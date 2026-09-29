@tool
class_name DayNightCycle
extends Node3D
## Owns the sun, moon, sky and environment and updates them from the game clock.
## Weather (phase 4) adjusts the public cloud/overcast/fog values.
##
## The light follows a simple physical model so every hour reads like a photograph:
## sunlight is dimmed and reddened by the air it crosses (sunlight()), the sky dims
## with the sun (shaders/sky.gdshader), and haze (fog tinted by the sky behind it)
## thickens with distance, in the morning and in bad weather. AgX tone mapping rolls
## bright greens and skies off towards white instead of clipping them to lime and cyan.

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
## Sun energy with the sun overhead in a clear sky.
const SUN_ENERGY := 3.0
## Optical depth of the air per air mass for red, green and blue light (Rayleigh
## scattering plus a little haze): blue is lost first, so a low sun turns orange.
const EXTINCTION := Vector3(0.03, 0.05, 0.1)
## Grey haze (aerosols) per air mass: dims a low sun without colouring it further.
const HAZE_EXTINCTION := 0.035
## Haze as an extinction coefficient (1/m): a clear day sees about 7 km, the morning
## haze and the weather (Weather.fog_boost) add to it. It is drawn as depth fog that
## stays faint across the valley and thickens towards the visibility distance, like
## real aerial perspective.
const HAZE_CLEAR := 0.00035
const HAZE_MORNING := 0.0006
const HAZE_NIGHT := 0.0007
## Fog amount = (clamp(distance / (visibility * HAZE_REACH), 0, 1) ^ HAZE_CURVE): at
## noon about 4% across the farmyard, a third at 2 km and two thirds on the far ridges.
const HAZE_REACH := 1.4
const HAZE_CURVE := 0.7
## The real sun's size in degrees: shadows sharp at contact, softening with distance.
const SUN_SIZE := 0.53
## Under a full cloud deck the little direct light left comes from a bright patch of
## cloud rather than a disc: this many degrees wide (soft shadow presets only).
const SUN_SIZE_OVERCAST := 4.0
## Environment values that change every frame are sent only when they move by more
## than this fraction (each setter re-sends a whole block to the renderer).
const ENV_STEP := 0.005
## Night grade (a lookup per colour channel after tone mapping): moonlit scenes read
## blue, as the eye and film see them, rather than grey-green. It follows night_factor
## in this many steps; by day the lookup is the identity.
const GRADE_STEPS := 16
## Textures of the sky shader, baked by tools/bake_sky.py (atmosphere LUTs, cloud noise
## and weather map) and from NASA's LRO map of the Moon.
const SKY_TEXTURES := {
	&"transmittance_lut": "res://art/sky/transmittance.exr",
	&"multiscatter_lut": "res://art/sky/multiscatter.exr",
	&"sky_irradiance_lut": "res://art/sky/sky_irradiance.exr",
	&"cloud_shape": "res://art/sky/cloud_shape.png",
	&"cloud_detail": "res://art/sky/cloud_detail.png",
	&"cloud_weather": "res://art/sky/cloud_weather.png",
	&"blue_noise": "res://art/sky/blue_noise.png",
	&"moon_albedo": "res://art/sky/moon.png",
}
## Sky clouds per graphics preset (LOW .. ULTRA): 0 flat 2D clouds, 1 volumetric,
## 2 volumetric with finer steps, more light samples and eroded detail.
const CLOUD_QUALITY: Array[int] = [0, 0, 1, 2]
## Days from one full moon to the next. The game's moon rides opposite the sun all
## night, so it only wanes to a half moon and back.
const MOON_CYCLE := 8.0

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var _sun_dir := Vector3.ZERO
var _moon_dir := Vector3.ZERO
## Sunlight colour (rgb) and strength (a) at the sun's current step.
var _light := Color(1, 1, 1, 1)
## The sun's size for the current graphics preset (0 = hard shadows).
var _sun_size := SUN_SIZE
## Whether the graphics preset gives the moon shadows.
var _moon_shadows := true
var env: Environment
var sky: Sky
var sky_material: ShaderMaterial
## Sky uniforms as last sent: each change re-renders the sky's radiance map.
var _sky_params := {}
var _grade_image: Image
var _grade_texture: ImageTexture
var _grade_step := -1


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


