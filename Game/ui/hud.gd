extends Control


signal tool_chosen(id)
signal speed_chosen(value)
signal pause_pressed
signal heatmap_pressed
signal sound_pressed
signal menu_pressed
signal help_pressed

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const TOP_H = 56.0
const BAR_Y = 656.0
const SCREEN = Vector2(1280, 720)

var game
var pause_btn
var speed_btns = {}
var tool_btns = {}
var tool_info = []
var heat_btn
var sound_btn
var menu_btn
var help_btn
var bar_zone
var overlay
var toast_text = ""
var toast_time = 0.0
var fps_on = false
var tween
var shown = {}
var flashes = {}


func setup(d) -> void:
	game = d
	rect_size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ThemeBuilder.build()
	_blocker(Rect2(0, 0, SCREEN.x, TOP_H))
	_blocker(Rect2(0, BAR_Y, SCREEN.x, SCREEN.y - BAR_Y))

	pause_btn = _button(Strings.t("PLAY"), Rect2(716, 9, 98, 38), "_on_pause")
	var x = 822.0
	for e in [[1.0, Strings.t("SPEED_1"), "btn_speed_1"], [2.0, Strings.t("SPEED_2"), "btn_speed_2"],
			[4.0, Strings.t("SPEED_4"), "btn_speed_4"]]:
		var b = _button(e[1], Rect2(x, 9, 52, 38), "_on_speed", [e[0]])
		speed_btns[e[0]] = b
		UiRegistry.register(e[2], b)
		x += 56.0
	help_btn = _button(Strings.t("HELP_BTN"), Rect2(994, 9, 44, 38), "_on_help")
	help_btn.hint_tooltip = Strings.t("HELP")
	sound_btn = _button(Strings.t("SETTINGS"), Rect2(1046, 9, 120, 38), "_on_sound")
	menu_btn = _button(Strings.t("MENU"), Rect2(1174, 9, 94, 38), "_on_menu")
	UiRegistry.register("btn_pause", pause_btn)
	UiRegistry.register("btn_help", help_btn)
	bar_zone = Control.new()
	bar_zone.rect_position = Vector2(230, 22)
	bar_zone.rect_size = Vector2(366, 22)
	bar_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_zone)
	UiRegistry.register("deliveries_bar", bar_zone)

	tool_info = [
		[C.Tool.ROAD, Strings.t("ROAD"), "road", Palette.ASPHALT, "tool_road"],
		[C.Tool.BRIDGE, Strings.t("BRIDGE"), "bridge", Palette.BRIDGE_DECK, "tool_bridge"],
		[C.Tool.LIGHT, Strings.t("LIGHT"), "light", Palette.OK, "tool_light"],
		[C.Tool.SORTER, Strings.t("SORTER"), "sorter", Palette.SORTER, "tool_sorter"],
		[C.Tool.ERASE, Strings.t("ERASE"), "", Palette.JAM, "tool_erase"],
	]
	x = 12.0
	for f in tool_info:
		var b = _button("", Rect2(x, BAR_Y + 10, 178, 44), "_on_tool", [f[0]])
		tool_btns[f[0]] = b
		UiRegistry.register(f[4], b)
		x += 186.0
	heat_btn = _button(Strings.t("HEATMAP"), Rect2(1040, BAR_Y + 10, 228, 44), "_on_heatmap")
	UiRegistry.register("btn_heatmap", heat_btn)

	overlay = Control.new()
	overlay.rect_size = SCREEN
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.connect("draw", self, "_draw_overlay")
	add_child(overlay)
	tween = Tween.new()
	add_child(tween)
	_refresh(true)


func _blocker(r: Rect2) -> void:
	var c = Control.new()
	c.rect_position = r.position
	c.rect_size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)


func _button(d: String, r: Rect2, e: String, f: Array = []) -> Button:
	var b = ThemeBuilder.button(d, r)
	b.rect_pivot_offset = r.size / 2.0
	b.connect("pressed", self, e, f + [b])
	add_child(b)
	return b


