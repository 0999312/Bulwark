extends GutTest
## i18n 硬约束回归：双语键奇偶、结构键覆盖、内容名回退、UI 场景无硬编码文案。

const REQUIRED_KEYS: Array[String] = [
	"menu.title", "pause.title", "settings.title", "result.stats",
	"shop.title", "shop.offers_title", "shop.sort_default", "shop.slot_main",
	"shop.workbench", "shop.bag", "shop.continue", "shop.buy", "shop.equip", "shop.unequip",
	"hud.resources", "hud.health", "hud.base", "hud.wave", "hud.facility_hint",
	"hud.banner_contact", "hud.controls_hint", "hud.revive",
	"content.weapon_model_ar_1.name", "content.shop_item_turret_damage_up.name",
	"content.facility_turret.name", "content.attachment_red_dot.name",
	"content.shop_item_damage_up.name", "content.shop_item_weapon_crate_ar_2.name",
]

func _load_locale(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

func test_locale_key_parity_and_required_keys() -> void:
	var zh := _load_locale("res://locales/zh.json")
	var en := _load_locale("res://locales/en.json")
	assert_gt(zh.size(), 200, "中文翻译表已装配")
	assert_eq(zh.size(), en.size(), "zh/en 键数必须一致")
	for key in zh.keys():
		assert_true(en.has(key), "en 缺少 %s" % key)
	for key in en.keys():
		assert_true(zh.has(key), "zh 缺少 %s" % key)
	for key in REQUIRED_KEYS:
		assert_true(zh.has(key), "zh 缺少 %s" % key)
		assert_true(en.has(key), "en 缺少 %s" % key)

func test_ui_text_switches_language_and_falls_back() -> void:
	var original := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(UiText.text("shop.title"), "Supply Depot")
	assert_eq(UiText.content_name("weapon/model/ar_1", "AR-1 突击步枪"),
		"AR-1 Assault Rifle", "内容名经翻译键返回")
	assert_eq(UiText.localized("__missing_key__", "fallback"), "fallback",
		"缺失键回退 fallback")
	TranslationServer.set_locale(original)

func test_ui_scene_files_contain_no_hardcoded_cjk_text() -> void:
	var dir := DirAccess.open("res://scenes/ui")
	assert_not_null(dir)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			var path := "res://scenes/ui/" + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			var text := file.get_as_text()
			file.close()
			for line in text.split("\n"):
				if "text" in line or "placeholder" in line or "tooltip" in line:
					for i in line.length():
						var code := line.unicode_at(i)
						if code >= 0x4E00 and code <= 0x9FFF:
							fail_test("%s 存在硬编码中文文本：%s" % [path, line])
		file_name = dir.get_next()
