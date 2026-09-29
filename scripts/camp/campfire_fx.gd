class_name CampfireFx
extends Node3D
## The living part of a campfire (Campfire sets heat, coals and smoke; they ease to
## their targets): tongues of flame over a glowing core (shaders/campfire_flame), sparks
## drifting up and now and then a log popping a burst of embers with a crack, a column
## of soft smoke leaning with the wind, a warm flickering light (the only one of the
## fire; it casts shadows on HIGH and ULTRA, dual-paraboloid on HIGH) and the crackle
## loop, all following how hot the fire is. Out of sight far away the particles stop.
## With several fires burning only the one nearest the camera casts shadows.
## How much of it there is follows the graphics preset (Fx.detail()).

## Fire's light: colour, energy at full heat, from the coals alone, and its reach (m).
const LIGHT_COLOR := Color(1.0, 0.56, 0.27)
const LIGHT_ENERGY := 2.0
const COAL_ENERGY := 0.45
const LIGHT_RANGE := 9.0
## Metres beyond which the particles stop (the light fades out on its own further on).
const FAR := 70.0
## Seconds the shown values take to follow their targets.
const EASE := 0.6

## Targets, 0..1: flames, coal glow, smoke.
var heat := 0.0
var coals := 0.0
var smoke := 0.0
## White steam instead of smoke (a doused fire).
var steaming := false

var _heat := 0.0
var _coals := 0.0
var _smoke := 0.0
var _flames: CPUParticles3D
var _core: CPUParticles3D
var _sparks: CPUParticles3D
var _pops: CPUParticles3D
var _smoke_p: CPUParticles3D
var _steam: CPUParticles3D
var _light: OmniLight3D
var _crackle: AudioStreamPlayer3D
var _t := 0.0
var _pop_in := 1.5
var _check_in := 0.0
var _near := true

## The fire whose light casts shadows (the nearest burning one) and how far it is.
static var _shadow_owner: WeakRef
static var _shadow_dist := INF
static var _flame_mat: ShaderMaterial
static var _spark_mat: ShaderMaterial
static var _smoke_mat: StandardMaterial3D


