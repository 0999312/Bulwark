extends SceneTree
## M0 视觉 mockup 临时采证入口（非 headless）：
##   godot --path . --rendering-method gl_compatibility -s res://tools/mockup_ui.gd -- --scene=menu --cap-size=1280x720
##   --scene=menu|hud|world；输出 docs/review/evidence/m0_mockup_<scene>_<cap-size>.png
## 说明：本工具仅用于 M0 人工拍板，不进入游戏运行时；内部 new StyleBoxFlat 仅此处一次性构建 mockup。

const ICONS := {
	"settings": "res://assets/icons/ui/settings.svg",
	"shop": "res://assets/icons/ui/shop.svg",
	"ranking": "res://assets/icons/ui/ranking.svg",
	"trophy": "res://assets/icons/ui/trophy.svg",
	"star": "res://assets/icons/feedback/star.svg",
	"book": "res://assets/icons/ui/book.svg",
	"users": "res://assets/icons/user/user_group.svg",
	"arrow_right": "res://assets/icons/arrow/arrow_right.svg",
	"refresh": "res://assets/icons/ui/refresh.svg",
	"cross": "res://assets/icons/feedback/cross.svg",
	"lock": "res://assets/icons/ui/lock.svg",
	"puzzle": "res://assets/icons/ui/puzzle.svg",
	"skull": "res://assets/icons/user/skull.svg",
	"yuan": "res://assets/icons/misc/yuan_yen.svg",
}

const COL_BG_DEEP := Color(0.024, 0.033, 0.047)
const COL_BG_PANEL := Color(0.045, 0.06, 0.082)
const COL_BG_RAISED := Color(0.075, 0.099, 0.131)
const COL_BG_INSET := Color(0.032, 0.043, 0.06)
const COL_BORDER := Color(0.25, 0.33, 0.44, 0.85)
const COL_BORDER_STRONG := Color(0.42, 0.53, 0.67)
const COL_ACCENT := Color(0.96, 0.74, 0.28)
const COL_ACCENT_BRIGHT := Color(1.0, 0.85, 0.47)
const COL_ACCENT_DIM := Color(0.96, 0.74, 0.28, 0.18)
const COL_TEXT := Color(0.93, 0.95, 0.97)
const COL_TEXT_SECONDARY := Color(0.62, 0.68, 0.75)
const COL_SUCCESS := Color(0.32, 0.75, 0.55)
const COL_DANGER := Color(0.93, 0.36, 0.33)
const COL_INFO := Color(0.44, 0.72, 0.95)
const COL_OLIVE := Color(0.45, 0.51, 0.30)
const COL_HAZARD := Color(0.93, 0.62, 0.12)

var _scene := "menu"
var _vs := Vector2i(1280, 720)

func _initialize() -> void:
	var cap_size := "1280x720"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene = arg.trim_prefix("--scene=")
		elif arg.begins_with("--cap-size="):
			cap_size = arg.trim_prefix("--cap-size=")
	var parts := cap_size.split("x")
	_vs = Vector2i(int(parts[0]), int(parts[1]))
	if _vs.x > 1280:
		root.size = _vs
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(_vs)
	var evidence_dir := ProjectSettings.globalize_path("res://docs/review/evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var target := "%s/m0_mockup_%s_%s.png" % [evidence_dir, _scene, cap_size]
	var mock: Node = null
	match _scene:
		"menu":
			mock = _build_menu()
		"hud":
			mock = _build_hud()
		"world":
			mock = _build_world()
		_:
			push_error("M0 mockup: unknown scene %s" % _scene)
			quit(1)
			return
	root.add_child(mock)
	var runner: Node = load("res://tools/mockup_ui_runner.gd").new()
	runner.set("_target", target)
	root.add_child(runner)

# ──────────────────────────────────────────────
# 通用构建辅助
# ──────────────────────────────────────────────

func _tex(path: String) -> Texture2D:
	return load(path)

func _style(bg: Color, border: Color, border_w: int = 1, radius: int = 4, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_top = border_w
	s.border_width_right = border_w
	s.border_width_bottom = border_w
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_right = radius
	s.corner_radius_bottom_left = radius
	s.content_margin_left = 14.0
	s.content_margin_top = 10.0
	s.content_margin_right = 14.0
	s.content_margin_bottom = 10.0
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = shadow
	return s

func _stripes_texture() -> ImageTexture:
	# 16x16 透明底 + 45° 斜条纹（低透明警示色）
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for x in 16:
		for y in 16:
			if (x + y) % 8 < 4:
				img.set_pixel(x, y, Color(COL_HAZARD.r, COL_HAZARD.g, COL_HAZARD.b, 0.28))
	return ImageTexture.create_from_image(img)

func _filled_texture(color: Color, w: int = 8, h: int = 8) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	for x in range(0, w, 4):
		img.set_pixel(x, 0, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0))
		img.set_pixel(x, h - 1, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0))
	return ImageTexture.create_from_image(img)

