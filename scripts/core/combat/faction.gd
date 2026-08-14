class_name Faction
extends RefCounted
## 阵营定义（P30 禁队友伤害的判定依据）
## 阵营 = 玩家 / 异变体；玩家阵营间伤害恒为 0（伤害管道第一道闸，M0 即实现）。

enum Type {
	PLAYER = 1, # 玩家阵营（合作模式下所有玩家同阵营）
	MUTANT = 2, # 异变体阵营
}
