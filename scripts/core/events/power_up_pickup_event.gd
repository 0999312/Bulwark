class_name PowerUpPickupEvent
extends Event
## 波中道具拾取（P1-6；host 权威，携带 player_id；pickup 场景/表现层监听）

var power_id: String
var player_id: int
var position: Vector2
## buff 时长（0 = 即时）
var duration: float = 0.0

func _init(p_power_id: String, p_player_id: int, p_position: Vector2, p_duration: float = 0.0) -> void:
	power_id = p_power_id
	player_id = p_player_id
	position = p_position
	duration = p_duration
