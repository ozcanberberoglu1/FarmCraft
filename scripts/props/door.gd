@tool
class_name Door
extends Node3D
## A hinged door: E opens and shuts it with a swing, and the shut leaf blocks the way
## (the swinging leaf pushes the player aside). The node sits on the hinge line at the
## foot of the leaf: the shut leaf runs `width` along +X with its outer face toward +Z,
## and opening swings it `open_angle` degrees toward -Z (into a room whose wall faces
## +Z). Whether it is open is kept in FarmState.flags[flag], so a rebuild (a house
## repair or upgrade) or a load finds it as it was.

## The door was opened (true) or shut (false).
signal toggled(open: bool)

## Every hinged door (tests, the tutorial).
const GROUP := &"doors"
## Leaf thickness (one layer of boards).
const LEAF_T := 0.035
## Grandpa's run-down house: grey boards, rusty iron.
const OLD := Color(0.5, 0.5, 0.49)
const OLD_DARK := Color(0.36, 0.33, 0.31)
const RUST := Color(0.36, 0.24, 0.16)
## The repaired house: oiled boards, black iron.
const OILED := Color(0.46, 0.42, 0.38)
const OILED_DARK := Color(0.38, 0.33, 0.29)
const IRON := Color(0.11, 0.11, 0.11)

## Leaf size.
@export var width := 1.25
@export var height := 2.24
## &"ruin": Grandpa's weathered ledged door (grey boards, one broken short and patched,
## rusty strap hinges and a ring pull, hanging a little crooked); &"plank": the repaired
## house's door of oiled boards with black strap hinges and a pull on each face.
@export var style: StringName = &"plank"
## Degrees the open leaf has turned about the hinge (negative: it swings out, to +Z).
@export var open_angle := 96.0
## Open when FarmState keeps no state for it yet.
@export var start_open := false
## Sent with Events.door_toggled.
@export var door_id: StringName = &""
## Key of its open state in FarmState.flags ("" = not kept).
@export var flag := ""

var _open := false
var _leaf: AnimatableBody3D
var _tween: Tween


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(GROUP)
	_open = start_open
	if not Engine.is_editor_hint() and flag != "":
		var kept: Variant = FarmState.flags.get(flag)
		if kept is bool:
			_open = kept
	_build()


func is_open() -> bool:
	return _open


## True while the leaf is swinging.
func is_moving() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## The pull on the leaf's outer face, wherever the leaf is.
func handle_point() -> Vector3:
	return _leaf.to_global(Vector3(width - 0.13, 1.02, LEAF_T + 0.03))


## A point on the leaf wherever it is: `local` in the leaf's own frame (x from the hinge
## along it, y up from its foot, z out from its inner face; its outer face at LEAF_T).
func leaf_point(local: Vector3) -> Vector3:
	return _leaf.to_global(local)


## Middle of the doorway at chest height (a waypoint target; it does not swing).
func waypoint_point() -> Vector3:
	return to_global(Vector3(width * 0.5, 1.2, LEAF_T * 0.5))


func interact_prompt(_player: Node) -> String:
	if is_moving():
		return ""
	return tr("ACTION_CLOSE") if _open else tr("ACTION_OPEN")


func interact(_player: Node) -> void:
	if is_moving() or Engine.is_editor_hint():
		return
	if _open and _doorway_blocked():
		Game.notify(tr("MSG_DOOR_BLOCKED"), UiTheme.RED)
		return
	set_open(not _open)


## Opens or shuts the door; `animate` false puts the leaf there at once.
func set_open(open: bool, animate := true) -> void:
	if open == _open and not is_moving():
		return
	_open = open
	if not Engine.is_editor_hint() and flag != "":
		FarmState.flags[flag] = open
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	# Before _ready there is no leaf yet (it is built from the flag).
	if _leaf and (not animate or not is_inside_tree()):
		_leaf.rotation.y = _angle(open)
	elif _leaf:
		_swing(open)
	toggled.emit(open)
	if not Engine.is_editor_hint():
		Events.door_toggled.emit(door_id, open)


func _angle(open: bool) -> float:
	return deg_to_rad(open_angle) if open else 0.0


