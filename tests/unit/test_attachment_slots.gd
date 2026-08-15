extends GutTest
## 改枪配件装配（WeaponSlots）：装配/卸下、修正生效（弹匣/换弹/射速）、事件

var ammo: AmmoSystem
var slots: WeaponSlots
var _equipped: Array[String] = []
var _unequipped: Array[String] = []

func before_each() -> void:
	ammo = AmmoSystem.new()
	ammo.set_count(WeaponTypeData.AmmoType.BULLET, 90)
	slots = WeaponSlots.new(ammo)
	var rifle_type := WeaponTypeData.new()
	rifle_type.id = "weapon/type/assault_rifle"
	rifle_type.slot = WeaponTypeData.SlotType.MAIN
	var rifle := WeaponModelData.new()
	rifle.id = "weapon/model/storm7"
	rifle.damage = 12.0
	rifle.fire_rate = 8.0
	rifle.mag_size = 30
	rifle.reload_time = 1.2
	slots.assign_slot(WeaponSlots.SLOT_MAIN, rifle_type, rifle)
	_equipped.clear()
	_unequipped.clear()
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"AttachmentEquippedEvent",
		func(e: AttachmentEquippedEvent) -> void: _equipped.append(e.attachment_location))
	EventBus.subscribe(&"AttachmentUnequippedEvent",
		func(e: AttachmentUnequippedEvent) -> void: _unequipped.append(e.attachment_location))

func _make_attachment(slot: int, attr: StringName, amount: float, multiplier: float = 1.0,
		id: String = "attachment/test") -> AttachmentData:
	var mod := AttributeModifierData.new()
	mod.attribute = attr
	mod.amount = amount
	mod.multiplier = multiplier
	var att := AttachmentData.new()
	att.id = id
	att.slot = slot
	att.modifiers.assign([mod])
	return att

func test_equip_attachment_refills_mag_to_new_capacity() -> void:
	# 扩容弹匣：30 → 45，装配后立即补满
	var ext := _make_attachment(AttachmentData.AttachmentSlot.MAG, &"mag_size", 0.0, 1.5, "attachment/ext")
	assert_true(slots.equip_attachment(WeaponSlots.SLOT_MAIN, ext))
	var slot := slots.get_slot(WeaponSlots.SLOT_MAIN)
	assert_eq(slot.mag, 45, "扩容后弹匣补满到 45")
	assert_eq(_equipped, ["bulwark:attachment/ext"])

func test_equip_replaces_same_slot() -> void:
	var old_att := _make_attachment(AttachmentData.AttachmentSlot.SIGHT, &"spread", -1.0, 1.0, "attachment/old")
	var new_att := _make_attachment(AttachmentData.AttachmentSlot.SIGHT, &"spread", -2.0, 1.0, "attachment/new")
	assert_true(slots.equip_attachment(WeaponSlots.SLOT_MAIN, old_att))
	assert_true(slots.equip_attachment(WeaponSlots.SLOT_MAIN, new_att))
	assert_eq(slots.get_attachment(WeaponSlots.SLOT_MAIN, AttachmentData.AttachmentSlot.SIGHT).id, "attachment/new")
	assert_eq(_equipped.size(), 2)
	assert_has(_unequipped, "bulwark:attachment/old", "旧配件卸下广播")

func test_unequip_attachment() -> void:
	var att := _make_attachment(AttachmentData.AttachmentSlot.MUZZLE, &"damage", 2.0, 1.0, "attachment/dmg")
	slots.equip_attachment(WeaponSlots.SLOT_MAIN, att)
	assert_true(slots.unequip_attachment(WeaponSlots.SLOT_MAIN, AttachmentData.AttachmentSlot.MUZZLE))
	assert_null(slots.get_attachment(WeaponSlots.SLOT_MAIN, AttachmentData.AttachmentSlot.MUZZLE))
	assert_eq(_unequipped, ["bulwark:attachment/dmg"])
	assert_false(slots.unequip_attachment(WeaponSlots.SLOT_MAIN, AttachmentData.AttachmentSlot.MUZZLE), "空槽拒绝卸下")

func test_effective_stats_include_attachments() -> void:
	var dmg := _make_attachment(AttachmentData.AttachmentSlot.MUZZLE, &"damage", 3.0, 1.0, "attachment/dmg")
	slots.equip_attachment(WeaponSlots.SLOT_MAIN, dmg)
	var stats := slots.get_effective_stats(slots.get_slot(WeaponSlots.SLOT_MAIN))
	assert_almost_eq(stats.damage, 15.0, 0.001, "配件伤害修正进入结算")

func test_fire_rate_affected_by_attachment() -> void:
	# 射速配件 → 开火 CD 缩短
	var rate := _make_attachment(AttachmentData.AttachmentSlot.STOCK, &"fire_rate", 0.0, 2.0, "attachment/rate")
	slots.equip_attachment(WeaponSlots.SLOT_MAIN, rate)
	assert_true(slots.try_fire(Vector2.RIGHT))
	assert_almost_eq(slots.get_current_slot().fire_cd, 1.0 / 16.0, 0.001, "射速 ×2 → CD 减半")

func test_reload_time_affected_by_attachment() -> void:
	var stock := _make_attachment(AttachmentData.AttachmentSlot.STOCK, &"reload_time", 0.0, 0.5, "attachment/stock")
	slots.equip_attachment(WeaponSlots.SLOT_MAIN, stock)
	slots.try_fire(Vector2.RIGHT)
	assert_true(slots.try_reload())
	assert_almost_eq(slots.get_current_slot().reload_timer, 0.6, 0.001, "换弹 ×0.5 → 0.6s")

func test_equip_rejected_on_empty_slot() -> void:
	var att := _make_attachment(AttachmentData.AttachmentSlot.MUZZLE, &"damage", 1.0, 1.0)
	assert_false(slots.equip_attachment(WeaponSlots.SLOT_SUB, att), "未装填槽位拒绝装配")

func test_global_bonus_affects_fire_rate() -> void:
	# RunState 武器向强化 → WeaponSlots 结算生效
	var run_state := RunState.new()
	var mod := AttributeModifierData.new()
	mod.attribute = &"fire_rate"
	mod.multiplier = 1.5
	run_state.apply_bonus_modifier(mod)
	var slots2 := WeaponSlots.new(AmmoSystem.new(), run_state)
	var rifle_type := WeaponTypeData.new()
	rifle_type.id = "weapon/type/assault_rifle"
	var rifle := WeaponModelData.new()
	rifle.id = "weapon/model/storm7"
	rifle.fire_rate = 8.0
	rifle.mag_size = 5
	slots2.assign_slot(WeaponSlots.SLOT_MAIN, rifle_type, rifle)
	assert_true(slots2.try_fire(Vector2.RIGHT))
	assert_almost_eq(slots2.get_current_slot().fire_cd, 1.0 / 12.0, 0.001, "全局射速 ×1.5 生效")
