extends Node
## Net 多人会话（autoload；架构 §2.3 预定的 Net 会话骨架，M2 最小可用版 → M4 可编程 API 重构）
## - M4：命令行参数保留为兜底（--net=host|client [--port] [--address] [--relay] [--relay-url] [--app-id]），
##   UI 走可编程 API：Net.start_host(options) / Net.join_host(options) / Net.stop_session()
## - 房主即服务器（listen server）：host create_server；client join，默认 127.0.0.1 = 本机双开；
##   局域网联机传 host 的局域网 IP
## - M3 问题 5：互联网 P2P（NodeTunnel）——relay 模式 NodeTunnelPeer 直接替换 ENetMultiplayerPeer，
##   高层 RPC/信号语义一致，权威模型不变；loopback/局域网路径不破坏
## - 权威模型：host 权威。client 只发意图（intent_relay RPC）；host→client 走快照/事件通道
## - process_mode = ALWAYS：host 暂停树期间仍收发 RPC，意图不丢
## - 玩家身份：host = player_id 0；客户端 = peer_id - 1（首个客户端 = 1，M2 固定双人）
## - 单机（无 --net 且未调 API）= OFFLINE：GameSession 走 host 逻辑（M1 行为不变）

enum Mode {
	OFFLINE = 0,
	HOST = 1,
	CLIENT = 2,
}

const DEFAULT_PORT := 31007
const DEFAULT_ADDRESS := "127.0.0.1"
const HOST_PEER_ID := 1
## M2 固定双人：host + 1 客户端（多人上限留 M6）
const MAX_CLIENTS := 1
## M3 问题 5：NodeTunnel relay 默认地址（公共 relay；可用 --relay-url 覆盖，自部署兜底）
const DEFAULT_RELAY := "us-east.nodetunnel.io:8080"
## M3 问题 5：relay 应用标识（NodeTunnel 按 app_id 隔离房间空间；冲突会导致串房）
## M4.1：换为开发者提供的有效 token（原 "bulwark_frontline" 在 relay 端无效）
const DEFAULT_APP_ID := "75wszckt2unslne"

var mode: Mode = Mode.OFFLINE
var port := DEFAULT_PORT
var host_address := DEFAULT_ADDRESS
var multiplayer_ok := false

## M3 问题 5：relay 模式开关与配置
var use_relay := false
var relay_address := DEFAULT_RELAY
var app_id := DEFAULT_APP_ID
## host 侧：relay 房间码（client 用 address=房间码 加入；房间 UI 展示）
var room_id := ""

## client 侧：host 分配的玩家 id（-1 = 未分配；首个客户端 = 1）
var assigned_player_id := -1

## 连接状态信号（GameSession 订阅：host 等客户端连上再开跑；client 连上后开始镜像）
signal host_started
signal connected_to_host
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
## client 侧：host 已分配玩家 id（收到后装配镜像；重载场景时已分配则直接装配）
signal player_id_assigned(pid: int)
## M4：启动/连接失败（房间 UI 展示；不再只有 push_error）
signal net_failed(message: String)

## host 侧：peer_id -> player_id（ENet peer id 为随机大数，不能从 id 推导玩家序号）
var _peer_player_map: Dictionary = {}
var _next_player_id := 0

## host 侧：意图处理器（GameSession 注入；player_id 由发送者推导，不信任客户端自报）
var _intent_handler: Callable
## client 侧：快照/事件接收回调（GameSession client 分支注入）
var _state_received: Callable
var _event_received: Callable
## M3 问题 3：敌人快照独立通道接收回调（敌人 10Hz 中频，与玩家 20Hz 高频解耦降带宽）
var _enemies_received: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var net_arg := _get_arg_value(args, "--net")
	if net_arg.is_empty():
		return
	# M3 问题 5：--relay 布尔开关（存在即启用 NodeTunnel relay 模式）
	use_relay = args.has("--relay")
	# mode 必须同步设置：GameSession._ready（场景装配）依赖 is_host/is_client 判定分支，
	# 若随 relay 连接一起延迟，场景会按 OFFLINE 单机装配并立即开跑
	match net_arg:
		"host":
			mode = Mode.HOST
			if use_relay:
				# 预防性延迟一帧（autoload _ready 处于引擎初始化早期）
				await get_tree().process_frame
			start_host(_options_from_cli(args))
		"client":
			mode = Mode.CLIENT
			if use_relay:
				await get_tree().process_frame
			join_host(_options_from_cli(args))
		_:
			mode = Mode.OFFLINE

