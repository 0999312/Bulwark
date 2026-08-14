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
		sub_label.text = "3 波异变体已被击退。\n你的职责完成了——虽然没人发勋章，\n营地的耗子倒是给你留了一块饼干。\n（M1 起：波间商店与搜索循环）"
	else:
		var reason: int = data.get("reason", RunDefeatEvent.Reason.BASE_DESTROYED)
		match reason:
			RunDefeatEvent.Reason.BASE_DESTROYED:
				title_label.text = "基地被啃穿了"
				sub_label.text = "异变体不在乎你的防线，它们只是饿了。\n下一位守军（就是你）请从重建基地开始。"
			_:
				title_label.text = "你阵亡了"
				sub_label.text = "复活系统还没修好（M1 接入）。\n基地或许还在，但故事先到这里。"
	restart_button.grab_focus()

func _on_restart_pressed() -> void:
	# 先取 tree 引用：close_panel 会把本面板移出场景树，之后再 get_tree() 会得到 null
	var tree := get_tree()
	UIManager.close_panel(panel_id)
	tree.paused = false
	tree.reload_current_scene()
