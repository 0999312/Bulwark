class_name WeaponSlots
extends RefCounted
## 三槽位武器框架（已定 P11）：主 / 副 / 手枪
## - M0 实装 主（突击步枪 1 型号）+ 手枪（应急位）；M1 实装副（霰弹枪）
## - 切换状态机（含 CD 计时，已定 P23）：
##     主↔副 = 1.5s；主/副↔手枪 = 0.3s
##     规则落地：cd = min(双方类型的 switch_cd)（手枪 0.3 恒提供快速拔枪路径）
## - 开火验证：切换中 / 换弹中 / 射速 CD / 弹匣空 → 拒绝；弹匣空自动换弹，也可 R 键主动换弹
## - 手枪（P25 修订）：弹匣有限（打空需换弹）、备弹无限（换弹免费补满，不消耗 AmmoSystem 计数）
## - M1 改枪：SlotState.attachments（配件槽位 → AttachmentData）经 WeaponStats 结算
##   最终数值（伤害/射速/弹匣/换弹/散布/暴击/弹丸数）；全局强化来自 RunState.bonus（可选注入）
## 纯逻辑：不引用场景节点；事件经 EventBus 广播（HUD/表现层订阅）。

const SLOT_MAIN := 0
const SLOT_SUB := 1
const SLOT_PISTOL := 2
const SLOT_COUNT := 3

## 槽位实例状态
class SlotState:
	var type_data: WeaponTypeData
	var model_data: WeaponModelData
	## 已装配配件：AttachmentData.AttachmentSlot(int) -> AttachmentData
	var attachments: Dictionary = {}
	var mag: int = 0
	var fire_cd: float = 0.0
	var reloading: bool = false
	var reload_timer: float = 0.0

var slots: Array[SlotState] = []
var current_index: int = SLOT_MAIN
var switching: bool = false
var switch_timer: float = 0.0
var _switch_target: int = SLOT_MAIN
var _switch_cd_total: float = 0.0
var ammo: AmmoSystem
## 全局强化（商店武器向；可选，null = 无强化）
var run_state: RunState
## 多人区分（默认 0 = 单机/本地；弹药/切换/换弹/配件事件携带）
var player_id: int = 0

func _init(p_ammo: AmmoSystem, p_run_state: RunState = null, p_player_id: int = 0) -> void:
	ammo = p_ammo
	run_state = p_run_state
	player_id = p_player_id
	slots = [
		SlotState.new(),
		SlotState.new(),
		SlotState.new(),
	]

## 装填槽位（GameSession 从 Registry 读取数据注入；attachments 可选）
func assign_slot(slot_index: int, type_data: WeaponTypeData, model_data: WeaponModelData,
		attachments: Dictionary = {}) -> void:
	var slot := slots[slot_index]
	slot.type_data = type_data
	slot.model_data = model_data
	slot.attachments = attachments.duplicate()
	var stats := get_effective_stats(slot)
	slot.mag = stats.mag_size
	slot.fire_cd = 0.0
	slot.reloading = false
	slot.reload_timer = 0.0
	_emit_ammo(slot)

## 初始状态广播（HUD 绑定：装填完成后推一次当前弹药/武器）
func emit_initial_state() -> void:
	var slot := get_current_slot()
	if slot.type_data != null and slot.model_data != null:
		_emit_ammo(slot)
		EventBus.publish(WeaponSwitchedEvent.new(
			current_index, slot.type_data.slot, _slot_model_location(slot), player_id))

func get_current_slot() -> SlotState:
	return slots[current_index]

func get_slot(slot_index: int) -> SlotState:
	return slots[slot_index]

func is_slot_ready(slot_index: int) -> bool:
	return slots[slot_index].type_data != null and slots[slot_index].model_data != null

func is_current_pistol() -> bool:
	return get_current_slot().type_data != null \
		and get_current_slot().type_data.slot == WeaponTypeData.SlotType.PISTOL

# ─── 改枪（M1 配件系统 / M5b 换型号） ───

## M5b：改枪台换型号。
## - 不传 type_data（缺省）：旧语义——新模型必须与槽位当前武器类型一致
## - 传入 type_data：允许同槽位类别内换武器类型（主槽 AR↔LMG↔ER、手枪槽 HG 等），
##   槽位类别（slot 枚举）必须一致；弹药/弹道/手感随新类型数据切换
func set_model(slot_index: int, model_data: WeaponModelData,
		type_data: WeaponTypeData = null) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if model_data == null:
		return false
	var slot := slots[slot_index]
	if slot.type_data == null:
		return false
	if type_data == null:
		if model_data.type_id != Bulwark.loc(slot.type_data.id).to_string():
			return false
	else:
		if model_data.type_id != Bulwark.loc(type_data.id).to_string():
			return false
		if type_data.slot != slot.type_data.slot:
			return false
		slot.type_data = type_data
	slot.model_data = model_data
	_after_loadout_change(slot)
	EventBus.publish(WeaponSwitchedEvent.new(
		slot_index, slot.type_data.slot, _slot_model_location(slot), player_id))
	return true

