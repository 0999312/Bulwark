class_name AmmoSystem
extends RefCounted
## 弹药系统：按弹药类型独立计数（子弹/燃料/榴弹/能量，架构 §4.2）
## 手枪无限备弹（已定 P25）：reserve = INFINITE（-1）表示永不耗尽

const INFINITE := -1

var _counts: Dictionary = {}  # AmmoType(int) -> int（reserve 数量；INFINITE = 无限）

## 设置弹药量；amount < 0 视为无限（INFINITE）
func set_count(ammo_type: int, amount: int) -> void:
	_counts[ammo_type] = amount

## 查询备弹；未设置过返回 0
func get_count(ammo_type: int) -> int:
	return _counts.get(ammo_type, 0)

func is_infinite(ammo_type: int) -> bool:
	return _counts.get(ammo_type, 0) == INFINITE

## 消耗备弹；无限备弹恒成功且不扣减
func consume(ammo_type: int, amount: int) -> bool:
	if amount <= 0:
		return true
	if is_infinite(ammo_type):
		return true
	var current := get_count(ammo_type)
	if current < amount:
		return false
	_counts[ammo_type] = current - amount
	return true

## 补充备弹（M0 无补给来源，结构留位）；无限备弹忽略
func add(ammo_type: int, amount: int) -> void:
	if amount <= 0 or is_infinite(ammo_type):
		return
	_counts[ammo_type] = get_count(ammo_type) + amount
