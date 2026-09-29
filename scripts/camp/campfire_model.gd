class_name CampfireModel
extends RefCounted
## The campfire's model, built here from photo material: a ring of photo-scanned stones
## (Poly Haven rock_09 and boulder_01, see art/models/nature/CREDITS.md) sooted on the
## side that faces the fire (shaders/campfire_stone.gdshader), a teepee of split logs
## over kindling and two fuel logs across the base, with bark photo maps (bark_brown_02)
## that char, crack and glow as the fire burns (shaders/campfire_wood.gdshader), and the
## bed of coals and ash under them. Also the flames' noise, the scorched ground's decal
## and the skewer sticks fish are cooked on. The fire's centre is the origin, the
## ground at y 0. Meshes and materials are made once and shared by every fire.

## Stones in the ring and the radius their centres sit at.
const STONES := 11
const RING_RADIUS := 0.47
## Scan pieces the stones are cut from: [scan, piece].
const STONE_SCANS := [["boulder_01", 0], ["rock_09", 0]]
## The most triangles a stone keeps (they are small: a coarse level of detail).
const STONE_TRIANGLES := 900
## Log vertex colour: R = how deep in the fire a point sits, G = the coal bed.
const LOG_SIDES := 9

static var _cache := {}


# --- Stones -------------------------------------------------------------------------

## [scan index, local transform] of each stone of the ring on flat ground: the ring's
## layout (seeded, the same for every fire; each fire sets their heights to its ground).
static func stone_layout() -> Array:
	if _cache.has("layout"):
		return _cache["layout"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	var out := []
	for i in STONES:
		var a := TAU * float(i) / STONES + rng.randf_range(-0.08, 0.08)
		# Mostly grey granite, now and then a rust-veined one.
		var scan := 1 if i % 4 == 2 else 0
		var box := stone_bounds(scan)
		var width := rng.randf_range(0.23, 0.3)
		var s := width / maxf(maxf(box.size.x, box.size.z), 0.001)
		var height := clampf(box.size.y * s, 0.15, 0.24)
		var size := Vector3(s, height / maxf(box.size.y, 0.001), s * rng.randf_range(0.8, 1.0))
		# Long side along the ring, tipped a little, sunk a few centimetres.
		var basis := Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.35, 0.35))
		basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)) * Basis(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
		basis = basis * Basis.from_scale(size)
		var r := RING_RADIUS + rng.randf_range(-0.025, 0.03)
		out.append([scan, Transform3D(basis, Vector3(cos(a) * r, -0.035, sin(a) * r))])
	_cache["layout"] = out
	return out


static func stone_bounds(scan: int) -> AABB:
	var s: Array = STONE_SCANS[scan]
	return NatureModels.piece_bounds(s[0], s[1])


## One stone of a scan at a coarse level of detail, only the vertices it uses kept.
static func stone_mesh(scan: int) -> ArrayMesh:
	var key := "stone_%d" % scan
	if _cache.has(key):
		return _cache[key]
	var arrays := _stone_arrays(scan)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, stone_material(scan))
	_cache[key] = m
	return m


