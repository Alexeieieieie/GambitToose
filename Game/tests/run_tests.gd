extends SceneTree

# Headless tests. Run with:
#   godot --no-window --path . -s tests/run_tests.gd

const C = preload("res://sim/constants.gd")
const Sim = preload("res://sim/sim.gd")
const Vehicle = preload("res://sim/vehicle.gd")
const Intersection = preload("res://sim/intersection.gd")
const LevelsScript = preload("res://autoload/levels.gd")
const SaveDataScript = preload("res://autoload/save_data.gd")
const TutorialData = preload("res://tutorial/tutorial_data.gd")
const TutorialManager = preload("res://tutorial/tutorial_manager.gd")
const TutorialSolver = preload("res://tutorial/tutorial_solver.gd")
const Director = preload("res://audio/audio_director.gd")
const Goals = preload("res://sim/goals.gd")

# Names the tutorial may highlight: every one is registered by the HUD or a panel.
const UI_NAMES = ["tool_road", "tool_bridge", "tool_light", "tool_sorter", "tool_erase", "btn_pause",
		"btn_speed_1", "btn_speed_2", "btn_speed_4", "btn_heatmap", "btn_help", "deliveries_bar",
		"light_mode_timer", "light_mode_sensor", "light_mode_priority", "light_apply", "sorter_apply"]

var failed = 0
var passed = 0


func _initialize() -> void:
	# Not _init(): the autoload singletons (Strings, Sfx) exist from here on.
	print("=== GambitToose tests ===")
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
	test_strings_parity()
	test_missing_keys()
	test_no_hardcoded_text()
	test_first_run()
	test_lessons_solvable()
	test_no_soft_locks()
	test_tutorial_cannot_be_lost()
	test_audio_files()
	test_audio_director()
	test_registry()
	test_audio_does_not_change_sim()
	test_goal_types()
	test_goal_level_data()
	test_goal_calibration()
	test_goals_read_only()
	test_goal_save()
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
				sim.metrics.jam_seconds, sim.metrics.score(), sim.goals.stars()])
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
	list_files("res://tutorial", ".gd", files)
	list_files("res://audio", ".gd", files)
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


func has_letter(s: String) -> bool:
	return has_latin(s) or has_cyrillic(s)


func literal_after(s: String, at: int) -> String:
	# The string literal that starts right after position `at` (spaces skipped), or "".
	var j = at
	while j < s.length() and s[j] == " ":
		j += 1
	if j >= s.length() or s[j] != "\"":
		return ""
	var lits = string_literals(s.substr(j, s.length() - j))
	return lits[0] if lits.size() > 0 else "?"


func strip_key_calls(s: String) -> String:
	# Removes Strings.t("KEY") and Strings.tf("KEY" so the key names are not mistaken for UI text.
	var out = s
	for head in ["Strings.t(\"", "Strings.tf(\"", "UiRegistry.register(\""]:
		var at = out.find(head)
		while at != -1:
			var end = out.find("\"", at + head.length())
			if end == -1:
				break
			out = out.substr(0, at) + "KEYCALL(" + out.substr(end + 1, out.length() - end - 1)
			at = out.find(head)
	return out


func strings_tables() -> Dictionary:
	var node = root.get_node("Strings")
	return node.get_script().get_script_constant_map()


func format_slots(s: String) -> Array:
	var out = []
	var i = 0
	while i < s.length():
		if s[i] == "%" and i + 1 < s.length() and s[i + 1] == "%":
			i += 1                   # a literal percent sign is not a slot
		elif s[i] == "%":
			var j = i + 1
			while j < s.length() and not (s[j] in ["s", "d", "f"]):
				j += 1
			out.append(s.substr(i, j - i + 1))
			i = j
		i += 1
	return out


