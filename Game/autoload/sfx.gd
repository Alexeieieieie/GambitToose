extends Node

# Sound effects pool and music. Everything is a local generated .wav file.

const POOL_SIZE = 6
const NAMES = ["deliver", "place", "bridge", "erase", "tick", "warn", "crash", "win", "lose", "click",
		"step", "lesson", "fanfare", "deny", "speed"]
# Semitone offsets of a major pentatonic ladder: deliveries in a row climb it.
const LADDER = [0, 2, 4, 7, 9, 12, 14, 16]
const MUSIC_DB = -9.0
const MUSIC_DUCKED_DB = -18.0

var enabled = true
var _streams = {}
var _pool = []
var _next = 0
var _music
var _siren
var _deliver_streak = 0
var _last_warn_msec = -100000


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in NAMES:
		var s = _load_stream(n, false)
		if s != null:
			_streams[n] = s
	for _i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = MUSIC_DB
	_music.stream = _load_stream("music", true)
	add_child(_music)
	_siren = AudioStreamPlayer.new()
	_siren.bus = "SFX"
	_siren.volume_db = -14.0
	_siren.stream = _load_stream("siren", true)
	add_child(_siren)
	set_enabled(SaveData.sound_on, false)
	if _music.stream != null:
		_music.play()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


func _load_stream(n: String, loop: bool):
	var path = "res://audio/" + n + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s != null and loop and s is AudioStreamSample:
		s.loop_mode = AudioStreamSample.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2   # 16-bit mono: two bytes per frame
	return s


func play(n: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(n):
		return
	var p = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[n]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func delivery_sound(during_jam: bool) -> void:
	# The ding climbs a musical scale while deliveries arrive without a jam.
	if during_jam:
		_deliver_streak = 0
	else:
		_deliver_streak = int(min(_deliver_streak + 1, LADDER.size() - 1))
	play("deliver", pow(2.0, LADDER[_deliver_streak] / 12.0), -4.0)


func reset_streak() -> void:
	_deliver_streak = 0


func warn() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_warn_msec < 5000:
		return
	_last_warn_msec = now
	play("warn", 1.0, -3.0)


func set_speed(speed: float) -> void:
	if _music == null:
		return
	if speed >= 4.0:
		_music.pitch_scale = 1.1
	elif speed >= 2.0:
		_music.pitch_scale = 1.05
	else:
		_music.pitch_scale = 1.0


func duck(on: bool) -> void:
	# Lowers the music under the results fanfare.
	if _music != null:
		_music.volume_db = MUSIC_DUCKED_DB if on else MUSIC_DB


func set_siren(on: bool) -> void:
	if _siren == null or _siren.stream == null:
		return
	if on and not _siren.playing:
		_siren.play()
	elif not on and _siren.playing:
		_siren.stop()


func set_enabled(on: bool, remember: bool = true) -> void:
	enabled = on
	if remember:
		SaveData.set_sound(on)
	for bus_name in ["Music", "SFX"]:
		var i = AudioServer.get_bus_index(bus_name)
		if i != -1:
			AudioServer.set_bus_mute(i, not on)


func toggle() -> bool:
	set_enabled(not enabled)
	return enabled
