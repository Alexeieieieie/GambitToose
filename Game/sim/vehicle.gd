extends Reference


const C = preload("res://sim/constants.gd")

enum S { DRIVING, WAITING, UNLOADING, STRANDED }

var color = 0
var urgent = false
var path = []
var idx = 0
var progress = 0.0
var state = S.DRIVING
var wait_time = 0.0
var unload_timer = 0.0
var pos = Vector2()
var spawn_time = 0.0
var reserved = false
var cell = Vector2()
var from_cell = C.NO_CELL
var dir = Vector2(1, 0)
var dir_prev = Vector2(1, 0)
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


func tick(dt: float, a) -> void:
	var b = a.grid
	moved = false
	if state == S.DRIVING:
		if idx >= path.size() - 1:
			_arrive(a)
			return
		if not reserved:
			if not b.try_enter(self, path[idx], path[idx + 1]):
				state = S.WAITING
				wait_time = 0.0
				return
			_begin_segment()
		progress = min(progress + speed * dt, 1.0)
		moved = true
		pos = b.center(path[idx]).linear_interpolate(b.center(path[idx + 1]), progress)
		if progress >= 1.0:
			b.leave(path[idx], self)
			from_cell = path[idx]
			idx += 1
			cell = path[idx]
			progress = 0.0
			reserved = false
			if idx >= path.size() - 1:
				_arrive(a)
	elif state == S.WAITING:
		wait_time += dt
		if idx >= path.size() - 1:
			_arrive(a)
		elif b.try_enter(self, path[idx], path[idx + 1]):
			_begin_segment()
			state = S.DRIVING
	elif state == S.UNLOADING:
		moved = true
		unload_timer -= dt
		if unload_timer <= 0.0:
			a.deliver(self)
	else:
		wait_time += dt


func _begin_segment() -> void:
	reserved = true
	dir_prev = dir
	dir = path[idx + 1] - path[idx]


func _arrive(a) -> void:
	if a.is_warehouse_for(cell, color):
		state = S.UNLOADING
		unload_timer = C.UNLOAD_TIME
	else:
		state = S.STRANDED
		wait_time = 0.0
