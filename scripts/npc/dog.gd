class_name Dog
extends Node3D
## A dog kept in a garden (Karamel, Zeynep's dog): a DogRig body pottering about its
## home_area, or doing what its owner's story asks of it (set_mode):
##   &"roam"   the default: walking about the garden, sniffing along the ground, standing
##             looking round, sitting, lying down a while (the head on its paws, and at
##             night mostly asleep); it looks at the player when he is near, wagging.
##   &"petted" turns to face the petter (`target`, the petter's position), or toward
##             petted_toward when that is set (an owner down beside it), sits and leans
##             into the hand, head up to the petter's face, ears back, the tail wagging
##             hard, now and then a soft whine.
##   &"eat"    goes to the bowl at `target`, puts its head in it and eats (the jaw
##             working, crunching and lapping) for EAT_TIME, then roams again (`ate`).
##   &"greet"  comes to `target` (the player) as far as its garden lets it, trotting when
##             it is far, with a bark or two, and stands there wagging, looking up at him.
## It keeps ROAM_INSET inside home_area with its body and its nose short of the edge, finds
## the ground under it by raycast, has a small collider the player can't walk through,
## and is animated only near the camera (less often off screen).

## It has finished eating and roams again.
signal ate

## Microseconds all dogs spent posing their bodies (a cost gauge for tests).
static var anim_usec := 0

const GROUP := &"dogs"
const MODES: Array[StringName] = [&"roam", &"petted", &"eat", &"greet"]
## Metres its body keeps inside home_area; how far ahead of its middle the nose is and
## how far inside the edge it stays.
const ROAM_INSET := 0.4
const NOSE_REACH := 0.64
const NOSE_INSET := 0.08
## Speeds (m/s): walking about, nosing along the ground, trotting to someone.
const WALK := 0.85
const SNIFF := 0.32
const TROT := 1.9
const TURN_RATE := 3.2
const ACCEL := 2.6
const EAT_TIME := 10.0
## How far short of the one it greets it stops (m).
const GREET_GAP := 0.95
const ANIMATE_RANGE := 50.0
const SHOW_RANGE := 90.0
## Roaming, what it does next and how likely it is (weights), and for how long (s).
enum Act { STAND, WANDER, SNIFF, SIT, LIE }
const ACT_WEIGHTS := {Act.STAND: 3.0, Act.WANDER: 4.0, Act.SNIFF: 2.5, Act.SIT: 2.0, Act.LIE: 1.5}
const ACT_TIME := {Act.STAND: Vector2(3.0, 8.0), Act.SNIFF: Vector2(3.0, 6.0), Act.SIT: Vector2(6.0, 15.0),
	Act.LIE: Vector2(15.0, 40.0)}

## The garden it keeps to (x, z world rectangle) and its name's string key.
var home_area := Rect2()
var name_key := ""
var mode: StringName = &"roam"
var target := Vector3.INF
## Petted, the point it sits facing (INF: the petter): with someone kneeling at its side
## it sits facing the way she does, looking round and up at her face.
var petted_toward := Vector3.INF
var rig: DogRig
## How many times it has barked.
var barks := 0
## The body's size against the model's (a puppy is smaller, PetDog): the gait is worked
## out at the model's own size (speed / gait_scale), so the paws never slide.
var gait_scale := 1.0

var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _on_screen: VisibleOnScreenNotifier3D
var _act := Act.STAND
var _act_t := 0.0
var _goal := Vector3.INF
var _speed := 0.0
var _want_speed := 0.0
var _yaw := 0.0
var _mode_t := 0.0
var _anim_acc := 0.0
var _bark_cd := 0.0
var _sound_t := 3.0
var _barks_left := 0
var _bark_wait := 0.0
var _player_near := false
var _player_away := 100.0
var _floor_y := 0.0
var _arrived := false
var _eat_left := 0.0
## Roaming, a spell of wagging now and then (seconds left, and until the next).
var _wag_t := 0.0
var _wag_wait := 8.0
## Rig-frame point the nose reaches with its head down in a bowl.
var _eat_nose := Vector3(0, 0.05, -0.6)


func _init() -> void:
	name = "Dog"


