class_name WaveDirector
extends RefCounted
## 波次调度（后端，纯逻辑；架构 §4.6）
## 流程：预警 → 刷怪 → 清场 → 下一波 → 3 波后胜利结算（M0 固定 3 波模板）
## - 构成生成：WaveGenerator（种子 PCG，同种子可复现）
## - 刷怪请求：SpawnRequestEvent → 表现层实例化敌人；register_enemy_spawned/died 簿记
## - 强度：不缩放（人数系数留位，M0 固定 1）
## - AI Director 动态调压预留：接口位置见 _begin_wave（当前固定曲线）

enum Phase {
	IDLE = 0,
	WARNING = 1,     # 预警（广播构成）
	ACTIVE = 2,      # 刷怪/接敌
	INTERMISSION = 3,# 波间窗口（M0 短计时；商店/搜索为 M1+）
	VICTORY = 4,     # 全部波次击退
}

const WAVE_INTERMISSION_DURATION := 5.0

## M1 波间商店：置 true 时 INTERMISSION 不自动计时，等待装配层 resume_from_intermission()
## （商店关闭后调用）；默认 false 保持 M0 自动计时（测试兼容）
var intermission_waits_for_shop := false

## P0-7：本局随机种子偏移（run_seed 注入；默认 0 保持 WaveData.seed 原样 → 既有测试确定性）
var run_seed_offset: int = 0

## P1-8：章节制运行定义（null = 遗留 flat 波次，测试兼容）
var run_definition: RunDefinition = null
## P2-17：无尽轮次（4 章循环；永不判胜；每循环难度 ×1.15）
var infinite_loop := false
var cycle_index := 0
var difficulty_cycle_scale := 1.0
## 单波同屏上限（建议 ≤40）：超限暂停刷出，保低端机不掉帧
const MAX_ON_SCREEN := 40
const ENDLESS_CYCLE_SCALE := 1.15
var current_chapter_index: int = -1
var current_wave_in_chapter: int = -1
var current_is_boss_wave: bool = false

var waves: Array[WaveData] = []
var phase: Phase = Phase.IDLE
var current_wave_index: int = -1

## 簿记：待刷怪数 / 存活敌人数（register_enemy_spawned/died 由表现层回报）
var pending_spawns: int = 0
var alive_enemies: int = 0

var _timer: float = 0.0
var _rng := SeededRNG.new()
var _started := false
## 流式刷怪状态：ACTIVE 阶段按 spawn_interval 出怪（随机方位、偶发群刷）
var _spawn_remaining: Dictionary = {}   # direction(int) -> 剩余只数
var _spawn_location: Dictionary = {}    # direction(int) -> enemy_location(String)
var _spawn_timer: float = 0.0

## 启动（waves 按顺序；M0 = WaveRegistry 的 bulwark:wave/1..3）
func start(waves_list: Array[WaveData]) -> void:
	if _started:
		return
	waves = waves_list
	_started = true
	_begin_next_wave()

## P1-8：章节制启动（RunDefinition → 扁平波次流：每章 waves + boss_wave）
func start_run(run: RunDefinition) -> void:
	if _started:
		return
	run_definition = run
	var flat: Array[WaveData] = []
	if run != null:
		for chapter: ChapterDefinition in run.chapters:
			for wave: WaveData in chapter.waves:
				flat.append(wave)
			if chapter.boss_wave != null:
				flat.append(chapter.boss_wave)
	if flat.is_empty():
		push_error("WaveDirector.start_run: RunDefinition 无章节/波次")
		_started = true
		phase = Phase.VICTORY
		EventBus.publish(RunVictoryEvent.new())
		return
	waves = flat
	_started = true
	_begin_next_wave()

## 由扁平索引推导章节/章内波次（0-based；flat 序列 = [ch.waves..., boss, ...]）
func _chapter_info_for_flat(flat_index: int) -> Dictionary:
	if run_definition == null or flat_index < 0:
		return {"chapter": -1, "wave_in_chapter": -1, "is_boss": false}
	var remaining := flat_index
	for ci in run_definition.chapters.size():
		var chapter: ChapterDefinition = run_definition.chapters[ci]
		var chapter_total := chapter.waves.size() + 1
		if remaining < chapter_total:
			return {
				"chapter": ci,
				"wave_in_chapter": remaining,
				"is_boss": remaining == chapter.waves.size(),
			}
		remaining -= chapter_total
	return {"chapter": run_definition.chapters.size() - 1,
		"wave_in_chapter": -1, "is_boss": false}

## 章名回退（中文数据字段；UI 显示走 UiText.content_name）
func _chapter_name(ci: int) -> String:
	if run_definition == null or ci < 0 or ci >= run_definition.chapters.size():
		return ""
	return run_definition.chapters[ci].display_name

## 每帧驱动（预警计时 / 流式刷怪 / 波间计时；AI Director 动态调压预留在此扩展）
func tick(delta: float) -> void:
	if not _started:
		return
	match phase:
		Phase.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				_activate_wave()
		Phase.ACTIVE:
			if not _is_spawn_pool_empty():
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					_spawn_next()
		Phase.INTERMISSION:
			if intermission_waits_for_shop:
				return  # 等待商店关闭（GameSession 调 resume_from_intermission）
			_timer -= delta
			if _timer <= 0.0:
				_begin_next_wave()
		_:
			pass

# ─── 表现层回报 ───

## 表现层每实例化一个敌人调用一次
func register_enemy_spawned() -> void:
	alive_enemies += 1
	if pending_spawns > 0:
		pending_spawns -= 1
	_check_wave_cleared()

## 表现层在敌人死亡/移除时调用
func register_enemy_died() -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	_check_wave_cleared()

