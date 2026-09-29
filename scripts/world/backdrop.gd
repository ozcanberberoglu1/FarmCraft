@tool
class_name Backdrop
extends Node3D
## Distant landscape around the map, so the world never ends at the terrain's edge:
## the rim's hills and their forest carry on past the map edge, roll out into broad
## wooded hills with clearings and rise to a ring of ridges a few kilometres away.
## Decorative only: one land mesh and one multimesh of tree cards, no collision, no
## shadows, not in GI. Both shaders draw their far parts squeezed inside the camera's
## range (shaders/include/backdrop.gdshaderinc), which needs all real geometry nearer
## than 0.86 of the camera's far plane from any spot the player can reach.
##
## The meshes are built once per session and shown by children without an owner, so
## nothing generated is ever saved into the scene.

## Vertices around each ring.
const SEGMENTS := 360
## Distance of each ring outside the map edge (metres, along the ray from the map
## centre). The first ones tuck under the terrain's edge so no gap can show; the
## spacing grows with distance, finest where the rim's own hills carry on.
const RINGS: Array[float] = [-12.0, -3.0, 0.0, 3.0, 7.0, 12.0, 18.0, 25.0, 33.0, 42.0, 52.0,
		63.0, 75.0, 88.0, 102.0, 118.0, 136.0, 156.0, 178.0, 203.0, 231.0, 262.0, 297.0, 336.0,
		380.0, 430.0, 487.0, 552.0, 625.0, 707.0, 800.0, 905.0, 1025.0, 1160.0, 1310.0, 1480.0,
		1680.0, 1900.0, 2150.0, 2450.0, 2800.0, 3200.0, 3650.0, 4150.0, 4700.0, 5300.0]
## Canopy surface above the ground where the tree cards give way to it (metres).
const CANOPY := 9.0
## Height of the far ridges above the hills in front of them.
const RIDGE_HEIGHT := 380.0
const SEED := 20240917
## Tree cards past the edge: the hill forest's density up to TREES_FULL metres out,
## thinning to none at TREES_END while the canopy surface rises under them.
const TREE_STEP := 5.0
const TREES_FULL := 40.0
const TREES_END := 230.0
## Share of the hill forest's grid cells that hold a tree (nature_spawner skips 18%).
const TREE_CHANCE := 0.82
## Trees are listed by distance out in bins this wide, nearest first, so a lower
## graphics preset drops the farthest ones (see TREE_SHARE).
const TREE_BIN := 25.0
## Share of the tree cards drawn per graphics preset (LOW .. ULTRA).
const TREE_SHARE: Array[float] = [0.55, 0.8, 1.0, 1.0]

## Built once per session: the world scene is rebuilt on every load.
static var _land: ArrayMesh
static var _trees: MultiMesh
static var _tree_material: ShaderMaterial

## The terrain's own hill noise (TerrainData._generate), so the rim carries on.
var _t_rolling: FastNoiseLite
var _t_hills: FastNoiseLite
var _t_ridge: FastNoiseLite
## Broad hills and far ridges.
var _rolling: FastNoiseLite
var _ridge: FastNoiseLite
## Ground height (without canopy) at each mesh vertex, for placing the trees.
var _ground_h := PackedFloat32Array()


func _ready() -> void:
	# In the editor the terrain may have been rebuilt since (Terrain.rebuild): build
	# afresh whenever the scene opens.
	if _land == null or Engine.is_editor_hint():
		_build()
	var land := MeshInstance3D.new()
	land.name = "Land"
	land.mesh = _land
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	land.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(land)
	var trees := MultiMeshInstance3D.new()
	trees.name = "Trees"
	trees.multimesh = _trees
	trees.material_override = _tree_material
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trees.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(trees)
	if not Engine.is_editor_hint():
		Settings.changed.connect(_apply_quality)
		_apply_quality()


## Draws the share of the tree cards the graphics preset allows.
func _apply_quality() -> void:
	_trees.visible_instance_count = int(_trees.instance_count * TREE_SHARE[Settings.quality])


func _build() -> void:
	TerrainData.ensure()
	_t_rolling = FastNoiseLite.new()
	_t_rolling.seed = TerrainData.SEED
	_t_rolling.frequency = 0.018
	_t_rolling.fractal_octaves = 3
	_t_hills = FastNoiseLite.new()
	_t_hills.seed = TerrainData.SEED + 1
	_t_hills.frequency = 0.012
	_t_hills.fractal_octaves = 4
	_t_ridge = FastNoiseLite.new()
	_t_ridge.seed = TerrainData.SEED + 3
	_t_ridge.frequency = 0.022
	_t_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_t_ridge.fractal_octaves = 3
	_rolling = FastNoiseLite.new()
	_rolling.seed = SEED + 41
	_rolling.frequency = 1.0 / 520.0
	_rolling.fractal_octaves = 3
	_ridge = FastNoiseLite.new()
	_ridge.seed = SEED + 43
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.frequency = 1.0 / 2300.0
	_ridge.fractal_octaves = 4
	_land = _build_land()
	_trees = _build_trees()
	_tree_material = _build_tree_material()


