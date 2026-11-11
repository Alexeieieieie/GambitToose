extends Control

# Top bar and toolbar. Reads the game state; sends the player's choices as signals.

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
var speed_btns = {}              # speed value -> Button
var tool_btns = {}               # tool id -> Button
var tool_info = []               # [tool id, caption, inventory key, dot color]
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
var shown = {}                   # last values pushed into the buttons


func setup(game_) -> void:
	game = game_
	rect_size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ThemeBuilder.build()
	_blocker(Rect2(0, 0, SCREEN.x, TOP_H))
	_blocker(Rect2(0, BAR_Y, SCREEN.x, SCREEN.y - BAR_Y))

	pause_btn = _button(Strings.t("PLAY"), Rect2(716, 9, 98, 38), "_on_pause")
	var x = 822.0
	for item in [[1.0, Strings.t("SPEED_1"), "btn_speed_1"], [2.0, Strings.t("SPEED_2"), "btn_speed_2"],
			[4.0, Strings.t("SPEED_4"), "btn_speed_4"]]:
		var b = _button(item[1], Rect2(x, 9, 52, 38), "_on_speed", [item[0]])
		speed_btns[item[0]] = b
		UiRegistry.register(item[2], b)
		x += 56.0
	help_btn = _button(Strings.t("HELP_BTN"), Rect2(994, 9, 44, 38), "_on_help")
	help_btn.hint_tooltip = Strings.t("HELP")
	sound_btn = _button(Strings.t("SOUND_ON"), Rect2(1046, 9, 120, 38), "_on_sound")
	menu_btn = _button(Strings.t("MENU"), Rect2(1174, 9, 94, 38), "_on_menu")
	UiRegistry.register("btn_pause", pause_btn)
	UiRegistry.register("btn_help", help_btn)
	# An invisible control over the deliveries bar, so the tutorial can point at it.
	bar_zone = Control.new()
	bar_zone.rect_position = Vector2(230, 22)
	bar_zone.rect_size = Vector2(366, 22)
	bar_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_zone)
	UiRegistry.register("deliveries_bar", bar_zone)

	tool_info = [                    # [tool id, caption, inventory key, dot color, registry name]
		[C.Tool.ROAD, Strings.t("ROAD"), "road", Palette.ASPHALT, "tool_road"],
		[C.Tool.BRIDGE, Strings.t("BRIDGE"), "bridge", Palette.BRIDGE_DECK, "tool_bridge"],
		[C.Tool.LIGHT, Strings.t("LIGHT"), "light", Palette.OK, "tool_light"],
		[C.Tool.SORTER, Strings.t("SORTER"), "sorter", Palette.SORTER, "tool_sorter"],
		[C.Tool.ERASE, Strings.t("ERASE"), "", Palette.JAM, "tool_erase"],
	]
	x = 12.0
	for info in tool_info:
		var b = _button("", Rect2(x, BAR_Y + 10, 178, 44), "_on_tool", [info[0]])
		tool_btns[info[0]] = b
		UiRegistry.register(info[4], b)
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
	# Stops clicks on the bars from reaching the map underneath.
	var c = Control.new()
	c.rect_position = r.position
	c.rect_size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)


func _button(caption: String, r: Rect2, method: String, binds: Array = []) -> Button:
	var b = ThemeBuilder.button(caption, r)
	b.rect_pivot_offset = r.size / 2.0
	b.connect("pressed", self, method, binds + [b])
	add_child(b)
	return b


func _pop(b: Button) -> void:
	Sfx.play("click", 1.0, -6.0)
	tween.interpolate_property(b, "rect_scale", Vector2(0.88, 0.88), Vector2(1, 1), 0.18,
			Tween.TRANS_BACK, Tween.EASE_OUT)
	tween.start()


func _on_pause(b) -> void:
	_pop(b)
	emit_signal("pause_pressed")


func _on_speed(value, b) -> void:
	_pop(b)
	emit_signal("speed_chosen", value)


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


func toast(msg: String, seconds: float = 2.5) -> void:
	toast_text = msg
	toast_time = seconds


