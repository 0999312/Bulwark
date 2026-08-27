# Bulwark「前线壁垒」进一步自审报告（v2）

> 日期：2026-08-27
> 对象：Godot 4.7 (mono) GDScript 项目 `Bulwark 前线壁垒`（俯视波次防守射击）
> 口径：本次仅产出**自审报告**，不修改游戏代码 / 资源 / 数据；UI 方向在报告中给出**两案对比**，不拍板。
> 基线：`docs/review/game-review.md`（2026-08-25 第一轮评审）、`docs/design/arcade-improvement-plan.md`（P0–P2 实施状态表）。
> 依据技能：GP `using-godot-skill-duo`、`godot-code-review`、`godot-ui`（skill 加载）；GP `player-controller`、`hud-system`、`input-handling`（阅读 SKILL.md 吸收）；GD-Agentic 参考 `godot-genre-shooter`、`godot-combat-system`、`godot-ui-theming`。

---

## 0. 结论摘要（TL;DR）

| 维度 | 评价 | 一句话 |
|---|---|---|
| 内容 / 时长 | **大幅补强** | 已从“单章 6 波 / 4–8 分钟”升级为 4 章 × (3+1) 波 = 16 波约 15–25 分钟，另有无尽模式、分数连击、波中道具、章间三选一、meta 解锁、叙事便签 |
| 工程 / 回归 | **绿** | GUT **320/320**（51 脚本 / 3513 断言）通过；架构检查 PASS、三分辨率 UI 冒烟 PASS、headless 冒烟 exit 0；i18n zh/en **309/309** |
| 游戏感 | **底层扎实，但“后坐力 → 准星”链路存在真实缺口** | 热度/散布/震屏/枪口回退都在，但 `_recoil_angle` 是**无消费者死代码**：后坐力不偏移瞄准/准星，准星也**没有 bloom/扩散可视化** —— 正是人工审查点 |
| UI / 美术 | **世界与 UI 双风格，廉价感有明确来源** | 世界已是 Kenney 像素 + 像素 VFX；菜单/HUD 仍是通用“深色圆角卡片 + 单一半粗字体 + 渐变底 + 无图标无装饰”，110 个 SVG 图标 0 引用 |
| 内容缺口（仍存在） | **中低优先级 / 有意延迟** | 无搜刮/探索循环、无 Boss 阶段、无难度/教学、无手柄辅助瞄准/灵敏度/震屏设置；**方向雷达/罗盘为有意延迟项**（反馈轮已移除，等更好的设计方向，不列为缺陷） |
| 隐藏缺陷（本轮新发现） | **需修** | Meta 解锁字符串缺 `bulwark:` 命名空间 → 解锁武器在改枪台无法通过 `ResourceLocation.from_string` 解析（GUT 集成测试中出现 `Invalid ResourceLocation format: weapon/model/lmg_1` 警告），meta 玩法实际不闭环 |

**一句话**：这个项目已经从“垂直切片”长成了“功能完整的街机波次生存”，**内容与工程基础均已成型**；下一轮最该投入的是人工指出的两件事 —— **①后坐力真正作用到准星/弹道并可视化**、**②UI 风格收口去廉价感**，顺带修掉 meta 命名空间这类“实现完成但集成未闭环”的裂缝。

---

## 1. 当前进度盘点

### 1.1 对 P0–P2 街机化计划的完成态（据 `arcade-improvement-plan.md` 执行状态表 + 本轮核验）

