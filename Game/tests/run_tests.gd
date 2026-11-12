extends SceneTree


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

const UI_NAMES = ["tool_road", "tool_bridge", "tool_light", "tool_sorter", "tool_erase", "btn_pause",
		"btn_speed_1", "btn_speed_2", "btn_speed_4", "btn_heatmap", "btn_help", "deliveries_bar",
		"light_mode_timer", "light_mode_sensor", "light_mode_priority", "light_apply", "sorter_apply"]

var failed = 0
var passed = 0


func _initialize() -> void:
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


func check(o: String, ok: bool, u: String = "") -> void:
	if ok:
		passed += 1
		print("[ OK ] " + o + ("  (" + u + ")" if u != "" else ""))
	else:
		failed += 1
		print("[FAIL] " + o + ("  (" + u + ")" if u != "" else ""))


func base_level() -> Dictionary:
	return {
		"id": 99, "name": "", "time": 600, "goal": 0, "mode": "score", "seed": 5,
		"factories": [], "warehouses": [], "water": [], "obstacles": [], "roads": [],
		"inventory": {"road": 400, "light": 20, "sorter": 20, "bridge": 20},
		"tutorial": false, "solution": [],
	}


func make_sim(lv: Dictionary):
	var o = Sim.new()
	o.load_level(lv)
	return o


func run(o, u: float) -> void:
	var n = int(round(u / C.STEP))
	for _i in range(n):
		o.step(C.STEP)


func line(o, u: Vector2, to: Vector2) -> void:
	o.apply_action({"type": "road_line", "from": u, "to": to})


func test_pathfinding() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(2, 7), "color": C.CargoColor.BLUE, "interval": 2.0}]
	lv["warehouses"] = [{"cell": Vector2(10, 7), "color": C.CargoColor.BLUE}]
	var o = make_sim(lv)
	line(o, Vector2(3, 7), Vector2(9, 7))
	run(o, 20.0)
	check("1a pathfinding: straight road delivers", o.metrics.deliveries >= 5,
			"deliveries=%d" % o.metrics.deliveries)

	lv = base_level()
	lv["factories"] = [{"cell": Vector2(2, 7), "color": C.CargoColor.BLUE, "interval": 2.0}]
	lv["warehouses"] = [{"cell": Vector2(12, 7), "color": C.CargoColor.BLUE}]
	o = make_sim(lv)
	line(o, Vector2(3, 7), Vector2(4, 7))
	line(o, Vector2(4, 6), Vector2(4, 5))
	line(o, Vector2(5, 5), Vector2(10, 5))
	line(o, Vector2(10, 6), Vector2(10, 7))
	line(o, Vector2(4, 8), Vector2(4, 9))
	line(o, Vector2(5, 9), Vector2(10, 9))
	o.build_road(Vector2(10, 8))
	o.build_road(Vector2(11, 7))
	var u = Vector2(4, 7)
	var ok = o.place_sorter(u) != null
	o.configure_sorter(u, {C.CargoColor.BLUE: Vector2(0, -1)})
	o.pathing.rebuild(o.grid)
	var up = o.pathing.find_path(C.CargoColor.BLUE, Vector2(2, 7), C.CargoColor.BLUE, o.warehouses)
	o.configure_sorter(u, {C.CargoColor.BLUE: Vector2(0, 1)})
	o.pathing.rebuild(o.grid)
	var z = o.pathing.find_path(C.CargoColor.BLUE, Vector2(2, 7), C.CargoColor.BLUE, o.warehouses)
	ok = ok and up.has(Vector2(4, 6)) and not up.has(Vector2(4, 8))
	ok = ok and z.has(Vector2(4, 8)) and not z.has(Vector2(4, 6))
	run(o, 20.0)
	check("1b pathfinding: sorter changes the route", ok and o.metrics.deliveries > 0,
			"up=%d down=%d deliveries=%d" % [up.size(), z.size(), o.metrics.deliveries])


func test_capacity_jam() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(1, 7), "color": C.CargoColor.BLUE, "interval": 1.0}]
	lv["warehouses"] = [{"cell": Vector2(12, 7), "color": C.CargoColor.BLUE}]
	var o = make_sim(lv)
	line(o, Vector2(2, 7), Vector2(11, 7))
	o.build_road(Vector2(8, 6))
	o.build_road(Vector2(8, 8))
	var l = o.place_light(Vector2(8, 7))
	l.period = 100000.0
	l.green_axis = 1
	var u = {}
	for _i in range(int(20.0 / C.STEP)):
		o.step(C.STEP)
		for v in o.vehicles:
			if v.state == Vehicle.S.WAITING and not u.has(v.cell):
				u[v.cell] = o.time
	var ok = true
	var z = -1.0
	for x in [7, 6, 5, 4, 3]:
		var aa = Vector2(x, 7)
		if not u.has(aa) or u[aa] <= z:
			ok = false
			break
		z = u[aa]
	check("2 capacity jam: queue grows backward tile by tile", ok and o.metrics.deliveries == 0,
			"queue tiles=%d" % u.size())


func tick_light(l, o: float) -> void:
	for _i in range(int(round(o / C.STEP))):
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


