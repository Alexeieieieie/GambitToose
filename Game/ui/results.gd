extends Control


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
const STAR_STEP = 0.6
const STAR_START = 0.4

var title_text = ""
var stars = 0
var goal_rows = []
var sounded = {}
var new_bits = 0
var won = false
var stats = []
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
	var a = ColorRect.new()
	a.color = Palette.alpha(Palette.NAVY, 0.7)
	a.rect_size = SCREEN
	a.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(a)
	card = Panel.new()
	card.rect_position = CARD.position
	card.rect_size = CARD.size
	card.rect_pivot_offset = CARD.size / 2.0
	card.add_stylebox_override("panel", ThemeBuilder.box(Palette.CARD, 24, 4, Palette.YELLOW))
	card.connect("draw", self, "_draw_card")
	add_child(card)
	hint_label = ThemeBuilder.label("", Rect2(50, 436, 700, 72), 17, true, Palette.NAVY, true)
	card.add_child(hint_label)
	var b = ThemeBuilder.button(Strings.t("MENU"), Rect2(40, 538, 170, 56), 18)
	b.connect("pressed", self, "_on_menu")
	card.add_child(b)
	var e = ThemeBuilder.button(Strings.t("RESTART"), Rect2(226, 538, 220, 56), 18)
	e.connect("pressed", self, "_on_restart")
	card.add_child(e)
	next_btn = ThemeBuilder.button(Strings.t("NEXT_LEVEL"), Rect2(462, 538, 298, 56), 18)
	ThemeBuilder.paint(next_btn, Palette.YELLOW, Palette.NAVY)
	next_btn.connect("pressed", self, "_on_next")
	card.add_child(next_btn)
	tween = Tween.new()
	add_child(tween)


