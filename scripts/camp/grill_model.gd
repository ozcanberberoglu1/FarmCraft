class_name GrillModel
extends RefCounted
## The two charcoal grills sold at the town market (Grill):
##   "grill"      a Turkish sheet-steel mangal: a flared trough with a rolled rim on four
##                splayed legs braced near the ground, steel loop handles at its ends and
##                a wire grate laid over it (six places, three by two)
##   "big_grill"  a long barbecue grill on a stand: a deeper trough on square legs with a
##                slatted wooden shelf below, two wheels at one end and a wooden handle at
##                the other, a wind guard along the back (twelve places, six by two)
## Both burn a bed of lump charcoal (coals_mesh) on a layer of ash (ash_mesh), drawn with
## the campfire's wood shader (CampfireModel.wood_material: it chars, glows and greys
## with the fire's burn, glow and ash).

## Per grill: the grate's size (x along the grill, y across, m), the trough's depth, the
## grate's height off the ground and its places (columns along x, rows across).
const LOOKS := {
	&"grill": {"size": Vector2(0.84, 0.38), "depth": 0.15, "grate_y": 0.76, "cols": 3, "rows": 2},
	&"big_grill": {"size": Vector2(1.5, 0.52), "depth": 0.2, "grate_y": 0.88, "cols": 6, "rows": 2},
}
## How much narrower the trough is at the bottom than at the rim (each side, m).
const FLARE := 0.03
## The charcoal bed lies this far over the trough's floor.
const BED_LIFT := 0.006

const STEEL_BLACK := Color(0.085, 0.08, 0.075)
const STEEL_INSIDE := Color(0.15, 0.135, 0.12)
const STEEL_EDGE := Color(0.24, 0.23, 0.22)
const GRATE := Color(0.33, 0.32, 0.31)
const TYRE := Color(0.05, 0.05, 0.05)
const WOOD := Color(0.5, 0.36, 0.24)

static var _cache := {}


static func look(id: StringName) -> Dictionary:
	return LOOKS.get(id, LOOKS[&"grill"])


## Height of the trough's floor (the charcoal bed lies on it).
static func bed_y(id: StringName) -> float:
	var l := look(id)
	return float(l["grate_y"]) - float(l["depth"]) + BED_LIFT


## The middle of place `slot` on the grate (`span` places wide from it), on the bars.
static func place_at(id: StringName, slot: int, span := 1) -> Vector3:
	var l := look(id)
	var cols := int(l["cols"])
	var rows := int(l["rows"])
	var cell := cell_size(id)
	var col := float(slot % cols) + float(span - 1) * 0.5
	var row := float(slot / cols)
	return Vector3((col - float(cols - 1) * 0.5) * cell.x, float(l["grate_y"]), (row - float(rows - 1) * 0.5) * cell.y)


## One place's size on the grate (x along the grill, y across).
static func cell_size(id: StringName) -> Vector2:
	var l := look(id)
	var size: Vector2 = l["size"]
	return Vector2(size.x / float(l["cols"]), size.y / float(l["rows"]))


# --- The grill --------------------------------------------------------------------------

## The steel (trough, legs, handles, grate) and wood of the grill, standing on the origin.
static func body_mesh(id: StringName) -> ArrayMesh:
	var key := "body_%s" % id
	if _cache.has(key):
		return _cache[key]
	var mb := MeshBuilder.new()
	var l := look(id)
	var size: Vector2 = l["size"]
	var rim := float(l["grate_y"]) - 0.006
	var bot := float(l["grate_y"]) - float(l["depth"])
	_trough(mb, size, rim, bot)
	if id == &"big_grill":
		_stand(mb, size, rim, bot)
	else:
		_legs(mb, size, rim, bot)
	_grate(mb, size, float(l["grate_y"]))
	var m := mb.build()
	_cache[key] = m
	return m


