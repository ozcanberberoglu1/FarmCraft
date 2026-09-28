@tool
class_name Terrain
extends Node3D
## Builds the terrain mesh (in chunks for culling), its heightmap collision and an
## invisible wall along the edge of the playable area (farm valley, town valley and
## the road corridor between them).

## Chunk edge length in metres (the map is split into CHUNK x CHUNK tiles).
const CHUNK := 50
## Marching-squares cell size for the boundary wall.
const WALL_CELL := 2.0

@export var rebuild := false:
	set(value):
		if value and is_inside_tree():
			TerrainData.invalidate()
			build()


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	TerrainData.ensure()
	_build_meshes()
	_build_collision()
	_build_boundary()


func _build_meshes() -> void:
	var nx := TerrainData.NX
	var nz := TerrainData.NZ
	var h := TerrainData.heights
	var normals := PackedVector3Array()
	normals.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var hl := h[iz * nx + maxi(ix - 1, 0)]
			var hr := h[iz * nx + mini(ix + 1, nx - 1)]
			var hd := h[maxi(iz - 1, 0) * nx + ix]
			var hu := h[mini(iz + 1, nz - 1) * nx + ix]
			normals[iz * nx + ix] = Vector3(hl - hr, 2.0, hd - hu).normalized()

	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/terrain.gdshader")
	material.set_shader_parameter("water_level", WorldLayout.WATER_LEVEL)
	material.set_shader_parameter("mask_tex", TerrainData.mask_texture())
	material.set_shader_parameter("map_min", Vector2(TerrainData.MIN_X, TerrainData.MIN_Z))
	material.set_shader_parameter("map_size", Vector2(WorldLayout.MAP_W, WorldLayout.MAP_D))
	material.set_shader_parameter("town_center", WorldLayout.TOWN_CENTER)
	material.set_shader_parameter("town_scale", WorldLayout.VALLEY_RADIUS / WorldLayout.TOWN_VALLEY_RADIUS)
	for layer in [["grass", "leafy_grass"], ["hill", "aerial_grass_rock"], ["path", "rocky_trail"],
			["dirt", "rocky_trail_02"], ["sand", "coast_sand_01"], ["rock", "rock_face_03"]]:
		material.set_shader_parameter(layer[0] + "_diff", Mats.texture(layer[1], "diff.jpg"))
		material.set_shader_parameter(layer[0] + "_nor", Mats.texture(layer[1], "nor.jpg"))
	for z0 in range(0, nz - 1, CHUNK):
		for x0 in range(0, nx - 1, CHUNK):
			var w := mini(CHUNK, nx - 1 - x0)
			var d := mini(CHUNK, nz - 1 - z0)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [x0 / CHUNK, z0 / CHUNK]
			mi.mesh = _chunk_mesh(x0, z0, w, d, normals)
			mi.mesh.surface_set_material(0, material)
			add_child(mi)


func _chunk_mesh(x0: int, z0: int, w: int, d: int, normals: PackedVector3Array) -> ArrayMesh:
	var nx := TerrainData.NX
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for iz in range(z0, z0 + d + 1):
		for ix in range(x0, x0 + w + 1):
			var i := iz * nx + ix
			verts.append(Vector3(TerrainData.MIN_X + ix, TerrainData.heights[i], TerrainData.MIN_Z + iz))
			norms.append(normals[i])
	var row := w + 1
	for z in d:
		for x in w:
			var a := z * row + x
			var b := a + 1
			var c := a + row
			var e := c + 1
			# Clockwise as seen from above (Godot front faces).
			idx.append_array([a, b, e, a, e, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = TerrainData.NX
	shape.map_depth = TerrainData.NZ
	shape.map_data = TerrainData.heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	# The height map is centred on its node.
	cs.position = Vector3(TerrainData.MIN_X + (TerrainData.NX - 1) * 0.5, 0.0, TerrainData.MIN_Z + (TerrainData.NZ - 1) * 0.5)
	body.add_child(cs)
	add_child(body)


## Vertical wall faces along the zero contour of WorldLayout.playable_distance
## (marching squares on a WALL_CELL grid), as one concave collision shape.
func _build_boundary() -> void:
	var rect := WorldLayout.map_rect()
	var cols := int(rect.size.x / WALL_CELL)
	var rows := int(rect.size.y / WALL_CELL)
	var field := PackedFloat32Array()
	field.resize((cols + 1) * (rows + 1))
	for j in rows + 1:
		for i in cols + 1:
			field[j * (cols + 1) + i] = WorldLayout.playable_distance(rect.position.x + i * WALL_CELL, rect.position.y + j * WALL_CELL)
	var faces := PackedVector3Array()
	var corner := func(i: int, j: int) -> Vector2: return rect.position + Vector2(i, j) * WALL_CELL
	for j in rows:
		for i in cols:
			var v := [field[j * (cols + 1) + i], field[j * (cols + 1) + i + 1],
				field[(j + 1) * (cols + 1) + i + 1], field[(j + 1) * (cols + 1) + i]]
			var pts := [corner.call(i, j), corner.call(i + 1, j), corner.call(i + 1, j + 1), corner.call(i, j + 1)]
			var cross: Array[Vector2] = []
			for e in 4:
				var a: float = v[e]
				var b: float = v[(e + 1) % 4]
				if (a > 0.0) != (b > 0.0):
					var t := a / (a - b)
					cross.append((pts[e] as Vector2).lerp(pts[(e + 1) % 4], t))
			for k in range(0, cross.size() - 1, 2):
				_wall_quad(faces, cross[k], cross[k + 1])
	if faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _wall_quad(faces: PackedVector3Array, a: Vector2, b: Vector2) -> void:
	var lo := minf(TerrainData.height(a.x, a.y), TerrainData.height(b.x, b.y)) - 4.0
	var hi := maxf(TerrainData.height(a.x, a.y), TerrainData.height(b.x, b.y)) + 40.0
	var a0 := Vector3(a.x, lo, a.y)
	var b0 := Vector3(b.x, lo, b.y)
	var a1 := Vector3(a.x, hi, a.y)
	var b1 := Vector3(b.x, hi, b.y)
	faces.append_array([a0, b0, b1, a0, b1, a1])
