class_name WaveData
extends Resource
## 波次构成模板数据
## 每波 = 种子 PCG 生成「方位 + 数量」构成（同种子可复现，GUT 断言），见 wave_generator.gd。
## 方位：N/E/S/W 基础 4 向 + 斜向（NE/SE/SW/NW）预留。

## 来袭方位（顺时针，从北开始）；斜向为 M0 后扩展预留
enum Direction {
	N = 0,
	NE = 1, # 斜向（预留）
	E = 2,
	SE = 3, # 斜向（预留）
	S = 4,
	SW = 5, # 斜向（预留）
	W = 6,
	NW = 7, # 斜向（预留）
}

## 方位数量下限/上限（含）
const COUNT_RANGE_MIN := 1
const COUNT_RANGE_MAX := 30

@export_group("标识")
@export var id: String = ""

@export_group("构成")
## PCG 种子：同种子 → 同构成（确定性，可复现、可调参）
@export var seed: int = 1
## 可出怪方位（WaveData.Direction 值列表）
@export var directions: Array[int] = []
## 每个方位的数量区间 [min, max]
@export var count_range: Vector2i = Vector2i(4, 6)
## 出怪敌人 ResourceLocation 字符串（如 "bulwark:enemy/runner"）
@export var enemy_location: String = "bulwark:enemy/runner"

@export_group("流程")
## 预警时长（秒）：广播构成 → 刷怪
@export var warn_duration: float = 2.0
## 刷怪节奏（秒）：ACTIVE 阶段每两次出怪的最小间隔（流式刷怪：
## 短间隔随机方位持续出怪，替代一次性全刷的扎堆体验）
@export var spawn_interval: float = 1.0
## 群刷概率（0-1）：每次出怪有该概率刷一小群（burst_size 只同方位），
## 复刻「短间隔随机方位 + 偶发集中怪群」的节奏
@export var burst_chance: float = 0.2
## 群刷数量（概率命中时同方位一次刷出的只数）
@export var burst_size: int = 3

@export_group("强度")
## 玩家人数缩放系数（架构 §4.6；M0 固定 1.0，单人多同时设计留位）
@export var player_count_scale: float = 1.0