func _process(delta: float) -> void:
	if game == null:
		return
	if toast_time > 0.0:
		toast_time -= delta
	_refresh(false)
	update()
	overlay.update()


func _changed(key: String, value) -> bool:
	if shown.get(key) == value:
		return false
	shown[key] = value
	return true


func _refresh(force: bool) -> void:
	if force:
		shown = {}
	var paused = game.speed == 0.0
	if _changed("paused", paused):
		pause_btn.text = Strings.t("PLAY") if paused else Strings.t("PAUSE")
		if paused:
			ThemeBuilder.paint(pause_btn, Palette.YELLOW, Palette.NAVY)
		else:
			ThemeBuilder.paint(pause_btn, Palette.NAVY_LIGHT, Palette.WHITE)
	var active_speed = game.speed if game.speed > 0.0 else game.last_speed
	if _changed("speed", active_speed):
		for value in speed_btns.keys():
			if value == active_speed:
				ThemeBuilder.paint(speed_btns[value], Palette.YELLOW, Palette.NAVY)
			else:
				ThemeBuilder.paint(speed_btns[value], Palette.NAVY_LIGHT, Palette.WHITE)
	if _changed("sound", Sfx.enabled):
		sound_btn.text = Strings.t("SOUND_ON") if Sfx.enabled else Strings.t("SOUND_OFF")
	if _changed("heat", game.heatmap_on):
		heat_btn.text = Strings.tf("TOGGLE", [Strings.t("HEATMAP"), Strings.t("ON")]) if game.heatmap_on else Strings.t("HEATMAP")
		ThemeBuilder.paint(heat_btn, Palette.HEATMAP_BTN, Palette.NAVY, game.heatmap_on)
	for info in tool_info:
		var id = info[0]
		var count = -1 if info[2] == "" else game.sim.inventory[info[2]]
		var allowed = game.is_tool_allowed(id)
		if _changed("tool%d" % id, [count, game.current_tool == id, allowed]):
			var b = tool_btns[id]
			b.text = info[1] if count < 0 else Strings.tf("COUNT", [info[1], count])
			b.disabled = not allowed
			b.hint_tooltip = "" if allowed else Strings.t("TUT_LOCKED")
			var bg = Palette.NAVY_LIGHT if count != 0 else Palette.NAVY_MID
			var fg = Palette.WHITE if count != 0 else Palette.TEXT_DIM
			if not allowed:
				bg = Palette.NAVY_MID
				fg = Palette.alpha(Palette.TEXT_DIM, 0.55)
			ThemeBuilder.paint(b, bg, fg, game.current_tool == id and allowed)


func _draw() -> void:
	if game == null:
		return
	var sim = game.sim
	draw_rect(Rect2(0, 0, SCREEN.x, TOP_H), Palette.NAVY)
	draw_rect(Rect2(0, BAR_Y, SCREEN.x, SCREEN.y - BAR_Y), Palette.NAVY)
	# Level name pill.
	var f18 = Fonts.make(18, true)
	var name_text = Strings.t(sim.level["name_key"])
	var pill_w = f18.get_string_size(name_text).x + 36.0
	var pill = Rect2(12, 10, pill_w, 36)
	draw_style_box(ThemeBuilder.box(Palette.YELLOW, 18), pill)
	DrawUtil.centered(self, f18, pill.position + pill.size / 2.0, name_text, Palette.NAVY)
	# Deliveries.
	var f14 = Fonts.make(14, true)
	var bar_x = max(pill.end.x + 16.0, 230.0)
	var bar = Rect2(bar_x, 22, 596.0 - bar_x, 22)
	DrawUtil.left(self, Fonts.make(12, true), Vector2(bar.position.x + 2, 12), Strings.t("DELIVERED"), Palette.TEXT_DIM)
	draw_style_box(ThemeBuilder.box(Palette.NAVY_MID, 11), bar)
	var caption = Strings.tf("SCORE", [sim.metrics.score()])
	if sim.goal > 0:
		var k = clamp(float(sim.metrics.deliveries) / max(sim.goal, 1), 0.0, 1.0)
		if k > 0.0:
			draw_style_box(ThemeBuilder.box(Palette.OK, 11), Rect2(bar.position, Vector2(max(bar.size.x * k, 22.0), bar.size.y)))
		caption = Strings.tf("PROGRESS", [sim.metrics.deliveries, sim.goal])
	elif sim.lesson:
		caption = Strings.tf("DELIVERED_N", [sim.metrics.deliveries])
	DrawUtil.centered(self, f14, bar.position + bar.size / 2.0, caption, Palette.WHITE)
	# Timer.
	var left = int(ceil(sim.time_left()))
	var timer_pill = Rect2(606, 8, 100, 40)
	var unlimited = sim.time_limit <= 0.0
	var low = left <= 20 and not unlimited
	draw_style_box(ThemeBuilder.box(Palette.NAVY_MID, 20, 2, Palette.JAM if low else Palette.NAVY_LIGHT), timer_pill)
	var timer_text = Strings.t("NO_LIMIT") if unlimited else Strings.tf("TIMER", [left / 60, left % 60])
	DrawUtil.centered(self, Fonts.make(24, true), timer_pill.position + timer_pill.size / 2.0,
			timer_text, Palette.JAM if low and left % 2 == 0 else Palette.WHITE)