## Direct sunlight for a sun at height `sin_h` (sine of its elevation): rgb is its
## colour (brightest channel 1), a its strength relative to an overhead sun. The path
## through the air (Kasten-Young air mass) grows ~38x towards the horizon.
static func sunlight(sin_h: float) -> Color:
	var h := maxf(rad_to_deg(asin(clampf(sin_h, -1.0, 1.0))), 0.0)
	var mass := 1.0 / (sin(deg_to_rad(h)) + 0.50572 * pow(h + 6.07995, -1.6364))
	var t := Vector3(exp(-mass * EXTINCTION.x), exp(-mass * EXTINCTION.y), exp(-mass * EXTINCTION.z))
	var peak := maxf(t.x, maxf(t.y, t.z))
	var lum := (t.x * 0.2126 + t.y * 0.7152 + t.z * 0.0722) * exp(-mass * HAZE_EXTINCTION)
	var zenith := (exp(-EXTINCTION.x) * 0.2126 + exp(-EXTINCTION.y) * 0.7152 + exp(-EXTINCTION.z) * 0.0722) * exp(-HAZE_EXTINCTION)
	return Color(t.x / peak, t.y / peak, t.z / peak, lum / zenith)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_sun_dir = Vector3.ZERO
	_moon_dir = Vector3.ZERO
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	for param: StringName in SKY_TEXTURES:
		sky_material.set_shader_parameter(param, load(SKY_TEXTURES[param]))
	_sky_params.clear()
	sky = Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX: a film-like response that desaturates towards white in the highlights, so a
	# sunlit meadow stays green and the sky near the sun stays sky, not cyan.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_agx_white = 6.5
	# A gentle toe: shaded wood and foliage under a low sun keep their colour.
	env.tonemap_agx_contrast = 1.2
	env.tonemap_exposure = 1.0
	# Contact shading: tight enough to darken the ground right under a wheel or a
	# post, wide enough to seat a building; a little of it reaches sunlit surfaces.
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.7
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.12
	env.ssao_ao_channel_affect = 0.2
	env.ssil_enabled = true
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_bounce_feedback = 0.45
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.015
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Haze: depth fog whose colour is the sky behind it (aerial perspective), with the
	# sun glowing through it. Its reach follows the hour and the weather (_apply).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_begin = 0.0
	env.fog_depth_curve = HAZE_CURVE
	env.fog_depth_end = 2.5 / HAZE_CLEAR * HAZE_REACH
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.92
	env.fog_sun_scatter = 0.06
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0005
	env.volumetric_fog_albedo = Color(0.92, 0.94, 1.0)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_gi_inject = 0.5
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.0
	_grade_image = Image.create(256, 1, false, Image.FORMAT_RGBF)
	_grade_step = -1
	_update_grade(0.0)
	env.adjustment_color_correction = _grade_texture
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
	# Most of the shadow map's detail goes to the first metres, where contact shadows
	# under boots, wheels and posts are judged.
	sun.directional_shadow_split_1 = 0.07
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.42
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.shadow_blur = 1.0
	sun.light_angular_distance = SUN_SIZE
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	# Turned from _process in LIGHT_STEP_DEG steps: interpolating between physics
	# ticks would smear each step over several frames of shadow re-renders.
	sun.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.42, 0.56, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.shadow_blur = 1.5
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(moon)
	if not Engine.is_editor_hint():
		if not Settings.changed.is_connected(apply_quality):
			Settings.changed.connect(apply_quality)
		apply_quality()


