extends Node
## M4 音频装配层（autoload，挂在 SoundManager 之后）：
## - 订阅玩法 EventBus 事件 → 经 sound_manager 播放（表现层不直接碰音频）
## - 音乐状态机：战斗曲（WaveStarted）/ 波间曲（WaveCleared）；主菜单经 play_menu_music() 接入
## - 多人过滤：client 只播本地玩家的身体音效（开火/受击/死亡/复活）；host 全播（同屏双人）
## - 弹匣空用 AmmoChangedEvent mag 边沿（host 权威事件经中继后 client 同样能触发点击声）

const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_MUSIC := "Music"

const SFX_PATH := "res://assets/audio/sfx/%s.mp3"
const UI_PATH := "res://assets/audio/ui/%s.mp3"
const MUSIC_BATTLE_PATH := "res://assets/audio/music/More than Arcade Life.mp3"
const MUSIC_INTERMISSION_PATH := "res://assets/audio/music/No Longer Being Normal.mp3"

const CROSSFADE := 0.8

enum MusicMode {
	OFF = 0,
	BATTLE = 1,
	INTERMISSION = 2,
}

var _rng := RandomNumberGenerator.new()
## 弹匣空边沿检测：player_id -> 上一帧 mag（AmmoChangedEvent）
var _last_mag: Dictionary = {}
## 生命下降检测：player_id -> 上一帧 hp
var _last_hp: Dictionary = {}
var _music_mode: int = MusicMode.OFF
## headless（GUT/冒烟/quit-after 自检）不播音乐：dummy 音频下长流在退出清理序中会留引用告警
var _music_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_music_enabled = DisplayServer.get_name() != "headless"
	_subscribe_events()

## 退出清理：立即停掉音乐并清空 stream 引用，避免 AudioStreamMP3/Playback 在 quit 时泄漏
func _exit_tree() -> void:
	if SoundManager == null or not is_instance_valid(SoundManager):
		return
	var music = SoundManager.music
	var players: Array = music.busy_players.duplicate()
	players.append_array(music.available_players.duplicate())
	for player in players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _subscribe_events() -> void:
	EventBus.subscribe(&"ShotFiredEvent", _on_shot_fired)
	EventBus.subscribe(&"ReloadStartedEvent", _on_reload_started)
	EventBus.subscribe(&"AmmoChangedEvent", _on_ammo_changed)
	EventBus.subscribe(&"PlayerHealthChangedEvent", _on_player_health_changed)
	EventBus.subscribe(&"PlayerDiedEvent", _on_player_died)
	EventBus.subscribe(&"EnemyDiedEvent", _on_enemy_died)
	EventBus.subscribe(&"RevivedEvent", _on_revived)
	EventBus.subscribe(&"ShopPurchasedEvent", _on_shop_purchased)
	EventBus.subscribe(&"ShopPurchaseRejectedEvent", _on_shop_purchase_rejected)
	EventBus.subscribe(&"WeaponSwitchRejectedEvent", _on_weapon_switch_rejected)
	EventBus.subscribe(&"WaveWarningEvent", _on_wave_warning)
	EventBus.subscribe(&"WaveStartedEvent", _on_wave_started)
	EventBus.subscribe(&"WaveClearedEvent", _on_wave_cleared)
	EventBus.subscribe(&"BarricadePlacedEvent", _on_barricade_placed)
	EventBus.subscribe(&"BarricadeDestroyedEvent", _on_barricade_destroyed)
	EventBus.subscribe(&"TurretFiredEvent", _on_turret_fired)
	EventBus.subscribe(&"RunDefeatEvent", _on_run_ended)
	EventBus.subscribe(&"RunVictoryEvent", _on_run_ended)

# ─── 播放辅助 ───

func play_sfx(resource: AudioStream, pitch: float = 1.0) -> AudioStreamPlayer:
	return SoundManager.play_sound_with_pitch(resource, pitch, BUS_SFX)

func play_ui(resource: AudioStream, pitch: float = 1.0) -> AudioStreamPlayer:
	return SoundManager.play_ui_sound_with_pitch(resource, pitch, BUS_UI)

## 供 UI 按钮/主菜单直接调用
func play_ui_select() -> void:
	play_ui(load(UI_PATH % "select"))

func play_ui_unable() -> void:
	play_ui(load(UI_PATH % "unable"))

func play_menu_music() -> void:
	_set_music(MusicMode.INTERMISSION)

func stop_music_for_menu() -> void:
	_set_music(MusicMode.OFF)

## client 身体音效过滤：只播本地玩家；host/OFFLINE 全播（同屏）
func _is_audible_player(pid: int) -> bool:
	if Net.is_client():
		return pid == Net.get_local_player_id()
	return true

