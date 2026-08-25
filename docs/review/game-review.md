# Bulwark「前线壁垒」游戏性 / 内容综合评审

> 评审对象：Godot 4.7 (mono) GDScript 项目 `Bulwark 前线壁垒`（俯视波次防守射击）
> 评审日期：2026-08-25
> 评审范围：游戏内容与时长、代码性能、美术素材与风格一致性、游戏感 / 玩家体验
> 评审方法：静态代码 / 资源 / 设计文档审查为主（含 headless 冒烟与 GUT 回归可复核）；**未进行真人完整试玩与真机性能采样**，涉及手感 / 帧率的结论为“代码级证据 + 建议实测”，不冒充实测结论。
> 结论口径：本文不修改任何游戏代码，仅产出评审文档与新内容方案。

---

## 0. 结论摘要（TL;DR）

| 维度 | 评价 | 关键问题 |
|---|---|---|
| 内容 / 时长 | **偏少，单局明显短** | 实为“6 波单链 + 波间商店”，无章节 / 搜索 / meta / Boss 机制；单局估计 **4–8 分钟**，距 GDD 15–30 分钟目标差距大；波次构成与商店刷新**种子固定**，每局内容几乎无随机性 |
| 代码性能 | **结构尚可，热路径有优化空间** | 敌人每帧全量扫描路障 O(E×B)、炮塔目标表每帧重建、命中判定每次开火重建目标数组、特效冲击环未池化、`Bulwark.loc()` 高频字符串化；`GameSession` 2020 行“上帝对象” |
| 美术一致性 | **存在明显混搭，且有交付风险** | Kenney 像素角色 + 扁平矢量 UI + 自定义 SVG 炮塔 + 512px 软粒子残留（枪口 / 基地烟雾 / 动态光）；炮塔素材仍引用被 `.gitignore` 忽略的 `temp_assets/`；9 种敌人共用同一张僵尸贴图，仅染色缩放 |
| 游戏感 / 体验 | **基础反馈扎实，但信息与差异化不足** | 后坐 / 震屏 / 受击闪白 / 死亡爆点做得不错；但**无伤害数字 / 命中标记 / 方向雷达**，音频武器分支存在死代码（手枪、霰弹枪永远用冲锋枪音效），无手柄辅助瞄准、无灵敏度 / 震屏开关、无难度与教学 |

一句话：**玩起来是一个完成度不错但内容偏薄、随机性不足的“垂直切片”**；它把 3C、手感反馈、网络权威模型等底层做好了，最缺的是把 GDD 的“肉鸽章节 + 搜索 + meta”拉回主线，并做一次风格收口与热路径优化。

---

## 1. 游戏内容 / 游戏时长

### 1.1 内容盘点（已检出的实际体量）

| 类别 | 数量 | 事实依据 |
|---|---|---|
| 波次 | **6 波单链，最后一波为精英波** | `scripts/core/registry/bulwark.gd` `WAVE_IDS`；`resources/waves/wave_1..6.tres` |
| 敌人类型 | **注册 9 种**：奔跑者 / 疾行者 / 硬壳者 / 自爆体 / 喷吐者 / 装甲兽 / 飞行体 / 狙击手 / 精英·巨兽 | `scripts/systems/content_bootstrap.gd` `register_enemies()`；`Bulwark.ENEMY_*` |
| 武器 | **5 类 × 16 型号**（AR3 + SG3 + HG4 + LMG3 + ER3） | `resources/weapons/type/`、`resources/weapons/model/` |
| 配件 | **4 种**（红点 / 扩容弹匣 / 制退器 / 轻量枪托） | `resources/attachments/`、`Bulwark.ATTACHMENT_*` |
| 商店商品 | **35 个注册项**（23 常规 + 12 武器箱；固定物资 3） | `Bulwark.SHOP_ITEM_IDS_INCLUDING_CRATES`、`resources/shop/items/` |
| 防线设施 | **2 种**（弧形路障、自动炮塔） | `Bulwark.FACILITY_*`、`resources/facilities/` |
| 单局内容路径 | 固定开成（AR1 + SG1 + HG1 + HG4）；商店刷新 4 随机 + 2 固定轮换；无搜刮 / 无地图事件 / 无章节间选择 | `scripts/systems/game_session.gd` `_setup_backend_host()`、`scripts/core/economy/shop_system.gd` |

