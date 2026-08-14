# 《前线壁垒》技术架构设计文档 v0.6

> 状态：**初稿** · 版本：v0.6（Modding 分层 + 无 PvP/禁队友伤害 + 弱点命中） · 日期：2025 年
> 关联文档：`game-design-doc.md`（策划案 v0.6，本文档是其 §14 的落地细化）。
> 技术栈：Godot 4.7 (mono)，GDScript 为主，必要时 C#；插件：mc_game_framework（EventBus/UIManager/Registry/Codec/I18N）、guide（输入）、sound_manager（音频）、gut（测试）。

---

## 1. 架构目标与设计原则

### 1.1 架构目标

1. **单人 / 多人双轨同构**：单机 = 本机 host + 本机客户端，与联机走同一套权威路径（已定 P2 同时设计）。
2. **数据驱动内容扩展**：武器、敌人、升级、波次、设施全部 Resource 化，新增内容零代码。
3. **前后端分离（渲染 / 逻辑解耦，硬性）**：领域逻辑（后端）不引用任何场景节点、材质、Sprite 等渲染对象；表现层（前端）只读后端状态做展示、只发意图命令。headless 可测、网络可复用、UI 可换肤。
4. **Registry + ResourceLocation 硬性约束（M0 起生效）**：所有内容（含 M0 的武器/敌人/波次）一律经 Registry 注册、`ResourceLocation(namespace:id)` 标识——官方与 Mod 同构，Mod 前置从第一天落实。
5. **技能集可裁剪**：技能 = 通用 Framework + 可复用 Action 原子，技能集增减只增删数据（§16 策划案裁剪流程的落地）。

### 1.2 设计原则（源自 game-architect 参考）

| 原则 | 落地 |
|---|---|
| 需求驱动、迭代演进 | 每里程碑（M0~M7）只做当前需求所需的最小架构，演进式加层 |
| 水平分层 + 垂直模块化 | 表现层 / 领域层 / 基础设施三层；按系统垂直切模块 |
| 范式混合 | **DDD**：战斗、伤害、AI、基地（规则复杂实体）· **数据驱动**：武器、波次、商店、meta（内容/流程/经济） |
| 预留变化点 | 关底实体可替换（精英波 → Boss）、无尽模式（未来扩展）；**PvP 明确不做**（已定 P30） |
| 测试友好 | 领域逻辑可 headless 运行，GUT 覆盖公式/生成/经济 |

### 1.3 通信规则（前后端分离，M0 起硬性执行）

**后端（逻辑 / 权威）** = 领域模块：纯 RefCounted / 逻辑 Node（不挂渲染子节点），状态可序列化，headless 可跑、host 可跑。
**前端（渲染 / 表现）** = 场景节点、UI、VFX、音频：只读后端状态做展示，经视图绑定层驱动。

- 领域模块间用 **EventBus**（mc_game_framework）解耦；表现订阅事件渲染。
- 前端 → 后端 = **意图命令**（多人下即 RPC 意图，见 §4.11）；后端校验并执行。
- 后端 → 前端 = **状态快照 / 事件 + Cue**（非关键表现提示）。
- **禁止（硬性）**：后端代码 `get_node` 场景节点、引用材质 / Sprite / 动画、直接读写 UI；前端代码直接修改后端数值（只能发意图）。
- **验证手段**：GUT 在无场景环境下实例化后端逻辑（§7）；M0 起代码评审以此为准。

---

## 2. 宏观架构（分层与模块）

### 2.1 分层

```
┌─ 前端（渲染/表现）：scenes/（player/enemy/base/world/ui 场景）、VFX、音频播放、HUD
│     只读后端状态 + 意图命令；视图绑定层（view_models/）驱动渲染
├─ 后端（逻辑/权威）：scripts/core/（战斗、技能、AI、波次、基地、经济、多人）
│     纯逻辑、无场景节点依赖；headless 可跑、host 可跑
└─ 基础设施：插件（mc_game_framework、guide、sound_manager、gut）
             + scripts/framework/（对象池、ServiceLocator、种子随机）
```

### 2.2 模块清单

