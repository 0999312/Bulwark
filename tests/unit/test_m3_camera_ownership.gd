extends GutTest
## M3 问题 1：摄像机归属——LOCAL 启用并 make_current，REMOTE/NONE 禁用
## （Camera2D「最后 enabled 者成为当前相机」：远端镜像视图相机必须禁用）
## 说明：GameSession._exit_tree 已清理 GUIDE context，实例化 main.tscn 无全局残留

var _session: GameSession

func before_each() -> void:
	EventBus.clear_all_listeners()
	Net.mode = Net.Mode.HOST  # 模拟 host 双人（镜头归属正是双人装配场景）
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(5)
	_session = main as GameSession

func after_each() -> void:
	get_tree().paused = false
	if _session != null and is_instance_valid(_session):
		_session.queue_free()
	_session = null
	Net.mode = Net.Mode.OFFLINE
	await wait_process_frames(2)

func test_local_camera_enabled_and_current() -> void:
	assert_eq(_session.players.size(), 2, "host 双玩家")
	var local: PlayerView = _session.player_views[0]
	assert_eq(local.role, PlayerView.Role.LOCAL)
	assert_true(local.camera.enabled, "本地玩家相机启用")
	assert_true(local.camera.is_current(), "本地玩家相机为当前相机")

func test_remote_camera_disabled() -> void:
	var remote: PlayerView = _session.player_views[1]
	assert_eq(remote.role, PlayerView.Role.REMOTE)
	assert_false(remote.camera.enabled, "远端镜像视图相机禁用（不抢镜头）")

func test_role_switch_toggles_camera() -> void:
	# 角色切换时相机归属跟随（无残留启用状态）
	var view := _session.player_views[1]
	view.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SNAPSHOT)
	assert_true(view.camera.enabled, "切为 LOCAL 后相机启用")
	view.set_role(PlayerView.Role.NONE, PlayerView.PositionMode.SNAPSHOT)
	assert_false(view.camera.enabled, "切为 NONE 后相机禁用")