## Swung in physics ticks, so the moving leaf pushes a player in its way aside.
func _swing(open: bool) -> void:
	var worn := style == &"ruin"
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if open:
		if worn:
			Audio.play("creak", handle_point(), -4.0, 0.12)
		else:
			Audio.play("door_open", handle_point(), -3.0)
		# An old door sticks a moment before it gives.
		if worn:
			_tween.tween_property(_leaf, "rotation:y", deg_to_rad(signf(open_angle) * 4.0), 0.22) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_leaf, "rotation:y", _angle(true), 1.05 if worn else 0.85) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	_tween.tween_property(_leaf, "rotation:y", 0.0, 0.62 if worn else 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_bang.bind(worn))
	# It bangs against the stop and settles back.
	_tween.tween_property(_leaf, "rotation:y", deg_to_rad(signf(open_angle) * 1.6), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_leaf, "rotation:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## The shut leaf meets the frame: a lower, looser thud for the old door.
func _bang(worn: bool) -> void:
	Audio.play("door_close", handle_point(), -3.0 if worn else -2.0, 0.1, &"Effects", 5.0, 0.85 if worn else 1.0)


## Someone (the player or an animal) stands where the shut leaf would be.
func _doorway_blocked() -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.1, height - 0.2, 0.5)
	q.shape = box
	q.transform = global_transform * Transform3D(Basis(), Vector3(width * 0.5, height * 0.5, LEAF_T * 0.5))
	q.collision_mask = 2 | 16
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_leaf = AnimatableBody3D.new()
	_leaf.name = "Leaf"
	# Blocks the player and the ray (layer 3 finds the Door one parent up).
	_leaf.collision_layer = 1 | 4
	_leaf.collision_mask = 0
	_leaf.sync_to_physics = true
	# Swung in physics ticks: drawn between them (see Settings._ready).
	_leaf.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	# Posed before it enters the tree, so it starts there without a swing.
	_leaf.rotation.y = _angle(_open)
	var mb := MeshBuilder.new()
	if style == &"ruin":
		_ruin_leaf(mb)
	else:
		_plank_leaf(mb)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.build()
	# It swings: kept out of SDFGI's static voxels, which would keep a stale shut door.
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_leaf.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, LEAF_T)
	cs.shape = shape
	cs.position = Vector3(width * 0.5, height * 0.5, LEAF_T * 0.5)
	_leaf.add_child(cs)
	add_child(_leaf)


## Grandpa's door: seven grey boards on two ledges and a brace, with light between them,
## one broken short and patched with a scrap board. It has dropped on its hinges, so
## the mesh hangs a degree off square (the collider stays true).
func _ruin_leaf(mb: MeshBuilder) -> void:
	var pivot := Vector3(0, height - 0.25, 0)
	var sag := Transform3D(Basis(Vector3.BACK, deg_to_rad(-1.0)), pivot) * Transform3D(Basis(), -pivot)
	var boards := 7
	var step := (width - 0.03) / boards
	for k in boards:
		# Rotted uneven at the foot; the fifth board broke off half a metre up.
		var y0 := 0.5 if k == 4 else 0.035 + 0.018 * (k % 3)
		var top := height - (0.045 if k == 6 else 0.0)
		var hh := top - y0
		var x := 0.03 + (k + 0.5) * step
		BuildingKit.plank(mb, &"planks_old", sag * Transform3D(Basis(), Vector3(x, y0 + hh * 0.5, LEAF_T * 0.5)),
				Vector3(BuildingKit.BOARD_H, hh, LEAF_T), _shade(OLD, 0.84 + 0.05 * (k % 3)),
				Vector2(0.3 * k, BuildingKit.BOARD_SEAM + ((k * 5) % 13) * BuildingKit.BOARD_H), true)
	# Scrap board nailed over the hole, askew, with two rusty nail heads.
	var patch := sag * Transform3D(Basis(Vector3.BACK, deg_to_rad(7.0)), Vector3(0.03 + 4.5 * step + 0.02, 0.27, LEAF_T + 0.011))
	BuildingKit.plank(mb, &"planks_old", patch, Vector3(0.44, BuildingKit.BOARD_H * 0.8, 0.022), _shade(OLD, 0.72),
			Vector2(1.3, BuildingKit.BOARD_SEAM + 7 * BuildingKit.BOARD_H))
	for nx: float in [-0.17, 0.17]:
		mb.box(&"rusty", patch * Transform3D(Basis(), Vector3(nx, 0, 0.012)), Vector3(0.012, 0.012, 0.004), RUST)
	# Ledges and the brace on the inside face, clear of the jamb when the door is open.
	for ly: float in [0.35, height - 0.4]:
		mb.box(&"wood_old_in", sag * Transform3D(Basis(), Vector3(0.08 + (width - 0.12) * 0.5, ly, -0.0175)),
				Vector3(width - 0.12, 0.12, LEAF_T), OLD_DARK, true)
	BuildingKit.beam(mb, &"wood_old_in", sag * Vector3(0.16, 0.44, -0.0175), sag * Vector3(width - 0.14, height - 0.49, -0.0175),
			Vector2(0.11, LEAF_T), OLD_DARK, true)
	# Rusty strap hinges outside, the knuckles on the hinge line.
	for hy: float in [0.35, height - 0.4]:
		_strap(mb, sag, hy, &"rusty", RUST, 0.52)
	# Ring pull outside; a wooden latch bar in a staple inside.
	var pull := Vector3(width - 0.13, 1.02, LEAF_T)
	mb.box(&"rusty", sag * Transform3D(Basis(), pull + Vector3(0, 0.02, 0.003)), Vector3(0.07, 0.1, 0.006), RUST)
	mb.ring(&"rusty", sag * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pull + Vector3(0, -0.035, 0.014)), 0.046, 0.036, 0.009, 12,
			_shade(RUST, 0.9))
	mb.box(&"wood_old_in", sag * Transform3D(Basis(Vector3.BACK, deg_to_rad(-3.0)), Vector3(width - 0.24, 1.02, -0.016)),
			Vector3(0.34, 0.05, 0.032), _shade(OLD_DARK, 1.15))
	mb.box(&"rusty", sag * Transform3D(Basis(), Vector3(width - 0.33, 1.02, -0.036)), Vector3(0.028, 0.08, 0.01), RUST)


