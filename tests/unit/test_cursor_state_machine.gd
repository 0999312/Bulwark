extends GutTest
## BUG 修复：进度准星必须从空到满（填充），不能从满到空（消耗）。

var _machine: Node

func before_each() -> void:
	_machine = load("res://scripts/systems/cursor_state_machine.gd").new()
	add_child_autofree(_machine)
	_machine._reload_remaining = 0.0
	_machine._reload_total = 1.0
	_machine._switch_remaining = 0.0
	_machine._switch_total = 1.0

func test_reload_progress_fills_from_empty_to_full() -> void:
	_machine._reload_remaining = 1.0
	assert_eq(_machine._progress_texture(), _machine.PROGRESS_EMPTY,
		"进度 0% 应显示空圈")
	_machine._reload_remaining = 0.5
	assert_eq(_machine._progress_texture(), _machine.PROGRESS_50,
		"进度 50% 应显示 50 帧")
	_machine._reload_remaining = 0.05
	assert_eq(_machine._progress_texture(), _machine.PROGRESS_FULL,
		"进度 95% 应显示满圈")

func test_switch_progress_fills_from_empty_to_full() -> void:
	_machine._switch_remaining = 0.8
	_machine._switch_total = 1.0
	assert_eq(_machine._progress_texture(), _machine.PROGRESS_25,
		"进度 20% 应显示 25 帧")
	_machine._switch_remaining = 0.2
	assert_eq(_machine._progress_texture(), _machine.PROGRESS_75,
		"进度 80% 应显示 75 帧")

# ─── M4 热态/样式 ───

func after_each() -> void:
	SettingsManager.set_cursor_style(0)
	SettingsManager.set_spread_visual(true)

func test_bloom_switches_by_heat() -> void:
	_machine.set_combat_heat(0.0)
	assert_eq(_machine._combat_texture(), _machine.CROSS_TEXTURE, "低热标准帧")
	_machine.set_combat_heat(3.0)
	assert_eq(_machine._combat_texture(), _machine.CROSS_HOT, "高热热态帧")

func test_cursor_style_variant_pair() -> void:
	SettingsManager.set_cursor_style(1)
	_machine.set_combat_heat(0.0)
	assert_eq(_machine._combat_texture(), _machine.CROSS_SMALL, "样式1 基础=小十字")
	_machine.set_combat_heat(3.0)
	assert_eq(_machine._combat_texture(), _machine.CROSS_LARGE, "样式1 热态=大十字")

func test_spread_visual_off_keeps_base_frame() -> void:
	SettingsManager.set_spread_visual(false)
	_machine.set_combat_heat(3.0)
	assert_eq(_machine._combat_texture(), _machine.CROSS_TEXTURE, "关闭散布可视化 → 始终标准帧")