# ─── 玩法事件 ───

func _on_shot_fired(event: ShotFiredEvent) -> void:
	if event == null or not _is_audible_player(event.player_id):
		return
	var stream := load(SFX_PATH % "smg_shoot")
	var pitch := _rng.randf_range(0.95, 1.05)
	var model: WeaponModelData = ContentBootstrap.get_entry(
		Bulwark.REG_WEAPON_MODEL, event.model_location)
	if model != null and model.type_id.ends_with("pistol"):
		stream = load(SFX_PATH % "handgun_shoot")
	elif model != null and model.type_id.ends_with("shotgun"):
		# 无霰弹素材：smg_shoot 降调（0.75~0.85）模拟低频爆响
		pitch = _rng.randf_range(0.75, 0.85)
	play_sfx(stream, pitch)

func _on_reload_started(event: ReloadStartedEvent) -> void:
	if event == null or not _is_audible_player(event.player_id):
		return
	play_sfx(load(SFX_PATH % "reload"))

func _on_ammo_changed(event: AmmoChangedEvent) -> void:
	if event == null or not _is_audible_player(event.player_id):
		return
	var last: Variant = _last_mag.get(event.player_id)
	if last != null and int(last) > 0 and event.mag <= 0:
		play_sfx(load(SFX_PATH % "mag_empty"))
	_last_mag[event.player_id] = event.mag

func _on_player_health_changed(event: PlayerHealthChangedEvent) -> void:
	if event == null or not _is_audible_player(event.player_id):
		return
	var last: Variant = _last_hp.get(event.player_id)
	if last != null and event.current < float(last):
		play_sfx(load(SFX_PATH % "entity_hurt"))
	_last_hp[event.player_id] = event.current

func _on_player_died(event: PlayerDiedEvent) -> void:
	if event == null or not _is_audible_player(event.player_id):
		return
	var idx := _rng.randi_range(1, 3)
	play_sfx(load(SFX_PATH % ("human_die_%d" % idx)))

func _on_enemy_died(_event: EnemyDiedEvent) -> void:
	# 仅 host/OFFLINE 发布 EnemyDiedEvent（client 敌人死亡走快照），无需过滤
	play_sfx(load(SFX_PATH % "mob_die"), _rng.randf_range(0.95, 1.05))

func _on_revived(event: RevivedEvent) -> void:
	if event == null or not _is_audible_player(event.player_id):
		return
	play_sfx(load(SFX_PATH % "heal"))

func _on_shop_purchased(_event: ShopPurchasedEvent) -> void:
	play_ui(load(UI_PATH % "shopping_buy"))

func _on_shop_purchase_rejected(_event: ShopPurchaseRejectedEvent) -> void:
	play_ui(load(UI_PATH % "unable"))

func _on_weapon_switch_rejected(_event: WeaponSwitchRejectedEvent) -> void:
	play_ui(load(UI_PATH % "unable"))

func _on_wave_warning(_event: WaveWarningEvent) -> void:
	play_sfx(load(SFX_PATH % "entity_hurt"), 0.6)

func _on_wave_started(_event: WaveStartedEvent) -> void:
	_set_music(MusicMode.BATTLE)

func _on_wave_cleared(_event: WaveClearedEvent) -> void:
	_set_music(MusicMode.INTERMISSION)

func _on_barricade_placed(_event: BarricadePlacedEvent) -> void:
	play_sfx(load(SFX_PATH % "item_drop"))

func _on_barricade_destroyed(_event: BarricadeDestroyedEvent) -> void:
	play_sfx(load(SFX_PATH % "mob_die"), 0.6)

func _on_turret_fired(_event: TurretFiredEvent) -> void:
	play_sfx(load(SFX_PATH % "smg_shoot"), _rng.randf_range(0.75, 0.85))

func _on_run_ended(_event: RefCounted) -> void:
	_set_music(MusicMode.OFF)

# ─── 音乐状态机 ───

func _set_music(mode: int) -> void:
	if not _music_enabled:
		_music_mode = mode
		return
	if mode == MusicMode.OFF:
		if _music_mode != MusicMode.OFF:
			SoundManager.stop_music(CROSSFADE)
		_music_mode = MusicMode.OFF
		return
	# 按需 load（ResourceCache 复用同一实例）；不在本节点持有流引用（退出清理更干净）
	var stream: AudioStream = load(
		MUSIC_BATTLE_PATH if mode == MusicMode.BATTLE else MUSIC_INTERMISSION_PATH)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	if _music_mode == mode and SoundManager.is_music_playing(stream):
		return
	_music_mode = mode
	SoundManager.play_music(stream, CROSSFADE, BUS_MUSIC)
