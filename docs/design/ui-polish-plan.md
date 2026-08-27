# Bulwark「前线壁垒」后续开发计划：UI 收口 + 手感补全（v2 审查修订）

> 状态：**v2（第 2 轮审查修订）— M0 已拍板；M1–M4 已执行（2026-08-27，见 `ui-polish-execution-report.md`）；M5 回归与交付进行中**
> 上游输入：`docs/review/self-audit-v2.md`（进一步自审）、`docs/review/game-review.md`（首轮评审）、`docs/design/arcade-improvement-plan.md`（P0–P2 街机化实施状态）、`docs/design/ui-polish-understanding.md`（第 1 轮理解）、`docs/design/ui-polish-review.md`（第 2 轮审查）
> 人工拍板（2026-08-27 第 2 轮）：Kenney 素材**不是像素风格**（Nearest 仅为防糊）；地图/地形多处为**近纯色块、缺素材增色**；**“像素优先统一”为错误结论** → 方向定为 **B 扁平军事化升级 + 世界层轻量增色**，A 方案仅存档参考。
> 本文档同时作为下一轮“理解 → 审查 → 执行”三阶段交接的载体（见 §6）

---

## 0. 背景与问题定义

### 0.1 人工反馈（本轮明确）

> “主菜单 / UI 设计仍然不够合格，UI 风格与游戏风格不是很搭配且不够精致。”

### 0.2 自审已确认的根因（证据）

| 问题 | 证据 | 影响 |
|---|---|---|
| 主菜单无记忆点 | `main_menu.tscn`：64×64 渐变底 + 居中文字按钮，无标题美术/徽章/装饰/图标 | 第一眼无法与“像素军事防线”建立联想 |
| 世界与 UI 双风格 | 世界 = Kenney **低清卡通**素材 + 8px VFX（Nearest 仅为防糊；地形多处近纯色块）；UI = 圆角 8–12 StyleBoxFlat + 半透明阴影矢量卡片 | 同屏拼贴感，廉价感主要来源 |
| 信息载体单一 | 商店/HUD/按钮几乎全文字；`assets/icons/` 110 SVG **0 引用**；备用准星 3 张 0 引用 | 无图标层级、无视觉节奏 |
| 控件质感单调 | 圆角+1px 边框+阴影是唯一质感；无纹理进度条（`TextureProgressBar`）、无角标/警示纹/铆钉/破旧处理 | 精致度不足 |
| 排版系统未对齐 | `m5-visual-qa-checklist.md` 8pt 间距节奏未勾选；HUD 用固定像素 PanelContainer，层级靠字号 | 专业度不足 |
| 手感链路缺口（人工反馈#1） | `_recoil_angle` 无消费者；准星固定 `target_a.png` 单帧；弹道只走 `spread+heat` | 后坐力不作用于准星/弹道，高射速武器手感上限低 |
| 已知集成缺陷 | `MetaProgress.UNLOCK_MODELS` 字符串缺 `bulwark:` 命名空间 → 改枪台解析失败 | meta 玩法不闭环 |

### 0.3 结论

下一轮的核心是**一次“视觉基建 + 分层替换”改造**，而不是零散的“美化补丁”：
先定方向 → 重构 Theme/组件基底 → 主菜单 → HUD/各面板 → 并行补手感链路 → 全量回归。

---

## 1. 目标与边界

### 1.1 目标

1. 主菜单达到“像素军事防线”的视觉语言：有标题美术、有图标、有装饰层级、有微动效。
2. UI 与游戏风格一致且精致：统一主题变体、**军事化/卡通扁平材质（与 Kenney 低清素材同源，Nearest 防糊）**、8pt 排版节奏、动画节奏一致。
2b. 世界层**轻量增色**（仅素材层）：用仓库已有 Kenney 素材（tiles/props/oilSpill/sandbag/crate/tank 部件）为纯色块地形补层次与装饰，与 UI 风格同调；不重做玩法/地形网格/新素材包。
3. 补全人工反馈的上限问题：后坐力真正影响准星/弹道，并可视化 bloom。
4. 修掉自审发现的集成裂缝（meta 命名空间等）。
5. 全程保持：i18n 双语、GUT 全绿、三分辨率不破版、截图人工复核。

