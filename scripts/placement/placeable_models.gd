@tool
class_name PlaceableModels
extends RefCounted
## Models of the placeable machines: photo-scanned Poly Haven props (CC0, see
## art/models/props/CREDITS.md) and pieces built here with the photo-textured
## materials. Every model stands on the ground at the origin with its front toward +Z.
## Machines with a part that moves have it as a separate "moving" mesh that turns
## about a vertical axis through pivot_of() (the quern's runner stone, the sprinkler's
## spinner); "whole" is everything together (icons, the placement preview, pickups).
## tools/bake_tools.gd saves the heavy ones to BAKED. Building kits (the coop kit) are
## a strapped flat-pack bundle as items (their placement preview is the finished
## building: ChickenCoop.ghost_mesh()).

const SCANS := {
	"spinning_wheel": "res://art/models/props/spinning_wheel_01/spinning_wheel_01_1k.gltf",
	"vice": "res://art/models/props/bench_vice_01/bench_vice_01_1k.gltf",
	"sprinkler": "res://art/models/props/garden_sprinkler_01/garden_sprinkler_01_1k.gltf",
	"barrel": "res://art/models/props/wine_barrel_01/wine_barrel_01_1k.gltf",
	"chalkboard": "res://art/models/props/standing_chalkboard_01/standing_chalkboard_01_1k.gltf",
	"stove": "res://art/models/props/barrel_stove/barrel_stove_1k.gltf",
	# The workbench's tools (tools/fetch_progression_models.py).
	"handsaw": "res://art/models/props/handsaw_wood/handsaw_wood_1k.gltf",
	"hammer": "res://art/models/props/wooden_hammer_01/wooden_hammer_01_1k.gltf",
	"plane": "res://art/models/props/hand_plane_no4/hand_plane_no4_1k.gltf",
}
const BAKED := "res://art/models/props/baked/%s_%s.res"
const MOVING: Array[StringName] = [&"quern", &"sprinkler"]
const QUERN_PIVOT := Vector3(0, 0.69, 0)
const WOOD := Color(0.55, 0.5, 0.45)
const WOOD_DARK := Color(0.42, 0.37, 0.33)
const IRON := Color(0.2, 0.2, 0.21)
const COPPER := Color(0.66, 0.4, 0.26)

static var _cache := {}


## "whole", "body" or "moving" mesh of a placeable (baked when available).
static func mesh(id: StringName, part := "whole") -> ArrayMesh:
	var key := "%s/%s" % [id, part]
	if _cache.has(key):
		return _cache[key]
	var path := BAKED % [id, part]
	var m: ArrayMesh = load(path) if ResourceLoader.exists(path) else build(id).get(part)
	_cache[key] = m
	return m


static func has_moving(id: StringName) -> bool:
	return id in MOVING


## Point on the axis the moving part turns about (model frame).
static func pivot_of(id: StringName) -> Vector3:
	if id == &"quern":
		return QUERN_PIVOT
	var m := mesh(id, "moving")
	if m == null:
		return Vector3.ZERO
	var c := m.get_aabb().get_center()
	return Vector3(c.x, 0.0, c.z)


## {"whole": mesh, "body": mesh, "moving": mesh or null}
static func build(id: StringName) -> Dictionary:
	var body := []
	var moving := []
	match id:
		&"workbench":
			_workbench(body, WORKBENCH_STAGES)
		&"cheese_press":
			_cheese_press(body)
		&"spinning_wheel":
			_scan(body, "spinning_wheel", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), 1.0)
		&"pickle_barrel":
			_scan(body, "barrel", Transform3D.IDENTITY, 0.87)
		&"jam_kettle":
			_jam_kettle(body)
		&"quern":
			_quern(body, moving)
		&"sprinkler":
			_sprinkler(body, moving)
		&"order_board":
			_scan(body, "chalkboard", Transform3D.IDENTITY, 1.51)
		&"coop_kit":
			_coop_kit(body)
		&"campfire":
			# Stones and laid logs (scripts/camp/campfire_model.gd).
			MeshMerge.add_mesh(body, CampfireModel.whole_mesh())
		&"food_table":
			# The butcher's table with its board and pail (food_table_model.gd).
			FoodTableModel.build(body)
	var out := {"body": MeshMerge.build(body), "moving": null}
	var whole := body.duplicate()
	if not moving.is_empty():
		out["moving"] = MeshMerge.build(moving)
		whole.append_array(moving)
	out["whole"] = MeshMerge.build(whole)
	return out


