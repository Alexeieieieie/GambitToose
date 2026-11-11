extends Reference

# One truck. Pure data plus the per-step movement rule.

const C = preload("res://sim/constants.gd")

enum S { DRIVING, WAITING, UNLOADING, STRANDED }

var color = 0                    # cargo color = which warehouse accepts it
var urgent = false
var path = []                    # Array of Vector2 cells
var idx = 0
var progress = 0.0               # 0..1 between path[idx] and path[idx + 1]
var state = S.DRIVING
var wait_time = 0.0
var unload_timer = 0.0
var pos = Vector2()              # world pixels (tile center line)
var spawn_time = 0.0
var reserved = false
var cell = Vector2()             # tile the vehicle is in
var from_cell = C.NO_CELL        # tile it entered `cell` from (its lane)
var dir = Vector2(1, 0)          # heading of the current segment
var dir_prev = Vector2(1, 0)     # heading of the previous segment
var speed = C.SPEED_NORMAL
var done = false
var moved = false
var repath_timer = 0.0


func route_class() -> int:
	return C.CargoColor.URGENT if urgent else color


func next_cell() -> Vector2:
	if idx + 1 < path.size():
		return path[idx + 1]
	return C.NO_CELL


func tick(dt: float, sim) -> void:
	var grid = sim.grid
	moved = false
	if state == S.DRIVING:
		if idx >= path.size() - 1:
			_arrive(sim)
			return
		if not reserved:
			if not grid.try_enter(self, path[idx], path[idx + 1]):
				state = S.WAITING
				wait_time = 0.0
				return
			_begin_segment()
		progress = min(progress + speed * dt, 1.0)
		moved = true
		pos = grid.center(path[idx]).linear_interpolate(grid.center(path[idx + 1]), progress)
		if progress >= 1.0:
			grid.leave(path[idx], self)
			from_cell = path[idx]
			idx += 1
			cell = path[idx]
			progress = 0.0
			reserved = false
			if idx >= path.size() - 1:
				_arrive(sim)
	elif state == S.WAITING:
		wait_time += dt
		if idx >= path.size() - 1:
			_arrive(sim)
		elif grid.try_enter(self, path[idx], path[idx + 1]):
			_begin_segment()
			state = S.DRIVING
	elif state == S.UNLOADING:
		moved = true
		unload_timer -= dt
		if unload_timer <= 0.0:
			sim.deliver(self)
	else:
		wait_time += dt


func _begin_segment() -> void:
	reserved = true
	dir_prev = dir
	dir = path[idx + 1] - path[idx]


func _arrive(sim) -> void:
	if sim.is_warehouse_for(cell, color):
		state = S.UNLOADING
		unload_timer = C.UNLOAD_TIME
	else:
		state = S.STRANDED
		wait_time = 0.0
