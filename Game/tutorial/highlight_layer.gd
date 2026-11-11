extends Control

# Pulsing outlines around map cells and buttons, plus a bouncing arrow. Draws only:
# it never changes game state and never blocks the mouse.

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")

const SCREEN = Vector2(1280, 720)
const MAP_ORIGIN = Vector2(0, 56)

var manager
var clock = 0.0


func setup(manager_) -> void:
	manager = manager_
	rect_size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func targets() -> Array:
	# Screen rectangles of everything the current step points at.
	var out = []
	var h = manager.highlights()
	for cell in h["cells"]:
		out.append(Rect2(MAP_ORIGIN + cell * C.TILE, Vector2(C.TILE, C.TILE)))
	for key in h["ui"]:
		var r = UiRegistry.get_rect(key)
		if r.size.x > 0.0:
			out.append(r)
	return out


func _process(delta: float) -> void:
	clock += delta
	update()


func _draw() -> void:
	if manager == null or manager.done:
		return
	var pulse = 0.5 + 0.5 * sin(clock * 5.0)
	var list = targets()
	for r in list:
		var g = r.grow(2.0 + 4.0 * pulse)
		draw_rect(g.grow(1.5), Palette.alpha(Palette.NAVY, 0.7), false, 2.0 + 1.5 * pulse)
		draw_rect(g, Palette.YELLOW, false, 2.5 + 1.5 * pulse)
	if list.size() > 0:
		var r = list[0]
		var bounce = abs(sin(clock * 4.0)) * 8.0
		if r.position.y < 120.0:
			var at = Vector2(r.position.x + r.size.x / 2.0, r.end.y + 20.0 + bounce)
			DrawUtil.triangle(self, at, Vector2(0, -1), 11.0, Palette.NAVY)
			DrawUtil.triangle(self, at, Vector2(0, -1), 8.0, Palette.YELLOW)
		else:
			var at2 = Vector2(r.position.x + r.size.x / 2.0, r.position.y - 20.0 - bounce)
			DrawUtil.triangle(self, at2, Vector2(0, 1), 11.0, Palette.NAVY)
			DrawUtil.triangle(self, at2, Vector2(0, 1), 8.0, Palette.YELLOW)