func _ready() -> void:
	add_to_group(GROUP)
	rig = DogRig.create()
	add_child(rig)
	rig.ground = _ground_at
	_eat_nose = rig.eat_nose_rig() if rig.skeleton else _eat_nose
	_body = AnimatableBody3D.new()
	_body.name = "Body"
	_body.collision_layer = 16
	_body.collision_mask = 0
	_body.sync_to_physics = false
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.15
	cap.height = 0.92
	_shape.shape = cap
	_body.add_child(_shape)
	add_child(_body)
	_on_screen = VisibleOnScreenNotifier3D.new()
	_on_screen.aabb = AABB(Vector3(-0.4, 0, -0.8), Vector3(0.8, 0.9, 1.6))
	add_child(_on_screen)
	_yaw = rotation.y
	_floor_y = global_position.y
	_place_collider()
	Settings.changed.connect(rig.apply_quality)
	for mi in rig.meshes:
		mi.visibility_range_end = SHOW_RANGE
		mi.visibility_range_end_margin = 6.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_snap_to_ground.call_deferred()
	_start_act(Act.STAND)


# --- The contract --------------------------------------------------------------------------

## What the dog does now (see the class notes): &"roam", &"petted" (target: the petter's
## position), &"eat" (target: the bowl on the ground) or &"greet" (target: the player).
func set_mode(new_mode: StringName, at: Vector3 = Vector3.INF) -> void:
	if not new_mode in MODES:
		push_warning("Dog: unknown mode %s" % new_mode)
		return
	var again := new_mode == mode
	mode = new_mode
	target = at
	if not again:
		_mode_t = 0.0
		_arrived = false
	match new_mode:
		&"roam":
			_start_act(Act.STAND)
		&"petted":
			_want_speed = 0.0
			if randf() < 0.5:
				_sound("dog_whine", -12.0)
		&"eat":
			_eat_left = EAT_TIME
			_arrived = false
		&"greet":
			if not again or _mode_t > 4.0:
				_barks_left = randi_range(1, 2)
				_bark_wait = 0.25
				_mode_t = 0.0
				_arrived = false


## Where a stroking hand goes: on the back behind the withers, following the dog as it
## moves and breathes.
func pet_point() -> Vector3:
	if rig and rig.skeleton:
		return rig.pet_world()
	return global_position + Vector3(0, 0.55, 0)


## The way a hand strokes along its back from pet_point (world, level): toward the tail.
func pet_along() -> Vector3:
	var back := global_basis.z
	back.y = 0.0
	return back.normalized()


## A bark (and the head's jerk that goes with it); not twice within a moment.
func bark() -> void:
	if _bark_cd > 0.0:
		return
	_bark_cd = 0.55
	barks += 1
	if rig:
		rig.woof()
	var at := rig.nose_world() if rig and rig.skeleton else global_position + Vector3(0, 0.6, 0)
	Audio.play("dog_bark", at, -3.0, 0.07, &"Effects", 8.0)


# --- Frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var cam := _camera_pos()
	var dist := cam.distance_to(global_position)
	if dist > (SHOW_RANGE if _speed > 0.05 else ANIMATE_RANGE):
		return
	_anim_acc += delta
	var every := 0.0
	if not _on_screen.is_on_screen():
		every = 0.25
	elif dist > 25.0:
		every = 1.0 / 20.0
	if _anim_acc < every:
		return
	_mood()
	var t0 := Time.get_ticks_usec()
	rig.animate(_anim_acc, _speed / gait_scale)
	anim_usec += Time.get_ticks_usec() - t0
	_anim_acc = 0.0


func _physics_process(delta: float) -> void:
	_mode_t += delta
	_bark_cd = maxf(_bark_cd - delta, 0.0)
	_sound_t -= delta
	_notice_player(delta)
	match mode:
		&"roam":
			_roam(delta)
		&"petted":
			_petted(delta)
		&"eat":
			_eat(delta)
		&"greet":
			_greet(delta)
	_move(delta)
	_place_collider()


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else global_position + Vector3(0, 50, 0)


func _player_pos() -> Vector3:
	var p := Game.player
	return p.global_position if p and is_instance_valid(p) else Vector3.INF


## The player coming into the garden's reach (after being away a while) gets a bark or
## two, roaming; near him the dog looks at him and wags.
func _notice_player(delta: float) -> void:
	var p := _player_pos()
	var near := p.is_finite() and p.distance_to(global_position) < 6.0
	if near and not _player_near and _player_away > 60.0 and mode == &"roam" and rig.pose != DogRig.Pose.LIE:
		_barks_left = 1
		_bark_wait = 0.4
	_player_near = near
	_player_away = 0.0 if near else _player_away + delta
	if _barks_left > 0:
		_bark_wait -= delta
		if _bark_wait <= 0.0:
			bark()
			_barks_left -= 1
			_bark_wait = randf_range(0.5, 0.8)


