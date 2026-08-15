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

## 快照频率（M2：20Hz 全量快照；带宽分级/增量留 M6）
const SNAPSHOT_INTERVAL := 0.05

@onready var player_node: CharacterBody2D = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var base_node: Node2D = $Base

var ammo_system: AmmoSystem
var weapon_slots: WeaponSlots
var player_controller: PlayerController
var base_core: BaseCore
var wave_director: WaveDirector
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

## 路障（后端控制器 + 前端视图；instance_id 递增分配）
var barricades: Array[BarricadeController] = []
var barricade_views: Array[BarricadeView] = []
var _barricade_seq := 1
## 配件背包（购买获得的配件 ResourceLocation 列表；装配后移除）
var attachment_bag: Array[String] = []

## GUIDE 动作实例（与启用上下文同实例，轮询式读取）
var actions: Dictionary = {}  # StringName -> GUIDEAction

var _run_finished := false
var _snapshot_timer := 0.0
var _snapshot_tick := 0
## 敌人网络 id（host 分配，快照/镜像同步用）
var _enemy_seq := 1
## 本进程负责的玩家 id（单机/OFFLINE = 0）
var _local_player_id := 0

## client 镜像簿记（去重发布 / 敌人镜像表）
var _last_run_state: Dictionary = {}
var _last_base: Dictionary = {}
var _last_players: Dictionary = {}
var _mirror_enemies: Dictionary = {}  # net_id(int) -> EnemyView
var _client_bag: Array[String] = []
var _client_started := false
## 结算结果（跨端 ui_state 携带；host 写入）
var _result_data: Dictionary = {}

func _ready() -> void:
	# 暂停菜单/结算面板需要在本节点暂停期间仍响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	ContentBootstrap.register_all()
	_build_navigation()
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
	if Net.is_host():
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0:
			_snapshot_timer = SNAPSHOT_INTERVAL
			_send_snapshot()

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
			Net.send_intent(&"toggle_pause")
		else:
			_toggle_pause()
	var interact_action: GUIDEAction = actions.get(&"interact")
	if interact_action != null and interact_action.is_triggered():
		if Net.is_client():
			Net.send_intent(&"place_barricade")
		else:
			_try_place_barricade()

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

	# ── 资源与经济（共享单一实例：货币/建材/储备/武器全局强化） ──
	run_state = RunState.new()
	run_state.add_credits(START_CREDITS)
	run_state.add_material(START_MATERIAL)
	run_state.add_reserve(START_RESERVE)

	shop_system = ShopSystem.new(run_state)
	var shop_pool: Array[ShopItemData] = []
	var shop_fixed: Array[ShopItemData] = []
	var shop_reg: ShopItemRegistry = RegistryManager.get_registry(Bulwark.REG_SHOP_ITEM)
	if shop_reg != null:
		for entry: ShopItemData in shop_reg.get_all_entries().values():
			if entry.is_fixed:
				shop_fixed.append(entry)
			else:
				shop_pool.append(entry)
	shop_system.setup(shop_pool, shop_fixed)

	# ── 玩家（M2：HOST 双玩家；OFFLINE 单玩家） ──
	var player_count := 2 if Net.is_host() else 1
	for i in player_count:
		var ammo := AmmoSystem.new()
		ammo.set_count(WeaponTypeData.AmmoType.BULLET, BULLET_RESERVE)
		ammo_systems.append(ammo)

		var slots := WeaponSlots.new(ammo, run_state, i)
		slots.assign_slot(
			WeaponSlots.SLOT_MAIN,
			type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE)),
			model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7)))
		slots.assign_slot(
			WeaponSlots.SLOT_SUB,
			type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_SHOTGUN)),
			model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_JAWBREAKER)))
		slots.assign_slot(
			WeaponSlots.SLOT_PISTOL,
			type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_PISTOL)),
			model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_SENTINEL1)))
		weapon_slots_list.append(slots)

		var attributes := AttributeSet.new()
		attributes.set_base(AttributeSet.MAX_HEALTH, 100.0)
		attributes.set_base(AttributeSet.MOVE_SPEED, 260.0)
		attributes.set_base(AttributeSet.RELOAD_SPEED, 1.0)
		players.append(PlayerController.new(attributes, slots, i))
		revive_systems.append(ReviveSystem.new(run_state))

	# 兼容别名（单机语义 = players[0]；既有测试/代码引用）
	player_controller = players[0]
	weapon_slots = weapon_slots_list[0]
	ammo_system = ammo_systems[0]
	revive_system = revive_systems[0]
	weapon_slots.emit_initial_state()

	base_core = BaseCore.new(BASE_DURABILITY)
	wave_director = WaveDirector.new()
	# 波间商店：清场后等待商店关闭再开下一波（M1）
	wave_director.intermission_waits_for_shop = true

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

