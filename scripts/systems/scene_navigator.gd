extends Node
## M4 场景流转（autoload；D-M4-12）：主菜单 ↔ 战斗场景切换
## - change_scene_to_file，不重启引擎；Net autoload 常驻复用
## - 切换前统一清理：暂停态复位、面板/覆盖层清空（GameSession._exit_tree 自清 GUIDE/光标）
## - go_to_battle 不重置 Net：由调用方决定单机/房间（主菜单已配置好 Net.mode）

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const BATTLE_SCENE := "res://scenes/world/main.tscn"

func go_to_menu() -> void:
	var tree := get_tree()
	tree.paused = false
	UIManager.close_all()
	UIManager.remove_overlay(Bulwark.loc(Bulwark.UI_HUD))
	Net.stop_session()
	tree.change_scene_to_file(MENU_SCENE)

func go_to_battle() -> void:
	var tree := get_tree()
	tree.paused = false
	UIManager.close_all()
	UIManager.remove_overlay(Bulwark.loc(Bulwark.UI_HUD))
	tree.change_scene_to_file(BATTLE_SCENE)
