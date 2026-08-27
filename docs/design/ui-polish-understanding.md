# Bulwark「前线壁垒」UI 收口计划 — 理解文档（第 1 轮）

> 轮次：第 1 轮（理解计划）
> 日期：2026-08-27（本轮实测）
> 对象：`docs/design/ui-polish-plan.md`（后续开发计划）
> 上游输入：`docs/review/self-audit-v2.md`、`docs/review/game-review.md`、`docs/design/arcade-improvement-plan.md`（执行状态表 + §8）
> 依据技能：`using-godot-skill-duo`（路由）；阅读吸收 `godot-ui` / `hud-system`（SKILL.md，确认 Theme 单一事实源、`TextureProgressBar` 建议、8pt 排版建议与计划一致）
> 约束：本阶段只读 / 只写本理解文档；未修改任何游戏代码、场景、资源、数据。
> ⚠️ **修订说明（第 2 轮审查后）**：本文第 1 轮中的“Kenney 像素”表述与 §五 5.1 的 **A 推荐**已被第 2 轮人工修正否决（Kenney 素材为低清卡通/扁平而非像素；地形多处近纯色块）。**最终方向以计划 v2 与 `ui-polish-review.md` 为准：B 扁平军事化升级 + 世界层轻量增色。**

---

## 一、一句话目标

把「主菜单 / UI 风格与 Kenney 低清卡通军事世界不搭、不够精致」的问题，用一次**视觉基建 + 分层替换**改造解决：先定方向（**B 扁平军事化 + 世界层轻量增色**，A 已否决）→ 重构 Theme/组件基底 → 重做主菜单 → 精致化 HUD 与面板 → 并行补上"后坐力→准星/弹道"手感链路与 meta 命名空间裂缝 → 全量回归与人工视觉复核收口。

---

## 二、现状核对表（计划引用的每条证据 → 本轮实测）

> 结论列：✅ 成立（与代码一致）／⚠️ 需修正（局部过时或表述不准确）／❌ 已过时（与当前代码不符）。凡引用代码均给文件+行号。

