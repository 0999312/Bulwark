# 《前线壁垒》M3 多人设计问题修复 · 交接提示词（插队 M3）

> 状态：**由 M2 局域网实测产生，插队 M3 优先处理**（早于原 M3 计划内容）。
> 用法：新对话首条消息 = 本文件全文；M2 背景细节见 `m2-design.md` 与 `m2-handoff-prompt.md`。
> 关联代码均已提交（commit `096281d` / `e5e8515`），工作区干净，可直接接手。

---

## 一、M2 现状速览（新对话所需最小上下文）

- **架构**：host 权威（listen server，房主即服务器）+ 意图 RPC + 快照 20Hz reliable 全量 + 事件中继 + client 只读镜像（无本地模拟，位置/敌人/状态全由快照驱动）。
- **双进程**：`--net=host` / `--net=client --address=<ip>`（IP 直连，本机 127.0.0.1 双开或局域网真机，无任何在线设施）。
- **关键文件**：
  - `scripts/systems/net/net.gd`（autoload：连接、意图中继、快照/事件通道、player_id 分配）
  - `scripts/systems/net/net_codec.gd`（协议编解码与键常量）
  - `scripts/systems/game_session.gd`（host 双玩家权威模拟 + 快照发送 / client 镜像装配 + 应用）
  - `scenes/player/player_view.gd`（Role LOCAL/REMOTE/NONE × PositionMode SIMULATED/SNAPSHOT）
  - `scenes/enemy/enemy_view.gd`（client 镜像模式：无 AI/碰撞，快照驱动）
  - `scenes/ui/hud.gd`（按 player_id 过滤显示本地玩家）
- **测试/运行**：`tools/run-dual.ps1`（窗口双开）、`tools/run-dual-test.ps1`（headless 双进程冒烟）、GUT 185/185（`$env:APPDATA` 重定向跑）。
- **已知技术坑（勿回退）**：ENet peer id 随机大数 → player_id 由 host 显式分配下发；快照包 > MTU 1392 时 unreliable 直接丢包 → 快照必须 reliable；ps1 脚本必须纯 ASCII（PowerShell 5.1 无 BOM UTF-8 中文会破语法）。

## 二、M3 修复问题清单（5 项，来自局域网实测）

### 问题 1：多人窗口共用一个摄像机（玩家 2 锁定不到自己角色）

- **现象**：client 机玩家 2 的镜头没有跟随本地玩家，锁定不到自己的角色。
- **初步根因**：每进程有两个 PlayerView（host：本地 A + 远端 B；client：远端 A + 本地 B），而 `player.tscn` 每个 PlayerView 自带一个 `Camera2D`。Godot 的 Camera2D 是"最后 enabled 者成为当前相机"，且镜像视图（远端玩家）的相机不应启用——当前装配未做显式相机管理，导致镜头归属错乱。
- **代码位置**：`scenes/player/player_view.gd`（`@onready var camera: Camera2D = $Camera2D`）、`game_session.gd` 的 `_setup_scene_bindings_host()` / `_setup_scene_bindings_client()`、`scenes/player/player.tscn`。
- **建议方向**：装配时显式管理——本地玩家视图相机 `enabled = true + make_current()`，远端镜像视图相机 `enabled = false`；或在 GameSession 装配时统一把相机从 PlayerView 解耦（每进程只挂一个本地相机）。需双开实测确认镜头跟随各自本地玩家。

### 问题 2：双机共用暂停状态（应改为全队同意才暂停）

- **现象**：任一玩家按 Esc → host 暂停树 → 全队暂停。
- **期望**（用户意见）：**全部玩家都请求暂停时，游戏逻辑才正式暂停**；仅一名玩家请求时游戏继续（该玩家可弹出自己的暂停面板）。
- **初步设计**：host 维护"暂停请求集合"（player_id → 请求中）。暂停生效条件 = 所有在线玩家均已请求；恢复同理（全部恢复或任一取消，需拍板：建议"任一玩家取消即恢复"或"全部确认恢复"，M3 内定稿）。host 端 `_toggle_pause` 与 client `intent_toggle_pause` 都改为"请求"语义，HUD 可提示"玩家 X 请求暂停 (1/2)"。
- **代码位置**：`game_session.gd` 的 `_toggle_pause()` / `_on_net_intent` 的 `toggle_pause` 分支、`pause_panel.gd`、`net.gd` 意图通道、`ui_state` 事件（client 跟随）。
- **注意**：host 树暂停期间 `Net` 为 `PROCESS_MODE_ALWAYS`，意图不丢（已具备）；暂停协议须兼容"暂停中收到其他玩家请求/取消"。

### 问题 3：client 机卡顿 + 粒子效果差

- **现象**：client 相对 host 明显卡顿；粒子效果显示差劲。
- **初步根因**（需实测确认）：
  1. 快照 20Hz reliable 全量（~1.6~2.2KB）→ 每帧解包 + 全量重建，真机带宽/CPU 开销放大；
  2. 快照位置**无插值**（20Hz 跳变 → 视觉卡顿感）；
  3. client 渲染双方所有玩家/敌人镜像 + 每只敌人死亡粒子 + 弹道 tracer，无任何降级；
  4. `_apply_enemies_snapshot` 全量增删改字典，敌人多时每帧开销大。
