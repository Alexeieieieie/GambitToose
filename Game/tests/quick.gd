extends SceneTree


const Sim = preload("res://sim/sim.gd")
const C = preload("res://sim/constants.gd")
const LevelsScript = preload("res://autoload/levels.gd")

var bad = 0


func ck(n: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + n)
	if not ok:
		bad += 1


func run(lv: Dictionary, use_sol: bool) -> Object:
	var s = Sim.new()
	s.load_level(lv)
	if use_sol:
		for a in lv["solution"]:
			s.apply_action(a)
	var i = 0
	while not s.finished and i < 40000:
		s.step(C.STEP)
		i += 1
	return s


func _initialize() -> void:
	var lvs = LevelsScript.new().LEVELS
	ck("levels exist", lvs.size() > 0)
	for lv in lvs:
		var s = run(lv, true)
		ck("level %d solution finishes" % lv["id"], s.finished)
		ck("level %d solution delivers" % lv["id"], s.metrics.deliveries > 0)
	var a = run(lvs[0], true)
	var b = run(lvs[0], true)
	ck("deterministic", a.metrics.deliveries == b.metrics.deliveries and a.time == b.time)
	var e = run(lvs[0], false)
	ck("level 1 without player actions still finishes", e.finished)
	print("QUICK DONE failures=%d" % bad)
	quit(1 if bad else 0)
