class_name BarricadeDestroyedEvent
extends Event
## 路障被摧毁（表现层播放破坏特效并移除节点）

var facility_location: String

func _init(p_facility_location: String) -> void:
	facility_location = p_facility_location
