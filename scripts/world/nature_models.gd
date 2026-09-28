@tool
class_name NatureModels
extends RefCounted
## Procedural vegetation and rocks built from photo-textured parts:
## bark-textured trunks and branches, leaf/needle cards cut from scanned foliage
## atlases, and smooth noise-displaced rocks. Meshes are cached per (kind, seed); the
## vegetation meshes are only ever drawn, so they are built indexed (shared vertices).

## Regions of the broadleaf atlas (leaves_broad_albedo.png), UV space.
const BROAD_TWIGS: Array[Rect2] = [Rect2(0.35, 0.06, 0.24, 0.63), Rect2(0.56, 0.03, 0.30, 0.64)]
const BROAD_SCATTER: Array[Rect2] = [Rect2(0.0, 0.02, 0.44, 0.47), Rect2(0.0, 0.5, 0.44, 0.48)]
## Needle twigs in the fir atlas (leaves_fir_albedo.png); the stem end is at the bottom.
const FIR_TWIGS: Array[Rect2] = [Rect2(0.31, 0.40, 0.34, 0.38), Rect2(0.63, 0.44, 0.33, 0.39),
		Rect2(0.19, 0.03, 0.23, 0.28), Rect2(0.65, 0.03, 0.28, 0.34)]

const NEUTRAL := Color(0.5, 0.5, 0.5)
const FLOWER_COLORS: Array[Color] = [Color("f4f1e6"), Color("f7d445"), Color("b48be0"), Color("ef6f5e"), Color("f2a0c8")]

static var _cache: Dictionary = {}
## Rock collision hulls, keyed like the rock meshes in _cache.
static var _rock_shapes: Dictionary = {}


static func _cached(key: String, maker: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


## Card brightness deep inside a far tree's crown (see _crown_shade).
const CROWN_SHADE_DEEP := 0.34


static func _tint(rng: RandomNumberGenerator, amount := 0.08, warm := 0.0) -> Color:
	var v := 0.5 * (1.0 + rng.randf_range(-amount, amount))
	var hue := rng.randf_range(-amount, amount) * 0.5 + warm
	return Color(v * (1.0 + hue), v, v * (1.0 - hue * 0.5))


## Far (shadowless) trees: darkens a card by how deep it sits in the crown, standing in
## for the self-shadowing the detailed trees get from real shadows. `open` is 0 deep
## inside (next to the trunk, under the crown) to 1 at the sunlit outside.
static func _crown_shade(c: Color, open: float) -> Color:
	var k := lerpf(CROWN_SHADE_DEEP, 1.0, clampf(open, 0.0, 1.0))
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _basis_from_dir(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y).normalized())


# --- Broadleaf tree ------------------------------------------------------------------

## Deciduous tree (kept under the old name so callers don't change).
static func oak(seed_value: int, detail := true) -> ArrayMesh:
	return _cached("broad_%d_%s" % [seed_value, detail], _make_broadleaf.bind(seed_value, detail))


