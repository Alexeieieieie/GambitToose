extends Reference


const C = preload("res://sim/constants.gd")
const Grid = preload("res://sim/grid.gd")
const Vehicle = preload("res://sim/vehicle.gd")
const Intersection = preload("res://sim/intersection.gd")
const Sorter = preload("res://sim/sorter.gd")
const Factory = preload("res://sim/factory.gd")
const Warehouse = preload("res://sim/warehouse.gd")
const Metrics = preload("res://sim/metrics.gd")
const Pathing = preload("res://sim/pathing.gd")
const Goals = preload("res://sim/goals.gd")

var level = {}
var grid
var pathing
var metrics
var goals
var goals_enabled = true
var rng = RandomNumberGenerator.new()

var vehicles = []
var factories = []
var warehouses = []
var lights = []
var sorters = []
var inventory = {"road": 0, "light": 0, "sorter": 0, "bridge": 0}
var pending_events = []
var events = []

var time = 0.0
var time_limit = 0.0
var goal = 0
var mode = "goal"
var finished = false
var lose_enabled = true
var lesson = false
var urgent_next = {}
var result = ""
var lose_reason = ""
var lose_cell = null

var density = {}
var still_time = 0.0
var risk_mark = -1
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
	goals = Goals.new()
	goals.setup(lv)
	rng.seed = lv.get("seed", 1)
	time_limit = float(lv.get("time", 240))
	goal = int(lv.get("goal", 0))
	mode = lv.get("mode", "goal")
	lose_enabled = lv.get("lose_enabled", true)
	lesson = lv.get("lesson", false)
	grid.track_conflicts = lv.get("force_crash", false)
	grid.hold_for_crash = grid.track_conflicts
	var c = lv.get("inventory", {})
	for e in ["road", "light", "sorter", "bridge"]:
		inventory[e] = int(c.get(e, 0))
	for g in lv.get("water", []):
		grid.tiles[g] = C.Tile.WATER
	for g in lv.get("obstacles", []):
		grid.tiles[g] = C.Tile.OBSTACLE
	for g in lv.get("roads", []):
		grid.tiles[g] = C.Tile.ROAD
	for f in lv.get("factories", []):
		_add_factory(f)
	for w in lv.get("warehouses", []):
		_add_warehouse(w)
	for a in lv.get("prebuilt", []):
		_apply_prebuilt(a)
	pending_events = lv.get("spawn_events", []).duplicate()
	for ev in pending_events:
		for f in ev.get("factories", []):
			grid.reserved[f["cell"]] = true
		for w in ev.get("warehouses", []):
			grid.reserved[w["cell"]] = true
	grid.mark_dirty()
	pathing.rebuild(grid)


func _apply_prebuilt(a: Dictionary) -> void:
	var c = a["type"]
	if c == "road_line":
		var e = a["from"]
		var to = a["to"]
		var d = Vector2(sign(to.x - e.x), sign(to.y - e.y))
		var g = e
		while true:
			grid.tiles[g] = C.Tile.ROAD
			if g == to:
				break
			g += d
	elif c == "road":
		grid.tiles[a["cell"]] = C.Tile.ROAD
	elif c == "light":
		var l = Intersection.new()
		l.cell = a["cell"]
		l.mode = a.get("mode", C.LightMode.TIMER)
		l.period = a.get("period", C.DEFAULT_PERIOD)
		l.threshold = a.get("threshold", C.DEFAULT_THRESHOLD)
		grid.controllers[l.cell] = l
		lights.append(l)
	grid.mark_dirty()


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



func can_build_road(c: Vector2) -> bool:
	return grid.in_bounds(c) and grid.tile(c) == C.Tile.EMPTY \
			and not grid.reserved.has(c) and inventory["road"] > 0


func build_road(c: Vector2) -> bool:
	if not can_build_road(c):
		return false
	grid.tiles[c] = C.Tile.ROAD
	grid.player_built[c] = true
	inventory["road"] -= 1
	grid.mark_dirty()
	return true


func can_build_bridge(c: Vector2) -> bool:
	return grid.in_bounds(c) and grid.tile(c) == C.Tile.WATER and inventory["bridge"] > 0


