class_name HeldItem
extends Node3D
## First-person view model of the selected hotbar item: lower-right placement, sway
## that lags behind mouse look, walking bob and the tool strokes of ToolAnim (wind-up,
## strike, impact hold, recovery). A stroke of a hold-to-use action is sampled on the
## player's action clock, so the contact pose lands on the tick the effect happens and
## is always drawn, even when a slow frame steps over it. The watering can pours a
## stream while it is tipped; an item taken from the world flies into the hand.

## Per-item pose in camera space: [position, rotation (deg), scale]
const POSES := {
	&"hoe": [Vector3(0.36, -0.5, -0.56), Vector3(-66, 4, 12), 0.56],
	&"scythe": [Vector3(0.4, -0.5, -0.6), Vector3(-62, -24, 10), 0.55],
	&"pickaxe": [Vector3(0.36, -0.44, -0.52), Vector3(-60, 0, 14), 0.62],
	&"axe": [Vector3(0.36, -0.44, -0.52), Vector3(-60, 0, 14), 0.62],
	&"pitchfork": [Vector3(0.36, -0.52, -0.56), Vector3(-66, 4, 12), 0.54],
	&"watering_can": [Vector3(0.4, -0.42, -0.78), Vector3(2, -72, 0), 0.8],
	&"milk_pail": [Vector3(0.38, -0.48, -0.7), Vector3(0, -20, 0), 0.8],
	&"shears": [Vector3(0.26, -0.28, -0.46), Vector3(-60, 0, 20), 1.0],
	&"brush": [Vector3(0.26, -0.28, -0.46), Vector3(-20, 30, 0), 1.0],
	# Bulky goods are carried lower and further out, on their base.
	&"hay": [Vector3(0.3, -0.44, -0.74), Vector3(8, 25, 0), 0.78],
	&"flour": [Vector3(0.3, -0.46, -0.7), Vector3(6, 25, 0), 0.8],
	&"feed": [Vector3(0.3, -0.46, -0.7), Vector3(6, 25, 0), 0.8],
	&"manure": [Vector3(0.3, -0.46, -0.7), Vector3(6, 25, 0), 0.8],
	&"fertilizer": [Vector3(0.3, -0.46, -0.72), Vector3(8, 25, 0), 0.8],
	&"milk": [Vector3(0.3, -0.46, -0.68), Vector3(4, 25, 0), 0.8],
	&"pumpkin": [Vector3(0.3, -0.44, -0.72), Vector3(8, 25, 0), 0.85],
	# A crate of hens is carried in front with both hands, its long side across the view.
	&"chicken_crate": [Vector3(0.02, -0.46, -0.64), Vector3(4, 90, 0), 0.95],
}
const DEFAULT_POSE := [Vector3(0.25, -0.24, -0.46), Vector3(12, 30, 0), 1.0]
const DEG := PI / 180.0
## Seconds a cut-short stroke takes to ease back to rest.
const CANCEL_BLEND := 0.16
## The watering can's spout tip and pouring direction in its model space (measured on the
## scan; the spout points along +Z).
const SPOUT := Vector3(0.0, 0.217, 0.411)
const SPOUT_DIR := Vector3(0.0, 0.33, 0.94)
## Seconds an item taken from the world flies into the hand or down into the hotbar.
const RECEIVE_TIME := 0.32

