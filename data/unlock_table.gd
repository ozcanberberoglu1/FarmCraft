class_name UnlockTable
extends RefCounted
## What each farm level opens up, so the farm grows with the player: crops (their
## seeds in the shops), animals (at the rancher), building projects, workbench recipes
## (RecipeTable "level"), tool upgrades and, at the top, better orders. Crops follow
## the calendar of the first year: each opens in time for its season (10 days a
## season; early levels come about once a week). Anything not listed is open from the
## start. Plain data: autoloads, the balance simulation and the UI all read it.

const CROPS := {
	&"wheat": 1, &"carrot": 1, &"potato": 1, &"strawberry": 2, &"tomato": 2, &"corn": 3, &"eggplant": 4,
	&"pumpkin": 4,
}
## Hens come on the first day (the story buys two in town for the new coop).
const ANIMALS := {&"chicken": 1, &"sheep": 3, &"cow": 4, &"horse": 6}
## The repairs (house_1, warehouse_1) and the coop kit are open from the start.
const PROJECTS := {
	&"house_1": 1, &"warehouse_1": 1, &"field_1": 2, &"coop_1": 2, &"barn_1": 3, &"warehouse_2": 3,
	&"field_2": 4, &"coop_2": 5, &"house_2": 5, &"barn_2": 6, &"field_3": 7, &"house_3": 8,
}
## Farm level each tool upgrade (+1, +2) needs.
const TOOL_UPGRADES: Array[int] = [0, 3, 6]
## From this level the order board holds one more order.
const EXTRA_ORDER_LEVEL := 9
## From this level orders pay this much more.
const ORDER_BONUS_LEVEL := 10
const ORDER_BONUS := 0.25


static func crop_level(crop: StringName) -> int:
	return int(CROPS.get(crop, 1))


static func animal_level(species: StringName) -> int:
	return int(ANIMALS.get(species, 1))


static func project_level(id: StringName) -> int:
	return int(PROJECTS.get(id, 1))


## Level an item needs to be bought (seeds follow their crop).
static func item_level(id: StringName) -> int:
	var s := String(id)
	if s.ends_with("_seed"):
		return crop_level(StringName(s.trim_suffix("_seed")))
	return 1


## Ids of what `level` opens, by kind: crops, animals, recipes, projects, upgrades
## (1 or 2), and the order perks.
static func opened_at(level: int) -> Dictionary:
	var out := {"crops": [], "animals": [], "recipes": [], "projects": [], "upgrades": [],
		"order_slot": level == EXTRA_ORDER_LEVEL, "order_bonus": level == ORDER_BONUS_LEVEL}
	for crop: StringName in CROPS:
		if CROPS[crop] == level:
			out["crops"].append(crop)
	for species: StringName in ANIMALS:
		if ANIMALS[species] == level:
			out["animals"].append(species)
	for id: StringName in RecipeTable.CRAFT_ORDER:
		if int(RecipeTable.crafting(id)["level"]) == level:
			out["recipes"].append(id)
	for id: StringName in ProjectTable.ORDER:
		# Grandpa's old run is no longer sold (the coop comes as a kit now), nor its
		# upgrade on the farms that never had it.
		if id == &"coop_1" or not FarmState.is_listed(id):
			continue
		if int(PROJECTS.get(id, 1)) == level and level > 1:
			out["projects"].append(id)
	for i in range(1, TOOL_UPGRADES.size()):
		if TOOL_UPGRADES[i] == level:
			out["upgrades"].append(i)
	return out


## Order slots on the board and the reward multiplier at `level`.
static func order_slots(level: int, base: int) -> int:
	return base + (1 if level >= EXTRA_ORDER_LEVEL else 0)


static func order_bonus(level: int) -> float:
	return 1.0 + (ORDER_BONUS if level >= ORDER_BONUS_LEVEL else 0.0)
