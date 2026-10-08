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
## Hitching is done one way only, by backing up: drive past the trailer, back a vehicle up
## to its tongue in line with it until the ball is within reach of the coupling (HITCH_REACH;
## a little more, HITCH_REACH_LINED, while the vehicle plainly stands in line with it), get
## out, E at the tongue ("Römorku bağla"; a clunk, the jockey wheel winds up); E there again
## unhitches it. What shows the way: a marker over the coupling for a driver who is near
## (amber, green in reach) and, on the ground ahead of the tongue, the place where the
## vehicle should stand and how it should point (_approach: an outline and chevrons that
## point at the tongue, draped over the ground, the marker's colour), for a driver who is
## near and, on foot too, while the trailer still waits in the dealer's bay or the story
## teaches the hitch (TrailerGoals.teaching). At the tongue with no ball in reach a line
## says what to do.
## Not the farmer's yet (Grandpa's with its tyre bill owed, the cargo trailer for sale) it
## is paid for at Kemal's desk in the dealership (DealerScreen), never at the trailer: its
## line says so.
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
## Plainly lined up (the vehicle's heading within HITCH_LINED of the trailer's line and its
## ball no further than HITCH_LINED_SIDE to either side of that line), the ball may stand
## this far from the coupling: a driver who came up straight but stopped a touch early is
## not sent back into the cab.
const HITCH_REACH_LINED := 1.25
const HITCH_LINED := deg_to_rad(14.0)
const HITCH_LINED_SIDE := 0.6
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
## The approach drawn on the ground ahead of the tongue: how far off it shows (m), how long
## the lane of chevrons is from the coupling (m), their spacing, the lane's width (a
## pickup's and a little), the length of the place outlined for the vehicle when nobody
## drives (a pickup's), the width of its lines and how far over the ground they lie (m).
const APPROACH_RANGE := 32.0
const APPROACH_LANE := 9.6
const APPROACH_EVERY := 1.2
const APPROACH_WIDTH := 2.3
const APPROACH_LENGTH := 5.55
const APPROACH_LINE := 0.09
const APPROACH_LIFT := 0.035
## Seconds between the calls of animals riding along.
const VOICE_EVERY := Vector2(9.0, 24.0)
## Room an animal takes (sheep: 1).
const ROOM := {&"cow": 2, &"horse": 2}
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
var _rng := RandomNumberGenerator.new()
## What a load asked to be put back once every vehicle is restored.
var _pending := {}
## The approach on the ground (see the class comment): top level, in the world's frame;
## where the trailer stood and how long the outlined place was when it was last laid out.
var _approach: MeshInstance3D
var _approach_at := Transform3D()
var _approach_len := 0.0


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
	# The strips on the ground are seen from either side.
	_guide_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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


## The farmer's vehicle whose ball is in reach of the coupling (null: none): within
## HITCH_REACH, or HITCH_REACH_LINED while it stands plainly in line with the trailer
## (lined_up).
func tow_in_reach() -> Vehicle:
	var c := coupling()
	var best: Vehicle = null
	var best_d := INF
	for v: Vehicle in Vehicle.all:
		if v is Trailer or not v.owned or not v.is_inside_tree() or towed_by(v) != null:
			continue
		var ball := v.global_transform * hitch_of(v)
		var d := Vector2(ball.x - c.x, ball.z - c.z).length()
		# Backed up to it, not nosed in from the side.
		var back := -v.global_basis.z
		var to_me := global_position - ball
		var reach := HITCH_REACH_LINED if lined_up(v) else HITCH_REACH
		if d < reach and d < best_d and absf(ball.y - c.y) < HITCH_RISE and Vector2(back.x, back.z).dot(Vector2(to_me.x, to_me.z)) > 0.0:
			best_d = d
			best = v
	return best


## Whether `v` stands plainly in line with the trailer, tail to its tongue: its heading
## within HITCH_LINED of the trailer's and its ball within HITCH_LINED_SIDE of the line
## that runs out along the tongue.
func lined_up(v: Vehicle) -> bool:
	var mine := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var its := Vector2(v.global_basis.z.x, v.global_basis.z.z).normalized()
	if absf(mine.angle_to(its)) > HITCH_LINED:
		return false
	var ball := v.global_transform * hitch_of(v)
	var c := coupling()
	var off := Vector2(ball.x - c.x, ball.z - c.z)
	return absf(off.dot(Vector2(mine.y, -mine.x))) < HITCH_LINED_SIDE and off.dot(mine) > -0.3


