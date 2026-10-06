class_name OptionSelector
extends HBoxContainer
## "◀ value ▶" picker cycling through a list of labels.

signal changed(index: int)

var options: Array = []
var index := 0
var _label: Label


## `label_width`: room for the longest label, so the arrows stay put while stepping.
func _init(p_options: Array = [], start := 0, label_width := 200.0) -> void:
	options = p_options
	index = clampi(start, 0, maxi(options.size() - 1, 0))
	add_theme_constant_override("separation", 6)
	var prev := IconButton.new("chevron_left", 36)
	prev.pressed.connect(_step.bind(-1))
	add_child(prev)
	_label = UiTheme.make_label("", UiTheme.heading(21, UiTheme.TEXT, 700, 2))
	_label.custom_minimum_size = Vector2(label_width, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_label)
	var next := IconButton.new("chevron_right", 36)
	next.pressed.connect(_step.bind(1))
	add_child(next)
	_update()


func _step(d: int) -> void:
	if options.is_empty():
		return
	index = posmod(index + d, options.size())
	_update()
	changed.emit(index)


func _update() -> void:
	_label.text = UiTheme.caps(String(options[index])) if not options.is_empty() else ""
