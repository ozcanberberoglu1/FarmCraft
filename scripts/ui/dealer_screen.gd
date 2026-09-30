class_name DealerScreen
extends ModalScreen
## Yeşilova Oto Galeri: everything the dealership sells (Town.dealer_stock) in a list on
## the left, each with its portrait, price and where it stands (the showroom or the
## lot); the chosen one on the right with its specs, price and the purchase. Opened on
## a vehicle (E at it) that one is shown; from the desk the first one still for sale.
## Bought in the showroom, it is brought round to the service bay (Town.deliver).

const PORTRAIT_DIR := "res://art/icons/vehicles/"

var _vehicle: Vehicle
var _content: HBoxContainer
var _money: Label
## The big portrait of the chosen vehicle (it hops when one is bought).
var _portrait: TextureRect


func _ready() -> void:
	ui_name = &"dealer"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_DEALER"), "key", tr("UI_DEALER_HINT"))
	_money = window.add_money_pill()
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 24)
	window.body.add_child(_content)
	Events.money_changed.connect(func(m: int, _d: int) -> void:
		_money.text = UiTheme.money(m)
		if visible:
			_fill())


static func portrait(kind: StringName) -> Texture2D:
	var path := PORTRAIT_DIR + String(kind) + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## Opens on `v` (null: the first vehicle still for sale).
func open(v: Vehicle) -> void:
	_vehicle = v
	if v == null:
		for s in _stock():
			if not s.owned:
				v = s
				break
		if v == null and not _stock().is_empty():
			v = _stock()[0]
	_vehicle = v
	if v == null:
		return
	_money.text = UiTheme.money(Economy.money)
	_fill()
	show_screen()


func close_screen() -> void:
	hide_screen()


## The dealership's vehicles (with the one opened on first when it is not one of them).
func _stock() -> Array[Vehicle]:
	var town := get_tree().get_first_node_in_group(&"town") as Town
	var out: Array[Vehicle] = []
	if town:
		for v in town.dealer_stock:
			if is_instance_valid(v):
				out.append(v)
	if _vehicle and is_instance_valid(_vehicle) and _vehicle not in out:
		out.push_front(_vehicle)
	return out


func _fill() -> void:
	for c in _content.get_children():
		c.queue_free()
	_portrait = null
	if _vehicle == null or not is_instance_valid(_vehicle):
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for v in _stock():
		list.add_child(_card(v))
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(800, 640)
	_content.add_child(card)
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 24)
	card.add_child(detail)
	_fill_detail(detail, _vehicle)


