@tool
class_name NatureModels
extends RefCounted
## Vegetation and rocks. Trees are built from film-quality Poly Haven tree models (see
## "Trees" below: real trunks and limbs, crowns as cards of rendered twig clusters, with
## levels of detail and eight-sided impostors). Bushes are procedural: leafy twig cards
## cut from a composed atlas (tools/build_foliage.gd), shaded darker deeper inside.
## Rocks, ferns, nettles, fallen branches, stumps and logs are photo-scans (Poly Haven,
## CC0, art/models/nature) with their own material (shaders/nature_scan*.gdshader).
## Meshes are cached per (kind, seed); the vegetation meshes are only ever drawn, so
## they are built indexed (shared vertices).

## Regions of the broadleaf atlas (leaves_broad_albedo.png), UV space (crops use them).
const BROAD_TWIGS: Array[Rect2] = [Rect2(0.35, 0.06, 0.24, 0.63), Rect2(0.56, 0.03, 0.30, 0.64)]
const BROAD_SCATTER: Array[Rect2] = [Rect2(0.0, 0.02, 0.44, 0.47), Rect2(0.0, 0.5, 0.44, 0.48)]
## Needle twigs in the fir atlas (leaves_fir_albedo.png); the stem end is at the bottom.
const FIR_TWIGS: Array[Rect2] = [Rect2(0.31, 0.40, 0.34, 0.38), Rect2(0.63, 0.44, 0.33, 0.39),
		Rect2(0.19, 0.03, 0.23, 0.28), Rect2(0.65, 0.03, 0.28, 0.34)]
