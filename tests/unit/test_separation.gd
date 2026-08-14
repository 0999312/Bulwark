extends GutTest
## 前后端分离验证（架构 §1.3 硬性约束 + §7 测试策略）
## 1) 静态检查：scripts/core/ 无 get_node / 渲染引用（Sprite/Material/动画/UI）
## 2) 后端模块在无场景环境下实例化通过（headless 可测）

const CORE_DIR := "res://scripts/core"
const FORBIDDEN_PATTERNS := [
	"get_node(",
	"Sprite2D",
	"Sprite3D",
	"Material",
	"Shader",
	"CanvasLayer",
	"CanvasItem",
	"AnimationPlayer",
	"preload(\"res://scenes",
	"load(\"res://scenes",
	"queue_free",
]

func test_core_scripts_have_no_scene_rendering_references() -> void:
	var files := _collect_gd_files(CORE_DIR)
	assert_gt(files.size(), 0, "scripts/core/ 应有脚本待检查")
	var violations: Array[String] = []
	for path: String in files:
		var content := FileAccess.get_file_as_string(path)
		for pattern: String in FORBIDDEN_PATTERNS:
			if content.contains(pattern):
				violations.append("%s -> %s" % [path, pattern])
	assert_eq(violations, [], "scripts/core/ 出现场景/渲染引用：\n%s" % "\n".join(violations))

func test_scene_scripts_never_mutate_backend_numerics() -> void:
	# 前端脚本禁止直接写入后端数值（只发意图）；抽查 scenes/ 不得出现
	# 对核心数值字段的直接赋值（damage/durability/health 的写操作应走后端 API）。
	var files := _collect_gd_files("res://scenes")
	var violations: Array[String] = []
	for path: String in files:
		var content := FileAccess.get_file_as_string(path)
		if content.contains(".durability =") or content.contains(".health =") \
				or content.contains(".mag ="):
			violations.append(path)
	assert_eq(violations, [], "前端直接写后端数值：\n%s" % "\n".join(violations))

func test_backend_instantiable_without_scene_tree() -> void:
	# 在 GUT（headless、无游戏场景）环境下直接实例化全部后端模块并冒烟驱动
	var ammo := AmmoSystem.new()
	ammo.set_count(WeaponTypeData.AmmoType.BULLET, 90)
	var slots := WeaponSlots.new(ammo)
	var rifle_type := WeaponTypeData.new()
	rifle_type.id = "weapon/type/assault_rifle"
	rifle_type.slot = WeaponTypeData.SlotType.MAIN
	var rifle := WeaponModelData.new()
	rifle.id = "weapon/model/storm7"
	rifle.mag_size = 30
	rifle.fire_rate = 8.0
	slots.assign_slot(WeaponSlots.SLOT_MAIN, rifle_type, rifle)

	var attributes := AttributeSet.new()
	attributes.set_base(AttributeSet.MAX_HEALTH, 100.0)
	attributes.set_base(AttributeSet.MOVE_SPEED, 260.0)
	var player := PlayerController.new(attributes, slots)
	var base := BaseCore.new(300.0)
	var director := WaveDirector.new()
	var runner := RunnerController.new(EnemyData.new())

	assert_not_null(player)
	assert_not_null(base)
	assert_not_null(director)
	assert_not_null(runner)

	# 冒烟：全部 tick / 结算不依赖场景环境
	player.set_shoot_intent(true)
	player.tick(0.016)
	director.tick(0.016)
	runner.tick(0.016, 500.0)
	var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, 10.0)
	player.take_damage(ctx)
	base.take_damage(10.0)
	assert_almost_eq(base.durability, 290.0, 0.001)

func _collect_gd_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			result.append_array(_collect_gd_files(full))
		elif name.ends_with(".gd"):
			result.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return result
