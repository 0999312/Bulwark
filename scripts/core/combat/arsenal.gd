class_name Arsenal
extends RefCounted
## 个人军械库（M5b，D-M5-3）：每玩家已拥有武器型号 ResourceLocation 列表
## - 开局默认型号由 GameSession 注入
## - 商店武器箱 → grant_model 加入军械库
## - 改枪台 → 从军械库选择型号换到 WeaponSlots 对应槽位
## 纯逻辑：不引用场景节点，host 权威持有；client 经事件/快照镜像。

var owned_models: Array[String] = []

func _init(starting_models: Array[String] = []) -> void:
	owned_models = starting_models.duplicate()

func owns(model_location: String) -> bool:
	return owned_models.has(model_location)

func add_model(model_location: String) -> bool:
	if model_location.is_empty() or owns(model_location):
		return false
	owned_models.append(model_location)
	return true

func get_owned_models() -> Array[String]:
	return owned_models.duplicate()

## 是否已装备该型号（由 WeaponSlots 查询，不在此持有槽位）
