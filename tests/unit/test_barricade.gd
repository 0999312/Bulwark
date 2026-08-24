extends GutTest
## 路障（BarricadeController）：耐久、受击、摧毁事件；奔跑者优先攻击路障；弧形几何纯函数

var data: DefenseFacilityData
var barricade: BarricadeController
var _destroyed: Array[String] = []
var _damaged: Array[float] = []

func before_each() -> void:
	data = DefenseFacilityData.new()
	data.id = "facility/barricade"
	data.max_durability = 150.0
	barricade = BarricadeController.new(data, 1)
	_destroyed.clear()
	_damaged.clear()
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"BarricadeDestroyedEvent",
		func(e: BarricadeDestroyedEvent) -> void: _destroyed.append(e.facility_location))
	EventBus.subscribe(&"BarricadeDamagedEvent",
		func(e: BarricadeDamagedEvent) -> void: _damaged.append(e.durability))

func test_initial_durability() -> void:
	assert_almost_eq(barricade.durability, 150.0, 0.001)
	assert_almost_eq(barricade.get_durability_ratio(), 1.0, 0.001)
	assert_false(barricade.is_destroyed())

func test_take_damage_reduces_durability() -> void:
	barricade.take_damage(30.0)
	assert_almost_eq(barricade.durability, 120.0, 0.001)
	assert_eq(_damaged.size(), 1)
	assert_almost_eq(_damaged[0], 120.0, 0.001)

func test_destroyed_emits_event_once() -> void:
	barricade.take_damage(150.0)
	assert_true(barricade.is_destroyed())
	assert_eq(_destroyed, ["bulwark:facility/barricade#1"])
	barricade.take_damage(10.0)
	assert_eq(_destroyed.size(), 1, "摧毁后不再重复广播")

func test_negative_damage_ignored() -> void:
	barricade.take_damage(-10.0)
	assert_almost_eq(barricade.durability, 150.0, 0.001)

func test_runner_attacks_barricade_preferentially() -> void:
	# 奔跑者：路障在攻击范围内 → 攻击路障（EnemyAttackEvent.target = 路障）
	var runner_data := EnemyData.new()
	runner_data.id = "enemy/runner"
	runner_data.max_hp = 12.0
	runner_data.attack_damage = 6.0
	runner_data.attack_interval = 1.0
	runner_data.attack_range = 50.0
	var runner := EnemyController.new(runner_data)

	var attacks: Array[EnemyAttackEvent] = []
	EventBus.subscribe(&"EnemyAttackEvent",
		func(e: EnemyAttackEvent) -> void: attacks.append(e))

	# 距离 20 ≤ attack_range 50 → 攻击（首爪延迟 1 个间隔后）
	for i in 6:
		runner.tick(0.2, 20.0, barricade)
	assert_eq(attacks.size(), 1, "攻击路障一次")
	assert_eq(attacks[0].target, "bulwark:facility/barricade#1", "攻击目标 = 路障唯一标识")

func test_runner_attacks_base_when_no_barricade() -> void:
	var runner_data := EnemyData.new()
	runner_data.id = "enemy/runner"
	runner_data.attack_damage = 6.0
	runner_data.attack_interval = 1.0
	runner_data.attack_range = 50.0
	var runner := EnemyController.new(runner_data)

	var attacks: Array[EnemyAttackEvent] = []
	EventBus.subscribe(&"EnemyAttackEvent",
		func(e: EnemyAttackEvent) -> void: attacks.append(e))

	for i in 6:
		runner.tick(0.2, 20.0, null)
	assert_eq(attacks.size(), 1)
	assert_eq(attacks[0].target, EnemyAttackEvent.TARGET_BASE, "无路障攻击基地")

func test_runner_switches_back_to_base_after_barricade_destroyed() -> void:
	var runner := EnemyController.new(_make_runner())

	var attacks: Array[EnemyAttackEvent] = []
	EventBus.subscribe(&"EnemyAttackEvent",
		func(e: EnemyAttackEvent) -> void: attacks.append(e))

	# 路障被摧毁后，即使传入同一实例也应转回基地
	barricade.take_damage(9999.0)
	for i in 6:
		runner.tick(0.2, 20.0, barricade)
	assert_eq(attacks.size(), 1)
	assert_eq(attacks[0].target, EnemyAttackEvent.TARGET_BASE, "路障已毁转回攻击基地")


