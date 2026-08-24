class_name PixelRing
extends Node2D
## 像素环冲击波（低分辨率游戏感组件，无外部贴图）：
## - 硬边方框 + 四角点 + 十字短线段，随半径扩散并淡出
## - 由 FxBurst.spawn_impact_ring 创建；与 Kenney 像素角色同语言
## - 纯程序化 draw，无高分辨率粒子贴图；一次创建、播完即释放

var _color := Color.WHITE
var _max_radius := 12.0
var _duration := 0.14
var _elapsed := 0.0

func setup(world_pos: Vector2, color: Color, max_radius: float, duration: float) -> void:
	global_position = world_pos
	_color = color
	_max_radius = maxf(4.0, max_radius)
	_duration = maxf(0.04, duration)
	z_index = 70

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()

func _draw() -> void:
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	var radius := _max_radius * (0.25 + 0.75 * t)
	var alpha := 1.0 - t
	var c := Color(_color, alpha)
	var r := roundi(radius)
	var d := roundi(radius * 0.7071)
	# 十字线段：上下左右四个方向（像素硬边，无抗锯齿）
	draw_rect(Rect2(-r - 2.0, -1.5, 4.0, 3.0), c)
	draw_rect(Rect2(r - 2.0, -1.5, 4.0, 3.0), c)
	draw_rect(Rect2(-1.5, -r - 2.0, 3.0, 4.0), c)
	draw_rect(Rect2(-1.5, r - 2.0, 3.0, 4.0), c)
	# 四角像素点：强调“方”而非圆的冲击波轮廓
	draw_rect(Rect2(d - 1.0, -d - 1.0, 2.0, 2.0), c)
	draw_rect(Rect2(-d - 1.0, -d - 1.0, 2.0, 2.0), c)
	draw_rect(Rect2(d - 1.0, d - 1.0, 2.0, 2.0), c)
	draw_rect(Rect2(-d - 1.0, d - 1.0, 2.0, 2.0), c)
