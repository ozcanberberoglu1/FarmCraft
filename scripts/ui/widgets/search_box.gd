class_name SearchBox
extends PanelContainer
## The search field the buying and selling lists share (the stalls' and the market's
## window, the catalogue, the car dealer's list, the animals he sells): a magnifier, the
## field ("What are you after?"), the key that reaches it (F) and a cross that empties it.
## The list is filtered as he types, by the goods' names as the screen shows them
## (matches): case-blind, the Turkish dotted and dotless i one letter, accents folded
## ("sut" finds "Süt"), anywhere in the name, every word typed somewhere in it.
## Keys: F (or a click) puts the caret in it; while it is there every key is the field's
## (E, I, Tab and the digits are letters, no screen closes on them); Enter leaves it with
## the list still filtered; Esc empties it, and with nothing in it closes the screen.
## Only while its screen is the one in front (in_front): a window opening over it (the
## level-up window, as a sale is made) takes the caret out and has the keys to itself.
## It empties itself when its screen closes (silently: screens fill their lists as they
## open). The first time one is on screen a line under it says how it works (HINT_FLAG:
## a bubble on the window itself, because the game's own notes stand behind a window's
## blurred backdrop), until he reaches for the field or TIP_SECONDS have passed. The line
## counts as said once it has really come up (or he has found the field by himself).

## The words typed, folded (fold): "" when the field is empty.
signal changed(query: String)

## The key that puts the caret in the field (InputSetup: F).
const FOCUS_ACTION := &"search"
## FarmState.flags: the one-time line about searching has been said.
const HINT_FLAG := "search_hint"
## True: the caret is in the field as soon as its screen opens (I and Tab then no longer
## close that screen: they are letters). False: F or a click first.
const FOCUS_ON_OPEN := false
const MAX_LENGTH := 24
## The one-time line: how long after the field comes on screen it shows (the window has
## opened by then) and how long it stays (s).
const TIP_DELAY := 0.35
const TIP_SECONDS := 8.0
const HEIGHT := 44.0
## The letters' paper and inks (the catalogue's page).
const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.2, 0.15, 0.11)
const INK_SOFT := Color(0.36, 0.29, 0.22)
## Letters that count as their plain one (after lower-casing; the Turkish i is fold's own).
const FOLDS := {"ç": "c", "ğ": "g", "ö": "o", "ş": "s", "ü": "u", "â": "a", "î": "i", "û": "u",
	"á": "a", "à": "a", "ä": "a", "ã": "a", "å": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
	"í": "i", "ì": "i", "ï": "i", "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ø": "o", "ú": "u", "ù": "u",
	"ñ": "n", "ß": "ss", "ý": "y", "ÿ": "y", "œ": "oe", "æ": "ae", "ą": "a", "ć": "c", "ę": "e",
	"ł": "l", "ń": "n", "ś": "s", "ź": "z", "ż": "z", "č": "c", "š": "s", "ž": "z", "ř": "r",
	"ě": "e", "ů": "u", "ď": "d", "ť": "t", "ň": "n", "ё": "е"}

## Tests: the one-time line is said in an automated run too.
static var testing := false

var field: LineEdit
var _paper := false
var _clear: Button
var _key: Control
var _glass: TextureRect
## The one-time line's bubble under the field (null when it isn't up).
var _tip: PanelContainer


## `text` as the search compares it: lower case, I İ ı i all "i", accents and combining
## marks gone, single spaces.
static func fold(text: String) -> String:
	var s := text.replace("İ", "i").replace("I", "i").to_lower().replace("ı", "i")
	var out := ""
	for i in s.length():
		var code := s.unicode_at(i)
		if code < 128:
			out += s[i]
		elif code < 0x300 or code > 0x36f:
			out += String(FOLDS.get(s[i], s[i]))
	return " ".join(out.split(" ", false))


## The name `shown` on a row answers the folded `query` (every word of it is somewhere in
## the name; an empty query takes everything).
static func matches(shown: String, query: String) -> bool:
	if query == "":
		return true
	var name := fold(shown)
	for word in query.split(" ", false):
		if not name.contains(word):
			return false
	return true


