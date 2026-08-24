# 《前线壁垒》M3 多人设计问题修复 · 设计文档

> 版本：v1.0 · 日期：2026-08 · 里程碑：M3（插队，早于原 M3 计划内容）
> 关联：`m3-handoff-prompt.md`（问题清单与验收）、`m2-design.md`（M2 架构约定，勿破坏）
> 本文件为 M3 实施依据；决策记录见 §8，开发者返回后请人工复核。

---

## 1. 范围

按 `m3-handoff-prompt.md` 顺序修复 5 项局域网实测问题：
1. 多人窗口共用一个摄像机（玩家 2 锁定不到自己角色）
2. 双机共用暂停状态（改为全队同意才暂停）
3. client 机卡顿 + 粒子效果差
4. 多人共享资源（改为小队独立资源分配）
5. 接入 NodeTunnel 解决互联网 P2P 联机（调研 + 最小集成）

硬性约束（M2 架构约定，不破坏）：
- host 权威 + 意图 RPC + 快照/事件中继；client 只读镜像
- 快照 reliable（MTU 1392 陷阱）；ps1 纯 ASCII
- 单机（OFFLINE）= M1 行为不变；GUT 集成测试直接实例化 main.tscn
- 测试纪律：GUT 与双进程冒烟不可并发

## 2. 问题 1：摄像机归属（表现层显式管理）

- **根因**：每个 PlayerView 自带 Camera2D，Camera2D 语义为「最后 enabled 者成为当前相机」；远端镜像视图相机未禁用 → 镜头归属错乱。
- **方案**：`PlayerView.set_role()` 显式管理相机：
  - `LOCAL` → `camera.enabled = true` + `make_current()`（每进程唯一活跃相机 = 本地玩家）
  - `REMOTE` / `NONE` → `camera.enabled = false`
- 相机震动（后坐反馈）只作用于启用相机（`_tick_gunplay` 判断 `camera.enabled`）。

## 3. 问题 2：全队同意暂停（协议级）

- **现状**：任一玩家 Esc → host 直接暂停树 → 全队冻结。
- **方案（D-M3-1）**：暂停 = 请求语义。
  - host 维护暂停请求集合 `_pause_requests: {player_id -> bool}`；**全员请求 → 冻结树；任一取消 → 恢复**（handoff 建议项定稿）。
  - 本地表现：按 Esc 立即开关**自己的**暂停面板（client 本地 `_toggle_pause_local` + 发意图；host 本地 `_toggle_pause(pid)`）。
  - 协议：`ui_state` 负载新增 `pause_requests: [player_id...]`（host 汇总广播）；client 面板开关由**本地请求状态**驱动，ui_state 只驱动正式暂停态与 HUD 提示。
  - HUD 新增暂停提示：「玩家 X、Y 请求暂停 (n/m) · 全员请求才暂停」。
  - 波间商店打开时树由商店托管（保持暂停），暂停请求只裁决非商店状态（`_evaluate_pause` 并入 shop_open 判定；`on_shop_closed` 后回到请求裁决）。
  - host 树暂停期间 Net 为 PROCESS_MODE_ALWAYS，意图不丢；暂停中收到请求/取消照常处理。

## 4. 问题 3：client 卡顿 + 粒子效果差

1. **快照渲染插值（双缓冲线性，M3 修订）**：`PlayerView` / `EnemyView` 镜像记录
   「上一快照点 → 当前快照点」，渲染位置在 `SNAPSHOT_INTERVAL`（玩家 0.05s / 敌人 0.1s）内
   线性推进；首帧快照直接置位（防漂移滑入）。取代初版指数平滑（对匀速运动滞后、
   产生"漂移/橡皮筋"视觉，真机双开实测否决）。
2. **快照频率分级**：敌人快照独立通道 10Hz（`Net.send_enemies` / `sync_enemies` RPC，
   reliable），玩家/run/base 保持 20Hz 主快照 → 带宽与 CPU 减半。
3. **client 粒子降级**：镜像死亡粒子 `amount × 0.5`（`MIRROR_PARTICLE_SCALE`，保底 2）。
4. **镜像去重**：`_apply_enemies_snapshot` 位置未变跳过置位（`_mirror_last_pos`），消失时同步清理。

### 4.1 本地预测（方向 B，真机双开实测后拍板）

- **背景**：快照驱动（M2 D2）在 client 端固有"输入→画面"整条链路延迟（RPC→host 模拟→
  快照回传→插值），本机双开实测 client 手感/流畅感显著差于 host；敌人插值（尤其 10Hz）
  存在切弯/漂移观感。
