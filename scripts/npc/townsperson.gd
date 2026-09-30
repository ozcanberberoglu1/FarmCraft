class_name Townsperson
extends AnimatableBody3D
## One of Yeşilova's townspeople (see TownPeople for who stands where): a HumanRig body
## doing its job or its day, looking at the player when he comes close and greeting him.
##
## Acts: STAND (idle, looking about), TALK (the car dealer: hands clasped, then selling
## with his hands), TILL (the grocer counting notes at the till), WIPE (the pump
## attendant wiping his pump), WRITE (the stockman at his hatch with the ledger), SWEEP
## (the shop boy sweeping the forecourt, a step at a time), BENCH (an old man sitting),
## TEA (sitting with a glass of tea, sipping) and WALK (along a route on the pavements,
## over the zebra crossing when the street is clear, round the player, vehicles and
## each other; turning back when the way stays blocked).
##
## E: a worker at a service (the counter, a pump with the player's vehicle at it, the
## dealer's desk, the Animal Market hatch) greets and opens it, so standing there never
## steals the service's prompt; anyone else is greeted and answers with a line of his
## own. Workers also welcome the player when he walks up. Animated only within
## ANIMATE_RANGE of the camera (less often off screen), drawn up to SHOW_RANGE.

enum Act { STAND, TALK, TILL, WIPE, WRITE, SWEEP, BENCH, TEA, WALK }

const GROUP := &"townspeople"
const ANIMATE_RANGE := 60.0
const NEAR_RANGE := 25.0
## Drawn up to (by graphics preset, LOW..ULTRA).
const SHOW_RANGE: Array[float] = [70.0, 90.0, 120.0, 140.0]
const LOOK_RANGE := 6.5
const WELCOME_RANGE := 4.0
const WELCOME_COOLDOWN := 150.0
const BUBBLE_SECONDS := 4.0
const GREET_SECONDS := 1.9
## Nuri Hoca's greeting: the glass put down on the table, the hand on the heart, the
## glass picked up again.
const TEA_GREET := 3.6
## How many lines each person has (SAY_<PERSON>_1..n).
const LINES := 2
## Walkers: how far off the route's line they step aside, how long they wait for a
## blocked way before turning back.
const MAX_LATERAL := 0.85
const GIVE_UP := 4.5

var person: StringName
var act := Act.STAND
var rig: HumanRig
## The service E opens (a TownPoint), or the pumps the attendant serves.
var service: Node
var pumps: Array = []
var worker := false
## Heights above the floor: the work surface (counter) and the seat.
var work_height := 1.0
var seat_height := 0.45
var waves := false
var hands_behind := false
var walk_speed := 1.1
## Walkers: waypoints {p: Vector3 (y ignored), wait: seconds, face: yaw or NAN}; a leg
## from one side of the street to the other is the zebra crossing.
var route: Array = []
## The sweeper: the line he sweeps along (world XZ, from - to).
var sweep_from := Vector3.ZERO
var sweep_to := Vector3.ZERO
## The tea drinker: the middle of his table's top (world), where he puts his glass down.
var tea_table := Vector3.INF

var _floor_y := 0.0
var _yaw := 0.0
var _speed := 0.0
var _wp := 1
var _dir := 1
var _wait := 0.0
var _blocked := 0.0
var _lateral := 0.0
var _crossing := false
var _probe_t := 0.0
var _greet_t := 99.0
var _stop_t := 0.0
var _line := 0
var _welcomed_at := -999.0
var _bubble: Label3D
var _bubble_t := 0.0
var _anim_acc := 0.0
var _look_target := Vector3.ZERO
var _look_t := 0.0
var _look_w := 0.0
var _prop: Node3D
var _sweep_s := 0.0
var _sweep_n := 0
var _step_left := 0.0
var _last_stroke := 0.0
var _last_step_phase := 0.0
var _on_screen: VisibleOnScreenNotifier3D
var _clock := 0.0
## The broom: 0 sweeping .. 1 held upright at his side (stopped to greet); the bristles'
## height above the ground; the right hand still on the handle.
var _broom_hold := 0.0
var _broom_lift := 0.0
var _broom_two_hands := true
## The tea glass: in his hand, or on the table at _glass_spot (body frame).
var _glass_in_hand := true
var _glass_spot := Vector3(-0.16, 0.73, 0.46)
## Microseconds all townspeople spent posing their bodies (a cost gauge for tests).
static var anim_usec := 0


