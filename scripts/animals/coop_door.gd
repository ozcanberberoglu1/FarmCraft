class_name CoopDoor
extends StaticBody3D
## The plank door of a kit-built coop, hung on its left jamb. E opens and shuts it
## (AnimalHousing.door_open, saved with the coop); shut, the hens inside stay in and
## the ones outside wait by the ramp. With a crated hen in hand, E lets her out into
## the coop instead. The node sits on the hinge and stays put: the leaf (its mesh and
## its collider) swings outward to lie back against the front wall, and the open
## doorway answers for the door too (a walk-through target on the interaction layer).

const OPEN_ANGLE := -PI * 0.94
const SWING_TIME := 0.5
## Id sent with Events.door_toggled.
const DOOR_ID := &"coop"

var housing: AnimalHousing
var width := 1.0
var height := 2.05

var _leaf: Node3D
var _leaf_shape: CollisionShape3D
var _angle := 0.0
var _tween: Tween

static var _leaf_mesh: ArrayMesh
static var _leaf_size := Vector2.ZERO


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	# Turned by a tween, not per physics tick: drawn where it is.
	_leaf.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_leaf)
	var mi := MeshInstance3D.new()
	mi.mesh = leaf_mesh(width, height)
	_leaf.add_child(mi)
	# Shapes only count as the body's own children: this one is turned with the leaf.
	_leaf_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.04, height - 0.04, 0.07)
	_leaf_shape.shape = box
	add_child(_leaf_shape)
	var way := Doorway.new()
	way.name = "Doorway"
	way.door = self
	add_child(way)
	_set_angle(OPEN_ANGLE if housing.door_open else 0.0)


## Plank leaf with a Z brace and battens on the outside, strap hinges and a latch;
## built once per size (every coop has the same door). The hinge edge is at x = 0.
static func leaf_mesh(w: float, h: float) -> ArrayMesh:
	if _leaf_mesh and _leaf_size == Vector2(w, h):
		return _leaf_mesh
	var mb := MeshBuilder.new()
	var lw := w - 0.04
	var lh := h - 0.04
	var boards := 5
	for i in boards:
		var bw := lw / boards
		var shade := AnimalBuildings.PLANK.darkened(0.06 + 0.05 * float(i % 2))
		mb.box_at(&"planks", Vector3(0.02 + bw * (i + 0.5), 0.02 + lh * 0.5, 0.0), Vector3(bw - 0.006, lh, 0.045), shade, Vector3.ZERO, true)
	var col := AnimalBuildings.PLANK_DARK
	for y: float in [0.28, lh - 0.22]:
		mb.box_at(&"wood", Vector3(0.02 + lw * 0.5, y, 0.04), Vector3(lw - 0.06, 0.12, 0.035), col)
	var brace_len := Vector2(lw - 0.16, lh - 0.62).length()
	var brace_ang := rad_to_deg(atan2(lh - 0.62, lw - 0.16))
	mb.box_at(&"wood", Vector3(0.02 + lw * 0.5, lh * 0.5 + 0.03, 0.04), Vector3(brace_len, 0.1, 0.03), col, Vector3(0, 0, brace_ang))
	# Black iron: two strap hinges from the hinge side and a thumb latch.
	var iron := Color(0.14, 0.13, 0.12)
	for y: float in [0.28, lh - 0.22]:
		mb.box_at(&"rusty", Vector3(0.24, y, 0.062), Vector3(0.46, 0.04, 0.008), iron)
		mb.cylinder(&"rusty", Transform3D(Basis(), Vector3(0.0, y - 0.07, 0.0)), 0.018, 0.018, 0.14, 8, iron)
	mb.box_at(&"rusty", Vector3(lw - 0.08, lh * 0.5, 0.062), Vector3(0.05, 0.16, 0.01), iron)
	mb.cylinder_between(&"rusty", Vector3(lw - 0.1, lh * 0.5 + 0.03, 0.07), Vector3(lw + 0.04, lh * 0.5 + 0.03, 0.07), 0.008, 0.008, 6, iron)
	_leaf_mesh = mb.build()
	_leaf_size = Vector2(w, h)
	return _leaf_mesh


func interact_prompt(_player: Node) -> String:
	if housing == null:
		return ""
	if held_crate() != &"":
		return release_prompt()
	return tr("ACTION_COOP_DOOR_CLOSE") if housing.door_open else tr("ACTION_COOP_DOOR_OPEN")


