class_name ShopItemData
extends Resource
## 商店商品定义（P22：随机池 + 固定物资；P13 商品池分类）
## 效果类型：
##   STAT_PLAYER    → 玩家属性修正（AttributeSet，modifier 指向玩家属性键）
##   STAT_WEAPON    → 武器属性修正（WeaponStats 数值键，全局生效于所有武器）
##   ATTACHMENT     → 配件（购买获得，装配到武器）
##   BARRICADE      → 路障组件（购买获得建造额度）
##   RESERVE        → 应急储备 +1（复活资源，局内极难补充 → 高价固定物资）

enum Category {
	STAT_PLAYER = 0,
	STAT_WEAPON = 1,
	ATTACHMENT = 2,
	BARRICADE = 3,
	RESERVE = 4,
	AMMO = 5,        # 弹药箱（补充子弹备弹；补给经济闭环）
}

enum Rarity {
	COMMON = 0,    # 普通
	RARE = 1,      # 稀有
	EPIC = 2,      # 史诗
	LEGENDARY = 3, # 传说
}

## 稀有度价格系数（base_price × coef；P22 价格曲线数据化）
const RARITY_PRICE_COEF := {
	Rarity.COMMON: 1.0,
	Rarity.RARE: 1.8,
	Rarity.EPIC: 3.2,
	Rarity.LEGENDARY: 6.0,
}

@export_group("标识")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export_group("商店")
@export var category: Category = Category.STAT_PLAYER
@export var rarity: Rarity = Rarity.COMMON
## 基础价格（货币）；实际价格 = base × rarity_coef × 1.3^(购买次数)（P22）
@export var base_price: int = 50
## 是否固定物资（固定区恒上架，随机池不抽取）
@export var is_fixed: bool = false

@export_group("效果")
## STAT_*：修正条目（attribute = 玩家属性键 或 WeaponStats 数值键）
@export var modifier: AttributeModifierData
## ATTACHMENT：配件 ResourceLocation 字符串（如 "bulwark:attachment/red_dot"）
@export var attachment_location: String = ""
## BARRICADE：购买获得的路障组件数
@export var barricade_count: int = 0
## RESERVE：购买获得的应急储备数
@export var reserve_count: int = 0
## AMMO：购买补充的子弹备弹数（弹药箱类商品）
@export var ammo_amount: int = 0

## 当前价格（含稀有度系数；购买次数递增由 ShopSystem 结算）
func price_with_rarity() -> int:
	return maxi(1, roundi(base_price * RARITY_PRICE_COEF.get(rarity, 1.0)))