## Graphics preset from the settings: global illumination, screen-space effects,
## volumetric fog, shadow detail and the sky's clouds.
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
	# With two splits the first one covers the first 9-14 m.
	sun.directional_shadow_split_1 = 0.07 if q >= Settings.Quality.HIGH else 0.15
	# Blend between cascades so no resolution seam slides along with the player.
	sun.directional_shadow_blend_splits = q >= Settings.Quality.HIGH
	# Soft shadows from the sun's size need the soft filter (MEDIUM and up).
	_sun_size = SUN_SIZE if q >= Settings.Quality.MEDIUM else 0.0
	sun.light_angular_distance = _sun_size
	_moon_shadows = q >= Settings.Quality.MEDIUM
	moon.shadow_enabled = _moon_shadows and not sun.visible
	# Volumetric clouds on HIGH and ULTRA; ULTRA also sharpens the sky in reflections.
	_set_sky(&"cloud_quality", CLOUD_QUALITY[q])
	var radiance := Sky.RADIANCE_SIZE_256 if q >= Settings.Quality.ULTRA else Sky.RADIANCE_SIZE_128
	if sky.radiance_size != radiance:
		sky.radiance_size = radiance
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
	# Morning haze from dawn until mid-morning; a lighter one in the evening.
	var morning := smoothstep(4.3, 5.8, hour) * (1.0 - smoothstep(7.5, 10.0, hour))
	var evening := smoothstep(17.0, 18.8, hour) * (1.0 - smoothstep(19.8, 21.0, hour))

	# The sky follows the lights' steps too: every change re-renders its radiance map.
	if _sun_dir == Vector3.ZERO or rad_to_deg(_sun_dir.angle_to(sd)) >= LIGHT_STEP_DEG:
		_sun_dir = sd
		sun.global_transform.basis = Basis.looking_at(-sd, Vector3.UP)
		_light = sunlight(sd.y)
		sun.light_color = Color(_light.r, _light.g, _light.b)
		_set_sky(&"sun_dir", sd)
		_set_sky(&"sun_color", Vector3(_light.r, _light.g, _light.b))
		_set_sky(&"sun_strength", _light.a)
	if _moon_dir == Vector3.ZERO or rad_to_deg(_moon_dir.angle_to(md)) >= LIGHT_STEP_DEG:
		_moon_dir = md
		moon.global_transform.basis = Basis.looking_at(-md, Vector3.UP)
		_set_sky(&"moon_dir", md)
	# Clouds take the direct sun away; the sky (ambient) stays and turns grey. Under a
	# rain deck only a trace of it is left, from a bright patch of cloud: faint, very
	# soft shadows.
	var cloud_cover := smoothstep(0.15, 0.85, overcast)
	var dim := 1.0 - cloud_cover * 0.93
	var thick_fog := clampf(fog_boost / 0.01, 0.0, 1.0)
	_set_light(sun, &"light_energy", SUN_ENERGY * _light.a * smoothstep(-0.012, 0.03, sun_h) * dim)
	_set_light(sun, &"shadow_opacity", lerpf(1.0, 0.25, smoothstep(0.3, 0.9, overcast)))
	if _sun_size > 0.0:
		_set_light(sun, &"light_angular_distance", lerpf(_sun_size, SUN_SIZE_OVERCAST, cloud_cover))
	var sun_up := sun.light_energy > 0.005
	if sun.visible != sun_up:
		sun.visible = sun_up
		# One shadowed directional light at a time: at dusk and dawn both are up, and
		# a second shadow map would halve the sun's share of the shadow atlas.
		moon.shadow_enabled = _moon_shadows and not sun_up
	_set_light(moon, &"light_energy", smoothstep(-0.05, 0.15, md.y) * 0.3 * night_factor * (1.0 - overcast * 0.7))
	moon.visible = moon.light_energy > 0.005

	_set_sky(&"sun_intensity", dim)
	_set_sky(&"moon_phase", moon_phase(1 if Engine.is_editor_hint() else GameClock.day))
	_set_sky(&"cloud_coverage", cloud_coverage)
	_set_sky(&"overcast", overcast)
	_set_sky(&"cloud_darkness", cloud_darkness)

	# Fog colour under the sky tint: pale blue by day, warm with a low sun, deep blue
	# at night, grey under cloud.
	var fog_color := Color(0.05, 0.07, 0.13).lerp(Color(0.66, 0.74, 0.84), day)
	fog_color = fog_color.lerp(Color(0.85, 0.66, 0.5), low_sun * day * 0.5)
	fog_color = fog_color.lerp(Color(0.55, 0.57, 0.6) * lerpf(0.15, 1.0, day), overcast * 0.7)
	# A fog bank is lit through and through: bright, nearly white by day.
	fog_color = fog_color.lerp(Color(0.86, 0.88, 0.9) * lerpf(0.08, 1.0, day), thick_fog)
	if not env.fog_light_color.is_equal_approx(fog_color):
		env.fog_light_color = fog_color
	var haze := lerpf(HAZE_NIGHT, HAZE_CLEAR, day) + HAZE_MORNING * morning + HAZE_CLEAR * 0.5 * evening
	_set_env(&"fog_depth_end", 2.5 / (haze + fog_boost) * HAZE_REACH)
	# In a fog bank sky and land alike fade to the fog's own colour, so no far ridge
	# shows through as a line.
	_set_env(&"fog_aerial_perspective", lerpf(0.92, 0.0, thick_fog))
	# Thick weather fog swallows the sky too, and the fog bank is lit mostly by the
	# sky around it, so far hills do not show through as dark silhouettes.
	_set_env(&"fog_sky_affect", clampf(fog_boost * 50.0, 0.0, 1.0))
	_set_env(&"volumetric_fog_sky_affect", thick_fog)
	_set_env(&"volumetric_fog_ambient_inject", lerpf(0.0, 0.7, thick_fog))
	# The sun glows through the haze when it is low, without washing out what stands
	# in front of it.
	_set_env(&"fog_sun_scatter", minf(0.04 + 0.12 * low_sun + 0.05 * morning, 0.2) * dim)
	# Volumetric fog only carries light shafts (the distance fog does the haze): thin by
	# day, a little thicker in the morning mist.
	_set_env(&"volumetric_fog_density", 0.0005 + morning * 0.0012 + evening * 0.0006 + night_factor * 0.0006 + fog_boost * 2.0)
	# By day the sun outshines the sky about four to one, as in a photograph; a low,
	# weak sun leaves more of the lighting to the sky. SDFGI (HIGH and up) takes the
	# sky's light at its own energy, so by day it follows, or shaded walls fall far
	# darker than on the presets without it. At night it stays near 1: it would also
	# multiply the lamps' bounce light, which with the moonlit sky tints shade purple.
	var ambient := lerpf(2.4, 0.95, day) + 0.6 * low_sun * day
	_set_env(&"ambient_light_energy", ambient)
	_set_env(&"sdfgi_energy", lerpf(1.1, ambient, day))
	# Storm light is dim and heavy.
	_set_env(&"tonemap_exposure", lerpf(1.35, 1.18, day) * (1.0 - cloud_darkness * 0.12 * day))
	_update_grade(night_factor * (1.0 - overcast * 0.4))
	# Night vision loses some colour; a low sun warms and deepens it. By day AgX alone
	# rolls bright colours off, with no grade on top.
	_set_env(&"adjustment_saturation", (lerpf(0.65, 1.0, day) + low_sun * day * 0.08) * (1.0 - overcast * 0.12))


