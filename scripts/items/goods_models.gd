@tool
class_name GoodsModels
extends RefCounted
## Photo-scanned models of produce and goods (Poly Haven, Sketchfab; see
## art/models/items/CREDITS.md) baked into ItemModels' frame: turned by `rot` (degrees)
## first, then standing on their base at the origin, `size` metres along their longest
## side, and turned about the vertical by `yaw` (degrees).
##   only / skip: keep or drop scene parts: node names containing the text, or a list
##     of exact names
##   island: keep only the largest connected piece of the scan (drops boards, stands)
##   tint: multiplies the albedo of every material (variants of one scan)
##   recolor: repaints the albedo textures as their brightness times this colour (the
##     yarn scan is dyed magenta; home-spun yarn is undyed)
## Several items may share one scan with different tints. tools/bake_tools.gd saves
## the results to BAKED so the game only loads them; rerun it after changing MODELS.

const PRODUCE := "res://art/models/items/produce/"
const GOODS := "res://art/models/items/goods/"
const MODELS := {
	# Produce (the fruit & vegetable pack pieces come out of tools/extract_scans.gd).
	&"carrot": {"path": PRODUCE + "carrot/carrot.gltf", "size": 0.19},
	&"potato": {"path": PRODUCE + "potato_a/potato_a.gltf", "size": 0.1},
	&"tomato": {"path": PRODUCE + "tomato/scene.gltf", "size": 0.075},
	&"eggplant": {"path": PRODUCE + "eggplant/scene.gltf", "size": 0.21, "yaw": 90.0},
	&"strawberry": {"path": PRODUCE + "strawberry/strawberry.gltf", "size": 0.045},
	&"pumpkin": {"path": PRODUCE + "pumpkin_a/pumpkin_a.gltf", "size": 0.26},
	# A sheaf: the wheat field's scanned bunch.
	&"wheat": {"path": "res://art/models/crops/wheat/scene.gltf", "size": 0.36},
	# Other potatoes and pumpkins of the pack, for variety in the field (not items).
	&"potato_b": {"path": PRODUCE + "potato_b/potato_b.gltf", "size": 0.09},
	&"pumpkin_b": {"path": PRODUCE + "pumpkin_b/pumpkin_b.gltf", "size": 0.28},
	# Goods.
	&"egg": {"path": GOODS + "egg/scene.gltf", "size": 0.058},
	&"milk": {"path": "res://art/models/items/metal_jug/metal_jug_1k.gltf", "size": 0.27},
	&"cheese": {"path": GOODS + "cheese_half/scene.gltf", "size": 0.24},
	&"yarn": {"path": GOODS + "yarn_ball/scene.gltf", "only": ["Object_3"], "size": 0.11,
		"recolor": Color(0.93, 0.89, 0.8)},
	&"pickles": {"path": GOODS + "pickle_jar/scene.gltf", "size": 0.14},
	&"jam": {"path": GOODS + "jam_jar/scene.gltf", "size": 0.12},
	&"tomato_paste": {"path": GOODS + "jam_jar/scene.gltf", "size": 0.11, "tint": Color(1.0, 0.72, 0.56)},
	&"flour": {"path": GOODS + "burlap_sack/scene.gltf", "size": 0.3, "tint": Color(1.3, 1.28, 1.22)},
	&"feed": {"path": GOODS + "burlap_sack/scene.gltf", "size": 0.3, "yaw": 150.0},
	&"manure": {"path": GOODS + "burlap_sack/scene.gltf", "size": 0.3, "yaw": 60.0, "tint": Color(0.55, 0.44, 0.34)},
	&"fertilizer": {"path": "res://art/models/items/compost_bag_02/compost_bag_02_1k.gltf", "size": 0.26},
	&"hay": {"path": GOODS + "hay_bales/scene.gltf", "island": true, "size": 0.42},
}
## Scans heavier than this get LODs.
const LOD_TRIANGLES := 12000
const BAKED := "res://art/models/items/baked/%s.res"
## Thinned-out versions (about this many triangles) for goods shown by the dozen: in
## crates on market shelves and in the pickup bed.
const LOW := {
	&"tomato": 90, &"potato": 90, &"potato_b": 90, &"carrot": 110, &"eggplant": 160, &"strawberry": 60,
	&"pumpkin": 320, &"pumpkin_b": 320, &"egg": 60, &"cheese": 260, &"pickles": 420, &"jam": 320,
	&"tomato_paste": 320, &"milk": 500, &"flour": 700, &"feed": 700, &"manure": 700, &"fertilizer": 900,
	&"hay": 500,
}
const BAKED_LOW := "res://art/models/items/baked/%s_low.res"