# 12 --------------------------------------------------------------------------
func test_strings_parity() -> void:
	var t = strings_tables()
	var en = t["EN"]
	var ru = t["RU"]
	var problems = []
	for key in en.keys():
		if not ru.has(key):
			problems.append("missing in RU: " + key)
		elif str(en[key]) == "" or str(ru[key]) == "":
			problems.append("empty: " + key)
		elif format_slots(en[key]) != format_slots(ru[key]):
			problems.append("placeholders differ: " + key)
	for key in ru.keys():
		if not en.has(key):
			problems.append("missing in EN: " + key)
	for p in problems:
		print("       " + p)
	check("12 strings parity: EN and RU have the same keys and placeholders", problems.empty() and en.size() > 100,
			"%d keys" % en.size())
	# English mode must not contain Cyrillic anywhere.
	var leaked = []
	for key in en.keys():
		if has_cyrillic(en[key]):
			leaked.append(key)
	check("12b english table has no Cyrillic text", leaked.empty(), str(leaked))


# 13 --------------------------------------------------------------------------
func test_missing_keys() -> void:
	var en = strings_tables()["EN"]
	var files = []
	list_files("res://", ".gd", files)
	var missing = []
	var used = 0
	for path in files:
		if path.begins_with("res://tests"):
			continue
		var n = 0
		for raw in read_lines(path):
			n += 1
			var s = strip_comment(raw)
			for head in ["Strings.t(\"", "Strings.tf(\""]:
				var at = s.find(head)
				while at != -1:
					var start = at + head.length()
					var end = s.find("\"", start)
					var key = s.substr(start, end - start)
					used += 1
					if not en.has(key):
						missing.append("%s:%d %s" % [path, n, key])
					at = s.find(head, end)
			# Keys named in data tables (help sections, lesson text) by their prefix.
			for lit in string_literals(s):
				if lit.length() > 4 and (lit.begins_with("HELP_") or lit.begins_with("TUT_") or lit.begins_with("TOAST_")) \
						and lit == lit.to_upper() and not en.has(lit):
					missing.append("%s:%d %s" % [path, n, lit])
	# Every key the lessons refer to.
	for lesson in TutorialData.get_lessons():
		var keys = [lesson["title_key"], lesson["level"]["name_key"]]
		for step in lesson["steps"]:
			keys.append(step["text_key"])
			if step.has("hint_key"):
				keys.append(step["hint_key"])
			if step.has("button_key"):
				keys.append(step["button_key"])
			for item in step.get("checklist", []):
				keys.append(item["key"])
		for k in keys:
			if not en.has(k):
				missing.append("lesson %s: %s" % [lesson["id"], k])
	for lv in LevelsScript.new().LEVELS:
		if not en.has(lv["name_key"]):
			missing.append("level name " + lv["name_key"])
	for m in missing:
		print("       " + m)
	check("13 missing keys: every Strings.t key exists in EN", missing.empty() and used > 80, "%d lookups checked" % used)


# 14 --------------------------------------------------------------------------
func test_no_hardcoded_text() -> void:
	# Player-facing text must come from autoload/strings.gd. Outside that file:
	#  - no text assignment or text-drawing call may take a literal with letters,
	#  - no script in view/, ui/ or tutorial/ may contain a Cyrillic literal at all.
	var files = []
	list_files("res://view", ".gd", files)
	list_files("res://ui", ".gd", files)
	list_files("res://tutorial", ".gd", files)
	list_files("res://autoload", ".gd", files)
	var direct = ["text = ", "text=", "set_text(", "hint_tooltip = ", "window_title = ", "set_window_title(", "toast(",
			"button(", "label(", "Button.new(", "Label.new(", "add_item("]
	var draw_calls = ["draw_string(", "centered(", "left("]
	var hits = []
	for path in files:
		if path.ends_with("strings.gd") or path.ends_with("tutorial_data.gd"):
			continue
		var in_ui = not path.begins_with("res://autoload")
		var n = 0
		for raw in read_lines(path):
			n += 1
			var s = strip_key_calls(strip_comment(raw))
			if in_ui:
				for lit in string_literals(s):
					if has_cyrillic(lit):
						hits.append("%s:%d Cyrillic literal \"%s\"" % [path, n, lit])
			for key in direct:
				var at = s.find(key)
				while at != -1:
					var lit = literal_after(s, at + key.length())
					if has_letter(lit):
						hits.append("%s:%d \"%s\"" % [path, n, lit])
					at = s.find(key, at + 1)
			for key in draw_calls:
				if s.find(key) == -1:
					continue
				var q = s.find("\"")
				while q != -1:
					var lit = literal_after(s, q)
					var after = q + lit.length() + 2
					var is_dict_key = after < s.length() and s[after] == "]"
					if has_letter(lit) and not is_dict_key:
						hits.append("%s:%d \"%s\"" % [path, n, lit])
					q = s.find("\"", after)
	for h in hits:
		print("       " + h)
	check("14 no hardcoded UI text outside strings.gd", hits.empty(), "%d files scanned" % files.size())


