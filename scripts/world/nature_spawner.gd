@tool
class_name NatureSpawner
extends Node3D
## Places trees, bushes, rocks and tall grass. Trees, rocks and grass patches inside
## the valley are harvestable resources with stable ids (for regrowth and saving);
## the forest on the surrounding hills is drawn with MultiMeshes.

@export var rebuild := false:
	set(value):
		if value and is_inside_tree():
			build()

## Hand-placed trees around the farm: [x, z, kind (0 pine, 1 oak), variant]
const FARM_TREES := [
	[-29.0, -29.0, 1, 1], [-35.5, -15.0, 0, 2], [-13.0, -29.0, 1, 2], [13.0, -30.0, 0, 1],
	[-26.0, 4.0, 1, 3], [31.0, -6.0, 1, 1], [-20.0, 10.0, 0, 3], [36.0, -28.0, 1, 2],
	[4.0, 34.0, 1, 3], [40.0, 34.0, 0, 1], [-10.0, 28.0, 0, 2], [-36.0, -20.0, 0, 1],
	[30.0, -32.0, 0, 3], [66.0, -16.0, 1, 1], [66.0, 14.0, 0, 2],
]

## Meadows where tall grass grows.
const GRASS_AREAS := [Rect2(-62, 24, 48, 22), Rect2(44, 26, 30, 18), Rect2(-72, -34, 26, 22),
	Rect2(64, -26, 18, 44), Rect2(-24, 36, 30, 14)]

var _placed: Array[Vector2] = []
var _tree_count := 0
var _rock_count := 0


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	_placed.clear()
	# Farm spots that must stay clear of trees, rocks and tall grass.
	_placed.append(WorldLayout.MANURE_HEAP)
	_tree_count = 0
	_rock_count = 0
	TerrainData.ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	var trees := Node3D.new()
	trees.name = "Trees"
	add_child(trees)
	for t in FARM_TREES:
		_spawn_tree(trees, Vector2(t[0], t[1]), int(t[2]), int(t[3]), rng)

	# Western forest, north-western grove and scattered meadow trees.
	_scatter_trees(trees, Rect2(-90, -70, 34, 120), 5.5, 0.75, rng)
	_scatter_trees(trees, Rect2(-58, -84, 44, 36), 6.0, 0.6, rng)
	_scatter_trees(trees, Rect2(-90, -90, 180, 180), 9.0, 0.05, rng)

	var rocks := Node3D.new()
	rocks.name = "Rocks"
	add_child(rocks)
	_scatter_rocks(rocks, WorldLayout.QUARRY_RECT, 22, 1.0, 1.7, rng, true)
	_scatter_rocks(rocks, Rect2(-88, -88, 176, 176), 30, 0.5, 1.1, rng, false)

	var patches := Node3D.new()
	patches.name = "GrassPatches"
	add_child(patches)
	_scatter_grass_patches(patches, rng)

	_scatter_bushes(rng)
	_build_hill_forest(rng)


func _free_spot(p: Vector2, min_dist: float) -> bool:
	for q in _placed:
		if p.distance_squared_to(q) < min_dist * min_dist:
			return false
	return true


func _valid_ground(x: float, z: float, margin: float) -> bool:
	if Vector2(x, z).length() > WorldLayout.VALLEY_RADIUS - 2.0:
		return false
	if WorldLayout.is_cleared(x, z, margin):
		return false
	if TerrainData.path_at(x, z) > 0.05 or TerrainData.dirt_at(x, z) > 0.2:
		return false
	if TerrainData.height(x, z) < WorldLayout.WATER_LEVEL + 0.4:
		return false
	# Keep the working farm area open.
	if Rect2(-30, -32, 98, 68).has_point(Vector2(x, z)):
		return false
	return TerrainData.normal_at(x, z).y > 0.85


func _scatter_trees(parent: Node3D, area: Rect2, spacing: float, chance: float, rng: RandomNumberGenerator) -> void:
	var cells_x := int(area.size.x / spacing)
	var cells_z := int(area.size.y / spacing)
	for iz in cells_z:
		for ix in cells_x:
			if rng.randf() > chance:
				continue
			var p := area.position + Vector2((ix + rng.randf()) * spacing, (iz + rng.randf()) * spacing)
			if not _valid_ground(p.x, p.y, 2.5) or not _free_spot(p, spacing * 0.7):
				continue
			var kind := 0 if rng.randf() < 0.55 else 1
			_spawn_tree(parent, p, kind, rng.randi_range(1, 3), rng)


func _spawn_tree(parent: Node3D, p: Vector2, kind: int, variant: int, rng: RandomNumberGenerator) -> void:
	_placed.append(p)
	var tree := ChoppableTree.new()
	tree.name = "Tree%d" % _tree_count
	tree.resource_id = "tree_%d" % _tree_count
	_tree_count += 1
	tree.kind = kind
	tree.variant = variant
	tree.tree_scale = rng.randf_range(0.85, 1.2)
	tree.position = TerrainData.point_on_ground(p.x, p.y, -0.1)
	tree.rotation.y = rng.randf() * TAU
	parent.add_child(tree)


