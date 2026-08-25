class_name VfxBank
extends RefCounted
## Kenney「Top-down Tanks Remastered」素材唯一入口（P0-4 / P1-15）
## - 运行时只允许经本类取纹理/动画；任何场景/脚本不得散落指向临时素材目录的 preload
## - 素材已复制进 assets/（Default size，非 Retina）；导入设置 Nearest / 无 mipmap / lossless
## - 双层预算：高频普通命中用 FxBurst 8px 几何（Tier1）；炮塔/弹体/爆炸/枪口焰走本类（Tier2）
## - 一次性懒加载 + 静态缓存：不在热路径重复 load / 解码

## 目标路径前缀
const DIR_TURRET := "res://assets/sprites/turret"
const DIR_BULLETS := "res://assets/vfx/kenney/bullets"
const DIR_MUZZLE := "res://assets/vfx/kenney/muzzle"
const DIR_EXPLOSION := "res://assets/vfx/kenney/explosion"
const DIR_SMOKE := "res://assets/vfx/kenney/explosion_smoke"
const DIR_DEBRIS := "res://assets/vfx/kenney/debris"
const DIR_TANKS := "res://assets/sprites/turret/tank"
const DIR_PROPS := "res://assets/sprites/props"

const EXPLOSION_FRAME_COUNT := 5
const EXPLOSION_DURATION := 0.35
const EXPLOSION_FPS := EXPLOSION_FRAME_COUNT / EXPLOSION_DURATION

## 纹理缓存：semantic_key -> Texture2D（只建一次）
static var _cache: Dictionary = {}
## 爆炸 SpriteFrames（只建一次）
static var _explosion_frames: SpriteFrames

## 统一懒加载入口（命名避开 Resource._get 虚方法签名冲突）
static func _load_texture(key: String, path: String) -> Texture2D:
	if _cache.has(key):
		var cached: Variant = _cache[key]
		return cached as Texture2D
	var resource: Variant = load(path)
	if resource is Texture2D:
		_cache[key] = resource
	else:
		push_error("VfxBank: 纹理解析失败 %s" % path)
		_cache[key] = null
	return _cache[key] as Texture2D

static func clear_cache() -> void:
	_cache.clear()
	_explosion_frames = null

# ─── 炮塔（底座 + 炮管拼接；P0-2 / P1-15） ───

static func turret_base(variant: String = "dark") -> Texture2D:
	var file := "tankBody_%s.png" % variant
	return _load_texture("turret_base:%s" % variant, "%s/%s" % [DIR_TURRET, file])

## index 1..3 = tankDark_barrelN；4..7 = specialBarrelN（可扩展武器炮管）
static func turret_barrel(index: int) -> Texture2D:
	var key := "turret_barrel:%d" % index
	var file: String
	if index >= 1 and index <= 3:
		file = "tankDark_barrel%d.png" % index
	else:
		file = "specialBarrel%d.png" % (index - 3)
	return _load_texture(key, "%s/%s" % [DIR_TURRET, file])

## 完整坦克（Boss/首领与敌人轮廓差异化预留）
static func tank_body_full(variant: String) -> Texture2D:
	var file := "tank_%s.png" % variant
	return _load_texture("tank_full:%s" % variant, "%s/%s" % [DIR_TANKS, file])

## 坦克底盘/装甲件（敌人轮廓差异：装甲兽/飞行体/精英/首领用）
static func tank_part(kind: String) -> Texture2D:
	var file := "%s.png" % kind
	return _load_texture("tank_part:%s" % kind, "%s/%s" % [DIR_TANKS, file])

# ─── 弹体（玩家/敌方；P0-2 / P1-15） ───

static func bullet(kind: String) -> Texture2D:
	var file := "bullet%s1.png" % kind.capitalize().replace(" ", "")
	return _load_texture("bullet:%s" % kind.to_lower(), "%s/%s" % [DIR_BULLETS, file])

# ─── 枪口焰（短缩放闪现；0.06s） ───

static func muzzle(kind: String = "large") -> Texture2D:
	var file := "shot%s.png" % kind.capitalize().replace(" ", "")
	return _load_texture("muzzle:%s" % kind.to_lower(), "%s/%s" % [DIR_MUZZLE, file])

# ─── 爆炸 5 帧动画（0.35s；死亡/自爆/AoE/Boss） ───