## A vehicle in the list: portrait, name, price and a tag (showroom or lot), or "yours".
func _card(v: Vehicle) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(412, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var active := v == _vehicle
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
	row.offset_left = 10
	row.offset_right = -14
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(118, 76)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.texture = portrait(v.kind)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_label := UiTheme.make_label(v.display_name(), UiTheme.text(18, UiTheme.TEXT, 700))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(150, 0)
	col.add_child(name_label)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	if v.owned:
		line.add_child(UiTheme.make_label(tr("VEHICLE_OWNED"), UiTheme.text(17, UiTheme.GREEN, 700)))
	else:
		line.add_child(UiTheme.price(v.price, 20))
		line.add_child(UiTheme.expand())
		var where := UiTheme.chip(tr("DEALER_IN_SHOWROOM") if Town.showroom_has(v.global_position) else tr("DEALER_ON_LOT"),
				UiTheme.TEXT_MUTED, "", 13)
		where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(where)
	_ignore_mouse(row)
	b.pressed.connect(func() -> void:
		if _vehicle != v:
			_vehicle = v
			Audio.ui("click", -8.0)
			_fill())
	return b


## Lets clicks through to the card's button.
static func _ignore_mouse(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in c.get_children():
		if child is Control:
			_ignore_mouse(child)


func _fill_detail(box: HBoxContainer, v: Vehicle) -> void:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.custom_minimum_size = Vector2(360, 0)
	box.add_child(left)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.05), 12))
	left.add_child(stage)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(360, 228)
	_portrait.texture = portrait(v.kind)
	stage.add_child(_portrait)
	left.add_child(UiTheme.paragraph(tr(v.info.get("desc_key", "")), 17, UiTheme.TEXT_MUTED, 360))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(col)
	var title := UiTheme.make_label(UiTheme.caps(v.display_name()), UiTheme.heading(30, UiTheme.TEXT, 700, 1))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(340, 0)
	col.add_child(title)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	col.add_child(chips)
	chips.add_child(UiTheme.chip(tr("VEHICLE_USED"), UiTheme.TEXT_MUTED))
	chips.add_child(UiTheme.chip(tr("VEHICLE_4WD") if v.info.get("drive", "rwd") == "4wd" else tr("VEHICLE_RWD"), UiTheme.TEXT_MUTED))
	if v.owned:
		chips.add_child(UiTheme.chip(tr("VEHICLE_OWNED"), UiTheme.GREEN, "check"))
	col.add_child(UiTheme.section(tr("VEHICLE_SPECS")))
	for spec: Array in [["truck", tr("VEHICLE_TOP_SPEED"), "%d km/h" % int(v.info.get("max_speed", 100))],
			["gear", tr("VEHICLE_WEIGHT"), "%s kg" % UiTheme.number(int(v.info.get("mass", 1400)))],
			["fuel", tr("VEHICLE_TANK"), "%d L" % int(v.info.get("fuel_capacity", 40))],
			["box", tr("VEHICLE_BED"), tr("VEHICLE_UNITS") % int(v.info.get("cargo_units", 100))],
			["drop", tr("VEHICLE_CONSUMPTION"), "%.1f L/km" % float(v.info.get("fuel_per_km", 0.5))]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiTheme.icon_rect(UiTheme.glyph(spec[0]), 22, UiTheme.GOLD_SOFT))
		var l := UiTheme.make_label(UiTheme.caps(spec[1]), UiTheme.heading(17, UiTheme.TEXT_MUTED, 700, 2))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UiTheme.make_label(spec[2], UiTheme.heading(21, UiTheme.TEXT, 700, 0)))
		col.add_child(row)
	col.add_child(UiTheme.expand())
	col.add_child(UiTheme.separator())
	var price_row := HBoxContainer.new()
	col.add_child(price_row)
	var pl := UiTheme.make_label(UiTheme.caps(tr("VEHICLE_PRICE")), UiTheme.heading(18, UiTheme.TEXT_MUTED, 700, 2))
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(pl)
	price_row.add_child(UiTheme.price(v.price, 34))
	if v.owned:
		col.add_child(UiTheme.paragraph(tr("VEHICLE_OWNED_ANY"), 17, UiTheme.GREEN, 380))
		return
	var missing := v.price - Economy.money
	if missing > 0:
		col.add_child(UiTheme.paragraph(tr("MSG_NEED_GOLD") % UiTheme.money(missing), 16, UiTheme.RED, 380))
	var buy := UiTheme.button(tr("VEHICLE_BUY_VEHICLE"), "primary", Vector2(380, 60), "key", 23)
	buy.disabled = missing > 0
	buy.pressed.connect(_buy)
	col.add_child(buy)


func _buy() -> void:
	var v := _vehicle
	if v == null or v.owned or not Economy.spend(v.price, "REPORT_VEHICLE"):
		return
	v.owned = true
	v.fuel = maxf(v.fuel, float(v.info.get("fuel_capacity", 40.0)) * 0.5)
	var town := get_tree().get_first_node_in_group(&"town") as Town
	var moved := town != null and town.deliver(v)
	v.changed.emit()
	Audio.ui("confirm")
	Game.notify(tr("MSG_VEHICLE_DELIVERED" if moved else "MSG_VEHICLE_BOUGHT") % v.display_name(), UiTheme.GREEN)
	hide_screen()
