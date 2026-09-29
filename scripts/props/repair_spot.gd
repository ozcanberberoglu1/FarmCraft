class_name RepairSpot
extends StaticBody3D
## One broken stretch of a run-down building's wall (Grandpa's house or warehouse at
## level 0): a hole through the old boards. With wood in hand, LMB nails fresh boards
## over it for one wood: the wall shudders under the blows, the boards knock, and the
## new planks stay. Aimed at without wood it says what it needs; a patched spot offers
## nothing. Which spots are done is kept in FarmState.flags (flag_key()), so a load or
## a rebuild shows them. The last spot of a building repairs it: its level-1 project
## is built at no cost (dust, the building rebuilt sound) and Events.building_repaired
## is sent. The building's Guide keeps its waypoint anchor on the nearest open spot.

## Every spot is in this group (patched or not).
const GROUP := &"repair_spots"
## The project the hands-on repair builds, by building id.
const PROJECTS := {&"house": &"house_1", &"warehouse": &"warehouse_1"}
## Waypoint anchor ids (WaypointMarker.tag), by building id.
const ANCHORS := {&"house": &"house_repair", &"warehouse": &"warehouse_repair"}
## Seconds from the last board to the repair: the knock and the shudder play out first.
const REPAIR_DELAY := 0.5
## Fresh boards: tint of the planks photo (new sawn pine, not yet greyed).
const FRESH := Color(0.64, 0.59, 0.5)
## How far the new boards reach past the hole on each side, and their thickness.
const OVERLAP := Vector2(0.15, 0.07)
const BOARD_T := 0.024

## &"house" or &"warehouse".
var building_id: StringName
## Its place among the building's spots (what FarmState.flags remembers).
var index := 0
## Spots of the building in all.
var total := 1
## The hole on the wall: width along it, height.
var size := Vector2(0.6, 0.6)
## Shudders with each blow (the building's wall mesh, a sibling in the same space).
var shake_node: Node3D
var patched := false

var _patch: MeshInstance3D
## An old board hanging across the hole from one nail (it rattles with each blow and
## is gone once patched); its origin is the nail.
var _loose: MeshInstance3D
var _shake_tween: Tween
var _rattle: Tween
var _shake_rest := Vector3.ZERO


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Just proud of the wall's face, so the aim ray finds it before the wall behind.
	box.size = Vector3(size.x + 0.16, size.y + 0.16, 0.08)
	cs.shape = box
	cs.position = Vector3(0, 0, 0.03)
	add_child(cs)
	if shake_node:
		_shake_rest = shake_node.position
	patched = is_patched(building_id, index)
	add_to_group(GROUP)
	if patched:
		_set_done()
	else:
		add_to_group(&"interactable")
		_add_loose_board()


## Adds a spot for each [{xf: frame on the wall (BuildingKit.opening_frame), size}] of
## `building` under `parent`, and the Guide that keeps its waypoint anchor, while the
## building still needs them. `shake` is its wall mesh (in `parent`'s space).
static func add_all(parent: Node3D, building: StringName, spots: Array[Dictionary], shake: Node3D) -> void:
	for i in spots.size():
		var s := RepairSpot.new()
		s.name = "Repair_%d" % i
		s.building_id = building
		s.index = i
		s.total = spots.size()
		s.size = spots[i]["size"]
		s.transform = spots[i]["xf"]
		s.shake_node = shake
		parent.add_child(s)
	if patched_count(building) < spots.size():
		var guide := Guide.new()
		guide.name = "RepairGuide"
		guide.building_id = building
		parent.add_child(guide)
		guide.refresh()
	elif not spots.is_empty():
		# Saved between the last board and the repair: finish it now.
		_repair_later(building)


static func flag_key(building: StringName) -> String:
	return "patched_%s" % building


## Indices of the building's spots that were patched.
static func patched_indices(building: StringName) -> Array:
	var out := []
	var v: Variant = FarmState.flags.get(flag_key(building))
	if v is Array:
		for i: Variant in v:
			out.append(int(i))
	return out


static func is_patched(building: StringName, i: int) -> bool:
	return patched_indices(building).has(i)


static func patched_count(building: StringName) -> int:
	return patched_indices(building).size()


## How many spots the building has (0 when it has none now: repaired, or not built).
static func spot_count(building: StringName) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	for n: Node in tree.get_nodes_in_group(GROUP):
		var s := n as RepairSpot
		if s and s.building_id == building and not s.is_queued_for_deletion():
			return s.total
	return 0


## The building a hands-on project repairs (&"" for other projects).
static func building_of(project: StringName) -> StringName:
	for b: StringName in PROJECTS:
		if PROJECTS[b] == project:
			return b
	return &""