### 1.2 单局时长估算（静态推算）

以波次模板 + 刷怪间隔 + 敌人移速（900px 刷怪半径 / 45~160 px/s）推算：

| 波 | 预估敌人总数 | 刷怪阶段（约） | 说明 |
|---|---|---|---|
| 1 | 15–21 | ~16–21s | 仅奔跑者，1.0s 间隔 |
| 2 | 28–40 | ~22–32s | 奔跑者 + 疾行者，0.8s 间隔 |
| 3 | 23–33 | ~16–23s | 引入喷吐者 / 自爆体，0.7s |
| 4 | 28–38 | ~20–27s | 疾行者 / 装甲兽 / 喷吐者，0.7s |
| 5 | 20–28 | ~13–18s | 飞行体 / 狙击手 / 硬壳者，0.65s |
| 6 | 9–12 | ~6–8s | 精英·巨兽 + 强化小怪 |

- 合计敌人约 **123–172 只**；纯战斗（刷怪 + 接敌 + 清场）约 **2.5–4.5 分钟**。
- 加 6 次预警（~20s）、5 次波间窗口（5s + 商店决策 0.5–2 分钟），**常规一局约 4–8 分钟**；商店反复斟酌可到 8–10 分钟。
- 与 GDD `docs/design/game-design-doc.md` P4 目标 **15–30 分钟** 差距明显。差异根源：GDD 的“4–6 章 × 每章 3–4 波”（P21）与“搜索–战斗循环”（§11）在当前版本均未落地，实际只有 1 章 6 波。

### 1.3 内容缺口（对照 GDD / 设计决策）

1. **无章节制**：GDD P18/P21 为“章节制肉鸽（每章 3~4 波 + 关底，一局 4~6 章）”，实现为单链 6 波。
2. **无搜索–战斗循环**：GDD §4/§11 的核心支柱“出基地搜刮 vs 回防”完全缺失；当前核心循环 = 守基地 → 商店 → 下一波。
3. **无 meta 成长**：GDD P16“有 meta 成长（局间货币永久解锁）”未实现；结算面板只显示本局统计（`scenes/ui/result_panel.gd`）。
4. **无主动/被动数值成长多样性**：技能系统已按 `docs/design/design-cut-and-gamefeel.md` 整体裁剪；玩家成长仅剩商店数值强化 + 配件 + 武器箱，深度受限。
5. **无 Boss 机制**：精英·巨兽只有“背部弱点 ×2”机制（`EnemyData.has_weak_point`），无阶段、召唤、硬直破甲；GDD P14 预留的 Boss 系统未实现。
6. **无叙事 / 世界表达**：GDD P28/P29 设定“非正经军人的荒诞感 + 便签/涂鸦叙事”，当前几乎无任何故事文本（主菜单副标题仅为 `FRONTLINE BULWARK`）。
7. **无难度选择 / 教学**：设置面板仅音频、键位、语言（`scenes/ui/settings_panel.gd`），无难度、无操作说明页。
8. **内容随机性不足（重要）**：
   - `resources/waves/*.tres` 的 `seed` 固定（101/202/…/606），`WaveGenerator.generate()` 同种子同构成 → **每局敌人组合完全一致**；
   - 商店刷新种子固定为 `wave_index * 1000 + 7`（`game_session.gd` `_on_wave_cleared()`） → **每局上架商品也基本一致**；
   - 仅刷怪落点带全局 `randf` 抖动（`_on_spawn_request()`），不能改变构成与节奏。
   - 结果：**重复游玩时“肉鸽感”很弱**——玩家能体验到差异的只有购买选择 / 操作发挥，而开局阵容与波次构成没有变化。

