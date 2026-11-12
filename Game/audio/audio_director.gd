extends Reference

# Decides WHAT to play. No scene tree, no audio devices: it takes simulation events and
# game state and produces sound requests and target music layer levels, so it is testable
# headless. Autoload Sfx executes the requests. It only observes; it never touches sim state.

const C = preload("res://sim/constants.gd")

const DELIVER_MERGE_WINDOW = 0.15    # deliveries closer than this play as one sound
const STREAK_RESET_SECONDS = 15.0
const MAX_NOTE = 4
const INTENSITY_INTERVAL = 0.5
const TENSION_ON = 0.5
const TENSION_OFF = 0.35
const COUNTDOWN_FROM = 10

# bus, base_db, priority (higher survives), cooldown_ms, max_voices, pitch_jitter, dur (seconds), files
const REGISTRY = {
	"deliver": {"bus": "SFX", "base_db": 0.0, "priority": 3, "cooldown_ms": 0, "max_voices": 3, "pitch_jitter": 0.0, "dur": 0.3,
			"files": ["deliver_0", "deliver_1", "deliver_2", "deliver_3", "deliver_4"]},
	"place_road": {"bus": "SFX", "base_db": -2.0, "priority": 2, "cooldown_ms": 40, "max_voices": 2, "pitch_jitter": 0.03, "dur": 0.09},
	"place_bridge": {"bus": "SFX", "base_db": -2.0, "priority": 2, "cooldown_ms": 60, "max_voices": 2, "pitch_jitter": 0.03, "dur": 0.14},
	"place_light": {"bus": "SFX", "base_db": -2.0, "priority": 2, "cooldown_ms": 60, "max_voices": 2, "pitch_jitter": 0.02, "dur": 0.16},
	"place_sorter": {"bus": "SFX", "base_db": -2.0, "priority": 2, "cooldown_ms": 60, "max_voices": 2, "pitch_jitter": 0.02, "dur": 0.15},
	"erase": {"bus": "SFX", "base_db": -3.0, "priority": 2, "cooldown_ms": 50, "max_voices": 2, "pitch_jitter": 0.04, "dur": 0.12},
	"invalid": {"bus": "SFX", "base_db": -3.0, "priority": 3, "cooldown_ms": 150, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.15},
	"tool_select": {"bus": "UI", "base_db": -2.0, "priority": 1, "cooldown_ms": 40, "max_voices": 1, "pitch_jitter": 0.02, "dur": 0.05},
	"ui_click": {"bus": "UI", "base_db": 0.0, "priority": 1, "cooldown_ms": 30, "max_voices": 2, "pitch_jitter": 0.02, "dur": 0.04},
	"ui_hover": {"bus": "UI", "base_db": -4.0, "priority": 0, "cooldown_ms": 60, "max_voices": 1, "pitch_jitter": 0.03, "dur": 0.02},
	"ui_toggle_on": {"bus": "UI", "base_db": 0.0, "priority": 1, "cooldown_ms": 80, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.08},
	"ui_toggle_off": {"bus": "UI", "base_db": 0.0, "priority": 1, "cooldown_ms": 80, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.08},
	"panel_open": {"bus": "UI", "base_db": 0.0, "priority": 1, "cooldown_ms": 100, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.15},
	"panel_close": {"bus": "UI", "base_db": 0.0, "priority": 1, "cooldown_ms": 100, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.15},
	"light_switch": {"bus": "SFX", "base_db": -12.0, "priority": 1, "cooldown_ms": 120, "max_voices": 2, "pitch_jitter": 0.02, "dur": 0.03},
	"speed_up": {"bus": "UI", "base_db": 0.0, "priority": 1, "cooldown_ms": 80, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.12},
	"speed_down": {"bus": "UI", "base_db": 0.0, "priority": 1, "cooldown_ms": 80, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.12},
	"pause": {"bus": "UI", "base_db": 0.0, "priority": 2, "cooldown_ms": 150, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.2},
	"resume": {"bus": "UI", "base_db": 0.0, "priority": 2, "cooldown_ms": 150, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.2},
	"jam_warn": {"bus": "SFX", "base_db": -1.0, "priority": 4, "cooldown_ms": 5000, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.35},
	"gridlock_warn": {"bus": "SFX", "base_db": -1.0, "priority": 4, "cooldown_ms": 2000, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.5},
	"patience_low": {"bus": "SFX", "base_db": -1.0, "priority": 4, "cooldown_ms": 1500, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.3},
	"crash": {"bus": "SFX", "base_db": 0.0, "priority": 5, "cooldown_ms": 300, "max_voices": 2, "pitch_jitter": 0.0, "dur": 0.3},
	"countdown_tick": {"bus": "SFX", "base_db": -3.0, "priority": 2, "cooldown_ms": 700, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.05},
	"goal_reached": {"bus": "SFX", "base_db": 0.0, "priority": 4, "cooldown_ms": 300, "max_voices": 2, "pitch_jitter": 0.0, "dur": 0.4},
	"goal_failed": {"bus": "SFX", "base_db": 0.0, "priority": 4, "cooldown_ms": 300, "max_voices": 2, "pitch_jitter": 0.0, "dur": 0.35},
	"star_1": {"bus": "SFX", "base_db": 0.0, "priority": 5, "cooldown_ms": 0, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.6},
	"star_2": {"bus": "SFX", "base_db": 0.0, "priority": 5, "cooldown_ms": 0, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.6},
	"star_3": {"bus": "SFX", "base_db": 0.0, "priority": 5, "cooldown_ms": 0, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.6},
	"win": {"bus": "SFX", "base_db": 0.0, "priority": 6, "cooldown_ms": 0, "max_voices": 1, "pitch_jitter": 0.0, "dur": 1.2},
	"lose": {"bus": "SFX", "base_db": 0.0, "priority": 6, "cooldown_ms": 0, "max_voices": 1, "pitch_jitter": 0.0, "dur": 1.0},
	"tutorial_step": {"bus": "UI", "base_db": 0.0, "priority": 3, "cooldown_ms": 100, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.2},
	"lesson_complete": {"bus": "SFX", "base_db": 0.0, "priority": 5, "cooldown_ms": 300, "max_voices": 1, "pitch_jitter": 0.0, "dur": 0.8},
}
const LOOP_FILES = ["siren", "ambience_traffic"]
const MUSIC_FILES = ["music_base", "music_melody", "music_tension", "music_menu"]

