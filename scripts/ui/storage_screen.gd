class_name StorageScreen
extends ModalScreen
## Moves goods between the bag, the farm warehouse and a pickup's bed, shown as
## side-by-side columns. Each row has arrows to move one (Shift: ten) or all of it
## to the neighbouring column. Crated hens move like goods (tagged as live animals);
## keys and worn tools stay in the bag.

## Warehouse counts as "near" within this distance of a vehicle or the player.
const NEAR := 16.0

var _columns: HBoxContainer
var _vehicle: Vehicle
var _with_warehouse := true
var _lists := {}
var _refresh_queued := false


func _ready() -> void:
	ui_name = &"storage"
	close_actions = [&"pause", &"inventory", &"animal_info"]
	make_window(tr("UI_STORAGE"), "warehouse", tr("UI_STORAGE_HINT"))
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 18)
	window.body.add_child(_columns)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	window.body.add_child(foot)
	var store_all := UiTheme.button(tr("UI_STORE_ALL_GOODS"), "primary", Vector2(260, 48), "arrow_up", 18)
	store_all.pressed.connect(_store_all_goods)
	foot.add_child(store_all)
	var load_all := UiTheme.button(tr("UI_LOAD_ALL"), "secondary", Vector2(260, 48), "truck", 18)
	load_all.name = "LoadAll"
	load_all.pressed.connect(_load_all)
	foot.add_child(load_all)
	var unload := UiTheme.button(tr("UI_UNLOAD_BED"), "secondary", Vector2(260, 48), "arrow_down", 18)
	unload.name = "Unload"
	unload.pressed.connect(_unload_all)
	foot.add_child(unload)
	PlayerState.inventory.changed.connect(_queue_refresh)
	FarmState.warehouse.changed.connect(_queue_refresh)


## Opens with `vehicle`'s bed (or the nearest parked vehicle) and the warehouse when
## it is close enough.
func open(vehicle: Vehicle = null) -> void:
	var here := Game.player.global_position if Game.player else Vector3.ZERO
	_vehicle = vehicle
	if _vehicle == null:
		_vehicle = Town._nearest_owned_vehicle(_warehouse_door(), NEAR)
	var from := _vehicle.global_position if vehicle else here
	_with_warehouse = from.distance_to(_warehouse_door()) < NEAR or vehicle == null
	if _vehicle and not _vehicle.cargo.changed.is_connected(_on_cargo_changed):
		_vehicle.cargo.changed.connect(_on_cargo_changed)
	window.set_heading(tr("UI_STORAGE") if _with_warehouse else tr("UI_PICKUP_BED"), "warehouse" if _with_warehouse else "truck",
			tr("UI_STORAGE_HINT"))
	var foot := window.body.get_child(1)
	(foot.get_node("LoadAll") as Control).visible = _with_warehouse and _vehicle != null
	(foot.get_node("Unload") as Control).visible = _with_warehouse and _vehicle != null
	_refresh()
	show_screen()


func _on_hidden() -> void:
	if _vehicle and _vehicle.cargo.changed.is_connected(_on_cargo_changed):
		_vehicle.cargo.changed.disconnect(_on_cargo_changed)


func _on_cargo_changed() -> void:
	_queue_refresh()


## Store / load / unload all change the bag, warehouse and bed once per item kind;
## the columns are rebuilt once at the end of the frame instead of after each change.
func _queue_refresh() -> void:
	if visible and not _refresh_queued:
		_refresh_queued = true
		_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	_refresh_queued = false
	if visible:
		_refresh()


func _warehouse_door() -> Vector3:
	var r := WorldLayout.WAREHOUSE_RECT
	return Vector3(r.position.x + 4.0, 0.0, r.end.y)


# --- Columns -----------------------------------------------------------------------------

## Column order: bag, warehouse (if near), bed (if a vehicle).
func _sources() -> Array:
	var out := [["bag", tr("UI_BAG"), "backpack"]]
	if _with_warehouse:
		out.append(["warehouse", tr("UI_WAREHOUSE"), "warehouse"])
	if _vehicle:
		out.append(["bed", tr("UI_PICKUP_BED"), "truck"])
	return out


func _refresh() -> void:
	for c in _columns.get_children():
		c.queue_free()
	var sources := _sources()
	for i in sources.size():
		_columns.add_child(_column(sources, i))


