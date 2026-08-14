class_name DirectionUtils
extends RefCounted
## 方位工具（WaveData.Direction ↔ 世界向量/罗盘符号）
## M0：N/E/S/W 基础 4 向刷怪点 + 斜向预留（NE/SE/SW/NW 已定义，刷怪点 M1+ 补充）

const SQRT_HALF := 0.7071067811865476

## 方位 → 单位向量（世界坐标，Y 向下：N = -Y）
static func to_vector(direction: int) -> Vector2:
	match direction:
		WaveData.Direction.N:
			return Vector2(0.0, -1.0)
		WaveData.Direction.NE:
			return Vector2(SQRT_HALF, -SQRT_HALF)
		WaveData.Direction.E:
			return Vector2(1.0, 0.0)
		WaveData.Direction.SE:
			return Vector2(SQRT_HALF, SQRT_HALF)
		WaveData.Direction.S:
			return Vector2(0.0, 1.0)
		WaveData.Direction.SW:
			return Vector2(-SQRT_HALF, SQRT_HALF)
		WaveData.Direction.W:
			return Vector2(-1.0, 0.0)
		WaveData.Direction.NW:
			return Vector2(-SQRT_HALF, -SQRT_HALF)
	return Vector2.ZERO

## 方位 → 罗盘符号（HUD 预告）
static func arrow(direction: int) -> String:
	match direction:
		WaveData.Direction.N:
			return "↑"
		WaveData.Direction.NE:
			return "↗"
		WaveData.Direction.E:
			return "→"
		WaveData.Direction.SE:
			return "↘"
		WaveData.Direction.S:
			return "↓"
		WaveData.Direction.SW:
			return "↙"
		WaveData.Direction.W:
			return "←"
		WaveData.Direction.NW:
			return "↖"
	return "?"
