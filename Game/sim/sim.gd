extends Reference

# The whole simulation. Runs without a scene tree: call step(dt) at a fixed rate.
# Things that happened are pushed onto `events` as dictionaries; the view drains them.

const C = preload("res://sim/constants.gd")
const Grid = preload("res://sim/grid.gd")
const Vehicle = preload("res://sim/vehicle.gd")
const Intersection = preload("res://sim/intersection.gd")
const Sorter = preload("res://sim/sorter.gd")
const Factory = preload("res://sim/factory.gd")
const Warehouse = preload("res://sim/warehouse.gd")
const Metrics = preload("res://sim/metrics.gd")
const Pathing = preload("res://sim/pathing.gd")

var level = {}
var grid
var pathing
var metrics
var rng = RandomNumberGenerator.new()

var vehicles = []
var factories = []
var warehouses = []
var lights = []
var sorters = []
var inventory = {"road": 0, "light": 0, "sorter": 0, "bridge": 0}
var pending_events = []          # spawn events not yet triggered
var events = []                  # drained by the view every frame

var time = 0.0
var time_limit = 0.0
var goal = 0
var mode = "goal"
var finished = false
var result = ""                  # "win", "lose", "finished"
var lose_reason = ""             # "patience", "gridlock", "time"
var lose_cell = null

var density = {}                 # Vector2 -> smoothed occupancy 0..1
var still_time = 0.0             # seconds without any vehicle moving
var jam_active = false
var crash_done = false
var weight_timer = 0.0
var deadlock_timer = 0.0
var deadlock_cooldown = 0.0
var last_deadlock = []


func load_level(lv: Dictionary) -> void:
	level = lv
	grid = Grid.new()
	grid.setup()
	pathing = Pathing.new()
	metrics = Metrics.new()
	rng.seed = lv.get("seed", 1)
	time_limit = float(lv.get("time", 240))
	goal = int(lv.get("goal", 0))
	mode = lv.get("mode", "goal")
	grid.track_conflicts = lv.get("tutorial", false)
	var inv = lv.get("inventory", {})
	for key in ["road", "light", "sorter", "bridge"]:
		inventory[key] = int(inv.get(key, 0))
	for cell in lv.get("water", []):
		grid.tiles[cell] = C.Tile.WATER
	for cell in lv.get("obstacles", []):
		grid.tiles[cell] = C.Tile.OBSTACLE
	for cell in lv.get("roads", []):
		grid.tiles[cell] = C.Tile.ROAD      # pre-built, not erasable
	for f in lv.get("factories", []):
		_add_factory(f)
	for w in lv.get("warehouses", []):
		_add_warehouse(w)
	pending_events = lv.get("spawn_events", []).duplicate()
	for ev in pending_events:
		for f in ev.get("factories", []):
			grid.reserved[f["cell"]] = true
		for w in ev.get("warehouses", []):
			grid.reserved[w["cell"]] = true
	grid.mark_dirty()
	pathing.rebuild(grid)


func _add_factory(d: Dictionary) -> void:
	var f = Factory.new()
	f.cell = d["cell"]
	f.color = d["color"]
	f.interval = float(d.get("interval", 4.0))
	f.start_at = float(d.get("start_at", 0.0))
	f.urgent_every = int(d.get("urgent_every", 0))
	factories.append(f)
	grid.tiles[f.cell] = C.Tile.FACTORY
	grid.reserved.erase(f.cell)


func _add_warehouse(d: Dictionary) -> void:
	var w = Warehouse.new()
	w.cell = d["cell"]
	w.color = d["color"]
	warehouses.append(w)
	grid.tiles[w.cell] = C.Tile.WAREHOUSE
	grid.reserved.erase(w.cell)


# ---------------------------------------------------------------- build commands
# These are the only things the player can do. None of them touches a vehicle,
# except erase(), which removes vehicles standing on a road that disappears.

func can_build_road(cell: Vector2) -> bool:
	return grid.in_bounds(cell) and grid.tile(cell) == C.Tile.EMPTY \
			and not grid.reserved.has(cell) and inventory["road"] > 0


func build_road(cell: Vector2) -> bool:
	if not can_build_road(cell):
		return false
	grid.tiles[cell] = C.Tile.ROAD
	grid.player_built[cell] = true
	inventory["road"] -= 1
	grid.mark_dirty()
	return true


func can_build_bridge(cell: Vector2) -> bool:
	return grid.in_bounds(cell) and grid.tile(cell) == C.Tile.WATER and inventory["bridge"] > 0