var _model: MeshInstance3D
var _item_id: StringName = &""
var _base := Transform3D.IDENTITY
var _sway := Vector2.ZERO
var _last_basis := Basis.IDENTITY
var _time := 0.0
## Put away while riding or driving (the Player sets it through set_stowed).
var stowed := false
# The stroke being played (a ToolAnim profile), its length and stroke count.
var _prof: Dictionary = {}
var _len := 0.0
var _strokes := 1
## Seconds into a stroke that runs on its own clock (a swing at nothing); -1 while it
## follows the player's action clock.
var _local := -1.0
## The last sampled stroke and u (for the impact latch). Kept as a float, not in a
## Vector2: a 32-bit copy of an impact such as 0.58 reads back just below it and would
## latch the contact pose for the rest of the stroke.
var _last_i := -1
var _last_u := -1.0
## The stroke's pose offset now: position (m) and rotation (deg) about the hand.
var _off_pos := Vector3.ZERO
var _off_rot := Vector3.ZERO
## Where a cut-short stroke eases back from, and how far along that is (1 -> 0).
var _from_pos := Vector3.ZERO
var _from_rot := Vector3.ZERO
var _blend := 0.0
var _pour := false
var _pour_w := 0.0
var _stream: CPUParticles3D
## An item taken from the world on its way into the hand (or the hotbar).
var _flight: MeshInstance3D
var _flight_from := Transform3D.IDENTITY
var _flight_to_hand := false
var _flight_slot := -1
var _flight_t := 0.0
## A pose frozen for screenshots (debug_pose): profile and u (-1 = off).
var _debug_prof: StringName = &""
var _debug_u := -1.0


func _ready() -> void:
	_model = MeshInstance3D.new()
	_model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Small clutter: kept out of the rain-blocker heightfield.
	_model.layers = 2
	add_child(_model)
	# Load the scanned tools and their textures with the scene, not on first use.
	for id: StringName in ToolModels.MODELS:
		ItemModels.mesh(id)
	PlayerState.selected_changed.connect(func(_s): _refresh())
	PlayerState.inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var stack := PlayerState.selected_stack()
	var id: StringName = stack.item.id if stack else &""
	if id == _item_id:
		return
	_item_id = id
	_stop_stroke()
	_apply_visibility()
	# Placeables show as the placement preview instead.
	if id == &"" or PlaceableTable.is_placeable(id):
		return
	_model.mesh = ItemModels.mesh(id)
	var pose: Array = POSES.get(id, DEFAULT_POSE)
	var s: float = pose[2]
	_base = Transform3D(Basis.from_euler((pose[1] as Vector3) * DEG).scaled(Vector3.ONE * s), pose[0])
	# Small items are held by their center rather than their origin.
	if not POSES.has(id):
		_base.origin -= _base.basis * _model.mesh.get_aabb().get_center()
	# Bring the new item up from below.
	_sway.y -= 0.35


func _apply_visibility() -> void:
	visible = not stowed and _item_id != &"" and not PlaceableTable.is_placeable(_item_id)


## Puts the item away (riding, driving) or brings it back out.
func set_stowed(on: bool) -> void:
	if on == stowed:
		return
	stowed = on
	if on:
		_stop_stroke()
		_end_flight()
	else:
		_sway.y -= 0.35
	_apply_visibility()


# --- Strokes ----------------------------------------------------------------------------

## Plays a ToolAnim profile: `strokes` strokes over `length` seconds, on the player's
## action clock (`follow_player`) or on its own (a swing at nothing).
func play(profile: StringName, length: float, strokes := 1, follow_player := true) -> void:
	_prof = ToolAnim.PROFILES.get(profile, ToolAnim.PROFILES[&"work"])
	_len = maxf(length, 0.05)
	_strokes = maxi(strokes, 1)
	_local = -1.0 if follow_player else 0.0
	_last_i = -1
	_last_u = -1.0
	# Carries on from wherever a stroke cut short left the item (a new bed mid-swing).
	_from_pos = _off_pos
	_from_rot = _off_rot
	_blend = 1.0 if _off_pos != Vector3.ZERO or _off_rot != Vector3.ZERO else 0.0


## A swing (for tools) or a short push (for other items) on its own clock.
func swing(duration := 0.35) -> void:
	play(&"work", duration, 1, false)


## Cuts the stroke short: the item eases back to rest from wherever it is.
func cancel() -> void:
	set_pouring(false)
	_prof = {}
	_from_pos = _off_pos
	_from_rot = _off_rot
	_blend = 1.0


func busy() -> bool:
	return not _prof.is_empty()


