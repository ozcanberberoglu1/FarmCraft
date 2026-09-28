class_name ModalScreen
extends Control
## Base for full-screen menus: blurred, darkened backdrop, a centred UiWindow, the
## UI stack (frees the mouse and pauses the clock), an open animation and closing
## with Esc or the screen's other `close_actions`.

var window: UiWindow
## What opens with the fade/scale animation (the window, or a custom layout).
var panel: Control
var ui_name: StringName = &"modal"
var close_actions: Array[StringName] = [&"pause"]


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Creates the centred window (call from _ready of the screen).
func make_window(title: String, icon_name := "", subtitle := "") -> UiWindow:
	add_child(UiTheme.backdrop())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	window = UiWindow.new(title, icon_name, subtitle)
	center.add_child(window)
	window.close_requested.connect(hide_screen)
	panel = window
	return window


func is_open() -> bool:
	return visible


func show_screen() -> void:
	if visible:
		return
	visible = true
	Game.push_ui(ui_name)
	Audio.ui("open", -10.0)
	if panel:
		panel.modulate.a = 0.0
		await get_tree().process_frame
		UiTheme.appear(panel)


func hide_screen() -> void:
	if not visible:
		return
	visible = false
	Game.pop_ui(ui_name)
	Audio.ui("close", -12.0)
	_on_hidden()


## Screens clean up here (containers, callbacks).
func _on_hidden() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for action in close_actions:
		if event.is_action_pressed(action):
			hide_screen()
			get_viewport().set_input_as_handled()
			return
