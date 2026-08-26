class_name WaveStartedEvent
extends Event
## 波次开始（刷怪）

var wave_index: int
var wave_total: int
## P1-8 章节制
var chapter_index: int = -1
var is_boss_wave: bool = false
## P2-17 无尽循环号
var cycle_index: int = 0

func _init(p_wave_index: int, p_wave_total: int,
		p_chapter_index: int = -1, p_is_boss_wave: bool = false,
		p_cycle_index: int = 0) -> void:
	wave_index = p_wave_index
	wave_total = p_wave_total
	chapter_index = p_chapter_index
	is_boss_wave = p_is_boss_wave
	cycle_index = p_cycle_index
