class_name InventoryScreen
extends ModalScreen
## Inventory (6×6, first slots = hotbar) with an item details card, and when a
## container such as a chest is open, its grid beside it with take/store-all
## buttons. Dragging an item outside the window drops it into the world.

const COLS := 6
const GAP := 8

var _player_grid: GridContainer
var _player_head: HBoxContainer
var _fill_label: Label
var _container_col: VBoxContainer
var _container_head: HBoxContainer
var _container_grid: GridContainer
var _details: PanelContainer
var _details_box: VBoxContainer
var _player_slots: Array[SlotUI] = []
var _container_slots: Array[SlotUI] = []
var _container: Inventory
var _on_close: Callable
var _hovered: SlotUI


func _ready() -> void:
	ui_name = &"inventory"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_INVENTORY"), "backpack", tr("UI_INV_HINT"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.body.add_child(row)
	# Container column (chests).
	_container_col = VBoxContainer.new()
	_container_col.add_theme_constant_override("separation", 12)
	_container_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_container_col)
	_container_head = UiTheme.section("", "chest")
	_container_col.add_child(_container_head)
	_container_grid = _grid(4)
	_container_col.add_child(_container_grid)
	var moves := HBoxContainer.new()
	moves.add_theme_constant_override("separation", 8)
	_container_col.add_child(moves)
	var take := UiTheme.button(tr("UI_TAKE_ALL"), "secondary", Vector2(0, 42), "arrow_down", 17)
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.pressed.connect(_move_all.bind(true))
	moves.add_child(take)
	var store := UiTheme.button(tr("UI_STORE_ALL"), "secondary", Vector2(0, 42), "arrow_up", 17)
	store.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store.pressed.connect(_move_all.bind(false))
	moves.add_child(store)
	# Player column.
	var player_col := VBoxContainer.new()
	player_col.add_theme_constant_override("separation", 12)
	player_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(player_col)
	_player_head = UiTheme.section(tr("UI_BAG"), "backpack")
	_fill_label = UiTheme.make_label("", UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 1))
	_player_head.add_child(_fill_label)
	player_col.add_child(_player_head)
	_player_grid = _grid(COLS)
	player_col.add_child(_player_grid)
	# Details card.
	_details = PanelContainer.new()
	_details.custom_minimum_size = Vector2(320, 0)
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(18)
	_details.add_theme_stylebox_override("panel", sb)
	row.add_child(_details)
	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 10)
	_details_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(_details_box)
	var inv := PlayerState.inventory
	for i in inv.size():
		_player_slots.append(_make_slot(_player_grid, inv, i, i + 1 if i < PlayerState.HOTBAR_SIZE else -1))
	inv.changed.connect(_refresh_player)


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	return g


## Opens the window; pass a container inventory (e.g. a chest) to show it too. The bag
## alone doesn't open on a new farm before its first item (PlayerState.hotbar_unlocked);
## a container still shows it.
func open(container: Inventory = null, title := "", on_close := Callable()) -> void:
	if container == null and not PlayerState.hotbar_unlocked:
		return
	_clear_container()
	_container = container
	_on_close = on_close
	_container_col.visible = container != null
	if container:
		(_container_head.get_child(1) as Label).text = UiTheme.caps(title)
		_container_grid.columns = 4 if container.size() <= 16 else COLS
		for i in container.size():
			_container_slots.append(_make_slot(_container_grid, container, i, -1))
		container.changed.connect(_refresh_container)
	window.set_heading(title if container else tr("UI_INVENTORY"), "chest" if container else "backpack", tr("UI_INV_HINT"))
	_refresh_player()
	_show_details(null)
	show_screen()


func close() -> void:
	hide_screen()


func _on_hidden() -> void:
	if _container and _container.changed.is_connected(_refresh_container):
		_container.changed.disconnect(_refresh_container)
	_clear_container()
	_container = null
	_hovered = null
	if _on_close.is_valid():
		_on_close.call()
	_on_close = Callable()


func _clear_container() -> void:
	for s in _container_slots:
		s.queue_free()
	_container_slots.clear()


func _make_slot(parent: Control, inv: Inventory, index: int, number: int) -> SlotUI:
	var slot := SlotUI.new()
	parent.add_child(slot)
	slot.setup(inv, index, number)
	slot.quick_move.connect(_quick_move)
	slot.hovered.connect(_on_slot_hovered)
	return slot


func _refresh_player() -> void:
	var used := 0
	for s in _player_slots:
		s.refresh()
		if s.stack():
			used += 1
	_fill_label.text = "%d / %d" % [used, _player_slots.size()]
	if _hovered:
		_show_details(_hovered.stack())


func _refresh_container() -> void:
	for s in _container_slots:
		s.refresh()


