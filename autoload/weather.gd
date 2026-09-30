extends Node
## Daily weather. Each morning today's weather becomes yesterday's forecast and a
## new forecast is rolled from the season's odds. Rain, storm and snow days get
## precipitation windows; outside them the sky stays overcast. Drives the sky, fog,
## wind, wetness and snow cover, rain/snow particles and lightning, and waters the
## fields while it rains.

signal weather_changed(kind: int)

enum Kind { SUNNY, CLOUDY, RAIN, STORM, SNOW, FOG }

const KEYS := ["WEATHER_SUNNY", "WEATHER_CLOUDY", "WEATHER_RAIN", "WEATHER_STORM", "WEATHER_SNOW", "WEATHER_FOG"]
const ICON_NAMES := ["sunny", "cloudy", "rain", "storm", "snow", "fog"]
## Odds per season (spring, summer, autumn, winter) in the order of Kind.
const ODDS := [
	[45, 25, 25, 5, 0, 0],
	[60, 15, 10, 15, 0, 0],
	[35, 30, 25, 0, 0, 10],
	[25, 25, 0, 0, 40, 10],
]
## Visual targets: [cloud_coverage, overcast, cloud_darkness, fog_boost, wind]
const LOOKS := {
	"sunny": [0.32, 0.0, 0.0, 0.0, 0.8],
	"cloudy": [0.72, 0.35, 0.18, 0.0004, 1.2],
	"damp": [0.82, 0.55, 0.3, 0.0008, 1.3],
	"rain": [0.96, 0.82, 0.5, 0.0016, 1.6],
	"storm": [1.0, 0.92, 0.8, 0.0022, 2.8],
	"snow": [0.96, 0.85, 0.25, 0.0028, 1.0],
	"fog": [0.6, 0.6, 0.1, 0.02, 0.4],
}

var today := Kind.SUNNY
var forecast := Kind.SUNNY
var seed_value := 0
## Precipitation windows for today as [start, end] in GameClock.total_minutes.
var windows: Array = []
var snow_cover := 0.0
var wetness := 0.0
## Debug override (-1 = off).
var forced := -1

var cloud_coverage := 0.32
var overcast := 0.0
var cloud_darkness := 0.0
var fog_boost := 0.0
var wind := 0.8
## Debug: fixed wind strength when >= 0 (flicker measurements).
var wind_override := -1.0
var precip := 0.0
## Rain falling right now, eased (0..1; snow is not rain): drops on the water ring only
## while it falls, however wet the ground still is (shader global rain_amount).
var rain_fall := 0.0
var flash := 0.0
var autumn := 0.0
var leaf_drop := 0.0

var _fx: Node3D
var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _collision: GPUParticlesCollisionHeightField3D
## The camera the rain height map was last rendered around (0 = out of date).
var _blocker_cam := 0
var _lightning: DirectionalLight3D
var _strike_timer := 12.0
var _strike_flashes := 0
## Shader globals as last sent.
var _globals := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# The effects follow the camera from _process: interpolating them between physics
	# ticks would drag them behind (and slide the rain height map mid-render).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	seed_value = randi()
	_build_fx()
	Events.day_started.connect(_on_day_started)
	Events.clock_tick.connect(_on_tick)
	today = Kind.SUNNY
	forecast = roll(2)
	_snap_visuals()


## At `night` a sunny sky reads "Clear" and the moon takes the sun's place in the icon.
func kind_name(kind: int = -1, night := false) -> String:
	var k := today if kind < 0 else kind
	return tr("WEATHER_CLEAR") if night and k == Kind.SUNNY else tr(KEYS[k])


func icon(kind: int = -1, night := false) -> Texture2D:
	var k := today if kind < 0 else kind
	var file: String = ICON_NAMES[k] + ("_night" if night and k in [Kind.SUNNY, Kind.CLOUDY] else "")
	return load("res://art/icons/weather/%s.svg" % file)


func current() -> int:
	return forced if forced >= 0 else today


