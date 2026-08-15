class_name AmmoChangedEvent
extends Event
## 弹药变化（HUD 绑定用）
## reserve == AmmoSystem.INFINITE（-1）表示无限备弹（已定 P25 手枪）
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0
var ammo_type: int
var mag: int
var reserve: int

func _init(p_ammo_type: int, p_mag: int, p_reserve: int, p_player_id: int = 0) -> void:
	player_id = p_player_id
	ammo_type = p_ammo_type
	mag = p_mag
	reserve = p_reserve
