# Bulwark「前线壁垒」执行报告（第 3 轮最终 · M1–M4 交付 / M5 验收项）

> 轮次：第 3 轮（执行计划，最终交付轮）
> 日期：2026-08-27
> 方向（已按人工拍板）：**B 扁平军事化 + 世界层轻量增色**；字体 = MiSans 军规化（**不引入像素字体**）
> 依据：计划 v2、第 2 轮评审"有条件通过 + 必须修正 #1–#10"、`ui-polish-understanding.md`、`ui-polish-visual-spec.md`

---

## 0. 一句话结论

**M0–M4 已全部执行并通过门禁（GUT 331/331 全绿、ARCH/RES(6 场景)/冒烟 PASS、i18n 奇偶 PASS、截图 read_image 复核），并按里程碑拆分提交；M5 收口项（最终截图集、双人冒烟、push）见 §5 遗留。**

---

## 1. 每里程碑改动清单

| 里程碑 | 改动文件（主要） | 说明 |
|---|---|---|
| **M0**（已拍板） | `ui-polish-plan.md`(v2)、`ui-polish-understanding.md`(同步)、`ui-polish-review.md`、`ui-polish-visual-spec.md`、`tools/mockup_ui{,_runner}.gd`、`docs/review/evidence/m0_mockup_*.png` | 方向/字体/圆角/范围拍板；mockup 采证工具 |
| **M1** | `assets/theme/military_flat.tres`（新，B 主题：4px 微圆角 + 1px 硬边 + 变体）、`project.godot`(切换主题)、`scripts/systems/ui_palette.gd`(STEEL/OLIVE/HAZARD/HP/BASE)、`scripts/ui/{ui_icon,icon_label,military_progress_bar}.gd`(新)、`scenes/ui/shop_panel.gd`(Theme 变体 duplicate + 图标 + `shop.price`)、`shop/result/pause/chapter_reward/settings_panel.tscn`(圆角 4)、`scenes/world/main.tscn`(世界增色：沙袋/木箱/油渍/残骸/tile 变体)、`tools/{check_resolutions(6 场景),capture_panels(新),mockup_ui_runner(_open 支持),capture_arcade(任意分辨率),capture_runner(基础帧)}.gd`、`locales/zh|en.json`、`tools/update_locales.py` | 基建 + 组件 + 商店迁移 + 世界增色 + 验收工具前置 |
| **M2** | `scenes/ui/main_menu.tscn`(Emblem/警示条纹/侧条/标签/圆角 4)、`scenes/ui/main_menu.gd`(按钮图标(UiIcon)+标题描边+入场 tween+条纹纹理)、`scripts/ui/ui_icon.gd`(arrow_right/menu) | 主菜单军事化 + 动效 |
| **M3** | `scenes/ui/hud.tscn`(HP/基地/Boss 改 `MilitaryProgressBar` 纹理条)、`scenes/ui/hud.gd`(bar 类型改 Range)、`scripts/ui/military_progress_bar.gd`(nine_patch fix)、`scenes/ui/settings_panel.gd`(补进场 0.22s)、`tools/capture_runner.gd`(frame40 基础帧) | HUD 纹理进度条 + 设置面板进场动画 |
| **M4** | `scripts/core/player/player_controller.gd`(后坐角权威：`recoil_angle` 累积/恢复/`aim_after_recoil`)、`scenes/player/player_view.gd`(去掉死代码 `_recoil_angle`、震屏方向改 `-aim_dir`、灵敏度/震屏开关强度接入)、`scripts/systems/cursor_state_machine.gd`(热态 `target_a→target_round_b`/`cross_small→cross_large`、heat 数据源、散布可视化开关)、`scripts/systems/{settings_manager,game_session,net/net_codec}.gd`(5 个新设置项 + 快照 heat 字段 + 数据源挂钩)、`scripts/core/score/meta_progress.gd`(UNLOCK_MODELS 补 `bulwark:` 命名空间 + 展示名剥前缀)、`tests/unit/{test_m4_recoil_aim,test_meta_namespace_integration,test_settings_m4}.gd`(新) + `test_cursor_state_machine.gd`(3 用例)、`test_meta_progress.gd`、`scenes/ui/settings_panel.{gd,tscn}`(手感 Tab：灵敏度/震屏/准星样式/散布可视化) | 手感补全 + meta 修复 + 设置项 + 网络兼容（快照 heat） |

## 2. 测试结果（最终门禁）

