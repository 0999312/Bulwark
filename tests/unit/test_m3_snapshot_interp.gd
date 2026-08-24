extends GutTest
## M3 问题 3：快照渲染插值——SNAPSHOT 玩家与 mirror 敌人向快照目标平滑收敛
## （消除 20Hz 跳变；回归防护：mirror 插值不得被 controller==null 短路）

func before_each() -> void:
	EventBus.clear_all_listeners()

func _make_player() -> PlayerView:
	var view: PlayerView = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(view)
	var ammo := AmmoSystem.new()
	var slots := WeaponSlots.new(ammo, RunState.new())
	var attrs := AttributeSet.new()
	attrs.set_base(AttributeSet.MAX_HEALTH, 100.0)
	attrs.set_base(AttributeSet.MOVE_SPEED, 260.0)
	var pc := PlayerController.new(attrs, slots)
	view.setup(pc, {})
	return view

func test_player_snapshot_position_interpolates() -> void:
	var view := _make_player()
	view.set_role(PlayerView.Role.NONE, PlayerView.PositionMode.SNAPSHOT)
	view.global_position = Vector2.ZERO
	view.apply_snapshot(Vector2(100.0, 0.0), 0.0)
	assert_almost_eq(view.global_position.x, 100.0, 0.001, "首帧快照直接置位（防漂移）")
	# 第二帧快照起走双缓冲线性插值：渲染位置从 prev(100) 匀速推进到 target(200)
	view.apply_snapshot(Vector2(200.0, 0.0), 0.0)
	await wait_physics_frames(1)
	assert_gt(view.global_position.x, 100.0, "渲染位置开始向新快照目标推进")
	assert_lt(view.global_position.x, 200.0, "插值而非瞬移")
	# 持续推进到目标
	for i in 120:
		await wait_physics_frames(1)
	assert_almost_eq(view.global_position.x, 200.0, 1.0, "最终到达快照目标")

func test_player_aim_set_immediately() -> void:
	var view := _make_player()
	view.set_role(PlayerView.Role.NONE, PlayerView.PositionMode.SNAPSHOT)
	view.apply_snapshot(Vector2.ZERO, 1.5708)
	assert_almost_eq(view.visual.rotation, 1.5708, 0.001, "朝向即时置位（M4：Aim 并入 Visual）")

func test_enemy_mirror_position_interpolates() -> void:
	ContentBootstrap.register_all()
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, "bulwark:enemy/runner")
	assert_not_null(enemy_data)
	var enemy: EnemyView = (load("res://scenes/enemy/enemy.tscn") as PackedScene).instantiate()
	add_child_autofree(enemy)
	enemy.setup_mirror(enemy_data)
	enemy.global_position = Vector2.ZERO
	enemy.apply_snapshot(Vector2(50.0, 0.0))
	assert_almost_eq(enemy.global_position.x, 50.0, 0.001, "mirror 首帧直接置位")
	enemy.apply_snapshot(Vector2(100.0, 0.0))
	await wait_physics_frames(1)
	assert_gt(enemy.global_position.x, 50.0, "mirror 敌人位置推进（controller==null 不得短路）")
	assert_lt(enemy.global_position.x, 100.0)
	for i in 120:
		await wait_physics_frames(1)
	assert_almost_eq(enemy.global_position.x, 100.0, 1.0, "镜像敌人到达快照目标")

func test_snapshot_first_frame_teleports_no_slide() -> void:
	# 首帧快照直接置位（不插值滑入）：防止新镜像从初始点"漂移"到目标
	var view := _make_player()
	view.set_role(PlayerView.Role.NONE, PlayerView.PositionMode.SNAPSHOT)
	view.global_position = Vector2(-500.0, 0.0)
	view.apply_snapshot(Vector2(80.0, 0.0), 0.0)
	assert_almost_eq(view.global_position.x, 80.0, 0.001, "首帧快照直接置位")
	# 第二次快照起进入插值（渲染位置从 80 推进到 120，不跳变）
	view.apply_snapshot(Vector2(120.0, 0.0), 0.0)
	assert_almost_eq(view.global_position.x, 80.0, 0.001, "快照到达瞬间渲染位置仍在上一点（连续）")
	await wait_physics_frames(1)
	assert_gt(view.global_position.x, 80.0, "后续快照走插值")
	assert_lt(view.global_position.x, 120.0)

# ─── M3 本地预测（方向 B）：SIMULATED 本地模拟 + 快照校正 ───

func test_prediction_correction_small_delta_kept() -> void:
	# 偏差 ≤ 阈值：视为预测领先（输入即时生效的手感），不拉回
	var view := _make_player()
	view.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SIMULATED)
	view.global_position = Vector2(100.0, 0.0)
	view.apply_prediction_correction(Vector2(130.0, 0.0))
	assert_almost_eq(view.global_position.x, 100.0, 0.001, "小偏差保持本地模拟位置")

func test_prediction_correction_large_delta_pulls_back() -> void:
	# 偏差 > 阈值（host 权威差异：碰撞/路障/复活）：向权威位置平滑收敛
	var view := _make_player()
	view.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SIMULATED)
	view.global_position = Vector2(100.0, 0.0)
	view.apply_prediction_correction(Vector2(300.0, 0.0))
	assert_almost_eq(view.global_position.x, 200.0, 0.001, "每次快照向权威位置收敛 50%")

func test_prediction_correction_ignored_in_snapshot_mode() -> void:
	# 校正只作用于 SIMULATED 本地玩家；SNAPSHOT 镜像由插值管
	var view := _make_player()
	view.set_role(PlayerView.Role.NONE, PlayerView.PositionMode.SNAPSHOT)
	view.global_position = Vector2(100.0, 0.0)
	view.apply_prediction_correction(Vector2(300.0, 0.0))
	assert_almost_eq(view.global_position.x, 100.0, 0.001, "SNAPSHOT 模式不响应校正")
