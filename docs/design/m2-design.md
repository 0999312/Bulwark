# 《前线壁垒》M2 多人架构验证 · 设计文档

> 版本：v1.0 · 日期：2026-08 · 里程碑：M2 多人架构验证（本机双客户端）
> 关联：`m2-handoff-prompt.md`、`design-review-m2-pre.md`、`architecture-design.md` §4.11/§6/§13.2
> 本文件为 M2 实施依据；开发者离机期间由 Agent 按 §8 决策记录自行拍板，返回后人工验证。

---

## 1. 目标与验收

- **目标**：MultiplayerAPI 权威模型验证——host 权威裁决，双客户端共同防守同一基地。
- **验收**：
  1. `tools/run-dual.ps1` 一键拉起 host + client 两个窗口，同局稳定运行（同步无错乱、无双倍结算）；
  2. client 可独立输入（单套键位，本机多窗口焦点切换）移动/射击/放置路障/购物，host 裁决并回显；
  3. **IP 直连（M2 内完成）**：client 支持 `--address=<host-ip>` 连接任意主机地址（局域网真机联机），默认 127.0.0.1 本机双开；
  4. headless 冒烟 `tools/run-dual-test.ps1` 双进程跑通（退出码判定）；
  5. GUT 全量回归 160+ 通过 + M2 新增单测。

## 2. 权威边界（承接 design-review §5 R1~R10）

| 系统 | 权威方 | 同步方式 | 客户端角色 |
|---|---|---|---|
| 玩家移动/瞄准/射击意图 | host（验证 + 模拟） | 意图 RPC（client→host，逐帧） | 只发意图；位置由快照驱动 |
| 玩家位置/血量/状态 | host（PlayerController + PlayerView 物理） | 快照 20Hz + 事件 | 镜像渲染 |
| 敌人 AI/寻路/位置/攻击 | host 独占（客户端无 NavigationAgent/碰撞） | 快照 20Hz（含 dead 标记） | 镜像 + 死亡粒子 |
| 伤害/击杀/掉落/货币 | host 独占（RNG 全局调用仅存在于 host 进程） | 快照 + 事件 | 只读 |
| 波次/刷怪/构成 | host（WaveDirector + SeededRNG） | 事件（wave_warning 简化摘要等） | HUD 显示 |
| 基地耐久 | host | 事件 + 快照兜底 | 表现 |
| 路障 | host（放置验证/受击/摧毁） | 事件（placed/damaged/destroyed） | 镜像 |
| 商店/货币/复活 | host（请求-响应） | 事件 + 意图 RPC | 镜像只读 + 发意图 |
| 暂停/商店/结算 UI 状态 | host | ui_state 事件 | 跟随开关（客户端不暂停树） |

**R1~R10 处理映射**：R1 客户端不跑寻路/AI（快照驱动）✓；R2 结算只在 host 进程 ✓；R3 全部前端→后端调用点封装为意图 RPC（清单见 §6）✓；R4 Net 会话骨架 = 本设计 §4 ✓；R5 刷怪/掉落 RNG 全部 host 独占 ✓；R6 GameSession 拆 host/client 双分支（§5）✓；R7 跨端序列化 = NetCodec（var_to_bytes 字典协议，§5.4）✓；R8 客户端不暂停树，跟随 ui_state ✓；R9 本地-远端玩家 = role 系统（§5.3）+ 敌人镜像 ✓；R10 player_count_scale 双人血量缩放（§9）✓。R11 冒烟脚本 + GUT 协议层测试（§11）；R12/R13 留 M6（带宽分级 / shop_panel 场景假设已纳入 client 分支处理）。

## 3. 网络拓扑

- **双进程 loopback + 局域网 IP 直连**（开发者拍板：M2 必须完成 IP 直连，验收不依赖任何在线设施）。
- 端口默认 31007（host 命令行 `--net=host --port=N`；client `--net=client --port=N --address=<host-ip>`，默认 `--address=127.0.0.1` = 本机双开；局域网联机时 client 传 host 的局域网 IP，host 防火墙放行端口即可，ENet 无需其他设施）。
- 单机（无 `--net` 参数）= OFFLINE 模式：走 host 逻辑但不挂网络层，M1 行为逐字节不变（GUT 集成测试直接实例化 main.tscn，必须兼容）。
- 玩家身份：host = player_id 0，首个客户端 = player_id 1（M2 固定双人）。

## 4. 网络层组件

### 4.1 `Net` autoload（scripts/systems/net/net.gd，project.godot 注册）

