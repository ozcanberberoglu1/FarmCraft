class_name ManureHeap
extends StaticBody3D
## The dung heap outside the barn pen. Mucking out the animals' bedding adds to it
## every night (FarmState.manure); the pitchfork takes manure from it, a few forkfuls
## at a time. The mound grows and shrinks with what is on it, a size step for every
## ManureMound.STEP of manure. Each step's mound is always the same: tools/bake_tools.gd
## bakes them, and the game loads them in the background (building one in GDScript
## takes long enough to stall a frame).

const PER_FORK := 5

## Mound meshes by size step, shared by every heap.
static var _mounds := {}

var _mound: MeshInstance3D
var _shape: CollisionShape3D
var _shown := -1


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	_mound = MeshInstance3D.new()
	add_child(_mound)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 1.0, 2.2)
	_shape.shape = box
	_shape.position.y = 0.5
	add_child(_shape)
	FarmState.manure_changed.connect(_refresh)
	_request_mounds()
	_refresh()


func _refresh() -> void:
	# Under one unit the heap is empty (step 0), so reaching 1.0 always shows the mound.
	var step := ceili(FarmState.manure / ManureMound.STEP) if FarmState.manure >= 1.0 else 0
	if step == _shown:
		return
	_shown = step
	_shape.disabled = step == 0
	_mound.mesh = mound(step) if step > 0 else null


## Starts loading the baked mounds on a background thread.
static func _request_mounds() -> void:
	for step in range(1, ManureMound.steps() + 1):
		var path := ManureMound.BAKED % step
		if _mounds.has(step) or not ResourceLoader.exists(path):
			continue
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path, "ArrayMesh")


## The mound at size `step`: baked (taken from its background load, waiting only if it
## is still running), or built here; once for each step.
static func mound(step: int) -> ArrayMesh:
	if not _mounds.has(step):
		var path := ManureMound.BAKED % step
		var m: ArrayMesh = null
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			m = ResourceLoader.load_threaded_get(path) as ArrayMesh
		if m == null and ResourceLoader.exists(path):
			m = load(path) as ArrayMesh
		_mounds[step] = m if m != null else ManureMound.build(step)
	return _mounds[step]


func use_prompt(_player: Node, stack: ItemStack) -> String:
	var a := use_action(null, stack)
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if stack == null or stack.item.tool_type != &"pitchfork" or FarmState.manure < 1.0:
		return {}
	return {"id": "muck", "verb": "ACTION_MUCK", "label": "PROGRESS_MUCKING", "duration": 1.1, "wear": true}


## The fork landing (the look only): a small clod where it stabs in, the forkful thrown
## up as it is lifted out.
func use_impact(player: Node, _stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	var at: Vector3 = hit.get("point", global_position + Vector3(0, 0.6, 0))
	if hit.get("final", false):
		Fx.dirt_burst(global_position + Vector3(0, 0.6, 0), 0.8)
	else:
		var back := Vector3.ZERO
		if player is Node3D:
			back = (player as Node3D).global_position - at
			back.y = 0.0
			back = back.normalized() * 0.4 if back.length() > 0.01 else Vector3.ZERO
		Fx.dirt_clods(at, back, 0.6)


func complete_use(_player: Node, _stack: ItemStack, _action: Dictionary) -> void:
	var n := mini(PER_FORK, int(FarmState.manure))
	var left := PlayerState.give(&"manure", n)
	FarmState.add_manure(-(n - left))


func info_prompt() -> String:
	return tr("INFO_MANURE_HEAP") % int(FarmState.manure)
