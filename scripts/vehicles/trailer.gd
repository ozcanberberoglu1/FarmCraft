class_name Trailer
extends Vehicle
## A trailer towed behind one of the farmer's vehicles (VehicleTable entries with
## "trailer": Grandpa's stock trailer, the dealership's cargo trailer). It is a Vehicle
## nobody drives: saved with the vehicles, kept off by walkers (Vehicle.keep_out), with a
## cargo bed of its own (CargoBed, BedPoint), but held kinematic and put where the tow
## solver says every physics tick, so nothing in the physics can make it jackknife or
## shake:
##   hitched, its coupling sits on the towing vehicle's ball and its axle follows at the
##   tongue's length (a tractrix: it cuts corners as a real one does); in reverse the swing
##   is eased back toward straight so it goes where the truck is pointed, and it never
##   swings further round than MAX_SWING; its wheels stand on the ground under each of
##   them (kerbs and slabs too), the body pitched from the ball's height and rolled by the
##   two wheels; run into a wall or a tree, it stops the truck (_stop_at_walls);
##   unhitched, it stands level on its jockey wheel where it was left.
## Hitching: back a vehicle up until its ball is within HITCH_REACH of the coupling (a
## marker over the coupling shows while the farmer drives near: amber, green in reach),
## get out, E at the tongue ("Römorku bağla"; a clunk, the jockey wheel winds up); E there
## again unhitches it.
## Wheeled by hand: an empty trailer (no animal, no cargo) need not be backed up to. With
## one of his vehicles standing within WHEEL_REACH of the coupling (any way round) and a
## clear, level place straight behind it, E at the tongue rolls the trailer there on its
## jockey wheel over a moment (wheel_choice, _wheel_plan: out along its own length first,
## then swung round and in; nothing in its way, and it collides with nothing while it
## rolls) at a brisk walk (WHEEL_SPEED) and couples it; the farmer in its way is stepped
## aside ahead of it (_roll_aside), it waits for a townsman or an animal who walks into its
## way (_roll_held), and its bed cannot be opened or loaded until it stands. The marker
## turns green for a driver who is near enough with room behind him, and he is told once
## he has stopped there. When it can't be done the tongue says why (too far, the vehicle
## tows another, no room, somebody in the way, loaded).
## The stock trailer: E at its body lowers and raises the gate (a ramp). With an animal on
## the rope (AnimalHandler) and the ramp down, E walks it up the ramp to its place (two
## sheep side by side, or one cow or horse: "room"); more are refused with a line. Aboard
## (the rope stays in his hand until it stands there) they stand facing the road, sway a
## little and call now and then, out of the world's
## goings-on as a ridden horse is. G at the open gate puts the rope back on the last one
## in: it turns, walks down the ramp and is on the rope again. Driving off with the ramp
## down shuts it. At the day's end whoever is still aboard is taken to its housing.

## Every trailer in the world.
const TRAILER_GROUP := &"trailers"
## How near (m, on the ground) a vehicle's ball must be to the coupling to hitch, and how
## much higher or lower it may stand.
const HITCH_REACH := 0.9
const HITCH_RISE := 0.7
## How far the trailer swings round behind its tow (radians from straight).
const MAX_SWING := deg_to_rad(62.0)
## Reversing, the swing is eased back by this share of itself per metre on top of what
## the tractrix adds: it settles instead of folding.
const REVERSE_EASE := 0.35
## The hitch moved further than this in one tick: the tow was put somewhere else (a
## load, a delivery) and the trailer is put straight behind it.
const TOW_JUMP := 2.5
## Height of the ball above the ground and how far behind the body's rear it stands, for
## a vehicle whose entry has no "hitch".
const BALL_HEIGHT := 0.47
const BALL_BEHIND := 0.1
## The gate's swing takes this long (s); an animal's pace on the ramp (m/s).
const GATE_TIME := 1.1
const BOARD_PACE := 1.25
## How far the marker shows to a driver (m).
const GUIDE_RANGE := 14.0
## Seconds between the calls of animals riding along.
const VOICE_EVERY := Vector2(9.0, 24.0)
## Seconds a second E confirms buying the cargo trailer.
const CONFIRM_TIME := 6.0
## Room an animal takes (sheep: 1).
const ROOM := {&"cow": 2, &"horse": 2}
## Wheeling an empty trailer to a vehicle by hand: how near (m, on the ground) the
## vehicle's ball must be to the coupling and how much higher or lower it may stand (from
## the dealer's bay to a pickup at the kerb in front is 5.4 to 6.5 m); how fast it is
## wheeled (m/s, a brisk walk) and how long it takes to get going and to stop (s), so how
## long the roll takes (s: the shortest, the longest, by the length of the way: 4 m in
## 1.6 s, 10 m in 3.4 s); and the longest way it is wheeled (m, a radian of turning on its
## axle counted as WHEEL_ARM m).
const WHEEL_REACH := 8.0
const WHEEL_RISE := 1.5
const WHEEL_SPEED := 3.5
const WHEEL_RAMP := 0.5
const WHEEL_TIME := Vector2(1.2, 5.3)
const WHEEL_FAR := 16.5
const WHEEL_ARM := 1.6
## While it rolls: how near its body the farmer's feet are let (m), how far ahead along
## its way he is stepped aside for it (m) and how fast (m/s); how far ahead it looks for a
## townsman or an animal who walked into its way (m) and how long in all it waits for them
## (s; then it goes on, as it must end somewhere); seconds between the steps heard at its
## tongue.
const WHEEL_KEEP := 0.5
const WHEEL_AHEAD := 1.6
const WHEEL_ASIDE := 3.2
const WHEEL_LOOK := 1.2
const WHEEL_WAIT := 2.0
const WHEEL_FOOT := 0.36
## The driver's marker goes green for a trailer to wheel over only below the second of
## these speeds (km/h), and he is told to get out only once he is slower than the first:
## driving past his trailer is not coming for it.
const WHEEL_SLOW := Vector2(3.0, 25.0)
## Its way is looked over every WHEEL_STEP m; straight out along its own length up to
## WHEEL_OUT m, straight in behind the vehicle from up to WHEEL_IN m back.
const WHEEL_STEP := 0.3
const WHEEL_OUT := 7.0
const WHEEL_IN := 3.5
## How near it may pass another vehicle's body (m), how far its tongue may stand into its
## tow's tail on the way in (the ball is under it), how near what stands (a wall, a post)
## or walks, and how near the farmer's feet its place may be.
const WHEEL_GAP := 0.12
const WHEEL_TOW_SLACK := 0.06
const WHEEL_WALL_GAP := 0.08
const WHEEL_SELF := 0.5
## What stands in its way is looked for between these heights over the ground (m: over a
## kerb, under a canopy), and the most its place may tilt (radians).
const WHEEL_CHECK := Vector2(0.45, 1.7)
const WHEEL_TILT := 0.2
## Seconds an answer of wheel_plan is kept (the marker, the hint and the goal ask every
## frame).
const WHEEL_EVERY := 0.3
## Things without a body that stand in a wheeled trailer's way all the same (the price
## board): nodes of this group with a "post" meta, Vector3(x, z, radius).
const WHEEL_POSTS := &"wheel_posts"

## The vehicle it is hitched to (null: parked).
var tow: Vehicle
var gate_open := false
## Animals aboard, in the order they came in.
var aboard: Array[Animal] = []

var _hitch := Vector3(0.0, 0.47, 3.0)
var _track := 0.93
var _radius := 0.33
var _jockey_z := 2.45
var _floor := 0.5
var _box_front := 1.5
var _box_rear := -1.35
var _box_half := 0.72
var _ramp_len := 1.34
var _ramp_run := 1.2
var _wheel_pivots: Array[Node3D] = []
var _ramp_pivot: Node3D
## The lowered ramp as something to look at (layer 4: only the farmer's look stops on it,
## and finds the trailer behind it): on while the gate is down.
var _ramp_touch: CollisionShape3D
var _jockey: Node3D
var _gate := 0.0
var _jockey_up := 0.0
var _spin := 0.0
var _last_hitch := Vector3.ZERO
## Physics ticks until a parked trailer is stood on the ground it was put on.
var _settle := 3
## Which way the tow was going when the trailer ran into something (0: free), and whether
## it has stood clear of everything since it was hitched (hitched up against a wall, it
## is let out whichever way the driver goes).
var _blocked := 0.0
var _clear_seen := false
## The next tick puts the coupling on the ball although nothing moves (just hitched).
var _snap := false
var _guide: MeshInstance3D
var _guide_mat: StandardMaterial3D
var _in_reach_told := false
var _ball: Node3D
## Animals walking in or out: Animal -> {"pts": local points, "i", "pos", "yaw", "out"}.
var _walks := {}
## Where each animal aboard stands (Animal -> local Vector3) and its own ground callable.
var _slots := {}
var _ground_was := {}
var _voice := 12.0
var _clock := 0.0
var _confirm := 0.0
var _rng := RandomNumberGenerator.new()
## What a load asked to be put back once every vehicle is restored.
var _pending := {}
## Being wheeled to a vehicle by hand (empty: not): {"to": Vehicle, "keys": the way
## (Vector3(x, z, heading) each), "lens", "total", "t", "time", "end": its place as a
## save keeps it, "layer": its collision layer while it stands, "pace": how fast its clock
## runs (0: it waits for somebody in its way), "held": seconds waited so far, "look":
## the query for walkers ahead, "shapes": its body as boxes to ask it with (_wheel_scene),
## "side": the side the farmer was last stepped to}.
var _roll := {}
## wheel_plan's last answers: vehicle instance id -> [msec, plan].
var _wheel_memo := {}
## Its body's boxes on the ground in its own frame: [centre (x, z), half size (x, z)] each.
var _wheel_boxes: Array = []
var _roll_step := 0.0


