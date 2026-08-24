extends GutTest
## M3 问题 4：小队独立资源——每玩家 RunState/ShopSystem/配件背包独立；
## 击杀奖励归属击杀者（killer_id）；host 双人装配结构正确
## 说明：GameSession._exit_tree 已清理 GUIDE context（全局副作用有根因修复），
## 本测试可安全实例化 main.tscn 做双人装配验证

var _session: GameSession

func before_each() -> void:
	EventBus.clear_all_listeners()
	Net.mode = Net.Mode.HOST  # 模拟 host：双玩家装配（无网络层，发送路径安全跳过）
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(5)
	_session = main as GameSession
	assert_eq(_session.players.size(), 2, "host 装配双玩家")

func after_each() -> void:
	get_tree().paused = false
	if _session != null and is_instance_valid(_session):
		_session.queue_free()
	_session = null
	Net.mode = Net.Mode.OFFLINE
	await wait_process_frames(2)

func test_per_player_run_states_are_independent() -> void:
	assert_eq(_session.run_states.size(), 2, "每人独立 RunState")
	assert_eq(_session.shop_systems.size(), 2, "每人独立商店")
	assert_eq(_session.attachment_bags.size(), 2, "每人独立配件背包")
	assert_eq(_session.run_states[0].player_id, 0)
	assert_eq(_session.run_states[1].player_id, 1)
	assert_ne(_session.run_states[0], _session.run_states[1], "实例独立")
	assert_ne(_session.shop_systems[0], _session.shop_systems[1])
	assert_eq(_session.run_state, _session.run_states[0], "兼容别名 = 玩家 0")
	assert_eq(_session.shop_system, _session.shop_systems[0])
	# 初始资源各自注入
	assert_eq(_session.run_states[0].credits, GameSession.START_CREDITS)
	assert_eq(_session.run_states[1].credits, GameSession.START_CREDITS)

func test_kill_reward_goes_to_killer() -> void:
	var rs0 := _session.run_states[0]
	var rs1 := _session.run_states[1]
	var c0 := rs0.credits
	var c1 := rs1.credits
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	var reward := enemy_data.kill_reward if enemy_data != null else 0
	# 击杀者 = 玩家 1：奖励只进玩家 1
	_session._on_enemy_died(EnemyDiedEvent.new("bulwark:enemy/runner", Vector2.ZERO, 1))
	assert_eq(rs1.credits, c1 + reward, "击杀奖励归击杀者")
	assert_eq(rs0.credits, c0, "其他玩家不受影响")

func test_kill_reward_default_killer_zero() -> void:
	# 单机兼容：事件默认 killer_id = 0 → 奖励进玩家 0
	var c0 := _session.run_states[0].credits
	_session._on_enemy_died(EnemyDiedEvent.new("bulwark:enemy/runner", Vector2.ZERO))
	assert_gt(_session.run_states[0].credits, c0)

func test_shop_consumes_buyers_credits_and_bonus_per_player() -> void:
	# 固定伤害商品（SHOP_DAMAGE_UP）确保 modifier.attribute = damage
	var target := ContentBootstrap.get_entry(Bulwark.REG_SHOP_ITEM,
		Bulwark.loc(Bulwark.SHOP_DAMAGE_UP).to_string()) as ShopItemData
	assert_not_null(target, "伤害商品已注册")
	var price := 60
	_session.shop_systems[1].offers.append(ShopRefreshedEvent.Offer.new(target, price, 0, true))
	var credits_before := _session.run_states[1].credits
	assert_true(_session.shop_systems[1].try_purchase(
		Bulwark.loc(target.id).to_string(),
		func(it: ShopItemData) -> void: _session._shop_effect_handler(it, 1)))
	assert_eq(_session.run_states[1].credits, credits_before - price, "扣购买者货币")
	assert_eq(_session.run_states[0].credits, GameSession.START_CREDITS, "玩家 0 货币不动")
	assert_gt(_session.run_states[1].bonus.get_final(&"damage"), 0.0, "强化落购买者通道")

func test_barricade_uses_placers_material() -> void:
	var mat0 := _session.run_states[0].material
	var mat1 := _session.run_states[1].material
	_session.run_states[1].add_material(2)
	# M4 议题 5：放置位置外推 + 半径下限——把玩家 0 放到合法半径（180px 出生位）
	_session.player_views[0].global_position = _session.base_node.global_position + Vector2(0.0, 180.0)
	_session._try_place_barricade(0)  # 放置者 = 玩家 0
	assert_eq(_session.run_states[0].material, mat0 - 1, "玩家 0 建材 -1")
	assert_eq(_session.run_states[1].material, mat1 + 2, "玩家 1 建材不动")

## 击杀者捕获（成员变量：lambda 对局部变量是值捕获，修改无效——M2 测试纪律）
var _got_killer := -1

func test_enemy_controller_reports_killer_id() -> void:
	EventBus.clear_all_listeners()
	_got_killer = -1
	EventBus.subscribe(&"EnemyDiedEvent",
		func(e: Event) -> void: _got_killer = (e as EnemyDiedEvent).killer_id)
	var data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	var runner := EnemyController.new(data)
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, 9999.0)
	runner.take_damage(ctx, 1)
	assert_eq(_got_killer, 1, "伤害管道透传击杀者")

func test_run_state_player_id_field() -> void:
	assert_eq(RunState.new().player_id, 0, "默认 0 = 单机")
	assert_eq(RunState.new(1).player_id, 1)
	var e := RunStateChangedEvent.new(10, 1, 1, 2)
	assert_eq(e.player_id, 2, "资源事件携带 player_id")
