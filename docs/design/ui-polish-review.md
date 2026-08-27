# Bulwark「前线壁垒」UI 收口计划 — 审查文档（第 2 轮）

> 轮次：第 2 轮（审查计划）
> 日期：2026-08-27（本轮）
> 审查对象：`docs/design/ui-polish-plan.md`（后续开发计划）、`docs/design/ui-polish-understanding.md`（第 1 轮理解文档）
> 上游输入：`docs/review/self-audit-v2.md`、`docs/review/game-review.md`、`docs/design/arcade-improvement-plan.md`
> **人工修正输入（本轮，优先级最高）**：Kenney 素材**并不是像素风格**（仍需 `Nearest` 过滤仅为防糊）；当前地图/地形多处是**近纯色块、缺少素材填色**；因此"像素优先统一"的方案是**错误结论**。
> 审查方式：静态阅读 + 只读检查（read/glob/grep/git status）+ read_image 视觉复核（角色/坦克/地形 tile 素材）；未改任何代码、场景、资源、计划文档。

---

## 总评

**有条件通过。** 计划骨架（M0 拍板 → M1 基建 → M2 主菜单 → M3 HUD/面板 → M4 手感 → M5 回归）与"人工反馈 #2 + #1"的目标对齐是成立的，但**计划 §2 的默认方向（A 像素优先）与本轮人工修正矛盾——其"世界层=Kenney 像素"前提不成立**；同时存在若干必须先修正的任务/工具/验收缺口（meta 修复无显式任务、验收工具覆盖不全、M3/M4 共用文件并行冲突、M4 后坐权威层未定义、i18n 与资产导入策略不完整）。**按下列必须修正项修订计划后，先做 M0 mockup 并人工确认，再进入 M1–M5。**

---

## 一、分项结论表（A–G）

