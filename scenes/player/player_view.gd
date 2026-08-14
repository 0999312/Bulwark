class_name PlayerView
extends CharacterBody2D
## 玩家表现层（前端）：只读后端状态 + 发意图
## - 输入轮询（GUIDE action）→ 意图（set_move_intent / set_shoot_intent / set_aim_direction / intent_switch）
## - 移动/碰撞由表现层执行（CharacterBody2D + move_and_slide），速度取后端属性
## - ShotFiredEvent（后端验证通过）→ 表现层执行 HITSCAN 射线 → 命中回报伤害管道
## - 弹道表现走对象池（scripts/framework/object_pool.gd）
## - 枪械手感（M0）：散布（基础 + 连射热度扩散）、枪口后坐动画、相机震动；均为纯表现，
##   后端 try_fire 保持确定性（可测）。方向性后坐/压枪为 M1+ 设计（见 docs/design/gunplay-attachment-notes.md）

const ACCELERATION := 2200.0
const TRACER_DURATION := 0.06
const TRACER_LAYER_MASK := 2  # 2D 物理层 2 = enemy

## ─── 枪械手感参数 ───
const HEAT_PER_SHOT := 0.15        # 每发连射热度增量（乘 type.recoil.x 系数）
const HEAT_DECAY := 2.0            # 停火后热度衰减速度（/秒，约 0.5s 归零）
const BLOOM_MAX_MULT := 2.0        # 满热度时散布的额外倍率（总倍率 1+2=3）
const MUZZLE_KICK := 5.0           # 枪口后坐回退像素（乘 type.recoil.y 系数）
const SHAKE_AMPLITUDE := 3.0       # 相机震动幅度（px）
const SHAKE_DURATION := 0.08       # 单发震动时长（秒）
const GUN_RECOVER_TIME := 0.12     # 枪口回退弹簧恢复时长（秒）

@onready var aim_marker: Node2D = $Aim
@onready var gun: ColorRect = $Aim/Gun
@onready var camera: Camera2D = $Camera2D
@onready var body: Polygon2D = $Body

var controller: PlayerController
var actions: Dictionary = {}  # StringName -> GUIDEAction（与 GUIDE 启用上下文同实例）

var _tracer_pool: ObjectPool
var _heat := 0.0               # 连射热度 0-1（散布扩散源）
var _shake_time := 0.0         # 相机震动剩余时间
var _gun_tween: Tween          # 枪口回退恢复动画
var _hit_tween: Tween          # 受击闪红动画
var _last_health := -1.0       # 上一帧生命（受击检测）
var _rng := RandomNumberGenerator.new()

func setup(p_controller: PlayerController, p_actions: Dictionary) -> void:
	controller = p_controller
	actions = p_actions
	_last_health = p_controller.health
	_rng.randomize()
	_tracer_pool = ObjectPool.new(_make_tracer)
	EventBus.subscribe(&"ShotFiredEvent", _on_shot_fired)
	EventBus.subscribe(&"PlayerHealthChangedEvent", _on_health_changed)

func _make_tracer() -> Node:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(1.0, 0.88, 0.4, 1.0)
	return line

## 散布应用：方向旋转随机偏移角（度）。纯函数，headless 可测
static func apply_spread(direction: Vector2, spread_degrees: float, rng: RandomNumberGenerator) -> Vector2:
	if spread_degrees <= 0.0 or direction.length_squared() <= 0.001:
		return direction
	var offset := deg_to_rad(rng.randf_range(-spread_degrees, spread_degrees))
	return direction.rotated(offset)

# ─── 输入轮询（GUIDE 在 _process 中先行更新 action 状态） ───

func _process(delta: float) -> void:
	_tick_gunplay(delta)
	if controller == null or controller.is_dead():
		return
	var move_action: GUIDEAction = actions.get(&"move")
	if move_action != null:
		controller.set_move_intent(move_action.value_axis_2d)
	var aim_action: GUIDEAction = actions.get(&"aim")
	if aim_action != null:
		# 鼠标纯自由瞄准（P9）：get_global_mouse_position 自动包含 Camera2D 变换
		# （旧实现用 viewport canvas transform，不含相机平移/缩放，瞄准方向完全错位）
		controller.set_aim_direction(get_global_mouse_position() - global_position)
	var shoot_action: GUIDEAction = actions.get(&"shoot")
	if shoot_action != null:
		controller.set_shoot_intent(shoot_action.is_triggered())
	var reload_action: GUIDEAction = actions.get(&"reload")
	if reload_action != null and reload_action.is_triggered():
		controller.intent_reload()
	_poll_weapon_switch()