## The building's open spot nearest `from` (the player), or null when all are done.
static func nearest_open(building: StringName, from: Vector3) -> RepairSpot:
	var tree := Engine.get_main_loop() as SceneTree
	var best: RepairSpot = null
	var best_d := INF
	for n: Node in tree.get_nodes_in_group(GROUP):
		var s := n as RepairSpot
		if s == null or s.building_id != building or s.patched or s.is_queued_for_deletion():
			continue
		var d := s.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = s
	return best


func interact_prompt(_player: Node) -> String:
	return ""


func use_prompt(player: Node, stack: ItemStack) -> String:
	var a := use_action(player, stack)
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if patched or stack == null or stack.item.id != &"wood":
		return {}
	return {"id": "patch", "verb": "ACTION_PATCH_WALL", "label": "PROGRESS_PATCHING", "duration": 1.0}


## Without wood in hand: what the hole needs.
func hint_prompt() -> String:
	if patched:
		return ""
	var stack := PlayerState.selected_stack()
	return "" if stack and stack.item.id == &"wood" else tr("HINT_PATCH_NEEDS_WOOD")


## A blow landing (the look and sound only): splinters and dust off the old boards, a
## knock, the wall shuddering and a small punch of the view.
func use_impact(player: Node, _stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	var out := global_basis.z
	var final: bool = hit.get("final", false)
	var at: Vector3 = hit.get("point", global_position + out * 0.05)
	Fx.wood_chips(at, out)
	Audio.play("plank", at, -4.0 if final else -7.0, 0.1, &"Effects", 5.0, 1.1)
	if final:
		Audio.play("wood_hit", at, -6.0, 0.08, &"Effects", 5.0, 1.3)
	_shake(0.012 if final else 0.007)
	_rattle_loose(4.0 if final else 2.5)
	if player is Player:
		(player as Player).kick_view(Vector4(-0.5, 0.0, 0.3, -0.008) * (1.0 if final else 0.6))


## The boards are on: one wood used, the spot remembered, and the building repaired
## when it was the last one.
func complete_use(_player: Node, _stack: ItemStack, _action: Dictionary) -> void:
	if patched or not PlayerState.inventory.remove_item(&"wood", 1):
		return
	var done := patched_indices(building_id)
	if not done.has(index):
		done.append(index)
	FarmState.flags[flag_key(building_id)] = done
	_set_done(true)
	Events.wall_patched.emit(building_id, done.size(), total)
	if done.size() >= total:
		_repair_later(building_id)


## Repairs `building` now (its level-1 project, at no cost): the farm raises the dust
## and rebuilds it. Returns false when it was already repaired.
static func repair(building: StringName) -> bool:
	var project: StringName = PROJECTS.get(building, &"")
	if project == &"" or FarmState.is_built(project):
		return false
	if not FarmState.build(project):
		# The story's repair never waits on a farm level.
		FarmState.built[project] = true
		FarmState.project_built.emit(project)
	Events.building_repaired.emit(building)
	return true


## In a static function, so the timer holds no spot (the repair frees them all).
static func _repair_later(building: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(REPAIR_DELAY, false).timeout.connect(func() -> void: RepairSpot.repair(building))


func _set_done(animate := false) -> void:
	patched = true
	remove_from_group(&"interactable")
	collision_layer = 0
	if _loose:
		_loose.queue_free()
		_loose = null
	_patch = MeshInstance3D.new()
	_patch.name = "Patch"
	_patch.mesh = _patch_mesh()
	# Slammed on by a tween outside the physics step.
	_patch.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_patch)
	if animate:
		_patch.position = Vector3(0, 0, 0.05)
		var tw := create_tween()
		tw.tween_property(_patch, "position", Vector3.ZERO, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The broken board: split off at one end, hanging from a nail by the hole's top corner
## down across it, pulled a little off the wall.
func _add_loose_board() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(building_id) + index * 71
	var side := 1.0 if index % 2 == 0 else -1.0
	var nail := Vector3(-side * (size.x * 0.5 + 0.1), size.y * 0.5 - 0.06, 0.018)
	var tip := Vector3(side * (size.x * 0.5 - 0.08), -size.y * 0.5 + rng.randf_range(0.08, 0.2), 0.034)
	var mb := MeshBuilder.new()
	var v := rng.randf_range(0.82, 0.95)
	BuildingKit.beam(mb, &"planks_old", Vector3(-side * 0.06, 0.02, 0), tip - nail, Vector2(BuildingKit.BOARD_H - 0.01, 0.026),
			Color(0.45 * v, 0.45 * v, 0.44 * v), false, 0.0, Vector2(rng.randf() * 2.2, BuildingKit.BOARD_SEAM + rng.randi_range(0, 12) * BuildingKit.BOARD_H))
	mb.box(&"rusty", Transform3D(Basis(), Vector3(0, 0, 0.016)), Vector3(0.014, 0.014, 0.01), Color(0.3, 0.2, 0.14))
	_loose = MeshInstance3D.new()
	_loose.name = "LooseBoard"
	_loose.mesh = mb.build()
	_loose.position = nail
	# Rattled by a tween outside the physics step.
	_loose.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_loose)


## Fresh horizontal boards across the hole, lapped like the old siding and reaching
## OVERLAP past it onto the sound boards, two nails at each end.
func _patch_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(building_id) + index * 131
	var bh := BuildingKit.BOARD_H
	var rows := ceili((size.y + OVERLAP.y * 2.0) / bh)
	var y0 := -rows * bh * 0.5
	var z := BOARD_T * 0.5 + 0.008
	for k in rows:
		var length := size.x + OVERLAP.x * 2.0 + rng.randf_range(-0.05, 0.16)
		var shift := rng.randf_range(-0.08, 0.08)
		var tilt := Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-1.2, 1.2))) * Basis(Vector3.RIGHT, -0.03)
		var xf := Transform3D(tilt, Vector3(shift, y0 + (k + 0.5) * bh, z + 0.002 * (k % 2)))
		var v := rng.randf_range(0.93, 1.06)
		BuildingKit.plank(mb, &"planks", xf, Vector3(length, bh - 0.006, BOARD_T), Color(FRESH.r * v, FRESH.g * v, FRESH.b * v),
				Vector2(rng.randf() * 2.2, BuildingKit.BOARD_SEAM + rng.randi_range(0, 12) * bh))
		for end: float in [-1.0, 1.0]:
			for ny: float in [-0.035, 0.035]:
				var nail := xf * Vector3(end * (length * 0.5 - 0.05), ny, BOARD_T * 0.5 + 0.002)
				mb.box(&"steel", Transform3D(xf.basis, nail), Vector3(0.011, 0.011, 0.006), Color(0.3, 0.29, 0.28))
	return mb.build()


