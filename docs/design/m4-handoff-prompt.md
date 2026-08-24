# 《前线壁垒》M4 交接提示词（Handoff Prompt）

> 状态：**M4 已执行完成（待人工复核）**——5 项议题全部落地；已按多轮人工反馈修订（M4 表现层修复、M4.1 设置/末波/图标/token、M4.2 键位寻址修复+设置分页+根目录 config.cfg+玩家 2 贴图修复、攻击朝向修复+枪口焰去 Light 光斑）；细节与全部决策见 `m4-design.md`（§9/§10 修订表）。
> 验证：GUT **227/227 全绿**（M4.1 后原基线脆弱测试在全量顺序下也通过）；loopback 40s 冒烟 PASS（host=ok client=ok）；relay 新 token 建房验证成功；改动未提交（提交时机由开发者定）。

---

## 一、M3 收尾现状速览（M4 所需最小上下文）

- **架构**：host 权威（listen server）+ 意图 RPC + 快照（玩家 20Hz / 敌人 10Hz 双通道）+ 事件中继 + client 只读镜像；**M3 新增本地预测**（client 本地玩家 SIMULATED 本地模拟 + 快照阈值校正，`PREDICTION_CORRECTION_DISTANCE=80px`）。
- **M3 方案 B（命中判定逻辑化）**：`scripts/core/combat/hitscan_resolver.gd`（纯几何判定）；`GameSession._on_shot_fired` 统一裁决（host/OFFLINE）；client tracer 画到 host 裁决命中点（`EVT_SHOT_FIRED` 带 `hit_points`）；敌人受击闪白走 `EVT_ENEMY_HIT`；连射热度 heat 迁入 `PlayerController`（core）。
- **M3 遗留（已知）**：① `frontend_wiring` 2 个测试在全量顺序下脆弱（基线零改动，单独跑绿）；② NodeTunnel 完整游戏进程 join 稳定挂起（上游 beta 插件兼容缺陷，`m3-design.md` §6.3 有完整调试存档；`run-dual-test.ps1 -Relay -AppId <token>` 可复测）。
- **关键文件**：`scripts/systems/game_session.gd`（装配/裁决）、`scripts/systems/net/net.gd`（`--net=host|client [--relay] [--address=]`）、`scenes/player/player_view.gd`、`scenes/enemy/enemy_view.gd`、`scenes/base/barricade_view.gd`、`scenes/ui/`（hud/shop_panel/pause_panel/result_panel）、`addons/mc_game_framework`（UIManager/EventBus/Registry）、`addons/sound_manager`（v2.6.1，**已启用但未接入任何音频**）。
- **测试/运行**：GUT（`$env:APPDATA` 重定向）、`tools/run-dual.ps1 [-Relay]`、`tools/run-dual-test.ps1 [-Relay -AppId]`；ps1 纯 ASCII。

---

## 二、M4 议题清单（5 项，按开发者提出的顺序）

### 议题 1：音频与美术素材接入（素材已就位）

- **现状**：项目视觉/音效均为**程序生成**（Polygon2D 矢量几何 + 无音频）；`addons/sound_manager` 已启用但零接入。
- **素材现状（临时文件夹 `assets_pack/`，用户明确其为临时目录！）**：
  - `kenney_top-down-shooter`（PNG/Spritesheet/Tilesheet/Vector）：hitman 角色动作帧（gun/hold/machine/reload/silencer）、武器、瓦片——**替换现有矢量几何玩家/敌人/武器表现**；
  - `kenney_cursor-pack (2)`（PNG/Vector）：光标素材（含方向箭头等，**需确认是否有准星类素材**）；
  - `kenney_particle-pack`（PNG Transparent/Black background + Unity samples）：粒子贴图；
  - `sounds/`：**音频已就位**——`music/`（2 首 mp3：More than Arcade Life / No Longer Being Normal）、`sounds/`（handgun_shoot/smg_shoot/mag_empty/reload/entity_hurt/human_die_1~3/mob_die/heal/item_drop）、`ui/`（select/shopping_buy/unable）。
