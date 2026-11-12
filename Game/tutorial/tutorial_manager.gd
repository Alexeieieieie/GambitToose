extends Reference


const C = preload("res://sim/constants.gd")

signal step_changed(step)
signal lesson_completed
signal tutorial_finished

const SUPPORTED = ["continue", "road_connected", "bridge_placed", "light_placed", "light_mode_set",
		"sorter_placed", "sorter_rule_set", "speed_started", "speed_set", "heatmap_toggled",
		"delivered_count", "urgent_delivered", "crash", "level_won", "level_lost"]
const HINT_AFTER = 15.0
const SKIP_AFTER = 30.0
const CHECK_INTERVAL = 0.25
const STUCK_SECONDS = 8.0

var lesson = {}
var steps = []
var idx = 0
var sim
var state = {}
var step_time = 0.0
var check_timer = 0.0
var done = false
var hint_shown = false
var lesson_no = 1
var lesson_count = 6
var broken = false


func start(a: Dictionary, b, c: int = 1, d: int = 6) -> void:
	lesson = a
	steps = lesson["steps"]
	sim = b
	lesson_no = c
	lesson_count = d
	idx = 0
	done = false
	state = {"speed": 0.0, "heatmap": false}
	_enter_step()
	_check()


func is_final() -> bool:
	return lesson.get("final", false)


func current_step() -> Dictionary:
	if idx < steps.size():
		return steps[idx]
	return {}


func current_wait() -> String:
	var s = current_step()
	return s["wait"]["event"] if s.has("wait") else ""


func is_info_step() -> bool:
	return current_wait() == "continue"


func notify(a: String, b: Dictionary = {}) -> void:
	if done:
		return
	if a == "continue":
		if current_wait() == "continue":
			state["continue"] = true
	elif a == "speed_set":
		state["speed"] = float(b.get("value", 0.0))
	elif a == "speed_started":
		state["speed_started"] = true
	elif a == "heatmap_toggled":
		state["heatmap"] = bool(b.get("on", false))
	elif a == "crash":
		state["crash"] = true
	_check()


func tick(a: float) -> void:
	if done:
		return
	step_time += a
	check_timer += a
	if check_timer >= CHECK_INTERVAL:
		check_timer = 0.0
		_check()
		broken = sim.still_time >= STUCK_SECONDS and sim.vehicles.size() >= C.GRIDLOCK_MIN_VEHICLES


func hint_available() -> bool:
	return not done and not is_info_step() and step_time >= HINT_AFTER and current_step().has("hint_key")


func skip_available() -> bool:
	return not done and not is_info_step() and step_time >= SKIP_AFTER


func show_hint() -> void:
	hint_shown = true


func skip_step() -> void:
	if not done and not is_info_step():
		_advance()
		_check()


func needs_panel() -> String:
	return current_step().get("needs_panel", "")


func highlights() -> Dictionary:
	var s = current_step()
	return {"cells": s.get("highlight_cells", []), "ui": s.get("highlight_ui", [])}


func checklist() -> Array:
	var a = []
	for b in current_step().get("checklist", []):
		a.append([b["key"], _met(b["cond"])])
	return a



func _check() -> void:
	var a = 0
	while not done and a <= steps.size():
		a += 1
		if not _met(current_step()["wait"]):
			break
		_advance()


func _advance() -> void:
	idx += 1
	if idx >= steps.size():
		done = true
		emit_signal("lesson_completed")
		if is_final():
			emit_signal("tutorial_finished")
		return
	_enter_step()


func _enter_step() -> void:
	step_time = 0.0
	hint_shown = false
	state["continue"] = false
	for h in current_step().get("on_enter", []):
		_run_hook(h)
	emit_signal("step_changed", current_step())


func _run_hook(h: Dictionary) -> void:
	if h["hook"] == "spawn_urgent":
		sim.urgent_next[h["color"]] = true


func _met(w: Dictionary) -> bool:
	var e = w.get("event", "continue")
	if e == "continue":
		return state.get("continue", false)
	if e == "road_connected":
		return _connected(int(w.get("color", 0)))
	if e == "bridge_placed":
		return _bridges_ok(w)
	if e == "light_placed":
		return sim.lights.size() > 0
	if e == "light_mode_set":
		for l in sim.lights:
			if l.mode == w["mode"]:
				return true
		return false
	if e == "sorter_placed":
		return sim.sorters.size() > 0
	if e == "sorter_rule_set":
		return _sorter_rules_ok()
	if e == "speed_started":
		return state.get("speed_started", false) or sim.time > 0.0
	if e == "speed_set":
		return state.get("speed", 0.0) == float(w["value"])
	if e == "heatmap_toggled":
		return state.get("heatmap", false) == bool(w["on"])
	if e == "delivered_count":
		return sim.metrics.deliveries >= int(w["n"])
	if e == "urgent_delivered":
		return sim.metrics.urgent_deliveries >= int(w["n"])
	if e == "crash":
		return sim.crash_done or state.get("crash", false)
	if e == "level_won":
		return sim.result == "win"
	if e == "level_lost":
		return sim.result == "lose"
	return false


func _connected(a: int) -> bool:
	for f in sim.factories:
		if f.color == a:
			return sim.has_route(f)
	return false


func _bridges_ok(w: Dictionary) -> bool:
	var g = sim.grid
	if w.has("cells"):
		for a in w["cells"]:
			if g.tile(a) != C.Tile.BRIDGE:
				return false
		return true
	var n = 0
	for a in g.road_cells:
		if g.tile(a) == C.Tile.BRIDGE:
			n += 1
	return n >= int(w.get("count", 1))


func _sorter_rules_ok() -> bool:
	for s in sim.sorters:
		var rb = s.rules.get(C.CargoColor.BLUE, Vector2())
		var rr = s.rules.get(C.CargoColor.RED, Vector2())
		if rb != Vector2() and rr != Vector2() and rb != rr:
			for f in sim.factories:
				if not sim.has_route(f):
					return false
			return true
	return false