static func _stone_arrays(scan: int) -> Array:
	var s: Array = STONE_SCANS[scan]
	var piece: Array = NatureModels.scan_pieces(s[0])[s[1]]
	var src: Array = piece[0]
	var indices: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	# The level of detail with the most triangles under the limit.
	var lods: Dictionary = piece[1]
	var best := indices
	for size: float in lods:
		var li: PackedInt32Array = lods[size]
		if li.size() / 3 <= STONE_TRIANGLES and (best.size() / 3 > STONE_TRIANGLES or li.size() > best.size()):
			best = li
	# Only the vertices those triangles use.
	var remap := {}
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var src_v: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var src_t: PackedFloat32Array = src[Mesh.ARRAY_TANGENT] if src[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var src_uv: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var out_i := PackedInt32Array()
	out_i.resize(best.size())
	for k in best.size():
		var old := best[k]
		var ni: int = remap.get(old, -1)
		if ni < 0:
			ni = verts.size()
			remap[old] = ni
			verts.append(src_v[old])
			normals.append(src_n[old])
			uvs.append(src_uv[old])
			if not src_t.is_empty():
				tangents.append_array(src_t.slice(old * 4, old * 4 + 4))
		out_i[k] = ni
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not tangents.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = out_i
	return arrays


static func stone_material(scan: int) -> ShaderMaterial:
	var key := "stone_mat_%d" % scan
	if _cache.has(key):
		return _cache[key]
	var src := NatureModels.scan_material(String(STONE_SCANS[scan][0]))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/campfire_stone.gdshader")
	for p in ["albedo_tex", "normal_tex", "rough_tex", "arm"]:
		m.set_shader_parameter(p, src.get_shader_parameter(p))
	# The granite boulder a cool grey; rock_09 a warm, rust-veined stone.
	m.set_shader_parameter("tint", Color(0.85, 0.85, 0.84) if scan == 0 else Color(0.7, 0.68, 0.66))
	_cache[key] = m
	return m


# --- Wood ---------------------------------------------------------------------------

static func wood_material() -> ShaderMaterial:
	if _cache.has("wood_mat"):
		return _cache["wood_mat"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/campfire_wood.gdshader")
	m.set_shader_parameter("albedo_tex", Mats.texture("bark_brown_02", "diff.jpg"))
	m.set_shader_parameter("normal_tex", Mats.texture("bark_brown_02", "nor.jpg"))
	m.set_shader_parameter("arm_tex", Mats.texture("bark_brown_02", "arm.jpg"))
	_cache["wood_mat"] = m
	return m


## The logs laid in the ring: five split logs leaning together in a teepee over a
## handful of kindling, two fuel logs across the base.
static func logs_mesh() -> ArrayMesh:
	if _cache.has("logs"):
		return _cache["logs"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	# Fuel logs across the base.
	_log(st, Vector3(-0.31, 0.05, -0.1), Vector3(0.3, 0.055, 0.07), 0.062, 0.055, rng)
	_log(st, Vector3(-0.08, 0.075, 0.3), Vector3(0.1, 0.08, -0.3), 0.056, 0.05, rng)
	# Kindling: thin sticks leaning in at the centre.
	for i in 7:
		var a := TAU * float(i) / 7.0 + rng.randf_range(-0.3, 0.3)
		var base := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.12, 0.17) + Vector3(0, 0.03, 0)
		var tip := Vector3(cos(a + 0.9), 0.0, sin(a + 0.9)) * 0.03 + Vector3(0, rng.randf_range(0.18, 0.24), 0)
		_log(st, base, tip, 0.012, 0.008, rng, 5)
	# The teepee: split logs from the ring's floor up to a crossing over the centre.
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3 + rng.randf_range(-0.12, 0.12)
		var base := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.26, 0.3) + Vector3(0, 0.02, 0)
		var top := Vector3(cos(a + 0.5), 0.0, sin(a + 0.5)) * 0.035 + Vector3(0, rng.randf_range(0.43, 0.48), 0)
		# Past the crossing a little.
		top = base + (top - base) * 1.1
		_log(st, base, top, rng.randf_range(0.045, 0.058), rng.randf_range(0.036, 0.044), rng)
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, wood_material())
	_cache["logs"] = m
	return m