func test_gridlock_lose() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(1, 7), "color": C.CargoColor.BLUE, "interval": 0.5}]
	lv["warehouses"] = [{"cell": Vector2(9, 7), "color": C.CargoColor.BLUE}]
	var o = make_sim(lv)
	line(o, Vector2(2, 7), Vector2(8, 7))
	o.build_road(Vector2(6, 6))
	o.build_road(Vector2(6, 8))
	var l = o.place_light(Vector2(6, 7))
	l.period = 100000.0
	l.green_axis = 1
	run(o, 29.0)
	var ok = o.finished and o.result == "lose" and o.lose_reason == "gridlock"
	check("4 gridlock: a closed network loses after 15 s without movement",
			ok and o.time >= C.GRIDLOCK_SECONDS and o.still_time >= C.GRIDLOCK_SECONDS - 0.01,
			"t=%.1f reason=%s" % [o.time, o.lose_reason])


func test_patience_lose() -> void:
	var lv = base_level()
	lv["factories"] = [{"cell": Vector2(1, 7), "color": C.CargoColor.BLUE, "interval": 2.0}]
	lv["warehouses"] = [{"cell": Vector2(9, 7), "color": C.CargoColor.BLUE}]
	var o = make_sim(lv)
	run(o, 40.0)
	check("5 patience: a warehouse with no route loses",
			o.finished and o.lose_reason == "patience" and abs(o.time - C.WAREHOUSE_PATIENCE_MAX) < 0.2,
			"t=%.1f" % o.time)


func run_fixed(lv: Dictionary, o: int) -> Array:
	var u = make_sim(lv)
	u.apply_solution()
	for _i in range(o):
		u.step(C.STEP)
	var z = Vector2()
	for v in u.vehicles:
		z += v.pos
	return [u.metrics.deliveries, u.metrics.score(), u.vehicles.size(), z]


func test_determinism() -> void:
	var o = LevelsScript.new()
	var lv = o.LEVELS[1]
	var a = run_fixed(lv, 3600)
	var b = run_fixed(lv, 3600)
	o.free()
	check("6 determinism: same seed and actions give the same result", a == b and a[0] > 0,
			"deliveries=%d score=%d" % [a[0], a[1]])


func test_level_validity() -> void:
	var o = LevelsScript.new()
	for lv in o.LEVELS:
		var u = make_sim(lv)
		var z = u.apply_solution()
		while not u.finished:
			u.step(C.STEP)
		var aa = true
		for f in u.factories:
			if not u.has_route(f):
				aa = false
		var ok = z and aa and u.pending_events.empty()
		if lv["mode"] == "goal":
			ok = ok and u.result == "win"
		else:
			ok = ok and u.result == "finished" and u.metrics.deliveries >= 40
		check("7 level %d valid with its solution" % lv["id"], ok,
				"built=%s routes=%s result=%s %s t=%.0f deliveries=%d jam=%.1f score=%d stars=%d" % [
				z, aa, u.result, u.lose_reason, u.time, u.metrics.deliveries,
				u.metrics.jam_seconds, u.metrics.score(), u.goals.stars()])
	o.free()


func test_performance() -> void:
	var lv = base_level()
	var o = [1, 3, 5, 7, 9, 11, 13]
	for i in range(o.size()):
		var y = o[i]
		var u = C.CargoColor.BLUE if i % 2 == 0 else C.CargoColor.RED
		lv["factories"].append({"cell": Vector2(0, y), "color": u, "interval": 0.4,
				"urgent_every": 5})
	lv["warehouses"] = [{"cell": Vector2(31, 1), "color": C.CargoColor.RED},
			{"cell": Vector2(31, 13), "color": C.CargoColor.BLUE}]
	var z = make_sim(lv)
	for y in o:
		line(z, Vector2(1, y), Vector2(30, y))
	for x in [6, 14, 22, 30]:
		line(z, Vector2(x, 1), Vector2(x, 13))
	for aa in [Vector2(14, 5), Vector2(14, 9), Vector2(22, 7), Vector2(30, 3), Vector2(30, 11)]:
		var l = z.place_light(aa)
		if l != null:
			l.mode = C.LightMode.SENSOR
	var ab = int(60.0 / C.STEP)
	var ac = 0
	var ad = 0
	var t0 = OS.get_ticks_usec()
	for _i in range(ab):
		z.finished = false
		for w in z.warehouses:
			w.patience = C.WAREHOUSE_PATIENCE_MAX
		z.still_time = 0.0
		z.step(C.STEP)
		ac = int(max(ac, z.vehicles.size()))
		ad += z.vehicles.size()
	var ae = float(OS.get_ticks_usec() - t0) / ab / 1000.0
	check("8 performance: average step under 2 ms with 120 vehicles",
			ae < 2.0 and ac >= C.MAX_VEHICLES,
			"avg step=%.3f ms, max vehicles=%d, avg vehicles=%d" % [ae, ac, ad / ab])


