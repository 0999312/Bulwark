extends Node
## M4 光标状态机（议题 2，D-M4-9）：
## - DEFAULT：系统箭头（无 custom cursor）
## - COMBAT：战斗准星（combat_context 启用时；GameSession 挂钩 set_combat_active）
## - PROGRESS：装填/切枪进度准星（ReloadStartedEvent / WeaponSwitchStartedEvent 计时驱动）
## 优先级：树暂停或任意面板打开 → DEFAULT；计时进行中 → PROGRESS；combat_active → COMBAT。
## 状态变化才调用 Input.set_custom_mouse_cursor（避免每帧重建光栅）。

const CROSS_TEXTURE := preload("res://assets/cursors/target_a.png")
const PROGRESS_25 := preload("res://assets/cursors/progress_CCW_25.png")
const PROGRESS_50 := preload("res://assets/cursors/progress_CCW_50.png")
const PROGRESS_75 := preload("res://assets/cursors/progress_CCW_75.png")
const PROGRESS_EMPTY := preload("res://assets/cursors/progress_empty.png")
const PROGRESS_FULL := preload("res://assets/cursors/progress_full.png")

enum State { DEFAULT, COMBAT, PROGRESS }

var _state: int = State.DEFAULT
var _combat_active := false
var _open_panels := 0
var _reload_remaining := 0.0
var _reload_total := 1.0
var _switch_remaining := 0.0
var _switch_total := 1.0
var _last_progress_texture: Texture2D

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
	_refresh()

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
			_last_progress_texture = null
		State.COMBAT:
			Input.set_custom_mouse_cursor(CROSS_TEXTURE, Input.CURSOR_ARROW, Vector2(16, 16))
			_last_progress_texture = null
		State.PROGRESS:
			_last_progress_texture = progress_texture
			Input.set_custom_mouse_cursor(progress_texture, Input.CURSOR_ARROW, Vector2(16, 16))

## 进度帧：按「已完成比例」选 空/25/50/75/满 五帧（Kenney progress_CCW 系列）。
## BUG 修复：此前误用剩余比例，导致进度圈从满圈倒退为空圈（从有到无）；
## 直觉应为从空到满（进度填充）。
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
