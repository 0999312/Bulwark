class_name Hud
extends Control
## 常驻 HUD（UIManager.add_overlay 挂载，bulwark:ui/hud）
## 数据绑定：订阅后端 EventBus 事件做展示；前端不直接读写后端数值（架构 §1.3/§4.12）
## 内容：生命 / 弹药 / 切换提示 / 基地耐久条 / 波次预告（方位罗盘）

const INFINITE_TEXT := "∞"

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var base_bar: ProgressBar = %BaseBar
@onready var base_label: Label = %BaseLabel
@onready var wave_label: Label = %WaveLabel
@onready var banner_label: Label = %BannerLabel
@onready var banner_bg: Panel = %BannerBG
@onready var compass_label: Label = %CompassLabel
@onready var ammo_row: HBoxContainer = %AmmoLabel
@onready var ammo_mag_label: Label = %AmmoMag
@onready var ammo_reserve_label: Label = %AmmoReserve
@onready var reload_label: Label = %ReloadLabel
@onready var switch_label: Label = %SwitchLabel
@onready var hint_label: Label = %HintLabel
@onready var slot_main_label: Label = %SlotMain
@onready var slot_sub_label: Label = %SlotSub
@onready var slot_pistol_label: Label = %SlotPistol
@onready var resources_label: Label = %ResourcesLabel
@onready var revive_label: Label = %ReviveLabel
@onready var revive_bg: Panel = %ReviveBG

var _banner_timer := 0.0
var _reload_timer := 0.0
var _switch_timer := 0.0
var _revive_timer := 0.0
var _revive_active := false
var _current_slot_type: int = WeaponTypeData.SlotType.MAIN
var _cached_ammo: Dictionary = {}  # {mag:int, reserve:int}
## M2 多人：本 HUD 只显示该玩家 id 的数据（host/单机 = 0；client = 1）
var _local_player_id := 0

## M2 多人：绑定本进程负责的玩家（GameSession 挂载时调用）
func set_local_player_id(pid: int) -> void:
	_local_player_id = pid

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.subscribe(&"PlayerHealthChangedEvent", _on_player_health)
	EventBus.subscribe(&"AmmoChangedEvent", _on_ammo_changed)
	EventBus.subscribe(&"WeaponSwitchedEvent", _on_weapon_switched)
	EventBus.subscribe(&"WeaponSwitchStartedEvent", _on_switch_started)
	EventBus.subscribe(&"WeaponSwitchRejectedEvent", _on_switch_rejected)
	EventBus.subscribe(&"ReloadStartedEvent", _on_reload_started)
	EventBus.subscribe(&"BaseDurabilityChangedEvent", _on_base_durability)
	EventBus.subscribe(&"WaveWarningEvent", _on_wave_warning)
	EventBus.subscribe(&"WaveStartedEvent", _on_wave_started)
	EventBus.subscribe(&"WaveClearedEvent", _on_wave_cleared)
	EventBus.subscribe(&"PlayerDiedEvent", _on_player_died)
	EventBus.subscribe(&"RunStateChangedEvent", _on_run_state_changed)
	EventBus.subscribe(&"ReviveStartedEvent", _on_revive_started)
	EventBus.subscribe(&"RevivedEvent", _on_revived)
	_update_slot_highlight()

func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			banner_label.visible = false
			banner_bg.visible = false
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			reload_label.visible = false
	if _switch_timer > 0.0:
		_switch_timer -= delta
		if _switch_timer <= 0.0:
			switch_label.visible = false
	if _revive_active:
		_revive_timer = maxf(0.0, _revive_timer - delta)
		revive_label.text = "复活中 %.1fs" % _revive_timer

# ─── 事件订阅 ───

