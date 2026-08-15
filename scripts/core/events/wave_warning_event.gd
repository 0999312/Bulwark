class_name WaveWarningEvent
extends Event
## 波次预警（HUD 波次预告：方位数量级 + 构成）
## direction_tiers（M2）：{"heavy": [dir...], "light": [dir...]}，由 WaveDirector 按
## WaveComposition.summarize_tiers() 填充；空 = 旧逻辑回退（逐方向罗列）

var wave_index: int          # 1-based
var wave_total: int
var composition: WaveComposition
var direction_tiers: Dictionary = {}

func _init(p_wave_index: int, p_wave_total: int, p_composition: WaveComposition,
		p_direction_tiers: Dictionary = {}) -> void:
	wave_index = p_wave_index
	wave_total = p_wave_total
	composition = p_composition
	direction_tiers = p_direction_tiers
