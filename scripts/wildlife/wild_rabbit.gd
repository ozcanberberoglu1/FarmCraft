class_name WildRabbit
extends Area3D
## A wild rabbit in the valley's meadows (Wildlife brings them and takes them away).
## It hops about nibbling the grass, sits up when the farmer comes near (closer when
## they walk, further when they run), then bolts away from them in a zig-zag, jinking
## hard when a hand is about to close on it. It runs faster than a sprinting farmer at
## first but tires (STAMINA), so a determined sprint catches up; E within CATCH_REACH
## (or running right into it) catches it: a "rabbit" item into the bag (at the feet
## when the bag is full), Events.game_caught(&"rabbit").
## It keeps to open wild ground: out of water, the farm's yard and plots, the town and
## buildings, and turns away from anything solid ahead (trees, rocks, fences, walls).
## No physics body: it follows the terrain; the Area3D is only for the E ray.

signal caught

enum State { GRAZE, SIT, WANDER, ALERT, FLEE, FREEZE }

const ITEM := &"rabbit"
## The farmer is noticed within this (m): walking, sprinting, standing still.
const NOTICE := Vector3(11.0, 17.0, 6.0)
## Flat out when fresh, and when spent (m/s); the farmer sprints at 7.
const RUN_SPEED := Vector2(5.2, 8.2)
## Seconds of flat-out running it has in it; it gets its wind back three times slower.
const STAMINA := 7.0
## A few lazy hops (about a body length each).
const WANDER_SPEED := 0.75
## It stops running once the farmer is this far behind (m).
const SAFE := 26.0
## E catches it this close (m, flat); running into it this close does too.
const CATCH_REACH := 1.7
const TACKLE := 0.8
## A sharp sideways jink when the farmer is this close (m), at most this often (s).
const JINK_RANGE := 2.6
const JINK_COOLDOWN := 1.4
## Beyond this (m) the pose is updated less often.
const FAR_ANIM := 40.0

var state := State.GRAZE
var rig: RabbitRig
var speed := 0.0
## 1 fresh .. 0 spent.
var stamina := 1.0
var heading := 0.0

var _timer := 2.0
var _sense := 0.0
var _zig := 1.0
var _zig_angle := 0.5
var _zig_timer := 0.0
var _jink := 0.0
var _probe := 0.0
var _blocked := false
var _rng := RandomNumberGenerator.new()
var _caught := false
var _run_sfx := 0.0
var _anim_wait := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(&"interactable")
	add_to_group(&"wild_rabbits")
	_rng.randomize()
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	# Generous, so a quick aim at a running rabbit still finds it.
	shape.radius = 0.22
	shape.height = 0.7
	cs.shape = shape
	cs.rotation.x = PI * 0.5
	cs.position = Vector3(0, 0.16, 0.0)
	add_child(cs)
	rig = RabbitRig.create()
	add_child(rig)
	heading = rotation.y
	_timer = _rng.randf_range(1.0, 4.0)
	state = State.GRAZE if _rng.randf() < 0.6 else State.SIT
	# Placed from _physics_process on the terrain: drawn between ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON


func interact_title() -> String:
	return tr("RABBIT_TITLE")


func interact_prompt(player: Node) -> String:
	return tr("ACTION_CATCH") if can_catch(player) else ""


func hint_prompt() -> String:
	var player := Game.player as Node3D
	return tr("RABBIT_HINT") if player and not can_catch(player) else ""


func interact(player: Node) -> void:
	if can_catch(player):
		catch(player)


## Close enough to grab.
func can_catch(player: Node) -> bool:
	if _caught or not (player is Node3D):
		return false
	return _flat_distance((player as Node3D).global_position) <= CATCH_REACH


