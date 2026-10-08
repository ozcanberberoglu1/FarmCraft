class_name AnimalPanel
extends ModalScreen
## Details of one animal: portrait, editable name, age, hearts, needs, condition and
## what it needs from the player (a hurt one: "Injured" and the hours left to have it
## treated by the vet, or that it is at the clinic). Closes if the animal is gone.
## Sheep, cows and horses show their sex ("Ram", "Ewe"), one born here "Born on the farm",
## and the lines about young (_breeding_lines: "Pregnant · 2 days left", its mother).
## A hen, a rooster or a chick has "Sell" beside its value (sell_pressed): it asks once
## ("Shall I put Pamuk in her crate to sell her?": the confirm window) and the bird goes
## into a crate in the bag for the Animal Market's dealer (LiveCrates.crate_up); when it
## must not be sold now, a line under the value says why (LiveCrates.crate_block).

const STATS := [["fullness", "food"], ["hydration", "drop"], ["happiness", "smile"], ["health", "health"]]
## The colour of the lines and chips about young (Breeding).
const PREGNANT := Color("f59ac8")

var _data: AnimalData
var _portrait: TextureRect
var _name_edit: LineEdit
var _sub: HBoxContainer
var _hearts: HBoxContainer
var _bars := {}
var _status: VBoxContainer
var _value: HBoxContainer
var _sell: UiButton
var _sell_note: Label
var _refresh_timer := 0.0


func _ready() -> void:
	ui_name = &"animal"
	close_actions = [&"pause", &"animal_info"]
	make_window(tr("UI_ANIMAL"), "paw")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	window.body.add_child(top)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.05), 14))
	top.add_child(stage)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(230, 170)
	stage.add_child(_portrait)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 10)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(titles)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 18
	_name_edit.custom_minimum_size = Vector2(330, 54)
	_name_edit.add_theme_font_override("font", UiTheme.display(700, 1))
	_name_edit.add_theme_font_size_override("font_size", 38)
	_name_edit.add_theme_color_override("font_color", UiTheme.TEXT)
	_name_edit.add_theme_color_override("caret_color", UiTheme.GOLD)
	var edit_sb := UiTheme.box(Color(1, 1, 1, 0.0), 8, 0)
	edit_sb.content_margin_left = 4
	_name_edit.add_theme_stylebox_override("normal", edit_sb)
	var focus_sb := UiTheme.box(Color(1, 1, 1, 0.06), 8, 1, Color(UiTheme.GOLD, 0.6))
	focus_sb.content_margin_left = 8
	_name_edit.add_theme_stylebox_override("focus", focus_sb)
	_name_edit.text_submitted.connect(func(t: String) -> void:
		_data.name = t.strip_edges().left(18)
		_name_edit.release_focus())
	# Any animal can be renamed here (the field is its name).
	_name_edit.tooltip_text = tr("ANIMAL_RENAME_HINT")
	titles.add_child(_name_edit)
	_sub = HBoxContainer.new()
	_sub.add_theme_constant_override("separation", 8)
	titles.add_child(_sub)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 4)
	titles.add_child(_hearts)
	window.body.add_child(UiTheme.section(tr("ANIMAL_NEEDS")))
	for s: Array in STATS:
		window.body.add_child(_make_bar(s[0], s[1]))
	window.body.add_child(UiTheme.section(tr("ANIMAL_CONDITION")))
	_status = VBoxContainer.new()
	_status.add_theme_constant_override("separation", 8)
	window.body.add_child(_status)
	window.body.add_child(UiTheme.separator())
	var foot := HBoxContainer.new()
	window.body.add_child(foot)
	var vl := UiTheme.make_label(UiTheme.caps(tr("ANIMAL_VALUE")), UiTheme.heading(18, UiTheme.TEXT_MUTED, 700, 2))
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(vl)
	_value = UiTheme.price(0, 28)
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_value)
	foot.add_theme_constant_override("separation", 18)
	# Birds only: into a crate for the dealer in town (asked once).
	_sell = UiTheme.button(tr("SHOP_SELL"), "secondary", Vector2(150, 46), "tag", 19)
	_sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sell.set_meta(&"mark", "SellBird")
	_sell.pressed.connect(sell_pressed)
	foot.add_child(_sell)
	_sell_note = UiTheme.paragraph("", 16, UiTheme.GOLD_SOFT, 600)
	_sell_note.visible = false
	window.body.add_child(_sell_note)