# 15 --------------------------------------------------------------------------
func test_first_run() -> void:
	var path = "user://test_save.cfg"
	var dir = Directory.new()
	if dir.file_exists(path):
		dir.remove(path)
	var a = SaveDataScript.new()
	a.path = path
	a.load_data()
	var fresh = a.is_first_run()
	a.finish_tutorial(false)
	var b = SaveDataScript.new()
	b.path = path
	var loaded = b.load_data()
	var after = not b.is_first_run() and not b.tutorial_skipped
	b.save_result(7, 1234, 5)
	var c = SaveDataScript.new()
	c.path = path
	c.load_data()
	var kept = c.get_best(7)["score"] == 1234 and c.get_stars(7) == 2 and c.get_mask(7) == 5 and not c.is_first_run()
	check("15a first run: fresh install is a first run, then not", fresh and loaded and after and kept)
	# A corrupt file must not crash and counts as a fresh install.
	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string("this is } not { a valid = config [[[ file\n=== ]]]")
	f.close()
	var d = SaveDataScript.new()
	d.path = path
	d.load_data()
	var corrupt_ok = d.is_first_run() and d.language == "en"
	f.open(path, File.WRITE)
	f.store_string("[meta]\ntutorial_done=\"yes\"\nlanguage=42\nsound_on=7\n[score]\nabc=5\n")
	f.close()
	var e = SaveDataScript.new()
	e.path = path
	e.load_data()
	var types_ok = e.is_first_run() and e.language == "en" and e.sound_on and e.best.empty()
	var g = SaveDataScript.new()
	g.path = "user://does_not_exist_%d.cfg" % OS.get_ticks_usec()
	var missing_ok = g.load_data() == false and g.is_first_run()
	check("15b first run: corrupt or missing save counts as a fresh install", corrupt_ok and types_ok and missing_ok)
	d.path = path
	d.delete_save()
	for node in [a, b, c, d, e, g]:
		node.free()


# 16 --------------------------------------------------------------------------
func test_lessons_solvable() -> void:
	var lessons = TutorialData.get_lessons()
	check("16a lessons: 6 lessons and a final test", lessons.size() == 7 and lessons[6].get("final", false))
	for i in range(lessons.size()):
		var lesson = lessons[i]
		var sim = make_sim(lesson["level"])
		var mgr = TutorialManager.new()
		mgr.start(lesson, sim, i + 1, 6)
		var err = TutorialSolver.run(sim, mgr, lesson)
		var ok = err == "" and mgr.done
		if lesson.get("final", false):
			ok = ok and sim.result == "win"
		check("16 lesson %s: solution completes it" % lesson["id"], ok,
				err if err != "" else "t=%.0f s, deliveries=%d" % [sim.time, sim.metrics.deliveries])


