@tool
class_name MeshBuilder
extends RefCounted
## Accumulates low-poly primitives into an ArrayMesh with one surface per material key.
##
## - Colors are given in sRGB (as in design tools) and stored linear.
## - Vertex alpha holds the wind-sway weight read by foliage shaders (0 = rigid).
## - Triangles are passed counter-clockwise as seen from their front side; they are
##   emitted in Godot's clockwise front-face order.
## - UVs of boxes/cylinders are in meters so procedural textures keep their scale.


class Surface:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()


static var _ico_cache: Dictionary = {}

var _surfaces: Dictionary = {}


static func lin(c: Color) -> Color:
	var l := c.srgb_to_linear()
	l.a = c.a
	return l


func is_empty() -> bool:
	for key in _surfaces:
		if not (_surfaces[key] as Surface).verts.is_empty():
			return false
	return true


func _surface(key: StringName) -> Surface:
	var s: Surface = _surfaces.get(key)
	if s == null:
		s = Surface.new()
		_surfaces[key] = s
	return s


# --- Raw triangles -------------------------------------------------------------

## Flat-shaded triangle, counter-clockwise from the front.
func tri(key: StringName, a: Vector3, b: Vector3, c: Vector3, color: Color,
		uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	tri_n(key, a, b, c, n, n, n, color, color, color, uv_a, uv_b, uv_c)


## Triangle with explicit per-vertex normals and colors.
func tri_n(key: StringName, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color,
		uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO) -> void:
	var s := _surface(key)
	s.verts.append(a)
	s.verts.append(c)
	s.verts.append(b)
	s.normals.append(na)
	s.normals.append(nc)
	s.normals.append(nb)
	s.colors.append(lin(ca))
	s.colors.append(lin(cc))
	s.colors.append(lin(cb))
	s.uvs.append(uv_a)
	s.uvs.append(uv_c)
	s.uvs.append(uv_b)


## Planar quad a-b-c-d, counter-clockwise from the front.
func quad(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color,
		uv_a := Vector2(0, 0), uv_b := Vector2(1, 0), uv_c := Vector2(1, 1), uv_d := Vector2(0, 1)) -> void:
	tri(key, a, b, c, color, uv_a, uv_b, uv_c)
	tri(key, a, c, d, color, uv_a, uv_c, uv_d)


## Double-sided quad (for thin cards such as leaves or cloth).
func quad2(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	quad(key, a, b, c, d, color)
	quad(key, d, c, b, a, color)


# --- Primitives ----------------------------------------------------------------

## Box of `size` centered on the origin of `xf`. `uv_rotate` swaps UV axes so
## plank textures run vertically on side faces.
func box(key: StringName, xf: Transform3D, size: Vector3, color: Color, uv_rotate := false) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, h.y, -h.z), xf * Vector3(-h.x, h.y, -h.z),
		xf * Vector3(-h.x, -h.y, h.z), xf * Vector3(h.x, -h.y, h.z),
		xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z)]
	_box_face(key, p[4], p[5], p[6], p[7], size.x, size.y, color, uv_rotate)  # +Z
	_box_face(key, p[1], p[0], p[3], p[2], size.x, size.y, color, uv_rotate)  # -Z
	_box_face(key, p[5], p[1], p[2], p[6], size.z, size.y, color, uv_rotate)  # +X
	_box_face(key, p[0], p[4], p[7], p[3], size.z, size.y, color, uv_rotate)  # -X
	_box_face(key, p[7], p[6], p[2], p[3], size.x, size.z, color, uv_rotate)  # +Y
	_box_face(key, p[0], p[1], p[5], p[4], size.x, size.z, color, uv_rotate)  # -Y


## Convenience: box at `center` with euler rotation in degrees.
func box_at(key: StringName, center: Vector3, size: Vector3, color: Color,
		rot_deg := Vector3.ZERO, uv_rotate := false) -> void:
	var b := Basis.from_euler(rot_deg * (PI / 180.0))
	box(key, Transform3D(b, center), size, color, uv_rotate)