func build_bridge(cell: Vector2) -> bool:
	if not can_build_bridge(cell):
		return false
	grid.tiles[cell] = C.Tile.BRIDGE
	grid.player_built[cell] = true
	inventory["bridge"] -= 1
	grid.mark_dirty()
	return true


func can_place_controller(cell: Vector2, kind: String) -> bool:
	return grid.is_junction(cell) and not grid.controllers.has(cell) and inventory[kind] > 0


func place_light(cell: Vector2):
	if not can_place_controller(cell, "light"):
		return null
	var l = Intersection.new()
	l.cell = cell
	grid.controllers[cell] = l
	lights.append(l)
	inventory["light"] -= 1
	grid.mark_dirty()
	return l


func place_sorter(cell: Vector2):
	if not can_place_controller(cell, "sorter"):
		return null
	var s = Sorter.new()
	s.cell = cell
	grid.controllers[cell] = s
	sorters.append(s)
	inventory["sorter"] -= 1
	grid.mark_dirty()
	return s


func configure_light(cell: Vector2, mode_: int, period: float, threshold: int, urgent_first: bool) -> bool:
	var l = grid.controllers.get(cell)
	if l == null or l.is_sorter:
		return false
	l.mode = mode_
	l.period = period
	l.threshold = threshold
	l.urgent_first = urgent_first
	return true


func configure_sorter(cell: Vector2, rules: Dictionary) -> bool:
	var s = grid.controllers.get(cell)
	if s == null or not s.is_sorter:
		return false
	for key in rules.keys():
		s.rules[key] = rules[key]
	grid.mark_dirty()
	return true


func can_erase(cell: Vector2) -> bool:
	return grid.controllers.has(cell) or grid.player_built.has(cell)


func erase(cell: Vector2) -> String:
	# Returns what was removed: "light", "sorter", "road", "bridge" or "".
	var ctrl = grid.controllers.get(cell)
	if ctrl != null:
		grid.controllers.erase(cell)
		var kind = "sorter" if ctrl.is_sorter else "light"
		if ctrl.is_sorter:
			sorters.erase(ctrl)
		else:
			lights.erase(ctrl)
		inventory[kind] += 1
		grid.mark_dirty()
		return kind
	if not grid.player_built.has(cell):
		return ""
	var was_bridge = grid.tile(cell) == C.Tile.BRIDGE
	for v in grid.occupants[cell].duplicate():
		_drop_vehicle(v)         # the road under it disappeared
	grid.tiles[cell] = C.Tile.WATER if was_bridge else C.Tile.EMPTY
	grid.player_built.erase(cell)
	var what = "bridge" if was_bridge else "road"
	inventory[what] += 1
	grid.mark_dirty()
	return what


func apply_action(a: Dictionary) -> bool:
	# Build actions used by level solutions and tests.
	var kind = a["type"]
	if kind == "road_line":
		var from = a["from"]
		var to = a["to"]
		var d = Vector2(sign(to.x - from.x), sign(to.y - from.y))
		var cell = from
		var ok = true
		while true:
			if grid.tile(cell) == C.Tile.EMPTY:
				ok = build_road(cell) and ok
			if cell == to:
				break
			cell += d
		return ok
	if kind == "road":
		return build_road(a["cell"])
	if kind == "bridge":
		return build_bridge(a["cell"])
	if kind == "light":
		if place_light(a["cell"]) == null:
			return false
		return configure_light(a["cell"], a.get("mode", C.LightMode.SENSOR),
				a.get("period", C.DEFAULT_PERIOD), a.get("threshold", C.DEFAULT_THRESHOLD),
				a.get("urgent_first", false))
	if kind == "sorter":
		if place_sorter(a["cell"]) == null:
			return false
		return configure_sorter(a["cell"], a.get("rules", {}))
	if kind == "erase":
		return erase(a["cell"]) != ""
	return false


func apply_solution() -> bool:
	var ok = true
	for a in level.get("solution", []):
		ok = apply_action(a) and ok
	return ok


# ---------------------------------------------------------------- queries

func is_warehouse_for(cell: Vector2, color: int) -> bool:
	if grid.tile(cell) != C.Tile.WAREHOUSE:
		return false
	for w in warehouses:
		if w.cell == cell:
			return w.color == color
	return false


func color_active(color: int) -> bool:
	for f in factories:
		if f.color == color and time >= f.start_at:
			return true
	return false


func has_route(f) -> bool:
	if grid.graph_dirty:
		pathing.rebuild(grid)
	return pathing.find_path(f.color, f.cell, f.color, warehouses).size() >= 2