static func make(kind_id: StringName, xform: Transform3D, for_sale := false) -> Trailer:
	var t := Trailer.new()
	t.kind = kind_id
	t.info = VehicleTable.get_info(kind_id)
	t.price = int(t.info.get("price", 0))
	t.owned = not for_sale
	t.fuel = 0.0
	t.transform = xform
	return t


## Every trailer in the world.
static func every() -> Array[Trailer]:
	var out: Array[Trailer] = []
	for v: Vehicle in Vehicle.all:
		if v is Trailer and v.is_inside_tree():
			out.append(v as Trailer)
	return out


## The trailer of `kind_id` (null when the world has none).
static func of_kind(kind_id: StringName) -> Trailer:
	for t in every():
		if t.kind == kind_id:
			return t
	return null


## The trailer hitched to `v` (null: none).
static func towed_by(v: Vehicle) -> Trailer:
	for t in every():
		if t.tow == v:
			return t
	return null


## The trailer animal `a` rides in (null: none).
static func carrying(a: Animal) -> Trailer:
	for t in every():
		if t.aboard.has(a):
			return t
	return null


## Where `v` carries a trailer's coupling: its tow ball, in its body frame.
static func hitch_of(v: Vehicle) -> Vector3:
	if v.info.has("tow_ball"):
		return v._mb(v.info["tow_ball"])
	var rear := INF
	for box: Array in v.info.get("boxes", []):
		var c: Vector3 = box[0]
		var size: Vector3 = box[1]
		if c.y - size.y * 0.5 < 1.0:
			rear = minf(rear, c.x - size.x * 0.5)
	if rear == INF:
		rear = -2.5
	return v._mb(Vector3(rear - BALL_BEHIND, BALL_HEIGHT, 0.0))


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	name = "Trailer_%s" % kind
	_base_mass = float(info.get("mass", 400.0))
	mass = _base_mass
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(GROUP)
	add_to_group(TRAILER_GROUP)
	# Moved by the tow solver, never by the physics.
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_base_com = Vector3(0.0, 0.6, 0.1)
	center_of_mass = _base_com
	_rng.seed = hash(String(kind))
	var h: Vector3 = info.get("hitch", Vector3(3.0, 0.47, 0.0))
	_hitch = Vector3(0.0, h.y, h.x)
	_track = float(info.get("track", 0.93))
	_radius = float(info.get("wheel_radius", 0.33))
	_jockey_z = float(info.get("jockey_x", 2.45))
	_floor = float(info.get("floor", 0.6))
	var box: Vector3 = info.get("box", Vector3(1.5, -1.35, 0.72))
	_box_front = box.x
	_box_rear = box.y
	_box_half = box.z
	_ramp_len = float(info.get("ramp", 0.0))
	_ramp_run = sqrt(maxf(_ramp_len * _ramp_len - _floor * _floor, 0.01))
	_arches = Vector4(0.0, 0.0, _radius, _radius * ARCH_GAP)
	cargo = Stockpile.new(int(info.get("cargo_units", 0)))
	_build_trailer_model()
	_build_body()
	_build_markers()
	_build_guide()
	_tail_light = OmniLight3D.new()
	_tail_light.position = _mb(info.get("tail_pos", Vector3(-1.5, 0.5, 0.0)))
	_tail_light.light_color = Color(1.0, 0.12, 0.06)
	_tail_light.omni_range = 2.0
	_tail_light.light_energy = 0.0
	add_child(_tail_light)
	cargo.changed.connect(_on_cargo_changed)
	Events.day_ending.connect(_on_day_ending)


## The model turned to face +Z, its wheels on pivots that roll, the gate on its hinge, the
## jockey wheel on a slide, the load in its bed.
func _build_trailer_model() -> void:
	var holder := Node3D.new()
	holder.name = "Model"
	holder.rotation.y = -PI * 0.5
	add_child(holder)
	var model := VehicleLook.build_model(info)
	holder.add_child(model)
	_mid_x = 0.0
	_bed = CargoBed.new()
	_bed.name = "Load"
	_bed.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	holder.add_child(_bed)
	_bed.setup(cargo, info)
	var ramp: MeshInstance3D = null
	var jockey: MeshInstance3D = null
	var wheels: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_restyle(mi)
		var n := String(mi.name)
		if "WheelStock" in n:
			wheels.append(mi)
		elif n.begins_with("Ramp"):
			ramp = mi
		elif n.begins_with("Jockey"):
			jockey = mi
	for mi in wheels:
		var pivot := Node3D.new()
		pivot.name = "Wheel_%d" % _wheel_pivots.size()
		add_child(pivot)
		pivot.position = to_local(_center_of(mi))
		mi.reparent(pivot, true)
		mi.position -= mi.transform * mi.get_aabb().get_center()
		_wheel_pivots.append(pivot)
	if ramp:
		_ramp_pivot = Node3D.new()
		_ramp_pivot.name = "RampHinge"
		add_child(_ramp_pivot)
		_ramp_pivot.position = Vector3(0.0, _floor, _box_rear - 0.02)
		ramp.reparent(_ramp_pivot, true)
		var touch := StaticBody3D.new()
		touch.name = "RampTouch"
		touch.collision_layer = 4
		touch.collision_mask = 0
		_ramp_touch = CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(_box_half * 2.0 + 0.1, 0.9, _ramp_run + 0.3)
		_ramp_touch.shape = box
		_ramp_touch.position = Vector3(0.0, 0.42, _box_rear - (_ramp_run + 0.3) * 0.5)
		_ramp_touch.disabled = true
		touch.add_child(_ramp_touch)
		add_child(touch)
	if jockey:
		_jockey = Node3D.new()
		_jockey.name = "JockeySlide"
		add_child(_jockey)
		jockey.reparent(_jockey, true)


## The marker a driver backs up to: a ring round the coupling and an arrow over it,
## amber, green once his ball is in reach.
func _build_guide() -> void:
	_guide_mat = StandardMaterial3D.new()
	_guide_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_guide_mat.albedo_color = Color(1.0, 0.7, 0.15)
	_guide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_guide_mat.albedo_color.a = 0.9
	_guide = MeshInstance3D.new()
	_guide.name = "HitchGuide"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.26
	ring.outer_radius = 0.32
	ring.rings = 24
	ring.ring_segments = 6
	_guide.mesh = ring
	_guide.material_override = _guide_mat
	_guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_guide.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_guide.position = _hitch + Vector3(0, 0.12, 0)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 0.0
	cone.height = 0.42
	cone.radial_segments = 12
	arrow.mesh = cone
	arrow.material_override = _guide_mat
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.position = Vector3(0, 0.85, 0)
	_guide.add_child(arrow)
	_guide.visible = false
	add_child(_guide)


# --- Towing ---------------------------------------------------------------------------------

## The coupling head in the world.
func coupling() -> Vector3:
	return global_transform * _hitch


## How far round it has swung behind its tow (radians; 0 straight, 0 when parked).
func swing() -> float:
	if tow == null:
		return 0.0
	var tf := tow.global_basis.z
	var mine := global_basis.z
	return Vector2(tf.x, tf.z).angle_to(Vector2(mine.x, mine.z))


## The farmer's vehicle whose ball is in reach of the coupling (null: none).
func tow_in_reach() -> Vehicle:
	var c := coupling()
	var best: Vehicle = null
	var best_d := HITCH_REACH
	for v: Vehicle in Vehicle.all:
		if v is Trailer or not v.owned or not v.is_inside_tree() or towed_by(v) != null:
			continue
		var ball := v.global_transform * hitch_of(v)
		var d := Vector2(ball.x - c.x, ball.z - c.z).length()
		# Backed up to it, not nosed in from the side.
		var back := -v.global_basis.z
		var to_me := global_position - ball
		if d < best_d and absf(ball.y - c.y) < HITCH_RISE and Vector2(back.x, back.z).dot(Vector2(to_me.x, to_me.z)) > 0.0:
			best_d = d
			best = v
	return best


## Onto `v`'s ball: the jockey wheel winds up and the trailer follows from now on.
func hitch(v: Vehicle, quiet := false) -> bool:
	if v == null or v == tow or v is Trailer or towed_by(v) != null:
		return false
	_cancel_roll()
	if tow:
		unhitch(true)
	tow = v
	add_collision_exception_with(v)
	v.add_collision_exception_with(self)
	_last_hitch = v.global_transform * hitch_of(v)
	_blocked = 0.0
	_clear_seen = false
	_snap = true
	_show_ball(true)
	if not quiet:
		Audio.play("metal", coupling(), -3.0, 0.05, &"Effects", 6.0, 0.8)
		Audio.play("plank", coupling(), -10.0, 0.05, &"Effects", 5.0, 0.7)
		Game.notify(tr("MSG_TRAILER_HITCHED") % [display_name(), v.display_name()], UiTheme.GREEN)
	changed.emit()
	return true