- 状态：`mode`（OFFLINE/HOST/CLIENT）、`peer_id`、`client_count`。
- 启动：解析 `OS.get_cmdline_user_args()` 的 `--net=host|client` / `--port`；`ENetMultiplayerPeer` + `multiplayer.multiplayer_peer`。
- **process_mode = ALWAYS**（host 暂停树期间仍接收/分发 RPC——商店/继续/暂停意图不丢）。
- 意图 RPC 入口（全部 `@rpc("any_peer", "call_local", "reliable")`，client→host 方向，经 `rpc_id(1, ...)` 或封装 `send_intent`）：
  `intent_move / intent_aim / intent_shoot / intent_reload / intent_switch / intent_place_barricade / intent_purchase / intent_equip / intent_unequip / intent_shop_continue / intent_toggle_pause`。
  收到后统一转 `GameSession._on_net_intent(player_id, intent, args)`（host 分支裁决；单机调用不经过网络）。
- host→client 通道：`rpc_sync_state(bytes)`（unreliable，20Hz 全量快照）、`rpc_handle_event(name, bytes)`（reliable 事件队列）。
- 信号：`host_started / connected_to_host / peer_connected / peer_disconnected`。

### 4.2 `NetCodec`（scripts/systems/net/net_codec.gd，纯函数 RefCounted）

- `pack_snapshot(dict) -> PackedByteArray` / `unpack_snapshot(bytes) -> Dictionary`（var_to_bytes/bytes_to_var 往返）。
- `pack_event(name, dict) / unpack_event(bytes)`。
- 跨端负载一律「字符串键字典 + Godot 原生类型」（Vector2→`[x, y]` 数组，避免浮点位差）。
- 快照/事件协议（§5.4/§5.5）集中定义在本模块常量区（`SNAPSHOT_KEYS`、`EVENT_*`），禁止散落魔法键。

## 5. GameSession 双分支重构

### 5.1 分支入口

```
_ready():
    ContentBootstrap.register_all(); _build_navigation()
    match Net.mode:
        OFFLINE / HOST:  _setup_host()   # 完整 M1 逻辑 + 双玩家 + 网络发送
        CLIENT:          _setup_client() # 只读镜像 + 快照/事件应用 + 意图发送
```

- OFFLINE：行为与 M1 完全一致（单玩家、无网络、_ready 末尾立即 start_run）。
- HOST：等 `peer_connected`（首个客户端）后才 `_start_run()`；期间 UI/输入照常装配。
- CLIENT：连上 host 后收到首个快照即开始（无需本地 start_run）。

### 5.2 host 后端（双玩家）

| 字段 | 说明 |
|---|---|
| `players: Array[PlayerController]` | [0]=host 本地、[1]=远端；各自属性/武器独立 |
| `weapon_slots_list / ammo_systems` | 每玩家独立（弹药独立、配件独立） |
| `revive_systems: Array[ReviveSystem]` | 每玩家独立 CD，共享 run_state 储备 |
| `run_state / shop_system / base_core` | 单一共享（货币/建材/储备/武器全局强化共享，P24 多人经济细则留 M6） |
| `attachment_bag` | 共享背包（装配目标按玩家） |

- 敌人/波次/基地/路障 = 现有单实例不变。
- `_physics_process`：循环 tick 全部玩家 + 复活 + 波次。
- 玩家事件（PlayerHealthChanged/Died/Revive*/ShotFired/Ammo/Weapon*/Reload/Attachment*）发布时携带 `player_id`（§7 事件类扩展）。

### 5.3 玩家视图角色（PlayerView 扩展）

| 进程 | 玩家 A(0) | 玩家 B(1) |
|---|---|---|
| host | LOCAL + SIMULATED（GUIDE 输入 → controller） | REMOTE + SIMULATED（Net 意图 → controller，同节点模拟） |
| client | NONE + SNAPSHOT（纯镜像，位置/朝向快照驱动） | LOCAL + SNAPSHOT（GUIDE 输入 → 仅发 RPC；位置快照驱动） |

- `role: LOCAL/REMOTE/NONE` 决定 `_process` 是否读 GUIDE（LOCAL）或忽略（REMOTE/NONE）。
- `position_mode: SIMULATED/SNAPSHOT` 决定 `_physics_process` 是否物理移动（SIMULATED）或仅由 `apply_snapshot()` 置位（SNAPSHOT）。
- `player_id` 过滤事件：视图只响应属于自己的事件（受击闪红/复活表现/开火表现）。
- host 的 B 视图：`PLAYER_SCENE.instantiate()` 运行时创建，初始位置 (0,-180)（基地另一侧）；REMOTE 视图的 tracer/枪口焰照常由 ShotFiredEvent 驱动（host 物理射线 → host 权威命中）。
- client 的 A 视图 = main.tscn 现有 Player 节点（位置被快照覆盖）；B 视图运行时创建。

