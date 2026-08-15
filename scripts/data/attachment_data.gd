class_name AttachmentData
extends Resource
## 武器配件（改枪系统，gunplay-attachment-notes.md §4 建议形态落地）
## 配件 = 槽位 + 修正列表（AttributeModifierData 的 add/mul 通道）+ 词条追加
## 接入点：WeaponSlots.SlotState.attachments（每武器槽位按配件槽类型装配 1 个）→ WeaponStats 结算

enum AttachmentSlot {
	MUZZLE = 0, # 枪口
	SIGHT = 1,  # 瞄具（无倍率：红点/全息小幅精度加成；狙击镜 M1 仅数据预留）
	MAG = 2,    # 弹匣
	STOCK = 3,  # 枪托
}

const SLOT_NAMES := {
	AttachmentSlot.MUZZLE: "枪口",
	AttachmentSlot.SIGHT: "瞄具",
	AttachmentSlot.MAG: "弹匣",
	AttachmentSlot.STOCK: "枪托",
}

@export_group("标识")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export_group("装配")
## 所属配件槽（同武器同槽仅可装 1 个）
@export var slot: AttachmentSlot = AttachmentSlot.MUZZLE

@export_group("修正")
## 修正列表（AttributeModifierData：attribute + amount/multiplier）
@export var modifiers: Array[AttributeModifierData] = []

@export_group("词条")
## 追加到武器的词条（keywords；M1 仅数据承载与查询，词条效果结算为 M2+ 伤害管道扩展）
@export var keywords: Array[String] = []

func get_slot_name() -> String:
	return SLOT_NAMES.get(slot, "未知")
