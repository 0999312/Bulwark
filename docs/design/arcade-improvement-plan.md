# Bulwark「前线壁垒」街机化综合改进方案（提案 · 待人工审计）

> 状态：**提案（v1.1）** — 本文件不执行任何代码 / 资源 / 数据改动；人工审计通过后，按 §6 阶段任务清单分步执行。
> 依据技能：`game-architect`、`godot-brainstorming`、`design`、`design-system`、`hud-system`、`particles-vfx`、`assets-pipeline`。
> v1.1 修订：炮塔与高冲击粒子改为**复用 `temp_assets/kenney_top-down-tanks-remastered` 素材拼接**；新增资产管线、许可、导入、双层 VFX 预算与更完整的审计维度。

---

## 0. 一句话目标

把当前“6 波单链、4–8 分钟的垂直切片”，改造成**“一局 4 章 × 每章 3–4 波 + 章末精英 / 约 15–25 分钟、分数 + 连击 + 排行榜驱动、回合间成长、Kenney 坦克素材拼接 + 像素几何 VFX 双层自洽”的街机式波次生存**。

---

## 1. 设计定位：本游戏的“街机风格”是什么

参考经典街机波次射击（Geometry Wars、Clash 'N Slash、空战街机）的共性，结合本项目现状，定义为：

| 维度 | 街机化目标 | 当前差距 |
|---|---|---|
| **节奏** | 短波、高密度、快回馈；波间“喘口气”但不冗长 | 6 波偏少；商店可无限停留，节奏空白 |
| **反馈** | 开火 / 命中 / 击杀 / 连击都有明确的视觉与音效回报 | 无伤害数字、无命中标记、无连击，音效分支有死代码 |
| **成长** | 局内短周期成长（道具掉落 + 波间购买），一局内可见强烈构筑变化 | 只有商店，无局内即时道具，构筑变化慢 |
| **挑战曲线** | 每章一个主题 + 章末压力峰值（精英/Boss），强度螺旋上升 | 1 章 6 波，强度线性，无章节点变化 |
| **分数** | 分数、连击倍率、排行榜、结算名次 | 结算只有统计，无分数体系 |
| **美术** | 高对比、干净；炮塔/弹体/爆炸使用 Kenney 俯视坦克素材拼接，普通命中用 8px 像素几何；无柔和烟雾/光晕污染 | 高清软粒子残留 + 矢量炮塔混搭 |
| **重玩** | 每局波次组合、掉落、商店有差异；失败即想再来一局 | 波次/商店种子固定，重复性低 |

---

## 2. 模块 A：粒子素材清理与替换（用户已明确“可以直接删除”）

### 2.1 现状盘点（已 grep 全仓引用）

`assets/particles/` 共 20 个 PNG，实际被引用的只有 5 个：

| 被引用文件 | 引用位置 | 用途 |
|---|---|---|
| `muzzle_02.png` | `scenes/player/player_view.gd` / `player.tscn` | 玩家枪口焰（512px 软光） |
| `smoke_06.png` | `scenes/base/base.tscn` | 基地低耐久烟雾 |
| `light_03.png` | `scenes/base/base.tscn` | 基地核心动态光 |
| `light_01.png` | `scripts/systems/lighting_manager.gd` | 枪口/爆炸动态光 |
| `dirt_01.png` | `scenes/base/barricade.tscn` | 路障摧毁粒子 |

**未引用的 15 个**（可直接删除）：`circle_01.png`、`circle_03.png`、`dirt_02.png`、`flame_02.png`、`flame_04.png`、`flare_01.png`、`muzzle_01.png`、`scorch_01.png`、`smoke_01.png`、`smoke_03.png`、`spark_01.png`、`spark_03.png`、`spark_05.png`、`star_02.png`、`star_04.png`。

### 2.2 删除与替换策略（两类）

**第一类：未引用贴图 → 直接删除（低风险）**
- 删除上表 15 个 PNG 及其 `.import` 文件；`assets/particles/` 目录仅在替换完 5 个引用后整体删除。
- 删除后 `grep -r "assets/particles" .` 应只命中已被替换的 5 处（最终 0 命中）。

**第二类：5 个被引用贴图 → 替换为“Kenney 坦克素材拼接 + 运行时像素几何”双层方案（v1.1 更新）**

| 原效果 | 替换方案 v1.1 | 主要代码点 |
|---|---|---|
| 枪口焰 `muzzle_02` | 使用 `shotLarge.png` / `shotOrange.png` 短缩放闪现（0.06s，0.5→1.0 → 淡出）；无对应素材时回退程序化 `Polygon2D` 星形闪光 | `scenes/player/player_view.gd`、`player.tscn`、新 `VfxBank` |
| 基地烟雾 `smoke_06` | 移除“现实主义烟雾”；低耐久时用 `explosionSmoke1.png` 低频单帧告警 + 核心 `modulate` 闪烁 / `PointLight2D` 脉冲（街机式告警） | `scenes/base/base.tscn`、`scripts/systems/fx_burst.gd` |
| 基地灯光 `light_03` / 动态光 `light_01` | 运行时生成 32×32 径向渐变 `ImageTexture`（`FxBurst.get_pixel_texture()` 扩展 `get_glow_texture()`），替换两个 `PointLight2D.texture` | `scripts/systems/lighting_manager.gd`、`scenes/base/base.tscn` |
| 路障摧毁 `dirt_01` | `sandbagBrown.png` / `barricadeWood.png` 作为碎片贴图（`CPUParticles2D.texture`，多个 8–16px 像素块）+ `FxBurst` 像素块爆点 | `scenes/base/barricade.tscn`、`barricade_view.gd` |
| （新增）敌人死亡 / 自爆 AoE | 5 帧 `explosion1..5.png` → `SpriteFrames` / `AnimatedSprite2D`（0.35s），死亡/自爆/Boss 击杀使用；普通命中小怪仍用 `FxBurst` 像素块 | `enemy_view.gd`、`fx_burst.gd`、新 `VfxBank` |
| （新增）玩家 / 敌方弹体 | `bulletGreen1.png`（玩家）、`bulletRed1.png` / `bulletDark1.png`（敌方）、`shotThin.png`（狙击）等，Sprite2D 按飞行方向 `rotation` | `player_view.gd`、`enemy_projectile.gd`、`turret_tracer.gd` |