### 1.4 内容改进建议（按性价比排序）

| 优先级 | 建议 | 预期收益 |
|---|---|---|
| P0 | **引入“本局随机种子”**：开局 `randomize()` 或 UI “重开/种子号”，`WaveDirector` 与 `ShopSystem` 改用该种子（或把波次种子的常量改为可注入 run seed）。改动小、测试已有 SeededRNG 基建 | 立刻解决“每局一样”，复玩价值大幅提升 |
| P0 | **加入方向雷达 / 罗盘**：HUD 增加 N/E/S/W + 斜向的来访方向指示（轻量 `TextureRect` 或文本箭头） | 直接支撑“多方位压力管理”核心支柱，弥补 M5d 移除逐方向箭头后的可读性空白 |
| P1 | **落 1 个最小 meta 层**：结算发放“徽章/点券”，在主菜单解锁起始武器/难度层/角色外观 | 建立“输了也有成长”，把单局 4 分钟变成可重复游玩产品 |
| P1 | **回补“探索/风险收益”一个轻量版本**：每波间限时出基地搜寻 1~2 个补给点（战斗触发） | 补齐 GDD 核心循环的“呼吸感”与攻守转换 |
| P1 | **扩展为 2~3 章**（或无尽波模式）：第 2 章换敌人组合/方位偏好 + 更强精英 | 单局时长向 15 分钟靠拢，且给商店/构筑更多展示空间 |
| P2 | 叙事便签 / 物品描述、教程关卡、难度档位、图鉴 | 内容厚度与商业完成度 |

---

## 2. 代码性能

### 2.1 热路径扫描（代码级证据）

1. **敌人每帧全量扫描路障（O(E×B)，最主要热点）**
   - `scenes/enemy/enemy_view.gd` `_physics_process()` 每帧：
     - `_should_target_barricades()` → `_find_nearest_live_barricade()`（遍历 `barricade_query.call()` 返回的全部路障，`distance_squared_to` 逐项比较，行 306–321）；
     - 即使只有少数路障，每个敌人每帧都执行一遍。中期同屏 30+ 敌人 × 10+ 路障 ≈ 300+ 距离运算/帧，且随双方数量线性增长。
2. **炮塔目标表每帧重建**
   - `scripts/systems/game_session.gd` `_tick_turrets()`（行 1046–1061）：只要有炮塔，每物理帧遍历 `enemies_root.get_children()` 并为每个存活敌人**新建字典** `{net_id, pos, radius, alive}`；随后 `TurretController._acquire_target()` 又为每个候选目标调用 `HitscanResolver.resolve_hit()` 并**每次新建单元素字典数组**（`scripts/core/base/turret_controller.gd` 行 42–65）。
   - 结果：T 台炮塔 × E 只敌人 = 每帧 T×E 次字典分配 + 线段判定，属可避免的 GC/CPU 压力。
3. **命中裁决每次开火重建目标数组 + 每次开火重算武器数值**
   - `game_session.gd` `_on_shot_fired()`（行 1376–1442）每次开火都遍历全部敌人建 `target_enemies` + `targets` 两个数组，再按弹丸数逐个 `HitscanResolver.resolve_hit()`；
   - `WeaponSlots.try_fire()`（`scripts/core/combat/weapon_slots.gd` 行 249–270）每次开火 `get_effective_stats()` 一次，`GameSession` 再次 `get_effective_stats()` 一次 → 每发子弹构造 **2 个 `WeaponStats`**；
   - LMG（14 发/s）+ 霰弹（10 弹丸）双人时，开火路径分配显著：每发 2×WeaponStats + pellets 次数组迭代 + hitscan 结果字典。
