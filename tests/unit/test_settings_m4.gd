extends GutTest
## M4：设置面板新增手感项（灵敏度/震屏/准星样式/散布可视化）持久化与默认值兼容。
## SettingsManager 使用 user://settings.cfg（测试后恢复默认，避免污染后续用例）。

func after_each() -> void:
	SettingsManager.set_sensitivity(1.0)
	SettingsManager.set_shake_enabled(true)
	SettingsManager.set_shake_strength(1.0)
	SettingsManager.set_cursor_style(0)
	SettingsManager.set_spread_visual(true)

func test_defaults_match_legacy_behavior() -> void:
	assert_eq(SettingsManager.get_sensitivity(), 1.0, "默认灵敏度 1.0（旧行为）")
	assert_true(SettingsManager.is_shake_enabled(), "默认震屏开")
	assert_eq(SettingsManager.get_shake_strength(), 1.0, "默认震屏强度 1.0")
	assert_eq(SettingsManager.get_cursor_style(), 0, "默认准星样式 0=标准")

func test_set_and_read_roundtrip() -> void:
	SettingsManager.set_sensitivity(1.4)
	assert_eq(SettingsManager.get_sensitivity(), 1.4)
	SettingsManager.set_shake_enabled(false)
	assert_false(SettingsManager.is_shake_enabled())
	SettingsManager.set_shake_strength(0.5)
	assert_almost_eq(SettingsManager.get_shake_strength(), 0.5, 0.001)
	SettingsManager.set_cursor_style(1)
	assert_eq(SettingsManager.get_cursor_style(), 1)
	SettingsManager.set_spread_visual(false)
	assert_false(SettingsManager.is_spread_visual_enabled())

func test_sensitivity_clamped() -> void:
	SettingsManager.set_sensitivity(9.9)
	assert_eq(SettingsManager.get_sensitivity(), 2.0, "上限 2.0")
	SettingsManager.set_sensitivity(0.01)
	assert_eq(SettingsManager.get_sensitivity(), 0.5, "下限 0.5")
