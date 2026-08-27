# Bulwark「前线壁垒」执行报告（第 3 轮 · M0 阶段交付）

> 轮次：第 3 轮（执行计划，最终交付轮）——**当前停在 M0 人工确认门**，M1–M5 未开始
> 日期：2026-08-27
> 依据：计划 v2（本轮回执修订）、第 2 轮评审"有条件通过"、人工修正（Kenney 非像素；地形纯色块 → B + 世界增色）
> 交付纪律遵循：未获得 M0 拍板前，**未批量改主题/字体，未改任何游戏运行时代码**（仅 docs + tools 采证工具）。

---

## 0. 本轮执行结论（一句话）

**已完成"第 2 轮必须修正项 #1–#10 的计划修订 + M0《视觉规格表》+ 4 张 mockup 截图采证并 read_image 复核"；按计划 M0 门禁，进入 M1 前需人类确认方向与 3 个设计问题。**

---

## 1. 前置修订（docs）

| 文件 | 变更 |
|---|---|
| `docs/design/ui-polish-plan.md` | 升级 **v2**：①方向改为 **B 扁平军事化 + 世界层轻量增色**（A 已否决，仅存档）；②§1.1/§1.2 更正"Kenney 像素"表述并新增"世界层增色仅限素材层"边界；③M0 字体任务改为"军事化字体层级 + Fusion Pixel Font 候选试验（OFL-1.1，先测覆盖）"；④M1 新增 `military_flat.tres`、6 场景 `check_resolutions` 扩展、采证脚本、世界增色、HUD 颜色并入 UiPalette、资产导入审计、i18n；⑤M2 焦点链（键盘+gamepad）/GUT 验收；⑥M3/M4 **设置面板串行化**；⑦M4 明确**后坐权威层（PlayerController core + ShotFiredEvent 新字段 + host 权威/client 镜像）与 client heat 快照字段**、meta 命名空间修复任务、NetCodec 新 key 兼容测试、双人冒烟必做；⑧M5 截图清单补商店/设置/结算/三选一/准星热态/世界增色 before-after；⑨§4 Gate 加"世界层增色"与资产导入审计；⑩§5 风险表补 6 行（字体授权/焦点链/client heat/世界增色范围/4.7 Theme API/验收工具） |
| `docs/design/ui-polish-understanding.md` | 顶部加"修订说明"；§一/§二 #2、#12 更正"Kenney 像素"→"Kenney 低清卡通（Nearest 防糊）"；§五 5.1 更新为"第 2 轮已否决 A，最终方向 B + 世界增色"；Q1–Q3 措辞按 B 语境调整 |
| `docs/design/ui-polish-review.md` | 第 2 轮审查产物（本次一并纳入提交） |

## 2. M0 执行清单（全部完成/产出）

- ✅ 资产盘点（图标 110 SVG / 准星 9 张 / Kenney tiles·props·muzzle·bullets·explosion·tank / VfxBank / UiPalette）——详见 `ui-polish-visual-spec.md` §5/§8/§9。
- ✅ 字体方案：MiSans 军规化为主；Fusion Pixel Font（OFL-1.1）作为标题/数字**候选试验**，需 M0 覆盖+观感测试后再定（未下载/未入库，等人工批准）。
- ✅ 《视觉规格表》：`docs/design/ui-polish-visual-spec.md`（色板扩展 A3、字体层级、圆角/边框/角标/警示纹/纹章、20 核心图标映射与缺项兜底、动效 ≤250ms、8pt 排版、Kenney 素材基准与导入审计、世界增色方案、M1 组件清单）。
- ✅ Mockup 临时采证工具：`tools/mockup_ui.gd` + `tools/mockup_ui_runner.gd`（`--scene=menu|hud|world`、`--cap-size=`，GL Compatibility 非 headless）。
- ✅ 截图（`docs/review/evidence/`，已 read_image 人工复核）：
  - `m0_mockup_menu_1280x720.png` / `m0_mockup_menu_1920x1080.png` —— 深海军蓝底 + 琥珀标题 + 军事按钮（图标位）+ 顶部/底部警示条纹 + 纹章 + 战功/版本角标。
  - `m0_mockup_hud_1280x720.png` —— TextureProgressBar（HP 绿/Boss 红，分段纹理）+ 图标行 + 8pt 面板化布局 + 波次横幅/徽章。
  - `m0_mockup_world_1280x720.png` —— 基地六角核心 + 沙袋环/木箱/油渍/角落残骸 + 玩家；概念示意"世界层轻量增色（仅素材层）"。

### read_image 复核结论（诚实记录）