## Deterministic weather for a given day (the first day is always sunny).
func roll(day: int) -> int:
	if day <= 1:
		return Kind.SUNNY
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value * 7919 + day)
	var odds: Array = ODDS[floori((day - 1) / float(GameClock.DAYS_PER_SEASON)) % 4]
	var total := 0
	for o in odds:
		total += o
	var pick := rng.randi_range(0, total - 1)
	for i in odds.size():
		pick -= odds[i]
		if pick < 0:
			return i
	return Kind.SUNNY


func is_precipitating() -> bool:
	var k := current()
	if k != Kind.RAIN and k != Kind.STORM and k != Kind.SNOW:
		return false
	if forced >= 0:
		return true
	var t := GameClock.total_minutes
	for w in windows:
		if t >= w[0] and t < w[1]:
			return true
	return false


func is_raining() -> bool:
	return is_precipitating() and current() != Kind.SNOW


func _on_day_started(day: int) -> void:
	today = forecast
	forecast = roll(day + 1)
	_make_windows(day)
	weather_changed.emit(today)


func _make_windows(day: int) -> void:
	windows.clear()
	if today != Kind.RAIN and today != Kind.STORM and today != Kind.SNOW:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value * 31 + day)
	var start := GameClock.total_minutes
	var first := start + (0.0 if rng.randf() < 0.35 else rng.randf_range(1.0, 6.0) * 60.0)
	var first_end := first + rng.randf_range(3.0, 8.0) * 60.0
	windows.append([first, first_end])
	if rng.randf() < 0.6:
		var second := first_end + rng.randf_range(1.0, 4.0) * 60.0
		windows.append([second, second + rng.randf_range(2.0, 6.0) * 60.0])


## Minutes of precipitation between two points in time (handles sleeping skips).
func _precip_minutes(from_t: float, to_t: float) -> float:
	var k := current()
	if k != Kind.RAIN and k != Kind.STORM and k != Kind.SNOW:
		return 0.0
	if forced >= 0:
		return to_t - from_t
	var total := 0.0
	for w in windows:
		total += maxf(0.0, minf(to_t, w[1]) - maxf(from_t, w[0]))
	return total


func _on_tick(total_minutes: float, delta_minutes: float) -> void:
	var hours := delta_minutes / 60.0
	var wet_hours := _precip_minutes(total_minutes - delta_minutes, total_minutes) / 60.0
	var dry_hours := hours - wet_hours
	var snowing := current() == Kind.SNOW
	if snowing:
		snow_cover = minf(snow_cover + wet_hours * 0.3, 1.0)
	elif wet_hours > 0.0:
		wetness = minf(wetness + wet_hours * 1.5, 1.0)
		get_tree().call_group(&"fields", &"rain")
	var winter := GameClock.get_season() == GameClock.Season.WINTER
	snow_cover = maxf(snow_cover - dry_hours * (0.015 if winter else 0.12), 0.0)
	wetness = maxf(wetness - dry_hours * 0.3, 0.0)


func _process(delta: float) -> void:
	var k := current()
	var raining_now := is_precipitating()
	var look: Array
	match k:
		Kind.SUNNY:
			look = LOOKS["sunny"]
		Kind.CLOUDY:
			look = LOOKS["cloudy"]
		Kind.FOG:
			look = (LOOKS["fog"] as Array).duplicate()
			# Morning fog burns off in the afternoon.
			look[3] = float(look[3]) * (1.0 - smoothstep(10.0, 15.0, GameClock.get_hour_float()) * 0.8)
		Kind.RAIN:
			look = LOOKS["rain"] if raining_now else LOOKS["damp"]
		Kind.STORM:
			look = LOOKS["storm"] if raining_now else LOOKS["damp"]
		Kind.SNOW:
			look = LOOKS["snow"] if raining_now else LOOKS["cloudy"]
	var rate := clampf(delta * 0.35, 0.0, 1.0)
	cloud_coverage = lerpf(cloud_coverage, look[0], rate)
	overcast = lerpf(overcast, look[1], rate)
	cloud_darkness = lerpf(cloud_darkness, look[2], rate)
	fog_boost = lerpf(fog_boost, look[3], rate)
	wind = lerpf(wind, look[4], rate) if wind_override < 0.0 else wind_override
	precip = lerpf(precip, 1.0 if raining_now else 0.0, clampf(delta * 0.5, 0.0, 1.0))
	var raining := raining_now and k != Kind.SNOW
	rain_fall = move_toward(rain_fall, (1.0 if k == Kind.STORM else 0.75) if raining else 0.0, delta * 0.4)
	_update_season(delta)
	_update_fx(delta, k)
	_set_global(&"wetness", wetness)
	_set_global(&"rain_amount", rain_fall)
	_set_global(&"snow_amount", snow_cover)
	_set_global(&"wind_strength", wind)
	_set_global(&"autumn_amount", autumn)
	_set_global(&"leaf_drop", leaf_drop)


