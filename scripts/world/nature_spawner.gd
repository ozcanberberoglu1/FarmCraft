@tool
class_name NatureSpawner
extends Node3D
## Places trees, bushes, rocks and tall grass. Trees, rocks and grass patches inside
## the valley are harvestable resources with stable ids (for regrowth and saving);
## the forest on the surrounding hills is drawn with MultiMeshes, and the forest
## edges get a floor of ferns, nettles, fallen branches, stones, stumps and logs.

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
	_scatter_undergrowth()
	if not Engine.is_editor_hint():
		if not Settings.changed.is_connected(_apply_quality):
			Settings.changed.connect(_apply_quality)
		_apply_quality()


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
		# Quarry rocks wear the bare scans (same collision shape: see NatureModels.rock).
		rock.rock_seed = rng.randi_range(1, 12) + (NatureModels.QUARRY_SEED if quarry else 0)
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


## Hill forest tiles whose nearest point is farther than this (m, per graphics preset
## LOW..ULTRA) switch from the 3D trees to impostors (one camera-facing picture per
## tree, from its side), which cost a fraction to draw. Within FOREST_FADE of the switch
## both are drawn, so it is hidden. There is no range fade: the forest shaders set
## ALPHA themselves, so a fade would not show, and a fading instance is drawn in the
## much slower transparent pass.
const FOREST_FAR: Array[float] = [60.0, 80.0, 120.0, 170.0]
const FOREST_FADE := 12.0
## How long the trees keep their finer levels of detail per graphics preset
## (GeometryInstance3D.lod_bias; see NatureModels.LOD_KEYS).
const LOD_BIAS: Array[float] = [0.6, 0.8, 1.3, 2.0]
## Spacing of the hill forest's grid (m; 15 % of its cells stay empty), and the share of
## its trees drawn per graphics preset.
const FOREST_STEP := 4.3
const FOREST_SHARE: Array[float] = [0.75, 0.9, 1.0, 1.0]
## From this preset (HIGH) up the forest's leaf cards cast the sun's shadows themselves
## (the crowns' own dappled shade); below it the plain shadow shapes stand in for them.
const CARD_SHADOWS := 2

## The hill forest's tiles of 3D trees, of impostors and of shadow shapes.
var _forest_near: Array[MultiMeshInstance3D] = []
var _forest_far: Array[MultiMeshInstance3D] = []
var _forest_shade: Array[MultiMeshInstance3D] = []


