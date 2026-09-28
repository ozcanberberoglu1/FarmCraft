class_name UiSlider
extends HSlider
## Slim horizontal slider: dark track, gold fill and a white round grabber.

static var _knob: Texture2D
static var _knob_hi: Texture2D


func _init(p_min := 0.0, p_max := 1.0, p_step := 0.01, start := 0.0) -> void:
	min_value = p_min
	max_value = p_max
	step = p_step
	value = start
	custom_minimum_size = Vector2(300, 30)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := UiTheme.box(Color(1, 1, 1, 0.12), 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := UiTheme.box(UiTheme.GOLD, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	var fill_hi := UiTheme.box(UiTheme.GOLD_SOFT, 3)
	fill_hi.content_margin_top = 3
	fill_hi.content_margin_bottom = 3
	add_theme_stylebox_override("slider", track)
	add_theme_stylebox_override("grabber_area", fill)
	add_theme_stylebox_override("grabber_area_highlight", fill_hi)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _knob == null:
		_knob = _circle(22, Color.WHITE, Color(0, 0, 0, 0.0))
		_knob_hi = _circle(24, Color.WHITE, Color(UiTheme.GOLD, 1.0))
	add_theme_icon_override("grabber", _knob)
	add_theme_icon_override("grabber_highlight", _knob_hi)


static func _circle(d: int, fill: Color, ring: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(d * 0.5 - dist, 0.0, 1.0)
			var col := fill
			if ring.a > 0.0 and dist > d * 0.5 - 3.0:
				col = ring
			img.set_pixel(x, y, Color(col, col.a * a))
	return ImageTexture.create_from_image(img)