| 模块 | 状态 | 核验证据 |
|---|---|---|
| 粒子素材收敛（20 旧 PNG 全清、Kenney 素材 38 个入库、VfxBank 单一入口） | ✅ | `grep "assets/particles\|temp_assets" scenes scripts resources assets` = 0；`scripts/systems/vfx_bank.gd` 存在 |
| 炮塔 / 弹体 / 爆炸 / 枪口焰 / 路障碎片 / 动态光替换 | ✅ | VfxBank 接入；炮塔 1.15 放大 + 朝向修正已验证 |
| 武器音效分支死代码修复（hg/sg/lmg/er 分支） | ✅ | `audio_director.gd` 按 `weapon/type/hg\|sg\|lmg\|er` 匹配 |
| 本局随机种子（波次 + 商店 + 无尽循环难度） | ✅ | `RunConfig.run_seed`；`test_run_seed`、`test_endless` |
| 章节制数据层（RunDefinition / ChapterDefinition / 4 章模板） | ✅ | `resources/runs/arcade_run.tres`、`resources/chapters/chapter_1..4.tres` |
| 分数 / 连击 / 完美波 / 章清奖励 / 本机 Top10 | ✅ | `ArcadeScore`、`HighScoreStore`（`user://highscore.json`） |
| 伤害数字（池化 24：白/黄/紫/青） | ✅ | `FxBurst` DAMAGE_POOL_SIZE=24；击中/炮塔均接线 |
| 波中道具掉落（8 种，buff 计时/到期对称） | ✅ | `PowerUpSystem` + pickup 场景；HUD buff 计时 |
| Boss 血条 + 章节横幅 + 叙事便签 | ✅ | HUD `BossBar`/`BannerLoreLabel`；zh/en 309 键 |
| 敌人轮廓差异化（装甲/狙击/飞行/自爆/精英） | ✅ | `enemy_view.gd` `_apply_outline` |
| 无尽模式（4 章循环 ×1.15，永不判胜） | ✅ | `WaveDirector.infinite_loop` |
| 最小 meta（战功货币 + 4 款起始武器解锁） | ⚠️ **完成但集成有裂缝** | `MetaProgress` 阈值逻辑完好；解锁字符串未带命名空间（见 §4.4 集成缺口与 §6 P0-4） |
| 章间三选一奖励 | ✅ | `chapter_reward_panel`；截图可见 |
| 方向雷达最短版 | ⏸ **有意延迟（待设计）** | 反馈轮明确“方向文字雷达/罗盘箭头从游戏剔除”（§4.2：尚未形成更好设计方向，待讨论，不算缺陷） |

### 1.2 内容体量（当前）

| 类别 | 数量 | 备注 |
|---|---|---|
| 章节 | 4 | 每章 3 普通波 + 章末精英 = 16 波；无尽模式循环 |
| 敌人 | 9 种 | 奔跑者/疾行者/硬壳者/自爆体/喷吐者/装甲兽/飞行体/狙击手/精英·巨兽 |
| 武器 | 5 类 × 16 型号 | AR3 + SG3 + HG4 + LMG3 + ER3；两级数据设计 |
| 配件 | 4 | 红点 / 扩容弹匣 / 制退器 / 轻量枪托 |
| 商店商品 | 35+ | 常规强化 + 武器箱 + 固定物资；按军械库过滤已拥有 |
| 道具 | 8 种 | 弹药/建材/医疗/急速射击/三连弹/护盾/分数加速/备用命 |
| 玩家系统 | — | 三槽武器/改枪/散布/后坐系数/复活/商店/分数/连击/meta |

### 1.3 本轮验证结果（2026-08-27 实测）

| 验证项 | 方式 | 结果 |
|---|---|---|
| GUT 全量回归 | `godot --headless -s addons/gut/gut_cmdln.gd --path .` | **51 脚本 / 320 用例 / 320 通过 / 3513 断言 / 74.9s**；含 11 条 deprecated 警告（非失败） |
| 架构分层检查 | `tools/check_architecture.gd` | **ARCH_CHECK=PASS**（core 无场景/渲染引用） |
| 三分辨率 UI 冒烟 | `tools/check_resolutions.gd` | **RES_CHECK=PASS**（1280×720 / 1920×1080 / 21:9） |
| 项目冒烟 | `godot --headless --path . --quit-after 60` | **exit 0**；zh/en 各 309 条翻译装载 |
| i18n 奇偶 | 启动装载 + `locales/` | **309/309 键一致** |
| 视觉采证 | `tools/capture_arcade.gd`（GL Compatibility，非 headless） | 主菜单 / HUD 预警 / HUD 战斗 / 1920 截图各 1 张，已 read_image 复核（见 §5） |

> 说明：headless 下 dummy 渲染拿不到 ViewportTexture，截图必须在 `--rendering-method gl_compatibility`（非 `--headless`）下执行；本轮已按此方式采证。

