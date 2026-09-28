@tool
class_name ToolModels
extends RefCounted
## Photo-scanned tool models (Poly Haven, Sketchfab; see art/models/tools/CREDITS.md)
## baked into one mesh each and brought into ItemModels' frame, so held-item poses,
## pickups and icons keep working:
##   long tools lie along +Y, head up, grip end at `bottom`, the head sticking out
##   toward `side` (±X or ±Z; flat ones face `flat` instead), `length` long;
##   containers stand on their base at the origin, `size` across their longest side.
## The handle axis comes from the principal axis of the vertices; the head is the end
## where the geometry spreads out most. `fix` (degrees) turns the result afterwards.
## Heavy scans get automatic LODs. tools/bake_tools.gd saves the results to BAKED so
## the game only loads them (building the shears takes ~130 ms); rerun it after
## changing MODELS.

const MODELS := {
	&"axe": {"path": "res://art/models/tools/wooden_axe/wooden_axe_1k.gltf", "kind": "long",
		"length": 0.83, "bottom": -0.36, "side": Vector3.RIGHT},
	&"pickaxe": {"path": "res://art/models/tools/picke_dirty_01/picke_dirty_01_1k.gltf", "kind": "long",
		"length": 0.97, "bottom": -0.4, "side": Vector3.RIGHT},
	# `side` is where the narrow chisel sticks out; the broad blade faces the other way,
	# down toward the soil in the hand.
	&"hoe": {"path": "res://art/models/tools/garden_hoe/scene.gltf", "kind": "long",
		"length": 1.33, "bottom": -0.42, "side": Vector3.BACK},
	&"scythe": {"path": "res://art/models/tools/scythe/scene.gltf", "kind": "long",
		"length": 1.44, "bottom": -0.6, "side": Vector3.RIGHT},
	&"pitchfork": {"path": "res://art/models/tools/pitchfork/scene.gltf", "kind": "long",
		"length": 1.74, "bottom": -0.6, "flat": Vector3.BACK},
	&"shears": {"path": "res://art/models/tools/sheep_shears/scene.gltf", "kind": "long",
		"length": 0.3, "bottom": -0.1, "flat": Vector3.BACK},
	&"watering_can": {"path": "res://art/models/tools/watering_can_metal_01/watering_can_metal_01_1k.gltf",
		"kind": "upright", "size": 0.59},
	&"milk_pail": {"path": "res://art/models/tools/wooden_bucket_01/wooden_bucket_01_1k.gltf",
		"kind": "upright", "size": 0.37},
}
## Scans heavier than this get LODs for distant pickups.
const LOD_TRIANGLES := 20000
const BAKED := "res://art/models/tools/baked/%s.res"


static func has(id: StringName) -> bool:
	return MODELS.has(id) and (ResourceLoader.exists(BAKED % id) or ResourceLoader.exists(MODELS[id]["path"]))


static func mesh(id: StringName) -> ArrayMesh:
	if ResourceLoader.exists(BAKED % id):
		return load(BAKED % id) as ArrayMesh
	return build(id)


## Builds the item-space mesh from the source model.
static func build(id: StringName) -> ArrayMesh:
	var cfg: Dictionary = MODELS[id]
	var parts := MeshMerge.scene_parts(load(cfg["path"]) as PackedScene)
	var points := MeshMerge.points(parts)
	var frame := _long_frame(points, cfg) if cfg["kind"] == "long" else _upright_frame(points, cfg)
	var surfaces := []
	MeshMerge.add_parts(surfaces, parts, frame)
	return MeshMerge.build(surfaces, LOD_TRIANGLES)


