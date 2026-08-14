class_name SpawnRequestEvent
extends Event
## 波次刷怪请求（WaveDirector 后端 → 表现层刷怪；表现层按 count 实例化敌人）
## 刷怪位置：基地周围圆环随机（方位扇形 + 随机半径，对齐原版 orbitradius 模型）

var direction: int    # WaveData.Direction
var count: int
var enemy_location: String

func _init(p_direction: int, p_count: int, p_enemy_location: String) -> void:
	direction = p_direction
	count = p_count
	enemy_location = p_enemy_location
