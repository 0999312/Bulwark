class_name WeaponModelRegistry
extends RegistryBase
## 武器型号注册表（架构 §10.3）

func _validate_entry(entry: Variant) -> bool:
	return entry is WeaponModelData

func _get_expected_type_name() -> String:
	return "WeaponModelData"
