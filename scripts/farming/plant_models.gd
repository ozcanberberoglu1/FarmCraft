@tool
class_name PlantModels
extends RefCounted
## Crop plants for each growth stage (0 sprout, 1 young, 2 growing, 3 ready).
## A bed is a MultiMesh of one plant: unit_mesh() is a single plant at a stage,
## standing on the origin with its surfaces joined per material, and LAYOUT spreads
## copies of it over the bed, each turned and sized a little differently.
## Corn, wheat and tomatoes are artist/scanned plants (Sketchfab, see
## art/models/crops/CREDITS.md). Potatoes and eggplants wear the tomato plant's foliage
## (the same family), bushier. Carrot, strawberry and pumpkin foliage are
## photo-textured leaf cards. Every crop bears the scanned produce the player harvests
## (GoodsModels), thinned out for the field. tools/bake_tools.gd saves the units to
## BAKED and their browned, withered copies to BAKED_W; warm_units() starts loading
## them all in the background, so a bed never waits on the disk when it grows.

const BED := 2.0
const STEM_GREEN := Color(0.32, 0.5, 0.18)
const WITHER := Color(0.9, 0.62, 0.32)
const BAKED := "res://art/models/crops/baked/%s_%d.res"
const BAKED_W := "res://art/models/crops/baked/%s_%d_w.res"
## Plants heavier than this get LODs (a bed draws 9 to 36 of them, and the far ones
## need far fewer triangles).
const UNIT_LOD_TRIANGLES := 1500
## Leaf-card surfaces whose material comes from Mats even in baked plants.
const LEAF_SURFACES: Array[StringName] = [&"crop_leaves", &"crop_feathery"]
const MAIZE := "res://art/models/crops/maize/scene.gltf"
const WHEAT := "res://art/models/crops/wheat/scene.gltf"
const TOMATO := "res://art/models/crops/tomato_plant/scene.gltf"
const CROPS: Array[StringName] = [&"wheat", &"carrot", &"potato", &"tomato", &"corn", &"eggplant", &"strawberry", &"pumpkin"]
## [rows, columns, jitter (m)] of plants in a bed.
const LAYOUT := {
	&"corn": [3, 3, 0.06], &"wheat": [6, 6, 0.07], &"tomato": [3, 3, 0.05], &"eggplant": [3, 3, 0.05],
	&"potato": [3, 3, 0.06], &"carrot": [4, 5, 0.05], &"strawberry": [3, 3, 0.06], &"pumpkin": [1, 1, 0.1],
}
## Maize scan parts by node name: the roots stay under the soil, the ears (with their
## silks) come at harvest time, the tassel once the plant is tall.
const MAIZE_ROOTS: Array[String] = ["defaultMaterial", "defaultMaterial2", "defaultMaterial3", "defaultMaterial6",
	"defaultMaterial7"]
const MAIZE_EARS: Array[String] = ["defaultMaterial4", "defaultMaterial5", "defaultMaterial8", "defaultMaterial9"]
const MAIZE_TASSEL: Array[String] = ["defaultMaterial10", "defaultMaterial11", "defaultMaterial12", "defaultMaterial17",
	"defaultMaterial18", "defaultMaterial19", "defaultMaterial20", "defaultMaterial21", "defaultMaterial22",
	"defaultMaterial23", "defaultMaterial24", "defaultMaterial25", "defaultMaterial26"]

static var _beds := {}
static var _units := {}
static var _browned_mats := {}
static var _tinted_mats := {}
static var _tomato_pieces := {}


