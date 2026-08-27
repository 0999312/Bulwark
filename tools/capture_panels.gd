extends SceneTree
## UI 面板截图采证（M1/M3/M5）：直接实例化设置/商店/结算面板并注入最小数据
##   godot --path . --rendering-method gl_compatibility -s res://tools/capture_panels.gd -- --panel=settings --cap-size=1280x720 --tag=before
##   --panel=settings|shop|result；输出 docs/review/evidence/m1_<tag>_<panel>_<cap-size>.png
## 注意：-s 模式 _initialize 期间树尚未运行，面板构建/_on_open 必须放到 runner._ready 的
## _setup Callable 中执行（否则 @onready 尚未解析）；顶层不得静态引用游戏 class_name/autoload。

var _panel_mode := "settings"
var _cap_size := "1280x720"
var _tag := "before"
var _panel_ref: Control = null
var _open_args: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--panel="):
			_panel_mode = arg.trim_prefix("--panel=")
		elif arg.begins_with("--cap-size="):
			_cap_size = arg.trim_prefix("--cap-size=")
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
	var parts := _cap_size.split("x")
	var vs := Vector2i(int(parts[0]), int(parts[1]))
	if vs.x > 1280:
		root.size = vs
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(vs)

	# 运行时注册内容（autoload 已就绪后加载，避免编译期依赖）
	var cb_script: GDScript = load("res://scripts/systems/content_bootstrap.gd")
	cb_script.call("register_all")

	var evidence_dir := ProjectSettings.globalize_path("res://docs/review/evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var target := "%s/m1_%s_%s_%s.png" % [evidence_dir, _tag, _panel_mode, _cap_size]
	var runner: Node = load("res://tools/mockup_ui_runner.gd").new()
	runner.set("_target", target)
	runner.set("_wait_frames", 40)
	runner.set("_setup", Callable(self, "_build_panel").bind(_panel_mode))
	runner.set("_open", Callable(self, "_open_panel"))
	root.add_child(runner)

func _build_panel(panel_mode: String) -> void:
	match panel_mode:
		"settings":
			_panel_ref = _instantiate("res://scenes/ui/settings_panel.tscn")
			root.call_deferred("add_child", _panel_ref)
		"shop":
			_build_shop_panel()
		"result":
			_build_result_panel()
		_:
			push_error("capture_panels: unknown panel %s" % panel_mode)
			quit(1)

func _open_panel() -> void:
	if _panel_ref != null:
		_panel_ref.call("_on_open", _open_args)

func _instantiate(path: String) -> Control:
	var packed: PackedScene = load(path)
	return packed.instantiate()

func _build_shop_panel() -> void:
	var run_state_script: GDScript = load("res://scripts/core/economy/run_state.gd")
	var shop_script: GDScript = load("res://scripts/core/economy/shop_system.gd")
	var ammo_script: GDScript = load("res://scripts/core/combat/ammo_system.gd")
	var slots_script: GDScript = load("res://scripts/core/combat/weapon_slots.gd")
	var arsenal_script: GDScript = load("res://scripts/core/combat/arsenal.gd")
	var event_script: GDScript = load("res://scripts/core/events/shop_refreshed_event.gd")

	var rs: Variant = run_state_script.new(0)
	rs.call("add_credits", 9999)
	var shop: Variant = shop_script.new(rs)

	# 直接从注册表取上架商品（绕开 setup 的 Array[ShopItemData] 类型绑定；offers 为无类型 Array）
	var items: Array = []
	var reg_mgr: Node = root.get_node_or_null("RegistryManager")
	if reg_mgr != null:
		var reg: Variant = reg_mgr.call("get_registry", "shop_item")
		if reg != null:
			for entry: Variant in reg.call("get_all_entries").values():
				items.append(entry)
	var offer_cls: GDScript = event_script.get("Offer")
	var offers: Array = []
	for i in mini(8, items.size()):
		var item: Variant = items[i]
		var price := int(item.call("price_with_rarity"))
		var offer: Variant = offer_cls.new(item, price, 0, true)
		offers.append(offer)
	shop.offers = offers

	var ammo: Variant = ammo_script.new()
	var slots: Variant = slots_script.new(ammo, rs, 0)
	var arsenal_models: Array[String] = ["bulwark:weapon/model/ar_1", "bulwark:weapon/model/sg_1"]
	var arsenal: Variant = arsenal_script.new(arsenal_models)

	var panel := _instantiate("res://scenes/ui/shop_panel.tscn")
	root.call_deferred("add_child", panel)
	_panel_ref = panel
	_open_args = {
		"shop": shop,
		"weapon_slots": slots,
		"run_state": rs,
		"bag": [] as Array[String],
		"arsenal": arsenal,
	}

func _build_result_panel() -> void:
	var panel := _instantiate("res://scenes/ui/result_panel.tscn")
	root.call_deferred("add_child", panel)
	_panel_ref = panel
	_open_args = {
		"victory": true,
		"stats": {
			"wave": 16,
			"kills": 123,
			"credits": 3200,
			"material": 12,
			"score": 12345,
			"combo": 7,
			"time": 418.5,
			"meta_gain": 12,
			"highscore_rank": 1,
			"highscores": [
				{"score": 12345, "combo": 7, "time": 418.5},
				{"score": 10001, "combo": 6, "time": 402.0},
				{"score": 8765, "combo": 5, "time": 390.2},
			],
		},
	}