func _box_face(key: StringName, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		u_len: float, v_len: float, color: Color, uv_rotate: bool) -> void:
	if uv_rotate:
		quad(key, a, b, c, d, color, Vector2(0, 0), Vector2(0, u_len), Vector2(v_len, u_len), Vector2(v_len, 0))
	else:
		quad(key, a, b, c, d, color, Vector2(0, 0), Vector2(u_len, 0), Vector2(u_len, v_len), Vector2(0, v_len))


## Tapered cylinder standing on the origin of `xf` (base at y=0, top at y=height).
## A zero top radius makes a cone.
func cylinder(key: StringName, xf: Transform3D, r_bottom: float, r_top: float, height: float,
		segments: int, color: Color, smooth := true, caps := true, color_top := Color(-1, 0, 0)) -> void:
	var top_col := color if color_top.r < 0.0 else color_top
	var nbasis := xf.basis.inverse().transposed()
	var slope := (r_bottom - r_top) / maxf(height, 0.0001)
	var circumference := TAU * (r_bottom + r_top) * 0.5
	var apex := xf * Vector3(0, height, 0)
	var is_cone := r_top < 0.0001
	for i in segments:
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var b0 := xf * (d0 * r_bottom)
		var b1 := xf * (d1 * r_bottom)
		var t0 := xf * (d0 * r_top + Vector3(0, height, 0))
		var t1 := xf * (d1 * r_top + Vector3(0, height, 0))
		var u0 := float(i) / segments * circumference
		var u1 := float(i + 1) / segments * circumference
		if smooth:
			var n0 := (nbasis * (d0 + Vector3(0, slope, 0))).normalized()
			var n1 := (nbasis * (d1 + Vector3(0, slope, 0))).normalized()
			if is_cone:
				var nm := (n0 + n1).normalized()
				tri_n(key, b1, b0, apex, n1, n0, nm, color, color, top_col,
						Vector2(u1, 0), Vector2(u0, 0), Vector2((u0 + u1) * 0.5, height))
			else:
				tri_n(key, b1, b0, t0, n1, n0, n0, color, color, top_col,
						Vector2(u1, 0), Vector2(u0, 0), Vector2(u0, height))
				tri_n(key, b1, t0, t1, n1, n0, n1, color, top_col, top_col,
						Vector2(u1, 0), Vector2(u0, height), Vector2(u1, height))
		else:
			var fn := (b0 - b1).cross((t0 if not is_cone else apex) - b1).normalized()
			if is_cone:
				tri_n(key, b1, b0, apex, fn, fn, fn, color, color, top_col)
			else:
				tri_n(key, b1, b0, t0, fn, fn, fn, color, color, top_col,
						Vector2(u1, 0), Vector2(u0, 0), Vector2(u0, height))
				tri_n(key, b1, t0, t1, fn, fn, fn, color, top_col, top_col,
						Vector2(u1, 0), Vector2(u0, height), Vector2(u1, height))
		if caps:
			if not is_cone:
				tri(key, apex, t1, t0, top_col, Vector2(0, 0), Vector2(d1.x, d1.z) * r_top, Vector2(d0.x, d0.z) * r_top)
			if r_bottom > 0.0001:
				tri(key, xf * Vector3.ZERO, b0, b1, color)


## Cylinder between two points (useful for branches, rails, rope).
func cylinder_between(key: StringName, from: Vector3, to: Vector3, r_from: float, r_to: float,
		segments: int, color: Color, smooth := true, caps := true) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 0.0001:
		return
	var y := dir / length
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	cylinder(key, Transform3D(Basis(x, y, z), from), r_from, r_to, length, segments, color, smooth, caps)


