class_name ReloadStartedEvent
extends Event
## 换弹开始（M0 自动换弹：弹匣空 + 开火意图；无换弹键位）

var duration: float
var ammo_type: int

func _init(p_duration: float, p_ammo_type: int) -> void:
	duration = p_duration
	ammo_type = p_ammo_type
