extends GutTest
## 三槽位武器 + 切换 CD 状态机测试（已定 P11/P23/P25）
## CD 规则：主↔副 1.5s；↔手枪 0.3s（落地：min(双方 switch_cd)）

const RIFLE_ID := "weapon/model/ar_1"
const PISTOL_ID := "weapon/model/hg_1"

var ammo: AmmoSystem
var slots: WeaponSlots

func before_each() -> void:
	ammo = AmmoSystem.new()
	ammo.set_count(WeaponTypeData.AmmoType.BULLET, 90)
	slots = WeaponSlots.new(ammo)
	var rifle_type := WeaponTypeData.new()
	rifle_type.id = "weapon/type/ar"
	rifle_type.slot = WeaponTypeData.SlotType.MAIN
	rifle_type.switch_cd = 1.5
	var rifle := WeaponModelData.new()
	rifle.id = RIFLE_ID
	rifle.damage = 12.0
	rifle.fire_rate = 8.0
	rifle.mag_size = 3
	rifle.reload_time = 0.5
	slots.assign_slot(WeaponSlots.SLOT_MAIN, rifle_type, rifle)
	var pistol_type := WeaponTypeData.new()
	pistol_type.id = "weapon/type/hg"
	pistol_type.slot = WeaponTypeData.SlotType.PISTOL
	pistol_type.switch_cd = 0.3
	var pistol := WeaponModelData.new()
	pistol.id = PISTOL_ID
	pistol.damage = 6.0
	pistol.fire_rate = 5.0
	pistol.mag_size = 12
	pistol.reload_time = 0.9
	slots.assign_slot(WeaponSlots.SLOT_PISTOL, pistol_type, pistol)

func test_initial_slot_is_main() -> void:
	assert_eq(slots.current_index, WeaponSlots.SLOT_MAIN)
	assert_true(slots.is_slot_ready(WeaponSlots.SLOT_MAIN))
	assert_true(slots.is_slot_ready(WeaponSlots.SLOT_PISTOL))

func test_switch_to_pistol_cd_is_0_3() -> void:
	# P23：↔手枪 0.3s
	assert_true(slots.try_switch_to(WeaponSlots.SLOT_PISTOL))
	assert_true(slots.is_switching())
	assert_almost_eq(slots.switch_timer, 0.3, 0.001)

func test_main_to_sub_cd_is_1_5_structure() -> void:
	# P23：主↔副 1.5s（副槽 M1 实装，结构先行）
	var sub_type := WeaponTypeData.new()
	sub_type.id = "weapon/type/sg_placeholder"
	sub_type.slot = WeaponTypeData.SlotType.SUB
	sub_type.switch_cd = 1.5
	var sub := WeaponModelData.new()
	sub.id = "weapon/model/sg_placeholder"
	sub.mag_size = 5
	slots.assign_slot(WeaponSlots.SLOT_SUB, sub_type, sub)
	assert_true(slots.try_switch_to(WeaponSlots.SLOT_SUB))
	assert_almost_eq(slots.switch_timer, 1.5, 0.001)

func test_switch_rejected_while_switching() -> void:
	slots.try_switch_to(WeaponSlots.SLOT_PISTOL)
	assert_false(slots.try_switch_to(WeaponSlots.SLOT_MAIN), "切换中拒绝再次切换")

func test_switch_rejected_for_empty_slot() -> void:
	assert_false(slots.try_switch_to(WeaponSlots.SLOT_SUB), "未装填槽位拒绝切换")
	assert_false(slots.try_switch_to(99), "越界槽位拒绝")

func test_switch_completes_after_cd() -> void:
	slots.try_switch_to(WeaponSlots.SLOT_PISTOL)
	slots.tick(0.1)
	assert_true(slots.is_switching())
	slots.tick(0.25)
	assert_false(slots.is_switching())
	assert_eq(slots.current_index, WeaponSlots.SLOT_PISTOL)

