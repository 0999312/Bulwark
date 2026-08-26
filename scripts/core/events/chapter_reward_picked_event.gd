class_name ChapterRewardPickedEvent
extends Event
## P2-19 章间三选一：玩家选定奖励（host 权威；表现层发布 → GameSession 应用）

var power_id: String
var chapter_index: int

func _init(p_power_id: String, p_chapter_index: int = -1) -> void:
	power_id = p_power_id
	chapter_index = p_chapter_index
