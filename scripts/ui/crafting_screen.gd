class_name CraftingScreen
extends ModalScreen
## The workbench. "Make": what can be made (RecipeTable.CRAFTING) on the left under
## their headings (tools, the campfire and bait, farm supplies, machines), the selected
## recipe's materials and the make button on the right; recipes open up with the farm
## level, materials come from the bag (a material the town market sells says so when
## short). Making takes a moment at the bench: a bar fills to the sound of the work
## (sawing wood, knocking stone, hammering iron), then the thing pops into the bag.
## "Tools": upgrade the tools in the bag (faster work, longer life) for iron ore and money.

## Cost of each tool upgrade level: iron ore, dollars, farm level needed.
const UPGRADE_COST := [{}, {"ore": 6, "money": 60, "level": UnlockTable.TOOL_UPGRADES[1]},
	{"ore": 15, "money": 180, "level": UnlockTable.TOOL_UPGRADES[2]}]

var _list: VBoxContainer
var _detail: VBoxContainer
var _selected: StringName = &""
var _tab := "make"
var _tabs: TabStrip
var _money: Label
var _tool_slot := -1
## Seconds a piece of work takes at the bench (the bar, the sounds).
const CRAFT_SECONDS := 1.4
## What is being made (&"" when the bench is idle), its bar and the picture that pops.
var _making: StringName = &""
var _make_bar: StatBar
var _head_icon: TextureRect
var _make_tween: Tween


func _ready() -> void:
	ui_name = &"crafting"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_WORKBENCH"), "hammer", tr("UI_WORKBENCH_HINT"))
	_tabs = TabStrip.new()
	_tabs.setup([["make", tr("UI_TAB_MAKE"), "hammer"], ["tools", tr("UI_TAB_TOOLS"), "wrench"]])
	_tabs.selected.connect(func(id: String) -> void:
		_tab = id
		_refresh())
	window.header_right.add_child(_tabs)
	_money = window.add_money_pill()
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
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(560, 600)
	body.add_child(card)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 14)
	card.add_child(_detail)
	PlayerState.inventory.changed.connect(func() -> void: if visible: _refresh())
	Events.money_changed.connect(func(_m: int, _d: int) -> void: if visible: _refresh())


func open() -> void:
	if _selected == &"":
		_selected = RecipeTable.CRAFT_ORDER[0]
	_refresh()
	show_screen()


func _refresh() -> void:
	# The bench is busy: the list and the card are drawn again when the work is done.
	if _making != &"":
		return
	for c in _list.get_children():
		c.queue_free()
	if _money:
		_money.text = UiTheme.money(Economy.money)
	if _tab == "tools":
		_refresh_tools()
		return
	var group := ""
	for id: StringName in RecipeTable.CRAFT_ORDER:
		var g := String(RecipeTable.crafting(id).get("group", ""))
		if g != group:
			group = g
			var head: Array = RecipeTable.GROUPS.get(g, ["", ""])
			if _list.get_child_count() > 0:
				_list.add_child(UiTheme.spacer(4))
			_list.add_child(UiTheme.section(tr(String(head[0])), String(head[1])))
		_list.add_child(_card(id))
	_show(_selected)


func _on_hidden() -> void:
	# Closed mid-work: nothing is used up.
	_making = &""
	if _make_tween:
		_make_tween.kill()


# --- Tool upgrades ------------------------------------------------------------------------

func _tool_slots() -> Array[int]:
	var out: Array[int] = []
	for i in PlayerState.inventory.size():
		var st := PlayerState.inventory.get_stack(i)
		if st and st.item.is_tool():
			out.append(i)
	return out


func _refresh_tools() -> void:
	var slots := _tool_slots()
	if _tool_slot not in slots:
		_tool_slot = slots[0] if not slots.is_empty() else -1
	if slots.is_empty():
		_list.add_child(UiTheme.paragraph(tr("UI_NO_TOOLS"), 17, UiTheme.TEXT_DIM, 400))
	for i in slots:
		_list.add_child(_tool_card(i))
	for c in _detail.get_children():
		c.queue_free()
	if _tool_slot >= 0:
		_show_tool(_tool_slot)


