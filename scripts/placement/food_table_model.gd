@tool
class_name FoodTableModel
extends RefCounted
## The food table's model (PlaceableModels "food_table"): a heavy butcher's table of
## weathered planks on square legs with rails and a slatted shelf; a thick end-grain
## chopping board on the top (FoodTable lays the catch on it at BOARD), a scanned wooden
## bowl of water to rinse in, a galvanised offal pail on the shelf, a back rail with hooks,
## a whetstone and a pinch of salt. Stands on the ground at the origin, front toward +Z.

const WOOD := Color(0.55, 0.5, 0.45)
const WOOD_DARK := Color(0.42, 0.37, 0.33)
const TOP := 0.86
## The board's top: where the catch lies (its middle), and the board's size.
const BOARD := Vector3(-0.14, 0.955, 0.07)
const BOARD_SIZE := Vector3(0.62, 0.075, 0.4)
## The offal pail's mouth (the heads go in there).
const PAIL := Vector3(0.5, 0.48, 0.02)
const BOWL := "res://art/models/items/wooden_bowl_01/wooden_bowl_01_1k.gltf"


static func build(out: Array) -> void:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	# Legs, rails and stretchers.
	for x: float in [-0.72, 0.72]:
		for z: float in [-0.3, 0.3]:
			mb.box_at(&"wood", Vector3(x, (TOP - 0.02) * 0.5, z), Vector3(0.085, TOP - 0.02, 0.085), WOOD_DARK)
	for z: float in [-0.3, 0.3]:
		mb.box_at(&"wood", Vector3(0, TOP - 0.1, z), Vector3(1.38, 0.09, 0.045), WOOD_DARK)
		mb.box_at(&"wood", Vector3(0, 0.3, z), Vector3(1.38, 0.06, 0.045), WOOD_DARK)
	for x: float in [-0.72, 0.72]:
		mb.box_at(&"wood", Vector3(x, TOP - 0.1, 0), Vector3(0.045, 0.09, 0.56), WOOD_DARK)
		mb.box_at(&"wood", Vector3(x, 0.3, 0), Vector3(0.045, 0.06, 0.56), WOOD_DARK)
	# The slatted shelf.
	for i in 6:
		mb.box_at(&"planks", Vector3(-0.6 + i * 0.24, 0.345, 0), Vector3(0.21, 0.025, 0.62), WOOD.darkened(0.06))
	# The top: four thick planks, a little uneven, their ends proud of the frame.
	for i in 4:
		var z := -0.285 + i * 0.19
		mb.box_at(&"planks", Vector3(rng.randf_range(-0.01, 0.01), TOP + 0.03, z), Vector3(1.6, 0.06, 0.185),
				WOOD.lightened(rng.randf_range(-0.04, 0.06)), Vector3(0, rng.randf_range(-0.4, 0.4), 0))
	# The chopping board, end grain up, a groove worn round its edge.
	var b := BOARD - Vector3(0, BOARD_SIZE.y * 0.5, 0)
	mb.box_at(&"endgrain", b, BOARD_SIZE, Color(0.62, 0.55, 0.47))
	mb.box_at(&"endgrain", b + Vector3(0, BOARD_SIZE.y * 0.5 + 0.001, 0), Vector3(BOARD_SIZE.x - 0.05, 0.002, BOARD_SIZE.z - 0.05),
			Color(0.5, 0.4, 0.34))
	# A whetstone and a pinch of coarse salt by the board.
	mb.box_at(&"stone", Vector3(0.28, TOP + 0.075, 0.2), Vector3(0.2, 0.03, 0.05), Color(0.46, 0.44, 0.42), Vector3(0, 12, 0))
	for i in 14:
		var p := Vector3(0.3 + rng.randf_range(-0.05, 0.05), TOP + 0.062, 0.04 + rng.randf_range(-0.04, 0.04))
		mb.box_at(&"veg", p, Vector3.ONE * rng.randf_range(0.004, 0.007), Color(0.93, 0.93, 0.9), Vector3(rng.randf() * 90, rng.randf() * 90, 0))
	# The back rail on two posts, with S-hooks.
	var bz := -0.36
	for x: float in [-0.72, 0.72]:
		mb.box_at(&"wood", Vector3(x, TOP + 0.35, bz), Vector3(0.06, 0.64, 0.06), WOOD_DARK)
	mb.cylinder_between(&"wood", Vector3(-0.75, TOP + 0.62, bz), Vector3(0.75, TOP + 0.62, bz), 0.018, 0.018, 10, WOOD_DARK)
	for x: float in [-0.45, -0.3, 0.18]:
		mb.ring(&"steel", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, TOP + 0.6, bz)), 0.022, 0.017, 0.005, 10, Color(0.4, 0.4, 0.41))
		mb.cylinder_between(&"steel", Vector3(x, TOP + 0.58, bz), Vector3(x, TOP + 0.5, bz + 0.01), 0.003, 0.003, 6, Color(0.4, 0.4, 0.41))
		mb.ring(&"steel", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, TOP + 0.49, bz + 0.012)), 0.018, 0.014, 0.005, 10, Color(0.4, 0.4, 0.41))
	# The offal pail on the shelf: galvanised, a rolled rim, a wire bail laid back.
	var pail := PAIL - Vector3(0, 0.13, 0)
	mb.ring(&"galv", Transform3D(Basis(), pail), 0.12, 0.113, 0.13, 18, Color(0.6, 0.62, 0.63))
	mb.disc(&"galv", Transform3D(Basis(), pail + Vector3(0, 0.004, 0)), 0.114, 18, Color(0.5, 0.52, 0.53))
	mb.ring(&"galv", Transform3D(Basis(), pail + Vector3(0, 0.124, 0)), 0.127, 0.113, 0.012, 18, Color(0.66, 0.68, 0.69))
	mb.disc(&"veg_gloss", Transform3D(Basis(), pail + Vector3(0, 0.035, 0)), 0.112, 18, Color(0.24, 0.06, 0.05))
	mb.cylinder_between(&"steel", pail + Vector3(-0.13, 0.11, 0), pail + Vector3(-0.1, 0.02, -0.12), 0.003, 0.003, 5, Color(0.35, 0.35, 0.36))
	mb.cylinder_between(&"steel", pail + Vector3(0.13, 0.11, 0), pail + Vector3(0.1, 0.02, -0.12), 0.003, 0.003, 5, Color(0.35, 0.35, 0.36))
	mb.cylinder_between(&"steel", pail + Vector3(-0.1, 0.02, -0.12), pail + Vector3(0.1, 0.02, -0.12), 0.003, 0.003, 5, Color(0.35, 0.35, 0.36))
	# Water in the rinsing bowl.
	var bowl_at := Vector3(0.5, TOP + 0.06, -0.08)
	mb.disc(&"water_still", Transform3D(Basis(), bowl_at + Vector3(0, 0.052, 0)), 0.1, 20, Color(0.32, 0.36, 0.34))
	MeshMerge.add_mesh(out, mb.build())
	_bowl(out, bowl_at, 0.26)


## The scanned wooden bowl, `size` across, standing on `at`.
static func _bowl(out: Array, at: Vector3, size: float) -> void:
	if not ResourceLoader.exists(BOWL):
		return
	var parts := MeshMerge.scene_parts(load(BOWL) as PackedScene)
	var box := MeshMerge.bounds(parts)
	var s := size / maxf(maxf(box.size.x, box.size.z), 0.001)
	var base := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	MeshMerge.add_parts(out, parts, Transform3D(Basis.from_scale(Vector3.ONE * s), at - base * s))
