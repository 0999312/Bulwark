class_name RunDefinition
extends Resource
## 一局运行定义（P1-8）：数据驱动章节编排
## - chapters：4 章模板（每章 3 普通波 + 1 章末精英波）
## - GameSession 展开为 WaveDirector 的扁平波次流（默认遗留模式仍走 Bulwark.WAVE_IDS 回退）
## - 用途：run_arcade.tres（主菜单街机模式）；legacy 单章 6 波 = 不加载本类时保留

@export_group("标识")
@export var id: String = ""
## 中文回退显示名（UI 经 UiText.content_name 取键）
@export var display_name: String = ""

@export_group("编排")
## 章节列表（顺序执行）
@export var chapters: Array[ChapterDefinition] = []

## 高分局分组键（按 RunDefinition id；默认空 = 本机单一榜单）
@export var highscore_key: String = ""

func get_total_wave_count() -> int:
	var total := 0
	for chapter: ChapterDefinition in chapters:
		total += chapter.waves.size() + 1
	return total

## 第 chapter_index 章（0-based）的波次+精英数量
func chapter_wave_count(chapter_index: int) -> int:
	if chapter_index < 0 or chapter_index >= chapters.size():
		return 0
	return chapters[chapter_index].waves.size() + 1
