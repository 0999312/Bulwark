# Bulwark「前线壁垒」视觉规格表（M0 产出 · 待人工确认）

> 轮次：第 3 轮（执行）· M0 视觉决策
> 日期：2026-08-27
> 依据：`docs/design/ui-polish-plan.md`（v2）、`docs/design/ui-polish-review.md`（第 2 轮，必须修正 #1–#10）、`docs/review/self-audit-v2.md`
> 已拍板方向：**B 扁平军事化升级 + 世界层轻量增色**（A 像素优先已否决——Kenney 素材为低清卡通/扁平，Nearest 仅为防糊；地形多处近纯色块）
> 状态：**Mockup 待人工确认**；确认前不批量改主题/字体。

---

## 1. 设计语言（一句话）

**"低清军事指挥部"**：深海军蓝 × 钢蓝 × 琥珀的扁平军事套件——1px 硬描边 + 微圆角/直角边角、警示斜纹与纹章、图标化信息（双通道：色 + 图标）、MiSans 军规化标题 + 8pt 网格排版；与 Kenney 低清卡通素材（Nearest 防糊）同调，不做像素化改造。

## 2. 色板（在 UiPalette 基础上扩展；单一事实源 = `scripts/systems/ui_palette.gd`）

| 令牌 | 建议值 | 用途 | 现状 |
|---|---|---|---|
| `BG_DEEP` | `(0.024, 0.033, 0.047)` | 全屏/场景底 | 已有 |
| `BG_PANEL` | `(0.045, 0.06, 0.082)` | 面板/卡片 | 已有 |
| `BG_RAISED` | `(0.075, 0.099, 0.131)` | 悬浮/按钮 | 已有 |
| `BORDER` | `(0.25, 0.33, 0.44, 0.85)` | 常规描边 | 已有 |
| `BORDER_STRONG` | `(0.42, 0.53, 0.67)` | 聚焦/强描边 | 已有 |
| `ACCENT` | `(0.96, 0.74, 0.28)` | 琥珀强调（操作/关键信息） | 已有 |
| `ACCENT_DIM` | `(0.96, 0.74, 0.28, 0.18)` | 弱化琥珀（徽章底） | 已有 |
| `SUCCESS / DANGER / INFO / WARNING` | 现有 | 语义色 | 已有 |
| **新增 `STEEL`** | `(0.42, 0.53, 0.67)` | 金属部件/纹章描边 | 待加（≈BORDER_STRONG） |
| **新增 `OLIVE`** | `(0.45, 0.51, 0.30)` | 世界增色点缀/装饰（Kenney 沙袋/木箱基调） | 待加 |
| **新增 `HAZARD`** | `(0.93, 0.62, 0.12)` | 警示斜纹/危险带（略深于 ACCENT） | 待加 |
| **新增 `PIXEL_DARK`** | `(0.015, 0.022, 0.03)` | 像素纹/槽位底 | 待加 |

规则：强调色只给"可交互/关键信息"；不整屏涂色；HUD 条/徽章颜色一律从 UiPalette 取（现状 `hud.tscn` 自定色与 UiPalette 有漂移，M1 修复）。

## 3. 字体层级（MiSans 为主；标题级候选像素化字体做试验）

| 级别 | 字体 | 字号 | 用途 |
|---|---|---|---|
| H1 标题 | MiSans-Semibold（若候选字体通过覆盖+观感测试则用候选字体） | 46–58px，字距 +2~4，描边 4–6px | 主菜单标题/章横幅 |
| H2 | MiSans-Semibold | 26–32px，描边 2–3px | 面板标题/波次标题 |
| H3 | MiSans-Semibold | 18–20px | 卡片名/分区标题 |
| 正文 | MiSans-Semibold | 14–16px | 描述/信息 |
| 数字 | MiSans-Semibold（等宽数字感） | 24–40px | 分数/弹药/资源 |
| 说明 | MiSans-Semibold | 11–13px | 提示/版本/说明 |

候选标题字体：**Fusion Pixel Font（OFL-1.1，泛中日韩）**——仅作标题/数字试验，需 M0 完成：①中文覆盖测试（"前线壁垒/无尽/战功/胜利/失败/第2章"等 + 数字 + 15–58px 阶梯截图）；②与卡通扁平 UI 的观感适配；③授权确认（OFL-1.1 可商用，标记来源）。**未通过则标题回退 MiSans 加大字距/描边**，不引入像素字体。

## 4. 形状 / 边框 / 角标

| 元素 | 规格 |
|---|---|
| 面板 | 1px `BORDER` 描边；圆角 **2–4px**（默认 4px；Q2 待 mockup 拍板）；无/极小阴影（≤3px，仅浮层） |
| 按钮 | 1px 硬边；hover 斜纹/亮度 + 图标位；按下 1px 下沉；focus 2px `ACCENT` 描边 |
| 角标 | 左上/右上"L 型"折角线（青蓝/琥珀 30% 透明）；条位不加 |
| 警示纹 | 45° 斜纹（`HAZARD`，12px 宽、间隔 12px，透明度 0.25–0.4）用于横幅/危险态/设置页眉 |
| 纹章 | 倒三角/盾形底（`BgPanel` + 琥珀描边）+ 坦克剪影（`tankBody_dark` 低透明）＋编号文字 |
| 徽章 | `PanelContainer`（`BG_INSET` + 1px `ACCENT_DIM` 边）+ 图标 + 数字 |

## 5. 图标映射（20 个核心图标；双通道：图标 + 颜色）

