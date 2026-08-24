class_name WeaponModelData
extends Resource
## 武器型号数据（两级设计第 2 级，已定 P10/P26）
## 同类下不同型号 = 数值微调 + 独特词条；命名虚构（P26，如 "风暴-7 突击步枪"）。
## 字段草案见 architecture-design.md §5。

@export_group("标识")
@export var id: String = ""
## 关联 WeaponTypeData 的 ResourceLocation 字符串（如 "bulwark:weapon/type/ar"）
@export var type_id: String = ""
@export var display_name: String = ""

@export_group("数值")
@export var damage: float = 10.0
## 射速：每秒发数
@export var fire_rate: float = 8.0
@export var mag_size: int = 30
@export var reload_time: float = 1.2
## 散布（度）：子弹方向的最大随机偏移角；表现层 HITSCAN 弹道应用（M0 已参与结算）
@export var spread: float = 0.0
@export var crit_chance: float = 0.1
@export var crit_multiplier: float = 2.0
## 有效射程（像素，HITSCAN 射线长度）
@export var range: float = 900.0
## 弹丸数（SPREAD 弹道：每发开火散射 n 条弹道；≥2 为霰弹）
@export var pellets: int = 1

@export_group("词条")
## 独特词条列表（P26，如 PIERCE / BURN / EXTENDED_MAG；M0 空，结构留位）
@export var keywords: Array[String] = []
