class_name PlayerView
extends CharacterBody2D
## 玩家表现层（前端）：只读后端状态 + 发意图
## - 输入轮询（GUIDE action）→ 意图（set_move_intent / set_shoot_intent / set_aim_direction / intent_switch）
## - 移动/碰撞由表现层执行（CharacterBody2D + move_and_slide），速度取后端属性
## - ShotFiredEvent（后端验证通过）→ 表现层执行 HITSCAN 射线 → 命中回报伤害管道
## - 弹道表现走对象池（scripts/framework/object_pool.gd）
## - 枪械手感（M1）：鸭科夫式 2D 俯视角适配（方向性后坐 + 连射热度 bloom + 方向化相机震动），
##   均为纯表现，后端 try_fire 保持确定性（可测）。模型见 docs/design/gunplay-attachment-notes.md §3
## - M2 多人：role/position_mode 双维——
##   role：LOCAL（读 GUIDE 输入；client 下同时发意图 RPC）/ REMOTE（host 上远端玩家：Net 意图写入
##         controller，本视图只模拟）/ NONE（远端镜像：无输入）
##   position_mode：SIMULATED（物理移动）/ SNAPSHOT（位置由 host 快照驱动，client 端）

const ACCELERATION := 2200.0
const TRACER_DURATION := 0.06
const TRACER_LAYER_MASK := 2  # 2D 物理层 2 = enemy

## ─── 枪械手感参数（M1：鸭科夫式 2D 俯视角适配，草案见 gunplay-attachment-notes.md §3）───
const RECOIL_PER_SHOT := 0.6      # 每发后坐脉冲（度，乘 type.recoil.x）
const RECOIL_RECOVER_SPEED := 3.0 # 后坐角弹簧恢复速度（度/秒，向 0 收敛）
const HEAT_PER_SHOT := 0.15       # 每发连射热度增量（度，乘 type.recoil.x）
const HEAT_MAX := 4.0             # 连射热度上限（度；草案 §3 "上限 4°"）
const HEAT_DECAY := 3.0           # 停火热度衰减速度（度/秒）
const MOVE_SPREAD_MULT := 1.5     # 移动时散布倍率
const MUZZLE_KICK := 5.0          # 枪口后坐回退像素（乘 type.recoil.y）
const SHAKE_AMPLITUDE := 3.0      # 相机震动幅度（px，草案 2~4px）
const SHAKE_DURATION := 0.08      # 单发震动时长（秒，草案 60~100ms）
const GUN_RECOVER_TIME := 0.12    # 枪口回退弹簧恢复时长（秒）

## M2 多人：输入角色 / 位置模式
enum Role {
	LOCAL = 0,   # 读本地 GUIDE 输入（client 下同时发意图 RPC）
	REMOTE = 1,  # host 上远端玩家：意图由 Net 写入 controller，本视图只模拟/表现
	NONE = 2,    # 纯镜像：无输入，位置由快照驱动
}
enum PositionMode {
	SIMULATED = 0,  # 物理模拟移动（host 端真实玩家）
	SNAPSHOT = 1,   # 位置由 host 快照驱动（client 端所有玩家）
}

@onready var aim_marker: Node2D = $Aim
@onready var gun: Polygon2D = $Aim/Gun
@onready var muzzle_flash: Polygon2D = $Aim/Sight
@onready var camera: Camera2D = $Camera2D
@onready var body: Polygon2D = $Body

var controller: PlayerController
var actions: Dictionary = {}  # StringName -> GUIDEAction（与 GUIDE 启用上下文同实例）

## M2 多人身份/模式（GameSession 装配时设置）
var player_id := 0
var role := Role.LOCAL
var position_mode := PositionMode.SIMULATED