## A scanned prop standing on the origin, scaled to `height` metres tall.
static func _scan(out: Array, scan: String, xf: Transform3D, height: float, only := "", skip := "") -> void:
	var parts := MeshMerge.scene_parts(load(SCANS[scan]) as PackedScene)
	if only != "" or skip != "":
		parts = parts.filter(func(p: Array) -> bool:
			var n: String = p[3]
			return (only == "" or only in n) and (skip == "" or skip not in n))
	var all_parts := MeshMerge.scene_parts(load(SCANS[scan]) as PackedScene)
	var box := MeshMerge.bounds(all_parts)
	var s := height / maxf(box.size.y, 0.001)
	var base := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var frame := xf * Transform3D(Basis.from_scale(Vector3.ONE * s), -base * s)
	MeshMerge.add_parts(out, parts, frame)


static func _add(out: Array, mb: MeshBuilder, xf := Transform3D.IDENTITY) -> void:
	MeshMerge.add_mesh(out, mb.build(), xf)


## A scanned piece turned by `rot`, scaled so its longest side is `longest` metres,
## set down with the middle of its base at `at`.
static func _scan_fit(out: Array, scan: String, rot: Basis, at: Vector3, longest: float) -> void:
	var parts := MeshMerge.scene_parts(load(SCANS[scan]) as PackedScene)
	var box := MeshMerge.bounds(parts, Transform3D(rot))
	var s := longest / maxf(maxf(box.size.x, box.size.y), maxf(box.size.z, 0.001))
	var base := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	MeshMerge.add_parts(out, parts, Transform3D(Basis.from_scale(Vector3.ONE * s), at) * Transform3D(rot, -base))


# --- Workbench ------------------------------------------------------------------------

## Stages the workbench goes up in on its site (Workbench); WORKBENCH_STAGES is the
## finished bench with its tools.
const WORKBENCH_STAGES := 3
static var _bench_stages := {}


## The bench part-built on its site: 0 legs and lower rails, 1 the frame and the shelf,
## 2 the top on (no tools yet).
static func workbench_stage(stage: int) -> ArrayMesh:
	if not _bench_stages.has(stage):
		var out := []
		_workbench(out, stage)
		_bench_stages[stage] = MeshMerge.build(out)
	return _bench_stages[stage]


