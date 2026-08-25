class_name ArcadeScore
extends RefCounted
## 街机分数/连击后端（P1-10，纯逻辑可 GUT 测）
## - 击杀得分 = 基础分 × combo_multiplier（外部分数加倍道具另乘）
## - combo 窗口：3.5s 内连续击杀 +1；超时/受致命伤重置
## - 波清 / 章清 / 无伤完美波奖励

const COMBO_WINDOW := 3.5
const COMBO_BASE_MULTIPLIER := 0.25
const COMBO_MULTIPLIER_CAP := 6.0

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var combo_timer: float = 0.0
var player_id: int = 0
## 外部加倍（道具“分数加速”：2.0；可与组合乘数相乘）
var external_multiplier: float = 1.0

var _last_gain: int = 0

func _init(p_player_id: int = 0) -> void:
	player_id = p_player_id

## 每帧驱动 combo 窗口
func tick(delta: float) -> void:
	if combo <= 0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		reset_combo()

## 击杀登记：返回本击杀得分增量；广播 ScoreChangedEvent
## 首杀 ×1.0，后续连击按当前 combo 加成（当前 combo 在击杀前查询）
func register_kill(base_score: int) -> int:
	var gain := int(round(base_score * get_multiplier()))
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_timer = COMBO_WINDOW
	score += gain
	_last_gain = gain
	_emit()
	return gain

## 外部倍率（道具）设置：0 视为 1.0
func set_external_multiplier(value: float) -> void:
	external_multiplier = maxf(0.0, value)

## 波清奖励；perfect = 本波基地未掉耐久且玩家未阵亡；返回奖励
func on_wave_cleared(perfect: bool, wave_scale: float) -> int:
	var bonus := int(round(500.0 * wave_scale)) if perfect else 0
	if bonus > 0:
		score += bonus
		combo = 0
		combo_timer = 0.0
		_emit()
	return bonus

## 章清奖励（章节系数）
func on_chapter_cleared(chapter_scale: float) -> int:
	var bonus := int(round(2000.0 * chapter_scale))
	score += bonus
	combo = 0
	combo_timer = 0.0
	_emit()
	return bonus

## 直接加分（调试/其他奖励）
func add_score(amount: int) -> void:
	if amount <= 0:
		return
	score += amount
	_emit()

## 受致命伤/复活失败：连击重置（分数保留）
func reset_combo() -> void:
	if combo == 0:
		return
	combo = 0
	combo_timer = 0.0
	_emit()

func get_multiplier() -> float:
	var combo_mult := minf(1.0 + combo * COMBO_BASE_MULTIPLIER, COMBO_MULTIPLIER_CAP)
	return combo_mult * maxf(0.0, external_multiplier)

## 最近一次击杀得分增量（伤害数字/反馈用）
func get_last_gain() -> int:
	return _last_gain

func _emit() -> void:
	EventBus.publish(ScoreChangedEvent.new(score, combo, get_multiplier(), player_id))
