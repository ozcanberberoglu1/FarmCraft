class_name CoplanarScan
extends RefCounted
## Finds z-fighting in built models: pairs of triangles that lie in one plane (their
## planes within `tol` metres of each other), face the same way and overlap. Two such
## faces are drawn at the same depth, so which one shows flickers with the view (worst
## from 20-40 m, where a 24-bit depth buffer steps in millimetres).
## scan(root) reads every visible MeshInstance3D under `root`; scan_meshes() takes
## [[mesh, transform, label]] lists. Each hit: {a, b (labels: "Node/surface"), at (between
## the two triangles' middles, in root space), n (the way they face), area (m2), gap (m),
## same, backed}. Two kinds of hit never show and are left out of fighting():
## - `same`: faces of one surface in one colour lying exactly in one plane (boards of the
##   same paint butted over each other: nothing to tell them apart);
## - `backed`: faces lying against a face turned the other way in the same plane (the
##   undersides of two things standing on a floor: only seen from inside the floor).

## Normals are binned to this many steps per unit; planes to `tol`.
const NORMAL_STEPS := 2048.0
## Overlaps smaller than this (m2) are slivers at shared edges, not faces.
const MIN_AREA := 0.0001

## Triangles read by the last scan (a scan of nothing proves nothing).
static var last_triangles := 0

var _tol := 0.001
## Triangles by plane: (binned normal, binned distance) -> [index].
var _bins := {}
## One 2D frame per binned normal: every triangle in it is laid out in the same 2D.
var _frames := {}
var _pts: Array[PackedVector2Array] = []
var _rects: Array[Rect2] = []
var _dist := PackedFloat64Array()
var _src := PackedInt32Array()
var _tint: Array[Color] = []
var _keys: Array[Vector4i] = []
var _cent := PackedVector3Array()
var _labels: Array[String] = []
var _two_sided: Array[bool] = []


## Every hit under `root` (see the class notes). `skip`: node names left out (and all
## under them).
static func scan(root: Node3D, tol := 0.001, skip: Array[StringName] = []) -> Array[Dictionary]:
	var meshes: Array = []
	_collect(root, root.global_transform.affine_inverse(), root, skip, meshes)
	return scan_meshes(meshes, tol)


static func scan_meshes(meshes: Array, tol := 0.001) -> Array[Dictionary]:
	var s := CoplanarScan.new()
	s._tol = tol
	for m: Array in meshes:
		s._read(m[0], m[1], m[2], (m[3] as MeshInstance3D) if m.size() > 3 else null)
	last_triangles = s._pts.size()
	return s._hits()


## The hits that show: neither `same` nor `backed`.
static func fighting(hits: Array[Dictionary]) -> Array[Dictionary]:
	return hits.filter(func(h: Dictionary) -> bool: return not h["same"] and not h["backed"])


## Square metres of faces fighting among the hits.
static func total_area(hits: Array[Dictionary]) -> float:
	var sum := 0.0
	for h: Dictionary in fighting(hits):
		sum += h["area"]
	return sum


## The hits grouped by the two surfaces, the way they face and (`cell` > 0) the place,
## that many metres across; largest first: [{a, b, area, count, gap, same, backed, at, n}].
static func summary(hits: Array[Dictionary], cell := 0.0) -> Array[Dictionary]:
	var groups := {}
	for h: Dictionary in hits:
		var key := "%s | %s | %s | %s%s" % [h["a"], h["b"], Vector3i(((h["n"] as Vector3) * 4.0).round()), h["same"], h["backed"]]
		if cell > 0.0:
			key += " | %s" % Vector3i(((h["at"] as Vector3) / cell).round())
		if not groups.has(key):
			groups[key] = {"a": h["a"], "b": h["b"], "area": 0.0, "count": 0, "gap": 0.0, "same": h["same"], "backed": h["backed"],
					"at": h["at"], "top": 0.0, "n": h["n"]}
		var g: Dictionary = groups[key]
		g["area"] += h["area"]
		g["count"] += 1
		g["gap"] = maxf(g["gap"], h["gap"])
		if h["area"] > g["top"]:
			# Where its largest overlap is.
			g["top"] = h["area"]
			g["at"] = h["at"]
	var out: Array[Dictionary] = []
	out.assign(groups.values())
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["area"] > q["area"])
	return out


static func _collect(node: Node, inv: Transform3D, root: Node3D, skip: Array[StringName], out: Array) -> void:
	if node != root and node.name in skip:
		return
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh != null and mi.is_visible_in_tree():
		out.append([mi.mesh, inv * mi.global_transform, String(root.get_path_to(mi)), mi])
	for c in node.get_children():
		_collect(c, inv, root, skip, out)