func _build_hill_forest(rng: RandomNumberGenerator) -> void:
	_forest_near.clear()
	_forest_far.clear()
	_forest_shade.clear()
	var meshes := NatureModels.forest_meshes()
	var broad_kinds := NatureModels.forest_broad()
	var frames: Array[Vector2] = []
	for m in meshes:
		frames.append(NatureModels.impostor_frame(m))
	var conifers := NatureModels.forest_kinds(false)
	var broadleaf := NatureModels.forest_kinds(true)
	# Tiles so each block of forest is culled and switches detail on its own.
	const TILE := 40.0
	var tiles := {}
	# One tree of a random kind (seven in ten conifers), `s` times its natural size, with
	# a random rank: a graphics preset drawing a share of the forest (FOREST_SHARE) draws
	# the trees ranked below it, in every tile and level of detail alike.
	var add := func(px: float, pz: float, s: float) -> void:
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		var kind: int = conifers[rng.randi() % conifers.size()] if rng.randf() < 0.7 \
				else broadleaf[rng.randi() % broadleaf.size()]
		var key := Vector2i(floori(px / TILE), floori(pz / TILE))
		if not tiles.has(key):
			var lists := []
			for i in meshes.size():
				lists.append([])
			tiles[key] = lists
		tiles[key][kind].append([Transform3D(b, TerrainData.point_on_ground(px, pz, -0.2)), rng.randf()])
	var rect := WorldLayout.map_rect().grow(-2.0)
	var z := rect.position.y
	while z < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var px := x + rng.randf_range(0.0, FOREST_STEP)
			var pz := z + rng.randf_range(0.0, FOREST_STEP)
			x += FOREST_STEP
			if WorldLayout.playable_distance(px, pz) > -1.0:
				continue
			if TerrainData.path_at(px, pz) > 0.1 or rng.randf() < 0.15:
				continue
			var n := TerrainData.normal_at(px, pz)
			if n.y < 0.62:
				continue
			# The trees are built at their natural size.
			add.call(px, pz, rng.randf_range(0.8, 1.2))
		z += FOREST_STEP
	# Young trees along the forest's edge: the wood thins out into the meadow through
	# saplings and half-grown trees instead of ending in a wall of full-grown ones.
	var young := 3.0
	z = rect.position.y
	while z < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var px := x + rng.randf_range(0.0, young)
			var pz := z + rng.randf_range(0.0, young)
			x += young
			var edge := WorldLayout.playable_distance(px, pz)
			if edge > -0.8 or edge < -9.0 or rng.randf() > 0.32:
				continue
			if TerrainData.path_at(px, pz) > 0.1 or TerrainData.normal_at(px, pz).y < 0.62:
				continue
			add.call(px, pz, lerpf(0.28, 0.7, clampf(-edge / 9.0, 0.0, 1.0)) * rng.randf_range(0.8, 1.2))
		z += young
	var proxies: Array[Transform3D] = []
	for m in meshes:
		proxies.append(NatureModels.shadow_transform(m))
	var by_rank := func(a: Array, b: Array) -> bool: return a[1] < b[1]
	for key: Vector2i in tiles:
		var far := []
		# Shadow shapes: cones for the conifers, ellipsoids for the broadleaf trees.
		var shades := [[], []]
		for i in meshes.size():
			var trees: Array = tiles[key][i]
			trees.sort_custom(by_rank)
			var near := _multimesh(meshes[i], trees.map(func(t: Array) -> Transform3D: return t[0]),
					"HillForest%d_%d_%d" % [i, key.x, key.y], false)
			if near:
				near.visibility_range_end = FOREST_FAR[Settings.Quality.ULTRA] + FOREST_FADE
				_ranked(near, trees)
				_forest_near.append(near)
			var broad := broad_kinds[i]
			for t: Array in trees:
				far.append([t[0], i, t[1]])
				shades[1 if broad else 0].append([t[0] * proxies[i], t[1]])
		far.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
		_impostors(far, frames, broad_kinds, "HillForestFar_%d_%d" % [key.x, key.y])
		# Below CARD_SHADOWS the leaf cards cast no shadows; the shapes cast them for the
		# 3D trees (see NatureModels.shadow_shape).
		for k in 2:
			var list: Array = shades[k]
			list.sort_custom(by_rank)
			var shade := _multimesh(NatureModels.shadow_shape(k == 1), list.map(func(t: Array) -> Transform3D: return t[0]),
					"ForestShade%d_%d_%d" % [k, key.x, key.y], true)
			if shade:
				shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				shade.visibility_range_end = FOREST_FAR[Settings.Quality.ULTRA] + FOREST_FADE
				_ranked(shade, list)
				_forest_shade.append(shade)


## Keeps the ranks of a forest multimesh's trees ([_, rank] in instance order, rising)
## for FOREST_SHARE.
func _ranked(mmi: MultiMeshInstance3D, trees: Array) -> void:
	var ranks := PackedFloat32Array()
	for t: Array in trees:
		ranks.append(float(t[t.size() - 1]))
	mmi.set_meta(&"ranks", ranks)


## One multimesh of impostor cards for a forest tile: [[transform, kind]].
func _impostors(trees: Array, frames: Array[Vector2], broad: Array[bool], node_name: String) -> void:
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
		mm.set_instance_custom_data(j, Color(kind, frames[kind].x, frames[kind].y, 1.0 if broad[kind] else 0.0))
	var mmi := MultiMeshInstance3D.new()
	_ranked(mmi, trees)
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visibility_range_begin = FOREST_FAR[Settings.Quality.ULTRA] - FOREST_FADE
	add_child(mmi)
	_forest_far.append(mmi)


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


# --- Forest floor ---------------------------------------------------------------------