static func _make_broadleaf(seed_value: int, detail: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 313 + 11
	var mb := MeshBuilder.new()
	var height := rng.randf_range(6.5, 8.5)
	var trunk_top := height * rng.randf_range(0.42, 0.5)
	var crown_center := Vector3(rng.randf_range(-0.3, 0.3), height * 0.66, rng.randf_range(-0.3, 0.3))
	var crown := Vector3(rng.randf_range(2.4, 3.1), height * 0.3, rng.randf_range(2.4, 3.1))

	# Trunk: a slightly wandering spine with a flared base.
	var spine: Array[Vector3] = [Vector3.ZERO]
	var segs := 4
	for i in range(1, segs + 1):
		var t := float(i) / segs
		spine.append(Vector3(rng.randf_range(-0.12, 0.12) * t, trunk_top * t, rng.randf_range(-0.12, 0.12) * t))
	var r0 := rng.randf_range(0.26, 0.34)
	mb.cylinder(&"bark", Transform3D.IDENTITY, r0 * 1.5, r0, 0.45, 10 if detail else 6, NEUTRAL, true, false)
	for i in segs:
		var ra := lerpf(r0, r0 * 0.62, float(i) / segs)
		var rb := lerpf(r0, r0 * 0.62, float(i + 1) / segs)
		mb.cylinder_between(&"bark", spine[i], spine[i + 1], ra, rb, 10 if detail else 6, NEUTRAL, true, false)

	# Main branches reach into the crown; each ends in a spray of leaf twigs.
	var tips: Array[Vector3] = []
	var branch_count := rng.randi_range(5, 7) if detail else 4
	for b in branch_count:
		var ang := b * 2.39996 + rng.randf_range(-0.3, 0.3)
		var start_t := rng.randf_range(0.7, 1.0)
		var start := spine[segs].lerp(spine[segs - 1], 1.0 - start_t)
		var outward := Vector3(cos(ang), 0.0, sin(ang))
		var dir := (outward * rng.randf_range(0.8, 1.2) + Vector3.UP * rng.randf_range(0.7, 1.3)).normalized()
		var length := rng.randf_range(1.8, 2.8)
		var end := start + dir * length
		mb.cylinder_between(&"bark", start, end, r0 * 0.45, 0.04, 6 if detail else 4, NEUTRAL, true, false)
		tips.append(end)
		if detail:
			for k in 2:
				var sub_start := start.lerp(end, rng.randf_range(0.45, 0.75))
				var sub_dir := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.0, 0.6), rng.randf_range(-0.8, 0.8))).normalized()
				var sub_end := sub_start + sub_dir * rng.randf_range(0.8, 1.4)
				mb.cylinder_between(&"bark", sub_start, sub_end, 0.05, 0.02, 4, NEUTRAL, true, false)
				tips.append(sub_end)
	tips.append(spine[segs] + Vector3(0, height * 0.35, 0))

	# Leaf twigs: sprays at branch tips plus fill across the crown shell.
	var cards := 0
	var spray := 7 if detail else 5
	for tip in tips:
		for i in spray:
			_leaf_twig(mb, tip + _rand_in_sphere(rng) * 0.5, crown_center, rng, 1.0, crown, detail)
			cards += 1
	var fill := 110 if detail else 75
	for i in fill:
		var p := crown_center + _rand_in_sphere(rng).normalized() * crown * sqrt(rng.randf_range(0.35, 1.0))
		_leaf_twig(mb, p, crown_center, rng, 0.9, crown, detail)
	mb.set_sway_by_height(&"bark", trunk_top * 0.7, height, 0.35)
	return mb.build({}, true)


## One compound-leaf twig card: base at `base`, pointing roughly away from the crown center.
static func _leaf_twig(mb: MeshBuilder, base: Vector3, center: Vector3, rng: RandomNumberGenerator,
		scale: float, crown := Vector3.ONE, detail := true) -> void:
	var out := (base - center).normalized()
	var dir := (out + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.3, 0.7), rng.randf_range(-0.6, 0.6))).normalized()
	var use_scatter := rng.randf() < 0.3
	var rect: Rect2 = BROAD_SCATTER[rng.randi() % 2] if use_scatter else BROAD_TWIGS[rng.randi() % 2]
	var length := rng.randf_range(1.0, 1.35) * scale
	var width := length * rect.size.x / rect.size.y
	if use_scatter:
		width = length * 0.95
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	side = side.rotated(dir, rng.randf_range(-0.9, 0.9))
	var shade := (out * 0.75 + Vector3.UP * 0.35).normalized()
	var tint := _tint(rng, 0.1)
	if not detail:
		# Deeper in the crown and on its underside is darker.
		var rel := (base - center) / crown
		tint = _crown_shade(tint, rel.length() * 0.8 + rel.y * 0.35)
	mb.card(&"leaves" if detail else &"leaves_far", base + dir * length * 0.5, side * width, dir * length, rect, shade,
			tint, 0.85, 1.0)