### 1.2 Non-goals（本计划不做）

- 不做搜刮/探索循环、Boss 阶段、新章节数值设计等大玩法。
- 不重做战斗数值/平衡（只做反馈与视觉）。
- 不做联网协议重构（仅按需扩展 `ShotFiredEvent` 字段并向后兼容）。
- 不删除既有主题作为唯一回退：重构期间保留旧主题可用，直到终验收。
- **世界层增色仅限“素材层”**：只复用仓库已有 Kenney 素材做装饰/层次/纹理变化；不重做地形网格、不新增素材包、不做玩法/氛围系统。

---

## 2. 设计方向（M0 拍板结论：**人工已否决 A，采用 B + 世界层增色**）

| 维度 | A：像素优先统一（**已否决**，仅存档参考） | B：扁平军事化升级（**采用**）+ 世界层增色 |
|---|---|---|
| 世界层 | 保持不变（Kenney 像素——**表述错误**：Kenney 为低清卡通/扁平，非像素） | **轻量增色**：用已有 Kenney 素材（tiles/props/oilSpill/sandbag/crate/tank 部件）替换/覆盖纯色块观感，加装饰与层次；不重做玩法 |
| UI 语言 | （否决）像素字体 + 1px 硬边 + 像素纹理条 + 像素图标 | 保留 StyleBoxFlat 体系，但加纹章/警示纹/图标/金属渐变/硬描边；纹理与字体层级与 Kenney 低清素材同调（Nearest 防糊） |
| 标题 | （否决）像素大字 + 中文像素字体 | MiSans 加大字距/描边/军规编号体 + 纹章；可选标题级像素化字体（候选 Fusion Pixel Font OFL-1.1，**先测中文覆盖**，未过则保留 MiSans 层级） |
| 成本 | 中 | 低-中 |
| 风格统一度 | ★★★★★（前提错误） | ★★★★（加入世界增色 + 排版后） |
| 风险 | 中文字体覆盖、字号可读性 | 若只加图标不加排版/世界增色，仍可能“廉价”——故本计划**强制**：排版系统（8pt）+ 世界层增色 + 军事纹章三者一起做 |

**共同起步动作（B 方向确定）**：
1. 建立 `theme_type_variation`：`MilitaryButton / CardRare / SlotBadge / MilitaryProgress / BannerPanel` 等，替换“每卡片 new StyleBoxFlat”。
2. 启用闲置资产：110 SVG 图标 → 先做 20 个核心图标；**注意现有 SVG 缺 HP/弹药/武器/道具等军事语义图标**，缺项用 VfxBank/Kenney 素材（bulletGreen/explosion/crateMetal 等）兜底或新绘，M0 规格表给出映射表。
3. 进度条改 `TextureProgressBar`（**军事化分段纹理**；纹理可运行时生成或复用 Kenney UI 素材，Nearest/lossless/无 mipmap）；准星热态接入。
4. `m5-visual-qa-checklist.md` 同步当前 `UiPalette` 令牌并补齐 8pt/动效验收项。
5. **世界层增色盘点**：纯色块地形点位、可用素材清单、装饰散布方案（M0 盘点入规格表，M1 执行）。

---

## 3. 里程碑计划

### M0 — 视觉决策与资产盘点（0.5–1 天）

- [ ] ~~与人类确认方向 A/B~~ **已拍板：B 扁平军事化 + 世界层增色**（方向不再重开；本步改为 mockup 人工确认）。
- [ ] 盘点可复用素材：icons（110 SVG，**标注缺项**）、cursors（9 张，含 3 张备用准星）、Kenney 素材（tiles/props/muzzle/bullet/explosion/tank）、`VfxBank` 纹理、`UiPalette`、纯色块地形点位（`scenes/world/main.tscn` Ground/Zone/网格/噪声点）。
- [ ] 选定军事化字体层级：标题/数字用“军规编号体”或候选像素化标题字体（**候选 Fusion Pixel Font，OFL-1.1，先做中文覆盖测试**）；正文 MiSans 兜底；无授权/覆盖不足时标题回退 MiSans 加大字距/描边。
- [ ] 产出《视觉规格表》：色板扩展、字号阶梯、边框/角标、图标映射（标注缺项兜底）、动效时长（≤250ms）、**素材基准（Kenney Default size 16/32/64 + 8px VFX）**、世界增色点位与素材清单。
- [ ] 结论：**展示 1–2 张军事化 mockup（临时场景或画布：主菜单 + HUD/世界增色概念），人工确认后再进入 M1。**

