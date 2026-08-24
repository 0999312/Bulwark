extends GutTest
## M5b：自动炮塔索敌/开火 + 通用设施耐久/修复

var _fired: Array[TurretFiredEvent] = []

func before_each() -> void:
	_fired.clear()
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"TurretFiredEvent",
		func(e: TurretFiredEvent) -> void: _fired.append(e))

func _make_turret_data() -> DefenseFacilityData:
	var data := DefenseFacilityData.new()
	data.id = "facility/turret"
	data.facility_type = DefenseFacilityData.FacilityType.TURRET
	data.max_durability = 100.0
	data.turret_damage = 6.0
	data.turret_fire_rate = 1.5
	data.turret_range = 200.0
	data.repair_cost = 1
	data.repair_amount = 30.0
	return data

func _make_turret() -> TurretController:
	var turret := TurretController.new(_make_turret_data(), 1)
	turret.setup_position(Vector2.ZERO)
	return turret

func test_turret_acquires_nearest_in_range_and_fires() -> void:
	var turret := _make_turret()
	var enemies := [
		{&"net_id": 1, &"pos": Vector2(100, 0), &"radius": 14.0, &"alive": true},
		{&"net_id": 2, &"pos": Vector2(80, 0), &"radius": 14.0, &"alive": true},
	]
	turret.tick(0.0, enemies)
	assert_eq(_fired.size(), 1, "冷却结束立即开火")
	assert_eq(_fired[0].target_net_id, 2, "取最近目标")
	assert_almost_eq(_fired[0].damage, 6.0, 0.001)
	# BUG 交接：target_position = HitscanResolver 命中点（圆心 80,0 - 半径 14 → x=66）
	assert_almost_eq(_fired[0].target_position.x, 66.0, 0.001,
		"粗射线终点为圆面进入点而非目标圆心")

func test_turret_cooldown_limits_fire_rate() -> void:
	var turret := _make_turret()
	var enemies := [{&"net_id": 1, &"pos": Vector2(100, 0), &"radius": 14.0, &"alive": true}]
	turret.tick(0.0, enemies)
	assert_eq(_fired.size(), 1)
	turret.tick(0.3, enemies)
	assert_eq(_fired.size(), 1, "0.3s < 0.667s 射速间隔不重复开火")
	turret.tick(0.4, enemies)
	assert_eq(_fired.size(), 2, "累计 0.7s ≥ 0.667s 再次开火")

func test_turret_damage_bonus_from_shop_upgrade() -> void:
	var turret := TurretController.new(_make_turret_data(), 2, 1.0)
	turret.setup_position(Vector2.ZERO)
	assert_almost_eq(turret.get_damage(), 7.0, 0.001, "炮塔伤害 +1 商品接通后基础 6→7")

func test_turret_ignores_out_of_range_or_dead() -> void:
	var turret := _make_turret()
	var enemies := [
		{&"net_id": 1, &"pos": Vector2(999, 0), &"radius": 14.0, &"alive": true},
		{&"net_id": 2, &"pos": Vector2(50, 0), &"radius": 14.0, &"alive": false},
	]
	turret.tick(0.0, enemies)
	assert_eq(_fired.size(), 0, "射程外或已死目标不触发")

func test_facility_damage_and_repair() -> void:
	var data := _make_turret_data()
	var facility := FacilityController.new(data, 1)
	facility.take_damage(40.0)
	assert_almost_eq(facility.durability, 60.0, 0.001)
	facility.repair(30.0)
	assert_almost_eq(facility.durability, 90.0, 0.001)
	assert_false(facility.is_destroyed())
	facility.take_damage(999.0)
	assert_true(facility.is_destroyed())
	facility.repair(50.0)
	assert_almost_eq(facility.durability, 0.0, 0.001, "已摧毁设施不可修复")
