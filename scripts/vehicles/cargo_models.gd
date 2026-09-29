class_name CargoModels
extends RefCounted
## Packages for goods riding in a vehicle bed and stacked on market shelves: slatted
## crates of produce or rock, sacks, hay bales, egg and milk crates, split firewood,
## pumpkins, boxes, and poultry crates with a live hen in each (the hen is a CrateHen
## the bed or shelf seats in the empty crate). The goods themselves are the scanned
## item models, thinned out (GoodsModels.low); crates and cartons are built here. A
## package stands on its bottom centre with its long side along +X and fills one bed
## slot of SIZE. Also knows how much one unit of each item weighs.

const SIZE := Vector3(0.5, 0.26, 0.36)
const PINE := Color(0.64, 0.56, 0.44)
const BURLAP := Color(0.66, 0.56, 0.4)
const KRAFT := Color(0.72, 0.6, 0.44)
const TWINE := Color(0.5, 0.33, 0.2)
const LEAF := Color(0.24, 0.42, 0.14)
## Firewood bark tints (0.5 grey leaves the bark texture as it is).
const BARK := Color(0.4, 0.34, 0.28)
const BARK_GREY := Color(0.44, 0.41, 0.37)

## Kilograms per item unit.
const UNIT_KG := {
	&"wheat": 1.0, &"carrot": 0.15, &"potato": 0.25, &"tomato": 0.15, &"corn": 0.35,
	&"eggplant": 0.3, &"strawberry": 0.05, &"pumpkin": 6.0,
	&"wood": 4.0, &"stone": 5.0, &"iron_ore": 6.0,
	&"hay": 3.0, &"feed": 2.0, &"medicine": 0.2,
	&"egg": 0.06, &"milk": 1.05, &"wool": 1.5,
	&"cheese": 1.0, &"yarn": 0.25, &"pickles": 0.8, &"jam": 0.5, &"tomato_paste": 0.6, &"flour": 2.0,
	&"fertilizer": 5.0, &"manure": 3.0, &"workbench": 60.0, &"cheese_press": 45.0, &"spinning_wheel": 20.0,
	&"pickle_barrel": 30.0, &"jam_kettle": 40.0, &"quern": 80.0, &"sprinkler": 3.0,
	&"chicken_crate": 6.0, &"truck_key": 0.05,
}
const SEED_KG := 0.05
const DEFAULT_KG := 0.5

static var _cache := {}
## Surfaces ([arrays, material, name]) of each thinned-out good: reading a mesh back
## from the GPU stalls the renderer, so each is read once.
static var _low_surfaces := {}


static func unit_kg(id: StringName) -> float:
	if String(id).ends_with("_seed"):
		return SEED_KG
	return float(UNIT_KG.get(id, DEFAULT_KG))


## A package with a live animal in it: one animal per package, and a CrateHen rides
## in it wherever it is shown.
static func is_live(id: StringName) -> bool:
	return AnimalTable.species_of_crate(id) != &""


## Units one package of `id` stands for when a slot holds `per_slot` units: a live
## crate is always one animal.
static func units_per_package(id: StringName, per_slot: int) -> int:
	return 1 if is_live(id) else per_slot


## The kind of package an item travels in.
static func look_of(id: StringName) -> String:
	if is_live(id):
		return "poultry_crate"
	match id:
		&"tomato", &"potato", &"carrot", &"corn", &"eggplant", &"strawberry", &"stone", &"iron_ore":
			return "crate"
		&"pumpkin":
			return "pumpkins"
		&"wood":
			return "firewood"
		&"hay":
			return "bale"
		&"wheat", &"feed", &"flour", &"fertilizer", &"manure":
			return "sack"
		&"cheese":
			return "cheese_crate"
		&"pickles", &"jam", &"tomato_paste":
			return "jar_crate"
		&"wool":
			return "wool_pack"
		&"egg":
			return "egg_crate"
		&"milk":
			return "milk_crate"
		&"medicine":
			return "medicine"
	if String(id).ends_with("_seed"):
		return "seed_bags"
	return "box"


