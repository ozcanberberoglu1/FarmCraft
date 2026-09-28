@tool
class_name SdfSculpt
extends RefCounted
## Signed-distance-field sculpting for organic, seamless meshes.
##
## Anatomy is described with primitives (ellipsoids and round cones) that are
## blended with smooth unions (and carved with smooth subtractions), then meshed
## with naive surface nets, projected onto the exact surface, and skinned to a
## skeleton using each primitive's bone. Every primitive also carries material
## attributes (color, pattern mask, colour zone, gloss...) that are blended per
## vertex. Used offline by tools/build_animals.gd; results are saved as scenes.

enum Kind { ELLIPSOID, ROUND_CONE }

const BIN := 0.08
## Surface id of eyes (AnimalBuilder.Surf.EYE).
const EYE_SURFACE := 5

# Primitive data (parallel arrays for speed).
var kinds := PackedInt32Array()
var subtract := PackedByteArray()
var blend := PackedFloat32Array()
var pa := PackedVector3Array()
var pb := PackedVector3Array()
var rad := PackedVector3Array()
var inv_basis: Array[Basis] = []
var noise_amp := PackedFloat32Array()
var noise_freq := PackedFloat32Array()
var bone := PackedInt32Array()
var color := PackedColorArray()
var surface := PackedInt32Array()
## (points zone, fixed color, gloss, fur amount)
var attr := PackedVector4Array()
## Adult-only features (combs, wattles) are marked 1.
var extra := PackedFloat32Array()
var aabbs: Array[AABB] = []

var noise := FastNoiseLite.new()

# Grid state.
var _origin := Vector3.ZERO
var _h := 0.02
var _n := Vector3i.ZERO
var _values := PackedFloat32Array()
var _bin_n := Vector3i.ZERO
var _bin_origin := Vector3.ZERO
var _bins: Array[PackedInt32Array] = []


func _init() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_octaves = 2
	noise.seed = 7


# --- Primitives ------------------------------------------------------------------------

## Adds an ellipsoid. Options: bone, color, surface, points, fixed, gloss, fur,
## noise ([amplitude, frequency]), subtract.
func ellipsoid(center: Vector3, radii: Vector3, k: float, opts: Dictionary = {}, rot_deg := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot_deg * (PI / 180.0))
	_add(Kind.ELLIPSOID, center, center, radii, b.inverse(), k, opts)
	var r := maxf(radii.x, maxf(radii.y, radii.z))
	aabbs.append(AABB(center - Vector3.ONE * r, Vector3.ONE * r * 2.0))


## Adds a round cone (capsule with different end radii) from a to b.
func cone(a: Vector3, b: Vector3, r1: float, r2: float, k: float, opts: Dictionary = {}) -> void:
	_add(Kind.ROUND_CONE, a, b, Vector3(r1, r2, 0.0), Basis(), k, opts)
	var box := AABB(a - Vector3.ONE * r1, Vector3.ONE * r1 * 2.0)
	box = box.merge(AABB(b - Vector3.ONE * r2, Vector3.ONE * r2 * 2.0))
	aabbs.append(box)


## A chain of round cones through points with per-point radii.
func chain(points: Array, radii: Array, k: float, opts: Dictionary = {}) -> void:
	for i in points.size() - 1:
		cone(points[i], points[i + 1], radii[i], radii[i + 1], k, opts)


func _add(kind: int, a: Vector3, b: Vector3, r: Vector3, ib: Basis, k: float, opts: Dictionary) -> void:
	kinds.append(kind)
	subtract.append(1 if opts.get("subtract", false) else 0)
	blend.append(maxf(k, 0.001))
	pa.append(a)
	pb.append(b)
	rad.append(r)
	inv_basis.append(ib)
	var nz: Array = opts.get("noise", [0.0, 1.0])
	noise_amp.append(nz[0])
	noise_freq.append(nz[1])
	bone.append(opts.get("bone", 0))
	# Colors are authored in sRGB; shaders work in linear space.
	var c: Color = opts.get("color", Color(1, 1, 1, 1))
	var lc := c.srgb_to_linear()
	lc.a = c.a
	color.append(lc)
	surface.append(opts.get("surface", 0))
	attr.append(Vector4(opts.get("points", 0.0), opts.get("fixed", 0.0), opts.get("gloss", 0.0), opts.get("fur", 1.0)))
	extra.append(1.0 if opts.get("adult_only", false) else 0.0)


