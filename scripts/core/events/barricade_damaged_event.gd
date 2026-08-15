class_name BarricadeDamagedEvent
extends Event
## 路障受击（敌人啃路障；表现层受击反馈）

var facility_location: String
var durability: float
var max_durability: float

func _init(p_facility_location: String, p_durability: float, p_max_durability: float) -> void:
	facility_location = p_facility_location
	durability = p_durability
	max_durability = p_max_durability
