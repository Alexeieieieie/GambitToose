extends Reference

# Small drawing helpers shared by the view and UI scripts.
# `ci` is the CanvasItem that is currently inside its _draw() call.


static func centered(ci: CanvasItem, font: Font, center: Vector2, msg: String, color: Color) -> void:
	var size = font.get_string_size(msg)
	var base = Vector2(center.x - size.x / 2.0, center.y - font.get_height() / 2.0 + font.get_ascent())
	ci.draw_string(font, base.floor(), msg, color)


static func left(ci: CanvasItem, font: Font, at: Vector2, msg: String, color: Color) -> void:
	# `at.y` is the vertical center of the line.
	var base = Vector2(at.x, at.y - font.get_height() / 2.0 + font.get_ascent())
	ci.draw_string(font, base.floor(), msg, color)


static func dashed_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0,
		dash: float = 6.0, gap: float = 5.0) -> void:
	var total = a.distance_to(b)
	if total < 0.5:
		return
	var dir = (b - a) / total
	var d = 0.0
	while d < total:
		var e = min(d + dash, total)
		ci.draw_line(a + dir * d, a + dir * e, color, width)
		d += dash + gap


static func dashed_rect(ci: CanvasItem, r: Rect2, color: Color, width: float = 2.0) -> void:
	var p0 = r.position
	var p1 = Vector2(r.end.x, r.position.y)
	var p2 = r.end
	var p3 = Vector2(r.position.x, r.end.y)
	dashed_line(ci, p0, p1, color, width)
	dashed_line(ci, p1, p2, color, width)
	dashed_line(ci, p2, p3, color, width)
	dashed_line(ci, p3, p0, color, width)


static func dashed_circle(ci: CanvasItem, center: Vector2, radius: float, color: Color,
		width: float = 1.5, parts: int = 6, shift: float = 0.0) -> void:
	var step = TAU / parts
	for i in range(parts):
		var a = shift + i * step
		ci.draw_arc(center, radius, a, a + step * 0.55, 6, color, width)


static func hatch(ci: CanvasItem, r: Rect2, color: Color, spacing: float = 8.0, width: float = 1.5) -> void:
	# Diagonal lines clipped to the rectangle.
	var w = r.size.x
	var h = r.size.y
	var k = spacing
	while k < w + h:
		var a = Vector2(min(k, w), max(k - w, 0.0))
		var b = Vector2(max(k - h, 0.0), min(k, h))
		ci.draw_line(r.position + a, r.position + b, color, width)
		k += spacing


static func star(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var pts = PoolVector2Array()
	for i in range(10):
		var r = radius if i % 2 == 0 else radius * 0.45
		var a = -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	# A star is concave, so draw it as triangles around the center.
	for i in range(10):
		ci.draw_colored_polygon(PoolVector2Array([center, pts[i], pts[(i + 1) % 10]]), color)


static func arrow(ci: CanvasItem, center: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var d = dir.normalized()
	var n = Vector2(-d.y, d.x)
	var tip = center + d * size
	var tail = center - d * size
	ci.draw_line(tail, center + d * size * 0.2, color, max(size * 0.32, 2.0))
	ci.draw_colored_polygon(PoolVector2Array([tip, center + n * size * 0.7, center - n * size * 0.7]), color)


static func triangle(ci: CanvasItem, center: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var d = dir.normalized()
	var n = Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PoolVector2Array([center + d * size, center - d * size * 0.6 + n * size * 0.8,
			center - d * size * 0.6 - n * size * 0.8]), color)


static func wrap_lines(font: Font, text: String, width: float) -> int:
	# How many lines a Label with autowrap will use (greedy word wrap).
	var lines = 1
	var cur = 0.0
	var space = font.get_string_size(" ").x
	for word in text.split(" "):
		var w = font.get_string_size(word).x
		if cur > 0.0 and cur + space + w > width * 0.97:
			lines += 1
			cur = w
		else:
			cur += (space if cur > 0.0 else 0.0) + w
	return lines