## The bed of `crop` at `stage`: copies of one plant spread over it.
static func multimesh(crop: StringName, stage: int, variant := 0, withered := false) -> MultiMesh:
	stage = clampi(stage, 0, 3)
	var key := "%s_%d_%d_%s" % [crop, stage, variant, withered]
	if _beds.has(key):
		return _beds[key]
	var unit := withered_unit(crop, stage) if withered else unit_mesh(crop, stage)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d_%d" % [crop, stage, variant])
	var lay: Array = LAYOUT[crop]
	var spots := _grid(lay[0], lay[1], rng, lay[2])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := rng.randf_range(0.88, 1.1)
		# Each plant stands in the hoed soil where it is (on a ridge or down a furrow),
		# a little sunk in, not on a flat plane above it.
		var at := spots[i]
		at.y = FarmPlot.soil_surface(at.x, at.z) - (FarmPlot.SOIL_Y + 0.03) - 0.012
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), at))
	_beds[key] = mm
	return mm


## One plant of `crop` at `stage` (baked when available).
static func unit_mesh(crop: StringName, stage: int) -> ArrayMesh:
	var key := "%s_%d" % [crop, stage]
	if not _units.has(key):
		var baked := _baked(BAKED % [crop, stage])
		_units[key] = baked if baked != null else build_unit(crop, stage)
	return _units[key]


## The withered plant of `crop` at `stage` (baked when available).
static func withered_unit(crop: StringName, stage: int) -> ArrayMesh:
	var key := "%s_%d_w" % [crop, stage]
	if not _units.has(key):
		var baked := _baked(BAKED_W % [crop, stage])
		_units[key] = baked if baked != null else _browned(unit_mesh(crop, stage))
	return _units[key]


## Starts loading every baked plant (each crop and stage, fresh and withered) on a
## background thread.
static func warm_units() -> void:
	for crop in CROPS:
		for stage in 4:
			for path: String in [BAKED % [crop, stage], BAKED_W % [crop, stage]]:
				if not ResourceLoader.exists(path) or ResourceLoader.has_cached(path):
					continue
				if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					ResourceLoader.load_threaded_request(path, "ArrayMesh")


## A baked plant: taken from its background load when warm_units() started one
## (waiting only if it is still running), otherwise loaded here; null if not baked.
static func _baked(path: String) -> ArrayMesh:
	var mesh: ArrayMesh = null
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		mesh = ResourceLoader.load_threaded_get(path) as ArrayMesh
	if mesh == null and ResourceLoader.exists(path):
		mesh = load(path) as ArrayMesh
	if mesh != null:
		# A bake keeps a copy of the leaf-card material it was made with: point those
		# surfaces at the current (shared) one, so the look is set in Mats alone.
		for si in mesh.get_surface_count():
			var surface := StringName(mesh.surface_get_name(si))
			if surface in LEAF_SURFACES:
				mesh.surface_set_material(si, Mats.get_mat(surface))
	return mesh


static func build_unit(crop: StringName, stage: int) -> ArrayMesh:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d" % [crop, stage])
	match crop:
		&"corn": _corn(out, stage)
		&"wheat": _wheat(out, stage, rng)
		&"tomato": _tomato(out, stage, rng)
		&"eggplant": _eggplant(out, stage, rng)
		&"potato": _potato(out, stage, rng)
		&"carrot": _carrot(out, stage, rng)
		&"strawberry": _strawberry(out, stage, rng)
		&"pumpkin": _pumpkin(out, stage, rng)
	for s: Array in out:
		s[1] = _field_material(s[1])
	return MeshMerge.build(MeshMerge.by_material(out), UNIT_LOD_TRIANGLES)


# --- Helpers -----------------------------------------------------------------------

## Plant positions on a jittered grid covering the bed.
static func _grid(rows: int, cols: int, rng: RandomNumberGenerator, jitter := 0.08) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for r in rows:
		for c in cols:
			var x := (float(c) + 0.5) / cols * BED - BED * 0.5
			var z := (float(r) + 0.5) / rows * BED - BED * 0.5
			out.append(Vector3(x + rng.randf_range(-jitter, jitter), 0, z + rng.randf_range(-jitter, jitter)))
	return out


