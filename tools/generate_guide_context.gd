@tool
## 生成设备操作 GUIDE 映射上下文的工具脚本
## 运行方式: godot --headless --script tools/generate_guide_context.gd
extends SceneTree

func _init() -> void:
	# 加载已创建的 Action 资源
	var process_action: GUIDEAction = load("res://input/actions/process_action.tres")
	var clear_action: GUIDEAction = load("res://input/actions/clear_action.tres")
	var prev_device_action: GUIDEAction = load("res://input/actions/prev_device_action.tres")
	var next_device_action: GUIDEAction = load("res://input/actions/next_device_action.tres")

	if process_action == null or clear_action == null or prev_device_action == null or next_device_action == null:
		push_error("无法加载 Action 资源")
		quit(1)
		return

	# 创建映射上下文
	var context := GUIDEMappingContext.new()
	context.display_name = "设备操作"

	# 加工动作: P 键
	var process_mapping := GUIDEActionMapping.new()
	process_mapping.action = process_action
	var process_input := GUIDEInputKey.new()
	process_input.key = KEY_P
	var process_input_mapping := GUIDEInputMapping.new()
	process_input_mapping.input = process_input
	var process_trigger := GUIDETriggerPressed.new()
	process_input_mapping.triggers = [process_trigger]
	process_mapping.input_mappings = [process_input_mapping]

	# 清空动作: C 键
	var clear_mapping := GUIDEActionMapping.new()
	clear_mapping.action = clear_action
	var clear_input := GUIDEInputKey.new()
	clear_input.key = KEY_C
	var clear_input_mapping := GUIDEInputMapping.new()
	clear_input_mapping.input = clear_input
	var clear_trigger := GUIDETriggerPressed.new()
	clear_input_mapping.triggers = [clear_trigger]
	clear_mapping.input_mappings = [clear_input_mapping]

	# 上一个设备: Q 键
	var prev_mapping := GUIDEActionMapping.new()
	prev_mapping.action = prev_device_action
	var prev_input := GUIDEInputKey.new()
	prev_input.key = KEY_Q
	var prev_input_mapping := GUIDEInputMapping.new()
	prev_input_mapping.input = prev_input
	var prev_trigger := GUIDETriggerPressed.new()
	prev_input_mapping.triggers = [prev_trigger]
	prev_mapping.input_mappings = [prev_input_mapping]

	# 下一个设备: E 键
	var next_mapping := GUIDEActionMapping.new()
	next_mapping.action = next_device_action
	var next_input := GUIDEInputKey.new()
	next_input.key = KEY_E
	var next_input_mapping := GUIDEInputMapping.new()
	next_input_mapping.input = next_input
	var next_trigger := GUIDETriggerPressed.new()
	next_input_mapping.triggers = [next_trigger]
	next_mapping.input_mappings = [next_input_mapping]

	context.mappings = [process_mapping, clear_mapping, prev_mapping, next_mapping]

	# 保存
	var err := ResourceSaver.save(context, "res://input/contexts/equipment_context.tres")
	if err == OK:
		print("equipment_context.tres 生成成功")
	else:
		push_error("保存失败: %d" % err)

	quit(0)
