extends Node2D


const C = preload("res://sim/constants.gd")
const Vehicle = preload("res://sim/vehicle.gd")
const DrawUtil = preload("res://ui/draw_util.gd")

var sim
var effects = []
var jam_rects = []
var jam_timer = 0.0
var clock = 0.0
var hover_cell = C.NO_CELL
var hover_ok = false
var hover_show = false


func setup(b) -> void:
	sim = b


func add(b: String, f: Array, g: float, h: Color = Color(1, 1, 1)) -> void:
	effects.append({"kind": b, "cells": f, "age": 0.0, "life": g, "color": h})


func _process(b: float) -> void:
	clock += b
	var f = []
	for e in effects:
		e["age"] += b
		if e["age"] < e["life"]:
			f.append(e)
	effects = f
	jam_timer += b
	if jam_timer >= 0.25:
		jam_timer = 0.0
		_find_jams()
	update()


func _find_jams() -> void:
	jam_rects = []
	if sim == null:
		return
	var b = {}
	var f = []
	for v in sim.vehicles:
		if (v.state == Vehicle.S.WAITING or v.state == Vehicle.S.STRANDED) and v.wait_time > 1.0:
			if not b.has(v.cell):
				b[v.cell] = true
				f.append(v.cell)
	var g = {}
	for h in f:
		if g.has(h):
			continue
		var j = [h]
		g[h] = true
		var lo = h
		var hi = h
		var n = 0
		while j.size() > 0:
			var l = j.pop_back()
			n += 1
			lo = Vector2(min(lo.x, l.x), min(lo.y, l.y))
			hi = Vector2(max(hi.x, l.x), max(hi.y, l.y))
			for d in C.DIRS:
				var nb = l + d
				if b.has(nb) and not g.has(nb):
					g[nb] = true
					j.append(nb)
		if n > 3:
			jam_rects.append(Rect2(lo * C.TILE, (hi - lo + Vector2(1, 1)) * C.TILE).grow(4.0))


func _draw() -> void:
	if sim == null:
		return
	var b = 0.5 + 0.5 * sin(clock * 6.0)
	for r in jam_rects:
		draw_rect(r, Palette.alpha(Palette.JAM, 0.10 + 0.08 * b))
		DrawUtil.dashed_rect(self, r.grow(b * 2.0), Palette.JAM, 2.5)
	for e in effects:
		var k = e["age"] / e["life"]
		var f = e["kind"]
		for g in e["cells"]:
			var c = sim.grid.center(g)
			var h = Rect2(g * C.TILE, Vector2(C.TILE, C.TILE))
			if f == "pop":
				var s = 1.0 + 0.35 * sin(k * PI) * (1.0 - k)
				var j = C.TILE * 0.5 * s
				draw_rect(Rect2(c - Vector2(j, j), Vector2(j, j) * 2.0),
						Palette.alpha(Palette.WHITE, 0.7 * (1.0 - k)), false, 3.0)
			elif f == "deliver":
				draw_arc(c, 10.0 + 22.0 * k, 0.0, TAU, 20, Palette.alpha(e["color"], 1.0 - k), 3.0)
				draw_arc(c, 4.0 + 14.0 * k, 0.0, TAU, 16, Palette.alpha(Palette.WHITE, 1.0 - k), 2.0)
			elif f == "crash":
				var on = fmod(e["age"], 0.3) < 0.15
				draw_rect(h.grow(3.0), Palette.alpha(Palette.JAM, 0.55 if on else 0.2))
				draw_rect(h.grow(6.0), Palette.JAM, false, 3.0)
				for i in range(8):
					var a = i * TAU / 8.0
					var l = Vector2(cos(a), sin(a))
					draw_line(c + l * (8.0 + 10.0 * min(k * 4.0, 1.0)), c + l * (14.0 + 22.0 * min(k * 4.0, 1.0)),
							Palette.YELLOW, 3.0)
			elif f == "deadlock":
				var m = fmod(e["age"], 0.4) < 0.2
				draw_rect(h, Palette.alpha(Palette.JAM, 0.6 if m else 0.25))
				DrawUtil.hatch(self, h, Palette.alpha(Palette.NAVY, 0.6), 8.0, 1.5)
			elif f == "new":
				draw_rect(h.grow(4.0 + 6.0 * b), Palette.alpha(Palette.YELLOW, 1.0 - k * 0.5), false, 3.0)
			elif f == "erase":
				draw_rect(h.grow(-6.0 * k), Palette.alpha(Palette.JAM, 0.5 * (1.0 - k)))
	if hover_show and sim.grid.in_bounds(hover_cell):
		var hr = Rect2(hover_cell * C.TILE, Vector2(C.TILE, C.TILE))
		var o = Palette.WHITE if hover_ok else Palette.alpha(Palette.NAVY, 0.45)
		draw_rect(hr, Palette.alpha(o, 0.18))
		draw_rect(hr, o, false, 2.0)
