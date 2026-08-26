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
	for type_id: String in Bulwark.WEAPON_TYPE_IDS:
		var file_name := "type_%s" % type_id.trim_prefix("weapon/type/")
		registry.register(Bulwark.loc(type_id), load("res://resources/weapons/type/%s.tres" % file_name))
	RegistryManager.register_registry(Bulwark.REG_WEAPON_TYPE, registry)

static func register_weapon_models() -> void:
	if RegistryManager.has_registry(Bulwark.REG_WEAPON_MODEL):
		return
	var registry := WeaponModelRegistry.new()
	for model_id: String in Bulwark.WEAPON_MODEL_IDS:
		var file_name := "model_%s" % model_id.trim_prefix("weapon/model/")
		registry.register(Bulwark.loc(model_id), load("res://resources/weapons/model/%s.tres" % file_name))
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
	registry.register(Bulwark.loc(Bulwark.ENEMY_SELF_DESTRUCT),
		load("res://resources/enemies/enemy_self_destruct.tres"))
	registry.register(Bulwark.loc(Bulwark.ENEMY_SPITTER),
		load("res://resources/enemies/enemy_spitter.tres"))
	registry.register(Bulwark.loc(Bulwark.ENEMY_ARMORED),
		load("res://resources/enemies/enemy_armored.tres"))
	registry.register(Bulwark.loc(Bulwark.ENEMY_FLYING),
		load("res://resources/enemies/enemy_flying.tres"))
	registry.register(Bulwark.loc(Bulwark.ENEMY_SNIPER),
		load("res://resources/enemies/enemy_sniper.tres"))
	registry.register(Bulwark.loc(Bulwark.ENEMY_ELITE_BEHEMOTH),
		load("res://resources/enemies/enemy_elite_behemoth.tres"))
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
	registry.register_panel(
		Bulwark.loc(Bulwark.UI_SETTINGS),
		load("res://scenes/ui/settings_panel.tscn"),
		UILayer.POPUP)
	registry.register_panel(
		Bulwark.loc(Bulwark.UI_CHAPTER_REWARD),
		load("res://scenes/ui/chapter_reward_panel.tscn"),
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
	for item_id: String in Bulwark.SHOP_ITEM_IDS_INCLUDING_CRATES:
		var file_name := "shop_%s" % item_id.trim_prefix("shop/item/")
		registry.register(Bulwark.loc(item_id), load("res://resources/shop/items/%s.tres" % file_name))
	RegistryManager.register_registry(Bulwark.REG_SHOP_ITEM, registry)

static func register_facilities() -> void:
	if RegistryManager.has_registry(Bulwark.REG_FACILITY):
		return
	var registry := FacilityRegistry.new()
	registry.register(Bulwark.loc(Bulwark.FACILITY_BARRICADE),
		load("res://resources/facilities/facility_barricade.tres"))
	registry.register(Bulwark.loc(Bulwark.FACILITY_TURRET),
		load("res://resources/facilities/facility_turret.tres"))
	RegistryManager.register_registry(Bulwark.REG_FACILITY, registry)

## 便捷查询：按 ResourceLocation 字符串从注册表取条目（未注册返回 null）
static func get_entry(registry_name: String, location_str: String) -> Variant:
	var registry: RegistryBase = RegistryManager.get_registry(registry_name)
	if registry == null:
		return null
	return registry.get_entry(ResourceLocation.from_string(location_str))