| 图标 | 方案（优先级：现有 SVG → VfxBank/Kenney → 新绘） |
|---|---|
| 商店 / 设置 / 退出 / 多人 / 分数 / 连击 / 书（便签）/ 排名 / 锁 | 现有 `assets/icons/ui|user|feedback|misc`：`shop.svg`、`settings.svg`、`arrow_right.svg`（或 `cross.svg`）、`user_group.svg`、`ranking.svg`、`star.svg`、`book.svg`、`trophy.svg`、`lock.svg` |
| 武器 / 弹药 | **缺** → 用 `assets/vfx/kenney/bullets/bulletGreen1.png`（弹药）/ `turretDark_barrel1.png`（武器）或新绘 16×16 白色轮廓 |
| HP / 基地 / 资源 / 波次 / 胜利 / 失败 / 复活 / 制作 / 购买 / 道具 / 配件 / 路径 | **缺** → 建议新绘单色 16×16 线稿（HP=十字/盾，基地=六角，资源=crate，波次=旗，胜利=trophy/星，失败=骷髅，复活=refresh，制作=扳手/齿轮，购买=yuan_yen，道具=箱，配件=puzzle，路径=折线） |
| 兜底原则 | 暂缺项先用 VfxBank/Kenney 成品（`crateMetal`、`crateWood`、`explosion1`、`sandbagBeige`）占位，M0 待人工确认后定"新绘 or 占位" |

导入：SVG `svg/scale=1.0` 现状可直接用；若小尺寸发虚，M1 做"描边化/重导出 32px PNG"（Nearest、lossless、无 mipmap 已与现有 `.import` 一致）。

## 6. 动效（≤250ms；全部 `TRANS_CUBIC + EASE_OUT`，重入 kill）

| 动效 | 时长 | 说明 |
|---|---|---|
| 面板进场 | 0.22s | `BaseModalPanel` 现有；设置面板补同款 |
| 标题进场 | 0.2–0.3s | 淡入 + 上浮 8px |
| 按钮 hover | 0.10s | 亮度/抬升 2px |
| 按钮按下 | 0.08s | 1px 下沉 |
| 按钮入场 stagger | 30ms/项 | 主菜单 |
| 数值条 | 0.22s | `tween_method`（HUD 现有） |
| 横幅 | 0.25s | 黄条展开 + 淡入 |

## 7. 排版 / 间距（8pt 网格）

- 基数：4/8/12/16/24/32；HUD 边距 16px；面板内容边距 14–16px；按钮高 46–48px。
- HUD：TopLeft/TopRight/BottomLeft 全部改 `MarginContainer` + `PanelContainer`/`HBox`/`VBox` 体系，**删除手写像素 offset**（现状 `hud.tscn` L143-265）。
- 焦点链：主菜单 `Single → Endless → Multi → Settings → Quit` 循环；面板进入 `grab_focus()` 首项；`focus_neighbor_*` 显式接线（键盘 + gamepad）。

## 8. 素材基准 / 资产导入审计

- 世界/UI 素材对齐 **Kenney Default size（16/32/64px）**，不用 Retina；VFX 保持 8px 几何双层预算（Tier1 高频 / Tier2 低频）。
- 新增纹理/图标/字体一律：`Nearest`、`lossless(compress/mode=0)`、`mipmaps/generate=false`、无 Retina（对照 `soldier1_stand.png.import` L18/L26、`settings.svg.import` L41）。
- `Theme` / `UiPalette` 为单一事实源；生产代码禁止在 `_ready/刷新` 中 `new StyleBoxFlat`（M1 起，`duplicate()` 例外）。

## 9. 世界层轻量增色方案（仅素材层，不改玩法/网格）

| 位置 | 装饰（全部仓库已有素材） |
|---|---|
| 基地外层环 | `sandbagBeige.png`（半圈）、`crateMetal.png`（两侧）、`oilSpill_large.png`（地面油渍） |
| 三个 Zone | `crateWood.png` / `tankBody_*.png` 残骸、`explosionSmoke1.png`（低透明告警点）、`bullet*` 弹壳点缀 |
| 边界/四角 | `tank_bigRed.png`/`tank_huge.png` 残骸剪影（低透明度）、`barricadeWood.png` 碎片 |
| 地面 | 现有 `tile_01/05` 平铺 + 增加 1–2 个 tile 变体瓦片（可同包取 `tile_105/214`）做色块区分，替换"纯色块"观感 |
| 验收 | 战斗 1280×720 before/after 截图；装饰不遮挡战斗可读性、不新增 draw-call 热点（低透明静态 Sprite） |

## 10. 组件清单（M1 落地）

`MilitaryButton`（变体）、`CardRare`、`SlotBadge`、`MilitaryProgressBar`（TextureProgressBar 子类，军事化分段纹理）、`BannerPanel`、`IconLabel`、`IconButton`、`UiIcon`（静态工具类，图标资源 → TextureRect）。

## 11. M0 待人工确认事项（详见终报告）

1. **方向确认**：B 扁平军事化 + 世界层轻量增色（A 已否决）——请确认。
2. **Q1 字体**：标题/数字是否试验 Fusion Pixel Font（OFL-1.1），还是直接用 MiSans 军规化（加大字距/描边）？
3. **Q2 圆角**：面板/按钮圆角 4px（默认建议）还是 8px（现状）或 0（直角）？
4. **Q3 HUD/面板**：全量军用化（图标+Icons+纹理条+硬边卡片）还是保留现状形状只换主题/图标？
5. **mockup 确认**：见 `docs/review/evidence/m0_mockup_*`（read_image 已复核）。