static func _tint(rng: RandomNumberGenerator, amount := 0.1, bias := 0.0) -> Color:
	var v := 0.5 * (1.0 + rng.randf_range(-amount, amount) + bias)
	return Color(v, v, v)


## A leaf card whose base sits at `base`, reaching along `dir`.
static func _leaf(mb: MeshBuilder, key: StringName, base: Vector3, dir: Vector3, length: float,
		rect: Rect2, rng: RandomNumberGenerator, tint: Color, width_ratio := -1.0) -> void:
	var d := dir.normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	side = side.rotated(d, rng.randf_range(-0.7, 0.7))
	var ratio := rect.size.x / rect.size.y if width_ratio < 0.0 else width_ratio
	var shade := (Vector3(d.x, 0.0, d.z) * 0.5 + Vector3.UP).normalized()
	mb.card(key, base + d * length * 0.5, side * length * ratio, d * length, rect, shade, tint, 0.3, 1.0)


## Grass-like blade (double sided through the foliage material).
static func _blade(mb: MeshBuilder, root: Vector3, height: float, width: float, lean: Vector3, col_base: Color,
		col_tip: Color) -> void:
	var side := Vector3(-lean.z, 0, lean.x).normalized() if lean.length() > 0.001 else Vector3.RIGHT
	var mid := root + Vector3.UP * height * 0.55 + lean * 0.4
	var tip := root + Vector3.UP * height + lean
	var n := (Vector3.UP + lean).normalized()
	var p0 := root - side * width * 0.5
	var p1 := root + side * width * 0.5
	var p2 := mid - side * width * 0.4
	var p3 := mid + side * width * 0.4
	var cm := col_base.lerp(col_tip, 0.55)
	mb.tri_n(&"evergreen", p0, p1, p3, n, n, n, col_base, col_base, cm)
	mb.tri_n(&"evergreen", p0, p3, p2, n, n, n, col_base, cm, cm)
	mb.tri_n(&"evergreen", p2, p3, tip, n, n, n, cm, cm, col_tip)


static func _stem(mb: MeshBuilder, from: Vector3, to: Vector3, radius: float, col := STEM_GREEN) -> void:
	mb.cylinder_between(&"evergreen", from, to, radius, radius * 0.7, 5, col, true, false)


## Scene parts of a scan, and the transform that stands it on the origin (its ground
## at `ground` in scan space) `height` tall, stretched sideways by `spread`.
static func _scan_frame(path: String, height: float, spread := 1.0, ground := NAN) -> Transform3D:
	var box := MeshMerge.bounds(MeshMerge.scene_parts(load(path) as PackedScene))
	var s := height / box.size.y
	var base := Vector3(box.get_center().x, box.position.y if is_nan(ground) else ground, box.get_center().z)
	var b := Basis.from_scale(Vector3(s * spread, s, s * spread))
	return Transform3D(b, -(b * base))


## Surfaces added to `out` from index `from` on get their materials multiplied by `tint`.
static func _retint(out: Array, from: int, tint: Color) -> void:
	for i in range(from, out.size()):
		var mat = out[i][1]
		if not mat is BaseMaterial3D:
			continue
		var key := [mat, tint]
		if not _tinted_mats.has(key):
			var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			m.albedo_color *= tint
			_tinted_mats[key] = m
		out[i][1] = _tinted_mats[key]


## Scanned leaves in a field: cut-out alpha (depth-sorted blending is slow and flickers
## over dozens of overlapping cards) and no specular sheen off the waxy scans. With
## metallic at 0 a metallic map changes nothing, so it is not sampled.
static func _field_material(mat: Material) -> Material:
	if not mat is BaseMaterial3D:
		return mat
	var key := ["field", mat]
	if not _tinted_mats.has(key):
		var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
		if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.45
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.metallic = 0.0
		m.metallic_texture = null
		m.metallic_specular = minf(m.metallic_specular, 0.35)
		_tinted_mats[key] = m
	return _tinted_mats[key]