# Every sound name the event mapping may request (checked against REGISTRY by the tests).
const MAPPED = ["deliver", "jam_warn", "gridlock_warn", "patience_low", "crash", "light_switch",
		"goal_reached", "goal_failed", "countdown_tick"]

var clock = 0.0                  # director time in seconds (real time, advanced by update)
var streak = 0                   # index of the next delivery note, 0..MAX_NOTE
var last_delivery = -1000.0
var intensity = 0.0              # 0..1, smoothed
var tension_on = false
var melody_on = false
var duck_db = 0.0
var duck_until = 0.0
var requests = []                # drained by the player with take_requests()

var _pending_note = -1           # a delivery waiting out the merge window
var _pending_at = 0.0
var _last_played = {}            # sound -> clock of the last play
var _voices = {}                 # sound -> end times of the voices still sounding
var _intensity_timer = 0.0
var _countdown_mark = -1


static func all_files() -> Array:
	var out = []
	for name in REGISTRY.keys():
		var e = REGISTRY[name]
		if e.has("files"):
			out.append_array(e["files"])
		else:
			out.append(name)
	out.append_array(LOOP_FILES)
	out.append_array(MUSIC_FILES)
	return out


func reset() -> void:
	streak = 0
	last_delivery = -1000.0
	intensity = 0.0
	tension_on = false
	melody_on = false
	duck_db = 0.0
	duck_until = 0.0
	requests = []
	_pending_note = -1
	_last_played = {}
	_voices = {}
	_intensity_timer = 0.0
	_countdown_mark = -1


func take_requests() -> Array:
	var out = requests
	requests = []
	return out


# Asks for a sound. Enforces cooldown and the voice limit. Returns true if it was accepted.
func request(sound: String, db: float = 0.0, pitch: float = 1.0, variant: int = -1) -> bool:
	if not REGISTRY.has(sound):
		return false
	var e = REGISTRY[sound]
	var last = _last_played.get(sound, -1000.0)
	if (clock - last) * 1000.0 < float(e["cooldown_ms"]):
		return false
	var live = []
	for end in _voices.get(sound, []):
		if end > clock:
			live.append(end)
	if live.size() >= int(e["max_voices"]):
		_voices[sound] = live
		return false
	live.append(clock + float(e["dur"]))
	_voices[sound] = live
	_last_played[sound] = clock
	var file = sound
	if e.has("files"):
		file = e["files"][int(clamp(variant, 0, e["files"].size() - 1))]
	requests.append({"name": sound, "file": file, "bus": e["bus"], "db": float(e["base_db"]) + db, "pitch": pitch,
			"priority": int(e["priority"]), "jitter": float(e["pitch_jitter"])})
	return true