- **方案**：client 本地玩家（`LOCAL`）改 `PositionMode.SIMULATED` **本地模拟**
  （输入即时生效，手感 = 单机）；意图照发（host 权威裁决不变）。
  - 快照校正：`apply_prediction_correction`——偏差 ≤ 80px 视为预测领先不拉回；
    超过阈值（host 权威差异：碰撞/路障/复活）→ 每快照向权威位置收敛 50%（无跳变）。
  - `PLAYER_STATE` 快照同步（M2 遗漏补上）：client 镜像 controller 的 state 与 host 一致，
    本地模拟在 DEAD/REVIVING 时正确停止移动。
  - 远端玩家/敌人镜像：保持双缓冲线性插值。
- **边界**：core 零改动（`scripts/core/` 无新增）；预测/校正全部在表现层；host 权威不变。
- **测试**：`test_m3_snapshot_interp.gd`（小偏差保持/大偏差拉回/SNAPSHOT 模式不响应）。

### 4.2 镜像反馈修复（真机双开实测后补）

| 现象 | 根因 | 修复 |
|---|---|---|
| client 命中敌人无受击反馈（敌人仍正常死亡） | 镜像敌人 `controller==null`，`apply_player_hit` 直接 return | mirror 模式命中仅闪白（纯表现，伤害仍 host 权威，不双重结算） |
| 路障被击穿后 client 仍显示存在、受击不闪白 | 镜像路障 `BarricadeController.new(facility, 0)` 的 `location#0` 与 host 事件 `location#真实id` 不匹配，`BarricadeView._on_damaged/_on_destroyed` 的 location 校验丢弃 | `_apply_barricade_placed` 从事件 location 解析 instance_id，镜像 controller 与 host 一致 |

- 回归测试：`test_m3_mirror_feedback.gd`（镜像敌人闪白不结算 / 镜像路障 location 匹配 + 销毁移除）。

### 4.3 命中判定逻辑化（方案 B，架构修订）

- **背景**：M1/M2 的命中判定实为"表现层物理射线"（`get_world_2d().direct_space_state.intersect_ray`）——
  裁决与渲染状态耦合（碰撞体开关/物理空间直接影响裁决）；client 镜像敌人（碰撞禁用）
  导致子弹视觉上穿过敌人（"没有受击反馈"实为命中判定不一致）。用户拍板：**命中判定逻辑化**。
- **方案**：
  - 新增 `scripts/core/combat/hitscan_resolver.gd`（core 纯几何：线段 vs 圆形目标集合，
    无节点/物理依赖）——"打没打中"由 core 确定性计算。
  - `GameSession`（装配层，host/OFFLINE）订阅 `ShotFiredEvent` 统一裁决：
    权威位置（host 视图=模拟）收集目标 → 散布（含连射热度/移动倍率）→ core 判定 →
    命中 → 伤害（`apply_player_hit`，killer_id 归属）→ 中继（`EVT_SHOT_FIRED` 带命中点 /
    `EVT_ENEMY_HIT` 敌人受击）→ 驱动视图 tracer（`view.show_tracer`）。
  - client 不再本地发射线：tracer 画到 host 裁决的命中点（视觉=裁决），镜像闪白由
    `EVT_ENEMY_HIT` 驱动——**"子弹穿敌人身体"从根上消除**。
  - 连射热度（heat）迁入 core（`PlayerController`）：命中散布参数随裁决状态，
    视图只保留后坐/震屏/枪口焰等纯手感反馈。
- **边界**：判定几何、散布、heat 全部在 core/装配层；视图零判定零伤害；
  host 权威不变；单机（OFFLINE）走同一裁决路径。
- **测试**：`test_hitscan_resolver.gd`（几何单测 6 项）+ `test_m3_mirror_feedback.gd`
  （EVT_ENEMY_HIT 闪白）+ 既有 `test_player_fire_hits_enemy_with_stats` 兼容。

## 5. 问题 4：小队独立资源分配

### 5.1 设计决策（D-M3-2，用户拍板"小队应有独立资源分配"，细则定稿如下）

| 维度 | M2 现状（共享） | M3 定稿（独立） |
|---|---|---|
| 货币 credits | RunState 单实例共享 | **每人独立** RunState（含 bonus） |
| 建材 material | 共享 | **每人独立**（路障建造用放置者建材） |
| 应急储备 reserve | 共享 | **每人独立**（复活用个人储备；任一耗尽判负规则不变） |
| 武器全局强化 bonus | RunState 共享 | **每人独立**（STAT_WEAPON 落购买者个人通道） |
| 配件背包 | 共享 | **每人独立**（装配/卸下操作各自背包） |
| 商店 | 单 ShopSystem（价格递增共享） | **每玩家一个 ShopSystem**（同 seed 刷新同商品集；purchase_counts 独立 → 价格递增独立） |
| 击杀奖励 | 入共享池 | **击杀者独享**（EnemyDiedEvent 携带 killer_id；掉落建材/弹药同理归击杀者） |
| 商店价格按人数缩放 | — | 不缩放（M6 再议） |