| 模块 | 职责 | 多人权威方 | 关键依赖 |
|---|---|---|---|
| Player3C | 移动/状态机/受击/复活 | host（意图 RPC + 验证） | guide 输入、Attribute |
| Combat-Weapon | 三槽位、切换 CD、弹药、开火 | host | WeaponType/ModelData、Projectile |
| Combat-Projectile | 弹道池化、命中、弹道模式 | host | 碰撞层、伤害管道 |
| SkillSystem | 技能执行生命周期、槽位 | host | SkillData、Action 原子 |
| Attribute/Damage | 属性修正、伤害管道、Buff/标签 | host | EventBus |
| EnemyAI | 寻路、行为 FSM | host | NavigationAgent2D、WaveDirector |
| WaveDirector | 波次构成生成、刷怪、强度缩放 | host | Wave/ChapterData、种子 PCG |
| BaseDefense | 基地耐久、设施建造/修复 | host | FacilityData、Economy |
| Economy/Shop | 资源、商店（随机+固定）、价格 | host | ShopData、RunState |
| Revive | 应急储备、复活流程、失败判定 | host | RunState |
| Search/Loot | 搜索点、掉落、时间压力 | host | LootTableData、WaveTimer |
| Meta | 局外货币、解锁清单、存档 | host（meta 持久化） | Save |
| Multiplayer | 会话、RPC、状态同步、预测插值 | —（基础设施） | MultiplayerAPI (ENet) |
| HUD/UI | 数据绑定、面板 | client（纯表现） | UIManager |
| Audio | 音乐/音效/环境 | client | sound_manager |
| Input | 动作映射、上下文 | client（意图采集） | guide |
| Modding | mods 扫描/加载/内容注入/一致性校验（M6+，架构从 M1 起预留） | host（Mod 集校验） | GodotModLoader、Registry |

### 2.3 单例（Autoload）规划（初稿）

`RunState`（当局状态：资源/章节/波次/构筑）、`WaveDirector`、`ShopSystem`、`MetaProgress`、`EventBus`（插件）、`UIManager`（插件）、`Guide`（插件）、`SoundManager`（插件）、`Net`（多人会话，单机时也挂载以保持同构）。

---

## 3. 目录结构落地

```
project/
├─ scenes/            # 场景（按模块子目录）
│  ├─ player/  enemy/  base/  world/  ui/  vfx/
├─ scripts/
│  ├─ core/           # 领域逻辑（player/combat/skill/enemy/wave/base/economy/revive/meta）
│  ├─ systems/        # 服务（shop/search/net/hud）
│  ├─ framework/      # 工具（object_pool.gd、seeded_rng.gd、service_locator.gd）
│  └─ ui/             # UI 逻辑
├─ resources/         # 数据驱动配置
│  ├─ weapons/type/  weapons/model/
│  ├─ enemies/  waves/  chapters/  facilities/  shop/  upgrades/  loot/
│  ├─ meta/  skills/
├─ input/actions/     # guide 动作配置（*.tres，用 tools/generate_guide_context.gd 生成上下文）
├─ assets/            # fonts/ theme/ icons/ sfx/ art/
├─ tests/             # GUT 测试（unit/ 对应领域模块）
├─ mods/              # 运行时 Mod（zip 或目录；export 后自动创建）
├─ mods-dev/          # 开发期 Mod（编辑器直连调试，配合 ModLoader Dev Tool）
└─ docs/              # design/ technical/ progress/
```

---

## 4. 核心系统设计

### 4.1 玩家 3C（CharacterBody2D）

- **状态机**（FSM）：`Idle / Move / Shoot / Reload / SwitchWeapon / Dead / Revive`（参考 state-machine 技能）。
- **输入**：guide 动作——`move`（WASD/左摇杆）、`aim`（鼠标/右摇杆）、`shoot`、`switch_1/2/3`、`skill`、`interact`（搜刮/修复/建造）、`map`、`pause`。
- **瞄准**（已定 P9）：鼠标纯自由瞄准；手柄轻辅助（最近敌人微吸附，仅手柄输入生效）。
- **冲刺**不是基础动作，而是战术技能（护盾/冲刺等由技能系统提供，保持 3C 精简）。

### 4.2 武器系统（两级 Resource，已定 P10）

```
WeaponTypeData（类）：id、槽位类型（main/sub/pistol）、弹药类型、弹道模式、切换CD档（主副1.5s / 手枪0.3s）、手感参数
WeaponModelData（型号）：type_id、数值（伤害/射速/弹匣/换弹/散布/暴击）、词条列表（穿甲/燃烧弹/扩容…）
```

