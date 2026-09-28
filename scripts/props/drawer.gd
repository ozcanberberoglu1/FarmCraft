@tool
class_name Drawer
extends Node3D
## A drawer that slides out of a desk or table with E, showing what lies in it:
## WorldItems put in with put(), which E can take only while it is out. The node sits
## on the back face of the drawer's front, shut, at the middle of the front; the box
## runs back along -Z and slides out toward +Z, `travel` far. Whether it is out is kept
## in FarmState.flags[flag], so a rebuild or a load finds it as it was.
## The furniture around it keeps its colliders behind the front's face: the front's
## ray box (layer 3) stands a little proud of it, so the ray finds the drawer first.

## The drawer was pulled out (true) or pushed in (false).
signal toggled(open: bool)

## Every drawer (tests, the tutorial).
const GROUP := &"drawers"
const WOOD := Color(0.48, 0.42, 0.36)
const WOOD_OLD := Color(0.43, 0.41, 0.39)
const BRASS := Color(0.66, 0.52, 0.3)
const RUST := Color(0.36, 0.24, 0.16)

## Inside of the box: width (X), height (Y), depth (Z, back from the front).
@export var size := Vector3(0.5, 0.09, 0.4)
## The front panel: how far it laps over the opening all round, and its thickness.
@export var front_lap := 0.018
@export var front_t := 0.022
## How far it slides out.
@export var travel := 0.28
## Grandpa's run-down house: grey wood and a rusty knob.
@export var worn := false
## Sent with Events.drawer_opened.
@export var drawer_id: StringName = &""
## Key of its open state in FarmState.flags ("" = not kept).
@export var flag := ""
## While FarmState.flags[lock_flag] is true it stays shut and shows no prompt.
@export var lock_flag := ""
## Height above the origin of the top of the ray box (the underside of the top above
## it), so a look at the top edge of the front still finds the drawer.
@export var reach_up := 0.06
## How far the ray box stands out in front of the front's face (to clear the top's edge).
@export var reach_out := 0.03

var _open := false
var _slide: Node3D
var _front: StaticBody3D
var _items: Array = []
var _tween: Tween


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(GROUP)
	if not Engine.is_editor_hint() and flag != "":
		var kept: Variant = FarmState.flags.get(flag)
		if kept is bool:
			_open = kept
	_build()
	for it in items():
		it.set_enabled(_open)
		if it.get_parent() == null:
			_slide.add_child(it)


func is_open() -> bool:
	return _open


func is_moving() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Shut and not openable yet (the story has not come to it).
func is_locked() -> bool:
	if Engine.is_editor_hint() or lock_flag == "":
		return false
	var v: Variant = FarmState.flags.get(lock_flag)
	return v is bool and v


## The knob, wherever the drawer is (a waypoint target).
func waypoint_point() -> Vector3:
	var at := Vector3(0, 0, front_t + 0.02)
	return _slide.to_global(at) if _slide else to_global(at)


## Lays `item` on the drawer's bottom at `at` (x across, y from the front back), turned
## `yaw_deg` about the vertical. E can take it only while the drawer is out.
func put(item: WorldItem, at: Vector2, yaw_deg := 0.0) -> void:
	item.position = Vector3(at.x, -size.y * 0.5 + 0.008, -at.y)
	item.rotation.y = deg_to_rad(yaw_deg)
	item.set_enabled(_open)
	_items.append(item)
	if _slide:
		_slide.add_child(item)


## The WorldItems still in it (not those already taken and flying to the hand).
func items() -> Array[WorldItem]:
	var out: Array[WorldItem] = []
	for it in _items:
		if is_instance_valid(it) and not (it as Node).is_queued_for_deletion() and not (it as WorldItem).is_gone():
			out.append(it as WorldItem)
	return out


func interact_prompt(_player: Node) -> String:
	if is_moving() or is_locked():
		return ""
	return tr("ACTION_CLOSE") if _open else tr("ACTION_OPEN")


func interact(_player: Node) -> void:
	if is_moving() or is_locked() or Engine.is_editor_hint():
		return
	set_open(not _open)


