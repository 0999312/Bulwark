class_name EnemyView
extends CharacterBody2D
## 奔跑者表现层（前端）：NavigationAgent2D 寻路冲向基地 + 行为 FSM 驱动
## - 后端 RunnerController 决定状态（Chase/Attack/Dead），表现层执行移动
## - 受击入口 apply_player_hit：构造 DamageContext → 伤害管道（含阵营过滤，P30）
## - 撞击玩家（M0 修订）：接触玩家 → 玩家受击 + 本怪自爆（对齐原版撞击模型）

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var controller: RunnerController
var target: Node2D

var _died_freed := false

func setup(p_data: EnemyData, p_target: Node2D) -> void:
	controller = RunnerController.new(p_data)
	target = p_target
	nav_agent.target_position = target.global_position

func _physics_process(delta: float) -> void:
	if controller == null:
		return
	if controller.is_dead():
		if not _died_freed:
			_died_freed = true
			queue_free()
		return

	var dist := global_position.distance_to(target.global_position)
	controller.tick(delta, dist)

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
func apply_player_hit(model: WeaponModelData, _aim_dir: Vector2) -> void:
	if controller == null or controller.is_dead():
		return
	var ctx := DamageContext.create(Faction.Type.PLAYER, Faction.Type.MUTANT, model.damage)
	ctx.crit_chance = model.crit_chance
	ctx.crit_multiplier = model.crit_multiplier
	ctx.defense = controller.data.armor
	controller.take_damage(ctx)
