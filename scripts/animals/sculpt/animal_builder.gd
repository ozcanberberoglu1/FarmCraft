@tool
class_name AnimalBuilder
extends RefCounted
## Turns an anatomy definition (SDF sculpt + skeleton + hair/feather cards) into a
## skinned, LOD'ed model scene: Model(Node3D) > Skeleton3D > MeshInstance3D.
##
## Vertex channels for the animal shaders:
##   COLOR   rgb base color multiplier, a = pattern mask (patches allowed)
##   UV      x = colour zone (0 coat, 1 points), y = fixed colour (ignores tint)
##   UV2     x = gloss, y = fur amount       (cards: UV = texture coordinates)
##   CUSTOM0 xyz = rest position (stable pattern space), w = adult-only feature

enum Surf { FUR, WOOL, FEATHER, KERATIN, SKIN, EYE, HAIR_CARD, FEATHER_CARD }

const SHADERS := {
	Surf.FUR: 0, Surf.WOOL: 1, Surf.FEATHER: 2, Surf.KERATIN: 3, Surf.SKIN: 4,
}

var sculpt: SdfSculpt
## [[name, parent_index, global_position], ...]
var bones: Array = []
## Cards: {surface, points: Array[Vector3], width: float, normal: Vector3, uv: Rect2, color: Color}
var cards: Array = []
var cell := 0.02
## Called after meshing with the builder, so cards can be placed on the surface.
var card_builders: Array[Callable] = []
## Eyeballs: {center, radius, bone, look, iris: Color, pupil: Vector2 (half size, fraction of the iris)}
var eyes: Array = []
var _eye_look := {"iris": Color(0.24, 0.13, 0.06), "pupil": Vector2(0.55, 0.28), "iris_size": 0.8}


func bone_index(bone_name: String) -> int:
	for i in bones.size():
		if bones[i][0] == bone_name:
			return i
	push_error("unknown bone " + bone_name)
	return 0


func add_bone(bone_name: String, parent: String, pos: Vector3) -> int:
	bones.append([bone_name, bone_index(parent) if parent != "" else -1, pos])
	return bones.size() - 1


## A hair or feather card following `points`, `width` wide, facing `normal`.
func add_card(surface_id: int, points: Array, width: float, normal: Vector3, uv := Rect2(0, 0, 1, 1),
		tint := Color.WHITE, taper := 0.3) -> void:
	cards.append({"surface": surface_id, "points": points, "width": width, "normal": normal, "uv": uv,
		"color": tint, "taper": taper})


## A real eyeball (UV sphere) set into the head: `near` is a point roughly where the
## eye sits, `look` the direction it faces. The ball is pushed out until it sits on
## the sculpted surface with `bulge` of its radius showing.
func add_eye(near: Vector3, radius: float, bone: String, look: Vector3, bulge := 0.45) -> void:
	eyes.append({"near": near, "radius": radius, "bone": bone, "look": look.normalized(), "bulge": bulge})


## Iris colour, pupil half-size (x wide, y tall, as a fraction of the iris) and iris size
## (fraction of the visible cap) shared by all eyes of this animal.
func set_eye_look(iris: Color, pupil: Vector2, iris_size := 0.8) -> void:
	_eye_look = {"iris": iris, "pupil": pupil, "iris_size": iris_size}


# --- Build ---------------------------------------------------------------------------------

