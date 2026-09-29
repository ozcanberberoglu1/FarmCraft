class_name DealerScreen
extends ModalScreen
## Yeşilova Oto: the vehicle for sale with its specs and price.

const PORTRAIT_DIR := "res://art/icons/vehicles/"

var _vehicle: Vehicle
var _content: HBoxContainer


func _ready() -> void:
	ui_name = &"dealer"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_DEALER"), "key", tr("UI_DEALER_HINT"))
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 28)
	window.body.add_child(_content)
	Events.money_changed.connect(func(_m: int, _d: int) -> void: if visible: _fill())


func open(v: Vehicle) -> void:
	_vehicle = v
	if v == null:
		return
	_fill()
	show_screen()


func _fill() -> void:
	for c in _content.get_children():
		c.queue_free()
	var v := _vehicle
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.05), 16))
	_content.add_child(stage)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(600, 380)
	var path := PORTRAIT_DIR + String(v.kind) + ".png"
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	stage.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(420, 0)
	_content.add_child(col)
	col.add_child(UiTheme.make_label(UiTheme.caps(v.display_name()), UiTheme.heading(40, UiTheme.TEXT, 700, 1)))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	col.add_child(chips)
	chips.add_child(UiTheme.chip(tr("VEHICLE_USED"), UiTheme.TEXT_MUTED))
	chips.add_child(UiTheme.chip(tr("VEHICLE_RWD"), UiTheme.TEXT_MUTED))
	if v.owned:
		chips.add_child(UiTheme.chip(tr("VEHICLE_OWNED"), UiTheme.GREEN, "check"))
	col.add_child(UiTheme.paragraph(tr(v.info.get("desc_key", "")), 18, UiTheme.TEXT_MUTED, 420))
	col.add_child(UiTheme.section(tr("VEHICLE_SPECS")))
	for spec: Array in [["truck", tr("VEHICLE_TOP_SPEED"), "%d km/h" % int(v.info.get("max_speed", 100))],
			["fuel", tr("VEHICLE_TANK"), "%d L" % int(v.info.get("fuel_capacity", 40))],
			["box", tr("VEHICLE_BED"), tr("VEHICLE_UNITS") % int(v.info.get("cargo_units", 100))],
			["drop", tr("VEHICLE_CONSUMPTION"), "%.1f L/km" % float(v.info.get("fuel_per_km", 0.5))]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiTheme.icon_rect(UiTheme.glyph(spec[0]), 22, UiTheme.GOLD_SOFT))
		var l := UiTheme.make_label(UiTheme.caps(spec[1]), UiTheme.heading(18, UiTheme.TEXT_MUTED, 700, 2))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UiTheme.make_label(spec[2], UiTheme.heading(22, UiTheme.TEXT, 700, 0)))
		col.add_child(row)
	col.add_child(UiTheme.expand())
	col.add_child(UiTheme.separator())
	var price_row := HBoxContainer.new()
	col.add_child(price_row)
	var pl := UiTheme.make_label(UiTheme.caps(tr("VEHICLE_PRICE")), UiTheme.heading(18, UiTheme.TEXT_MUTED, 700, 2))
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(pl)
	price_row.add_child(UiTheme.price(v.price, 36))
	if v.owned:
		col.add_child(UiTheme.paragraph(tr("VEHICLE_OWNED_HINT"), 17, UiTheme.GREEN, 420))
		return
	var missing := v.price - Economy.money
	if missing > 0:
		col.add_child(UiTheme.paragraph(tr("MSG_NEED_GOLD") % UiTheme.money(missing), 16, UiTheme.RED, 420))
	var buy := UiTheme.button(tr("VEHICLE_BUY"), "primary", Vector2(420, 60), "key", 24)
	buy.disabled = missing > 0
	buy.pressed.connect(_buy)
	col.add_child(buy)


func _buy() -> void:
	var v := _vehicle
	if v == null or v.owned or not Economy.spend(v.price, "REPORT_VEHICLE"):
		return
	v.owned = true
	v.fuel = maxf(v.fuel, float(v.info.get("fuel_capacity", 40.0)) * 0.5)
	v.changed.emit()
	Game.notify(tr("MSG_VEHICLE_BOUGHT") % v.display_name(), UiTheme.GREEN)
	hide_screen()