var _tracer_pool: ObjectPool
var _heat := 0.0               # 连射热度（度，0 ~ HEAT_MAX；散布扩散源）
var _recoil_angle := 0.0       # 后坐角（度）：每发脉冲累积，弹簧向 0 恢复
var _shake_time := 0.0         # 相机震动剩余时间（秒）
var _shake_axis := Vector2.ZERO # 震动主方向（后坐脉冲反方向单位向量）
var _gun_tween: Tween          # 枪口回退恢复动画
var _hit_tween: Tween          # 受击闪红动画
var _muzzle_tween: Tween       # 枪口焰闪现动画
var _last_health := -1.0       # 上一帧生命（受击检测）
var _rng := RandomNumberGenerator.new()
# 复活表现（M1）：后端 controller.state 在复活 CD 期间保持 DEAD（REVIVING 枚举未接线），
# 故用 ReviveStartedEvent/RevivedEvent 追踪"复活中"与"复活完成"，而非轮询 is_reviving()
var _is_reviving_visual := false # 复活中（倒地 + 闪烁提示）
var _blink_t := 0.0            # 复活闪烁相位（秒）

func setup(p_controller: PlayerController, p_actions: Dictionary) -> void:
	controller = p_controller
	actions = p_actions
	_last_health = p_controller.health
	_rng.randomize()
	_tracer_pool = ObjectPool.new(_make_tracer)
	EventBus.subscribe(&"ShotFiredEvent", _on_shot_fired)
	EventBus.subscribe(&"PlayerHealthChangedEvent", _on_health_changed)
	EventBus.subscribe(&"PlayerDiedEvent", _on_player_died)
	EventBus.subscribe(&"ReviveStartedEvent", _on_revive_started)
	EventBus.subscribe(&"RevivedEvent", _on_revived)

## M2 多人：装配身份与模式（GameSession 在 setup 后调用）
func set_role(p_role: Role, p_position_mode: PositionMode) -> void:
	role = p_role
	position_mode = p_position_mode

func set_player_id(p_id: int) -> void:
	player_id = p_id

## 快照置位（client 端 SNAPSHOT 玩家每帧调用；host 端 SIMULATED 忽略）
func apply_snapshot(pos: Vector2, aim_angle: float) -> void:
	if position_mode != PositionMode.SNAPSHOT:
		return
	global_position = pos
	if aim_marker != null:
		aim_marker.rotation = aim_angle

func _make_tracer() -> Node:
	# 弹道发光：外圈半透明光晕 + 内核亮线，复用同一对象池
	var tracer := Node2D.new()
	var glow := Line2D.new()
	glow.width = 7.0
	glow.default_color = Color(1.0, 0.75, 0.25, 0.35)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.antialiased = true
	tracer.add_child(glow)
	var core := Line2D.new()
	core.width = 2.5
	core.default_color = Color(1.0, 0.92, 0.6, 1.0)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	core.antialiased = true
	tracer.add_child(core)
	return tracer

## 散布应用：方向旋转随机偏移角（度）。纯函数，headless 可测
static func apply_spread(direction: Vector2, spread_degrees: float, rng: RandomNumberGenerator) -> Vector2:
	if spread_degrees <= 0.0 or direction.length_squared() <= 0.001:
		return direction
	var offset := deg_to_rad(rng.randf_range(-spread_degrees, spread_degrees))
	return direction.rotated(offset)

# ─── 输入轮询（GUIDE 在 _process 中先行更新 action 状态；仅 LOCAL 角色） ───

func _process(delta: float) -> void:
	_tick_gunplay(delta)
	_tick_revive_blink(delta)
	if controller == null or controller.is_dead():
		return
	if role != Role.LOCAL:
		return  # REMOTE：意图由 Net 写入；NONE：无输入
	var move_action: GUIDEAction = actions.get(&"move")
	if move_action != null:
		var dir := move_action.value_axis_2d
		controller.set_move_intent(dir)
		if Net.is_client():
			Net.send_intent(&"move", [dir])
	var aim_action: GUIDEAction = actions.get(&"aim")
	if aim_action != null:
		if Net.is_client():
			# client 备选键位：键盘八向瞄准（IJKL/方向键 value_axis_2d）
			var kbd := aim_action.value_axis_2d
			if kbd.length_squared() > 0.001:
				var aim := kbd.normalized()
				controller.set_aim_direction(aim)
				Net.send_intent(&"aim", [aim])
		else:
			# 鼠标纯自由瞄准（P9）：get_global_mouse_position 自动包含 Camera2D 变换
			# （旧实现用 viewport canvas transform，不含相机平移/缩放，瞄准方向完全错位）
			controller.set_aim_direction(get_global_mouse_position() - global_position)
	var shoot_action: GUIDEAction = actions.get(&"shoot")
	if shoot_action != null:
		var held := shoot_action.is_triggered()
		controller.set_shoot_intent(held)
		if Net.is_client():
			Net.send_intent(&"shoot", [held])
	var reload_action: GUIDEAction = actions.get(&"reload")
	if reload_action != null and reload_action.is_triggered():
		controller.intent_reload()
		if Net.is_client():
			Net.send_intent(&"reload")
	_poll_weapon_switch()

