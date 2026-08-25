class_name GameSession
extends Node2D
## 本局组合根（前端装配层）：创建后端实例、接线、驱动帧循环
## - 后端（scripts/core/）纯逻辑：PlayerController / WeaponSlots / AmmoSystem / BaseCore / WaveDirector
##   + M1：RunState（货币/建材/储备）、ShopSystem（波间商店）、ReviveSystem（复活）、BarricadeController（路障）
## - 前端 → 后端 = 意图命令；后端 → 前端 = EventBus 事件（表现层只读状态）
## - M2 多人（host 权威）：本类按 Net.mode 拆双分支——
##   HOST/OFFLINE：完整模拟（M2 起 HOST 双玩家：本地 + 远端）+ 快照/事件广播 + 意图裁决
##   CLIENT：只读镜像（无本地模拟，位置/状态全由快照驱动）+ 发意图 RPC
##   单机 = OFFLINE（无网络层），行为与 M1 完全一致

const ENEMY_SCENE := preload("res://scenes/enemy/enemy.tscn")
const BARRICADE_SCENE := preload("res://scenes/base/barricade.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/vfx/enemy_projectile.tscn")
const TURRET_TRACER_SCENE := preload("res://scenes/vfx/turret_tracer.tscn")
const TURRET_SCENE := preload("res://scenes/base/turret.tscn")
const POWERUP_PICKUP_SCENE := preload("res://scenes/power/power_up_pickup.tscn")

const BASE_DURABILITY := 400.0
const BULLET_RESERVE := 120
const SPAWN_ARC_SPACING := 36.0
## 导航区域边界（M2 前置调参：容纳 900 刷怪半径）
const NAV_RECT := Rect2(-1250.0, -1250.0, 2500.0, 2500.0)

## 初始资源（M1：开局经济，商店成长起点）
const START_CREDITS := 120
const START_MATERIAL := 2
const START_RESERVE := 2

## 击杀奖励：建材微量掉落（路障建造循环：击杀 → 建材 → 商店/建造）
const KILL_MATERIAL_CHANCE := 0.35
## 击杀弹药掉落（审查 D3：补弹药补给手段，否则 wave5 前备弹告罄且无恢复途径）
const KILL_AMMO_CHANCE := 0.25
const KILL_AMMO_AMOUNT := 5

## 玩家初始站位（基地两侧；A = host/单机本地，B = 远端/客户端本地）
const PLAYER_A_SPAWN := Vector2(0.0, 180.0)
const PLAYER_B_SPAWN := Vector2(0.0, -180.0)

## 快照频率（M2：20Hz 全量快照；M3 问题 3：带宽分级——玩家高频/敌人中频解耦）
const SNAPSHOT_INTERVAL := 0.05
const ENEMIES_SNAPSHOT_INTERVAL := 0.1

@onready var player_node: CharacterBody2D = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var base_node: Node2D = $Base

var ammo_system: AmmoSystem
var weapon_slots: WeaponSlots
var player_controller: PlayerController
var base_core: BaseCore
var wave_director: WaveDirector
## M3 问题 4：资源/商店/背包改为 per-player（小队独立资源，D-M3-2）。
## run_state / shop_system / attachment_bag 保留为 players[0] 兼容别名（单机语义，既有引用不破坏）
var run_state: RunState
var shop_system: ShopSystem
var revive_system: ReviveSystem

## M2 双玩家（host：0=本地 1=远端；client：0=远端镜像 1=本地镜像；单机仅 [0]）
## player_controller / weapon_slots / ammo_system / revive_system 为 players[0] 的兼容别名（单机语义）
var players: Array[PlayerController] = []
var player_views: Array[PlayerView] = []
var weapon_slots_list: Array[WeaponSlots] = []
var ammo_systems: Array[AmmoSystem] = []
var revive_systems: Array[ReviveSystem] = []
## M3 问题 4：per-player 资源/商店/配件背包（与 players 下标对齐）
var run_states: Array[RunState] = []
var shop_systems: Array[ShopSystem] = []
## 元素为 Array[String]（未类型化外层：Array[Array] 元素无法赋给 Array[String] 类型化别名）
var attachment_bags: Array = []
## M5b：每玩家个人军械库（host 权威；client 镜像经事件/快照）
var arsenals: Array[Arsenal] = []
var arsenal: Arsenal
## M5b 设施选择：F 循环切换，E 放置/交互
var _selected_facility_type: int = DefenseFacilityData.FacilityType.BARRICADE
const FACILITY_CYCLE := [
	DefenseFacilityData.FacilityType.BARRICADE,
	DefenseFacilityData.FacilityType.TURRET,
]

## 路障（后端控制器 + 前端视图；instance_id 递增分配）
var barricades: Array[BarricadeController] = []
var barricade_views: Array[BarricadeView] = []
var _barricade_seq := 1
## M5b：自动炮塔（后端控制器 + 前端视图）
var turrets: Array[TurretController] = []
var turret_views: Array = []  # Array[Node2D]
## 配件背包（购买获得的配件 ResourceLocation 列表；装配后移除）
## M3：兼容别名（= attachment_bags[0]；单机语义，直接 append 反映到 per-player 背包）
var attachment_bag: Array[String] = []

## GUIDE 动作实例（与启用上下文同实例，轮询式读取）
var actions: Dictionary = {}  # StringName -> GUIDEAction
## 已启用的 combat_context（_exit_tree 时清理：GUIDE 是全局 autoload，
## 本节点释放后残留的 context 会污染后续场景/测试的输入状态）
var _combat_context: GUIDEMappingContext

var _run_finished := false
var _snapshot_timer := 0.0
var _snapshot_tick := 0
var _enemies_timer := 0.0
## 敌人网络 id（host 分配，快照/镜像同步用）
var _enemy_seq := 1
## 本进程负责的玩家 id（单机/OFFLINE = 0）
var _local_player_id := 0

## client 镜像簿记（去重发布 / 敌人镜像表）
var _last_run_state: Dictionary = {}
var _last_base: Dictionary = {}
var _last_players: Dictionary = {}
var _mirror_enemies: Dictionary = {}  # net_id(int) -> EnemyView
## M3 问题 3：敌人镜像位置去重（快照位置未变时跳过 set，降低每帧开销）
var _mirror_last_pos: Dictionary = {}  # net_id(int) -> Vector2
## M3 问题 4：per-player 镜像配件背包（元素为 Array[String]；客户端面板绑定本地玩家）
var _client_bags: Array = []
## M5b：per-player 镜像军械库（元素为 Array[String]）
var _client_arsenals: Array = []
## M3 问题 4：client 本地购买计数镜像（offers 视角自行计算：价格/已购/可负担）
var _client_purchase_counts: Dictionary = {}
var _client_started := false
## 结算结果（跨端 ui_state 携带；host 写入）
var _result_data: Dictionary = {}
## M5e：本局统计（击杀/波次/资源）
var _run_stats: Dictionary = {}
## P1 街机化：分数/连击/道具/Boss
var arcade_scores: Array[ArcadeScore] = []
var power_up_system: PowerUpSystem
var _run_start_ms := 0
var _wave_perfect := true
## 道具掉落（P1-6）：击杀后按权重 roll，几率为 POWERUP_DROP_CHANCE
const POWERUP_DROP_CHANCE := 0.12

## M3 问题 2：全队同意暂停——
## - host 维护暂停请求集合（player_id -> 请求中）；全员请求才正式暂停树，任一取消即恢复（D-M3-1）
## - client 本地面板开关由本地请求状态驱动；ui_state 只广播汇总（pause_requests）与正式暂停态
var _pause_requests: Dictionary = {}
var _local_pause_requested := false
## HUD 覆盖层引用（暂停请求提示 / 资源行 per-player 刷新）
var _hud: Hud
## P1-8 章节地面色调（main.tscn Ground Polygon2D）
var _ground_node: Node2D

## M3 方案 B：命中判定逻辑化——散布 RNG（裁决侧 host/OFFLINE 独占，与表现层手感解耦）
var _shot_rng := RandomNumberGenerator.new()
## 敌人命中半径（与 enemy.tscn CircleShape2D radius 对齐；判定输入）
const ENEMY_HIT_RADIUS := 14.0

func _ready() -> void:
	# 暂停菜单/结算面板需要在本节点暂停期间仍响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shot_rng.randomize()
	ContentBootstrap.register_all()
	_build_navigation()
	_ground_node = get_node_or_null("Ground") as Node2D
	_setup_smoke()
	if Net.is_client():
		# client 镜像装配依赖 host 分配的玩家 id（ENet peer id 随机，不能本地推导）；
		# 等 assign_player_id 信号；重载场景时已分配则直接装配
		Net.player_id_assigned.connect(_on_client_player_id_assigned)
		if Net.get_local_player_id() >= 0:
			_setup_client()
	else:
		_setup_host()
		if Net.is_host():
			# 多人 host：等客户端连上再开跑；重载场景时已有连接则直接开
			Net.set_intent_handler(_on_net_intent)
			Net.peer_connected.connect(_on_host_peer_connected)
			if Net.has_connected_client():
				_start_run()

## 释放清理：GUIDE 为全局 autoload，本节点启用的 context 在释放后必须禁用，
## 否则残留状态会污染后续场景（游戏重开/测试顺序）的输入处理
func _exit_tree() -> void:
	if _combat_context != null:
		GUIDE.disable_mapping_context(_combat_context)
		_combat_context = null
	# M4 光标状态机：战斗上下文释放 → 光标回默认（与 GUIDE 清理同点）
	CursorStateMachine.set_combat_active(false)
	# M4.1 面板残留清理：本局结束/重开前关闭战斗面板（防跨局/跨测试残留）
	for panel_id in [Bulwark.UI_RESULT, Bulwark.UI_PAUSE, Bulwark.UI_SHOP, Bulwark.UI_SETTINGS]:
		if UIManager.is_panel_open(Bulwark.loc(panel_id)):
			UIManager.close_panel(Bulwark.loc(panel_id))

func _on_client_player_id_assigned(_pid: int) -> void:
	_setup_client()

func _physics_process(delta: float) -> void:
	if Net.is_client():
		return
	if get_tree().paused or _run_finished or players.is_empty():
		return
	for i in players.size():
		players[i].tick(delta)
	for rs: ReviveSystem in revive_systems:
		rs.tick(delta)
	wave_director.tick(delta)
	_tick_turrets(delta)
	for score in arcade_scores:
		score.tick(delta)
	if power_up_system != null:
		power_up_system.tick(delta)
	if Net.is_host():
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0:
			_snapshot_timer = SNAPSHOT_INTERVAL
			_send_snapshot()
		# M3 问题 3：敌人快照独立 10Hz 通道（与玩家 20Hz 解耦，带宽减半）
		_enemies_timer -= delta
		if _enemies_timer <= 0.0:
			_enemies_timer = ENEMIES_SNAPSHOT_INTERVAL
			_send_enemies_snapshot()

func _process(_delta: float) -> void:
	if _smoke_mode:
		_smoke_tick(_delta)  # host/client 都计时（冒烟）
		if _run_finished:
			return
	if _run_finished:
		return
	var pause_action: GUIDEAction = actions.get(&"pause")
	if pause_action != null and pause_action.is_triggered():
		if Net.is_client():
			# client：本地立即开关自己的暂停面板（请求语义），host 汇总后决定是否冻结
			_toggle_pause_local()
			Net.send_intent(&"toggle_pause")
		else:
			_toggle_pause()
	var interact_action: GUIDEAction = actions.get(&"interact")
	if interact_action != null and interact_action.is_triggered():
		if Net.is_client():
			Net.send_intent(&"interact_facility", [_selected_facility_type])
		else:
			_try_interact_or_place(0, _selected_facility_type)
	var cycle_facility_action: GUIDEAction = actions.get(&"cycle_facility")
	if cycle_facility_action != null and cycle_facility_action.is_triggered():
		_cycle_facility()

# ─── 装配（host/OFFLINE） ───

func _setup_host() -> void:
	_setup_backend_host()
	_setup_input()
	_setup_scene_bindings_host()
	_setup_hud(0)
	_subscribe_events()
	_broadcast_initial_state()
	if not Net.is_host():
		_start_run()  # 单机（OFFLINE）：立即开跑

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

