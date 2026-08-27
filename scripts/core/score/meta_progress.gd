class_name MetaProgress
extends RefCounted
## P2-18 最小 meta：结算货币 → 起始武器解锁（本机持久化，带版本号）
## - 每局结算 meta_credits += max(1, floor(score/1000))
## - 达到阈值自动解锁对应起始武器（写入起始军械库；武器箱不再上架已拥有型号）
## - 写失败降级：返回当前内存值，不阻塞游戏

const VERSION := 1
const SAVE_PATH := "user://meta.json"

## 解锁表（顺序 = 门槛递增；带 `bulwark:` 命名空间，改枪台/注册表可直接解析）
const UNLOCK_MODELS := [
	{"model": "bulwark:weapon/model/ar_2", "cost": 1},
	{"model": "bulwark:weapon/model/sg_2", "cost": 2},
	{"model": "bulwark:weapon/model/lmg_1", "cost": 4},
	{"model": "bulwark:weapon/model/er_1", "cost": 6},
]

static var _cache: Dictionary = {}

static func get_meta_credits() -> int:
	_ensure_loaded()
	return int(_cache.get("credits", 0))

static func add_meta_credits(amount: int) -> void:
	if amount <= 0:
		return
	_ensure_loaded()
	_cache["credits"] = int(_cache.get("credits", 0)) + amount
	_save()

## 已解锁起始武器（ResourceLocation 字符串）
static func get_unlocked_models() -> Array[String]:
	_ensure_loaded()
	var credits := int(_cache.get("credits", 0))
	var out: Array[String] = []
	for unlock: Dictionary in UNLOCK_MODELS:
		if credits >= int(unlock.get("cost", 0)):
			out.append(str(unlock.get("model", "")))
	return out

## 下一个未解锁 {model,cost}；全部解锁返回 {}
static func get_next_unlock() -> Dictionary:
	_ensure_loaded()
	var credits := int(_cache.get("credits", 0))
	for unlock: Dictionary in UNLOCK_MODELS:
		if credits < int(unlock.get("cost", 0)):
			return unlock.duplicate()
	return {}

## 主菜单展示：下一个未解锁武器的本地化名；全部解锁返回空串
static func get_next_unlock_name() -> String:
	var next := get_next_unlock()
	if next.is_empty():
		return ""
	var model_str := str(next.get("model", ""))
	# content 键按无命名空间 id 生成；展示时剥掉命名空间前缀
	var display_id := model_str.trim_prefix("bulwark:")
	return UiText.content_name(display_id, model_str)

static func reset(path: String = SAVE_PATH) -> void:
	_cache = {"version": VERSION, "credits": 0}
	_write_file(path, _cache)

static func _save() -> void:
	_write_file(SAVE_PATH, _cache)

static func _ensure_loaded() -> void:
	if _cache.is_empty():
		_cache = _read_file(SAVE_PATH)
		if int(_cache.get("version", -1)) != VERSION:
			_cache = {"version": VERSION, "credits": 0}

static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}

static func _write_file(path: String, payload: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return OK