func _scatter_rocks(parent: Node3D, area: Rect2, count: int, min_size: float, max_size: float,
		rng: RandomNumberGenerator, quarry: bool) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 20:
		attempts += 1
		var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
		if not _valid_ground(p.x, p.y, 2.0) or not _free_spot(p, 3.0):
			continue
		_placed.append(p)
		var rock := BreakableRock.new()
		rock.name = "Rock%d" % _rock_count
		rock.resource_id = "rock_%d" % _rock_count
		_rock_count += 1
		rock.size = rng.randf_range(min_size, max_size)
		rock.rock_seed = rng.randi_range(1, 12)
		rock.quarry = quarry
		rock.position = TerrainData.point_on_ground(p.x, p.y, -0.15 * rock.size)
		rock.rotation.y = rng.randf() * TAU
		parent.add_child(rock)
		placed += 1


func _scatter_grass_patches(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var index := 0
	for area: Rect2 in GRASS_AREAS:
		var count := int(area.get_area() / 42.0)
		var attempts := 0
		var placed := 0
		while placed < count and attempts < count * 15:
			attempts += 1
			var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
			if p.length() > WorldLayout.VALLEY_RADIUS - 3.0 or TerrainData.path_at(p.x, p.y) > 0.05:
				continue
			if TerrainData.height(p.x, p.y) < WorldLayout.WATER_LEVEL + 0.5 or TerrainData.normal_at(p.x, p.y).y < 0.9:
				continue
			if not _free_spot(p, 2.2):
				continue
			_placed.append(p)
			var patch := GrassPatch.new()
			patch.name = "GrassPatch%d" % index
			patch.resource_id = "grass_%d" % index
			patch.patch_seed = index * 31 + 5
			patch.position = TerrainData.point_on_ground(p.x, p.y)
			parent.add_child(patch)
			index += 1
			placed += 1


func _scatter_bushes(rng: RandomNumberGenerator) -> void:
	var transforms: Array[Array] = [[], [], [], []]
	var attempts := 0
	var placed := 0
	while placed < 110 and attempts < 3000:
		attempts += 1
		var p := Vector2(rng.randf_range(-88, 88), rng.randf_range(-88, 88))
		if not _valid_ground(p.x, p.y, 1.5) or not _free_spot(p, 2.0):
			continue
		placed += 1
		var s := rng.randf_range(0.8, 1.4)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), TerrainData.point_on_ground(p.x, p.y, -0.05))
		transforms[rng.randi() % transforms.size()].append(xf)
	for i in transforms.size():
		_multimesh(NatureModels.bush(i + 1), transforms[i], "Bushes%d" % i, true)


## Hill forest tiles whose centre is farther than this switch from leaf-card trees to
## impostors (one camera-facing picture per tree), which cost a fraction to draw.
## Within FOREST_FADE of the switch both are drawn, so it is hidden. There is no range
## fade: the forest shaders set ALPHA themselves, so a fade would not show, and a
## fading instance is drawn in the much slower transparent pass.
const FOREST_FAR := 75.0
const FOREST_FADE := 12.0


func _build_hill_forest(rng: RandomNumberGenerator) -> void:
	var meshes := NatureModels.forest_meshes()
	var frames: Array[Vector2] = []
	for m in meshes:
		frames.append(NatureModels.impostor_frame(m))
	# Tiles so each block of forest is culled and switches detail on its own.
	const TILE := 40.0
	var tiles := {}
	var rect := WorldLayout.map_rect().grow(-2.0)
	var step := 5.0
	var z := rect.position.y
	while z < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var px := x + rng.randf_range(0.0, step)
			var pz := z + rng.randf_range(0.0, step)
			x += step
			if WorldLayout.playable_distance(px, pz) > -1.0:
				continue
			if TerrainData.path_at(px, pz) > 0.1 or rng.randf() < 0.18:
				continue
			var n := TerrainData.normal_at(px, pz)
			if n.y < 0.62:
				continue
			var s := rng.randf_range(0.9, 1.5)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
			var kind := rng.randi_range(0, 2) if rng.randf() < 0.7 else rng.randi_range(3, 4)
			var key := Vector2i(floori(px / TILE), floori(pz / TILE))
			if not tiles.has(key):
				tiles[key] = [[], [], [], [], []]
			tiles[key][kind].append(Transform3D(b, TerrainData.point_on_ground(px, pz, -0.2)))
		z += step
	for key: Vector2i in tiles:
		var far := []
		for i in meshes.size():
			var near := _multimesh(meshes[i], tiles[key][i], "HillForest%d_%d_%d" % [i, key.x, key.y], false)
			if near:
				near.visibility_range_end = FOREST_FAR + FOREST_FADE
			for xf: Transform3D in tiles[key][i]:
				far.append([xf, i])
		_impostors(far, frames, "HillForestFar_%d_%d" % [key.x, key.y])


## One multimesh of impostor cards for a forest tile: [[transform, kind]].
func _impostors(trees: Array, frames: Array[Vector2], node_name: String) -> void:
	if trees.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = NatureModels.impostor_card()
	mm.instance_count = trees.size()
	for j in trees.size():
		var kind: int = trees[j][1]
		mm.set_instance_transform(j, trees[j][0])
		mm.set_instance_custom_data(j, Color(kind, frames[kind].x, frames[kind].y, 1.0 if kind >= 3 else 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visibility_range_begin = FOREST_FAR - FOREST_FADE
	add_child(mmi)


func _multimesh(mesh: Mesh, transforms: Array, node_name: String, shadows: bool) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Leaf-card clutter spread over the whole map: not voxelized into SDFGI (it still
	# receives GI).
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mmi)
	return mmi
