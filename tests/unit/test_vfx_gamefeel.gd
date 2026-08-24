extends GutTest
## 游戏感 VFX 回归（particles-vfx / godot-particles / tween-animation 组合落地）：
## ① FxBurst 像素纹理池可用（弃用高清软粒子贴图）
## ② 像素冲击环与爆点可创建、可自动释放
## ③ 敌人弹体低分辨率视觉：发射脉冲 + 抵达反馈后自毁，无外部高清贴图依赖

func test_fx_burst_pixel_pool_and_ring() -> void:
	await wait_process_frames(3)
	assert_not_null(FxBurst.get_pixel_texture(), "运行时生成 8px 像素纹理")
	assert_false(FxBurst._spark_pool.is_empty(), "粒子池已就绪")
	FxBurst.spawn_hit_spark(Vector2(10, 10), Color(1.0, 0.8, 0.3))
	FxBurst.spawn_flare(Vector2(20, 10), Color(1.0, 0.4, 0.2))
	FxBurst.spawn_impact_ring(Vector2(30, 10), Color(0.6, 1.0, 0.4), 16.0, 0.1)
	await wait_process_frames(12)
	pass_test("像素爆点/冲击环创建无脚本错误")

func test_enemy_projectile_pixel_style_flight_and_arrival() -> void:
	var proj: EnemyProjectile = (load("res://scenes/vfx/enemy_projectile.tscn") as PackedScene) \
		.instantiate() as EnemyProjectile
	add_child_autofree(proj)
	assert_eq(EnemyProjectile.color_for_kind("spit"), Color(0.62, 0.95, 0.38))
	proj.setup(Vector2.ZERO, Vector2(240, 0), 600.0, "spit")
	assert_gt(proj.get_child_count(), 0, "弹体创建像素视觉层")
	await wait_process_frames(60)
	assert_false(is_instance_valid(proj), "抵达后播放反馈并自毁")

func test_enemy_projectile_moves_to_target_not_always_right() -> void:
	var proj: EnemyProjectile = (load("res://scenes/vfx/enemy_projectile.tscn") as PackedScene) \
		.instantiate() as EnemyProjectile
	add_child_autofree(proj)
	proj.setup(Vector2(0, 0), Vector2(0, 300), 600.0, "spit")
	await wait_seconds(0.25)
	assert_gt(proj.global_position.y, 30.0, "弹体应向目标方向（+Y）移动")
	assert_almost_eq(proj.global_position.x, 0.0, 0.5, "向正 Y 飞行时 X 不应漂移")
	assert_gt(proj.global_position.y, proj.global_position.x, "位移主方向应为目标方向")