func test_fire_consumes_ammo_and_respects_fire_rate() -> void:
	assert_true(slots.try_fire(Vector2.RIGHT))
	assert_eq(slots.get_current_slot().mag, 2, "开火应扣弹匣")
	assert_false(slots.try_fire(Vector2.RIGHT), "射速 CD 内拒绝")
	slots.tick(1.0 / 8.0)
	assert_true(slots.try_fire(Vector2.RIGHT))

func test_empty_mag_triggers_auto_reload() -> void:
	for i in 3:
		assert_true(slots.try_fire(Vector2.RIGHT))
		slots.tick(1.0)
	assert_false(slots.try_fire(Vector2.RIGHT), "弹匣空拒绝开火")
	assert_true(slots.is_reloading(), "弹匣空自动换弹")
	slots.tick(0.5)
	assert_false(slots.is_reloading())
	assert_eq(slots.get_current_slot().mag, 3, "换弹回满弹匣")
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 90 - 3, "换弹从备弹扣除")

func test_pistol_limited_mag_infinite_reserve() -> void:
	# P25 修订：手枪弹匣有限（打空需换弹）、备弹无限（换弹免费补满、不消耗 AmmoSystem 计数）
	slots.try_switch_to(WeaponSlots.SLOT_PISTOL)
	slots.tick(0.3)
	assert_true(slots.is_current_pistol())
	for i in 12:
		assert_true(slots.try_fire(Vector2.RIGHT), "第 %d 发应可开火" % (i + 1))
		slots.tick(0.3)
	assert_false(slots.try_fire(Vector2.RIGHT), "手枪弹匣空拒绝开火")
	assert_true(slots.is_reloading(), "手枪弹匣空自动换弹")
	slots.tick(0.9)
	assert_false(slots.is_reloading())
	assert_eq(slots.get_current_slot().mag, 12, "手枪换弹回满弹匣")
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 90, "手枪换弹不消耗备弹")

func test_manual_reload_mid_mag() -> void:
	# 主动换弹（R 键）：弹匣未空也可换弹
	slots.try_fire(Vector2.RIGHT)
	assert_eq(slots.get_current_slot().mag, 2)
	assert_true(slots.try_reload(), "主动换弹应受理")
	assert_true(slots.is_reloading())
	slots.tick(0.5)
	assert_false(slots.is_reloading())
	assert_eq(slots.get_current_slot().mag, 3, "换弹回满弹匣")
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 89, "补 1 发扣 1 备弹")

func test_manual_reload_rejected_when_full() -> void:
	assert_false(slots.try_reload(), "弹匣满拒绝换弹")

func test_manual_reload_rejected_while_switching() -> void:
	slots.try_switch_to(WeaponSlots.SLOT_PISTOL)
	assert_false(slots.try_reload(), "切换中拒绝换弹")

func test_pistol_manual_reload_free() -> void:
	# 手枪主动换弹同样免费（无限备弹）
	slots.try_switch_to(WeaponSlots.SLOT_PISTOL)
	slots.tick(0.3)
	slots.try_fire(Vector2.RIGHT)
	assert_true(slots.try_reload(), "手枪主动换弹应受理")
	slots.tick(0.9)
	assert_eq(slots.get_current_slot().mag, 12, "手枪换弹回满")
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 90, "手枪换弹不消耗备弹")

func test_switch_cancels_reload() -> void:
	# 弹匣空 → 换弹中 → 切手枪打断换弹（M0 规则：切换打断换弹）
	for i in 3:
		slots.try_fire(Vector2.RIGHT)
		slots.tick(1.0)
	slots.try_fire(Vector2.RIGHT)
	assert_true(slots.is_reloading())
	assert_true(slots.try_switch_to(WeaponSlots.SLOT_PISTOL))
	assert_false(slots.get_slot(WeaponSlots.SLOT_MAIN).reloading, "切换打断换弹")
