extends GutTest
## 弹药系统测试：按类型计数、有限/无限备弹（P25 手枪无限）

func test_count_consume_add() -> void:
	var ammo := AmmoSystem.new()
	ammo.set_count(WeaponTypeData.AmmoType.BULLET, 10)
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 10)
	assert_true(ammo.consume(WeaponTypeData.AmmoType.BULLET, 4))
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 6)
	assert_false(ammo.consume(WeaponTypeData.AmmoType.BULLET, 7), "备弹不足拒绝消耗")
	ammo.add(WeaponTypeData.AmmoType.BULLET, 5)
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 11)

func test_unset_type_is_zero() -> void:
	var ammo := AmmoSystem.new()
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.FUEL), 0)
	assert_false(ammo.consume(WeaponTypeData.AmmoType.FUEL, 1))

func test_infinite_reserve_never_depletes() -> void:
	# P25：手枪无限备弹（INFINITE = -1）
	var ammo := AmmoSystem.new()
	ammo.set_count(WeaponTypeData.AmmoType.BULLET, AmmoSystem.INFINITE)
	assert_true(ammo.is_infinite(WeaponTypeData.AmmoType.BULLET))
	for i in 1000:
		assert_true(ammo.consume(WeaponTypeData.AmmoType.BULLET, 30))
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), AmmoSystem.INFINITE)

func test_ammo_types_are_independent() -> void:
	var ammo := AmmoSystem.new()
	ammo.set_count(WeaponTypeData.AmmoType.BULLET, 5)
	ammo.set_count(WeaponTypeData.AmmoType.ENERGY, 3)
	ammo.consume(WeaponTypeData.AmmoType.BULLET, 5)
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.BULLET), 0)
	assert_eq(ammo.get_count(WeaponTypeData.AmmoType.ENERGY), 3, "类型独立计数")
