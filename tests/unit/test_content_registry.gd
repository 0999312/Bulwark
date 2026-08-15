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

func test_m1_content_registered_under_bulwark() -> void:
	# M1：副武器霰弹枪、奔跑者变种、波次 4~6、配件、商店商品、路障设施
	var type_reg: WeaponTypeRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_TYPE)
	var model_reg: WeaponModelRegistry = RegistryManager.get_registry(Bulwark.REG_WEAPON_MODEL)
	var enemy_reg: EnemyRegistry = RegistryManager.get_registry(Bulwark.REG_ENEMY)
	var wave_reg: WaveRegistry = RegistryManager.get_registry(Bulwark.REG_WAVE)
	var att_reg: AttachmentRegistry = RegistryManager.get_registry(Bulwark.REG_ATTACHMENT)
	var shop_reg: ShopItemRegistry = RegistryManager.get_registry(Bulwark.REG_SHOP_ITEM)
	var fac_reg: FacilityRegistry = RegistryManager.get_registry(Bulwark.REG_FACILITY)
	assert_not_null(type_reg)
	assert_not_null(model_reg)
	assert_not_null(enemy_reg)
	assert_not_null(wave_reg)
	assert_not_null(att_reg)
	assert_not_null(shop_reg)
	assert_not_null(fac_reg)

	# 霰弹枪（副武器）：类型 + 型号 + 弹丸数
	var shotgun: WeaponTypeData = type_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_TYPE_SHOTGUN))
	assert_not_null(shotgun)
	assert_eq(shotgun.slot, WeaponTypeData.SlotType.SUB, "霰弹枪为副槽")
	assert_eq(shotgun.ballistic, WeaponTypeData.BallisticMode.SPREAD, "霰弹为 SPREAD 弹道")
	var jawbreaker: WeaponModelData = model_reg.get_entry(Bulwark.loc(Bulwark.WEAPON_MODEL_JAWBREAKER))
	assert_not_null(jawbreaker)
	assert_gt(jawbreaker.pellets, 1, "霰弹型号弹丸数 > 1")

	# 奔跑者变种
	assert_not_null(enemy_reg.get_entry(Bulwark.loc(Bulwark.ENEMY_RUNNER_FAST)))
	assert_not_null(enemy_reg.get_entry(Bulwark.loc(Bulwark.ENEMY_RUNNER_TOUGH)))

	# 波次 4~6（多敌人组）
	for wave_id in [Bulwark.WAVE_4, Bulwark.WAVE_5, Bulwark.WAVE_6]:
		var wave: WaveData = wave_reg.get_entry(Bulwark.loc(wave_id))
		assert_not_null(wave)
		assert_false(wave.groups.is_empty(), "M1 波次使用多敌人组")

	# 配件 ×4
	for att_id in [Bulwark.ATTACHMENT_RED_DOT, Bulwark.ATTACHMENT_EXT_MAG,
			Bulwark.ATTACHMENT_COMPENSATOR, Bulwark.ATTACHMENT_LIGHT_STOCK]:
		assert_not_null(att_reg.get_entry(Bulwark.loc(att_id)))

	# 商店商品：随机池 + 固定物资
	var shop_entries: Dictionary = shop_reg.get_all_entries()
	assert_gt(shop_entries.size(), 8, "商品池 > 8 项")
	var fixed_count := 0
	for item: ShopItemData in shop_entries.values():
		if item.is_fixed:
			fixed_count += 1
	assert_gte(fixed_count, 3, "固定物资 ≥ 3（路障 + 应急储备 + 弹药箱）")
	# 弹药箱（补给经济闭环）：固定物资 + 补弹数量
	var ammo_crate: ShopItemData = shop_reg.get_entry(Bulwark.loc(Bulwark.SHOP_AMMO_CRATE))
	assert_not_null(ammo_crate, "弹药箱已注册")
	assert_true(ammo_crate.is_fixed, "弹药箱为固定物资（波间恒可购买）")
	assert_gt(ammo_crate.ammo_amount, 0, "弹药箱补弹量 > 0")

	# 路障设施
	var barricade: DefenseFacilityData = fac_reg.get_entry(Bulwark.loc(Bulwark.FACILITY_BARRICADE))
	assert_not_null(barricade)
	assert_gt(barricade.max_durability, 0.0)

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
