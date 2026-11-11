extends Control

# Title screen with a decorative road. Everything is drawn in code.

const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)

var clock = 0.0
var sound_btn
var trucks = []                  # [lane, offset, speed, color index]


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	var items = [[Strings.PLAY, "_on_play"], [Strings.LEVELS, "_on_levels"],
			[Strings.SOUND_ON, "_on_sound"], [Strings.EXIT, "_on_exit"]]
	var y = 286.0
	for item in items:
		var b = ThemeBuilder.button(item[0], Rect2(480, y, 320, 58), 24)
		b.connect("pressed", self, item[1])
		add_child(b)
		if item[1] == "_on_play":
			ThemeBuilder.paint(b, Palette.YELLOW, Palette.NAVY)
		if item[1] == "_on_sound":
			sound_btn = b
		y += 70.0
	_sync_sound()
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(9):
		trucks.append([i % 2, rng.randf_range(0.0, 1400.0), rng.randf_range(70.0, 130.0), i % 3])
	Sfx.set_speed(1.0)
	Sfx.set_siren(false)


func _sync_sound() -> void:
	sound_btn.text = Strings.SOUND_ON if Sfx.enabled else Strings.SOUND_OFF


func _process(delta: float) -> void:
	clock += delta
	update()


func _draw() -> void:
	draw_rect(Rect2(Vector2(), SCREEN), Palette.NAVY)
	draw_rect(Rect2(0, 590, SCREEN.x, 130), Palette.GRASS)
	draw_rect(Rect2(0, 618, SCREEN.x, 64), Palette.ASPHALT)
	DrawUtil.dashed_line(self, Vector2(0, 650), Vector2(SCREEN.x, 650), Palette.LANE_DASH, 3.0, 22.0, 18.0)
	for i in range(9):
		var x = fmod(i * 173.0 + 60.0, SCREEN.x)
		draw_circle(Vector2(x, 600 if i % 2 == 0 else 704), 12.0, Palette.TREE)
	for t in trucks:
		var dir = 1.0 if t[0] == 0 else -1.0
		var x = fmod(t[1] + clock * t[2], 1400.0) - 60.0
		if dir < 0.0:
			x = SCREEN.x - x
		var y = 666.0 if t[0] == 0 else 634.0
		var body = Rect2(x - 22, y - 11, 44, 22)
		draw_style_box(ThemeBuilder.box(Palette.cargo(t[3]), 5, 2, Palette.cargo_dark(t[3])), body)
		var cab_x = x + 10 if dir > 0.0 else x - 20
		draw_style_box(ThemeBuilder.box(Palette.cargo(t[3]).lightened(0.45), 3), Rect2(cab_x, y - 8, 10, 16))
		if t[3] == 2:
			DrawUtil.dashed_circle(self, Vector2(x, y), 30.0, Palette.URGENT_RING, 2.0, 8, clock * 2.0)
	var big = Fonts.make(92, true)
	DrawUtil.centered(self, big, Vector2(SCREEN.x / 2.0 + 5, 141), Strings.TITLE, Palette.YELLOW)
	DrawUtil.centered(self, big, Vector2(SCREEN.x / 2.0, 136), Strings.TITLE, Palette.WHITE)
	DrawUtil.centered(self, Fonts.make(18, false), Vector2(SCREEN.x / 2.0, 222), Strings.SUBTITLE, Palette.TEXT_DIM)


func _on_play() -> void:
	Sfx.play("click")
	Levels.current = 0
	get_tree().change_scene("res://view/game.tscn")


func _on_levels() -> void:
	Sfx.play("click")
	get_tree().change_scene("res://ui/level_select.tscn")


func _on_sound() -> void:
	Sfx.toggle()
	Sfx.play("click")
	_sync_sound()


func _on_exit() -> void:
	get_tree().quit()