func _build_land() -> ArrayMesh:
	var rect := WorldLayout.map_rect()
	var center := rect.get_center()
	var rings := RINGS.size()
	var count := SEGMENTS * rings
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(count)
	colors.resize(count)
	uvs.resize(count)
	_ground_h.resize(count)
	for a in SEGMENTS:
		var dir := _ray(a)
		var r0 := _edge_distance(dir)
		var edge := center + dir * r0
		# The terrain's height at the edge, and how far the continued noise misses it
		# there: the miss fades out over the first metres so the seam is exact.
		var edge_h := TerrainData.height(edge.x - dir.x * 0.5, edge.y - dir.y * 0.5)
		var miss := edge_h - _ground(edge, 0.0, dir)
		for k in rings:
			var s: float = RINGS[k]
			var p := center + dir * (r0 + s)
			var i := k * SEGMENTS + a
			var ground: float
			if s < 0.0:
				ground = TerrainData.height(p.x, p.y) - 3.0
			elif s == 0.0:
				ground = edge_h - 0.5
			else:
				ground = _ground(p, s, dir) + miss * (1.0 - smoothstep(0.0, 40.0, s))
			# Forest everywhere but on the highest ridges, which are bare rock.
			var rock := smoothstep(420.0, 560.0, ground)
			_ground_h[i] = ground
			var canopy := CANOPY * smoothstep(TREES_FULL, TREES_END, s) * (1.0 - rock)
			verts[i] = Vector3(p.x, ground + canopy, p.y)
			colors[i] = Color(1.0 - rock, rock, 0.0)
			uvs[i] = Vector2(s, 0.0)

	var normals := PackedVector3Array()
	normals.resize(count)
	for k in rings:
		for a in SEGMENTS:
			var left := verts[k * SEGMENTS + (a + SEGMENTS - 1) % SEGMENTS]
			var right := verts[k * SEGMENTS + (a + 1) % SEGMENTS]
			var inner := verts[maxi(k - 1, 0) * SEGMENTS + a]
			var outer := verts[mini(k + 1, rings - 1) * SEGMENTS + a]
			normals[k * SEGMENTS + a] = (outer - inner).cross(right - left).normalized() * -1.0
	var idx := PackedInt32Array()
	idx.resize((rings - 1) * SEGMENTS * 6)
	var n := 0
	for k in rings - 1:
		for a in SEGMENTS:
			var b := (a + 1) % SEGMENTS
			var i0 := k * SEGMENTS + a
			var i1 := k * SEGMENTS + b
			var i2 := (k + 1) * SEGMENTS + a
			var i3 := (k + 1) * SEGMENTS + b
			# Clockwise as seen from above (Godot front faces).
			idx[n] = i0
			idx[n + 1] = i2
			idx[n + 2] = i3
			idx[n + 3] = i0
			idx[n + 4] = i3
			idx[n + 5] = i1
			n += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/backdrop.gdshader")
	m.surface_set_material(0, mat)
	return m


## Ground height `s` metres out from the map edge at `p`, along `dir` from the map
## centre. The rim's hills carry on as TerrainData builds them (its noise at full hill
## weight), their finer relief fading where the mesh grows coarser, into broad hills
## that rise towards the far ridges. All of it is a 2D field, so nothing lines up with
## the rings or rays of the mesh. East and west, where the sun rises and sets, the land
## stays low (about a degree above the horizon from a hilltop), so the sun is seen
## going down over it rather than vanishing behind a ridge while it still lights the farm.
func _ground(p: Vector2, s: float, dir: Vector2) -> float:
	var fine := 1.0 - smoothstep(40.0, 130.0, s)
	var mid := 1.0 - smoothstep(160.0, 520.0, s)
	var rim := 17.0 + _t_hills.get_noise_2dv(p) * 12.0 * mid \
			+ (_t_ridge.get_noise_2dv(p) * 5.0 + _t_rolling.get_noise_2dv(p) * 1.2) * fine
	var sun_side := smoothstep(0.72, 0.94, absf(dir.x))
	var broad := _rolling.get_noise_2dv(p) * 40.0 * smoothstep(60.0, 1200.0, s) * lerpf(1.0, 0.35, sun_side)
	var rise := smoothstep(150.0, 1500.0, s) * 55.0 * lerpf(1.0, 0.3, sun_side)
	var ridge := (0.35 + 0.65 * (_ridge.get_noise_2dv(p) * 0.5 + 0.5)) * smoothstep(900.0, 4300.0, s) \
			* RIDGE_HEIGHT * lerpf(1.0, 0.12, sun_side)
	return rim + broad + rise + ridge