| 项 | 结果 |
|---|---|
| **GUT 全量** | ✅ **54 脚本 / 331 用例 / 331 通过 / 3572 断言 / 70.9s（exit 0）**；11 deprecated 警告（既有，非失败）；`test_i18n` 硬编码检查 PASS（新键全部入 locales） |
| 架构分层 | ✅ `ARCH_CHECK=PASS` |
| 三分辨率 UI（6 场景，含 settings/chapter_reward） | ✅ `RES_CHECK=PASS`（1280×720 / 1920×1080 / 21:9） |
| Headless 冒烟 | ✅ `--quit-after 60` exit 0 |
| i18n | ✅ zh/en 键集奇偶一致（新增 10 键双语同参；`shop.price`/`settings.*` 已同步 `tools/update_locales.py` 结构化字典） |

## 3. 截图采证与人工复核（`docs/review/evidence/`，read_image 已复核）

| 截图 | 结论 |
|---|---|
| `m0_mockup_menu{1280,1920}`、`m0_mockup_hud_1280`、`m0_mockup_world_1280` | M0 概念确认（军事扁平 + 图标位 + 警示条纹 + 世界增色设想）——见上轮报告 |
| `m1_before/after_{settings,shop,result}_1280x720.png` | 商店卡片：圆角 4 + 图标位 + 稀有度边（Theme 变体）；设置 4px 卡片 + 新增"手感"Tab；结算卡片 4px——改造前对比有明显质感变化 |
| `m2_menu_{1280x720,1920x1080,21x9}.png` | 主菜单：Emblem/警示条纹/侧条/BULWARK HQ 标签/按钮图标/战功徽章化；21:9 用 2560×1440 窗口（显示器上限）内容按 21:9 布局，不破版、（无异常） |
| `m3_hud_base_{1280x720,1920x1080}.png` | 战斗 HUD：HP/基地 MilitaryProgressBar 分段纹理显示正常；世界增色（沙袋环/木箱/油渍/残骸/zone 色调）可见，不遮挡战斗可读性 |
| `m3_hud_warning/active_{1280x720,1920x1080}.png` | 波次横幅 + 章间三选一面板 + HUD 同框，不破版 |

> 注：商店/设置/结算截图由 `tools/capture_panels.gd` 注入最小数据（`--panel=settings|shop|result`）拍摄；HUD 由 `capture_arcade.gd --showcase` 拍摄。21:9 菜单截图受显示器宽度 2560 限制（内容按 3440×1440 逻辑布局）。

## 4. 提交（本批，尚未 push）

| commit | 内容 |
|---|---|
| （下批提交到 main） | 按里程碑 4 个 feat commit：M1 基建+商店+世界增色+工具 / M2 主菜单 / M3 HUD+设置动画 / M4 手感+meta 修复+设置项+测试；外加 docs commit（计划状态、QA 清单令牌、gunplay 手感状态、最终执行报告） |

## 5. 遗留 TODO / 未完成项（如实）

1. **M5 收口项**：①最终全量截图集已具备（菜单 3 分辨率、HUD 基础/预警/战斗 1280+1920、商店/设置/结算 before/after）；②**双人冒烟未跑**（`tools/run-dual.ps1`）——M4 网络改动（玩家快照新增 `heat` 字段向后兼容）建议在有人机双开环境下补跑；③`git push origin main` 待本报告后执行；④`m5-visual-qa-checklist` 的 8pt 间距（HUD 仍是固定像素 offset，未改 Margin 体系）与"进出场 ≤250ms（退出动画未做）"两项保持未勾选——如实记录。
2. **遗留工程项**（非本计划范围，记录）：`CursorStateMachine._process` 每帧 `_refresh()` 优化；`check_resolutions` 已扩 6 场景；HUD 图标化（弹药/分数图标位）未全部落地（M3 只换纹理条 + 面板化边框）。
3. **已知 flaky**：`test_spawn_positions_vary_on_ring`（随机落点最小间距），本轮未触发；建议后续改 seeded RNG 断言。

## 6. 是否达到 §4 整体 Gate

| Gate | 状态 |
|---|---|
| 1 主菜单/UI 人工视觉复核 + 三分辨率无破版 | ✅（1280/1920/21:9 截图复核通过） |
| 2 后坐力影响准星/弹道 + 热态 + 设置项持久化 | ✅（`test_m4_recoil_aim`/`test_cursor_bloom_state`/`test_settings_m4` + 代码接线） |
| 3 GUT/ARCH/RES/冒烟 | ✅ 331/331 全绿 |
| 4 i18n 奇偶 + 无硬编码 | ✅（含 settings 新键双语；`settings_panel.tscn` 硬编码已清） |
| 5 性能（无每帧 new/load；纹理 Nearest/lossless/no mipmap） | ✅（Theme/组件静态缓存；`military_flat`/素材沿用项目导入策略；图标经 UiIcon 缓存） |
| 6 世界层增色前后对比 | ✅（`m3_hud_base_1280x720` vs 旧 `hud_active_1280.png`：装饰/色调层次可见） |
| （附加）双人冒烟 | ⚠️ 未跑（需要双开环境；列入 M5 遗留） |

