# 《前线壁垒》M4 设计文档（素材 / 音频 / 表现 / 界面 / 路障）

> 状态：M4 进行中。本文件记录 M4 全部自行拍板决策（依 m4-handoff-prompt.md §四惯例，返回后人工复核）。
> 上游：`m4-handoff-prompt.md`；M3 细节见 `m3-design.md`。

---

## 1. 视觉与素材总原则（开发者补充，必守）

**Kenney 用色核心：高饱和 + 明确分类 + 易阅读。**

- 选材优先高饱和、轮廓清晰、一眼可辨类型的 Kenney 素材；不用灰蒙蒙/低对比素材。
- 分类用色：玩家（军绿/蓝）、敌人（僵尸红/棕）、路障（沙袋亮黄褐）、基地（钢灰金属）保持高可辨度。
- Theme 沿用同一纪律：面板暗色底 + 高饱和强调色（青绿交互 / 琥珀警示），字体粗描边保证易读。
- 完整 `tilesheet_complete.png`（27×20 格，64px/格）已勘察：M4 只取散装 `tile_*.png` 的草地/沙地/沙袋/钢圆盘做地面与设施贴图；完整 TileMap 铺装（道路/水体/建筑成套）留给 M5 环境阶段，避免 M4 范围膨胀。

---

## 2. 议题 1 决策：素材迁移与音频接入

### D-M4-1 素材目录（迁移后删除 `assets_pack/`）

```
assets/audio/music/    More than Arcade Life.mp3 / No Longer Being Normal.mp3
assets/audio/sfx/      handgun_shoot / smg_shoot / mag_empty / reload / entity_hurt
                       / human_die_1~3 / mob_die / heal / item_drop
assets/audio/ui/       select / shopping_buy / unable
assets/sprites/chars/  soldier1_*（玩家 A）、manBlue_*（玩家 B）、zoimbie1_*（敌人）
assets/sprites/tiles/  tile_01(草地) tile_05(沙地) tile_105(沙袋墙) tile_214(钢圆盘)
assets/particles/      muzzle/spark/flame/smoke/dirt/scorch/circle/star/light/flare 子集
assets/cursors/        cross_large / cross_small / progress_CCW_{25,50,75} / progress_empty / progress_full
assets/licenses/       三份 Kenney License.txt
```

### D-M4-2 音频授权

- Kenney 三包均为 CC0（License.txt 随包迁移留档）。
- `assets_pack/sounds/`（mp3）来源与授权未标注：**M4 照常接入**（用户明确素材已就位），但在决策表中标注"授权待人工确认"，交付说明中提示：若复核发现非 CC0，需在发布前替换或补授权。项目目前无发布计划，风险可控。
- **M5 更新（人工确认）**：音效/UI 音为公共素材；两首音乐来自 Clash'N Slash（Enkord / tj technoiZ），作曲家已离世、Enkord 基本沉寂，**仅作为本地测试素材，发布前必须替换或取得授权**。详见 `THIRD_PARTY_NOTICES.md`。

### D-M4-3 音频总线（default_bus_layout.tres）

- `Master → SFX / UI / Music` 三条总线；sound_manager 的探测逻辑（SFX/UI/Music）自动命中。
- `AudioDirector`（新 autoload，挂在 SoundManager 之后）订阅 EventBus 事件播放；所有音频触发点与玩法代码解耦。

### D-M4-4 音效映射表

| 事件 | 资源 | 备注 |
|---|---|---|
| ShotFiredEvent（突击步枪/霰弹主副槽） | smg_shoot | 霰弹 pitch 0.8 随机 0.75~0.85（单资源无霰弹音，低频感替代） |
| ShotFiredEvent（手枪） | handgun_shoot | pitch 随机 0.95~1.05 |
| ReloadStartedEvent | reload | |
| 弹匣空 | mag_empty | 实现取 AmmoChangedEvent mag 边沿（host 权威事件中继后 client 同触发，免新增 core 事件） |
| PlayerHealthChangedEvent（下降） | entity_hurt | 只对本地玩家 id |
| PlayerDiedEvent | human_die_1~3 随机 | |
| EnemyDiedEvent | mob_die | |
| RevivedEvent | heal | |
| ShopPurchasedEvent | shopping_buy | UI 总线 |
| ShopPurchaseRejectedEvent / WeaponSwitchRejectedEvent | unable | UI 总线 |
| UIOpenEvent（面板开） / UI 按钮点击 | select | UI 总线（按钮点击由 UI 脚本直接触发） |
| WaveWarningEvent | unable（pitch 0.6，告警感） | 无专属素材的临时映射 |
| BarricadePlacedEvent | item_drop | 放置落地感 |
| BarricadeDestroyedEvent | mob_die pitch 0.6 | 结构倒塌感 |