## UV sphere / ellipsoid centered on the origin of `xf`.
func sphere(key: StringName, xf: Transform3D, radii: Vector3, segments: int, rings: int,
		color: Color, smooth := true) -> void:
	var nbasis := xf.basis.inverse().transposed()
	var inv_r := Vector3(1.0 / radii.x, 1.0 / radii.y, 1.0 / radii.z)
	for r in rings:
		var v0 := PI * float(r) / rings
		var v1 := PI * float(r + 1) / rings
		for s in segments:
			var u0 := TAU * float(s) / segments
			var u1 := TAU * float(s + 1) / segments
			var d00 := _sph(v0, u0)
			var d01 := _sph(v0, u1)
			var d11 := _sph(v1, u1)
			var d10 := _sph(v1, u0)
			var p00 := xf * (d00 * radii)
			var p01 := xf * (d01 * radii)
			var p11 := xf * (d11 * radii)
			var p10 := xf * (d10 * radii)
			if smooth:
				var n00 := (nbasis * (d00 * inv_r)).normalized()
				var n01 := (nbasis * (d01 * inv_r)).normalized()
				var n11 := (nbasis * (d11 * inv_r)).normalized()
				var n10 := (nbasis * (d10 * inv_r)).normalized()
				if r > 0:
					tri_n(key, p00, p01, p11, n00, n01, n11, color, color, color)
				if r < rings - 1:
					tri_n(key, p00, p11, p10, n00, n11, n10, color, color, color)
			else:
				tri(key, p00, p01, p11, color)
				tri(key, p00, p11, p10, color)


static func _sph(v: float, u: float) -> Vector3:
	return Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))


