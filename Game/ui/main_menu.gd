extends Control

# Title screen with a decorative road. Everything is drawn in code.

const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")
const Backdrop = preload("res://ui/backdrop.gd")

const SCREEN = Vector2(1280, 720)

var clock = 0.0
var sound_btn
var lang_btn
var trucks = []


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	trucks = Backdrop.make_trucks()
	var y = 250.0
	var play = _button(Strings.t("PLAY"), Rect2(480, y, 320, 56), 24, "_on_play")
	ThemeBuilder.paint(play, Palette.YELLOW, Palette.NAVY)
	_button(Strings.t("LEVELS"), Rect2(480, y + 66, 320, 56), 24, "_on_levels")
	_button(Strings.t("TUTORIAL"), Rect2(480, y + 132, 320, 56), 24, "_on_tutorial")
	sound_btn = _button("", Rect2(480, y + 198, 120, 50), 16, "_on_sound")
	lang_btn = _button(Strings.t("LANGUAGE_BTN"), Rect2(610, y + 198, 190, 50), 16, "_on_language")
	_button(Strings.t("EXIT"), Rect2(480, y + 258, 320, 56), 24, "_on_exit")
	_sync_sound()
	Sfx.set_speed(1.0)
	Sfx.set_siren(false)


func _button(caption: String, r: Rect2, size: int, method: String) -> Button:
	var b = ThemeBuilder.button(caption, r, size)
	b.connect("pressed", self, method)
	add_child(b)
	return b


func _sync_sound() -> void:
	sound_btn.text = Strings.t("SOUND_ON") if Sfx.enabled else Strings.t("SOUND_OFF")


func _process(delta: float) -> void:
	clock += delta
	update()


func _draw() -> void:
	Backdrop.draw(self, clock, trucks)
	Backdrop.title(self, 136.0)
	DrawUtil.centered(self, Fonts.make(18, false), Vector2(SCREEN.x / 2.0, 214), Strings.t("SUBTITLE"), Palette.TEXT_DIM)


func _on_play() -> void:
	Sfx.play("click")
	Levels.mode = "level"
	Levels.current = 0
	get_tree().change_scene("res://view/game.tscn")


func _on_levels() -> void:
	Sfx.play("click")
	get_tree().change_scene("res://ui/level_select.tscn")


func _on_tutorial() -> void:
	# Replaying never changes saved progress.
	Sfx.play("click")
	Levels.mode = "tutorial"
	Levels.tutorial_index = 0
	get_tree().change_scene("res://view/game.tscn")


func _on_sound() -> void:
	Sfx.toggle()
	Sfx.play("click")
	_sync_sound()


func _on_language() -> void:
	Strings.set_lang("ru" if Strings.lang == "en" else "en")
	Sfx.play("click")
	get_tree().reload_current_scene()


func _on_exit() -> void:
	get_tree().quit()
