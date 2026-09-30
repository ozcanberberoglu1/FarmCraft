@tool
class_name FoodModels
extends RefCounted
## Models of the food the catch becomes (ItemModels asks here first):
##   "<fish>_cleaned"          the species' fish with its head cut off behind the gill
##                             cover, the cut face showing flesh, backbone and the emptied
##                             belly (art/textures/food/fish_flesh, tools/make_food_textures.py)
##   "<fish>_cleaned_cooked"   the same cut from the grilled fish, the face cooked white
##   "<fish>_trophy"           the species' item model, a size up (a giant in the hand)
##   "rabbit_meat(_cooked)"    a jointed hind leg of game: thigh, drumstick and the knuckle
##                             of bone at its end, raw red or roasted brown
## The fish are cut from FishModels' own meshes (lying along +X, head toward +X): every
## triangle is clipped against the cut plane and the opening closed with a cap whose
## texture is spread over the cut's outline. piece() gives the body and the head in the
## whole fish's item frame, for the food table's knife to part them in place.

const TEX := "res://art/textures/food/"
## Where the head comes off, as a share of the fish's length back from the nose: just
## behind the gill cover (the species' gill line over its body without the tail fin,
## tools/blender/make_fishing.py).
const HEAD_CUT := {
	&"fish_rudd": 0.19, &"fish_crucian": 0.2, &"fish_perch": 0.22, &"fish_carp": 0.19, &"fish_tench": 0.2,
	&"fish_trout": 0.2, &"fish_zander": 0.22, &"fish_pike": 0.24, &"fish_catfish": 0.19,
	# The lake's other fish (FishTable, the bait update).
	&"fish_roach": 0.19, &"fish_bleak": 0.19, &"fish_gudgeon": 0.21, &"fish_bream": 0.18, &"fish_chub": 0.22,
	&"fish_barbel": 0.2, &"fish_eel": 0.13, &"fish_grass_carp": 0.19, &"fish_silver_carp": 0.22,
	&"fish_brown_trout": 0.2, &"fish_sturgeon": 0.2,
}
## Trophies in the hand, as pickups and on the icon: this much larger than their species.
const TROPHY_ITEM_SCALE := 1.35
const MEATS: Array[StringName] = [&"rabbit_meat", &"rabbit_meat_cooked"]
const SUFFIX_CLEANED := "_cleaned"
const SUFFIX_CLEANED_COOKED := "_cleaned_cooked"

static var _cache := {}
static var _mats := {}


static func has(id: StringName) -> bool:
	if id in MEATS:
		return true
	if _trophy_species(id) != &"":
		return true
	return HEAD_CUT.has(species_of_cleaned(id))


## The species of a trophy item ("fish_carp_trophy" -> fish_carp; &"" for anything else).
## Kept apart from FishTable, which needs the game's autoloads (tools draw these too).
static func _trophy_species(id: StringName) -> StringName:
	var s := String(id)
	if not s.ends_with("_trophy"):
		return &""
	var species := StringName(s.trim_suffix("_trophy"))
	return species if FishModels.has(species) else &""


## The species of a cleaned fish item (&"" for anything else).
static func species_of_cleaned(id: StringName) -> StringName:
	var s := String(id)
	if s.ends_with(SUFFIX_CLEANED_COOKED):
		return StringName(s.trim_suffix(SUFFIX_CLEANED_COOKED))
	if s.ends_with(SUFFIX_CLEANED):
		return StringName(s.trim_suffix(SUFFIX_CLEANED))
	return &""


## The cleaned item of species `id` (&"" when it has none).
static func cleaned_id(id: StringName) -> StringName:
	return StringName(String(id) + SUFFIX_CLEANED) if HEAD_CUT.has(id) else &""