## The moon's phase angle on `day` (radians between the moon and the sunlight on it,
## PI = full moon): full on day 1, a half moon half a cycle later.
static func moon_phase(day: int) -> float:
	return lerpf(PI, PI * 0.5, 0.5 - 0.5 * cos(TAU * float(day - 1) / MOON_CYCLE))


## Rebuilds the night grade for night weight `w` (0..1) when it moves a step: red a
## little down, blue lifted in the darks.
func _update_grade(w: float) -> void:
	var step := roundi(clampf(w, 0.0, 1.0) * GRADE_STEPS)
	if step == _grade_step:
		return
	_grade_step = step
	var k := float(step) / GRADE_STEPS
	for i in 256:
		# Texel i is sampled at its centre: store the curve's value there.
		var v := (i + 0.5) / 256.0
		_grade_image.set_pixel(i, 0, Color(v * (1.0 - 0.1 * k), v * (1.0 - 0.04 * k),
				minf(v + k * 0.06 * (1.0 - v) * (1.0 - v), 1.0)))
	if _grade_texture == null:
		_grade_texture = ImageTexture.create_from_image(_grade_image)
	else:
		_grade_texture.update(_grade_image)


## Sends a sky uniform only when it changed.
func _set_sky(param: StringName, value: Variant) -> void:
	if not _sky_params.has(param) or _sky_params[param] != value:
		_sky_params[param] = value
		sky_material.set_shader_parameter(param, value)


## Each Environment setter re-sends its whole block to the renderer: skip changes
## smaller than ENV_STEP of the value, which do not show.
func _set_env(property: StringName, value: float) -> void:
	var old := float(env.get(property))
	if absf(value - old) > maxf(absf(old), absf(value)) * ENV_STEP or (value != old and is_zero_approx(value)):
		env.set(property, value)


## Sets a light property only when it changed.
func _set_light(light: Light3D, property: StringName, value: float) -> void:
	if not is_equal_approx(float(light.get(property)), value):
		light.set(property, value)
