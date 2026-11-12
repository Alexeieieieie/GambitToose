extends Reference


const C = preload("res://sim/constants.gd")

var tiles = {}
var occupants = {}
var controllers = {}
var road_cells = []
var junctions = {}
var player_built = {}
var reserved = {}
var graph_dirty = true

var track_conflicts = false
var hold_for_crash = false
var now = 0.0
var conflict_times = {}
var conflicts = []


func setup() -> void:
	for y in range(C.MAP_H):
		for x in range(C.MAP_W):
			var a = Vector2(x, y)
			tiles[a] = C.Tile.EMPTY
			occupants[a] = []
	refresh_cells()


func in_bounds(a: Vector2) -> bool:
	return a.x >= 0 and a.y >= 0 and a.x < C.MAP_W and a.y < C.MAP_H


func tile(a: Vector2) -> int:
	return tiles.get(a, C.Tile.OBSTACLE)


func is_roadlike(a: Vector2) -> bool:
	var t = tiles.get(a, C.Tile.OBSTACLE)
	return t == C.Tile.ROAD or t == C.Tile.BRIDGE


func is_building(a: Vector2) -> bool:
	var t = tiles.get(a, C.Tile.OBSTACLE)
	return t == C.Tile.FACTORY or t == C.Tile.WAREHOUSE


func is_passable(a: Vector2) -> bool:
	var t = tiles.get(a, C.Tile.OBSTACLE)
	return t == C.Tile.ROAD or t == C.Tile.BRIDGE or t == C.Tile.FACTORY or t == C.Tile.WAREHOUSE


func road_neighbor_count(a: Vector2) -> int:
	var n = 0
	for d in C.DIRS:
		if is_roadlike(a + d):
			n += 1
	return n


func is_junction(a: Vector2) -> bool:
	return junctions.has(a)


func capacity(a: Vector2) -> int:
	return C.JUNCTION_CAPACITY if junctions.has(a) else C.ROAD_CAPACITY


func center(a: Vector2) -> Vector2:
	return Vector2((a.x + 0.5) * C.TILE, (a.y + 0.5) * C.TILE)


func label(a: Vector2) -> String:
	var x = int(a.x)
	var s = ""
	if x >= 26:
		s += char(65 + int(x / 26) - 1)
	s += char(65 + x % 26)
	return s + str(int(a.y) + 1)


func refresh_cells() -> void:
	road_cells = []
	junctions = {}
	for y in range(C.MAP_H):
		for x in range(C.MAP_W):
			var a = Vector2(x, y)
			if is_passable(a):
				road_cells.append(a)
				if is_roadlike(a) and road_neighbor_count(a) >= 3:
					junctions[a] = true


func mark_dirty() -> void:
	refresh_cells()
	graph_dirty = true


func try_enter(v, a: Vector2, to: Vector2) -> bool:
	if not is_passable(to):
		return false
	var b = controllers.get(to)
	if track_conflicts and b == null and junctions.has(to):
		_note_conflict(a, to)
		if hold_for_crash and conflicts.empty() and v.wait_time < C.CRASH_HOLD_MAX:
			var c = 1 - (0 if a.y == to.y else 1)
			if now - conflict_times[to][c] > 0.2:
				return false
	var e = occupants[to]
	if e.size() >= capacity(to):
		return false
	for o in e:
		var f = o.from_cell if o.cell == to else o.cell
		if f == a:
			return false
	if b != null and not b.allows(v, a):
		return false
	e.append(v)
	return true


func leave(a: Vector2, v) -> void:
	occupants[a].erase(v)


func _note_conflict(a: Vector2, to: Vector2) -> void:
	var b = 0 if a.y == to.y else 1
	if not conflict_times.has(to):
		conflict_times[to] = [-100.0, -100.0]
	var c = conflict_times[to]
	c[b] = now
	if abs(c[0] - c[1]) <= 1.0 and not conflicts.has(to):
		conflicts.append(to)
