class_name WaveGenerator
extends RefCounted
## 波次构成生成器（种子 PCG，构造法；架构 §4.6）
## 输入：WaveData（种子 + 方位集 + 数量区间 + 敌人）→ 输出 WaveComposition
## 同种子 → 同构成（GUT 断言可复现）；人数系数留位（M0 固定 1.0）

## 生成构成；rng 由调用方持有（保证跨调用确定性链），也可直接传种子
## M1：WaveData.groups（多敌人组，奔跑者变种混合）；groups 为空回退单组简写
## P1-8：count_scale = 难度缩放（chapter_scale × wave_scale），默认 1.0 保持既有调用/测试
static func generate(wave_data: WaveData, rng: SeededRNG,
		count_scale: float = 1.0) -> WaveComposition:
	var composition := WaveComposition.new()
	composition.is_elite_wave = wave_data.is_elite_wave
	for group: WaveSpawnGroupData in wave_data.get_spawn_groups():
		for direction: int in group.directions:
			var count := rng.randi_range(group.count_range.x, group.count_range.y)
			count = _apply_player_count_scale(count, wave_data.player_count_scale * group.count_scale)
			count = _apply_difficulty_scale(count, count_scale)
			composition.add_group(direction, count, group.enemy_location)
	return composition

## 难度缩放（P1-8）：roundi 后至少 1 只（避免压力峰值波被难度 0 清空）
static func _apply_difficulty_scale(count: int, scale: float) -> int:
	if scale <= 0.0:
		return count
	return maxi(1, roundi(count * scale))

## 人数缩放（架构 §4.6：1人=1.0；M0 固定 1.0，多人系数 M2+ 调参）
static func _apply_player_count_scale(count: int, scale: float) -> int:
	if scale <= 0.0:
		return count
	return maxi(1, roundi(count * scale))
