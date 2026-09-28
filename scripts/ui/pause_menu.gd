class_name PauseMenu
extends ModalScreen
## Esc menu over the blurred game: resume, save, load, settings, back to the title
## screen or quit, beside a card summarising the farm today.

var _summary: VBoxContainer


func _ready() -> void:
	ui_name = &"pause"
	close_actions = [&"pause"]
	add_child(UiTheme.backdrop())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 130)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	panel = left
	left.add_child(UiTheme.logo(96))
	left.add_child(UiTheme.spacer(24))
	left.add_child(UiTheme.make_label(UiTheme.caps(tr("UI_PAUSED")), UiTheme.heading(22, UiTheme.TEXT_MUTED, 700, 5, true)))
	for spec: Array in [["UI_RESUME", "primary", "play", hide_screen],
			["UI_SAVE_GAME", "secondary", "save", func() -> void: Game.hud.open_saves("save")],
			["UI_LOAD_GAME", "secondary", "folder", func() -> void: Game.hud.open_saves("load")],
			["SETTINGS_TITLE", "secondary", "gear", func() -> void: Game.hud.open_settings()],
			["UI_MAIN_MENU", "secondary", "home", _to_title],
			["UI_QUIT", "ghost", "exit", func() -> void: Game.quit_game()]]:
		var b := UiTheme.button(tr(spec[0]), spec[1], Vector2(420, 56), spec[2], 23)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(spec[3])
		left.add_child(b)
	left.add_child(UiTheme.expand())
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 10)
	hint.add_child(UiTheme.keycap("ESC", 16))
	var hl := UiTheme.make_label(UiTheme.caps(tr("UI_RESUME")), UiTheme.heading(18, UiTheme.TEXT_MUTED, 700, 3))
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.add_child(hl)
	left.add_child(hint)
	row.add_child(UiTheme.expand())
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	right.add_child(UiTheme.expand())
	var card := GlassPanel.new(Vector4(26, 22, 30, 24), 18.0)
	card.custom_minimum_size = Vector2(380, 0)
	right.add_child(card)
	_summary = VBoxContainer.new()
	_summary.add_theme_constant_override("separation", 12)
	card.add_child(_summary)


func show_screen() -> void:
	# The frame under the menu becomes the picture of a save made from here.
	if not visible:
		SaveGame.snapshot()
	_fill_summary()
	super.show_screen()


func _fill_summary() -> void:
	for c in _summary.get_children():
		c.queue_free()
	_summary.add_child(UiTheme.section(tr("UI_FARM_TODAY"), "barn"))
	var rows := [
		["calendar", "%s · %s %d" % [tr("HUD_DAY") % GameClock.day, GameClock.season_name(), GameClock.get_day_of_season()]],
		["clock", GameClock.time_string()],
		["coin", "%s %s" % [UiTheme.money(Economy.money), tr("UI_GOLD")]],
		["paw", tr("UI_ANIMAL_COUNT") % Animals.animals.size()],
	]
	for r: Array in rows:
		_summary.add_child(UiTheme.icon_row(UiTheme.glyph(r[0]), UiTheme.caps(String(r[1])), UiTheme.TEXT, 22, 22))
	var weather := UiTheme.icon_row(Weather.icon(-1, GameClock.is_night()),
			UiTheme.caps(Weather.kind_name(-1, GameClock.is_night())), UiTheme.TEXT, 22, 26)
	_summary.add_child(weather)


func _to_title() -> void:
	hide_screen()
	Game.hud.show_title()
