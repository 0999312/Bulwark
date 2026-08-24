extends SceneTree
## M5d 三分辨率 UI 冒烟：在 headless 下依次实例化主要 UI 场景，检查无脚本错误。
## 分辨率覆盖 1280×720 / 1920×1080 / 21:9 (3440×1440)。

const UI_SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/pause_panel.tscn",
	"res://scenes/ui/result_panel.tscn",
	"res://scenes/ui/shop_panel.tscn",
]

const SIZES := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(3440, 1440),
]

func _initialize() -> void:
	for size in SIZES:
		root.content_scale_size = size
		for scene_path in UI_SCENES:
			var packed := load(scene_path) as PackedScene
			if packed == null:
				print("RES_CHECK=FAIL missing ", scene_path)
				quit(1)
				return
			var inst := packed.instantiate()
			root.add_child(inst)
			# 只做实例化冒烟；下一帧前移除
			root.remove_child(inst)
			inst.queue_free()
	print("RES_CHECK=PASS")
	quit(0)