func _label(text: String, size: int, color: Color, align: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

func _icon(path: String, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex(path)
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _btn(text: String, icon_path: String) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = _tex(icon_path) if icon_path != "" else null
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", _style(COL_BG_RAISED, COL_BORDER))
	b.add_theme_stylebox_override("hover", _style(Color(0.10, 0.13, 0.17), COL_ACCENT_DIM))
	b.add_theme_stylebox_override("pressed", _style(COL_BG_INSET, COL_ACCENT))
	b.add_theme_stylebox_override("focus", _style(COL_BG_RAISED, COL_ACCENT_BRIGHT, 2))
	return b

func _strip_bar(height: int, color: Color) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _stripes_texture()
	r.modulate = color
	r.custom_minimum_size = Vector2(0, height)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# ──────────────────────────────────────────────
# 主菜单 mockup
# ──────────────────────────────────────────────

func _build_menu() -> Control:
	var root_c := Control.new()
	root_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COL_BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_c.add_child(bg)

	# 顶部/底部警示条纹
	var top_strip := _strip_bar(10, Color.WHITE)
	top_strip.anchor_right = 1.0
	top_strip.offset_bottom = 10.0
	root_c.add_child(top_strip)
	var bottom_strip := _strip_bar(14, Color.WHITE)
	bottom_strip.anchor_top = 1.0
	bottom_strip.anchor_right = 1.0
	bottom_strip.anchor_bottom = 1.0
	bottom_strip.offset_top = -14.0
	root_c.add_child(bottom_strip)

	# 标题区：纹章 + 标题 + 副标题
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_c.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var emblem := _icon("res://assets/sprites/turret/tankBody_dark.png", Vector2(96, 90))
	emblem.modulate = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.9)
	emblem.rotation = -0.35
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(emblem)

	var title := _label("前线壁垒", 56, COL_ACCENT_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.016, 0.024, 0.95))
	vbox.add_child(title)
	vbox.add_child(_label("FRONTLINE BULWARK · 波次防线 · 指挥部 07", 17, COL_TEXT_SECONDARY, HORIZONTAL_ALIGNMENT_CENTER))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer)

	var menu_v := VBoxContainer.new()
	menu_v.add_theme_constant_override("separation", 10)
	menu_v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(menu_v)
	menu_v.add_child(_btn("开始作战", ICONS["arrow_right"]))
	menu_v.add_child(_btn("无尽模式", ICONS["refresh"]))
	menu_v.add_child(_btn("多人防线", ICONS["users"]))
	menu_v.add_child(_btn("设置", ICONS["settings"]))
	menu_v.add_child(_btn("退出", ICONS["cross"]))

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(meta_row)
	meta_row.add_child(_icon(ICONS["trophy"], Vector2(18, 18)))
	meta_row.add_child(_label("战功 7 · 下一解锁: LMG-1", 15, COL_TEXT_SECONDARY))

	# 角标/装饰
	var tag := _label("BULWARK HQ", 13, Color(1, 1, 1, 0.35))
	tag.anchor_top = 0.0
	tag.anchor_left = 0.0
	tag.offset_left = 18.0
	tag.offset_top = 18.0
	root_c.add_child(tag)

	var version := _label("v1.2.0 · 像素前线(?) · 构建 0086", 13, Color(1, 1, 1, 0.3))
	version.anchor_top = 1.0
	version.anchor_right = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -320.0
	version.offset_top = -40.0
	version.offset_right = -16.0
	version.offset_bottom = -18.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root_c.add_child(version)

	# 左右竖条装饰
	for side in [0.0, 1.0]:
		var bar := ColorRect.new()
		bar.color = Color(COL_HAZARD.r, COL_HAZARD.g, COL_HAZARD.b, 0.16)
		bar.anchor_top = 0.1
		bar.anchor_bottom = 0.9
		bar.anchor_left = side
		bar.anchor_right = side
		bar.offset_left = 10.0 if side == 0.0 else -22.0
		bar.offset_right = 22.0 if side == 0.0 else -10.0
		root_c.add_child(bar)
	return root_c