func setup(model: StringName, tints: Dictionary = {}) -> void:
	rig = HumanRig.create(model, tints)
	rig.name = "Body"
	add_child(rig)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	collision_layer = 4 | 16
	collision_mask = 0
	sync_to_physics = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	var seated := act in [Act.BENCH, Act.TEA]
	cap.height = 1.25 if seated else 1.72
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5 + (0.05 if seated else 0.0), 0.1 if seated else 0.0)
	add_child(cs)
	_on_screen = VisibleOnScreenNotifier3D.new()
	_on_screen.aabb = AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.9, 1.2))
	add_child(_on_screen)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font = UiTheme.font(700)
	_bubble.font_size = 44
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.05, 0.05, 0.06, 0.85)
	_bubble.modulate = Color(1.0, 0.97, 0.9)
	_bubble.pixel_size = 0.0021
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.width = 700.0
	_bubble.visible = false
	_bubble.fixed_size = false
	_bubble.no_depth_test = false
	add_child(_bubble)
	_yaw = rotation.y
	_floor_y = global_position.y
	if act == Act.SWEEP:
		_sweep_s = (_flat(position) - _flat(sweep_from)).dot((_flat(sweep_to) - _flat(sweep_from)).normalized())
		_prop = _broom()
		rig.add_child(_prop)
	elif act == Act.TEA:
		_prop = _tea_glass()
		rig.add_child(_prop)
		if tea_table.is_finite():
			# On the near side of the table, clear of the glasses standing on it.
			var c := to_local(tea_table)
			var toward := Vector3(-0.12, 0.0, 0.2) - Vector3(c.x, 0.0, c.z)
			_glass_spot = Vector3(c.x, c.y, c.z) + toward.normalized() * minf(0.27, toward.length())
	rig.reset()
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	_snap_to_ground.call_deferred()


func _apply_quality() -> void:
	rig.apply_quality()
	var r: float = SHOW_RANGE[Settings.quality]
	rig.body.visibility_range_end = r
	rig.body.visibility_range_end_margin = 8.0
	rig.body.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if _prop:
		for mi: MeshInstance3D in _prop.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = minf(r, 60.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if Settings.quality == Settings.Quality.LOW else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _snap_to_ground() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var h := _ground(global_position.x, global_position.z, global_position.y)
	if act in [Act.BENCH, Act.TEA]:
		return
	global_position.y = h
	_floor_y = h


func _ground(x: float, z: float, near_y: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, near_y + 1.2, z), Vector3(x, near_y - 2.0, z), 1)
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else near_y


# --- Interaction -----------------------------------------------------------------------------

func interact_title() -> String:
	return tr("PERSON_" + String(person).to_upper())


func interact_prompt(player: Node) -> String:
	var s := service_now()
	if s != null:
		return s.interact_prompt(player)
	return tr("ACTION_GREET")


func interact(player: Node) -> void:
	greet()
	var s := service_now()
	if s != null:
		s.interact(player)


## The service E on this person opens now: his counter or desk, or the pump the
## player's vehicle stands at (the attendant); null: a greeting only.
func service_now() -> Node:
	if service != null and is_instance_valid(service):
		return service
	for p: Node3D in pumps:
		if is_instance_valid(p) and Town._nearest_owned_vehicle(p.global_position, 7.5) != null:
			return p
	return null


## Says the next of his lines (a speech bubble over his head) with a gesture, turned
## to the player; a walker stops for it.
func greet(line := -1) -> void:
	_line = (line if line >= 0 else _line) % LINES
	say(tr("SAY_%s_%d" % [String(person).to_upper(), _line + 1]))
	_line += 1
	# A greeting under way isn't started over (the hand would jump back): while the hand
	# is on the heart it stays there longer.
	var hold := Vector2(1.3, 2.4) if act == Act.TEA else Vector2(0.45, GREET_SECONDS - 0.5)
	if _greet_t >= _greet_len():
		_greet_t = 0.0
	elif _greet_t > hold.x and _greet_t < hold.y:
		_greet_t = hold.x
	_welcomed_at = _clock
	if act == Act.WALK or act == Act.SWEEP:
		_stop_t = 3.2


func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bubble_t = BUBBLE_SECONDS


func is_speaking() -> bool:
	return _bubble.visible


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else global_position + Vector3(0, 50, 0)


