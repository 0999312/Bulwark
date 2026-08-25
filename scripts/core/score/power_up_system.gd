class_name PowerUpSystem
extends RefCounted
## 波中道具系统（P1-12，后端纯逻辑可 GUT 测）
## - 计时 buff：key = "power_id|player_id"；tick 递减，到期回调 expire_cb 并广播 PowerUpExpiredEvent
## - 即时效果：activate 时直接调用 apply_cb（不进入计时）
## - 应用/回收由装配层注入回调（GameSession 裁决玩家/武器数值，保持后端无场景依赖）

var _active: Dictionary = {}  # key -> {data: PowerUpData, player_id:int, remaining:float}
var _apply_cb: Callable = Callable()
var _expire_cb: Callable = Callable()

func setup(p_apply_cb: Callable, p_expire_cb: Callable) -> void:
	_apply_cb = p_apply_cb
	_expire_cb = p_expire_cb

## 激活道具；data.duration <= 0 视为即时效
func activate(data: PowerUpData, player_id: int) -> void:
	if data == null:
		return
	if data.duration > 0.0:
		var key := _key(data.id, player_id)
		if _active.has(key):
			# 刷新时长（修正已应用，不重复叠加）
			_active[key]["remaining"] = data.duration
			return
		_active[key] = {"data": data, "player_id": player_id, "remaining": data.duration}
		_apply(data, player_id)
	else:
		_apply(data, player_id)

## 每帧驱动 buff 计时
func tick(delta: float) -> void:
	if _active.is_empty():
		return
	var expired: Array[String] = []
	for key: String in _active.keys():
		var entry: Dictionary = _active[key]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			expired.append(key)
	for key: String in expired:
		var entry: Dictionary = _active[key]
		var data := entry["data"] as PowerUpData
		var pid := int(entry["player_id"])
		_active.erase(key)
		if _expire_cb.is_valid():
			_expire_cb.call(data, pid)
		EventBus.publish(PowerUpExpiredEvent.new(data.id, pid))

func is_active(power_id: String, player_id: int) -> bool:
	return _active.has(_key(power_id, player_id))

func get_remaining(power_id: String, player_id: int) -> float:
	var entry: Variant = _active.get(_key(power_id, player_id))
	if entry == null:
		return 0.0
	return float((entry as Dictionary).get("remaining", 0.0))

## 活跃 buff 摘要（HUD 显示用）：Array[Dictionary]（power_id/remaining/duration）
func get_active_summary(player_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry_v: Variant in _active.values():
		var entry: Dictionary = entry_v
		if int(entry.get("player_id", -1)) != player_id:
			continue
		var data := entry["data"] as PowerUpData
		out.append({
			"id": data.id,
			"name": data.display_name,
			"remaining": float(entry.get("remaining", 0.0)),
			"duration": data.duration,
		})
	return out

## 分数加倍统计（分数加速道具：取所有活跃项乘数之积；默认 1.0）
func score_multiplier(player_id: int) -> float:
	var mult := 1.0
	for entry_v: Variant in _active.values():
		var entry: Dictionary = entry_v
		if int(entry.get("player_id", -1)) != player_id:
			continue
		var data := entry["data"] as PowerUpData
		if data != null and data.effect == PowerUpData.EffectKind.SCORE_MULT:
			mult *= maxf(0.0, data.amount)
	return mult

func clear() -> void:
	_active.clear()

func _key(power_id: String, player_id: int) -> String:
	return "%s|%d" % [power_id, player_id]

func _apply(data: PowerUpData, player_id: int) -> void:
	if _apply_cb.is_valid():
		_apply_cb.call(data, player_id)