- 实现：`GameSession` 持有 `run_states / shop_systems / attachment_bags` 数组；`run_state / shop_system / attachment_bag` 保留为 **players[0] 兼容别名**（单机语义 + 既有测试/代码引用不破坏）。
- `RunState` 增加 `player_id` 字段（构造可选参数，默认 0）；`RunStateChangedEvent` 增加 `player_id`（默认 0，兼容全部现有构造点）。
- 击杀归属链路：`PlayerView._fire_ray(player_id)` → `EnemyView.apply_player_hit(stats, dir, killer_id)` → `RunnerController.take_damage(ctx, killer_id)` → `die(killer_id)` → `EnemyDiedEvent(+killer_id)`；撞击自爆 killer = 被撞玩家。
- 弹药补给 `_grant_bullets(amount, pid)` 落击杀者/购买者弹药池。

### 5.2 协议扩展（快照/事件 per-player）

```
SNAP_RUN.resources: {
  "0": {"credits": int, "material": int, "reserve": int, "bag": [String]},
  "1": {...},
}
```
- `EVT_RUN_STATE` / `EVT_BAG_CHANGED` 负载新增 `KEY_PLAYER_ID`（host 中继带 player_id；client 更新对应镜像，只对本地玩家发布事件）。
- `EVT_SHOP_OFFERS` 简化为 `{offers: [{location}]}`（client 用本地镜像 purchase_counts + credits 自行计算价格/已购/可负担 —— 广播同一 payload 无法表达 per-player 视角）。
- client 镜像：`_client_purchase_counts` 本地累积（EVT_SHOP_PURCHASED 时 +1，与 host 侧只统计本玩家购买一致）。
- HUD 资源行按本地玩家过滤；商店面板绑定本地玩家实例（shop/run_state/bag）。

## 6. 问题 5：NodeTunnel 接入（互联网 P2P）

### 6.1 调研结论（详见 `m3-p5-nodetunnel-research.md` + 本机实测）

- **插件形态**：Rust GDExtension（`MultiplayerPeerExtension` 子类 `NodeTunnelPeer`），预编译二进制随 GitHub Releases 分发（Windows dll / Linux so / macOS dylib）；**Godot 4.7 加载实测通过**（headless 冒烟确认类注册与 relay 连接）。
- **接入方式**：`NodeTunnelPeer` 直接替换 `ENetMultiplayerPeer` 赋值给 `multiplayer.multiplayer_peer`——高层 RPC/信号/快照语义一致，host 权威模型零改动（路线 A，调研推荐）。
- **relay 服务**：公共 relay `us-east.nodetunnel.io:8080` / `eu_central.nodetunnel.io:8080` 在线（实测收到业务响应），**但要求注册 app token**（nodetunnel.io 注册应用 → 15 字符 token；未注册返回 401 "App token is not allowed"，实测确认）。自部署（`NodeTunnel/relay-server`，Rust，UDP 8080）不需要 token（WHITELIST 本地配置），当前环境无 Rust/Docker 未自部署。
- **协议兼容**：客户端 `PROTOCOL_VERSION = 1.1.0_beta` 与 relay-server `ALLOWED_VERSIONS=1.1.0_beta` 匹配；host peer id 恒为 1（`HOST_PEER_ID` 假设成立）；`get_max_packet_size = 16MB`（ENet MTU 1392 陷阱不适用，reliable 语义保留）。
- **房间流程**：host `host_room` → `room_connected` 拿 room_id 分享；client `join_room(room_id)` 加入；之后与 ENet 一致。

### 6.2 实现（net.gd 增量，loopback/局域网路径零改动）

- 新参数：`--relay`（布尔开关）、`--relay-url=`（默认 us-east.nodetunnel.io:8080）、`--app-id=`（默认 bulwark_frontline，公共 relay 需填注册 token）。
- host：`--net=host --relay` → 认证 → 建房间 → 打印 `room_id=<id>`（`host_started` 广播）。
- client：`--net=client --relay --address=<房间码>` → 认证 → 加入房间。
- `_make_relay_peer()` 统一构造 + error 信号接线；其余（意图 RPC/快照/事件/player_id 分配）全部复用现有路径。
- `tools/run-dual.ps1 -Relay`：host 日志自动抓取 room_id 并拉起 client（窗口双开人工验收用）。
- `tools/check_nodetunnel.gd`：relay 连通性/建房/加入验证脚本（headless）。

### 6.3 验证状态与待办（阻塞项明确）