# 17 --------------------------------------------------------------------------
func test_no_soft_locks() -> void:
	var problems = []
	for lesson in TutorialData.get_lessons():
		var mgr = TutorialManager.new()
		for step in lesson["steps"]:
			var id = step["id"]
			if not step.has("wait") or not step["wait"].has("event"):
				problems.append(id + ": no wait condition")
				continue
			var e = step["wait"]["event"]
			if not (e in TutorialManager.SUPPORTED):
				problems.append(id + ": unsupported event " + e)
			if e != "continue" and not step.has("hint_key"):
				problems.append(id + ": action step without a hint")
			for name in step.get("highlight_ui", []):
				if not (name in UI_NAMES):
					problems.append(id + ": unknown ui name " + name)
			for item in step.get("checklist", []):
				if not (item["cond"]["event"] in TutorialManager.SUPPORTED):
					problems.append(id + ": unsupported checklist event")
			if step.get("needs_panel", "") != "" and not (step["needs_panel"] in ["light", "sorter"]):
				problems.append(id + ": bad needs_panel")
		# Lessons and tools must be consistent with the level.
		var allowed = lesson["level"].get("allowed_tools", [])
		if allowed.empty():
			problems.append(lesson["id"] + ": no allowed_tools")
	for p in problems:
		print("       " + p)
	check("17 no soft locks: every step has a wait, a hint and known highlights", problems.empty())
	# The hint and skip timers exist so a stuck player is never trapped.
	var lesson = TutorialData.get_lesson(0)
	var sim = make_sim(lesson["level"])
	var mgr = TutorialManager.new()
	mgr.start(lesson, sim, 1, 6)
	mgr.notify("continue")
	mgr.notify("continue")                       # now on the road step
	var before = mgr.hint_available() or mgr.skip_available()
	mgr.tick(TutorialManager.HINT_AFTER + 0.1)
	var hint_ok = mgr.hint_available() and not mgr.skip_available()
	mgr.tick(TutorialManager.SKIP_AFTER)
	var skip_ok = mgr.skip_available()
	var idx = mgr.idx
	mgr.skip_step()
	check("17b hint after 15 s, skip step after 30 s, skip really advances", not before and hint_ok and skip_ok and mgr.idx == idx + 1)


# 18 --------------------------------------------------------------------------
func test_tutorial_cannot_be_lost() -> void:
	var lessons = TutorialData.get_lessons()
	var all_ok = true
	var details = ""
	for i in range(6):
		var lesson = lessons[i]
		var sim = make_sim(lesson["level"])
		# A deliberately bad network: whatever is prebuilt, with any lights stuck on red.
		for l in sim.lights:
			l.period = 100000.0
			l.green_axis = 1
		if lesson["id"] in ["l3", "l5"]:
			sim.apply_action({"type": "light", "cell": Vector2(15, 7), "mode": C.LightMode.TIMER})
			sim.lights[0].period = 100000.0
			sim.lights[0].green_axis = 1
		if lesson["id"] == "l1":
			sim.apply_action({"type": "road_line", "from": Vector2(5, 7), "to": Vector2(10, 7)})  # a road to nowhere
		run(sim, 60.0)
		if sim.finished or sim.result != "":
			all_ok = false
			details += " %s:%s/%s" % [lesson["id"], sim.result, sim.lose_reason]
	check("18 tutorial cannot be lost: 60 s of a bad network in lessons 1 to 6", all_ok, details)
	# The final test, in contrast, can be lost.
	var sim2 = make_sim(lessons[6]["level"])
	run(sim2, 40.0)
	check("18b the final test can be lost", sim2.finished and sim2.result == "lose", sim2.lose_reason)


# 19 --------------------------------------------------------------------------
func audio_dir_files() -> Array:
	var out = []
	var dir = Directory.new()
	if dir.open("res://audio") != OK:
		return out
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		if name.ends_with(".wav"):
			out.append(name.get_basename())
		name = dir.get_next()
	dir.list_dir_end()
	return out


func test_audio_files() -> void:
	var have = audio_dir_files()
	var missing = []
	var total = 0
	for n in Director.all_files():
		if not have.has(n):
			missing.append(n)
		else:
			var f = File.new()
			f.open("res://audio/%s.wav" % n, File.READ)
			total += f.get_len()
			f.close()
	var output = []
	var code = OS.execute("python3", ["-I", ProjectSettings.globalize_path("res://tools/check_audio.py")], true, output)
	var py_ok = code == 0 or code == -1       # -1: python is not installed here, so the script cannot run
	check("19 audio: every sound file exists, the total is small, check_audio.py passes",
			missing.empty() and total < 6 * 1048576 and py_ok,
			"missing=%s total=%d KB python exit=%d" % [str(missing), total / 1024, code])


