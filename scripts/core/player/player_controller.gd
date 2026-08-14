class_name PlayerController
extends RefCounted
## 玩家后端控制器（纯逻辑，headless 可测）
## - FSM：Idle / Move / Shoot / Reload / Dead（M0 子集；结构为扩展预留：SwitchWeapon 并入 WeaponSlots 切换状态机）
## - 意图接口（前端 → 后端）：set_move_intent / set_aim_direction / set_shoot_intent / intent_switch
## - 后端验证射击（弹药/冷却，WeaponSlots.try_fire）→ 广播 ShotFiredEvent → 表现层执行弹道
## - 生命经伤害管道结算（M0 无敌人攻击玩家，结构留位 + 测试用）
## 属性走 AttributeSet：base + 修正（M0 雏形）

enum State {
	IDLE = 0,
	MOVE = 1,
	SHOOT = 2,
	RELOAD = 3,
	DEAD = 4,
}

const STATE_NAMES := {
	State.IDLE: &"Idle",
	State.MOVE: &"Move",
	State.SHOOT: &"Shoot",
	State.RELOAD: &"Reload",
	State.DEAD: &"Dead",
}

var attribute_set: AttributeSet
var weapon_slots: WeaponSlots

var health: float = 100.0
var max_health: float = 100.0
var state: State = State.IDLE

## 意图状态（前端每帧喂入）
var move_direction: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var shoot_held: bool = false

var _dead_reported := false

func _init(p_attributes: AttributeSet, p_weapon_slots: WeaponSlots) -> void:
	attribute_set = p_attributes
	weapon_slots = p_weapon_slots
	_recompute_health()
	# 初始状态广播（HUD 绑定）
	EventBus.publish(PlayerHealthChangedEvent.new(health, max_health))

func get_state_name() -> StringName:
	return STATE_NAMES[state]

func is_dead() -> bool:
	return state == State.DEAD

# ─── 意图（前端 → 后端） ───

func set_move_intent(dir: Vector2) -> void:
	move_direction = dir

func set_aim_direction(dir: Vector2) -> void:
	if dir.length_squared() > 0.001:
		aim_direction = dir.normalized()

func set_shoot_intent(held: bool) -> void:
	shoot_held = held

func intent_switch(slot_index: int) -> void:
	if state == State.DEAD:
		return
	weapon_slots.try_switch_to(slot_index)

## 主动换弹意图（R 键）；拒绝条件由 WeaponSlots.try_reload 裁决
func intent_reload() -> void:
	if state == State.DEAD:
		return
	weapon_slots.try_reload()

# ─── 每帧驱动（后端权威） ───

func tick(delta: float) -> void:
	if state == State.DEAD:
		return
	weapon_slots.tick(delta)
	if shoot_held:
		weapon_slots.try_fire(aim_direction)
	_update_state()

func _update_state() -> void:
	var next: State
	if state == State.DEAD:
		return
	elif weapon_slots.is_reloading():
		next = State.RELOAD
	elif shoot_held and not weapon_slots.is_switching():
		next = State.SHOOT
	elif move_direction.length_squared() > 0.001:
		next = State.MOVE
	else:
		next = State.IDLE
	_transition_to(next)

func _transition_to(next: State) -> void:
	if next == state:
		return
	state = next
	EventBus.publish(PlayerStateChangedEvent.new(state))

# ─── 生命 / 伤害 ───

func _recompute_health() -> void:
	max_health = attribute_set.get_final(AttributeSet.MAX_HEALTH)
	health = minf(health, max_health) if health > 0.0 else max_health

## 受击（M0 无敌人攻击玩家；复活/失败判定结构留位，P7 主判定 = 基地耐久）
func take_damage(ctx: DamageContext) -> DamageResult:
	if state == State.DEAD:
		return DamageResult.new()
	var result := DamagePipeline.compute(ctx)
	if result.damage > 0.0:
		health = maxf(0.0, health - result.damage)
		EventBus.publish(PlayerHealthChangedEvent.new(health, max_health))
		if health <= 0.0:
			_transition_to(State.DEAD)
			if not _dead_reported:
				_dead_reported = true
				EventBus.publish(PlayerDiedEvent.new())
	return result

## 治疗（M0 无来源，结构留位）
func heal(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	EventBus.publish(PlayerHealthChangedEvent.new(health, max_health))
