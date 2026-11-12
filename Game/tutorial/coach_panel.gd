extends Control


const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const MAP_ORIGIN = Vector2(0, 56)
const W = 520.0
const PAD = 20.0
const TOP_Y = 62.0
const BOTTOM_Y = 650.0

var game
var manager
var dim
var tag_label
var title_label
var text_label
var hint_label
var continue_btn
var hint_btn
var skip_step_btn
var reset_btn
var skip_tut_btn
var next_btn
var tween
var slide = 0.0
var card_h = 200.0
var layout_key = ""
var showing_done = false
var first_step = true
var check_y = 0.0
var target_pos = Vector2()


func setup(d, e) -> void:
	game = d
	manager = e
	theme = ThemeBuilder.build()
	mouse_filter = Control.MOUSE_FILTER_STOP
	rect_size = Vector2(W, card_h)
	dim = ColorRect.new()
	dim.color = Palette.alpha(Palette.NAVY, 0.22)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.show_behind_parent = true
	add_child(dim)
	tag_label = ThemeBuilder.label("", Rect2(PAD, 12, 300, 18), 12, true, Palette.TEXT_DIM)
	title_label = ThemeBuilder.label("", Rect2(PAD, 30, W - 2 * PAD, 28), 20, true, Palette.YELLOW)
	text_label = ThemeBuilder.label("", Rect2(PAD, 62, W - 2 * PAD, 60), 16, false, Palette.WHITE)
	text_label.valign = Label.VALIGN_TOP
	text_label.add_constant_override("line_spacing", 3)
	hint_label = ThemeBuilder.label("", Rect2(PAD, 122, W - 2 * PAD, 20), 14, true, Palette.YELLOW)
	hint_label.valign = Label.VALIGN_TOP
	for l in [tag_label, title_label, text_label, hint_label]:
		add_child(l)
	continue_btn = _button("", 16, "_on_continue")
	ThemeBuilder.paint(continue_btn, Palette.YELLOW, Palette.NAVY)
	next_btn = _button(Strings.t("TUT_NEXT_LESSON"), 16, "_on_next")
	ThemeBuilder.paint(next_btn, Palette.YELLOW, Palette.NAVY)
	hint_btn = _button(Strings.t("TUT_HINT"), 14, "_on_hint")
	skip_step_btn = _button(Strings.t("TUT_SKIP_STEP"), 13, "_on_skip_step")
	reset_btn = _button(Strings.t("TUT_RESET"), 13, "_on_reset")
	skip_tut_btn = _button(Strings.t("SKIP_TUTORIAL"), 13, "_on_skip_tutorial")
	skip_tut_btn.flat = true
	skip_tut_btn.add_color_override("font_color", Palette.TEXT_DIM)
	tween = Tween.new()
	add_child(tween)
	manager.connect("step_changed", self, "_on_step_changed")
	manager.connect("lesson_completed", self, "_on_lesson_completed")


func _button(d: String, e: int, g: String) -> Button:
	var b = ThemeBuilder.button(d, Rect2(0, 0, 100, 30), e)
	b.connect("pressed", self, g)
	add_child(b)
	return b



func _on_step_changed(d) -> void:
	showing_done = false
	if not first_step:
		Sfx.play("tutorial_step")
	first_step = false
	layout_key = ""
	_slide_in()


func _on_lesson_completed() -> void:
	if manager.is_final():
		visible = false
		return
	showing_done = true
	Sfx.play("lesson_complete")
	layout_key = ""
	_slide_in()


