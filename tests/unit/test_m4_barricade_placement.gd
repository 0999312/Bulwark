extends GutTest
## M4 议题 5：路障放置外推与玩家碰撞（D-M4-16/17）
## - 放置几何纯函数回归：方位角不变、半径外推、零向量兜底
## - 间距校验纯函数：防重叠堆叠
## - 场景掩码回归：玩家必须阻挡 world(8) 层（mask 含 8）；敌人仍阻挡 world

func test_placement_moves_forward_along_base_line() -> void:
	# 玩家 (0,180)、基地 (0,0) → 外推 48px → (0,228)
	var result := BarricadeController.compute_forward_placement(
		Vector2(0.0, 180.0), Vector2.ZERO, 48.0)
	assert_almost_eq(result["pos"].x, 0.0, 0.001, "方位角不变：x 不偏移")
	assert_almost_eq(result["pos"].y, 228.0, 0.001, "半径 + 48 外推")
	assert_almost_eq(result["radius"], 180.0, 0.001, "返回放置者原半径")

func test_placement_preserves_angle() -> void:
	# 斜向放置：外推后仍在基地→玩家连线上（叉积≈0）
	var result := BarricadeController.compute_forward_placement(
		Vector2(120.0, 160.0), Vector2.ZERO, 48.0)
	var pos: Vector2 = result["pos"]
	var cross := pos.cross(Vector2(120.0, 160.0))
	assert_almost_eq(cross, 0.0, 0.01, "外推点与玩家方位共线")
	assert_gt(pos.length(), 200.0, "半径增大（200 = sqrt(120^2+160^2)）")

func test_placement_zero_radius_falls_back() -> void:
	# 玩家与基地同点：零向量兜底，不产生 NaN
	var result := BarricadeController.compute_forward_placement(
		Vector2(50.0, 50.0), Vector2(50.0, 50.0), 48.0)
	assert_eq(result["pos"], Vector2(50.0, 50.0), "退化输入退回玩家站位")

func test_negative_offset_rejected() -> void:
	var result := BarricadeController.compute_forward_placement(
		Vector2(0.0, 180.0), Vector2.ZERO, -10.0)
	assert_eq(result["pos"], Vector2(0.0, 180.0), "非法偏移不放置")

func test_min_spacing_blocks_overlap() -> void:
	var existing: Array = [Vector2(0.0, 228.0)]
	assert_false(BarricadeController.has_min_spacing(Vector2(20.0, 228.0), existing, 64.0),
		"间距不足拒绝")
	assert_true(BarricadeController.has_min_spacing(Vector2(80.0, 228.0), existing, 64.0),
		"间距达标放行")

func test_player_scene_mask_includes_world_layer() -> void:
	var player: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	assert_true(player.collision_mask & 8 != 0, "玩家 mask 含 world(8)：不可跨越路障（D-M4-16）")
	assert_true(player.collision_mask & 2 != 0, "玩家仍与敌人碰撞")
	assert_true(player.collision_mask & 4 != 0, "玩家保持原有基地阻挡（6|8=14）")

func test_enemy_scene_mask_keeps_blocking_barricades() -> void:
	var enemy: CharacterBody2D = (load("res://scenes/enemy/enemy.tscn") as PackedScene).instantiate()
	add_child_autofree(enemy)
	assert_true(enemy.collision_mask & 8 != 0, "敌人仍被路障（world 层）阻挡")

## 最小碰撞验证（D-M4-18）：出生位玩家向路障直冲，move_and_slide 必须在弧前停下
## （弧内半径 217、玩家碰撞半径 16 → 圆心理论停点 ≈ 201；给 11px 余量断言 212）
func test_player_cannot_cross_barricade_collision() -> void:
	ContentBootstrap.register_all()
	var facility: DefenseFacilityData = ContentBootstrap.get_entry(
		Bulwark.REG_FACILITY, Bulwark.loc(Bulwark.FACILITY_BARRICADE).to_string())
	assert_not_null(facility, "路障设施数据已注册")
	if facility == null:
		return
	var root := Node2D.new()
	add_child_autofree(root)
	var player: PlayerView = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	var ammo := AmmoSystem.new()
	var slots := WeaponSlots.new(ammo, RunState.new())
	var attrs := AttributeSet.new()
	attrs.set_base(AttributeSet.MAX_HEALTH, 100.0)
	attrs.set_base(AttributeSet.MOVE_SPEED, 260.0)
	attrs.set_base(AttributeSet.RELOAD_SPEED, 1.0)
	player.setup(PlayerController.new(attrs, slots), {})
	player.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SIMULATED)
	player.global_position = Vector2(0.0, 180.0)
	var barricade: BarricadeView = (load("res://scenes/base/barricade.tscn") as PackedScene).instantiate()
	root.add_child(barricade)
	barricade.setup(BarricadeController.new(facility, 1))
	barricade.global_position = Vector2(0.0, 228.0)
	barricade.align_to_arc(Vector2.ZERO)
	await wait_physics_frames(2)
	player.controller.set_move_intent(Vector2.DOWN)
	for i in 40:
		await wait_physics_frames(1)
	assert_gt(player.global_position.y, 180.0, "玩家已向路障移动")
	assert_lt(player.global_position.y, 212.0, "move_and_slide 被弧形碰撞挡住（不可跨越，D-M4-16）")
	player.controller.set_move_intent(Vector2.ZERO)