## `paper`: in ink on the catalogue's paper instead of on the windows' glass.
func _init(width := 320.0, paper := false) -> void:
	_paper = paper
	custom_minimum_size = Vector2(width, HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_IBEAM
	var ink := INK if paper else UiTheme.TEXT
	var soft := INK_SOFT if paper else UiTheme.TEXT_MUTED
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_glass = UiTheme.icon_rect(UiTheme.glyph("search"), 22, soft)
	_glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_glass)
	field = LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.max_length = MAX_LENGTH
	field.context_menu_enabled = false
	field.middle_mouse_paste_enabled = false
	field.caret_blink = true
	field.add_theme_font_override("font", UiTheme.font(600))
	field.add_theme_font_size_override("font_size", 20)
	field.add_theme_color_override("font_color", ink)
	field.add_theme_color_override("font_placeholder_color", Color(soft, 0.75))
	field.add_theme_color_override("caret_color", INK if paper else UiTheme.GOLD)
	field.add_theme_color_override("selection_color", Color(UiTheme.GOLD, 0.35))
	for state: String in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	row.add_child(field)
	_key = UiTheme.keycap("F", 15)
	_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_key)
	_clear = Button.new()
	_clear.icon = UiTheme.glyph("close")
	_clear.expand_icon = true
	_clear.flat = true
	_clear.custom_minimum_size = Vector2(26, 26)
	_clear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_clear.focus_mode = Control.FOCUS_NONE
	_clear.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		_clear.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["icon_normal_color", "icon_focus_color"]:
		_clear.add_theme_color_override(state, soft)
	for state: String in ["icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		_clear.add_theme_color_override(state, ink)
	_clear.visible = false
	row.add_child(_clear)
	field.text_changed.connect(_on_typed)
	field.gui_input.connect(_on_field_input)
	# Enter: back to the screen's own keys, the list still filtered.
	field.text_submitted.connect(func(_t: String) -> void: field.release_focus())
	field.focus_entered.connect(_sync)
	field.focus_exited.connect(_sync)
	_clear.pressed.connect(func() -> void:
		Audio.ui("click", -9.0)
		clear())
	_sync()


func _ready() -> void:
	Events.ui_opened.connect(_on_ui_opened)


## The screen the field is on (null: on none).
func _screen() -> ModalScreen:
	var n := get_parent()
	while n != null and not n is ModalScreen:
		n = n.get_parent()
	return n as ModalScreen


## Its screen is the one in front: no other window has opened over it.
func in_front() -> bool:
	var screen := _screen()
	return screen == null or not Game.is_ui_open() or Game.top_ui() == screen.ui_name


## A window opened over the field's screen: the caret out, the keys are that window's.
func _on_ui_opened(_ui_name: StringName) -> void:
	if field.has_focus() and not in_front():
		field.release_focus()


## The words in the field, folded for matches ("" when there are none).
func query() -> String:
	return fold(field.text)


## The line a list shows when nothing in it answers the search.
func none_line() -> String:
	return tr("SEARCH_NONE") % field.text.strip_edges()


func has_caret() -> bool:
	return field.has_focus()


## The one-time line is up under the field: its text ("" when it isn't).
func tip_text() -> String:
	if not is_instance_valid(_tip) or _tip.is_queued_for_deletion():
		return ""
	return String(_tip.get_meta(&"text", ""))


## The caret into the field (F, a click on the magnifier).
func focus() -> void:
	if not is_visible_in_tree() or not in_front():
		return
	# (he has found the field by himself: the one-time line has nothing left to say)
	FarmState.flags[HINT_FLAG] = true
	_drop_tip()
	field.grab_focus()
	# (a field focused from code does not take keys until it is told to: Godot 4.3+)
	if field.has_method(&"edit") and not field.is_editing():
		field.edit()
	field.caret_column = field.text.length()


## Empties the field and tells the list (the cross, Esc).
func clear() -> void:
	if field.text == "":
		return
	field.text = ""
	_sync()
	changed.emit("")


## Empties the field and gives the caret up without a word: the screen closed (or the
## field went out of sight), and screens fill their lists as they open.
func reset() -> void:
	field.text = ""
	if field.has_focus():
		field.release_focus()
	_drop_tip()
	_sync()


func _on_typed(_text: String) -> void:
	_drop_tip()
	_sync()
	changed.emit(query())


## The cross while there is something to empty, the key while the caret is elsewhere;
## the rim gold while he types.
func _sync() -> void:
	var typing := field.has_focus()
	_clear.visible = field.text != ""
	_key.visible = field.text == "" and not typing
	var sb: StyleBoxFlat
	if _paper:
		sb = UiTheme.box(PAPER.darkened(0.03 if typing else 0.08), 6, 1, Color(INK_SOFT, 0.8 if typing else 0.4))
	else:
		sb = UiTheme.box(Color(0, 0, 0, 0.4 if typing else 0.28), 10, 1, Color(UiTheme.GOLD, 0.7) if typing else Color(1, 1, 1, 0.14))
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED or field == null or not is_inside_tree():
		return
	if not is_visible_in_tree():
		reset()
		return
	# (in the language of the moment: it can change while the game runs)
	field.placeholder_text = tr("SEARCH_PLACEHOLDER")
	_clear.tooltip_text = tr("SEARCH_CLEAR")
	_tell_once()
	if FOCUS_ON_OPEN:
		focus.call_deferred()


## The first time a search field is on screen: one line on how it works, in a bubble
## under the field (over the tops of the list's first tiles; over the field on paper).
func _tell_once() -> void:
	if bool(FarmState.flags.get(HINT_FLAG, false)) or DebugTools.is_automated() and not testing:
		return
	_drop_tip()
	var tip := PanelContainer.new()
	_tip = tip
	# (its own place on the screen: the box neither sizes it nor is sized by it)
	tip.top_level = true
	tip.z_index = 50
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.set_meta(&"text", tr("HINT_SEARCH"))
	var sb := UiTheme.box(Color(0.05, 0.06, 0.05, 0.97), 10, 1, Color(UiTheme.GOLD, 0.75))
	sb.border_width_left = 4
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	tip.add_theme_stylebox_override("panel", sb)
	tip.add_child(UiTheme.icon_row(UiTheme.glyph("info"), tr("HINT_SEARCH"), UiTheme.GOLD_SOFT, 20, 22))
	tip.modulate.a = 0.0
	add_child(tip)
	# (once the window has opened and the field is where it stays)
	await get_tree().create_timer(TIP_DELAY).timeout
	if not is_instance_valid(tip) or tip != _tip or not is_visible_in_tree():
		return
	# (said: a window shut again before the line came up has not said it)
	FarmState.flags[HINT_FLAG] = true
	tip.reset_size()
	# (under the field, over the tiles' tops; on the catalogue's paper over the field: under
	# it the bubble would hide the whole first line of the list, its buttons with it)
	tip.global_position = global_position + (Vector2(0.0, -tip.size.y - 8.0) if _paper else Vector2(0.0, size.y + 8.0))
	Audio.ui("notify", -10.0)
	var tw := tip.create_tween()
	tw.tween_property(tip, "modulate:a", 1.0, 0.2)
	tw.tween_interval(TIP_SECONDS)
	tw.tween_property(tip, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_drop_tip)


## The one-time line goes (he reached for the field, the screen closed, its time is up).
func _drop_tip() -> void:
	if is_instance_valid(_tip):
		_tip.queue_free()
	_tip = null


## A click anywhere on the box (the magnifier, the rim) is a click in the field.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		focus()
		accept_event()


## The field's keys before the field has them: Esc empties it, and with nothing in it
## closes the screen; Tab and the up and down arrows stay here (they would walk the caret
## off to another control).
func _on_field_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	if _is_cancel(k):
		field.accept_event()
		if k.echo:
			return
		if field.text != "":
			clear()
		else:
			_close_screen()
	elif k.keycode in [KEY_TAB, KEY_UP, KEY_DOWN] or k.physical_keycode in [KEY_TAB, KEY_UP, KEY_DOWN]:
		field.accept_event()


static func _is_cancel(k: InputEventKey) -> bool:
	return k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE or k.is_action(&"pause")


## Esc with nothing typed: the screen the field is on closes, as Esc does anywhere on it.
func _close_screen() -> void:
	field.release_focus()
	var screen := _screen()
	if screen != null:
		screen.hide_screen()


## Keys the field left alone come by here before any of the game's or the screen's own
## (this runs ahead of every _unhandled_input): with the caret in the field they end
## here, so nothing typed opens the bag, picks a hotbar slot or closes the screen (the
## F1-F12 keys go on: a screenshot can be taken while he types). With the caret elsewhere:
## F brings it, and Esc empties a field with words in it before it closes anything.
## Under another window (in_front) every key is that window's.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not is_visible_in_tree() or not in_front():
		return
	if field.has_focus():
		if k.keycode < KEY_F1 or k.keycode > KEY_F35:
			if k.physical_keycode < KEY_F1 or k.physical_keycode > KEY_F35:
				get_viewport().set_input_as_handled()
		return
	if not k.pressed or k.echo:
		return
	if k.is_action(FOCUS_ACTION):
		get_viewport().set_input_as_handled()
		Audio.ui("click", -10.0)
		focus()
	elif _is_cancel(k) and field.text != "":
		get_viewport().set_input_as_handled()
		clear()