func list_files(o: String, u: String, z: Array) -> void:
	var aa = Directory.new()
	if aa.open(o) != OK:
		return
	aa.list_dir_begin(true, true)
	var ab = aa.get_next()
	while ab != "":
		var ac = o + "/" + ab if o != "res://" else o + ab
		if aa.current_is_dir():
			list_files(ac, u, z)
		elif ab.ends_with(u):
			z.append(ac)
		ab = aa.get_next()
	aa.list_dir_end()


func read_lines(o: String) -> Array:
	var f = File.new()
	if f.open(o, File.READ) != OK:
		return []
	var u = f.get_as_text().split("\n")
	f.close()
	return Array(u)


func strip_comment(s: String) -> String:
	var o = false
	for i in range(s.length()):
		var ch = s[i]
		if ch == "\"":
			o = not o
		elif ch == "#" and not o:
			return s.substr(0, i)
	return s


func assigns_field(s: String, o: String) -> bool:
	var u = "." + o
	var at = s.find(u)
	while at != -1:
		var j = at + u.length()
		var z = s[j] if j < s.length() else ""
		var aa = z != "" and (z == "_" or (z >= "a" and z <= "z") or (z >= "A" and z <= "Z") \
				or (z >= "0" and z <= "9"))
		if not aa:
			while j < s.length() and s[j] == " ":
				j += 1
			var ab = s.substr(j, 2)
			if ab.length() > 0 and ab[0] == "=" and ab != "==":
				return true
			if ab in ["+=", "-=", "*=", "/="]:
				return true
		at = s.find(u, at + 1)
	return false


func test_no_manual_control() -> void:
	var o = []
	list_files("res://view", ".gd", o)
	list_files("res://ui", ".gd", o)
	list_files("res://tutorial", ".gd", o)
	list_files("res://audio", ".gd", o)
	var u = ["path", "state", "pos", "progress", "idx", "speed", "wait_time", "unload_timer",
			"from_cell", "reserved", "done", "dir", "dir_prev", "urgent", "repath_timer"]
	var z = ["vehicles.erase", "vehicles.remove", "vehicles.clear", "vehicles.pop", "vehicles.append",
			"vehicles.insert", "vehicles.resize", "vehicles =", "_drop_vehicle", "spawn_vehicle", ".deliver(",
			"_repath", "v.tick(", ".path.", "try_enter", ".leave("]
	var aa = [".erase(", ".append(", ".clear(", ".remove(", ".push_back(", ".pop_back(", "] ="]
	var ab = []
	for ac in o:
		var n = 0
		for ad in read_lines(ac):
			n += 1
			var s = strip_comment(ad)
			for f in u:
				if assigns_field(s, f):
					ab.append("%s:%d assigns .%s" % [ac, n, f])
			for p in z:
				if s.find(p) != -1 and s.find("vehicles ==") == -1:
					ab.append("%s:%d %s" % [ac, n, p])
			if s.find("occupants") != -1:
				for p in aa:
					if s.find(p) != -1:
						ab.append("%s:%d edits occupants" % [ac, n])
	for h in ab:
		print("       " + h)
	check("9 no manual control: view and UI never change a vehicle", ab.empty() and o.size() > 0,
			"%d files scanned" % o.size())


func test_offline() -> void:
	var o = []
	list_files("res://", ".gd", o)
	list_files("res://", ".tscn", o)
	var u = ["HTTP" + "Request", "HTTP" + "Client", "StreamPeer" + "TCP", "PacketPeer" + "UDP",
			"WebSocket" + "Client", "WebSocket" + "Server", "NetworkedMultiplayer" + "ENet",
			"OS.shell" + "_open", "TCP_" + "Server", "UP" + "NP"]
	var z = []
	for aa in o:
		var n = 0
		for ab in read_lines(aa):
			n += 1
			for b in u:
				if ab.find(b) != -1:
					z.append("%s:%d %s" % [aa, n, b])
	for h in z:
		print("       " + h)
	check("10 offline: no network classes anywhere", z.empty() and o.size() > 10,
			"%d files scanned" % o.size())


func has_latin(s: String) -> bool:
	for i in range(s.length()):
		var o = s.ord_at(i)
		if (o >= 65 and o <= 90) or (o >= 97 and o <= 122):
			return true
	return false


func string_literals(s: String) -> Array:
	var o = []
	var u = ""
	var z = false
	var i = 0
	while i < s.length():
		var ch = s[i]
		if z:
			if ch == "\\":
				i += 2
				continue
			if ch == "\"":
				z = false
				o.append(u)
			else:
				u += ch
		elif ch == "\"":
			z = true
			u = ""
		i += 1
	return o


func has_cyrillic(s: String) -> bool:
	for i in range(s.length()):
		var o = s.ord_at(i)
		if o >= 0x400 and o <= 0x4FF:
			return true
	return false


func has_letter(s: String) -> bool:
	return has_latin(s) or has_cyrillic(s)


func literal_after(s: String, at: int) -> String:
	var j = at
	while j < s.length() and s[j] == " ":
		j += 1
	if j >= s.length() or s[j] != "\"":
		return ""
	var o = string_literals(s.substr(j, s.length() - j))
	return o[0] if o.size() > 0 else "?"


