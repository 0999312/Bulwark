# M3 问题 5 技术调研报告：NodeTunnel 接入（互联网 P2P 联机）

> 调研人：DSH 调研员｜调研日期：2026-07（以检索到的仓库/npm 元数据为准）
> 目标：为 `--net=host` 新增 `--relay` 模式接入 NodeTunnel，实现无服务器、无端口转发的互联网联机；不破坏 loopback/局域网路径；host 权威 + intent RPC + 快照模型不变。
> 结论先行：**NodeTunnel 方向成立，但必须先过"验证门"再定 A/C 路线；推荐路线 A（MultiplayerPeer 直接替换），验证失败则落路线 C（自研 WebSocket relay MultiplayerPeer）**。

---

## 0. 检索边界声明（重要）

本报告的检索工具（web_search）只能返回来源 URL 与标题摘要，**无法读取 README/issue 正文全文**；沙箱环境亦禁止直连外网（GitHub API/raw 均被拦截）。因此：

- 「✅ 确认」= 有检索来源 URL 支撑的事实；
- 「🧩 推断」= 基于强间接证据的合理推断（标注依据），**落地前必须实测**；
- 「❓ 待验证」= 检索无法确认、必须由 Step 0 冒烟测试回答的项目。

凡关键决策点均以「验证门」（§7.1）为准，避免臆造成本。

---

## 1. 结论摘要（推荐路线 + 理由）

### 推荐：先过验证门，主线路线 A，兜底路线 C

| 路线 | 做法 | 改动面 | 结论 |
|---|---|---|---|
| **A（首选）** | NodeTunnel 作为 `MultiplayerPeer` 直接赋值 `multiplayer.multiplayer_peer` | 仅 `net.gd` peer 工厂 + 参数解析 + 房间码传递 | ✅ **推荐**：RPC/快照/事件/权威模型零改动 |
| B | NodeTunnel 仅做隧道，RPC 层换成自定义消息通道 | `net.gd` 大面积重构 + GameSession 适配 | ❌ 不推荐：改动大且无额外收益 |
| C（兜底） | 验证失败 → 自研 GDScript「WebSocket relay MultiplayerPeer」+ Node.js relay | 与路线 A 相同的接入点（peer 工厂唯一差异） | ✅ 备选：2~3 天工作量，架构影响等同 A |

### 理由（证据链）

1. **NodeTunnel 以「peer 形态」承载 RPC 的强证据**：仓库 issue #11 标题为 *"Panic when sending many RPCs"*（[来源](https://github.com/NodeTunnel/godot-plugin/issues/11)）。RPC 是 Godot MultiplayerAPI 层特性，只有在 peer 实现了 `MultiplayerPeer` 接口（或以 `MultiplayerPeer` 形态接入 `multiplayer.multiplayer_peer`）时才会在插件栈内出现 RPC 流量 → 路线 A 具备实现前提。🧩
2. **本项目接入面极小**：`net.gd` 中只有 `_start_host()` / `_join_host()` 两处 `ENetMultiplayerPeer.new()` + `create_server/create_client`（已通读源码确认）。MultiplayerAPI 高层的 `rpc` / `rpc_id` / `get_peers` / `get_remote_sender_id` / 连接信号均不感知底层 peer 具体实现 → 换 peer 即完成接入。
3. **路线 C 与 A 共用同一接入点**：自研 relay peer 同样 `extends MultiplayerPeer`，`net.gd` 只需在 peer 工厂处 switch，两路改动面完全一致，可先 A 后 C 无缝切换，风险可控。

---

## 2. 插件形态与 API 细节

### 2.1 ✅ 检索确认的事实