## 切换武器（GUIDE switch_weapon 边沿触发 + 当前按下的数字键解析目标槽位）
func _poll_weapon_switch() -> void:
	var switch_action: GUIDEAction = actions.get(&"switch_weapon")
	if switch_action == null or not switch_action.is_triggered():
		return
	if Input.is_key_pressed(KEY_1):
		controller.intent_switch(WeaponSlots.SLOT_MAIN)
	elif Input.is_key_pressed(KEY_2):
		controller.intent_switch(WeaponSlots.SLOT_SUB)
	elif Input.is_key_pressed(KEY_3):
		controller.intent_switch(WeaponSlots.SLOT_PISTOL)

# ─── 枪械手感（表现层：热度衰减 / 相机震动 / 枪口后坐） ───

## 每帧驱动：连射热度衰减 + 相机震动残影（无论死活都跑，保证视觉恢复）
func _tick_gunplay(delta: float) -> void:
	if _heat > 0.0:
		_heat = maxf(0.0, _heat - HEAT_DECAY * delta)
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		if camera != null:
			camera.offset = Vector2(
				_rng.randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE),
				_rng.randf_range(-SHAKE_AMPLITUDE, SHAKE_AMPLITUDE))
	elif camera != null and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

## 每发子弹的手感反馈：连射热度 + 相机震动 + 枪口回退（纯表现，不影响后端命中判定）
func _apply_recoil_feedback(recoil: Vector2) -> void:
	_heat = minf(1.0, _heat + HEAT_PER_SHOT * recoil.x)
	_shake_time = SHAKE_DURATION
	if gun != null:
		if _gun_tween != null and _gun_tween.is_valid():
			_gun_tween.kill()
		gun.position = Vector2(-MUZZLE_KICK * recoil.y, 0.0)
		_gun_tween = create_tween()
		_gun_tween.tween_property(gun, "position", Vector2.ZERO, GUN_RECOVER_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 受击检测：生命下降 → 机身闪红（0.18s 恢复）
func _on_health_changed(event: PlayerHealthChangedEvent) -> void:
	if event.current < _last_health:
		_flash_hit()
	_last_health = event.current

## 敌人撞击伤害入口（EnemyView 经 has_method 调用，避免 PlayerView↔EnemyView 循环引用）
func take_ram_hit(damage: float) -> void:
	if controller == null or controller.is_dead():
		return
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, damage)
	controller.take_damage(ctx)

func _flash_hit() -> void:
	if body == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	body.self_modulate = Color(1.0, 0.32, 0.32)
	_hit_tween = create_tween()
	_hit_tween.tween_property(body, "self_modulate", Color.WHITE, 0.18)

# ─── 移动（表现层执行） ───

func _physics_process(delta: float) -> void:
	if controller == null:
		return
	if controller.is_dead():
		velocity = Vector2.ZERO
	else:
		var speed := controller.attribute_set.get_final(AttributeSet.MOVE_SPEED)
		var dir := controller.move_direction
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
		velocity = velocity.move_toward(dir * speed, ACCELERATION * delta)
	move_and_slide()
	aim_marker.rotation = controller.aim_direction.angle()

# ─── 弹道执行（HITSCAN，后端验证后触发；散布为表现层手感，命中判定以后端意图方向结算） ───

func _on_shot_fired(event: ShotFiredEvent) -> void:
	var model: WeaponModelData = ContentBootstrap.get_entry(Bulwark.REG_WEAPON_MODEL, event.model_location)
	var range := model.range if model != null else 900.0
	var spread := model.spread if model != null else 0.0
	var recoil := Vector2.ONE
	if model != null and not model.type_id.is_empty():
		var type_data: WeaponTypeData = ContentBootstrap.get_entry(Bulwark.REG_WEAPON_TYPE, model.type_id)
		if type_data != null:
			recoil = type_data.recoil

	# 散布：基础散布 ×（1 + 连射热度扩散）——连续射击散布逐渐扩大
	var dir := apply_spread(event.aim_direction, spread * (1.0 + _heat * BLOOM_MAX_MULT), _rng)

	var from := global_position
	var to := from + dir * range

	var query := PhysicsRayQueryParameters2D.create(from, to, TRACER_LAYER_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	var end := to
	if not hit.is_empty():
		end = hit.position
		var collider = hit.collider
		if collider is EnemyView:
			collider.apply_player_hit(model, dir)
	_show_tracer(from, end)
	_apply_recoil_feedback(recoil)

func _show_tracer(from: Vector2, to: Vector2) -> void:
	var line: Line2D = _tracer_pool.acquire()
	line.points = PackedVector2Array([from, to])
	line.modulate.a = 1.0
	# 挂在世界层（全局坐标直接可用）
	get_parent().add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, TRACER_DURATION)
	tw.tween_callback(_release_tracer.bind(line))

func _release_tracer(line: Line2D) -> void:
	if not is_instance_valid(line):
		return
	if line.get_parent() != null:
		line.get_parent().remove_child(line)
	_tracer_pool.release(line)
