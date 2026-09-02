## Central audio playback. Buses: Master > Music / SFX / UI / Voice.
## - play_sfx()/play_ui()/play_voice() use pooled players with optional pitch
##   variation and per-stream rate limiting (hordes must not stack 50 identical hits).
## - play_music() crossfades between two music players.
## Volumes are read from GameState settings and re-applied when they change.
extends Node

const SFX_POOL_SIZE := 16
const UI_POOL_SIZE := 4
const VOICE_POOL_SIZE := 2
const SAME_SOUND_MIN_INTERVAL_MSEC := 40

var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _voice_pool: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_tween: Tween
var _last_play_msec: Dictionary = {}  # stream rid -> msec
var _current_music: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_pool = _make_pool("SFX", SFX_POOL_SIZE)
	_ui_pool = _make_pool("UI", UI_POOL_SIZE)
	_voice_pool = _make_pool("Voice", VOICE_POOL_SIZE)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_active = _music_a
	GameState.settings_changed.connect(apply_settings)
	GameState.profile_loaded.connect(apply_settings)
	apply_settings()


func _make_pool(bus: String, size: int) -> Array[AudioStreamPlayer]:
	var pool: Array[AudioStreamPlayer] = []
	for i in size:
		pool.append(_make_player(bus))
	return pool


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# --- Playback ----------------------------------------------------------------

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variance: float = 0.08) -> void:
	_play_pooled(_sfx_pool, stream, volume_db, pitch_variance)


func play_ui(stream: AudioStream, volume_db: float = 0.0) -> void:
	_play_pooled(_ui_pool, stream, volume_db, 0.0)


func play_voice(stream: AudioStream, volume_db: float = 0.0) -> void:
	_play_pooled(_voice_pool, stream, volume_db, 0.0)


func _play_pooled(pool: Array[AudioStreamPlayer], stream: AudioStream, volume_db: float, pitch_variance: float) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	var key := stream.get_rid()
	if _last_play_msec.has(key) and now - int(_last_play_msec[key]) < SAME_SOUND_MIN_INTERVAL_MSEC:
		return
	_last_play_msec[key] = now
	var player := _free_player(pool)
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


func _free_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	# All busy: steal the oldest (first) and rotate it to the back.
	var p: AudioStreamPlayer = pool.pop_front()
	pool.append(p)
	return p


func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
	if stream == _current_music:
		return
	_current_music = stream
	var from := _music_active
	var to := _music_b if _music_active == _music_a else _music_a
	_music_active = to
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	to.stream = stream
	to.volume_db = -40.0
	if stream != null:
		to.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(to, "volume_db", 0.0, fade_time).from(-40.0)
	if from.playing:
		_music_tween.tween_property(from, "volume_db", -40.0, fade_time)
		_music_tween.chain().tween_callback(from.stop)


func stop_music(fade_time: float = 0.8) -> void:
	play_music(null, fade_time)


# --- Settings ----------------------------------------------------------------

func apply_settings() -> void:
	var muted: bool = GameState.get_setting("muted", false)
	set_bus_volume("Music", float(GameState.get_setting("music_volume", 0.8)))
	set_bus_volume("SFX", float(GameState.get_setting("sfx_volume", 1.0)))
	set_bus_volume("UI", float(GameState.get_setting("sfx_volume", 1.0)))
	set_bus_volume("Voice", float(GameState.get_setting("sfx_volume", 1.0)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		Log.warn("Audio", "Unknown bus %s" % bus)
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