func _setup_backend_host() -> void:
	var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	if type_reg == null or model_reg == null:
		push_error("GameSession: 内容注册缺失（weapon_type/weapon_model）")
		return

	# ── 资源与经济（M3 问题 4：per-player 独立——货币/建材/储备/武器强化各自一份） ──
	var shop_pool: Array[ShopItemData] = []
	var shop_fixed: Array[ShopItemData] = []
	var shop_reg: ShopItemRegistry = RegistryManager.get_registry(Bulwark.REG_SHOP_ITEM)
	if shop_reg != null:
		for entry: ShopItemData in shop_reg.get_all_entries().values():
			if entry.is_fixed:
				shop_fixed.append(entry)
			else:
				shop_pool.append(entry)

	# ── 玩家（M2：HOST 双玩家；OFFLINE 单玩家） ──
	var player_count := 2 if Net.is_host() else 1
	for i in player_count:
		var rs := RunState.new(i)
		rs.add_credits(START_CREDITS)
		rs.add_material(START_MATERIAL)
		rs.add_reserve(START_RESERVE)
		run_states.append(rs)
		var bag: Array[String] = []
		attachment_bags.append(bag)
		arsenals.append(Arsenal.new([
			Bulwark.loc(Bulwark.WEAPON_MODEL_AR_1).to_string(),
			Bulwark.loc(Bulwark.WEAPON_MODEL_SG_1).to_string(),
			Bulwark.loc(Bulwark.WEAPON_MODEL_HG_1).to_string(),
			Bulwark.loc(Bulwark.WEAPON_MODEL_HG_4).to_string(),
		]))

		var ammo := AmmoSystem.new()
		ammo.set_count(WeaponTypeData.AmmoType.BULLET, BULLET_RESERVE)
		ammo.set_count(WeaponTypeData.AmmoType.ENERGY, 30)
		ammo_systems.append(ammo)

		var slots := WeaponSlots.new(ammo, rs, i)
		slots.assign_slot(
			WeaponSlots.SLOT_MAIN,
			type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_AR)),
			model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_AR_1)))
		slots.assign_slot(
			WeaponSlots.SLOT_SUB,
			type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_SG)),
			model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_SG_1)))
		slots.assign_slot(
			WeaponSlots.SLOT_PISTOL,
			type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_HG)),
			model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_HG_1)))
		weapon_slots_list.append(slots)

		var attributes := AttributeSet.new()
		attributes.set_base(AttributeSet.MAX_HEALTH, 100.0)
		attributes.set_base(AttributeSet.MOVE_SPEED, 260.0)
		attributes.set_base(AttributeSet.RELOAD_SPEED, 1.0)
		players.append(PlayerController.new(attributes, slots, i))
		revive_systems.append(ReviveSystem.new(rs))

	# 每玩家独立商店（同 seed 刷新同商品集；购买计数/价格递增独立，D-M3-2）
	# 武器箱按各玩家军械库过滤：已拥有型号不再上架
	for i in player_count:
		var ss := ShopSystem.new(run_states[i])
		ss.setup(shop_pool, shop_fixed, arsenals[i].owned_models)
		shop_systems.append(ss)

	# P1 街机化：每玩家一分（host 权威；HUD 按 player_id 过滤）
	for i in player_count:
		arcade_scores.append(ArcadeScore.new(i))
	power_up_system = PowerUpSystem.new()
	power_up_system.setup(_apply_power_up, _expire_power_up)
	_build_power_up_pool()

	# 兼容别名（单机语义 = players[0]；既有测试/代码引用）
	player_controller = players[0]
	weapon_slots = weapon_slots_list[0]
	ammo_system = ammo_systems[0]
	revive_system = revive_systems[0]
	run_state = run_states[0]
	shop_system = shop_systems[0]
	attachment_bag = attachment_bags[0]
	arsenal = arsenals[0]
	weapon_slots.emit_initial_state()

	base_core = BaseCore.new(BASE_DURABILITY)
	wave_director = WaveDirector.new()
	# P0-7：本局随机种子（波次 + 商店共源；Offline/主机权威侧注入）
	wave_director.set_run_seed(RunConfig.run_seed)
	# 波间商店：清场后等待商店关闭再开下一波（M1）
	wave_director.intermission_waits_for_shop = true

func _setup_input() -> void:
	_combat_context = load("res://input/contexts/combat_context.tres")
	if _combat_context == null:
		push_error("GameSession: combat_context.tres 缺失（先运行 tools/generate_guide_context.gd）")
		return
	GUIDE.enable_mapping_context(_combat_context, false, 0)
	CursorStateMachine.set_combat_active(true)
	for mapping: GUIDEActionMapping in _combat_context.mappings:
		actions[mapping.action.name] = mapping.action

	var equipment_context: GUIDEMappingContext = load("res://input/contexts/equipment_context.tres")
	if equipment_context != null:
		GUIDE.enable_mapping_context(equipment_context, false, 1)

func _setup_scene_bindings_host() -> void:
	var view := player_node as PlayerView
	view.setup(player_controller, actions)
	view.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SIMULATED)
	view.set_player_id(0)
	view.set_visual_pack("soldier1")
	player_views.append(view)
	if Net.is_host() and players.size() > 1:
		var view_b: PlayerView = PLAYER_SCENE.instantiate() as PlayerView
		add_child(view_b)
		view_b.global_position = PLAYER_B_SPAWN
		view_b.setup(players[1], {})
		view_b.set_role(PlayerView.Role.REMOTE, PlayerView.PositionMode.SIMULATED)
		view_b.set_player_id(1)
		view_b.set_visual_pack("manBlue")
		player_views.append(view_b)
	(base_node as BaseView).setup(base_core)

## HUD 挂载（UIManager 覆盖层；HUD 只读后端事件，不直接读写数值）
## UIManager 为跨场景 autoload：重开本局前先移除旧覆盖层，避免 id 冲突残留
func _setup_hud(local_player_id: int) -> void:
	_local_player_id = local_player_id
	var overlay_id := Bulwark.loc(Bulwark.UI_HUD)
	if UIManager.get_overlay(overlay_id) != null:
		UIManager.remove_overlay(overlay_id)
	var hud: Control = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	hud.set_local_player_id(local_player_id)
	_hud = hud as Hud
	UIManager.add_overlay(overlay_id, hud)
	if _hud != null:
		_hud.set_facility_hint(_selected_facility_type)

## 初始状态广播：HUD 挂载晚于后端创建，开局补发当前值避免显示 "--"
## （生命/基地耐久在创建时无事件；弹药/武器初始事件在 HUD 订阅前已发布）
## 多人 host：客户端连上时重发（见 _on_host_peer_connected）
## M3 问题 4：per-player 资源事件（携带 player_id）
func _broadcast_initial_state() -> void:
	for i in players.size():
		var pc: PlayerController = players[i]
		EventBus.publish(PlayerHealthChangedEvent.new(pc.health, pc.max_health, i))
	EventBus.publish(BaseDurabilityChangedEvent.new(
		base_core.durability, base_core.max_durability))
	for i in run_states.size():
		var rs: RunState = run_states[i]
		EventBus.publish(RunStateChangedEvent.new(rs.credits, rs.material, rs.reserve, i))
	for i in weapon_slots_list.size():
		weapon_slots_list[i].emit_initial_state()

func _subscribe_events() -> void:
	EventBus.subscribe(&"SpawnRequestEvent", _on_spawn_request)
	EventBus.subscribe(&"EnemyDiedEvent", _on_enemy_died)
	EventBus.subscribe(&"EnemyAttackEvent", _on_enemy_attack)
	EventBus.subscribe(&"EnemyRangedAttackEvent", _on_enemy_ranged_attack)
	EventBus.subscribe(&"EnemyAoEEvent", _on_enemy_aoe)
	EventBus.subscribe(&"TurretFiredEvent", _on_turret_fired)
	EventBus.subscribe(&"BaseDestroyedEvent", _on_base_destroyed)
	EventBus.subscribe(&"RunVictoryEvent", _on_run_victory)
	EventBus.subscribe(&"PlayerDiedEvent", _on_player_died)
	EventBus.subscribe(&"RevivedEvent", _on_revived)
	EventBus.subscribe(&"WaveClearedEvent", _on_wave_cleared)
	EventBus.subscribe(&"WaveStartedEvent", _on_wave_started_for_score)
	EventBus.subscribe(&"WaveWarningEvent", _on_wave_warning_theme)
	EventBus.subscribe(&"BaseDurabilityChangedEvent", _on_base_durability_for_score)
	EventBus.subscribe(&"PowerUpPickupEvent", _on_power_up_pickup)
	EventBus.subscribe(&"BarricadeDestroyedEvent", _on_barricade_destroyed)
	# M3 方案 B：命中判定在装配层裁决（core 几何判定；host/OFFLINE 均订阅，client 不裁决）
	EventBus.subscribe(&"ShotFiredEvent", _on_shot_fired)
	if Net.is_host():
		# 跨端事件中继（host → client）
		EventBus.subscribe(&"PlayerHealthChangedEvent", _relay_player_health)
		EventBus.subscribe(&"ReviveStartedEvent", _relay_revive_started)
		EventBus.subscribe(&"AmmoChangedEvent", _relay_ammo_changed)
		EventBus.subscribe(&"WeaponSwitchedEvent", _relay_weapon_switched)
		EventBus.subscribe(&"WeaponSwitchStartedEvent", _relay_weapon_switch_started)
		EventBus.subscribe(&"WeaponSwitchRejectedEvent", _relay_weapon_switch_rejected)
		EventBus.subscribe(&"ReloadStartedEvent", _relay_reload_started)
		EventBus.subscribe(&"AttachmentEquippedEvent", _relay_attachment_equipped)
		EventBus.subscribe(&"AttachmentUnequippedEvent", _relay_attachment_unequipped)
		EventBus.subscribe(&"RunStateChangedEvent", _relay_run_state)
		EventBus.subscribe(&"WaveWarningEvent", _relay_wave_warning)
		EventBus.subscribe(&"WaveStartedEvent", _relay_wave_started)
		EventBus.subscribe(&"WaveClearedEvent", _relay_wave_cleared)
		EventBus.subscribe(&"BarricadePlacedEvent", _relay_barricade_placed)
		EventBus.subscribe(&"BarricadeDamagedEvent", _relay_barricade_damaged)
		EventBus.subscribe(&"BarricadeDestroyedEvent", _relay_barricade_destroyed)
		EventBus.subscribe(&"EnemyRangedAttackEvent", _relay_enemy_ranged_attack)
		EventBus.subscribe(&"EnemyAoEEvent", _relay_enemy_aoe)
		EventBus.subscribe(&"TurretFiredEvent", _relay_turret_fired)
		# P1 街机化中继
		EventBus.subscribe(&"ScoreChangedEvent", _relay_score_changed)
		EventBus.subscribe(&"PowerUpPickupEvent", _relay_power_up_pickup)
		EventBus.subscribe(&"PowerUpExpiredEvent", _relay_power_up_expired)
		EventBus.subscribe(&"EnemyHealthChangedEvent", _relay_enemy_health)

# ─── 装配（client：只读镜像） ───

## 幂等保护：连接重入/信号重复时不重复装配
var _client_setup_done := false

func _setup_client() -> void:
	if _client_setup_done:
		return
	_client_setup_done = true
	_local_player_id = Net.get_local_player_id()
	# 镜像后端（不跑 tick，纯展示：HUD/商店面板读取；M3 问题 4：per-player 镜像）
	for i in 2:
		var rs := RunState.new(i)
		run_states.append(rs)
		var bag: Array[String] = []
		attachment_bags.append(bag)
		_client_bags.append(bag)
		var owned: Array[String] = []
		arsenals.append(Arsenal.new(owned))
		_client_arsenals.append(owned)
		shop_systems.append(ShopSystem.new(rs))
		var ammo := AmmoSystem.new()
		ammo.set_count(WeaponTypeData.AmmoType.BULLET, 0)
		ammo.set_count(WeaponTypeData.AmmoType.ENERGY, 0)
		ammo_systems.append(ammo)
		var slots := WeaponSlots.new(ammo, rs, i)
		# 镜像槽位与 host 同构（HUD/商店面板只读展示；数值由 host 事件/快照覆盖）
		var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
		var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
		if type_reg != null and model_reg != null:
			slots.assign_slot(WeaponSlots.SLOT_MAIN,
				type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_AR)),
				model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_AR_1)))
			slots.assign_slot(WeaponSlots.SLOT_SUB,
				type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_SG)),
				model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_SG_1)))
			slots.assign_slot(WeaponSlots.SLOT_PISTOL,
				type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_HG)),
				model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_HG_1)))
		weapon_slots_list.append(slots)
		var attributes := AttributeSet.new()
		attributes.set_base(AttributeSet.MAX_HEALTH, 100.0)
		attributes.set_base(AttributeSet.MOVE_SPEED, 260.0)
		attributes.set_base(AttributeSet.RELOAD_SPEED, 1.0)
		players.append(PlayerController.new(attributes, slots, i))
		revive_systems.append(ReviveSystem.new(rs))
	player_controller = players[_local_player_id]
	weapon_slots = weapon_slots_list[_local_player_id]
	ammo_system = ammo_systems[_local_player_id]
	revive_system = revive_systems[_local_player_id]
	run_state = run_states[_local_player_id]
	shop_system = shop_systems[_local_player_id]
	attachment_bag = attachment_bags[_local_player_id]
	arsenal = arsenals[_local_player_id]
	base_core = BaseCore.new(BASE_DURABILITY)
	wave_director = WaveDirector.new()

	_setup_input()
	_setup_scene_bindings_client()
	_setup_hud(_local_player_id)

	Net.set_state_receiver(_on_net_state)
	Net.set_event_receiver(_on_net_event)
	# M3 问题 3：敌人快照独立通道接收
	Net.set_enemies_receiver(_on_net_enemies)

func _setup_scene_bindings_client() -> void:
	# 玩家 A（远端，id 0）= 场景既有节点：纯镜像
	var view_a := player_node as PlayerView
	view_a.setup(players[0], {})
	view_a.set_role(PlayerView.Role.NONE, PlayerView.PositionMode.SNAPSHOT)
	view_a.set_player_id(0)
	view_a.set_visual_pack("soldier1")
	player_views.append(view_a)
	# 玩家 B（本地，id 1）= 运行时实例化：M3 本地预测（方向 B）——
	# SIMULATED 本地模拟（输入即时生效，手感 = 单机）+ 快照校正（apply_prediction_correction）
	var view_b: PlayerView = PLAYER_SCENE.instantiate() as PlayerView
	add_child(view_b)
	view_b.global_position = PLAYER_B_SPAWN
	view_b.setup(players[1], actions)
	view_b.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SIMULATED)
	view_b.set_player_id(1)
	view_b.set_visual_pack("manBlue")
	player_views.append(view_b)
	(base_node as BaseView).setup(base_core)

# ─── 多人 host：客户端接入/意图 ───

func _on_host_peer_connected(_peer_id: int) -> void:
	# 客户端接入：补发初始状态（后端早已装配，初始事件在 client 加入前已发布过）
	_broadcast_initial_state()
	_start_run()

## 意图裁决（host；player_id 由 Net 从发送者推导，不信任客户端自报）
func _on_net_intent(player_id: int, intent: StringName, args: Array) -> void:
	if _run_finished:
		return
	if player_id < 0 or player_id >= players.size():
		return
	if _smoke_mode:
		_smoke_stats["intents"] = int(_smoke_stats.get("intents", 0)) + 1
	match intent:
		&"move":
			players[player_id].set_move_intent(args[0] if args.size() > 0 else Vector2.ZERO)
		&"aim":
			players[player_id].set_aim_direction(args[0] if args.size() > 0 else Vector2.RIGHT)
		&"shoot":
			players[player_id].set_shoot_intent(bool(args[0]) if args.size() > 0 else false)
		&"reload":
			players[player_id].intent_reload()
		&"switch":
			players[player_id].intent_switch(int(args[0]) if args.size() > 0 else 0)
		&"place_barricade":
			_try_place_barricade(player_id)
		&"interact_facility":
			_try_interact_or_place(player_id, int(args[0]) if args.size() > 0 else DefenseFacilityData.FacilityType.BARRICADE)
		&"purchase":
			_host_purchase(player_id, str(args[0]) if args.size() > 0 else "")
		&"equip":
			if args.size() >= 2:
				_host_equip(player_id, int(args[0]), str(args[1]))
		&"unequip":
			if args.size() >= 2:
				_host_unequip(player_id, int(args[0]), int(args[1]))
		&"equip_model":
			if args.size() >= 2:
				_host_equip_model(player_id, int(args[0]), str(args[1]))
		&"shop_continue":
			on_shop_closed()
		&"toggle_pause":
			# M3 问题 2：请求语义——翻转发送者的暂停请求（全员请求才冻结）
			_toggle_pause(player_id)

