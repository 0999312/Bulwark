class_name BaseDurabilityChangedEvent
extends Event
## 基地耐久变化（HUD 绑定用）

var current: float
var max_value: float

func _init(p_current: float, p_max: float) -> void:
	current = p_current
	max_value = p_max
