@tool
class_name BerryModels
extends RefCounted
## The wild berry bushes' models (BerryBush): each bush is a mound of twigs cut from the
## Poly Haven shrub scans (art/models/nature/shrub_0x, CC0; tools/fetch_wild.py), turned,
## leant out and grown to the bush's size, with its fruit as a second mesh shown while it
## is ripe (clusters of glossy blueberries, blackberries and raspberries made of drupelets,
## rosehips). tools/bake_berries.gd builds them into art/models/nature/baked/ once; the
## game only loads them. The same berries make the items' models (a handful on a leaf).

const KINDS: Array[StringName] = [&"blueberry", &"blackberry", &"raspberry", &"rosehip"]
## Bush shapes baked per kind.
const VARIANTS := 2
const BAKED := "res://art/models/nature/baked/berry_%s_%d%s.res"
const SHRUB := "res://art/models/nature/%s/%s_1k.gltf"
const SHRUB_TEX := "res://art/models/nature/%s/textures/%s_%s_1k.jpg"

## Per kind: the scan its twigs come from, how many twigs and how much larger than the
## scan, the bush's radius and height (m), how far the twigs lean out (rad), the leaves'
## tint, the berries (count of clusters, berries per cluster, size (m), colours: ripe
## and a share of unripe ones), how they are built ("drupes": aggregates of drupelets)
## and their shading (roughness, the blueberry's waxy bloom).
const LOOK := {
	&"blueberry": {"scan": "shrub_04", "twigs": [22, 28], "scale": [2.9, 3.6], "radius": 0.65, "height": 0.78,
		"lean": [0.25, 0.8], "tint": Color(0.5, 0.62, 0.48), "clusters": 30, "per": [4, 6], "size": 0.0095,
		"ripe": Color(0.13, 0.13, 0.27), "unripe": [Color(0.5, 0.22, 0.38), Color(0.62, 0.7, 0.44)], "unripe_share": 0.15,
		"rough": 0.5, "bloom": 0.6, "shape": "round"},
	&"blackberry": {"scan": "shrub_01", "twigs": [20, 24], "scale": [2.4, 3.1], "radius": 0.85, "height": 1.1,
		"lean": [0.35, 1.0], "tint": Color(0.56, 0.66, 0.5), "clusters": 30, "per": [2, 3], "size": 0.013,
		"ripe": Color(0.08, 0.045, 0.09), "unripe": [Color(0.62, 0.07, 0.09), Color(0.5, 0.58, 0.26)], "unripe_share": 0.3,
		"rough": 0.22, "bloom": 0.0, "shape": "drupes"},
	&"raspberry": {"scan": "shrub_01", "twigs": [14, 18], "scale": [2.6, 3.2], "radius": 0.55, "height": 1.2,
		"lean": [0.1, 0.45], "tint": Color(0.86, 0.95, 0.78), "clusters": 26, "per": [1, 3], "size": 0.011,
		"ripe": Color(0.72, 0.07, 0.14), "unripe": [Color(0.9, 0.55, 0.45), Color(0.75, 0.78, 0.5)], "unripe_share": 0.2,
		"rough": 0.4, "bloom": 0.15, "shape": "drupes"},
	&"rosehip": {"scan": "shrub_02", "twigs": [4, 5], "scale": [0.8, 1.0], "radius": 0.55, "height": 1.35,
		"lean": [0.05, 0.3], "tint": Color(0.62, 0.72, 0.56), "clusters": 34, "per": [1, 3], "size": 0.0115,
		"ripe": Color(0.78, 0.16, 0.05), "unripe": [Color(0.86, 0.45, 0.1), Color(0.6, 0.62, 0.28)], "unripe_share": 0.15,
		"rough": 0.2, "bloom": 0.0, "shape": "hip"},
}
## Twig triangle budget per scan (each bush has 4-22 twigs; the bush gets LODs).
const TWIG_TRIANGLES := {"shrub_01": 1800, "shrub_02": 5200, "shrub_04": 1400}

static var _cache := {}


# --- In game -------------------------------------------------------------------------------

