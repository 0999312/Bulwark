class_name RunnerController
extends RefCounted
## 奔跑者后端控制器（纯逻辑，headless 可测）
## 行为 FSM 雏形：Chase（冲锋） / Attack（啃基地） / Dead
## - 寻路/移动由表现层执行（NavigationAgent2D）；后端只收「到目标距离」驱动状态
## - 攻击：到攻击距离内按 attack_interval 出爪，广播 EnemyAttackEvent → BaseCore 订阅结算
## - 受击：经伤害管道（来源玩家阵营），归零 → Dead + EnemyDiedEvent（WaveDirector 簿记）

enum State {
	CHASE = 0,
	ATTACK = 1,
	DEAD = 2,
}

var data: EnemyData
var health: float = 0.0
var state: State = State.CHASE
var attack_timer: float = 0.0

var _dead_reported := false

func _init(p_data: EnemyData) -> void:
	data = p_data
	health = data.max_hp
	# 首次出爪前给玩家一个完整攻击间隔的反应时间（不再落地即咬）
	attack_timer = data.attack_interval

func is_dead() -> bool:
	return state == State.DEAD

## 每帧驱动；distance_to_target 由表现层提供（目标 = 基地）
func tick(delta: float, distance_to_target: float) -> void:
	if state == State.DEAD:
		return
	if distance_to_target <= data.attack_range:
		if state != State.ATTACK:
			state = State.ATTACK
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = data.attack_interval
			EventBus.publish(EnemyAttackEvent.new(data.attack_damage, Bulwark.loc(data.id).to_string()))
	else:
		if state != State.CHASE:
			state = State.CHASE
			attack_timer = 0.0

## 受击（伤害管道入口；source = 玩家阵营）
func take_damage(ctx: DamageContext) -> DamageResult:
	if state == State.DEAD:
		return DamageResult.new()
	var result := DamagePipeline.compute(ctx)
	if result.damage > 0.0:
		health = maxf(0.0, health - result.damage)
		if health <= 0.0:
			die()
	return result

## 公开死亡入口（表现层：撞击玩家后自爆等同归于尽）
func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	if not _dead_reported:
		_dead_reported = true
		EventBus.publish(EnemyDiedEvent.new(Bulwark.loc(data.id).to_string(), Vector2.ZERO))
