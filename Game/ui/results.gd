extends Control

# The win or lose screen: title, stars, three stats, one concrete hint.

signal restart_pressed
signal next_pressed
signal menu_pressed

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")
const GoalIcon = preload("res://ui/goal_icon.gd")
const Goals = preload("res://sim/goals.gd")

const SCREEN = Vector2(1280, 720)
const CARD = Rect2(240, 50, 800, 620)
const STAR_STEP = 0.6            # seconds between the stars
const STAR_START = 0.4

var title_text = ""
var stars = 0
var goal_rows = []               # [text, result text, status, is_new]
var sounded = {}
var new_bits = 0
var won = false
var stats = []                   # [caption, value]
var hint_text = ""
var score_text = ""
var card
var hint_label
var next_btn
var tween
var age = 0.0


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	visible = false
	var dim = ColorRect.new()
	dim.color = Palette.alpha(Palette.NAVY, 0.7)
	dim.rect_size = SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	card = Panel.new()
	card.rect_position = CARD.position
	card.rect_size = CARD.size
	card.rect_pivot_offset = CARD.size / 2.0
	card.add_stylebox_override("panel", ThemeBuilder.box(Palette.CARD, 24, 4, Palette.YELLOW))
	card.connect("draw", self, "_draw_card")
	add_child(card)
	hint_label = ThemeBuilder.label("", Rect2(50, 436, 700, 72), 17, true, Palette.NAVY, true)
	card.add_child(hint_label)
	var menu = ThemeBuilder.button(Strings.t("MENU"), Rect2(40, 538, 170, 56), 18)
	menu.connect("pressed", self, "_on_menu")
	card.add_child(menu)
	var again = ThemeBuilder.button(Strings.t("RESTART"), Rect2(226, 538, 220, 56), 18)
	again.connect("pressed", self, "_on_restart")
	card.add_child(again)
	next_btn = ThemeBuilder.button(Strings.t("NEXT_LEVEL"), Rect2(462, 538, 298, 56), 18)
	ThemeBuilder.paint(next_btn, Palette.YELLOW, Palette.NAVY)
	next_btn.connect("pressed", self, "_on_next")
	card.add_child(next_btn)
	tween = Tween.new()
	add_child(tween)


