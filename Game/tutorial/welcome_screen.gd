extends Control


const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const ConfirmDialog = preload("res://ui/confirm_dialog.gd")

const SCREEN = Vector2(1280, 720)

var clock = 0.0
var trucks = []
var confirm


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	trucks = Backdrop.make_trucks()
	add_child(ThemeBuilder.label(Strings.t("WELCOME_TITLE"), Rect2(240, 196, 800, 50), 34, true, Palette.WHITE, true))
	add_child(ThemeBuilder.label(Strings.t("WELCOME_BODY"), Rect2(290, 256, 700, 110), 20, false, Palette.TEXT_DIM, true))
	var a = ThemeBuilder.button(Strings.t("START_TUTORIAL"), Rect2(450, 396, 380, 70), 26)
	ThemeBuilder.paint(a, Palette.YELLOW, Palette.NAVY)
	a.connect("pressed", self, "_on_start")
	add_child(a)
	var b = ThemeBuilder.button(Strings.t("SKIP_TUTORIAL"), Rect2(540, 488, 200, 40), 16)
	b.flat = true
	b.add_color_override("font_color", Palette.TEXT_DIM)
	b.connect("pressed", self, "_on_skip")
	add_child(b)
	confirm = ConfirmDialog.new()
	add_child(confirm)
	confirm.connect("confirmed", self, "_on_skip_confirmed")


func _process(a: float) -> void:
	clock += a
	update()


func _draw() -> void:
	Backdrop.draw(self, clock, trucks)
	var a = Fonts.make(64, true)
	DrawUtil.centered(self, a, Vector2(SCREEN.x / 2.0 + 4, 104), Strings.t("TITLE"), Palette.YELLOW)
	DrawUtil.centered(self, a, Vector2(SCREEN.x / 2.0, 100), Strings.t("TITLE"), Palette.WHITE)


func _on_start() -> void:
	Sfx.play("ui_click")
	Levels.mode = "tutorial"
	Levels.tutorial_index = 0
	get_tree().change_scene("res://view/game.tscn")


func _on_skip() -> void:
	Sfx.play("ui_click", 1.0, -6.0)
	confirm.open()


func _on_skip_confirmed() -> void:
	SaveData.finish_tutorial(true)
	get_tree().change_scene("res://ui/main_menu.tscn")
