extends GutTest
## M2 复活无敌帧（PlayerController）：复活后 2s 免疫伤害，期间不触发再次阵亡

var player: PlayerController
var slots: WeaponSlots
var ammo: AmmoSystem
var run_state: RunState
var _died_count := 0

func before_each() -> void:
	ammo = AmmoSystem.new()
	run_state = RunState.new()
	slots = WeaponSlots.new(ammo, run_state)
	var attrs := AttributeSet.new()
	attrs.set_base(AttributeSet.MAX_HEALTH, 100.0)
	player = PlayerController.new(attrs, slots)
	_died_count = 0
	EventBus.clear_all_listeners()
	EventBus.subscribe(&"PlayerDiedEvent", func(_e: Event) -> void: _died_count += 1)

func _kill() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 9999.0)
	player.take_damage(ctx)

func test_revive_grants_invincibility() -> void:
	_kill()
	assert_true(player.is_dead(), "先阵亡")
	player.revive()
	assert_false(player.is_dead(), "复活成功")
	assert_gt(player.get_invincible_time(), 0.0, "复活后进入无敌帧")
	_kill()
	assert_false(player.is_dead(), "无敌帧内伤害被免疫")
	assert_eq(_died_count, 1, "不触发第二次阵亡事件")
	assert_eq(player.health, player.max_health, "满血未被扣")

func test_invincibility_expires_after_duration() -> void:
	_kill()
	player.revive()
	player.tick(PlayerController.INVINCIBLE_DURATION + 0.1)
	assert_eq(player.get_invincible_time(), 0.0, "无敌帧到期归零")
	_kill()
	assert_true(player.is_dead(), "过期后伤害正常生效")
	assert_eq(_died_count, 2, "触发第二次阵亡事件")

func test_invincibility_does_not_block_healing() -> void:
	_kill()
	player.revive()
	player.heal(10.0)  # 满血时治疗无效果但不应报错
	assert_eq(player.health, player.max_health)

func test_normal_damage_without_revive_unchanged() -> void:
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 30.0)
	player.take_damage(ctx)
	assert_eq(player.health, 70.0, "未复活时正常掉血")
	assert_eq(player.get_invincible_time(), 0.0, "无无敌帧")