func _ready() -> void:
	_t = randf() * 100.0
	var d := Fx.detail()
	_core = _emitter(maxi(roundi(4 * minf(d, 1.0)), 3), 1.1, _quad(flame_material(), true))
	_core.emission_box_extents = Vector3(0.07, 0.01, 0.07)
	_core.position = Vector3(0, 0.03, 0)
	_core.initial_velocity_min = 0.04
	_core.initial_velocity_max = 0.14
	_core.gravity = Vector3(0, 0.35, 0)
	_core.scale_amount_min = 0.5
	_core.scale_amount_max = 0.66
	_core.scale_amount_curve = _curve([Vector2(0, 0.7), Vector2(0.3, 1.0), Vector2(1, 0.55)])
	_core.color = Color(0.9, 0.75, 0.62, 0.75)
	_core.color_ramp = _ramp([[0.0, 0.0], [0.2, 1.0], [0.7, 0.8], [1.0, 0.0]])
	_flames = _emitter(roundi(20 * clampf(d, 0.6, 1.2)), 0.78, _quad(flame_material(), true))
	_flames.lifetime_randomness = 0.3
	_flames.emission_box_extents = Vector3(0.13, 0.02, 0.13)
	_flames.position = Vector3(0, 0.05, 0)
	_flames.spread = 8.0
	_flames.initial_velocity_min = 0.3
	_flames.initial_velocity_max = 0.6
	_flames.gravity = Vector3(0, 1.4, 0)
	_flames.damping_min = 0.2
	_flames.damping_max = 0.6
	_flames.angle_min = -40.0
	_flames.angle_max = 40.0
	_flames.scale_amount_curve = _curve([Vector2(0, 0.55), Vector2(0.28, 1.0), Vector2(1, 0.35)])
	_flames.color_ramp = _ramp([[0.0, 0.0], [0.12, 1.0], [0.6, 0.85], [1.0, 0.0]])
	_sparks = _emitter(roundi(10 * d), 1.3, _quad(spark_material(), false))
	_sparks.lifetime_randomness = 0.6
	_sparks.emission_box_extents = Vector3(0.12, 0.05, 0.12)
	_sparks.position = Vector3(0, 0.22, 0)
	_sparks.spread = 22.0
	_sparks.initial_velocity_min = 0.5
	_sparks.initial_velocity_max = 1.5
	_sparks.gravity = Vector3(0, 0.25, 0)
	_sparks.damping_min = 0.3
	_sparks.damping_max = 1.0
	_sparks.radial_accel_min = -0.6
	_sparks.radial_accel_max = 0.6
	_sparks.scale_amount_min = 0.01
	_sparks.scale_amount_max = 0.02
	_sparks.color_ramp = _spark_ramp()
	_pops = _emitter(roundi(12 * d), 1.3, _quad(spark_material(), false))
	_pops.one_shot = true
	_pops.explosiveness = 1.0
	_pops.emitting = false
	_pops.emission_box_extents = Vector3(0.08, 0.04, 0.08)
	_pops.position = Vector3(0, 0.15, 0)
	_pops.spread = 40.0
	_pops.initial_velocity_min = 1.4
	_pops.initial_velocity_max = 3.0
	_pops.gravity = Vector3(0, -1.6, 0)
	_pops.damping_min = 0.4
	_pops.damping_max = 0.9
	_pops.scale_amount_min = 0.014
	_pops.scale_amount_max = 0.03
	_pops.color_ramp = _spark_ramp()
	_smoke_p = _emitter(maxi(roundi(11 * d), 5), 6.0, _quad(smoke_material(), false))
	_smoke_p.lifetime_randomness = 0.25
	_smoke_p.local_coords = false
	_smoke_p.emission_box_extents = Vector3(0.1, 0.02, 0.1)
	_smoke_p.position = Vector3(0, 0.5, 0)
	_smoke_p.spread = 10.0
	_smoke_p.initial_velocity_min = 0.3
	_smoke_p.initial_velocity_max = 0.5
	_smoke_p.damping_min = 0.02
	_smoke_p.damping_max = 0.08
	_smoke_p.angle_min = -180.0
	_smoke_p.angle_max = 180.0
	_smoke_p.angular_velocity_min = -14.0
	_smoke_p.angular_velocity_max = 14.0
	_smoke_p.anim_offset_max = 1.0
	_smoke_p.scale_amount_min = 0.35
	_smoke_p.scale_amount_max = 0.6
	_smoke_p.scale_amount_curve = _curve([Vector2(0, 0.5), Vector2(1, 3.2)])
	_smoke_p.color_ramp = _ramp([[0.0, 0.0], [0.14, 0.9], [0.55, 0.55], [1.0, 0.0]])
	_steam = _emitter(maxi(roundi(26 * d), 12), 3.4, _quad(smoke_material(), false))
	_steam.one_shot = true
	_steam.explosiveness = 0.75
	_steam.emitting = false
	_steam.local_coords = false
	_steam.emission_box_extents = Vector3(0.28, 0.05, 0.28)
	_steam.position = Vector3(0, 0.15, 0)
	_steam.spread = 30.0
	_steam.initial_velocity_min = 0.8
	_steam.initial_velocity_max = 1.9
	_steam.gravity = Vector3(0, 0.45, 0)
	_steam.damping_min = 0.6
	_steam.damping_max = 1.2
	_steam.angle_min = -180.0
	_steam.angle_max = 180.0
	_steam.anim_offset_max = 1.0
	_steam.scale_amount_min = 0.35
	_steam.scale_amount_max = 0.7
	_steam.scale_amount_curve = _curve([Vector2(0, 0.6), Vector2(1, 3.0)])
	_steam.color = Color(0.92, 0.92, 0.92, 0.6)
	_steam.color_ramp = _ramp([[0.0, 0.0], [0.08, 1.0], [0.5, 0.5], [1.0, 0.0]])
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 1.1
	_light.light_specular = 0.6
	_light.position = Vector3(0, 0.45, 0)
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 55.0
	_light.distance_fade_shadow = 22.0
	_light.distance_fade_length = 12.0
	_light.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_light.visible = false
	add_child(_light)
	_crackle = CampSfx.loop("fire_loop", self, -80.0, 3.2)
	_crackle.position = Vector3(0, 0.3, 0)
	_apply_quality()
	Settings.changed.connect(_apply_quality)


