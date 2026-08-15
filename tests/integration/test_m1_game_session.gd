extends GutTest
## M1 集成测试：商店经济、路障防线、复活流程在主场景装配中的表现
## 依赖 GameSession 完整装配（RunState/ShopSystem/ReviveSystem/Barricade）

var _session: GameSession

func before_each() -> void:
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(10)
	_session = main as GameSession
	assert_not_null(_session, "main.tscn 根节点应为 GameSession")

func after_each() -> void:
	get_tree().paused = false
	if _session != null and is_instance_valid(_session):
		_session.queue_free()
	_session = null
	await wait_process_frames(3)

func test_initial_run_state_and_weapons() -> void:
	assert_eq(_session.run_state.credits, GameSession.START_CREDITS, "开局货币")
	assert_eq(_session.run_state.material, GameSession.START_MATERIAL, "开局建材")
	assert_eq(_session.run_state.reserve, GameSession.START_RESERVE, "开局应急储备")
	# 三槽完整：主步枪 / 副霰弹 / 手枪
	assert_true(_session.weapon_slots.is_slot_ready(WeaponSlots.SLOT_MAIN))
	assert_true(_session.weapon_slots.is_slot_ready(WeaponSlots.SLOT_SUB))
	assert_true(_session.weapon_slots.is_slot_ready(WeaponSlots.SLOT_PISTOL))
	assert_eq(_session.weapon_slots.get_slot(WeaponSlots.SLOT_SUB).type_data.slot,
		WeaponTypeData.SlotType.SUB, "副槽为霰弹枪")

func test_kill_rewards_credits() -> void:
	var credits_before: int = _session.run_state.credits
	var event := EnemyDiedEvent.new("bulwark:enemy/runner", Vector2.ZERO)
	_session._on_enemy_died(event)
	assert_gt(_session.run_state.credits, credits_before, "击杀获得货币奖励")

func test_shop_purchase_applies_weapon_bonus() -> void:
	# 直接走后端：手动注入武器向商品 → 购买 → WeaponStats 结算生效
	_session.shop_system.refresh(1)
	var target: ShopItemData = null
	for offer in _session.shop_system.offers:
		var item: ShopItemData = offer.item
		if item.category == ShopItemData.Category.STAT_WEAPON and item.modifier != null \
				and item.modifier.attribute == &"damage":
			target = item
			break
	if target == null:
		# 种子 1 未刷出伤害商品 → 手动上架（随机池商品都在 Registry）
		target = ContentBootstrap.get_entry(Bulwark.REG_SHOP_ITEM,
			Bulwark.loc(Bulwark.SHOP_DAMAGE_UP).to_string()) as ShopItemData
		assert_not_null(target, "伤害商品已注册")
		_session.shop_system.offers.append(ShopRefreshedEvent.Offer.new(target, 60, 0, true))
	var stats_before := _session.weapon_slots.get_effective_stats(_session.weapon_slots.get_current_slot())
	_session.run_state.add_credits(10000)
	assert_true(_session.shop_system.try_purchase(Bulwark.loc(target.id).to_string(),
		_session._shop_effect_handler), "购买伤害商品")
	var stats_after := _session.weapon_slots.get_effective_stats(_session.weapon_slots.get_current_slot())
	assert_almost_eq(stats_after.damage, stats_before.damage + 2.0, 0.001, "伤害 +2 生效")

func test_shop_move_speed_bonus_keeps_player_mobile() -> void:
	# 回归：STAT_PLAYER 乘法商品曾把 amount=0 传入乘法通道 → 移速终值 0（无法移动）
	_session.shop_system.refresh(2)
	var target := ContentBootstrap.get_entry(Bulwark.REG_SHOP_ITEM,
		Bulwark.loc(Bulwark.SHOP_MOVE_SPEED_UP).to_string()) as ShopItemData
	assert_not_null(target, "移速商品已注册")
	if not _session.shop_system.is_offered(Bulwark.loc(target.id).to_string()):
		_session.shop_system.offers.append(ShopRefreshedEvent.Offer.new(target, 100, 0, true))
	_session.run_state.add_credits(10000)
	assert_true(_session.shop_system.try_purchase(Bulwark.loc(target.id).to_string(),
		_session._shop_effect_handler), "购买移速商品")
	var speed := _session.player_controller.attribute_set.get_final(AttributeSet.MOVE_SPEED)
	assert_gt(speed, 260.0, "移速终值应高于基础值 260（乘法 1.06 生效且不为 0）")

func test_shop_ammo_crate_replenishes_bullets() -> void:
	# 弹药箱（固定物资）：波间恒上架，购买后子弹备弹 +30
	_session.shop_system.refresh(3)
	var crate_location := Bulwark.loc(Bulwark.SHOP_AMMO_CRATE).to_string()
	assert_true(_session.shop_system.is_offered(crate_location), "弹药箱固定上架")
	var reserve_before := _session.ammo_system.get_count(WeaponTypeData.AmmoType.BULLET)
	_session.run_state.add_credits(10000)
	assert_true(_session.shop_system.try_purchase(crate_location, _session._shop_effect_handler),
		"购买弹药箱")
	assert_eq(_session.ammo_system.get_count(WeaponTypeData.AmmoType.BULLET),
		reserve_before + 30, "备弹 +30")

