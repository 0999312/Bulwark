class_name WaveWarningEvent
extends Event
## 波次预警（HUD 波次预告：方位罗盘 + 构成）

var wave_index: int          # 1-based
var wave_total: int
var composition: WaveComposition

func _init(p_wave_index: int, p_wave_total: int, p_composition: WaveComposition) -> void:
	wave_index = p_wave_index
	wave_total = p_wave_total
	composition = p_composition
