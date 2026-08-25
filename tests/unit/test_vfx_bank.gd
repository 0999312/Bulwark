extends GutTest
## P0-4：VfxBank 单一纹理入口测试
## - 所有受管路径不得引用外部临时素材目录
## - 爆炸 5 帧动画/SpriteFrames 只建一次且帧数正确
## - 炮塔/弹体/枪口焰/碎片/装饰各取用路径可加载（素材复制后断言非空）

func before_each() -> void:
	EventBus.clear_all_listeners()

func test_managed_paths_have_no_temp_reference() -> void:
	for path in VfxBank.managed_paths():
		assert_false(path.contains("temp_assets"), "受管路径不得引用 temp_assets：%s" % path)
		assert_true(path.begins_with("res://assets/"), "素材必须位于 assets/：%s" % path)

func test_explosion_frames_are_five() -> void:
	var frames := VfxBank.explosion_textures()
	assert_eq(frames.size(), VfxBank.EXPLOSION_FRAME_COUNT, "爆炸帧数应为 5")
	for frame in frames:
		assert_not_null(frame, "爆炸帧非空")

func test_explosion_sprite_frames_cached() -> void:
	var sf1 := VfxBank.explosion_sprite_frames()
	var sf2 := VfxBank.explosion_sprite_frames()
	assert_same(sf1, sf2, "SpriteFrames 应只建一次（缓存）")
	assert_gt(sf1.get_frame_count("default"), 0, "默认动画至少一帧")
	assert_almost_eq(sf1.get_animation_speed("default"),
		VfxBank.EXPLOSION_FPS, 0.01, "动画速度对齐 0.35s 总时长")

func test_core_textures_non_null() -> void:
	assert_not_null(VfxBank.turret_base("dark"), "炮塔底座")
	assert_not_null(VfxBank.turret_barrel(1), "炮管 1")
	assert_not_null(VfxBank.bullet("green"), "绿色弹体")
	assert_not_null(VfxBank.bullet("red"), "红色弹体")
	assert_not_null(VfxBank.muzzle("orange"), "橙色枪口焰")
	assert_not_null(VfxBank.debris("sandbagBrown"), "沙袋碎片")
	assert_not_null(VfxBank.smoke(), "告警爆烟")

func test_clear_cache_rebuilds() -> void:
	VfxBank.explosion_sprite_frames()
	VfxBank.clear_cache()
	var sf := VfxBank.explosion_sprite_frames()
	assert_not_null(sf, "清缓存后可重建")
