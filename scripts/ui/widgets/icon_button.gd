class_name IconButton
extends Button
## Round glass button showing one line icon (close, arrows, steppers).

func _init(icon_name := "close", diameter := 40.0, tint := UiTheme.TEXT) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon = UiTheme.glyph(icon_name)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r := int(diameter * 0.5)
	var pad := diameter * 0.27
	for state: Array in [["normal", Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.12)],
			["hover", Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.3)],
			["pressed", Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.3)],
			["hover_pressed", Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.3)],
			["disabled", Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06)]]:
		var sb := UiTheme.box(state[1], r, 1, state[2])
		sb.set_content_margin_all(pad)
		add_theme_stylebox_override(state[0], sb)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		add_theme_color_override(state, tint)
	add_theme_color_override("icon_disabled_color", Color(tint, 0.3))
	pressed.connect(func() -> void: Audio.ui("click", -9.0))
