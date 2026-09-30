class_name OrderScreen
extends ModalScreen
## The town's orders: who wants what, how many, by which day and for how much; what
## the player has of it (bag and a pickup parked by the board) and a deliver button.

## Customers (Yeşilova townsfolk and businesses; proper names, not translated).
const CLIENTS := ["Ayşe K.", "Mehmet D.", "Fatma Y.", "Hasan B.", "Zeynep A.", "Mustafa T.", "Elif S.",
	"Ali R.", "Emine Ç.", "Hüseyin G.", "Yeşilova Lokantası", "Ova Fırını"]

var _list: VBoxContainer


func _ready() -> void:
	ui_name = &"orders"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_ORDERS"), "tag", tr("UI_ORDERS_HINT"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	window.body.add_child(_list)
	Quests.orders_changed.connect(func() -> void: if visible: _refresh())
	PlayerState.inventory.changed.connect(func() -> void: if visible: _refresh())


func open() -> void:
	_refresh()
	show_screen()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Quests.orders.is_empty():
		_list.add_child(UiTheme.paragraph(tr("UI_NO_ORDERS"), 18, UiTheme.TEXT_DIM, 760))
	for o: Dictionary in Quests.orders:
		_list.add_child(_card(o))


func _card(o: Dictionary) -> Control:
	var item := ItemDB.get_item(StringName(o["item"]))
	var card := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.22), 14, 1, UiTheme.LINE)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(900, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	row.add_child(UiTheme.icon_rect(item.icon, 72))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiTheme.make_label("%s ×%d" % [item.display_name(), int(o["count"])], UiTheme.heading(26, UiTheme.TEXT, 700, 1)))
	var days := int(o["due"]) - GameClock.day
	var when := tr("UI_ORDER_TODAY") if days <= 0 else tr("UI_ORDER_DAYS") % days
	var meta := "%s · %s" % [CLIENTS[int(o.get("client", 0)) % CLIENTS.size()], when]
	col.add_child(UiTheme.make_label(meta, UiTheme.text(16, UiTheme.RED if days <= 0 else UiTheme.TEXT_MUTED, 600)))
	var have := Quests.available(StringName(o["item"]))
	var need := int(o["count"])
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	col.add_child(bar_row)
	var bar := StatBar.new(6.0, UiTheme.GREEN if have >= need else UiTheme.GOLD)
	bar.max_value = need
	bar.set_value(mini(have, need), false)
	bar.custom_minimum_size = Vector2(320, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	bar_row.add_child(UiTheme.make_label(tr("UI_ORDER_HAVE") % [mini(have, need), need],
			UiTheme.heading(18, UiTheme.GREEN if have >= need else UiTheme.TEXT_MUTED, 700, 0)))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	var price := UiTheme.price(roundi(int(o["reward"]) * Economy.carnival_factor()), 26)
	price.size_flags_horizontal = Control.SIZE_SHRINK_END
	if Carnival.is_on():
		price.add_theme_constant_override("separation", 8)
		price.add_child(CarnivalBanner.badge())
	right.add_child(price)
	var b := UiTheme.button(tr("UI_DELIVER"), "success", Vector2(200, 46), "check", 18)
	b.disabled = have < need
	b.pressed.connect(func() -> void: Quests.deliver(o))
	right.add_child(b)
	return card
