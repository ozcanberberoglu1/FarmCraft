class_name SwitchToggle
extends Control
## On/off switch: a pill track (gold when on) with a sliding knob.

signal toggled(on: bool)

var on := false
var _t := 0.0


func _init(start := false) -> void:
	on = start
	_t = 1.0 if start else 0.0
	custom_minimum_size = Vector2(64, 34)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE


func set_on(value: bool) -> void:
	on = value
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on = not on
		set_process(true)
		toggled.emit(on)
		Audio.ui("toggle", -8.0)
		accept_event()


func _process(delta: float) -> void:
	_t = move_toward(_t, 1.0 if on else 0.0, delta * 7.0)
	queue_redraw()
	if is_equal_approx(_t, 1.0 if on else 0.0):
		set_process(false)


func _draw() -> void:
	var h := 30.0
	var y := (size.y - h) * 0.5
	var track := UiTheme.box(Color(1, 1, 1, 0.12).lerp(Color(UiTheme.GOLD, 0.95), _t), int(h * 0.5), 1,
			Color(1, 1, 1, 0.18).lerp(Color("f9d98b"), _t))
	draw_style_box(track, Rect2(0, y, size.x, h))
	var r := h * 0.5 - 4.0
	var x := lerpf(h * 0.5, size.x - h * 0.5, _t)
	draw_circle(Vector2(x, y + h * 0.5 + 1.0), r, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(x, y + h * 0.5), r, Color.WHITE)