func mirror_x(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


# --- Distance functions -----------------------------------------------------------------

func prim(i: int, p: Vector3) -> float:
	var d: float
	if kinds[i] == Kind.ELLIPSOID:
		var q := inv_basis[i] * (p - pa[i])
		var r := rad[i]
		var k0 := Vector3(q.x / r.x, q.y / r.y, q.z / r.z).length()
		var k1 := Vector3(q.x / (r.x * r.x), q.y / (r.y * r.y), q.z / (r.z * r.z)).length()
		d = k0 * (k0 - 1.0) / maxf(k1, 1e-9)
	else:
		d = _round_cone(p, pa[i], pb[i], rad[i].x, rad[i].y)
	if noise_amp[i] > 0.0:
		var f := noise_freq[i]
		d -= noise_amp[i] * noise.get_noise_3d(p.x * f, p.y * f, p.z * f)
	return d


static func _round_cone(p: Vector3, a: Vector3, b: Vector3, r1: float, r2: float) -> float:
	var ba := b - a
	var l2 := ba.dot(ba)
	if l2 < 1e-10:
		return p.distance_to(a) - maxf(r1, r2)
	var rr := r1 - r2
	var a2 := l2 - rr * rr
	var il2 := 1.0 / l2
	var q := p - a
	var y := q.dot(ba)
	var z := y - l2
	var w := q * l2 - ba * y
	var x2 := w.dot(w)
	var y2 := y * y * l2
	var z2 := z * z * l2
	var k := signf(rr) * rr * rr * x2
	if signf(z) * a2 * z2 > k:
		return sqrt(x2 + z2) * il2 - r2
	if signf(y) * a2 * y2 < k:
		return sqrt(x2 + y2) * il2 - r1
	return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1


## Blended distance at p using the primitives listed in `cand` (in insertion order).
func eval_with(p: Vector3, cand: PackedInt32Array) -> float:
	var d := 1e9
	for i in cand:
		var di := prim(i, p)
		var k := blend[i]
		if subtract[i] == 0:
			var h := maxf(k - absf(d - di), 0.0) / k
			d = minf(d, di) - h * h * k * 0.25
		else:
			var h := maxf(k - absf(d + di), 0.0) / k
			d = maxf(d, -di) + h * h * k * 0.25
	return d


func eval(p: Vector3) -> float:
	return eval_with(p, _cands_at(p))


func _cands_at(p: Vector3) -> PackedInt32Array:
	var b := Vector3i(((p - _bin_origin) / BIN).floor())
	if b.x < 0 or b.y < 0 or b.z < 0 or b.x >= _bin_n.x or b.y >= _bin_n.y or b.z >= _bin_n.z:
		return PackedInt32Array()
	return _bins[(b.z * _bin_n.y + b.y) * _bin_n.x + b.x]


## Walks from p along dir until just outside the surface (for placing hair on skin).
func project_out(p: Vector3, dir: Vector3, offset := 0.004) -> Vector3:
	var d := dir.normalized()
	var q := p
	for i in 200:
		var v := eval(q)
		if v >= offset:
			return q
		q += d * maxf(absf(v) * 0.6, 0.002)
	return q


## First surface hit from `from` travelling along dir (sphere tracing).
func raycast(from: Vector3, dir: Vector3, max_dist := 2.0) -> Vector3:
	var d := dir.normalized()
	var t := 0.0
	while t < max_dist:
		var v := eval(from + d * t)
		if v < 0.002:
			return from + d * t
		t += maxf(v * 0.8, 0.002)
	return from + d * max_dist


func gradient(p: Vector3) -> Vector3:
	var e := _h * 0.35
	var c := _cands_at(p)
	var k1 := Vector3(1, -1, -1)
	var k2 := Vector3(-1, -1, 1)
	var k3 := Vector3(-1, 1, -1)
	var k4 := Vector3(1, 1, 1)
	var g := k1 * eval_with(p + k1 * e, c) + k2 * eval_with(p + k2 * e, c) \
			+ k3 * eval_with(p + k3 * e, c) + k4 * eval_with(p + k4 * e, c)
	return g.normalized() if g.length_squared() > 1e-20 else Vector3.UP


# --- Meshing ----------------------------------------------------------------------------

## Samples the field and builds the mesh. Returns {verts, normals, tris} where tris
## index into verts.
func polygonize(cell: float) -> Dictionary:
	_h = cell
	var box := aabbs[0]
	for b in aabbs:
		box = box.merge(b)
	var margin := 0.06
	for i in blend.size():
		margin = maxf(margin, blend[i] * 0.5 + noise_amp[i] + 0.02)
	box = box.grow(margin + cell * 2.0)
	_origin = box.position
	_n = Vector3i(ceili(box.size.x / cell) + 1, ceili(box.size.y / cell) + 1, ceili(box.size.z / cell) + 1)
	_build_bins(box)
	_sample()
	return _surface_nets()


func _build_bins(box: AABB) -> void:
	_bin_origin = box.position
	_bin_n = Vector3i(ceili(box.size.x / BIN) + 1, ceili(box.size.y / BIN) + 1, ceili(box.size.z / BIN) + 1)
	_bins.clear()
	_bins.resize(_bin_n.x * _bin_n.y * _bin_n.z)
	for i in _bins.size():
		_bins[i] = PackedInt32Array()
	for i in kinds.size():
		var g := aabbs[i].grow(blend[i] + noise_amp[i] + 0.03)
		var lo := Vector3i(((g.position - _bin_origin) / BIN).floor()).clamp(Vector3i.ZERO, _bin_n - Vector3i.ONE)
		var hi := Vector3i(((g.end - _bin_origin) / BIN).floor()).clamp(Vector3i.ZERO, _bin_n - Vector3i.ONE)
		for z in range(lo.z, hi.z + 1):
			for y in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					_bins[(z * _bin_n.y + y) * _bin_n.x + x].append(i)


func _sample() -> void:
	_values.resize(_n.x * _n.y * _n.z)
	var idx := 0
	for z in _n.z:
		var pz := _origin.z + z * _h
		for y in _n.y:
			var py := _origin.y + y * _h
			for x in _n.x:
				var p := Vector3(_origin.x + x * _h, py, pz)
				var c := _cands_at(p)
				_values[idx] = eval_with(p, c) if not c.is_empty() else 1.0
				idx += 1


const CORNERS := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
const EDGES := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]