static func explosion_textures() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for i in range(1, EXPLOSION_FRAME_COUNT + 1):
		var tex := _load_texture("explosion:%d" % i,
			"%s/explosion%d.png" % [DIR_EXPLOSION, i])
		if tex != null:
			frames.append(tex)
	return frames

static func explosion_sprite_frames() -> SpriteFrames:
	if _explosion_frames != null:
		return _explosion_frames
	var sf := SpriteFrames.new()
	if not sf.has_animation("default"):
		sf.add_animation("default")
	# 显式单次播放：Godot SpriteFrames 新增动画可能默认 loop，必须关掉（否则播完不消失）
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", EXPLOSION_FPS)
	for i in range(1, EXPLOSION_FRAME_COUNT + 1):
		var tex := _load_texture("explosion:%d" % i,
			"%s/explosion%d.png" % [DIR_EXPLOSION, i])
		if tex != null:
			sf.add_frame("default", tex)
	_explosion_frames = sf
	return sf

# ─── 路障碎片 / 章节装饰 ───

## 低耐久告警爆烟（explosionSmoke1，低频单帧；基地低耐久用）
static func smoke() -> Texture2D:
	return _load_texture("smoke:warning", "%s/explosionSmoke1.png" % DIR_SMOKE)

static func debris(kind: String) -> Texture2D:
	var file := "%s.png" % kind
	return _load_texture("debris:%s" % kind, "%s/%s" % [DIR_DEBRIS, file])

static func prop(kind: String) -> Texture2D:
	var file := "%s.png" % kind
	return _load_texture("prop:%s" % kind, "%s/%s" % [DIR_PROPS, file])

# ─── 测试/审计辅助 ───

## 返回本类管理的全部资源路径（供 grep/审计确认不引用外部临时素材）
static func managed_paths() -> Array[String]:
	return (_turret_paths() + _bullet_paths() + _muzzle_paths()
		+ _explosion_paths() + _debris_paths() + _prop_paths()
		+ _smoke_paths() + _tank_paths())

static func _turret_paths() -> Array[String]:
	return [
		"%s/tankBody_dark.png" % DIR_TURRET,
		"%s/tankBody_green.png" % DIR_TURRET,
		"%s/tankBody_sand.png" % DIR_TURRET,
		"%s/tankBody_red.png" % DIR_TURRET,
		"%s/tankDark_barrel1.png" % DIR_TURRET,
		"%s/tankDark_barrel2.png" % DIR_TURRET,
		"%s/tankDark_barrel3.png" % DIR_TURRET,
		"%s/specialBarrel1.png" % DIR_TURRET,
	]

static func _bullet_paths() -> Array[String]:
	var paths: Array[String] = []
	for kind: String in ["green", "red", "dark", "blue", "sand"]:
		paths.append("%s/bullet%s1.png" % [DIR_BULLETS, kind.capitalize()])
	return paths

static func _muzzle_paths() -> Array[String]:
	return [
		"%s/shotLarge.png" % DIR_MUZZLE,
		"%s/shotOrange.png" % DIR_MUZZLE,
		"%s/shotRed.png" % DIR_MUZZLE,
		"%s/shotThin.png" % DIR_MUZZLE,
	]

static func _explosion_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in range(1, EXPLOSION_FRAME_COUNT + 1):
		paths.append("%s/explosion%d.png" % [DIR_EXPLOSION, i])
	return paths

static func _debris_paths() -> Array[String]:
	return [
		"%s/sandbagBrown.png" % DIR_DEBRIS,
		"%s/barricadeWood.png" % DIR_DEBRIS,
		"%s/crateWood.png" % DIR_DEBRIS,
	]

static func _prop_paths() -> Array[String]:
	return [
		"%s/crateMetal.png" % DIR_PROPS,
		"%s/sandbagBeige.png" % DIR_PROPS,
		"%s/oilSpill_small.png" % DIR_PROPS,
		"%s/oilSpill_large.png" % DIR_PROPS,
	]

static func _smoke_paths() -> Array[String]:
	return ["%s/explosionSmoke1.png" % DIR_SMOKE]

static func _tank_paths() -> Array[String]:
	return [
		"%s/tank_dark.png" % DIR_TANKS,
		"%s/tank_huge.png" % DIR_TANKS,
		"%s/tank_bigRed.png" % DIR_TANKS,
		"%s/tank_blue.png" % DIR_TANKS,
		"%s/tank_green.png" % DIR_TANKS,
		"%s/tankBody_darkLarge.png" % DIR_TANKS,
		"%s/tankBody_blue.png" % DIR_TANKS,
	]
