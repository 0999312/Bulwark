class_name ShopPurchaseRejectedEvent
extends Event
## 商店购买拒绝（货币不足 / 商品不存在）

enum Reason {
	NOT_FOUND = 0,     # 商品未上架
	NOT_ENOUGH_CREDITS = 1, # 货币不足
}

var item_location: String
var reason: int

func _init(p_item_location: String, p_reason: int) -> void:
	item_location = p_item_location
	reason = p_reason