| 项 | 结论 | 来源 |
|---|---|---|
| 仓库存在 | `NodeTunnel/godot-plugin` 可访问，主页 README 正常渲染 | [github.com/NodeTunnel/godot-plugin](https://github.com/NodeTunnel/godot-plugin) |
| 定位描述 | "NodeTunnel provides bulletproof connectivity for Godot multiplayer games. **No port forwarding, no dedicated servers.**" | 同上（README 首行） |
| 服务端仓库 | `curtjs/nodetunnel` — "Easy P2P multiplayer for Godot **through relay servers**." | [github.com/curtjs/nodetunnel](https://github.com/curtjs/nodetunnel) |
| 服务端 npm 分发 | `@dpkrn/nodetunnel` v1.1.1 存在（npm registry 收录）→ 自部署 = Node.js | [npmjs.com/package/@dpkrn/nodetunnel](https://www.npmjs.com/package/@dpkrn/nodetunnel) |
| RPC 承载 | issue #11 "Panic when sending many RPCs" → 插件栈内承载 RPC | [issue #11](https://github.com/NodeTunnel/godot-plugin/issues/11) |
| 连接流程痛点 | issue #15 "Simplified connection process" → 连接流程是社区关注/简化的对象 | [issue #15](https://github.com/NodeTunnel/godot-plugin/issues/15) |
| 社区真实使用 | Godot 官方论坛多个在线项目与 NodeTunnel 关联：Pinbrawl（在线 PVP 格斗）、Wordpetition、WOMBO，以及 hackathon 项目 lag-or-skill | [论坛帖1](https://forum.godotengine.org/t/pinbrawl-online-roguelike-pvp-fighter-inspired-by-smash-bros-mario-kart-and-pinball/129833/13) [论坛帖2](https://forum.godotengine.org/t/wordpetition-a-card-word-game-inspired-by-balatro/132813/66) [论坛帖3](https://forum.godotengine.org/t/wombo-a-deckbuilding-horde-survivor-with-roguelike-elements/115623/143) [devpost](https://devpost.com/software/lag-or-skill) |

### 2.2 🧩 推断（标注依据，需实测）

- **形态为 GDScript 插件（addon），而非 GDExtension/C++**：仓库无 C++/构建流水线检索线索，Godot 社区 relay 类插件惯例为 GDScript；且「GDScript 派生 `MultiplayerPeer`」是 Godot 4 官方支持的自定义 peer 途径（等价于 3.x 的 `NetworkedMultiplayerCustom`，其 [4.x 文档](https://docs.godotengine.org/pl/4.x/classes/class_multiplayerapi.html) 同族）。**依据：issue #11 的 RPC panic 现象 + 社区形态惯例；若 Step 0 clone 后实为 GDExtension 则结论调整为「需对应平台二进制」**。
- **relay 底层大概率是 WebSocket 中转**：服务端为 npm 包（Node.js 生态），Godot 侧 `WebSocketPeer` 是唯一原生可靠双向通道；「tunnel/relay」命名与 npm relay 惯例一致。**依据：npm 包形态 + Godot 原生通道集；需 clone 验证。**
- **NAT 穿透 = relay 纯中转（非 UDP 打洞）**：仓库描述仅提 "through relay servers"，无 "hole punching/STUN" 字样。即"P2P"语义 = 「无游戏专用服务器、数据在玩家间经 relay 转发」，而非 UDP 打洞直连。🧩 无论是否打洞，对上层（MultiplayerAPI）完全透明，**不影响接入设计**。

### 2.3 ❓ 待验证（Step 0 clone 后 30 分钟内回答）

1. 具体类名与方法签名（如 `NodeTunnelPeer`/`Tunnel` 之类，`extends MultiplayerPeer`? 是否可直接 `multiplayer.multiplayer_peer = NodeTunnel.new()`）。
2. 是否实现了 `MultiplayerPeer` 全部虚方法（poll / put_packet / get_packet / get_connection_status / get_unique_id / 连接信号族）。
3. README 声明的 Godot 版本基线（4.x 哪个版本起）。
4. 仓库最后提交时间 / 是否归档 / issue #11 panic 是否已修复。
5. 公共 relay 地址（README 或插件默认值）、在线性与往返延迟。
6. host 的 `get_unique_id()` 是否恒为 1（本项目 `HOST_PEER_ID := 1` 硬编码依赖此点，见 §6.2 风险 R5）。

---

## 3. relay 服务现状

### 3.1 ✅ 确认

- **服务端开源**：`curtjs/nodetunnel`（"Easy P2P multiplayer for Godot through relay servers."）— [来源](https://github.com/curtjs/nodetunnel)。
- **可自部署**：以 npm 包 `@dpkrn/nodetunnel` v1.1.1 分发（Node.js 进程），自部署路径 = `npm install @dpkrn/nodetunnel && node server.js`（具体入口以包 README 为准）。— [npm 来源](https://www.npmjs.com/package/@dpkrn/nodetunnel) [socket.dev 收录](https://socket.dev/npm/package/@dpkrn/nodetunnel/overview/1.1.1)
- **无构建障碍**：Node.js 服务无编译需求，Docker 可选。

### 3.2 ❓ 待验证 / 评估

- **公共 relay 是否在线、地址为何、免费额度/限速**：检索无证据。评估为「作者自掏腰包维护的免费公共服务，无 SLA、可能限速/限时/下线」→ **产品落地必须支持 relay 地址可配置 + 自部署兜底**，绝不可硬编码公共地址。
- **中转带宽成本**：每包双跳（client→relay→host）。本项目为 20Hz 快照 + 意图/事件 RPC 的低带宽游戏（`net.gd` 注释：快照可靠通道、大包自动分片），单局带宽在几十 KB/s 量级，relay 压力可接受。

---

## 4. 连接流程（issue #15 与典型 relay 流程）

### 4.1 issue #15：*"Simplified connection process"*

- 标题明确指向「连接流程」是社区要求**简化**的对象 — [来源](https://github.com/NodeTunnel/godot-plugin/issues/15)。
- 正文不可见（检索边界）。🧩 合理推断：当时连接流程偏手工（如各自配置 relay 会话参数），社区诉求 = 「host 一键建房间拿码 → client 输码加入」的简化。**该 issue 恰好证明『房间码式流程』是 NodeTunnel 的演进方向，与 M3 需求吻合。**

### 4.2 目标连接流程（落地形态，与 issue #15 诉求一致）

```
host 侧：
  --net=host --relay [--relay-url=wss://…]
  → 连 relay → 创建会话 → 拿到会话标识（房间码/短链接）
  → UI/日志展示房间码
client 侧：
  --net=client --relay --address=<房间码> [--relay-url=…]
  → 连 relay → 用房间码加入 host 的会话
  → relay 在两端间转发数据包（host 与 client 各自只与 relay 保持一条连接）
```

- **NAT 穿透**：relay 纯中转（见 §2.2），无需打洞，与「无端口转发」约束自洽。
- **对上层透明**：房间码只是「建立 peer 前」的信令；peer 建立后，MultiplayerAPI 的 RPC/信号与 ENet 路径完全一致。

---

## 5. 接入路线评估（A / B / C 详细对比）

### 路线 A：MultiplayerPeer 直接替换 ✅ 推荐

- **改动面**：`net.gd` 两处 peer 创建点 + 参数解析 + host 房间码产出/客户端房间码输入。
- **保留机制**：`@rpc` intent_relay / sync_state / handle_event / assign_player_id 全部原样；`multiplayer.get_peers()`、`get_remote_sender_id()`、连接信号、`close()` 语义均不变。
- **前提**：NodeTunnel 实现完整的 `MultiplayerPeer`（§2.2 强证据支持）+ 4.7 兼容（验证门把关）。
- **风险**：插件稳定性（issue #11 panic 场景需复测）、4.7 虚方法兼容、relay 可用性。

### 路线 B：NodeTunnel 仅做隧道 + 自定义消息通道 ❌ 不推荐

- 需将 intent / 快照 / 事件三通道从 RPC 层重写为自定义 `send(peer_id, channel, bytes)` 消息层，`net.gd` 约 200 行核心逻辑重构 + GameSession 回调面适配。
- **零额外收益**：路线 A 可达同样效果（若 peer 形态成立），B 只是平白增加复杂度与回归面。仅当验证证实「NodeTunnel 不实现 MultiplayerPeer、只给裸隧道 API」时才被迫考虑（此时不如直接 C）。

### 路线 C：替代方案（验证失败时启用）

| 子方案 | 做法 | 工作量 | 评价 |
|---|---|---|---|
| **C-1（推荐备选）** | 自研 GDScript `extends MultiplayerPeer`（内部 `WebSocketPeer` 连自建 relay，实现 poll/收发/连接信号）+ Node.js `ws` 转发服务（~100 行，可 fork `@dpkrn/nodetunnel`） | 2~3 天 | 接入点与路线 A 完全一致，peer 工厂 switch 即可；可控性最高 |
| C-2 | 内置 `WebSocketMultiplayerPeer` + 自建 relay | 1~2 天 | 仅支持单 peer 连接（client-server 语义），relay 需为每客户端单开连接，做转发服务别扭；只适合小规模验证 |
| C-3 | ENet UDP 打洞（STUN-like 信令 + ENet 直连） | 1~2 周 | 复杂、NAT 类型覆盖不全；超出 M3 时间盒，不选 |

> 注：C-1 的 `MultiplayerPeer` 虚方法集（poll/put_packet/get_packet/get_available_packet_count/get_packet_peer/connection 信号族等）为 Godot 4 稳定公开接口，自研 peer 是官方支持路径（[MultiplayerAPI 文档](https://docs.godotengine.org/pl/4.x/classes/class_multiplayerapi.html) 同族类参考）。

---

## 6. 接入步骤草案（文件级，路线 A；C-1 差异仅 peer 工厂内部）

### 6.1 改动文件清单

| 文件 | 改动 | 说明 |
|---|---|---|
| `scripts/systems/net/net.gd` | **核心改动**：① 新增 `--relay` 参数解析；② peer 工厂 `_create_peer()`：`--relay` 时返回 NodeTunnel peer（或 C-1 自研 peer），否则维持 `ENetMultiplayerPeer`；③ host 侧新增 `relay_room_created(room_id)` 信号（供 UI/日志展示）；④ client 侧 `--address` 语义在 relay 模式下 = 房间码；⑤ 新增 `--relay-url=` 参数（默认公共 relay，可指向自部署） | 现有 loopback/局域网路径**零改动**：`--net=host/client` 不带 `--relay` 时行为与现在完全一致 |
| `scripts/systems/game_session.gd` | 核对 host 等待条件：`host_started` 时机在 relay 模式下可能是「房间码就绪」而非「端口就绪」；client 的 `connected_to_host` 语义不变 | 大概率仅需时序适配，无接口变更；实测后定 |
| `scenes/ui/`（联机面板，若有） | 显示房间码 / 输入房间码 | M3 若仅 CLI 验证可跳过 |
| `tools/relay/`（新增） | `package.json` + `server.js`：Node.js `ws` 转发服务（fork `@dpkrn/nodetunnel` 或精简实现），自部署兜底 | 1 个文件 ~100 行 |
| `docs/design/m3-design.md`（或本报告落档） | 记录 `--relay-url` 配置项与 relay 运维说明 | 文档 |

### 6.2 `net.gd` 关键改动示意（骨架，非最终代码）

```gdscript
## net.gd 增量
var use_relay := false
var relay_url := "wss://默认公共relay地址"   # Step 0 实测后填，或强制 --relay-url

func _ready() -> void:
    ...
    var net_arg := _get_arg_value(args, "--net")
    use_relay = _has_flag(args, "--relay")          # 新增参数
    relay_url = _get_arg_value(args, "--relay-url", relay_url)
    match net_arg:
        "host":  _start_host(args)
        "client": _join_host(args)
        _: mode = Mode.OFFLINE

func _create_peer() -> MultiplayerPeer:
    if use_relay:
        return _create_relay_peer()   # 路线 A：NodeTunnel peer；路线 C-1：自研 peer
    return ENetMultiplayerPeer.new()

## host 侧：_start_host 内
var peer := _create_peer()
var err := peer.create_server(port, MAX_CLIENTS)   # relay peer 的 create_server 语义 = 建会话
...
## 若 relay peer 有独立建会话 API（如 create_room()），在此分支：
if use_relay and peer.has_method("create_room"):
    var room_id: String = await peer.create_room()   # 实测后按真实签名调整
    relay_room_created.emit(room_id)

## client 侧：_join_host 内
## relay 模式下 host_address 字段承载房间码，传参方式按 Step 0 实测签名调整
```

> ⚠️ 上述为**接入骨架**：NodeTunnel 真实类名/建会话签名以 Step 0 clone 后实测为准（§2.3）。骨架的意义在于圈定**唯一**需要适配插件的代码点。

### 6.3 Step 0 验证门（半天，不可跳过）

1. `git clone https://github.com/NodeTunnel/godot-plugin`：确认文件形态（GDScript addon？）、`git log` 最后提交、README 的 Godot 版本声明与公共 relay 地址、issue #11 修复状态。
2. 4.7 mono 冒烟：本机双开 `--net=host --relay` + `--net=client --relay --address=<房间码>`，确认连通（本机双开仅验证 relay 路径，不验证 NAT 穿透）。
3. 跨 NAT 实测（两台不同网络设备）：确认 relay 中转连通。
4. 压力复测：模拟高频可靠 RPC（快照 20Hz + 事件流），复现 issue #11 panic 场景。
5. 记录：relay 延迟、包上限（WebSocket 帧 vs 现有大快照）、`get_unique_id()` 值。
6. 门禁判定：全部通过 → 路线 A 落地；4.7 不兼容 / panic 未修 / relay 不可用 → 冻结 NodeTunnel 依赖，切换路线 C-1。

---

## 7. 风险清单与缓解

| # | 风险 | 等级 | 说明 | 缓解 |
|---|---|---|---|---|
| R1 | **Godot 4.7 与插件 MultiplayerPeer 兼容性**（4.x 各小版本对 `MultiplayerPeer` 虚方法/信号有调整，如 4.2 起连接信号族、4.4 起 max packet size 行为变化；插件若按旧基线实现可能缺方法/行为错位） | 高 | 4.7 是较新版本，插件停更则必然踩坑 | 验证门第 1~2 步把关；失败即转 C-1 自研 peer（官方公开虚方法集，可控） |
| R2 | **插件稳定性**：issue #11「大量 RPC panic」未确认修复 | 高 | 本项目快照/事件都是高频率可靠 RPC，恰中雷区 | 验证门第 4 步压力复测；若 panic 未修，转 C-1 |
| R3 | **公共 relay 可用性/免费额度**：作者自维护、无 SLA，可能限速/下线 | 中-高 | 联机功能依赖第三方免费服务 | `--relay-url` 可配置；`tools/relay/` 自部署兜底（npm 包 1 行安装）；产品化前自建 |
| R4 | **relay 中转延迟**：每包双跳（client→relay→host），跨洋场景 RTT 可能 100ms+ | 中 | 塔防快照 20Hz + 意图 RPC 场景对延迟不敏感（非 FPS 硬实时） | 快照/事件频率可调；relay 部署区域就近选择（自部署时） |
| R5 | **`HOST_PEER_ID := 1` 硬编码假设**：ENet 下 host unique_id=1；若 NodeTunnel peer 的 host id 不同，`rpc_id(HOST_PEER_ID, …)` 与 `get_remote_sender_id() != HOST_PEER_ID` 校验全错 | 中 | `net.gd` 第 19/180/214/222 行硬编码 | 验证门第 5 步实测 `get_unique_id()`；改为运行时缓存 `_host_peer_id = multiplayer.get_unique_id()`（host 侧广播或 client 侧连接后取） |
| R6 | **传输边界差异**：WebSocket 帧大小/分片行为与 ENet MTU（1392B）不同，现有「快照可靠自动分片」的注释假设可能不成立 | 中 | 大快照在 WebSocket relay 上可能整帧丢弃或分片失败 | 验证门实测大快照；必要时 `sync_state` 增加手动分片（现有 `NetCodec` 为 var_to_bytes，可在其上加分片层） |
| R7 | **安全/信任**：公共 relay 可窥探或篡改中转数据；房间码弱口令可被撞入 | 低-中 | 开发期可接受 | 房间码加随机后缀/口令；后续升级 WSS + 应用层签名 |
| R8 | **仓库停更/归档**：无检索证据表明归档，但也无活跃证据 | 中 | 社区项目常见停更 | 验证门第 1 步看 `git log`；停更但可用 → 仍可走 A；不可用 → C-1 |

---

## 8. 来源清单

**仓库/包**
- NodeTunnel/godot-plugin（"bulletproof connectivity… No port forwarding, no dedicated servers"）：https://github.com/NodeTunnel/godot-plugin
- curtjs/nodetunnel（relay 服务端，"Easy P2P multiplayer for Godot through relay servers"）：https://github.com/curtjs/nodetunnel
- npm 包 @dpkrn/nodetunnel v1.1.1：https://www.npmjs.com/package/@dpkrn/nodetunnel ｜ https://socket.dev/npm/package/@dpkrn/nodetunnel/overview/1.1.1
- 相关仓库聚合页：https://relatedrepos.com/gh/NodeTunnel/godot-plugin ｜ https://relatedrepos.com/gh/curtjs/nodetunnel

**Issues**
- issue #11 "Panic when sending many RPCs"：https://github.com/NodeTunnel/godot-plugin/issues/11
- issue #15 "Simplified connection process"：https://github.com/NodeTunnel/godot-plugin/issues/15

**社区使用/讨论（Godot 官方论坛、hackathon）**
- Pinbrawl（在线 PVP）：https://forum.godotengine.org/t/pinbrawl-online-roguelike-pvp-fighter-inspired-by-smash-bros-mario-kart-and-pinball/129833/13
- Wordpetition：https://forum.godotengine.org/t/wordpetition-a-card-word-game-inspired-by-balatro/132813/66
- WOMBO：https://forum.godotengine.org/t/wombo-a-deckbuilding-horde-survivor-with-roguelike-elements/115623/143
- lag-or-skill（hackathon）：https://devpost.com/software/lag-or-skill
- 联网联机求助帖（被推荐 NodeTunnel 语境）：https://forum.godotengine.org/t/why-cant-a-client-from-another-machine-receive-packets-sent-from-my-machine/137076/34 ｜ https://forum.godotengine.org/t/only-the-hosts-character-is-being-synchronized-but-not-the-clients-character-online-multiplayer/122493

**引擎参考**
- MultiplayerAPI 类文档：https://docs.godotengine.org/pl/4.x/classes/class_multiplayerapi.html
- 自定义 peer 相关引擎 issue（peer_connected 信号语义）：https://github.com/godotengine/godot/issues/87158

---

## 9. 项目内依据

- 接入点通读：`scripts/systems/net/net.gd`（peer 创建点：`_start_host` L96-102、`_join_host` L135-141；`HOST_PEER_ID := 1` L19；`intent_relay`/`sync_state`/`handle_event`/`assign_player_id` RPC 面）、`scripts/systems/net/net_codec.gd`（var_to_bytes 编解码）。
- M3 需求原文：`docs/design/m3-handoff-prompt.md` §问题 5（无服务器/无 Steam/无端口转发；`--net=host --relay` 增量；权威模型不变；验收=跨 NAT 实测连上并同局稳定）。