## 结算当前数值（模型 × 配件 × 全局强化）；null 槽返回空 WeaponStats
func get_effective_stats(slot: SlotState) -> WeaponStats:
	if slot == null or slot.model_data == null:
		return WeaponStats.compute(null, [], null)
	var attachments: Array = slot.attachments.values()
	return WeaponStats.compute(slot.model_data, attachments,
		run_state.bonus if run_state != null else null)

## 装配配件到武器槽（同配件槽替换旧件）；返回是否受理
## 弹匣修正生效：新 mag_size ≥ 当前 → 补满差额（换弹匣即装满）；变小 → 截断
func equip_attachment(slot_index: int, attachment: AttachmentData) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if attachment == null:
		return false
	var slot := slots[slot_index]
	if slot.model_data == null:
		return false
	var replaced: AttachmentData = slot.attachments.get(attachment.slot)
	slot.attachments[attachment.slot] = attachment
	_after_loadout_change(slot)
	EventBus.publish(AttachmentEquippedEvent.new(
		slot_index, Bulwark.loc(attachment.id).to_string(), player_id))
	if replaced != null and replaced != attachment:
		EventBus.publish(AttachmentUnequippedEvent.new(
			slot_index, Bulwark.loc(replaced.id).to_string(), player_id))
	return true

