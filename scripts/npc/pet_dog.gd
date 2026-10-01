class_name PetDog
extends Dog
## The farmer's own dog in the world (what it knows, its age and name: Pet). Karamel's
## body (Dog, DogRig) at the size Pet.size() gives (a pup's: smaller, its head and paws
## drawn bigger; grown, Karamel's), the gait worked out at the model's size so its paws
## never slide, and a day of its own (`task`):
##   &"follow"  near the farmer on the farm, loosely: it trots up (runs, far behind) when
##              he walks off and stops FOLLOW_NEAR short, then potters about near him
##              (Dog's roaming: sniffing, standing looking at him, sitting, lying down);
##              outside the farmhouse door while he is in the house. Left far behind out
##              of sight it catches up (CATCH_UP).
##   &"home"    by its bed at the farmhouse while he is away (driving, off the farm); when
##              he comes back on foot it runs to greet him, barking.
##   &"bed"     asleep on its bed at night (NIGHT_FROM .. NIGHT_TO); grown (Pet.guards)
##              it keeps watch by the animals instead:
##   &"guard"   lying near the animals with its head up; wolves within WOLF_BARK: up,
##              facing the nearest, barking; one closer than WOLF_BACK_OFF it backs away
##              from (the wolves never go for it).
##   &"come"    whistled for (Pet.whistle): running to him, then greeting him (Dog's
##              &"greet"); a pup not listening only looks up.
##   &"sit"     told to sit, once it has learnt to: sitting looking up at him a while.
##   &"petted"  a pat (E): it sits and leans into the hand (Dog's &"petted").
##   &"fetch"   after a thrown ball (a Pickup), picking it up in its mouth; then
##              &"carry": bringing it back and dropping it at his feet (the ball comes
##              into his bag as any pickup does), once it has learnt to, or else
##              &"play": trotting about with it, dropping it, pouncing on it again, and
##              in the end leaving it lying.
## Obstacles (walls, fences, the house) are felt for ahead (_steer) and never walked
## through. Cheap: a ground ray a tick, a ray ahead while it moves, a few probes five
## times a second while it heads somewhere, its choices four times a second.

const PET_GROUP := &"pet_dog"
## Night: on its bed (or on guard) from NIGHT_FROM to NIGHT_TO (hours).
const NIGHT_FROM := 21.5
const NIGHT_TO := 6.0
## Running at the model's size (m/s; a pup runs as much slower as it is smaller).
const RUN := 3.3
## Following: it goes when he is further than FOLLOW_FAR, stops FOLLOW_NEAR off; left
## further than CATCH_UP behind, out of sight, it catches up.
const FOLLOW_NEAR := 2.2
const FOLLOW_FAR := 5.5
const CATCH_UP := 28.0
## Whistled: it stops this far from him, and greets him this long.
const COME_GAP := 1.1
const GREET_HOLD := 3.0
## Seconds it stays sat when told, and leaning into a pat.
const SIT_HOLD := 25.0
const PET_HOLD := 2.5
## Guarding: wolves this near are barked at, this near backed away from (m); how far from
## the animals toward the house it keeps watch.
const WOLF_BARK := 30.0
const WOLF_BACK_OFF := 3.5
const GUARD_OFF := 7.0
## Seconds between looks ahead for obstacles while heading somewhere.
const PROBE := 0.2

var task: StringName = &"follow"
## Its size against Karamel's (Pet.size()).
var size := 1.0
## The ball it is after (a Pickup lying or rolling), and whether one is in its mouth.
var ball: Pickup
var holding_ball := false
## Counters for tests: balls brought back, balls played with, whistles answered.
var fetched := 0
var played := 0
var came := 0

var _task_t := 0.0
var _going := false
var _settled := false
var _think := 0.0
var _probe_t := 0.0
var _detour := 0.0
var _detour_side := 1.0
var _stuck_t := 0.0
## What it goes back to after a pat or a sit.
var _after: StringName = &"follow"
## Seconds it looks up at the farmer (a whistle, a command it doesn't know yet).
var _look_up := 0.0
var _play_left := 0
## The ball was just thrown (not tossed about in play): its first pick-up counts.
var _fresh_throw := false
var _play_goal := Vector3.INF
var _mouth_t := 0.0
var _post := Vector3.INF
var _wolf: Node3D
var _grow_t := 0.0
var _ball_mesh: MeshInstance3D


func _init() -> void:
	name = "PetDog"


