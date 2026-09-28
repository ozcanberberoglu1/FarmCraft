extends Node
## Global game state: input actions, mouse capture and the stack of open UI screens.

var player: Node3D = null
var world: Node3D = null
var hud: CanvasLayer = null

var _ui_stack: Array[StringName] = []


func _init() -> void:
	InputSetup.register_actions()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_ui_open() -> bool:
	return not _ui_stack.is_empty()


func top_ui() -> StringName:
	return _ui_stack.back() if not _ui_stack.is_empty() else &""


## A rebuilt game scene starts with no screens open.
func reset_ui() -> void:
	_ui_stack.clear()


func push_ui(ui_name: StringName) -> void:
	if ui_name in _ui_stack:
		return
	_ui_stack.push_back(ui_name)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.ui_opened.emit(ui_name)


func pop_ui(ui_name: StringName) -> void:
	if ui_name not in _ui_stack:
		return
	_ui_stack.erase(ui_name)
	Events.ui_closed.emit(ui_name)
	if _ui_stack.is_empty():
		capture_mouse()


func capture_mouse() -> void:
	# Automated screenshot runs must never grab the user's mouse.
	if DebugTools.is_automated():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Quits after the sound has stopped (so no playing stream is cut off mid-mix).
func quit_game() -> void:
	Audio.shutdown()
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit()


func notify(text: String, color := Color(1.0, 0.85, 0.3)) -> void:
	Events.notification_requested.emit(text, color)
	if color.is_equal_approx(UiTheme.RED) or (color.r > 0.9 and color.g < 0.62 and color.b < 0.5):
		Audio.ui("error", -10.0)
