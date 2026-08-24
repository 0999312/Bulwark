class_name DamageContext
extends RefCounted
## 伤害上下文：来源/武器/弹道/部位 → 伤害管道输入
## 管道流程（架构 §4.4）：阵营过滤 → 攻击加成 → 暴击判定 → 防御减免 → 应用生命

var source_faction: int = Faction.Type.MUTANT
var target_faction: int = Faction.Type.PLAYER

## 基础伤害（来源攻击力）
var base_damage: float = 0.0
## 攻击加成（additive，如商店伤害+；M0 恒 0，结构留位）
var attack_bonus: float = 0.0

## 暴击判定
var crit_chance: float = 0.0
var crit_multiplier: float = 2.0

## 防御减免系数（0.0 ~ 0.9；调用方从目标数据读取，如 EnemyData.armor）
var defense: float = 0.0

## 弱点命中标记（已定 P31：M0 仅占位，命中 ×2；大型目标挂可选命中区为 M4+）
var weak_point_hit: bool = false
## 弱点倍率（默认 2.0；精英·巨兽数据可覆盖）
var weak_point_multiplier: float = 2.0

## 方向性护甲（装甲兽，P31）：开启后按攻击方向与目标朝向夹角判定正面/侧背
var directional_defense: bool = false
## 攻击方向（由伤害来源提供；零向量 = 不做方向判定）
var attack_direction: Vector2 = Vector2.ZERO
## 目标朝向（由目标实体提供；零向量 = 不做方向判定）
var facing_direction: Vector2 = Vector2.ZERO
## 正面护甲（directional_defense=true 且判定为正面时使用）
var frontal_defense: float = 0.0

func _init() -> void:
	pass

## 便捷构造：来源 → 目标的基础伤害
static func create(source: int, target: int, damage: float) -> DamageContext:
	var ctx := DamageContext.new()
	ctx.source_faction = source
	ctx.target_faction = target
	ctx.base_damage = damage
	return ctx
