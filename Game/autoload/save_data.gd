extends Node


const DEFAULT_PATH = "user://save.cfg"

var path = DEFAULT_PATH
var tutorial_done = false
var tutorial_skipped = false
var language = "en"
var sound_on = true
var vol_master = 100
var vol_music = 60
var vol_effects = 90
var best = {}
var goal_masks = {}


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


func _as_volume(v, a: int) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_REAL:
		return a
	return int(clamp(int(v), 0, 100))


func _as_bool(v) -> bool:
	return typeof(v) == TYPE_BOOL and v


func load_data() -> bool:
	_reset_values()
	var a = ConfigFile.new()
	if a.load(path) != OK:
		return false
	tutorial_done = _as_bool(a.get_value("meta", "tutorial_done", false))
	tutorial_skipped = _as_bool(a.get_value("meta", "tutorial_skipped", false))
	sound_on = not (typeof(a.get_value("meta", "sound_on", true)) == TYPE_BOOL \
			and a.get_value("meta", "sound_on", true) == false)
	vol_master = _as_volume(a.get_value("meta", "vol_master", 100), 100)
	vol_music = _as_volume(a.get_value("meta", "vol_music", 60), 60)
	vol_effects = _as_volume(a.get_value("meta", "vol_effects", 90), 90)
	var c = a.get_value("meta", "language", "en")
	language = c if (typeof(c) == TYPE_STRING and c in ["en", "ru"]) else "en"
	if a.has_section("score"):
		for e in a.get_section_keys("score"):
			if not e.is_valid_integer():
				continue
			var id = int(e)
			best[id] = {
				"score": int(a.get_value("score", e, 0)),
				"played": _as_bool(a.get_value("played", e, false)),
			}
	if a.has_section("goals"):
		for e in a.get_section_keys("goals"):
			if e.is_valid_integer():
				var m = a.get_value("goals", e, 0)
				goal_masks[int(e)] = int(m) & 7 if typeof(m) == TYPE_INT else 0
	return true


func save_data() -> void:
	var a = ConfigFile.new()
	a.set_value("meta", "tutorial_done", tutorial_done)
	a.set_value("meta", "tutorial_skipped", tutorial_skipped)
	a.set_value("meta", "language", language)
	a.set_value("meta", "sound_on", sound_on)
	a.set_value("meta", "vol_master", vol_master)
	a.set_value("meta", "vol_music", vol_music)
	a.set_value("meta", "vol_effects", vol_effects)
	for id in best.keys():
		a.set_value("score", str(id), best[id]["score"])
		a.set_value("played", str(id), best[id]["played"])
	for id in goal_masks.keys():
		a.set_value("goals", str(id), goal_masks[id])
	a.save(path)


func is_first_run() -> bool:
	return not tutorial_done


func finish_tutorial(a: bool) -> void:
	tutorial_done = true
	if a:
		tutorial_skipped = true
	save_data()


func set_language(a: String) -> void:
	language = a
	save_data()


func set_sound(on: bool) -> void:
	sound_on = on
	save_data()


func set_volumes(a: int, c: int, e: int) -> void:
	vol_master = int(clamp(a, 0, 100))
	vol_music = int(clamp(c, 0, 100))
	vol_effects = int(clamp(e, 0, 100))
	save_data()


func get_best(id: int) -> Dictionary:
	return best.get(id, {"score": 0, "played": false})


func get_mask(id: int) -> int:
	return int(goal_masks.get(id, 0))


func get_stars(id: int) -> int:
	return popcount(get_mask(id))


static func popcount(a: int) -> int:
	var n = 0
	for i in range(3):
		if a & (1 << i):
			n += 1
	return n


func save_result(id: int, a: int, c: int) -> int:
	var b = get_best(id)
	if not b["played"] or a > b["score"]:
		b["score"] = a
	b["played"] = true
	best[id] = b
	var e = get_mask(id)
	goal_masks[id] = (e | c) & 7
	save_data()
	return c & ~e & 7


func delete_save() -> void:
	var d = Directory.new()
	if d.file_exists(path):
		d.remove(path)
	_reset_values()


func _input(a: InputEvent) -> void:
	if OS.is_debug_build() and a is InputEventKey and a.pressed and not a.echo \
			and a.scancode == KEY_F9:
		delete_save()
		get_node("/root/Strings").lang = "en"
		get_node("/root/Sfx").set_enabled(true, false)
		get_tree().change_scene("res://ui/boot.tscn")