func show_result(sim, has_next: bool, new_goal_bits: int = 0) -> void:
	var m = sim.metrics
	won = sim.won()
	new_bits = new_goal_bits
	stars = sim.goals.stars()
	goal_rows = []
	sounded = {}
	for i in range(sim.goals.count()):
		var type = sim.goals.type_of(i)
		var text = Strings.t(Goals.text_key(type)) if type == "complete" else Strings.tf(Goals.text_key(type), [int(sim.goals.value_of(i))])
		var res = "" if type == "complete" else Strings.tf(Goals.result_key(type), sim.goals.result_args(i, sim))
		var done = sim.goals.status[i] == Goals.Status.DONE
		goal_rows.append([text, res, sim.goals.status[i], done and (new_goal_bits & (1 << i)) != 0])
	if sim.result == "win":
		title_text = Strings.t("WIN_TITLE")
	elif sim.result == "finished":
		title_text = Strings.t("FINISH_TITLE")
	elif sim.lose_reason == "patience":
		title_text = Strings.t("LOSE_PATIENCE")
	elif sim.lose_reason == "time":
		title_text = Strings.t("LOSE_TIME")
	else:
		title_text = Strings.t("LOSE_GRIDLOCK")
	score_text = Strings.tf("SCORE", [m.score()])
	stats = [
		[Strings.t("DELIVERED"), str(m.deliveries) if sim.mode != "goal" else Strings.tf("PROGRESS", [m.deliveries, sim.goal])],
		[Strings.t("AVG_DELIVERY"), Strings.tf("SECONDS", [m.avg_delivery_time()])],
		[Strings.t("TIME_IN_JAMS"), Strings.tf("SECONDS", [m.jam_seconds])],
	]
	hint_text = make_hint(sim)
	hint_label.text = hint_text
	next_btn.visible = has_next
	next_btn.disabled = not won
	if not won:
		ThemeBuilder.paint(next_btn, Palette.STAR_OFF, Palette.NAVY_LIGHT)
	age = 0.0
	visible = true
	tween.interpolate_property(card, "rect_scale", Vector2(0.7, 0.7), Vector2(1, 1), 0.35,
			Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()


func _near(sim, cell: Vector2, radius: int, what: String):
	# Finds the closest light, junction or water tile around a cell.
	var best = null
	var best_d = 999.0
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var c = cell + Vector2(x, y)
			var hit = false
			if what == "light":
				var ctrl = sim.grid.controllers.get(c)
				hit = ctrl != null and not ctrl.is_sorter
			elif what == "junction":
				hit = sim.grid.is_junction(c)
			elif what == "water":
				var t = sim.grid.tile(c)
				hit = sim.grid.in_bounds(c) and (t == C.Tile.WATER or t == C.Tile.BRIDGE)
			var d = abs(x) + abs(y)
			if hit and d < best_d:
				best_d = d
				best = c
	return best


func make_hint(sim) -> String:
	var g = sim.grid
	if sim.result == "lose" and sim.lose_reason == "patience" and sim.lose_cell != null:
		return Strings.t("HINT_PATIENCE")
	var worst = sim.metrics.worst_jam_cell()
	if sim.result != "lose":
		var bad = sim.goals.first_failed()
		if bad == -1:
			return Strings.t("HINT_PERFECT")
		var type = sim.goals.type_of(bad)
		if type == "time_left_min" or type == "avg_delivery_max":
			return Strings.t("HINT_G_FASTER")
		if type == "urgent_min":
			return Strings.t("HINT_G_URGENT")
		if type == "patience_min":
			return Strings.t("HINT_G_PATIENCE")
		if type == "roads_max":
			return Strings.t("HINT_G_ROADS")
		if type == "deliver_min" or type == "score_min":
			return Strings.t("HINT_G_SCORE")
		# jam_seconds_max falls through to the jam location hint below
	if sim.result == "lose" and sim.lose_reason == "gridlock":
		var at = worst
		if sim.last_deadlock.size() > 0:
			at = sim.last_deadlock[0]
		if at == null and sim.vehicles.size() > 0:
			at = sim.vehicles[0].cell
		if at != null:
			return Strings.tf("HINT_GRIDLOCK", [g.label(at)])
		return Strings.t("HINT_NO_JAM_LOSS")
	if worst == null or sim.metrics.jam_seconds < 5.0:
		if sim.result == "lose":
			return Strings.t("HINT_TIME")
		return Strings.t("HINT_CLEAN")
	var where = g.label(worst)
	var light_cell = _near(sim, worst, 5, "light")
	if light_cell != null and g.controllers[light_cell].mode == C.LightMode.TIMER:
		return Strings.tf("HINT_SENSOR", [where])
	if light_cell == null and _near(sim, worst, 5, "junction") != null and sim.inventory["light"] > 0:
		return Strings.tf("HINT_LIGHT", [where])
	if _near(sim, worst, 3, "water") != null and sim.inventory["bridge"] > 0:
		return Strings.tf("HINT_BRIDGE", [where])
	if sim.inventory["sorter"] > 0:
		return Strings.tf("HINT_SORTER", [where])
	if sim.inventory["light"] > 0:
		return Strings.tf("HINT_LIGHT", [where])
	return Strings.tf("HINT_SORTER", [where])


func _process(delta: float) -> void:
	if visible:
		age += delta
		_star_sounds()
		card.update()


func _star_time(i: int) -> float:
	return STAR_START + i * STAR_STEP


func _star_sounds() -> void:
	var earned = 0
	for i in range(goal_rows.size()):
		if goal_rows[i][2] != Goals.Status.DONE:
			continue
		earned += 1
		if age >= _star_time(i) and not sounded.has(i):
			sounded[i] = true
			Sfx.play("star_%d" % int(clamp(earned, 1, 3)))


func _draw_card() -> void:
	var w = CARD.size.x
	DrawUtil.centered(card, Fonts.make(42, true), Vector2(w / 2.0, 50), title_text,
			Palette.NAVY if won else Palette.RED_DARK)
	# Stars appear one by one, 0.6 s apart. An earned star is gold, an unearned one is gray with an outline.
	for i in range(3):
		var c = Vector2(w / 2.0 + (i - 1) * 100.0, 118 - (8 if i == 1 else 0))
		var shown = age >= _star_time(i)
		var got = i < goal_rows.size() and goal_rows[i][2] == Goals.Status.DONE
		DrawUtil.star(card, c, 38.0, Palette.NAVY)
		var grow = 1.0
		if shown and got:
			grow = 1.0 + 0.3 * max(0.0, 1.0 - (age - _star_time(i)) * 4.0)
		DrawUtil.star(card, c, 31.0 * grow, Palette.YELLOW if (shown and got) else Palette.STAR_OFF)
	DrawUtil.centered(card, Fonts.make(22, true), Vector2(w / 2.0, 176), score_text, Palette.NAVY)
	var f = Fonts.make(17, false)
	var fb = Fonts.make(17, true)
	for i in range(goal_rows.size()):
		var row = goal_rows[i]
		var y = 200.0 + i * 42.0
		card.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.1), 12), Rect2(40, y, 720, 38))
		var state = row[2] if age >= _star_time(i) else GoalIcon.PENDING
		GoalIcon.draw(card, Vector2(66, y + 19), 13.0, state, Palette.CARD)
		DrawUtil.left(card, f, Vector2(92, y + 19), row[0], Palette.NAVY)
		if row[1] != "":
			var rw = f.get_string_size(row[1]).x
			DrawUtil.left(card, f, Vector2(676 - rw, y + 19), row[1], Palette.NAVY_LIGHT)
		if row[3] and age >= _star_time(i):
			card.draw_style_box(ThemeBuilder.box(Palette.YELLOW, 10), Rect2(684, y + 6, 66, 26))
			DrawUtil.centered(card, fb, Vector2(717, y + 19), Strings.t("NEW_BADGE"), Palette.NAVY)
	for i in range(stats.size()):
		var r = Rect2(40 + i * 244, 334, 232, 88)
		card.draw_style_box(ThemeBuilder.box(Palette.NAVY_MID, 16), r)
		DrawUtil.centered(card, Fonts.make(14, true), r.position + Vector2(r.size.x / 2.0, 24), stats[i][0], Palette.TEXT_DIM)
		DrawUtil.centered(card, Fonts.make(24, true), r.position + Vector2(r.size.x / 2.0, 58), stats[i][1], Palette.WHITE)
	card.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.YELLOW, 0.35), 12), Rect2(40, 432, 720, 84))


func _on_restart() -> void:
	Sfx.play("ui_click")
	emit_signal("restart_pressed")


func _on_next() -> void:
	Sfx.play("ui_click")
	emit_signal("next_pressed")


func _on_menu() -> void:
	Sfx.play("ui_click")
	emit_signal("menu_pressed")
