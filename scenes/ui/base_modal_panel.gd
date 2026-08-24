class_name BaseModalPanel
extends UIPanel
## M5d 共享模态面板基类：
## - 全屏压暗
## - 卡片进场 tween（≤250ms，TRANS_CUBIC + EASE_OUT）
## - tween 引用防重入，暂停树时仍按 process 推进（TWEEN_PAUSE_PROCESS）
## 子类在 _on_open 中先调用 super(data) 即可获得统一进场效果。

const ENTER_DURATION := 0.22
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.62)

var _dim: ColorRect
var _card: Control
var _enter_tween: Tween

func _ready() -> void:
	_setup_modal()

func _setup_modal() -> void:
	if _dim != null:
		return
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	move_child(_dim, 0)
	_card = _find_panel_container(self)
	if _card != null:
		_card.pivot_offset = _card.size * 0.5

func _on_open(data: Dictionary = {}) -> void:
	_play_enter()

func _on_close() -> void:
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()

func _play_enter() -> void:
	if _card == null:
		return
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	if _enter_tween != null and _enter_tween.is_valid():
		_enter_tween.kill()
	_enter_tween = create_tween()
	_enter_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_enter_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_enter_tween.set_parallel(true)
	_enter_tween.tween_property(_card, "modulate:a", 1.0, ENTER_DURATION)
	_enter_tween.tween_property(_card, "scale", Vector2.ONE, ENTER_DURATION)

func _find_panel_container(node: Node) -> Control:
	for child in node.get_children():
		if child is PanelContainer:
			return child as Control
		if child is Control:
			var found := _find_panel_container(child)
			if found != null:
				return found
	return null
