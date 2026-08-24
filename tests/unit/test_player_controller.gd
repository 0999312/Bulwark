extends GutTest
## 玩家控制器 FSM 测试：Idle/Move/Shoot/Reload/Dead 状态机（M0 子集）

var controller: PlayerController

func before_each() -> void:
	var attributes := AttributeSet.new()
	attributes.set_base(AttributeSet.MAX_HEALTH, 100.0)
	attributes.set_base(AttributeSet.MOVE_SPEED, 260.0)
	attributes.set_base(AttributeSet.RELOAD_SPEED, 1.0)
	var ammo := AmmoSystem.new()
	ammo.set_count(WeaponTypeData.AmmoType.BULLET, 90)
	var slots := WeaponSlots.new(ammo)
	var rifle_type := WeaponTypeData.new()
	rifle_type.id = "weapon/type/ar"
	rifle_type.slot = WeaponTypeData.SlotType.MAIN
	rifle_type.switch_cd = 1.5
	var rifle := WeaponModelData.new()
	rifle.id = "weapon/model/ar_1"
	rifle.mag_size = 30
	rifle.fire_rate = 8.0
	rifle.reload_time = 0.5
	slots.assign_slot(WeaponSlots.SLOT_MAIN, rifle_type, rifle)
	var pistol_type := WeaponTypeData.new()
	pistol_type.id = "weapon/type/hg"
	pistol_type.slot = WeaponTypeData.SlotType.PISTOL
	pistol_type.switch_cd = 0.3
	var pistol := WeaponModelData.new()
	pistol.id = "weapon/model/hg_1"
	pistol.mag_size = 12
	slots.assign_slot(WeaponSlots.SLOT_PISTOL, pistol_type, pistol)
	controller = PlayerController.new(attributes, slots)

func test_initial_state_idle() -> void:
	assert_eq(controller.state, PlayerController.State.IDLE)

func test_move_intent_drives_move_state() -> void:
	controller.set_move_intent(Vector2(1, 0))
	controller.tick(0.016)
	assert_eq(controller.state, PlayerController.State.MOVE)

func test_shoot_intent_drives_shoot_state() -> void:
	controller.set_shoot_intent(true)
	controller.tick(0.016)
	assert_eq(controller.state, PlayerController.State.SHOOT)

func test_no_intent_returns_to_idle() -> void:
	controller.set_move_intent(Vector2(1, 0))
	controller.tick(0.016)
	assert_eq(controller.state, PlayerController.State.MOVE)
	controller.set_move_intent(Vector2.ZERO)
	controller.tick(0.016)
	assert_eq(controller.state, PlayerController.State.IDLE)

func test_reload_state_after_empty_mag() -> void:
	controller.set_shoot_intent(true)
	for i in 30:
		controller.tick(0.5)
	# 第 31 个 tick：弹匣空 → 自动换弹 → Reload 状态
	controller.tick(0.016)
	assert_eq(controller.state, PlayerController.State.RELOAD, "弹匣空自动换弹 → Reload 状态")
	controller.set_shoot_intent(false)
	controller.tick(0.6)
	assert_eq(controller.state, PlayerController.State.IDLE, "换弹完成回到 Idle")

func test_dead_state_from_damage() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 999.0)
	controller.take_damage(ctx)
	assert_eq(controller.state, PlayerController.State.DEAD)
	assert_true(controller.is_dead())
	# 死亡后意图不再生效（复活系统 M0 不做，结构留位）
	controller.set_move_intent(Vector2(1, 0))
	controller.set_shoot_intent(true)
	controller.tick(0.016)
	assert_eq(controller.state, PlayerController.State.DEAD)

func test_damage_applied_via_pipeline_and_health_clamped() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 30.0)
	controller.take_damage(ctx)
	assert_almost_eq(controller.health, 70.0, 0.001)

func test_switch_intent_goes_to_weapon_slots() -> void:
	controller.intent_switch(WeaponSlots.SLOT_PISTOL)
	assert_true(controller.weapon_slots.is_switching())
	controller.tick(0.4)
	assert_eq(controller.weapon_slots.current_index, WeaponSlots.SLOT_PISTOL)

func test_reload_intent_goes_to_weapon_slots() -> void:
	# 主动换弹：先开一枪（弹匣 30→29）再按 R
	controller.set_shoot_intent(true)
	controller.tick(0.016)
	controller.set_shoot_intent(false)
	assert_eq(controller.weapon_slots.get_current_slot().mag, 29, "开火应扣弹匣")
	controller.intent_reload()
	assert_true(controller.weapon_slots.is_reloading(), "intent_reload 应触发换弹")
	controller.tick(0.6)
	assert_false(controller.weapon_slots.is_reloading(), "换弹应完成")
	assert_eq(controller.weapon_slots.get_current_slot().mag, 30, "换弹回满弹匣")

func test_attribute_final_composition() -> void:
	# 属性公式：(base + additive) × multiplicative
	controller.attribute_set.add_modifier(AttributeSet.MOVE_SPEED, 40.0)
	controller.attribute_set.add_modifier(AttributeSet.MOVE_SPEED, 1.5, true)
	assert_almost_eq(controller.attribute_set.get_final(AttributeSet.MOVE_SPEED), 450.0, 0.001)
