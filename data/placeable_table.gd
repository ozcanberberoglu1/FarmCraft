class_name PlaceableTable
extends RefCounted
## Things the player puts down on the farm: what kind of object each is and the
## footprint it takes (x wide, y tall, z deep, metres; used for the collision box and
## for checking that the spot is free).
## Buildings ("building": true) are put up from a kit: the footprint is their whole
## plot (the coop and the yard its hens scratch in), "reach" how far ahead the ghost
## goes, "build_seconds" the real seconds of play the site stands before it is
## finished, "build_id" their id in Events.construction_started/building_completed and
## "name_key" what the building is called.

const PLACEABLES := {
	&"workbench": {"kind": "workbench", "size": Vector3(1.9, 1.0, 0.85)},
	&"cheese_press": {"kind": "machine", "size": Vector3(0.9, 1.35, 0.7)},
	&"spinning_wheel": {"kind": "machine", "size": Vector3(0.55, 1.0, 1.05)},
	&"pickle_barrel": {"kind": "machine", "size": Vector3(0.78, 0.9, 0.78)},
	&"jam_kettle": {"kind": "machine", "size": Vector3(0.64, 1.1, 0.64)},
	&"quern": {"kind": "machine", "size": Vector3(1.0, 0.85, 1.0)},
	&"sprinkler": {"kind": "sprinkler", "size": Vector3(0.5, 0.35, 0.4)},
	&"coop_kit": {"kind": "coop", "size": Vector3(11.0, 2.8, 10.0), "building": true, "reach": 12.0,
		"build_seconds": 180.0, "build_id": &"coop", "name_key": "HOUSING_COOP"},
}


static func get_info(id: StringName) -> Dictionary:
	return PLACEABLES.get(id, {})


static func is_placeable(id: StringName) -> bool:
	return PLACEABLES.has(id)


static func is_building(id: StringName) -> bool:
	return bool(get_info(id).get("building", false))
