class_name MilitaryProgressBar
extends TextureProgressBar
## M1 军事化分段进度条：运行时生成 8px 段纹理（暗边框 + 分段凹槽），
## 颜色按 UiPalette 语义（fill_color 可 export）；纹理按颜色键缓存，不每帧创建。

const SEGMENT := 8

static var _texture_cache: Dictionary = {}

@export var fill_color: Color = UiPalette.ACCENT
@export var under_color: Color = Color(0.02, 0.03, 0.045)

func _ready() -> void:
	fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	nine_patch_stretch = true
	texture_under = _make_texture(under_color, true)
	texture_progress = _make_texture(fill_color, false)

func set_fill(value: Color) -> void:
	fill_color = value
	if is_inside_tree():
		texture_progress = _make_texture(value, false)

func _make_texture(color: Color, dark: bool) -> ImageTexture:
	var key := "%s_%s" % [color.to_html(true), "under" if dark else "fill"]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var img := Image.create(SEGMENT, SEGMENT, false, Image.FORMAT_RGBA8)
	var edge_color := Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 1.0)
	var groove_color := Color(color.r * 0.75, color.g * 0.75, color.b * 0.75, 1.0)
	for y in SEGMENT:
		for x in SEGMENT:
			if y == 0 or y == SEGMENT - 1 or x == 0 or x == SEGMENT - 1:
				img.set_pixel(x, y, edge_color)
			elif x == SEGMENT - 2:
				img.set_pixel(x, y, groove_color)
			else:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[key] = tex
	return tex