## 波间商店关闭 → 继续下一波（intermission_waits_for_shop 时由装配层调用）
func resume_from_intermission() -> void:
	if phase != Phase.INTERMISSION:
		return
	_begin_next_wave()

## P0-7：注入本局随机种子（波次构成差异化；同类刷新/生成共用偏移）
func set_run_seed(seed: int) -> void:
	run_seed_offset = seed

func get_run_seed_offset() -> int:
	return run_seed_offset

func get_wave_progress() -> String:
	return "%d/%d" % [current_wave_index + 1, waves.size()]

# ─── 内部流程 ───

func _begin_next_wave() -> void:
	if phase == Phase.VICTORY:
		return
	current_wave_index += 1
	if current_wave_index >= waves.size():
		if infinite_loop:
			# P2-17 无尽：回到第 1 波继续；难度与种子随循环上抬
			current_wave_index = 0
			cycle_index += 1
			difficulty_cycle_scale *= ENDLESS_CYCLE_SCALE
		else:
			phase = Phase.VICTORY
			EventBus.publish(RunVictoryEvent.new())
			return

	var wave_data := waves[current_wave_index]
	# P1-8：章节信息（legacy 下 chapter=-1 保持向后兼容）
	var chapter_info := _chapter_info_for_flat(current_wave_index)
	current_chapter_index = int(chapter_info.get("chapter", -1))
	current_wave_in_chapter = int(chapter_info.get("wave_in_chapter", -1))
	current_is_boss_wave = bool(chapter_info.get("is_boss", false))
	# 难度：chapter_scale × DifficultyCurve.wave_scale（P1-8；legacy 只乘 wave_scale）
	var wave_scale := DifficultyCurve.get_wave_scale(current_wave_in_chapter + 1)
	if run_definition != null and current_chapter_index >= 0:
		wave_scale *= run_definition.chapters[current_chapter_index].chapter_scale
	if infinite_loop:
		wave_scale *= difficulty_cycle_scale
	# 每波独立种子（WaveData.seed + 本局运行偏移 + 循环偏差），确定性可复现
	_rng.set_seed(wave_data.seed + run_seed_offset + cycle_index * 1000)
	var composition := WaveGenerator.generate(wave_data, _rng, wave_scale)

	phase = Phase.WARNING
	_timer = wave_data.warn_duration
	EventBus.publish(WaveWarningEvent.new(current_wave_index + 1, waves.size(), composition,
		composition.summarize_tiers(), composition.threat_tier(), composition.has_elite(),
		current_chapter_index, _chapter_name(current_chapter_index),
		current_wave_in_chapter, current_is_boss_wave, cycle_index))
	# 预警构成暂存，ACTIVE 时发出刷怪请求
	_pending_composition = composition

var _pending_composition: WaveComposition

func _activate_wave() -> void:
	phase = Phase.ACTIVE
	EventBus.publish(WaveStartedEvent.new(
		current_wave_index + 1, waves.size(), current_chapter_index,
		current_is_boss_wave, cycle_index))
	var composition := _pending_composition
	_pending_composition = null
	if composition == null:
		return
	_init_spawn_pool(composition)
	# 第一只立即刷（不给双倍间隔的真空期）
	_spawn_timer = 0.0

## 初始化流式刷怪池：每个方位一个剩余计数（刷怪顺序交给 _spawn_next 随机决定）
func _init_spawn_pool(composition: WaveComposition) -> void:
	_spawn_remaining.clear()
	_spawn_location.clear()
	for group: WaveComposition.SpawnGroup in composition.groups:
		_spawn_remaining[group.direction] = group.count
		_spawn_location[group.direction] = group.enemy_location

func _is_spawn_pool_empty() -> bool:
	for remaining in _spawn_remaining.values():
		if remaining > 0:
			return false
	return true

## 从刷怪池随机方位出怪（先记账再发布：EventBus 同步分发，表现层会立即 register_enemy_spawned）
## - 随机短间隔：每 spawn_interval 从尚有剩余的方位中随机挑一个
## - 偶发集中怪群：burst_chance 概率一次刷 burst_size 只同方位（Clash N Slash 式节奏）
func _spawn_next() -> void:
	var wave := waves[current_wave_index]
	# 收集尚有剩余的方位
	var available: Array[int] = []
	for dir in _spawn_remaining.keys():
		if _spawn_remaining[dir] > 0:
			available.append(dir)
	if available.is_empty():
		return
	var direction: int = available[_rng.randi_range(0, available.size() - 1)]
	var count := 1
	if wave.burst_chance > 0.0 and _rng.randf() < wave.burst_chance:
		count = maxi(2, wave.burst_size)
	count = mini(count, _spawn_remaining[direction])
	# P1-8 同屏上限：超限暂停刷出（短间隔重试，不丢刷怪池）
	var capacity := MAX_ON_SCREEN - (alive_enemies + pending_spawns)
	if capacity <= 0:
		_spawn_timer = minf(wave.spawn_interval, 0.25)
		return
	count = mini(count, capacity)
	if count <= 0:
		return
	_spawn_remaining[direction] -= count
	pending_spawns += count
	EventBus.publish(SpawnRequestEvent.new(
		direction, count, _spawn_location[direction]))
	_spawn_timer = wave.spawn_interval

func _check_wave_cleared() -> void:
	if phase != Phase.ACTIVE:
		return
	# 刷怪池空 + 无待刷 + 无存活 → 清场（流式刷怪下池未空时波次不结束）
	if _is_spawn_pool_empty() and pending_spawns <= 0 and alive_enemies <= 0:
		phase = Phase.INTERMISSION
		_timer = WAVE_INTERMISSION_DURATION
		EventBus.publish(WaveClearedEvent.new(
			current_wave_index + 1, current_chapter_index, current_is_boss_wave))