func strip_key_calls(s: String) -> String:
	var o = s
	for u in ["Strings.t(\"", "Strings.tf(\"", "UiRegistry.register(\""]:
		var at = o.find(u)
		while at != -1:
			var z = o.find("\"", at + u.length())
			if z == -1:
				break
			o = o.substr(0, at) + "KEYCALL(" + o.substr(z + 1, o.length() - z - 1)
			at = o.find(u)
	return o


func strings_tables() -> Dictionary:
	var o = root.get_node("Strings")
	return o.get_script().get_script_constant_map()


func format_slots(s: String) -> Array:
	var o = []
	var i = 0
	while i < s.length():
		if s[i] == "%" and i + 1 < s.length() and s[i + 1] == "%":
			i += 1
		elif s[i] == "%":
			var j = i + 1
			while j < s.length() and not (s[j] in ["s", "d", "f"]):
				j += 1
			o.append(s.substr(i, j - i + 1))
			i = j
		i += 1
	return o


func test_strings_parity() -> void:
	var t = strings_tables()
	var en = t["EN"]
	var ru = t["RU"]
	var o = []
	for u in en.keys():
		if not ru.has(u):
			o.append("missing in RU: " + u)
		elif str(en[u]) == "" or str(ru[u]) == "":
			o.append("empty: " + u)
		elif format_slots(en[u]) != format_slots(ru[u]):
			o.append("placeholders differ: " + u)
	for u in ru.keys():
		if not en.has(u):
			o.append("missing in EN: " + u)
	for p in o:
		print("       " + p)
	check("12 strings parity: EN and RU have the same keys and placeholders", o.empty() and en.size() > 100,
			"%d keys" % en.size())
	var z = []
	for u in en.keys():
		if has_cyrillic(en[u]):
			z.append(u)
	check("12b english table has no Cyrillic text", z.empty(), str(z))


func test_missing_keys() -> void:
	var en = strings_tables()["EN"]
	var o = []
	list_files("res://", ".gd", o)
	var u = []
	var z = 0
	for aa in o:
		if aa.begins_with("res://tests"):
			continue
		var n = 0
		for ab in read_lines(aa):
			n += 1
			var s = strip_comment(ab)
			for ac in ["Strings.t(\"", "Strings.tf(\""]:
				var at = s.find(ac)
				while at != -1:
					var ad = at + ac.length()
					var ae = s.find("\"", ad)
					var af = s.substr(ad, ae - ad)
					z += 1
					if not en.has(af):
						u.append("%s:%d %s" % [aa, n, af])
					at = s.find(ac, ae)
			for ag in string_literals(s):
				if ag.length() > 4 and (ag.begins_with("HELP_") or ag.begins_with("TUT_") or ag.begins_with("TOAST_")) \
						and ag == ag.to_upper() and not en.has(ag):
					u.append("%s:%d %s" % [aa, n, ag])
	for ah in TutorialData.get_lessons():
		var ai = [ah["title_key"], ah["level"]["name_key"]]
		for aj in ah["steps"]:
			ai.append(aj["text_key"])
			if aj.has("hint_key"):
				ai.append(aj["hint_key"])
			if aj.has("button_key"):
				ai.append(aj["button_key"])
			for ak in aj.get("checklist", []):
				ai.append(ak["key"])
		for k in ai:
			if not en.has(k):
				u.append("lesson %s: %s" % [ah["id"], k])
	for lv in LevelsScript.new().LEVELS:
		if not en.has(lv["name_key"]):
			u.append("level name " + lv["name_key"])
	for m in u:
		print("       " + m)
	check("13 missing keys: every Strings.t key exists in EN", u.empty() and z > 80, "%d lookups checked" % z)


func test_no_hardcoded_text() -> void:
	var o = []
	list_files("res://view", ".gd", o)
	list_files("res://ui", ".gd", o)
	list_files("res://tutorial", ".gd", o)
	list_files("res://autoload", ".gd", o)
	var u = ["text = ", "text=", "set_text(", "hint_tooltip = ", "window_title = ", "set_window_title(", "toast(",
			"button(", "label(", "Button.new(", "Label.new(", "add_item("]
	var z = ["draw_string(", "centered(", "left("]
	var aa = []
	for ab in o:
		if ab.ends_with("strings.gd") or ab.ends_with("tutorial_data.gd"):
			continue
		var ac = not ab.begins_with("res://autoload")
		var n = 0
		for ad in read_lines(ab):
			n += 1
			var s = strip_key_calls(strip_comment(ad))
			if ac:
				for ae in string_literals(s):
					if has_cyrillic(ae):
						aa.append("%s:%d Cyrillic literal \"%s\"" % [ab, n, ae])
			for af in u:
				var at = s.find(af)
				while at != -1:
					var ae = literal_after(s, at + af.length())
					if has_letter(ae):
						aa.append("%s:%d \"%s\"" % [ab, n, ae])
					at = s.find(af, at + 1)
			for af in z:
				if s.find(af) == -1:
					continue
				var q = s.find("\"")
				while q != -1:
					var ae = literal_after(s, q)
					var ag = q + ae.length() + 2
					var ah = ag < s.length() and s[ag] == "]"
					if has_letter(ae) and not ah:
						aa.append("%s:%d \"%s\"" % [ab, n, ae])
					q = s.find("\"", ag)
	for h in aa:
		print("       " + h)
	check("14 no hardcoded UI text outside strings.gd", aa.empty(), "%d files scanned" % o.size())