func _read(mesh: Mesh, xf: Transform3D, label: String, mi: MeshInstance3D) -> void:
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		var colors: Variant = arrays[Mesh.ARRAY_COLOR]
		var mat: Material = mi.get_active_material(s) if mi else mesh.surface_get_material(s)
		var sname := (mesh as ArrayMesh).surface_get_name(s) if mesh is ArrayMesh else ""
		_labels.append("%s/%s" % [label, sname if sname != "" else str(s)])
		_two_sided.append(_is_two_sided(mat))
		var source := _labels.size() - 1
		var count: int = (index as PackedInt32Array).size() if index != null else verts.size()
		for i in range(0, count - 2, 3):
			var ia: int = index[i] if index != null else i
			var ib: int = index[i + 1] if index != null else i + 1
			var ic: int = index[i + 2] if index != null else i + 2
			var a := xf * verts[ia]
			var b := xf * verts[ib]
			var c := xf * verts[ic]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-12:
				continue
			n = n.normalized()
			var nk := Vector3i(roundi(n.x * NORMAL_STEPS), roundi(n.y * NORMAL_STEPS), roundi(n.z * NORMAL_STEPS))
			var p := PackedVector2Array([_flat(nk, a), _flat(nk, b), _flat(nk, c)])
			if (p[1] - p[0]).cross(p[2] - p[0]) < 0.0:
				p = PackedVector2Array([p[0], p[2], p[1]])
			var d := n.dot((a + b + c) / 3.0)
			var key := Vector4i(nk.x, nk.y, nk.z, floori(d / _tol))
			_pts.append(p)
			_rects.append(Rect2(p[0], Vector2.ZERO).expand(p[1]).expand(p[2]))
			_dist.append(d)
			_src.append(source)
			_tint.append(colors[ia] if colors != null else Color.WHITE)
			_keys.append(key)
			_cent.append((a + b + c) / 3.0)
			if not _bins.has(key):
				_bins[key] = []
			(_bins[key] as Array).append(_pts.size() - 1)


## `p` in the 2D frame of the planes binned to normal `nk`.
func _flat(nk: Vector3i, p: Vector3) -> Vector2:
	if not _frames.has(nk):
		var fn := Vector3(nk).normalized()
		var u := fn.cross(Vector3.UP if absf(fn.y) < 0.9 else Vector3.RIGHT).normalized()
		_frames[nk] = [u, fn.cross(u)]
	var f: Array = _frames[nk]
	return Vector2(p.dot(f[0]), p.dot(f[1]))


func _hits() -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for id in _pts.size():
		var key := _keys[id]
		for step: int in [-1, 0, 1]:
			_pairs(id, _bins.get(Vector4i(key.x, key.y, key.z, key.w + step)), false, hits)
		if _two_sided[_src[id]]:
			# Drawn from both sides: it fights another such face turned the other way too (a
			# one-sided face against its back is a thing standing on it, seen from one side only).
			var back := floori(-_dist[id] / _tol)
			for step: int in [-1, 0, 1]:
				_pairs(id, _bins.get(Vector4i(-key.x, -key.y, -key.z, back + step)), true, hits)
	return hits


func _pairs(id: int, others: Variant, flipped: bool, hits: Array[Dictionary]) -> void:
	if others == null:
		return
	# Shrunk a little, so faces that only touch along an edge are not looked at.
	var r := _rects[id]
	r = r.grow(-minf(0.0015, minf(r.size.x, r.size.y) * 0.45))
	var key := _keys[id]
	for other: int in others as Array:
		# Each pair once.
		if other <= id or (flipped and not _two_sided[_src[other]]):
			continue
		var gap := absf(_dist[id] - (-_dist[other] if flipped else _dist[other]))
		if gap > _tol:
			continue
		var q := _pts[other]
		if flipped:
			# A plane seen from behind: its frame is this one's with X turned round.
			q = PackedVector2Array([Vector2(-q[0].x, q[0].y), Vector2(-q[2].x, q[2].y), Vector2(-q[1].x, q[1].y)])
		if not r.intersects(Rect2(q[0], Vector2.ZERO).expand(q[1]).expand(q[2]), false):
			continue
		var poly := _clip(_pts[id], q)
		var area := _area(poly)
		if area < MIN_AREA:
			continue
		var mid := Vector2.ZERO
		for p: Vector2 in poly:
			mid += p / poly.size()
		hits.append({"a": _labels[_src[id]], "b": _labels[_src[other]], "area": area, "gap": gap,
				"at": (_cent[id] + _cent[other]) * 0.5,
				# The way the faces look (MeshBuilder winds its triangles clockwise from the front).
				"n": -Vector3(key.x, key.y, key.z).normalized(),
				"same": not flipped and _src[id] == _src[other] and _tint[id].is_equal_approx(_tint[other]) and gap < 1e-5,
				"backed": not flipped and _backed(id, mid)})


## Whether a face turned the other way lies in triangle `id`'s plane over `at` (in its 2D
## frame): the faces there are pressed against a solid and never seen.
func _backed(id: int, at: Vector2) -> bool:
	var key := _keys[id]
	var back := floori(-_dist[id] / _tol)
	var p := Vector2(-at.x, at.y)
	for step: int in [-1, 0, 1]:
		var others: Variant = _bins.get(Vector4i(-key.x, -key.y, -key.z, back + step))
		if others == null:
			continue
		for other: int in others as Array:
			if absf(_dist[id] + _dist[other]) > _tol or not _rects[other].has_point(p):
				continue
			var t := _pts[other]
			if (t[1] - t[0]).cross(p - t[0]) >= 0.0 and (t[2] - t[1]).cross(p - t[1]) >= 0.0 and (t[0] - t[2]).cross(p - t[2]) >= 0.0:
				return true
	return false


## The part of triangle `subject` inside triangle `clip` (both counter-clockwise).
static func _clip(subject: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	var out := subject
	for i in 3:
		var a := clip[i]
		var b := clip[(i + 1) % 3]
		var edge := b - a
		var next := PackedVector2Array()
		for k in out.size():
			var p := out[k]
			var q := out[(k + 1) % out.size()]
			var sp := edge.cross(p - a)
			var sq := edge.cross(q - a)
			if sp >= 0.0:
				next.append(p)
			if (sp > 0.0 and sq < 0.0) or (sp < 0.0 and sq > 0.0):
				next.append(p + (q - p) * (sp / (sp - sq)))
		out = next
		if out.size() < 3:
			return PackedVector2Array()
	return out


static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(sum) * 0.5


static func _is_two_sided(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
		return (mat as ShaderMaterial).shader.code.contains("cull_disabled")
	return false
