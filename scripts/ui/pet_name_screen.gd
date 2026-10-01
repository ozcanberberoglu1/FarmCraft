class_name PetNameScreen
extends ModalScreen
## A small prompt as Zeynep hands the farmer his pup (Pet.adopt): what to call it, a
## name already in the field ("Fındık") that he can keep or type over. Enter, the button
## or Esc settle it (an empty field keeps the suggested name).

## The name he chose.
signal named(pet_name: String)

var edit: LineEdit
var _default := ""


func _ready() -> void:
	ui_name = &"pet_name"
	close_actions = [&"pause"]


func open(default_name: String) -> void:
	_default = default_name
	for c in get_children():
		c.queue_free()
	make_window(tr("PET_NAME_TITLE"), "heart", tr("PET_NAME_SUB"))
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
