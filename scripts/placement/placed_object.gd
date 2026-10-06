class_name PlacedObject
extends StaticBody3D
## Something the player put down on the farm (a machine, a sprinkler, the workbench, a
## coop put up from a kit). Its entry in FarmState.placed ({id, pos, yaw} plus its own
## state) is the saved state; F picks it back up into the bag when it holds nothing.
## Buildings (PlaceableTable "building") bring their own model and colliders.

var item_id: StringName
var entry: Dictionary
var _moving: Node3D


## The node for a FarmState.placed entry.
static func create(e: Dictionary) -> PlacedObject:
	var id := StringName(e["id"])
	var node: PlacedObject
	match String(PlaceableTable.get_info(id).get("kind", "")):
		"machine":
			node = Machine.new()
		"sprinkler":
			node = Sprinkler.new()
		"workbench":
			node = Workbench.new()
		"coop":
			node = ChickenCoop.new()
		"campfire":
			node = Campfire.new()
		_:
			node = _by_kind(String(PlaceableTable.get_info(id).get("kind", "")))
	node.item_id = id
	node.entry = e
	node.name = "%s_%d" % [id, absi(hash(e["pos"])) % 100000]
	node.position = e["pos"]
	node.rotation.y = float(e.get("yaw", 0.0))
	return node


## Kinds without a case above (the campfire) bring their own script,
## res://scripts/placement/<kind>.gd (extending PlacedObject); else a plain one.
static func _by_kind(kind: String) -> PlacedObject:
	var path := "res://scripts/placement/%s.gd" % kind
	if kind != "" and ResourceLoader.exists(path):
		var node: Variant = (load(path) as Script).new()
		if node is PlacedObject:
			return node
		if node is Node:
			(node as Node).free()
	return PlacedObject.new()


func _ready() -> void:
	# Solid for walking into (layer 1) and a target for the interaction ray (layer 4).
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"placed")
	if PlaceableTable.is_building(item_id) or bool(PlaceableTable.get_info(item_id).get("custom", false)):
		_setup()
		return
	var size: Vector3 = PlaceableTable.get_info(item_id).get("size", Vector3.ONE)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = PlaceableModels.mesh(item_id, "body")
	add_child(body)
	if PlaceableModels.has_moving(item_id):
		var pivot := PlaceableModels.pivot_of(item_id)
		_moving = Node3D.new()
		_moving.name = "Moving"
		_moving.position = pivot
		# Turned from _process: interpolating it between physics ticks would make it stutter.
		_moving.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_moving)
		var mi := MeshInstance3D.new()
		mi.mesh = PlaceableModels.mesh(item_id, "moving")
		mi.position = -pivot
		_moving.add_child(mi)
	_setup()


## Subclasses add their own parts here.
func _setup() -> void:
	pass


func can_pick_up() -> bool:
	return true


func interact_prompt(_player: Node) -> String:
	return ""


func info_prompt() -> String:
	return tr("ACTION_PICK_UP") if can_pick_up() else ""


## F: back into the bag (and off the farm).
func info_interact(_player: Node) -> void:
	if not can_pick_up():
		return
	if PlayerState.give(item_id, 1) > 0:
		return
	Audio.play("plank", global_position + Vector3(0, 0.4, 0), -6.0)
	FarmState.remove_placed(entry)
	queue_free()


## The item's name for prompts.
func display_name() -> String:
	return ItemDB.get_item(item_id).display_name()


# --- Paint (Painter): a can of paint in hand, LMB on a placed thing that takes it ---------

func use_prompt(_player: Node, stack: ItemStack) -> String:
	return Painter.use_prompt(self, stack)


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return Painter.use_action(self, stack)


func use_impact(_player: Node, stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	Painter.use_impact(self, stack, hit)


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	Painter.complete_use(self, stack)