---

## 2. 专项自检 A：后坐力 → 准星/弹道链路（人工反馈#1）

### 2.1 现状（代码级事实）

| 环节 | 实现 | 证据 |
|---|---|---|
| 散布（bloom） | `GameSession._on_shot_fired()`：`total_spread = (stats.spread + heat) * move_mult`，逐弹丸 `PlayerView.apply_spread()` 随机偏移 | `game_session.gd:1717-1741`；`player_view.gd:251-255` |
| 连射热度 | `PlayerController.HEAT_PER_SHOT/HEAT_MAX/HEAT_DECAY`；裁决侧 `players[pid].heat` 累加/衰减 | `player_controller.gd:33-47,106-107`；`game_session.gd:1715-1716` |
| 后坐系数 | `WeaponTypeData.recoil = Vector2(x,y)`：x = 热度和枪口回退系数；AR(1,1) / SG(1.3,1.5) / HG(0.5,0.5) / LMG(1.5,1.8) / ER(0.6,0.8) | `weapon_type_data.gd:44-46`；`resources/weapons/type/*.tres` |
| 后坐视觉 | 震屏（方向化）+ 枪口回退 tween + 枪口焰闪现 | `player_view.gd:340-371` |
| **后坐角** | `PlayerView._recoil_angle` 每发 `±0.6° × recoil.x` 累加、弹簧恢复 | `player_view.gd:77,324-327,450-451` |

### 2.2 发现的问题

1. **后坐角是死代码（最关键）**
   `_recoil_angle` 只在 `player_view.gd` 内部写入（`_on_shot_fired`）与衰减（`_tick_gunplay`），**全项目无任何读取者**：
   - 不参与 `visual.rotation`（`player_view.gd:428` 只读 `controller.aim_direction.angle()`）；
   - 不参与 `GameSession` 的弹道裁决（裁决只使用 `stats.spread + heat` 的随机散布）；
   - 不参与准星/光标（`CursorStateMachine` 只切 `target_a.png` / 换弹进度帧）。
   结论：**当前“后坐力”= 相机震动 + 枪口回退的纯表现，瞄准点/准星完全不受后坐力影响**，与 `docs/design/gunplay-attachment-notes.md` §3“每发子弹后 aim 方向施加脉冲偏移，弹簧恢复”的设计意向不符。

2. **准星无 bloom/扩散可视化**
   - 战斗准星固定为 `assets/cursors/target_a.png`（32×32 单帧），无热态切换；
   - `assets/cursors/` 里现成可用的 `target_round_b.png`、`cross_large.png`、`cross_small.png` **零引用**；
   - 玩家看不到“连射散布在变大”，只知道“枪在抖”——信息不对称，高射速武器（LMG 14发/s）尤其明显。

3. **震屏方向注释与实现疑似不符（次级）**
   `player_view.gd:344` 写 `_shake_axis = aim_dir.rotated(deg_to_rad(-pulse))`，`pulse` 仅 ±0.6°；注释称“后坐脉冲反方向”，实际只是沿瞄准方向的微小旋转，并非反冲方向。观感上震屏更像随机抖动，缺少“被后坐力推着走”的方向感。

4. **准星位置与弹道原点脱钩**
   系统光标位置 = 鼠标屏幕点；弹道原点为枪口（`MUZZLE_LOCAL_POS` 随瞄准旋转），弹道还会随机散布 ±(spread+heat)°。准星既不走散布、也不走后坐，会让高射速下“准星在靶心、子弹却打飞”的可读性进一步下降。

### 2.3 改进建议（供后续实施，本次不改）

