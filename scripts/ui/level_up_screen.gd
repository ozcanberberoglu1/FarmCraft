class_name LevelUpScreen
extends ModalScreen
## Shown when the farm reaches a new level: everything it opens (crops, animals,
## workbench recipes, buildings, tool upgrades, order perks, from UnlockTable) and a
## look ahead at the next level.

const CARD := Vector2(150, 164)

## Levels reached while the window is up (several at once after a big delivery).
var _levels: Array[int] = []


func _ready() -> void:
	ui_name = &"level_up"
	close_actions = [&"pause", &"interact"]


func open(level: int) -> void:
	_levels.append(level)
	for c in get_children():
		c.queue_free()
	make_window(tr("UI_LEVEL_UP") % level, "star", tr("UI_LEVEL_UP_SUB"))
	var body := window.body
	var opened := []
	for l in _levels:
		opened.append_array(entries(l))
	if not opened.is_empty():
		body.add_child(UiTheme.section(tr("UI_UNLOCKED"), "sparkles"))
		var grid := GridContainer.new()
		grid.columns = mini(opened.size(), 6)
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		body.add_child(grid)
		for e: Array in opened:
			grid.add_child(_card(e))
	if level < Progress.MAX_LEVEL:
		var next := entries(level + 1).map(func(e: Array) -> String: return String(e[1]))
		if not next.is_empty():
			body.add_child(UiTheme.spacer(6))
			body.add_child(UiTheme.section(tr("UI_NEXT_LEVEL") % (level + 1), "lock"))
			body.add_child(UiTheme.paragraph(UiTheme.join_list(PackedStringArray(next)), 17, UiTheme.TEXT_MUTED, 780))
	body.add_child(UiTheme.spacer(10))
	var ok := UiTheme.button(tr("UI_LEVEL_UP_OK"), "primary", Vector2(260, 56), "check", 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(hide_screen)
	body.add_child(ok)
	Audio.ui("confirm", -2.0)
	if visible:
		UiTheme.appear(panel)
	show_screen()


func _on_hidden() -> void:
	_levels.clear()


## What `level` opens, for display: [icon, name, tinted (a line icon to colour)].
static func entries(level: int) -> Array:
	var o := UnlockTable.opened_at(level)
	var out := []
	for crop: StringName in o["crops"]:
		var item := ItemDB.get_item(CropTable.get_crop(crop)["item"])
		out.append([item.icon, item.display_name(), false])
	for species: StringName in o["animals"]:
		out.append([RancherScreen.portrait(species), Animals.species_name(species), false])
	for id: StringName in o["recipes"]:
		var item := ItemDB.get_item(id)
		out.append([item.icon, item.display_name(), false])
	for id: StringName in o["projects"]:
		var group: String = ProjectTable.get_project(id)["group"]
		out.append([UiTheme.glyph(BuildScreen.GROUP_ICONS.get(group, "hammer")),
			TranslationServer.translate("PROJECT_" + String(id).to_upper()), true])
	for i: int in o["upgrades"]:
		out.append([UiTheme.glyph("wrench"), TranslationServer.translate("UNLOCK_UPGRADE") % i, true])
	if o["order_slot"]:
		out.append([UiTheme.glyph("tag"), TranslationServer.translate("UNLOCK_ORDER_SLOT"), true])
	if o["order_bonus"]:
		out.append([UiTheme.glyph("arrow_up"), TranslationServer.translate("UNLOCK_ORDER_BONUS") % roundi(UnlockTable.ORDER_BONUS * 100.0), true])
	return out


func _card(e: Array) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	var sb := UiTheme.box(Color(0, 0, 0, 0.26), 14, 1, Color(UiTheme.GOLD, 0.25))
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	# Item icons carry their own margin; line icons are drawn smaller.
	var pic := UiTheme.icon_rect(e[0], 88 if not e[2] else 46, UiTheme.GOLD_SOFT if e[2] else Color.WHITE)
	pic.custom_minimum_size = Vector2(0, 88)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(pic)
	var name_label := UiTheme.make_label(UiTheme.caps(String(e[1])), UiTheme.heading(15, UiTheme.TEXT, 700, 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(CARD.x - 20, 0)
	name_label.max_lines_visible = 2
	col.add_child(name_label)
	return card