# --- Frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	var cam := _camera_pos()
	var dist := cam.distance_to(global_position)
	if _bubble.visible:
		_bubble_t -= delta
		_bubble.modulate.a = clampf(_bubble_t / 0.6, 0.0, 1.0)
		if _bubble_t <= 0.0:
			_bubble.visible = false
	_greet_t += delta
	if worker and dist < WELCOME_RANGE and _clock - _welcomed_at > WELCOME_COOLDOWN and Game.player and (Game.player as Player).driving == null:
		greet(0)
	# Past ANIMATE_RANGE only someone on the move keeps moving his legs (a few times a
	# second, as far as he is drawn): a frozen stride sliding along would show.
	var moving := _speed > 0.05
	if dist > (SHOW_RANGE[Settings.quality] if moving else ANIMATE_RANGE):
		return
	_anim_acc += delta
	var every := 0.0
	if not _on_screen.is_on_screen():
		every = 0.3
	elif dist > ANIMATE_RANGE:
		every = 0.1
	elif dist > NEAR_RANGE:
		every = 1.0 / 15.0
	elif dist > 10.0:
		every = 1.0 / 30.0
	if _anim_acc < every:
		return
	var t0 := Time.get_ticks_usec()
	_animate(_anim_acc, cam)
	anim_usec += Time.get_ticks_usec() - t0
	_anim_acc = 0.0


func _physics_process(delta: float) -> void:
	_stop_t = maxf(_stop_t - delta, 0.0)
	if act == Act.WALK:
		_walk_route(delta)
	elif act == Act.SWEEP:
		_sweep_move(delta)


# --- Walking ---------------------------------------------------------------------------------

func _walk_route(delta: float) -> void:
	if route.size() < 2:
		return
	var here := global_position
	var target: Dictionary = route[_wp]
	var prev: Dictionary = route[posmod(_wp - _dir, route.size())]
	var to := _flat(target["p"]) - _flat(here)
	var seg := (_flat(target["p"]) - _flat(prev["p"])).normalized()
	var want := walk_speed
	var face := NAN
	if _stop_t > 0.0:
		want = 0.0
		face = _yaw_to(Game.player.global_position) if Game.player else NAN
	elif _wait > 0.0:
		_wait -= delta
		want = 0.0
		face = float(prev.get("face", NAN))
	elif _is_crossing(prev, target) and not _crossing:
		# At the kerb: over the zebra only when no vehicle stands on it or comes.
		if _road_clear(here):
			_crossing = true
		else:
			want = 0.0
			face = atan2(seg.x, seg.z)
			# A vehicle left on the crossing: after a while he walks on the way he came.
			_blocked += delta * 0.25
	var lateral_want := 0.0
	if want > 0.0:
		var probe := _flat(here) + seg * 1.2 + _left(seg) * _lateral
		var r := _obstacle(probe, here, seg)
		if r == 1:
			# Something ahead: step aside where it's free, else wait.
			var best := NAN
			for k in [0.5, -0.5, 0.85, -0.85, 0.25, -0.25]:
				var lat := clampf(_lateral + float(k), -MAX_LATERAL, MAX_LATERAL)
				if absf(lat - _lateral) < 0.2:
					continue
				if _obstacle(_flat(here) + seg * 1.2 + _left(seg) * lat, here, seg) == 0:
					best = lat
					break
			if is_nan(best):
				want = 0.0
				_blocked += delta
			else:
				lateral_want = best
		elif r == 2:
			lateral_want = -0.6
		else:
			_blocked = 0.0
			lateral_want = _lateral * 0.98 if absf(_lateral) > 0.05 else 0.0
	if _blocked > GIVE_UP:
		# Still blocked: turn back the way he came.
		_blocked = 0.0
		_dir = -_dir
		_wp = posmod(_wp + _dir, route.size())
		_crossing = false
		return
	if _is_crossing(prev, target):
		lateral_want = 0.0
	_lateral = move_toward(_lateral, lateral_want if want > 0.0 else _lateral, delta * 0.8)
	var aim := _flat(target["p"]) + _left(seg) * _lateral * clampf(to.length() / 2.0, 0.0, 1.0)
	var heading := aim - _flat(here)
	var move_yaw := atan2(heading.x, heading.z) if heading.length() > 0.05 else _yaw
	var turn := absf(wrapf(move_yaw - _yaw, -PI, PI))
	if want > 0.0 and turn > 0.9:
		want *= 0.3
	_speed = move_toward(_speed, want, delta * (1.6 if want > _speed else 3.0))
	var yaw_goal := move_yaw if _speed > 0.05 or want > 0.0 else (face if not is_nan(face) else _yaw)
	_yaw = _turn(_yaw, yaw_goal, delta * 2.6)
	rotation.y = _yaw
	if _speed > 0.001:
		var step := heading.normalized() * _speed * delta
		var p := here + Vector3(step.x, 0.0, step.z)
		_probe_t -= delta
		if _probe_t <= 0.0:
			_probe_t = 0.15
			_floor_y = _ground(p.x, p.z, _floor_y)
		p.y = lerpf(here.y, _floor_y, clampf(delta * 10.0, 0.0, 1.0))
		global_position = p
	if to.length() < 0.35 and _stop_t <= 0.0:
		_wait = float(target.get("wait", 0.0))
		_crossing = false
		_wp = posmod(_wp + _dir, route.size())


