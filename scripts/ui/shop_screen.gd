class_name ShopScreen
extends ModalScreen
## Merchant window with BUY and SELL tabs. BUY lists the shop's stock at fixed
## prices; SELL lists everything sellable in the player's inventory at today's
## market price (with a rising/falling trend). At the Yeşilova Market the SELL tab
## also lists the bed of the player's pickup parked outside, and sells its whole load
## in one go; the window opens on SELL when that bed holds goods. Optional tool repair.
## Over the tiles a search field (SearchBox: F or a click, then the goods' name): the grid
## shows what answers it on either tab; the tile picked stays picked while it is still
## there, else the first one found is; with nothing found a line says so.

const TILE := Vector2(132, 164)
const COLS := 5
## Dollars per point of wear mended (a worn-out hoe costs about a quarter of a new one).
const REPAIR_PER_POINT := 0.25

var _tabs: TabStrip
var _money: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _search: SearchBox
var _detail: VBoxContainer
var _extra: VBoxContainer
var _tab := "buy"
var _shop := {}
## Selected entry: {id, quality}
var _sel := {}
var _qty := 1
## The grid's tiles by entry key, so a click only restyles two of them.
var _tiles := {}


class ShopTile extends Button:
	var entry := {}


func _ready() -> void:
	ui_name = &"shop"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_SHOP"), "cart")
	_tabs = TabStrip.new()
	_tabs.selected.connect(_set_tab)
	window.header_right.add_child(_tabs)
	_money = window.add_money_pill()
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.body.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	_search = SearchBox.new(COLS * (TILE.x + 10) - 10)
	_search.changed.connect(_on_search)
	left.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COLS * (TILE.x + 10), 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_scroll = scroll
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	_extra = VBoxContainer.new()
	left.add_child(_extra)
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(400, 0)
	body.add_child(card)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 12)
	card.add_child(_detail)
	Events.money_changed.connect(func(m: int, _d: int) -> void: _money.text = UiTheme.money(m))
	PlayerState.inventory.changed.connect(func() -> void: if visible and _tab == "sell": _fill_grid())


## shop = {title: key, stock: [item ids], buys: bool, repair: bool}
func open(shop: Dictionary) -> void:
	_shop = shop
	window.set_heading(tr(shop.get("title", "UI_SHOP")), "cart", tr("UI_SHOP_HINT"))
	_money.text = UiTheme.money(Economy.money)
	var tabs := [["buy", tr("SHOP_TAB_BUY"), "cart"]]
	if _shop.get("buys", true):
		tabs.append(["sell", tr("SHOP_TAB_SELL"), "tag"])
	_tabs.setup(tabs)
	# A loaded pickup parked outside: the farmer came to sell.
	_set_tab("sell" if _shop.get("buys", true) and _load_value(_cargo()) > 0 else "buy")
	show_screen()


func close_screen() -> void:
	hide_screen()


## The window is the Yeşilova Market's (the one shop that buys a pickup's load): the
## story's grocer stands behind it (Quests' first seeds).
func is_town_market() -> bool:
	return bool(_shop.get("cargo", false))


func _set_tab(tab: String) -> void:
	_tab = tab
	if _tabs.current != tab:
		_tabs.select(tab)
		return
	_sel = {}
	_qty = 1
	_fill_grid()


## The bed of the player's vehicle parked at this shop, if the shop buys from it.
func _cargo() -> Stockpile:
	if not _shop.get("cargo", false):
		return null
	var town := get_tree().get_first_node_in_group(&"town") as Town
	var v := town.vehicle_at_market() if town else null
	return v.cargo if v else null


func _entries() -> Array:
	var out := []
	if _tab == "buy":
		for id: StringName in _shop.get("stock", []):
			out.append({"id": id, "quality": 0})
	else:
		var seen := {}
		for s in PlayerState.inventory.slots:
			if s == null or s.item.sell_price <= 0:
				continue
			var key := "%s_%d" % [s.item.id, s.quality]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"id": s.item.id, "quality": s.quality})
		var cargo := _cargo()
		if cargo:
			for e: Dictionary in cargo.entries():
				var key := "%s_%d" % [e["id"], e["quality"]]
				if seen.has(key) or ItemDB.get_item(e["id"]).sell_price <= 0:
					continue
				seen[key] = true
				out.append({"id": e["id"], "quality": e["quality"]})
	return out