## The leaves and twigs of bush `variant` of `kind`, with their material.
static func leaves(kind: StringName, variant: int) -> Mesh:
	var key := "leaves_%s_%d" % [kind, variant]
	if not _cache.has(key):
		var m := load(BAKED % [kind, variant, ""]) as ArrayMesh
		if m:
			m.surface_set_material(0, leaf_material(kind))
		_cache[key] = m
	return _cache[key]


## Its berries (shown while the bush is ripe).
static func fruit(kind: StringName, variant: int) -> Mesh:
	var key := "fruit_%s_%d" % [kind, variant]
	if not _cache.has(key):
		var m := load(BAKED % [kind, variant, "_fruit"]) as ArrayMesh
		if m:
			m.surface_set_material(0, fruit_material(kind))
		_cache[key] = m
	return _cache[key]


## The scan's photographed leaves (nature_scan_foliage: cut out, swaying, browning in
## autumn), tinted per kind.
static func leaf_material(kind: StringName) -> ShaderMaterial:
	var key := "leafmat_" + String(kind)
	if _cache.has(key):
		return _cache[key]
	var look: Dictionary = LOOK[kind]
	var scan: String = look["scan"]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/nature_scan_foliage.gdshader")
	mat.set_shader_parameter("albedo_tex", load(SHRUB_TEX % [scan, scan, "diff"]))
	mat.set_shader_parameter("normal_tex", load(SHRUB_TEX % [scan, scan, "nor_gl"]))
	mat.set_shader_parameter("rough_tex", load(SHRUB_TEX % [scan, scan, "arm"]))
	mat.set_shader_parameter("alpha_tex", load(SHRUB_TEX % [scan, scan, "alpha"]))
	mat.set_shader_parameter("arm", true)
	mat.set_shader_parameter("tint", look["tint"])
	mat.set_shader_parameter("sway", 0.05)
	mat.set_shader_parameter("soil_height", 0.08)
	mat.set_shader_parameter("translucency", 0.45)
	_cache[key] = mat
	return mat


## The berries' skin (shaders/berry.gdshader; colours are in the vertices).
static func fruit_material(kind: StringName) -> ShaderMaterial:
	var key := "fruitmat_" + String(kind)
	if _cache.has(key):
		return _cache[key]
	var look: Dictionary = LOOK[kind]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/berry.gdshader")
	mat.set_shader_parameter("roughness", float(look["rough"]))
	mat.set_shader_parameter("bloom", float(look["bloom"]))
	mat.set_shader_parameter("sway", 0.05)
	_cache[key] = mat
	return mat


## A handful of `kind`: the item's model (held, dropped, its icon), made here from the
## same berries.
static func handful(kind: StringName) -> ArrayMesh:
	var key := "handful_" + String(kind)
	if _cache.has(key):
		return _cache[key]
	var look: Dictionary = LOOK[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var mb := MeshBuilder.new()
	var size: float = look["size"] * 1.25
	# A little heap: a ring on the bottom, a few on top.
	var spots: Array[Vector3] = []
	var n := 9 if look["shape"] == "round" else 6
	for i in n:
		var a := TAU * float(i) / float(n - 1) + rng.randf_range(-0.2, 0.2)
		var r := 0.0 if i == n - 1 else size * 2.1
		var y := size * (1.0 if i < n - 1 else 2.6)
		spots.append(Vector3(cos(a) * r, y, sin(a) * r))
	for p in spots:
		var up := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 1.0), rng.randf_range(-0.6, 0.6)).normalized()
		_berry(mb, look, p, up, size, look["ripe"], rng, true)
	var m := mb.build({&"berry": fruit_material(kind)}, true)
	_cache[key] = m
	return m


# --- Baking (tools/bake_berries.gd) ----------------------------------------------------------

