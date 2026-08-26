class_name NetCodec
extends RefCounted
## 跨端协议编解码（M2 多人）：快照/事件负载 ↔ PackedByteArray（var_to_bytes 往返）
## - 协议键集中定义在本模块常量区，业务侧禁止散落魔法键（架构硬性约束 §1.1 精神）
## - 跨端负载一律「字符串键字典 + Godot 原生类型」；Vector2 显式转 [x, y] 数组

# ─── 快照键 ───
const SNAP_TICK := "tick"
const SNAP_RUN := "run"
const SNAP_BASE := "base"
const SNAP_PLAYERS := "players"
const SNAP_ENEMIES := "enemies"

const RUN_PAUSED := "paused"
const RUN_SHOP_OPEN := "shop_open"
const RUN_FINISHED := "finished"
const RUN_CREDITS := "credits"
const RUN_MATERIAL := "material"
const RUN_RESERVE := "reserve"
const RUN_BAG := "bag"
const RUN_ARSENAL := "arsenal"
const RUN_WAVE_INDEX := "wave_index"
const RUN_WAVE_TOTAL := "wave_total"
## M3 问题 4：per-player 资源表（SNAP_RUN 内；player_id -> {credits, material, reserve, bag}）
const RUN_RESOURCES := "resources"

const BASE_DURABILITY := "durability"
const BASE_MAX := "max"

const PLAYER_POS := "pos"
const PLAYER_AIM := "aim"
const PLAYER_HP := "hp"
const PLAYER_MAX_HP := "max_hp"
const PLAYER_STATE := "state"

const ENEMY_POS := "pos"
const ENEMY_STATE := "state"
const ENEMY_LOCATION := "location"
const ENEMY_STATE_ALIVE := 0
const ENEMY_STATE_DEAD := 1

# ─── 事件名（rpc_handle_event 第一参数；client 端 match 路由） ───
const EVT_WAVE_WARNING := "wave_warning"
const EVT_WAVE_STARTED := "wave_started"
const EVT_WAVE_CLEARED := "wave_cleared"
const EVT_RUN_VICTORY := "run_victory"
const EVT_RUN_DEFEAT := "run_defeat"
const EVT_PLAYER_HEALTH := "player_health"
const EVT_PLAYER_DIED := "player_died"
const EVT_REVIVE_STARTED := "revive_started"
const EVT_REVIVED := "revived"
const EVT_SHOT_FIRED := "shot_fired"
const EVT_AMMO_CHANGED := "ammo_changed"
const EVT_WEAPON_SWITCHED := "weapon_switched"
const EVT_WEAPON_SWITCH_STARTED := "weapon_switch_started"
const EVT_WEAPON_SWITCH_REJECTED := "weapon_switch_rejected"
const EVT_RELOAD_STARTED := "reload_started"
const EVT_ATTACHMENT_EQUIPPED := "attachment_equipped"
const EVT_ATTACHMENT_UNEQUIPPED := "attachment_unequipped"
## M3 方案 B：敌人受击反馈中继（host 命中 → client 镜像闪白）
const EVT_ENEMY_HIT := "enemy_hit"
const EVT_BAG_CHANGED := "bag_changed"
const EVT_SHOP_OFFERS := "shop_offers"
const EVT_SHOP_PURCHASED := "shop_purchased"
const EVT_SHOP_PURCHASE_REJECTED := "shop_purchase_rejected"
const EVT_RUN_STATE := "run_state"
const EVT_BASE_DURABILITY := "base_durability"
const EVT_BARRICADE_PLACED := "barricade_placed"
const EVT_BARRICADE_DAMAGED := "barricade_damaged"
const EVT_BARRICADE_DESTROYED := "barricade_destroyed"
## M5a：敌人远程攻击 / 范围伤害事件中继（host → client 视觉弹体/爆炸）
const EVT_ENEMY_RANGED_ATTACK := "enemy_ranged_attack"
const EVT_ENEMY_AOE := "enemy_aoe"
const EVT_TURRET_FIRED := "turret_fired"
const EVT_TURRET_PLACED := "turret_placed"
const EVT_ARSENAL_CHANGED := "arsenal_changed"
const EVT_UI_STATE := "ui_state"
## P1 街机化：分数/连击、道具拾取/到期、Boss 血量（host → client 镜像）
const EVT_SCORE_CHANGED := "score_changed"
const EVT_POWERUP_PICKUP := "powerup_pickup"
const EVT_POWERUP_EXPIRED := "powerup_expired"
const EVT_ENEMY_HEALTH := "enemy_health"