## The rig's pose, look, tail and ears by what the dog is doing.
func _mood() -> void:
	var p := _player_pos()
	rig.look_at_point = Vector3.INF
	rig.chewing = false
	rig.lean = 0.0
	rig.ears_back = 0.0
	rig.head_rest = false
	match mode:
		&"roam":
			rig.pose = DogRig.Pose.SIT if _act == Act.SIT else (DogRig.Pose.LIE if _act == Act.LIE else DogRig.Pose.STAND)
			rig.nose_down = 0.85 if _act == Act.SNIFF else 0.0
			rig.head_rest = _act == Act.LIE and (_act_t > 6.0 or _night())
			rig.wag = 0.65 if _wag_t > 0.0 and not rig.head_rest else 0.25
			if _player_near and not rig.head_rest:
				rig.look_at_point = p + Vector3(0, 1.4, 0)
				rig.wag = 0.55
			rig.panting = false
		&"petted":
			rig.pose = DogRig.Pose.SIT if _facing(_petted_facing(), 0.5) else DogRig.Pose.STAND
			rig.nose_down = 0.0
			if target.is_finite():
				# Up at the petter's face (down on a knee beside it).
				rig.look_at_point = target + Vector3(0, 1.05, 0)
				var local := to_local(target)
				rig.lean = clampf(local.x * 2.0, -1.0, 1.0) * 0.7
			rig.ears_back = 0.8
			rig.wag = 1.0
			rig.panting = false
		&"eat":
			var at_bowl := _arrived and _eat_left > 0.0
			rig.pose = DogRig.Pose.STAND
			rig.nose_down = 1.0 if at_bowl else 0.0
			rig.chewing = at_bowl
			rig.wag = 0.45
			if not at_bowl and target.is_finite():
				rig.look_at_point = target
		&"greet":
			rig.pose = DogRig.Pose.STAND
			rig.nose_down = 0.0
			if target.is_finite():
				rig.look_at_point = target + Vector3(0, 1.3, 0)
			rig.wag = 1.0 if _mode_t < 20.0 else 0.7
			rig.panting = _arrived and _mode_t < 25.0


# --- Roaming ---------------------------------------------------------------------------------

func _night() -> bool:
	var h := GameClock.get_hour_float()
	return h < 6.0 or h > 21.5


func _start_act(act: Act) -> void:
	_act = act
	_act_t = 0.0
	_want_speed = 0.0
	_goal = Vector3.INF
	match act:
		Act.WANDER:
			_goal = _pick_spot(3.5)
		Act.SNIFF:
			_goal = _pick_spot(1.4)


## Next thing to do, roaming (at night mostly lying down asleep).
func _next_act() -> void:
	if _night() and randf() < 0.8:
		_start_act(Act.LIE)
		return
	var total := 0.0
	for a: Act in ACT_WEIGHTS:
		total += float(ACT_WEIGHTS[a]) * (0.3 if a == _act else 1.0)
	var r := randf() * total
	for a: Act in ACT_WEIGHTS:
		r -= float(ACT_WEIGHTS[a]) * (0.3 if a == _act else 1.0)
		if r <= 0.0:
			_start_act(a)
			return
	_start_act(Act.STAND)


func _act_len(act: Act) -> float:
	var span: Vector2 = ACT_TIME.get(act, Vector2(3.0, 6.0))
	return randf_range(span.x, span.y) * (2.5 if act == Act.LIE and _night() else 1.0)


func _roam(delta: float) -> void:
	_act_t += delta
	_wag_t -= delta
	_wag_wait -= delta
	if _wag_wait <= 0.0:
		_wag_wait = randf_range(8.0, 20.0)
		_wag_t = randf_range(1.5, 4.0)
	match _act:
		Act.WANDER, Act.SNIFF:
			var sniff := _act == Act.SNIFF
			if not _goal.is_finite() or _flat(_goal - global_position).length() < 0.15 or _act_t > 20.0:
				if sniff and _act_t < _act_len(Act.SNIFF) * 0.5:
					_goal = _pick_spot(1.2)
				else:
					_next_act()
				return
			_head_to(_goal, (SNIFF if sniff else WALK) * gait_scale, delta)
			if _blocked():
				_goal = _pick_spot(2.5)
		_:
			_want_speed = 0.0
			# Sitting or lying stays put; standing turns now and then toward the player.
			if _player_near and _act == Act.STAND and _act_t > 1.0:
				_turn_to(_player_pos(), delta * 0.5)
			if _act_t > _act_len(_act) * (1.0 if _act != Act.STAND else 0.7) and _act_t > 3.0:
				_next_act()