## A produce item's scan thinned out for the field (dozens of them per bed): the item
## mesh with its triangles cut to about `triangles`, placed with `xf`.
static func _produce(out: Array, id: StringName, xf: Transform3D, triangles := 300, tint := Color(1, 1, 1)) -> void:
	var from := out.size()
	MeshMerge.add_mesh(out, _lod(GoodsModels.mesh(id), triangles), xf)
	if tint != Color(1, 1, 1):
		_retint(out, from, tint)


static func _lod(mesh: ArrayMesh, triangles: int) -> ArrayMesh:
	return GoodsModels.decimated(mesh, triangles)


## Basis turning an item lying along X into one hanging (or standing) along Y, its
## thinner end up (the stalk end of an eggplant, the shoulders of a carrot are the
## thicker end, so `thin_up` false stands a carrot root first).
static func _upright(mesh: ArrayMesh, thin_up := true) -> Basis:
	var box := mesh.get_aabb()
	var lo := 0.0
	var hi := 0.0
	var n_lo := 0
	var n_hi := 0
	var c := box.get_center()
	for si in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			var t := (v.x - box.position.x) / maxf(box.size.x, 0.0001)
			var r := Vector2(v.y - c.y, v.z - c.z).length()
			if t < 0.2:
				lo += r
				n_lo += 1
			elif t > 0.8:
				hi += r
				n_hi += 1
	var high_end_thin := hi / maxf(n_hi, 1) < lo / maxf(n_lo, 1)
	# +X up when the +X end is the one we want on top.
	var x_up := high_end_thin == thin_up
	return Basis(Vector3.BACK, PI * 0.5 if x_up else -PI * 0.5)


## Places `mesh` turned by `b` with the middle of its top at `top`.
static func _hung_from(mesh: ArrayMesh, b: Basis, top: Vector3) -> Transform3D:
	var box := Transform3D(b, Vector3.ZERO) * mesh.get_aabb()
	return Transform3D(b, top - Vector3(box.get_center().x, box.end.y, box.get_center().z))


## Triangles entirely below `y` dropped (produce half buried in the soil).
static func _clip_below(out: Array, from: int, y: float) -> void:
	for i in range(from, out.size()):
		var arr: Array = out[i][0]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		var kept := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if verts[idx[t]].y > y or verts[idx[t + 1]].y > y or verts[idx[t + 2]].y > y:
				kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
		arr[Mesh.ARRAY_INDEX] = kept


# --- Tomato plant pieces -----------------------------------------------------------