## Noise-displaced icosphere: rocks, foliage clumps, bushes. Flat shaded by default;
## `smooth` averages normals for rounded, realistic surfaces. `flatten_bottom` squashes
## everything below that fraction of the radius (rocks resting on the ground).
## `jitter` randomly varies the brightness of each face.
func blob(key: StringName, xf: Transform3D, radius: float, subdiv: int, color: Color,
		noise_amp := 0.0, noise_freq := 1.2, seed_value := 0, jitter := 0.0, smooth := false,
		flatten_bottom := -2.0) -> void:
	var topo: Dictionary = _icosphere(subdiv)
	var unit: PackedVector3Array = topo["verts"]
	var faces: PackedInt32Array = topo["faces"]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = noise_freq
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	var local := PackedVector3Array()
	local.resize(unit.size())
	for i in unit.size():
		var v := unit[i]
		var p := v * radius * (1.0 + noise.get_noise_3dv(v) * noise_amp)
		if p.y < flatten_bottom * radius:
			p.y = lerpf(flatten_bottom * radius, p.y, 0.15)
		local[i] = p
	var pts := PackedVector3Array()
	pts.resize(local.size())
	for i in local.size():
		pts[i] = xf * local[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	if smooth:
		var acc := PackedVector3Array()
		acc.resize(pts.size())
		for i in range(0, faces.size(), 3):
			var a := pts[faces[i]]
			var fn := (pts[faces[i + 1]] - a).cross(pts[faces[i + 2]] - a)
			for k in 3:
				acc[faces[i + k]] += fn
		for i in range(0, faces.size(), 3):
			var ia := faces[i]
			var ib := faces[i + 1]
			var ic := faces[i + 2]
			tri_n(key, pts[ia], pts[ib], pts[ic], acc[ia].normalized(), acc[ib].normalized(),
					acc[ic].normalized(), color, color, color)
		return
	for i in range(0, faces.size(), 3):
		var c := color
		if jitter > 0.0:
			var f := 1.0 + rng.randf_range(-jitter, jitter)
			c = Color(c.r * f, c.g * f, c.b * f, c.a)
		tri(key, pts[faces[i]], pts[faces[i + 1]], pts[faces[i + 2]], c)


## Deformed box from 8 corners, in the same order box() uses:
## (-x-y-z), (+x-y-z), (+x+y-z), (-x+y-z), (-x-y+z), (+x-y+z), (+x+y+z), (-x+y+z).
## Handy for wedges such as axe heads and blades.
func hexa(key: StringName, p: Array[Vector3], color: Color) -> void:
	_box_face(key, p[4], p[5], p[6], p[7], p[4].distance_to(p[5]), p[4].distance_to(p[7]), color, false)
	_box_face(key, p[1], p[0], p[3], p[2], p[1].distance_to(p[0]), p[1].distance_to(p[2]), color, false)
	_box_face(key, p[5], p[1], p[2], p[6], p[5].distance_to(p[1]), p[5].distance_to(p[6]), color, false)
	_box_face(key, p[0], p[4], p[7], p[3], p[0].distance_to(p[4]), p[0].distance_to(p[3]), color, false)
	_box_face(key, p[7], p[6], p[2], p[3], p[7].distance_to(p[6]), p[7].distance_to(p[3]), color, false)
	_box_face(key, p[0], p[1], p[5], p[4], p[0].distance_to(p[1]), p[0].distance_to(p[4]), color, false)


## Smooth tube through `centers` with per-ring radii (a "loft"): carrots, eggplants,
## corn cobs, horns, curved handles. Ends are closed with fans when `caps` is true.
func loft(key: StringName, centers: Array[Vector3], radii: Array[float], segments: int, color: Color,
		caps := true, colors: Array[Color] = []) -> void:
	var n := centers.size()
	if n < 2:
		return
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var prev_side := Vector3.ZERO
	for i in n:
		var t := (centers[mini(i + 1, n - 1)] - centers[maxi(i - 1, 0)]).normalized()
		var side := prev_side
		if side == Vector3.ZERO or absf(side.dot(t)) > 0.99:
			side = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		side = (side - t * side.dot(t)).normalized()
		prev_side = side
		var up := t.cross(side).normalized()
		var ring := PackedVector3Array()
		var nring := PackedVector3Array()
		for k in segments:
			var a := TAU * float(k) / segments
			var d := side * cos(a) + up * sin(a)
			ring.append(centers[i] + d * radii[i])
			nring.append(d)
		rings.append(ring)
		normals.append(nring)
	# Tilt normals for changing radii (so tapered ends shade correctly).
	for i in n:
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, n - 1)
		var dr := radii[i1] - radii[i0]
		var dl := centers[i1].distance_to(centers[i0])
		var t := (centers[i1] - centers[i0]).normalized()
		for k in segments:
			normals[i][k] = (normals[i][k] - t * (dr / maxf(dl, 0.0001))).normalized()
	var length := 0.0
	for i in n - 1:
		var c0: Color = colors[i] if i < colors.size() else color
		var c1: Color = colors[i + 1] if i + 1 < colors.size() else color
		var seg_len := centers[i].distance_to(centers[i + 1])
		for k in segments:
			var k1 := (k + 1) % segments
			var u0 := float(k) / segments
			var u1 := float(k + 1) / segments
			var a := rings[i][k]
			var b := rings[i][k1]
			var c := rings[i + 1][k1]
			var d := rings[i + 1][k]
			var uv_a := Vector2(u0, length)
			var uv_b := Vector2(u1, length)
			var uv_c := Vector2(u1, length + seg_len)
			var uv_d := Vector2(u0, length + seg_len)
			# Rings run counter-clockwise around the axis, so (a, b, c) faces outward.
			tri_n(key, a, b, c, normals[i][k], normals[i][k1], normals[i + 1][k1], c0, c0, c1, uv_a, uv_b, uv_c)
			tri_n(key, a, c, d, normals[i][k], normals[i + 1][k1], normals[i + 1][k], c0, c1, c1, uv_a, uv_c, uv_d)
		length += seg_len
	if caps:
		var t0 := (centers[0] - centers[1]).normalized()
		var t1 := (centers[n - 1] - centers[n - 2]).normalized()
		for k in segments:
			var k1 := (k + 1) % segments
			if radii[0] > 0.0001:
				tri_n(key, centers[0], rings[0][k1], rings[0][k], t0, t0, t0, color, color, color)
			if radii[n - 1] > 0.0001:
				tri_n(key, centers[n - 1], rings[n - 1][k], rings[n - 1][k1], t1, t1, t1, color, color, color)