### 5.4 快照协议（host→client，20Hz，unreliable 全量）

```python
{
  "tick": int,
  "run": {"paused": bool, "shop_open": bool, "finished": bool,
          "credits": int, "material": int, "reserve": int,
          "bag": [String], "wave_index": int, "wave_total": int},
  "base": {"durability": float, "max": float},
  "players": {
    0: {"pos": [x, y], "aim": float, "hp": float, "max_hp": float, "state": int},
    1: {...}
  },
  "enemies": { int_id: {"pos": [x, y], "state": int} },  # state: 0=alive 1=dead（dead 保留到粒子播完）
}
```

- 敌人 net_id：host 在 `_on_spawn_request` 分配递增（EnemyView.net_id）。
- client 应用：`players` → 视图置位 + hp/state 变化去重发事件；`enemies` → 增删改镜像（alive 置位；dead 播死亡反馈；消失时若未 dead 直接 free）；`base`/`run` 去重发事件（HUD 刷新）。

### 5.5 事件协议（host→client，reliable）

| 事件 | payload | client 动作 |
|---|---|---|
| wave_warning | `{wave_index, wave_total, tiers: {"heavy":[dirs], "light":[dirs]}}` | 重建 WaveWarningEvent（含 direction_tiers）→ HUD |
| wave_started / wave_cleared | `{wave_index, wave_total}` | 重建事件 → HUD |
| player_health / player_died / revive_started / revived | `+player_id` | 仅本地玩家事件重建发布（HUD/视图）；shot/ammo/weapon 同理按 player_id 过滤 |
| shot_fired | `{player_id, model_location, aim_direction}` | 对应视图播 tracer/枪口焰（纯表现，命中已由 host 结算） |
| ammo_changed / weapon_switched / weapon_switch_started / weapon_switch_rejected / reload_started | `+player_id` | 本地玩家 HUD 重建 |
| attachment_equipped / attachment_unequipped | `+player_id` | 本地玩家镜像槽位更新 |
| bag_changed | `{player_id, bag:[String]}` | 镜像背包全量替换 |
| shop_offers | `{offers:[{location, price, owned, affordable}]}` | 镜像 ShopSystem.offers 重建（client 从 Registry 解析 ShopItemData） |
| shop_purchased / shop_purchase_rejected | `{location, price, reason}` | 重建事件（面板反馈）+ 触发 host 重发 shop_offers 刷新 |
| run_state | `{credits, material, reserve}` | 重建 RunStateChangedEvent（镜像 run_state 同步） |
| base_durability | `{current, max}` | 重建事件（镜像 base_core 同步） |
| barricade_placed / barricade_damaged / barricade_destroyed | `{location, pos, durability, max}` | 重建事件 → client 创建/更新/移除路障镜像 |
| ui_state | `{paused, shop_open, result:{victory, reason}}` | 打开/关闭 ShopPanel / PausePanel / ResultPanel（不暂停树） |

- client 端事件路由：全局事件（wave/base/run_state/barricade/shop/ui）全部 publish；玩家事件按 `player_id == 本地 id` 过滤 publish。
- 商店面板数据（client 打开时）：镜像 `shop_system / weapon_slots / run_state / bag` + 空 effect_handler（购买走 intent）。

## 6. 意图 RPC 清单（前端→后端调用点盘点，承接 R3）

| 调用点（M1 现状） | M2 意图 | 备注 |
|---|---|---|
| PlayerView._process → controller.set_move_intent/set_aim_direction/set_shoot_intent | intent_move / intent_aim / intent_shoot（逐帧） | host 侧 REMOTE 视图直接写 controller |
| PlayerView._poll_weapon_switch → intent_switch | intent_switch | |
| PlayerView → intent_reload | intent_reload | |
| GameSession._process interact → _try_place_barricade | intent_place_barricade | host 用该玩家模拟位置（不信客户端坐标） |
| GameSession._process pause → _toggle_pause | intent_toggle_pause | client 暂停请求 → host 裁决 |
| ShopPanel._on_buy_pressed → shop_system.try_purchase | intent_purchase(item_location) | host 校验（上架/货币） |
| ShopPanel._on_bag_pressed → weapon_slots.equip_attachment | intent_equip(slot, attachment_location) | host 校验（背包有货） |
| ShopPanel._on_unequip_pressed | intent_unequip(slot, attachment_slot) | |
| ShopPanel._on_continue_pressed → on_shop_closed | intent_shop_continue | host 恢复波次 |
| PausePanel._on_resume_pressed → tree.paused=false | intent_toggle_pause（client 侧） | host 侧本地直切 |