func _setup_scene_bindings_host() -> void:
	var view := player_node as PlayerView
	view.setup(player_controller, actions)
	view.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SIMULATED)
	view.set_player_id(0)
	player_views.append(view)
	if Net.is_host() and players.size() > 1:
		var view_b: PlayerView = PLAYER_SCENE.instantiate() as PlayerView
		add_child(view_b)
		view_b.global_position = PLAYER_B_SPAWN
		view_b.setup(players[1], {})
		view_b.set_role(PlayerView.Role.REMOTE, PlayerView.PositionMode.SIMULATED)
		view_b.set_player_id(1)
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
	UIManager.add_overlay(overlay_id, hud)

## 初始状态广播：HUD 挂载晚于后端创建，开局补发当前值避免显示 "--"
## （生命/基地耐久在创建时无事件；弹药/武器初始事件在 HUD 订阅前已发布）
## 多人 host：客户端连上时重发（见 _on_host_peer_connected）
func _broadcast_initial_state() -> void:
	for i in players.size():
		var pc: PlayerController = players[i]
		EventBus.publish(PlayerHealthChangedEvent.new(pc.health, pc.max_health, i))
	EventBus.publish(BaseDurabilityChangedEvent.new(
		base_core.durability, base_core.max_durability))
	EventBus.publish(RunStateChangedEvent.new(
		run_state.credits, run_state.material, run_state.reserve))
	for i in weapon_slots_list.size():
		weapon_slots_list[i].emit_initial_state()

func _subscribe_events() -> void:
	EventBus.subscribe(&"SpawnRequestEvent", _on_spawn_request)
	EventBus.subscribe(&"EnemyDiedEvent", _on_enemy_died)
	EventBus.subscribe(&"EnemyAttackEvent", _on_enemy_attack)
	EventBus.subscribe(&"BaseDestroyedEvent", _on_base_destroyed)
	EventBus.subscribe(&"RunVictoryEvent", _on_run_victory)
	EventBus.subscribe(&"PlayerDiedEvent", _on_player_died)
	EventBus.subscribe(&"RevivedEvent", _on_revived)
	EventBus.subscribe(&"WaveClearedEvent", _on_wave_cleared)
	EventBus.subscribe(&"BarricadeDestroyedEvent", _on_barricade_destroyed)
	if Net.is_host():
		# 跨端事件中继（host → client）
		EventBus.subscribe(&"PlayerHealthChangedEvent", _relay_player_health)
		EventBus.subscribe(&"ReviveStartedEvent", _relay_revive_started)
		EventBus.subscribe(&"ShotFiredEvent", _relay_shot_fired)
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

# ─── 装配（client：只读镜像） ───

## 幂等保护：连接重入/信号重复时不重复装配
var _client_setup_done := false

func _setup_client() -> void:
	if _client_setup_done:
		return
	_client_setup_done = true
	_local_player_id = Net.get_local_player_id()
	# 镜像后端（不跑 tick，纯展示：HUD/商店面板读取）
	run_state = RunState.new()
	shop_system = ShopSystem.new(run_state)
	for i in 2:
		var ammo := AmmoSystem.new()
		ammo.set_count(WeaponTypeData.AmmoType.BULLET, 0)
		ammo_systems.append(ammo)
		var slots := WeaponSlots.new(ammo, run_state, i)
		# 镜像槽位与 host 同构（HUD/商店面板只读展示；数值由 host 事件/快照覆盖）
		var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
		var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
		if type_reg != null and model_reg != null:
			slots.assign_slot(WeaponSlots.SLOT_MAIN,
				type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE)),
				model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7)))
			slots.assign_slot(WeaponSlots.SLOT_SUB,
				type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_SHOTGUN)),
				model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_JAWBREAKER)))
			slots.assign_slot(WeaponSlots.SLOT_PISTOL,
				type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_PISTOL)),
				model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_SENTINEL1)))
		weapon_slots_list.append(slots)
		var attributes := AttributeSet.new()
		attributes.set_base(AttributeSet.MAX_HEALTH, 100.0)
		attributes.set_base(AttributeSet.MOVE_SPEED, 260.0)
		attributes.set_base(AttributeSet.RELOAD_SPEED, 1.0)
		players.append(PlayerController.new(attributes, slots, i))
		revive_systems.append(ReviveSystem.new(run_state))
	player_controller = players[_local_player_id]
	weapon_slots = weapon_slots_list[_local_player_id]
	ammo_system = ammo_systems[_local_player_id]
	revive_system = revive_systems[_local_player_id]
	base_core = BaseCore.new(BASE_DURABILITY)
	wave_director = WaveDirector.new()

	_setup_input()
	_setup_scene_bindings_client()
	_setup_hud(_local_player_id)

	Net.set_state_receiver(_on_net_state)
	Net.set_event_receiver(_on_net_event)