### D-M4-5 音乐切换

- `More than Arcade Life` = 战斗曲；`No Longer Being Normal` = 波间/主菜单曲。
- `WaveStartedEvent → 战斗曲`；`WaveClearedEvent → 波间曲`；`RunDefeat/RunVictory → 停战斗曲，回主菜单后播波间曲`；主菜单 `_ready` 播波间曲。
- mp3 导入设置 Loop 在 AudioDirector 运行时置位（不依赖 .import）。
- headless（GUT/冒烟/自检）不播音乐：dummy 音频下长流退出会留引用告警；SFX 不受影响。

---

## 3. 议题 2/3 决策：表现层（精灵 / 光标 / 粒子 / 光照）

### D-M4-6 玩家表现（保留碰撞，视觉全换）

- `player.tscn`：CollisionShape2D 不变；新增 `Visual`（Node2D，旋转=瞄准角）→ `Body`（Sprite2D）+ `MuzzleFlash`（Sprite2D）。
- 俯视角标准做法：整个 Visual 随瞄准旋转（枪口基线朝 +X），身体跟随转身；原 Aim 节点移除。
- 玩家 A = Soldier 1；玩家 B = Man Blue（分类易读：绿 vs 蓝）。
- 姿势映射（按 Kenney 帧语义）：MAIN/SUB → `machine`，PISTOL → `gun`，切枪中 → `hold`，换弹中 → `reload`，死亡 → `stand`（旋转 90° + 半透明）。
- **枢轴（人工游玩修订）**：所有姿势共用该视觉包 stand 帧的身体中心偏移（soldier1 ≈ -2.9,-0.5；manBlue ≈ -2.2,-0.5），旋转轴固定在躯干上，切帧不跳。
- 枪口后坐 tween 作用在 `Visual.position`（沿 aim 反向回退）；命中闪白作用在 `Body.modulate`。

### D-M4-7 敌人表现

- `enemy.tscn`：Body → Sprite2D（`zoimbie1_stand.png`，offset 对齐），删除 Teeth/Horn 多边形；`visual_scale` / `body_color` / 闪白 / 死亡粒子逻辑全保留。
- **朝向（人工游玩修订）**：Kenney 帧默认朝 +X；新增 `Visual` 层按移动方向旋转（CHASE = 速度方向、ATTACK = 面向目标、镜像 = 快照插值方向），修复"向下移动却横向朝右"的 90° 错位。

### D-M4-8 基地与路障（贴图化，几何仍程序生成）

- 基地：`tile_214.png`（钢灰圆盘，64px）Sprite2D scale≈1.5 替换八边形主体；Core/Glow 保留作高饱和核心光；耐久变色走 modulate。
- 路障：弧面几何照旧重建，`Visual` Polygon2D 增加 `texture=tile_105.png`（沙袋墙）+ 沿弧长/thickness 生成 `uv`；Outline/Spikes 颜色改为 Kenney 沙袋系亮色。
- 地面：Ground 用 `tile_01`（高饱和草地绿），ZoneA/B/C 用 `tile_05`（沙地）贴 Polygon2D 平铺纹理（纯色平铺，成本≈0）；网格/圆环线保留（军规读数感）。

### D-M4-9 光标状态机（CursorStateMachine autoload）

