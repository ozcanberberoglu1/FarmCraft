class_name Player
extends CharacterBody3D
## First-person farmer: movement, mouse look, head bob, the interaction ray and the
## hold-to-use tool actions (their strokes, impacts and view punch).
##
## Interactables are nodes in the "interactable" group (or a parent of the hit
## collider up to 4 levels) that implement:
##   interact_prompt(player) -> String   verb shown as "E (VERB)"; "" = none
##   interact(player)                    called when E is pressed
## and optionally info_prompt() -> String ("F (...)") with info_interact(player) for F,
## interact_title() -> String (a name line over the prompts), hint_prompt() -> String
## (a plain line under the prompt, no key) and set_highlight(on)
## (driven by the use prompt, or always while aimed at for the "look_highlight" group).
## Hold-to-use targets implement use_prompt/use_action/complete_use and optionally
## can_start(action, stack) and use_impact(player, stack, action, hit): the cosmetic
## side of each tool stroke landing (hit: "stroke", "final", "point", "normal").

signal target_changed(target: Node)
signal footstep
## A tool stroke landed on the action's target (is_final: the gameplay effect happened).
signal tool_impact(action_id: String, stroke: int, is_final: bool)

## Seconds between prompt rebuilds while the target stays the same (its state may change).
const PROMPT_REFRESH := 0.1
## View punch spring (camera only; the aim ray sits on Head, so the target never moves):
## stiffness, damping (peaks ~70 ms after the hit, settled by ~0.4 s) and the impulse per
## degree (metre for the dip) of peak.
const KICK_K := 240.0
const KICK_C := 21.0
const KICK_GAIN := 33.0
## Shake at full trauma (degrees: pitch, yaw, roll); trauma fades at TRAUMA_FADE per second.
const SHAKE_DEG := Vector3(2.0, 2.0, 3.0)
const TRAUMA_FADE := 2.4

@export var walk_speed := 4.3
@export var sprint_speed := 7.0
@export var acceleration := 10.0
@export var air_control := 0.3
@export var jump_velocity := 4.8
@export var reach := 3.2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/InteractRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var target: Node = null
var held: HeldItem
## Placement preview while a placeable is in hand.
var placer: Placer
## The horse being ridden, if any.
var riding: Animal = null
## The vehicle being driven, if any.
var driving: Vehicle = null
## Physics frames left before collisions come back after getting out of a vehicle.
var _exit_frames := 0
var _ride_saved := {}

# Hold-to-use action state (hoeing, planting, watering, harvesting...).
var _action := {}
var _action_target: Node = null
var _action_stack: ItemStack = null
var _action_elapsed := 0.0
var _use_was_down := false
## The action's cue timeline (ToolAnim.cues), the next cue to fire and when the final
## stroke lands (the progress bar fills up to it).
var _cues: Array = []
var _next_cue := 0
var _final_time := 1.0
## The final stroke has landed: the rest of the action is follow-through.
var _committed := false
## The action's ToolAnim profile.
var _anim: StringName = &""
## The watering can's pour sound while it runs.
var _pour_sfx: Node = null
# View punch (pitch, yaw, roll in degrees, dip in metres) and shake.
var _kick := Vector4.ZERO
var _kick_v := Vector4.ZERO
var _trauma := 0.0
var _shake_t := 0.0

var _pitch := 0.0
var _bob_phase := 0.0
var _bob_amount := 0.0
## Head bob offset in camera space.
var _bob := Vector3.ZERO
## Sprint held on the last physics tick (widens the view).
var _sprinting := false
var _last_step_sign := 1.0
var _last_prompt := PackedStringArray()
var _prompt_timer := 0.0


