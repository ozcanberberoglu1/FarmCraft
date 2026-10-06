class_name Wolf
extends Node3D
## A grey wolf of a pack raiding the farm at night: a WolfRig body that a raid director
## (WolfRaids) spawns at the forest's edge (Wolf.spawn) and drives with set_goal:
##   &"idle"           stands about where it is, looking round.
##   &"approach"       trots to `target` (a Vector3; lopes when it is far) and waits there.
##   &"prowl"          circles `target` (a Vector3 or a Node3D) 8-15 m out, each wolf at
##                     its own distance and way round, stopping to sniff the ground or to
##                     look in at it.
##   &"hunt"           goes after `target` (a farm Animal): runs it down and bites it
##                     (`bit`), again and again until told otherwise. An animal in a
##                     building it reaches only through an open door; behind a shut one
##                     it prowls round the building instead. Low fences it leaps.
##   &"attack_player"  goes for the farmer (`target`) and keeps at him: a short stalk,
##                     low and growling, then bite after bite. Up to PRESSERS wolves press
##                     him at once, each from its own side: in close, a crouch and a snarl
##                     (WINDUP_TIME: his moment to step back or aside), a lunge and a bite
##                     (`bit`, PlayerState.hurt), a step back and round, and in again; the
##                     rest of the pack circles close by, snarling, and takes a turn. Into
##                     a coop or barn whose door stands open it follows him by the door and
##                     goes on inside. In a vehicle it circles the vehicle VEHICLE_TIME,
##                     then gives up (`gave_up`) and runs off; in the farmhouse, the
##                     warehouse or behind a shut door it prowls round outside a while,
##                     then gives up too.
##   &"howl"           stops, sits and howls, now and then, until told otherwise.
##   &"flee"           runs flat out, tail tucked, to `target` (a Vector3 far off) and is
##                     gone (freed) when there or out of sight far away. Held up on the way
##                     (`stuck`: a fence corner, a door shut on it) it tries another way out
##                     of the valley, and is gone as soon as nobody is looking at it (or the
##                     farmer is far off): none is left standing on the farm.
## It never goes into a building (save the open coop or barn of a hunted animal or of the
## farmer); in one it has no more business in (its prey taken, told to prowl or to go) it
## first trots back out by the door it came in by (_leave_building). It keeps FIRE_KEEP off
## a burning campfire, out of the pond and out of town. It steers round what is in its
## way by short rays (fences, walls, trees, rocks), round a vehicle by its corners, and
## keeps its distance from the rest of the pack. It never steps into a vehicle (its body
## would shove it, Vehicle.keep_out).
##
## It can be hit (group &"hittable", take_hit): it flinches and yelps, staggers off and
## backs away a moment (a blow that misses it, dodge, it only jumps aside from; on the
## move it is harder to hit, evasion); at no health left it falls dead (`died`) and lies there as a
## carcass: E "take the pelt" puts a wolf pelt in the bag and the carcass is gone; left
## alone it goes by itself CARCASS_HOURS later (a night slept through not counted: it is
## still there in the morning), when nobody is looking at it.
## A collider on the animal layer (the farmer bumps into it, hits find it); the body is
## posed only near the camera (less often off screen). While the game is paused (the
## pause menu, the settings: frozen()) it stands frozen as it is: no step, no bite
## behind the menu.

## A bite landed on `target` (a farm Animal, or the farmer).
signal bit(target: Node3D)
## It was killed.
signal died(wolf: Wolf)
## It gave up on the farmer (shut in a vehicle or a building) and is running off.
signal gave_up(wolf: Wolf)

const GROUP := &"wolves"
const GOALS: Array[StringName] = [&"idle", &"approach", &"prowl", &"hunt", &"attack_player", &"howl", &"flee"]
const MAX_HEALTH := 100.0
const PELT := &"wolf_pelt"
## Speeds (m/s): walking, trotting, loping (a canter), flat out, stalking.
const WALK := 1.15
const TROT := 2.7
const LOPE := 4.8
const RUN := 8.5
const STALK := 0.6
const ACCEL := 7.0
## Turning (rad/s) when slow; running, it turns no tighter than TURN_GRIP (m/s²) lets it.
const TURN_RATE := 4.0
const TURN_GRIP := 11.0
## Prowling round something: how far out (m).
const PROWL_RADIUS := Vector2(8.0, 15.0)
## Round the farmer: how far out the wolves not pressing him circle (m), how close a
## bite reaches (an animal's too), the least time (s) between one wolf's bites.
const RING_RADIUS := Vector2(2.8, 4.0)
const BITE_REACH := 1.4
const ANIMAL_REACH := 0.95
const BITE_COOLDOWN := 1.4
## Pressing him: how many wolves at once, how many lunges each before it may leave its
## place to one circling, and how long it may try to get at him before it does anyway.
const PRESSERS := 2
const PRESS_BITES := 2
const PRESS_TIME := 7.0
## The lunge at him: how near (m) it winds up, the wind-up (s; crouched and snarling, the
## aim fixed for its last part: his moment to step back or aside), the spring's top
## speed (m/s), how far round (rad/s) it can still turn in the air, how near his feet its
## body stops (m), and the least time between any two lunges at him (s).
const WINDUP_RANGE := 2.1
const WINDUP_TIME := 0.4
const WINDUP_AIM := 0.6
const LUNGE_SPEED := 7.5
const LUNGE_TURN := 1.5
const LUNGE_STOP := 0.85
const LUNGE_GAP := 0.75
## Before the first bite a short stalk (s, counted within STALK_NEAR m of him); after
## each lunge a step back and round (s).
const STALK_TIME := Vector2(0.8, 1.6)
const STALK_NEAR := 8.0
const RECOVER_TIME := Vector2(0.45, 0.85)
## What a bite on the farmer does (PlayerState.hurt: about five bites knock him out).
const BITE_HURT := 20.0
## Round a vehicle the farmer has shut himself in: how far out (m) and how long (s)
## before it gives up.
const VEHICLE_RING := 4.8
const VEHICLE_TIME := Vector2(15.0, 25.0)
## Outside a building he is in: how long it prowls (s) before giving up.
const INDOORS_TIME := Vector2(20.0, 35.0)
## Seconds a howl lasts (the head up, the mouth working).
const HOWL_TIME := 4.2
## A burning campfire keeps it this far off (m).
const FIRE_KEEP := 6.0
## How far from other wolves it keeps (m), and its body's reach for walls.
const SPACING := 2.2
const BODY_REACH := 0.75
## A vehicle: how far its body keeps off one (m from the vehicle's body: half its own
## length, so turning it never swings into it), and how much wider it goes round one in
## its way (Vehicle.way_round; its probes alone took a car for a low fence to leap, and
## looked no further than the farmer standing beside it).
const VEHICLE_KEEP := 0.66
const VEHICLE_BERTH := 0.9
## A fence or wall up to this high (m) it leaps when it has to (hunting, fleeing,
## going for the farmer).
const LEAP_HEIGHT := 1.3
const LEAP_TIME := 0.55
## Fleeing: it has got nowhere (under STUCK_MOVE m) for STUCK_TIME s: stuck. Stuck, or
## still not away after FLEE_LONG s, it is gone once the farmer isn't looking at it or is
## GONE_FAR m off (he never sees one stand about, or vanish).
const STUCK_MOVE := 2.0
const STUCK_TIME := 5.0
const FLEE_LONG := 40.0
const GONE_FAR := 60.0
## A carcass goes after this many game hours (when nobody is looking at it).
const CARCASS_HOURS := 6.0
const ANIMATE_RANGE := 70.0
const SHOW_RANGE := 130.0
## The farm valley it keeps to (it comes from, and goes back to, the forest round it).
const LAND_RADIUS := 115.0