## A leg of the route over the street (its ends on either side): the zebra crossing.
static func _is_crossing(a: Dictionary, b: Dictionary) -> bool:
	return ((a["p"] as Vector3).z - Town.STREET_Z) * ((b["p"] as Vector3).z - Town.STREET_Z) < 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _left(dir: Vector3) -> Vector3:
	return Vector3(dir.z, 0.0, -dir.x)


func _yaw_to(p: Vector3) -> float:
	var d := p - global_position
	return atan2(d.x, d.z)


static func _turn(from: float, to: float, max_step: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -max_step, max_step)


## 0: free, 1: blocked (the player, a vehicle), 2: another walker coming (keep right).
func _obstacle(probe: Vector3, here: Vector3, seg: Vector3) -> int:
	var player := Game.player as Player
	if player and player.driving == null:
		var pp := _flat(player.global_position)
		if pp.distance_to(probe) < 1.0 or (pp.distance_to(_flat(here)) < 1.1 and (pp - _flat(here)).dot(seg) > 0.0):
			return 1
	for v: Node3D in get_tree().get_nodes_in_group(Vehicle.GROUP):
		var local := v.global_transform.affine_inverse() * Vector3(probe.x, v.global_position.y, probe.z)
		if absf(local.x) < 1.35 and absf(local.z) < 3.0:
			return 1
	for o: Townsperson in get_tree().get_nodes_in_group(GROUP):
		if o == self:
			continue
		if _flat(o.global_position).distance_to(probe) < 0.9:
			return 2 if o.act == Act.WALK else 1
	return 0


## The street is clear to cross at `at`: nothing on the crossing, nothing coming.
func _road_clear(at: Vector3) -> bool:
	for v: Node3D in get_tree().get_nodes_in_group(Vehicle.GROUP):
		var p := v.global_position
		if absf(p.z - Town.STREET_Z) > 6.0:
			continue
		var dx := p.x - at.x
		if absf(dx) < 5.0:
			return false
		var vel: Vector3 = (v as RigidBody3D).linear_velocity if v is RigidBody3D else Vector3.ZERO
		if absf(dx) < 30.0 and vel.length() > 0.8 and vel.x * dx < 0.0:
			return false
	return true


# --- Sweeping --------------------------------------------------------------------------------

## A few strokes where he stands, then a couple of steps on along the line; back at its end.
func _sweep_move(delta: float) -> void:
	var line := _flat(sweep_to) - _flat(sweep_from)
	var length := line.length()
	var dir := line / length
	if _step_left > 0.0 and _stop_t <= 0.0:
		var player := Game.player as Player
		var ahead := _flat(global_position) + dir * float(_dir) * 1.0
		if player and player.driving == null and _flat(player.global_position).distance_to(ahead) < 1.0:
			return
		var d := minf(delta * 0.55, _step_left)
		_step_left -= d
		_sweep_s = clampf(_sweep_s + d * float(_dir), 0.0, length)
		var p := _flat(sweep_from) + dir * _sweep_s
		p.y = global_position.y
		global_position = p
		_speed = 0.55
		if _sweep_s <= 0.0 or _sweep_s >= length:
			_dir = -_dir
	else:
		_speed = 0.0
	# He faces the way he sweeps along the line (turning round at its ends), or the
	# player who greeted him.
	var face := atan2(dir.x * float(_dir), dir.z * float(_dir))
	if _stop_t > 0.0 and Game.player:
		face = _yaw_to(Game.player.global_position)
	_yaw = _turn(_yaw, face, delta * 2.0)
	rotation.y = _yaw


# --- Animation -------------------------------------------------------------------------------

func _greet_len() -> float:
	return TEA_GREET if act == Act.TEA else GREET_SECONDS


