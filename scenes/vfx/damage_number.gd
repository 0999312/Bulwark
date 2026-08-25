class_name DamageNumber
extends Node2D
## 浮动伤害数字（P1-11，池化；8px 像素语言 → 小字号 MiSans + 上浮淡出）
## 颜色语义：白=普通 / 黄=暴击 / 紫=弱点 / 橙=高倍击杀（由调用方指定）

const DURATION := 0.7
const RISE_SPEED := 42.0
const FONT_SIZE := 15

var _text := ""
var _color := Color.WHITE
var _t := 0.0
var _active := false

func setup(text: String, color: Color, world_pos: Vector2) -> void:
	_text = text
	_color = color
	global_position = world_pos
	_t = 0.0
	_active = true
	visible = true
	modulate = Color.WHITE
	z_index = 70

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	position.y -= RISE_SPEED * delta
	modulate.a = clampf(1.0 - _t / DURATION, 0.0, 1.0)
	queue_redraw()
	if _t >= DURATION:
		_active = false
		visible = false

func _draw() -> void:
	if not _active or _text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	draw_string(font, Vector2(-width * 0.5, 4.0), _text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _color)
