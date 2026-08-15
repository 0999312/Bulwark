class_name AttachmentEquippedEvent
extends Event
## 配件装配成功（WeaponSlots 槽位装配；HUD/装配 UI 刷新）
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0
var slot_index: int      # 武器槽（WeaponSlots.SLOT_*）
var attachment_location: String

func _init(p_slot_index: int, p_attachment_location: String, p_player_id: int = 0) -> void:
	player_id = p_player_id
	slot_index = p_slot_index
	attachment_location = p_attachment_location
