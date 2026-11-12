extends Reference



static func centered(ci: CanvasItem, c: Font, f: Vector2, g: String, j: Color) -> void:
	var l = c.get_string_size(g)
	var m = Vector2(f.x - l.x / 2.0, f.y - c.get_height() / 2.0 + c.get_ascent())
	ci.draw_string(c, m.floor(), g, j)


static func left(ci: CanvasItem, c: Font, at: Vector2, f: String, g: Color) -> void:
	var j = Vector2(at.x, at.y - c.get_height() / 2.0 + c.get_ascent())
	ci.draw_string(c, j.floor(), f, g)


static func dashed_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0,
		dash: float = 6.0, gap: float = 5.0) -> void:
	var c = a.distance_to(b)
	if c < 0.5:
		return
	var f = (b - a) / c
	var d = 0.0
	while d < c:
		var e = min(d + dash, c)
		ci.draw_line(a + f * d, a + f * e, color, width)
		d += dash + gap


static func dashed_rect(ci: CanvasItem, r: Rect2, c: Color, f: float = 2.0) -> void:
	var p0 = r.position
	var p1 = Vector2(r.end.x, r.position.y)
	var p2 = r.end
	var p3 = Vector2(r.position.x, r.end.y)
	dashed_line(ci, p0, p1, c, f)
	dashed_line(ci, p1, p2, c, f)
	dashed_line(ci, p2, p3, c, f)
	dashed_line(ci, p3, p0, c, f)


static func dashed_circle(ci: CanvasItem, center: Vector2, radius: float, color: Color,
		width: float = 1.5, parts: int = 6, shift: float = 0.0) -> void:
	var c = TAU / parts
	for i in range(parts):
		var a = shift + i * c
		ci.draw_arc(center, radius, a, a + c * 0.55, 6, color, width)


static func hatch(ci: CanvasItem, r: Rect2, c: Color, f: float = 8.0, g: float = 1.5) -> void:
	var w = r.size.x
	var h = r.size.y
	var k = f
	while k < w + h:
		var a = Vector2(min(k, w), max(k - w, 0.0))
		var b = Vector2(max(k - h, 0.0), min(k, h))
		ci.draw_line(r.position + a, r.position + b, c, g)
		k += f


static func star(ci: CanvasItem, c: Vector2, f: float, g: Color) -> void:
	var j = PoolVector2Array()
	for i in range(10):
		var r = f if i % 2 == 0 else f * 0.45
		var a = -PI / 2.0 + i * PI / 5.0
		j.append(c + Vector2(cos(a), sin(a)) * r)
	for i in range(10):
		ci.draw_colored_polygon(PoolVector2Array([c, j[i], j[(i + 1) % 10]]), g)


static func arrow(ci: CanvasItem, c: Vector2, f: Vector2, g: float, j: Color) -> void:
	var d = f.normalized()
	var n = Vector2(-d.y, d.x)
	var l = c + d * g
	var m = c - d * g
	ci.draw_line(m, c + d * g * 0.2, j, max(g * 0.32, 2.0))
	ci.draw_colored_polygon(PoolVector2Array([l, c + n * g * 0.7, c - n * g * 0.7]), j)


static func triangle(ci: CanvasItem, c: Vector2, f: Vector2, g: float, j: Color) -> void:
	var d = f.normalized()
	var n = Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PoolVector2Array([c + d * g, c - d * g * 0.6 + n * g * 0.8,
			c - d * g * 0.6 - n * g * 0.8]), j)


static func wrap_lines(c: Font, f: String, g: float) -> int:
	var j = 1
	var l = 0.0
	var m = c.get_string_size(" ").x
	for o in f.split(" "):
		var w = c.get_string_size(o).x
		if l > 0.0 and l + m + w > g * 0.97:
			j += 1
			l = w
		else:
			l += (m if l > 0.0 else 0.0) + w
	return j
