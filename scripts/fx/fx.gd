class_name Fx
extends RefCounted
## One-shot particle effects for farming actions. Finished emitters stay in the world
## and are reused by the next burst of the same look. Tool strikes fire theirs on the
## impact frame (see ToolAnim and the targets' use_impact), thrown the way the blow goes.

## Finished emitters kept for reuse per look.
const POOL_SIZE := 4
const SOIL := Color(0.27, 0.19, 0.12)
const DUST := Color(0.45, 0.36, 0.26, 0.6)
const WATER := Color(0.75, 0.88, 1.0, 0.85)
const SPLASH := Color(0.8, 0.9, 1.0, 0.8)
const SPARK := Color(1.0, 0.62, 0.22)

static var _mats: Dictionary = {}
## Particle quads per look ("color|size|aspect|glow").
static var _meshes: Dictionary = {}
## Finished emitters per look, waiting for their next burst.
static var _pool: Dictionary = {}
## Sparks shrink away; dust puffs swell as they drift.
static var _shrink: Curve
static var _swell: Curve
## Set while warm_up runs: every burst is one still particle, so nothing sprays in front
## of the player while the loading veil fades out.
static var _warming := false


## Shows one tiny burst of every particle look at `at`, so their shaders are compiled
## and their emitters made while the loading screen is up instead of on the first hoe
## stroke, axe blow or watering.
static func warm_up(at: Vector3) -> void:
	_warming = true
	_burst(at, Color(0.34, 0.24, 0.15), 1, Vector3.ZERO, 0.0, 0.1, 0.0, 0.035)
	_burst(at, WATER, 1, Vector3.ZERO, 0.0, 0.1, 0.0, 0.025)
	dirt_clods(at, Vector3.ZERO, 0.1)
	wood_chips(at)
	stone_chips(at)
	clippings(at, Vector3.RIGHT)
	leaves(at, Vector2(0.1, 0.1), true)
	leaves(at, Vector2(0.1, 0.1), false)
	seed_scatter(at, at + Vector3(0, -0.1, 0), 0.1, Color(0.6, 0.5, 0.3))
	drips(at)
	_warming = false


static func dirt_burst(at: Vector3, size := 1.0) -> void:
	_burst(at, Color(0.34, 0.24, 0.15), int(30 * size), Vector3(size * 0.6, 0.02, size * 0.6), 2.2, 0.8, 50.0, 0.035)


## Clods thrown up and back (`back`: toward the player) where a blade bites the soil,
## with a low puff of dust.
static func dirt_clods(at: Vector3, back: Vector3, size := 1.0) -> void:
	var dir := (Vector3.UP * 1.4 + back).normalized()
	_burst(at, SOIL, maxi(int(10 * size), 1), Vector3(0.12, 0.02, 0.12) * size, 3.0, 0.9, 35.0, 0.06, dir,
			9.8, 0.0, 1.0, false, 0.4)
	_burst(at, Color(0.34, 0.24, 0.15), maxi(int(14 * size), 1), Vector3(0.14, 0.02, 0.14) * size, 2.4, 0.7, 45.0, 0.03, dir)
	_burst(at, DUST, maxi(int(8 * size), 1), Vector3(0.2, 0.02, 0.2), 0.9, 0.6, 80.0, 0.14, Vector3.UP, 1.5, 1.5)


static func water_splash(at: Vector3) -> void:
	# Droplets fall from the can's height onto the bed, then a few bounce.
	_burst(at + Vector3(0, 0.9, 0), WATER, 70, Vector3(0.7, 0.05, 0.7), 1.2, 0.7, 20.0, 0.025, Vector3.DOWN)
	_burst(at, SPLASH, 24, Vector3(0.8, 0.02, 0.8), 1.4, 0.4, 70.0, 0.02)


## A few droplets bouncing off the soil under the can's stream.
static func drips(at: Vector3) -> void:
	_burst(at, SPLASH, 8, Vector3(0.25, 0.02, 0.25), 1.2, 0.35, 60.0, 0.02)


static func leaf_burst(at: Vector3, crop: StringName) -> void:
	var col := Color(0.8, 0.66, 0.3) if crop == &"wheat" else Color(0.32, 0.5, 0.18)
	_burst(at, col, 26, Vector3(0.6, 0.2, 0.6), 2.6, 1.0, 60.0, 0.04)