4. **像素冲击环未池化**
   - `scripts/systems/fx_burst.gd` `spawn_impact_ring()` 每次 `PixelRing.new()` 入树（行 112–118）；`scenes/vfx/pixel_ring.gd` 每帧 `queue_redraw()` + `_process()`，播完 `queue_free()`。
   - 群杀 / 霰弹 / 自爆波次会瞬时创建大量短命 `Node2D`，虽单个开销小，但**无上限、无池化**；与“FxBurst 火花池（32 个）只借不建”的既定纪律不一致。
5. **`Bulwark.loc()` 高频字符串化**
   - `Bulwark.loc()` 每次 `ResourceLocation.new()`，`to_string()` 每次拼接字符串；热路径（每发子弹事件、每次敌人快照、每次路障/炮塔路由、商店查找）反复调用。建议为常量位置做缓存或直接比较 `ResourceLocation`。
6. **网络快照分配（可控但可再压）**
   - host 每 50ms 全量玩家快照 + 每 100ms 全量敌人快照（`game_session.gd` 行 1292–1352），每次重建嵌套字典；20/10Hz 下可接受，但敌人数量上升时带宽/序列化成本随 O(E) 增长，且**无 AOI / 增量快照**（架构文档 §9 预留 M6）。
7. **设计承诺未落地**
   - `docs/design/architecture-design.md` 提到“同屏敌人预算上限（WaveDirector 控制）、导航预算（分帧寻路）、AOI 剔除”；实际 `WaveDirector` **无同屏/总刷怪上限控制**，导航为每帧 `get_next_path_position()`，无分帧。
   - `scripts/core/wave/difficulty_curve.gd` 已实现但**无任何调用**（grep 仅命中定义行）——原计划用于动态难度/人数缩放的“一张表”仍闲置。

### 2.2 架构 / 可维护性

- `scripts/systems/game_session.gd` 共 **2020 行**，同时承载：后端装配（离线/host/client 双分支）、事件订阅与中继、快照编解码、路障/炮塔放置修复、商店效果裁决、胜负/暂停、冒烟脚本。虽然“core 纯逻辑 / 表现层只读”的总体分层是干净的，但装配层已膨胀成“上帝对象”，新增功能极易再次堆叠。
- 遗留/死代码：
  - `WeaponTypeData.BallisticMode`（HITSCAN/PROJECTILE/SPREAD/…）定义了 8 种弹道，但**除 HITSCAN + pellets 外从未被结算逻辑读取**（grep 仅命中枚举/字段声明）——能量步枪 `ballistic=5(CHARGE)`、霰弹 `SPREAD` 都只是标签，实际手感差异主要靠射速/散布/弹丸数。
  - `EnemyData.ThreatMode.AMBUSHER`（潜伏者）未注册、无数据；`EnemyData.aura_strength` 留位。
  - 空文件 `resources/shop/items/shop_c`（0 字节）为仓库杂物，应删除。

### 2.3 性能改进建议

| 优先级 | 建议 | 说明 |
|---|---|---|
| P0 | **敌人 → 路障近邻缓存**：每波/每帧由 GameSession 维护“存活路障数组”，敌人仅做索引/少量空间哈希；或把“最近路障”按方向段缓存，放置/摧毁时失效 | 消灭 O(E×B) 全扫描 |
| P0 | **炮塔目标表复用**：`_tick_turrets()` 只收集一次 `Array[EnemyView]`，传引用而非每帧新建字典；`TurretController` 直接吃 `EnemyView` 或预填充的轻量结构 | 消灭每帧 T×E 字典 |
| P1 | **命中空间查询**：开火时用圆形网格/简单分桶（或按方向预筛），避免每发遍历全部敌人；`WeaponStats` 增加 dirty 缓存（槽位/配件/强化变化时重算一次） | 高射速 + 霰弹直接收益 |
| P1 | **池化 PixelRing / 弹体尾部**：可复用小节点池，或改为单根 `Line2D` + 时间驱动统一绘制 | 减少瞬时节点/重绘 |
| P1 | 将 `GameSession` 拆分：`SessionBackend`（纯逻辑驱动）/ `SessionNetSync`（快照/中继）/ `SessionFacilities`（路障炮塔）等 | 可维护性，长期收益 |
| P2 | 同屏敌人预算 + 导航分帧/降低刷新频率；`Bulwark.loc` 缓存；快照增量/AOI | 大后期 / 真机验证后 |
| — | **先实测再优化**：跑 profiler（低/中/高波 + 霰弹 + 多炮塔 + 双人），以 CPU 时间/帧率数据为准，避免臆测性优化 | 本文为静态线索，需实测闭环 |

