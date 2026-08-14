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

static func register_weapon_types() -> void:
	if RegistryManager.has_registry(Bulwark.REG_WEAPON_TYPE):
		return
	var registry := WeaponTypeRegistry.new()
	registry.register(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE),
		load("res://resources/weapons/type/type_assault_rifle.tres"))
	registry.register(Bulwark.loc(Bulwark.WEAPON_TYPE_PISTOL),
		load("res://resources/weapons/type/type_pistol.tres"))
	RegistryManager.register_registry(Bulwark.REG_WEAPON_TYPE, registry)

static func register_weapon_models() -> void:
	if RegistryManager.has_registry(Bulwark.REG_WEAPON_MODEL):
		return
	var registry := WeaponModelRegistry.new()
	registry.register(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7),
		load("res://resources/weapons/model/model_storm7.tres"))
	registry.register(Bulwark.loc(Bulwark.WEAPON_MODEL_SENTINEL1),
		load("res://resources/weapons/model/model_sentinel1.tres"))
	RegistryManager.register_registry(Bulwark.REG_WEAPON_MODEL, registry)

static func register_enemies() -> void:
	if RegistryManager.has_registry(Bulwark.REG_ENEMY):
		return
	var registry := EnemyRegistry.new()
	registry.register(Bulwark.loc(Bulwark.ENEMY_RUNNER),
		load("res://resources/enemies/enemy_runner.tres"))
	RegistryManager.register_registry(Bulwark.REG_ENEMY, registry)

static func register_waves() -> void:
	if RegistryManager.has_registry(Bulwark.REG_WAVE):
		return
	var registry := WaveRegistry.new()
	registry.register(Bulwark.loc(Bulwark.WAVE_1), load("res://resources/waves/wave_1.tres"))
	registry.register(Bulwark.loc(Bulwark.WAVE_2), load("res://resources/waves/wave_2.tres"))
	registry.register(Bulwark.loc(Bulwark.WAVE_3), load("res://resources/waves/wave_3.tres"))
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
	RegistryManager.register_registry(Bulwark.REG_UI, registry)

## 便捷查询：按 ResourceLocation 字符串从注册表取条目（未注册返回 null）
static func get_entry(registry_name: String, location_str: String) -> Variant:
	var registry: RegistryBase = RegistryManager.get_registry(registry_name)
	if registry == null:
		return null
	return registry.get_entry(ResourceLocation.from_string(location_str))
