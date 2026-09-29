class_name Eating
extends RefCounted
## Eating from the hand: right mouse button with food in hand (an item whose ItemTable
## row has "food" > 0: hunger points it gives back) brings it up to the mouth, two bites
## and a chew, and it is gone from the bag: PlayerState.needs.eat, Events.food_eaten.
## Milk is drunk the same way. The Player shows "RMB (Eat)" while food is in hand and
## the farmer could do with it.

## Seconds the whole bite takes (up to the mouth, two bites, back down).
const TIME := 1.3
## Where in it (0..1) the bites land; the food is gone at the last one.
const BITES: Array[float] = [0.38, 0.6]
## Hunger this close to full: "You're full".
const FULL_MARGIN := 3.0
## Under this much hunger the prompt offers any food in hand; a cooked meal always.
const PROMPT_BELOW := 90.0
## Food with no "food" value of its own in the table (a cooked fish added without one).
const DEFAULT_FOOD := 20
## Items drunk rather than eaten.
const DRINKS: Array[StringName] = [&"milk"]


## Hunger points `id` gives back when eaten (0: not food).
static func food_value(id: StringName) -> int:
	var row: Dictionary = ItemTable.ITEMS.get(id, {})
	var v := int(row.get("food", 0))
	if v <= 0 and ItemDB.has_item(id) and ItemDB.get_item(id).category == "food":
		v = DEFAULT_FOOD
	return maxi(v, 0)


static func is_food(stack: ItemStack) -> bool:
	return stack != null and stack.item != null and food_value(stack.item.id) > 0


## The verb for eating `id` ("Eat", or "Drink" for milk).
static func verb(id: StringName) -> String:
	return TranslationServer.translate("ACTION_DRINK" if id in DRINKS else "ACTION_EAT")


## The farmer's hands are free to eat: on foot, nothing else going on.
static func hands_free(player: Player) -> bool:
	return player != null and player.riding == null and player.driving == null and not Game.is_ui_open() \
			and not player.placer.active and player.action_clock() < 0.0 and not player.held.busy()


## "RMB (Eat)" while food is in hand and the farmer could do with it: a cooked meal
## unless full, a crop or milk once somewhat hungry ("" otherwise).
static func prompt_line(player: Player, stack: ItemStack) -> String:
	if not is_food(stack) or PlayerState.needs.hunger >= Needs.MAX - FULL_MARGIN:
		return ""
	if stack.item.category != "food" and PlayerState.needs.hunger >= PROMPT_BELOW:
		return ""
	if player.riding != null or player.driving != null or player.placer.active:
		return ""
	return "%s (%s)" % [TranslationServer.translate("KEY_RMB"), verb(stack.item.id)]


## RMB: eats what is in hand. Returns true when the click was taken (eaten, or "full").
static func try_eat(player: Player) -> bool:
	var stack := PlayerState.selected_stack()
	if not is_food(stack) or not hands_free(player):
		return false
	var id := stack.item.id
	if PlayerState.needs.hunger >= Needs.MAX - FULL_MARGIN:
		Game.notify(TranslationServer.translate("MSG_NOT_HUNGRY"), UiTheme.TEXT_MUTED)
		return true
	var slot := PlayerState.selected
	var points := food_value(id)
	player.held.play(&"eat", TIME, 1, false)
	var tree := player.get_tree()
	for i in BITES.size():
		var last := i == BITES.size() - 1
		tree.create_timer(TIME * BITES[i], false, true).timeout.connect(func() -> void:
			if not is_instance_valid(player):
				return
			var mouth := player.camera.global_position - player.camera.global_basis.z * 0.25 - player.camera.global_basis.y * 0.08
			CampSfx.play("bite" if not last else "chew", mouth, -8.0 if not last else -10.0, 0.08, 2.0,
					0.95 if id in DRINKS else 1.0)
			# The head nods into each bite.
			player.kick_view(Vector4(0.5, 0.0, 0.0, -0.004))
			if last:
				_swallow(id, slot, points))
	return true


## The last bite: the food leaves the bag (if it is still the one in hand) and fills
## the farmer up.
static func _swallow(id: StringName, slot: int, points: int) -> void:
	var s := PlayerState.inventory.get_stack(slot)
	if s == null or s.item.id != id:
		return
	if PlayerState.inventory.take_from(slot, 1) == null:
		return
	PlayerState.needs.eat(points)
	Events.food_eaten.emit(id)
