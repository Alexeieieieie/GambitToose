extends Control


signal closed

const ThemeBuilder = preload("res://ui/theme_builder.gd")

const SCREEN = Vector2(1280, 720)
const CARD = Rect2(400, 170, 480, 380)

var sliders = {}
var value_labels = {}
var sound_btn
var card


func _ready() -> void:
	rect_size = SCREEN
	theme = ThemeBuilder.build()
	visible = false
	var a = ColorRect.new()
	a.color = Palette.alpha(Palette.NAVY, 0.72)
	a.rect_size = SCREEN
	a.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(a)
	card = Panel.new()
	card.rect_position = CARD.position
	card.rect_size = CARD.size
	card.add_stylebox_override("panel", ThemeBuilder.box(Palette.NAVY_MID, 20, 3, Palette.YELLOW))
	add_child(card)
	card.add_child(ThemeBuilder.label(Strings.t("SETTINGS"), Rect2(24, 16, 432, 40), 28, true, Palette.YELLOW))
	var y = 76.0
	for b in [["master", "VOL_MASTER"], ["music", "VOL_MUSIC"], ["effects", "VOL_EFFECTS"]]:
		card.add_child(ThemeBuilder.label(Strings.t(b[1]), Rect2(24, y, 250, 28), 18, true, Palette.WHITE))
		var vl = ThemeBuilder.label("", Rect2(380, y, 76, 28), 18, true, Palette.TEXT_DIM)
		vl.align = Label.ALIGN_RIGHT
		card.add_child(vl)
		value_labels[b[0]] = vl
		var s = HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 1
		s.rect_position = Vector2(24, y + 34)
		s.rect_size = Vector2(432, 24)
		s.focus_mode = Control.FOCUS_NONE
		s.connect("value_changed", self, "_on_value", [b[0]])
		s.connect("mouse_exited", self, "_save")
		card.add_child(s)
		sliders[b[0]] = s
		y += 78.0
	sound_btn = ThemeBuilder.button("", Rect2(24, 312, 200, 48), 18)
	sound_btn.connect("pressed", self, "_on_sound")
	card.add_child(sound_btn)
	var c = ThemeBuilder.button(Strings.t("CLOSE"), Rect2(256, 312, 200, 48), 18)
	ThemeBuilder.paint(c, Palette.YELLOW, Palette.NAVY)
	c.connect("pressed", self, "close")
	card.add_child(c)


func open() -> void:
	sliders["master"].value = SaveData.vol_master
	sliders["music"].value = SaveData.vol_music
	sliders["effects"].value = SaveData.vol_effects
	for k in sliders.keys():
		value_labels[k].text = str(int(sliders[k].value))
	_sync_sound()
	visible = true
	Sfx.play("panel_open")


func _sync_sound() -> void:
	sound_btn.text = Strings.t("SOUND_ON") if Sfx.enabled else Strings.t("SOUND_OFF")


func _on_value(v: float, a: String) -> void:
	value_labels[a].text = str(int(v))
	if not visible:
		return
	if a == "master":
		SaveData.vol_master = int(v)
	elif a == "music":
		SaveData.vol_music = int(v)
	else:
		SaveData.vol_effects = int(v)
		Sfx.play("place_road")
	Sfx.apply_settings()


func _save() -> void:
	SaveData.set_volumes(SaveData.vol_master, SaveData.vol_music, SaveData.vol_effects)


func _on_sound() -> void:
	Sfx.toggle()
	_sync_sound()


func close() -> void:
	if not visible:
		return
	_save()
	Sfx.play("panel_close")
	visible = false
	emit_signal("closed")
