extends Control


signal started

const DrawUtil = preload("res://ui/draw_util.gd")
const GoalIcon = preload("res://ui/goal_icon.gd")
const Goals = preload("res://sim/goals.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const CARD = Rect2(330, 110, 620, 500)

var sim
var mask = 0
var card


func setup(a) -> void:
	sim = a
	mask = SaveData.get_mask(sim.level["id"])
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	var b = ColorRect.new()
	b.color = Palette.alpha(Palette.NAVY, 0.72)
	b.rect_size = SCREEN
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(b)
	card = Panel.new()
	card.rect_position = CARD.position
	card.rect_size = CARD.size
	card.add_stylebox_override("panel", ThemeBuilder.box(Palette.NAVY_MID, 22, 3, Palette.YELLOW))
	card.connect("draw", self, "_draw_card")
	add_child(card)
	card.add_child(ThemeBuilder.label(Strings.t(sim.level["name_key"]), Rect2(30, 22, 560, 46), 32, true, Palette.WHITE, true))
	var c = ""
	if sim.mode == "score":
		c = Strings.tf("INTRO_OBJECTIVE_SCORE", [int(sim.time_limit)])
	else:
		c = Strings.tf("INTRO_OBJECTIVE_GOAL", [sim.goal, int(sim.time_limit)])
	card.add_child(ThemeBuilder.label(c, Rect2(30, 74, 560, 56), 18, false, Palette.TEXT_DIM, true))
	card.add_child(ThemeBuilder.label(Strings.t("STAR_GOALS"), Rect2(30, 140, 560, 34), 22, true, Palette.YELLOW, true))
	var d = ThemeBuilder.button(Strings.t("INTRO_START"), Rect2(200, 372, 220, 60), 24)
	ThemeBuilder.paint(d, Palette.YELLOW, Palette.NAVY)
	d.connect("pressed", self, "begin")
	card.add_child(d)
	card.add_child(ThemeBuilder.label(Strings.t("INTRO_HINT"), Rect2(30, 444, 560, 40), 15, false, Palette.TEXT_DIM, true))


func goal_text(i: int) -> String:
	var a = sim.goals.type_of(i)
	if a == "complete":
		return Strings.t(Goals.text_key(a))
	return Strings.tf(Goals.text_key(a), [int(sim.goals.value_of(i))])


func begin() -> void:
	if not visible:
		return
	Sfx.play("ui_click")
	visible = false
	emit_signal("started")


func _draw_card() -> void:
	var f = Fonts.make(20, false)
	for i in range(sim.goals.count()):
		var y = 190.0 + i * 54.0
		card.draw_style_box(ThemeBuilder.box(Palette.alpha(Palette.NAVY, 0.55), 14), Rect2(40, y, 540, 46))
		var a = (mask & (1 << i)) != 0
		GoalIcon.draw(card, Vector2(72, y + 23), 15.0, GoalIcon.DONE if a else GoalIcon.PENDING, Palette.NAVY)
		DrawUtil.left(card, f, Vector2(100, y + 23), goal_text(i), Palette.WHITE)
