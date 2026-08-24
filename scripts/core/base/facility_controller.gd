class_name FacilityController
extends RefCounted
## 设施通用后端（M5b）：耐久/受击/修复/唯一标识
## 路障仍保留 BarricadeController（弧形几何）；炮塔/弹药补给点用本类或子类。

var data: DefenseFacilityData
var instance_id: int = 0
var durability: float = 0.0
var max_durability: float = 0.0

var _destroyed_reported := false

func _init(p_data: DefenseFacilityData, p_instance_id: int = 0) -> void:
	data = p_data
	instance_id = p_instance_id
	max_durability = p_data.max_durability
	durability = p_data.max_durability

func is_destroyed() -> bool:
	return _destroyed_reported

func get_location() -> String:
	return "%s#%d" % [Bulwark.loc(data.id).to_string(), instance_id]

func get_durability_ratio() -> float:
	if max_durability <= 0.0:
		return 0.0
	return durability / max_durability

func take_damage(amount: float) -> float:
	if _destroyed_reported or amount <= 0.0:
		return durability
	durability = maxf(0.0, durability - amount)
	EventBus.publish(BarricadeDamagedEvent.new(get_location(), durability, max_durability))
	if durability <= 0.0 and not _destroyed_reported:
		_destroyed_reported = true
		EventBus.publish(BarricadeDestroyedEvent.new(get_location()))
	return durability

func repair(amount: float) -> float:
	if _destroyed_reported or amount <= 0.0:
		return durability
	durability = minf(max_durability, durability + amount)
	EventBus.publish(BarricadeDamagedEvent.new(get_location(), durability, max_durability))
	return durability