**双层 VFX 预算（性能纪律）**：
- **Tier 1（高频、廉价）**：`FxBurst` 运行时 8px 像素几何——普通命中火花、通用碎片、玩家 tracer 光带；
- **Tier 2（低频、高冲击）**：Kenney 坦克素材——炮塔模型、弹体、死亡爆炸、自爆 AoE、Boss 击杀、枪口焰；
- 这既满足“清理不合适的旧粒子素材”，又避免每颗子弹都播放 5 帧动画带来的开销。

**原则（v1.1）**：
1. 删除所有旧 `assets/particles/*.png`（20 个，替换后 0 引用）；
2. 炮塔、弹体、爆炸等“高冲击表现”改为复用 `temp_assets/kenney_top-down-tanks-remastered/PNG/Default size/` 素材（**必须复制到 `assets/` 提交，不能留在被 gitignore 的 `temp_assets/`**）；
3. `FxBurst` 运行时 8px 贴图继续承担高频廉价粒子（普通命中/碎片）。

### 2.2A Kenney `top-down-tanks-remastered` 素材复用映射（v1.1 新增，已实际盘点）

源包目录：`temp_assets/kenney_top-down-tanks-remastered/PNG/Default size/`（另有 `Retina/` 与 `Spritesheet/*.xml`；默认使用 Default size，避免体积与过滤问题）。许可：**CC0**（`License.txt` 已确认，无需署名，建议在 `assets/CREDITS.md` 注明）。

| 用途 | 源素材（Default size） | 目标路径（建议） | 用法 |
|---|---|---|---|
| 炮塔底座 | `tankBody_dark.png`（或 `tankBody_sand/green/red/blue.png` 做配色变体） | `assets/sprites/turret/turret_base.png` | `Sprite2D`，scale 0.6~0.75；替换现 `temp_assets/turret/turret_base.svg` |
| 炮塔炮管 | `tankDark_barrel1/2/3.png`、`specialBarrel1..7.png` | `assets/sprites/turret/turret_barrel_1.png` 等 | 3 款可换炮管；`TurretView.Barrel` 引用 |
| 完整坦克（备选大炮塔/Boss 座驾） | `tank_dark.png`、`tank_huge.png`、`tank_bigRed.png` | `assets/sprites/turret/turret_variants/` | 后续 Boss/首领载具预留 |
| 玩家普通弹体 | `bulletGreen1.png` / `bulletGreen2/3.png` | `assets/vfx/kenney/bullets/bulletGreen1.png` | 手枪/AR/LMG 弹头（按武器微调颜色） |
| 敌方弹体 | `bulletRed1.png`、`bulletDark1.png`、`bulletBlue1.png` | `assets/vfx/kenney/bullets/` | 喷吐者/狙击手/飞行体弹体换色 |
| 炮塔 / 枪口焰 | `shotLarge.png`、`shotOrange.png`、`shotRed.png` | `assets/vfx/kenney/muzzle/` | 短缩放闪现（0.06s） |
| 死亡爆炸（5 帧动画） | `explosion1..5.png` | `assets/vfx/kenney/explosion/` | `SpriteFrames`（`AnimatedSprite2D` 或 `AtlasTexture` 序列），0.35s |
| 爆烟残留（可选用） | `explosionSmoke1..5.png` | `assets/vfx/kenney/explosion_smoke/` | 低透明度、低频，自爆/地道场景用 |
| 路障碎片 | `sandbagBrown.png`、`barricadeWood.png`、`crateWood.png` | `assets/vfx/kenney/debris/` | `CPUParticles2D.texture`，配合像素块 |
| 地面油渍 / 战后标记 | `oilSpill_small.png`、`oilSpill_large.png` | `assets/sprites/decor/` | 章节地形 / Boss 战后装饰（可选） |
| 补给箱 / 掩体装饰 | `crateMetal.png`、`crateWood_side.png`、`sandbagBeige.png` | `assets/sprites/props/` | 章节场景装饰、基地周围掩体（可选） |

**资产管线（`assets-pipeline`）要求**：
- 只复制上述“用到的” ~25–35 个文件（不要整个 374 个 PNG 全量进库），避免仓库体积与导入时间膨胀；
- 导入设置：`texture_filter = Nearest`（跟随 project.godot）、无 mipmap、`lossless` 压缩；像素分辨率与现有 Kenney 角色一致（Default size，非 Retina）；
- 创建 **`VfxBank`**（Resource 或静态类）：集中持有 `SpriteFrames` / `AtlasTexture` / `Texture2D`，炮塔与 VFX 场景只引用 `VfxBank`，禁止散落 `preload("res://temp_assets/...")`；
- 复制时保留 `License.txt` 到 `assets/CREDITS.md`（CC0 声明 + 来源）；
- 删除 `temp_assets/turret/*.svg` 引用后，`grep -rn "temp_assets/turret" .` 必须 0 命中。

### 2.3 审计要点（不做则不能执行）

- [ ] 五个替换点全部落地后，`grep -rn "assets/particles" scenes scripts resources` 为 **0 命中**；
- [ ] 新素材已从 `temp_assets/kenney_top-down-tanks-remastered/` **复制进 `assets/`** 并纳入 git；`grep -rn "temp_assets" scenes scripts resources assets` 为 **0 命中**（无运行时依赖）；
- [ ] `assets/particles/` 整个目录删除，`git status` 无遗留 `.import` 引用；
- [ ] `VfxBank` 单一入口建成：炮塔 / 弹体 / 爆炸 / 枪口焰全部走它，无散落 `preload` 硬编码路径；
- [ ] 导入设置符合：`Nearest` 过滤、无 mipmap、lossless、只用 Default size（Retina 未误用）；
- [ ] `assets/CREDITS.md` 注明 Kenney CC0；
- [ ] headless 冒烟 + GUT 全量通过；
- [ ] 截图确认：炮塔造型与角色风格一致、爆炸 5 帧节奏正常、弹体方向正确、枪口焰/基地告警/路障摧毁在 1280×720 与 1920×1080 均清晰、无黑屏、无缺纹理。

