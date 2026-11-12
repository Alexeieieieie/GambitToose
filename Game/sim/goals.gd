extends Reference

# Per-level star goals. A pure observer: it reads the simulation and pushes
# goal_reached / goal_failed events, and never changes anything the simulation does.

enum Status { PENDING, DONE, FAILED }

const TYPES = ["complete", "time_left_min", "jam_seconds_max", "avg_delivery_max", "urgent_min",
		"patience_min", "roads_max", "deliver_min", "score_min"]
const LIVE_TYPES = ["urgent_min", "deliver_min", "score_min"]          # DONE the moment the value is reached
const EARLY_FAIL_TYPES = ["jam_seconds_max", "patience_min"]           # FAILED the moment the limit is broken
const NO_VALUE_TYPES = ["complete"]

var defs = []                    # from the level
var status = []                  # one Status per goal
var finalized = false


static func text_key(type: String) -> String:
	return "GOAL_" + type.to_upper()


static func progress_key(type: String) -> String:
	return "GOALP_" + type.to_upper()


static func result_key(type: String) -> String:
	return "GOALR_" + type.to_upper()


func setup(level: Dictionary) -> void:
	defs = level.get("star_goals", [])
	status = []
	for _d in defs:
		status.append(Status.PENDING)
	finalized = false


func count() -> int:
	return defs.size()


func type_of(i: int) -> String:
	return defs[i]["type"]


func value_of(i: int) -> float:
	return float(defs[i].get("value", 0))


func _mark(sim, i: int, st: int, announce: bool) -> void:
	if status[i] != Status.PENDING:
		return                   # a goal never goes back, and never changes twice
	status[i] = st
	if announce and sim != null:
		sim.events.append({"type": "goal_reached" if st == Status.DONE else "goal_failed", "index": i})


func tick(sim) -> void:
	if finalized:
		return
	var m = sim.metrics
	for i in range(defs.size()):
		if status[i] != Status.PENDING:
			continue
		var type = type_of(i)
		var v = value_of(i)
		if type == "urgent_min" and m.urgent_deliveries >= v:
			_mark(sim, i, Status.DONE, true)
		elif type == "deliver_min" and m.deliveries >= v:
			_mark(sim, i, Status.DONE, true)
		elif type == "score_min" and m.score() >= v:
			_mark(sim, i, Status.DONE, true)
		elif type == "jam_seconds_max" and m.jam_seconds > v:
			_mark(sim, i, Status.FAILED, true)
		elif type == "patience_min" and m.min_patience_ratio * 100.0 < v:
			_mark(sim, i, Status.FAILED, true)


func finalize(sim, won: bool) -> void:
	if finalized:
		return
	tick(sim)
	finalized = true
	var m = sim.metrics
	for i in range(defs.size()):
		if status[i] != Status.PENDING:
			continue
		var type = type_of(i)
		var v = value_of(i)
		var ok = false
		if type == "complete":
			ok = won
		elif type == "time_left_min":
			ok = won and sim.time_left() >= v
		elif type == "avg_delivery_max":
			ok = won and m.deliveries > 0 and m.avg_delivery_time() <= v
		elif type == "roads_max":
			ok = won and sim.grid.player_built.size() <= v
		elif type == "jam_seconds_max" or type == "patience_min":
			ok = won           # nothing broke the limit during the run
		# live goals still pending at the end were not reached
		_mark(sim, i, Status.DONE if ok else Status.FAILED, false)


func value_text_args(i: int, sim) -> Array:
	# The numbers for the live progress text (GOALP_<TYPE>) and the final result text (GOALR_<TYPE>).
	var m = sim.metrics
	var type = type_of(i)
	var v = int(value_of(i))
	if type == "time_left_min":
		return [int(sim.time_left())]
	if type == "jam_seconds_max":
		return [int(m.jam_seconds), v]
	if type == "avg_delivery_max":
		return [m.avg_delivery_time(), v]
	if type == "urgent_min":
		return [m.urgent_deliveries, v]
	if type == "patience_min":
		return [int(m.min_patience_ratio * 100.0)]
	if type == "roads_max":
		return [sim.grid.player_built.size(), v]
	if type == "deliver_min":
		return [m.deliveries, v]
	if type == "score_min":
		return [m.score(), v]
	return []


func result_args(i: int, sim) -> Array:
	# One number for the final "Result: ..." text (GOALR_<TYPE>).
	var a = value_text_args(i, sim)
	if a.size() == 0:
		return []
	return [a[0]]


func earned_mask() -> int:
	var mask = 0
	for i in range(status.size()):
		if status[i] == Status.DONE:
			mask |= (1 << i)
	return mask


func stars() -> int:
	var n = 0
	for st in status:
		if st == Status.DONE:
			n += 1
	return n


func first_failed() -> int:
	for i in range(status.size()):
		if status[i] == Status.FAILED:
			return i
	return -1
