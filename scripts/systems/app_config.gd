extends Node
## M4.2 根目录配置读取层（autoload）：
## - 加载 res://config.cfg（部署/联机参数，玩家可直接编辑，重启生效）
## - Net 默认值、主菜单房间字段、相机 zoom 等从本类取；缺失项回退内置默认
## - 玩家个人偏好仍在 user://（settings.cfg / input_bindings.json），不混入部署配置

const CONFIG_PATH := "res://config.cfg"

const DEFAULT_PORT := 31007
const DEFAULT_ADDRESS := "127.0.0.1"
const DEFAULT_RELAY_URL := "us-east.nodetunnel.io:8080"
const DEFAULT_APP_ID := "75wszckt2unslne"
const DEFAULT_CAMERA_ZOOM := 0.7

var _config := ConfigFile.new()

func _ready() -> void:
	var err := _config.load(CONFIG_PATH)
	if err != OK:
		push_warning("AppConfig: 未找到 %s，使用内置默认值（err=%d）" % [CONFIG_PATH, err])

func get_net_port() -> int:
	return int(_config.get_value("net", "port", DEFAULT_PORT))

func get_net_address() -> String:
	return str(_config.get_value("net", "address", DEFAULT_ADDRESS))

func get_relay_url() -> String:
	return str(_config.get_value("net", "relay_url", DEFAULT_RELAY_URL))

func get_app_id() -> String:
	return str(_config.get_value("net", "app_id", DEFAULT_APP_ID))

func get_camera_zoom() -> float:
	# 下限 0.5：1280/0.5=2560 < 地面 2800 宽，保证 Camera2D limit 钳制仍然有效（不露背景）
	return clampf(float(_config.get_value("game", "camera_zoom", DEFAULT_CAMERA_ZOOM)), 0.5, 2.0)

## Net 可编程 API 的默认选项包（UI/CLI 共用）
func get_net_defaults() -> Dictionary:
	return {
		"port": get_net_port(),
		"address": get_net_address(),
		"relay_url": get_relay_url(),
		"app_id": get_app_id(),
	}
