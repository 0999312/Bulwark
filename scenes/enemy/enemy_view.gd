class_name EnemyView
extends CharacterBody2D
## 敌人表现层（前端）：NavigationAgent2D 寻路冲向基地 + 行为 FSM 驱动
## - 后端 EnemyController 决定状态（Chase/Attack/Dead），表现层执行移动
## - 受击入口 apply_player_hit：构造 DamageContext → 伤害管道（含阵营过滤，P30）
## - 撞击玩家（M0 修订）：接触玩家 → 玩家受击 + 本怪自爆（对齐原版撞击模型）
## - M1 路障优先：最近未摧毁路障进入攻击范围时优先攻击，否则仍冲基地
## - M1 小怪感：变种视觉（visual_scale/body_color）+ 受击闪白 + 死亡粒子爆发
## - M5a：按 ThreatMode 分派——自爆体撞击/贴近自爆；远程怪不啃路障；飞行体无视路障
## - M2 多人镜像：client 端 setup_mirror（无 AI/碰撞，位置/死亡由 host 快照驱动）；
##   net_id 为 host 分配的网络标识（快照同步键）

# ─── 表现常量 ───
const HIT_FLASH_DURATION := 0.1               # 受击闪白恢复时长（秒）
const HIT_FLASH_COLOR := Color(2.0, 2.0, 2.0) # 受击闪白峰值（超白）
const DEATH_FREE_MARGIN := 0.1                # 死亡粒子播完后的释放余量（秒）
## M3 问题 3：镜像快照**双缓冲线性插值**（匀速平滑、无指数插值的漂移感；
## 间隔须与 GameSession.ENEMIES_SNAPSHOT_INTERVAL（10Hz）同步）
const SNAPSHOT_INTERVAL := 0.1
## M3 问题 3：client 镜像死亡粒子降级倍率（真机带宽/CPU 开销放大时保帧率）
const MIRROR_PARTICLE_SCALE := 0.5

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var death_particles: CPUParticles2D = $DeathParticles

var controller: EnemyController
var target: Node2D
## 路障视图查询回调（GameSession 注入）：调用返回 Array[BarricadeView]
var barricade_query: Callable

## M2 多人：host 分配的敌人网络 id（client 镜像按此增删改）
var net_id := -1
## M2 多人镜像模式：无 AI/碰撞，位置与死亡由快照驱动
var mirror_mode := false

## M3 问题 3：镜像快照插值状态（双缓冲线性；首帧直接置位，去重时停留 target）
var _snap_prev := Vector2.ZERO
var _snap_target := Vector2.ZERO
var _snap_has_prev := false
var _snap_t := 1.0

var _died_freed := false
var _hit_tween: Tween
var _hit_scale_tween: Tween
var _knock_tween: Tween
var _base_visual_scale := 1.0

func setup(p_data: EnemyData, p_target: Node2D, p_barricade_query: Callable = Callable(),
		p_hp_scale: float = 1.0) -> void:
	controller = EnemyController.new(p_data, p_hp_scale)
	target = p_target
	barricade_query = p_barricade_query
	nav_agent.target_position = target.global_position
	_apply_visual(p_data)

## M2 镜像初始化（client）：仅视觉 + 死亡粒子；AI/碰撞/受击全部禁用
func setup_mirror(p_data: EnemyData) -> void:
	mirror_mode = true
	controller = null
	target = null
	_apply_visual(p_data)
	# Godot 4.7：NavigationAgent2D 无 enabled 属性（avoidance_enabled 仅控制避障），
	# mirror 不驱动导航（_physics_process 提前 return），无需再禁用
	nav_agent.avoidance_enabled = false
	collision_shape.set_deferred("disabled", true)

## 镜像置位（host 快照）；M3：双缓冲线性插值（新快照把当前 target 转 prev）
func apply_snapshot(pos: Vector2) -> void:
	if not mirror_mode:
		return
	if _snap_has_prev:
		_snap_prev = _snap_target
	else:
		# 首帧快照直接置位（避免从初始点滑入的"漂移"）
		_snap_prev = pos
		global_position = pos
		_snap_has_prev = true
	_snap_target = pos
	_snap_t = 0.0

## 镜像死亡（快照 dead 标记）：播放死亡粒子，播完自毁
func apply_dead_snapshot() -> void:
	if not mirror_mode or _died_freed:
		return
	_play_death_feedback()

func has_death_visual() -> bool:
	return _died_freed

