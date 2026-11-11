extends Node2D

# Traffic density overlay. Redraws a few times per second, not every frame.

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")

var sim
var timer = 0.0


func setup(sim_) -> void:
	sim = sim_
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	timer += delta
	if timer >= C.HEATMAP_REDRAW_INTERVAL:
		timer = 0.0
		update()


func level_of(d: float) -> int:
	if d < 0.4:
		return 0
	if d < 0.8:
		return 1
	return 2


func _draw() -> void:
	if sim == null:
		return
	var g = sim.grid
	for cell in g.road_cells:
		if not g.is_roadlike(cell):
			continue
		var d = max(sim.density.get(cell, 0.0), float(g.occupants[cell].size()) / g.capacity(cell) * 0.6)
		var r = Rect2(cell * C.TILE + Vector2(2, 2), Vector2(C.TILE - 4, C.TILE - 4))
		var lv = level_of(d)
		if lv == 0:
			draw_rect(r, Palette.alpha(Palette.OK, 0.45))
		elif lv == 1:
			draw_rect(r, Palette.alpha(Palette.BUSY, 0.6))
			draw_rect(r, Palette.alpha(Palette.NAVY, 0.5), false, 1.0)
		else:
			draw_rect(r, Palette.alpha(Palette.JAM, 0.65))
			DrawUtil.hatch(self, r, Palette.alpha(Palette.NAVY, 0.75), 8.0, 1.5)
			draw_rect(r, Palette.NAVY, false, 2.0)
