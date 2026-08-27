# Bulwark「前线壁垒」后续开发计划：UI 收口 + 手感补全（v1）

> 状态：**计划草案，未执行**
> 上游输入：`docs/review/self-audit-v2.md`（进一步自审）、`docs/review/game-review.md`（首轮评审）、`docs/design/arcade-improvement-plan.md`（P0–P2 街机化实施状态）
> 当前待决：UI 方向 **A 像素优先统一** vs **B 扁平军事化升级**（M0 拍板，默认建议 A）
> 本文档同时作为下一轮“理解 → 审查 → 执行”三阶段交接的载体（见 §6）

---

## 0. 背景与问题定义

### 0.1 人工反馈（本轮明确）

> “主菜单 / UI 设计仍然不够合格，UI 风格与游戏风格不是很搭配且不够精致。”

### 0.2 自审已确认的根因（证据）

| 问题 | 证据 | 影响 |
|---|---|---|
| 主菜单无记忆点 | `main_menu.tscn`：64×64 渐变底 + 居中文字按钮，无标题美术/徽章/装饰/图标 | 第一眼无法与“像素军事防线”建立联想 |
| 世界与 UI 双风格 | 世界 = Kenney 像素 + 8px VFX；UI = 圆角 8–12 StyleBoxFlat + 半透明阴影矢量卡片 | 同屏拼贴感，廉价感主要来源 |
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
2. UI 与游戏风格一致且精致：统一主题变体、像素化/军事化材质、8pt 排版节奏、动画节奏一致。
3. 补全人工反馈的上限问题：后坐力真正影响准星/弹道，并可视化 bloom。
4. 修掉自审发现的集成裂缝（meta 命名空间等）。
5. 全程保持：i18n 双语、GUT 全绿、三分辨率不破版、截图人工复核。

### 1.2 Non-goals（本计划不做）

- 不做搜刮/探索循环、Boss 阶段、新章节数值设计等大玩法。
- 不重做战斗数值/平衡（只做反馈与视觉）。
- 不做联网协议重构（仅按需扩展 `ShotFiredEvent` 字段并向后兼容）。
- 不删除既有主题作为唯一回退：重构期间保留旧主题可用，直到终验收。

---

## 2. 设计方向（M0 拍板，默认建议 A）

| 维度 | A：像素优先统一（推荐） | B：扁平军事化升级 |
|---|---|---|
| 世界层 | 保持不变（Kenney 像素） | 保持不变 |
| UI 语言 | 像素字体 + 1px 硬边 + 像素纹理条 + 像素图标；去掉大圆角/软阴影 | 保留 StyleBoxFlat，但加纹章/警示纹/图标/金属渐变/硬描边 |
| 标题 | 像素大字（含中文像素字体，回退 MiSans）+ 描边/阴影分层 + 徽章 | MiSans 加大字距/描边/军规编号体 + 纹章 |
| 成本 | 中 | 低-中 |
| 风格统一度 | ★★★★★ | ★★★ |
| 风险 | 中文字体覆盖、字号可读性 | 若只加图标不加排版，仍可能“廉价” |

**共同起步动作（无论 A/B）**：
1. 建立 `theme_type_variation`：`MilitaryButton / CardRare / SlotBadge / PixelProgress / BannerPanel` 等，替换“每卡片 new StyleBoxFlat”。
2. 启用闲置资产：110 SVG 图标 → 先做 20 个核心图标（HP/弹药/资源/基地/分数/连击/波次/商店/设置/多人/退出/路径/武器/配件/道具/胜利/失败/复活/制作/购买）。
3. 进度条改 `TextureProgressBar`（像素块填充）；准星热态接入。
4. `m5-visual-qa-checklist.md` 同步当前 `UiPalette` 令牌并补齐 8pt/动效验收项。

---

## 3. 里程碑计划

### M0 — 视觉决策与资产盘点（0.5–1 天）

- [ ] 与人类确认方向 A/B（默认 A）。
- [ ] 盘点可复用素材：icons（110 SVG）、cursors（4 张）、Kenney 坦克/箭头/UI 包、`VfxBank` 纹理、`UiPalette`。
- [ ] 选定/生成像素字体（必须含中文；确定 fallback 策略）。
- [ ] 产出《视觉规格表》：色板扩展、字号阶梯、边框/角标、图标映射、动效时长（≤250ms）、像素基准（8/16/32px）。
- [ ] 结论：**展示 1-2 张像素级 mockup（可用临时场景或画布），人工确认后再进入 M1。**

验收：视觉规格表 + mockup 截图人工复核通过；未确认前不写代码。

