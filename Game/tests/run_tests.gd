extends SceneTree

# Headless tests. Run with:
#   godot --no-window --path . -s tests/run_tests.gd

const C = preload("res://sim/constants.gd")
const Sim = preload("res://sim/sim.gd")
const Vehicle = preload("res://sim/vehicle.gd")
const Intersection = preload("res://sim/intersection.gd")
const LevelsScript = preload("res://autoload/levels.gd")

var failed = 0
var passed = 0


func _init() -> void:
	print("=== GridFlow tests ===")
	test_pathfinding()
	test_capacity_jam()
	test_light_modes()
	test_gridlock_lose()
	test_patience_lose()
	test_determinism()
	test_level_validity()
	test_performance()
	test_no_manual_control()
	test_offline()
	test_strings()
	print("passed: %d, failed: %d" % [passed, failed])
	if failed > 0:
		print("TESTS FAILED")
		quit(1)
	else:
		print("TESTS PASSED")
		quit()


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		print("[ OK ] " + name + ("  (" + detail + ")" if detail != "" else ""))
	else:
		failed += 1
		print("[FAIL] " + name + ("  (" + detail + ")" if detail != "" else ""))


func base_level() -> Dictionary:
	return {
		"id": 99, "name": "", "time": 600, "goal": 0, "mode": "score", "seed": 5,
		"factories": [], "warehouses": [], "water": [], "obstacles": [], "roads": [],
		"inventory": {"road": 400, "light": 20, "sorter": 20, "bridge": 20},
		"tutorial": false, "solution": [],
	}


func make_sim(lv: Dictionary):
	var sim = Sim.new()
	sim.load_level(lv)
	return sim


func run(sim, seconds: float) -> void:
	var n = int(round(seconds / C.STEP))
	for _i in range(n):
		sim.step(C.STEP)


func line(sim, from: Vector2, to: Vector2) -> void:
	sim.apply_action({"type": "road_line", "from": from, "to": to})


# 1 ---------------------------------------------------------------------------
func test_pathfinding() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(2, 7), "color": C.CargoColor.BLUE, "interval": 2.0}]
	lv["warehouses"] = [{"cell": Vector2(10, 7), "color": C.CargoColor.BLUE}]
	var sim = make_sim(lv)
	line(sim, Vector2(3, 7), Vector2(9, 7))
	run(sim, 20.0)
	check("1a pathfinding: straight road delivers", sim.metrics.deliveries >= 5,
			"deliveries=%d" % sim.metrics.deliveries)

	# Two routes around a block; a sorter at the fork picks one per color.
	lv = base_level()
	lv["factories"] = [{"cell": Vector2(2, 7), "color": C.CargoColor.BLUE, "interval": 2.0}]
	lv["warehouses"] = [{"cell": Vector2(12, 7), "color": C.CargoColor.BLUE}]
	sim = make_sim(lv)
	line(sim, Vector2(3, 7), Vector2(4, 7))
	line(sim, Vector2(4, 6), Vector2(4, 5))
	line(sim, Vector2(5, 5), Vector2(10, 5))
	line(sim, Vector2(10, 6), Vector2(10, 7))
	line(sim, Vector2(4, 8), Vector2(4, 9))
	line(sim, Vector2(5, 9), Vector2(10, 9))
	sim.build_road(Vector2(10, 8))
	sim.build_road(Vector2(11, 7))
	var fork = Vector2(4, 7)
	var ok = sim.place_sorter(fork) != null
	sim.configure_sorter(fork, {C.CargoColor.BLUE: Vector2(0, -1)})
	sim.pathing.rebuild(sim.grid)
	var up = sim.pathing.find_path(C.CargoColor.BLUE, Vector2(2, 7), C.CargoColor.BLUE, sim.warehouses)
	sim.configure_sorter(fork, {C.CargoColor.BLUE: Vector2(0, 1)})
	sim.pathing.rebuild(sim.grid)
	var down = sim.pathing.find_path(C.CargoColor.BLUE, Vector2(2, 7), C.CargoColor.BLUE, sim.warehouses)
	ok = ok and up.has(Vector2(4, 6)) and not up.has(Vector2(4, 8))
	ok = ok and down.has(Vector2(4, 8)) and not down.has(Vector2(4, 6))
	run(sim, 20.0)
	check("1b pathfinding: sorter changes the route", ok and sim.metrics.deliveries > 0,
			"up=%d down=%d deliveries=%d" % [up.size(), down.size(), sim.metrics.deliveries])