func open(a: AnimalData) -> void:
	_data = a
	_portrait.texture = RancherScreen.portrait(a.species, a.adult)
	_name_edit.text = a.name
	for c in _sub.get_children():
		c.queue_free()
	_sub.add_child(UiTheme.chip(Breeding.sex_name(a), UiTheme.GOLD_SOFT, "paw"))
	if a.adult:
		_sub.add_child(UiTheme.chip(tr("ANIMAL_ADULT"), UiTheme.TEXT_MUTED))
	else:
		_sub.add_child(UiTheme.chip(tr("ANIMAL_GROWING") % [int(a.growth), int(a.info()["grow_days"])], UiTheme.BLUE))
	if a.injured():
		_sub.add_child(UiTheme.chip(tr("ANIMAL_INJURED"), UiTheme.RED, "health"))
	if a.born_day >= 0:
		_sub.add_child(UiTheme.chip(tr("ANIMAL_BORN_HERE"), PREGNANT, "heart"))
	_sell.visible = AnimalTable.is_poultry(a.species)
	_sell.tooltip_text = tr("ANIMAL_SELL_HINT")
	_set_sell_note("")
	_refresh()
	show_screen()


## "Sell" on a bird's card: when it can't be sold now the reason shows under its value
## (and comes back); else the confirm window asks once and, on yes, the bird goes into a
## crate in the bag and the card closes. Returns the reason ("" when it asked).
func sell_pressed() -> String:
	if _data == null:
		return ""
	var why := LiveCrates.crate_block(_data)
	_set_sell_note(why)
	if why != "":
		Audio.ui("error", -6.0)
		return why
	var a := _data
	# (A name just typed into the field is the one asked about and kept.)
	if _name_edit.text.strip_edges() != "":
		a.name = _name_edit.text.strip_edges().left(18)
	Game.hud.confirm_dialog.ask(tr("SELL_ASK_TITLE") % a.name,
			tr("SELL_ASK_TEXT") % [a.name, UiTheme.money(LiveCrates.sale_price(a))], tr("SELL_ASK_YES"),
			func() -> void:
				if LiveCrates.crate_up(a):
					Audio.ui("confirm", -6.0)
					close_panel()
				else:
					_set_sell_note(LiveCrates.crate_block(a)))
	return ""


## The line under the value that says why the bird isn't sold now ("" hides it).
func sell_note() -> String:
	return _sell_note.text if _sell_note.visible else ""


func _set_sell_note(text: String) -> void:
	_sell_note.text = text
	_sell_note.visible = text != ""


func close_panel() -> void:
	hide_screen()


func _on_hidden() -> void:
	if _data and _name_edit.text.strip_edges() != "":
		_data.name = _name_edit.text.strip_edges().left(18)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_refresh()


func _make_bar(key: String, icon_name: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiTheme.icon_rect(UiTheme.glyph(icon_name), 22, UiTheme.TEXT_MUTED))
	var l := UiTheme.make_label(UiTheme.caps(tr("STAT_" + key.to_upper())), UiTheme.heading(19, UiTheme.TEXT, 700, 2))
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var bar := StatBar.new(10.0)
	bar.custom_minimum_size = Vector2(360, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value := UiTheme.make_label("", UiTheme.heading(21, UiTheme.TEXT, 700, 0))
	value.custom_minimum_size = Vector2(44, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	_bars[key] = [bar, value]
	return row


func _refresh() -> void:
	if _data == null:
		return
	# Gone (taken by wolves, died of its wounds, sold): nothing left to show.
	if not Animals.animals.has(_data):
		close_panel()
		return
	for c in _hearts.get_children():
		c.queue_free()
	for i in 5:
		_hearts.add_child(UiTheme.icon_rect(UiTheme.glyph("heart"), 26, Color("ff6f86") if i < _data.hearts() else Color(1, 1, 1, 0.14)))
	for key: String in _bars:
		var v := clampf(float(_data.get(key)), 0.0, 100.0)
		(_bars[key][0] as StatBar).set_value(v)
		(_bars[key][1] as Label).text = str(roundi(v))
	for c in _status.get_children():
		c.queue_free()
	for line: Array in _status_lines():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UiTheme.box(line[1], 5))
		row.add_child(dot)
		var l := UiTheme.make_label(line[0], UiTheme.text(18, line[1].lerp(UiTheme.TEXT, 0.35), 600))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)
		row.add_child(l)
		_status.add_child(row)
	(_value.get_child(0) as Label).text = UiTheme.money(_data.sale_value())


