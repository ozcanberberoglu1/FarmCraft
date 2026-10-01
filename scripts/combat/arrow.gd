class_name Arrow
extends Node3D
## An arrow loosed from the bow (Combat). It flies where the farmer aimed, dropping a
## little (GRAVITY) and turning to its flight, and stops at the first thing it strikes:
## - something hittable (a wolf, a rabbit): take_hit(damage, from, &"arrow"); the arrow
##   then breaks (BREAK_CHANCE) or stays stuck in the body and moves with it;
## - the ground, a tree or a wall (static things): it drives in point first and stays;
## - anything else (a vehicle, a door, a farm animal, a townsperson): it glances off and
##   lies on the ground at its foot;
## - the pond: a splash, and it is gone.
## A stuck or lying arrow is taken back into the bag with E or by walking over it
## (PICKUP_REACH), not while it is in a body that can still be hit. One left lying for
## LIFETIME_HOURS in-game hours goes away; only MAX_LYING are kept (the oldest goes) and
## none are saved.

enum State { FLYING, STUCK }

## Gravity on the arrow (m/s²): less than a stone's, so a shot drops only a little.
const GRAVITY := 4.9
## Seconds in the air before it is given up on (shot into the sky).
const MAX_FLIGHT := 6.0
## The world, interaction volumes (a rabbit's) and the animal layer stop it.
const HIT_MASK := 1 | 4 | 16
## Share of the arrows that strike a body and break.
const BREAK_CHANCE := 0.3
## Walking this close (m, flat) picks a lying arrow up, once it has lain PICKUP_ARM s.
const PICKUP_REACH := 0.9
const PICKUP_ARM := 0.8
const LIFETIME_HOURS := 48.0
const MAX_LYING := 40
## How deep the point drives in (m): soil, wood and stone, a body.
const DEPTH_SOIL := 0.13
## An arrow coming in flatter than this into the ground digs its point in and its shaft
## stands up to this angle (degrees from level), out of the grass where it can be seen.
const GROUND_ANGLE := 45.0
const DEPTH_WOOD := 0.07
const DEPTH_BODY := 0.15
const ITEM := &"arrow"

## Arrows stuck or lying in the world, oldest first.
static var _lying: Array[Arrow] = []

var state := State.FLYING
var velocity := Vector3.ZERO
var damage := 0.0
## Where the shot came from (the farmer): the `from` of take_hit.
var shooter_at := Vector3.ZERO
## The body it is stuck in (followed every frame), and its place on that body.
var host: Node3D = null
var _host_offset := Transform3D.IDENTITY
var _exclude: Array[RID] = []
## Where the point was at the last tick (the bow, at first: nothing close is flown past).
var _last_tip := Vector3.ZERO
var _age := 0.0
var _stuck_at := 0.0
var _taken := false
var _mi: MeshInstance3D
var _grab: StaticBody3D


## Looses an arrow from `from` at `vel` (m/s) that wounds `dmg`; `shooter` is never hit.
static func launch(from: Vector3, vel: Vector3, dmg: float, from_where: Vector3,
		shooter: CollisionObject3D = null) -> Arrow:
	var a := Arrow.new()
	a.velocity = vel
	a.damage = dmg
	a.shooter_at = from_where
	if shooter:
		a._exclude = [shooter.get_rid()]
	Game.world.add_child(a)
	a.global_transform = Transform3D(_facing(vel), from)
	a._last_tip = from
	a.reset_physics_interpolation()
	return a


## Every arrow stuck or lying in the world now.
static func lying() -> Array[Arrow]:
	var out: Array[Arrow] = []
	out.assign(_lying.filter(func(a: Arrow) -> bool: return is_instance_valid(a) and not a._taken))
	return out


func _ready() -> void:
	add_to_group(&"arrows")
	# Moved in physics ticks while it flies: drawn between ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_mi = MeshInstance3D.new()
	_mi.mesh = ArrowModels.single()
	_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Small clutter: kept out of the rain-blocker heightfield.
	_mi.layers = 2
	add_child(_mi)


func _exit_tree() -> void:
	_lying.erase(self)


