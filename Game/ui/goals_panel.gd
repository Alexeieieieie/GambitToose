extends Control

# The live goal tracker under the top bar. G toggles it. It is open for the first 10 seconds
# of a run, then collapses to three star icons. It never blocks the map: only a small strip
# (the heading, or the collapsed box) takes clicks.

const DrawUtil = preload("res://ui/draw_util.gd")
const GoalIcon = preload("res://ui/goal_icon.gd")
const Goals = preload("res://sim/goals.gd")

const SCREEN = Vector2(1280, 720)
const ORIGIN = Vector2(12, 62)
const ROW_H = 28.0
const HEAD_H = 32.0
const COLLAPSED = Vector2(132, 38)
const OPEN_SECONDS = 10.0

var sim
var expanded = true
var user_toggled = false
var pops = {}                    # goal index -> seconds since it changed (for the pop animation)
var width = 400.0
var toggle_btn


func setup(sim_) -> void:
	sim = sim_
	rect_size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f = Fonts.make(14, false)
	var widest = 0.0
	for i in range(sim.goals.count()):
		widest = max(widest, f.get_string_size(goal_text(i)).x)
	width = clamp(widest + 150.0, 330.0, 560.0)
	toggle_btn = Button.new()
	toggle_btn.flat = true
	toggle_btn.focus_mode = Control.FOCUS_NONE
	toggle_btn.connect("pressed", self, "toggle")
	add_child(toggle_btn)
	_layout()
	visible = sim.goals.count() > 0


func goal_text(i: int) -> String:
	var type = sim.goals.type_of(i)
	var v = int(sim.goals.value_of(i))
	var key = Goals.text_key(type)
	if type == "complete":
		return Strings.t(key)
	return Strings.tf(key, [v])


func progress_text(i: int) -> String:
	var type = sim.goals.type_of(i)
	if type == "complete":
		return ""
	var args = sim.goals.value_text_args(i, sim)
	return Strings.tf(Goals.progress_key(type), args)


func box_rect() -> Rect2:
	if expanded:
		return Rect2(ORIGIN, Vector2(width, HEAD_H + sim.goals.count() * ROW_H + 8.0))
	return Rect2(ORIGIN, COLLAPSED)


func _layout() -> void:
	var r = box_rect()
	var strip = Rect2(r.position, Vector2(r.size.x, HEAD_H)) if expanded else r
	toggle_btn.rect_position = strip.position
	toggle_btn.rect_size = strip.size
	toggle_btn.hint_tooltip = Strings.t("GOALS")


func toggle() -> void:
	user_toggled = true
	expanded = not expanded
	Sfx.play("panel_open" if expanded else "panel_close")
	_layout()


func pop(i: int) -> void:
	pops[i] = 0.0


func _process(delta: float) -> void:
	if sim == null or not visible:
		return
	if not user_toggled and expanded and sim.time >= OPEN_SECONDS:
		expanded = false
		_layout()
	for i in pops.keys():
		pops[i] += delta
		if pops[i] > 0.6:
			pops.erase(i)
	update()


func _icon_radius(i: int, base: float) -> float:
	if pops.has(i):
		var t = pops[i]
		return base * (1.0 + 0.45 * max(0.0, 1.0 - t * 3.0) * (1.0 if t < 0.34 else 0.0))
	return base


func _draw() -> void:
	if sim == null or sim.goals.count() == 0:
		return
	var r = box_rect()
	var bg = Palette.alpha(Palette.NAVY, 0.86)
	draw_style_box(_box(bg), r)
	if not expanded:
		for i in range(3):
			var c = r.position + Vector2(26 + i * 40, r.size.y / 2.0)
			GoalIcon.draw(self, c, _icon_radius(i, 13.0), sim.goals.status[i], Palette.NAVY)
		return
	var head = Fonts.make(15, true)
	DrawUtil.left(self, head, r.position + Vector2(14, 16), Strings.t("GOALS"), Palette.YELLOW)
	var f = Fonts.make(14, false)
	for i in range(sim.goals.count()):
		var y = r.position.y + HEAD_H + i * ROW_H
		GoalIcon.draw(self, Vector2(r.position.x + 24, y + ROW_H / 2.0), _icon_radius(i, 10.0), sim.goals.status[i], Palette.NAVY)
		var col = Palette.WHITE
		if sim.goals.status[i] == Goals.Status.FAILED:
			col = Palette.TEXT_DIM
		DrawUtil.left(self, f, Vector2(r.position.x + 44, y + ROW_H / 2.0), goal_text(i), col)
		var prog = progress_text(i)
		if prog != "":
			var w = f.get_string_size(prog).x
			DrawUtil.left(self, f, Vector2(r.end.x - 12 - w, y + ROW_H / 2.0), prog, Palette.TEXT_DIM)


func _box(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.anti_aliasing = true
	return sb
