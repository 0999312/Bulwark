class_name WaveComposition
extends RefCounted
## 波次构成：一组刷怪单元（方位 + 数量 + 敌人），由 WaveGenerator 种子 PCG 生成

## 刷怪单元
class SpawnGroup:
	var direction: int = WaveData.Direction.N
	var count: int = 0
	var enemy_location: String = ""

	func _init(p_direction: int, p_count: int, p_enemy_location: String) -> void:
		direction = p_direction
		count = p_count
		enemy_location = p_enemy_location

var groups: Array[SpawnGroup] = []

## 方位数量级阈值（M2，HUD 分级：count >= 该值 = 大量，否则少量）
## 对齐 wave 数据分布：W1~3 单方向 6~11 → 大量；W4+ 快/硬壳 2~5 → 少量
const HEAVY_THRESHOLD := 6

func add_group(direction: int, count: int, enemy_location: String) -> void:
	groups.append(SpawnGroup.new(direction, count, enemy_location))

## 总敌人数
func total_count() -> int:
	var total := 0
	for g in groups:
		total += g.count
	return total

## 紧凑文本摘要（HUD 预告/日志用），如 "N×4 E×6"
func summarize() -> String:
	var parts: Array[String] = []
	for g in groups:
		parts.append("%s×%d" % [WaveData.Direction.keys()[g.direction], g.count])
	return ", ".join(parts)

## 方位数量级分级（M2，HUD 简化显示：只报大量/少量，不再逐方向罗列数量）
## 按方向聚合（同方向多组取最大 count 定级），返回 {"heavy": [dir...], "light": [dir...]}
func summarize_tiers(threshold: int = HEAVY_THRESHOLD) -> Dictionary:
	var per_dir: Dictionary = {}  # dir(int) -> max_count
	for g in groups:
		per_dir[g.direction] = maxi(per_dir.get(g.direction, 0), g.count)
	var tiers := {"heavy": [], "light": []}
	for dir: int in per_dir.keys():
		var target: Array = tiers["heavy"] if per_dir[dir] >= threshold else tiers["light"]
		target.append(dir)
	(tiers["heavy"] as Array).sort()
	(tiers["light"] as Array).sort()
	return tiers