## Microseconds all wolves spent posing their bodies, and thinking and moving (cost
## gauges for tests).
static var anim_usec := 0
static var think_usec := 0
## The wolves pressing each target (instance id -> Array of wolves) and when the next
## lunge at it may come (game seconds by _clock).
static var _turns := {}
static var _next_go := {}
## Game seconds (time-scaled, paused with the wolves), advanced once a physics tick.
static var _clock := 0.0
static var _clock_tick := -1

var goal: StringName = &"idle"
var target: Variant = null
var health := MAX_HEALTH
var rig: WolfRig
var dead := false
## Bites landed, and times hit (for the director and tests).
var bites := 0
var hits := 0
## How far its body reaches out from hit_center (m; the knife's reach, Combat).
var hit_radius := 0.42

var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _on_screen: VisibleOnScreenNotifier3D
var _rng := RandomNumberGenerator.new()
var _speed := 0.0
var _want_speed := 0.0
var _yaw := 0.0
var _floor_y := 0.0
var _goal_t := 0.0
var _anim_acc := 0.0
## Steering: when it next looks ahead, the heading it takes round something in its way
## (INF: none) and for how long.
var _probe_t := 0.0
var _detour := INF
var _detour_t := 0.0
## Circling: its own distance out and way round; a pause (s left) and what it does then.
var _ring_r := 10.0
var _ring_dir := 1.0
var _pause_t := 0.0
var _pause_wait := 6.0
var _sniff := false
## At the farmer: pressing him (one of PRESSERS), for how long, its lunges since; the
## stalk left (s); the wind-up's clock (-1: none) and the lunge's (-1: none), the heading
## a lunge at him keeps; backing off (s); the time to its next bite.
var _going_in := false
var _dart_t := 0.0
var _press_bites := 0
var _stalk_t := 0.0
var _windup_t := -1.0
var _lunge_t := -1.0
var _lunge_yaw := 0.0
var _back_off := 0.0
var _bite_cd := 0.0
## Giving up on the farmer: seconds left (-1: not counting), and why.
var _give_up_t := -1.0
var _give_up_why := &""
## Hit: staggering away (velocity, m/s) for a moment; backing off after.
var _stagger := Vector3.ZERO
var _stagger_t := 0.0
## Leaping a fence: seconds into it (-1: not leaping), from what height.
var _leap_t := -1.0
var _sound_t := 2.0
var _howl_t := 3.0
## Game minutes when it died (-1 alive); the carcass posed for good.
var _died_at := -1.0
var _laid_out := false
## Waypoints to go through first (into a coop by its door).
var _path: Array[Vector3] = []
## The housing whose building it may go into (a hunted animal's or the farmer's, door
## open).
var _inside_ok: AnimalHousing = null
## The building its waypoints lead into or out of (after the farmer).
var _path_for: AnimalHousing = null
## The building it is on its way out of by the door (_leave_building).
var _leaving: AnimalHousing = null
## Fleeing and getting nowhere (see STUCK_TIME): where it last got on from, for how long
## it has not since, and how often it turned another way.
var stuck := false
var _stuck_from := Vector3.INF
var _stuck_t := 0.0
var _stuck_turns := 0


func _init() -> void:
	name = "Wolf"


## A wolf standing on the ground at `at` under `parent`, facing the farm.
static func spawn(parent: Node, at: Vector3) -> Wolf:
	var w := Wolf.new()
	parent.add_child(w, true)
	var p := Vector3(at.x, TerrainData.height(at.x, at.z), at.z)
	w.global_position = p
	w._yaw = atan2(p.x, p.z)
	w.rotation.y = w._yaw
	w._floor_y = p.y
	w.reset_physics_interpolation()
	return w


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"hittable")
	_rng.randomize()
	rig = WolfRig.make()
	add_child(rig)
	rig.ground = _ground_at
	_body = AnimatableBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 16
	_body.collision_mask = 0
	_body.sync_to_physics = false
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.2
	cap.height = 1.25
	_shape.shape = cap
	_body.add_child(_shape)
	add_child(_body)
	_on_screen = VisibleOnScreenNotifier3D.new()
	_on_screen.aabb = AABB(Vector3(-0.5, 0, -1.1), Vector3(1.0, 1.1, 2.4))
	add_child(_on_screen)
	_yaw = rotation.y
	_floor_y = global_position.y
	_ring_r = _rng.randf_range(PROWL_RADIUS.x, PROWL_RADIUS.y)
	_ring_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_place_collider()
	if not Settings.changed.is_connected(rig.apply_quality):
		Settings.changed.connect(rig.apply_quality)
	Events.time_skipped.connect(_on_time_skipped)
	for mi in rig.meshes:
		mi.visibility_range_end = SHOW_RANGE
		mi.visibility_range_end_margin = 8.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Moved in physics ticks: drawn between them.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_snap_to_ground.call_deferred()


func _exit_tree() -> void:
	_release_turn()


# --- The contract ----------------------------------------------------------------------------

## What it does now (see the class notes).
func set_goal(new_goal: StringName, new_target: Variant = null) -> void:
	if dead:
		return
	if not new_goal in GOALS:
		push_warning("Wolf: unknown goal %s" % new_goal)
		return
	if new_goal != goal or not _same_target(new_target):
		_goal_t = 0.0
		_give_up_t = -1.0
		_pause_t = 0.0
		_pause_wait = _rng.randf_range(3.0, 8.0)
		_path.clear()
		_path_for = null
		_inside_ok = null
		_leaving = null
		stuck = false
		_stuck_from = Vector3.INF
		_stuck_t = 0.0
		_stuck_turns = 0
		_release_turn()
		_going_in = false
		_back_off = 0.0
		_windup_t = -1.0
		_lunge_t = -1.0
		_detour = INF
		if new_goal == &"prowl":
			_ring_r = _rng.randf_range(PROWL_RADIUS.x, PROWL_RADIUS.y)
		elif new_goal == &"attack_player":
			_ring_r = _rng.randf_range(RING_RADIUS.x, RING_RADIUS.y)
			_stalk_t = _rng.randf_range(STALK_TIME.x, STALK_TIME.y)
			_press_bites = 0
	goal = new_goal
	target = new_target
	if goal == &"howl":
		_howl_t = HOWL_TIME


