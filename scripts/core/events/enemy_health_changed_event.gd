class_name EnemyHealthChangedEvent
extends Event
## 敌人生命变化（P1-13 Boss 血条；host 权威，is_elite 过滤）

var enemy_id: int
var data_id: String
var current: float
var max_value: float
var is_elite: bool = false
var position: Vector2

func _init(p_enemy_id: int, p_data_id: String, p_current: float, p_max_value: float,
		p_is_elite: bool = false, p_position: Vector2 = Vector2.ZERO) -> void:
	enemy_id = p_enemy_id
	data_id = p_data_id
	current = p_current
	max_value = p_max_value
	is_elite = p_is_elite
	position = p_position