func test_barricade_placement_consumes_material() -> void:
	var material_before: int = _session.run_state.material
	if material_before <= 0:
		_session.run_state.add_material(1)
		material_before = _session.run_state.material
	# 放置位置注入基地旁（headless 鼠标位置不可控）
	_session._try_place_barricade(_session.base_node.global_position)
	assert_eq(_session.run_state.material, material_before - 1, "放置消耗 1 建材")
	assert_eq(_session.barricades.size(), 1, "路障控制器已登记")

func test_barricade_out_of_radius_rejected() -> void:
	var material_before: int = _session.run_state.material
	_session._try_place_barricade(Vector2(5000, 5000))
	assert_eq(_session.run_state.material, material_before, "越界放置不消耗建材")
	assert_eq(_session.barricades.size(), 0, "越界不放置")

func test_enemy_attacks_barricade_instead_of_base() -> void:
	# 路障放在基地旁 → 敌人冲基地路上攻击路障，基地耐久不掉
	_session.run_state.add_material(5)
	_session._try_place_barricade(_session.base_node.global_position)
	assert_eq(_session.barricades.size(), 1)
	var base_durability: float = _session.base_core.durability

	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	var enemy: EnemyView = load("res://scenes/enemy/enemy.tscn").instantiate()
	_session.enemies_root.add_child(enemy)
	enemy.setup(enemy_data, _session.base_node, _session._get_barricade_views)
	enemy.global_position = _session.base_node.global_position + Vector2(120, 0)

	# 等敌人接近路障（路障在基地位置）
	for i in 300:
		await wait_physics_frames(1)
		if _session.barricades[0].durability < _session.barricades[0].max_durability:
			break
	assert_lt(_session.barricades[0].durability, _session.barricades[0].max_durability,
		"路障被敌人攻击")
	assert_almost_eq(_session.base_core.durability, base_durability, 0.001,
		"路障未被摧毁前基地耐久不掉")

func test_wave_cleared_opens_shop_and_resume_starts_next_wave() -> void:
	# 直接推流程：清场事件 → 商店面板打开 + 暂停 → 关闭 → 下一波
	_session.wave_director.phase = WaveDirector.Phase.INTERMISSION
	var cleared := WaveClearedEvent.new(1)
	_session._on_wave_cleared(cleared)
	await wait_process_frames(3)
	assert_true(get_tree().paused, "波间商店暂停")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)), "商店面板打开")

	_session.on_shop_closed()
	await wait_process_frames(3)
	assert_false(get_tree().paused, "关闭商店恢复")
	assert_false(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)), "商店面板关闭")
	assert_eq(_session.wave_director.phase, WaveDirector.Phase.WARNING, "下一波预警开始")
	assert_eq(_session.wave_director.current_wave_index, 1, "推进到第 2 波")

func test_player_fire_hits_enemy_with_stats() -> void:
	# 玩家射击命中链路：ShotFiredEvent → 表现层射线 → apply_player_hit(stats) → 敌人掉血
	# （回归防护：player_view 曾用 WeaponModelData 代理传参导致命中不结算，签名必须对齐）
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	var enemy: EnemyView = load("res://scenes/enemy/enemy.tscn").instantiate()
	_session.enemies_root.add_child(enemy)
	enemy.setup(enemy_data, _session.base_node)
	enemy.global_position = _session.player_node.global_position + Vector2(0, -100)
	var hp_before: float = enemy.controller.health

	# 模拟后端验证通过的射击事件（主武器向上）
	EventBus.publish(ShotFiredEvent.new(
		Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7).to_string(), Vector2.UP))
	await wait_physics_frames(2)
	assert_lt(enemy.controller.health, hp_before, "玩家射击应命中敌人并造成伤害")
	# 12dmg vs 12HP：暴击(24dmg)会直接击杀，正常命中则残血——两种都合法，不做死亡断言

func test_attachment_bag_purchase_and_equip() -> void:
	# 购买配件 → 背包 → 装配到主武器 → 数值生效
	_session.shop_system.refresh(3)
	var ext_mag_item := "bulwark:shop/item/ext_mag"
	if not _session.shop_system.is_offered(ext_mag_item):
		# 种子 3 未刷出则手动上架（构造 offers 注入）
		var item: ShopItemData = ContentBootstrap.get_entry(Bulwark.REG_SHOP_ITEM, ext_mag_item)
		_session.shop_system.offers.append(ShopRefreshedEvent.Offer.new(item, 100, 0, true))
	_session.run_state.add_credits(10000)
	assert_true(_session.shop_system.try_purchase(ext_mag_item,
		func(it: ShopItemData) -> void: _session.attachment_bag.append(it.attachment_location)),
		"购买扩容弹匣")
	assert_has(_session.attachment_bag, "bulwark:attachment/ext_mag", "配件入背包")

	var attachment: AttachmentData = ContentBootstrap.get_entry(
		Bulwark.REG_ATTACHMENT, "bulwark:attachment/ext_mag")
	assert_not_null(attachment, "配件数据已注册")
	assert_true(_session.weapon_slots.equip_attachment(WeaponSlots.SLOT_MAIN, attachment),
		"装配到主武器")
	var stats := _session.weapon_slots.get_effective_stats(_session.weapon_slots.get_slot(WeaponSlots.SLOT_MAIN))
	assert_eq(stats.mag_size, 45, "主武器弹匣 30 × 1.5 = 45")