## Sends a shader global only when it changed.
func _set_global(param: StringName, value: float) -> void:
	if not _globals.has(param) or _globals[param] != value:
		_globals[param] = value
		RenderingServer.global_shader_parameter_set(param, value)


## Autumn colors build up over the season; leaves fall late in autumn and stay
## off through winter.
func _update_season(delta: float) -> void:
	var season := GameClock.get_season()
	var progress := (GameClock.get_day_of_season() - 1 + GameClock.get_hour_float() / 24.0) / GameClock.DAYS_PER_SEASON
	var target_autumn := 0.0
	var target_drop := 0.0
	if season == GameClock.Season.AUTUMN:
		target_autumn = smoothstep(0.0, 0.3, progress)
		target_drop = smoothstep(0.55, 1.0, progress) * 0.85
	elif season == GameClock.Season.WINTER:
		target_autumn = 1.0
		target_drop = 0.9
	var rate := clampf(delta * 2.0, 0.0, 1.0)
	autumn = lerpf(autumn, target_autumn, rate)
	leaf_drop = lerpf(leaf_drop, target_drop, rate)


## Jumps visuals straight to their targets (new game, loading, debug).
func _snap_visuals() -> void:
	for i in 60:
		_process(0.5)


# --- Effects -----------------------------------------------------------------------------

func _build_fx() -> void:
	_fx = Node3D.new()
	_fx.name = "WeatherFx"
	add_child(_fx)
	_rain = _make_particles(9000, 1.1, Vector3(24, 0.5, 24), 14.0, Vector2(0.012, 0.55),
			Color(0.72, 0.76, 0.82, 0.32), 17.0, 21.0, false)
	_snow = _make_particles(6000, 7.0, Vector3(22, 3.0, 22), 9.0, Vector2(0.04, 0.04),
			Color(0.97, 0.98, 1.0, 0.9), 0.8, 1.6, true)
	# Roofs and canopies stop the rain: a top-down height map around the camera.
	# Every render of it draws all the geometry in the box, so _update_fx moves it
	# by hand, only while something falls and in coarse steps. Only visual layer 1
	# (ground, buildings, rocks, trees) counts: grass, particles, animals and other
	# small clutter live on layer 2.
	_collision = GPUParticlesCollisionHeightField3D.new()
	_collision.name = "RainBlocker"
	_collision.size = Vector3(64, 60, 64)
	_collision.position.y = 12.0
	_collision.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_collision.heightfield_mask = 1
	_collision.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(_collision)
	# New roofs: render the height map again (next frame, once they are built).
	FarmState.project_built.connect(func(_id: StringName) -> void: _blocker_cam = 0)
	_lightning = DirectionalLight3D.new()
	_lightning.rotation_degrees = Vector3(-60, 30, 0)
	_lightning.light_color = Color(0.82, 0.86, 1.0)
	_lightning.light_energy = 0.0
	_lightning.visible = false
	_fx.add_child(_lightning)


## Re-renders the rain height map, e.g. after a new roof went up.
func refresh_rain_blockers() -> void:
	if _collision:
		RenderingServer.particles_collision_height_field_update(_collision.get_base())


