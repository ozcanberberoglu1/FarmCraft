class_name RecipeTable
extends RefCounted
## What the workbench makes and what the machines turn goods into.
##
## CRAFTING: item -> {items: {id: count}, count (made), level (farm level needed),
## group (the heading it is listed under at the workbench: GROUPS)}
## PROCESSING: machine -> [{in: {id: count}, out: item, hours (game hours)}]

## Levels follow UnlockTable: a machine opens with what feeds it (fertilizer with the
## chickens' manure, the spinning wheel with sheep, the cheese press with cows). The
## first tools (knife, rod, bow), the campfire and bait are there from the first
## workbench: the second day's story makes the knife, the rod and a campfire. Nails and
## rope come from the town market; the farm's tools can be made again when one wears
## out or a second hand needs one (iron ore from the quarry or the market).
const CRAFTING := {
	# Tools.
	&"knife": {"items": {&"wood": 2, &"stone": 3}, "count": 1, "level": 1, "group": "tools"},
	&"fishing_rod": {"items": {&"wood": 3, &"rope": 2}, "count": 1, "level": 1, "group": "tools"},
	&"bow": {"items": {&"wood": 4, &"nails": 4, &"rope": 2}, "count": 1, "level": 1, "group": "tools"},
	&"axe": {"items": {&"wood": 3, &"iron_ore": 3}, "count": 1, "level": 1, "group": "tools"},
	&"pickaxe": {"items": {&"wood": 3, &"iron_ore": 4}, "count": 1, "level": 1, "group": "tools"},
	&"hoe": {"items": {&"wood": 3, &"iron_ore": 3}, "count": 1, "level": 1, "group": "tools"},
	&"scythe": {"items": {&"wood": 4, &"iron_ore": 4}, "count": 1, "level": 1, "group": "tools"},
	&"watering_can": {"items": {&"iron_ore": 5, &"nails": 2}, "count": 1, "level": 1, "group": "tools"},
	&"pitchfork": {"items": {&"wood": 4, &"iron_ore": 3, &"nails": 2}, "count": 1, "level": 2, "group": "tools"},
	&"shears": {"items": {&"iron_ore": 4, &"wood": 1}, "count": 1, "level": 3, "group": "tools"},
	&"milk_pail": {"items": {&"wood": 6, &"nails": 4}, "count": 1, "level": 4, "group": "tools"},
	# The campfire and bait.
	&"campfire": {"items": {&"stone": 8, &"wood": 6}, "count": 1, "level": 1, "group": "camp"},
	# The food table: a catch cleaned on it and cooked fills far more.
	&"food_table": {"items": {&"wood": 14, &"stone": 4, &"nails": 8}, "count": 1, "level": 1, "group": "camp"},
	&"dough": {"items": {&"wheat": 2}, "count": 4, "level": 1, "group": "camp"},
	# The farm's supplies.
	&"feed": {"items": {&"wheat": 2}, "count": 5, "level": 1, "group": "farm"},
	&"fertilizer": {"items": {&"manure": 4, &"hay": 1}, "count": 2, "level": 2, "group": "farm"},
	&"sprinkler": {"items": {&"iron_ore": 5, &"stone": 3}, "count": 1, "level": 3, "group": "farm"},
	# Machines.
	&"quern": {"items": {&"stone": 20, &"wood": 10}, "count": 1, "level": 1, "group": "machines"},
	&"pickle_barrel": {"items": {&"wood": 35, &"iron_ore": 3}, "count": 1, "level": 3, "group": "machines"},
	&"spinning_wheel": {"items": {&"wood": 40, &"iron_ore": 2}, "count": 1, "level": 3, "group": "machines"},
	&"cheese_press": {"items": {&"wood": 30, &"iron_ore": 4}, "count": 1, "level": 4, "group": "machines"},
	&"jam_kettle": {"items": {&"stone": 20, &"iron_ore": 10}, "count": 1, "level": 5, "group": "machines"},
}
## The workbench's list, heading by heading (GROUPS).
const CRAFT_ORDER: Array[StringName] = [&"knife", &"fishing_rod", &"bow", &"axe", &"pickaxe", &"hoe",
	&"scythe", &"watering_can", &"pitchfork", &"shears", &"milk_pail", &"campfire", &"food_table", &"dough", &"feed",
	&"fertilizer", &"sprinkler", &"quern", &"pickle_barrel", &"spinning_wheel", &"cheese_press", &"jam_kettle"]
## Headings of the workbench's list: group -> [translation key, icon].
const GROUPS := {
	"tools": ["CRAFT_GROUP_TOOLS", "hammer"], "camp": ["CRAFT_GROUP_CAMP", "campfire"],
	"farm": ["CRAFT_GROUP_FARM", "wheat"], "machines": ["CRAFT_GROUP_MACHINES", "wrench"],
}

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
