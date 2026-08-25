class_name PowerUpExpiredEvent
extends Event
## 计时 buff 到期（P1-6；HUD 移除计时条）

var power_id: String
var player_id: int

func _init(p_power_id: String, p_player_id: int) -> void:
	power_id = p_power_id
	player_id = p_player_id