func _setup_scene_bindings_client() -> void:
	# 玩家 A（远端，id 0）= 场景既有节点：纯镜像
	var view_a := player_node as PlayerView
	view_a.setup(players[0], {})
	view_a.set_role(PlayerView.Role.NONE, PlayerView.PositionMode.SNAPSHOT)
	view_a.set_player_id(0)
	player_views.append(view_a)
	# 玩家 B（本地，id 1）= 运行时实例化：本地输入（发 RPC）+ 快照驱动位置
	var view_b: PlayerView = PLAYER_SCENE.instantiate() as PlayerView
	add_child(view_b)
	view_b.global_position = PLAYER_B_SPAWN
	view_b.setup(players[1], actions)
	view_b.set_role(PlayerView.Role.LOCAL, PlayerView.PositionMode.SNAPSHOT)
	view_b.set_player_id(1)
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
		&"purchase":
			_host_purchase(player_id, str(args[0]) if args.size() > 0 else "")
		&"equip":
			if args.size() >= 2:
				_host_equip(player_id, int(args[0]), str(args[1]))
		&"unequip":
			if args.size() >= 2:
				_host_unequip(player_id, int(args[0]), int(args[1]))
		&"shop_continue":
			on_shop_closed()
		&"toggle_pause":
			_toggle_pause()

## 商店购买（host 裁决）：效果作用于购买者玩家（STAT_PLAYER）或共享资源
func _host_purchase(player_id: int, item_location: String) -> void:
	shop_system.try_purchase(item_location,
		func(item: ShopItemData) -> void: _shop_effect_handler(item, player_id))
	if Net.is_host():
		Net.send_event(NetCodec.EVT_SHOP_OFFERS, _shop_offers_payload())
		Net.send_event(NetCodec.EVT_BAG_CHANGED, {NetCodec.KEY_BAG: attachment_bag.duplicate()})

## 装配配件（host 校验：背包有货；旧件替换回背包）
func _host_equip(player_id: int, slot_index: int, attachment_location: String) -> void:
	var attachment := _get_attachment(attachment_location)
	if attachment == null or slot_index < 0 or slot_index >= WeaponSlots.SLOT_COUNT:
		return
	var idx := attachment_bag.find(attachment_location)
	if idx < 0:
		return
	var replaced: AttachmentData = weapon_slots_list[player_id].get_attachment(slot_index, attachment.slot)
	if weapon_slots_list[player_id].equip_attachment(slot_index, attachment):
		attachment_bag.remove_at(idx)
		if replaced != null and replaced.id != attachment.id:
			attachment_bag.append(Bulwark.loc(replaced.id).to_string())
		Net.send_event(NetCodec.EVT_BAG_CHANGED, {NetCodec.KEY_BAG: attachment_bag.duplicate()})

func _host_unequip(player_id: int, slot_index: int, attachment_slot: int) -> void:
	var attachment: AttachmentData = weapon_slots_list[player_id].get_attachment(slot_index, attachment_slot)
	if attachment == null:
		return
	if weapon_slots_list[player_id].unequip_attachment(slot_index, attachment_slot):
		attachment_bag.append(Bulwark.loc(attachment.id).to_string())
		Net.send_event(NetCodec.EVT_BAG_CHANGED, {NetCodec.KEY_BAG: attachment_bag.duplicate()})

