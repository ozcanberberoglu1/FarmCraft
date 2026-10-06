class_name BuildScreen
extends ModalScreen
## Construction board: projects (fields, animal housing, house upgrades) grouped on
## the left with their status, the selected one's requirements and costs on the
## right, and the build button. Kit projects (the chicken coop) are cut and bundled
## here and go into the bag; the player puts them up wherever they like.
## The coop expansion is made on one of the farm's kit-built coops: with one coop it is
## that one; with more, the detail lists them (birds, size, how far from the house, a
## "Show" that puts the dot over it) and the player picks one first.
## Opened while a story goal needs a project (Quests.board_project: the coop kit of the
## first day, the workbench kit of the second...), the board opens on that card: picked,
## scrolled into view and tagged "Goal" (only as it opens: after that the list stays
## where the player scrolls it, whatever is clicked or refreshed). While the first
## day's coop is still to be made (Quests.coop_comes_first) everything else that costs
## money is locked ("the coop first"), and a farmer whose money is gone gets that first
## coop kit for its wood alone (Grandpa paid for it: Quests.coop_kit_is_gift), so the
## story never dead-ends here.

const GROUP_ICONS := {"field": "wheat", "animals": "paw", "house": "home", "storage": "warehouse", "workshop": "hammer"}

var _list: VBoxContainer
var _scroll: ScrollContainer
## Project id -> its card in the list.
var _cards := {}
var _detail: VBoxContainer
var _selected: StringName = &""
## The coop picked for the expansion (its uid; "" for the first that can be made longer).
var _coop_pick := ""


func _ready() -> void:
	ui_name = &"build"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_BUILD_BOARD"), "hammer", tr("UI_BUILD_HINT"))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.body.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(440, 600)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
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


## Opens the board on `focus`; without one, on the project the story's goal needs
## (goal_project), else on the first that can be built. The card picked is scrolled
## into view.
func open(focus: StringName = &"") -> void:
	var goal := goal_project()
	if focus != &"" and on_board(focus):
		_selected = focus
	else:
		_selected = goal if goal != &"" else _first_open()
	_refresh()
	show_screen()
	# Only here, as the board opens: the list goes to the card picked for the player.
	_reveal_selected()


## The project the story's current goal needs from the board (&"" for none, or when the
## board doesn't show it).
static func goal_project() -> StringName:
	var id := Quests.board_project()
	return id if id != &"" and on_board(id) else &""


## Why the story keeps `id` from being made now ("" when it doesn't): while the first
## day's coop is to be made, every other project that costs money waits for it.
static func story_lock(id: StringName) -> String:
	if id == &"coop_kit" or not Quests.coop_comes_first():
		return ""
	var cost := int(ProjectTable.get_project(id).get("cost", 0))
	if ProjectTable.is_per_coop(id):
		cost = int(ProjectTable.coop_step(0).get("cost", 0))
	return "BUILD_COOP_FIRST" if cost > 0 else ""


## Whether `id` is made for its materials alone now (the story's first coop kit with the
## money gone: Grandpa paid for it).
static func is_gift(id: StringName) -> bool:
	return id == &"coop_kit" and Quests.coop_kit_is_gift()


## The picked card in the middle of the list's view, once the list is laid out.
func _reveal_selected() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var card := _cards.get(_selected) as Control
	if not visible or card == null or not is_instance_valid(card):
		return
	_scroll.scroll_vertical = maxi(int(card.position.y - (_scroll.size.y - card.size.y) * 0.5), 0)


## Whether the board shows `id`: listed for this farm and not built by hand (the
## repairs of Grandpa's house and warehouse, see RepairSpot).
static func on_board(id: StringName) -> bool:
	if ProjectTable.needs_pet(id) and not Pet.has_dog():
		# The doghouse: only once there is a dog to live in it.
		return false
	return FarmState.is_listed(id) and not ProjectTable.is_hands_on(id)


## Whether the one `id` the farm needs stands already (the doghouse: put up, or going up).
static func single_stands(id: StringName) -> bool:
	var kit := ProjectTable.kit_of(id)
	if not ProjectTable.is_single(id) or kit == &"":
		return false
	for e: Dictionary in FarmState.placed:
		if StringName(e["id"]) == kit:
			return true
	return false


## The first project on the board that can be built now, else the first one not built
## yet.
func _first_open() -> StringName:
	var fallback: StringName = &""
	var first: StringName = &""
	for id: StringName in ProjectTable.ORDER:
		if not on_board(id):
			continue
		if first == &"":
			first = id
		if FarmState.is_built(id):
			continue
		if FarmState.can_build(id):
			return id
		if fallback == &"":
			fallback = id
	return fallback if fallback != &"" else first


