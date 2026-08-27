extends GutTest
## M4：meta 解锁字符串命名空间集成（修复 Invalid ResourceLocation format 警告）
## 断言：解锁型号带 bulwark: 前缀、可被 ResourceLocation.from_string 解析、注册表可查询（改枪台可装备）。

func before_each() -> void:
	MetaProgress.reset()

func after_each() -> void:
	MetaProgress.reset()

func test_unlocked_models_namespaced_and_parseable() -> void:
	MetaProgress.add_meta_credits(4)
	var unlocked := MetaProgress.get_unlocked_models()
	assert_true(unlocked.size() >= 3, "4 战功解锁 AR-2/SG-2/LMG-1")
	for model_str: String in unlocked:
		assert_true(model_str.begins_with("bulwark:"), "%s 应带命名空间" % model_str)
		var loc := ResourceLocation.from_string(model_str)
		assert_not_null(loc, "%s 可解析" % model_str)
		if loc == null:
			continue
		assert_eq(loc.namespace_id, "bulwark", "%s namespace=bulwark" % model_str)
		var reg: Variant = RegistryManager.get_registry("weapon_model")
		assert_not_null(reg, "weapon_model 注册表存在")
		if reg != null:
			assert_not_null(reg.get_entry(loc), "%s 注册表可查询（改枪台 _get_model 前置）" % model_str)

func test_next_unlock_name_uses_content_key_without_namespace() -> void:
	MetaProgress.reset()
	MetaProgress.add_meta_credits(1)
	var name := MetaProgress.get_next_unlock_name()
	assert_true(name != "bulwark:weapon/model/sg_2", "展示名不应是裸 id：%s" % name)