| # | 计划 §0.2 证据 | 本轮实测（文件:行号） | 结论 |
|---|---|---|---|
| 1 | 主菜单无记忆点：`main_menu.tscn` 64×64 渐变底 + 居中文字按钮，无标题美术/徽章/装饰/图标 | `scenes/ui/main_menu.tscn`：`GradientTexture2D_bg` width=64 height=64（L10-15）；`TitleLabel` 58px（L64-70）；`SubLabel` 17px + 英文副标题（L72-78）；5 个 280×46 按钮（L87-118，Single/Endless/Multi/Settings/Quit）；`MetaLabel` 纯文字（L97-103）；`VersionLabel` 纯文字（L234-249）。全场景无图标/纹章/装饰节点 | ✅ 成立 |
| 2 | 世界与 UI 双风格：世界=Kenney 像素 + 8px VFX；UI=圆角 8–12 StyleBoxFlat + 半透明阴影矢量卡片 | `assets/theme/minimal_vector.tres`：按钮/面板圆角 8–10（L16-19、L32-35、L48-51、L66-69、L84-87、L197-202）、阴影 3–8px（L52-53、L70-71、L201-202）；`scenes/ui/hud.tscn` HP/基地条圆角 5（L6-18）；`scenes/ui/shop_panel.gd` 卡片圆角 8 + 阴影 4（L339-348）。世界层为 Kenney **低清卡通**素材 + VfxBank 8px/runtime（`assets/sprites/chars`、`assets/vfx/kenney` 等；**已复核 `soldier1_stand.png`/`tankBody_dark.png` 为卡通/扁平而非像素画**；`tile_01.png` 64×64 近纯色块）。⚠️ 此条文字需按第 2 轮修正 | ✅ 成立（表述需修正：Kenney 非像素） |
| 3 | 信息载体单一：商店/HUD/按钮几乎全文字；`assets/icons/` 110 SVG **0 引用**；备用准星 3 张 0 引用 | `grep assets/icons` 在 scenes/scripts/resources 均 0 命中（仅 `.import` 与 docs 命中）；`grep target_round_b / cross_large / cross_small` 在 scenes/scripts/resources 均 0 命中；`assets/cursors/` 实际含 `target_a.png` + 备用 3 张 + progress 5 帧（glob 确认）。图标文件数：glob 100/110（结果已 spill，全文 110 个），与审计一致 | ✅ 成立（补充：见 §六 图标映射缺口） |
| 4 | 控件质感单调：圆角+1px 边框+阴影是唯一质感；无 `TextureProgressBar`、无角标/警示纹/铆钉/破旧处理 | `minimal_vector.tres` 全为 StyleBoxFlat（1px 边框 + 圆角 + 阴影）；`grep TextureProgressBar` 全仓 0 命中；`hud.tscn` 血条/基地/Boss 条均为 `ProgressBar` + StyleBoxFlat（L167-173、L196-202、L239-246）；无警示纹/铆钉节点或样式 | ✅ 成立 |
| 5 | 排版系统未对齐：`m5-visual-qa-checklist.md` 8pt 间距节奏未勾选；HUD 用固定像素 PanelContainer，层级靠字号 | `docs/design/m5-visual-qa-checklist.md` L33「8pt 间距节奏（4/8/12/16/24）」仍为 `[ ]`（L20-23 动效若干项同样未勾）；`hud.tscn` TopLeft offset_left=16/offset_right=312（L143-149）、TopRight（L175-184）、BottomLeft（L256-265）均手写像素 offset；HUD 无 MarginContainer 体系 | ✅ 成立 |
| 6 | 手感链路缺口：`_recoil_angle` 无消费者；准星固定 `target_a.png` 单帧；弹道只走 `spread+heat` | `scenes/player/player_view.gd`：`_recoil_angle` 仅写入/衰减（L77、L451、L324-327），全项目无任何读取者；`visual.rotation` 只读 `controller.aim_direction.angle()`（L428）；`scripts/systems/cursor_state_machine.gd` COMBAT 固定 `CROSS_TEXTURE = target_a.png`（L9、L95）；`scripts/systems/game_session.gd` `total_spread = (stats.spread + heat) * move_mult`（L1720）→ `apply_spread(muzzle_dir, ...)`（L1740），无后坐角参与 | ✅ 成立 |
| 7 | 震屏方向注释与实现疑似不符（`_shake_axis` 非反冲方向） | `player_view.gd` L344：`_shake_axis = aim_dir.rotated(deg_to_rad(-pulse))`，pulse 仅为 ±0.6°×recoil.x（L450），不是 `-aim_dir`；L342 注释宣称「后坐脉冲反方向」 | ✅ 成立（次级问题，计划 M4-③ 已列入） |
| 8 | Meta 解锁字符串缺 `bulwark:` 命名空间 → 改枪台解析失败 | `scripts/core/score/meta_progress.gd` L12-17：`{"model": "weapon/model/ar_2", ...}` 均无前缀；`addons/mc_game_framework/utils/resource_location.gd` L40-51：`from_string` 无冒号 → 返回 null + 警告；`scenes/ui/shop_panel.gd` L566-573：`_get_model` 对 null 直接返回 null（解锁武器不出现在改枪台列表）；`scripts/systems/game_session.gd` L303-305 把原始串追加进 `Arsenal`。**本轮 GUT 集成测试日志实测复现**：`WARNING: Invalid ResourceLocation format: weapon/model/lmg_1 / er_1`，栈为 `resource_location.gd:46` → `shop_panel.gd:570`（`_refresh_models`）→ `game_session.gd:1082`（`_on_wave_cleared`）→ `test_m1_game_session.gd:155` | ✅ 成立（已实锤复现） |
| 9 | 主题无 `theme_type_variation`，shop 卡片用 `StyleBoxFlat.new()` | `grep theme_type_variation` 全仓（.tres/.gd）0 命中；`scenes/ui/shop_panel.gd` L332（卡片）与 L384（价格徽章）各 `StyleBoxFlat.new()` 一次；价格徽章 `"¥%d"` 字面量 L402 | ✅ 成立 |
| 10 | 设置面板（`UIPanel`）无进场动画；`BaseModalPanel` 有 0.22s 进场 | `scenes/ui/settings_panel.gd` L2 extends `UIPanel`，无任何 tween；`scenes/ui/base_modal_panel.gd` L9 `ENTER_DURATION := 0.22`，L39-51 进场 tween；商店/暂停/结算/三选一均 extends `BaseModalPanel` | ✅ 成立 |
| 11 | `m5-visual-qa-checklist.md` 仍写旧绿色系令牌（`#0B0F0D/#AD9A40/#3FBFAD`），与当前 `UiPalette`（深海军蓝×钢蓝×琥珀）不符 | `m5-visual-qa-checklist.md` L13-14：绿色系令牌；`scripts/systems/ui_palette.gd` L9-39：`BG_DEEP(0.024,0.033,0.047)` / `BORDER(0.25,0.33,0.44)` / `ACCENT(0.96,0.74,0.28)`；`project.godot` L57 默认主题 `minimal_vector.tres` | ✅ 成立（计划 M1/M5 需同步，注意计划 §2 公共步 4 已列） |
| 12 | 世界与 UI 素材现状（world = Kenney 像素 + 8px VFX） | `assets/sprites/chars/*`（Kenney 32px 低清卡通）、`assets/vfx/kenney/*`（炮塔/弹体/爆炸/枪口焰/碎片，VfxBank 单一入口 `scripts/systems/vfx_bank.gd`）；`scenes/world/main.tscn` L12-196：Ground/Zone 为 tile 平铺 + 网格线/环形线 + 8 个 6px 噪声点，**无装饰/道具填充**；`arcade-improvement-plan.md` 执行状态表 L375-402 显示 P0–P2+反馈修复全部 done，`temp_assets` 相关引用已清零。⚠️ 表述需修正：Kenney 为低清卡通，非像素 | ✅ 成立（表述需修正） |