## Into the bag (at the farmer's feet when it is full), with a scuffle and a squeak.
func catch(player: Node = null) -> void:
	if _caught:
		return
	_caught = true
	collision_layer = 0
	var at := global_position + Vector3(0, 0.15, 0)
	WildSfx.play("catch", at, -2.0)
	Audio.play("grass", at, -12.0, 0.1, &"Effects", 3.0, 1.3)
	Fx.clippings(at, Vector3.UP, Color(0.4, 0.5, 0.24))
	var left := PlayerState.give(ITEM, 1)
	if left > 0:
		Pickup.spawn(ItemStack.create(ITEM, 1), at, Vector3(0, 1.5, 0))
	elif player is Player:
		(player as Player).show_take(ITEM, rig.global_transform)
		(player as Player).kick_view(Vector4(-1.2, 0.0, 0.6, -0.01))
	if left == 0:
		Events.item_picked_up.emit(ITEM, 1)
	Events.game_caught.emit(ITEM)
	caught.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if _caught:
		return
	var player := Game.player as Player
	_sense -= delta
	if _sense <= 0.0:
		_sense = 0.15
		_look_around(player)
	_timer -= delta
	_jink = maxf(_jink - delta, 0.0)
	var want := 0.0
	match state:
		State.GRAZE, State.SIT:
			stamina = minf(stamina + delta / (STAMINA * 3.0), 1.0)
			if _timer <= 0.0:
				_next_idle()
		State.FREEZE:
			stamina = minf(stamina + delta / (STAMINA * 2.0), 1.0)
			if _timer <= 0.0 or stamina > 0.6:
				state = State.SIT
				_timer = _rng.randf_range(2.0, 5.0)
		State.WANDER:
			want = WANDER_SPEED
			if _timer <= 0.0:
				_next_idle()
		State.ALERT:
			if _timer <= 0.0:
				# Off if the farmer is still coming, else it settles down again.
				if player and _flat_distance(player.global_position) < _notice(player):
					_bolt()
				else:
					state = State.SIT
					_timer = _rng.randf_range(2.0, 5.0)
		State.FLEE:
			want = _flee(delta, player)
	speed = move_toward(speed, want, delta * (14.0 if want > speed else 9.0))
	if speed > 0.05:
		_move(delta)
	elif state == State.ALERT and player:
		# Turned side-on to watch the farmer with one eye.
		var to := player.global_position - global_position
		_turn_to(atan2(-to.x, -to.z) + PI * 0.5, delta, 4.0)
	var mode := RabbitRig.Mode.SIT
	match state:
		State.GRAZE:
			mode = RabbitRig.Mode.GRAZE
		State.ALERT:
			mode = RabbitRig.Mode.ALERT
		State.WANDER, State.FLEE:
			mode = RabbitRig.Mode.HOP if speed > 0.2 else RabbitRig.Mode.SIT
	# Far off, the pose is worked out ten times a second (cheap with a few about).
	_anim_wait += delta
	if _anim_wait >= 0.1 or player == null or _flat_distance(player.global_position) < FAR_ANIM:
		rig.animate(_anim_wait, speed, mode)
		_anim_wait = 0.0
	# Running into it (a sprinting farmer right on top of it) catches it too.
	if player and state == State.FLEE and _flat_distance(player.global_position) < TACKLE \
			and Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed + 0.5:
		catch(player)


## What it makes of the farmer: noticed within NOTICE (by their pace), too close to
## wait for (half that) means running at once.
func _look_around(player: Player) -> void:
	if player == null or not is_instance_valid(player):
		return
	var d := _flat_distance(player.global_position)
	var notice := _notice(player)
	match state:
		State.GRAZE, State.SIT, State.WANDER:
			if d < notice * 0.5:
				_bolt()
			elif d < notice:
				state = State.ALERT
				_timer = _rng.randf_range(0.35, 0.8)
				WildSfx.play("thump", global_position, -6.0)
		State.FREEZE:
			if d < notice * 0.6:
				_bolt()
		State.FLEE:
			if d > SAFE:
				state = State.ALERT if stamina > 0.3 else State.FREEZE
				_timer = _rng.randf_range(1.5, 3.0)


## How near the farmer may come unnoticed: by their pace (on horseback or driving, far).
func _notice(player: Player) -> float:
	if player.driving != null or player.riding != null:
		return NOTICE.y
	var pace := Vector2(player.velocity.x, player.velocity.z).length()
	return NOTICE.z if pace < 0.3 else (NOTICE.y if pace > player.walk_speed + 0.5 else NOTICE.x)


func _bolt() -> void:
	state = State.FLEE
	_zig_timer = 0.0
	WildSfx.play("thump", global_position, -4.0)


