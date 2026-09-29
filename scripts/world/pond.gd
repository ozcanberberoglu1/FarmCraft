@tool
class_name Pond
extends Node3D
## Water surface for the pond plus an invisible ring that keeps the player on shore.
## The water body is interactable so the watering can can be refilled here (phase 3).
## Fish live in it: the fishing rod (Angler) casts into water deep enough for the float
## (is_fishable) and its flights ignore the shore ring (shore_wall).
## Reeds with a few cattails grow in stands along the water's edge, leaving the farm
## side open (visual only: no collision).

## Reed stands: [centre angle around the pond (radians, 0 = east, toward the farm), half
## width (radians), clumps].
const REED_STANDS := [[1.95, 0.32, 26], [2.9, 0.42, 36], [3.9, 0.3, 22], [4.75, 0.28, 18], [5.45, 0.14, 8]]
const REED_CLUMP_VARIANTS := 3
## Screen-space reflection march steps of the water per graphics preset (LOW..ULTRA).
const REFLECTION_STEPS: Array[int] = [0, 10, 14, 16]

static var _reed_meshes: Array[ArrayMesh] = []

var _water_mat: ShaderMaterial


## Water shallower than this doesn't float the float or hold a fish.
const FISHING_DEPTH := 0.12


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"pond")
	for c in get_children():
		c.queue_free()
	position = Vector3(WorldLayout.POND_CENTER.x, WorldLayout.WATER_LEVEL, WorldLayout.POND_CENTER.y)
	var r := WorldLayout.POND_RADIUS
	var plane := PlaneMesh.new()
	plane.size = Vector2(r * 2.8, r * 2.8)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	_water_mat = mat
	_apply_quality()
	if not Engine.is_editor_hint() and not Settings.changed.is_connected(_apply_quality):
		Settings.changed.connect(_apply_quality)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_add_reeds()

	var body := StaticBody3D.new()
	body.name = "ShoreWall"
	body.collision_layer = 1
	body.collision_mask = 0
	var segments := 28
	var wall_r := r - 0.9
	for i in segments:
		var ang := TAU * (i + 0.5) / segments
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * wall_r / segments + 0.4, 4.0, 0.4)
		cs.shape = box
		cs.position = Vector3(cos(ang) * wall_r, 1.0, sin(ang) * wall_r)
		cs.rotation.y = -ang + PI * 0.5
		body.add_child(cs)
	add_child(body)

	# Water surface the player can aim at to refill the watering can.
	var surface := StaticBody3D.new()
	surface.name = "WaterSurface"
	surface.collision_layer = 4
	surface.collision_mask = 0
	var scs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r + 0.3
	cyl.height = 0.2
	scs.shape = cyl
	surface.add_child(scs)
	add_child(surface)


func _apply_quality() -> void:
	var q: int = REFLECTION_STEPS.size() - 1 if Engine.is_editor_hint() else Settings.quality
	_water_mat.set_shader_parameter("ssr_steps", REFLECTION_STEPS[q])


## Reed clumps along the shoreline stands: each at the water's edge, from a little way
## into the water to just above it.
func _add_reeds() -> void:
	if _reed_meshes.is_empty():
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/grass.gdshader")
		mat.set_shader_parameter("fade_start", 70.0)
		mat.set_shader_parameter("fade_end", 90.0)
		mat.set_shader_parameter("bend", 0.07)
		mat.set_shader_parameter("blade_color", Color(0.28, 0.36, 0.17))
		mat.set_shader_parameter("tip_color", Color(0.5, 0.48, 0.3))
		mat.set_shader_parameter("dry_tips", 0.45)
		for v in REED_CLUMP_VARIANTS:
			_reed_meshes.append(_reed_clump(v, mat))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var lists: Array = []
	for v in REED_CLUMP_VARIANTS:
		lists.append([])
	var centre := WorldLayout.POND_CENTER
	for stand: Array in REED_STANDS:
		for i in int(stand[2]):
			var ang := float(stand[0]) + rng.randf_range(-1.0, 1.0) * float(stand[1])
			var dir := Vector2(cos(ang), sin(ang))
			var into := rng.randf_range(-0.9, 0.35)
			var s := rng.randf_range(0.75, 1.2)
			var rot := rng.randf() * TAU
			var kind := rng.randi() % REED_CLUMP_VARIANTS
			var r := _shore_radius(dir) + into
			var p := centre + dir * r
			var y := maxf(TerrainData.height(p.x, p.y), WorldLayout.WATER_LEVEL - 0.35)
			var xf := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(s, s * rng.randf_range(0.85, 1.15), s)),
					Vector3(p.x, y - 0.05, p.y) - global_position)
			lists[kind].append(xf)
	for v in REED_CLUMP_VARIANTS:
		var list: Array = lists[v]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _reed_meshes[v]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Reeds%d" % v
		mmi.multimesh = mm
		# Small clutter: kept out of the rain-blocker heightfield.
		mmi.layers = 2
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mmi.visibility_range_end = 95.0
		add_child(mmi)


