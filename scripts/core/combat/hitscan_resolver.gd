class_name HitscanResolver
extends RefCounted
## 命中判定（core 纯逻辑，无节点/物理空间依赖）
## - "打没打中"由本模块确定性计算（线段 vs 圆形目标集合），表现层只按结果播效果
## - 设计背景（M3 架构修订，方向 B）：M1/M2 的命中判定实为"表现层物理射线"
##   （get_world_2d().direct_space_state.intersect_ray），与渲染状态耦合——
##   碰撞体开关/物理空间状态直接影响裁决，client 端镜像敌人（碰撞禁用）导致
##   子弹视觉上穿过敌人。此处将判定几何化、数据化，host 用权威位置裁决。
## - 判定输入由装配层提供（目标位置/半径），本模块不持有任何状态

## 目标描述（判定输入）：{pos: Vector2, radius: float}
## 返回：{hit: bool, index: int, point: Vector2}
static func resolve_hit(origin: Vector2, dir: Vector2, range: float,
		targets: Array) -> Dictionary:
	if dir.length_squared() < 0.0001 or range <= 0.0:
		return {&"hit": false, &"index": -1, &"point": origin}
	var dir_n := dir.normalized()
	var range_end := origin + dir_n * range
	var best_index := -1
	var best_enter_dist_sq := INF
	var best_point := range_end
	for i in targets.size():
		var t: Dictionary = targets[i]
		var center: Vector2 = t.get(&"pos", Vector2.ZERO)
		var radius := float(t.get(&"radius", 0.0))
		if radius <= 0.0:
			continue
		# 线段到圆心的最近点（投影参数 clamp 到 [0, range]）
		var proj := (center - origin).dot(dir_n)
		var closest := origin + dir_n * clampf(proj, 0.0, range)
		var d_sq := closest.distance_squared_to(center)
		if d_sq > radius * radius:
			continue
		# 进入点：从最近点沿 -dir 回溯到圆面（子弹停在敌人表面）
		var back := sqrt(maxf(0.0, radius * radius - d_sq))
		var enter := closest - dir_n * back
		# 多目标取最近命中（按进入点与起点距离排序）
		var enter_dist_sq := origin.distance_squared_to(enter)
		if enter_dist_sq < best_enter_dist_sq:
			best_enter_dist_sq = enter_dist_sq
			best_index = i
			best_point = enter
	if best_index < 0:
		return {&"hit": false, &"index": -1, &"point": range_end}
	return {&"hit": true, &"index": best_index, &"point": best_point}
