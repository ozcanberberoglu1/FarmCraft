class_name Pickup
extends RigidBody3D
## An item lying in the world. After a short delay it is pulled toward a nearby
## player and collected (partially, if the inventory is nearly full): it hops up in an
## arc toward the player's pocket, shrinking as it goes.
## Eggs (HAND_ONLY) are never pulled in: the farmer looks at one and takes it with E, one
## egg at a time (it flies into the hand or down into its hotbar slot). They are small
## and the colour of straw, so they are shown: within EGG_SHIMMER_RANGE a soft halo of
## light and a passing glint (egg_shimmer.gdshader), and the egg the farmer looks at
## (the interaction ray: set_highlight, the "look_highlight" group) a thin warm outline
## and a brighter rim.
## The dog's ball (BALL) is taken by hand as well, shown the same way, and never by
## walking near it: E looking at it, once it is the farmer's to take (while the dog is
## after it, only a line saying to wait). It is a ball: a small sphere that bounces a
## little, loses speed rolling over the grass (BALL_DRAG) and lies still where it stops
## (frozen there: on a slope too) a few seconds after it was thrown; fallen into a pond
## it floats and drifts to the bank; under the ground it is put back on it (_ball_step).

const MAGNET_RANGE := 2.4
const ARM_DELAY := 0.6
## Where a pickup flies to, in the camera's space: a pocket just under the view.
const POCKET := Vector3(0.22, -0.55, -0.35)
## Items only ever taken by hand (E), one at a time; the reach of their grab target (on
## the interaction layer only: a little more than the egg itself, easier to aim at).
const HAND_ONLY: Array[StringName] = [&"egg", &"dog_ball"]
const GRAB_RADIUS := 0.09
## The dog's ball: its item, its radius and its grab target's (m); the speed it loses a
## second rolling on the ground (m/s²: thick grass), the speed under which it lies still
## there (m/s), and how fast it drifts to the bank in a pond (m/s).
const BALL := &"dog_ball"
const BALL_RADIUS := 0.034
const BALL_GRAB := 0.17
const BALL_DRAG := 3.6
const BALL_STILL := 0.4
const BALL_DRIFT := 1.8
## Metres from the eye within which an egg shimmers (none beyond), and where the shimmer
## is at its full (it fades in between the two).
const EGG_SHIMMER_RANGE := 4.0
const EGG_SHIMMER_FULL := 2.8

var stack: ItemStack
## Harvest pops seek the player from further away.
var seek := false
## Taken by hand only (HAND_ONLY): no pull toward the player.
var by_hand := false
## The dog's ball (BALL): lying still where it stopped (frozen), or afloat in a pond.
var is_ball := false
var still := false
var afloat := false
var _ground_t := 0.0
var _air_t := 0.0
var _bob := 0.0
var _age := 0.0
var _flying := false
var _mi: MeshInstance3D
var _mi_scale := 1.0
## Where the flight toward the player started, and how far along it is (0..1).
var _fly_from := Vector3.ZERO
var _fly_t := 0.0
## An egg's shimmer shell and the outline shown while it is looked at (eggs only).
var _shimmer: MeshInstance3D
var _outline: MeshInstance3D

static var _shimmer_mat: ShaderMaterial
static var _outline_mat: ShaderMaterial


static func spawn(item_stack: ItemStack, at: Vector3, impulse := Vector3.ZERO, seek_player := false) -> Pickup:
	var p := Pickup.new()
	p.stack = item_stack
	p.seek = seek_player
	p.position = at
	Game.world.add_child(p)
	p.reset_physics_interpolation()
	p.apply_central_impulse(impulse)
	return p


func _ready() -> void:
	# Moved in physics ticks: drawn between ticks (see Settings._ready).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer = 8
	collision_mask = 1
	mass = 0.5
	angular_damp = 2.0
	linear_damp = 0.4
	add_to_group(&"pickups")
	var mesh := ItemModels.mesh(stack.item.id)
	var aabb := mesh.get_aabb()
	# Long tools are scaled down so every pickup reads as a small object on the ground.
	var s := minf(1.0, 0.45 / maxf(aabb.get_longest_axis_size(), 0.01))
	_mi = MeshInstance3D.new()
	_mi.mesh = mesh
	_mi_scale = s
	_mi.scale = Vector3.ONE * s
	_mi.position = -aabb.get_center() * s
	# Small moving clutter: no GI voxelization, kept out of the rain-blocker heightfield.
	_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_mi.layers = 2
	add_child(_mi)
	# A dropped fish keeps its cartoon eyes ("Komik hayvanlar" setting).
	ComicFx.dress_fish(_mi, stack.item.id)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (aabb.size * s).max(Vector3(0.08, 0.08, 0.08))
	cs.shape = box
	add_child(cs)
	rotation.y = randf() * TAU
	by_hand = stack.item.id in HAND_ONLY
	is_ball = stack.item.id == BALL
	if is_ball:
		_become_ball(cs)
	if by_hand:
		add_to_group(&"interactable")
		# Highlighted whenever it is looked at (Player), and shimmering near by.
		add_to_group(&"look_highlight")
		_shimmer = egg_shimmer(mesh)
		_mi.add_child(_shimmer)
		_outline = _shell(mesh, _outline_material())
		_outline.name = "Outline"
		_outline.visible = false
		_mi.add_child(_outline)
		var grab := StaticBody3D.new()
		grab.name = "Grab"
		grab.collision_layer = 4
		grab.collision_mask = 0
		var gs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = BALL_GRAB if is_ball else GRAB_RADIUS
		gs.shape = sphere
		grab.add_child(gs)
		add_child(grab)