## 商店购买（host 裁决）：效果作用于购买者玩家（D-M3-2：个人货币/个人商店/个人强化）
func _host_purchase(player_id: int, item_location: String) -> void:
	if player_id < 0 or player_id >= shop_systems.size():
		return
	shop_systems[player_id].try_purchase(item_location,
		func(item: ShopItemData) -> void: _shop_effect_handler(item, player_id))
	if Net.is_host():
		Net.send_event(NetCodec.EVT_SHOP_OFFERS, _shop_offers_payload())
		Net.send_event(NetCodec.EVT_BAG_CHANGED, {
			NetCodec.KEY_PLAYER_ID: player_id,
			NetCodec.KEY_BAG: attachment_bags[player_id].duplicate(),
		})

## 装配配件（host 校验：该玩家背包有货；旧件替换回其背包）
func _host_equip(player_id: int, slot_index: int, attachment_location: String) -> void:
	var attachment := _get_attachment(attachment_location)
	if attachment == null or slot_index < 0 or slot_index >= WeaponSlots.SLOT_COUNT:
		return
	if player_id < 0 or player_id >= attachment_bags.size():
		return
	var bag: Array[String] = attachment_bags[player_id]
	var idx := bag.find(attachment_location)
	if idx < 0:
		return
	var replaced: AttachmentData = weapon_slots_list[player_id].get_attachment(slot_index, attachment.slot)
	if weapon_slots_list[player_id].equip_attachment(slot_index, attachment):
		bag.remove_at(idx)
		if replaced != null and replaced.id != attachment.id:
			bag.append(Bulwark.loc(replaced.id).to_string())
		Net.send_event(NetCodec.EVT_BAG_CHANGED, {
			NetCodec.KEY_PLAYER_ID: player_id,
			NetCodec.KEY_BAG: bag.duplicate(),
		})

func _host_unequip(player_id: int, slot_index: int, attachment_slot: int) -> void:
	var attachment: AttachmentData = weapon_slots_list[player_id].get_attachment(slot_index, attachment_slot)
	if attachment == null:
		return
	if player_id < 0 or player_id >= attachment_bags.size():
		return
	if weapon_slots_list[player_id].unequip_attachment(slot_index, attachment_slot):
		attachment_bags[player_id].append(Bulwark.loc(attachment.id).to_string())
		Net.send_event(NetCodec.EVT_BAG_CHANGED, {
			NetCodec.KEY_PLAYER_ID: player_id,
			NetCodec.KEY_BAG: attachment_bags[player_id].duplicate(),
		})

## M5b：改枪台换型号（host 校验军械库拥有该型号 + 槽位类型匹配）
func _host_equip_model(player_id: int, slot_index: int, model_location: String) -> void:
	if player_id < 0 or player_id >= arsenals.size():
		return
	if slot_index < 0 or slot_index >= WeaponSlots.SLOT_COUNT:
		return
	if not arsenals[player_id].owns(model_location):
		return
	var registry := RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	if registry == null:
		return
	var loc := ResourceLocation.from_string(model_location)
	if loc == null:
		return
	var model := registry.get_entry(loc) as WeaponModelData
	if model == null:
		return
	var type_data := _get_weapon_type(model.type_id)
	if type_data == null:
		return
	weapon_slots_list[player_id].set_model(slot_index, model, type_data)

func _get_attachment(location: String) -> AttachmentData:
	var registry := RegistryManager.get_registry(Bulwark.REG_ATTACHMENT)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as AttachmentData

func _get_weapon_type(location: String) -> WeaponTypeData:
	var registry := RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as WeaponTypeData

func _get_model(location: String) -> WeaponModelData:
	var registry := RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as WeaponModelData

# ─── 事件路由（host）：敌人攻击/击杀/胜负/复活/商店（按 player_id） ───

## 敌人攻击路由：target 空 = 基地；非空 = 路障唯一标识（location#id）
func _on_enemy_attack(event: EnemyAttackEvent) -> void:
	if event == null:
		return
	if event.target == EnemyAttackEvent.TARGET_BASE:
		base_core.take_damage(event.damage)
		return
	for i in barricades.size():
		if barricades[i].get_location() == event.target:
			barricades[i].take_damage(event.damage)
			return

## M5a：敌人远程攻击（host 逻辑命中 + 事件驱动视觉弹体，D-M5-1）
## 当前最小目标 = 基地；事件同时驱动 host/client 视觉弹体（client 经中继）。
func _on_enemy_ranged_attack(event: EnemyRangedAttackEvent) -> void:
	if event == null or Net.is_client():
		return
	base_core.take_damage(event.damage)
	_spawn_enemy_projectile(event)

## M5a：敌人范围伤害（自爆体 AoE，host 逻辑命中）
## 结算基地 + 所有玩家；视觉爆炸由 host/client 事件驱动。
func _on_enemy_aoe(event: EnemyAoEEvent) -> void:
	if event == null or Net.is_client():
		return
	if base_node.global_position.distance_to(event.position) <= event.radius:
		base_core.take_damage(event.damage)
	for i in players.size():
		if i >= player_views.size() or not is_instance_valid(player_views[i]):
			continue
		if player_views[i].global_position.distance_to(event.position) <= event.radius:
			var ctx := DamageContext.create(Faction.Type.MUTANT, Faction.Type.PLAYER, event.damage)
			players[i].take_damage(ctx)
	_spawn_enemy_aoe_visual(event)

## M5b：自动炮塔命中（host 逻辑命中；client 由中继事件驱动视觉）
func _on_turret_fired(event: TurretFiredEvent) -> void:
	if event == null or Net.is_client():
		return
	for child in enemies_root.get_children():
		var enemy := child as EnemyView
		if enemy == null or enemy.net_id != event.target_net_id:
			continue
		var aim_dir := (event.target_position - event.origin).normalized()
		var dmg_result: DamageResult = enemy.apply_turret_hit(event.damage, aim_dir)
		if dmg_result != null and dmg_result.damage > 0.0:
			FxBurst.spawn_damage_number(
				enemy.global_position + Vector2(0, -22),
				str(roundi(dmg_result.damage)), Color(0.6, 0.9, 1.0))
		break
	_spawn_turret_tracer(event)

## 击杀奖励（M1 商店经济）：货币 + 概率建材 + 概率弹药（审查 D3 补给闭环）
## M3 问题 4：奖励归属击杀者独享（killer_id 由 EnemyDiedEvent 携带；撞击自爆 = 被撞玩家）
func _on_enemy_died(event: EnemyDiedEvent) -> void:
	wave_director.register_enemy_died()
	_run_stats["kills"] = int(_run_stats.get("kills", 0)) + 1
	if event == null:
		return
	var killer := event.killer_id
	if killer < 0 or killer >= run_states.size():
		killer = 0
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, event.enemy_location)
	if enemy_data != null and enemy_data.kill_reward > 0:
		run_states[killer].add_credits(enemy_data.kill_reward)
		if randf() < KILL_MATERIAL_CHANCE:
			run_states[killer].add_material(1)
		if randf() < KILL_AMMO_CHANCE:
			_grant_bullets(KILL_AMMO_AMOUNT, killer)
	# P1-10 分数/连击：基础分 × 连击倍率 × 道具加倍
	if killer < arcade_scores.size():
		var score_backend := arcade_scores[killer]
		score_backend.set_external_multiplier(
			power_up_system.score_multiplier(killer) if power_up_system != null else 1.0)
		var base_score := _score_for_enemy(event.enemy_location)
		if base_score > 0:
			score_backend.register_kill(base_score)
	_run_stats["score"] = arcade_scores[0].score if not arcade_scores.is_empty() else 0
	# P1-6 道具掉落：击杀位置视觉化掉落
	if randf() < POWERUP_DROP_CHANCE:
		_spawn_power_up_pickup(event.position)

## 敌人基础分（P1-10；后续可移到 EnemyData 数据字段）
func _score_for_enemy(enemy_location: String) -> int:
	var short := enemy_location.get_slice("enemy/", 1)
	match short:
		"runner":
			return 50
		"self_destruct":
			return 90
		"runner_fast":
			return 80
		"flying":
			return 120
		"runner_tough":
			return 100
		"spitter":
			return 120
		"armored":
			return 150
		"sniper":
			return 140
		"elite_behemoth":
			return 1000
	return 25

## 掉落池（装配层加载一次；P1-6）
var _power_up_pool: Array[PowerUpData] = []

func _build_power_up_pool() -> void:
	_power_up_pool.clear()
	var dir := DirAccess.open("res://resources/powerups")
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if file.ends_with(".tres"):
			var data: PowerUpData = load("res://resources/powerups/%s" % file)
			if data != null:
				_power_up_pool.append(data)
		file = dir.get_next()
	dir.list_dir_end()

func _roll_power_up() -> PowerUpData:
	if _power_up_pool.is_empty():
		return null
	var total := 0.0
	for data: PowerUpData in _power_up_pool:
		total += maxf(0.0, data.weight)
	if total <= 0.0:
		return null
	var roll := randf() * total
	var acc := 0.0
	for data: PowerUpData in _power_up_pool:
		acc += maxf(0.0, data.weight)
		if roll < acc:
			return data
	return _power_up_pool.back()

func _spawn_power_up_pickup(pos: Vector2) -> void:
	var data := _roll_power_up()
	if data == null:
		return
	var pickup: Node = POWERUP_PICKUP_SCENE.instantiate() as Node
	pickup.set("power_data", data)
	pickup.set("player_id", -1)
	get_parent().add_child(pickup)
	pickup.global_position = pos

## 补充子弹备弹并广播弹药事件（掉弹/商店弹药箱共用；HUD 只订阅事件刷新 reserve）
## M3 问题 4：补给落入指定玩家（默认 0 = 单机/本地）的弹药池
## M5b：通用弹药补给（子弹/能量等）；保留 _grant_bullets 兼容旧调用
func _grant_ammo(ammo_type: int, amount: int, p_player_id: int = 0) -> void:
	if amount <= 0:
		return
	var pid := p_player_id if p_player_id >= 0 and p_player_id < ammo_systems.size() else 0
	ammo_systems[pid].add(ammo_type, amount)
	var slot := weapon_slots_list[pid].get_current_slot()
	EventBus.publish(AmmoChangedEvent.new(
		ammo_type,
		slot.mag if slot.type_data != null else 0,
		ammo_systems[pid].get_count(ammo_type),
		pid))

func _grant_bullets(amount: int, p_player_id: int = 0) -> void:
	_grant_ammo(WeaponTypeData.AmmoType.BULLET, amount, p_player_id)

# ─── P1 街机化：分数/连击 perfect-wave / 道具 ───

## 波开始：perfect 标记复位（本波基地未掉耐久 + 玩家未阵亡 = PERFECT WAVE）
func _on_wave_started_for_score(_event: WaveStartedEvent) -> void:
	_wave_perfect = true
	_last_base_durability = base_core.durability if base_core != null else -1.0

## P1-8 章节地面色调：章首波切换 main.tscn 地面颜色（host/单机）
func _on_wave_warning_theme(event: WaveWarningEvent) -> void:
	if event.chapter_index < 0 or _ground_node == null \
			or wave_director.run_definition == null:
		return
	if event.chapter_index >= wave_director.run_definition.chapters.size():
		return
	var chapter: ChapterDefinition = wave_director.run_definition.chapters[event.chapter_index]
	_ground_node.color = chapter.theme_rgb

var _last_base_durability := -1.0

## 基地耐久下降检测：perfect 波被打破
func _on_base_durability_for_score(event: BaseDurabilityChangedEvent) -> void:
	if _last_base_durability >= 0.0 and event.current < _last_base_durability - 0.001:
		_wave_perfect = false
	_last_base_durability = event.current

## 道具拾取（host/OFFLINE 裁决；client 不订阅）
func _on_power_up_pickup(event: PowerUpPickupEvent) -> void:
	if event == null or power_up_system == null:
		return
	var data := _get_power_up(event.power_id)
	if data != null:
		power_up_system.activate(data, event.player_id)

func _get_power_up(power_id: String) -> PowerUpData:
	for data: PowerUpData in _power_up_pool:
		if data.id == power_id:
			return data
	return null

## 道具效果应用（即时 + 计时首次；多人在单玩家上分别应用）
func _apply_power_up(data: PowerUpData, pid: int) -> void:
	if data == null or pid < 0 or pid >= players.size():
		return
	match data.effect:
		PowerUpData.EffectKind.AMMO:
			_grant_ammo(WeaponTypeData.AmmoType.BULLET, maxi(1, int(data.amount)), pid)
		PowerUpData.EffectKind.MATERIAL:
			run_states[pid].add_material(maxi(1, int(data.amount)))
		PowerUpData.EffectKind.HEAL:
			players[pid].heal(data.amount)
		PowerUpData.EffectKind.FIRE_RATE:
			run_states[pid].bonus.add_modifier(WeaponStats.KEY_FIRE_RATE, maxf(0.01, data.amount), true)
		PowerUpData.EffectKind.PELLETS:
			run_states[pid].bonus.add_modifier(WeaponStats.KEY_PELLETS, data.amount, false)
		PowerUpData.EffectKind.SHIELD:
			players[pid].apply_bonus(AttributeSet.ARMOR, data.amount, false)
		PowerUpData.EffectKind.SCORE_MULT:
			pass  # 倍率由 PowerUpSystem.score_multiplier 实时读取
		PowerUpData.EffectKind.RESERVE:
			run_states[pid].add_reserve(maxi(1, int(data.amount)))