# 2 ---------------------------------------------------------------------------
func test_capacity_jam() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(1, 7), "color": C.CargoColor.BLUE, "interval": 1.0}]
	lv["warehouses"] = [{"cell": Vector2(12, 7), "color": C.CargoColor.BLUE}]
	var sim = make_sim(lv)
	line(sim, Vector2(2, 7), Vector2(11, 7))
	sim.build_road(Vector2(8, 6))
	sim.build_road(Vector2(8, 8))
	var l = sim.place_light(Vector2(8, 7))
	l.period = 100000.0
	l.green_axis = 1             # red for the horizontal road, forever
	var first_wait = {}
	for _i in range(int(20.0 / C.STEP)):
		sim.step(C.STEP)
		for v in sim.vehicles:
			if v.state == Vehicle.S.WAITING and not first_wait.has(v.cell):
				first_wait[v.cell] = sim.time
	var ok = true
	var prev = -1.0
	for x in [7, 6, 5, 4, 3]:
		var cell = Vector2(x, 7)
		if not first_wait.has(cell) or first_wait[cell] <= prev:
			ok = false
			break
		prev = first_wait[cell]
	check("2 capacity jam: queue grows backward tile by tile", ok and sim.metrics.deliveries == 0,
			"queue tiles=%d" % first_wait.size())


# 3 ---------------------------------------------------------------------------
func tick_light(l, seconds: float) -> void:
	for _i in range(int(round(seconds / C.STEP))):
		l.tick(C.STEP)


func test_light_modes() -> void:
	var l = Intersection.new()
	l.mode = C.LightMode.TIMER
	l.period = 3.0
	tick_light(l, 2.8)
	var ok = l.phase == Intersection.Phase.GREEN and l.green_axis == 0
	tick_light(l, 0.4)
	ok = ok and l.phase == Intersection.Phase.YELLOW
	tick_light(l, 1.0 + 0.5 + 0.1)
	ok = ok and l.phase == Intersection.Phase.GREEN and l.green_axis == 1
	check("3a light: timer switches on its period", ok)

	l = Intersection.new()
	l.mode = C.LightMode.SENSOR
	l.threshold = 2
	l.waiting = [1, 2]
	tick_light(l, 6.0)
	ok = l.green_axis == 0 and l.phase == Intersection.Phase.GREEN
	l.waiting = [1, 3]
	tick_light(l, 0.1)
	ok = ok and l.phase == Intersection.Phase.YELLOW
	tick_light(l, 1.6)
	ok = ok and l.green_axis == 1
	check("3b light: sensor switches when the other axis exceeds the threshold", ok)

	l = Intersection.new()
	l.mode = C.LightMode.PRIORITY
	l.threshold = 5
	l.waiting = [2, 1]
	tick_light(l, 6.0)
	ok = l.green_axis == 0
	l.urgent_waiting = [false, true]
	tick_light(l, 0.1)
	ok = ok and l.green_axis == 1 and l.phase == Intersection.Phase.GREEN
	check("3c light: priority switches for an urgent truck", ok)


# 4 ---------------------------------------------------------------------------
func test_gridlock_lose() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(1, 7), "color": C.CargoColor.BLUE, "interval": 0.5}]
	lv["warehouses"] = [{"cell": Vector2(9, 7), "color": C.CargoColor.BLUE}]
	var sim = make_sim(lv)
	line(sim, Vector2(2, 7), Vector2(8, 7))
	sim.build_road(Vector2(6, 6))
	sim.build_road(Vector2(6, 8))
	var l = sim.place_light(Vector2(6, 7))
	l.period = 100000.0
	l.green_axis = 1
	run(sim, 29.0)
	var ok = sim.finished and sim.result == "lose" and sim.lose_reason == "gridlock"
	check("4 gridlock: a closed network loses after 15 s without movement",
			ok and sim.time >= C.GRIDLOCK_SECONDS and sim.still_time >= C.GRIDLOCK_SECONDS - 0.01,
			"t=%.1f reason=%s" % [sim.time, sim.lose_reason])


