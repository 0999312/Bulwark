class_name PowerUpPickup
extends Area2D
## 波中道具拾取（P1-6，纯表现/host 权威）
## - host/OFFLINE 侧由 GameSession 在击杀位置生成；玩家接触 → PowerUpPickupEvent（携带 player_id）
## - 9 秒未捡自动消失；表现：Kenney 道具贴图 + 浮动/闪烁

const LIFETIME := 9.0
const FLOAT_AMPLITUDE := 3.0

var power_data: PowerUpData
var player_id: int = -1

var _t := 0.0
var _taken := false
var _sprite: Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(0.8, 0.8)
	add_child(_sprite)
	var texture: Texture2D = null
	if power_data != null:
		if power_data.vfx_key in ["crateMetal", "sandbagBeige", "oilSpill_small", "oilSpill_large"]:
			texture = VfxBank.prop(power_data.vfx_key)
		elif power_data.vfx_key in ["sandbagBrown", "barricadeWood", "crateWood"]:
			texture = VfxBank.debris(power_data.vfx_key)
		elif power_data.vfx_key.begins_with("bullet"):
			texture = VfxBank.bullet(power_data.vfx_key.trim_prefix("bullet").trim_suffix("1").to_lower())
		elif power_data.vfx_key.begins_with("shot"):
			texture = VfxBank.muzzle(power_data.vfx_key.trim_prefix("shot").to_lower())
	if texture == null:
		texture = FxBurst.get_pixel_texture()
		_sprite.modulate = power_data.icon_color if power_data != null else Color.WHITE
	_sprite.texture = texture
	if power_data == null:
		return
	if power_data.effect == PowerUpData.EffectKind.SCORE_MULT:
		_sprite.modulate = power_data.icon_color

func _process(delta: float) -> void:
	_t += delta
	if _taken:
		return
	if _t >= LIFETIME:
		queue_free()
		return
	# 轻微浮动 + 尾段闪烁提醒
	if _sprite != null:
		_sprite.position.y = -FLOAT_AMPLITUDE * sin(_t * 4.0)
		if _t > LIFETIME - 2.0:
			_sprite.modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 10.0))

func _on_body_entered(body: Node2D) -> void:
	if _taken or power_data == null:
		return
	var pid_v: Variant = body.get("player_id")
	if pid_v == null:
		return
	_taken = true
	EventBus.publish(PowerUpPickupEvent.new(
		power_data.id, int(pid_v), global_position, power_data.duration))
	queue_free()