- **WeaponSlots**：3 槽（主/副/手枪）+ 切换状态机（含 CD 计时；"切换中是否可移动/被打断"待 P23）。
- **AmmoSystem**：弹药按类型独立计数（子弹/燃料/榴弹/能量）；手枪**无限备弹**（已定 P25）。
- **弹道执行**：`ProjectileFactory` 池化（参考 particles-vfx 的对象复用思路）；弹道模式枚举：`STRAIGHT / SPREAD(霰弹) / PARABOLA(榴弹) / PIERCE / CHARGE(蓄力) / BEAM(能量) / FLAME(喷火器) / HITSCAN(步枪)`。
- 开火流程：意图 → host 验证（弹药/冷却）→ 生成弹道 → 命中伤害管道 → 表现事件。

### 4.3 技能系统（Framework + Action，参考 system-skill）

- `SkillData`（Resource）：id、槽位、冷却/充能数、阶段时长（windup → cast → recover）、Actions 列表、UI 元数据。
- `SkillExecutor`：执行生命周期（可被打断规则）、冷却计时、充能管理；槽位 **1 个开局，图纸解锁第 2 槽**（已定 P12）。
- **Action 原子**（数据驱动，可组合复用）：
  `SpawnProjectile`（手雷/空袭落弹）/ `AoE`（空袭）/ `Buff`（护盾）/ `Heal`（医疗包）/ `Teleport-Dash`（冲刺）/ `Mark`（标记射击）。
- 技能集裁剪（策划案 §16）= 数据层删减 + 少量新 Action，架构不动。

### 4.4 属性与伤害管道

- `AttributeSet`：base + 修正列表，`final = (base + additive) × multiplicative`，缓存重算（商店/技能频繁改属性）。
- `Tags + Effects`：灼烧（DOT）、标记（增伤）、无敌帧等轻量状态（参考 system-skill §2）。
- **伤害管道**：`DamageContext(来源/武器/弹道/部位)` → **阵营过滤** → 攻击加成 → 暴击判定 → 防御减免 → 应用生命 → 广播 `OnDamageDealt / OnKilled`（吸血、词条、击杀特效挂在这里）。
- **阵营与友军过滤（硬性，已定 P30）**：阵营 = 玩家 / 异变体；**玩家阵营间伤害恒为 0**（禁止队友伤害）；AOE / 溅射 / 附带效果（灼烧、标记）判定时排除同阵营；弹道可穿透友军不结算。实现为伤害管道第一道闸（纯过滤，无反弹/惩罚机制）。
- **弱点命中（已定 P31）**：大型目标（精英/Boss）挂可选命中区（表现层 Area2D 子节点），命中时在 `DamageContext` 携带 `weak_point` 标记；倍率 / 硬直 / 破甲在后端伤害管道结算（弱点是数据标记，不是部位实体）。装甲兽的方向性护甲 = 攻击方向与朝向夹角判定（2 态），同样走管道内的护甲修正步骤。
- 敌人/玩家同用一套 Attribute + 伤害管道（多人群组无关，天然同构）。

### 4.5 敌人 AI

- **移动**：NavigationAgent2D，目标 = 基地（或进攻玩家）；飞行体走自定义直线/曲线路径（无视路障）。
- **行为 FSM**：按威胁模式数据驱动参数（移速/索敌范围/攻击间隔/弹道）：冲锋(近战) / 自爆(近战特攻) / 喷吐(弹幕) / 狙击(蓄力点名) / 飞行(绕后) / 装甲(高血)。
- **精英·巨兽**：光环（增益小怪）+ 高血量；关底波 = 1 只巨兽 + 同方位强化小怪潮 1.5×（已定 P27）。
- 敌人数量预算：同屏上限（如 60）由 WaveDirector 控制（风险见 §9）。

### 4.6 波次系统（WaveDirector）

- 数据：`ChapterData`（每章 3~4 波 + 关底精英波，已定 P21）+ `WaveTemplate`（构成模板）。
- **构成生成**：种子 PCG（构造法，参考 system-pcg §1）——由 `敌人组合 × 方位（N/E/S/W+斜向）× 强度（数量/等级）` 三元组生成，同种子可复现（利于测试与平衡调参）。
- **强度缩放**：按玩家人数系数（1人=1.0，2人≈1.6，3人≈2.1，4人≈2.5，初值待调）。
- **AI Director 调压预留**：当前固定曲线；后续可切为实时强度监控动态刷怪（接口预留，不实现）。

