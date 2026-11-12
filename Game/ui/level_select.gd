extends Control

# Three level cards with the best stars and score.

const DrawUtil = preload("res://ui/draw_util.gd")
const ThemeBuilder = preload("res://ui/theme_builder.gd")
const GoalIcon = preload("res://ui/goal_icon.gd")
const Goals = preload("res://sim/goals.gd")

const SCREEN = Vector2(1280, 720)
const CARD_W = 370.0
const CARD_H = 400.0
const CARD_Y = 170.0


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	for i in range(Levels.LEVELS.size()):
		var r = card_rect(i)
		var b = ThemeBuilder.button(Strings.t("PLAY"), Rect2(r.position.x + 40, r.end.y - 84, CARD_W - 80, 56), 18)
		ThemeBuilder.paint(b, Palette.YELLOW, Palette.NAVY)
		b.connect("pressed", self, "_on_level", [i])
		add_child(b)
		Sfx.hover_hook(b)
		# Hovering the stars lists the three goals ([x] = earned).
		var tip = Control.new()
		tip.rect_position = Vector2(r.position.x + CARD_W / 2.0 - 120.0, r.position.y + 112.0)
		tip.rect_size = Vector2(240, 56)
		tip.hint_tooltip = goals_tooltip(Levels.LEVELS[i])
		add_child(tip)
	var back = ThemeBuilder.button(Strings.t("BACK"), Rect2(40, 628, 200, 56), 18)
	back.connect("pressed", self, "_on_back")
	add_child(back)


func goals_tooltip(lv: Dictionary) -> String:
	var mask = SaveData.get_mask(lv["id"])
	var lines = []
	var i = 0
	for g in lv.get("star_goals", []):
		var mark = Strings.t("GOALS_EARNED_MARK") if (mask & (1 << i)) != 0 else Strings.t("GOALS_OPEN_MARK")
		var text = Strings.t(Goals.text_key(g["type"])) if g["type"] == "complete" \
				else Strings.tf(Goals.text_key(g["type"]), [int(g.get("value", 0))])
		lines.append(mark + " " + text)
		i += 1
	return "\n".join(PoolStringArray(lines))


func card_rect(i: int) -> Rect2:
	var gap = (SCREEN.x - CARD_W * 3.0) / 4.0
	return Rect2(gap + i * (CARD_W + gap), CARD_Y, CARD_W, CARD_H)


func _draw() -> void:
	draw_rect(Rect2(Vector2(), SCREEN), Palette.NAVY)
	DrawUtil.centered(self, Fonts.make(46, true), Vector2(SCREEN.x / 2.0, 88), Strings.t("LEVELS"), Palette.WHITE)
	for i in range(Levels.LEVELS.size()):
		var lv = Levels.LEVELS[i]
		var r = card_rect(i)
		var mid = r.position.x + r.size.x / 2.0
		draw_style_box(ThemeBuilder.box(Palette.NAVY_MID, 20, 3, Palette.NAVY_LIGHT), r)
		DrawUtil.centered(self, Fonts.make(14, true), Vector2(mid, r.position.y + 34), Strings.tf("LEVEL_N", [lv["id"]]), Palette.YELLOW)
		DrawUtil.centered(self, Fonts.make(24, true), Vector2(mid, r.position.y + 70), Strings.t(lv["name_key"]), Palette.WHITE)
		var best = SaveData.get_best(lv["id"])
		var mask = SaveData.get_mask(lv["id"])
		for s in range(3):
			var c = Vector2(mid + (s - 1) * 74.0, r.position.y + 140)
			DrawUtil.star(self, c, 32.0, Palette.NAVY)
			DrawUtil.star(self, c, 26.0, Palette.YELLOW if (mask & (1 << s)) != 0 else Palette.NAVY_LIGHT)
		var goal_text = Strings.t("GOAL_SCORE") if lv["mode"] == "score" else Strings.tf("GOAL", [lv["goal"]])
		DrawUtil.centered(self, Fonts.make(16, false), Vector2(mid, r.position.y + 206), goal_text, Palette.TEXT_DIM)
		DrawUtil.centered(self, Fonts.make(16, false), Vector2(mid, r.position.y + 234),
				Strings.tf("DURATION", [int(lv["time"]) / 60, int(lv["time"]) % 60]), Palette.TEXT_DIM)
		var best_text = Strings.tf("BEST", [best["score"]]) if best["played"] else Strings.t("NOT_PLAYED")
		DrawUtil.centered(self, Fonts.make(18, true), Vector2(mid, r.position.y + 276), best_text, Palette.WHITE)


func _on_level(i: int) -> void:
	Sfx.play("ui_click")
	Levels.mode = "level"
	Levels.current = i
	get_tree().change_scene("res://view/game.tscn")


func _on_back() -> void:
	Sfx.play("ui_click")
	get_tree().change_scene("res://ui/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		_on_back()
