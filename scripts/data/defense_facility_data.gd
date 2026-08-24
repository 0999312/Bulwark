class_name DefenseFacilityData
extends Resource
## 防线设施数据（架构 §4.7 DefenseFacilityData）
## 保留设施：路障（阻挡/拖延怪物推进）、自动炮塔（辅助火力）
## 弧形路障：沿基地同心圆弧段（弧心 = 基地），弧线穿过玩家站位

enum FacilityType {
	BARRICADE = 0,   # 路障（M1 实装）
	TURRET = 1,      # 自动炮塔（M5b）
	# 弹药补给台已移除（冗余：击杀掉弹 + 商店弹药箱已覆盖补给闭环）
}

@export_group("标识")
@export var id: String = ""
@export var display_name: String = ""
@export var facility_type: FacilityType = FacilityType.BARRICADE

@export_group("数值")
## 耐久上限（敌人攻击按 attack_damage 扣减）
@export var max_durability: float = 150.0
## 建造消耗建材
@export var material_cost: int = 1
## 建造半径限制（距基地中心；路障需布防在基地附近）
@export var build_radius: float = 500.0

@export_group("炮塔")
## 自动炮塔：单发伤害（host 结算；温和削弱：10→6）
@export var turret_damage: float = 6.0
## 自动炮塔：射速（发/秒；温和削弱：2.0→1.5）
@export var turret_fire_rate: float = 1.5
## 自动炮塔：索敌/射程（像素；温和削弱：500→360）
@export var turret_range: float = 360.0
## 最小修复：每次修复消耗建材
@export var repair_cost: int = 1
## 最小修复：每次修复恢复耐久
@export var repair_amount: float = 50.0

@export_group("表现")
## 视觉尺寸（表现层缩放参考；弧形路障不再使用，保留向后兼容）
@export var visual_size: Vector2 = Vector2(80.0, 24.0)

@export_group("弧形路障")
## 弧线覆盖角（度）：路障作为"防线片段"的弧长（审查硬性 ≤60° 防卡堆；建议区间 45~60）
@export var arc_degrees: float = 60.0
## 弧线径向厚度（px）：建议 20~24px
@export var arc_thickness: float = 22.0
