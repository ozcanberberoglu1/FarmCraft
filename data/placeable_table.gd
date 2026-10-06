class_name PlaceableTable
extends RefCounted
## Things the player puts down on the farm: what kind of object each is and the
## footprint it takes (x wide, y tall, z deep, metres; used for the collision box and
## for checking that the spot is free).
## Buildings ("building": true) are put up from a kit: the footprint is their whole
## plot (the coop and the yard its hens scratch in), "reach" how far ahead the ghost
## goes, "build_seconds" the real seconds of play the site stands before it is
## finished, "build_id" their id in Events.construction_started/building_completed and
## "name_key" what the building is called. The workbench goes up the same way on a
## small plot (the bench and room to work at it; Workbench.BENCH is the bench itself),
## and the doghouse (Doghouse: the farmer's own dog's, half a minute's work).
## The campfire and the grills are put down anywhere outdoors (not in a building or a yard).

## A minute of work for each building put up from a kit.
const BUILD_SECONDS := 60.0
## The story's first coop and first workbench go up in ten seconds (Quests.build_seconds:
## the player is waiting on them with a goal up); every later one takes its usual time.
const TUTORIAL_BUILD_SECONDS := 10.0

const PLACEABLES := {
	&"workbench": {"kind": "workbench", "size": Vector3(2.4, 1.0, 1.6), "building": true, "reach": 7.0,
		"build_seconds": BUILD_SECONDS, "build_id": &"workbench", "name_key": "ITEM_WORKBENCH"},
	&"cheese_press": {"kind": "machine", "size": Vector3(0.9, 1.35, 0.7)},
	&"spinning_wheel": {"kind": "machine", "size": Vector3(0.55, 1.0, 1.05)},
	&"pickle_barrel": {"kind": "machine", "size": Vector3(0.78, 0.9, 0.78)},
	&"jam_kettle": {"kind": "machine", "size": Vector3(0.64, 1.1, 0.64)},
	&"quern": {"kind": "machine", "size": Vector3(1.0, 0.85, 1.0)},
	&"sprinkler": {"kind": "sprinkler", "size": Vector3(0.5, 0.35, 0.4)},
	## A ring of stones with logs laid in it: lit with E, it burns 5 in-game hours (see
	## scripts/camp/campfire.gd). Only on open ground: never under a roof, on a field or
	## on a track.
	&"campfire": {"kind": "campfire", "size": Vector3(1.15, 0.45, 1.15)},
	## Charcoal grills from the town market (Mangal, Büyük Mangal): put down outdoors like
	## the campfire and cooked on the same way, with six and twelve places on the grate
	## (scripts/placement/grill.gd, GrillModel).
	&"grill": {"kind": "grill", "size": Vector3(0.98, 0.8, 0.5)},
	&"big_grill": {"kind": "grill", "size": Vector3(1.78, 0.95, 0.6)},
	## The food table (Yemek Tezgahı): a butcher's table where a fish or game is cleaned
	## with a knife before it is cooked (scripts/placement/food_table.gd).
	&"food_table": {"kind": "food_table", "size": Vector3(1.62, 0.96, 0.78)},
	## The mailbox on its post (scripts/placement/mailbox.gd): letters from the town (Mail).
	&"mailbox": {"kind": "mailbox", "size": Vector3(0.36, 1.25, 0.5)},
	&"coop_kit": {"kind": "coop", "size": Vector3(11.0, 2.8, 10.0), "building": true, "reach": 12.0,
		"build_seconds": BUILD_SECONDS, "build_id": &"coop", "name_key": "HOUSING_COOP"},
	## The dog's house (scripts/placement/doghouse.gd): its plot is the house itself and a
	## step of ground round it; the dog's doorstep is in front of its door (+Z).
	&"doghouse": {"kind": "doghouse", "size": Vector3(1.6, 1.2, 1.8), "building": true, "reach": 5.5,
		"build_seconds": 30.0, "build_id": &"doghouse", "name_key": "ITEM_DOGHOUSE"},
}


static func get_info(id: StringName) -> Dictionary:
	return PLACEABLES.get(id, {})


static func is_placeable(id: StringName) -> bool:
	return PLACEABLES.has(id)


static func is_building(id: StringName) -> bool:
	return bool(get_info(id).get("building", false))


## Real seconds a building of `id` usually takes to go up (the one being put down now:
## Quests.build_seconds; one going up: its own build_seconds(), kept in its entry).
static func build_seconds(id: StringName) -> float:
	return float(get_info(id).get("build_seconds", BUILD_SECONDS))
