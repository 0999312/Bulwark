class_name PlayerHealthChangedEvent
extends Event
## 玩家生命变化（HUD 绑定用；player_id 供多人区分，默认 0 = 单机/本地）

var player_id: int = 0
var current: float
var max_value: float

func _init(p_current: float, p_max: float, p_player_id: int = 0) -> void:
	player_id = p_player_id
	current = p_current
	max_value = p_max
