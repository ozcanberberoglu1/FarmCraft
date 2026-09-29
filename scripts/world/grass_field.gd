@tool
class_name GrassField
extends Node3D
## Scatters meadow grass and wild flowers over the valley using chunked MultiMeshes.
## The grass is photo-scanned tufts on alpha-tested cards (three crossed cards per
## clump, cut from Poly Haven's grass_medium_01 atlas, see TUFTS): the grass shader
## colours each clump from the same meadow fields as the terrain under it (lush in damp
## hollows, trampled along lanes and yards, dry patches that turn some tufts to straw),
## thins the clumps out with distance and shrinks the rest into their roots before the
## chunk is cut off. Chunks are generated deterministically, so areas can be cleared
## later (new buildings, fields) by rebuilding only the affected chunks.

## Grass tufts: [rect in the 2048x1024 card atlas (green half; the dry copy sits 512
## rows lower), tuft height in metres]. tools/build_grass_cards.gd packs the atlas
## (keep its rects in step with these).
const TUFTS := [
	[Rect2i(8, 8, 572, 249), 0.34],
	[Rect2i(596, 8, 431, 262), 0.42],
	[Rect2i(1043, 8, 456, 198), 0.28],
	[Rect2i(8, 278, 353, 223), 0.36],
	[Rect2i(377, 278, 520, 182), 0.26],
]
const ATLAS_SIZE := Vector2(2048, 1024)
const ATLAS := "res://art/textures/grass_cards/grass_cards_albedo.png"
## Clump meshes (each three cards with their own tufts); a clump picks one at random.
const CLUMP_VARIANTS := 3
## How far the flowers are drawn (metres to a chunk's centre).
const FLOWER_RANGE := 58.0
## Share of the grass clumps each graphics preset draws (LOW..ULTRA).
const QUALITY_SHARE: Array[float] = [0.45, 0.7, 0.88, 1.0]

@export var density := 3.0
@export var flower_density := 0.07
@export var chunk_size := 20.0
@export var radius := 90.0
@export var fade_end := 58.0
@export var rebuild := false:
	set(value):
		if value and is_inside_tree():
			_cache.clear()
			build()

## Rects (world XZ) where no grass grows, registered by buildings and fields.
var blocked: Array[Rect2] = []

## Instance buffers of the chunks built so far, kept across scene reloads (the world is
## built again on Continue and on a language change): chunk key -> [the blocked rects
## touching the chunk, one MultiMesh buffer per grass mesh and then per flower mesh].
static var _cache := {}
## density, flower_density and chunk_size the cache was built with.
static var _cache_settings := Vector3.ZERO
static var _clumps: Array[ArrayMesh] = []

var _patch_noise := FastNoiseLite.new()
var _grass_meshes: Array[Mesh] = []
var _flower_meshes: Array[Mesh] = []
var _chunks: Dictionary = {}
## Chunks to rebuild after block(), one per frame.
var _pending: Array[Vector2i] = []
var _built := false


func _ready() -> void:
	set_process(false)
	# Deferred so structures created in the same frame can register their footprint first.
	build.call_deferred()
	if not Engine.is_editor_hint():
		Settings.changed.connect(_apply_quality)


## Removes grass inside `rect` (plus a small margin); the affected chunks are rebuilt
## over the next frames, one per frame.
func block(rect: Rect2) -> void:
	var r := rect.grow(0.3)
	if blocked.has(r):
		return
	blocked.append(r)
	if not _built:
		return
	for key: Vector2i in _chunks:
		if Rect2(_origin(key), Vector2.ONE * chunk_size).intersects(rect.grow(0.5)) and not _pending.has(key):
			_pending.append(key)
	set_process(not _pending.is_empty())


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		_build_chunk(_pending.pop_front())
	set_process(not _pending.is_empty())


## World XZ of a chunk's corner. Chunks tile the map rectangle.
func _origin(key: Vector2i) -> Vector2:
	return WorldLayout.map_rect().position + Vector2(key.x, key.y) * chunk_size


func build() -> void:
	for c in get_children():
		c.queue_free()
	_chunks.clear()
	_pending.clear()
	var settings := Vector3(density, flower_density, chunk_size)
	if settings != _cache_settings:
		_cache.clear()
		_cache_settings = settings
	TerrainData.ensure()
	_patch_noise.seed = 99
	_patch_noise.frequency = 0.04
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/grass_card.gdshader")
	grass_mat.set_shader_parameter("albedo_tex", load(ATLAS))
	grass_mat.set_shader_parameter("fade_start", fade_end - 16.0)
	grass_mat.set_shader_parameter("fade_end", fade_end)
	TerrainData.apply_ground_fields(grass_mat)
	_grass_meshes.clear()
	for i in CLUMP_VARIANTS:
		var m := clump_mesh(i).duplicate() as ArrayMesh
		m.surface_set_material(0, grass_mat)
		_grass_meshes.append(m)
	_flower_meshes.clear()
	for i in NatureModels.FLOWER_COLORS.size():
		_flower_meshes.append(NatureModels.flower(i))
	# Chunks over the playable area: farm valley, road corridor and town.
	var rect := WorldLayout.map_rect()
	for cz in int(ceil(rect.size.y / chunk_size)):
		for cx in int(ceil(rect.size.x / chunk_size)):
			var key := Vector2i(cx, cz)
			var center := _origin(key) + Vector2.ONE * chunk_size * 0.5
			if WorldLayout.playable_distance(center.x, center.y) < -chunk_size * 0.75:
				continue
			_build_chunk(key)
	_built = true