---

## 3. 模块 B：多轮（章节）波次体系

### 3.1 目标节奏（对照）

| 方案 | 结构 | 预计一局时长 | 适用 |
|---|---|---|---|
| **A. 章节制（推荐）** | 4 章 ×（3 波 + 章末精英 = 4 波）= **16 波** | **14–22 分钟** | 主模式，对齐 GDD P21“每章 3~4 波 + 关底，一局 4~6 章” |
| B. 无尽轮次 | 每轮 4 波（3 波 + 精英），无限轮，难度/分数持续上抬 | 一局以失败或自觉结束 | 街机排行榜模式 |
| C. 双模式 | A + B 并存，主菜单可选 | 按模式 | 最终形态，建议先 A 后 B |

**推荐先做 A**：一次性把内容量拉到 GDD 目标，同时把当前已做好的 9 种敌人 / 16 款武器 / 35 商品全部放进“按章差异化组合”，不改核心战斗手感。

### 3.2 章节模板（示例）

| 章节 | 主题（视觉用地面色调/装饰区分） | 波次构成（现有敌人池） | 章末精英 |
|---|---|---|---|
| 第 1 章 · 前哨周边 | 草地 + 少量污土 | 波1 奔跑者 / 波2 奔跑者+疾行者 / 波3 自爆体+喷吐者 | 精英·疾行者（强化快怪 + 疾行精英变体） |
| 第 2 章 · 废弃小镇 | 灰蓝色调 + 网格残骸 | 波1 疾行者+装甲兽 / 波2 喷吐者+狙击手 / 波3 混合 | 装甲首领（强化装甲兽） |
| 第 3 章 · 工业污染区 | 暗橙 / 污染色 | 波1 飞行体+狙击手 / 波2 自爆体+飞行体 / 波3 全混合 | 飞行母体（强化飞行体） |
| 第 4 章 · 巢穴 | 深红 / 黑岩 | 波1 精英小怪潮 / 波2 混合高密度 / 波3 混合+自爆潮 | **精英·巨兽（最终 Boss，沿用弱点机制，加 1 阶段变体）** |

> 说明：章节波次数量可用数据再调；重点是“每章不同威胁组合 + 章末压力峰值”，而不是新增 9 种新敌人。

### 3.3 需要的数据结构（提案，待审计）

```
RunDefinition (Resource)
├── id / display_name
├── chapters: Array[ChapterDefinition]   # 4 章
├── default_player_count_scale
└── highscore_key?（排行榜按 RunDefinition 分组）

ChapterDefinition (Resource)
├── id / display_name / theme_rgb / theme_ground_texture?
├── waves: Array[WaveData]        # 3 波（复用现有 WaveData）
├── boss_wave: WaveData           # 章末精英波
└── round_reward_pool: Array[String]  # 轮间奖励选择池
```

- 扩展方向：工厂模式为**数据驱动**（`Data-Driven Design`），新增章节 = 新增 `ChapterDefinition.tres` + 少量敌人数据，零代码。
- `WaveDirector` 增加 `ROUND_INTERMISSION`（章间）与 `BossWaveStarted` 相位；`WaveClearedEvent` 增加 `chapter_index`；现有 `EventBus` 事件可向后兼容（新增字段不影响旧订阅）。
- `GameSession._begin_waves()` 从 `Bulwark.WAVE_IDS` 改为读 `RunDefinition`；多人 host/client 只需随快照携带 `chapter_index/round_phase`。

### 3.4 单波与新波次微调（街机节奏）

- 每波持续时间目标 **40–70 秒**（含预警 + 接敌 + 清场），章末精英 60–90 秒。
- 建议：`spawn_interval` 中后期压到 0.5–0.7s；**单波同屏上限**（例如 40 只）由 `WaveDirector` 控制，超限暂停刷出，保证低端机不掉帧（当前无上限约束）。
- 预警：大字横幅（`WAVE 2/16` / `第 2 章 · 废弃小镇`）+ 方向罗盘恢复（见 §4.3）。
- 波间：商店保留但增加**可选 15–30 秒倒计时**（可关），形成街机“抓紧买”的节奏；倒计时结束后自动开下一波。

### 3.5 难度增长

- `DifficultyCurve.WAVE_SCALES`（当前未使用）接入本章结构：`wave_scale = chapter_scale × wave_scale`；`chapter_scale` 例如 `[1.0, 1.25, 1.5, 1.8]`。
- 多人人数缩放沿用现有 `player_count_scale`（敌人血量 ×1.6 + 波次 `count_scale`），不新增复杂规则。

---

## 4. 模块 C：街机玩法层（分数 / 连击 / 道具 / 生命 / 排行榜）

### 4.1 分数与连击（核心“街机感”）

**后端 `ArcadeScore`（纯逻辑 RefCounted，可 GUT 测）：**

| 字段 | 说明 |
|---|---|
| `score: int` | 总分 |
| `combo: int` | 连续击杀数（3.5 秒内击杀 +1，超时/受致命伤重置） |
| `combo_multiplier: float` | `min(1.0 + combo * 0.25, 6.0)` |
| `wave_bonus / chapter_bonus / perfect_bonus` | 波清/章清/无伤奖励 |

**基础分值（示例，可调）**：

| 敌人 | 基础分 |
|---|---|
| 奔跑者 / 自爆体 | 50 / 90 |
| 疾行者 / 飞行体 | 80 / 120 |
| 硬壳者 / 喷吐者 | 100 / 120 |
| 装甲兽 | 150 |
| 狙击手 | 140 |
| 精英·巨兽 | 1000 |

