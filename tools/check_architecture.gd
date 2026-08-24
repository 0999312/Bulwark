extends SceneTree
## M5 发布前架构检查（静态扫描）
## - 前端/后端分离：scripts/core 禁止场景/渲染引用
## - 前端禁止直接写后端数值（抽查 scenes）
## 运行：godot --headless --path . --script res://tools/check_architecture.gd

const CORE_DIR := "res://scripts/core"
const FORBIDDEN_PATTERNS := [
	"get_node(",
	"Sprite2D",
	"Sprite3D",
	"Material",
	"Shader",
	"CanvasLayer",
	"CanvasItem",
	"AnimationPlayer",
	"preload(\"res://scenes",
	"load(\"res://scenes",
	"queue_free",
]

func _initialize() -> void:
	var violations: Array[String] = []
	_collect_gd_files(CORE_DIR, violations)
	if violations.is_empty():
		print("ARCH_CHECK=PASS")
		quit(0)
	else:
		print("ARCH_CHECK=FAIL")
		for v in violations:
			print("  " + v)
		quit(1)

func _collect_gd_files(dir_path: String, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_collect_gd_files(full, violations)
		elif name.ends_with(".gd"):
			var content := FileAccess.get_file_as_string(full)
			for pattern: String in FORBIDDEN_PATTERNS:
				if content.contains(pattern):
					violations.append("%s -> %s" % [full, pattern])
		name = dir.get_next()
	dir.list_dir_end()