### 本轮补充发现（计划未列/需修正的项）

1. **meta 修复缺少显式执行任务**：计划 §1.1 目标 4 与 §0.2 都说要修，但 M0–M5 任务清单中只有 M4 测试项 `test_meta_namespace_integration`（§3 M4），**没有"给 `MetaProgress.UNLOCK_MODELS` 补 `bulwark:` 前缀（或 `_get_model` 兼容）"的代码任务**。建议在 M4（或提前到 M1 前作为 P0 修复）补一行显式任务。
2. **`check_resolutions.gd` 覆盖不全**：`tools/check_resolutions.gd` L5-10 只实例化 `main_menu / pause_panel / result_panel / shop_panel`，**缺 `settings_panel.tscn`、`chapter_reward_panel.tscn`（也未含 hud）**；计划 M3 验收写「面板全场景三分辨率实例化 PASS」但目前工具未覆盖，需扩场景或按面板另测。
3. **`TextureProgressBar` 无素材**：仓库没有任何"像素进度条纹理"（`assets/**/*.png` 列表无 bar/segment 纹理），计划 M1 的「像素块填充」需要新建纹理（运行时 `ImageTexture` 或 Kenney UI 素材），导入策略需按 Nearest/lossless/无 mipmap（`project.godot` L68 `default_texture_filter=0` 已满足 Nearest）。
4. **110 SVG 与「20 个核心图标」映射缺口**：现有 `assets/icons/` 分类为 feedback/media/emoji/arrow/device/misc/user/ui（见 glob 列表），**没有 HP/弹药/资源/基地/武器/配件/道具/胜利/失败/复活/制作/购买等军事/战斗语义图标**；计划说「优先用已有 110 SVG 做像素化/描边化而非重绘」，但核心 20 图标大概率需要新增或借用 VfxBank/Kenney 素材（如 `bulletGreen1`、`explosion1`、`crateMetal`），属工作量不确定项。
5. **`_recoil_angle` 常量与裁决侧 heat 脱节**：后坐角表现值在 `player_view.gd`（`RECOIL_PER_SHOT=0.6`，L23），而散布用 heat 在 `scripts/core/player/player_controller.gd`（`HEAT_MAX=4.0 / HEAT_PER_SHOT=0.15`，L35-37）；两者是两套数值体系，M4 接入时需决定权威层与数值口径（见 §四歧义、§七 Q1）。
6. **client 端拿不到 heat**：`game_session.gd` L1622-1625 玩家快照 payload 只有 aim/hp/max_hp/state，**不含 heat**；`game_session.gd` L1698-1699 client 直接 return（不维护 heat）。M4「准星热态按 heat/HEAT_MAX 驱动」若在 client 表现，需新增快照字段或客户端本地估算，属待定技术点。

---

## 三、范围边界（做什么 / 不做什么，与自审建议的取舍）

### 3.1 本计划做什么（按 §1.1 + §2 共同起步动作）