### M1 — Theme / 组件基底重构（1–2 天）

- [ ] 重写/扩展 `assets/theme/minimal_vector.tres`：基础样式 + `theme_type_variation` 全家桶。
- [ ] 新建 `Assets/theme/pixel_overlay.tres`（A 方案）或 `military_flat.tres`（B 方案）作为可选叠加层。
- [ ] 新建 `PixelProgressBar`（TextureProgressBar 子类）与 `IconLabel`/`IconButton`（图标 + 文字，双通道，颜色/字号走 Theme）。
- [ ] 建立 `UiIcon`（静态工具类：图标资源 → TextureRect；只用已入库 assets/icons 或 VfxBank 纹理）。
- [ ] `UiPalette` 扩展：边框/警示纹/稀有度图标色/像素色阶。
- [ ] 迁移 `shop_panel.gd` 卡片为 Theme 变体（删除 `StyleBoxFlat.new()` 路径，保留 `duplicate()` 稀有度边框）。

验收：旧 UI 不破版（`check_resolutions.gd` PASS）；商店/设置/结算三处截图对比如改造前有明显质感提升；GUT 全量不回归。

### M2 — 主菜单重做（2–3 天，重点）

- [ ] 背景：像素战场剪影 / 暗色俯视地图 + 网格 + 警示纹（静态可接受，动态入场加分）。
- [ ] 标题区：像素大字 + 描边 + 副标题 + 阵营徽章/国徽风纹章；标题进场（0.2–0.3s 淡入 + 上浮）。
- [ ] 按钮：像素卡片（1px 硬边、斜纹 hover、图标位、按下 1px 下沉）；focus 琥珀描边；键盘/gamepad 焦点链完整。
- [ ] 按钮区微动效：hover 抬升/亮度、按下回弹、入场 stagger。
- [ ] 元菜单：战功/下一解锁 徽章化（图标 + 数字）；版本角标样式化；多人房间表单对齐新主题。
- [ ] 中英文各一份语言切换即时生效；**无任何硬编码用户可见文案**。

验收：1280×720 / 1920×1080 / 21:9 三张主菜单截图人工复核；与旧截图对比“不再廉价”；焦点链、双语、无硬编码；`main_menu.tscn` 无脚本错误。

### M3 — HUD 与各面板精致化（2–3 天）

- [ ] HUD 数据条：HP/基地/Boss 换 `PixelProgressBar`；资源/弹药/分数/连击加图标。
- [ ] 8pt 间距节奏：TopLeft/TopRight/BottomLeft 改 Margin + Container 体系（不再手写像素 offset）。
- [ ] 波次横幅：像素大字 + 锯齿/警示边；Boss 血条 + 名称徽章。
- [ ] 连击/伤害数字：现有 `DamageNumber` 改为像素字体层（或无则加描边/描影）。
- [ ] 商店/结算/设置/三选一全面板统一 Theme 变体 + 进出场动画（`BaseModalPanel` 统一，设置面板补进场）。
- [ ] 波间/暂停/结算面板的稀有度、价格、状态徽章全部走 UiPalette + UiIcon。

验收：战斗 HUD 1280/1920 截图复核（可读性、不破版、风格统一）；面板全场景三分辨率实例化 PASS；无脚本错误。

### M4 — 手感补全（可与 M1–M3 并行，2 天）

- [ ] 后坐角接入裁决：`ShotFiredEvent` 携带“后坐后实际瞄准方向”（新增字段，向后兼容）；`GameSession` 用 `apply_spread(aim_rotated(recoil_angle), spread, rng)`。
- [ ] 准星热态：heat/HEAT_MAX 驱动 `target_a → target_round_b`（或 `cross_small → cross_large`）；换弹/切枪进度保持现有五帧。
- [ ] 震屏方向修正：`_shake_axis` 改为反冲方向（`-aim_dir` 或后坐脉冲反方向）。
- [ ] 设置面板新增：鼠标灵敏度、震屏开关/强度、准星样式、散布可视化开关（版本化 `settings.cfg` 兼容）。
- [ ] 测试：`test_recoil_affects_aim`（后坐角 → 弹道偏离）、`test_cursor_bloom_state`（heat → 光标帧）、`test_meta_namespace_integration`（meta 解锁 → 改枪台可装备）。

验收：新测试通过；GUT 全量；主观手感：连射时准星明显扩散、弹道被后坐推走、LMG/霰弹冲击感提升。

### M5 — 回归与交付（1 天）