---

## 3. 美术素材 / 美术风格一致性

### 3.1 当前素材构成

| 层 | 素材 | 风格 |
|---|---|---|
| 角色（玩家/敌人） | `assets/sprites/chars/`：soldier1 / manBlue / zoimbie1（Kenney Top-Down Shooter PNG） | 32px 级像素风，`project.godot` 默认纹理过滤 = Nearest |
| 地面/基地 | `assets/sprites/tiles/tile_01/05/105/214.png`（Kenney 瓦片） | 像素风；地面为 `Polygon2D` 纹理平铺 |
| 炮塔 | `res://temp_assets/turret/turret_base.svg`、`turret_barrel.svg`、`turret_flash.svg` | **自定义矢量**，与像素世界不同源 |
| 粒子/VFX | `FxBurst` 运行时 8px 像素方块 + `PixelRing` 程序化绘制（**已统一为像素语言**）；但 `player_view.gd` 枪口仍用 `assets/particles/muzzle_02.png`（注释明确 512px 星芒焰），基地用 `smoke_06.png`/`light_03.png`，动态光用 `light_01.png` | 像素 VFX 与 **512px 软粒子残留**混用 |
| UI | `assets/theme/minimal_vector.tres`（StyleBoxFlat 圆角深海军蓝/钢蓝/琥珀）+ MiSans-Semibold + `UiPalette` | 现代扁平矢量 |
| 图标 | `assets/icons/`（110 个单色 SVG） | **基本未接入**（grep `assets/icons` 仅命中 AGENTS.md 与旧评审文档） |

### 3.2 一致性问题

1. **世界与 UI 双风格**：世界是 Kenney 像素角色 + 像素瓦片，HUD/商店/主菜单是圆角扁平矢量卡片。扁平矢量作为 HUD 层可以成立，但炮塔 SVG（矢量）与角色（像素）同屏时风格割裂最明显。
2. **炮塔临时素材引用 + 交付风险**：
   - `scenes/base/turret.tscn` 与 `scenes/vfx/turret_tracer.gd` 直接引用 `res://temp_assets/turret/*.svg`；
   - `.gitignore` 第 33 行 **`temp_assets/` 不入库**（仅本地解压源包）→ 若仓库克隆/导出，炮塔可能**缺纹理**。即使本地可玩，也属“未定稿占位素材”依赖（`docs/design/bug-handoff.md` 已注明占位，待正式素材替换）。
3. **高清软粒子残留**：`design-cut-and-gamefeel.md` §4 的纪律是“不继续使用 512px 高清软粒子贴图，统一 8px 像素”，但枪口焰（`muzzle_02.png`）、基地烟雾/核心光（`smoke_06.png`/`light_03.png`）、动态光（`light_01.png`）仍为高解析软贴图——同一帧里既有像素方块命中特效又有柔光枪口焰，观感不统一。
4. **敌人可读性差**：9 种敌人全部使用同一张 `zoimbie1_stand.png`，仅 `body_color` 染色 + `visual_scale` 缩放（`enemy_view.gd` `_apply_visual()`）；装甲兽 / 狙击手 / 飞行体 / 精英在轮廓上没有区分，远距离难以一眼分辨威胁类型。
5. **资源冗余**：
   - `assets/icons/` 110 个 SVG 基本未使用；
   - `assets/particles/` 约 20 张贴图仅用到少数（muzzle_02 / smoke_06 / light_03 / light_01 / dirt_01 等）；
   - `temp_assets/` 存放整套 Kenney 源包与 `topdownTanks_vector.svg`（未使用），本地体积/导入时间膨胀；虽被 gitignore，仍拖慢首次导入与编辑器资源扫描。