# 20 --------------------------------------------------------------------------
func test_audio_director() -> void:
	var d = Director.new()
	for _i in range(7):
		d.on_event({"type": "deliver"})
		d.update(0.2)
	var files = []
	for r in d.take_requests():
		files.append(r["file"])
	check("20a streak: deliveries climb to note 4 and stay there",
			files == ["deliver_0", "deliver_1", "deliver_2", "deliver_3", "deliver_4", "deliver_4", "deliver_4"], str(files))
	d.on_event({"type": "deliver"})
	d.on_event({"type": "jam_start"})
	d.update(0.2)
	d.on_event({"type": "deliver"})
	d.update(0.2)
	files = []
	for r in d.take_requests():
		files.append(r["file"])
	check("20b streak: a jam resets it", files.size() == 3 and files[2] == "deliver_0" and files[0] == "jam_warn", str(files))
	d.on_event({"type": "deliver"})
	d.on_event({"type": "deliver"})
	d.update(0.2)
	d.take_requests()
	d.update(16.0)
	d.on_event({"type": "deliver"})
	d.update(0.2)
	var after_idle = d.take_requests()
	check("20c streak: 15 s without a delivery resets it", after_idle.size() == 1 and after_idle[0]["file"] == "deliver_0")

	# Merging: a burst of deliveries inside 150 ms plays one sound with the highest note.
	d = Director.new()
	for _i in range(4):
		d.on_event({"type": "deliver"})
		d.update(0.02)
	d.update(0.2)
	var burst = d.take_requests()
	check("20d merging: four deliveries within 150 ms play one sound, the highest note",
			burst.size() == 1 and burst[0]["file"] == "deliver_3", str(burst.size()))

	# Cooldowns and voices.
	d = Director.new()
	var first = d.request("place_road")
	var second = d.request("place_road")
	d.update(0.05)
	var third = d.request("place_road")
	check("20e cooldown: a sound does not repeat inside its cooldown", first and not second and third)
	d = Director.new()
	var accepted = 0
	for _i in range(5):
		if d.request("deliver"):
			accepted += 1
	check("20f voices: max_voices is respected", accepted == 3, "accepted=%d" % accepted)
	d = Director.new()
	d.on_event({"type": "jam_start"})
	var warn_first = d.take_requests().size() == 1
	d.update(1.0)
	d.on_event({"type": "jam_start"})
	var warn_second = d.take_requests().size() == 0     # at most one jam_warn per 5 s
	d.update(5.0)
	d.on_event({"type": "jam_start"})
	check("20g jam warning is limited to once per 5 s", warn_first and warn_second and d.take_requests().size() == 1)

	# Ducking and intensity.
	d = Director.new()
	d.duck(4.0, 1.0)
	var ducked = d.duck_offset() == -4.0
	d.update(1.1)
	check("20h ducking: lowers the music and returns to zero after its time", ducked and d.duck_offset() == 0.0)
	d = Director.new()
	var in_range = true
	var went_on = false
	for _i in range(20):
		d.set_intensity_target(1.0)
		in_range = in_range and d.intensity >= 0.0 and d.intensity <= 1.0
		went_on = went_on or d.tension_on
	var stays = true
	d.intensity = 0.45
	d.set_intensity_target(0.45)
	stays = d.tension_on                       # between 0.35 and 0.5: the layer does not flicker off
	for _i in range(20):
		d.set_intensity_target(0.0)
		in_range = in_range and d.intensity >= 0.0 and d.intensity <= 1.0
	check("20i intensity stays in 0..1; tension fades in above 0.5 and out below 0.35",
			in_range and went_on and stays and not d.tension_on)
	d = Director.new()
	check("20j melody layer starts after the first delivery",
			d.layer_targets()["melody"] == 0.0 and _after_delivery(d)["melody"] == 1.0)
	check("20k music pitch follows the speed", Director.music_pitch(1.0) == 1.0 and Director.music_pitch(2.0) == 1.04 \
			and Director.music_pitch(4.0) == 1.08)


func _after_delivery(d) -> Dictionary:
	d.on_event({"type": "deliver"})
	return d.layer_targets()