## The tomato plant scan (scan space) cut into "stem", "foliage", "flowers" and "fruit"
## (each [arrays, material, name]), by the colour of each connected piece; the stem
## is slimmed (the scan's is as thick as a broom handle).
static func _tomato_split() -> Dictionary:
	if not _tomato_pieces.is_empty():
		return _tomato_pieces
	var surfaces := []
	MeshMerge.add_parts(surfaces, MeshMerge.scene_parts(load(TOMATO) as PackedScene))
	var arr: Array = surfaces[0][0]
	var mat: BaseMaterial3D = surfaces[0][1]
	var img := mat.albedo_texture.get_image()
	if img.is_compressed():
		img.decompress()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var islands := _islands(verts, idx)
	var groups := {"stem": PackedInt32Array(), "foliage": PackedInt32Array(), "flowers": PackedInt32Array(), "fruit": PackedInt32Array()}
	# The stem is the piece reaching highest.
	var stem_i := 0
	var tallest := -1.0
	for i in islands.size():
		var box := AABB(verts[idx[islands[i][0]]], Vector3.ZERO)
		for t: int in islands[i]:
			for j in 3:
				box = box.expand(verts[idx[t + j]])
		if box.size.y > tallest:
			tallest = box.size.y
			stem_i = i
	for i in islands.size():
		var col := Color(0, 0, 0)
		for t: int in islands[i]:
			var uv := (uvs[idx[t]] + uvs[idx[t + 1]] + uvs[idx[t + 2]]) / 3.0
			col += img.get_pixel(clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1),
					clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1))
		col /= float(islands[i].size())
		var group := "foliage"
		if i == stem_i:
			group = "stem"
		elif col.r > 0.8 and col.g < 0.4:
			group = "fruit"
		elif col.r > 0.6 and col.g < 0.6 and col.b > 0.2:
			group = "fruit"  # the green-brown calyx on top of each tomato
		elif col.r > 0.55 and col.g > 0.55 and col.b < 0.15:
			group = "flowers"
		for t: int in islands[i]:
			groups[group].append_array([idx[t], idx[t + 1], idx[t + 2]])
	# Slim the stem toward its own axis, measured in slices along its height.
	var stem_idx: PackedInt32Array = groups["stem"]
	var used := {}
	for k in stem_idx:
		used[k] = true
	var y0 := INF
	var y1 := -INF
	for k: int in used:
		y0 = minf(y0, verts[k].y)
		y1 = maxf(y1, verts[k].y)
	var slices := 16
	var sums := []
	sums.resize(slices)
	for s in slices:
		sums[s] = [Vector2.ZERO, 0]
	for k: int in used:
		var s := clampi(int((verts[k].y - y0) / maxf(y1 - y0, 0.0001) * slices), 0, slices - 1)
		sums[s][0] += Vector2(verts[k].x, verts[k].z)
		sums[s][1] += 1
	for k: int in used:
		var s := clampi(int((verts[k].y - y0) / maxf(y1 - y0, 0.0001) * slices), 0, slices - 1)
		var axis: Vector2 = sums[s][0] / maxf(sums[s][1], 1)
		var v := verts[k]
		var d := Vector2(v.x, v.z) - axis
		verts[k] = Vector3(axis.x + d.x * 0.4, v.y, axis.y + d.y * 0.4)
	arr[Mesh.ARRAY_VERTEX] = verts
	for g: String in groups:
		var part := arr.duplicate()
		part[Mesh.ARRAY_INDEX] = groups[g]
		_tomato_pieces[g] = [GoodsModels._compacted(part), mat, "tomato_" + g]
	return _tomato_pieces


