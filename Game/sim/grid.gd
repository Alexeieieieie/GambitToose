extends Reference

# The tile map, tile reservations, and the rule for entering a tile.

const C = preload("res://sim/constants.gd")

var tiles = {}          # Vector2 -> Tile enum value
var occupants = {}      # Vector2 -> Array of vehicles reserving this tile
var controllers = {}    # Vector2 -> light or sorter object
var road_cells = []     # every passable cell, in row order
var junctions = {}      # Vector2 -> true
var player_built = {}   # Vector2 -> true for tiles the player placed
var reserved = {}       # Vector2 -> true for future building sites
var graph_dirty = true

# Conflict tracking for the tutorial crash event.
var track_conflicts = false
var now = 0.0
var conflict_times = {} # Vector2 -> [time axis 0, time axis 1]
var conflicts = []      # cells where two axes met within one second


func setup() -> void:
	for y in range(C.MAP_H):
		for x in range(C.MAP_W):
			var cell = Vector2(x, y)
			tiles[cell] = C.Tile.EMPTY
			occupants[cell] = []
	refresh_cells()


func in_bounds(cell: Vector2) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < C.MAP_W and cell.y < C.MAP_H


func tile(cell: Vector2) -> int:
	return tiles.get(cell, C.Tile.OBSTACLE)


func is_roadlike(cell: Vector2) -> bool:
	var t = tiles.get(cell, C.Tile.OBSTACLE)
	return t == C.Tile.ROAD or t == C.Tile.BRIDGE


func is_building(cell: Vector2) -> bool:
	var t = tiles.get(cell, C.Tile.OBSTACLE)
	return t == C.Tile.FACTORY or t == C.Tile.WAREHOUSE


func is_passable(cell: Vector2) -> bool:
	var t = tiles.get(cell, C.Tile.OBSTACLE)
	return t == C.Tile.ROAD or t == C.Tile.BRIDGE or t == C.Tile.FACTORY or t == C.Tile.WAREHOUSE


func road_neighbor_count(cell: Vector2) -> int:
	var n = 0
	for d in C.DIRS:
		if is_roadlike(cell + d):
			n += 1
	return n


func is_junction(cell: Vector2) -> bool:
	return junctions.has(cell)


func capacity(cell: Vector2) -> int:
	return C.JUNCTION_CAPACITY if junctions.has(cell) else C.ROAD_CAPACITY


func center(cell: Vector2) -> Vector2:
	return Vector2((cell.x + 0.5) * C.TILE, (cell.y + 0.5) * C.TILE)


func label(cell: Vector2) -> String:
	# Column letter(s) and row number, for example B3.
	var x = int(cell.x)
	var s = ""
	if x >= 26:
		s += char(65 + int(x / 26) - 1)
	s += char(65 + x % 26)
	return s + str(int(cell.y) + 1)


func refresh_cells() -> void:
	road_cells = []
	junctions = {}
	for y in range(C.MAP_H):
		for x in range(C.MAP_W):
			var cell = Vector2(x, y)
			if is_passable(cell):
				road_cells.append(cell)
				if is_roadlike(cell) and road_neighbor_count(cell) >= 3:
					junctions[cell] = true


func mark_dirty() -> void:
	refresh_cells()
	graph_dirty = true


func try_enter(v, from: Vector2, to: Vector2) -> bool:
	if not is_passable(to):
		return false
	var ctrl = controllers.get(to)
	if track_conflicts and ctrl == null and junctions.has(to):
		_note_conflict(from, to)
	var occ = occupants[to]
	if occ.size() >= capacity(to):
		return false
	for o in occ:
		# One vehicle per lane: a lane is identified by the tile it is entered from.
		var ofrom = o.from_cell if o.cell == to else o.cell
		if ofrom == from:
			return false
	if ctrl != null and not ctrl.allows(v, from):
		return false
	occ.append(v)                # reservation is immediate
	return true


func leave(cell: Vector2, v) -> void:
	occupants[cell].erase(v)


func _note_conflict(from: Vector2, to: Vector2) -> void:
	var axis = 0 if from.y == to.y else 1
	if not conflict_times.has(to):
		conflict_times[to] = [-100.0, -100.0]
	var times = conflict_times[to]
	times[axis] = now
	if abs(times[0] - times[1]) <= 1.0 and not conflicts.has(to):
		conflicts.append(to)