## 计时 buff 到期：移除修正（对称）
func _expire_power_up(data: PowerUpData, pid: int) -> void:
	if data == null or pid < 0 or pid >= players.size():
		return
	match data.effect:
		PowerUpData.EffectKind.FIRE_RATE:
			run_states[pid].bonus.remove_modifier(WeaponStats.KEY_FIRE_RATE, maxf(0.01, data.amount), true)
		PowerUpData.EffectKind.PELLETS:
			run_states[pid].bonus.remove_modifier(WeaponStats.KEY_PELLETS, data.amount, false)
		PowerUpData.EffectKind.SHIELD:
			players[pid].remove_bonus(AttributeSet.ARMOR, data.amount, false)
		_:
			pass

## M5a：敌人远程弹体视觉（host/client 事件驱动；纯表现，不做逐帧快照）
func _spawn_enemy_projectile(event: EnemyRangedAttackEvent) -> void:
	if event == null:
		return
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate() as Node2D
	get_parent().add_child(projectile)
	if projectile.has_method("setup"):
		projectile.setup(event.origin, event.target_position, event.speed, event.projectile_kind)

## M5a：自爆 AoE 视觉（爆炸闪光；复用 M4 粒子池）
func _spawn_enemy_aoe_visual(event: EnemyAoEEvent) -> void:
	if event == null:
		return
	FxBurst.spawn_flare(event.position, Color(1.0, 0.45, 0.2))

## BUG 交接：炮塔弹道改为主机射线裁决 + 客户端粗射线表现（更粗/更亮），
## 不再复用飞行弹体；event.target_position 已经是 HitscanResolver 命中点。
func _spawn_turret_tracer(event: TurretFiredEvent) -> void:
	if event == null:
		return
	var tracer: TurretTracer = TURRET_TRACER_SCENE.instantiate() as TurretTracer
	add_child(tracer)
	tracer.setup(event.origin, event.target_position)

## 玩家阵亡（M1 复活系统，P7/P20）：储备充足 → 复活 CD；耗尽 → 失败结算
## M2 双人：每玩家独立复活 CD；M3 问题 4：储备独立（个人储备耗尽 → 判负，多人规则 M6 细化）
func _on_player_died(event: PlayerDiedEvent) -> void:
	_wave_perfect = false
	var pid := event.player_id if event != null else 0
	if pid < 0 or pid >= revive_systems.size():
		pid = 0
	if revive_systems[pid].on_player_died():
		if Net.is_host():
			Net.send_event(NetCodec.EVT_REVIVE_STARTED, {
				NetCodec.KEY_PLAYER_ID: pid,
				NetCodec.KEY_CD: revive_systems[pid].REVIVE_CD,
			})
		return
	_finish_run(RunDefeatEvent.Reason.PLAYER_DEAD)

## 复活完成：回满血 + 拉回基地（M2 双人：各自回各自出生侧）
func _on_revived(event: RevivedEvent) -> void:
	var pid := event.player_id if event != null else 0
	if pid < 0 or pid >= players.size():
		pid = 0
	players[pid].revive()
	var spawn_pos := PLAYER_B_SPAWN if pid == 1 else PLAYER_A_SPAWN
	if pid < player_views.size() and is_instance_valid(player_views[pid]):
		player_views[pid].global_position = base_node.global_position + spawn_pos
	if Net.is_host():
		Net.send_event(NetCodec.EVT_REVIVED, {NetCodec.KEY_PLAYER_ID: pid})

## P1-10 波清/章清奖励：PERFECT WAVE +500×波系数；章清 +2000×章系数
func _grant_wave_score(event: WaveClearedEvent) -> void:
	if arcade_scores.is_empty() or event == null:
		return
	var wave_scale := DifficultyCurve.get_wave_scale(event.wave_index)
	for score_backend: ArcadeScore in arcade_scores:
		score_backend.on_wave_cleared(_wave_perfect, wave_scale)
	# 章末精英波且非最后一章 → 章清奖励
	if event.is_boss_wave and wave_director.run_definition != null \
			and event.chapter_index >= 0 \
			and event.chapter_index < wave_director.run_definition.chapters.size() - 1:
		var chapter: ChapterDefinition = wave_director.run_definition.chapters[event.chapter_index]
		for score_backend: ArcadeScore in arcade_scores:
			score_backend.on_chapter_cleared(chapter.chapter_scale)

## 波间商店（M1）：清场 → 刷新商品 → 打开面板 + 暂停（host 裁决；client 跟随 ui_state）
## M3 问题 4：每玩家独立商店（同 seed 刷新同商品集；面板绑定 host 本地玩家 = 玩家 0）
## M4.1：最后一波清场直接结算，不再打开波间商店（无需波间购买）
func _on_wave_cleared(event: WaveClearedEvent) -> void:
	if _run_finished:
		return
	_grant_wave_score(event)
	var total := wave_director.waves.size()
	if event.wave_index >= total:
		# 末波：INTERMISSION 直接续到下一波 → WaveDirector 发现无下一波 → VICTORY
		wave_director.resume_from_intermission()
		return
	var seed := event.wave_index * 1000 + 7 + RunConfig.run_seed
	for ss: ShopSystem in shop_systems:
		ss.refresh(seed)
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_SHOP), {
		"shop": shop_system,
		"weapon_slots": weapon_slots,
		"run_state": run_state,
		"bag": attachment_bag,
		"arsenal": arsenal,
		"effect_handler": _shop_effect_handler,
	})
	if Net.is_host():
		Net.send_event(NetCodec.EVT_SHOP_OFFERS, _shop_offers_payload())
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

## 商店购买效果落点（装配层统一裁决，前端只发购买意图）：
## STAT_PLAYER → 购买者玩家 AttributeSet；STAT_WEAPON → 购买者 RunState.bonus（武器结算）；
## ATTACHMENT → 购买者配件背包；BARRICADE/RESERVE → 购买者资源；AMMO → 购买者弹药池
## p_player_id：多人时全部落点归购买者（默认 0 = 单机/本地）
func _shop_effect_handler(item: ShopItemData, p_player_id: int = 0) -> void:
	if item == null:
		return
	var pid := p_player_id if p_player_id >= 0 and p_player_id < players.size() else 0
	match item.category:
		ShopItemData.Category.STAT_PLAYER:
			if item.modifier != null:
				# 修正通道取值：乘法商品传 multiplier、加法商品传 amount（amount=0 的纯乘法商品
				# 若误传 amount 会把乘法通道归零 → 属性终值 0（如"行军靴"导致移速 0 无法移动）
				if item.modifier.multiplier != 1.0:
					players[pid].apply_bonus(item.modifier.attribute,
						item.modifier.multiplier, true)
				else:
					players[pid].apply_bonus(item.modifier.attribute,
						item.modifier.amount, false)
		ShopItemData.Category.STAT_WEAPON:
			if item.modifier != null:
				run_states[pid].apply_bonus_modifier(item.modifier)
		ShopItemData.Category.ATTACHMENT:
			if not item.attachment_location.is_empty():
				attachment_bags[pid].append(item.attachment_location)
		ShopItemData.Category.BARRICADE:
			run_states[pid].add_material(item.barricade_count)
		ShopItemData.Category.RESERVE:
			run_states[pid].add_reserve(item.reserve_count)
		ShopItemData.Category.AMMO:
			_grant_ammo(item.ammo_type, item.ammo_amount, pid)
		ShopItemData.Category.WEAPON_CRATE:
			if not item.model_location.is_empty() and pid < arsenals.size():
				if arsenals[pid].add_model(item.model_location):
					if Net.is_host():
						Net.send_event(NetCodec.EVT_ARSENAL_CHANGED, {
							NetCodec.KEY_PLAYER_ID: pid,
							NetCodec.KEY_ARSENAL: arsenals[pid].get_owned_models(),
						})

## 商店面板关闭（"继续"按钮）→ 恢复 → 下一波
## client：发意图由 host 裁决；host：本地直接恢复 + 广播 ui_state
func on_shop_closed() -> void:
	if _run_finished:
		return
	if Net.is_client():
		Net.send_intent(&"shop_continue")
		return
	UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	wave_director.resume_from_intermission()
	# 商店关闭后树状态回到暂停请求裁决（全队仍请求中则保持暂停）
	_evaluate_pause()
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

# ─── 路障（M1 防线设施；M2 前置：弧形路障已落地） ───

## 放置路障（E 键意图）：消耗 1 建材；M4 位置改为「玩家前方」（D-M4-17）——
## 方位角不变、半径 + BARRIER_FORWARD_OFFSET（玩家与基地连线外侧），保留 build_radius 上限，
## 新增半径下限（不封死出生环）与路障间距（防重叠堆叠）。
## 双人：p_player_id 指定放置者（host 用其模拟位置；不信客户端坐标）；建材扣放置者个人资源
const BARRIER_FORWARD_OFFSET := 48.0
const BARRIER_MIN_RADIUS := 96.0
const BARRIER_MIN_SPACING := 64.0

func _try_place_barricade(p_player_id: int = 0) -> void:
	if _run_finished or get_tree().paused:
		return
	var pid := p_player_id if p_player_id >= 0 and p_player_id < player_views.size() else 0
	if players[pid].is_incapacitated():
		return
	var facility: DefenseFacilityData = ContentBootstrap.get_entry(
		Bulwark.REG_FACILITY, Bulwark.loc(Bulwark.FACILITY_BARRICADE).to_string())
	if facility == null:
		return
	if not run_states[pid].try_spend_material(facility.material_cost):
		return
	var player_pos := player_views[pid].global_position
	var placement := BarricadeController.compute_forward_placement(
		player_pos, base_node.global_position, BARRIER_FORWARD_OFFSET)
	var pos: Vector2 = placement.get(&"pos", player_pos)
	var radius := float(placement.get(&"radius", 0.0))
	var base_pos := base_node.global_position
	# 校验：半径下限 / 放置点上限 / 与既有路障间距（失败退回建材，D-M4-17）
	if radius < BARRIER_MIN_RADIUS \
			or base_pos.distance_to(pos) > facility.build_radius \
			or not _barricade_spacing_ok(pos):
		run_states[pid].add_material(facility.material_cost)
		return
	var controller := BarricadeController.new(facility, _barricade_seq)
	_barricade_seq += 1
	barricades.append(controller)
	var view: BarricadeView = BARRICADE_SCENE.instantiate() as BarricadeView
	barricade_views.append(view)
	add_child(view)
	view.global_position = pos
	view.setup(controller)
	view.align_to_arc(base_pos)  # 弧心朝向基地 + 按半径重建弧面/碰撞
	EventBus.publish(BarricadePlacedEvent.new(controller.get_location(), pos))

func _barricade_spacing_ok(candidate: Vector2) -> bool:
	var existing: Array = []
	for view: BarricadeView in barricade_views:
		if view != null and is_instance_valid(view):
			existing.append(view.global_position)
	return BarricadeController.has_min_spacing(candidate, existing, BARRIER_MIN_SPACING)

func _on_barricade_destroyed(event: BarricadeDestroyedEvent) -> void:
	# 表现层视图自监听销毁事件移除节点；后端控制器保留（查询/路由安全返回）
	for i in barricades.size():
		if barricades[i].get_location() == event.facility_location:
			barricades[i] = null
			barricades.remove_at(i)
			break
	for i in barricade_views.size():
		if barricade_views[i] != null and is_instance_valid(barricade_views[i]) \
				and barricade_views[i].get_location() == event.facility_location:
			barricade_views[i].queue_free()
			barricade_views.remove_at(i)
			break

# ─── M5b：炮塔/最小修复交互 ───

func _facility_spacing_ok(candidate: Vector2) -> bool:
	var existing: Array = []
	for v in barricade_views:
		if v != null and is_instance_valid(v):
			existing.append(v.global_position)
	for v in turret_views:
		if v != null and is_instance_valid(v):
			existing.append(v.global_position)
	return BarricadeController.has_min_spacing(candidate, existing, BARRIER_MIN_SPACING)

func _try_place_turret(p_player_id: int = 0) -> void:
	if _run_finished or get_tree().paused:
		return
	var pid := p_player_id if p_player_id >= 0 and p_player_id < player_views.size() else 0
	if players[pid].is_incapacitated():
		return
	var facility: DefenseFacilityData = ContentBootstrap.get_entry(
		Bulwark.REG_FACILITY, Bulwark.loc(Bulwark.FACILITY_TURRET).to_string())
	if facility == null:
		return
	if not run_states[pid].try_spend_material(facility.material_cost):
		return
	var player_pos := player_views[pid].global_position
	var placement := BarricadeController.compute_forward_placement(
		player_pos, base_node.global_position, BARRIER_FORWARD_OFFSET)
	var pos: Vector2 = placement.get(&"pos", player_pos)
	var radius := float(placement.get(&"radius", 0.0))
	if radius < BARRIER_MIN_RADIUS \
			or base_node.global_position.distance_to(pos) > facility.build_radius \
			or not _facility_spacing_ok(pos):
		run_states[pid].add_material(facility.material_cost)
		return
	var controller := TurretController.new(
		facility, _barricade_seq,
		run_states[pid].get_bonus_final(AttributeSet.TURRET_DAMAGE))
	_barricade_seq += 1
	controller.setup_position(pos)
	turrets.append(controller)
	var view: Node2D = TURRET_SCENE.instantiate() as Node2D
	turret_views.append(view)
	add_child(view)
	view.global_position = pos
	view.setup(controller)
	if Net.is_host():
		Net.send_event(NetCodec.EVT_TURRET_PLACED, {
			NetCodec.KEY_LOCATION: controller.get_location(),
			NetCodec.KEY_POS: NetCodec.vec_to_arr(pos),
		})

## E 键统一交互：优先修复受损设施，否则放置当前选中设施（路障/炮塔）
func _cycle_facility() -> void:
	var idx := FACILITY_CYCLE.find(_selected_facility_type)
	_selected_facility_type = FACILITY_CYCLE[(idx + 1) % FACILITY_CYCLE.size()]
	if _hud != null:
		_hud.set_facility_hint(_selected_facility_type)

