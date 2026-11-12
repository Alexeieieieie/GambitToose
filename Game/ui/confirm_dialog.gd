extends Control


signal confirmed
signal cancelled

const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const CARD = Rect2(390, 250, 500, 220)


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	visible = false
	var a = ColorRect.new()
	a.color = Palette.alpha(Palette.NAVY, 0.7)
	a.rect_size = SCREEN
	a.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(a)
	var b = Panel.new()
	b.rect_position = CARD.position
	b.rect_size = CARD.size
	b.add_stylebox_override("panel", ThemeBuilder.box(Palette.NAVY_MID, 18, 3, Palette.YELLOW))
	add_child(b)
	b.add_child(ThemeBuilder.label(Strings.t("SKIP_CONFIRM"), Rect2(28, 22, 444, 90), 20, true, Palette.WHITE, true))
	var c = ThemeBuilder.button(Strings.t("SKIP"), Rect2(28, 140, 210, 52), 18)
	c.connect("pressed", self, "_on_yes")
	b.add_child(c)
	var no = ThemeBuilder.button(Strings.t("GO_BACK"), Rect2(262, 140, 210, 52), 18)
	ThemeBuilder.paint(no, Palette.YELLOW, Palette.NAVY)
	no.connect("pressed", self, "_on_no")
	b.add_child(no)


func open() -> void:
	visible = true


func _on_yes() -> void:
	Sfx.play("ui_click")
	visible = false
	emit_signal("confirmed")


func _on_no() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	visible = false
	emit_signal("cancelled")
