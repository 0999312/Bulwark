class_name EnemyAttackEvent
extends Event
## 敌人对基地的近战啃咬（后端发出；BaseCore 订阅并按伤害管道结算）
## M0 唯一目标 = 基地；后续版本可扩展目标类型（防线设施等）

var damage: float
var enemy_location: String

func _init(p_damage: float, p_enemy_location: String) -> void:
	damage = p_damage
	enemy_location = p_enemy_location