func time_left() -> float:
	return max(time_limit - time, 0.0)


# ---------------------------------------------------------------- vehicles

func spawn_vehicle(f, path: Array, urgent: bool) -> void:
	var v = Vehicle.new()
	v.color = f.color
	v.urgent = urgent
	v.speed = C.SPEED_URGENT if urgent else C.SPEED_NORMAL
	v.path = path
	v.cell = path[0]
	v.pos = grid.center(v.cell)
	v.dir = path[1] - path[0]
	v.dir_prev = v.dir
	v.spawn_time = time
	v.repath_timer = C.REPATH_URGENT_INTERVAL
	grid.occupants[v.cell].append(v)
	vehicles.append(v)


func deliver(v) -> void:
	v.done = true
	metrics.deliveries += 1
	metrics.total_delivery_time += time - v.spawn_time
	for w in warehouses:
		if w.cell == v.cell:
			w.deliver()
	events.append({"type": "deliver", "cell": v.cell, "color": v.color, "jam": jam_active})


func _drop_vehicle(v) -> void:
	grid.occupants[v.cell].erase(v)
	if v.reserved:
		var n = v.next_cell()
		if grid.occupants.has(n):
			grid.occupants[n].erase(v)
	v.done = true
	vehicles.erase(v)


func _repath(v) -> bool:
	var start = v.next_cell() if v.reserved else v.cell
	var p = pathing.find_path(v.route_class(), start, v.color, warehouses)
	if p.empty():
		return false
	if v.reserved:
		p.push_front(v.cell)
	v.path = p
	v.idx = 0
	if v.state == Vehicle.S.WAITING or v.state == Vehicle.S.STRANDED:
		v.state = Vehicle.S.DRIVING
	return true


func _path_broken(v) -> bool:
	for i in range(v.idx, v.path.size()):
		if not grid.is_passable(v.path[i]):
			return true
	return false


func _revalidate_paths() -> void:
	for v in vehicles:
		if v.state == Vehicle.S.UNLOADING:
			continue
		if v.state == Vehicle.S.STRANDED or _path_broken(v):
			if not _repath(v):
				# No way out: stop at the end of the tile it is committed to.
				var keep = [v.cell]
				if v.reserved:
					keep.append(v.next_cell())
				v.path = keep
				v.idx = 0


# ---------------------------------------------------------------- the step

func step(dt: float) -> void:
	if finished:
		return
	if grid.graph_dirty:
		pathing.rebuild(grid)
		pathing.update_weights(grid, density)
		_revalidate_paths()
	time += dt
	grid.now = time
	_run_spawn_events()
	for f in factories:
		f.tick(dt, self)
	_update_sensors()
	for l in lights:
		var before = l.green_axis
		l.tick(dt)
		if l.green_axis != before:
			events.append({"type": "light_switch", "cell": l.cell})
	_tick_vehicles(dt)
	_tick_warehouses(dt)
	_tick_jams(dt)
	_tick_gridlock(dt)
	weight_timer += dt
	if weight_timer >= C.WEIGHT_REFRESH_INTERVAL:
		weight_timer = 0.0
		_refresh_density()
		pathing.update_weights(grid, density)
	deadlock_timer += dt
	deadlock_cooldown = max(deadlock_cooldown - dt, 0.0)
	if deadlock_timer >= C.DEADLOCK_CHECK_INTERVAL:
		deadlock_timer = 0.0
		_check_deadlock()
	if grid.track_conflicts and not crash_done and grid.conflicts.size() > 0:
		crash_done = true
		events.append({"type": "crash", "cell": grid.conflicts[0]})
	_check_end()


func _run_spawn_events() -> void:
	while pending_events.size() > 0 and time >= float(pending_events[0]["at"]):
		var ev = pending_events[0]
		pending_events.remove(0)
		var cells = []
		for f in ev.get("factories", []):
			var d = f.duplicate()
			d["start_at"] = time + float(f.get("delay", 3.0))
			_add_factory(d)
			cells.append(d["cell"])
		for w in ev.get("warehouses", []):
			_add_warehouse(w)
			cells.append(w["cell"])
		grid.mark_dirty()
		pathing.rebuild(grid)
		events.append({"type": "new_building", "cells": cells})