- [ ] GUT 全量（`godot --headless -s addons/gut/gut_cmdln.gd --path .`）。
- [ ] `tools/check_architecture.gd`、`tools/check_resolutions.gd`、headless 冒烟。
- [ ] i18n 双语键奇偶（新增键进 `tools/update_locales.py` 过程）。
- [ ] 截图采证（GL Compatibility）：主菜单、HUD 预警、HUD 战斗、商店/设置/结算各 1280 + 1920；read_image 人工复核。
- [ ] 双人冒烟（`tools/run-dual.ps1`，可选，Network 改动后必做）。
- [ ] 文档同步：`m5-visual-qa-checklist.md` 令牌/勾选、`gunplay-attachment-notes.md` 手感状态、本计划执行状态表。
- [ ] 提交：feat/fix 分提交 + 推送；交付清单（变更文件 + 证据 manifest）。

---

## 4. 整体验收标准（Gate）

1. 主菜单/UI：人工视觉复核通过（“风格一致、不再廉价”），三分辨率截图无破版。
2. 手感：后坐力影响准星/弹道有测试 + 人工确认；准星有热态；设置项生效且持久化。
3. 工程：GUT 全量通过；ARCH/RES/冒烟 PASS；无新增脚本错误/deprecated 警告（新增除外）。
4. i18n：zh/en 键集奇偶一致；无硬编码用户可见文本（有历史保留格式符除外，需注明）。
5. 性能：无新增每帧 `get_node/load/new StyleBoxFlat`；热路径不劣化（可选 profiler 对比）。

---

## 5. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| 方向未拍板导致返工 | 高 | M0 必须出 mockup + 人工确认后才进 M1 |
| 像素字体中文覆盖差 | 中 | 先测字体覆盖；正文回退 MiSans；标题+数字用像素字 |
| Theme 重构波及所有 UI 场景 | 中 | 分批替换（M1 组件 → M2 菜单 → M3 HUD/面板），每批跑 RES_CHECK + 截图 |
| 图标重绘/加工工作量 | 中 | 先做 20 核心里程碑，其余 P2；优先用已有 110 SVG 做“像素化/描边化”而非重绘 |
| 后坐力裁决改动影响多人 | 中 | 事件字段向后兼容 + host 权威 + 双人冒烟 |
| 手感数值过度 | 低 | 可调参数集中；提供默认保守值 + 设置项 |
| 计划范围膨胀 | 中 | 本计划严格 Non-goals；新增需求进 P2 或单独计划 |

---

## 6. 交接提示词（三个阶段，独立可复制）

> 以下三个提示词按顺序使用：**理解计划 → 审查计划 → 执行计划**。
> 每步产出写入 `docs/design/` 或 `docs/review/`，并在完成后报告。

### 6.1 提示词一：理解计划

```text
【角色】你是 Bulwark「前线壁垒」（Godot 4.7 mono / GDScript，路径 E:\godot_learning\projects\godot_dsh_test）的“计划理解 Agent”。
【你的任务】深入理解《docs/design/ui-polish-plan.md》（后续开发计划）与上游输入，产出《docs/design/ui-polish-understanding.md》，供下一阶段审查。

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
```

### 6.2 提示词二：审查计划

```text
【角色】你是 Bulwark「前线壁垒」的“计划审查 Agent”（Godot 4.7 / GDScript / 像素风波次防守射击）。
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
- 只审查、只输出评审文档；不改计划文档本身（修改意见以“清单”形式给出，由人类批准后由执行 Agent 落）。
- 不执行任何游戏代码改动；可运行只读检查（git status、grep、read）。
- 若发现计划引用的证据已过时，明确写“过时，需以理解文档的核对结果为准”。
- 输出完成后报告：评审结论、必须修正项数量、是否建议先拍板设计方向。
```

### 6.3 提示词三：执行计划

```text
【角色】你是 Bulwark「前线壁垒」的“执行 Agent”（Godot 4.7 mono / GDScript；项目路径 E:\godot_learning\projects\godot_dsh_test）。
【你的任务】按《docs/design/ui-polish-plan.md》执行尚未完成的里程碑，并以“每里程碑一提交、全量验收后推送”的方式交付。

【前置要求】
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
```

---

## 7. 结论

本轮主线是 **UI 视觉基建 + 主菜单重做**（M0–M3），手感补全（M4）与已知缺陷修复并行，最后以全量回归 + 人工视觉复核收口（M5）。方向 A/B 是唯一需要人类在 M0 拍板的关键决策；三个交接提示词已按“理解 → 审查 → 执行”准备，可直接复制给下一轮 Agent。
