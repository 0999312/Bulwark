class_name ShotFiredEvent
extends Event
## 开火意图已通过后端验证（弹药/冷却），弹道生成事件
## 前端表现层据此执行弹道（HITSCAN 射线 / 弹体）并回报命中
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0
var model_location: String      # WeaponModelData 的 ResourceLocation 字符串
var aim_direction: Vector2      # 瞄准方向（单位向量；后端只发意图，射击原点由表现层提供）

func _init(p_model_location: String, p_aim_direction: Vector2, p_player_id: int = 0) -> void:
	player_id = p_player_id
	model_location = p_model_location
	aim_direction = p_aim_direction