### 4.7 基地与防线

- `BaseCore`：耐久（host 权威）、失败判定（耐久归零 = 失败，已定 P7）。
- `DefenseFacilityData`（Resource）：类型（路障/自动炮塔/弹药补给点）、耐久、消耗资源、炮塔射程/伤害、补给量。
- 建造/修复流程：玩家交互意图 → host 验证资源 → 扣资源 → 放置/恢复 → 同步。

### 4.8 商店经济

- `ShopSystem`：每波结算刷新 **4 个随机商品 + 固定物资区**（已定 P22）。
- 价格：`base_price × rarity_coef × 1.3^(同商品购买次数)`（稀有度：普通/稀有/史诗/传说）。
- 随机池权重、固定物资解锁条件清单 → 数据表（P22 细节）。
- 资源（策划案 §9.3）：建材/弹药/能量/应急储备/局外货币——`RunState` 统一持有，host 权威。

### 4.9 搜索循环

- 搜索点（Resource）：类型（弹药箱/建材堆/武器残骸/情报终端/图纸）、风险圈层（近圈/远圈）。
- **时间压力**：全局 `WaveTimer` 倒计时，波前未回防 → 防线无防守接敌（策划案 §11）。
- 情报终端 = 提前揭示下一波构成（信息价值）；图纸 = 解锁第二技能槽（已定 P12）。

### 4.10 meta 系统

- `MetaProgress`：局外货币、解锁清单（武器种类/型号、技能、难度层、外观——已定 P16）。
- 结算：`RunResult`（章节进度/货币）→ 写入存档（ConfigFile/JSON，参考 save-load）。
- 解锁项 = Resource 清单 + 解锁条件（meta 货币消耗曲线待 P16 细节）。

### 4.11 多人（参考 multiplayer-overview）

- **权威模型**：host（房主即服务器）权威——战斗、经济、基地、AI、波次全部 host 裁决；client 只发**意图**（输入/交互 RPC），不信任客户端结果。
- **同步风格**：
  - 玩家移动/射击：client 预测 + host 校正（状态同步快照）；
  - 敌人/弹道/基地：host 权威快照同步 + client 插值；
  - 商店/meta：请求-响应（RPC，防作弊）；
  - 复活/资源：host 验证。
- **单机 = 同构**：单机时 Net 以 localhost 会话挂载，代码路径与联机一致（M2 里程碑验证）。
- 反作弊边界：客户端仅上报意图；伤害/资源/耐久结果一律 host 计算（multiplayer-overview §8）。

### 4.12 UI / HUD（UIManager + 数据绑定）

- 常驻 HUD：生命/护甲、当前武器弹药 + 三槽切换提示、技能冷却、**基地耐久条**、**波次预告（方位罗盘）**、波间商店面板、复活提示（应急储备余量）。
- 面板：商店（随机 4 + 固定区）、搜索点交互提示、章节结算、meta 主菜单。
- 数据绑定：领域状态 → UI 通过事件/绑定层（mc_game_framework UIManager），UI 不直接读节点状态。

### 4.13 音频（sound_manager）

- 音乐（章节氛围/战斗紧张度切换）、音效（射击/换弹/切换/命中/爆炸/怪物吼叫/UI）、环境（风/雨/基地运转音）。
- 事件驱动：领域广播 `sfx_request` 事件，音频模块播放（表现层职责）。

### 4.14 输入（guide）

- 动作清单见 §4.1；界面上下文（战斗/商店/菜单）用 MappingContext 切换（guide 插件特性）。
- 手柄支持（已定 P8）：瞄准辅助差异化（P9）、切换键位。

---

## 5. 数据驱动 Resource 设计（字段草案）

> **命名空间约束（Mod 前置）**：所有 Resource 内容在运行时统一以 `ResourceLocation(namespace:id)` 注册（见 §10.2），官方内容使用 `bulwark:` 命名空间，Mod 使用各自 mod_id——从第一天起为 Mod 铺路，不改架构。

以武器为例（其余同类）：

```gdscript
# resources/weapons/type/type_assault_rifle.tres
class_name WeaponTypeData extends Resource
@export var id: String                    # "assault_rifle"
@export var slot: SlotType                # MAIN / SUB / PISTOL
@export var ammo_type: AmmoType           # BULLET / FUEL / GRENADE / ENERGY
@export var ballistic: BallisticMode      # HITSCAN / PROJECTILE / SPREAD / ...
@export var switch_cd: float              # 主副 1.5 / 手枪 0.3（已定 P23）
@export var recoil: Vector2               # 后座散布手感
@export var muzzle_speed: float
```

