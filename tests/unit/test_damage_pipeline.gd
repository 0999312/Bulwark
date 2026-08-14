extends GutTest
## 伤害管道测试（架构 §4.4）：
## 阵营过滤（P30 第一道闸）→ 攻击加成 → 暴击判定 → 防御减免 → 弱点占位（P31）

func test_player_to_player_damage_is_zero() -> void:
	# P30：玩家阵营间伤害恒为 0（禁止队友伤害）
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.PLAYER, 50.0)
	ctx.crit_chance = 1.0
	var result := DamagePipeline.compute(ctx)
	assert_true(result.blocked_by_faction, "同阵营应被第一道闸拦截")
	assert_eq(result.damage, 0.0, "玩家→玩家伤害必须为 0")

func test_same_faction_always_blocked_even_with_high_crit() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.MUTANT, 999.0)
	ctx.crit_chance = 1.0
	ctx.weak_point_hit = true
	var result := DamagePipeline.compute(ctx)
	assert_true(result.blocked_by_faction)
	assert_eq(result.damage, 0.0)

func test_mutant_to_player_damage_applies() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 10.0)
	var result := DamagePipeline.compute(ctx)
	assert_false(result.blocked_by_faction)
	assert_almost_eq(result.damage, 10.0, 0.001)

func test_attack_bonus_is_additive() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 10.0)
	ctx.attack_bonus = 5.0
	var result := DamagePipeline.compute(ctx)
	assert_almost_eq(result.damage, 15.0, 0.001)

func test_crit_roll_and_multiplier() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var crit_ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 10.0)
	crit_ctx.crit_chance = 1.0
	crit_ctx.crit_multiplier = 2.0
	var crit_result := DamagePipeline.compute(crit_ctx, rng)
	assert_true(crit_result.critical)
	assert_almost_eq(crit_result.damage, 20.0, 0.001)

	var no_crit_ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 10.0)
	no_crit_ctx.crit_chance = 0.0
	var no_crit_result := DamagePipeline.compute(no_crit_ctx, rng)
	assert_false(no_crit_result.critical)
	assert_almost_eq(no_crit_result.damage, 10.0, 0.001)

func test_defense_reduction() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 100.0)
	ctx.defense = 0.25
	var result := DamagePipeline.compute(ctx)
	assert_almost_eq(result.damage, 75.0, 0.001)

func test_defense_clamped_to_0_9() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 100.0)
	ctx.defense = 5.0
	var result := DamagePipeline.compute(ctx)
	assert_almost_eq(result.damage, 10.0, 0.001)

func test_weak_point_placeholder_doubles() -> void:
	# P31 弱点机制 M0 仅占位：weak_point_hit → ×2
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 10.0)
	ctx.weak_point_hit = true
	var result := DamagePipeline.compute(ctx)
	assert_almost_eq(result.damage, 20.0, 0.001)

func test_crit_and_weak_point_stack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 10.0)
	ctx.crit_chance = 1.0
	ctx.crit_multiplier = 2.0
	ctx.weak_point_hit = true
	var result := DamagePipeline.compute(ctx, rng)
	assert_almost_eq(result.damage, 40.0, 0.001)
