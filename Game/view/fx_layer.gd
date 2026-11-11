extends Node2D

# Short-lived effects: build pops, delivery flashes, crash and deadlock flashes,
# jam rings, and the tile under the mouse.

const C = preload("res://sim/constants.gd")
const Vehicle = preload("res://sim/vehicle.gd")
const DrawUtil = preload("res://ui/draw_util.gd")

var sim
var effects = []                 # dictionaries: kind, cells, age, life, color
var jam_rects = []
var jam_timer = 0.0
var clock = 0.0
var hover_cell = C.NO_CELL
var hover_ok = false
var hover_show = false


func setup(sim_) -> void:
	sim = sim_


func add(kind: String, cells: Array, life: float, color: Color = Color(1, 1, 1)) -> void:
	effects.append({"kind": kind, "cells": cells, "age": 0.0, "life": life, "color": color})


func _process(delta: float) -> void:
	clock += delta
	var keep = []
	for e in effects:
		e["age"] += delta
		if e["age"] < e["life"]:
			keep.append(e)
	effects = keep
	jam_timer += delta
	if jam_timer >= 0.25:
		jam_timer = 0.0
		_find_jams()
	update()


func _find_jams() -> void:
	# Groups of neighboring tiles with waiting vehicles; a group above 3 tiles gets a ring.
	jam_rects = []
	if sim == null:
		return
	var waiting = {}
	var order = []
	for v in sim.vehicles:
		if (v.state == Vehicle.S.WAITING or v.state == Vehicle.S.STRANDED) and v.wait_time > 1.0:
			if not waiting.has(v.cell):
				waiting[v.cell] = true
				order.append(v.cell)
	var seen = {}
	for start in order:
		if seen.has(start):
			continue
		var stack = [start]
		seen[start] = true
		var lo = start
		var hi = start
		var n = 0
		while stack.size() > 0:
			var cell = stack.pop_back()
			n += 1
			lo = Vector2(min(lo.x, cell.x), min(lo.y, cell.y))
			hi = Vector2(max(hi.x, cell.x), max(hi.y, cell.y))
			for d in C.DIRS:
				var nb = cell + d
				if waiting.has(nb) and not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
		if n > 3:
			jam_rects.append(Rect2(lo * C.TILE, (hi - lo + Vector2(1, 1)) * C.TILE).grow(4.0))


func _draw() -> void:
	if sim == null:
		return
	var pulse = 0.5 + 0.5 * sin(clock * 6.0)
	for r in jam_rects:
		draw_rect(r, Palette.alpha(Palette.JAM, 0.10 + 0.08 * pulse))
		DrawUtil.dashed_rect(self, r.grow(pulse * 2.0), Palette.JAM, 2.5)
	for e in effects:
		var k = e["age"] / e["life"]
		var kind = e["kind"]
		for cell in e["cells"]:
			var c = sim.grid.center(cell)
			var tile_rect = Rect2(cell * C.TILE, Vector2(C.TILE, C.TILE))
			if kind == "pop":
				# Scale pop: a square that overshoots and settles.
				var s = 1.0 + 0.35 * sin(k * PI) * (1.0 - k)
				var half = C.TILE * 0.5 * s
				draw_rect(Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0),
						Palette.alpha(Palette.WHITE, 0.7 * (1.0 - k)), false, 3.0)
			elif kind == "deliver":
				draw_arc(c, 10.0 + 22.0 * k, 0.0, TAU, 20, Palette.alpha(e["color"], 1.0 - k), 3.0)
				draw_arc(c, 4.0 + 14.0 * k, 0.0, TAU, 16, Palette.alpha(Palette.WHITE, 1.0 - k), 2.0)
			elif kind == "crash":
				var on = fmod(e["age"], 0.3) < 0.15
				draw_rect(tile_rect.grow(3.0), Palette.alpha(Palette.JAM, 0.55 if on else 0.2))
				draw_rect(tile_rect.grow(6.0), Palette.JAM, false, 3.0)
				for i in range(8):
					var a = i * TAU / 8.0
					var dir = Vector2(cos(a), sin(a))
					draw_line(c + dir * (8.0 + 10.0 * min(k * 4.0, 1.0)), c + dir * (14.0 + 22.0 * min(k * 4.0, 1.0)),
							Palette.YELLOW, 3.0)
			elif kind == "deadlock":
				var on2 = fmod(e["age"], 0.4) < 0.2
				draw_rect(tile_rect, Palette.alpha(Palette.JAM, 0.6 if on2 else 0.25))
				DrawUtil.hatch(self, tile_rect, Palette.alpha(Palette.NAVY, 0.6), 8.0, 1.5)
			elif kind == "new":
				draw_rect(tile_rect.grow(4.0 + 6.0 * pulse), Palette.alpha(Palette.YELLOW, 1.0 - k * 0.5), false, 3.0)
			elif kind == "erase":
				draw_rect(tile_rect.grow(-6.0 * k), Palette.alpha(Palette.JAM, 0.5 * (1.0 - k)))
	if hover_show and sim.grid.in_bounds(hover_cell):
		var hr = Rect2(hover_cell * C.TILE, Vector2(C.TILE, C.TILE))
		var col = Palette.WHITE if hover_ok else Palette.alpha(Palette.NAVY, 0.45)
		draw_rect(hr, Palette.alpha(col, 0.18))
		draw_rect(hr, col, false, 2.0)