| # | 建议 | 预期收益 | 成本 |
|---|---|---|---|
| 1 | **后坐角接进裁决**：`ShotFiredEvent` 携带“后坐脉冲后的实际瞄准方向”，`GameSession` 用 `apply_spread(aim_rotated(recoil_angle), spread, rng)` 结算；host 权威驱动，client 镜像仅表现 | 弹道真正“被后坐推走”，可感知、可玩 | 中（涉及事件字段/网络协议/测试） |
| 2 | **准星热态**：按 `heat/HEAT_MAX` 在 `target_a → target_round_b` 或 `cross_small → cross_large` 间切换/插值；换弹/切枪进度复用现有 `CursorStateMachine` 状态机 | 散布可视化，玩家有“稳住节奏”的博弈 | 低（素材已存在） |
| 3 | **相机震屏方向修正**：`_shake_axis = -aim_dir`（或后坐脉冲反方向），幅度随 heat 提升 | 后坐方向感正确，LMG/霰弹更有冲击 | 低 |
| 4 | **可调设置**：鼠标灵敏度、震屏开关/强度、散布可视开关进设置面板 | 无障碍/玩家手感个性化 | 低-中 |
| 5 | 回归测试：新增 `test_recoil_affects_aim`（后坐角 → 弹道偏离）、`test_cursor_bloom_state`（heat → 光标帧） | 防止手感改造回归 | 低 |

> 参考：GD `godot-genre-shooter` 明确 **"Apply kick to camera rotation and spread bloom, not weapon mesh alone"** —— 当前实现恰好落在“只动 weapon mesh/camera shake”的旧模式。

---

## 3. 专项自检 B：菜单 / UI 风格与廉价感（人工反馈#2）

### 3.1 现状（代码 + 截图证据）

- 世界层：Kenney 像素角色/瓦片 + 8px 像素几何 VFX + 坦克素材拼接炮塔/弹体/爆炸 —— 风格统一，已达标。
- UI 层：项目主题 `minimal_vector.tres` 为“深海军蓝 × 钢蓝描边 × 琥珀强调”的 **StyleBoxFlat 圆角扁平体系**；主菜单为 **64×64 渐变底 + 居中标题/按钮**（`main_menu.tscn`：`GradientTexture2D_bg`、标题 58px 琥珀、副标题 17px、5 个 280×46 按钮、右下版本号）。
- HUD：纯 Label + `ProgressBar`（圆角 StyleBoxFlat 填充）+ `PanelContainer` 默认面板；无图标、无纹理条、无像素描边。
- 商店：动态卡片每张 `StyleBoxFlat.new()`（`shop_panel.gd:332-349`、价格徽章 `:384-399`），仅文字 + 稀有度色边，**无图标/图标位**。
- `assets/icons/`：**110 个单色 SVG，0 处引用**；`assets/cursors/` 备用准星 3 张 0 引用。
- 字体：全项目唯一 `MiSans-Semibold`；无像素字体/等宽军规字体，无字体层级（除字号外无字重/变体）。
- 动效：`BaseModalPanel`（商店/结算/三选一）有 0.22s 进场；**设置面板（UIPanel）无进场动画**；`m5-visual-qa-checklist.md` 的“面板进出 ≤250ms、重入 kill”仍为未勾选状态。

### 3.2 廉价感来源（结论）

1. **无“画面记忆点”**：主菜单是通用深色渐变 + 文字按钮，没有标题美术、徽章/LOGO、撕边/斜纹/警示条纹、像素装饰；任何人第一眼无法把这套菜单和“像素军事防守”联系上。
2. **世界与 UI 断层**：像素世界里出现圆润、矢量、半透明阴影的卡片；反差不是“HUD 与世界的正常对比”，而是“两套材质系统”的拼贴感。
3. **信息载体单一**：全部靠文字（商店卡片、HUD、按钮），稀有度只靠边框色和文字颜色；图标 110 个闲置，恰恰是能立刻提质的“0 成本素材”。
4. **控件质感单调**：圆角 8–12 + 1px 边框 + 阴影是当前唯一的“质感来源”；无纹理、无纹理进度条（`hud-system` 建议像素风用 `TextureProgressBar`）、无角标/旗标/警示纹。
5. **数学密度未对齐**：8pt 间距节奏在清单上仍未勾选；HUD 顶部/BottomLeft 用固定像素 PanelContainer，信息层级靠字号而非排版系统。

### 3.3 两案对比（按用户要求：只给方案，不拍板）

