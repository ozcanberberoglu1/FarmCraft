class_name ProjectTable
extends RefCounted
## Everything that can be built from the construction board.
## cost: dollars (the coop kit of the first day fits what two hens leave of the
## starting money); items: materials taken from the player's inventory;
## requires: projects that must be built first.
## kit: the board cuts and bundles a building kit instead of building on the spot; the
## kit goes into the bag and is put up wherever the player places it (and can be made
## again for another one).
## hands_on: not on the board; built by hand in the world (Grandpa's house and warehouse
## are repaired by nailing wood over the holes in their walls, see RepairSpot), free.
## per_coop: made on one of the farm's kit-built coops, step by step (the coop
## expansion: COOP_STEPS prices each step; the board picks the coop), never "built".
## Names/descriptions come from PROJECT_<ID> / PROJECT_<ID>_DESC.

const PROJECTS := {
	&"field_1": {"cost": 250, "items": {}, "requires": [], "group": "field"},
	&"field_2": {"cost": 900, "items": {&"wood": 30}, "requires": [&"field_1"], "group": "field"},
	&"field_3": {"cost": 2400, "items": {&"wood": 60, &"stone": 30}, "requires": [&"field_2"], "group": "field"},
	&"coop_kit": {"cost": 25, "items": {&"wood": 15}, "requires": [], "group": "animals", "kit": &"coop_kit"},
	# A kit-built coop made longer (ChickenCoop's expansion), one coop and one step at a
	# time: its cost here is the first step's (COOP_STEPS has both).
	&"coop_expand": {"cost": 100, "items": {&"wood": 20, &"nails": 10}, "requires": [], "group": "animals", "per_coop": true},
	# The second day's workbench: a kit like the coop's, put up near the house in a minute.
	&"workbench": {"cost": 40, "items": {&"wood": 10}, "requires": [], "group": "workshop", "kit": &"workbench"},
	# Grandpa's fixed chicken run by the fields: no longer sold, kept for the farms that have it.
	&"coop_1": {"cost": 125, "items": {&"wood": 30}, "requires": [], "group": "animals"},
	&"coop_2": {"cost": 600, "items": {&"wood": 80, &"stone": 40}, "requires": [&"coop_1"], "group": "animals"},
	&"barn_1": {"cost": 200, "items": {&"wood": 50}, "requires": [], "group": "animals"},
	&"barn_2": {"cost": 1350, "items": {&"wood": 150, &"stone": 80}, "requires": [&"barn_1"], "group": "animals"},
	# Grandpa's run-down house and warehouse are repaired by hand, one wood a hole.
	&"house_1": {"cost": 0, "items": {}, "requires": [], "group": "house", "hands_on": true},
	&"house_2": {"cost": 1500, "items": {&"wood": 120, &"stone": 40}, "requires": [&"house_1"], "group": "house"},
	&"house_3": {"cost": 4500, "items": {&"wood": 200, &"stone": 100, &"iron_ore": 20}, "requires": [&"house_2"], "group": "house"},
	&"warehouse_1": {"cost": 0, "items": {}, "requires": [], "group": "storage", "hands_on": true},
	&"warehouse_2": {"cost": 900, "items": {&"wood": 80, &"stone": 40}, "requires": [&"warehouse_1"], "group": "storage"},
}

## Order shown on the board (hands-on projects are left off it).
const ORDER := [&"workbench", &"house_1", &"house_2", &"house_3", &"warehouse_1", &"warehouse_2", &"field_1", &"field_2", &"field_3",
	&"barn_1", &"barn_2", &"coop_kit", &"coop_expand", &"coop_1", &"coop_2"]
## Warehouse capacity in units per level (0 = Grandpa's run-down shed, half its racks
## rotten; 1 = repaired; 2 = bigger).
const WAREHOUSE_CAPACITY := [200, 400, 1200]

## Animal housing capacity per level (0 = not built).
const BARN_CAPACITY := [0, 4, 8]
const COOP_CAPACITY := [0, 4, 8]
## A kit-built coop's places by its expansion steps (ChickenCoop.expansion): 8 as it
## comes, 14 and 20 made longer.
const KIT_COOP_CAPACITY: Array[int] = [8, 14, 20]
## What each expansion step costs (the farm level it needs: UnlockTable.COOP_EXPANSION).
## Dearer a place than a second kit, which is the first day's price: one coop longer
## keeps one door to shut against the wolves, one feeder and one yard.
const COOP_STEPS: Array[Dictionary] = [
	{"cost": 100, "items": {&"wood": 20, &"nails": 10}},
	{"cost": 200, "items": {&"wood": 35, &"nails": 20, &"stone": 10}},
]


static func get_project(id: StringName) -> Dictionary:
	return PROJECTS.get(id, {})


## The kit this project makes (&"" for projects built on the spot).
static func kit_of(id: StringName) -> StringName:
	return StringName(get_project(id).get("kit", &""))


## True for the projects made on one of the farm's coops (the expansion), never built.
static func is_per_coop(id: StringName) -> bool:
	return bool(get_project(id).get("per_coop", false))


## Expansion step `step` (0: the first) of a kit-built coop: {cost, items}; {} past the last.
static func coop_step(step: int) -> Dictionary:
	return COOP_STEPS[step] if step >= 0 and step < COOP_STEPS.size() else {}


## True for the projects built by hand in the world, never from the board.
static func is_hands_on(id: StringName) -> bool:
	return bool(get_project(id).get("hands_on", false))