## 切换武器（GUIDE switch_weapon 边沿触发 + 当前按下的数字键解析目标槽位）
func _poll_weapon_switch() -> void:
	var switch_action: GUIDEAction = actions.get(&"switch_weapon")
	if switch_action == null or not switch_action.is_triggered():
		return
	var slot := -1
	if Input.is_key_pressed(KEY_1):
		slot = WeaponSlots.SLOT_MAIN
	elif Input.is_key_pressed(KEY_2):
		slot = WeaponSlots.SLOT_SUB
	elif Input.is_key_pressed(KEY_3):
		slot = WeaponSlots.SLOT_PISTOL
	elif Input.is_key_pressed(KEY_U):
		slot = WeaponSlots.SLOT_MAIN
	elif Input.is_key_pressed(KEY_O):
		slot = WeaponSlots.SLOT_SUB
	elif Input.is_key_pressed(KEY_I):
		slot = WeaponSlots.SLOT_PISTOL
	if slot < 0:
		return
	controller.intent_switch(slot)
	if Net.is_client():
		Net.send_intent(&"switch", [slot])

# ─── 枪械手感（表现层：热度/后坐恢复 / 方向化相机震动 / 枪口后坐） ───

## 每帧驱动：连射热度衰减 + 后坐角弹簧恢复 + 相机震动残影（无论死活都跑，保证视觉恢复）
func _tick_gunplay(delta: float) -> void:
	if _heat > 0.0:
		_heat = maxf(0.0, _heat - HEAT_DECAY * delta)
	if absf(_recoil_angle) > 0.01:
		_recoil_angle = move_toward(_recoil_angle, 0.0, RECOIL_RECOVER_SPEED * delta)
	else:
		_recoil_angle = 0.0
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		if camera != null:
			# 方向化震动：主分量沿后坐反方向（_shake_axis），幅度随时间衰减，叠加少量随机抖动
			var amp := SHAKE_AMPLITUDE * (_shake_time / SHAKE_DURATION)
			camera.offset = _shake_axis * amp \
				+ Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp)) * 0.3
	elif camera != null and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

## 每发子弹的手感反馈：连射热度 + 方向化相机震动 + 枪口回退（纯表现，不影响后端命中判定）
func _apply_recoil_feedback(recoil: Vector2, pulse: float, aim_dir: Vector2) -> void:
	_heat = minf(HEAT_MAX, _heat + HEAT_PER_SHOT * recoil.x)
	_shake_time = SHAKE_DURATION
	# 震动主方向 = 后坐脉冲反方向（以 aim 方向为基准反向旋转 pulse 角）
	if aim_dir.length_squared() > 0.001:
		_shake_axis = aim_dir.rotated(deg_to_rad(-pulse))
	else:
		_shake_axis = Vector2.UP
	if gun != null:
		if _gun_tween != null and _gun_tween.is_valid():
			_gun_tween.kill()
		gun.position = Vector2(-MUZZLE_KICK * recoil.y, 0.0)
		_gun_tween = create_tween()
		_gun_tween.tween_property(gun, "position", Vector2.ZERO, GUN_RECOVER_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 枪口焰：开火瞬间闪现（放大 + 淡出），非开火时保持隐藏（避免"常驻枪口焰"观感）
const MUZZLE_FLASH_DURATION := 0.06

func _flash_muzzle() -> void:
	if muzzle_flash == null:
		return
	if _muzzle_tween != null and _muzzle_tween.is_valid():
		_muzzle_tween.kill()
	muzzle_flash.visible = true
	muzzle_flash.scale = Vector2(1.5, 1.5)
	muzzle_flash.modulate.a = 1.0
	_muzzle_tween = create_tween()
	_muzzle_tween.tween_property(muzzle_flash, "scale", Vector2.ONE, MUZZLE_FLASH_DURATION)
	_muzzle_tween.parallel().tween_property(muzzle_flash, "modulate:a", 0.0, MUZZLE_FLASH_DURATION)
	_muzzle_tween.tween_callback(func() -> void: muzzle_flash.visible = false)

## 受击检测：生命下降 → 机身闪红（0.18s 恢复）；仅响应本玩家事件（M2）
func _on_health_changed(event: PlayerHealthChangedEvent) -> void:
	if event.player_id != player_id:
		return
	if event.current < _last_health:
		_flash_hit()
	_last_health = event.current

## 敌人撞击伤害入口（EnemyView 经 has_method 调用，避免 PlayerView↔EnemyView 循环引用）
## 仅 host 模拟端有效（client 镜像无物理碰撞；host 权威结算）
func take_ram_hit(damage: float) -> void:
	if controller == null or controller.is_dead():
		return
	if position_mode != PositionMode.SIMULATED:
		return
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, damage)
	controller.take_damage(ctx)