- 三态：DEFAULT（系统箭头，无 custom cursor）/ COMBAT（`cross_large` 准星，hotspot 16,16）/ PROGRESS（`progress_CCW_{25,50,75,empty,full}` 按剩余比例切帧）。
- 状态裁决优先级：`get_tree().paused 或 UIManager 面板开 → DEFAULT`；`Reload/WeaponSwitch 计时进行中 → PROGRESS`；`combat_active → COMBAT`；否则 DEFAULT。
- `GameSession._setup_input` 启用 combat_context 时 `CursorStateMachine.set_combat_active(true)`，`_exit_tree` 置 false（与现有 GUIDE 清理同点挂钩）。
- 进度准星数据源 = `ReloadStartedEvent.duration` / `WeaponSwitchStartedEvent.switch_cd`（复用 HUD 计时语义）。

### D-M4-10 粒子接入（pooling + client 降级纪律）

- 迁移 `PNG (Transparent)` 子集；给 CPUParticles2D 设 texture：
  - 敌人死亡：随机 `spark_*` + 保留 color_ramp（MIRROR_PARTICLE_SCALE 降级不动）。
  - 玩家枪口焰：`muzzle_01`（Sprite2D 闪现，替代原三角形 Sight）。
  - 命中火花：HitPoints 处由 GameSession 生成一次性 `CPUParticles2D`（`spark_05`），走 ObjectPool 风格手动复用（池容量 24，见 `scripts/systems/fx_burst.gd`）。
  - 路障摧毁：新增 `CPUParticles2D`（`dirt_01/02 + smoke_06` 双段或单段），跟随原淡出动画。
  - 基地低耐久烟：换 `smoke_06` 贴图。
- 性能纪律：动态粒子总数 ≤ 48；client 镜像死亡仍按 `MIRROR_PARTICLE_SCALE` 降量；命中火花只在 host/OFFLINE 裁决侧生成（client 由 EVT_ENEMY_HIT 闪白承担，不重复生成）。
- **人工游玩修订（尺寸）**：kenney_particle-pack 原图为 512×512 高清贴图，不能按默认 1.x 倍率用——所有 CPUParticles2D 的 `scale_amount` 已改为 0.02~0.08 档（约 10~40px），枪口焰 Sprite2D 0.07→0.035，PointLight2D 光斑 texture_scale 0.15（基地常驻 0.3），与 32px 角色同尺度。
- **人工游玩修订（整体尺度）**：Camera2D zoom 1.4 → 0.7（角色视觉尺寸 = 原来的 1/2），世界/碰撞/HUD 全部不动；可见区域约 1830×1030px，刷怪环 900px 半径仍大部分在屏外，接敌预警感保留。

### D-M4-11 光照架构预留（昼夜留 M5）
- 新增 `LightingManager` autoload：负责 CanvasModulate（环境色）、环境状态（DAY/NIGHT，M4 仅 DAY）、动态光池 `request_flash(pos, color, energy, duration)`（同屏上限 8）。
- M4 实际接线：本地玩家枪口焰触发 PointLight2D 闪（0.05s，衰减快）；基地 Core 常驻低强度暖光（1 盏，不占动态池）。
- M5 接口预留：`set_environment(state, color, duration)` / `DAY_LIGHT / NIGHT_LIGHT` 常量，M5 昼夜循环只调接口。

---

## 4. 议题 4 决策：主菜单 / 房间 / 设置（M4b）

### D-M4-12 场景架构：change_scene_to_file，不重启引擎

- `main_scene` 改为 `scenes/ui/main_menu.tscn`；`开始游戏` → `change_scene_to_file("res://scenes/world/main.tscn")`；结算/暂停 → `返回主菜单` 同法。
- Net 是 autoload 常驻：房间建好后 Net.mode 已定，切场景后 GameSession 按现有分支装配（host 等 client、client 等 player_id），无需改生命周期。
- 菜单场景与战斗场景互斥：切场景前 `UIManager.close_all()` + `remove_overlay(UI_HUD)`（防跨场景残留）；GameSession._exit_tree 已清 GUIDE context。

### D-M4-13 Net 可编程 API（CLI 兜底保留）

