class_name AttributeModifierData
extends Resource
## 属性修正条目（通用：配件修正 / 商店强化共用）
## 通道与 AttributeSet 一致：final = (base + additive) × multiplicative
## 目标属性键：
##   - 玩家：AttributeSet.MAX_HEALTH / MOVE_SPEED / RELOAD_SPEED
##   - 武器：WeaponStats 的数值键（damage / fire_rate / mag_size / reload_time / spread / crit_chance / pellets）

@export_group("标识")
@export var id: String = ""
@export var display_name: String = ""

@export_group("修正")
## 目标属性键（StringName，见类注释的键清单）
@export var attribute: StringName = &""
## 加法通道数值（叠加到 base）
@export var amount: float = 0.0
## 乘法通道系数（累乘；1.0 = 不生效）
@export_range(0.0, 5.0, 0.01)
var multiplier: float = 1.0

## 生效判定：乘法通道默认恒生效（1.0 不改变结果）
func is_effective() -> bool:
	return amount != 0.0 or multiplier != 1.0
