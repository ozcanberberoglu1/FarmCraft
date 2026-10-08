class_name CatalogPage
extends PanelContainer
## The Yeşilova Market catalogue, the mailbox screen's second page (LetterScreen, once
## Hasan's catalogue has come: Mail.catalog): a printed sheet listing the market's everyday
## goods with their prices, a − and + beside each, and the order slip next to it: the lines
## written so far, the road fee, the total, when it comes, and "Place the order" (paid on
## the spot). While an order is open the slip shows that one instead, with "Cancel" (the
## money back) until midnight; the list waits until it has come.
## Over the list a search field in ink (SearchBox: by the goods' name): lines that don't
## answer it are folded away (what is written on the slip stays written).

## The letters' paper and inks (LetterScreen).
const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.2, 0.15, 0.11)
const INK_SOFT := Color(0.36, 0.29, 0.22)
const INK_RED := Color(0.62, 0.16, 0.1)
const LIST_SIZE := Vector2(600, 452)
const SLIP_WIDTH := 330.0

## The order being written: {StringName id: count}.
var draft := {}

var _catalog: Catalog
var _money: Label
var _rows := {}
var _slip: VBoxContainer
var _list_note: Label
var _search: SearchBox
var _scroll: ScrollContainer
## The line under the list's last row when the search finds nothing.
var _none: Label


func _ready() -> void:
	_catalog = Mail.catalog
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(6)
	sb.border_color = PAPER.darkened(0.18)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 34
	sb.content_margin_bottom = 30
	add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph("book"), 30, INK_SOFT))
	var title := UiTheme.make_label(UiTheme.caps(tr("CATALOG_TITLE")), UiTheme.heading(30, INK, 700, 2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_money = UiTheme.make_label("", UiTheme.heading(24, INK, 700, 1))
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_money)
	col.add_child(UiTheme.make_label(tr("CATALOG_SUBTITLE") % [UiTheme.money(Catalog.FEE), Catalog.post_time()], UiTheme.text(17, INK_SOFT, 500)))
	var rule := ColorRect.new()
	rule.color = Color(INK_SOFT, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	col.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)
	_search = SearchBox.new(LIST_SIZE.x, true)
	_search.changed.connect(func(_q: String) -> void:
		_apply_search()
		_scroll.scroll_vertical = 0)
	left.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_scroll = scroll
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id: StringName in _catalog.goods():
		var row := _make_row(id)
		_rows[id]["row"] = row
		list.add_child(row)
	_none = UiTheme.make_label("", UiTheme.text(18, INK_SOFT, 500))
	_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_none.custom_minimum_size = Vector2(LIST_SIZE.x - 20.0, 0)
	_none.visible = false
	list.add_child(_none)
	_list_note = UiTheme.make_label("", UiTheme.text(16, INK_SOFT, 500))
	left.add_child(_list_note)
	var card := PanelContainer.new()
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = PAPER.darkened(0.08)
	sbs.set_corner_radius_all(4)
	sbs.border_color = Color(INK_SOFT, 0.3)
	sbs.set_border_width_all(1)
	sbs.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sbs)
	card.custom_minimum_size = Vector2(SLIP_WIDTH + 36, 0)
	body.add_child(card)
	_slip = VBoxContainer.new()
	_slip.add_theme_constant_override("separation", 7)
	card.add_child(_slip)
	_catalog.changed.connect(refresh)
	Events.money_changed.connect(_on_money)
	refresh()


func _exit_tree() -> void:
	if _catalog != null and _catalog.changed.is_connected(refresh):
		_catalog.changed.disconnect(refresh)
	if Events.money_changed.is_connected(_on_money):
		Events.money_changed.disconnect(_on_money)


func _on_money(_m: int, _d: int) -> void:
	refresh()


