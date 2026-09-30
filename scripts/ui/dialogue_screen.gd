class_name DialogueScreen
extends Control
## A conversation with someone in town, at the bottom centre of the screen: a frosted
## glass panel with the speaker's name over the line, typed out quickly, and a key cap
## saying how to go on (E, the left mouse button or Space; a press while a line is
## still typing shows it whole). Esc skips to the end. The world goes on while it is
## open (the person keeps moving, a door keeps swinging) but the player stands still:
## it is on Game's UI stack like the other screens, which stops walking and mouse look,
## and the view eases round to the one speaking (`focus`).
##
## Lines are {who: &"player" or a person's id (PERSON_<ID> names them), text: the
## translated line, cue: a Callable run as the line comes up (optional)}.

## A line came up (its index in the conversation).
signal line_started(index: int)
## The conversation is over (read to the end or skipped).
signal finished

const UI_NAME := &"dialogue"
const CHARS_PER_SECOND := 60.0
const WIDTH := 940.0
## Space under the panel (the hotbar hides while a screen is open).
const BOTTOM := 64.0
const PLAYER := &"player"
## Colours of the names: the player's own and the other speaker's.
const PLAYER_COLOR := Color("9fd3f0")
const OTHER_COLOR := UiTheme.GOLD_SOFT
## How quickly the view turns to the one speaking (per second, exponential).
const FOCUS_RATE := 5.0

var lines: Array[Dictionary] = []
var index := -1
## Where the view turns while it is open: a Node3D (its head height: eye_point() when it
## has one) or a Vector3; null leaves the view as it is.
var focus: Variant = null

var _on_done := Callable()
var _shown := 0.0
var _panel: GlassPanel
var _name: Label
var _text: Label
var _next: HBoxContainer
var _shade: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# A soft darkening at the foot of the screen, so the panel reads over a bright day.
	_shade = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 128
	_shade.texture = tex
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.place(_shade, Vector2(0.0, 1.0), Vector2(0, -330), Vector2(0, 330))
	_shade.anchor_right = 1.0
	_shade.offset_right = 0.0
	add_child(_shade)
	_panel = GlassPanel.new(Vector4(34, 20, 34, 22), 20.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -WIDTH * 0.5
	_panel.offset_right = WIDTH * 0.5
	_panel.offset_bottom = -BOTTOM
	_panel.offset_top = -BOTTOM
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_name = UiTheme.make_label("", UiTheme.heading(20, OTHER_COLOR, 700, 3))
	col.add_child(_name)
	_text = UiTheme.make_label("", UiTheme.text(25, UiTheme.TEXT, 600))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 68.0, 64)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_text)
	_next = HBoxContainer.new()
	_next.add_theme_constant_override("separation", 8)
	_next.alignment = BoxContainer.ALIGNMENT_END
	_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next.add_child(UiTheme.keycap("E", 16))
	var go := UiTheme.make_label(UiTheme.caps(tr("DIALOGUE_NEXT")), UiTheme.heading(16, UiTheme.TEXT_MUTED, 700, 2))
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next.add_child(go)
	col.add_child(_next)


func is_open() -> bool:
	return visible


## Opens the conversation `talk` (see the class notes); `on_done` runs when it is over.
func open(talk: Array, on_done := Callable(), look_at: Variant = null) -> void:
	lines.clear()
	for l: Dictionary in talk:
		lines.append(l)
	if lines.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_on_done = on_done
	focus = look_at
	index = -1
	visible = true
	Game.push_ui(UI_NAME)
	# The cursor stays hidden: this is a conversation, not a window to click about in.
	Game.capture_mouse()
	_panel.modulate.a = 0.0
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	_next_line()


## Goes on: shows the rest of a line still typing, else the next line (or ends).
func advance() -> void:
	if not visible:
		return
	if _text.visible_characters >= 0 and _text.visible_characters < _text.get_total_character_count():
		_shown = float(_text.get_total_character_count())
		_text.visible_characters = -1
		return
	Audio.ui("click", -16.0)
	_next_line()


## Ends the conversation now; the lines' cues not reached yet still run, in order, so
## whatever they start (a gift handed over) isn't lost.
func skip() -> void:
	if not visible:
		return
	while index + 1 < lines.size():
		index += 1
		_run_cue(index)
	_close()


## The line on screen now ("" when closed).
func current_text() -> String:
	return String(lines[index]["text"]) if visible and index >= 0 and index < lines.size() else ""


func current_speaker() -> StringName:
	return StringName(lines[index].get("who", &"")) if visible and index >= 0 and index < lines.size() else &""


func _next_line() -> void:
	index += 1
	if index >= lines.size():
		_close()
		return
	var l: Dictionary = lines[index]
	var who := StringName(l.get("who", PLAYER))
	var mine := who == PLAYER
	_name.text = UiTheme.caps(tr("DIALOGUE_YOU") if mine else tr("PERSON_" + String(who).to_upper()))
	_name.label_settings = UiTheme.heading(20, PLAYER_COLOR if mine else OTHER_COLOR, 700, 3)
	_text.text = String(l.get("text", ""))
	_shown = 0.0
	_text.visible_characters = 0
	_run_cue(index)
	line_started.emit(index)


func _run_cue(i: int) -> void:
	var cue: Variant = lines[i].get("cue")
	if cue is Callable and (cue as Callable).is_valid():
		(cue as Callable).call()


func _close() -> void:
	visible = false
	index = -1
	focus = null
	Game.pop_ui(UI_NAME)
	var done := _on_done
	_on_done = Callable()
	finished.emit()
	if done.is_valid():
		done.call()


func _process(delta: float) -> void:
	if not visible:
		return
	var total := _text.get_total_character_count()
	if _text.visible_characters >= 0:
		_shown += delta * CHARS_PER_SECOND
		_text.visible_characters = -1 if _shown >= total else int(_shown)
	_next.modulate.a = 1.0 if _text.visible_characters < 0 else 0.35
	_turn_view(delta)


## Eases the player's view round to the one speaking.
func _turn_view(delta: float) -> void:
	var player := Game.player as Player
	if player == null or player.driving != null or focus == null:
		return
	var at := Vector3.INF
	if focus is Vector3:
		at = focus
	elif focus is Node3D and is_instance_valid(focus) and (focus as Node3D).is_inside_tree():
		var n := focus as Node3D
		var rig: Variant = n.get("rig")
		if rig is HumanRig and is_instance_valid(rig):
			at = (rig as HumanRig).to_global((rig as HumanRig).eye_point())
		else:
			at = n.global_position + Vector3(0, 1.5, 0)
	if not at.is_finite():
		return
	var eye := player.camera.global_position
	var d := at - eye
	if Vector2(d.x, d.z).length() < 0.2:
		return
	var yaw := atan2(-d.x, -d.z)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-40.0), deg_to_rad(40.0))
	var k := 1.0 - exp(-delta * FOCUS_RATE)
	var cur_yaw := player.rotation.y
	var cur_pitch := player.head.rotation.x
	player.look_at_yaw_pitch(cur_yaw + wrapf(yaw - cur_yaw, -PI, PI) * k, lerpf(cur_pitch, pitch, k))


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("use"):
		advance()
		get_viewport().set_input_as_handled()
