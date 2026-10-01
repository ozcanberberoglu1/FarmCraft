class_name VetScreen
extends ModalScreen
## The vet clinic in town (Yeşilova Veteriner Kliniği: E at its counter or at Dr. Selin,
## in its hours). The farm's injured animals, the most urgent first: each with its
## portrait, name and kind, how long it has left and the fee (VetClinic.fee), and "Treat":
## paid, the clinic's assistant goes to collect it (Animals.send_to_vet) and it comes
## home healed VetClinic.treatment_minutes later; short of money the button says how much
## is missing. Under them the animals at the clinic now and when they come home. When
## there are none of either, a word that all is well. Knows the animals only through the
## injured part of the Animals API (injured_ids, hours_left, send_to_vet, at_vet_ids,
## vet_return_at).

var _content: VBoxContainer
var _money: Label


## The time of day (HH:MM) at GameClock.total_minutes `total`.
static func clock_at(total: float) -> String:
	var m := fposmod(GameClock.minute + total - GameClock.total_minutes, float(GameClock.MINUTES_PER_DAY))
	return "%02d:%02d" % [int(m / 60.0), int(m) % 60]


func _ready() -> void:
	ui_name = &"vet"
	close_actions = [&"pause", &"inventory"]
	make_window(tr("UI_VET"), "health", tr("UI_VET_HINT"))
	_money = window.add_money_pill()
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(1060, 560)
	_content.add_theme_constant_override("separation", 12)
	window.body.add_child(_content)
	Events.money_changed.connect(func(m: int, _d: int) -> void:
		_money.text = UiTheme.money(m)
		if visible:
			_fill())
	Animals.changed.connect(func() -> void: if visible: _fill())


func open() -> void:
	window.set_heading(tr("UI_VET"), "health", tr("UI_VET_HINT"))
	_money.text = UiTheme.money(Economy.money)
	_fill()
	show_screen()


func close_screen() -> void:
	hide_screen()


## Pays for the injured animal `id` and sends the assistant for it. False (nothing
## changes) when it is not injured on the farm or the money is short.
func treat(id: int) -> bool:
	var a := Animals.by_id(id)
	if a == null or not Animals.injured_ids().has(id):
		return false
	var cost := VetClinic.fee(a.species, a.adult)
	if not Economy.spend(cost, "REPORT_VET"):
		Audio.ui("error", -6.0)
		_fill()
		return false
	var back := GameClock.total_minutes + VetClinic.treatment_minutes(a.species)
	Animals.send_to_vet(id, back)
	Audio.ui("confirm")
	Game.notify(tr("VET_SENT") % [a.name, clock_at(back)], UiTheme.GREEN)
	_fill()
	return true


func _fill() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	var injured := Animals.injured_ids()
	var away := Animals.at_vet_ids()
	if injured.is_empty() and away.is_empty():
		_fill_empty()
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(1060, 490)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.add_child(scroll)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 10)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		if not injured.is_empty():
			list.add_child(UiTheme.section(tr("VET_INJURED"), "health"))
			injured.sort_custom(func(a: Variant, b: Variant) -> bool: return Animals.hours_left(a) < Animals.hours_left(b))
			for id: Variant in injured:
				list.add_child(_injured_row(int(id)))
		if not away.is_empty():
			list.add_child(UiTheme.spacer(4.0))
			list.add_child(UiTheme.section(tr("VET_AT_CLINIC"), "clock"))
			for id: Variant in away:
				list.add_child(_clinic_row(int(id)))
	_content.add_child(UiTheme.expand())
	_content.add_child(UiTheme.separator())
	_content.add_child(_info("info", tr("VET_FEE_RULE") % [UiTheme.percent(roundi(VetClinic.FEE_SHARE * 100.0)),
			UiTheme.money(VetClinic.FEE_MIN)]))


