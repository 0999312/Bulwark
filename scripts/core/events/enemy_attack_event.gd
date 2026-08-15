class_name EnemyAttackEvent
extends Event
## 敌人近战攻击（后端发出；GameSession 按目标结算）
## M0 唯一目标 = 基地；M1 扩展：target 非空 = 路障 facility ResourceLocation（如 "bulwark:facility/barricade"）

const TARGET_BASE := ""

var damage: float
var enemy_location: String
## 攻击目标（"" = 基地；否则为路障 ResourceLocation 字符串）
var target: String

func _init(p_damage: float, p_enemy_location: String, p_target: String = "") -> void:
	damage = p_damage
	enemy_location = p_enemy_location
	target = p_target