验收：视觉规格表 + mockup 截图人工复核通过；未确认前不写主题/字体代码。

### M1 — Theme / 组件基底重构 + 世界层增色（1–2 天）

- [ ] 重写/扩展 `assets/theme/minimal_vector.tres`：基础样式 + `theme_type_variation` 全家桶（MilitaryButton / CardRare / SlotBadge / MilitaryProgress / BannerPanel）。
- [ ] 新建 `assets/theme/military_flat.tres`（B 方案叠加层；A 方案 pixel_overlay.tres **不建**）。
- [ ] 新建 `MilitaryProgressBar`（TextureProgressBar 子类，军事化分段纹理）与 `IconLabel`/`IconButton`（图标 + 文字，双通道，颜色/字号走 Theme）。
- [ ] 建立 `UiIcon`（静态工具类：图标资源 → TextureRect；只用已入库 assets/icons 或 VfxBank 纹理；图标/纹理只预载或静态缓存，禁止每帧 load）。
- [ ] `UiPalette` 扩展：边框/警示纹/稀有度图标色/军事色阶；**并把 `hud.tscn` 现有的 HUD 条/徽章颜色并入 UiPalette/Theme**（消除 `StyleBoxFlat_hp_fill`/`StyleBoxFlat_base_fill` 与 UiPalette 的漂移）。
- [ ] 迁移 `shop_panel.gd` 卡片为 Theme 变体（删除 `StyleBoxFlat.new()` 路径，保留 `duplicate()` 稀有度边框）。
- [ ] **验收工具前置**：扩 `tools/check_resolutions.gd`（加 `settings_panel.tscn`、`chapter_reward_panel.tscn`，共 6 场景）；新建/扩展采证脚本支持 `--shop/--settings/--result`（GL Compatibility）。
- [ ] **世界层轻量增色**：围绕基地/区域用已有 Kenney 素材（sandbag/crate/oilSpill/tank 部件/tile 变体）补装饰与层次，替换“纯色块”观感；不改玩法/网格。
- [ ] **资产导入审计**：新增纹理/图标/字体 Nearest + lossless + 无 mipmap + 无 Retina；验证 `theme_type_variation` 在 Godot 4.7 `.tres` 的持久化方式（先临时场景验证再批量）。
- [ ] i18n：新增键进 `locales/zh.json`+`en.json`（同键同参），跑 `tools/update_locales.py` + 键奇偶校验。

验收：`check_resolutions.gd`（6 场景）PASS；商店/设置/结算三处截图（before/after）有明显质感提升 + `read_image` 复核；HUD 颜色走 UiPalette（grep 校验无漂移）；世界增色 before/after 截图对比通过；GUT 全量不回归。

### M2 — 主菜单重做（2–3 天，重点）

- [ ] 背景：暗色俯视军事地图 + 网格 + 警示条纹 + Kenney 素材点缀（坦克剪影/沙袋/油渍；静态可接受，动态入场加分）。
- [ ] 标题区：MiSans 加大字距 + 描边 + 副标题 + 阵营徽章/国徽风纹章（若 M0 像素化标题字体通过覆盖测试则标题/数字用该字体）；标题进场（0.2–0.3s 淡入 + 上浮）。
- [ ] 按钮：军事卡（1px 硬边、斜纹 hover、图标位、按下 1px 下沉）；focus 琥珀描边；**键盘/gamepad 焦点链完整**（`focus_neighbor` + `grab_focus()`）。
- [ ] 按钮区微动效：hover 抬升/亮度、按下回弹、入场 stagger（≤250ms，重入 kill）。
- [ ] 元菜单：战功/下一解锁 徽章化（图标 + 数字）；版本角标样式化；多人房间表单对齐新主题。
- [ ] 中英文各一份语言切换即时生效；**无任何硬编码用户可见文案**（新增键进 locales）。