```gdscript
# resources/weapons/model/model_storm7.tres
class_name WeaponModelData extends Resource
@export var type_id: String               # 关联 WeaponTypeData
@export var display_name: String          # "风暴-7 突击步枪"（虚构命名，已定 P26）
@export var damage: float
@export var fire_rate: float
@export var mag_size: int
@export var reload_time: float
@export var spread: float
@export var crit_chance: float
@export var keywords: Array[Keyword]      # PIERCE / BURN / EXTENDED_MAG ...
```

- `enemies/`：`EnemyData`（血量/移速/威胁模式/行为参数/掉落表）。
- `waves/` `chapters/`：波次构成模板 + 章节波表（含精英波标记）。
- `shop/` `upgrades/`：商品定义（类别/稀有度/基础价/效果引用）。
- `facilities/`：设施定义。`loot/`：搜索点/掉落表。`skills/`：技能定义。
- `meta/`：解锁项清单。全部通过 `Registry`（mc_game_framework）注册，编辑器友好。

---

## 6. 多人权威边界表（摘要）

| 系统 | 权威 | 同步方式 | 客户端角色 |
|---|---|---|---|
| 玩家移动/射击意图 | host 验证 | 意图 RPC + 状态快照 | 预测 + 插值 + 校正 |
| 伤害/击杀/掉落 | host | 快照 + 事件 | 表现 |
| 敌人 AI / 波次 / 刷怪 | host | 快照 + 事件 | 插值表现 |
| 基地耐久 / 设施 | host | 快照 | 表现 + 意图（建造/修复） |
| 商店 / 货币 / 复活 | host | 请求-响应 RPC | 展示 + 请求 |
| meta 存档 | host（房主存档） | 结算时写入 | 展示 |
| HUD / VFX / 音频 | — | 本地 | 全权本地播放 |

---

## 7. 测试策略（GUT，headless 可跑）

纯逻辑模块（不依赖场景）用 GUT 覆盖，作为"技能集裁剪回归"的自动化保障：

| 测试域 | 用例 |
|---|---|
| 伤害管道 | 加成/减免/暴击/词条组合的公式正确性 |
| 波次生成 | 种子确定性：同种子同构成；方位/强度三元组边界 |
| 商店 | 随机刷新（种子）、价格递增曲线、固定物资解锁条件 |
| 经济/复活 | 资源扣减、复活代价、失败判定 |
| 切换状态机 | CD 计时、切手枪快捷路径、非法切换拒绝 |
| 前后端分离 | 后端模块在无场景环境实例化通过（禁 get_node / 渲染引用；评审 + 静态检查） |

运行方式（AGENTS.md §7）：`godot.exe --headless -s addons/gut/gut_cmdln.gd --path .`

---

## 8. 里程碑 × 架构演进

| 里程碑 | 架构交付物 | 验证 |
|---|---|---|
| M0 垂直切片 | Player3C + 单弹道 + 单敌人 FSM + BaseCore + WaveDirector（固定 3 波）——**内容走 Registry+ResourceLocation、前后端分离** | headless 可跑闭环 + 架构硬性约束验收 |
| M1 核心循环 | 三槽武器 + 切换状态机 + AmmoSystem + 商店 MVP + 波次方位生成 | 单局 15 分钟 |
| M2 多人架构验证 | Net 会话 + 意图 RPC + 状态快照 + 本地双客户端 | 2 客户端同局稳定 |
| M3 搜索循环 | 搜索点 + 掉落表 + WaveTimer + 敌人 5 种 | 攻守节奏成立 |
| M4 章节制 | ChapterData + 精英波 + 商店随机/固定 + meta 存档 | 章节闭环 |
| M5 打磨 | 表现层优化（VFX/音频/UI 绑定） | 手感达标 |
| M6 多人完整 | 强度缩放 + 多人商店规则 + 反作弊验证 | 局域网稳定 |
| M7 发布 | 内容补齐 + 平衡 + 分发 | 可发布 |

---

## 9. 风险与对策

