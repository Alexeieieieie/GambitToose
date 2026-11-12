extends SceneTree


const Sim = preload("res://sim/sim.gd")
const C = preload("res://sim/constants.gd")
const LevelsScript = preload("res://autoload/levels.gd")


func _initialize() -> void:
	var b = LevelsScript.new()
	for lv in b.LEVELS:
		for c in ["solution", "baseline", "timer"]:
			var d = Sim.new()
			d.load_level(lv)
			for a in lv["solution"]:
				if c == "baseline" and (a["type"] == "light" or a["type"] == "sorter"):
					continue
				var e = a
				if c == "timer" and a["type"] == "light":
					e = a.duplicate()
					e["mode"] = C.LightMode.TIMER
				d.apply_action(e)
			var f = 0
			while not d.finished and f < 40000:
				d.step(C.STEP)
				f += 1
			var m = d.metrics
			print("L%d %-8s result=%s deliv=%d time=%.0f left=%.0f jam=%.1f avg=%.1f urgent=%d minpat=%.2f roads=%d score=%d status=%s" % [
				lv["id"], c, d.result, m.deliveries, d.time, d.time_left(), m.jam_seconds,
				m.avg_delivery_time(), m.urgent_deliveries, m.min_patience_ratio, d.grid.player_built.size(),
				m.score(), str(d.goals.status)])
	quit()
