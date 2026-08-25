class_name HighScoreStore
extends RefCounted
## 本机高分榜（P1-10）：user://highscore.json（带版本号，Top10）
## 写失败降级：返回 {ok:false}，不阻塞结算面板

const VERSION := 1
const MAX_ENTRIES := 10
const DEFAULT_PATH := "user://highscore.json"

static func load_top(path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var data := _read_file(path)
	if data.is_empty() or int(data.get("version", -1)) != VERSION:
		return []
	var entries: Array = data.get("entries", [])
	var out: Array[Dictionary] = []
	var count := mini(entries.size(), MAX_ENTRIES)
	for i in count:
		var entry: Dictionary = entries[i]
		out.append(entry.duplicate())
	return out

## 写入一条并返回名次（1-based；未进榜返回 -1）。score<=0 不写。
## entry: {score:int, combo:int, kills:int, time:float, name:String}
static func save_entry(entry: Dictionary, path: String = DEFAULT_PATH) -> int:
	var score_v: Variant = entry.get("score", 0)
	if int(score_v) <= 0:
		return -1
	var current := load_top(path)
	var new_entry := {
		"score": int(entry.get("score", 0)),
		"combo": int(entry.get("combo", 0)),
		"kills": int(entry.get("kills", 0)),
		"time": float(entry.get("time", 0.0)),
		"name": str(entry.get("name", "")),
	}
	current.append(new_entry)
	current.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0)))
	if current.size() > MAX_ENTRIES:
		current.resize(MAX_ENTRIES)
	var rank := -1
	for i in current.size():
		if current[i] == new_entry:
			rank = i + 1
			break
	var payload := {"version": VERSION, "entries": current}
	var err := _write_file(path, payload)
	if err != OK:
		push_warning("HighScoreStore: 写入失败 %s err=%d" % [path, err])
		return -1
	return rank

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

static func reset(path: String = DEFAULT_PATH) -> void:
	var payload := {"version": VERSION, "entries": []}
	_write_file(path, payload)