func show_result(a, b: bool, e: int = 0) -> void:
	var m = a.metrics
	won = a.won()
	new_bits = e
	stars = a.goals.stars()
	goal_rows = []
	sounded = {}
	for i in range(a.goals.count()):
		var h = a.goals.type_of(i)
		var j = Strings.t(Goals.text_key(h)) if h == "complete" else Strings.tf(Goals.text_key(h), [int(a.goals.value_of(i))])
		var k = "" if h == "complete" else Strings.tf(Goals.result_key(h), a.goals.result_args(i, a))
		var l = a.goals.status[i] == Goals.Status.DONE
		goal_rows.append([j, k, a.goals.status[i], l and (e & (1 << i)) != 0])
	if a.result == "win":
		title_text = Strings.t("WIN_TITLE")
	elif a.result == "finished":
		title_text = Strings.t("FINISH_TITLE")
	elif a.lose_reason == "patience":
		title_text = Strings.t("LOSE_PATIENCE")
	elif a.lose_reason == "time":
		title_text = Strings.t("LOSE_TIME")
	else:
		title_text = Strings.t("LOSE_GRIDLOCK")
	score_text = Strings.tf("SCORE", [m.score()])
	stats = [
		[Strings.t("DELIVERED"), str(m.deliveries) if a.mode != "goal" else Strings.tf("PROGRESS", [m.deliveries, a.goal])],
		[Strings.t("AVG_DELIVERY"), Strings.tf("SECONDS", [m.avg_delivery_time()])],
		[Strings.t("TIME_IN_JAMS"), Strings.tf("SECONDS", [m.jam_seconds])],
	]
	hint_text = make_hint(a)
	hint_label.text = hint_text
	next_btn.visible = b
	next_btn.disabled = not won
	if not won:
		ThemeBuilder.paint(next_btn, Palette.STAR_OFF, Palette.NAVY_LIGHT)
	age = 0.0
	visible = true
	tween.interpolate_property(card, "rect_scale", Vector2(0.7, 0.7), Vector2(1, 1), 0.35,
			Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()


func _near(a, b: Vector2, e: int, h: String):
	var j = null
	var k = 999.0
	for y in range(-e, e + 1):
		for x in range(-e, e + 1):
			var c = b + Vector2(x, y)
			var l = false
			if h == "light":
				var n = a.grid.controllers.get(c)
				l = n != null and not n.is_sorter
			elif h == "junction":
				l = a.grid.is_junction(c)
			elif h == "water":
				var t = a.grid.tile(c)
				l = a.grid.in_bounds(c) and (t == C.Tile.WATER or t == C.Tile.BRIDGE)
			var d = abs(x) + abs(y)
			if l and d < k:
				k = d
				j = c
	return j


func make_hint(a) -> String:
	var g = a.grid
	if a.result == "lose" and a.lose_reason == "patience" and a.lose_cell != null:
		return Strings.t("HINT_PATIENCE")
	var b = a.metrics.worst_jam_cell()
	if a.result != "lose":
		var e = a.goals.first_failed()
		if e == -1:
			return Strings.t("HINT_PERFECT")
		var h = a.goals.type_of(e)
		if h == "time_left_min" or h == "avg_delivery_max":
			return Strings.t("HINT_G_FASTER")
		if h == "urgent_min":
			return Strings.t("HINT_G_URGENT")
		if h == "patience_min":
			return Strings.t("HINT_G_PATIENCE")
		if h == "roads_max":
			return Strings.t("HINT_G_ROADS")
		if h == "deliver_min" or h == "score_min":
			return Strings.t("HINT_G_SCORE")
	if a.result == "lose" and a.lose_reason == "gridlock":
		var at = b
		if a.last_deadlock.size() > 0:
			at = a.last_deadlock[0]
		if at == null and a.vehicles.size() > 0:
			at = a.vehicles[0].cell
		if at != null:
			return Strings.tf("HINT_GRIDLOCK", [g.label(at)])
		return Strings.t("HINT_NO_JAM_LOSS")
	if b == null or a.metrics.jam_seconds < 5.0:
		if a.result == "lose":
			return Strings.t("HINT_TIME")
		return Strings.t("HINT_CLEAN")
	var j = g.label(b)
	var k = _near(a, b, 5, "light")
	if k != null and g.controllers[k].mode == C.LightMode.TIMER:
		return Strings.tf("HINT_SENSOR", [j])
	if k == null and _near(a, b, 5, "junction") != null and a.inventory["light"] > 0:
		return Strings.tf("HINT_LIGHT", [j])
	if _near(a, b, 3, "water") != null and a.inventory["bridge"] > 0:
		return Strings.tf("HINT_BRIDGE", [j])
	if a.inventory["sorter"] > 0:
		return Strings.tf("HINT_SORTER", [j])
	if a.inventory["light"] > 0:
		return Strings.tf("HINT_LIGHT", [j])
	return Strings.tf("HINT_SORTER", [j])


func _process(a: float) -> void:
	if visible:
		age += a
		_star_sounds()
		card.update()


func _star_time(i: int) -> float:
	return STAR_START + i * STAR_STEP


func _star_sounds() -> void:
	var a = 0
	for i in range(goal_rows.size()):
		if goal_rows[i][2] != Goals.Status.DONE:
			continue
		a += 1
		if age >= _star_time(i) and not sounded.has(i):
			sounded[i] = true
			Sfx.play("star_%d" % int(clamp(a, 1, 3)))


func _draw_card() -> void:
	var w = CARD.size.x
	DrawUtil.centered(card, Fonts.make(42, true), Vector2(w / 2.0, 50), title_text,
			Palette.NAVY if won else Palette.RED_DARK)
	for i in range(3):
		var c = Vector2(w / 2.0 + (i - 1) * 100.0, 118 - (8 if i == 1 else 0))
		var a = age >= _star_time(i)
		var b = i < goal_rows.size() and goal_rows[i][2] == Goals.Status.DONE
		DrawUtil.star(card, c, 38.0, Palette.NAVY)
		var e = 1.0
		if a and b:
			e = 1.0 + 0.3 * max(0.0, 1.0 - (age - _star_time(i)) * 4.0)
		DrawUtil.star(card, c, 31.0 * e, Palette.YELLOW if (a and b) else Palette.STAR_OFF)
	DrawUtil.centered(card, Fonts.make(22, true), Vector2(w / 2.0, 176), score_text, Palette.NAVY)
	var f = Fonts.make(17, false)
	var fb = Fonts.make(17, true)
	for i in range(goal_rows.size()):
		var h = goal_rows[i]
		var y = 200.0 + i * 42.0
		card.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.1), 12), Rect2(40, y, 720, 38))
		var j = h[2] if age >= _star_time(i) else GoalIcon.PENDING
		GoalIcon.draw(card, Vector2(66, y + 19), 13.0, j, Palette.CARD)
		DrawUtil.left(card, f, Vector2(92, y + 19), h[0], Palette.NAVY)
		if h[1] != "":
			var rw = f.get_string_size(h[1]).x
			DrawUtil.left(card, f, Vector2(676 - rw, y + 19), h[1], Palette.NAVY_LIGHT)
		if h[3] and age >= _star_time(i):
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