- **待办**：
  1. 素材从 `assets_pack/` 迁移到正式目录（建议 `assets/audio/music|sfx|ui`、`assets/sprites/`、`assets/particles/`），**迁移完成后清理 `assets_pack/`**；
  2. 用 `sound_manager` 接入：开火（区分枪型）/换弹/弹匣空/受击/死亡/击杀/购买/UI 点击/波次告警；音乐循环（战斗曲 + 波间曲切换）；
  3. Kenney 素材替换矢量几何表现（玩家/敌人/武器/路障/基地），保留现有碰撞几何（CollisionShape 不变，仅视觉替换）；
  4. **License 确认**：Kenney 素材 CC0（可商用、无需署名）；`sounds/` 来源需确认（mp3 带 .import 文件，来源与授权待确认）。
- **待确认**：`sounds/` 素材来源与授权；音乐曲目选择与切换规则（按波次/状态？）。

### 议题 2：Theme 设计与光标状态机（战斗准星）

- **现状**：`assets/theme/minimal_vector.tres` 已接线（project.godot `gui/theme/custom`）；`modern_flat.tres` 存在未用；**无自定义光标**（系统默认箭头）。
- **待办**：
  1. 基于议题 1 的美化素材更新 Theme（面板/按钮/进度条/字体排版风格统一，军事风）；
  2. **光标状态机**（M4 明确需求）：
     - 战斗状态（combat_context 启用时）→ **准星光标**；
     - 一般状态（菜单/商店/波间）→ **默认光标**；
     - **装填/切枪 → 进度准星**（随 reload/switch CD 显示进度，复用现有 `ReloadStartedEvent` / `WeaponSwitchStartedEvent` 的 duration 与 HUD 计时）。
  3. 光标与 GUIDE 上下文联动：`GameSession._setup_input` 启用/禁用 combat_context 的时机即战斗/非战斗切换点（现有 `_combat_context` 字段 + `_exit_tree` 清理逻辑可直接挂钩）。
- **素材确认（已勘察）**：`kenney_cursor-pack (2)/PNG` 内含 **`cross_large.png` / `cross_small.png`（十字准星）**，战斗准星可直接使用；另有 `busy_circle.png`（环形进度感素材，可参考做装填/切枪进度准星）。

### 议题 3：粒子与光线效果（为黑夜/昼夜战斗预留）

- **现状**：`CPUParticles2D` 仅用于敌人死亡爆发（`enemy.tscn` DeathParticles，client 镜像已降级）；`kenney_particle-pack` 素材未用；项目渲染为 Forward Plus（**支持 2D 光照：PointLight2D/DirectionalLight2D/CanvasModulate**，未启用任何光）。
- **待办**：
  1. 基于 particle-pack 接入：弹道火光/枪口焰增强、命中火花、爆炸、受击粒子、路障损坏碎片等（替换/增强现有程序化粒子）；
  2. **光线预留**：夜间战斗/昼夜交替长周期战斗的地基——2D 光照层（CanvasModulate 环境色、PointLight2D 枪口/爆炸光、动态光衰减），M4 只做**效果接入 + 光照架构预留**（如 `LightingManager`/环境状态），昼夜循环本身留 M5+；
  3. 性能纪律：粒子池化（现有 `object_pool.gd`）、client 镜像降级策略沿用（`MIRROR_PARTICLE_SCALE`）。
- **待确认**：光照性能目标（同屏光源数上限）、昼夜时长与循环是否 M4 范围（建议 M5+）。

### 议题 4：主菜单 / 暂停 / 配置界面（多人房间 UI）

