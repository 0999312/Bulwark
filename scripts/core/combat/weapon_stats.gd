class_name WeaponStats
extends RefCounted
## 武器数值结算（改枪系统核心，纯逻辑）
## 输入：WeaponModelData + 已装配配件（AttachmentData 数组）+ 全局强化（RunState.bonus）
## 输出：开火/命中使用的最终数值（伤害/射速/弹匣/换弹/散布/暴击/弹丸数/射程）
## 修正通道与 AttributeSet 一致：final = (base + Σadd) × Πmul
## - 配件修正：按配件 slots 装配（同槽冲突由 WeaponSlots 保证）
## - 全局强化：RunState.bonus（商店武器向商品）
## 纯函数可测：同输入 → 同输出（headless）

## 数值键（AttributeModifierData.attribute 目标）
const KEY_DAMAGE := &"damage"
const KEY_FIRE_RATE := &"fire_rate"
const KEY_MAG_SIZE := &"mag_size"
const KEY_RELOAD_TIME := &"reload_time"
const KEY_SPREAD := &"spread"
const KEY_CRIT_CHANCE := &"crit_chance"
const KEY_PELLETS := &"pellets"

## 数值字段（结算结果；由 compute 填充）
var damage: float = 0.0
var fire_rate: float = 1.0
var mag_size: int = 1
var reload_time: float = 1.0
var spread: float = 0.0
var crit_chance: float = 0.0
var crit_multiplier: float = 2.0
var range: float = 900.0
var pellets: int = 1
## 合并后的词条（模型词条 + 配件词条）
var keywords: Array[String] = []

static func compute(model: WeaponModelData, attachments: Array = [], bonus: AttributeSet = null) -> WeaponStats:
	var stats := WeaponStats.new()
	if model == null:
		return stats
	stats.damage = model.damage
	stats.fire_rate = model.fire_rate
	stats.mag_size = model.mag_size
	stats.reload_time = model.reload_time
	stats.spread = model.spread
	stats.crit_chance = model.crit_chance
	stats.crit_multiplier = model.crit_multiplier
	stats.range = model.range
	stats.pellets = maxi(1, model.pellets)
	stats.keywords = model.keywords.duplicate()

	# 配件修正（后装配的附件按顺序累加/累乘；同属性多附件可叠加）
	for attachment: AttachmentData in attachments:
		if attachment == null:
			continue
		for mod: AttributeModifierData in attachment.modifiers:
			if mod != null and mod.is_effective():
				stats._apply_modifier(mod)
		for kw: String in attachment.keywords:
			if not stats.keywords.has(kw):
				stats.keywords.append(kw)

	# 全局强化（商店武器向；bonus 持有 add/mul 修正，读取拆分通道避免未初始化键的 0 值污染乘法）
	if bonus != null:
		for key: StringName in [KEY_DAMAGE, KEY_FIRE_RATE, KEY_MAG_SIZE, KEY_RELOAD_TIME,
				KEY_SPREAD, KEY_CRIT_CHANCE, KEY_PELLETS]:
			if bonus.get_additive(key) != 0.0:
				stats._apply_attr(key, bonus.get_additive(key), false)
			if bonus.get_multiplicative(key) != 1.0:
				stats._apply_attr(key, bonus.get_multiplicative(key), true)

	stats.mag_size = maxi(1, stats.mag_size)
	stats.pellets = maxi(1, stats.pellets)
	stats.fire_rate = maxf(0.05, stats.fire_rate)
	stats.reload_time = maxf(0.05, stats.reload_time)
	return stats

func _apply_modifier(mod: AttributeModifierData) -> void:
	if mod.amount != 0.0:
		_apply_attr(mod.attribute, mod.amount, false)
	if mod.multiplier != 1.0:
		_apply_attr(mod.attribute, mod.multiplier, true)

func _apply_attr(attr: StringName, value: float, multiplicative: bool) -> void:
	match attr:
		KEY_DAMAGE:
			damage = damage * value if multiplicative else damage + value
		KEY_FIRE_RATE:
			fire_rate = fire_rate * value if multiplicative else fire_rate + value
		KEY_MAG_SIZE:
			mag_size = int(roundf(mag_size * value)) if multiplicative else mag_size + int(roundf(value))
		KEY_RELOAD_TIME:
			reload_time = reload_time * value if multiplicative else reload_time + value
		KEY_SPREAD:
			spread = spread * value if multiplicative else spread + value
		KEY_CRIT_CHANCE:
			crit_chance = crit_chance * value if multiplicative else crit_chance + value
		KEY_PELLETS:
			pellets = int(roundf(pellets * value)) if multiplicative else pellets + int(roundf(value))
		_:
			push_warning("WeaponStats: 未识别的数值键 %s" % attr)