# 21 --------------------------------------------------------------------------
func test_registry() -> void:
	var problems = []
	for n in Director.MAPPED:
		if not Director.REGISTRY.has(n):
			problems.append("mapped but not in the registry: " + n)
	for n in Director.REGISTRY.keys():
		var e = Director.REGISTRY[n]
		for k in ["bus", "base_db", "priority", "cooldown_ms", "max_voices", "pitch_jitter", "dur"]:
			if not e.has(k):
				problems.append(n + " lacks " + k)
	var used = Director.all_files()
	var have = audio_dir_files()
	for n in used:
		if not have.has(n):
			problems.append("no file for " + n)
	for n in have:
		if not used.has(n):
			problems.append("file not used by the registry: " + n)
	for p in problems:
		print("       " + p)
	check("21 registry: every mapped sound is registered, has a file, and every file is used",
			problems.empty(), "%d files" % have.size())


func fingerprint(sim) -> Array:
	var sum = Vector2()
	for v in sim.vehicles:
		sum += v.pos
	return [sim.metrics.deliveries, sim.metrics.score(), sim.vehicles.size(), sum, sim.metrics.jam_seconds,
			sim.time, sim.result, sim.metrics.urgent_deliveries]


func run_level(lv: Dictionary, drain_into = null, goals_on: bool = true) -> Array:
	var sim = make_sim(lv)
	sim.goals_enabled = goals_on
	sim.apply_solution()
	var steps = 0
	while not sim.finished and steps < 9000:
		sim.step(C.STEP)
		steps += 1
		if drain_into != null:
			for ev in sim.events:
				drain_into.on_event(ev)
			sim.events = []
			drain_into.update(C.STEP, sim)
	return fingerprint(sim)


func test_audio_does_not_change_sim() -> void:
	var levels = LevelsScript.new()
	var lv = levels.LEVELS[1]
	var plain = run_level(lv)
	var with_audio = run_level(lv, Director.new())
	levels.free()
	check("22 new events and the audio director do not change the simulation", plain == with_audio,
			"deliveries=%d" % plain[0])


# 23 --------------------------------------------------------------------------
func goal_sim(goals: Array, mode: String = "goal"):
	var lv = base_level()
	lv["mode"] = mode
	lv["goal"] = 5
	lv["time"] = 100
	lv["star_goals"] = goals
	return make_sim(lv)


func status_of(goals: Array, setup_fn, won: bool, finalize: bool = true) -> Array:
	var sim = goal_sim(goals)
	sim.time = 60.0
	setup_fn.call_func(sim)
	sim.goals.tick(sim)
	if finalize:
		sim.goals.finalize(sim, won)
	return sim.goals.status


