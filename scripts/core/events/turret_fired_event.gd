class_name TurretFiredEvent
extends Event
## 自动炮塔开火（M5b + BUG 交接）：host 逻辑命中已由 HitscanResolver 裁决。
## target_position = 射线命中点（圆面进入点），事件驱动 client 粗射线表现与炮管朝向。

var facility_location: String
var origin: Vector2
var target_position: Vector2
var target_net_id: int
var damage: float

func _init(p_facility_location: String, p_origin: Vector2, p_target_position: Vector2,
		p_target_net_id: int, p_damage: float) -> void:
	facility_location = p_facility_location
	origin = p_origin
	target_position = p_target_position
	target_net_id = p_target_net_id
	damage = p_damage
