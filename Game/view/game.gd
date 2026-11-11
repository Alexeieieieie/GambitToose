extends Node2D

# The level scene. Runs the simulation at a fixed timestep, turns mouse input into
# build commands, and plays sounds and effects for simulation events.
# Nothing here ever addresses a vehicle: the player builds roads and sets rules only.

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
const TutorialOverlay = preload("res://ui/tutorial_overlay.gd")
const Results = preload("res://ui/results.gd")

const MAP_ORIGIN = Vector2(0, 56)

var sim
var level = {}
var speed = 0.0                  # 0 (pause), 1, 2, 4
var last_speed = 1.0
var acc = 0.0
var current_tool = C.Tool.ROAD
var heatmap_on = false
var modal = false                # a panel or the results screen is open
var painting = false
var last_cell = C.NO_CELL
var crash_seen = false
var crash_cell = C.NO_CELL
var ended = false
var siren_timer = 0.0

var world
var grid_view
var heatmap
var vehicle_layer
var building_layer
var fx
var hud
var light_panel
var sorter_panel
var tutorial
var results


func _ready() -> void:
	level = Levels.level()
	sim = Sim.new()
	sim.load_level(level)

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
	if level.get("tutorial", false):
		tutorial = TutorialOverlay.new()
		ui.add_child(tutorial)
		tutorial.setup(self)
	light_panel = LightPanel.new()
	ui.add_child(light_panel)
	light_panel.connect("applied", self, "_on_light_applied")
	light_panel.connect("closed", self, "_on_panel_closed")
	sorter_panel = SorterPanel.new()
	ui.add_child(sorter_panel)
	sorter_panel.connect("applied", self, "_on_sorter_applied")
	sorter_panel.connect("closed", self, "_on_panel_closed")
	results = Results.new()
	ui.add_child(results)
	results.connect("restart_pressed", self, "restart")
	results.connect("next_pressed", self, "next_level")
	results.connect("menu_pressed", self, "go_menu")

	Sfx.set_speed(1.0)
	Sfx.reset_streak()
	hud.toast(Strings.TOAST_PAUSED, 4.0)


func _layer(script) -> Node2D:
	var n = script.new()
	world.add_child(n)
	n.setup(sim)
	return n


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	_update_hover()
	if sim.finished or modal:
		_drain_events()
		return
	acc += delta * speed
	var n = 0
	while acc >= C.STEP and n < C.MAX_STEPS_PER_FRAME:
		sim.step(C.STEP)
		acc -= C.STEP
		n += 1
	if n == C.MAX_STEPS_PER_FRAME:
		acc = 0.0                # drop the backlog so 4x never freezes the game
	_drain_events()
	vehicle_layer.update()
	siren_timer += delta
	if siren_timer >= 0.5:
		siren_timer = 0.0
		_update_siren()


func _update_siren() -> void:
	var urgent = false
	if speed > 0.0:
		for v in sim.vehicles:
			if v.urgent:
				urgent = true
				break
	Sfx.set_siren(urgent)


func _drain_events() -> void:
	if sim.events.empty():
		return
	var list = sim.events
	sim.events = []
	for ev in list:
		var kind = ev["type"]
		if kind == "deliver":
			Sfx.delivery_sound(ev["jam"])
			fx.add("deliver", [ev["cell"]], 0.5, Palette.cargo(ev["color"]))
		elif kind == "jam_start":
			Sfx.warn()
			Sfx.reset_streak()
			hud.toast(Strings.TOAST_JAM, 1.5)
		elif kind == "light_switch":
			Sfx.play("tick", 1.0, -10.0)
		elif kind == "crash":
			crash_seen = true
			crash_cell = ev["cell"]
			Sfx.play("crash")
			fx.add("crash", [ev["cell"]], 2.5)
			hud.toast(Strings.TUT_CRASH, 3.0)
			set_speed(0.0)
		elif kind == "deadlock_cycle":
			fx.add("deadlock", ev["cells"], 1.6)
			hud.toast(Strings.TOAST_DEADLOCK % sim.grid.label(ev["cells"][0]), 2.5)
		elif kind == "new_building":
			grid_view.update()
			Sfx.play("place", 0.7)
			fx.add("new", ev["cells"], 6.0)
			hud.toast(Strings.TOAST_NEW_BUILDING, 4.0)
		elif kind == "finished":
			_on_finished()


func _on_finished() -> void:
	if ended:
		return
	ended = true
	modal = true
	painting = false
	Sfx.set_siren(false)
	var won = sim.won()
	Levels.save_result(level["id"], sim.metrics.score(), sim.metrics.stars(won))
	Sfx.play("win" if won else "lose")
	if sim.lose_cell != null:
		fx.add("crash", [sim.lose_cell], 3.0)
	yield(get_tree().create_timer(0.9), "timeout")
	results.show_result(sim, Levels.has_next())


# ---------------------------------------------------------------- controls

func set_speed(value: float) -> void:
	if value > 0.0:
		last_speed = value
	speed = value
	Sfx.set_speed(last_speed)
	if speed == 0.0:
		Sfx.set_siren(false)


func toggle_pause() -> void:
	if speed > 0.0:
		set_speed(0.0)
	else:
		set_speed(last_speed)


func set_tool(id: int) -> void:
	current_tool = id