## A spot in the garden within `reach` of the dog (its nose short of the edge wherever it
## faces there).
func _pick_spot(reach: float) -> Vector3:
	var area := _inner(NOSE_REACH + NOSE_INSET)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return global_position
	for i in 12:
		var a := randf() * TAU
		var r := randf_range(reach * 0.35, reach)
		var p := Vector2(global_position.x + cos(a) * r, global_position.z + sin(a) * r)
		if area.has_point(p) and not _path_blocked(Vector3(p.x, global_position.y, p.y)):
			return Vector3(p.x, global_position.y, p.y)
	var c := area.get_center()
	return Vector3(c.x, global_position.y, c.y)


func _inner(inset: float) -> Rect2:
	if home_area.size == Vector2.ZERO:
		return Rect2(Vector2(global_position.x, global_position.z) - Vector2(4, 4), Vector2(8, 8))
	return home_area.grow(-inset)


# --- The other modes -----------------------------------------------------------------------

## Turns to face the petter (on the spot) and sits.
func _petted(delta: float) -> void:
	_want_speed = 0.0
	if target.is_finite():
		_turn_to(_petted_facing(), delta)
	if _sound_t <= 0.0:
		_sound_t = randf_range(6.0, 12.0)
		if randf() < 0.35:
			_sound("dog_whine", -14.0)


## Where it faces, petted: petted_toward, or else the petter.
func _petted_facing() -> Vector3:
	return petted_toward if petted_toward.is_finite() else target


## To the bowl, head down in it, then back to roaming.
func _eat(delta: float) -> void:
	if not target.is_finite():
		set_mode(&"roam")
		return
	if not _arrived:
		var spot := _eat_spot()
		var d := _flat(spot - global_position).length()
		if d > 0.06 and _mode_t < 25.0:
			_head_to(spot, (WALK if d > 0.4 else 0.35) * gait_scale, delta)
			return
		_want_speed = 0.0
		_turn_to(target, delta)
		if _facing(target, 0.12) or _mode_t > 25.0:
			_arrived = true
			_sound_t = 0.6
		return
	_want_speed = 0.0
	_turn_to(target, delta * 0.3)
	_eat_left -= delta
	if _sound_t <= 0.0 and rig.sit_amount() < 0.1:
		_sound_t = randf_range(1.1, 1.8)
		_sound("dog_eat", -9.0)
	if _eat_left <= 0.0:
		set_mode(&"roam")
		ate.emit()


## Where the dog stands to reach the bowl with its nose, coming at it from where it is.
func _eat_spot() -> Vector3:
	var dir := _flat(target - global_position)
	if dir.length() < 0.05:
		dir = -global_transform.basis.z
	dir = dir.normalized()
	var reach := Vector2(_eat_nose.x, _eat_nose.z).length()
	var spot := target - dir * reach
	var area := _inner(0.15)
	if home_area.size != Vector2.ZERO:
		spot.x = clampf(spot.x, area.position.x, area.end.x)
		spot.z = clampf(spot.z, area.position.y, area.end.y)
	return Vector3(spot.x, global_position.y, spot.z)


## Up to the player (trotting when far), as close as the garden lets it, then facing him.
func _greet(delta: float) -> void:
	if not target.is_finite():
		set_mode(&"roam")
		return
	var to := _flat(target - global_position)
	var spot := target - to.normalized() * GREET_GAP if to.length() > GREET_GAP else global_position
	var area := _inner(ROAM_INSET)
	if home_area.size != Vector2.ZERO:
		spot.x = clampf(spot.x, area.position.x, area.end.x)
		spot.z = clampf(spot.z, area.position.y, area.end.y)
	var d := _flat(spot - global_position).length()
	if d > 0.25 and not _arrived:
		_head_to(Vector3(spot.x, global_position.y, spot.z), (TROT if d > 2.0 else WALK) * gait_scale, delta)
		if _speed < 0.05 and _mode_t > 1.5 and _blocked():
			_arrived = true
		return
	_arrived = d < 0.8
	_want_speed = 0.0
	_turn_to(target, delta)
	if _sound_t <= 0.0:
		_sound_t = randf_range(5.0, 9.0)
		if _mode_t < 25.0 and randf() < 0.5:
			_sound("dog_pant", -12.0)
		elif randf() < 0.2:
			bark()


# --- Moving --------------------------------------------------------------------------------

## Heads for `goal` at `speed`, turning first where it has to turn a lot.
func _head_to(goal: Vector3, speed: float, delta: float) -> void:
	var to := _flat(goal - global_position)
	if to.length() < 0.02:
		_want_speed = 0.0
		return
	var want := atan2(-to.x, -to.z)
	var diff := angle_difference(_yaw, want)
	_yaw += clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
	# Slows into sharp turns and as it arrives.
	var turn_k := clampf(1.0 - (absf(diff) - 0.35) / 1.0, 0.0, 1.0)
	_want_speed = speed * turn_k * clampf(to.length() / 0.35, 0.25, 1.0)