func _physics_process(delta: float) -> void:
	if mirror_mode:
		# 镜像（controller 恒 null）：双缓冲线性插值——prev → target 在
		# SNAPSHOT_INTERVAL 内匀速推进，到达后停留等待下一快照
		# （必须置于 controller 检查之前：setup_mirror 置 null）
		if _snap_has_prev:
			_snap_t += delta / SNAPSHOT_INTERVAL
			global_position = _snap_prev.lerp(_snap_target, minf(_snap_t, 1.0))
		# M4 朝向：素材默认朝 +X；按插值位移方向旋转 Visual（与本体朝向一致）
		var move_dir := _snap_target - _snap_prev
		if move_dir.length_squared() > 4.0:
			visual.rotation = move_dir.angle()
		return  # 位置由快照驱动
	if controller == null:
		return
	if controller.is_dead():
		if not _died_freed:
			_died_freed = true
			_play_death_feedback()
		return

	var dist_to_base := global_position.distance_to(target.global_position)
	var barricade_view: BarricadeView = null
	if _should_target_barricades():
		barricade_view = _find_nearest_live_barricade()
	var barricade_controller: BarricadeController = null
	var distance_to_target := dist_to_base
	var target_pos := target.global_position
	if barricade_view != null:
		var dist_to_barricade := global_position.distance_to(barricade_view.global_position)
		if dist_to_barricade <= controller.data.attack_range:
			barricade_controller = barricade_view.controller
			distance_to_target = dist_to_barricade
			target_pos = barricade_view.global_position
	controller.tick(delta, distance_to_target, barricade_controller,
		global_position, target_pos, Vector2.RIGHT.rotated(visual.rotation))

	if controller.state == EnemyController.State.CHASE:
		nav_agent.target_position = target.global_position
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position).normalized()
		velocity = dir * controller.data.move_speed
		# M4 朝向：素材默认朝 +X，随移动方向旋转（修复"↓ 移动却朝 →"的 90° 错位）
		visual.rotation = dir.angle()
	else:
		velocity = Vector2.ZERO
		# 攻击/待机：面向“实际正在攻击的目标”——正在啃的路障 > 基地。
		# （不能用最近路障视图：它可能在攻击范围外，会让啃基地的怪侧身朝远处路障）
		var attack_target := target.global_position
		if barricade_controller != null and barricade_view != null:
			attack_target = barricade_view.global_position
		var face_dir := attack_target - global_position
		if face_dir.length_squared() > 1.0:
			visual.rotation = face_dir.angle()
	move_and_slide()
	_check_player_ram()

## 撞击玩家检测：接触玩家 → 玩家经伤害管道受击 + 本怪自爆（等同归于尽）
## 用 has_method 探测玩家（避免 PlayerView↔EnemyView 的 class_name 循环引用）
## M3 问题 4：自爆击杀归属 = 被撞玩家（killer_id 随 EnemyDiedEvent）
## M5a：自爆体撞击直接走 AoE（controller.explode），不再叠加单次撞击伤害
func _check_player_ram() -> void:
	if controller == null or controller.is_dead():
		return
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and collider.has_method("take_ram_hit"):
			if controller.data.threat_mode == EnemyData.ThreatMode.SELF_DESTRUCT:
				controller.explode(global_position)
				return
			collider.take_ram_hit(controller.data.attack_damage)
			var killer_id := 0
			if collider.get("player_id") != null:
				killer_id = int(collider.get("player_id"))
			controller.die(killer_id)
			return

## 玩家命中（HITSCAN 命中回报 → 伤害管道；来源 = 玩家阵营）
## M3 问题 4：killer_id = 射击者玩家（默认 0 = 单机/本地；随死亡事件供奖励归属）
## M3 修复：client 镜像敌人（mirror_mode，controller=null）命中只做闪白反馈
## （纯表现；伤害由 host 权威裁决——镜像不结算，否则会与 host 双重伤害）
func apply_player_hit(stats: WeaponStats, aim_dir: Vector2, killer_id: int = 0,
		weak_point_hit: bool = false) -> DamageResult:
	if mirror_mode:
		_flash_hit()
		return null
	if controller == null or controller.is_dead():
		return null
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, stats.damage)
	ctx.crit_chance = stats.crit_chance
	ctx.crit_multiplier = stats.crit_multiplier
	ctx.defense = controller.data.armor
	# M5a：精英弱点采用朝向判定（背部弱点）——从背后命中自动视为弱点
	var weak_hit := weak_point_hit
	if controller.data.has_weak_point and aim_dir.length_squared() > 0.001:
		var enemy_facing := Vector2.RIGHT.rotated(visual.rotation)
		if aim_dir.normalized().dot(enemy_facing) < 0.0:
			weak_hit = true
	var result := controller.take_damage(ctx, killer_id, aim_dir, weak_hit)
	if result != null and result.damage > 0.0:
		_flash_hit()
		_apply_hit_knock(aim_dir)
		_publish_health(result)
	return result

