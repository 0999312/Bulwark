class_name TurretController
extends FacilityController
## 自动炮塔后端（M5b，纯逻辑）：host 索敌 + HitscanResolver 结算 + 事件驱动表现
## - GameSession 每帧喂入敌人目标表（{net_id, pos, radius, alive}）
## - 射程内取最近目标，冷却结束广播 TurretFiredEvent（host 应用伤害，client 表现）
## - 耐久/修复复用 FacilityController
## - damage_bonus：放置者的炮塔伤害强化（商店"炮塔伤害+1"落 RunState.bonus，放置时快照）

var position: Vector2 = Vector2.ZERO
var cooldown: float = 0.0
var damage_bonus: float = 0.0

func _init(p_data: DefenseFacilityData, p_instance_id: int = 0,
		p_damage_bonus: float = 0.0) -> void:
	super(p_data, p_instance_id)
	damage_bonus = maxf(0.0, p_damage_bonus)

func setup_position(p_position: Vector2) -> void:
	position = p_position

func get_damage() -> float:
	return data.turret_damage + damage_bonus

func tick(delta: float, enemies: Array) -> void:
	if is_destroyed():
		return
	if cooldown > 0.0:
		cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0:
		return
	var target := _acquire_target(enemies)
	if target.is_empty():
		return
	var target_pos: Vector2 = target.get(&"pos", Vector2.ZERO)
	var hit_point: Vector2 = target.get(&"hit_point", target_pos)
	var target_id: int = target.get(&"net_id", -1)
	cooldown = 1.0 / maxf(0.01, data.turret_fire_rate)
	# target_position = 射线命中点（圆面进入点），host/client 粗射线都画到该点
	EventBus.publish(TurretFiredEvent.new(
		get_location(), position, hit_point, target_id, get_damage()))

func _acquire_target(enemies: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_dist_sq := INF
	for e in enemies:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		if not bool(ed.get(&"alive", true)):
			continue
		var pos: Vector2 = ed.get(&"pos", Vector2.ZERO)
		var radius := float(ed.get(&"radius", 14.0))
		var dist_sq := position.distance_squared_to(pos)
		if dist_sq <= data.turret_range * data.turret_range and dist_sq < best_dist_sq:
			# 用 HitscanResolver 做一次线段命中确认（目标圆必须被射程线段覆盖）
			var res := HitscanResolver.resolve_hit(
				position, (pos - position).normalized(), data.turret_range,
				[{&"pos": pos, &"radius": radius}])
			if bool(res.get(&"hit", false)):
				best_dist_sq = dist_sq
				best = {
					&"net_id": int(ed.get(&"net_id", -1)),
					&"pos": pos,
					&"hit_point": Vector2(res.get(&"point", pos)),
				}
	return best
