extends Reference


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
var waiting = [0, 0]
var urgent_waiting = [false, false]
var switches = 0


func tick(dt: float) -> void:
	t += dt
	if phase == Phase.GREEN:
		if t >= C.MIN_GREEN:
			if _urgent_override():
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
	var a = 1 - green_axis
	return urgent_waiting[a] and not urgent_waiting[green_axis]


func _wants_switch() -> bool:
	var a = 1 - green_axis
	if mode == C.LightMode.TIMER:
		return t >= period
	return waiting[a] > threshold or (waiting[green_axis] == 0 and waiting[a] > 0)


func allows(_v, a: Vector2) -> bool:
	var b = 0 if a.y == cell.y else 1
	return phase == Phase.GREEN and b == green_axis