验收：1280×720 / 1920×1080 / 21:9 三张主菜单截图人工复核；与旧截图对比“不再廉价”；焦点链（键盘 + gamepad）、双语、无硬编码；`main_menu.tscn` 无脚本错误；GUT 全量不回归。

### M3 — HUD 与各面板精致化（2–3 天）

- [ ] HUD 数据条：HP/基地/Boss 换 `MilitaryProgressBar`（TextureProgressBar，军事化分段纹理）；资源/弹药/分数/连击加图标（UiIcon，缺失语义用 Kenney/VfxBank 兜底）。
- [ ] 8pt 间距节奏：TopLeft/TopRight/BottomLeft 改 Margin + Container 体系（不再手写像素 offset）。
- [ ] 波次横幅：军事化大字 + 锯齿/警示边；Boss 血条 + 名称徽章。
- [ ] 连击/伤害数字：现有 `DamageNumber` 改为军事化字体层/描边（MiSans + 双描边，或通过 M0 测试的标题字体）。
- [ ] 商店/结算/设置/三选一全面板统一 Theme 变体 + 进出场动画（`BaseModalPanel` 统一，设置面板补进场）；**与 M4 设置项改动串行（M3 → M4），避免共用文件冲突**。
- [ ] 波间/暂停/结算面板的稀有度、价格、状态徽章全部走 UiPalette + UiIcon。
- [ ] i18n：新增文案/图标 tooltip 键进 locales（同键同参）并跑奇偶校验。

验收：战斗 HUD 1280/1920 截图复核（可读性、不破版、风格统一）；面板全场景（6 场景）三分辨率实例化 PASS；无脚本错误；GUT 全量不回归。

### M4 — 手感补全（可与 M1–M3 并行，2 天）

- [ ] **Meta 命名空间修复（P0 级，可在 M1 前先修）**：`MetaProgress.UNLOCK_MODELS` 字符串补 `bulwark:` 前缀（或 `_get_model`/`ResourceLocation.from_string` 兼容无命名空间）——GUT 已复现 `Invalid ResourceLocation format: weapon/model/lmg_1|er_1`。
- [ ] 后坐角接入裁决（**权威层设计**）：后坐角状态移入 `PlayerController`（core，host/OFFLINE 驱动）；`WeaponSlots.try_fire` 发布 `ShotFiredEvent` 时携带“后坐后实际瞄准方向”（新增字段，向后兼容）；`GameSession._on_shot_fired` 用 `apply_spread(aim_after_recoil, spread, rng)`；client 仅表现（事件中继镜像），host 权威。
- [ ] 准星热态：heat/HEAT_MAX 驱动 `target_a → target_round_b`（或 `cross_small → cross_large`，M0 mockup 定）；换弹/切枪进度保持现有五帧；**client 端 heat 数据源：玩家快照新增 heat 字段（默认 0，向后兼容）**，或客户端按射击事件本地估算（二选一，默认快照字段）。
- [ ] 震屏方向修正：`_shake_axis` 改为反冲方向（`-aim_dir` 或后坐脉冲反方向）。
- [ ] 设置面板新增：鼠标灵敏度、震屏开关/强度、准星样式、散布可视化开关（版本化 `settings.cfg` 兼容，`SettingsManager.SETTINGS_VERSION` 预留迁移）；**与 M3 串行（M3 先做动画/主题，M4 再改设置项）**。
- [ ] NetCodec：`EVT_SHOT_FIRED` 新增 key 常量 + 编解码双向测试；旧 payload 无新 key 时读取默认值（向后兼容）。
- [ ] 测试：`test_recoil_affects_aim`（后坐角 → 弹道偏离）、`test_cursor_bloom_state`（heat → 光标帧）、`test_meta_namespace_integration`（meta 解锁 → 改枪台可装备）、`test_net_codec_shot_recoil`（新 key 兼容）。

验收：新测试通过；GUT 全量；主观手感：连射时准星明显扩散、弹道被后坐推走、LMG/霰弹冲击感提升；**双人冒烟（`tools/run-dual.ps1`）必做**（Network 改动后）。

