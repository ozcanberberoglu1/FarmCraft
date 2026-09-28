class_name SettingsScreen
extends ModalScreen
## Settings: general (language, day length), video (quality preset, fullscreen,
## v-sync, resolution scale, field of view, camera shake, FPS counter), audio and
## controls (mouse, key bindings). Changes apply at once and are saved when the window closes.

const CATEGORIES := [["general", "SETTINGS_GENERAL", "globe"], ["video", "SETTINGS_VIDEO", "monitor"],
	["audio", "SETTINGS_AUDIO", "speaker"], ["controls", "SETTINGS_CONTROLS", "keyboard"]]
const BINDINGS := [["BIND_MOVE", ["W", "A", "S", "D"]], ["BIND_SPRINT", ["SHIFT"]], ["BIND_JUMP", ["SPACE"]],
	["BIND_USE", ["LMB"]], ["BIND_INTERACT", ["E"]], ["BIND_INFO", ["F"]], ["BIND_INVENTORY", ["TAB", "I"]],
	["BIND_DROP", ["Q"]], ["BIND_HOTBAR", ["1", "–", "8"]], ["BIND_VEHICLE", ["V", "L"]], ["BIND_PAUSE", ["ESC"]]]

var _nav: VBoxContainer
var _rows: VBoxContainer
var _nav_buttons := {}
var _category := "general"


func _ready() -> void:
	ui_name = &"settings"
	make_window(tr("SETTINGS_TITLE"), "gear", tr("SETTINGS_HINT"))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	window.body.add_child(body)
	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 8)
	_nav.custom_minimum_size = Vector2(250, 0)
	body.add_child(_nav)
	for c: Array in CATEGORIES:
		var b := Button.new()
		b.text = UiTheme.caps(tr(c[1]))
		b.icon = UiTheme.glyph(c[2])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(250, 54)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", UiTheme.display(700, 2))
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_constant_override("h_separation", 12)
		b.add_theme_constant_override("icon_max_width", 22)
		b.pressed.connect(_select.bind(String(c[0])))
		_nav.add_child(b)
		_nav_buttons[String(c[0])] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	window.body.add_child(UiTheme.separator())
	var foot := HBoxContainer.new()
	window.body.add_child(foot)
	var reset := UiTheme.button(tr("SETTINGS_DEFAULTS"), "ghost", Vector2(220, 50), "wrench", 19)
	reset.pressed.connect(func() -> void:
		Settings.reset_defaults()
		Settings.apply()
		_select(_category))
	foot.add_child(reset)
	foot.add_child(UiTheme.expand())
	var done := UiTheme.button(tr("SETTINGS_DONE"), "primary", Vector2(220, 50), "check", 20)
	done.pressed.connect(hide_screen)
	foot.add_child(done)


func show_screen() -> void:
	_select(_category)
	super.show_screen()


func _on_hidden() -> void:
	Settings.save_settings()


func _select(category: String) -> void:
	_category = category
	for key: String in _nav_buttons:
		var b: Button = _nav_buttons[key]
		var active := key == category
		var normal := UiTheme.box(UiTheme.CARD_ACTIVE if active else Color(1, 1, 1, 0.0), 12, 1,
				Color(UiTheme.GOLD, 0.5) if active else Color(1, 1, 1, 0.0))
		if active:
			normal.border_width_left = 4
		normal.content_margin_left = 18
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = UiTheme.CARD_ACTIVE if active else UiTheme.CARD_HOVER
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, normal if state == "normal" else hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var fg := UiTheme.GOLD_SOFT if active else UiTheme.TEXT_MUTED
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, fg if state == "font_color" else (fg if active else UiTheme.TEXT))
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(state, fg)
	for c in _rows.get_children():
		c.queue_free()
	match category:
		"general":
			_general()
		"video":
			_video()
		"audio":
			_audio()
		_:
			_controls()


# --- Rows ---------------------------------------------------------------------------

