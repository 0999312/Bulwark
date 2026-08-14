class_name EnemyDiedEvent
extends Event
## 敌人死亡（表现层播放死亡动画/移除；WaveDirector 簿记清场）

var enemy_location: String
var position: Vector2

func _init(p_enemy_location: String, p_position: Vector2) -> void:
	enemy_location = p_enemy_location
	position = p_position