## The item's model (held, dropped, icons, on the fire): centred like FishModels.mesh.
static func mesh(id: StringName) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	var m: ArrayMesh
	if id in MEATS:
		m = _meat(id.ends_with("_cooked"))
	elif _trophy_species(id) != &"":
		var base := FishModels.mesh(_trophy_species(id))
		var surfaces := []
		MeshMerge.add_mesh(surfaces, base, Transform3D(Basis.from_scale(Vector3.ONE * TROPHY_ITEM_SCALE), Vector3.ZERO))
		m = MeshMerge.build(surfaces, 40000)
	else:
		var species := species_of_cleaned(id)
		var body := piece(species, "body", String(id).ends_with(SUFFIX_CLEANED_COOKED))
		# Centred on what is left of the fish, turned end for end so the cut face is the
		# one an icon or a held fish shows.
		var surfaces := []
		MeshMerge.add_mesh(surfaces, body, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(Basis(), -body.get_aabb().get_center()))
		m = MeshMerge.build(surfaces, 40000)
	_cache[id] = m
	return m


## The body ("body") or the head ("head") of `species` cut apart, in the frame of the
## whole fish's item model (FishModels.mesh), raw or grilled.
static func piece(species: StringName, part: String, cooked := false) -> ArrayMesh:
	var key := "%s/%s/%s" % [species, part, cooked]
	if _cache.has(key):
		return _cache[key]
	var whole := FishModels.mesh(StringName(String(species) + ("_cooked" if cooked else "")))
	var m := ArrayMesh.new()
	if whole.get_surface_count() > 0:
		var box := whole.get_aabb()
		var cut := box.end.x - box.size.x * float(HEAD_CUT.get(species, 0.2))
		m = clip(whole, cut, part == "body", flesh_material(cooked))
	_cache[key] = m
	return m


# --- Cutting --------------------------------------------------------------------------

