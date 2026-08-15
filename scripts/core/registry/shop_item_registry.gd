class_name ShopItemRegistry
extends RegistryBase
## 商店商品注册表（架构 §10.3：类型化注册表）

func _validate_entry(entry: Variant) -> bool:
	return entry is ShopItemData

func _get_expected_type_name() -> String:
	return "ShopItemData"