func _surface_nets() -> Dictionary:
	var nx := _n.x
	var nxy := _n.x * _n.y
	var cell_vert := PackedInt32Array()
	cell_vert.resize(_n.x * _n.y * _n.z)
	cell_vert.fill(-1)
	var verts := PackedVector3Array()
	var corner_off := PackedInt32Array()
	for c: Vector3i in CORNERS:
		corner_off.append(c.z * nxy + c.y * nx + c.x)
	var vals := PackedFloat32Array()
	vals.resize(8)
	for z in _n.z - 1:
		for y in _n.y - 1:
			var base := z * nxy + y * nx
			for x in _n.x - 1:
				var i0 := base + x
				var inside := 0
				for c in 8:
					var v := _values[i0 + corner_off[c]]
					vals[c] = v
					if v < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var sum := Vector3.ZERO
				var cnt := 0
				for e: Array in EDGES:
					var va := vals[e[0]]
					var vb := vals[e[1]]
					if (va < 0.0) == (vb < 0.0):
						continue
					var t := va / (va - vb)
					var ca: Vector3i = CORNERS[e[0]]
					var cb: Vector3i = CORNERS[e[1]]
					sum += Vector3(ca).lerp(Vector3(cb), t)
					cnt += 1
				var local := sum / float(cnt)
				cell_vert[i0] = verts.size()
				verts.append(_origin + (Vector3(x, y, z) + local) * _h)
	# Quads around every grid edge that crosses the surface.
	var tris := PackedInt32Array()
	for z in range(1, _n.z - 1):
		for y in range(1, _n.y - 1):
			for x in range(1, _n.x - 1):
				var i0 := z * nxy + y * nx + x
				var v0 := _values[i0]
				var in0 := v0 < 0.0
				# +X edge: cells sharing it lie at y-1..y, z-1..z.
				if (_values[i0 + 1] < 0.0) != in0:
					_quad(tris, cell_vert, i0 - nx - nxy, i0 - nxy, i0, i0 - nx)
				if (_values[i0 + nx] < 0.0) != in0:
					_quad(tris, cell_vert, i0 - 1 - nxy, i0 - nxy, i0, i0 - 1)
				if (_values[i0 + nxy] < 0.0) != in0:
					_quad(tris, cell_vert, i0 - 1 - nx, i0 - nx, i0, i0 - 1)
	return {"verts": verts, "tris": tris}


