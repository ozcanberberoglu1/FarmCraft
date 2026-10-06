class_name Fx
extends RefCounted
## One-shot effects for farming and resource work. Tool strikes fire theirs on the impact
## frame (see ToolAnim and the targets' use_impact), thrown the way the blow goes.
## Solid bits (bark chips, splinters, rock fragments, soil clods, leaves, stalks, seeds)
## are real little lit meshes that tumble, bounce and settle on the ground (FxDebris);
## dust is soft, lit puffs; water is clear glinting drops that leave wet patches on the
## ground. Finished particle emitters stay in the world and are reused by the next burst
## of the same look. How much of it there is follows the graphics preset (detail()).

## Finished emitters kept for reuse per look.
const POOL_SIZE := 4
const SOIL := Color(0.27, 0.19, 0.12)
const DUST := Color(0.5, 0.42, 0.33, 0.28)
const WATER := Color(0.75, 0.88, 1.0, 0.85)
## Photo tints of the thrown bits (0.5 grey = the photo as-is).
const SOIL_TINTS: Array[Color] = [Color(0.44, 0.42, 0.4), Color(0.38, 0.36, 0.34), Color(0.52, 0.48, 0.44)]
const ROCK_TINT := Color(0.54, 0.5, 0.46)
const DUST_TEX := "res://art/textures/fx/dust_puff.png"
const WET_TEX := "res://art/textures/fx/wet_spot.png"
const WET_ORM_TEX := "res://art/textures/fx/wet_spot_orm.png"

static var _mats: Dictionary = {}
## Particle meshes per look.
static var _meshes: Dictionary = {}
## Finished emitters per look, waiting for their next burst.
static var _pool: Dictionary = {}
## Sparks shrink away; dust puffs swell as they drift.
static var _shrink: Curve
static var _swell: Curve
static var _fade: Gradient
static var _debris_node: FxDebris
static var _dust_mat: StandardMaterial3D
static var _drop_mat: ShaderMaterial
## Wet patches on the ground, oldest first (reused when there are enough).
static var _spots: Array[Decal] = []
## Set while warm_up runs: every burst is one still particle, so nothing sprays in front
## of the player while the loading veil fades out.
static var _warming := false


## How much of each effect the graphics preset affords (bits per burst): LOW is light
## on a laptop, ULTRA throws the most and lets it lie longest.
static func detail() -> float:
	match Settings.quality:
		Settings.Quality.LOW:
			return 0.45
		Settings.Quality.MEDIUM:
			return 0.7
		Settings.Quality.HIGH:
			return 1.0
	return 1.35


## Shows one tiny burst of every look at `at`, so their shaders are compiled and their
## emitters made while the loading screen is up instead of on the first hoe stroke, axe
## blow or watering.
static func warm_up(at: Vector3) -> void:
	_warming = true
	_burst(at, Color(0.34, 0.24, 0.15), 1, Vector3.ZERO, 0.0, 0.1, 0.0, 0.035)
	egg_splat(at)
	_puff(at, DUST, 1, Vector3.ZERO, 0.0, 0.1, Vector2(0.01, 0.01))
	_drops(at, 1, Vector3.ZERO, 0.0, 0.1, Vector3.UP, 0.0, 0.004)
	var d := _debris()
	if d:
		for look: StringName in [&"wood_oak", &"wood_pine", &"splinter", &"rock", &"clod", &"crumb", &"leaf", &"blade", &"seed"]:
			d.throw({"look": look, "count": 1, "at": at, "size": Vector2(0.001, 0.001), "speed": Vector2.ZERO,
					"life": Vector2(0.15, 0.15)})
		TreeNotch.warm_up(Game.world, at)
		ChoppableTree.warm_up(Game.world, at)
		# What a felled tree drops when its trunk lands: the logs and, now and then, a
		# sapling. (The first ones took over a second to build and draw.)
		for id: StringName in [&"wood", SaplingGrove.ITEM]:
			if ItemDB.has_item(id):
				warm_pickup(id, at)
	_warming = false