## Hit for `damage` from `from` (a knife's cut, an arrow): it flinches, yelps and
## staggers away; at no health left it falls dead.
func take_hit(damage: float, from: Vector3, kind: StringName) -> void:
	if dead:
		return
	hits += 1
	health -= damage
	var local := to_local(from)
	# +1: the blow came from its right.
	var side := 1.0 if local.x > 0.0 else -1.0
	var away := _flat(global_position - from)
	away = away.normalized() if away.length() > 0.01 else global_transform.basis.z
	if health <= 0.0:
		health = 0.0
		_die(-side, kind)
		return
	rig.flinch(side)
	_sound("wolf_yelp", 0.0)
	_stagger = away * (2.8 if kind == &"axe" else (2.4 if kind == &"knife" else 1.6))
	_stagger_t = 0.3
	_back_off = maxf(_back_off, _rng.randf_range(0.8, 1.4))
	_release_turn()
	_going_in = false
	_windup_t = -1.0
	_lunge_t = -1.0


## A blow at it from `from` that missed: it jumps aside (no wound; a lunge goes on).
func dodge(from: Vector3) -> void:
	if dead or _lunge_t >= 0.0:
		return
	var away := _flat(global_position - from)
	away = away.normalized() if away.length() > 0.01 else global_transform.basis.z
	var side := away.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_stagger = (side * 0.8 + away * 0.6).normalized() * 2.6
	_stagger_t = 0.2


## How hard it is to hit now (0 standing .. 1): on the move, and most of all lunging.
func evasion() -> float:
	if dead:
		return 0.0
	if _lunge_t >= 0.0:
		return 1.0
	return clampf((_speed - 1.5) / 5.0, 0.0, 1.0)


func is_dead() -> bool:
	return dead


## For the knife's reach (Combat): only a live wolf is struck, at the middle of its body.
func can_be_hit() -> bool:
	return not dead


func hit_center() -> Vector3:
	return _shape.global_position if _shape else global_position + Vector3(0, 0.5, 0)


## Where its head is (eye height for looks, a bite's source).
func head_point() -> Vector3:
	return rig.bone_world("head") if rig and rig.skeleton else global_position + Vector3(0, 0.6, 0)


# --- The carcass -----------------------------------------------------------------------------

func interact_title() -> String:
	return tr("WOLF_TITLE") if dead else ""


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_TAKE_PELT") if dead and rig.dead_amount() > 0.8 else ""


func interact(player: Node) -> void:
	if dead and rig.dead_amount() > 0.8:
		take_pelt(player)


## The pelt into the bag (at the farmer's feet when it is full); the carcass is gone.
func take_pelt(player: Node = null) -> void:
	if not dead or is_queued_for_deletion():
		return
	var at := global_position + Vector3(0, 0.25, 0)
	var left := PlayerState.give(PELT, 1)
	if left > 0:
		Pickup.spawn(ItemStack.create(PELT, 1), at, Vector3(0, 1.2, 0))
	else:
		if player is Player:
			(player as Player).show_take(PELT, Transform3D(Basis(Vector3.UP, _yaw), at))
		Events.item_picked_up.emit(PELT, 1)
	Audio.play("soft", at, -4.0, 0.08, &"Effects", 4.0)
	Audio.play("grass", at, -10.0, 0.1, &"Effects", 3.0, 0.8)
	queue_free()


## A night slept through doesn't count toward the carcass going (CARCASS_HOURS).
func _on_time_skipped(minutes: float) -> void:
	if dead:
		_died_at += minutes


## Game hours since it died (-1 alive).
func hours_dead() -> float:
	return (GameClock.total_minutes - _died_at) / 60.0 if dead else -1.0


func _die(side: float, _kind: StringName) -> void:
	dead = true
	_died_at = GameClock.total_minutes
	_speed = 0.0
	_want_speed = 0.0
	_stagger = Vector3.ZERO
	_leap_t = -1.0
	_release_turn()
	remove_from_group(&"hittable")
	add_to_group(&"interactable")
	add_to_group(&"wolf_carcasses")
	rig.die(side)
	_sound("wolf_death", 0.0)
	# The carcass: not in the farmer's way, but the aim finds it (interactable layer).
	_body.collision_layer = 4
	_place_collider()
	died.emit(self)


# --- Frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if frozen():
		return
	var cam := _camera_pos()
	var dist := cam.distance_to(global_position)
	if dead:
		_carcass(delta)
		# Lying still: posed once more after the fall, then left as it is.
		if _laid_out:
			return
		_laid_out = rig.dead_amount() >= 1.0
	if dist > (SHOW_RANGE if _speed > 0.05 else ANIMATE_RANGE) and not dead:
		return
	_anim_acc += delta
	var every := 0.0
	if not _on_screen.is_on_screen():
		every = 0.25
	elif dist > 30.0:
		every = 1.0 / 20.0
	if _anim_acc < every and not dead:
		return
	if not dead:
		_mood()
	var t0 := Time.get_ticks_usec()
	rig.animate(_anim_acc, _speed)
	anim_usec += Time.get_ticks_usec() - t0
	_anim_acc = 0.0


func _physics_process(delta: float) -> void:
	if dead or frozen():
		return
	var t0 := Time.get_ticks_usec()
	if _clock_tick != Engine.get_physics_frames():
		_clock_tick = Engine.get_physics_frames()
		_clock += delta
	_goal_t += delta
	_bite_cd = maxf(_bite_cd - delta, 0.0)
	_sound_t -= delta
	_back_off = maxf(_back_off - delta, 0.0)
	_stagger_t = maxf(_stagger_t - delta, 0.0)
	if _stagger_t <= 0.0:
		_stagger = Vector3.ZERO
	match goal:
		&"idle":
			_want_speed = 0.0
		&"approach":
			if not _leave_building(delta):
				_approach(delta)
		&"prowl":
			if not _leave_building(delta):
				_prowl(delta, _target_point())
		&"hunt":
			_hunt(delta)
		&"attack_player":
			_attack_player(delta)
		&"howl":
			_howl(delta)
		&"flee":
			_flee(delta)
	_move(delta)
	_place_collider()
	think_usec += Time.get_ticks_usec() - t0


## Whether the wolves stand frozen: a screen that pauses the game is open (the pause
## menu, the settings: Game.is_paused()), though not the sleep screen (as the farmer
## faints the pack is seen running off; asleep, they are gone anyway).
static func frozen() -> bool:
	if not Game.is_paused():
		return false
	var hud := Game.hud as HUD
	return hud == null or not hud.sleep_screen.is_busy()


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else global_position + Vector3(0, 50, 0)


