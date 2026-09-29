@tool
class_name Fence
extends Node3D
## Rustic post-and-rail fence along a polyline of world XZ points (node at origin):
## hewn posts, some leaning, green and dark where they stand in the wet, and split
## rails silvered by the weather with lichen on them (the "fence_wood" material).
## Segments listed in `gaps` are left open as gateways.

@export var points := PackedVector2Array()
@export var closed := false
@export var gaps := PackedInt32Array()
@export var post_spacing := 2.2
@export var height := 1.1
@export var seed_value := 1
@export var rebuild := false:
	set(value):
		if value and is_inside_tree():
			build()

const WOOD := Color(0.52, 0.5, 0.48)
const WOOD_DARK := Color(0.42, 0.4, 0.38)


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	if points.size() < 2:
		return
	TerrainData.ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	var n := points.size()
	var seg_count := n if closed else n - 1
	var made := {}
	# Gate posts first so shared corners use the sturdier post.
	for s in seg_count:
		if s in gaps:
			_post_once(mb, made, points[s], rng, 1.35, 0.2)
			_post_once(mb, made, points[(s + 1) % n], rng, 1.35, 0.2)
	for s in seg_count:
		if s in gaps:
			continue
		var a := points[s]
		var b := points[(s + 1) % n]
		var count := maxi(1, roundi(a.distance_to(b) / post_spacing))
		var posts: Array[Transform3D] = []
		for i in count + 1:
			posts.append(_post_once(mb, made, a.lerp(b, float(i) / count), rng, 1.0, 0.14))
		for i in count:
			for rail_y: float in [height * 0.42, height * 0.82]:
				# Through the posts as they stand, leaning ones included.
				_rail(mb, posts[i] * Vector3(0, rail_y + 0.1, 0), posts[i + 1] * Vector3(0, rail_y + 0.1, 0), rng)
		_segment_collider(body, a, b)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	add_child(body)


## Adds a post unless one already stands at `p`; returns its frame (see _post).
func _post_once(mb: MeshBuilder, made: Dictionary, p: Vector2, rng: RandomNumberGenerator,
		height_scale: float, thickness: float) -> Transform3D:
	var key := Vector2i(roundi(p.x * 10.0), roundi(p.y * 10.0))
	if not made.has(key):
		made[key] = _post(mb, p, rng, height_scale, thickness)
	return made[key]


## A post at `p`; returns its frame: origin at its foot 0.1 m in the ground, Y up it.
func _post(mb: MeshBuilder, p: Vector2, rng: RandomNumberGenerator, height_scale: float, thickness: float) -> Transform3D:
	var ground := TerrainData.point_on_ground(p.x, p.y)
	var h := height * height_scale * rng.randf_range(0.95, 1.08) + 0.1
	# Most stand near true; now and then one has been pushed over by cattle or frost.
	var lean := 2.5 if rng.randf() < 0.85 else 6.0
	var tilt := Vector3(rng.randf_range(-lean, lean), rng.randf_range(0, 360), rng.randf_range(-lean, lean))
	var col := WOOD_DARK.lerp(WOOD, rng.randf())
	var b := Basis.from_euler(tilt * (PI / 180.0))
	var r := thickness * 0.62
	# Hewn to seven faces and tapering; darker and green up to where the grass wets it.
	var wet := Color(col.r * 0.6, col.g * 0.64, col.b * 0.52)
	var foot := Transform3D(b, ground + Vector3(0, -0.1, 0))
	mb.cylinder(&"fence_wood", foot, r * 1.06, r, 0.45, 7, wet, false, false, col)
	mb.cylinder(&"fence_wood", foot * Transform3D(Basis(), Vector3(0, 0.45, 0)), r, r * 0.9, h - 0.45, 7, col, false, true)
	return foot


func _rail(mb: MeshBuilder, from: Vector3, to: Vector3, rng: RandomNumberGenerator) -> void:
	var sag := Vector3(0, rng.randf_range(-0.03, 0.02), 0)
	var dir := (to - from).normalized()
	var col := WOOD.lerp(WOOD_DARK, rng.randf() * 0.5)
	# A split rail: an uneven five-sided section, a little thicker at one end, running
	# on past the posts at both ends.
	var r := rng.randf_range(0.045, 0.058)
	var a := from - dir * 0.07 + sag * 0.3
	var b := to + dir * 0.07 + sag * 0.3
	var mid := (from + to) * 0.5 + sag
	var taper := rng.randf_range(0.85, 1.0)
	mb.cylinder_between(&"fence_wood", a, mid, r, r * lerpf(1.0, taper, 0.5), 5, col, false, true)
	mb.cylinder_between(&"fence_wood", mid, b, r * lerpf(1.0, taper, 0.5), r * taper, 5, col, false, true)


func _segment_collider(body: StaticBody3D, a: Vector2, b: Vector2) -> void:
	var mid := (a + b) * 0.5
	var ground := TerrainData.point_on_ground(mid.x, mid.y)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(a.distance_to(b), 1.8, 0.24)
	cs.shape = box
	cs.position = ground + Vector3(0, 0.8, 0)
	var d := b - a
	cs.rotation.y = -atan2(d.y, d.x)
	body.add_child(cs)