func _price(entry: Dictionary) -> int:
	if _tab == "buy":
		return Economy.buy_price(entry["id"])
	return Economy.sell_price(entry["id"], entry["quality"])


func _owned(entry: Dictionary) -> int:
	var n := 0
	for s in PlayerState.inventory.slots:
		if s and s.item.id == entry["id"] and (_tab == "buy" or s.quality == entry["quality"]):
			n += s.count
	if _tab == "sell":
		n += _in_cargo(entry)
	return n


func _in_cargo(entry: Dictionary) -> int:
	var cargo := _cargo()
	return cargo.count(entry["id"], entry["quality"]) if cargo else 0


## The tab's entries the search field lets through (all of them while it is empty).
func shown_entries() -> Array:
	var query := _search.query()
	if query == "":
		return _entries()
	return _entries().filter(func(e: Dictionary) -> bool:
		return SearchBox.matches(ItemDB.get_item(e["id"]).display_name(), query))


## The words in the search field changed: the grid from its top, on a tile that is in it.
func _on_search(_query: String) -> void:
	_fill_grid()
	_scroll.scroll_vertical = 0
	# (the whole list again: down to the tile picked, once the grid is laid out)
	await get_tree().process_frame
	var tile: ShopTile = _tiles.get(_entry_key(_sel)) if not _sel.is_empty() else null
	if is_instance_valid(tile) and visible:
		_scroll.ensure_control_visible(tile)


func _fill_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_tiles.clear()
	var entries := shown_entries()
	var searching := _search.query() != ""
	# A search that leaves the picked tile out picks the first one it found.
	if searching and not _sel.is_empty() and not entries.any(_is_selected):
		_sel = {}
		_qty = 1
	if _sel.is_empty() and not entries.is_empty():
		_sel = entries[0]
	for e in entries:
		var t := _make_tile(e)
		_tiles[_entry_key(e)] = t
		_grid.add_child(t)
	if entries.is_empty():
		var nothing := searching and not _entries().is_empty()
		_grid.add_child(UiTheme.paragraph(_search.none_line() if nothing else tr("SHOP_NOTHING_TO_SELL"), 20, UiTheme.TEXT_DIM, 600))
		_sel = {}
	_fill_extra()
	_show_detail()


func _is_selected(entry: Dictionary) -> bool:
	return not _sel.is_empty() and _sel["id"] == entry["id"] and _sel["quality"] == entry["quality"]


func _entry_key(entry: Dictionary) -> String:
	return "%s|%d" % [entry["id"], entry["quality"]]


## The tile's card: gold-rimmed when selected.
func _style_tile(t: ShopTile, sel: bool) -> void:
	var normal: StyleBoxFlat
	if sel:
		normal = UiTheme.glow_box(UiTheme.CARD_ACTIVE, 12, Color(UiTheme.GOLD, 0.9), Color(UiTheme.GOLD, 0.22), 10)
	else:
		normal = UiTheme.box(Color(0, 0, 0, 0.25), 12, 1, Color(1, 1, 1, 0.08))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = UiTheme.CARD_ACTIVE if sel else UiTheme.CARD_HOVER
	hover.border_color = Color(UiTheme.GOLD, 0.9) if sel else Color(1, 1, 1, 0.3)
	t.add_theme_stylebox_override("normal", normal)
	t.add_theme_stylebox_override("hover", hover)
	t.add_theme_stylebox_override("pressed", hover)
	t.add_theme_stylebox_override("hover_pressed", hover)


