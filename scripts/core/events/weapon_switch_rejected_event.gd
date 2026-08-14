class_name WeaponSwitchRejectedEvent
extends Event
## 切枪请求被拒绝事件（HUD 反馈用）
## 原因：switching = 切换中；empty = 目标槽未装备

const REASON_SWITCHING := &"switching"
const REASON_EMPTY := &"empty"

var slot_index: int
var reason: StringName

func _init(p_slot_index: int, p_reason: StringName) -> void:
	slot_index = p_slot_index
	reason = p_reason
