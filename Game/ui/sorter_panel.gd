extends Control


signal applied(cell, rules)
signal closed

const C = preload("res://sim/constants.gd")
const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const CARD = Rect2(350, 150, 580, 420)

var cell = Vector2()
var chosen = {}
var valid = []
var title
var card
var row_btns = []


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	visible = false
	var a = ColorRect.new()
	a.color = Palette.alpha(Palette.NAVY, 0.65)
	a.rect_size = SCREEN
	a.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(a)
	card = Panel.new()
	card.rect_position = CARD.position
	card.rect_size = CARD.size
	card.add_stylebox_override("panel", ThemeBuilder.box(Palette.NAVY_MID, 18, 3, Palette.SORTER))
	add_child(card)
	card.connect("draw", self, "_draw_rows")
	title = ThemeBuilder.label("", Rect2(24, 14, 532, 40), 24, true)
	card.add_child(title)
	card.add_child(ThemeBuilder.label(Strings.t("SORTER_HELP"), Rect2(24, 52, 532, 24), 14, false, Palette.TEXT_DIM))
	var c = ThemeBuilder.button(Strings.t("CANCEL"), Rect2(24, 348, 250, 52), 18)
	Sfx.hover_hook(c)
	c.connect("pressed", self, "_on_cancel")
	card.add_child(c)
	var e = ThemeBuilder.button(Strings.t("APPLY"), Rect2(306, 348, 250, 52), 18)
	Sfx.hover_hook(e)
	ThemeBuilder.paint(e, Palette.YELLOW, Palette.NAVY)
	e.connect("pressed", self, "_on_apply")
	card.add_child(e)
	UiRegistry.register("sorter_apply", e)


func move_to_right() -> void:
	card.rect_position = Vector2(SCREEN.x - CARD.size.x - 10.0, CARD.position.y)


func open(a, c: Array, e: String) -> void:
	cell = a.cell
	valid = c
	chosen = {}
	for f in a.rules.keys():
		chosen[f] = a.rules[f]
	title.text = Strings.tf("SORTER_TITLE", [e])
	for g in row_btns:
		g[2].queue_free()
	row_btns = []
	var h = [[C.CargoColor.BLUE, Strings.t("CARGO_BLUE")], [C.CargoColor.RED, Strings.t("CARGO_RED")],
			[C.CargoColor.URGENT, Strings.t("CARGO_URGENT")]]
	var y = 92.0
	for i in h:
		var x = 170.0
		var j = ThemeBuilder.button(Strings.t("ANY_DIR"), Rect2(x, y, 110, 56), 14)
		Sfx.hover_hook(j)
		j.connect("pressed", self, "_on_pick", [i[0], Vector2()])
		card.add_child(j)
		row_btns.append([i[0], Vector2(), j])
		x += 118.0
		for d in [Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 0)]:
			if not valid.has(d):
				continue
			var b = ThemeBuilder.button("", Rect2(x, y, 56, 56), 14)
			Sfx.hover_hook(b)
			b.connect("pressed", self, "_on_pick", [i[0], d])
			b.connect("draw", self, "_draw_arrow", [b, d])
			card.add_child(b)
			row_btns.append([i[0], d, b])
			x += 64.0
		y += 82.0
	_sync()
	visible = true


func _draw_rows() -> void:
	var a = [[C.CargoColor.BLUE, Strings.t("CARGO_BLUE")], [C.CargoColor.RED, Strings.t("CARGO_RED")],
			[C.CargoColor.URGENT, Strings.t("CARGO_URGENT")]]
	var y = 92.0
	for c in a:
		var at = Vector2(42, y + 28)
		card.draw_rect(Rect2(at.x - 12, at.y - 7, 24, 14), Palette.cargo(c[0]))
		card.draw_rect(Rect2(at.x + 5, at.y - 6, 6, 12), Palette.cargo(c[0]).lightened(0.45))
		if c[0] == C.CargoColor.URGENT:
			DrawUtil.dashed_circle(card, at, 18.0, Palette.URGENT_RING, 2.0)
		DrawUtil.left(card, Fonts.make(16, true), Vector2(68, y + 28), c[1], Palette.WHITE)
		y += 82.0


func _draw_arrow(b, d) -> void:
	DrawUtil.arrow(b, b.rect_size / 2.0, d, 14.0, Palette.WHITE)


func _sync() -> void:
	for a in row_btns:
		var on = chosen.get(a[0], Vector2()) == a[1]
		ThemeBuilder.paint(a[2], Palette.cargo_dark(a[0]) if on else Palette.NAVY, Palette.WHITE, on)
	card.update()


func _on_pick(a, d) -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	chosen[a] = d
	_sync()


func _on_apply() -> void:
	Sfx.play("place_sorter")
	visible = false
	emit_signal("applied", cell, chosen)
	emit_signal("closed")


func _on_cancel() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	visible = false
	emit_signal("closed")