func _flash_hit() -> void:
	if body == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	body.modulate = Color(1.0, 0.32, 0.32)
	_hit_tween = create_tween()
	_hit_tween.tween_property(body, "modulate", Color.WHITE, 0.18)

# ─── 移动（SIMULATED：物理模拟；SNAPSHOT：位置由快照驱动） ───

func _physics_process(delta: float) -> void:
	if controller == null:
		return
	if position_mode == PositionMode.SNAPSHOT:
		return  # 位置/朝向由 apply_snapshot 每帧置位
	if controller.is_incapacitated():
		velocity = Vector2.ZERO
	else:
		var speed := controller.attribute_set.get_final(AttributeSet.MOVE_SPEED)
		var dir := controller.move_direction
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
		velocity = velocity.move_toward(dir * speed, ACCELERATION * delta)
	move_and_slide()
	aim_marker.rotation = controller.aim_direction.angle()

# ─── 弹道执行（HITSCAN，后端验证后触发；散布为表现层手感） ───

## 开火事件：结算修正后数值（含配件/商店强化）→ 方向性后坐 → 多弹丸逐条射线
## M2：按 player_id 过滤（本视图只表现本玩家的开火；命中判定仅 host 真实敌人执行）
func _on_shot_fired(event: ShotFiredEvent) -> void:
	if event.player_id != player_id:
		return
	if controller == null or controller.weapon_slots == null:
		return
	# 修正后数值（含配件/商店强化）：伤害/暴击/散布/弹丸数/射程
	var stats := controller.weapon_slots.get_effective_stats(controller.weapon_slots.get_current_slot())
	# 手感系数（type.recoil）：从 model.type_id 查 type 数据（WeaponStats 不含 recoil）
	var recoil := Vector2.ONE
	var model: WeaponModelData = ContentBootstrap.get_entry(Bulwark.REG_WEAPON_MODEL, event.model_location)
	if model != null and not model.type_id.is_empty():
		var type_data: WeaponTypeData = ContentBootstrap.get_entry(Bulwark.REG_WEAPON_TYPE, model.type_id)
		if type_data != null:
			recoil = type_data.recoil

	# 每发后坐脉冲（随机方向，鸭科夫"瞄准点随机偏移"）；弹簧恢复由 _tick_gunplay 驱动
	var pulse := _rng.randf_range(-RECOIL_PER_SHOT, RECOIL_PER_SHOT) * recoil.x
	_recoil_angle += pulse
	# 移动时散布扩大（MOVE_SPEED 相关：意图移动即判定）
	var move_mult := MOVE_SPREAD_MULT if controller.move_direction.length_squared() > 0.001 else 1.0
	# 最终散布（度）=（基础 spread + 连射热度）× 移动倍率
	var total_spread := (stats.spread + _heat) * move_mult
	# 枪口实际方向 = aim_direction 旋转当前后坐角（准星与枪口分离的 2D 等价）
	var muzzle_dir := event.aim_direction.rotated(deg_to_rad(_recoil_angle))

	# 多弹丸（霰弹）：每颗弹丸独立 apply_spread + 独立射线，保证命中真实
	var pellets := maxi(1, stats.pellets)
	for _i in range(pellets):
		var dir := apply_spread(muzzle_dir, total_spread, _rng)
		_fire_ray(stats, dir)

	_apply_recoil_feedback(recoil, pulse, event.aim_direction)
	_flash_muzzle()