func _on_player_health(event: PlayerHealthChangedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	hp_bar.max_value = event.max_value
	hp_bar.value = event.current
	hp_label.text = "生命 %d/%d" % [event.current, event.max_value]

func _on_ammo_changed(event: AmmoChangedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_cached_ammo = {"mag": event.mag, "reserve": event.reserve}
	_refresh_ammo_label()

func _on_weapon_switched(event: WeaponSwitchedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_current_slot_type = event.slot_type
	switch_label.visible = false
	reload_label.visible = false
	_update_slot_highlight()
	_refresh_ammo_label()

func _on_switch_started(event: WeaponSwitchStartedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	switch_label.text = "切换中 %.1fs" % event.switch_cd
	switch_label.visible = true
	_switch_timer = event.switch_cd

func _on_switch_rejected(event: WeaponSwitchRejectedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	match event.reason:
		WeaponSwitchRejectedEvent.REASON_EMPTY:
			switch_label.text = "槽位 %d 空" % (event.slot_index + 1)
		_:
			switch_label.text = "切换中…"
	switch_label.visible = true
	_switch_timer = 1.5

func _on_reload_started(event: ReloadStartedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	reload_label.text = "换弹 %.1fs" % event.duration
	reload_label.visible = true
	_reload_timer = event.duration

func _on_base_durability(event: BaseDurabilityChangedEvent) -> void:
	base_bar.max_value = event.max_value
	base_bar.value = event.current
	base_label.text = "基地 %d/%d" % [event.current, event.max_value]

func _on_wave_warning(event: WaveWarningEvent) -> void:
	wave_label.text = "第 %d/%d 波" % [event.wave_index, event.wave_total]
	# 只报来袭方位数量级（M2 简化：大量/少量分级，不再逐方向罗列数量与箭头）
	# direction_tiers 由 WaveDirector 填充；空（旧事件/测试）时回退逐方向罗列
	var summary := _format_direction_tiers(event)
	compass_label.text = "来袭 %s" % summary
	compass_label.visible = true
	_show_banner("第 %d 波 · %s" % [event.wave_index, summary], 2.5)

## 方位分级摘要文本（M2，纯函数便于测试）：
## {"heavy": [dir...], "light": [dir...]} → "大量 ↑→ · 少量 ↘"
## direction_tiers 为空时回退旧逻辑（逐方向箭头罗列；composition 可能为 null（client 镜像））
static func _format_direction_tiers(event: WaveWarningEvent) -> String:
	var tiers := event.direction_tiers
	if tiers.is_empty() or not (tiers.get("heavy", []) is Array):
		if event.composition == null:
			return ""
		var parts: Array[String] = []
		for group: WaveComposition.SpawnGroup in event.composition.groups:
			parts.append(DirectionUtils.arrow(group.direction))
		return " ".join(parts)
	var sections: Array[String] = []
	var heavy: Array = tiers.get("heavy", [])
	var light: Array = tiers.get("light", [])
	if not heavy.is_empty():
		sections.append("大量 %s" % _arrows_text(heavy))
	if not light.is_empty():
		sections.append("少量 %s" % _arrows_text(light))
	return " · ".join(sections)

static func _arrows_text(directions: Array) -> String:
	var parts: Array[String] = []
	for dir in directions:
		parts.append(DirectionUtils.arrow(int(dir)))
	return "".join(parts)

func _on_wave_started(_event: WaveStartedEvent) -> void:
	_show_banner("接敌！", 1.5)

func _on_wave_cleared(event: WaveClearedEvent) -> void:
	_show_banner("第 %d 波击退。" % event.wave_index, 2.0)

func _on_player_died(event: PlayerDiedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_show_banner("阵亡。正在调用应急储备…", 2.0)

func _on_run_state_changed(event: RunStateChangedEvent) -> void:
	resources_label.text = "货币 %d · 建材 %d · 储备 %d" % [
		event.credits, event.material, event.reserve]

func _on_revive_started(event: ReviveStartedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_revive_active = true
	_revive_timer = event.revive_cd
	revive_label.text = "复活中 %.1fs" % _revive_timer
	revive_label.visible = true
	revive_bg.visible = true

func _on_revived(event: RevivedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_revive_active = false
	revive_label.visible = false
	revive_bg.visible = false

# ─── 内部 ───

func _refresh_ammo_label() -> void:
	if _cached_ammo.is_empty():
		ammo_mag_label.text = "--"
		ammo_reserve_label.text = ""
		return
	var reserve_text: String
	if _current_slot_type == WeaponTypeData.SlotType.PISTOL:
		# 手枪（P25 修订）：弹匣有限、备弹无限（与 BULLET 池无关，恒显 ∞）
		reserve_text = INFINITE_TEXT
	else:
		reserve_text = INFINITE_TEXT if int(_cached_ammo["reserve"]) == AmmoSystem.INFINITE \
			else str(_cached_ammo["reserve"])
	ammo_mag_label.text = str(int(_cached_ammo["mag"]))
	ammo_reserve_label.text = "/ %s" % reserve_text

func _update_slot_highlight() -> void:
	slot_main_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.MAIN else Color(1, 1, 1, 0.45)
	slot_sub_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.SUB else Color(1, 1, 1, 0.45)
	slot_pistol_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.PISTOL else Color(1, 1, 1, 0.45)

func _show_banner(text: String, duration: float) -> void:
	banner_label.text = text
	banner_label.visible = true
	banner_bg.visible = true
	_banner_timer = duration