## The hill forest carried on past the edge as the same camera-facing tree pictures
## (NatureModels impostors): its density near the map, thinning out over the rising
## canopy surface. Ordered nearest first (see TREE_BIN).
func _build_trees() -> MultiMesh:
	var meshes := NatureModels.forest_meshes()
	var frames: Array[Vector2] = []
	for m in meshes:
		frames.append(NatureModels.impostor_frame(m))
	var broad := NatureModels.forest_broad()
	var conifers := NatureModels.forest_kinds(false)
	var broadleaf := NatureModels.forest_kinds(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 47
	var rect := WorldLayout.map_rect()
	var center := rect.get_center()
	var bins: Array[Array] = []
	for i in ceili(TREES_END / TREE_BIN):
		bins.append([])
	var z := rect.position.y - TREES_END
	while z < rect.end.y + TREES_END:
		var x := rect.position.x - TREES_END
		while x < rect.end.x + TREES_END:
			var p := Vector2(x + rng.randf() * TREE_STEP, z + rng.randf() * TREE_STEP)
			x += TREE_STEP
			if rect.has_point(p):
				continue
			var to_p := p - center
			var dir := to_p.normalized()
			var s := to_p.length() - _edge_distance(dir)
			if s < 1.5 or s > TREES_END:
				continue
			if rng.randf() > TREE_CHANCE * pow(1.0 - smoothstep(TREES_FULL, TREES_END, s), 1.5):
				continue
			var y := _ground_at(dir, s) - 0.25
			# The trees are built at their natural size (as in the hill forest).
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25))
			var kind: int = conifers[rng.randi() % conifers.size()] if rng.randf() < 0.7 \
					else broadleaf[rng.randi() % broadleaf.size()]
			var bin := clampi(floori((s + rng.randf_range(-15.0, 15.0)) / TREE_BIN), 0, bins.size() - 1)
			bins[bin].append([Transform3D(b, Vector3(p.x, y, p.y)), kind])
		z += TREE_STEP
	# Shuffled within each bin, so a cut through it thins it evenly all round.
	var trees := []
	for b in bins:
		for i in range(b.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t: Array = b[i]
			b[i] = b[j]
			b[j] = t
		trees.append_array(b)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = NatureModels.impostor_card()
	mm.instance_count = trees.size()
	for j in trees.size():
		var kind: int = trees[j][1]
		mm.set_instance_transform(j, trees[j][0])
		mm.set_instance_custom_data(j, Color(kind, frames[kind].x, frames[kind].y, 1.0 if broad[kind] else 0.0))
	return mm


## The hill forest's impostor material with the backdrop's depth squeeze: same atlas
## and settings, taken from the card so the two never drift apart.
func _build_tree_material() -> ShaderMaterial:
	var source := NatureModels.impostor_card().surface_get_material(0) as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/backdrop_trees.gdshader")
	for param in [&"atlas", &"normal_atlas", &"rows", &"views", &"brightness"]:
		mat.set_shader_parameter(param, source.get_shader_parameter(param))
	return mat


## Ground height on the land mesh `s` metres out along `dir` (between its vertices).
func _ground_at(dir: Vector2, s: float) -> float:
	var af := fposmod(atan2(dir.y, dir.x), TAU) / TAU * SEGMENTS
	var a0 := floori(af) % SEGMENTS
	var a1 := (a0 + 1) % SEGMENTS
	var ta := af - floorf(af)
	var k := 0
	while k < RINGS.size() - 2 and RINGS[k + 1] <= s:
		k += 1
	var tk := clampf((s - RINGS[k]) / (RINGS[k + 1] - RINGS[k]), 0.0, 1.0)
	var inner := lerpf(_ground_h[k * SEGMENTS + a0], _ground_h[k * SEGMENTS + a1], ta)
	var outer := lerpf(_ground_h[(k + 1) * SEGMENTS + a0], _ground_h[(k + 1) * SEGMENTS + a1], ta)
	return lerpf(inner, outer, tk)


static func _ray(a: int) -> Vector2:
	var ang := TAU * a / SEGMENTS
	return Vector2(cos(ang), sin(ang))


## Distance from the map centre to the map edge along `dir`.
static func _edge_distance(dir: Vector2) -> float:
	var half := WorldLayout.map_rect().size * 0.5
	return minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