static func _rand_in_sphere(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length_squared() <= 1.0 and v.length_squared() > 0.01:
			return v
	return Vector3.UP


# --- Conifer ---------------------------------------------------------------------

## Fir-like conifer (kept under the old name so callers don't change).
static func pine(seed_value: int, detail := true) -> ArrayMesh:
	return _cached("fir_%d_%s" % [seed_value, detail], _make_fir.bind(seed_value, detail))


static func _make_fir(seed_value: int, detail: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 101 + 3
	var mb := MeshBuilder.new()
	var height := rng.randf_range(8.0, 11.0)
	var r0 := rng.randf_range(0.22, 0.3)
	mb.cylinder(&"bark_pine", Transform3D.IDENTITY, r0 * 1.4, r0, 0.4, 9 if detail else 6, NEUTRAL, true, false)
	# Far trees hide most of the trunk inside the crown so they don't read as poles.
	var trunk_top := height - 0.4 if detail else height * 0.7
	mb.cylinder(&"bark_pine", Transform3D(Basis(), Vector3(0, 0.4, 0)), r0, 0.03 if detail else 0.08, trunk_top - 0.4, 9 if detail else 6, NEUTRAL, true, false)

	var first := rng.randf_range(1.3, 1.9)
	var spacing := 0.5 if detail else 0.62
	var max_len := rng.randf_range(2.3, 2.9)
	var y := first
	var whorl := 0
	while y < height - 0.6:
		var t := (y - first) / (height - first)
		var length := max_len * pow(1.0 - t, 0.85) + 0.35
		var branches := rng.randi_range(5, 7) if detail else 5
		for b in branches:
			var ang := TAU * float(b) / branches + whorl * 0.7 + rng.randf_range(-0.2, 0.2)
			var droop := rng.randf_range(-0.35, -0.1) + t * 0.25
			var dir := Vector3(cos(ang), droop, sin(ang)).normalized()
			var start := Vector3(0, y, 0)
			var end := start + dir * length
			if detail and t < 0.6:
				mb.cylinder_between(&"bark_pine", start, start.lerp(end, 0.85), 0.035, 0.012, 4, NEUTRAL, true, false)
			_fir_branch_cards(mb, start, dir, length, rng, detail, t)
		y += spacing * rng.randf_range(0.85, 1.15)
		whorl += 1
	# Spire.
	for i in 3:
		var a := TAU * i / 3.0
		var dir := Vector3(cos(a) * 0.25, 1.0, sin(a) * 0.25).normalized()
		var side := dir.cross(Vector3(cos(a), 0, sin(a))).normalized()
		mb.card(&"needles" if detail else &"needles_far", Vector3(0, height - 0.55, 0) + dir * 0.45, side * 0.6, dir * 1.0, FIR_TWIGS[2],
				(dir + Vector3(cos(a), 0, sin(a))).normalized(), _tint(rng, 0.06), 0.6, 1.0)
	mb.set_sway_by_height(&"needles", 0.0, height, 1.0)
	mb.set_sway_by_height(&"needles_far", 0.0, height, 1.0)
	mb.set_sway_by_height(&"bark_pine", height * 0.3, height, 0.4)
	return mb.build({}, true)


static func _fir_branch_cards(mb: MeshBuilder, start: Vector3, dir: Vector3, length: float,
		rng: RandomNumberGenerator, detail: bool, height_t := 1.0) -> void:
	var outward := Vector3(dir.x, 0.0, dir.z).normalized()
	var count := maxi(1, int(ceil(length / (0.55 if detail else 0.7))))
	for i in count:
		var along := (float(i) + 0.5) / count
		var size := lerpf(0.95, 0.65, along) * clampf(length / 1.6, 0.6, 1.25) * (1.0 if detail else 1.5)
		var base := start + dir * length * along * 0.8
		# Card lies roughly along the branch, needles fanning sideways; a second card
		# is rolled around the branch for thickness.
		# Two cards rolled around the branch so foliage reads from the side too.
		var flip := 1.0 if rng.randf() < 0.5 else -1.0
		var rolls := [rng.randf_range(-0.3, 0.3), rng.randf_range(0.9, 1.3) * flip] if detail \
				else [rng.randf_range(0.95, 1.2) * flip, -rng.randf_range(0.2, 0.45) * flip]
		for roll: float in rolls:
			var side := dir.cross(Vector3.UP).normalized().rotated(dir, roll)
			var rect: Rect2 = FIR_TWIGS[rng.randi() % FIR_TWIGS.size()]
			var w := size * rect.size.x / rect.size.y * 1.2
			var shade := (outward * 0.6 + Vector3.UP * 0.55).normalized()
			var tint := _tint(rng, 0.08, -0.02)
			if not detail:
				# Near the trunk and on the lower whorls (under the rest of the crown) is darker.
				tint = _crown_shade(tint, along * 0.75 + height_t * 0.45)
			mb.card(&"needles" if detail else &"needles_far", base + dir * size * 0.5, side * w, dir * size, rect, shade,
					tint)


# --- Distant impostors ------------------------------------------------------------------
# The far hill forest is drawn as camera-facing cards showing a picture of the real
# tree (tools/tree_impostors.gd renders the atlas): one layer per tree instead of a
# few hundred overlapping leaf cards.

const IMPOSTOR_ATLAS := "res://art/textures/impostors/forest.png"
## Cell height / width in the atlas.
const IMPOSTOR_ASPECT := 1.5


## The hill forest trees, in atlas order.
static func forest_meshes() -> Array[Mesh]:
	return [pine(4, false), pine(5, false), pine(6, false), oak(4, false), oak(5, false)]


## World size (width, height) of a tree's picture: base at the bottom edge, trunk centred.
static func impostor_frame(mesh: Mesh) -> Vector2:
	var box := mesh.get_aabb()
	var half := maxf(maxf(-box.position.x, box.end.x), maxf(-box.position.z, box.end.z))
	var h := maxf(box.end.y * 1.02, half * 2.0 * IMPOSTOR_ASPECT)
	return Vector2(h / IMPOSTOR_ASPECT, h)


## Unit card for the impostor shader: x across (-0.5..0.5), y up (0..1).
static func impostor_card() -> ArrayMesh:
	if _cache.has("impostor_card"):
		return _cache["impostor_card"]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tree_impostor.gdshader")
	mat.set_shader_parameter("atlas", load(IMPOSTOR_ATLAS))
	mat.set_shader_parameter("cells", float(forest_meshes().size()))
	# Matches the leaf-card trees' average brightness (measured side by side).
	mat.set_shader_parameter("brightness", 1.06)
	m.surface_set_material(0, mat)
	# The card turns to face the camera: cull it as the whole tree volume.
	var widest := 0.0
	var tallest := 0.0
	for tree in forest_meshes():
		var f := impostor_frame(tree)
		widest = maxf(widest, f.x)
		tallest = maxf(tallest, f.y)
	m.custom_aabb = AABB(Vector3(-widest * 0.5, 0, -widest * 0.5), Vector3(widest, tallest, widest))
	_cache["impostor_card"] = m
	return m


# --- Bushes ------------------------------------------------------------------------

static func bush(seed_value: int) -> ArrayMesh:
	return _cached("bush_%d" % seed_value, _make_bush.bind(seed_value))


static func _make_bush(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 71 + 5
	var mb := MeshBuilder.new()
	var center := Vector3(0, 0.55, 0)
	var radius := Vector3(rng.randf_range(0.8, 1.1), 0.55, rng.randf_range(0.8, 1.1))
	for i in 5:
		var tip := center + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.4), rng.randf_range(-0.5, 0.5))
		mb.cylinder_between(&"bark", Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)), tip, 0.03, 0.012, 4, NEUTRAL, true, false)
	for i in 34:
		var p := center + _rand_in_sphere(rng).normalized() * radius * sqrt(rng.randf_range(0.3, 1.0))
		p.y = maxf(p.y, 0.15)
		_leaf_twig(mb, p, center - Vector3(0, 0.3, 0), rng, 0.62)
	mb.set_sway_by_height(&"leaves", 0.0, 1.4, 0.45)
	return mb.build({}, true)


