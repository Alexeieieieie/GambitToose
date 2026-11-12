extends Node2D


const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

var sim
var body_style = {}
var cab_style = {}
var clock = 0.0


func setup(a) -> void:
	sim = a
	for c in [C.CargoColor.BLUE, C.CargoColor.RED, C.CargoColor.URGENT]:
		body_style[c] = ThemeBuilder.box(Palette.cargo(c), 3, 1, Palette.cargo_dark(c))
		cab_style[c] = ThemeBuilder.box(Palette.cargo(c).lightened(0.45), 2)


func _process(a: float) -> void:
	clock += a


func heading(v) -> Vector2:
	var k = min(v.progress * 2.5, 1.0)
	var d = v.dir_prev.linear_interpolate(v.dir, k)
	if d.length() < 0.05:
		return v.dir
	return d.normalized()


func _draw() -> void:
	if sim == null:
		return
	var a = Rect2(-11, -6, 22, 12)
	var b = Rect2(5, -5, 5, 10)
	for v in sim.vehicles:
		var d = heading(v)
		var p = v.pos + Vector2(-d.y, d.x) * C.LANE_OFFSET
		var e = C.CargoColor.URGENT if v.urgent else v.color
		draw_set_transform(p, d.angle(), Vector2(1, 1))
		if v.urgent:
			draw_line(Vector2(-20, -3), Vector2(-13, -3), Palette.URGENT_RING, 1.5)
			draw_line(Vector2(-23, 3), Vector2(-13, 3), Palette.URGENT_RING, 1.5)
		draw_style_box(body_style[e], a)
		draw_style_box(cab_style[e], b)
		if v.urgent:
			draw_rect(Rect2(-7, -5, 5, 10), Palette.cargo(v.color))
			DrawUtil.dashed_circle(self, Vector2(), 15.0, Palette.URGENT_RING, 1.5, 6, clock * 3.0)
	draw_set_transform(Vector2(), 0.0, Vector2(1, 1))
