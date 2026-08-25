extends Node
## M4 2D 光照架构预留（议题 3，D-M4-11）：
## - CanvasModulate 环境色 + 环境状态接口（DAY/NIGHT）；昼夜循环留 M5，M4 只提供地基
## - 动态闪光池：枪口焰/爆炸请求短期 PointLight2D（同屏上限 FLASH_LIGHT_MAX）
## - 性能纪律：闪光到期立即停用回池；M5 昼夜/动态光衰减在此扩展

const FLASH_LIGHT_MAX := 8

const ENV_DAY := 0
const ENV_NIGHT := 1
const DAY_LIGHT := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_LIGHT := Color(0.42, 0.5, 0.78, 1.0)

var environment_state: int = ENV_DAY
var _canvas_modulate: CanvasModulate
var _lights_root: Node2D
var _flash_pool: Array[PointLight2D] = []
var _flash_tweens: Dictionary = {}  # PointLight2D -> Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_ensure_canvas_modulate")

func _ensure_canvas_modulate() -> void:
	if not is_inside_tree():
		return
	_lights_root = Node2D.new()
	_lights_root.name = "WorldLights"
	get_tree().root.add_child(_lights_root)
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "CanvasModulate"
	_canvas_modulate.color = DAY_LIGHT
	get_tree().root.add_child(_canvas_modulate)
	# 场景切换时 CanvasModulate/WorldLights 常驻 root，GameSession 释放不带走光照层

## M5 昼夜接口：切环境色（duration>0 平滑过渡）
func set_environment(state: int, duration: float = 0.0) -> void:
	environment_state = state
	if _canvas_modulate == null:
		return
	var target := DAY_LIGHT if state == ENV_DAY else NIGHT_LIGHT
	if duration <= 0.0:
		_canvas_modulate.color = target
		return
	var tw := create_tween()
	tw.tween_property(_canvas_modulate, "color", target, duration)

## 短期动态光：世界坐标点闪光（枪口/爆炸）；超上限时复用最旧的灯
func request_flash(world_pos: Vector2, color: Color = Color(1.0, 0.82, 0.45),
		energy: float = 1.2, duration: float = 0.08) -> void:
	if _lights_root == null:
		return
	var light := _acquire_light()
	if light == null:
		return
	_clear_flash_tween(light)
	light.global_position = world_pos
	light.color = color
	light.energy = energy
	light.enabled = true
	var tw := create_tween()
	tw.tween_property(light, "energy", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		light.enabled = false
		_flash_tweens.erase(light))
	_flash_tweens[light] = tw

func _acquire_light() -> PointLight2D:
	if _flash_pool.size() < FLASH_LIGHT_MAX:
		var light := PointLight2D.new()
		light.texture = FxBurst.get_glow_texture()
		light.shadow_enabled = false
		light.enabled = false
		light.energy = 0.0
		light.texture_scale = 0.15
		_lights_root.add_child(light)
		_flash_pool.append(light)
	# 优先取空闲灯
	for pooled in _flash_pool:
		if not pooled.enabled:
			return pooled
	# 全忙：取池首（最旧），打断复用
	return _flash_pool[0]

func _clear_flash_tween(light: PointLight2D) -> void:
	var tw: Tween = _flash_tweens.get(light)
	if tw != null and tw.is_valid():
		tw.kill()
	_flash_tweens.erase(light)
