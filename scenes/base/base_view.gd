class_name BaseView
extends StaticBody2D
## 基地表现层：只读后端 BaseCore 状态驱动视觉（耐久变色/核心光效）

@onready var visual: Polygon2D = $Visual
@onready var core_visual: Polygon2D = $Visual/Core

var core: BaseCore

func setup(p_core: BaseCore) -> void:
	core = p_core
	EventBus.subscribe(&"BaseDurabilityChangedEvent", _on_durability_changed)
	_update_visual(core.durability, core.max_durability)

func _on_durability_changed(event: BaseDurabilityChangedEvent) -> void:
	_update_visual(event.current, event.max_value)

func _update_visual(current: float, max_value: float) -> void:
	var ratio := current / max_value if max_value > 0.0 else 0.0
	# 耐久高 → 偏青的军绿；耐久低 → 偏红（基地被打穿的既视感）
	visual.color = Color(0.28, 0.42, 0.5, 1.0).lerp(Color(0.5, 0.18, 0.16, 1.0), 1.0 - ratio)
	core_visual.modulate.a = 0.4 + 0.6 * ratio
