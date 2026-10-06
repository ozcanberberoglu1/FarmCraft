class_name RancherScreen
extends ModalScreen
## The Animal Market (Hayvan Pazarı) in town: buy animals, sell your own, and open the
## supplies shop (feed, hay, medicine, tools). "Buy" lists every kind the market keeps
## (AnimalTable.ORDER) on the left, each with its price and whether this farm may buy it;
## the chosen kind on the right: what it gives and eats, what the market wants to see
## on the farm first (the farm level, the building: LiveCrates.market_lock) and where it
## will live, then the purchase. Crated kinds (hens) come in transport crates, as many as
## the order says, straight into the farmer's hands and bag; only what doesn't fit is set
## down in front of the seller at the market's pickup spot by the gate (LiveCrates,
## MarketCrates): no coop needed yet. The others are young or grown: they wait in the
## loading pen by the gate for the farmer's stock trailer, or, with no trailer of his in
## town, the dealer brings them over the next morning for a fee (TrailerYard). One brought
## back to the market in the trailer sells for more. While the story's first days run the market sells
## hens only (LiveCrates.story_lock): every other kind shows locked, with the reason.
## Sheep, cows and horses are sold female (young or grown) and, grown, male (_fill_male:
## the ram, the bull, the stallion a herd needs to have young: Breeding).
## Opened at a pen's gate or the hen stall, the market shows that kind first (open_market).

const PORTRAIT_DIR := "res://art/icons/animals/"

var _tabs: TabStrip
var _content: VBoxContainer
var _money: Label
var _tab := "buy"
var _confirm_sell := -1
## The kind shown on the right of "Buy".
var _selected: StringName = &""
## Where the market was opened.
var _stall_at := Vector3.ZERO
## Crated animals in the order being put together.
var _order := 2
## The big portrait of the chosen kind (it hops when one is bought).
var _portrait: TextureRect


static func portrait(species: StringName, adult := true) -> Texture2D:
	for s: StringName in [species, MarketHerd.model_of(species)]:
		var path := "%s%s%s.png" % [PORTRAIT_DIR, s, "" if adult else "_baby"]
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
	_content.custom_minimum_size = Vector2(1200, 600)
	window.body.add_child(_content)
	Events.money_changed.connect(func(m: int, _d: int) -> void:
		_money.text = UiTheme.money(m)
		if visible and _tab == "buy":
			_fill())
	Animals.changed.connect(func() -> void: if visible: _fill())


## The market as the livestock office opens it (the whole list, the last kind shown).
func open() -> void:
	var town := get_tree().get_first_node_in_group(&"town") as Town
	var at := town.market_office.global_position if town and town.market_office else Vector3.ZERO
	open_market(at, &"")


## Opens the market at `at` on `focus` (&"": the kind last shown, else the first).
func open_market(at: Vector3, focus: StringName = &"") -> void:
	_stall_at = at
	if focus != &"" and not AnimalTable.get_species(focus).is_empty():
		if focus != _selected:
			_order = _default_order(focus)
		_selected = focus
	elif _selected == &"" or AnimalTable.get_species(_selected).is_empty():
		_selected = AnimalTable.ORDER[0]
		_order = _default_order(_selected)
	window.set_heading(tr("UI_RANCHER"), "paw", tr("UI_RANCHER_HINT"))
	_money.text = UiTheme.money(Economy.money)
	_order = clampi(_order, 1, LiveCrates.MAX_ORDER)
	_tab = "buy"
	_tabs.select("buy")
	_fill()
	show_screen()


## How many crates an order starts at: a pair of hens (the first coop's), one of anything else.
func _default_order(species: StringName) -> int:
	return 2 if species == &"chicken" else 1


## The hen stall: the market on crated hens.
func open_poultry(stall_at: Vector3) -> void:
	open_market(stall_at, &"chicken")


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
	_portrait = null
	if _tab == "buy":
		_fill_buy()
	else:
		_fill_sell()


# --- Buying -----------------------------------------------------------------------------

