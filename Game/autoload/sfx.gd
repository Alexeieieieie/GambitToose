extends Node


const Director = preload("res://audio/audio_director.gd")

const POOL_SIZE = 10
const BUSES = ["Music", "SFX", "UI", "Ambience"]
const LAYERS = ["music_base", "music_melody", "music_tension"]
const MUSIC_BUS_BASE_DB = 0.0
const PAUSE_DUCK_DB = -6.0
const LOWPASS_ON_HZ = 900.0
const LOWPASS_OFF_HZ = 20000.0
const DRIFT_LIMIT = 0.03
const FADE_SECONDS = {"music_melody": 1.5, "music_tension": 1.0, "music_base": 0.8, "music_menu": 1.0}

var enabled = true
var director
var rng = RandomNumberGenerator.new()

var _streams = {}
var _pool = []
var _pool_prio = []
var _pool_started = []
var _layers = {}
var _level = {}
var _menu_player
var _menu_level = 0.0
var _ambience
var _siren
var _siren_on = false
var _siren_level = 0.0
var _mode = "menu"
var _results_level = 1.0
var _paused = false
var _speed = 1.0
var _lowpass_hz = LOWPASS_OFF_HZ
var _lowpass_fx
var _lowpass_index = -1
var _drift_timer = 0.0
var _vehicle_count = 0
var _amb_level = 0.0
var _sim


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	rng.randomize()
	director = Director.new()
	_build_buses()
	_load_all()
	for _i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
		_pool_prio.append(-1)
		_pool_started.append(0)
	for n in LAYERS:
		_layers[n] = _make_loop_player(n, "Music")
		_level[n] = 0.0
	_menu_player = _make_loop_player("music_menu", "Music")
	_ambience = _make_loop_player("ambience_traffic", "Ambience")
	_siren = _make_loop_player("siren", "SFX")
	apply_settings()
	set_enabled(SaveData.sound_on, false)
	start_menu_music()



func _build_buses() -> void:
	for a in BUSES:
		if AudioServer.get_bus_index(a) == -1:
			AudioServer.add_bus()
			var i = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, a)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Ambience"), "SFX")
	var c = AudioServer.get_bus_index("Master")
	var d = AudioEffectLimiter.new()
	d.ceiling_db = -1.0
	d.threshold_db = -3.0
	AudioServer.add_bus_effect(c, d)
	_lowpass_fx = AudioEffectLowPassFilter.new()
	_lowpass_fx.cutoff_hz = LOWPASS_OFF_HZ
	var e = AudioServer.get_bus_index("Music")
	AudioServer.add_bus_effect(e, _lowpass_fx)
	_lowpass_index = AudioServer.get_bus_effect_count(e) - 1
	AudioServer.set_bus_effect_enabled(e, _lowpass_index, false)


func _load_all() -> void:
	for n in Director.all_files():
		var a = "res://audio/" + n + ".wav"
		if not ResourceLoader.exists(a):
			continue
		var s = load(a)
		if s != null and n in Director.LOOP_FILES + Director.MUSIC_FILES and s is AudioStreamSample:
			s.loop_mode = AudioStreamSample.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2
		_streams[n] = s


func _make_loop_player(n: String, a: String) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.bus = a
	p.stream = _streams.get(n)
	p.volume_db = -80.0
	add_child(p)
	return p



func apply_settings() -> void:
	_set_bus_linear("Master", SaveData.vol_master / 100.0)
	_set_bus_linear("Music", SaveData.vol_music / 100.0)
	_set_bus_linear("SFX", SaveData.vol_effects / 100.0)
	_set_bus_linear("UI", SaveData.vol_effects / 100.0)


func _set_bus_linear(a: String, v: float) -> void:
	var i = AudioServer.get_bus_index(a)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear2db(v) if v > 0.001 else -80.0)


func set_enabled(on: bool, a: bool = true) -> void:
	enabled = on
	if a:
		SaveData.set_sound(on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)


func toggle() -> bool:
	set_enabled(not enabled)
	play("ui_toggle_on" if enabled else "ui_toggle_off")
	return enabled



func play(n: String, a: float = 1.0, c: float = 0.0) -> void:
	if director.request(n, c, a):
		_flush()


func play_variant(n: String, a: int, c: float = 1.0, d: float = 0.0) -> void:
	if director.request(n, d, c, a):
		_flush()


func handle_event(ev: Dictionary) -> void:
	director.on_event(ev)
	_flush()


func _flush() -> void:
	for r in director.take_requests():
		_play_request(r)


func _play_request(r: Dictionary) -> void:
	var a = _streams.get(r["file"])
	if a == null:
		return
	var c = _pick_voice(int(r["priority"]))
	if c < 0:
		return
	var p = _pool[c]
	p.stream = a
	p.bus = r["bus"]
	p.pitch_scale = r["pitch"] * (1.0 + (rng.randf() * 2.0 - 1.0) * r["jitter"])
	p.volume_db = r["db"]
	p.play()
	_pool_prio[c] = r["priority"]
	_pool_started[c] = OS.get_ticks_msec()


func _pick_voice(a: int) -> int:
	var c = -1
	for i in range(_pool.size()):
		if not _pool[i].playing:
			return i
		if _pool_prio[i] <= a:
			if c == -1 or _pool_prio[i] < _pool_prio[c] \
					or (_pool_prio[i] == _pool_prio[c] and _pool_started[i] < _pool_started[c]):
				c = i
	return c


