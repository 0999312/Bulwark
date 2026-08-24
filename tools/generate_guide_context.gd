@tool
## 生成 GUIDE 输入配置的工具脚本（M0）
## 运行方式: godot --headless --script tools/generate_guide_context.gd
##
## 生成内容：
## - input/actions/：process/clear/prev_device/next_device（设备操作，原工具行为）
##   + move/aim/shoot/switch_weapon/pause/reload/interact（战斗动作，需求单 §2 + M1）
## - input/contexts/equipment_context.tres（设备操作映射）
## - input/contexts/combat_context.tres（战斗映射：WASD 移动 / 鼠标瞄准 / 左键射击 / 1-2-3 切枪 / R 换弹 / E 互动 / Esc 暂停）
## 双客户端共用同一套键位（M2：键盘/鼠标输入属于有焦点的窗口，本机多窗口各自点击焦点即可）
extends SceneTree

const ACTION_DIR := "res://input/actions"
const CONTEXT_DIR := "res://input/contexts"

func _init() -> void:
	# ── 1. 设备操作动作（原工具保留） ──
	var process_action := _make_action(&"process_action", "处理", "设备操作",
		GUIDEAction.GUIDEActionValueType.BOOL)
	var clear_action := _make_action(&"clear_action", "清空", "设备操作",
		GUIDEAction.GUIDEActionValueType.BOOL)
	var prev_device_action := _make_action(&"prev_device_action", "上一个设备", "设备操作",
		GUIDEAction.GUIDEActionValueType.BOOL)
	var next_device_action := _make_action(&"next_device_action", "下一个设备", "设备操作",
		GUIDEAction.GUIDEActionValueType.BOOL)

	# ── 2. M0 战斗动作 ──
	# move：AXIS_2D，WASD 四键经 Scale 修正映射到方向（W=-Y，Godot 屏幕坐标）
	var move_action := _make_action(&"move", "移动", "战斗",
		GUIDEAction.GUIDEActionValueType.AXIS_2D, true)
	# aim：AXIS_2D，鼠标位置（P9 鼠标纯自由瞄准；不可重映射——瞄准由鼠标位置语义决定）
	var aim_action := _make_action(&"aim", "瞄准", "战斗",
		GUIDEAction.GUIDEActionValueType.AXIS_2D, false)
	# shoot：BOOL，鼠标左键（按下即持续触发，配合 Down 默认触发器实现连射）
	var shoot_action := _make_action(&"shoot", "射击", "战斗",
		GUIDEAction.GUIDEActionValueType.BOOL, true)
	# switch_weapon：BOOL，数字键 1/2/3（主/副/手枪；Pressed 触发器 = 边沿检测）
	var switch_action := _make_action(&"switch_weapon", "切换武器", "战斗",
		GUIDEAction.GUIDEActionValueType.BOOL, true)
	# pause：BOOL，Esc
	var pause_action := _make_action(&"pause", "暂停", "系统",
		GUIDEAction.GUIDEActionValueType.BOOL, true)
	# reload：BOOL，R（M0 手动换弹）
	var reload_action := _make_action(&"reload", "换弹", "战斗",
		GUIDEAction.GUIDEActionValueType.BOOL, true)
	# interact：BOOL，E（M1 互动/放置路障；Pressed 边沿触发）
	var interact_action := _make_action(&"interact", "互动", "战斗",
		GUIDEAction.GUIDEActionValueType.BOOL, true)
	# cycle_facility：BOOL，F（M5b 设施切换；Pressed 边沿触发）
	var cycle_facility_action := _make_action(&"cycle_facility", "切换设施", "战斗",
		GUIDEAction.GUIDEActionValueType.BOOL, true)

	# ── 3. 保存动作资源 ──
	_save_action(process_action, "process_action")
	_save_action(clear_action, "clear_action")
	_save_action(prev_device_action, "prev_device_action")
	_save_action(next_device_action, "next_device_action")
	_save_action(move_action, "move")
	_save_action(aim_action, "aim")
	_save_action(shoot_action, "shoot")
	_save_action(switch_action, "switch_weapon")
	_save_action(pause_action, "pause")
	_save_action(reload_action, "reload")
	_save_action(interact_action, "interact")
	_save_action(cycle_facility_action, "cycle_facility")

	# ── 4. 设备操作上下文（原工具行为：P/C/Q/E） ──
	var equipment_context := GUIDEMappingContext.new()
	equipment_context.display_name = "设备操作"
	equipment_context.mappings = [
		_key_mapping(process_action, KEY_P, true),
		_key_mapping(clear_action, KEY_C, true),
		_key_mapping(prev_device_action, KEY_Q, true),
		_key_mapping(next_device_action, KEY_E, true),
	]
	_save_context(equipment_context, "equipment_context")

	# ── 5. 战斗上下文（M0；M4.2 修订：同动作多键合并为单 mapping 多 input_mapping，
	#    这样 GUIDE remapping 的 (context, action, index) 才能唯一寻址每个按键） ──
	var combat_context := GUIDEMappingContext.new()
	combat_context.display_name = "战斗"
	combat_context.mappings = [
		# 移动：WASD → 方向向量（Down 默认触发器：按住持续触发）
		_multi_key_mapping(move_action,
			[KEY_W, KEY_S, KEY_A, KEY_D], false,
			[Vector3(0, -1, 0), Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(1, 0, 0)]),
		# 瞄准：鼠标位置（自由瞄准，P9）
		_mouse_position_mapping(aim_action),
		# 射击：左键按住连射
		_mouse_button_mapping(shoot_action, MOUSE_BUTTON_LEFT),
		# 切换武器：1/2/3（Pressed = 边沿触发）
		_multi_key_mapping(switch_action,
			[KEY_1, KEY_2, KEY_3], true,
			[Vector3.ONE, Vector3.ONE, Vector3.ONE]),
		# 暂停：Esc
		_key_mapping(pause_action, KEY_ESCAPE, true),
		# 换弹：R（边沿触发）
		_key_mapping(reload_action, KEY_R, true),
		# 互动/放置：E（边沿触发）
		_key_mapping(interact_action, KEY_E, true),
		# 切换设施：F（M5b，边沿触发）
		_key_mapping(cycle_facility_action, KEY_F, true),
	]
	_save_context(combat_context, "combat_context")

	print("GUIDE 输入配置生成完成：actions ×12, contexts ×2")
	quit(0)

