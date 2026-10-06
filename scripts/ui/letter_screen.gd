class_name LetterScreen
extends ModalScreen
## Grandpa Osman's letters, on a sheet of paper over the blurred game: the one waiting
## when a new game begins (why the player is here and what to do first), and the last
## one when the story's goals are done. Paragraphs are separated by "|" in the texts.
## Other letters come from the town: Beyza's on the morning of a carnival day
## ("carnival", Carnival), signed with its own LETTER_<KIND>_SIGN; and the mail in the
## mailbox by the house (open_mail: Mail's letters, the first unread one on the sheet and
## all of them in a list beside it, a gift in the envelope taken out as it is opened; once
## the market's catalogue has come, a tab strip over them and the catalogue as a second
## page: CatalogPage).
## Putting the first letter down turns to his notebook: the first chapter's line shows
## under the first goal.

const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.2, 0.15, 0.11)
const INK_SOFT := Color(0.36, 0.29, 0.22)

var _sheet: PanelContainer
## The letter on the sheet: "intro", "final", "carnival" or "mail".
var _kind := ""
## Mail: the letter on the sheet (Mail.letters index), where a gift that doesn't fit
## drops, the list's column and the sheet's.
var mail_index := -1
var _drop_at := Vector3.INF
var _list: VBoxContainer
var _page: VBoxContainer
## Mail: the market catalogue's page (null before the catalogue has come), the tab strip
## over the letters and the letters' own row.
var catalog_page: CatalogPage
var _mail_tabs: TabStrip
var _mail_row: Control


func _ready() -> void:
	ui_name = &"letter"
	close_actions = [&"pause"]


