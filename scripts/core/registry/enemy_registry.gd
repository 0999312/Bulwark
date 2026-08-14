class_name EnemyRegistry
extends RegistryBase
## 敌人注册表（架构 §10.3）

func _validate_entry(entry: Variant) -> bool:
	return entry is EnemyData

func _get_expected_type_name() -> String:
	return "EnemyData"