## The rig's pose, look, tail and ears by what it is doing.
func _mood() -> void:
	rig.look_at_point = Vector3.INF
	rig.nose_down = 0.0
	rig.crouch = 0.0
	rig.snarl = 0.0
	rig.howl = 0.0
	rig.tail_mood = 0.0
	rig.ears_back = 0.0
	rig.panting = false
	rig.pose = DogRig.Pose.STAND
	match goal:
		&"idle", &"approach":
			rig.nose_down = 0.8 if _sniff and _speed < 0.3 else 0.0
		&"prowl":
			rig.nose_down = 0.85 if _sniff and _pause_t > 0.0 else (0.25 if _speed < 1.6 else 0.0)
			var c := _target_point()
			if not _sniff and _pause_t > 0.0 and c.is_finite():
				rig.look_at_point = c + Vector3(0, 0.6, 0)
		&"hunt":
			rig.tail_mood = 0.6
			var n := _target_node()
			if n and is_instance_valid(n):
				rig.look_at_point = n.global_position + Vector3(0, 0.3, 0)
				var d := _flat(n.global_position - global_position).length()
				rig.crouch = 0.35 * clampf(1.0 - absf(d - 6.0) / 4.0, 0.0, 1.0) if _speed < 3.0 else 0.0
				rig.snarl = 0.4 if d < 3.0 else 0.0
		&"attack_player":
			var p := _target_node()
			if p and is_instance_valid(p):
				rig.look_at_point = _player_centre(p) + Vector3(0, 1.0, 0)
			if _give_up_why == &"" or _give_up_why == &"vehicle":
				rig.snarl = 1.0
				rig.tail_mood = 0.8
				if _windup_t >= 0.0:
					# Gathered for the spring: low on its haunches, ears flat.
					rig.crouch = 1.0
					rig.ears_back = 1.0
				elif _back_off <= 0.0 and _speed < 4.0:
					rig.crouch = 0.55 if _stalk_t > 0.0 else 0.3
			else:
				rig.nose_down = 0.6 if _sniff and _pause_t > 0.0 else 0.0
			if _back_off > 0.0:
				rig.ears_back = 0.8
				rig.tail_mood = -0.3
			rig.panting = _goal_t > 20.0
		&"howl":
			rig.pose = DogRig.Pose.SIT
			rig.howl = 1.0 if _howl_t > 0.0 else 0.15
		&"flee":
			rig.tail_mood = -1.0
			rig.ears_back = 0.7
			rig.panting = true


# --- Goals ------------------------------------------------------------------------------------

func _approach(delta: float) -> void:
	var p := _target_point()
	if not p.is_finite():
		_want_speed = 0.0
		return
	# A pack sent to one point gathers round it, each to its own place.
	var slot := _slot_offset(p)
	p += slot
	var d := _flat(p - global_position).length()
	if d > (0.5 if slot != Vector3.ZERO else 1.0):
		_sniff = false
		_steer_to(p, LOPE if d > 30.0 else TROT, delta)
	else:
		_want_speed = 0.0
		_idle_about(delta)


## Round `centre` at its own distance, stopping now and then to sniff or look in.
func _prowl(delta: float, centre: Vector3, radius := -1.0, speed := WALK * 1.3) -> void:
	if not centre.is_finite():
		_want_speed = 0.0
		return
	var r := _ring_r if radius < 0.0 else radius
	if _pause_t > 0.0:
		_pause_t -= delta
		_want_speed = 0.0
		if not _sniff:
			_turn_to(centre, delta)
		return
	_pause_wait -= delta
	if _pause_wait <= 0.0:
		_pause_wait = _rng.randf_range(6.0, 12.0)
		_pause_t = _rng.randf_range(1.5, 4.0)
		_sniff = _rng.randf() < 0.55
		return
	var from := _flat(global_position - centre)
	var a := atan2(from.z, from.x) if from.length() > 0.1 else _rng.randf() * TAU
	var lead := clampf(2.2 / maxf(r, 1.0), 0.15, 0.7)
	var aim := a + _ring_dir * lead
	var p := centre + Vector3(cos(aim), 0.0, sin(aim)) * r
	if _forbidden(p):
		# Round the other way (a wall, a fire, the pond in the way).
		_ring_dir = -_ring_dir
	var far := absf(from.length() - r) > 4.0
	_steer_to(p, TROT if far else speed, delta)


## After a farm animal: runs it down and bites it; into its open coop by the door,
## round its shut one.
func _hunt(delta: float) -> void:
	var n := _target_node()
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		set_goal(&"prowl", global_position)
		return
	var tp := n.global_position
	var housing := n.get("housing") as AnimalHousing
	var indoors: Variant = n.get("indoors")
	var inside := indoors is bool and bool(indoors)
	# In a building its prey isn't in (it got out, or is another coop's): out by the door.
	var mine := _housing_at(global_position)
	if (mine != null or _leaving != null) and not (inside and housing != null and housing == (mine if mine else _leaving)):
		if _leave_building(delta):
			return
	elif _leaving != null:
		# Its prey is back in here: it stays.
		_leaving = null
		_path.clear()
	if inside and housing and housing.level >= 2:
		if not housing.can_pass():
			# Shut in: round the building, nose to the ground; no way in.
			_inside_ok = null
			_prowl(delta, housing.center(), maxf(housing.building.size.length() * 0.5 + 2.5, 4.0), WALK)
			return
		_inside_ok = housing
		if not housing.is_in_building(global_position):
			if _path.is_empty():
				# Round the building first when it stands between (a long coop's back wall).
				_path = housing.way_round_to_door(global_position)
				_path.append_array([housing.door_outside(), housing.door_inside()])
	else:
		_inside_ok = housing if housing and housing.level >= 2 and housing.can_pass() and housing.is_in_building(global_position) else null
		_path.clear()
	if not _path.is_empty():
		var wp: Vector3 = _path[0]
		if _flat(wp - global_position).length() < 0.6:
			_path.pop_front()
		else:
			_steer_to(wp, TROT if _path.size() < 2 else LOPE, delta)
			return
	var d := _flat(tp - global_position).length()
	var reach := ANIMAL_REACH + _target_radius(n)
	_update_lunge(delta, n, reach)
	if _lunge_t >= 0.0:
		return
	if d > reach * 0.9:
		var speed := LOPE if d > 14.0 else (RUN if d > 3.0 else TROT)
		if inside:
			speed = minf(speed, TROT)
		_steer_to(tp, speed, delta, true)
	else:
		_want_speed = 0.0
		_turn_to(tp, delta)
	if d < reach + 0.5 and _bite_cd <= 0.0 and _facing(tp, 0.5):
		_start_lunge()