## Away from the farmer, zig-zagging, jinking when they are about to grab it. Returns
## the speed it runs at.
func _flee(delta: float, player: Player) -> float:
	stamina = maxf(stamina - delta / STAMINA, 0.0)
	var away := heading
	var d := 99.0
	if player:
		var from := global_position - player.global_position
		away = atan2(-from.x, -from.z)
		d = _flat_distance(player.global_position)
	_zig_timer -= delta
	if _zig_timer <= 0.0:
		# The next leg of the zig-zag, to the other side.
		_zig_timer = _rng.randf_range(0.45, 1.0)
		_zig = -_zig
		_zig_angle = _zig * _rng.randf_range(0.4, 0.85)
	if d < JINK_RANGE and _jink <= 0.0 and stamina > 0.05:
		# A hard turn to one side: the hand closes on empty air.
		_jink = JINK_COOLDOWN
		_zig = -_zig
		_zig_angle = _zig * _rng.randf_range(1.2, 1.7)
		heading = away + _zig_angle
		_zig_timer = 0.5
	var target := away + _zig_angle
	_turn_to(target, delta, 9.0)
	_run_sfx -= delta
	if _run_sfx <= 0.0:
		_run_sfx = 0.28
		Audio.play("grass", global_position, -24.0, 0.2, &"Effects", 2.5, 1.6)
	return lerpf(RUN_SPEED.x, RUN_SPEED.y, sqrt(stamina))


func _next_idle() -> void:
	var r := _rng.randf()
	if r < 0.45:
		state = State.GRAZE
		_timer = _rng.randf_range(3.0, 8.0)
	elif r < 0.7:
		state = State.SIT
		_timer = _rng.randf_range(2.0, 5.0)
	else:
		state = State.WANDER
		heading += _rng.randf_range(-1.4, 1.4)
		_timer = _rng.randf_range(1.5, 4.0)


## Hops along its heading, keeping to open ground and steering round anything ahead.
func _move(delta: float) -> void:
	_probe -= delta
	if _probe <= 0.0:
		_probe = 0.08 if state == State.FLEE else 0.2
		_blocked = not _clear(heading, maxf(speed * 0.35, 0.8))
		if _blocked:
			heading = _free_heading(heading)
	var step := Vector3(-sin(heading), 0.0, -cos(heading)) * speed * delta
	var next := global_position + step
	if not ground_ok(next.x, next.z):
		heading = _free_heading(heading)
		return
	next.y = TerrainData.height(next.x, next.z)
	global_position = next
	rotation.y = lerp_angle(rotation.y, heading, 1.0 - exp(-delta * 14.0))


func _turn_to(angle: float, delta: float, rate: float) -> void:
	heading = lerp_angle(heading, angle, 1.0 - exp(-delta * rate))
	if speed <= 0.05:
		rotation.y = lerp_angle(rotation.y, heading, 1.0 - exp(-delta * rate))


## The nearest heading to `h` that is clear, turning away from the farmer first.
func _free_heading(h: float) -> float:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var player := Game.player as Node3D
	if player:
		var to := player.global_position - global_position
		var right := Vector3(cos(h), 0.0, -sin(h))
		side = 1.0 if right.dot(to) > 0.0 else -1.0
	for step in [0.5, 1.0, 1.5, 2.1, 2.7]:
		for s in [side, -side]:
			var c: float = h + s * step
			if _clear(c, 1.2):
				return c
	return h + PI


## Open ground `reach` m along `h` and nothing solid in the way.
func _clear(h: float, reach: float) -> bool:
	var dir := Vector3(-sin(h), 0.0, -cos(h))
	var end := global_position + dir * reach
	if not ground_ok(end.x, end.z):
		return false
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, Vector3(end.x, TerrainData.height(end.x, end.z) + 0.2, end.z), 1)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	# The terrain itself is not in the way (slopes are checked by ground_ok).
	return hit.is_empty() or (hit["collider"] as Node).get_parent() is Terrain


## Ground a rabbit may run on: in the valley, on land (not in the pond or wet banks),
## not too steep, out of the farm's yard and plots, the town and the buildings.
static func ground_ok(x: float, z: float) -> bool:
	if Vector2(x, z).length() > WorldLayout.VALLEY_RADIUS - 1.5:
		return false
	if TerrainData.height(x, z) < WorldLayout.WATER_LEVEL + 0.35 \
			or WorldLayout.distance_to_pond(x, z) < WorldLayout.POND_RADIUS + 1.0:
		return false
	if TerrainData.normal_at(x, z).y < 0.8:
		return false
	# The farm's yard, buildings and pens.
	if Rect2(-32, -34, 102, 72).has_point(Vector2(x, z)) or WorldLayout.is_cleared(x, z, 1.0):
		return false
	if Placer.reserved(x, z) or Placer.in_building_plot(Vector3(x, 0.0, z)):
		return false
	return true


func _flat_distance(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()