## Distance from the pond centre, along `dir`, to where the ground rises out of the water.
static func _shore_radius(dir: Vector2) -> float:
	var r := WorldLayout.POND_RADIUS * 0.5
	while r < WorldLayout.POND_RADIUS + 5.0:
		var p := WorldLayout.POND_CENTER + dir * r
		if TerrainData.height(p.x, p.y) > WorldLayout.WATER_LEVEL:
			return r
		r += 0.1
	return WorldLayout.POND_RADIUS


## A clump of reed leaves, a few with a cattail: long narrow blades (UV.x = blade
## height, UV.y = up the blade, as the grass shader expects), the cattail heads brown
## through the vertex colour.
static func _reed_clump(variant: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808 + variant * 31
	var mb := MeshBuilder.new()
	var green := Color.WHITE
	var brown := Color(0.82, 0.5, 0.6)
	for i in 22:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.22)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0.0, sin(facing))
		var out := Vector3(root.x, 0.0, root.z).normalized() if root.length() > 0.01 else side
		var h := rng.randf_range(0.8, 1.6)
		var w := rng.randf_range(0.014, 0.024)
		var lean := out * rng.randf_range(0.05, 0.3) * h
		# Three segments that bend over toward the tip.
		var pts: Array[Vector3] = []
		for k in 4:
			var f := k / 3.0
			pts.append(root + Vector3.UP * h * f + lean * f * f)
		for k in 3:
			var f0 := k / 3.0
			var f1 := (k + 1) / 3.0
			var w0 := w * (1.0 - f0 * 0.75)
			var w1 := w * (1.0 - f1 * 0.75)
			var n := Vector3.UP
			if k < 2:
				mb.tri_n(&"reed", pts[k] - side * w0, pts[k] + side * w0, pts[k + 1] + side * w1, n, n, n, green, green, green,
						Vector2(h, f0), Vector2(h, f0), Vector2(h, f1))
				mb.tri_n(&"reed", pts[k] - side * w0, pts[k + 1] + side * w1, pts[k + 1] - side * w1, n, n, n, green, green,
						green, Vector2(h, f0), Vector2(h, f1), Vector2(h, f1))
			else:
				mb.tri_n(&"reed", pts[k] - side * w0, pts[k] + side * w0, pts[k + 1], n, n, n, green, green, green,
						Vector2(h, f0), Vector2(h, f0), Vector2(h, 1.0))
	# Cattails: a straight stem with a brown head below its spike.
	for i in rng.randi_range(1, 3):
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.15)
		var h := rng.randf_range(1.3, 1.8)
		var side := Vector3(cos(a + 1.3), 0.0, sin(a + 1.3))
		var n := Vector3.UP
		var top := root + Vector3.UP * h
		mb.tri_n(&"reed", root - side * 0.006, root + side * 0.006, top + side * 0.003, n, n, n, green, green, green,
				Vector2(h, 0.0), Vector2(h, 0.0), Vector2(h, 1.0))
		mb.tri_n(&"reed", root - side * 0.006, top + side * 0.003, top - side * 0.003, n, n, n, green, green, green,
				Vector2(h, 0.0), Vector2(h, 1.0), Vector2(h, 1.0))
		# The head: a six-sided spindle from 0.8 to 0.92 of the stem.
		var y0 := h * 0.8
		var y1 := h * 0.92
		for k in 6:
			var a0 := TAU * k / 6.0
			var a1 := TAU * (k + 1) / 6.0
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var b0 := root + d0 * 0.022 + Vector3.UP * y0
			var b1 := root + d1 * 0.022 + Vector3.UP * y0
			var t0 := root + d0 * 0.02 + Vector3.UP * y1
			var t1 := root + d1 * 0.02 + Vector3.UP * y1
			var v0 := y0 / h
			var v1 := y1 / h
			mb.tri_n(&"reed", b0, t1, b1, d0, d1, d1, brown, brown, brown, Vector2(h, v0), Vector2(h, v1), Vector2(h, v0))
			mb.tri_n(&"reed", b0, t0, t1, d0, d0, d1, brown, brown, brown, Vector2(h, v0), Vector2(h, v1), Vector2(h, v1))
	return mb.build({&"reed": mat}, true)


func use_prompt(_player: Node, stack: ItemStack) -> String:
	return WaterSource.use_prompt(stack)


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return WaterSource.use_action(stack)


func can_start(_action: Dictionary, stack: ItemStack) -> String:
	return WaterSource.can_start(stack)


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	WaterSource.refill(stack)


## Water deep enough to fish in at `p` (its x and z).
static func is_fishable(p: Vector3) -> bool:
	var c := WorldLayout.POND_CENTER
	if Vector2(p.x, p.z).distance_to(c) > WorldLayout.POND_RADIUS + 1.5:
		return false
	return TerrainData.height(p.x, p.z) < WorldLayout.WATER_LEVEL - FISHING_DEPTH


## The invisible ring that keeps the player on the shore (casts fly over it).
func shore_wall() -> CollisionObject3D:
	return get_node_or_null("ShoreWall") as CollisionObject3D