static func _trough(mb: MeshBuilder, size: Vector2, rim: float, bot: float) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var t := func(sx: float, sz: float) -> Vector3: return Vector3(sx * hx, rim, sz * hz)
	var b := func(sx: float, sz: float) -> Vector3: return Vector3(sx * (hx - FLARE), bot, sz * (hz - FLARE))
	# The four walls, black outside and ash-stained inside.
	for w: Array in [[-1.0, 1.0, 1.0, 1.0], [1.0, -1.0, -1.0, -1.0], [1.0, 1.0, 1.0, -1.0], [-1.0, -1.0, -1.0, 1.0]]:
		var a: Vector3 = b.call(w[0], w[1])
		var c: Vector3 = b.call(w[2], w[3])
		var d: Vector3 = t.call(w[2], w[3])
		var e: Vector3 = t.call(w[0], w[1])
		_sheet(mb, a, c, d, e, STEEL_BLACK, STEEL_INSIDE)
	# The floor.
	_sheet(mb, b.call(-1.0, -1.0), b.call(1.0, -1.0), b.call(1.0, 1.0), b.call(-1.0, 1.0), STEEL_BLACK, STEEL_INSIDE)
	# A rolled rim round the top.
	var corners: Array[Vector3] = [t.call(-1.0, -1.0), t.call(1.0, -1.0), t.call(1.0, 1.0), t.call(-1.0, 1.0)]
	for i in 4:
		mb.cylinder_between(&"steel", corners[i], corners[(i + 1) % 4], 0.007, 0.007, 8, STEEL_EDGE, true, false)
	# A row of air holes low along each long side (dark, glowing nothing: just holes).
	var holes := maxi(int(size.x / 0.09), 4)
	for sz: float in [-1.0, 1.0]:
		for i in holes:
			var x := lerpf(-hx + 0.08, hx - 0.08, (float(i) + 0.5) / holes)
			var y := bot + 0.035
			var z := sz * (hz - FLARE + FLARE * (y - bot) / (rim - bot)) + sz * 0.0015
			mb.disc(&"rusty", Transform3D(Basis(Vector3.RIGHT, sz * PI * 0.5), Vector3(x, y, z)), 0.011, 10, Color(0.015, 0.012, 0.01))
	# Loop handles at the ends.
	for sx: float in [-1.0, 1.0]:
		var y := rim - 0.035
		var x0 := sx * (hx - 0.004)
		var x1 := sx * (hx + 0.065)
		var p: Array[Vector3] = [Vector3(x0, y, -0.07), Vector3(x1, y, -0.07), Vector3(x1, y, 0.07), Vector3(x0, y, 0.07)]
		for i in 3:
			mb.cylinder_between(&"steel", p[i], p[i + 1], 0.0055, 0.0055, 8, STEEL_EDGE.darkened(0.2))


## Thin sheet steel: the quad a b c d (counter-clockwise seen from outside) both ways.
static func _sheet(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outside: Color, inside: Color) -> void:
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	mb.quad(&"rusty", a, b, c, d, outside, Vector2(0, 0), Vector2(la, 0), Vector2(la, lb), Vector2(0, lb))
	mb.quad(&"rusty", d, c, b, a, inside, Vector2(0, lb), Vector2(la, lb), Vector2(la, 0), Vector2(0, 0))


## The mangal's four splayed legs, braced near the ground.
static func _legs(mb: MeshBuilder, size: Vector2, _rim: float, bot: float) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var feet: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var top := Vector3(sx * (hx - FLARE - 0.012), bot + 0.06, sz * (hz - FLARE + 0.006))
			var foot := Vector3(sx * (hx + 0.015), 0.0, sz * (hz + 0.05))
			mb.cylinder_between(&"rusty", foot, top, 0.011, 0.011, 4, STEEL_BLACK, false)
			mb.cylinder(&"rusty", Transform3D(Basis(), foot), 0.02, 0.018, 0.008, 10, STEEL_BLACK.darkened(0.3))
			feet.append(foot.lerp(top, 0.18))
	# Braces: along each side and across each end.
	for pair: Array in [[0, 2], [1, 3], [0, 1], [2, 3]]:
		mb.cylinder_between(&"rusty", feet[pair[0]], feet[pair[1]], 0.007, 0.007, 6, STEEL_BLACK)