## 单条射线检测：命中 EnemyView 时回报伤害管道（伤害/暴击取自修正后 stats）
## client 镜像：命中 mirror 敌人无伤害（EnemyView.apply_player_hit 对无 controller 直接返回）
func _fire_ray(stats: WeaponStats, dir: Vector2) -> void:
	var from := global_position
	var to := from + dir * stats.range

	var query := PhysicsRayQueryParameters2D.create(from, to, TRACER_LAYER_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	var end := to
	if not hit.is_empty():
		end = hit.position
		var collider = hit.collider
		if collider is EnemyView:
			# 命中回报：enemy_view.apply_player_hit(stats: WeaponStats, ...) 已对齐，
			# 直接传修正后 stats（配件/商店强化经 WeaponStats 生效）
			collider.apply_player_hit(stats, dir)
	_show_tracer(from, end)

func _show_tracer(from: Vector2, to: Vector2) -> void:
	var tracer: Node2D = _tracer_pool.acquire()
	for child in tracer.get_children():
		var line := child as Line2D
		if line != null:
			line.points = PackedVector2Array([from, to])
	tracer.modulate.a = 1.0
	# 挂在世界层（全局坐标直接可用）
	get_parent().add_child(tracer)
	var tw := create_tween()
	tw.tween_property(tracer, "modulate:a", 0.0, TRACER_DURATION)
	tw.tween_callback(_release_tracer.bind(tracer))

func _release_tracer(tracer: Node2D) -> void:
	if not is_instance_valid(tracer):
		return
	if tracer.get_parent() != null:
		tracer.get_parent().remove_child(tracer)
	_tracer_pool.release(tracer)

# ─── 复活表现（M1：死亡倒地 / 复活中闪烁 / 复活完成复位；M2：按 player_id 过滤） ───

## 阵亡：Body 旋转 90° + 变暗 alpha 0.5 + 枪械隐藏
func _on_player_died(event: PlayerDiedEvent) -> void:
	if event.player_id != player_id:
		return
	# 终止受击闪红动画，避免其 tween 把倒地 alpha 0.5 渐变回不透明
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	if body != null:
		body.rotation = deg_to_rad(90.0)
		body.modulate = Color(1.0, 1.0, 1.0, 0.5)
	if gun != null:
		gun.visible = false
	if muzzle_flash != null:
		muzzle_flash.visible = false

## 复活 CD 开始（ReviveStartedEvent）：保持倒地 + 闪烁提示
func _on_revive_started(event: ReviveStartedEvent) -> void:
	if event.player_id != player_id:
		return
	_is_reviving_visual = true
	_blink_t = 0.0

## 复活完成（RevivedEvent）：Body 恢复旋转/颜色 + 枪械视觉复位（位置由 GameSession 重置）
func _on_revived(event: RevivedEvent) -> void:
	if event.player_id != player_id:
		return
	_is_reviving_visual = false
	if body != null:
		body.rotation = 0.0
		body.modulate = Color.WHITE
	_reset_gunplay_visual()

## 复活中闪烁：modulate.a 周期变化（约 5Hz），无论死活都跑（复活 CD 期间 state 为 DEAD）
func _tick_revive_blink(delta: float) -> void:
	if not _is_reviving_visual or body == null:
		return
	_blink_t += delta
	var a := 0.3 + 0.4 * (0.5 + 0.5 * sin(_blink_t * 10.0))
	body.modulate = Color(1.0, 1.0, 1.0, a)

## 枪械视觉复位：heat/recoil/震动归零 + 枪口位置/可见性恢复
func _reset_gunplay_visual() -> void:
	_heat = 0.0
	_recoil_angle = 0.0
	_shake_time = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO
	if gun != null:
		if _gun_tween != null and _gun_tween.is_valid():
			_gun_tween.kill()
		gun.position = Vector2.ZERO
		gun.visible = true
	if muzzle_flash != null:
		if _muzzle_tween != null and _muzzle_tween.is_valid():
			_muzzle_tween.kill()
		muzzle_flash.visible = false
		muzzle_flash.scale = Vector2.ONE
		muzzle_flash.modulate.a = 1.0
