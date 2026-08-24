class_name EnemyDiedEvent
extends Event
## 敌人死亡（表现层播放死亡动画/移除；WaveDirector 簿记清场）
## M3 问题 4：携带 killer_id（击杀者玩家；默认 0 = 单机/本地；撞击自爆 = 被撞玩家）

var enemy_location: String
var position: Vector2
var killer_id: int

func _init(p_enemy_location: String, p_position: Vector2, p_killer_id: int = 0) -> void:
	enemy_location = p_enemy_location
	position = p_position
	killer_id = p_killer_id
