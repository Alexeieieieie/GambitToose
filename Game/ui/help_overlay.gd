extends Control


signal closed

const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const SECTIONS = [["HELP_H_GOAL", "HELP_GOAL"], ["HELP_H_TOOLS", "HELP_TOOLS"], ["HELP_H_LIGHTS", "HELP_LIGHTS"],
		["HELP_H_URGENT", "HELP_URGENT"], ["HELP_H_HEATMAP", "HELP_HEATMAP"], ["HELP_H_STARS", "HELP_STARS"], ["HELP_H_CONTROLS", "HELP_CONTROLS"]]

var card
var close_btn


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	visible = false
	var a = ColorRect.new()
	a.color = Palette.alpha(Palette.NAVY, 0.72)
	a.rect_size = SCREEN
	a.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(a)
	var f = Fonts.make(16, false)
	var b = 660.0
	var y = 74.0
	var c = []
	for s in SECTIONS:
		var h = DrawUtil.wrap_lines(f, Strings.t(s[1]), b) * (f.get_height() + 3) + 6
		c.append([s, y, max(h, 26.0)])
		y += max(h, 26.0) + 14.0
	var d = DrawUtil.wrap_lines(Fonts.make(18, true), Strings.t("HELP_FOOT"), 812.0) * 27.0
	var e = y + d + 90.0
	card = Panel.new()
	card.rect_position = Vector2((SCREEN.x - 860.0) / 2.0, (SCREEN.y - e) / 2.0)
	card.rect_size = Vector2(860, e)
	card.add_stylebox_override("panel", ThemeBuilder.box(Palette.NAVY_MID, 20, 3, Palette.YELLOW))
	add_child(card)
	card.add_child(ThemeBuilder.label(Strings.t("HELP_TITLE"), Rect2(24, 14, 812, 40), 26, true, Palette.YELLOW))
	for r in c:
		card.add_child(ThemeBuilder.label(Strings.t(r[0][0]), Rect2(24, r[1], 150, 26), 16, true, Palette.YELLOW))
		var l = ThemeBuilder.label(Strings.t(r[0][1]), Rect2(176, r[1], b, r[2]), 16, false, Palette.WHITE)
		l.valign = Label.VALIGN_TOP
		l.add_constant_override("line_spacing", 3)
		card.add_child(l)
	card.add_child(ThemeBuilder.label(Strings.t("HELP_FOOT"), Rect2(24, y + 2, 812, d), 18, true, Palette.WHITE, true))
	close_btn = ThemeBuilder.button(Strings.t("CLOSE"), Rect2(330, e - 64, 200, 46), 18)
	ThemeBuilder.paint(close_btn, Palette.YELLOW, Palette.NAVY)
	close_btn.connect("pressed", self, "close")
	card.add_child(close_btn)


func open() -> void:
	visible = true


func close() -> void:
	if not visible:
		return
	Sfx.play("ui_click", 1.0, -6.0)
	visible = false
	emit_signal("closed")