func _try_interact_or_place(p_player_id: int = 0, facility_type: int = -1) -> void:
	var pid := p_player_id if p_player_id >= 0 and p_player_id < player_views.size() else 0
	if facility_type < 0:
		facility_type = _selected_facility_type
	if _try_repair_nearest_facility(pid):
		return
	match facility_type:
		DefenseFacilityData.FacilityType.TURRET:
			_try_place_turret(pid)
		_:
			_try_place_barricade(pid)

func _try_repair_nearest_facility(p_player_id: int) -> bool:
	if p_player_id < 0 or p_player_id >= player_views.size():
		return false
	var player_pos := player_views[p_player_id].global_position
	var candidates: Array = []
	for i in barricades.size():
		if i < barricade_views.size() and is_instance_valid(barricade_views[i]):
			candidates.append([barricades[i], barricade_views[i].global_position])
	for i in turrets.size():
		if i < turret_views.size() and is_instance_valid(turret_views[i]):
			candidates.append([turrets[i], turret_views[i].global_position])
	for c in candidates:
		var controller: FacilityController = c[0]
		var pos: Vector2 = c[1]
		if controller == null or controller.is_destroyed():
			continue
		if controller.durability >= controller.max_durability:
			continue
		if player_pos.distance_to(pos) > 110.0:
			continue
		if run_states[p_player_id].try_spend_material(controller.data.repair_cost):
			controller.repair(controller.data.repair_amount)
			return true
	return false

func _tick_turrets(delta: float) -> void:
	if turrets.is_empty():
		return
	var enemies: Array = []
	for child in enemies_root.get_children():
		var enemy := child as EnemyView
		if enemy == null or enemy.controller == null or enemy.controller.is_dead():
			continue
		enemies.append({
			&"net_id": enemy.net_id,
			&"pos": enemy.global_position,
			&"radius": ENEMY_HIT_RADIUS,
			&"alive": true,
		})
	for turret: TurretController in turrets:
		turret.tick(delta, enemies)

func _start_run() -> void:
	_run_start_ms = Time.get_ticks_msec()
	_begin_waves()

const ARCADE_RUN_PATH := "res://resources/runs/arcade_run.tres"

func _begin_waves() -> void:
	# P1-8：街机模式 = RunDefinition（4 章 × 3+1 波）；legacy 单章 6 波回退（既有测试/CLI 兼容）
	if RunConfig.is_arcade():
		var run: RunDefinition = load(ARCADE_RUN_PATH)
		if run == null or run.chapters.is_empty():
			push_error("GameSession: 街机 RunDefinition 缺失 %s" % ARCADE_RUN_PATH)
			return
		wave_director.start_run(run)
		return
	var wave_reg: WaveRegistry = RegistryManager.get_registry(Bulwark.REG_WAVE)
	var waves: Array[WaveData] = []
	for wave_id: String in Bulwark.WAVE_IDS:
		var wave: WaveData = wave_reg.get_entry(Bulwark.loc(wave_id))
		if wave == null:
			push_error("GameSession: 波次模板缺失 %s" % wave_id)
			return
		waves.append(wave)
	wave_director.start(waves)

# ─── 刷怪（host 响应 SpawnRequestEvent；圆环随机刷新：方位扇形 + 随机半径） ───
## client 不订阅：敌人由 host 模拟，快照镜像（RNG 全部 host 独占）

## 刷怪圆环：基地周围环形出怪（对齐原版 orbitradius 模型）
const SPAWN_RADIUS := 900.0         # 基准刷怪半径（px；M2 前置调参：720→900 拉长接敌时间）
const SPAWN_RADIUS_JITTER := 0.15   # 半径随机缩放 ±15%（审查【硬性】：R×(1+jitter) ≤ 战场边界-边距）
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
	# 双人强度缩放（R10）：在线双人时血量 × EnemyData.player_count_scale（数据已配 1.6）
	var hp_scale := enemy_data.player_count_scale if Net.is_host() else 1.0
	for i in event.count:
		var enemy: EnemyView = ENEMY_SCENE.instantiate() as EnemyView
		enemies_root.add_child(enemy)
		enemy.net_id = _enemy_seq
		_enemy_seq += 1
		enemy.setup(enemy_data, base_node, _get_barricade_views, hp_scale)
		# 圆环随机：随机半径 × 随机方位；群刷沿切线铺开成排
		var radius := SPAWN_RADIUS * randf_range(1.0 - SPAWN_RADIUS_JITTER, 1.0 + SPAWN_RADIUS_JITTER)
		var offset := (i - (event.count - 1) / 2.0) * SPAWN_ARC_SPACING
		var pos := base_node.global_position + dir_vec * radius + perp * offset \
			+ Vector2(randf_range(-SPAWN_POS_JITTER, SPAWN_POS_JITTER),
				randf_range(-SPAWN_POS_JITTER, SPAWN_POS_JITTER))
		# 落点 clamp 到导航区域（内缩 20px 防御，审查 §3.3.2 建议）
		enemy.global_position = Vector2(
			clampf(pos.x, NAV_RECT.position.x + 20.0, NAV_RECT.end.x - 20.0),
			clampf(pos.y, NAV_RECT.position.y + 20.0, NAV_RECT.end.y - 20.0))
		wave_director.register_enemy_spawned()

## 路障视图查询（表现层注入 EnemyView：攻击路径上的路障优先）
func _get_barricade_views() -> Array[BarricadeView]:
	return barricade_views

# ─── 胜负结算 ───

func _on_base_destroyed(_event: BaseDestroyedEvent) -> void:
	_finish_run(RunDefeatEvent.Reason.BASE_DESTROYED)

func _on_run_victory(_event: RunVictoryEvent) -> void:
	_finish_run_victory()

func _collect_run_stats() -> Dictionary:
	var stats := _run_stats.duplicate()
	stats["wave"] = wave_director.current_wave_index + 1
	if not run_states.is_empty():
		stats["credits"] = run_states[0].credits
		stats["material"] = run_states[0].material
		stats["reserve"] = run_states[0].reserve
	if not arcade_scores.is_empty():
		stats["score"] = arcade_scores[0].score
		stats["combo"] = arcade_scores[0].max_combo
		stats["time"] = (Time.get_ticks_msec() - _run_start_ms) / 1000.0
	return stats

## P1-10 结算：写入本地 Top10 并把排行榜带入结果面板
func _attach_score_result() -> void:
	if arcade_scores.is_empty():
		return
	var sc := arcade_scores[0]
	var stats: Dictionary = _result_data.get("stats", {})
	stats["score"] = sc.score
	stats["combo"] = sc.max_combo
	var time_sec := (Time.get_ticks_msec() - _run_start_ms) / 1000.0
	stats["time"] = time_sec
	var entry := {
		"score": sc.score,
		"combo": sc.max_combo,
		"kills": int(_run_stats.get("kills", 0)),
		"time": time_sec,
		"name": "",
	}
	stats["highscore_rank"] = HighScoreStore.save_entry(entry)
	stats["highscores"] = HighScoreStore.load_top()
	_result_data["stats"] = stats

func _finish_run_victory() -> void:
	if _run_finished:
		return
	_run_finished = true
	_result_data = {"victory": true, "stats": _collect_run_stats()}
	_attach_score_result()
	# 清掉可能残留的波间商店面板（最后波清场后商店刚打开即胜利）
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_RESULT), _result_data)
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

func _finish_run(reason: int) -> void:
	if _run_finished:
		return
	_run_finished = true
	_result_data = {"victory": false, "reason": reason, "stats": _collect_run_stats()}
	_attach_score_result()
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_RESULT), _result_data)
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

# ─── 暂停（M3 问题 2：全队同意才暂停） ───

## 暂停请求切换（host/单机）：按「该玩家自身请求状态」判定方向（面板状态是进程共享的，
## 双人时不能以面板开合推断单人 toggle 方向），本地面板只随本地玩家请求状态开关。
## 单机（players 仅 1 人）：请求即全员 → 行为与 M1 完全一致
func _toggle_pause(p_player_id: int = 0) -> void:
	var requesting := not bool(_pause_requests.get(p_player_id, false))
	if p_player_id == _local_player_id:
		if requesting:
			UIManager.open_panel(Bulwark.loc(Bulwark.UI_PAUSE))
		else:
			UIManager.close_panel(Bulwark.loc(Bulwark.UI_PAUSE))
	_set_pause_request(p_player_id, requesting)

## client 本地：立即开关自己的暂停面板（请求语义；host 汇总后经 ui_state 广播正式暂停态）
func _toggle_pause_local() -> void:
	_local_pause_requested = not _local_pause_requested
	if _local_pause_requested:
		UIManager.open_panel(Bulwark.loc(Bulwark.UI_PAUSE))
	else:
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_PAUSE))

func _set_pause_request(p_player_id: int, requested: bool) -> void:
	_pause_requests[p_player_id] = requested
	_evaluate_pause()

## 暂停生效判定：全部在线玩家均已请求 → 冻结树；否则恢复（任一玩家取消即恢复，D-M3-1）
## 波间商店打开时树由商店托管（保持暂停），暂停请求只裁决非商店状态的冻结
## host 树暂停期间 Net 为 PROCESS_MODE_ALWAYS，意图不丢，暂停中收到请求/取消照常处理
func _evaluate_pause() -> void:
	var all_requested := true
	for i in players.size():
		if not _pause_requests.get(i, false):
			all_requested = false
			break
	get_tree().paused = all_requested \
		or UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP))
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

# ─── 多人 host：快照与事件中继 ───

func _ui_state_payload() -> Dictionary:
	var requests: Array = []
	for i in players.size():
		if _pause_requests.get(i, false):
			requests.append(i)
	return {
		NetCodec.KEY_PAUSED: get_tree().paused,
		NetCodec.KEY_SHOP_OPEN: UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)),
		NetCodec.KEY_RESULT: _result_data,
		NetCodec.KEY_PAUSE_REQUESTS: requests,
	}

## client：暂停请求提示更新（HUD 显示"玩家 X 请求暂停 (n/m)"）
func _update_pause_hint(requests: Array) -> void:
	if _hud != null:
		_hud.set_pause_requests(requests, players.size())

# ─── 冒烟（--smoke：headless 双进程验收；各端统计关键指标，到点断言退出） ───

var _smoke_mode := false
var _smoke_duration := 40.0
var _smoke_timer := 0.0
var _smoke_step := 0
var _smoke_stats: Dictionary = {}

func _setup_smoke() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--smoke"):
		return
	_smoke_mode = true
	for arg in args:
		if arg.begins_with("--smoke-duration="):
			_smoke_duration = maxf(5.0, float(arg.trim_prefix("--smoke-duration=")))
	_smoke_stats = {
		"snapshots": 0,  # host：已发送快照帧数
		"intents": 0,    # host：已收到客户端意图数
		"syncs": 0,      # client：已收到快照帧数
		"enemy_peak": 0, # 双方：敌人数量峰值（快照/镜像）
	}

func _smoke_tick(delta: float) -> void:
	_smoke_timer += delta
	if Net.is_client():
		# 自动意图：周期轮换移动方向 + 断续射击 + 放置路障 + 切枪
		_smoke_step += 1
		var dirs := [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
		Net.send_intent(&"move", [dirs[_smoke_step % 4]])
		Net.send_intent(&"aim", [Vector2.RIGHT])
		Net.send_intent(&"shoot", [_smoke_step % 2 == 0])
		if _smoke_step == 4:
			Net.send_intent(&"place_barricade")
		if _smoke_step == 8:
			Net.send_intent(&"switch", [WeaponSlots.SLOT_SUB])
		if _smoke_step == 12:
			Net.send_intent(&"reload")
	if _smoke_timer >= _smoke_duration:
		_finish_smoke()

func _finish_smoke() -> void:
	var ok := false
	if Net.is_host():
		ok = int(_smoke_stats.get("snapshots", 0)) > 0 \
			and int(_smoke_stats.get("intents", 0)) > 0 \
			and int(_smoke_stats.get("enemy_peak", 0)) > 0
	else:
		ok = int(_smoke_stats.get("syncs", 0)) > 0 \
			and int(_smoke_stats.get("enemy_peak", 0)) > 0
	print("[smoke] %s stats=%s" % ["HOST" if Net.is_host() else "CLIENT", _smoke_stats])
	print("SMOKE_RESULT=%s" % ("ok" if ok else "fail"))
	# 结果写 user:// 文件（规避 stdout 重定向缓冲/进程退出时序的判定问题；验收脚本读取）
	var f := FileAccess.open("user://smoke-result.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("ok" if ok else "fail")
		f.close()
	get_tree().quit(0 if ok else 1)

## M3 问题 4：商店商品广播——只带商品 location（价格/已购/可负担为 per-player 视角，
## 广播通道无法逐玩家表达，client 用本地镜像 purchase_counts + credits 自行计算，D-M3-4）
func _shop_offers_payload() -> Dictionary:
	var offers: Array = []
	for offer_variant in shop_system.offers:
		var offer := offer_variant as ShopRefreshedEvent.Offer
		if offer == null or offer.item == null:
			continue
		offers.append({
			NetCodec.KEY_OFFER_LOCATION: Bulwark.loc(offer.item.id).to_string(),
		})
	return {NetCodec.KEY_OFFERS: offers}

func _send_snapshot() -> void:
	if players.is_empty() or base_core == null:
		return
	_snapshot_tick += 1
	if _smoke_mode:
		_smoke_stats["snapshots"] = int(_smoke_stats.get("snapshots", 0)) + 1
	var players_data: Dictionary = {}
	for i in players.size():
		var view := player_views[i]
		players_data[str(i)] = {
			NetCodec.PLAYER_POS: NetCodec.vec_to_arr(view.global_position),
			NetCodec.PLAYER_AIM: players[i].aim_direction.angle(),
			NetCodec.PLAYER_HP: players[i].health,
			NetCodec.PLAYER_MAX_HP: players[i].max_health,
			NetCodec.PLAYER_STATE: players[i].state,
		}
	# M3 问题 4：per-player 资源表（credits/material/reserve/bag 各玩家独立）
	var resources: Dictionary = {}
	for i in run_states.size():
		resources[str(i)] = {
			NetCodec.RUN_CREDITS: run_states[i].credits,
			NetCodec.RUN_MATERIAL: run_states[i].material,
			NetCodec.RUN_RESERVE: run_states[i].reserve,
			NetCodec.RUN_BAG: attachment_bags[i].duplicate(),
			NetCodec.RUN_ARSENAL: arsenals[i].get_owned_models() if i < arsenals.size() else [],
		}
	Net.send_snapshot({
		NetCodec.SNAP_TICK: _snapshot_tick,
		NetCodec.SNAP_RUN: {
			NetCodec.RUN_PAUSED: get_tree().paused,
			NetCodec.RUN_SHOP_OPEN: UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)),
			NetCodec.RUN_FINISHED: _run_finished,
			NetCodec.RUN_RESOURCES: resources,
			NetCodec.RUN_WAVE_INDEX: wave_director.current_wave_index + 1,
			NetCodec.RUN_WAVE_TOTAL: wave_director.waves.size(),
		},
		NetCodec.SNAP_BASE: {
			NetCodec.BASE_DURABILITY: base_core.durability,
			NetCodec.BASE_MAX: base_core.max_durability,
		},
		NetCodec.SNAP_PLAYERS: players_data,
	})