## Leafy twig sprays of the cluster atlas (leaves_cluster), stem end at the bottom middle.
const LEAF_SPRAYS: Array[Rect2] = [Rect2(0.0, 0.0, 0.5, 0.5), Rect2(0.5, 0.0, 0.5, 0.5),
		Rect2(0.0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]

const NEUTRAL := Color(0.5, 0.5, 0.5)
const FLOWER_COLORS: Array[Color] = [Color("f4f1e6"), Color("f7d445"), Color("b48be0"), Color("ef6f5e"), Color("f2a0c8")]

static var _cache: Dictionary = {}
## Rock collision hulls, keyed like the rock meshes in _cache.
static var _rock_shapes: Dictionary = {}
## Crown of each built tree mesh (keyed by the mesh): [crown bottom, top, radius, broadleaf].
static var _crowns: Dictionary = {}


static func _cached(key: String, maker: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


## Brightness of a card deep inside a crown (next to the trunk, under the crown)
## relative to one on its sunlit outside: the self-shadowing and lost sky light the
## vertex colour carries (also ambient occlusion in shaders/foliage_card.gdshader).
## Bushes, which have real shadows, use the near one.
const CROWN_SHADE_NEAR := 0.7
const CROWN_SHADE_FAR := 0.42


static func _tint(rng: RandomNumberGenerator, amount := 0.08, warm := 0.0) -> Color:
	var v := 0.5 * (1.0 + rng.randf_range(-amount, amount))
	var hue := rng.randf_range(-amount, amount) * 0.5 + warm
	return Color(v * (1.0 + hue), v, v * (1.0 - hue * 0.5))


## Darkens a card colour by how deep it sits in the crown: `open` is 0 deep inside
## (next to the trunk, under the crown) to 1 at the sunlit outside.
static func _crown_shade(c: Color, open: float, deep := CROWN_SHADE_FAR) -> Color:
	var k := lerpf(deep, 1.0, clampf(open, 0.0, 1.0))
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _basis_from_dir(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y).normalized())


## How far a foliage card's lighting normal leans from the crown's towards the card's.
const CARD_FACING := 0.8


## A foliage card growing from `base` along `up` (full length), `right` wide, with the
## stem end of the atlas cell at `base`. The colour runs from `c_base` at the stem to
## `c_tip`, so a branch darkens towards the trunk; `n` is the lighting normal.
static func _stem_card(mb: MeshBuilder, key: StringName, base: Vector3, right: Vector3, up: Vector3,
		rect: Rect2, n: Vector3, c_base: Color, c_tip: Color, sway_base := 1.0, sway_tip := 1.0) -> void:
	var r := right * 0.5
	var bl := base - r
	var br := base + r
	var tr := base + r + up
	var tl := base - r + up
	var uv_bl := Vector2(rect.position.x, rect.end.y)
	var uv_br := rect.end
	var uv_tr := Vector2(rect.end.x, rect.position.y)
	var uv_tl := rect.position
	# Leaned towards the card's own facing (on the side the crown normal is on): the
	# shadows' normal bias follows this normal, and one lying in the card's plane would
	# let the card shadow itself in stripes (acne).
	var facing := right.cross(up).normalized()
	if facing.dot(n) < 0.0:
		facing = -facing
	n = (n.normalized() + facing * CARD_FACING).normalized()
	var cb := Color(c_base.r, c_base.g, c_base.b, sway_base)
	var ct := Color(c_tip.r, c_tip.g, c_tip.b, sway_tip)
	mb.tri_n(key, bl, br, tr, n, n, n, cb, cb, ct, uv_bl, uv_br, uv_tr)
	mb.tri_n(key, bl, tr, tl, n, n, n, cb, ct, ct, uv_bl, uv_tr, uv_tl)


# --- Trees -----------------------------------------------------------------------------
# Built from Poly Haven's film-quality tree models (every needle and leaf modelled) by
# tools/fetch_trees.py and Blender (tools/blender/build_trees.py), into
# art/models/trees/<tree>.glb: the real trunk and limbs, and the crown as a cloud of
# cards, each showing a rendered cluster of the real twigs and leaves with its normal
# map and the crown's self-shading. Three levels of detail per part, joined into one
# mesh here (Godot picks the level by distance: LOD_KEYS); past them, pictures of the
# whole tree from eight sides (the impostors, one atlas for all trees).

const TREE_DIR := "res://art/models/trees/"
## The trees, in impostor atlas order (tools/blender/build_trees.py TREE_ORDER).
const TREES: Array[String] = ["fir_a", "fir_b", "fir_c", "pine_a", "pine_b", "pine_c", "broadleaf", "olive", "locust"]
## The valley's choppable trees and the town's by variant (1..3): conifers and broadleaf.
const CONIFER_VARIANTS: Array[String] = ["fir_b", "pine_b", "pine_c"]
const BROADLEAF_VARIANTS: Array[String] = ["broadleaf", "olive", "locust"]
## Godot's LOD keys for levels 1 and 2: at lod_bias 1 a 1600 px wide view switches at
## about 586 x key metres (so ~23 m and ~53 m); the graphics presets scale this with
## GeometryInstance3D.lod_bias (NatureSpawner.LOD_BIAS).
const LOD_KEYS: Array[float] = [0.04, 0.09]
## Card height / width of the impostor pictures.
const IMPOSTOR_ASPECT := 2.0
const IMPOSTOR_ATLAS := TREE_DIR + "textures/impostors.webp"
const IMPOSTOR_NORMALS := TREE_DIR + "textures/impostors_nor.webp"
const IMPOSTOR_VIEWS := 8

## Look of each tree's leaf cards (shaders/tree_leaves.gdshader uniforms).
## Needle sprays are finer than a texel of the atlas, so the conifers cut out lower.
const CONIFER_LOOK := {"translucency": 0.3, "crown_blend": 0.4, "brightness": 1.0, "tint": Color(0.97, 1.0, 0.97),
	"alpha_cut": 0.3, "mip_alpha": 0.45, "specular": 0.12, "roughness": 0.82,
	"sway": 0.2, "branch_sway": 0.07, "flutter": 0.01}
const BROADLEAF_LOOK := {"translucency": 0.55, "crown_blend": 0.5, "brightness": 1.0, "tint": Color(1.0, 1.0, 1.0),
	"alpha_cut": 0.42, "mip_alpha": 0.35, "specular": 0.25, "roughness": 0.72,
	"sway": 0.22, "branch_sway": 0.12, "flutter": 0.03, "deciduous": 1.0}

## Tree name of each built tree mesh.
static var _tree_names: Dictionary = {}
## Leaf materials of the trees (NatureSpawner sets how far the sun's shadows reach).
static var _leaf_mats: Array[ShaderMaterial] = []


## A conifer for the valley and the town, by variant (1..3). `_detail` is unused: the
## mesh has its own levels of detail.
static func pine(seed_value: int, _detail := true) -> ArrayMesh:
	return tree(CONIFER_VARIANTS[(maxi(seed_value, 1) - 1) % CONIFER_VARIANTS.size()])


## A broadleaf tree by variant (1..3), see pine().
static func oak(seed_value: int, _detail := true) -> ArrayMesh:
	return tree(BROADLEAF_VARIANTS[(maxi(seed_value, 1) - 1) % BROADLEAF_VARIANTS.size()])


## What tools/blender/build_trees.py wrote about a tree: height, radius, crown centre
## and radii (metres, Y up), impostor frame, texture names.
static func tree_info(tree_name: String) -> Dictionary:
	var key := "info_" + tree_name
	if not _cache.has(key):
		_cache[key] = (load(TREE_DIR + tree_name + ".json") as JSON).data
	return _cache[key]


static func tree(tree_name: String) -> ArrayMesh:
	return _cached("tree_" + tree_name, _make_tree.bind(tree_name))


static func _make_tree(tree_name: String) -> ArrayMesh:
	var info := tree_info(tree_name)
	var scene := load(TREE_DIR + tree_name + ".glb") as PackedScene
	var root := scene.instantiate()
	var parts := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		parts[String(mi.name)] = mi.mesh
	root.free()
	var m := ArrayMesh.new()
	for part: String in ["trunk", "branches", "cards"]:
		if not parts.has(part + "_lod0"):
			continue
		var levels: Array[Mesh] = []
		for level in 3:
			levels.append(parts.get("%s_lod%d" % [part, level]))
		_add_levels(m, levels)
		m.surface_set_material(m.get_surface_count() - 1, _tree_material(tree_name, part, info))
	var c: Array = info["crown"]["center"]
	var r: Array = info["crown"]["radius"]
	_crowns[m] = [float(c[1]) - float(r[1]), float(c[1]) + float(r[1]), maxf(float(r[0]), float(r[2])), bool(info["broad"])]
	_tree_names[m] = tree_name
	return m


## One surface from a part's levels of detail: all their vertices, level 0's triangles,
## the others as LOD index arrays.
static func _add_levels(m: ArrayMesh, levels: Array[Mesh]) -> void:
	var base: Array = levels[0].surface_get_arrays(0)
	var lods := {}
	for level in range(1, levels.size()):
		if levels[level] == null:
			continue
		var a: Array = levels[level].surface_get_arrays(0)
		var offset := (base[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for ch in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2,
				Mesh.ARRAY_COLOR]:
			if base[ch] == null or a[ch] == null:
				base[ch] = null
				continue
			var joined = base[ch]
			joined.append_array(a[ch])
			base[ch] = joined
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i in idx.size():
			idx[i] += offset
		lods[LOD_KEYS[level - 1]] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base, [], lods)


static func _tree_material(tree_name: String, part: String, info: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var tex := TREE_DIR + "textures/"
	var look: Dictionary = BROADLEAF_LOOK if info["broad"] else CONIFER_LOOK
	if part == "cards":
		mat.shader = load("res://shaders/tree_leaves.gdshader")
		var albedo := load(tex + String(info["leaves"])) as Texture2D
		mat.set_shader_parameter("albedo_tex", albedo)
		mat.set_shader_parameter("normal_tex", load(tex + String(info["leaves_nor"])))
		mat.set_shader_parameter("tex_size", float(albedo.get_width()))
		for k: String in look:
			mat.set_shader_parameter(k, look[k])
		_leaf_mats.append(mat)
	else:
		var bark: Dictionary = info["bark"][part]
		mat.shader = load("res://shaders/tree_bark.gdshader")
		mat.set_shader_parameter("albedo_tex", load(tex + String(bark["diff"])))
		mat.set_shader_parameter("normal_tex", load(tex + String(bark["nor"])))
		if bark.has("arm"):
			mat.set_shader_parameter("arm_tex", load(tex + String(bark["arm"])))
		for k: String in ["sway", "branch_sway"]:
			mat.set_shader_parameter(k, look[k])
		mat.set_shader_parameter("flutter", 0.0)
	return mat


## The leaf materials of the trees built so far.
static func leaf_materials() -> Array[ShaderMaterial]:
	return _leaf_mats


# --- Hill forest -----------------------------------------------------------------------

## Which of forest_meshes() are broadleaf (autumn colours, leaf fall).
static func forest_broad() -> Array[bool]:
	var out: Array[bool] = []
	for t in TREES:
		out.append(bool(tree_info(t)["broad"]))
	return out


## The hill forest trees, in atlas order.
static func forest_meshes() -> Array[Mesh]:
	var out: Array[Mesh] = []
	for t in TREES:
		out.append(tree(t))
	return out


## Indices into forest_meshes() of the conifers and of the broadleaf trees.
static func forest_kinds(broad: bool) -> Array[int]:
	var out: Array[int] = []
	var flags := forest_broad()
	for i in flags.size():
		if flags[i] == broad:
			out.append(i)
	return out


## World size (width, height) of a tree's picture: base at the bottom edge, trunk centred.
static func impostor_frame(mesh: Mesh) -> Vector2:
	var imp: Dictionary = tree_info(_tree_names[mesh])["impostor"]
	return Vector2(float(imp["width"]), float(imp["height"]))


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
	mat.set_shader_parameter("normal_atlas", load(IMPOSTOR_NORMALS))
	mat.set_shader_parameter("rows", float(TREES.size()))
	mat.set_shader_parameter("views", float(IMPOSTOR_VIEWS))
	m.surface_set_material(0, mat)
	# The card turns to face the camera: cull it as the whole tree volume.
	var widest := 0.0
	var tallest := 0.0
	for t in forest_meshes():
		var f := impostor_frame(t)
		widest = maxf(widest, f.x)
		tallest = maxf(tallest, f.y)
	m.custom_aabb = AABB(Vector3(-widest * 0.5, 0, -widest * 0.5), Vector3(widest, tallest, widest))
	_cache["impostor_card"] = m
	return m


# --- Shadow proxies ------------------------------------------------------------------
# On the lower graphics presets the hill forest's leaf cards cast no shadows (thousands
# of alpha-tested cards in every shadow cascade; see NatureSpawner.CARD_SHADOWS).
# Instead each tree casts the shadow of a plain cone or ellipsoid a little inside its
# crown, holed in patches so the shade is dappled with sun flecks: it falls on the
# forest floor and on the tree's own inner and far-side branches.

## Unit shadow shape: a lumpy cone (base radius about 1 at y 0, tip at y 1) for
## conifers, or a lumpy ellipsoid (radius 1 round (0, 0.5, 0), 1 tall) for broadleaf
## trees. The lumps break up the shadow's outline like whorls and lobes do.
static func shadow_shape(broad: bool) -> ArrayMesh:
	var key := "shadow_%s" % broad
	if _cache.has(key):
		return _cache[key]
	var mb := MeshBuilder.new()
	if broad:
		mb.blob(&"shadow", Transform3D(Basis.from_scale(Vector3(1.0, 0.5, 1.0)), Vector3(0, 0.5, 0)), 1.0, 1, NEUTRAL,
				0.45, 1.6, 3)
	else:
		# Tiers like the whorls of branches (a jagged, layered outline, not a smooth cone).
		var sides := 9
		var tiers := 5
		var rng := RandomNumberGenerator.new()
		rng.seed = 12
		for k in tiers:
			var y0 := 0.88 * k / tiers
			var y1 := y0 + 0.32
			var r0 := (1.0 - y0) * rng.randf_range(0.9, 1.1)
			var turn := rng.randf() * TAU
			var bottom := PackedVector3Array()
			for i in sides:
				var a := turn + TAU * i / sides
				var r := r0 * rng.randf_range(0.72, 1.12)
				bottom.append(Vector3(cos(a) * r, y0 + rng.randf_range(-0.03, 0.05), sin(a) * r))
			var tip := Vector3(0, minf(y1, 1.0), 0)
			for i in sides:
				mb.tri(&"shadow", bottom[i], tip, bottom[(i + 1) % sides], NEUTRAL)
				mb.tri(&"shadow", bottom[i], bottom[(i + 1) % sides], Vector3(0, y0, 0), NEUTRAL)
	var m := mb.build({&"shadow": _shadow_material()})
	_cache[key] = m
	return m


## Dappled: holes in patches let sun flecks through (shaders/tree_shadow.gdshader).
## Either winding casts: the shapes are only ever drawn into shadow maps.
static func _shadow_material() -> Material:
	if not _cache.has("shadow_mat"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/tree_shadow.gdshader")
		_cache["shadow_mat"] = mat
	return _cache["shadow_mat"]


## Transform of a tree's shadow shape (shadow_shape) relative to the tree: its crown,
## a little smaller so the outer foliage stays sunlit.
static func shadow_transform(mesh: Mesh) -> Transform3D:
	var crown: Array = _crowns.get(mesh, [2.0, 10.0, 3.0, false])
	var bottom: float = crown[0]
	var top: float = crown[1]
	var radius: float = crown[2]
	if crown[3]:
		return Transform3D(Basis.from_scale(Vector3(radius * 0.6, (top - bottom) * 0.72, radius * 0.6)),
				Vector3(0, bottom + (top - bottom) * 0.12, 0))
	return Transform3D(Basis.from_scale(Vector3(radius * 0.52, (top - bottom) * 0.9, radius * 0.52)),
			Vector3(0, bottom + 0.4, 0))


# --- Bushes ------------------------------------------------------------------------

## A shrub: a few stems under two or three low mounds of leafy twigs.
static func bush(seed_value: int) -> ArrayMesh:
	return _cached("bush_%d" % seed_value, _make_bush.bind(seed_value))


static func _make_bush(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 71 + 5
	var mb := MeshBuilder.new()
	var center := Vector3(0, 0.55, 0)
	var radius := Vector3(rng.randf_range(0.85, 1.15), 0.62, rng.randf_range(0.85, 1.15))
	var mounds: Array[Array] = []
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		mounds.append([center + Vector3(cos(a) * 0.35, rng.randf_range(-0.05, 0.15), sin(a) * 0.35), rng.randf_range(0.6, 0.8)])
	for i in 6:
		var tip := center + Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(0.0, 0.45), rng.randf_range(-0.55, 0.55))
		mb.cylinder_between(&"bark", Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12)), tip, 0.03, 0.01,
				4, NEUTRAL, true, false)
	for m: Array in mounds:
		var c: Vector3 = m[0]
		var r: float = m[1]
		for i in int(r * r * 30.0):
			var out := _rand_in_sphere(rng).normalized()
			out.y = absf(out.y) * 0.8 + 0.1
			out = out.normalized()
			var p := c + out * r * rng.randf_range(0.35, 0.8)
			p.y = maxf(p.y, 0.12)
			_leaf_card(mb, &"leaves", p, out, c, center, radius, rng, rng.randf_range(0.7, 0.95), CROWN_SHADE_NEAR)
	mb.set_sway_by_height(&"leaves", 0.0, 1.4, 0.45)
	return mb.build({}, true)


## One leafy twig card growing from `p` out of its lobe (centred at `lobe`), lit with a
## normal between the lobe's and the whole crown's, darker deeper in the crown.
static func _leaf_card(mb: MeshBuilder, key: StringName, p: Vector3, out: Vector3, lobe: Vector3,
		crown_center: Vector3, crown: Vector3, rng: RandomNumberGenerator, length: float, deep: float) -> void:
	var dir := (out + Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.2, 0.45), rng.randf_range(-0.45, 0.45))).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	side = side.rotated(dir, rng.randf_range(-1.2, 1.2))
	var rel := (p - crown_center) / crown
	var n := (out * 0.55 + rel.normalized() * 0.35 + Vector3.UP * 0.25).normalized()
	var tint := _tint(rng, 0.1)
	# Deeper in the crown and on its underside is darker; the twig's stem end is
	# further in than its tip.
	var depth := clampf(rel.length(), 0.0, 1.2)
	var open := depth * 0.75 + rel.y * 0.3 + 0.1
	var base := p - dir * length * 0.3
	_stem_card(mb, key, base, side * length, dir * length, LEAF_SPRAYS[rng.randi() % LEAF_SPRAYS.size()], n,
			_crown_shade(tint, open - 0.3, deep), _crown_shade(tint, open + 0.15, deep), 0.85, 1.0)


