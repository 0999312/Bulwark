extends Control
## M4 主菜单（议题 4，D-M4-12/13/14/15 + M4.1 修订）：
## - 单机 / 多人房间（局域网 IP 直连 + Relay 房间码）/ 设置 / 退出
## - 设置面板复用 UIManager 的 UI_SETTINGS（与暂停面板同面板，语言/音量/键位齐全）
## - Net 可编程 API（start_host / join_host / stop_session）经本界面驱动；CLI 参数保留兜底
## - 文案全部走 tr()（locales/zh.json、en.json），语言切换即时生效

@onready var main_buttons: VBoxContainer = %MainButtons
@onready var endless_button: Button = %EndlessButton
@onready var meta_label: Label = %MetaLabel
@onready var room_panel: PanelContainer = %RoomPanel
@onready var mode_option: OptionButton = %ModeOption
@onready var create_port_edit: LineEdit = %CreatePortEdit
@onready var room_code_label: Label = %RoomCodeLabel
@onready var go_button: Button = %GoButton
@onready var join_address_label: Label = %JoinAddressLabel
@onready var join_address_edit: LineEdit = %JoinAddressEdit
@onready var join_port_edit: LineEdit = %JoinPortEdit
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioDirector.play_menu_music()
	# 设置面板走 UIManager：需要 UIRegistry 已注册（GameSession 之外的主菜单首屏也要注册一次）
	ContentBootstrap.register_all()
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)
	_apply_texts()
	_apply_military_skin()
	%SingleButton.pressed.connect(_on_single_pressed)
	%EndlessButton.pressed.connect(_on_endless_pressed)
	%MultiButton.pressed.connect(_on_multi_pressed)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%CreateButton.pressed.connect(_on_create_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	go_button.pressed.connect(_on_go_pressed)
	%RoomBackButton.pressed.connect(_show_main)
	mode_option.item_selected.connect(_on_mode_selected)
	Net.host_started.connect(_on_host_started)
	Net.connected_to_host.connect(_on_connected_to_host)
	Net.net_failed.connect(_on_net_failed)
	_refresh_mode_fields()
	%SingleButton.grab_focus()
	# CLI 兜底：--net=host|client 时主菜单直接进战场（兼容 run-dual / 冒烟脚本）
	var net_cli := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--net" or arg.begins_with("--net="):
			net_cli = true
			break
	if net_cli and Net.is_online():
		call_deferred("_enter_battle")

func _on_language_changed(_event: LanguageChangedEvent) -> void:
	_apply_texts()
	_refresh_mode_texts()

func _apply_texts() -> void:
	%TitleLabel.text = tr("menu.title")
	%SubLabel.text = UiText.text("menu.subtitle")
	%SingleButton.text = tr("menu.single")
	%EndlessButton.text = tr("menu.endless")
	%MultiButton.text = tr("menu.multi")
	%SettingsButton.text = tr("menu.settings")
	%QuitButton.text = tr("menu.quit")
	%VersionLabel.text = tr("menu.version")
	_refresh_meta_text()
	%RoomTitle.text = tr("room.title")
	%ModeLabel.text = tr("room.mode_label")
	%CreateTitle.text = tr("room.create_title")
	%CreatePortLabel.text = tr("room.port")
	%CreateButton.text = tr("room.create_button")
	%GoButton.text = tr("room.go_battle")
	%JoinTitle.text = tr("room.join_title")
	%JoinPortLabel.text = tr("room.port")
	%JoinButton.text = tr("room.join_button")
	%RoomBackButton.text = tr("room.back")

## M2 军事化皮肤（去图标/去条纹版本）：标题描边 + 入场动效（一次性，非每帧）
func _apply_military_skin() -> void:
	%TitleLabel.add_theme_constant_override("outline_size", 6)
	%TitleLabel.add_theme_color_override("font_outline_color", Color(0.97, 0.95, 0.89, 0.95))
	_play_entrance()

## 标题/按钮入场（≤250ms，一次性）
func _play_entrance() -> void:
	var title := %TitleLabel
	title.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.25)
	var i := 0
	for btn: Variant in [%SingleButton, %EndlessButton, %MultiButton, %SettingsButton, %QuitButton]:
		var b := btn as Button
		if b == null:
			continue
		b.modulate.a = 0.0
		b.scale = Vector2(0.98, 0.98)
		var tw2 := create_tween()
		tw2.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw2.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.08 + i * 0.03)
		tw2.parallel().tween_property(b, "scale", Vector2.ONE, 0.2).set_delay(0.08 + i * 0.03)
		i += 1

func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)
	if Net.host_started.is_connected(_on_host_started):
		Net.host_started.disconnect(_on_host_started)
	if Net.connected_to_host.is_connected(_on_connected_to_host):
		Net.connected_to_host.disconnect(_on_connected_to_host)
	if Net.net_failed.is_connected(_on_net_failed):
		Net.net_failed.disconnect(_on_net_failed)