func close_screen() -> void:
	hide_screen()


## Builds the list and the detail again (something was built or paid for, a coop was
## picked for the expansion). The list stays where it was scrolled to: its old rows leave
## at once (_clear), so it is never taller or shorter than before on the way.
func _refresh() -> void:
	_clear(_list)
	_cards.clear()
	var group := ""
	for id: StringName in ProjectTable.ORDER:
		if not on_board(id):
			continue
		var p := ProjectTable.get_project(id)
		if p["group"] != group:
			# (a little room over every group but the first)
			if group != "":
				_list.add_child(UiTheme.spacer(6))
			group = p["group"]
			_list.add_child(UiTheme.section(tr("BUILD_GROUP_" + group.to_upper()), GROUP_ICONS.get(group, "")))
		var card := _make_card(id)
		_cards[id] = card
		_list.add_child(card)
	_show_detail(_selected)


## Takes `box`'s rows away: out of the layout at once, freed when the frame is over. Rows
## only queued to be freed stand beside the new ones for a frame: the detail, twice as
## tall for that frame, stretched the window and the list's view with it, and a view as
## tall as the whole list has nothing to scroll: it went back to its top and stayed there.
static func _clear(box: Container) -> void:
	for c in box.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		c.queue_free()


## Picks project `id`: its card lit (the one picked before plain again) and its detail
## shown. The list itself is left alone, so it stays where the player scrolled it.
func _select(id: StringName) -> void:
	var was := _selected
	_selected = id
	for other: StringName in [was, id]:
		var card := _cards.get(other) as Button
		if card and is_instance_valid(card):
			_style_card(card, other == id)
	_show_detail(id)


func _status(id: StringName) -> String:
	if ProjectTable.is_per_coop(id):
		return "locked" if Progress.level < UnlockTable.project_level(id) or story_lock(id) != "" else "available"
	if FarmState.is_built(id) or single_stands(id):
		return "built"
	if not FarmState.can_build(id) or story_lock(id) != "":
		return "locked"
	return "available"


