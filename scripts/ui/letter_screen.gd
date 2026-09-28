class_name LetterScreen
extends ModalScreen
## Grandpa Osman's letters, on a sheet of paper over the blurred game: the one waiting
## when a new game begins (why the player is here and what to do first), and the last
## one when the story's goals are done. Paragraphs are separated by "|" in the texts.
## Putting the first letter down turns to his notebook: the first chapter's line shows
## under the first goal.

const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.2, 0.15, 0.11)
const INK_SOFT := Color(0.36, 0.29, 0.22)

var _sheet: PanelContainer
## The letter on the sheet: "intro" or "final".
var _kind := ""


func _ready() -> void:
	ui_name = &"letter"
	close_actions = [&"pause"]


## `kind`: "intro" or "final".
func open(kind: String) -> void:
	_kind = kind
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
	for para in tr("LETTER_%s_BODY" % kind.to_upper()).split("|"):
		var l := UiTheme.make_label(para.strip_edges(), UiTheme.text(20, INK, 500))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(700, 0)
		col.add_child(l)
	var sign := UiTheme.make_label(tr("LETTER_SIGN"), UiTheme.heading(24, INK_SOFT, 600, 1))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(sign)
	col.add_child(UiTheme.spacer(6))
	var ok := UiTheme.button(tr("LETTER_%s_BUTTON" % kind.to_upper()), "primary", Vector2(300, 56), "check", 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(hide_screen)
	col.add_child(ok)
	show_screen()


func _on_hidden() -> void:
	if _kind == "intro" and not Quests.tutorial_done() and not DebugTools.is_automated() and Game.hud != null:
		Game.hud.show_chapter_note(Quests.chapter())