## Buys `adult` (or young) `species` straight into its housing, if the market sells it
## to this farm. Crated kinds go through LiveCrates.buy instead.
func buy_animal(species: StringName, adult: bool) -> bool:
	if why_not(species, adult) != "":
		Audio.ui("error", -6.0)
		return false
	var a := Animals.buy(species, adult, "", true)
	if a == null:
		return false
	# Into the loading pen: the farmer's trailer fetches it, or the dealer brings it.
	TrailerYard.bought(a)
	_fill()
	_bought(species, adult)
	return true


## "" when `species` can be bought here now (young or grown; crated kinds: `count` of
## them), else why not: the market's lock first, then the farm (room, money).
func why_not(species: StringName, adult := true, count := 1) -> String:
	var lock := LiveCrates.market_lock(species)
	if lock != "":
		return lock
	if AnimalTable.crate_item(species) != &"":
		return LiveCrates.can_buy(species, count, _stall_at)
	var why := Animals.can_buy(species, adult)
	if why == "":
		# With no trailer of his in town the dealer's fee comes on top.
		var info := AnimalTable.get_species(species)
		var cost := int(info["adult_price"] if adult else info["baby_price"]) + TrailerYard.fee_now()
		if Economy.money < cost:
			return tr("MSG_NEED_GOLD") % UiTheme.money(cost - Economy.money)
	return why


func _bought(species: StringName, adult: bool) -> void:
	Audio.ui("confirm")
	if Game.player:
		Audio.animal_voice(MarketHerd.model_of(species), adult, (Game.player as Node3D).global_position + Vector3(0, -0.4, 0), -8.0)
	if is_instance_valid(_portrait):
		var t := create_tween()
		_portrait.pivot_offset = _portrait.size * Vector2(0.5, 1.0)
		t.tween_property(_portrait, "scale", Vector2(1.08, 0.92), 0.08)
		t.tween_property(_portrait, "scale", Vector2(0.96, 1.06), 0.1)
		t.tween_property(_portrait, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fill_buy() -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for species: StringName in AnimalTable.ORDER:
		list.add_child(_species_card(species))
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(756, 600)
	body.add_child(card)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 12)
	card.add_child(detail)
	_fill_detail(detail, _selected)


## A kind in the list: portrait, name, the grown one's price and a tag (for sale, or
## what locks it).
func _species_card(species: StringName) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(404, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var active := species == _selected
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
	var lock := LiveCrates.market_lock(species)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(104, 76)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.texture = portrait(species)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lock != "":
		pic.modulate = Color(0.55, 0.55, 0.55, 0.8)
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_label := UiTheme.make_label(Animals.species_name(species), UiTheme.text(21, UiTheme.TEXT if lock == "" else UiTheme.TEXT_DIM, 700))
	name_label.clip_text = true
	col.add_child(name_label)
	col.add_child(UiTheme.price(int(AnimalTable.get_species(species).get("adult_price", 0)), 20))
	var chip: Control
	var need := UnlockTable.animal_level(species)
	var project := AnimalTable.market_needs(species)
	if Progress.level < need:
		chip = UiTheme.chip(tr("UI_LEVEL_SHORT") % need, UiTheme.TEXT_DIM, "lock", 15)
	elif LiveCrates.story_lock(species) != "":
		# The story's first days: hens only.
		chip = UiTheme.chip(tr("BUILD_LOCKED"), UiTheme.TEXT_DIM, "lock", 15)
	elif lock != "":
		chip = UiTheme.chip(tr("PROJECT_" + String(project).to_upper()), UiTheme.RED, "lock", 14)
	else:
		chip = UiTheme.chip(tr("MARKET_FOR_SALE"), UiTheme.GREEN, "check", 15)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	b.pressed.connect(func() -> void:
		if _selected != species:
			_selected = species
			_order = _default_order(species)
			Audio.ui("click", -8.0)
			_fill())
	return b


## An icon and a line of text (wraps).
func _info(icon_name: String, text: String, color := UiTheme.TEXT_MUTED) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := UiTheme.icon_rect(UiTheme.glyph(icon_name), 20, UiTheme.GOLD_SOFT)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var l := UiTheme.make_label(text, UiTheme.text(17, color, 600))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	return row


## A requirement: a tick or a padlock, what it is and how the farm stands.
func _requirement(ok: bool, label: String, state: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiTheme.icon_rect(UiTheme.glyph("check" if ok else "lock"), 20, UiTheme.GREEN if ok else UiTheme.RED))
	var l := UiTheme.make_label(label, UiTheme.text(18, UiTheme.TEXT, 600))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiTheme.make_label(state, UiTheme.heading(18, UiTheme.GREEN if ok else UiTheme.RED, 700, 0)))
	return row


