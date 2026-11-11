extends Reference

# Plays a lesson's `solution` through the real simulation and a real manager, with no UI.
# Used by the tests (and the smoke test) to prove every lesson can be finished.

const C = preload("res://sim/constants.gd")

const MAX_RUN_SECONDS = 400.0


static func run(sim, manager, lesson: Dictionary) -> String:
	# Returns "" on success or a description of what went wrong.
	for entry in lesson["solution"]:
		var what = entry["do"]
		if what == "continue":
			manager.notify("continue")
		elif what == "action":
			if not sim.apply_action(entry["action"]):
				return "action failed: " + str(entry["action"])
			manager.notify("changed")
		elif what == "speed":
			manager.notify("speed_started")
			manager.notify("speed_set", {"value": entry["value"]})
		elif what == "heatmap":
			manager.notify("heatmap_toggled", {"on": entry["on"]})
		elif what == "run_for":
			_run(sim, manager, entry["seconds"], false)
		elif what == "run":
			var err = _run(sim, manager, MAX_RUN_SECONDS, true)
			if err != "":
				return err
		if manager.done:
			break
	if not manager.done:
		return "lesson not completed, stuck at step %d (%s)" % [manager.idx, manager.current_step().get("id", "?")]
	return ""


static func _run(sim, manager, seconds: float, until_step_done: bool) -> String:
	# Steps the simulation. With until_step_done it stops as soon as the manager moves on.
	var start_idx = manager.idx
	var n = int(seconds / C.STEP)
	for _i in range(n):
		sim.step(C.STEP)
		manager.tick(C.STEP)
		if until_step_done and (manager.idx != start_idx or manager.done):
			return ""
		if sim.finished:
			manager.notify("changed")          # lets the manager see a win or a loss
			if manager.done or manager.idx != start_idx:
				return ""
			if until_step_done:
				return "run ended early: %s %s" % [sim.result, sim.lose_reason]
			return ""
	if until_step_done:
		return "step did not complete within %d seconds (step %s)" % [int(seconds), manager.current_step().get("id", "?")]
	return ""