| 块 | 内容 | 对应自审 §6 |
|---|---|---|
| 视觉基建 | `theme_type_variation`（MilitaryButton/CardRare/SlotBadge/PixelProgress/BannerPanel 等）+ `UiPalette` 扩展 + `UiIcon`/`IconLabel`/`IconButton`/`PixelProgressBar` 组件 + Theme 重写/叠加层 | P0-3 |
| 资产启用 | 110 SVG → 20 核心图标；`TextureProgressBar`；3 张备用准星启用 | P0-3 / P0-1 |
| 主菜单 | 背景/标题区/按钮/微动效/元菜单/房间表单 + 焦点链 + i18n | P0-3 |
| HUD/面板 | 数据条换 PixelProgressBar、图标、8pt 排版、波次横幅、全面板 Theme 统一 + 进出场动画（含设置面板补进场） | P0-3 / P1-7 |
| 手感补全 | 后坐角进裁决、准星热态、震屏方向修正、灵敏度/震屏/准星/散布可视化设置项 | P0-1 / P0-2 |
| 集成修复 | meta 命名空间（**建议补显式任务**）| P0-4 |
| 回归 | GUT / ARCH / RES / 冒烟 / i18n 奇偶 / 截图人工复核 / 文档同步 / 提交 | P0-5 |

### 3.2 本计划不做什么（Non-goals，§1.2）

- 不做搜刮/探索循环、Boss 阶段、新章节数值设计等大玩法。
- 不重做战斗数值/平衡（只做反馈与视觉）。
- 不做联网协议重构（仅按需扩展 `ShotFiredEvent` 字段并向后兼容）。
- 不删除既有主题作为唯一回退（重构期间旧主题保留可用，直到终验收）。

### 3.3 与自审报告其他建议的取舍（明确不进本计划的项）

| 自审/评审建议 | 取舍 | 理由 |
|---|---|---|
| P1-6 方向压力设计（全新方向讨论） | **不在本计划** | 属于「有意延迟项」（自审 §4.2、街机化状态表 L395 已从 HUD 剔除方向雷达/罗盘箭头）；待专门设计后再动 |
| P1-8 性能：路障近邻缓存/炮塔目标表复用/WeaponStats 缓存/PixelRing 池化 | **不在本计划**（计划 §1.2 明确不重做战斗数值，性能也未列入） | 与「视觉收口+手感」目标不同源；建议保留为独立 P1 项 |
| P1-10 `GameSession` 拆分（2431 行） | **不在本计划** | 架构重构风险大、收益长线；与 UI 改造成本相冲突 |
| P1-9 高分榜分组/玩家名、难度选择/教学波 | **不在本计划** | 内容/系统向，非 UI 精致度或手感 |
| 自审 §4.5 小残留：`shop_panel.gd:402` `"¥%d"`、`:124` `"↺"` 字面量 | 计划未列，**建议 M3/M5 顺带处理** | i18n 硬约束；改动极小，宜随手入键并跑奇偶校验 |
| 自审 §4.1 `CursorStateMachine._process()` 每帧 `_refresh()` | 计划未列，**建议 M4 准星热态改造时顺带优化** | 与 M4 正在改同一文件；自审已指出可避免 |
| 自审 §1.2 方向雷达最短版/指南针 | 不做（同 P1-6） | 有意延迟 |

---

## 四、里程碑拆解（M0–M5：输入 / 输出 / 验收）

> M0–M5 顺序、任务与验收均按计划 §3，此处补「输入」与「最可能歧义一处」。

### M0 — 视觉决策与资产盘点（0.5–1 天）

- **输入**：计划 §2 两案对比表；自审 §3.3 两案对比；素材盘点结果（icons 110、cursors 9 张、VfxBank、UiPalette、Kenney 素材已在 `assets/`）；人类对 A/B 与字体/圆角/HUD 层的拍板。
- **输出**：《视觉规格表》（色板扩展、字号阶梯、边框/角标、图标映射、动效 ≤250ms、像素基准 8/16/32px）；1–2 张像素级 mockup 截图；人工确认结论。
- **验收**：规格表 + mockup 截图人工复核通过；**未确认前不写代码**。
- ⚠️ 前置依赖：A/B 未拍板则 M1 的 Theme 重构方向不定；M0 需先完成字体覆盖测试（见 §六）与 mockup 手段（临时场景 or 画布脚本）的确定。

