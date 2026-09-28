@tool
class_name MeshMerge
extends RefCounted
## Joins meshes into one: surfaces of downloaded scenes (keeping their materials) and
## of MeshBuilder meshes, each under its own transform. Heavy results get automatic
## LODs. Used for the scanned tools and the placeable machines.

## [transform relative to the scene root, mesh, surface materials, node name] for every
## mesh in a scene.
static func scene_parts(scene: PackedScene) -> Array:
	var root := scene.instantiate() as Node3D
	var out := []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var mats := []
		for si in mi.mesh.get_surface_count():
			mats.append(mi.get_active_material(si))
		out.append([xf, mi.mesh, mats, String(mi.name)])
	root.free()
	return out


## All vertex positions of `parts` (for sizing and orienting).
static func points(parts: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for part: Array in parts:
		var xf: Transform3D = part[0]
		var m: Mesh = part[1]
		for si in m.get_surface_count():
			for v: Vector3 in m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	return out


## Bounding box of `parts` under `frame`.
static func bounds(parts: Array, frame := Transform3D.IDENTITY) -> AABB:
	var pts := points(parts)
	var box := AABB(frame * pts[0], Vector3.ZERO) if not pts.is_empty() else AABB()
	for p in pts:
		box = box.expand(frame * p)
	return box


## Surfaces ([arrays, material, name]) of `parts` under `frame`, appended to `out`.
static func add_parts(out: Array, parts: Array, frame := Transform3D.IDENTITY) -> void:
	for part: Array in parts:
		var mats: Array = part[2]
		var m: Mesh = part[1]
		for si in m.get_surface_count():
			out.append([_moved(m.surface_get_arrays(si), frame * (part[0] as Transform3D)), mats[si], m.surface_get_name(si)])


## Surfaces of a built mesh (e.g. from MeshBuilder) under `xf`, appended to `out`.
static func add_mesh(out: Array, mesh: Mesh, xf := Transform3D.IDENTITY) -> void:
	if mesh == null:
		return
	for si in mesh.get_surface_count():
		out.append([_moved(mesh.surface_get_arrays(si), xf), mesh.surface_get_material(si), mesh.surface_get_name(si)])


static func _moved(arr: Array, xf: Transform3D) -> Array:
	var rot := xf.basis.orthonormalized()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = xf * verts[i]
	arr[Mesh.ARRAY_VERTEX] = verts
	if arr[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in normals.size():
			normals[i] = (rot * normals[i]).normalized()
		arr[Mesh.ARRAY_NORMAL] = normals
	if arr[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		for i in range(0, tangents.size(), 4):
			var t := (rot * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])).normalized()
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		arr[Mesh.ARRAY_TANGENT] = tangents
	# Custom channels and skinning would need their format flags; not used here.
	for ch in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		arr[ch] = null
	return arr


## Surfaces that share a material joined into one (fewer draw calls). Channels some
## of the joined surfaces lack are filled with neutral values.
static func by_material(surfaces: Array) -> Array:
	var groups := {}
	var order := []
	for s: Array in surfaces:
		var key = s[1] if s[1] != null else "__none"
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(s)
	var out := []
	for key in order:
		var group: Array = groups[key]
		if group.size() == 1:
			out.append(group[0])
			continue
		var has := {}
		for ch in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
			has[ch] = group.any(func(s: Array) -> bool: return (s[0] as Array)[ch] != null)
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var tangents := PackedFloat32Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var uv2s := PackedVector2Array()
		var indices := PackedInt32Array()
		for s: Array in group:
			var arr: Array = s[0]
			var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var base := verts.size()
			var n := sv.size()
			verts.append_array(sv)
			if has[Mesh.ARRAY_NORMAL]:
				normals.append_array(arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else _filled(PackedVector3Array(), n, Vector3.UP))
			if has[Mesh.ARRAY_TANGENT]:
				var t: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT] if arr[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
				if t.is_empty():
					for i in n:
						t.append_array([1.0, 0.0, 0.0, 1.0])
				tangents.append_array(t)
			if has[Mesh.ARRAY_COLOR]:
				colors.append_array(arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else _filled(PackedColorArray(), n, Color.WHITE))
			if has[Mesh.ARRAY_TEX_UV]:
				uvs.append_array(arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else _filled(PackedVector2Array(), n, Vector2.ZERO))
			if has[Mesh.ARRAY_TEX_UV2]:
				uv2s.append_array(arr[Mesh.ARRAY_TEX_UV2] if arr[Mesh.ARRAY_TEX_UV2] != null else _filled(PackedVector2Array(), n, Vector2.ZERO))
			if arr[Mesh.ARRAY_INDEX] != null:
				for i: int in arr[Mesh.ARRAY_INDEX]:
					indices.append(base + i)
			else:
				for i in n:
					indices.append(base + i)
		var joined := []
		joined.resize(Mesh.ARRAY_MAX)
		joined[Mesh.ARRAY_VERTEX] = verts
		joined[Mesh.ARRAY_INDEX] = indices
		if has[Mesh.ARRAY_NORMAL]:
			joined[Mesh.ARRAY_NORMAL] = normals
		if has[Mesh.ARRAY_TANGENT]:
			joined[Mesh.ARRAY_TANGENT] = tangents
		if has[Mesh.ARRAY_COLOR]:
			joined[Mesh.ARRAY_COLOR] = colors
		if has[Mesh.ARRAY_TEX_UV]:
			joined[Mesh.ARRAY_TEX_UV] = uvs
		if has[Mesh.ARRAY_TEX_UV2]:
			joined[Mesh.ARRAY_TEX_UV2] = uv2s
		out.append([joined, group[0][1], group[0][2]])
	return out


static func _filled(arr, n: int, value):
	arr.resize(n)
	arr.fill(value)
	return arr


## One ArrayMesh from surfaces; LODs when above `lod_triangles`.
static func build(surfaces: Array, lod_triangles := 20000) -> ArrayMesh:
	var triangles := 0
	for s: Array in surfaces:
		var arr: Array = s[0]
		if arr[Mesh.ARRAY_INDEX] != null:
			triangles += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		else:
			triangles += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	if triangles > lod_triangles:
		var im := ImporterMesh.new()
		for s: Array in surfaces:
			var arr: Array = s[0]
			if arr[Mesh.ARRAY_INDEX] == null:
				var idx := PackedInt32Array()
				for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
					idx.append(i)
				arr[Mesh.ARRAY_INDEX] = idx
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, s[1], s[2])
		im.generate_lods(25.0, 60.0, [])
		return im.get_mesh()
	var out := ArrayMesh.new()
	for s: Array in surfaces:
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s[0])
		var idx := out.get_surface_count() - 1
		out.surface_set_material(idx, s[1])
		out.surface_set_name(idx, s[2])
	return out
