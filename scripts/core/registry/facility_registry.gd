class_name FacilityRegistry
extends RegistryBase
## 防线设施注册表（架构 §10.3：类型化注册表）

func _validate_entry(entry: Variant) -> bool:
	return entry is DefenseFacilityData

func _get_expected_type_name() -> String:
	return "DefenseFacilityData"