## The catalogue's goods the search field lets through, in the list's order.
func shown_goods() -> Array[StringName]:
	var query := _search.query()
	var out: Array[StringName] = []
	for id: StringName in _rows:
		if SearchBox.matches(ItemDB.get_item(id).display_name(), query):
			out.append(id)
	return out


## Shows the lines the search field lets through (and a word when there are none).
func _apply_search() -> void:
	var found := shown_goods()
	for id: StringName in _rows:
		(_rows[id]["row"] as Control).visible = id in found
	_none.visible = found.is_empty() and not _rows.is_empty()
	if _none.visible:
		_none.text = _search.none_line()


## One line of the catalogue: the picture, the name, the price, − count +.
func _make_row(id: StringName) -> Control:
	var item := ItemDB.get_item(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 44)
	row.add_child(UiTheme.icon_rect(item.icon, 40))
	var name_label := UiTheme.make_label(item.display_name(), UiTheme.text(19, INK, 600))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.clip_text = true
	row.add_child(name_label)
	var price := UiTheme.make_label(UiTheme.money(Catalog.price(id)), UiTheme.heading(21, INK, 700, 0))
	price.custom_minimum_size = Vector2(64, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	var minus := _ink_button("−", Vector2(40, 36))
	minus.pressed.connect(add.bind(id, -1))
	row.add_child(minus)
	var count := UiTheme.make_label("0", UiTheme.heading(22, INK, 700, 0))
	count.custom_minimum_size = Vector2(40, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	var plus := _ink_button("+", Vector2(40, 36))
	plus.pressed.connect(add.bind(id, 1))
	row.add_child(plus)
	var more := _ink_button("+10", Vector2(54, 36))
	more.pressed.connect(add.bind(id, 10))
	row.add_child(more)
	_rows[id] = {"count": count, "minus": minus, "plus": plus, "more": more}
	return row


## A small button in ink on the paper.
func _ink_button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UiTheme.display(700, 1))
	b.add_theme_font_size_override("font_size", 20)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK_SOFT, 0.35))
	var normal := StyleBoxFlat.new()
	normal.bg_color = PAPER.darkened(0.1)
	normal.set_corner_radius_all(5)
	normal.border_color = Color(INK_SOFT, 0.45)
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PAPER.darkened(0.2)
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = Color(PAPER.darkened(0.06), 0.5)
	off.border_color = Color(INK_SOFT, 0.15)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: Audio.ui("click", -9.0))
	return b


## `step` more (or fewer) of `id` on the slip.
func add(id: StringName, step: int) -> void:
	set_count(id, int(draft.get(id, 0)) + step)


## `count` of `id` on the slip (within what one order takes; a new kind only while the
## crate has room for one).
func set_count(id: StringName, count: int) -> void:
	if not _catalog.order.is_empty() or not _rows.has(id):
		return
	var n := clampi(count, 0, Catalog.max_count(id))
	if n > 0 and not draft.has(id) and draft.size() >= Catalog.MAX_KINDS:
		return
	if n > 0:
		draft[id] = n
	else:
		draft.erase(id)
	refresh()


## Writes the order on the slip and pays for it. False: it can't be (Catalog.order_error).
func confirm() -> bool:
	if not _catalog.place_order(draft):
		return false
	draft = {}
	refresh()
	return true


## Calls the open order off (the money back). False once it is on its way.
func cancel() -> bool:
	return _catalog.cancel_order()


## The rows' counts and buttons, the money and the slip, as things stand.
func refresh() -> void:
	if not is_inside_tree():
		return
	_money.text = tr("CATALOG_MONEY") % UiTheme.money(Economy.money)
	var open := not _catalog.order.is_empty()
	var full := draft.size() >= Catalog.MAX_KINDS
	for id: StringName in _rows:
		var r: Dictionary = _rows[id]
		var n := int(draft.get(id, 0))
		(r["count"] as Label).text = str(n)
		(r["count"] as Label).modulate.a = 1.0 if n > 0 else 0.4
		(r["minus"] as Button).disabled = open or n <= 0
		var room := not open and n < Catalog.max_count(id) and (n > 0 or not full)
		(r["plus"] as Button).disabled = not room
		(r["more"] as Button).disabled = not room
	_list_note.text = tr("CATALOG_ONE_ORDER") if open else tr("CATALOG_LIMIT") % Catalog.MAX_KINDS
	# (the field empties itself when the page is turned away from)
	_apply_search()
	_fill_slip(open)