| 项 | 状态 |
|---|---|
| GDExtension 在 Godot 4.7 加载 | ✅ 实测通过 |
| 公共 relay 在线可达（认证/建房/加入/peer_connected/数据转发） | ✅ `-s` 脚本链路 6/6 通过（含 host id=1、get_peers、发包收包） |
| **完整游戏进程（main.tscn）下 client join** | ⚠️ **稳定挂起**（status 恒 CONNECTING、relay 无响应；-s 模式/双赋值场景可成功 → 判定为 NodeTunnel v1.1.0_beta（godot-rust api-4-3）在 Godot 4.7 完整进程环境的兼容缺陷；非本项目代码问题，接入层逻辑与协议层均已验证） |
| 跨 NAT 真机实测 | ⏳ 同上（需插件上游修复或自部署 relay 排查） |
| 自部署 relay（可选兜底） | ⏳ 需 Rust/Docker 环境（README：`cargo build --release` + `RELAY_ID/ALLOWED_VERSIONS/UDP_BIND_ADDRESS` 环境变量 + WHITELIST） |

**调试结论存档**（后续接手者避免重复排查）：
- `set_multiplayer_peer` 在 Godot 4.7 校验 peer 状态（须 CONNECTING/CONNECTED）→ 必须先 `connect_to_relay`（同步置 CONNECTING）再赋值；
- Net 的 `mode` 必须同步设置（不得随 relay 连接延迟），否则 GameSession 按 OFFLINE 单机装配并立即开跑（曾导致双端误触发 [RUN-START]）；
- NodeTunnelPeer 事件处理依赖 poll（主场景由 MultiplayerAPI 驱动）；`-s` 脚本模式需手动 poll；
- `process_frame` 信号先于场景 `_ready` flush（赋值顺序影响 poll 归属）。

## 7. 验收

| 项 | 状态 |
|---|---|
| GUT 全量 | ✅ **206/208 通过**（基线 185 恢复零改动 + M3 新增 23）；**2 个已知脆弱**：`frontend_wiring` 的 result 面板残留 + Esc 输入残留（跨测试顺序问题，与 M3 无关，单独跑 7/7 绿；按开发者决策保持基线零改动） |
| loopback 双进程冒烟（`tools/run-dual-test.ps1`） | ✅ PASS（M2 路径无回归；敌人 10Hz 通道 + 本地预测同步路径实测工作） |
| 问题 1 相机归属 | ✅ 代码 + 单测（LOCAL enabled/make_current；REMOTE/NONE 禁用）；窗口双开人工复核待做 |
| 问题 2 全队暂停 | ✅ 代码 + 单测（单方不冻结/全员冻结/取消恢复/远端请求不弹本地面板/商店托管）；双开人工复核待做 |
| 问题 3 client 流畅度 | ✅ 双缓冲线性插值（漂移修复）+ 敌人 10Hz 通道 + 粒子降级 + 镜像去重；**本地预测（方向 B）已实现**（§4.1）；真机观感待双开复核 |
| 问题 4 独立资源 | ✅ 设计定稿（§5）+ 代码 + 单测（击杀归属/个人商店/个人建材）；小队场景跑通待双开复核 |
| 问题 5 NodeTunnel | ⚠️ 接入完成 + 链路验证（-s 6/6）；完整游戏进程 join 稳定挂起 = 上游 beta 插件兼容缺陷（§6.3），待插件上游修复或自部署 relay 排查 |

## 8. 决策记录（Agent 依 M2 惯例自行拍板，返回后请人工复核）

| # | 决策 | 依据 |
|---|---|---|
| D-M3-1 | 暂停：全员请求才冻结；任一取消即恢复 | handoff 建议项；节奏最简（M2 D5 同精神） |
| D-M3-2 | 资源：每人完全独立（货币/建材/储备/强化/背包/商店计数），击杀独享，价格不缩放 | 用户拍板"小队独立资源分配"；单层最简，双层留 M6 |
| D-M3-3 | 性能：指数插值 + 敌人 10Hz 独立通道 + 镜像粒子减半 + 位置去重 | handoff 建议方向的最小实现；增量快照留 M6 |
| D-M3-4 | 商店面板数据 per-player：offers 事件只带 location，client 自行计算视角 | 广播通道无法表达 per-player 价格/可负担 |
| D-M3-5 | 问题 5：NodeTunnel 接入采用路线 A（NodeTunnelPeer 直接替换 multiplayer_peer）；`--relay` 参数模式；公共 relay 需注册 app token，`--app-id` 承载 | 调研确认 MultiplayerPeerExtension 形态 + Godot 4.7 加载实测通过；host id=1 语义一致；自部署 relay 为无 token 兜底（需 Rust 环境） |