func _turn_to(p: Vector3, delta: float) -> void:
	var to := _flat(p - global_position)
	if to.length() < 0.05:
		return
	var want := atan2(-to.x, -to.z)
	# Sitting it shuffles round slowly.
	var rate := TURN_RATE * (0.35 if rig.sit_amount() > 0.3 else 0.8)
	_yaw += clampf(angle_difference(_yaw, want), -rate * delta, rate * delta)


func _facing(p: Vector3, tolerance: float) -> bool:
	if not p.is_finite():
		return true
	var to := _flat(p - global_position)
	return to.length() < 0.05 or absf(angle_difference(_yaw, atan2(-to.x, -to.z))) < tolerance


func _move(delta: float) -> void:
	# Sitting or lying down it doesn't walk off: it gets up first.
	var up := rig.sit_amount() < 0.05 and rig.lie_amount() < 0.05
	var want := _want_speed if up else 0.0
	_speed = move_toward(_speed, want, ACCEL * delta)
	rotation.y = _yaw
	if _speed > 0.001:
		var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var next := global_position + fwd * _speed * delta
		# Set down outside its garden, it may only come back in.
		if _inside(next, fwd) or _outside_by(next) < _outside_by(global_position) - 0.0001:
			global_position = next
		else:
			_speed = 0.0
			if mode == &"roam" and _act in [Act.WANDER, Act.SNIFF]:
				_goal = _pick_spot(3.0)
	var h := _ground_at(global_position.x, global_position.z)
	_floor_y = h if absf(h - _floor_y) > 0.5 else lerpf(_floor_y, h, 1.0 - exp(-delta * 12.0))
	global_position.y = _floor_y


## Whether the dog's middle keeps ROAM_INSET inside its garden and its nose NOSE_INSET.
func _inside(p: Vector3, fwd: Vector3) -> bool:
	if home_area.size == Vector2.ZERO:
		return true
	var nose := p + fwd * NOSE_REACH
	return _inner(ROAM_INSET).has_point(Vector2(p.x, p.z)) and _inner(NOSE_INSET).has_point(Vector2(nose.x, nose.z))


## How far a point is outside the rectangle the dog's middle keeps to (0 inside).
func _outside_by(p: Vector3) -> float:
	if home_area.size == Vector2.ZERO:
		return 0.0
	var r := _inner(ROAM_INSET)
	var d := Vector2(maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0), maxf(maxf(r.position.y - p.z, p.z - r.end.y), 0.0))
	return d.length()


## Something solid just ahead (a kennel, boxes, a wall).
func _blocked() -> bool:
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	return _ray(global_position + Vector3(0, 0.3, 0), global_position + Vector3(0, 0.3, 0) + fwd * (NOSE_REACH + 0.15))


func _path_blocked(to: Vector3) -> bool:
	var a := global_position + Vector3(0, 0.3, 0)
	var b := Vector3(to.x, a.y, to.z)
	var dir := _flat(b - a).normalized()
	return _ray(a, b + dir * NOSE_REACH)


func _ray(a: Vector3, b: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## The ground's height under (x, z): the world's colliders (the garden, a step), else the
## terrain.
func _ground_at(x: float, z: float) -> float:
	var y := global_position.y if is_inside_tree() else 0.0
	if is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, y + 1.0, z), Vector3(x, y - 2.0, z), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			return (hit["position"] as Vector3).y
	return TerrainData.height(x, z)


func _snap_to_ground() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_floor_y = _ground_at(global_position.x, global_position.z)
	global_position.y = _floor_y


## The collider along the body, low when it lies, tilted up when it sits.
func _place_collider() -> void:
	if _shape == null or rig == null:
		return
	var s := rig.sit_amount() * (1.0 - rig.lie_amount())
	var l := rig.lie_amount()
	var pitch := lerpf(PI * 0.5, PI * 0.5 - 0.65, s)
	var y := lerpf(lerpf(0.4, 0.34, s), 0.2, l)
	_shape.transform = Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0, y, lerpf(0.02, 0.1, s)))


func _sound(set_name: String, volume_db: float) -> void:
	var at := rig.nose_world() if rig and rig.skeleton else global_position + Vector3(0, 0.5, 0)
	Audio.play(set_name, at, volume_db, 0.06, &"Effects", 5.0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
