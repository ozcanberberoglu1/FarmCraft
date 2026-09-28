class_name ConfirmDialog
extends ModalScreen
## A small "are you sure?" window over other screens: a message, a cancel button and
## a confirm button that runs the given action (red for destructive ones).

var _text: Label
var _ok: UiButton
var _action: Callable


func _ready() -> void:
	ui_name = &"confirm"
	make_window("", "info")
	# It opens over other screens: dim them rather than blur them away.
	var backdrop := get_child(0)
	remove_child(backdrop)
	backdrop.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, 0)
	_text = UiTheme.paragraph("", 18, UiTheme.TEXT, 520)
	window.body.add_child(_text)
	window.body.add_child(UiTheme.spacer(6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	window.body.add_child(row)
	var cancel := UiTheme.button(tr("UI_CANCEL"), "ghost", Vector2(170, 48), "", 18)
	cancel.pressed.connect(hide_screen)
	row.add_child(cancel)
	_ok = UiTheme.button("", "primary", Vector2(220, 48), "check", 18)
	_ok.pressed.connect(_confirm)
	row.add_child(_ok)


func ask(title: String, text: String, ok_label: String, action: Callable, danger := false) -> void:
	window.set_heading(title, "info")
	_text.text = text
	_ok.setup(ok_label, "danger" if danger else "primary", Vector2(220, 48), "trash" if danger else "check", 18)
	_action = action
	show_screen()


func _confirm() -> void:
	hide_screen()
	if _action.is_valid():
		_action.call()