## The big grill's stand: square legs (wheels at one end), a slatted shelf, a wooden
## handle and a wind guard along the back.
static func _stand(mb: MeshBuilder, size: Vector2, rim: float, bot: float) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var wheel_r := 0.1
	var shelf_y := 0.24
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var x := sx * (hx - FLARE - 0.03)
			var z := sz * (hz - FLARE + 0.004)
			var y0 := wheel_r if sx < 0.0 else 0.0
			mb.box_at(&"rusty", Vector3(x, (y0 + bot + 0.05) * 0.5, z), Vector3(0.03, bot + 0.05 - y0, 0.03), STEEL_BLACK)
			if sx > 0.0:
				mb.box_at(&"rusty", Vector3(x, 0.005, z), Vector3(0.05, 0.01, 0.05), TYRE)
	# Rails along the shelf and under the trough.
	for sz: float in [-1.0, 1.0]:
		var z := sz * (hz - FLARE + 0.004)
		mb.box_at(&"rusty", Vector3(0, shelf_y, z), Vector3(size.x - 2.0 * (FLARE + 0.03), 0.025, 0.025), STEEL_BLACK)
		mb.box_at(&"rusty", Vector3(0, bot - 0.012, z), Vector3(size.x - 2.0 * FLARE, 0.025, 0.025), STEEL_BLACK)
	# Wooden slats across the shelf.
	var slats := int((size.x - 0.2) / 0.12)
	for i in slats:
		var x := lerpf(-hx + 0.12, hx - 0.12, (float(i) + 0.5) / slats)
		mb.box_at(&"wood", Vector3(x, shelf_y + 0.022, 0), Vector3(0.085, 0.018, size.y - 2.0 * FLARE + 0.04),
				WOOD.darkened(0.08 * float(i % 3)), Vector3.ZERO, true)
	# Wheels on an axle at the -x end.
	var wx := -(hx - FLARE - 0.03)
	mb.cylinder_between(&"steel", Vector3(wx, wheel_r, -hz - 0.03), Vector3(wx, wheel_r, hz + 0.03), 0.009, 0.009, 8, GRATE)
	for sz: float in [-1.0, 1.0]:
		var c := Vector3(wx, wheel_r, sz * (hz + 0.012))
		mb.cylinder(&"rusty", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c - Vector3(0, 0, 0.02)), wheel_r, wheel_r, 0.04, 20, TYRE)
		mb.cylinder(&"steel", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c - Vector3(0, 0, 0.024)), 0.045, 0.045, 0.048, 14, GRATE)
	# The handle at the +x end: two steel arms and a wooden bar.
	var hy := rim - 0.05
	for sz: float in [-1.0, 1.0]:
		mb.cylinder_between(&"steel", Vector3(hx - 0.004, hy, sz * 0.15), Vector3(hx + 0.13, hy + 0.03, sz * 0.15), 0.008, 0.008, 8, STEEL_EDGE)
	mb.cylinder_between(&"wood", Vector3(hx + 0.13, hy + 0.03, -0.17), Vector3(hx + 0.13, hy + 0.03, 0.17), 0.017, 0.017, 12, WOOD)
	# The wind guard along the back.
	mb.box_at(&"rusty", Vector3(0, rim + 0.06, -hz - 0.004), Vector3(size.x, 0.12, 0.004), STEEL_BLACK)
	mb.cylinder_between(&"steel", Vector3(-hx, rim + 0.12, -hz - 0.004), Vector3(hx, rim + 0.12, -hz - 0.004), 0.005, 0.005, 8, STEEL_EDGE)


## The wire grate: a frame, bars across the grill and two runners under them, with
## lifting handles at the ends.
static func _grate(mb: MeshBuilder, size: Vector2, gy: float) -> void:
	var hx := size.x * 0.5 - 0.012
	var hz := size.y * 0.5 - 0.006
	var r := 0.0032
	var y := gy - r
	var bars := int(size.x / 0.021)
	for i in bars + 1:
		var x := lerpf(-hx + 0.006, hx - 0.006, float(i) / bars)
		mb.cylinder_between(&"steel", Vector3(x, y, -hz), Vector3(x, y, hz), r, r, 6, GRATE, true, false)
	var fy := y - r - 0.004
	for sz: float in [-1.0, 1.0]:
		mb.cylinder_between(&"steel", Vector3(-hx, fy, sz * hz), Vector3(hx, fy, sz * hz), 0.0045, 0.0045, 8, GRATE)
		mb.cylinder_between(&"steel", Vector3(-hx, fy, sz * hz * 0.45), Vector3(hx, fy, sz * hz * 0.45), 0.0035, 0.0035, 6, GRATE)
	for sx: float in [-1.0, 1.0]:
		mb.cylinder_between(&"steel", Vector3(sx * hx, fy, -hz), Vector3(sx * hx, fy, hz), 0.0045, 0.0045, 8, GRATE)
		var p: Array[Vector3] = [Vector3(sx * hx, fy, -0.045), Vector3(sx * (hx + 0.035), fy + 0.02, -0.045),
			Vector3(sx * (hx + 0.035), fy + 0.02, 0.045), Vector3(sx * hx, fy, 0.045)]
		for i in 3:
			mb.cylinder_between(&"steel", p[i], p[i + 1], 0.003, 0.003, 6, GRATE)