func _tool_card(slot: int) -> Button:
	var st := PlayerState.inventory.get_stack(slot)
	var b := Button.new()
	b.custom_minimum_size = Vector2(420, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var active := slot == _tool_slot
	var normal := UiTheme.box(UiTheme.CARD_ACTIVE if active else UiTheme.CARD, 12, 1,
			Color(UiTheme.GOLD, 0.7) if active else Color(1, 1, 1, 0.07))
	if active:
		normal.border_width_left = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.06) if active else UiTheme.CARD_HOVER
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, normal if state == "normal" else hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -14
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pic := UiTheme.icon_rect(st.item.icon, 46)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var name_label := UiTheme.make_label(st.display_name(), UiTheme.text(19, UiTheme.TEXT, 600))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.clip_text = true
	row.add_child(name_label)
	var chip := UiTheme.chip(tr("UI_UPGRADE_MAX") if st.upgrade >= ItemStack.MAX_UPGRADE else "+%d" % st.upgrade,
			UiTheme.GOLD if st.upgrade > 0 else UiTheme.TEXT_DIM, "", 15)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	b.pressed.connect(func() -> void:
		_tool_slot = slot
		_refresh())
	return b


func _show_tool(slot: int) -> void:
	var st := PlayerState.inventory.get_stack(slot)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_detail.add_child(head)
	head.add_child(UiTheme.icon_rect(st.item.icon, 72))
	var title := UiTheme.make_label(UiTheme.caps(st.display_name()), UiTheme.heading(34, UiTheme.TEXT, 700, 1))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	if st.upgrade >= ItemStack.MAX_UPGRADE:
		_detail.add_child(UiTheme.paragraph(tr("UI_UPGRADE_DONE"), 18, UiTheme.TEXT_MUTED, 510))
		return
	var next := st.upgrade + 1
	var cost: Dictionary = UPGRADE_COST[next]
	_detail.add_child(UiTheme.paragraph(tr("UI_UPGRADE_DESC"), 18, UiTheme.TEXT_MUTED, 510))
	_detail.add_child(UiTheme.section(tr("UI_UPGRADE_EFFECT"), "sparkles"))
	var speed_now := roundi((1.0 - st.speed_factor()) * 100.0)
	var speed_next := roundi(0.2 * next * 100.0)
	_detail.add_child(UiTheme.icon_row(UiTheme.glyph("clock"), tr("UI_UPGRADE_SPEED") % [speed_now, speed_next], UiTheme.TEXT, 18, 20))
	if st.item.has_durability():
		var dur_next := roundi(st.item.max_durability * (1.0 + 0.5 * next))
		_detail.add_child(UiTheme.icon_row(UiTheme.glyph("wrench"), tr("UI_UPGRADE_DURABILITY") % [st.max_durability(), dur_next], UiTheme.TEXT, 18, 20))
	_detail.add_child(UiTheme.section(tr("UI_MATERIALS"), "box"))
	var ore := ItemDB.get_item(&"iron_ore")
	_detail.add_child(_cost_row(ore.icon, ore.display_name(), PlayerState.inventory.count_item(&"iron_ore"), int(cost["ore"])))
	_detail.add_child(_cost_row(null, tr("UI_GOLD").capitalize(), Economy.money, int(cost["money"]), true))
	var level_ok := Progress.level >= int(cost["level"])
	if not level_ok:
		_detail.add_child(UiTheme.icon_row(UiTheme.glyph("lock"), tr("UI_NEEDS_LEVEL") % [int(cost["level"]), Progress.level], UiTheme.RED, 18, 20))
	_detail.add_child(UiTheme.expand())
	var button := UiTheme.button(tr("UI_UPGRADE"), "primary", Vector2(510, 60), "wrench", 24)
	button.disabled = not can_upgrade(slot)
	button.pressed.connect(func() -> void:
		if upgrade_tool(slot):
			_refresh())
	_detail.add_child(button)


func can_upgrade(slot: int) -> bool:
	var st := PlayerState.inventory.get_stack(slot)
	if st == null or not st.item.is_tool() or st.upgrade >= ItemStack.MAX_UPGRADE:
		return false
	var cost: Dictionary = UPGRADE_COST[st.upgrade + 1]
	return Progress.level >= int(cost["level"]) and Economy.money >= int(cost["money"]) \
			and PlayerState.inventory.count_item(&"iron_ore") >= int(cost["ore"])


