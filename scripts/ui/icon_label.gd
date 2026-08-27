class_name IconLabel
extends HBoxContainer
## M1 图标 + 文字复合控件（双通道：图标 + 文字；颜色/字号走 Theme override）。
## 静态资源经 UiIcon 取用；构造后可用 set_text / set_icon_key 更新。

var icon_rect: TextureRect
var label: Label

func _init(p_icon_key: String = "", p_text: String = "") -> void:
	add_theme_constant_override("separation", 6)
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false
	add_child(icon_rect)
	label = Label.new()
	add_child(label)
	set_icon_key(p_icon_key)
	set_text(p_text)

func set_icon_key(key: String) -> void:
	if key.is_empty():
		icon_rect.visible = false
		return
	icon_rect.texture = UiIcon.icon(key)
	icon_rect.visible = icon_rect.texture != null

func set_text(text: String) -> void:
	label.text = text

func set_font_size(size: int) -> void:
	label.add_theme_font_size_override("font_size", size)

func set_font_color(color: Color) -> void:
	label.add_theme_color_override("font_color", color)