## Triangle start indices of each connected piece (vertices welded by position).
static func _islands(verts: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	var find := func(x: int) -> int:
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	var by_pos := {}
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		if by_pos.has(key):
			var a: int = find.call(i)
			var b: int = find.call(by_pos[key])
			if a != b:
				parent[a] = b
		else:
			by_pos[key] = i
	for t in range(0, idx.size(), 3):
		var a: int = find.call(idx[t])
		for j in [1, 2]:
			var b: int = find.call(idx[t + j])
			if a != b:
				parent[b] = a
	var by_root := {}
	for t in range(0, idx.size(), 3):
		var r: int = find.call(idx[t])
		if not by_root.has(r):
			by_root[r] = PackedInt32Array()
		by_root[r].append(t)
	return by_root.values()


## The tomato plant's pieces placed with `xf` (the scan's fruit are dense spheres:
## thinned to a quarter).
static func _add_tomato(out: Array, xf: Transform3D, pieces: Array[String]) -> void:
	var split := _tomato_split()
	for p in pieces:
		var s: Array = split[p]
		var arr: Array = (s[0] as Array).duplicate(true)
		if p == "fruit":
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			arr = _lod(m, int((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 12)).surface_get_arrays(0)
		out.append([MeshMerge._moved(arr, xf), s[1], s[2]])


## A bush of `copies` tomato-family stems from one root, each turned about the
## vertical and leaning out by about `tilt` radians, the whole `height` tall.
static func _bush(out: Array, height: float, copies: int, tilt: float, spread: float, rng: RandomNumberGenerator,
		pieces: Array[String], fruit_on_first := false) -> void:
	var frame := _scan_frame(TOMATO, height, spread)
	for i in copies:
		var yaw := TAU * i / copies + rng.randf_range(-0.4, 0.4)
		var lean := 0.0 if i == 0 and copies < 3 else tilt * rng.randf_range(0.75, 1.2)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
		var these := pieces.duplicate()
		if fruit_on_first and i > 0:
			these.erase("fruit")
		_add_tomato(out, Transform3D(b, Vector3.ZERO) * frame, these)


# --- Crops -------------------------------------------------------------------------

## Maize: lower leaves first, the whole plant with its tassel, then the ears.
static func _corn(out: Array, stage: int) -> void:
	var scale: Array[float] = [0.12, 0.36, 0.68, 0.8]
	var leaves_below: Array[float] = [0.9, 1.8, 99.0, 99.0]
	var keep := []
	for p: Array in MeshMerge.scene_parts(load(MAIZE) as PackedScene):
		var n: String = p[3]
		if n in MAIZE_ROOTS or (n in MAIZE_EARS and stage < 3) or (n in MAIZE_TASSEL and stage < 2):
			continue
		if not (n in MAIZE_EARS or n in MAIZE_TASSEL) and MeshMerge.bounds([p]).position.y > leaves_below[stage]:
			continue
		keep.append(p)
	# The scan stands on its stalk at the origin.
	MeshMerge.add_parts(out, keep, Transform3D(Basis.from_scale(Vector3.ONE * scale[stage]), Vector3.ZERO))


## Wheat: grass-like blades while young, then the scanned bunch, green until it ripens.
static func _wheat(out: Array, stage: int, rng: RandomNumberGenerator) -> void:
	if stage <= 1:
		var mb := MeshBuilder.new()
		var green := Color(0.36, 0.55, 0.2)
		var h := 0.16 if stage == 0 else 0.4
		for b in rng.randi_range(9, 12):
			var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.03, 0.12) * h * 2.0
			_blade(mb, Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06)), rng.randf_range(0.7, 1.0) * h, 0.016,
					lean, green.darkened(0.3), green)
		MeshMerge.add_mesh(out, mb.build())
		return
	var from := out.size()
	MeshMerge.add_parts(out, MeshMerge.scene_parts(load(WHEAT) as PackedScene), _scan_frame(WHEAT, 0.78 if stage == 2 else 0.95))
	if stage == 2:
		_retint(out, from, Color(0.6, 0.86, 0.42))


## Tomato: the scanned plant on a stake; flowers while growing, fruit when ready.
static func _tomato(out: Array, stage: int, rng: RandomNumberGenerator) -> void:
	var heights: Array[float] = [0.24, 0.55, 0.95, 1.15]
	var pieces: Array[String] = ["stem", "foliage"]
	if stage >= 2:
		pieces.append("flowers")
	if stage == 3:
		pieces.append("fruit")
	# The main stem tied to the stake and a side shoot.
	_bush(out, heights[stage], 2 if stage >= 1 else 1, 0.35, 1.0, rng, pieces)
	if stage >= 1:
		var mb := MeshBuilder.new()
		var h := heights[stage] * 1.08
		mb.box_at(&"wood", Vector3(0.045, h * 0.5 - 0.05, 0.02), Vector3(0.028, h + 0.1, 0.028), Color(0.55, 0.5, 0.44))
		MeshMerge.add_mesh(out, mb.build())


