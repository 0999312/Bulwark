class_name WaveWarningEvent
extends Event
## 波次预警（HUD 波次预告：方位数量级 + 构成）
## direction_tiers（M2）：{"heavy": [dir...], "light": [dir...]}，由 WaveDirector 按
## WaveComposition.summarize_tiers() 填充；空 = 旧逻辑回退（逐方向罗列）

var wave_index: int          # 1-based
var wave_total: int
var composition: WaveComposition
var direction_tiers: Dictionary = {}
## M5d：网络只广播数量档 + 精英标记（D-M5-13）
var threat_tier: String = ""
var has_elite: bool = false
## P1-8 章节制：章节索引（0-based）/章名回退/章内波次（0-based）/是否为章末精英波
var chapter_index: int = -1
var chapter_name: String = ""
var wave_in_chapter: int = -1
var is_boss_wave: bool = false

func _init(p_wave_index: int, p_wave_total: int, p_composition: WaveComposition,
		p_direction_tiers: Dictionary = {}, p_threat_tier: String = "",
		p_has_elite: bool = false, p_chapter_index: int = -1,
		p_chapter_name: String = "", p_wave_in_chapter: int = -1,
		p_is_boss_wave: bool = false) -> void:
	wave_index = p_wave_index
	wave_total = p_wave_total
	composition = p_composition
	direction_tiers = p_direction_tiers
	threat_tier = p_threat_tier
	has_elite = p_has_elite
	chapter_index = p_chapter_index
	chapter_name = p_chapter_name
	wave_in_chapter = p_wave_in_chapter
	is_boss_wave = p_is_boss_wave