## "3× Feed ........ $3": one line of the slip.
func _slip_line(text: String, amount: int, strong := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UiTheme.make_label(text, UiTheme.text(18 if not strong else 22, INK, 700 if strong else 500))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	row.add_child(UiTheme.make_label(UiTheme.money(amount), UiTheme.heading(20 if not strong else 28, INK, 700, 0)))
	return row


func _slip_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(INK_SOFT, 0.35)
	rule.custom_minimum_size = Vector2(0, 1)
	return rule


func _slip_note(text: String, color := INK_SOFT) -> Label:
	var l := UiTheme.make_label(text, UiTheme.text(16, color, 500))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(SLIP_WIDTH, 0)
	return l


## The slip: the open order (and its way out), else the one being written.
func _fill_slip(open: bool) -> void:
	for c in _slip.get_children():
		c.queue_free()
	var items: Dictionary = _catalog.order.get("items", {}) if open else draft
	_slip.add_child(UiTheme.make_label(UiTheme.caps(tr("CATALOG_OPEN_ORDER") if open else tr("CATALOG_SLIP")), UiTheme.heading(22, INK, 700, 2)))
	_slip.add_child(_slip_rule())
	if items.is_empty():
		_slip.add_child(_slip_note(tr("CATALOG_SLIP_EMPTY")))
	for id: Variant in items:
		var item := ItemDB.get_item(StringName(id))
		if item != null:
			_slip.add_child(_slip_line("%d× %s" % [int(items[id]), item.display_name()], Catalog.price(StringName(id)) * int(items[id])))
	_slip.add_child(_slip_line(tr("CATALOG_FEE"), Catalog.FEE))
	_slip.add_child(_slip_rule())
	var cost: int = int(_catalog.order.get("paid", 0)) if open else Catalog.total(items)
	_slip.add_child(_slip_line(tr("SHOP_TOTAL_LABEL"), cost, true))
	var spacer := UiTheme.expand()
	spacer.custom_minimum_size = Vector2(0, 8)
	_slip.add_child(spacer)
	var due := UiTheme.make_label(tr("CATALOG_DUE_%d" % mini(_catalog.mornings_left(), 2)) % Catalog.post_time(), UiTheme.text(18, INK, 700))
	due.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	due.custom_minimum_size = Vector2(SLIP_WIDTH, 0)
	_slip.add_child(due)
	if open:
		var can := _catalog.can_cancel()
		_slip.add_child(_slip_note(tr("CATALOG_CUTOFF") if can else tr("CATALOG_ON_THE_WAY")))
		var back := UiTheme.button(tr("CATALOG_CANCEL") % UiTheme.money(cost), "danger", Vector2(SLIP_WIDTH, 50), "close", 19)
		back.disabled = not can
		back.pressed.connect(cancel)
		_slip.add_child(back)
		return
	var why := _catalog.order_error(items)
	if why == "money":
		_slip.add_child(_slip_note(tr("MSG_NOT_ENOUGH_MONEY"), INK_RED))
	elif GameClock.minute >= 1440.0:
		_slip.add_child(_slip_note(tr("CATALOG_LATE")))
	else:
		_slip.add_child(_slip_note(tr("CATALOG_CUTOFF")))
	var ok := UiTheme.button(tr("CATALOG_ORDER"), "primary", Vector2(SLIP_WIDTH, 54), "check", 22)
	ok.disabled = why != ""
	ok.pressed.connect(confirm)
	_slip.add_child(ok)