# --- Charcoal ---------------------------------------------------------------------------

## The lump charcoal in the trough, its floor at the origin (put at bed_y): two loose
## layers of lumps over the floor.
static func coals_mesh(id: StringName) -> ArrayMesh:
	var key := "coals_%s" % id
	if _cache.has(key):
		return _cache[key]
	var size := _inner(id)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23 + int(size.x * 100.0)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 5.0
	var ico: Dictionary = MeshBuilder._icosphere(1)
	var unit: PackedVector3Array = ico["verts"]
	var faces: PackedInt32Array = ico["faces"]
	# The lumps stay inside 85% of the floor: the bed spreads a little as it burns.
	var hx := size.x * 0.5 * 0.85
	var hz := size.y * 0.5 * 0.85
	var count := int(size.x * size.y * 300.0)
	for i in count:
		var layer := 0 if i < count * 0.6 else 1
		var lump := Vector3(rng.randf_range(0.02, 0.036), rng.randf_range(0.014, 0.024), rng.randf_range(0.018, 0.032))
		var c := Vector3(rng.randf_range(-hx, hx), lump.y * 0.6 + layer * 0.022, rng.randf_range(-hz, hz))
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
		var hot := rng.randf_range(0.75, 1.0)
		for f in range(0, faces.size(), 3):
			var p: Array[Vector3] = []
			for j in 3:
				var v := unit[faces[f + j]]
				var bump := 1.0 + noise.get_noise_3dv(v * 2.5 + Vector3(i * 1.7, 0, 0)) * 0.45
				p.append(c + basis * (v * lump * bump))
			var n := (p[1] - p[0]).cross(p[2] - p[0]).normalized()
			for j: int in [0, 2, 1]:
				_vert(st, p[j], n, Vector2(p[j].x, p[j].z) * 3.0, hot)
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, CampfireModel.wood_material())
	_cache[key] = m
	return m


## The ash and fines on the trough's floor under the lumps (seen once it has burnt).
static func ash_mesh(id: StringName) -> ArrayMesh:
	var key := "ash_%s" % id
	if _cache.has(key):
		return _cache[key]
	var size := _inner(id) * 0.98
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 9.0
	var nx := maxi(int(size.x / 0.05), 2)
	var nz := maxi(int(size.y / 0.05), 2)
	var at := func(i: int, k: int) -> Vector3:
		var x := (float(i) / nx - 0.5) * size.x
		var z := (float(k) / nz - 0.5) * size.y
		var edge := minf(minf(float(i), float(nx - i)), minf(float(k), float(nz - k)))
		var h := 0.008 + noise.get_noise_2d(x, z) * 0.006 if edge > 0.0 else 0.0
		return Vector3(x, h, z)
	for i in nx:
		for k in nz:
			var a: Vector3 = at.call(i, k)
			var b: Vector3 = at.call(i + 1, k)
			var c: Vector3 = at.call(i + 1, k + 1)
			var d: Vector3 = at.call(i, k + 1)
			for tri: Array in [[a, d, c], [a, c, b]]:
				var p0: Vector3 = tri[0]
				var p1: Vector3 = tri[1]
				var p2: Vector3 = tri[2]
				var n := (p1 - p0).cross(p2 - p0).normalized()
				if n.y < 0.0:
					n = -n
				for p: Vector3 in [p0, p2, p1]:
					_vert(st, p, n, Vector2(p.x, p.z), 0.8)
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, CampfireModel.wood_material())
	_cache[key] = m
	return m


## The trough's floor (x, z) inside its walls.
static func _inner(id: StringName) -> Vector2:
	var size: Vector2 = look(id)["size"]
	return size - Vector2.ONE * (2.0 * FLARE + 0.01)


## A charcoal vertex for the wood shader: R how hot it sits, G 1 (the bed: always
## charred, it glows in its hot spots).
static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, hot: float) -> void:
	st.set_color(Color(hot, 1.0, 0.0, 1.0))
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)


# --- The whole thing --------------------------------------------------------------------

## The grill with its charcoal as one set of surfaces (the item, the placement preview).
static func add_whole(out: Array, id: StringName) -> void:
	MeshMerge.add_mesh(out, body_mesh(id))
	MeshMerge.add_mesh(out, coals_mesh(id), Transform3D(Basis(), Vector3(0, bed_y(id), 0)))