func _ready() -> void:
	super()
	remove_from_group(Dog.GROUP)
	add_to_group(PET_GROUP)
	add_to_group(&"interactable")
	home_area = Rect2()
	_ball_mesh = MeshInstance3D.new()
	_ball_mesh.name = "Ball"
	_ball_mesh.mesh = ItemModels.mesh(Pet.BALL)
	_ball_mesh.top_level = true
	_ball_mesh.visible = false
	_ball_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_ball_mesh)
	grow()


## Its size and a pup's proportions for its age now (Pet.size, Pet.growth).
func grow() -> void:
	size = Pet.size()
	var young := 1.0 - Pet.growth()
	gait_scale = size
	if rig:
		rig.scale = Vector3.ONE * size
		rig.head_scale = lerpf(1.0, Pet.PUPPY_HEAD, young)
		rig.paw_scale = lerpf(1.0, Pet.PUPPY_PAWS, young)
	var cap := _shape.shape as CapsuleShape3D if _shape else null
	if cap:
		cap.radius = 0.15 * size
		cap.height = 0.92 * size
	if _on_screen:
		_on_screen.aabb = AABB(Vector3(-0.4, 0.0, -0.8) * size, Vector3(0.8, 0.9, 1.6) * size)


## The farm's valley (where it follows him; off it, he is away).
static func on_farm(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < WorldLayout.VALLEY_RADIUS - 4.0


# --- The farmer's commands (Pet) -------------------------------------------------------------

## A whistle: heeded, it comes running; not (a pup with its nose in something), it only
## looks up and goes on.
func whistled(heeded: bool) -> void:
	_look_up = 1.6
	if not heeded or task == &"carry":
		return
	if holding_ball:
		_drop_ball(Vector3.ZERO)
	_set_task(&"come")
	_barks_left = 1
	_bark_wait = 0.3


## "Sit!" (learnt): it sits where it is, looking up at him.
func sit_down() -> void:
	if task != &"sit" and task != &"petted":
		_after = task
	_set_task(&"sit")
	_start_act(Act.SIT)


## "Sit!" not yet learnt: it looks up at him wagging, not sure what he wants.
func puzzled() -> void:
	_look_up = 2.5
	if randf() < 0.5:
		bark()


## A pat: it sits and leans into the hand a moment.
func petted_by(petter: Node3D) -> void:
	if holding_ball:
		# It lets the ball drop to be petted.
		_drop_ball(Vector3.ZERO)
		ball = null
	if task != &"petted":
		_after = task
	_set_task(&"petted")
	set_mode(&"petted", petter.global_position if petter else Vector3.INF)


## Turns it at once to face `p` (set down beside the farmer).
func look_toward(p: Vector3) -> void:
	var to := _flat(p - global_position)
	if to.length() > 0.05:
		_yaw = atan2(-to.x, -to.z)
		rotation.y = _yaw


## A ball thrown: it goes after it (not while he is away, nor with wolves to watch).
func chase(b: Pickup) -> void:
	if b == null or task == &"home" or (task == &"guard" and _wolf != null):
		return
	if holding_ball:
		return
	ball = b
	_play_left = randi_range(2, 3)
	_fresh_throw = true
	_set_task(&"fetch")


# --- The player's interaction ------------------------------------------------------------------

func interact_title() -> String:
	return Pet.dog_name


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_PET")


func interact(_player: Node) -> void:
	Pet.pat()


func info_prompt() -> String:
	return tr("ACTION_DOG_SIT")


func info_interact(_player: Node) -> void:
	Pet.command_sit()


# --- Frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if holding_ball:
		_ball_mesh.global_position = _mouth_point()
		_ball_mesh.scale = Vector3.ONE * clampf(size * 1.3, 0.8, 1.0)


func _physics_process(delta: float) -> void:
	_mode_t += delta
	_task_t += delta
	_look_up -= delta
	_bark_cd = maxf(_bark_cd - delta, 0.0)
	_sound_t -= delta
	_notice_player(delta)
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		_decide()
	match task:
		&"follow":
			_follow(delta)
		&"home":
			_stay_home(delta)
		&"bed", &"guard":
			_night_watch(delta)
		&"come":
			_come(delta)
		&"sit":
			_want_speed = 0.0
			_act = Act.SIT
			_turn_to(_player_pos(), delta * 0.5)
		&"petted":
			target = _player_pos()
			_petted(delta)
			if _task_t > PET_HOLD:
				_set_task(_after if _after in [&"follow", &"home", &"bed", &"guard"] else &"follow")
		&"fetch":
			_fetch(delta)
		&"carry":
			_carry(delta)
		&"play":
			_play(delta)
	_move_pet(delta)
	_place_collider()


## What it should be doing, four times a second: the day's routine (with him on the farm,
## at home while he is away, its bed or its watch at night) and its growing.
func _decide() -> void:
	_grow_t -= 0.25
	if _grow_t <= 0.0:
		_grow_t = 5.0
		if absf(Pet.size() - size) > 0.002:
			grow()
	var away := _away()
	var night := _night_now()
	_wolf = _nearest_wolf() if task == &"guard" else null
	match task:
		&"follow":
			if away:
				_set_task(&"home")
			elif night:
				_set_task(_night_task())
		&"home":
			if night:
				_set_task(_night_task())
			elif not away and _flat(_player_pos() - global_position).length() < 35.0:
				# He is back: a run and a bark or two to greet him.
				_set_task(&"come")
				_barks_left = 2
				_bark_wait = 0.3
		&"bed", &"guard":
			if not night:
				_set_task(&"home" if away else &"follow")
			elif task != _night_task():
				_set_task(_night_task())
		&"sit":
			if away or _task_t > SIT_HOLD or _flat(_player_pos() - global_position).length() > 12.0:
				_set_task(&"follow")
		&"come":
			if away:
				_set_task(&"home")
		&"fetch", &"carry", &"play":
			if away:
				if holding_ball:
					_drop_ball(Vector3.ZERO)
				ball = null
				_set_task(&"home")


func _set_task(t: StringName) -> void:
	task = t
	_task_t = 0.0
	_going = false
	_settled = false
	_stuck_t = 0.0
	_mouth_t = 0.0
	_play_goal = Vector3.INF
	home_area = _home_area() if t == &"home" else Rect2()
	if mode != &"roam":
		set_mode(&"roam")
	else:
		_start_act(Act.STAND)
	if t == &"guard":
		_post = _guard_post()


func _night_now() -> bool:
	var h := GameClock.get_hour_float()
	return h >= NIGHT_FROM or h < NIGHT_TO


func _night_task() -> StringName:
	return &"guard" if Pet.guards() else &"bed"


## The farmer away: driving, or off the farm's valley (gone to town).
func _away() -> bool:
	var p := Game.player as Player
	if p == null or not is_instance_valid(p):
		return true
	return p.driving != null or not on_farm(p.global_position)


# --- The day ---------------------------------------------------------------------------------

## Loosely after him: up to FOLLOW_NEAR off when he is further than FOLLOW_FAR (by the
## door while he is in the house), then pottering about.
func _follow(delta: float) -> void:
	var p := _player_pos()
	if not p.is_finite():
		return
	var goal := p
	var near := FOLLOW_NEAR
	var far := FOLLOW_FAR
	if WolfRaids.in_house(p):
		goal = _door_point()
		near = 0.5
		far = 1.6
	var d := _flat(goal - global_position).length()
	if not _going and d > far:
		_going = true
		_start_act(Act.WANDER)
	if _going:
		if d <= near + 0.25:
			_going = false
			_start_act(Act.STAND)
			return
		var spot := goal + _flat(global_position - goal).normalized() * near
		var pace := RUN if d > 9.0 else (TROT if d > 4.5 else WALK)
		_steer(spot, pace * size, delta)
		if d > CATCH_UP:
			_catch_up(goal)
		return
	_roam(delta)


## Just outside the farmhouse's door.
func _door_point() -> Vector3:
	var x := WorldLayout.HOUSE_DOOR_X + 1.0
	var z := WorldLayout.HOUSE_FRONT_Z + 2.4
	return Vector3(x, TerrainData.height(x, z), z)


## Out of sight far behind: round the corner after him, a few metres back.
func _catch_up(goal: Vector3) -> void:
	if _on_screen.is_on_screen():
		return
	var back := _flat(global_position - goal).normalized()
	var at := goal + back * 8.0
	at.y = TerrainData.height(at.x, at.z)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.is_position_in_frustum(at + Vector3(0, 0.3, 0)):
		return
	if absf(_ground_at(at.x, at.z) - at.y) > 0.3:
		return
	_warp(at)


func _warp(at: Vector3) -> void:
	global_position = at
	_floor_y = at.y
	_speed = 0.0
	reset_physics_interpolation()


## Its patch round the bed while the farmer is away (x, z rect: in front of the house).
func _home_area() -> Rect2:
	var bed := Pet.bed_point()
	return Rect2(bed.x - 1.4, bed.z - 0.8, 4.2, 4.0)


## By its bed while he is away (back there first), roaming its patch.
func _stay_home(delta: float) -> void:
	var bed := Pet.bed_point()
	if not _home_area().grow(-0.5).has_point(Vector2(global_position.x, global_position.z)):
		var d := _flat(bed - global_position).length()
		var cam := _camera_pos()
		if d > 30.0 and not _on_screen.is_on_screen() and cam.distance_to(bed) > 30.0:
			_warp(bed + Vector3(1.4, 0.0, 1.2))
			return
		_steer(bed, (TROT if d > 8.0 else WALK) * size, delta)
		if _stuck_t > 6.0 and not _on_screen.is_on_screen():
			_warp(bed + Vector3(1.4, 0.0, 1.2))
		return
	_roam(delta)


## Night: to its bed and asleep on it, or (grown) on watch near the animals.
func _night_watch(delta: float) -> void:
	var spot := Pet.bed_point() if task == &"bed" else _post
	if task == &"guard" and _wolf != null and is_instance_valid(_wolf):
		var away := _flat(global_position - _wolf.global_position)
		_act = Act.STAND
		if away.length() < WOLF_BACK_OFF:
			# Too close: it gives ground, still barking.
			_steer(global_position + away.normalized() * 3.0, TROT * size, delta)
		else:
			_want_speed = 0.0
			_turn_to(_wolf.global_position, delta)
		if _sound_t <= 0.0:
			_sound_t = randf_range(0.7, 1.4)
			bark()
		return
	if not _settled:
		var d := _flat(spot - global_position).length()
		if d > 0.3 and _stuck_t < 5.0 and _task_t < 120.0:
			_act = Act.STAND
			_steer(spot, (TROT if d > 6.0 else WALK) * size, delta)
			if d > 30.0 and not _on_screen.is_on_screen() and _camera_pos().distance_to(spot) > 30.0:
				_warp(spot)
			return
		_settled = true
		_start_act(Act.LIE)
	_want_speed = 0.0
	_act = Act.LIE
	_act_t += delta


## Where it keeps watch: from the animals GUARD_OFF toward the farmhouse.
func _guard_post() -> Vector3:
	var a := WolfRaids.animals_area()
	var house := _door_point()
	var dir := _flat(house - a)
	var p := a + dir.normalized() * minf(GUARD_OFF, dir.length()) if dir.length() > 0.1 else a
	return Vector3(p.x, TerrainData.height(p.x, p.z), p.z)


func _nearest_wolf() -> Node3D:
	var best: Node3D = null
	var best_d := WOLF_BARK
	for w in WolfRaids.wolves():
		var d := _flat(w.global_position - global_position).length()
		if d < best_d:
			best = w
			best_d = d
	return best


## Whistled: running to him, then greeting him.
func _come(delta: float) -> void:
	var p := _player_pos()
	if not p.is_finite():
		_set_task(&"follow")
		return
	if mode == &"greet":
		target = p
		_greet(delta)
		if _mode_t > GREET_HOLD:
			_set_task(&"follow")
		return
	var d := _flat(p - global_position).length()
	if d <= COME_GAP + 0.3 or _task_t > 40.0:
		came += 1
		set_mode(&"greet", p)
		return
	var spot := p + _flat(global_position - p).normalized() * COME_GAP
	_steer(spot, (RUN if d > 3.0 else TROT) * size, delta)
	if d > CATCH_UP:
		_catch_up(p)


# --- The ball --------------------------------------------------------------------------------

## After the ball (rolling or lying): its nose to it, a moment head down, and it has it.
func _fetch(delta: float) -> void:
	if ball == null or not is_instance_valid(ball) or ball.is_queued_for_deletion() or ball._flying:
		ball = null
		_set_task(&"follow")
		return
	var bp := ball.global_position
	var reach := _mouth_reach()
	var to := _flat(bp - global_position)
	var d := to.length()
	if d > reach + 0.12 or ball.linear_velocity.length() > 1.2:
		_mouth_t = 0.0
		var spot := bp - to.normalized() * reach
		_steer(spot, (RUN if d > 2.5 else TROT * 0.7) * size, delta)
		if _task_t > 40.0:
			ball = null
			_set_task(&"follow")
		return
	_want_speed = 0.0
	_turn_to(bp, delta * 2.0)
	if _facing(bp, 0.4):
		_mouth_t += delta
		if _mouth_t > 0.35:
			_pick_up()


func _pick_up() -> void:
	if ball and is_instance_valid(ball):
		ball.queue_free()
	ball = null
	holding_ball = true
	_ball_mesh.visible = true
	Pet.ball_caught()
	if Pet.knows(&"fetch"):
		_set_task(&"carry")
	else:
		if _fresh_throw:
			played += 1
		_set_task(&"play")
	_fresh_throw = false


## The ball back to him: up to his feet, a moment, and it lets it drop there.
func _carry(delta: float) -> void:
	var p := _player_pos()
	if not p.is_finite():
		_drop_ball(Vector3.ZERO)
		_set_task(&"follow")
		return
	var d := _flat(p - global_position).length()
	if d > 1.0 + 0.25 and _task_t < 40.0:
		_mouth_t = 0.0
		var spot := p + _flat(global_position - p).normalized() * 1.0
		_steer(spot, (RUN if d > 4.0 else TROT * 0.7) * size, delta)
		if d > CATCH_UP:
			_catch_up(p)
		return
	_want_speed = 0.0
	_turn_to(p, delta * 1.5)
	if _facing(p, 0.35) or _task_t > 40.0:
		_mouth_t += delta
		if _mouth_t > 0.4:
			var toward := _flat(p - global_position).normalized()
			_drop_ball(toward * 0.6 + Vector3.UP * 0.4)
			ball = null
			fetched += 1
			_set_task(&"follow")
			_look_up = 2.5


## Not yet taught to bring it: trotting about with the ball, dropping it with a toss of the
## head and pouncing on it again, a few times; then it leaves it lying.
func _play(delta: float) -> void:
	if not _play_goal.is_finite():
		_play_goal = _pick_spot(2.2)
	var d := _flat(_play_goal - global_position).length()
	if d > 0.3 and _task_t < 2.5:
		_steer(_play_goal, TROT * 0.8 * size, delta)
		return
	_want_speed = 0.0
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var tossed := _drop_ball(fwd.rotated(Vector3.UP, randf_range(-0.8, 0.8)) * randf_range(0.8, 1.6) + Vector3.UP * 1.1)
	_play_left -= 1
	if _play_left > 0 and tossed:
		ball = tossed
		var keep := _play_left
		_set_task(&"fetch")
		_play_left = keep
	else:
		ball = null
		_set_task(&"follow")


## The ball out of its mouth (with `vel`): lying in the world again, a pickup. Returns it.
func _drop_ball(vel: Vector3) -> Pickup:
	if not holding_ball:
		return null
	holding_ball = false
	_ball_mesh.visible = false
	var stack := ItemStack.create(Pet.BALL, 1)
	if stack == null or Game.world == null:
		return null
	var p := Pickup.spawn(stack, _mouth_point())
	Pet.make_bouncy(p)
	p.linear_velocity = vel
	return p


## Where the ball is held: in its mouth, just under and behind the nose.
func _mouth_point() -> Vector3:
	var nose := rig.nose_world() if rig and rig.skeleton else global_position + Vector3(0, 0.5, 0) * size
	return nose + global_basis.z * 0.025 * size - Vector3.UP * 0.05 * size


## How far ahead of its middle the ball is when its nose is on it (m).
func _mouth_reach() -> float:
	return 0.6 * size


# --- Moving --------------------------------------------------------------------------------

## Heads for `goal` at `speed`, feeling ahead for walls and fences (every PROBE seconds)
## and turning aside round them.
func _steer(goal: Vector3, speed: float, delta: float) -> void:
	var to := _flat(goal - global_position)
	if to.length() < 0.03:
		_want_speed = 0.0
		return
	var dir := to.normalized()
	_probe_t -= delta
	if _probe_t <= 0.0:
		_probe_t = PROBE
		var reach := minf(to.length(), 0.9 * size + 0.5)
		if _clear(dir, reach):
			_detour = 0.0
		else:
			var found := false
			for a: float in [0.55, 1.1, 1.65, 2.2]:
				for sgn: float in [_detour_side, -_detour_side]:
					if _clear(dir.rotated(Vector3.UP, a * sgn), reach):
						_detour = a * sgn
						_detour_side = sgn
						found = true
						break
				if found:
					break
			if not found:
				_detour = PI * 0.5 * _detour_side
	if _stuck_t > 2.0:
		# Stuck against something: the other way round it.
		_detour_side = -_detour_side
		_stuck_t = 0.0
		_probe_t = 0.0
	var aim := goal if _detour == 0.0 else global_position + dir.rotated(Vector3.UP, _detour) * maxf(to.length(), 0.6)
	_head_to(aim, speed, delta)


## Nothing solid (walls, fences, the house: the world layer) within `reach` along `dir`,
## at the height of its chest, following the ground ahead.
func _clear(dir: Vector3, reach: float) -> bool:
	var h := 0.28 * size + 0.08
	var a := global_position + Vector3(0, h, 0)
	var b := global_position + dir * reach
	b.y = maxf(TerrainData.height(b.x, b.z), global_position.y - 0.3) + h
	return not _ray(a, b)


## Moves on at its speed (it gets up first) where nothing blocks it, on the ground.
func _move_pet(delta: float) -> void:
	var up := rig.sit_amount() < 0.05 and rig.lie_amount() < 0.05
	_speed = move_toward(_speed, _want_speed if up else 0.0, ACCEL * delta)
	rotation.y = _yaw
	if _speed > 0.001:
		var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var step := fwd * _speed * delta
		if _clear(fwd, 0.3 * size + 0.12 + step.length()):
			global_position += step
			_stuck_t = maxf(_stuck_t - delta, 0.0)
		else:
			_speed = 0.0
			_stuck_t += delta
			_probe_t = 0.0
	elif _want_speed > 0.05 and up:
		_stuck_t += delta * 0.5
	var h := _ground_at(global_position.x, global_position.z)
	_floor_y = h if absf(h - _floor_y) > 0.5 else lerpf(_floor_y, h, 1.0 - exp(-delta * 12.0))
	global_position.y = _floor_y


## The collider along its body at its size.
func _place_collider() -> void:
	if _shape == null or rig == null:
		return
	var s := rig.sit_amount() * (1.0 - rig.lie_amount())
	var l := rig.lie_amount()
	var pitch := lerpf(PI * 0.5, PI * 0.5 - 0.65, s)
	var y := lerpf(lerpf(0.4, 0.34, s), 0.2, l) * size
	_shape.transform = Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0, y, lerpf(0.02, 0.1, s) * size))


