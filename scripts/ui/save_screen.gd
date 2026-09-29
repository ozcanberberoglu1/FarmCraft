class_name SaveScreen
extends ModalScreen
## Save and load slots: the autosave and three manual slots as cards with a picture
## of the moment, the day and season, money, time played and when it was saved. In
## save mode a card writes the game there (asking before overwriting); in load mode
## it loads it (asking first when a game is in progress). Saves can be deleted.

const PICTURE := Vector2(224, 126)

var _mode := "load"
var _grid: GridContainer


func _ready() -> void:
	ui_name = &"saves"
	close_actions = [&"pause"]
	make_window(tr("UI_LOAD_GAME"), "folder")
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	window.body.add_child(_grid)


## `mode` is "save" or "load".
func open(mode: String) -> void:
	_mode = mode
	if mode == "save":
		window.set_heading(tr("UI_SAVE_GAME"), "save", tr("UI_SAVE_HINT"))
	else:
		window.set_heading(tr("UI_LOAD_GAME"), "folder", tr("UI_LOAD_HINT"))
	_refresh()
	show_screen()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for slot in SaveGame.SLOTS:
		_grid.add_child(_card(slot))


func _card(slot: String) -> Control:
	var h := SaveGame.info(slot)
	var empty := h.is_empty()
	var auto := slot == SaveGame.AUTO
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(580, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(_picture(slot, empty))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := tr("UI_SLOT_AUTO") if auto else tr("UI_SLOT") % int(slot.get_slice("_", 1))
	col.add_child(UiTheme.make_label(UiTheme.caps(title), UiTheme.heading(20, UiTheme.GOLD_SOFT if auto else UiTheme.TEXT, 700, 2)))
	if empty:
		col.add_child(UiTheme.make_label(tr("UI_EMPTY"), UiTheme.text(16, UiTheme.TEXT_DIM, 600)))
	else:
		var when := UiTheme.caps("%s · %s %d" % [tr("HUD_DAY") % int(h.get("day", 1)), GameClock.season_name(int(h.get("season", 0))), int(h.get("day_of_season", 1))])
		col.add_child(UiTheme.icon_row(UiTheme.glyph("calendar"), when, UiTheme.TEXT, 16, 18))
		col.add_child(UiTheme.icon_row(null, UiTheme.money(int(h.get("money", 0))), UiTheme.TEXT, 16, 18))
		var played := int(float(h.get("play_seconds", 0.0)) / 60.0)
		col.add_child(UiTheme.icon_row(UiTheme.glyph("clock"), tr("UI_PLAYTIME") % [played / 60, played % 60], UiTheme.TEXT_MUTED, 15, 18))
		col.add_child(UiTheme.make_label(UiTheme.date_time(float(h.get("saved_at", 0.0))), UiTheme.text(14, UiTheme.TEXT_DIM, 600)))
	col.add_child(UiTheme.expand())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	if _mode == "save":
		if auto:
			buttons.add_child(UiTheme.chip(tr("UI_AUTOSAVE_NOTE"), UiTheme.TEXT_MUTED, "clock", 14))
		else:
			var save := UiTheme.button(tr("UI_SAVE"), "primary", Vector2(170, 42), "save", 17)
			save.pressed.connect(_save.bind(slot, empty))
			buttons.add_child(save)
	else:
		var load_button := UiTheme.button(tr("UI_LOAD"), "primary", Vector2(170, 42), "play", 17)
		load_button.disabled = empty
		load_button.pressed.connect(_load.bind(slot))
		buttons.add_child(load_button)
	if not empty:
		var del := IconButton.new("trash", 42, UiTheme.TEXT_MUTED)
		del.tooltip_text = tr("UI_DELETE")
		del.pressed.connect(_delete.bind(slot))
		buttons.add_child(del)
	return card


func _picture(slot: String, empty: bool) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = PICTURE
	var sb := UiTheme.box(Color(1, 1, 1, 0.04), 10, 1, Color(1, 1, 1, 0.08))
	frame.add_theme_stylebox_override("panel", sb)
	var tex: Texture2D = null if empty else SaveGame.thumbnail(slot)
	if tex:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = PICTURE
		frame.add_child(pic)
	else:
		var center := CenterContainer.new()
		center.add_child(UiTheme.icon_rect(UiTheme.glyph("folder" if empty else "save"), 40, UiTheme.TEXT_DIM))
		frame.add_child(center)
	return frame


func _save(slot: String, empty: bool) -> void:
	if empty:
		_do_save(slot)
	else:
		Game.hud.confirm_dialog.ask(tr("UI_OVERWRITE_TITLE"), tr("UI_OVERWRITE_TEXT"), tr("UI_SAVE"), _do_save.bind(slot))


func _do_save(slot: String) -> void:
	if SaveGame.save(slot):
		Game.notify(tr("MSG_SAVED"), UiTheme.GREEN)
	else:
		Game.notify(tr("MSG_SAVE_FAILED"), UiTheme.RED)
	_refresh()


func _load(slot: String) -> void:
	if SaveGame.started and not Game.hud.title_screen.visible:
		Game.hud.confirm_dialog.ask(tr("UI_LOAD_GAME"), tr("UI_UNSAVED_TEXT"), tr("UI_LOAD"), _do_load.bind(slot))
	else:
		_do_load(slot)


func _do_load(slot: String) -> void:
	hide_screen()
	SaveGame.load_game(slot)


func _delete(slot: String) -> void:
	Game.hud.confirm_dialog.ask(tr("UI_DELETE_TITLE"), tr("UI_DELETE_TEXT"), tr("UI_DELETE"), _do_delete.bind(slot), true)


func _do_delete(slot: String) -> void:
	SaveGame.delete(slot)
	_refresh()
