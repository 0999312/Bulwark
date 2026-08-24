extends GutTest
## 主场景端到端测试：实例化 main.tscn，走真实输入路径验证暂停/结算/重启
## 等待用 wait_process_frames（基于 process_frame 信号，树暂停时仍会发出）

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

func _send_key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _toggle_pause() -> void:
	_send_key(KEY_ESCAPE, true)
	await wait_process_frames(2)
	_send_key(KEY_ESCAPE, false)
	await wait_process_frames(2)

func _spawn_enemy_near_base() -> EnemyView:
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	var enemy: EnemyView = load("res://scenes/enemy/enemy.tscn").instantiate()
	_session.enemies_root.add_child(enemy)
	enemy.setup(enemy_data, _session.base_node)
	enemy.global_position = _session.base_node.global_position + Vector2(50, 0)
	return enemy

func test_escape_opens_pause_panel_and_resumes() -> void:
	_send_key(KEY_ESCAPE, true)
	await wait_process_frames(2)
	_send_key(KEY_ESCAPE, false)
	await wait_process_frames(2)
	assert_true(get_tree().paused, "按 Esc 后树应暂停")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)), "暂停面板应打开")

	# 再次 Esc 恢复
	_send_key(KEY_ESCAPE, true)
	await wait_process_frames(2)
	_send_key(KEY_ESCAPE, false)
	await wait_process_frames(2)
	assert_false(get_tree().paused, "再次按 Esc 应恢复运行")
	assert_false(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)), "恢复后暂停面板应关闭")

func test_wave_starts_after_warning() -> void:
	# 波次警告事件应广播（HUD 依赖），且预警后刷怪
	var spawned := [0]
	EventBus.subscribe(&"SpawnRequestEvent", func(_e): spawned[0] += 1)
	# 预警 4 秒（wave_1）+ 物理帧 60Hz → 最多等 320 物理帧
	for i in 320:
		await wait_physics_frames(1)
		if spawned[0] > 0:
			break
	assert_true(spawned[0] > 0, "预警结束后应发出刷怪请求")

func test_base_destroyed_opens_result_panel() -> void:
	_session.base_core.take_damage(9999.0)
	await wait_process_frames(3)
	assert_true(_session._run_finished, "基地摧毁后本局应结束")
	assert_true(get_tree().paused, "基地摧毁后树应暂停")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_RESULT)), "结算面板应打开")

func test_restart_after_defeat_reloads_scene() -> void:
	_session.base_core.take_damage(9999.0)
	await wait_process_frames(3)
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_RESULT)), "结算面板应打开")

	# 模拟重启按钮流程：关闭面板 + 恢复运行 + 场景替换
	# （GUT 环境无 current_scene，reload_current_scene 无法使用，手动执行等价步骤）
	var panel: UIPanel = UIManager.get_top_panel(UILayer.POPUP)
	assert_not_null(panel, "POPUP 层应有结算面板")
	if panel == null:
		return
	UIManager.close_panel(panel.panel_id)
	get_tree().paused = false
	_session.queue_free()
	_session = null
	await wait_process_frames(3)

	# 新局（等价于 reload_current_scene 后的场景）
	var new_main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child_autofree(new_main)
	await wait_process_frames(10)
	var new_session := new_main as GameSession
	assert_not_null(new_session, "重启后应有新 GameSession")
	if new_session == null:
		return
	_session = new_session
	assert_false(new_session._run_finished, "新局不应处于结束状态")
	assert_false(get_tree().paused, "重启后树应恢复运行")

	# 新局应正常刷怪：EventBus 中旧场景的失效监听器必须被清理，
	# 否则 null callable 报错会中断事件派发（场景重载后无法重启的根因）
	var spawned := [0]
	EventBus.subscribe(&"SpawnRequestEvent", func(_e): spawned[0] += 1)
	for i in 320:
		await wait_physics_frames(1)
		if spawned[0] > 0:
			break
	assert_true(spawned[0] > 0, "新局应正常发出刷怪请求（事件总线无残留失效监听器）")

func test_pause_freezes_player_movement() -> void:
	_send_key(KEY_W, true)
	await wait_physics_frames(20)
	var pos_before := _session.player_node.global_position
	assert_true(pos_before.y < 180.0, "按住 W 玩家应向上移动")

	await _toggle_pause()
	assert_true(get_tree().paused, "树应暂停")
	var pos_paused := _session.player_node.global_position
	await wait_process_frames(40)
	assert_eq(_session.player_node.global_position, pos_paused, "暂停期间玩家不应移动")

	await _toggle_pause()
	assert_false(get_tree().paused, "树应恢复")
	await wait_physics_frames(10)
	assert_true(_session.player_node.global_position.y < pos_paused.y, "恢复后玩家应继续向上移动")
	_send_key(KEY_W, false)
	await wait_process_frames(2)

