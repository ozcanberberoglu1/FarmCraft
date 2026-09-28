class_name BuildScreen
extends ModalScreen
## Construction board: projects (fields, animal housing, house upgrades) grouped on
## the left with their status, the selected one's requirements and costs on the
## right, and the build button. Kit projects (the chicken coop) are cut and bundled
## here and go into the bag; the player puts them up wherever they like.

const GROUP_ICONS := {"field": "wheat", "animals": "paw", "house": "home", "storage": "warehouse"}

var _list: VBoxContainer
var _detail: VBoxContainer
var _selected: StringName = &""


func _ready() -> void:
	ui_name = &"build"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_BUILD_BOARD"), "hammer", tr("UI_BUILD_HINT"))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.body.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var detail_card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(24)
	detail_card.add_theme_stylebox_override("panel", sb)
	detail_card.custom_minimum_size = Vector2(560, 600)
	body.add_child(detail_card)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 14)
	detail_card.add_child(_detail)
	FarmState.project_built.connect(func(_id: StringName) -> void: if visible: _refresh())
	Events.money_changed.connect(func(_m: int, _d: int) -> void: if visible: _show_detail(_selected))


func open(focus: StringName = &"") -> void:
	_selected = focus if focus != &"" else _first_open()
	_refresh()
	show_screen()


## The first project on the board that can be built now (the repairs on a new farm),
## else the first one not built yet.
func _first_open() -> StringName:
	var fallback: StringName = &""
	for id: StringName in ProjectTable.ORDER:
		if FarmState.is_built(id) or not FarmState.is_listed(id):
			continue
		if FarmState.can_build(id):
			return id
		if fallback == &"":
			fallback = id
	return fallback if fallback != &"" else ProjectTable.ORDER[0]


func close_screen() -> void:
	hide_screen()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var group := ""
	for id: StringName in ProjectTable.ORDER:
		if not FarmState.is_listed(id):
			continue
		var p := ProjectTable.get_project(id)
		if p["group"] != group:
			group = p["group"]
			if _list.get_child_count() > 0:
				_list.add_child(UiTheme.spacer(6))
			_list.add_child(UiTheme.section(tr("BUILD_GROUP_" + group.to_upper()), GROUP_ICONS.get(group, "")))
		_list.add_child(_make_card(id))
	_show_detail(_selected)


func _status(id: StringName) -> String:
	if FarmState.is_built(id):
		return "built"
	if not FarmState.can_build(id):
		return "locked"
	return "available"