## Clutter along the forest edges and under the valley's woods: scan and piece
## (NatureModels.SCANS), share of the spots, size range (height, or length for wood
## lying down), triangle budget, how much of it is sunk into the ground, whether it
## lies along the slope, view range (m), shadows, and the band of edge distance it
## grows in (WorldLayout.playable_distance: positive inside the playable area).
## No collision: it is all small or lies flat.
const UNDERGROWTH := [
	{"scan": "fern_02", "piece": 1, "share": 2.4, "size": [0.7, 1.1], "tris": 1200, "range": 50.0, "band": [-13.0, 1.5]},
	{"scan": "fern_02", "piece": 2, "share": 2.0, "size": [0.6, 1.0], "tris": 1200, "range": 50.0, "band": [-13.0, 1.5]},
	{"scan": "fern_02", "piece": 0, "share": 1.4, "size": [0.45, 0.75], "tris": 800, "range": 40.0, "band": [-13.0, 2.0]},
	{"scan": "nettle_plant", "piece": 4, "share": 1.0, "size": [0.75, 1.1], "tris": 1000, "range": 45.0,
		"band": [-5.0, 2.0]},
	{"scan": "nettle_plant", "piece": 0, "share": 0.9, "size": [0.45, 0.7], "tris": 800, "range": 40.0,
		"band": [-5.0, 2.0]},
	{"scan": "dry_branches_medium_01", "piece": 0, "share": 0.7, "size": [1.1, 1.8], "tris": 800, "lie": true,
		"sink": 0.2, "range": 40.0, "band": [-13.0, 0.5]},
	{"scan": "dry_branches_medium_01", "piece": 1, "share": 0.6, "size": [0.8, 1.3], "tris": 600, "lie": true,
		"sink": 0.2, "range": 35.0, "band": [-13.0, 0.5]},
	{"scan": "rock_moss_set_02", "piece": 1, "share": 0.5, "size": [0.2, 0.5], "tris": 600, "lie": true, "sink": 0.3,
		"range": 60.0, "band": [-13.0, 1.0]},
	{"scan": "rock_moss_set_01", "piece": 2, "share": 0.4, "size": [0.25, 0.6], "tris": 600, "lie": true, "sink": 0.3,
		"range": 60.0, "band": [-13.0, 1.0]},
	{"scan": "tree_stump_01", "piece": 0, "share": 0.25, "size": [0.45, 0.75], "tris": 2500, "sink": 0.12,
		"range": 90.0, "band": [-13.0, -2.0]},
	{"scan": "dead_tree_trunk", "piece": 0, "share": 0.2, "size": [3.5, 5.5], "tris": 3000, "lie": true, "sink": 0.25,
		"range": 90.0, "shadows": true, "band": [-13.0, -3.0]},
]
## The valley's woods (NatureSpawner._scatter_trees areas) also get a forest floor.
const WOODS := [Rect2(-90, -70, 34, 120), Rect2(-58, -84, 44, 36)]
## Undergrowth tiles: a MultiMesh picks one level of detail for all of it (by its
## nearest point) and is one draw call; this balances the two.
const FLOOR_TILE := 40.0
## Share of the undergrowth drawn and how far, per graphics preset (Settings.Quality).
const FLOOR_SHARE := [0.35, 0.6, 1.0, 1.0]
const FLOOR_RANGE := [0.6, 0.8, 1.0, 1.0]
## How far the sun's shadows reach per graphics preset (DayNightCycle.apply_quality;
## they fade out over the last 15 %): past it the trees and bushes shade their crowns
## themselves (tree_leaves.gdshader and foliage_card.gdshader shade_range).
const SHADOW_REACH := [60.0, 90.0, 120.0, 120.0]

## [MultiMeshInstance3D, view range] of the forest floor, for the graphics presets.
var _floor: Array = []


