class_name RunState
extends RefCounted
## 当局资源与全局强化（后端，纯逻辑；架构 §4.8 经济模块）
## - 货币 credits：击杀奖励 / 商店消费（M1 唯一经济币种）
## - 建材 material：击杀奖励（少量）/ 商店购买 / 路障建造消耗
## - 应急储备 reserve：复活资源（P20 局内极难补充；商店高价固定物资）
## - 强化 AttributeSet：商店购买的全局修正（玩家属性 / 武器数值共享通道）
## 变更广播 RunStateChangedEvent（HUD / 商店面板绑定）
## 能量资源已移除（唯一用途弹药补给台已删除）

const ATTRIBUTE_KEYS := [
	AttributeSet.MAX_HEALTH,
	AttributeSet.MOVE_SPEED,
	AttributeSet.RELOAD_SPEED,
	AttributeSet.ARMOR,
	AttributeSet.LIFESTEAL,
	AttributeSet.SWITCH_CD,
	AttributeSet.TURRET_DAMAGE,
	AttributeSet.BARRICADE_HP,
	AttributeSet.REPAIR_SPEED,
	AttributeSet.BUILD_COST,
	AttributeSet.MATERIAL_YIELD,
	AttributeSet.CREDIT_YIELD,
]

var credits: int = 0
var material: int = 0
var reserve: int = 0

## 全局强化（商店 STAT_PLAYER / STAT_WEAPON 修正落在这里；
## 玩家侧 AttributeSet 与武器侧 WeaponStats 在结算时叠加本集）
var bonus: AttributeSet

## M3 问题 4：所属玩家（多人独立资源；默认 0 = 单机/本地；事件携带供前端过滤）
var player_id: int = 0

func _init(p_player_id: int = 0) -> void:
	player_id = p_player_id
	bonus = AttributeSet.new()
	for key: StringName in ATTRIBUTE_KEYS:
		bonus.set_base(key, 0.0)

# ─── 资源 ───

func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	_emit_changed()

## 消费货币；余额不足返回 false（不扣减）
func try_spend_credits(amount: int) -> bool:
	if amount <= 0:
		return true
	if credits < amount:
		return false
	credits -= amount
	_emit_changed()
	return true

func add_material(amount: int) -> void:
	if amount <= 0:
		return
	material += amount
	_emit_changed()

func try_spend_material(amount: int) -> bool:
	if amount <= 0:
		return true
	if material < amount:
		return false
	material -= amount
	_emit_changed()
	return true

func add_reserve(amount: int) -> void:
	if amount <= 0:
		return
	reserve += amount
	_emit_changed()

## 消耗应急储备（复活）；无储备返回 false
func try_spend_reserve(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if reserve < amount:
		return false
	reserve -= amount
	_emit_changed()
	return true

# ─── 强化 ───

## 应用商店强化（add/mul 通道写入 bonus）
func apply_bonus_modifier(modifier: AttributeModifierData) -> void:
	if modifier == null or modifier.attribute == &"":
		return
	if modifier.multiplier != 1.0:
		bonus.add_modifier(modifier.attribute, modifier.multiplier, true)
	elif modifier.amount != 0.0:
		bonus.add_modifier(modifier.attribute, modifier.amount, false)

func get_bonus_final(attr: StringName) -> float:
	return bonus.get_final(attr)

func _emit_changed() -> void:
	EventBus.publish(RunStateChangedEvent.new(credits, material, reserve, player_id))