## After the farmer: a short stalk, then bite after bite, PRESSERS of the pack at him at
## once from their own sides while the rest circle close and take their turn; after him
## into the coop or barn he is in by its open door; round his vehicle, or outside the
## building it can't get into, until it gives up.
func _attack_player(delta: float) -> void:
	var p := _target_node()
	if p == null or not is_instance_valid(p):
		set_goal(&"idle")
		return
	var v := p.get("driving") as Node3D
	if v and is_instance_valid(v):
		# In a vehicle: round it (snarling, now and then a growl), then off.
		if _give_up_why != &"vehicle":
			_give_up_why = &"vehicle"
			_give_up_t = _rng.randf_range(VEHICLE_TIME.x, VEHICLE_TIME.y)
			_release_turn()
			_going_in = false
			_windup_t = -1.0
		_count_down(delta)
		_prowl(delta, v.global_position, VEHICLE_RING + float(get_instance_id() % 3) * 0.6, TROT)
		_growl_now_and_then(0.5)
		return
	var at := p.global_position
	if _unreachable(at):
		if _give_up_why != &"indoors":
			_give_up_why = &"indoors"
			_give_up_t = _rng.randf_range(INDOORS_TIME.x, INDOORS_TIME.y)
			_release_turn()
			_going_in = false
			_windup_t = -1.0
			_ring_r = _rng.randf_range(8.0, 12.0)
		_inside_ok = _housing_at(global_position)
		_count_down(delta)
		_prowl(delta, at, _ring_r, WALK * 1.3)
		return
	if _give_up_why != &"":
		_give_up_why = &""
		_give_up_t = -1.0
		_ring_r = _rng.randf_range(RING_RADIUS.x, RING_RADIUS.y)
	_update_lunge(delta, p, BITE_REACH)
	if _lunge_t >= 0.0:
		return
	# Into (or out of) the coop he is in, by its door.
	if _through_door(delta, at):
		return
	var d := _flat(at - global_position).length()
	var inside := _inside_ok != null and _inside_ok.is_in_building(global_position)
	if _back_off > 0.0:
		# A step back and round after a bite or a blow, to come in again from a new side.
		var away := _flat(global_position - at)
		away = away.normalized() if away.length() > 0.05 else global_transform.basis.z
		var back := 1.6 if inside else 3.0
		_steer_to(at + away.rotated(Vector3.UP, _ring_dir * 0.5) * back, TROT if inside else LOPE, delta)
		return
	if _windup_t >= 0.0:
		_windup(delta, p, d)
		return
	if _stalk_t > 0.0:
		# Coming at him low, growling, before the first spring.
		if d < STALK_NEAR:
			_stalk_t -= delta
			if _sound_t <= 0.0:
				_sound_t = _rng.randf_range(1.5, 3.0)
				_sound("wolf_growl", -2.0)
		if d > STALK_NEAR:
			_steer_to(at, RUN if d > 14.0 else LOPE, delta, true)
		elif d > WINDUP_RANGE + 0.6:
			_steer_to(at, minf(WALK * 1.6, TROT), delta, true)
		else:
			_want_speed = 0.0
			_turn_to(at, delta)
		return
	var key := p.get_instance_id()
	if not _going_in and _bite_cd <= 0.0 and not _fire_near(at) and _turns_at(key).size() < PRESSERS:
		_take_turn(key)
	if _going_in:
		_dart_t += delta
		if _dart_t > PRESS_TIME and _turns_at(key).size() >= PRESSERS:
			# Too long without getting at him: its place to one of the others.
			_release_turn()
			_going_in = false
		else:
			_press(delta, at, d, key, inside)
			return
	# Circling close: its own place round him, facing him, snarling, edging round.
	var from := _flat(global_position - at)
	var a := atan2(from.z, from.x) if from.length() > 0.1 else _rng.randf() * TAU
	var aim := a + _ring_dir * 0.35
	var r := minf(_ring_r, 1.6) if inside else _ring_r
	var spot := at + Vector3(cos(aim), 0.0, sin(aim)) * r
	if _forbidden(spot):
		_ring_dir = -_ring_dir
	if absf(d - r) > 0.8:
		_steer_to(spot, LOPE if d > r + 6.0 else TROT, delta, true)
	else:
		_steer_to(spot, WALK, delta)
		if _speed < 1.3:
			_turn_to(at, delta * 0.6)
	_growl_now_and_then(0.5)


## Pressing him: in from its own side (away from the other wolf pressing him), and once
## near enough and facing him, the wind-up for a lunge (when none came at him just now).
func _press(delta: float, at: Vector3, d: float, key: int, inside: bool) -> void:
	if d > WINDUP_RANGE:
		var side := _press_side(at, key)
		var spot := at + side * BITE_REACH if d > 3.5 else at
		var speed := RUN if d > 6.0 else (LOPE if d > 3.5 else TROT)
		_steer_to(spot, minf(speed, TROT) if inside else speed, delta, true)
		return
	_want_speed = 0.0
	_turn_to(at, delta * 1.6)
	if _facing(at, 0.5) and _clock >= float(_next_go.get(key, 0.0)):
		_windup_t = 0.0
		_next_go[key] = _clock + WINDUP_TIME + LUNGE_GAP
		_sound("wolf_snarl", -1.0)


## Where it comes at him from (a flat unit vector out from him): its own side, at least
## a third of the way round from the other wolf pressing him.
func _press_side(at: Vector3, key: int) -> Vector3:
	var mine := _flat(global_position - at)
	mine = mine.normalized() if mine.length() > 0.05 else global_transform.basis.z
	for w: Wolf in _turns_at(key):
		if w == self or not is_instance_valid(w):
			continue
		var o := _flat(w.global_position - at)
		if o.length() < 0.05:
			continue
		o = o.normalized()
		if mine.dot(o) > -0.4:
			var s := signf(o.cross(mine).y)
			mine = o.rotated(Vector3.UP, (s if s != 0.0 else _ring_dir) * deg_to_rad(125.0))
	return mine


## The wind-up: crouched and snarling, turned to him (its aim fixed for the last part),
## then the spring; he got well away meanwhile: after him again.
func _windup(delta: float, p: Node3D, d: float) -> void:
	_windup_t += delta
	_want_speed = 0.0
	if _windup_t < WINDUP_TIME * WINDUP_AIM:
		_turn_to(p.global_position, delta * 2.0)
	if d > WINDUP_RANGE + 2.2:
		_windup_t = -1.0
		return
	if _windup_t >= WINDUP_TIME:
		_windup_t = -1.0
		_lunge_yaw = _yaw
		_start_lunge()


## The wolves pressing the target with instance id `key` (the dead and gone left out).
static func _turns_at(key: int) -> Array:
	var out: Array = _turns.get(key, [])
	out = out.filter(func(w: Variant) -> bool: return is_instance_valid(w) and not (w as Wolf).dead)
	_turns[key] = out
	return out


func _take_turn(key: int) -> void:
	var list := _turns_at(key)
	if not list.has(self):
		list.append(self)
	_going_in = true
	_dart_t = 0.0
	_press_bites = 0


## The building (a coop's or a barn's) it can go into after the farmer at `at`: his, door
## open; and the way in by its door, or out by it when he has left it (true while it
## follows those waypoints).
func _through_door(delta: float, at: Vector3) -> bool:
	var his := _housing_at(at)
	var mine := _housing_at(global_position)
	_inside_ok = his if his else mine
	if mine and mine != his:
		# Out by the door first.
		if _path_for != mine or _path.is_empty():
			_path_for = mine
			_path.assign([mine.door_inside(), mine.door_outside()])
	elif his and mine != his:
		if _path_for != his or _path.is_empty():
			_path_for = his
			_path = his.way_round_to_door(global_position)
			_path.append_array([his.door_outside(), his.door_inside()])
	else:
		_path.clear()
		_path_for = null
	while not _path.is_empty() and _flat(_path[0] - global_position).length() < 0.6:
		_path.pop_front()
	if _path.is_empty():
		_path_for = null
		return false
	_windup_t = -1.0
	_steer_to(_path[0], TROT if _path.size() < 3 else LOPE, delta)
	_growl_now_and_then(0.4)
	return true


## The farm building (a coop, a barn) `p` is in, or null.
static func _housing_at(p: Vector3) -> AnimalHousing:
	var farm := Game.world.get("farm") as Farm if Game.world else null
	if farm == null:
		return null
	for h in farm.housings():
		if h.level >= 2 and h.is_in_building(p):
			return h
	return null


func _count_down(delta: float) -> void:
	if _give_up_t < 0.0:
		return
	_give_up_t -= delta
	if _give_up_t <= 0.0:
		_give_up_t = -1.0
		var why := _give_up_why
		_give_up_why = &""
		gave_up.emit(self)
		# (The director may have sent it somewhere already.)
		if goal == &"attack_player":
			set_goal(&"flee", flee_point(global_position))
		print_verbose("Wolf: gave up (%s)" % why)


