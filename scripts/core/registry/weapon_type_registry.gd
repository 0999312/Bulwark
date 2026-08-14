class_name WeaponTypeRegistry
extends RegistryBase
## 武器种类注册表（架构 §10.3：类型化注册表，覆写 _validate_entry 类型校验）

func _validate_entry(entry: Variant) -> bool:
	return entry is WeaponTypeData

func _get_expected_type_name() -> String:
	return "WeaponTypeData"