# 5 ---------------------------------------------------------------------------
func test_patience_lose() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(1, 7), "color": C.CargoColor.BLUE, "interval": 2.0}]
	lv["warehouses"] = [{"cell": Vector2(9, 7), "color": C.CargoColor.BLUE}]
	var sim = make_sim(lv)
	run(sim, 40.0)
	check("5 patience: a warehouse with no route loses",
			sim.finished and sim.lose_reason == "patience" and abs(sim.time - C.WAREHOUSE_PATIENCE_MAX) < 0.2,
			"t=%.1f" % sim.time)


# 6 ---------------------------------------------------------------------------
func run_fixed(lv: Dictionary, steps: int) -> Array:
	var sim = make_sim(lv)
	sim.apply_solution()
	for _i in range(steps):
		sim.step(C.STEP)
	var sum = Vector2()
	for v in sim.vehicles:
		sum += v.pos
	return [sim.metrics.deliveries, sim.metrics.score(), sim.vehicles.size(), sum]


func test_determinism() -> void:
	var levels = LevelsScript.new()
	var lv = levels.LEVELS[1]
	var a = run_fixed(lv, 3600)
	var b = run_fixed(lv, 3600)
	levels.free()
	check("6 determinism: same seed and actions give the same result", a == b and a[0] > 0,
			"deliveries=%d score=%d" % [a[0], a[1]])


# 7 ---------------------------------------------------------------------------
func test_level_validity() -> void:
	var levels = LevelsScript.new()
	for lv in levels.LEVELS:
		var sim = make_sim(lv)
		var built = sim.apply_solution()
		while not sim.finished:
			sim.step(C.STEP)
		var routes = true
		for f in sim.factories:
			if not sim.has_route(f):
				routes = false
		var ok = built and routes and sim.pending_events.empty()
		if lv["mode"] == "goal":
			ok = ok and sim.result == "win"
		else:
			ok = ok and sim.result == "finished" and sim.metrics.deliveries >= 40
		check("7 level %d valid with its solution" % lv["id"], ok,
				"built=%s routes=%s result=%s %s t=%.0f deliveries=%d jam=%.1f score=%d stars=%d" % [
				built, routes, sim.result, sim.lose_reason, sim.time, sim.metrics.deliveries,
				sim.metrics.jam_seconds, sim.metrics.score(), sim.metrics.stars(sim.won())])
	levels.free()


# 8 ---------------------------------------------------------------------------
func test_performance() -> void:
	var lv = base_level()
	var rows = [1, 3, 5, 7, 9, 11, 13]
	for i in range(rows.size()):
		var y = rows[i]
		var color = C.CargoColor.BLUE if i % 2 == 0 else C.CargoColor.RED
		lv["factories"].append({"cell": Vector2(0, y), "color": color, "interval": 0.4,
				"urgent_every": 5})
	lv["warehouses"] = [{"cell": Vector2(31, 1), "color": C.CargoColor.RED},
			{"cell": Vector2(31, 13), "color": C.CargoColor.BLUE}]
	var sim = make_sim(lv)
	for y in rows:
		line(sim, Vector2(1, y), Vector2(30, y))
	for x in [6, 14, 22, 30]:
		line(sim, Vector2(x, 1), Vector2(x, 13))
	for cell in [Vector2(14, 5), Vector2(14, 9), Vector2(22, 7), Vector2(30, 3), Vector2(30, 11)]:
		var l = sim.place_light(cell)
		if l != null:
			l.mode = C.LightMode.SENSOR
	var steps = int(60.0 / C.STEP)
	var max_v = 0
	var sum_v = 0
	var t0 = OS.get_ticks_usec()
	for _i in range(steps):
		sim.finished = false     # keep stepping even if a lose rule fires
		for w in sim.warehouses:
			w.patience = C.WAREHOUSE_PATIENCE_MAX
		sim.still_time = 0.0
		sim.step(C.STEP)
		max_v = int(max(max_v, sim.vehicles.size()))
		sum_v += sim.vehicles.size()
	var avg_ms = float(OS.get_ticks_usec() - t0) / steps / 1000.0
	check("8 performance: average step under 2 ms with 120 vehicles",
			avg_ms < 2.0 and max_v >= C.MAX_VEHICLES,
			"avg step=%.3f ms, max vehicles=%d, avg vehicles=%d" % [avg_ms, max_v, sum_v / steps])