static var _low := {}
static var _decimated := {}


static func has(id: StringName) -> bool:
	return MODELS.has(id) and (ResourceLoader.exists(BAKED % id) or ResourceLoader.exists(MODELS[id]["path"]))


static func mesh(id: StringName) -> ArrayMesh:
	if ResourceLoader.exists(BAKED % id):
		return load(BAKED % id) as ArrayMesh
	return build(id)


## The thinned-out version of an item (LOW), baked when available.
static func low(id: StringName) -> ArrayMesh:
	if not _low.has(id):
		var path := BAKED_LOW % id
		_low[id] = load(path) if ResourceLoader.exists(path) else decimated(mesh(id), int(LOW.get(id, 300)))
	return _low[id]


## `mesh` with its triangles cut to about `triangles` (the automatic LOD nearest to it,
## shared out between the surfaces), unused vertices dropped.
static func decimated(source: ArrayMesh, triangles: int) -> ArrayMesh:
	var key := [source, triangles]
	if _decimated.has(key):
		return _decimated[key]
	var im := ImporterMesh.new()
	var total := 0
	for si in source.get_surface_count():
		var arr := source.surface_get_arrays(si)
		total += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, source.surface_get_material(si), source.surface_get_name(si))
	# A wide normal merge angle lets small rounded goods simplify further.
	im.generate_lods(75.0, 90.0, [])
	var out := ArrayMesh.new()
	for si in im.get_surface_count():
		var arr := im.get_surface_arrays(si)
		var best: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var want := maxf(float(triangles) * (best.size() / 3) / maxf(total, 1), 12.0)
		var best_err := absf(log(best.size() / 3.0 / want))
		for li in im.get_surface_lod_count(si):
			var idx := im.get_surface_lod_indices(si, li)
			var err := absf(log(maxf(idx.size() / 3.0, 1.0) / want))
			if err < best_err:
				best = idx
				best_err = err
		arr[Mesh.ARRAY_INDEX] = best
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compacted(arr))
		out.surface_set_material(si, im.get_surface_material(si))
	_decimated[key] = out
	return out


## Builds the item-space mesh from the source model.
static func build(id: StringName) -> ArrayMesh:
	var cfg: Dictionary = MODELS[id]
	var parts := MeshMerge.scene_parts(load(cfg["path"]) as PackedScene)
	if cfg.has("only") or cfg.has("skip"):
		parts = parts.filter(func(p: Array) -> bool:
			return (not cfg.has("only") or _named(p[3], cfg["only"])) and (not cfg.has("skip") or not _named(p[3], cfg["skip"])))
	var rot := Basis.from_euler((cfg.get("rot", Vector3.ZERO) as Vector3) * (PI / 180.0))
	var surfaces := []
	MeshMerge.add_parts(surfaces, parts, Transform3D(rot, Vector3.ZERO))
	if cfg.get("island", false):
		surfaces = _largest_island(surfaces)
	# Stand the result on its base, sized and turned.
	var box := _bounds(surfaces)
	var s := float(cfg["size"]) / maxf(box.get_longest_axis_size(), 0.0001)
	var base := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var yaw := Basis(Vector3.UP, deg_to_rad(float(cfg.get("yaw", 0.0))))
	var frame := Transform3D(yaw.scaled(Vector3.ONE * s), yaw * (-base * s))
	var placed := []
	var mats := {}
	for surf: Array in surfaces:
		if not mats.has(surf[1]):
			mats[surf[1]] = _material(surf[1], cfg)
		placed.append([MeshMerge._moved(surf[0], frame), mats[surf[1]], surf[2]])
	return MeshMerge.build(MeshMerge.by_material(placed), LOD_TRIANGLES)


static func _bounds(surfaces: Array) -> AABB:
	var box := AABB()
	var first := true
	for surf: Array in surfaces:
		for v: Vector3 in (surf[0] as Array)[Mesh.ARRAY_VERTEX]:
			if first:
				box = AABB(v, Vector3.ZERO)
				first = false
			else:
				box = box.expand(v)
	return box