func _animate(delta: float, cam: Vector3) -> void:
	rig.time += delta
	rig.begin()
	var greeting := _greet_t < _greet_len()
	# g: the nod and bow; the hand goes to the heart (or waves) and stays till near the end.
	var g := 0.0
	var hand := 0.0
	if greeting:
		if act == Act.TEA:
			g = sin(clampf((_greet_t - 0.9) / 1.8, 0.0, 1.0) * PI)
		else:
			g = sin(clampf(_greet_t / GREET_SECONDS, 0.0, 1.0) * PI)
			hand = smoothstep(0.0, 0.45, _greet_t) * (1.0 - smoothstep(GREET_SECONDS - 0.5, GREET_SECONDS, _greet_t))
	match act:
		Act.BENCH:
			rig.sit(seat_height, 0.2)
		Act.TEA:
			rig.sit(seat_height, 0.1, false)
		Act.WALK:
			if _speed > 0.05:
				rig.walk(delta, _speed, 0.85 if hands_behind else 1.0, not hands_behind and not greeting)
			else:
				rig.stance(0.0, false)
		Act.SWEEP:
			if _speed > 0.05:
				rig.walk(delta, _speed * 0.8, 0.7, false)
				rig.rot_x(&"spine_02", 0.16)
			else:
				rig.move_pelvis(Vector3(0.0, -0.035, -0.03))
				rig.stance(0.42, false)
		Act.WRITE:
			rig.stance(0.32, false)
		Act.TILL:
			rig.stance(0.12, false)
		_:
			rig.stance(0.0, false)
	if greeting:
		rig.rot_x(&"spine_03", g * 0.1)
	_look(delta, cam, g)
	match act:
		Act.TILL:
			_arms_till()
		Act.WRITE:
			_arms_write()
		Act.WIPE:
			_arms_wipe()
		Act.TALK:
			_arms_talk()
		Act.SWEEP:
			_arms_sweep(delta)
		Act.TEA:
			_arms_tea()
		Act.WALK:
			if hands_behind:
				_hands_behind()
			elif _speed <= 0.05 or greeting:
				rig.relaxed_arms()
		Act.STAND:
			if hands_behind:
				_hands_behind()
			else:
				rig.relaxed_arms()
	if hand > 0.0:
		_arms_greet(hand)
	_place_props()
	if _speed > 0.05 and act == Act.WALK:
		var ph := fposmod(rig.gait_phase * 2.0, 1.0)
		if ph < _last_step_phase and cam.distance_to(global_position) < 14.0:
			Audio.play("step_concrete", global_position, -21.0, 0.12, &"Effects", 2.0)
		_last_step_phase = ph
	rig.commit()
	if _bubble.visible:
		_bubble.position = rig.eye_point() + Vector3(0, 0.42, 0)


## The head: to the player when he is close and in front (a worker at work glances
## less), else looking about now and then; down at the work while working.
func _look(delta: float, cam: Vector3, greet_amount: float) -> void:
	var local := to_local(cam)
	var d := local - rig.eye_point()
	var facing := absf(atan2(d.x, d.z))
	var near := d.length() < LOOK_RANGE and facing < 1.9
	var busy := _busy()
	var w := 0.0
	if near:
		w = 1.0 if (not busy or greet_amount > 0.0 or d.length() < 2.6) else 0.55
	_look_w = move_toward(_look_w, w, delta * 1.5)
	if _look_w > 0.02:
		rig.look_at_point(local, _look_w, delta)
		if greet_amount > 0.0:
			rig.rot_x(&"head", greet_amount * 0.28)
		return
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(2.5, 6.5)
		var yaw := randf_range(-0.9, 0.9) if act != Act.WALK else randf_range(-0.4, 0.4)
		var pitch := randf_range(-0.15, 0.1)
		if busy:
			yaw *= 0.3
			pitch = 0.45
		_look_target = rig.eye_point() + Vector3(sin(yaw), -sin(pitch), cos(yaw)) * 3.0
	if busy:
		_look_target = _work_point()
	rig.look_at_point(_look_target, 0.85, delta)
	if greet_amount > 0.0:
		rig.rot_x(&"head", greet_amount * 0.28)


func _busy() -> bool:
	match act:
		Act.TILL:
			return fmod(rig.time + rig.seed_phase, 14.0) < 8.0
		Act.WRITE:
			return fmod(rig.time + rig.seed_phase, 12.0) < 7.5
		Act.WIPE:
			return _wiping()
		Act.SWEEP:
			return _speed < 0.05
	return false


func _work_point() -> Vector3:
	match act:
		Act.SWEEP:
			return _broom_head
		Act.TILL, Act.WRITE:
			return Vector3(-0.05, work_height, 0.42)
		Act.WIPE:
			return Vector3(-0.05, 1.2, 0.45)
	return rig.eye_point() + Vector3(0, -0.5, 2.0)


func _pole(side: String) -> Vector3:
	var sgn := 1.0 if side == "_l" else -1.0
	return Vector3(sgn * 0.7, -0.3, -0.6)


func _flat_hand(side: String, at: Vector3, fingers := Vector3(0, 0, 1)) -> void:
	var sgn := 1.0 if side == "_l" else -1.0
	rig.reach(side, at, _pole(side))
	rig.orient_hand(side, fingers + Vector3(-sgn * 0.15, 0, 0), Vector3(0, -1, 0))
	rig.curl(side, 0.15, 0.2)


