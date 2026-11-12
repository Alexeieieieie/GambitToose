extends Node2D


const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const Intersection = preload("res://sim/intersection.gd")

var sim
var clock = 0.0


func setup(a) -> void:
	sim = a


func _process(a: float) -> void:
	clock += a
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
	var a = Palette.cargo(f.color)
	var b = Palette.cargo_dark(f.color)
	var e = f.is_active(sim.time)
	if not e:
		a = a.linear_interpolate(Palette.GRASS, 0.45)
		b = b.linear_interpolate(Palette.GRASS, 0.45)
	draw_rect(Rect2(o + Vector2(5, 8), Vector2(34, 31)), Palette.alpha(Palette.NAVY, 0.2))
	draw_rect(Rect2(o + Vector2(26, 0), Vector2(8, 14)), b)
	draw_rect(Rect2(o + Vector2(3, 10), Vector2(34, 27)), a)
	draw_rect(Rect2(o + Vector2(3, 10), Vector2(34, 7)), b)
	draw_rect(Rect2(o + Vector2(8, 22), Vector2(9, 9)), Palette.CARD)
	draw_rect(Rect2(o + Vector2(22, 22), Vector2(9, 9)), Palette.CARD)
	if e:
		var g = fmod(clock * 0.8 + f.cell.x * 0.37, 1.0)
		draw_circle(o + Vector2(30, -2 - g * 10.0), 3.0 + g * 3.0, Palette.alpha(Palette.WHITE, 0.7 * (1.0 - g)))
	if f.no_route and e:
		_draw_warning(o + Vector2(20, -8))


func _draw_warning(p: Vector2) -> void:
	var a = sin(clock * 6.0) * 2.0
	p.y += a
	draw_colored_polygon(PoolVector2Array([p + Vector2(0, -11), p + Vector2(11, 8), p + Vector2(-11, 8)]), Palette.NAVY)
	draw_colored_polygon(PoolVector2Array([p + Vector2(0, -7), p + Vector2(7, 6), p + Vector2(-7, 6)]), Palette.YELLOW)
	DrawUtil.centered(self, Fonts.make(12, true), p + Vector2(0, 1), Strings.t("NO_ROUTE"), Palette.NAVY)


func _draw_warehouse(w) -> void:
	var o = w.cell * C.TILE
	var a = Palette.cargo(w.color)
	var b = Palette.cargo_dark(w.color)
	draw_rect(Rect2(o + Vector2(5, 16), Vector2(34, 23)), Palette.alpha(Palette.NAVY, 0.2))
	draw_rect(Rect2(o + Vector2(3, 15), Vector2(34, 22)), a)
	draw_colored_polygon(PoolVector2Array([o + Vector2(0, 16), o + Vector2(20, 2), o + Vector2(40, 16)]), b)
	draw_rect(Rect2(o + Vector2(14, 22), Vector2(12, 15)), Palette.CARD)
	draw_line(o + Vector2(20, 22), o + Vector2(20, 37), b, 1.0)
	var k = clamp(w.patience / C.WAREHOUSE_PATIENCE_MAX, 0.0, 1.0)
	var e = Rect2(o + Vector2(2, -9), Vector2(36, 7))
	var g = Palette.OK
	if k < 0.25:
		g = Palette.JAM
	elif k < 0.5:
		g = Palette.BUSY
	draw_rect(e.grow(1.5), Palette.NAVY)
	draw_rect(Rect2(e.position, Vector2(e.size.x * k, e.size.y)), g)
	if k < 0.25 and fmod(clock, 0.5) < 0.25:
		draw_rect(e.grow(3.0), Palette.JAM, false, 2.0)


func _axis_color(l, a: int) -> Color:
	if l.green_axis != a:
		return Palette.JAM
	if l.phase == Intersection.Phase.GREEN:
		return Palette.OK
	if l.phase == Intersection.Phase.YELLOW:
		return Palette.BUSY
	return Palette.JAM


func _draw_light(l) -> void:
	var c = sim.grid.center(l.cell)
	var a = C.TILE / 2.0
	var h = _axis_color(l, 0)
	var v = _axis_color(l, 1)
	draw_line(c + Vector2(-a, 1), c + Vector2(-a, 12), h, 3.0)
	draw_line(c + Vector2(a, -1), c + Vector2(a, -12), h, 3.0)
	draw_line(c + Vector2(-1, -a), c + Vector2(-12, -a), v, 3.0)
	draw_line(c + Vector2(1, a), c + Vector2(12, a), v, 3.0)
	var b = Rect2(c + Vector2(a - 13, -a - 5), Vector2(12, 28))
	draw_rect(b, Palette.LIGHT_BOX)
	var e = 0
	if h == Palette.OK:
		e = 2
	elif h == Palette.BUSY:
		e = 1
	var g = [Palette.JAM, Palette.BUSY, Palette.OK]
	for i in range(3):
		var j = b.position + Vector2(6, 5 + i * 9)
		draw_circle(j, 3.5, g[i] if i == e else Palette.LIGHT_OFF)
	var m = b.position + Vector2(6, 34)
	if l.mode == C.LightMode.SENSOR:
		draw_arc(m, 4.0, PI, TAU, 6, Palette.NAVY, 2.0)
		draw_circle(m, 1.5, Palette.NAVY)
	elif l.mode == C.LightMode.PRIORITY:
		DrawUtil.triangle(self, m, Vector2(0, -1), 5.0, Palette.URGENT_RING)


func _draw_sorter(s) -> void:
	var c = sim.grid.center(s.cell)
	var r = 10.0
	var a = PoolVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(PoolVector2Array([c + Vector2(0, -r - 2), c + Vector2(r + 2, 0), c + Vector2(0, r + 2),
			c + Vector2(-r - 2, 0)]), Palette.SORTER_DARK)
	draw_colored_polygon(a, Palette.SORTER)
	var b = {C.CargoColor.BLUE: -5.0, C.CargoColor.RED: 5.0, C.CargoColor.URGENT: 0.0}
	for e in [C.CargoColor.BLUE, C.CargoColor.RED, C.CargoColor.URGENT]:
		var d = s.rules.get(e, Vector2())
		if d == Vector2():
			continue
		var g = Vector2(-d.y, d.x) * b[e]
		var at = c + d * 15.0 + g
		DrawUtil.triangle(self, at, d, 6.5, Palette.WHITE)
		DrawUtil.triangle(self, at, d, 4.5, Palette.cargo(e))
