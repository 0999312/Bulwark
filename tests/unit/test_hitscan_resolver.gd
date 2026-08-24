extends GutTest
## M3 方案 B：命中判定逻辑化——HitscanResolver 纯几何判定单测
## （线段 vs 圆形目标：命中/未命中/最近优先/边界情形）

func _target(pos: Vector2, radius: float = 14.0) -> Dictionary:
	return {&"pos": pos, &"radius": radius}

func test_hit_center_target() -> void:
	# 敌人正前方 100px，半径 14 → 命中，命中点在敌人表面
	var res := HitscanResolver.resolve_hit(
		Vector2.ZERO, Vector2.RIGHT, 500.0, [_target(Vector2(100, 0))])
	assert_true(res.get(&"hit", false), "正前方目标应命中")
	assert_eq(res.get(&"index", -1), 0)
	var point: Vector2 = res.get(&"point", Vector2.ZERO)
	assert_almost_eq(point.x, 86.0, 1.0, "命中点在敌人表面（100 - 14）")

func test_miss_out_of_range() -> void:
	# 目标在射程外 → 未命中，point = 射程尽头
	var res := HitscanResolver.resolve_hit(
		Vector2.ZERO, Vector2.RIGHT, 100.0, [_target(Vector2(200, 0))])
	assert_false(res.get(&"hit", false), "射程外未命中")
	var point: Vector2 = res.get(&"point", Vector2.ZERO)
	assert_almost_eq(point.x, 100.0, 0.001, "未命中 point = 射程尽头")

func test_miss_by_angle() -> void:
	# 目标在侧向但射线不经过 → 未命中
	var res := HitscanResolver.resolve_hit(
		Vector2.ZERO, Vector2.RIGHT, 500.0, [_target(Vector2(100, 50))])
	assert_false(res.get(&"hit", false), "偏离射线路径未命中")

func test_nearest_target_priority() -> void:
	# 两个目标在射线上：取最近命中
	var res := HitscanResolver.resolve_hit(
		Vector2.ZERO, Vector2.RIGHT, 500.0, [
			_target(Vector2(200, 0)),
			_target(Vector2(100, 0)),
		])
	assert_true(res.get(&"hit", false))
	assert_eq(res.get(&"index", -1), 1, "取最近目标")

func test_hit_off_axis_closest_point() -> void:
	# 射线擦过目标边缘（最近点距离 < 半径）→ 命中
	var res := HitscanResolver.resolve_hit(
		Vector2.ZERO, Vector2.RIGHT, 500.0, [_target(Vector2(100, 13.9))])
	assert_true(res.get(&"hit", false), "擦边命中（13.9 < 14）")

func test_zero_range_or_dir() -> void:
	var res := HitscanResolver.resolve_hit(Vector2.ZERO, Vector2.RIGHT, 0.0,
		[_target(Vector2(50, 0))])
	assert_false(res.get(&"hit", false), "射程 0 不命中")
	var res2 := HitscanResolver.resolve_hit(Vector2.ZERO, Vector2.ZERO, 500.0,
		[_target(Vector2(50, 0))])
	assert_false(res2.get(&"hit", false), "零方向不命中")
