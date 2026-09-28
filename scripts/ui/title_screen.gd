class_name TitleScreen
extends ModalScreen
## Title screen over the live farm, filmed by a slowly circling camera: continue the
## latest save, a new game, load, settings, quit, and the asset credits.

const ORBIT_CENTER := Vector3(18, 0, -6)
const ORBIT_RADIUS := 52.0
const ORBIT_HEIGHT := 17.0

var _camera: Camera3D
var _angle := 2.2
var _buttons: VBoxContainer


func _ready() -> void:
	ui_name = &"title"
	close_actions = []
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.025, 0.02, 0.88))
	grad.set_color(1, Color(0.02, 0.025, 0.02, 0.0))
	grad.add_point(0.45, Color(0.02, 0.025, 0.02, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 130)
	margin.add_theme_constant_override("margin_right", 130)
	margin.add_theme_constant_override("margin_top", 150)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	panel = col
	col.add_child(UiTheme.logo(128))
	col.add_child(UiTheme.spacer(70))
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	col.add_child(_buttons)
	_fill_buttons()
	col.add_child(UiTheme.expand())
	var credits := UiTheme.paragraph(tr("UI_CREDITS"), 14, Color(1, 1, 1, 0.45), 900)
	col.add_child(credits)
	set_process(false)


## Continue appears once there is a save to continue.
func _fill_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	var latest := SaveGame.latest()
	var specs: Array = []
	# Back from the pause menu the game in progress comes first; on a fresh launch,
	# the latest save.
	if SaveGame.started:
		specs.append(["UI_BACK_TO_GAME", "primary", "play", _play])
	elif latest != "":
		specs.append(["UI_CONTINUE", "primary", "play", SaveGame.load_game.bind(latest)])
	specs.append(["UI_NEW_GAME", "primary" if specs.is_empty() else "secondary", "sparkles", _new_game])
	if latest != "":
		specs.append(["UI_LOAD_GAME", "secondary", "folder", func() -> void: Game.hud.open_saves("load")])
	specs.append(["SETTINGS_TITLE", "secondary", "gear", func() -> void: Game.hud.open_settings()])
	specs.append(["UI_QUIT", "ghost", "exit", func() -> void: Game.quit_game()])
	for spec: Array in specs:
		var b := UiTheme.button(tr(spec[0]), spec[1], Vector2(420, 64), spec[2], 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(spec[3])
		_buttons.add_child(b)


## A fresh launch already shows a new farm; later ones rebuild it (after asking).
## Either way the story opens with Grandpa's letter.
func _new_game() -> void:
	if not SaveGame.started:
		SaveGame.started = true
		await _play()
		if not DebugTools.is_automated():
			Game.hud.letter_screen.open("intro")
		return
	Game.hud.confirm_dialog.ask(tr("UI_NEW_GAME"), tr("UI_UNSAVED_TEXT"), tr("UI_NEW_GAME"), SaveGame.new_game)


func show_title() -> void:
	if visible:
		return
	_fill_buttons()
	if Game.world:
		_camera = Camera3D.new()
		_camera.fov = 55.0
		_camera.far = 800.0
		# Moved every frame in _process, not on physics ticks.
		_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		Game.world.add_child(_camera)
		_update_camera(0.0)
		_camera.make_current()
	set_process(true)
	show_screen()


func _process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	_angle += delta * 0.035
	var pos := ORBIT_CENTER + Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_angle) * ORBIT_RADIUS)
	_camera.global_position = pos
	_camera.look_at(ORBIT_CENTER + Vector3(0, 2.5, 0), Vector3.UP)


func _play() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	await tw.finished
	var player := Game.player as Player
	if player:
		# Mid-drive the view is the vehicle's: the player's own camera is not placed then.
		(player.driving._current_camera() if player.driving else player.camera).make_current()
	if _camera:
		_camera.queue_free()
		_camera = null
	hide_screen()
	modulate.a = 1.0
