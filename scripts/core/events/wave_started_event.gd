class_name WaveStartedEvent
extends Event
## 波次开始（刷怪）

var wave_index: int
var wave_total: int

func _init(p_wave_index: int, p_wave_total: int) -> void:
	wave_index = p_wave_index
	wave_total = p_wave_total
