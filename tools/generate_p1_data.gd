extends SceneTree
## P1 数据生成器（一次性）：生成 4 章模板 + 街机 RunDefinition + 8 个道具资源
## 用法：godot --headless --path . -s tools/generate_p1_data.gd
## 生成后可删除本脚本，或保留作数据再生成工具。

func _initialize() -> void:
	var base := "res://resources"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base + "/chapters"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base + "/runs"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base + "/powerups"))
	_gen_chapters()
	_gen_run()
	_gen_powerups()
	print("generate_p1_data: done")
	quit()

func _group(dirs: Array, count_range: Vector2i, enemy_location: String,
		count_scale: float = 1.0) -> WaveSpawnGroupData:
	var g := WaveSpawnGroupData.new()
	var dirs_typed: Array[int] = []
	for dir in dirs:
		dirs_typed.append(int(dir))
	g.directions = dirs_typed
	g.count_range = count_range
	g.enemy_location = enemy_location
	g.count_scale = count_scale
	return g

func _wave(id: String, seed_value: int, groups: Array, elite := false,
		spawn_interval := 0.8) -> WaveData:
	var w := WaveData.new()
	w.id = id
	w.seed = seed_value
	var groups_typed: Array[WaveSpawnGroupData] = []
	for g in groups:
		groups_typed.append(g as WaveSpawnGroupData)
	w.groups = groups_typed
	w.warn_duration = 3.5
	w.spawn_interval = spawn_interval
	w.burst_chance = 0.18
	w.burst_size = 3
	w.player_count_scale = 1.0
	w.is_elite_wave = elite
	return w

func _add_behemoth_boss(seed_value: int, extra_groups: Array) -> WaveData:
	var groups: Array = [_group([0], Vector2i(1, 1), "bulwark:enemy/elite_behemoth")]
	groups.append_array(extra_groups)
	return _wave("boss_%d" % seed_value, seed_value, groups, true, 0.9)

func _gen_chapters() -> void:
	# 第 1 章 · 前哨周边（草地）
	var c1 := ChapterDefinition.new()
	c1.id = "chapter/1"
	c1.display_name = "第 1 章 · 前哨周边"
	c1.theme_rgb = Color(0.36, 0.62, 0.4, 1.0)
	c1.chapter_scale = 1.0
	c1.round_reward_pool = ["power/ammo", "power/material", "power/heal",
		"power/fire_rate", "power/pellets"]
	c1.waves = [
		_wave("chapter/1/wave/1", 1101, [_group([0, 2], Vector2i(4, 6), "bulwark:enemy/runner")]),
		_wave("chapter/1/wave/2", 1102, [
			_group([0, 2], Vector2i(3, 5), "bulwark:enemy/runner"),
			_group([4, 6], Vector2i(3, 5), "bulwark:enemy/runner_fast")]),
		_wave("chapter/1/wave/3", 1103, [
			_group([0, 2], Vector2i(2, 4), "bulwark:enemy/self_destruct"),
			_group([4, 6], Vector2i(2, 4), "bulwark:enemy/spitter")]),
	]
	c1.boss_wave = _add_behemoth_boss(1104, [
		_group([0], Vector2i(3, 4), "bulwark:enemy/runner_fast", 1.2)])
	ResourceSaver.save(c1, "res://resources/chapters/chapter_1.tres")

	# 第 2 章 · 废弃小镇（灰蓝）
	var c2 := ChapterDefinition.new()
	c2.id = "chapter/2"
	c2.display_name = "第 2 章 · 废弃小镇"
	c2.theme_rgb = Color(0.42, 0.48, 0.62, 1.0)
	c2.chapter_scale = 1.25
	c2.round_reward_pool = ["power/ammo", "power/fire_rate", "power/pellets", "power/shield"]
	c2.waves = [
		_wave("chapter/2/wave/1", 1201, [
			_group([0, 2], Vector2i(3, 5), "bulwark:enemy/runner_fast"),
			_group([4, 6], Vector2i(2, 3), "bulwark:enemy/armored")]),
		_wave("chapter/2/wave/2", 1202, [
			_group([0, 2], Vector2i(2, 4), "bulwark:enemy/spitter"),
			_group([4, 6], Vector2i(1, 3), "bulwark:enemy/sniper")]),
		_wave("chapter/2/wave/3", 1203, [
			_group([0, 2], Vector2i(2, 4), "bulwark:enemy/runner"),
			_group([4, 6], Vector2i(2, 4), "bulwark:enemy/runner_tough"),
			_group([2, 6], Vector2i(1, 3), "bulwark:enemy/self_destruct")]),
	]
	c2.boss_wave = _add_behemoth_boss(1204, [
		_group([0], Vector2i(2, 3), "bulwark:enemy/armored", 1.2)])
	ResourceSaver.save(c2, "res://resources/chapters/chapter_2.tres")

	# 第 3 章 · 工业污染区（暗橙）
	var c3 := ChapterDefinition.new()
	c3.id = "chapter/3"
	c3.display_name = "第 3 章 · 工业污染区"
	c3.theme_rgb = Color(0.62, 0.36, 0.2, 1.0)
	c3.chapter_scale = 1.5
	c3.round_reward_pool = ["power/heal", "power/ammo", "power/pellets", "power/score"]
	c3.waves = [
		_wave("chapter/3/wave/1", 1301, [
			_group([0, 2], Vector2i(2, 4), "bulwark:enemy/flying"),
			_group([4, 6], Vector2i(1, 3), "bulwark:enemy/sniper")]),
		_wave("chapter/3/wave/2", 1302, [
			_group([0, 2], Vector2i(2, 4), "bulwark:enemy/self_destruct"),
			_group([4, 6], Vector2i(2, 4), "bulwark:enemy/flying")]),
		_wave("chapter/3/wave/3", 1303, [
			_group([0], Vector2i(2, 4), "bulwark:enemy/runner"),
			_group([2], Vector2i(2, 3), "bulwark:enemy/spitter"),
			_group([4], Vector2i(1, 3), "bulwark:enemy/armored"),
			_group([6], Vector2i(1, 3), "bulwark:enemy/flying")]),
	]
	c3.boss_wave = _add_behemoth_boss(1304, [
		_group([0], Vector2i(2, 4), "bulwark:enemy/flying", 1.2)])
	ResourceSaver.save(c3, "res://resources/chapters/chapter_3.tres")

	# 第 4 章 · 巢穴（深红）
	var c4 := ChapterDefinition.new()
	c4.id = "chapter/4"
	c4.display_name = "第 4 章 · 巢穴"
	c4.theme_rgb = Color(0.52, 0.18, 0.2, 1.0)
	c4.chapter_scale = 1.8
	c4.round_reward_pool = ["power/shield", "power/score", "power/reserve",
		"power/fire_rate", "power/pellets"]
	c4.waves = [
		_wave("chapter/4/wave/1", 1401, [
			_group([0, 2], Vector2i(2, 4), "bulwark:enemy/runner_tough"),
			_group([4, 6], Vector2i(2, 4), "bulwark:enemy/runner_fast")]),
		_wave("chapter/4/wave/2", 1402, [
			_group([0, 2], Vector2i(3, 5), "bulwark:enemy/runner"),
			_group([4, 6], Vector2i(2, 4), "bulwark:enemy/spitter"),
			_group([2, 6], Vector2i(1, 3), "bulwark:enemy/armored")]),
		_wave("chapter/4/wave/3", 1403, [
			_group([0, 4], Vector2i(2, 4), "bulwark:enemy/self_destruct"),
			_group([2, 6], Vector2i(2, 4), "bulwark:enemy/flying"),
			_group([0, 6], Vector2i(1, 2), "bulwark:enemy/sniper")]),
	]
	c4.boss_wave = _add_behemoth_boss(1404, [
		_group([0], Vector2i(2, 3), "bulwark:enemy/runner_tough", 1.3),
		_group([2], Vector2i(1, 2), "bulwark:enemy/spitter", 1.2)])
	ResourceSaver.save(c4, "res://resources/chapters/chapter_4.tres")

