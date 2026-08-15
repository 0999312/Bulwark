class_name BarricadeController
extends RefCounted
## 路障后端（纯逻辑；架构 §4.7 设施）
## - 耐久：敌人攻击（EnemyAttackEvent target=路障）经装配层结算扣减
## - 归零 → 摧毁事件（表现层移除节点）
## - 实例标识：facility_location（数据） + instance_id（同数据多实例区分，装配层分配）

var data: DefenseFacilityData
var instance_id: int = 0
var durability: float = 0.0
var max_durability: float = 0.0

var _destroyed_reported := false

func _init(p_data: DefenseFacilityData, p_instance_id: int = 0) -> void:
	data = p_data
	instance_id = p_instance_id
	max_durability = p_data.max_durability
	durability = p_data.max_durability

func is_destroyed() -> bool:
	return _destroyed_reported

## 唯一标识（同数据多实例区分）：如 "bulwark:facility/barricade#3"
## 事件路由（EnemyAttackEvent.target）与表现层节点查找共用
func get_location() -> String:
	return "%s#%d" % [Bulwark.loc(data.id).to_string(), instance_id]

func get_durability_ratio() -> float:
	if max_durability <= 0.0:
		return 0.0
	return durability / max_durability

## 受击（敌人攻击结算入口；防御减免走伤害管道，M1 路障无护甲直接扣减）
func take_damage(amount: float) -> float:
	if _destroyed_reported or amount <= 0.0:
		return durability
	durability = maxf(0.0, durability - amount)
	EventBus.publish(BarricadeDamagedEvent.new(get_location(), durability, max_durability))
	if durability <= 0.0 and not _destroyed_reported:
		_destroyed_reported = true
		EventBus.publish(BarricadeDestroyedEvent.new(get_location()))
	return durability


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
