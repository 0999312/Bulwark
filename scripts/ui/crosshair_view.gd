class_name CrosshairView
extends CanvasLayer
## 战斗准星绘制层（M4 手感可视化 · 用户反馈"准星抖动"）：
## - 跟随鼠标（屏幕坐标）+ 后坐抖动（heat 驱动，每帧随机偏移，幅度随热态增大）
## - 热态扩散：heat ≥ HEAT_MAX/2 时准星张开 + 颜色转橙红，直观感受后坐冲击
## - 与 CursorStateMachine 配合：COMBAT 时隐藏 OS 光标，由本层绘制；面板/暂停/换弹时隐藏

const BASE_JITTER := 1.6
const HEAT_JITTER := 1.9
const HEAT_BLOOM_THRESHOLD := 2.0

var _panel: Control
var _shown := false
var _heat := 0.0

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_cross)
	add_child(_panel)

func _process(_delta: float) -> void:
	_heat = CursorStateMachine.get_combat_heat()
	_shown = CursorStateMachine.is_combat_overlay_visible()
	_panel.queue_redraw()

func _draw_cross() -> void:
	if not _shown:
		return
	var pos := get_viewport().get_mouse_position()
	# 后坐抖动：每帧随机偏移，幅度随 heat 增大（下限 1.6px，热度满时约 9.2px）
	var amp := BASE_JITTER + _heat * HEAT_JITTER
	pos += Vector2(randf_range(-amp, amp), randf_range(-amp, amp))

	var bloom := _heat >= HEAT_BLOOM_THRESHOLD
	var r := (11.0 if bloom else 9.0) + _heat * 0.6
	var gap := 5.0
	var color := Color(1.0, 0.56, 0.3) if bloom else Color(1.0, 0.85, 0.47)
	var width := 2.0

	# 四段刻度 + 中心点（张开的"扩散"观感）
	_panel.draw_line(pos + Vector2(-r, 0), pos + Vector2(-gap, 0), color, width)
	_panel.draw_line(pos + Vector2(r, 0), pos + Vector2(gap, 0), color, width)
	_panel.draw_line(pos + Vector2(0, -r), pos + Vector2(0, -gap), color, width)
	_panel.draw_line(pos + Vector2(0, r), pos + Vector2(0, gap), color, width)
	_panel.draw_circle(pos, 1.8, color)
	# 热态外圈微光
	if bloom:
		_panel.draw_arc(pos, r + 4.0, 0, TAU, 24, Color(color.r, color.g, color.b, 0.35), 1.5)
