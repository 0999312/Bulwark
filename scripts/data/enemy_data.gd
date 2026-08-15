class_name EnemyData
extends Resource
## 敌人数据（异变体，已定 P5）
## 数据驱动参数：血量/移速/威胁模式/行为参数；掉落表留位（M0 无掉落）。
## 字段草案见 architecture-design.md §5；敌人类型池见 game-design-doc.md §8.2。

enum ThreatMode {
	RUNNER = 0,        # 奔跑者：近战冲锋（M0 唯一实装）
	SELF_DESTRUCT = 1, # 自爆体：贴近自爆
	ARMORED = 2,       # 装甲兽：高血、方向性护甲（P31 占位）
	SPITTER = 3,       # 喷吐者：远程弹幕
	SNIPER = 4,        # 狙击手怪：蓄力点名
	FLYING = 5,        # 飞行体：绕后
	AMBUSHER = 6,      # 潜伏者：隐匿突袭（扩展池）
	ELITE = 7,         # 精英·巨兽：波次核心（P27 预留）
}

@export_group("标识")
@export var id: String = ""
@export var display_name: String = ""

@export_group("行为")
@export var threat_mode: ThreatMode = ThreatMode.RUNNER

@export_group("数值")
@export var max_hp: float = 30.0
@export var move_speed: float = 180.0
@export var attack_damage: float = 8.0
## 攻击间隔（秒）
@export var attack_interval: float = 1.0
## 攻击触发距离（像素）
@export var attack_range: float = 40.0
## 防御减免（0.0 ~ 0.9，伤害管道减免系数）
@export_range(0.0, 0.9, 0.01)
var armor: float = 0.0

@export_group("强度")
## 多人人数缩放系数（架构 §4.6；M0 固定 1.0，结构留位）
@export var player_count_scale: float = 1.0

@export_group("掉落")
## 掉落表 ResourceLocation 列表（M0 无掉落，结构留位）
@export var loot_table_locations: Array[String] = []

@export_group("经济")
## 击杀奖励货币（M1：商店经济来源）
@export var kill_reward: int = 10

@export_group("表现")
## 视觉缩放（表现层参考；奔跑者变种区分体型用）
@export var visual_scale: float = 1.0
## 身体主色调（表现层填充色；变种区分用）
@export var body_color: Color = Color(0.65, 0.35, 0.3, 1.0)
