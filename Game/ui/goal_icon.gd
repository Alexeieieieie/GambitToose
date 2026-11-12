extends Reference


const DrawUtil = preload("res://ui/draw_util.gd")

const PENDING = 0
const DONE = 1
const FAILED = 2


static func draw(ci: CanvasItem, a: Vector2, b: float, c: int, bg: Color) -> void:
	if c == DONE:
		DrawUtil.star(ci, a, b, Palette.NAVY)
		DrawUtil.star(ci, a, b * 0.82, Palette.YELLOW)
		var w = max(b * 0.2, 2.0)
		var e = PoolVector2Array([a + Vector2(-0.34, 0.02) * b, a + Vector2(-0.08, 0.3) * b,
				a + Vector2(0.38, -0.26) * b])
		ci.draw_polyline(e, Palette.NAVY, w, true)
	elif c == FAILED:
		DrawUtil.star(ci, a, b, Palette.TEXT_DIM)
		DrawUtil.star(ci, a, b * 0.82, Palette.STAR_OFF)
		var w = max(b * 0.2, 2.0)
		var d = b * 0.28
		ci.draw_line(a + Vector2(-d, -d + 2), a + Vector2(d, d + 2), Palette.NAVY, w, true)
		ci.draw_line(a + Vector2(d, -d + 2), a + Vector2(-d, d + 2), Palette.NAVY, w, true)
	else:
		DrawUtil.star(ci, a, b, Palette.TEXT_DIM)
		DrawUtil.star(ci, a, b * 0.66, bg)


static func state_of(a: int) -> int:
	return a