## Chips and bark flakes flying off the trunk toward `out` (the side the axe hit), with
## a little sawdust.
static func wood_chips(at: Vector3, out := Vector3.UP) -> void:
	var dir := (out.normalized() + Vector3.UP * 0.45).normalized()
	_burst(at, Color(0.78, 0.62, 0.42), 22, Vector3(0.05, 0.08, 0.05), 4.2, 0.8, 38.0, 0.035, dir,
			9.8, 0.0, 1.6, false, 0.4)
	_burst(at, Color(0.33, 0.24, 0.16), 8, Vector3(0.05, 0.1, 0.05), 3.0, 0.9, 45.0, 0.05, dir,
			9.8, 0.0, 1.8, false, 0.4)
	_burst(at, Color(0.62, 0.52, 0.4, 0.5), 5, Vector3(0.05, 0.05, 0.05), 0.6, 0.9, 70.0, 0.16, dir, 0.8, 2.0)


## Grey chips and a few hot sparks off the rock toward `out`, and a puff of rock dust.
static func stone_chips(at: Vector3, out := Vector3.UP) -> void:
	var dir := (out.normalized() + Vector3.UP * 0.6).normalized()
	_burst(at, Color(0.55, 0.54, 0.52), 18, Vector3(0.06, 0.06, 0.06), 3.6, 0.7, 45.0, 0.03, dir,
			9.8, 0.0, 1.3, false, 0.4)
	_burst(at, SPARK, 9, Vector3(0.02, 0.02, 0.02), 6.0, 0.22, 55.0, 0.012, dir, 9.8, 0.0, 1.0, true, 0.7)
	_burst(at, Color(0.6, 0.58, 0.55, 0.5), 5, Vector3(0.06, 0.06, 0.06), 0.7, 0.8, 70.0, 0.15, dir, 0.8, 2.0)


## A thrown egg breaking: yolk and white spattered off the surface, bits of shell.
static func egg_splat(at: Vector3, normal := Vector3.UP) -> void:
	var dir := (normal.normalized() + Vector3.UP * 0.4).normalized()
	_burst(at, Color(0.97, 0.68, 0.12), 14, Vector3(0.03, 0.03, 0.03), 2.2, 0.55, 60.0, 0.022, dir,
			9.8, 0.0, 1.0, false, 0.4)
	_burst(at, Color(0.95, 0.92, 0.84), 10, Vector3(0.03, 0.03, 0.03), 2.8, 0.6, 70.0, 0.016, dir,
			9.8, 0.0, 1.5, false, 0.5)


## Grass clippings flung along the scythe's sweep (`sweep`: world direction).
static func clippings(at: Vector3, sweep: Vector3, color := Color(0.36, 0.52, 0.2)) -> void:
	var dir := (sweep.normalized() + Vector3.UP * 0.7).normalized()
	_burst(at, color, 24, Vector3(0.4, 0.15, 0.4), 3.2, 1.1, 30.0, 0.04, dir, 4.0, 2.0, 2.5, false, 0.4)


## Needles or leaves shaken loose from a crown (half extents in metres) drifting down.
static func leaves(at: Vector3, half: Vector2, needles: bool) -> void:
	var col := Color(0.2, 0.33, 0.14) if needles else Color(0.3, 0.45, 0.16)
	_burst(at, col, 8, Vector3(half.x, 0.3, half.y), 0.4, 2.2, 90.0, 0.03 if needles else 0.05, Vector3.DOWN,
			2.5, 1.5, 3.0 if needles else 1.0)


## Seeds thrown from `from` in an arc that lands on `to` after `flight` seconds.
static func seed_scatter(from: Vector3, to: Vector3, flight: float, color: Color) -> void:
	var t := maxf(flight, 0.05)
	var v := (to - from) / t + Vector3(0, 4.9 * t, 0)
	_burst(from, color, 22, Vector3(0.02, 0.02, 0.02), v.length(), t + 0.06, 9.0, 0.014, v.normalized(),
			9.8, 0.0, 1.0, false, 0.88, 0.6)


## Construction dust over an area (half extents in meters).
static func dust_cloud(at: Vector3, half_extents: Vector2) -> void:
	var amount := int(clampf(half_extents.x * half_extents.y * 4.0, 40, 400))
	_burst(at, Color(0.62, 0.56, 0.48, 0.55), amount, Vector3(half_extents.x, 0.6, half_extents.y), 1.6, 1.6, 80.0, 0.35)


