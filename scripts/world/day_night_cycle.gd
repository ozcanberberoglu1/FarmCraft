@tool
class_name DayNightCycle
extends Node3D
## Owns the sun, moon, sky and environment and updates them from the game clock.
## Weather (phase 4) adjusts the public cloud/overcast/fog values.

## 0 during the day .. 1 at night; lamps read this to switch on.
static var night_factor := 0.0

@export_range(0.0, 24.0, 0.1) var preview_hour := 10.5:
	set(value):
		preview_hour = value
		if Engine.is_editor_hint() and is_inside_tree() and sun:
			_apply(value)

var cloud_coverage := 0.42
var overcast := 0.0
var cloud_darkness := 0.0
var fog_boost := 0.0

## The shadow-casting lights turn in small steps instead of every frame: a light
## that turns a little each frame re-rasterises its shadow map from a slightly new
## angle every frame, which makes every shadow edge and leaf shadow shimmer. A step
## this small is invisible as motion (about 0.6 s of game time at normal speed).
const LIGHT_STEP_DEG := 0.2
## The sky's clock (shader global `sky_time`) wraps like the engine's TIME, so float
## precision holds in long sessions.
const SKY_TIME_WRAP := 3600.0

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var _sun_dir := Vector3.ZERO
var _moon_dir := Vector3.ZERO
var env: Environment
var sky_material: ShaderMaterial
## Sky uniforms as last sent: each change re-renders the sky's radiance map.
var _sky_params := {}


func _ready() -> void:
	_build()
	_apply(_hour())


func _process(_delta: float) -> void:
	# Clouds and stars move with a global rather than TIME: TIME alone would mark the
	# radiance map dirty every frame, although only the on-screen sky uses it.
	RenderingServer.global_shader_parameter_set(&"sky_time", fmod(Time.get_ticks_usec() / 1000000.0, SKY_TIME_WRAP))
	if not Engine.is_editor_hint():
		cloud_coverage = Weather.cloud_coverage
		overcast = Weather.overcast
		cloud_darkness = Weather.cloud_darkness
		fog_boost = Weather.fog_boost
		_set_sky(&"flash", Weather.flash)
	_apply(_hour())


func _hour() -> float:
	if Engine.is_editor_hint():
		return preview_hour
	return GameClock.get_hour_float()


## Direction pointing towards the sun. It rises in the east (+X), culminates in the
## south (+Z) and sets in the west around 19:15.
static func sun_direction(hour: float) -> Vector3:
	var phi := (hour - 6.0) / 24.0 * TAU
	return Vector3(cos(phi), sin(phi) * 0.85 + 0.28, sin(phi) * 0.45).normalized()


static func moon_direction(hour: float) -> Vector3:
	var phi := (hour - 6.0) / 24.0 * TAU
	return Vector3(-cos(phi) * 0.9, -sin(phi) * 0.85 + 0.28, -sin(phi) * 0.4 + 0.25).normalized()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	_sky_params.clear()
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_bounce_feedback = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.4
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.1
	env.fog_aerial_perspective = 0.85
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.002
	env.volumetric_fog_albedo = Color(0.92, 0.94, 1.0)
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_gi_inject = 0.5
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.03
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	# Eye adaptation: interiors and nights brighten gradually, like a real camera.
	var cam_attr := CameraAttributesPractical.new()
	cam_attr.auto_exposure_enabled = true
	cam_attr.auto_exposure_scale = 0.4
	cam_attr.auto_exposure_speed = 1.2
	cam_attr.auto_exposure_min_sensitivity = 100.0
	cam_attr.auto_exposure_max_sensitivity = 420.0
	world_env.camera_attributes = cam_attr
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_blur = 1.0
	sun.light_angular_distance = 0.5
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	# Turned from _process in LIGHT_STEP_DEG steps: interpolating between physics
	# ticks would smear each step over several frames of shadow re-renders.
	sun.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(moon)
	if not Engine.is_editor_hint():
		if not Settings.changed.is_connected(apply_quality):
			Settings.changed.connect(apply_quality)
		apply_quality()