**街机化规则建议**：
- 击杀得分 = 基础分 × `combo_multiplier`；
- 出现伤害数字（本方案同时落地）：白字普通 / 黄字暴击 / 紫字弱点 / 橙字连击；
- “PERFECT WAVE”：本波基地未掉耐久 + 玩家未死亡 → +500 × 波系数，并播 jingle；
- “ROUND CLEAR”：章节清空 → +2000 × 章节系数；
- 结算面板：总分、单局最高连击、击杀数、用时、**本机历史 Top 10**（`user://highscore.json`，街机排版；可选输入 3 字缩写名）。

### 4.2 波中道具掉落（街机“吃到就是赚到”）

| 道具 | 出现率（建议） | 效果 | 表现 |
|---|---|---|---|
| 弹药箱 | 10% | +30 子弹 | 黄色 8px 方块，浮动 | 
| 建材包 | 8% | +1 建材 | 棕色方块 |
| 医疗包 | 3% | +25 HP（过量转护盾?） | 红白十字像素块 |
| 急速射击 | 4% | 6s 内 `fire_rate × 1.5` | 青色闪烁，带计时条（HUD 小图标） |
| 三连弹 | 4% | 6s 内 `pellets +2`（等同霰弹化） | 绿色闪烁 |
| 护盾 | 2% | 5s 内免疫/吸收 50 伤害 | 蓝色圆环 |
| 分数加速 | 3% | 10s 内得分 ×2 | 金色闪烁 |
| 备用命 | 0.5% | `reserve + 1`（应急储备） | 紫色/红色像素块 |

- 掉落目标：`Area2D`（pickup）+ `CollisionShape2D`，9 秒未捡自动消失；
- 与现有击杀奖励（概率建材/弹药）**并存但替换为“视觉化掉落物”**，不再只是静默 `add_material`；
- 道具效果走 `EventBus`（如 `PowerUpPickupEvent`），表现层只监听；后端 `PowerUpSystem` 维护 buff 计时器（`AttributeSet` 临时乘数 + `_fire_rate` 等），与现有商店强化同通道；
- 道具图标/拾取物优先复用 §2.2A Kenney 素材（`crateMetal.png`→弹药箱、`crateWood.png`→建材、`shotOrange.png`→急速射击、`bulletGreen1.png`→三连弹 等），只有未映射的图标才用 Tier1 像素块兜底。

### 4.3 HUD / 界面（街机大字号 + 信息密度）

按 `hud-system` 规范设计：

```
CanvasLayer(layer=1)              # 已有 Hud → 建议改造
├── TopBar
│   ├── ScoreLabel      # 大字号滚动数字（tween_method 计数）
│   ├── ComboBar        # 连击倍率 + 剩余时间条（短触发动画）
│   ├── HealthBar       # 现有 HP/基地
│   └── RoundLabel      # “第 2 章 · 3/4 波”（替代当前 wave_label 文案结构）
├── DirectionRadar      # 恢复/增强：N/E/S/W+斜向，战斗中显示敌人来袭方位
├── BossBar             # 章末精英：顶部大血条 + 名称（+弱点提示）
├── PickupTimers        # 当前 buff 图标 + 剩余秒数
└── DamageNumbersLayer  # 池化浮动伤害数字（世界→屏幕坐标转换）
```

- 字体保持 MiSans（现有），新增：分数用 40–56px、波/章标题 32px 全屏横幅、伤害数字 12–16px 像素感；
- 配色沿用 `UiPalette`（深海军蓝 × 琥珀 × 语义色），街机化只加“效果层”高饱和色，不改变面板 token；
- 方向罗盘：当前 HUD 已移除逐方向箭头，本方案**恢复为轻量罗盘 + 波次预览**（这是“多方位防守”核心支柱的最低成本补强）。

### 4.4 生命 / 续关（可选，街机“再来一局”）

- 保留当前“应急储备 = 复活资源”；
- 街机化视觉：HUD 显示 `残存 ×N` 图标，死亡时“继续？”面板（存在文字/音效）；
- 进阶规则（可选）：第 1 章通关奖励 1 次额外储备；总储备归零且阵亡 → 结算面板 + 排行榜写入 → 主菜单，把“失败”变成“再看一次分数榜再开一局”。

### 4.5 音效（配合删除/新增）

- 修复 `AudioDirector._on_shot_fired` 的 `type_id` 匹配死代码（`pistol`/`shotgun` 永不命中）：
  - 当前类型 id：`weapon/type/hg` / `weapon/type/sg` / `lmg` / `er`；
  - 新增：LMG 低频厚重、ER 高频能量音（可用现有 `smg_shoot`/`handgun_shoot` 变调 + 叠层，不新增外部素材）；
- 新增街机 jingle：连击升级、PERFECT WAVE、ROUND CLEAR、BOSS 预警、道具拾取（现有 `kenney_interface_sounds` 音色可复用，无需新素材）。

---

## 5. 模块 D：美术 / 表现统一（v1.1：Kenney 坦克素材拼接）

1. **世界层**：像素优先（Kenney 角色 + 瓦片 + 8px 几何 VFX）；矢量只保留 HUD/面板（“像素世界 + 矢量 HUD”组合）。VFX 双预算：普通命中 = `FxBurst` 8px 几何；炮塔/弹体/爆炸 = Kenney 坦克素材。
2. **炮塔（重点改造）**：用 `tankBody_dark.png`（底座）+ `tankDark_barrel1/2/3.png` 或 `specialBarrel*.png`（炮管）**拼接组装**（`Turret.tscn` 的 `Sprite`/`Barrel` 节点不变，替换 texture 即可）；可做 3 套配色变体（沙色/绿色/深色）。完全移除 `temp_assets/turret/*.svg`。
3. **弹体与爆炸**：玩家/敌人弹体用 `bulletGreen1/Red1/Blue1/Dark1.png`；死亡/自爆 AoE 用 `explosion1..5.png` 5 帧动画；枪口焰用 `shotLarge.png`/`shotOrange.png` 短闪现。全部经 `VfxBank` 取用。
4. **敌人可读性**：9 种敌人先做轮廓差异——装甲兽加盾/金属色块、狙击手加长管/镜、飞行体加翼/悬空阴影、精英加体型+弱点发光；可用 `temp_assets/kenney_top-down-shooter/PNG/` 其他剪影拼装，也可从坦克包取零件做“机械化 Boss/载具”区分。
5. **章节主题**：每章改地面色调（`main.tscn` 的 `Polygon2D.color` / 叠加 `ColorRect` 大色块）与装饰（`crateMetal.png`、`sandbagBeige.png`、`oilSpill_*.png` 可复用），成本极低，收益是高辨识度。
6. **许可与版本**：`assets/CREDITS.md` 记录 Kenney CC0；`temp_assets/` 仅作为本地源包，最终运行时零依赖。