func test_goal_types() -> void:
	var P = Goals.Status.PENDING
	var D = Goals.Status.DONE
	var F = Goals.Status.FAILED
	var ok = true
	var detail = ""
	var cases = [
		# [goal def, setup callable name, won, expected status]
		[{"type": "complete"}, "noop", true, D],
		[{"type": "complete"}, "noop", false, F],
		[{"type": "time_left_min", "value": 30}, "noop", true, D],
		[{"type": "time_left_min", "value": 50}, "noop", true, F],
		[{"type": "time_left_min", "value": 30}, "noop", false, F],
		[{"type": "jam_seconds_max", "value": 5}, "jam3", true, D],
		[{"type": "jam_seconds_max", "value": 5}, "jam6", true, F],
		[{"type": "jam_seconds_max", "value": 5}, "jam3", false, F],
		[{"type": "avg_delivery_max", "value": 6}, "avg5", true, D],
		[{"type": "avg_delivery_max", "value": 4}, "avg5", true, F],
		[{"type": "avg_delivery_max", "value": 6}, "avg5", false, F],
		[{"type": "urgent_min", "value": 3}, "urgent3", false, D],
		[{"type": "urgent_min", "value": 4}, "urgent3", true, F],
		[{"type": "patience_min", "value": 40}, "pat50", true, D],
		[{"type": "patience_min", "value": 40}, "pat30", true, F],
		[{"type": "roads_max", "value": 5}, "roads5", true, D],
		[{"type": "roads_max", "value": 4}, "roads5", true, F],
		[{"type": "deliver_min", "value": 4}, "deliv5", false, D],
		[{"type": "deliver_min", "value": 6}, "deliv5", true, F],
		[{"type": "score_min", "value": 400}, "deliv5", false, D],
		[{"type": "score_min", "value": 900}, "deliv5", true, F],
	]
	for c in cases:
		var sim = goal_sim([c[0]])
		sim.time = 60.0
		_apply_setup(sim, c[1])
		sim.goals.tick(sim)
		sim.goals.finalize(sim, c[2])
		if sim.goals.status[0] != c[3]:
			ok = false
			detail += " %s/%s/%s got %d" % [c[0]["type"], c[1], str(c[2]), sim.goals.status[0]]
	check("23a goals: every type is pending, done or failed as defined", ok, detail)

	# Early behavior: live goals complete at once, early-fail goals fail at once, and nothing changes back.
	var sim2 = goal_sim([{"type": "urgent_min", "value": 2}, {"type": "jam_seconds_max", "value": 5},
			{"type": "patience_min", "value": 40}])
	sim2.metrics.urgent_deliveries = 2
	sim2.metrics.jam_seconds = 6.0
	sim2.metrics.min_patience_ratio = 0.2
	sim2.goals.tick(sim2)
	var early = sim2.goals.status == [D, F, F]
	var kinds = []
	for ev in sim2.events:
		kinds.append(ev["type"])
	sim2.metrics.urgent_deliveries = 0
	sim2.metrics.jam_seconds = 0.0
	sim2.metrics.min_patience_ratio = 1.0
	sim2.goals.tick(sim2)
	sim2.goals.finalize(sim2, true)
	check("23b goals: live goals finish at once, early-fail goals fail at once, never change back",
			early and sim2.goals.status == [D, F, F] and kinds.count("goal_reached") == 1 and kinds.count("goal_failed") == 2,
			str(kinds))
	var sim3 = goal_sim([{"type": "complete"}, {"type": "jam_seconds_max", "value": 5}, {"type": "urgent_min", "value": 9}])
	sim3.goals.finalize(sim3, true)
	check("23c goals: mask and star count", sim3.goals.earned_mask() == 3 and sim3.goals.stars() == 2
			and SaveDataScript.popcount(5) == 2)
	var empty = goal_sim([])
	empty.goals.finalize(empty, true)
	check("23d goals: a level without goals has no stars", empty.goals.stars() == 0 and empty.goals.count() == 0)


func _apply_setup(sim, name: String) -> void:
	if name == "jam3":
		sim.metrics.jam_seconds = 3.0
	elif name == "jam6":
		sim.metrics.jam_seconds = 6.0
	elif name == "avg5":
		sim.metrics.deliveries = 2
		sim.metrics.total_delivery_time = 10.0
	elif name == "urgent3":
		sim.metrics.urgent_deliveries = 3
	elif name == "pat50":
		sim.metrics.min_patience_ratio = 0.5
	elif name == "pat30":
		sim.metrics.min_patience_ratio = 0.3
	elif name == "roads5":
		for i in range(5):
			sim.grid.player_built[Vector2(i, 0)] = true
	elif name == "deliv5":
		sim.metrics.deliveries = 5
		sim.metrics.total_delivery_time = 50.0


func test_goal_level_data() -> void:
	var levels = LevelsScript.new()
	var t = strings_tables()
	var problems = []
	for lv in levels.LEVELS:
		var g = lv.get("star_goals", [])
		if g.size() != 3:
			problems.append("level %d has %d goals" % [lv["id"], g.size()])
			continue
		if g[0]["type"] != "complete":
			problems.append("level %d: first goal is not complete" % lv["id"])
		for goal in g:
			var type = goal["type"]
			if not Goals.TYPES.has(type):
				problems.append("unknown type " + type)
				continue
			if type != "complete" and not (goal.has("value") and goal["value"] > 0):
				problems.append("%s needs a positive value" % type)
			var keys = [Goals.text_key(type)]
			if type != "complete":
				keys.append(Goals.progress_key(type))
				keys.append(Goals.result_key(type))
			for k in keys:
				if not t["EN"].has(k) or not t["RU"].has(k):
					problems.append("missing text " + k)
	for lesson in TutorialData.get_lessons():
		if lesson["level"].has("star_goals"):
			problems.append("tutorial lesson has star goals")
	levels.free()
	for p in problems:
		print("       " + p)
	check("23e goal data: three goals per level, first is complete, valid types and values, texts exist",
			problems.empty())