func _fill_detail(box: VBoxContainer, species: StringName) -> void:
	var info := AnimalTable.get_species(species)
	if info.is_empty():
		return
	var crate := AnimalTable.crate_item(species)
	# Portrait beside the name and what it gives and eats.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.05), 12))
	head.add_child(stage)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(250, 170)
	_portrait.texture = portrait(species)
	stage.add_child(_portrait)
	var about := VBoxContainer.new()
	about.add_theme_constant_override("separation", 8)
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(about)
	var title := Animals.species_name(species) if crate == &"" else ItemDB.get_item(crate).display_name()
	about.add_child(UiTheme.make_label(UiTheme.caps(title), UiTheme.heading(32, UiTheme.TEXT, 700, 2)))
	var product: StringName = info.get("product", &"")
	var days := int(info.get("product_days", 1))
	if info.get("rideable", false):
		about.add_child(_info("sparkles", tr("RANCHER_RIDEABLE")))
	elif product != &"" and ItemDB.get_item(product):
		about.add_child(_info("sparkles", tr("RANCHER_PRODUCT") % [ItemDB.get_item(product).display_name(),
				tr("RANCHER_DAILY") if days <= 1 else tr("RANCHER_EVERY_DAYS") % days]))
	elif species == &"rooster":
		about.add_child(_info("sparkles", tr("RANCHER_ROOSTER")))
	var ration := ItemDB.get_item(&"feed" if String(info.get("housing", "")) == "coop" else &"hay")
	about.add_child(_info("food", tr("RANCHER_FOOD") % [int(info.get("food", 1)), ration.display_name()]))
	# What the market wants to see on the farm first, and where it will live.
	box.add_child(UiTheme.section(tr("MARKET_REQUIREMENTS"), "barn"))
	var need := UnlockTable.animal_level(species)
	box.add_child(_requirement(Progress.level >= need, tr("MARKET_REQ_LEVEL") % need, tr("UI_LEVEL_SHORT") % Progress.level))
	var story := LiveCrates.story_lock(species)
	if story != "" and Progress.level >= need:
		# Not sold yet: the reason, in the list of what the market wants first.
		box.add_child(_info("lock", story, UiTheme.RED))
	var project := AnimalTable.market_needs(species)
	if project != &"":
		var built := FarmState.is_built(project)
		box.add_child(_requirement(built, tr("PROJECT_" + String(project).to_upper()),
				tr("MARKET_BUILT") if built else tr("MARKET_NOT_BUILT")))
	var kind := String(info.get("housing", "barn"))
	var housing: AnimalHousing = Animals.home_for(species)
	var home := tr("HOUSING_" + kind.to_upper())
	if crate != &"":
		# Crated birds wait in their crates: the coop only matters to let them out.
		var has_coop := housing != null and housing.level > 0
		box.add_child(_info("home", "%s: %d / %d" % [home, Animals.count_in(kind), housing.capacity()] if has_coop else tr("RANCHER_CRATE_HINT"),
				UiTheme.TEXT if has_coop else UiTheme.GOLD_SOFT))
	elif housing and housing.level > 0:
		box.add_child(_requirement(housing.free_space() > 0, home, "%d / %d" % [Animals.count_in(kind), housing.capacity()]))
	box.add_child(UiTheme.expand())
	box.add_child(UiTheme.separator())
	if crate != &"":
		_fill_crate_order(box, species)
	else:
		_fill_young_or_grown(box, species, info)


