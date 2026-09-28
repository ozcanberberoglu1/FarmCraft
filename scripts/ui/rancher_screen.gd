class_name RancherScreen
extends ModalScreen
## Livestock dealer: buy chickens, sheep, cows and horses (young or grown), sell
## your animals, and open the supplies shop (feed, hay, medicine, tools). Opened from
## the poultry stall in town it is the poultry seller instead (open_poultry): grown
## hens in transport crates, no coop needed yet, loaded into the bed of the pickup
## parked in front (else carried in the bag).

const PORTRAIT_DIR := "res://art/icons/animals/"

var _tabs: TabStrip
var _content: VBoxContainer
var _money: Label
var _tab := "buy"
var _confirm_sell := -1
## Opened at the poultry stall: crated hens only.
var _poultry := false
## Where the stall stands (a vehicle parked near it takes the crates).
var _stall_at := Vector3.ZERO
## Hens in the order being put together.
var _order := 2


static func portrait(species: StringName, adult := true) -> Texture2D:
	var path := "%s%s%s.png" % [PORTRAIT_DIR, species, "" if adult else "_baby"]
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _ready() -> void:
	ui_name = &"rancher"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_RANCHER"), "paw", tr("UI_RANCHER_HINT"))
	_tabs = TabStrip.new()
	_tabs.setup([["buy", tr("RANCHER_TAB_BUY"), "paw"], ["sell", tr("RANCHER_TAB_SELL"), "tag"],
			["supplies", tr("RANCHER_TAB_SUPPLIES"), "chest"]])
	_tabs.selected.connect(_set_tab)
	window.header_right.add_child(_tabs)
	_money = window.add_money_pill()
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(1200, 580)
	window.body.add_child(_content)
	Events.money_changed.connect(func(m: int, _d: int) -> void: _money.text = UiTheme.money(m))
	Animals.changed.connect(func() -> void: if visible: _fill())


func open() -> void:
	_poultry = false
	_tabs.visible = true
	window.set_heading(tr("UI_RANCHER"), "paw", tr("UI_RANCHER_HINT"))
	_money.text = UiTheme.money(Economy.money)
	_tabs.select("buy")
	show_screen()


## The poultry stall: hens in crates for the pickup parked by `stall_at`.
func open_poultry(stall_at: Vector3) -> void:
	_poultry = true
	_stall_at = stall_at
	_tabs.visible = false
	window.set_heading(tr("UI_POULTRY"), "paw", tr("UI_POULTRY_HINT"))
	_money.text = UiTheme.money(Economy.money)
	_order = clampi(_order, 1, LiveCrates.MAX_ORDER)
	_fill()
	show_screen()


func close_screen() -> void:
	hide_screen()


func _set_tab(tab: String) -> void:
	if tab == "supplies":
		close_screen()
		Game.hud.open_shop(ShopStock.rancher_supplies())
		return
	_tab = tab
	_confirm_sell = -1
	_fill()


func _fill() -> void:
	for c in _content.get_children():
		c.queue_free()
	if _poultry:
		_fill_poultry()
	elif _tab == "buy":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_content.add_child(row)
		for species: StringName in AnimalTable.ORDER:
			row.add_child(_buy_card(species))
	else:
		_fill_sell()


func _info(icon_name: String, text: String, color := UiTheme.TEXT_MUTED) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := UiTheme.icon_rect(UiTheme.glyph(icon_name), 20, UiTheme.GOLD_SOFT)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var l := UiTheme.make_label(text, UiTheme.text(17, color, 600))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	return row