func _options_from_cli(args: PackedStringArray) -> Dictionary:
	return {
		"port": int(_get_arg_value(args, "--port", str(AppConfig.get_net_port()))),
		"address": _get_arg_value(args, "--address", AppConfig.get_net_address()),
		"relay": use_relay,
		"relay_url": _get_arg_value(args, "--relay-url", AppConfig.get_relay_url()),
		"app_id": _get_arg_value(args, "--app-id", AppConfig.get_app_id()),
	}

func _exit_tree() -> void:
	stop_session()

# ─── 查询 ───

func is_online() -> bool:
	return mode != Mode.OFFLINE

func is_host() -> bool:
	return mode == Mode.HOST

func is_client() -> bool:
	return mode == Mode.CLIENT

## 本进程负责的玩家 id：host = 0；client = host 分配的 id（分配前 = -1）
func get_local_player_id() -> int:
	if mode == Mode.CLIENT:
		return assigned_player_id
	return 0

## 是否有已连接的客户端（host 侧判定双人缩放/开始条件）
func has_connected_client() -> bool:
	if not is_host() or not multiplayer_ok:
		return false
	return not multiplayer.get_peers().is_empty()

# ─── M4 可编程 API ───

## 创建房间（host）。
## options：{port:int, relay:bool, relay_url:String, app_id:String}
func start_host(options: Dictionary = {}) -> void:
	_reset_session()
	mode = Mode.HOST
	port = int(options.get("port", AppConfig.get_net_port()))
	use_relay = bool(options.get("relay", false))
	relay_address = str(options.get("relay_url", AppConfig.get_relay_url()))
	app_id = str(options.get("app_id", AppConfig.get_app_id()))
	if use_relay:
		_start_relay_host()
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		mode = Mode.OFFLINE
		push_error("Net: host 启动失败（端口 %d）err=%d" % [port, err])
		net_failed.emit(UiText.text("net.error_port_in_use", [port, err]))
		return
	_attach_peer(peer)
	multiplayer_ok = true
	print("[Net] host 就绪：端口 %d，等待客户端…" % port)
	host_started.emit()

## 加入房间（client）。
## options：{address:String(局域网 IP 或 relay 房间码), port:int, relay:bool, relay_url:String, app_id:String}
func join_host(options: Dictionary = {}) -> void:
	_reset_session()
	mode = Mode.CLIENT
	port = int(options.get("port", AppConfig.get_net_port()))
	host_address = str(options.get("address", AppConfig.get_net_address()))
	use_relay = bool(options.get("relay", false))
	relay_address = str(options.get("relay_url", AppConfig.get_relay_url()))
	app_id = str(options.get("app_id", AppConfig.get_app_id()))
	if use_relay:
		_join_relay_host()
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_address, port)
	if err != OK:
		mode = Mode.OFFLINE
		push_error("Net: client 启动失败 err=%d" % err)
		net_failed.emit(UiText.text("net.error_connect", [host_address, port, err]))
		return
	_attach_peer(peer)
	multiplayer_ok = true
	print("[Net] t=%d client 连接 %s:%d…" % [Time.get_ticks_msec(), host_address, port])

## 结束当前网络会话（回主菜单/换房前调用）；不影响进程常驻与后续再建房
func stop_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	multiplayer_ok = false
	_peer_player_map.clear()
	_next_player_id = 0
	room_id = ""
	assigned_player_id = -1
	mode = Mode.OFFLINE

