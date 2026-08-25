extends GutTest
## P1-8：RunDefinition/ChapterDefinition + WaveDirector 章间状态机测试
## - 街机 RunDefinition：4 章 × (3 波 + 精英) = 16 波
## - 章间状态机：chapter_index/wave_in_chapter/is_boss 推进正确，打满 16 波胜利
## - legacy 回退：start(waves) 不带章节信息（向后兼容既有 6 波路径）
## - 同屏上限：MAX_ON_SCREEN 生效（同步刷怪簿记下场上敌人数不超上限）

var _warnings: Array[WaveWarningEvent] = []
var _victory := false

func before_each() -> void:
	_warnings.clear()
	_victory = false
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"WaveWarningEvent",
		func(e: WaveWarningEvent) -> void: _warnings.append(e))
	EventBus.subscribe(&"RunVictoryEvent", func(_e: Event) -> void: _victory = true)

func test_arcade_run_has_four_chapters_sixteen_waves() -> void:
	var run: RunDefinition = load("res://resources/runs/arcade_run.tres")
	assert_not_null(run)
	assert_eq(run.chapters.size(), 4, "4 章")
	assert_eq(run.get_total_wave_count(), 16, "4×(3+1)=16 波")
	for chapter: ChapterDefinition in run.chapters:
		assert_eq(chapter.waves.size(), 3, "每章 3 普通波")
		assert_not_null(chapter.boss_wave, "每章章末精英波")
		assert_true(chapter.boss_wave.is_elite_wave)

func _make_wave(seed_value: int, count_range: Vector2i) -> WaveData:
	var w := WaveData.new()
	w.seed = seed_value
	w.directions = [0]
	w.count_range = count_range
	w.enemy_location = "bulwark:enemy/runner"
	w.warn_duration = 0.5
	w.spawn_interval = 0.05
	w.burst_chance = 0.0
	return w

func _run_to_end(director: WaveDirector, max_ticks: int) -> void:
	var guard := 0
	while director.phase != WaveDirector.Phase.VICTORY and guard < max_ticks:
		director.tick(0.1)
		if director.phase == WaveDirector.Phase.ACTIVE:
			while director.pending_spawns > 0:
				director.register_enemy_spawned()
			while director.alive_enemies > 0:
				director.register_enemy_died()
		guard += 1

func test_chapter_state_machine_completes_victory() -> void:
	var run: RunDefinition = load("res://resources/runs/arcade_run.tres")
	var director := WaveDirector.new()
	director.start_run(run)
	assert_not_null(director.run_definition, "run_definition 已注入")
	assert_eq(director.waves.size(), 16)
	_run_to_end(director, 4000)
	assert_true(_victory, "16 波打完胜利")
	assert_eq(director.current_wave_index, 16)
	# 校验章信息：章首波 chapter_index 递增、每章第 4 波是精英
	# warnings 平铺 16 条；flat 索引 3/7/11/15 为各章章末精英
	assert_eq(_warnings.size(), 16)
	assert_eq(_warnings[0].chapter_index, 0)
	assert_eq(_warnings[3].is_boss_wave, true, "第 1 章章末精英")
	assert_eq(_warnings[7].is_boss_wave, true, "第 2 章章末精英")
	assert_eq(_warnings[8].chapter_index, 2, "flat 索引 8 属于第 3 章")
	assert_eq(_warnings[11].is_boss_wave, true, "第 3 章章末精英")
	assert_eq(_warnings[15].is_boss_wave, true, "第 4 章章末精英")

func test_legacy_start_keeps_chapter_defaults() -> void:
	var director := WaveDirector.new()
	director.start([_make_wave(1, Vector2i(2, 2))])
	assert_eq(director.run_definition, null)
	assert_eq(director.current_chapter_index, -1)
	assert_eq(_warnings.size(), 1)
	assert_eq(_warnings[0].chapter_index, -1, "legacy 无章节信息")

func test_same_screen_cap_limits_alive() -> void:
	var director := WaveDirector.new()
	var max_alive := 0
	EventBus.subscribe(&"SpawnRequestEvent",
		func(e: SpawnRequestEvent) -> void:
			for i in e.count:
				director.register_enemy_spawned()
			max_alive = maxi(max_alive, director.alive_enemies))
	var wave := _make_wave(7, Vector2i(50, 50))
	wave.spawn_interval = 0.01
	director.start([wave])
	var guard := 0
	while director.pending_spawns > 0 and guard < 4000:
		director.tick(0.1)
		guard += 1
	assert_true(max_alive <= WaveDirector.MAX_ON_SCREEN, "同屏敌人数不超过上限")