## A heavy joiner's bench: plank top, square legs with rails, a lower shelf with a box
## of offcuts, a back board with the scanned saw hanging on its pegs, the scanned vice
## bolted to the front right corner and a hammer and a plane on the top. Built up to
## `stage` (see workbench_stage; WORKBENCH_STAGES: all of it).
static func _workbench(out: Array, stage: int) -> void:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var top := 0.9
	# Legs, the lower rails and the stretchers.
	for x: float in [-0.84, 0.84]:
		for z: float in [-0.32, 0.32]:
			mb.box_at(&"wood", Vector3(x, (top - 0.07) * 0.5, z), Vector3(0.09, top - 0.07, 0.09), WOOD_DARK)
	for z: float in [-0.32, 0.32]:
		mb.box_at(&"wood", Vector3(0, 0.2, z), Vector3(1.6, 0.07, 0.05), WOOD_DARK)
	for x: float in [-0.84, 0.84]:
		mb.box_at(&"wood", Vector3(x, 0.2, 0), Vector3(0.05, 0.07, 0.6), WOOD_DARK)
	if stage >= 1:
		# Aprons under the top and the shelf's boards.
		for z: float in [-0.32, 0.32]:
			mb.box_at(&"wood", Vector3(0, top - 0.13, z), Vector3(1.6, 0.1, 0.05), WOOD_DARK)
		for i in 4:
			mb.box_at(&"planks", Vector3(-0.6 + i * 0.4, 0.25, 0), Vector3(0.38, 0.025, 0.66), WOOD.darkened(0.08))
	if stage >= 2:
		for i in 3:
			var z := -0.27 + i * 0.27
			mb.box_at(&"wood", Vector3(0, top - 0.035, z), Vector3(1.9, 0.07, 0.26), WOOD.lightened(rng.randf_range(-0.05, 0.05)))
	if stage < WORKBENCH_STAGES:
		_add(out, mb)
		return
	# Box of offcuts on the shelf.
	var bx := Vector3(-0.45, 0.26, 0.02)
	mb.box_at(&"planks", bx + Vector3(0, 0.1, 0), Vector3(0.44, 0.2, 0.32), WOOD.lightened(0.05))
	for i in 5:
		mb.box_at(&"wood", bx + Vector3(rng.randf_range(-0.14, 0.14), 0.2 + rng.randf() * 0.06, rng.randf_range(-0.08, 0.08)),
				Vector3(rng.randf_range(0.2, 0.34), 0.03, 0.05), WOOD.lightened(0.1), Vector3(rng.randf_range(-8, 8), rng.randf_range(-20, 20), 0))
	# The back board on two posts, with pegs for the saw and a coil of string.
	var bz := -0.43
	for x: float in [-0.84, 0.84]:
		mb.box_at(&"wood", Vector3(x, (top + 1.55) * 0.5, bz), Vector3(0.07, 1.55 - top, 0.06), WOOD_DARK)
	mb.box_at(&"planks", Vector3(0, 1.3, bz + 0.01), Vector3(1.75, 0.4, 0.025), WOOD.lightened(0.04), Vector3.ZERO, true)
	mb.box_at(&"wood", Vector3(0, 1.52, bz + 0.01), Vector3(1.8, 0.05, 0.05), WOOD_DARK)
	for x: float in [-0.52, -0.1, 0.45, 0.62]:
		mb.cylinder_between(&"wood", Vector3(x, 1.4, bz + 0.02), Vector3(x, 1.41, bz + 0.1), 0.009, 0.008, 6, WOOD_DARK)
	mb.ring(&"cloth", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.62, 1.33, bz + 0.05)), 0.06, 0.035, 0.03, 14, Color(0.72, 0.62, 0.45))
	# A board being worked on the top.
	mb.box_at(&"planks", Vector3(0.1, top + 0.012, -0.22), Vector3(0.7, 0.024, 0.16), WOOD.lightened(0.08), Vector3(0, 6, 0))
	_add(out, mb)
	_scan(out, "vice", Transform3D(Basis(Vector3.UP, PI), Vector3(0.66, top, 0.28)), 0.29)
	# The saw hanging flat on the back board, its handle on the left peg.
	_scan_fit(out, "handsaw", Basis(Vector3.UP, PI * 0.5), Vector3(-0.28, 1.19, bz + 0.035), 0.6)
	# The claw hammer lying on its side, and the plane on its sole.
	_scan_fit(out, "hammer", Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)).rotated(Vector3.UP, 0.35),
			Vector3(-0.45, top, 0.05), 0.3)
	_scan_fit(out, "plane", Basis(Vector3.UP, -0.2), Vector3(0.2, top + 0.024, -0.2), 0.25)


# --- Cheese press ------------------------------------------------------------------------