## Off the ball: it stands on its jockey wheel where it is.
func unhitch(quiet := false) -> void:
	if tow == null:
		return
	_show_ball(false)
	if is_instance_valid(tow):
		remove_collision_exception_with(tow)
		tow.remove_collision_exception_with(self)
	tow = null
	_settle = 1
	_blocked = 0.0
	if not quiet:
		Audio.play("metal", coupling(), -5.0, 0.05, &"Effects", 6.0, 1.05)
		Game.notify(tr("MSG_TRAILER_UNHITCHED") % display_name(), UiTheme.GOLD_SOFT)
	changed.emit()


## A draw bar and ball under the towing vehicle's tail while it tows.
func _show_ball(on: bool) -> void:
	if is_instance_valid(_ball):
		_ball.queue_free()
	_ball = null
	if not on or tow == null:
		return
	var at := hitch_of(tow)
	_ball = Node3D.new()
	_ball.name = "TowBall"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.065)
	mat.metallic = 0.7
	mat.roughness = 0.45
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.05, 0.42)
	bar.mesh = bm
	bar.material_override = mat
	bar.position = at + Vector3(0, -0.085, 0.19)
	_ball.add_child(bar)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.014
	cm.bottom_radius = 0.02
	cm.height = 0.07
	neck.mesh = cm
	neck.material_override = mat
	neck.position = at + Vector3(0, -0.05, 0)
	_ball.add_child(neck)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.027
	sm.height = 0.054
	ball.mesh = sm
	ball.material_override = mat
	ball.position = at + Vector3(0, -0.005, 0)
	_ball.add_child(ball)
	tow.add_child(_ball)


func teleport(xf: Transform3D) -> void:
	_cancel_roll()
	super.teleport(xf)
	if tow == null:
		_settle = 2


func _physics_process(delta: float) -> void:
	_confirm = maxf(_confirm - delta, 0.0)
	if tow != null:
		if not is_instance_valid(tow) or not tow.is_inside_tree():
			tow = null
			_settle = 1
		else:
			_tow_tick(delta)
			return
	if not _roll.is_empty():
		_roll_tick(delta)
		return
	if _settle > 0:
		_settle -= 1
		if _settle == 0:
			_stand()


## One tick behind the tow (see the class comment).
func _tow_tick(delta: float) -> void:
	var ball := tow.global_transform * hitch_of(tow)
	var step := Vector2(ball.x - _last_hitch.x, ball.z - _last_hitch.z)
	if step.length() > TOW_JUMP:
		straighten()
		return
	var tf3 := tow.global_basis.z
	var tf := Vector2(tf3.x, tf3.z).normalized()
	var o := global_position
	if step.length() < 0.0004 and absf(ball.y - _last_hitch.y) < 0.0004 and tow.freeze and not _snap:
		# Parked: nothing moves.
		_set_light_states(false, false)
		return
	_snap = false
	var dy := ball.y - o.y - _hitch.y
	var reach := sqrt(maxf(_hitch.z * _hitch.z - dy * dy, 1.0))
	var d := Vector2(o.x - ball.x, o.z - ball.z)
	var back := -tf
	d = back if d.length() < 0.05 else d.normalized()
	var turn := back.angle_to(d)
	var along := step.dot(tf)
	if along < 0.0:
		turn -= turn * clampf((1.0 / _hitch.z + REVERSE_EASE) * -along, 0.0, 1.0)
	turn = clampf(turn, -MAX_SWING, MAX_SWING)
	d = back.rotated(turn)
	var axle := Vector2(ball.x, ball.z) + d * reach
	var xf := _pose(axle, -d, ball)
	var rolled := (xf.origin - o).dot(xf.basis.z)
	_spin = fposmod(_spin + rolled / _radius, TAU)
	global_transform = xf
	_last_hitch = ball
	_stop_at_walls(along, delta)
	# Driving off with the ramp down: up it goes.
	if gate_open and absf(tow.forward_speed()) > 1.2 and _walks.is_empty():
		set_gate(false)
		Game.notify(tr("MSG_TRAILER_GATE_SHUT"), UiTheme.GOLD_SOFT)
	lights_on = tow.lights_on
	_set_light_states(tow.brake > 1.6 and tow.driver != null, false)


## Straight behind its tow (hitched from a save, or the tow was put somewhere else).
func straighten() -> void:
	if tow == null:
		return
	var ball := tow.global_transform * hitch_of(tow)
	var tf3 := tow.global_basis.z
	var tf := Vector2(tf3.x, tf3.z).normalized()
	var axle := Vector2(ball.x, ball.z) - tf * _hitch.z
	global_position = Vector3(axle.x, ball.y - _hitch.y, axle.y)
	global_transform = _pose(axle, tf, ball)
	_last_hitch = ball
	reset_physics_interpolation()


## Parked: level on its two wheels and the jockey wheel, on the ground under them, where
## and heading as it is.
func _stand() -> void:
	var f := global_basis.z
	var dir := Vector2(f.x, f.z)
	dir = Vector2(0, 1) if dir.length() < 0.01 else dir.normalized()
	var o := global_position
	global_transform = _pose(Vector2(o.x, o.z), dir, null)
	reset_physics_interpolation()