## Package mesh for `id`; `variant` changes the random details (produce, knots).
static func mesh(id: StringName, variant := 0) -> ArrayMesh:
	var key := "%s:%d" % [id, variant]
	if _cache.has(key):
		return _cache[key]
	var mb := MeshBuilder.new()
	# Surfaces of the scanned goods ([arrays, material, name]).
	var scans := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match look_of(id):
		"crate":
			_crate(mb, rng)
			_crate_fill(mb, scans, id, rng)
		"pumpkins":
			for i in 2:
				var pid := &"pumpkin" if i == 0 else &"pumpkin_b"
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.86, 0.94))
				_scan(scans, pid, Transform3D(b, Vector3(-0.125 + i * 0.25 + rng.randf_range(-0.01, 0.01), 0.0, rng.randf_range(-0.03, 0.03))))
		"firewood":
			_firewood(mb, rng)
		"bale":
			var hay := GoodsModels.low(&"hay")
			var turn := Basis(Vector3.UP, PI * 0.5) if hay.get_aabb().size.z > hay.get_aabb().size.x else Basis()
			_scan(scans, &"hay", _fit(hay, Vector3(0.48, 0.25, 0.34), turn))
		"sack":
			if id == &"fertilizer":
				_scan(scans, &"fertilizer", _fit(GoodsModels.low(&"fertilizer"), Vector3(0.34, 0.24, 0.3)))
			else:
				_sack(scans, &"flour" if id == &"flour" else (&"manure" if id == &"manure" else &"feed"), rng)
		"cheese_crate":
			_crate(mb, rng)
			var cheese := GoodsModels.low(&"cheese")
			for layer in 2:
				for i in 2:
					for k in 2:
						var b := Basis(Vector3.UP, (PI if (i + k + layer) % 2 == 0 else 0.0) + rng.randf_range(-0.2, 0.2))
						var at := Vector3(-0.11 + i * 0.22, 0.018 + layer * 0.075, -0.075 + k * 0.15)
						_scan(scans, &"cheese", Transform3D(b.scaled(Vector3.ONE * 0.85), at))
		"jar_crate":
			_plastic_crate(mb, Color(0.3, 0.42, 0.3), 0.12)
			for i in 4:
				for k in 3:
					var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.85)
					_scan(scans, id, Transform3D(b, Vector3(-0.165 + i * 0.11, 0.016, -0.1 + k * 0.1)))
		"wool_pack":
			_sack(scans, &"feed", rng)
			var fleece := Color(0.94, 0.91, 0.83)
			for i in 5:
				var p := Vector3(0.23 + rng.randf_range(-0.01, 0.02), 0.11 + rng.randf_range(-0.03, 0.04), rng.randf_range(-0.06, 0.06))
				mb.blob(&"wool", Transform3D(Basis(), p), rng.randf_range(0.035, 0.05), 1, fleece, 0.2, 3.0, i, 0.0, true)
		"egg_crate":
			_egg_crate(mb, scans, rng)
		"milk_crate":
			var can := GoodsModels.low(&"milk")
			var s := 0.25 / can.get_aabb().size.y
			for i in 2:
				_scan(scans, &"milk", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(-0.12 + i * 0.24, 0.0, rng.randf_range(-0.02, 0.02))))
		"medicine":
			_medicine(mb)
		"poultry_crate":
			ItemModels.poultry_crate(mb, rng)
		"seed_bags":
			_seed_bags(mb, ItemModels.CROP_COLORS.get(StringName(String(id).trim_suffix("_seed")), Color(0.5, 0.5, 0.5)), rng)
		_:
			_carton(mb, rng)
	# The built surfaces first, then the scans joined per material (they never share
	# one with the builder's).
	var m := mb.build()
	for surf: Array in MeshMerge.by_material(scans):
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf[0])
		m.surface_set_material(m.get_surface_count() - 1, surf[1])
		m.surface_set_name(m.get_surface_count() - 1, surf[2])
	_cache[key] = m
	return m


## A scanned good (thinned out) placed with `xf`.
static func _scan(scans: Array, id: StringName, xf: Transform3D) -> void:
	if not _low_surfaces.has(id):
		var list := []
		var low := GoodsModels.low(id)
		if low != null:
			for si in low.get_surface_count():
				list.append([low.surface_get_arrays(si), low.surface_get_material(si), low.surface_get_name(si)])
		_low_surfaces[id] = list
	for surf: Array in _low_surfaces[id]:
		# _moved() rewrites the packed arrays it is given (shared by reference): a deep copy.
		scans.append([MeshMerge._moved((surf[0] as Array).duplicate(true), xf), surf[1], surf[2]])


