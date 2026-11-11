extends Reference

# The decorative road with moving trucks shown behind the menu and the tutorial screens.

const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)


static func make_trucks() -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var trucks = []
	for i in range(9):
		trucks.append([i % 2, rng.randf_range(0.0, 1400.0), rng.randf_range(70.0, 130.0), i % 3])
	return trucks


static func draw(ci: CanvasItem, clock: float, trucks: Array) -> void:
	ci.draw_rect(Rect2(Vector2(), SCREEN), Palette.NAVY)
	ci.draw_rect(Rect2(0, 590, SCREEN.x, 130), Palette.GRASS)
	ci.draw_rect(Rect2(0, 618, SCREEN.x, 64), Palette.ASPHALT)
	DrawUtil.dashed_line(ci, Vector2(0, 650), Vector2(SCREEN.x, 650), Palette.LANE_DASH, 3.0, 22.0, 18.0)
	for i in range(9):
		var x = fmod(i * 173.0 + 60.0, SCREEN.x)
		ci.draw_circle(Vector2(x, 600 if i % 2 == 0 else 704), 12.0, Palette.TREE)
	for t in trucks:
		var dir = 1.0 if t[0] == 0 else -1.0
		var x = fmod(t[1] + clock * t[2], 1400.0) - 60.0
		if dir < 0.0:
			x = SCREEN.x - x
		var y = 666.0 if t[0] == 0 else 634.0
		var body = Rect2(x - 22, y - 11, 44, 22)
		ci.draw_style_box(ThemeBuilder.box(Palette.cargo(t[3]), 5, 2, Palette.cargo_dark(t[3])), body)
		var cab_x = x + 10 if dir > 0.0 else x - 20
		ci.draw_style_box(ThemeBuilder.box(Palette.cargo(t[3]).lightened(0.45), 3), Rect2(cab_x, y - 8, 10, 16))
		if t[3] == 2:
			DrawUtil.dashed_circle(ci, Vector2(x, y), 30.0, Palette.URGENT_RING, 2.0, 8, clock * 2.0)


static func title(ci: CanvasItem, y: float) -> void:
	var big = Fonts.make(92, true)
	DrawUtil.centered(ci, big, Vector2(SCREEN.x / 2.0 + 5, y + 5), Strings.t("TITLE"), Palette.YELLOW)
	DrawUtil.centered(ci, big, Vector2(SCREEN.x / 2.0, y), Strings.t("TITLE"), Palette.WHITE)