## The part of `src` on one side of the plane x = `cut` (x below it when `keep_below`),
## every triangle across the plane clipped exactly, the opening closed with a cap of
## `cap_mat` facing out of the cut (+X for the part below). The cap follows the outline
## of the surface with the most triangles cut (the skin; fins and eyes are only
## trimmed), its UVs spread over the outline's bounding box.
static func clip(src: Mesh, cut: float, keep_below: bool, cap_mat: Material) -> ArrayMesh:
	var surfaces := []
	var outline := PackedVector3Array()
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var res := _clip_surface(arr, cut, keep_below)
		var out: Array = res[0]
		if (out[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		surfaces.append([out, src.surface_get_material(si), src.surface_get_name(si)])
		var pts: PackedVector3Array = res[1]
		if pts.size() > outline.size():
			outline = pts
	if outline.size() >= 6:
		var mb := MeshBuilder.new()
		_cap(mb, outline, cut, Vector3.RIGHT if keep_below else Vector3.LEFT)
		MeshMerge.add_mesh(surfaces, mb.build({&"flesh": cap_mat}))
	return MeshMerge.build(surfaces, 40000)


## [clipped arrays (no index), the points where its triangles cross the plane].
static func _clip_surface(arr: Array, cut: float, keep_below: bool) -> Array:
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var tangents: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT] if arr[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var colors: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var uv2s: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	var index: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if index.is_empty():
		index.resize(verts.size())
		for i in verts.size():
			index[i] = i
	var crossings := PackedVector3Array()
	var sgn := 1.0 if keep_below else -1.0
	# What is kept, as clipped vertices: a, b, t = the point t of the way from a to b.
	var ops: Array = []
	for f in range(0, index.size() - 2, 3):
		var tri := [index[f], index[f + 1], index[f + 2]]
		var d: Array[float] = []
		var inside := 0
		for i: int in tri:
			var di := (cut - verts[i].x) * sgn
			d.append(di)
			if di >= 0.0:
				inside += 1
		if inside == 0:
			continue
		if inside == 3:
			for i: int in tri:
				ops.append_array([i, i, 0.0])
			continue
		# Sutherland-Hodgman against the plane: the polygon of what is kept (3 or 4 corners).
		var poly: Array = []
		for k in 3:
			var a: int = tri[k]
			var b: int = tri[(k + 1) % 3]
			var da := d[k]
			var db := d[(k + 1) % 3]
			if da >= 0.0:
				poly.append([a, a, 0.0])
			if (da >= 0.0) != (db >= 0.0):
				var t := da / (da - db)
				poly.append([a, b, t])
				crossings.append(verts[a].lerp(verts[b], t))
		for k in range(1, poly.size() - 1):
			for c: Array in [poly[0], poly[k], poly[k + 1]]:
				ops.append_array(c)
	var n := ops.size() / 3
	var o_v := PackedVector3Array()
	var o_n := PackedVector3Array()
	var o_t := PackedFloat32Array()
	var o_c := PackedColorArray()
	var o_uv := PackedVector2Array()
	var o_uv2 := PackedVector2Array()
	var has_n := normals.size() == verts.size()
	var has_t := tangents.size() == verts.size() * 4
	var has_c := colors.size() == verts.size()
	var has_uv := uvs.size() == verts.size()
	var has_uv2 := uv2s.size() == verts.size()
	o_v.resize(n)
	if has_n:
		o_n.resize(n)
	if has_t:
		o_t.resize(n * 4)
	if has_c:
		o_c.resize(n)
	if has_uv:
		o_uv.resize(n)
	if has_uv2:
		o_uv2.resize(n)
	for i in n:
		var va: int = ops[i * 3]
		var vb: int = ops[i * 3 + 1]
		var t: float = ops[i * 3 + 2]
		o_v[i] = verts[va].lerp(verts[vb], t)
		if has_n:
			o_n[i] = normals[va].lerp(normals[vb], t).normalized()
		if has_t:
			for k in 4:
				o_t[i * 4 + k] = lerpf(tangents[va * 4 + k], tangents[vb * 4 + k], t)
		if has_c:
			o_c[i] = colors[va].lerp(colors[vb], t)
		if has_uv:
			o_uv[i] = uvs[va].lerp(uvs[vb], t)
		if has_uv2:
			o_uv2[i] = uv2s[va].lerp(uv2s[vb], t)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = o_v
	if has_n:
		out[Mesh.ARRAY_NORMAL] = o_n
	if has_t:
		out[Mesh.ARRAY_TANGENT] = o_t
	if has_c:
		out[Mesh.ARRAY_COLOR] = o_c
	if has_uv:
		out[Mesh.ARRAY_TEX_UV] = o_uv
	if has_uv2:
		out[Mesh.ARRAY_TEX_UV2] = o_uv2
	return [out, crossings]


## A fan over the cut's outline (points on the plane x = cut), facing `facing`. UVs: u
## across the fish (its Z), v down it (its Y), over the outline's bounding box.
static func _cap(mb: MeshBuilder, pts: PackedVector3Array, cut: float, facing: Vector3) -> void:
	var c := Vector2.ZERO
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var q := Vector2(p.z, p.y)
		c += q
		lo = lo.min(q)
		hi = hi.max(q)
	c /= float(pts.size())
	# Round the outline: points sorted by angle about the centre, near-duplicates dropped.
	var ring: Array = []
	for p in pts:
		var q := Vector2(p.z, p.y)
		ring.append([atan2(q.y - c.y, q.x - c.x), q])
	ring.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var outline: Array[Vector2] = []
	var min_step := (hi - lo).length() * 0.004
	for e: Array in ring:
		var q: Vector2 = e[1]
		if outline.is_empty() or q.distance_to(outline[-1]) > min_step:
			outline.append(q)
	if outline.size() > 2 and outline[0].distance_to(outline[-1]) <= min_step:
		outline.pop_back()
	var span := (hi - lo).max(Vector2(0.0001, 0.0001))
	var uv := func(q: Vector2) -> Vector2:
		return Vector2((q.x - lo.x) / span.x, (hi.y - q.y) / span.y)
	var center := Vector3(cut, c.y, c.x)
	for k in outline.size():
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		var pa := Vector3(cut, a.y, a.x)
		var pb := Vector3(cut, b.y, b.x)
		# Counter-clockwise from the side it faces (MeshBuilder's winding).
		if (pa - center).cross(pb - center).dot(facing) < 0.0:
			mb.tri(&"flesh", center, pb, pa, Color.WHITE, uv.call(c), uv.call(b), uv.call(a))
		else:
			mb.tri(&"flesh", center, pa, pb, Color.WHITE, uv.call(c), uv.call(a), uv.call(b))


# --- Materials ------------------------------------------------------------------------

## The cut face of a fish: wet, pink-white flesh (raw) or white flakes (cooked).
static func flesh_material(cooked: bool) -> Material:
	var key := "fish_flesh_cooked" if cooked else "fish_flesh"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_texture = load(TEX + key + "_albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load(TEX + key + "_nor.png")
	m.normal_scale = 0.7
	m.roughness = 0.62 if cooked else 0.42
	m.metallic_specular = 0.45 if cooked else 0.55
	if not cooked:
		m.clearcoat_enabled = true
		m.clearcoat = 0.2
		m.clearcoat_roughness = 0.3
	_mats[key] = m
	return m


## Game meat, raw or roasted; UVs of MeshBuilder lofts: u round, v along in metres.
static func meat_material(cooked: bool) -> Material:
	var key := "meat_cooked" if cooked else "meat"
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_texture = load(TEX + key + "_albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load(TEX + key + "_nor.png")
	m.normal_scale = 0.9
	m.uv1_scale = Vector3(1.0, 6.0, 1.0)
	m.roughness = 0.58 if cooked else 0.34
	m.metallic_specular = 0.5
	if not cooked:
		m.clearcoat_enabled = true
		m.clearcoat = 0.3
		m.clearcoat_roughness = 0.3
	else:
		m.clearcoat_enabled = true
		m.clearcoat = 0.18
		m.clearcoat_roughness = 0.45
	_mats[key] = m
	return m


# --- Meat -----------------------------------------------------------------------------

## A jointed hind leg of game along +X: the round thigh, the drumstick narrowing to the
## knuckle, a stub of bone showing; roasted it shrinks a little and darkens.
static func _meat(cooked: bool) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var centers: Array[Vector3] = []
	var radii: Array[Vector2] = []
	var shrink := 0.94 if cooked else 1.0
	# (x, width, height, rise): the thigh swells, the drumstick tapers to the joint.
	var profile := [[-0.085, 0.004, 0.004, 0.0], [-0.08, 0.018, 0.016, 0.0], [-0.07, 0.03, 0.026, 0.002],
		[-0.052, 0.038, 0.032, 0.004], [-0.03, 0.04, 0.034, 0.005], [-0.008, 0.035, 0.03, 0.004],
		[0.012, 0.026, 0.022, 0.002], [0.032, 0.019, 0.017, 0.0], [0.05, 0.015, 0.014, -0.002],
		[0.066, 0.012, 0.012, -0.003], [0.074, 0.011, 0.011, -0.003], [0.078, 0.004, 0.004, -0.003]]
	for e: Array in profile:
		centers.append(Vector3(float(e[0]), float(e[3]), 0.0) * shrink)
		radii.append(Vector2(float(e[1]), float(e[2])) * shrink)
	mb.loft_ellipse(&"meat", centers, radii, 18, Color.WHITE)
	# The bone's knuckle out of the narrow end.
	var bone := Color(0.9, 0.86, 0.78) if not cooked else Color(0.72, 0.62, 0.5)
	var tip := Vector3(0.078, -0.003, 0.0) * shrink
	mb.cylinder_between(&"veg", tip - Vector3(0.006, 0, 0), tip + Vector3(0.016, 0.001, 0), 0.0055, 0.005, 10, bone)
	mb.sphere(&"veg", Transform3D(Basis(), tip + Vector3(0.019, 0.001, 0)), Vector3(0.008, 0.0075, 0.0085), 10, 6, bone)
	mb.sphere(&"veg", Transform3D(Basis(), tip + Vector3(0.018, -0.001, 0.004)), Vector3(0.006, 0.0055, 0.006), 8, 5, bone)
	return mb.build({&"meat": meat_material(cooked)})
