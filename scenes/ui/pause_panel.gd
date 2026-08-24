class_name PausePanel
extends BaseModalPanel
## 暂停面板（UIManager POPUP 层；Esc 由 GameSession 轮询 GUIDE 动作切换）
## M2 多人：client 的暂停面板只发恢复意图（host 裁决）；面板关闭由本地请求状态 + ui_state 驱动
## M3 问题 2：暂停改为"请求"语义——点继续 = 取消自己的暂停请求；
## host 汇总全员请求才冻结树，任一取消即恢复（_toggle_pause 处理）

func _ready() -> void:
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)
	_apply_texts()

func _on_open(data: Dictionary = {}) -> void:
	super(data)

func _on_close() -> void:
	super()
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)

func _on_language_changed(_event: LanguageChangedEvent) -> void:
	_apply_texts()

func _apply_texts() -> void:
	# M4.1：文案走 tr()（语言切换即时生效）
	%TitleLabel.text = tr("pause.title")
	%ResumeButton.text = tr("pause.resume")
	%SettingsButton.text = tr("pause.settings")
	%MenuButton.text = tr("pause.menu")

func _on_resume_pressed() -> void:
	if Net.is_client():
		# 本地立即取消请求（关面板），host 汇总后广播暂停态
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_toggle_pause_local"):
			scene._toggle_pause_local()
		Net.send_intent(&"toggle_pause")
		return
	# host/单机：走请求语义（取消自己的请求；单机 = 直接恢复，与 M1 一致）
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_toggle_pause"):
		scene._toggle_pause()
		return
	var tree := get_tree()
	tree.paused = false
	UIManager.close_panel(panel_id)

## M4：暂停内设置入口（设置面板压在本面板上方，返回即恢复暂停栈）
func _on_settings_pressed() -> void:
	AudioDirector.play_ui_select()
	UIManager.open_panel(Bulwark.loc(Bulwark.UI_SETTINGS))

## M4：放弃本局回主菜单（Net 会话由 SceneNavigator 统一关闭）
func _on_menu_pressed() -> void:
	AudioDirector.play_ui_select()
	SceneNavigator.go_to_menu()
