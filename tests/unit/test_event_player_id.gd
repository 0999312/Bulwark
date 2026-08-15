extends GutTest
## M2 玩家事件 player_id（多人区分）：构造默认 0（单机兼容）、显式传值、字段携带
## 注意：lambda 修改局部变量无效（值捕获），事件捕获用成员变量

var _got_player_id := -1

func test_default_player_id_is_zero() -> void:
	var e := PlayerHealthChangedEvent.new(80.0, 100.0)
	assert_eq(e.player_id, 0, "默认 0 = 单机/本地")
	var died := PlayerDiedEvent.new()
	assert_eq(died.player_id, 0)

func test_explicit_player_id_carried() -> void:
	var e := PlayerHealthChangedEvent.new(80.0, 100.0, 1)
	assert_eq(e.player_id, 1, "双人：player 1 事件")
	var died := PlayerDiedEvent.new(1)
	assert_eq(died.player_id, 1)
	var revive := ReviveStartedEvent.new(4.0, 1)
	assert_eq(revive.player_id, 1)
	assert_eq(revive.revive_cd, 4.0)
	var revived := RevivedEvent.new(100.0, 100.0, 1)
	assert_eq(revived.player_id, 1)

func test_weapon_events_carry_player_id() -> void:
	assert_eq(AmmoChangedEvent.new(0, 30, 90, 1).player_id, 1)
	assert_eq(WeaponSwitchedEvent.new(0, 0, "bulwark:weapon/model/storm7", 1).player_id, 1)
	assert_eq(WeaponSwitchStartedEvent.new(1, 1.5, 1).player_id, 1)
	assert_eq(WeaponSwitchRejectedEvent.new(2, WeaponSwitchRejectedEvent.REASON_EMPTY, 1).player_id, 1)
	assert_eq(ReloadStartedEvent.new(1.2, 0, 1).player_id, 1)
	assert_eq(ShotFiredEvent.new("bulwark:weapon/model/storm7", Vector2.RIGHT, 1).player_id, 1)
	assert_eq(AttachmentEquippedEvent.new(0, "bulwark:attachment/red_dot", 1).player_id, 1)
	assert_eq(AttachmentUnequippedEvent.new(0, "bulwark:attachment/red_dot", 1).player_id, 1)

func test_player_controller_emits_events_with_id() -> void:
	EventBus.clear_all_listeners()
	_got_player_id = -1
	EventBus.subscribe(&"PlayerHealthChangedEvent",
		func(e: Event) -> void: _got_player_id = (e as PlayerHealthChangedEvent).player_id)
	var ammo := AmmoSystem.new()
	var slots := WeaponSlots.new(ammo, RunState.new(), 1)
	var attrs := AttributeSet.new()
	attrs.set_base(AttributeSet.MAX_HEALTH, 100.0)
	var player := PlayerController.new(attrs, slots, 1)
	assert_eq(_got_player_id, 1, "构造时广播携带 player_id")

func test_weapon_slots_emits_events_with_id() -> void:
	EventBus.clear_all_listeners()
	_got_player_id = -1
	EventBus.subscribe(&"AmmoChangedEvent",
		func(e: Event) -> void: _got_player_id = (e as AmmoChangedEvent).player_id)
	var ammo := AmmoSystem.new()
	var slots := WeaponSlots.new(ammo, RunState.new(), 1)
	# 装填槽位后 emit（空槽位不发弹药事件）
	ContentBootstrap.register_all()
	var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	slots.assign_slot(WeaponSlots.SLOT_MAIN,
		type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE)),
		model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7)))
	slots.emit_initial_state()
	assert_eq(_got_player_id, 1, "弹药事件携带 player_id")
