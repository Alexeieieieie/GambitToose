extends Control

# The win or lose screen: title, stars, three stats, one concrete hint.

signal restart_pressed
signal next_pressed
signal menu_pressed

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const CARD = Rect2(290, 70, 700, 580)

var title_text = ""
var stars = 0
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
	hint_label = ThemeBuilder.label("", Rect2(40, 404, 620, 64), 16, true, Palette.NAVY, true)
	card.add_child(hint_label)
	var menu = ThemeBuilder.button(Strings.MENU, Rect2(40, 494, 150, 56), 18)
	menu.connect("pressed", self, "_on_menu")
	card.add_child(menu)
	var again = ThemeBuilder.button(Strings.RESTART, Rect2(206, 494, 180, 56), 18)
	again.connect("pressed", self, "_on_restart")
	card.add_child(again)
	next_btn = ThemeBuilder.button(Strings.NEXT_LEVEL, Rect2(402, 494, 258, 56), 18)
	ThemeBuilder.paint(next_btn, Palette.YELLOW, Palette.NAVY)
	next_btn.connect("pressed", self, "_on_next")
	card.add_child(next_btn)
	tween = Tween.new()
	add_child(tween)


func show_result(sim, has_next: bool) -> void:
	var m = sim.metrics
	won = sim.won()
	stars = m.stars(won)
	if sim.result == "win":
		title_text = Strings.WIN_TITLE
	elif sim.result == "finished":
		title_text = Strings.FINISH_TITLE
	elif sim.lose_reason == "patience":
		title_text = Strings.LOSE_PATIENCE
	elif sim.lose_reason == "time":
		title_text = Strings.LOSE_TIME
	else:
		title_text = Strings.LOSE_GRIDLOCK
	score_text = Strings.SCORE % m.score()
	stats = [
		[Strings.DELIVERED, str(m.deliveries) if sim.mode != "goal" else Strings.PROGRESS % [m.deliveries, sim.goal]],
		[Strings.AVG_DELIVERY, Strings.SECONDS % m.avg_delivery_time()],
		[Strings.TIME_IN_JAMS, Strings.SECONDS % m.jam_seconds],
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
		return Strings.HINT_PATIENCE % g.label(sim.lose_cell)
	var worst = sim.metrics.worst_jam_cell()
	if sim.result == "lose" and sim.lose_reason == "gridlock":
		var at = worst
		if sim.last_deadlock.size() > 0:
			at = sim.last_deadlock[0]
		if at == null and sim.vehicles.size() > 0:
			at = sim.vehicles[0].cell
		if at != null:
			return Strings.HINT_GRIDLOCK % g.label(at)
		return Strings.HINT_NO_JAM_LOSS
	if worst == null or sim.metrics.jam_seconds < 5.0:
		if sim.result == "lose":
			return Strings.HINT_TIME
		return Strings.HINT_CLEAN
	var where = g.label(worst)
	var light_cell = _near(sim, worst, 5, "light")
	if light_cell != null and g.controllers[light_cell].mode == C.LightMode.TIMER:
		return Strings.HINT_SENSOR % where
	if light_cell == null and _near(sim, worst, 5, "junction") != null and sim.inventory["light"] > 0:
		return Strings.HINT_LIGHT % where
	if _near(sim, worst, 3, "water") != null and sim.inventory["bridge"] > 0:
		return Strings.HINT_BRIDGE % where
	if sim.inventory["sorter"] > 0:
		return Strings.HINT_SORTER % where
	if sim.inventory["light"] > 0:
		return Strings.HINT_LIGHT % where
	return Strings.HINT_SORTER % where


func _process(delta: float) -> void:
	if visible:
		age += delta
		card.update()


func _draw_card() -> void:
	var w = CARD.size.x
	DrawUtil.centered(card, Fonts.make(46, true), Vector2(w / 2.0, 58), title_text,
			Palette.NAVY if won else Palette.RED_DARK)
	# Stars appear one by one. Empty stars are outlined, so the count reads without color.
	for i in range(3):
		var c = Vector2(w / 2.0 + (i - 1) * 110.0, 150 - (10 if i == 1 else 0))
		DrawUtil.star(card, c, 46.0, Palette.NAVY)
		var lit = i < stars and age > 0.35 + i * 0.3
		var grow = 1.0
		if lit:
			grow = 1.0 + 0.3 * max(0.0, 1.0 - (age - 0.35 - i * 0.3) * 4.0)
		DrawUtil.star(card, c, 38.0 * grow, Palette.YELLOW if lit else Palette.STAR_OFF)
	DrawUtil.centered(card, Fonts.make(24, true), Vector2(w / 2.0, 222), score_text, Palette.NAVY)
	for i in range(stats.size()):
		var r = Rect2(40 + i * 213, 256, 194, 124)
		card.draw_style_box(ThemeBuilder.box(Palette.NAVY_MID, 16), r)
		DrawUtil.centered(card, Fonts.make(14, true), r.position + Vector2(r.size.x / 2.0, 30), stats[i][0], Palette.TEXT_DIM)
		DrawUtil.centered(card, Fonts.make(24, true), r.position + Vector2(r.size.x / 2.0, 78), stats[i][1], Palette.WHITE)
	card.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.YELLOW, 0.35), 12), Rect2(30, 398, 640, 76))


func _on_restart() -> void:
	Sfx.play("click")
	emit_signal("restart_pressed")


func _on_next() -> void:
	Sfx.play("click")
	emit_signal("next_pressed")


func _on_menu() -> void:
	Sfx.play("click")
	emit_signal("menu_pressed")
