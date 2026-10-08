class_name BodyWarp
extends RefCounted
## Putting a kinematic walker (an animal, a dog, a townsperson) somewhere at once. The
## physics server carries a kinematic body to a new place by sweeping it there within one
## tick, at whatever speed that takes (three metres are 180 m/s), and what its collider
## touches on the way gets that speed: the pup set down from the passenger seat rammed the
## pickup through the ground. So the collider is off while the body is moved and comes
## back on TICKS physics ticks later, when it stands still at the new place (the farmer's
## own body does the same getting out of a cab, Player._exit_frames).
##   on_after_move(shape)  put down / set out into the world: collider on, after the move
##   moved(shape)          a walker with its collider on was just put somewhere else
##   off(shape)            picked up, riding: collider off until on_after_move
## The three go through here so that a later call always wins over an earlier one's wait.

const TICKS := 2
const _SEQ := &"body_warp_seq"
const _WANT := &"body_warp_on"


## The collider off for as long as it is carried or rides.
static func off(shape: CollisionShape3D) -> void:
	if shape == null:
		return
	shape.set_meta(_SEQ, int(shape.get_meta(_SEQ, 0)) + 1)
	shape.set_meta(_WANT, false)
	shape.set_deferred("disabled", true)


## The body has just been (or is just about to be, this frame) put where it now belongs:
## its collider stays off for the move and is on again TICKS physics ticks later.
static func on_after_move(shape: CollisionShape3D) -> void:
	if shape == null:
		return
	var seq := int(shape.get_meta(_SEQ, 0)) + 1
	shape.set_meta(_SEQ, seq)
	shape.set_meta(_WANT, true)
	shape.set_deferred("disabled", true)
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or not shape.is_inside_tree():
		shape.set_deferred("disabled", false)
		return
	for i in TICKS:
		await loop.physics_frame
	if is_instance_valid(shape) and int(shape.get_meta(_SEQ, 0)) == seq:
		shape.disabled = false


## A walker standing in the world was just put somewhere else in one go: the same wait,
## unless its collider is meant to be off anyway (carried, ridden).
static func moved(shape: CollisionShape3D) -> void:
	if shape == null or not bool(shape.get_meta(_WANT, not shape.disabled)):
		return
	on_after_move(shape)