func test_first_run() -> void:
	var o = "user://test_save.cfg"
	var u = Directory.new()
	if u.file_exists(o):
		u.remove(o)
	var a = SaveDataScript.new()
	a.path = o
	a.load_data()
	var z = a.is_first_run()
	a.finish_tutorial(false)
	var b = SaveDataScript.new()
	b.path = o
	var aa = b.load_data()
	var ab = not b.is_first_run() and not b.tutorial_skipped
	b.save_result(7, 1234, 5)
	var c = SaveDataScript.new()
	c.path = o
	c.load_data()
	var ac = c.get_best(7)["score"] == 1234 and c.get_stars(7) == 2 and c.get_mask(7) == 5 and not c.is_first_run()
	check("15a first run: fresh install is a first run, then not", z and aa and ab and ac)
	var f = File.new()
	f.open(o, File.WRITE)
	f.store_string("this is } not { a valid = config [[[ file\n=== ]]]")
	f.close()
	var d = SaveDataScript.new()
	d.path = o
	d.load_data()
	var ad = d.is_first_run() and d.language == "en"
	f.open(o, File.WRITE)
	f.store_string("[meta]\ntutorial_done=\"yes\"\nlanguage=42\nsound_on=7\n[score]\nabc=5\n")
	f.close()
	var e = SaveDataScript.new()
	e.path = o
	e.load_data()
	var ae = e.is_first_run() and e.language == "en" and e.sound_on and e.best.empty()
	var g = SaveDataScript.new()
	g.path = "user://does_not_exist_%d.cfg" % OS.get_ticks_usec()
	var af = g.load_data() == false and g.is_first_run()
	check("15b first run: corrupt or missing save counts as a fresh install", ad and ae and af)
	d.path = o
	d.delete_save()
	for ag in [a, b, c, d, e, g]:
		ag.free()


func test_lessons_solvable() -> void:
	var o = TutorialData.get_lessons()
	check("16a lessons: 6 lessons and a final test", o.size() == 7 and o[6].get("final", false))
	for i in range(o.size()):
		var u = o[i]
		var z = make_sim(u["level"])
		var aa = TutorialManager.new()
		aa.start(u, z, i + 1, 6)
		var ab = TutorialSolver.run(z, aa, u)
		var ok = ab == "" and aa.done
		if u.get("final", false):
			ok = ok and z.result == "win"
		check("16 lesson %s: solution completes it" % u["id"], ok,
				ab if ab != "" else "t=%.0f s, deliveries=%d" % [z.time, z.metrics.deliveries])


func test_no_soft_locks() -> void:
	var o = []
	for u in TutorialData.get_lessons():
		var z = TutorialManager.new()
		for aa in u["steps"]:
			var id = aa["id"]
			if not aa.has("wait") or not aa["wait"].has("event"):
				o.append(id + ": no wait condition")
				continue
			var e = aa["wait"]["event"]
			if not (e in TutorialManager.SUPPORTED):
				o.append(id + ": unsupported event " + e)
			if e != "continue" and not aa.has("hint_key"):
				o.append(id + ": action step without a hint")
			for ab in aa.get("highlight_ui", []):
				if not (ab in UI_NAMES):
					o.append(id + ": unknown ui name " + ab)
			for ac in aa.get("checklist", []):
				if not (ac["cond"]["event"] in TutorialManager.SUPPORTED):
					o.append(id + ": unsupported checklist event")
			if aa.get("needs_panel", "") != "" and not (aa["needs_panel"] in ["light", "sorter"]):
				o.append(id + ": bad needs_panel")
		var ad = u["level"].get("allowed_tools", [])
		if ad.empty():
			o.append(u["id"] + ": no allowed_tools")
	for p in o:
		print("       " + p)
	check("17 no soft locks: every step has a wait, a hint and known highlights", o.empty())
	var u = TutorialData.get_lesson(0)
	var ae = make_sim(u["level"])
	var z = TutorialManager.new()
	z.start(u, ae, 1, 6)
	z.notify("continue")
	z.notify("continue")
	var af = z.hint_available() or z.skip_available()
	z.tick(TutorialManager.HINT_AFTER + 0.1)
	var ag = z.hint_available() and not z.skip_available()
	z.tick(TutorialManager.SKIP_AFTER)
	var ah = z.skip_available()
	var ai = z.idx
	z.skip_step()
	check("17b hint after 15 s, skip step after 30 s, skip really advances", not af and ag and ah and z.idx == ai + 1)


