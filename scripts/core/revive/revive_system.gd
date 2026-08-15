class_name ReviveSystem
extends RefCounted
## 复活系统（后端，纯逻辑；P7/P20）
## - 玩家阵亡 → 消耗 1 应急储备 → 进入复活 CD（复活本身耗时）→ CD 结束广播 RevivedEvent
## - 储备不足 → 返回失败（装配层据此走 RunDefeatEvent.PLAYER_DEAD 结算）
## - CD 期间玩家保持 DEAD（表现层倒地/读条）；基地继续受敌（压力窗口）
## - 复活 CD 可被中断？M1 规则：不可中断（倒地后必然复活），保证节奏清晰

const REVIVE_CD := 4.0   # 复活耗时（秒，体感待调）

enum State {
	IDLE = 0,     # 无复活流程
	REVIVING = 1, # 复活 CD 中
}

var state: State = State.IDLE
var revive_timer: float = 0.0

var _run_state: RunState

func _init(p_run_state: RunState) -> void:
	_run_state = p_run_state

func is_reviving() -> bool:
	return state == State.REVIVING

## 玩家阵亡入口；返回是否进入复活流程（false = 储备耗尽，应由装配层判负）
func on_player_died() -> bool:
	if state == State.REVIVING:
		return false
	if not _run_state.try_spend_reserve(1):
		return false
	state = State.REVIVING
	revive_timer = REVIVE_CD
	EventBus.publish(ReviveStartedEvent.new(REVIVE_CD))
	return true

## 每帧驱动（复活 CD 计时；装配层在非暂停时驱动）
func tick(delta: float) -> void:
	if state != State.REVIVING:
		return
	revive_timer -= delta
	if revive_timer <= 0.0:
		state = State.IDLE
		revive_timer = 0.0
		EventBus.publish(RevivedEvent.new(0.0, 0.0))  # 血量由装配层（PlayerController）填充

func get_revive_progress() -> float:
	if state != State.REVIVING or REVIVE_CD <= 0.0:
		return 0.0
	return 1.0 - clampf(revive_timer / REVIVE_CD, 0.0, 1.0)