func build_bridge(c: Vector2) -> bool:
	if not can_build_bridge(c):
		return false
	grid.tiles[c] = C.Tile.BRIDGE
	grid.player_built[c] = true
	inventory["bridge"] -= 1
	grid.mark_dirty()
	return true


func can_place_controller(c: Vector2, e: String) -> bool:
	return grid.is_junction(c) and not grid.controllers.has(c) and inventory[e] > 0


func place_light(c: Vector2):
	if not can_place_controller(c, "light"):
		return null
	var l = Intersection.new()
	l.cell = c
	grid.controllers[c] = l
	lights.append(l)
	inventory["light"] -= 1
	grid.mark_dirty()
	return l


func place_sorter(c: Vector2):
	if not can_place_controller(c, "sorter"):
		return null
	var s = Sorter.new()
	s.cell = c
	grid.controllers[c] = s
	sorters.append(s)
	inventory["sorter"] -= 1
	grid.mark_dirty()
	return s


func configure_light(c: Vector2, e: int, g: float, h: int, j: bool) -> bool:
	var l = grid.controllers.get(c)
	if l == null or l.is_sorter:
		return false
	l.mode = e
	l.period = g
	l.threshold = h
	l.urgent_first = j
	return true


func configure_sorter(c: Vector2, e: Dictionary) -> bool:
	var s = grid.controllers.get(c)
	if s == null or not s.is_sorter:
		return false
	for g in e.keys():
		s.rules[g] = e[g]
	grid.mark_dirty()
	return true


func can_erase(c: Vector2) -> bool:
	return grid.controllers.has(c) or grid.player_built.has(c)


func erase(c: Vector2) -> String:
	var e = grid.controllers.get(c)
	if e != null:
		grid.controllers.erase(c)
		var g = "sorter" if e.is_sorter else "light"
		if e.is_sorter:
			sorters.erase(e)
		else:
			lights.erase(e)
		inventory[g] += 1
		grid.mark_dirty()
		return g
	if not grid.player_built.has(c):
		return ""
	var h = grid.tile(c) == C.Tile.BRIDGE
	for v in grid.occupants[c].duplicate():
		_drop_vehicle(v)
	grid.tiles[c] = C.Tile.WATER if h else C.Tile.EMPTY
	grid.player_built.erase(c)
	var j = "bridge" if h else "road"
	inventory[j] += 1
	grid.mark_dirty()
	return j


func apply_action(a: Dictionary) -> bool:
	var c = a["type"]
	if c == "road_line":
		var e = a["from"]
		var to = a["to"]
		var d = Vector2(sign(to.x - e.x), sign(to.y - e.y))
		var g = e
		var ok = true
		while true:
			if grid.tile(g) == C.Tile.EMPTY:
				ok = build_road(g) and ok
			if g == to:
				break
			g += d
		return ok
	if c == "road":
		return build_road(a["cell"])
	if c == "bridge":
		return build_bridge(a["cell"])
	if c == "light":
		if place_light(a["cell"]) == null:
			return false
		return configure_light(a["cell"], a.get("mode", C.LightMode.SENSOR),
				a.get("period", C.DEFAULT_PERIOD), a.get("threshold", C.DEFAULT_THRESHOLD),
				a.get("urgent_first", false))
	if c == "sorter":
		if place_sorter(a["cell"]) == null:
			return false
		return configure_sorter(a["cell"], a.get("rules", {}))
	if c == "configure_light":
		return configure_light(a["cell"], a.get("mode", C.LightMode.SENSOR),
				a.get("period", C.DEFAULT_PERIOD), a.get("threshold", C.DEFAULT_THRESHOLD),
				a.get("urgent_first", false))
	if c == "erase":
		return erase(a["cell"]) != ""
	return false


func apply_solution() -> bool:
	var ok = true
	for a in level.get("solution", []):
		ok = apply_action(a) and ok
	return ok



func is_warehouse_for(c: Vector2, e: int) -> bool:
	if grid.tile(c) != C.Tile.WAREHOUSE:
		return false
	for w in warehouses:
		if w.cell == c:
			return w.color == e
	return false


