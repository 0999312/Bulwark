class_name RunStateChangedEvent
extends Event
## 当局资源变化（货币 / 建材 / 应急储备；商店与 HUD 绑定）
## 能量已移除（弹药补给台删除）；M3 问题 4：携带 player_id（默认 0 = 单机/本地）

var credits: int
var material: int
var reserve: int
var player_id: int

func _init(p_credits: int, p_material: int, p_reserve: int, p_player_id: int = 0) -> void:
	credits = p_credits
	material = p_material
	reserve = p_reserve
	player_id = p_player_id
