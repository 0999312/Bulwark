class_name ContentBootstrap
extends RefCounted
## 内容引导：M0 全部内容（武器种类/型号、敌人、波次、UI）经 Registry + ResourceLocation 注册
## 架构硬性约束（§1.1/§10.8）：官方内容 = bulwark 命名空间下第一个内容包；Mod 走同一管线注册更多条目。
## 幂等：已注册过的注册表不重复注册（测试/热重载安全）。

## 注册全部内容（在 RegistryManager 可用时调用；GameSession._ready 执行）
static func register_all() -> void:
	register_weapon_types()
	register_weapon_models()
	register_enemies()
	register_waves()
	register_ui()
	register_attachments()
	register_shop_items()
	register_facilities()

static func register_weapon_types() -> void:
	if RegistryManager.has_registry(Bulwark.REG_WEAPON_TYPE):
		return
	var registry := WeaponTypeRegistry.new()
	registry.register(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE),
		load("res://resources/weapons/type/type_assault_rifle.tres"))
	registry.register(Bulwark.loc(Bulwark.WEAPON_TYPE_PISTOL),
		load("res://resources/weapons/type/type_pistol.tres"))
	registry.register(Bulwark.loc(Bulwark.WEAPON_TYPE_SHOTGUN),
		load("res://resources/weapons/type/type_shotgun.tres"))
	RegistryManager.register_registry(Bulwark.REG_WEAPON_TYPE, registry)

static func register_weapon_models() -> void:
	if RegistryManager.has_registry(Bulwark.REG_WEAPON_MODEL):
		return
	var registry := WeaponModelRegistry.new()
	registry.register(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7),
		load("res://resources/weapons/model/model_storm7.tres"))
	registry.register(Bulwark.loc(Bulwark.WEAPON_MODEL_SENTINEL1),
		load("res://resources/weapons/model/model_sentinel1.tres"))
	registry.register(Bulwark.loc(Bulwark.WEAPON_MODEL_JAWBREAKER),
		load("res://resources/weapons/model/model_jawbreaker.tres"))
	RegistryManager.register_registry(Bulwark.REG_WEAPON_MODEL, registry)

static func register_enemies() -> void:
	if RegistryManager.has_registry(Bulwark.REG_ENEMY):
		return
	var registry := EnemyRegistry.new()
	registry.register(Bulwark.loc(Bulwark.ENEMY_RUNNER),
		load("res://resources/enemies/enemy_runner.tres"))
	registry.register(Bulwark.loc(Bulwark.ENEMY_RUNNER_FAST),
		load("res://resources/enemies/enemy_runner_fast.tres"))
	registry.register(Bulwark.loc(Bulwark.ENEMY_RUNNER_TOUGH),
		load("res://resources/enemies/enemy_runner_tough.tres"))
	RegistryManager.register_registry(Bulwark.REG_ENEMY, registry)

static func register_waves() -> void:
	if RegistryManager.has_registry(Bulwark.REG_WAVE):
		return
	var registry := WaveRegistry.new()
	for wave_id: String in Bulwark.WAVE_IDS:
		# wave/1 → wave_1.tres（文件命名：resources/waves/wave_N.tres）
		var file_name := wave_id.replace("/", "_")
		registry.register(Bulwark.loc(wave_id), load("res://resources/waves/%s.tres" % file_name))
	RegistryManager.register_registry(Bulwark.REG_WAVE, registry)

## UI 面板注册（UIManager 面板栈；HUD 用 add_overlay 直接挂）
static func register_ui() -> void:
	if RegistryManager.has_registry(Bulwark.REG_UI):
		return
	var registry := UIRegistry.new()
	registry.register_panel(
		Bulwark.loc(Bulwark.UI_RESULT),
		load("res://scenes/ui/result_panel.tscn"),
		UILayer.POPUP)
	registry.register_panel(
		Bulwark.loc(Bulwark.UI_PAUSE),
		load("res://scenes/ui/pause_panel.tscn"),
		UILayer.POPUP)
	registry.register_panel(
		Bulwark.loc(Bulwark.UI_SHOP),
		load("res://scenes/ui/shop_panel.tscn"),
		UILayer.POPUP)
	RegistryManager.register_registry(Bulwark.REG_UI, registry)

static func register_attachments() -> void:
	if RegistryManager.has_registry(Bulwark.REG_ATTACHMENT):
		return
	var registry := AttachmentRegistry.new()
	registry.register(Bulwark.loc(Bulwark.ATTACHMENT_RED_DOT),
		load("res://resources/attachments/attachment_red_dot.tres"))
	registry.register(Bulwark.loc(Bulwark.ATTACHMENT_EXT_MAG),
		load("res://resources/attachments/attachment_ext_mag.tres"))
	registry.register(Bulwark.loc(Bulwark.ATTACHMENT_COMPENSATOR),
		load("res://resources/attachments/attachment_compensator.tres"))
	registry.register(Bulwark.loc(Bulwark.ATTACHMENT_LIGHT_STOCK),
		load("res://resources/attachments/attachment_light_stock.tres"))
	RegistryManager.register_registry(Bulwark.REG_ATTACHMENT, registry)

static func register_shop_items() -> void:
	if RegistryManager.has_registry(Bulwark.REG_SHOP_ITEM):
		return
	var registry := ShopItemRegistry.new()
	registry.register(Bulwark.loc(Bulwark.SHOP_DAMAGE_UP), load("res://resources/shop/items/shop_damage_up.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_FIRE_RATE_UP), load("res://resources/shop/items/shop_fire_rate_up.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_MAG_UP), load("res://resources/shop/items/shop_mag_up.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_RELOAD_UP), load("res://resources/shop/items/shop_reload_up.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_MAX_HP_UP), load("res://resources/shop/items/shop_max_hp_up.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_MOVE_SPEED_UP), load("res://resources/shop/items/shop_move_speed_up.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_RED_DOT), load("res://resources/shop/items/shop_red_dot.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_EXT_MAG), load("res://resources/shop/items/shop_ext_mag.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_COMPENSATOR), load("res://resources/shop/items/shop_compensator.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_LIGHT_STOCK), load("res://resources/shop/items/shop_light_stock.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_BARRICADE), load("res://resources/shop/items/shop_barricade.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_RESERVE), load("res://resources/shop/items/shop_reserve.tres"))
	registry.register(Bulwark.loc(Bulwark.SHOP_AMMO_CRATE), load("res://resources/shop/items/shop_ammo_crate.tres"))
	RegistryManager.register_registry(Bulwark.REG_SHOP_ITEM, registry)

static func register_facilities() -> void:
	if RegistryManager.has_registry(Bulwark.REG_FACILITY):
		return
	var registry := FacilityRegistry.new()
	registry.register(Bulwark.loc(Bulwark.FACILITY_BARRICADE),
		load("res://resources/facilities/facility_barricade.tres"))
	RegistryManager.register_registry(Bulwark.REG_FACILITY, registry)

## 便捷查询：按 ResourceLocation 字符串从注册表取条目（未注册返回 null）
static func get_entry(registry_name: String, location_str: String) -> Variant:
	var registry: RegistryBase = RegistryManager.get_registry(registry_name)
	if registry == null:
		return null
	return registry.get_entry(ResourceLocation.from_string(location_str))
