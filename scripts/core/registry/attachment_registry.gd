class_name AttachmentRegistry
extends RegistryBase
## 配件注册表（架构 §10.3：类型化注册表）

func _validate_entry(entry: Variant) -> bool:
	return entry is AttachmentData

func _get_expected_type_name() -> String:
	return "AttachmentData"
