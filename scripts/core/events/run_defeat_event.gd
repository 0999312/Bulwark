class_name RunDefeatEvent
extends Event
## 本局失败结算（P7：主判定 = 基地耐久归零；玩家阵亡提示性，复活结构留位）

enum Reason {
	BASE_DESTROYED = 0, # 基地耐久归零（唯一主失败条件，已定 P7）
	PLAYER_DEAD = 1,    # 玩家阵亡（M0 仅提示；复活/失败判定结构留位，M1+ 联入资源判定）
}

var reason: int

func _init(p_reason: int) -> void:
	reason = p_reason