func build() -> Node3D:
	var t0 := Time.get_ticks_msec()
	var mesh_data := sculpt.polygonize(cell)
	var t1 := Time.get_ticks_msec()
	sculpt.refine(mesh_data, 2)
	var t2 := Time.get_ticks_msec()
	var verts: PackedVector3Array = mesh_data["verts"]
	var normals: PackedVector3Array = mesh_data["normals"]
	var tris: PackedInt32Array = mesh_data["tris"]
	var vattr: Array = []
	vattr.resize(verts.size())
	for i in verts.size():
		vattr[i] = sculpt.attributes(verts[i])
	for cb in card_builders:
		cb.call(self)
	var t3 := Time.get_ticks_msec()
	print("  sculpt: %d verts, %d tris (sample %d ms, refine %d ms, attributes %d ms)" % [
		verts.size(), tris.size() / 3, t1 - t0, t2 - t1, t3 - t2])

	# Split triangles into surfaces by the majority material of their vertices.
	var per_surface := {}
	for t in range(0, tris.size(), 3):
		var s0: int = vattr[tris[t]][2]
		var s1: int = vattr[tris[t + 1]][2]
		var s2: int = vattr[tris[t + 2]][2]
		var s := s0 if (s0 == s1 or s0 == s2) else s1
		if not per_surface.has(s):
			per_surface[s] = []
		(per_surface[s] as Array).append_array([tris[t], tris[t + 1], tris[t + 2]])

	var im := ImporterMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for s: int in per_surface:
		var arrays := _surface_arrays(PackedInt32Array(per_surface[s]), verts, normals, vattr)
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _material(s), "surf_%d" % s, flags)
	for s: int in [Surf.HAIR_CARD, Surf.FEATHER_CARD]:
		var arrays := _card_arrays(s)
		if not arrays.is_empty():
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _material(s), "surf_%d" % s, flags)
	if not eyes.is_empty():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, _eye_arrays(), [], {}, _eye_material(), "eyes", flags)
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()

	var root := Node3D.new()
	root.name = "Model"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	root.add_child(skel)
	skel.owner = root
	var skin := Skin.new()
	for i in bones.size():
		var b: Array = bones[i]
		skel.add_bone(b[0])
		var parent: int = b[1]
		skel.set_bone_parent(i, parent)
		var local: Vector3 = b[2] - (bones[parent][2] as Vector3 if parent >= 0 else Vector3.ZERO)
		skel.set_bone_rest(i, Transform3D(Basis(), local))
		skin.add_named_bind(b[0], Transform3D(Basis(), -(b[2] as Vector3)))
	skel.reset_bone_poses()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.skin = skin
	skel.add_child(mi)
	mi.owner = root
	mi.skeleton = NodePath("..")
	print("  built in %d ms" % (Time.get_ticks_msec() - t0))
	return root


func _surface_arrays(idx: PackedInt32Array, verts: PackedVector3Array, normals: PackedVector3Array, vattr: Array) -> Array:
	# Re-index only the vertices this surface uses.
	var remap := {}
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()
	var bone_arr := PackedInt32Array()
	var weight_arr := PackedFloat32Array()
	var out_idx := PackedInt32Array()
	for v in idx:
		if not remap.has(v):
			remap[v] = pos.size()
			var a: Array = vattr[v]
			var c: Color = a[0]
			var at: Vector4 = a[1]
			pos.append(verts[v])
			nrm.append(normals[v])
			col.append(c)
			uv.append(Vector2(at.x, at.y))
			uv2.append(Vector2(at.z, at.w))
			custom.append_array([verts[v].x, verts[v].y, verts[v].z, a[5]])
			bone_arr.append_array(a[3])
			weight_arr.append_array(a[4])
		out_idx.append(remap[v])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_BONES] = bone_arr
	arrays[Mesh.ARRAY_WEIGHTS] = weight_arr
	arrays[Mesh.ARRAY_INDEX] = out_idx
	return arrays