## The trailer's place with its axle over `axle` (XZ), heading `dir`: its wheels on the
## ground under each (the roll), its coupling on `front` (the ball) or, parked (null), its
## jockey wheel on the ground under it (the pitch).
func _pose(axle: Vector2, dir: Vector2, front: Variant) -> Transform3D:
	var left2 := Vector2(dir.y, -dir.x)
	var near := global_position.y
	var wl := axle + left2 * _track
	var wr := axle - left2 * _track
	var gl := _ground_under(wl, near)
	var gr := _ground_under(wr, near)
	var o := Vector3(axle.x, (gl + gr) * 0.5, axle.y)
	var pitch := 0.0
	if front is Vector3:
		var dv: Vector3 = (front as Vector3) - o
		pitch = atan2(dv.y, Vector2(dv.x, dv.z).length()) - atan2(_hitch.y, _hitch.z)
	else:
		var j := axle + dir * _jockey_z
		pitch = atan2(_ground_under(j, o.y) - o.y, _jockey_z)
	pitch = clampf(pitch, -0.45, 0.45)
	var f := (Vector3(dir.x, 0.0, dir.y) * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
	var left0 := Vector3(left2.x, 0.0, left2.y)
	var up0 := f.cross(left0).normalized()
	var roll := clampf(atan2(gl - gr, 2.0 * _track), -0.35, 0.35)
	var left := (left0 * cos(roll) + up0 * sin(roll)).normalized()
	return Transform3D(Basis(left, f.cross(left).normalized(), f), o)


## The ground a wheel at `p` (XZ) stands on, looked for round height `near`: the terrain,
## or what is built on it up to a kerb's height above (a pavement, a slab, a ramp), never a
## body that happens to stand there.
func _ground_under(p: Vector2, near: float) -> float:
	var terrain := TerrainData.height(p.x, p.y)
	if not is_inside_tree():
		return terrain
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, maxf(near, terrain) + 0.6, p.y), Vector3(p.x, minf(near, terrain) - 1.5, p.y), 1)
	var skip: Array[RID] = []
	for v: Vehicle in Vehicle.all:
		skip.append(v.get_rid())
	if is_instance_valid(Game.player):
		skip.append((Game.player as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return terrain
	var y := (hit["position"] as Vector3).y
	return y if y < terrain + 0.4 else terrain


## Run into something that stands (a wall, a tree, a fence): the tow is stopped, and may
## only go back the way it came until the trailer is clear of it.
func _stop_at_walls(along: float, delta: float) -> void:
	if absf(along) < 0.002 and _blocked == 0.0:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_footprint.size.x - 0.5, 0.7, _box_front - _box_rear - 0.2)
	q.shape = shape
	q.collision_mask = 1
	var skip: Array[RID] = []
	for v: Vehicle in Vehicle.all:
		skip.append(v.get_rid())
	if is_instance_valid(Game.player):
		skip.append((Game.player as CollisionObject3D).get_rid())
	q.exclude = skip
	q.transform = global_transform * Transform3D(Basis(), Vector3(0.0, 1.25, (_box_front + _box_rear) * 0.5))
	var hit := not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
	if not hit:
		_blocked = 0.0
		_clear_seen = true
		return
	if not _clear_seen:
		return
	if _blocked == 0.0:
		_blocked = signf(along) if absf(along) > 0.0001 else -1.0
		Audio.play("metal", global_position + Vector3(0, 1.0, 0), -6.0, 0.1, &"Effects", 8.0, 0.6)
	var fwd := tow.global_basis.z
	var going := tow.linear_velocity.dot(fwd)
	if signf(going) == _blocked and absf(going) > 0.01:
		tow.linear_velocity -= fwd * going * minf(delta * 30.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	var want_gate := 1.0 if gate_open else 0.0
	if _gate != want_gate:
		_gate = move_toward(_gate, want_gate, delta / GATE_TIME)
		if _gate == want_gate:
			Audio.play("plank" if gate_open else "metal", _gate_point(), -6.0, 0.08, &"Effects", 6.0, 0.8)
	if _ramp_pivot:
		var down := PI * 0.5 + asin(clampf(_floor / maxf(_ramp_len, 0.01), 0.0, 1.0))
		_ramp_pivot.rotation.x = -down * smoothstep(0.0, 1.0, _gate)
		if _ramp_touch.disabled == gate_open:
			_ramp_touch.set_deferred("disabled", not gate_open)
	var up := 1.0 if tow != null else 0.0
	_jockey_up = move_toward(_jockey_up, up, delta * 1.6)
	if _jockey:
		_jockey.position.y = 0.3 * smoothstep(0.0, 1.0, _jockey_up)
	for w in _wheel_pivots:
		w.rotation.x = _spin
	_update_guide()
	_ride(delta)


## The marker over the coupling: only for a driver near an owned trailer that stands
## unhitched; green and a line once he can get out and couple it (his ball in reach, or
## the trailer empty and near enough to be wheeled over, with room behind him).
func _update_guide() -> void:
	var p := Game.player as Player
	var show := false
	if owned and tow == null and is_instance_valid(p) and p.driving != null and not p.driving is Trailer \
			and towed_by(p.driving) == null:
		show = p.driving.global_position.distance_to(coupling()) < GUIDE_RANGE
	if show != _guide.visible:
		_guide.visible = show
		_in_reach_told = false
	if not show:
		return
	var ready := tow_in_reach() == p.driving
	var tell := ready
	var kmh := p.driving.speed_kmh()
	if not ready and _roll.is_empty() and kmh < WHEEL_SLOW.y and not loaded() and _wheel_near(p.driving):
		ready = String(wheel_plan(p.driving)["why"]) == ""
		# Told once he has as good as stopped there, not while he drives past.
		tell = ready and kmh < WHEEL_SLOW.x
	_guide_mat.albedo_color = Color(0.3, 1.0, 0.35, 0.95) if ready else Color(1.0, 0.7, 0.15, 0.9)
	_guide.rotation.y = _clock * 1.2
	if tell and not _in_reach_told:
		_in_reach_told = true
		Game.notify(tr("MSG_TRAILER_IN_REACH"), UiTheme.GREEN)
	elif not ready and p.driving.global_position.distance_to(coupling()) > WHEEL_REACH + 3.5:
		_in_reach_told = false


# --- Wheeled by hand --------------------------------------------------------------------------

## Whether anything rides in it (an animal, cargo): such a trailer is not wheeled by hand.
func loaded() -> bool:
	_prune()
	return not aboard.is_empty() or cargo.total() > 0


## Whether it is being wheeled to a vehicle right now.
func rolling() -> bool:
	return not _roll.is_empty()


## Whether E at the tongue would couple it now: a ball in reach, or one of the farmer's
## vehicles near enough to wheel it to.
func can_couple() -> bool:
	return owned and tow == null and (tow_in_reach() != null or String(wheel_choice()["why"]) == "")


## Whether `v`'s ball is near enough to the coupling to wheel the trailer to it.
func _wheel_near(v: Vehicle) -> bool:
	var ball := v.global_transform * hitch_of(v)
	var c := coupling()
	return Vector2(ball.x - c.x, ball.z - c.z).length() < WHEEL_REACH and absf(ball.y - c.y) < WHEEL_RISE


## Which of the farmer's vehicles it can be wheeled to by hand now and how: {"to", "why":
## "", "keys", "end"}, or {"to": null, "why": the key of the line that says why not}: too
## far, the only one near tows a trailer already, no room, somebody in the way, loaded.
## `fresh`: looked over anew (E), not from the last answer.
func wheel_choice(fresh := false) -> Dictionary:
	if not owned or tow != null or not _roll.is_empty():
		return {"to": null, "why": "HINT_TRAILER_BACK_UP"}
	if loaded():
		return {"to": null, "why": "HINT_TRAILER_WHEEL_LOADED"}
	var c := coupling()
	var near: Array = []
	var taken := false
	for v: Vehicle in Vehicle.all:
		if v is Trailer or not v.owned or not v.is_inside_tree() or not _wheel_near(v):
			continue
		var busy := towed_by(v) != null
		for t in every():
			busy = busy or (t != self and t._roll.get("to") == v)
		if busy:
			taken = true
		else:
			var ball := v.global_transform * hitch_of(v)
			near.append([Vector2(ball.x - c.x, ball.z - c.z).length(), v])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	# Nothing free near: too far, or the one that stands near has a trailer on its ball.
	var why := "HINT_TRAILER_WHEEL_TAKEN" if taken else "HINT_TRAILER_BACK_UP"
	for i in near.size():
		var plan := wheel_plan(near[i][1] as Vehicle, fresh)
		if String(plan["why"]) == "":
			return plan
		if i == 0:
			why = String(plan["why"])
	return {"to": null, "why": why}


## How it would be wheeled to `v` (see wheel_choice), from the last answer when that is
## no older than WHEEL_EVERY.
func wheel_plan(v: Vehicle, fresh := false) -> Dictionary:
	var id := v.get_instance_id()
	var now := Time.get_ticks_msec()
	if not fresh and _wheel_memo.has(id) and now - int(_wheel_memo[id][0]) < int(WHEEL_EVERY * 1000.0):
		return _wheel_memo[id][1]
	var plan := _wheel_plan(v)
	_wheel_memo[id] = [now, plan]
	return plan


## Its place straight behind `v` (level enough, nothing standing in it, the farmer not in
## it) and a clear way there. Refused for want of room with a townsman or an animal in
## the way, it is looked over once more without them: clear then, the line is to wait a
## moment, not to move the vehicle.
func _wheel_plan(v: Vehicle) -> Dictionary:
	var scene := _wheel_scene(v)
	var plan := _wheel_look(v, scene)
	if String(plan["why"]) == "HINT_TRAILER_WHEEL_NO_ROOM" and bool(scene["walker"]):
		if String(_wheel_look(v, _wheel_scene(v, false))["why"]) == "":
			return {"to": null, "why": "HINT_TRAILER_WHEEL_WAIT"}
	return plan


func _wheel_look(v: Vehicle, scene: Dictionary) -> Dictionary:
	var no_room := {"to": null, "why": "HINT_TRAILER_WHEEL_NO_ROOM"}
	var ball := v.global_transform * hitch_of(v)
	var f3 := v.global_basis.z
	var h1 := Vector2(f3.x, f3.z)
	if h1.length() < 0.6 or v.global_basis.y.y < 0.8:
		return no_room
	h1 = h1.normalized()
	var a1 := Vector2(ball.x, ball.z) - h1 * _hitch.z
	var end := Vector3(a1.x, a1.y, atan2(h1.x, h1.y))
	var place := _pose(a1, h1, ball)
	if place.basis.y.y < cos(WHEEL_TILT):
		return no_room
	if _wheel_hits(end, scene):
		return no_room
	var me: Variant = null
	var p := Game.player as Player
	if is_instance_valid(p) and p.driving == null:
		me = Vector2(p.global_position.x, p.global_position.z)
		if _wheel_over(end, me as Vector2, WHEEL_SELF):
			return {"to": null, "why": "HINT_TRAILER_WHEEL_SELF"}
	var f0 := global_basis.z
	var keys := _wheel_route(Vector3(global_position.x, global_position.z, atan2(f0.x, f0.z)), end, scene, me)
	if keys.is_empty():
		return no_room
	return {"to": v, "why": "", "keys": keys, "end": place}


## What a way to `v` is looked over against: the other vehicles' bodies on the ground
## (its tow's a little smaller: the tongue ends under its tail), the bodiless posts, the
## query for what stands or walks (the world and, with `walkers`, the walkers' layer; not
## the vehicles, the farmer or his own dog, who steps aside), the boxes it is asked with.
## "walker": a look found a townsman or an animal in the way.
func _wheel_scene(v: Vehicle, walkers := true) -> Dictionary:
	if _wheel_boxes.is_empty():
		for box: Array in info.get("boxes", []):
			var c := _mb(box[0])
			var size: Vector3 = box[1]
			_wheel_boxes.append([Vector2(c.x, c.z), Vector2(size.z * 0.5, size.x * 0.5)])
	var skip: Array[RID] = []
	var others: Array = []
	var here := Vector2(global_position.x, global_position.z)
	for o: Vehicle in Vehicle.all:
		if not o.is_inside_tree():
			continue
		skip.append(o.get_rid())
		var at := Vector2(o.global_position.x, o.global_position.z)
		if o != self and at.distance_to(here) < WHEEL_FAR + WHEEL_REACH + o._reach + _reach:
			others.append([at, o._reach, o._ground_boxes(-WHEEL_TOW_SLACK if o == v else WHEEL_GAP)])
	if is_instance_valid(Game.player):
		skip.append((Game.player as CollisionObject3D).get_rid())
	for dog in get_tree().get_nodes_in_group(PetDog.PET_GROUP):
		for body in dog.find_children("*", "CollisionObject3D", true, false):
			skip.append((body as CollisionObject3D).get_rid())
	var posts: Array[Vector3] = []
	for n in get_tree().get_nodes_in_group(WHEEL_POSTS):
		if n is Node3D and (n as Node3D).visible and n.has_meta("post"):
			posts.append(n.get_meta("post"))
	var shapes: Array = []
	var tall := WHEEL_CHECK.y - WHEEL_CHECK.x
	var whole := BoxShape3D.new()
	whole.size = Vector3(_footprint.size.x + WHEEL_WALL_GAP * 2.0, tall, _footprint.size.y + WHEEL_WALL_GAP * 2.0)
	shapes.append([whole, _footprint.get_center()])
	for b: Array in _wheel_boxes:
		var half: Vector2 = b[1]
		var shape := BoxShape3D.new()
		shape.size = Vector3(half.x * 2.0 + WHEEL_WALL_GAP * 2.0, tall, half.y * 2.0 + WHEEL_WALL_GAP * 2.0)
		shapes.append([shape, b[0]])
	var q := PhysicsShapeQueryParameters3D.new()
	q.collision_mask = (1 | 16) if walkers else 1
	q.exclude = skip
	return {"others": others, "posts": posts, "shapes": shapes, "query": q, "space": get_world_3d().direct_space_state, "memo": {}, "walker": false}


## Whether the trailer standing at `pose` (x, z, heading) would stand in something: a
## vehicle's body, a post, a wall, an animal, a townsman.
func _wheel_hits(pose: Vector3, scene: Dictionary) -> bool:
	var memo: Dictionary = scene["memo"]
	var key := Vector3i(roundi(pose.x * 25.0), roundi(pose.y * 25.0), roundi(pose.z * 50.0))
	if not memo.has(key):
		memo[key] = _wheel_hits_now(pose, scene)
	return memo[key]


func _wheel_hits_now(pose: Vector3, scene: Dictionary) -> bool:
	var fwd := Vector2(sin(pose.z), cos(pose.z))
	var right := Vector2(cos(pose.z), -sin(pose.z))
	var at := Vector2(pose.x, pose.y)
	var mine: Array[PackedVector2Array] = []
	for o: Array in scene["others"]:
		if at.distance_to(o[0]) > _reach + float(o[1]) + 0.4:
			continue
		if mine.is_empty():
			for b: Array in _wheel_boxes:
				var c: Vector2 = b[0]
				var h: Vector2 = b[1]
				var mid := at + right * c.x + fwd * c.y
				mine.append(PackedVector2Array([mid - right * h.x - fwd * h.y, mid + right * h.x - fwd * h.y,
						mid + right * h.x + fwd * h.y, mid - right * h.x + fwd * h.y]))
		for a in mine:
			for b: PackedVector2Array in o[2]:
				if not Geometry2D.intersect_polygons(a, b).is_empty():
					return true
	for post: Vector3 in scene["posts"]:
		if _wheel_over(pose, Vector2(post.x, post.y), post.z):
			return true
	# What stands or walks there: the whole of it first, then box by box (the tongue is
	# narrow).
	var q: PhysicsShapeQueryParameters3D = scene["query"]
	var space: PhysicsDirectSpaceState3D = scene["space"]
	var turned := Basis(Vector3.UP, pose.z)
	var y := _ground_under(at, global_position.y) + (WHEEL_CHECK.x + WHEEL_CHECK.y) * 0.5
	var shapes: Array = scene["shapes"]
	for i in shapes.size():
		var c: Vector2 = shapes[i][1]
		var mid := at + right * c.x + fwd * c.y
		q.shape = shapes[i][0]
		q.transform = Transform3D(turned, Vector3(mid.x, y, mid.y))
		var found := space.intersect_shape(q, 1)
		var hit := not found.is_empty()
		if i == 0 and not hit:
			return false
		if i > 0 and hit:
			var body := found[0].get("collider") as CollisionObject3D
			if body != null and (body.collision_layer & 16) != 0:
				scene["walker"] = true
			return true
	return false


## Whether the ground point `p` is within `radius` of the trailer's body standing at `pose`.
func _wheel_over(pose: Vector3, p: Vector2, radius: float) -> bool:
	var d := p - Vector2(pose.x, pose.y)
	var lx := d.dot(Vector2(cos(pose.z), -sin(pose.z)))
	var lz := d.dot(Vector2(sin(pose.z), cos(pose.z)))
	for b: Array in _wheel_boxes:
		var c: Vector2 = b[0]
		var h: Vector2 = b[1]
		if Vector2(maxf(absf(lx - c.x) - h.x, 0.0), maxf(absf(lz - c.y) - h.y, 0.0)).length() < radius:
			return true
	return false


## How far (m, up to `far`) the trailer can go straight along `dir` from `from` before
## it stands in something; `short`: a step short of that.
func _wheel_free(from: Vector3, dir: Vector2, far: float, scene: Dictionary, short: bool) -> float:
	var free := 0.0
	var d := WHEEL_STEP
	while d <= far + 0.001:
		if _wheel_hits(Vector3(from.x + dir.x * d, from.y + dir.y * d, from.z), scene):
			return maxf(free - WHEEL_STEP, 0.0) if short else free
		free = d
		d += WHEEL_STEP
	return free


## How long the stretch from pose `a` to pose `b` is (m; turning counted by WHEEL_ARM).
static func _wheel_len(a: Vector3, b: Vector3) -> float:
	return maxf(Vector2(b.x - a.x, b.y - a.y).length(), absf(b.z - a.z) * WHEEL_ARM)


## The way from `start` to `end` (poses: x, z, heading; the headings run on from one to
## the next, so a turn the long way round is more than half a circle): the shortest clear
## one of a handful, each out along its own length first (as far as its place is ahead,
## as far as it can go, half that, or not at all), then either swung round while it is
## carried over, or turned on its axle to where it goes, rolled there and turned again
## (tongue or tail first, the short way round or the long), and straight in behind the
## vehicle for the last stretch. One that does not pass over the farmer (`me`, his feet)
## before one that does. Empty: none.
func _wheel_route(start: Vector3, end: Vector3, scene: Dictionary, me: Variant) -> Array[Vector3]:
	var h0 := Vector2(sin(start.z), cos(start.z))
	var h1 := Vector2(sin(end.z), cos(end.z))
	var a0 := Vector2(start.x, start.y)
	var a1 := Vector2(end.x, end.y)
	var out_free := _wheel_free(start, h0, WHEEL_OUT, scene, true)
	var in_free := _wheel_free(end, -h1, WHEEL_IN, scene, false)
	var outs: Array[float] = []
	for d: float in [clampf((a1 - a0).dot(h0), 0.0, out_free), out_free, out_free * 0.5, 0.0]:
		var known := false
		for o in outs:
			known = known or absf(o - d) < 0.25
		if not known:
			outs.append(d)
	var ways: Array = []
	for d in outs:
		var p1 := Vector3(a0.x + h0.x * d, a0.y + h0.y * d, start.z)
		for k: float in [0.0, 0.8, 2.0, 3.5]:
			if k > in_free + 0.01:
				break
			var q2 := a1 - h1 * k
			var round_to := start.z + angle_difference(start.z, end.z)
			ways.append(_wheel_keys([start, p1, Vector3(q2.x, q2.y, round_to), Vector3(a1.x, a1.y, round_to)]))
			var go := q2 - Vector2(p1.x, p1.y)
			if go.length() < 0.3:
				continue
			for lead: float in [0.0, PI]:
				var along := p1.z + angle_difference(p1.z, atan2(go.x, go.y) + lead)
				var back := angle_difference(along, end.z)
				var turns: Array[float] = [back]
				if absf(back) > 0.02:
					turns.append(back - signf(back) * TAU)
				for turn in turns:
					ways.append(_wheel_keys([start, p1, Vector3(p1.x, p1.y, along), Vector3(q2.x, q2.y, along),
							Vector3(q2.x, q2.y, along + turn), Vector3(a1.x, a1.y, along + turn)]))
	ways.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["len"]) < float(b["len"]))
	var spare: Array[Vector3] = []
	var tried := 0
	for way: Dictionary in ways:
		if float(way["len"]) > WHEEL_FAR or tried >= 48:
			break
		tried += 1
		var keys: Array[Vector3] = way["keys"]
		var over := _wheel_way(keys, scene, me)
		if over == 0:
			return keys
		if over == 1 and spare.is_empty():
			spare = keys
	return spare


