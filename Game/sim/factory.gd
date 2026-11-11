extends Reference

# Spawns trucks on its own schedule. The player never triggers a spawn.

const C = preload("res://sim/constants.gd")

var cell = Vector2()
var color = 0
var interval = 4.0
var start_at = 0.0
var urgent_every = 0             # every Nth truck is urgent (0 = never)
var timer = 0.0
var count = 0
var no_route = false             # shown as a warning icon


func is_active(time: float) -> bool:
	return time >= start_at


func tick(dt: float, sim) -> void:
	if sim.time < start_at:
		return
	timer -= dt
	if timer > 0.0:
		return
	if sim.vehicles.size() >= C.MAX_VEHICLES:
		timer = interval         # skip this spawn
		return
	if sim.grid.occupants[cell].size() > 0:
		return                   # start tile is busy, try again next step
	var urgent = urgent_every > 0 and (count + 1) % urgent_every == 0
	var cls = C.CargoColor.URGENT if urgent else color
	var path = sim.pathing.find_path(cls, cell, color, sim.warehouses)
	if path.size() < 2:
		no_route = true
		timer = C.NO_ROUTE_RETRY
		return
	no_route = false
	count += 1
	sim.spawn_vehicle(self, path, urgent)
	timer = interval * sim.rng.randf_range(1.0 - C.SPAWN_JITTER, 1.0 + C.SPAWN_JITTER)