func finish_run(lv: Dictionary, variant: String):
	var sim = make_sim(lv)
	for a in lv["solution"]:
		var act = a
		if variant == "baseline" and (a["type"] == "light" or a["type"] == "sorter"):
			continue
		if variant == "timer" and a["type"] == "light":
			act = a.duplicate()
			act["mode"] = C.LightMode.TIMER
		sim.apply_action(act)
	var steps = 0
	while not sim.finished and steps < 12000:
		sim.step(C.STEP)
		steps += 1
	return sim


func test_goal_calibration() -> void:
	var levels = LevelsScript.new()
	var all_three = true
	var careless_ok = true
	var detail = ""
	for lv in levels.LEVELS:
		var sol = finish_run(lv, "solution")
		var base = finish_run(lv, "baseline")
		var timer = finish_run(lv, "timer")
		if sol.goals.stars() != 3:
			all_three = false
		if timer.goals.stars() > 2:
			careless_ok = false
		detail += " L%d solution=%d roads-only=%d timer-lights=%d;" % [lv["id"], sol.goals.stars(), base.goals.stars(), timer.goals.stars()]
	levels.free()
	check("24a calibration: the intended solution earns three stars on every level", all_three, detail)
	check("24b calibration: a careless build (all lights on slow timers) earns at most two stars", careless_ok, detail)


func test_goals_read_only() -> void:
	var levels = LevelsScript.new()
	var ok = true
	for lv in levels.LEVELS:
		var a = run_level(lv, null, true)
		var b = run_level(lv, null, false)
		if a != b:
			ok = false
	levels.free()
	check("25 goals are read-only: results are identical with goals on and off", ok)


func test_goal_save() -> void:
	var path = "user://test_goals.cfg"
	var dir = Directory.new()
	if dir.file_exists(path):
		dir.remove(path)
	var a = SaveDataScript.new()
	a.path = path
	a.load_data()
	var first = a.save_result(1, 100, 1)
	var second = a.save_result(1, 50, 6)
	var third = a.save_result(1, 900, 2)
	var b = SaveDataScript.new()
	b.path = path
	b.load_data()
	check("26a save: goal masks are ORed, earned goals stay earned, new bits are reported",
			first == 1 and second == 6 and third == 0 and b.get_mask(1) == 7 and b.get_stars(1) == 3
			and b.get_best(1)["score"] == 900)
	a.set_volumes(50, 20, 70)
	var c = SaveDataScript.new()
	c.path = path
	c.load_data()
	check("26b save: volumes roundtrip, defaults are 100 / 60 / 90",
			c.vol_master == 50 and c.vol_music == 20 and c.vol_effects == 70
			and SaveDataScript.new().vol_master == 100 and SaveDataScript.new().vol_music == 60
			and SaveDataScript.new().vol_effects == 90)
	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string("[meta]\ntutorial_done=true\nvol_master=\"loud\"\nvol_music=500\n[score]\n1=500\n[stars]\n1=3\n[played]\n1=true\n[goals]\n2=\"x\"\n3=99\n")
	f.close()
	var d = SaveDataScript.new()
	d.path = path
	d.load_data()
	check("26c save: an old save (single stars value) migrates to empty masks, bad values never crash",
			d.get_stars(1) == 0 and d.get_best(1)["score"] == 500 and d.get_mask(2) == 0 and d.get_mask(3) == 3
			and d.vol_master == 100 and d.vol_music == 100 and d.tutorial_done)
	if dir.file_exists(path):
		dir.remove(path)