## Sits and howls now and then: each howl HOWL_TIME s, then a quiet while.
func _howl(delta: float) -> void:
	_want_speed = 0.0
	if rig.sit_amount() < 0.8:
		return
	if _howl_t >= HOWL_TIME:
		_sound("wolf_howl", 2.0, 30.0)
	_howl_t -= delta
	if _howl_t <= -_rng.randf_range(3.0, 7.0):
		_howl_t = HOWL_TIME


## Away to `target` flat out, tail tucked (out of a coop or barn by its door first); gone
## when there or far off unseen. The safety net: one that gets nowhere (`stuck`: it turns
## another way out of the valley) or is still about after FLEE_LONG s is gone as soon as
## the farmer isn't looking at it, or is far off (unwatched).
func _flee(delta: float) -> void:
	var p := _target_point()
	if not p.is_finite():
		p = flee_point(global_position)
		target = p
	var out := _leave_building(delta)
	if not out:
		_steer_to(p, RUN, delta, true)
	_watch_stuck(delta, out)
	var d := _flat(p - global_position).length()
	var far := _camera_pos().distance_to(global_position) > GONE_FAR
	if d < 2.5 or (far and not _on_screen.is_on_screen() and _goal_t > 3.0):
		queue_free()
	elif (stuck or _goal_t > FLEE_LONG) and unwatched():
		queue_free()


## Fleeing: has it got anywhere lately? Not for STUCK_TIME s: `stuck`, and (out in the
## open: `indoors` is on its way out of a building) it heads for the valley's rim another
## way round, further each time.
func _watch_stuck(delta: float, indoors: bool) -> void:
	if not _stuck_from.is_finite() or _flat(global_position - _stuck_from).length() >= STUCK_MOVE:
		_stuck_from = global_position
		_stuck_t = 0.0
		stuck = false
		return
	_stuck_t += delta
	if _stuck_t < STUCK_TIME:
		return
	stuck = true
	_stuck_t = 0.0
	if indoors:
		return
	_stuck_turns += 1
	var side := _ring_dir if _stuck_turns % 2 == 1 else -_ring_dir
	var dir := _flat(global_position).normalized().rotated(Vector3.UP, side * minf(0.8 * float(_stuck_turns), 2.6))
	if dir == Vector3.ZERO:
		dir = Vector3.RIGHT
	var to := dir * (LAND_RADIUS - 5.0)
	target = Vector3(to.x, TerrainData.height(to.x, to.z), to.z)
	_detour = INF


## Nobody is looking at it: off the farmer's screen, or GONE_FAR m and more from him.
func unwatched() -> bool:
	return not _on_screen.is_on_screen() or _camera_pos().distance_to(global_position) > GONE_FAR


## In a coop or barn it has no business in any more (its prey taken, the raid over, told
## to prowl or to go): out at a trot by the door it came in by, before anything else (true
## while it is on its way out). A door shut on it meanwhile keeps it in: it waits there.
func _leave_building(delta: float) -> bool:
	var mine := _housing_at(global_position)
	if mine != null and _leaving != mine:
		_leaving = mine
		_path_for = mine
		_path.assign([mine.door_inside(), mine.door_outside()])
		# Already in the doorway: straight on out.
		var l := mine.flat(global_position)
		if absf(l.x - mine.door_x()) < 0.35 and l.y > mine.flat(mine.door_inside()).y:
			_path.pop_front()
	if _leaving == null:
		return false
	while not _path.is_empty() and _flat(_path[0] - global_position).length() < 0.6:
		_path.pop_front()
	if _path.is_empty():
		_leaving = null
		_path_for = null
		_inside_ok = null
		return false
	_inside_ok = _leaving
	_windup_t = -1.0
	if mine != null and not mine.can_pass():
		_want_speed = 0.0
		_turn_to(mine.door_outside(), delta)
		return true
	_steer_to(_path[0], TROT, delta)
	return true


## A point far off in the forest, away from `from` and the farm.
static func flee_point(from: Vector3) -> Vector3:
	var dir := Vector2(from.x, from.z)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(1, 0).rotated(randf() * TAU)
	var p := dir * (LAND_RADIUS - 5.0)
	return Vector3(p.x, TerrainData.height(p.x, p.y), p.y)


## Its own place round a point several wolves are sent to: the first at the point, the
## rest round it SPACING out, by their order among those going there.
func _slot_offset(p: Vector3) -> Vector3:
	var i := 0
	for n in get_tree().get_nodes_in_group(GROUP):
		var w := n as Wolf
		if w == self:
			break
		if w and not w.dead and w.goal == goal and w._same_target(target):
			i += 1
	if i == 0:
		return Vector3.ZERO
	var a := float(i) * 2.39996
	var r := SPACING * (1.2 + 0.35 * float(i / 6))
	var off := Vector3(cos(a), 0.0, sin(a)) * r
	return off if not _forbidden(p + off) else Vector3.ZERO


func _idle_about(delta: float) -> void:
	_pause_wait -= delta
	if _pause_wait <= 0.0:
		_pause_wait = _rng.randf_range(4.0, 9.0)
		_sniff = _rng.randf() < 0.4


# --- Biting -----------------------------------------------------------------------------------

func _start_lunge() -> void:
	if _lunge_t >= 0.0:
		return
	_lunge_t = 0.0
	rig.lunge()
	_sound("wolf_snarl", -4.0)


## The lunge: a spring at `n` (forward, fast); at its peak the jaws close: a bite if it
## is in reach. At the farmer it springs along the heading it gathered itself on, turning
## only a little after him (he can step out of it), stops short of his feet and then
## steps back and round; at an animal it follows it and worries on.
func _update_lunge(delta: float, n: Node3D, reach: float) -> void:
	if _lunge_t < 0.0:
		return
	_lunge_t += delta
	var to := _flat(n.global_position - global_position)
	var at_him := goal == &"attack_player"
	if _lunge_t < 0.22:
		if at_him:
			var want := atan2(-to.x, -to.z)
			_yaw += clampf(angle_difference(_yaw, want), -LUNGE_TURN * delta, LUNGE_TURN * delta)
			var ahead := to.dot(Vector3(-sin(_yaw), 0.0, -cos(_yaw)))
			_want_speed = clampf((ahead - LUNGE_STOP) * 9.0, 0.0, LUNGE_SPEED)
			_speed = _want_speed
		else:
			_turn_to(n.global_position, delta * 2.0)
			_want_speed = clampf(to.length() * 6.0, 0.0, 6.0)
			_speed = maxf(_speed, _want_speed * 0.8)
	else:
		_want_speed = 0.0
		if at_him:
			_speed = move_toward(_speed, 0.0, 20.0 * delta)
	if _lunge_t >= 0.22 and _lunge_t - delta < 0.22:
		var hit := to.length() < reach + 0.35
		if at_him:
			hit = hit and _facing(n.global_position, 0.75)
		if hit:
			_bite(n)
		else:
			_sound("wolf_bite", -12.0)
	if _lunge_t >= WolfRig.LUNGE_TIME:
		_lunge_t = -1.0
		_bite_cd = BITE_COOLDOWN
		if at_him:
			_press_bites += 1
			if _press_bites >= PRESS_BITES:
				# Its spell done: the place to one of the others (or back to it).
				_release_turn()
				_going_in = false
			_back_off = _rng.randf_range(RECOVER_TIME.x, RECOVER_TIME.y)


