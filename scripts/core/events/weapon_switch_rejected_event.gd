class_name WeaponSwitchRejectedEvent
extends Event
## 切枪请求被拒绝事件（HUD 反馈用）
## 原因：switching = 切换中；empty = 目标槽未装备
## player_id 供多人区分（默认 0 = 单机/本地）

const REASON_SWITCHING := &"switching"
const REASON_EMPTY := &"empty"

var player_id: int = 0
var slot_index: int
var reason: StringName

func _init(p_slot_index: int, p_reason: StringName, p_player_id: int = 0) -> void:
	player_id = p_player_id
	slot_index = p_slot_index
	reason = p_reason
