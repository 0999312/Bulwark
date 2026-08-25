extends Node
## 截图运行器（Node._process 驱动；SceneTree 的 _process 在 -s 下不可靠）
## 被 tools/capture_arcade.gd 挂载到 root；到帧数后截图到 user://captures/

var _frames := 0
var _cap_size := "1280x720"
var _showcase := false

func _ready() -> void:
	if _showcase:
		call_deferred("_add_showcase")

func _add_showcase() -> void:
	## 采证用临时舞台：炮塔（VfxBank 拼接）+ 枪口焰 + 爆炸 5 帧 + 玩家/敌方弹体
	var vp: Vector2i = get_viewport().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.32)
	# 炮塔
	var turret: Node = load("res://scenes/base/turret.tscn").instantiate()
	var facility: DefenseFacilityData = load("res://resources/facilities/facility_turret.tres")
	var ctrl := FacilityController.new(facility, 9999)
	turret.global_position = center + Vector2(-240, 120)
	turret.scale = Vector2(1.5, 1.5)
	get_tree().root.add_child(turret)
	turret.setup.call_deferred(ctrl)
	# 枪口焰（Kenney shotOrange）
	var muzzle := Sprite2D.new()
	muzzle.texture = VfxBank.muzzle("orange")
	muzzle.scale = Vector2(0.08, 0.08)
	muzzle.global_position = center + Vector2(-240 + 90, 120 + 16)
	get_tree().root.add_child(muzzle)
	# 爆炸 5 帧循环
	var boom := AnimatedSprite2D.new()
	boom.sprite_frames = VfxBank.explosion_sprite_frames()
	boom.sprite_frames.set_animation_loop("default", true)
	boom.scale = Vector2(2.0, 2.0)
	boom.global_position = center + Vector2(-180, 0)
	get_tree().root.add_child(boom)
	boom.play("default")
	# 弹体（玩家绿 / 敌方红 / 敌方暗）
	var bullet_pos := center + Vector2(140, 0)
	for bullet_kind: String in ["green", "red", "dark"]:
		var b := Sprite2D.new()
		b.texture = VfxBank.bullet(bullet_kind)
		b.scale = Vector2(1.4, 1.4)
		b.global_position = bullet_pos
		bullet_pos += Vector2(0, 34)
		get_tree().root.add_child(b)

func _process(_delta: float) -> void:
	_frames += 1
	# showcase 模式：注入 HUD 街机化演示事件（分数/连击/buff/Boss 血条）
	if _showcase and _frames == 70:
		var event_bus: Node = get_tree().root.get_node_or_null("EventBus")
		if event_bus != null:
			event_bus.call("publish", ScoreChangedEvent.new(12345, 7, 2.75, 0))
			event_bus.call("publish", EnemyHealthChangedEvent.new(
				999, "bulwark:enemy/elite_behemoth", 620.0, 1000.0, true, Vector2.ZERO))
			event_bus.call("publish", PowerUpPickupEvent.new("power/fire_rate", 0, Vector2.ZERO, 6.0))
	match _frames:
		90:
			_capture("arcade_hud_warning_%s" % _cap_size)
		180:
			_capture("arcade_hud_active_%s" % _cap_size)
		300:
			get_tree().quit()

func _capture(name: String) -> void:
	var viewport := get_viewport()
	var tex := viewport.get_texture()
	print("capture diag: frame=%d tex=%s size=%s" % [_frames, tex, viewport.size])
	if tex == null:
		push_error("capture: viewport texture null at frame %d" % _frames)
		return
	var img := tex.get_image()
	if img == null:
		push_error("capture: image null")
		return
	var dir := "user://captures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s.png" % [dir, name]
	var err := img.save_png(path)
	print("capture: %s -> %s err=%d" % [name, ProjectSettings.globalize_path(path), err])
