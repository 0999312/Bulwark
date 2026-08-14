class_name WeaponSwitchedEvent
extends Event
## 切换完成（CD 计时结束，当前槽位生效）

var slot_index: int             # 0=主 1=副 2=手枪（WeaponSlots 槽位索引）
var slot_type: int              # WeaponTypeData.SlotType
var model_location: String

func _init(p_slot_index: int, p_slot_type: int, p_model_location: String) -> void:
	slot_index = p_slot_index
	slot_type = p_slot_type
	model_location = p_model_location
