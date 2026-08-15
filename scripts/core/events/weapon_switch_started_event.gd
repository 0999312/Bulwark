class_name WeaponSwitchStartedEvent
extends Event
## 切换开始（进入 CD，HUD 显示切换中/进度）
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0
var target_slot_index: int
var switch_cd: float

func _init(p_target_slot_index: int, p_switch_cd: float, p_player_id: int = 0) -> void:
	player_id = p_player_id
	target_slot_index = p_target_slot_index
	switch_cd = p_switch_cd
