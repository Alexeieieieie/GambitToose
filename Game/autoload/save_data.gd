extends Node

# Everything that is remembered between launches, in a local file only.
# A missing or corrupt file is treated as a fresh install; it never crashes the game.

const DEFAULT_PATH = "user://save.cfg"

var path = DEFAULT_PATH
var tutorial_done = false
var tutorial_skipped = false
var language = "en"
var sound_on = true
var vol_master = 100             # 0..100
var vol_music = 60
var vol_effects = 90
var best = {}                    # level id -> {"score", "played"}
var goal_masks = {}              # level id -> bit mask of the star goals ever earned (bit i = goal i)


func _ready() -> void:
	load_data()


func _reset_values() -> void:
	tutorial_done = false
	tutorial_skipped = false
	language = "en"
	sound_on = true
	vol_master = 100
	vol_music = 60
	vol_effects = 90
	best = {}
	goal_masks = {}


func _as_volume(v, default: int) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_REAL:
		return default
	return int(clamp(int(v), 0, 100))


func _as_bool(v) -> bool:
	return typeof(v) == TYPE_BOOL and v


func load_data() -> bool:
	# Returns true if a valid file was read.
	_reset_values()
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	tutorial_done = _as_bool(cfg.get_value("meta", "tutorial_done", false))
	tutorial_skipped = _as_bool(cfg.get_value("meta", "tutorial_skipped", false))
	sound_on = not (typeof(cfg.get_value("meta", "sound_on", true)) == TYPE_BOOL \
			and cfg.get_value("meta", "sound_on", true) == false)
	vol_master = _as_volume(cfg.get_value("meta", "vol_master", 100), 100)
	vol_music = _as_volume(cfg.get_value("meta", "vol_music", 60), 60)
	vol_effects = _as_volume(cfg.get_value("meta", "vol_effects", 90), 90)
	var lang = cfg.get_value("meta", "language", "en")
	language = lang if (typeof(lang) == TYPE_STRING and lang in ["en", "ru"]) else "en"
	if cfg.has_section("score"):
		for key in cfg.get_section_keys("score"):
			if not key.is_valid_integer():
				continue
			var id = int(key)
			best[id] = {
				"score": int(cfg.get_value("score", key, 0)),
				"played": _as_bool(cfg.get_value("played", key, false)),
			}
	# Old saves had a "stars" section from the previous star rule: it is ignored on purpose.
	if cfg.has_section("goals"):
		for key in cfg.get_section_keys("goals"):
			if key.is_valid_integer():
				var m = cfg.get_value("goals", key, 0)
				goal_masks[int(key)] = int(m) & 7 if typeof(m) == TYPE_INT else 0
	return true


func save_data() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "tutorial_done", tutorial_done)
	cfg.set_value("meta", "tutorial_skipped", tutorial_skipped)
	cfg.set_value("meta", "language", language)
	cfg.set_value("meta", "sound_on", sound_on)
	cfg.set_value("meta", "vol_master", vol_master)
	cfg.set_value("meta", "vol_music", vol_music)
	cfg.set_value("meta", "vol_effects", vol_effects)
	for id in best.keys():
		cfg.set_value("score", str(id), best[id]["score"])
		cfg.set_value("played", str(id), best[id]["played"])
	for id in goal_masks.keys():
		cfg.set_value("goals", str(id), goal_masks[id])
	cfg.save(path)


func is_first_run() -> bool:
	return not tutorial_done


func finish_tutorial(skipped: bool) -> void:
	# Skipping marks the tutorial as done too, so it is not forced again.
	tutorial_done = true
	if skipped:
		tutorial_skipped = true
	save_data()


func set_language(code: String) -> void:
	language = code
	save_data()


func set_sound(on: bool) -> void:
	sound_on = on
	save_data()


func set_volumes(v_master: int, v_music: int, v_effects: int) -> void:
	vol_master = int(clamp(v_master, 0, 100))
	vol_music = int(clamp(v_music, 0, 100))
	vol_effects = int(clamp(v_effects, 0, 100))
	save_data()


func get_best(id: int) -> Dictionary:
	return best.get(id, {"score": 0, "played": false})


func get_mask(id: int) -> int:
	return int(goal_masks.get(id, 0))


func get_stars(id: int) -> int:
	return popcount(get_mask(id))


static func popcount(mask: int) -> int:
	var n = 0
	for i in range(3):
		if mask & (1 << i):
			n += 1
	return n


func save_result(id: int, score: int, mask: int) -> int:
	# Earned goals stay earned: the new mask is ORed into the old one.
	# Returns the bits that are new in this run.
	var b = get_best(id)
	if not b["played"] or score > b["score"]:
		b["score"] = score
	b["played"] = true
	best[id] = b
	var old = get_mask(id)
	goal_masks[id] = (old | mask) & 7
	save_data()
	return mask & ~old & 7


func delete_save() -> void:
	var d = Directory.new()
	if d.file_exists(path):
		d.remove(path)
	_reset_values()


func _input(event: InputEvent) -> void:
	# Debug builds only: F9 wipes the save and starts over, to test the first-run flow.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and event.scancode == KEY_F9:
		delete_save()
		# Looked up by path: autoloads that need SaveData must not be referenced from here.
		get_node("/root/Strings").lang = "en"
		get_node("/root/Sfx").set_enabled(true, false)
		get_tree().change_scene("res://ui/boot.tscn")
