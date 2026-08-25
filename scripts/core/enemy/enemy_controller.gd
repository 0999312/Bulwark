class_name EnemyController
extends RefCounted
## 敌人后端控制器（纯逻辑，headless 可测）
## 由 RunnerController 泛化而来 → 按 ThreatMode 分派行为：
## - RUNNER / ARMORED / ELITE：近战冲锋，优先啃路障，否则啃基地
## - SELF_DESTRUCT：贴近后自爆，广播 EnemyAoEEvent（host 逻辑命中 + 事件驱动视觉）
## - SPITTER / SNIPER：远程弹幕，广播 EnemyRangedAttackEvent（host 逻辑命中 + 事件驱动视觉弹体）
## - FLYING：无视路障，直扑基地
## 伤害管道：方向护甲（装甲兽）、弱点（精英·巨兽）在 take_damage 中透传。

enum State {
	CHASE = 0,
	ATTACK = 1,
	DEAD = 2,
}

## 方向护甲正面判定阈值（点积 >= 0.5 视为正面）
const FRONTAL_DOT_THRESHOLD := 0.5

var data: EnemyData
var health: float = 0.0
var max_health: float = 0.0
var state: State = State.CHASE
var attack_timer: float = 0.0
## 当前攻击目标（近战：路障优先；null = 基地）
var attacking_barricade: BarricadeController = null
## 当前朝向（方向护甲用；由表现层每帧喂入，默认朝 +X）
var facing_direction: Vector2 = Vector2.RIGHT

var _dead_reported := false

## p_hp_scale：双人强度缩放（M2，EnemyData.player_count_scale；单机默认 1.0 不缩放）
func _init(p_data: EnemyData, p_hp_scale: float = 1.0) -> void:
	data = p_data
	health = data.max_hp * maxf(p_hp_scale, 0.01)
	max_health = health
	# 首次出招前给玩家一个完整攻击间隔的反应时间（不再落地即咬）
	attack_timer = data.attack_interval
	if data.windup_time > 0.0:
		attack_timer += data.windup_time

func is_dead() -> bool:
	return state == State.DEAD

## 每帧驱动；distance_to_target = 到当前目标距离（表现层提供：路障或基地）
## barricade：可选路障（有效且未摧毁时优先攻击）；null = 攻击基地
## origin/target_pos/facing：事件与方向护甲所需（纯逻辑不持有节点，由表现层喂入）
func tick(delta: float, distance_to_target: float, barricade: BarricadeController = null,
		origin: Vector2 = Vector2.ZERO, target_pos: Vector2 = Vector2.ZERO,
		facing: Vector2 = Vector2.RIGHT) -> void:
	if state == State.DEAD:
		return
	if facing.length_squared() > 0.001:
		facing_direction = facing.normalized()

	# 路障优先（近战型）：目标是路障且已摧毁 → 转为冲基地（下一次 tick 重新判定距离）
	if _can_attack_barricades():
		if barricade == null or barricade.is_destroyed():
			attacking_barricade = null
		else:
			attacking_barricade = barricade
	else:
		attacking_barricade = null

	match data.threat_mode:
		EnemyData.ThreatMode.SELF_DESTRUCT:
			_tick_self_destruct(delta, distance_to_target, origin)
		EnemyData.ThreatMode.SPITTER, EnemyData.ThreatMode.SNIPER:
			_tick_ranged(delta, distance_to_target, origin, target_pos)
		_:
			_tick_melee(delta, distance_to_target)

## 是否按近战逻辑优先攻击路障（远程/自爆/飞行不啃路障）
func _can_attack_barricades() -> bool:
	if data == null:
		return false
	if data.ignores_barricades:
		return false
	return data.threat_mode in [
		EnemyData.ThreatMode.RUNNER,
		EnemyData.ThreatMode.ARMORED,
		EnemyData.ThreatMode.ELITE,
	]

