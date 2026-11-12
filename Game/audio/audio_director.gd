extends Reference


const C = preload("res://sim/constants.gd")

const DELIVER_MERGE_WINDOW = 0.15
const STREAK_RESET_SECONDS = 15.0
const MAX_NOTE = 4
const INTENSITY_INTERVAL = 0.5
const TENSION_ON = 0.5
const TENSION_OFF = 0.35
const COUNTDOWN_FROM = 10

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

const MAPPED = ["deliver", "jam_warn", "gridlock_warn", "patience_low", "crash", "light_switch",
		"goal_reached", "goal_failed", "countdown_tick"]

var clock = 0.0
var streak = 0
var last_delivery = -1000.0
var intensity = 0.0
var tension_on = false
var melody_on = false
var duck_db = 0.0
var duck_until = 0.0
var requests = []

var _pending_note = -1
var _pending_at = 0.0
var _last_played = {}
var _voices = {}
var _intensity_timer = 0.0
var _countdown_mark = -1


static func all_files() -> Array:
	var a = []
	for b in REGISTRY.keys():
		var e = REGISTRY[b]
		if e.has("files"):
			a.append_array(e["files"])
		else:
			a.append(b)
	a.append_array(LOOP_FILES)
	a.append_array(MUSIC_FILES)
	return a


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
	var a = requests
	requests = []
	return a


func request(a: String, db: float = 0.0, b: float = 1.0, c: int = -1) -> bool:
	if not REGISTRY.has(a):
		return false
	var e = REGISTRY[a]
	var d = _last_played.get(a, -1000.0)
	if (clock - d) * 1000.0 < float(e["cooldown_ms"]):
		return false
	var f = []
	for g in _voices.get(a, []):
		if g > clock:
			f.append(g)
	if f.size() >= int(e["max_voices"]):
		_voices[a] = f
		return false
	f.append(clock + float(e["dur"]))
	_voices[a] = f
	_last_played[a] = clock
	var h = a
	if e.has("files"):
		h = e["files"][int(clamp(c, 0, e["files"].size() - 1))]
	requests.append({"name": a, "file": h, "bus": e["bus"], "db": float(e["base_db"]) + db, "pitch": b,
			"priority": int(e["priority"]), "jitter": float(e["pitch_jitter"])})
	return true


func on_event(ev: Dictionary) -> void:
	var a = ev.get("type", "")
	if a == "deliver":
		_on_delivery()
	elif a == "jam_start":
		streak = 0
		request("jam_warn")
		duck(4.0, 1.0)
	elif a == "gridlock_risk":
		request("gridlock_warn")
	elif a == "patience_low":
		request("patience_low")
	elif a == "crash":
		request("crash")
	elif a == "light_switch":
		request("light_switch")
	elif a == "goal_reached":
		request("goal_reached")
	elif a == "goal_failed":
		request("goal_failed")


func _on_delivery() -> void:
	melody_on = true
	last_delivery = clock
	var a = int(min(streak, MAX_NOTE))
	streak = int(min(streak + 1, MAX_NOTE))
	if _pending_note < 0:
		_pending_note = a
		_pending_at = clock
	else:
		_pending_note = int(max(_pending_note, a))


func update(dt: float, a = null) -> void:
	clock += dt
	if _pending_note >= 0 and clock - _pending_at >= DELIVER_MERGE_WINDOW:
		request("deliver", 0.0, 1.0, _pending_note)
		_pending_note = -1
	if streak > 0 and clock - last_delivery > STREAK_RESET_SECONDS:
		streak = 0
	if duck_db != 0.0 and clock >= duck_until:
		duck_db = 0.0
	if a != null:
		_intensity_timer += dt
		if _intensity_timer >= INTENSITY_INTERVAL:
			_intensity_timer = 0.0
			update_intensity(a)
		_update_countdown(a)


func duck(db: float, a: float) -> void:
	duck_db = -abs(db)
	duck_until = clock + a


func duck_offset() -> float:
	return duck_db if clock < duck_until else 0.0


func update_intensity(a) -> float:
	var b = 0
	var c = a.grid.road_cells.size()
	for d in a.density.keys():
		if a.density[d] > 0.8:
			b += 1
	var f = float(b) / float(max(c, 1))
	var g = 1.0
	for w in a.warehouses:
		if a.color_active(w.color):
			g = min(g, w.patience / C.WAREHOUSE_PATIENCE_MAX)
	var h = clamp(a.still_time / C.GRIDLOCK_SECONDS, 0.0, 1.0)
	var i = 0.5 * clamp(f * 4.0, 0.0, 1.0) + 0.3 * (1.0 - g) + 0.2 * h
	return set_intensity_target(i)


func set_intensity_target(a: float) -> float:
	intensity = clamp(lerp(intensity, clamp(a, 0.0, 1.0), 0.35), 0.0, 1.0)
	if not tension_on and intensity > TENSION_ON:
		tension_on = true
	elif tension_on and intensity < TENSION_OFF:
		tension_on = false
	return intensity


func _update_countdown(a) -> void:
	if a.time_limit <= 0.0 or a.finished:
		return
	var b = a.time_left()
	if b <= 0.0 or b > COUNTDOWN_FROM:
		_countdown_mark = -1
		return
	var c = int(ceil(b))
	if c != _countdown_mark:
		_countdown_mark = c
		request("countdown_tick")


func layer_targets() -> Dictionary:
	return {"base": 1.0, "melody": 1.0 if melody_on else 0.0, "tension": 1.0 if tension_on else 0.0}


func ambience_level(a: int) -> float:
	return clamp(float(a) / 40.0, 0.0, 1.0)


static func music_pitch(a: float) -> float:
	if a >= 4.0:
		return 1.08
	if a >= 2.0:
		return 1.04
	return 1.0
