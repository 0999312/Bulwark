extends Node
## M4 一次性粒子爆发池（议题 3，D-M4-10）：
## - 命中火花（裁决侧命中点）与爆炸闪光由本类统一管理
## - 池容量恒定（SPARK_POOL_SIZE），只借不建；client 镜像不生成火花（由 EVT_ENEMY_HIT 闪白承担）
## - 游戏感改造：弃用 512px 高清软粒子贴图，统一为运行时生成的 8px 像素方块纹理，
##   与 Kenney 像素角色同分辨率体系；命中/死亡/弹道特效 = 像素方块爆点 + 像素环扩散
##   （设计依据：particles-vfx / godot-particles / tween-animation 三技能组合）

const SPARK_POOL_SIZE := 32
const DAMAGE_POOL_SIZE := 24
const EXPLOSION_POOL_SIZE := 10
const PIXEL_SIZE := 8
const GLOW_SIZE := 32

var _root: Node2D
var _spark_pool: Array[CPUParticles2D] = []
var _damage_pool: Array[DamageNumber] = []
var _explosion_pool: Array[AnimatedSprite2D] = []
var _explosion_tweens: Dictionary = {}  # AnimatedSprite2D -> Tween（兜底定时隐藏）
var _pool_cursor := 0
var _damage_cursor := 0
var _explosion_cursor := 0
var _pixel_texture: ImageTexture
var _glow_texture: ImageTexture

## 共享像素纹理（8px 硬边白块 + 低透明度外圈；颜色由 CPUParticles2D.color 乘算）
func get_pixel_texture() -> ImageTexture:
	if _pixel_texture != null:
		return _pixel_texture
	var img := Image.create(PIXEL_SIZE, PIXEL_SIZE, false, Image.FORMAT_RGBA8)
	for y in PIXEL_SIZE:
		for x in PIXEL_SIZE:
			var dx := x - (PIXEL_SIZE - 1) * 0.5
			var dy := y - (PIXEL_SIZE - 1) * 0.5
			var d := sqrt(dx * dx + dy * dy)
			if d <= 2.2:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif d <= 3.4:
				img.set_pixel(x, y, Color(1, 1, 1, 0.45))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_pixel_texture = ImageTexture.create_from_image(img)
	return _pixel_texture

## 共享径向渐变光斑（32×32，白→透明）：替换旧 512px 软粒子动态光贴图
## 用途：PointLight2D.texture / 基地核心光 / 短促闪光（P0-2）
func get_glow_texture() -> ImageTexture:
	if _glow_texture != null:
		return _glow_texture
	var img := Image.create(GLOW_SIZE, GLOW_SIZE, false, Image.FORMAT_RGBA8)
	var center := (GLOW_SIZE - 1) * 0.5
	for y in GLOW_SIZE:
		for x in GLOW_SIZE:
			var d := Vector2(x, y).distance_to(Vector2(center, center)) / center
			if d >= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var a := pow(1.0 - d, 2.2)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_glow_texture = ImageTexture.create_from_image(img)
	return _glow_texture

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_ensure_root")

func _ensure_root() -> void:
	if not is_inside_tree() or _root != null:
		return
	_root = Node2D.new()
	_root.name = "FxBursts"
	get_tree().root.add_child(_root)
	for i in SPARK_POOL_SIZE:
		var particles := _make_spark()
		_root.add_child(particles)
		_spark_pool.append(particles)
	for i in DAMAGE_POOL_SIZE:
		var dn := DamageNumber.new()
		dn.visible = false
		_root.add_child(dn)
		_damage_pool.append(dn)
	# P1-15 爆炸 5 帧动画池（0.35s，只建一次；死亡/自爆/AoE/Boss 击杀）
	for i in EXPLOSION_POOL_SIZE:
		var ex := AnimatedSprite2D.new()
		ex.sprite_frames = VfxBank.explosion_sprite_frames()
		ex.visible = false
		ex.animation_finished.connect(func() -> void: ex.visible = false)
		_root.add_child(ex)
		_explosion_pool.append(ex)

func _make_spark() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = get_pixel_texture()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.25
	particles.lifetime_randomness = 0.2
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 220.0)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 130.0
	# 8px 纹理按 0.4~0.9 缩放 = 3~7px 的像素方块，贴合 Kenney 角色（32px 基准）
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 0.9
	return particles