## 7. 事件类与后端扩展（player_id / 无敌帧）

- 玩家相关事件类加 `player_id: int = 0`（可选构造参数，默认 0 兼容全部现有构造点与测试）：
  PlayerHealthChangedEvent / PlayerDiedEvent / ReviveStartedEvent / RevivedEvent / ShotFiredEvent / AmmoChangedEvent / WeaponSwitchedEvent / WeaponSwitchStartedEvent / WeaponSwitchRejectedEvent / ReloadStartedEvent / AttachmentEquippedEvent / AttachmentUnequippedEvent。
- `PlayerController`：加 `player_id`（构造可选参数），发布玩家事件时携带；加**复活无敌帧**（M1 已知问题 #7）：`revive()` 后 `INVINCIBLE_DURATION := 2.0s`，期间 `take_damage` 直接返回空结果（敌人守尸不再秒杀）。
- `WeaponSlots`：加 `player_id`（可选构造参数），发布弹药/切换/换弹事件时携带。
- `WaveWarningEvent`：加 `direction_tiers`（`{"heavy":[dirs], "light":[dirs]}`，wave_director 填充；空 = 旧逻辑回退）。
- `WaveComposition.summarize_tiers(threshold)`：按方向聚合 count，`count >= threshold` 定级 heavy，否则 light；`HEAVY_THRESHOLD := 6`（W1~3 单方向 6~11 → 大量；W4+ 快/硬壳 2~5 → 少量，符合直觉）。
- `RunnerController._init(p_data, p_hp_scale = 1.0)`：双人血量缩放注入点（不破坏现有构造）。

## 8. HUD 波次方位分级（开发者指示：按数量级简化为大量/少量）

- `hud._on_wave_warning`：`compass_label` 显示「来袭 大量 ↑→↓← · 少量 ↘↙」（每档只列方向箭头，tier 内按方向排序）；banner 同构。
- 单机与双机走同一 `direction_tiers` 数据（wave_director 统一填充），不再逐方向罗列箭头。
- 纯函数 `_format_tiers` 供 GUT 断言。

## 9. 双人强度缩放（R10）

- host 在线（HOST 且 client 已连接）时，`_on_spawn_request` 对每只敌人应用 `enemy_data.player_count_scale`（血量乘数）：`RunnerController.new(data, data.player_count_scale)`。
- 资源文件 `enemy_runner/fast/tough.tres` 的 `player_count_scale` 从 1.0 → **1.6**（架构 §4.6 建议值）。
- 单机（OFFLINE）不应用（数据字段仅双人时消费）；波次数量不缩放（保持 WaveGenerator 种子确定性，GUT 断言不受影响；数量缩放留 M6）。
- `EnemyView.setup` 增加可选 `p_hp_scale := 1.0` 透传。

## 10. 双客户端输入（单套键位，本机多窗口）

- **双端共用同一套键位**（combat_context：WASD/鼠标/左键/1-2-3/R/E/Esc）：键盘与鼠标输入属于**有焦点的窗口**，本机双开时各窗口点击获得焦点后即可独立操作，无需第二套键位（M2 修订：alt 键位方案已移除，避免过度设计）。
- 局域网真机联机时每台机器天然一套键位，与单机体验一致。
- client 分支 `_setup_input` 与 host 完全相同（同一 combat_context；双进程各自启用，互不影响）。

## 11. 测试与验收

### 11.1 GUT 新增
- `test_net_codec.gd`：快照/事件 pack→unpack 往返一致（含 Vector2/嵌套数组/浮点）。
- `test_wave_composition_tiers.gd`：`summarize_tiers` 分级/阈值/方向聚合。
- `test_revive_invincibility.gd`：revive 后 2s 内 take_damage 免疫；过期后恢复。
- `test_player_count_scale.gd`：RunnerController hp_scale 生效；默认参数不破坏。
- `test_event_player_id.gd`：玩家事件 player_id 构造/携带。

### 11.2 回归
- 全量 GUT（现 160 + 新增）headless 通过（APPDATA 重定向，见 m2-handoff §六）。

