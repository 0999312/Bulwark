class_name DefenseFacilityData
extends Resource
## 防线设施数据（架构 §4.7 DefenseFacilityData）
## M1 实装：路障（阻挡/拖延怪物推进，可被敌人攻击摧毁，消耗建材建造）
## 弧形路障：沿基地同心圆弧段（弧心 = 基地），弧线穿过玩家站位

enum FacilityType {
	BARRICADE = 0, # 路障（M1 唯一实装）
	# TURRET / AMMO_DEPOT / SPIKE / REPAIR_STATION 为 M3+ 扩展（§7.3 设施池）
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

@export_group("表现")
## 视觉尺寸（表现层缩放参考；弧形路障不再使用，保留向后兼容）
@export var visual_size: Vector2 = Vector2(80.0, 24.0)

@export_group("弧形路障")
## 弧线覆盖角（度）：路障作为"防线片段"的弧长（审查硬性 ≤60° 防卡堆；建议区间 45~60）
@export var arc_degrees: float = 60.0
## 弧线径向厚度（px）：建议 20~24px
@export var arc_thickness: float = 22.0