func color_active(c: int) -> bool:
	for f in factories:
		if f.color == c and time >= f.start_at:
			return true
	return false


func has_route(f) -> bool:
	if grid.graph_dirty:
		pathing.rebuild(grid)
	return pathing.find_path(f.color, f.cell, f.color, warehouses).size() >= 2


func time_left() -> float:
	return max(time_limit - time, 0.0)



func spawn_vehicle(f, c: Array, e: bool) -> void:
	var v = Vehicle.new()
	v.color = f.color
	v.urgent = e
	v.speed = C.SPEED_URGENT if e else C.SPEED_NORMAL
	v.path = c
	v.cell = c[0]
	v.pos = grid.center(v.cell)
	v.dir = c[1] - c[0]
	v.dir_prev = v.dir
	v.spawn_time = time
	v.repath_timer = C.REPATH_URGENT_INTERVAL
	grid.occupants[v.cell].append(v)
	vehicles.append(v)


func deliver(v) -> void:
	v.done = true
	metrics.deliveries += 1
	metrics.total_delivery_time += time - v.spawn_time
	if v.urgent:
		metrics.urgent_deliveries += 1
	for w in warehouses:
		if w.cell == v.cell:
			w.deliver()
	events.append({"type": "deliver", "cell": v.cell, "color": v.color, "jam": jam_active, "urgent": v.urgent})


func _drop_vehicle(v) -> void:
	grid.occupants[v.cell].erase(v)
	if v.reserved:
		var n = v.next_cell()
		if grid.occupants.has(n):
			grid.occupants[n].erase(v)
	v.done = true
	vehicles.erase(v)


func _repath(v) -> bool:
	var c = v.next_cell() if v.reserved else v.cell
	var p = pathing.find_path(v.route_class(), c, v.color, warehouses)
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
				var c = [v.cell]
				if v.reserved:
					c.append(v.next_cell())
				v.path = c
				v.idx = 0



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
		var c = l.green_axis
		l.tick(dt)
		if l.green_axis != c:
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
	metrics.time_left = time_left()
	metrics.roads_used = grid.player_built.size()
	if goals_enabled:
		goals.tick(self)
	if grid.track_conflicts and not crash_done and grid.conflicts.size() > 0:
		crash_done = true
		events.append({"type": "crash", "cell": grid.conflicts[0]})
	_check_end()


func _run_spawn_events() -> void:
	while pending_events.size() > 0 and time >= float(pending_events[0]["at"]):
		var ev = pending_events[0]
		pending_events.remove(0)
		var c = []
		for f in ev.get("factories", []):
			var d = f.duplicate()
			d["start_at"] = time + float(f.get("delay", 3.0))
			_add_factory(d)
			c.append(d["cell"])
		for w in ev.get("warehouses", []):
			_add_warehouse(w)
			c.append(w["cell"])
		grid.mark_dirty()
		pathing.rebuild(grid)
		events.append({"type": "new_building", "cells": c})


func _update_sensors() -> void:
	for l in lights:
		l.waiting[0] = 0
		l.waiting[1] = 0
		l.urgent_waiting[0] = false
		l.urgent_waiting[1] = false
		for d in C.DIRS:
			var c = 0 if d.y == 0 else 1
			var e = l.cell
			var g = l.cell + d
			var n = 0
			while n < C.SENSOR_RANGE and grid.is_passable(g):
				var h = false
				for v in grid.occupants[g]:
					if v.cell == g and v.state == Vehicle.S.WAITING and v.next_cell() == e:
						h = true
						l.waiting[c] += 1
						if v.urgent:
							l.urgent_waiting[c] = true
				if not h:
					break
				e = g
				g += d
				n += 1


func _tick_vehicles(dt: float) -> void:
	var c = false
	for v in vehicles:
		if v.urgent and v.state != Vehicle.S.UNLOADING:
			v.repath_timer -= dt
			if v.repath_timer <= 0.0:
				v.repath_timer = C.REPATH_URGENT_INTERVAL
				_repath(v)
		v.tick(dt, self)
		if v.done:
			c = true
	if c:
		var e = []
		for v in vehicles:
			if v.done:
				grid.occupants[v.cell].erase(v)
			else:
				e.append(v)
		vehicles = e