## 内部：先停旧会话并复位状态（不触发 mode 抖动）
func _reset_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	multiplayer_ok = false
	_peer_player_map.clear()
	_next_player_id = 0
	room_id = ""
	assigned_player_id = -1

func _attach_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected_to_server() -> void:
	print("[Net] t=%d 已连接 host（peer=%d）" % [Time.get_ticks_msec(), multiplayer.get_unique_id()])
	connected_to_host.emit()

func _on_connection_failed() -> void:
	print("[Net] t=%d 连接失败" % Time.get_ticks_msec())
	net_failed.emit(UiText.text("net.error_connect_failed", [host_address, port]))

func _on_server_disconnected() -> void:
	print("[Net] t=%d 与 host 断开" % Time.get_ticks_msec())
	net_failed.emit(UiText.text("net.error_disconnected"))

## host：客户端接入 → 分配玩家 id 并下发（ENet peer id 随机，玩家序号由 host 统一分配）
func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return  # client 端也会收到 peer_connected（host 接入），只允许 host 分配身份
	print("[Net] t=%d 客户端接入 peer=%d" % [Time.get_ticks_msec(), peer_id])
	_next_player_id += 1
	_peer_player_map[peer_id] = _next_player_id
	rpc_id(peer_id, "assign_player_id", _next_player_id)
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	print("[Net] t=%d 客户端断开 peer=%d" % [Time.get_ticks_msec(), peer_id])
	_peer_player_map.erase(peer_id)
	peer_disconnected.emit(peer_id)

## client：接收 host 分配的玩家 id（仅 host 可调用）
@rpc("authority", "call_local", "reliable")
func assign_player_id(pid: int) -> void:
	if not is_client():
		return
	assigned_player_id = pid
	print("[Net] t=%d 分配玩家 id=%d" % [Time.get_ticks_msec(), pid])
	player_id_assigned.emit(pid)

# ─── relay（NodeTunnel；M3 问题 5，M4 纳入可编程 API） ───

func _start_relay_host() -> void:
	var peer := _make_relay_peer()
	peer.connect_to_relay(relay_address, app_id)
	_attach_peer(peer)
	multiplayer_ok = true
	print("[Net] relay host：连接 %s（app=%s）…" % [relay_address, app_id])
	_host_relay_flow(peer)

func _host_relay_flow(peer: NodeTunnelPeer) -> void:
	await peer.authenticated
	print("[Net] relay 已认证，创建房间…")
	peer.host_room(true, "Bulwark Frontline")
	await peer.room_connected
	room_id = peer.room_id
	print("[Net] relay 房间已创建 room_id=%s（client 加入：--net=client --relay --address=%s）"
		% [room_id, room_id])
	host_started.emit()

func _join_relay_host() -> void:
	var peer := _make_relay_peer()
	peer.connect_to_relay(relay_address, app_id)
	_attach_peer(peer)
	multiplayer_ok = true
	print("[Net] t=%d client 连接 relay %s，加入房间 %s…" % [Time.get_ticks_msec(), relay_address, host_address])
	_client_relay_flow(peer)

func _client_relay_flow(peer: NodeTunnelPeer) -> void:
	await peer.authenticated
	print("[Net] relay 已认证，加入房间 %s…" % host_address)
	var jerr := peer.join_room(host_address)
	if jerr != OK:
		push_error("NodeTunnel 加入房间失败 err=%d" % jerr)
		net_failed.emit(UiText.text("net.error_join_room", [jerr]))
		return
	await peer.room_connected
	print("[Net] t=%d 已加入房间 %s（peer=%d）" % [Time.get_ticks_msec(), host_address, multiplayer.get_unique_id()])
	connected_to_host.emit()

