class_name TurretTracer
extends Node2D
## 炮塔粗射线表现（BUG 交接）：类似玩家 HITSCAN tracer，但更粗、更亮。
## host 用 HitscanResolver 裁决命中点，client 由中继事件驱动同一表现，
## 弹道不再使用飞行弹体，视觉与裁决一致。

const DURATION := 0.12

func setup(from: Vector2, to: Vector2) -> void:
	z_index = 60

	var glow := _make_line(18.0, Color(0.25, 0.85, 1.0, 0.35), from, to)
	add_child(glow)
	var mid := _make_line(9.0, Color(0.4, 0.92, 1.0, 0.75), from, to)
	add_child(mid)
	var core := _make_line(4.0, Color(0.9, 1.0, 1.0, 1.0), from, to)
	add_child(core)

	# 枪口/命中点闪光（Kenney shotLarge，经 VfxBank）
	var muzzle := Sprite2D.new()
	muzzle.texture = VfxBank.muzzle("large")
	muzzle.position = from
	muzzle.scale = Vector2(0.7, 0.7)
	add_child(muzzle)
	var hit := Sprite2D.new()
	hit.texture = VfxBank.muzzle("large")
	hit.position = to
	hit.scale = Vector2(0.45, 0.45)
	add_child(hit)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(muzzle, "scale", Vector2(1.4, 1.4), DURATION)
	tw.chain().tween_callback(queue_free)

func _make_line(width: float, color: Color, from: Vector2, to: Vector2) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.points = PackedVector2Array([from, to])
	return line