### M5 — 回归与交付（1 天）

- [ ] GUT 全量（`godot --headless -s addons/gut/gut_cmdln.gd --path .`）。
- [ ] `tools/check_architecture.gd`、`tools/check_resolutions.gd`（**6 场景**）、headless 冒烟。
- [ ] i18n 双语键奇偶（新增键进 `tools/update_locales.py` 过程；zh/en 键集差异 0）。
- [ ] 截图采证（GL Compatibility，非 headless）：主菜单、HUD 预警、HUD 战斗、**商店/设置/结算、三选一、准星热态（低/高热）、世界增色 before/after**各 1280 + 1920；read_image 人工复核。
- [ ] 双人冒烟（`tools/run-dual.ps1`，Network 改动后**必做**）。
- [ ] 文档同步：`m5-visual-qa-checklist.md` 令牌/勾选（深海军蓝×钢蓝×琥珀）、`gunplay-attachment-notes.md` 手感状态、本计划执行状态表、ui-polish-understanding/review 修订指向。
- [ ] 提交：**每里程碑一个 commit**（feat/fix/docs 分开）+ 记录回滚点（commit hash）；完成后 `git push origin main`；交付清单（变更文件 + 证据 manifest：file/test/image/run）。

---

## 4. 整体验收标准（Gate）

1. 主菜单/UI：人工视觉复核通过（“风格一致、不再廉价”），三分辨率截图无破版。
2. 手感：后坐力影响准星/弹道有测试 + 人工确认；准星有热态；设置项生效且持久化。
3. 工程：GUT 全量通过；ARCH/RES（6 场景）/冒烟 PASS；无新增脚本错误/deprecated 警告（新增除外）。
4. i18n：zh/en 键集奇偶一致；无硬编码用户可见文本（有历史保留格式符除外，需注明）；新增键同键同参。
5. 性能：无新增每帧 `get_node/load/new StyleBoxFlat`；新纹理按 Nearest + lossless + 无 mipmap + 无 Retina；图标/字体只预载或静态缓存；热路径不劣化（可选 profiler 对比）。
6. 世界层：增色 before/after 截图对比通过——以素材/装饰替代“纯色块”观感，且不破坏战斗可读性。

---

## 5. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| 方向未拍板导致返工 | 高 | ~~M0 拍板 A/B~~ **已拍板 B + 世界层增色**；M0 仍须出 mockup + 人工确认后才进 M1 |
| 中文字体覆盖/授权 | 中 | 先测候选字体（Fusion Pixel Font OFL-1.1）中文覆盖；正文回退 MiSans；**确认许可（OFL/商用）后再入库**；覆盖不足 → 标题回退 MiSans 加大字距/描边 |
| 动画与焦点链回归 | 中 | M2/M3 验收含“键盘/gamepad 焦点链完整 + 重入 kill”；对照 `m5-visual-qa-checklist` 动效项 |
| Theme 重构波及所有 UI 场景 | 中 | 分批替换（M1 组件 → M2 菜单 → M3 HUD/面板），每批跑 RES_CHECK（6 场景）+ 截图；旧主题保留回退 |
| 图标重绘/加工工作量 | 中 | 先做 20 核心里程碑，其余 P2；**现有 110 SVG 缺军事语义图标**，缺项用 VfxBank/Kenney 素材兜底或新绘，M0 规格表定映射 |
| 后坐力裁决改动影响多人 | 中 | 事件字段向后兼容（新 key + 默认值）+ host 权威 + **双人冒烟必做** |
| client 端 heat/准星数据源 | 中 | 玩家快照新增 heat 字段（向后兼容）或客户端本地估算；**默认：快照字段 + net_codec 测试** |
| 手感数值过度 | 低 | 可调参数集中；提供默认保守值 + 设置项 |
| 世界层增色范围膨胀 | 中 | 明确“仅素材层、复用已有 asset、不改玩法/网格”；M0 点位图 + M1 前后截图验收 |
| `theme_type_variation` / TextureProgressBar 4.7 兼容 | 中 | M1 前用临时场景验证 `.tres` 持久化与主题属性，再批量替换 |
| 采证/验收工具缺口 | 中 | M1 前置扩 `check_resolutions.gd`（6 场景）与采证脚本（--shop/--settings/--result/--cursor）；已写入 M1/M5 任务 |
| 计划范围膨胀 | 中 | 本计划严格 Non-goals；新增需求进 P2 或单独计划 |

