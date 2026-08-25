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
## M3 问题 3：快照渲染插值——采用**双缓冲线性插值**（网络同步标准做法）：
## 渲染位置 = 上一快照点 → 当前快照点按时间线性推进；匀速运动完美平滑、
## 零滞后、无指数插值的"漂移/橡皮筋"感。间隔须与 GameSession.SNAPSHOT_INTERVAL（20Hz）同步
const SNAPSHOT_INTERVAL := 0.05

## ─── 枪械手感参数（M1：鸭科夫式 2D 俯视角适配，草案见 gunplay-attachment-notes.md §3）───
const RECOIL_PER_SHOT := 0.6      # 每发后坐脉冲（度，乘 type.recoil.x）
const RECOIL_RECOVER_SPEED := 3.0 # 后坐角弹簧恢复速度（度/秒，向 0 收敛）
const MOVE_SPREAD_MULT := 1.5     # 移动时散布倍率（裁决侧使用，见 GameSession._on_shot_fired）
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

@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var muzzle_flash: Sprite2D = $Visual/MuzzleFlash
@onready var camera: Camera2D = $Camera2D

var controller: PlayerController
var actions: Dictionary = {}  # StringName -> GUIDEAction（与 GUIDE 启用上下文同实例）

## M2 多人身份/模式（GameSession 装配时设置）
var player_id := 0
var role := Role.LOCAL
var position_mode := PositionMode.SIMULATED

## ─── M4 Kenney 姿势库（表现层贴图状态机；D-M4-6） ───
## 纹理按 视觉包前缀（soldier1/manBlue）+ 姿势名 动态 load；offset 用像素质心与画布中心差
## 对齐脚底/身体中心（俯视角单帧素材，切换帧时视觉不跳动）。
enum Pose { STAND, HOLD, GUN, MACHINE, RELOAD }
const POSE_NAMES := ["stand", "hold", "gun", "machine", "reload"]
## 视觉包 → 固定枢轴偏移（质心-中心，像素；取自 stand 帧的身体中心）。
## 所有姿势共用同一枢轴：旋转时轴点始终落在角色躯干上，切帧不跳动（D-M4-6 修订）。
const POSE_OFFSETS := {
	"soldier1": Vector2(-2.9, -0.5),
	"manBlue": Vector2(-2.2, -0.5),
}
## 枪口焰局部位置（枪口基线朝 +X；以固定枢轴为原点，machine/gun 帧枪口实测）
const MUZZLE_LOCAL_POS := Vector2(22.0, 7.0)

var visual_pack := "soldier1"
var _pose_textures: Dictionary = {}
var _pivot_offset := Vector2.ZERO
var _current_pose: int = Pose.STAND
var _pose_reload_timer := 0.0
var _pose_switch_timer := 0.0

var _tracer_pool: ObjectPool
var _recoil_angle := 0.0       # 后坐角（度）：每发脉冲累积，弹簧向 0 恢复
var _shake_time := 0.0         # 相机震动剩余时间（秒）
var _shake_axis := Vector2.ZERO # 震动主方向（后坐脉冲反方向单位向量）
var _gun_tween: Tween          # 枪口回退恢复动画
var _hit_tween: Tween          # 受击闪红动画
var _muzzle_tween: Tween       # 枪口焰闪现动画
var _last_health := -1.0       # 上一帧生命（受击检测）
var _rng := RandomNumberGenerator.new()
## M3 问题 3：快照插值状态（双缓冲线性）——
## _snap_prev/_snap_target = 上一/当前快照点；_snap_t = 当前快照周期内插值进度
## 首帧快照直接置位（无插值滑入）；去重（位置未变）不更新时停留在 target
var _snap_prev := Vector2.ZERO
var _snap_target := Vector2.ZERO
var _snap_has_prev := false
var _snap_t := 1.0

## M3 本地预测（方向 B）：client 本地玩家 SIMULATED 本地模拟 + 快照校正。
## host 权威位置与本地预测位置的偏差小于该阈值时视为"预测领先"（不校正，保持手感）；
## 超过阈值（host 端碰撞/路障阻挡/复活重置等权威差异）→ 平滑拉回
const PREDICTION_CORRECTION_DISTANCE := 80.0
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
	_build_pose_library()
	if muzzle_flash != null:
		muzzle_flash.texture = VfxBank.muzzle("orange")
		muzzle_flash.position = MUZZLE_LOCAL_POS
	EventBus.subscribe(&"ShotFiredEvent", _on_shot_fired)
	EventBus.subscribe(&"PlayerHealthChangedEvent", _on_health_changed)
	EventBus.subscribe(&"PlayerDiedEvent", _on_player_died)
	EventBus.subscribe(&"ReviveStartedEvent", _on_revive_started)
	EventBus.subscribe(&"RevivedEvent", _on_revived)
	# M4 姿势库：切枪/换弹事件驱动 hold/reload 帧
	EventBus.subscribe(&"WeaponSwitchedEvent", _on_weapon_switched)
	EventBus.subscribe(&"ReloadStartedEvent", _on_reload_started)
	EventBus.subscribe(&"WeaponSwitchStartedEvent", _on_switch_started)
	_update_pose()

