class_name TurretView
extends FacilityView
## 自动炮塔表现层（BUG 交接）：在通用设施视图基础上增加炮管朝向反馈。
## 开火事件由 host/client 共同接收（client 经中继），炮管转向裁决命中点。

@onready var barrel: Sprite2D = $Barrel

func setup(p_controller: FacilityController, p_texture: Texture2D = null,
		p_color: Color = Color.WHITE) -> void:
	super(p_controller, p_texture, p_color)
	EventBus.subscribe(&"TurretFiredEvent", _on_turret_fired)

func _on_turret_fired(event: TurretFiredEvent) -> void:
	if controller == null or event == null:
		return
	if event.facility_location != controller.get_location():
		return
	if barrel == null:
		return
	barrel.rotation = (event.target_position - global_position).angle()
	# 炮管微后座（纯表现；0.09s 回弹）
	barrel.position = Vector2(-3.0, 0.0).rotated(barrel.rotation)
	var tw := create_tween()
	tw.tween_property(barrel, "position", Vector2.ZERO, 0.09) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