func _bite(n: Node3D) -> void:
	bites += 1
	_sound("wolf_bite", 0.0)
	if n == Game.player:
		PlayerState.hurt(BITE_HURT, head_point())
	bit.emit(n)


func _release_turn() -> void:
	for key in _turns.keys():
		var list: Array = _turns[key]
		list.erase(self)


# --- Moving -----------------------------------------------------------------------------------

## The goal's target when it is a node still there (a hunted animal killed or sold is
## freed under the wolf), else null.
func _target_node() -> Node3D:
	return target as Node3D if typeof(target) == TYPE_OBJECT and is_instance_valid(target) else null


func _target_point() -> Vector3:
	if target is Vector3:
		return target
	var n := _target_node()
	if n and is_instance_valid(n):
		return _player_centre(n) if n is Player else n.global_position
	return Vector3.INF


## The farmer's position (his vehicle's when he's driving).
static func _player_centre(p: Node3D) -> Vector3:
	var v := p.get("driving") as Node3D
	return v.global_position if v and is_instance_valid(v) else p.global_position


func _same_target(t: Variant) -> bool:
	if t is Vector3 and target is Vector3:
		return (t as Vector3).is_equal_approx(target)
	return typeof(t) == typeof(target) and t == target


func _target_radius(n: Node3D) -> float:
	if n.has_method(&"radius"):
		return float(n.call(&"radius"))
	return 0.3


## Heads for `p` at `speed`: round the rest of the pack, round what is in the way
## (leaping low fences when `leap`), slowing into sharp turns and as it arrives.
func _steer_to(p: Vector3, speed: float, delta: float, leap := false) -> void:
	var to := _flat(p - global_position)
	var dist := to.length()
	if dist < 0.05:
		_want_speed = 0.0
		return
	# A vehicle in the way: round it by its corners (beside it, when `p` is in it).
	var via := _flat(Vehicle.way_round(global_position, p, VEHICLE_KEEP, VEHICLE_BERTH) - global_position)
	if via.length() < 0.05:
		_want_speed = 0.0
		return
	var dir := via.normalized()
	# Out of a forbidden place first (a fire's reach, a building it shouldn't be in).
	var out := _escape()
	if out != Vector3.ZERO:
		dir = out
	dir = (dir + _separation() * 0.9).normalized()
	var want := atan2(-dir.x, -dir.z)
	_probe_t -= delta
	if _probe_t <= 0.0:
		_probe_t = 0.1
		# (Not past where it is going: a wall behind the farmer in a coop is no obstacle.)
		var reach := minf(clampf(_speed * 0.6 + BODY_REACH, BODY_REACH + 0.3, 4.5), maxf(via.length(), BODY_REACH + 0.3))
		var clear := _clear(want, reach, leap)
		if clear:
			_detour = INF
		elif not is_finite(_detour) or not _clear(_detour, reach, leap):
			_detour = _free_heading(want, reach, leap)
			_detour_t = 0.8
	if is_finite(_detour):
		_detour_t -= delta
		if _detour_t <= 0.0:
			_detour = INF
		else:
			want = _detour
	var diff := angle_difference(_yaw, want)
	var rate := minf(TURN_RATE, TURN_GRIP / maxf(_speed, 0.5))
	_yaw += clampf(diff, -rate * delta, rate * delta)
	var turn_k := clampf(1.0 - (absf(diff) - 0.5) / 1.2, 0.15, 1.0)
	_want_speed = speed * turn_k * clampf(dist / 1.2, 0.3, 1.0)


func _turn_to(p: Vector3, delta: float) -> void:
	var to := _flat(p - global_position)
	if to.length() < 0.05:
		return
	var want := atan2(-to.x, -to.z)
	var rate := TURN_RATE * (0.4 if rig.sit_amount() > 0.3 else 0.75)
	_yaw += clampf(angle_difference(_yaw, want), -rate * delta, rate * delta)


func _facing(p: Vector3, tolerance: float) -> bool:
	var to := _flat(p - global_position)
	return to.length() < 0.05 or absf(angle_difference(_yaw, atan2(-to.x, -to.z))) < tolerance


## Keeping its distance from the rest of the pack: a push away from those too near.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for n in get_tree().get_nodes_in_group(GROUP):
		var w := n as Wolf
		if w == self or w == null or w.dead:
			continue
		var d := _flat(global_position - w.global_position)
		var l := d.length()
		if l < SPACING and l > 0.001:
			push += d / l * (1.0 - l / SPACING)
		elif l <= 0.001:
			push += Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * 0.5
	return push


func _move(delta: float) -> void:
	var up := rig.sit_amount() < 0.05 and rig.lie_amount() < 0.05
	_speed = move_toward(_speed, _want_speed if up else 0.0, ACCEL * delta)
	rotation.y = _yaw
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var step := fwd * _speed * delta + _stagger * delta
	if step.length() > 0.0001:
		var next := global_position + step
		var blocked := false
		if _forbidden(next) and not _forbidden(global_position):
			blocked = true
		elif _leap_t < 0.0 and _wall_ahead(step):
			blocked = true
		if not blocked:
			# Never into a vehicle (its body would shove it): along its side, or stopped.
			var kept := Vehicle.keep_out(global_position, next, VEHICLE_KEEP)
			blocked = _flat(kept - global_position).length() < step.length() * 0.05
			next = Vector3(kept.x, next.y, kept.z)
		if blocked:
			_speed *= 0.3
			_detour = INF
			_probe_t = 0.0
		else:
			global_position = next
	var h := _ground_at(global_position.x, global_position.z)
	_floor_y = h if absf(h - _floor_y) > 0.6 else lerpf(_floor_y, h, 1.0 - exp(-delta * 12.0))
	var lift := 0.0
	if _leap_t >= 0.0:
		_leap_t += delta
		lift = sin(PI * clampf(_leap_t / LEAP_TIME, 0.0, 1.0)) * (LEAP_HEIGHT * 0.75)
		if _leap_t >= LEAP_TIME:
			_leap_t = -1.0
	global_position.y = _floor_y + lift


## Something solid right in front of its chest (a wall, a fence) it would walk into.
func _wall_ahead(step: Vector3) -> bool:
	var dir := _flat(step).normalized()
	if dir == Vector3.ZERO:
		return false
	var a := global_position + Vector3(0, 0.45, 0)
	return _hit(a, a + dir * (BODY_REACH * 0.8 + step.length()))


