extends Reference

# One AStar2D graph per cargo class. Sorters are expressed as missing edges.

const C = preload("res://sim/constants.gd")

const CLASSES = [C.CargoColor.BLUE, C.CargoColor.RED, C.CargoColor.URGENT]

var astar = {}                   # cargo class -> AStar2D


func pid(cell: Vector2) -> int:
	return int(cell.y) * C.MAP_W + int(cell.x)


func rebuild(grid) -> void:
	grid.refresh_cells()
	for c in CLASSES:
		var a = AStar2D.new()
		for cell in grid.road_cells:
			a.add_point(pid(cell), cell)
		for cell in grid.road_cells:
			for n in exits(grid, cell, c):
				a.connect_points(pid(cell), pid(n), false)
		astar[c] = a
	grid.graph_dirty = false


func exits(grid, cell: Vector2, cls: int) -> Array:
	var out = []
	var t = grid.tile(cell)
	if t == C.Tile.WAREHOUSE:
		return out               # a warehouse is an end point only
	for d in C.DIRS:
		var n = cell + d
		if not grid.is_passable(n):
			continue
		if grid.tile(n) == C.Tile.FACTORY:
			continue             # nothing drives into a factory
		out.append(n)
	var ctrl = grid.controllers.get(cell)
	if ctrl != null and ctrl.is_sorter:
		var rule = ctrl.rules.get(cls, Vector2())
		if rule != Vector2() and out.has(cell + rule):
			return [cell + rule]
	return out


func valid_dirs(grid, cell: Vector2) -> Array:
	# Directions a sorter on this cell may point to.
	var out = []
	for d in C.DIRS:
		var n = cell + d
		if grid.is_passable(n) and grid.tile(n) != C.Tile.FACTORY:
			out.append(d)
	return out


func find_path(cls: int, start: Vector2, color: int, warehouses: Array) -> Array:
	# Path to the nearest warehouse of the cargo color, by path length.
	var a = astar.get(cls)
	if a == null or not a.has_point(pid(start)):
		return []
	var best = []
	for w in warehouses:
		if w.color != color:
			continue
		if w.cell == start:
			return [start]
		if not a.has_point(pid(w.cell)):
			continue
		var p = a.get_point_path(pid(start), pid(w.cell))
		if p.size() > 0 and (best.empty() or p.size() < best.size()):
			best = Array(p)
	return best


func update_weights(grid, density: Dictionary) -> void:
	for cell in grid.road_cells:
		var w = 1.0 + 3.0 * density.get(cell, 0.0)
		var id = pid(cell)
		for c in CLASSES:
			var a = astar.get(c)
			if a != null and a.has_point(id):
				a.set_point_weight_scale(id, w)
