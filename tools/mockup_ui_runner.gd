extends Node
## 截图运行器（挂到 root，等若干帧后截图到目标路径并退出）
## 可选注入：_target（输出路径）、_setup（Callable，_ready 时执行构建）、
## _open（Callable，第 10 帧执行，用于树进入运行态后再调用面板 _on_open）、_wait_frames。

var _frames := 0
var _wait_frames := 24
var _target := ""
var _setup: Callable = Callable()
var _open: Callable = Callable()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _setup.is_valid():
		_setup.call()
	if _target.is_empty():
		push_error("mockup runner: empty target")
		get_tree().quit(1)
		return

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 10 and _open.is_valid():
		_open.call()
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
