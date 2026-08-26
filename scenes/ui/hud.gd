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
@onready var banner_lore_label: Label = %BannerLoreLabel
@onready var banner_bg: Panel = %BannerBG
@onready var compass_label: Label = %CompassLabel
@onready var score_label: Label = %ScoreLabel
@onready var combo_label: Label = %ComboLabel
@onready var buff_label: Label = %BuffLabel
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_label: Label = %BossLabel
@onready var ammo_row: HBoxContainer = %AmmoLabel
@onready var ammo_title_label: Label = %AmmoTitle
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
@onready var pause_hint_label: Label = %PauseHintLabel

var _banner_timer := 0.0
var _reload_timer := 0.0
var _switch_timer := 0.0
var _revive_timer := 0.0
var _hp_tween: Tween
var _base_tween: Tween
var _revive_active := false
var _current_slot_type: int = WeaponTypeData.SlotType.MAIN
var _cached_ammo: Dictionary = {}  # {mag:int, reserve:int}
var _cached_health: Dictionary = {}
var _cached_base: Dictionary = {}
var _cached_resources: Array = []
var _cached_wave: Dictionary = {}
var _cached_facility_type: int = DefenseFacilityData.FacilityType.BARRICADE
var _cached_pause_requests: Array = []
var _cached_pause_total := 2
## P1 街机化缓存
var _cached_score: Dictionary = {"score": 0, "combo": 0, "mult": 1.0}
var _buff_timers: Dictionary = {}  # power_id -> {remaining, duration}
var _boss_name := ""
## M2 多人：本 HUD 只显示该玩家 id 的数据（host/单机 = 0；client = 1）
var _local_player_id := 0

## M2 多人：绑定本进程负责的玩家（GameSession 挂载时调用）
func set_local_player_id(pid: int) -> void:
	_local_player_id = pid

## M3 问题 2：全队暂停请求提示（client 跟随 ui_state 调用）
## requests = 请求暂停的玩家 id 列表（host 汇总）；total = 在线玩家数
func set_facility_hint(facility_type: int) -> void:
	_cached_facility_type = facility_type
	var facility_id := "facility/barricade"
	match facility_type:
		DefenseFacilityData.FacilityType.TURRET:
			facility_id = "facility/turret"
	var name := UiText.content_name(facility_id, "?")
	hint_label.text = UiText.text("hud.facility_hint", [name])
	hint_label.visible = true

func set_pause_requests(requests: Array, total: int) -> void:
	_cached_pause_requests = requests.duplicate()
	_cached_pause_total = maxi(total, 1)
	_refresh_pause_hint()

func _refresh_pause_hint() -> void:
	if _cached_pause_requests.is_empty():
		pause_hint_label.visible = false
		return
	var parts: Array[String] = []
	for pid_v in _cached_pause_requests:
		parts.append(UiText.text("common.player_number", [int(pid_v) + 1]))
	pause_hint_label.text = UiText.text("hud.pause_requests", [
		"、".join(parts), _cached_pause_requests.size(), _cached_pause_total])
	pause_hint_label.visible = true

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
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)
	EventBus.subscribe(&"ScoreChangedEvent", _on_score_changed)
	EventBus.subscribe(&"PowerUpPickupEvent", _on_power_up_pickup)
	EventBus.subscribe(&"PowerUpExpiredEvent", _on_power_up_expired)
	EventBus.subscribe(&"EnemyHealthChangedEvent", _on_enemy_health)
	_update_slot_highlight()
	_apply_static_texts()

func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)

func _on_language_changed(_event: LanguageChangedEvent) -> void:
	_apply_static_texts()
	_refresh_pause_hint()
	_refresh_cached_texts()

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
		revive_label.text = _format_seconds("hud.revive", _revive_timer)
	if not _buff_timers.is_empty():
		var expired: Array[String] = []
		for key: String in _buff_timers.keys():
			var entry: Dictionary = _buff_timers[key]
			entry["remaining"] = float(entry["remaining"]) - delta
			if float(entry["remaining"]) <= 0.0:
				expired.append(key)
		for key: String in expired:
			_buff_timers.erase(key)
		_refresh_buff_label()