func on_event(ev: Dictionary) -> void:
	var kind = ev.get("type", "")
	if kind == "deliver":
		_on_delivery()
	elif kind == "jam_start":
		streak = 0
		request("jam_warn")
		duck(4.0, 1.0)
	elif kind == "gridlock_risk":
		request("gridlock_warn")
	elif kind == "patience_low":
		request("patience_low")
	elif kind == "crash":
		request("crash")
	elif kind == "light_switch":
		request("light_switch")
	elif kind == "goal_reached":
		request("goal_reached")
	elif kind == "goal_failed":
		request("goal_failed")


func _on_delivery() -> void:
	melody_on = true
	last_delivery = clock
	var note = int(min(streak, MAX_NOTE))
	streak = int(min(streak + 1, MAX_NOTE))
	if _pending_note < 0:
		_pending_note = note
		_pending_at = clock
	else:
		_pending_note = int(max(_pending_note, note))     # merged: the highest note of the burst


# Advances the clock by real seconds. `sim` (optional) lets the director read game state.
func update(dt: float, sim = null) -> void:
	clock += dt
	if _pending_note >= 0 and clock - _pending_at >= DELIVER_MERGE_WINDOW:
		request("deliver", 0.0, 1.0, _pending_note)
		_pending_note = -1
	if streak > 0 and clock - last_delivery > STREAK_RESET_SECONDS:
		streak = 0
	if duck_db != 0.0 and clock >= duck_until:
		duck_db = 0.0
	if sim != null:
		_intensity_timer += dt
		if _intensity_timer >= INTENSITY_INTERVAL:
			_intensity_timer = 0.0
			update_intensity(sim)
		_update_countdown(sim)


func duck(db: float, seconds: float) -> void:
	# `db` is a positive number of dB to lower the music by.
	duck_db = -abs(db)
	duck_until = clock + seconds


func duck_offset() -> float:
	return duck_db if clock < duck_until else 0.0


func update_intensity(sim) -> float:
	var jam_cells = 0
	var roads = sim.grid.road_cells.size()
	for cell in sim.density.keys():
		if sim.density[cell] > 0.8:
			jam_cells += 1
	var jam_fraction = float(jam_cells) / float(max(roads, 1))
	var lowest = 1.0
	for w in sim.warehouses:
		if sim.color_active(w.color):
			lowest = min(lowest, w.patience / C.WAREHOUSE_PATIENCE_MAX)
	var gridlock = clamp(sim.still_time / C.GRIDLOCK_SECONDS, 0.0, 1.0)
	var target = 0.5 * clamp(jam_fraction * 4.0, 0.0, 1.0) + 0.3 * (1.0 - lowest) + 0.2 * gridlock
	return set_intensity_target(target)


func set_intensity_target(target: float) -> float:
	# Smoothed so the layers never flicker; tension has hysteresis (on above 0.5, off below 0.35).
	intensity = clamp(lerp(intensity, clamp(target, 0.0, 1.0), 0.35), 0.0, 1.0)
	if not tension_on and intensity > TENSION_ON:
		tension_on = true
	elif tension_on and intensity < TENSION_OFF:
		tension_on = false
	return intensity


func _update_countdown(sim) -> void:
	if sim.time_limit <= 0.0 or sim.finished:
		return
	var left = sim.time_left()
	if left <= 0.0 or left > COUNTDOWN_FROM:
		_countdown_mark = -1
		return
	var whole = int(ceil(left))
	if whole != _countdown_mark:
		_countdown_mark = whole
		request("countdown_tick")


# Target level (0..1) of each music layer in a level.
func layer_targets() -> Dictionary:
	return {"base": 1.0, "melody": 1.0 if melody_on else 0.0, "tension": 1.0 if tension_on else 0.0}


# Ambient traffic loudness (0..1) from the number of vehicles.
func ambience_level(vehicle_count: int) -> float:
	return clamp(float(vehicle_count) / 40.0, 0.0, 1.0)


static func music_pitch(speed: float) -> float:
	if speed >= 4.0:
		return 1.08
	if speed >= 2.0:
		return 1.04
	return 1.0
