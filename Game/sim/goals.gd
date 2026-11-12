extends Reference


enum Status { PENDING, DONE, FAILED }

const TYPES = ["complete", "time_left_min", "jam_seconds_max", "avg_delivery_max", "urgent_min",
		"patience_min", "roads_max", "deliver_min", "score_min"]
const LIVE_TYPES = ["urgent_min", "deliver_min", "score_min"]
const EARLY_FAIL_TYPES = ["jam_seconds_max", "patience_min"]
const NO_VALUE_TYPES = ["complete"]

var defs = []
var status = []
var finalized = false


static func text_key(b: String) -> String:
	return "GOAL_" + b.to_upper()


static func progress_key(b: String) -> String:
	return "GOALP_" + b.to_upper()


static func result_key(b: String) -> String:
	return "GOALR_" + b.to_upper()


func setup(b: Dictionary) -> void:
	defs = b.get("star_goals", [])
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


func _mark(b, i: int, st: int, c: bool) -> void:
	if status[i] != Status.PENDING:
		return
	status[i] = st
	if c and b != null:
		b.events.append({"type": "goal_reached" if st == Status.DONE else "goal_failed", "index": i})


func tick(b) -> void:
	if finalized:
		return
	var m = b.metrics
	for i in range(defs.size()):
		if status[i] != Status.PENDING:
			continue
		var c = type_of(i)
		var v = value_of(i)
		if c == "urgent_min" and m.urgent_deliveries >= v:
			_mark(b, i, Status.DONE, true)
		elif c == "deliver_min" and m.deliveries >= v:
			_mark(b, i, Status.DONE, true)
		elif c == "score_min" and m.score() >= v:
			_mark(b, i, Status.DONE, true)
		elif c == "jam_seconds_max" and m.jam_seconds > v:
			_mark(b, i, Status.FAILED, true)
		elif c == "patience_min" and m.min_patience_ratio * 100.0 < v:
			_mark(b, i, Status.FAILED, true)


func finalize(b, c: bool) -> void:
	if finalized:
		return
	tick(b)
	finalized = true
	var m = b.metrics
	for i in range(defs.size()):
		if status[i] != Status.PENDING:
			continue
		var d = type_of(i)
		var v = value_of(i)
		var ok = false
		if d == "complete":
			ok = c
		elif d == "time_left_min":
			ok = c and b.time_left() >= v
		elif d == "avg_delivery_max":
			ok = c and m.deliveries > 0 and m.avg_delivery_time() <= v
		elif d == "roads_max":
			ok = c and b.grid.player_built.size() <= v
		elif d == "jam_seconds_max" or d == "patience_min":
			ok = c
		_mark(b, i, Status.DONE if ok else Status.FAILED, false)


func value_text_args(i: int, b) -> Array:
	var m = b.metrics
	var c = type_of(i)
	var v = int(value_of(i))
	if c == "time_left_min":
		return [int(b.time_left())]
	if c == "jam_seconds_max":
		return [int(m.jam_seconds), v]
	if c == "avg_delivery_max":
		return [m.avg_delivery_time(), v]
	if c == "urgent_min":
		return [m.urgent_deliveries, v]
	if c == "patience_min":
		return [int(m.min_patience_ratio * 100.0)]
	if c == "roads_max":
		return [b.grid.player_built.size(), v]
	if c == "deliver_min":
		return [m.deliveries, v]
	if c == "score_min":
		return [m.score(), v]
	return []


func result_args(i: int, b) -> Array:
	var a = value_text_args(i, b)
	if a.size() == 0:
		return []
	return [a[0]]


func earned_mask() -> int:
	var b = 0
	for i in range(status.size()):
		if status[i] == Status.DONE:
			b |= (1 << i)
	return b


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
