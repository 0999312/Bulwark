class_name ChapterDefinition
extends Resource
## 章节模板（P1-8）：主题色调 + 3 普通波 + 章末精英波 + 章系数
## - theme_rgb 供 main.tscn/地面色调切章（§5 章节主题，P1-9）
## - chapter_scale 接入 DifficultyCurve（chapter_scale × wave_scale）

@export_group("标识")
@export var id: String = ""
## 中文回退显示名（UI 经 UiText.content_name 取键）
@export var display_name: String = ""

@export_group("主题")
## 地面/环境主色调（章节辨识度）
@export var theme_rgb: Color = Color(0.36, 0.62, 0.4, 1.0)

@export_group("编排")
## 普通波（3 波）
@export var waves: Array[WaveData] = []
## 章末精英波（1 波）
@export var boss_wave: WaveData = null

@export_group("强度")
## 本章难度系数（与 DifficultyCurve.get_wave_scale(wave_in_chapter) 相乘）
@export var chapter_scale: float = 1.0

@export_group("奖励")
## 章间奖励池（三选一/结算预留；P2）
@export var round_reward_pool: Array[String] = []
