extends GutTest
## 奔跑者后端控制器测试：行为 FSM（Chase/Attack/Dead）+ 攻击事件 + 受击/死亡

var _attack_count := 0
var _died := false

func before_each() -> void:
	_attack_count = 0
	_died = false
	# 清理跨测试累积的事件订阅（GUT 复用同一测试实例，lambda 每次新建不会去重）
	EventBus.clear_all_listeners()

func _make_runner() -> EnemyController:
	var data := EnemyData.new()
	data.id = "enemy/runner"
	data.max_hp = 30.0
	data.move_speed = 185.0
	data.attack_damage = 8.0
	data.attack_interval = 1.0
	data.attack_range = 42.0
	return EnemyController.new(data)

func test_initial_chase_state() -> void:
	var runner := _make_runner()
	assert_eq(runner.state, EnemyController.State.CHASE)
	assert_eq(runner.health, 30.0)

func test_far_target_keeps_chase() -> void:
	var runner := _make_runner()
	runner.tick(0.016, 500.0)
	assert_eq(runner.state, EnemyController.State.CHASE)

func test_close_target_enters_attack_and_emits_event() -> void:
	var runner := _make_runner()
	EventBus.subscribe(&"EnemyAttackEvent",
		func(_e: EnemyAttackEvent) -> void: _attack_count += 1)
	# 进入攻击距离：首爪前有一个完整攻击间隔的反应时间（不再落地即咬）
	runner.tick(0.016, 30.0)
	assert_eq(runner.state, EnemyController.State.ATTACK)
	assert_eq(_attack_count, 0, "接敌首帧不出爪（给玩家反应时间）")
	runner.tick(0.5, 30.0)
	assert_eq(_attack_count, 0, "攻击间隔内不应出爪")
	# 满一个间隔后出第一爪
	runner.tick(0.6, 30.0)
	assert_eq(_attack_count, 1, "满攻击间隔后出第一爪")
	# 再过 1.0s 出第二爪
	runner.tick(0.5, 30.0)
	assert_eq(_attack_count, 1)
	runner.tick(0.6, 30.0)
	assert_eq(_attack_count, 2, "按 attack_interval 节奏出爪")

func test_leave_range_returns_to_chase() -> void:
	var runner := _make_runner()
	runner.tick(0.016, 30.0)
	assert_eq(runner.state, EnemyController.State.ATTACK)
	runner.tick(0.016, 100.0)
	assert_eq(runner.state, EnemyController.State.CHASE)

func test_take_damage_through_pipeline_and_die() -> void:
	var runner := _make_runner()
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 12.0)
	var result := runner.take_damage(ctx)
	assert_almost_eq(result.damage, 12.0, 0.001)
	assert_almost_eq(runner.health, 18.0, 0.001)
	ctx.base_damage = 18.0
	runner.take_damage(ctx)
	assert_true(runner.is_dead())
	assert_eq(runner.state, EnemyController.State.DEAD)

func test_death_broadcasts_enemy_died() -> void:
	var runner := _make_runner()
	EventBus.subscribe(&"EnemyDiedEvent", func(_e: EnemyDiedEvent) -> void: _died = true)
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 999.0)
	runner.take_damage(ctx)
	assert_true(_died, "死亡应广播 EnemyDiedEvent（WaveDirector 簿记）")
	# 死亡后伤害不再生效、事件只广播一次
	runner.take_damage(ctx)
	assert_eq(_died, true)

func test_die_entrypoint_is_idempotent() -> void:
	# 撞击自爆入口（EnemyView 撞击玩家调用）：广播一次且幂等
	var runner := _make_runner()
	var death_count := [0]
	EventBus.subscribe(&"EnemyDiedEvent", func(_e: EnemyDiedEvent) -> void: death_count[0] += 1)
	runner.die()
	assert_true(runner.is_dead())
	runner.die()
	assert_eq(death_count[0], 1, "死亡事件只广播一次")