func _gen_run() -> void:
	var run := RunDefinition.new()
	run.id = "run/arcade"
	run.display_name = "街机章节模式"
	run.highscore_key = "arcade"
	run.chapters = [
		load("res://resources/chapters/chapter_1.tres"),
		load("res://resources/chapters/chapter_2.tres"),
		load("res://resources/chapters/chapter_3.tres"),
		load("res://resources/chapters/chapter_4.tres"),
	]
	ResourceSaver.save(run, "res://resources/runs/arcade_run.tres")

func _gen_powerups() -> void:
	var defs := [
		["power/ammo", "弹药箱", PowerUpData.EffectKind.AMMO, 30.0, 0.0, 10.0, "crateMetal", Color(1.0, 0.86, 0.4, 1.0)],
		["power/material", "建材包", PowerUpData.EffectKind.MATERIAL, 1.0, 0.0, 8.0, "crateWood", Color(0.72, 0.52, 0.3, 1.0)],
		["power/heal", "医疗包", PowerUpData.EffectKind.HEAL, 25.0, 0.0, 3.0, "", Color(0.95, 0.35, 0.35, 1.0)],
		["power/fire_rate", "急速射击", PowerUpData.EffectKind.FIRE_RATE, 1.5, 6.0, 4.0, "shotOrange", Color(0.35, 0.9, 0.85, 1.0)],
		["power/pellets", "三连弹", PowerUpData.EffectKind.PELLETS, 2.0, 6.0, 4.0, "bulletGreen1", Color(0.4, 0.95, 0.45, 1.0)],
		["power/shield", "护盾", PowerUpData.EffectKind.SHIELD, 0.4, 5.0, 2.0, "", Color(0.4, 0.6, 1.0, 1.0)],
		["power/score", "分数加速", PowerUpData.EffectKind.SCORE_MULT, 2.0, 10.0, 3.0, "", Color(1.0, 0.78, 0.3, 1.0)],
		["power/reserve", "备用命", PowerUpData.EffectKind.RESERVE, 1.0, 0.0, 0.5, "", Color(0.75, 0.35, 0.9, 1.0)],
	]
	for d in defs:
		var p := PowerUpData.new()
		p.id = d[0]
		p.display_name = d[1]
		p.effect = d[2]
		p.amount = d[3]
		p.duration = d[4]
		p.weight = d[5]
		p.vfx_key = d[6]
		p.icon_color = d[7]
		var file := "res://resources/powerups/power_up_%s.tres" % String(d[0]).split("/")[1].replace("_", "_")
		ResourceSaver.save(p, file)