| 维度 | 方案 A：像素优先统一 | 方案 B：保留扁平矢量，强化军事身份 |
|---|---|---|
| 核心动作 | UI 全面转向像素语言（非位图照搬，而是“像素化处理 + 像素字体 + 1px 硬边”） | 保留 StyleBoxFlat 体系，但注入军事视觉 DNA（图标、纹章、警示条纹、徽章、更硬的描边） |
| 字体 | 像素/等宽风字体（标题用像素字，正文用现 MiSans 兜底）；可给标题做像素描边层 | MiSans 保留，增加字符间距/大小写/描边/阴影层级，标题改“军规编号体” |
| 进度条/徽章 | `TextureProgressBar`（Kenney 坦克包/UI 素材）+ 像素块填充；按钮 1px 硬边 | 现 ProgressBar 改 `theme_type_variation`：警示斜纹、裂纹、金属渐变，不引入位图 |
| 图标 | 从 110 SVG 中挑 20–30 个重绘成 8–16px 像素化图标（或直接用 Kenney UI 包） | 直接使用 110 SVG（单色线稿天然适配深色 UI），面板加 icon 位 |
| 背景/装饰 | 主菜单加像素场景剪影/像素装饰带；半透明面板自带像素噪点 | 主菜单加军事纹章、斜纹警示带、雷达网格背景；面板边框加“铆钉/破旧”纹理 |
| 风格一致性 | 与世界完全同源（推荐面） | 与“像素世界 + 矢量 HUD”组合常见，但要靠元素密度和配色防“廉价” |
| 成本 | 中（需像素字体、图标重绘/替换、主题重写） | 低-中（主要重写 Theme + 复用现有图标/素材） |
| 风险 | 需要统一“像素 UI 观感”，字号可读性要细调 | 若只换图标不换排版，有可能仍是“廉价扁平” |
| 推荐度 | ★★★★（更根治“廉价感”） | ★★★（性价比高，可作第一步） |

> 两案都建议先做**低成本公共项**：①启用闲置图标/准星；②`Theme` 增加 `theme_type_variation`（如 `MilitaryButton / CardRare / SlotBadge`）替代“每个卡片 new StyleBoxFlat”；③修正 `m5-visual-qa-checklist.md` 中过时的绿色系令牌（现为深海军蓝体系）；④补齐面板进出场动画与 8pt 间距节奏。

---

## 4. 全方面自检（其余维度）

### 4.1 代码质量与架构

- ✅ 分层干净：`scripts/core` 无场景/渲染引用（ARCH_CHECK=PASS）；前后端事件解耦成熟（EventBus + player_id 过滤）。
- ⚠️ `scripts/systems/game_session.gd` 已 **2431 行**（第一轮评审 2020 行），装配层继续膨胀成“上帝对象”：波次、商店、分数、道具、meta、多端中继、设施、胜负、冒烟全在一处；建议拆 `SessionBackend / SessionNetSync / SessionFacilities / SessionMeta`。
- ⚠️ `shop_panel.gd` 每张卡片新建 2 个 `StyleBoxFlat`（违反 GD `godot-ui-theming` “never create StyleBox in `_ready()` for many nodes”）；应改为 Theme 类型变体 + `duplicate()` 稀有度边框。
- ⚠️ `CursorStateMachine._process()` 每帧调用 `_refresh()`（虽内部早退，仍属可避免的每帧函数调用）；建议只在计时器变化/状态变化时刷新。
- ✅ 命名/类型风格基本规范：`snake_case`、类型标注齐全、`StringName` 在热路径使用良好。

### 4.2 游戏体验 / 信息可读性

- ✅ 已加分：伤害数字、暴击/弱点分色、连击/Boss 血条、buff 计时、章节横幅、命中火花/爆炸池。
- ⏸ **方向压力可读性——有意移除，待设计**：反馈轮明确从 HUD 剔除方向文字雷达/罗盘箭头，当前只有“预计中等来袭”；团队尚未形成比旧罗盘更好的设计方向，故列为**后续讨论项**而非缺陷（GDD“多方位压力管理”最终形态待定）。
- ⚠️ 无难度选择 / 教学：设置面板只有 音频 / 键位 / 语言；无操作说明页、无教学波（虽第 1 波仅有奔跑者，但无文本引导）。
- ⚠️ 无手柄辅助瞄准、无灵敏度 / 震屏开关（`AppConfig.get_camera_zoom()` 存在但未进设置），无准星大小/颜色选项。