func _physics_process(delta: float) -> void:
	_age += delta
	if state == State.FLYING:
		_fly(delta)
	elif not _taken:
		_check_walk_over()
		if GameClock.total_minutes - _stuck_at > LIFETIME_HOURS * 60.0:
			queue_free()


func _process(_delta: float) -> void:
	if state != State.STUCK or host == null:
		return
	if not is_instance_valid(host) or not host.is_inside_tree():
		_drop_from_host()
		return
	global_transform = host.get_global_transform_interpolated() * _host_offset


# --- Flight ------------------------------------------------------------------------------

func _fly(delta: float) -> void:
	var tip := _last_tip
	velocity.y -= GRAVITY * delta
	var step := velocity * delta
	var dir := velocity.normalized()
	var next_tip := global_position + dir * ArrowModels.LENGTH + step
	_last_tip = next_tip
	# The pond: it goes under with a splash.
	var water := WorldLayout.WATER_LEVEL
	if tip.y >= water and next_tip.y < water:
		var at := tip.lerp(next_tip, (tip.y - water) / maxf(tip.y - next_tip.y, 0.0001))
		if TerrainData.is_underwater(at.x, at.z, 0.0):
			Fx.drips(at)
			Audio.play("splash", at, -14.0, 0.1, &"Effects", 4.0, 1.6)
			queue_free()
			return
	var hit := _cast(tip, next_tip)
	if not hit.is_empty():
		_strike(hit, dir)
		return
	global_transform = Transform3D(_facing(velocity), global_position + step)
	if _age > MAX_FLIGHT:
		queue_free()


## The first thing between `from` and `to` that stops an arrow (interaction volumes of
## things that can't be hit and the pond's invisible shore are flown through).
func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var skip := _exclude.duplicate()
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, skip)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {}
		var c: Object = hit["collider"]
		if Combat.find_hittable(c) != null or not (c is CollisionObject3D):
			return hit
		var solid := c is CollisionObject3D and ((c as CollisionObject3D).collision_layer & (1 | 16)) != 0
		if solid and not (c is Area3D) and not ((c as Node).get_parent() is Pond):
			return hit
		skip.append((c as CollisionObject3D).get_rid())
	return {}


func _strike(hit: Dictionary, dir: Vector3) -> void:
	var at: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var c: Object = hit["collider"]
	var h := Combat.find_hittable(c)
	if h != null and (not h.has_method("can_be_hit") or h.can_be_hit()):
		h.take_hit(damage, shooter_at, Combat.ARROW)
		CombatSfx.play("arrow_flesh", at, -2.0, 0.08)
		Fx.blood_drops(at, -dir)
		if randf() < BREAK_CHANCE or not is_instance_valid(h) or not h.is_inside_tree():
			_break(at, dir)
			return
		_stick(at, dir, DEPTH_BODY, h)
		return
	if h != null:
		# A carcass: it goes in like into a body, without a wound.
		CombatSfx.play("arrow_flesh", at, -8.0, 0.08)
		_stick(at, dir, DEPTH_BODY, h)
		return
	if c is StaticBody3D and not (c is AnimatableBody3D):
		var ground := normal.y > 0.7
		CombatSfx.play("arrow_ground" if ground else "arrow_wood", at, -3.0, 0.08)
		if ground:
			Fx.dirt_clods(at, -dir, 0.25)
			var flat := Vector3(dir.x, 0.0, dir.z)
			var least := deg_to_rad(GROUND_ANGLE)
			if -dir.y < sin(least) and flat.length() > 0.01:
				dir = flat.normalized() * cos(least) + Vector3.DOWN * sin(least)
		else:
			Fx.wood_chips(at, normal)
		_stick(at, dir, DEPTH_SOIL if ground else DEPTH_WOOD, null)
		return
	# A vehicle, a door, a farm animal, a townsperson: it glances off and drops.
	CombatSfx.play("arrow_wood", at, -10.0, 0.1)
	if c is CollisionObject3D:
		_exclude.append((c as CollisionObject3D).get_rid())
	_lie_down(at)


## The shaft snaps in the body: a crack and a few splinters, nothing left to take.
func _break(at: Vector3, dir: Vector3) -> void:
	CombatSfx.play("arrow_break", at, -6.0, 0.08)
	Fx.wood_chips(at, -dir)
	queue_free()