# ─── 弧形几何（纯函数，headless 可测） ───

func test_arc_polygon_vertex_count() -> void:
	var poly := BarricadeController.build_arc_polygon(Vector2(0, 220), deg_to_rad(32.5), 22.0, 24)
	assert_eq(poly.size(), (24 + 1) * 2, "外圈 N+1 + 内圈 N+1 = 50")

func test_arc_polygon_endpoint_symmetry() -> void:
	var center := Vector2(0, 220)
	var half := deg_to_rad(32.5)
	var poly := BarricadeController.build_arc_polygon(center, half, 22.0, 24)
	var n := 24
	var outer_start := poly[0]                       # 外圈起点（angle_start）
	var inner_start := poly[(n + 1) * 2 - 1]        # 内圈末点（同角度反向采样）
	var dir_outer := (outer_start - center).normalized()
	var dir_inner := (inner_start - center).normalized()
	assert_almost_eq(dir_outer.x, dir_inner.x, 0.001, "两端同角度：方向一致")
	assert_almost_eq(dir_outer.y, dir_inner.y, 0.001, "两端同角度：方向一致")
	assert_almost_eq(outer_start.distance_to(center) - inner_start.distance_to(center), 22.0, 0.001, "内外半径差 = 厚度")

func test_arc_polygon_width_equals_thickness() -> void:
	var center := Vector2(0, 220)
	var half := deg_to_rad(32.5)
	var poly := BarricadeController.build_arc_polygon(center, half, 22.0, 24)
	var n := 24
	var mid_outer := poly[n / 2]                    # 外圈中点（angle=mid，指向 -Y）
	var mid_inner := poly[(n + 1) + n / 2]          # 内圈中点
	assert_almost_eq(mid_outer.distance_to(mid_inner), 22.0, 0.001, "弧中线宽度 ≈ 厚度")

func test_arc_polygon_passes_through_origin() -> void:
	# 弧线穿过 view 原点（玩家脚下）：内外圈中点关于原点对称（±thickness/2）
	var center := Vector2(0, 220)
	var half := deg_to_rad(32.5)
	var poly := BarricadeController.build_arc_polygon(center, half, 22.0, 24)
	var n := 24
	var mid_outer := poly[n / 2]
	var mid_inner := poly[(n + 1) + n / 2]
	assert_almost_eq(mid_outer.x, 0.0, 0.001, "外圈中点在 -Y 轴上")
	assert_almost_eq(mid_inner.x, 0.0, 0.001, "内圈中点在 -Y 轴上")
	assert_almost_eq(mid_outer.y, -11.0, 0.001, "外圈中点 y = -thickness/2")
	assert_almost_eq(mid_inner.y, 11.0, 0.001, "内圈中点 y = +thickness/2")

func test_spike_polygon_vertex_count() -> void:
	var poly := BarricadeController.build_spike_polygon(Vector2(0, 220), deg_to_rad(32.5), 22.0, 9.0, 12)
	assert_eq(poly.size(), 3 * 12 + 2, "下边 N+1 + 锯齿 2N + 闭合 1")

func test_arc_segments_count_and_closure() -> void:
	# 碰撞线段：外圈 N + 内圈 N + 两端收口 2 = 2N+2 段 = (2N+2)×2 点
	var segs := BarricadeController.build_arc_segments(Vector2(0, 220), deg_to_rad(30.0), 22.0, 24)
	assert_eq(segs.size(), (24 * 2 + 2) * 2, "线段点数 = (2N+2)×2")
	# 线段端点都在弧带内外圈上（距弧心距离 = outer_r 或 inner_r）
	var center := Vector2(0, 220)
	var outer_r := 220.0 + 11.0
	var inner_r := 220.0 - 11.0
	for i in range(0, segs.size(), 2):
		var d := segs[i].distance_to(center)
		var is_boundary := absf(d - outer_r) < 0.01 or absf(d - inner_r) < 0.01
		assert_true(is_boundary, "线段端点必须落在弧带内外圈边界上")


func _make_runner() -> EnemyData:
	var d := EnemyData.new()
	d.id = "enemy/runner"
	d.attack_damage = 6.0
	d.attack_interval = 1.0
	d.attack_range = 50.0
	return d