## Farmhouse screw press: two uprights and a crossbeam carry an iron screw that bears
## on a follower in a hooped wooden mould, standing in a draining tray with a spout.
static func _cheese_press(out: Array) -> void:
	var mb := MeshBuilder.new()
	mb.box_at(&"wood", Vector3(0, 0.12, 0), Vector3(0.9, 0.1, 0.62), WOOD_DARK)
	for x: float in [-0.38, 0.38]:
		for z: float in [-0.24, 0.24]:
			mb.box_at(&"wood", Vector3(x, 0.035, z), Vector3(0.1, 0.07, 0.1), WOOD_DARK.darkened(0.1))
	# Draining board with a lip and a spout at the front.
	mb.box_at(&"wood", Vector3(0, 0.185, 0), Vector3(0.66, 0.03, 0.5), WOOD)
	for s: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(0, 0.215, s * 0.24), Vector3(0.66, 0.03, 0.02), WOOD)
		mb.box_at(&"wood", Vector3(s * 0.32, 0.215, 0), Vector3(0.02, 0.03, 0.5), WOOD)
	mb.box_at(&"wood", Vector3(0, 0.19, 0.29), Vector3(0.06, 0.02, 0.1), WOOD)
	# Mould with iron hoops, the follower and a pressing block.
	mb.cylinder(&"wood", Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.17, 0.17, 0.22, 20, WOOD.lightened(0.05))
	for y: float in [0.24, 0.36]:
		mb.ring(&"metal", Transform3D(Basis(), Vector3(0, y, 0)), 0.176, 0.168, 0.025, 20, IRON)
	mb.cylinder(&"wood", Transform3D(Basis(), Vector3(0, 0.42, 0)), 0.16, 0.16, 0.04, 20, WOOD)
	mb.box_at(&"wood", Vector3(0, 0.5, 0), Vector3(0.24, 0.12, 0.24), WOOD_DARK)
	# Frame and screw.
	for x: float in [-0.36, 0.36]:
		mb.box_at(&"wood", Vector3(x, 0.72, 0), Vector3(0.09, 1.2, 0.09), WOOD_DARK)
	mb.box_at(&"wood", Vector3(0, 1.22, 0), Vector3(0.9, 0.13, 0.13), WOOD_DARK)
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(0, 0.56, 0)), 0.026, 0.026, 0.8, 10, IRON)
	for i in 14:
		mb.ring(&"metal", Transform3D(Basis(), Vector3(0, 0.62 + i * 0.04, 0)), 0.034, 0.024, 0.012, 10, IRON.lightened(0.1))
	mb.cylinder_between(&"metal", Vector3(-0.26, 1.38, 0), Vector3(0.26, 1.38, 0), 0.016, 0.016, 8, IRON)
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(0, 1.29, 0)), 0.04, 0.04, 0.1, 10, IRON)
	for x: float in [-0.26, 0.26]:
		mb.sphere(&"metal", Transform3D(Basis(), Vector3(x, 1.38, 0)), Vector3.ONE * 0.028, 8, 6, IRON)
	_add(out, mb)


# --- Jam kettle --------------------------------------------------------------------------

## A copper preserving pan with two handles and a wooden spoon, on a barrel stove.
static func _jam_kettle(out: Array) -> void:
	_scan(out, "stove", Transform3D.IDENTITY, 0.86)
	var mb := MeshBuilder.new()
	var y0 := 0.86
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 7:
		var t := float(i) / 6.0
		centers.append(Vector3(0, y0 + t * 0.24, 0))
		radii.append(lerpf(0.2, 0.27, sqrt(t)))
	mb.loft(&"metal", centers, radii, 24, COPPER)
	mb.disc(&"metal", Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, y0 + 0.002, 0)), 0.2, 24, COPPER.darkened(0.2))
	mb.ring(&"metal", Transform3D(Basis(), Vector3(0, y0 + 0.235, 0)), 0.285, 0.262, 0.02, 24, COPPER.lightened(0.1))
	for s: float in [-1.0, 1.0]:
		mb.ring(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * 0.3, y0 + 0.2, 0)), 0.05, 0.038, 0.014, 12, IRON)
	# The contents (dark fruit) and a wooden spoon leaning on the rim.
	mb.disc(&"veg_gloss", Transform3D(Basis(), Vector3(0, y0 + 0.17, 0)), 0.245, 24, Color(0.58, 0.1, 0.1))
	mb.cylinder_between(&"wood", Vector3(0.05, y0 + 0.14, 0.02), Vector3(0.24, y0 + 0.52, 0.12), 0.012, 0.01, 8, WOOD.lightened(0.1))
	mb.sphere(&"wood", Transform3D(Basis(), Vector3(0.04, y0 + 0.13, 0.015)), Vector3(0.04, 0.012, 0.03), 10, 6, WOOD.lightened(0.1))
	_add(out, mb)


# --- Quern ----------------------------------------------------------------------------------