func _tick_melee(delta: float, distance_to_target: float) -> void:
	if distance_to_target <= data.attack_range:
		if state != State.ATTACK:
			state = State.ATTACK
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = data.attack_interval
			var target := ""
			if attacking_barricade != null:
				target = attacking_barricade.get_location()
			EventBus.publish(EnemyAttackEvent.new(
				data.attack_damage, Bulwark.loc(data.id).to_string(), target))
	else:
		if state != State.CHASE:
			state = State.CHASE
			attack_timer = data.attack_interval
			if data.windup_time > 0.0:
				attack_timer += data.windup_time

func _tick_ranged(delta: float, distance_to_target: float,
		origin: Vector2, target_pos: Vector2) -> void:
	if distance_to_target <= data.attack_range:
		if state != State.ATTACK:
			state = State.ATTACK
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = data.attack_interval
			if data.windup_time > 0.0:
				attack_timer += data.windup_time
			_fire_ranged(origin, target_pos, distance_to_target)
	else:
		if state != State.CHASE:
			state = State.CHASE
			attack_timer = data.attack_interval
			if data.windup_time > 0.0:
				attack_timer += data.windup_time

func _fire_ranged(origin: Vector2, target_pos: Vector2, distance_to_target: float = 0.0) -> void:
	var projectile_kind := "spit"
	if data.threat_mode == EnemyData.ThreatMode.SNIPER:
		projectile_kind = "snipe"
	var target := target_pos
	# 基地可能就在世界原点 (0,0)，不能把 ZERO 当作“无目标”哨兵；
	# 仅当表现层确实没喂目标时，才按当前朝向与距离推导落点。
	if target == Vector2.ZERO:
		var dir := facing_direction
		if dir.length_squared() <= 0.001:
			dir = Vector2.RIGHT
		target = origin + dir.normalized() * maxf(1.0, distance_to_target)
	EventBus.publish(EnemyRangedAttackEvent.new(
		Bulwark.loc(data.id).to_string(),
		origin,
		target,
		data.attack_damage,
		projectile_kind,
		data.projectile_speed))

func _tick_self_destruct(delta: float, distance_to_target: float,
		origin: Vector2) -> void:
	if distance_to_target <= data.attack_range:
		if state != State.ATTACK:
			state = State.ATTACK
		attack_timer -= delta
		if attack_timer <= 0.0:
			explode(origin)
	else:
		if state != State.CHASE:
			state = State.CHASE
			attack_timer = data.attack_interval

## 自爆入口（核心自爆/表现层撞击玩家共用）：广播 AoE + 死亡
func explode(origin: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	var damage := data.explosion_damage if data.explosion_damage > 0.0 else data.attack_damage
	EventBus.publish(EnemyAoEEvent.new(
		Bulwark.loc(data.id).to_string(),
		origin,
		data.explosion_radius,
		damage))
	die()

## 受击（伤害管道入口；source = 玩家阵营）
## M3 问题 4：killer_id = 击杀者玩家（默认 0 = 单机/本地；随 EnemyDiedEvent 供奖励归属）
## attack_direction：伤害来源方向（装甲兽方向护甲用）
## weak_point_hit：是否命中弱点（精英·巨兽用）
func take_damage(ctx: DamageContext, killer_id: int = 0,
		attack_direction: Vector2 = Vector2.ZERO, weak_point_hit: bool = false) -> DamageResult:
	if state == State.DEAD:
		return DamageResult.new()
	if data.has_weak_point and weak_point_hit:
		ctx.weak_point_hit = true
		ctx.weak_point_multiplier = data.weak_point_multiplier
	if data.directional_armor:
		ctx.directional_defense = true
		ctx.frontal_defense = data.frontal_armor
		ctx.attack_direction = attack_direction
		ctx.facing_direction = facing_direction
	ctx.defense = data.armor
	var result := DamagePipeline.compute(ctx)
	if result.damage > 0.0:
		health = maxf(0.0, health - result.damage)
		if health <= 0.0:
			die(killer_id)
	return result

## 公开死亡入口（表现层：撞击玩家后自爆等同归于尽；killer = 被撞玩家）
func die(killer_id: int = 0) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	if not _dead_reported:
		_dead_reported = true
		EventBus.publish(EnemyDiedEvent.new(
			Bulwark.loc(data.id).to_string(), Vector2.ZERO, killer_id))
