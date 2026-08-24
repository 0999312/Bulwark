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

func get_wave_progress() -> String:
	return "%d/%d" % [current_wave_index + 1, waves.size()]

# ─── 内部流程 ───

func _begin_next_wave() -> void:
	if phase == Phase.VICTORY:
		return
	current_wave_index += 1
	if current_wave_index >= waves.size():
		phase = Phase.VICTORY
		EventBus.publish(RunVictoryEvent.new())
		return

	var wave_data := waves[current_wave_index]
	# 每波独立种子（WaveData.seed），确定性可复现
	_rng.set_seed(wave_data.seed)
	var composition := WaveGenerator.generate(wave_data, _rng)

	phase = Phase.WARNING
	_timer = wave_data.warn_duration
	EventBus.publish(WaveWarningEvent.new(current_wave_index + 1, waves.size(), composition,
		composition.summarize_tiers(), composition.threat_tier(), composition.has_elite()))
	# 预警构成暂存，ACTIVE 时发出刷怪请求
	_pending_composition = composition

var _pending_composition: WaveComposition

func _activate_wave() -> void:
	phase = Phase.ACTIVE
	EventBus.publish(WaveStartedEvent.new(current_wave_index + 1, waves.size()))
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
		EventBus.publish(WaveClearedEvent.new(current_wave_index + 1))
