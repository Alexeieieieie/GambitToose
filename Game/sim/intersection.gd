extends Reference

# A smart traffic light on one tile. Axis 0 is horizontal, axis 1 is vertical.

const C = preload("res://sim/constants.gd")

enum Phase { GREEN, YELLOW, ALL_RED }

var is_sorter = false
var cell = Vector2()
var mode = C.LightMode.TIMER
var period = C.DEFAULT_PERIOD
var threshold = C.DEFAULT_THRESHOLD
var urgent_first = false
var phase = Phase.GREEN
var green_axis = 0
var t = 0.0
var waiting = [0, 0]             # queue length per axis, filled by the simulation
var urgent_waiting = [false, false]
var switches = 0                 # counts changes of the green axis


func tick(dt: float) -> void:
	t += dt
	if phase == Phase.GREEN:
		if t >= C.MIN_GREEN:
			if _urgent_override():
				# Urgent trucks skip the yellow and all-red delay.
				_flip()
			elif _wants_switch():
				_enter(Phase.YELLOW)
	elif phase == Phase.YELLOW:
		if t >= C.YELLOW_TIME:
			_enter(Phase.ALL_RED)
	else:
		if t >= C.ALL_RED_TIME:
			_flip()


func _flip() -> void:
	green_axis = 1 - green_axis
	switches += 1
	_enter(Phase.GREEN)


func _enter(p: int) -> void:
	phase = p
	t = 0.0


func _urgent_override() -> bool:
	if mode != C.LightMode.PRIORITY and not urgent_first:
		return false
	var other = 1 - green_axis
	return urgent_waiting[other] and not urgent_waiting[green_axis]


func _wants_switch() -> bool:
	var other = 1 - green_axis
	if mode == C.LightMode.TIMER:
		return t >= period
	# SENSOR, and PRIORITY when no urgent truck is waiting.
	return waiting[other] > threshold or (waiting[green_axis] == 0 and waiting[other] > 0)


func allows(_v, from: Vector2) -> bool:
	var axis = 0 if from.y == cell.y else 1
	return phase == Phase.GREEN and axis == green_axis
