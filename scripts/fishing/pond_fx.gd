class_name PondFx
extends RefCounted
## Water effects of fishing: rings of ripples spreading over the pond (shaders/ripple),
## drops thrown up where something breaks the surface (Fx's clear droplets, cut off at
## the waterline) and a burst of white spray for a thrashing fish. Rings are pooled.

const MAX_RINGS := 14

static var _rings: Array[MeshInstance3D] = []
static var _ring_mesh: PlaneMesh
static var _ring_mat: ShaderMaterial
static var _drop_mat: ShaderMaterial
static var _drop_mesh: Mesh
static var _spray: Array[CPUParticles3D] = []


## A ring of ripples at `at` (on the water) growing to `radius` metres over `life` seconds.
static func ring(at: Vector3, radius := 0.8, life := 2.2, strength := 1.0) -> void:
	if Game.world == null:
		return
	var r := _free_ring()
	if r == null:
		return
	r.global_position = Vector3(at.x, WorldLayout.WATER_LEVEL + 0.004, at.z)
	r.scale = Vector3.ONE * radius
	r.visible = true
	r.set_instance_shader_parameter(&"strength", strength)
	r.set_instance_shader_parameter(&"age", 0.0)
	if r.has_meta(&"tween"):
		var old: Tween = r.get_meta(&"tween")
		if old and old.is_valid():
			old.kill()
	var tw := r.create_tween()
	tw.tween_method(func(a: float) -> void: r.set_instance_shader_parameter(&"age", a), 0.0, 1.0, life)
	tw.tween_callback(func() -> void: r.visible = false)
	r.set_meta(&"tween", tw)


static func _free_ring() -> MeshInstance3D:
	# (assign: filter() hands back an untyped Array.)
	_rings.assign(_rings.filter(func(n: MeshInstance3D) -> bool: return is_instance_valid(n) and n.get_parent() == Game.world))
	for r in _rings:
		if not r.visible:
			return r
	if _rings.size() >= MAX_RINGS:
		return _rings[0]
	if _ring_mesh == null:
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2(2.0, 2.0)
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = load("res://shaders/ripple.gdshader")
		# Over the pond's water (both are see-through).
		_ring_mat.render_priority = 1
	var r := MeshInstance3D.new()
	r.mesh = _ring_mesh
	r.material_override = _ring_mat
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	r.layers = 2
	r.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	r.visible = false
	Game.world.add_child(r)
	_rings.append(r)
	return r


## Drops thrown up from the surface at `at`: `amount` of them at up to `speed` m/s,
## spread over `radius` metres; they vanish into the water where they fall back.
static func drops(at: Vector3, amount: int, speed: float, radius := 0.1, size := 0.004) -> void:
	if Game.world == null:
		return
	if _drop_mat == null:
		_drop_mat = Fx.droplet_material().duplicate() as ShaderMaterial
		_drop_mat.set_shader_parameter("floor_y", WorldLayout.WATER_LEVEL - 0.005)
		_drop_mesh = Fx.droplet_mesh(1.0, 2.0, _drop_mat)
	var p := _emitter(_drop_mesh)
	p.amount = maxi(roundi(amount * Fx.detail()), 3)
	p.lifetime = maxf(speed * 0.28, 0.3)
	p.direction = Vector3.UP
	p.spread = 38.0
	p.gravity = Vector3(0, -9.8, 0)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.particle_flag_align_y = true
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.global_position = Vector3(at.x, WorldLayout.WATER_LEVEL + 0.01, at.z)
	p.restart()


## White spray over a thrashing fish (soft puffs that burst up and sink back).
static func spray(at: Vector3, size := 1.0) -> void:
	if Game.world == null:
		return
	var p := _emitter(null, true)
	p.amount = maxi(roundi(10 * Fx.detail()), 4)
	p.lifetime = 0.55
	p.direction = Vector3.UP
	p.spread = 55.0
	p.gravity = Vector3(0, -9.0, 0)
	p.initial_velocity_min = 0.5 * size
	p.initial_velocity_max = 1.5 * size
	p.scale_amount_min = 0.1 * size
	p.scale_amount_max = 0.22 * size
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12 * size
	p.global_position = Vector3(at.x, WorldLayout.WATER_LEVEL + 0.03, at.z)
	p.restart()


static func _emitter(mesh: Mesh, puff := false) -> CPUParticles3D:
	_spray.assign(_spray.filter(func(n: CPUParticles3D) -> bool: return is_instance_valid(n) and n.get_parent() == Game.world))
	for e in _spray:
		if not e.emitting and e.has_meta(&"puff") == puff:
			return e
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.layers = 2
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if puff:
		p.set_meta(&"puff", true)
		var q := QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(Fx.DUST_TEX)
		m.albedo_color = Color(0.92, 0.95, 0.97, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.4
		q.material = m
		p.mesh = q
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.9))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = ramp
		p.angle_min = -180.0
		p.angle_max = 180.0
	else:
		p.mesh = mesh
	Game.world.add_child(p)
	_spray.append(p)
	return p
