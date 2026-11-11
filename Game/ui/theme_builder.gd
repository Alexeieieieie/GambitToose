extends Reference

# Builds the Theme and the style boxes in code (no .tres files).


static func box(color: Color, radius: int = 10, border: int = 0, border_color: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = true
	return sb


static func build() -> Theme:
	var t = Theme.new()
	t.default_font = Fonts.make(16, true)
	t.set_stylebox("normal", "Button", box(Palette.NAVY_LIGHT))
	t.set_stylebox("hover", "Button", box(Palette.NAVY_LIGHT.lightened(0.12)))
	t.set_stylebox("pressed", "Button", box(Palette.NAVY_LIGHT.darkened(0.15)))
	t.set_stylebox("disabled", "Button", box(Palette.NAVY_MID))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Palette.WHITE)
	t.set_color("font_color_hover", "Button", Palette.WHITE)
	t.set_color("font_color_pressed", "Button", Palette.WHITE)
	t.set_color("font_color_disabled", "Button", Palette.TEXT_DIM)
	t.set_color("font_color", "Label", Palette.WHITE)
	t.set_stylebox("slider", "HSlider", box(Palette.NAVY, 4))
	t.set_stylebox("grabber_area", "HSlider", box(Palette.YELLOW, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Palette.YELLOW, 4))
	return t


static func paint(btn: Button, bg: Color, fg: Color, outline: bool = false) -> void:
	# Recolors one button: used for the active speed, the active tool, and so on.
	var border = 3 if outline else 0
	btn.add_stylebox_override("normal", box(bg, 10, border, Palette.YELLOW))
	btn.add_stylebox_override("hover", box(bg.lightened(0.1), 10, border, Palette.YELLOW))
	btn.add_stylebox_override("pressed", box(bg.darkened(0.12), 10, border, Palette.YELLOW))
	btn.add_color_override("font_color", fg)
	btn.add_color_override("font_color_hover", fg)
	btn.add_color_override("font_color_pressed", fg)


static func button(caption: String, rect: Rect2, font_size: int = 16) -> Button:
	var b = Button.new()
	b.text = caption
	b.rect_position = rect.position
	b.rect_size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_font_override("font", Fonts.make(font_size, true))
	return b


static func label(caption: String, rect: Rect2, font_size: int = 16, bold: bool = false,
		color: Color = Color(1, 1, 1), centered: bool = false) -> Label:
	var l = Label.new()
	l.autowrap = true            # before the text, or the label first sizes itself to one long line
	l.add_font_override("font", Fonts.make(font_size, bold))
	l.add_color_override("font_color", color)
	l.valign = Label.VALIGN_CENTER
	l.text = caption
	l.rect_min_size = Vector2(rect.size.x, 0)
	l.rect_position = rect.position
	l.rect_size = rect.size
	if centered:
		l.align = Label.ALIGN_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
