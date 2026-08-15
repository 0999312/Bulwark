class_name BarricadePlacedEvent
extends Event
## 路障放置（后端放置意图已受理；表现层实例化路障节点）

var facility_location: String
var position: Vector2

func _init(p_facility_location: String, p_position: Vector2) -> void:
	facility_location = p_facility_location
	position = p_position