# ─── 事件订阅 ───

func _on_player_health(event: PlayerHealthChangedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_cached_health = {"current": event.current, "max": event.max_value}
	hp_bar.max_value = event.max_value
	_tween_hp(event.current)
	hp_label.text = UiText.text("hud.health", [event.current, event.max_value])

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
	switch_label.text = _format_seconds("hud.switching", event.switch_cd)
	switch_label.visible = true
	_switch_timer = event.switch_cd

func _on_switch_rejected(event: WeaponSwitchRejectedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	match event.reason:
		WeaponSwitchRejectedEvent.REASON_EMPTY:
			switch_label.text = UiText.text("hud.slot_empty", [event.slot_index + 1])
		_:
			switch_label.text = UiText.text("hud.switching_dots")
	switch_label.visible = true
	_switch_timer = 1.5

func _on_reload_started(event: ReloadStartedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	reload_label.text = _format_seconds("hud.reloading", event.duration)
	reload_label.visible = true
	_reload_timer = event.duration

func _on_base_durability(event: BaseDurabilityChangedEvent) -> void:
	_cached_base = {"current": event.current, "max": event.max_value}
	base_bar.max_value = event.max_value
	_tween_base(event.current)
	base_label.text = UiText.text("hud.base", [event.current, event.max_value])

func _on_wave_warning(event: WaveWarningEvent) -> void:
	_cached_wave = {
		"index": event.wave_index,
		"tier": event.threat_tier,
		"elite": event.has_elite,
		"cycle": event.cycle_index,
	}
	if event.cycle_index > 0:
		wave_label.text = UiText.text("hud.wave_endless", [event.cycle_index, event.wave_index])
	else:
		wave_label.text = UiText.text("hud.wave", [event.wave_index])
	# 只报数量档 + 精英标记（玩家要求：方向罗盘/文字雷达从游戏剔除）
	var tier_text := _tier_text(event.threat_tier)
	var elite_text := UiText.text("hud.elite_warning") if event.has_elite else ""
	compass_label.text = UiText.text("hud.incoming", [tier_text, elite_text])
	compass_label.visible = true
	if event.wave_in_chapter == 0 and event.chapter_index >= 0 \
			and not event.chapter_name.is_empty():
		# P1-13/P2-20 章节横幅（标题大字） + 叙事便签（小字半透明，独立样式）
		var lore_key := "lore.chapter.%d" % (event.chapter_index + 1)
		var lore_text := tr(lore_key)
		if lore_text == lore_key:
			lore_text = ""
		_show_banner(UiText.text("hud.banner_chapter",
			[event.chapter_name, event.wave_index]), 3.5, lore_text)
	else:
		_show_banner(UiText.text("hud.banner_wave_warning",
			[event.wave_index, tier_text, elite_text]), 2.5)

static func _tier_text(tier: String) -> String:
	match tier:
		WaveComposition.TIER_HEAVY:
			return UiText.text("hud.tier_heavy")
		WaveComposition.TIER_MEDIUM:
			return UiText.text("hud.tier_medium")
		WaveComposition.TIER_LIGHT:
			return UiText.text("hud.tier_light")
		_:
			return UiText.text("hud.tier_unknown")

## 保留纯函数供测试（HUD 不再调用：方向罗盘已按玩家要求从游戏剔除）
static func _format_direction_tiers(event: WaveWarningEvent) -> String:
	var tiers := event.direction_tiers
	if not tiers.is_empty():
		return _format_direction_dict(tiers)
	if event.composition == null:
		return ""
	var parts: Array[String] = []
	for group: WaveComposition.SpawnGroup in event.composition.groups:
		parts.append(DirectionUtils.arrow(group.direction))
	return " ".join(parts)

static func _format_direction_dict(tiers: Dictionary) -> String:
	if tiers.is_empty() or not (tiers.get("heavy", []) is Array):
		return ""
	var sections: Array[String] = []
	var heavy: Array = tiers.get("heavy", [])
	var light: Array = tiers.get("light", [])
	if not heavy.is_empty():
		sections.append("%s %s" % [UiText.text("hud.tier_heavy"), _arrows_text(heavy)])
	if not light.is_empty():
		sections.append("%s %s" % [UiText.text("hud.tier_light"), _arrows_text(light)])
	return " · ".join(sections)

static func _arrows_text(directions: Array) -> String:
	var parts: Array[String] = []
	for dir in directions:
		parts.append(DirectionUtils.arrow(int(dir)))
	return "".join(parts)

func _on_wave_started(_event: WaveStartedEvent) -> void:
	_show_banner(UiText.text("hud.banner_contact"), 1.5)

func _on_wave_cleared(event: WaveClearedEvent) -> void:
	_show_banner(UiText.text("hud.banner_wave_cleared", [event.wave_index]), 2.0)

# ─── P1 街机化：分数/连击 / buff 计时 / Boss 血条 ───

func _on_score_changed(event: ScoreChangedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_cached_score = {"score": event.score, "combo": event.combo, "mult": event.multiplier}
	_refresh_score_texts()

func _on_power_up_pickup(event: PowerUpPickupEvent) -> void:
	if event.player_id != _local_player_id or event.duration <= 0.0:
		return
	_buff_timers[event.power_id] = {"remaining": event.duration, "duration": event.duration}
	_refresh_buff_label()

func _on_power_up_expired(event: PowerUpExpiredEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_buff_timers.erase(event.power_id)
	_refresh_buff_label()

func _refresh_buff_label() -> void:
	if _buff_timers.is_empty():
		buff_label.text = ""
		return
	var parts: Array[String] = []
	for key: String in _buff_timers.keys():
		var entry: Dictionary = _buff_timers[key]
		var remaining := int(ceilf(float(entry["remaining"])))
		var name := UiText.content_name(key, key)
		parts.append(UiText.text("hud.buff_item", [name, remaining]))
	buff_label.text = " · ".join(parts)

func _refresh_score_texts() -> void:
	if score_label == null:
		return
	score_label.text = UiText.text("hud.score", [int(_cached_score.get("score", 0))])
	if int(_cached_score.get("combo", 0)) > 0:
		combo_label.text = UiText.text("hud.combo", [
			int(_cached_score.get("combo", 0)),
			"%.1f" % float(_cached_score.get("mult", 1.0))])
		combo_label.visible = true
	else:
		combo_label.text = ""
		combo_label.visible = false

func _on_enemy_health(event: EnemyHealthChangedEvent) -> void:
	if not event.is_elite:
		return
	if boss_bar == null:
		return
	boss_bar.max_value = maxf(1.0, event.max_value)
	boss_bar.value = maxf(0.0, event.current)
	boss_bar.visible = event.current > 0.0
	if not event.data_id.is_empty():
		_boss_name = UiText.content_name(event.data_id, event.data_id)
		boss_label.text = _boss_name
	boss_label.visible = event.current > 0.0

func _on_player_died(event: PlayerDiedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_show_banner(UiText.text("hud.banner_died"), 2.0)

func _on_run_state_changed(event: RunStateChangedEvent) -> void:
	# M3 问题 4：资源行只显示本地玩家（host/单机 = 0；client = 本地 id）
	if event.player_id != _local_player_id:
		return
	_cached_resources = [event.credits, event.material, event.reserve]
	resources_label.text = UiText.text("hud.resources",
		[event.credits, event.material, event.reserve])

func _on_revive_started(event: ReviveStartedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_revive_active = true
	_revive_timer = event.revive_cd
	revive_label.text = _format_seconds("hud.revive", _revive_timer)
	revive_label.visible = true
	revive_bg.visible = true

func _on_revived(event: RevivedEvent) -> void:
	if event.player_id != _local_player_id:
		return
	_revive_active = false
	revive_label.visible = false
	revive_bg.visible = false

# ─── 内部 ───

static func _format_seconds(key: String, seconds: float) -> String:
	return UiText.text(key, ["%.1f" % seconds])

func _apply_static_texts() -> void:
	resources_label.text = UiText.text("hud.resources_placeholder") if _cached_resources.is_empty() \
		else UiText.text("hud.resources", _cached_resources)
	hp_label.text = UiText.text("hud.health_placeholder") if _cached_health.is_empty() \
		else UiText.text("hud.health", [_cached_health.get("current", 0), _cached_health.get("max", 0)])
	base_label.text = UiText.text("hud.base_placeholder") if _cached_base.is_empty() \
		else UiText.text("hud.base", [_cached_base.get("current", 0), _cached_base.get("max", 0)])
	wave_label.text = UiText.text("hud.wave_endless",
		[int(_cached_wave.get("cycle", 0)), int(_cached_wave.get("index", -1))]) \
		if int(_cached_wave.get("cycle", 0)) > 0 else (
		UiText.text("hud.wave", [int(_cached_wave.get("index", -1))]) \
		if not _cached_wave.is_empty() else UiText.text("hud.wave_placeholder"))
	ammo_title_label.text = UiText.text("hud.ammo_title")
	slot_main_label.text = UiText.text("hud.slot_badge", [1, UiText.text("common.slot_main")])
	slot_sub_label.text = UiText.text("hud.slot_badge", [2, UiText.text("common.slot_sub")])
	slot_pistol_label.text = UiText.text("hud.slot_badge", [3, UiText.text("common.slot_pistol")])
	hint_label.text = UiText.text("hud.controls_hint") if _cached_facility_type < 0 \
		else UiText.text("hud.facility_hint", [_facility_name(_cached_facility_type)])
	_refresh_ammo_label()
	_refresh_pause_hint()
	_refresh_score_texts()
	_refresh_buff_label()

func _refresh_cached_texts() -> void:
	_apply_static_texts()
	if _revive_active:
		revive_label.text = _format_seconds("hud.revive", _revive_timer)
	if _reload_timer > 0.0:
		reload_label.text = _format_seconds("hud.reloading", _reload_timer)
	if _switch_timer > 0.0:
		switch_label.text = _format_seconds("hud.switching", _switch_timer)
	if not _cached_wave.is_empty():
		var tier_text := _tier_text(str(_cached_wave.get("tier", "")))
		var elite_text := UiText.text("hud.elite_warning") if bool(_cached_wave.get("elite", false)) else ""
		compass_label.text = UiText.text("hud.incoming", [tier_text, elite_text])

func _facility_name(facility_type: int) -> String:
	match facility_type:
		DefenseFacilityData.FacilityType.TURRET:
			return UiText.content_name("facility/turret", "自动炮塔")
		_:
			return UiText.content_name("facility/barricade", "路障")

## M5d：数值条用 tween_method 平滑过渡（≤250ms，重入前 kill）
func _tween_hp(target_value: float) -> void:
	_tween_bar_to(hp_bar, target_value, _hp_tween)

func _tween_base(target_value: float) -> void:
	_tween_bar_to(base_bar, target_value, _base_tween)

func _tween_bar_to(bar: ProgressBar, target_value: float, existing_tween: Tween) -> void:
	if bar == null:
		return
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()
	var start_value := bar.value
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: bar.value = v, start_value, target_value, 0.22)
	if existing_tween == _hp_tween:
		_hp_tween = tw
	elif existing_tween == _base_tween:
		_base_tween = tw

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
	ammo_reserve_label.text = UiText.text("hud.ammo_display", [reserve_text])

func _update_slot_highlight() -> void:
	slot_main_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.MAIN else Color(1, 1, 1, 0.45)
	slot_sub_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.SUB else Color(1, 1, 1, 0.45)
	slot_pistol_label.modulate = Color(1, 1, 1, 1) if _current_slot_type == WeaponTypeData.SlotType.PISTOL else Color(1, 1, 1, 0.45)

func _show_banner(text: String, duration: float, sub_text: String = "") -> void:
	banner_label.text = text
	banner_label.visible = true
	if banner_lore_label != null:
		banner_lore_label.text = sub_text
		banner_lore_label.visible = not sub_text.is_empty()
	banner_bg.visible = true
	_banner_timer = duration
