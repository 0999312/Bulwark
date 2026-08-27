extends Node
## M0 mockup 截图运行器（挂到 root，等若干帧后截图到目标路径并退出）
## 由 tools/mockup_ui.gd 创建并注入 _target。

var _frames := 0
var _wait_frames := 24
var _target := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _target.is_empty():
		push_error("mockup runner: empty target")
		get_tree().quit(1)
		return

func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= _wait_frames:
		var viewport := get_viewport()
		var tex := viewport.get_texture()
		if tex == null:
			push_error("mockup: viewport texture null")
			get_tree().quit(1)
			return
		var img := tex.get_image()
		if img == null:
			push_error("mockup: get_image null")
			get_tree().quit(1)
			return
		var err := img.save_png(_target)
		print("M0_MOCKUP_SAVE=%s err=%d size=%s" % [_target, err, viewport.size])
		get_tree().quit(0)
