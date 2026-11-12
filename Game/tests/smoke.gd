extends Node

# Drives the real scenes end to end (first launch, every lesson, the final test, menus) and
# saves screenshots. Development aid, not one of the required tests:
#   SMOKE_OUT=/some/folder godot --path . res://tests/smoke.tscn

const C = preload("res://sim/constants.gd")
const TutorialData = preload("res://tutorial/tutorial_data.gd")

var out_dir = "user://"
var failures = 0


func _ready() -> void:
	if OS.has_environment("SMOKE_OUT"):
		out_dir = OS.get_environment("SMOKE_OUT") + "/"
	call_deferred("_run")


func expect(what: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for _i in range(n):
		yield(get_tree(), "idle_frame")


func wait_real(seconds: float) -> void:
	var until = OS.get_ticks_msec() + int(seconds * 1000.0)
	while OS.get_ticks_msec() < until:
		yield(get_tree(), "idle_frame")


func shot(name: String) -> void:
	yield(VisualServer, "frame_post_draw")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(out_dir + name + ".png")
	print("shot " + name)


func scene():
	return get_tree().current_scene


func click(at: Vector2, pressed: bool) -> void:
	var ev = InputEventMouseButton.new()
	ev.button_index = BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func move(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	var ev = InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func cell_px(cell: Vector2) -> Vector2:
	return Vector2(0, 56) + (cell + Vector2(0.5, 0.5)) * C.TILE


func press_control(c: Control) -> void:
	var at = c.get_global_rect().position + c.get_global_rect().size / 2.0
	move(at)
	yield(frames(2), "completed")
	click(at, true)
	yield(frames(2), "completed")
	click(at, false)
	yield(frames(2), "completed")


func go(path: String) -> void:
	get_tree().change_scene(path)
	yield(frames(12), "completed")


func exec(g, e: Dictionary) -> void:
	# Plays one entry of a lesson solution through the real game loop.
	var what = e["do"]
	if what == "continue":
		g.coach._on_continue()
	elif what == "action":
		g.sim.apply_action(e["action"])
		g.grid_view.update()
		g._tell_tutorial_changed()
	elif what == "speed":
		if g.modal:
			g.light_panel.visible = false
			g.sorter_panel.visible = false
			g._on_panel_closed()
		g.set_speed(e["value"])
	elif what == "heatmap":
		g.toggle_heatmap()
	elif what == "run_for":
		yield(frames(int(e["seconds"] * 10.0)), "completed")
	elif what == "run":
		var start = g.tutorial.idx
		var n = 0
		while g.tutorial.idx == start and not g.tutorial.done and n < 9000:
			n += 1
			yield(get_tree(), "idle_frame")
		if n >= 9000:
			expect("run did not finish step %s" % g.tutorial.current_step().get("id", "?"), false)
	yield(frames(3), "completed")


func play_lesson(index: int, shots: Dictionary) -> void:
	# `shots` maps solution entry numbers to screenshot names taken right after that entry.
	var g = scene()
	var lesson = TutorialData.get_lesson(index)
	yield(shot("%s_start" % lesson["id"]), "completed")
	var i = 0
	for e in lesson["solution"]:
		yield(exec(g, e), "completed")
		if shots.has(i):
			yield(frames(20), "completed")
			yield(shot(shots[i]), "completed")
		i += 1
		if g.tutorial.done:
			break
	yield(frames(10), "completed")
	expect("lesson %s completed" % lesson["id"], g.tutorial.done)


func _run() -> void:
	get_tree().current_scene = null          # keeps this node alive across scene changes
	Engine.time_scale = 1.0
	SaveData.delete_save()
	Strings.lang = "en"

	# --- first launch -> welcome screen
	yield(go("res://ui/boot.tscn"), "completed")
	yield(frames(10), "completed")
	expect("fresh install shows the welcome screen", scene().name == "WelcomeScreen")
	yield(shot("01_welcome"), "completed")
	scene()._on_skip()
	yield(frames(5), "completed")
	yield(shot("02_skip_confirm"), "completed")
	scene().confirm._on_no()
	scene()._on_start()
	yield(frames(15), "completed")
	expect("tutorial starts in the game scene", scene().name == "Game" and scene().is_tutorial)

	# --- lesson 1 with real mouse input
	var g = scene()
	yield(shot("03_l1_step1"), "completed")
	g.coach._on_continue()
	yield(frames(5), "completed")
	g.coach._on_continue()
	yield(frames(30), "completed")
	yield(shot("04_l1_road_step"), "completed")
	move(cell_px(Vector2(5, 7)))
	yield(frames(3), "completed")
	click(cell_px(Vector2(5, 7)), true)
	yield(frames(3), "completed")
	for x in range(6, 27):
		move(cell_px(Vector2(x, 7)))
		yield(frames(2), "completed")
	click(cell_px(Vector2(26, 7)), false)
	yield(frames(10), "completed")
	expect("dragging a road connects the buildings and advances the step", g.tutorial.idx == 3)
	yield(shot("05_l1_press_play"), "completed")
	# A locked tool must not work.
	g.set_tool(C.Tool.LIGHT)
	expect("locked tool is ignored in lesson 1", g.current_tool == C.Tool.ROAD)
	yield(press_control(g.hud.speed_btns[1.0]), "completed")
	expect("the 1x button starts the simulation", g.speed == 1.0 and g.tutorial.idx == 4)
	Engine.time_scale = 4.0
	var n = 0
	while not g.tutorial.done and n < 4000:
		n += 1
		yield(get_tree(), "idle_frame")
	Engine.time_scale = 1.0
	yield(frames(30), "completed")
	expect("lesson 1 finishes after 3 deliveries", g.tutorial.done and g.sim.metrics.deliveries >= 3)
	yield(shot("06_l1_done"), "completed")
	g.coach._on_next()
	yield(frames(15), "completed")

	# --- lessons 2 to 6 through the real game loop
	Engine.time_scale = 4.0
	yield(play_lesson(1, {1: "07_l2_red_road", 3: "08_l2_crash", 4: "09_l2_explain"}), "completed")
	g = scene()
	g.coach._on_next()
	yield(frames(15), "completed")
	yield(play_lesson(2, {0: "10_l3_panel", 4: "11_l3_sensor"}), "completed")
	g = scene()
	g.coach._on_next()
	yield(frames(15), "completed")
	# Lesson 4 by hand: bridges by the solution, then the real Sorter tool and panel.
	g = scene()
	var l4 = TutorialData.get_lesson(3)
	for k in range(6):
		yield(exec(g, l4["solution"][k]), "completed")
	yield(frames(20), "completed")
	yield(shot("12_l4_bridges"), "completed")
	g.set_tool(C.Tool.SORTER)
	g._use_tool(Vector2(8, 7), true)
	yield(frames(20), "completed")
	expect("placing a sorter opens its panel", g.sorter_panel.visible and g.tutorial.current_step()["id"] == "l4_s5")
	yield(shot("13_l4_sorter_panel"), "completed")
	g.sorter_panel._on_pick(C.CargoColor.BLUE, Vector2(0, -1))
	g.sorter_panel._on_pick(C.CargoColor.RED, Vector2(0, 1))
	g.sorter_panel._on_apply()
	yield(frames(10), "completed")
	expect("applying different exits completes the sorter step", g.tutorial.current_step()["id"] == "l4_s6")
	g.set_speed(4.0)
	var guard = 0
	while not g.tutorial.done and guard < 9000:
		guard += 1
		yield(get_tree(), "idle_frame")
	expect("lesson l4 completed", g.tutorial.done)
	g = scene()
	g.coach._on_next()
	yield(frames(15), "completed")
	yield(play_lesson(4, {1: "14_l5_priority", 3: "15_l5_urgent"}), "completed")
	g = scene()
	g.coach._on_next()
	yield(frames(15), "completed")
	yield(play_lesson(5, {2: "16_l6_heatmap"}), "completed")
	g = scene()
	g.coach._on_next()
	yield(frames(15), "completed")

	# --- final test
	expect("final test scene", scene().lesson.get("final", false))
	yield(shot("17_final_intro"), "completed")
	Engine.time_scale = 4.0
	yield(play_lesson(6, {5: "18_final_built"}), "completed")
	Engine.time_scale = 1.0
	yield(wait_real(2.5), "completed")
	expect("passing the final test shows the completion screen", scene().name == "CompleteScreen")
	expect("tutorial is saved as done", not SaveData.is_first_run() and not SaveData.tutorial_skipped)
	yield(shot("19_complete"), "completed")

	# --- next launch goes straight to the menu
	yield(go("res://ui/boot.tscn"), "completed")
	yield(frames(10), "completed")
	expect("second launch goes to the main menu", scene().name == "MainMenu")
	yield(shot("20_menu"), "completed")
	scene()._on_language()
	yield(frames(15), "completed")
	expect("language switch reloads the menu in Russian", Strings.lang == "ru" and scene().name == "MainMenu")
	yield(shot("21_menu_ru"), "completed")

	# --- replaying the tutorial in Russian, then back to English
	scene()._on_tutorial()
	yield(frames(15), "completed")
	g = scene()
	g.coach._on_continue()
	yield(frames(10), "completed")
	yield(shot("22_l1_ru"), "completed")
	g.go_menu()
	yield(frames(10), "completed")
	scene()._on_language()
	yield(frames(10), "completed")
	expect("language is English again", Strings.lang == "en")

	# --- normal level with help overlay and a loss
	Levels.mode = "level"
	Levels.current = 0
	yield(go("res://view/game.tscn"), "completed")
	g = scene()
	expect("the level intro card lists three goals and pauses the run",
			g.intro != null and g.intro.visible and g.modal and g.speed == 0.0 and g.sim.goals.count() == 3)
	yield(frames(5), "completed")
	yield(shot("23a_level_intro"), "completed")
	g.intro.begin()
	yield(frames(5), "completed")
	expect("Start closes the intro card", not g.modal and not g.intro.visible)
	g.open_settings()
	yield(frames(5), "completed")
	yield(shot("23b_settings"), "completed")
	expect("settings pause the run and close again", g.modal and g.speed == 0.0)
	g.settings.close()
	g.set_speed(4.0)
	g.open_help()
	yield(frames(8), "completed")
	yield(shot("23_help"), "completed")
	expect("help pauses the simulation", g.speed == 0.0 and g.modal)
	g.help.close()
	expect("closing help restores the speed", g.speed == 4.0 and not g.modal)
	Engine.time_scale = 4.0
	n = 0
	while not g.sim.finished and n < 4000:
		n += 1
		yield(get_tree(), "idle_frame")
	Engine.time_scale = 1.0
	yield(wait_real(2.0), "completed")
	yield(shot("24_level_lost"), "completed")
	expect("an empty Level 1 ends in a loss", g.sim.result == "lose")

	# --- a winning run of Level 1 shows the goals while playing and the stars at the end
	SaveData.goal_masks = {}
	Levels.mode = "level"
	Levels.current = 0
	yield(go("res://view/game.tscn"), "completed")
	g = scene()
	g.intro.begin()
	g.sim.apply_solution()
	g.grid_view.update()
	g.set_speed(4.0)
	Engine.time_scale = 4.0
	n = 0
	while not g.sim.finished and n < 4000:
		n += 1
		if n == 60:
			yield(shot("25a_goals_hud"), "completed")
		yield(get_tree(), "idle_frame")
	Engine.time_scale = 1.0
	yield(wait_real(1.6), "completed")
	yield(shot("25b_results_midway"), "completed")
	yield(wait_real(2.6), "completed")
	yield(shot("25c_results_win"), "completed")
	expect("Level 1 solution wins", g.sim.result == "win")
	expect("three goals earned and saved", g.sim.goals.stars() == 3 and SaveData.get_stars(1) == 3)
	expect("results are visible", g.results.visible)
	yield(go("res://ui/level_select.tscn"), "completed")
	yield(frames(5), "completed")
	yield(shot("25d_level_select"), "completed")
	Levels.current = 0
	yield(go("res://view/game.tscn"), "completed")

	# --- restart five times: no growth in nodes
	var counts = []
	for i in range(5):
		scene().restart()
		yield(frames(10), "completed")
		counts.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	expect("node count is stable over restarts %s" % str(counts), counts[0] == counts[4])
	print("SMOKE DONE failures=%d" % failures)
	SaveData.delete_save()
	get_tree().quit()