## The lines about young (Breeding): hers on the way and the days left, a young one's
## mother, what a male is for, and whether a female living with one is ready for young.
func _breeding_lines() -> Array:
	var out := []
	if not Breeding.breeds(_data.species):
		return out
	if _data.pregnant():
		out.append([Breeding.status_text(_data), PREGNANT])
	elif not _data.adult:
		var mother := Animals.by_id(_data.mother)
		if mother != null:
			out.append([tr("STATUS_MOTHER") % mother.name, UiTheme.TEXT_MUTED])
	elif _data.male:
		out.append([tr("STATUS_MALE"), UiTheme.TEXT_MUTED])
	elif Breeding.sire_in(Animals.housing_of(_data), _data.species) != null:
		var ready := Breeding.blocker(_data) in ["", "rest"]
		out.append([tr("STATUS_BREED_READY") if ready else tr("STATUS_BREED_CARE"), PREGNANT if ready else UiTheme.TEXT_MUTED])
	return out


func _status_lines() -> Array:
	var bad := UiTheme.RED
	var good := UiTheme.GREEN
	var info := UiTheme.TEXT_MUTED
	var out := []
	var node := Animals.node_of(_data)
	if _data.at_vet():
		out.append([tr("STATUS_AT_VET") % maxi(1, ceili(Animals.hours_left(_data.id))), UiTheme.BLUE])
	elif _data.injured():
		out.append([tr("STATUS_INJURED") % maxi(1, ceili(Animals.hours_left(_data.id))), bad])
	if _data.sick:
		out.append([tr("STATUS_SICK"), bad])
	out.append_array(_breeding_lines())
	if _data.wet > 0.25:
		if (node and node.indoors) or not Weather.is_precipitating():
			out.append([tr("STATUS_DRYING"), info])
		else:
			out.append([tr("STATUS_WET"), bad])
	if _data.cold:
		out.append([tr("STATUS_COLD"), bad])
	if _data.fullness < 30.0:
		out.append([tr("STATUS_HUNGRY"), bad])
	if _data.hydration < 30.0:
		out.append([tr("STATUS_THIRSTY"), bad])
	var housing := Animals.housing_of(_data)
	if housing and not housing.has_shelter():
		out.append([tr("STATUS_NO_SHELTER"), Color("f2b64a")])
	if node and node.indoors:
		out.append([tr("STATUS_INDOORS"), UiTheme.BLUE])
	match _data.species:
		&"cow":
			if _data.adult and not _data.male:
				out.append([tr("STATUS_MILK_READY") if _data.product_ready else tr("STATUS_MILK_TOMORROW"), good if _data.product_ready else info])
		&"sheep":
			if _data.adult:
				out.append([tr("STATUS_WOOL_READY") if _data.product_ready else tr("STATUS_WOOL") % roundi(_data.wool * 100.0), good if _data.product_ready else info])
		&"chicken":
			if _data.adult:
				out.append([tr("STATUS_EGGS"), info])
		&"horse":
			if _data.adult:
				out.append([tr("STATUS_RIDE"), good])
	out.append([tr("STATUS_PETTED") if _data.petted_today else tr("STATUS_NOT_PETTED"), good if _data.petted_today else info])
	return out