func _make_particles(amount: int, lifetime: float, extents: Vector3, height: float, quad: Vector2,
		color: Color, speed_min: float, speed_max: float, flakes: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 60, 80))
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.collision_base_size = 0.02
	# Simulate every frame: at the default 30 steps/s a drop overshoots a roof by up
	# to a metre before it is caught, and shows under the ceiling.
	p.fixed_fps = 0
	p.interpolate = false
	p.position.y = height
	if not flakes:
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 3.0 if not flakes else 20.0
	pm.initial_velocity_min = speed_min
	pm.initial_velocity_max = speed_max
	pm.gravity = Vector3(0, -9.8 if not flakes else -0.4, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	if flakes:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.4
		pm.turbulence_noise_scale = 4.0
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.15
		pm.scale_min = 0.6
		pm.scale_max = 1.4
	p.process_material = pm
	var mesh := QuadMesh.new()
	mesh.size = quad
	if not flakes:
		# The streak trails above the drop's head, so it vanishes as the head hits.
		mesh.center_offset = Vector3(0, -quad.y * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.roughness = 0.3
	mat.disable_receive_shadows = true
	# Drops right in front of the lens would read as thick white bars.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.6 if flakes else 1.0
	mat.distance_fade_max_distance = 1.8 if flakes else 4.5
	if flakes:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.albedo_texture = _flake_texture()
	mesh.material = mat
	p.draw_pass_1 = mesh
	_fx.add_child(p)
	return p


func _flake_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


func _update_fx(delta: float, k: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		_fx.global_position = cam.global_position
	var snowing := k == Kind.SNOW
	var heavy := 1.0 if k == Kind.STORM else 0.65
	_rain.amount_ratio = precip * heavy if not snowing else 0.0
	_rain.emitting = _rain.amount_ratio > 0.01
	_snow.amount_ratio = precip if snowing else 0.0
	_snow.emitting = _snow.amount_ratio > 0.01
	_update_rain_blockers(cam)
	# Wind slants the rain.
	var pm := _rain.process_material as ParticleProcessMaterial
	var slant := Vector3(0.08 * wind, -1, 0.04 * wind).normalized()
	if not slant.is_equal_approx(pm.direction):
		pm.direction = slant
	# Lightning in storms: a double flash every 8-25 seconds.
	flash = maxf(flash - delta * 6.0, 0.0)
	if k == Kind.STORM and precip > 0.5:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			if _strike_flashes == 0:
				_strike_flashes = 2
				Events.lightning.emit()
			flash = 1.0 if _strike_flashes == 2 else 0.75
			_strike_flashes -= 1
			_strike_timer = 0.12 if _strike_flashes > 0 else randf_range(8.0, 25.0)
	_lightning.visible = flash > 0.01
	_lightning.light_energy = flash * 3.0


## While rain or snow falls (and for the ~8 s tail of precip that covers the last
## flakes' lifetime), keeps the rain height map centred on the camera in 6 m steps:
## from anywhere in a cell the 64 m box still covers the ±24 m emission area plus
## wind drift. Each step re-renders it once; in dry weather it is never re-rendered.
## While driving it steps every metre, so the moving cab and bed keep the rain off.
func _update_rain_blockers(cam: Camera3D) -> void:
	if cam == null or not (precip > 0.0002 or _rain.emitting or _snow.emitting):
		_blocker_cam = 0
		return
	var step := 1.0 if Game.player is Player and (Game.player as Player).driving != null else 6.0
	var c := cam.global_position
	var at := Vector3(snappedf(c.x, step), 12.0, snappedf(c.z, step))
	if _blocker_cam != cam.get_instance_id() or not at.is_equal_approx(_collision.position):
		_blocker_cam = cam.get_instance_id()
		_collision.position = at
		refresh_rain_blockers()


# --- Debug & save ------------------------------------------------------------------------

func force(kind: int) -> void:
	forced = kind
	today = kind if kind >= 0 else today
	_snap_visuals()
	weather_changed.emit(today)


func new_game() -> void:
	load_data({"seed": randi()})
	forecast = roll(2)


func save_data() -> Dictionary:
	return {"today": today, "forecast": forecast, "seed": seed_value, "windows": windows,
		"snow": snow_cover, "wet": wetness}


func load_data(d: Dictionary) -> void:
	today = int(d.get("today", Kind.SUNNY))
	forecast = int(d.get("forecast", Kind.SUNNY))
	seed_value = int(d.get("seed", seed_value))
	windows = d.get("windows", [])
	snow_cover = float(d.get("snow", 0.0))
	wetness = float(d.get("wet", 0.0))
	forced = -1
	_snap_visuals()
	weather_changed.emit(today)