## Squeezes `mesh`, turned by `pre`, into a box of `size` standing on the origin.
static func _fit(mesh: ArrayMesh, size: Vector3, pre := Basis()) -> Transform3D:
	var box := Transform3D(pre, Vector3.ZERO) * mesh.get_aabb()
	var b := Basis.from_scale(Vector3(size.x / box.size.x, size.y / box.size.y, size.z / box.size.z)) * pre
	var moved := Transform3D(b, Vector3.ZERO) * mesh.get_aabb()
	return Transform3D(b, -Vector3(moved.get_center().x, moved.position.y, moved.get_center().z))


# --- Crates --------------------------------------------------------------------------

## Open slatted pine crate, SIZE footprint.
static func _crate(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var c := PINE.lightened(rng.randf_range(-0.06, 0.06))
	var l := SIZE.x
	var w := SIZE.z
	for z: float in [-0.12, 0.0, 0.12]:
		mb.box_at(&"wood", Vector3(0, 0.008, z), Vector3(l - 0.02, 0.016, 0.1), c.darkened(0.08))
	for y: float in [0.045, 0.125, 0.205]:
		for s: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(0, y, s * (w * 0.5 - 0.008)), Vector3(l - 0.03, 0.062, 0.014), c)
			mb.box_at(&"wood", Vector3(s * (l * 0.5 - 0.008), y, 0), Vector3(0.014, 0.062, w - 0.03), c)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(sx * (l * 0.5 - 0.02), 0.12, sz * (w * 0.5 - 0.02)), Vector3(0.032, 0.24, 0.032), c.darkened(0.12))


## Heaped contents: a dark layer that hides the floor and one layer of produce on top.
static func _crate_fill(mb: MeshBuilder, scans: Array, id: StringName, rng: RandomNumberGenerator) -> void:
	var col: Color = ItemModels.CROP_COLORS.get(id, Color(0.4, 0.4, 0.4))
	var inner := Vector2(SIZE.x - 0.05, SIZE.z - 0.05)
	match id:
		&"tomato":
			_under(mb, inner, 0.15, col.darkened(0.45))
			for p: Vector3 in _grid(rng, inner, 6, 4, 0.145, 0.006):
				_scan(scans, id, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))), p))
		&"potato":
			_under(mb, inner, 0.14, col.darkened(0.4))
			for p: Vector3 in _grid(rng, inner, 5, 4, 0.13, 0.01):
				var pid := &"potato" if rng.randf() < 0.5 else &"potato_b"
				_scan(scans, pid, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))), p))
		&"carrot":
			_under(mb, inner, 0.13, col.darkened(0.45))
			for p: Vector3 in _grid(rng, inner, 2, 6, 0.125, 0.008):
				var b := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2) + (PI if rng.randf() < 0.5 else 0.0))
				_scan(scans, id, Transform3D(b, p - b * Vector3(0.0, 0, 0)))
		&"corn":
			_under(mb, inner, 0.12, LEAF.darkened(0.3))
			for p: Vector3 in _grid(rng, inner, 3, 4, 0.18, 0.01):
				var yaw := rng.randf_range(-0.2, 0.2)
				var b := Basis(Vector3.UP, yaw)
				mb.sphere(&"veg", Transform3D(b, p), Vector3(0.075, 0.032, 0.032), 8, 5, col.lightened(rng.randf_range(-0.08, 0.05)))
				for s: float in [-1.0, 1.0]:
					var husk := Transform3D(b * Basis(Vector3.RIGHT, s * 0.9), p + b * Vector3(-0.01, 0.004, s * 0.012))
					mb.sphere(&"veg", husk, Vector3(0.085, 0.006, 0.03), 7, 4, Color(0.56, 0.66, 0.34))
		&"eggplant":
			_under(mb, inner, 0.13, col.darkened(0.3))
			for p: Vector3 in _grid(rng, inner, 2, 4, 0.125, 0.008):
				var b := Basis(Vector3.UP, rng.randf_range(-0.15, 0.15) + (PI if rng.randf() < 0.5 else 0.0))
				_scan(scans, id, Transform3D(b, p))
		&"strawberry":
			# Green punnets of berries.
			for i in 3:
				for k in 2:
					var c := Vector3(-0.15 + i * 0.15, 0.105, -0.083 + k * 0.166)
					mb.box_at(&"paper", c, Vector3(0.14, 0.05, 0.155), Color(0.3, 0.5, 0.26))
					for b: Vector2 in [Vector2(-0.04, -0.045), Vector2(0.04, -0.045), Vector2(0.0, 0.0), Vector2(-0.04, 0.045), Vector2(0.04, 0.045)]:
						var p := c + Vector3(b.x + rng.randf_range(-0.008, 0.008), 0.02, b.y + rng.randf_range(-0.008, 0.008))
						_scan(scans, id, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-1.2, 1.2))), p))
			_under(mb, inner, 0.08, Color(0.3, 0.26, 0.2))
		&"stone", &"iron_ore":
			var iron := id == &"iron_ore"
			var tint := Color(0.3, 0.27, 0.26) if iron else Color(0.42, 0.41, 0.4)
			_under(mb, inner, 0.11, tint.darkened(0.3))
			for p: Vector3 in _grid(rng, inner, 3, 2, 0.15, 0.015):
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.2, 0.8, 1.0)), p)
				mb.blob(&"stone", xf, rng.randf_range(0.07, 0.085), 1, tint.lightened(rng.randf_range(-0.06, 0.06)), 0.3, 2.2, rng.randi() % 97, 0.0, true, -0.35)
				if iron:
					for f in 3:
						var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), rng.randf_range(-1, 1)).normalized()
						mb.blob(&"steel", Transform3D(Basis(), p + d * Vector3(0.085, 0.055, 0.07)), 0.014, 1, Color(0.62, 0.34, 0.16), 0.3, 3.0, f)


