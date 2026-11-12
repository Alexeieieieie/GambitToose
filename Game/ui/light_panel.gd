extends Control


signal applied(cell, mode, period, threshold, urgent_first)
signal closed

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")
const Intersection = preload("res://sim/intersection.gd")

const SCREEN = Vector2(1280, 720)
const CARD = Rect2(330, 100, 620, 520)

var cell = Vector2()
var chosen_mode = C.LightMode.TIMER
var chosen_urgent = false
var card
var title
var sub_label
var mode_btns = {}
var mode_notes = {}
var threshold_label
var threshold_slider
var period_label
var period_slider
var urgent_btn
var preview
var demo
var demo_clock = 0.0


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	visible = false
	var d = ColorRect.new()
	d.color = Palette.alpha(Palette.NAVY, 0.65)
	d.rect_size = SCREEN
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(d)
	card = Panel.new()
	card.rect_position = CARD.position
	card.rect_size = CARD.size
	card.add_stylebox_override("panel", ThemeBuilder.box(Palette.NAVY_MID, 18, 3, Palette.NAVY_LIGHT))
	add_child(card)
	title = ThemeBuilder.label("", Rect2(24, 8, 572, 36), 24, true)
	card.add_child(title)
	sub_label = ThemeBuilder.label(Strings.t("LIGHT_PANEL_SUB"), Rect2(24, 40, 572, 22), 14, false, Palette.TEXT_DIM)
	card.add_child(sub_label)

	var e = [[C.LightMode.TIMER, Strings.t("MODE_TIMER"), Strings.t("MODE_TIMER_DESC"), "light_mode_timer"],
			[C.LightMode.SENSOR, Strings.t("MODE_SENSOR"), Strings.t("MODE_SENSOR_DESC"), "light_mode_sensor"],
			[C.LightMode.PRIORITY, Strings.t("MODE_PRIORITY"), Strings.t("MODE_PRIORITY_DESC"), "light_mode_priority"]]
	var x = 24.0
	for m in e:
		var b = ThemeBuilder.button(m[1], Rect2(x, 66, 182, 52), 18)
		Sfx.hover_hook(b)
		b.connect("pressed", self, "_on_mode", [m[0]])
		card.add_child(b)
		mode_btns[m[0]] = b
		UiRegistry.register(m[3], b)
		var f = ThemeBuilder.label(m[2], Rect2(x, 120, 182, 40), 12, false, Palette.TEXT_DIM, true)
		card.add_child(f)
		mode_notes[m[0]] = f
		x += 195.0

	threshold_label = ThemeBuilder.label("", Rect2(24, 176, 300, 26), 16, true)
	card.add_child(threshold_label)
	threshold_slider = _slider(Rect2(24, 204, 300, 24), 1, 10)
	threshold_slider.connect("value_changed", self, "_on_slider")
	card.add_child(threshold_slider)
	period_label = ThemeBuilder.label("", Rect2(24, 244, 300, 26), 16, true)
	card.add_child(period_label)
	period_slider = _slider(Rect2(24, 272, 300, 24), 2, 15)
	period_slider.connect("value_changed", self, "_on_slider")
	card.add_child(period_slider)

	urgent_btn = ThemeBuilder.button("", Rect2(24, 322, 572, 46), 16)
	Sfx.hover_hook(urgent_btn)
	urgent_btn.connect("pressed", self, "_on_urgent")
	card.add_child(urgent_btn)

	var g = ThemeBuilder.label(Strings.t("PREVIEW"), Rect2(350, 172, 246, 22), 12, true, Palette.TEXT_DIM, true)
	card.add_child(g)
	preview = Control.new()
	preview.rect_position = Vector2(350, 196)
	preview.rect_size = Vector2(246, 112)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.connect("draw", self, "_draw_preview")
	card.add_child(preview)

	var h = ThemeBuilder.button(Strings.t("CANCEL"), Rect2(24, 448, 270, 52), 18)
	Sfx.hover_hook(h)
	h.connect("pressed", self, "_on_cancel")
	card.add_child(h)
	var j = ThemeBuilder.button(Strings.t("APPLY"), Rect2(326, 448, 270, 52), 18)
	Sfx.hover_hook(j)
	ThemeBuilder.paint(j, Palette.YELLOW, Palette.NAVY)
	j.connect("pressed", self, "_on_apply")
	card.add_child(j)
	UiRegistry.register("light_apply", j)


func _slider(r: Rect2, lo: float, hi: float) -> HSlider:
	var s = HSlider.new()
	s.rect_position = r.position
	s.rect_size = r.size
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.focus_mode = Control.FOCUS_NONE
	return s


func move_to_right() -> void:
	card.rect_position = Vector2(SCREEN.x - CARD.size.x - 10.0, CARD.position.y)