- `Net.start_host(options: Dictionary)`：`{port, relay, relay_url, app_id}` → ENet create_server 或 NodeTunnel host_room；emit `host_started` / `net_failed(msg)`。
- `Net.join_host(options: Dictionary)`：`{address(房间码/IP), port, relay, relay_url, app_id}` → ENet create_client 或 relay join；emit `connected_to_host` / `net_failed`。
- `_ready` 解析 CLI 后调用同一 API；`--net=` 兜底不变。
- 新增 `net_failed(msg)` 信号（房间 UI 显示错误，不再只有 push_error）。

### D-M4-14 房间 UI 信息架构（不做公共房间列表）

- 创建房间：局域网 / 互联网（relay）二选一 → 开始后显示 `端口 31007` 或 `房间码`（`Net.room_id`，创建完成后经 `host_started` 刷新）。
- 加入房间：局域网填 IP（默认 127.0.0.1）+ 端口；互联网填房间码（`--address` 语义）。NodeTunnel `get_rooms()` 公共列表留 M6（需服务端列表体验设计，M4 范围外）。

### D-M4-15 设置与持久化

- `SettingsManager` autoload：`ConfigFile` 存 `user://settings.cfg`，段 `[audio]`：`music_volume/sfx_volume/ui_volume`（0..1 线性）；启动时应用三总线；slider 用 `linear_to_db` / `db_to_linear`；接近 0 时 mute。
- 设置界面在菜单与暂停面板内都提供入口（面板复用）。
- 画质选项 M4 不做（1280×720 canvas_items 拉伸足够，M6 再议）。

---

## 5. 议题 5 决策：路障放置与碰撞（M4c，先设计后最小验证）

### D-M4-16 设计结论（碰撞）

- 玩家 `collision_mask` 6 → **14（= enemy2|base4|world8）**：保持原有敌人/基地阻挡，**新增路障层阻挡**（议题 5 原案 6|8）。
- 2D 物理无单向碰撞，不做"只挡外侧→内侧"的伪单向；玩家可绕弧端通行（弧形路障两端开放，这是绕行通道）。
- 出生点安全：玩家 A/B 出生半径 180（基地核心 r=48，基地阻挡为既有语义）；路障放置外推后距基地 ≥ 放置者半径+48，弧在玩家外侧；**规则上禁止在距基地 < 96px 半径内放置**（防止路障封死弧内活动空间）。
- move_and_slide 与 ConcavePolygonShape2D 凹碰撞：玩家低速 + 圆碰撞体，Godot 官方支持 CharacterBody2D 对凹形静态碰撞；M4c 双开/单机实测验证（设计上无穿透风险）。

### D-M4-17 设计结论（放置公式与规则）

```
base_dir   = (player.pos - base.pos)
r          = base_dir.length()
placement  = base.pos + base_dir.normalized() * (r + BARRIER_FORWARD_OFFSET)
BARRIER_FORWARD_OFFSET = 48px     # 留出玩家与弧之间一个身位的移动空间
约束：
  1) r >= BARRIER_MIN_RADIUS(96)                       # 不封死出生环
  2) placement 距基地 <= facility.build_radius         # 保留原上限校验
  3) placement 距既有路障中心 >= BARRIER_MIN_SPACING(64) # 防重叠堆叠
```
- 放置者语义不变：以放置者自己位置为极坐标基准（host 权威模拟位置，不信客户端坐标）。
- 敌人导航不绕行路障为 M2 backlog，M4 不展开；路障外推后敌人仍需先啃弧线，玩家在弧内活动空间更大（弧外推 = 内侧活动区变大），与"玩家不可穿过"兼容。

### D-M4-18 验证顺序

1. GUT：新增 barricade 放置几何纯函数测试（外推/半径/间距/上限）。
2. 单机手工冒烟：出生→E 放置→撞路障不可穿过→绕弧端通过。
3. `tools/run-dual.ps1` loopback 双开：双方互见路障、双方都被挡。

---

## 6. M4 决策记录（人工复核总表）