func _make_card(id: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(420, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var status := _status(id)
	var active := id == _selected
	var normal := UiTheme.box(UiTheme.CARD_ACTIVE if active else UiTheme.CARD, 12, 1,
			Color(UiTheme.GOLD, 0.7) if active else Color(1, 1, 1, 0.07))
	if active:
		normal.border_width_left = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.06) if active else UiTheme.CARD_HOVER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -14
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var name_label := UiTheme.make_label(UiTheme.caps(tr("PROJECT_" + String(id).to_upper())),
			UiTheme.heading(21, UiTheme.TEXT if status != "locked" else UiTheme.TEXT_DIM, 700, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.clip_text = true
	row.add_child(name_label)
	var chip: Control
	match status:
		"built":
			chip = UiTheme.chip(tr("BUILD_DONE"), UiTheme.GREEN, "check", 15)
		"locked":
			var need := UnlockTable.project_level(id)
			chip = UiTheme.chip(tr("UI_LEVEL_SHORT") % need if Progress.level < need else tr("BUILD_LOCKED"), UiTheme.TEXT_DIM, "lock", 15)
		_:
			var kit := ProjectTable.kit_of(id)
			if kit != &"" and PlayerState.inventory.count_item(kit) > 0:
				chip = UiTheme.chip(tr("BUILD_IN_BAG"), UiTheme.GOLD, "backpack", 15)
			else:
				chip = UiTheme.price(int(ProjectTable.get_project(id)["cost"]), 21, 22)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	b.pressed.connect(func() -> void:
		_selected = id
		_refresh())
	return b


func _show_detail(id: StringName) -> void:
	for c in _detail.get_children():
		c.queue_free()
	if id == &"":
		return
	var p := ProjectTable.get_project(id)
	var status := _status(id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_detail.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph(GROUP_ICONS.get(p["group"], "hammer")), 34, UiTheme.GOLD_SOFT))
	var title := UiTheme.make_label(UiTheme.caps(tr("PROJECT_" + String(id).to_upper())), UiTheme.heading(38, UiTheme.TEXT, 700, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_detail.add_child(UiTheme.paragraph(tr("PROJECT_%s_DESC" % String(id).to_upper()), 19, UiTheme.TEXT_MUTED, 510))
	if status == "built":
		_detail.add_child(UiTheme.spacer(12))
		var done := UiTheme.chip(tr("BUILD_DONE"), UiTheme.GREEN, "check", 22)
		done.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_detail.add_child(done)
		return
	var reqs: Array = p["requires"]
	var need := UnlockTable.project_level(id)
	if not reqs.is_empty() or need > 1:
		_detail.add_child(UiTheme.section(tr("BUILD_REQUIREMENTS"), "lock"))
		if need > 1:
			var ok := Progress.level >= need
			var r := UiTheme.icon_row(UiTheme.glyph("check" if ok else "close"), tr("HUD_FARM_LEVEL") % need,
					UiTheme.GREEN if ok else UiTheme.RED, 20, 20)
			(r.get_child(0) as TextureRect).modulate = UiTheme.GREEN if ok else UiTheme.RED
			_detail.add_child(r)
		for req: StringName in reqs:
			var ok := FarmState.is_built(req)
			var r := UiTheme.icon_row(UiTheme.glyph("check" if ok else "close"),
					tr("PROJECT_" + String(req).to_upper()), UiTheme.GREEN if ok else UiTheme.RED, 20, 20)
			(r.get_child(0) as TextureRect).modulate = UiTheme.GREEN if ok else UiTheme.RED
			_detail.add_child(r)
	var kit := ProjectTable.kit_of(id)
	if kit != &"":
		var info := PlaceableTable.get_info(kit)
		var minutes := ceili(float(info.get("build_seconds", 60.0)) / 60.0)
		_detail.add_child(UiTheme.icon_row(UiTheme.glyph("clock"), tr("BUILD_TIME_MIN") % minutes, UiTheme.TEXT, 20, 20))
		_detail.add_child(UiTheme.paragraph(tr("BUILD_KIT_HINT"), 16, UiTheme.TEXT_MUTED, 510))
		var have := PlayerState.inventory.count_item(kit)
		if have > 0:
			_detail.add_child(UiTheme.icon_row(UiTheme.glyph("backpack"), "%s ×%d" % [tr("BUILD_IN_BAG"), have], UiTheme.GOLD, 20, 20))
	_detail.add_child(UiTheme.section(tr("BUILD_COST"), "coin"))
	var cost := int(p["cost"])
	_detail.add_child(_cost_row(UiTheme.glyph("coin"), tr("UI_GOLD").capitalize(), Economy.money, cost))
	for item_id: StringName in p["items"]:
		var item := ItemDB.get_item(item_id)
		_detail.add_child(_cost_row(item.icon, item.display_name(), PlayerState.inventory.count_item(item_id), int(p["items"][item_id])))
	_detail.add_child(UiTheme.expand())
	var missing := FarmState.missing_for(id)
	if missing != "" and status == "available":
		var ml := UiTheme.paragraph(tr("BUILD_MISSING") % missing, 16, UiTheme.RED, 510)
		_detail.add_child(ml)
	var button := UiTheme.button(tr("BUILD_MAKE_KIT" if kit != &"" else "BUILD_BUTTON"), "primary", Vector2(510, 60),
			"box" if kit != &"" else "hammer", 24)
	button.disabled = status != "available" or missing != ""
	button.pressed.connect(_build.bind(id))
	_detail.add_child(button)


## Icon, name, have / need and a progress meter for one cost.
func _cost_row(tex: Texture2D, label: String, have: int, need: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := UiTheme.icon_rect(tex, 40)
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var l := UiTheme.make_label(label, UiTheme.text(18, UiTheme.TEXT, 600))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var ok := have >= need
	head.add_child(UiTheme.make_label("%s / %s" % [UiTheme.money(mini(have, need)), UiTheme.money(need)],
			UiTheme.heading(20, UiTheme.GREEN if ok else UiTheme.RED, 700, 0)))
	var bar := StatBar.new(6.0, UiTheme.GREEN if ok else UiTheme.GOLD)
	bar.max_value = need
	bar.set_value(mini(have, need), false)
	col.add_child(bar)
	return row


func _build(id: StringName) -> void:
	if not FarmState.build(id):
		return
	var kit := ProjectTable.kit_of(id)
	if kit != &"":
		# In hand at once: closing the board shows where it would go up (brought down
		# from the bag into the hotbar when it landed there).
		var inv := PlayerState.inventory
		var at := -1
		for i in inv.size():
			var s := inv.get_stack(i)
			if s and s.item.id == kit:
				at = i
				if i < PlayerState.HOTBAR_SIZE:
					break
		if at >= PlayerState.HOTBAR_SIZE:
			var free := inv.first_empty(0, PlayerState.HOTBAR_SIZE)
			var to := free if free >= 0 else PlayerState.selected
			Inventory.transfer(inv, at, inv, to)
			at = to
		if at >= 0:
			PlayerState.select(at)
		Game.notify(tr("MSG_KIT_READY") % ItemDB.get_item(kit).display_name(), UiTheme.GREEN)
	close_screen()
