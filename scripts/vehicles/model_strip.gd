class_name ModelStrip
extends RefCounted
## Cuts loose parts out of downloaded models: every connected island of a mesh
## (vertices at the same spot count as joined) that lies wholly inside a box goes.
## The pickup model ships with a load baked into its bed trim (a crate frame, boxes
## and toolboxes), which the game draws itself.

## Stripped meshes, kept for the session: a mesh is read back from the GPU and walked
## vertex by vertex in GDScript only the first time.
static var _cache := {}


## Strips the meshes of `model` whose names contain `mesh_name`; `box` is in the
## model's own frame.
static func strip_parts(model: Node3D, mesh_name: String, box: AABB) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh_name in String(mi.name):
			mi.mesh = _stripped(mi.mesh, _to_model(mi, model), box)


static func _to_model(n: Node3D, model: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != model:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _stripped(src: Mesh, xf: Transform3D, box: AABB) -> Mesh:
	# By the mesh's path inside its scene: that stays the same when the scene is loaded
	# again (a new world, a vehicle bought later), its instance id does not.
	var id := src.resource_path if not src.resource_path.is_empty() else str(src.get_instance_id())
	var key := "%s|%s|%s" % [id, xf, box]
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			for i in verts.size():
				idx.append(i)
		# Union-find over vertices; vertices at the same spot belong together.
		var parent := PackedInt32Array()
		parent.resize(verts.size())
		for i in verts.size():
			parent[i] = i
		var at := {}
		for i in verts.size():
			var spot := verts[i].snapped(Vector3.ONE * 0.0005)
			if at.has(spot):
				_union(parent, i, at[spot])
			else:
				at[spot] = i
		for t in idx.size() / 3:
			_union(parent, idx[t * 3], idx[t * 3 + 1])
			_union(parent, idx[t * 3], idx[t * 3 + 2])
		var bounds := {}
		for i in verts.size():
			var root := _find(parent, i)
			var p := xf * verts[i]
			if bounds.has(root):
				var b: AABB = bounds[root]
				bounds[root] = b.expand(p)
			else:
				bounds[root] = AABB(p, Vector3.ZERO)
		var keep := PackedInt32Array()
		for t in idx.size() / 3:
			if not box.encloses(bounds[_find(parent, idx[t * 3])]):
				keep.append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		arr[Mesh.ARRAY_INDEX] = keep
		# Custom channels would need their format flags; a static model has no use for them.
		for ch in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			arr[ch] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
		out.surface_set_name(si, src.surface_get_name(si))
	_cache[key] = out
	return out


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb
