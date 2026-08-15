class_name BarricadeView
extends StaticBody2D
## 路障表现层（前端）：弧形碰撞阻挡敌人 + 耐久视觉 + 受击/摧毁反馈
## - 后端 BarricadeController 持有耐久；本节点订阅事件做展示与移除
## - 碰撞：layer 8（world）——敌人（mask 13 = 1|4|8）被阻挡，玩家（mask 6）不受影响
## - 弧形几何：弧心 = 基地（局部 +Y），弧线穿过玩家脚下；align_to_arc 旋转 + 重建弧面/碰撞

@onready var outline: Polygon2D = $Outline
@onready var visual: Polygon2D = $Visual
@onready var spikes: Polygon2D = $Spikes
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var controller: BarricadeController

var _destroyed_freed := false
## 弧半径（玩家到基地距离，clamp 后）；0 = 尚未对齐
var _arc_radius := 0.0

## 弧面几何参数兜底（与 facility_barricade.tres 对齐；数据未配置时使用）
const DEFAULT_ARC_DEGREES := 60.0
const DEFAULT_ARC_THICKNESS := 22.0
const ARC_SAMPLES := 28            # 外圈采样段数
const SPIKE_COUNT := 12            # 尖刺数量
const SPIKE_LENGTH := 9.0          # 尖刺长度（px）
const OUTLINE_WIDTH := 3.0         # 描边宽度（px）

func setup(p_controller: BarricadeController) -> void:
	controller = p_controller
	EventBus.subscribe(&"BarricadeDamagedEvent", _on_damaged)
	EventBus.subscribe(&"BarricadeDestroyedEvent", _on_destroyed)

## 对齐弧线：把局部 +Y（弧心所在方向）旋转到"玩家→基地"方向，并按半径重建弧面/碰撞
## base_pos：基地全局坐标
func align_to_arc(base_pos: Vector2) -> void:
	var base_dir := base_pos - global_position
	var radius := base_dir.length()
	var arc_degrees := DEFAULT_ARC_DEGREES
	var thickness := DEFAULT_ARC_THICKNESS
	if controller != null and controller.data != null:
		arc_degrees = controller.data.arc_degrees
		thickness = controller.data.arc_thickness
	# 防御：半径过小会让内圈半径非正，clamp 到至少一个厚度（测试注入基地位置时 radius=0）
	_arc_radius = maxf(radius, thickness)
	# 朝向推导：弧心在局部 +Y（(0, R)），局部 +Y 需转到 base_dir；
	# 局部 +Y 的角度为 PI/2，故 rotation = base_dir.angle() - PI/2。
	# base_dir 为零向量时 angle()=0，rotation 退化为 -PI/2，无实际影响。
	rotation = base_dir.angle() - PI * 0.5
	_rebuild_arc_geometry(arc_degrees, thickness)

## 按当前半径重建弧面（主体/描边/尖刺）与凹碰撞
func _rebuild_arc_geometry(arc_degrees: float, thickness: float) -> void:
	var half := deg_to_rad(arc_degrees) * 0.5
	var center := Vector2(0.0, _arc_radius)  # 弧心在局部 +Y（旋转后指向基地）
	var body_poly := BarricadeController.build_arc_polygon(center, half, thickness, ARC_SAMPLES)
	# 碰撞：弧带为凹多边形（内圈向弧心凹入），用 ConcavePolygonShape2D 线段模式
	var shape := ConcavePolygonShape2D.new()
	shape.segments = BarricadeController.build_arc_segments(center, half, thickness, ARC_SAMPLES)
	collision_shape.shape = shape
	# 主体弧面
	visual.polygon = body_poly
	# 描边：向外扩一圈（外圈 +outline、内圈 -outline），先绘制被主体盖住只露边框
	outline.polygon = BarricadeController.build_arc_polygon(
		center, half, thickness + OUTLINE_WIDTH * 2.0, ARC_SAMPLES)
	# 尖刺：朝向基地一侧（内圈向弧心方向伸出）
	spikes.polygon = BarricadeController.build_spike_polygon(
		center, half, thickness, SPIKE_LENGTH, SPIKE_COUNT)

func get_location() -> String:
	if controller == null:
		return ""
	return controller.get_location()

func _on_damaged(event: BarricadeDamagedEvent) -> void:
	if controller == null or event.facility_location != controller.get_location():
		return
	# 受击闪白（简易反馈，三块视觉一起闪）
	_set_flash(Color(1.0, 0.7, 0.7))
	var tw := create_tween()
	tw.tween_property(visual, "self_modulate", Color.WHITE, 0.15)
	tw.parallel().tween_property(spikes, "self_modulate", Color.WHITE, 0.15)
	tw.parallel().tween_property(outline, "self_modulate", Color.WHITE, 0.15)

func _on_destroyed(event: BarricadeDestroyedEvent) -> void:
	if controller == null or event.facility_location != controller.get_location():
		return
	if _destroyed_freed:
		return
	_destroyed_freed = true
	# 拆除反馈：短暂放大 + 整体淡出后移除（GameSession 也会清理引用）
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)

func _set_flash(color: Color) -> void:
	visual.self_modulate = color
	spikes.self_modulate = color
	outline.self_modulate = color