# --- Rocks -----------------------------------------------------------------------

static func rock(seed_value: int, size := 1.0) -> ArrayMesh:
	return _cached(_rock_key(seed_value, size), _make_rock.bind(seed_value, size))


## Collision hull of rock(seed_value, size), shared by every rock of that shape. It is
## made from the generated vertices, so the mesh is never read back from the GPU.
static func rock_shape(seed_value: int, size := 1.0) -> ConvexPolygonShape3D:
	rock(seed_value, size)
	return _rock_shapes[_rock_key(seed_value, size)]


static func _rock_key(seed_value: int, size: float) -> String:
	return "rock_%d_%.2f" % [seed_value, size]


static func _make_rock(seed_value: int, size: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + 1
	var mb := MeshBuilder.new()
	var scale := Vector3(rng.randf_range(1.0, 1.45), rng.randf_range(0.55, 0.8), rng.randf_range(0.85, 1.2)) * size
	var xf := Transform3D(Basis.from_scale(scale).rotated(Vector3.UP, rng.randf() * TAU), Vector3(0, 0.22 * scale.y, 0))
	mb.blob(&"rock", xf, 0.85, 3, NEUTRAL, 0.38, 1.3, seed_value, 0.0, true, -0.35)
	if rng.randf() < 0.55:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0.0, sin(a)) * 1.05 * size
		mb.blob(&"rock", Transform3D(Basis.from_scale(Vector3(1.1, 0.65, 0.9)), p), 0.36 * size, 2, NEUTRAL,
				0.35, 1.8, seed_value + 5, 0.0, true, -0.3)
	var hull := ConvexPolygonShape3D.new()
	hull.points = mb.vertices()
	_rock_shapes[_rock_key(seed_value, size)] = hull
	return mb.build()