| 维度 | 结论 | 具体证据 | 修正建议 |
|---|---|---|---|
| **A. 目标一致性** | **有风险** | ① 计划 §0.1/§1.1 目标 1-4 确与人工反馈 #2（主菜单/UI 不合格、风格不搭、不精致）与 #1（后坐力）对齐，方向正确；② 但计划 §2"默认建议 A + 世界层保持不变（Kenney 像素）"与理解文档 §五 5.1 都以"世界层已像素化"为前提——**该前提已被本轮人工修正否定**：`assets/sprites/chars/soldier1_stand.png`（36×43，Kenney 低清卡通剪影）、`assets/sprites/turret/tankBody_dark.png`（38×36，卡通/扁平部件）均为低清**卡通**素材而非严格像素画；`project.godot` L68 `default_texture_filter=0`（Nearest）只是"防糊"手段，不等同于像素风；③ 地形证据：`scenes/world/main.tscn` L12-19 Ground 用 `tile_01.png` 平铺、L21-46 三 Zone 用 `tile_05.png` 平铺、L48-140 仅网格线/环形线、L142-196 仅 8 个 6px 菱形"噪声点"，无装饰/道具/障碍物填充；`assets/sprites/tiles/tile_01.png` 为 64×64 **近纯绿 + 零星杂点**——"地形纯色块"成立；④ 计划 §1.1 目标 2 写"像素化/军事化材质"、§2 共同起步 3 写"像素块填充"，均隐含像素方向 | ① 计划方向改为 **B 扁平军事化升级**（详见必须修正 #1）；② §1.1 目标 2 措辞改为"军事化/卡通扁平材质（与 Kenney 同源）"；③ **Non-goal "世界层保持不变"需修订**——增加"世界层轻量增色"（见必须修正 #2），否则"整体精致"目标无法达成 |
| **B. 完整性与依赖** | **有风险** | ① M0–M5 任务链完整、顺序合理（M0→M1→M2→M3 串行；M4 与 M1–M3 并行）；② 缺口：**meta 修复无显式代码任务**（计划 §1.1 目标 4 与 §0.2 均提及，但 §3 M0–M5 只有 M4 测试项 `test_meta_namespace_integration`）；**世界层增色未列入**；M0"选定/生成像素字体"在 B 方案下需改为"选定军事化中文字体层级/字距描边策略"；③ **并行冲突**：M3（设置面板补进场/主题，`scenes/ui/settings_panel.gd/.tscn`）与 M4（设置面板新增 4 个设置项）共用同一文件，计划写"可与 M1–M3 并行"会冲突；④ 工具依赖未前置：M1 验收"商店/设置/结算三处截图"、M3 验收"面板全场景三分辨率实例化 PASS"分别依赖 `tools/capture_arcade.gd`（现仅 `--menu/--showcase`，L8-17）与 `tools/check_resolutions.gd`（现仅 4 场景，L5-10，**缺 settings_panel.tscn / chapter_reward_panel.tscn**）——工具未扩则验收不可执行 | ① 补 meta 修复代码任务（见必须修正 #3）；② M3/M4 设置面板改动**串行化**（见必须修正 #5）；③ M0/M1 前置"验收工具扩展"（见必须修正 #4）；④ 补"世界层增色"任务（见必须修正 #2） |
| **C. 验收标准可测性** | **有风险** | ① M0/M2/M3/M5 大多有可执行验收（截图/命令/测试/人工复核），C 面总体合格；② 不可测/难判定的项：M1"商店/设置/结算三处截图对比有明显质感提升"——**未说明 old/new 基线截图路径与 read_image 复核要求**；M3"面板全场景三分辨率实例化 PASS"——`check_resolutions.gd` 未覆盖 settings/chapter_reward（见 B-④）；M4"主观手感：准星明显扩散、弹道被推走"——**无量化指标**（可测：后坐角→弹道偏移角断言、heat→帧映射断言、LMG/霰弹冲击感主观项仅作人工项）；M5 截图清单**缺设置面板/三选一/准星热态/世界增色前后对照** | ① 每处截图验收补"采证命令 + 存档路径 + read_image 复核"；② M4 增加量化断言（`test_recoil_affects_aim`：给定 recoil 角断言弹道偏离；`test_cursor_bloom_state`：heat→帧断言）；③ M3/M5 先扩工具再来验收（见必须修正 #4）；④ M4/M5 增补截图项（见"建议新增采证项"） |
| **D. 工程约束** | **有风险** | ① 分层：M1 规定"UiPalette/Theme 单一事实源、删除 `StyleBoxFlat.new()` 路径、保留 `duplicate()`"，符合架构纪律；`scripts/core` 无场景引用（`ARCH_CHECK=PASS` 本轮复核）；② i18n：计划 M2/M3 提"双语、无硬编码"，但 **M1 新增组件（IconLabel/IconButton/新增 tooltip）、M4 新增设置项（灵敏度/震屏/准星样式/散布可视化）文案未明确进 `locales/zh.json`+`en.json` 流程**；既有小残留 `shop_panel.gd:402` `"¥%d"`、`:124` `"↺"` 未列入；③ **Theme 单一事实源现状有漂移**：`scenes/ui/hud.tscn` L6-18 自定 `StyleBoxFlat_hp_fill`（绿 0.32,0.72,0.52）/ `StyleBoxFlat_base_fill`（橙 0.87,0.58,0.22），与 `scripts/systems/ui_palette.gd` L24/L29 `ACCENT(0.96,0.74,0.28)`/`SUCCESS(0.32,0.75,0.55)` **数值不一致**——HUD 未走 UiPalette；④ GUT 门禁：M1/M4/M5 有，**M2/M3 验收未列 GUT 全量**；⑤ 多人 host 权威：M4 提"host 权威 + 双人冒烟"，但任务列表未写"host 权威裁决 + client 镜像仅表现"细则与 NetCodec 新 key 双向测试 | ① i18n：M1/M4 一律"新键进双语、同键同参、per-milestone 跑 `tools/update_locales.py` + 奇偶校验"，并顺手收编 `¥%d/↺`（见必须修正 #7）；② M3 把 HUD 条/徽章颜色并入 UiPalette/Theme（见必须修正 #8）；③ 每里程碑（含 M2/M3）统一跑 GUT 全量；④ M4 明确 host 权威/clip 表现/NetCodec 兼容测试（见必须修正 #6） |
| **E. 性能与资产** | **有风险** | ① 计划 §4 Gate 5"无新增每帧 get_node/load/new StyleBoxFlat"是好的硬约束；M1 `UiIcon`（静态缓存）、Theme 变体、`duplicate()` 稀有度边框均符合；② 现状资产导入已达标：`assets/sprites/chars/soldier1_stand.png.import` L18 `compress/mode=0`（lossless）、L26 `mipmaps/generate=false`；`assets/icons/ui/settings.svg.import` 同参数 + `svg/scale=1.0`（L41）；`project.godot` L68 默认 Nearest——但 **计划 §0.2/§3 没有把这些写成审计项**；③ **新素材/字体/图标导入策略未在计划中明确**（M1 `pixel_overlay`/进度条纹理、M0 字体、SVG 图标像素化/描边化重导出）；且计划多处用"像素"措辞（§2 A 方案、共同起步 3），与 B 方向不符；④ icon 高频使用若走 `load`（未预载）或每帧 `get_node`，将违反 Gate 5，需在 M1 组件设计时防 | ① M0/M1 增加资产审计项：新纹理/字体/图标一律 Nearest/lossless/无 mipmap/无 Retina（对照现有 `.import` 参数），并补充 `theme_type_variation` 在 Godot 4.7 `.tres` 的持久化方式验证（见必须修正 #9）；② 术语随方向修正（见必须修正 #1）；③ M1 组件设计明确图标/纹理只预载或静态缓存 |
| **F. 风险与缓解** | **有风险** | 计划 §5 风险表覆盖：方向未拍板、字体覆盖、Theme 波及、图标工作量、后坐裁决影响多人、数值过度、范围膨胀——**基本面良好**；缺失：① **中文字体授权/获取**（虽写"字体覆盖差"，未提许可与候选来源）；② **动画与焦点链**（M2 有任务但风险表无"键鼠/gamepad 焦点链回归"行）；③ **client 端 heat/准星数据源**（计划 M4 写"heat/HEAT_MAX 驱动"，但玩家快照 `game_session.gd` L1622-1625 **不含 heat**，client 不跑 `players[i].tick`（L188-194），数据源未设计）；④ **世界增色范围膨胀**（若加入需明确"仅复用已有素材 + 不做玩法"）；⑤ **`theme_type_variation`/TextureProgressBar 的 Godot 4.7 兼容性**未验证；⑥ **验收工具缺口**（capture/check_resolutions）未入风险表 | 风险表补 6 行：字体许可/获取、焦点链、client heat 数据源、世界增色范围、4.7 theme API 验证、采证/检查工具缺口（对应必须修正 #1/#2/#4/#6/#9） |
| **G. 可回退性** | **PASS（附建议）** | ① Non-goal"不删除既有主题作为唯一回退"（计划 §1.2-4）+ M1 分批替换（组件→菜单→HUD/面板）+ 每批 RES_CHECK/截图，回退面可控；② M4 事件"新字段向后兼容"给网络回退留了口子；③ 现有 `assets/theme/modern_flat.tres` 可作另一层回退（project.godot L57 默认 minimal_vector）；④ 建议补充：**每里程碑一个提交**（计划执行提示 §6.3 已写，但 §3 未列，建议正式写进 §3/M5），并在 M1/M2/M3 各设一个"回滚点"（git tag 或 commit hash 记录在交付清单） | ① §3 每里程碑注明"单独提交 + 回滚点记录"；② M1 验收项加"旧主题切换回退开关可用"（可将 project.godot 临时切回 modern_flat 验证，不删除） |