## How far through its stroke the item was last drawn (0..1; -1 before the first frame).
func current_u() -> float:
	return _last_u


## The can's stream on or off (it only shows while the item is in view).
func set_pouring(on: bool) -> void:
	_pour = on
	if on and _stream == null:
		_stream = Fx.make_stream(SPOUT_DIR)
		add_child(_stream)
	if on:
		# Out of the spout for the can, else down out of the item's mouth.
		_stream.direction = SPOUT_DIR if _item_id == &"watering_can" else Vector3.DOWN
		_place_stream(_model.transform)
	if _stream:
		_stream.emitting = on and visible


## Where things leave the item in the world: the can's spout, else the top of the model
## (the mouth of a seed packet or a sack).
func mouth_global() -> Vector3:
	if _model.mesh == null or not visible:
		var cam := get_parent() as Node3D
		return cam.global_transform * Vector3(0.2, -0.25, -0.5) if cam else global_position
	return _model.global_transform * _mouth_local()


func _mouth_local() -> Vector3:
	if _item_id == &"watering_can":
		return SPOUT
	var b := _model.mesh.get_aabb()
	return Vector3(b.get_center().x, b.end.y, b.get_center().z)


func _place_stream(xf: Transform3D) -> void:
	if _stream == null or _model.mesh == null:
		return
	_stream.transform = Transform3D(xf.basis.orthonormalized(), xf * _mouth_local())


## Freezes the item at `u` of a profile's stroke for screenshots (u < 0 lets go).
func debug_pose(profile: StringName, u: float) -> void:
	_debug_prof = profile
	_debug_u = u
	var p: Dictionary = ToolAnim.PROFILES.get(profile, {})
	var pour: Vector2 = p.get("pour", Vector2(2.0, 2.0))
	set_pouring(u >= pour.x and u <= pour.y)


func _stop_stroke() -> void:
	_prof = {}
	_blend = 0.0
	_off_pos = Vector3.ZERO
	_off_rot = Vector3.ZERO
	set_pouring(false)


## The stroke's offset at `t` seconds into the action. The contact pose is latched: a
## frame that would step over it draws it instead.
func _sample(t: float) -> void:
	var stroke := _len / float(_strokes)
	var i := mini(int(t / stroke), _strokes - 1)
	var u := clampf((t - stroke * float(i)) / stroke, 0.0, 1.0)
	var imp := float(_prof.get("impact", -1.0))
	if imp > 0.0 and u > imp and (_last_i != i or _last_u < imp):
		u = imp
	_last_i = i
	_last_u = u
	var pose := ToolAnim.sample(_prof, u)
	_off_pos = pose[0]
	_off_rot = pose[1]


# --- Taking from the world -----------------------------------------------------------

## An item taken from the world flies from `from` (its model's world transform) into the
## hand when it is the item in hand (`to_hand`), else down into hotbar `slot` (-1: the
## bag). Only a look: the caller has already put it in the inventory.
func receive(item_id: StringName, from: Transform3D, to_hand: bool, slot := -1) -> void:
	_end_flight()
	var cam := get_parent() as Node3D
	if cam == null or stowed:
		return
	_flight = MeshInstance3D.new()
	_flight.mesh = ItemModels.mesh(item_id)
	_flight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flight.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_flight.layers = 2
	_flight.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.add_child(_flight)
	_flight_from = from
	_flight_to_hand = to_hand and item_id == _item_id and visible
	_flight_slot = slot
	_flight_t = 0.0
	if _flight_to_hand:
		# The flight replaces the rise from below.
		_model.visible = false
		_sway.y = 0.0
	_update_flight(0.0)


