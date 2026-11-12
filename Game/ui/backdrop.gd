extends Reference


const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)


static func make_trucks() -> Array:
	var a = RandomNumberGenerator.new()
	a.seed = 42
	var b = []
	for i in range(9):
		b.append([i % 2, a.randf_range(0.0, 1400.0), a.randf_range(70.0, 130.0), i % 3])
	return b


static func draw(ci: CanvasItem, a: float, b: Array) -> void:
	ci.draw_rect(Rect2(Vector2(), SCREEN), Palette.NAVY)
	ci.draw_rect(Rect2(0, 590, SCREEN.x, 130), Palette.GRASS)
	ci.draw_rect(Rect2(0, 618, SCREEN.x, 64), Palette.ASPHALT)
	DrawUtil.dashed_line(ci, Vector2(0, 650), Vector2(SCREEN.x, 650), Palette.LANE_DASH, 3.0, 22.0, 18.0)
	for i in range(9):
		var x = fmod(i * 173.0 + 60.0, SCREEN.x)
		ci.draw_circle(Vector2(x, 600 if i % 2 == 0 else 704), 12.0, Palette.TREE)
	for t in b:
		var c = 1.0 if t[0] == 0 else -1.0
		var x = fmod(t[1] + a * t[2], 1400.0) - 60.0
		if c < 0.0:
			x = SCREEN.x - x
		var y = 666.0 if t[0] == 0 else 634.0
		var d = Rect2(x - 22, y - 11, 44, 22)
		ci.draw_style_box(ThemeBuilder.box(Palette.cargo(t[3]), 5, 2, Palette.cargo_dark(t[3])), d)
		var e = x + 10 if c > 0.0 else x - 20
		ci.draw_style_box(ThemeBuilder.box(Palette.cargo(t[3]).lightened(0.45), 3), Rect2(e, y - 8, 10, 16))
		if t[3] == 2:
			DrawUtil.dashed_circle(ci, Vector2(x, y), 30.0, Palette.URGENT_RING, 2.0, 8, a * 2.0)


static func title(ci: CanvasItem, y: float) -> void:
	var a = Fonts.make(92, true)
	DrawUtil.centered(ci, a, Vector2(SCREEN.x / 2.0 + 5, y + 5), Strings.t("TITLE"), Palette.YELLOW)
	DrawUtil.centered(ci, a, Vector2(SCREEN.x / 2.0, y), Strings.t("TITLE"), Palette.WHITE)