func _physics_process(delta: float) -> void:
	_age += delta
	if is_ball and not _flying:
		_ball_step(delta)
	var player := Game.player as Player
	if player == null or _age < ARM_DELAY or (by_hand and not _flying):
		return
	var target := player.global_position + Vector3(0, 0.9, 0)
	var magnet := 8.0 if seek else MAGNET_RANGE
	if not _flying and global_position.distance_to(target) < magnet and _has_room():
		_flying = true
		freeze = true
		collision_layer = 0
		_fly_from = global_position
		_fly_t = 0.0
	if _flying:
		# Into the pocket, just under the view (the chest while driving).
		var to := target if player.driving else player.camera.global_transform * POCKET
		var dist := _fly_from.distance_to(to)
		_fly_t = minf(_fly_t + delta / (0.28 + dist * 0.04), 1.0)
		var mid := _fly_from.lerp(to, 0.5) + Vector3.UP * clampf(dist * 0.25, 0.15, 0.8)
		var u := ease(_fly_t, 1.8)
		global_position = _fly_from.lerp(mid, u).lerp(mid.lerp(to, u), u)
		_mi.scale = Vector3.ONE * _mi_scale * lerpf(1.0, 0.35, u)
		if _fly_t >= 1.0:
			_collect()


func _has_room() -> bool:
	var inv := PlayerState.inventory
	if inv.first_empty() >= 0:
		return true
	for s in inv.slots:
		if s != null and s.can_merge(stack) and s.space_left() > 0:
			return true
	return false


func _collect() -> void:
	var left := PlayerState.inventory.add_stack(stack)
	var taken := stack.count - left
	if taken > 0:
		Game.notify("+%dx %s" % [taken, stack.item.display_name()])
		Events.item_picked_up.emit(stack.item.id, taken)
	if left > 0:
		stack.count = left
		_flying = false
		freeze = false
		collision_layer = 8
		_age = 0.0
		_mi.scale = Vector3.ONE * _mi_scale
	else:
		queue_free()


# --- Taken by hand (eggs) -----------------------------------------------------------------

## The shimmer shell for an egg's `mesh` (a child of the egg's MeshInstance3D: the
## Pickup's, the HatchingEgg's): drawn only within EGG_SHIMMER_RANGE of the eye.
static func egg_shimmer(mesh: Mesh) -> MeshInstance3D:
	if _shimmer_mat == null:
		_shimmer_mat = ShaderMaterial.new()
		_shimmer_mat.shader = load("res://shaders/egg_shimmer.gdshader")
		_shimmer_mat.set_shader_parameter(&"fade_end", EGG_SHIMMER_RANGE)
		_shimmer_mat.set_shader_parameter(&"fade_full", EGG_SHIMMER_FULL)
	var shell := _shell(mesh, _shimmer_mat)
	shell.name = "Shimmer"
	shell.visibility_range_end = EGG_SHIMMER_RANGE + 0.4
	shell.set_instance_shader_parameter(&"phase", randf())
	return shell


## How strongly an egg shimmers `distance` metres from the eye (0..1, as the shader fades it).
static func shimmer_at(distance: float) -> float:
	return 1.0 - smoothstep(EGG_SHIMMER_FULL, EGG_SHIMMER_RANGE, distance)


static func _outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/egg_outline.gdshader")
	return _outline_mat


## `mesh` again as a shell with `material` over every surface: no shadow, no GI, off the
## rain map's layer (as the pickup's own mesh).
static func _shell(mesh: Mesh, material: Material) -> MeshInstance3D:
	var shell := MeshInstance3D.new()
	shell.mesh = mesh
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	shell.layers = 2
	return shell


## The egg the farmer looks at: its outline shows and its rim lights up (Player calls
## this for the "look_highlight" group while it is the interaction ray's target).
func set_highlight(on: bool) -> void:
	if _outline == null or _outline.visible == on:
		return
	_outline.visible = on
	_shimmer.set_instance_shader_parameter(&"aimed", 1.0 if on else 0.0)


## Whether it is shown as looked at (its outline is up).
func is_highlighted() -> bool:
	return _outline != null and _outline.visible


## Its shimmer shell (eggs only; null for anything else).
func shimmer() -> MeshInstance3D:
	return _shimmer


