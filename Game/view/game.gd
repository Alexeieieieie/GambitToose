extends Node2D


const C = preload("res://sim/constants.gd")
const Sim = preload("res://sim/sim.gd")
const GridView = preload("res://view/grid_view.gd")
const VehicleLayer = preload("res://view/vehicle_layer.gd")
const BuildingLayer = preload("res://view/building_layer.gd")
const HeatmapLayer = preload("res://view/heatmap_layer.gd")
const FxLayer = preload("res://view/fx_layer.gd")
const Hud = preload("res://ui/hud.gd")
const LightPanel = preload("res://ui/light_panel.gd")
const SorterPanel = preload("res://ui/sorter_panel.gd")
const HelpOverlay = preload("res://ui/help_overlay.gd")
const ConfirmDialog = preload("res://ui/confirm_dialog.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const GoalsPanel = preload("res://ui/goals_panel.gd")
const LevelIntro = preload("res://ui/level_intro.gd")
const Goals = preload("res://sim/goals.gd")
const Results = preload("res://ui/results.gd")
const TutorialData = preload("res://tutorial/tutorial_data.gd")
const TutorialManager = preload("res://tutorial/tutorial_manager.gd")
const CoachPanel = preload("res://tutorial/coach_panel.gd")
const HighlightLayer = preload("res://tutorial/highlight_layer.gd")

const MAP_ORIGIN = Vector2(0, 56)
const TOOL_ORDER = [C.Tool.ROAD, C.Tool.BRIDGE, C.Tool.LIGHT, C.Tool.SORTER, C.Tool.ERASE]

var sim
var level = {}
var lesson = {}
var is_tutorial = false
var tutorial
var allowed_tools = []
var speed = 0.0
var last_speed = 1.0
var acc = 0.0
var current_tool = C.Tool.ROAD
var heatmap_on = false
var modal = false
var painting = false
var last_cell = C.NO_CELL
var ended = false
var siren_timer = 0.0
var help_prev_speed = 0.0
var overlay_prev_speed = 0.0

var world
var grid_view
var heatmap
var vehicle_layer
var building_layer
var fx
var hud
var light_panel
var sorter_panel
var help
var settings
var confirm
var goals_panel
var intro
var coach
var highlight
var results


func _ready() -> void:
	is_tutorial = Levels.mode == "tutorial"
	if is_tutorial:
		lesson = TutorialData.get_lesson(Levels.tutorial_index)
		level = lesson["level"]
		allowed_tools = level.get("allowed_tools", [])
	else:
		level = Levels.level()
	sim = Sim.new()
	sim.load_level(level)
	current_tool = _first_allowed_tool()

	world = Node2D.new()
	world.position = MAP_ORIGIN
	add_child(world)
	grid_view = _layer(GridView)
	heatmap = _layer(HeatmapLayer)
	vehicle_layer = _layer(VehicleLayer)
	building_layer = _layer(BuildingLayer)
	fx = _layer(FxLayer)

	var ui = CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	hud.setup(self)
	hud.connect("tool_chosen", self, "set_tool")
	hud.connect("speed_chosen", self, "set_speed")
	hud.connect("pause_pressed", self, "toggle_pause")
	hud.connect("heatmap_pressed", self, "toggle_heatmap")
	hud.connect("sound_pressed", self, "_on_sound")
	hud.connect("menu_pressed", self, "go_menu")
	hud.connect("help_pressed", self, "open_help")
	if not is_tutorial and sim.goals.count() > 0:
		goals_panel = GoalsPanel.new()
		ui.add_child(goals_panel)
		goals_panel.setup(sim)
	light_panel = LightPanel.new()
	ui.add_child(light_panel)
	light_panel.connect("applied", self, "_on_light_applied")
	light_panel.connect("closed", self, "_on_panel_closed")
	sorter_panel = SorterPanel.new()
	ui.add_child(sorter_panel)
	sorter_panel.connect("applied", self, "_on_sorter_applied")
	sorter_panel.connect("closed", self, "_on_panel_closed")
	help = HelpOverlay.new()
	ui.add_child(help)
	help.connect("closed", self, "_on_help_closed")
	settings = SettingsPanel.new()
	ui.add_child(settings)
	settings.connect("closed", self, "_on_settings_closed")
	if is_tutorial:
		_setup_tutorial(ui)
	confirm = ConfirmDialog.new()
	ui.add_child(confirm)
	confirm.connect("confirmed", self, "skip_tutorial")
	results = Results.new()
	ui.add_child(results)
	results.connect("restart_pressed", self, "restart")
	results.connect("next_pressed", self, "next_level")
	results.connect("menu_pressed", self, "go_menu")

	Sfx.start_level_audio(sim)
	Sfx.set_speed(1.0)
	Sfx.set_paused(true)
	if goals_panel != null:
		intro = LevelIntro.new()
		ui.add_child(intro)
		intro.setup(sim)
		intro.connect("started", self, "_on_intro_started")
		modal = true
	elif not is_tutorial:
		hud.toast(Strings.t("TOAST_PAUSED"), 4.0)


func _setup_tutorial(ui: CanvasLayer) -> void:
	light_panel.move_to_right()
	sorter_panel.move_to_right()
	tutorial = TutorialManager.new()
	coach = CoachPanel.new()
	ui.add_child(coach)
	coach.setup(self, tutorial)
	highlight = HighlightLayer.new()
	ui.add_child(highlight)
	highlight.setup(tutorial)
	tutorial.connect("step_changed", self, "_on_tutorial_step")
	tutorial.start(lesson, sim, Levels.tutorial_index + 1, TutorialData.lesson_count() - 1)


func _layer(a) -> Node2D:
	var n = a.new()
	world.add_child(n)
	n.setup(sim)
	return n


func _first_allowed_tool() -> int:
	for t in TOOL_ORDER:
		if is_tool_allowed(t):
			return t
	return C.Tool.ROAD


func is_tool_allowed(id: int) -> bool:
	return allowed_tools.empty() or allowed_tools.has(id)



func _process(a: float) -> void:
	_update_hover()
	if tutorial != null:
		tutorial.tick(a)
		_keep_panel_open()
	if sim.finished or modal:
		_drain_events()
		return
	acc += a * speed
	var n = 0
	while acc >= C.STEP and n < C.MAX_STEPS_PER_FRAME:
		sim.step(C.STEP)
		acc -= C.STEP
		n += 1
	if n == C.MAX_STEPS_PER_FRAME:
		acc = 0.0
	_drain_events()
	vehicle_layer.update()
	siren_timer += a
	if siren_timer >= 0.5:
		siren_timer = 0.0
		_update_siren()


func _keep_panel_open() -> void:
	if modal or ended or help.visible:
		return
	var a = tutorial.needs_panel()
	if a == "light" and sim.lights.size() > 0:
		_open_panel(sim.lights[0])
	elif a == "sorter" and sim.sorters.size() > 0:
		_open_panel(sim.sorters[0])


func _update_siren() -> void:
	var a = false
	if speed > 0.0:
		for v in sim.vehicles:
			if v.urgent:
				a = true
				break
	Sfx.set_siren(a)


func _drain_events() -> void:
	if sim.events.empty():
		return
	var a = sim.events
	sim.events = []
	for ev in a:
		var b = ev["type"]
		Sfx.handle_event(ev)
		if b == "deliver":
			fx.add("deliver", [ev["cell"]], 0.5, Palette.cargo(ev["color"]))
		elif b == "jam_start":
			hud.toast(Strings.t("TOAST_JAM"), 1.5)
		elif b == "crash":
			fx.add("crash", [ev["cell"]], 2.5)
			_apply_speed(0.0)
			if tutorial != null:
				tutorial.notify("crash")
		elif b == "deadlock_cycle":
			fx.add("deadlock", ev["cells"], 1.6)
			hud.toast(Strings.tf("TOAST_DEADLOCK", [sim.grid.label(ev["cells"][0])]), 2.5)
		elif b == "new_building":
			grid_view.update()
			Sfx.play("tutorial_step", 1.0, -4.0)
			fx.add("new", ev["cells"], 6.0)
			hud.toast(Strings.t("TOAST_NEW_BUILDING"), 4.0)
		elif b == "goal_reached" or b == "goal_failed":
			_on_goal_event(b, int(ev["index"]))
		elif b == "finished":
			_on_finished()


func _on_goal_event(a: String, b: int) -> void:
	if goals_panel == null:
		return
	goals_panel.pop(b)
	var c = "TOAST_GOAL_REACHED" if a == "goal_reached" else "TOAST_GOAL_MISSED"
	hud.toast(Strings.t(c) + "  " + goals_panel.goal_text(b), 2.6)


func _on_intro_started() -> void:
	modal = ended or help.visible or settings.visible
	hud.toast(Strings.t("TOAST_PAUSED"), 4.0)


func _on_finished() -> void:
	if ended:
		return
	ended = true
	modal = true
	painting = false
	Sfx.set_siren(false)
	var a = sim.won()
	var b = 0
	if sim.lose_cell != null:
		fx.add("crash", [sim.lose_cell], 3.0)
	if tutorial != null:
		tutorial.notify("level_won" if a else "level_lost")
	if is_tutorial and level.get("final_test", false) and a:
		Sfx.play("win")
		yield(get_tree().create_timer(1.4), "timeout")
		next_lesson()
		return
	if not is_tutorial:
		b = SaveData.save_result(level["id"], sim.metrics.score(), sim.goals.earned_mask())
	Sfx.results_started()
	Sfx.play("win" if a else "lose")
	yield(get_tree().create_timer(0.9), "timeout")
	results.show_result(sim, Levels.has_next() and not is_tutorial, b)



func _apply_speed(a: float) -> void:
	if a > 0.0:
		last_speed = a
	speed = a
	Sfx.set_speed(last_speed)
	Sfx.set_paused(speed == 0.0)
	if speed == 0.0:
		Sfx.set_siren(false)


func set_speed(a: float) -> void:
	var b = speed == 0.0
	if a != speed:
		if a == 0.0:
			Sfx.play("pause")
		elif b:
			Sfx.play("resume")
		elif a > speed:
			Sfx.play("speed_up")
		else:
			Sfx.play("speed_down")
	_apply_speed(a)
	if tutorial != null:
		if b and a > 0.0:
			tutorial.notify("speed_started")
		tutorial.notify("speed_set", {"value": a})


func toggle_pause() -> void:
	if speed > 0.0:
		set_speed(0.0)
	else:
		set_speed(last_speed)


func set_tool(id: int) -> void:
	if not is_tool_allowed(id):
		Sfx.play("invalid", 1.0, -3.0)
		return
	if id != current_tool:
		Sfx.play("tool_select")
	current_tool = id


func toggle_heatmap() -> void:
	heatmap_on = not heatmap_on
	heatmap.visible = heatmap_on
	heatmap.update()
	Sfx.play("ui_toggle_on" if heatmap_on else "ui_toggle_off")
	if tutorial != null:
		tutorial.notify("heatmap_toggled", {"on": heatmap_on})


func _on_sound() -> void:
	open_settings()


func open_settings() -> void:
	if settings.visible or help.visible or ended:
		return
	overlay_prev_speed = speed
	_apply_speed(0.0)
	modal = true
	painting = false
	settings.open()


func _on_settings_closed() -> void:
	modal = ended or light_panel.visible or sorter_panel.visible or help.visible \
			or (intro != null and intro.visible)
	if overlay_prev_speed > 0.0:
		_apply_speed(overlay_prev_speed)
	overlay_prev_speed = 0.0


func open_help() -> void:
	if help.visible or settings.visible or ended:
		return
	help_prev_speed = speed
	_apply_speed(0.0)
	modal = true
	painting = false
	help.open()


func _on_help_closed() -> void:
	modal = ended or light_panel.visible or sorter_panel.visible or (intro != null and intro.visible)
	if help_prev_speed > 0.0:
		_apply_speed(help_prev_speed)
	help_prev_speed = 0.0


func go_menu() -> void:
	Sfx.set_siren(false)
	get_tree().change_scene("res://ui/main_menu.tscn")


func restart() -> void:
	Sfx.set_siren(false)
	get_tree().reload_current_scene()


func next_level() -> void:
	if Levels.has_next():
		Levels.current += 1
	get_tree().reload_current_scene()


func next_lesson() -> void:
	Levels.tutorial_index += 1
	if Levels.tutorial_index >= TutorialData.lesson_count():
		get_tree().change_scene("res://tutorial/complete_screen.tscn")
	else:
		get_tree().reload_current_scene()


func ask_skip_tutorial() -> void:
	confirm.open()


func skip_tutorial() -> void:
	if SaveData.is_first_run():
		SaveData.finish_tutorial(true)
	get_tree().change_scene("res://ui/main_menu.tscn")


func _on_tutorial_step(a) -> void:
	if a.get("pause_sim", false):
		_apply_speed(0.0)


func _unhandled_input(a: InputEvent) -> void:
	if a is InputEventKey:
		if a.pressed and not a.echo:
			_on_key(a.scancode)
		return
	if modal or ended:
		return
	if a is InputEventMouseButton and a.button_index == BUTTON_LEFT:
		if a.pressed:
			painting = true
			last_cell = C.NO_CELL
			_use_tool(_mouse_cell(), true)
		else:
			painting = false
	elif a is InputEventMouseMotion and painting:
		_drag_to(_mouse_cell())


func _on_key(a: int) -> void:
	if a == KEY_F3:
		hud.fps_on = not hud.fps_on
		return
	if a == KEY_F1:
		if help.visible:
			help.close()
		else:
			open_help()
		return
	if a == KEY_G and goals_panel != null:
		goals_panel.toggle()
		return
	if intro != null and intro.visible and (a == KEY_ENTER or a == KEY_KP_ENTER or a == KEY_SPACE):
		intro.begin()
		return
	if a == KEY_ESCAPE:
		if settings.visible:
			settings.close()
		elif help.visible:
			help.close()
		elif intro != null and intro.visible:
			go_menu()
		elif confirm.visible:
			confirm.visible = false
		elif light_panel.visible or sorter_panel.visible:
			light_panel.visible = false
			sorter_panel.visible = false
			_on_panel_closed()
		else:
			go_menu()
		return
	if a == KEY_R:
		restart()
		return
	if modal or ended:
		return
	if a == KEY_SPACE:
		toggle_pause()
	elif a == KEY_1:
		set_speed(1.0)
	elif a == KEY_2:
		set_speed(2.0)
	elif a == KEY_3:
		set_speed(4.0)
	elif a == KEY_H:
		toggle_heatmap()



func _mouse_cell() -> Vector2:
	return (world.get_local_mouse_position() / C.TILE).floor()


func _update_hover() -> void:
	var a = _mouse_cell()
	fx.hover_cell = a
	fx.hover_show = not modal and not ended and sim.grid.in_bounds(a) \
			and get_viewport().get_mouse_position().y < 656.0
	fx.hover_ok = _can_use(a)


func _can_use(a: Vector2) -> bool:
	if sim.grid.controllers.has(a) and current_tool != C.Tool.ERASE:
		return true
	if current_tool == C.Tool.ROAD:
		return sim.can_build_road(a)
	if current_tool == C.Tool.BRIDGE:
		return sim.can_build_bridge(a)
	if current_tool == C.Tool.LIGHT:
		return sim.can_place_controller(a, "light")
	if current_tool == C.Tool.SORTER:
		return sim.can_place_controller(a, "sorter")
	if current_tool == C.Tool.ERASE:
		return sim.can_erase(a)
	return false


func _drag_to(a: Vector2) -> void:
	if current_tool != C.Tool.ROAD and current_tool != C.Tool.ERASE and current_tool != C.Tool.BRIDGE:
		return
	if last_cell == C.NO_CELL:
		_use_tool(a, false)
		return
	var b = 0
	while last_cell != a and b < 64:
		b += 1
		var d = a - last_cell
		var c = Vector2(sign(d.x), 0) if abs(d.x) >= abs(d.y) else Vector2(0, sign(d.y))
		_use_tool(last_cell + c, false)


func _deny(a: String, b: int = -1) -> void:
	hud.toast(a)
	Sfx.play("invalid")
	if b != -1:
		hud.flash_tool(b)


func _use_tool(a: Vector2, b: bool) -> void:
	last_cell = a
	if not sim.grid.in_bounds(a):
		return
	var c = sim.grid.controllers.get(a)
	if c != null and current_tool != C.Tool.ERASE:
		if b:
			_open_panel(c)
		return
	var e = false
	var f = "place_road"
	if current_tool == C.Tool.ROAD:
		e = sim.build_road(a)
		if not e and b:
			if sim.inventory["road"] <= 0 and sim.grid.tile(a) == C.Tile.EMPTY:
				_deny(Strings.t("TOAST_NO_ITEMS"), C.Tool.ROAD)
			elif sim.grid.tile(a) != C.Tile.EMPTY or sim.grid.reserved.has(a):
				Sfx.play("invalid")
	elif current_tool == C.Tool.BRIDGE:
		f = "place_bridge"
		e = sim.build_bridge(a)
		if not e and b:
			if sim.grid.tile(a) != C.Tile.WATER:
				_deny(Strings.t("TOAST_NEED_WATER"))
			elif sim.inventory["bridge"] <= 0:
				_deny(Strings.t("TOAST_NO_ITEMS"), C.Tool.BRIDGE)
	elif current_tool == C.Tool.LIGHT or current_tool == C.Tool.SORTER:
		if not b:
			return
		var g = "light" if current_tool == C.Tool.LIGHT else "sorter"
		var h = sim.place_light(a) if g == "light" else sim.place_sorter(a)
		if h != null:
			e = true
			f = "place_light" if g == "light" else "place_sorter"
			_open_panel(h)
		elif sim.inventory[g] <= 0:
			_deny(Strings.t("TOAST_NO_ITEMS"), current_tool)
		else:
			_deny(Strings.t("TOAST_NEED_JUNCTION"))
	elif current_tool == C.Tool.ERASE:
		if sim.erase(a) != "":
			Sfx.play("erase")
			fx.add("erase", [a], 0.3)
			grid_view.update()
			_tell_tutorial_changed()
		return
	if e:
		Sfx.play(f)
		fx.add("pop", [a], 0.3)
		grid_view.update()
		_tell_tutorial_changed()


func _tell_tutorial_changed() -> void:
	if tutorial != null:
		tutorial.notify("changed")


func _open_panel(a) -> void:
	painting = false
	modal = true
	Sfx.play("panel_open")
	var b = sim.grid.label(a.cell)
	if a.is_sorter:
		sorter_panel.open(a, sim.pathing.valid_dirs(sim.grid, a.cell), b)
	else:
		light_panel.open(a, b)


func _on_light_applied(a, b, c, e, f) -> void:
	sim.configure_light(a, b, c, e, f)
	_tell_tutorial_changed()


func _on_sorter_applied(a, b) -> void:
	sim.configure_sorter(a, b)
	_tell_tutorial_changed()


func _on_panel_closed() -> void:
	Sfx.play("panel_close")
	modal = ended or help.visible
