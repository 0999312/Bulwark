class_name WaveClearedEvent
extends Event
## 波次清场

var wave_index: int
## P1-8 章节制
var chapter_index: int = -1
var is_boss_wave: bool = false

func _init(p_wave_index: int, p_chapter_index: int = -1, p_is_boss_wave: bool = false) -> void:
	wave_index = p_wave_index
	chapter_index = p_chapter_index
	is_boss_wave = p_is_boss_wave
