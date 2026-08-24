extends GutTest
## M5b：个人军械库（Arsenal）与 WeaponSlots 换型号

func test_arsenal_starts_with_defaults() -> void:
	var arsenal := Arsenal.new(["bulwark:weapon/model/ar_1"])
	assert_true(arsenal.owns("bulwark:weapon/model/ar_1"))
	assert_false(arsenal.owns("bulwark:weapon/model/ar_2"))

func test_arsenal_add_model_idempotent() -> void:
	var arsenal := Arsenal.new()
	assert_true(arsenal.add_model("bulwark:weapon/model/ar_2"))
	assert_false(arsenal.add_model("bulwark:weapon/model/ar_2"), "重复添加被拒绝")
	assert_eq(arsenal.get_owned_models().size(), 1)

func test_weapon_slots_set_model_matches_type() -> void:
	var ammo := AmmoSystem.new()
	var slots := WeaponSlots.new(ammo)
	var ar_type := WeaponTypeData.new()
	ar_type.id = "weapon/type/ar"
	var ar_1 := WeaponModelData.new()
	ar_1.id = "weapon/model/ar_1"
	ar_1.type_id = "bulwark:weapon/type/ar"
	ar_1.mag_size = 30
	slots.assign_slot(WeaponSlots.SLOT_MAIN, ar_type, ar_1)

	var ar_2 := WeaponModelData.new()
	ar_2.id = "weapon/model/ar_2"
	ar_2.type_id = "bulwark:weapon/type/ar"
	ar_2.mag_size = 24
	assert_true(slots.set_model(WeaponSlots.SLOT_MAIN, ar_2), "同类型换型号成功")
	assert_eq(slots.get_slot(WeaponSlots.SLOT_MAIN).model_data.id, "weapon/model/ar_2")
	assert_eq(slots.get_slot(WeaponSlots.SLOT_MAIN).mag, 24, "换型号后弹匣按新模型重装")

func test_weapon_slots_set_model_rejects_wrong_type() -> void:
	var ammo := AmmoSystem.new()
	var slots := WeaponSlots.new(ammo)
	var ar_type := WeaponTypeData.new()
	ar_type.id = "weapon/type/ar"
	var ar_1 := WeaponModelData.new()
	ar_1.id = "weapon/model/ar_1"
	ar_1.type_id = "bulwark:weapon/type/ar"
	slots.assign_slot(WeaponSlots.SLOT_MAIN, ar_type, ar_1)
	var sg_1 := WeaponModelData.new()
	sg_1.id = "weapon/model/sg_1"
	sg_1.type_id = "bulwark:weapon/type/sg"
	assert_false(slots.set_model(WeaponSlots.SLOT_MAIN, sg_1), "槽位类型不匹配拒绝")

func test_weapon_slots_set_model_switches_type_within_slot_class() -> void:
	var ammo := AmmoSystem.new()
	var slots := WeaponSlots.new(ammo)
	var ar_type := WeaponTypeData.new()
	ar_type.id = "weapon/type/ar"
	ar_type.slot = WeaponTypeData.SlotType.MAIN
	var ar_1 := WeaponModelData.new()
	ar_1.id = "weapon/model/ar_1"
	ar_1.type_id = "bulwark:weapon/type/ar"
	ar_1.mag_size = 30
	slots.assign_slot(WeaponSlots.SLOT_MAIN, ar_type, ar_1)

	var lmg_type := WeaponTypeData.new()
	lmg_type.id = "weapon/type/lmg"
	lmg_type.slot = WeaponTypeData.SlotType.MAIN
	var lmg_1 := WeaponModelData.new()
	lmg_1.id = "weapon/model/lmg_1"
	lmg_1.type_id = "bulwark:weapon/type/lmg"
	lmg_1.mag_size = 60
	assert_true(slots.set_model(WeaponSlots.SLOT_MAIN, lmg_1, lmg_type),
		"主槽类别内允许 AR → LMG 换型")
	assert_eq(slots.get_slot(WeaponSlots.SLOT_MAIN).type_data.id, "weapon/type/lmg")
	assert_eq(slots.get_slot(WeaponSlots.SLOT_MAIN).model_data.id, "weapon/model/lmg_1")
	assert_eq(slots.get_slot(WeaponSlots.SLOT_MAIN).mag, 60, "换型后按新类型/模型重装")

	var sg_type := WeaponTypeData.new()
	sg_type.id = "weapon/type/sg"
	sg_type.slot = WeaponTypeData.SlotType.SUB
	var sg_1 := WeaponModelData.new()
	sg_1.id = "weapon/model/sg_1"
	sg_1.type_id = "bulwark:weapon/type/sg"
	assert_false(slots.set_model(WeaponSlots.SLOT_MAIN, sg_1, sg_type),
		"跨槽位类别（主槽 ← 副武器）仍拒绝")
