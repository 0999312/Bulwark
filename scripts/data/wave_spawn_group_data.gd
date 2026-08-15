class_name WaveSpawnGroupData
extends Resource
## 波次刷怪组（M1：波次构成支持多敌人组合）
## 一组 = 若干方位 + 数量区间 + 敌人；WaveData.groups 允许多组混合（奔跑者 + 变种）
## 兼容：WaveData.groups 为空时回退到旧单组字段（directions/count_range/enemy_location，M0 数据不迁移）

@export_group("构成")
## 可出怪方位（WaveData.Direction 值列表）
@export var directions: Array[int] = []
## 每方位数量区间 [min, max]
@export var count_range: Vector2i = Vector2i(4, 6)
## 出怪敌人 ResourceLocation 字符串（如 "bulwark:enemy/runner"）
@export var enemy_location: String = "bulwark:enemy/runner"

@export_group("强度")
## 本组数量缩放系数（默认 1.0；多人人数系数在 WaveData 层统一）
@export var count_scale: float = 1.0
