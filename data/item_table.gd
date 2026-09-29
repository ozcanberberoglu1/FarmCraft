class_name ItemTable
extends RefCounted
## Every item in the game. Prices in dollars (docs/BALANCE.md; tools/balance_sim.gd plays
## them through).
## Names come from the translation keys ITEM_<ID> / DESC_<ID>.
##
## Fields: cat, stack, sell, buy, dur (max durability), tool, crop (seeds), water (can capacity)

const ITEMS := {
	# Tools
	&"hoe": {"cat": "tool", "stack": 1, "sell": 0, "buy": 40, "dur": 150, "tool": &"hoe"},
	&"watering_can": {"cat": "tool", "stack": 1, "sell": 0, "buy": 50, "dur": 200, "tool": &"watering_can", "water": 12},
	&"scythe": {"cat": "tool", "stack": 1, "sell": 0, "buy": 40, "dur": 150, "tool": &"scythe"},
	&"pickaxe": {"cat": "tool", "stack": 1, "sell": 0, "buy": 40, "dur": 120, "tool": &"pickaxe"},
	&"axe": {"cat": "tool", "stack": 1, "sell": 0, "buy": 40, "dur": 120, "tool": &"axe"},
	&"milk_pail": {"cat": "tool", "stack": 1, "sell": 0, "buy": 75, "dur": 0, "tool": &"milk_pail"},
	&"shears": {"cat": "tool", "stack": 1, "sell": 0, "buy": 90, "dur": 200, "tool": &"shears"},
	&"brush": {"cat": "tool", "stack": 1, "sell": 0, "buy": 40, "dur": 0, "tool": &"brush"},
	&"pitchfork": {"cat": "tool", "stack": 1, "sell": 0, "buy": 50, "dur": 200, "tool": &"pitchfork"},
	## Grandpa's pickup key (kept in the desk drawer).
	&"truck_key": {"cat": "key", "stack": 1, "sell": 0, "buy": 0},

	# Seeds
	&"wheat_seed": {"cat": "seed", "stack": 99, "sell": 1, "buy": 1, "crop": &"wheat"},
	&"carrot_seed": {"cat": "seed", "stack": 99, "sell": 1, "buy": 2, "crop": &"carrot"},
	&"potato_seed": {"cat": "seed", "stack": 99, "sell": 1, "buy": 2, "crop": &"potato"},
	&"tomato_seed": {"cat": "seed", "stack": 99, "sell": 2, "buy": 5, "crop": &"tomato"},
	&"corn_seed": {"cat": "seed", "stack": 99, "sell": 2, "buy": 4, "crop": &"corn"},
	&"eggplant_seed": {"cat": "seed", "stack": 99, "sell": 3, "buy": 6, "crop": &"eggplant"},
	&"strawberry_seed": {"cat": "seed", "stack": 99, "sell": 5, "buy": 10, "crop": &"strawberry"},
	&"pumpkin_seed": {"cat": "seed", "stack": 99, "sell": 6, "buy": 12, "crop": &"pumpkin"},

	# Crops
	&"wheat": {"cat": "crop", "stack": 99, "sell": 2, "buy": 0},
	&"carrot": {"cat": "crop", "stack": 99, "sell": 4, "buy": 0},
	&"potato": {"cat": "crop", "stack": 99, "sell": 3, "buy": 0},
	&"tomato": {"cat": "crop", "stack": 99, "sell": 3, "buy": 0},
	&"corn": {"cat": "crop", "stack": 99, "sell": 4, "buy": 0},
	&"eggplant": {"cat": "crop", "stack": 99, "sell": 5, "buy": 0},
	&"strawberry": {"cat": "crop", "stack": 99, "sell": 5, "buy": 0},
	&"pumpkin": {"cat": "crop", "stack": 20, "sell": 45, "buy": 0},

	# Resources
	&"wood": {"cat": "resource", "stack": 99, "sell": 1, "buy": 2},
	&"stone": {"cat": "resource", "stack": 99, "sell": 1, "buy": 2},
	&"iron_ore": {"cat": "resource", "stack": 99, "sell": 2, "buy": 6},
	&"hay": {"cat": "feed", "stack": 99, "sell": 1, "buy": 3},

	# Livestock supplies and products
	&"feed": {"cat": "feed", "stack": 99, "sell": 1, "buy": 1},
	&"medicine": {"cat": "feed", "stack": 20, "sell": 8, "buy": 20},
	&"egg": {"cat": "animal_product", "stack": 99, "sell": 5, "buy": 0},
	## A live hen in a wooden crate (bought in town, released at a coop).
	&"chicken_crate": {"cat": "animal", "stack": 4, "sell": 0, "buy": 0},
	&"milk": {"cat": "animal_product", "stack": 99, "sell": 13, "buy": 0},
	&"wool": {"cat": "animal_product", "stack": 99, "sell": 30, "buy": 0},

	# Farming supplies: fertilizer and manure make crops grow faster and better
	&"fertilizer": {"cat": "supply", "stack": 99, "sell": 2, "buy": 5},
	&"manure": {"cat": "supply", "stack": 99, "sell": 1, "buy": 0},

	# Artisan goods, made in the machines
	&"cheese": {"cat": "artisan", "stack": 99, "sell": 50, "buy": 0},
	&"yarn": {"cat": "artisan", "stack": 99, "sell": 45, "buy": 0},
	&"pickles": {"cat": "artisan", "stack": 99, "sell": 36, "buy": 0},
	&"jam": {"cat": "artisan", "stack": 99, "sell": 35, "buy": 0},
	&"tomato_paste": {"cat": "artisan", "stack": 99, "sell": 32, "buy": 0},
	&"flour": {"cat": "artisan", "stack": 99, "sell": 17, "buy": 0},

	# Placeables (put down with the placement preview; made at the workbench)
	&"workbench": {"cat": "placeable", "stack": 1, "sell": 15, "buy": 40},
	## A chicken coop to put down (crafted on the construction board, then built on site).
	&"coop_kit": {"cat": "placeable", "stack": 1, "sell": 0, "buy": 0},
	&"cheese_press": {"cat": "placeable", "stack": 5, "sell": 40, "buy": 0},
	&"spinning_wheel": {"cat": "placeable", "stack": 5, "sell": 40, "buy": 0},
	&"pickle_barrel": {"cat": "placeable", "stack": 5, "sell": 25, "buy": 0},
	&"jam_kettle": {"cat": "placeable", "stack": 5, "sell": 30, "buy": 0},
	&"quern": {"cat": "placeable", "stack": 5, "sell": 20, "buy": 0},
	&"sprinkler": {"cat": "placeable", "stack": 20, "sell": 10, "buy": 0},
}

const CATEGORY_KEYS := {
	"tool": "CAT_TOOL", "seed": "CAT_SEED", "crop": "CAT_CROP", "resource": "CAT_RESOURCE",
	"feed": "CAT_FEED", "animal_product": "CAT_ANIMAL_PRODUCT", "artisan": "CAT_ARTISAN",
	"placeable": "CAT_PLACEABLE", "supply": "CAT_SUPPLY", "key": "CAT_KEY", "animal": "CAT_ANIMAL",
}

## Items the player starts a new game with: [id, count]
const STARTING_ITEMS := [
	[&"hoe", 1], [&"watering_can", 1], [&"scythe", 1], [&"pickaxe", 1], [&"axe", 1],
	[&"wheat_seed", 10], [&"potato_seed", 5],
]
