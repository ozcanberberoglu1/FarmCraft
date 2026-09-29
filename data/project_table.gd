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
## Names/descriptions come from PROJECT_<ID> / PROJECT_<ID>_DESC.

const PROJECTS := {
	&"field_1": {"cost": 250, "items": {}, "requires": [], "group": "field"},
	&"field_2": {"cost": 900, "items": {&"wood": 30}, "requires": [&"field_1"], "group": "field"},
	&"field_3": {"cost": 2400, "items": {&"wood": 60, &"stone": 30}, "requires": [&"field_2"], "group": "field"},
	&"coop_kit": {"cost": 25, "items": {&"wood": 15}, "requires": [], "group": "animals", "kit": &"coop_kit"},
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
const ORDER := [&"house_1", &"house_2", &"house_3", &"warehouse_1", &"warehouse_2", &"field_1", &"field_2", &"field_3",
	&"barn_1", &"barn_2", &"coop_kit", &"coop_1", &"coop_2"]
## Warehouse capacity in units per level (0 = Grandpa's run-down shed, half its racks
## rotten; 1 = repaired; 2 = bigger).
const WAREHOUSE_CAPACITY := [200, 400, 1200]

## Animal housing capacity per level (0 = not built).
const BARN_CAPACITY := [0, 4, 8]
const COOP_CAPACITY := [0, 4, 8]


static func get_project(id: StringName) -> Dictionary:
	return PROJECTS.get(id, {})


## The kit this project makes (&"" for projects built on the spot).
static func kit_of(id: StringName) -> StringName:
	return StringName(get_project(id).get("kit", &""))


## True for the projects built by hand in the world, never from the board.
static func is_hands_on(id: StringName) -> bool:
	return bool(get_project(id).get("hands_on", false))