func _draw_overlay() -> void:
	if game == null:
		return
	# Colored dots on the tool buttons.
	for info in tool_info:
		var b = tool_btns[info[0]]
		var c = b.rect_position + Vector2(20, b.rect_size.y / 2.0)
		overlay.draw_circle(c, 8.0, Palette.NAVY)
		overlay.draw_circle(c, 6.0, info[3])
		if not game.is_tool_allowed(info[0]):
			# A small padlock on the right side of a locked tool.
			var lc = b.rect_position + Vector2(b.rect_size.x - 22, b.rect_size.y / 2.0 + 3)
			overlay.draw_rect(Rect2(lc + Vector2(-7, -4), Vector2(14, 11)), Palette.TEXT_DIM)
			overlay.draw_arc(lc + Vector2(0, -4), 5.0, PI, TAU, 8, Palette.TEXT_DIM, 2.5)
	# Heatmap legend, with patterns as well as colors.
	if game.heatmap_on:
		var f12 = Fonts.make(12, true)
		var box = Rect2(1040, BAR_Y - 120, 228, 84)
		overlay.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.92), 10), box)
		var rows = [[Palette.OK, Strings.t("FREE"), 0], [Palette.BUSY, Strings.t("BUSY"), 1], [Palette.JAM, Strings.t("JAM_STRIPED"), 2]]
		for i in range(3):
			var r = Rect2(box.position + Vector2(12, 10 + i * 24), Vector2(18, 18))
			overlay.draw_rect(r, rows[i][0])
			if rows[i][2] == 2:
				DrawUtil.hatch(overlay, r, Palette.NAVY, 6.0, 1.5)
			if rows[i][2] >= 1:
				overlay.draw_rect(r, Palette.NAVY, false, 1.0)
			DrawUtil.left(overlay, f12, Vector2(r.end.x + 10, r.position.y + 9), rows[i][1], Palette.WHITE)
	# Toast.
	if toast_time > 0.0 and toast_text != "":
		var f16 = Fonts.make(16, true)
		var w = f16.get_string_size(toast_text).x + 40.0
		var a = clamp(toast_time * 3.0, 0.0, 1.0)
		var tr = Rect2((SCREEN.x - w) / 2.0, BAR_Y - 52, w, 38)
		overlay.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.92 * a), 19, 2, Palette.alpha(Palette.YELLOW, a)), tr)
		DrawUtil.centered(overlay, f16, tr.position + tr.size / 2.0, toast_text, Palette.alpha(Palette.WHITE, a))
	if fps_on:
		DrawUtil.left(overlay, Fonts.make(14, true), Vector2(12, TOP_H + 16),
				Strings.tf("FPS", [int(Engine.get_frames_per_second())]), Palette.NAVY)