# ─── 导航 ───

func _show_main() -> void:
	main_buttons.visible = true
	room_panel.visible = false
	%SingleButton.grab_focus()

func _on_single_pressed() -> void:
	Net.stop_session()
	RunConfig.prepare_arcade()
	_enter_battle()

func _on_endless_pressed() -> void:
	Net.stop_session()
	RunConfig.prepare_endless()
	_enter_battle()

## P2-18 meta 进度展示（货币 + 下一个未解锁起始武器）
func _refresh_meta_text() -> void:
	var credits := MetaProgress.get_meta_credits()
	var next := MetaProgress.get_next_unlock_name()
	if next.is_empty():
		meta_label.text = UiText.text("menu.meta_all_unlocked", [credits])
	else:
		meta_label.text = UiText.text("menu.meta_progress", [credits, next])

func _on_multi_pressed() -> void:
	main_buttons.visible = false
	room_panel.visible = true
	status_label.text = ""
	go_button.visible = false
	%CreateButton.disabled = false
	_refresh_mode_fields()
	%CreateButton.grab_focus()

func _on_settings_pressed() -> void:
	AudioDirector.play_ui_select()
	# 复用 UIManager 设置面板（音量/语言/键位；返回键自动回到主菜单层）
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_SETTINGS))

func _on_quit_pressed() -> void:
	get_tree().quit()

func _enter_battle() -> void:
	SceneNavigator.go_to_battle()

# ─── 房间（局域网 / Relay） ───

func _on_mode_selected(_index: int) -> void:
	AudioDirector.play_ui_select()
	_refresh_mode_fields()

func _is_relay_mode() -> bool:
	return mode_option.selected == 1

func _refresh_mode_fields() -> void:
	_refresh_mode_texts()
	var relay := _is_relay_mode()
	join_address_edit.text = "" if relay else AppConfig.get_net_address()
	create_port_edit.text = str(AppConfig.get_net_port())
	join_port_edit.text = str(AppConfig.get_net_port())
	create_port_edit.editable = not relay
	join_port_edit.editable = not relay
	room_code_label.text = ""

func _refresh_mode_texts() -> void:
	var relay := _is_relay_mode()
	mode_option.set_item_text(0, tr("room.mode_lan"))
	mode_option.set_item_text(1, tr("room.mode_relay"))
	join_address_label.text = tr("room.code_label") if relay else tr("room.ip_label")
	join_address_edit.placeholder_text = tr("room.code_placeholder") if relay else tr("room.ip_placeholder")

func _on_create_pressed() -> void:
	AudioDirector.play_ui_select()
	status_label.text = ""
	%CreateButton.disabled = true
	var options := {
		"port": int(create_port_edit.text) if create_port_edit.text.is_valid_int() else AppConfig.get_net_port(),
		"relay": _is_relay_mode(),
		"relay_url": AppConfig.get_relay_url(),
		"app_id": AppConfig.get_app_id(),
	}
	Net.start_host(options)

func _on_join_pressed() -> void:
	AudioDirector.play_ui_select()
	var relay := _is_relay_mode()
	var address := join_address_edit.text.strip_edges()
	if address.is_empty():
		status_label.add_theme_color_override("font_color", UiPalette.DANGER_SOFT)
		status_label.text = tr("room.enter_code") if relay else tr("room.enter_ip")
		return
	status_label.add_theme_color_override("font_color", UiPalette.SUCCESS)
	status_label.text = tr("room.connecting")
	Net.join_host({
		"address": address,
		"port": int(join_port_edit.text) if join_port_edit.text.is_valid_int() else AppConfig.get_net_port(),
		"relay": relay,
		"relay_url": AppConfig.get_relay_url(),
		"app_id": AppConfig.get_app_id(),
	})

func _on_go_pressed() -> void:
	AudioDirector.play_ui_select()
	RunConfig.prepare_arcade()
	_enter_battle()

func _on_host_started() -> void:
	status_label.add_theme_color_override("font_color", UiPalette.SUCCESS)
	if Net.use_relay:
		room_code_label.text = tr("room.room_code").format([Net.room_id])
		status_label.text = tr("room.created_code")
	else:
		room_code_label.text = tr("room.listening").format([Net.port])
		status_label.text = tr("room.created_lan")
	go_button.visible = true
	go_button.grab_focus()

func _on_connected_to_host() -> void:
	status_label.text = tr("room.connected")
	call_deferred("_enter_battle")

func _on_net_failed(message: String) -> void:
	status_label.add_theme_color_override("font_color", UiPalette.DANGER_SOFT)
	status_label.text = message
	go_button.visible = false
	%CreateButton.disabled = false
