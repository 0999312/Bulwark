extends Node
## Net 多人会话（autoload；架构 §2.3 预定的 Net 会话骨架，M2 最小可用版）
## - 房主即服务器（listen server）：host（--net=host [--port=N]）create_server；
##   client（--net=client [--port=N] [--address=<host-ip>]）join，默认 127.0.0.1 = 本机双开；
##   局域网联机时传 host 的局域网 IP（M2 验收项：IP 直连）
## - 权威模型：host 权威。client 只发意图（intent_relay RPC）；host→client 走快照/事件通道
## - process_mode = ALWAYS：host 暂停树（波间商店/暂停）期间仍收发 RPC，意图不丢
## - 玩家身份：host = player_id 0；客户端 = peer_id - 1（首个客户端 = 1，M2 固定双人）
## - 单机（无 --net 参数）= OFFLINE：无网络层，GameSession 走 host 逻辑（M1 行为不变）

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

var mode: Mode = Mode.OFFLINE
var port := DEFAULT_PORT
var host_address := DEFAULT_ADDRESS
var multiplayer_ok := false

## client 侧：host 分配的玩家 id（-1 = 未分配；M2 首个客户端 = 1）
var assigned_player_id := -1

## 连接状态信号（GameSession 订阅：host 等客户端连上再开跑；client 连上后开始镜像）
signal host_started
signal connected_to_host
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
## client 侧：host 已分配玩家 id（收到后装配镜像；重载场景时已分配则直接装配）
signal player_id_assigned(pid: int)

## host 侧：peer_id -> player_id（ENet peer id 为随机大数，不能从 id 推导玩家序号）
var _peer_player_map: Dictionary = {}
var _next_player_id := 0

## host 侧：意图处理器（GameSession 注入；player_id 由发送者推导，不信任客户端自报）
var _intent_handler: Callable
## client 侧：快照/事件接收回调（GameSession client 分支注入）
var _state_received: Callable
var _event_received: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var net_arg := _get_arg_value(args, "--net")
	match net_arg:
		"host":
			_start_host(args)
		"client":
			_join_host(args)
		_:
			mode = Mode.OFFLINE

func _exit_tree() -> void:
	if multiplayer_ok and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	multiplayer_ok = false
	mode = Mode.OFFLINE

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

# ─── 启动 ───

func _start_host(args: PackedStringArray) -> void:
	mode = Mode.HOST
	port = int(_get_arg_value(args, "--port", str(DEFAULT_PORT)))
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Net: host 启动失败（端口 %d）err=%d" % [port, err])
		mode = Mode.OFFLINE
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer_ok = true
	print("[Net] host 就绪：端口 %d，等待客户端…" % port)
	host_started.emit()

## host：客户端接入 → 分配玩家 id 并下发（ENet peer id 随机，玩家序号由 host 统一分配）
func _on_peer_connected(peer_id: int) -> void:
	print("[Net] t=%d 客户端接入 peer=%d" % [Time.get_ticks_msec(), peer_id])
	_next_player_id += 1
	_peer_player_map[peer_id] = _next_player_id
	rpc_id(peer_id, "assign_player_id", _next_player_id)
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
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

func _join_host(args: PackedStringArray) -> void:
	mode = Mode.CLIENT
	port = int(_get_arg_value(args, "--port", str(DEFAULT_PORT)))
	host_address = _get_arg_value(args, "--address", DEFAULT_ADDRESS)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host_address, port)
	if err != OK:
		push_error("Net: client 启动失败 err=%d" % err)
		mode = Mode.OFFLINE
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func() -> void:
		print("[Net] t=%d 已连接 host（peer=%d）" % [Time.get_ticks_msec(), multiplayer.get_unique_id()])
		connected_to_host.emit())
	multiplayer.connection_failed.connect(func() -> void:
		print("[Net] t=%d 连接失败" % Time.get_ticks_msec()))
	multiplayer.server_disconnected.connect(func() -> void:
		print("[Net] t=%d 与 host 断开" % Time.get_ticks_msec()))
	multiplayer_ok = true
	print("[Net] t=%d client 连接 %s:%d…" % [Time.get_ticks_msec(), host_address, port])

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
# ─── host → client：快照（unreliable，20Hz 全量）与事件（reliable） ───

func send_snapshot(payload: Dictionary) -> void:
	if not is_host() or not multiplayer_ok:
		return
	if multiplayer.get_peers().is_empty():
		return
	# reliable：全量快照（含敌人列表）可能超过 ENet MTU（1392B），reliable 自动分片重组；
	# unreliable 下大包会被直接丢弃（冒烟实测 1675B → 客户端收不到）。带宽分级留 M6
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
@rpc("any_peer", "call_local", "reliable")
func handle_event(event_name: String, bytes: PackedByteArray) -> void:
	if not is_client() or not multiplayer_ok:
		return
	if multiplayer.get_remote_sender_id() != HOST_PEER_ID:
		return
	if _event_received.is_valid():
		_event_received.call(StringName(event_name), NetCodec.unpack_event(bytes))
