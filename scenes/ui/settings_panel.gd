class_name SettingsPanel
extends UIPanel
## M4.2 设置面板（UIManager POPUP 层；主菜单/暂停面板共用）
## 三个分页：音频 / 键位 / 语言（TabContainer，互不挤占，直觉分区）
## - 音量三路（SettingsManager，ConfigFile 持久化）
## - 键位绑定（InputSettings：GUIDE remapping + user://input_bindings.json）
## - 语言切换（MSF I18NManager；locales/zh.json、en.json）
## close 返回上一层面板

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var ui_slider: HSlider = %UiSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue
@onready var ui_value: Label = %UiValue
@onready var tabs: TabContainer = %Tabs
@onready var keys_hint: Label = %KeysHint
@onready var keys_list: VBoxContainer = %KeysList
@onready var reset_all_button: Button = %ResetAllButton
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var language_hint: Label = %LanguageHint

func _ready() -> void:
	# UIManager 每次 open 都新建实例（CacheMode.NONE）：在入树后接线，无重复连接问题
	language_option.item_selected.connect(_on_language_selected)
	reset_all_button.pressed.connect(_on_reset_all_pressed)
	%BackButton.pressed.connect(_on_back_pressed)
	InputSettings.bindings_changed.connect(_rebuild_key_rows)
	SettingsManager.language_changed.connect(_on_language_changed)
	_apply_texts()

func _apply_texts() -> void:
	%TitleLabel.text = tr("settings.title")
	tabs.set_tab_title(0, tr("settings.tab_audio"))
	tabs.set_tab_title(1, tr("settings.tab_keys"))
	tabs.set_tab_title(2, tr("settings.tab_language"))
	%MusicLabel.text = tr("settings.music")
	%SfxLabel.text = tr("settings.sfx")
	%UiLabel.text = tr("settings.ui")
	keys_hint.text = tr("settings.key_hint")
	reset_all_button.text = tr("settings.key.reset_all")
	language_label.text = tr("settings.language")
	language_hint.text = tr("settings.language_hint")
	%BackButton.text = tr("settings.back")

func _on_open(_data: Dictionary = {}) -> void:
	music_slider.set_value_no_signal(SettingsManager.get_volume("Music"))
	sfx_slider.set_value_no_signal(SettingsManager.get_volume("SFX"))
	ui_slider.set_value_no_signal(SettingsManager.get_volume("UI"))
	_refresh_labels()
	_refresh_language_options()
	_rebuild_key_rows()
	tabs.current_tab = 0
	%BackButton.grab_focus()

func _on_close() -> void:
	InputSettings.abort_detection()

func _on_back_pressed() -> void:
	AudioDirector.play_ui_select()
	UIManager.close_panel(panel_id)

func _refresh_labels() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value * 100.0)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value * 100.0)
	ui_value.text = "%d%%" % roundi(ui_slider.value * 100.0)

func _on_music_changed(value: float) -> void:
	SettingsManager.set_volume("Music", value)
	_refresh_labels()

func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_volume("SFX", value)
	_refresh_labels()

func _on_ui_changed(value: float) -> void:
	SettingsManager.set_volume("UI", value)
	_refresh_labels()

# ─── 语言（M4.1：MSF I18N 系统） ───

func _refresh_language_options() -> void:
	language_option.clear()
	language_option.add_item(tr("settings.language_zh"))
	language_option.set_item_metadata(0, "zh")
	language_option.add_item(tr("settings.language_en"))
	language_option.set_item_metadata(1, "en")
	language_option.select(0 if SettingsManager.get_language() == "zh" else 1)

func _on_language_selected(index: int) -> void:
	var code := str(language_option.get_item_metadata(index))
	SettingsManager.set_language(code)
	AudioDirector.play_ui_select()

func _on_language_changed(_lang_code: String) -> void:
	_apply_texts()
	_refresh_language_options()

# ─── 键位（M4.2：GUIDE remapping；move/switch 已合单 mapping，index 唯一） ───

func _rebuild_key_rows() -> void:
	for child in keys_list.get_children():
		child.queue_free()
	for item in InputSettings.get_items():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		keys_list.add_child(row)

		var label := Label.new()
		label.custom_minimum_size = Vector2(190.0, 0.0)
		label.text = _row_label(item)
		label.add_theme_font_size_override("font_size", 15)
		row.add_child(label)

		var key_button := Button.new()
		key_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_button.text = InputSettings.get_bound_label(item)
		key_button.focus_mode = Control.FOCUS_ALL
		key_button.pressed.connect(_on_key_button_pressed.bind(item, key_button))
		row.add_child(key_button)

		var reset := Button.new()
		reset.text = "↺"
		reset.tooltip_text = tr("settings.key.reset_one")
		reset.focus_mode = Control.FOCUS_ALL
		reset.pressed.connect(_on_key_reset_pressed.bind(item))
		row.add_child(reset)

func _row_label(item) -> String:
	var action_name := StringName(str(item.action.name))
	if action_name == &"move":
		match int(item.index):
			0: return tr("settings.key.move_up")
			1: return tr("settings.key.move_down")
			2: return tr("settings.key.move_left")
			_: return tr("settings.key.move_right")
	if action_name == &"switch_weapon":
		return tr("settings.key.slot").format([int(item.index) + 1])
	match action_name:
		&"shoot":
			return tr("settings.key.shoot")
		&"pause":
			return tr("settings.key.pause")
		&"reload":
			return tr("settings.key.reload")
		&"interact":
			return tr("settings.key.interact")
		&"aim":
			return tr("settings.key.aim")
		&"cycle_facility":
			return tr("settings.key.cycle_facility")
		&"process_action":
			return tr("settings.key.process")
		&"clear_action":
			return tr("settings.key.clear")
		&"prev_device_action":
			return tr("settings.key.prev_device")
		&"next_device_action":
			return tr("settings.key.next_device")
	return str(item.action.display_name)

func _on_key_button_pressed(item, button: Button) -> void:
	AudioDirector.play_ui_select()
	InputSettings.abort_detection()
	InputSettings.start_detection(item)
	button.text = tr("settings.key.press")

func _on_key_reset_pressed(item) -> void:
	AudioDirector.play_ui_select()
	InputSettings.reset_item(item)

func _on_reset_all_pressed() -> void:
	AudioDirector.play_ui_select()
	InputSettings.reset_all_bindings()
