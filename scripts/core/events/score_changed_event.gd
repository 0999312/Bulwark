class_name ScoreChangedEvent
extends Event
## 分数/连击变化（P1-10；HUD 滚动数字/连击条订阅）

var score: int
var combo: int
var multiplier: float
var player_id: int

func _init(p_score: int, p_combo: int, p_multiplier: float, p_player_id: int = 0) -> void:
	score = p_score
	combo = p_combo
	multiplier = p_multiplier
	player_id = p_player_id