func _arms_till() -> void:
	var top := work_height + 0.04
	if fmod(rig.time + rig.seed_phase, 14.0) < 8.0:
		# Counting notes: the left hand holds the wad up, the right flicks them over.
		var c := fmod(rig.time * 1.6, 1.0)
		var flick := sin(c * PI)
		rig.reach("_l", Vector3(0.1, top + 0.06, 0.42), _pole("_l"))
		rig.orient_hand("_l", Vector3(-0.5, 0.2, 1.0), Vector3(-0.4, 0.4, -0.3))
		rig.curl("_l", 0.45, 0.2)
		rig.reach("_r", Vector3(-0.12 + flick * 0.07, top + 0.03 + flick * 0.05, 0.44), _pole("_r"))
		rig.orient_hand("_r", Vector3(0.5, -0.1, 1.0), Vector3(0.3, -0.6, 0.0))
		rig.curl("_r", 0.3 + flick * 0.2, 0.3)
		if c < _last_stroke and fmod(rig.time, 5.0) < 1.0:
			Audio.play("coins_small", global_position + Vector3(0, 1, 0), -22.0, 0.1, &"Effects", 2.0)
		_last_stroke = c
	else:
		_flat_hand("_l", Vector3(0.2, top, 0.38))
		_flat_hand("_r", Vector3(-0.2, top, 0.4))


func _arms_write() -> void:
	var top := work_height + 0.05
	_flat_hand("_l", Vector3(0.18, top, 0.4), Vector3(-0.4, 0, 1))
	var w := fmod(rig.time + rig.seed_phase, 12.0) < 7.5
	var s := Vector3(sin(rig.time * 9.0) * 0.012 + fmod(rig.time * 0.8, 1.0) * 0.08, 0.0, cos(rig.time * 11.0) * 0.008) if w else Vector3.ZERO
	rig.reach("_r", Vector3(-0.12, top + 0.02, 0.4) + s, _pole("_r"))
	rig.orient_hand("_r", Vector3(0.5, -0.2, 1.0), Vector3(0.1, -1, -0.2))
	rig.curl("_r", 0.55, 0.5)


func _wiping() -> bool:
	return fmod(rig.time + rig.seed_phase, 13.0) < 5.0


func _arms_wipe() -> void:
	if _wiping():
		var a := rig.time * 5.0
		rig.reach("_r", Vector3(-0.06 + cos(a) * 0.1, 1.2 + sin(a) * 0.08, 0.42), _pole("_r"))
		rig.orient_hand("_r", Vector3(0.2, 1.0, 0.1), Vector3(0, 0, 1))
		rig.curl("_r", 0.2, 0.2)
		rig.reach("_l", Vector3(0.24, 1.25, 0.38), _pole("_l"))
		rig.orient_hand("_l", Vector3(0, 1.0, 0.1), Vector3(0, 0, 1))
		rig.curl("_l", 0.1, 0.2)
	else:
		_hands_behind()


func _arms_talk() -> void:
	var t := fmod(rig.time + rig.seed_phase, 11.0)
	if t < 4.5 or is_speaking():
		# Selling: open hands up in front, moving with the words.
		var wl := rig.wobble(2.2, 3.0)
		var wr := rig.wobble(2.6, 5.0)
		rig.reach("_l", Vector3(0.2 + wl * 0.05, 1.08 + wl * 0.06, 0.34), _pole("_l"))
		rig.orient_hand("_l", Vector3(-0.2, 0.3, 1.0), Vector3(-0.5, 0.8, 0.0))
		rig.curl("_l", 0.2, 0.2)
		rig.reach("_r", Vector3(-0.22 + wr * 0.06, 1.12 + wr * 0.07, 0.36), _pole("_r"))
		rig.orient_hand("_r", Vector3(0.2, 0.3, 1.0), Vector3(0.5, 0.8, 0.0))
		rig.curl("_r", 0.2, 0.2)
	else:
		# Hands clasped in front.
		var c := Vector3(0.0, rig.pelvis_y + 0.04, 0.2)
		rig.reach("_l", c + Vector3(0.035, 0.0, 0.0), _pole("_l"))
		rig.orient_hand("_l", Vector3(-1, -0.4, 0.3), Vector3(-0.2, 0, -1))
		rig.reach("_r", c + Vector3(-0.03, 0.02, 0.02), _pole("_r"))
		rig.orient_hand("_r", Vector3(1, -0.4, 0.3), Vector3(0.2, 0, -1))
		rig.curl("_l", 0.5, 0.4)
		rig.curl("_r", 0.5, 0.4)


func _hands_behind() -> void:
	var c := Vector3(0.0, rig.pelvis_y + 0.09, -0.24)
	rig.reach("_l", c + Vector3(0.05, 0.0, 0.0), Vector3(0.8, 0.0, 0.2))
	rig.orient_hand("_l", Vector3(-1, -0.3, 0), Vector3(0, 0, -1))
	rig.reach("_r", c + Vector3(-0.04, 0.02, -0.02), Vector3(-0.8, 0.0, 0.2))
	rig.orient_hand("_r", Vector3(1, -0.3, 0), Vector3(0, 0, -1))
	rig.curl("_l", 0.55, 0.4)
	rig.curl("_r", 0.6, 0.4)


