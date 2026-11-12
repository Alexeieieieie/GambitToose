extends Reference


const C = preload("res://sim/constants.gd")

const MAX_RUN_SECONDS = 400.0


static func run(a, b, c: Dictionary) -> String:
	for d in c["solution"]:
		var e = d["do"]
		if e == "continue":
			b.notify("continue")
		elif e == "action":
			if not a.apply_action(d["action"]):
				return "action failed: " + str(d["action"])
			b.notify("changed")
		elif e == "speed":
			b.notify("speed_started")
			b.notify("speed_set", {"value": d["value"]})
		elif e == "heatmap":
			b.notify("heatmap_toggled", {"on": d["on"]})
		elif e == "run_for":
			_run(a, b, d["seconds"], false)
		elif e == "run":
			var f = _run(a, b, MAX_RUN_SECONDS, true)
			if f != "":
				return f
		if b.done:
			break
	if not b.done:
		return "lesson not completed, stuck at step %d (%s)" % [b.idx, b.current_step().get("id", "?")]
	return ""


static func _run(a, b, c: float, d: bool) -> String:
	var e = b.idx
	var n = int(c / C.STEP)
	for _i in range(n):
		a.step(C.STEP)
		b.tick(C.STEP)
		if d and (b.idx != e or b.done):
			return ""
		if a.finished:
			b.notify("changed")
			if b.done or b.idx != e:
				return ""
			if d:
				return "run ended early: %s %s" % [a.result, a.lose_reason]
			return ""
	if d:
		return "step did not complete within %d seconds (step %s)" % [int(c), b.current_step().get("id", "?")]
	return ""