6. **文档与实现token不一致**：`docs/design/m5-visual-qa-checklist.md` 仍写“背景 `#0B0F0D`、边框橄榄黄 `#AD9A40`、交互青绿 `#3FBFAD`”等旧令牌，而当前 `UiPalette` 已改为深海军蓝 × 钢蓝 × 琥珀（`design-cut-and-gamefeel.md` §8）——清单未同步，后续视觉评审会误判。

### 3.3 风格统一建议

1. **定调（二选一，建议先定后做）**：
   - A. **像素优先**（推荐）：保留 Kenney 角色/瓦片，把炮塔改成像素 Sprite（或移植 Kenney 坦克矢量 → 低分辨率位图），枪口/基地/灯光全部换成 `FxBurst` 同款 8px 像素纹理；UI 保持扁平矢量作为 HUD 层（像素 + 矢量 HUD 是常见且成立的组合）。
   - B. **矢量优先**：整体转向 GDD P6“扁平矢量 + 描边卡通”，需要重绘/替换 Kenney 角色与瓦片，成本高，目前不现实。
2. **把使用中的 `temp_assets/turret/*.svg` 迁移到 `assets/` 并取消 gitignore 影响**（或确认已纳入提交后再使用）；正式素材替换后删除临时依赖。
3. **敌人差异化**：至少给 4 类威胁（远程 / 装甲 / 飞行 / 精英）提供不同轮廓或部件（盾、翅膀、体型轮廓、发光弱点标记），染色只作为辅助。
4. **删除/归档未用素材**：110 图标、未用粒子、`topdownTanks_vector.svg`、`shop_c` 空文件；减少仓库体积与导入时间。
5. **同步视觉 QA 清单**：以当前 `UiPalette` 为唯一事实源，修正 `m5-visual-qa-checklist.md`。

---

## 4. 游戏感 / 玩家体验感

### 4.1 做得好的部分（保留）

- **射击手感链路完整**：方向性后坐角弹簧恢复、连射热度扩散（`PlayerController.HEAT_*`）、枪口回退 tween、方向化相机震动（`player_view.gd`）。
- **受击/死亡反馈分层**：敌人受击闪白 + 1.15 倍缩放重击 + 3px 视觉击退；死亡先 1.35 倍爆点再淡出 + 像素粒子 + 冲击环 + 动态光（`enemy_view.gd`）。
- **弹体表现**：敌方弹体出膛 0.5→1.0 BACK 脉冲 + 加速入弯 + 双层像素短尾 + 抵达爆点（`enemy_projectile.gd`）——时序符合 “anticipation → impact → aftermath”。
- **池化与性能纪律**：玩家 tracer 用 `ObjectPool`；FxBurst 火花固定 32 池；动态光 `LightingManager` 上限 8 个 `PointLight2D`；client 镜像死亡粒子减半。
- **网络手感**：快照双缓冲线性插值 + 本地预测校正阈值（80px），避免橡皮筋感；敌人 10Hz 独立通道 + 位置去重。
- **音频/输入辅助**：`AudioDirector` 音乐状态机（战斗/波间/菜单）、换弹进度准星（`CursorStateMachine`）、按键可重绑定、双语 i18n 即时切换。
- **节奏**：波前预警横幅、波间商店暂停、全员同意暂停——流程反馈是清晰的。

### 4.2 发现的问题