---

## 6. 交接提示词（同一对话内连续三轮）

> 以下三个提示词按顺序使用：**理解计划 → 审查计划 → 执行计划**。
> 它们不是三个独立对话，而是**同一对话中的连续三轮**：第 2 轮在第 1 轮的产出与上下文上继续，第 3 轮在前两轮结论上执行。
> 每轮结束时只交付本轮的产物，然后**停下等待下一条提示（或人类确认）**，不要跨轮提前动手。

### 6.1 提示词一：理解计划

```text
【回合】这是同一对话的**第 1 轮（理解计划）**。本会话已有上下文（含自审结论与计划），请沿用；不要当作新对话重新开场。
【角色】你是 Bulwark「前线壁垒」（Godot 4.7 mono / GDScript，路径 E:\godot_learning\projects\godot_dsh_test）的计划理解者。
【你的任务】深入理解《docs/design/ui-polish-plan.md》（后续开发计划）与上游输入，产出《docs/design/ui-polish-understanding.md》，供下一轮审查。

【必读】
1. docs/design/ui-polish-plan.md（本计划）
2. docs/review/self-audit-v2.md（进一步自审报告）
3. docs/review/game-review.md（首轮评审）
4. docs/design/arcade-improvement-plan.md（仅看执行状态表与 §8 决策点）
5. 按需读：assets/theme/minimal_vector.tres、scripts/systems/ui_palette.gd、scenes/ui/main_menu.tscn、scenes/ui/hud.tscn、scenes/ui/shop_panel.gd、scenes/player/player_view.gd、scripts/systems/cursor_state_machine.gd、scripts/core/score/meta_progress.gd

【工作方式】
1. 先加载 using-godot-skill-duo，确认路由；需要时阅读 godot-ui / godot-code-review / hud-system / player-controller / godot-testing 的 SKILL.md。
2. 用 read/glob/grep 核实计划中每一条“事实证据”是否与当前代码一致（例如 _recoil_angle 是否仍无消费者、MetaProgress 字符串是否仍无命名空间、StyleBoxFlat.new() 是否仍在 shop_panel）。
3. 用 bash 快速跑基线：git status、GUT 全量（export APPDATA="$PWD/.appdata"; godot --headless -s addons/gut/gut_cmdln.gd --path "$PWD"）、tools/check_resolutions.gd、tools/check_architecture.gd（无需截图）。

【输出《docs/design/ui-polish-understanding.md》（中文，必须包含）】
- 一、一句话目标：计划最终要达成什么。
- 二、现状核对表：计划引用的每条证据 → 实测是否成立（成立/已过时/需修正）。
- 三、范围边界：本计划“做什么/不做什么”，列出与自审报告其他建议的取舍。
- 四、里程碑拆解：M0–M5 各自的输入/输出/验收，指出你认为最可能有歧义的一处。
- 五、设计方向意见：A 像素优先 vs B 扁平军事化，你倾向哪个、为什么、需要人拍板的 3 个具体问题（如字体选择、圆角策略、是否保留矢量 HUD 层）。
- 六、风险与未知：影响执行的关键风险、需要提前验证的技术点（如中文字体覆盖、TextureProgressBar 素材、准星热态切换帧）。
- 七、给审查者的重点问题列表（最多 8 条）。

【硬约束】
- 本阶段只读/只写理解文档，不改任何游戏代码、场景、资源。
- 不臆测：凡引用代码/资源，必须给出文件与行号；不确定就写“待核实”。
- 输出完成后报告：理解文档路径、基线测试结果（GUT 是否全绿）、待拍板问题列表。
- **本轮到此结束**：交付后停止，等待第 2 轮提示词；不要进入审查或执行。
```

### 6.2 提示词二：审查计划