func open(d, e: String) -> void:
	cell = d.cell
	chosen_mode = d.mode
	chosen_urgent = d.urgent_first
	threshold_slider.value = d.threshold
	period_slider.value = d.period
	title.text = Strings.tf("LIGHT_TITLE", [e])
	demo = Intersection.new()
	_sync()
	visible = true


func _sync() -> void:
	for m in mode_btns.keys():
		var on = m == chosen_mode
		ThemeBuilder.paint(mode_btns[m], Palette.NAVY_LIGHT if on else Palette.NAVY, Palette.WHITE, on)
	threshold_label.text = Strings.tf("THRESHOLD", [int(threshold_slider.value)])
	period_label.text = Strings.tf("PERIOD", [int(period_slider.value)])
	var d = chosen_mode == C.LightMode.TIMER
	threshold_slider.editable = not d
	period_slider.editable = d
	threshold_label.modulate.a = 0.4 if d else 1.0
	threshold_slider.modulate.a = 0.4 if d else 1.0
	period_label.modulate.a = 1.0 if d else 0.4
	period_slider.modulate.a = 1.0 if d else 0.4
	var e = chosen_urgent or chosen_mode == C.LightMode.PRIORITY
	urgent_btn.text = Strings.tf("TOGGLE", [Strings.t("URGENT_FIRST"), Strings.t("ON") if e else Strings.t("OFF")])
	ThemeBuilder.paint(urgent_btn, Palette.NAVY_LIGHT if e else Palette.NAVY, Palette.WHITE, e)
	urgent_btn.disabled = chosen_mode == C.LightMode.PRIORITY
	if demo != null:
		demo.mode = chosen_mode
		demo.period = period_slider.value
		demo.threshold = int(threshold_slider.value)
		demo.urgent_first = chosen_urgent


func _on_mode(m) -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	chosen_mode = m
	_sync()


func _on_slider(d) -> void:
	_sync()


func _on_urgent() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	chosen_urgent = not chosen_urgent
	_sync()


func _on_apply() -> void:
	Sfx.play("place_light")
	visible = false
	emit_signal("applied", cell, chosen_mode, period_slider.value, int(threshold_slider.value), chosen_urgent)
	emit_signal("closed")


func _on_cancel() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	visible = false
	emit_signal("closed")


func _process(d: float) -> void:
	if not visible or demo == null:
		return
	demo_clock += d
	var e = 1 - demo.green_axis
	demo.waiting[demo.green_axis] = 0 if demo.t > 1.5 else 2
	demo.waiting[e] = int(min(demo.t * 1.5, 9.0))
	demo.urgent_waiting[e] = fmod(demo_clock, 9.0) > 7.0
	demo.urgent_waiting[demo.green_axis] = false
	demo.tick(d)
	preview.update()


func _draw_preview() -> void:
	var d = preview.rect_size
	var c = d / 2.0
	preview.draw_style_box(ThemeBuilder.box(Palette.GRASS, 10), Rect2(Vector2(), d))
	preview.draw_rect(Rect2(0, c.y - 13, d.x, 26), Palette.ASPHALT)
	preview.draw_rect(Rect2(c.x - 13, 0, 26, d.y), Palette.ASPHALT)
	if demo == null:
		return
	var e = []
	for f in [0, 1]:
		var g = Palette.JAM
		if demo.green_axis == f:
			g = Palette.OK if demo.phase == Intersection.Phase.GREEN else Palette.BUSY
			if demo.phase == Intersection.Phase.ALL_RED:
				g = Palette.JAM
		e.append(g)
	preview.draw_line(c + Vector2(-16, -13), c + Vector2(-16, 13), e[0], 4.0)
	preview.draw_line(c + Vector2(16, -13), c + Vector2(16, 13), e[0], 4.0)
	preview.draw_line(c + Vector2(-13, -16), c + Vector2(13, -16), e[1], 4.0)
	preview.draw_line(c + Vector2(-13, 16), c + Vector2(13, 16), e[1], 4.0)
	for i in range(int(min(demo.waiting[0], 6))):
		preview.draw_rect(Rect2(c.x - 36 - i * 17, c.y + 2, 13, 8), Palette.BLUE)
	for i in range(int(min(demo.waiting[1], 3))):
		preview.draw_rect(Rect2(c.x - 10, c.y - 36 - i * 13, 8, 11), Palette.RED)
	var h = -1
	if demo.urgent_waiting[0]:
		h = 0
	elif demo.urgent_waiting[1]:
		h = 1
	if h == 0:
		DrawUtil.dashed_circle(preview, Vector2(c.x - 30, c.y + 6), 11.0, Palette.URGENT_RING, 2.0, 6, demo_clock * 3.0)
	elif h == 1:
		DrawUtil.dashed_circle(preview, Vector2(c.x - 6, c.y - 31), 11.0, Palette.URGENT_RING, 2.0, 6, demo_clock * 3.0)