# static checks ---------------------------------------------------------------
func list_files(dir_path: String, ext: String, out: Array) -> void:
	var dir = Directory.new()
	if dir.open(dir_path) != OK:
		return
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		var full = dir_path + "/" + name if dir_path != "res://" else dir_path + name
		if dir.current_is_dir():
			list_files(full, ext, out)
		elif name.ends_with(ext):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func read_lines(path: String) -> Array:
	var f = File.new()
	if f.open(path, File.READ) != OK:
		return []
	var lines = f.get_as_text().split("\n")
	f.close()
	return Array(lines)


func strip_comment(s: String) -> String:
	var in_str = false
	for i in range(s.length()):
		var ch = s[i]
		if ch == "\"":
			in_str = not in_str
		elif ch == "#" and not in_str:
			return s.substr(0, i)
	return s


# 9 ---------------------------------------------------------------------------
func assigns_field(s: String, field: String) -> bool:
	# True if the line assigns to `.field` (=, +=, -=, *=, /=), but not if it compares (==).
	var key = "." + field
	var at = s.find(key)
	while at != -1:
		var j = at + key.length()
		var next = s[j] if j < s.length() else ""
		var is_word = next != "" and (next == "_" or (next >= "a" and next <= "z") or (next >= "A" and next <= "Z") \
				or (next >= "0" and next <= "9"))
		if not is_word:
			while j < s.length() and s[j] == " ":
				j += 1
			var rest = s.substr(j, 2)
			if rest.length() > 0 and rest[0] == "=" and rest != "==":
				return true
			if rest in ["+=", "-=", "*=", "/="]:
				return true
		at = s.find(key, at + 1)
	return false


func test_no_manual_control() -> void:
	# The view and UI may read vehicles but must never change, move or remove them.
	var files = []
	list_files("res://view", ".gd", files)
	list_files("res://ui", ".gd", files)
	var fields = ["path", "state", "pos", "progress", "idx", "speed", "wait_time", "unload_timer",
			"from_cell", "reserved", "done", "dir", "dir_prev", "urgent", "repath_timer"]
	var calls = ["vehicles.erase", "vehicles.remove", "vehicles.clear", "vehicles.pop", "vehicles.append",
			"vehicles.insert", "vehicles.resize", "vehicles =", "_drop_vehicle", "spawn_vehicle", ".deliver(",
			"_repath", "v.tick(", ".path.", "try_enter", ".leave("]
	var list_edits = [".erase(", ".append(", ".clear(", ".remove(", ".push_back(", ".pop_back(", "] ="]
	var hits = []
	for path in files:
		var n = 0
		for raw in read_lines(path):
			n += 1
			var s = strip_comment(raw)
			for f in fields:
				if assigns_field(s, f):
					hits.append("%s:%d assigns .%s" % [path, n, f])
			for p in calls:
				if s.find(p) != -1 and s.find("vehicles ==") == -1:
					hits.append("%s:%d %s" % [path, n, p])
			if s.find("occupants") != -1:
				for p in list_edits:
					if s.find(p) != -1:
						hits.append("%s:%d edits occupants" % [path, n])
	for h in hits:
		print("       " + h)
	check("9 no manual control: view and UI never change a vehicle", hits.empty() and files.size() > 0,
			"%d files scanned" % files.size())