var _broom_head := Vector3(0, 0, 0.5)


## The broom: strokes from his right to his left across the ground in front, the head
## lifted on the way back; the left fist at the top leads, the right one lower down
## pushes, the handle through both. Stopped to greet, he stands it upright at his left
## side in the left hand (the right one goes to his heart).
func _arms_sweep(delta: float) -> void:
	var stroke := fmod(rig.time * 0.95 + rig.seed_phase, 1.0)
	var bx := 0.0
	var lift := 0.0
	if _speed > 0.05 or _stop_t > 0.0:
		bx = 0.0
		lift = 0.08
	elif stroke < 0.45:
		bx = lerpf(-0.42, 0.22, smoothstep(0.0, 0.45, stroke))
	else:
		bx = lerpf(0.22, -0.42, smoothstep(0.45, 1.0, stroke))
		lift = sin((stroke - 0.45) / 0.55 * PI) * 0.07
	if _speed <= 0.05 and _stop_t <= 0.0:
		if stroke < _last_stroke:
			_sweep_n += 1
			if _sweep_n >= 5:
				_sweep_n = 0
				_step_left = 0.7
			if _camera_pos().distance_to(global_position) < 18.0:
				Audio.play("brush", global_position + transform.basis.z * 0.6, -15.0, 0.15, &"Effects", 3.0, 0.75)
		_last_stroke = stroke
	# Stopped to greet, or stepping on: the broom stood (carried) upright at his left.
	_broom_hold = move_toward(_broom_hold, 1.0 if _stop_t > 0.0 or _speed > 0.05 else 0.0, delta * 2.5)
	var up := smoothstep(0.0, 1.0, _broom_hold)
	# The left fist near the top at his waist, the right one a forearm lower down the
	# handle (both within reach of the bent-over body), the bristles out in front.
	var y0 := rig.pelvis_y
	var head := Vector3(bx - 0.14, lift, 0.6).lerp(Vector3(0.36, 0.05 if _speed > 0.05 else 0.0, 0.3), up)
	var top := Vector3(-0.07 + bx * 0.25, y0 + 0.3, 0.3).lerp(Vector3(0.25, y0 + 0.08, 0.2), up)
	_broom_head = head
	_broom_lift = head.y
	rig.rot_y(&"spine_02", bx * 0.25 * (1.0 - up))
	var axis := (top - head).normalized()
	var low := top - axis * 0.23
	rig.hold("_l", top, axis, Vector3(-1, 0.1, 0.1), _pole("_l"), 0.85)
	var grip := rig.hold_pose("_r", low, axis, Vector3(-1, -0.25, 0.2))
	_broom_two_hands = up <= 0.0
	if _broom_two_hands:
		rig.hold("_r", low, axis, Vector3(-1, -0.25, 0.2), _pole("_r"), 0.85)
	else:
		# The right hand lets go and hangs at his side while the broom stands.
		rig.pose_between("_r", grip, rig.relaxed_pose("_r"), up, _pole("_r"), 0.85, 0.35)


## Nuri Hoca at his tea: the glass in his right hand, raised to sip now and then; the left
## hand on its thigh. Greeted, he puts the glass down on the table, lays his hand on his
## heart, then takes the glass up again.
func _arms_tea() -> void:
	var t := fmod(rig.time + rig.seed_phase, 16.0)
	var sip := smoothstep(0.0, 0.8, t) * (1.0 - smoothstep(2.4, 3.2, t))
	var gt := _greet_t if _greet_t < TEA_GREET else -1.0
	# The left hand on its thigh.
	var knee := rig.pos(rig.bi(&"calf_l"))
	var hip := rig.pos(rig.bi(&"thigh_l"))
	rig.reach("_l", hip.lerp(knee, 0.6) + Vector3(0.02, 0.07, 0.0), Vector3(0.6, -0.2, -1.0))
	rig.orient_hand("_l", Vector3(-0.25, -0.35, 1.0), Vector3(0, -1, 0))
	rig.curl("_l", 0.3, 0.3)
	# The glass held in front of him, or at his lips, tipped towards him.
	var at := Vector3(-0.07, seat_height + 0.31, 0.3).lerp(rig.eye_point() + Vector3(-0.01, -0.17, 0.085), sip)
	if is_speaking() and sip < 0.05 and gt < 0.0:
		at += Vector3(rig.wobble(3.0, 1.0) * 0.04, rig.wobble(2.4, 2.0) * 0.05 + 0.06, 0.04)
	var glass_up := Vector3(0.0, cos(sip * 0.55), -sin(sip * 0.55))
	# Greeted: down on the table (0-0.8 s), hand on the heart (0.8-2.9 s), up again.
	var down := 0.0
	var heart := 0.0
	_glass_in_hand = true
	if gt >= 0.0:
		if gt < 0.8:
			down = smoothstep(0.0, 0.8, gt)
		elif gt < 2.9:
			down = 1.0
			_glass_in_hand = false
			heart = smoothstep(0.8, 1.3, gt) * (1.0 - smoothstep(2.4, 2.9, gt))
		else:
			down = 1.0 - smoothstep(2.9, 3.6, gt)
	if down > 0.0:
		rig.rot_x(&"spine_02", down * (1.0 - heart) * 0.22)
		at = at.lerp(_glass_spot + Vector3(0.0, 0.042, 0.0), down) + Vector3(0.0, sin(down * PI) * 0.05, 0.0)
		glass_up = glass_up.slerp(Vector3.UP, down)
	rig.hold("_r", at, glass_up, Vector3(0.3, -0.1, 1.0), _pole("_r"), 0.62)
	if heart > 0.0:
		rig.hand_on_heart("_r", heart)
	if sip > 0.5:
		rig.rot_x(&"head", -sip * 0.12)