func _slide_in() -> void:
	tween.stop_all()
	tween.interpolate_property(self, "slide", 22.0, 0.0, 0.28, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(self, "modulate:a", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.start()



func _on_continue() -> void:
	Sfx.play("ui_click", 1.0, -4.0)
	manager.notify("continue")


func _on_next() -> void:
	Sfx.play("ui_click")
	game.next_lesson()


func _on_hint() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	manager.show_hint()
	layout_key = ""


func _on_skip_step() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	manager.skip_step()


func _on_reset() -> void:
	Sfx.play("ui_click")
	game.restart()


func _on_skip_tutorial() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	game.ask_skip_tutorial()



func _key() -> String:
	return "%s|%s|%s|%s" % [manager.idx, manager.hint_shown, showing_done, manager.checklist().size()]


func _relayout() -> void:
	var d = Fonts.make(16, false)
	var e = Fonts.make(14, true)
	var g = W - 2 * PAD
	var j = manager.current_step()
	if j.empty() and not showing_done:
		return
	if manager.is_final():
		tag_label.text = Strings.t("TUT_FINAL_TAG")
	else:
		tag_label.text = Strings.tf("TUT_LESSON_TAG", [manager.lesson_no, manager.lesson_count])
	title_label.text = Strings.t(manager.lesson["title_key"])
	var k = ""
	var m = ""
	if showing_done:
		title_label.text = Strings.t("TUT_LESSON_DONE")
		k = Strings.t("TUT_LESSON_DONE_BODY")
	else:
		k = Strings.t(j["text_key"])
		if manager.hint_shown and j.has("hint_key"):
			m = Strings.t(j["hint_key"])
	text_label.text = k
	var o = DrawUtil.wrap_lines(d, k, g) * (d.get_height() + 3)
	text_label.rect_position = Vector2(PAD, 62)
	text_label.rect_size = Vector2(g, o)
	var y = 62.0 + o + 6.0
	hint_label.text = m
	hint_label.visible = m != ""
	if m != "":
		var hh = DrawUtil.wrap_lines(e, m, g) * (e.get_height() + 3)
		hint_label.rect_position = Vector2(PAD, y)
		hint_label.rect_size = Vector2(g, hh)
		y += hh + 6.0
	check_y = y
	if not showing_done and manager.checklist().size() > 0:
		y += 26.0
	continue_btn.text = Strings.t(j.get("button_key", "TUT_CONTINUE")) if not showing_done else ""
	card_h = y + 46.0
	rect_size = Vector2(W, card_h)
	layout_key = _key()


func _text_w(b: Button, d: int) -> float:
	return Fonts.make(d, true).get_string_size(b.text).x


func _place() -> void:
	var d = []
	var h = manager.highlights()
	for e in h["cells"]:
		d.append(Rect2(MAP_ORIGIN + e * C.TILE, Vector2(C.TILE, C.TILE)).grow(12.0))
	for g in h["ui"]:
		var r = UiRegistry.get_rect(g)
		if r.size.x > 0.0:
			d.append(r.grow(10.0))
	var j = BOTTOM_Y - card_h
	var k = [Vector2(380, TOP_Y), Vector2(380, j), Vector2(16, TOP_Y), Vector2(16, j),
			Vector2(744, TOP_Y), Vector2(744, j)]
	if game.modal:
		k = [Vector2(16, TOP_Y), Vector2(16, j)]
	var m = k[0]
	var o = 1e12
	for c in k:
		var p = Rect2(c, Vector2(W, card_h))
		var q = 0.0
		for a in d:
			var s = p.clip(a)
			q += s.size.x * s.size.y
		if q < o - 0.5:
			o = q
			m = c
		if q == 0.0:
			break
	target_pos = m


func _process(d: float) -> void:
	if manager == null or (manager.done and not showing_done):
		return
	if _key() != layout_key:
		_relayout()
	_place()
	rect_position = rect_position.linear_interpolate(target_pos + Vector2(0, slide), 0.35) \
			if abs(rect_position.x - target_pos.x) < 400.0 and rect_position.y > 0.0 else target_pos + Vector2(0, slide)
	var e = manager.is_info_step()
	dim.visible = e and not showing_done and not game.modal
	dim.rect_position = Vector2(0, MAP_ORIGIN.y) - rect_position
	dim.rect_size = Vector2(SCREEN.x, 600)
	continue_btn.visible = e and not showing_done
	next_btn.visible = showing_done
	hint_btn.visible = not showing_done and manager.hint_available() and not manager.hint_shown
	skip_step_btn.visible = not showing_done and manager.skip_available()
	reset_btn.visible = manager.broken and not showing_done
	var fy = card_h - 40.0
	skip_tut_btn.rect_position = Vector2(PAD - 8, fy + 4)
	skip_tut_btn.rect_size = Vector2(_text_w(skip_tut_btn, 13) + 36.0, 28)
	var x = W - PAD
	for b in [continue_btn, next_btn]:
		if b.visible:
			b.rect_size = Vector2(150, 36)
			x -= 150
			b.rect_position = Vector2(x, fy)
			x -= 8
	for b in [hint_btn, skip_step_btn, reset_btn]:
		if b.visible:
			var w = max(_text_w(b, 14 if b == hint_btn else 13) + 40.0, 80.0)
			b.rect_size = Vector2(w, 30)
			x -= w
			b.rect_position = Vector2(x, fy + 3)
			x -= 8
	update()


func _draw() -> void:
	if manager == null:
		return
	draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.97), 18, 3, Palette.alpha(Palette.YELLOW, 0.9)),
			Rect2(Vector2(), Vector2(W, card_h)))
	var n = manager.steps.size()
	for i in range(n):
		var c = Vector2(W - PAD - (n - 1 - i) * 14.0 - 4.0, 21)
		var d = i < manager.idx or showing_done
		if i == manager.idx and not showing_done:
			draw_circle(c, 5.0, Palette.YELLOW)
		elif d:
			draw_circle(c, 4.0, Palette.OK)
		else:
			draw_circle(c, 4.0, Palette.NAVY_LIGHT)
	if showing_done:
		return
	var e = manager.checklist()
	var x = PAD
	for g in e:
		var j = Rect2(x, check_y + 2, 18, 18)
		draw_style_box(ThemeBuilder.box(Palette.OK if g[1] else Palette.NAVY_MID, 4, 2, Palette.YELLOW), j)
		if g[1]:
			draw_line(j.position + Vector2(4, 9), j.position + Vector2(8, 13), Palette.NAVY, 2.5)
			draw_line(j.position + Vector2(8, 13), j.position + Vector2(14, 5), Palette.NAVY, 2.5)
		var k = Strings.t(g[0])
		var f = Fonts.make(14, true)
		DrawUtil.left(self, f, Vector2(x + 26, check_y + 11), k, Palette.WHITE)
		x += 26 + f.get_string_size(k).x + 24
