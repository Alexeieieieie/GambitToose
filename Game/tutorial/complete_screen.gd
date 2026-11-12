extends Control

# Shown after the final test is passed.

const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")
const Backdrop = preload("res://ui/backdrop.gd")

const SCREEN = Vector2(1280, 720)

var clock = 0.0
var trucks = []


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	trucks = Backdrop.make_trucks()
	if SaveData.is_first_run():
		SaveData.finish_tutorial(false)
	add_child(ThemeBuilder.label(Strings.t("COMPLETE_BODY"), Rect2(290, 290, 700, 110), 20, false, Palette.TEXT_DIM, true))
	var play = ThemeBuilder.button(Strings.t("PLAY_LEVEL_1"), Rect2(330, 430, 300, 64), 22)
	ThemeBuilder.paint(play, Palette.YELLOW, Palette.NAVY)
	play.connect("pressed", self, "_on_play")
	add_child(play)
	var menu = ThemeBuilder.button(Strings.t("MAIN_MENU"), Rect2(650, 430, 300, 64), 22)
	menu.connect("pressed", self, "_on_menu")
	add_child(menu)
	Sfx.play("win")


func _process(delta: float) -> void:
	clock += delta
	update()


func _draw() -> void:
	Backdrop.draw(self, clock, trucks)
	DrawUtil.centered(self, Fonts.make(46, true), Vector2(SCREEN.x / 2.0, 100), Strings.t("COMPLETE_TITLE"), Palette.WHITE)
	for i in range(3):
		var c = Vector2(SCREEN.x / 2.0 + (i - 1) * 96.0, 200 - (8 if i == 1 else 0) + sin(clock * 3.0 + i) * 3.0)
		DrawUtil.star(self, c, 40.0, Palette.NAVY_LIGHT)
		DrawUtil.star(self, c, 33.0, Palette.YELLOW)


func _on_play() -> void:
	Sfx.play("ui_click")
	Levels.mode = "level"
	Levels.current = 0
	get_tree().change_scene("res://view/game.tscn")


func _on_menu() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene("res://ui/main_menu.tscn")
