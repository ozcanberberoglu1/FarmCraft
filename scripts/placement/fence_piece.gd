class_name FencePiece
extends PlacedObject
## A piece of the farmer's own fence (PlaceableTable "fence_panel", "fence_gate"), put
## down by FencePlacing: it runs from its end A to its end B (`len` metres along its own
## X, the entry's `pos` in the middle) with a post at each, upright on any slope, the
## rails following the ground from one to the other.
##   A panel is solid: nobody walks through it (a wolf leaps it, Wolf.LEAP_HEIGHT).
##   A gate swings with E (hinged at A): shut it is as solid as a panel, open the way is
##   free for the farmer and for an animal on his halter. Saved in the entry ("open").
## E held for HOLD seconds takes either back into the bag.
## A post two pieces share is drawn by one of them only (set_posts: Pastures decides,
## and knows the loops the pieces close).

const GROUP := &"fence_pieces"
## Seconds E is held to take a piece back up.
const HOLD := 0.6
## How far a gate swings open (radians) and how long it takes (seconds).
const SWING := 1.9
const SWING_TIME := 0.55
## The solid part's height and thickness (m): low enough for a wolf to leap.
const SOLID := Vector2(1.16, 0.16)

var _mesh: MeshInstance3D
var _block: CollisionShape3D
var _pivot: Node3D
var _posts: Array[bool] = [true, true]
var _open := false
## E held on it: seconds so far (-1: not held), and who holds it.
var _hold := -1.0
var _holder: Player
var _showing := false


func _setup() -> void:
	add_to_group(GROUP)
	_open = is_gate() and bool(entry.get("open", false))
	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	add_child(_mesh)
	var length := span()
	var slope := atan2(rise(), length)
	_block = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length - (0.3 if is_gate() else 0.0), SOLID.x, SOLID.y)
	_block.shape = box
	_block.transform = Transform3D(Basis(Vector3.BACK, slope), Vector3(0, SOLID.x * 0.5 + 0.04, 0))
	add_child(_block)
	if is_gate():
		_setup_gate(length, slope)
	_rebuild()
	set_process(false)
	Pastures.mark_dirty()


func _exit_tree() -> void:
	_end_hold(false)
	Pastures.mark_dirty()


## The gate's posts (always solid) and its leaf on the hinge at A, with a body of its own
## to aim at (it keeps nobody out: the way through is `_block`'s, off while it is open).
func _setup_gate(length: float, slope: float) -> void:
	for s: float in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var post := BoxShape3D.new()
		post.size = Vector3(0.2, FenceModels.GATE_POST, 0.2)
		cs.shape = post
		cs.position = Vector3(s * length * 0.5, s * rise() * 0.5 + FenceModels.GATE_POST * 0.5, 0.0)
		add_child(cs)
	_pivot = Node3D.new()
	_pivot.name = "Leaf"
	_pivot.position = Vector3(-length * 0.5, -rise() * 0.5, 0.0)
	_pivot.rotation = Vector3(0.0, SWING if _open else 0.0, slope)
	add_child(_pivot)
	var leaf := MeshInstance3D.new()
	leaf.mesh = FenceModels.gate_leaf(length)
	_pivot.add_child(leaf)
	var grip := StaticBody3D.new()
	grip.collision_layer = 4
	grip.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length - 0.3, 0.95, 0.1)
	cs.shape = box
	cs.position = Vector3(length * 0.5, 0.64, 0.0)
	grip.add_child(cs)
	_pivot.add_child(grip)
	_block.disabled = _open


func is_gate() -> bool:
	return bool(PlaceableTable.get_info(item_id).get("gate", false))


func is_open() -> bool:
	return _open


## Metres from end A to end B.
func span() -> float:
	return float(entry.get("len", FenceModels.PANEL))


## Its two ends on the ground (world): A, B.
func ends() -> Array[Vector3]:
	return ends_of(entry)