## The poses `list` as a way: {"keys": them without the ones that repeat, "len"}.
func _wheel_keys(list: Array) -> Dictionary:
	var keys: Array[Vector3] = [list[0]]
	var total := 0.0
	for i in range(1, list.size()):
		var step := _wheel_len(keys.back(), list[i])
		if step > 0.02 or i == list.size() - 1:
			total += step
			keys.append(list[i])
	return {"keys": keys, "len": total}


## Looks over the way `keys`: -1 something stands in it, 1 clear but over the farmer's
## feet (`me`), 0 clear.
func _wheel_way(keys: Array[Vector3], scene: Dictionary, me: Variant) -> int:
	for i in range(1, keys.size()):
		if _wheel_hits(keys[i], scene):
			return -1
	var over := 0
	for i in keys.size() - 1:
		var n := maxi(ceili(_wheel_len(keys[i], keys[i + 1]) / WHEEL_STEP), 1)
		for j in range(1, n):
			var pose := keys[i].lerp(keys[i + 1], float(j) / n)
			if _wheel_hits(pose, scene):
				return -1
			if over == 0 and me is Vector2 and _wheel_over(pose, me as Vector2, WHEEL_SELF - 0.1):
				over = 1
	return over


## Off it goes along the plan's way (wheel_choice): through nothing, as its way was looked
## over, and colliding with nothing while it rolls (a body moved by hand sweeps aside
## whatever it touches). The ramp is put up first.
func _start_roll(plan: Dictionary) -> void:
	var keys: Array[Vector3] = plan["keys"]
	var lens := PackedFloat32Array()
	var total := 0.0
	for i in keys.size() - 1:
		lens.append(_wheel_len(keys[i], keys[i + 1]))
		total += lens[i]
	if gate_open:
		set_gate(false)
	var scene := _wheel_scene(plan["to"] as Vehicle)
	var look := PhysicsShapeQueryParameters3D.new()
	look.collision_mask = 16
	look.exclude = (scene["query"] as PhysicsShapeQueryParameters3D).exclude
	_roll = {"to": plan["to"], "keys": keys, "lens": lens, "total": total, "t": 0.0,
		"time": clampf(total / WHEEL_SPEED + WHEEL_RAMP, WHEEL_TIME.x, WHEEL_TIME.y), "end": plan["end"], "layer": collision_layer,
		"pace": 1.0, "held": 0.0, "look": look, "shapes": scene["shapes"], "side": 0.0}
	collision_layer = 0
	_bed_touch(false)
	_roll_step = 0.0
	_wheel_memo.clear()
	Audio.play("creak", coupling(), -7.0, 0.08, &"Effects", 6.0, 1.25)


