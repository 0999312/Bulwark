class_name EnemyRangedAttackEvent
extends Event
## 敌人远程攻击（后端发出；host 逻辑命中 + 事件驱动视觉弹体，D-M5-1）
## 事件只描述一次攻击的起点/终点/伤害/表现种类；弹体不做逐帧快照。

var enemy_location: String
var origin: Vector2
var target_position: Vector2
var damage: float
var projectile_kind: String
var speed: float

func _init(p_enemy_location: String, p_origin: Vector2, p_target_position: Vector2,
		p_damage: float, p_projectile_kind: String = "spit", p_speed: float = 600.0) -> void:
	enemy_location = p_enemy_location
	origin = p_origin
	target_position = p_target_position
	damage = p_damage
	projectile_kind = p_projectile_kind
	speed = p_speed