## Right hand on the heart and a nod ("hoş geldin"); the young man waves instead.
## `amount`: 0 at the work .. 1 on the heart.
func _arms_greet(amount: float) -> void:
	if waves:
		rig.wave("_r", amount, _greet_t * 11.0)
	elif act != Act.TEA:
		rig.hand_on_heart("_r", amount)
	if act == Act.SWEEP and amount > 0.02:
		_broom_two_hands = false


## Held things go where the hands holding them are now (the pose just made).
func _place_props() -> void:
	if _prop == null:
		return
	match act:
		Act.SWEEP:
			# The handle through the left fist (and the right one while it holds on), the
			# bristles on the ground (or lifted off it).
			var gl := rig.grip_point("_l")
			var axis := (gl - rig.grip_point("_r")).normalized() if _broom_two_hands else (gl - _broom_head).normalized()
			# (a fist that fell short of its place on the handle: the handle through the
			# top one to where the bristles should be)
			if axis.y < 0.3 or (gl.y - _broom_lift) / axis.y > 1.44:
				axis = (gl - _broom_head).normalized()
			var head := gl - axis * ((gl.y - _broom_lift) / axis.y)
			var z := (Vector3.RIGHT - axis * axis.x).normalized()
			_prop.transform = Transform3D(Basis(axis.cross(z), axis, z), head)
		Act.TEA:
			if _glass_in_hand:
				# Upright along the fist's thumb side, held a little below its middle.
				var ax := rig.hand_axes("_r")
				var up := ax.z.normalized()
				var x := (ax.x - up * ax.x.dot(up)).normalized()
				_prop.transform = Transform3D(Basis(x, up, x.cross(up)), rig.grip_point("_r") - up * 0.042)
			else:
				_prop.transform = Transform3D(Basis(), _glass_spot)


# --- Props -----------------------------------------------------------------------------------

static func _broom() -> Node3D:
	var mb := MeshBuilder.new()
	mb.cylinder(&"wood", Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.013, 0.012, 1.2, 8, Color(0.55, 0.42, 0.28))
	mb.box_at(&"metal", Vector3(0, 0.29, 0), Vector3(0.05, 0.05, 0.05), Color(0.6, 0.15, 0.1))
	for k in 9:
		var a := (float(k) / 8.0 - 0.5) * 0.7
		mb.box(&"straw", Transform3D(Basis(Vector3.BACK, a), Vector3(sin(a) * 0.14, 0.15, 0.0)), Vector3(0.05, 0.3, 0.025), Color(0.72, 0.6, 0.36).darkened(randf() * 0.15))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.name = "Broom"
	var n := Node3D.new()
	n.add_child(mi)
	return n


static func _tea_glass() -> Node3D:
	var mb := MeshBuilder.new()
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), Vector3(0, 0.005, 0)), 0.018, 0.014, 0.045, 10, Color(0.42, 0.07, 0.03))
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.014, 0.019, 0.035, 10, Color(0.45, 0.08, 0.03))
	mb.cylinder(&"glass", Transform3D(Basis(), Vector3.ZERO), 0.022, 0.017, 0.05, 12, Color(1, 1, 1, 0.3))
	mb.cylinder(&"glass", Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.017, 0.024, 0.045, 12, Color(1, 1, 1, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.name = "TeaGlass"
	var n := Node3D.new()
	n.add_child(mi)
	return n
