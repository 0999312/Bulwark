class_name WaveGenerator
extends RefCounted
## 波次构成生成器（种子 PCG，构造法；架构 §4.6）
## 输入：WaveData（种子 + 方位集 + 数量区间 + 敌人）→ 输出 WaveComposition
## 同种子 → 同构成（GUT 断言可复现）；人数系数留位（M0 固定 1.0）

## 生成构成；rng 由调用方持有（保证跨调用确定性链），也可直接传种子
static func generate(wave_data: WaveData, rng: SeededRNG) -> WaveComposition:
	var composition := WaveComposition.new()
	for direction: int in wave_data.directions:
		var count := rng.randi_range(wave_data.count_range.x, wave_data.count_range.y)
		count = _apply_player_count_scale(count, wave_data.player_count_scale)
		composition.add_group(direction, count, wave_data.enemy_location)
	return composition

## 人数缩放（架构 §4.6：1人=1.0；M0 固定 1.0，多人系数 M2+ 调参）
static func _apply_player_count_scale(count: int, scale: float) -> int:
	if scale <= 0.0:
		return count
	return maxi(1, roundi(count * scale))