## Smooth organic tube (bodies, necks, heads, limbs): cross-sections are ellipses
## with half-extents radii[i] = (side, up), kept upright relative to `up_hint`.
## Normals come from the surface itself, so tapering and bends shade correctly.
## Ends are left open; pass tiny end radii for rounded tips. colors[i] tints ring i
## (vertex alpha included).
func loft_ellipse(key: StringName, centers: Array[Vector3], radii: Array[Vector2], segments: int,
		color: Color, colors: Array[Color] = [], up_hint := Vector3.UP) -> void:
	var n := centers.size()
	if n < 2:
		return
	var grid: Array[PackedVector3Array] = []
	for i in n:
		var t := (centers[mini(i + 1, n - 1)] - centers[maxi(i - 1, 0)]).normalized()
		var up := up_hint - t * up_hint.dot(t)
		if up.length_squared() < 1e-6:
			up = t.cross(Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.FORWARD)
		up = up.normalized()
		var side := up.cross(t).normalized()
		var ring := PackedVector3Array()
		for k in segments:
			var a := TAU * float(k) / segments
			ring.append(centers[i] + side * cos(a) * radii[i].x + up * sin(a) * radii[i].y)
		grid.append(ring)
	var normals: Array[PackedVector3Array] = []
	for i in n:
		var nring := PackedVector3Array()
		for k in segments:
			var dk := grid[i][(k + 1) % segments] - grid[i][(k - 1 + segments) % segments]
			var di := grid[mini(i + 1, n - 1)][k] - grid[maxi(i - 1, 0)][k]
			var nn := dk.cross(di)
			if nn.length_squared() < 1e-12:
				nn = grid[i][k] - centers[i]
			nn = nn.normalized()
			if nn.dot(grid[i][k] - centers[i]) < 0.0:
				nn = -nn
			nring.append(nn)
		normals.append(nring)
	var v := 0.0
	for i in n - 1:
		var c0: Color = colors[i] if i < colors.size() else color
		var c1: Color = colors[i + 1] if i + 1 < colors.size() else color
		var seg_len := centers[i].distance_to(centers[i + 1])
		for k in segments:
			var k1 := (k + 1) % segments
			var u0 := float(k) / segments
			var u1 := float(k + 1) / segments
			tri_n(key, grid[i][k], grid[i][k1], grid[i + 1][k1], normals[i][k], normals[i][k1], normals[i + 1][k1],
					c0, c0, c1, Vector2(u0, v), Vector2(u1, v), Vector2(u1, v + seg_len))
			tri_n(key, grid[i][k], grid[i + 1][k1], grid[i + 1][k], normals[i][k], normals[i + 1][k1], normals[i + 1][k],
					c0, c1, c1, Vector2(u0, v), Vector2(u1, v + seg_len), Vector2(u0, v + seg_len))
		v += seg_len


## Flat disc in the XZ plane of `xf`, facing +Y (UVs in meters, centered).
func disc(key: StringName, xf: Transform3D, radius: float, segments: int, color: Color) -> void:
	var c := xf * Vector3.ZERO
	for k in segments:
		var a0 := TAU * float(k) / segments
		var a1 := TAU * float(k + 1) / segments
		var p0 := Vector2(cos(a0), sin(a0)) * radius
		var p1 := Vector2(cos(a1), sin(a1)) * radius
		tri(key, c, xf * Vector3(p1.x, 0, p1.y), xf * Vector3(p0.x, 0, p0.y), color, Vector2.ZERO, p1, p0)


