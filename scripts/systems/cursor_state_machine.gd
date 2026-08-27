extends Node
## M4 光标状态机（议题 2，D-M4-9 + M4 手感补全）：
## - DEFAULT：系统箭头（无 custom cursor）
## - COMBAT：战斗准星（combat_context 启用时；GameSession 挂钩 set_combat_active）
## - PROGRESS：装填/切枪进度准星（ReloadStartedEvent / WeaponSwitchStartedEvent 计时驱动）
## 优先级：树暂停或任意面板打开 → DEFAULT；计时进行中 → PROGRESS；combat_active → COMBAT。
## M4 之后：COMBAT 支持热态（heat/HEAT_MAX → target_a→target_round_b 或 cross_small→cross_large），
## heat 由 GameSession 注入 _heat_source（host 权威 / client 快照镜像）；状态变化才设置光标。

const CROSS_TEXTURE := preload("res://assets/cursors/target_a.png")
const CROSS_HOT := preload("res://assets/cursors/target_round_b.png")
const CROSS_SMALL := preload("res://assets/cursors/cross_small.png")
const CROSS_LARGE := preload("res://assets/cursors/cross_large.png")
const PROGRESS_25 := preload("res://assets/cursors/progress_CCW_25.png")
const PROGRESS_50 := preload("res://assets/cursors/progress_CCW_50.png")
const PROGRESS_75 := preload("res://assets/cursors/progress_CCW_75.png")
const PROGRESS_EMPTY := preload("res://assets/cursors/progress_empty.png")
const PROGRESS_FULL := preload("res://assets/cursors/progress_full.png")

## 热态切换阈值（heat 0~HEAT_MAX=4；超过一半进入热态扩散帧）
const HEAT_BLOOM_THRESHOLD := 2.0

enum State { DEFAULT, COMBAT, PROGRESS }

var _state: int = State.DEFAULT
var _combat_active := false
var _open_panels := 0
var _reload_remaining := 0.0
var _reload_total := 1.0
var _switch_remaining := 0.0
var _switch_total := 1.0
var _last_progress_texture: Texture2D
var _combat_heat := 0.0
var _heat_source: Callable = Callable()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.subscribe(&"ReloadStartedEvent", _on_reload_started)
	EventBus.subscribe(&"WeaponSwitchStartedEvent", _on_switch_started)
	EventBus.subscribe(&"UIOpenEvent", _on_ui_open)
	EventBus.subscribe(&"UICloseEvent", _on_ui_close)

## GameSession._setup_input 启用 combat_context 时调用；_exit_tree 置 false（同点清理）
func set_combat_active(active: bool) -> void:
	_combat_active = active
	if not active:
		_reload_remaining = 0.0
		_switch_remaining = 0.0
		_combat_heat = 0.0
	_refresh()

## M4：heat 数据源（GameSession 注入；host 权威 / client 快照镜像的属性读取）
func set_heat_source(source: Callable) -> void:
	_heat_source = source

func set_combat_heat(value: float) -> void:
	_combat_heat = maxf(0.0, value)

## 供 CrosshairView 读取（每帧，属性访问）
func get_combat_heat() -> float:
	return _combat_heat

## 战斗准星覆盖层是否应显示（COMBAT 且无面板/暂停/换弹）
func is_combat_overlay_visible() -> bool:
	return _combat_active and _open_panels <= 0 and not get_tree().paused \
		and _reload_remaining <= 0.0 and _switch_remaining <= 0.0

func _on_reload_started(event: ReloadStartedEvent) -> void:
	if event == null or not _is_local_player(event.player_id):
		return
	_reload_total = maxf(0.01, event.duration)
	_reload_remaining = _reload_total

func _on_switch_started(event: WeaponSwitchStartedEvent) -> void:
	if event == null or not _is_local_player(event.player_id):
		return
	_switch_total = maxf(0.01, event.switch_cd)
	_switch_remaining = _switch_total

func _on_ui_open(_event: RefCounted) -> void:
	_open_panels += 1
	_refresh()

func _on_ui_close(_event: RefCounted) -> void:
	_open_panels = maxi(0, _open_panels - 1)
	_refresh()

func _is_local_player(pid: int) -> bool:
	if Net.is_client():
		return pid == Net.get_local_player_id()
	return pid == 0

func _process(delta: float) -> void:
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(0.0, _reload_remaining - delta)
		if _reload_remaining <= 0.0:
			_refresh()
	if _switch_remaining > 0.0:
		_switch_remaining = maxf(0.0, _switch_remaining - delta)
		if _switch_remaining <= 0.0:
			_refresh()
	if _combat_active and _heat_source.is_valid():
		_combat_heat = maxf(0.0, float(_heat_source.call()))
	_refresh()

func _refresh() -> void:
	var next := State.DEFAULT
	if get_tree().paused or _open_panels > 0:
		next = State.DEFAULT
	elif _reload_remaining > 0.0 or _switch_remaining > 0.0:
		next = State.PROGRESS
	elif _combat_active:
		next = State.COMBAT
	var progress_texture := _progress_texture() if next == State.PROGRESS else null
	if next == _state and not (next == State.PROGRESS and progress_texture != _last_progress_texture):
		return
	_state = next
	match _state:
		State.DEFAULT:
			Input.set_custom_mouse_cursor(null)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_last_progress_texture = null
		State.COMBAT:
			# 准星由 CrosshairView 绘制（含后坐抖动/热态扩散），隐藏 OS 光标
			Input.set_custom_mouse_cursor(null)
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			_last_progress_texture = null
		State.PROGRESS:
			_last_progress_texture = progress_texture
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Input.set_custom_mouse_cursor(progress_texture, Input.CURSOR_ARROW, Vector2(16, 16))

## M4 热态帧：style=0 → target_a→target_round_b；style=1 → cross_small→cross_large；
## spread_visual 关闭时始终用基础帧（散布逻辑不变，仅可视化关闭）
func _combat_texture() -> Texture2D:
	var style := SettingsManager.get_cursor_style()
	var spread_visual := SettingsManager.is_spread_visual_enabled()
	var base: Texture2D = CROSS_SMALL if style == 1 else CROSS_TEXTURE
	if not spread_visual or _combat_heat < HEAT_BLOOM_THRESHOLD:
		return base
	return CROSS_LARGE if style == 1 else CROSS_HOT

## 进度帧：按「已完成比例」选 空/25/50/75/满 五帧（Kenney progress_CCW 系列）。
func _progress_texture() -> Texture2D:
	var remaining_ratio := 0.0
	if _reload_remaining > 0.0:
		remaining_ratio = _reload_remaining / _reload_total
	else:
		remaining_ratio = _switch_remaining / _switch_total
	var progress := clampf(1.0 - remaining_ratio, 0.0, 1.0)
	if progress >= 0.9:
		return PROGRESS_FULL
	if progress >= 0.65:
		return PROGRESS_75
	if progress >= 0.4:
		return PROGRESS_50
	if progress >= 0.15:
		return PROGRESS_25
	return PROGRESS_EMPTY