---

## 二、必须修正项清单（进入执行前需改计划/理解文档，编号越靠前越优先）

| # | 文件/位置 | 建议文本（供人类批准后由执行者落） |
|---|---|---|
| **1** | `ui-polish-plan.md` §2（+ §1.1 目标 2、共同起步 3）；`ui-polish-understanding.md` §五 5.1、§二 #2/#12 | **方向修正为 B 扁平军事化升级（默认）**：① 更正"世界层=Kenney 像素"为"世界层=Kenney **低清卡通/扁平**素材（Nearest 仅为防糊）+ 少量 8px 几何 VFX；地形多为近纯色块/平铺 tile"；② A 方案从"默认推荐"改为"已由人工否决/仅存档参考"（或删除）；③ 目标 2 措辞改为"统一主题变体、**军事化/卡通扁平材质**、8pt 排版节奏、动画节奏一致"；④ 共同起步 3"像素块填充"改为"军事化分段纹理/材质填充（TextureProgressBar，纹理可程序化或复用 Kenney UI）"；⑤ 同步修正理解文档中"世界=像素"的表述与 A 推荐 |
| **2** | `ui-polish-plan.md` §1.2 Non-goals（+ §3 M1 或新增 M1.5） | **增加"世界层轻量增色"子范围**（建议 M1 或 M0 拍板后执行）：仅复用仓库已有素材（`assets/sprites/tiles/*` 变体、`assets/sprites/props/` crate/sandbag/oilSpill、`assets/vfx/kenney/*` 装饰、base/barricade 部件）为地形/地图补充装饰、层次与细节，消除"纯色块"感；明确**不做**玩法/新素材包/重做地形网格；验收=战斗 1280×720 截图人工复核"地形有细节、与 UI 协调" |
| **3** | `ui-polish-plan.md` §3（M4 或 M1 前 P0） | **补 meta 命名空间修复显式代码任务**：`MetaProgress.UNLOCK_MODELS` 字符串补 `bulwark:` 前缀（或 `shop_panel._get_model`/`ResourceLocation.from_string` 兼容无命名空间），并把 `test_meta_namespace_integration` 增强为"解锁 → 起始军械库 → 改枪台 `_get_model` 可装备"的集成断言；当前 GUT 日志已复现 `Invalid ResourceLocation format: weapon/model/lmg_1|er_1`（`resource_location.gd:46` → `shop_panel.gd:570` → `game_session.gd:1082`） |
| **4** | `ui-polish-plan.md` §3（M0/M1 前置 + M5） | **验收工具前置扩展**：① `tools/check_resolutions.gd` 增加 `scenes/ui/settings_panel.tscn`、`scenes/ui/chapter_reward_panel.tscn`（hud 需战斗上下文另行处理）；② `tools/capture_arcade.gd`（或新增 `tools/capture_ui.gd`）支持 `--shop/--settings/--result`（及 M4 需要的准星热态/世界增色对照）截图模式；③ 命令与存档路径写进 §3 对应里程碑验收 |
| **5** | `ui-polish-plan.md` §3（M3/M4 并行说明） | **设置面板改动串行化**：M3（设置面板补进场/主题）先于 M4（新增 4 个设置项），或注明"两处由同一执行者、同一提交负责"，避免并行合并冲突 |
| **6** | `ui-polish-plan.md` §3（M4） | **M4 设计细化**：明确①后坐角权威层（建议移入 `PlayerController`/`GameSession` core 状态，`PlayerView` 仅表现；或事件携带"后坐后 aim"由裁决侧生成）；②`ShotFiredEvent` 新增字段/`NetCodec` 新 key 的定义与旧端忽略规则；③client 端准星热态的 heat 数据源（玩家快照新增 heat 字段或客户端按射击事件本地估算，二选一并注明默认）；④host 权威 + client 镜像仅表现的写作顺序；⑤新增 3 个测试的断言口径（角度/帧映射/命名空间） |
| **7** | `ui-polish-plan.md` §3（M1/M4/i18n 约束段） | **i18n 补全**：M1 新增组件/图标 tooltip、M4 设置项（灵敏度/震屏开关与强度/准星样式/散布可视化）标签全部进 `locales/zh.json`+`en.json`（同键同参），并顺带收编 `shop_panel.gd:402` `"¥%d"`、`settings_panel.gd:124` `"↺"` 字面量；每里程碑运行 `tools/update_locales.py` + 键奇偶校验（0 差异） |
| **8** | `ui-polish-plan.md` §3（M3）+ `m5-visual-qa-checklist.md` | **HUD 颜色并入 UiPalette/Theme**：把 `hud.tscn` 自定 `StyleBoxFlat_*_fill`（绿 0.32,0.72,0.52 / 橙 0.87,0.58,0.22）改为读取 `UiPalette.SUCCESS/ACCENT` 等令牌（Theme 变体或 `@export`），消除"单一事实源被绕过"的漂移；M1 一并同步 `m5-visual-qa-checklist.md` 旧绿色系令牌（L13-14 `#0B0F0D/#AD9A40/#3FBFAD` → 深海军蓝×钢蓝×琥珀）与 8pt/动效勾选 |
| **9** | `ui-polish-plan.md` §3（M0/M1）+ §5 | **资产/API 审计 + 术语**：① 新纹理/字体/图标导入审计项：Nearest、lossless、无 mipmap、无 Retina（对照 `soldier1_stand.png.import` L18/L26、`settings.svg.import` L41）；② SVG 图标"像素化/描边化"给出具体重导出或着色方案（现 `svg/scale=1.0` 直接使用可能发虚）；③ M1 前置验证 `theme_type_variation` 与 `TextureProgressBar` 主题属性在 Godot 4.7 的 `.tres` 持久化方式（建议先用临时场景验证再批量替换）；④ 删除/替换计划内全部"像素"误导措辞（见 #1） |
| **10** | `ui-polish-plan.md` §3（M2）+ §5 | **焦点链/可访问性**：M2 验收增加"键盘/gamepad 焦点链完整、暂停/返回路径可用、focus 描边可不依赖颜色（颜色+图标双通道）"；风险表补"焦点链回归"行 |