## Eggplant: the tomato's foliage, wider and lower, purple flowers, then the fruit
## hanging among the leaves.
static func _eggplant(out: Array, stage: int, rng: RandomNumberGenerator) -> void:
	var heights: Array[float] = [0.2, 0.42, 0.62, 0.72]
	_bush(out, heights[stage], 1 if stage == 0 else 3, 0.5, 1.2, rng, ["stem", "foliage"])
	if stage == 2:
		var mb := MeshBuilder.new()
		for i in 4:
			var a := TAU * i / 4.0 + rng.randf_range(-0.4, 0.4)
			mb.blob(&"veg", Transform3D(Basis(), Vector3(cos(a) * 0.1, heights[stage] * rng.randf_range(0.5, 0.75), sin(a) * 0.1)),
					0.014, 0, Color(0.62, 0.45, 0.82))
		MeshMerge.add_mesh(out, mb.build())
	if stage == 3:
		var mesh := GoodsModels.mesh(&"eggplant")
		var hang := _upright(mesh, true)
		for i in 2:
			var a := PI * i + rng.randf_range(-0.5, 0.5)
			var top := Vector3(cos(a) * 0.12, heights[stage] * rng.randf_range(0.42, 0.55), sin(a) * 0.12)
			var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) * hang
			_produce(out, &"eggplant", _hung_from(mesh, b, top), 380)


## Potato: low, bushy tomato-family foliage; white flowers, then tubers pushing out of
## the soil under it.
static func _potato(out: Array, stage: int, rng: RandomNumberGenerator) -> void:
	var heights: Array[float] = [0.18, 0.36, 0.52, 0.56]
	_bush(out, heights[stage], 1 if stage == 0 else 4, 0.55, 1.6, rng, ["stem", "foliage"])
	if stage == 2:
		var mb := MeshBuilder.new()
		for i in 5:
			var a := TAU * i / 5.0 + rng.randf_range(-0.4, 0.4)
			mb.blob(&"veg", Transform3D(Basis(), Vector3(cos(a) * 0.12, heights[stage] * rng.randf_range(0.8, 1.0), sin(a) * 0.12)),
					0.012, 0, Color(0.95, 0.93, 0.97) if rng.randf() < 0.7 else Color(0.72, 0.58, 0.86))
		MeshMerge.add_mesh(out, mb.build())
	if stage == 3:
		for i in 3:
			var a := TAU * i / 3.0 + rng.randf_range(-0.4, 0.4)
			var id := &"potato" if i != 1 else &"potato_b"
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
			var at := Vector3(cos(a) * 0.14, -0.035, sin(a) * 0.14)
			var first := out.size()
			_produce(out, id, Transform3D(b, at), 220)
			_clip_below(out, first, -0.03)


## Carrot: feathery tops; the orange shoulders show above the soil when ready.
static func _carrot(out: Array, stage: int, rng: RandomNumberGenerator) -> void:
	var s: float = [0.22, 0.5, 0.8, 1.0][stage]
	var mb := MeshBuilder.new()
	for f in 2 + stage * 2:
		var ang := rng.randf() * TAU
		var dir := Vector3(cos(ang) * 0.35, 1.0, sin(ang) * 0.35)
		var rect: Rect2 = NatureModels.FIR_TWIGS[rng.randi() % 2]
		_leaf(mb, &"crop_feathery", Vector3.ZERO, dir, rng.randf_range(0.2, 0.34) * s, rect, rng, _tint(rng, 0.12), 0.75)
	MeshMerge.add_mesh(out, mb.build())
	if stage == 3:
		var mesh := GoodsModels.mesh(&"carrot")
		var first := out.size()
		_produce(out, &"carrot", _hung_from(mesh, _upright(mesh, false), Vector3(0, 0.022, 0)), 260)
		_clip_below(out, first, -0.02)