func _buy_card(species: StringName) -> Control:
	var info := AnimalTable.get_species(species)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(286, 570)
	var sb := UiTheme.box(Color(0, 0, 0, 0.24), 16, 1, Color(1, 1, 1, 0.08))
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	# Portrait on a soft spotlight.
	var stage := PanelContainer.new()
	var ssb := UiTheme.box(Color(1, 1, 1, 0.05), 12)
	stage.add_theme_stylebox_override("panel", ssb)
	box.add_child(stage)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(254, 180)
	pic.texture = portrait(species)
	stage.add_child(pic)
	box.add_child(UiTheme.make_label(UiTheme.caps(Animals.species_name(species)), UiTheme.heading(34, UiTheme.TEXT, 700, 2)))
	var housing_kind: String = info["housing"]
	var housing: AnimalHousing = Game.world.farm.housing_for(housing_kind)
	var home := tr("HOUSING_" + housing_kind.to_upper())
	var space := "%d / %d" % [Animals.count_in(housing_kind), housing.capacity()] if housing.level > 0 else tr("BUILD_LOCKED")
	box.add_child(_info("home", "%s: %s" % [home, space], UiTheme.TEXT))
	var product: StringName = info.get("product", &"")
	var product_text := tr("RANCHER_RIDEABLE") if info.get("rideable", false) else (tr("RANCHER_PRODUCT") % [ItemDB.get_item(product).display_name(),
			tr("RANCHER_DAILY") if int(info["product_days"]) == 1 else tr("RANCHER_EVERY_DAYS") % int(info["product_days"])])
	box.add_child(_info("sparkles", product_text))
	box.add_child(_info("food", tr("RANCHER_FOOD") % [int(info["food"]), ItemDB.get_item(&"feed" if species == &"chicken" else &"hay").display_name()]))
	box.add_child(UiTheme.expand())
	var reason_any := Animals.can_buy(species, false)
	if reason_any != "" and AnimalTable.crate_item(species) != &"":
		# Hens also come in crates at the poultry stall by the market, coop or not.
		box.add_child(UiTheme.paragraph(tr("RANCHER_POULTRY_STALL_HINT"), 15, UiTheme.GOLD_SOFT, 254))
	elif reason_any != "":
		box.add_child(UiTheme.paragraph(reason_any, 15, UiTheme.RED, 254))
	for adult: bool in [false, true]:
		var cost: int = info["adult_price"] if adult else info["baby_price"]
		var b := UiTheme.button("%s  ·  %s" % [Animals.species_name(species, adult), UiTheme.money(cost)],
				"primary" if adult else "secondary", Vector2(254, 50), "", 19)
		var reason := Animals.can_buy(species, adult)
		b.disabled = reason != ""
		b.tooltip_text = reason
		b.pressed.connect(func() -> void:
			Animals.buy(species, adult)
			_fill())
		box.add_child(b)
	return card


# --- Poultry stall -----------------------------------------------------------------------