> **结论：除"双人冒烟"外，§4 整体 Gate 均满足；双人冒烟因环境受限未执行，示为已知遗留而非隐藏。**

---

## 7. 精修轮（用户美学反馈后，2026-08-27 补交）

> 用户反馈："这一轮的优化甚至降低了美学设计的效果——游戏整体变得更难看了"。按反馈精修：

| # | 反馈 | 处理 |
|---|---|---|
| 1 | 去掉图标 | 移除主菜单按钮图标、商店卡片图标位；删除 `scripts/ui/{ui_icon,icon_label,military_progress_bar}.gd`（未使用即删） |
| 2 | 长列内容给可见滚动条 | `military_light.tres` 滚动条 8px 宽 + 高对比 grabber；`settings_panel.tscn` KeysScroll `vertical_scroll_mode=2`（SHOW_ALWAYS）；商店 OffersScroll/RightScroll 原已 SHOW_ALWAYS（确认可见，见截图右侧绿色竖条） |
| 3 | 优化世界装饰 + 章节变化 | 新 `scenes/world/world_decor.gd`：每章一组固定道具+色调（前哨=沙袋/木箱；小镇=灰蓝残骸+油渍；污染区=暗橙油渍+烟雾；巢穴=深红剪影），`WaveStartedEvent.chapter_index` 驱动换章；删除 M1 散点式 20 个 Sprite 硬编码 |
| 4 | 调色板可改（考虑亮色） | 新 `assets/theme/military_light.tres`（米白/卡其面板 + 深橄榄文字 + 琥珀强调，圆角 6、轻阴影）；`project.godot` 切换；**HUD 场景 root 显式挂回 `minimal_vector.tres`（保持深色可读）**；面板 tscn 移除硬编码深色 stylebox 覆盖 |
| 5 | 条纹分段进度条很差 | HUD 三条改回原版 `ProgressBar`（圆角填充），删除 military_progress_bar 使用 |
| 6 | 主菜单给世界背景 | 新 `scenes/ui/menu_world_backdrop.tscn`（Kenney 地面+基地轮廓+稀疏道具+暗调），经 `SubViewport` 渲染为 `main_menu.tscn` 背景 + 半透明压暗；去除纹章/警示条纹/侧条/HQ 标签 |

**精修验证**：`RES_CHECK=PASS`（6 场景，含新背景场景）；`GUT`（见 §2 复跑结果）；截图 `m2_menu_v2_{1280x720,1920x1080}`（世界背景+浅色按钮）、`m1_after_settings|shop_1280x720`（浅色面板+可见滚动条）、`m3_hud_base_v2_1280x720`（深色原版 HUD+章节装饰）——均已 read_image 复核。

---

## 8. 第二轮精修（美学复批 + 手感反馈，2026-08-27 再补交）

> 用户反馈：①亮色反而设计不当、字体冲突不可读；②装饰物效果仍不理想；③手感无明显差异，建议给准星加抖动以直观感受后坐冲击。

| 反馈 | 处理 |
|---|---|
| 亮色不可读 | **回退深色**：`project.godot` 主题切回 `minimal_vector.tres`，删除 `military_light.tres`；主菜单/商店/设置截图复验：深底浅字，可读性恢复（`m2_menu_v3_1280x720.png`、`m1_after_shop_1280x720.png`） |
| 装饰效果不理想 | 世界装饰第三次降噪：`world_decor.gd` 只保留**地面印痕/暗色残骸剪影**（油渍、坦克剪影、黑烟，α≤0.55），删除亮色沙袋/木箱；菜单背景道具同步压暗（`m3_hud_base_v3_1280x720.png`：装饰克制成暗轮廓） |
| 准星抖动 | 新增 `scripts/ui/crosshair_view.gd`（CanvasLayer 40）绘制准星：随鼠标 + **每帧随机抖动**（幅度 = 1.6px + heat×1.9，热满约 9px）；heat≥2 时准星张开 + 变橙红 + 外圈微光；`CursorStateMachine` COMBAT 改隐藏 OS 光标并由本层绘制（面板/暂停/换弹时恢复）；仍保留热态帧 API 与测试 |

**验证**：GUT **331/331**（54 脚本/3572 断言）；`ARCH_CHECK=PASS`；`RES_CHECK=PASS`（6 场景）；headless 冒烟 exit 0；截图 `m2_menu_v3_1280x720`（深色+世界背景）、`m1_after_shop_1280x720`（深色+可见滚动条）、`m3_hud_base_v3_1280x720`（深色 HUD+克制的暗色装饰）read_image 复核通过。