## Card strips: quads along each card's polyline, weighted to the nearest bones.
func _card_arrays(surface_id: int) -> Array:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var tan := PackedFloat32Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()
	var bone_arr := PackedInt32Array()
	var weight_arr := PackedFloat32Array()
	var idx := PackedInt32Array()
	for card: Dictionary in cards:
		if card["surface"] != surface_id:
			continue
		var pts: Array = card["points"]
		var n: Vector3 = (card["normal"] as Vector3).normalized()
		var r: Rect2 = card["uv"]
		var width: float = card["width"]
		var taper: float = card["taper"]
		var base_index := pos.size()
		var length := 0.0
		var lengths := [0.0]
		for i in range(1, pts.size()):
			length += (pts[i] as Vector3).distance_to(pts[i - 1])
			lengths.append(length)
		for i in pts.size():
			var p: Vector3 = pts[i]
			var dir: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
			var side := dir.cross(n).normalized()
			var t := float(lengths[i]) / maxf(length, 0.0001)
			var w := width * (1.0 - taper * t) * 0.5
			var v := r.position.y + r.size.y * t
			for s: float in [-1.0, 1.0]:
				var vp := p + side * w * s
				pos.append(vp)
				nrm.append(n)
				tan.append_array([side.x, side.y, side.z, 1.0])
				var cc: Color = card["color"]
				col.append(Color(cc.srgb_to_linear(), cc.a))
				uv.append(Vector2(r.position.x + r.size.x * (0.0 if s < 0.0 else 1.0), v))
				uv2.append(Vector2(0, 0))
				custom.append_array([vp.x, vp.y, vp.z, 0.0])
				var bw := _nearest_bones(vp)
				bone_arr.append_array(bw[0])
				weight_arr.append_array(bw[1])
		for i in pts.size() - 1:
			var a := base_index + i * 2
			# Clockwise from the +normal side (Godot front faces); cards render two-sided.
			idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	if pos.is_empty():
		return []
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TANGENT] = tan
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_BONES] = bone_arr
	arrays[Mesh.ARRAY_WEIGHTS] = weight_arr
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


## UV spheres for the eyes. UV is a planar projection along the look direction, so
## the eye texture's centre (pupil) faces where the animal looks.
func _eye_arrays() -> Array:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var tan := PackedFloat32Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom := PackedFloat32Array()
	var bone_arr := PackedInt32Array()
	var weight_arr := PackedFloat32Array()
	var idx := PackedInt32Array()
	const RINGS := 14
	const SEGMENTS := 20
	for eye: Dictionary in eyes:
		var look: Vector3 = eye["look"]
		var r: float = eye["radius"]
		# Sit the ball on the surface: find where the look ray leaves the head, then
		# sink the centre so `bulge` of the radius shows.
		var start: Vector3 = eye["near"] as Vector3 - look * maxf(r * 3.0, 0.03)
		var surface_point: Vector3
		if sculpt.eval(start) < 0.0:
			surface_point = sculpt.project_out(start, look, 0.0)
		else:
			surface_point = sculpt.raycast(eye["near"] as Vector3 + look * 0.3, -look, 0.6)
		var center := surface_point - look * r * (1.0 - 2.0 * float(eye["bulge"]))
		var up := Vector3.UP if absf(look.y) < 0.9 else Vector3.FORWARD
		var right := up.cross(look).normalized()
		up = look.cross(right).normalized()
		var bone := bone_index(eye["bone"])
		var base := pos.size()
		for i in RINGS + 1:
			# Ring 0 is the front pole (the pupil), the last ring the back pole.
			var theta := PI * float(i) / RINGS
			for j in SEGMENTS + 1:
				var phi := TAU * float(j) / SEGMENTS
				var n := look * cos(theta) + (right * cos(phi) + up * sin(phi)) * sin(theta)
				var p := center + n * r
				pos.append(p)
				nrm.append(n)
				var t := (-n.cross(look)).normalized() if sin(theta) > 0.001 else right
				tan.append_array([t.x, t.y, t.z, 1.0])
				col.append(Color.WHITE)
				# Planar projection of the front hemisphere; the back gets the sclera.
				var d := n.dot(look)
				var planar := Vector2(n.dot(right), -n.dot(up)) * 0.5 + Vector2(0.5, 0.5)
				uv.append(planar if d > 0.0 else Vector2(0.0, 0.0))
				uv2.append(Vector2.ZERO)
				custom.append_array([p.x, p.y, p.z, 0.0])
				bone_arr.append_array([bone, 0, 0, 0])
				weight_arr.append_array([1.0, 0.0, 0.0, 0.0])
		for i in RINGS:
			for j in SEGMENTS:
				var a := base + i * (SEGMENTS + 1) + j
				var b := a + SEGMENTS + 1
				# Clockwise seen from outside.
				idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TANGENT] = tan
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_BONES] = bone_arr
	arrays[Mesh.ARRAY_WEIGHTS] = weight_arr
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