func _quad(tris: PackedInt32Array, cell_vert: PackedInt32Array, c0: int, c1: int, c2: int, c3: int) -> void:
	var a := cell_vert[c0]
	var b := cell_vert[c1]
	var c := cell_vert[c2]
	var d := cell_vert[c3]
	if a < 0 or b < 0 or c < 0 or d < 0:
		return
	tris.append_array([a, b, c, a, c, d])


## Moves vertices onto the exact surface and computes smooth normals; flips
## triangles so they face outward.
func refine(mesh: Dictionary, iterations := 2) -> void:
	var verts: PackedVector3Array = mesh["verts"]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		var p := verts[i]
		for it in iterations:
			var d := eval(p)
			var g := gradient(p)
			p -= g * d
		verts[i] = p
		normals[i] = gradient(p)
	mesh["verts"] = verts
	mesh["normals"] = normals
	var tris: PackedInt32Array = mesh["tris"]
	for t in range(0, tris.size(), 3):
		var a := verts[tris[t]]
		var b := verts[tris[t + 1]]
		var c := verts[tris[t + 2]]
		var gn := (b - a).cross(c - a)
		var avg := normals[tris[t]] + normals[tris[t + 1]] + normals[tris[t + 2]]
		# Stored order must be clockwise seen from outside (Godot front faces).
		if gn.dot(avg) > 0.0:
			var tmp := tris[t + 1]
			tris[t + 1] = tris[t + 2]
			tris[t + 2] = tmp
	mesh["tris"] = tris


# --- Attributes & skinning ---------------------------------------------------------------

## Blended material attributes and bone weights for a point on the surface.
## Returns [color, attr(Vector4), surface_id, bones(PackedInt32Array 4), weights(PackedFloat32Array 4), extra]
func attributes(p: Vector3) -> Array:
	var cand := _cands_at(p)
	var col := Color(0, 0, 0, 0)
	var at := Vector4.ZERO
	var wsum := 0.0
	var best := -1.0
	var surf := 0
	var bone_w := {}
	var ex := 0.0
	for i in cand:
		if subtract[i] == 1:
			continue
		var di := maxf(prim(i, p), 0.0)
		# Materials change sharply at the seam between parts; skinning blends wider.
		var w := exp(-di / 0.0035)
		if w > best:
			best = w
			surf = surface[i]
		# Eyes use their own material; keep their colour out of the surrounding skin.
		if surface[i] != EYE_SURFACE:
			col += color[i] * w
			at += attr[i] * w
			ex += extra[i] * w
			wsum += w
		var bw := exp(-di / 0.035)
		bone_w[bone[i]] = float(bone_w.get(bone[i], 0.0)) + bw
	if wsum <= 0.0 and surf == EYE_SURFACE:
		return [Color(0.05, 0.04, 0.035, 0.0), Vector4(0, 1, 0, 0), surf, _bones_only(p, cand), PackedFloat32Array([1, 0, 0, 0]), 0.0]
	if wsum <= 0.0:
		return [Color.WHITE, Vector4(0, 0, 0, 1), 0, PackedInt32Array([0, 0, 0, 0]), PackedFloat32Array([1, 0, 0, 0]), 0.0]
	col /= wsum
	at /= wsum
	var pairs := []
	for b in bone_w:
		pairs.append([bone_w[b], b])
	pairs.sort_custom(func(l, r): return l[0] > r[0])
	var bones := PackedInt32Array([0, 0, 0, 0])
	var weights := PackedFloat32Array([0, 0, 0, 0])
	var total := 0.0
	for j in mini(4, pairs.size()):
		total += pairs[j][0]
	for j in mini(4, pairs.size()):
		bones[j] = pairs[j][1]
		weights[j] = pairs[j][0] / total
	return [col, at, surf, bones, weights, ex / wsum]


func _bones_only(p: Vector3, cand: PackedInt32Array) -> PackedInt32Array:
	var best := INF
	var b := 0
	for i in cand:
		var d := prim(i, p)
		if d < best:
			best = d
			b = bone[i]
	return PackedInt32Array([b, 0, 0, 0])
