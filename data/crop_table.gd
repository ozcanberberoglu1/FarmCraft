class_name CropTable
extends RefCounted
## Growth data for every crop (see docs/PLAN.md, economy section). Times are in
## in-game hours; a crop only grows while its soil is wet.
##
## grow_h:   hours from planting to the first harvest
## regrow_h: hours between later harvests (0 = single harvest, plot is cleared)
## yield:    [min, max] items per harvest
## extra:    optional byproduct [item_id, count]
## seasons:  seasons the crop can grow in (0 spring, 1 summer, 2 autumn, 3 winter)

const CROPS := {
	&"wheat": {"grow_h": 20, "regrow_h": 0, "yield": [2, 2], "item": &"wheat", "extra": [&"hay", 1], "seasons": [0, 1, 2]},
	&"carrot": {"grow_h": 36, "regrow_h": 0, "yield": [2, 2], "item": &"carrot", "seasons": [0, 2]},
	&"potato": {"grow_h": 48, "regrow_h": 0, "yield": [2, 4], "item": &"potato", "seasons": [0, 2]},
	&"tomato": {"grow_h": 72, "regrow_h": 36, "yield": [3, 3], "item": &"tomato", "seasons": [1]},
	&"corn": {"grow_h": 84, "regrow_h": 48, "yield": [2, 2], "item": &"corn", "seasons": [1, 2]},
	&"eggplant": {"grow_h": 60, "regrow_h": 48, "yield": [2, 2], "item": &"eggplant", "seasons": [1, 2]},
	&"strawberry": {"grow_h": 96, "regrow_h": 48, "yield": [3, 3], "item": &"strawberry", "seasons": [0]},
	&"pumpkin": {"grow_h": 144, "regrow_h": 0, "yield": [1, 1], "item": &"pumpkin", "seasons": [2]},
}

## Watered soil stays wet this long.
const WET_HOURS := 24.0
## A crop left dry for this long withers.
const WITHER_HOURS := 48.0
## Visual growth stages: 0 sprout, 1 young, 2 growing, 3 ready.
const STAGES := 4


static func get_crop(id: StringName) -> Dictionary:
	return CROPS.get(id, {})


static func in_season(id: StringName, season: int) -> bool:
	return season in CROPS.get(id, {}).get("seasons", [])