## 卸下指定配件槽；返回是否受理
func unequip_attachment(slot_index: int, attachment_slot: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	var slot := slots[slot_index]
	if not slot.attachments.has(attachment_slot):
		return false
	var removed: AttachmentData = slot.attachments[attachment_slot]
	slot.attachments.erase(attachment_slot)
	_after_loadout_change(slot)
	EventBus.publish(AttachmentUnequippedEvent.new(
		slot_index, Bulwark.loc(removed.id).to_string(), player_id))
	return true

## 已装配配件（查询用；返回 AttachmentData 或 null）
func get_attachment(slot_index: int, attachment_slot: int) -> AttachmentData:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	return slots[slot_index].attachments.get(attachment_slot)

func _after_loadout_change(slot: SlotState) -> void:
	var stats := get_effective_stats(slot)
	slot.mag = mini(slot.mag, stats.mag_size)
	if slot.mag < stats.mag_size:
		# 换弹匣/扩容：直接补满到新容量（改枪即保养，节奏友好）
		slot.mag = stats.mag_size
	_emit_ammo(slot)

# ─── 切换状态机 ───

## 请求切换到目标槽；返回是否受理（切换中 / 槽位未装填 → 拒绝并广播反馈事件）
func try_switch_to(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if slot_index == current_index:
		return false
	if switching:
		EventBus.publish(WeaponSwitchRejectedEvent.new(slot_index, WeaponSwitchRejectedEvent.REASON_SWITCHING, player_id))
		return false
	if not is_slot_ready(slot_index):
		EventBus.publish(WeaponSwitchRejectedEvent.new(slot_index, WeaponSwitchRejectedEvent.REASON_EMPTY, player_id))
		return false
	_begin_switch(slot_index)
	return true

## 切换 CD（P23）：主↔副 1.5s；↔手枪 0.3s
## 落地规则：cd = min(双方类型 switch_cd)；手枪类型配置 0.3、重武器 1.5 → 天然满足
func _get_switch_cd(from_index: int, to_index: int) -> float:
	var from_cd := slots[from_index].type_data.switch_cd if slots[from_index].type_data else 1.5
	var to_cd := slots[to_index].type_data.switch_cd if slots[to_index].type_data else 1.5
	return minf(from_cd, to_cd)

func _begin_switch(to_index: int) -> void:
	switching = true
	_switch_target = to_index
	_switch_cd_total = _get_switch_cd(current_index, to_index)
	switch_timer = _switch_cd_total
	# 切换打断换弹（P23 细节待定，M0 定为打断）
	if get_current_slot().reloading:
		_cancel_reload(get_current_slot())
	EventBus.publish(WeaponSwitchStartedEvent.new(to_index, _switch_cd_total, player_id))

## 每帧驱动（CD 计时 / 换弹计时）
func tick(delta: float) -> void:
	if switching:
		switch_timer -= delta
		if switch_timer <= 0.0:
			_finish_switch()
	var current := get_current_slot()
	if current.fire_cd > 0.0:
		current.fire_cd = maxf(0.0, current.fire_cd - delta)
	if current.reloading:
		current.reload_timer -= delta
		if current.reload_timer <= 0.0:
			_finish_reload(current)

func _finish_switch() -> void:
	switching = false
	current_index = _switch_target
	var slot := get_current_slot()
	EventBus.publish(WeaponSwitchedEvent.new(
		current_index,
		slot.type_data.slot,
		_slot_model_location(slot),
		player_id))
	# 切枪后立即广播当前槽弹药状态（HUD 显示同步，避免沿用上一把枪的旧数据）
	_emit_ammo(slot)

## 是否正在切换（HUD 显示 CD）
func is_switching() -> bool:
	return switching

func get_switch_progress() -> float:
	if not switching or _switch_cd_total <= 0.0:
		return 0.0
	return 1.0 - switch_timer / _switch_cd_total

# ─── 开火 ───

func is_reloading() -> bool:
	return get_current_slot().reloading

## 开火验证（弹药/冷却）→ 消耗弹药 → 广播 ShotFiredEvent
## aim_direction 由表现层注入（后端只发意图，原点由表现层提供）
func try_fire(aim_direction: Vector2) -> bool:
	if switching:
		return false
	var slot := get_current_slot()
	if slot.type_data == null or slot.model_data == null:
		return false
	if slot.reloading:
		return false
	# 弹匣空 → 立即自动换弹（先于射速 CD 检查：最后一发后不等待 CD）
	# 手枪同规则（P25 修订：无限备弹 ≠ 无限弹匣，弹匣打空仍需换弹）
	if slot.mag <= 0:
		_start_reload(slot)
		return false
	if slot.fire_cd > 0.0:
		return false

	slot.mag -= 1
	_emit_ammo(slot)
	var stats := get_effective_stats(slot)
	slot.fire_cd = 1.0 / maxf(0.01, stats.fire_rate)
	EventBus.publish(ShotFiredEvent.new(_slot_model_location(slot), aim_direction.normalized(), player_id))
	return true

# ─── 换弹 ───

## 主动换弹（R 键意图入口）；返回是否受理
func try_reload() -> bool:
	if switching:
		return false
	var slot := get_current_slot()
	if slot.type_data == null or slot.model_data == null:
		return false
	if slot.reloading:
		return false
	var stats := get_effective_stats(slot)
	if slot.mag >= stats.mag_size:
		return false
	if not _slot_has_infinite_reserve(slot) \
			and ammo.get_count(slot.type_data.ammo_type) <= 0:
		return false
	_start_reload(slot)
	return true

## 槽位是否拥有无限备弹：
## - 手枪 = 无限备弹兜底（P25 修订：弹匣有限、备弹无限）
## - 其余弹药类型看 AmmoSystem 的 INFINITE 标记
func _slot_has_infinite_reserve(slot: SlotState) -> bool:
	if slot.type_data == null:
		return false
	return slot.type_data.slot == WeaponTypeData.SlotType.PISTOL \
		or ammo.is_infinite(slot.type_data.ammo_type)

func _start_reload(slot: SlotState) -> void:
	if slot.reloading or slot.model_data == null:
		return
	var stats := get_effective_stats(slot)
	if slot.mag >= stats.mag_size:
		return
	# 无限备弹 → 无需检查备弹；有限备弹 → 备弹 0 则无法换弹
	if not _slot_has_infinite_reserve(slot) \
			and ammo.get_count(slot.type_data.ammo_type) <= 0:
		return
	slot.reloading = true
	slot.reload_timer = stats.reload_time
	EventBus.publish(ReloadStartedEvent.new(stats.reload_time, slot.type_data.ammo_type, player_id))

func _cancel_reload(slot: SlotState) -> void:
	slot.reloading = false
	slot.reload_timer = 0.0

func _finish_reload(slot: SlotState) -> void:
	slot.reloading = false
	slot.reload_timer = 0.0
	var stats := get_effective_stats(slot)
	var need := stats.mag_size - slot.mag
	if need <= 0:
		return
	# 无限备弹（手枪兜底）：直接补满、不消耗备弹；有限备弹：从备弹扣除
	if _slot_has_infinite_reserve(slot):
		slot.mag = stats.mag_size
	else:
		var reserve := ammo.get_count(slot.type_data.ammo_type)
		var taken := mini(need, reserve)
		ammo.consume(slot.type_data.ammo_type, taken)
		slot.mag += taken
	_emit_ammo(slot)

# ─── 内部 ───

func _slot_model_location(slot: SlotState) -> String:
	if slot.model_data == null:
		return ""
	return Bulwark.loc(slot.model_data.id).to_string()

func _emit_ammo(slot: SlotState) -> void:
	if slot.type_data == null:
		return
	EventBus.publish(AmmoChangedEvent.new(
		slot.type_data.ammo_type,
		slot.mag,
		ammo.get_count(slot.type_data.ammo_type),
		player_id))
