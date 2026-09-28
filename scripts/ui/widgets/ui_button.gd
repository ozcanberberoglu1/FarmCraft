class_name UiButton
extends Button
## Styled button: gold primary, glass secondary, green success, red danger or a
## text-only ghost. Upper-case condensed label, optional icon, and a small lift
## and brighten on hover.

const KINDS := {
	"primary": {"bg": UiTheme.GOLD, "fg": UiTheme.TEXT_DARK, "border": Color("f9d98b")},
	"secondary": {"bg": Color(1, 1, 1, 0.07), "fg": UiTheme.TEXT, "border": Color(1, 1, 1, 0.16)},
	"success": {"bg": Color("4f9a45"), "fg": UiTheme.TEXT, "border": Color("7ccc6e")},
	"danger": {"bg": Color("b8483a"), "fg": UiTheme.TEXT, "border": Color("ff8a78")},
	"ghost": {"bg": Color(1, 1, 1, 0.0), "fg": UiTheme.TEXT_MUTED, "border": Color(1, 1, 1, 0.0)},
}

var kind := "primary"
var _tween: Tween


func setup(label: String, p_kind := "primary", min_size := Vector2(180, 50), icon_name := "", font_size := 21) -> void:
	kind = p_kind if KINDS.has(p_kind) else "primary"
	text = UiTheme.caps(label)
	custom_minimum_size = min_size
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var k: Dictionary = KINDS[kind]
	var bg: Color = k["bg"]
	var fg: Color = k["fg"]
	var edge: Color = k["border"]
	add_theme_font_override("font", UiTheme.display(700, 2))
	add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, fg)
	add_theme_color_override("font_disabled_color", Color(fg, 0.4))
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		add_theme_color_override(state, fg)
	add_theme_color_override("icon_disabled_color", Color(fg, 0.35))
	add_theme_constant_override("h_separation", 10)
	add_theme_constant_override("icon_max_width", int(font_size * 1.1))
	var normal := UiTheme.box(bg, 10, 1, edge)
	var hover := UiTheme.box(bg.lightened(0.12) if kind != "ghost" else Color(1, 1, 1, 0.07), 10, 1, edge.lightened(0.2))
	if kind == "primary":
		hover.shadow_color = Color(UiTheme.GOLD, 0.35)
		hover.shadow_size = 12
	var pressed := UiTheme.box(bg.darkened(0.12) if kind != "ghost" else Color(1, 1, 1, 0.12), 10, 1, edge)
	var disabled := UiTheme.box(Color(1, 1, 1, 0.04), 10, 1, Color(1, 1, 1, 0.08))
	for sb: StyleBoxFlat in [normal, hover, pressed, disabled]:
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("hover_pressed", pressed)
	add_theme_stylebox_override("disabled", disabled)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_name != "":
		icon = UiTheme.glyph(icon_name)
		expand_icon = false
	if not mouse_entered.is_connected(_hover):
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))
		self.pressed.connect(func() -> void: Audio.ui("confirm" if kind in ["primary", "success"] else "click", -7.0))


func _hover(on: bool) -> void:
	if disabled:
		return
	if on:
		Audio.ui("hover", -20.0)
	pivot_offset = size * 0.5
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.025, 1.025) if on else Vector2.ONE, 0.12)