## A grass clump: three cards crossing at 60 degrees around the root, each showing one
## photo tuft at its own size. UV = atlas (green half), UV2.x = height up the card
## (0 root .. 1 top), UV2.y = the card's random value. Normals lean off vertical,
## alike on both faces, so the cards of a clump catch the light differently.
static func clump_mesh(variant: int) -> ArrayMesh:
	if _clumps.size() > variant and _clumps[variant] != null:
		return _clumps[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + 17
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var turn := rng.randf() * TAU
	for k in 3:
		var t: Array = TUFTS[rng.randi() % TUFTS.size()]
		var r: Rect2i = t[0]
		var h: float = float(t[1]) * rng.randf_range(0.85, 1.15)
		var w: float = h * float(r.size.x) / float(r.size.y)
		var a := turn + k * TAU / 3.0 + rng.randf_range(-0.25, 0.25)
		var side := Vector3(cos(a), 0.0, sin(a))
		var facing := Vector3(-side.z, 0.0, side.x)
		var centre := Vector3(rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.06, 0.06))
		# The tops lean a little to one side.
		var lean := facing * rng.randf_range(-0.12, 0.12) * h
		# Tilted well off vertical: blades take the midday sun at a slant (the photo
		# already has its own light), a low sun lights some cards and backlights others.
		var n := (Vector3.UP * 0.8 + facing * 0.6).normalized()
		var u0 := r.position.x / ATLAS_SIZE.x
		var u1 := (r.position.x + r.size.x) / ATLAS_SIZE.x
		var v0 := r.position.y / ATLAS_SIZE.y
		var v1 := (r.position.y + r.size.y) / ATLAS_SIZE.y
		# Mirror half the cards so the same tuft doesn't repeat itself.
		if rng.randf() < 0.5:
			var tmp := u0
			u0 = u1
			u1 = tmp
		var rnd := rng.randf()
		var base := verts.size()
		# The root edge sits a little under the ground so no gap shows on slopes.
		verts.append_array([centre - side * w * 0.5 + Vector3(0, -0.03, 0), centre + side * w * 0.5 + Vector3(0, -0.03, 0),
				centre + side * w * 0.5 + Vector3(0, h, 0) + lean, centre - side * w * 0.5 + Vector3(0, h, 0) + lean])
		norms.append_array([n, n, n, n])
		uvs.append_array([Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)])
		uv2s.append_array([Vector2(0.0, rnd), Vector2(0.0, rnd), Vector2(1.0, rnd), Vector2(1.0, rnd)])
		idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Instances sway and shrink in the shader: keep culling from clipping bent tops.
	mesh.custom_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 1.0, 1.6))
	while _clumps.size() <= variant:
		_clumps.append(null)
	_clumps[variant] = mesh
	return mesh


func _build_chunk(key: Vector2i) -> void:
	if _chunks.has(key):
		for n: Node in _chunks[key]:
			n.queue_free()
	var nodes: Array[Node] = []
	_chunks[key] = nodes
	var origin := _origin(key)
	var center := origin + Vector2.ONE * chunk_size * 0.5
	var base := Vector3(center.x, TerrainData.height(center.x, center.y), center.y)
	# Only the blocked rects touching this chunk are checked for each point.
	var area := Rect2(origin, Vector2.ONE * chunk_size)
	var rects: Array[Rect2] = []
	for r in blocked:
		if r.intersects(area, true):
			rects.append(r)
	var entry: Array = _cache.get(key, [])
	if entry.is_empty() or entry[0] != rects:
		entry = [rects, _scatter(key, origin, base, rects)]
		_cache[key] = entry
	var buffers: Array = entry[1]
	# Grass is cut off without a fade: at that distance the shader has already shrunk
	# every clump into its root (a fading instance is drawn in the slower transparent
	# pass). Flowers don't shrink, so they fade out.
	for i in _grass_meshes.size():
		_add_multimesh(nodes, _grass_meshes[i], buffers[i], base, fade_end + chunk_size * 0.75, false)
	for i in _flower_meshes.size():
		_add_multimesh(nodes, _flower_meshes[i], buffers[_grass_meshes.size() + i], base, FLOWER_RANGE, true)
	_apply_quality_to(nodes)