func _column(sources: Array, i: int) -> Control:
	var src: Array = sources[i]
	var id: String = src[0]
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(420, 520)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var head := UiTheme.section(src[1], src[2])
	var fill := UiTheme.make_label(_fill_text(id), UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 1))
	head.add_child(fill)
	col.add_child(head)
	if id != "bag":
		var stock := _stock(id)
		var bar := StatBar.new(6.0, UiTheme.GOLD)
		bar.max_value = stock.capacity
		bar.set_value(stock.total(), false)
		col.add_child(bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var entries := _entries(id)
	if entries.is_empty():
		var empty := UiTheme.make_label(tr("UI_EMPTY"), UiTheme.text(17, UiTheme.TEXT_DIM, 600))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(UiTheme.spacer(40))
		list.add_child(empty)
	var left: String = sources[i - 1][0] if i > 0 else ""
	var right: String = sources[i + 1][0] if i + 1 < sources.size() else ""
	for e: Dictionary in entries:
		list.add_child(_row(id, e, left, right))
	return card


func _fill_text(id: String) -> String:
	if id == "bag":
		var used := 0
		for s in PlayerState.inventory.slots:
			if s:
				used += 1
		return "%d / %d" % [used, PlayerState.inventory.size()]
	var st := _stock(id)
	return "%s / %s" % [UiTheme.number(st.total()), UiTheme.number(st.capacity)]


func _stock(id: String) -> Stockpile:
	return FarmState.warehouse if id == "warehouse" else _vehicle.cargo


## [{id, quality, count, movable}] for a column.
func _entries(id: String) -> Array:
	if id != "bag":
		var out := []
		for e: Dictionary in _stock(id).entries():
			e["movable"] = true
			out.append(e)
		return out
	var merged := {}
	var order := []
	for s in PlayerState.inventory.slots:
		if s == null:
			continue
		var key := Stockpile.key_of(s.item.id, s.quality)
		if not merged.has(key):
			merged[key] = {"id": s.item.id, "quality": s.quality, "count": 0,
				"movable": Stockpile.can_store(s.item)}
			order.append(key)
		merged[key]["count"] += s.count
	var list := []
	for k in order:
		list.append(merged[k])
	return list


func _row(src: String, e: Dictionary, left: String, right: String) -> Control:
	var item := ItemDB.get_item(e["id"])
	var row := PanelContainer.new()
	var sb := UiTheme.box(Color(1, 1, 1, 0.04), 10, 1, Color(1, 1, 1, 0.06))
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var movable: bool = e.get("movable", true)
	if left != "":
		h.add_child(_arrow("chevron_left", src, left, e, false, movable))
		h.add_child(_arrow("chevrons_left", src, left, e, true, movable))
	h.add_child(UiTheme.icon_rect(item.icon, 40))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(names)
	names.add_child(UiTheme.make_label(item.display_name(), UiTheme.text(17, UiTheme.TEXT if movable else UiTheme.TEXT_DIM, 600)))
	if LiveCrates.is_live(item.id):
		names.add_child(UiTheme.make_label(tr("UI_LIVE_ANIMAL"), UiTheme.text(13, UiTheme.GREEN, 600)))
	var q: int = e["quality"]
	if q > 0:
		names.add_child(UiTheme.make_label("★ " + tr("UI_QUALITY_GOLD" if q == 2 else "UI_QUALITY_SILVER"), UiTheme.text(13, UiTheme.GOLD if q == 2 else Color("dfe7f2"), 600)))
	var count := UiTheme.make_label("× %d" % int(e["count"]), UiTheme.heading(21, UiTheme.TEXT, 700, 0))
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(count)
	if right != "":
		h.add_child(_arrow("chevrons_right", src, right, e, true, movable))
		h.add_child(_arrow("chevron_right", src, right, e, false, movable))
	return row


func _arrow(icon_name: String, from: String, to: String, e: Dictionary, all: bool, enabled: bool) -> Control:
	var b := IconButton.new(icon_name, 34, UiTheme.GOLD_SOFT if all else UiTheme.TEXT)
	b.disabled = not enabled
	b.tooltip_text = tr("UI_MOVE_ALL") if all else tr("UI_MOVE_ONE")
	b.pressed.connect(func() -> void:
		var amount := int(e["count"]) if all else (10 if Input.is_key_pressed(KEY_SHIFT) else 1)
		_move(from, to, e["id"], int(e["quality"]), amount))
	return b


## Moves `amount` of an item between two columns.
func _move(from: String, to: String, id: StringName, quality: int, amount: int) -> int:
	var moved := 0
	if from == "bag":
		var target := _stock(to)
		var left := amount
		for i in PlayerState.inventory.size():
			var s := PlayerState.inventory.get_stack(i)
			if s == null or s.item.id != id or s.quality != quality:
				continue
			var n := mini(mini(s.count, left), target.space())
			if n <= 0:
				break
			target.add(id, n, quality)
			PlayerState.inventory.take_from(i, n)
			moved += n
			left -= n
			if left <= 0:
				break
	elif to == "bag":
		moved = _stock(from).withdraw_to(PlayerState.inventory, id, quality, amount)
	else:
		moved = _stock(from).transfer_to(_stock(to), id, quality, amount)
	if moved < amount:
		Game.notify(tr("MSG_NO_ROOM"), UiTheme.RED)
	return moved


## Every bag item that can be stored goes to the warehouse (or the bed).
func _store_all_goods() -> void:
	var target := "warehouse" if _with_warehouse else "bed"
	for e: Dictionary in _entries("bag"):
		if e["movable"]:
			_move("bag", target, e["id"], e["quality"], e["count"])


## Loads the bed from the warehouse, most valuable goods first (crated hens stay: they
## only go aboard one by one, when the farmer means them to).
func _load_all() -> void:
	if _vehicle == null or not _with_warehouse:
		return
	var entries := FarmState.warehouse.entries().filter(func(e: Dictionary) -> bool: return not LiveCrates.is_live(e["id"]))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Economy.sell_price(a["id"], a["quality"]) > Economy.sell_price(b["id"], b["quality"]))
	for e: Dictionary in entries:
		if _vehicle.cargo.space() <= 0:
			break
		FarmState.warehouse.transfer_to(_vehicle.cargo, e["id"], e["quality"], e["count"])


## Empties the bed into the warehouse.
func _unload_all() -> void:
	if _vehicle == null or not _with_warehouse:
		return
	for e: Dictionary in _vehicle.cargo.entries():
		if _vehicle.cargo.transfer_to(FarmState.warehouse, e["id"], e["quality"], e["count"]) < int(e["count"]):
			Game.notify(tr("MSG_NO_ROOM"), UiTheme.RED)
			return