func _row(title_key: String, desc_key: String, control: Control) -> void:
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 12, 1, Color(1, 1, 1, 0.07))
	sb.content_margin_left = 20
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(texts)
	texts.add_child(UiTheme.make_label(UiTheme.caps(tr(title_key)), UiTheme.heading(21, UiTheme.TEXT, 700, 2)))
	if desc_key != "":
		texts.add_child(UiTheme.paragraph(tr(desc_key), 15, UiTheme.TEXT_DIM, 400))
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	_rows.add_child(card)


func _switch(title_key: String, desc_key: String, value: bool, apply: Callable) -> void:
	var s := SwitchToggle.new(value)
	s.toggled.connect(func(on: bool) -> void:
		apply.call(on)
		Settings.apply())
	_row(title_key, desc_key, s)


## Slider with its value shown beside it (`fmt` turns the value into text).
func _slider(title_key: String, desc_key: String, lo: float, hi: float, step: float, value: float,
		fmt: Callable, apply: Callable) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var slider := UiSlider.new(lo, hi, step, value)
	slider.custom_minimum_size = Vector2(260, 30)
	box.add_child(slider)
	var label := UiTheme.make_label(fmt.call(value), UiTheme.heading(21, UiTheme.GOLD_SOFT, 700, 0))
	label.custom_minimum_size = Vector2(70, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(label)
	slider.value_changed.connect(func(v: float) -> void:
		label.text = fmt.call(v)
		apply.call(v)
		Settings.apply())
	_row(title_key, desc_key, box)


func _choice(title_key: String, desc_key: String, options: Array, index: int, apply: Callable) -> void:
	var sel := OptionSelector.new(options, index)
	sel.changed.connect(func(i: int) -> void:
		apply.call(i)
		Settings.apply())
	_row(title_key, desc_key, sel)


func _general() -> void:
	_rows.add_child(UiTheme.section(tr("SETTINGS_GENERAL"), "globe"))
	_languages()
	_slider("SETTINGS_DAY_LENGTH", "SETTINGS_DAY_LENGTH_DESC", 5.0, 40.0, 1.0, Settings.day_length_minutes,
			func(v: float) -> String: return tr("SETTINGS_MINUTES") % int(v),
			func(v: float) -> void: Settings.day_length_minutes = v)


## Every language as a button showing its own name in its own script; picking one
## rebuilds the game in that language (the game itself carries on).
func _languages() -> void:
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 12, 1, Color(1, 1, 1, 0.07))
	sb.content_margin_left = 20
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	col.add_child(UiTheme.make_label(UiTheme.caps(tr("SETTINGS_LANGUAGE")), UiTheme.heading(21, UiTheme.TEXT, 700, 2)))
	col.add_child(UiTheme.paragraph(tr("SETTINGS_LANGUAGE_DESC"), 15, UiTheme.TEXT_DIM, 700))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for code: String in Settings.LANGUAGES:
		var b := Button.new()
		b.name = "Lang_" + code
		b.text = String(Settings.LANGUAGE_NAMES[code])
		b.custom_minimum_size = Vector2(186, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", UiTheme.display_for(code, 700, 1))
		b.add_theme_font_size_override("font_size", 19)
		var active := code == Settings.language
		var normal := UiTheme.box(UiTheme.CARD_ACTIVE if active else Color(1, 1, 1, 0.05), 10, 2 if active else 1,
				Color(UiTheme.GOLD, 0.8) if active else Color(1, 1, 1, 0.1))
		var hover := UiTheme.box(UiTheme.CARD_HOVER, 10, 1, Color(1, 1, 1, 0.25))
		for state in ["normal", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, normal)
		b.add_theme_stylebox_override("hover", normal if active else hover)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var fg := UiTheme.GOLD_SOFT if active else UiTheme.TEXT
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, fg)
		if not active:
			b.pressed.connect(_set_language.bind(code))
		grid.add_child(b)
	_rows.add_child(card)


