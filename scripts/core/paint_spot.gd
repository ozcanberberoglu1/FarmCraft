class_name PaintSpot
extends Node3D
## What the hands work on while a can of paint is aimed at a wall that is no interactable
## of its own (Painter.wall_target): the repaired farmhouse (LMB its walls, E its trim)
## or a finished kit coop (LMB its walls). One node, moved to where the crosshair is.

## The FarmHouse or the ChickenCoop aimed at.
var what: Node


func _ready() -> void:
	add_to_group(&"interactable")


func aim(target: Node, at: Vector3) -> void:
	what = target
	global_position = at


func _valid() -> bool:
	return what != null and is_instance_valid(what)


func _walls() -> Dictionary:
	if not _valid():
		return {}
	return Painter.house_spec("house_walls") if what is FarmHouse else Painter.coop_spec(what as ChickenCoop)


func interact_title() -> String:
	if not _valid():
		return ""
	return tr("PAINT_TITLE_HOUSE") if what is FarmHouse else tr("HOUSING_COOP")


func use_prompt(_player: Node, stack: ItemStack) -> String:
	return Painter.use_prompt(what, stack, _walls()) if _valid() and not _walls().is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return Painter.use_action(what, stack, _walls()) if _valid() and not _walls().is_empty() else {}


func use_impact(_player: Node, stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	# The brush lands where the crosshair is on the wall.
	Painter.use_impact(self, stack, {"point": global_position, "normal": hit.get("normal", Vector3.UP)})


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	if _valid():
		Painter.complete_use(what, stack, _walls())


## E on the farmhouse: its trim (the casings, the corner boards, the fascia).
func interact_prompt(_player: Node) -> String:
	if not _valid() or not what is FarmHouse:
		return ""
	var trim := Painter.house_spec("house_trim")
	return Painter.use_prompt(what, PlayerState.selected_stack(), trim) if not trim.is_empty() else ""


func interact(player: Node) -> void:
	if interact_prompt(player) == "":
		return
	var stack := PlayerState.selected_stack()
	if player is Player:
		(player as Player).held.play(&"brush", 0.9, 2, false)
	Painter.use_impact(self, stack, {"point": global_position, "normal": Vector3.UP})
	Painter.complete_use(what, stack, Painter.house_spec("house_trim"))


## A run-down house takes no paint yet.
func hint_prompt() -> String:
	if _valid() and what is FarmHouse and (what as FarmHouse).level < 1:
		return tr("HINT_PAINT_REPAIR_FIRST")
	return ""
