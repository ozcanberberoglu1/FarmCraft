class_name PetNameScreen
extends ModalScreen
## A small naming prompt: as Zeynep hands the farmer his pup (Pet.adopt), and as the
## farm's first hens and its first rooster go into the coop (Animals.release). A name is
## already in the field ("Fındık", "Gıdık"...) that he can keep or type over, and a few
## other ideas under it fill the field when clicked. Enter, the button or Esc settle it
## (an empty field keeps the suggested name).

## The name he chose.
signal named(pet_name: String)

## Ideas shown under the field at most.
const MAX_IDEAS := 4

var edit: LineEdit
var _default := ""


func _ready() -> void:
	ui_name = &"pet_name"
	close_actions = [&"pause"]


## Opens the prompt with `default_name` in the field: the puppy's title and line unless
## `title` / `sub` are given, with `ideas` (other names) as buttons under it.
func open(default_name: String, title := "", sub := "", icon := "heart", ideas: PackedStringArray = PackedStringArray()) -> void:
	_default = default_name
	for c in get_children():
		c.queue_free()
	make_window(title if title != "" else tr("PET_NAME_TITLE"), icon, sub if sub != "" else tr("PET_NAME_SUB"))
	var body := window.body
	edit = LineEdit.new()
	edit.text = default_name
	edit.max_length = 18
	edit.custom_minimum_size = Vector2(420, 60)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_override("font", UiTheme.display(700, 1))
	edit.add_theme_font_size_override("font_size", 36)
	edit.add_theme_color_override("font_color", UiTheme.TEXT)
	edit.add_theme_color_override("caret_color", UiTheme.GOLD)
	var sb := UiTheme.box(Color(1, 1, 1, 0.06), 8, 1, Color(UiTheme.GOLD, 0.6))
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	edit.add_theme_stylebox_override("normal", sb)
	edit.add_theme_stylebox_override("focus", sb)
	edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	edit.text_submitted.connect(func(_t: String) -> void: hide_screen())
	body.add_child(edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for idea: String in ideas:
		if idea.strip_edges() == "" or idea == default_name or row.get_child_count() >= MAX_IDEAS:
			continue
		var b := UiTheme.button(idea, "ghost", Vector2(0, 40), "", 18)
		b.pressed.connect(func() -> void:
			edit.text = idea
			edit.grab_focus()
			edit.caret_column = idea.length())
		row.add_child(b)
	if row.get_child_count() > 0:
		body.add_child(UiTheme.spacer(8))
		body.add_child(row)
	else:
		row.free()
	body.add_child(UiTheme.spacer(10))
	var ok := UiTheme.button(tr("PET_NAME_OK"), "primary", Vector2(260, 56), "check", 22)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(hide_screen)
	body.add_child(ok)
	show_screen()
	edit.grab_focus.call_deferred()
	edit.select_all.call_deferred()


## Settles the name (the field's, or the suggested one when left empty).
func confirm() -> void:
	hide_screen()


func _on_hidden() -> void:
	var n := edit.text.strip_edges() if edit else ""
	named.emit(n if n != "" else _default)