```text
【回合】这是同一对话的**第 2 轮（审查计划）**。继续沿用本会话；第 1 轮的《docs/design/ui-polish-understanding.md》与结论已在上下文中（若缺失，先读该文件再继续）。
【角色】你是 Bulwark「前线壁垒」（Godot 4.7 / GDScript / 像素风波次防守射击）的计划审查者。
【你的任务】审查《docs/design/ui-polish-plan.md》与《docs/design/ui-polish-understanding.md》的可行性、完整性与风险，产出《docs/design/ui-polish-review.md》（含 PASS/FAIL 与修正建议）。

【必读】
1. docs/design/ui-polish-plan.md
2. docs/design/ui-polish-understanding.md
3. docs/review/self-audit-v2.md
4. 按需读：assets/theme/minimal_vector.tres、scripts/systems/ui_palette.gd、scripts/systems/game_session.gd、tools/check_resolutions.gd、tools/capture_arcade.gd、tests/（unit/integration 代表性文件）

【审查维度（逐项给分：PASS / 有风险 / FAIL）】
- A. 目标一致性：是否真的解决“主菜单/UI 不合格、风格不搭、不精致”，是否与人工反馈 #2 对齐。
- B. 完整性与依赖：M0–M5 是否有遗漏任务；顺序是否合理；并行项是否有冲突（如 Theme 重构与 HUD 改造共用文件）。
- C. 验收标准可测性：每条验收是否有可执行命令/截图/测试；是否可被“人工复核”明确判定。
- D. 工程约束：GDScript 分层、i18n 硬约束、Theme 单一事实源、GUT 门禁、多人 host 权威是否被遵守。
- E. 性能与资产：是否引入每帧 new/load；图标/字体/纹理导入策略（Nearest、lossless、无 mipmap）是否明确。
- F. 风险与缓解：风险表是否覆盖主题重构波及面、中文字体、动画与焦点链、网络字段扩展。
- G. 可回退性：是否有“改坏了能回退”的方案（旧主题保留/分批替换/单提交粒度）。

【输出《docs/design/ui-polish-review.md》（中文）】
- 总评：通过 / 有条件通过 / 退回（一句话理由）。
- 分项结论表：A–G 每项的状态 + 具体证据 + 修正建议。
- 必须修正项清单（进入执行前需改计划文档的条目，编号后附建议文本）。
- 建议新增的测试/截图/采证项（含文件路径与命令）。
- 推荐下一步：按原计划执行 / 先做 M0 mockup 再批准 M1–M5 / 其他。

【硬约束】
- 只审查、只输出评审文档；不改计划文档本身（修改意见以“清单”形式给出，由人类批准后由执行者落）。
- 不执行任何游戏代码改动；可运行只读检查（git status、grep、read）。
- 若发现计划引用的证据已过时，明确写“过时，需以理解文档的核对结果为准”。
- 输出完成后报告：评审结论、必须修正项数量、是否建议先拍板设计方向。
- **本轮到此结束**：交付后停止，等待第 3 轮提示词；不要提前执行。
```

### 6.3 提示词三：执行计划

