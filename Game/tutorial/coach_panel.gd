extends Control

# The instruction card of the tutorial. It shows the current step of the manager and
# sends the player's button presses back to it. It holds no lesson logic itself.

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


func setup(game_, manager_) -> void:
	game = game_
	manager = manager_
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


func _button(caption: String, size: int, method: String) -> Button:
	var b = ThemeBuilder.button(caption, Rect2(0, 0, 100, 30), size)
	b.connect("pressed", self, method)
	add_child(b)
	return b


# ------------------------------------------------------------------ manager events

func _on_step_changed(_step) -> void:
	showing_done = false
	if not first_step:
		Sfx.play("step")
	first_step = false
	layout_key = ""
	_slide_in()


func _on_lesson_completed() -> void:
	if manager.is_final():
		visible = false           # the game moves on to the completion screen
		return
	showing_done = true
	Sfx.play("lesson")
	layout_key = ""
	_slide_in()


func _slide_in() -> void:
	tween.stop_all()
	tween.interpolate_property(self, "slide", 22.0, 0.0, 0.28, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(self, "modulate:a", 0.0, 1.0, 0.2, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.start()


# ------------------------------------------------------------------ button handlers

func _on_continue() -> void:
	Sfx.play("click", 1.0, -4.0)
	manager.notify("continue")


func _on_next() -> void:
	Sfx.play("click")
	game.next_lesson()


func _on_hint() -> void:
	Sfx.play("click", 1.0, -6.0)
	manager.show_hint()
	layout_key = ""


func _on_skip_step() -> void:
	Sfx.play("click", 1.0, -6.0)
	manager.skip_step()


func _on_reset() -> void:
	Sfx.play("click")
	game.restart()


func _on_skip_tutorial() -> void:
	Sfx.play("click", 1.0, -6.0)
	game.ask_skip_tutorial()


# ------------------------------------------------------------------ layout

func _key() -> String:
	return "%s|%s|%s|%s" % [manager.idx, manager.hint_shown, showing_done, manager.checklist().size()]


func _relayout() -> void:
	var f16 = Fonts.make(16, false)
	var f14 = Fonts.make(14, true)
	var inner = W - 2 * PAD
	var step = manager.current_step()
	if step.empty() and not showing_done:
		return
	if manager.is_final():
		tag_label.text = Strings.t("TUT_FINAL_TAG")
	else:
		tag_label.text = Strings.tf("TUT_LESSON_TAG", [manager.lesson_no, manager.lesson_count])
	title_label.text = Strings.t(manager.lesson["title_key"])
	var body = ""
	var hint = ""
	if showing_done:
		title_label.text = Strings.t("TUT_LESSON_DONE")
		body = Strings.t("TUT_LESSON_DONE_BODY")
	else:
		body = Strings.t(step["text_key"])
		if manager.hint_shown and step.has("hint_key"):
			hint = Strings.t(step["hint_key"])
	text_label.text = body
	var text_h = DrawUtil.wrap_lines(f16, body, inner) * (f16.get_height() + 3)
	text_label.rect_position = Vector2(PAD, 62)
	text_label.rect_size = Vector2(inner, text_h)
	var y = 62.0 + text_h + 6.0
	hint_label.text = hint
	hint_label.visible = hint != ""
	if hint != "":
		var hh = DrawUtil.wrap_lines(f14, hint, inner) * (f14.get_height() + 3)
		hint_label.rect_position = Vector2(PAD, y)
		hint_label.rect_size = Vector2(inner, hh)
		y += hh + 6.0
	check_y = y
	if not showing_done and manager.checklist().size() > 0:
		y += 26.0
	continue_btn.text = Strings.t(step.get("button_key", "TUT_CONTINUE")) if not showing_done else ""
	card_h = y + 46.0
	rect_size = Vector2(W, card_h)
	layout_key = _key()


func _text_w(b: Button, size: int) -> float:
	return Fonts.make(size, true).get_string_size(b.text).x


func _place() -> void:
	var avoid = []
	var h = manager.highlights()
	for cell in h["cells"]:
		avoid.append(Rect2(MAP_ORIGIN + cell * C.TILE, Vector2(C.TILE, C.TILE)).grow(12.0))
	for key in h["ui"]:
		var r = UiRegistry.get_rect(key)
		if r.size.x > 0.0:
			avoid.append(r.grow(10.0))
	var bottom = BOTTOM_Y - card_h
	var cands = [Vector2(380, TOP_Y), Vector2(380, bottom), Vector2(16, TOP_Y), Vector2(16, bottom),
			Vector2(744, TOP_Y), Vector2(744, bottom)]
	if game.modal:
		cands = [Vector2(16, TOP_Y), Vector2(16, bottom)]
	var best = cands[0]
	var best_area = 1e12
	for c in cands:
		var rect = Rect2(c, Vector2(W, card_h))
		var area = 0.0
		for a in avoid:
			var inter = rect.clip(a)
			area += inter.size.x * inter.size.y
		if area < best_area - 0.5:
			best_area = area
			best = c
		if area == 0.0:
			break
	target_pos = best


func _process(_delta: float) -> void:
	if manager == null or (manager.done and not showing_done):
		return                    # nothing left to show (the final test ended)
	if _key() != layout_key:
		_relayout()
	_place()
	rect_position = rect_position.linear_interpolate(target_pos + Vector2(0, slide), 0.35) \
			if abs(rect_position.x - target_pos.x) < 400.0 and rect_position.y > 0.0 else target_pos + Vector2(0, slide)
	var info = manager.is_info_step()
	dim.visible = info and not showing_done and not game.modal
	dim.rect_position = Vector2(0, MAP_ORIGIN.y) - rect_position
	dim.rect_size = Vector2(SCREEN.x, 600)
	continue_btn.visible = info and not showing_done
	next_btn.visible = showing_done
	hint_btn.visible = not showing_done and manager.hint_available() and not manager.hint_shown
	skip_step_btn.visible = not showing_done and manager.skip_available()
	reset_btn.visible = manager.broken and not showing_done
	# Footer: the skip link at the left, action buttons from the right edge.
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
	# Progress dots: one per step of this lesson.
	var n = manager.steps.size()
	for i in range(n):
		var c = Vector2(W - PAD - (n - 1 - i) * 14.0 - 4.0, 21)
		var filled = i < manager.idx or showing_done
		if i == manager.idx and not showing_done:
			draw_circle(c, 5.0, Palette.YELLOW)
		elif filled:
			draw_circle(c, 4.0, Palette.OK)
		else:
			draw_circle(c, 4.0, Palette.NAVY_LIGHT)
	if showing_done:
		return
	var list = manager.checklist()
	var x = PAD
	for item in list:
		var box = Rect2(x, check_y + 2, 18, 18)
		draw_style_box(ThemeBuilder.box(Palette.OK if item[1] else Palette.NAVY_MID, 4, 2, Palette.YELLOW), box)
		if item[1]:
			draw_line(box.position + Vector2(4, 9), box.position + Vector2(8, 13), Palette.NAVY, 2.5)
			draw_line(box.position + Vector2(8, 13), box.position + Vector2(14, 5), Palette.NAVY, 2.5)
		var label = Strings.t(item[0])
		var f = Fonts.make(14, true)
		DrawUtil.left(self, f, Vector2(x + 26, check_y + 11), label, Palette.WHITE)
		x += 26 + f.get_string_size(label).x + 24