- **代码位置**：`game_session.gd` 的 `_send_snapshot()` / `_apply_player_snapshot()` / `_apply_enemies_snapshot()`、`net.gd` `send_snapshot`、`player_view.gd`（tracer 对象池已复用，检查 client 端行为）、`enemy_view.gd`（死亡粒子）。
- **建议方向**：① 快照位置插值（client 侧记录上一帧快照，渲染位置 lerp）；② 快照频率分级（玩家高频/敌人中频，M6 计划项可提前最小实现）或增量快照；③ client 粒子降级（死亡粒子数量/开关随窗口模式配置）；④ headless 冒烟不暴露渲染性能，**必须以双开窗口实测为准**。
- **备注**：本问题与问题 1 同属"client 表现层"，可一并修。

### 问题 4：多人共享资源设计（小队应有独立资源分配）

- **结论**（用户拍板）：共享资源（货币/建材/储备/武器全局强化）对本游戏不是好设计，**小队应有独立资源分配设计**。
- **现状**：`RunState` 单一实例全队共享（credits/material/reserve + 全局强化 bonus），击杀奖励入共享池，商店消耗共享货币；武器/弹药/配件/复活 CD 已按玩家独立。
- **设计决策点（M3 需定稿，P19/P24 长期未定）**：每人独立货币/建材/储备？还是"小队公共 + 个人"双层？击杀奖励归属（击杀者独享/小队均分）？商店购买用谁的钱？商店价格是否按人数缩放？强化（STAT_WEAPON）作用于个人还是共享？
- **代码位置**：`game_session.gd`（`run_state` 创建与 `_on_enemy_died` 奖励、`_shop_effect_handler`）、`scripts/core/economy/run_state.gd`、`shop_system.gd`、快照 `RUN_*` 字段与 `EVT_RUN_STATE`/`EVT_BAG_CHANGED` 协议。
- **建议**：先写设计小节（可参考 `game-design-doc.md` §13 多人扩展 + `architecture-design.md` §4.8），再改代码；协议层（快照/事件）需同步扩展为 per-player 资源字段。
- **提醒**：此改动会触碰 `RunState`/`ShopSystem` 的既有单测，注意回归（GUT 185 基线）。

### 问题 5：接入 P2P 联机库（NodeTunnel）解决互联网联机燃眉之急

- **需求**：无服务器、无 Steam、无端口转发前提下的互联网联机。
- **调研结果**（新对话需进一步验证）：
  - [NodeTunnel/godot-plugin](https://github.com/NodeTunnel/godot-plugin)：Godot 多人连接库，"no port forwarding, no dedicated servers"——通过公共 relay 服务器穿透 NAT；
  - 服务端实现 [curtjs/nodetunnel](https://github.com/curtjs/nodetunnel)（relay 中转的 P2P）；
  - 连接流程简化议题见 [issue #15](https://github.com/NodeTunnel/godot-plugin/issues/15)。
- **M3 待办**：验证 Godot 4.7 兼容性与插件形态（GDExtension？普通插件？）；接入方式（替换 `ENetMultiplayerPeer` 作为 `multiplayer.multiplayer_peer` 的 provider？还是包一层连接层？）；relay 服务可用性/免费额度/自部署；与现有 `Net` 层的最小改动面。
- **硬性约束**：**权威模型不变**（host 权威、意图 RPC、快照同步全部保留）——NodeTunnel 只解决"怎么连上"，不改变"谁裁决"。目标：`--net=host` 多一个 `--relay` 模式走 NodeTunnel 接入，现有 loopback/局域网路径不破坏。

## 三、M2 架构关键约定（修复时勿破坏）

| 约定 | 说明 |
|---|---|
| 前后端分离 | `scripts/core/` 纯逻辑无 get_node；表现层只读状态 + 发意图（架构硬性约束） |
| host 权威 | 敌人 AI/寻路/RNG/掉落/结算只存在于 host 进程；client 无物理 |
| player_id | host 显式分配下发（`assign_player_id` RPC），前端事件按 player_id 过滤 |
| 快照 reliable | MTU 1392 陷阱：全量快照必须 reliable（unreliable 大包被 ENet 丢弃） |
| 事件中继 | host 订阅 EventBus → `Net.send_event` → client 重建/路由（`_on_net_event`） |
| 单机兼容 | OFFLINE 模式（无 --net）= M1 行为不变，GUT 集成测试直接实例化 main.tscn |
| 测试纪律 | GUT 与双进程冒烟**不可并发**（共享 .godot 缓存会互踩）；ps1 脚本纯 ASCII |

## 四、验收建议（M3 完成后）

1. 双开窗口：问题 1（镜头各自跟随）、问题 2（单方暂停不冻结、双方暂停才冻结）、问题 3（client 流畅度/粒子观感）实测通过；
2. 局域网真机复测（与本次测试相同环境）；
3. 问题 4：设计文档定稿 + 独立资源在小队场景跑通（击杀归属/商店消费符合设计）；
4. 问题 5：NodeTunnel 模式在互联网环境（跨 NAT）实测连上并同局稳定；
5. 回归：GUT 全量（185 基线 + 新增）+ `tools/run-dual-test.ps1` 冒烟 PASS。