func test_pause_freezes_enemies_and_base() -> void:
	var enemy := _spawn_enemy_near_base()
	# 等敌人进入攻击并出第一爪（首爪延迟 + 攻击间隔 ≈ 2.5s → 160 物理帧）
	for i in 180:
		await wait_physics_frames(1)
		if _session.base_core.durability < _session.base_core.max_durability:
			break
	assert_true(_session.base_core.durability < _session.base_core.max_durability, "敌人应已开始攻击基地")

	await _toggle_pause()
	assert_true(get_tree().paused, "树应暂停")
	var dur_paused := _session.base_core.durability
	var enemy_pos := enemy.global_position
	await wait_process_frames(40)
	assert_almost_eq(_session.base_core.durability, dur_paused, 0.001, "暂停期间基地不应掉耐久")
	assert_eq(enemy.global_position, enemy_pos, "暂停期间敌人不应移动")

	await _toggle_pause()
	assert_false(get_tree().paused, "树应恢复")
	for i in 120:
		await wait_physics_frames(1)
		if _session.base_core.durability < dur_paused:
			break
	assert_true(_session.base_core.durability < dur_paused, "恢复后敌人应继续攻击基地")

func test_enemy_rams_player_deals_damage_and_dies() -> void:
	# 敌人从玩家下方冲向基地，路径穿过玩家 → 撞击：玩家掉血 + 敌人自爆
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	var enemy: EnemyView = load("res://scenes/enemy/enemy.tscn").instantiate()
	_session.enemies_root.add_child(enemy)
	enemy.setup(enemy_data, _session.base_node)
	enemy.global_position = Vector2(0, 300)  # 玩家在 (0,180)，基地在 (0,0)
	var hp_before: float = _session.player_controller.health

	for i in 150:
		await wait_physics_frames(1)
		if _session.player_controller.health < hp_before:
			break
	assert_true(_session.player_controller.health < hp_before, "敌人撞击应对玩家造成伤害")
	assert_true(enemy.controller.is_dead(), "撞击后敌人应自爆")

func test_player_death_starts_revive_not_fail() -> void:
	# M1 复活系统（P7/P20）：初始储备 2 → 阵亡进入复活 CD，不直接失败
	assert_gt(_session.run_state.reserve, 0, "开局有应急储备")
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 9999.0)
	_session.player_controller.take_damage(ctx)
	await wait_process_frames(3)
	assert_false(_session._run_finished, "储备充足时阵亡不判负")
	assert_true(_session.revive_system.is_reviving(), "进入复活 CD")
	assert_true(_session.player_controller.is_dead(), "复活中玩家保持死亡状态")
	# 复活 CD 结束 → 复活回基地
	for i in 400:
		await wait_physics_frames(1)
		if not _session.revive_system.is_reviving():
			break
	assert_false(_session.revive_system.is_reviving(), "复活 CD 应结束")
	assert_false(_session.player_controller.is_dead(), "复活后玩家复活")
	assert_almost_eq(_session.player_controller.health,
		_session.player_controller.max_health, 0.001, "复活回满血")
	assert_lt(_session.run_state.reserve, 2, "复活消耗 1 储备")

func test_player_death_without_reserve_ends_run() -> void:
	# 初始储备 2：两次阵亡各消耗 1（复活后再次阵亡），储备耗尽第三次阵亡判负
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 9999.0)
	_session.player_controller.take_damage(ctx)
	await wait_process_frames(3)
	# 第一次：进入复活
	assert_false(_session._run_finished, "第一次阵亡进入复活")
	for i in 400:
		await wait_physics_frames(1)
		if not _session.revive_system.is_reviving():
			break
	assert_eq(_session.run_state.reserve, 1, "第一次复活消耗 1 储备")
	# 复活附带 2s 无敌帧（M2 修复：防敌人守尸秒杀）——等无敌结束再阵亡，否则伤害被免疫
	for i in 300:
		await wait_physics_frames(1)
		if _session.player_controller.get_invincible_time() <= 0.0:
			break
	# 第二次阵亡 → 储备 1 → 再复活
	var ctx2 := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 9999.0)
	_session.player_controller.take_damage(ctx2)
	await wait_process_frames(3)
	assert_false(_session._run_finished, "第二次阵亡仍可复活")
	for i in 400:
		await wait_physics_frames(1)
		if not _session.revive_system.is_reviving():
			break
	assert_eq(_session.run_state.reserve, 0, "两次复活耗尽储备")
	# 第二次复活同样带 2s 无敌帧，等结束再阵亡
	for i in 300:
		await wait_physics_frames(1)
		if _session.player_controller.get_invincible_time() <= 0.0:
			break
	# 第三次阵亡 → 储备 0 → 失败
	var ctx3 := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 9999.0)
	_session.player_controller.take_damage(ctx3)
	await wait_process_frames(3)
	assert_true(_session._run_finished, "储备耗尽后阵亡判负")
	assert_true(get_tree().paused, "失败后树暂停")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_RESULT)), "失败打开结算面板")

func test_spawn_positions_vary_on_ring() -> void:
	# 圆环随机刷新：同一方位多只出怪，位置应随机散布（非固定标记点）
	for i in 10:
		_session._on_spawn_request(SpawnRequestEvent.new(0, 1, "bulwark:enemy/runner"))
	await wait_process_frames(2)
	var positions: Array[Vector2] = []
	for child in _session.enemies_root.get_children():
		if child is EnemyView:
			positions.append((child as EnemyView).global_position)
	assert_eq(positions.size(), 10, "10 只敌人应全部实例化")
	var min_dist := INF
	var max_dist := 0.0
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			var d := positions[i].distance_to(positions[j])
			min_dist = minf(min_dist, d)
			max_dist = maxf(max_dist, d)
	assert_true(min_dist > 5.0, "任意两只不应重叠在同一落点")
	assert_true(max_dist > 100.0, "刷怪位置应沿圆环随机散布（非固定点）")