# --- Ground cover ------------------------------------------------------------------

## Clump of grass blades. UV.x = blade height (m), UV.y = 0 at root .. 1 at tip.
static func grass_clump(seed_value: int, blades := 7) -> ArrayMesh:
	return _cached("grass_%d_%d" % [seed_value, blades], _make_grass.bind(seed_value, blades))


static func _make_grass(seed_value: int, blades: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 53 + 9
	var mb := MeshBuilder.new()
	var white := Color.WHITE
	for i in blades:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.2)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0, sin(facing))
		var lean := Vector3(-side.z, 0, side.x) * rng.randf_range(0.05, 0.25)
		var h := rng.randf_range(0.26, 0.62)
		var w := rng.randf_range(0.022, 0.04)
		var up := Vector3.UP
		var p0 := root - side * w * 0.5
		var p1 := root + side * w * 0.5
		var mid := root + up * h * 0.55 + lean * 0.35
		var p2 := mid - side * w * 0.36
		var p3 := mid + side * w * 0.36
		var tip := root + up * h + lean
		var n := up
		mb.tri_n(&"grass", p0, p1, p3, n, n, n, white, white, white, Vector2(h, 0), Vector2(h, 0), Vector2(h, 0.55))
		mb.tri_n(&"grass", p0, p3, p2, n, n, n, white, white, white, Vector2(h, 0), Vector2(h, 0.55), Vector2(h, 0.55))
		mb.tri_n(&"grass", p2, p3, tip, n, n, n, white, white, white, Vector2(h, 0.55), Vector2(h, 0.55), Vector2(h, 1.0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	return mb.build({&"grass": mat}, true)


static func flower(seed_value: int) -> ArrayMesh:
	return _cached("flower_%d" % seed_value, _make_flower.bind(seed_value))


static func _make_flower(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 29 + 7
	var mb := MeshBuilder.new()
	var petal: Color = FLOWER_COLORS[seed_value % FLOWER_COLORS.size()]
	var stem := Color("4f7a34")
	var count := rng.randi_range(2, 4)
	for i in count:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.15)
		var h := rng.randf_range(0.25, 0.42)
		var head := root + Vector3(rng.randf_range(-0.04, 0.04), h, rng.randf_range(-0.04, 0.04))
		mb.cylinder_between(&"evergreen", root, head, 0.008, 0.006, 3, stem, false, false)
		var petals := 6
		for p in petals:
			var pa := TAU * float(p) / petals + rng.randf() * 0.3
			var dir := Vector3(cos(pa), 0.2, sin(pa))
			mb.leaf(&"evergreen", head, dir, Vector3.UP, 0.05, 0.035, petal)
		mb.blob(&"evergreen", Transform3D(Basis(), head + Vector3(0, 0.008, 0)), 0.013, 0, Color("e9b93a"))
	mb.set_sway_by_height(&"evergreen", 0.0, 0.45, 0.6)
	return mb.build({}, true)