func _ready() -> void:
	# Moved in physics ticks: drawn between ticks (see Settings._ready).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	Game.player = self
	ray.target_position = Vector3(0, 0, -reach)
	ray.add_exception(self)
	# The camera is placed every frame from the interpolated body (see _process), so
	# walking is smooth at any frame rate and mouse look never waits for a physics tick.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = Settings.fov
	held = HeldItem.new()
	held.name = "HeldItem"
	camera.add_child(held)
	placer = Placer.new()
	placer.name = "Placer"
	# Grid-snapped and shown in one jump: interpolating it would only streak it in.
	placer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(placer)
	footstep.connect(func() -> void:
		if riding == null and driving == null:
			Audio.footstep(self, Vector2(velocity.x, velocity.z).length() > walk_speed + 0.5))
	PlayerState.selected_changed.connect(_refresh_prompt.unbind(1))
	PlayerState.inventory.changed.connect(_refresh_prompt)
	Game.capture_mouse()


## Snaps the view. Callers use it right after teleporting the player, so the body is
## not interpolated from where it was.
func look_at_yaw_pitch(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = pitch
	head.rotation.x = pitch
	reset_physics_interpolation()


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_ui_open() or driving:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := Settings.mouse_sensitivity
		rotate_y(-motion.relative.x * sens)
		var dy := motion.relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
		_pitch = clampf(_pitch - dy, deg_to_rad(-88.0), deg_to_rad(88.0))
		head.rotation.x = _pitch
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("animal_info"):
		if target is Animal and not riding:
			Game.hud.open_animal_panel((target as Animal).data)
		elif target and is_instance_valid(target) and target.has_method("info_interact"):
			target.info_interact(self)
	elif event.is_action_pressed("hotbar_next"):
		PlayerState.select(PlayerState.selected + 1)
	elif event.is_action_pressed("hotbar_prev"):
		PlayerState.select(PlayerState.selected - 1)
	elif event.is_action_pressed("rotate") and placer.active:
		placer.rotate_step()
	elif event.is_action_pressed("drop"):
		_drop_selected(Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META))
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Game.capture_mouse()
	else:
		for i in PlayerState.HOTBAR_SIZE:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				PlayerState.select(i)
				break