## The twigs of a shrub scan: surface arrays, each stood on the origin (its foot at y 0),
## simplified to TWIG_TRIANGLES. shrub_02's four shrubs are its nodes; the rows of little
## plants in shrub_01 and shrub_04 are cut apart where their stems meet the ground.
static func twigs(scan: String) -> Array:
	var key := "twigs_" + scan
	if _cache.has(key):
		return _cache[key]
	var parts := MeshMerge.scene_parts(load(SHRUB % [scan, scan]) as PackedScene)
	var pieces: Array = []
	for part: Array in parts:
		var arrays := NatureModels._transformed((part[1] as Mesh).surface_get_arrays(0), part[0])
		if parts.size() > 1:
			pieces.append(arrays)
		else:
			pieces.append_array(_split_plants(arrays))
	var out: Array = []
	for arrays: Array in pieces:
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		# Its foot: the middle of the lowest few centimetres.
		var low := INF
		for v in verts:
			low = minf(low, v.y)
		var foot := Vector3.ZERO
		var feet := 0
		for v in verts:
			if v.y < low + 0.02:
				foot += v
				feet += 1
		foot /= maxf(feet, 1)
		arrays[Mesh.ARRAY_VERTEX] = Transform3D(Basis(), Vector3(-foot.x, -low, -foot.z)) * verts
		for ch in [Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
				Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			arrays[ch] = null
		out.append(_simplified(arrays, TWIG_TRIANGLES.get(scan, 2000)))
	_cache[key] = out
	return out


## `arrays` cut down to about `max_triangles` (the first level of detail under it, or the
## coarsest there is), keeping only the vertices it still uses.
static func _simplified(arrays: Array, max_triangles: int) -> Array:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in im.get_surface_lod_count(0):
		idx = im.get_surface_lod_indices(0, i)
		if idx.size() / 3 <= max_triangles:
			break
	return _subset(arrays, idx)


## Cuts a row of separate little plants (one mesh) into one surface per plant: the stems'
## feet on the ground mark the plants; every connected piece goes to the nearest foot.
static func _split_plants(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var low := INF
	for v in verts:
		low = minf(low, v.y)
	# Feet: runs of ground-level vertices along the row (x), apart by more than 6 cm.
	var xs: Array[float] = []
	for v in verts:
		if v.y < low + 0.012:
			xs.append(v.x)
	xs.sort()
	var feet: Array[Vector2] = []
	var start := 0
	for i in range(1, xs.size() + 1):
		if i == xs.size() or xs[i] - xs[i - 1] > 0.06:
			var sum := 0.0
			for j in range(start, i):
				sum += xs[j]
			feet.append(Vector2(sum / (i - start), 0.0))
			start = i
	for f in feet.size():
		# The foot's depth (z): the mean of the ground vertices near it.
		var z := 0.0
		var k := 0
		for v in verts:
			if v.y < low + 0.012 and absf(v.x - feet[f].x) < 0.04:
				z += v.z
				k += 1
		feet[f].y = z / maxf(k, 1)
	# Connected pieces (union-find over the triangles).
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	var find := func(a: int) -> int:
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a
	for t in range(0, idx.size(), 3):
		var a: int = find.call(idx[t])
		for j in [1, 2]:
			var b: int = find.call(idx[t + j])
			if a != b:
				parent[b] = a
	var centre := {}
	var count := {}
	for i in verts.size():
		var r: int = find.call(i)
		centre[r] = centre.get(r, Vector3.ZERO) + verts[i]
		count[r] = count.get(r, 0) + 1
	var owner := {}
	for r: int in centre:
		var c: Vector3 = centre[r] / float(count[r])
		var best := 0
		for f in feet.size():
			if Vector2(c.x, c.z).distance_squared_to(feet[f]) < Vector2(c.x, c.z).distance_squared_to(feet[best]):
				best = f
		owner[r] = best
	var tris: Array[PackedInt32Array] = []
	tris.resize(feet.size())
	for t in range(0, idx.size(), 3):
		var f: int = owner[find.call(idx[t])]
		tris[f].append_array([idx[t], idx[t + 1], idx[t + 2]])
	var out: Array = []
	for f in feet.size():
		if tris[f].size() < 300:
			continue
		out.append(_subset(arrays, tris[f]))
	return out


## The vertices `tris` use, re-indexed.
static func _subset(arrays: Array, tris: PackedInt32Array) -> Array:
	var remap := {}
	var keep := PackedInt32Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(tris.size())
	for i in tris.size():
		var v := tris[i]
		if not remap.has(v):
			remap[v] = keep.size()
			keep.append(v)
		new_idx[i] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for ch in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV]:
		var src = arrays[ch]
		if src == null:
			continue
		var dst = src.duplicate()
		dst.resize(keep.size())
		for i in keep.size():
			dst[i] = src[keep[i]]
		out[ch] = dst
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var src: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var dst := PackedFloat32Array()
		dst.resize(keep.size() * 4)
		for i in keep.size():
			for c in 4:
				dst[i * 4 + c] = src[keep[i] * 4 + c]
		out[Mesh.ARRAY_TANGENT] = dst
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


## Bush `variant` of `kind`: [leaves ArrayMesh (with LODs), fruit ArrayMesh], materials unset.
static func build_bush(kind: StringName, variant: int) -> Array:
	var look: Dictionary = LOOK[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(kind)) + variant * 7919
	var pool := twigs(look["scan"])
	var radius: float = look["radius"]
	var n := rng.randi_range(look["twigs"][0], look["twigs"][1])
	var merged: Array = []
	for i in n:
		var src: Array = pool[rng.randi() % pool.size()]
		# Out from the middle; the outer twigs lean out further and stand lower.
		var a := TAU * (float(i) + rng.randf_range(-0.35, 0.35)) / float(n)
		var out_r := sqrt(rng.randf_range(0.05, 1.0))
		var lean := lerpf(float(look["lean"][0]), float(look["lean"][1]), out_r) + rng.randf_range(-0.1, 0.1)
		var s := rng.randf_range(look["scale"][0], look["scale"][1]) * lerpf(1.08, 0.82, out_r)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var basis := Basis(dir.cross(Vector3.UP).normalized(), -lean) * Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(s, s * rng.randf_range(0.9, 1.1), s))
		var foot := dir * out_r * radius * 0.35 + Vector3(0, -0.02, 0)
		var xf := Transform3D(basis, foot)
		var arrays := NatureModels._transformed(src, xf)
		merged = _append(merged, arrays)
	# Soil on the stems' feet: vertex alpha is the height over the ground / 4 m.
	var verts: PackedVector3Array = merged[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		colors[i] = Color(1, 1, 1, clampf(verts[i].y / 4.0, 0.0, 1.0))
	merged[Mesh.ARRAY_COLOR] = colors
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, merged)
	im.generate_lods(25.0, 60.0, [])
	var leaves_mesh := im.get_mesh()
	return [leaves_mesh, _build_fruit(kind, look, merged, rng)]


