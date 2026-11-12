extends Reference

# The star icon of a goal. The state is readable without color:
# pending = outlined star, done = gold filled star with a check mark, failed = gray star with an X.

const DrawUtil = preload("res://ui/draw_util.gd")

const PENDING = 0
const DONE = 1
const FAILED = 2


static func draw(ci: CanvasItem, center: Vector2, radius: float, state: int, bg: Color) -> void:
	if state == DONE:
		DrawUtil.star(ci, center, radius, Palette.NAVY)
		DrawUtil.star(ci, center, radius * 0.82, Palette.YELLOW)
		var w = max(radius * 0.2, 2.0)
		var pts = PoolVector2Array([center + Vector2(-0.34, 0.02) * radius, center + Vector2(-0.08, 0.3) * radius,
				center + Vector2(0.38, -0.26) * radius])
		ci.draw_polyline(pts, Palette.NAVY, w, true)
	elif state == FAILED:
		DrawUtil.star(ci, center, radius, Palette.TEXT_DIM)
		DrawUtil.star(ci, center, radius * 0.82, Palette.STAR_OFF)
		var w = max(radius * 0.2, 2.0)
		var d = radius * 0.28
		ci.draw_line(center + Vector2(-d, -d + 2), center + Vector2(d, d + 2), Palette.NAVY, w, true)
		ci.draw_line(center + Vector2(d, -d + 2), center + Vector2(-d, d + 2), Palette.NAVY, w, true)
	else:
		DrawUtil.star(ci, center, radius, Palette.TEXT_DIM)
		DrawUtil.star(ci, center, radius * 0.66, bg)


static func state_of(goal_status: int) -> int:
	# Goals.Status: PENDING 0, DONE 1, FAILED 2 map one to one.
	return goal_status