## Glossy eyeball with a painted iris and pupil (horizontal slit for grazers, round
## for birds) and a darker limbal ring; the sclera barely shows, like in real grazers.
func _eye_material() -> Material:
	const SIZE := 128
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var iris: Color = _eye_look["iris"]
	var pupil: Vector2 = _eye_look["pupil"]
	var iris_r: float = _eye_look["iris_size"]
	var sclera := Color(0.16, 0.12, 0.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in SIZE:
		for x in SIZE:
			var p := (Vector2(x + 0.5, y + 0.5) / SIZE - Vector2(0.5, 0.5)) * 2.0
			var r := p.length()
			var c := sclera
			if r < iris_r:
				var t := r / iris_r
				# Radial fibres and a darker rim.
				var ang := atan2(p.y, p.x)
				var fibre := 0.85 + 0.15 * sin(ang * 37.0 + sin(ang * 11.0) * 2.0)
				c = iris.darkened(0.45 * smoothstep(0.7, 1.0, t)).lightened(0.12 * (1.0 - t)) * fibre
				c.a = 1.0
				var q := Vector2(p.x / (pupil.x * iris_r), p.y / (pupil.y * iris_r))
				var edge := smoothstep(0.85, 1.05, q.length())
				c = Color(0.01, 0.008, 0.008).lerp(c, edge)
			elif r < iris_r + 0.06:
				c = sclera.lerp(iris.darkened(0.6), 0.5)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.04
	m.metallic_specular = 0.7
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.02
	m.rim_enabled = false
	return m


## Weights of the two bones whose segments pass closest to p.
func _nearest_bones(p: Vector3) -> Array:
	var best := [[INF, 0], [INF, 0]]
	for i in bones.size():
		var a: Vector3 = bones[i][2]
		var b := a
		for j in bones.size():
			if bones[j][1] == i:
				b = bones[j][2]
				break
		var d := p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))
		if d < best[0][0]:
			best[1] = best[0]
			best[0] = [d, i]
		elif d < best[1][0]:
			best[1] = [d, i]
	var w0 := 1.0 / maxf(best[0][0], 0.005)
	var w1 := 1.0 / maxf(best[1][0], 0.005) * 0.5
	var total := w0 + w1
	return [PackedInt32Array([best[0][1], best[1][1], 0, 0]), PackedFloat32Array([w0 / total, w1 / total, 0, 0])]


# --- Materials ------------------------------------------------------------------------------

static func _material(s: int) -> Material:
	match s:
		Surf.EYE:
			var e := StandardMaterial3D.new()
			e.albedo_color = Color(0.035, 0.028, 0.024)
			e.roughness = 0.12
			e.metallic_specular = 0.55
			return e
		Surf.HAIR_CARD:
			var h := ShaderMaterial.new()
			h.shader = load("res://shaders/animal_hair.gdshader")
			h.set_shader_parameter("strands", load("res://art/textures/generated/hair_strands.png"))
			return h
		Surf.FEATHER_CARD:
			var f := ShaderMaterial.new()
			f.shader = load("res://shaders/animal_hair.gdshader")
			f.set_shader_parameter("strands", load("res://art/textures/generated/feather.png"))
			f.set_shader_parameter("use_coat_tint", true)
			f.set_shader_parameter("anisotropy", 0.2)
			return f
		_:
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/animal_coat.gdshader")
			m.set_shader_parameter("kind", SHADERS.get(s, 0))
			return m
