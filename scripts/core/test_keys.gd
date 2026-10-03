class_name TestKeys
extends Node
## Test shortcuts for trying the game out (Settings.test_shortcuts; off, none of them do
## anything): F6 held runs the clock FAST times faster (GameClock.fast_forward, a small
## pill on screen while it does), F7 skips to the next morning (06:00) the way sleeping
## does (SleepScreen.start_sleep: the night's simulations, the wolves, the crops, the
## morning report and the autosave), F8 moves the clock on an hour. Only while playing:
## not on the title screen, over a window or while a game loads. Made by DebugTools.

const FAST := 30.0

var _hint: PanelContainer
var _hint_text: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hint()


## The shortcuts work now: switched on, a game under way, no window open.
static func active() -> bool:
	if not Settings.test_shortcuts or SaveGame.loading or Game.is_ui_open():
		return false
	var player := Game.player as Player
	return player != null and is_instance_valid(player) and Game.hud != null


func _process(_delta: float) -> void:
	var fast := active() and Input.is_action_pressed(&"test_time_fast") and GameClock.running
	var want := FAST if fast else 1.0
	if GameClock.fast_forward != want:
		GameClock.fast_forward = want
	if _hint.visible != fast:
		# (in the language of the moment: it can change while the game runs)
		_hint_text.text = tr("TEST_FAST_HINT") % int(FAST)
		_hint.visible = fast


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.is_echo() or not active():
		return
	if event.is_action_pressed(&"test_skip_night"):
		get_viewport().set_input_as_handled()
		skip_to_morning()
	elif event.is_action_pressed(&"test_plus_hour"):
		get_viewport().set_input_as_handled()
		plus_hour()


## F7: to bed and on to 06:00, as sleeping goes (out of a vehicle first).
func skip_to_morning() -> void:
	var hud := Game.hud as HUD
	if hud == null or hud.sleep_screen.is_busy():
		return
	var player := Game.player as Player
	if player and player.driving:
		player.exit_vehicle()
	hud.sleep_screen.start_sleep()


## F8: the clock an hour on (the simulations get the hour as one tick).
func plus_hour() -> void:
	GameClock.advance(60.0)
	Game.notify(tr("MSG_TEST_HOUR") % GameClock.time_string(), UiTheme.TEXT_MUTED)


## A small pill at the top of the screen while F6 runs the clock fast.
func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_hint = PanelContainer.new()
	var sb := UiTheme.box(Color(0.05, 0.06, 0.05, 0.62), 16, 1, Color(UiTheme.GOLD, 0.55))
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_hint.add_theme_stylebox_override("panel", sb)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = 132.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(row)
	row.add_child(UiTheme.icon_rect(UiTheme.glyph("chevrons_right"), 20.0, UiTheme.GOLD_SOFT))
	_hint_text = UiTheme.make_label("", UiTheme.heading(18, UiTheme.GOLD_SOFT, 700, 1))
	row.add_child(_hint_text)
	_hint.visible = false
	layer.add_child(_hint)