func _update_sensors() -> void:
	# Each light measures the queue of waiting vehicles on its four approaches.
	for l in lights:
		l.waiting[0] = 0
		l.waiting[1] = 0
		l.urgent_waiting[0] = false
		l.urgent_waiting[1] = false
		for d in C.DIRS:
			var axis = 0 if d.y == 0 else 1
			var prev = l.cell
			var cur = l.cell + d
			var n = 0
			while n < C.SENSOR_RANGE and grid.is_passable(cur):
				var found = false
				for v in grid.occupants[cur]:
					if v.cell == cur and v.state == Vehicle.S.WAITING and v.next_cell() == prev:
						found = true
						l.waiting[axis] += 1
						if v.urgent:
							l.urgent_waiting[axis] = true
				if not found:
					break
				prev = cur
				cur += d
				n += 1


func _tick_vehicles(dt: float) -> void:
	var any_done = false
	for v in vehicles:
		if v.urgent and v.state != Vehicle.S.UNLOADING:
			v.repath_timer -= dt
			if v.repath_timer <= 0.0:
				v.repath_timer = C.REPATH_URGENT_INTERVAL
				_repath(v)
		v.tick(dt, self)
		if v.done:
			any_done = true
	if any_done:
		var keep = []
		for v in vehicles:
			if v.done:
				grid.occupants[v.cell].erase(v)
			else:
				keep.append(v)
		vehicles = keep


func _tick_warehouses(dt: float) -> void:
	for w in warehouses:
		if not color_active(w.color):
			continue
		w.drain(dt)
		if w.patience <= 0.0 and not finished:
			_finish("lose", "patience", w.cell)


func _tick_jams(dt: float) -> void:
	var jam = false
	for v in vehicles:
		if (v.state == Vehicle.S.WAITING or v.state == Vehicle.S.STRANDED) and v.wait_time > C.JAM_WAIT:
			jam = true
			metrics.add_jam_cell(v.cell, dt)
	if jam:
		metrics.jam_seconds += dt
	if jam and not jam_active:
		events.append({"type": "jam_start"})
	elif jam_active and not jam:
		events.append({"type": "jam_end"})
	jam_active = jam


func _tick_gridlock(dt: float) -> void:
	var moving = false
	for v in vehicles:
		if v.moved:
			moving = true
			break
	if moving or vehicles.size() < C.GRIDLOCK_MIN_VEHICLES:
		still_time = 0.0
		return
	still_time += dt
	if still_time >= C.GRIDLOCK_SECONDS and not finished:
		_finish("lose", "gridlock", null)


func _refresh_density() -> void:
	for cell in grid.road_cells:
		var now = float(grid.occupants[cell].size()) / grid.capacity(cell)
		density[cell] = lerp(density.get(cell, 0.0), min(now, 1.0), 0.2)


func _blocker_of(v):
	# The waiting vehicle that keeps `v` out of its next tile, or null.
	var to = v.next_cell()
	if not grid.occupants.has(to):
		return null
	var is_j = grid.is_junction(to)
	for o in grid.occupants[to]:
		if o.cell != to or o.state != Vehicle.S.WAITING:
			continue
		if is_j or o.from_cell == v.cell:
			return o
	return null


func _check_deadlock() -> void:
	# Wait-for graph: every waiting vehicle points at the vehicle blocking it.
	var wait_for = {}
	for v in vehicles:
		if v.state == Vehicle.S.WAITING:
			var b = _blocker_of(v)
			if b != null:
				wait_for[v] = b
	var visited = {}
	for v in vehicles:
		if not wait_for.has(v) or visited.has(v):
			continue
		var chain = []
		var on_chain = {}
		var cur = v
		while cur != null and wait_for.has(cur) and not visited.has(cur):
			visited[cur] = true
			on_chain[cur] = chain.size()
			chain.append(cur)
			cur = wait_for[cur]
		if cur != null and on_chain.has(cur):
			var cells = []
			for i in range(on_chain[cur], chain.size()):
				cells.append(chain[i].cell)
			last_deadlock = cells
			if deadlock_cooldown <= 0.0:
				deadlock_cooldown = 2.0
				events.append({"type": "deadlock_cycle", "cells": cells})
			return
	last_deadlock = []


func _check_end() -> void:
	if finished:
		return
	if mode == "goal" and metrics.deliveries >= goal:
		_finish("win", "", null)
	elif time >= time_limit:
		if mode == "score":
			_finish("finished", "", null)
		else:
			_finish("lose", "time", null)


func _finish(res: String, reason: String, cell) -> void:
	finished = true
	result = res
	lose_reason = reason
	lose_cell = cell
	events.append({"type": "finished", "result": res, "reason": reason})


func won() -> bool:
	return result == "win" or result == "finished"
