extends GutTest
## 波次调度流程测试：预警 → 流式刷怪（随机方位 + 偶发群刷）→ 清场 → 3 波 → 胜利结算
## 注：GDScript lambda 按值捕获局部标量，累积状态用成员变量（按引用捕获）
## 流式刷怪（M0 修订）：ACTIVE 阶段按 spawn_interval 出怪，方位随机、burst_chance 概率群刷

var _victory := false
var _requested_total := 0
var _cleared: Array[int] = []
var _warnings: Array[int] = []
var _requests: Array[SpawnRequestEvent] = []

func before_each() -> void:
	_victory = false
	_requested_total = 0
	_cleared.clear()
	_warnings.clear()
	_requests.clear()
	# 清理跨测试累积的事件订阅（GUT 复用同一测试实例，lambda 每次新建不会去重）
	EventBus.clear_all_listeners()

func _make_wave(seed_value: int, directions: Array[int], count_range: Vector2i) -> WaveData:
	var wave := WaveData.new()
	wave.seed = seed_value
	wave.directions = directions
	wave.count_range = count_range
	wave.enemy_location = "bulwark:enemy/runner"
	wave.warn_duration = 1.0
	wave.spawn_interval = 0.1
	wave.burst_chance = 0.0
	return wave

func _run_to_victory(director: WaveDirector, max_ticks: int) -> void:
	var guard := 0
	while director.phase != WaveDirector.Phase.VICTORY and guard < max_ticks:
		director.tick(0.1)
		if director.phase == WaveDirector.Phase.ACTIVE:
			# 模拟表现层：刷完全部请求 → 敌人全部阵亡
			while director.pending_spawns > 0:
				director.register_enemy_spawned()
			while director.alive_enemies > 0:
				director.register_enemy_died()
		guard += 1

func test_full_three_wave_run_ends_in_victory() -> void:
	var director := WaveDirector.new()
	EventBus.subscribe(&"RunVictoryEvent", func(_e: Event) -> void: _victory = true)
	EventBus.subscribe(&"SpawnRequestEvent", func(e: SpawnRequestEvent) -> void: _requested_total += e.count)

	director.start([
		_make_wave(1, [0], Vector2i(2, 2)),
		_make_wave(2, [2], Vector2i(2, 2)),
		_make_wave(3, [4], Vector2i(2, 2)),
	])
	assert_eq(director.phase, WaveDirector.Phase.WARNING, "启动即进入第 1 波预警")

	_run_to_victory(director, 900)

	assert_eq(director.phase, WaveDirector.Phase.VICTORY, "3 波打完进入胜利")
	assert_true(_victory, "胜利事件已广播")
	assert_eq(_requested_total, 6, "3 波 × 每波 2 只（流式逐只发布）")
	assert_eq(director.current_wave_index, 3, "波次索引推进到 3（1-based 第 3 波结束）")

func test_wave_cleared_events_sequence() -> void:
	var director := WaveDirector.new()
	EventBus.subscribe(&"WaveClearedEvent", func(e: WaveClearedEvent) -> void: _cleared.append(e.wave_index))
	EventBus.subscribe(&"WaveWarningEvent", func(e: WaveWarningEvent) -> void: _warnings.append(e.wave_index))

	director.start([_make_wave(1, [0], Vector2i(2, 2))])
	_run_to_victory(director, 400)

	assert_eq(_warnings, [1], "第 1 波预警一次")
	assert_eq(_cleared, [1], "第 1 波清场一次")

func test_streaming_spawn_random_direction_over_time() -> void:
	# 流式刷怪：预警期间不出怪；ACTIVE 后按间隔出怪；方位随机但合法
	var director := WaveDirector.new()
	EventBus.subscribe(&"SpawnRequestEvent",
		func(e: SpawnRequestEvent) -> void: _requests.append(e))

	var wave := _make_wave(7, [0, 2], Vector2i(2, 2))
	wave.spawn_interval = 0.5
	director.start([wave])

	director.tick(0.9)
	assert_eq(_requests.size(), 0, "预警期间不刷怪")
	director.tick(0.1)  # 预警结束 → ACTIVE（激活帧不发布）
	assert_eq(_requests.size(), 0, "激活帧不发布")
	director.tick(0.1)  # 第一只立即（spawn_timer 从 0 起）
	assert_eq(_requests.size(), 1, "第一只立即刷出")
	assert_true(wave.directions.has(_requests[0].direction), "方位来自波次配置")
	assert_eq(_requests[0].count, 1, "常规出怪单只")
	director.tick(0.4)
	assert_eq(_requests.size(), 1, "间隔内不再刷")
	director.tick(0.2)  # 累计 0.6s ≥ 0.5s 间隔 → 第二只
	assert_eq(_requests.size(), 2, "间隔到刷第二只")
	assert_true(wave.directions.has(_requests[1].direction), "方位随机但合法")

