class_name AmmoChangedEvent
extends Event
## 弹药变化（HUD 绑定用）
## reserve == AmmoSystem.INFINITE（-1）表示无限备弹（已定 P25 手枪）

var ammo_type: int
var mag: int
var reserve: int

func _init(p_ammo_type: int, p_mag: int, p_reserve: int) -> void:
	ammo_type = p_ammo_type
	mag = p_mag
	reserve = p_reserve