## A plain line under the prompt: the dog is on its way to this ball.
func hint_prompt() -> String:
	return tr("HINT_BALL_WAIT") % Pet.dog_name if _dog_after() else ""


func interact_prompt(_player: Node) -> String:
	if not by_hand or _flying or is_queued_for_deletion() or _dog_after():
		return ""
	return tr("ACTION_TAKE_BALL") if is_ball else tr("ACTION_TAKE_EGG")


## E: one egg into the bag (the rest of a dropped stack stays lying here), a soft sound
## as it comes off the straw or the ground, and it flies into the hand (or its slot).
func interact(player: Node) -> void:
	if not by_hand or _flying or is_queued_for_deletion() or _dog_after():
		return
	var one := stack.copy()
	one.count = 1
	if PlayerState.inventory.add_stack(one) > 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))
		return
	var id := stack.item.id
	var from := _mi.global_transform
	stack.count -= 1
	if stack.count <= 0:
		collision_layer = 0
		queue_free()
	Audio.play("soft", global_position, -12.0, 0.1, &"Effects", 3.0, 1.7)
	Game.notify("+1x %s" % one.item.display_name())
	Events.item_picked_up.emit(id, 1)
	if player is Player:
		(player as Player).show_take(id, from)


# --- The dog's ball ------------------------------------------------------------------------

## A ball's body: a small sphere with some bounce, swept (it is small and quick: it never
## tunnels through the ground), its touching the ground known (_ball_step).
func _become_ball(cs: CollisionShape3D) -> void:
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.7
	mat.rough = true
	physics_material_override = mat
	angular_damp = 0.8
	linear_damp = 0.15
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	can_sleep = false
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_RADIUS
	cs.shape = sphere


## The dog (PetDog) is on its way to this ball: it is the dog's to take, not the farmer's.
func _dog_after() -> bool:
	var dog := Pet.dog
	return is_ball and dog != null and is_instance_valid(dog) and dog.ball == self and dog.task == &"fetch"


## A tick of the ball: rolling on the ground it loses BALL_DRAG of speed a second (its
## spin with it, so it doesn't push itself on) and under BALL_STILL it lies still; in a
## pond's water it floats and drifts ashore; under the ground it is put back on it.
func _ball_step(delta: float) -> void:
	if afloat:
		_drift(delta)
		return
	if still:
		return
	var p := global_position
	var ground := TerrainData.height(p.x, p.z)
	if p.y < WorldLayout.WATER_LEVEL and ground < WorldLayout.WATER_LEVEL - BALL_RADIUS:
		afloat = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		global_position = Vector3(p.x, WorldLayout.WATER_LEVEL, p.z)
		Fx.water_splash(Vector3(p.x, WorldLayout.WATER_LEVEL, p.z))
		return
	if p.y < ground - 0.5:
		global_position = Vector3(p.x, ground + BALL_RADIUS, p.z)
		reset_physics_interpolation()
		_lie_still()
		return
	if get_contact_count() == 0 and p.y > ground + BALL_RADIUS + 0.02:
		_air_t += delta
		if _air_t > 0.12:
			_ground_t = 0.0
		return
	_air_t = 0.0
	_ground_t += delta
	var v := linear_velocity
	var speed := v.length()
	if speed < BALL_STILL and _ground_t > 0.1:
		_lie_still()
		return
	if speed > 0.001:
		var k := maxf(speed - BALL_DRAG * delta, 0.0) / speed
		linear_velocity = v * k
		angular_velocity *= k


## It lies still where it is (a static body: it stays put on a slope).
func _lie_still() -> void:
	still = true
	afloat = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true


## Afloat in a pond: bobbing on the water, drifting out from the middle till it is on the
## bank outside the pond's shore wall (where the farmer and the dog can get at it).
func _drift(delta: float) -> void:
	var p := global_position
	var xz := Vector2(p.x, p.z)
	var c := WorldLayout.POND_CENTER
	var r := WorldLayout.POND_RADIUS
	if xz.distance_to(WorldLayout.TOWN_POND_CENTER) - WorldLayout.TOWN_POND_RADIUS < xz.distance_to(c) - r:
		c = WorldLayout.TOWN_POND_CENTER
		r = WorldLayout.TOWN_POND_RADIUS
	var d := xz.distance_to(c)
	var ground := TerrainData.height(p.x, p.z)
	if d > r + 8.0 or (ground > WorldLayout.WATER_LEVEL - 0.02 and d > r - 0.3):
		# On the bank (or in some other water, where it stays afloat as it is).
		global_position = Vector3(p.x, maxf(ground + BALL_RADIUS, WorldLayout.WATER_LEVEL), p.z)
		_lie_still()
		return
	var out := (xz - c) / d if d > 0.01 else Vector2.RIGHT
	xz += out * BALL_DRIFT * delta
	_bob += delta
	var y := maxf(WorldLayout.WATER_LEVEL + sin(_bob * 3.0) * 0.008, TerrainData.height(xz.x, xz.y) + BALL_RADIUS)
	global_position = Vector3(xz.x, y, xz.y)
