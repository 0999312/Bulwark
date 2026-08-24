extends GutTest
## M3 问题 2：全队同意暂停——单方请求不冻结、全员请求才冻结、任一取消即恢复；
## host 双人请求集合语义；波间商店期间树由商店托管
## 说明：GameSession._exit_tree 已清理 GUIDE context，实例化 main.tscn 无全局残留

var _session: GameSession

func before_each() -> void:
	EventBus.clear_all_listeners()
	Net.mode = Net.Mode.HOST  # 模拟 host 双人（无网络层，ui_state 广播安全跳过）
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(5)
	_session = main as GameSession
	assert_eq(_session.players.size(), 2, "host 装配双玩家")

func after_each() -> void:
	get_tree().paused = false
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_PAUSE))
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_RESULT)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_RESULT))
	if _session != null and is_instance_valid(_session):
		_session.queue_free()
	_session = null
	Net.mode = Net.Mode.OFFLINE
	await wait_process_frames(2)

func test_single_request_does_not_freeze() -> void:
	_session._toggle_pause(0)
	assert_false(get_tree().paused, "仅一名玩家请求不冻结树")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)), "请求者本地面板打开")
	assert_true(_session._pause_requests.get(0, false), "请求集合记录玩家 0")
	assert_false(_session._pause_requests.get(1, false))

func test_all_requests_freeze() -> void:
	_session._toggle_pause(0)
	_session._toggle_pause(1)
	assert_true(get_tree().paused, "全员请求 → 冻结")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)))

func test_cancel_resumes() -> void:
	_session._toggle_pause(0)
	_session._toggle_pause(1)
	assert_true(get_tree().paused)
	_session._toggle_pause(1)  # 玩家 1 取消
	assert_false(get_tree().paused, "任一取消 → 恢复")
	assert_false(_session._pause_requests.get(1, false))

func test_pause_state_payload_includes_requests() -> void:
	_session._toggle_pause(0)
	var payload := _session._ui_state_payload()
	var requests: Array = payload.get(NetCodec.KEY_PAUSE_REQUESTS, [])
	assert_eq(requests, [0], "ui_state 携带请求集合")

func test_remote_request_does_not_open_local_panel() -> void:
	# 远端玩家请求：本地面板只随本地玩家（_local_player_id）请求状态开关
	_session._toggle_pause(1)
	assert_false(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)), "远端请求不弹本地面板")
	assert_false(get_tree().paused, "单方请求不冻结")
	assert_true(_session._pause_requests.get(1, false))

func test_shop_open_keeps_tree_paused_despite_no_requests() -> void:
	# 波间商店：打开商店（树暂停）后暂停请求全部取消也不解除（商店托管）
	_session._toggle_pause(0)
	_session._toggle_pause(0)  # 取消
	assert_false(get_tree().paused)
	# M4.1：末波直通胜利；本测试模拟“非末波”清场（waves 2 个且 wave_index=1 < total）
	ContentBootstrap.register_all()
	var wave_reg: WaveRegistry = RegistryManager.get_registry(Bulwark.REG_WAVE)
	var wave: WaveData = wave_reg.get_entry(Bulwark.loc(Bulwark.WAVE_1))
	assert_not_null(wave)
	_session.wave_director.waves = [wave, wave]
	_session.wave_director.phase = WaveDirector.Phase.INTERMISSION
	_session._on_wave_cleared(WaveClearedEvent.new(1))
	await wait_process_frames(2)
	assert_true(get_tree().paused, "商店打开树暂停")
	assert_true(UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)))
	_session.on_shop_closed()
	await wait_process_frames(2)
	assert_false(get_tree().paused, "商店关闭恢复")