## M4 视觉包（GameSession 装配后调用：0 = Soldier1 绿；1 = ManBlue 蓝，分类可读 D-M4-6）
func set_visual_pack(pack: String) -> void:
	visual_pack = pack
	_build_pose_library()
	# 强制刷新：_update_pose 对相同 pose 会提前返回，必须打破缓存避免
	# “玩家 2 已经切包却仍显示玩家 1 贴图”的初始帧错位（M4.2 反馈修复）
	_current_pose = -1
	_update_pose()

func _build_pose_library() -> void:
	_pose_textures.clear()
	for pose_name: String in POSE_NAMES:
		var tex := load("res://assets/sprites/chars/%s_%s.png" % [visual_pack, pose_name])
		if tex != null:
			_pose_textures[pose_name] = tex
	_pivot_offset = POSE_OFFSETS.get(visual_pack, POSE_OFFSETS["soldier1"])

func _on_weapon_switched(event: WeaponSwitchedEvent) -> void:
	if event.player_id == player_id:
		_pose_switch_timer = 0.0
		_update_pose()

func _on_reload_started(event: ReloadStartedEvent) -> void:
	if event.player_id == player_id:
		_pose_reload_timer = event.duration
		_update_pose()

func _on_switch_started(event: WeaponSwitchStartedEvent) -> void:
	if event.player_id == player_id:
		_pose_switch_timer = event.switch_cd
		_update_pose()

## 姿势裁决：死亡 > 换弹 > 切枪 > 槽位类型（MAIN/SUB=machine，PISTOL=gun，空=stand）
func _update_pose() -> void:
	if body == null or controller == null:
		return
	var pose := Pose.STAND
	if controller.is_incapacitated():
		pose = Pose.STAND
	elif _pose_reload_timer > 0.0:
		pose = Pose.RELOAD
	elif _pose_switch_timer > 0.0:
		pose = Pose.HOLD
	elif controller.weapon_slots != null and controller.weapon_slots.is_current_pistol():
		pose = Pose.GUN
	elif controller.weapon_slots != null \
			and controller.weapon_slots.get_current_slot().type_data != null:
		pose = Pose.MACHINE
	if pose == _current_pose:
		return
	_current_pose = pose
	var pose_name: String = POSE_NAMES[pose]
	if _pose_textures.has(pose_name):
		body.texture = _pose_textures[pose_name]
	body.offset = _pivot_offset

## M2 多人：装配身份与模式（GameSession 在 setup 后调用）
## M3 问题 1：显式相机归属——每进程只允许一个活跃相机（本地玩家视图）。
## Camera2D 语义为「最后 enabled 者成为当前相机」：若不管理，远端镜像视图的
## 相机（默认 enabled）会抢走镜头归属。LOCAL → enabled + make_current；
## REMOTE/NONE → 禁用（镜头只跟随各自进程的本地玩家）。
func set_role(p_role: Role, p_position_mode: PositionMode) -> void:
	role = p_role
	position_mode = p_position_mode
	if camera == null:
		return
	if role == Role.LOCAL:
		camera.enabled = true
		camera.zoom = Vector2.ONE * AppConfig.get_camera_zoom()
		camera.make_current()
	else:
		camera.enabled = false

func set_player_id(p_id: int) -> void:
	player_id = p_id

## M3 本地预测：host 权威位置校正（client 本地玩家 SIMULATED 模式，每快照调用）。
## 偏差 ≤ 阈值 → 预测领先，保持本地模拟（输入即时生效的手感不被每帧拉回破坏）；
## 偏差 > 阈值 → 向权威位置平滑收敛（避免瞬移跳变）
func apply_prediction_correction(authority_pos: Vector2) -> void:
	if position_mode != PositionMode.SIMULATED:
		return
	if global_position.distance_to(authority_pos) > PREDICTION_CORRECTION_DISTANCE:
		# 每快照周期向权威位置收敛 50%（两次快照 ≈ 75%，连续收敛无跳变）
		global_position = global_position.lerp(authority_pos, 0.5)