## A crated kind: how many (no more than the farmer carries and the pickup spot still
## takes), the total, where the crates go (the bag; the seller's spot for the rest), the
## buy button.
func _fill_crate_order(box: VBoxContainer, species: StringName) -> void:
	var most := clampi(mini(LiveCrates.buy_room(AnimalTable.crate_item(species)), LiveCrates.MAX_ORDER), 1, LiveCrates.MAX_ORDER)
	_order = clampi(_order, 1, most)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var minus := IconButton.new("minus", 46, UiTheme.TEXT)
	minus.disabled = _order <= 1
	minus.pressed.connect(func() -> void:
		_order = maxi(_order - 1, 1)
		Audio.ui("click")
		_fill())
	minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(minus)
	var count := UiTheme.make_label(str(_order), UiTheme.heading(52, UiTheme.TEXT, 700, 0))
	count.custom_minimum_size = Vector2(76, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(count)
	var plus := IconButton.new("plus", 46, UiTheme.TEXT)
	plus.disabled = _order >= most
	plus.pressed.connect(func() -> void:
		_order = mini(_order + 1, most)
		Audio.ui("click")
		_fill())
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plus)
	var each := LiveCrates.price(species)
	var sums := VBoxContainer.new()
	sums.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sums.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sums.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(sums)
	var unit := UiTheme.make_label(tr("UI_POULTRY_EACH") % UiTheme.money(each), UiTheme.text(17, UiTheme.TEXT_MUTED, 600))
	unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sums.add_child(unit)
	var total := HBoxContainer.new()
	total.alignment = BoxContainer.ALIGNMENT_END
	total.add_theme_constant_override("separation", 12)
	total.add_child(UiTheme.make_label(UiTheme.caps(tr("UI_TOTAL")), UiTheme.heading(18, UiTheme.TEXT_MUTED, 700, 2)))
	total.add_child(UiTheme.price(each * _order, 32))
	sums.add_child(total)
	# Straight into the bag; an order bigger than the bag says what will wait at the seller's.
	var over := _order - LiveCrates.carry_room(AnimalTable.crate_item(species))
	box.add_child(_info("box", tr("RANCHER_CRATES_TO_BAG") if over <= 0 else tr("RANCHER_CRATES_OVERFLOW") % over,
			UiTheme.TEXT if over <= 0 else UiTheme.GOLD_SOFT))
	var waiting := LiveCrates.count_at(&"market")
	if waiting > 0:
		box.add_child(_info("clock", tr("RANCHER_CRATES_WAITING") % [waiting, LiveCrates.MAX_WAITING], UiTheme.GOLD_SOFT))
	var why := why_not(species, true, _order)
	# (The story's lock is said above, among what the market wants first.)
	if why != "" and why != LiveCrates.story_lock(species):
		box.add_child(UiTheme.paragraph(why, 16, UiTheme.RED, 700))
	var buy := UiTheme.button(tr("RANCHER_BUY_CRATES") % [_order, Animals.species_name(species), UiTheme.money(each * _order)],
			"success", Vector2(712, 58), "check", 22)
	# Marked for the scripted checks (rows rebuilt in one frame can't share a name).
	buy.set_meta(&"mark", "BuyCrates")
	buy.disabled = why != ""
	buy.pressed.connect(func() -> void:
		var got := LiveCrates.buy(species, _order, _stall_at)
		_fill()
		if got > 0:
			_bought(species, true))
	box.add_child(buy)


