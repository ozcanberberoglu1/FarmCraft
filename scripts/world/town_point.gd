class_name TownPoint
extends StaticBody3D
## An invisible interaction box in town (shop counters, fuel pumps): shows a prompt
## and runs `action` on E. While the one who works it (`staff`, a Townsperson) is away
## at a town event it works all the same, saying so under the prompt (an honesty box).

var prompt_key := ""
## Translation keys filled into the prompt's %s (an Animal Market pen: its kind).
var prompt_args: Array = []
var action: Callable
var size := Vector3.ONE
var is_pump := false
## Who serves here (TownPeople sets it): the hint says when he is away.
var staff: Node


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)


func interact_prompt(_player: Node) -> String:
	if is_pump:
		var v := Town._nearest_owned_vehicle(global_position, 7.5)
		if v == null:
			return tr("ACTION_REFUEL_NO_VEHICLE")
		var need := float(v.info.get("fuel_capacity", 40.0)) - v.fuel
		return tr(prompt_key) % [roundi(need), UiTheme.money(int(ceil(need * Town.FUEL_PRICE)))]
	if not prompt_args.is_empty():
		return tr(prompt_key) % prompt_args.map(func(k: String) -> String: return tr(k))
	return tr(prompt_key)


func interact(_player: Node) -> void:
	if action.is_valid():
		action.call()


## A line under the prompt while the one who serves here is away at a town event.
func hint_prompt() -> String:
	if staff != null and is_instance_valid(staff) and bool(staff.get("away")):
		return tr("HINT_SERVICE_AWAY")
	return ""
