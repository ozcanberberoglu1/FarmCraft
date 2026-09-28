class_name BedPoint
extends StaticBody3D
## A vehicle's bed as an interaction target: an invisible box around the bed and
## tailgate (layer 4, so it only stops the interaction ray). E loads the goods in
## hand; with crated hens aboard, E lifts the next crate out into the farmer's hands
## (onto the crates already carried, then into a free hotbar slot); otherwise E opens
## the bed. F opens the bed (crates go back aboard from there).

var vehicle: Vehicle
var size := Vector3.ONE


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)


## The crate E would lift out now (&"" when E does something else).
func _crate_to_take() -> StringName:
	var live := vehicle.live_cargo()
	if live == &"":
		return &""
	var s := PlayerState.selected_stack()
	if not Vehicle.is_cargo(s):
		return live
	# Carrying crates of the same kind: pick up another (onto the stack while it has
	# room, then into a free hotbar slot), so pressing E again never loads them back.
	if s.item.id == live:
		return live
	return &""


func interact_prompt(player: Node) -> String:
	if not vehicle.owned:
		return vehicle.interact_prompt(player)
	var crate := _crate_to_take()
	if crate != &"":
		return tr("ACTION_TAKE_CRATE") % [ItemDB.get_item(crate).display_name(), vehicle.cargo.count(crate)]
	var s := PlayerState.selected_stack()
	if Vehicle.is_cargo(s):
		if vehicle.cargo.space() <= 0:
			return tr("ACTION_BED_FULL")
		return tr("ACTION_LOAD_BED") % [s.item.display_name(), mini(s.count, vehicle.cargo.space())]
	return tr("ACTION_OPEN_BED")


func info_prompt() -> String:
	if not vehicle.owned:
		return ""
	return tr("ACTION_BED_INFO") % [vehicle.cargo.total(), vehicle.cargo.capacity]


func interact(player: Node) -> void:
	if not vehicle.owned:
		vehicle.interact(player)
	elif _crate_to_take() != &"":
		vehicle.take_live()
	elif Vehicle.is_cargo(PlayerState.selected_stack()):
		vehicle.load_selected()
	else:
		Game.hud.open_storage(vehicle)


func info_interact(player: Node) -> void:
	vehicle.info_interact(player)