| 风险 | 对策 |
|---|---|
| 同屏敌人过多性能 | 同屏预算上限（WaveDirector 控制）、对象池、导航预算（分帧寻路）、AOI 剔除 |
| 切换手感不佳 | CD 数值与打断规则（P23）在 M1 实机反复调参，状态机先行可测 |
| 商店经济失衡 | 价格曲线/稀有度权重数据表化，GUT 回归 + 试玩调参 |
| 多人同步带宽 | 快照频率分级（玩家高频/敌人中频/基地低频）、增量同步 |
| 单人多人数值割裂 | 强度缩放系数单一来源（RunState），M2 起持续对照测试 |
| 技能集裁剪返工 | Framework+Action 原子化 + §16 裁剪表，删数据不删架构 |

---

## 10. Modding 支持

### 10.1 设计目标与原则

- **Mod = 内容包（数据）+ 可选代码（脚本）**：绝大多数 Mod 只注册数据条目（新武器/敌人/商品），无需改游戏代码；少数 Mod 注册新脚本类（新弹道模式 / 新 Action 原子 / 新敌人行为）。
- **官方内容与 Mod 同构**：官方内容就是 `bulwark:` 命名空间下的"第一个内容包"，Mod 只是注册更多条目——不存在两套系统。
- **Mod 按"作用端"分层（manifest 声明 `side`）**：
  - **gameplay Mod**：影响逻辑 / 权威内容（武器、敌人、波次、技能、数值、设施）——**多人下必须双端强一致**（§10.6）；
  - **client-only Mod**：只影响客户端表现（资源更换、UI 美化、画面 / 光影优化等）——**允许单端，不参与一致性校验**；单端 Mod 是模组生态的正常形态，本项目明确支持；
  - 本项目**无纯 server 部署**，不产生 server-only Mod（如需未来预留，仅作扩展点声明，不实现）。
- 本项目基于 **MSF（mc_game_framework）**：其 Minecraft 风格设计（ResourceLocation / Registry / Codec / EventBus / Tag / Component）天然就是为 Mod 生态准备的基础设施（见 §10.2 映射）。

### 10.2 MSF 原生能力 → Mod 支撑映射

| MSF 组件 | 能力 | Mod 用途 |
|---|---|---|
| `ResourceLocation` | `namespace:path` 严格校验、全局唯一标识 | **Mod 内容 ID**：`mod_id:content_id`，天然防冲突 |
| `RegistryManager` / `RegistryBase` | 类型化注册表（register / unregister / get_entry / 覆写类型校验） | **内容注入点**：武器/型号、敌人、波次、技能、设施、商品、搜索点、meta 解锁 |
| `Codec`（MapCodec / JsonOps） | 数据序列化 / 反序列化 | Mod 数据定义、存档兼容（存档存完整 ID） |
| `EventBus` | 事件解耦 | Mod 订阅 / 广播游戏事件（钩子扩展） |
| `Tag` / `TagRegistry` | 内容标记与过滤 | Mod 内容打标（如 `modded_weapon`）、条件筛选 |
| `Component` / `ComponentHost` | 实体组件化 | Mod 给实体挂自定义组件（数据跟随实体） |
| `I18NManager` | 本地化 | Mod 文案多语言键（不硬编码文本） |
| `UIManager` | 面板注册 | Mod 自定义 UI 面板 |

### 10.3 内容注册体系（类型化注册表）

- 每个内容域一个 `RegistryBase` 子类，覆写 `_validate_entry` 做类型/字段校验：
  `WeaponTypeRegistry`、`WeaponModelRegistry`、`EnemyRegistry`、`WaveRegistry`、`SkillRegistry`、`FacilityRegistry`、`ShopPoolRegistry`、`LootRegistry`、`MetaUnlockRegistry`。
- 全部经 `RegistryManager` 注册（`register_registry("weapon_type", ...)` 等）。
- **冲突策略**：`bulwark:xxx` 与 `mod:xxx` 合法共存；同一命名空间内重复注册 → `RegistryBase` 已有覆盖告警（Mod 排错可观测）。
- **数据类 Mod**：新增内容 = 新增注册条目（零代码）；**代码类 Mod**：额外注册脚本类（弹道模式 / Action / 敌人行为 FSM / 设施类型），其余走同一条注册管线。

### 10.4 Mod 加载管线（复用 GodotModLoader）