func _make_card(id: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(420, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var status := _status(id)
	_style_card(b, id == _selected)
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
	if id == goal_project() and status != "built":
		# What the story's goal asks for.
		var tag := UiTheme.chip(tr("BUILD_GOAL_TAG"), UiTheme.GOLD, "star", 13)
		# Marked for the scripted checks (rows rebuilt in one frame can't share a name).
		tag.set_meta(&"mark", "GoalTag")
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	var chip: Control
	match status:
		"built":
			chip = UiTheme.chip(tr("BUILD_DONE"), UiTheme.GREEN, "check", 15)
		"locked":
			var need := UnlockTable.project_level(id)
			var why := tr("UI_LEVEL_SHORT") % need if Progress.level < need else tr("BUILD_LOCKED")
			if Progress.level >= need and story_lock(id) != "":
				why = tr(story_lock(id))
			chip = UiTheme.chip(why, UiTheme.TEXT_DIM, "lock", 15 if why.length() < 12 else 13)
		_:
			var kit := ProjectTable.kit_of(id)
			if ProjectTable.is_per_coop(id):
				chip = _expand_chip()
			elif kit != &"" and PlayerState.inventory.count_item(kit) > 0:
				chip = UiTheme.chip(tr("BUILD_IN_BAG"), UiTheme.GOLD, "backpack", 15)
			else:
				chip = UiTheme.price(0 if is_gift(id) else int(ProjectTable.get_project(id)["cost"]), 21)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	b.pressed.connect(_select.bind(id))
	return b


## A project card's look: the one picked (`active`) lit, with a gold edge.
func _style_card(b: Button, active: bool) -> void:
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
	b.set_meta(&"active", active)


func _show_detail(id: StringName) -> void:
	_clear(_detail)
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
	var story := story_lock(id)
	if story != "":
		# The first day's money is kept for the coop: say so instead of a bare padlock.
		var wait := UiTheme.paragraph(tr("BUILD_COOP_FIRST_LINE"), 17, UiTheme.GOLD_SOFT, 510)
		wait.set_meta(&"mark", "StoryLock")
		_detail.add_child(wait)
	if ProjectTable.is_per_coop(id):
		_show_expand_detail(id, status)
		return
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
			var req_name := tr("PROJECT_" + String(req).to_upper())
			if not ok and ProjectTable.is_hands_on(req):
				# Not sold here: say how it is done.
				req_name += " (%s)" % tr("SIGN_REPAIR_WALLS")
			var r := UiTheme.icon_row(UiTheme.glyph("check" if ok else "close"),
					req_name, UiTheme.GREEN if ok else UiTheme.RED, 20, 20)
			(r.get_child(0) as TextureRect).modulate = UiTheme.GREEN if ok else UiTheme.RED
			_detail.add_child(r)
	var kit := ProjectTable.kit_of(id)
	if kit != &"":
		_detail.add_child(UiTheme.icon_row(UiTheme.glyph("clock"), build_time_text(kit), UiTheme.TEXT, 20, 20))
		_detail.add_child(UiTheme.paragraph(tr("BUILD_KIT_HINT"), 16, UiTheme.TEXT_MUTED, 510))
		var have := PlayerState.inventory.count_item(kit)
		if have > 0:
			_detail.add_child(UiTheme.icon_row(UiTheme.glyph("backpack"), "%s ×%d" % [tr("BUILD_IN_BAG"), have], UiTheme.GOLD, 20, 20))
	_detail.add_child(UiTheme.section(tr("BUILD_COST"), "tag"))
	var gift := is_gift(id)
	var cost := 0 if gift else int(p["cost"])
	if gift:
		# The money went at the market: Grandpa paid for this one, only its wood is asked.
		var paid := UiTheme.paragraph(tr("BUILD_GRANDPA_PAID"), 17, UiTheme.GOLD_SOFT, 510)
		paid.set_meta(&"mark", "GrandpaPaid")
		_detail.add_child(paid)
	else:
		_detail.add_child(_cost_row(null, tr("UI_GOLD").capitalize(), Economy.money, cost, true))
	for item_id: StringName in p["items"]:
		var item := ItemDB.get_item(item_id)
		_detail.add_child(_cost_row(item.icon, item.display_name(), PlayerState.inventory.count_item(item_id), int(p["items"][item_id])))
	_detail.add_child(UiTheme.expand())
	var missing := FarmState.missing_cost(cost, p["items"])
	if missing != "" and status == "available":
		var ml := UiTheme.paragraph(tr("BUILD_MISSING") % missing, 16, UiTheme.RED, 510)
		_detail.add_child(ml)
	var button := UiTheme.button(tr("BUILD_MAKE_KIT" if kit != &"" else "BUILD_BUTTON"), "primary", Vector2(510, 60),
			"box" if kit != &"" else "hammer", 24)
	button.set_meta(&"mark", "BuildButton")
	button.disabled = status != "available" or missing != ""
	button.pressed.connect(_build.bind(id))
	_detail.add_child(button)


## Icon, name, have / need and a progress meter for one cost.
## `dollars`: the amounts are money (else counts of a material); no `tex`: no picture.
## How long kit `kit` takes to go up if it is put down now: "about 1 min", or "about 10
## seconds" for the story's first coop and workbench (Quests.build_seconds).
func build_time_text(kit: StringName) -> String:
	var secs := Quests.build_seconds(kit)
	if secs < 60.0:
		return tr("BUILD_TIME_SEC") % ceili(secs)
	return tr("BUILD_TIME_MIN") % ceili(secs / 60.0)


func _cost_row(tex: Texture2D, label: String, have: int, need: int, dollars := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		row.add_child(UiTheme.icon_rect(tex, 40))
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
	var amounts := "%s / %s" % [UiTheme.money(mini(have, need)), UiTheme.money(need)] if dollars \
			else "%s / %s" % [UiTheme.number(mini(have, need)), UiTheme.number(need)]
	head.add_child(UiTheme.make_label(amounts,
			UiTheme.heading(20, UiTheme.GREEN if ok else UiTheme.RED, 700, 0)))
	var bar := StatBar.new(6.0, UiTheme.GREEN if ok else UiTheme.GOLD)
	bar.max_value = need
	bar.set_value(mini(have, need), false)
	col.add_child(bar)
	return row


func _build(id: StringName) -> void:
	if story_lock(id) != "":
		return
	if ProjectTable.is_per_coop(id):
		_expand()
		return
	var gift := is_gift(id)
	if not FarmState.build(id, gift):
		return
	if gift:
		Game.notify(tr("BUILD_GRANDPA_PAID"), UiTheme.GOLD_SOFT)
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


# --- Coop expansion -------------------------------------------------------------------------

## The farm's kit-built coops, sites included, in the order they were put up.
static func _coops() -> Array[ChickenCoop]:
	var none: Array[ChickenCoop] = []
	var farm := Game.world.get("farm") as Farm if Game.world else null
	return farm.kit_coops() if farm else none


## The coop the expansion is for: the one picked, else the first that can be made longer
## now (the farm at its next step's level), else the first that could be at a higher
## level, else the first (null without a coop).
func _expand_target() -> ChickenCoop:
	var coops := _coops()
	for c in coops:
		if c.uid() == _coop_pick and c.expand_block() == "":
			return c
	for c in coops:
		if _can_expand_now(c):
			return c
	for c in coops:
		if c.expand_block() == "":
			return c
	return coops[0] if not coops.is_empty() else null


## Whether coop `c` can be made longer now: nothing in the way and the farm at the level
## its next step needs.
static func _can_expand_now(c: ChickenCoop) -> bool:
	return c.expand_block() == "" and Progress.level >= UnlockTable.coop_step_level(c.expansion())


## The expansion's tag in the list: its next step's price (a coop picked that waits on the
## farm level makes way for one that can be made longer now), else why not.
func _expand_chip() -> Control:
	var coop := _expand_target()
	if coop and not _can_expand_now(coop):
		for c in _coops():
			if _can_expand_now(c):
				coop = c
				break
	if coop == null or coop.expand_block() != "":
		var why := tr(coop.expand_block()) if coop else tr("BUILD_LOCKED")
		return UiTheme.chip(why, UiTheme.TEXT_DIM, "lock", 15)
	var need := UnlockTable.coop_step_level(coop.expansion())
	if Progress.level < need:
		return UiTheme.chip(tr("UI_LEVEL_SHORT") % need, UiTheme.TEXT_DIM, "lock", 15)
	return UiTheme.price(int(coop.next_step()["cost"]), 21)


## The expansion's detail: the coop it is for (or the list to pick one from), what it
## gets, the farm level, the time, the cost and the button.
func _show_expand_detail(id: StringName, status: String) -> void:
	var coops := _coops()
	var coop := _expand_target()
	var block := coop.expand_block() if coop else "BUILD_NEEDS_COOP"
	if coop == null:
		var r := UiTheme.icon_row(UiTheme.glyph("close"), tr("BUILD_NEEDS_COOP"), UiTheme.RED, 20, 20)
		(r.get_child(0) as TextureRect).modulate = UiTheme.RED
		_detail.add_child(r)
	else:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.add_child(UiTheme.section(tr("BUILD_EXPAND_PICK" if coops.size() > 1 else "BUILD_EXPAND_THIS"), "home"))
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		if coops.size() > 1:
			# A long list scrolls (two and a half rows show).
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.custom_minimum_size = Vector2(510, mini(coops.size(), 3) * 64 - (24 if coops.size() > 3 else 6))
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(rows)
			box.add_child(scroll)
		else:
			box.add_child(rows)
		for c in coops:
			rows.add_child(_coop_row(c, coops.size() > 1, c == coop and block == ""))
		_detail.add_child(box)
	var step := coop.expansion() if coop and block == "" else 0
	var cost: Dictionary = ProjectTable.coop_step(step)
	var need := UnlockTable.coop_step_level(step)
	var level_ok := Progress.level >= need
	if block == "":
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 4)
		info.add_child(UiTheme.icon_row(UiTheme.glyph("paw"), tr("BUILD_EXPAND_CHANGE") % [ChickenCoop.capacity_at(step),
				ChickenCoop.capacity_at(step + 1), ChickenCoop.NESTS_BY_SIZE[step], ChickenCoop.NESTS_BY_SIZE[step + 1]], UiTheme.GOLD_SOFT, 19, 20))
		var r := UiTheme.icon_row(UiTheme.glyph("check" if level_ok else "close"), tr("HUD_FARM_LEVEL") % need,
				UiTheme.GREEN if level_ok else UiTheme.RED, 19, 20)
		(r.get_child(0) as TextureRect).modulate = UiTheme.GREEN if level_ok else UiTheme.RED
		info.add_child(r)
		info.add_child(UiTheme.icon_row(UiTheme.glyph("clock"), tr("BUILD_TIME_MIN") % ceili(ChickenCoop.EXPAND_SECONDS / 60.0), UiTheme.TEXT, 19, 20))
		_detail.add_child(info)
	elif coop:
		var why := UiTheme.chip(tr(block), UiTheme.TEXT_DIM, "lock", 18)
		why.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_detail.add_child(why)
	# The price of the step to come (the first one's before there is a coop).
	if block == "" or coop == null:
		_detail.add_child(UiTheme.section(tr("BUILD_COST"), "tag"))
		_detail.add_child(_cost_row(null, tr("UI_GOLD").capitalize(), Economy.money, int(cost["cost"]), true))
		for item_id: StringName in cost["items"]:
			var item := ItemDB.get_item(item_id)
			_detail.add_child(_cost_row(item.icon, item.display_name(), PlayerState.inventory.count_item(item_id), int(cost["items"][item_id])))
	_detail.add_child(UiTheme.expand())
	var missing := FarmState.missing_cost(int(cost["cost"]), cost["items"])
	if missing != "" and block == "" and status == "available":
		_detail.add_child(UiTheme.paragraph(tr("BUILD_MISSING") % missing, 16, UiTheme.RED, 510))
	var button := UiTheme.button(tr("BUILD_EXPAND"), "primary", Vector2(510, 60), "hammer", 24)
	button.disabled = status != "available" or block != "" or not level_ok or missing != ""
	button.pressed.connect(_build.bind(id))
	_detail.add_child(button)


## A coop in the expansion's list: its name, birds and room, how often it was made longer
## and how far from the house it stands, why it can't be picked (as long as it gets,
## going up), and "Show". `pickable`: a button that picks it; `active`: the one picked.
func _coop_row(coop: ChickenCoop, pickable: bool, active: bool) -> Control:
	var row: Control
	var block := coop.expand_block()
	if pickable:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = block != ""
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if block == "" else Control.CURSOR_ARROW
		var normal := UiTheme.box(UiTheme.CARD_ACTIVE if active else UiTheme.CARD, 10, 1,
				Color(UiTheme.GOLD, 0.7) if active else Color(1, 1, 1, 0.07))
		if active:
			normal.border_width_left = 4
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = normal.bg_color.lightened(0.06) if active else UiTheme.CARD_HOVER
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, hover if state.begins_with("hover") or state == "pressed" else normal)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func() -> void:
			_coop_pick = coop.uid()
			_refresh())
		row = b
	else:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CARD, 10, 1, Color(1, 1, 1, 0.07)))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row = p
	row.custom_minimum_size = Vector2(500, 58)
	row.name = "Coop%d" % coop.number()
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 14
	line.offset_right = -10
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(col)
	var dim := block != "" and pickable
	col.add_child(UiTheme.make_label(UiTheme.caps(coop.coop_name()), UiTheme.heading(19, UiTheme.TEXT_DIM if dim else UiTheme.TEXT, 700, 1)))
	var birds := Animals.count_at(coop.housing) if coop.housing else 0
	var room := coop.housing.capacity() if coop.housing else ChickenCoop.capacity_at(0)
	var door := Vector2(WorldLayout.HOUSE_DOOR_X, WorldLayout.HOUSE_FRONT_Z)
	var c := coop.center_point()
	var facts := PackedStringArray([tr("BUILD_EXPAND_BIRDS") % [birds, room],
		tr("BUILD_EXPAND_LEVEL") % [coop.expansion(), ChickenCoop.MAX_EXPANSION],
		tr("BUILD_EXPAND_DISTANCE") % roundi(door.distance_to(Vector2(c.x, c.z)))])
	col.add_child(UiTheme.make_label(" · ".join(facts), UiTheme.text(15, UiTheme.TEXT_DIM if dim else UiTheme.TEXT_MUTED, 600)))
	if block != "":
		var why := UiTheme.chip(tr(block), UiTheme.TEXT_DIM, "", 13)
		why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(why)
	var show := UiTheme.button(tr("BUILD_SHOW"), "secondary", Vector2(0, 38), "cursor", 16)
	show.name = "Show"
	show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	show.pressed.connect(_show_coop.bind(coop))
	line.add_child(show)
	return row


## "Show": the board closes and the dot floats over the coop a while.
func _show_coop(coop: ChickenCoop) -> void:
	if not is_instance_valid(coop):
		return
	Quests.point_out(coop.center_point() + Vector3(0, 3.4, 0), coop.coop_name())
	close_screen()


## Pays for the next step on the coop picked and starts it.
func _expand() -> void:
	var coop := _expand_target()
	if coop == null or not coop.buy_expansion():
		return
	Game.notify(tr("MSG_COOP_EXPANDING") % coop.coop_name(), UiTheme.GREEN)
	close_screen()