## Flat layer under the top produce so the crate never looks hollow.
static func _under(mb: MeshBuilder, inner: Vector2, y: float, color: Color) -> void:
	mb.box_at(&"veg_rough", Vector3(0, y * 0.5, 0), Vector3(inner.x, y, inner.y), color)


## nx x nz jittered points on a layer at height y.
static func _grid(rng: RandomNumberGenerator, inner: Vector2, nx: int, nz: int, y: float, jitter: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in nx:
		for k in nz:
			out.append(Vector3((i + 0.5) / nx * inner.x - inner.x * 0.5 + rng.randf_range(-jitter, jitter),
					y + rng.randf_range(-0.01, 0.012),
					(k + 0.5) / nz * inner.y - inner.y * 0.5 + rng.randf_range(-jitter, jitter)))
	return out


# --- Loose goods ---------------------------------------------------------------------

## Split logs stacked 3-2-1, bark outside and end grain at the cut ends. The bark is
## tinted a darker, warmer brown than the texture (seasoned oak and beech), each log a
## little different.
static func _firewood(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	for p: Vector2 in [Vector2(-0.12, 0.05), Vector2(0.0, 0.05), Vector2(0.12, 0.05), Vector2(-0.06, 0.135), Vector2(0.06, 0.135), Vector2(0.0, 0.215)]:
		var r := rng.randf_range(0.044, 0.054)
		var half := rng.randf_range(0.21, 0.24)
		var c := Vector3(rng.randf_range(-0.015, 0.015), p.y, p.x + rng.randf_range(-0.006, 0.006))
		var a := c - Vector3(half, 0, 0)
		var b := c + Vector3(half, 0, 0)
		var bark := BARK.lerp(BARK_GREY, rng.randf()).lightened(rng.randf_range(-0.05, 0.05))
		mb.cylinder_between(&"bark", a, b, r, r * 0.96, 9, bark, false, false)
		mb.disc(&"endgrain", Transform3D(Basis(Vector3.BACK, -PI * 0.5), b), r * 0.96, 9, Color.WHITE)
		mb.disc(&"endgrain", Transform3D(Basis(Vector3.BACK, PI * 0.5), a), r, 9, Color.WHITE)


## A full sack (the scanned burlap one, tinted as `id`) lying on its side, the tied
## end toward +X.
static func _sack(scans: Array, id: StringName, rng: RandomNumberGenerator) -> void:
	var lie := Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.UP, rng.randf() * TAU)
	_scan(scans, id, _fit(GoodsModels.low(id), Vector3(0.48, 0.22, 0.32), lie))


## Plastic crate with stacked pulp trays of eggs.
static func _egg_crate(mb: MeshBuilder, scans: Array, rng: RandomNumberGenerator) -> void:
	_plastic_crate(mb, Color(0.34, 0.44, 0.52), 0.2)
	var tray := Color(0.62, 0.6, 0.56)
	for y: float in [0.03, 0.09, 0.15]:
		mb.box_at(&"paper", Vector3(0, y, 0), Vector3(SIZE.x - 0.05, 0.016, SIZE.z - 0.05), tray)
	for i in 6:
		for k in 4:
			var p := Vector3(-0.19 + i * 0.076, 0.158, -0.114 + k * 0.076)
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)))
			_scan(scans, &"egg", Transform3D(b.scaled(Vector3.ONE * 0.9), p))


