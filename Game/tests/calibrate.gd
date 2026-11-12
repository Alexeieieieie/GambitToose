extends SceneTree

# Developer tool: prints what the intended solution and a baseline earn on every level.
# Run: ./godot.sh --no-window -s tests/calibrate.gd

const Sim = preload("res://sim/sim.gd")
const C = preload("res://sim/constants.gd")
const LevelsScript = preload("res://autoload/levels.gd")


func _initialize() -> void:
	var levels = LevelsScript.new()
	for lv in levels.LEVELS:
		for variant in ["solution", "baseline", "timer"]:
			var sim = Sim.new()
			sim.load_level(lv)
			for a in lv["solution"]:
				if variant == "baseline" and (a["type"] == "light" or a["type"] == "sorter"):
					continue
				var act = a
				if variant == "timer" and a["type"] == "light":
					act = a.duplicate()
					act["mode"] = C.LightMode.TIMER
				sim.apply_action(act)
			var guard = 0
			while not sim.finished and guard < 40000:
				sim.step(C.STEP)
				guard += 1
			var m = sim.metrics
			print("L%d %-8s result=%s deliv=%d time=%.0f left=%.0f jam=%.1f avg=%.1f urgent=%d minpat=%.2f roads=%d score=%d status=%s" % [
				lv["id"], variant, sim.result, m.deliveries, sim.time, sim.time_left(), m.jam_seconds,
				m.avg_delivery_time(), m.urgent_deliveries, m.min_patience_ratio, sim.grid.player_built.size(),
				m.score(), str(sim.goals.status)])
	quit()