---

## 三、建议新增的测试 / 截图 / 采证项（含路径与命令）

### 3.1 建议新增 GUT 测试（`tests/unit/`，M4/M1）

| 建议测试文件 | 断言要点 | 备注 |
|---|---|---|
| `tests/unit/test_recoil_affects_aim.gd` | 给定 `recoil_angle`（或后坐后 aim）→ `apply_spread(aim_rotated(...))` 弹道偏离角在 [0, recoil+spread] 内；host/OFFLINE 裁决路径只调用一次 `apply_spread` | 可复用 `PlayerView.apply_spread` 纯函数（现有 `tests/unit/test_gunplay_spread.gd` 同类） |
| `tests/unit/test_cursor_bloom_state.gd` | heat 0/1/2/4 → 光标帧映射（`target_a` vs `target_round_b` 或 `cross_small→cross_large`）；与 PROGRESS 状态优先级不变 | 在 `test_cursor_state_machine.gd` 基础上扩展；需先给 CursorStateMachine 增加可注入 heat 的 API（当前无） |
| `tests/unit/test_meta_namespace_integration.gd`（增强） | `MetaProgress.get_unlocked_models()` 返回 `bulwark:` 前缀；`Arsenal` → `_get_model()`（或 `ResourceLocation.from_string`）可解析；商店/改枪台可装备 | 替代纯元数据断言；当前 `test_meta_progress.gd` 仅测字符串 |
| `tests/unit/test_settings_m4_v2.gd` | 新增设置项（灵敏度/震屏/准星样式/散布可视化）读写 `settings.cfg`（`SETTINGS_VERSION` 兼容旧文件、缺省值回退） | 参照 `SettingsManager`（`scripts/systems/settings_manager.gd` L45-73）与 `test_m4_input_settings.gd` |
| `tests/unit/test_net_codec_shot_recoil.gd` | `EVT_SHOT_FIRED` 新增 key 编码/解码双向一致；旧 payload 无新 key 时解码默认值（向后兼容） | 参照 `scripts/systems/net/net_codec.gd` L52/L94-95/L125 |

