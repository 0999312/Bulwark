extends GutTest
## SeededRNG 测试：种子确定性（波次 PCG 可复现的基础）

func test_same_seed_same_sequence() -> void:
	var a := SeededRNG.new(42)
	var b := SeededRNG.new(42)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for i in 50:
		seq_a.append(a.randi_range(1, 100))
		seq_b.append(b.randi_range(1, 100))
	assert_eq(seq_a, seq_b, "同种子必须产生完全相同的序列")

func test_different_seed_produces_different_sequence() -> void:
	var a := SeededRNG.new(1)
	var b := SeededRNG.new(2)
	var same := 0
	for i in 20:
		if a.randi_range(0, 999999) == b.randi_range(0, 999999):
			same += 1
	assert_lt(same, 20, "不同种子序列应不同（碰撞概率可忽略）")

func test_set_seed_resets_sequence() -> void:
	var rng := SeededRNG.new(42)
	var first := rng.randi_range(1, 1000000)
	rng.set_seed(42)
	assert_eq(rng.randi_range(1, 1000000), first, "重新置位后序列从头开始")

func test_shuffle_deterministic_and_permutes() -> void:
	var a := SeededRNG.new(7)
	var b := SeededRNG.new(7)
	var arr_a := a.shuffle([1, 2, 3, 4, 5, 6, 7, 8])
	var arr_b := b.shuffle([1, 2, 3, 4, 5, 6, 7, 8])
	assert_eq(arr_a, arr_b)
	assert_eq(arr_a.size(), 8)
	assert_eq(arr_a.reduce(func(acc: int, v: int) -> int: return acc + v, 0), 36, "洗牌不丢元素")

func test_pick_and_weighted_index() -> void:
	var rng := SeededRNG.new(3)
	var arr := [10, 20, 30]
	for i in 10:
		assert_true(arr.has(rng.pick(arr)))
	assert_eq(rng.weighted_index([0.0, 0.0]), -1)
	var idx := rng.weighted_index([1.0, 0.0])
	assert_eq(idx, 0)
