class_name EnemyProjectile
extends Node2D
## M5a 敌人远程弹体视觉（事件驱动，纯表现；游戏感改造版）
## - host 逻辑命中已裁决；本节点只负责从 origin 飞行到 target_position 后播放抵达反馈
## - 低分辨率方案：像素方块弹体 + 像素短尾 + 抵达像素爆点/冲击环，
##   不再使用 512px 高清软粒子贴图（与 Kenney 像素角色同语言）
## - 设计依据：godot-particles（2D 用 CPUParticles 或纯几何）+ tween-animation（加速入弯）

const BODY_SCALE := 1.25        # 8px 纹理 → 10px 弹体
const GLOW_SCALE := 2.1         # 16.8px 低透明外圈
const TAIL_LENGTH := 11.0

static func color_for_kind(kind: String) -> Color:
	if kind == "snipe":
		return Color(1.0, 0.62, 0.25)
	return Color(0.62, 0.95, 0.38)

## P1-15 敌方弹体走 Kenney 素材（VfxBank；狙击 = 暗弹，普通 = 红弹）
static func _body_texture_for_kind(kind: String) -> Texture2D:
	if kind == "snipe":
		return VfxBank.bullet("dark")
	return VfxBank.bullet("red")

var _move_tween: Tween
var _visual: Node2D

func setup(origin: Vector2, target_position: Vector2, speed: float, kind: String) -> void:
	global_position = origin
	z_index = 55
	var color := color_for_kind(kind)
	var direction := target_position - origin
	if direction.length_squared() > 0.001:
		rotation = direction.angle()

	_visual = Node2D.new()
	add_child(_visual)

	var glow := Sprite2D.new()
	glow.texture = FxBurst.get_pixel_texture()
	glow.scale = Vector2.ONE * GLOW_SCALE
	glow.modulate = Color(color.r, color.g, color.b, 0.28)
	_visual.add_child(glow)

	var body := Sprite2D.new()
	body.texture = _body_texture_for_kind(kind)
	body.scale = Vector2.ONE * BODY_SCALE
	body.modulate = color
	_visual.add_child(body)

	# 像素短尾：外圈光尾 + 内核亮尾（局部 -X = 飞行反方向）
	var tail_glow := Line2D.new()
	tail_glow.width = 6.0
	tail_glow.default_color = Color(color.r, color.g, color.b, 0.25)
	tail_glow.points = PackedVector2Array([Vector2(-TAIL_LENGTH, 0), Vector2(-3.0, 0)])
	tail_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tail_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	tail_glow.antialiased = true
	_visual.add_child(tail_glow)
	var tail_core := Line2D.new()
	tail_core.width = 2.0
	tail_core.default_color = Color(color.r, color.g, color.b, 0.9)
	tail_core.points = PackedVector2Array([Vector2(-TAIL_LENGTH * 0.65, 0), Vector2(-1.0, 0)])
	tail_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tail_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	tail_core.antialiased = true
	_visual.add_child(tail_core)

	# 发射口瞬间反馈：小像素爆点（host/client 同一事件驱动，双端一致）
	FxBurst.spawn_pixel_burst(origin, color, 4, 80.0, 0.14, 0.0)

	# 出膛缩放脉冲：0.5 → 1.0，制造“弹出”感
	var pulse := create_tween()
	pulse.tween_property(_visual, "scale", Vector2.ONE, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual.scale = Vector2.ONE * 0.5

	var distance := origin.distance_to(target_position)
	var duration := maxf(0.06, distance / maxf(speed, 1.0))
	# 加速入弯：起始略慢，逼近目标时加速（比匀速更有“发射感”）
	_move_tween = create_tween()
	_move_tween.tween_property(self, "global_position", target_position, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move_tween.tween_callback(_on_arrival.bind(color))

func _on_arrival(color: Color) -> void:
	# 抵达反馈：像素爆点 + 冲击环 + 短促动态光（纯表现，伤害由 host 已裁决）
	FxBurst.spawn_pixel_burst(global_position, color, 6, 140.0, 0.2, 0.0)
	FxBurst.spawn_impact_ring(global_position, color.lightened(0.15), 13.0, 0.12)
	LightingManager.request_flash(global_position, color.lightened(0.2), 0.85, 0.08)
	queue_free()
