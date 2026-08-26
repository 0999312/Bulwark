extends GutTest
## P2-17：无尽轮次测试（循环章节、难度上抬、永不判胜）

var _warnings: Array[WaveWarningEvent] = []
var _victory := false

func before_each() -> void:
	_warnings.clear()
	_victory = false
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"WaveWarningEvent",
		func(e: WaveWarningEvent) -> void: _warnings.append(e))
	EventBus.subscribe(&"RunVictoryEvent", func(_e: Event) -> void: _victory = true)

func test_endless_loops_without_victory() -> void:
	var run: RunDefinition = load("res://resources/runs/arcade_run.tres")
	var director := WaveDirector.new()
	director.start_run(run)
	director.infinite_loop = true
	var guard := 0
	while director.cycle_index < 2 and guard < 20000:
		director.tick(0.1)
		if director.phase == WaveDirector.Phase.ACTIVE:
			while director.pending_spawns > 0:
				director.register_enemy_spawned()
			while director.alive_enemies > 0:
				director.register_enemy_died()
		guard += 1
	assert_eq(director.cycle_index, 2, "至少进入第 3 循环")
	assert_almost_eq(director.difficulty_cycle_scale, 1.15 * 1.15, 0.01,
		"两个循环后的难度系数 = 1.15^2")
	assert_false(_victory, "无尽模式永不广播 RunVictoryEvent")

func test_endless_cycle_index_in_events() -> void:
	var run: RunDefinition = load("res://resources/runs/arcade_run.tres")
	var director := WaveDirector.new()
	director.start_run(run)
	director.infinite_loop = true
	_warnings.clear()
	# 手动快进 16 波到循环边界
	var guard := 0
	while director.cycle_index < 1 and guard < 20000:
		director.tick(0.1)
		if director.phase == WaveDirector.Phase.ACTIVE:
			while director.pending_spawns > 0:
				director.register_enemy_spawned()
			while director.alive_enemies > 0:
				director.register_enemy_died()
		guard += 1
	var cycle_warnings := 0
	for w in _warnings:
		if w.cycle_index >= 1:
			cycle_warnings += 1
	assert_eq(director.cycle_index, 1)
	assert_gt(cycle_warnings, 0, "循环后预警事件携带 cycle_index>=1")