func _quick_move(slot: SlotUI) -> void:
	var stack := slot.stack()
	if stack == null:
		return
	var target: Inventory
	var first := 0
	var last := -1
	if slot.inventory == PlayerState.inventory:
		if _container:
			target = _container
		else:
			target = PlayerState.inventory
			var in_hotbar := slot.index < PlayerState.HOTBAR_SIZE
			first = PlayerState.HOTBAR_SIZE if in_hotbar else 0
			last = -1 if in_hotbar else PlayerState.HOTBAR_SIZE
	else:
		target = PlayerState.inventory
	var left := target.add_stack(stack, first, last)
	if left == 0:
		slot.inventory.set_stack(slot.index, null)
	else:
		stack.count = left
		slot.inventory.changed.emit()


## Takes everything from the container (take = true) or stores the bag's
## non-hotbar items in it.
func _move_all(take: bool) -> void:
	if _container == null:
		return
	var from: Array[SlotUI] = _container_slots if take else _player_slots
	for slot in from:
		if not take and slot.index < PlayerState.HOTBAR_SIZE:
			continue
		if slot.stack():
			_quick_move(slot)


# --- Dropping into the world ------------------------------------------------------

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("inventory")


func _drop_data(_at: Vector2, data: Variant) -> void:
	var inv: Inventory = data["inventory"]
	var index: int = data["index"]
	var s := inv.get_stack(index)
	if s and Game.player and Game.player.has_method("drop_stack"):
		Game.player.drop_stack(inv.take_from(index, s.count))


# --- Details ---------------------------------------------------------------------

func _on_slot_hovered(slot: SlotUI, inside: bool) -> void:
	if inside:
		_hovered = slot
		_show_details(slot.stack())
	elif _hovered == slot:
		_hovered = null


func _show_details(s: ItemStack) -> void:
	for c in _details_box.get_children():
		c.queue_free()
	if s == null:
		var hint := UiTheme.paragraph(tr("UI_INV_EMPTY_DETAILS"), 17, UiTheme.TEXT_DIM, 284)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_details_box.add_child(UiTheme.spacer(150))
		_details_box.add_child(UiTheme.icon_rect(UiTheme.glyph("info"), 40, UiTheme.TEXT_DIM))
		_details_box.add_child(hint)
		return
	var stage := PanelContainer.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.04), 12))
	_details_box.add_child(stage)
	var pic := UiTheme.icon_rect(s.item.icon, 150)
	pic.custom_minimum_size = Vector2(284, 160)
	stage.add_child(pic)
	var name_label := UiTheme.make_label(UiTheme.caps(s.display_name()), UiTheme.heading(30, UiTheme.TEXT, 700, 1))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(284, 0)
	_details_box.add_child(name_label)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details_box.add_child(chips)
	chips.add_child(UiTheme.chip(s.item.category_name(), UiTheme.TEXT_MUTED))
	if s.quality == ItemStack.Quality.SILVER:
		chips.add_child(UiTheme.chip(tr("UI_QUALITY_SILVER"), Color("dfe7f2"), "star"))
	elif s.quality == ItemStack.Quality.GOLD:
		chips.add_child(UiTheme.chip(tr("UI_QUALITY_GOLD"), UiTheme.GOLD, "star"))
	var desc := s.item.description()
	if desc != "":
		_details_box.add_child(UiTheme.paragraph(desc, 17, UiTheme.TEXT_MUTED, 284))
	if s.item.has_durability():
		_details_box.add_child(_meter_row(tr("UI_DURABILITY_LABEL"), s.durability, s.max_durability(), Color(0, 0, 0, 0)))
	if s.item.water_capacity > 0:
		_details_box.add_child(_meter_row(tr("UI_WATER_LABEL"), s.water, s.item.water_capacity, UiTheme.BLUE))
	if s.count > 1:
		_details_box.add_child(UiTheme.icon_row(UiTheme.glyph("backpack"), "× %d" % s.count, UiTheme.TEXT, 20, 20))
	if s.item.sell_price > 0:
		var price_row := HBoxContainer.new()
		price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pl := UiTheme.make_label(UiTheme.caps(tr("UI_SELLS_FOR")), UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 2))
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		price_row.add_child(pl)
		price_row.add_child(UiTheme.price(s.item.sell_price, 24, 24))
		_details_box.add_child(UiTheme.separator())
		_details_box.add_child(price_row)


func _meter_row(label: String, value: int, max_value: int, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.make_label(UiTheme.caps(label), UiTheme.heading(16, UiTheme.TEXT_MUTED, 700, 2))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(UiTheme.make_label("%d / %d" % [value, max_value], UiTheme.heading(17, UiTheme.TEXT, 700, 0)))
	box.add_child(head)
	var bar := StatBar.new(8.0, color)
	bar.max_value = max_value
	bar.set_value(value, false)
	bar.custom_minimum_size = Vector2(284, 8)
	box.add_child(bar)
	return box
