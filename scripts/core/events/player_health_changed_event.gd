class_name PlayerHealthChangedEvent
extends Event
## 玩家生命变化（HUD 绑定用）

var current: float
var max_value: float

func _init(p_current: float, p_max: float) -> void:
	current = p_current
	max_value = p_max