static func _rand_in_sphere(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length_squared() <= 1.0 and v.length_squared() > 0.01:
			return v
	return Vector3.UP


# --- Scanned nature models ------------------------------------------------------------

## Poly Haven scans (see art/models/nature/CREDITS.md): glTF path and texture resolution.
const SCANS := {
	"rock_moss_set_01": ["res://art/models/nature/rock_moss_set_01/rock_moss_set_01_2k.gltf", "2k"],
	"rock_moss_set_02": ["res://art/models/nature/rock_moss_set_02/rock_moss_set_02_2k.gltf", "2k"],
	"boulder_01": ["res://art/models/nature/boulder_01/boulder_01_2k.gltf", "2k"],
	"rock_09": ["res://art/models/nature/rock_09/rock_09_1k.gltf", "1k"],
	"fern_02": ["res://art/models/nature/fern_02/fern_02_1k.gltf", "1k"],
	"nettle_plant": ["res://art/models/nature/nettle_plant/nettle_plant_1k.gltf", "1k"],
	"dry_branches_medium_01": ["res://art/models/nature/dry_branches_medium_01/dry_branches_medium_01_1k.gltf", "1k"],
	"tree_stump_01": ["res://art/models/nature/tree_stump_01/tree_stump_01_1k.gltf", "1k"],
	"dead_tree_trunk": ["res://art/models/nature/dead_tree_trunk/dead_tree_trunk_1k.gltf", "1k"],
}
## Material settings per scan (shaders/nature_scan*.gdshader uniforms). Scans without
## an ARM map have a plain roughness map.
const SCAN_LOOK := {
	"rock_moss_set_01": {"arm": false, "moss_amount": 0.15, "tint": Color(0.92, 0.92, 0.9), "max_triangles": 6000},
	"rock_moss_set_02": {"arm": false, "moss_amount": 0.2, "tint": Color(0.9, 0.9, 0.88), "max_triangles": 6000},
	"boulder_01": {"moss_amount": 0.3, "tint": Color(0.86, 0.86, 0.86), "max_triangles": 6000},
	"rock_09": {"moss_amount": 0.0, "tint": Color(0.78, 0.76, 0.74), "roughness_mult": 1.5, "max_triangles": 6000},
	"fern_02": {"foliage": true, "sway": 0.06, "tint": Color(1.0, 1.04, 0.95), "soil_height": 0.0},
	"nettle_plant": {"foliage": true, "sway": 0.05, "tint": Color(0.95, 1.0, 0.92), "soil_height": 0.0,
		"max_triangles": 2500},
	"dry_branches_medium_01": {"moss_amount": 0.1, "max_triangles": 2500},
	"tree_stump_01": {"moss_amount": 0.25, "max_triangles": 8000},
	"dead_tree_trunk": {"moss_amount": 0.35, "max_triangles": 8000},
}
## Largest triangle count a scan piece keeps unless SCAN_LOOK says otherwise (denser
## scans are simplified first).
const SCAN_MAX_TRIANGLES := 12000


## Simplified scan pieces saved by tools/bake_nature.gd: <scan>_<piece index>.res
## (ImporterMesh with its LODs), so the game doesn't simplify the dense scans at load.
const SCAN_BAKED := "res://art/models/nature/baked/%s_%d.res"


## The pieces of a scan: [surface arrays (footprint centred on the origin, lowest point
## at y 0, in metres), LODs {size: indices}, node name], ordered by name. Each piece is
## simplified to its triangle limit and has its LODs (baked, or made here once).
static func scan_pieces(scan: String) -> Array:
	var key := "scan_" + scan
	if _cache.has(key):
		return _cache[key]
	var out := []
	if ResourceLoader.exists(SCAN_BAKED % [scan, 0]):
		var i := 0
		while ResourceLoader.exists(SCAN_BAKED % [scan, i]):
			out.append(_piece_from(load(SCAN_BAKED % [scan, i]) as ImporterMesh))
			i += 1
	else:
		for im in build_scan(scan):
			out.append(_piece_from(im))
	_cache[key] = out
	return out


## [arrays, lods, name] of a simplified piece.
static func _piece_from(im: ImporterMesh) -> Array:
	var lods := {}
	for i in im.get_surface_lod_count(0):
		lods[im.get_surface_lod_size(0, i)] = im.get_surface_lod_indices(0, i)
	return [im.get_surface_arrays(0), lods, im.get_surface_name(0)]


## A scan's pieces, each sat on the origin and simplified with its LODs (what
## tools/bake_nature.gd saves), ordered by node name.
static func build_scan(scan: String) -> Array[ImporterMesh]:
	var parts := MeshMerge.scene_parts(load(SCANS[scan][0]) as PackedScene)
	parts.sort_custom(func(a: Array, b: Array) -> bool: return String(a[3]) < String(b[3]))
	var out: Array[ImporterMesh] = []
	var limit: int = (SCAN_LOOK.get(scan, {}) as Dictionary).get("max_triangles", SCAN_MAX_TRIANGLES)
	for part: Array in parts:
		var arrays := _transformed((part[1] as Mesh).surface_get_arrays(0), part[0])
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var box := AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
		arrays[Mesh.ARRAY_VERTEX] = Transform3D(Basis(), Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)) * verts
		for ch in [Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
				Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			arrays[ch] = null
		var im := _simplified(arrays, limit)
		# Keep the node name with the piece.
		var named := ImporterMesh.new()
		var lods := {}
		for i in im.get_surface_lod_count(0):
			lods[im.get_surface_lod_size(0, i)] = im.get_surface_lod_indices(0, i)
		named.add_surface(Mesh.PRIMITIVE_TRIANGLES, im.get_surface_arrays(0), [], lods, null, String(part[3]))
		out.append(named)
	return out


## `arrays` under `xf` (normals and tangents turned with it). Normals are left
## unnormalised: the GPU encoding normalises them.
static func _transformed(arrays: Array, xf: Transform3D) -> Array:
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = xf * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	if arrays[Mesh.ARRAY_NORMAL] != null:
		out[Mesh.ARRAY_NORMAL] = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) \
				* (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
		var b := xf.basis
		for i in range(0, tangents.size(), 4):
			var t := b * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		out[Mesh.ARRAY_TANGENT] = tangents
	return out


## `arrays` cut down to `max_triangles` if denser, with its LODs.
static func _simplified(arrays: Array, max_triangles: int) -> ImporterMesh:
	if arrays[Mesh.ARRAY_INDEX] == null:
		var idx := PackedInt32Array()
		for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			idx.append(i)
		arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	if (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 > max_triangles:
		# The first LOD under the limit becomes the full-detail mesh, simplified again.
		for i in im.get_surface_lod_count(0):
			var li := im.get_surface_lod_indices(0, i)
			if li.size() / 3 <= max_triangles:
				var base := im.get_surface_arrays(0)
				base[Mesh.ARRAY_INDEX] = li
				im = ImporterMesh.new()
				im.add_surface(Mesh.PRIMITIVE_TRIANGLES, base)
				im.generate_lods(25.0, 60.0, [])
				break
	return im


## [arrays, lods] of scan piece `index` under `xf`. `ground_y` is the ground's height in
## the piece's own frame: vertex colour alpha carries the height above it (/ 4 m), for
## the soil and moss the material puts near the ground.
static func _piece(scan: String, index: int, xf := Transform3D.IDENTITY, ground_y := 0.0) -> Array:
	var piece: Array = scan_pieces(scan)[index]
	var src: Array = piece[0]
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var up := absf(xf.basis.y.y)
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		colors[i] = Color(1, 1, 1, clampf((verts[i].y - ground_y) * up / 4.0, 0.0, 1.0))
	var arrays := _transformed(src, xf)
	arrays[Mesh.ARRAY_COLOR] = colors
	var s := xf.basis.get_scale()
	var k := (absf(s.x) + absf(s.y) + absf(s.z)) / 3.0
	var lods := {}
	for size: float in piece[1]:
		lods[size * k] = piece[1][size]
	return [arrays, lods]


## Bounding box of scan piece `index` (its footprint centred, lowest point at y 0).
static func piece_bounds(scan: String, index: int) -> AABB:
	var key := "bounds_%s_%d" % [scan, index]
	if not _cache.has(key):
		var verts: PackedVector3Array = scan_pieces(scan)[index][0][Mesh.ARRAY_VERTEX]
		var box := AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
		_cache[key] = box
	return _cache[key]


## Scan piece `index` as forest-floor clutter: sunk `sink` of its height into the
## ground, shrinking away into it towards `view_range` metres (no popping), cut down
## to its first level of detail under `max_triangles` (small things need few).
static func floor_mesh(scan: String, index: int, sink: float, view_range: float, max_triangles := 100000) -> ArrayMesh:
	var key := "floor_%s_%d_%.2f_%.0f_%d" % [scan, index, sink, view_range, max_triangles]
	if _cache.has(key):
		return _cache[key]
	var p := _piece(scan, index, Transform3D.IDENTITY, piece_bounds(scan, index).size.y * sink)
	var arrays: Array = p[0]
	var lods: Dictionary = p[1]
	if (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 > max_triangles:
		var sizes := lods.keys()
		sizes.sort()
		for size: float in sizes:
			var idx: PackedInt32Array = lods[size]
			if idx.size() / 3 <= max_triangles:
				arrays[Mesh.ARRAY_INDEX] = idx
				break
		# Only the levels coarser than the new full detail stay.
		var kept := {}
		for size: float in sizes:
			if (lods[size] as PackedInt32Array).size() < (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size():
				kept[size] = lods[size]
		lods = kept
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	m.surface_set_material(0, scan_material(scan, view_range))
	_cache[key] = m
	return m


## Scales the view range the forest-floor materials shrink away at (graphics presets).
static func set_floor_range_scale(k: float) -> void:
	for key: String in _cache:
		if key.begins_with("scanmat_"):
			var mat: ShaderMaterial = _cache[key]
			var base: float = mat.get_meta("view_range", 0.0)
			if base > 0.0:
				mat.set_shader_parameter("fade_end", base * k)


## The shared material of a scan's pieces; with a `view_range` (forest-floor clutter)
## they shrink away into the ground before it.
static func scan_material(scan: String, view_range := 0.0) -> ShaderMaterial:
	var key := "scanmat_%s_%.0f" % [scan, view_range]
	if _cache.has(key):
		return _cache[key]
	var look: Dictionary = SCAN_LOOK.get(scan, {})
	var foliage: bool = look.get("foliage", false)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/nature_scan_foliage.gdshader" if foliage else "res://shaders/nature_scan.gdshader")
	var dir := (SCANS[scan][0] as String).get_base_dir() + "/textures/%s_%s_%s.jpg"
	var res: String = SCANS[scan][1]
	var arm: bool = look.get("arm", true)
	mat.set_shader_parameter("albedo_tex", load(dir % [scan, "diff", res]))
	mat.set_shader_parameter("normal_tex", load(dir % [scan, "nor_gl", res]))
	mat.set_shader_parameter("rough_tex", load(dir % [scan, "arm" if arm else "rough", res]))
	mat.set_shader_parameter("arm", arm)
	if foliage:
		mat.set_shader_parameter("alpha_tex", load(dir % [scan, "alpha", res]))
	for k: String in look:
		if k in ["foliage", "arm", "max_triangles"]:
			continue
		mat.set_shader_parameter(k, look[k])
	if view_range > 0.0:
		mat.set_meta("view_range", view_range)
		mat.set_shader_parameter("fade_end", view_range)
	_cache[key] = mat
	return mat


# --- Rocks -----------------------------------------------------------------------

## Scan pieces the breakable rocks wear: [scan, piece index]. Field rocks are the
## mossy granite boulders; quarry rocks (seed >= QUARRY_SEED) the bare, rust-veined ones.
const FIELD_ROCKS := [["rock_moss_set_01", 0], ["rock_moss_set_01", 1], ["rock_moss_set_01", 2], ["rock_moss_set_01", 3],
	["rock_moss_set_01", 4], ["rock_moss_set_01", 5], ["rock_moss_set_02", 0], ["rock_moss_set_02", 1],
	["rock_moss_set_02", 2], ["rock_moss_set_02", 4], ["rock_moss_set_02", 5], ["boulder_01", 0]]
const QUARRY_ROCKS := [["rock_09", 0], ["rock_moss_set_02", 0], ["rock_moss_set_02", 3], ["rock_moss_set_02", 6],
	["boulder_01", 0], ["rock_moss_set_02", 2]]
## Rock seeds from here on are quarry rocks (seed - QUARRY_SEED gives the shape).
const QUARRY_SEED := 100


static func rock(seed_value: int, size := 1.0) -> ArrayMesh:
	return _cached(_rock_key(seed_value, size), _make_rock.bind(seed_value, size))


## Collision hull of rock(seed_value, size), shared by every rock of that shape. It is
## made from the generated vertices, so the mesh is never read back from the GPU.
static func rock_shape(seed_value: int, size := 1.0) -> ConvexPolygonShape3D:
	rock(seed_value, size)
	return _rock_shapes[_rock_key(seed_value, size)]


static func _rock_key(seed_value: int, size: float) -> String:
	return "rock_%d_%.2f" % [seed_value, size]


## A boulder: the collision hull is the rounded shape the rocks always had (one blob and
## sometimes a smaller one beside it); the scanned rocks drawn are fitted into each blob,
## sunk a little into the ground.
static func _make_rock(seed_value: int, size: float) -> ArrayMesh:
	var shape_seed := seed_value % QUARRY_SEED
	var quarry := seed_value >= QUARRY_SEED
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed * 977 + 1
	var main := MeshBuilder.new()
	var scale := Vector3(rng.randf_range(1.0, 1.45), rng.randf_range(0.55, 0.8), rng.randf_range(0.85, 1.2)) * size
	var yaw := rng.randf() * TAU
	var xf := Transform3D(Basis.from_scale(scale).rotated(Vector3.UP, yaw), Vector3(0, 0.22 * scale.y, 0))
	main.blob(&"rock", xf, 0.85, 3, NEUTRAL, 0.38, 1.3, shape_seed, 0.0, true, -0.35)
	var side := MeshBuilder.new()
	var side_at := Vector3.ZERO
	if rng.randf() < 0.55:
		var a := rng.randf() * TAU
		side_at = Vector3(cos(a), 0.0, sin(a)) * 1.05 * size
		side.blob(&"rock", Transform3D(Basis.from_scale(Vector3(1.1, 0.65, 0.9)), side_at), 0.36 * size, 2, NEUTRAL,
				0.35, 1.8, shape_seed + 5, 0.0, true, -0.3)
	var points := main.vertices()
	points.append_array(side.vertices())
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	_rock_shapes[_rock_key(seed_value, size)] = hull
	# The rock origin is 0.15 * size below the ground (NatureSpawner).
	var ground := 0.15 * size
	var pool: Array = QUARRY_ROCKS if quarry else FIELD_ROCKS
	var pick: Array = pool[(shape_seed * 7 + int(size * 10.0)) % pool.size()]
	var p := _fit_scan(pick, main.vertices(), yaw, ground, 0.12)
	if not side.is_empty():
		# The small one beside it is another piece of the same scan (one material).
		var count := scan_pieces(pick[0]).size()
		var small := [pick[0], (int(pick[1]) + 1 + shape_seed) % count]
		p = _concat(p, _fit_scan(small, side.vertices(), yaw + 0.7, ground, 0.1))
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, p[0], [], p[1])
	m.surface_set_material(0, scan_material(pick[0]))
	return m


## [arrays, lods] of a scan piece stretched into the box of `points` (in the frame
## turned by `yaw`), its base sunk `sink` of its height below the box's bottom.
static func _fit_scan(pick: Array, points: PackedVector3Array, yaw: float, ground: float, sink: float) -> Array:
	var turn := Basis(Vector3.UP, yaw)
	var inv := turn.inverse()
	var box := AABB(inv * points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(inv * p)
	var own := piece_bounds(pick[0], pick[1])
	# Lay the piece's long side along the box's long side.
	var swap := (own.size.x > own.size.z) != (box.size.x > box.size.z)
	var tx := box.size.z if swap else box.size.x
	var tz := box.size.x if swap else box.size.z
	var s := Vector3(tx * 0.98 / maxf(own.size.x, 0.01), box.size.y * (1.0 + sink) / maxf(own.size.y, 0.01),
			tz * 0.98 / maxf(own.size.z, 0.01))
	# Keep the scan's proportions within reason (no rubber rocks).
	var mean := pow(s.x * s.y * s.z, 1.0 / 3.0)
	s = s.clamp(Vector3.ONE * mean * 0.7, Vector3.ONE * mean * 1.45)
	var basis := turn * (Basis(Vector3.UP, PI * 0.5) if swap else Basis()) * Basis.from_scale(s)
	var origin := turn * Vector3(box.get_center().x, box.position.y - box.size.y * sink, box.get_center().z)
	return _piece(pick[0], pick[1], Transform3D(basis, origin), (ground - origin.y) / s.y)


## Two [arrays, lods] joined into one (same material): LOD levels are paired in order.
static func _concat(a: Array, b: Array) -> Array:
	var out: Array = (a[0] as Array).duplicate(true)
	var bb: Array = b[0]
	var base := (out[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for ch in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR]:
		if out[ch] != null and bb[ch] != null:
			out[ch].append_array(bb[ch])
	var shifted := func(idx: PackedInt32Array) -> PackedInt32Array:
		var r := idx.duplicate()
		for i in r.size():
			r[i] += base
		return r
	var joined: PackedInt32Array = out[Mesh.ARRAY_INDEX]
	joined.append_array(shifted.call(bb[Mesh.ARRAY_INDEX]))
	out[Mesh.ARRAY_INDEX] = joined
	var ka: Array = (a[1] as Dictionary).keys()
	var kb: Array = (b[1] as Dictionary).keys()
	ka.sort()
	kb.sort()
	var lods := {}
	for i in ka.size():
		var ia: PackedInt32Array = (a[1][ka[i]] as PackedInt32Array).duplicate()
		var ib: PackedInt32Array = b[1][kb[mini(i, kb.size() - 1)]] if not kb.is_empty() else bb[Mesh.ARRAY_INDEX]
		ia.append_array(shifted.call(ib))
		lods[ka[i]] = ia
	return [out, lods]


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
