extends GutTest
## 基地核心测试（P7：耐久归零判负）
## 敌人啃基地的接线（EnemyAttackEvent → BaseCore）在 GameSession（装配层）完成，
## 单测覆盖：BaseCore 扣减/判负 + RunnerController 攻击事件（见 test_runner_controller.gd）

func test_durability_clamp_and_destroy() -> void:
	var core := BaseCore.new(100.0)
	assert_eq(core.durability, 100.0)
	assert_false(core.is_destroyed())
	core.take_damage(40.0)
	assert_eq(core.durability, 60.0)
	assert_false(core.is_destroyed())
	core.take_damage(100.0)
	assert_eq(core.durability, 0.0)
	assert_true(core.is_destroyed(), "耐久归零 → destroyed")
	core.take_damage(10.0)
	assert_eq(core.durability, 0.0, "归零后不再扣减")

func test_negative_or_zero_damage_ignored() -> void:
	var core := BaseCore.new(100.0)
	core.take_damage(-5.0)
	core.take_damage(0.0)
	assert_eq(core.durability, 100.0)

func test_durability_ratio() -> void:
	var core := BaseCore.new(200.0)
	assert_almost_eq(core.get_durability_ratio(), 1.0, 0.001)
	core.take_damage(50.0)
	assert_almost_eq(core.get_durability_ratio(), 0.75, 0.001)

func test_exact_damage_destroys() -> void:
	var core := BaseCore.new(30.0)
	core.take_damage(30.0)
	assert_true(core.is_destroyed())
	assert_eq(core.durability, 0.0)
