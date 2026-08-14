class_name PlayerStateChangedEvent
extends Event
## 玩家 FSM 状态变化（PlayerController.State 枚举值）

var state: int

func _init(p_state: int) -> void:
	state = p_state
