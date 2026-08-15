class_name BaseView
extends StaticBody2D
## 基地表现层：只读后端 BaseCore 状态驱动视觉（耐久变色/核心光效/低耐久冒烟闪烁）

const LOW_RATIO := 0.35      # 低耐久阈值（低于此比例冒烟 + 核心闪烁）
const BLINK_SPEED := 8.0     # 低耐久核心闪烁频率

@onready var visual: Polygon2D = $Visual
@onready var core_visual: Polygon2D = $Visual/Core
@onready var smoke: CPUParticles2D = $Smoke

var core: BaseCore
var _low_durability := false
var _blink_t := 0.0

func setup(p_core: BaseCore) -> void:
	core = p_core
	EventBus.subscribe(&"BaseDurabilityChangedEvent", _on_durability_changed)
	_update_visual(core.durability, core.max_durability)

func _process(delta: float) -> void:
	if not _low_durability:
		return
	_blink_t += delta
	var a := 0.45 + 0.55 * (0.5 + 0.5 * sin(_blink_t * BLINK_SPEED))
	core_visual.self_modulate = Color(1.0, 0.45, 0.3, a)

func _on_durability_changed(event: BaseDurabilityChangedEvent) -> void:
	_update_visual(event.current, event.max_value)

func _update_visual(current: float, max_value: float) -> void:
	var ratio := current / max_value if max_value > 0.0 else 0.0
	_low_durability = ratio <= LOW_RATIO
	# 耐久高 → 偏青的军绿；耐久低 → 偏红（基地被打穿的既视感）
	visual.color = Color(0.28, 0.42, 0.5, 1.0).lerp(Color(0.5, 0.18, 0.16, 1.0), 1.0 - ratio)
	core_visual.modulate.a = 0.4 + 0.6 * ratio
	if smoke != null:
		smoke.emitting = _low_durability
	if not _low_durability:
		core_visual.self_modulate = Color.WHITE
		_blink_t = 0.0