## Two millstones on a sturdy table with a flour trough; the upper (runner) stone is
## turned by a peg and moves separately.
static func _quern(body: Array, moving: Array) -> void:
	var mb := MeshBuilder.new()
	for x: float in [-0.38, 0.38]:
		for z: float in [-0.38, 0.38]:
			mb.box_at(&"wood", Vector3(x, 0.26, z), Vector3(0.1, 0.52, 0.1), WOOD_DARK)
	mb.box_at(&"wood", Vector3(0, 0.54, 0), Vector3(0.96, 0.06, 0.96), WOOD)
	for s: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(0, 0.14, s * 0.38), Vector3(0.7, 0.06, 0.05), WOOD_DARK)
	# Bed stone with a rim of flour and a small wooden trough at the front.
	mb.cylinder(&"stone", Transform3D(Basis(), Vector3(0, 0.57, 0)), 0.4, 0.39, 0.1, 28, Color(0.55, 0.53, 0.5))
	mb.ring(&"veg_rough", Transform3D(Basis(), Vector3(0, 0.57, 0)), 0.43, 0.395, 0.02, 28, Color(0.9, 0.88, 0.82))
	mb.box_at(&"wood", Vector3(0, 0.6, 0.47), Vector3(0.22, 0.06, 0.14), WOOD)
	mb.box_at(&"veg_rough", Vector3(0, 0.625, 0.47), Vector3(0.16, 0.02, 0.1), Color(0.92, 0.9, 0.84))
	_add(body, mb)
	var runner := MeshBuilder.new()
	var pivot := QUERN_PIVOT
	runner.cylinder(&"stone", Transform3D(Basis(), Vector3(0, 0.67, 0) - pivot), 0.37, 0.36, 0.13, 28, Color(0.5, 0.49, 0.47))
	runner.cylinder(&"stone", Transform3D(Basis(), Vector3(0, 0.8, 0) - pivot), 0.06, 0.07, 0.012, 16, Color(0.3, 0.29, 0.28))
	runner.cylinder(&"wood", Transform3D(Basis(), Vector3(0.27, 0.8, 0) - pivot), 0.028, 0.024, 0.28, 10, WOOD.lightened(0.1))
	MeshMerge.add_mesh(moving, runner.build(), Transform3D(Basis(), pivot))


# --- Sprinkler --------------------------------------------------------------------------------

## The scanned walking sprinkler, a little larger than life so it reads in the beds;
## its twin-arm spinner turns while watering.
static func _sprinkler(body: Array, moving: Array) -> void:
	_scan(body, "sprinkler", Transform3D.IDENTITY, 0.36, "", "spinner")
	_scan(moving, "sprinkler", Transform3D.IDENTITY, 0.36, "spinner")


# --- Coop kit --------------------------------------------------------------------------------

## The kit as it comes off the board: sawn boards and battens strapped into a bundle on
## two bearers, a roll of chicken wire on top and a sack of nails and hinges.
static func _coop_kit(out: Array) -> void:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for x: float in [-0.45, 0.45]:
		mb.box_at(&"wood", Vector3(x, 0.04, 0), Vector3(0.08, 0.08, 0.62), WOOD_DARK)
	for layer in 4:
		for k in 3:
			var z := -0.2 + k * 0.2
			var tone := WOOD.lightened(rng.randf_range(-0.04, 0.1))
			mb.box_at(&"planks", Vector3(rng.randf_range(-0.03, 0.03), 0.105 + layer * 0.052, z), Vector3(1.3, 0.048, 0.19), tone, Vector3.ZERO, true)
	# Battens on top.
	for k in 4:
		mb.box_at(&"wood", Vector3(0.05, 0.33, -0.18 + k * 0.12), Vector3(1.2, 0.045, 0.045), WOOD.lightened(0.06))
	# Two steel straps round the bundle.
	for x: float in [-0.38, 0.38]:
		mb.box_at(&"steel", Vector3(x, 0.215, 0.305), Vector3(0.035, 0.24, 0.006), IRON.lightened(0.15))
		mb.box_at(&"steel", Vector3(x, 0.215, -0.305), Vector3(0.035, 0.24, 0.006), IRON.lightened(0.15))
		mb.box_at(&"steel", Vector3(x, 0.357, 0), Vector3(0.035, 0.006, 0.62), IRON.lightened(0.15))
	# A roll of chicken wire and a sack of nails and hinges.
	# Lying across the bundle at one end (the cylinder's axis turned from +Y to +Z).
	mb.cylinder(&"galv", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.4, 0.49, -0.4)), 0.12, 0.12, 0.8, 14, Color(0.66, 0.68, 0.7))
	mb.cylinder(&"galv", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.4, 0.49, -0.41)), 0.05, 0.05, 0.82, 10, Color(0.3, 0.3, 0.3))
	mb.sphere(&"cloth", Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.38, 0.45, 0.05)), Vector3(0.14, 0.11, 0.12), 10, 7, Color(0.62, 0.52, 0.38))
	mb.cylinder(&"cloth", Transform3D(Basis(), Vector3(-0.38, 0.53, 0.05)), 0.04, 0.02, 0.07, 8, Color(0.55, 0.46, 0.34))
	_add(out, mb)
