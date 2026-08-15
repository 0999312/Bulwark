class_name EnemyView
extends CharacterBody2D
## 奔跑者表现层（前端）：NavigationAgent2D 寻路冲向基地 + 行为 FSM 驱动
## - 后端 RunnerController 决定状态（Chase/Attack/Dead），表现层执行移动
## - 受击入口 apply_player_hit：构造 DamageContext → 伤害管道（含阵营过滤，P30）
## - 撞击玩家（M0 修订）：接触玩家 → 玩家受击 + 本怪自爆（对齐原版撞击模型）
## - M1 路障优先：最近未摧毁路障进入攻击范围时优先攻击，否则仍冲基地
## - M1 小怪感：变种视觉（visual_scale/body_color）+ 受击闪白 + 死亡粒子爆发
## - M2 多人镜像：client 端 setup_mirror（无 AI/碰撞，位置/死亡由 host 快照驱动）；
##   net_id 为 host 分配的网络标识（快照同步键）

# ─── 表现常量 ───
const HIT_FLASH_DURATION := 0.1               # 受击闪白恢复时长（秒）
const HIT_FLASH_COLOR := Color(2.0, 2.0, 2.0) # 受击闪白峰值（超白）
const DEATH_FREE_MARGIN := 0.1                # 死亡粒子播完后的释放余量（秒）

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var body: Polygon2D = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var death_particles: CPUParticles2D = $DeathParticles

var controller: RunnerController
var target: Node2D
## 路障视图查询回调（GameSession 注入）：调用返回 Array[BarricadeView]
var barricade_query: Callable

## M2 多人：host 分配的敌人网络 id（client 镜像按此增删改）
var net_id := -1
## M2 多人镜像模式：无 AI/碰撞，位置与死亡由快照驱动
var mirror_mode := false

var _died_freed := false
var _hit_tween: Tween

func setup(p_data: EnemyData, p_target: Node2D, p_barricade_query: Callable = Callable(),
		p_hp_scale: float = 1.0) -> void:
	controller = RunnerController.new(p_data, p_hp_scale)
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
	nav_agent.enabled = false
	collision_shape.set_deferred("disabled", true)

## 镜像置位（host 快照）
func apply_snapshot(pos: Vector2) -> void:
	if not mirror_mode:
		return
	global_position = pos

## 镜像死亡（快照 dead 标记）：播放死亡粒子，播完自毁
func apply_dead_snapshot() -> void:
	if not mirror_mode or _died_freed:
		return
	_play_death_feedback()

func has_death_visual() -> bool:
	return _died_freed

func _physics_process(delta: float) -> void:
	if controller == null:
		return
	if mirror_mode:
		return  # 位置由快照驱动
	if controller.is_dead():
		if not _died_freed:
			_died_freed = true
			_play_death_feedback()
		return

	var dist_to_base := global_position.distance_to(target.global_position)
	var barricade_view := _find_nearest_live_barricade()
	var barricade_controller: BarricadeController = null
	var distance_to_target := dist_to_base
	if barricade_view != null:
		var dist_to_barricade := global_position.distance_to(barricade_view.global_position)
		if dist_to_barricade <= controller.data.attack_range:
			barricade_controller = barricade_view.controller
			distance_to_target = dist_to_barricade
	controller.tick(delta, distance_to_target, barricade_controller)

	if controller.state == RunnerController.State.CHASE:
		nav_agent.target_position = target.global_position
		var next_pos := nav_agent.get_next_path_position()
		var dir := (next_pos - global_position).normalized()
		velocity = dir * controller.data.move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_check_player_ram()

## 撞击玩家检测：接触玩家 → 玩家经伤害管道受击 + 本怪自爆（等同归于尽）
## 用 has_method 探测玩家（避免 PlayerView↔EnemyView 的 class_name 循环引用）
func _check_player_ram() -> void:
	if controller == null or controller.is_dead():
		return
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and collider.has_method("take_ram_hit"):
			collider.take_ram_hit(controller.data.attack_damage)
			controller.die()
			return

## 玩家命中（HITSCAN 命中回报 → 伤害管道；来源 = 玩家阵营）
func apply_player_hit(stats: WeaponStats, _aim_dir: Vector2) -> void:
	if controller == null or controller.is_dead():
		return
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, stats.damage)
	ctx.crit_chance = stats.crit_chance
	ctx.crit_multiplier = stats.crit_multiplier
	ctx.defense = controller.data.armor
	var result := controller.take_damage(ctx)
	if result.damage > 0.0:
		_flash_hit()

## 变种视觉：仅缩放 Body（碰撞体保持 1:1），并按 body_color 配色（含死亡粒子渐变）
func _apply_visual_variation() -> void:
	if controller == null or controller.data == null:
		return
	_apply_visual(controller.data)

func _apply_visual(p_data: EnemyData) -> void:
	if p_data == null:
		return
	body.scale = Vector2.ONE * p_data.visual_scale
	body.color = p_data.body_color
	var ramp := Gradient.new()
	ramp.add_point(0.0, p_data.body_color.lightened(0.35))
	ramp.add_point(1.0, p_data.body_color.darkened(0.35))
	death_particles.color_ramp = ramp

## 受击闪白：self_modulate 峰值超白后 0.1s 回白（对齐玩家/路障反馈模式）
func _flash_hit() -> void:
	if body == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	body.modulate = HIT_FLASH_COLOR
	_hit_tween = create_tween()
	_hit_tween.tween_property(body, "modulate", Color.WHITE, HIT_FLASH_DURATION)

## 死亡反馈：隐藏本体 + 禁用碰撞 + 播放一次性粒子，播完后释放
func _play_death_feedback() -> void:
	body.visible = false
	collision_shape.set_deferred("disabled", true)
	death_particles.restart()
	death_particles.emitting = true
	var tw := create_tween()
	tw.tween_interval(death_particles.lifetime + DEATH_FREE_MARGIN)
	tw.tween_callback(queue_free)

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
