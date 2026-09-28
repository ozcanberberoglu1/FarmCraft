class_name RecipeTable
extends RefCounted
## What the workbench makes and what the machines turn goods into.
##
## CRAFTING: item -> {items: {id: count}, count (made), level (farm level needed)}
## PROCESSING: machine -> [{in: {id: count}, out: item, hours (game hours)}]

## Levels follow UnlockTable: a machine opens with what feeds it (fertilizer with the
## chickens' manure, the spinning wheel with sheep, the cheese press with cows).
const CRAFTING := {
	&"quern": {"items": {&"stone": 20, &"wood": 10}, "count": 1, "level": 1},
	&"fertilizer": {"items": {&"manure": 4, &"hay": 1}, "count": 2, "level": 2},
	&"sprinkler": {"items": {&"iron_ore": 5, &"stone": 3}, "count": 1, "level": 3},
	&"pickle_barrel": {"items": {&"wood": 35, &"iron_ore": 3}, "count": 1, "level": 3},
	&"spinning_wheel": {"items": {&"wood": 40, &"iron_ore": 2}, "count": 1, "level": 3},
	&"cheese_press": {"items": {&"wood": 30, &"iron_ore": 4}, "count": 1, "level": 4},
	&"jam_kettle": {"items": {&"stone": 20, &"iron_ore": 10}, "count": 1, "level": 5},
}
const CRAFT_ORDER: Array[StringName] = [&"quern", &"fertilizer", &"sprinkler", &"pickle_barrel",
	&"spinning_wheel", &"cheese_press", &"jam_kettle"]

const PROCESSING := {
	&"cheese_press": [{"in": {&"milk": 2}, "out": &"cheese", "hours": 12}],
	&"spinning_wheel": [{"in": {&"wool": 1}, "out": &"yarn", "hours": 8}],
	&"pickle_barrel": [{"in": {&"carrot": 5}, "out": &"pickles", "hours": 36},
		{"in": {&"eggplant": 4}, "out": &"pickles", "hours": 36}],
	&"jam_kettle": [{"in": {&"strawberry": 4}, "out": &"jam", "hours": 6},
		{"in": {&"tomato": 6}, "out": &"tomato_paste", "hours": 8}],
	&"quern": [{"in": {&"wheat": 5}, "out": &"flour", "hours": 3}],
}


static func crafting(id: StringName) -> Dictionary:
	return CRAFTING.get(id, {})


static func processing(machine: StringName) -> Array:
	return PROCESSING.get(machine, [])


## The recipe of `machine` that takes `item_id`, or {}.
static func recipe_for(machine: StringName, item_id: StringName) -> Dictionary:
	for r: Dictionary in processing(machine):
		if (r["in"] as Dictionary).has(item_id):
			return r
	return {}
