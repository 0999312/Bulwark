extends GutTest
## 枪械手感：散布纯函数测试（表现层弹道偏移，headless 可测）
## PlayerView.apply_spread 是静态纯函数：方向旋转随机偏移角（度）

func test_zero_spread_keeps_direction() -> void:
	var rng := RandomNumberGenerator.new()
	var dir := Vector2.RIGHT
	assert_eq(PlayerView.apply_spread(dir, 0.0, rng), dir, "零散布方向不变")
	assert_eq(PlayerView.apply_spread(Vector2.UP, 0.0, rng), Vector2.UP, "零散布方向不变（任意方向）")

func test_spread_offsets_within_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 300:
		var spread_dir := PlayerView.apply_spread(Vector2.RIGHT, 3.0, rng)
		assert_almost_eq(spread_dir.length(), 1.0, 0.0001, "散布后保持单位向量")
		var angle := absf(spread_dir.angle())
		assert_true(angle <= deg_to_rad(3.0) + 0.0001, "偏移角不超过散布上限")

func test_spread_mean_near_zero() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var total := 0.0
	var n := 500
	for i in n:
		total += PlayerView.apply_spread(Vector2.RIGHT, 2.0, rng).angle()
	assert_almost_eq(total / n, 0.0, 0.05, "均匀散布均值≈原方向（无系统偏差）")

func test_zero_length_direction_is_untouched() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(PlayerView.apply_spread(Vector2.ZERO, 5.0, rng), Vector2.ZERO, "零向量不参与旋转")
