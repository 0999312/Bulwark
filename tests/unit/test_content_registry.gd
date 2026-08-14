extends GutTest
## 内容注册验收（架构硬性约束：所有内容经 Registry + ResourceLocation，bulwark 命名空间）
## 与 Mod 前置同构：官方内容 = bulwark 命名空间下第一个内容包

func before_all() -> void:
	ContentBootstrap.register_all()

func test_all_m0_content_registered_under_bulwark() -> void:
	var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	var enemy_reg: EnemyRegistry = RegistryManager.get_registry(Bulwark.REG_ENEMY)
	var wave_reg: WaveRegistry = RegistryManager.get_registry(Bulwark.REG_WAVE)
	assert_not_null(type_reg)
	assert_not_null(model_reg)
	assert_not_null(enemy_reg)
	assert_not_null(wave_reg)

	# 武器种类
	assert_not_null(type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE)))
	assert_not_null(type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_PISTOL)))
	# 武器型号
	assert_not_null(model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7)))
	assert_not_null(model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_SENTINEL1)))
	# 敌人
	assert_not_null(enemy_reg.get_entry(Bulwark.loc(Bulwark.ENEMY_RUNNER)))
	# 波次 ×3
	for wave_id in [Bulwark.WAVE_1, Bulwark.WAVE_2, Bulwark.WAVE_3]:
		assert_not_null(wave_reg.get_entry(Bulwark.loc(wave_id)))

func test_registry_type_validation_rejects_wrong_type() -> void:
	var enemy_reg := EnemyRegistry.new()
	assert_false(enemy_reg.register(Bulwark.loc("enemy/bad"), WeaponTypeData.new()),
		"EnemyRegistry 应拒绝非 EnemyData")
	assert_true(enemy_reg.register(Bulwark.loc("enemy/ok"), EnemyData.new()))
	var wave_reg := WaveRegistry.new()
	assert_false(wave_reg.register(Bulwark.loc("wave/bad"), EnemyData.new()))
	assert_true(wave_reg.register(Bulwark.loc("wave/ok"), WaveData.new()))

func test_resource_location_namespace_and_id() -> void:
	var loc := Bulwark.loc(Bulwark.ENEMY_RUNNER)
	assert_eq(loc.to_string(), "bulwark:enemy/runner")
	assert_eq(loc.namespace_id, "bulwark")
	assert_true(ResourceLocation.is_valid(loc.to_string()))

func test_p23_switch_cd_values_in_data() -> void:
	# 已定数值 P23：主↔副 1.5s、↔手枪 0.3s（数据驱动来源）
	var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	var rifle: WeaponTypeData = type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_ASSAULT_RIFLE))
	var pistol: WeaponTypeData = type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_PISTOL))
	assert_not_null(rifle)
	assert_not_null(pistol)
	assert_almost_eq(rifle.switch_cd, 1.5, 0.001)
	assert_almost_eq(pistol.switch_cd, 0.3, 0.001)

func test_p26_fictional_names_in_data() -> void:
	var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	var storm7: WeaponModelData = model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7))
	assert_not_null(storm7)
	assert_string_contains(storm7.display_name, "风暴-7")
	assert_eq(storm7.type_id, "bulwark:weapon/type/assault_rifle")

func test_model_type_reference_resolves() -> void:
	# 数据层交叉引用（type_id → WeaponTypeRegistry）可解析
	var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	var storm7: WeaponModelData = model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_STORM7))
	var resolved: WeaponTypeData = type_reg.get_entry(ResourceLocation.from_string(storm7.type_id))
	assert_not_null(resolved)
	assert_eq(resolved.id, "weapon/type/assault_rifle")
