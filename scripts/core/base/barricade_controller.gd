class_name BarricadeController
extends FacilityController
## 路障后端（纯逻辑；架构 §4.7 设施）
## - 继承 FacilityController：耐久/受击/修复/唯一标识通用
## - 归零 → 摧毁事件（表现层移除节点）
## - 弧形几何与放置公式为本类扩展

func _init(p_data: DefenseFacilityData, p_instance_id: int = 0) -> void:
	super(p_data, p_instance_id)

# ─── M4 放置几何（纯函数，headless 可测；D-M4-17） ───

## 放置位置 = 玩家与基地连线的外侧（方位角不变，半径 + forward_offset）。
## 返回 {pos: Vector2, radius: float}；radius = 放置者到基地的原距离（<0 时退回玩家站位）
static func compute_forward_placement(player_pos: Vector2, base_pos: Vector2,
		forward_offset: float) -> Dictionary:
	var base_dir := player_pos - base_pos
	var radius := base_dir.length()
	if radius <= 0.001 or forward_offset < 0.0:
		return {"pos": player_pos, "radius": radius}
	return {
		"pos": base_pos + base_dir.normalized() * (radius + forward_offset),
		"radius": radius,
	}

## 与既有路障中心的最小间距校验（防重叠堆叠；D-M4-17 规则 3）
static func has_min_spacing(candidate: Vector2, existing: Array, min_spacing: float) -> bool:
	for pos_v in existing:
		if not (pos_v is Vector2):
			continue
		if candidate.distance_to(pos_v) < min_spacing:
			return false
	return true


# ─── 弧形几何（纯函数，headless 可测；供 BarricadeView 生成弧面/碰撞/尖刺） ───

## 生成弧形路障的闭合凸多边形（外圈 + 内圈闭合，弧段外凸可直接用于 ConvexPolygonShape2D）
## center_offset：弧心在 view 局部坐标（如 Vector2(0, R)，R = 玩家到基地距离，弧心指向基地）
## half_angle：弧半角（弧度）
## thickness：径向厚度（px）
## samples：外圈采样段数 N（外圈 N+1 点 + 内圈 N+1 点，共 2N+2 点）
## 返回：外圈(angle_start→end) + 内圈(end→start) 的闭合顶点数组
static func build_arc_polygon(center_offset: Vector2, half_angle: float, thickness: float, samples: int = 24) -> PackedVector2Array:
	var radius := center_offset.length()
	var mid_angle := (-center_offset).angle()  # 弧中点（view 原点 = 玩家脚下）相对弧心的角度
	var outer_r := radius + thickness * 0.5
	var inner_r := maxf(radius - thickness * 0.5, 0.01)
	var points := PackedVector2Array()
	points.resize((samples + 1) * 2)
	for i in range(samples + 1):
		var a := mid_angle - half_angle + (half_angle * 2.0) * i / samples
		points[i] = center_offset + Vector2(cos(a), sin(a)) * outer_r
	for i in range(samples + 1):
		var a := mid_angle + half_angle - (half_angle * 2.0) * i / samples
		points[samples + 1 + i] = center_offset + Vector2(cos(a), sin(a)) * inner_r
	return points

## 生成弧形路障的碰撞线段（ConcavePolygonShape2D.segments 用；弧带是凹多边形，凸 shape 装不下）
## 返回：外圈 N 段 + 内圈 N 段 + 两端径向收口 2 段，共 (2N+2)×2 个点
## 注意：segments 是无限薄线段，敌人为低速 CharacterBody2D（≤130px/s）无穿透风险
static func build_arc_segments(center_offset: Vector2, half_angle: float, thickness: float, samples: int = 24) -> PackedVector2Array:
	var radius := center_offset.length()
	var mid_angle := (-center_offset).angle()
	var outer_r := radius + thickness * 0.5
	var inner_r := maxf(radius - thickness * 0.5, 0.01)
	var segs := PackedVector2Array()
	segs.resize((samples * 2 + 2) * 2)
	var idx := 0
	# 外圈弧（start→end 逐段）
	for i in range(samples):
		var a0 := mid_angle - half_angle + (half_angle * 2.0) * i / samples
		var a1 := mid_angle - half_angle + (half_angle * 2.0) * (i + 1) / samples
		segs[idx] = center_offset + Vector2(cos(a0), sin(a0)) * outer_r
		segs[idx + 1] = center_offset + Vector2(cos(a1), sin(a1)) * outer_r
		idx += 2
	# 内圈弧（start→end 逐段）
	for i in range(samples):
		var a0 := mid_angle - half_angle + (half_angle * 2.0) * i / samples
		var a1 := mid_angle - half_angle + (half_angle * 2.0) * (i + 1) / samples
		segs[idx] = center_offset + Vector2(cos(a0), sin(a0)) * inner_r
		segs[idx + 1] = center_offset + Vector2(cos(a1), sin(a1)) * inner_r
		idx += 2
	# 两端径向收口（外圈→内圈，闭合弧带）
	var a_start := mid_angle - half_angle
	var a_end := mid_angle + half_angle
	segs[idx] = center_offset + Vector2(cos(a_start), sin(a_start)) * outer_r
	segs[idx + 1] = center_offset + Vector2(cos(a_start), sin(a_start)) * inner_r
	segs[idx + 2] = center_offset + Vector2(cos(a_end), sin(a_end)) * outer_r
	segs[idx + 3] = center_offset + Vector2(cos(a_end), sin(a_end)) * inner_r
	return segs

## 生成弧形路障朝向基地一侧的尖刺装饰（锯齿带；非凸，仅视觉 Polygon2D）
## 尖刺从内圈弧向弧心（基地）方向伸出，符合"朝向基地一侧的尖刺"定位
## spikes：尖刺个数；spike_length：尖刺长度（px）
static func build_spike_polygon(center_offset: Vector2, half_angle: float, thickness: float, spike_length: float, spikes: int = 12) -> PackedVector2Array:
	var radius := center_offset.length()
	var mid_angle := (-center_offset).angle()
	var inner_r := maxf(radius - thickness * 0.5, 0.01)
	var start_angle := mid_angle - half_angle
	var end_angle := mid_angle + half_angle
	var points := PackedVector2Array()
	points.resize((spikes + 1) + spikes * 2 + 1)
	# 下边：内圈弧平滑 start→end
	for i in range(spikes + 1):
		var a := start_angle + (end_angle - start_angle) * i / spikes
		points[i] = center_offset + Vector2(cos(a), sin(a)) * inner_r
	# 上边：锯齿 end→start（每段 = 底点 + 向内尖顶点）
	var idx := spikes + 1
	for i in range(spikes, 0, -1):
		var a_cur := start_angle + (end_angle - start_angle) * i / spikes
		var a_prev := start_angle + (end_angle - start_angle) * (i - 1) / spikes
		points[idx] = center_offset + Vector2(cos(a_cur), sin(a_cur)) * inner_r
		points[idx + 1] = center_offset + Vector2(cos((a_cur + a_prev) * 0.5), sin((a_cur + a_prev) * 0.5)) * (inner_r - spike_length)
		idx += 2
	# 闭合回 start 底点
	points[idx] = center_offset + Vector2(cos(start_angle), sin(start_angle)) * inner_r
	return points