## M3 问题 5：统一构造 NodeTunnelPeer（错误信号接线；其余与 ENet 路径一致）
func _make_relay_peer() -> NodeTunnelPeer:
	var peer := NodeTunnelPeer.new()
	peer.error.connect(func(error_msg: String) -> void:
		push_error("NodeTunnel 错误: %s" % error_msg)
		net_failed.emit(UiText.text("net.error_relay", [error_msg])))
	return peer

## 解析 user args 的 key=value；缺失返回 default_value
func _get_arg_value(args: PackedStringArray, key: String, default_value := "") -> String:
	for arg in args:
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return default_value

# ─── 注入回调（GameSession 装配） ───

func set_intent_handler(handler: Callable) -> void:
	_intent_handler = handler

func set_state_receiver(receiver: Callable) -> void:
	_state_received = receiver

func set_event_receiver(receiver: Callable) -> void:
	_event_received = receiver

func set_enemies_receiver(receiver: Callable) -> void:
	_enemies_received = receiver

# ─── 意图（client → host） ───

## 客户端发意图（player_id 由 host 从发送者推导，客户端不传）
func send_intent(intent: StringName, args: Array = []) -> void:
	if not is_client() or not multiplayer_ok:
		return
	if multiplayer.multiplayer_peer == null \
			or multiplayer.multiplayer_peer.get_connection_status() \
			!= MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		return  # 连接握手未完成/断开时静默丢弃（headless 冒烟下避免刷屏）
	rpc_id(HOST_PEER_ID, "intent_relay", intent, args)

@rpc("any_peer", "call_local", "reliable")
func intent_relay(intent: StringName, args: Array) -> void:
	if not is_host() or not multiplayer_ok:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _peer_player_map.has(sender_id):
		return
	var pid: int = _peer_player_map[sender_id]
	if _intent_handler.is_valid():
		_intent_handler.call(pid, intent, args)

# ─── host → client：快照（reliable）与事件（reliable） ───

func send_snapshot(payload: Dictionary) -> void:
	if not is_host() or not multiplayer_ok:
		return
	if multiplayer.get_peers().is_empty():
		return
	# reliable：全量快照可能超过 ENet MTU（1392B），reliable 自动分片重组；
	# unreliable 下大包会被直接丢弃。带宽分级留 M6
	rpc("sync_state", NetCodec.pack_snapshot(payload))

func send_event(event_name: String, payload: Dictionary) -> void:
	if not is_host() or not multiplayer_ok:
		return
	if multiplayer.get_peers().is_empty():
		return
	rpc("handle_event", event_name, NetCodec.pack_event(payload))

@rpc("any_peer", "call_local", "reliable")
func sync_state(bytes: PackedByteArray) -> void:
	if not is_client() or not multiplayer_ok:
		return
	if multiplayer.get_remote_sender_id() != HOST_PEER_ID:
		return
	if _state_received.is_valid():
		_state_received.call(NetCodec.unpack_snapshot(bytes))

## M3 问题 3：敌人快照独立通道（host 10Hz 中频发送，client 单独接收）
func send_enemies(payload: Dictionary) -> void:
	if not is_host() or not multiplayer_ok:
		return
	if multiplayer.get_peers().is_empty():
		return
	rpc("sync_enemies", NetCodec.pack_snapshot(payload))

@rpc("any_peer", "call_local", "reliable")
func sync_enemies(bytes: PackedByteArray) -> void:
	if not is_client() or not multiplayer_ok:
		return
	if multiplayer.get_remote_sender_id() != HOST_PEER_ID:
		return
	if _enemies_received.is_valid():
		_enemies_received.call(NetCodec.unpack_snapshot(bytes))

@rpc("any_peer", "call_local", "reliable")
func handle_event(event_name: String, bytes: PackedByteArray) -> void:
	if not is_client() or not multiplayer_ok:
		return
	if multiplayer.get_remote_sender_id() != HOST_PEER_ID:
		return
	if _event_received.is_valid():
		_event_received.call(StringName(event_name), NetCodec.unpack_event(bytes))
