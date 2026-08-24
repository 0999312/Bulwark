extends GutTest
## M3 修复回归：client 镜像反馈——
## ① 镜像敌人命中闪白（mirror 模式纯表现，伤害仍由 host 权威裁决）
## ② 镜像路障 location 匹配 host（damaged/destroyed 事件过滤依赖 location#id 一致，
##    不匹配会导致路障不闪白、被击穿后仍显示）

var _session: GameSession

func before_each() -> void:
	EventBus.clear_all_listeners()
	Net.mode = Net.Mode.HOST  # 复用 host 装配（镜像逻辑与 Net 模式无关，仅需完整场景）
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(5)
	_session = main as GameSession
	assert_not_null(_session, "main.tscn 根节点应为 GameSession")

func after_each() -> void:
	get_tree().paused = false
	if _session != null and is_instance_valid(_session):
		_session.queue_free()
	_session = null
	Net.mode = Net.Mode.OFFLINE
	await wait_process_frames(2)

func test_mirror_enemy_flashes_on_host_hit_event() -> void:
	# M3 方案 B：host 命中敌人 → EVT_ENEMY_HIT 中继 → client 镜像闪白
	ContentBootstrap.register_all()
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	assert_not_null(enemy_data)
	var enemy: EnemyView = (load("res://scenes/enemy/enemy.tscn") as PackedScene).instantiate() as EnemyView
	_session.enemies_root.add_child(enemy)
	enemy.setup_mirror(enemy_data)
	enemy.net_id = 7
	_session._mirror_enemies[7] = enemy
	_session._on_net_event(NetCodec.EVT_ENEMY_HIT, {NetCodec.KEY_ENEMY_ID: 7})
	assert_eq(enemy.body.self_modulate, EnemyView.HIT_FLASH_COLOR, "host 命中事件驱动镜像闪白（M4：Body 为 Sprite2D，闪白走 self_modulate）")
	assert_eq(enemy.controller, null, "镜像不结算伤害（host 权威）")

func test_mirror_barricade_location_matches_host_and_destroys() -> void:
	var location := "bulwark:facility/barricade#3"
	_session._apply_barricade_placed({
		NetCodec.KEY_LOCATION: location,
		NetCodec.KEY_POS: [100.0, 0.0],
	})
	var found: BarricadeView = null
	for child in _session.get_parent().get_children():
		if child is BarricadeView:
			found = child
			break
	assert_not_null(found, "镜像路障已创建")
	if found == null:
		return
	assert_eq(found.get_location(), location, "镜像路障 location 匹配 host（事件过滤可用）")
	# 受击事件应命中（location 匹配 → 闪白开始）
	EventBus.publish(BarricadeDamagedEvent.new(location, 50.0, 100.0))
	assert_ne(found.visual.self_modulate, Color.WHITE, "受击后路障闪白")
	# 销毁事件 → 路障应淡出移除
	EventBus.publish(BarricadeDestroyedEvent.new(location))
	await wait_process_frames(30)  # 淡出 tween 0.15s + 余量
	assert_false(is_instance_valid(found), "销毁事件后镜像路障移除")

func test_mirror_turret_placed_damaged_and_destroyed() -> void:
	var location := "bulwark:facility/turret#5"
	_session._apply_turret_placed({
		NetCodec.KEY_LOCATION: location,
		NetCodec.KEY_POS: [-80.0, 40.0],
	})
	var found: TurretView = null
	for child in _session.get_children():
		if child is TurretView:
			found = child
			break
	assert_not_null(found, "镜像炮塔已创建（主机放置 → 客户端可见）")
	if found == null:
		return
	assert_eq(found.get_location(), location, "镜像炮塔 location 匹配 host")
	assert_almost_eq(found.global_position.x, -80.0, 0.001, "镜像炮塔位置与 host 一致")
	EventBus.publish(BarricadeDamagedEvent.new(location, 70.0, 120.0))
	assert_ne(found.sprite.self_modulate, Color.WHITE, "受击后炮塔闪白")
	EventBus.publish(BarricadeDestroyedEvent.new(location))
	await wait_process_frames(30)
	assert_false(is_instance_valid(found), "销毁事件后镜像炮塔移除")