## M5b：自动炮塔命中（host 裁决；伤害管道同玩家命中，来源=玩家阵营）
func apply_turret_hit(damage: float, aim_dir: Vector2) -> DamageResult:
	if mirror_mode:
		_flash_hit()
		return null
	if controller == null or controller.is_dead():
		return null
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, damage)
	ctx.defense = controller.data.armor
	var result := controller.take_damage(ctx, 0, aim_dir)
	if result != null and result.damage > 0.0:
		_flash_hit()
		_apply_hit_knock(aim_dir)
		_publish_health(result)
	return result

## P1-13 精英/Boss 血量上报（host 权威；client 中继 → BossBar）
func _publish_health(_result: DamageResult) -> void:
	if controller == null or controller.data == null:
		return
	if not controller.data.is_elite and controller.data.threat_mode != EnemyData.ThreatMode.ELITE:
		return
	EventBus.publish(EnemyHealthChangedEvent.new(
		net_id,
		Bulwark.loc(controller.data.id).to_string(),
		controller.health,
		controller.max_health,
		true,
		global_position))

## 变种视觉：仅缩放 Body（碰撞体保持 1:1），并按 body_color 配色（含死亡粒子渐变）
func _apply_visual_variation() -> void:
	if controller == null or controller.data == null:
		return
	_apply_visual(controller.data)

func _apply_visual(p_data: EnemyData) -> void:
	if p_data == null:
		return
	_base_visual_scale = p_data.visual_scale
	body.scale = Vector2.ONE * _base_visual_scale
	# M4：Body 为 Sprite2D——基础配色走 modulate，受击闪白走 self_modulate（互不覆盖）
	body.modulate = p_data.body_color
	body.self_modulate = Color.WHITE
	var ramp := Gradient.new()
	ramp.add_point(0.0, p_data.body_color.lightened(0.35))
	ramp.add_point(1.0, p_data.body_color.darkened(0.35))
	death_particles.color_ramp = ramp
	# 游戏感改造：死亡粒子改为 8px 像素方块（颜色由 ramp 驱动），弃用高清软粒子贴图
	death_particles.texture = FxBurst.get_pixel_texture()
	death_particles.modulate = Color.WHITE
	death_particles.scale_amount_min = 0.5
	death_particles.scale_amount_max = 1.0
	_apply_outline(p_data)

## P1-14 敌人轮廓差异化：用 Kenney 坦克素材为 5 类威胁加装轮廓部件
## （装甲 = 铁甲底盘 / 狙击 = 长炮管 / 飞行 = 载具剪影 / 自爆 = 红色炸弹 / 精英 = 巨兽+弱点）
func _apply_outline(p_data: EnemyData) -> void:
	if p_data == null or visual == null:
		return
	var short := p_data.id.get_slice("enemy/", 1)
	match short:
		"armored":
			_add_outline_part(VfxBank.turret_base("dark"), 0.95,
				Color(0.35, 0.32, 0.38, 0.92), true, Vector2(0, 2), 0.0)
		"sniper":
			_add_outline_part(VfxBank.turret_barrel(2), 0.55,
				Color(0.5, 0.45, 0.42, 0.95), false, Vector2(16, 0), 0.0)
		"flying":
			_add_outline_part(VfxBank.tank_body_full("blue"), 0.62,
				Color(0.45, 0.55, 0.85, 0.75), true, Vector2(0, 3), 0.0)
		"self_destruct":
			_add_outline_part(VfxBank.bullet("red"), 2.2,
				Color(1.0, 0.3, 0.22, 0.9), true, Vector2(0, 1), 0.0)
		"elite_behemoth":
			_add_outline_part(VfxBank.tank_part("tank_huge"), 0.9,
				Color(0.62, 0.15, 0.16, 0.95), true, Vector2(0, 4), 0.0)
			# 背部弱点光点（视觉提示；与 data.has_weak_point 对应）
			var weak := Polygon2D.new()
			weak.polygon = PackedVector2Array([-3, -3, 3, -3, 3, 3, -3, 3])
			weak.color = Color(1.0, 0.25, 0.2, 0.95)
			weak.position = Vector2(-_base_visual_scale * 10.0, 0)
			visual.add_child(weak)
			visual.move_child(weak, 0)

