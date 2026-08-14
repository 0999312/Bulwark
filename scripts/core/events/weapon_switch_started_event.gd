class_name WeaponSwitchStartedEvent
extends Event
## 切换开始（进入 CD，HUD 显示切换中/进度）

var target_slot_index: int
var switch_cd: float

func _init(p_target_slot_index: int, p_switch_cd: float) -> void:
	target_slot_index = p_target_slot_index
	switch_cd = p_switch_cd