> GodotModLoader（CC0，`new_project/addons/mod_loader` 中已有副本）提供：mods 目录 / zip 扫描、hook 包（`mod_hook_packer`）、依赖解析、profile 与 config、日志。移植为本项目 `addons/mod_loader` 后按以下顺序接入：

1. 启动扫描 `mods/`（zip 或目录）与 `mods-dev/`（开发期）；
2. 加载 hook 包（仅非编辑器运行时，编辑器用 Dev Tool）；
3. 按依赖序初始化各 Mod（profile / config 读取）；
4. **内容注入**：Mod 数据经 `RegistryManager` 注册（数据类）或脚本类注册（代码类）；
5. 汇总冲突 / 错误到 ModLoaderLog（可观测、可报告）。
6. **读取 manifest 的 `side` 声明**（gameplay / client_only），决定其是否参与双端一致性校验（§10.6）。

### 10.5 存档与内容兼容

- 存档记录内容的**完整 `ResourceLocation` 字符串（含 namespace）+ 版本号**（Codec 序列化）。
- **缺失内容策略**（Mod 卸载后）：占位条目（UI 显示"缺失内容"）/ 跳过 / 严格模式拒绝加载——三级可配。
- 存档头部内嵌 **Mod 清单**（mod_id + 版本），加载时校验并提示。

### 10.6 多人 + Mod（按作用端分层的一致性策略）

- host 权威模型不变：Mod 内容由 host 生成/裁决，客户端只表现（§6 边界表不因 Mod 改变）。
- **gameplay Mod（影响逻辑 / 权威内容）→ 双端强一致**：
  1. 连接时交换 **Mod 清单**（mod_id + side + 版本 + **内容哈希**）；
  2. **数据类**：host 下发内容（Resource 数据经 Codec 传输 / 内容包），客户端加载后计算哈希二次比对；
  3. **代码类**：客户端必须持有与 host 完全一致的脚本包（预装或 host 下发整包），加载后按文件哈希比对；
  4. **任一不一致 → 拒绝加入**（不降级、不忽略）；运行期周期性复验（防中途篡改 / 掉包）。
- **client-only Mod（表现类：资源更换 / UI 美化 / 画面与光影优化）→ 允许单端**：
  - 不参与一致性校验，host 不要求客户端持有相同 client-only Mod；
  - 客户端可自由开关（换肤 / 美化 / 性能向画面 Mod 是模组生态正常形态）；
  - 若 client-only Mod 意外引用了 gameplay 内容，加载期校验拦截并提示（防御性检查）。
- 反作弊：Mod 带来的伤害/资源仍走 host 验证管道，Mod 不绕过经济/耐久校验；client-only Mod 因不触碰逻辑，天然不构成作弊面。

### 10.7 安全边界

| 场景 | 策略 |
|---|---|
| 单机 + 脚本 Mod | 完全能力（玩家自担风险），首次加载弹警告 |
| 多人 + gameplay 代码 Mod | 双端强一致（§10.6），host 裁决，不一致拒绝加入 |
| 多人 + client-only Mod | 允许单端（换肤 / 美化 / 画面光影优化），不校验、不影响加入 |
| 数据 Mod 校验 | `RegistryBase._validate_entry` + Codec 字段类型/范围校验（M 级防御，不防恶意代码） |

### 10.8 里程碑

- **M0 起（硬性约束，立即生效）**：所有内容（含 M0 的武器/敌人/波次）必须经 Registry + ResourceLocation 注册，前后端分离同步执行——官方与 Mod 同构，M6 接入零返工。
- **M6**：移植 GodotModLoader、`mods/` 目录、Mod manifest（side 声明）、**gameplay 双端一致性流程 + client-only 单端通道**（§10.6）、缺失内容策略。
- **发布后**：Mod API 文档 + 示例 Mod 模板（一个数据类 + 一个代码类）。

---

## 11. 待定架构项（与策划案 [P#] 联动）

- P16 meta 解锁清单与存档结构；P19/P24 多人经济归属；P20 应急储备数值公式；P22 商店数据表细节；P23 切换打断规则；P26 型号数据表；P27 精英波数值。
- **Mod 相关待定**：Mod API 文档与示例模板、gameplay / client-only 的**判定清单与 manifest 字段规范**、client-only 光影/画面 Mod 的加载优先级与冲突规则、存档缺失内容三级策略的默认档、代码 Mod 的 hook 面清单。
- 以上均为**数据层/数值层**待定，不阻塞架构骨架。