func _scatter_undergrowth() -> void:
	_floor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var patches := FastNoiseLite.new()
	patches.seed = 31
	patches.frequency = 0.07
	var total := 0.0
	for u: Dictionary in UNDERGROWTH:
		total += float(u["share"])
	var tiles := {}
	var rect := WorldLayout.map_rect().grow(-2.0)
	var step := 1.8
	var z := rect.position.y
	while z < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var p := Vector2(x + rng.randf_range(0.0, step), z + rng.randf_range(0.0, step))
			x += step
			var edge := WorldLayout.playable_distance(p.x, p.y)
			var woods := edge > 0.0 and WOODS.any(func(r: Rect2) -> bool: return r.has_point(p))
			if edge < -13.0 or (edge > 2.0 and not woods):
				continue
			# Colonies: dense in patches, thin between them; densest just inside the trees.
			var density := smoothstep(-0.25, 0.35, patches.get_noise_2dv(p)) * (0.55 if woods else 1.0)
			density *= 1.0 - smoothstep(-6.0, -13.0, edge) * 0.5
			if rng.randf() > density * 0.8:
				continue
			if not _floor_ground(p, edge, woods):
				continue
			var pick := rng.randf() * total
			var index := 0
			while index < UNDERGROWTH.size() - 1:
				pick -= float(UNDERGROWTH[index]["share"])
				if pick <= 0.0:
					break
				index += 1
			var u: Dictionary = UNDERGROWTH[index]
			var band: Array = u["band"]
			if not woods and (edge < float(band[0]) or edge > float(band[1])):
				continue
			var key := Vector2i(floori(p.x / FLOOR_TILE), floori(p.y / FLOOR_TILE))
			if not tiles.has(key):
				tiles[key] = {}
			if not tiles[key].has(index):
				tiles[key][index] = []
			tiles[key][index].append(_floor_transform(u, p, rng))
		z += step
	for key: Vector2i in tiles:
		for index: int in tiles[key]:
			var u: Dictionary = UNDERGROWTH[index]
			var list: Array = tiles[key][index]
			# Shuffled, so the graphics presets can draw a random share of them.
			for i in range(list.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var t: Transform3D = list[i]
				list[i] = list[j]
				list[j] = t
			var mesh := NatureModels.floor_mesh(u["scan"], u["piece"], float(u.get("sink", 0.05)), float(u["range"]),
					int(u["tris"]))
			var mmi := _multimesh(mesh, list, "ForestFloor%d_%d_%d" % [index, key.x, key.y], u.get("shadows", false))
			if mmi:
				# Small clutter: kept out of the rain-blocker heightfield.
				mmi.layers = 2
				_floor.append([mmi, float(u["range"])])


## Whether the forest floor can have something at `p`: not on paths, roads, water or
## the farm's working ground, not on anything placed (trees, rocks, grass patches).
func _floor_ground(p: Vector2, edge: float, woods: bool) -> bool:
	if TerrainData.path_at(p.x, p.y) > 0.05 or TerrainData.dirt_at(p.x, p.y) > 0.2:
		return false
	if TerrainData.height(p.x, p.y) < WorldLayout.WATER_LEVEL + 0.3:
		return false
	if WorldLayout.distance_to_road(p.x, p.y) < 6.5:
		return false
	if TerrainData.normal_at(p.x, p.y).y < 0.62:
		return false
	if edge > -1.0 or woods:
		# Inside the playable area: keep clear of the working farm and what is placed.
		if WorldLayout.is_cleared(p.x, p.y, 2.0) or Rect2(-30, -32, 98, 68).has_point(p):
			return false
		if not _free_spot(p, 1.3):
			return false
	return true


## Where one piece of clutter stands: turned at random, sized, sunk and (lying wood and
## stones) tilted with the slope.
func _floor_transform(u: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> Transform3D:
	var size: Array = u["size"]
	var target := rng.randf_range(size[0], size[1])
	var box := NatureModels.piece_bounds(u["scan"], u["piece"])
	var lie: bool = u.get("lie", false)
	var along := maxf(box.size.x, box.size.z) if lie and float(size[1]) > 1.0 else box.size.y
	var s := target / maxf(along, 0.01)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
	if lie:
		var n := TerrainData.normal_at(p.x, p.y)
		basis = Basis(Quaternion(Vector3.UP, n)) * basis
	var sink := float(u.get("sink", 0.05)) * box.size.y * s
	return Transform3D(basis, TerrainData.point_on_ground(p.x, p.y, -sink))


## Draws the share of the forest floor the graphics preset allows, as far as it allows;
## sets how far the forest's 3D trees reach, how long trees keep their detail and what
## casts the forest's shadows; has the crowns shade themselves where the sun's shadows end.
func _apply_quality() -> void:
	var q: int = Settings.quality
	for entry: Array in _floor:
		var mmi: MultiMeshInstance3D = entry[0]
		if not is_instance_valid(mmi):
			continue
		mmi.multimesh.visible_instance_count = ceili(mmi.multimesh.instance_count * FLOOR_SHARE[q])
		mmi.visibility_range_end = float(entry[1]) * FLOOR_RANGE[q]
	NatureModels.set_floor_range_scale(FLOOR_RANGE[q])
	var reach: float = SHADOW_REACH[q]
	(Mats.get_mat(&"leaves") as ShaderMaterial).set_shader_parameter("shade_range", Vector2(reach * 0.85, reach))
	for mat in NatureModels.leaf_materials():
		mat.set_shader_parameter("shade_range", Vector2(reach * 0.85, reach))
	var cards_cast := q >= CARD_SHADOWS
	for list: Array in [_forest_near, _forest_far, _forest_shade]:
		for mmi: MultiMeshInstance3D in list:
			var ranks: PackedFloat32Array = mmi.get_meta(&"ranks")
			mmi.multimesh.visible_instance_count = ranks.bsearch(FOREST_SHARE[q])
	for mmi in _forest_near:
		mmi.visibility_range_end = FOREST_FAR[q] + FOREST_FADE
		mmi.lod_bias = LOD_BIAS[q]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cards_cast \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mmi in _forest_far:
		mmi.visibility_range_begin = FOREST_FAR[q] - FOREST_FADE
	for mmi in _forest_shade:
		mmi.visible = not cards_cast
		mmi.visibility_range_end = FOREST_FAR[q] + FOREST_FADE
	var trees := get_node_or_null("Trees")
	if trees:
		for mi: MeshInstance3D in trees.find_children("*", "MeshInstance3D", true, false):
			mi.lod_bias = LOD_BIAS[q]
