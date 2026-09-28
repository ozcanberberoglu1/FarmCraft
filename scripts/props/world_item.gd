@tool
class_name WorldItem
extends StaticBody3D
## An item resting in the world (on a table, in a drawer): E takes it into the bag.
## Unlike Pickup it never moves or seeks the player: the interaction ray sees it
## (layer 3) but nothing collides with it. Once taken it stays gone: FarmState.flags
## remembers it (see `flag`), so a rebuild or a load does not bring it back.
## The origin is where it rests: the model is lifted so its lowest point touches it
## and placed on it by `anchor`.

## Emitted once all of it was taken, just before it leaves the world.
signal taken(item_id: StringName, count: int)

## Items resting in the world (tests, the tutorial).
const GROUP := &"world_items"
## FarmState.flags key of what is left of partly taken items (the bag was full):
## {"<flag>" or "<flag>:<entry>": count}.
const LEFT_FLAG := "items_left"
## Seconds the taken item takes to fly to the camera and vanish.
const TAKE_TIME := 0.2

@export var item_id: StringName = &""
@export_range(1, 999) var count := 1
## Turns the model (ItemModels frame: long tools along +Y, head up) into its resting pose.
@export var lay := Basis()
## Which point of the laid model's bounding box sits on the origin, in fractions of its
## size: (0.5, 0, 0.5) centres its footprint there, (0.5, 0, 1) puts its +Z end there.
## NAN on X or Z keeps the model's own origin on that axis (a long tool's handle line).
@export var anchor := Vector3(0.5, 0.0, 0.5)
## A model of its own instead of ItemModels.mesh(item_id).
@export var mesh: Mesh
## Tilts the laid model along its length so it lies on two points of its underside (a
## hoe on its blade and the end of its handle) instead of floating on its lowest one.
@export var settle := false
## Key in FarmState.flags that remembers it was taken ("" = not remembered).
@export var flag := ""
## When set, flags[flag] is a list of taken entries and this one is added to it;
## otherwise flags[flag] becomes true.
@export var flag_entry := ""

var _model: MeshInstance3D
## Middle of the laid model, in its own space.
var _center := Vector3.ZERO
var _enabled := true
var _gone := false

## Settled poses by mesh and lay (worked out once per model).
static var _settle_cache: Dictionary = {}


func _ready() -> void:
	collision_layer = 4 if _enabled else 0
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(GROUP)
	if not Engine.is_editor_hint():
		if is_taken(flag, flag_entry):
			_gone = true
			queue_free()
			return
		var left: Variant = _left_counts().get(_key())
		if left is int and int(left) > 0:
			count = int(left)
	_build()


## Whether the item remembered under `flag_name` (and `entry`) was taken.
static func is_taken(flag_name: String, entry := "") -> bool:
	if flag_name == "":
		return false
	var v: Variant = FarmState.flags.get(flag_name)
	if entry == "":
		return v is bool and v
	return v is Array and (v as Array).has(entry)


## The ray can find it (and E take it) only while enabled (a shut drawer's contents).
func set_enabled(on: bool) -> void:
	_enabled = on
	collision_layer = 4 if on and not _gone else 0


func is_enabled() -> bool:
	return _enabled and not _gone


## Taken: flying to the hand, or already on its way out of the world.
func is_gone() -> bool:
	return _gone


## The middle of the item (a waypoint target; a look there finds it).
func waypoint_point() -> Vector3:
	return to_global(_center)


func _build() -> void:
	var m: Mesh = mesh if mesh else ItemModels.mesh(item_id)
	var pose := lay
	var box := Transform3D(lay, Vector3.ZERO) * m.get_aabb()
	if settle:
		# The tilted pose and its tight bounds (the tilted mesh AABB is looser than the
		# vertices, and would lift the tool off its two support points).
		var settled: Array = _settled(m, lay)
		pose = settled[0]
		box = settled[1]
	var corner := box.position + box.size * anchor
	var offset := Vector3(0.0 if is_nan(anchor.x) else -corner.x, 0.002 - corner.y, 0.0 if is_nan(anchor.z) else -corner.z)
	_model = MeshInstance3D.new()
	_model.name = "Model"
	_model.mesh = m
	_model.transform = Transform3D(pose, offset)
	# Small clutter: no GI voxelization, kept out of the rain-blocker heightfield.
	_model.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_model.layers = 2
	add_child(_model)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = (box.size + Vector3(0.02, 0.02, 0.02)).max(Vector3(0.06, 0.06, 0.06))
	cs.shape = shape
	_center = box.get_center() + offset
	cs.position = _center
	add_child(cs)


