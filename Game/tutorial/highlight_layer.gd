extends Control


const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")

const SCREEN = Vector2(1280, 720)
const MAP_ORIGIN = Vector2(0, 56)

var manager
var clock = 0.0


func setup(a) -> void:
	manager = a
	rect_size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func targets() -> Array:
	var a = []
	var h = manager.highlights()
	for b in h["cells"]:
		a.append(Rect2(MAP_ORIGIN + b * C.TILE, Vector2(C.TILE, C.TILE)))
	for c in h["ui"]:
		var r = UiRegistry.get_rect(c)
		if r.size.x > 0.0:
			a.append(r)
	return a


func _process(a: float) -> void:
	clock += a
	update()


func _draw() -> void:
	if manager == null or manager.done:
		return
	var a = 0.5 + 0.5 * sin(clock * 5.0)
	var b = targets()
	for r in b:
		var g = r.grow(2.0 + 4.0 * a)
		draw_rect(g.grow(1.5), Palette.alpha(Palette.NAVY, 0.7), false, 2.0 + 1.5 * a)
		draw_rect(g, Palette.YELLOW, false, 2.5 + 1.5 * a)
	if b.size() > 0:
		var r = b[0]
		var c = abs(sin(clock * 4.0)) * 8.0
		if r.position.y < 120.0:
			var at = Vector2(r.position.x + r.size.x / 2.0, r.end.y + 20.0 + c)
			DrawUtil.triangle(self, at, Vector2(0, -1), 11.0, Palette.NAVY)
			DrawUtil.triangle(self, at, Vector2(0, -1), 8.0, Palette.YELLOW)
		else:
			var d = Vector2(r.position.x + r.size.x / 2.0, r.position.y - 20.0 - c)
			DrawUtil.triangle(self, d, Vector2(0, 1), 11.0, Palette.NAVY)
			DrawUtil.triangle(self, d, Vector2(0, 1), 8.0, Palette.YELLOW)