### 11.3 双进程冒烟（R11 最小化）
- `tools/run-dual-test.ps1`：host（headless，`--net=host --smoke`）+ client（headless，`--net=client --smoke`）各独立 APPDATA；client 自动发意图（移动/射击/放置）；host 统计并断言：快照帧数 > 0、收到意图数 > 0、client 镜像敌人峰值 > 0、双端基地耐久一致；`--smoke` 到达时限（默认 45s）后输出 `SMOKE_RESULT=ok/fail` 并退出码判定。
- `tools/run-dual.ps1`：窗口模式一键双开（人工验收用）。

## 12. 路障设计 backlog（开发者指示：仅记录，不在 M2 实现）

- 弧形路障（R=玩家距离、弧长 60°、自动朝向基地）已在 M2 前置调参落地（`barricade_controller.gd` 几何 + `barricade_view.gd`）。
- **M2 范围外待议问题（记录，不处理）**：
  1. 敌人 NavigationAgent 不绕行路障（物理阻挡后原地啃）——M3+ 防线系统做导航动态烘焙；
  2. 弧段覆盖角 ≤60° 的单段局限（多方位来袭需多段补防，尚无"段数/成本/上限"设计）；
  3. 路障"完全替代玩家"风险（耐久/成本上限未定，商店"路障耐久+"成长线未做）；
  4. 其他由开发者补充的具体设计问题（本文件作为登记处）。
- 详细分析见 `design-review-m2-pre.md` §4；处理时机 M3+。

## 13. 变更文件清单

- 新增：`scripts/systems/net/net.gd`、`scripts/systems/net/net_codec.gd`、`tools/run-dual.ps1`、`tools/run-dual-test.ps1`、`tests/unit/test_net_codec.gd`、`tests/unit/test_wave_composition_tiers.gd`、`tests/unit/test_revive_invincibility.gd`、`tests/unit/test_player_count_scale.gd`、`tests/unit/test_event_player_id.gd`、本文件。
- 修改：`project.godot`（Net autoload）、`game_session.gd`、`player_view.gd`、`enemy_view.gd`、`hud.gd`、`shop_panel.gd`、`pause_panel.gd`、`player_controller.gd`、`weapon_slots.gd`、`runner_controller.gd`、`wave_director.gd`、`wave_composition.gd`、`wave_warning_event.gd` + 12 个玩家相关事件类、`enemy_*.tres`×3（scale 1.6）、`tools/generate_guide_context.gd`、`docs/design/m2-handoff-prompt.md`（M2 收官更新）。

## 14. 决策记录（开发者离机，Agent 自行拍板，返回后请人工复核）

| # | 决策 | 依据 |
|---|---|---|
| D1 | 双进程 loopback + 局域网 IP 直连（`--address=`），房主即服务器 | 开发者拍板：不写专用服务端、不依赖 Steam/第三方，IP 直连必须在 M2 完成；listen server 是架构 §13.2 既定路线；互联网穿透选型（Steam/relay）留 M6+ |
| D1b | 单套键位（双端共用 combat_context），不设备选键位 | 开发者拍板：键盘/鼠标输入属于有焦点的窗口，本机多窗口各自点击焦点即可独立操作；alt 键位方案（已实现）移除，避免过度设计 |
| D2 | 客户端位置完全快照驱动（无本地预测） | 权威彻底、实现最简；loopback 延迟≈0，体感可接受；预测留 M6 |
| D3 | 货币/建材/储备/武器全局强化共享；武器/弹药/配件/复活 CD 独立 | P19/P24 未定，取"共享资源池 + 独立构筑"折中，M6 再细化 |
| D4 | 双人缩放在敌人血量（×player_count_scale=1.6），不缩放波次数量 | 保护 WaveGenerator 种子确定性测试 |
| D5 | 任一玩家点"继续"即恢复波次 | 合作节奏最简单 |
| D6 | 任一玩家储备耗尽 → 本局失败（与单机同规则） | 多人失败规则 M6 细化 |
| D7 | 方位分级阈值 6 | 对齐 wave 数据分布（W1~3 全大量、W4+ 快/硬壳少量） |
| D8 | 复活无敌帧 2.0s | M1 已知问题 #7 建议值 |

## 15. 已知取舍（M2 验证范围外）

- 带宽/快照频率分级（R12）、玩家预测插值、掉线重连、2 人以上会话、商店多人专属规则（P24）、波次数量缩放 → 全部 M6。
- client 无本地物理：玩家/敌人/路障碰撞仅存在于 host 进程。
- 快照 20Hz reliable 语义：loopback 下丢帧可忽略；全量覆盖保证最终一致。
