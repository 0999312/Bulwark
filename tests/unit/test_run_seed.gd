extends GutTest
## P0-7：本局随机种子注入测试
## - 默认偏移 0：WaveDirector 行为与旧版完全一致（WaveData.seed 原样）→ 既有测试确定性
## - set_run_seed 后波次构成随种子变化（如相同 WaveData 不同 run seed 生成不同构成）

var _warnings: Array[String] = []

func before_each() -> void:
	_warnings.clear()
	EventBus.clear_all_listeners()

func _make_wave(seed_value: int) -> WaveData:
	var wave := WaveData.new()
	wave.seed = seed_value
	wave.directions = [0, 2, 4, 6]
	wave.count_range = Vector2i(1, 10)
	wave.enemy_location = "bulwark:enemy/runner"
	wave.warn_duration = 1.0
	wave.spawn_interval = 0.1
	wave.burst_chance = 0.0
	return wave

func _start_and_capture(run_seed: int) -> String:
	_warnings.clear()
	EventBus.clear_all_listeners()
	var director := WaveDirector.new()
	if run_seed != 0:
		director.set_run_seed(run_seed)
	EventBus.subscribe(&"WaveWarningEvent",
		func(e: WaveWarningEvent) -> void: _warnings.append(e.composition.summarize()))
	director.start([_make_wave(101)])
	return _warnings[0] if not _warnings.is_empty() else ""

func test_default_seed_offset_is_zero() -> void:
	var director := WaveDirector.new()
	assert_eq(director.get_run_seed_offset(), 0, "默认 run seed 偏移为 0（回退确定性）")

func test_run_seed_changes_wave_composition() -> void:
	var s0 := _start_and_capture(0)
	var s1 := _start_and_capture(12345)
	assert_false(s0.is_empty(), "基线构成已捕获")
	assert_false(s1.is_empty(), "注入构成已捕获")
	assert_ne(s0, s1, "不同 run seed 应产生不同波次构成")

func test_same_run_seed_is_deterministic() -> void:
	var a := _start_and_capture(777)
	var b := _start_and_capture(777)
	assert_eq(a, b, "同 run seed 反复生成应可复现")
