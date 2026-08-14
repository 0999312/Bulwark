class_name GameSession
extends Node2D
## 本局组合根（前端装配层）：创建后端实例、接线、驱动帧循环
## - 后端（scripts/core/）纯逻辑：PlayerController / WeaponSlots / AmmoSystem / BaseCore / WaveDirector
## - 前端 → 后端 = 意图命令；后端 → 前端 = EventBus 事件（表现层只读状态）
## - host 权威结构留位（M2 多人验证：本会话即"单机 host"）

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")

const BASE_DURABILITY := 400.0
const BULLET_RESERVE := 90
const SPAWN_ARC_SPACING := 36.0
## 导航区域边界（M0 开放场地）
const NAV_RECT := Rect2(-1100.0, -900.0, 2200.0, 1800.0)

@onready var player_node: CharacterBody2D = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var base_node: Node2D = $Base

var ammo_system: AmmoSystem
var weapon_slots: WeaponSlots
var player_controller: PlayerController
var base_core: BaseCore
var wave_director: WaveDirector

## GUIDE 动作实例（与启用上下文同实例，轮询式读取）
var actions: Dictionary = {}  # StringName -> GUIDEAction

var _run_finished := false

func _ready() -> void:
	# 暂停菜单/结算面板需要在本节点暂停期间仍响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	ContentBootstrap.register_all()
	_build_navigation()
	_setup_backend()
	_setup_input()
	_setup_scene_bindings()
	_setup_hud()
	_subscribe_events()
	_start_run()

func _physics_process(delta: float) -> void:
	if get_tree().paused or _run_finished or player_controller == null:
		return
	player_controller.tick(delta)
	wave_director.tick(delta)

func _process(_delta: float) -> void:
	if _run_finished:
		return
	var pause_action: GUIDEAction = actions.get(&"pause")
	if pause_action != null and pause_action.is_triggered():
		_toggle_pause()

# ─── 装配 ───

func _build_navigation() -> void:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	var poly := NavigationPolygon.new()
	poly.vertices = PackedVector2Array([
		NAV_RECT.position,
		NAV_RECT.position + Vector2(NAV_RECT.size.x, 0.0),
		NAV_RECT.end,
		NAV_RECT.position + Vector2(0.0, NAV_RECT.size.y),
	])
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = poly
	# 手工构建的多边形无需 bake（bake 会按源几何体重新生成，空几何会把多边形清空）；
	# 入树后导航服务器在下一物理帧同步地图
	add_child(region)
	move_child(region, 0)

func _setup_backend() -> void:
	var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	if type_reg == null or model_reg == null:
		push_error("GameSession: 内容注册缺失（weapon_type/weapon_model）")
		return

	ammo_system = AmmoSystem.new()
	ammo_system.set_count(WeaponTypeData.AmmoType.BULLET, BULLET_RESERVE)

	weapon_slots = WeaponSlots.new(ammo_system)
	weapon_slots.assign_slot(
		WeaponSlots.SLOT_MAIN,
		type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE)),
		model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7)))
	weapon_slots.assign_slot(
		WeaponSlots.SLOT_PISTOL,
		type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_PISTOL)),
		model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_SENTINEL1)))
	weapon_slots.emit_initial_state()

	var attributes := AttributeSet.new()
	attributes.set_base(AttributeSet.MAX_HEALTH, 100.0)
	attributes.set_base(AttributeSet.MOVE_SPEED, 260.0)
	attributes.set_base(AttributeSet.RELOAD_SPEED, 1.0)

	player_controller = PlayerController.new(attributes, weapon_slots)
	base_core = BaseCore.new(BASE_DURABILITY)
	wave_director = WaveDirector.new()

func _setup_input() -> void:
	var combat_context: GUIDEMappingContext = load("res://input/contexts/combat_context.tres")
	if combat_context == null:
		push_error("GameSession: combat_context.tres 缺失（先运行 tools/generate_guide_context.gd）")
		return
	GUIDE.enable_mapping_context(combat_context, false, 0)
	for mapping: GUIDEActionMapping in combat_context.mappings:
		actions[mapping.action.name] = mapping.action

	var equipment_context: GUIDEMappingContext = load("res://input/contexts/equipment_context.tres")
	if equipment_context != null:
		GUIDE.enable_mapping_context(equipment_context, false, 1)

func _setup_scene_bindings() -> void:
	var view := player_node as PlayerView
	view.setup(player_controller, actions)
	(base_node as BaseView).setup(base_core)

## HUD 挂载（UIManager 覆盖层；HUD 只读后端事件，不直接读写数值）
## UIManager 为跨场景 autoload：重开本局前先移除旧覆盖层，避免 id 冲突残留
func _setup_hud() -> void:
	var overlay_id := Bulwark.loc(Bulwark.UI_HUD)
	if UIManager.get_overlay(overlay_id) != null:
		UIManager.remove_overlay(overlay_id)
	var hud: Control = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	UIManager.add_overlay(overlay_id, hud)

