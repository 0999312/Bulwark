class_name AttributeSet
extends RefCounted
## 属性集雏形（架构 §4.4）：base + 修正列表
## final = (base + additive) × multiplicative；缓存重算（商店/技能频繁改属性为 M1+）
## M0 使用：max_health / move_speed / reload_speed（reload_speed 供换弹时长缩放，结构留位）

## 属性键常量
const MAX_HEALTH := &"max_health"
const MOVE_SPEED := &"move_speed"
const RELOAD_SPEED := &"reload_speed"

var _base: Dictionary = {}           # StringName -> float
var _additive: Dictionary = {}       # StringName -> float（Σ）
var _multiplicative: Dictionary = {} # StringName -> float（Π，恒 ≥ 0）

func set_base(attr: StringName, value: float) -> void:
	_base[attr] = value
	if not _additive.has(attr):
		_additive[attr] = 0.0
	if not _multiplicative.has(attr):
		_multiplicative[attr] = 1.0

## 添加修正（multiplicative=true 走乘法通道；相同 attr+通道 累加/累乘）
func add_modifier(attr: StringName, amount: float, multiplicative: bool = false) -> void:
	if not _base.has(attr):
		set_base(attr, 0.0)
	if multiplicative:
		_multiplicative[attr] = _multiplicative[attr] * maxf(0.0, amount)
	else:
		_additive[attr] = _additive[attr] + amount

func remove_modifier(attr: StringName, amount: float, multiplicative: bool = false) -> void:
	if not _base.has(attr):
		return
	if multiplicative:
		if amount > 0.0:
			_multiplicative[attr] = _multiplicative[attr] / amount
	else:
		_additive[attr] = _additive[attr] - amount

## 终值：(base + additive) × multiplicative
func get_final(attr: StringName) -> float:
	return (_base.get(attr, 0.0) + _additive.get(attr, 0.0)) * _multiplicative.get(attr, 1.0)

## 加法通道累计值（未设置返回 0）
func get_additive(attr: StringName) -> float:
	return _additive.get(attr, 0.0)

## 乘法通道累计值（未设置返回 1）
func get_multiplicative(attr: StringName) -> float:
	return _multiplicative.get(attr, 1.0)