### 4.3 性能（静态扫描，未 profiler 实测）

| 热点 | 现状 | 建议 |
|---|---|---|
| 敌人每帧全量扫路障 | `enemy_view.gd:116-117,373-376` 仍每帧遍历 barricade_query 结果 | 由 GameSession 维护存活路障数组/空间哈希，事件失效 |
| 开火每发重建目标数组 | `game_session.gd:1722-1732` 每发遍历全部敌人建 `target_enemies + targets` | 分桶/方向预筛；快照缓存 |
| 每发重复算 WeaponStats | `WeaponSlots.try_fire` 与 `GameSession._on_shot_fired` 各调一次 `get_effective_stats` | 事件携带结算快照或 dirty 缓存 |
| PixelRing 未池化 | `fx_burst.gd:152-158` 每次 `PixelRing.new()` 入树、播完自毁 | 池化或并入 FxBurst 统一环池 |
| 同屏上限 | ✅ `WaveDirector.MAX_ON_SCREEN = 40`，超限暂停刷出 | — |
| 池化 | ✅ 火花 32 / 伤害 24 / 爆炸 10 / tracer / 动态光 8 上限 | — |

### 4.4 内容 / 数据 / 平衡

- ✅ 内容量已达标（16 波 + 无尽 + 道具 + meta）。
- ⚠️ **Meta 解锁集成未闭环**：`MetaProgress.UNLOCK_MODELS` 存的是 `weapon/model/lmg_1` 这类无命名空间串，而注册表/商店/改枪台都走 `bulwark:weapon/model/...`；改枪台 `_get_model()` 对前者报 `Invalid ResourceLocation format`，解锁武器实际进不了可装备军械库（GUT 集成出现同类警告，纯元数据测试未覆盖）。
- ⚠️ **本局随机性已改善但未全开**：种子已注入波次/商店；`RunDefinition.highscore_key` 定义了但无人使用，高分榜未按 run/模式分组、无玩家名输入（仅自动 Top10）。
- ⚠️ 无“搜索/探索”回合（GDD 核心循环支柱仍缺）；无 Boss 阶段/召唤/硬直破甲（精英·巨兽仅背部弱点）。
- ⚠️ 波间商店仍可无限停留（方案曾建议可选 15–30s 倒计时，未落地）；无尽模式难度逐循环 ×1.15 未做上限保护，极后期可能数值失控。

### 4.5 i18n / 兼容

- ✅ 309/309 键奇偶一致；语言切换即时生效；内容名走 `UiText.content_name/description`。
- ⚠️ 小残留：`shop_panel.gd:402` 价格符号 `"¥%d"`、`:124` 重置按钮 `"↺"` 为字面量（非用户可读长文案，但建议入 i18n）。
- ✅ 持久化：设置/键位/高分/meta 均带版本号 + 写失败降级。
- ✅ 多人：host 权威 + 事件中继 + client 镜像降量；本章未做双人实跑（需 `tools/run-dual.ps1` 实测，建议纳入下一轮回归）。

### 4.6 文档同步

- ⚠️ `docs/design/m5-visual-qa-checklist.md` 仍写旧绿色系令牌（`#0B0F0D/#AD9A40/#3FBFAD`），与当前 `UiPalette`（深海军蓝 × 钢蓝 × 琥珀）不符；方向箭头/雷达条目与当前“仅数量档”实现不一致。
- ⚠️ `docs/design/gunplay-attachment-notes.md` §5.4 写明“后坐力：纯表现自动恢复，M1 验证后再议” —— 本轮应升级为“实现：表现层 + 裁决层均未生效（死代码）”，并作为下轮 P0。

---

## 5. 视觉证据（read_image 已复核）

