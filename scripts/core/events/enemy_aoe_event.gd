class_name EnemyAoEEvent
extends Event
## 敌人范围伤害（自爆体等；host 逻辑命中：按半径结算基地/玩家，视觉由事件驱动）

var enemy_location: String
var position: Vector2
var radius: float
var damage: float

func _init(p_enemy_location: String, p_position: Vector2,
		p_radius: float, p_damage: float) -> void:
	enemy_location = p_enemy_location
	position = p_position
	radius = p_radius
	damage = p_damage