### 3.2 建议新增采证/验收项（`docs/review/evidence/`，read_image 人工复核）

| 截图 | 命令（GL Compatibility，非 `--headless`） |
|---|---|
| 主菜单 1280×720 / 1920×1080 / 21:9 改造前后 | `godot --path . --rendering-method gl_compatibility -s res://tools/capture_arcade.gd -- --menu --cap-size=1280x720`（+ 1920x1080、3440x1440） |
| 商店 / 设置 / 结算 1280×720 + 1920×1080 | 需先扩展 capture（见必须修正 #4）：`tools/capture_ui.gd -- --shop/--settings/--result --cap-size=...` |
| HUD 战斗（含波次横幅/PixelProgressBar/Boss 徽章）1280×720 + 1920×1080 | `godot --path . --rendering-method gl_compatibility -s res://tools/capture_arcade.gd -- --showcase --cap-size=1280x720`（现有命令） |
| 准星热态两帧（低 heat / 高 heat）1280×720 | 新增 `--cursor` 模式或临时场景（连射中两帧截图） |
| **世界层增色前后对照** 1280×720 | `--showcase` 同机位 before/after 截图（M1 世界增色任务验收） |

### 3.3 建议量化基线（进交付清单）

- GUT：用例数 **≥ 320**（新增后），断言数 ≥ 3513 + 新增，exit 0；
- `check_resolutions.gd`：扩展后场景数 = 6（含 settings/chapter_reward），`RES_CHECK=PASS`；
- `check_architecture.gd`：`ARCH_CHECK=PASS`（core 零场景/渲染引用）；
- i18n：zh/en 键集差异 **0**；"无硬编码"grep（`scenes/ scripts/` 用户可见字符串字面量）0 命中（`¥%d`/`↺` 收编后）；
- Headless 冒烟：`godot --headless --path . --quit-after 60` exit 0。