## Builds an item's pickup model and draws it for a moment, tiny and moving as a thrown
## pickup does, so that its mesh, materials and pipelines are ready before the first one
## drops in the middle of the game.
static func warm_pickup(id: StringName, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ItemModels.mesh(id)
	# As Pickup draws it.
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.layers = 2
	Game.world.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * 0.01
	var tw := mi.create_tween()
	tw.tween_property(mi, "position:y", mi.position.y + 0.05, 0.5)
	tw.tween_callback(mi.queue_free)


# --- Axe, pick, hoe, scythe ----------------------------------------------------------

## Chips and bark flakes flying off a trunk toward `out` (the side the axe hit), with a
## few long splinters and a little sawdust. `pine` picks the pine's bark.
static func wood_chips(at: Vector3, out := Vector3.UP, pine := false) -> void:
	var d := _debris()
	if d == null:
		return
	var dir := (out.normalized() + Vector3.UP * 0.5).normalized()
	var life := _linger()
	d.throw({"look": &"wood_pine" if pine else &"wood_oak", "count": _n(6), "at": at, "box": Vector3.ONE * 0.03,
			"dir": dir, "cone": 42.0, "speed": Vector2(1.6, 3.8), "size": Vector2(0.022, 0.045), "spin": 18.0,
			"life": life, "collide": true})
	d.throw({"look": &"splinter", "count": _n(6), "at": at, "box": Vector3.ONE * 0.03, "dir": dir, "cone": 35.0,
			"speed": Vector2(2.0, 4.2), "size": Vector2(0.035, 0.08), "spin": 22.0, "life": life, "collide": true,
			"colors": [Color(0.5, 0.5, 0.5), Color(0.55, 0.53, 0.5), Color(0.46, 0.44, 0.42)]})
	d.throw({"look": &"seed", "count": _n(10), "at": at, "box": Vector3.ONE * 0.04, "dir": dir, "cone": 60.0,
			"speed": Vector2(0.8, 2.4), "size": Vector2(0.003, 0.007), "shape": Vector3(1.0, 0.4, 0.8),
			"life": life * 0.6, "colors": _lin([Color(0.86, 0.74, 0.55), Color(0.8, 0.66, 0.46)])})
	_puff(at, Color(0.62, 0.52, 0.4, 0.22), _n(2), Vector3.ONE * 0.03, 0.4, 0.8, Vector2(0.08, 0.16), dir, 0.2)


## Rock fragments knocked off where the pick struck, flying toward `out`, a little grit
## and a puff of rock dust. `tint` matches the rock (0.5 grey = the photo as-is).
static func stone_chips(at: Vector3, out := Vector3.UP, tint := ROCK_TINT) -> void:
	var d := _debris()
	if d == null:
		return
	var dir := (out.normalized() + Vector3.UP * 0.6).normalized()
	var life := _linger()
	var tints := [tint, tint.darkened(0.15), tint.lightened(0.1)]
	d.throw({"look": &"rock", "count": _n(6), "at": at, "box": Vector3.ONE * 0.03, "dir": dir, "cone": 55.0,
			"speed": Vector2(1.4, 3.2), "size": Vector2(0.022, 0.06), "shape": Vector3(1.0, 0.65, 0.85),
			"shape_jitter": 0.35, "spin": 16.0, "colors": tints, "life": life, "collide": true})
	d.throw({"look": &"rock", "count": _n(5), "at": at, "box": Vector3.ONE * 0.03, "dir": dir, "cone": 65.0,
			"speed": Vector2(1.0, 3.0), "size": Vector2(0.004, 0.01), "spin": 20.0, "colors": tints, "life": life * 0.7,
			"collide": true})
	var dust := Color(tint.r * 1.15, tint.g * 1.15, tint.b * 1.15, 0.3)
	_puff(at, dust, _n(2), Vector3.ONE * 0.04, 0.45, 1.0, Vector2(0.12, 0.26), dir, 0.2)


## A boulder bursting apart: chunks thrown all round from `at`, and grit.
static func rock_burst(at: Vector3, size: float, tint := ROCK_TINT) -> void:
	var d := _debris()
	if d == null:
		return
	var life := _linger()
	var tints := [tint, tint.darkened(0.15), tint.lightened(0.1)]
	d.throw({"look": &"rock", "count": _n(8 + 6 * size), "at": at, "box": Vector3(0.3, 0.2, 0.3) * size,
			"dir": Vector3.UP, "cone": 75.0, "speed": Vector2(1.5, 3.6), "size": Vector2(0.03, 0.08) * clampf(size, 0.6, 1.4),
			"shape": Vector3(1.0, 0.7, 0.85), "shape_jitter": 0.35, "spin": 12.0, "colors": tints, "life": life})
	d.throw({"look": &"rock", "count": _n(12), "at": at, "box": Vector3(0.3, 0.2, 0.3) * size, "dir": Vector3.UP,
			"cone": 80.0, "speed": Vector2(1.0, 3.0), "size": Vector2(0.006, 0.016), "spin": 18.0, "colors": tints,
			"life": life * 0.7})


## Clods thrown up and back (`back`: toward the player) where a blade bites the soil,
## crumbs and a low puff of dust. `ground`: the soil's height (else the terrain's).
static func dirt_clods(at: Vector3, back: Vector3, size := 1.0, ground := NAN) -> void:
	var d := _debris()
	if d == null:
		return
	var dir := (Vector3.UP * 1.4 + back).normalized()
	var life := _linger()
	var spec := {"look": &"clod", "count": _n(7 * size), "at": at, "box": Vector3(0.1, 0.02, 0.1) * size, "dir": dir,
			"cone": 35.0, "speed": Vector2(1.2, 2.6), "size": Vector2(0.02, 0.05), "shape": Vector3(1.0, 0.75, 0.9),
			"colors": SOIL_TINTS, "spin": 10.0, "life": life}
	if not is_nan(ground):
		spec["floor"] = ground
	d.throw(spec)
	d.throw(_with(spec, {"look": &"crumb", "count": _n(12 * size), "cone": 50.0, "speed": Vector2(0.8, 2.2),
			"size": Vector2(0.004, 0.011), "box": Vector3(0.14, 0.02, 0.14) * size, "life": life * 0.7}))
	_puff(at, DUST, _n(1.5 * size), Vector3(0.12, 0.02, 0.12) * size, 0.35, 1.1, Vector2(0.18, 0.35), Vector3.UP, 0.1)


## Loose soil kicked up over an area (`size` about its half width in metres): crumbs
## and dust.
static func dirt_burst(at: Vector3, size := 1.0, ground := NAN) -> void:
	var d := _debris()
	if d == null:
		return
	var spec := {"look": &"crumb", "count": _n(16 * size), "at": at, "box": Vector3(0.5, 0.02, 0.5) * size,
			"dir": Vector3.UP, "cone": 50.0, "speed": Vector2(0.8, 2.0), "size": Vector2(0.005, 0.014),
			"colors": SOIL_TINTS, "life": _linger() * 0.7}
	if not is_nan(ground):
		spec["floor"] = ground
	d.throw(spec)
	_puff(at, DUST, _n(2 * size), Vector3(0.45, 0.03, 0.45) * size, 0.3, 1.3, Vector2(0.25, 0.5), Vector3.UP, 0.08)


## Grass clippings flung along the scythe's sweep (`sweep`: world direction). `color`
## as seen (sRGB); `ground`: where they come down (else the terrain).
static func clippings(at: Vector3, sweep: Vector3, color := Color(0.36, 0.52, 0.2), ground := NAN) -> void:
	var d := _debris()
	if d == null:
		return
	var dir := (sweep.normalized() + Vector3.UP * 0.7).normalized()
	var spec := {"look": &"blade", "count": _n(22), "at": at, "box": Vector3(0.35, 0.12, 0.35), "dir": dir, "cone": 30.0,
			"speed": Vector2(1.5, 3.2), "size": Vector2(0.035, 0.09), "shape": Vector3(1.0, 1.0, 0.7), "spin": 9.0,
			"colors": _lin([color, color.darkened(0.15), color.lightened(0.1), color.lerp(Color(0.6, 0.55, 0.3), 0.3)]),
			"life": _linger()}
	if not is_nan(ground):
		spec["floor"] = ground
	d.throw(spec)


## A crop taken off its bed (`ground`: the soil's height): leaves and bits of stalk, or
## straw and chaff for wheat, and a few crumbs of soil.
static func leaf_burst(at: Vector3, crop: StringName, ground := NAN) -> void:
	var d := _debris()
	if d == null:
		return
	var life := _linger()
	var spec := {"at": at, "box": Vector3(0.45, 0.15, 0.45), "dir": Vector3.UP, "cone": 55.0, "life": life}
	if not is_nan(ground):
		spec["floor"] = ground
	if crop == &"wheat":
		var straw := [Color(0.84, 0.72, 0.42), Color(0.78, 0.64, 0.36), Color(0.9, 0.8, 0.52), Color(0.72, 0.6, 0.34)]
		d.throw(_with(spec, {"look": &"blade", "count": _n(18), "speed": Vector2(1.4, 3.0), "size": Vector2(0.05, 0.11),
				"shape": Vector3(1.0, 1.0, 0.55), "spin": 10.0, "colors": _lin(straw)}))
		d.throw(_with(spec, {"look": &"seed", "count": _n(14), "speed": Vector2(1.0, 2.6), "size": Vector2(0.003, 0.006),
				"shape": Vector3(1.0, 0.5, 0.6), "colors": _lin([Color(0.88, 0.8, 0.56), Color(0.8, 0.68, 0.42)])}))
	else:
		var greens := [Color(0.26, 0.36, 0.13), Color(0.22, 0.32, 0.11), Color(0.3, 0.4, 0.16), Color(0.36, 0.42, 0.18)]
		d.throw(_with(spec, {"look": &"leaf", "count": _n(14), "speed": Vector2(1.2, 2.6), "size": Vector2(0.05, 0.1),
				"spin": 7.0, "colors": _lin(greens)}))
		d.throw(_with(spec, {"look": &"blade", "count": _n(6), "speed": Vector2(1.2, 2.4), "size": Vector2(0.04, 0.08),
				"shape": Vector3(1.0, 1.0, 0.6), "spin": 8.0, "colors": _lin([Color(0.42, 0.52, 0.24), Color(0.5, 0.56, 0.3)])}))
	d.throw(_with(spec, {"look": &"crumb", "count": _n(8), "box": Vector3(0.3, 0.05, 0.3), "speed": Vector2(0.8, 1.8),
			"size": Vector2(0.005, 0.012), "colors": SOIL_TINTS, "life": life * 0.7}))
	var dust_at := Vector3(at.x, ground + 0.05, at.z) if not is_nan(ground) else at
	_puff(dust_at, DUST, _n(1.5), Vector3(0.3, 0.02, 0.3), 0.3, 1.1, Vector2(0.2, 0.4), Vector3.UP, 0.1)


## Needles or leaves shaken loose from a crown (half extents in metres) drifting down.
static func leaves(at: Vector3, half: Vector2, needles: bool) -> void:
	var d := _debris()
	if d == null:
		return
	var spec := {"at": at, "box": Vector3(half.x, 0.4, half.y), "dir": Vector3.DOWN, "cone": 60.0,
			"speed": Vector2(0.0, 0.4), "life": Vector2(6.0, 9.0) + _linger()}
	if needles:
		d.throw(_with(spec, {"look": &"blade", "count": _n(10), "size": Vector2(0.018, 0.032),
				"shape": Vector3(1.0, 1.0, 0.3), "spin": 6.0, "colors": _lin(_needle_colors())}))
	else:
		d.throw(_with(spec, {"look": &"leaf", "count": _n(8), "size": Vector2(0.05, 0.09), "spin": 5.0,
				"colors": _lin(_leaf_colors())}))


## A felled crown striking the ground at `at` (half extents in metres): leaves or
## needles burst up and drift back down, with a few snapped twigs.
static func crown_crash(at: Vector3, half: Vector2, needles: bool) -> void:
	var d := _debris()
	if d == null:
		return
	var spec := {"at": at, "box": Vector3(half.x, 0.3, half.y), "dir": Vector3.UP, "cone": 50.0,
			"speed": Vector2(1.0, 3.0), "life": Vector2(4.0, 6.0) + _linger()}
	if needles:
		d.throw(_with(spec, {"look": &"blade", "count": _n(30), "size": Vector2(0.018, 0.035),
				"shape": Vector3(1.0, 1.0, 0.3), "spin": 8.0, "colors": _lin(_needle_colors())}))
	else:
		d.throw(_with(spec, {"look": &"leaf", "count": _n(30), "size": Vector2(0.05, 0.09), "spin": 7.0,
				"colors": _lin(_leaf_colors())}))
	d.throw(_with(spec, {"look": &"splinter", "count": _n(8), "size": Vector2(0.08, 0.2), "spin": 8.0,
			"life": _linger() + Vector2(1.0, 1.0), "colors": [Color(0.3, 0.26, 0.22), Color(0.36, 0.3, 0.24)]}))


## Seeds thrown from `from` in an arc that lands on `to` after `flight` seconds, where
## they settle on the soil for a moment.
static func seed_scatter(from: Vector3, to: Vector3, flight: float, color: Color) -> void:
	var d := _debris()
	if d == null:
		return
	var t := maxf(flight, 0.05)
	var v := (to - from) / t + Vector3(0, 4.9 * t, 0)
	var sp := v.length()
	d.throw({"look": &"seed", "count": maxi(_n(16), 8), "at": from, "box": Vector3.ONE * 0.015, "dir": v, "cone": 4.0,
			"speed": Vector2(sp * 0.94, sp * 1.04), "size": Vector2(0.004, 0.008), "shape": Vector3(1.0, 0.6, 0.7),
			"colors": _lin([color, color.darkened(0.12), color.lightened(0.1)]), "floor": to.y - 0.04,
			"life": Vector2(t + 1.2, t + 2.2)})


# --- Water ---------------------------------------------------------------------------

## A shower of drops over a bed or trough (the can emptied over it), with splashes.
static func water_splash(at: Vector3) -> void:
	_drops(at + Vector3(0, 0.9, 0), _n(60), Vector3(0.7, 0.05, 0.7), 0.8, 0.38, Vector3.DOWN, 15.0, 0.0045)
	_drops(at, _n(26), Vector3(0.8, 0.02, 0.8), 1.2, 0.35, Vector3.UP, 55.0, 0.0035)


## A few drops bouncing off the soil under the can's stream.
static func drips(at: Vector3) -> void:
	_drops(at, _n(10), Vector3(0.2, 0.02, 0.2), 1.0, 0.32, Vector3.UP, 55.0, 0.0035)


## A dark, glossy wet patch soaking into the ground at `at` (radius in metres) that
## dries away after a while. More of them are kept on higher presets; none on LOW.
static func wet_spot(at: Vector3, radius := 0.1) -> void:
	var cap: int = [0, 8, 16, 28][clampi(Settings.quality, 0, 3)]
	if cap == 0 or Game.world == null:
		return
	while not _spots.is_empty() and (not is_instance_valid(_spots[0]) or _spots[0].get_parent() != Game.world):
		_spots.pop_front()
	var dc: Decal
	if _spots.size() >= cap:
		dc = _spots.pop_front()
	else:
		dc = Decal.new()
		dc.texture_albedo = load(WET_TEX)
		dc.texture_orm = load(WET_ORM_TEX)
		# Only the ground and what stands on it (not the held tool or the thrown bits).
		dc.cull_mask = 1
		dc.upper_fade = 0.4
		dc.lower_fade = 0.4
		Game.world.add_child(dc)
	_spots.append(dc)
	dc.visible = true
	dc.global_position = at + Vector3(0, 0.04, 0)
	dc.rotation = Vector3(0.0, randf() * TAU, 0.0)
	dc.size = Vector3(radius * 2.0, 0.24, radius * 2.0)
	dc.modulate = Color(1, 1, 1, 0)
	if dc.has_meta(&"tween"):
		var old: Tween = dc.get_meta(&"tween")
		if old and old.is_valid():
			old.kill()
	var tw := dc.create_tween()
	tw.tween_property(dc, "modulate:a", randf_range(0.75, 0.95), 0.3)
	tw.tween_interval(randf_range(6.0, 10.0) * detail())
	tw.tween_property(dc, "modulate:a", 0.0, 4.0)
	tw.tween_callback(func() -> void: dc.visible = false)
	dc.set_meta(&"tween", tw)


## A looping water stream for the watering can's spout (the caller places it, turns
## `emitting` on and off and may aim it). Its drops fall in the world, not with the view.
static func make_stream(direction: Vector3) -> FxStream:
	var p := FxStream.new()
	p.axis = direction
	p.direction = direction
	return p


## The drops' material (shared; FxStream makes its own copy to cut its stream off).
static func droplet_material() -> ShaderMaterial:
	if _drop_mat == null:
		_drop_mat = ShaderMaterial.new()
		_drop_mat.shader = load("res://shaders/droplet.gdshader")
	return _drop_mat


## A drop `radius` across, `stretch` times as long along Y (its flight: the emitters
## align Y to the velocity).
static func droplet_mesh(radius: float, stretch: float, material: Material) -> Mesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * stretch
	m.radial_segments = 6
	m.rings = 3
	m.material = material
	return m


# --- Dust and splatter ---------------------------------------------------------------

## A thrown egg breaking: yolk and white spattered off the surface, bits of shell.
static func egg_splat(at: Vector3, normal := Vector3.UP) -> void:
	var dir := (normal.normalized() + Vector3.UP * 0.4).normalized()
	_burst(at, Color(0.97, 0.68, 0.12), 14, Vector3(0.03, 0.03, 0.03), 2.2, 0.55, 60.0, 0.022, dir,
			9.8, 0.0, 1.0, false, 0.4)
	_burst(at, Color(0.95, 0.92, 0.84), 10, Vector3(0.03, 0.03, 0.03), 2.8, 0.6, 70.0, 0.016, dir,
			9.8, 0.0, 1.5, false, 0.5)


## A knife or an arrow striking an animal: a few small dark drops thrown off the wound
## the way the blow came back out (`out`), falling to the ground. Kept small and few.
static func blood_drops(at: Vector3, out := Vector3.UP) -> void:
	var dir := (out.normalized() + Vector3.UP * 0.5).normalized()
	_burst(at, Color(0.32, 0.03, 0.03), _n(9), Vector3(0.02, 0.02, 0.02), 1.6, 0.5, 45.0, 0.011, dir,
			9.8, 0.0, 1.0, false, 0.35)


## Construction dust over an area (half extents in meters).
static func dust_cloud(at: Vector3, half_extents: Vector2) -> void:
	var amount := roundi(clampf(half_extents.x * half_extents.y * 1.6, 8.0, 90.0) * detail())
	_puff(at, Color(0.6, 0.53, 0.44, 0.34), amount, Vector3(half_extents.x, 0.5, half_extents.y), 0.6, 2.2,
			Vector2(0.5, 1.3), Vector3.UP, 0.15, 1.2)


## Soft, lit dust puffs that swell and fade (`size`: metres across, min..max; `rise`:
## how much they lift, as a share of gravity pulling up).
static func _puff(at: Vector3, color: Color, amount: int, extents: Vector3, speed: float, lifetime: float,
		size: Vector2, direction := Vector3.UP, rise := 0.2, damping := 2.0) -> void:
	if Game.world == null:
		return
	if _warming:
		amount = 1
		extents = Vector3.ZERO
		speed = 0.0
		lifetime = 0.1
	var key := "puff"
	var p := _take(key)
	if p == null:
		p = _emitter(key, _dust_quad())
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -25.0
		p.angular_velocity_max = 25.0
		p.anim_offset_min = 0.0
		p.anim_offset_max = 1.0
		p.scale_amount_curve = _curve(false)
		p.color_ramp = _fade_ramp()
	if p.amount != maxi(amount, 1):
		p.amount = maxi(amount, 1)
	p.color = color
	p.lifetime = maxf(lifetime, 0.05)
	p.direction = direction
	p.spread = 70.0
	p.gravity = Vector3(0, 9.8 * rise, 0)
	p.damping_min = damping * 0.6
	p.damping_max = damping
	p.explosiveness = 0.9
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	p.emission_box_extents = extents
	p.global_position = at
	p.restart()


## A burst of water drops.
static func _drops(at: Vector3, amount: int, extents: Vector3, speed: float, lifetime: float,
		direction: Vector3, spread: float, radius: float) -> void:
	if Game.world == null:
		return
	if _warming:
		amount = 1
		extents = Vector3.ZERO
		speed = 0.0
		lifetime = 0.1
	var key := "drop|%.4f" % radius
	var p := _take(key)
	if p == null:
		p = _emitter(key, droplet_mesh(radius, 2.2, droplet_material()))
		p.particle_flag_align_y = true
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.3
	if p.amount != maxi(amount, 1):
		p.amount = maxi(amount, 1)
	p.lifetime = maxf(lifetime, 0.05)
	p.direction = direction
	p.spread = spread
	p.gravity = Vector3(0, -9.8, 0)
	p.explosiveness = 0.85
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.emission_box_extents = extents
	p.global_position = at
	p.restart()


static func _dust_quad() -> QuadMesh:
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.billboard_keep_scale = true
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.albedo_texture = load(DUST_TEX)
		_dust_mat.vertex_color_use_as_albedo = true
		# Puff colours are written as seen (sRGB).
		_dust_mat.vertex_color_is_srgb = true
		_dust_mat.particles_anim_h_frames = 2
		_dust_mat.particles_anim_v_frames = 2
		_dust_mat.particles_anim_loop = false
		_dust_mat.roughness = 1.0
		_dust_mat.metallic_specular = 0.0
		# Soft where it meets the ground, lit through from behind by the sun.
		_dust_mat.proximity_fade_enabled = true
		_dust_mat.proximity_fade_distance = 0.4
		_dust_mat.backlight_enabled = true
		_dust_mat.backlight = Color(0.25, 0.22, 0.18)
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	mesh.material = _dust_mat
	return mesh


## Fades in fast and out slowly.
static func _fade_ramp() -> Gradient:
	if _fade == null:
		_fade = Gradient.new()
		_fade.set_color(0, Color(1, 1, 1, 0))
		_fade.set_color(1, Color(1, 1, 1, 0))
		_fade.add_point(0.12, Color(1, 1, 1, 1))
		_fade.add_point(0.45, Color(1, 1, 1, 0.75))
	return _fade


# --- Helpers -------------------------------------------------------------------------

## The world's thrown-bits node (made on first use, in the current world).
static func _debris() -> FxDebris:
	if Game.world == null:
		return null
	if not is_instance_valid(_debris_node) or _debris_node.get_parent() != Game.world:
		_debris_node = FxDebris.new()
		_debris_node.name = "FxDebris"
		Game.world.add_child(_debris_node)
	return _debris_node


static func _n(base: float) -> int:
	return maxi(roundi(base * detail()), 1)


## Seconds (min, max) a thrown bit lives: its flight and a while on the ground, longer on
## the higher presets.
static func _linger() -> Vector2:
	match Settings.quality:
		Settings.Quality.LOW:
			return Vector2(1.2, 2.0)
		Settings.Quality.MEDIUM:
			return Vector2(2.0, 3.0)
		Settings.Quality.HIGH:
			return Vector2(3.0, 4.5)
	return Vector2(4.5, 7.0)


## Leaves as the season has them (sRGB).
static func _leaf_colors() -> Array:
	match GameClock.get_season():
		GameClock.Season.AUTUMN:
			return [Color(0.78, 0.5, 0.16), Color(0.86, 0.66, 0.2), Color(0.62, 0.3, 0.12), Color(0.5, 0.36, 0.18)]
		GameClock.Season.WINTER:
			return [Color(0.46, 0.34, 0.2), Color(0.4, 0.3, 0.2)]
	return [Color(0.25, 0.35, 0.13), Color(0.21, 0.3, 0.1), Color(0.3, 0.38, 0.15), Color(0.36, 0.4, 0.17)]


## Spruce needles, a few of them dry (sRGB).
static func _needle_colors() -> Array:
	return [Color(0.2, 0.3, 0.14), Color(0.26, 0.34, 0.16), Color(0.42, 0.36, 0.2)]


## sRGB colors as linear albedo (the plain looks' tints).
static func _lin(colors: Array) -> Array:
	var out := []
	for c: Color in colors:
		out.append(c.srgb_to_linear())
	return out


static func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(extra, true)
	return out


## One burst of flat coloured particles (eggs, feathers). `gravity` pulls down (m/s²),
## `damping` slows the particles, `aspect` > 1 makes them longer than wide (they tumble),
## `glow` makes them emissive, `speed_min` is the slowest start speed as a share of
## `speed`.
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


## A one-shot emitter drawing `mesh`, back in the pool of `key` when it has finished.
static func _emitter(key: String, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Small clutter: kept out of the rain height map (layer 2) and out of GI.
	p.layers = 2
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Placed once per burst and never moved in between: nothing to interpolate.
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.finished.connect(func() -> void: _release(p, key))
	Game.world.add_child(p)
	return p


static func _make(key: String, color: Color, particle_size: float, aspect := 1.0, glow := false) -> CPUParticles3D:
	if not _meshes.has(key):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(particle_size * aspect, particle_size)
		mesh.material = _material(color, glow)
		_meshes[key] = mesh
	var p := _emitter(key, _meshes[key])
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	if aspect != 1.0:
		# Flakes tumble as they fly.
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
	if glow:
		p.scale_amount_curve = _curve(true)
	elif color.a < 1.0 and particle_size >= 0.1:
		p.scale_amount_curve = _curve(false)
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
		_swell.add_point(Vector2(0.0, 0.55))
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
			m.emission_energy_multiplier = 6.0
			m.emission = color
		_mats[key] = m
	return _mats[key]