func test_tutorial_cannot_be_lost() -> void:
	var o = TutorialData.get_lessons()
	var u = true
	var z = ""
	for i in range(6):
		var aa = o[i]
		var ab = make_sim(aa["level"])
		for l in ab.lights:
			l.period = 100000.0
			l.green_axis = 1
		if aa["id"] in ["l3", "l5"]:
			ab.apply_action({"type": "light", "cell": Vector2(15, 7), "mode": C.LightMode.TIMER})
			ab.lights[0].period = 100000.0
			ab.lights[0].green_axis = 1
		if aa["id"] == "l1":
			ab.apply_action({"type": "road_line", "from": Vector2(5, 7), "to": Vector2(10, 7)})
		run(ab, 60.0)
		if ab.finished or ab.result != "":
			u = false
			z += " %s:%s/%s" % [aa["id"], ab.result, ab.lose_reason]
	check("18 tutorial cannot be lost: 60 s of a bad network in lessons 1 to 6", u, z)
	var ac = make_sim(o[6]["level"])
	run(ac, 40.0)
	check("18b the final test can be lost", ac.finished and ac.result == "lose", ac.lose_reason)


func audio_dir_files() -> Array:
	var o = []
	var u = Directory.new()
	if u.open("res://audio") != OK:
		return o
	u.list_dir_begin(true, true)
	var z = u.get_next()
	while z != "":
		if z.ends_with(".wav"):
			o.append(z.get_basename())
		z = u.get_next()
	u.list_dir_end()
	return o


func test_audio_files() -> void:
	var o = audio_dir_files()
	var u = []
	var z = 0
	for n in Director.all_files():
		if not o.has(n):
			u.append(n)
		else:
			var f = File.new()
			f.open("res://audio/%s.wav" % n, File.READ)
			z += f.get_len()
			f.close()
	var aa = []
	var ab = OS.execute("python3", ["-I", ProjectSettings.globalize_path("res://tools/check_audio.py")], true, aa)
	var ac = ab == 0 or ab == -1
	check("19 audio: every sound file exists, the total is small, check_audio.py passes",
			u.empty() and z < 6 * 1048576 and ac,
			"missing=%s total=%d KB python exit=%d" % [str(u), z / 1024, ab])


func test_audio_director() -> void:
	var d = Director.new()
	for _i in range(7):
		d.on_event({"type": "deliver"})
		d.update(0.2)
	var o = []
	for r in d.take_requests():
		o.append(r["file"])
	check("20a streak: deliveries climb to note 4 and stay there",
			o == ["deliver_0", "deliver_1", "deliver_2", "deliver_3", "deliver_4", "deliver_4", "deliver_4"], str(o))
	d.on_event({"type": "deliver"})
	d.on_event({"type": "jam_start"})
	d.update(0.2)
	d.on_event({"type": "deliver"})
	d.update(0.2)
	o = []
	for r in d.take_requests():
		o.append(r["file"])
	check("20b streak: a jam resets it", o.size() == 3 and o[2] == "deliver_0" and o[0] == "jam_warn", str(o))
	d.on_event({"type": "deliver"})
	d.on_event({"type": "deliver"})
	d.update(0.2)
	d.take_requests()
	d.update(16.0)
	d.on_event({"type": "deliver"})
	d.update(0.2)
	var u = d.take_requests()
	check("20c streak: 15 s without a delivery resets it", u.size() == 1 and u[0]["file"] == "deliver_0")

	d = Director.new()
	for _i in range(4):
		d.on_event({"type": "deliver"})
		d.update(0.02)
	d.update(0.2)
	var z = d.take_requests()
	check("20d merging: four deliveries within 150 ms play one sound, the highest note",
			z.size() == 1 and z[0]["file"] == "deliver_3", str(z.size()))

	d = Director.new()
	var aa = d.request("place_road")
	var ab = d.request("place_road")
	d.update(0.05)
	var ac = d.request("place_road")
	check("20e cooldown: a sound does not repeat inside its cooldown", aa and not ab and ac)
	d = Director.new()
	var ad = 0
	for _i in range(5):
		if d.request("deliver"):
			ad += 1
	check("20f voices: max_voices is respected", ad == 3, "accepted=%d" % ad)
	d = Director.new()
	d.on_event({"type": "jam_start"})
	var ae = d.take_requests().size() == 1
	d.update(1.0)
	d.on_event({"type": "jam_start"})
	var af = d.take_requests().size() == 0
	d.update(5.0)
	d.on_event({"type": "jam_start"})
	check("20g jam warning is limited to once per 5 s", ae and af and d.take_requests().size() == 1)

	d = Director.new()
	d.duck(4.0, 1.0)
	var ag = d.duck_offset() == -4.0
	d.update(1.1)
	check("20h ducking: lowers the music and returns to zero after its time", ag and d.duck_offset() == 0.0)
	d = Director.new()
	var ah = true
	var ai = false
	for _i in range(20):
		d.set_intensity_target(1.0)
		ah = ah and d.intensity >= 0.0 and d.intensity <= 1.0
		ai = ai or d.tension_on
	var aj = true
	d.intensity = 0.45
	d.set_intensity_target(0.45)
	aj = d.tension_on
	for _i in range(20):
		d.set_intensity_target(0.0)
		ah = ah and d.intensity >= 0.0 and d.intensity <= 1.0
	check("20i intensity stays in 0..1; tension fades in above 0.5 and out below 0.35",
			ah and ai and aj and not d.tension_on)
	d = Director.new()
	check("20j melody layer starts after the first delivery",
			d.layer_targets()["melody"] == 0.0 and _after_delivery(d)["melody"] == 1.0)
	check("20k music pitch follows the speed", Director.music_pitch(1.0) == 1.0 and Director.music_pitch(2.0) == 1.04 \
			and Director.music_pitch(4.0) == 1.08)


