extends GutTest
## M2 双人强度缩放（RunnerController hp_scale）：血量乘数生效、默认参数不破坏单机路径

func _make_data(hp: float) -> EnemyData:
	var data := EnemyData.new()
	data.max_hp = hp
	return data

func test_hp_scale_multiplies_health() -> void:
	var data := _make_data(30.0)
	var runner := RunnerController.new(data, 1.6)
	assert_almost_eq(runner.health, 48.0, 0.001, "血量 ×1.6（30→48）")

func test_hp_scale_default_is_no_scale() -> void:
	var data := _make_data(30.0)
	var runner := RunnerController.new(data)
	assert_almost_eq(runner.health, 30.0, 0.001, "默认 1.0 不缩放（单机路径）")

func test_hp_scale_guard_against_non_positive() -> void:
	var data := _make_data(30.0)
	var runner := RunnerController.new(data, 0.0)
	assert_gt(runner.health, 0.0, "非正缩放被防御钳制")
	var runner2 := RunnerController.new(data, -2.0)
	assert_gt(runner2.health, 0.0, "负数缩放被防御钳制")

func test_scaled_runner_keeps_behaviour() -> void:
	var data := _make_data(30.0)
	data.attack_interval = 1.0
	data.attack_range = 70.0
	var runner := RunnerController.new(data, 1.6)
	# 攻击计时：首次出爪前有一个完整间隔（M1 行为保持）
	assert_eq(runner.attack_timer, 1.0, "攻击计时不受缩放影响")
	runner.tick(0.5, 50.0)  # 距离 50 < 70 → 攻击状态计时
	assert_eq(runner.state, RunnerController.State.ATTACK, "行为 FSM 不受缩放影响")
