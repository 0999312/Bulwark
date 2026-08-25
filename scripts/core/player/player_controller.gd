class_name PlayerController
extends RefCounted
## 玩家后端控制器（纯逻辑，headless 可测）
## - FSM：Idle / Move / Shoot / Reload / Dead（M0 子集；结构为扩展预留：SwitchWeapon 并入 WeaponSlots 切换状态机）
## - 意图接口（前端 → 后端）：set_move_intent / set_aim_direction / set_shoot_intent / intent_switch
## - 后端验证射击（弹药/冷却，WeaponSlots.try_fire）→ 广播 ShotFiredEvent → 表现层执行弹道
## - 生命经伤害管道结算（M0 无敌人攻击玩家，结构留位 + 测试用）
## 属性走 AttributeSet：base + 修正（M0 雏形）
## player_id：多人区分（默认 0 = 单机/本地；事件携带）

enum State {
	IDLE = 0,
	MOVE = 1,
	SHOOT = 2,
	RELOAD = 3,
	DEAD = 4,
	REVIVING = 5, # M1：复活 CD 中（ReviveSystem 驱动，玩家不可控）
}

const STATE_NAMES := {
	State.IDLE: &"Idle",
	State.MOVE: &"Move",
	State.SHOOT: &"Shoot",
	State.RELOAD: &"Reload",
	State.DEAD: &"Dead",
	State.REVIVING: &"Reviving",
}

## 复活无敌帧（M2，M1 已知问题 #7：防止敌人"守尸"——复活瞬间被再撞秒杀）
const INVINCIBLE_DURATION := 2.0

## M3 方案 B：连射热度（命中散布扩散源）——裁决状态进 core。
## 命中判定逻辑化后散布在裁决侧（装配层）计算，heat 必须随裁决状态存在，
## 不再作为表现层私有手感数值（原在 PlayerView）
const HEAT_MAX := 4.0             # 连射热度上限（度；草案 §3 "上限 4°"）
const HEAT_DECAY := 3.0           # 停火热度衰减速度（度/秒）
const HEAT_PER_SHOT := 0.15       # 每发连射热度增量（度，乘 type.recoil.x）

var player_id: int = 0
var attribute_set: AttributeSet
var weapon_slots: WeaponSlots

var health: float = 100.0
var max_health: float = 100.0
var state: State = State.IDLE
## 连射热度（0 ~ HEAT_MAX；裁决侧散布计算用；视图可读用于表现）
var heat := 0.0

## 意图状态（前端每帧喂入）
var move_direction: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var shoot_held: bool = false

var _dead_reported := false
var _invincible_time := 0.0

func _init(p_attributes: AttributeSet, p_weapon_slots: WeaponSlots, p_player_id: int = 0) -> void:
	player_id = p_player_id
	attribute_set = p_attributes
	weapon_slots = p_weapon_slots
	_recompute_health()
	# 初始状态广播（HUD 绑定）
	EventBus.publish(PlayerHealthChangedEvent.new(health, max_health, player_id))

func get_state_name() -> StringName:
	return STATE_NAMES[state]

func is_dead() -> bool:
	return state == State.DEAD

## 复活 CD 中（表现层倒地/读条；期间不响应移动/射击意图）
func is_reviving() -> bool:
	return state == State.REVIVING

## 不可操作（死亡或复活中）
func is_incapacitated() -> bool:
	return state == State.DEAD or state == State.REVIVING

# ─── 意图（前端 → 后端） ───

func set_move_intent(dir: Vector2) -> void:
	move_direction = dir

func set_aim_direction(dir: Vector2) -> void:
	if dir.length_squared() > 0.001:
		aim_direction = dir.normalized()

func set_shoot_intent(held: bool) -> void:
	shoot_held = held

func intent_switch(slot_index: int) -> void:
	if is_incapacitated():
		return
	weapon_slots.try_switch_to(slot_index)

## 主动换弹意图（R 键）；拒绝条件由 WeaponSlots.try_reload 裁决
func intent_reload() -> void:
	if is_incapacitated():
		return
	weapon_slots.try_reload()

# ─── 每帧驱动（后端权威） ───

func tick(delta: float) -> void:
	# 连射热度衰减（无论死活都衰减，与表现层解耦后由裁决侧统一维护）
	if heat > 0.0:
		heat = maxf(0.0, heat - HEAT_DECAY * delta)
	if _invincible_time > 0.0:
		_invincible_time = maxf(0.0, _invincible_time - delta)
	if is_incapacitated():
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
## 复活无敌帧期间免疫伤害（敌人守尸不再秒杀，M2）
func take_damage(ctx: DamageContext) -> DamageResult:
	if is_incapacitated():
		return DamageResult.new()
	if _invincible_time > 0.0:
		return DamageResult.new()
	var result := DamagePipeline.compute(ctx)
	if result.damage > 0.0:
		health = maxf(0.0, health - result.damage)
		EventBus.publish(PlayerHealthChangedEvent.new(health, max_health, player_id))
		if health <= 0.0:
			_transition_to(State.DEAD)
			if not _dead_reported:
				_dead_reported = true
				EventBus.publish(PlayerDiedEvent.new(player_id))
	return result

## 商店强化（M1，STAT_PLAYER 商品）：修正写入玩家 AttributeSet 并重算生命
func apply_bonus(attr: StringName, amount: float, multiplicative: bool = false) -> void:
	attribute_set.add_modifier(attr, amount, multiplicative)
	recompute_health()

## P1-6 道具到期：移除临时修正（与 apply_bonus 对称）
func remove_bonus(attr: StringName, amount: float, multiplicative: bool = false) -> void:
	attribute_set.remove_modifier(attr, amount, multiplicative)
	recompute_health()

## 重算生命上限（购买生命强化后调用；满血时同步上限差额）
func recompute_health() -> void:
	_recompute_health()
	EventBus.publish(PlayerHealthChangedEvent.new(health, max_health, player_id))

## P1-6 道具治疗：回复至多 amount（不超上限；死亡/复活中不生效）
func heal(amount: float) -> void:
	if amount <= 0.0 or is_incapacitated():
		return
	health = minf(health + amount, max_health)
	EventBus.publish(PlayerHealthChangedEvent.new(health, max_health, player_id))

## 复活（P7/P20：ReviveSystem CD 结束后由装配层调用；满血回场 + 短时无敌帧）
func revive() -> void:
	if state != State.DEAD:
		return
	_dead_reported = false
	health = max_health
	state = State.IDLE
	_invincible_time = INVINCIBLE_DURATION
	heat = 0.0  # 复活重置连射热度（与表现层视觉复位一致）
	EventBus.publish(PlayerHealthChangedEvent.new(health, max_health, player_id))
	EventBus.publish(PlayerStateChangedEvent.new(state))

## 复活无敌帧剩余时间（秒；0 = 非无敌；测试/表现层查询）
func get_invincible_time() -> float:
	return _invincible_time