func _after_delivery(d) -> Dictionary:
	d.on_event({"type": "deliver"})
	return d.layer_targets()


func test_registry() -> void:
	var o = []
	for n in Director.MAPPED:
		if not Director.REGISTRY.has(n):
			o.append("mapped but not in the registry: " + n)
	for n in Director.REGISTRY.keys():
		var e = Director.REGISTRY[n]
		for k in ["bus", "base_db", "priority", "cooldown_ms", "max_voices", "pitch_jitter", "dur"]:
			if not e.has(k):
				o.append(n + " lacks " + k)
	var u = Director.all_files()
	var z = audio_dir_files()
	for n in u:
		if not z.has(n):
			o.append("no file for " + n)
	for n in z:
		if not u.has(n):
			o.append("file not used by the registry: " + n)
	for p in o:
		print("       " + p)
	check("21 registry: every mapped sound is registered, has a file, and every file is used",
			o.empty(), "%d files" % z.size())


func fingerprint(o) -> Array:
	var u = Vector2()
	for v in o.vehicles:
		u += v.pos
	return [o.metrics.deliveries, o.metrics.score(), o.vehicles.size(), u, o.metrics.jam_seconds,
			o.time, o.result, o.metrics.urgent_deliveries]


func run_level(lv: Dictionary, o = null, u: bool = true) -> Array:
	var z = make_sim(lv)
	z.goals_enabled = u
	z.apply_solution()
	var aa = 0
	while not z.finished and aa < 9000:
		z.step(C.STEP)
		aa += 1
		if o != null:
			for ev in z.events:
				o.on_event(ev)
			z.events = []
			o.update(C.STEP, z)
	return fingerprint(z)


func test_audio_does_not_change_sim() -> void:
	var o = LevelsScript.new()
	var lv = o.LEVELS[1]
	var u = run_level(lv)
	var z = run_level(lv, Director.new())
	o.free()
	check("22 new events and the audio director do not change the simulation", u == z,
			"deliveries=%d" % u[0])


func goal_sim(o: Array, u: String = "goal"):
	var lv = base_level()
	lv["mode"] = u
	lv["goal"] = 5
	lv["time"] = 100
	lv["star_goals"] = o
	return make_sim(lv)


func status_of(o: Array, u, z: bool, aa: bool = true) -> Array:
	var ab = goal_sim(o)
	ab.time = 60.0
	u.call_func(ab)
	ab.goals.tick(ab)
	if aa:
		ab.goals.finalize(ab, z)
	return ab.goals.status


