extends Node
## M4.1 键位设置（autoload）：基于 GUIDE 的 remapping API + JSON 持久化
## - 启动时初始化 GUIDERemapper（combat/equipment 两个 context）→ 应用持久化绑定到 GUIDE
## - UI（设置面板）经 get_items() 拿可重映射项，start_detection() 监听按键后写回
## - 冲突策略：新键与既有绑定冲突时，自动清掉冲突项（简单直接，面板即时刷新）
## - 持久化：user://input_bindings.json，只保存与默认不同的绑定（含“故意未绑定”）

const CONTEXT_PATHS: Array[String] = [
	"res://input/contexts/combat_context.tres",
	"res://input/contexts/equipment_context.tres",
]
const BINDINGS_PATH := "user://input_bindings.json"

signal bindings_changed

var _contexts: Array[GUIDEMappingContext] = []
var _remapper := GUIDERemapper.new()
var _detector: GUIDEInputDetector
var _detecting_item: Variant = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in CONTEXT_PATHS:
		var context := load(path) as GUIDEMappingContext
		if context != null:
			_contexts.append(context)
	_remapper.initialize(_contexts, GUIDERemappingConfig.new())
	_load_bindings()
	_apply_to_guide()

# ─── 查询 / 重置 ───

func get_items() -> Array:
	return _remapper.get_remappable_items()

func is_detecting() -> bool:
	return _detector != null and is_instance_valid(_detector) and _detector.is_detecting

func abort_detection() -> void:
	if _detector != null and is_instance_valid(_detector) and _detector.is_detecting:
		_detector.abort_detection()

func reset_all_bindings() -> void:
	for item in get_items():
		_remapper.restore_default_for(item)
	_apply_to_guide()

func reset_item(item) -> void:
	_remapper.restore_default_for(item)
	_apply_to_guide()

func get_bound_label(item) -> String:
	var input = _remapper.get_bound_input_or_null(item)
	if input == null:
		return tr("settings.key.unbound")
	if input is GUIDEInputKey:
		var parts: Array[String] = []
		if input.control:
			parts.append("Ctrl")
		if input.shift:
			parts.append("Shift")
		if input.alt:
			parts.append("Alt")
		if input.meta:
			parts.append("Meta")
		parts.append(OS.get_keycode_string(input.key))
		return "+".join(parts)
	if input is GUIDEInputMouseButton:
		match int(input.button):
			MOUSE_BUTTON_LEFT:
				return tr("settings.key.mouse_left")
			MOUSE_BUTTON_RIGHT:
				return tr("settings.key.mouse_right")
			MOUSE_BUTTON_MIDDLE:
				return tr("settings.key.mouse_middle")
			_:
				return "M%d" % int(input.button)
	if input is GUIDEInputJoyButton:
		return "Joy %d · B%d" % [int(input.joy_index) + 1, int(input.button)]
	return "?"

# ─── 按键监听 ───

## 开始检测：移动只允许键盘（轴映射），射击允许键盘+鼠标，其余键位仅键盘
func start_detection(item) -> void:
	if is_detecting():
		abort_detection()
		_cleanup_detector()
	_detector = GUIDEInputDetector.new()
	_detector.detection_countdown_seconds = 0.2
	var esc := GUIDEInputKey.new()
	esc.key = KEY_ESCAPE
	var abort_inputs: Array[GUIDEInput] = [esc]
	_detector.abort_detection_on = abort_inputs
	add_child(_detector)
	_detecting_item = item
	_detector.input_detected.connect(_on_input_detected.bind(item))
	var action_name := StringName(str(item.action.name))
	if action_name == &"move" or action_name == &"switch_weapon" \
			or action_name == &"pause" or action_name == &"reload" \
			or action_name == &"interact" \
			or action_name == &"cycle_facility":
		_detector.detect_bool([GUIDEInputDetector.DeviceType.KEYBOARD])
	else:
		_detector.detect_bool([
			GUIDEInputDetector.DeviceType.KEYBOARD,
			GUIDEInputDetector.DeviceType.MOUSE,
		])

func _on_input_detected(item, input) -> void:
	if _detecting_item != item:
		return
	_detecting_item = null
	if input != null:
		# 冲突处理：先清掉所有与新键冲突的旧绑定，再写入新键
		for collision in _remapper.get_input_collisions(item, input):
			_remapper.set_bound_input(collision, null)
		_remapper.set_bound_input(item, input)
	_apply_to_guide()
	_cleanup_detector()

func _cleanup_detector() -> void:
	if _detector != null:
		if is_instance_valid(_detector):
			_detector.queue_free()
		_detector = null
	_detecting_item = null

# ─── 持久化 ───

func _apply_to_guide() -> void:
	GUIDE.set_remapping_config(_remapper.get_mapping_config())
	_save_bindings()
	bindings_changed.emit()

func _save_bindings() -> void:
	var entries: Array = []
	for item in get_items():
		var current = _remapper.get_bound_input_or_null(item)
		var default_input = _remapper.get_default_input(item)
		var differs := false
		if current == null and default_input != null:
			differs = true
		elif current != null and default_input == null:
			differs = true
		elif current != null and default_input != null \
				and not current.is_same_as(default_input):
			differs = true
		if not differs:
			continue
		entries.append({
			"context": item.context.resource_path,
			"action": str(item.action.name),
			"index": int(item.index),
			"input": _serialize_input(current),
		})
	var file := FileAccess.open(BINDINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("InputSettings: 无法写入 %s" % BINDINGS_PATH)
		return
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()

func _load_bindings() -> void:
	var file := FileAccess.open(BINDINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not (data is Array):
		return
	for entry in data:
		if not (entry is Dictionary):
			continue
		var item = _find_item(
			str(entry.get("context", "")),
			str(entry.get("action", "")),
			int(entry.get("index", 0)))
		if item == null:
			continue
		_remapper.set_bound_input(item, _deserialize_input(entry.get("input", null)))

func _find_item(context_path: String, action_name: String, index: int):
	for item in get_items():
		if item.context.resource_path == context_path \
				and str(item.action.name) == action_name \
				and int(item.index) == index:
			return item
	return null

func _serialize_input(input) -> Dictionary:
	if input == null:
		return {}
	if input is GUIDEInputKey:
		return {
			"type": "key",
			"key": int(input.key),
			"shift": bool(input.shift),
			"control": bool(input.control),
			"alt": bool(input.alt),
			"meta": bool(input.meta),
			"allow_additional_modifiers": bool(input.allow_additional_modifiers),
		}
	if input is GUIDEInputMouseButton:
		return {"type": "mouse", "button": int(input.button)}
	if input is GUIDEInputJoyButton:
		return {"type": "joy", "button": int(input.button), "joy_index": int(input.joy_index)}
	return {}

func _deserialize_input(data):
	if not (data is Dictionary):
		return null
	match str(data.get("type", "")):
		"key":
			var key := GUIDEInputKey.new()
			key.key = int(data.get("key", KEY_NONE))
			key.shift = bool(data.get("shift", false))
			key.control = bool(data.get("control", false))
			key.alt = bool(data.get("alt", false))
			key.meta = bool(data.get("meta", false))
			key.allow_additional_modifiers = bool(data.get("allow_additional_modifiers", true))
			return key
		"mouse":
			var mouse := GUIDEInputMouseButton.new()
			mouse.button = int(data.get("button", MOUSE_BUTTON_LEFT))
			return mouse
		"joy":
			var joy := GUIDEInputJoyButton.new()
			joy.button = int(data.get("button", 0))
			joy.joy_index = int(data.get("joy_index", -1))
			return joy
	return null
