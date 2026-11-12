extends Reference


const C = preload("res://sim/constants.gd")

var cell = Vector2()
var color = 0
var interval = 4.0
var start_at = 0.0
var urgent_every = 0
var timer = 0.0
var count = 0
var no_route = false


func is_active(a: float) -> bool:
	return a >= start_at


func tick(dt: float, a) -> void:
	if a.time < start_at:
		return
	timer -= dt
	if timer > 0.0:
		return
	if a.vehicles.size() >= C.MAX_VEHICLES:
		timer = interval
		return
	if a.grid.occupants[cell].size() > 0:
		return
	var b = urgent_every > 0 and (count + 1) % urgent_every == 0
	if a.urgent_next.get(color, false):
		b = true
	var c = C.CargoColor.URGENT if b else color
	var d = a.pathing.find_path(c, cell, color, a.warehouses)
	if d.size() < 2:
		no_route = true
		timer = C.NO_ROUTE_RETRY
		return
	no_route = false
	count += 1
	a.spawn_vehicle(self, d, b)
	if b:
		a.urgent_next[color] = false
	timer = interval * a.rng.randf_range(1.0 - C.SPAWN_JITTER, 1.0 + C.SPAWN_JITTER)
