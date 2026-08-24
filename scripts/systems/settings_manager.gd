extends Node
## M4 设置持久化（autoload；ConfigFile user://settings.cfg，D-M4-15）
## - [audio] music_volume / sfx_volume / ui_volume：0..1 线性值
## - 启动时读取并应用到 SFX/UI/Music 总线；UI slider 改动即时生效并落盘
## - 线性 ↔ dB 全部走 linear_to_db / db_to_linear；接近 0 时 mute（避免 -inf）

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_META := "meta"
const SETTINGS_VERSION := 1

const KEY_MUSIC := "music_volume"
const KEY_SFX := "sfx_volume"
const KEY_UI := "ui_volume"
const KEY_LANG := "language"

## 支持的语言：code → 翻译 JSON（I18NManager/MSF I18n 系统，M4.1）
const LOCALE_FILES := {
	"zh": "res://locales/zh.json",
	"en": "res://locales/en.json",
}
const DEFAULT_LANGUAGE := "zh"

const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_MUSIC := "Music"

const MUTE_THRESHOLD := 0.001

signal settings_changed(bus_name: String, linear_volume: float)
signal language_changed(lang_code: String)

var _config := ConfigFile.new()
var _volumes: Dictionary = {}
var _language := DEFAULT_LANGUAGE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply_all()
	_load_locales()
	# 启动即应用持久化语言（在设置面板打开前，主菜单/各 UI 的 tr() 即已是正确语言）
	I18NManager.set_language(_language)

func _load() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		# 首次运行：使用默认值并落盘，便于用户手改
		_volumes[KEY_MUSIC] = 1.0
		_volumes[KEY_SFX] = 1.0
		_volumes[KEY_UI] = 1.0
		_language = DEFAULT_LANGUAGE
		save()
		return
	var version := int(_config.get_value(SECTION_META, "version", 0))
	if version < SETTINGS_VERSION:
		# 预留迁移入口；v1 无历史格式
		pass
	_volumes[KEY_MUSIC] = clampf(float(_config.get_value(SECTION_AUDIO, KEY_MUSIC, 1.0)), 0.0, 1.0)
	_volumes[KEY_SFX] = clampf(float(_config.get_value(SECTION_AUDIO, KEY_SFX, 1.0)), 0.0, 1.0)
	_volumes[KEY_UI] = clampf(float(_config.get_value(SECTION_AUDIO, KEY_UI, 1.0)), 0.0, 1.0)
	_language = str(_config.get_value(SECTION_AUDIO, KEY_LANG, DEFAULT_LANGUAGE))
	if not LOCALE_FILES.has(_language):
		_language = DEFAULT_LANGUAGE

func save() -> void:
	_config.set_value(SECTION_META, "version", SETTINGS_VERSION)
	for key in [KEY_MUSIC, KEY_SFX, KEY_UI]:
		_config.set_value(SECTION_AUDIO, key, float(_volumes.get(key, 1.0)))
	_config.set_value(SECTION_AUDIO, KEY_LANG, _language)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_error("SettingsManager: 保存设置失败 err=%d" % err)

func get_volume(bus_name: String) -> float:
	match bus_name:
		BUS_MUSIC:
			return float(_volumes.get(KEY_MUSIC, 1.0))
		BUS_SFX:
			return float(_volumes.get(KEY_SFX, 1.0))
		BUS_UI:
			return float(_volumes.get(KEY_UI, 1.0))
	return 1.0

func set_volume(bus_name: String, linear_volume: float) -> void:
	var clamped := clampf(linear_volume, 0.0, 1.0)
	match bus_name:
		BUS_MUSIC:
			_volumes[KEY_MUSIC] = clamped
		BUS_SFX:
			_volumes[KEY_SFX] = clamped
		BUS_UI:
			_volumes[KEY_UI] = clamped
		_:
			return
	_apply_bus(bus_name, clamped)
	settings_changed.emit(bus_name, clamped)
	save()

## 把 0..1 线性值写到 AudioServer 总线（接近 0 → mute，避免 linear_to_db(0)=-inf）
func _apply_bus(bus_name: String, linear_volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear_volume <= MUTE_THRESHOLD:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, linear_to_db(MUTE_THRESHOLD))
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_volume))

func _apply_all() -> void:
	_apply_bus(BUS_MUSIC, get_volume(BUS_MUSIC))
	_apply_bus(BUS_SFX, get_volume(BUS_SFX))
	_apply_bus(BUS_UI, get_volume(BUS_UI))

# ─── 语言（MSF I18NManager；M4.1） ───

## 启动时把所有支持语言注册到 TranslationServer（locale 由 set_language 切换）
func _load_locales() -> void:
	for code: String in LOCALE_FILES.keys():
		I18NManager.load_translation(code, LOCALE_FILES[code])

func get_language() -> String:
	return _language

func get_language_options() -> Array:
	var options: Array = []
	for code: String in LOCALE_FILES.keys():
		options.append({"code": code})
	return options

func set_language(lang_code: String) -> void:
	if not LOCALE_FILES.has(lang_code):
		return
	if _language == lang_code:
		return
	_language = lang_code
	save()
	I18NManager.set_language(lang_code)
	language_changed.emit(lang_code)