## "Let the hen in" / "Let the rooster in", by the crate in hand.
static func release_prompt() -> String:
	var rooster := AnimalTable.species_of_crate(held_crate()) == &"rooster"
	return LiveCrates.tr_key("ACTION_RELEASE_ROOSTER" if rooster else "ACTION_RELEASE_HEN")


func interact(_player: Node) -> void:
	if housing == null:
		return
	if held_crate() != &"":
		release_from_hand()
		return
	set_open(not housing.door_open)


## Opens or shuts the door (with its creak and swing).
func set_open(open: bool, animate := true) -> void:
	if housing == null or housing.door_open == open:
		return
	housing.set_door(open)
	var at := global_position + global_basis.x * width * 0.5 + Vector3(0, 1.0, 0)
	if animate:
		Audio.play("door_open" if open else "door_close", at, -4.0)
		if not open and not housing.animals_outside().is_empty():
			Game.notify(tr("MSG_COOP_DOOR_SHUT"), Color(1.0, 0.72, 0.4))
	swing(open, animate)
	Events.door_toggled.emit(DOOR_ID, open)


func swing(open: bool, animate := true) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	var target := OPEN_ANGLE if open else 0.0
	if not animate or not is_inside_tree():
		_set_angle(target)
		return
	_tween = create_tween()
	_tween.tween_method(_set_angle, _angle, target, SWING_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_angle(a: float) -> void:
	_angle = a
	var b := Basis(Vector3.UP, a)
	_leaf.rotation.y = a
	_leaf_shape.transform = Transform3D(b, b * Vector3(width * 0.5, height * 0.5, 0.0))


## The crate in the player's hand (its item id), or &"" when the hand holds none.
static func held_crate() -> StringName:
	return LiveCrates.held()


## Lets the crated hen in the player's hand out into this coop.
func release_from_hand() -> bool:
	if not release_held(housing):
		return false
	Audio.play("plank", global_position + Vector3(0, 0.6, 0), -6.0)
	return true


## Lets the crated animal in the player's hand out into the housing `to` (at `at`, else
## just inside its door): a flurry of feathers and a cluck. False when the hand holds no
## crate for it or it is full (with a note).
static func release_held(to: AnimalHousing, at := Vector3.INF) -> bool:
	var crate := held_crate()
	if crate == &"" or to == null:
		return false
	var species := AnimalTable.species_of_crate(crate)
	if String(AnimalTable.get_species(species).get("housing", "")) != to.kind:
		return false
	if to.free_space() <= 0:
		Game.notify(LiveCrates.tr_key("MSG_COOP_FULL") % to.capacity(), UiTheme.RED)
		return false
	# Out of the hand first: whoever listens to the release counts the crates left.
	PlayerState.inventory.remove_item(crate, 1)
	var a := Animals.release(species, to, at)
	if a == null:
		PlayerState.inventory.add_item(crate, 1)
		return false
	var n := Animals.node_of(a)
	var p := (n.global_position if n else to.door_inside()) + Vector3(0, 0.45, 0)
	feathers(p)
	Audio.animal_voice(species, true, p, -2.0)
	return true


## A flurry of white and russet feathers that drift down slowly (a hen flapping out
## of her crate).
static func feathers(at: Vector3) -> void:
	Fx._burst(at, Color(0.95, 0.93, 0.88), 16, Vector3(0.25, 0.15, 0.25), 1.6, 2.4, 80.0, 0.045, Vector3.UP,
			1.2, 2.5, 1.8, false, 0.3)
	Fx._burst(at, Color(0.62, 0.36, 0.2), 8, Vector3(0.2, 0.12, 0.2), 1.4, 2.2, 80.0, 0.04, Vector3.UP,
			1.2, 2.5, 1.8, false, 0.3)
	Fx.dust_cloud(at - Vector3(0, 0.35, 0), Vector2(0.4, 0.4))


## The doorway: aimed at while the door stands open, it answers for the door (E shuts
## it or lets a crated hen in). On the interaction layer only: the farmer and the hens
## walk through it.
class Doorway extends StaticBody3D:
	var door: CoopDoor

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		add_to_group(&"interactable")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(door.width - 0.12, door.height - 0.1, 0.3)
		cs.shape = box
		# In the opening, just inside the frame (the hinge is on the left jamb).
		cs.position = Vector3(door.width * 0.5, door.height * 0.5, -0.2)
		add_child(cs)

	func interact_prompt(player: Node) -> String:
		return door.interact_prompt(player)

	func interact(player: Node) -> void:
		door.interact(player)