### M1 — Theme / 组件基底重构（1–2 天）

- **输入**：M0 规格表 + 拍板；`minimal_vector.tres`、`ui_palette.gd`、`shop_panel.gd`、`hud.tscn` 现状。
- **输出**：Theme 全变体 + `pixel_overlay.tres`（A）/`military_flat.tres`（B）；`PixelProgressBar`、`IconLabel`/`IconButton`、`UiIcon`；`UiPalette` 扩展；`shop_panel.gd` 卡片/价格徽章迁移 Theme 变体（删除两条 `StyleBoxFlat.new()`，保留 `duplicate()` 稀有度边）。
- **验收**：旧 UI 不破版（`check_resolutions.gd` PASS——**注意工具目前缺 settings/chapter_reward 场景，需先扩**）；商店/设置/结算三处截图有质感提升；GUT 全量不回归。
- ⚠️ 风险点：Theme 波及所有 UI 场景 → 分批替换；i18n 新增键进 `locales/zh.json`/`en.json`。

### M2 — 主菜单重做（2–3 天，重点）

- **输入**：M1 组件 + M0 像素字体；`main_menu.tscn`/`main_menu.gd` 现状（含房间表单、meta 文本、版本角标、CLI `--net` 兜底 L43-50）。
- **输出**：像素战场剪影/暗色地图背景；标题区（大字+描边+副标题+徽章/纹章 + 0.2–0.3s 进场）；像素卡片按钮（1px 硬边、斜纹 hover、图标位、按下 1px 下沉、focus 琥珀描边、键鼠/gamepad 焦点链完整）；按钮微动效 + 入场 stagger；元菜单徽章化；房间表单对齐新主题；双语即时切换、零硬编码。
- **验收**：1280/1920/21:9 三张主菜单截图人工复核；与旧截图对比「不再廉价」；焦点链、双语、无硬编码；无脚本错误。
- ⚠️ 保留项：`main_menu.gd` CLI 兜底（L43-50）与 `Net` 流程不可破坏。

### M3 — HUD 与各面板精致化（2–3 天）

- **输入**：M1/M2 成果；`hud.tscn`/`hud.gd`、`shop_panel`/`result_panel`/`settings_panel`/`chapter_reward_panel`/`pause_panel`、`base_modal_panel.gd`。
- **输出**：HP/基地/Boss 换 `PixelProgressBar` + 图标；8pt 间距（Margin+Container 体系，替换手写 offset）；波次横幅像素化 + Boss 名称徽章；连击/伤害数字像素字体层/描边；全面板统一 Theme 变体 + 进出场动画（设置面板补进场）；稀有度/价格/状态徽章走 UiPalette + UiIcon。
- **验收**：战斗 HUD 1280/1920 截图复核（可读性、不破版、风格统一）；面板全场景三分辨率实例化 PASS（**需先补工具场景**）；无脚本错误。
- ⚠️ 与 M4 冲突：设置面板同时被 M3（动画/主题）与 M4（新增 4 个设置项）改动，建议串行或由同一执行者负责（见 §七 Q5）。

### M4 — 手感补全（可与 M1–M3 并行，2 天）

- **输入**：`ShotFiredEvent`（`scripts/core/events/shot_fired_event.gd`）、`WeaponSlots.try_fire`（`scripts/core/combat/weapon_slots.gd:247-270`）、`PlayerView._recoil_angle`、`CursorStateMachine`、`GameSession._on_shot_fired`、`SettingsManager`/`settings.cfg`。
- **输出**：后坐角进裁决（事件携带"后坐后实际瞄准方向"，向后兼容）；准星热态（heat/HEAT_MAX 驱动）；震屏方向修正（`-aim_dir` 或反冲脉冲方向）；设置面板新增 灵敏度/震屏开关与强度/准星样式/散布可视化（版本化 settings.cfg）；三个新测试（`test_recoil_affects_aim`、`test_cursor_bloom_state`、`test_meta_namespace_integration`）。
- **验收**：新测试通过；GUT 全量；主观手感：连射准星明显扩散、弹道被后坐推走、LMG/霰弹冲击感提升。
- **最可能歧义所在（见 §4.1）**：后坐角权威层归属 + client 端 heat/准星数据源。

### M5 — 回归与交付（1 天）

