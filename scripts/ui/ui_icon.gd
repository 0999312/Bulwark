class_name UiIcon
extends RefCounted
## M1 图标单一入口（静态工具类）：把 assets/icons / VfxBank / Kenney 素材映射为 Texture2D，
## 只允许从这里取图标，禁止散落 preload 魔法路径；纹理按 key 缓存（一次性 load）。
## 单色 SVG 图标为 10px 源（svg/scale=1.0），在小尺寸下按需由 M1 后续重导出描边版；
## 缺项（HP/波次/武器等）先用 Kenney/VfxBank 成品占位。

const ICON_PATHS := {
	# 已有 SVG
	"shop": "res://assets/icons/ui/shop.svg",
	"settings": "res://assets/icons/ui/settings.svg",
	"ranking": "res://assets/icons/ui/ranking.svg",
	"trophy": "res://assets/icons/ui/trophy.svg",
	"star": "res://assets/icons/feedback/star.svg",
	"book": "res://assets/icons/ui/book.svg",
	"users": "res://assets/icons/user/user_group.svg",
	"exit": "res://assets/icons/feedback/cross.svg",
	"arrow_right": "res://assets/icons/arrow/arrow_right.svg",
	"menu": "res://assets/icons/ui/menu.svg",
	"refresh": "res://assets/icons/ui/refresh.svg",
	"lock": "res://assets/icons/ui/lock.svg",
	"puzzle": "res://assets/icons/ui/puzzle.svg",
	"skull": "res://assets/icons/user/skull.svg",
	"yuan": "res://assets/icons/misc/yuan_yen.svg",
	# Kenney / VfxBank 占位（军事语义缺项）
	"bullet": "res://assets/vfx/kenney/bullets/bulletGreen1.png",
	"crate": "res://assets/sprites/props/crateMetal.png",
	"wood": "res://assets/vfx/kenney/debris/crateWood.png",
	"sandbag": "res://assets/sprites/props/sandbagBeige.png",
	"tank": "res://assets/sprites/turret/tankBody_dark.png",
	"explosion": "res://assets/vfx/kenney/explosion/explosion1.png",
}

static var _cache: Dictionary = {}

## 取图标（缓存；未知 key 返回 null 并告警一次）
static func icon(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path: String = ICON_PATHS.get(key, "")
	if path.is_empty():
		push_warning("UiIcon: unknown icon key '%s'" % key)
		return null
	var tex := load(path) as Texture2D
	_cache[key] = tex
	return tex

## 应用到 TextureRect（保持方寸，不缩放裁边）
static func apply(tex_rect: TextureRect, key: String, size: Vector2 = Vector2(18, 18)) -> void:
	tex_rect.texture = icon(key)
	tex_rect.custom_minimum_size = size
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