## `kind`: "intro", "final" or "carnival"; `args` fill {placeholders} in its body.
func open(kind: String, args := {}) -> void:
	_kind = kind
	if kind == "carnival" and args.is_empty():
		args = Carnival.letter_args()
	elif kind == "contest" and args.is_empty():
		args = FishingContest.letter_args()
	for c in get_children():
		c.queue_free()
	add_child(UiTheme.backdrop())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_sheet = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(6)
	sb.border_color = PAPER.darkened(0.18)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 64
	sb.content_margin_right = 64
	sb.content_margin_top = 52
	sb.content_margin_bottom = 44
	_sheet.add_theme_stylebox_override("panel", sb)
	center.add_child(_sheet)
	panel = _sheet
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(700, 0)
	_sheet.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph("letter"), 30, INK_SOFT))
	var title := UiTheme.make_label(UiTheme.caps(tr("LETTER_%s_TITLE" % kind.to_upper())), UiTheme.heading(30, INK, 700, 2))
	head.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(INK_SOFT, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	for para in tr("LETTER_%s_BODY" % kind.to_upper()).format(args).split("|"):
		var l := UiTheme.make_label(para.strip_edges(), UiTheme.text(20, INK, 500))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(700, 0)
		col.add_child(l)
	# Grandpa signs his own; a letter from someone else carries its sender's name.
	var sign_key := "LETTER_%s_SIGN" % kind.to_upper()
	var sign := UiTheme.make_label(tr(sign_key) if tr(sign_key) != sign_key else tr("LETTER_SIGN"),
			UiTheme.heading(24, INK_SOFT, 600, 1))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(sign)
	col.add_child(UiTheme.spacer(6))
	var ok := UiTheme.button(tr("LETTER_%s_BUTTON" % kind.to_upper()), "primary", Vector2(300, 56), "check", 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(hide_screen)
	col.add_child(ok)
	show_screen()


## The mailbox's letters: the first unread one open on the sheet (else the newest), the
## list of all of them beside it. A gift that doesn't fit the bag drops at `drop_at`.
func open_mail(drop_at := Vector3.INF) -> void:
	_kind = "mail"
	_drop_at = drop_at
	for c in get_children():
		c.queue_free()
	add_child(UiTheme.backdrop())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	center.add_child(row)
	panel = row
	# The list: every letter, newest first.
	var side := PanelContainer.new()
	var sbl := StyleBoxFlat.new()
	sbl.bg_color = PAPER.darkened(0.12)
	sbl.set_corner_radius_all(6)
	sbl.content_margin_left = 18
	sbl.content_margin_right = 18
	sbl.content_margin_top = 20
	sbl.content_margin_bottom = 20
	side.add_theme_stylebox_override("panel", sbl)
	side.custom_minimum_size = Vector2(300, 0)
	row.add_child(side)
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 8)
	side.add_child(scol)
	scol.add_child(UiTheme.make_label(UiTheme.caps(tr("MAIL_LIST_TITLE")), UiTheme.heading(20, INK, 700, 2)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(264, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scol.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	# The sheet.
	_sheet = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(6)
	sb.border_color = PAPER.darkened(0.18)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 56
	sb.content_margin_right = 56
	sb.content_margin_top = 44
	sb.content_margin_bottom = 36
	_sheet.add_theme_stylebox_override("panel", sb)
	row.add_child(_sheet)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 14)
	_page.custom_minimum_size = Vector2(620, 0)
	_sheet.add_child(_page)
	var first := -1
	for i in Mail.letters.size():
		if not bool(Mail.letters[i].get("read", false)):
			first = i
			break
	show_letter(first if first >= 0 else Mail.letters.size() - 1)
	_add_catalog(center, row, first < 0)
	show_screen()


## The market catalogue beside the letters (Mail.catalog, once Hasan's catalogue has come):
## a tab strip over the letters' `row` and the catalogue's page in their place when its tab
## is picked; `open_on_it`: the screen opens on the catalogue (no letter waits unread).
func _add_catalog(center: Control, row: Control, open_on_it: bool) -> void:
	catalog_page = null
	_mail_tabs = null
	_mail_row = row
	if not Mail.catalog.available():
		return
	center.remove_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	panel = col
	_mail_tabs = TabStrip.new()
	_mail_tabs.setup([["letters", tr("MAIL_LIST_TITLE"), "letter"], ["catalog", tr("CATALOG_TAB"), "book"]])
	_mail_tabs.selected.connect(show_mail_tab)
	col.add_child(_mail_tabs)
	col.add_child(row)
	catalog_page = CatalogPage.new()
	catalog_page.visible = false
	col.add_child(catalog_page)
	if open_on_it:
		_mail_tabs.select("catalog")


## The mailbox's page `id` on the screen: "letters" or "catalog" (the tab strip's pick).
func show_mail_tab(id: String) -> void:
	if catalog_page == null or _mail_tabs == null:
		return
	if _mail_tabs.current != id:
		_mail_tabs.select(id)
		return
	catalog_page.visible = id == "catalog"
	_mail_row.visible = id != "catalog"
	if id == "catalog":
		catalog_page.refresh()


## Letter `index` of Mail.letters on the sheet (opened: read, its gift taken out); -1:
## none yet.
func show_letter(index: int) -> void:
	mail_index = index
	for c in _page.get_children():
		c.queue_free()
	var gift := {}
	if index >= 0 and index < Mail.letters.size():
		gift = Mail.open_letter(index, _drop_at)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_page.add_child(head)
	head.add_child(UiTheme.icon_rect(UiTheme.glyph("letter"), 28, INK_SOFT))
	if index < 0 or index >= Mail.letters.size():
		head.add_child(UiTheme.make_label(UiTheme.caps(tr("MAIL_LIST_TITLE")), UiTheme.heading(28, INK, 700, 2)))
		var none := UiTheme.make_label(tr("MAIL_EMPTY"), UiTheme.text(20, INK_SOFT, 500))
		_page.add_child(none)
	else:
		var l: Dictionary = Mail.letters[index]
		var title := UiTheme.make_label(UiTheme.caps(tr(String(l["title"]))), UiTheme.heading(28, INK, 700, 2))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(560, 0)
		head.add_child(title)
		var rule := ColorRect.new()
		rule.color = Color(INK_SOFT, 0.35)
		rule.custom_minimum_size = Vector2(0, 2)
		_page.add_child(rule)
		# Addressed to the farm by its name (FarmIdentity).
		_page.add_child(UiTheme.make_label(tr("MAIL_TO") % FarmIdentity.farm_name(), UiTheme.text(17, INK_SOFT, 600)))
		for para in tr(String(l["body"])).format(l.get("args", {})).split("|"):
			var p := UiTheme.make_label(para.strip_edges(), UiTheme.text(20, INK, 500))
			p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			p.custom_minimum_size = Vector2(620, 0)
			_page.add_child(p)
		var sign := UiTheme.make_label("— %s" % tr(String(l["from"])), UiTheme.heading(22, INK_SOFT, 600, 1))
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_page.add_child(sign)
		var in_it: Dictionary = gift if not gift.is_empty() else l.get("gift", {})
		if not in_it.is_empty():
			var g := UiTheme.make_label(tr("MAIL_GIFT") % Relations.gift_text(in_it), UiTheme.text(18, Color(0.45, 0.25, 0.12), 600))
			_page.add_child(g)
	_page.add_child(UiTheme.spacer(4))
	var more := -1
	for i in Mail.letters.size():
		if not bool(Mail.letters[i].get("read", false)):
			more = i
			break
	var ok := UiTheme.button(tr("MAIL_NEXT") if more >= 0 else tr("MAIL_CLOSE"), "primary", Vector2(280, 52),
			"letter" if more >= 0 else "check", 21)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func() -> void:
		if more >= 0:
			show_letter(more)
		else:
			hide_screen())
	_page.add_child(ok)
	_fill_list()


## The list beside the sheet: newest first, the one on the sheet marked, unread ones bold.
func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if Mail.letters.is_empty():
		_list.add_child(UiTheme.make_label(tr("MAIL_EMPTY"), UiTheme.text(16, INK_SOFT, 500)))
		return
	for i in range(Mail.letters.size() - 1, -1, -1):
		var l: Dictionary = Mail.letters[i]
		var unread := not bool(l.get("read", false))
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(260, 0)
		b.text = "%s%s\n%s" % ["● " if unread else "", tr(String(l["title"])), tr(String(l["from"]))]
		# Dark ink on the paper; the letter on the sheet on a lighter slip.
		var ink := INK if unread or i == mail_index else INK_SOFT
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, ink)
		b.add_theme_font_size_override("font_size", 16)
		var slip := StyleBoxFlat.new()
		slip.bg_color = Color(PAPER, 1.0 if i == mail_index else 0.0)
		slip.set_corner_radius_all(4)
		slip.content_margin_left = 8
		slip.content_margin_right = 8
		slip.content_margin_top = 4
		slip.content_margin_bottom = 4
		var hover := slip.duplicate() as StyleBoxFlat
		hover.bg_color = Color(PAPER, 1.0 if i == mail_index else 0.5)
		b.add_theme_stylebox_override("normal", slip)
		b.add_theme_stylebox_override("pressed", slip)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", hover)
		var idx := i
		b.pressed.connect(func() -> void: show_letter(idx))
		_list.add_child(b)


func _on_hidden() -> void:
	if _kind == "intro" and not Quests.tutorial_done() and not DebugTools.is_automated() and Game.hud != null:
		Game.hud.show_chapter_note(Quests.chapter())
