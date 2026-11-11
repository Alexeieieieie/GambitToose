extends Node2D

# Draws factories, warehouses with their patience bars, lights and sorters.

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const Intersection = preload("res://sim/intersection.gd")

var sim
var clock = 0.0


func setup(sim_) -> void:
	sim = sim_


func _process(delta: float) -> void:
	clock += delta
	update()


func _draw() -> void:
	if sim == null:
		return
	for f in sim.factories:
		_draw_factory(f)
	for w in sim.warehouses:
		_draw_warehouse(w)
	for l in sim.lights:
		_draw_light(l)
	for s in sim.sorters:
		_draw_sorter(s)


func _draw_factory(f) -> void:
	var o = f.cell * C.TILE
	var col = Palette.cargo(f.color)
	var dark = Palette.cargo_dark(f.color)
	var active = f.is_active(sim.time)
	if not active:
		col = col.linear_interpolate(Palette.GRASS, 0.45)
		dark = dark.linear_interpolate(Palette.GRASS, 0.45)
	draw_rect(Rect2(o + Vector2(5, 8), Vector2(34, 31)), Palette.alpha(Palette.NAVY, 0.2))
	draw_rect(Rect2(o + Vector2(26, 0), Vector2(8, 14)), dark)              # chimney
	draw_rect(Rect2(o + Vector2(3, 10), Vector2(34, 27)), col)             # body
	draw_rect(Rect2(o + Vector2(3, 10), Vector2(34, 7)), dark)             # roof strip
	draw_rect(Rect2(o + Vector2(8, 22), Vector2(9, 9)), Palette.CARD)      # windows
	draw_rect(Rect2(o + Vector2(22, 22), Vector2(9, 9)), Palette.CARD)
	if active:
		var puff = fmod(clock * 0.8 + f.cell.x * 0.37, 1.0)
		draw_circle(o + Vector2(30, -2 - puff * 10.0), 3.0 + puff * 3.0, Palette.alpha(Palette.WHITE, 0.7 * (1.0 - puff)))
	if f.no_route and active:
		_draw_warning(o + Vector2(20, -8))


func _draw_warning(p: Vector2) -> void:
	var bob = sin(clock * 6.0) * 2.0
	p.y += bob
	draw_colored_polygon(PoolVector2Array([p + Vector2(0, -11), p + Vector2(11, 8), p + Vector2(-11, 8)]), Palette.NAVY)
	draw_colored_polygon(PoolVector2Array([p + Vector2(0, -7), p + Vector2(7, 6), p + Vector2(-7, 6)]), Palette.YELLOW)
	DrawUtil.centered(self, Fonts.make(12, true), p + Vector2(0, 1), Strings.t("NO_ROUTE"), Palette.NAVY)


func _draw_warehouse(w) -> void:
	var o = w.cell * C.TILE
	var col = Palette.cargo(w.color)
	var dark = Palette.cargo_dark(w.color)
	draw_rect(Rect2(o + Vector2(5, 16), Vector2(34, 23)), Palette.alpha(Palette.NAVY, 0.2))
	draw_rect(Rect2(o + Vector2(3, 15), Vector2(34, 22)), col)
	draw_colored_polygon(PoolVector2Array([o + Vector2(0, 16), o + Vector2(20, 2), o + Vector2(40, 16)]), dark)
	draw_rect(Rect2(o + Vector2(14, 22), Vector2(12, 15)), Palette.CARD)   # door
	draw_line(o + Vector2(20, 22), o + Vector2(20, 37), dark, 1.0)
	# Patience bar: the length and the color both change, so it reads without color.
	var k = clamp(w.patience / C.WAREHOUSE_PATIENCE_MAX, 0.0, 1.0)
	var bar = Rect2(o + Vector2(2, -9), Vector2(36, 7))
	var fill = Palette.OK
	if k < 0.25:
		fill = Palette.JAM
	elif k < 0.5:
		fill = Palette.BUSY
	draw_rect(bar.grow(1.5), Palette.NAVY)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), fill)
	if k < 0.25 and fmod(clock, 0.5) < 0.25:
		draw_rect(bar.grow(3.0), Palette.JAM, false, 2.0)


func _axis_color(l, axis: int) -> Color:
	if l.green_axis != axis:
		return Palette.JAM
	if l.phase == Intersection.Phase.GREEN:
		return Palette.OK
	if l.phase == Intersection.Phase.YELLOW:
		return Palette.BUSY
	return Palette.JAM


func _draw_light(l) -> void:
	var c = sim.grid.center(l.cell)
	var half = C.TILE / 2.0
	# Stop lines on the four approaches.
	var h = _axis_color(l, 0)
	var v = _axis_color(l, 1)
	draw_line(c + Vector2(-half, 1), c + Vector2(-half, 12), h, 3.0)
	draw_line(c + Vector2(half, -1), c + Vector2(half, -12), h, 3.0)
	draw_line(c + Vector2(-1, -half), c + Vector2(-12, -half), v, 3.0)
	draw_line(c + Vector2(1, half), c + Vector2(12, half), v, 3.0)
	# The box with three dots shows the horizontal road: top red, middle yellow, bottom green.
	var box = Rect2(c + Vector2(half - 13, -half - 5), Vector2(12, 28))
	draw_rect(box, Palette.LIGHT_BOX)
	var lit = 0
	if h == Palette.OK:
		lit = 2
	elif h == Palette.BUSY:
		lit = 1
	var cols = [Palette.JAM, Palette.BUSY, Palette.OK]
	for i in range(3):
		var dot = box.position + Vector2(6, 5 + i * 9)
		draw_circle(dot, 3.5, cols[i] if i == lit else Palette.LIGHT_OFF)
	# A small mark for the mode, so the mode is visible without opening the panel.
	var mark = box.position + Vector2(6, 34)
	if l.mode == C.LightMode.SENSOR:
		draw_arc(mark, 4.0, PI, TAU, 6, Palette.NAVY, 2.0)
		draw_circle(mark, 1.5, Palette.NAVY)
	elif l.mode == C.LightMode.PRIORITY:
		DrawUtil.triangle(self, mark, Vector2(0, -1), 5.0, Palette.URGENT_RING)


func _draw_sorter(s) -> void:
	var c = sim.grid.center(s.cell)
	var r = 10.0
	var pts = PoolVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(PoolVector2Array([c + Vector2(0, -r - 2), c + Vector2(r + 2, 0), c + Vector2(0, r + 2),
			c + Vector2(-r - 2, 0)]), Palette.SORTER_DARK)
	draw_colored_polygon(pts, Palette.SORTER)
	# One arrow per cargo color that has a rule; they are spread sideways so they do not overlap.
	var slot = {C.CargoColor.BLUE: -5.0, C.CargoColor.RED: 5.0, C.CargoColor.URGENT: 0.0}
	for color in [C.CargoColor.BLUE, C.CargoColor.RED, C.CargoColor.URGENT]:
		var d = s.rules.get(color, Vector2())
		if d == Vector2():
			continue
		var side = Vector2(-d.y, d.x) * slot[color]
		var at = c + d * 15.0 + side
		DrawUtil.triangle(self, at, d, 6.5, Palette.WHITE)
		DrawUtil.triangle(self, at, d, 4.5, Palette.cargo(color))