## An _info row whose text takes the whole width (wider cards than the buy cards).
func _wide(row: HBoxContainer) -> HBoxContainer:
	(row.get_child(1) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _fill_poultry() -> void:
	var species := &"chicken"
	var info := AnimalTable.get_species(species)
	var crate := AnimalTable.crate_item(species)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_content.add_child(row)
	# The hen: portrait, what she gives and eats, where she will live.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 570)
	var sb := UiTheme.box(Color(0, 0, 0, 0.24), 16, 1, Color(1, 1, 1, 0.08))
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	row.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.05), 12))
	box.add_child(stage)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(394, 230)
	pic.texture = portrait(species)
	stage.add_child(pic)
	box.add_child(UiTheme.make_label(UiTheme.caps(ItemDB.get_item(crate).display_name()), UiTheme.heading(32, UiTheme.TEXT, 700, 2)))
	box.add_child(_wide(_info("sparkles", tr("RANCHER_PRODUCT") % [ItemDB.get_item(info["product"]).display_name(), tr("RANCHER_DAILY")])))
	box.add_child(_wide(_info("food", tr("RANCHER_FOOD") % [int(info["food"]), ItemDB.get_item(&"feed").display_name()])))
	var housing: AnimalHousing = Game.world.farm.housing_for(info["housing"]) if Game.world else null
	if housing and housing.level > 0:
		box.add_child(_wide(_info("home", "%s: %d / %d" % [tr("HOUSING_COOP"), Animals.count_in(info["housing"]), housing.capacity()], UiTheme.TEXT)))
	box.add_child(_wide(_info("box", tr("RANCHER_CRATE_HINT"), UiTheme.TEXT)))
	# The order: how many, what it costs, where the crates go.
	var order := PanelContainer.new()
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var osb := UiTheme.box(Color(0, 0, 0, 0.24), 16, 1, Color(1, 1, 1, 0.08))
	osb.set_content_margin_all(24)
	order.add_theme_stylebox_override("panel", osb)
	row.add_child(order)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	order.add_child(col)
	col.add_child(UiTheme.section(tr("UI_POULTRY_ORDER"), "cart"))
	var room := LiveCrates.room_at(species, _stall_at)
	var most := clampi(mini(room, LiveCrates.MAX_ORDER), 1, LiveCrates.MAX_ORDER)
	_order = clampi(_order, 1, most)
	var qty := HBoxContainer.new()
	qty.add_theme_constant_override("separation", 18)
	qty.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(qty)
	var minus := IconButton.new("minus", 52, UiTheme.TEXT)
	minus.disabled = _order <= 1
	minus.pressed.connect(func() -> void:
		_order = maxi(_order - 1, 1)
		Audio.ui("click")
		_fill())
	qty.add_child(minus)
	var count := UiTheme.make_label(str(_order), UiTheme.heading(64, UiTheme.TEXT, 700, 0))
	count.custom_minimum_size = Vector2(110, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty.add_child(count)
	var plus := IconButton.new("plus", 52, UiTheme.TEXT)
	plus.disabled = _order >= most
	plus.pressed.connect(func() -> void:
		_order = mini(_order + 1, most)
		Audio.ui("click")
		_fill())
	qty.add_child(plus)
	var each := LiveCrates.price(species)
	var unit := UiTheme.make_label(tr("UI_POULTRY_EACH") % UiTheme.money(each), UiTheme.text(18, UiTheme.TEXT_MUTED, 600))
	unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(unit)
	var total := HBoxContainer.new()
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_theme_constant_override("separation", 12)
	total.add_child(UiTheme.make_label(UiTheme.caps(tr("UI_TOTAL")), UiTheme.heading(20, UiTheme.TEXT_MUTED, 700, 2)))
	total.add_child(UiTheme.price(each * _order, 36, 36))
	col.add_child(total)
	col.add_child(UiTheme.separator())
	var v := LiveCrates.vehicle_near(_stall_at)
	if v:
		col.add_child(_wide(_info("truck", tr("RANCHER_CRATE_TO_BED") % [v.display_name(), v.cargo.space()], UiTheme.GREEN)))
	else:
		col.add_child(_wide(_info("backpack", tr("RANCHER_CRATE_TO_BAG"), UiTheme.TEXT)))
	col.add_child(UiTheme.expand())
	var why := LiveCrates.can_buy(species, _order, _stall_at)
	if why != "":
		col.add_child(UiTheme.paragraph(why, 16, UiTheme.RED, 620))
	var buy := UiTheme.button(tr("RANCHER_BUY_CRATES") % [_order, UiTheme.money(each * _order)], "success", Vector2(620, 60), "check", 22)
	buy.disabled = why != ""
	buy.pressed.connect(func() -> void:
		if LiveCrates.buy(species, _order, _stall_at) > 0:
			Audio.ui("confirm")
		_fill())
	col.add_child(buy)


func _fill_sell() -> void:
	if Animals.animals.is_empty():
		var empty := VBoxContainer.new()
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.add_child(empty)
		empty.add_child(UiTheme.icon_rect(UiTheme.glyph("paw"), 64, UiTheme.TEXT_DIM))
		var l := UiTheme.make_label(tr("RANCHER_NO_ANIMALS"), UiTheme.text(22, UiTheme.TEXT_DIM, 600))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(l)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1200, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for a in Animals.animals:
		var row := PanelContainer.new()
		var sb := UiTheme.box(Color(0, 0, 0, 0.24), 12, 1, Color(1, 1, 1, 0.08))
		sb.content_margin_left = 12
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 20)
		row.add_child(h)
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(110, 76)
		pic.texture = portrait(a.species, a.adult)
		h.add_child(pic)
		var name_box := VBoxContainer.new()
		name_box.custom_minimum_size = Vector2(300, 0)
		name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_box.add_theme_constant_override("separation", 2)
		name_box.add_child(UiTheme.make_label(UiTheme.caps(a.name), UiTheme.heading(26, UiTheme.TEXT, 700, 1)))
		name_box.add_child(UiTheme.make_label(Animals.species_name(a.species, a.adult), UiTheme.text(16, UiTheme.TEXT_MUTED, 600)))
		h.add_child(name_box)
		var stats := VBoxContainer.new()
		stats.add_theme_constant_override("separation", 6)
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(stats)
		var hearts := HBoxContainer.new()
		hearts.add_theme_constant_override("separation", 3)
		for i in 5:
			hearts.add_child(UiTheme.icon_rect(UiTheme.glyph("heart"), 18, Color("ff6f86") if i < a.hearts() else Color(1, 1, 1, 0.15)))
		stats.add_child(hearts)
		for pair: Array in [["health", a.health], ["smile", a.happiness]]:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			r.add_child(UiTheme.icon_rect(UiTheme.glyph(pair[0]), 16, UiTheme.TEXT_MUTED))
			var bar := StatBar.new(6.0)
			bar.custom_minimum_size = Vector2(220, 6)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.set_value(float(pair[1]), false)
			r.add_child(bar)
			stats.add_child(r)
		var price_row := UiTheme.price(a.sale_value(), 28, 28)
		price_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(price_row)
		var confirm := _confirm_sell == a.id
		var b := UiTheme.button(tr("RANCHER_CONFIRM") if confirm else tr("SHOP_SELL"), "danger" if confirm else "success",
				Vector2(170, 50), "check" if confirm else "tag", 19)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			if _confirm_sell == a.id:
				var got := Animals.sell(a)
				Game.notify("+%s %s" % [UiTheme.money(got), tr("UI_GOLD")], UiTheme.GOLD_SOFT)
				_confirm_sell = -1
			else:
				_confirm_sell = a.id
			_fill())
		h.add_child(b)
		list.add_child(row)