# --- How it looks ----------------------------------------------------------------------------

func _mood() -> void:
	super()
	var p := _player_pos()
	match task:
		&"follow", &"home":
			if _going or _speed > 0.3:
				rig.pose = DogRig.Pose.STAND
				rig.nose_down = 0.0
				rig.head_rest = false
				rig.wag = maxf(rig.wag, 0.6)
		&"bed":
			if _settled:
				rig.pose = DogRig.Pose.LIE
				rig.head_rest = _act_t > 3.0
				rig.wag = 0.0 if rig.head_rest else 0.3
				rig.look_at_point = Vector3.INF
			else:
				rig.pose = DogRig.Pose.STAND
		&"guard":
			rig.head_rest = false
			if _wolf != null and is_instance_valid(_wolf):
				rig.pose = DogRig.Pose.STAND
				rig.look_at_point = _wolf.global_position + Vector3(0, 0.5, 0)
				rig.wag = 0.0
				rig.panting = false
			elif _settled:
				rig.pose = DogRig.Pose.LIE
				rig.wag = 0.15
			else:
				rig.pose = DogRig.Pose.STAND
		&"come", &"carry":
			if mode != &"greet":
				rig.pose = DogRig.Pose.STAND
				rig.nose_down = 0.0
				rig.head_rest = false
				if p.is_finite():
					rig.look_at_point = p + Vector3(0, 1.2, 0)
				rig.wag = 1.0
				rig.panting = true
		&"sit":
			rig.pose = DogRig.Pose.SIT
			rig.head_rest = false
			if p.is_finite():
				rig.look_at_point = p + Vector3(0, 1.5, 0)
			rig.wag = 0.6
		&"fetch":
			rig.pose = DogRig.Pose.STAND
			rig.head_rest = false
			rig.nose_down = 0.9 if _mouth_t > 0.0 else 0.0
			if ball and is_instance_valid(ball) and _mouth_t <= 0.0:
				rig.look_at_point = ball.global_position
			rig.wag = 0.9
		&"play":
			rig.pose = DogRig.Pose.STAND
			rig.head_rest = false
			rig.nose_down = 0.15
			rig.wag = 1.0
	if _look_up > 0.0 and p.is_finite() and task != &"sit":
		rig.look_at_point = p + Vector3(0, 1.4, 0)
		rig.head_rest = false
		rig.wag = maxf(rig.wag, 0.7)