## One tick of the roll: along its way at a walk (up to its pace, steady, and down again),
## on its wheels and its jockey wheel, the wheels turning with it, steps at its tongue;
## waiting while somebody walks across its way, the farmer stepped aside ahead of it; at
## the end it couples.
func _roll_tick(delta: float) -> void:
	var time := float(_roll["time"])
	var total := float(_roll["total"])
	var share := WHEEL_RAMP / time
	var at := _wheel_ease(clampf(float(_roll["t"]) / time, 0.0, 1.0), share) * total
	# Somebody in the next stretch of its way: its clock runs down, and up again after.
	var pace := move_toward(float(_roll["pace"]), 0.0 if _roll_held(at, delta) else 1.0, delta * 5.0)
	_roll["pace"] = pace
	_roll["t"] = float(_roll["t"]) + delta * pace
	var u := clampf(float(_roll["t"]) / time, 0.0, 1.0)
	var s := _wheel_ease(u, share) * total
	_roll_aside(s, delta)
	var pose := _roll_pose(s)
	var o := global_position
	var xf := _pose(Vector2(pose.x, pose.y), Vector2(sin(pose.z), cos(pose.z)), null)
	var rolled := (xf.origin - o).dot(xf.basis.z)
	_spin = fposmod(_spin + rolled / _radius, TAU)
	global_transform = xf
	_roll_step += delta * pace
	if _roll_step > WHEEL_FOOT:
		_roll_step = 0.0
		Audio.play("step_" + Audio._surface(self), coupling(), -13.0, 0.1, &"Effects", 3.0)
	if u >= 1.0:
		_end_roll()


## How far along its way (0 to 1) it is at `u` of its time: getting going over the share
## `ramp` of it, steady, and stopping over as much.
static func _wheel_ease(u: float, ramp: float) -> float:
	var a := clampf(ramp, 0.01, 0.5)
	if u < a:
		return u * u / (2.0 * a * (1.0 - a))
	if u > 1.0 - a:
		return 1.0 - (1.0 - u) * (1.0 - u) / (2.0 * a * (1.0 - a))
	return (u - a * 0.5) / (1.0 - a)


## Where it is (x, z, heading) `s` m along the way it is rolling.
func _roll_pose(s: float) -> Vector3:
	var keys: Array[Vector3] = _roll["keys"]
	var lens: PackedFloat32Array = _roll["lens"]
	var i := 0
	while i < lens.size() - 1 and s > lens[i]:
		s -= lens[i]
		i += 1
	return keys[i].lerp(keys[i + 1], clampf(s / maxf(lens[i], 0.001), 0.0, 1.0))


## Whether a townsman or an animal stands in the next WHEEL_LOOK m of its way from `at`
## (m along it): it waits for them, WHEEL_WAIT s in all at the most. Not for one who
## stands against it already (a walker stopped at its side by Vehicle.keep_out waits for
## it to go, and would wait for ever).
func _roll_held(at: float, delta: float) -> bool:
	if float(_roll["held"]) >= WHEEL_WAIT:
		return false
	var total := float(_roll["total"])
	var shapes: Array = _roll["shapes"]
	var beside := _roll_walkers(_roll_pose(at), shapes.slice(0, 1))
	var body := shapes.slice(1) if shapes.size() > 1 else shapes
	for ahead: float in [WHEEL_LOOK * 0.5, WHEEL_LOOK]:
		for who: int in _roll_walkers(_roll_pose(minf(at + ahead, total)), body):
			if not beside.has(who):
				_roll["held"] = float(_roll["held"]) + delta
				return true
	return false


## The townsmen and animals (instance ids) its body, as the boxes `shapes` (_wheel_scene),
## would touch standing at `pose`.
func _roll_walkers(pose: Vector3, shapes: Array) -> Array[int]:
	var out: Array[int] = []
	var q: PhysicsShapeQueryParameters3D = _roll["look"]
	var space := get_world_3d().direct_space_state
	var fwd := Vector2(sin(pose.z), cos(pose.z))
	var right := Vector2(cos(pose.z), -sin(pose.z))
	var turned := Basis(Vector3.UP, pose.z)
	var y := global_position.y + (WHEEL_CHECK.x + WHEEL_CHECK.y) * 0.5
	for shape: Array in shapes:
		var c: Vector2 = shape[1]
		var mid := Vector2(pose.x, pose.y) + right * c.x + fwd * c.y
		q.shape = shape[0]
		q.transform = Transform3D(turned, Vector3(mid.x, y, mid.y))
		for hit: Dictionary in space.intersect_shape(q, 6):
			var id := int(hit.get("collider_id", 0))
			if not out.has(id):
				out.append(id)
	return out


## The farmer on foot where it is about to be (the next WHEEL_AHEAD m of its way from `s`)
## takes a step aside, out of its way to the nearer side, as one does with a trailer in
## hand: it never rolls over his feet or through his view. A wall beside him stops him,
## not it.
func _roll_aside(s: float, delta: float) -> void:
	var p := Game.player as Player
	if not is_instance_valid(p) or p.driving != null or absf(p.global_position.y - global_position.y) > 2.5:
		return
	var feet := Vector2(p.global_position.x, p.global_position.z)
	var total := float(_roll["total"])
	for i in 5:
		var pose := _roll_pose(minf(s + WHEEL_AHEAD * i / 4.0, total))
		if not _wheel_over(pose, feet, WHEEL_KEEP):
			continue
		var right := Vector2(cos(pose.z), -sin(pose.z))
		var lx := (feet - Vector2(pose.x, pose.y)).dot(right)
		var side := float(_roll["side"])
		if absf(lx) > 0.08 or side == 0.0:
			side = 1.0 if lx >= 0.0 else -1.0
		var step := right * side * WHEEL_ASIDE * delta
		if p.test_move(p.global_transform, Vector3(step.x, 0.0, step.y)) and absf(lx) < 0.5:
			# Something stands on that side of him: the other way.
			side = -side
			step = -step
		_roll["side"] = side
		p.move_and_collide(Vector3(step.x, 0.0, step.y))
		return


## At its place: it stands as a body again and goes onto the ball (when the vehicle still
## stands there: one driven off meanwhile leaves it standing on its jockey wheel).
func _end_roll() -> void:
	var to: Variant = _roll.get("to")
	collision_layer = int(_roll["layer"])
	_bed_touch(true)
	_roll = {}
	_wheel_memo.clear()
	if is_instance_valid(to) and (to as Vehicle).is_inside_tree() and towed_by(to as Vehicle) == null:
		var ball := (to as Vehicle).global_transform * hitch_of(to as Vehicle)
		var c := coupling()
		if Vector2(ball.x - c.x, ball.z - c.z).length() < HITCH_REACH and hitch(to as Vehicle):
			return
	_settle = 1


## The roll given up (put somewhere else, loaded from a save): it stands where it is.
func _cancel_roll() -> void:
	if _roll.is_empty():
		return
	collision_layer = int(_roll["layer"])
	_bed_touch(true)
	_roll = {}
	_wheel_memo.clear()
	_settle = 1


