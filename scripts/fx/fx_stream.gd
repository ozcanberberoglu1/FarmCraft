class_name FxStream
extends CPUParticles3D
## The watering can's stream: clear, glinting drops falling in the world from the spout
## (HeldItem places it on the spout every frame and turns `emitting` on and off). Aimed
## at a spot (aim), the drops arc from the spout onto it, else they leave along the
## spout's axis. The drops end where the water lands (their shader hides what falls
## below that), which splashes, and the ground there darkens with wet patches
## (Fx.wet_spot).

## Metres a drop falls at most before it is gone.
const MAX_FALL := 3.0
## Seconds between wet patches where the stream lands.
const SPOT_EVERY := 0.14
## m/s the drops leave the spout with when the stream is not aimed.
const SPEED := Vector2(1.15, 1.45)
## An aimed stream: the fastest a drop leaves the spout (m/s) and how far (degrees) its
## flight may climb or dip from the spout's axis; a spot beyond that is pulled back
## toward the can until the stream reaches it.
const MAX_SPEED := 3.4
const MAX_TURN := 35.0

## The spout's axis in the stream's own frame: the way the water leaves.
var axis := Vector3.FORWARD

var _mat: ShaderMaterial
var _splash: CPUParticles3D
var _spot_t := 0.0
var _land := Vector3.ZERO
var _landed := false
var _aim := Vector3.ZERO
var _aimed := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	one_shot = false
	emitting = false
	explosiveness = 0.0
	randomness = 1.0
	lifetime = 0.8
	var q := Fx.detail()
	amount = maxi(roundi(300 * q), 90)
	spread = 2.5
	flatness = 0.0
	initial_velocity_min = SPEED.x
	initial_velocity_max = SPEED.y
	gravity = Vector3(0, -9.8, 0)
	damping_min = 0.0
	damping_max = 0.3
	scale_amount_min = 0.5
	scale_amount_max = 1.1
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.006
	particle_flag_align_y = true
	local_coords = false
	_mat = Fx.droplet_material().duplicate() as ShaderMaterial
	mesh = Fx.droplet_mesh(0.006, 5.0, _mat)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Small clutter: kept out of the rain height map (layer 2) and out of GI.
	layers = 2
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Placed every frame from the view model's _process.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.randomize()


func _ready() -> void:
	_splash = CPUParticles3D.new()
	_splash.one_shot = false
	_splash.emitting = false
	_splash.amount = maxi(roundi(36 * Fx.detail()), 12)
	_splash.lifetime = 0.4
	_splash.randomness = 1.0
	_splash.direction = Vector3.UP
	_splash.spread = 50.0
	_splash.initial_velocity_min = 0.35
	_splash.initial_velocity_max = 1.1
	_splash.gravity = Vector3(0, -9.8, 0)
	_splash.scale_amount_min = 0.4
	_splash.scale_amount_max = 1.0
	_splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_splash.emission_sphere_radius = 0.035
	_splash.particle_flag_align_y = true
	_splash.local_coords = false
	_splash.mesh = Fx.droplet_mesh(0.0045, 1.8, Fx.droplet_material())
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splash.layers = 2
	_splash.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_splash.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_splash.top_level = true
	add_child(_splash)


func _process(delta: float) -> void:
	if not emitting or not is_visible_in_tree():
		if _splash and _splash.emitting:
			_splash.emitting = false
		_landed = false
		return
	_launch()
	_find_landing()
	_mat.set_shader_parameter("floor_y", _land.y if _landed else -1.0e6)
	_splash.emitting = _landed
	if not _landed:
		return
	_splash.global_position = _land + Vector3(0, 0.01, 0)
	_spot_t -= delta
	if _spot_t <= 0.0:
		_spot_t = SPOT_EVERY * _rng.randf_range(0.7, 1.3)
		var off := Vector3(_rng.randf_range(-0.07, 0.07), 0.0, _rng.randf_range(-0.07, 0.07))
		Fx.wet_spot(_land + off, _rng.randf_range(0.07, 0.13))


## Lands the stream on `at` (world) while it pours; `on` false lets it leave along the
## spout's axis again.
func aim(at: Vector3, on := true) -> void:
	_aim = at
	_aimed = on


## The drops' direction and speed this frame: onto the aimed spot, else along the axis.
func _launch() -> void:
	var ax := (global_basis * axis).normalized()
	var v := launch_velocity(global_position, _aim, ax) if _aimed else Vector3.ZERO
	if v == Vector3.ZERO:
		direction = axis
		initial_velocity_min = SPEED.x
		initial_velocity_max = SPEED.y
		return
	var speed := v.length()
	direction = (global_basis.inverse() * (v / speed)).normalized()
	initial_velocity_min = speed * 0.92
	initial_velocity_max = speed * 1.08


## The velocity a drop leaves `from` with to come down on `to`: headed for it, climbing or
## dipping as little from the spout's `axis` (world) as a can's stream allows. A spot
## out of reach is pulled back toward the can. ZERO when the stream cannot get near it.
static func launch_velocity(from: Vector3, to: Vector3, axis: Vector3) -> Vector3:
	var d := to - from
	var axis_climb := asin(clampf(axis.y, -1.0, 1.0))
	var max_turn := deg_to_rad(MAX_TURN)
	for pull in 12:
		var best := Vector3.ZERO
		var best_turn := INF
		# Flight times short enough for the drops' lifetime.
		for i in 16:
			var t := lerpf(0.1, 0.7, float(i) / 15.0)
			var v := d / t + Vector3(0.0, 4.9 * t, 0.0)
			if v.length() > MAX_SPEED:
				continue
			var turn := absf(asin(clampf(v.y / v.length(), -1.0, 1.0)) - axis_climb)
			if turn < best_turn:
				best_turn = turn
				best = v
		if best_turn <= max_turn:
			return best
		d = Vector3(d.x * 0.9, d.y, d.z * 0.9)
	return Vector3.ZERO


## Where the stream comes down now, else `fallback`.
func landing(fallback: Vector3) -> Vector3:
	return _land if emitting and _landed else fallback


## Where a drop leaving the spout at the middle speed comes down: the ground, a bed or a
## trough, whichever it meets first.
func _find_landing() -> void:
	_landed = false
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var v := (global_basis * direction).normalized() * (initial_velocity_min + initial_velocity_max) * 0.5
	var from := global_position
	var exclude: Array[RID] = []
	if Game.player is CollisionObject3D:
		exclude.append((Game.player as CollisionObject3D).get_rid())
	var t := 0.0
	for i in 5:
		t += 0.16
		var to := global_position + v * t + Vector3(0, -4.9 * t * t, 0)
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, exclude)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			_land = hit["position"]
			_landed = true
			return
		if global_position.y - to.y > MAX_FALL:
			return
		from = to