func _set_language(code: String) -> void:
	Settings.language = code
	Settings.save_settings()
	Settings.apply()
	# Build every text again in the new language; come back to this page.
	var reopen: Array = []
	if Game.hud.title_screen.visible:
		reopen.append("title")
	if Game.hud.pause_menu.visible:
		reopen.append("pause")
	reopen.append("settings")
	SaveGame.reload_in_place(reopen)


func _video() -> void:
	_rows.add_child(UiTheme.section(tr("SETTINGS_VIDEO"), "monitor"))
	_choice("SETTINGS_QUALITY", "SETTINGS_QUALITY_DESC",
			[tr("QUALITY_LOW"), tr("QUALITY_MEDIUM"), tr("QUALITY_HIGH"), tr("QUALITY_ULTRA")], Settings.quality,
			func(i: int) -> void: Settings.quality = i as Settings.Quality)
	_switch("SETTINGS_FULLSCREEN", "", Settings.fullscreen, func(on: bool) -> void: Settings.fullscreen = on)
	_switch("SETTINGS_VSYNC", "SETTINGS_VSYNC_DESC", Settings.vsync, func(on: bool) -> void: Settings.vsync = on)
	_slider("SETTINGS_RENDER_SCALE", "SETTINGS_RENDER_SCALE_DESC", 0.5, 1.0, 0.05, Settings.render_scale,
			func(v: float) -> String: return UiTheme.percent(roundi(v * 100.0)),
			func(v: float) -> void: Settings.render_scale = v)
	_slider("SETTINGS_FOV", "", 60.0, 100.0, 1.0, Settings.fov,
			func(v: float) -> String: return "%d°" % int(v),
			func(v: float) -> void: Settings.fov = v)
	_slider("SETTINGS_CAMERA_SHAKE", "SETTINGS_CAMERA_SHAKE_DESC", 0.0, 1.0, 0.05, Settings.camera_shake,
			func(v: float) -> String: return UiTheme.percent(roundi(v * 100.0)),
			func(v: float) -> void: Settings.camera_shake = v)
	_switch("SETTINGS_SHOW_FPS", "", Settings.show_fps, func(on: bool) -> void: Settings.show_fps = on)


func _audio() -> void:
	_rows.add_child(UiTheme.section(tr("SETTINGS_AUDIO"), "speaker"))
	_slider("SETTINGS_MASTER_VOLUME", "", 0.0, 1.0, 0.01, Settings.master_volume,
			func(v: float) -> String: return UiTheme.percent(roundi(v * 100.0)),
			func(v: float) -> void: Settings.master_volume = v)
	for entry: Array in [["SETTINGS_MUSIC_VOLUME", "music_volume"], ["SETTINGS_EFFECTS_VOLUME", "effects_volume"],
			["SETTINGS_AMBIENCE_VOLUME", "ambience_volume"], ["SETTINGS_UI_VOLUME", "ui_volume"]]:
		var key: String = entry[1]
		_slider(entry[0], "", 0.0, 1.0, 0.01, float(Settings.get(key)),
				func(v: float) -> String: return UiTheme.percent(roundi(v * 100.0)),
				func(v: float) -> void: Settings.set(key, v))


func _controls() -> void:
	_rows.add_child(UiTheme.section(tr("SETTINGS_MOUSE"), "mouse"))
	_slider("SETTINGS_SENSITIVITY", "", 0.0005, 0.006, 0.0001, Settings.mouse_sensitivity,
			func(v: float) -> String: return "%.1f" % (v / 0.0006),
			func(v: float) -> void: Settings.mouse_sensitivity = v)
	_switch("SETTINGS_INVERT_Y", "", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on)
	_rows.add_child(UiTheme.section(tr("SETTINGS_KEYS"), "keyboard"))
	for b: Array in BINDINGS:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 6)
		for k: String in b[1]:
			if k == "–":
				var dash := UiTheme.make_label("–", UiTheme.heading(20, UiTheme.TEXT_MUTED, 700, 0))
				dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				keys.add_child(dash)
			else:
				keys.add_child(UiTheme.keycap(k, 18))
		_row(b[0], "", keys)
