class_name Pickup
extends RigidBody3D
## An item lying in the world. After a short delay it is pulled toward a nearby
## player and collected (partially, if the inventory is nearly full): it hops up in an
## arc toward the player's pocket, shrinking as it goes.

const MAGNET_RANGE := 2.4
const ARM_DELAY := 0.6
## Where a pickup flies to, in the camera's space: a pocket just under the view.
const POCKET := Vector3(0.22, -0.55, -0.35)

var stack: ItemStack
## Harvest pops seek the player from further away.
var seek := false
var _age := 0.0
var _flying := false
var _mi: MeshInstance3D
var _mi_scale := 1.0
## Where the flight toward the player started, and how far along it is (0..1).
var _fly_from := Vector3.ZERO
var _fly_t := 0.0


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
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (aabb.size * s).max(Vector3(0.08, 0.08, 0.08))
	cs.shape = box
	add_child(cs)
	rotation.y = randf() * TAU


func _physics_process(delta: float) -> void:
	_age += delta
	var player := Game.player as Player
	if player == null or _age < ARM_DELAY:
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