## Draws the share of each chunk's grass the graphics preset allows. Clumps are stored
## in scatter order (random positions), so any leading share is spread evenly.
func _apply_quality() -> void:
	for key: Vector2i in _chunks:
		_apply_quality_to(_chunks[key])


func _apply_quality_to(nodes: Array[Node]) -> void:
	var share := 1.0 if Engine.is_editor_hint() else QUALITY_SHARE[Settings.quality]
	for n in nodes:
		var mmi := n as MultiMeshInstance3D
		if mmi and is_instance_valid(mmi) and _grass_meshes.has(mmi.multimesh.mesh):
			var count := mmi.multimesh.instance_count
			mmi.multimesh.visible_instance_count = count if share >= 1.0 else int(count * share)


## Places the chunk's grass clumps and flowers; returns one MultiMesh buffer per grass
## mesh, then one per flower mesh.
func _scatter(key: Vector2i, origin: Vector2, base: Vector3, rects: Array[Rect2]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + 4242
	var grass_xf: Array = []
	for i in _grass_meshes.size():
		grass_xf.append([])
	var flower_xf: Array = []
	for i in _flower_meshes.size():
		flower_xf.append([])

	var tries := int(chunk_size * chunk_size * density)
	for i in tries:
		# Draw every random number up front so skipped points don't shift the sequence.
		var x := origin.x + rng.randf() * chunk_size
		var z := origin.y + rng.randf() * chunk_size
		var s := rng.randf_range(0.75, 1.35)
		var stretch := rng.randf_range(0.85, 1.2)
		var rot := rng.randf() * TAU
		var kind := rng.randi() % _grass_meshes.size()
		var skip := rng.randf()
		var patch := _patch_noise.get_noise_2d(x, z)
		# Sparser, lower grass in patches, a denser sward elsewhere.
		if patch < -0.3 and skip < 0.6:
			continue
		if not _allowed(x, z, rects):
			# A few low tufts in the grassy strip between a lane's wheel ruts.
			if skip < 0.45 or TerrainData.track_distance(x, z) > 0.28 or not _allowed(x, z, rects, true):
				continue
			s *= 0.7
		var y := TerrainData.height(x, z)
		s *= 1.2 if patch > 0.35 else 1.0
		var b := Basis(Vector3.UP, rot).scaled(Vector3(s, s * stretch, s))
		grass_xf[kind].append(Transform3D(b, Vector3(x, y, z) - base))

	var flower_tries := int(chunk_size * chunk_size * flower_density)
	for i in flower_tries:
		var x := origin.x + rng.randf() * chunk_size
		var z := origin.y + rng.randf() * chunk_size
		var s := rng.randf_range(0.8, 1.2)
		var rot := rng.randf() * TAU
		if _patch_noise.get_noise_2d(x * 1.7, z * 1.7) < 0.05 or not _allowed(x, z, rects):
			continue
		var y := TerrainData.height(x, z)
		var xf := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(s, s, s)), Vector3(x, y, z) - base)
		# Flower colors cluster by area.
		var kind := int(absf(_patch_noise.get_noise_2d(x * 0.5 + 100.0, z * 0.5)) * 20.0) % _flower_meshes.size()
		flower_xf[kind].append(xf)

	var buffers := []
	for list: Array in grass_xf + flower_xf:
		buffers.append(_buffer(list))
	return buffers


## Transforms in the MultiMesh.buffer layout (TRANSFORM_3D: 12 floats per instance).
static func _buffer(transforms: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(transforms.size() * 12)
	var o := 0
	for xf: Transform3D in transforms:
		var b := xf.basis
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = xf.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = xf.origin.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = xf.origin.z
		o += 12
	return buf


func _add_multimesh(nodes: Array[Node], mesh: Mesh, buffer: PackedFloat32Array, base: Vector3, vis_end: float,
		fade: bool) -> void:
	if buffer.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = buffer.size() / 12
	mm.buffer = buffer
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.position = base
	# Small clutter: kept out of the rain-blocker heightfield.
	mmi.layers = 2
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.visibility_range_end = vis_end
	if fade:
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	nodes.append(mmi)


## Whether meadow grass grows at (x, z); `on_lane` allows the lanes themselves.
func _allowed(x: float, z: float, rects: Array[Rect2], on_lane := false) -> bool:
	var d := sqrt(x * x + z * z)
	var inside := WorldLayout.playable_distance(x, z)
	if inside < -4.0:
		return false
	if not on_lane and TerrainData.path_at(x, z) > 0.3:
		return false
	if TerrainData.dirt_at(x, z) > 0.4:
		return false
	if WorldLayout.is_cleared(x, z):
		return false
	var p := Vector2(x, z)
	for r in rects:
		if r.has_point(p):
			return false
	if TerrainData.height(x, z) < WorldLayout.WATER_LEVEL + 0.3:
		return false
	if (d > 60.0 or inside < 6.0) and TerrainData.normal_at(x, z).y < 0.8:
		return false
	return true