## Its bed as something to look at (E, F: BedPoint): not while it rolls, when the box
## passing the farmer's crosshair would open on a second E, or take cargo aboard.
func _bed_touch(on: bool) -> void:
	var bed := get_node_or_null("BedPoint") as CollisionObject3D
	if bed != null:
		bed.collision_layer = 4 if on else 0


# --- Animals aboard ---------------------------------------------------------------------------

## How much room `a` takes (see ROOM).
static func room_of(a: Animal) -> int:
	return int(ROOM.get(a.data.species, 1))


func room_used() -> int:
	_prune()
	var n := 0
	for a in aboard:
		n += room_of(a)
	return n


## Animals that left the world while aboard (sold, gone) are off the list.
func _prune() -> void:
	for i in range(aboard.size() - 1, -1, -1):
		var x: Variant = aboard[i]
		if not is_instance_valid(x) or not (x as Node).is_inside_tree():
			aboard.remove_at(i)
	for book: Dictionary in [_walks, _slots, _ground_was]:
		for k: Variant in book.keys():
			if not is_instance_valid(k) or not (k as Node).is_inside_tree():
				book.erase(k)


func room_total() -> int:
	return int(info.get("room", 0))


## Whether it carries animals at all (the stock trailer).
func takes_animals() -> bool:
	return room_total() > 0


## Lowers (true) or raises the gate. Not while an animal is on the ramp.
func set_gate(open: bool) -> bool:
	if _ramp_pivot == null or open == gate_open:
		return false
	if not _walks.is_empty():
		return false
	gate_open = open
	Audio.play("creak", _gate_point(), -8.0, 0.08, &"Effects", 6.0)
	changed.emit()
	return true


## The gate fully down.
func ramp_down() -> bool:
	return gate_open and _gate >= 0.999


func _gate_point() -> Vector3:
	return global_transform * Vector3(0.0, _floor + 0.4, _box_rear - 0.3)


## Height of what an animal stands on at local `z`: the floor, or the ramp behind it.
func _deck(z: float) -> float:
	if z >= _box_rear:
		return _floor
	return _floor * (1.0 - clampf((_box_rear - z) / _ramp_run, 0.0, 1.0))


## The height (world) an animal's feet find at `p`: the floor and the ramp.
func surface_y(p: Vector3) -> float:
	var l := to_local(p)
	return (global_transform * Vector3(l.x, _deck(l.z), l.z)).y


## Why `a` can't come aboard now ("": it can).
func why_not_aboard(a: Animal) -> String:
	if not takes_animals() or a == null or not is_instance_valid(a):
		return tr("MSG_TRAILER_NO_ANIMALS")
	if room_used() + room_of(a) > room_total():
		return tr("MSG_TRAILER_FULL")
	return ""


## `a` (on the farmer's rope, or standing by) walks up the ramp to its place and rides
## from then on. False when it can't (the gate up, no room: the farmer is told).
func load_animal(a: Animal) -> bool:
	var why := why_not_aboard(a)
	if why == "" and not ramp_down():
		why = tr("MSG_TRAILER_GATE_FIRST")
	if why != "" or aboard.has(a):
		if why != "":
			Game.notify(why, UiTheme.RED)
			Audio.ui("error", -6.0)
		return false
	# The rope stays in the farmer's hand until it stands in its place (AnimalHandler.boarding).
	var p := Game.player as Player
	if a.led and is_instance_valid(p) and p.handler != null and p.handler.led == a:
		p.handler.boarding = true
	elif a.led or a.carried:
		AnimalHandler.lost(a, true)
		a.led = false
	_ground_was[a] = a.rig.ground
	a.set_ridden(true)
	a._badge.visible = false
	a._badge_key = ""
	a.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	a.rig.ground = surface_y
	a.data.away = true
	a.data.away_pos = a.global_position
	aboard.append(a)
	_slots[a] = _slot_for(a)
	var start := to_local(a.global_position)
	start.y = 0.0
	var foot := _box_rear - _ramp_run
	var pts: Array[Vector3] = []
	if start.z > foot - 0.5:
		# Beside the trailer: back along its side and round to the ramp's foot first.
		var side := signf(start.x) if absf(start.x) > 0.1 else 1.0
		pts.append(Vector3(side * maxf(absf(start.x), _footprint.size.x * 0.5 + a.radius() + 0.2), 0.0, foot - 0.9))
	pts.append(Vector3(0.0, 0.0, foot - 0.35))
	pts.append(Vector3(0.0, _floor, _box_rear - 0.05))
	pts.append(_slots[a])
	_walks[a] = {"pts": pts, "i": 0, "pos": start, "yaw": atan2(-(pts[0].x - start.x), -(pts[0].z - start.z)), "out": false}
	Audio.animal_voice(a.data.species, a.data.adult, a.global_position, -9.0)
	changed.emit()
	return true


## Where `a` stands aboard (local): a cow or a horse down the middle, sheep side by side.
func _slot_for(a: Animal) -> Vector3:
	var mid := (_box_front - 0.55 + _box_rear) * 0.5
	if room_of(a) > 1:
		return Vector3(0.0, _floor, mid)
	var taken := 0
	for other in aboard:
		if other != a and is_instance_valid(other) and room_of(other) == 1:
			taken += 1
	var left := taken % 2 == 0
	if taken == 1:
		# The side its mate left free.
		for other in aboard:
			if other != a and _slots.has(other):
				left = (_slots[other] as Vector3).x < 0.0
	return Vector3(0.36 if left else -0.36, _floor, mid + (0.2 if left else -0.2))


## The last animal in comes out down the ramp, onto the farmer's rope when `handler` is
## given and his hands are free. False when there is none or the ramp isn't down.
func unload_animal(handler: AnimalHandler = null) -> bool:
	_prune()
	if aboard.is_empty() or not ramp_down() or not _walks.is_empty():
		return false
	var a := aboard.back() as Animal
	var foot := _box_rear - _ramp_run
	var pts: Array[Vector3] = [Vector3(0.0, _floor, _box_rear - 0.05), Vector3(0.0, 0.0, foot - 0.35), Vector3(0.0, 0.0, foot - 1.5)]
	_walks[a] = {"pts": pts, "i": 0, "pos": _slots.get(a, Vector3(0.0, _floor, 0.0)), "yaw": PI, "out": true, "handler": handler}
	Audio.animal_voice(a.data.species, a.data.adult, a.global_position, -9.0)
	return true


## `a` is the world's again where it stands: off the trailer, on the ground.
func _set_free(a: Animal) -> void:
	aboard.erase(a)
	_walks.erase(a)
	_slots.erase(a)
	if not is_instance_valid(a):
		return
	if _ground_was.has(a):
		a.rig.ground = _ground_was[a]
		_ground_was.erase(a)
	a.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var p := a.global_position
	var yaw := a.global_basis.get_euler().y
	a.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, a.housing.ground_height(p), p.z))
	a.set_ridden(false)


## Every frame: the animals walking in and out along the ramp, those aboard standing in
## their places on the drawn trailer (swaying a little as it goes), a call now and then.
func _ride(delta: float) -> void:
	if aboard.is_empty():
		return
	_prune()
	var xf := get_global_transform_interpolated()
	var speed := absf(tow.forward_speed()) if tow != null and is_instance_valid(tow) else 0.0
	var going := clampf(speed / 6.0, 0.0, 1.0)
	for a: Animal in aboard.duplicate():
		if _walks.has(a):
			_walk(a, xf, delta)
			continue
		var slot: Vector3 = _slots.get(a, Vector3(0.0, _floor, 0.0))
		var phase := float(a.data.id) * 1.7
		var sway := sin(_clock * 2.1 + phase) * 0.012 * going
		var nod := sin(_clock * 3.3 + phase) * 0.008 * going
		var b := Basis(Vector3.UP, PI + sin(_clock * 0.37 + phase) * 0.06) * Basis(Vector3.BACK, sway * 2.0)
		a.global_transform = xf * Transform3D(b, slot + Vector3(sway, 0.0, nod))
		a.rig.animate(delta, 0.0, AnimalRig.Mode.IDLE)
	if going > 0.15:
		_voice -= delta
		if _voice <= 0.0 and not aboard.is_empty():
			_voice = _rng.randf_range(VOICE_EVERY.x, VOICE_EVERY.y)
			var who := aboard[_rng.randi() % aboard.size()]
			if is_instance_valid(who):
				Audio.animal_voice(who.data.species, who.data.adult, who.global_position + Vector3(0, 0.8, 0), -7.0)