| 截图 | 路径 | 内容 |
|---|---|---|
| 主菜单 1280×720 | `docs/review/evidence/menu_1280.png` | 深色渐变底、琥珀大标题、4+1 按钮、meta 提示；无任何装饰/图标/像素元素 —— 廉价感直观来源 |
| HUD 波前预警 1280×720 | `docs/review/evidence/hud_warning_1280.png` | 顶部资源/血条、右上基地/波次/分数/连击/buff/Boss 条、底部武器槽/弹药、中央章节横幅；纯文字 + 圆角条 |
| HUD 战斗（三选一面板）1280×720 | `docs/review/evidence/hud_active_1280.png` | 章间三选一模态（卡片 + 半透明压暗 + 进场缩放大体可辨），HUD 与模态同框 |
| HUD 战斗 1920×1080 | `docs/review/evidence/hud_active_1920.png` | 同上在 1080p 下不破版、HUD 贴边正常 |

> 说明：截图目录在 `.appdata/Godot/app_userdata/Bulwark 前线壁垒/captures/` 亦有原始文件（本轮为证据复制到 `docs/review/evidence/`）。

---

## 6. 建议路线图（后续实施，本次不改）

### P0（下周可做，优先解决人工反馈）

| # | 事项 | 涉及 |
|---|---|---|
| 1 | 后坐力生效：裁决层应用后坐角到弹道 + 准星热态（3 张备用光标） | `PlayerView`、`GameSession`、`ShotFiredEvent`、`CursorStateMachine`、`test_gunplay_spread/recoil` |
| 2 | 震屏方向修正 + 灵敏度/震屏开关进设置 | `player_view.gd`、`settings_panel`、`SettingsManager` |
| 3 | UI 廉价感第一刀：启用图标/纹理进度条/军事纹章 + `theme_type_variation` 重构 shop 卡片 + 主题变体 | `minimal_vector.tres`、`shop_panel.gd`、`hud.tscn`、`main_menu.tscn` |
| 4 | **修 meta 命名空间 bug**：`MetaProgress.UNLOCK_MODELS` 补 `bulwark:` 前缀（或 `_get_model` 兼容无命名空间） | `meta_progress.gd`（+ 集成测试） |
| 5 | 文档同步：`m5-visual-qa-checklist.md` 令牌、`gunplay-attachment-notes.md` 状态 | docs |

### P1

| # | 事项 |
|---|---|
| 6 | 方向压力设计（**全新方案讨论后再定**，不直接回滚旧“文字/箭头罗盘”） |
| 7 | 商店动态 StyleBox → Theme 变体；面板进出场动画补齐（含设置面板） |
| 8 | 性能：命中空间查询 + 路障近邻缓存 + PixelRing 池化 + WeaponStats 复用 |
| 9 | 高分榜按 run 分组 + 玩家名输入；难度选择/教学波 |
| 10 | GameSession 拆分（SessionBackend / SessionNetSync / SessionFacilities / SessionMeta） |

### P2

| # | 事项 |
|---|---|
| 11 | 搜索/探索回合、Boss 阶段、无尽难度上限、波间倒计时 |
| 12 | 真机 profiler + 双人实跑（`run-dual.ps1`）+ UI 截图三分辨率全量复核 |

---

## 7. 结论

1. **进度**：P0–P2 街机化内容几乎全部落地并保持全绿回归（320/320）；内容量、分数/连击/道具/meta、VFX 统一均达到“可玩原型”之上 —— 当前是完成度很高的垂直切片 + 轻量街机层。
2. **人工反馈两点均成立且有明确证据**：
   - 后坐力对准星/弹道的影响**尚未实现**（`_recoil_angle` 死代码 + 准星固定单帧），实现后手感上限会明显提升；
   - UI 廉价感来自**通用扁平卡片 + 无图标/装饰/纹理 + 世界 UI 双风格**，两案（像素优先 / 扁平军事化）均已给出对比，待决策。
3. **额外发现**：meta 解锁命名空间不闭环、设置缺灵敏度/震屏、商店动态 StyleBox、GameSession 2431 行等 —— 均为后续迭代输入；方向雷达/罗盘为**有意延迟项**（待更好设计方向，后续专门讨论）。

> 下一轮建议从 §6 的 P0-1/2/3/4 开始：先让“后坐力真正打到准星上”，再做 UI 风格收口，两者都是低风险高感知的改动。