```text
【回合】这是同一对话的**第 3 轮（执行计划，最终交付轮）**。继续沿用本会话；第 1 轮理解结论与第 2 轮评审结论均已在上下文中（若缺失，先读 docs/design/ui-polish-understanding.md 与 docs/design/ui-polish-review.md 补齐再开始）。
【角色】你是 Bulwark「前线壁垒」（Godot 4.7 mono / GDScript；项目路径 E:\godot_learning\projects\godot_dsh_test）的计划执行者。
【你的任务】按《docs/design/ui-polish-plan.md》执行尚未完成的里程碑，并以“每里程碑一提交、全量验收后推送”的方式交付。

【前置要求】
0. 先回顾第 1 轮“现状核对表”与第 2 轮“必须修正项/推荐下一步”；若评审结论为“退回/有条件通过”，先修订计划文档（或向人类请示），取得批准后再动代码。
1. 若《docs/design/ui-polish-review.md》存在且含“退回/有条件通过”，先按其中“必须修正项清单”修订计划文档（或向人类请示），取得批准后再动代码。
2. 若设计方向 A/B 未拍板：执行 M0 时先出《视觉规格表》+ mockup 截图，向人类确认后再进入 M1；未被确认前不得批量替换主题/字体。
3. 先加载 using-godot-skill-duo，并按其路由加载：godot-ui、godot-code-review、hud-system、player-controller、input-handling、godot-testing、godot-optimization；需要时读 GD 参考 godot-ui-theming、godot-genre-shooter。

【执行纪律】
- 每个里程碑：先 todo 规划 → 小步实施 → 局部验证 → 截图/测试 → 提交（feat/fix/docs 分开）。
- 涉及 UI 文案：一律走 locales/zh.json + en.json（同键同参），禁止硬编码用户可见文本；新增键后运行 tools/update_locales.py 并做键集奇偶校验。
- 涉及 Theme：以 UiPalette 与 Theme 资源为单一事实源；禁止在 _ready/刷新里 new StyleBoxFlat；必须用 theme_type_variation 或 duplicate 后再改。
- 涉及手感：后坐角进裁决（host 权威），ShotFiredEvent 新增字段向后兼容；client 仅表现。
- 涉及性能：不得在 _process/_physics_process 中新增 get_node/load/资源创建；新增纹理按 Nearest + lossless + 无 mipmap。
- 多人改动涉及 NetCodec/事件：跑 tools/run-dual.ps1 或至少说明未跑原因。

【每里程碑必跑（完成即记录结果）】
- GUT：export APPDATA="$PWD/.appdata"; godot --headless -s addons/gut/gut_cmdln.gd --path "$PWD"
- 架构/UI：godot --headless --path "$PWD" -s res://tools/check_architecture.gd；godot --headless --path "$PWD" -s res://tools/check_resolutions.gd
- 冒烟：godot --headless --path "$PWD" --quit-after 60
- 截图（必须非 --headless）：
  godot --path "$PWD" --rendering-method gl_compatibility -s res://tools/capture_arcade.gd -- --menu --cap-size=1280x720
  godot --path "$PWD" --rendering-method gl_compatibility -s res://tools/capture_arcade.gd -- --showcase --cap-size=1280x720
  godot --path "$PWD" --rendering-method gl_compatibility -s res://tools/capture_arcade.gd -- --showcase --cap-size=1920x1080
  截图存至 docs/review/evidence/<milestone>_<名称>_<分辨率>.png，并用 read_image 人工复核（部分 UI 需临时脚本补拍商店/设置/结算，如需要先写 tools/ 下采证脚本并说明）。
- i18n：启动装载 zh/en 键数一致；无硬编码检查（grep 场景/脚本中的可见字符串字面量）。

【交付输出】
- 最终报告（Markdown）：每里程碑改动文件清单、测试结果、截图路径与复核结论、是否有遗留 TODO、是否达到 §4 整体 Gate。
- 提交：按里程碑拆 commit（避免一个大 commit）；完成后 git push origin main；报告交付证据清单（file/test/image/run 类型）。
- 若中途失败：不隐瞒；列出失败项、证据、建议下一步；不要为了“看起来完成”而跳过验收。

【硬约束】
- 不越过 Non-goals（不做搜刮/探索循环、Boss 阶段、数值重构等）；确有需要先停下向人类请示。
- 不修改 addons/ 第三方插件源码。
- C# 无法在会话内编译；如必须改 C#，先说明并停在编辑器构建这一步。
- **最终交付轮**：完成后给出最终报告与证据清单；若中途因人类决策点（如方向 A/B、字体选择）暂停，明确列出待确认事项与恢复步骤，等人类回复后继续，不要擅自替人类拍板。
```

---

## 7. 结论

本轮主线是 **UI 视觉基建 + 主菜单重做 + 世界层轻量增色**（M0–M3），手感补全（M4）与 meta 命名空间等已知缺陷修复并行，最后以全量回归 + 人工视觉复核收口（M5）。方向已由人工拍板（**B 扁平军事化升级 + 世界层增色**，A 已否决）；M0 仍须出《视觉规格表》+ mockup 截图并经人工确认后才可进入 M1。三个交接提示词已按“**同一对话内连续三轮**（理解 → 审查 → 执行）”准备，复制后按顺序在同一会话中发出即可。