| # | 决策 | 依据 |
|---|---|---|
| D-M4-1 | 素材按 §2 目录迁移，完成后删除 assets_pack/ | 议题 1 待办 1 |
| D-M4-2 | sounds/ 来源未明仍接入，授权留待人工确认 | 议题 1 待确认 |
| D-M4-3 | SFX/UI/Music 三总线 + AudioDirector autoload | sound_manager 探测逻辑 |
| D-M4-4 | 音效映射见 §2 表 | 素材库只有 11 个 SFX |
| D-M4-5 | 战斗曲=More than Arcade Life，波间/菜单=No Longer Being Normal | 两首曲目特性 |
| D-M4-6 | 玩家 Soldier1/ManBlue，Visual 随瞄准旋转，姿势映射表 | Kenney 帧语义 |
| D-M4-7 | 敌人 zoimbie1_stand 静态贴图 | 近战怪无枪械 |
| D-M4-8 | 基地 tile_214 钢盘、路障 tile_105 沙袋、地面 tile_01/05 | Kenney 高饱和/分类可读原则 |
| D-M4-9 | 光标三态（系统默认/准星/进度帧切） | 议题 2 |
| D-M4-10 | 粒子贴图接入 + FX burst 池 + client 降级沿用 | 议题 3 |
| D-M4-11 | LightingManager 光池预留，昼夜 M5 | 议题 3 待确认项拍板 |
| D-M4-12 | 主菜单 change_scene_to_file，Net 常驻复用 | 议题 4 待确认 |
| D-M4-13 | Net.start_host/join_host + net_failed 信号 | 议题 4 待办 2 |
| D-M4-14 | 房间码直连，公共房间列表 M6 | 议题 4 待确认 |
| D-M4-15 | ConfigFile user://settings.cfg 三路音量 | 议题 4 待办 3 |
| D-M4-16 | 玩家 mask 6→14（保持基地阻挡 + 新增路障阻挡），不做伪单向 | 议题 5 配置确认 |
| D-M4-17 | 外推 48px + 半径下限 96 + 间距 64 | 议题 5 放置公式 |
| D-M4-18 | 已执行：GUT 放置/掩码/碰撞测试 8/8 绿 + loopback 冒烟 PASS | 议题 5 建议 |

---

## 7. M4 验证结果（交付时快照）

| 验证项 | 结果 |
|---|---|
| headless import 刷新 | exit 0，无 SCRIPT ERROR |
| 主菜单 headless 启动（--quit-after） | 无脚本错误 / 无资源泄漏告警 |
| GUT 全量（M4.1 后） | **227/227 全绿**（GameSession._exit_tree 面板清理后，原基线脆弱测试在全量顺序下也通过） |
| GUT M4 路障专项 | 8/8 通过（放置几何 / 间距 / 掩码 / move_and_slide 碰撞阻挡） |
| GUT M4.1 设置专项 | 3/3 通过（键位项暴露 / 绑定+恢复默认 / zh↔en 切换） |
| loopback 双进程冒烟（40s） | PASS：host=ok client=ok（快照 489 / 同步 442 / 敌人峰值 19） |
| relay 建房间（新 token 75wszckt2unslne） | 认证+建房成功（room_id 正常生成，0 脚本错误）；完整 relay 双端 join 仍受 M3 已知 NodeTunnel beta 缺陷影响 |
| M4.2 复测 | GUT 227/227 全绿 + loopback 40s PASS + relay 从 config.cfg 读默认值建房成功 |

## 8. 遗留与人工复核提示

- `assets/audio/**`（sounds/ 迁移）授权待确认（D-M4-2）；确认后补 THIRD_PARTY_NOTICES 或替换。
- `test_result_panel_opens_and_closes` 全量顺序失败为基线脆弱，非 M4 回归；单独跑绿。
- 昼夜循环 / 完整 TileMap 地面铺装 / NodeTunnel 公共房间列表留 M5/M6（D-M4-11/14）。
- 玩家 Visual 全向旋转属于俯视角射手表现惯例，若试玩后想恢复“身体不转身”可在 PlayerView 关掉 visual.rotation。

## 9. M4.1 人工游玩反馈修订