## Pulls it out or pushes it in; `animate` false puts it there at once.
func set_open(open: bool, animate := true) -> void:
	if open == _open and not is_moving():
		return
	_open = open
	if not Engine.is_editor_hint() and flag != "":
		FarmState.flags[flag] = open
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	# What lies in it can be reached as soon as it moves out, not once it has gone in.
	for it in items():
		it.set_enabled(open)
	var z := travel if open else 0.0
	# Before _ready there is no slide yet (it is built where _open says).
	if _slide and (not animate or not is_inside_tree()):
		_slide.position.z = z
	elif _slide:
		_tween = create_tween()
		if open:
			_tween.tween_property(_slide, "position:z", z, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		else:
			_tween.tween_property(_slide, "position:z", z, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Wood on wood: a short scrape, lower for the old one.
		Audio.play("plank", waypoint_point(), -12.0 if open else -9.0, 0.1, &"Effects", 5.0,
				(1.35 if worn else 1.55) if open else 1.3)
	toggled.emit(open)
	if open and not Engine.is_editor_hint():
		Events.drawer_opened.emit(drawer_id)


func _build() -> void:
	_slide = Node3D.new()
	_slide.name = "Slide"
	# A tween slides it every frame, not in physics steps.
	_slide.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_slide.position.z = travel if _open else 0.0
	add_child(_slide)
	var mb := MeshBuilder.new()
	var key: StringName = &"wood_old_in" if worn else &"wood_in"
	var wood := WOOD_OLD if worn else WOOD
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	# Front panel over the opening, with a knob.
	mb.box_at(key, Vector3(0, 0, front_t * 0.5), Vector3(size.x + front_lap * 2.0, size.y + front_lap * 2.0, front_t), wood)
	if worn:
		# The knob came off long ago; a bent nail and a loop of twine do instead.
		mb.box_at(&"rusty", Vector3(0, 0.004, front_t + 0.012), Vector3(0.005, 0.005, 0.026), RUST)
		mb.cylinder_between(&"cloth", Vector3(-0.012, 0.004, front_t + 0.022), Vector3(0.012, -0.018, front_t + 0.026), 0.0025, 0.0025, 5,
				Color(0.62, 0.55, 0.42))
		mb.cylinder_between(&"cloth", Vector3(0.012, -0.018, front_t + 0.026), Vector3(0.012, 0.004, front_t + 0.022), 0.0025, 0.0025, 5,
				Color(0.62, 0.55, 0.42))
	else:
		mb.cylinder(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, front_t)), 0.008, 0.007, 0.018, 10, BRASS.darkened(0.2))
		mb.cylinder(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, front_t + 0.018)), 0.016, 0.014, 0.012, 14, BRASS)
	# The box behind it: sides, back and bottom.
	var side_t := 0.012
	for sx: float in [-1.0, 1.0]:
		mb.box_at(key, Vector3(sx * (hx - side_t * 0.5), -0.004, -size.z * 0.5), Vector3(side_t, size.y - 0.008, size.z), wood.darkened(0.08))
	mb.box_at(key, Vector3(0, -0.004, -size.z + side_t * 0.5), Vector3(size.x - side_t * 2.0, size.y - 0.008, side_t), wood.darkened(0.12))
	mb.box_at(key, Vector3(0, -hy + 0.004, -size.z * 0.5), Vector3(size.x - 0.004, 0.008, size.z), wood.darkened(0.2))
	# What lives in a drawer: a pencil stub, a folded bill and a few loose nails.
	mb.cylinder_between(&"paint_in", Vector3(-hx + 0.06, -hy + 0.013, -0.22), Vector3(-hx + 0.15, -hy + 0.013, -0.19), 0.0045, 0.0045, 6,
			Color(0.72, 0.56, 0.2))
	mb.cylinder_between(&"paint_in", Vector3(-hx + 0.15, -hy + 0.013, -0.19), Vector3(-hx + 0.165, -hy + 0.013, -0.185), 0.0045, 0.0008, 6,
			Color(0.8, 0.7, 0.55))
	mb.box_at(&"paper", Vector3(hx - 0.12, -hy + 0.011, -0.26), Vector3(0.14, 0.004, 0.09), Color(0.86, 0.82, 0.7), Vector3(0, 14, 1.5))
	mb.box_at(&"paper", Vector3(hx - 0.115, -hy + 0.0135, -0.255), Vector3(0.12, 0.002, 0.07), Color(0.8, 0.76, 0.64), Vector3(0, 9, -1))
	for k in 3:
		var nail := Vector3(-hx + 0.07 + k * 0.022, -hy + 0.01, -0.1 + (k % 2) * 0.018)
		mb.cylinder_between(&"rusty" if worn else &"metal", nail, nail + Vector3(0.045, 0, 0.01 * (k - 1)), 0.0016, 0.0016, 4,
				RUST if worn else Color(0.4, 0.4, 0.42))
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.build()
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_slide.add_child(mi)
	# The ray box over the front (the drawer itself collides with nothing).
	_front = StaticBody3D.new()
	_front.name = "Front"
	_front.collision_layer = 4
	_front.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bottom := -hy - front_lap
	var top := reach_up
	box.size = Vector3(size.x + front_lap * 2.0 + 0.02, top - bottom, front_t + reach_out)
	cs.shape = box
	cs.position = Vector3(0, (top + bottom) * 0.5, (front_t + reach_out) * 0.5)
	_front.add_child(cs)
	_slide.add_child(_front)