## 命中火花：round-robin 借用池节点（刚播完的粒子被立即重播亦可，视觉无感）
func spawn_hit_spark(world_pos: Vector2, color: Color = Color(1.0, 0.86, 0.4)) -> void:
	if _root == null or _spark_pool.is_empty():
		return
	var particles := _spark_pool[_pool_cursor % _spark_pool.size()]
	_pool_cursor += 1
	particles.global_position = world_pos
	particles.color = color
	particles.amount = 8
	particles.lifetime = 0.22
	particles.gravity = Vector2(0.0, 260.0)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 150.0
	particles.restart()
	particles.emitting = true

## 通用像素爆点：任意颜色/数量/速度/重力（命中、枪口、弹体抵达、死亡共用）
func spawn_pixel_burst(world_pos: Vector2, color: Color, count: int = 8,
		speed: float = 120.0, lifetime: float = 0.25, gravity_y: float = 0.0) -> void:
	if _root == null or _spark_pool.is_empty() or count <= 0:
		return
	var particles := _spark_pool[_pool_cursor % _spark_pool.size()]
	_pool_cursor += 1
	particles.global_position = world_pos
	particles.color = color
	particles.amount = mini(count, 24)
	particles.lifetime = maxf(0.08, lifetime)
	particles.lifetime_randomness = 0.15
	particles.gravity = Vector2(0.0, gravity_y)
	particles.initial_velocity_min = speed * 0.35
	particles.initial_velocity_max = speed
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.8
	particles.restart()
	particles.emitting = true

## 爆炸闪光：像素方块短促四散 + 动态光；不再使用高清 flare 贴图
func spawn_flare(world_pos: Vector2, color: Color = Color(1.0, 0.7, 0.3)) -> void:
	LightingManager.request_flash(world_pos, color, 1.4, 0.12)
	spawn_pixel_burst(world_pos, color, 7, 90.0, 0.26, 40.0)
	spawn_impact_ring(world_pos, color.lightened(0.2), 12.0, 0.14)

## 像素环扩散（硬边方框 + 四角点；低分辨率画风下的冲击波替代品）
func spawn_impact_ring(world_pos: Vector2, color: Color,
		max_radius: float = 12.0, duration: float = 0.14) -> void:
	if _root == null:
		return
	var ring := PixelRing.new()
	_root.add_child(ring)
	ring.setup(world_pos, color, max_radius, duration)

## P1-11 伤害数字（池化，只借不建；普通命中/暴击/弱点/连击分色）
func spawn_damage_number(world_pos: Vector2, text: String, color: Color) -> void:
	if _root == null or _damage_pool.is_empty() or text.is_empty():
		return
	var dn := _damage_pool[_damage_cursor % _damage_pool.size()]
	_damage_cursor += 1
	dn.setup(text, color, world_pos)

## P1-15 爆炸 5 帧动画（0.35s；池化借用，播完自动隐藏；Tier2）
## 双保险：animation_finished 信号 + 定时兜底（无论 loop 状态如何，0.35s 后强制 stop+隐藏）
func spawn_explosion(world_pos: Vector2, scale: float = 1.0) -> void:
	if _root == null or _explosion_pool.is_empty():
		return
	var ex := _explosion_pool[_explosion_cursor % _explosion_pool.size()]
	_explosion_cursor += 1
	ex.global_position = world_pos
	ex.scale = Vector2.ONE * maxf(0.2, scale)
	ex.modulate = Color.WHITE
	ex.frame = 0
	ex.visible = true
	ex.play("default")
	# 兜底：覆盖上一个定时器，0.35s+ε 后强制隐藏（不经 signal）
	var old_tw: Tween = _explosion_tweens.get(ex)
	if old_tw != null and old_tw.is_valid():
		old_tw.kill()
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_interval(VfxBank.EXPLOSION_DURATION + 0.05)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ex):
			ex.stop()
			ex.visible = false
		_explosion_tweens.erase(ex))
	_explosion_tweens[ex] = tw

## 测试/审计：当前可见爆炸数（用于断言“播完即消失”）
func get_active_explosion_count() -> int:
	var count := 0
	for ex in _explosion_pool:
		if is_instance_valid(ex) and ex.visible:
			count += 1
	return count
