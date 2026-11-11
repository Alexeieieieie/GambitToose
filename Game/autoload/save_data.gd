extends Node

# Everything that is remembered between launches, in a local file only.
# A missing or corrupt file is treated as a fresh install; it never crashes the game.

const DEFAULT_PATH = "user://save.cfg"

var path = DEFAULT_PATH
var tutorial_done = false
var tutorial_skipped = false
var language = "en"
var sound_on = true
var best = {}                    # level id -> {"score", "stars", "played"}


func _ready() -> void:
	load_data()


func _reset_values() -> void:
	tutorial_done = false
	tutorial_skipped = false
	language = "en"
	sound_on = true
	best = {}


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
	var lang = cfg.get_value("meta", "language", "en")
	language = lang if (typeof(lang) == TYPE_STRING and lang in ["en", "ru"]) else "en"
	if cfg.has_section("score"):
		for key in cfg.get_section_keys("score"):
			if not key.is_valid_integer():
				continue
			var id = int(key)
			best[id] = {
				"score": int(cfg.get_value("score", key, 0)),
				"stars": int(clamp(int(cfg.get_value("stars", key, 0)), 0, 3)),
				"played": _as_bool(cfg.get_value("played", key, false)),
			}
	return true


func save_data() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "tutorial_done", tutorial_done)
	cfg.set_value("meta", "tutorial_skipped", tutorial_skipped)
	cfg.set_value("meta", "language", language)
	cfg.set_value("meta", "sound_on", sound_on)
	for id in best.keys():
		cfg.set_value("score", str(id), best[id]["score"])
		cfg.set_value("stars", str(id), best[id]["stars"])
		cfg.set_value("played", str(id), best[id]["played"])
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


func get_best(id: int) -> Dictionary:
	return best.get(id, {"score": 0, "stars": 0, "played": false})


func save_result(id: int, score: int, stars: int) -> void:
	var b = get_best(id)
	if not b["played"] or score > b["score"]:
		b["score"] = score
	b["stars"] = int(max(b["stars"], stars))
	b["played"] = true
	best[id] = b
	save_data()


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
