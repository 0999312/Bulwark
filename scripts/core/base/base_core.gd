class_name BaseCore
extends RefCounted
## 基地核心（后端，纯逻辑）：耐久、扣减、归零 → 失败事件（已定 P7）
## - host 权威结构留位（M2 多人验证）
## - 敌人啃基地（EnemyAttackEvent）由 GameSession 接线结算（RefCounted 自订阅 EventBus
##   在对象释放后会产生失效回调，订阅生命周期归装配层管理——前后端分离的接线职责）

var durability: float = 0.0
var max_durability: float = 0.0

var _destroyed_reported := false

func _init(p_max_durability: float) -> void:
	max_durability = p_max_durability
	durability = p_max_durability
	# 初始状态广播（HUD 绑定）
	EventBus.publish(BaseDurabilityChangedEvent.new(durability, max_durability))

## 直接扣减（敌人啃咬由 GameSession 订阅 EnemyAttackEvent 后调用；防御减免走伤害管道）
func take_damage(amount: float) -> float:
	if _destroyed_reported or amount <= 0.0:
		return durability
	durability = maxf(0.0, durability - amount)
	EventBus.publish(BaseDurabilityChangedEvent.new(durability, max_durability))
	if durability <= 0.0 and not _destroyed_reported:
		_destroyed_reported = true
		EventBus.publish(BaseDestroyedEvent.new())
	return durability

func is_destroyed() -> bool:
	return _destroyed_reported

func get_durability_ratio() -> float:
	if max_durability <= 0.0:
		return 0.0
	return durability / max_durability