# ──────────────────────────────────────────────
# HUD mockup
# ──────────────────────────────────────────────

func _progress_bar(value: float, max_v: float, color: Color, size: Vector2) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.value = value
	bar.max_value = max_v
	bar.custom_minimum_size = size
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	bar.texture_under = _filled_texture(Color(0.02, 0.03, 0.045), 16, 16)
	var fill := _filled_texture(color, 8, 8)
	bar.texture_progress = fill
	bar.modulate = Color(1, 1, 1, 1)
	return bar

func _panel_style() -> StyleBoxFlat:
	return _style(COL_BG_PANEL, COL_BORDER, 1, 4)

func _build_hud() -> Control:
	var root_c := Control.new()
	root_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = COL_BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_c.add_child(bg)

	# TopLeft：资源 + HP
	var tl := PanelContainer.new()
	tl.add_theme_stylebox_override("panel", _panel_style())
	tl.offset_left = 16.0
	tl.offset_top = 16.0
	tl.offset_right = 316.0
	tl.offset_bottom = 118.0
	root_c.add_child(tl)
	var tl_v := VBoxContainer.new()
	tl_v.add_theme_constant_override("separation", 4)
	tl.add_child(tl_v)
	tl_v.add_child(_label("资源 3200 · 建材 12 · 预备 1", 16, COL_ACCENT_BRIGHT))
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	tl_v.add_child(hp_row)
	hp_row.add_child(_icon(ICONS["trophy"], Vector2(16, 16)))
	hp_row.add_child(_label("HP", 18, COL_TEXT))
	hp_row.add_child(_progress_bar(72, 100, COL_SUCCESS, Vector2(200, 16)))
	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 6)
	tl_v.add_child(ammo_row)
	ammo_row.add_child(_icon("res://assets/vfx/kenney/bullets/bulletGreen1.png", Vector2(16, 16)))
	ammo_row.add_child(_label("12 / 96", 16, COL_TEXT))

	# TopRight：分数/连击/波次/Boss
	var tr := PanelContainer.new()
	tr.add_theme_stylebox_override("panel", _panel_style())
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -380.0
	tr.offset_top = 16.0
	tr.offset_right = -16.0
	tr.offset_bottom = 200.0
	root_c.add_child(tr)
	var tr_v := VBoxContainer.new()
	tr_v.add_theme_constant_override("separation", 4)
	tr.add_child(tr_v)
	tr_v.add_child(_label("12345", 30, COL_ACCENT_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	tr_v.add_child(_label("连击 ×2.7", 16, Color(1.0, 0.6, 0.35), HORIZONTAL_ALIGNMENT_RIGHT))
	tr_v.add_child(_label("第 2 章 · 3/4 波", 18, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	var boss_row := HBoxContainer.new()
	boss_row.alignment = BoxContainer.ALIGNMENT_END
	tr_v.add_child(boss_row)
	boss_row.add_child(_label("精英·巨兽", 16, COL_DANGER))
	boss_row.add_child(_progress_bar(62, 100, COL_DANGER, Vector2(200, 14)))
	var buff_row := HBoxContainer.new()
	buff_row.add_theme_constant_override("separation", 8)
	buff_row.alignment = BoxContainer.ALIGNMENT_END
	tr_v.add_child(buff_row)
	buff_row.add_child(_icon("res://assets/vfx/kenney/bullets/bulletGreen1.png", Vector2(16, 16)))
	buff_row.add_child(_icon("res://assets/sprites/props/crateMetal.png", Vector2(16, 16)))
	buff_row.add_child(_icon(ICONS["star"], Vector2(16, 16)))
	buff_row.add_child(_label("急速 6s", 13, Color(0.55, 0.9, 0.8)))

	# BottomLeft：武器槽 + 弹容
	var bl := PanelContainer.new()
	bl.add_theme_stylebox_override("panel", _panel_style())
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 16.0
	bl.offset_top = -96.0
	bl.offset_right = 420.0
	bl.offset_bottom = -16.0
	root_c.add_child(bl)
	var bl_v := VBoxContainer.new()
	bl_v.add_theme_constant_override("separation", 4)
	bl.add_child(bl_v)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	bl_v.add_child(slots)
	for name in ["AR-1", "SG-1", "HG-1"]:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", _style(COL_BG_INSET, COL_BORDER, 1, 6))
		badge.add_child(_label(name, 18, COL_TEXT))
		slots.add_child(badge)
	var ammo := _label("弹药 12 | 96   能量 30 | 0", 14, COL_TEXT_SECONDARY)
	bl_v.add_child(ammo)

	# 中央波次横幅
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.09, 0.85), Color(0.9, 0.72, 0.3, 0.6), 2, 4))
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -300.0
	banner.offset_right = 300.0
	banner.offset_top = 84.0
	banner.offset_bottom = 170.0
	root_c.add_child(banner)
	var b_v := VBoxContainer.new()
	b_v.add_theme_constant_override("separation", 2)
	banner.add_child(b_v)
	b_v.add_child(_label("第 2 章 · 废弃小镇", 26, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
	b_v.add_child(_label("灰蓝街巷里传来履带声——加固东侧防线。", 16, Color(0.85, 0.9, 0.98, 0.85), HORIZONTAL_ALIGNMENT_CENTER))

	# 顶部警示条
	var strip := _strip_bar(8, Color.WHITE)
	strip.anchor_right = 1.0
	root_c.add_child(strip)
	return root_c

# ──────────────────────────────────────────────
# 世界层增色概念 mockup
# ──────────────────────────────────────────────

func _world_sprite(path: String, pos: Vector2, scale: float, tint: Color = Color.WHITE, alpha: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(path)
	s.global_position = pos
	s.scale = Vector2(scale, scale)
	s.modulate = Color(tint.r, tint.g, tint.b, alpha)
	return s

func _build_world() -> Node2D:
	var world := Node2D.new()

	var bg := Sprite2D.new()
	bg.texture = _tex("res://assets/sprites/tiles/tile_01.png")
	bg.scale = Vector2(18, 18)
	bg.modulate = Color(0.5, 0.62, 0.5)
	world.add_child(bg)

	var zone_a := _world_sprite("res://assets/sprites/tiles/tile_05.png", Vector2(-560, -420), 18, Color(0.8, 0.95, 0.85))
	var zone_b := _world_sprite("res://assets/sprites/tiles/tile_05.png", Vector2(560, 420), 18, Color(0.82, 0.9, 1.0))
	var zone_c := _world_sprite("res://assets/sprites/tiles/tile_05.png", Vector2(560, -420), 18, Color(1.0, 0.88, 0.82))
	world.add_child(zone_a)
	world.add_child(zone_b)
	world.add_child(zone_c)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2.ZERO
	cam.zoom = Vector2(1.1, 1.1)
	cam.enabled = true
	world.add_child(cam)

	for gx in range(-1000, 1001, 500):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(gx, -1100), Vector2(gx, 1100)])
		line.width = 1.0
		line.default_color = Color(0.18, 0.22, 0.27, 0.3)
		world.add_child(line)
	for gy in range(-1000, 1001, 500):
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(-1350, gy), Vector2(1350, gy)])
		line.width = 1.0
		line.default_color = Color(0.18, 0.22, 0.27, 0.3)
		world.add_child(line)

	# 基地（核心 + 三环 + 高亮）
	var rings := [Vector2(300, 0), Vector2(520, 0), Vector2(720, 0)]
	for r in rings:
		var ring := Line2D.new()
		var pts: PackedVector2Array = []
		for i in 12:
			var a := TAU * i / 12.0
			pts.append(Vector2(cos(a), sin(a)) * r.x)
		ring.points = pts
		ring.closed = true
		ring.width = 2.0 if r.x == 300 else 1.5
		ring.default_color = Color(0.22, 0.3, 0.38, 0.4)
		world.add_child(ring)
	var core := Polygon2D.new()
	var core_pts: PackedVector2Array = []
	for i in 6:
		core_pts.append(Vector2(cos(TAU * i / 6.0), sin(TAU * i / 6.0)) * 90.0)
	core.polygon = core_pts
	core.color = Color(0.12, 0.16, 0.22)
	world.add_child(core)
	var glow := Polygon2D.new()
	glow.polygon = core_pts
	glow.scale = Vector2(1.25, 1.25)
	glow.color = Color(COL_HAZARD.r, COL_HAZARD.g, COL_HAZARD.b, 0.12)
	world.add_child(glow)

	# 装饰：沙袋/木箱/油渍/残骸（全部仓库已有素材）
	var sandbag_positions := [Vector2(-260, -140), Vector2(-320, -40), Vector2(-260, 60), Vector2(260, -140), Vector2(320, -40), Vector2(260, 60)]
	for i in sandbag_positions.size():
		world.add_child(_world_sprite("res://assets/sprites/props/sandbagBeige.png", sandbag_positions[i], 2.2, Color.WHITE, 0.95))
	var crate_positions := [Vector2(-180, 200), Vector2(180, 200), Vector2(-820, -620), Vector2(820, 620), Vector2(820, -620), Vector2(-820, 620)]
	for i in crate_positions.size():
		var p: Vector2 = crate_positions[i]
		var path := "res://assets/sprites/props/crateMetal.png" if i % 2 == 0 else "res://assets/vfx/kenney/debris/crateWood.png"
		world.add_child(_world_sprite(path, p, 2.6, Color.WHITE, 0.9))
	for oil in [Vector2(-520, 260), Vector2(560, -260), Vector2(-640, -250)]:
		world.add_child(_world_sprite("res://assets/sprites/props/oilSpill_large.png", oil, 3.2, Color.WHITE, 0.65))
	for wreck in [Vector2(-1150, -900), Vector2(1150, 900), Vector2(1150, -900), Vector2(-1150, 900)]:
		world.add_child(_world_sprite("res://assets/sprites/turret/tank/tank_huge.png", wreck, 3.0, Color(0.3, 0.36, 0.42), 0.55))
	world.add_child(_world_sprite("res://assets/sprites/props/sandbagBeige.png", Vector2(-40, -260), 2.6))
	world.add_child(_world_sprite("res://assets/sprites/props/sandbagBeige.png", Vector2(40, -260), 2.6))

	# 玩家示意
	var player := _world_sprite("res://assets/sprites/chars/soldier1_stand.png", Vector2(0, 170), 3.0)
	world.add_child(player)

	var player_label := Label.new()
	player_label.text = "玩家[P1]"
	player_label.position = Vector2(-24, 118)
	player_label.add_theme_font_size_override("font_size", 14)
	player_label.add_theme_color_override("font_color", COL_INFO)
	world.add_child(player_label)

	var title := Label.new()
	title.text = "M0 概念示意：世界层轻量增色（仅素材层 · 沙袋/木箱/油渍/残骸/变体瓦片）"
	title.position = Vector2(-620, 12)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COL_ACCENT_BRIGHT)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.016, 0.024, 0.9))
	world.add_child(title)
	return world