| # | 问题 | 处理 |
|---|---|---|
| R-1 | 多人建房 token 错误 | `Net.DEFAULT_APP_ID` / `run-dual*.ps1` 默认 AppId 改为有效 token `75wszckt2unslne` |
| R-2 | 枪口焰用错材质/像烟 | 换 `muzzle_02.png`（无烟星芒焰），弃用 muzzle_01 的烟尾 |
| R-3 | 设置项太少 | 设置面板新增：语言切换（MSF I18NManager + locales/zh.json、en.json）与键位绑定（GUIDERemapper + GUIDEInputDetector + user://input_bindings.json 持久化）；主菜单/暂停/结算文案走 tr() |
| R-4 | 末波还弹商店 | `GameSession._on_wave_cleared`：`event.wave_index >= waves.size()` 时直接 `resume_from_intermission()` → 胜利结算，不开商店 |
| R-5 | 摄像机出地图露背景 | Camera2D 加 limit_left/right/top/bottom（±1400/±1150，与地面矩形一致），zoom 0.7 下自动钳制 |
| R-6 | 新图标 | `icon.svg` 换成军用帐篷（橄榄绿 A 形帐篷 + 琥珀星） |

### M4.1 键位细节

- `tools/generate_guide_context.gd`：move/shoot/switch_weapon/pause/reload/interact 六个动作 `is_remappable=true`（aim 鼠标位置不可重映射），已重新生成 contexts。
- `InputSettings`（autoload）：保存与默认不同的绑定到 `user://input_bindings.json`；冲突自动清掉旧绑定；Esc 中止检测。
- 设置面板键位行：移动×4 / 射击 / 切换武器×3 / 暂停 / 换弹 / 互动，每行单独恢复 + 全部恢复默认。

### M4.1 语言细节

- `SettingsManager` 持久化 `[audio].language`（zh/en）；启动注册两套翻译并 set_locale。
- `locales/zh.json` / `locales/en.json` 覆盖主菜单/房间/设置/暂停/结算文案；游戏内 HUD 仍为中文（HUD 全量 i18n 留 M5）。

## 10. M4.2 第三轮反馈修订

| # | 问题 | 处理 |
|---|---|---|
| R-7 | 键位列表出现 4 个相同“移动”行 | 根因：combat_context 把 move/switch 拆成多个 GUIDEActionMapping，每个 input index 都是 0，GUIDERemapper 按 (context, action, index) 寻址互相覆盖。生成器改为多键合一 mapping（move 1×4、switch 1×3）并重新生成 context；新增 GUT 断言 index 唯一性 |
| R-8 | 键位与音量挤在同一面板不直观 | 设置面板改 TabContainer 三页：音频 / 键位 / 语言（见 `settings_panel.tscn`） |
| R-9 | 中转服务器不可调 | 新增根目录 `config.cfg`（玩家可见可改）：`[net] port/address/relay_url/app_id` + `[game] camera_zoom`；`AppConfig` autoload 读取，Net 默认值、房间 UI 预填、相机 zoom 全部走它。个人偏好仍在 `user://` |
| R-10 | 玩家 2 入场显示为角色 1 | `PlayerView.set_visual_pack()` 的 `_update_pose()` 对相同 pose 提前 return，没刷新贴图；现强制 `_current_pose = -1` 后重算 |
| R-11 | 敌人攻击基地/路障时“侧身” | 攻击朝向目标选择错误：原来用“最近路障视图”（可能在攻击范围外），啃基地的怪会朝远处路障侧身。改为面向实际攻击目标（正在啃的路障 `barricade_controller` > 基地） |
| R-12 | 射击像 Light 而不是 Muzzle | 枪口同时挂了 `LightingManager.request_flash`（PointLight2D 光斑），视觉盖过 muzzle 贴图；移除枪口光斑（光照架构保留给爆炸/昼夜 M5），`player.tscn` 与运行时统一为 `muzzle_02.png`，枪口焰调整为 41px→20px 星芒 |

### M4.2 键位/配置说明

- 改键位直接作用于 GUIDE（无需重启）；配置保存在 `user://input_bindings.json`。
- 改 `config.cfg` 需要重启游戏生效；`camera_zoom` 钳制在 0.5~2.0（保证 Camera2D limit 不露背景）。
- `run-dual*.ps1` 的 `-RelayUrl/-AppId` 参数仍可临时覆盖 config.cfg。
