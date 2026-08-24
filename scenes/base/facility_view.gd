class_name FacilityView
extends StaticBody2D
## 通用设施表现层（M5b）：自动炮塔/弹药补给点使用
## - 后端 FacilityController 持有耐久；本节点订阅事件做展示与移除
## - 碰撞：layer 8（world），与路障一致阻挡敌人/玩家（炮塔/补给点也占位）

@onready var sprite: Sprite2D = $Sprite

var controller: FacilityController
var _destroyed_freed := false

func setup(p_controller: FacilityController, p_texture: Texture2D = null,
		p_color: Color = Color.WHITE) -> void:
	controller = p_controller
	if p_texture != null:
		sprite.texture = p_texture
	sprite.modulate = p_color
	EventBus.subscribe(&"BarricadeDamagedEvent", _on_damaged)
	EventBus.subscribe(&"BarricadeDestroyedEvent", _on_destroyed)

func get_location() -> String:
	if controller == null:
		return ""
	return controller.get_location()

func _on_damaged(event: BarricadeDamagedEvent) -> void:
	if controller == null or event.facility_location != controller.get_location():
		return
	sprite.self_modulate = Color(1.0, 0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(sprite, "self_modulate", Color.WHITE, 0.15)

func _on_destroyed(event: BarricadeDestroyedEvent) -> void:
	if controller == null or event.facility_location != controller.get_location():
		return
	if _destroyed_freed:
		return
	_destroyed_freed = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