## Graphics preset from the settings: global illumination, screen-space effects,
## volumetric fog and shadow detail.
func apply_quality() -> void:
	if env == null:
		return
	var q: int = Settings.quality
	env.sdfgi_enabled = q >= Settings.Quality.HIGH
	env.ssil_enabled = q >= Settings.Quality.ULTRA
	env.ssao_enabled = q >= Settings.Quality.MEDIUM
	env.volumetric_fog_enabled = q >= Settings.Quality.MEDIUM
	env.glow_enabled = q >= Settings.Quality.LOW
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= Settings.Quality.HIGH \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [60.0, 90.0, 120.0, 120.0][q]
	# Blend between cascades so no resolution seam slides along with the player.
	sun.directional_shadow_blend_splits = q >= Settings.Quality.HIGH
	moon.shadow_enabled = q >= Settings.Quality.MEDIUM
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096, 4096][q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
			[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
			RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][q])


func _apply(hour: float) -> void:
	var sd := sun_direction(hour)
	var md := moon_direction(hour)
	var sun_h := sd.y
	var day := smoothstep(-0.12, 0.2, sun_h)
	night_factor = 1.0 - smoothstep(-0.1, 0.12, sun_h)
	var low_sun := 1.0 - smoothstep(0.05, 0.42, sun_h)

	if _sun_dir == Vector3.ZERO or rad_to_deg(_sun_dir.angle_to(sd)) >= LIGHT_STEP_DEG:
		_sun_dir = sd
		sun.global_transform.basis = Basis.looking_at(-sd, Vector3.UP)
	if _moon_dir == Vector3.ZERO or rad_to_deg(_moon_dir.angle_to(md)) >= LIGHT_STEP_DEG:
		_moon_dir = md
		moon.global_transform.basis = Basis.looking_at(-md, Vector3.UP)
	var dim := 1.0 - overcast * 0.65
	sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.62, 0.38), low_sun)
	sun.light_energy = smoothstep(-0.04, 0.12, sun_h) * 2.3 * dim
	sun.visible = sun.light_energy > 0.005
	moon.light_energy = smoothstep(-0.05, 0.15, md.y) * 0.34 * night_factor * dim
	moon.visible = moon.light_energy > 0.005

	_set_sky(&"sun_dir", sd)
	_set_sky(&"moon_dir", md)
	_set_sky(&"sun_intensity", dim)
	_set_sky(&"cloud_coverage", cloud_coverage)
	_set_sky(&"overcast", overcast)
	_set_sky(&"cloud_darkness", cloud_darkness)

	var fog_color := Color(0.1, 0.12, 0.2).lerp(Color(0.7, 0.78, 0.88), day)
	if not env.fog_light_color.is_equal_approx(fog_color):
		env.fog_light_color = fog_color
	_set_env(&"fog_density", lerpf(0.0009, 0.0014, night_factor) + fog_boost)
	_set_env(&"volumetric_fog_density", 0.001 + fog_boost * 4.0 + low_sun * day * 0.001)
	_set_env(&"ambient_light_energy", lerpf(1.6, 1.0, day))
	_set_env(&"tonemap_exposure", lerpf(1.3, 1.0, day))
	_set_env(&"adjustment_saturation", lerpf(0.7, 1.05, day))


## Sends a sky uniform only when it changed.
func _set_sky(param: StringName, value: Variant) -> void:
	if not _sky_params.has(param) or _sky_params[param] != value:
		_sky_params[param] = value
		sky_material.set_shader_parameter(param, value)


## Each Environment setter re-sends its whole block to the renderer: skip values
## that did not change.
func _set_env(property: StringName, value: float) -> void:
	if not is_equal_approx(float(env.get(property)), value):
		env.set(property, value)