# 10 --------------------------------------------------------------------------
func test_offline() -> void:
	var files = []
	list_files("res://", ".gd", files)
	list_files("res://", ".tscn", files)
	var banned = ["HTTP" + "Request", "HTTP" + "Client", "StreamPeer" + "TCP", "PacketPeer" + "UDP",
			"WebSocket" + "Client", "WebSocket" + "Server", "NetworkedMultiplayer" + "ENet",
			"OS.shell" + "_open", "TCP_" + "Server", "UP" + "NP"]
	var hits = []
	for path in files:
		var n = 0
		for raw in read_lines(path):
			n += 1
			for b in banned:
				if raw.find(b) != -1:
					hits.append("%s:%d %s" % [path, n, b])
	for h in hits:
		print("       " + h)
	check("10 offline: no network classes anywhere", hits.empty() and files.size() > 10,
			"%d files scanned" % files.size())


# 11 --------------------------------------------------------------------------
func has_latin(s: String) -> bool:
	for i in range(s.length()):
		var code = s.ord_at(i)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			return true
	return false


func string_literals(s: String) -> Array:
	var out = []
	var cur = ""
	var in_str = false
	var i = 0
	while i < s.length():
		var ch = s[i]
		if in_str:
			if ch == "\\":
				i += 2
				continue
			if ch == "\"":
				in_str = false
				out.append(cur)
			else:
				cur += ch
		elif ch == "\"":
			in_str = true
			cur = ""
		i += 1
	return out


func has_cyrillic(s: String) -> bool:
	for i in range(s.length()):
		var code = s.ord_at(i)
		if code >= 0x400 and code <= 0x4FF:
			return true
	return false


func literal_after(s: String, at: int) -> String:
	# The string literal that starts right after position `at` (spaces skipped), or "".
	var j = at
	while j < s.length() and s[j] == " ":
		j += 1
	if j >= s.length() or s[j] != "\"":
		return ""
	var lits = string_literals(s.substr(j, s.length() - j))
	return lits[0] if lits.size() > 0 else "?"


func test_strings() -> void:
	# Player-facing text must come from autoload/strings.gd. So outside that file:
	#  - no text assignment or text-drawing call may take a literal with Latin letters,
	#  - no script in view/ or ui/ may contain a Cyrillic literal at all.
	var files = []
	list_files("res://view", ".gd", files)
	list_files("res://ui", ".gd", files)
	list_files("res://autoload", ".gd", files)
	var direct = ["text = ", "text=", "set_text(", "hint_tooltip = ", "window_title = ", "toast(",
			"button(", "label(", "Button.new(", "Label.new(", "add_item("]
	var draw_calls = ["draw_string(", "centered(", "left("]
	var hits = []
	for path in files:
		if path.ends_with("strings.gd"):
			continue
		var in_ui = path.begins_with("res://view") or path.begins_with("res://ui")
		var n = 0
		for raw in read_lines(path):
			n += 1
			var s = strip_comment(raw)
			if in_ui:
				for lit in string_literals(s):
					if has_cyrillic(lit):
						hits.append("%s:%d Cyrillic literal \"%s\"" % [path, n, lit])
			for key in direct:
				var at = s.find(key)
				while at != -1:
					var lit = literal_after(s, at + key.length())
					if has_latin(lit):
						hits.append("%s:%d \"%s\"" % [path, n, lit])
					at = s.find(key, at + 1)
			for key in draw_calls:
				if s.find(key) == -1:
					continue
				var rest = s
				var q = rest.find("\"")
				while q != -1:
					var lit = literal_after(rest, q)
					var after = q + lit.length() + 2
					var is_key = after < rest.length() and rest[after] == "]"
					if has_latin(lit) and not is_key:
						hits.append("%s:%d \"%s\"" % [path, n, lit])
					q = rest.find("\"", after)
	for h in hits:
		print("       " + h)
	var levels = LevelsScript.new()
	var names_ok = true
	for lv in levels.LEVELS:
		if has_latin(lv["name"]):
			names_ok = false
	levels.free()
	check("11 strings: UI text is Russian and lives in strings.gd", hits.empty() and names_ok,
			"%d files scanned" % files.size())