func _get_attachment(location: String) -> AttachmentData:
	var registry := RegistryManager.get_registry(Bulwark.REG_ATTACHMENT)
	if registry == null:
		return null
	var loc := ResourceLocation.from_string(location)
	if loc == null:
		return null
	return registry.get_entry(loc) as AttachmentData

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

## 击杀奖励（M1 商店经济）：货币 + 概率建材 + 概率弹药（审查 D3 补给闭环）
func _on_enemy_died(event: EnemyDiedEvent) -> void:
	wave_director.register_enemy_died()
	if event == null:
		return
	var enemy_data: EnemyData = ContentBootstrap.get_entry(Bulwark.REG_ENEMY, event.enemy_location)
	if enemy_data != null and enemy_data.kill_reward > 0:
		run_state.add_credits(enemy_data.kill_reward)
		if randf() < KILL_MATERIAL_CHANCE:
			run_state.add_material(1)
		if randf() < KILL_AMMO_CHANCE:
			_grant_bullets(KILL_AMMO_AMOUNT)

## 补充子弹备弹并广播弹药事件（掉弹/商店弹药箱共用；HUD 只订阅事件刷新 reserve）
## 双人：补给落入本地玩家（host 进程 = 玩家 0）的弹药池
func _grant_bullets(amount: int) -> void:
	if amount <= 0:
		return
	ammo_system.add(WeaponTypeData.AmmoType.BULLET, amount)
	var slot := weapon_slots.get_current_slot()
	EventBus.publish(AmmoChangedEvent.new(
		WeaponTypeData.AmmoType.BULLET,
		slot.mag if slot.type_data != null else 0,
		ammo_system.get_count(WeaponTypeData.AmmoType.BULLET),
		_local_player_id))

## 玩家阵亡（M1 复活系统，P7/P20）：储备充足 → 复活 CD；耗尽 → 失败结算
## M2 双人：每玩家独立复活 CD，共享储备；任一玩家储备耗尽 → 判负（多人规则 M6 细化）
func _on_player_died(event: PlayerDiedEvent) -> void:
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

## 波间商店（M1）：清场 → 刷新商品 → 打开面板 + 暂停（host 裁决；client 跟随 ui_state）
func _on_wave_cleared(event: WaveClearedEvent) -> void:
	if _run_finished:
		return
	shop_system.refresh(event.wave_index * 1000 + 7)
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_SHOP), {
		"shop": shop_system,
		"weapon_slots": weapon_slots,
		"run_state": run_state,
		"bag": attachment_bag,
		"effect_handler": _shop_effect_handler,
	})
	if Net.is_host():
		Net.send_event(NetCodec.EVT_SHOP_OFFERS, _shop_offers_payload())
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

## 商店购买效果落点（装配层统一裁决，前端只发购买意图）：
## STAT_PLAYER → 购买者玩家 AttributeSet；STAT_WEAPON → RunState.bonus（武器结算）；
## ATTACHMENT → 配件背包；BARRICADE/RESERVE → 资源
## p_player_id：双人时 STAT_PLAYER 强化落到购买者（默认 0 = 单机/本地）
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
				run_state.apply_bonus_modifier(item.modifier)
		ShopItemData.Category.ATTACHMENT:
			if not item.attachment_location.is_empty():
				attachment_bag.append(item.attachment_location)
		ShopItemData.Category.BARRICADE:
			run_state.add_material(item.barricade_count)
		ShopItemData.Category.RESERVE:
			run_state.add_reserve(item.reserve_count)
		ShopItemData.Category.AMMO:
			_grant_bullets(item.ammo_amount)

## 商店面板关闭（"继续"按钮）→ 恢复 → 下一波
## client：发意图由 host 裁决；host：本地直接恢复 + 广播 ui_state
func on_shop_closed() -> void:
	if _run_finished:
		return
	if Net.is_client():
		Net.send_intent(&"shop_continue")
		return
	UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	get_tree().paused = false
	wave_director.resume_from_intermission()
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

# ─── 路障（M1 防线设施；M2 前置：弧形路障已落地） ───