---

## 6. 阶段任务落点（供人工审计后分步执行）

### P0（低风险、立即可审）

| # | 任务 | 涉及文件（预估） | 技能 |
|---|---|---|---|
| 1 | 删除 15 个未引用粒子贴图 | `assets/particles/*.png`（15）+ `.import` | `particles-vfx` |
| 2 | 替换 5 个被引用粒子 → Kenney 素材拼接 + 运行时灯光 | `player_view.gd`、`player.tscn`、`base.tscn`、`barricade.tscn`、`lighting_manager.gd`、`fx_burst.gd` | `particles-vfx`、`assets-pipeline`、`godot-code-review` |
| 3 | 复制 Kenney 坦克素材到 `assets/`（炮塔/弹体/爆炸/枪口焰/碎片，约 25–35 文件）+ 导入设置 + `assets/CREDITS.md` | `assets/sprites/turret/`、`assets/vfx/kenney/`、`assets/CREDITS.md`、`.import` 批量配置 | `assets-pipeline` |
| 4 | 建立 `VfxBank` 单一纹理入口（`SpriteFrames`/`AtlasTexture`/`Texture2D`） | 新 `scripts/systems/vfx_bank.gd`（或 Resource） | `resource-pattern`、`godot-testing` |
| 5 | 修复 AudioDirector 武器音效分支 + 补 2 个变调 | `audio_director.gd`（无新增外部素材） | `audio-system` |
| 6 | 引入本局随机种子（波次 + 商店） | `game_session.gd`、`wave_director.gd`、`shop_system.gd`、`bulwark.gd` | `godot-brainstorming`、`resource-pattern` |
| 7 | HUD 增加方向罗盘/雷达最短版 | `hud.tscn`、`hud.gd` | `hud-system` |

### P1（核心街机化，2–4 周）

| # | 任务 | 波及系统 | 技能 |
|---|---|---|---|
| 8 | `RunDefinition` / `ChapterDefinition` 数据层 + `WaveDirector` 章间状态机 | `scripts/data/`、`scripts/core/wave/`、`game_session.gd`、`resources/` | `game-architect`、`resource-pattern`、`godot-testing` |
| 9 | 章节波次/精英数据（4 章模板） | `resources/chapters/*.tres` | `data-driven-design` |
| 10 | 分数/连击后端 + 事件 + 结算排行榜 | `ArcadeScore`、`ScoreChangedEvent`、`result_panel.gd`、HUD | `event-bus`、`hud-system`、`save-load` |
| 11 | 伤害数字（池化浮动数字） | `hud.gd/tscn`、新 `DamageNumber` 场景 | `hud-system`、`tween-animation` |
| 12 | 波中道具掉落 + buff 计时 | `PowerUpData`、`PowerUpSystem`、pickup 场景、`EventBus` | `ability-system`、`event-bus`、`resource-pattern` |
| 13 | 章末 Boss 大血条 + 章节过场横幅 | HUD、`base_modal_panel`/新横幅 | `hud-system`、`tween-animation` |
| 14 | 敌人轮廓差异化（5 种） | `assets/sprites/`、`enemy.tscn`、`enemy_view.gd` | `assets-pipeline`、`2d-essentials` |
| 15 | `VfxBank` 接入炮塔/弹体/爆炸动画（5 帧 SpriteFrames + 池化） | `turret.tscn`、`turret_tracer.gd`、`enemy_view.gd`、`fx_burst.gd`、`VfxBank` | `particles-vfx`、`tween-animation`、`assets-pipeline` |
| 16 | 移除 `temp_assets/turret/*` 依赖并全仓 grep 清零 | `turret.tscn`、`turret_tracer.gd`、git 提交 | `assets-pipeline` |

### P2（可选扩展）

| # | 任务 | 备注 |
|---|---|---|
| 17 | 无尽轮次模式（B 方案）+ 自适应难度 | 建立“再来一局”的排行榜驱动力 |
| 18 | 最小 meta 解锁（结算货币 → 起始武器/角色/难度） | 若 P1 后仍觉单局内容薄 |
| 19 | 章间三选一奖励（轻量肉鸽选择） | 可复用商店数据 |
| 20 | 叙事便签 / 章节开场白 / 菜单 attract 模式 | 最后做 |

---

## 7. 人工审计清单（执行前必过）

**A. 资产 / 许可 / 导入**
- [ ] **许可**：`assets/CREDITS.md` 注明 Kenney Top-down Tanks Remastered（CC0）；无未授权第三方素材混入。
- [ ] **来源与路径**：新素材全部复制到 `assets/`；`grep -rn "temp_assets" scenes scripts resources assets` 为 0；`assets/particles/` 目录已删除，无 `.import` 悬空引用。
- [ ] **导入设置**：纹理 `Nearest` 过滤、无 mipmap、lossless；只用 Default size（未误用 Retina 造成内存/风格不一致）；所有新贴图尺寸与现有 Kenney 角色同分辨率体系。
- [ ] **资源收敛**：炮塔/弹体/爆炸/枪口焰全部经 `VfxBank`；无散落 `preload` 与魔法路径；`SpriteFrames` 只建一次。

**B. 风格一致性 / 视觉验收**
- [ ] 1280×720 / 1920×1080 / 21:9 截图复核：炮塔拼接件边缘不跳像素、弹体朝向正确、爆炸 5 帧节奏自然、枪口焰尺度合理、基地告警可读、无空纹理/黑块。
- [ ] 世界层统一“Kenney 像素/卡通 + 矢量 HUD”；敌人轮廓差异化达到远距离可辨（装甲/狙击/飞行/精英）。
- [ ] 章节主题色调切换不刺眼，地面装饰不干扰战斗可读性。

