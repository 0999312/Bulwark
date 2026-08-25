extends SceneTree
## 临时截图采证入口（P0/P1 视觉验证，不入正式交付）：
##   godot --path . -s tools/capture_arcade.gd -- --cap-size=1280x720
## 直接加载 main.tscn（单机 OFFLINE），挂载 capture_runner.gd 按帧截图到 user://captures/

func _initialize() -> void:
	var cap_size := "1280x720"
	var showcase := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cap-size="):
			cap_size = arg.trim_prefix("--cap-size=")
		elif arg == "--showcase":
			showcase = true
	if cap_size == "1920x1080":
		root.size = Vector2i(1920, 1080)
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(Vector2i(1920, 1080))
	var run_config: Node = root.get_node_or_null("RunConfig")
	if run_config != null:
		run_config.call("prepare_arcade")
	var game: PackedScene = load("res://scenes/world/main.tscn")
	root.add_child(game.instantiate())
	var runner: Node = load("res://tools/capture_runner.gd").new()
	runner.set("_cap_size", cap_size)
	runner.set("_showcase", showcase)
	root.add_child(runner)
