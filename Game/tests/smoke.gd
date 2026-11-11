extends Node

# Drives the real scenes end to end and saves screenshots. Development aid:
#   godot --path . res://tests/smoke.tscn
# Screenshots go to the folder in the SMOKE_OUT environment variable (default user://).

const C = preload("res://sim/constants.gd")

var out_dir = "user://"
var errors = 0


func _ready() -> void:
	if OS.has_environment("SMOKE_OUT"):
		out_dir = OS.get_environment("SMOKE_OUT") + "/"
	call_deferred("_run")


func frames(n: int) -> void:
	for _i in range(n):
		yield(get_tree(), "idle_frame")


func wait_real(seconds: float) -> void:
	var until = OS.get_ticks_msec() + int(seconds * 1000.0)
	while OS.get_ticks_msec() < until:
		yield(get_tree(), "idle_frame")


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


func mouse_checks() -> void:
	# Real input path: drag a road, click the toolbar, erase, press keys.
	var g = game()
	var before = g.sim.inventory["road"]
	move(cell_px(Vector2(3, 2)))
	yield(frames(3), "completed")
	click(cell_px(Vector2(3, 2)), true)
	yield(frames(3), "completed")
	for x in [4, 5, 6, 7]:
		move(cell_px(Vector2(x, 2)))
		yield(frames(3), "completed")
	click(cell_px(Vector2(7, 2)), false)
	yield(frames(3), "completed")
	print("drag built %d road tiles (expected 5)" % (before - g.sim.inventory["road"]))
	# A click on the toolbar must choose a tool and build nothing.
	var erase_btn = g.hud.tool_btns[C.Tool.ERASE]
	var at = erase_btn.rect_position + erase_btn.rect_size / 2.0
	move(at)
	yield(frames(3), "completed")
	click(at, true)
	yield(frames(2), "completed")
	click(at, false)
	yield(frames(3), "completed")
	print("tool after toolbar click = %d (expected %d)" % [g.current_tool, C.Tool.ERASE])
	for x in [3, 4, 5, 6, 7]:
		move(cell_px(Vector2(x, 2)))
		yield(frames(2), "completed")
		click(cell_px(Vector2(x, 2)), true)
		yield(frames(2), "completed")
		click(cell_px(Vector2(x, 2)), false)
		yield(frames(2), "completed")
	print("after erase: road inventory back to start = %s" % (g.sim.inventory["road"] == before))
	for code in [KEY_SPACE, KEY_3, KEY_H, KEY_F3]:
		var ev = InputEventKey.new()
		ev.scancode = code
		ev.pressed = true
		Input.parse_input_event(ev)
		yield(frames(3), "completed")
	print("keys: speed=%s heatmap=%s fps=%s" % [g.speed, g.heatmap_on, g.hud.fps_on])
	g.toggle_heatmap()
	g.set_speed(0.0)
	g.set_tool(C.Tool.ROAD)


func shot(name: String) -> void:
	yield(VisualServer, "frame_post_draw")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(out_dir + name + ".png")
	print("shot " + name)


func game():
	return get_tree().current_scene


func run_until_finished(max_frames: int) -> void:
	var n = 0
	while not game().sim.finished and n < max_frames:
		n += 1
		yield(get_tree(), "idle_frame")
	print("finished=%s result=%s reason=%s t=%.0f deliveries=%d fps=%d nodes=%d vehicles=%d" % [
			game().sim.finished, game().sim.result, game().sim.lose_reason, game().sim.time,
			game().sim.metrics.deliveries, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), game().sim.vehicles.size()])


func _run() -> void:
	get_tree().current_scene = null
	get_tree().change_scene("res://ui/main_menu.tscn")
	yield(frames(20), "completed")
	yield(shot("01_menu"), "completed")
	get_tree().change_scene("res://ui/level_select.tscn")
	yield(frames(10), "completed")
	yield(shot("02_levels"), "completed")

	# Level 1: build the road, run to the scripted crash, place a sensor light, win.
	Levels.current = 0
	get_tree().change_scene("res://view/game.tscn")
	yield(frames(10), "completed")
	yield(shot("03_l1_start"), "completed")
	var g = game()
	g.sim.apply_action({"type": "road_line", "from": Vector2(3, 7), "to": Vector2(28, 7)})
	g.grid_view.update()
	yield(frames(5), "completed")
	Engine.time_scale = 4.0
	g.set_speed(4.0)
	var n = 0
	while not g.crash_seen and n < 2000:
		n += 1
		yield(get_tree(), "idle_frame")
	print("crash_seen=%s at t=%.1f speed=%s step=%s" % [g.crash_seen, g.sim.time, g.speed, g.tutorial.current_id()])
	yield(frames(10), "completed")
	yield(shot("04_l1_crash"), "completed")
	g.set_tool(C.Tool.LIGHT)
	g._use_tool(g.crash_cell, true)
	yield(frames(10), "completed")
	yield(shot("05_light_panel"), "completed")
	g.light_panel._on_mode(C.LightMode.SENSOR)
	yield(frames(40), "completed")
	yield(shot("06_light_panel_sensor"), "completed")
	g.light_panel._on_apply()
	g.set_speed(4.0)
	yield(frames(30), "completed")
	yield(shot("07_l1_running"), "completed")
	yield(run_until_finished(4000), "completed")
	yield(wait_real(2.0), "completed")
	yield(shot("08_l1_results"), "completed")

	# Level 2: intended solution with the heatmap on.
	g.next_level()
	yield(frames(10), "completed")
	g = game()
	yield(shot("09_l2_start"), "completed")
	yield(mouse_checks(), "completed")
	g.sim.apply_solution()
	g.grid_view.update()
	g.toggle_heatmap()
	g.set_speed(4.0)
	yield(frames(260), "completed")
	yield(shot("10_l2_heatmap"), "completed")
	g._open_panel(g.sim.sorters[0])
	yield(frames(10), "completed")
	yield(shot("11_sorter_panel"), "completed")
	g.sorter_panel._on_cancel()
	g.toggle_heatmap()
	yield(frames(200), "completed")
	yield(shot("12_l2_running"), "completed")
	yield(run_until_finished(6000), "completed")
	yield(wait_real(2.0), "completed")
	yield(shot("13_l2_results"), "completed")

	# Level 3 with no roads at all: must end in a patience loss.
	g.next_level()
	yield(frames(10), "completed")
	g = game()
	g.set_speed(4.0)
	yield(run_until_finished(3000), "completed")
	yield(wait_real(2.0), "completed")
	yield(shot("14_l3_lose"), "completed")

	# Restart five times and watch the node count.
	for i in range(5):
		game().restart()
		yield(frames(8), "completed")
		game().sim.apply_solution()
		game().grid_view.update()
		game().set_speed(4.0)
		yield(frames(150), "completed")
		print("restart %d: nodes=%d vehicles=%d t=%.0f" % [i + 1,
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), game().sim.vehicles.size(), game().sim.time])
	yield(shot("15_l3_running"), "completed")
	yield(run_until_finished(8000), "completed")
	yield(wait_real(2.0), "completed")
	yield(shot("16_l3_results"), "completed")
	Engine.time_scale = 1.0
	print("SMOKE DONE")
	get_tree().quit()