# ─── 构造辅助 ───

func _make_action(action_name: StringName, display: String, category: String, value_type: int,
		remappable: bool = false) -> GUIDEAction:
	var action := GUIDEAction.new()
	action.name = action_name
	action.display_name = display
	action.display_category = category
	action.action_value_type = value_type
	action.is_remappable = remappable
	return action

func _save_action(action: GUIDEAction, file_name: String) -> void:
	var err := ResourceSaver.save(action, "%s/%s.tres" % [ACTION_DIR, file_name])
	if err != OK:
		push_error("保存动作失败 %s: %d" % [file_name, err])

func _save_context(context: GUIDEMappingContext, file_name: String) -> void:
	var err := ResourceSaver.save(context, "%s/%s.tres" % [CONTEXT_DIR, file_name])
	if err != OK:
		push_error("保存上下文失败 %s: %d" % [file_name, err])

## 按键映射；pressed=true 用 Pressed 触发器（边沿），否则用默认 Down（按住持续）
## swizzle 修饰器（order=0）为 M0 关键修复：GUIDE 键盘输入恒为 Vector3(1,0,0)，
## Y 轴键（W/S）需先 swizzle（X→Y）再 scale 定向；X 轴键（A/D）只 scale。
## 若 X 轴键误加 swizzle，输出会被 scale 归零（见 test_frontend_wiring 回归）
func _key_mapping(action: GUIDEAction, key: Key, pressed: bool, scale := Vector3.ONE) -> GUIDEActionMapping:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var input_mapping := GUIDEInputMapping.new()
	var input := GUIDEInputKey.new()
	input.key = key
	input_mapping.input = input
	var modifiers: Array[GUIDEModifier] = []
	if scale != Vector3.ONE:
		if scale.y != 0.0:
			var swizzle := GUIDEModifierInputSwizzle.new()
			swizzle.order = 0
			modifiers.append(swizzle)
		var modifier := GUIDEModifierScale.new()
		modifier.scale = scale
		modifiers.append(modifier)
		input_mapping.modifiers = modifiers
	if pressed:
		input_mapping.triggers = [GUIDETriggerPressed.new()]
	mapping.input_mappings = [input_mapping]
	return mapping

## 多键映射（M4.2）：同一动作的多个按键合入一个 GUIDEActionMapping，
## input_mappings 的 index 即键位序号——GUIDERemapper 以 (context, action, index) 寻址，
## 拆成多个 mapping 会导致 index 全为 0、键位设置互相覆盖。
func _multi_key_mapping(action: GUIDEAction, keys: Array, pressed: bool,
		scales: Array) -> GUIDEActionMapping:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var input_mappings: Array[GUIDEInputMapping] = []
	for i in keys.size():
		var input_mapping := GUIDEInputMapping.new()
		var input := GUIDEInputKey.new()
		input.key = keys[i]
		input_mapping.input = input
		var scale: Vector3 = scales[i] if i < scales.size() else Vector3.ONE
		var modifiers: Array[GUIDEModifier] = []
		if scale != Vector3.ONE:
			if scale.y != 0.0:
				var swizzle := GUIDEModifierInputSwizzle.new()
				swizzle.order = 0
				modifiers.append(swizzle)
			var modifier := GUIDEModifierScale.new()
			modifier.scale = scale
			modifiers.append(modifier)
			input_mapping.modifiers = modifiers
		if pressed:
			input_mapping.triggers = [GUIDETriggerPressed.new()]
		input_mappings.append(input_mapping)
	mapping.input_mappings = input_mappings
	return mapping

## 鼠标位置映射（自由瞄准）
func _mouse_position_mapping(action: GUIDEAction) -> GUIDEActionMapping:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var input_mapping := GUIDEInputMapping.new()
	input_mapping.input = GUIDEInputMousePosition.new()
	mapping.input_mappings = [input_mapping]
	return mapping

## 鼠标按键映射（按住持续触发 → 连射）
func _mouse_button_mapping(action: GUIDEAction, button: MouseButton) -> GUIDEActionMapping:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var input_mapping := GUIDEInputMapping.new()
	var input := GUIDEInputMouseButton.new()
	input.button = button
	input_mapping.input = input
	mapping.input_mappings = [input_mapping]
	return mapping
