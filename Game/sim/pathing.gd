extends Reference


const C = preload("res://sim/constants.gd")

const CLASSES = [C.CargoColor.BLUE, C.CargoColor.RED, C.CargoColor.URGENT]

var astar = {}


func pid(b: Vector2) -> int:
	return int(b.y) * C.MAP_W + int(b.x)


func rebuild(b) -> void:
	b.refresh_cells()
	for c in CLASSES:
		var a = AStar2D.new()
		for e in b.road_cells:
			a.add_point(pid(e), e)
		for e in b.road_cells:
			for n in exits(b, e, c):
				a.connect_points(pid(e), pid(n), false)
		astar[c] = a
	b.graph_dirty = false


func exits(b, e: Vector2, f: int) -> Array:
	var g = []
	var t = b.tile(e)
	if t == C.Tile.WAREHOUSE:
		return g
	for d in C.DIRS:
		var n = e + d
		if not b.is_passable(n):
			continue
		if b.tile(n) == C.Tile.FACTORY:
			continue
		g.append(n)
	var h = b.controllers.get(e)
	if h != null and h.is_sorter:
		var i = h.rules.get(f, Vector2())
		if i != Vector2() and g.has(e + i):
			return [e + i]
	return g


func valid_dirs(b, e: Vector2) -> Array:
	var f = []
	for d in C.DIRS:
		var n = e + d
		if b.is_passable(n) and b.tile(n) != C.Tile.FACTORY:
			f.append(d)
	return f


func find_path(b: int, e: Vector2, f: int, g: Array) -> Array:
	var a = astar.get(b)
	if a == null or not a.has_point(pid(e)):
		return []
	var h = []
	for w in g:
		if w.color != f:
			continue
		if w.cell == e:
			return [e]
		if not a.has_point(pid(w.cell)):
			continue
		var p = a.get_point_path(pid(e), pid(w.cell))
		if p.size() > 0 and (h.empty() or p.size() < h.size()):
			h = Array(p)
	return h


func update_weights(b, e: Dictionary) -> void:
	for f in b.road_cells:
		var w = 1.0 + 3.0 * e.get(f, 0.0)
		var id = pid(f)
		for c in CLASSES:
			var a = astar.get(c)
			if a != null and a.has_point(id):
				a.set_point_weight_scale(id, w)