func interact_prompt(_player: Node) -> String:
	if not is_enabled():
		return ""
	var item := ItemDB.get_item(item_id)
	if item == null:
		return ""
	var label := item.display_name() if count <= 1 else "%s ×%d" % [item.display_name(), count]
	return tr("ACTION_TAKE_ITEM") % label


func interact(_player: Node) -> void:
	if not is_enabled() or Engine.is_editor_hint():
		return
	var left := PlayerState.give(item_id, count)
	var got := count - left
	if got <= 0:
		return
	if left > 0:
		# The bag is full: the rest stays here, and is remembered.
		count = left
		if flag != "":
			var counts := _left_counts()
			counts[_key()] = left
			FarmState.flags[LEFT_FLAG] = counts
		Events.item_picked_up.emit(item_id, got)
		return
	_gone = true
	collision_layer = 0
	_remember_taken()
	Events.item_picked_up.emit(item_id, got)
	Events.world_item_taken.emit(item_id)
	taken.emit(item_id, got)
	_fly_away()


## Stores in FarmState.flags that it was taken.
func _remember_taken() -> void:
	if flag == "":
		return
	var counts := _left_counts()
	if counts.has(_key()):
		counts.erase(_key())
		FarmState.flags[LEFT_FLAG] = counts
	if flag_entry == "":
		FarmState.flags[flag] = true
		return
	var v: Variant = FarmState.flags.get(flag)
	var list: Array = v if v is Array else []
	if not list.has(flag_entry):
		list.append(flag_entry)
	FarmState.flags[flag] = list


## Lifted toward the eye and shrunk away, as if picked up.
func _fly_away() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _model == null:
		queue_free()
		return
	var to := cam.global_position + cam.global_basis * Vector3(0.0, -0.25, -0.35)
	var tw := create_tween()
	tw.tween_method(_fly.bind(_model.global_transform, to), 0.0, 1.0, TAKE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _fly(t: float, from: Transform3D, to: Vector3) -> void:
	var xf := from.scaled_local(Vector3.ONE * lerpf(1.0, 0.15, t))
	xf.origin = from.origin.lerp(to, t)
	_model.global_transform = xf


## `pose` tilted about the cross axis of the model's longer horizontal side, so it rests
## on the edge of its underside's lower hull that lies under its middle: [the tilted
## Basis, the AABB of the vertices in it].
static func _settled(m: Mesh, pose: Basis) -> Array:
	var cache_key := "%d|%s" % [m.get_instance_id(), pose]
	if _settle_cache.has(cache_key):
		return _settle_cache[cache_key]
	const BINS := 24
	var box := Transform3D(pose, Vector3.ZERO) * m.get_aabb()
	var along_z := box.size.z >= box.size.x
	var from := box.position.z if along_z else box.position.x
	var span := maxf(box.size.z if along_z else box.size.x, 0.001)
	# Read back once: the bounds pass below walks them again.
	var surfaces: Array[PackedVector3Array] = []
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			surfaces.append(arrays[Mesh.ARRAY_VERTEX])
	# The lowest point of each slice along the length.
	var low: Array[float] = []
	low.resize(BINS)
	low.fill(INF)
	for verts in surfaces:
		for v in verts:
			var p := pose * v
			var i := clampi(int(((p.z if along_z else p.x) - from) / span * BINS), 0, BINS - 1)
			low[i] = minf(low[i], p.y)
	# Their lower hull (monotone chain), then its edge under the middle.
	var hull: Array[Vector2] = []
	for i in BINS:
		if low[i] == INF:
			continue
		var q := Vector2(from + (i + 0.5) * span / BINS, low[i])
		while hull.size() >= 2 and (hull[-1] - hull[-2]).cross(q - hull[-2]) <= 0.0:
			hull.pop_back()
		hull.append(q)
	var mid := from + span * 0.5
	var slope := 0.0
	for i in hull.size() - 1:
		if hull[i].x <= mid and hull[i + 1].x >= mid:
			slope = (hull[i + 1].y - hull[i].y) / maxf(hull[i + 1].x - hull[i].x, 0.0001)
			break
	var tilt := Basis(Vector3.RIGHT, atan(slope)) if along_z else Basis(Vector3.BACK, -atan(slope))
	var out := tilt * pose
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for verts in surfaces:
		for v in verts:
			var p := out * v
			lo = lo.min(p)
			hi = hi.max(p)
	var bounds := AABB(lo, hi - lo) if lo.x <= hi.x else Transform3D(out, Vector3.ZERO) * m.get_aabb()
	var result := [out, bounds]
	_settle_cache[cache_key] = result
	return result


func _key() -> String:
	return flag if flag_entry == "" else "%s:%s" % [flag, flag_entry]


static func _left_counts() -> Dictionary:
	var d: Variant = FarmState.flags.get(LEFT_FLAG)
	return d if d is Dictionary else {}