## The two ends on the ground (world) of the piece a FarmState.placed entry describes.
static func ends_of(e: Dictionary) -> Array[Vector3]:
	var pos: Vector3 = e["pos"]
	var yaw := float(e.get("yaw", 0.0))
	var half := Vector3(cos(yaw), 0.0, -sin(yaw)) * float(e.get("len", FenceModels.PANEL)) * 0.5
	var out: Array[Vector3] = []
	for p: Vector3 in [pos - half, pos + half]:
		out.append(Vector3(p.x, TerrainData.height(p.x, p.z), p.z))
	return out


## How much higher end B stands than end A.
func rise() -> float:
	var e := ends()
	return e[1].y - e[0].y


## Which of its ends' posts are its own to draw (the others stand in a neighbour's mesh).
func set_posts(a: bool, b: bool) -> void:
	if is_gate() or (_posts[0] == a and _posts[1] == b):
		return
	_posts = [a, b]
	_rebuild()


func _rebuild() -> void:
	var seed_value := absi(hash(entry["pos"])) % 100000
	if is_gate():
		_mesh.mesh = FenceModels.gate_posts(span(), rise(), seed_value)
	else:
		_mesh.mesh = FenceModels.panel(span(), rise(), _posts[0], _posts[1], seed_value)


# --- The gate ------------------------------------------------------------------------------

## Swings the gate open or shut (at once when `instant`).
func set_open(open: bool, instant := false) -> void:
	if not is_gate() or open == _open:
		return
	_open = open
	entry["open"] = open
	_block.set_deferred("disabled", open)
	var angle := SWING if open else 0.0
	if instant or not is_inside_tree():
		_pivot.rotation.y = angle
	else:
		var tw := create_tween()
		tw.tween_property(_pivot, "rotation:y", angle, SWING_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Audio.play("creak", global_position + Vector3(0, 0.8, 0), -8.0, 0.1)
		if not open:
			tw.tween_callback(func() -> void: Audio.play("wood_hit", global_position + Vector3(0, 0.8, 0), -12.0))
	Pastures.gate_moved(self)


# --- Prompts -------------------------------------------------------------------------------

func interact_title() -> String:
	return display_name()


func interact_prompt(_player: Node) -> String:
	if is_gate():
		return tr("ACTION_CLOSE") if _open else tr("ACTION_OPEN")
	return tr("ACTION_HOLD_PICK_UP")


## A gate's second line: E held takes it up (a panel says so on its E line).
func hint_prompt() -> String:
	return tr("HINT_FENCE_HOLD") if is_gate() else ""


## The farm's other things go back into the bag with F; these with E held.
func info_prompt() -> String:
	return ""


func info_interact(_player: Node) -> void:
	pass


## E down on it: held on, it is taken up; let go at once, a gate swings.
func interact(player: Node) -> void:
	_hold = 0.0
	_holder = player as Player
	set_process(true)


func _process(delta: float) -> void:
	if _hold < 0.0:
		set_process(false)
		return
	var aimed := _holder != null and is_instance_valid(_holder) and _holder.target == self
	if not Input.is_action_pressed("interact") or Game.is_ui_open() or not aimed:
		var tapped := _hold < HOLD and aimed
		_end_hold(false)
		if tapped and is_gate():
			set_open(not _open)
		return
	_hold += delta
	if _hold > 0.18 and not _showing:
		_showing = true
		Events.action_progress_started.emit(tr("PROGRESS_FENCE_PICKUP"), HOLD)
	if _showing:
		Events.action_progress_updated.emit(clampf(_hold / HOLD, 0.0, 1.0))
	if _hold >= HOLD:
		_end_hold(true)
		pick_up()


func _end_hold(done: bool) -> void:
	if _showing:
		Events.action_progress_finished.emit(done)
	_showing = false
	_hold = -1.0
	_holder = null


## Back into the bag (and off the farm). False when the bag has no room for it.
func pick_up() -> bool:
	if PlayerState.give(item_id, 1) > 0:
		return false
	Audio.play("plank", global_position + Vector3(0, 0.5, 0), -6.0)
	FarmState.remove_placed(entry)
	FencePlacing.forget(self)
	queue_free()
	Pastures.mark_dirty()
	return true