func _make_tile(entry: Dictionary) -> ShopTile:
	var t := ShopTile.new()
	t.entry = entry
	t.custom_minimum_size = TILE
	t.focus_mode = Control.FOCUS_NONE
	t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_tile(t, _is_selected(entry))
	t.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var item := ItemDB.get_item(entry["id"])
	var pic := UiTheme.icon_rect(item.icon, 78)
	pic.position = Vector2((TILE.x - 78) * 0.5, 10)
	pic.size = Vector2(78, 78)
	t.add_child(pic)
	var locked := _locked(entry)
	if locked:
		pic.modulate = Color(1, 1, 1, 0.3)
	var name_label := UiTheme.make_label(UiTheme.caps(item.display_name()), UiTheme.heading(16, UiTheme.TEXT, 700, 1))
	name_label.position = Vector2(6, 88)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.fit_label(name_label, TILE.x - 12, 13)
	name_label.size.y = 40
	t.add_child(name_label)
	if locked:
		name_label.modulate = Color(1, 1, 1, 0.45)
		var lock := UiTheme.chip(tr("UI_LEVEL_SHORT") % UnlockTable.item_level(entry["id"]), UiTheme.GOLD_SOFT, "lock", 15)
		lock.position = Vector2(8, 8)
		t.add_child(lock)
	var price_row := UiTheme.price(_price(entry), 20)
	price_row.position = Vector2(12, TILE.y - 36)
	t.add_child(price_row)
	if _tab == "sell" and Carnival.is_on():
		price_row.add_theme_constant_override("separation", 5)
		price_row.add_child(CarnivalBanner.badge(12, false))
	if _tab == "sell":
		var trend := Economy.price_trend(entry["id"])
		if trend != 0:
			var arrow := UiTheme.icon_rect(UiTheme.glyph("arrow_up" if trend > 0 else "arrow_down"), 18,
					UiTheme.GREEN if trend > 0 else UiTheme.RED)
			arrow.position = Vector2(TILE.x - 30, TILE.y - 33)
			arrow.size = Vector2(18, 18)
			t.add_child(arrow)
		if entry["quality"] > 0:
			var star := UiTheme.icon_rect(UiTheme.glyph("star"), 18, Color("dfe7f2") if entry["quality"] == 1 else UiTheme.GOLD)
			star.position = Vector2(TILE.x - 28, 10)
			star.size = Vector2(18, 18)
			t.add_child(star)
		var count := UiTheme.make_label("×%d" % _owned(entry), UiTheme.heading(16, UiTheme.TEXT_MUTED, 700, 0))
		count.position = Vector2(10, 8)
		t.add_child(count)
		if _in_cargo(entry) > 0:
			var truck := UiTheme.icon_rect(UiTheme.glyph("truck"), 18, UiTheme.GOLD_SOFT)
			truck.position = Vector2(10, 30)
			truck.size = Vector2(18, 18)
			t.add_child(truck)
	t.pressed.connect(func() -> void:
		var old: ShopTile = null
		if not _sel.is_empty():
			old = _tiles.get(_entry_key(_sel))
		_sel = entry
		_qty = 1
		if old and old != t:
			_style_tile(old, false)
		_style_tile(t, true)
		_show_detail())
	return t


func _fill_extra() -> void:
	for c in _extra.get_children():
		c.queue_free()
	if _tab == "sell":
		# A carnival night: the town pays double until it ends.
		if Carnival.is_on():
			_extra.add_child(CarnivalBanner.strip(tr("SHOP_CARNIVAL_STRIP") % Carnival.letter_args()["end"], COLS * (TILE.x + 10) - 10))
		var worth := _load_value(_cargo())
		if worth > 0:
			var sell_all := UiTheme.button(tr("SHOP_SELL_LOAD") % UiTheme.money(worth), "success",
					Vector2(COLS * (TILE.x + 10) - 10, 48), "truck", 19)
			sell_all.pressed.connect(_sell_load)
			_extra.add_child(sell_all)
		return
	if not _shop.get("repair", false):
		return
	var cost := _repair_cost()
	var b := UiTheme.button(tr("SHOP_REPAIR") % UiTheme.money(cost) if cost > 0 else tr("SHOP_REPAIR_NONE"), "secondary",
			Vector2(COLS * (TILE.x + 10) - 10, 48), "wrench", 19)
	b.disabled = cost <= 0 or Economy.money < cost
	b.pressed.connect(_repair)
	_extra.add_child(b)


## What the sellable goods in the parked pickup's bed fetch right now, exactly as
## _sell_load pays (lot by lot, each unit lowering its item's price).
func _load_value(cargo: Stockpile) -> int:
	if cargo == null:
		return 0
	var worth := 0
	var counted := {}
	for e: Dictionary in cargo.entries():
		var id: StringName = e["id"]
		var item := ItemDB.get_item(id)
		if item == null or item.sell_price <= 0:
			continue
		worth += Economy.quote(id, int(e["count"]), int(e["quality"]), 1.0, int(counted.get(id, 0)))
		counted[id] = int(counted.get(id, 0)) + int(e["count"])
	return worth