- **现状**：**无主菜单**（`main_scene = main.tscn` 直接进战斗）；已有 `shop_panel` / `pause_panel` / `result_panel`（UIManager 栈式管理）；**联网启动全部走命令行参数**（`--net=host|client --address= --relay`，`net.gd` 解析），无 UI。
- **待办**：
  1. **主菜单场景**（`scenes/ui/main_menu.tscn`）：标题 + 开始游戏（单机）/ 多人（创建房间 / 加入房间）/ 设置 / 退出；UIManager 挂载或独立场景切换（**切换流程待定**：`get_tree().change_scene_to_file` 与现有 GameSession 生命周期/Net autoload 的衔接——注意 Net 是 autoload 常驻，重启局不需要重启引擎）；
  2. **多人房间界面**：
     - 创建房间：模式选择（局域网 `--net=host` / 互联网 relay `--relay`）→ 显示房间码/端口（relay 模式 room_id 来自 `Net.room_id`，已具备）；
     - 加入房间：输入 IP+端口（局域网）或房间码（relay）→ 调 `Net` 启动；
     - **需要把 `net.gd` 的命令行解析扩展为可编程 API**（如 `Net.start_host(port, relay, url, app_id)` / `Net.join_host(address, ...)`——现为 `_ready` 一次性解析，M4 需重构为可调用形式；命令行参数保留为兜底）；
  3. **设置界面**：音量（music/sfx/ui 三路，配合 sound_manager）、画质选项（可选）；**持久化**：`ConfigFile`（user://）或现有框架（`save-load` 技能可参考）；
  4. 暂停/结算面板按议题 2 的 Theme 统一重设计。
- **待确认**：主菜单与战斗场景切换架构（change_scene vs UIManager 覆盖层）；配置项清单与持久化格式；多人房间 UI 的信息架构（房间列表 vs 房间码直连——NodeTunnel 有 `get_rooms()` 可做公共房间列表，是否 M4 范围）。

### 议题 5：路障放置与玩家碰撞（接入时需提前确认配置方案）

- **现状**：路障为弧形 `StaticBody2D`（layer 8 world；`collision_mask` 设计：敌人（mask 13）被阻挡、**玩家（mask 6）不受影响 → 玩家可跨越路障**）；放置逻辑 `_try_place_barricade(p_player_id)`：消耗放置者 1 建材，位置 = **放置者玩家当前站位**（弧心=基地、弧线穿过玩家脚下）。
- **开发者的新需求**：
  1. **玩家不能跨越路障**（碰撞）——"玩家能跨越路障倒是有点奇怪"；
  2. **放置位置改为"玩家前方"**——相对基地的**极坐标距离更远**（方位角不变，半径 + 偏移），即路障放在玩家与基地连线的外侧。
- **接入时需提前确认的配置方案**（开发者明确）：
  - **碰撞实现**：玩家 `collision_mask` 加入路障层（6 → 6|8？）的后果——玩家出生点在基地内、路障围成弧圈，需验证玩家能否在弧内自由移动、能否被自己放置的路障困住/卡死；`move_and_slide` 与 ConcavePolygonShape2D 凹碰撞交互；**是否有"路障不可被玩家穿过但玩家可绕行"的层/掩码组合**（如路障只挡"外侧→内侧"方向——2D 无单向碰撞，需用 Area 或代码门控）；
  - **放置公式**：`pos = base_dir.normalized() * (player_radius_from_base + OFFSET)`（方位角不变、半径外推）；OFFSET 取值（贴脸 vs 留出移动空间）；放置距离上限/下限（现有 `facility.build_radius` 校验是否保留）；
  - **放置规则**：是否限制"前方最近可放位置"（防重叠/防挡自己出生点）；多人下放置者与基地连线以谁的位置为基准（放置者自己 ✓ 现有语义）；
  - **导航影响**：敌人 NavigationAgent 不绕行路障（M2 backlog）——玩家不可穿过后，路障阵型会把玩家困在弧内还是弧外？弧心朝向基地、玩家在弧内侧（贴近基地）→ 路障外推后玩家在弧内侧仍有活动空间——需实测。
