class_name RunStateChangedEvent
extends Event
## 当局资源变化（货币 / 建材 / 应急储备；商店与 HUD 绑定）

var credits: int
var material: int
var reserve: int

func _init(p_credits: int, p_material: int, p_reserve: int) -> void:
	credits = p_credits
	material = p_material
	reserve = p_reserve