## Nobody hurt, nobody at the clinic.
func _fill_empty() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(1060, 470)
	box.add_theme_constant_override("separation", 12)
	_content.add_child(box)
	var pic := UiTheme.icon_rect(UiTheme.glyph("paw"), 72, UiTheme.GREEN)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(pic)
	var l := UiTheme.make_label(tr("VET_EMPTY"), UiTheme.heading(30, UiTheme.TEXT, 700, 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var hint := UiTheme.paragraph(tr("VET_EMPTY_HINT"), 18, UiTheme.TEXT_MUTED, 640.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hint)


## A row's card and the line in it.
func _row() -> HBoxContainer:
	var panel := PanelContainer.new()
	var sb := UiTheme.box(Color(0, 0, 0, 0.24), 12, 1, Color(1, 1, 1, 0.08))
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	panel.add_child(h)
	return h


## Portrait, name and kind of animal `a`, and a tag under them.
func _animal(h: HBoxContainer, a: AnimalData, tag: Control) -> void:
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(110, 78)
	pic.texture = RancherScreen.portrait(a.species, a.adult)
	h.add_child(pic)
	var name_box := VBoxContainer.new()
	name_box.custom_minimum_size = Vector2(300, 0)
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_theme_constant_override("separation", 3)
	name_box.add_child(UiTheme.make_label(UiTheme.caps(a.name), UiTheme.heading(26, UiTheme.TEXT, 700, 1)))
	name_box.add_child(UiTheme.make_label(Animals.species_name(a.species, a.adult), UiTheme.text(16, UiTheme.TEXT_MUTED, 600)))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_box.add_child(tag)
	h.add_child(name_box)


## An injured animal: the time it has left, the fee and the button (or what is missing).
func _injured_row(id: int) -> Control:
	var h := _row()
	var a := Animals.by_id(id)
	if a == null:
		return h.get_parent()
	_animal(h, a, UiTheme.chip(tr("VET_INJURED_TAG"), UiTheme.RED, "health", 14))
	var left := Animals.hours_left(id)
	var status := VBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_theme_constant_override("separation", 4)
	var text := tr("VET_HOURS_LEFT") % ceili(left) if left >= 1.0 else tr("VET_LESS_THAN_HOUR")
	status.add_child(UiTheme.icon_row(UiTheme.glyph("clock"), text, UiTheme.RED if left < 6.0 else UiTheme.GOLD_SOFT, 20, 20))
	status.add_child(UiTheme.make_label(tr("VET_TREATMENT_HOURS") % _hours_text(VetClinic.treatment_minutes(a.species)),
			UiTheme.text(16, UiTheme.TEXT_MUTED, 600)))
	h.add_child(status)
	var cost := VetClinic.fee(a.species, a.adult)
	var price := UiTheme.price(cost, 28)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(price)
	var short := cost - Economy.money
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	var b := UiTheme.button(tr("VET_TREAT"), "success", Vector2(230, 52), "health", 19)
	b.disabled = short > 0
	b.pressed.connect(func() -> void: treat(id))
	col.add_child(b)
	if short > 0:
		var miss := UiTheme.make_label(tr("VET_SHORT") % UiTheme.money(short), UiTheme.text(16, UiTheme.RED, 700))
		miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(miss)
	h.add_child(col)
	return h.get_parent()


## An animal at the clinic: in treatment, and when it is back at the farm.
func _clinic_row(id: int) -> Control:
	var h := _row()
	var a := Animals.by_id(id)
	if a == null:
		return h.get_parent()
	_animal(h, a, UiTheme.chip(tr("VET_IN_TREATMENT"), UiTheme.GREEN, "health", 14))
	var status := VBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := Animals.vet_return_at(id)
	var text := tr("VET_RETURNS") % clock_at(back) if back >= 0.0 else tr("VET_RETURNS_SOON")
	status.add_child(UiTheme.icon_row(UiTheme.glyph("home"), text, UiTheme.TEXT, 20, 20))
	h.add_child(status)
	return h.get_parent()


## "2", "2.5": a treatment's hours.
static func _hours_text(minutes: float) -> String:
	var h := minutes / 60.0
	return str(roundi(h)) if is_equal_approx(h, roundf(h)) else ("%.1f" % h).replace(".", "," if TranslationServer.get_locale().begins_with("tr") else ".")


## An icon and a line of text (wraps).
func _info(icon_name: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := UiTheme.icon_rect(UiTheme.glyph(icon_name), 20, UiTheme.GOLD_SOFT)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var l := UiTheme.make_label(text, UiTheme.text(16, UiTheme.TEXT_MUTED, 600))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row