## M3 问题 3：敌人快照独立通道（10Hz 中频；与玩家 20Hz 解耦，真机带宽减半）
func _send_enemies_snapshot() -> void:
	var enemies_data: Dictionary = {}
	for child in enemies_root.get_children():
		var enemy := child as EnemyView
		if enemy == null or enemy.controller == null:
			continue
		enemies_data[str(enemy.net_id)] = {
			NetCodec.ENEMY_POS: NetCodec.vec_to_arr(enemy.global_position),
			NetCodec.ENEMY_STATE: (
				NetCodec.ENEMY_STATE_DEAD if enemy.controller.is_dead()
				else NetCodec.ENEMY_STATE_ALIVE),
			NetCodec.ENEMY_LOCATION: Bulwark.loc(enemy.controller.data.id).to_string(),
		}
	if _smoke_mode:
		_smoke_stats["enemy_peak"] = maxi(
			int(_smoke_stats.get("enemy_peak", 0)), enemies_data.size())
	Net.send_enemies(enemies_data)

func _relay(event_name: String, payload: Dictionary) -> void:
	if Net.is_host():
		Net.send_event(event_name, payload)

func _relay_player_health(event: PlayerHealthChangedEvent) -> void:
	_relay(NetCodec.EVT_PLAYER_HEALTH, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_CURRENT: event.current,
		NetCodec.KEY_MAX: event.max_value,
	})

func _relay_revive_started(event: ReviveStartedEvent) -> void:
	_relay(NetCodec.EVT_REVIVE_STARTED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_CD: event.revive_cd,
	})

## M3 方案 B：射击命中裁决（装配层，host/OFFLINE）——核心变更：
## "打没打中"由 core 几何判定（HitscanResolver）基于权威位置（host 视图=模拟）计算，
## 不再依赖表现层物理射线/碰撞体状态；伤害/受击反馈/tracer 全部由本层统一驱动，
## client 端表现（tracer/镜像闪白）跟随 host 裁决结果（EVT_SHOT_FIRED 带命中点 /
## EVT_ENEMY_HIT 中继），视觉与裁决一致。
func _on_shot_fired(event: ShotFiredEvent) -> void:
	if event == null:
		return
	if Net.is_client():
		return  # client 不裁决（host 权威；中继事件由 _on_net_event 路由表现）
	var pid := event.player_id
	if pid < 0 or pid >= weapon_slots_list.size() or pid >= player_views.size():
		return
	var view := player_views[pid]
	if view == null or not is_instance_valid(view):
		return
	var stats := weapon_slots_list[pid].get_effective_stats(
		weapon_slots_list[pid].get_current_slot())
	# 手感系数（type.recoil）：连射热度累加量（裁决侧维护 heat；原在表现层）
	var recoil := Vector2.ONE
	var model: WeaponModelData = ContentBootstrap.get_entry(Bulwark.REG_WEAPON_MODEL, event.model_location)
	if model != null and not model.type_id.is_empty():
		var type_data: WeaponTypeData = ContentBootstrap.get_entry(Bulwark.REG_WEAPON_TYPE, model.type_id)
		if type_data != null:
			recoil = type_data.recoil
	players[pid].heat = minf(PlayerController.HEAT_MAX,
		players[pid].heat + PlayerController.HEAT_PER_SHOT * recoil.x)
	# 移动时散布扩大（与表现层解耦后由裁决侧统一计算）
	var move_mult := PlayerView.MOVE_SPREAD_MULT \
		if players[pid].move_direction.length_squared() > 0.001 else 1.0
	var total_spread := (stats.spread + players[pid].heat) * move_mult
	# 权威目标集合（敌人视图位置 = host 模拟位置；排除已死）
	var target_enemies: Array = []
	var targets: Array = []
	for child in enemies_root.get_children():
		var enemy := child as EnemyView
		if enemy == null or enemy.controller == null or enemy.controller.is_dead():
			continue
		target_enemies.append(enemy)
		targets.append({
			&"pos": enemy.global_position,
			&"radius": ENEMY_HIT_RADIUS,
		})
	var muzzle_dir := event.aim_direction
	# 权威发射点：玩家枪口世界坐标（角色中心 + 枪口局部偏移随瞄准旋转），而非身体中心
	var origin := view.global_position \
		+ PlayerView.MUZZLE_LOCAL_POS.rotated(muzzle_dir.angle())
	var pellets := maxi(1, stats.pellets)
	var hit_points: Array = []
	for _i in pellets:
		var dir := PlayerView.apply_spread(muzzle_dir, total_spread, _shot_rng)
		var res := HitscanResolver.resolve_hit(origin, dir, stats.range, targets)
		var end: Vector2 = res.get(&"point", origin + dir * stats.range)
		if res.get(&"hit", false):
			var hit_enemy: EnemyView = target_enemies[res.get(&"index", 0)]
			# 伤害（killer_id = 射击者；镜像/单机同路径）
			var dmg_result: DamageResult = hit_enemy.apply_player_hit(stats, dir, pid)
			# M4：裁决命中点火花（host/OFFLINE；client 由 EVT_ENEMY_HIT 闪白承担，不重复生成）
			FxBurst.spawn_hit_spark(end)
			# P1-11 伤害数字：白=普通 / 黄=暴击 / 紫=弱点（host/单机）
			if dmg_result != null and dmg_result.damage > 0.0:
				var dmg_color := Color.WHITE
				if dmg_result.critical:
					dmg_color = Color(1.0, 0.85, 0.3)
				elif hit_enemy.controller != null and hit_enemy.controller.data != null \
						and hit_enemy.controller.data.has_weak_point:
					dmg_color = Color(0.85, 0.45, 1.0)
				FxBurst.spawn_damage_number(
					hit_enemy.global_position + Vector2(0, -22),
					str(roundi(dmg_result.damage)), dmg_color)
			# 受击反馈中继（host → client 镜像闪白）
			if Net.is_host():
				Net.send_event(NetCodec.EVT_ENEMY_HIT, {
					NetCodec.KEY_ENEMY_ID: hit_enemy.net_id,
				})
		hit_points.append(NetCodec.vec_to_arr(end))
		view.show_tracer(origin, dir, end)
	# 中继：命中点随开火事件（client tracer 画到 host 裁决的命中点）
	if Net.is_host():
		Net.send_event(NetCodec.EVT_SHOT_FIRED, {
			NetCodec.KEY_PLAYER_ID: pid,
			NetCodec.KEY_MODEL_LOCATION: event.model_location,
			NetCodec.KEY_AIM_DIRECTION: NetCodec.vec_to_arr(event.aim_direction),
			NetCodec.KEY_HIT_POINTS: hit_points,
		})

func _relay_ammo_changed(event: AmmoChangedEvent) -> void:
	_relay(NetCodec.EVT_AMMO_CHANGED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_AMMO_TYPE: event.ammo_type,
		NetCodec.KEY_MAG: event.mag,
		NetCodec.KEY_RESERVE: event.reserve,
	})

func _relay_weapon_switched(event: WeaponSwitchedEvent) -> void:
	_relay(NetCodec.EVT_WEAPON_SWITCHED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_SLOT_INDEX: event.slot_index,
		NetCodec.KEY_SLOT_TYPE: event.slot_type,
		NetCodec.KEY_MODEL_LOCATION: event.model_location,
	})

func _relay_weapon_switch_started(event: WeaponSwitchStartedEvent) -> void:
	_relay(NetCodec.EVT_WEAPON_SWITCH_STARTED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_SLOT_INDEX: event.target_slot_index,
		NetCodec.KEY_CD: event.switch_cd,
	})

func _relay_weapon_switch_rejected(event: WeaponSwitchRejectedEvent) -> void:
	_relay(NetCodec.EVT_WEAPON_SWITCH_REJECTED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_SLOT_INDEX: event.slot_index,
		NetCodec.KEY_REASON: String(event.reason),
	})

func _relay_reload_started(event: ReloadStartedEvent) -> void:
	_relay(NetCodec.EVT_RELOAD_STARTED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_DURATION: event.duration,
		NetCodec.KEY_AMMO_TYPE: event.ammo_type,
	})

func _relay_attachment_equipped(event: AttachmentEquippedEvent) -> void:
	_relay(NetCodec.EVT_ATTACHMENT_EQUIPPED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_SLOT_INDEX: event.slot_index,
		NetCodec.KEY_ATTACHMENT_LOCATION: event.attachment_location,
	})

func _relay_attachment_unequipped(event: AttachmentUnequippedEvent) -> void:
	_relay(NetCodec.EVT_ATTACHMENT_UNEQUIPPED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_SLOT_INDEX: event.slot_index,
		NetCodec.KEY_ATTACHMENT_LOCATION: event.attachment_location,
	})

func _relay_run_state(event: RunStateChangedEvent) -> void:
	_relay(NetCodec.EVT_RUN_STATE, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_CREDITS: event.credits,
		NetCodec.KEY_MATERIAL: event.material,
		NetCodec.KEY_RESERVE_COUNT: event.reserve,
	})

func _relay_wave_warning(event: WaveWarningEvent) -> void:
	_relay(NetCodec.EVT_WAVE_WARNING, {
		NetCodec.KEY_WAVE_INDEX: event.wave_index,
		NetCodec.KEY_WAVE_TOTAL: event.wave_total,
		NetCodec.KEY_TIERS: event.direction_tiers,
		NetCodec.KEY_THREAT_TIER: event.threat_tier,
		NetCodec.KEY_HAS_ELITE: event.has_elite,
		NetCodec.KEY_CHAPTER_INDEX: event.chapter_index,
		NetCodec.KEY_CHAPTER_NAME: event.chapter_name,
		NetCodec.KEY_WAVE_IN_CHAPTER: event.wave_in_chapter,
		NetCodec.KEY_IS_BOSS: event.is_boss_wave,
	})

func _relay_wave_started(event: WaveStartedEvent) -> void:
	_relay(NetCodec.EVT_WAVE_STARTED, {
		NetCodec.KEY_WAVE_INDEX: event.wave_index,
		NetCodec.KEY_WAVE_TOTAL: event.wave_total,
		NetCodec.KEY_CHAPTER_INDEX: event.chapter_index,
		NetCodec.KEY_IS_BOSS: event.is_boss_wave,
	})

func _relay_wave_cleared(event: WaveClearedEvent) -> void:
	_relay(NetCodec.EVT_WAVE_CLEARED, {
		NetCodec.KEY_WAVE_INDEX: event.wave_index,
		NetCodec.KEY_CHAPTER_INDEX: event.chapter_index,
		NetCodec.KEY_IS_BOSS: event.is_boss_wave,
	})

func _relay_barricade_placed(event: BarricadePlacedEvent) -> void:
	_relay(NetCodec.EVT_BARRICADE_PLACED, {
		NetCodec.KEY_LOCATION: event.facility_location,
		NetCodec.KEY_POS: NetCodec.vec_to_arr(event.position),
	})

func _relay_barricade_damaged(event: BarricadeDamagedEvent) -> void:
	_relay(NetCodec.EVT_BARRICADE_DAMAGED, {
		NetCodec.KEY_LOCATION: event.facility_location,
		NetCodec.KEY_DURABILITY: event.durability,
		NetCodec.KEY_MAX_DURABILITY: event.max_durability,
	})

func _relay_barricade_destroyed(event: BarricadeDestroyedEvent) -> void:
	_relay(NetCodec.EVT_BARRICADE_DESTROYED, {
		NetCodec.KEY_LOCATION: event.facility_location,
	})

## M5a：敌人远程攻击/范围伤害中继（host → client 视觉弹体/爆炸）
func _relay_enemy_ranged_attack(event: EnemyRangedAttackEvent) -> void:
	_relay(NetCodec.EVT_ENEMY_RANGED_ATTACK, {
		NetCodec.KEY_ENEMY_LOCATION: event.enemy_location,
		NetCodec.KEY_POS: NetCodec.vec_to_arr(event.origin),
		NetCodec.KEY_TARGET_POS: NetCodec.vec_to_arr(event.target_position),
		NetCodec.KEY_DAMAGE: event.damage,
		NetCodec.KEY_PROJECTILE_KIND: event.projectile_kind,
		NetCodec.KEY_SPEED: event.speed,
	})

func _relay_enemy_aoe(event: EnemyAoEEvent) -> void:
	_relay(NetCodec.EVT_ENEMY_AOE, {
		NetCodec.KEY_ENEMY_LOCATION: event.enemy_location,
		NetCodec.KEY_POS: NetCodec.vec_to_arr(event.position),
		NetCodec.KEY_RADIUS: event.radius,
		NetCodec.KEY_DAMAGE: event.damage,
	})

func _relay_turret_fired(event: TurretFiredEvent) -> void:
	_relay(NetCodec.EVT_TURRET_FIRED, {
		NetCodec.KEY_LOCATION: event.facility_location,
		NetCodec.KEY_POS: NetCodec.vec_to_arr(event.origin),
		NetCodec.KEY_TARGET_POS: NetCodec.vec_to_arr(event.target_position),
		NetCodec.KEY_ENEMY_ID: event.target_net_id,
		NetCodec.KEY_DAMAGE: event.damage,
	})