## Model space -> item space for a long tool.
static func _long_frame(points: PackedVector3Array, cfg: Dictionary) -> Transform3D:
	var pca := _principal_axes(points)
	var center: Vector3 = pca[0]
	var axis: Vector3 = pca[1]
	var t_min := INF
	var t_max := -INF
	for p in points:
		var t := (p - center).dot(axis)
		t_min = minf(t_min, t)
		t_max = maxf(t_max, t)
	# The head is the end where the geometry spreads farthest from the axis.
	var span := t_max - t_min
	var spread := [0.0, 0.0]
	var counts := [0, 0]
	var head_sum := [Vector3.ZERO, Vector3.ZERO]
	for p in points:
		var d := p - center
		var t := d.dot(axis)
		var end := 0 if t < t_min + span * 0.2 else (1 if t > t_max - span * 0.2 else -1)
		if end < 0:
			continue
		spread[end] += (d - axis * t).length_squared()
		counts[end] += 1
		head_sum[end] += p
	var low := float(spread[0]) / maxf(counts[0], 1)
	var high := float(spread[1]) / maxf(counts[1], 1)
	var head_end := 1 if high >= low else 0
	if head_end == 0:
		axis = -axis
		var t_swap := -t_max
		t_max = -t_min
		t_min = t_swap
	var y := axis
	var x: Vector3
	var z: Vector3
	if cfg.has("flat"):
		# Flat tools (shears) face their thinnest axis toward `flat` (+Z).
		z = (pca[3] as Vector3).normalized()
		z = (z - y * z.dot(y)).normalized()
		x = y.cross(z).normalized()
	else:
		var head: Vector3 = head_sum[head_end] / maxf(counts[head_end], 1)
		var out := head - center
		out = out - y * out.dot(y)
		if out.length() < span * 0.01:
			out = pca[2]
		out = out.normalized()
		var sd: Vector3 = cfg.get("side", Vector3.RIGHT)
		if absf(sd.z) > 0.5:
			z = out * signf(sd.z)
			x = y.cross(z).normalized()
		else:
			x = out * signf(sd.x)
			z = x.cross(y).normalized()
	var s := float(cfg["length"]) / maxf(span, 0.0001)
	# Rows are the new axes: item = s * basis * (p - grip).
	var basis := Basis(Vector3(x.x, y.x, z.x), Vector3(x.y, y.y, z.y), Vector3(x.z, y.z, z.z)).scaled(Vector3.ONE * s)
	# The grip end sits on the handle axis at `bottom`.
	var grip := Vector3.ZERO
	var n := 0
	for p in points:
		if (p - center).dot(y) < t_min + span * 0.12:
			grip += p
			n += 1
	grip = grip / maxf(n, 1)
	grip = center + y * t_min + (grip - center - y * (grip - center).dot(y))
	var frame := Transform3D(basis, -(basis * grip) + Vector3(0, float(cfg["bottom"]), 0))
	return _fixed(frame, cfg)


## Model space -> item space for a container: upright, base centred on the origin.
static func _upright_frame(points: PackedVector3Array, cfg: Dictionary) -> Transform3D:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	var s := float(cfg["size"]) / maxf(box.get_longest_axis_size(), 0.0001)
	var base := Vector3.ZERO
	var n := 0
	for p in points:
		if p.y < box.position.y + box.size.y * 0.1:
			base += p
			n += 1
	base = base / maxf(n, 1)
	base.y = box.position.y
	var frame := Transform3D(Basis.from_scale(Vector3.ONE * s), -base * s)
	return _fixed(frame, cfg)


static func _fixed(frame: Transform3D, cfg: Dictionary) -> Transform3D:
	if not cfg.has("fix"):
		return frame
	return Transform3D(Basis.from_euler((cfg["fix"] as Vector3) * (PI / 180.0)), Vector3.ZERO) * frame


## [mean, main axis, second axis, third axis] of a point cloud.
static func _principal_axes(points: PackedVector3Array) -> Array:
	var mean := Vector3.ZERO
	for p in points:
		mean += p
	mean /= maxf(points.size(), 1)
	var c := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for p in points:
		var d := p - mean
		for i in 3:
			for j in 3:
				c[i][j] += d[i] * d[j]
	var axes: Array[Vector3] = []
	var start: Array[Vector3] = [Vector3(1, 0.7, 0.3), Vector3(0.3, 1, 0.7), Vector3(0.7, 0.3, 1)]
	for k in 2:
		var v := start[k].normalized()
		for it in 64:
			var w := Vector3(c[0][0] * v.x + c[0][1] * v.y + c[0][2] * v.z,
					c[1][0] * v.x + c[1][1] * v.y + c[1][2] * v.z,
					c[2][0] * v.x + c[2][1] * v.y + c[2][2] * v.z)
			for a in axes:
				w -= a * w.dot(a)
			if w.length() < 1e-12:
				break
			v = w.normalized()
		axes.append(v)
	return [mean, axes[0], axes[1], axes[0].cross(axes[1]).normalized()]