## Sells everything sellable in the parked pickup's bed at the counter.
func _sell_load() -> void:
	var cargo := _cargo()
	if cargo == null:
		return
	var income := 0
	var units := 0
	for e: Dictionary in cargo.entries():
		var id: StringName = e["id"]
		var item := ItemDB.get_item(id)
		if item == null or item.sell_price <= 0:
			continue
		var n := cargo.take(id, int(e["count"]), int(e["quality"]))
		if n > 0:
			income += Economy.sell(id, n, int(e["quality"]))
			units += n
	if units > 0:
		Game.notify(tr("MSG_LOAD_SOLD") % [units, UiTheme.money(income)], UiTheme.GOLD_SOFT)
	_sel = {}
	_qty = 1
	_fill_grid()


## What mending every tool in the bag costs: REPAIR_PER_POINT for each point of wear.
func _repair_cost() -> int:
	var worn := 0
	for s in PlayerState.inventory.slots:
		if s and s.item.has_durability():
			worn += s.max_durability() - s.durability
	return ceili(worn * REPAIR_PER_POINT)


func _repair() -> void:
	var cost := _repair_cost()
	if cost <= 0 or not Economy.spend(cost, "REPORT_REPAIR"):
		return
	for s in PlayerState.inventory.slots:
		if s and s.item.has_durability():
			s.durability = s.max_durability()
	PlayerState.inventory.changed.emit()
	Game.notify(tr("MSG_TOOLS_REPAIRED"), UiTheme.GREEN)
	_fill_grid()


func _max_qty() -> int:
	if _sel.is_empty():
		return 0
	var price := _price(_sel)
	if _tab == "buy":
		if _locked(_sel):
			return 0
		var item := ItemDB.get_item(_sel["id"])
		var by_money := int(Economy.money / float(maxi(price, 1)))
		var room := 0
		for s in PlayerState.inventory.slots:
			if s == null:
				room += item.max_stack
			elif s.item == item and s.quality == 0:
				room += s.space_left()
		return mini(by_money, mini(room, 99))
	return _owned(_sel)


## Seeds of crops the farm level hasn't opened yet: on the shelf, not for sale.
func _locked(entry: Dictionary) -> bool:
	return _tab == "buy" and UnlockTable.item_level(entry["id"]) > Progress.level