## 快照置位（client 端 SNAPSHOT 玩家每帧调用；host 端 SIMULATED 忽略）
## M3：双缓冲线性插值——新快照把当前 target 转 prev，渲染位置按时间推进
func apply_snapshot(pos: Vector2, aim_angle: float) -> void:
	if position_mode != PositionMode.SNAPSHOT:
		return
	if _snap_has_prev:
		_snap_prev = _snap_target
	else:
		# 首帧快照：直接置位（避免从初始点滑入的"漂移"）
		_snap_prev = pos
		global_position = pos
		_snap_has_prev = true
	_snap_target = pos
	_snap_t = 0.0
	if visual != null:
		visual.rotation = aim_angle

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
	# P1-15 玩家弹体：Kenney bulletGreen（沿弹道方向旋转；素材默认朝上）
	var bullet := Sprite2D.new()
	bullet.texture = VfxBank.bullet("green")
	bullet.scale = Vector2(2.2, 2.2)
	tracer.add_child(bullet)
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
		# 鼠标纯自由瞄准（P9）：get_global_mouse_position 自动包含 Camera2D 变换
		# （旧实现用 viewport canvas transform，不含相机平移/缩放，瞄准方向完全错位）
		# 本机多窗口：键盘/鼠标输入属于有焦点的窗口，双端单套键位即可（M2 修订）
		var aim := get_global_mouse_position() - global_position
		controller.set_aim_direction(aim)
		if Net.is_client():
			Net.send_intent(&"aim", [aim.normalized()])
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
	if slot < 0:
		return
	controller.intent_switch(slot)
	if Net.is_client():
		Net.send_intent(&"switch", [slot])

# ─── 枪械手感（表现层：热度/后坐恢复 / 方向化相机震动 / 枪口后坐） ───

## 每帧驱动：后坐角弹簧恢复 + 相机震动残影（无论死活都跑，保证视觉恢复）
func _tick_gunplay(delta: float) -> void:
	if _pose_reload_timer > 0.0:
		_pose_reload_timer = maxf(0.0, _pose_reload_timer - delta)
		if _pose_reload_timer <= 0.0:
			_update_pose()
	if _pose_switch_timer > 0.0:
		_pose_switch_timer = maxf(0.0, _pose_switch_timer - delta)
		if _pose_switch_timer <= 0.0:
			_update_pose()
	if absf(_recoil_angle) > 0.01:
		_recoil_angle = move_toward(_recoil_angle, 0.0, RECOIL_RECOVER_SPEED * delta)
	else:
		_recoil_angle = 0.0
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		# M3：相机震动仅作用于启用的本地相机（远端镜像视图相机已禁用，跳过避免无效偏移）
		if camera != null and camera.enabled:
			# 方向化震动：主分量沿后坐反方向（_shake_axis），幅度随时间衰减，叠加少量随机抖动
			var amp := SHAKE_AMPLITUDE * (_shake_time / SHAKE_DURATION)
			camera.offset = _shake_axis * amp \
				+ Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp)) * 0.3
	elif camera != null and camera.enabled and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

