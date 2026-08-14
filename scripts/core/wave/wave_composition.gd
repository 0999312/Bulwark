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