---

## 四、推荐下一步

1. **先拍板/修订方向**（本轮人工已给结论）：按必须修正 #1/#2 把计划 §2 与 §1.2、理解文档 §五 5.1 修正为 **B 扁平军事化升级 + 世界层轻量增色**，经人类确认后生效。
2. **修订计划文档**：按必须修正 #1–#10 更新 `ui-polish-plan.md`（本审查只给清单，不动原文），并把第 1 轮理解文档中的"Kenney 像素"表述与 A 推荐同步更正。
3. **执行 M0**：出《视觉规格表》（军事化色板/字号阶梯/边框角标/图标映射/动效 ≤250ms）+ **1–2 张 mockup 截图（含世界增色示意）**，人工确认后再进入 M1——M0 前先做"中文/西欧字符覆盖率 + 军事化字体层级"渲染测试与 `theme_type_variation` 4.7 语法验证。
4. **M1–M5 按修正后计划执行**，每里程碑：GUT 全量 + `check_resolutions.gd`（扩展后）+ `check_architecture.gd` + 截图（read_image 复核）+ 单提交 + 回滚点记录；M4 涉及网络字段时双人冒烟改为**必做**。

---

> 说明：本审查未修改任何文档正文（含计划、理解文档）；所有"必须修正项"以清单形式给出，由人类批准后由执行者落实。若方向 B 的"世界增色"预算超出本轮范围，也可先在计划中明确"本轮不做、记为 P1 独立项"，但需避免"UI 精致化后仍显得与世界不搭"的批评重复出现。