static func _append(a: Array, b: Array) -> Array:
	if a.is_empty():
		return b.duplicate()
	var base := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var out := a.duplicate()
	out[Mesh.ARRAY_VERTEX] = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array) + (b[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	out[Mesh.ARRAY_NORMAL] = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array) + (b[Mesh.ARRAY_NORMAL] as PackedVector3Array)
	out[Mesh.ARRAY_TANGENT] = (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array) + (b[Mesh.ARRAY_TANGENT] as PackedFloat32Array)
	out[Mesh.ARRAY_TEX_UV] = (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array) + (b[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
	var idx: PackedInt32Array = (b[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	for i in idx.size():
		idx[i] += base
	out[Mesh.ARRAY_INDEX] = (a[Mesh.ARRAY_INDEX] as PackedInt32Array) + idx
	return out


## The berries: clusters hung on the bush's outer leaves, where they can be seen.
static func _build_fruit(kind: StringName, look: Dictionary, leaves_arrays: Array, rng: RandomNumberGenerator) -> ArrayMesh:
	var verts: PackedVector3Array = leaves_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = leaves_arrays[Mesh.ARRAY_NORMAL]
	var top := 0.0
	var reach := 0.0
	for v in verts:
		top = maxf(top, v.y)
		reach = maxf(reach, Vector2(v.x, v.z).length())
	var mb := MeshBuilder.new()
	var spots: Array[Vector3] = []
	var size: float = look["size"]
	var tries := 0
	while spots.size() < int(look["clusters"]) and tries < 4000:
		tries += 1
		var i := rng.randi() % verts.size()
		var v := verts[i]
		# On the bush's outer shell, from knee height up.
		var shell := Vector2(v.x, v.z).length() / maxf(reach, 0.01) + v.y / maxf(top, 0.01) * 0.8
		if v.y < top * 0.28 or shell < 0.75:
			continue
		var clear := true
		for s in spots:
			if s.distance_squared_to(v) < 0.09 * 0.09:
				clear = false
				break
		if not clear:
			continue
		spots.append(v)
		var out := Vector3(v.x, 0.0, v.z).normalized()
		var n := normals[i].normalized() if normals[i].length() > 0.01 else out
		if n.dot(out) < 0.0:
			n = -n
		var per := rng.randi_range(look["per"][0], look["per"][1])
		var anchor := v + (n * 0.6 + out * 0.4).normalized() * size * 1.4
		for b in per:
			var p := anchor + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1.2, 0.3), rng.randf_range(-1, 1)) * size * 1.3 * minf(b, 1)
			var col: Color = look["ripe"]
			if rng.randf() < float(look["unripe_share"]):
				var list: Array = look["unripe"]
				col = list[rng.randi() % list.size()]
			col = Color(col.r * rng.randf_range(0.9, 1.1), col.g * rng.randf_range(0.9, 1.1), col.b * rng.randf_range(0.9, 1.1))
			# Hanging, the blossom end down and out.
			var hang := (Vector3.DOWN * 0.8 + out * 0.5 + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))).normalized()
			_berry(mb, look, p, -hang, size * rng.randf_range(0.85, 1.12), col, rng)
	var m := mb.build({&"berry": null}, true)
	var arrays := m.surface_get_arrays(0)
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


## One berry at `p`, its stem end towards `up` (colours in sRGB, MeshBuilder's way).
## `fine`: rounder, for the item seen up close in the hand.
static func _berry(mb: MeshBuilder, look: Dictionary, p: Vector3, up: Vector3, size: float, col: Color,
		rng: RandomNumberGenerator, fine := false) -> void:
	var basis := _basis_up(up)
	var seg := 2 if fine else 1
	match String(look["shape"]):
		"round":
			# A blueberry: a slightly flattened ball with its crown (a dark ring) at the tip.
			mb.sphere(&"berry", Transform3D(basis, p), Vector3(size, size * 0.86, size), 8 * seg, 6 * seg, col)
			var tip := p - up * size * 0.84
			mb.sphere(&"berry", Transform3D(basis, tip), Vector3(size * 0.34, size * 0.12, size * 0.34), 6, 3,
					col.darkened(0.55))
		"hip":
			# A rosehip: an egg, narrower at the tip, with its dried sepals.
			mb.sphere(&"berry", Transform3D(basis, p), Vector3(size * 0.78, size * 1.15, size * 0.78), 10 * seg, 8 * seg, col)
			var tip := p - up * size * 1.12
			for k in 5:
				var a := TAU * k / 5.0 + rng.randf()
				var out := basis * Vector3(cos(a), 0, sin(a))
				mb.cylinder_between(&"berry", tip, tip + (out * 0.9 - up * 0.5).normalized() * size * 0.7, size * 0.1, size * 0.02,
						3, Color(0.22, 0.14, 0.08))
		_:
			# Blackberries and raspberries: a thimble of drupelets.
			var rings := 3
			for r in rings:
				var t := (float(r) + 0.5) / rings
				var ring_y := lerpf(0.75, -0.95, t) * size
				var ring_r := sin(lerpf(0.5, 2.7, t)) * size * 0.95
				var count := maxi(3, roundi(ring_r / size * 5.0))
				for k in count:
					var a := TAU * (float(k) + 0.5 * float(r % 2)) / count
					var at := p + basis * Vector3(cos(a) * ring_r, ring_y, sin(a) * ring_r)
					mb.sphere(&"berry", Transform3D(basis, at), Vector3.ONE * size * 0.46 * rng.randf_range(0.9, 1.1), 9 if fine else 4, 6 if fine else 3,
							col * rng.randf_range(0.92, 1.06))
			mb.sphere(&"berry", Transform3D(basis, p - up * size * 0.9), Vector3.ONE * size * 0.4, 6, 4, col)


static func _basis_up(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized() * -1.0).orthonormalized()
