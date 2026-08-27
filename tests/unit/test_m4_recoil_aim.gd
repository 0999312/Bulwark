extends GutTest
## M4：后坐角 → 弹道方向的纯函数（PlayerController.aim_after_recoil）
## 断言：零角度不变、正/负角度旋转方向正确、角度影响弹道（非纯表现）。

func test_zero_recoil_keeps_aim() -> void:
	assert_eq(PlayerController.aim_after_recoil(Vector2.RIGHT, 0.0), Vector2.RIGHT)
	assert_eq(PlayerController.aim_after_recoil(Vector2.UP, 0.0), Vector2.UP)

func test_recoil_rotates_aim() -> void:
	var aim := PlayerController.aim_after_recoil(Vector2.RIGHT, 2.0)
	assert_almost_eq(aim.length(), 1.0, 0.0001, "保持单位向量")
	assert_almost_eq(aim.angle(), deg_to_rad(2.0), 0.0001, "+2° 逆时针旋转")
	var aim_down := PlayerController.aim_after_recoil(Vector2.RIGHT, -2.0)
	assert_almost_eq(aim_down.angle(), deg_to_rad(-2.0), 0.0001, "-2° 顺时针旋转")

func test_recoil_affects_spread_chain() -> void:
	# 后坐角进入散布链：aim_after_recoil 后再 apply_spread，方向偏离应含 recoil
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var after := PlayerController.aim_after_recoil(Vector2.RIGHT, 3.0)
	var spread := PlayerView.apply_spread(after, 2.0, rng)
	assert_true(absf(spread.angle()) > 0.0, "后坐 + 散布后弹道偏离原方向")
