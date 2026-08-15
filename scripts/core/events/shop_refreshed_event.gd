class_name ShopRefreshedEvent
extends Event
## 商店刷新（每波间结算；4 随机商品 + 固定物资区 → 商店面板渲染）
## offers 为当前可购买的全部条目（含价格与购买次数）

## 商品条目（面板渲染单元）
class Offer:
	var item: ShopItemData
	var price: int        # 当前价格（含递增）
	var owned: int        # 已购次数（递增展示）
	var can_afford: bool  # 快照：货币是否足够（面板禁用按钮）

	func _init(p_item: ShopItemData, p_price: int, p_owned: int, p_can_afford: bool) -> void:
		item = p_item
		price = p_price
		owned = p_owned
		can_afford = p_can_afford

var offers: Array = []  # Array[Offer]

func _init(p_offers: Array) -> void:
	offers = p_offers
