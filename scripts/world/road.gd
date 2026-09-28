@tool
class_name Road
extends Node3D
## The asphalt county road from the farm gate to the town: a ribbon mesh along the
## terrain's road profile (TerrainData.road_points / road_heights) with skirts that
## tuck into the ground, plus exact collision for wheels and feet.

## How far the skirts reach out and down to hide the road bed.
const SKIRT_OUT := 0.45
const SKIRT_DOWN := 0.3


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	TerrainData.ensure()
	var pts := TerrainData.road_points
	var hs := TerrainData.road_heights
	var n := pts.size()
	if n < 2:
		return
	var half := WorldLayout.ROAD_WIDTH * 0.5
	# Across-road profile: [offset from centre, height offset, u].
	var profile := [[-half - SKIRT_OUT, -SKIRT_DOWN, -SKIRT_OUT], [-half, 0.0, 0.0], [0.0, 0.035, half],
			[half, 0.0, half * 2.0], [half + SKIRT_OUT, -SKIRT_DOWN, half * 2.0 + SKIRT_OUT]]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var along := 0.0
	for i in n:
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, n - 1)]
		var dir := (next - prev).normalized()
		var side := Vector2(-dir.y, dir.x)
		if i > 0:
			along += pts[i].distance_to(pts[i - 1])
		for p: Array in profile:
			var xz: Vector2 = pts[i] + side * float(p[0])
			verts.append(Vector3(xz.x, hs[i] + float(p[1]), xz.y))
			uvs.append(Vector2(float(p[2]), along))
	var cols := profile.size()
	for i in n - 1:
		for c in cols - 1:
			var a := i * cols + c
			var b := a + 1
			var d := a + cols
			var e := d + 1
			idx.append_array([a, d, e, a, e, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/road.gdshader")
	mat.set_shader_parameter("albedo_tex", Mats.texture("asphalt_02", "diff.jpg"))
	mat.set_shader_parameter("normal_tex", Mats.texture("asphalt_02", "nor.jpg"))
	mat.set_shader_parameter("arm_tex", Mats.texture("asphalt_02", "arm.jpg"))
	mat.set_shader_parameter("road_width", WorldLayout.ROAD_WIDTH)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Asphalt"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Collision: the drivable surface only (without the skirts).
	var faces := PackedVector3Array()
	for i in n - 1:
		for c in range(1, cols - 2):
			var a := verts[i * cols + c]
			var b := verts[i * cols + c + 1]
			var d := verts[(i + 1) * cols + c]
			var e := verts[(i + 1) * cols + c + 1]
			faces.append_array([a, d, e, a, e, b])
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