## Driven in point first, `depth` deep along its flight, at `at` (in `into`, a body it
## then follows, when given).
func _stick(at: Vector3, dir: Vector3, depth: float, into: Node3D) -> void:
	var tip := at + dir * depth
	global_transform = Transform3D(_facing(dir), tip - dir * ArrowModels.LENGTH)
	_settle()
	if into != null:
		host = into
		_host_offset = into.global_transform.affine_inverse() * global_transform
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Lies flat on the ground below `at`, turned any way.
func _lie_down(at: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 6.0, 1, _exclude)
	var hit := space.intersect_ray(q)
	var ground: Vector3 = hit["position"] if not hit.is_empty() else TerrainData.point_on_ground(at.x, at.z)
	var yaw := randf() * TAU
	var flat := Vector3(sin(yaw), 0.0, cos(yaw))
	var b := Basis.looking_at(flat, Vector3.UP).rotated(flat.cross(Vector3.UP).normalized(), randf_range(-0.04, 0.04))
	global_transform = Transform3D(b, ground + Vector3.UP * 0.012 - flat * ArrowModels.LENGTH * 0.5)
	_settle()


## From flying to staying: interactable, counted among the lying arrows.
func _settle() -> void:
	state = State.STUCK
	velocity = Vector3.ZERO
	_age = 0.0
	_stuck_at = GameClock.total_minutes
	reset_physics_interpolation()
	add_to_group(&"interactable")
	# What E aims at: the shaft's middle, a little thicker than the shaft.
	_grab = StaticBody3D.new()
	_grab.name = "Grab"
	_grab.collision_layer = 4
	_grab.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.06
	cap.height = ArrowModels.LENGTH * 0.8
	cs.shape = cap
	cs.rotation.x = PI * 0.5
	cs.position = Vector3(0, 0, -ArrowModels.LENGTH * 0.4)
	_grab.add_child(cs)
	add_child(_grab)
	_lying.append(self)
	while _lying.size() > MAX_LYING:
		var old: Arrow = _lying.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## The body it was in is gone (a pelt taken, a wolf run off): it falls to the ground.
func _drop_from_host() -> void:
	host = null
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_lie_down(global_position + global_basis * Vector3(0, 0, -ArrowModels.LENGTH * 0.5))


# --- Taking it back --------------------------------------------------------------------

## Not while it is in something that can still be hit (a live wolf).
func can_take() -> bool:
	if _taken or state != State.STUCK:
		return false
	if host != null and is_instance_valid(host) and (not host.has_method("can_be_hit") or host.can_be_hit()):
		return false
	return true


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_TAKE_ARROW") if can_take() else ""


func interact(player: Node) -> void:
	take(player)


## Back into the bag (it flies into the hand when the arrows are in hand). With the bag
## full it stays: a word about it, unless `quiet` (walked over, like any pickup).
func take(player: Node = null, quiet := false) -> bool:
	if not can_take():
		return false
	if PlayerState.inventory.add_item(ITEM, 1) > 0:
		if not quiet:
			Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))
		return false
	_taken = true
	_lying.erase(self)
	Audio.play("soft", global_position, -14.0, 0.1, &"Effects", 3.0, 1.4)
	Game.notify("+1x %s" % ItemDB.get_item(ITEM).display_name())
	Events.item_picked_up.emit(ITEM, 1)
	if player is Player:
		# The bag's arrows stand along +Y: shown turned along the shaft.
		var xf := global_transform
		(player as Player).show_take(ITEM, Transform3D(Basis(xf.basis.x, -xf.basis.z, xf.basis.y), xf.origin))
	queue_free()
	return true


func _check_walk_over() -> void:
	if _age < PICKUP_ARM or not can_take():
		return
	var player := Game.player as Player
	if player == null or player.driving != null or player.riding != null:
		return
	var mid := global_transform * Vector3(0, 0, -ArrowModels.LENGTH * 0.5)
	var p := player.global_position
	if Vector2(mid.x - p.x, mid.z - p.z).length() < PICKUP_REACH and absf(mid.y - p.y) < 1.4:
		take(player, true)


static func _facing(dir: Vector3) -> Basis:
	var d := dir.normalized()
	return Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.98 else Vector3.FORWARD)