## Shadows from the fire's light on HIGH (dual-paraboloid) and ULTRA (cube, soft), for
## the nearest burning fire only.
func _apply_quality() -> void:
	var q := Settings.quality
	_light.shadow_enabled = q >= Settings.Quality.HIGH and _owns_shadow()
	_light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE if q == Settings.Quality.ULTRA else OmniLight3D.SHADOW_DUAL_PARABOLOID
	_light.light_size = 0.12 if q == Settings.Quality.ULTRA else 0.0
	_light.shadow_bias = 0.08
	_light.shadow_normal_bias = 1.5


## Snaps the shown values to the targets (a fire loaded as it is, not easing in).
func snap() -> void:
	_heat = heat
	_coals = coals
	_smoke = smoke
	_update(0.0)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(delta / EASE, 0.0, 1.0)
	_heat = move_toward(_heat, heat, maxf(absf(heat - _heat) * k, delta * 0.08))
	_coals = move_toward(_coals, coals, maxf(absf(coals - _coals) * k, delta * 0.08))
	_smoke = move_toward(_smoke, smoke, maxf(absf(smoke - _smoke) * k, delta * 0.05))
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = 0.3
		var cam := get_viewport().get_camera_3d()
		var dist := cam.global_position.distance_to(global_position) if cam else 0.0
		_near = dist < FAR
		_claim_shadow(dist)
	_update(delta)


func _update(delta: float) -> void:
	var flames := _heat > 0.02 and _near
	_flames.emitting = flames
	_core.emitting = flames
	if flames:
		_flames.scale_amount_min = 0.3 * lerpf(0.45, 1.0, _heat)
		_flames.scale_amount_max = 0.52 * lerpf(0.45, 1.0, _heat)
		_flames.initial_velocity_max = lerpf(0.3, 0.6, _heat)
	_flames.set_instance_shader_parameter("heat", clampf(_heat * 1.3, 0.0, 1.0))
	_core.set_instance_shader_parameter("heat", clampf(maxf(_heat, _coals * 0.25), 0.0, 1.0))
	_sparks.emitting = _near and _heat > 0.25
	_smoke_p.emitting = _near and _smoke > 0.03
	var tint := Color(0.86, 0.86, 0.86) if steaming else Color(0.4, 0.39, 0.37)
	_smoke_p.color = Color(tint.r, tint.g, tint.b, clampf(_smoke, 0.0, 1.0) * (0.55 if steaming else 0.62))
	# The wind leans the smoke over.
	var wind := Weather.wind if Weather.wind_override < 0.0 else Weather.wind_override
	_smoke_p.gravity = Vector3(0.55, 0.06, 0.25) * wind * 0.35 + Vector3(0, 0.05, 0)
	# The light: flames and coals, flickering (a quick flutter over a slow breath) and
	# its source wandering a little so the shadows move.
	var energy := _heat * LIGHT_ENERGY + _coals * COAL_ENERGY
	var flicker := 0.84 + 0.1 * sin(_t * 8.7 + sin(_t * 2.3) * 2.0) + 0.06 * sin(_t * 23.1) * sin(_t * 3.7)
	if _heat < 0.05:
		# Coals only breathe slowly.
		flicker = 0.9 + 0.1 * sin(_t * 1.6) * sin(_t * 0.7 + 1.0)
	_light.light_energy = energy * flicker
	_light.visible = energy > 0.01
	_light.omni_range = LIGHT_RANGE * lerpf(0.55, 1.0, clampf(_heat + _coals * 0.2, 0.0, 1.0))
	# Up in the flames' tips, so the bed right under them isn't burnt white.
	_light.position = Vector3(sin(_t * 5.1) * 0.03, 0.8 + sin(_t * 7.7) * 0.03 * _heat, cos(_t * 4.3) * 0.03)
	# Crackling, louder the hotter; embers only tick.
	var level := clampf(_heat + _coals * 0.2, 0.0, 1.0)
	_crackle.volume_db = linear_to_db(maxf(level, 0.0001)) - 3.0
	if level > 0.01 and _near:
		CampSfx.start_loop(_crackle)
	elif _crackle.playing and level <= 0.01:
		_crackle.stop()
	# Now and then a log pops.
	if delta > 0.0 and _near and (_heat > 0.3 or _coals > 0.6):
		_pop_in -= delta * (1.0 if _heat > 0.3 else 0.3)
		if _pop_in <= 0.0:
			_pop_in = randf_range(0.8, 3.2)
			pop()


