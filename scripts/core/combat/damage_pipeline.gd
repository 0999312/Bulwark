class_name DamagePipeline
extends RefCounted
## 伤害管道（架构 §4.4）：纯逻辑、headless 可测
## 流程：
##   1. 阵营过滤（第一道闸，硬性 P30）：玩家阵营间伤害恒为 0（禁队友伤害）
##   2. 攻击加成：base + attack_bonus
##   3. 暴击判定：roll < crit_chance → ×crit_multiplier
##   4. 弱点（P31 占位）：weak_point_hit → ×2
##   5. 防御减免：×(1 - defense)
## 结果不直接改动目标生命；由调用方（实体）应用并广播 OnDamageDealt / OnKilled。

## 计算最终伤害（rng 可选：传入可复现的随机源用于测试/确定性）
static func compute(ctx: DamageContext, rng: RandomNumberGenerator = null) -> DamageResult:
	var result := DamageResult.new()

	# ── 1. 阵营过滤（第一道闸）：玩家→玩家恒 0（P30 禁止队友伤害）
	#    异变体→异变体同样免疫（AOE/溅射排除同阵营的同一规则；M0 无 AOE，规则先行）
	if ctx.source_faction == ctx.target_faction:
		result.blocked_by_faction = true
		return result

	# ── 2. 攻击加成
	var damage: float = ctx.base_damage + ctx.attack_bonus
	if damage <= 0.0:
		return result

	# ── 3. 暴击判定
	if ctx.crit_chance > 0.0:
		var roll: float
		if rng != null:
			roll = rng.randf()
		else:
			roll = randf()
		if roll < ctx.crit_chance:
			damage *= ctx.crit_multiplier
			result.critical = true

	# ── 4. 弱点（P31 占位：命中 ×2）
	if ctx.weak_point_hit:
		damage *= 2.0

	# ── 5. 防御减免
	damage *= 1.0 - clampf(ctx.defense, 0.0, 0.9)

	result.damage = damage
	return result
