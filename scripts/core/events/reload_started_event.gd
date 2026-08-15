class_name ReloadStartedEvent
extends Event
## 换弹开始（M0 自动换弹：弹匣空 + 开火意图；无换弹键位）
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0
var duration: float
var ammo_type: int

func _init(p_duration: float, p_ammo_type: int, p_player_id: int = 0) -> void:
	player_id = p_player_id
	duration = p_duration
	ammo_type = p_ammo_type