func _owns_shadow() -> bool:
	return _shadow_owner != null and _shadow_owner.get_ref() == self


## Takes the shadows over from a farther (or cold) fire.
func _claim_shadow(dist: float) -> void:
	var burning := _heat + _coals > 0.05
	var owner: Object = _shadow_owner.get_ref() if _shadow_owner else null
	if owner == self:
		_shadow_dist = dist if burning else INF
	elif burning and (owner == null or dist < _shadow_dist - 1.0):
		_shadow_owner = weakref(self)
		_shadow_dist = dist
	var want := Settings.quality >= Settings.Quality.HIGH and _owns_shadow()
	if _light.shadow_enabled != want:
		_light.shadow_enabled = want


## A log popping: a burst of embers and a crack.
func pop(strength := 1.0) -> void:
	if not _near:
		return
	_pops.amount = maxi(roundi(12 * Fx.detail() * strength), 3)
	_pops.restart()
	CampSfx.play("fire_pop", global_position + Vector3(0, 0.25, 0), -6.0 + 4.0 * (strength - 1.0), 0.15, 3.0)


## Water on the fire: the flames die at once in a cloud of steam; the light goes.
func douse() -> void:
	heat = 0.0
	_heat = 0.0
	coals = 0.0
	steaming = true
	smoke = 0.7
	_smoke = 0.7
	_steam.restart()
	_update(0.0)


## A small hiss of steam (drops of the can landing on the coals).
func hiss() -> void:
	_steam.amount = maxi(roundi(6 * Fx.detail()), 3)
	_steam.restart()


func _emitter(amount: int, lifetime: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.mesh = mesh
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.direction = Vector3.UP
	p.anim_offset_min = 0.0
	p.anim_offset_max = 1.0
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Small clutter: kept out of the rain height map (layer 2).
	p.layers = 2
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(p)
	return p


static func _quad(mat: Material, from_bottom: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	if from_bottom:
		# Tongues rise from the particle's point, taller than wide.
		q.size = Vector2(0.8, 1.35)
		q.center_offset = Vector3(0, 0.675, 0)
	q.material = mat
	return q


static func _curve(points: Array) -> Curve:
	var c := Curve.new()
	c.max_value = 4.0
	for p: Vector2 in points:
		c.add_point(p)
	return c


## White with an alpha ramp: [[offset, alpha]].
static func _ramp(points: Array) -> Gradient:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for p: Array in points:
		offsets.append(float(p[0]))
		colors.append(Color(1, 1, 1, float(p[1])))
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	return g


static func _spark_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.62, 0.25, 1.0), Color(1.0, 0.3, 0.05, 0.85), Color(0.5, 0.06, 0.01, 0.0)])
	return g


static func flame_material() -> ShaderMaterial:
	if _flame_mat == null:
		_flame_mat = ShaderMaterial.new()
		_flame_mat.shader = load("res://shaders/campfire_flame.gdshader")
		_flame_mat.set_shader_parameter("noise_tex", CampfireModel.flame_noise())
	return _flame_mat


static func spark_material() -> ShaderMaterial:
	if _spark_mat == null:
		_spark_mat = ShaderMaterial.new()
		_spark_mat.shader = load("res://shaders/campfire_spark.gdshader")
	return _spark_mat


## Soft lit puffs (the dust puff flipbook): smoke, steam.
static func smoke_material() -> StandardMaterial3D:
	if _smoke_mat == null:
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = load(Fx.DUST_TEX)
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.particles_anim_h_frames = 2
		m.particles_anim_v_frames = 2
		m.particles_anim_loop = false
		m.roughness = 1.0
		m.metallic_specular = 0.0
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 0.35
		m.backlight_enabled = true
		m.backlight = Color(0.3, 0.26, 0.22)
		_smoke_mat = m
	return _smoke_mat