## 放置路障（E 键意图）：消耗 1 建材，位置 = 玩家站位（M2 前置重构：跟随玩家而非鼠标）
## 弧线自动朝向基地（align_to_arc），形成贴合圆形防线的同心弧段
## 双人：p_player_id 指定放置者（host 用其模拟位置；不信客户端坐标）
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
	if not run_state.try_spend_material(facility.material_cost):
		return
	var pos := player_views[pid].global_position
	if base_node.global_position.distance_to(pos) > facility.build_radius:
		run_state.add_material(facility.material_cost)  # 退回（越界不放置）
		return
	var controller := BarricadeController.new(facility, _barricade_seq)
	_barricade_seq += 1
	barricades.append(controller)
	var view: BarricadeView = BARRICADE_SCENE.instantiate() as BarricadeView
	barricade_views.append(view)
	get_parent().add_child(view)
	view.global_position = pos
	view.setup(controller)
	view.align_to_arc(base_node.global_position)  # 弧心朝向基地 + 按半径重建弧面/碰撞
	EventBus.publish(BarricadePlacedEvent.new(controller.get_location(), pos))

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

func _start_run() -> void:
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

func _finish_run_victory() -> void:
	if _run_finished:
		return
	_run_finished = true
	_result_data = {"victory": true}
	# 清掉可能残留的波间商店面板（最后波清场后商店刚打开即胜利）
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_RESULT), {"victory": true})
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

func _finish_run(reason: int) -> void:
	if _run_finished:
		return
	_run_finished = true
	_result_data = {"victory": false, "reason": reason}
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	get_tree().paused = true
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_RESULT), {"victory": false, "reason": reason})
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

# ─── 暂停 ───

func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_PAUSE))
	else:
		get_tree().paused = true
		UIManager.open_panel(Bulwark.loc(Bulwark.UI_PAUSE))
	if Net.is_host():
		Net.send_event(NetCodec.EVT_UI_STATE, _ui_state_payload())

# ─── 多人 host：快照与事件中继 ───

func _ui_state_payload() -> Dictionary:
	return {
		NetCodec.KEY_PAUSED: get_tree().paused,
		NetCodec.KEY_SHOP_OPEN: UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)),
		NetCodec.KEY_RESULT: _result_data,
	}

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

func _shop_offers_payload() -> Dictionary:
	var offers: Array = []
	for offer_variant in shop_system.offers:
		var offer := offer_variant as ShopRefreshedEvent.Offer
		if offer == null or offer.item == null:
			continue
		offers.append({
			NetCodec.KEY_OFFER_LOCATION: Bulwark.loc(offer.item.id).to_string(),
			NetCodec.KEY_OFFER_PRICE: offer.price,
			NetCodec.KEY_OFFER_OWNED: offer.owned,
			NetCodec.KEY_OFFER_AFFORDABLE: offer.can_afford,
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
	Net.send_snapshot({
		NetCodec.SNAP_TICK: _snapshot_tick,
		NetCodec.SNAP_RUN: {
			NetCodec.RUN_PAUSED: get_tree().paused,
			NetCodec.RUN_SHOP_OPEN: UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)),
			NetCodec.RUN_FINISHED: _run_finished,
			NetCodec.RUN_CREDITS: run_state.credits,
			NetCodec.RUN_MATERIAL: run_state.material,
			NetCodec.RUN_RESERVE: run_state.reserve,
			NetCodec.RUN_BAG: attachment_bag.duplicate(),
			NetCodec.RUN_WAVE_INDEX: wave_director.current_wave_index + 1,
			NetCodec.RUN_WAVE_TOTAL: wave_director.waves.size(),
		},
		NetCodec.SNAP_BASE: {
			NetCodec.BASE_DURABILITY: base_core.durability,
			NetCodec.BASE_MAX: base_core.max_durability,
		},
		NetCodec.SNAP_PLAYERS: players_data,
		NetCodec.SNAP_ENEMIES: enemies_data,
	})

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

func _relay_shot_fired(event: ShotFiredEvent) -> void:
	_relay(NetCodec.EVT_SHOT_FIRED, {
		NetCodec.KEY_PLAYER_ID: event.player_id,
		NetCodec.KEY_MODEL_LOCATION: event.model_location,
		NetCodec.KEY_AIM_DIRECTION: NetCodec.vec_to_arr(event.aim_direction),
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
		NetCodec.KEY_CREDITS: event.credits,
		NetCodec.KEY_MATERIAL: event.material,
		NetCodec.KEY_RESERVE_COUNT: event.reserve,
	})

func _relay_wave_warning(event: WaveWarningEvent) -> void:
	_relay(NetCodec.EVT_WAVE_WARNING, {
		NetCodec.KEY_WAVE_INDEX: event.wave_index,
		NetCodec.KEY_WAVE_TOTAL: event.wave_total,
		NetCodec.KEY_TIERS: event.direction_tiers,
	})

