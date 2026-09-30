class_name HeldPoses
extends RefCounted
## How the first-person view model holds each item at rest (camera space) and the point
## of the model the hand grips; HeldItem plays ToolAnim's strokes about that point.
## Kept free of autoloads so tools/tool_preview.gd can draw the poses on their own.

## Per-item rest pose in camera space: [position of the grip, rotation (deg), scale,
## optional grip point in model space (long tools: their origin; see grip_point)].
const POSES := {
	# Long tools: the handle rises from the hand with the head in the swing plane of their
	# stroke (ToolAnim "axis"): the axe's bit, the pick's point and the hoe's broad blade
	# face forward, so the stroke leads with them.
	&"axe": [Vector3(0.3, -0.42, -0.46), Vector3(12, 130, -22), 0.66],
	&"pickaxe": [Vector3(0.3, -0.42, -0.46), Vector3(8, 130, -22), 0.64],
	&"hoe": [Vector3(0.32, -0.46, -0.52), Vector3(-35.8, 38.3, -7.4), 0.56],
	# The snath runs forward and down, the blade lies across the view with its edge
	# toward the player, ready to sweep flat to the left.
	&"scythe": [Vector3(0.3, -0.32, -0.42), Vector3(80.7, 124.9, -68.9), 0.55],
	&"pitchfork": [Vector3(0.36, -0.47, -0.56), Vector3(-66, 4, 12), 0.54],
	# Gripped by its back handle, the spout pointing ahead (a little toward the aim).
	&"watering_can": [Vector3(0.3, -0.21, -0.5), Vector3(3.3, -159.6, 4.3), 0.75, Vector3(0.0, 0.19, -0.15)],
	# Hanging from the hand by its bail.
	&"milk_pail": [Vector3(0.38, -0.19, -0.7), Vector3(0, -20, 0), 0.8, Vector3(0.0, 0.36, 0.0)],
	# Shears point ahead with the blades flat; the brush's bristles face ahead, the hand
	# through its strap.
	&"shears": [Vector3(0.24, -0.24, -0.44), Vector3(-77.6, -26.6, 56.2), 1.0],
	&"brush": [Vector3(0.22, -0.21, -0.42), Vector3(60.4, -30.1, -31.5), 1.0, Vector3(0.0, 0.07, 0.0)],
	# Bulky goods are carried lower and further out, on their base.
	&"hay": [Vector3(0.3, -0.44, -0.74), Vector3(8, 25, 0), 0.78],
	&"flour": [Vector3(0.3, -0.46, -0.7), Vector3(6, 25, 0), 0.8],
	&"feed": [Vector3(0.3, -0.46, -0.7), Vector3(6, 25, 0), 0.8],
	&"dog_food": [Vector3(0.3, -0.44, -0.66), Vector3(4, 20, 0), 0.8],
	&"manure": [Vector3(0.3, -0.46, -0.7), Vector3(6, 25, 0), 0.8],
	&"fertilizer": [Vector3(0.3, -0.46, -0.72), Vector3(8, 25, 0), 0.8],
	&"milk": [Vector3(0.3, -0.46, -0.68), Vector3(4, 25, 0), 0.8],
	&"pumpkin": [Vector3(0.3, -0.44, -0.72), Vector3(8, 25, 0), 0.85],
	# Wood and stone: one piece in the hand, not the whole pile.
	&"wood": [Vector3(0.3, -0.4, -0.6), Vector3(12, 62, 6), 0.4],
	&"stone": [Vector3(0.3, -0.38, -0.58), Vector3(10, 30, 0), 0.5],
	# The fishing rod: held at the reel seat, low on the right, the rod rising ahead to the
	# left of centre, the reel hanging under it.
	&"fishing_rod": [Vector3(0.24, -0.34, -0.44), Vector3(0, -82, 55), 1.0, Vector3.ZERO],
	&"cane_rod": [Vector3(0.24, -0.34, -0.44), Vector3(0, -82, 55), 1.0, Vector3.ZERO],
	&"carbon_rod": [Vector3(0.24, -0.34, -0.44), Vector3(0, -82, 55), 1.0, Vector3.ZERO],
	&"carp_rod": [Vector3(0.24, -0.34, -0.44), Vector3(0, -82, 55), 1.0, Vector3.ZERO],
	# A crate of hens is carried in front with both hands, its long side across the view.
	&"chicken_crate": [Vector3(0.02, -0.46, -0.64), Vector3(4, 90, 0), 0.95],
	&"rooster_crate": [Vector3(0.02, -0.46, -0.64), Vector3(4, 90, 0), 0.95],
	# The knife point ahead and a little up and in, the flat of the blade to the side.
	&"knife": [Vector3(0.19, -0.19, -0.4), Vector3(-19.2, 95.3, -64.9), 1.0],
	# The bow in the left hand, upright and canted, turned to show its curve and string.
	&"bow": [Vector3(-0.17, -0.12, -0.62), Vector3(12.6, 59.3, -0.9), 0.62],
	# Small goods carried in the palm.
	&"rope": [Vector3(0.28, -0.3, -0.55), Vector3(24, 25, 0), 0.8],
	&"dough": [Vector3(0.27, -0.28, -0.5), Vector3(18, 25, 0), 0.9],
	&"worm": [Vector3(0.26, -0.26, -0.48), Vector3(22, 25, 0), 1.0],
	# The market's bait: a tin, a bucket, a lure in the palm.
	&"maggot": [Vector3(0.26, -0.26, -0.48), Vector3(22, 25, 0), 1.0],
	&"sweetcorn": [Vector3(0.26, -0.27, -0.48), Vector3(18, 25, 0), 1.0],
	&"cheese_bait": [Vector3(0.26, -0.26, -0.48), Vector3(24, 25, 0), 1.0],
	&"minnow": [Vector3(0.3, -0.4, -0.62), Vector3(8, 25, 0), 0.9],
	&"spinner": [Vector3(0.22, -0.2, -0.4), Vector3(30, 40, 0), 1.0],
	&"nails": [Vector3(0.26, -0.27, -0.48), Vector3(14, 25, 0), 1.0],
	# A sapling is carried upright by its root ball.
	&"sapling": [Vector3(0.28, -0.46, -0.62), Vector3(0, 20, 6), 0.85],
}
const DEFAULT_POSE := [Vector3(0.25, -0.24, -0.46), Vector3(12, 30, 0), 1.0]
const DEG := PI / 180.0
## The watering can's spout tip (the middle of the rose's face) and pouring direction (the
## axis of the spout and the rose, rising ~40 degrees) in its model space, measured on
## the scan; the spout points along +Z.
const SPOUT := Vector3(0.0, 0.227, 0.401)
const SPOUT_DIR := Vector3(0.0, 0.636, 0.772)


## Where the hand holds `id` in its model space: strokes turn the item about it. Long
## tools are gripped at their origin; other items by POSES' grip, else their center.
static func grip_point(id: StringName, mesh: Mesh) -> Vector3:
	var pose: Array = POSES.get(id, DEFAULT_POSE)
	if pose.size() > 3:
		return pose[3]
	if not POSES.has(id) and mesh:
		return mesh.get_aabb().get_center()
	return Vector3.ZERO


## The item's rest transform in camera space: its grip at the pose's position.
static func rest_pose(id: StringName, mesh: Mesh) -> Transform3D:
	var pose: Array = POSES.get(id, DEFAULT_POSE)
	var b := Basis.from_euler((pose[1] as Vector3) * DEG).scaled(Vector3.ONE * float(pose[2]))
	return Transform3D(b, (pose[0] as Vector3) - b * grip_point(id, mesh))


## `rest` moved by a stroke's offset: shifted by `pos` and turned by `rot` (camera space)
## about the hand at `grip`.
static func posed(rest: Transform3D, grip: Vector3, pos: Vector3, rot: Quaternion) -> Transform3D:
	var b := Basis(rot) * rest.basis
	return Transform3D(b, rest * grip + pos - b * grip)