func _add_outline_part(texture: Texture2D, scale_mult: float, color: Color,
		behind: bool, offset: Vector2, rotation_deg: float) -> void:
	if texture == null:
		return
	var part := Sprite2D.new()
	part.texture = texture
	part.scale = Vector2.ONE * (_base_visual_scale * scale_mult)
	part.modulate = color
	part.position = offset * _base_visual_scale
	part.rotation = deg_to_rad(rotation_deg)
	visual.add_child(part)
	if behind:
		visual.move_child(part, 0)

## 受击闪白（M3 方案 B：host 命中后经 EVT_ENEMY_HIT 驱动 client 镜像闪白；
## 本地命中路径仍由 apply_player_hit 调用）
func flash_hit() -> void:
	_flash_hit()

## 受击闪白：self_modulate 峰值超白后 0.1s 回白（对齐玩家/路障反馈模式）
## 游戏感改造：同步叠加“缩放重击”——命中瞬间 1.15 倍，0.12s 回弹
func _flash_hit() -> void:
	if body == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	body.self_modulate = HIT_FLASH_COLOR
	_hit_tween = create_tween()
	_hit_tween.tween_property(body, "self_modulate", Color.WHITE, HIT_FLASH_DURATION)
	if _hit_scale_tween != null and _hit_scale_tween.is_valid():
		_hit_scale_tween.kill()
	body.scale = Vector2.ONE * _base_visual_scale * 1.15
	_hit_scale_tween = create_tween()
	_hit_scale_tween.tween_property(body, "scale", Vector2.ONE * _base_visual_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 命中方向短促位移（视觉击退；不改变物理位置，host/client 镜像同表现）
func _apply_hit_knock(dir: Vector2) -> void:
	if visual == null or dir.length_squared() <= 0.001:
		return
	if _knock_tween != null and _knock_tween.is_valid():
		_knock_tween.kill()
	visual.position = dir.normalized() * 3.0
	_knock_tween = create_tween()
	_knock_tween.tween_property(visual, "position", Vector2.ZERO, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 死亡反馈：缩放爆点 → 像素粒子爆发 + 冲击环 + 闪光 → 释放
## 游戏感改造：先“炸开”再“散落”（anticipation → impact → aftermath）
## M3：client 镜像死亡粒子按 MIRROR_PARTICLE_SCALE 降量（真机性能保帧）
func _play_death_feedback() -> void:
	if body != null:
		if _hit_tween != null and _hit_tween.is_valid():
			_hit_tween.kill()
		if _hit_scale_tween != null and _hit_scale_tween.is_valid():
			_hit_scale_tween.kill()
		var pop := create_tween()
		pop.set_parallel(true)
		pop.tween_property(body, "scale", Vector2.ONE * _base_visual_scale * 1.35, 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(body, "modulate:a", 0.0, 0.1)
		pop.tween_callback(func() -> void: body.visible = false)
	collision_shape.set_deferred("disabled", true)
	if mirror_mode and Net.is_client():
		death_particles.amount = maxi(2, roundi(death_particles.amount * MIRROR_PARTICLE_SCALE))
	death_particles.restart()
	death_particles.emitting = true
	# P1-15 死亡爆炸 5 帧动画（Tier2；池化，host/client 同表现）
	FxBurst.spawn_explosion(global_position, maxf(1.2, _base_visual_scale * 1.6))
	# M4：死亡爆炸闪光（池化，host/client 同播；粒子数量本身已按镜像降级）
	FxBurst.spawn_flare(global_position)
	var tw := create_tween()
	tw.tween_interval(death_particles.lifetime + DEATH_FREE_MARGIN)
	tw.tween_callback(queue_free)

## M5a：哪些威胁模式按近战路障优先（远程/自爆/飞行不啃路障）
func _should_target_barricades() -> bool:
	if controller == null or controller.data == null:
		return false
	if controller.data.ignores_barricades:
		return false
	return controller.data.threat_mode in [
		EnemyData.ThreatMode.RUNNER,
		EnemyData.ThreatMode.ARMORED,
		EnemyData.ThreatMode.ELITE,
	]

## 找最近未摧毁路障（BarricadeView.controller 已注入且 !is_destroyed()）
func _find_nearest_live_barricade() -> BarricadeView:
	if barricade_query.is_null():
		return null
	var views: Array[BarricadeView] = barricade_query.call()
	var nearest: BarricadeView = null
	var nearest_dist_sq := INF
	for view: BarricadeView in views:
		if view == null or not is_instance_valid(view):
			continue
		if view.controller == null or view.controller.is_destroyed():
			continue
		var d_sq := global_position.distance_squared_to(view.global_position)
		if d_sq < nearest_dist_sq:
			nearest_dist_sq = d_sq
			nearest = view
	return nearest
