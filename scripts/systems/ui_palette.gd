class_name UiPalette
extends RefCounted
## UI 配色单一事实源（godot-ui / godot-ui-theming 的 Shared-Color-Palette 模式）
## - Theme 资源（minimal_vector.tres）与 GDScript 动态 UI 都从这里取色，防止两套色板漂移
## - 设计语言：深海军蓝底 + 钢蓝描边 + 琥珀强调 + 语义色（成功/危险/信息/稀有度）
## - 美学原则：低饱和底色、高对比文字、强调色只用于“可交互/重要信息”，不做全屏涂色

# ─── 背景层级 ───
const BG_DEEP := Color(0.024, 0.033, 0.047)       # 全屏底色（最暗，接近黑蓝）
const BG_PANEL := Color(0.045, 0.06, 0.082)       # 面板/卡片
const BG_RAISED := Color(0.075, 0.099, 0.131)     # 悬浮/可点击控件
const BG_INSET := Color(0.032, 0.043, 0.06)       # 输入框/凹陷槽

# ─── 描边层级 ───
const BORDER := Color(0.25, 0.33, 0.44, 0.85)     # 常规描边
const BORDER_STRONG := Color(0.42, 0.53, 0.67)    # 聚焦/强描边

# ─── 文字层级 ───
const TEXT_PRIMARY := Color(0.93, 0.95, 0.97)
const TEXT_SECONDARY := Color(0.62, 0.68, 0.75)
const TEXT_DISABLED := Color(0.36, 0.41, 0.47)

# ─── 强调色（军事琥珀：只给关键操作与关键信息） ───
const ACCENT := Color(0.96, 0.74, 0.28)
const ACCENT_BRIGHT := Color(1.0, 0.85, 0.47)
const ACCENT_DIM := Color(0.96, 0.74, 0.28, 0.18)

# ─── 语义色 ───
const SUCCESS := Color(0.32, 0.75, 0.55)
const DANGER := Color(0.93, 0.36, 0.33)
const DANGER_SOFT := Color(1.0, 0.52, 0.46)
const INFO := Color(0.44, 0.72, 0.95)
const WARNING := Color(1.0, 0.66, 0.3)

# ─── 稀有度（商店商品；与 Theme 强调色形成层级而不抢内容） ───
const RARITY_COMMON := Color(0.84, 0.85, 0.87)
const RARITY_RARE := Color(0.44, 0.72, 0.95)
const RARITY_EPIC := Color(0.74, 0.5, 0.95)
const RARITY_LEGENDARY := Color(1.0, 0.75, 0.3)

# ─── M1 军事化扩展（B 方向：低清卡通扁平 + 军事 DNA） ───
const STEEL := Color(0.42, 0.53, 0.67)        # 金属部件/纹章描边
const OLIVE := Color(0.45, 0.51, 0.30)         # 世界增色点缀（沙袋/木箱基调）
const HAZARD := Color(0.93, 0.62, 0.12)        # 警示斜纹/危险带（略深于 ACCENT）
const PIXEL_DARK := Color(0.015, 0.022, 0.03)  # 槽位/像素纹底
const HP_SAFE := Color(0.32, 0.75, 0.55)       # HP 条（与 SUCCESS 一致，HUD 专用别名）
const BASE_GUARD := Color(0.87, 0.58, 0.22)    # 基地耐久条（HUD 专用别名，向 ACCENT 靠拢）