1. **武器音效分支是死代码（明确的 Bug）**
   - `scripts/systems/audio_director.gd` `_on_shot_fired()`：
     ```gdscript
     if model != null and model.type_id.ends_with("pistol"):
         stream = load(SFX_PATH % "handgun_shoot")
     elif model != null and model.type_id.ends_with("shotgun"):
         pitch = _rng.randf_range(0.75, 0.85)
     ```
   - 但 `type_id` 实际为 `"weapon/type/hg"`、`"weapon/type/sg"`（见 `resources/weapons/type/type_hg.tres`、`type_sg.tres`），**永远不命中**：手枪没有手枪音效、霰弹没有降调爆响，全部武器都播 `smg_shoot`。LMG/ER 也无独立音色。
2. **缺少方向/压力可视化**
   - M5d 已移除逐方向箭头（`hud.gd` 只显示“数量档 + 精英”文字，`docs/design/m5-visual-qa-checklist.md` 也确认“无箭头/逐方向”），但**没有雷达/小地图/常驻方位指示**。敌人从屏幕外接近时，玩家不知道主压力方向——直接削弱「多方位压力管理」这一 GDD 核心支柱。
3. **无伤害数字 / 命中标记 / 击杀反馈差异化**
   - 全项目 grep 无 `damage_number` / `hitmarker`；击杀只播通用 `mob_die` 音效 + 死亡粒子。高射速下“打没打中”反馈主要靠受击闪白与粒子，暴击/弱点命中（精英 ×2、装甲正面减伤）**没有专门视觉或音效**，策略性机位难以形成正循环。
4. **无手柄/辅助配置**
   - GDD P8/P9 提到手柄适配与“手柄轻辅助瞄准”；grep 无 joypad 设备检测、无瞄准辅助代码；设置面板也无鼠标灵敏度、镜头缩放、震屏开关。桌面鼠标手感目前是唯一通路，且灵敏度不可调。
5. **缺少上手引导**
   - 主菜单没有“玩法说明/操作说明”；进入战斗仅 HUD 默认“操作提示”（`hud.controls_hint`）与设施提示，无教学波次或图例（例如：路障挡怪、炮塔自动索敌、弱点打背、装甲打侧/背）。
6. **波间决策信息有限**
   - 商店卡片只有名称/描述/价格；“当前构筑收益”“已购次数”“下一波压力”的关联提示弱；武器箱存在“已拥有过滤”，但 HUD/商店没有军械库进度概览（图鉴式收集感缺失）。

### 4.3 游戏感改进建议

| 优先级 | 建议 |
|---|---|
| P0 | 修复 `AudioDirector` 类型匹配：按 `type_id` 前缀/枚举匹配 `hg`/`sg`/`lmg`/`er`，并补 1~2 个武器音色（或至少让霰弹/重武器明显区分） |
| P0 | 增加**方向压力 UI**：波次预警恢复方向箭头/罗盘，战斗中显示敌人相对基地的方位点（轻量 HUD 图标即可） |
| P1 | **命中/暴击/弱点反馈**：命中标记（十字闪烁）、暴击/弱点加色、伤害数字（可选，小字号浮动）；装甲正面攻击给“无效/减免”反馈音效与视觉 |
| P1 | 设置项：鼠标灵敏度、镜头缩放（当前仅 `config.cfg camera_zoom`）、震屏开关/强度、手柄辅助瞄准开关 |
| P1 | 初始波引导：第 1 波只出奔跑者并叠加简短操作提示（已有波次流程，成本低） |
| P2 | 商店“构筑概览”（当前武器/配件/全局强化汇总）；结算增加“本局构筑”回顾与下一局可解锁预览 |
| P2 | 面板动效（进出场 250ms，QA 清单未达标项）、击杀连击/波次评分等纯兴奋点 |

---

## 5. 建议优先级路线图