## A kind brought straight to the farm: the young one and the grown one, each with its price.
func _fill_young_or_grown(box: VBoxContainer, species: StringName, info: Dictionary) -> void:
	box.add_child(_info("barn", TrailerYard.delivery_line(), UiTheme.TEXT))
	var why := why_not(species, false)
	var why_grown := why_not(species, true)
	var shown := why_grown if why_grown != "" else why
	if shown != "" and shown != LiveCrates.story_lock(species):
		box.add_child(UiTheme.paragraph(shown, 16, UiTheme.RED, 700))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for adult: bool in [false, true]:
		var cost := int(info["adult_price"] if adult else info["baby_price"])
		var b := UiTheme.button("%s  ·  %s" % [Animals.species_name(species, adult), UiTheme.money(cost)],
				"success" if adult else "secondary", Vector2(349, 58), "check" if adult else "", 20)
		var reason := why_grown if adult else why
		b.disabled = reason != ""
		b.tooltip_text = reason
		b.pressed.connect(func() -> void:
			if not buy_animal(species, adult):
				_fill())
		row.add_child(b)
	if Breeding.breeds(species):
		_fill_male(box, species)


## The kind's male (a ram, a bull, a stallion: Breeding), sold grown: what he is for, his
## price, the purchase.
func _fill_male(box: VBoxContainer, species: StringName) -> void:
	var who := Breeding.male_name(species)
	box.add_child(_info("heart", tr("RANCHER_MALE_HINT") % who, UiTheme.TEXT_MUTED))
	var lock := LiveCrates.market_lock(species)
	var why := lock if lock != "" else Breeding.can_buy_male(species)
	var b := UiTheme.button("%s  ·  %s" % [who, UiTheme.money(Breeding.male_price(species))], "secondary", Vector2(712, 52), "heart", 20)
	b.set_meta(&"mark", "BuyMale")
	b.disabled = why != ""
	b.tooltip_text = why
	b.pressed.connect(func() -> void:
		if buy_male(species):
			return
		_fill())
	box.add_child(b)


## Buys a grown male of `species`, if the market sells the kind to this farm
## (Breeding.buy_male). Like any animal that walks he then waits in the loading pen for the
## farmer's trailer, or the dealer brings him the next morning for the fee (TrailerYard).
func buy_male(species: StringName) -> bool:
	if LiveCrates.market_lock(species) != "" or Breeding.can_buy_male(species) != "" \
			or Economy.money < Breeding.male_price(species) + TrailerYard.fee_now():
		Audio.ui("error", -6.0)
		return false
	var a := Breeding.buy_male(species)
	if a == null:
		return false
	TrailerYard.bought(a)
	_fill()
	_bought(species, true)
	return true


# --- Selling ------------------------------------------------------------------------------

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
	scroll.custom_minimum_size = Vector2(1200, 600)
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
		name_box.add_child(UiTheme.make_label(Breeding.sex_name(a) if not a.pregnant() else "%s  ·  %s" % [Breeding.sex_name(a), Breeding.status_text(a)],
				UiTheme.text(16, UiTheme.TEXT_MUTED, 600)))
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
		# Brought to the market in the trailer: it fetches more.
		var bonus := TrailerYard.sale_bonus(a)
		if bonus > 0:
			var brought := UiTheme.chip(tr("MARKET_TRAILER_BONUS"), UiTheme.GREEN, "check", 15)
			brought.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(brought)
		var price_row := UiTheme.price(a.sale_value() + bonus, 28)
		price_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(price_row)
		if a.at_vet():
			# Away at the vet's clinic: not here to be sold until it is back.
			var away := UiTheme.chip(tr("VET_IN_TREATMENT"), UiTheme.GREEN, "health", 17)
			away.custom_minimum_size = Vector2(170, 0)
			away.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(away)
			list.add_child(row)
			continue
		var confirm := _confirm_sell == a.id
		var b := UiTheme.button(tr("RANCHER_CONFIRM") if confirm else tr("SHOP_SELL"), "danger" if confirm else "success",
				Vector2(170, 50), "check" if confirm else "tag", 19)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			if _confirm_sell == a.id:
				var extra := TrailerYard.sale_bonus(a)
				var got := Animals.sell(a) + extra
				if extra > 0:
					Economy.add_money(extra, "REPORT_ANIMALS")
				Game.notify("+" + UiTheme.money(got), UiTheme.GOLD_SOFT)
				_confirm_sell = -1
			else:
				_confirm_sell = a.id
			_fill())
		h.add_child(b)
		list.add_child(row)
