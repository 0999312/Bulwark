class_name RevivedEvent
extends Event
## 复活完成（表现层把玩家拉回基地复活点，重置位置与状态）
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0
var health: float
var max_health: float

func _init(p_health: float, p_max_health: float, p_player_id: int = 0) -> void:
	player_id = p_player_id
	health = p_health
	max_health = p_max_health