func _update_flight(delta: float) -> void:
	var cam := get_parent() as Node3D
	if not is_instance_valid(_flight) or cam == null:
		_end_flight()
		return
	_flight_t = minf(_flight_t + delta / RECEIVE_TIME, 1.0)
	var u: float = Tween.interpolate_value(0.0, 1.0, _flight_t, 1.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	var a := cam.global_transform.affine_inverse() * _flight_from
	var b := _base if _flight_to_hand else _hotbar_spot()
	# A low arc: up a little on the way, turning and scaling to the pose it ends in.
	var mid := a.origin.lerp(b.origin, 0.5) + Vector3(0, 0.12, 0)
	var p := a.origin.lerp(mid, u).lerp(mid.lerp(b.origin, u), u)
	var q := a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), u)
	var s := a.basis.get_scale().lerp(b.basis.get_scale(), u)
	_flight.transform = Transform3D(Basis(q) * Basis.from_scale(s), p)
	if _flight_t >= 1.0:
		_end_flight()


## Just under the bottom edge of the view, above the item's hotbar slot, tiny.
func _hotbar_spot() -> Transform3D:
	var x := 0.0
	if _flight_slot >= 0:
		x = lerpf(-0.24, 0.24, float(_flight_slot) / float(maxi(PlayerState.HOTBAR_SIZE - 1, 1)))
	return Transform3D(Basis.from_scale(Vector3.ONE * 0.05), Vector3(x, -0.46, -0.5))


func _end_flight() -> void:
	if is_instance_valid(_flight):
		_flight.queue_free()
	_flight = null
	_model.visible = true


# --- Every frame --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _flight != null:
		_update_flight(delta)
	if not visible:
		return
	_time += delta
	var cam := get_parent() as Node3D
	var basis_now := cam.global_basis
	# Sway: how much the view turned since last frame, eased back to rest.
	var turn := _last_basis.inverse() * basis_now
	var euler := turn.get_euler()
	_sway += Vector2(-euler.y, euler.x) * 0.6
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	_sway = _sway.clamp(Vector2(-0.08, -0.4), Vector2(0.08, 0.08))
	_last_basis = basis_now
	var player := Game.player as Player
	var bob := 0.0
	if player and player.is_on_floor():
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		bob = sin(_time * 9.0) * 0.012 * clampf(speed / 4.0, 0.0, 1.5)
	var offset := Vector3(_sway.x, _sway.y + bob + sin(_time * 1.6) * 0.004, 0)
	_update_stroke(delta, player)
	# The can wobbles a little in the hand while it pours.
	_pour_w = move_toward(_pour_w, 1.0 if _pour else 0.0, delta * 6.0)
	var wobble := Vector3(0, 0, sin(_time * TAU * 5.5) * 1.5) * _pour_w
	var xf := _base
	xf.origin += offset + _off_pos + Vector3(0, sin(_time * TAU * 3.1) * 0.006 * _pour_w, 0)
	# Turned about the hand (the model's origin is the grip for long tools).
	xf.basis = Basis.from_euler((_off_rot + wobble) * DEG) * xf.basis
	_model.transform = xf
	if _stream:
		_place_stream(xf)


func _update_stroke(delta: float, player: Player) -> void:
	if _debug_u >= 0.0:
		var pose := ToolAnim.sample(ToolAnim.PROFILES.get(_debug_prof, {}), _debug_u)
		_off_pos = pose[0]
		_off_rot = pose[1]
		return
	var t := -1.0
	if not _prof.is_empty():
		if _local >= 0.0:
			_local += delta
			t = _local
			if _local >= _len:
				_prof = {}
				t = -1.0
		else:
			t = player.action_clock() if player else -1.0
			if t < 0.0:
				_prof = {}
	# What is left of a stroke cut short, eased out on top of the new one (or of rest).
	var left_pos := Vector3.ZERO
	var left_rot := Vector3.ZERO
	if _blend > 0.0:
		_blend = maxf(_blend - delta / CANCEL_BLEND, 0.0)
		var w := _blend * _blend * (3.0 - 2.0 * _blend)
		left_pos = _from_pos * w
		left_rot = _from_rot * w
	if t >= 0.0:
		_sample(t)
		_off_pos += left_pos
		_off_rot += left_rot
	else:
		_off_pos = left_pos
		_off_rot = left_rot
