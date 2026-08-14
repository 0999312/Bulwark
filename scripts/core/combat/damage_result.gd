class_name DamageResult
extends RefCounted
## 伤害结算结果

var damage: float = 0.0
var critical: bool = false
## 阵营过滤拦截（同阵营免疫：玩家→玩家恒 0，已定 P30）
var blocked_by_faction: bool = false

func is_zero() -> bool:
	return damage <= 0.0