- **建议**：M4 接入时先写设计小节（参考 `m2-design.md` §12 路障 backlog + `barricade_controller.gd` 几何），再做最小碰撞验证（玩家 mask + 路障层，双开/单机实测卡位），最后定配置。

---

## 三、M4 测试与纪律（沿用既有约定）

1. GUT：`$env:APPDATA` 重定向跑；新增 class_name 后 `--headless --import` 刷新全局类缓存；测试间 EventBus/面板/输入状态残留需自清理（M3 经验：`GameSession._exit_tree` 已清理 GUIDE context）；
2. 双进程冒烟：`tools/run-dual-test.ps1`（loopback 必跑；relay 需 token）；
3. ps1 纯 ASCII；`assets_pack/` 迁移完成后删除（临时目录）；
4. 前后端分离：逻辑进 `scripts/core/`（M3 方案 B 为先例——判定/状态归 core，表现层只播效果）；UI 只读状态 + 发意图/事件。

## 四、M4 决策记录（Agent 依惯例自行拍板，返回后人工复核）

| # | 决策 | 依据 |
|---|---|---|
| D-M4-1 | 素材按 m4-design §2 目录迁移，完成后已删除 assets_pack/ | 议题 1 待办 1 |
| D-M4-2 | sounds/ 来源未明仍接入，授权留待人工确认 | 议题 1 待确认 |
| D-M4-3 | SFX/UI/Music 三总线 + AudioDirector autoload（headless 不播音乐） | sound_manager 探测逻辑 |
| D-M4-4 | 音效映射表见 m4-design §2（弹匣空用 AmmoChanged mag 边沿触发） | 素材库 11 个 SFX |
| D-M4-5 | 战斗曲=More than Arcade Life，波间/菜单=No Longer Being Normal | 两首曲目特性 |
| D-M4-6 | 玩家 Soldier1/ManBlue，Visual 随瞄准旋转，姿势映射 machine/gun/hold/reload | Kenney 帧语义 |
| D-M4-7 | 敌人 zoimbie1_stand 静态贴图 | 近战怪无枪械 |
| D-M4-8 | 基地 tile_214 钢盘、路障 tile_105 沙袋、地面 tile_01/05 | Kenney 高饱和/分类可读原则 |
| D-M4-9 | 光标三态（系统默认/准星/进度帧切） | 议题 2 |
| D-M4-10 | 粒子贴图接入 + FX burst 池 + client 降级沿用 | 议题 3 |
| D-M4-11 | LightingManager 光池预留，昼夜留 M5 | 议题 3 待确认项拍板 |
| D-M4-12 | 主菜单 change_scene_to_file，Net 常驻复用（SceneNavigator） | 议题 4 待确认 |
| D-M4-13 | Net.start_host/join_host + net_failed 信号（CLI 兜底保留） | 议题 4 待办 2 |
| D-M4-14 | 房间码直连，公共房间列表 M6 | 议题 4 待确认 |
| D-M4-15 | ConfigFile user://settings.cfg 三路音量（SettingsManager） | 议题 4 待办 3 |
| D-M4-16 | 玩家 mask 6→14（保持基地阻挡 + 新增路障阻挡），不做伪单向 | 议题 5 配置确认 |
| D-M4-17 | 外推 48px + 半径下限 96 + 间距 64（core 纯函数） | 议题 5 放置公式 |
| D-M4-18 | 已执行：GUT 纯函数+碰撞测试 8/8 绿、loopback 冒烟 PASS | 议题 5 建议 |

## 五、M4 建议拆分（供规划参考）

- **M4a 表现层**：议题 1（素材迁移 + 音频接入）→ 议题 2（Theme + 光标）→ 议题 3（粒子/光线预留）；
- **M4b 界面层**：议题 4（主菜单/房间 UI/设置）；
- **M4c 玩法层**：议题 5（路障碰撞与放置，先设计后最小验证）。
