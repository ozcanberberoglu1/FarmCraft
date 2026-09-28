class_name TabStrip
extends HBoxContainer
## Segmented tab bar: icon + upper-case label per tab; the active tab is lit in
## gold with an underline.

signal selected(id: String)

var current := ""
var _buttons := {}


## tabs: [[id, label, icon_name], ...]
func setup(tabs: Array) -> void:
	add_theme_constant_override("separation", 6)
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	for t: Array in tabs:
		var b := Button.new()
		b.text = UiTheme.caps(String(t[1]))
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_override("font", UiTheme.display(700, 2))
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_constant_override("h_separation", 8)
		b.add_theme_constant_override("icon_max_width", 20)
		if t.size() > 2 and t[2] != "":
			b.icon = UiTheme.glyph(t[2])
		b.pressed.connect(select.bind(String(t[0])))
		b.pressed.connect(func() -> void: Audio.ui("click", -9.0))
		add_child(b)
		_buttons[String(t[0])] = b
	if not tabs.is_empty():
		_style(String(tabs[0][0]))


func select(id: String) -> void:
	if not _buttons.has(id):
		return
	_style(id)
	selected.emit(id)


func _style(id: String) -> void:
	current = id
	for key: String in _buttons:
		var b: Button = _buttons[key]
		var active := key == id
		var fg := UiTheme.GOLD_SOFT if active else UiTheme.TEXT_MUTED
		var normal := UiTheme.box(UiTheme.CARD_ACTIVE if active else Color(1, 1, 1, 0.03), 10, 1,
				Color(UiTheme.GOLD, 0.45) if active else Color(1, 1, 1, 0.06))
		if active:
			normal.border_width_bottom = 3
			normal.border_color = Color(UiTheme.GOLD, 0.8)
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = normal.bg_color.lightened(0.08) if active else UiTheme.CARD_HOVER
		for sb: StyleBoxFlat in [normal, hover]:
			sb.content_margin_left = 16
			sb.content_margin_right = 18
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.add_theme_stylebox_override("hover_pressed", hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, fg if active or state == "font_color" else UiTheme.TEXT)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(state, fg)
