class_name ResultPanel
extends UIPanel
## 本局结算面板（UIManager POPUP 层；胜利/失败，P7 主判定 = 基地耐久归零）

@onready var title_label: Label = %TitleLabel
@onready var sub_label: Label = %SubLabel
@onready var restart_button: Button = %RestartButton

func _on_open(data: Dictionary = {}) -> void:
	var victory: bool = data.get("victory", false)
	if victory:
		title_label.text = "防线守住了"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
		sub_label.text = "没人发勋章，但耗子留了块饼干。"
	else:
		title_label.add_theme_color_override("font_color", Color(1, 0.52, 0.46))
		var reason: int = data.get("reason", RunDefeatEvent.Reason.BASE_DESTROYED)
		match reason:
			RunDefeatEvent.Reason.BASE_DESTROYED:
				title_label.text = "基地被啃穿了"
				sub_label.text = "它们只是饿了。"
			_:
				title_label.text = "你阵亡了"
				sub_label.text = "储备用完了，没人来扶你。"
	restart_button.grab_focus()

func _on_restart_pressed() -> void:
	# 先取 tree 引用：close_panel 会把本面板移出场景树，之后再 get_tree() 会得到 null
	var tree := get_tree()
	UIManager.close_panel(panel_id)
	tree.paused = false
	tree.reload_current_scene()