## 每发子弹的手感反馈：方向化相机震动 + 枪口回退（纯表现，不影响后端命中判定）
func _apply_recoil_feedback(recoil: Vector2, pulse: float, aim_dir: Vector2) -> void:
	_shake_time = SHAKE_DURATION
	# 震动主方向 = 后坐脉冲反方向（以 aim 方向为基准反向旋转 pulse 角）
	if aim_dir.length_squared() > 0.001:
		_shake_axis = aim_dir.rotated(deg_to_rad(-pulse))
	else:
		_shake_axis = Vector2.UP
	if visual != null:
		if _gun_tween != null and _gun_tween.is_valid():
			_gun_tween.kill()
		# M4：整枪视觉沿瞄准反方向回退（Visual 已旋转到 aim，局部 -X = 反冲方向）
		visual.position = Vector2(-MUZZLE_KICK * recoil.y, 0.0)
		_gun_tween = create_tween()
		_gun_tween.tween_property(visual, "position", Vector2.ZERO, GUN_RECOVER_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 枪口焰：开火瞬间闪现（放大 + 淡出），非开火时保持隐藏（避免"常驻枪口焰"观感）
const MUZZLE_FLASH_DURATION := 0.06

func _flash_muzzle() -> void:
	if muzzle_flash == null:
		return
	if _muzzle_tween != null and _muzzle_tween.is_valid():
		_muzzle_tween.kill()
	muzzle_flash.visible = true
	# Kenney shotOrange（Default size 16×28）：0.38→0.18 缩放拍成短闪现（与 32px 角色匹配）
	muzzle_flash.scale = Vector2(0.38, 0.38)
	muzzle_flash.modulate = Color(1.0, 0.92, 0.7, 1.0)
	_muzzle_tween = create_tween()
	_muzzle_tween.tween_property(muzzle_flash, "scale", Vector2(0.18, 0.18), MUZZLE_FLASH_DURATION)
	_muzzle_tween.parallel().tween_property(muzzle_flash, "modulate:a", 0.0, MUZZLE_FLASH_DURATION)
	_muzzle_tween.tween_callback(func() -> void: muzzle_flash.visible = false)

## 受击检测：生命下降 → 机身闪红 + 受击震屏（0.18s 恢复）；仅响应本玩家事件（M2）
func _on_health_changed(event: PlayerHealthChangedEvent) -> void:
	if event.player_id != player_id:
		return
	if event.current < _last_health:
		_flash_hit()
		_apply_hit_shake()
	_last_health = event.current

## 受击震屏：复用方向化震动通道，主方向随机，幅度与单发后坐一致
func _apply_hit_shake() -> void:
	_shake_time = SHAKE_DURATION * 1.4
	_shake_axis = Vector2.UP.rotated(_rng.randf_range(0.0, TAU))

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
		# 双缓冲线性插值：prev → target 在 SNAPSHOT_INTERVAL 内匀速推进；
		# 到达后停在 target 等待下一快照（去重不更新时无抖动）
		if _snap_has_prev:
			_snap_t += delta / SNAPSHOT_INTERVAL
			global_position = _snap_prev.lerp(_snap_target, minf(_snap_t, 1.0))
		return  # 位置/朝向由快照驱动
	if controller.is_incapacitated():
		velocity = Vector2.ZERO
	else:
		var speed := controller.attribute_set.get_final(AttributeSet.MOVE_SPEED)
		var dir := controller.move_direction
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
		velocity = velocity.move_toward(dir * speed, ACCELERATION * delta)
	move_and_slide()
	if visual != null:
		visual.rotation = controller.aim_direction.angle()

# ─── 弹道执行（HITSCAN，后端验证后触发；散布为表现层手感） ───

## 开火事件：结算修正后数值（含配件/商店强化）→ 方向性后坐 → 枪口反馈
## M2：按 player_id 过滤（本视图只表现本玩家的开火）
## M3 方案 B：命中判定/伤害/tracer 由 GameSession（装配层）用 core 几何判定统一裁决，
## 本视图只保留即时手感反馈（后坐/震屏/枪口焰）；tracer 由裁决侧 show_tracer 驱动
func _on_shot_fired(event: ShotFiredEvent) -> void:
	if event.player_id != player_id:
		return
	if controller == null or controller.weapon_slots == null:
		return
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
	_apply_recoil_feedback(recoil, pulse, event.aim_direction)
	_flash_muzzle()

## M3 方案 B：tracer 由裁决侧（GameSession）驱动——起点/终点均为裁决几何结果，
## 表现层不自行发射线（client 镜像无碰撞的"子弹穿身"问题由此消除）
func show_tracer(from: Vector2, _dir: Vector2, hit_point: Vector2) -> void:
	_show_tracer(from, hit_point)

func _show_tracer(from: Vector2, to: Vector2) -> void:
	var tracer: Node2D = _tracer_pool.acquire()
	for child in tracer.get_children():
		var line := child as Line2D
		if line != null:
			line.points = PackedVector2Array([from, to])
		elif child is Sprite2D:
			# P1-15：弹体精灵按弹道方向旋转并从出膛点出发（素材默认朝上 → +PI/2）
			var bullet := child as Sprite2D
			bullet.global_position = from
			bullet.rotation = (to - from).angle() + PI * 0.5
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
	if muzzle_flash != null:
		muzzle_flash.visible = false
	_update_pose()

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
	_update_pose()

## 复活中闪烁：modulate.a 周期变化（约 5Hz），无论死活都跑（复活 CD 期间 state 为 DEAD）
func _tick_revive_blink(delta: float) -> void:
	if not _is_reviving_visual or body == null:
		return
	_blink_t += delta
	var a := 0.3 + 0.4 * (0.5 + 0.5 * sin(_blink_t * 10.0))
	body.modulate = Color(1.0, 1.0, 1.0, a)

## 枪械视觉复位：recoil/震动归零 + 枪口位置/可见性恢复
func _reset_gunplay_visual() -> void:
	_recoil_angle = 0.0
	_shake_time = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO
	if visual != null:
		if _gun_tween != null and _gun_tween.is_valid():
			_gun_tween.kill()
		visual.position = Vector2.ZERO
	if muzzle_flash != null:
		if _muzzle_tween != null and _muzzle_tween.is_valid():
			_muzzle_tween.kill()
		muzzle_flash.visible = false
		muzzle_flash.scale = Vector2.ONE
		muzzle_flash.modulate.a = 1.0
