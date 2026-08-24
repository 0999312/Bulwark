class_name ResultPanel
extends BaseModalPanel
## 本局结算面板（UIManager POPUP 层；胜利/失败，P7 主判定 = 基地耐久归零）

@onready var title_label: Label = %TitleLabel
@onready var stats_label: Label = %StatsLabel
@onready var restart_button: Button = %RestartButton

var _data: Dictionary = {}

func _ready() -> void:
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)
	restart_button.text = tr("result.restart")
	%MenuButton.text = tr("result.menu")

func _on_open(data: Dictionary = {}) -> void:
	super(data)
	_data = data
	_refresh_texts()
	restart_button.grab_focus()

func _on_close() -> void:
	super()
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)
	_data.clear()

func _on_language_changed(_event: LanguageChangedEvent) -> void:
	restart_button.text = tr("result.restart")
	%MenuButton.text = tr("result.menu")
	_refresh_texts()

func _refresh_texts() -> void:
	var victory: bool = _data.get("victory", false)
	if victory:
		title_label.text = tr("result.victory_title")
		title_label.add_theme_color_override("font_color", UiPalette.ACCENT_BRIGHT)
	else:
		title_label.add_theme_color_override("font_color", UiPalette.DANGER_SOFT)
		var reason: int = _data.get("reason", RunDefeatEvent.Reason.BASE_DESTROYED)
		match reason:
			RunDefeatEvent.Reason.BASE_DESTROYED:
				title_label.text = tr("result.defeat_base")
			_:
				title_label.text = tr("result.defeat_player")
	var stats: Dictionary = _data.get("stats", {})
	if not stats.is_empty():
		stats_label.text = UiText.text("result.stats", [
			int(stats.get("wave", 0)),
			int(stats.get("kills", 0)),
			int(stats.get("credits", 0)),
			int(stats.get("material", 0)),
		])
	else:
		stats_label.text = ""

func _on_restart_pressed() -> void:
	# 先取 tree 引用：close_panel 会把本面板移出场景树，之后再 get_tree() 会得到 null
	var tree := get_tree()
	UIManager.close_panel(panel_id)
	tree.paused = false
	tree.reload_current_scene()

## M4：结算返回主菜单（Net 会话由 SceneNavigator 统一关闭）
func _on_menu_pressed() -> void:
	AudioDirector.play_ui_select()
	SceneNavigator.go_to_menu()