func _info_row(label: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.make_label(UiTheme.caps(label), UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 2))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(value)
	return row


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _sel.is_empty():
		# (a search that finds nothing: the card keeps its width, the window doesn't jump)
		_detail.custom_minimum_size.x = _detail.size.x
		return
	_detail.custom_minimum_size.x = 0.0
	var item := ItemDB.get_item(_sel["id"])
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.04), 12))
	_detail.add_child(stage)
	var pic := UiTheme.icon_rect(item.icon, 150)
	pic.custom_minimum_size = Vector2(356, 170)
	stage.add_child(pic)
	var name_label := UiTheme.make_label(UiTheme.caps(item.display_name()), UiTheme.heading(32, UiTheme.TEXT, 700, 1))
	_detail.add_child(name_label)
	if item.description() != "":
		_detail.add_child(UiTheme.paragraph(item.description(), 17, UiTheme.TEXT_MUTED, 356))
	if _locked(_sel):
		_detail.add_child(UiTheme.icon_row(UiTheme.glyph("lock"), tr("UI_NEEDS_LEVEL") % [UnlockTable.item_level(_sel["id"]), Progress.level],
				UiTheme.RED, 18, 20))
	var price := _price(_sel)
	_detail.add_child(UiTheme.separator())
	var unit := UiTheme.price(price, 22)
	if _tab == "sell" and Carnival.is_on():
		unit.add_theme_constant_override("separation", 8)
		unit.add_child(CarnivalBanner.badge(14))
	_detail.add_child(_info_row(tr("SHOP_UNIT"), unit))
	var in_bed: int = _in_cargo(_sel) if _tab == "sell" else 0
	_detail.add_child(_info_row(tr("SHOP_IN_BAG"), UiTheme.make_label(str(_owned(_sel) - in_bed), UiTheme.heading(22, UiTheme.TEXT, 700, 0))))
	if in_bed > 0:
		_detail.add_child(_info_row(tr("SHOP_IN_BED"), UiTheme.make_label(str(in_bed), UiTheme.heading(22, UiTheme.TEXT, 700, 0))))
	if _tab == "sell":
		var trend := Economy.price_trend(_sel["id"])
		if trend != 0:
			var chip := UiTheme.chip(tr("SHOP_TREND_UP") if trend > 0 else tr("SHOP_TREND_DOWN"),
					UiTheme.GREEN if trend > 0 else UiTheme.RED, "arrow_up" if trend > 0 else "arrow_down", 15)
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_detail.add_child(chip)
	var max_q := _max_qty()
	_qty = clampi(_qty, mini(1, max_q), max_q)
	_detail.add_child(UiTheme.section(tr("SHOP_QUANTITY")))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_child(qrow)
	for step in [-10, -1]:
		var b := UiTheme.button(str(step), "secondary", Vector2(54, 44), "", 18)
		b.pressed.connect(func() -> void:
			_qty = clampi(_qty + step, mini(1, max_q), max_q)
			_show_detail())
		qrow.add_child(b)
	var qbox := PanelContainer.new()
	qbox.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.35), 10, 1, Color(UiTheme.GOLD, 0.4)))
	qbox.custom_minimum_size = Vector2(76, 44)
	var ql := UiTheme.make_label(str(_qty), UiTheme.heading(28, UiTheme.TEXT, 700, 0))
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ql.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qbox.add_child(ql)
	qrow.add_child(qbox)
	for step in [1, 10]:
		var b := UiTheme.button("+%d" % step, "secondary", Vector2(54, 44), "", 18)
		b.pressed.connect(func() -> void:
			_qty = clampi(_qty + step, mini(1, max_q), max_q)
			_show_detail())
		qrow.add_child(b)
	var bmax := UiTheme.button(tr("SHOP_MAX"), "ghost", Vector2(64, 44), "", 18)
	bmax.pressed.connect(func() -> void:
		_qty = max_q
		_show_detail())
	qrow.add_child(bmax)
	_detail.add_child(UiTheme.expand())
	# Selling many units lowers the price as they go: show what the sale really pays.
	var total: int = price * _qty if _tab == "buy" else Economy.quote(_sel["id"], _qty, int(_sel["quality"]))
	var total_row := _info_row(tr("SHOP_TOTAL_LABEL"), UiTheme.price(total, 32))
	_detail.add_child(total_row)
	var action := UiTheme.button(tr("SHOP_BUY") if _tab == "buy" else tr("SHOP_SELL"),
			"primary" if _tab == "buy" else "success", Vector2(356, 58), "cart" if _tab == "buy" else "tag", 24)
	action.disabled = _qty <= 0
	action.pressed.connect(_confirm)
	_detail.add_child(action)


func _confirm() -> void:
	if _sel.is_empty() or _qty <= 0:
		return
	var id: StringName = _sel["id"]
	if _tab == "buy":
		var cost := Economy.buy_price(id) * _qty
		if not Economy.spend(cost, "REPORT_PURCHASES"):
			return
		var left := PlayerState.inventory.add_item(id, _qty)
		if left > 0:
			Economy.add_money(Economy.buy_price(id) * left, "REPORT_PURCHASES")
		Game.notify("+%d× %s" % [_qty - left, ItemDB.get_item(id).display_name()])
		if _qty - left > 0:
			Events.item_bought.emit(id, _qty - left)
	else:
		var quality: int = _sel["quality"]
		var removed := 0
		for i in PlayerState.inventory.size():
			var s := PlayerState.inventory.get_stack(i)
			if s == null or s.item.id != id or s.quality != quality:
				continue
			var take := mini(s.count, _qty - removed)
			PlayerState.inventory.take_from(i, take)
			removed += take
			if removed >= _qty:
				break
		var cargo := _cargo()
		if removed < _qty and cargo:
			removed += cargo.take(id, _qty - removed, quality)
		var income := Economy.sell(id, removed, quality)
		Game.notify("+" + UiTheme.money(income), UiTheme.GOLD_SOFT)
	_qty = 1
	_fill_grid()