| 优先级 | 内容 | 涉及面 |
|---|---|---|
| **P0（本周可做）** | ① 本局随机种子（波次 + 商店）；② 方向雷达/罗盘 HUD；③ 修复武器音效分支；④ 炮塔素材移出 `temp_assets`（或确认提交）；⑤ 删除 `shop_c` 空文件 | 内容 × 游戏感 × 交付 |
| **P1（2–4 周）** | ⑥ 敌人→路障近邻缓存 + 炮塔目标表复用 + WeaponStats 缓存；⑦ 敌人差异化轮廓（4~6 个新 sprite）；⑧ 命中/暴击/弱点反馈 + 设置补充；⑨ 最小 meta（结算货币 + 解锁树）；⑩ 轻量探索点 | 性能 × 美术 × 游戏感 × 内容 |
| **P2（后续版本）** | 第二/三章节或无尽模式、Boss 机制、叙事便签、难度档、教学关卡、面板动效、资产清理（110 图标/未用粒子/源包）、GDD/QA 文档同步 | 内容厚度与完成度 |

---

## 6. 证据与验证

### 6.1 主要证据文件

- 内容：`scripts/core/registry/bulwark.gd`、`scripts/systems/content_bootstrap.gd`、`resources/waves/*.tres`、`resources/enemies/`、`resources/weapons/`、`resources/shop/items/`、`resources/facilities/`
- 代码性能：`scripts/systems/game_session.gd`、`scenes/enemy/enemy_view.gd`、`scripts/core/base/turret_controller.gd`、`scripts/systems/fx_burst.gd`、`scenes/vfx/pixel_ring.gd`、`scripts/core/combat/weapon_slots.gd`
- 美术：`scenes/base/turret.tscn`、`scenes/vfx/turret_tracer.gd`、`scenes/base/base.tscn`、`scenes/player/player.tscn`、`scripts/systems/fx_burst.gd`、`scripts/systems/ui_palette.gd`、`assets/theme/minimal_vector.tres`
- 游戏感：`scripts/systems/audio_director.gd`、`scenes/player/player_view.gd`、`scenes/enemy/enemy_view.gd`、`scenes/ui/hud.gd`、`scripts/systems/cursor_state_machine.gd`
- 设计基准：`docs/design/game-design-doc.md`、`docs/design/design-cut-and-gamefeel.md`、`docs/design/architecture-design.md`、`docs/design/m5-visual-qa-checklist.md`、`docs/design/bug-handoff.md`

### 6.2 本次验证结果（2026-08-26 实测）

| 验证项 | 命令 | 结果 |
|---|---|---|
| headless 项目冒烟 | `godot --headless --path . --quit-after 60` | **exit 0**；主菜单正常加载，zh/en 各 264 条翻译装载；无游戏脚本错误（仅沙箱环境的 `user://` 日志/输入绑定写入告警，非项目缺陷） |
| GUT 全量回归 | `godot --headless -s addons/gut/gut_cmdln.gd --path .` | **285/285 通过**（42 个测试脚本，exit 0）；输入绑定/设置保存用例需写 `user://`，在完整访问权限下通过 |
| 历史基线（引用） | `docs/design/design-cut-and-gamefeel.md` §5 | 记载 GUT 283/283、i18n 264/264、headless 冒烟无脚本错误；现测试集已增至 285 项 |

补充事实核验（命令行）：

- `docs/review/game-review.md`：存在、非空（25,821 字节），UTF-8。
- `scripts/systems/game_session.gd`：`wc -l` = **2020 行**（与本文引用一致）。
- `resources/shop/items/*.tres` = **35 个**（与“35 个注册项”一致）。
- `assets/icons/**/*.svg` = **110 个**（与“110 个未接入图标”一致）。
- `git ls-files temp_assets/turret/*` = **空**，`git check-ignore temp_assets/turret/turret_base.svg` 命中 → 证实炮塔素材**未被 git 跟踪且被忽略**，即“fresh clone 可能缺炮塔纹理”的交付风险成立。
- 真机 profiler / 真人试玩：**未执行**（静态审查结论，需后续实测补充帧率数据）。

---

> 说明：本评审 `docs/review/game-review.md` 为后续内容/性能/美术/手感迭代的输入文档；优先执行 P0 项即可显著改善“可重复游玩性”与“核心支柱可读性”。