- **输入**：M1–M4 全部成果。
- **输出**：GUT 全量；ARCH/RES/headless 冒烟；i18n 键奇偶；截图采证（GL Compatibility 非 headless；主菜单/HUD 预警/HUD 战斗/商店/设置/结算各 1280+1920，read_image 人工复核；`tools/capture_arcade.gd` 目前只有 `--menu/--showcase`，商店/设置/结算需临时采证脚本，计划已注明）；双人冒烟（网络改动后必做）；文档同步（`m5-visual-qa-checklist.md`、`gunplay-attachment-notes.md`、本计划状态表）；feat/fix 分提交 + 推送；交付清单。
- **验收**：§4 整体 Gate 全过。

### 4.1 我认为最可能有歧义的一处（供审查者重点盯）

**M4「`ShotFiredEvent` 携带『后坐后实际瞄准方向』」的权威层与数据流未定义。**

- 现状：`ShotFiredEvent` 由 `scripts/core/combat/weapon_slots.gd:269`（后端 `WeaponSlots.try_fire`）发布，`aim_direction` 是**表现层注入的意图**（L248 注释"后端只发意图"）；而 `_recoil_angle` 目前只存在于 `scenes/player/player_view.gd:77`（表现层私有，只写不读）。
- 计划写了"`GameSession` 用 `apply_spread(aim_rotated(recoil_angle), spread, rng)`"（§3 M4），但没有说清：**由谁累加/衰减 recoil 角**（PlayerView 表现层？PlayerController core？GameSession 装配层？）、**事件里带的是什么**（后坐后的 aim 向量？recoil 角本身？）、**host/client 各自拿什么值**、**client 准星热态的 heat 从哪来**（当前玩家快照 L1622-1625 无 heat，client 不跑 `players[i].tick`，L188-194 仅 host）。
- 这直接影响实现量与网络改动面，也决定"向后兼容"究竟指"新增字段/新 key，旧端忽略"还是"协议版本升级"。

---

## 五、设计方向意见（A 像素优先 vs B 扁平军事化）

### 5.1 结论更新（⚠️ 第 2 轮已否决 A）

**最终方向（以第 2 轮人工修正 + 计划 v2 为准）：B 扁平军事化升级 + 世界层轻量增色。**
第 1 轮此处曾推荐 A，其前提"世界层=Kenney 像素"已被人工修正否定：
- `assets/sprites/chars/soldier1_stand.png`、`assets/sprites/turret/tankBody_dark.png` 为 Kenney **低清卡通/扁平**素材（Nearest 仅为防糊）；
- 地形多处为近纯色块（`tile_01.png` 64×64 近纯绿 + `main.tscn` 网格/噪声点），反而说明**世界层需要“增色”**而非"向像素靠拢"；
- 因此 UI 应与 Kenney 卡通/扁平风格同调（军事纹章/警示纹/图标/硬描边 + 军事化字体层级），而不是改造成像素语言。

保留（第 1 轮仍成立的判断）：纹章、警示条纹、斜纹 hover、铆钉/破旧感属于"军事视觉 DNA"，与 B 方向一致，应并入规格表；两案共有"公共项"（图标 + `theme_type_variation` + 8pt + 面板动画）不受方向影响，可先做。

### 5.2 需要人拍板的 3 个具体问题

