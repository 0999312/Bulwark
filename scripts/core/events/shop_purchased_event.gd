class_name ShopPurchasedEvent
extends Event
## 商店购买成功（应用效果后广播；商店面板/HUD 刷新）

var item_location: String
var price_paid: int

func _init(p_item_location: String, p_price_paid: int) -> void:
	item_location = p_item_location
	price_paid = p_price_paid