## The repaired door: seven oiled boards on two ledges and a brace, black strap hinges,
## an iron pull on each face and a thumb latch.
func _plank_leaf(mb: MeshBuilder) -> void:
	var xf := Transform3D.IDENTITY
	var boards := 7
	var step := width / boards
	for k in boards:
		var x := (k + 0.5) * step
		# Centre one board of the photo on each (it is a little narrower than the step).
		var uv := Vector2(0.3 * k, BuildingKit.BOARD_SEAM + ((k * 5) % 13) * BuildingKit.BOARD_H - (step - BuildingKit.BOARD_H) * 0.5)
		BuildingKit.plank(mb, &"planks", Transform3D(Basis(), Vector3(x, height * 0.5, LEAF_T * 0.5)),
				Vector3(step - 0.002, height, LEAF_T), _shade(OILED, 0.95 + 0.04 * (k % 3)), uv, true)
	for ly: float in [0.3, height - 0.35]:
		mb.box(&"wood_in", Transform3D(Basis(), Vector3(0.08 + (width - 0.12) * 0.5, ly, -0.0175)), Vector3(width - 0.12, 0.13, LEAF_T),
				OILED_DARK, true)
	BuildingKit.beam(mb, &"wood_in", Vector3(0.16, 0.4, -0.0175), Vector3(width - 0.14, height - 0.44, -0.0175), Vector2(0.12, LEAF_T),
			OILED_DARK, true)
	for hy: float in [0.3, height - 0.35]:
		_strap(mb, xf, hy, &"metal", IRON, 0.62)
	# D pulls outside and inside, and the latch bar over the inside pull.
	for side: float in [1.0, -1.0]:
		var z := LEAF_T if side > 0.0 else 0.0
		var c := Vector3(width - 0.13, 1.02, z)
		mb.loft(&"metal", [c + Vector3(0, 0.08, 0), c + Vector3(0, 0.07, side * 0.045), c + Vector3(0, -0.07, side * 0.045),
				c + Vector3(0, -0.08, 0)], [0.009, 0.009, 0.009, 0.009], 6, IRON)
		for py: float in [0.08, -0.08]:
			mb.box_at(&"metal", c + Vector3(0, py, side * 0.003), Vector3(0.03, 0.05, 0.006), IRON)
	mb.box_at(&"metal", Vector3(width - 0.2, 1.16, -0.008), Vector3(0.26, 0.022, 0.012), IRON)


## A strap hinge on the outer face at height `y`: a tapering iron strap over the boards
## and its knuckle on the hinge line.
func _strap(mb: MeshBuilder, xf: Transform3D, y: float, key: StringName, color: Color, length: float) -> void:
	var z := LEAF_T + 0.004
	mb.box(key, xf * Transform3D(Basis(), Vector3(length * 0.3, y, z)), Vector3(length * 0.6, 0.05, 0.007), color)
	mb.box(key, xf * Transform3D(Basis(), Vector3(length * 0.78, y, z)), Vector3(length * 0.44, 0.034, 0.007), color)
	mb.cylinder(key, xf * Transform3D(Basis(), Vector3(0.0, y - 0.07, LEAF_T + 0.01)), 0.013, 0.013, 0.14, 8, _shade(color, 0.85))
	for nx: float in [0.1, length * 0.45, length * 0.9]:
		mb.box(key, xf * Transform3D(Basis(), Vector3(nx, y, z + 0.004)), Vector3(0.012, 0.012, 0.004), _shade(color, 0.7))


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f)