func toggle_heatmap() -> void:
	heatmap_on = not heatmap_on
	heatmap.visible = heatmap_on
	heatmap.update()


func _on_sound() -> void:
	Sfx.toggle()


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			_on_key(event.scancode)
		return
	if modal or ended:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			painting = true
			last_cell = C.NO_CELL
			_use_tool(_mouse_cell(), true)
		else:
			painting = false
	elif event is InputEventMouseMotion and painting:
		_drag_to(_mouse_cell())


func _on_key(code: int) -> void:
	if code == KEY_F3:
		hud.fps_on = not hud.fps_on
		return
	if code == KEY_ESCAPE:
		if light_panel.visible or sorter_panel.visible:
			light_panel.visible = false
			sorter_panel.visible = false
			_on_panel_closed()
		else:
			go_menu()
		return
	if code == KEY_R:
		restart()
		return
	if modal or ended:
		return
	if code == KEY_SPACE:
		toggle_pause()
	elif code == KEY_1:
		set_speed(1.0)
	elif code == KEY_2:
		set_speed(2.0)
	elif code == KEY_3:
		set_speed(4.0)
	elif code == KEY_H:
		toggle_heatmap()


# ---------------------------------------------------------------- building

func _mouse_cell() -> Vector2:
	return (world.get_local_mouse_position() / C.TILE).floor()


func _update_hover() -> void:
	var cell = _mouse_cell()
	fx.hover_cell = cell
	fx.hover_show = not modal and not ended and sim.grid.in_bounds(cell) \
			and get_viewport().get_mouse_position().y < 656.0
	fx.hover_ok = _can_use(cell)


func _can_use(cell: Vector2) -> bool:
	if sim.grid.controllers.has(cell) and current_tool != C.Tool.ERASE:
		return true
	if current_tool == C.Tool.ROAD:
		return sim.can_build_road(cell)
	if current_tool == C.Tool.BRIDGE:
		return sim.can_build_bridge(cell)
	if current_tool == C.Tool.LIGHT:
		return sim.can_place_controller(cell, "light")
	if current_tool == C.Tool.SORTER:
		return sim.can_place_controller(cell, "sorter")
	if current_tool == C.Tool.ERASE:
		return sim.can_erase(cell)
	return false


func _drag_to(cell: Vector2) -> void:
	# Fill in the cells between two mouse samples so fast drags leave no gaps.
	if current_tool != C.Tool.ROAD and current_tool != C.Tool.ERASE and current_tool != C.Tool.BRIDGE:
		return
	if last_cell == C.NO_CELL:
		_use_tool(cell, false)
		return
	var guard = 0
	while last_cell != cell and guard < 64:
		guard += 1
		var d = cell - last_cell
		var step = Vector2(sign(d.x), 0) if abs(d.x) >= abs(d.y) else Vector2(0, sign(d.y))
		_use_tool(last_cell + step, false)


func _use_tool(cell: Vector2, is_click: bool) -> void:
	last_cell = cell
	if not sim.grid.in_bounds(cell):
		return
	var ctrl = sim.grid.controllers.get(cell)
	if ctrl != null and current_tool != C.Tool.ERASE:
		if is_click:
			_open_panel(ctrl)
		return
	var built = false
	if current_tool == C.Tool.ROAD:
		built = sim.build_road(cell)
		if not built and is_click and sim.inventory["road"] <= 0 and sim.grid.tile(cell) == C.Tile.EMPTY:
			hud.toast(Strings.TOAST_NO_ITEMS)
	elif current_tool == C.Tool.BRIDGE:
		built = sim.build_bridge(cell)
		if not built and is_click:
			if sim.grid.tile(cell) != C.Tile.WATER:
				hud.toast(Strings.TOAST_NEED_WATER)
			elif sim.inventory["bridge"] <= 0:
				hud.toast(Strings.TOAST_NO_ITEMS)
	elif current_tool == C.Tool.LIGHT or current_tool == C.Tool.SORTER:
		if not is_click:
			return
		var kind = "light" if current_tool == C.Tool.LIGHT else "sorter"
		var placed = sim.place_light(cell) if kind == "light" else sim.place_sorter(cell)
		if placed != null:
			built = true
			_open_panel(placed)
		elif sim.inventory[kind] <= 0:
			hud.toast(Strings.TOAST_NO_ITEMS)
		else:
			hud.toast(Strings.TOAST_NEED_JUNCTION)
	elif current_tool == C.Tool.ERASE:
		if sim.erase(cell) != "":
			Sfx.play("erase")
			fx.add("erase", [cell], 0.3)
			grid_view.update()
		return
	if built:
		Sfx.play("place", 1.0 + randf() * 0.15)
		fx.add("pop", [cell], 0.3)
		grid_view.update()


func _open_panel(ctrl) -> void:
	painting = false
	modal = true
	var where = sim.grid.label(ctrl.cell)
	if ctrl.is_sorter:
		sorter_panel.open(ctrl, sim.pathing.valid_dirs(sim.grid, ctrl.cell), where)
	else:
		light_panel.open(ctrl, where)


func _on_light_applied(cell, mode, period, threshold, urgent_first) -> void:
	sim.configure_light(cell, mode, period, threshold, urgent_first)


func _on_sorter_applied(cell, rules) -> void:
	sim.configure_sorter(cell, rules)


func _on_panel_closed() -> void:
	modal = ended
