class_name WorldDecor
extends Node2D
## 世界层装饰（第 2/3 次修正：改用"地面印痕 + 暗色残骸剪影"，只做低对比地面装饰，
## 不再放置亮色道具（沙袋/木箱曾被反馈为"悬空杂物"）；按章节更换素材组与色调。
## 仅素材层：不改玩法/网格/新素材包。

const TEX := {
	"oil": preload("res://assets/sprites/props/oilSpill_large.png"),
	"tank": preload("res://assets/sprites/turret/tank/tank_huge.png"),
	"tank_dark": preload("res://assets/sprites/turret/tank/tank_dark.png"),
	"smoke": preload("res://assets/vfx/kenney/explosion_smoke/explosionSmoke1.png"),
}

## 每章装饰集：[材质key, 位置, 缩放, alpha]；色调统一压暗（融入地面，避免"对象感"）
const CHAPTER_SETS := [
	{ # 第 1 章 · 前哨周边：油渍 + 轻烟 + 边缘残骸
		"tint": Color(0.42, 0.44, 0.4),
		"props": [
			["oil", Vector2(-520, 260), 2.8, 0.4],
			["oil", Vector2(560, -260), 2.8, 0.4],
			["smoke", Vector2(-320, -40), 2.2, 0.3],
			["smoke", Vector2(320, -40), 2.2, 0.3],
			["tank_dark", Vector2(-1150, -900), 2.4, 0.35],
			["tank_dark", Vector2(1150, 900), 2.4, 0.35],
		],
	},
	{ # 第 2 章 · 废弃小镇：灰蓝残骸 + 油渍
		"tint": Color(0.4, 0.46, 0.56),
		"props": [
			["oil", Vector2(-520, 260), 3.0, 0.45],
			["oil", Vector2(560, -260), 3.0, 0.45],
			["tank_dark", Vector2(-260, -140), 1.8, 0.35],
			["tank_dark", Vector2(260, -140), 1.8, 0.35],
			["tank", Vector2(-1150, -900), 2.4, 0.4],
			["tank", Vector2(1150, 900), 2.4, 0.4],
		],
	},
	{ # 第 3 章 · 工业污染区：暗橙油渍 + 黑烟
		"tint": Color(0.5, 0.4, 0.32),
		"props": [
			["oil", Vector2(-520, 260), 3.2, 0.5],
			["oil", Vector2(560, -260), 3.2, 0.5],
			["oil", Vector2(-640, -250), 3.0, 0.5],
			["smoke", Vector2(-320, -40), 2.6, 0.4],
			["smoke", Vector2(320, -40), 2.6, 0.4],
			["tank", Vector2(-1150, -900), 2.6, 0.4],
			["tank", Vector2(1150, 900), 2.6, 0.4],
		],
	},
	{ # 第 4 章 · 巢穴：深红黑岩剪影 + 暗油
		"tint": Color(0.46, 0.32, 0.3),
		"props": [
			["oil", Vector2(-520, 260), 3.4, 0.55],
			["oil", Vector2(560, -260), 3.4, 0.55],
			["tank_dark", Vector2(-260, -140), 2.0, 0.4],
			["tank_dark", Vector2(260, -140), 2.0, 0.4],
			["smoke", Vector2(-320, -40), 2.8, 0.45],
			["smoke", Vector2(320, -40), 2.8, 0.45],
			["tank", Vector2(-1150, -900), 3.0, 0.45],
			["tank", Vector2(1150, 900), 3.0, 0.45],
			["tank", Vector2(1150, -900), 3.0, 0.45],
			["tank", Vector2(-1150, 900), 3.0, 0.45],
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
