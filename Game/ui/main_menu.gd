extends Control


const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")
const Backdrop = preload("res://ui/backdrop.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")

const SCREEN = Vector2(1280, 720)

var clock = 0.0
var settings_btn
var settings
var lang_btn
var trucks = []


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	trucks = Backdrop.make_trucks()
	var y = 250.0
	var a = _button(Strings.t("PLAY"), Rect2(480, y, 320, 56), 24, "_on_play")
	ThemeBuilder.paint(a, Palette.YELLOW, Palette.NAVY)
	_button(Strings.t("LEVELS"), Rect2(480, y + 66, 320, 56), 24, "_on_levels")
	_button(Strings.t("TUTORIAL"), Rect2(480, y + 132, 320, 56), 24, "_on_tutorial")
	settings_btn = _button(Strings.t("SETTINGS"), Rect2(480, y + 198, 150, 50), 16, "_on_settings")
	lang_btn = _button(Strings.t("LANGUAGE_BTN"), Rect2(640, y + 198, 160, 50), 16, "_on_language")
	_button(Strings.t("EXIT"), Rect2(480, y + 258, 320, 56), 24, "_on_exit")
	settings = SettingsPanel.new()
	add_child(settings)
	Sfx.set_speed(1.0)
	Sfx.set_siren(false)
	Sfx.start_menu_music()


func _button(a: String, r: Rect2, c: int, d: String) -> Button:
	var b = ThemeBuilder.button(a, r, c)
	b.connect("pressed", self, d)
	add_child(b)
	Sfx.hover_hook(b)
	return b


func _process(a: float) -> void:
	clock += a
	update()


func _draw() -> void:
	Backdrop.draw(self, clock, trucks)
	Backdrop.title(self, 136.0)
	DrawUtil.centered(self, Fonts.make(18, false), Vector2(SCREEN.x / 2.0, 214), Strings.t("SUBTITLE"), Palette.TEXT_DIM)


func _on_play() -> void:
	Sfx.play("ui_click")
	Levels.mode = "level"
	Levels.current = 0
	get_tree().change_scene("res://view/game.tscn")


func _on_levels() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene("res://ui/level_select.tscn")


func _on_tutorial() -> void:
	Sfx.play("ui_click")
	Levels.mode = "tutorial"
	Levels.tutorial_index = 0
	get_tree().change_scene("res://view/game.tscn")


func _on_settings() -> void:
	Sfx.play("ui_click")
	settings.open()


func _on_language() -> void:
	Strings.set_lang("ru" if Strings.lang == "en" else "en")
	Sfx.play("ui_click")
	get_tree().reload_current_scene()


func _on_exit() -> void:
	get_tree().quit()
