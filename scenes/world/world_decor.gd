class_name WorldDecor
extends Node2D
## M1 世界层轻量增色（第 2 轮修正：按章节变化装饰内容与色调，拒绝“散点杂物”）
## 策略：少量、低饱和、融入地面的静态道具；每章一组固定素材 + 色调；WaveStartedEvent 驱动换章。
## 仅素材层：不改玩法/网格/新素材包。

const TEX := {
	"sandbag": preload("res://assets/sprites/props/sandbagBeige.png"),
	"crate": preload("res://assets/sprites/props/crateMetal.png"),
	"wood": preload("res://assets/vfx/kenney/debris/crateWood.png"),
	"oil": preload("res://assets/sprites/props/oilSpill_large.png"),
	"tank": preload("res://assets/sprites/turret/tank/tank_huge.png"),
	"tank_dark": preload("res://assets/sprites/turret/tank/tank_dark.png"),
	"smoke": preload("res://assets/vfx/kenney/explosion_smoke/explosionSmoke1.png"),
}

## 每章装饰集：[材质key, 位置, 缩放, alpha]；色调见 CHAPTER_TINT（与章节主题同调）
const CHAPTER_SETS := [
	{ # 第 1 章 · 前哨周边（草地/泥土）
		"tint": Color(1.0, 1.0, 0.9),
		"props": [
			["sandbag", Vector2(-260, -140), 2.0, 0.95],
			["sandbag", Vector2(-320, -40), 2.0, 0.95],
			["sandbag", Vector2(-260, 60), 2.0, 0.95],
			["sandbag", Vector2(260, -140), 2.0, 0.95],
			["sandbag", Vector2(320, -40), 2.0, 0.95],
			["crate", Vector2(-180, 200), 2.4, 0.9],
			["wood", Vector2(180, 200), 2.4, 0.9],
			["crate", Vector2(-820, -620), 2.6, 0.85],
			["wood", Vector2(820, 620), 2.6, 0.85],
			["tank_dark", Vector2(-1150, -900), 2.4, 0.5],
		],
	},
	{ # 第 2 章 · 废弃小镇（灰蓝）
		"tint": Color(0.78, 0.84, 1.0),
		"props": [
			["crate", Vector2(-260, -140), 2.2, 0.85],
			["wood", Vector2(-320, -40), 2.2, 0.85],
			["tank_dark", Vector2(-260, 60), 1.8, 0.55],
			["crate", Vector2(260, -140), 2.2, 0.85],
			["wood", Vector2(320, -40), 2.2, 0.85],
			["tank_dark", Vector2(260, 60), 1.8, 0.55],
			["oil", Vector2(-520, 260), 2.8, 0.6],
			["oil", Vector2(560, -260), 2.8, 0.6],
			["tank", Vector2(-1150, 900), 2.4, 0.5],
			["tank", Vector2(1150, -900), 2.4, 0.5],
		],
	},
	{ # 第 3 章 · 工业污染区（暗橙）
		"tint": Color(1.0, 0.82, 0.62),
		"props": [
			["crate", Vector2(-260, -140), 2.4, 0.9],
			["crate", Vector2(260, -140), 2.4, 0.9],
			["oil", Vector2(-520, 260), 3.0, 0.7],
			["oil", Vector2(560, -260), 3.0, 0.7],
			["oil", Vector2(-640, -250), 3.0, 0.7],
			["smoke", Vector2(-320, -40), 2.2, 0.5],
			["smoke", Vector2(320, -40), 2.2, 0.5],
			["tank", Vector2(-1150, -900), 2.6, 0.55],
			["tank", Vector2(1150, 900), 2.6, 0.55],
			["wood", Vector2(-180, 200), 2.4, 0.85],
		],
	},
	{ # 第 4 章 · 巢穴（深红黑岩）
		"tint": Color(0.9, 0.62, 0.58),
		"props": [
			["tank_dark", Vector2(-260, -140), 2.0, 0.5],
			["tank_dark", Vector2(260, -140), 2.0, 0.5],
			["oil", Vector2(-520, 260), 3.2, 0.75],
			["oil", Vector2(560, -260), 3.2, 0.75],
			["smoke", Vector2(-320, -40), 2.6, 0.6],
			["smoke", Vector2(320, -40), 2.6, 0.6],
			["tank", Vector2(-1150, -900), 3.0, 0.6],
			["tank", Vector2(1150, 900), 3.0, 0.6],
			["tank", Vector2(1150, -900), 3.0, 0.6],
			["tank", Vector2(-1150, 900), 3.0, 0.6],
		],
	},
]

var _chapter := -1
var _sprites: Array[Sprite2D] = []

func _ready() -> void:
	for i in 12:
		var s := Sprite2D.new()
		s.z_index = -8
		add_child(s)
		_sprites.append(s)
	EventBus.subscribe(&"WaveStartedEvent", _on_wave_started)
	_apply(0)

func _exit_tree() -> void:
	EventBus.unsubscribe(&"WaveStartedEvent", _on_wave_started)

func _on_wave_started(event: WaveStartedEvent) -> void:
	if event == null:
		return
	var idx := event.chapter_index
	if idx >= 0 and idx != _chapter:
		_apply(idx)

func _apply(chapter_index: int) -> void:
	_chapter = chapter_index
	var set: Dictionary = CHAPTER_SETS[clampi(chapter_index, 0, CHAPTER_SETS.size() - 1)]
	var tint: Color = set.get("tint", Color.WHITE)
	var props: Array = set.get("props", [])
	for i in _sprites.size():
		var s := _sprites[i]
		if i >= props.size():
			s.visible = false
			continue
		var p: Array = props[i]
		s.texture = TEX.get(String(p[0])) as Texture2D
		s.position = p[1]
		s.scale = Vector2(float(p[2]), float(p[2]))
		var alpha := float(p[3])
		s.modulate = Color(tint.r, tint.g, tint.b, alpha)
		s.visible = s.texture != null
