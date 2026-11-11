extends Node2D

# Draws the static world: grass, water, rocks, trees, roads, bridges.
# Redrawn only when the network changes (call update()).

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")

const ROAD_W = 26.0
const DECK_W = 34.0

var sim
var trees = []                   # [cell, offset, radius]
var waves = {}                   # water cell -> offset


func setup(sim_) -> void:
	sim = sim_
	var rng = RandomNumberGenerator.new()
	rng.seed = int(sim.level.get("seed", 1)) + 99
	trees = []
	for _i in range(70):
		var cell = Vector2(rng.randi_range(0, C.MAP_W - 1), rng.randi_range(0, C.MAP_H - 1))
		var off = Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 8))
		trees.append([cell, off, rng.randf_range(8.0, 12.0)])
	waves = {}
	for y in range(C.MAP_H):
		for x in range(C.MAP_W):
			waves[Vector2(x, y)] = Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
	update()


func _draw() -> void:
	if sim == null:
		return
	var g = sim.grid
	var size = Vector2(C.MAP_W, C.MAP_H) * C.TILE
	draw_rect(Rect2(Vector2(), size), Palette.GRASS)
	for x in range(1, C.MAP_W):
		draw_line(Vector2(x * C.TILE, 0), Vector2(x * C.TILE, size.y), Palette.GRID_LINE, 1.0)
	for y in range(1, C.MAP_H):
		draw_line(Vector2(0, y * C.TILE), Vector2(size.x, y * C.TILE), Palette.GRID_LINE, 1.0)
	_draw_water(g)
	for item in trees:
		var cell = item[0]
		if g.tile(cell) == C.Tile.EMPTY and not g.reserved.has(cell):
			_draw_tree(g.center(cell) + item[1], item[2])
	for y in range(C.MAP_H):
		for x in range(C.MAP_W):
			var cell = Vector2(x, y)
			if g.tile(cell) == C.Tile.OBSTACLE:
				_draw_rock(g.center(cell))
			if g.reserved.has(cell):
				var r = Rect2(cell * C.TILE + Vector2(4, 4), Vector2(C.TILE - 8, C.TILE - 8))
				draw_rect(r, Palette.alpha(Palette.NAVY, 0.12))
				DrawUtil.dashed_rect(self, r, Palette.alpha(Palette.NAVY, 0.55), 2.0)
	_draw_roads(g)


func _draw_water(g) -> void:
	for y in range(C.MAP_H):
		for x in range(C.MAP_W):
			var cell = Vector2(x, y)
			var t = g.tile(cell)
			if t != C.Tile.WATER and t != C.Tile.BRIDGE:
				continue
			draw_rect(Rect2(cell * C.TILE, Vector2(C.TILE, C.TILE)), Palette.WATER)
			var c = g.center(cell) + waves[cell]
			draw_arc(c, 7.0, PI * 1.15, PI * 1.85, 6, Palette.WAVE, 2.0)
			draw_arc(c + Vector2(9, 7), 5.0, PI * 1.15, PI * 1.85, 5, Palette.WAVE, 1.5)


func _draw_tree(p: Vector2, r: float) -> void:
	draw_circle(p + Vector2(2, 3), r, Palette.alpha(Palette.TREE_DARK, 0.35))
	draw_circle(p, r, Palette.TREE)
	draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.55, Palette.TREE.lightened(0.15))


func _draw_rock(p: Vector2) -> void:
	draw_circle(p + Vector2(2, 4), 14.0, Palette.alpha(Palette.NAVY, 0.2))
	draw_colored_polygon(PoolVector2Array([p + Vector2(-15, 8), p + Vector2(-10, -9), p + Vector2(2, -14),
			p + Vector2(14, -4), p + Vector2(13, 10), p + Vector2(-4, 13)]), Palette.ROCK_DARK)
	draw_colored_polygon(PoolVector2Array([p + Vector2(-9, 3), p + Vector2(-6, -7), p + Vector2(2, -10),
			p + Vector2(9, -3), p + Vector2(4, 4)]), Palette.ROCK)


func _arm(center: Vector2, d: Vector2, width: float) -> Rect2:
	# Rectangle from the tile center to the tile edge in direction d.
	var half = C.TILE / 2.0
	if d.x != 0:
		var x0 = center.x if d.x > 0 else center.x - half
		return Rect2(x0, center.y - width / 2.0, half, width)
	var y0 = center.y if d.y > 0 else center.y - half
	return Rect2(center.x - width / 2.0, y0, width, half)


func _draw_roads(g) -> void:
	var cells = []
	for cell in g.road_cells:
		if g.is_roadlike(cell):
			cells.append(cell)
	# Bridge decks first, then asphalt, then lane markings.
	for cell in cells:
		if g.tile(cell) != C.Tile.BRIDGE:
			continue
		var c = g.center(cell)
		var vertical = g.is_passable(cell + Vector2(0, 1)) or g.is_passable(cell + Vector2(0, -1))
		var deck = Rect2(c.x - DECK_W / 2.0, c.y - C.TILE / 2.0 - 3, DECK_W, C.TILE + 6)
		if not vertical:
			deck = Rect2(c.x - C.TILE / 2.0 - 3, c.y - DECK_W / 2.0, C.TILE + 6, DECK_W)
		draw_rect(deck, Palette.BRIDGE_DECK)
		if vertical:
			draw_line(deck.position, Vector2(deck.position.x, deck.end.y), Palette.BRIDGE_RAIL, 3.0)
			draw_line(Vector2(deck.end.x, deck.position.y), deck.end, Palette.BRIDGE_RAIL, 3.0)
		else:
			draw_line(deck.position, Vector2(deck.end.x, deck.position.y), Palette.BRIDGE_RAIL, 3.0)
			draw_line(Vector2(deck.position.x, deck.end.y), deck.end, Palette.BRIDGE_RAIL, 3.0)
	for cell in cells:
		var c = g.center(cell)
		draw_rect(Rect2(c - Vector2(ROAD_W, ROAD_W) / 2.0, Vector2(ROAD_W, ROAD_W)), Palette.ASPHALT)
		draw_circle(c, ROAD_W / 2.0, Palette.ASPHALT)
		for d in C.DIRS:
			if g.is_passable(cell + d):
				draw_rect(_arm(c, d, ROAD_W), Palette.ASPHALT)
	for cell in cells:
		if g.is_junction(cell):
			continue
		var c = g.center(cell)
		for d in C.DIRS:
			if g.is_passable(cell + d):
				DrawUtil.dashed_line(self, c + d * 3.0, c + d * (C.TILE / 2.0), Palette.LANE_DASH, 2.0, 5.0, 5.0)