func _pop(b: Button) -> void:
	Sfx.play("ui_click")
	tween.interpolate_property(b, "rect_scale", Vector2(0.88, 0.88), Vector2(1, 1), 0.18,
			Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()


func _on_pause(b) -> void:
	_pop(b)
	emit_signal("pause_pressed")


func _on_speed(d, b) -> void:
	_pop(b)
	emit_signal("speed_chosen", d)


func _on_tool(id, b) -> void:
	_pop(b)
	emit_signal("tool_chosen", id)


func _on_heatmap(b) -> void:
	_pop(b)
	emit_signal("heatmap_pressed")


func _on_sound(b) -> void:
	emit_signal("sound_pressed")
	_pop(b)


func _on_help(b) -> void:
	_pop(b)
	emit_signal("help_pressed")


func _on_menu(b) -> void:
	_pop(b)
	emit_signal("menu_pressed")


func pause_rect() -> Rect2:
	return Rect2(pause_btn.rect_position, pause_btn.rect_size)


func flash_tool(id: int) -> void:
	flashes[id] = 0.45


func toast(d: String, e: float = 2.5) -> void:
	toast_text = d
	toast_time = e


func _process(d: float) -> void:
	if game == null:
		return
	if toast_time > 0.0:
		toast_time -= d
	for id in flashes.keys():
		flashes[id] -= d
		if flashes[id] <= 0.0:
			flashes.erase(id)
	_refresh(false)
	update()
	overlay.update()


func _changed(d: String, e) -> bool:
	if shown.get(d) == e:
		return false
	shown[d] = e
	return true


func _refresh(d: bool) -> void:
	if d:
		shown = {}
	var e = game.speed == 0.0
	if _changed("paused", e):
		pause_btn.text = Strings.t("PLAY") if e else Strings.t("PAUSE")
		if e:
			ThemeBuilder.paint(pause_btn, Palette.YELLOW, Palette.NAVY)
		else:
			ThemeBuilder.paint(pause_btn, Palette.NAVY_LIGHT, Palette.WHITE)
	var f = game.speed if game.speed > 0.0 else game.last_speed
	if _changed("speed", f):
		for g in speed_btns.keys():
			if g == f:
				ThemeBuilder.paint(speed_btns[g], Palette.YELLOW, Palette.NAVY)
			else:
				ThemeBuilder.paint(speed_btns[g], Palette.NAVY_LIGHT, Palette.WHITE)
	if _changed("heat", game.heatmap_on):
		heat_btn.text = Strings.tf("TOGGLE", [Strings.t("HEATMAP"), Strings.t("ON")]) if game.heatmap_on else Strings.t("HEATMAP")
		ThemeBuilder.paint(heat_btn, Palette.HEATMAP_BTN, Palette.NAVY, game.heatmap_on)
	for h in tool_info:
		var id = h[0]
		var j = -1 if h[2] == "" else game.sim.inventory[h[2]]
		var l = game.is_tool_allowed(id)
		if _changed("tool%d" % id, [j, game.current_tool == id, l, flashes.has(id)]):
			var b = tool_btns[id]
			b.text = h[1] if j < 0 else Strings.tf("COUNT", [h[1], j])
			b.disabled = not l
			b.hint_tooltip = "" if l else Strings.t("TUT_LOCKED")
			var bg = Palette.NAVY_LIGHT if j != 0 else Palette.NAVY_MID
			var fg = Palette.WHITE if j != 0 else Palette.TEXT_DIM
			if not l:
				bg = Palette.NAVY_MID
				fg = Palette.alpha(Palette.TEXT_DIM, 0.55)
			if flashes.has(id):
				bg = Palette.RED
				fg = Palette.WHITE
			ThemeBuilder.paint(b, bg, fg, game.current_tool == id and l)


func _draw() -> void:
	if game == null:
		return
	var d = game.sim
	draw_rect(Rect2(0, 0, SCREEN.x, TOP_H), Palette.NAVY)
	draw_rect(Rect2(0, BAR_Y, SCREEN.x, SCREEN.y - BAR_Y), Palette.NAVY)
	var e = Fonts.make(18, true)
	var f = Strings.t(d.level["name_key"])
	var g = e.get_string_size(f).x + 36.0
	var h = Rect2(12, 10, g, 36)
	draw_style_box(ThemeBuilder.box(Palette.YELLOW, 18), h)
	DrawUtil.centered(self, e, h.position + h.size / 2.0, f, Palette.NAVY)
	var j = Fonts.make(14, true)
	var l = max(h.end.x + 16.0, 230.0)
	var m = Rect2(l, 22, 596.0 - l, 22)
	DrawUtil.left(self, Fonts.make(12, true), Vector2(m.position.x + 2, 12), Strings.t("DELIVERED"), Palette.TEXT_DIM)
	draw_style_box(ThemeBuilder.box(Palette.NAVY_MID, 11), m)
	var n = Strings.tf("SCORE", [d.metrics.score()])
	if d.goal > 0:
		var k = clamp(float(d.metrics.deliveries) / max(d.goal, 1), 0.0, 1.0)
		if k > 0.0:
			draw_style_box(ThemeBuilder.box(Palette.OK, 11), Rect2(m.position, Vector2(max(m.size.x * k, 22.0), m.size.y)))
		n = Strings.tf("PROGRESS", [d.metrics.deliveries, d.goal])
	elif d.lesson:
		n = Strings.tf("DELIVERED_N", [d.metrics.deliveries])
	DrawUtil.centered(self, j, m.position + m.size / 2.0, n, Palette.WHITE)
	var o = int(ceil(d.time_left()))
	var p = Rect2(606, 8, 100, 40)
	var q = d.time_limit <= 0.0
	var s = o <= 20 and not q
	draw_style_box(ThemeBuilder.box(Palette.NAVY_MID, 20, 2, Palette.JAM if s else Palette.NAVY_LIGHT), p)
	var u = Strings.t("NO_LIMIT") if q else Strings.tf("TIMER", [o / 60, o % 60])
	DrawUtil.centered(self, Fonts.make(24, true), p.position + p.size / 2.0,
			u, Palette.JAM if s and o % 2 == 0 else Palette.WHITE)


func _draw_overlay() -> void:
	if game == null:
		return
	for d in tool_info:
		var b = tool_btns[d[0]]
		var c = b.rect_position + Vector2(20, b.rect_size.y / 2.0)
		overlay.draw_circle(c, 8.0, Palette.NAVY)
		overlay.draw_circle(c, 6.0, d[3])
		if not game.is_tool_allowed(d[0]):
			var lc = b.rect_position + Vector2(b.rect_size.x - 22, b.rect_size.y / 2.0 + 3)
			overlay.draw_rect(Rect2(lc + Vector2(-7, -4), Vector2(14, 11)), Palette.TEXT_DIM)
			overlay.draw_arc(lc + Vector2(0, -4), 5.0, PI, TAU, 8, Palette.TEXT_DIM, 2.5)
	if game.heatmap_on:
		var e = Fonts.make(12, true)
		var f = Rect2(1040, BAR_Y - 120, 228, 84)
		overlay.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.92), 10), f)
		var g = [[Palette.OK, Strings.t("FREE"), 0], [Palette.BUSY, Strings.t("BUSY"), 1], [Palette.JAM, Strings.t("JAM_STRIPED"), 2]]
		for i in range(3):
			var r = Rect2(f.position + Vector2(12, 10 + i * 24), Vector2(18, 18))
			overlay.draw_rect(r, g[i][0])
			if g[i][2] == 2:
				DrawUtil.hatch(overlay, r, Palette.NAVY, 6.0, 1.5)
			if g[i][2] >= 1:
				overlay.draw_rect(r, Palette.NAVY, false, 1.0)
			DrawUtil.left(overlay, e, Vector2(r.end.x + 10, r.position.y + 9), g[i][1], Palette.WHITE)
	if toast_time > 0.0 and toast_text != "":
		var h = Fonts.make(16, true)
		var w = h.get_string_size(toast_text).x + 40.0
		var a = clamp(toast_time * 3.0, 0.0, 1.0)
		var tr = Rect2((SCREEN.x - w) / 2.0, BAR_Y - 52, w, 38)
		overlay.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.92 * a), 19, 2, Palette.alpha(Palette.YELLOW, a)), tr)
		DrawUtil.centered(overlay, h, tr.position + tr.size / 2.0, toast_text, Palette.alpha(Palette.WHITE, a))
	if fps_on:
		DrawUtil.left(overlay, Fonts.make(14, true), Vector2(12, TOP_H + 16),
				Strings.tf("FPS", [int(Engine.get_frames_per_second())]), Palette.NAVY)