# ─── P1 街机化中继（host → client 镜像/HUD） ───

func _relay_score_changed(event: ScoreChangedEvent) -> void:
	_relay(NetCodec.EVT_SCORE_CHANGED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_SCORE: event.score,
		NetCodec.KEY_COMBO: event.combo,
		NetCodec.KEY_MULTIPLIER: event.multiplier,
	})

func _relay_power_up_pickup(event: PowerUpPickupEvent) -> void:
	_relay(NetCodec.EVT_POWERUP_PICKUP, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_POWER_ID: event.power_id,
		NetCodec.KEY_DURATION: event.duration,
		NetCodec.KEY_POS: NetCodec.vec_to_arr(event.position),
	})

func _relay_power_up_expired(event: PowerUpExpiredEvent) -> void:
	_relay(NetCodec.EVT_POWERUP_EXPIRED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_POWER_ID: event.power_id,
	})

func _relay_enemy_health(event: EnemyHealthChangedEvent) -> void:
	_relay(NetCodec.EVT_ENEMY_HEALTH, {
		NetCodec.KEY_ENEMY_ID: event.enemy_id,
		NetCodec.KEY_DATA_ID: event.data_id,
		NetCodec.KEY_CURRENT: event.current,
		NetCodec.KEY_MAX: event.max_value,
		NetCodec.KEY_IS_ELITE: event.is_elite,
		NetCodec.KEY_POS: NetCodec.vec_to_arr(event.position),
	})

# ─── 多人 client：快照应用 / 事件路由（镜像） ───

func _on_net_state(data: Dictionary) -> void:
	if not _client_started:
		_client_started = true
	if _smoke_mode:
		_smoke_stats["syncs"] = int(_smoke_stats.get("syncs", 0)) + 1
	# run 状态（M3 问题 4：per-player 资源表；只对本地玩家发布事件 → HUD 资源行）
	var run: Dictionary = data.get(NetCodec.SNAP_RUN, {})
	var resources: Dictionary = run.get(NetCodec.RUN_RESOURCES, {})
	if resources != _last_run_state:
		_last_run_state = resources
		for pid_str in resources.keys():
			var pid := int(pid_str)
			if pid < 0 or pid >= run_states.size():
				continue
			var rdata: Dictionary = resources[pid_str]
			var rs := run_states[pid]
			rs.credits = int(rdata.get(NetCodec.RUN_CREDITS, 0))
			rs.material = int(rdata.get(NetCodec.RUN_MATERIAL, 0))
			rs.reserve = int(rdata.get(NetCodec.RUN_RESERVE, 0))
			# 背包镜像（per-player）
			var bag: Array = rdata.get(NetCodec.RUN_BAG, [])
			_client_bags[pid].clear()
			for loc in bag:
				_client_bags[pid].append(str(loc))
			# 军械库镜像（M5b）
			var owned_models: Array = rdata.get(NetCodec.RUN_ARSENAL, [])
			if pid < arsenals.size() and pid < _client_arsenals.size():
				arsenals[pid].owned_models.clear()
				_client_arsenals[pid].clear()
				for loc in owned_models:
					arsenals[pid].owned_models.append(str(loc))
					_client_arsenals[pid].append(str(loc))
		EventBus.publish(RunStateChangedEvent.new(
			run_state.credits, run_state.material, run_state.reserve,
			_local_player_id))
	# 基地（去重发布 BaseDurabilityChangedEvent）
	var base: Dictionary = data.get(NetCodec.SNAP_BASE, {})
	if base != _last_base:
		_last_base = base
		base_core.durability = float(base.get(NetCodec.BASE_DURABILITY, 0.0))
		base_core.max_durability = float(base.get(NetCodec.BASE_MAX, 0.0))
		EventBus.publish(BaseDurabilityChangedEvent.new(
			base_core.durability, base_core.max_durability))
	# 玩家（快照置位 + 去重发布健康事件）
	var players_data: Dictionary = data.get(NetCodec.SNAP_PLAYERS, {})
	for pid_str in players_data.keys():
		_apply_player_snapshot(int(pid_str), players_data[pid_str])

## M3 问题 3：敌人快照独立通道（10Hz；与玩家主快照解耦）
func _on_net_enemies(enemies: Dictionary) -> void:
	if _smoke_mode:
		_smoke_stats["syncs_enemies"] = int(_smoke_stats.get("syncs_enemies", 0)) + 1
	_apply_enemies_snapshot(enemies)

func _apply_player_snapshot(pid: int, pdata: Dictionary) -> void:
	if pid < 0 or pid >= player_views.size():
		return
	var view := player_views[pid]
	var pos := NetCodec.arr_to_vec(pdata.get(NetCodec.PLAYER_POS, [0.0, 0.0]))
	var aim := float(pdata.get(NetCodec.PLAYER_AIM, 0.0))
	if view.position_mode == PlayerView.PositionMode.SNAPSHOT:
		# 远端镜像：双缓冲线性插值
		view.apply_snapshot(pos, aim)
	else:
		# 本地玩家（M3 本地预测 SIMULATED）：快照校正（偏差大才拉回）；aim 本地实时不覆盖
		view.apply_prediction_correction(pos)
	var hp := float(pdata.get(NetCodec.PLAYER_HP, 0.0))
	var max_hp := float(pdata.get(NetCodec.PLAYER_MAX_HP, 100.0))
	players[pid].health = hp
	players[pid].max_health = max_hp
	# M3 本地预测：同步后端状态（DEAD/REVIVING 等）——本地模拟依赖 is_incapacitated 停止移动
	players[pid].state = int(pdata.get(NetCodec.PLAYER_STATE, players[pid].state))
	var key := str(pid)
	var last: Dictionary = _last_players.get(key, {})
	if last.get(NetCodec.PLAYER_HP, -1.0) != hp or last.get(NetCodec.PLAYER_MAX_HP, -1.0) != max_hp:
		EventBus.publish(PlayerHealthChangedEvent.new(hp, max_hp, pid))
	_last_players[key] = {
		NetCodec.PLAYER_HP: hp,
		NetCodec.PLAYER_MAX_HP: max_hp,
	}

func _apply_enemies_snapshot(enemies: Dictionary) -> void:
	var seen: Dictionary = {}
	for id_str in enemies.keys():
		var id := int(id_str)
		var edata: Dictionary = enemies[id_str]
		var state := int(edata.get(NetCodec.ENEMY_STATE, NetCodec.ENEMY_STATE_ALIVE))
		var mirror: EnemyView = _mirror_enemies.get(id)
		if mirror == null or not is_instance_valid(mirror):
			var enemy_data: EnemyData = ContentBootstrap.get_entry(
				Bulwark.REG_ENEMY, str(edata.get(NetCodec.ENEMY_LOCATION, "")))
			if enemy_data == null:
				continue
			mirror = ENEMY_SCENE.instantiate() as EnemyView
			enemies_root.add_child(mirror)
			mirror.setup_mirror(enemy_data)
			_mirror_enemies[id] = mirror
		if state == NetCodec.ENEMY_STATE_DEAD:
			mirror.apply_dead_snapshot()
		else:
			var pos := NetCodec.arr_to_vec(edata.get(NetCodec.ENEMY_POS, [0.0, 0.0]))
			# M3 问题 3：位置未变跳过 set（20Hz 快照多数帧位置相同，省插值/置位开销）
			var last: Variant = _mirror_last_pos.get(id)
			if last == null or (last as Vector2) != pos:
				mirror.apply_snapshot(pos)
				_mirror_last_pos[id] = pos
		seen[id] = true
	if _smoke_mode:
		_smoke_stats["enemy_peak"] = maxi(
			int(_smoke_stats.get("enemy_peak", 0)), seen.size())
	for id in _mirror_enemies.keys():
		if not seen.has(id):
			var m: EnemyView = _mirror_enemies[id]
			_mirror_enemies.erase(id)
			_mirror_last_pos.erase(id)
			if is_instance_valid(m) and not m.has_death_visual():
				m.queue_free()

func _on_net_event(event_name: StringName, payload: Dictionary) -> void:
	match event_name:
		NetCodec.EVT_WAVE_WARNING:
			EventBus.publish(WaveWarningEvent.new(
				int(payload.get(NetCodec.KEY_WAVE_INDEX, 0)),
				int(payload.get(NetCodec.KEY_WAVE_TOTAL, 0)),
				null,
				payload.get(NetCodec.KEY_TIERS, {}),
				str(payload.get(NetCodec.KEY_THREAT_TIER, "")),
				bool(payload.get(NetCodec.KEY_HAS_ELITE, false)),
				int(payload.get(NetCodec.KEY_CHAPTER_INDEX, -1)),
				str(payload.get(NetCodec.KEY_CHAPTER_NAME, "")),
				int(payload.get(NetCodec.KEY_WAVE_IN_CHAPTER, -1)),
				bool(payload.get(NetCodec.KEY_IS_BOSS, false))))
		NetCodec.EVT_WAVE_STARTED:
			EventBus.publish(WaveStartedEvent.new(
				int(payload.get(NetCodec.KEY_WAVE_INDEX, 0)),
				int(payload.get(NetCodec.KEY_WAVE_TOTAL, 0)),
				int(payload.get(NetCodec.KEY_CHAPTER_INDEX, -1)),
				bool(payload.get(NetCodec.KEY_IS_BOSS, false))))
		NetCodec.EVT_WAVE_CLEARED:
			EventBus.publish(WaveClearedEvent.new(
				int(payload.get(NetCodec.KEY_WAVE_INDEX, 0)),
				int(payload.get(NetCodec.KEY_CHAPTER_INDEX, -1)),
				bool(payload.get(NetCodec.KEY_IS_BOSS, false))))
		NetCodec.EVT_PLAYER_HEALTH:
			EventBus.publish(PlayerHealthChangedEvent.new(
				float(payload.get(NetCodec.KEY_CURRENT, 0.0)),
				float(payload.get(NetCodec.KEY_MAX, 100.0)),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_PLAYER_DIED:
			EventBus.publish(PlayerDiedEvent.new(int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_REVIVE_STARTED:
			EventBus.publish(ReviveStartedEvent.new(
				float(payload.get(NetCodec.KEY_CD, 4.0)),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_REVIVED:
			EventBus.publish(RevivedEvent.new(0.0, 0.0, int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_SHOT_FIRED:
			# M3 方案 B：client tracer 由 host 裁决的命中点驱动（不再本地发射线），
			# 表现与裁决一致；开火事件照发（视图后坐/枪口焰即时反馈）
			var shot_pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
			if shot_pid == _local_player_id and shot_pid < player_views.size() \
					and is_instance_valid(player_views[shot_pid]):
				var aim := NetCodec.arr_to_vec(payload.get(NetCodec.KEY_AIM_DIRECTION, [1.0, 0.0]))
				var hit_points: Array = payload.get(NetCodec.KEY_HIT_POINTS, [])
				var view := player_views[shot_pid]
				var origin := view.global_position
				for hp_v in hit_points:
					view.show_tracer(origin, aim, NetCodec.arr_to_vec(hp_v))
			EventBus.publish(ShotFiredEvent.new(
				str(payload.get(NetCodec.KEY_MODEL_LOCATION, "")),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_AIM_DIRECTION, [1.0, 0.0])),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_ENEMY_HIT:
			# M3 方案 B：host 命中敌人 → client 镜像闪白（受击反馈跨端）
			var hit_enemy: EnemyView = _mirror_enemies.get(
				int(payload.get(NetCodec.KEY_ENEMY_ID, -1)))
			if hit_enemy != null and is_instance_valid(hit_enemy):
				hit_enemy.flash_hit()
		NetCodec.EVT_AMMO_CHANGED:
			_apply_ammo_event(payload)
		NetCodec.EVT_WEAPON_SWITCHED:
			_apply_weapon_switched(payload)
		NetCodec.EVT_WEAPON_SWITCH_STARTED:
			EventBus.publish(WeaponSwitchStartedEvent.new(
				int(payload.get(NetCodec.KEY_SLOT_INDEX, 0)),
				float(payload.get(NetCodec.KEY_CD, 0.0)),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_WEAPON_SWITCH_REJECTED:
			EventBus.publish(WeaponSwitchRejectedEvent.new(
				int(payload.get(NetCodec.KEY_SLOT_INDEX, 0)),
				StringName(str(payload.get(NetCodec.KEY_REASON, ""))),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_RELOAD_STARTED:
			EventBus.publish(ReloadStartedEvent.new(
				float(payload.get(NetCodec.KEY_DURATION, 0.0)),
				int(payload.get(NetCodec.KEY_AMMO_TYPE, 0)),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_ATTACHMENT_EQUIPPED:
			_apply_attachment_equipped(payload)
		NetCodec.EVT_ATTACHMENT_UNEQUIPPED:
			_apply_attachment_unequipped(payload)
		NetCodec.EVT_BAG_CHANGED:
			# M3 问题 4：per-player 背包镜像（payload 携带 player_id）
			var bag_pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
			if bag_pid >= 0 and bag_pid < _client_bags.size():
				var bag: Array = payload.get(NetCodec.KEY_BAG, [])
				_client_bags[bag_pid].clear()
				for loc in bag:
					_client_bags[bag_pid].append(str(loc))
		NetCodec.EVT_SHOP_OFFERS:
			_apply_shop_offers(payload)
		NetCodec.EVT_SHOP_PURCHASED:
			# M3 问题 4：本地购买计数镜像（offers 视角：价格递增/已购自行计算）
			var bought_location := str(payload.get(NetCodec.KEY_LOCATION, ""))
			var bought_item := _get_shop_item(bought_location)
			if bought_item != null:
				_client_purchase_counts[bought_item.id] = \
					int(_client_purchase_counts.get(bought_item.id, 0)) + 1
			EventBus.publish(ShopPurchasedEvent.new(
				bought_location,
				int(payload.get(NetCodec.KEY_OFFER_PRICE, 0))))
		NetCodec.EVT_SHOP_PURCHASE_REJECTED:
			EventBus.publish(ShopPurchaseRejectedEvent.new(
				str(payload.get(NetCodec.KEY_LOCATION, "")),
				int(payload.get(NetCodec.KEY_REASON, 0))))
		NetCodec.EVT_RUN_STATE:
			# M3 问题 4：per-player 资源事件（只对本地玩家发布 → HUD 按 player_id 过滤）
			var rs_pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
			if rs_pid >= 0 and rs_pid < run_states.size():
				var rs := run_states[rs_pid]
				rs.credits = int(payload.get(NetCodec.KEY_CREDITS, 0))
				rs.material = int(payload.get(NetCodec.KEY_MATERIAL, 0))
				rs.reserve = int(payload.get(NetCodec.KEY_RESERVE_COUNT, 0))
				if rs_pid == _local_player_id:
					EventBus.publish(RunStateChangedEvent.new(
						rs.credits, rs.material, rs.reserve, rs_pid))
		NetCodec.EVT_BASE_DURABILITY:
			base_core.durability = float(payload.get(NetCodec.KEY_DURABILITY, 0.0))
			base_core.max_durability = float(payload.get(NetCodec.KEY_MAX_DURABILITY, 0.0))
			EventBus.publish(BaseDurabilityChangedEvent.new(
				base_core.durability, base_core.max_durability))
		NetCodec.EVT_BARRICADE_PLACED:
			_apply_barricade_placed(payload)
		NetCodec.EVT_BARRICADE_DAMAGED:
			EventBus.publish(BarricadeDamagedEvent.new(
				str(payload.get(NetCodec.KEY_LOCATION, "")),
				float(payload.get(NetCodec.KEY_DURABILITY, 0.0)),
				float(payload.get(NetCodec.KEY_MAX_DURABILITY, 0.0))))
		NetCodec.EVT_BARRICADE_DESTROYED:
			EventBus.publish(BarricadeDestroyedEvent.new(
				str(payload.get(NetCodec.KEY_LOCATION, ""))))
		NetCodec.EVT_ENEMY_RANGED_ATTACK:
			var ranged := EnemyRangedAttackEvent.new(
				str(payload.get(NetCodec.KEY_ENEMY_LOCATION, "")),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0])),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_TARGET_POS, [0.0, 0.0])),
				float(payload.get(NetCodec.KEY_DAMAGE, 0.0)),
				str(payload.get(NetCodec.KEY_PROJECTILE_KIND, "spit")),
				float(payload.get(NetCodec.KEY_SPEED, 600.0)))
			EventBus.publish(ranged)
			_spawn_enemy_projectile(ranged)
		NetCodec.EVT_ENEMY_AOE:
			var aoe := EnemyAoEEvent.new(
				str(payload.get(NetCodec.KEY_ENEMY_LOCATION, "")),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0])),
				float(payload.get(NetCodec.KEY_RADIUS, 0.0)),
				float(payload.get(NetCodec.KEY_DAMAGE, 0.0)))
			EventBus.publish(aoe)
			_spawn_enemy_aoe_visual(aoe)
		NetCodec.EVT_TURRET_FIRED:
			var turret_event := TurretFiredEvent.new(
				str(payload.get(NetCodec.KEY_LOCATION, "")),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0])),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_TARGET_POS, [0.0, 0.0])),
				int(payload.get(NetCodec.KEY_ENEMY_ID, -1)),
				float(payload.get(NetCodec.KEY_DAMAGE, 0.0)))
			EventBus.publish(turret_event)
			_spawn_turret_tracer(turret_event)
		NetCodec.EVT_ARSENAL_CHANGED:
			var arsenal_pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
			if arsenal_pid >= 0 and arsenal_pid < arsenals.size() \
					and arsenal_pid < _client_arsenals.size():
				arsenals[arsenal_pid].owned_models.clear()
				_client_arsenals[arsenal_pid].clear()
				for loc in payload.get(NetCodec.KEY_ARSENAL, []):
					arsenals[arsenal_pid].owned_models.append(str(loc))
					_client_arsenals[arsenal_pid].append(str(loc))
		NetCodec.EVT_TURRET_PLACED:
			_apply_turret_placed(payload)
		NetCodec.EVT_SCORE_CHANGED:
			EventBus.publish(ScoreChangedEvent.new(
				int(payload.get(NetCodec.KEY_SCORE, 0)),
				int(payload.get(NetCodec.KEY_COMBO, 0)),
				float(payload.get(NetCodec.KEY_MULTIPLIER, 1.0)),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_POWERUP_PICKUP:
			# client 镜像：HUD buff 计时条/音效（效果由 host 权威应用）
			EventBus.publish(PowerUpPickupEvent.new(
				str(payload.get(NetCodec.KEY_POWER_ID, "")),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0)),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0])),
				float(payload.get(NetCodec.KEY_DURATION, 0.0))))
		NetCodec.EVT_POWERUP_EXPIRED:
			EventBus.publish(PowerUpExpiredEvent.new(
				str(payload.get(NetCodec.KEY_POWER_ID, "")),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
		NetCodec.EVT_ENEMY_HEALTH:
			EventBus.publish(EnemyHealthChangedEvent.new(
				int(payload.get(NetCodec.KEY_ENEMY_ID, -1)),
				str(payload.get(NetCodec.KEY_DATA_ID, "")),
				float(payload.get(NetCodec.KEY_CURRENT, 0.0)),
				float(payload.get(NetCodec.KEY_MAX, 0.0)),
				bool(payload.get(NetCodec.KEY_IS_ELITE, false)),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0]))))
		NetCodec.EVT_UI_STATE:
			_apply_ui_state(payload)