## A looping water stream for the watering can's spout (the caller places it and turns
## `emitting` on and off). Its drops fall in the world, not with the view.
static func make_stream(direction: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = false
	p.emitting = false
	p.amount = 48
	p.lifetime = 0.45
	p.explosiveness = 0.0
	p.direction = direction
	p.spread = 5.0
	p.initial_velocity_min = 1.1
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.012
	p.local_coords = false
	var key := "stream"
	if not _meshes.has(key):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.018, 0.018)
		mesh.material = _material(WATER)
		_meshes[key] = mesh
	p.mesh = _meshes[key]
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.layers = 2
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Placed every frame from the view model's _process.
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return p


## One burst. `gravity` pulls down (m/s²), `damping` slows the particles, `aspect` > 1
## makes them longer than wide (they tumble), `glow` makes them emissive, `speed_min`
## is the slowest start speed as a share of `speed`.
static func _burst(at: Vector3, color: Color, amount: int, extents: Vector3, speed: float, lifetime: float,
		spread: float, particle_size: float, direction := Vector3.UP, gravity := 9.8, damping := 0.0,
		aspect := 1.0, glow := false, speed_min := 0.5, explosiveness := 0.85) -> void:
	if Game.world == null:
		return
	if _warming:
		amount = 1
		extents = Vector3.ZERO
		speed = 0.0
		lifetime = 0.1
	var key := "%s|%.3f|%.1f|%s" % [color.to_html(), particle_size, aspect, glow]
	var p := _take(key)
	if p == null:
		p = _make(key, color, particle_size, aspect, glow)
	if p.amount != maxi(amount, 1):
		p.amount = maxi(amount, 1)
	p.lifetime = maxf(lifetime, 0.05)
	p.direction = direction
	p.spread = spread
	p.gravity = Vector3(0, -gravity, 0)
	p.damping_min = damping * 0.6
	p.damping_max = damping
	p.explosiveness = explosiveness
	p.initial_velocity_min = speed * speed_min
	p.initial_velocity_max = speed
	p.emission_box_extents = extents
	p.global_position = at
	p.restart()


## A finished emitter of this look that is still in the current world, or null.
static func _take(key: String) -> CPUParticles3D:
	var list: Array = _pool.get(key, [])
	while not list.is_empty():
		var v: Variant = list.pop_back()
		if is_instance_valid(v) and (v as Node).get_parent() == Game.world:
			return v as CPUParticles3D
	return null


static func _make(key: String, color: Color, particle_size: float, aspect := 1.0, glow := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.85
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	if aspect != 1.0:
		# Splinters, flakes and blades of grass tumble as they fly.
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
	if glow:
		p.scale_amount_curve = _curve(true)
	elif color.a < 1.0 and particle_size >= 0.1:
		p.scale_amount_curve = _curve(false)
	if not _meshes.has(key):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(particle_size * aspect, particle_size)
		mesh.material = _material(color, glow)
		_meshes[key] = mesh
	p.mesh = _meshes[key]
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Small clutter: kept out of the rain height map (layer 2) and out of GI.
	p.layers = 2
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Placed once per burst and never moved in between: nothing to interpolate.
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.finished.connect(func() -> void: _release(p, key))
	Game.world.add_child(p)
	return p


static func _release(p: CPUParticles3D, key: String) -> void:
	if not _pool.has(key):
		_pool[key] = []
	var list: Array = _pool[key]
	if list.size() < POOL_SIZE:
		list.append(p)
	else:
		p.queue_free()


## Size over a particle's life: shrinking to nothing (sparks) or swelling (dust).
static func _curve(shrink: bool) -> Curve:
	if shrink:
		if _shrink == null:
			_shrink = Curve.new()
			_shrink.add_point(Vector2(0.0, 1.0))
			_shrink.add_point(Vector2(1.0, 0.0))
		return _shrink
	if _swell == null:
		_swell = Curve.new()
		_swell.add_point(Vector2(0.0, 0.6))
		_swell.add_point(Vector2(1.0, 1.0))
	return _swell


static func _material(color: Color, glow := false) -> StandardMaterial3D:
	var key := color.to_html() + ("|glow" if glow else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_color = color
		m.roughness = 0.6
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glow:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 6.0
		_mats[key] = m
	return _mats[key]
