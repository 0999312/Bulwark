extends GutTest
## M1 完整单局流程测试：6 波全流程（清场 → 波间商店 → 下一波 → … → 胜利结算）
## 验证"单局可玩"的核心链路：波次调度 × 商店开关 × 胜利判定全部贯通

var _session: GameSession

func before_each() -> void:
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(10)
	_session = main as GameSession
	assert_not_null(_session)

func after_each() -> void:
	get_tree().paused = false
	if _session != null and is_instance_valid(_session):
		_session.queue_free()
	_session = null
	await wait_process_frames(3)

## 模拟表现层：清空刷怪池 + 击杀簿记 + 移除真实敌人视图（快速推波）
## 注：_spawn_remaining 由 WaveDirector 内部簿记，测试直接清空以跳过流式节奏；
##     仅清簿记不够——残留敌人会继续打基地导致判负，必须同时移除敌人节点
func _clear_current_wave() -> void:
	var director := _session.wave_director
	director._spawn_remaining.clear()
	while director.pending_spawns > 0:
		director.register_enemy_spawned()
	while director.alive_enemies > 0:
		director.register_enemy_died()
	# 池空 + 无存活时 register 回调不再触发清场判定，需手动调用
	director._check_wave_cleared()
	for child in _session.enemies_root.get_children():
		if child is EnemyView:
			child.queue_free()

func test_full_run_six_waves_to_victory() -> void:
	var director := _session.wave_director
	var shop_opens := 0
	# 保险：测试推波期间真实敌人可能啃基地，加大耐久避免误判负
	_session.base_core.durability = 99999.0

	# 6 波循环
	for wave_idx in range(1, 7):
		# 等本波 ACTIVE（预警结束后刷怪）
		var guard := 0
		while director.phase != WaveDirector.Phase.ACTIVE and guard < 600:
			await wait_physics_frames(1)
			guard += 1
		assert_eq(director.phase, WaveDirector.Phase.ACTIVE, "第 %d 波应进入接敌" % wave_idx)
		assert_eq(director.current_wave_index, wave_idx - 1, "波次索引正确")

		# ACTIVE 后立即清场（清池 + 击杀簿记 + 移除真实敌人；不等流式刷完）
		_clear_current_wave()
		await wait_physics_frames(2)

		# 波间：前 5 波打开商店 + 暂停；末波直接进胜利（M4.1 决策：无需波间购买）
		if wave_idx < 6:
			guard = 0
			while not UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)) and guard < 120:
				await wait_process_frames(1)
				guard += 1
			assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)), "第 %d 波后商店打开" % wave_idx)
			shop_opens += 1
			assert_true(get_tree().paused, "商店期间暂停")
			# 买一个固定物资（路障组件）验证经济链路
			_session.run_state.add_credits(1000)
			_session.shop_system.try_purchase(
				Bulwark.loc(Bulwark.SHOP_BARRICADE).to_string(), _session._shop_effect_handler)
			assert_gt(_session.run_state.material, 0, "路障组件购买生效")
			_session.on_shop_closed()
			await wait_process_frames(3)
		else:
			# 末波清场后不应再弹商店，直接结算
			for i in 10:
				await wait_process_frames(1)
			assert_false(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)),
				"末波清场后不再打开波间商店（M4.1）")

	# 等待胜利结算（最后波清场 → INTERMISSION → 无下一波 → VICTORY）
	var guard := 0
	while director.phase != WaveDirector.Phase.VICTORY and guard < 400:
		await wait_process_frames(1)
		guard += 1
		if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
			_session.on_shop_closed()
	assert_eq(director.phase, WaveDirector.Phase.VICTORY, "6 波打完进入胜利")
	assert_gte(shop_opens, 5, "至少 5 次波间商店打开（第 1~5 波后必开）")
	await wait_process_frames(5)
	assert_true(_session._run_finished, "胜利结算已触发")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_RESULT)), "胜利面板打开")