func _tick_warehouses(dt: float) -> void:
	for w in warehouses:
		if not color_active(w.color):
			continue
		w.drain(dt)
		_observe_patience(w)
		if not lose_enabled:
			if w.patience <= 1.0:
				w.patience = C.WAREHOUSE_PATIENCE_MAX
			continue
		if w.patience <= 0.0 and not finished:
			_finish("lose", "patience", w.cell)


func _observe_patience(w) -> void:
	var r = w.ratio()
	if r < metrics.min_patience_ratio:
		metrics.min_patience_ratio = r
	for c in C.PATIENCE_LOW_PERCENT:
		if r * 100.0 < c:
			if not w.low_flags.get(c, false):
				w.low_flags[c] = true
				events.append({"type": "patience_low", "cell": w.cell, "threshold": c})
		elif r * 100.0 >= C.PATIENCE_REARM_PERCENT:
			w.low_flags[c] = false


func _tick_jams(dt: float) -> void:
	var c = false
	for v in vehicles:
		if (v.state == Vehicle.S.WAITING or v.state == Vehicle.S.STRANDED) and v.wait_time > C.JAM_WAIT:
			c = true
			metrics.add_jam_cell(v.cell, dt)
	if c:
		metrics.jam_seconds += dt
	if c and not jam_active:
		events.append({"type": "jam_start"})
	elif jam_active and not c:
		events.append({"type": "jam_end"})
	jam_active = c


func _tick_gridlock(dt: float) -> void:
	var c = false
	for v in vehicles:
		if v.moved:
			c = true
			break
	if c or vehicles.size() < C.GRIDLOCK_MIN_VEHICLES:
		still_time = 0.0
		risk_mark = -1
		return
	still_time += dt
	if still_time >= C.GRIDLOCK_RISK_SECONDS and int(still_time) != risk_mark:
		risk_mark = int(still_time)
		events.append({"type": "gridlock_risk", "seconds": int(still_time)})
	if still_time >= C.GRIDLOCK_SECONDS and not finished and lose_enabled:
		_finish("lose", "gridlock", null)


func _refresh_density() -> void:
	for c in grid.road_cells:
		var e = float(grid.occupants[c].size()) / grid.capacity(c)
		density[c] = lerp(density.get(c, 0.0), min(e, 1.0), 0.2)


func _blocker_of(v):
	var to = v.next_cell()
	if not grid.occupants.has(to):
		return null
	var c = grid.is_junction(to)
	for o in grid.occupants[to]:
		if o.cell != to or o.state != Vehicle.S.WAITING:
			continue
		if c or o.from_cell == v.cell:
			return o
	return null


func _check_deadlock() -> void:
	var c = {}
	for v in vehicles:
		if v.state == Vehicle.S.WAITING:
			var b = _blocker_of(v)
			if b != null:
				c[v] = b
	var e = {}
	for v in vehicles:
		if not c.has(v) or e.has(v):
			continue
		var g = []
		var h = {}
		var j = v
		while j != null and c.has(j) and not e.has(j):
			e[j] = true
			h[j] = g.size()
			g.append(j)
			j = c[j]
		if j != null and h.has(j):
			var k = []
			for i in range(h[j], g.size()):
				k.append(g[i].cell)
			last_deadlock = k
			if deadlock_cooldown <= 0.0:
				deadlock_cooldown = 2.0
				events.append({"type": "deadlock_cycle", "cells": k})
			return
	last_deadlock = []


func _check_end() -> void:
	if finished or lesson:
		return
	if mode == "goal" and metrics.deliveries >= goal:
		_finish("win", "", null)
	elif time_limit > 0.0 and time >= time_limit:
		if mode == "score":
			_finish("finished", "", null)
		else:
			_finish("lose", "time", null)


func _finish(c: String, e: String, g) -> void:
	finished = true
	result = c
	lose_reason = e
	lose_cell = g
	if goals_enabled:
		goals.finalize(self, won())
	events.append({"type": "finished", "result": c, "reason": e})


func won() -> bool:
	return result == "win" or result == "finished"