## Onto `v`'s ball: the jockey wheel winds up and the trailer follows from now on.
func hitch(v: Vehicle, quiet := false) -> bool:
	if v == null or v == tow or v is Trailer or towed_by(v) != null:
		return false
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
	super.teleport(xf)
	if tow == null:
		_settle = 2


func _physics_process(delta: float) -> void:
	if tow != null:
		if not is_instance_valid(tow) or not tow.is_inside_tree():
			tow = null
			_settle = 1
		else:
			_tow_tick(delta)
			return
	# Parked: never lost either (Vehicle._watch_lost; behind a tow it goes where that goes,
	# and is stood straight behind it when the tow is put back, TOW_JUMP).
	_watch_lost(delta)
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


## Behind a tow that was itself just brought back (a save with the pair out of the world):
## one line for the two of them, the tow's.
func _tell_back() -> void:
	if tow != null and is_instance_valid(tow) and Time.get_ticks_msec() - tow._told_back < 60000:
		return
	super._tell_back()


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
	_note_safe()


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
## unhitched; green and a line once his ball is in reach and he can get out and couple it.
## The approach on the ground goes with it (_update_approach).
func _update_guide() -> void:
	var p := Game.player as Player
	var mine := owned and tow == null and is_instance_valid(p)
	var driver := mine and p.driving != null and not p.driving is Trailer and towed_by(p.driving) == null
	# How far off the farmer is (his vehicle when he drives): nothing is looked for or
	# drawn for one far away.
	var off := INF
	if mine:
		off = (p.driving.global_position if p.driving != null else p.global_position).distance_to(coupling())
	var show := driver and off < GUIDE_RANGE
	var ready := false
	if off < APPROACH_RANGE:
		var v := tow_in_reach()
		ready = v != null and (not driver or v == p.driving)
	_guide_mat.albedo_color = Color(0.3, 1.0, 0.35, 0.95) if ready else Color(1.0, 0.7, 0.15, 0.9)
	_update_approach(p, off < APPROACH_RANGE, driver)
	if show != _guide.visible:
		_guide.visible = show
		_in_reach_told = false
	if not show:
		return
	_guide.rotation.y = _clock * 1.2
	if ready and not _in_reach_told:
		_in_reach_told = true
		Game.notify(tr("MSG_TRAILER_IN_REACH"), UiTheme.GREEN)
	elif not ready and p.driving.global_position.distance_to(coupling()) > HITCH_REACH_LINED + 2.5:
		_in_reach_told = false


# --- The approach on the ground ---------------------------------------------------------------

## Whether the approach is drawn now: the trailer his and unhitched, the farmer within
## APPROACH_RANGE, and either at the wheel of a vehicle that could take it, or on foot
## while it still waits in the dealer's bay or the story teaches the hitch.
func approach_shown() -> bool:
	return _approach != null and _approach.visible


func _update_approach(p: Player, near: bool, driver: bool) -> void:
	var show := near and (driver or (p.driving == null and TrailerGoals.teaching(self)))
	if not show:
		if _approach != null:
			_approach.visible = false
		return
	var length := APPROACH_LENGTH
	if driver:
		length = p.driving._footprint.size.y + 0.25
	if _approach == null:
		_approach = MeshInstance3D.new()
		_approach.name = "HitchApproach"
		_approach.top_level = true
		_approach.material_override = _guide_mat
		_approach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_approach.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_approach.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_approach)
		_approach_len = 0.0
	if _approach_len == 0.0 or absf(length - _approach_len) > 0.05 or global_position.distance_to(_approach_at.origin) > 0.05 \
			or global_basis.z.dot(_approach_at.basis.z) < 0.9995:
		_approach.global_transform = Transform3D.IDENTITY
		_approach.mesh = _approach_mesh(length)
		_approach_at = global_transform
		_approach_len = length
	_approach.visible = true


## Where the middle of the place outlined for the vehicle is and how it points: on the
## ground ahead of the tongue, in line with the trailer, nose away from it (its heading the
## trailer's). `length`: the vehicle's.
func approach_place(length := APPROACH_LENGTH) -> Transform3D:
	var c := coupling()
	var f := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var mid := Vector2(c.x, c.z) + f * (length * 0.5 + 0.05)
	return Transform3D(Basis(Vector3.UP, atan2(f.x, f.y)), Vector3(mid.x, _ground_under(mid, c.y), mid.y))


