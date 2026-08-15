class_name ReviveStartedEvent
extends Event
## 复活开始（P7/P20：消耗应急储备，进入复活 CD；表现层播放倒地/读条）
## player_id 供多人区分（默认 0 = 单机/本地）

var player_id: int = 0
var revive_cd: float

func _init(p_revive_cd: float, p_player_id: int = 0) -> void:
	player_id = p_player_id
	revive_cd = p_revive_cd
