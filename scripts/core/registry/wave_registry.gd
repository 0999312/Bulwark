class_name WaveRegistry
extends RegistryBase
## 波次模板注册表（架构 §10.3）

func _validate_entry(entry: Variant) -> bool:
	return entry is WaveData

func _get_expected_type_name() -> String:
	return "WaveData"