## The approach as one mesh in the world's frame, every corner on the ground under it
## (the bay's concrete, the pavement, the bevelled kerb, the street): the outline of the
## place a vehicle `length` m long stands in with its ball on the coupling, a bar across
## its far end for the nose, and a lane of chevrons out from the tongue that point at it.
func _approach_mesh(length: float) -> ArrayMesh:
	var c := coupling()
	var f := Vector2(global_basis.z.x, global_basis.z.z).normalized()
	var r := Vector2(f.y, -f.x)
	var o := Vector2(c.x, c.z)
	var half := APPROACH_WIDTH * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The place: two long sides and the nose's bar, in short pieces so they follow the kerb.
	for side: float in [-1.0, 1.0]:
		_approach_strip(st, o + r * side * half + f * 0.1, o + r * side * half + f * (length + 0.1), APPROACH_LINE)
	_approach_strip(st, o - r * half + f * (length + 0.1), o + r * half + f * (length + 0.1), APPROACH_LINE * 2.0)
	# The lane: chevrons from its far end to the tongue, each pointing at the trailer.
	var d := 0.9
	while d <= APPROACH_LANE:
		var tip := o + f * d
		for side: float in [-1.0, 1.0]:
			_approach_strip(st, tip, tip + f * 0.5 + r * side * 0.62, APPROACH_LINE * 1.6)
		d += APPROACH_EVERY
	return st.commit()


## A flat strip from `a` to `b` (world x, z), `width` m wide, in pieces no longer than half
## a metre, each corner APPROACH_LIFT over the ground under it.
func _approach_strip(st: SurfaceTool, a: Vector2, b: Vector2, width: float) -> void:
	var along := b - a
	var n := maxi(ceili(along.length() / 0.5), 1)
	var side := Vector2(along.y, -along.x).normalized() * width * 0.5
	var near := coupling().y
	var last: Array[Vector3] = []
	for i in n + 1:
		var m := a + along * (float(i) / n)
		var pair: Array[Vector3] = []
		for q: Vector2 in [m - side, m + side]:
			pair.append(Vector3(q.x, _ground_under(q, near) + APPROACH_LIFT, q.y))
		if not last.is_empty():
			for v: Vector3 in [last[0], last[1], pair[1], last[0], pair[1], pair[0]]:
				st.add_vertex(v)
		last = pair


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
		# Paid for at Kemal's desk, not here (hint_prompt says so).
		return ""
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
		if kind == &"trailer_stock":
			return tr("HINT_TRAILER_GRANDPA") % UiTheme.money(price)
		return tr("HINT_TRAILER_FOR_SALE") % [display_name(), UiTheme.money(price)]
	var p := Game.player as Player
	if is_instance_valid(p) and _zone(p) == &"hitch":
		# No ball at the coupling: how it is hitched.
		return "" if tow != null or tow_in_reach() != null else tr("HINT_TRAILER_BACK_UP")
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
		return
	if _zone(player) == &"hitch":
		if tow != null:
			unhitch()
			return
		var v := tow_in_reach()
		if v != null:
			hitch(v)
			return
		# No ball at the coupling: it is backed up to, there is no other way.
		Game.notify(tr("HINT_TRAILER_BACK_UP"), UiTheme.GOLD_SOFT)
		Audio.ui("error", -8.0)
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


## Paid for at Kemal's desk (DealerScreen): Grandpa's tyre bill, or the cargo trailer's
## price. It is the farmer's from now on and waits in the bay; Kemal says where it stands
## and how it is taken (his own line). False when the money is short or it is his already.
func pay() -> bool:
	if owned or not Economy.spend(price, "REPORT_VEHICLE"):
		return false
	owned = true
	Audio.ui("confirm")
	Game.notify(tr("MSG_TRAILER_GRANDPA" if kind == &"trailer_stock" else "MSG_TRAILER_BOUGHT") % display_name(), UiTheme.GREEN)
	changed.emit()
	return true


# --- Save -----------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var d := super.save_data()
	d["tow"] = String(tow.kind) if tow != null and is_instance_valid(tow) else ""
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
