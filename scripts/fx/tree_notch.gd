class_name TreeNotch
extends MeshInstance3D
## The notch an axe cuts in a standing trunk, deeper with every blow until the tree goes
## over: a flat floor and a sloping roof of fresh, torn wood with a facet left by each
## blow (shaders/tree_notch.gdshader draws them over the bark wherever the bark is cut
## away, so the trunk mesh stays as it is). It rides the tree's swaying pivot, so it
## shudders and falls with the trunk. Origin on the trunk's axis at the notch floor, +X
## out through the notch.

## Share of the trunk's radius cut away by the blow that fells the tree.
const MAX_DEPTH := 0.62
## Height of the mouth per metre of depth (a roof sloping at about 50 degrees).
const MOUTH_SLOPE := 1.15
## How far past the mean bark radius the faces reach (rough bark stands out of it).
const REACH := 1.4
const SEGMENTS := 16

static var _mats: Dictionary = {}
## Trunk centre and radius per mesh and height (see trunk_at).
static var _trunks: Dictionary = {}

## Mean bark radius at the notch (m).
var radius := 0.3
## How deep the notch is cut from the bark (m).
var depth := 0.0
var blows := 0


func setup(trunk_radius: float, pine: bool) -> void:
	radius = trunk_radius
	material_override = _material(pine)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Small clutter: kept out of the rain height map.
	layers = 2
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_instance_shader_parameter("notch_seed", randf() * 100.0)


func _process(_delta: float) -> void:
	# Once the falling trunk leans over, the notch's reach would sweep through the stump
	# and the ground: the cut is hidden from there on (the trunk is moving fast by then).
	visible = global_basis.y.normalized().dot(Vector3.UP) > 0.93


## Cuts the notch to `share` (0..1) of its full depth, with one more blow's facet.
func cut_to(share: float) -> void:
	blows += 1
	depth = maxf(depth, radius * MAX_DEPTH * clampf(share, 0.0, 1.0))
	var mouth := depth * MOUTH_SLOPE
	set_instance_shader_parameter("notch_r", radius)
	set_instance_shader_parameter("notch_depth", depth)
	set_instance_shader_parameter("notch_mouth", mouth)
	set_instance_shader_parameter("notch_blows", float(blows))
	set_instance_shader_parameter("notch_reach", radius * REACH)
	mesh = _build(radius, depth, mouth)


## A point in the notch's mouth, in the world: where the chips fly out.
func mouth_point() -> Vector3:
	var x0 := radius - depth
	var half := sqrt(maxf(radius * radius - x0 * x0, 0.0)) * 0.5
	return to_global(Vector3(radius + 0.03, depth * MOUTH_SLOPE * randf_range(0.3, 0.7), randf_range(-half, half)))


## The floor and roof of the notch, reaching from the crease out past the bark.
static func _build(r: float, d: float, mouth: float) -> ArrayMesh:
	var x0 := r - d
	var reach := r * REACH
	var c := sqrt(maxf(reach * reach - x0 * x0, 0.0))
	var k := mouth / maxf(d, 0.001)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roof_n := Vector3(k, -1.0, 0.0).normalized()
	for i in SEGMENTS:
		var z0 := lerpf(-c, c, float(i) / SEGMENTS)
		var z1 := lerpf(-c, c, float(i + 1) / SEGMENTS)
		var o0 := sqrt(maxf(reach * reach - z0 * z0, x0 * x0))
		var o1 := sqrt(maxf(reach * reach - z1 * z1, x0 * x0))
		# Floor, facing up.
		_quad(st, Vector3(x0, 0, z0), Vector3(o0, 0, z0), Vector3(o1, 0, z1), Vector3(x0, 0, z1), Vector3.UP)
		# Roof, facing down and out into the notch.
		_quad(st, Vector3(x0, 0, z0), Vector3(o0, k * (o0 - x0), z0), Vector3(o1, k * (o1 - x0), z1),
				Vector3(x0, 0, z1), roof_n)
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	for tri: Array in [[a, b, c], [a, c, d]]:
		var p: Vector3 = tri[0]
		var q: Vector3 = tri[1]
		var r: Vector3 = tri[2]
		# Godot's front faces wind clockwise seen from the front.
		if (q - p).cross(r - p).dot(n) > 0.0:
			st.add_vertex(p)
			st.add_vertex(r)
			st.add_vertex(q)
		else:
			st.add_vertex(p)
			st.add_vertex(q)
			st.add_vertex(r)


static func _material(pine: bool) -> ShaderMaterial:
	if _mats.has(pine):
		return _mats[pine]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/tree_notch.gdshader")
	if pine:
		m.set_shader_parameter("sapwood", Color(0.8, 0.68, 0.6))
		m.set_shader_parameter("heartwood", Color(0.7, 0.5, 0.4))
		m.set_shader_parameter("bark_color", Color(0.4, 0.3, 0.24))
	else:
		m.set_shader_parameter("sapwood", Color(0.76, 0.64, 0.58))
		m.set_shader_parameter("heartwood", Color(0.58, 0.44, 0.36))
		m.set_shader_parameter("bark_color", Color(0.42, 0.36, 0.3))
	_mats[pine] = m
	return m


## The trunk's centre (x, z) and mean bark radius (y) at height `y` of a tree mesh, in
## the mesh's own units: from the vertices around that height whose normals point out
## from the axis (the trunk's surface, not the branches). (0, fallback, 0) when there
## are too few.
static func trunk_at(tree_mesh: Mesh, y: float, fallback: float) -> Vector3:
	var key := "%d|%d" % [tree_mesh.get_rid().get_id(), roundi(y * 10.0)]
	if _trunks.has(key):
		return _trunks[key]
	var pts := PackedVector2Array()
	for s in tree_mesh.get_surface_count():
		# Leaves and needles are most of a tree's vertices and none of its trunk.
		var mat := tree_mesh.surface_get_material(s) as ShaderMaterial
		if mat and mat.shader and mat.shader.resource_path.contains("foliage"):
			continue
		var arrays := tree_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.size() != verts.size():
			continue
		for i in verts.size():
			var v := verts[i]
			if absf(v.y - y) > 0.35:
				continue
			var flat := Vector2(v.x, v.z)
			var dist := flat.length()
			if dist > 0.8 or dist < 0.05:
				continue
			var n := normals[i]
			if absf(n.y) > 0.5 or Vector2(n.x, n.z).normalized().dot(flat / dist) < 0.8:
				continue
			pts.append(flat)
	var out := Vector3(0.0, fallback, 0.0)
	if pts.size() >= 6:
		var centre := Vector2.ZERO
		for p in pts:
			centre += p
		centre /= pts.size()
		var r := 0.0
		for p in pts:
			r += p.distance_to(centre)
		out = Vector3(centre.x, r / pts.size(), centre.y)
	_trunks[key] = out
	return out


## Draws a notch for a moment so its shader is ready before the first axe blow.
static func warm_up(parent: Node, at: Vector3) -> void:
	var n := TreeNotch.new()
	parent.add_child(n)
	n.global_position = at
	n.setup(0.3, false)
	n.cut_to(0.5)
	n.get_tree().create_timer(0.5).timeout.connect(n.queue_free)