## A log from `a` to `b` (radii at each end): bark all round with a little knobbly
## unevenness, sawn ends; bark UVs in metres.
static func _log(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, rng: RandomNumberGenerator,
		sides := LOG_SIDES) -> void:
	var axis := b - a
	var length := axis.length()
	var t := axis / length
	var side := t.cross(Vector3.UP if absf(t.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(t).normalized()
	var rings := maxi(2, ceili(length / 0.07) + 1)
	var phase := rng.randf() * 10.0
	var grid: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	for i in rings:
		var f := float(i) / float(rings - 1)
		var c := a + axis * f
		var r := lerpf(ra, rb, f)
		var ring := PackedVector3Array()
		var nring := PackedVector3Array()
		for k in sides:
			var ang := TAU * float(k) / sides
			var d := side * cos(ang) + up * sin(ang)
			var bump := 1.0 + 0.09 * sin(ang * 3.0 + phase + f * 5.0) * sin(f * 11.0 + phase)
			ring.append(c + d * r * bump)
			nring.append(d)
		grid.append(ring)
		norms.append(nring)
	var circ := TAU * (ra + rb) * 0.5
	for i in rings - 1:
		for k in sides:
			var k1 := (k + 1) % sides
			var u0 := float(k) / sides * circ
			var u1 := float(k + 1) / sides * circ
			var v0 := float(i) / float(rings - 1) * length
			var v1 := float(i + 1) / float(rings - 1) * length
			# Clockwise from outside (Godot's front faces).
			_vert(st, grid[i][k], norms[i][k], Vector2(u0, v0))
			_vert(st, grid[i][k1], norms[i][k1], Vector2(u1, v0))
			_vert(st, grid[i + 1][k1], norms[i + 1][k1], Vector2(u1, v1))
			_vert(st, grid[i][k], norms[i][k], Vector2(u0, v0))
			_vert(st, grid[i + 1][k1], norms[i + 1][k1], Vector2(u1, v1))
			_vert(st, grid[i + 1][k], norms[i + 1][k], Vector2(u0, v1))
	# Sawn ends (the char covers their end grain once burning).
	for e in 2:
		var ring := grid[0] if e == 0 else grid[rings - 1]
		var c := a if e == 0 else b
		var n := -t if e == 0 else t
		for k in sides:
			var k1 := (k + 1) % sides
			var p0 := ring[k]
			var p1 := ring[k1]
			if e == 0:
				_vert(st, c, n, Vector2(0.5, 0.5) * 0.1)
				_vert(st, p1, n, Vector2(0.1, 0.0))
				_vert(st, p0, n, Vector2(0.0, 0.0))
			else:
				_vert(st, c, n, Vector2(0.5, 0.5) * 0.1)
				_vert(st, p0, n, Vector2(0.0, 0.0))
				_vert(st, p1, n, Vector2(0.1, 0.0))


## A vertex with its colour: R how deep in the fire it sits (the centre and the flames
## over it), G 0 (wood).
static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, bed := 0.0) -> void:
	var d := Vector2(p.x, p.z).length()
	var exposure := clampf(1.0 - (d - 0.05) / 0.3, 0.0, 1.0)
	st.set_color(Color(exposure, bed, 0.0, 1.0))
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)


## The bed under the logs: a low mound of ash and coals spreading to the stones, lumps
## of charcoal on it.
static func bed_mesh() -> ArrayMesh:
	if _cache.has("bed"):
		return _cache["bed"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 91
	noise.frequency = 6.0
	var rings := 7
	var sides := 22
	var outer := 0.44
	var pts: Array[PackedVector3Array] = []
	for i in rings + 1:
		var r := outer * float(i) / rings
		var ring := PackedVector3Array()
		for k in sides:
			var a := TAU * float(k) / sides
			var x := cos(a) * r
			var z := sin(a) * r
			# Heaped in the middle, thinning out to the stones.
			var h := 0.045 * (1.0 - pow(r / outer, 1.6)) + noise.get_noise_2d(x, z) * 0.012 * (1.0 - r / outer) - 0.004
			ring.append(Vector3(x, h, z))
		pts.append(ring)
	for i in rings:
		for k in sides:
			var k1 := (k + 1) % sides
			var a0 := pts[i][k]
			var a1 := pts[i][k1]
			var b0 := pts[i + 1][k]
			var b1 := pts[i + 1][k1]
			var n := (b0 - a0).cross(a1 - a0).normalized()
			if n.y < 0.0:
				n = -n
			for p: Vector3 in [a0, b0, b1, a0, b1, a1]:
				_vert(st, p, n, Vector2(p.x, p.z), 1.0)
	# Charcoal lumps.
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var ico: Dictionary = MeshBuilder._icosphere(1)
	var unit: PackedVector3Array = ico["verts"]
	var faces: PackedInt32Array = ico["faces"]
	for i in 18:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.24
		var size := Vector3(rng.randf_range(0.025, 0.05), rng.randf_range(0.015, 0.03), rng.randf_range(0.02, 0.04))
		var c := Vector3(cos(a) * r, 0.03 * (1.0 - r / 0.3) + size.y * 0.3, sin(a) * r)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		for f in range(0, faces.size(), 3):
			var p: Array[Vector3] = []
			for j in 3:
				var v := unit[faces[f + j]]
				var bump := 1.0 + noise.get_noise_3dv(v * 3.0 + Vector3(i, 0, 0)) * 0.35
				p.append(c + basis * (v * size * bump))
			var n := (p[1] - p[0]).cross(p[2] - p[0]).normalized()
			_vert(st, p[0], n, Vector2(p[0].x, p[0].z) * 3.0, 1.0)
			_vert(st, p[2], n, Vector2(p[2].x, p[2].z) * 3.0, 1.0)
			_vert(st, p[1], n, Vector2(p[1].x, p[1].z) * 3.0, 1.0)
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, wood_material())
	_cache["bed"] = m
	return m


## A green stick a fish is cooked on, pushed into the ground at the origin, pointing
## up its Y axis (`length` long).
static func stick_mesh(length: float) -> ArrayMesh:
	var key := "stick_%.2f" % length
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_log(st, Vector3(0, -0.06, 0), Vector3(0.004, length, -0.006), 0.011, 0.006, rng, 6)
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, wood_material())
	_cache[key] = m
	return m


# --- The whole thing -----------------------------------------------------------------

## Stones, logs (fresh) on flat ground as one mesh: the item, the placement preview.
static func whole_mesh() -> ArrayMesh:
	if _cache.has("whole"):
		return _cache["whole"]
	var m := ArrayMesh.new()
	for scan in STONE_SCANS.size():
		var src := _stone_arrays(scan)
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var tangents := PackedFloat32Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
		var stan: Variant = src[Mesh.ARRAY_TANGENT]
		var suv: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
		var si: PackedInt32Array = src[Mesh.ARRAY_INDEX]
		for entry: Array in stone_layout():
			if int(entry[0]) != scan:
				continue
			var xf: Transform3D = entry[1]
			var nb := xf.basis.inverse().transposed()
			var base := verts.size()
			for v in sv:
				verts.append(xf * v)
			for n in sn:
				normals.append((nb * n).normalized())
			if stan != null:
				var tt: PackedFloat32Array = stan
				for k in range(0, tt.size(), 4):
					var tv := (xf.basis * Vector3(tt[k], tt[k + 1], tt[k + 2])).normalized()
					tangents.append(tv.x)
					tangents.append(tv.y)
					tangents.append(tv.z)
					tangents.append(tt[k + 3])
			uvs.append_array(suv)
			for i in si:
				idx.append(base + i)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		if not tangents.is_empty():
			arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(m.get_surface_count() - 1, stone_material(scan))
	var logs := logs_mesh()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, logs.surface_get_arrays(0))
	m.surface_set_material(m.get_surface_count() - 1, wood_material())
	_cache["whole"] = m
	return m


# --- Textures -------------------------------------------------------------------------

## Tileable noise the flames are eaten away by.
static func flame_noise() -> Texture2D:
	if _cache.has("noise"):
		return _cache["noise"]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.035
	n.fractal_octaves = 3
	n.seed = 3
	var t := NoiseTexture2D.new()
	t.width = 128
	t.height = 128
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	_cache["noise"] = t
	return t


## The scorched ground around a fire: soot black at the ring, fading out in ragged
## patches (alpha), a little ash grey in the middle.
static func scorch_texture() -> Texture2D:
	if _cache.has("scorch"):
		return _cache["scorch"]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 44
	n.frequency = 0.06
	n.fractal_octaves = 3
	for y in size:
		for x in size:
			var p := Vector2(x, y) / float(size - 1) * 2.0 - Vector2.ONE
			var r := p.length()
			var k := n.get_noise_2d(x, y) * 0.5 + 0.5
			var edge := 0.62 + (k - 0.5) * 0.35
			var a := 1.0 - smoothstep(edge - 0.25, edge, r)
			var soot := Color(0.045, 0.04, 0.036).lerp(Color(0.2, 0.17, 0.13), smoothstep(0.35, 0.8, r))
			var ash := Color(0.42, 0.4, 0.37)
			var col := soot.lerp(ash, (1.0 - smoothstep(0.0, 0.32, r)) * 0.35 * k)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a * (0.75 + 0.25 * k), 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["scorch"] = t
	return t
