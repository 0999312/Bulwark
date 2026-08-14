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
@onready var compass_label: Label = %CompassLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var reload_label: Label = %ReloadLabel
@onready var switch_label: Label = %SwitchLabel
@onready var hint_label: Label = %HintLabel
@onready var slot_main_label: Label = %SlotMain
@onready var slot_sub_label: Label = %SlotSub
@onready var slot_pistol_label: Label = %SlotPistol

var _banner_timer := 0.0
var _reload_timer := 0.0
var _switch_timer := 0.0
var _current_slot_type: int = WeaponTypeData.SlotType.MAIN
var _cached_ammo: Dictionary = {}  # {mag:int, reserve:int}

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
	_update_slot_highlight()

func _process(delta: float) -> void:
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			banner_label.visible = false
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			reload_label.visible = false
	if _switch_timer > 0.0:
		_switch_timer -= delta
		if _switch_timer <= 0.0:
			switch_label.visible = false

# ─── 事件订阅 ───

func _on_player_health(event: PlayerHealthChangedEvent) -> void:
	hp_bar.max_value = event.max_value
	hp_bar.value = event.current
	hp_label.text = "生命 %d / %d" % [event.current, event.max_value]

func _on_ammo_changed(event: AmmoChangedEvent) -> void:
	_cached_ammo = {"mag": event.mag, "reserve": event.reserve}
	_refresh_ammo_label()

func _on_weapon_switched(event: WeaponSwitchedEvent) -> void:
	_current_slot_type = event.slot_type
	switch_label.visible = false
	reload_label.visible = false
	_update_slot_highlight()
	_refresh_ammo_label()

func _on_switch_started(event: WeaponSwitchStartedEvent) -> void:
	switch_label.text = "切换中… %.1fs" % event.switch_cd
	switch_label.visible = true
	_switch_timer = event.switch_cd

func _on_switch_rejected(event: WeaponSwitchRejectedEvent) -> void:
	match event.reason:
		WeaponSwitchRejectedEvent.REASON_EMPTY:
			switch_label.text = "%d 号槽位未装备（M1 实装副武器）" % (event.slot_index + 1)
		_:
			switch_label.text = "正在切换…"
	switch_label.visible = true
	_switch_timer = 1.5

func _on_reload_started(event: ReloadStartedEvent) -> void:
	reload_label.text = "换弹中… %.1fs" % event.duration
	reload_label.visible = true
	_reload_timer = event.duration

func _on_base_durability(event: BaseDurabilityChangedEvent) -> void:
	base_bar.max_value = event.max_value
	base_bar.value = event.current
	base_label.text = "基地 %d / %d" % [event.current, event.max_value]

func _on_wave_warning(event: WaveWarningEvent) -> void:
	wave_label.text = "第 %d / %d 波" % [event.wave_index, event.wave_total]
	# 只报来袭方位，不报数量（M0 修订：不明确敌人数量更有压迫感，见圆环刷新设计）
	var parts: Array[String] = []
	for group: WaveComposition.SpawnGroup in event.composition.groups:
		parts.append(DirectionUtils.arrow(group.direction))
	compass_label.text = "来袭：%s" % "  ".join(parts)
	compass_label.visible = true
	_show_banner("第 %d 波预警：%s" % [event.wave_index, "  ".join(parts)], 2.5)

func _on_wave_started(_event: WaveStartedEvent) -> void:
	_show_banner("接敌！", 1.5)

func _on_wave_cleared(event: WaveClearedEvent) -> void:
	_show_banner("第 %d 波击退。喘口气。" % event.wave_index, 2.0)

func _on_player_died(_event: PlayerDiedEvent) -> void:
	_show_banner("你阵亡了——基地还在，暂时没人来扶你。（复活系统 M1 接入）", 4.0)

# ─── 内部 ───

func _refresh_ammo_label() -> void:
	if _current_slot_type == WeaponTypeData.SlotType.PISTOL:
		# 手枪（P25 修订）：弹匣有限、备弹无限
		var mag := int(_cached_ammo.get("mag", 0))
		ammo_label.text = "弹药 %d / %s" % [mag, INFINITE_TEXT]
		return
	if _cached_ammo.is_empty():
		ammo_label.text = "弹药 --"
		return
	var reserve_text := INFINITE_TEXT if int(_cached_ammo["reserve"]) == AmmoSystem.INFINITE \
		else str(_cached_ammo["reserve"])
	ammo_label.text = "弹药 %d / %s" % [_cached_ammo["mag"], reserve_text]

func _update_slot_highlight() -> void:
	slot_main_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.MAIN else Color(1, 1, 1, 0.45)
	slot_sub_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.SUB else Color(1, 1, 1, 0.45)
	slot_pistol_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.PISTOL else Color(1, 1, 1, 0.45)

func _show_banner(text: String, duration: float) -> void:
	banner_label.text = text
	banner_label.visible = true
	_banner_timer = duration
