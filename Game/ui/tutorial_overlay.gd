extends Control

# The scripted tutorial of Level 1: a list of steps, each with a text, cells to
# highlight and a completion check. Steps that are already satisfied are skipped.

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const MAP_ORIGIN = Vector2(0, 56)

var game
var steps = []
var step_no = 0
var clock = 0.0
var done_timer = 0.0


func setup(game_) -> void:
	game = game_
	rect_size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sim = game.sim
	var ends = [sim.factories[0].cell, sim.warehouses[0].cell]
	steps = [
		{"id": "road_connected", "text": Strings.TUT_ROAD, "cells": ends, "button": false},
		{"id": "speed_started", "text": Strings.TUT_PLAY, "cells": [], "button": true},
		{"id": "crash_detected", "text": Strings.TUT_WATCH, "cells": [], "button": false},
		{"id": "light_placed", "text": Strings.TUT_LIGHT, "cells": [], "button": false},
		{"id": "light_mode_sensor", "text": Strings.TUT_SENSOR, "cells": [], "button": false},
		{"id": "finished", "text": Strings.TUT_DONE, "cells": [], "button": true},
	]


func _has_sensor_light() -> bool:
	for l in game.sim.lights:
		if l.mode == C.LightMode.SENSOR:
			return true
	return false


func _is_done(id: String) -> bool:
	var sim = game.sim
	if id == "road_connected":
		return sim.has_route(sim.factories[0])
	if id == "speed_started":
		return game.speed > 0.0 or sim.time > 0.0
	if id == "crash_detected":
		return game.crash_seen or sim.lights.size() > 0 or sim.time > 40.0
	if id == "light_placed":
		return sim.lights.size() > 0
	if id == "light_mode_sensor":
		return _has_sensor_light()
	if id == "finished":
		return done_timer > 5.0 or game.speed > 0.0
	return true


func _process(delta: float) -> void:
	if game == null or step_no >= steps.size():
		visible = false
		return
	clock += delta
	if steps[step_no]["id"] == "finished":
		done_timer += delta
	while step_no < steps.size() and _is_done(steps[step_no]["id"]):
		step_no += 1
	update()


func current_id() -> String:
	if step_no < steps.size():
		return steps[step_no]["id"]
	return ""


func _draw() -> void:
	if game == null or step_no >= steps.size() or game.modal:
		return
	var step = steps[step_no]
	var pulse = 0.5 + 0.5 * sin(clock * 5.0)
	var f = Fonts.make(18, true)
	var w = f.get_string_size(step["text"]).x + 56.0
	var r = Rect2((SCREEN.x - w) / 2.0, 59, w, 34)
	draw_style_box(ThemeBuilder.box(Palette.NAVY, 17, 2, Palette.YELLOW), r)
	DrawUtil.centered(self, f, r.position + r.size / 2.0, step["text"], Palette.WHITE)
	var cells = step["cells"].duplicate()
	if step["id"] == "light_placed":
		if game.crash_cell != C.NO_CELL:
			cells.append(game.crash_cell)
		else:
			for cell in game.sim.grid.road_cells:
				if game.sim.grid.is_junction(cell):
					cells.append(cell)
					break
	for cell in cells:
		var tr = Rect2(MAP_ORIGIN + cell * C.TILE, Vector2(C.TILE, C.TILE)).grow(3.0 + 5.0 * pulse)
		draw_rect(tr, Palette.YELLOW, false, 3.0)
		draw_rect(tr.grow(3.0), Palette.alpha(Palette.NAVY, 0.6), false, 1.5)
	if step["button"]:
		var br = game.hud.pause_rect().grow(3.0 + 4.0 * pulse)
		draw_rect(br, Palette.WHITE, false, 3.0)
		DrawUtil.triangle(self, Vector2(br.position.x + br.size.x / 2.0, br.end.y + 16.0 + 4.0 * pulse),
				Vector2(0, -1), 10.0, Palette.YELLOW)
