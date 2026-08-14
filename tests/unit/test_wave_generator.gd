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