**C. 性能 / 帧率**
- [ ] profiler 实测：最大波 + 双人 + 10 炮塔 + 大量击杀：同屏敌人 ≤ 40、总粒子体系 ≤ 48、无 20ms+ 逻辑帧尖峰；爆炸动画帧不每帧 `load`、`VfxBank` 无重复解码。
- [ ] 双层 VFX 预算：普通命中走 8px 几何（Tier1），仅中高冲击走 Kenney 素材（Tier2）；client 镜像爆炸/粒子有降量策略。

**D. 玩法 / 数据**
- [ ] 多轮章节：4 章 × 3+1 波，单局 14–22 分钟；`RunDefinition` 数据可回退“单章 6 波”旧配置；`WaveDirector` 章间状态机边界清晰；精英/Boss 事件在 host/client 双端一致。
- [ ] 分数/连击/排行榜：后端纯逻辑可测；`user://highscore.json` 写失败时有降级；结算显示总分/最高连击/用时/Top10。
- [ ] 道具掉落：`PowerUpSystem` buff 计时准确；与商店强化叠加规则明确（乘法 vs 加法）；备用命（reserve）稀有度合理。
- [ ] 生命/续关：复活资源数量、失败条件、HUD “残存 N” 显示一致。

**E. 工程 / 兼容**
- [ ] **回归**：GUT 全量（新增 `VfxBank`、`ArcadeScore`、`RunDefinition`、`PowerUpSystem` 测试）通过；headless 冒烟 exit 0。
- [ ] **i18n**：新增文案进 `locales/zh.json` / `en.json`，键奇偶校验通过；无硬编码用户可见文本。
- [ ] **多人**：host 权威（波/章/分数/道具/Boss）；新事件进 `NetCodec` 中继；client 镜像渲染预算不劣化。
- [ ] **存档/设置**：新增设置项（音量/语言/键位/难度/灵敏度）持久化兼容旧 `settings.cfg`；高分榜文件格式带版本号。
- [ ] **无障碍**：至少保留“震屏开关、命中反馈音量、颜色区分+图标双通道（不单靠颜色）”；方向罗盘提供文字兜底。
- [ ] **文档同步**：更新 `game-design-doc.md` 章节制描述、`m5-visual-qa-checklist.md` 令牌、`docs/review/game-review.md` 验证状态。

**F. 风险与缓解（供审计参考）**

| 风险 | 等级 | 缓解 |
|---|---|---|
| 新素材仍在 `temp_assets/`（被 gitignore）导致缺失 | 高 | 复制进 `assets/` 并纳入 git；本方案强制“运行时零 temp_assets 依赖”审计项 |
| 章节制改造波及 WaveDirector/多人协议，回归面大 | 高 | `RunDefinition` 保留“单章 6 波”回退；分阶段提交；每步跑 GUT + 双端冒烟 |
| 5 帧爆炸动画 + 池化不当造成波动 | 中 | Tier1/Tier2 双层预算；`VfxBank` 只加载一次；client 镜像降量；profiler 实测 |
| 分数/连击在多人端不一致 | 中 | 纯逻辑 `ArcadeScore` 主机权威 + 事件中继；GUT 覆盖 |
| 美术风格与 GDD P6“扁平矢量”表述不同 | 低 | 明确选择“Kenney 卡通/像素 + 矢量 HUD”；在 GDD 加一行风格修订备注 |
| 新贴图导入设置错误（Retina/mipmap/过滤） | 低 | assets-pipeline 审计项 + 截图复核 |

---

## 8. 决策点（人工审计时拍板）

| 决策 | 候选 | 默认建议 |
|---|---|---|
| 波次结构 | A 章节制 / B 无尽 / C 双模式 | **先 A，P2 再加 B** |
| 每章波数 | 3+1 / 4+1 / 4+2 | 3+1（16 波，14–22 分钟） |
| 是否加“完美波/连击” | 要 / 不要 | **要**（街机核心） |
| 道具掉落 | 道具掉落 + 商店并存 / 只商店 | **并存**（先掉落，影响大） |
| 生命/续关 | 保持储备制 / 加命视觉 / 加 continue | 先做 HUD 图标 + 结算榜；continue 后置 |
| 粒子删除范围 | 仅删 15 个未引用 / 全部 20 个一并替换 | **20 个全清**（按 §2.2 替换后删除） |
| **粒子素材来源（v1.1 新增）** | 纯程序化 / Kenney 坦克素材 / **双层混合** | **双层混合**：普通命中用 8px 几何，炮塔/弹体/爆炸用 Kenney 素材 |
| 炮塔外形 | `tankBody_dark + tankDark_barrel1` / 沙色 / 三色变体 | 先深色基础款，P1 加 2 套配色变体 |
| 排行榜 | 本地 Top10 / 联网 | **本地 Top10**（零服务器成本） |

---

> 本提案未执行任何代码或资源删除；`docs/review/game-review.md` 为上一轮评审基线。
> 人工审计通过后，建议按 §6 的 P0 → P1 → P2 顺序执行，每阶段完成后跑 GUT + 冒烟 + 截图复核。

---

## 执行状态表（实现阶段维护，不删除原方案内容）

> 状态：done / pending。验证结果列记录每任务完成时的局部/全量验证（全量 GUT 截至 P0 为 44 脚本 / 293 用例 293 通过）。