func _relay_wave_started(event: WaveStartedEvent) -> void:
	_relay(NetCodec.EVT_WAVE_STARTED, {
		NetCodec.KEY_WAVE_INDEX: event.wave_index,
		NetCodec.KEY_WAVE_TOTAL: event.wave_total,
	})

func _relay_wave_cleared(event: WaveClearedEvent) -> void:
	_relay(NetCodec.EVT_WAVE_CLEARED, {
		NetCodec.KEY_WAVE_INDEX: event.wave_index,
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

# ─── 多人 client：快照应用 / 事件路由（镜像） ───

func _on_net_state(data: Dictionary) -> void:
	if not _client_started:
		_client_started = true
	if _smoke_mode:
		_smoke_stats["syncs"] = int(_smoke_stats.get("syncs", 0)) + 1
	# run 状态（去重发布 RunStateChangedEvent；HUD 资源行）
	var run: Dictionary = data.get(NetCodec.SNAP_RUN, {})
	if run != _last_run_state:
		_last_run_state = run
		run_state.credits = int(run.get(NetCodec.RUN_CREDITS, 0))
		run_state.material = int(run.get(NetCodec.RUN_MATERIAL, 0))
		run_state.reserve = int(run.get(NetCodec.RUN_RESERVE, 0))
		EventBus.publish(RunStateChangedEvent.new(
			run_state.credits, run_state.material, run_state.reserve))
		# 背包镜像（共享）
		var bag: Array = run.get(NetCodec.RUN_BAG, [])
		_client_bag.clear()
		for loc in bag:
			_client_bag.append(str(loc))
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
	# 敌人镜像（增删改）
	_apply_enemies_snapshot(data.get(NetCodec.SNAP_ENEMIES, {}))

func _apply_player_snapshot(pid: int, pdata: Dictionary) -> void:
	if pid < 0 or pid >= player_views.size():
		return
	var view := player_views[pid]
	view.apply_snapshot(
		NetCodec.arr_to_vec(pdata.get(NetCodec.PLAYER_POS, [0.0, 0.0])),
		float(pdata.get(NetCodec.PLAYER_AIM, 0.0)))
	var hp := float(pdata.get(NetCodec.PLAYER_HP, 0.0))
	var max_hp := float(pdata.get(NetCodec.PLAYER_MAX_HP, 100.0))
	players[pid].health = hp
	players[pid].max_health = max_hp
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
			mirror.apply_snapshot(NetCodec.arr_to_vec(edata.get(NetCodec.ENEMY_POS, [0.0, 0.0])))
		seen[id] = true
	if _smoke_mode:
		_smoke_stats["enemy_peak"] = maxi(
			int(_smoke_stats.get("enemy_peak", 0)), seen.size())
	for id in _mirror_enemies.keys():
		if not seen.has(id):
			var m: EnemyView = _mirror_enemies[id]
			_mirror_enemies.erase(id)
			if is_instance_valid(m) and not m.has_death_visual():
				m.queue_free()

func _on_net_event(event_name: StringName, payload: Dictionary) -> void:
	match event_name:
		NetCodec.EVT_WAVE_WARNING:
			EventBus.publish(WaveWarningEvent.new(
				int(payload.get(NetCodec.KEY_WAVE_INDEX, 0)),
				int(payload.get(NetCodec.KEY_WAVE_TOTAL, 0)),
				null,
				payload.get(NetCodec.KEY_TIERS, {})))
		NetCodec.EVT_WAVE_STARTED:
			EventBus.publish(WaveStartedEvent.new(
				int(payload.get(NetCodec.KEY_WAVE_INDEX, 0)),
				int(payload.get(NetCodec.KEY_WAVE_TOTAL, 0))))
		NetCodec.EVT_WAVE_CLEARED:
			EventBus.publish(WaveClearedEvent.new(
				int(payload.get(NetCodec.KEY_WAVE_INDEX, 0))))
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
			EventBus.publish(ShotFiredEvent.new(
				str(payload.get(NetCodec.KEY_MODEL_LOCATION, "")),
				NetCodec.arr_to_vec(payload.get(NetCodec.KEY_AIM_DIRECTION, [1.0, 0.0])),
				int(payload.get(NetCodec.KEY_PLAYER_ID, 0))))
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
			var bag: Array = payload.get(NetCodec.KEY_BAG, [])
			_client_bag.clear()
			for loc in bag:
				_client_bag.append(str(loc))
		NetCodec.EVT_SHOP_OFFERS:
			_apply_shop_offers(payload)
		NetCodec.EVT_SHOP_PURCHASED:
			EventBus.publish(ShopPurchasedEvent.new(
				str(payload.get(NetCodec.KEY_LOCATION, "")),
				int(payload.get(NetCodec.KEY_OFFER_PRICE, 0))))
		NetCodec.EVT_SHOP_PURCHASE_REJECTED:
			EventBus.publish(ShopPurchaseRejectedEvent.new(
				str(payload.get(NetCodec.KEY_LOCATION, "")),
				int(payload.get(NetCodec.KEY_REASON, 0))))
		NetCodec.EVT_RUN_STATE:
			run_state.credits = int(payload.get(NetCodec.KEY_CREDITS, 0))
			run_state.material = int(payload.get(NetCodec.KEY_MATERIAL, 0))
			run_state.reserve = int(payload.get(NetCodec.KEY_RESERVE_COUNT, 0))
			EventBus.publish(RunStateChangedEvent.new(
				run_state.credits, run_state.material, run_state.reserve))
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
	if pid < weapon_slots_list.size():
		weapon_slots_list[pid].current_index = int(payload.get(NetCodec.KEY_SLOT_INDEX, 0))
	EventBus.publish(WeaponSwitchedEvent.new(
		int(payload.get(NetCodec.KEY_SLOT_INDEX, 0)),
		int(payload.get(NetCodec.KEY_SLOT_TYPE, 0)),
		str(payload.get(NetCodec.KEY_MODEL_LOCATION, "")),
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

func _apply_shop_offers(payload: Dictionary) -> void:
	var offers: Array = []
	for o in payload.get(NetCodec.KEY_OFFERS, []):
		if not (o is Dictionary):
			continue
		var od: Dictionary = o
		var item := _get_shop_item(str(od.get(NetCodec.KEY_OFFER_LOCATION, "")))
		if item == null:
			continue
		offers.append(ShopRefreshedEvent.Offer.new(
			item,
			int(od.get(NetCodec.KEY_OFFER_PRICE, 0)),
			int(od.get(NetCodec.KEY_OFFER_OWNED, 0)),
			bool(od.get(NetCodec.KEY_OFFER_AFFORDABLE, false))))
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
func _apply_barricade_placed(payload: Dictionary) -> void:
	var facility: DefenseFacilityData = ContentBootstrap.get_entry(
		Bulwark.REG_FACILITY, Bulwark.loc(Bulwark.FACILITY_BARRICADE).to_string())
	if facility == null:
		return
	var controller := BarricadeController.new(facility, 0)
	var view: BarricadeView = BARRICADE_SCENE.instantiate() as BarricadeView
	get_parent().add_child(view)
	view.global_position = NetCodec.arr_to_vec(payload.get(NetCodec.KEY_POS, [0.0, 0.0]))
	view.setup(controller)
	view.align_to_arc(base_node.global_position)
	# 镜像路障无后端簿记；直接广播事件让视图完成后续（受击闪白由 damaged 事件驱动）
	EventBus.publish(BarricadePlacedEvent.new(
		str(payload.get(NetCodec.KEY_LOCATION, "")), view.global_position))

## client UI 状态跟随（不暂停树；仅开关面板）
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
		return
	var shop_open := bool(payload.get(NetCodec.KEY_SHOP_OPEN, false))
	var paused := bool(payload.get(NetCodec.KEY_PAUSED, false))
	if shop_open:
		if not UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
			UIManager.open_panel(Bulwark.loc(Bulwark.UI_SHOP), {
				"shop": shop_system,
				"weapon_slots": weapon_slots,
				"run_state": run_state,
				"bag": _client_bag,
				"effect_handler": Callable(),
			})
		return
	if paused:
		if not UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)):
			UIManager.open_panel(Bulwark.loc(Bulwark.UI_PAUSE))
		return
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_SHOP)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_SHOP))
	if UIManager.is_panel_open(Bulwark.loc(Bulwark.UI_PAUSE)):
		UIManager.close_panel(Bulwark.loc(Bulwark.UI_PAUSE))