| 截图 | 结论 | 待 M1 调优点 |
|---|---|---|
| 菜单 1280/1920 | 方向正确：军事扁平 + 图标位 + 警示纹；标题/纹章可读 | ①按钮图标 SVG 渲染偏小/偏暗 → M1 做 16–20px 重导出/描边化；②纹章（tankBody 旋转）边缘略糊 → 剪影化/加边框；③左右竖条装饰需与网格/角标统一 |
| HUD | TextureProgressBar 段纹理可用；面板化 + 图标行思路成立 | ①HP/Boss 条在紧凑行内偏小 → 加最小宽度/九宫格纹理；②资源/弹药图标同样偏暗；③顶层警示条压住信息 → 位置微调 |
| 世界 | 概念能传达"沙袋/木箱/油渍/残骸点缀"；但地面仍偏"大色块"（tile 放大后纹理平淡） | M1 需用**tile 变体（tile_105/214）+ 小噪点/碎片贴花**提升地面细节；仅放道具不足以根治"纯色块"手感——已记入 M1 世界增色任务（含"变体瓦片"） |

## 3. 测试 / 验证结果（M0 里程碑必跑）

| 项 | 命令 | 结果 |
|---|---|---|
| GUT 全量 | `godot --headless -s addons/gut/gut_cmdln.gd --path .` | **`320/320 全绿`（复跑确认；51 脚本 / 3513 断言 / 70.9s，exit 0；11 deprecated 警告）。说明：首次运行 `319/320`——`test_game_session_wiring.gd:252`“任意两只不应重叠在同一落点”（10 只随机落点最小间距 <5px）偶发失败，复跑即全绿；**为全局 `randf` 随机刷新的固有 flaky，与本轮 docs/tools 改动无关**；已作为已知项记录（建议后续改用 seeded RNG 断言） |
| 架构 | `-s res://tools/check_architecture.gd` | `ARCH_CHECK=PASS` |
| 分辨率 UI（4 场景，M1 将扩 6） | `-s res://tools/check_resolutions.gd` | `RES_CHECK=PASS`（1280/1920/21:9；zh/en 各 309 键） |
| 冒烟 | `godot --headless --path . --quit-after 60` | exit 0；zh/en 各 309 键 |
| i18n | 上述运行日志 | 309/309 键一致（本轮未新增游戏文案） |

## 4. 遗留 TODO / 未完成项（如实）

1. **M1–M5 未开始**（受 M0 门禁约束，等待人工确认）。
2. **meta 命名空间未修**（属 M4/M1 前 P0；本轮未改代码，遵守"未确认前不写代码"）。
3. **`check_resolutions.gd` 尚未扩 6 场景、采证脚本尚未支持 --shop/--settings/--result**（计划已列为 M1 前置）。
4. **字体文件未下载/未入库**（Fusion Pixel Font 为候选，待批准 + 覆盖测试）。
5. **未 git push**（本轮仅本地提交；待 M0 批复或按用户指示推送）。
6. **已知 flaky 测试**：`test_spawn_positions_vary_on_ring`（随机落点最小间距）偶发失败一次、复跑全绿——建议后续改 seeded RNG 断言（非本计划范围，记录备忘）。

## 5. 待确认事项与恢复步骤（等人类回复后继续）

**需要人类拍板/确认（M0 门禁）：**

| # | 事项 | 建议（默认） | 若不通过 |
|---|---|---|---|
| D1 | 方向确认：B 扁平军事化 + 世界层轻量增色（A 已否决） | ✅ 按计划 v2 执行 | 改回/重定方向 → 重做规格表与 mockup |
| D2 (Q1) | 字体：标题/数字试验 Fusion Pixel Font（OFL-1.1）或直接用 MiSans 军规化（加大字距/描边） | 先做覆盖+观感测试；通过则标题用，正文 MiSans；不通过则纯 MiSans 军规化 | 选择其他字体 → M0 追加覆盖测试 |
| D3 (Q2) | 圆角策略：面板/按钮圆角 4px（建议）/ 8px（现状）/ 0（直角） | 4px 微圆角 + 1px 硬描边 | 指定后改规格表样式参数 |
| D4 (Q3) | HUD/面板范围：全量军用化（图标 + 纹理条 + 硬边卡片）vs 仅换主题/图标/边饰 | 全量军用化（配合世界增色） | 若选轻量，M3 范围缩小、M1 组件精简 |
| D5 | mockup / 规格表批复 | 见 §2、§5；回复"继续"即进入 M1 | 提出修改点 → 按点改规格表/重出 mockup |

**恢复步骤（若确认继续）**：①修订完成（已就绪）→ ②M1：扩 `tools/check_resolutions.gd`（6 场景）+ 采证脚本 --shop/--settings/--result → Theme 变体/`military_flat.tres`/MilitaryProgressBar/IconLabel/IconButton/UiIcon/UiPalette（含 HUD 颜色并入）→ shop_panel 迁移 → 世界增色（tile 变体 + 道具）→ 资产导入审计 → 截图 before/after + read_image → GUT/ARCH/RES → ③M2 主菜单 → ④M3 HUD/面板 → ⑤M4 手感 + meta 修复（串行于 M3 之后，Network 改动必跑 run-dual）→ ⑥M5 全量回归 + 采证 + 提交推送。

---

> 说明：本轮未修改游戏运行时代码/主题/字体/资源；`git status` 仅含 docs 与 tools/mockup 工具及 evidence png。