func _physics_process(delta: float) -> void:
	if driving:
		global_position = driving.driver_eye_global() - Vector3(0, head.position.y, 0)
		velocity = Vector3.ZERO
		_update_prompt()
		return
	if _exit_frames > 0:
		# The physics server moves a teleported kinematic body by sweeping it; with
		# its shape on, the sweep out of the cab would kick the vehicle into the air.
		_exit_frames -= 1
		velocity = Vector3.ZERO
		if _exit_frames == 0:
			($CollisionShape3D as CollisionShape3D).disabled = false
		return
	placer.update(self)
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	var input := Vector2.ZERO
	var can_move := not Game.is_ui_open()
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if on_floor and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	var sprinting := can_move and Input.is_action_pressed("sprint") and input.y < -0.1
	var speed := sprint_speed if sprinting else walk_speed
	var wish := global_basis * Vector3(input.x, 0.0, input.y)
	wish.y = 0.0
	wish = wish.normalized() * speed * minf(input.length(), 1.0)
	var control := 1.0 if on_floor else air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(wish, clampf(acceleration * control * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	if riding:
		_update_riding(delta)
	_sprinting = sprinting
	_update_target(delta)
	_update_action(delta)


## Places the camera at the interpolated eye with the current look, the view punch and
## shake on top (the vehicle's camera is used while driving).
func _process(delta: float) -> void:
	if driving:
		return
	_update_view_effects(delta)
	_update_kick(delta)
	var look := global_basis * head.basis
	var jolt := _jolt()
	if jolt != Vector3.ZERO:
		look = look * Basis.from_euler(jolt)
	var eye := get_global_transform_interpolated().origin + global_basis * head.position + look * (_bob + Vector3(0, _kick.w, 0))
	camera.global_transform = Transform3D(look, eye)


## Punches the view (pitch, yaw, roll in degrees and a dip in metres at its peak) and adds
## shake (0..1); both scaled by Settings.camera_shake.
func kick_view(kick: Vector4, trauma := 0.0) -> void:
	_kick_v += kick * KICK_GAIN * Settings.camera_shake
	add_trauma(trauma)


## Shakes the view (a tree landing nearby, a heavy blow); 1 is the most.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount * Settings.camera_shake, 0.0, 1.0)


## The punch spring, sub-stepped so it stays steady at low frame rates.
func _update_kick(delta: float) -> void:
	if _trauma <= 0.0 and _kick == Vector4.ZERO and _kick_v == Vector4.ZERO:
		return
	var left := minf(delta, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_kick_v += (-_kick * KICK_K - _kick_v * KICK_C) * h
		_kick += _kick_v * h
		left -= h
	if _kick.length_squared() < 1e-8 and _kick_v.length_squared() < 1e-6:
		_kick = Vector4.ZERO
		_kick_v = Vector4.ZERO
	_trauma = maxf(_trauma - delta * TRAUMA_FADE, 0.0)
	_shake_t += delta


## The camera's turn from the punch and the shake (radians: pitch, yaw, roll).
func _jolt() -> Vector3:
	var r := Vector3(_kick.x, _kick.y, _kick.z)
	var sh := _trauma * _trauma
	if sh > 0.0:
		var t := _shake_t
		var j := Vector3(sin(t * 113.0) + sin(t * 71.0 + 1.3), sin(t * 127.0 + 2.1) + sin(t * 83.0),
				sin(t * 97.0 + 0.7) + sin(t * 59.0 + 2.9)) * 0.5
		r += j * SHAKE_DEG * sh
	return r * (PI / 180.0)


func _update_view_effects(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and speed > 0.5
	_bob_amount = lerpf(_bob_amount, 1.0 if moving else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	_bob_phase += delta * speed * 1.9
	var wave := sin(_bob_phase * 2.0)
	_bob = Vector3(cos(_bob_phase) * 0.022, wave * 0.035, 0.0) * _bob_amount
	if moving and signf(wave) != _last_step_sign and wave < 0.0:
		footstep.emit()
	_last_step_sign = signf(wave)
	var target_fov := Settings.fov + (6.0 if _sprinting and speed > 5.0 else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 6.0, 0.0, 1.0))


# --- Interaction -----------------------------------------------------------------

## The ray is cast here only (it is disabled so the engine doesn't cast it again).
## The prompt is rebuilt when the target or the hand changes, else every PROMPT_REFRESH.
func _update_target(delta: float) -> void:
	var new_target: Node = null
	if not Game.is_ui_open():
		ray.force_raycast_update()
		if ray.is_colliding():
			new_target = _find_interactable(ray.get_collider())
	if new_target != target:
		if target and is_instance_valid(target) and target.has_method("set_highlight"):
			target.set_highlight(false)
		target = new_target
		target_changed.emit(target)
		_prompt_timer = 0.0
	_prompt_timer -= delta
	if _prompt_timer <= 0.0:
		_prompt_timer = PROMPT_REFRESH
		_update_prompt()


## Rebuilds the prompt on the next physics tick.
func _refresh_prompt() -> void:
	_prompt_timer = 0.0


static func _find_interactable(node: Object) -> Node:
	var n := node as Node
	for i in 4:
		if n == null:
			return null
		if n.is_in_group(&"interactable"):
			return n
		n = n.get_parent()
	return null


func _update_prompt() -> void:
	var lines := PackedStringArray()
	if driving:
		# The dashboard lists the driving keys (E included).
		if lines != _last_prompt:
			_last_prompt = lines
			Events.interaction_prompt_changed.emit(lines)
		return
	if riding:
		lines.append("%s (%s)" % [tr("KEY_E"), tr("ACTION_DISMOUNT")])
		if lines != _last_prompt:
			_last_prompt = lines
			Events.interaction_prompt_changed.emit(lines)
		return
	if placer.active:
		# A building kit (the coop) is built there, anything else is placed.
		lines.append("%s (%s)" % [tr("KEY_LMB"), tr("ACTION_BUILD" if placer.is_building() else "ACTION_PLACE")])
		lines.append("R (%s)" % tr("ACTION_ROTATE"))
		if not placer.valid:
			lines.append(tr(placer.reason))
		if lines != _last_prompt:
			_last_prompt = lines
			Events.interaction_prompt_changed.emit(lines)
		return
	var stack := PlayerState.selected_stack()
	var can_use := false
	if target and is_instance_valid(target) and target.has_method("use_prompt"):
		var use_verb: String = target.use_prompt(self, stack)
		if use_verb != "":
			lines.append("%s (%s)" % [tr("KEY_LMB"), use_verb])
			can_use = true
	if target and is_instance_valid(target) and target.has_method("set_highlight"):
		target.set_highlight(can_use or target.is_in_group(&"look_highlight"))
	if target and is_instance_valid(target) and target.has_method("interact_title"):
		# The thing's name over its prompts (the tutorial table's tools).
		var title: String = target.interact_title()
		if title != "":
			lines.insert(0, HUD.TITLE_MARK + title)
	if target and is_instance_valid(target) and target.has_method("interact_prompt"):
		var verb: String = target.interact_prompt(self)
		if verb != "":
			lines.append("%s (%s)" % [tr("KEY_E"), verb])
	if target and is_instance_valid(target) and target.has_method("info_prompt"):
		var info: String = target.info_prompt()
		if info != "":
			lines.append("%s (%s)" % [tr("KEY_F"), info])
	if target and is_instance_valid(target) and target.has_method("hint_prompt"):
		# A plain line (no key): the HUD draws it without a key cap.
		var hint: String = target.hint_prompt()
		if hint != "":
			lines.append(hint)
	if lines != _last_prompt:
		_last_prompt = lines
		Events.interaction_prompt_changed.emit(lines)


# --- Hold-to-use actions ----------------------------------------------------------------

## Hold LMB on a target to run its action. The action plays as one ToolAnim timeline on
## the action clock: the gameplay effect, its sound, particles and the camera kick land
## together on the final stroke's impact tick, and the rest of the duration is committed
## follow-through, so every action keeps its length.
func _update_action(delta: float) -> void:
	var down := Input.is_action_pressed("use") and not Game.is_ui_open() and riding == null
	var pressed_now := down and not _use_was_down
	_use_was_down = down
	if placer.active:
		if not _action.is_empty():
			_end_action(_committed)
		if pressed_now:
			placer.place()
		return
	var stack := PlayerState.selected_stack()
	if not _action.is_empty():
		# Until the final stroke lands the button must stay down on the same target with the
		# same item; after that the follow-through always plays out.
		if not _committed and not (down and target == _action_target and stack == _action_stack and is_instance_valid(_action_target)):
			_end_action(false)
			return
		_action_elapsed += delta
		while not _action.is_empty() and _next_cue < _cues.size() and _action_elapsed >= float((_cues[_next_cue] as Array)[0]):
			_next_cue += 1
			_fire_cue(_cues[_next_cue - 1])
		if _action.is_empty():
			return
		if not _committed:
			Events.action_progress_updated.emit(clampf(_action_elapsed / _final_time, 0.0, 1.0))
		elif _action_elapsed >= float(_action["duration"]):
			_end_action(true)
		return
	if not down:
		return
	var info: Dictionary = {}
	if target and is_instance_valid(target) and target.has_method("use_action") and stack:
		info = target.use_action(self, stack)
	if info.is_empty():
		if pressed_now and stack and not held.busy() and stack.item.category != "animal":
			_swing_at_nothing(stack)
		return
	if info.get("wear", false) and stack.item.has_durability() and stack.durability <= 0:
		if pressed_now:
			Game.notify(tr("MSG_TOOL_BROKEN") % stack.item.display_name(), Color(1.0, 0.45, 0.35))
		return
	if target.has_method("can_start"):
		var refusal: String = target.can_start(info, stack)
		if refusal != "":
			if pressed_now:
				Game.notify(refusal, Color(1.0, 0.6, 0.4))
			return
	if stack.item.is_tool() and stack.upgrade > 0:
		info = info.duplicate()
		info["duration"] = float(info["duration"]) * stack.speed_factor()
	_action = info
	_action_target = target
	_action_stack = stack
	_action_elapsed = 0.0
	_committed = false
	var dur := float(info["duration"])
	var anim := ToolAnim.resolve(String(info.get("id", "")), stack)
	_anim = anim[0]
	var strokes := ToolAnim.strokes_for(int(anim[1]), dur)
	_cues = ToolAnim.cues(_anim, strokes, dur)
	_next_cue = 0
	_final_time = dur
	for c: Array in _cues:
		if c[1] == &"final":
			_final_time = maxf(float(c[0]), 0.01)
	held.play(_anim, dur, strokes)
	Events.action_progress_started.emit(tr(info.get("label", "")), _final_time)


## A swing at nothing: the tool's own stroke (a push for other items) and its swoosh.
func _swing_at_nothing(stack: ItemStack) -> void:
	var tool := stack.item.tool_type
	var profile: StringName = ToolAnim.TOOL_PROFILES.get(tool, &"work")
	var length: float = ToolAnim.AIR.get(tool, 0.35)
	held.play(profile, length, 1, false)
	var impact := ToolAnim.impact_u(profile)
	var p: Dictionary = ToolAnim.PROFILES[profile]
	if p.get("whoosh", false) and impact > 0.0:
		get_tree().create_timer(maxf(length * impact - ToolAnim.WHOOSH_LEAD, 0.0), false, true).timeout.connect(
				func() -> void: Audio.swing(tool, camera.global_position - camera.global_basis.z * 0.6))


func _fire_cue(cue: Array) -> void:
	var stack := _action_stack
	var id := String(_action.get("id", ""))
	var kind: StringName = cue[1]
	match kind:
		&"whoosh":
			if stack:
				Audio.swing(stack.item.tool_type, camera.global_position - camera.global_basis.z * 0.6)
		&"pour_on":
			held.set_pouring(true)
			Audio.fade_out(_pour_sfx)
			_pour_sfx = Audio.action_started(id, _sound_spot(_action_target))
		&"pour_off":
			held.set_pouring(false)
			Audio.fade_out(_pour_sfx)
			_pour_sfx = null
		&"release":
			var from := held.mouth_global()
			var aim := _impact_point()
			Fx.seed_scatter(from, aim[0], ToolAnim.SEED_FLIGHT, _scatter_color(stack))
			Audio.impact(id, from)
		&"hit", &"final":
			var is_final: bool = kind == &"final"
			var aim := _impact_point()
			var p: Dictionary = ToolAnim.PROFILES.get(_anim, {})
			var kick: Vector4 = p.get("kick", Vector4.ZERO)
			kick_view(kick * (1.0 if is_final else 0.7), float(p.get("trauma", 0.0)) * (1.0 if is_final else 0.5))
			if is_instance_valid(_action_target) and _action_target.has_method("use_impact"):
				_action_target.use_impact(self, stack, _action,
						{"stroke": int(cue[2]), "final": is_final, "point": aim[0], "normal": aim[1]})
			tool_impact.emit(id, int(cue[2]), is_final)
			if is_final:
				_land_action(stack)
			else:
				Audio.impact(id, aim[0])


## The final stroke landed: the effect happens on this tick; the rest of the action's
## duration is follow-through (no other action starts before it ends).
func _land_action(stack: ItemStack) -> void:
	var t := _action_target
	var a := _action
	var id := String(a.get("id", ""))
	_committed = true
	Events.action_progress_finished.emit(true)
	_refresh_prompt()
	if not is_instance_valid(t):
		return
	if a.get("wear", false):
		wear_tool(stack)
	Audio.action_done(id, _sound_spot(t), t)
	t.complete_use(self, stack, a)
	Events.action_done.emit(id, t)


## Where the stroke lands and the surface's normal: the aim point on the action's
## target, else in front of the target.
func _impact_point() -> Array:
	ray.force_raycast_update()
	if ray.is_colliding() and _find_interactable(ray.get_collider()) == _action_target:
		return [ray.get_collision_point(), ray.get_collision_normal()]
	var p := global_position - global_basis.z + Vector3(0, 0.8, 0)
	if is_instance_valid(_action_target) and _action_target is Node3D:
		p = (_action_target as Node3D).global_position + Vector3(0, 0.5, 0)
	return [p, (camera.global_position - p).normalized()]


## What thrown seeds, feed or fertilizer look like.
static func _scatter_color(stack: ItemStack) -> Color:
	if stack == null:
		return Color(0.55, 0.42, 0.25)
	match stack.item.id:
		&"fertilizer":
			return Color(0.82, 0.81, 0.76)
		&"manure":
			return Color(0.26, 0.19, 0.11)
		&"hay", &"feed":
			return Color(0.78, 0.66, 0.36)
	var crop: Color = ItemModels.CROP_COLORS.get(stack.item.crop_id, Color(0.55, 0.42, 0.25))
	return Color(0.52, 0.4, 0.24).lerp(crop, 0.25)


## Seconds into the running action, between physics ticks too (the view model follows
## it exactly); -1 when there is none.
func action_clock() -> float:
	if _action.is_empty():
		return -1.0
	# The step the clock advances by per tick (Engine.time_scale included).
	return _action_elapsed + Engine.get_physics_interpolation_fraction() * get_physics_process_delta_time()


## Where an action on `node` is heard: the node, or just in front of the player.
func _sound_spot(node: Node) -> Vector3:
	if node is Node3D and is_instance_valid(node):
		return (node as Node3D).global_position + Vector3(0, 0.5, 0)
	return global_position - global_basis.z + Vector3(0, 1.0, 0)


func _end_action(completed: bool) -> void:
	var was_committed := _committed
	_action = {}
	_action_target = null
	_action_stack = null
	_cues = []
	_next_cue = 0
	_committed = false
	Audio.fade_out(_pour_sfx)
	_pour_sfx = null
	held.set_pouring(false)
	if not completed:
		held.cancel()
	_refresh_prompt()
	# A landed action already closed its progress bar.
	if not was_committed:
		Events.action_progress_finished.emit(completed)


## Wears a tool down by one use; a tool at zero durability can't be used.
func wear_tool(stack: ItemStack, amount := 1) -> void:
	if stack == null or not stack.item.has_durability():
		return
	stack.durability = maxi(stack.durability - amount, 0)
	if stack.durability == 0:
		Game.notify(tr("MSG_TOOL_BROKEN") % stack.item.display_name(), Color(1.0, 0.45, 0.35))
	PlayerState.inventory.changed.emit()


func _drop_selected(whole_stack: bool) -> void:
	var s := PlayerState.selected_stack()
	if s == null:
		return
	drop_stack(PlayerState.inventory.take_from(PlayerState.selected, s.count if whole_stack else 1))


## Throws a stack into the world in front of the player (a hen in its crate is kept).
func drop_stack(stack: ItemStack) -> void:
	if stack == null:
		return
	if stack.item.category == "animal":
		PlayerState.inventory.add_stack(stack)
		Game.notify(tr("MSG_CANT_DROP_CRATE"))
		return
	var forward := -camera.global_basis.z
	var at := camera.global_position + forward * 0.7 + Vector3(0, -0.3, 0)
	Pickup.spawn(stack, at, (forward * 2.2 + Vector3.UP * 1.2) * 0.5)


# --- Riding ------------------------------------------------------------------------------

func mount(horse: Animal) -> void:
	if riding or horse.ridden:
		return
	riding = horse
	horse.set_ridden(true)
	global_position = horse.global_position + Vector3(0, 0.05, 0)
	rotation.y = horse.rotation.y
	reset_physics_interpolation()
	var capsule := ($CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D
	_ride_saved = {"walk": walk_speed, "sprint": sprint_speed, "head": head.position, "radius": capsule.radius}
	walk_speed = 4.6
	sprint_speed = 11.0
	# Eyes above the saddle seat, a little ahead of the horse's centre.
	head.position = Vector3(0, 2.45, -0.38)
	capsule.radius = 0.55
	_end_action(false)
	held.set_stowed(true)
	Audio.animal_voice(&"horse", true, horse.global_position, -4.0)
	Game.notify(tr("MSG_MOUNTED") % horse.data.name, Color(0.55, 1.0, 0.45))


func dismount() -> void:
	if riding == null:
		return
	var horse := riding
	riding = null
	var capsule := ($CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D
	walk_speed = _ride_saved.get("walk", walk_speed)
	sprint_speed = _ride_saved.get("sprint", sprint_speed)
	head.position = _ride_saved.get("head", Vector3(0, 1.62, 0))
	capsule.radius = _ride_saved.get("radius", 0.35)
	held.set_stowed(false)
	horse.global_position = global_position
	horse.set_ridden(false)
	# Step off to the left side of the horse.
	var left := -global_basis.x
	global_position += left * 1.15 + Vector3(0, 0.1, 0)
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	_refresh_prompt()


func _update_riding(delta: float) -> void:
	riding.global_position = global_position
	riding.rotation.y = rotation.y
	var speed := Vector2(velocity.x, velocity.z).length()
	var mode := AnimalRig.Mode.IDLE
	if speed > 6.0:
		mode = AnimalRig.Mode.RUN
	elif speed > 0.1:
		mode = AnimalRig.Mode.WALK
	riding.rig.animate(delta, speed, mode)


func enter_vehicle(v: Vehicle) -> void:
	if driving or riding or v.driver:
		return
	driving = v
	_end_action(false)
	velocity = Vector3.ZERO
	visible = false
	($CollisionShape3D as CollisionShape3D).disabled = true
	held.set_stowed(true)
	v.set_driver(self)
	Audio.vehicle_enter(v)
	Game.notify(tr("MSG_ENTERED_VEHICLE") % v.display_name(), UiTheme.GREEN)
	Events.interaction_prompt_changed.emit(PackedStringArray())


func exit_vehicle() -> void:
	if driving == null:
		return
	var v := driving
	var spot := v.exit_point()
	v.set_driver(null)
	Audio.vehicle_exit(v)
	driving = null
	global_position = spot
	# Face the way the vehicle points (its forward is +Z; the player looks along -Z).
	look_at_yaw_pitch(v.global_rotation.y + PI, 0.0)
	visible = true
	# Collisions return once the body has been moved out (see _physics_process).
	_exit_frames = 2
	held.set_stowed(false)
	camera.make_current()
	_last_prompt = PackedStringArray(["-"])
	_refresh_prompt()


## The look of taking an item from the world (the tutorial table's tools, the drawer's
## key): it flies from `from` (its model's world transform, ItemModels.mesh(item_id))
## into the hand when it is the item in hand, else down into its hotbar slot. Only a
## look: call it right after putting the item in the bag, then free the world object.
func show_take(item_id: StringName, from: Transform3D) -> void:
	var slot := -1
	for i in PlayerState.HOTBAR_SIZE:
		var s := PlayerState.inventory.get_stack(i)
		if s and s.item.id == item_id and (slot < 0 or i == PlayerState.selected):
			slot = i
	held.receive(item_id, from, slot >= 0 and slot == PlayerState.selected, slot)


func _interact() -> void:
	if riding:
		dismount()
		return
	if target and is_instance_valid(target) and target.has_method("interact"):
		target.interact(self)