## 事件负载键（各事件通用）
const KEY_PLAYER_ID := "player_id"
const KEY_WAVE_INDEX := "wave_index"
const KEY_WAVE_TOTAL := "wave_total"
const KEY_TIERS := "tiers"
const KEY_THREAT_TIER := "threat_tier"
const KEY_HAS_ELITE := "has_elite"
const KEY_CURRENT := "current"
const KEY_MAX := "max"
const KEY_CD := "cd"
const KEY_MODEL_LOCATION := "model_location"
const KEY_AIM_DIRECTION := "aim_direction"
const KEY_AMMO_TYPE := "ammo_type"
const KEY_MAG := "mag"
const KEY_RESERVE := "reserve"
const KEY_SLOT_INDEX := "slot_index"
const KEY_SLOT_TYPE := "slot_type"
const KEY_REASON := "reason"
const KEY_DURATION := "duration"
const KEY_ATTACHMENT_LOCATION := "attachment_location"
const KEY_BAG := "bag"
const KEY_ARSENAL := "arsenal"
const KEY_OFFERS := "offers"
const KEY_OFFER_LOCATION := "location"
const KEY_OFFER_PRICE := "price"
const KEY_OFFER_OWNED := "owned"
const KEY_OFFER_AFFORDABLE := "affordable"
const KEY_LOCATION := "location"
const KEY_POS := "pos"
const KEY_DURABILITY := "durability"
const KEY_MAX_DURABILITY := "max_durability"
const KEY_PAUSED := "paused"
const KEY_SHOP_OPEN := "shop_open"
const KEY_RESULT := "result"
const KEY_VICTORY := "victory"
const KEY_CREDITS := "credits"
const KEY_MATERIAL := "material"
const KEY_RESERVE_COUNT := "reserve"
## M3 问题 2：暂停请求集合（ui_state 负载；Array[int] 请求中的玩家 id，全队请求才正式暂停）
const KEY_PAUSE_REQUESTS := "pause_requests"
## M3 方案 B：命中判定结果（shot_fired 负载；Array[Vector2] 每弹丸命中点/射程尽头）
const KEY_HIT_POINTS := "hit_points"
## M3 方案 B：敌人受击反馈（enemy_hit 负载；host 分配的敌人 net_id）
const KEY_ENEMY_ID := "enemy_id"
## M5a：敌人远程攻击 / 范围伤害负载
const KEY_ENEMY_LOCATION := "enemy_location"
const KEY_TARGET_POS := "target_pos"
const KEY_PROJECTILE_KIND := "projectile_kind"
const KEY_SPEED := "speed"
const KEY_RADIUS := "radius"
const KEY_DAMAGE := "damage"
## P1 街机化负载键
const KEY_SCORE := "score"
const KEY_COMBO := "combo"
const KEY_MULTIPLIER := "multiplier"
const KEY_POWER_ID := "power_id"
const KEY_DATA_ID := "data_id"
const KEY_IS_ELITE := "is_elite"
const KEY_CHAPTER_INDEX := "chapter_index"
const KEY_CHAPTER_NAME := "chapter_name"
const KEY_IS_BOSS := "is_boss"
const KEY_WAVE_IN_CHAPTER := "wave_in_chapter"
const KEY_CYCLE_INDEX := "cycle_index"

# ─── 编解码 ───

static func pack_snapshot(data: Dictionary) -> PackedByteArray:
	return var_to_bytes(data)

static func unpack_snapshot(bytes: PackedByteArray) -> Dictionary:
	var data: Variant = bytes_to_var(bytes)
	return data if data is Dictionary else {}

static func pack_event(payload: Dictionary) -> PackedByteArray:
	return var_to_bytes(payload)

static func unpack_event(bytes: PackedByteArray) -> Dictionary:
	var data: Variant = bytes_to_var(bytes)
	return data if data is Dictionary else {}

## Vector2 ↔ [x, y]（快照/事件负载用，避免 Vector2 变体类型跨端不一致）
static func vec_to_arr(v: Vector2) -> Array:
	return [v.x, v.y]

static func arr_to_vec(a: Array) -> Vector2:
	if a.size() < 2:
		return Vector2.ZERO
	return Vector2(a[0], a[1])