## Upgrades the tool in `slot` one level (and repairs it).
func upgrade_tool(slot: int) -> bool:
	if not can_upgrade(slot):
		return false
	var st := PlayerState.inventory.get_stack(slot)
	var cost: Dictionary = UPGRADE_COST[st.upgrade + 1]
	PlayerState.inventory.remove_item(&"iron_ore", int(cost["ore"]))
	Economy.spend(int(cost["money"]), "REPORT_UPGRADES")
	st.upgrade += 1
	if st.item.has_durability():
		st.durability = st.max_durability()
	PlayerState.inventory.changed.emit()
	Audio.play("metal", null, -4.0)
	Game.notify(tr("MSG_TOOL_UPGRADED") % st.display_name(), UiTheme.GOLD)
	Events.crafted.emit(st.item.id, 1)
	return true


func _unlocked(id: StringName) -> bool:
	return Progress.level >= int(RecipeTable.crafting(id).get("level", 1))


func _missing(id: StringName) -> bool:
	var r := RecipeTable.crafting(id)
	for item_id: StringName in r["items"]:
		if PlayerState.inventory.count_item(item_id) < int(r["items"][item_id]):
			return true
	return false


func _card(id: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(420, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var active := id == _selected
	var normal := UiTheme.box(UiTheme.CARD_ACTIVE if active else UiTheme.CARD, 12, 1,
			Color(UiTheme.GOLD, 0.7) if active else Color(1, 1, 1, 0.07))
	if active:
		normal.border_width_left = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.06) if active else UiTheme.CARD_HOVER
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, normal if state == "normal" else hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -14
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var item := ItemDB.get_item(id)
	var pic := UiTheme.icon_rect(item.icon, 46)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var unlocked := _unlocked(id)
	var name_label := UiTheme.make_label(item.display_name(), UiTheme.text(19, UiTheme.TEXT if unlocked else UiTheme.TEXT_DIM, 600))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.clip_text = true
	row.add_child(name_label)
	var chip: Control
	if not unlocked:
		chip = UiTheme.chip(tr("UI_LEVEL_SHORT") % int(RecipeTable.crafting(id)["level"]), UiTheme.TEXT_DIM, "lock", 15)
	elif _missing(id):
		chip = UiTheme.chip(tr("UI_NEEDS_MATERIALS"), UiTheme.TEXT_MUTED, "", 14)
	else:
		chip = UiTheme.chip(tr("UI_CAN_MAKE"), UiTheme.GREEN, "check", 15)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	b.pressed.connect(func() -> void:
		_selected = id
		_refresh())
	return b


func _show(id: StringName) -> void:
	for c in _detail.get_children():
		c.queue_free()
	var r := RecipeTable.crafting(id)
	if r.is_empty():
		return
	var item := ItemDB.get_item(id)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_detail.add_child(head)
	_head_icon = UiTheme.icon_rect(item.icon, 72)
	head.add_child(_head_icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(titles)
	titles.add_child(UiTheme.make_label(UiTheme.caps(item.display_name()), UiTheme.heading(34, UiTheme.TEXT, 700, 1)))
	var count := int(r.get("count", 1))
	if count > 1:
		titles.add_child(UiTheme.make_label(tr("UI_MAKES") % count, UiTheme.text(16, UiTheme.GOLD_SOFT, 600)))
	_detail.add_child(UiTheme.paragraph(item.description(), 18, UiTheme.TEXT_MUTED, 510))
	var level := int(r.get("level", 1))
	if not _unlocked(id):
		var lock := UiTheme.icon_row(UiTheme.glyph("lock"), tr("UI_NEEDS_LEVEL") % [level, Progress.level], UiTheme.RED, 18, 20)
		_detail.add_child(lock)
	_detail.add_child(UiTheme.section(tr("UI_MATERIALS"), "box"))
	var from_market := PackedStringArray()
	for item_id: StringName in r["items"]:
		var it := ItemDB.get_item(item_id)
		var have := PlayerState.inventory.count_item(item_id)
		_detail.add_child(_cost_row(it.icon, it.display_name(), have, int(r["items"][item_id])))
		if have < int(r["items"][item_id]) and item_id in ShopStock.MARKET_EXTRAS:
			from_market.append(it.display_name())
	if not from_market.is_empty():
		_detail.add_child(UiTheme.icon_row(UiTheme.glyph("store"), tr("UI_SOLD_AT_MARKET") % UiTheme.join_list(from_market),
				UiTheme.GOLD_SOFT, 17, 18))
	_detail.add_child(UiTheme.expand())
	_make_bar = StatBar.new(8.0, UiTheme.GOLD)
	_make_bar.max_value = 1.0
	_make_bar.modulate.a = 0.0
	_detail.add_child(_make_bar)
	var button := UiTheme.button(tr("UI_CRAFT"), "primary", Vector2(510, 60), "hammer", 24)
	button.disabled = not _unlocked(id) or _missing(id)
	button.pressed.connect(_craft.bind(id, button))
	_detail.add_child(button)


## Icon, name, have / need and a meter for one material.
## `dollars`: the amounts are money (else counts of a material); no `tex`: no picture.
func _cost_row(tex: Texture2D, label: String, have: int, need: int, dollars := false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		row.add_child(UiTheme.icon_rect(tex, 40))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var l := UiTheme.make_label(label, UiTheme.text(18, UiTheme.TEXT, 600))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var ok := have >= need
	var amounts := "%s / %s" % [UiTheme.money(mini(have, need)), UiTheme.money(need)] if dollars else "%d / %d" % [mini(have, need), need]
	head.add_child(UiTheme.make_label(amounts, UiTheme.heading(20, UiTheme.GREEN if ok else UiTheme.RED, 700, 0)))
	var bar := StatBar.new(6.0, UiTheme.GREEN if ok else UiTheme.GOLD)
	bar.max_value = need
	bar.set_value(mini(have, need), false)
	col.add_child(bar)
	return row


## Makes one batch: materials out of the bag, the result in.
func craft(id: StringName) -> bool:
	if not _unlocked(id) or _missing(id):
		return false
	var r := RecipeTable.crafting(id)
	var count := int(r.get("count", 1))
	for item_id: StringName in r["items"]:
		PlayerState.inventory.remove_item(item_id, int(r["items"][item_id]))
	var left := PlayerState.give(id, count)
	if left > 0 and Game.player:
		(Game.player as Player).drop_stack(ItemStack.create(id, left))
	Audio.play("wood_hit", null, -8.0)
	Events.crafted.emit(id, count)
	return true


## The make button: the work takes CRAFT_SECONDS at the bench, then the thing is made.
func _craft(id: StringName, button: Control) -> void:
	if _making != &"" or not _unlocked(id) or _missing(id):
		return
	_making = id
	if button is BaseButton:
		(button as BaseButton).disabled = true
	_make_bar.set_value(0.0, false)
	_make_tween = create_tween()
	_make_tween.tween_property(_make_bar, "modulate:a", 1.0, 0.12)
	_make_tween.parallel().tween_method(func(v: float) -> void: _make_bar.set_value(v, false), 0.0, 1.0, CRAFT_SECONDS)
	var knocks := 4
	for i in knocks:
		get_tree().create_timer(CRAFT_SECONDS * (0.08 + 0.23 * i)).timeout.connect(_work_sound.bind(id))
	await _make_tween.finished
	if _making != id or not visible:
		return
	_making = &""
	if not craft(id):
		_refresh()
		return
	Audio.ui("confirm", -6.0)
	var item := ItemDB.get_item(id)
	var count := int(RecipeTable.crafting(id).get("count", 1))
	Game.notify(tr("MSG_CRAFTED") % ("%s ×%d" % [item.display_name(), count] if count > 1 else item.display_name()), UiTheme.GREEN)
	_refresh()
	# The new thing pops in the card.
	if _head_icon:
		_head_icon.pivot_offset = _head_icon.custom_minimum_size * 0.5
		_head_icon.scale = Vector2.ONE * 1.3
		create_tween().tween_property(_head_icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## One knock of the work, by what the recipe is made of.
func _work_sound(id: StringName) -> void:
	if _making != id or not visible:
		return
	var items: Dictionary = RecipeTable.crafting(id).get("items", {})
	var pick: Array[String] = []
	if items.has(&"iron_ore") or items.has(&"nails"):
		pick.append("metal")
	if items.has(&"stone"):
		pick.append("pick")
	if items.has(&"wood"):
		pick.append_array(["wood_hit", "plank"])
	if pick.is_empty():
		pick.append("soft")
	Audio.play(pick[randi() % pick.size()], null, -9.0, 0.12)
