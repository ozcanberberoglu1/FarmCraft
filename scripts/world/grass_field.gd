@tool
class_name GrassField
extends Node3D
## Scatters grass clumps and wild flowers over the valley using chunked MultiMeshes.
## Each chunk is distance-culled; the grass shader shrinks blades before the cutoff.
## Chunks are generated deterministically, so areas can be cleared later (new
## buildings, fields) by rebuilding only the affected chunks.

@export var density := 3.2
@export var flower_density := 0.07
@export var chunk_size := 16.0
@export var radius := 90.0
@export var fade_end := 44.0
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
	grass_mat.shader = load("res://shaders/grass.gdshader")
	grass_mat.set_shader_parameter("fade_start", fade_end - 12.0)
	grass_mat.set_shader_parameter("fade_end", fade_end)
	grass_mat.set_shader_parameter("ground_tex", Mats.texture("leafy_grass", "diff.jpg"))
	_grass_meshes.clear()
	for i in 4:
		var m := NatureModels.grass_clump(i + 1, 6 + i).duplicate() as ArrayMesh
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
	# every blade into its root (a fading instance is drawn in the slower transparent
	# pass). Flowers don't shrink, so they fade out.
	for i in _grass_meshes.size():
		_add_multimesh(nodes, _grass_meshes[i], buffers[i], base, fade_end + chunk_size * 0.75, false)
	for i in _flower_meshes.size():
		_add_multimesh(nodes, _flower_meshes[i], buffers[_grass_meshes.size() + i], base, fade_end + chunk_size, true)


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
		var s := rng.randf_range(0.75, 1.2)
		var stretch := rng.randf_range(0.85, 1.25)
		var rot := rng.randf() * TAU
		var kind := rng.randi() % _grass_meshes.size()
		var skip := rng.randf()
		var patch := _patch_noise.get_noise_2d(x, z)
		if patch < -0.45 and skip < 0.7:
			continue
		if not _allowed(x, z, rects):
			continue
		var y := TerrainData.height(x, z)
		s *= 1.15 if patch > 0.3 else 1.0
		var b := Basis(Vector3.UP, rot).scaled(Vector3(s, s * stretch, s))
		grass_xf[kind].append(Transform3D(b, Vector3(x, y - 0.03, z) - base))

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


func _allowed(x: float, z: float, rects: Array[Rect2]) -> bool:
	var d := sqrt(x * x + z * z)
	var inside := WorldLayout.playable_distance(x, z)
	if inside < -4.0:
		return false
	if TerrainData.path_at(x, z) > 0.3 or TerrainData.dirt_at(x, z) > 0.4:
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
