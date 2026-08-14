extends GutTest
## 奔跑者后端控制器测试：行为 FSM（Chase/Attack/Dead）+ 攻击事件 + 受击/死亡

var _attack_count := 0
var _died := false

func before_each() -> void:
	_attack_count = 0
	_died = false
	# 清理跨测试累积的事件订阅（GUT 复用同一测试实例，lambda 每次新建不会去重）
	EventBus.clear_all_listeners()

func _make_runner() -> RunnerController:
	var data := EnemyData.new()
	data.id = "enemy/runner"
	data.max_hp = 30.0
	data.move_speed = 185.0
	data.attack_damage = 8.0
	data.attack_interval = 1.0
	data.attack_range = 42.0
	return RunnerController.new(data)

func test_initial_chase_state() -> void:
	var runner := _make_runner()
	assert_eq(runner.state, RunnerController.State.CHASE)
	assert_eq(runner.health, 30.0)

func test_far_target_keeps_chase() -> void:
	var runner := _make_runner()
	runner.tick(0.016, 500.0)
	assert_eq(runner.state, RunnerController.State.CHASE)

func test_close_target_enters_attack_and_emits_event() -> void:
	var runner := _make_runner()
	EventBus.subscribe(&"EnemyAttackEvent",
		func(_e: EnemyAttackEvent) -> void: _attack_count += 1)
	# 进入攻击距离：首爪前有一个完整攻击间隔的反应时间（不再落地即咬）
	runner.tick(0.016, 30.0)
	assert_eq(runner.state, RunnerController.State.ATTACK)
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
	assert_eq(runner.state, RunnerController.State.ATTACK)
	runner.tick(0.016, 100.0)
	assert_eq(runner.state, RunnerController.State.CHASE)

func test_take_damage_through_pipeline_and_die() -> void:
	var runner := _make_runner()
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 12.0)
	var result := runner.take_damage(ctx)
	assert_almost_eq(result.damage, 12.0, 0.001)
	assert_almost_eq(runner.health, 18.0, 0.001)
	ctx.base_damage = 18.0
	runner.take_damage(ctx)
	assert_true(runner.is_dead())
	assert_eq(runner.state, RunnerController.State.DEAD)

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
	var runner := RunnerController.new(data)
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 40.0)
	ctx.defense = data.armor
	runner.take_damage(ctx)
	assert_almost_eq(runner.health, 70.0, 0.001, "防御减免 25%")