func test_spawn_requests_carry_composition() -> void:
	var director := WaveDirector.new()
	EventBus.subscribe(&"SpawnRequestEvent",
		func(e: SpawnRequestEvent) -> void: _requests.append(e))

	var wave := _make_wave(42, [0, 2, 6], Vector2i(3, 3))
	director.start([wave])
	for i in 30:
		director.tick(0.1)  # 预警 1.0 + 9 只 × 0.1s 全部刷出

	assert_eq(_requests.size(), 9, "3 方位 × 3 只逐只发布")
	var per_dir := {0: 0, 2: 0, 6: 0}
	for req in _requests:
		assert_eq(req.count, 1, "每次只刷一只")
		assert_eq(req.enemy_location, "bulwark:enemy/runner")
		assert_true(wave.directions.has(req.direction), "方位合法")
		per_dir[req.direction] += 1
	assert_eq(per_dir[0], 3, "北方向恰好 3 只（总数守恒）")
	assert_eq(per_dir[2], 3, "东方向恰好 3 只")
	assert_eq(per_dir[6], 3, "西方向恰好 3 只")
	assert_eq(director.pending_spawns, 9)

func test_burst_spawn_emits_group() -> void:
	# burst_chance=1.0：每次出怪都刷一小群（Clash N Slash 式偶发怪群）
	var director := WaveDirector.new()
	EventBus.subscribe(&"SpawnRequestEvent",
		func(e: SpawnRequestEvent) -> void: _requests.append(e))

	var wave := _make_wave(7, [0], Vector2i(6, 6))
	wave.burst_chance = 1.0
	wave.burst_size = 3
	director.start([wave])
	for i in 30:
		director.tick(0.1)

	assert_eq(_requests.size(), 2, "6 只 ÷ 每群 3 只 = 2 次出怪")
	assert_eq(_requests[0].count, 3, "第一次出怪为 3 只群")
	assert_eq(_requests[1].count, 3, "第二次出怪为 3 只群")
	assert_eq(director.pending_spawns, 6)

func test_burst_capped_by_remaining() -> void:
	# 群刷不超过剩余数量（剩 2 只时按 2 只出）
	var director := WaveDirector.new()
	EventBus.subscribe(&"SpawnRequestEvent",
		func(e: SpawnRequestEvent) -> void: _requests.append(e))

	var wave := _make_wave(7, [0], Vector2i(2, 2))
	wave.burst_chance = 1.0
	wave.burst_size = 3
	director.start([wave])
	for i in 20:
		director.tick(0.1)

	assert_eq(_requests.size(), 1, "2 只不足一群 → 一次出完")
	assert_eq(_requests[0].count, 2, "群刷被剩余数量截断")
	assert_eq(director.pending_spawns, 2)

func test_pending_bookkeeping_with_synchronous_spawn() -> void:
	# 回归：发布前必须先记账（EventBus 同步分发，表现层立即 register_enemy_spawned）
	var director := WaveDirector.new()
	EventBus.subscribe(&"SpawnRequestEvent",
		func(e: SpawnRequestEvent) -> void:
			for i in e.count:
				director.register_enemy_spawned())
	var wave := _make_wave(9, [0, 2], Vector2i(4, 4))
	director.start([wave])
	for i in 30:
		director.tick(0.1)
	assert_eq(director.pending_spawns, 0, "同步刷怪后 pending 归零")
	assert_eq(director.alive_enemies, 8, "两方位 × 4 只全部登记")
	# 击杀清场 → 波间（刷怪池已空）
	while director.alive_enemies > 0:
		director.register_enemy_died()
	assert_eq(director.phase, WaveDirector.Phase.INTERMISSION)

func test_wave_not_cleared_while_pool_has_spawns() -> void:
	# 流式刷怪下：刷怪池未空时即使场上无敌也不得提前清场
	var director := WaveDirector.new()
	EventBus.subscribe(&"SpawnRequestEvent",
		func(e: SpawnRequestEvent) -> void:
			for i in e.count:
				director.register_enemy_spawned())
	var wave := _make_wave(9, [0], Vector2i(4, 4))
	wave.spawn_interval = 1.0
	director.start([wave])
	director.tick(1.0)  # 预警结束
	director.tick(0.1)  # 第一只刷出并被登记
	assert_eq(director.alive_enemies, 1)
	# 击杀场上唯一敌人：刷怪池还有 3 只待刷，不得清场
	while director.alive_enemies > 0:
		director.register_enemy_died()
	assert_eq(director.phase, WaveDirector.Phase.ACTIVE, "刷怪池未空不得提前清场")