func test_same_faction_attack_blocked() -> void:
	# P30：异变体→异变体同阵营免疫（与玩家间禁伤害同一道闸）
	var runner := _make_runner()
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.MUTANT, 50.0)
	var result := runner.take_damage(ctx)
	assert_true(result.blocked_by_faction)
	assert_eq(runner.health, 30.0)

func test_armor_reduces_incoming_damage() -> void:
	var data := EnemyData.new()
	data.id = "enemy/runner"
	data.max_hp = 100.0
	data.armor = 0.25
	var runner := EnemyController.new(data)
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 40.0)
	ctx.defense = data.armor
	runner.take_damage(ctx)
	assert_almost_eq(runner.health, 70.0, 0.001, "防御减免 25%")

# ─── M5a：多威胁模式分派 ───

func test_spitter_fires_ranged_event() -> void:
	var data := EnemyData.new()
	data.id = "enemy/spitter"
	data.threat_mode = EnemyData.ThreatMode.SPITTER
	data.max_hp = 20.0
	data.attack_damage = 10.0
	data.attack_interval = 1.0
	data.attack_range = 200.0
	data.projectile_speed = 300.0
	var enemy := EnemyController.new(data)
	var ranged: Array[EnemyRangedAttackEvent] = []
	EventBus.subscribe(&"EnemyRangedAttackEvent",
		func(e: EnemyRangedAttackEvent) -> void: ranged.append(e))
	enemy.tick(0.016, 100.0, null, Vector2.ZERO, Vector2(100, 0))
	assert_eq(ranged.size(), 0, "进入射程首帧不立即开火（反应时间）")
	for i in 6:
		enemy.tick(0.2, 100.0, null, Vector2.ZERO, Vector2(100, 0))
	assert_eq(ranged.size(), 1, "满攻击间隔后发射一次")
	assert_eq(ranged[0].projectile_kind, "spit")
	assert_eq(ranged[0].damage, 10.0)

func test_ranged_target_at_world_origin_falls_back_to_facing_not_right() -> void:
	var data := EnemyData.new()
	data.id = "enemy/spitter"
	data.threat_mode = EnemyData.ThreatMode.SPITTER
	data.max_hp = 20.0
	data.attack_damage = 10.0
	data.attack_interval = 1.0
	data.attack_range = 200.0
	data.projectile_speed = 300.0
	var enemy := EnemyController.new(data)
	var ranged: Array[EnemyRangedAttackEvent] = []
	EventBus.subscribe(&"EnemyRangedAttackEvent",
		func(e: EnemyRangedAttackEvent) -> void: ranged.append(e))
	# 基地位于世界原点 (0,0)，敌人从 +X 方向面朝基地攻击
	for i in 6:
		enemy.tick(0.2, 100.0, null, Vector2(100, 0), Vector2.ZERO, Vector2.LEFT)
	assert_eq(ranged.size(), 1)
	assert_eq(ranged[0].target_position, Vector2.ZERO,
		"目标为原点基地时不得被替换成向右的哨兵落点")

func test_sniper_windup_delays_first_shot() -> void:
	var data := EnemyData.new()
	data.id = "enemy/sniper"
	data.threat_mode = EnemyData.ThreatMode.SNIPER
	data.max_hp = 25.0
	data.attack_damage = 25.0
	data.attack_interval = 1.0
	data.attack_range = 300.0
	data.windup_time = 0.5
	var enemy := EnemyController.new(data)
	var ranged: Array[EnemyRangedAttackEvent] = []
	EventBus.subscribe(&"EnemyRangedAttackEvent",
		func(e: EnemyRangedAttackEvent) -> void: ranged.append(e))
	enemy.tick(1.4, 100.0, null, Vector2.ZERO, Vector2(200, 0))
	assert_eq(ranged.size(), 0, "蓄力未完成不发射")
	enemy.tick(0.2, 100.0, null, Vector2.ZERO, Vector2(200, 0))
	assert_eq(ranged.size(), 1, "蓄力完成后发射")
	assert_eq(ranged[0].projectile_kind, "snipe")