func delivery_streak() -> int:
	return director.streak



func start_menu_music() -> void:
	_mode = "menu"
	_siren_on = false
	_menu_level = 0.0
	if _menu_player.stream != null and not _menu_player.playing:
		_menu_player.play()
	for n in LAYERS:
		_level[n] = 0.0


func start_level_audio(a) -> void:
	_mode = "level"
	_sim = a
	_results_level = 1.0
	_paused = false
	_siren_on = false
	director.reset()
	for n in LAYERS:
		_level[n] = 0.0
		var p = _layers[n]
		if p.stream != null:
			p.volume_db = -80.0
			p.play()
	_level["music_base"] = 0.0
	if not _ambience.playing and _ambience.stream != null:
		_ambience.play()
	_drift_timer = 0.0


func results_started() -> void:
	_mode = "results"
	_siren_on = false
	director.duck(8.0, 2.0)


func set_speed(a: float) -> void:
	_speed = a
	var c = Director.music_pitch(a)
	for n in LAYERS:
		_layers[n].pitch_scale = c
	_menu_player.pitch_scale = 1.0


func set_paused(a: bool) -> void:
	_paused = a


func set_siren(on: bool) -> void:
	_siren_on = on


func reset_streak() -> void:
	director.streak = 0


func duck(on: bool) -> void:
	if on:
		director.duck(8.0, 2.0)
	else:
		director.duck_db = 0.0
		director.duck_until = 0.0


func _process(a: float) -> void:
	director.update(a, _sim if _mode == "level" else null)
	_flush()
	_update_music(a)
	_update_ambience(a)
	_update_lowpass(a)
	_drift_timer += a
	if _drift_timer >= 1.0:
		_drift_timer = 0.0
		_fix_drift()


func _fade(a: float, c: float, d: float, e: float) -> float:
	var f = e / max(d, 0.05)
	if c > a:
		return min(a + f, c)
	return max(a - f, c)


func _lin_db(v: float) -> float:
	return linear2db(v) if v > 0.001 else -80.0


func _update_music(a: float) -> void:
	var c = director.duck_offset() + (PAUSE_DUCK_DB if _paused else 0.0)
	var d = 1.0 if _mode == "menu" else 0.0
	_menu_level = _fade(_menu_level, d, FADE_SECONDS["music_menu"], a)
	_menu_player.volume_db = _lin_db(_menu_level) + c
	if _menu_level <= 0.001 and _menu_player.playing and _mode != "menu":
		_menu_player.stop()
	if _mode == "menu":
		for n in LAYERS:
			_layers[n].volume_db = -80.0
		return
	var e = director.layer_targets()
	var f = 1.0
	if _mode == "results":
		_results_level = _fade(_results_level, 0.0, 1.0, a)
		f = _results_level
	for n in LAYERS:
		var g = n.replace("music_", "")
		_level[n] = _fade(_level[n], e[g], FADE_SECONDS[n], a)
		_layers[n].volume_db = _lin_db(_level[n] * f) + c


func _update_ambience(a: float) -> void:
	var c = 0.0
	if _mode == "level" and _sim != null and not _paused:
		_vehicle_count = _sim.vehicles.size()
		c = director.ambience_level(_vehicle_count)
	_amb_level = _fade(_amb_level, c, 1.0, a)
	_ambience.volume_db = lerp(-60.0, -4.0, _amb_level) if _amb_level > 0.001 else -80.0
	var d = 1.0 if (_siren_on and _mode == "level" and not _paused) else 0.0
	_siren_level = _fade(_siren_level, d, 0.3, a)
	_siren.volume_db = _lin_db(_siren_level)
	if _siren_level > 0.001 and not _siren.playing and _siren.stream != null:
		_siren.play()
	elif _siren_level <= 0.001 and _siren.playing:
		_siren.stop()


func _update_lowpass(a: float) -> void:
	var c = LOWPASS_ON_HZ if _paused else LOWPASS_OFF_HZ
	var d = AudioServer.get_bus_index("Music")
	if abs(_lowpass_hz - c) > 1.0:
		var k = clamp(a / 0.2, 0.0, 1.0)
		_lowpass_hz = exp(lerp(log(_lowpass_hz), log(c), k))
		_lowpass_fx.cutoff_hz = _lowpass_hz
		AudioServer.set_bus_effect_enabled(d, _lowpass_index, true)
	elif not _paused:
		AudioServer.set_bus_effect_enabled(d, _lowpass_index, false)


func _fix_drift() -> void:
	if _mode != "level":
		return
	var a = _layers["music_base"]
	if not a.playing:
		return
	var c = a.get_playback_position()
	for n in ["music_melody", "music_tension"]:
		var p = _layers[n]
		if p.playing and abs(p.get_playback_position() - c) > DRIFT_LIMIT:
			p.play(c)


func layer_drift() -> float:
	var a = _layers["music_base"]
	var c = 0.0
	for n in ["music_melody", "music_tension"]:
		c = max(c, abs(_layers[n].get_playback_position() - a.get_playback_position()))
	return c


func hover_hook(b: Control) -> void:
	b.connect("mouse_entered", self, "play", ["ui_hover", 1.0, 0.0])