func _subscribe_events() -> void:
	EventBus.subscribe(&"SpawnRequestEvent", _on_spawn_request)
	EventBus.subscribe(&"EnemyDiedEvent", _on_enemy_died)
	EventBus.subscribe(&"EnemyAttackEvent", _on_enemy_attack)
	EventBus.subscribe(&"BaseDestroyedEvent", _on_base_destroyed)
	EventBus.subscribe(&"RunVictoryEvent", _on_run_victory)
	EventBus.subscribe(&"PlayerDiedEvent", _on_player_died)

## 敌人啃基地（RunnerController 广播）→ 基地核心结算（订阅生命周期随装配层 = 安全）
func _on_enemy_attack(event: EnemyAttackEvent) -> void:
	if event == null:
		return
	base_core.take_damage(event.damage)

## 玩家阵亡 → 本局失败（M0 修订：撞击伤害实装后，玩家死亡即失败结算）
func _on_player_died(_event: PlayerDiedEvent) -> void:
	_finish_run(RunDefeatEvent.Reason.PLAYER_DEAD)

func _start_run() -> void:
	var wave_reg: WaveRegistry = RegistryManager.get_registry(Bulwark.REG_WAVE)
	var waves: Array[WaveData] = []
	for wave_id in [Bulwark.WAVE_1, Bulwark.WAVE_2, Bulwark.WAVE_3]:
		var wave: WaveData = wave_reg.get_entry(Bulwark.loc(wave_id))
		if wave == null:
			push_error("GameSession: 波次模板缺失 %s" % wave_id)
			return
		waves.append(wave)
	wave_director.start(waves)

# ─── 刷怪（表现层响应 SpawnRequestEvent；圆环随机刷新：方位扇形 + 随机半径） ───

## 刷怪圆环：基地周围环形出怪（对齐原版 orbitradius 模型）
const SPAWN_RADIUS := 720.0         # 基准刷怪半径（px）
const SPAWN_RADIUS_JITTER := 0.25   # 半径随机缩放 ±25%
const SPAWN_ANGLE_JITTER := 30.0    # 方位随机角偏移 ±30°
const SPAWN_POS_JITTER := 12.0      # 落点微抖动（px）

func _on_spawn_request(event: SpawnRequestEvent) -> void:
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, event.enemy_location)
	if enemy_data == null:
		push_error("GameSession: 敌人模板缺失 %s" % event.enemy_location)
		return
	# 来向向量：波次方向 + 随机角偏移（斜角方向天然支持，8 方向枚举）
	var dir_vec := DirectionUtils.to_vector(event.direction).rotated(
		deg_to_rad(randf_range(-SPAWN_ANGLE_JITTER, SPAWN_ANGLE_JITTER)))
	var perp := dir_vec.orthogonal()
	for i in event.count:
		var enemy: EnemyView = ENEMY_SCENE.instantiate() as EnemyView
		enemies_root.add_child(enemy)
		enemy.setup(enemy_data, base_node)
		# 圆环随机：随机半径 × 随机方位；群刷沿切线铺开成排
		var radius := SPAWN_RADIUS * randf_range(1.0 - SPAWN_RADIUS_JITTER, 1.0 + SPAWN_RADIUS_JITTER)
		var offset := (i - (event.count - 1) / 2.0) * SPAWN_ARC_SPACING
		enemy.global_position = base_node.global_position + dir_vec * radius + perp * offset \
			+ Vector2(randf_range(-SPAWN_POS_JITTER, SPAWN_POS_JITTER),
				randf_range(-SPAWN_POS_JITTER, SPAWN_POS_JITTER))
		wave_director.register_enemy_spawned()

func _on_enemy_died(_event: EnemyDiedEvent) -> void:
	wave_director.register_enemy_died()

# ─── 胜负结算 ───

func _on_base_destroyed(_event: BaseDestroyedEvent) -> void:
	_finish_run(RunDefeatEvent.Reason.BASE_DESTROYED)

func _on_run_victory(_event: RunVictoryEvent) -> void:
	_finish_run_victory()

func _finish_run_victory() -> void:
	if _run_finished:
		return
	_run_finished = true
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_RESULT), {"victory": true})

func _finish_run(reason: int) -> void:
	if _run_finished:
		return
	_run_finished = true
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_RESULT), {"victory": false, "reason": reason})

# ─── 暂停 ───

func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_PAUSE))
	else:
		get_tree().paused = true
		UIManager.open_panel(Bulwark.loc(Bulwark.UI_PAUSE))
