class_name PlayerDiedEvent
extends Event
## 玩家阵亡（P7：复活系统 M0 不做，死亡仅提示，失败主判定以基地耐久为准）
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0

func _init(p_player_id: int = 0) -> void:
	player_id = p_player_id