func test_goal_types() -> void:
	var P = Goals.Status.PENDING
	var D = Goals.Status.DONE
	var F = Goals.Status.FAILED
	var ok = true
	var o = ""
	var u = [
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
	for c in u:
		var z = goal_sim([c[0]])
		z.time = 60.0
		_apply_setup(z, c[1])
		z.goals.tick(z)
		z.goals.finalize(z, c[2])
		if z.goals.status[0] != c[3]:
			ok = false
			o += " %s/%s/%s got %d" % [c[0]["type"], c[1], str(c[2]), z.goals.status[0]]
	check("23a goals: every type is pending, done or failed as defined", ok, o)

	var aa = goal_sim([{"type": "urgent_min", "value": 2}, {"type": "jam_seconds_max", "value": 5},
			{"type": "patience_min", "value": 40}])
	aa.metrics.urgent_deliveries = 2
	aa.metrics.jam_seconds = 6.0
	aa.metrics.min_patience_ratio = 0.2
	aa.goals.tick(aa)
	var ab = aa.goals.status == [D, F, F]
	var ac = []
	for ev in aa.events:
		ac.append(ev["type"])
	aa.metrics.urgent_deliveries = 0
	aa.metrics.jam_seconds = 0.0
	aa.metrics.min_patience_ratio = 1.0
	aa.goals.tick(aa)
	aa.goals.finalize(aa, true)
	check("23b goals: live goals finish at once, early-fail goals fail at once, never change back",
			ab and aa.goals.status == [D, F, F] and ac.count("goal_reached") == 1 and ac.count("goal_failed") == 2,
			str(ac))
	var ad = goal_sim([{"type": "complete"}, {"type": "jam_seconds_max", "value": 5}, {"type": "urgent_min", "value": 9}])
	ad.goals.finalize(ad, true)
	check("23c goals: mask and star count", ad.goals.earned_mask() == 3 and ad.goals.stars() == 2
			and SaveDataScript.popcount(5) == 2)
	var ae = goal_sim([])
	ae.goals.finalize(ae, true)
	check("23d goals: a level without goals has no stars", ae.goals.stars() == 0 and ae.goals.count() == 0)


func _apply_setup(o, u: String) -> void:
	if u == "jam3":
		o.metrics.jam_seconds = 3.0
	elif u == "jam6":
		o.metrics.jam_seconds = 6.0
	elif u == "avg5":
		o.metrics.deliveries = 2
		o.metrics.total_delivery_time = 10.0
	elif u == "urgent3":
		o.metrics.urgent_deliveries = 3
	elif u == "pat50":
		o.metrics.min_patience_ratio = 0.5
	elif u == "pat30":
		o.metrics.min_patience_ratio = 0.3
	elif u == "roads5":
		for i in range(5):
			o.grid.player_built[Vector2(i, 0)] = true
	elif u == "deliv5":
		o.metrics.deliveries = 5
		o.metrics.total_delivery_time = 50.0


func test_goal_level_data() -> void:
	var o = LevelsScript.new()
	var t = strings_tables()
	var u = []
	for lv in o.LEVELS:
		var g = lv.get("star_goals", [])
		if g.size() != 3:
			u.append("level %d has %d goals" % [lv["id"], g.size()])
			continue
		if g[0]["type"] != "complete":
			u.append("level %d: first goal is not complete" % lv["id"])
		for z in g:
			var aa = z["type"]
			if not Goals.TYPES.has(aa):
				u.append("unknown type " + aa)
				continue
			if aa != "complete" and not (z.has("value") and z["value"] > 0):
				u.append("%s needs a positive value" % aa)
			var ab = [Goals.text_key(aa)]
			if aa != "complete":
				ab.append(Goals.progress_key(aa))
				ab.append(Goals.result_key(aa))
			for k in ab:
				if not t["EN"].has(k) or not t["RU"].has(k):
					u.append("missing text " + k)
	for ac in TutorialData.get_lessons():
		if ac["level"].has("star_goals"):
			u.append("tutorial lesson has star goals")
	o.free()
	for p in u:
		print("       " + p)
	check("23e goal data: three goals per level, first is complete, valid types and values, texts exist",
			u.empty())


func finish_run(lv: Dictionary, o: String):
	var u = make_sim(lv)
	for a in lv["solution"]:
		var z = a
		if o == "baseline" and (a["type"] == "light" or a["type"] == "sorter"):
			continue
		if o == "timer" and a["type"] == "light":
			z = a.duplicate()
			z["mode"] = C.LightMode.TIMER
		u.apply_action(z)
	var aa = 0
	while not u.finished and aa < 12000:
		u.step(C.STEP)
		aa += 1
	return u


func test_goal_calibration() -> void:
	var o = LevelsScript.new()
	var u = true
	var z = true
	var aa = ""
	for lv in o.LEVELS:
		var ab = finish_run(lv, "solution")
		var ac = finish_run(lv, "baseline")
		var ad = finish_run(lv, "timer")
		if ab.goals.stars() != 3:
			u = false
		if ad.goals.stars() > 2:
			z = false
		aa += " L%d solution=%d roads-only=%d timer-lights=%d;" % [lv["id"], ab.goals.stars(), ac.goals.stars(), ad.goals.stars()]
	o.free()
	check("24a calibration: the intended solution earns three stars on every level", u, aa)
	check("24b calibration: a careless build (all lights on slow timers) earns at most two stars", z, aa)


func test_goals_read_only() -> void:
	var o = LevelsScript.new()
	var ok = true
	for lv in o.LEVELS:
		var a = run_level(lv, null, true)
		var b = run_level(lv, null, false)
		if a != b:
			ok = false
	o.free()
	check("25 goals are read-only: results are identical with goals on and off", ok)


func test_goal_save() -> void:
	var o = "user://test_goals.cfg"
	var u = Directory.new()
	if u.file_exists(o):
		u.remove(o)
	var a = SaveDataScript.new()
	a.path = o
	a.load_data()
	var z = a.save_result(1, 100, 1)
	var aa = a.save_result(1, 50, 6)
	var ab = a.save_result(1, 900, 2)
	var b = SaveDataScript.new()
	b.path = o
	b.load_data()
	check("26a save: goal masks are ORed, earned goals stay earned, new bits are reported",
			z == 1 and aa == 6 and ab == 0 and b.get_mask(1) == 7 and b.get_stars(1) == 3
			and b.get_best(1)["score"] == 900)
	a.set_volumes(50, 20, 70)
	var c = SaveDataScript.new()
	c.path = o
	c.load_data()
	check("26b save: volumes roundtrip, defaults are 100 / 60 / 90",
			c.vol_master == 50 and c.vol_music == 20 and c.vol_effects == 70
			and SaveDataScript.new().vol_master == 100 and SaveDataScript.new().vol_music == 60
			and SaveDataScript.new().vol_effects == 90)
	var f = File.new()
	f.open(o, File.WRITE)
	f.store_string("[meta]\ntutorial_done=true\nvol_master=\"loud\"\nvol_music=500\n[score]\n1=500\n[stars]\n1=3\n[played]\n1=true\n[goals]\n2=\"x\"\n3=99\n")
	f.close()
	var d = SaveDataScript.new()
	d.path = o
	d.load_data()
	check("26c save: an old save (single stars value) migrates to empty masks, bad values never crash",
			d.get_stars(1) == 0 and d.get_best(1)["score"] == 500 and d.get_mask(2) == 0 and d.get_mask(3) == 3
			and d.vol_master == 100 and d.vol_music == 100 and d.tutorial_done)
	if u.file_exists(o):
		u.remove(o)
