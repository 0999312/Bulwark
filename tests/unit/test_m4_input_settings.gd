extends GutTest
## M4.1 设置扩展回归：GUIDE 键位 remapping + 语言切换（MSF I18N）
## - InputSettings 暴露 combat 可重映射项（move×4 / shoot / switch×3 / pause / reload / interact）
## - 单项绑定 → 标签刷新 → 恢复默认；语言切换 → TranslationServer locale 与 tr() 文案

func after_each() -> void:
	# 测试内改了用户设置：恢复默认，避免污染后续测试
	InputSettings.reset_all_bindings()
	SettingsManager.set_language("zh")

func test_remappable_items_exist() -> void:
	var items := InputSettings.get_items()
	assert_gte(items.size(), 12, "combat 动作共 12 个可重映射项")
	var names: Dictionary = {}
	var move_indexes: Array = []
	var switch_indexes: Array = []
	for item in items:
		names[str(item.action.name)] = int(names.get(str(item.action.name), 0)) + 1
		if str(item.action.name) == "move":
			move_indexes.append(int(item.index))
		if str(item.action.name) == "switch_weapon":
			switch_indexes.append(int(item.index))
	assert_eq(int(names.get("move", 0)), 4, "移动四键都可重映射")
	assert_eq(int(names.get("switch_weapon", 0)), 3, "切换武器三键都可重映射")
	assert_eq(int(names.get("shoot", 0)), 1, "射击可重映射")
	assert_eq(int(names.get("cycle_facility", 0)), 1, "设施切换 F 可重映射")
	move_indexes.sort()
	switch_indexes.sort()
	assert_eq(move_indexes, [0, 1, 2, 3], "M4.2：移动四键合并为单 mapping，index 唯一（修复四个“移动·上”）")
	assert_eq(switch_indexes, [0, 1, 2], "M4.2：切枪三键 index 唯一")

func test_bind_reload_key_and_reset() -> void:
	var reload_item = null
	for item in InputSettings.get_items():
		if str(item.action.name) == "reload":
			reload_item = item
			break
	assert_not_null(reload_item, "找到换弹项")
	if reload_item == null:
		return
	var key := GUIDEInputKey.new()
	key.key = KEY_T
	var remapper = InputSettings._remapper
	remapper.set_bound_input(reload_item, key)
	InputSettings._apply_to_guide()
	assert_true(InputSettings.get_bound_label(reload_item).contains("T"), "绑定后标签显示 T 键")
	InputSettings.reset_all_bindings()
	assert_true(InputSettings.get_bound_label(reload_item).contains("R"), "恢复默认后回到 R 键")

func test_language_switch_uses_i18n_manager() -> void:
	assert_eq(SettingsManager.get_language(), "zh")
	assert_eq(TranslationServer.get_locale(), "zh")
	SettingsManager.set_language("en")
	assert_eq(TranslationServer.get_locale(), "en", "locale 已切换")
	assert_eq(tr("menu.title"), "BULWARK", "英文翻译生效")
	SettingsManager.set_language("zh")
	assert_eq(TranslationServer.get_locale(), "zh", "切回中文")
	assert_eq(tr("menu.title"), "前线壁垒", "中文翻译生效")

func test_bind_cycle_facility_key_and_reset() -> void:
	var cycle_item = null
	for item in InputSettings.get_items():
		if str(item.action.name) == "cycle_facility":
			cycle_item = item
			break
	assert_not_null(cycle_item, "找到设施切换项")
	if cycle_item == null:
		return
	var key := GUIDEInputKey.new()
	key.key = KEY_V
	var remapper = InputSettings._remapper
	remapper.set_bound_input(cycle_item, key)
	InputSettings._apply_to_guide()
	assert_true(InputSettings.get_bound_label(cycle_item).contains("V"), "设施切换绑定后显示 V 键")
	InputSettings.reset_all_bindings()
	assert_true(InputSettings.get_bound_label(cycle_item).contains("F"), "恢复默认后回到 F 键")
