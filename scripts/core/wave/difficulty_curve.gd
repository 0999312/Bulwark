class_name DifficultyCurve
extends RefCounted
## M5e 难度曲线一张表（6 波单链）
## 供波次/平衡调参使用；当前保留为数据表 + 查询接口，后续可接入 WaveDirector 动态缩放。
## 索引按 1-based 波次。

const WAVE_SCALES := [1.0, 1.12, 1.25, 1.4, 1.6, 1.8]

static func get_wave_scale(wave_index: int) -> float:
	if wave_index < 1 or wave_index > WAVE_SCALES.size():
		return 1.0
	return WAVE_SCALES[wave_index - 1]

static func get_wave_count() -> int:
	return WAVE_SCALES.size()