static func _plastic_crate(mb: MeshBuilder, color: Color, wall: float) -> void:
	var l := SIZE.x
	var w := SIZE.z
	mb.box_at(&"paint_in", Vector3(0, 0.008, 0), Vector3(l, 0.016, w), color.darkened(0.15))
	for s: float in [-1.0, 1.0]:
		mb.box_at(&"paint_in", Vector3(0, wall * 0.5, s * (w * 0.5 - 0.008)), Vector3(l, wall, 0.016), color)
		mb.box_at(&"paint_in", Vector3(s * (l * 0.5 - 0.008), wall * 0.5, 0), Vector3(0.016, wall, w - 0.032), color)
	# Rim and handle slots.
	for s: float in [-1.0, 1.0]:
		mb.box_at(&"paint_in", Vector3(0, wall - 0.006, s * (w * 0.5 - 0.004)), Vector3(l + 0.004, 0.012, 0.024), color.lightened(0.08))
		mb.box_at(&"paint_in", Vector3(s * (l * 0.5 + 0.001), wall - 0.035, 0), Vector3(0.004, 0.025, 0.1), color.darkened(0.5))


## Four cartons of veterinary medicine with red crosses.
static func _medicine(mb: MeshBuilder) -> void:
	for x: float in [-0.12, 0.12]:
		for z: float in [-0.086, 0.086]:
			var c := Vector3(x, 0.09, z)
			mb.box_at(&"paper", c, Vector3(0.23, 0.18, 0.165), Color(0.92, 0.91, 0.87))
			mb.box_at(&"paper", c + Vector3(0, 0.091, 0), Vector3(0.07, 0.003, 0.022), Color(0.8, 0.12, 0.1))
			mb.box_at(&"paper", c + Vector3(0, 0.091, 0), Vector3(0.022, 0.003, 0.07), Color(0.8, 0.12, 0.1))


## Six kraft paper seed bags with a band in the crop's colour.
static func _seed_bags(mb: MeshBuilder, band: Color, rng: RandomNumberGenerator) -> void:
	for i in 3:
		for k in 2:
			var c := Vector3(-0.16 + i * 0.16, 0.0, -0.082 + k * 0.164)
			var h := rng.randf_range(0.19, 0.22)
			var yaw := Vector3(0, rng.randf_range(-6, 6), 0)
			mb.box_at(&"paper", c + Vector3(0, h * 0.5, 0), Vector3(0.14, h, 0.1), KRAFT.lightened(rng.randf_range(-0.05, 0.05)), yaw)
			mb.box_at(&"paper", c + Vector3(0, h + 0.012, 0), Vector3(0.14, 0.024, 0.05), KRAFT.darkened(0.1), yaw)
			mb.box_at(&"paper", c + Vector3(0, h * 0.42, 0), Vector3(0.143, 0.045, 0.103), band, yaw)


## Taped cardboard box for anything else.
static func _carton(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var c := Color(0.62, 0.48, 0.32).lightened(rng.randf_range(-0.05, 0.05))
	mb.box_at(&"paper", Vector3(0, 0.12, 0), Vector3(0.48, 0.24, 0.34), c)
	mb.box_at(&"paper", Vector3(0, 0.241, 0), Vector3(0.482, 0.003, 0.06), Color(0.75, 0.66, 0.5))
