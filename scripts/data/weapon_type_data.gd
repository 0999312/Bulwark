class_name WeaponTypeData
extends Resource
## 武器种类数据（两级设计第 1 级，已定 P10）
## 决定手感 / 定位 / 弹药类型 / 弹道特征 / 切换 CD 档（已定 P23）
## 字段草案见 architecture-design.md §5；内容一律经 Registry + ResourceLocation 注册（bulwark 命名空间）。

enum SlotType {
	MAIN = 0,   # 主武器
	SUB = 1,    # 副武器
	PISTOL = 2, # 手枪（应急位，已定 P25：无限备弹、低伤害、快速拔枪）
}

enum AmmoType {
	BULLET = 0, # 子弹
	FUEL = 1,   # 燃料
	GRENADE = 2,# 榴弹
	ENERGY = 3, # 能量
}

enum BallisticMode {
	HITSCAN = 0,   # 步枪类（M0 突击步枪使用）
	PROJECTILE = 1,# 普通弹道
	SPREAD = 2,    # 霰弹
	PARABOLA = 3,  # 榴弹
	PIERCE = 4,    # 贯穿
	CHARGE = 5,    # 蓄力
	BEAM = 6,      # 能量束
	FLAME = 7,     # 喷火
}

@export_group("标识")
## 注册 id（不含命名空间，如 "assault_rifle"）；注册时拼为 bulwark:weapon/type/assault_rifle
@export var id: String = ""
@export var display_name: String = ""

@export_group("定位")
@export var slot: SlotType = SlotType.MAIN
@export var ammo_type: AmmoType = AmmoType.BULLET
@export var ballistic: BallisticMode = BallisticMode.HITSCAN

@export_group("手感")
## 切换 CD（P23）：主↔副 1.5s，↔手枪 0.3s（切换规则见 WeaponSlots，取两者 min）
@export var switch_cd: float = 1.5
## 后坐手感（M0 表现层生效）：x = 连射热度系数（每发热度增量乘数，决定散布扩散速度）；
## y = 枪口后坐幅度系数（枪口回退像素乘数）
@export var recoil: Vector2 = Vector2.ONE
@export var muzzle_speed: float = 100.0
