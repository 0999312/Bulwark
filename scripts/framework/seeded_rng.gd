class_name SeededRNG
extends RefCounted
## 种子随机数发生器（波次生成确定性）
## 同种子 → 同序列（GUT 断言可复现）；供 WaveDirector 生成「方位 + 数量」构成。
## 参考架构文档 §4.6：种子 PCG（构造法），利于测试与平衡调参。

var seed_value: int:
	get:
		return _rng.seed

var _rng := RandomNumberGenerator.new()

func _init(p_seed: int = 0) -> void:
	_rng.seed = p_seed

## 设置种子（重新置位）
func set_seed(p_seed: int) -> void:
	_rng.seed = p_seed

## [from, to] 闭区间随机整数
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

## 随机布尔
func chance(probability: float) -> bool:
	return _rng.randf() < probability

## 从数组中随机取一项（浅拷贝返回；数组为空返回 null）
func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[_rng.randi_range(0, arr.size() - 1)]

## Fisher-Yates 洗牌（原地，返回自身便于链式调用）
func shuffle(arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr

## 按权重随机索引（weights 为正数数组；返回 -1 表示全零/空）
func weighted_index(weights: Array[float]) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if roll < acc:
			return i
	return weights.size() - 1