## One frame of `a`'s walk along its points (local): up the ramp to its place, or down it
## and out.
func _walk(a: Animal, xf: Transform3D, delta: float) -> void:
	var w: Dictionary = _walks[a]
	var pts: Array = w["pts"]
	var pos: Vector3 = w["pos"]
	var step := BOARD_PACE * delta
	var yaw: float = w["yaw"]
	while step > 0.0 and int(w["i"]) < pts.size():
		var to: Vector3 = pts[int(w["i"])]
		var flat := Vector2(to.x - pos.x, to.z - pos.z)
		var d := flat.length()
		if d > 0.01:
			yaw = lerp_angle(yaw, atan2(-flat.x, -flat.y), clampf(delta * 6.0, 0.0, 1.0))
		if d <= step:
			pos = to
			step -= d
			w["i"] = int(w["i"]) + 1
		else:
			pos += Vector3(flat.x, 0.0, flat.y) / d * step
			step = 0.0
	pos.y = _deck(pos.z)
	var done := int(w["i"]) >= pts.size()
	if done and not bool(w["out"]):
		# In its place: round to face the road.
		yaw = lerp_angle(yaw, PI, clampf(delta * 5.0, 0.0, 1.0))
		done = absf(angle_difference(yaw, PI)) < 0.05
	w["pos"] = pos
	w["yaw"] = yaw
	a.global_transform = xf * Transform3D(Basis(Vector3.UP, yaw), pos)
	a.rig.animate(delta, 0.0 if int(w["i"]) >= pts.size() else BOARD_PACE, AnimalRig.Mode.WALK if int(w["i"]) < pts.size() else AnimalRig.Mode.IDLE)
	if not done:
		return
	if bool(w["out"]):
		var handler := w.get("handler") as AnimalHandler
		_set_free(a)
		if handler != null and is_instance_valid(handler) and not handler.busy() and a.can_lead():
			handler.lead(a)
		else:
			a._settle_where_left()
		changed.emit()
	else:
		_walks.erase(a)
		# In its place: the rope comes off.
		if a.led:
			AnimalHandler.lost(a, true)
			a.led = false
		a.data.away = true
		Audio.play("plank", a.global_position, -12.0, 0.1, &"Effects", 5.0)
		changed.emit()


## An animal that was aboard in a save is back in its place at once.
func _seat(a: Animal) -> void:
	if a == null or aboard.has(a) or why_not_aboard(a) != "":
		return
	_ground_was[a] = a.rig.ground
	a.set_ridden(true)
	a._badge.visible = false
	a._badge_key = ""
	a.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	a.rig.ground = surface_y
	a.data.away = true
	aboard.append(a)
	_slots[a] = _slot_for(a)


## The day ends: whoever still rides is taken to its housing for the night.
func _on_day_ending() -> void:
	_prune()
	if aboard.is_empty():
		return
	for a: Animal in aboard.duplicate():
		_set_free(a)
		if is_instance_valid(a) and a.is_inside_tree() and a.housing:
			a.data.away = false
			a.teleport_home(a.housing.has_shelter() and a.housing.can_pass())
	Game.notify(tr("MSG_TRAILER_NIGHT"), UiTheme.GOLD_SOFT)


# --- Interaction ---------------------------------------------------------------------------

## Where on it the farmer looks: &"hitch" (the tongue) or &"body".
func _zone(player: Node) -> StringName:
	var p := player as Player
	if p == null:
		return &"body"
	var at := p.ray.get_collision_point() if p.ray.is_colliding() else p.global_position
	return &"hitch" if to_local(at).z > _box_front + 0.12 else &"body"


func _led_by(player: Node) -> Animal:
	var p := player as Player
	return p.handler.led if p != null and p.handler != null and is_instance_valid(p.handler.led) else null


func interact_prompt(player: Node) -> String:
	if not owned:
		return tr("ACTION_TRAILER_FEE" if kind == &"trailer_stock" else "ACTION_BUY_VEHICLE") % UiTheme.money(price)
	if _zone(player) == &"hitch":
		return tr("ACTION_TRAILER_UNHITCH") if tow != null else tr("ACTION_TRAILER_HITCH")
	if not takes_animals():
		return tr("ACTION_OPEN_BED")
	var led := _led_by(player)
	if led != null and gate_open:
		return tr("ACTION_TRAILER_LOAD") % led.data.name
	return tr("ACTION_TRAILER_GATE_UP") if gate_open else tr("ACTION_TRAILER_GATE_DOWN")


func info_prompt() -> String:
	return tr("ACTION_OPEN_BED") if owned and cargo.capacity > 0 else ""


## A plain line under the prompts: who rides in it, or how to hitch it.
func hint_prompt() -> String:
	if not owned:
		return tr("HINT_TRAILER_GRANDPA") if kind == &"trailer_stock" else tr(info.get("desc_key", ""))
	var p := Game.player as Player
	if is_instance_valid(p) and _zone(p) == &"hitch":
		if tow != null or tow_in_reach() != null or not _roll.is_empty():
			return ""
		var why := String(wheel_choice()["why"])
		return "" if why == "" else tr(why)
	if not takes_animals():
		return ""
	_prune()
	var names := PackedStringArray()
	for a in aboard:
		names.append(a.data.name)
	if names.is_empty():
		return tr("HINT_TRAILER_EMPTY") % room_total()
	return tr("HINT_TRAILER_ABOARD") % [UiTheme.join_list(names), room_used(), room_total()]


## G at the open gate: the rope back on the last animal in ("" when there is nothing to
## take out).
func handle_line(player: Node) -> String:
	_prune()
	if not owned or aboard.is_empty() or not ramp_down() or not _walks.is_empty() or _zone(player) == &"hitch":
		return ""
	return "G (%s)" % (tr("ACTION_TRAILER_UNLOAD") % (aboard.back() as Animal).data.name)


func handle_pressed(player: Node) -> void:
	if handle_line(player) == "":
		return
	var p := player as Player
	unload_animal(p.handler if p else null)


func interact(player: Node) -> void:
	if not owned:
		_buy()
		return
	if _zone(player) == &"hitch":
		if tow != null:
			unhitch()
			return
		if not _roll.is_empty():
			return
		var v := tow_in_reach()
		if v != null:
			hitch(v)
			return
		# No ball at the coupling: wheeled over to a vehicle standing near, when it can be.
		var plan := wheel_choice(true)
		if String(plan["why"]) != "":
			Game.notify(tr(String(plan["why"])), UiTheme.GOLD_SOFT)
			Audio.ui("error", -8.0)
			return
		_start_roll(plan)
		return
	if not takes_animals():
		Game.hud.open_storage(self)
		return
	var led := _led_by(player)
	if led != null and gate_open:
		if ramp_down():
			load_animal(led)
		return
	if not set_gate(not gate_open) and not _walks.is_empty():
		Game.notify(tr("MSG_TRAILER_WAIT"), UiTheme.GOLD_SOFT)


## Grandpa's is paid for at once (the tyre bill); the cargo trailer asks for a second E.
func _buy() -> void:
	if Economy.money < price:
		Game.notify(tr("MSG_NEED_GOLD") % UiTheme.money(price - Economy.money), UiTheme.RED)
		Audio.ui("error", -6.0)
		return
	if kind != &"trailer_stock" and _confirm <= 0.0:
		_confirm = CONFIRM_TIME
		Game.notify(tr("MSG_TRAILER_CONFIRM") % [display_name(), UiTheme.money(price)], UiTheme.GOLD_SOFT)
		return
	if not Economy.spend(price, "REPORT_VEHICLE"):
		return
	owned = true
	_confirm = 0.0
	Audio.ui("confirm")
	Game.notify(tr("MSG_TRAILER_GRANDPA" if kind == &"trailer_stock" else "MSG_TRAILER_BOUGHT") % display_name(), UiTheme.GREEN)
	changed.emit()


# --- Save -----------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var d := super.save_data()
	var to: Variant = tow
	if not _roll.is_empty() and is_instance_valid(_roll.get("to")):
		# Saved while it is wheeled over: coupled, in its place behind that vehicle.
		to = _roll["to"]
		d["xform"] = _roll["end"]
	d["tow"] = String((to as Vehicle).kind) if to != null and is_instance_valid(to) else ""
	d["gate"] = gate_open
	_prune()
	var ids := []
	for a in aboard:
		# Where it stands now: a save without the trailer would find it there.
		a.data.away = true
		a.data.away_pos = a.global_position
		ids.append(a.data.id)
	d["aboard"] = ids
	return d


func load_data(d: Dictionary) -> void:
	_cancel_roll()
	if not bool(d.get("owned", owned)):
		# Not the farmer's yet: it stands in its bay at the dealer's (TrailerYard), not where
		# an older save had it (at the kerb in the street).
		d = d.duplicate()
		d["xform"] = TrailerYard.bay_place(kind)
	super.load_data(d)
	gate_open = bool(d.get("gate", false))
	_gate = 1.0 if gate_open else 0.0
	_pending = {"tow": String(d.get("tow", "")), "aboard": d.get("aboard", [])}
	# Once every vehicle stands where its save left it.
	_restore.call_deferred()


func _restore() -> void:
	var want := String(_pending.get("tow", ""))
	if want != "":
		for v: Vehicle in Vehicle.all:
			if String(v.kind) == want and not v is Trailer and v.is_inside_tree():
				hitch(v, true)
				_jockey_up = 1.0
				break
	if tow == null:
		_settle = 2
	for id: Variant in _pending.get("aboard", []):
		var data := Animals.by_id(int(id))
		if data != null:
			_seat(Animals.node_of(data))
	_pending = {}