| # | 问题 | 选项 / 影响 | 我的建议 |
|---|---|---|---|
| Q1 | **字体选择**：标题/数字用哪套军事化/编号体字体，正文是否回退 MiSans？ | 候选：开源 [Fusion Pixel Font（缝合像素字体，OFL-1.1，泛中日韩，仅作标题/数字试验）](https://github.com/TakWolf/fusion-pixel-font)（**注意：B 方向下它不是“必须”，需先测覆盖/观感**）；或 MiSans 加大字距/描边/军规编号体；或双字体层级。影响 M0 字体测试、M2 标题观感、进货成本 | 先做覆盖 + 观感测试（中文标题+数字渲染截图），默认"标题/数字尝试 Fusion Pixel（通过则用，否则 MiSans 军规化） + 正文 MiSans"；若覆盖不足回退 |
| Q2 | **圆角/硬边策略**：B 方向下 StyleBoxFlat 的圆角与描边该怎么定？ | 保留 8–12 圆角（现状）vs 收窄到 2–4px 微圆角 + 1px 硬描边 + 警示纹/铆钉装饰。影响 StyleBox 重写范围与"军事感"强度 | 建议 2–4px 微圆角 + 1px 硬描边 + 无/极小阴影，配合警示斜纹/角标；在 mockup 中二选一评估 |
| Q3 | **是否保留矢量 HUD 层**：HUD 与面板是否全量军用化（图标+纹理条+硬边卡片），还是只换主题/图标/边饰？ | 全量军用化：风格最统一（Kenney 低清同调），改动面大（hud.tscn 全部 StyleBox/字体/条重做）；只换主题/图标：成本低，但可能残留"通用扁平"观感 | 我倾向 **全量军用化（保留 StyleBoxFlat 体系但加军事 DNA + 纹理条）**，并同步世界层增色；需人在 mockup 上拍板，避免 M3 返工 |

---

## 六、风险与未知（执行前需提前验证）

| 风险/未知 | 等级 | 需要提前做的验证或设计 | 备注 |
|---|---|---|---|
| 中文字体覆盖 / 像素字号可读性 | 高 | M0 前下载候选像素字体，用 Godot `FontFile` 渲染测试：中文标题（含"前线壁垒/无尽/战功/胜利/失败"等）+ 数字 + 15–58px 阶梯截图；确认 fallback（MiSans）策略与双字体层级不失控 | 仓库当前只有 MiSans-Semibold（`assets/fonts/`，theme L3 引用 .ttf） |
| `TextureProgressBar` 素材缺失 | 中 | 确认条纹理来源：运行时 `ImageTexture`（参考 `FxBurst` get_pixel_texture/get_glow_texture 思路）或 Kenney UI 包；导入 Nearest/lossless/无 mipmap；`theme_type_variation` / TextureProgressBar 主题属性在 Godot 4.7 的写法（`minimal_vector.tres` 无先例） | 全仓无 bar 纹理；`project.godot` L68 默认 Nearest 已就位 |
| 准星热态切换帧 | 中 | 实测 4 张候选（`target_a/target_round_b/cross_large/cross_small`）尺寸/中心热点/像素风格；确定离散帧切换 vs 缩放插值；确定 heat→帧 映射（tier 或连续）；确定与换弹/切枪 PROGRESS 状态的优先级不变 | 当前 COMBAT 固定 `target_a`（cursor_state_machine.gd L9/L95），progress 5 帧已实现（L10-14、L104-119） |
| client 端 heat 数据源 | 中 | 若准星热态需在 client 表现：玩家快照新增 heat 字段（`game_session.gd` L1622-1625）或 client 本地按射击事件估算；需保持 host 权威口径一致 | client 不跑 `players[i].tick`（L188-194），heat 无本地衰减源 |
| `ShotFiredEvent` / NetCodec 字段扩展 | 中 | 明确新旧字段兼容：新 key（如 `KEY_AIM_AFTER_RECOIL`）加入 `net_codec.gd` 常量表（当前 L94-95、L125 无此键）；旧端读取忽略；host 权威 + 双人冒烟必做 | `shot_fired_event.gd` L7-9 现字段：player_id/model_location/aim_direction |
| 后坐数值体系统一 | 中 | 决定 `PlayerView.RECOIL_PER_SHOT=0.6`（L23）与 `PlayerController.HEAT_PER_SHOT=0.15`（L37）两套数值是否合并/是否保留表现/裁决分离 | 关系 M4 手感调参与测试断言 |
| Theme 重构波及所有 UI | 中 | 分批替换（M1 组件 → M2 菜单 → M3 HUD/面板）；保留旧主题可用作回退（Non-goal 4）；每批跑 RES_CHECK + 截图 | 现 `modern_flat.tres` 存在但非默认（project.godot L57 用 minimal_vector） |
| 图标工作量/映射 | 中 | 先盘点 110 SVG 中可用于"核心 20 图标"的比例；缺的（HP/弹药/资源/武器/道具等）用 VfxBank/Kenney 素材拼 or 新绘；M0 规格表给出映射表，避免执行中临时找素材 | 见 §二补充发现 4 |
| 采证工具缺口 | 中 | `capture_arcade.gd` 仅 `--menu/--showcase`（L8-17）；商店/设置/结算需临时脚本（计划 M5 已注明）；`check_resolutions.gd` 需补 settings/chapter_reward 场景 | 直接影响 M1/M3/M5 验收的"截图对比/全场景 PASS" |
| 多人手感一致性 | 低-中 | 后坐/准星若只存在于本地表现，双人下 client 可能看到"host 弹道 + 本地准星不匹配"；需明确 host 权威裁决 + client 镜像表现策略 | 计划 M5 双人冒烟为可选项，但 M4 网络改动后建议必做 |

---

## 七、给审查者的重点问题列表（≤8 条）

1. **Q1（最重要）**：M4 后坐角权威层未定义——由谁累加后坐角、`ShotFiredEvent` 携带"后坐后实际瞄准方向"还是"recoil 角"、client 准星热态的 heat 从哪来？请给出明确设计或在计划中标注"待 M4 细化"。
2. **Q2**：M0 字体来源（Fusion Pixel Font OFL？自绘？）与双字体层级（标题像素 + 正文 MiSans）是否可接受？是否需要"先做中文覆盖渲染测试+截图"作为 M0 硬验收？
3. **Q3**：`TextureProgressBar` 的像素条素材来源（运行时生成 vs 引入 Kenney UI 包）与导入策略（Nearest/lossless/无 mipmap）是否应由 M1 在计划中写明确，而不留到执行时现找？
4. **Q4**：A/B 未拍板前，M1 是否可以先做两案共有"公共项"（`theme_type_variation` + `UiIcon` + `UiPalette` 扩展 + 8pt + 面板动画），把字体/圆角/pixel overlay 的决定推迟到 M0 mockup 之后？建议在计划中明确 M1 的"前置依赖/可提前部分"。
5. **Q5**：M3（设置面板补进场/主题）与 M4（设置面板新增 4 个设置项）共用 `settings_panel.gd/.tscn`，计划写"可与 M1–M3 并行"——是否改为串行，或注明由同一执行者/同一提交负责，避免合并冲突？
6. **Q6**：Non-goal "不做联网协议重构（仅按需扩展 `ShotFiredEvent` 字段并向后兼容）"与 M4"事件新增字段"的边界：新增 NetCodec key 算不算"协议重构"？旧端兼容是否必须"读不到就忽略"并加对应测试？双人冒烟是否因此从"可选"变"必做"？
7. **Q7**：M3/M5 验收依赖 `check_resolutions.gd`（缺 settings/chapter_reward 场景）与 `capture_arcade.gd`（缺商店/设置/结算截图模式）——是否计划先扩这两个工具（或写临时采证/检查脚本）再验收？建议把"工具扩展"写进 M1 前置或 M5 任务。
8. **Q8**：meta 命名空间修复只有测试没有代码任务（§二补充发现 1），且 `m5-visual-qa-checklist.md` 旧令牌同步、`gunplay-attachment-notes.md` 手感状态更新归属哪个里程碑未明确——请在计划中补：meta 修复（建议 M4 或提前）、QA 清单同步（建议 M1）、手感文档同步（建议 M4/M5）。

---

## 附：本轮基线实测（2026-08-27）

| 验证项 | 命令/方式 | 结果 |
|---|---|---|
| git 状态 | `git status --short --branch` | 干净：`## main...origin/main`，无未提交改动 |
| GUT 全量 | `godot --headless -s addons/gut/gut_cmdln.gd --path .`（输出重定向 `.appdata/gut_baseline.log`） | **51 脚本 / 320 用例 / 320 通过 / 3513 断言 / 70.7s（exit 0）**；11 条 deprecated 警告（非失败）；与自审 v2 记录一致。⚠️ 日志同时复现 `Invalid ResourceLocation format: weapon/model/lmg_1|er_1` 警告（见 §二 #8） |
| 架构分层 | `godot --headless --path . -s res://tools/check_architecture.gd` | `ARCH_CHECK=PASS` |
| 三分辨率 UI | `godot --headless --path . -s res://tools/check_resolutions.gd` | `RES_CHECK=PASS`（1280×720 / 1920×1080 / 21:9；zh/en 各 309 条装载） |
| headless 冒烟 | `godot --headless --path . --quit-after 60` | exit 0；zh/en 各 309 条装载，无脚本错误输出 |
| i18n 装载 | 上述运行日志 | zh/en 均 **309 keys**，与自审 v2 一致 |

> 说明：本轮未做截图采证 / 视觉复核（第 1 轮无此要求）；截图与 read_image 人工复核留给 M0 mockup 与 M2/M3/M5 验收轮。