## client 弹药/武器事件：更新镜像槽位 + 按 player_id 发布（HUD 只显示本地玩家）
func _apply_ammo_event(payload: Dictionary) -> void:
	var pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
	if pid < weapon_slots_list.size():
		var slots := weapon_slots_list[pid]
		slots.get_current_slot().mag = int(payload.get(NetCodec.KEY_MAG, 0))
		ammo_systems[pid].set_count(
			int(payload.get(NetCodec.KEY_AMMO_TYPE, 0)), int(payload.get(NetCodec.KEY_RESERVE, 0)))
	EventBus.publish(AmmoChangedEvent.new(
		int(payload.get(NetCodec.KEY_AMMO_TYPE, 0)),
		int(payload.get(NetCodec.KEY_MAG, 0)),
		int(payload.get(NetCodec.KEY_RESERVE, 0)),
		pid))

func _apply_weapon_switched(payload: Dictionary) -> void:
	var pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
	var slot_index := int(payload.get(NetCodec.KEY_SLOT_INDEX, 0))
	var model_location := str(payload.get(NetCodec.KEY_MODEL_LOCATION, ""))
	var mirrored := false
	if pid < weapon_slots_list.size():
		weapon_slots_list[pid].current_index = slot_index
		# M5b 改枪台：host 换型号后 client 镜像槽位同步（类型 + 模型一起切换）；
		# set_model 内部已广播 WeaponSwitchedEvent，成功时不再重复发布
		var model := _get_model(model_location)
		if model != null:
			var type_data := _get_weapon_type(model.type_id)
			if type_data != null:
				mirrored = weapon_slots_list[pid].set_model(slot_index, model, type_data)
	if not mirrored:
		EventBus.publish(WeaponSwitchedEvent.new(
			slot_index,
			int(payload.get(NetCodec.KEY_SLOT_TYPE, 0)),
			model_location,
			pid))

func _apply_attachment_equipped(payload: Dictionary) -> void:
	var pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
	var attachment := _get_attachment(str(payload.get(NetCodec.KEY_ATTACHMENT_LOCATION, "")))
	if pid < weapon_slots_list.size() and attachment != null:
		weapon_slots_list[pid].equip_attachment(
			int(payload.get(NetCodec.KEY_SLOT_INDEX, 0)), attachment)
	EventBus.publish(AttachmentEquippedEvent.new(
		int(payload.get(NetCodec.KEY_SLOT_INDEX, 0)),
		str(payload.get(NetCodec.KEY_ATTACHMENT_LOCATION, "")),
		pid))

func _apply_attachment_unequipped(payload: Dictionary) -> void:
	var pid := int(payload.get(NetCodec.KEY_PLAYER_ID, 0))
	# 事件不含 attachment_slot，从配件数据反推槽位（AttachmentData.slot）
	var attachment := _get_attachment(str(payload.get(NetCodec.KEY_ATTACHMENT_LOCATION, "")))
	if pid < weapon_slots_list.size() and attachment != null:
		weapon_slots_list[pid].unequip_attachment(
			int(payload.get(NetCodec.KEY_SLOT_INDEX, 0)), attachment.slot)
	EventBus.publish(AttachmentUnequippedEvent.new(
		int(payload.get(NetCodec.KEY_SLOT_INDEX, 0)),
		str(payload.get(NetCodec.KEY_ATTACHMENT_LOCATION, "")),
		pid))

## M3 问题 4：商店 offers 镜像——广播只带商品 location，本端用本地镜像
## purchase_counts + credits 自行计算价格/已购/可负担（per-player 视角，D-M3-4）
func _apply_shop_offers(payload: Dictionary) -> void:
	var offers: Array = []
	for o in payload.get(NetCodec.KEY_OFFERS, []):
		if not (o is Dictionary):
			continue
		var od: Dictionary = o
		var item := _get_shop_item(str(od.get(NetCodec.KEY_OFFER_LOCATION, "")))
		if item == null:
			continue
		var owned := int(_client_purchase_counts.get(item.id, 0))
		var price := maxi(1, roundi(item.price_with_rarity()
			* pow(ShopSystem.PRICE_ESCALATION, owned)))
		offers.append(ShopRefreshedEvent.Offer.new(
			item, price, owned, run_state.credits >= price))
	shop_system.offers = offers
	EventBus.publish(ShopRefreshedEvent.new(offers))

func _get_shop_item(location: String) -> ShopItemData:
	var registry := RegistryManager.get_registry(Bulwark.REG_SHOP_ITEM)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as ShopItemData

## client 路障镜像（事件驱动：placed 创建 / damaged 闪白 / destroyed 移除；位置明文）
## M3 修复：镜像 controller 必须用 host 分配的 instance_id（从 location#id 解析），
## 否则 damaged/destroyed 事件会被 BarricadeView._on_damaged/_on_destroyed 的
## location 校验丢弃 → 镜像路障不闪白、被击穿后仍显示
func _apply_barricade_placed(payload: Dictionary) -> void:
	var facility: DefenseFacilityData = ContentBootstrap.get_entry(
		Bulwark.REG_FACILITY, Bulwark.loc(Bulwark.FACILITY_BARRICADE).to_string())
	if facility == null:
		return
	var location := str(payload.get(NetCodec.KEY_LOCATION, ""))
	var instance_id := 0
	var hash_idx := location.rfind("#")
	if hash_idx >= 0:
		instance_id = int(location.substr(hash_idx + 1))
	var controller := BarricadeController.new(facility, instance_id)
	var view: BarricadeView = BARRICADE_SCENE.instantiate() as BarricadeView
	get_parent().add_child(view)
	view.global_position = NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0]))
	view.setup(controller)
	view.align_to_arc(base_node.global_position)
	# 镜像路障无后端簿记；直接广播事件让视图完成后续（受击闪白由 damaged 事件驱动）
	EventBus.publish(BarricadePlacedEvent.new(
		str(payload.get(NetCodec.KEY_LOCATION, "")), view.global_position))

## client 炮塔镜像（事件驱动：host 放置 → 客户端创建同一 instance 的炮塔；
## 受损/修复/销毁复用 BarricadeDamaged/Destroyed 事件，TurretView 订阅后与 host 一致）
func _apply_turret_placed(payload: Dictionary) -> void:
	var facility: DefenseFacilityData = ContentBootstrap.get_entry(
		Bulwark.REG_FACILITY, Bulwark.loc(Bulwark.FACILITY_TURRET).to_string())
	if facility == null:
		return
	var location := str(payload.get(NetCodec.KEY_LOCATION, ""))
	var instance_id := 0
	var hash_idx := location.rfind("#")
	if hash_idx >= 0:
		instance_id = int(location.substr(hash_idx + 1))
	var controller := FacilityController.new(facility, instance_id)
	var view: Node2D = TURRET_SCENE.instantiate() as Node2D
	add_child(view)
	view.global_position = NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0]))
	view.setup(controller)

## client UI 状态跟随（不暂停树；仅开关面板）
## M3 问题 2：暂停面板开关由本地请求状态驱动（_toggle_pause_local），
## ui_state 仅驱动：正式暂停（全队请求）时确保面板打开 + 汇总提示刷新；
## paused=false 不主动关闭暂停面板（本玩家请求中等待队友时保持打开）
func _apply_ui_state(payload: Dictionary) -> void:
	var result: Dictionary = payload.get(NetCodec.KEY_RESULT, {})
	if not result.is_empty():
		_run_finished = true
		if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
			UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
		if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)):
			UIManager.close_panel(Bulwark.loc(Bulwark.UI_PAUSE))
		if not UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_RESULT)):
			UIManager.open_panel(Bulwark.loc(Bulwark.UI_RESULT), result)
		_update_pause_hint([])
		return
	var shop_open := bool(payload.get(NetCodec.KEY_SHOP_OPEN, false))
	var paused := bool(payload.get(NetCodec.KEY_PAUSED, false))
	if shop_open:
		if not UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
			UIManager.open_panel(Bulwark.loc(Bulwark.UI_SHOP), {
				"shop": shop_system,
				"weapon_slots": weapon_slots,
				"run_state": run_state,
				"bag": _client_bags[_local_player_id] if _local_player_id < _client_bags.size() else [],
				"arsenal": arsenal,
				"effect_handler": Callable(),
			})
		_update_pause_hint([])
		return
	if paused:
		if not UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)):
			UIManager.open_panel(Bulwark.loc(Bulwark.UI_PAUSE))
		_update_pause_hint(payload.get(NetCodec.KEY_PAUSE_REQUESTS, []))
		return
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	_update_pause_hint(payload.get(NetCodec.KEY_PAUSE_REQUESTS, []))
