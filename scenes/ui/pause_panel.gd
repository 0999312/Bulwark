class_name PausePanel
extends UIPanel
## 暂停面板（UIManager POPUP 层；Esc 由 GameSession 轮询 GUIDE 动作切换）

func _on_resume_pressed() -> void:
	# 先取 tree 引用：close_panel 会把本面板移出场景树
	var tree := get_tree()
	tree.paused = false
	UIManager.close_panel(panel_id)