## Strawberry: a low rosette of leaves; white flowers, then berries resting on the soil.
static func _strawberry(out: Array, stage: int, rng: RandomNumberGenerator) -> void:
	var mb := MeshBuilder.new()
	var count := 4 + stage * 3
	for i in count:
		var ang := TAU * i / count + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), rng.randf_range(0.3, 0.7), sin(ang))
		var rect: Rect2 = NatureModels.BROAD_SCATTER[rng.randi() % 2]
		_leaf(mb, &"crop_leaves", Vector3(0, 0.02, 0), dir, rng.randf_range(0.17, 0.25) * maxf([0.22, 0.5, 0.8, 1.0][stage], 0.45),
				rect, rng, _tint(rng, 0.08, -0.05), 0.9)
	if stage == 2:
		for i in 3:
			mb.blob(&"veg", Transform3D(Basis(), Vector3(rng.randf_range(-0.08, 0.08), 0.12, rng.randf_range(-0.08, 0.08))), 0.012, 0, Color(0.97, 0.97, 0.94))
	MeshMerge.add_mesh(out, mb.build())
	if stage == 3:
		for i in 4:
			var ang := TAU * i / 4.0 + rng.randf_range(-0.4, 0.4)
			var b := Basis.from_euler(Vector3(rng.randf_range(-1.2, 1.2), rng.randf() * TAU, rng.randf_range(-1.2, 1.2)))
			_produce(out, &"strawberry", Transform3D(b, Vector3(cos(ang) * 0.12, 0.012, sin(ang) * 0.12)), 240)


## Pumpkin: vines creeping over the bed with big leaves; small green fruit, then ripe
## pumpkins.
static func _pumpkin(out: Array, stage: int, rng: RandomNumberGenerator) -> void:
	var s: float = [0.22, 0.5, 0.8, 1.0][stage]
	var mb := MeshBuilder.new()
	var vines := 3 + stage
	for v in vines:
		var ang := TAU * v / vines + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var length := rng.randf_range(0.6, 1.0) * s
		var prev := Vector3(0, 0.03, 0)
		for k in 4:
			var next := dir * length * (k + 1) / 4.0 + Vector3(0, 0.03, 0) + Vector3(-dir.z, 0, dir.x) * sin(k * 1.7) * 0.08
			_stem(mb, prev, next, 0.012 * maxf(s, 0.5), Color(0.38, 0.5, 0.22))
			for l in 1 + int(stage >= 2):
				var leaf_dir := (dir * 0.4 + Vector3.UP + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))).normalized()
				var rect: Rect2 = NatureModels.BROAD_SCATTER[rng.randi() % 2]
				_leaf(mb, &"crop_leaves", next, leaf_dir, rng.randf_range(0.34, 0.5) * maxf(s, 0.45), rect, rng, _tint(rng, 0.1, -0.1), 0.95)
			prev = next
	MeshMerge.add_mesh(out, mb.build())
	if stage == 2:
		for i in 2:
			var at := Vector3(0.28 - i * 0.5, 0.0, -0.15 + i * 0.35)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.5)
			_produce(out, &"pumpkin", Transform3D(b, at), 400, Color(0.62, 0.95, 0.5))
	if stage == 3:
		var spots := [[&"pumpkin", Vector3(0.3, 0.0, -0.18), 1.15], [&"pumpkin_b", Vector3(-0.28, 0.0, 0.3), 1.0]]
		for sp: Array in spots:
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * float(sp[2]))
			_produce(out, sp[0], Transform3D(b, sp[1]), 500)


## A browned copy of a plant (withered crops), with its own LODs. It reads the plant
## back from the GPU, so tools/bake_tools.gd bakes these and the game only loads them.
static func _browned(unit: ArrayMesh) -> ArrayMesh:
	var surfaces := []
	for si in unit.get_surface_count():
		var arr := unit.surface_get_arrays(si)
		var mat := unit.surface_get_material(si)
		if mat is BaseMaterial3D:
			if not _browned_mats.has(mat):
				var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				m.albedo_color *= WITHER
				_browned_mats[mat] = m
			mat = _browned_mats[mat]
		elif arr[Mesh.ARRAY_COLOR] != null:
			var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			for i in cols.size():
				cols[i] = Color(cols[i].r * WITHER.r, cols[i].g * WITHER.g, cols[i].b * WITHER.b, cols[i].a)
			arr[Mesh.ARRAY_COLOR] = cols
		surfaces.append([arr, mat, unit.surface_get_name(si)])
	return MeshMerge.build(surfaces, UNIT_LOD_TRIANGLES)
