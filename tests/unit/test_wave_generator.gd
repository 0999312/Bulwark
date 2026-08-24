extends GutTest
## 波次构成生成测试（架构 §4.6）：种子 PCG 确定性 + 方位/数量边界

func _make_wave(seed_value: int, directions: Array[int], count_range: Vector2i) -> WaveData:
	var wave := WaveData.new()
	wave.seed = seed_value
	wave.directions = directions
	wave.count_range = count_range
	wave.enemy_location = "bulwark:enemy/runner"
	wave.warn_duration = 2.0
	return wave

func test_same_seed_same_composition() -> void:
	var wave := _make_wave(20250101, [0, 2, 4, 6], Vector2i(3, 8))
	var a := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	var b := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(a.groups.size(), b.groups.size(), "同种子构成组数一致")
	for i in a.groups.size():
		assert_eq(a.groups[i].direction, b.groups[i].direction)
		assert_eq(a.groups[i].count, b.groups[i].count)
		assert_eq(a.groups[i].enemy_location, b.groups[i].enemy_location)

func test_different_seed_different_counts() -> void:
	# 宽区间下不同种子几乎必然产生不同数量（构造性断言）
	var wave := _make_wave(1, [0, 2, 4, 6], Vector2i(1, 200))
	var a := WaveGenerator.generate(wave, SeededRNG.new(1))
	var b := WaveGenerator.generate(wave, SeededRNG.new(2))
	var differs := false
	for i in a.groups.size():
		if a.groups[i].count != b.groups[i].count:
			differs = true
	assert_true(differs, "不同种子应产生不同构成（宽区间下）")

func test_counts_within_range_and_directions_respected() -> void:
	var wave := _make_wave(777, [0, 2, 6], Vector2i(4, 6))
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(comp.groups.size(), 3)
	for group: WaveComposition.SpawnGroup in comp.groups:
		assert_true(wave.directions.has(group.direction), "方位必须来自模板方位集")
		assert_gte(group.count, 4)
		assert_lte(group.count, 6)
		assert_eq(group.enemy_location, "bulwark:enemy/runner")

func test_single_direction_wave() -> void:
	var wave := _make_wave(11, [2], Vector2i(5, 5))
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(comp.groups.size(), 1)
	assert_eq(comp.groups[0].direction, WaveData.Direction.E)
	assert_eq(comp.groups[0].count, 5)
	assert_eq(comp.total_count(), 5)

func test_player_count_scale_placeholder_is_one() -> void:
	# 强度不缩放（单人多同时设计，人数系数留位，M0 固定 1）
	var wave := _make_wave(5, [0], Vector2i(4, 4))
	wave.player_count_scale = 1.0
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(comp.groups[0].count, 4)

func test_summarize_format() -> void:
	var wave := _make_wave(9, [0, 2], Vector2i(3, 3))
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_string_contains(comp.summarize(), "N×3")
	assert_string_contains(comp.summarize(), "E×3")

# ─── M1：多敌人组构成（奔跑者变种混合） ───

func _make_group(directions: Array[int], count_range: Vector2i, enemy_location: String) -> WaveSpawnGroupData:
	var group := WaveSpawnGroupData.new()
	group.directions = directions
	group.count_range = count_range
	group.enemy_location = enemy_location
	return group

func test_multi_group_composition_mixes_enemies() -> void:
	var wave := WaveData.new()
	wave.seed = 404
	wave.groups = [
		_make_group([0, 2], Vector2i(6, 8), "bulwark:enemy/runner"),
		_make_group([4, 6], Vector2i(3, 5), "bulwark:enemy/runner_fast"),
	]
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(comp.groups.size(), 4, "2 组 × 2 方位 = 4 个刷怪组")
	var fast_count := 0
	for group: WaveComposition.SpawnGroup in comp.groups:
		if group.enemy_location == "bulwark:enemy/runner_fast":
			fast_count += group.count
	assert_gt(fast_count, 0, "疾行者组应出怪")
	assert_gt(comp.total_count(), fast_count, "总数含奔跑者组")

func test_multi_group_deterministic_same_seed() -> void:
	var wave := WaveData.new()
	wave.seed = 505
	wave.groups = [
		_make_group([0], Vector2i(2, 4), "bulwark:enemy/runner"),
		_make_group([2], Vector2i(1, 3), "bulwark:enemy/runner_tough"),
	]
	var a := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	var b := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(a.total_count(), b.total_count(), "同种子多组总数一致")

func test_legacy_single_group_fallback() -> void:
	# groups 为空 → 回退单组简写字段（M0 数据不迁移）
	var wave := _make_wave(9, [0, 2], Vector2i(3, 3))
	assert_eq(wave.get_spawn_groups().size(), 1)
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(comp.groups.size(), 2)
	for group: WaveComposition.SpawnGroup in comp.groups:
		assert_eq(group.enemy_location, "bulwark:enemy/runner")

func test_group_count_scale() -> void:
	var wave := WaveData.new()
	wave.seed = 606
	var group := _make_group([0], Vector2i(4, 4), "bulwark:enemy/runner")
	group.count_scale = 1.5
	wave.groups = [group]
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_eq(comp.groups[0].count, 6, "组内数量 ×1.5")

# ─── M5a：精英波标记透传 ───

func test_elite_wave_flag_propagates_to_composition() -> void:
	var wave := WaveData.new()
	wave.seed = 606
	wave.is_elite_wave = true
	wave.groups = [_make_group([0], Vector2i(1, 1), "bulwark:enemy/elite_behemoth")]
	var comp := WaveGenerator.generate(wave, SeededRNG.new(wave.seed))
	assert_true(comp.is_elite_wave, "WaveData.is_elite_wave 应透传到 WaveComposition")
	assert_true(comp.has_elite(), "精英波构成可识别")

# ─── M5e：难度曲线表 ───

func test_difficulty_curve_table() -> void:
	assert_eq(DifficultyCurve.get_wave_count(), 6, "6 波单链")
	assert_eq(DifficultyCurve.get_wave_scale(1), 1.0, "第 1 波基准")
	assert_gt(DifficultyCurve.get_wave_scale(6), DifficultyCurve.get_wave_scale(1), "后期波次强度更高")
	assert_eq(DifficultyCurve.get_wave_scale(0), 1.0, "越界回退 1.0")
	assert_eq(DifficultyCurve.get_wave_scale(99), 1.0, "越界回退 1.0")