func test_self_destruct_explodes_aoe_and_dies() -> void:
	var data := EnemyData.new()
	data.id = "enemy/self_destruct"
	data.threat_mode = EnemyData.ThreatMode.SELF_DESTRUCT
	data.max_hp = 18.0
	data.attack_interval = 1.0
	data.attack_range = 42.0
	data.explosion_radius = 90.0
	data.explosion_damage = 30.0
	var enemy := EnemyController.new(data)
	var aoe: Array[EnemyAoEEvent] = []
	EventBus.subscribe(&"EnemyAoEEvent",
		func(e: EnemyAoEEvent) -> void: aoe.append(e))
	enemy.tick(0.016, 20.0, null, Vector2(10, 10))
	assert_false(enemy.is_dead(), "进入引爆范围首帧不立即爆（引信时间）")
	for i in 6:
		enemy.tick(0.2, 20.0, null, Vector2(10, 10))
	assert_true(enemy.is_dead(), "引信结束自爆并死亡")
	assert_eq(aoe.size(), 1, "自爆广播一次 AoE")
	assert_eq(aoe[0].radius, 90.0)
	assert_eq(aoe[0].damage, 30.0)

func test_armored_directional_armor_front_vs_back() -> void:
	var data := EnemyData.new()
	data.id = "enemy/armored"
	data.threat_mode = EnemyData.ThreatMode.ARMORED
	data.max_hp = 100.0
	data.armor = 0.0
	data.directional_armor = true
	data.frontal_armor = 0.5
	var front_enemy := EnemyController.new(data)
	front_enemy.facing_direction = Vector2.RIGHT
	var front_ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 100.0)
	var front_result := front_enemy.take_damage(front_ctx, 0, Vector2.RIGHT)
	assert_almost_eq(front_result.damage, 50.0, 0.001, "正面命中吃正面护甲 50% 减伤")

	var back_enemy := EnemyController.new(data)
	back_enemy.facing_direction = Vector2.RIGHT
	var back_ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 100.0)
	var back_result := back_enemy.take_damage(back_ctx, 0, Vector2.LEFT)
	assert_almost_eq(back_result.damage, 100.0, 0.001, "背向命中无护甲减伤")

func test_elite_weak_point_multiplier() -> void:
	var data := EnemyData.new()
	data.id = "enemy/elite_behemoth"
	data.threat_mode = EnemyData.ThreatMode.ELITE
	data.max_hp = 100.0
	data.has_weak_point = true
	data.weak_point_multiplier = 3.0
	var enemy := EnemyController.new(data)
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 10.0)
	var result := enemy.take_damage(ctx, 0, Vector2.ZERO, true)
	assert_almost_eq(result.damage, 30.0, 0.001, "弱点命中按数据倍率 3.0 增伤")

func test_flying_ignores_barricade_attacks_base() -> void:
	var data := EnemyData.new()
	data.id = "enemy/flying"
	data.threat_mode = EnemyData.ThreatMode.FLYING
	data.max_hp = 20.0
	data.attack_damage = 8.0
	data.attack_interval = 1.0
	data.attack_range = 60.0
	data.ignores_barricades = true
	var enemy := EnemyController.new(data)
	var barricade_data := DefenseFacilityData.new()
	barricade_data.max_durability = 100.0
	var barricade := BarricadeController.new(barricade_data, 1)
	var attacks: Array[EnemyAttackEvent] = []
	EventBus.subscribe(&"EnemyAttackEvent",
		func(e: EnemyAttackEvent) -> void: attacks.append(e))
	enemy.tick(1.1, 20.0, barricade)
	assert_eq(attacks.size(), 1, "飞行体近身攻击一次")
	assert_eq(attacks[0].target, EnemyAttackEvent.TARGET_BASE, "飞行体无视路障，直接打基地")
	assert_eq(enemy.attacking_barricade, null, "飞行体不记录路障目标")