## Hollow cylinder (tube) with flat top and bottom rings.
func ring(key: StringName, xf: Transform3D, r_outer: float, r_inner: float, height: float,
		segments: int, color: Color, jitter := 0.0, seed_value := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var up := Vector3(0, height, 0)
	for i in segments:
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var c := color
		if jitter > 0.0:
			var f := 1.0 + rng.randf_range(-jitter, jitter)
			c = Color(c.r * f, c.g * f, c.b * f)
		var ob0 := xf * (d0 * r_outer)
		var ob1 := xf * (d1 * r_outer)
		var ot0 := xf * (d0 * r_outer + up)
		var ot1 := xf * (d1 * r_outer + up)
		var ib0 := xf * (d0 * r_inner)
		var ib1 := xf * (d1 * r_inner)
		var it0 := xf * (d0 * r_inner + up)
		var it1 := xf * (d1 * r_inner + up)
		quad(key, ob1, ob0, ot0, ot1, c)   # outer wall
		quad(key, ib0, ib1, it1, it0, c)   # inner wall (faces inward)
		quad(key, ot1, ot0, it0, it1, c)   # top
		quad(key, ob0, ob1, ib1, ib0, c)   # bottom


## Triangular prism: triangle (-w/2,0)-(w/2,0)-(0,h) in the XY plane extruded along Z.
func prism(key: StringName, xf: Transform3D, width: float, height: float, depth: float,
		color: Color, bottom := true) -> void:
	var w := width * 0.5
	var d := depth * 0.5
	var fl := xf * Vector3(-w, 0, d)
	var fr := xf * Vector3(w, 0, d)
	var ft := xf * Vector3(0, height, d)
	var bl := xf * Vector3(-w, 0, -d)
	var br := xf * Vector3(w, 0, -d)
	var bt := xf * Vector3(0, height, -d)
	tri(key, fl, fr, ft, color, Vector2(0, 0), Vector2(width, 0), Vector2(w, height))
	tri(key, br, bl, bt, color, Vector2(0, 0), Vector2(width, 0), Vector2(w, height))
	var slope_len := Vector2(w, height).length()
	quad(key, fl, ft, bt, bl, color, Vector2(0, 0), Vector2(0, slope_len), Vector2(depth, slope_len), Vector2(depth, 0))
	quad(key, br, bt, ft, fr, color, Vector2(0, 0), Vector2(0, slope_len), Vector2(depth, slope_len), Vector2(depth, 0))
	if bottom:
		quad(key, bl, br, fr, fl, color)


## Thin leaf card: a diamond shape from `base` along `dir`, facing `normal`.
## Use `double_sided` only with back-face-culled materials; foliage materials
## already render both sides.
func leaf(key: StringName, base: Vector3, dir: Vector3, normal: Vector3, length: float,
		width: float, color: Color, tip_color := Color(-1, 0, 0), droop := 0.0,
		double_sided := false) -> void:
	var tip_c := color if tip_color.r < 0.0 else tip_color
	var d := dir.normalized()
	var n := normal.normalized()
	var side := d.cross(n).normalized() * width * 0.5
	var mid := base + d * length * 0.45 + Vector3.DOWN * droop * 0.3
	var tip := base + d * length + Vector3.DOWN * droop
	var l := mid + side
	var r := mid - side
	tri_n(key, base, l, tip, n, n, n, color, color, tip_c)
	tri_n(key, base, tip, r, n, n, n, color, tip_c, color)
	if double_sided:
		tri_n(key, base, tip, l, -n, -n, -n, color, tip_c, color)
		tri_n(key, base, r, tip, -n, -n, -n, color, color, tip_c)


## Foliage card: a quad centered on `center`, spanning `right` and `up` (full
## extents), textured with `uv_rect` of an atlas. `shade_normal` is used for all four
## vertices (e.g. pointing away from the crown center for soft, volumetric lighting).
func card(key: StringName, center: Vector3, right: Vector3, up: Vector3, uv_rect: Rect2,
		shade_normal: Vector3, color: Color, sway_bottom := 1.0, sway_top := 1.0) -> void:
	var r := right * 0.5
	var u := up * 0.5
	var bl := center - r - u
	var br := center + r - u
	var tr := center + r + u
	var tl := center - r + u
	var uv_bl := Vector2(uv_rect.position.x, uv_rect.end.y)
	var uv_br := uv_rect.end
	var uv_tr := Vector2(uv_rect.end.x, uv_rect.position.y)
	var uv_tl := uv_rect.position
	var n := shade_normal.normalized()
	var cb := Color(color.r, color.g, color.b, sway_bottom)
	var ct := Color(color.r, color.g, color.b, sway_top)
	tri_n(key, bl, br, tr, n, n, n, cb, cb, ct, uv_bl, uv_br, uv_tr)
	tri_n(key, bl, tr, tl, n, n, n, cb, ct, ct, uv_bl, uv_tr, uv_tl)


# --- Post-processing -----------------------------------------------------------

## Writes the sway weight (vertex alpha) from height: 0 at y_min, `strength` at y_max.
func set_sway_by_height(key: StringName, y_min: float, y_max: float, strength := 1.0) -> void:
	var s: Surface = _surfaces.get(key)
	if s == null:
		return
	var span := maxf(y_max - y_min, 0.001)
	for i in s.verts.size():
		var c := s.colors[i]
		c.a = clampf((s.verts[i].y - y_min) / span, 0.0, 1.0) * strength
		s.colors[i] = c


## Multiplies every vertex color (rgb) by `factor` — e.g. browning withered plants.
func tint_all(factor: Color) -> void:
	for key in _surfaces:
		var surf: Surface = _surfaces[key]
		for i in surf.colors.size():
			var c := surf.colors[i]
			surf.colors[i] = Color(c.r * factor.r, c.g * factor.g, c.b * factor.b, c.a)


## Appends all surfaces of `other`, transformed by `xf`.
func append(other: MeshBuilder, xf := Transform3D.IDENTITY) -> void:
	var nbasis := xf.basis.inverse().transposed()
	for key in other._surfaces:
		var src: Surface = other._surfaces[key]
		var dst := _surface(key)
		for i in src.verts.size():
			dst.verts.append(xf * src.verts[i])
			dst.normals.append((nbasis * src.normals[i]).normalized())
		dst.colors.append_array(src.colors)
		dst.uvs.append_array(src.uvs)


## Every vertex position of every surface (e.g. for a convex collision hull).
func vertices() -> PackedVector3Array:
	var out := PackedVector3Array()
	for key in _surfaces:
		out.append_array((_surfaces[key] as Surface).verts)
	return out


## `indexed` shares vertices between triangles (see _weld), so fewer vertices are
## shaded in every pass. Only for meshes that are just drawn: code that copies
## triangles out of a mesh (BuildingKit.append_mesh, MarketStall) expects a plain list.
func build(material_overrides: Dictionary = {}, indexed := false) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _surfaces:
		var s: Surface = _surfaces[key]
		if s.verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.verts
		arrays[Mesh.ARRAY_NORMAL] = s.normals
		arrays[Mesh.ARRAY_TANGENT] = _tangents(s)
		arrays[Mesh.ARRAY_COLOR] = s.colors
		arrays[Mesh.ARRAY_TEX_UV] = s.uvs
		if indexed:
			_weld(arrays)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_name(idx, String(key))
		var mat: Material = material_overrides[key] if material_overrides.has(key) else Mats.get_mat(key)
		mesh.surface_set_material(idx, mat)
	return mesh


## Per-triangle tangents from the UV layout, following Godot's convention
## (tangent along +U, sign chosen so normal maps in OpenGL format shade correctly).
static func _tangents(s: Surface) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(s.verts.size() * 4)
	for i in range(0, s.verts.size(), 3):
		var p0 := s.verts[i]
		var e1 := s.verts[i + 1] - p0
		var e2 := s.verts[i + 2] - p0
		var d1 := s.uvs[i + 1] - s.uvs[i]
		var d2 := s.uvs[i + 2] - s.uvs[i]
		var r := d1.x * d2.y - d2.x * d1.y
		var t := Vector3.RIGHT
		var b := Vector3.FORWARD
		if absf(r) > 1e-10:
			t = (e1 * d2.y - e2 * d1.y) / r
			b = (e2 * d1.x - e1 * d2.x) / r
		for k in 3:
			var n := s.normals[i + k]
			var tn := (t - n * n.dot(t))
			if tn.length_squared() < 1e-12:
				tn = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
			tn = tn.normalized()
			var w := -1.0 if n.cross(tn).dot(b) > 0.0 else 1.0
			var o := (i + k) * 4
			out[o] = tn.x
			out[o + 1] = tn.y
			out[o + 2] = tn.z
			out[o + 3] = w
	return out


## Largest tangent difference still treated as the same vertex: per-triangle tangents
## of one flat card differ only by rounding, far below the GPU's 16-bit precision.
const TANGENT_WELD := 1e-5


## Rewrites a triangle list as shared vertices plus an index buffer, keeping the
## triangle order. Vertices merge only when position, normal, colour and UV are
## identical (flat-shaded faces keep their own vertices) and tangents match.
static func _weld(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_tangents := PackedFloat32Array()
	var out_colors := PackedColorArray()
	var out_uvs := PackedVector2Array()
	var index := PackedInt32Array()
	index.resize(verts.size())
	var at_position := {}
	for i in verts.size():
		var t := i * 4
		var same: Array = at_position.get(verts[i], [])
		var found := -1
		for j: int in same:
			var u := j * 4
			if out_normals[j] == normals[i] and out_colors[j] == colors[i] and out_uvs[j] == uvs[i] \
					and out_tangents[u + 3] == tangents[t + 3] \
					and absf(out_tangents[u] - tangents[t]) < TANGENT_WELD \
					and absf(out_tangents[u + 1] - tangents[t + 1]) < TANGENT_WELD \
					and absf(out_tangents[u + 2] - tangents[t + 2]) < TANGENT_WELD:
				found = j
				break
		if found < 0:
			found = out_verts.size()
			if same.is_empty():
				at_position[verts[i]] = same
			same.append(found)
			out_verts.append(verts[i])
			out_normals.append(normals[i])
			out_colors.append(colors[i])
			out_uvs.append(uvs[i])
			for k in 4:
				out_tangents.append(tangents[t + k])
		index[i] = found
	arrays[Mesh.ARRAY_VERTEX] = out_verts
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_TANGENT] = out_tangents
	arrays[Mesh.ARRAY_COLOR] = out_colors
	arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	arrays[Mesh.ARRAY_INDEX] = index


# --- Icosphere topology --------------------------------------------------------

static func _icosphere(subdiv: int) -> Dictionary:
	if _ico_cache.has(subdiv):
		return _ico_cache[subdiv]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array[int] = [
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	for _level in subdiv:
		var mid_cache := {}
		var new_faces: Array[int] = []
		for i in range(0, faces.size(), 3):
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			var ab := _mid(a, b, verts, mid_cache)
			var bc := _mid(b, c, verts, mid_cache)
			var ca := _mid(c, a, verts, mid_cache)
			new_faces.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		faces = new_faces
	var result := {"verts": PackedVector3Array(verts), "faces": PackedInt32Array(faces)}
	_ico_cache[subdiv] = result
	return result


static func _mid(a: int, b: int, verts: Array[Vector3], cache: Dictionary) -> int:
	var k := Vector2i(mini(a, b), maxi(a, b))
	if cache.has(k):
		return cache[k]
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	cache[k] = verts.size() - 1
	return verts.size() - 1