## The wall jumps out along its face and back, dying away (in physics steps, so the
## interpolated wall mesh moves smoothly).
func _shake(amount: float) -> void:
	if shake_node == null or not is_instance_valid(shake_node):
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var out := transform.basis.z
	shake_node.position = _shake_rest
	_shake_tween = shake_node.create_tween()
	_shake_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_shake_tween.tween_property(shake_node, "position", _shake_rest - out * amount, 0.03)
	_shake_tween.tween_property(shake_node, "position", _shake_rest + out * amount * 0.55, 0.05)
	_shake_tween.tween_property(shake_node, "position", _shake_rest - out * amount * 0.25, 0.05)
	_shake_tween.tween_property(shake_node, "position", _shake_rest, 0.06)


## The loose board swings on its nail and settles (degrees of the first swing).
func _rattle_loose(degrees: float) -> void:
	if _loose == null:
		return
	if _rattle and _rattle.is_valid():
		_rattle.kill()
	_loose.rotation = Vector3.ZERO
	var r := deg_to_rad(degrees)
	_rattle = create_tween()
	_rattle.tween_property(_loose, "rotation:z", r, 0.04)
	_rattle.tween_property(_loose, "rotation:z", -r * 0.6, 0.08)
	_rattle.tween_property(_loose, "rotation:z", r * 0.25, 0.08)
	_rattle.tween_property(_loose, "rotation:z", 0.0, 0.1)


## Keeps the building's waypoint anchor (ANCHORS) on the open spot nearest the player,
## a hand's width off the wall; untags itself once every spot is patched.
class Guide extends Marker3D:
	const EVERY := 0.25

	var building_id: StringName
	var _wait := 0.0

	func _ready() -> void:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		WaypointMarker.tag(self, RepairSpot.ANCHORS.get(building_id, &""))

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0:
			_wait = EVERY
			refresh()

	func refresh() -> void:
		if not is_inside_tree():
			return
		var from := Vector3.ZERO
		if Game.player and is_instance_valid(Game.player):
			from = (Game.player as Node3D).global_position
		var spot := RepairSpot.nearest_open(building_id, from)
		if spot == null:
			remove_from_group(WaypointMarker.ANCHOR_GROUP)
			set_process(false)
			return
		global_position = spot.global_position + spot.global_basis.z * 0.1


## The "needs repair" sign by a run-down building: how it is mended (wood nailed over
## the holes in its walls) and how many holes are done. Nothing to open: the board
## doesn't sell the repair.
class Sign extends ForSaleSign:
	var building_id: StringName

	func _ready() -> void:
		super()
		Events.wall_patched.connect(_on_wall_patched)
		# The building's spots are up by the end of this frame.
		refresh.call_deferred()

	func refresh() -> void:
		if _title == null:
			return
		_title.text = tr("SIGN_REPAIR_WALLS")
		var total := RepairSpot.spot_count(building_id)
		_price.text = "%d / %d" % [RepairSpot.patched_count(building_id), total] if total > 0 else ""

	func interact_prompt(_player: Node) -> String:
		return ""

	func interact(_player: Node) -> void:
		pass

	func _on_wall_patched(id: StringName, _done: int, _total: int) -> void:
		if id == building_id:
			refresh()