| 任务号 | 状态 | 改动文件（主要） | 验证结果 |
|---|---|---|---|
| 1 | done | `assets/particles/`（20 PNG + .import 整目录删除，含 15 个未引用 + 5 个被引用） | `grep -rn "assets/particles" scenes scripts resources assets` = 0 命中；目录不存在 |
| 2 | done | `scenes/player/player_view.gd`、`player.tscn`、`scenes/base/base.tscn`、`base_view.gd`、`barricade.tscn`、`barricade_view.gd`、`scripts/systems/lighting_manager.gd`、`fx_burst.gd`（新增 `get_glow_texture()`） | 5 个旧粒子引用全部替换为 Kenney/FxBurst 运行时几何；GUT 293/293 |
| 3 | done | `assets/sprites/turret/`、`assets/sprites/turret/tank/`、`assets/vfx/kenney/*`、`assets/sprites/props/`、`assets/CREDITS.md`、`THIRD_PARTY_NOTICES.md`、`.import`（38 个 Default size PNG） | headless --import EXIT=0；新 .import `compress/mode=0`（lossless）+ `mipmaps/generate=false`；项目默认纹理过滤 Nearest；无 Retina |
| 4 | done | `scripts/systems/vfx_bank.gd`（静态类：纹理缓存 + 爆炸 5 帧 SpriteFrames）、`tests/unit/test_vfx_bank.gd` | test_vfx_bank 5/5；受管路径 0 个引用外部临时素材 |
| 5 | done | `scenes/base/turret.tscn`、`scenes/base/turret_view.gd`、`scenes/vfx/turret_tracer.gd`、`scenes/base/base_view.gd`、`scenes/player/player_view.gd`、`scenes/base/barricade_view.gd`、`scripts/systems/lighting_manager.gd` | VfxBank 接入炮塔/枪口焰/爆烟/碎片/动态光；`grep -rn "temp_assets" scenes scripts resources assets` = 0 命中 |
| 6 | done | `scripts/systems/audio_director.gd` | `_on_shot_fired` 按 `weapon/type/hg\|sg\|lmg\|er` 匹配：HG 手枪音 / SG 降调 / LMG 0.68–0.78 厚音 / ER 高音 1.3–1.45；GUT 293/293 |
| 7 | done | `scripts/systems/run_config.gd`（新 autoload）、`project.godot`、`scripts/core/wave/wave_director.gd`、`scripts/systems/game_session.gd`、`scenes/ui/main_menu.gd`、`tests/unit/test_run_seed.gd` | 本局随机种子接入波次（`wave.seed + run_seed_offset`，默认 0 保既有测试确定性）与商店刷新（`wave_index*1000+7+run_seed`）；test_run_seed 3/3；test_m1_full_run 仍 1/1 |
| 8（P0 附加） | done | `scenes/ui/hud.gd`/`hud.tscn`（复用现有 CompassLabel） | HUD 罗盘最短版（大量/少量 + N/E/S/W+斜向箭头）；1280×720 与 1920×1080 截图人工复核通过 |
| P0 回归 | done | — | GUT 44 脚本 293/293（新增 8 用例）；headless 冒烟 `--quit-after 60` EXIT=0；i18n zh/en 264/264；截图：`user://captures/arcade_hud_warning|active_1280x720.png`、`arcade_hud_warning|active_1920x1080.png`（read_image 已复核） |
| 8（P1） | done | `scripts/data/run_definition.gd`、`scripts/data/chapter_definition.gd`、`resources/runs/arcade_run.tres`、`resources/chapters/chapter_1..4.tres`、`tools/generate_p1_data.gd` | RunDefinition/ChapterDefinition 数据层建成；4 章 ×(3+1)=16 波；legacy 单章 6 波回退保留；test_run_definition 5/5 |
| 9（P1） | done | `resources/runs/arcade_run.tres`、`resources/chapters/chapter_1..4.tres`（波次/精英内嵌） | 4 章模板数据落盘；每章 3 普通波 + 章末精英波（behemoth + 章节主题敌人组合）；chapter_scale [1.0/1.25/1.5/1.8] |
| 10（P1） | done | `scripts/core/wave/wave_director.gd`、`wave_generator.gd`、`scripts/systems/game_session.gd`（`_begin_waves` 街机分支） | WaveDirector `start_run()` 章间状态机：chapter_index/wave_in_chapter/is_boss 推进；`DifficultyCurve` 接入（chapter_scale × wave_scale 传入 `WaveGenerator.generate`）；同屏上限 MAX_ON_SCREEN=40（`_spawn_next` 超限延迟刷出）；legacy `start()` 行为不变 |
| 10（P1） | done | `scripts/core/score/arcade_score.gd`、`scripts/core/events/score_changed_event.gd`、`scripts/systems/game_session.gd`（击杀/波清/章清/结算接线）、`scenes/ui/result_panel.gd`、`scenes/ui/hud.gd`、`scripts/core/score/highscore_store.gd` | 分数/连击/倍率（×1.0→×6.0 封顶）+ PERFECT WAVE/章清奖励；结算总分/最高连击/用时 + `user://highscore.json`（version=1 Top10，写失败降级）；test_arcade_score 6/6、test_highscore_store 4/4 |
| 11（P1） | done | `scenes/vfx/damage_number.gd`、`scripts/systems/fx_burst.gd`（DamageNumber 池 24）、`scripts/systems/game_session.gd`（命中/炮塔命中接线）、`scenes/enemy/enemy_view.gd`（返回 DamageResult） | 伤害数字池化 24：白/黄（暴击）/紫（弱点）/青（炮塔）；host/单机裁决侧生成 |
| 12（P1） | done | `scripts/data/power_up_data.gd`、`scripts/core/score/power_up_system.gd`、`resources/powerups/power_up_{ammo,material,heal,fire_rate,pellets,shield,score,reserve}.tres`、`scenes/power/power_up_pickup.tscn/.gd`、`scripts/systems/game_session.gd`（掉落/应用/到期）、`scenes/ui/hud.gd`（buff 计时） | 8 种道具（权重表）+ 掉落 12%；buff 计时/刷新/到期精确；即时/计时回调对称；test_power_up_system 6/6 |
| 13（P1） | done | `scenes/ui/hud.tscn`（Score/Combo/Buff/BossBar 节点）、`scenes/ui/hud.gd`（章节横幅/BossBar）、`scripts/core/events/enemy_health_changed_event.gd`、`scenes/enemy/enemy_view.gd`（`_publish_health`） | Boss 大血条 + 名称（精英·巨兽）；章节横幅（章名 + 第 N 波）；1280/1920 截图人工复核通过 |
| 14（P1） | done | `scenes/enemy/enemy_view.gd`（`_apply_outline` + `_add_outline_part`） | 5 类轮廓差异：装甲（tankBody_dark）/狙击（长炮管）/飞行（tank_blue）/自爆（红色弹体）/精英（tank_huge + 弱点光点） |
| 15（P1） | done | `scripts/systems/vfx_bank.gd`、`scripts/systems/fx_burst.gd`（爆炸池 10）、`scenes/enemy/enemy_view.gd`（死亡爆炸）、`scenes/vfx/enemy_projectile.gd`、`scenes/player/player_view.gd`（tracer 弹体） | VfxBank 接入炮塔/弹体/爆炸 5 帧动画（0.35s 池化）：死亡/自爆/AoE/Boss 击杀；玩家弹体 bulletGreen、敌方红/暗弹体 |
| 16（P1） | done | `scripts/systems/net/net_codec.gd`、`scripts/systems/game_session.gd`（relay/apply）、`scripts/core/events/{score_changed,power_up_pickup,power_up_expired,enemy_health_changed}_event.gd` | temp_assets 与旧粒子依赖全仓清零（`grep temp_assets|assets/particles` scenes/scripts/resources/assets 四目录 0 命中）；新事件全部进 NetCodec 中继清单并携带 player_id |
| P1 网络/审计 | done | — | GUT 48 脚本 312/312（新增 27 用例）；headless 冒烟 `--quit-after 60` EXIT=0；i18n zh/en 各 296 键（键集奇偶校验 0 差异）；`tools/update_locales.py` 已同步新增结构键与 content 键；截图：`user://captures/arcade_hud_warning|active_{1280x720,1920x1080}.png`（read_image 已复核：章节横幅/分数/连击/buff 计时/BossBar 精英·巨兽/爆炸帧/炮塔/弹体/罗盘） |
| 反馈修复 | done | `scripts/systems/{fx_burst,vfx_bank}.gd`、`tools/capture_runner.gd`、`scenes/enemy/enemy_view.gd`、`scenes/base/{turret.tscn,turret_view.gd}`、`scenes/player/player_view.gd`、`scenes/vfx/{enemy_projectile,turret_tracer}.gd`、`scenes/ui/hud.gd`、`scripts/systems/game_session.gd`、`tests/unit/test_fx_burst.gd` | ①爆炸 SpriteFrames 显式 `set_animation_loop(false)` + FxBurst 兜底定时隐藏（0.35s+ε 强制 stop+hide），新增 `get_active_explosion_count()` 回归测试，spawn→0.6s 后可见数归零（313/313）；②炮塔放大至 1.15、弹体/枪口焰放大，素材默认朝上 → 炮管/弹体/枪口焰 +PI/2 对齐弹道；③HUD 方向文字雷达/罗盘箭头从游戏剔除（仅数量档+精英标记）；④玩家 HITSCAN 权威发射点改为枪口世界坐标（`PlayerView.MUZZLE_LOCAL_POS` 随瞄准旋转），射击口与枪口/弹迹一致 |
| 17（P2） | done | `scripts/systems/run_config.gd`（ENDLESS）、`scripts/core/wave/wave_director.gd`（infinite_loop/cycle_index/difficulty_cycle_scale）、`scripts/core/events/{wave_warning,wave_started}_event.gd`、`scripts/systems/{net_codec,game_session}.gd`、`scenes/ui/hud.gd`、`scenes/ui/main_menu.{gd,tscn}`、`tests/unit/test_endless.gd` | 无尽模式：4 章循环、每循环难度 ×1.15、永不判胜、失败入榜；cycle_index 入事件/中继/HUD（`无尽 · 循环 N · 第 M 波`）；主菜单新增“无尽模式”按钮；test_endless 2/2（两循环无 RunVictory + 事件 cycle 正确） |
| 18（P2） | done | `scripts/core/score/meta_progress.gd`、`scripts/systems/game_session.gd`（起始军械库 + 结算战功）、`scenes/ui/{main_menu,result_panel}.gd`、`tests/unit/test_meta_progress.gd` | 最小 meta：`user://meta.json`（version=1）战功货币 = max(1, floor(score/1000))；阈值自动解锁 AR-2(1)/SG-2(2)/LMG-1(4)/ER-1(6)，解锁后进起始军械库（改枪台可装备）；主菜单显示战功与下一解锁；test_meta_progress 3/3 |
| 19（P2） | done | `scripts/core/events/chapter_reward_picked_event.gd`、`scenes/ui/chapter_reward_panel.{gd,tscn}`、`scripts/systems/{content_bootstrap,game_session}.gd`、`scripts/core/registry/bulwark.gd` | 章间三选一：Boss 波（非最终/无尽）暂停弹三选一面板（复用 PowerUp 池，3 选 1 即时生效），选择后恢复；host 权威；截图人工复核通过 |
| 20（P2） | done | `locales/zh.json`、`locales/en.json`、`tools/update_locales.py`、`scenes/ui/hud.gd`、`scenes/ui/chapter_reward_panel.gd` | 叙事便签：4 章开场白 `lore.chapter.1..4` 双语；章首横幅第二行显示便签，章末三选一面板副标题复用；i18n zh/en 309/309 校验通过 |
| P2 回归 | done | — | GUT 53 脚本 / 318 用例 / 318 通过（新增 endless 2、meta_progress 3）；headless 冒烟 `--quit-after 60` EXIT=0；i18n zh/en 各 309 键（键集差异 0）；截图：主菜单（无尽按钮+战功 7 全解锁）与章间三选一面板（read_image 已复核）|
| 横幅排版反馈 | done | `scenes/ui/hud.tscn`、`scenes/ui/hud.gd` | 叙事便签合并回章节横幅：窄居中 560×92 标题条内两行排版（标题 26px 金色 / 便签 16px 半透明），完整显示且不再压右上 HUD；复活提示下移避免重叠；GUT 318/318、headless 冒烟 EXIT=0、1280 截图复核通过 |
