extends GutTest
## 前端接线集成测试：验证 UIManager 面板开合与 GUIDE 输入链（headless 可复现）
## 输入走真实引擎路径：Input.parse_input_event → viewport tracker → GUIDE 注入 → 帧循环
## 背景：暂停/结算面板不出现、W/S 移动失效、射击、切枪等前端问题无法在纯后端单测中暴露

func before_all() -> void:
	ContentBootstrap.register_all()

func test_pause_panel_opens_and_closes() -> void:
	var panel_id := Bulwark.loc(Bulwark.UI_PAUSE)
	var panel: UIPanel = UIManager.open_panel(panel_id)
	assert_not_null(panel, "暂停面板应能打开")
	if panel != null:
		assert_true(UIManager.is_panel_open(panel_id), "打开后面板应登记为活跃")
		UIManager.close_panel(panel_id)
		assert_false(UIManager.is_panel_open(panel_id), "关闭后面板应移除活跃登记")

func test_result_panel_opens_and_closes() -> void:
	var panel_id := Bulwark.loc(Bulwark.UI_RESULT)
	var panel: UIPanel = UIManager.open_panel(panel_id, {"victory": false})
	assert_not_null(panel, "结算面板应能打开")
	if panel != null:
		assert_true(UIManager.is_panel_open(panel_id), "打开后结算面板应登记为活跃")
		UIManager.close_panel(panel_id)
		assert_false(UIManager.is_panel_open(panel_id), "关闭后结算面板应移除活跃登记")

# ─── GUIDE 输入链（真实帧循环 + parse_input_event） ───

func _enable_combat_context() -> GUIDEMappingContext:
	var combat_context: GUIDEMappingContext = load("res://input/contexts/combat_context.tres")
	GUIDE.enable_mapping_context(combat_context, true, 0)
	return combat_context

func _get_action(context: GUIDEMappingContext, action_name: StringName) -> GUIDEAction:
	for mapping: GUIDEActionMapping in context.mappings:
		if mapping.action != null and mapping.action.name == action_name:
			return mapping.action
	return null

func _send_key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _send_mouse_button(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)

func test_guide_pause_action_fires_on_escape_press() -> void:
	var context := _enable_combat_context()
	var pause_action := _get_action(context, &"pause")
	assert_not_null(pause_action, "combat_context 应包含 pause 动作")
	if pause_action == null:
		return
	assert_false(pause_action.is_triggered(), "初始 pause 不应触发")

	_send_key(KEY_ESCAPE, true)
	await wait_process_frames(1)
	assert_true(pause_action.is_triggered(), "按下 Esc 后 pause 应触发（GameSession 轮询依赖此状态）")

	_send_key(KEY_ESCAPE, false)
	await wait_process_frames(2)
	_send_key(KEY_ESCAPE, true)
	await wait_process_frames(1)
	assert_true(pause_action.is_triggered(), "松开再按 Esc 应再次触发")
	_send_key(KEY_ESCAPE, false)
	await wait_process_frames(2)

func test_guide_move_action_y_axis() -> void:
	var context := _enable_combat_context()
	var move_action := _get_action(context, &"move")
	assert_not_null(move_action, "combat_context 应包含 move 动作")
	if move_action == null:
		return

	_send_key(KEY_W, true)
	await wait_frames(2)
	assert_almost_eq(move_action.value_axis_2d.y, -1.0, 0.001, "按住 W 时 move 的 y 应为 -1（向上）")
	assert_almost_eq(move_action.value_axis_2d.x, 0.0, 0.001, "按住 W 时 move 的 x 应为 0")
	_send_key(KEY_W, false)
	await wait_frames(2)

	_send_key(KEY_S, true)
	await wait_frames(2)
	assert_almost_eq(move_action.value_axis_2d.y, 1.0, 0.001, "按住 S 时 move 的 y 应为 +1（向下）")
	_send_key(KEY_S, false)
	await wait_frames(2)

	_send_key(KEY_A, true)
	await wait_frames(2)
	assert_almost_eq(move_action.value_axis_2d.x, -1.0, 0.001, "按住 A 时 move 的 x 应为 -1（向左）")
	_send_key(KEY_A, false)
	await wait_frames(2)

	_send_key(KEY_D, true)
	await wait_frames(2)
	assert_almost_eq(move_action.value_axis_2d.x, 1.0, 0.001, "按住 D 时 move 的 x 应为 +1（向右）")
	_send_key(KEY_D, false)
	await wait_frames(2)

func test_guide_shoot_action_fires_on_mouse_hold() -> void:
	var context := _enable_combat_context()
	var shoot_action := _get_action(context, &"shoot")
	assert_not_null(shoot_action, "combat_context 应包含 shoot 动作")
	if shoot_action == null:
		return

	_send_mouse_button(MOUSE_BUTTON_LEFT, true)
	await wait_frames(2)
	assert_true(shoot_action.is_triggered(), "按住左键时 shoot 应触发（持续射击依赖此状态）")

	await wait_frames(2)
	assert_true(shoot_action.is_triggered(), "按住左键期间 shoot 应持续触发")

	_send_mouse_button(MOUSE_BUTTON_LEFT, false)
	await wait_frames(2)
	assert_false(shoot_action.is_triggered(), "松开左键后 shoot 应停止触发")

func test_guide_switch_weapon_fires_on_number_key() -> void:
	var context := _enable_combat_context()
	var switch_action := _get_action(context, &"switch_weapon")
	assert_not_null(switch_action, "combat_context 应包含 switch_weapon 动作")
	if switch_action == null:
		return

	_send_key(KEY_1, true)
	await wait_process_frames(1)
	assert_true(switch_action.is_triggered(), "按下 1 时 switch_weapon 应触发")
	_send_key(KEY_1, false)
	await wait_process_frames(2)

	_send_key(KEY_3, true)
	await wait_process_frames(1)
	assert_true(switch_action.is_triggered(), "按下 3 时 switch_weapon 应触发")
	_send_key(KEY_3, false)
	await wait_process_frames(2)

func test_guide_reload_action_fires_on_r_key() -> void:
	var context := _enable_combat_context()
	var reload_action := _get_action(context, &"reload")
	assert_not_null(reload_action, "combat_context 应包含 reload 动作")
	if reload_action == null:
		return

	_send_key(KEY_R, true)
	await wait_process_frames(1)
	assert_true(reload_action.is_triggered(), "按下 R 时 reload 应触发")
	_send_key(KEY_R, false)
	await wait_process_frames(2)
	assert_false(reload_action.is_triggered(), "松开 R 后 reload 应停止触发")