## Whether heading `h` is open for `reach` m: nothing solid in the way at chest height
## (or only a low fence it may leap, never a vehicle: it starts the leap when the fence
## is close), and not into a forbidden place.
func _clear(h: float, reach: float, leap: bool) -> bool:
	var dir := Vector3(-sin(h), 0.0, -cos(h))
	var end := global_position + dir * reach
	if _forbidden(end) or _forbidden(global_position + dir * reach * 0.5):
		return false
	var a := global_position + Vector3(0, 0.45, 0)
	var hit := _ray(a, a + dir * reach)
	if hit.is_empty():
		return true
	# Never up onto (or over) a vehicle: as low as a fence, but its body would land on it.
	if leap and _leap_t < 0.0 and not hit["collider"] is Vehicle:
		var b := global_position + Vector3(0, LEAP_HEIGHT + 0.1, 0)
		if _ray(b, b + dir * reach).is_empty():
			var d := (hit["position"] as Vector3).distance_to(a)
			if d < 1.3 and _speed > 2.0:
				_leap_t = 0.0
				_sound("wolf_bite", -24.0)
			return true
	return false


## The nearest open heading to `h`, trying either side further and further round.
func _free_heading(h: float, reach: float, leap: bool) -> float:
	var side := _ring_dir
	for step in [0.45, 0.9, 1.35, 1.8, 2.3, 2.8]:
		for s in [side, -side]:
			var c: float = h + s * step
			if _clear(c, reach, leap):
				return c
	return h + PI


## Somewhere it doesn't go: in a building (save the hunted animal's open coop), within
## FIRE_KEEP of a burning campfire, in the pond, in town or out of the land.
func _forbidden(p: Vector3) -> bool:
	if Vector2(p.x, p.z).length() > LAND_RADIUS:
		return true
	if Vector2(p.x, p.z).distance_to(WorldLayout.TOWN_CENTER) < WorldLayout.TOWN_VALLEY_RADIUS + 12.0:
		return true
	if WorldLayout.distance_to_pond(p.x, p.z) < WorldLayout.POND_RADIUS + 0.5:
		return true
	if _fire_near(p):
		return true
	return in_building(p, _inside_ok)


## A burning campfire within FIRE_KEEP of `p` (or a lit lantern post within its reach:
## Pastures.lantern_near).
func _fire_near(p: Vector3) -> bool:
	if Pastures.lantern_near(p):
		return true
	for n in get_tree().get_nodes_in_group(&"campfires"):
		var f := n as Node3D
		if f and f.has_method(&"is_burning") and f.call(&"is_burning") \
				and Vector2(f.global_position.x - p.x, f.global_position.z - p.z).length() < FIRE_KEEP:
			return true
	return false


## Whether `p` is in (or right against) one of the farm's buildings: the house, the
## warehouse, any barn or coop building (`except` the one it may go into).
static func in_building(p: Vector3, except: AnimalHousing = null) -> bool:
	var pt := Vector2(p.x, p.z)
	if WorldLayout.house_rect(FarmState.house_level()).grow(0.6).has_point(pt):
		return true
	if WorldLayout.WAREHOUSE_RECT.grow(0.6).has_point(pt):
		return true
	var farm := Game.world.get("farm") as Farm if Game.world else null
	if farm:
		for h in farm.housings():
			if h != except and h.level >= 2 and h.building.grow(0.5).has_point(h.flat(p)):
				return true
	return false


## The farmer is somewhere it can't get at him: in the farmhouse or the warehouse, or in
## a coop or barn whose door is shut (one whose door stands open it goes into after him).
func _unreachable(p: Vector3) -> bool:
	var pt := Vector2(p.x, p.z)
	if WorldLayout.house_rect(FarmState.house_level()).grow(0.3).has_point(pt) or WorldLayout.WAREHOUSE_RECT.grow(0.3).has_point(pt):
		return true
	var h := _housing_at(p)
	return h != null and not h.can_pass()


## Out of a forbidden place it stands in: the way out (zero when it isn't in one).
func _escape() -> Vector3:
	if not _forbidden(global_position):
		return Vector3.ZERO
	for n in get_tree().get_nodes_in_group(&"campfires"):
		var f := n as Node3D
		if f and f.has_method(&"is_burning") and f.call(&"is_burning"):
			var d := _flat(global_position - f.global_position)
			if d.length() < FIRE_KEEP:
				return d.normalized() if d.length() > 0.01 else Vector3.RIGHT
	return Pastures.lantern_escape(global_position)


func _hit(a: Vector3, b: Vector3) -> bool:
	return not _ray(a, b).is_empty()


## A ray against the world's colliders (not the terrain: slopes it just walks).
func _ray(a: Vector3, b: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return hit
	var c := hit["collider"] as Node
	if c and c.get_parent() is Terrain:
		return {}
	return hit


## The ground's height under (x, z): what it stands on low down (a step, a coop's
## floor), else the terrain; never the top of a fence or a wall.
func _ground_at(x: float, z: float) -> float:
	var t := TerrainData.height(x, z)
	if not is_inside_tree():
		return t
	var y := maxf(global_position.y, t)
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.9, z), Vector3(x, t - 0.5, z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hy := (hit["position"] as Vector3).y
		if hy - t < (0.75 if _inside_ok else 0.35):
			return hy
	return t


func _snap_to_ground() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_floor_y = _ground_at(global_position.x, global_position.z)
	global_position.y = _floor_y
	reset_physics_interpolation()


## The collider along the body: standing, sitting (tilted up) or the carcass on its side.
func _place_collider() -> void:
	if _shape == null or rig == null:
		return
	if dead:
		_shape.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.18, 0.05))
		return
	var s := rig.sit_amount() * (1.0 - rig.lie_amount())
	var l := rig.lie_amount()
	var pitch := lerpf(PI * 0.5, PI * 0.5 - 0.7, s)
	var y := lerpf(lerpf(0.52, 0.42, s), 0.25, l)
	_shape.transform = Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0, y, lerpf(0.0, 0.12, s)))


# --- The carcass's end ------------------------------------------------------------------------

## Gone by itself CARCASS_HOURS after it died, when nobody is looking at it.
func _carcass(_delta: float) -> void:
	if hours_dead() >= CARCASS_HOURS and not _on_screen.is_on_screen():
		queue_free()


# --- Sound ------------------------------------------------------------------------------------

func _sound(set_name: String, volume_db: float, unit_size := 6.0) -> void:
	var at := head_point()
	Audio.play(set_name, at, volume_db, 0.06, &"Effects", unit_size)


func _growl_now_and_then(chance: float) -> void:
	if _sound_t > 0.0:
		return
	_sound_t = _rng.randf_range(2.0, 4.5)
	if _rng.randf() < chance:
		_sound("wolf_growl", -4.0)


## Howling far off in the forest round the farm, heard from the farmer: `intensity`
## 0..1 is how loud and how many voices (a raid's warning). A chorus from one side, at
## higher intensity a second answering from another.
static func play_distant_howls(intensity: float) -> void:
	var player := Game.player as Node3D
	if player == null or not is_instance_valid(player) or intensity <= 0.0:
		return
	var from := Vector2(player.global_position.x, player.global_position.z)
	var voices := 1 if intensity < 0.6 else 2
	var base := randf() * TAU
	for i in voices:
		var a := base + float(i) * randf_range(1.6, 2.6)
		var d := randf_range(70.0, 110.0)
		var p := from + Vector2(cos(a), sin(a)) * d
		var at := Vector3(p.x, TerrainData.height(p.x, p.y) + 6.0, p.y)
		Audio.play("wolf_howl_far", at, lerpf(-6.0, 4.0, clampf(intensity, 0.0, 1.0)) - 3.0 * float(i), 0.05,
				&"Effects", 26.0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