static func _named(node_name: String, which) -> bool:
	if which is Array:
		return node_name in which
	return String(which) in node_name


static func _material(mat: Material, cfg: Dictionary) -> Material:
	if not (cfg.has("tint") or cfg.has("recolor")) or not mat is BaseMaterial3D:
		return mat
	var m := mat.duplicate() as BaseMaterial3D
	if cfg.has("tint"):
		m.albedo_color *= cfg["tint"] as Color
	if cfg.has("recolor") and m.albedo_texture:
		var img := m.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGB8)
		img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
		var col := cfg["recolor"] as Color
		for y in img.get_height():
			for x in img.get_width():
				var l := img.get_pixel(x, y).get_luminance()
				# Brightness keeps the fibres' light and shadow; lift it a little so the
				# dyed scan's dark red doesn't turn the yarn grey.
				l = clampf(0.25 + l * 1.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(col.r * l, col.g * l, col.b * l))
		img.generate_mipmaps()
		m.albedo_texture = ImageTexture.create_from_image(img)
	return m


## The surfaces cut down to the connected piece (shared vertex positions) with the most
## triangles.
static func _largest_island(surfaces: Array) -> Array:
	# Union-find over welded vertex positions of all surfaces.
	var parent := {}
	var key_of := func(v: Vector3) -> Vector3i:
		return Vector3i((v * 2000.0).round())
	var find := func(k: Vector3i) -> Vector3i:
		var r := k
		while parent[r] != r:
			r = parent[r]
		var c := k
		while parent[c] != r:
			var nxt: Vector3i = parent[c]
			parent[c] = r
			c = nxt
		return r
	var tris := []
	for si in surfaces.size():
		var arr: Array = surfaces[si][0]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		for t in range(0, idx.size(), 3):
			var ks: Array[Vector3i] = [key_of.call(verts[idx[t]]), key_of.call(verts[idx[t + 1]]), key_of.call(verts[idx[t + 2]])]
			for k in ks:
				if not parent.has(k):
					parent[k] = k
			var r0: Vector3i = find.call(ks[0])
			for k in [ks[1], ks[2]]:
				var r: Vector3i = find.call(k)
				if r != r0:
					parent[r] = r0
			tris.append([si, t, ks[0]])
	var counts := {}
	for tr: Array in tris:
		var r: Vector3i = find.call(tr[2])
		counts[r] = int(counts.get(r, 0)) + 1
	var best: Vector3i
	var best_n := -1
	for r: Vector3i in counts:
		if int(counts[r]) > best_n:
			best_n = counts[r]
			best = r
	var keep := {}
	for tr: Array in tris:
		if find.call(tr[2]) == best:
			keep[Vector2i(tr[0], tr[1])] = true
	var out := []
	for si in surfaces.size():
		var arr: Array = (surfaces[si][0] as Array).duplicate()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
		var kept := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if keep.has(Vector2i(si, t)):
				kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
		if kept.is_empty():
			continue
		arr[Mesh.ARRAY_INDEX] = kept
		out.append([_compacted(arr), surfaces[si][1], surfaces[si][2]])
	return out


## Drops the vertices no triangle uses (they would still count in the mesh bounds).
static func _compacted(arr: Array) -> Array:
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var remap := {}
	var order := PackedInt32Array()
	for i in idx:
		if not remap.has(i):
			remap[i] = order.size()
			order.append(i)
	var out := arr.duplicate()
	var new_idx := PackedInt32Array()
	new_idx.resize(idx.size())
	for k in idx.size():
		new_idx[k] = remap[idx[k]]
	out[Mesh.ARRAY_INDEX] = new_idx
	for ch in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arr[ch] == null:
			continue
		var src = arr[ch]
		var dst = src.duplicate()
		dst.resize(order.size())
		for k in order.size():
			dst[k] = src[order[k]]
		out[ch] = dst
	if arr[Mesh.ARRAY_TANGENT] != null:
		var src: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var dst := PackedFloat32Array()
		dst.resize(order.size() * 4)
		for k in order.size():
			for c in 4:
				dst[k * 4 + c] = src[order[k] * 4 + c]
		out[Mesh.ARRAY_TANGENT] = dst
	return out
