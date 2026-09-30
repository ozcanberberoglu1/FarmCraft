class_name ItemTable
extends RefCounted
## Every item in the game. Prices in dollars (docs/BALANCE.md; tools/balance_sim.gd plays
## them through).
## Names come from the translation keys ITEM_<ID> / DESC_<ID>.
##
## Fields: cat, stack, sell, buy, dur (max durability), tool, crop (seeds), water (can capacity),
## food (hunger points restored when eaten with the right mouse button; food > 0 is edible)

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
	&"carrot": {"cat": "crop", "stack": 99, "sell": 4, "buy": 0, "food": 8},
	&"potato": {"cat": "crop", "stack": 99, "sell": 3, "buy": 0, "food": 4},
	&"tomato": {"cat": "crop", "stack": 99, "sell": 3, "buy": 0, "food": 6},
	&"corn": {"cat": "crop", "stack": 99, "sell": 4, "buy": 0, "food": 7},
	&"eggplant": {"cat": "crop", "stack": 99, "sell": 5, "buy": 0},
	&"strawberry": {"cat": "crop", "stack": 99, "sell": 5, "buy": 0, "food": 5},
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
	&"milk": {"cat": "animal_product", "stack": 99, "sell": 13, "buy": 0, "food": 10},
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
	## A workbench kit (the construction board cuts one for $40 and 10 wood, the town
	## market sells it ready bundled); put up near the house like the coop kit.
	&"workbench": {"cat": "placeable", "stack": 1, "sell": 15, "buy": 55},
	## A chicken coop to put down (crafted on the construction board, then built on site).
	&"coop_kit": {"cat": "placeable", "stack": 1, "sell": 0, "buy": 0},
	&"cheese_press": {"cat": "placeable", "stack": 5, "sell": 40, "buy": 0},
	&"spinning_wheel": {"cat": "placeable", "stack": 5, "sell": 40, "buy": 0},
	&"pickle_barrel": {"cat": "placeable", "stack": 5, "sell": 25, "buy": 0},
	&"jam_kettle": {"cat": "placeable", "stack": 5, "sell": 30, "buy": 0},
	&"quern": {"cat": "placeable", "stack": 5, "sell": 20, "buy": 0},
	&"sprinkler": {"cat": "placeable", "stack": 20, "sell": 10, "buy": 0},

	# Made at the workbench (RecipeTable): the first tools, the campfire, their materials
	# (nails and rope from the town market) and bait for the rod (docs/BALANCE.md).
	## A short fish knife: guts and fillets the catch.
	&"knife": {"cat": "tool", "stack": 1, "sell": 0, "buy": 0, "dur": 200, "tool": &"knife"},
	&"bow": {"cat": "tool", "stack": 1, "sell": 0, "buy": 0, "dur": 250, "tool": &"bow"},
	## The standard rod (FishTable.RODS: the cane pole, carbon and carp rods further down).
	## Every cast wears it by one.
	&"fishing_rod": {"cat": "tool", "stack": 1, "sell": 0, "buy": 0, "dur": 150, "tool": &"fishing_rod"},
	## A bundle of split logs and hearth stones: put down outdoors, it burns five hours.
	&"campfire": {"cat": "placeable", "stack": 5, "sell": 0, "buy": 0},
	&"nails": {"cat": "material", "stack": 99, "sell": 0, "buy": 1},
	&"rope": {"cat": "material", "stack": 20, "sell": 1, "buy": 4},
	&"worm": {"cat": "bait", "stack": 99, "sell": 0, "buy": 1},
	&"dough": {"cat": "bait", "stack": 99, "sell": 0, "buy": 1},
	## A young tree dropped by a felled one: planted and watered it grows into a tree.
	&"sapling": {"cat": "sapling", "stack": 20, "sell": 2, "buy": 0},

	# --- POULTRY agent: the rooster (eggs left under a rooster stay the plain "egg"; the
	# coop keeps which ones are fertile) ---
	## A live rooster in a wooden crate (bought at the animal market, let out at a coop).
	&"rooster_crate": {"cat": "animal", "stack": 4, "sell": 0, "buy": 0},
	# --- NATURE: wild food of the land ---
	# Berries picked off the wild bushes at the forest's edge (BerryBush, a handful at a
	# time): eaten from the hand with the right mouse button or sold. A wild rabbit caught
	# by hand after a chase (WildRabbit): sold, or cleaned into meat at the food table.
	&"blueberry": {"cat": "forage", "stack": 50, "sell": 2, "buy": 0, "food": 5},
	&"blackberry": {"cat": "forage", "stack": 50, "sell": 2, "buy": 0, "food": 5},
	&"raspberry": {"cat": "forage", "stack": 50, "sell": 3, "buy": 0, "food": 4},
	&"rosehip": {"cat": "forage", "stack": 50, "sell": 2, "buy": 0, "food": 3},
	&"rabbit": {"cat": "game", "stack": 5, "sell": 15, "buy": 0},
	# --- end NATURE ---
	# --- FOOD agent: the food table, the catch cleaned on it, meat and trophy fish ---
	## The food table (Yemek Tezgahı): a butcher's table put down on the farm. A fish or
	## game laid on it is cleaned with a knife from the bag (scripts/placement/food_table.gd).
	&"food_table": {"cat": "placeable", "stack": 1, "sell": 20, "buy": 0},
	# Cleaned at the food table: the fish headed and gutted, the game cut into meat. They
	# cook on the campfire into <id>_cooked, which fills far more than a whole grilled
	# fish (Campfire.cooked_id).
	&"fish_rudd_cleaned": {"cat": "fish", "stack": 20, "sell": 3, "buy": 0},
	&"fish_crucian_cleaned": {"cat": "fish", "stack": 20, "sell": 3, "buy": 0},
	&"fish_perch_cleaned": {"cat": "fish", "stack": 20, "sell": 4, "buy": 0},
	&"fish_carp_cleaned": {"cat": "fish", "stack": 10, "sell": 9, "buy": 0},
	&"fish_tench_cleaned": {"cat": "fish", "stack": 10, "sell": 10, "buy": 0},
	&"fish_trout_cleaned": {"cat": "fish", "stack": 10, "sell": 16, "buy": 0},
	&"fish_zander_cleaned": {"cat": "fish", "stack": 10, "sell": 22, "buy": 0},
	&"fish_pike_cleaned": {"cat": "fish", "stack": 5, "sell": 30, "buy": 0},
	&"fish_catfish_cleaned": {"cat": "fish", "stack": 5, "sell": 55, "buy": 0},
	&"fish_rudd_cleaned_cooked": {"cat": "food", "stack": 20, "sell": 5, "buy": 0, "food": 33},
	&"fish_crucian_cleaned_cooked": {"cat": "food", "stack": 20, "sell": 5, "buy": 0, "food": 33},
	&"fish_perch_cleaned_cooked": {"cat": "food", "stack": 20, "sell": 6, "buy": 0, "food": 40},
	&"fish_carp_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 13, "buy": 0, "food": 70},
	&"fish_tench_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 14, "buy": 0, "food": 62},
	&"fish_trout_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 22, "buy": 0, "food": 66},
	&"fish_zander_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 30, "buy": 0, "food": 75},
	&"fish_pike_cleaned_cooked": {"cat": "food", "stack": 5, "sell": 40, "buy": 0, "food": 88},
	&"fish_catfish_cleaned_cooked": {"cat": "food", "stack": 5, "sell": 72, "buy": 0, "food": 100},
	&"rabbit_meat": {"cat": "meat", "stack": 20, "sell": 4, "buy": 0},
	&"rabbit_meat_cooked": {"cat": "food", "stack": 20, "sell": 8, "buy": 0, "food": 32},
	# Trophy fish: now and then a giant of its species bites (FishTable.TROPHY_CHANCE), ten
	# times the weight, sold for ten times the price.
	&"fish_rudd_trophy": {"cat": "fish", "stack": 5, "sell": 30, "buy": 0},
	&"fish_crucian_trophy": {"cat": "fish", "stack": 5, "sell": 30, "buy": 0},
	&"fish_perch_trophy": {"cat": "fish", "stack": 5, "sell": 40, "buy": 0},
	&"fish_crayfish_trophy": {"cat": "fish", "stack": 5, "sell": 60, "buy": 0},
	&"fish_carp_trophy": {"cat": "fish", "stack": 5, "sell": 90, "buy": 0},
	&"fish_tench_trophy": {"cat": "fish", "stack": 5, "sell": 100, "buy": 0},
	&"fish_trout_trophy": {"cat": "fish", "stack": 5, "sell": 160, "buy": 0},
	&"fish_zander_trophy": {"cat": "fish", "stack": 5, "sell": 220, "buy": 0},
	&"fish_pike_trophy": {"cat": "fish", "stack": 5, "sell": 300, "buy": 0},
	&"fish_catfish_trophy": {"cat": "fish", "stack": 5, "sell": 550, "buy": 0},
	# --- end FOOD agent ---

	# Fish (see data/fish_table.gd): caught in the pond with the fishing rod, sold in the
	# shipping bin (rarer fish pay more) or cooked on the campfire into <id>_cooked, which
	# restores "food" hunger points when eaten. The old boot is junk.
	&"fish_rudd": {"cat": "fish", "stack": 20, "sell": 3, "buy": 0},
	&"fish_crucian": {"cat": "fish", "stack": 20, "sell": 3, "buy": 0},
	&"fish_perch": {"cat": "fish", "stack": 20, "sell": 4, "buy": 0},
	&"fish_crayfish": {"cat": "fish", "stack": 20, "sell": 6, "buy": 0},
	&"fish_carp": {"cat": "fish", "stack": 10, "sell": 9, "buy": 0},
	&"fish_tench": {"cat": "fish", "stack": 10, "sell": 10, "buy": 0},
	&"fish_trout": {"cat": "fish", "stack": 10, "sell": 16, "buy": 0},
	&"fish_zander": {"cat": "fish", "stack": 10, "sell": 22, "buy": 0},
	&"fish_pike": {"cat": "fish", "stack": 5, "sell": 30, "buy": 0},
	&"fish_catfish": {"cat": "fish", "stack": 5, "sell": 55, "buy": 0},
	&"fish_rudd_cooked": {"cat": "food", "stack": 20, "sell": 5, "buy": 0, "food": 15},
	&"fish_crucian_cooked": {"cat": "food", "stack": 20, "sell": 5, "buy": 0, "food": 15},
	&"fish_perch_cooked": {"cat": "food", "stack": 20, "sell": 6, "buy": 0, "food": 18},
	&"fish_crayfish_cooked": {"cat": "food", "stack": 20, "sell": 9, "buy": 0, "food": 12},
	&"fish_carp_cooked": {"cat": "food", "stack": 10, "sell": 13, "buy": 0, "food": 32},
	&"fish_tench_cooked": {"cat": "food", "stack": 10, "sell": 14, "buy": 0, "food": 28},
	&"fish_trout_cooked": {"cat": "food", "stack": 10, "sell": 22, "buy": 0, "food": 30},
	&"fish_zander_cooked": {"cat": "food", "stack": 10, "sell": 30, "buy": 0, "food": 34},
	&"fish_pike_cooked": {"cat": "food", "stack": 5, "sell": 40, "buy": 0, "food": 40},
	&"fish_catfish_cooked": {"cat": "food", "stack": 5, "sell": 72, "buy": 0, "food": 55},
	&"old_boot": {"cat": "junk", "stack": 5, "sell": 1, "buy": 0},
	# --- FISHING: rods, bait and the lake's other fish (FishTable) ---
	# Rods made at the workbench: a cane pole (a little wood and rope: short casts, soon
	# worn out), the standard rod (above), a carbon spinning rod and a carp rod (nails and
	# iron for the reel: far casts, long-lasting, the giants hold). Each cast wears one by 1.
	&"cane_rod": {"cat": "tool", "stack": 1, "sell": 0, "buy": 0, "dur": 50, "tool": &"fishing_rod"},
	&"carbon_rod": {"cat": "tool", "stack": 1, "sell": 0, "buy": 0, "dur": 320, "tool": &"fishing_rod"},
	&"carp_rod": {"cat": "tool", "stack": 1, "sell": 0, "buy": 0, "dur": 500, "tool": &"fishing_rod"},
	# Bait at the town market (worms and dough above): each draws its own fish.
	&"maggot": {"cat": "bait", "stack": 99, "sell": 0, "buy": 2},
	&"sweetcorn": {"cat": "bait", "stack": 99, "sell": 0, "buy": 2},
	&"cheese_bait": {"cat": "bait", "stack": 99, "sell": 0, "buy": 3},
	&"minnow": {"cat": "bait", "stack": 20, "sell": 0, "buy": 4},
	## A spinner lure: not eaten, it goes on casting until it snags or a fish takes it.
	&"spinner": {"cat": "bait", "stack": 10, "sell": 0, "buy": 15},
	# The fish (raw, grilled whole, cleaned, cleaned and grilled, and the trophy giant).
	&"fish_roach": {"cat": "fish", "stack": 20, "sell": 3, "buy": 0},
	&"fish_roach_cooked": {"cat": "food", "stack": 20, "sell": 5, "buy": 0, "food": 15},
	&"fish_roach_cleaned": {"cat": "fish", "stack": 20, "sell": 3, "buy": 0},
	&"fish_roach_cleaned_cooked": {"cat": "food", "stack": 20, "sell": 5, "buy": 0, "food": 33},
	&"fish_roach_trophy": {"cat": "fish", "stack": 5, "sell": 30, "buy": 0},
	&"fish_bleak": {"cat": "fish", "stack": 20, "sell": 2, "buy": 0},
	&"fish_bleak_cooked": {"cat": "food", "stack": 20, "sell": 3, "buy": 0, "food": 8},
	&"fish_bleak_cleaned": {"cat": "fish", "stack": 20, "sell": 2, "buy": 0},
	&"fish_bleak_cleaned_cooked": {"cat": "food", "stack": 20, "sell": 3, "buy": 0, "food": 18},
	&"fish_bleak_trophy": {"cat": "fish", "stack": 5, "sell": 20, "buy": 0},
	&"fish_gudgeon": {"cat": "fish", "stack": 20, "sell": 2, "buy": 0},
	&"fish_gudgeon_cooked": {"cat": "food", "stack": 20, "sell": 3, "buy": 0, "food": 8},
	&"fish_gudgeon_cleaned": {"cat": "fish", "stack": 20, "sell": 2, "buy": 0},
	&"fish_gudgeon_cleaned_cooked": {"cat": "food", "stack": 20, "sell": 3, "buy": 0, "food": 18},
	&"fish_gudgeon_trophy": {"cat": "fish", "stack": 5, "sell": 20, "buy": 0},
	&"fish_bream": {"cat": "fish", "stack": 10, "sell": 6, "buy": 0},
	&"fish_bream_cooked": {"cat": "food", "stack": 10, "sell": 9, "buy": 0, "food": 26},
	&"fish_bream_cleaned": {"cat": "fish", "stack": 10, "sell": 6, "buy": 0},
	&"fish_bream_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 9, "buy": 0, "food": 57},
	&"fish_bream_trophy": {"cat": "fish", "stack": 5, "sell": 60, "buy": 0},
	&"fish_chub": {"cat": "fish", "stack": 10, "sell": 7, "buy": 0},
	&"fish_chub_cooked": {"cat": "food", "stack": 10, "sell": 10, "buy": 0, "food": 26},
	&"fish_chub_cleaned": {"cat": "fish", "stack": 10, "sell": 7, "buy": 0},
	&"fish_chub_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 10, "buy": 0, "food": 57},
	&"fish_chub_trophy": {"cat": "fish", "stack": 5, "sell": 70, "buy": 0},
	&"fish_barbel": {"cat": "fish", "stack": 10, "sell": 12, "buy": 0},
	&"fish_barbel_cooked": {"cat": "food", "stack": 10, "sell": 17, "buy": 0, "food": 34},
	&"fish_barbel_cleaned": {"cat": "fish", "stack": 10, "sell": 12, "buy": 0},
	&"fish_barbel_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 17, "buy": 0, "food": 75},
	&"fish_barbel_trophy": {"cat": "fish", "stack": 5, "sell": 120, "buy": 0},
	&"fish_eel": {"cat": "fish", "stack": 10, "sell": 16, "buy": 0},
	&"fish_eel_cooked": {"cat": "food", "stack": 10, "sell": 22, "buy": 0, "food": 36},
	&"fish_eel_cleaned": {"cat": "fish", "stack": 10, "sell": 16, "buy": 0},
	&"fish_eel_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 22, "buy": 0, "food": 79},
	&"fish_eel_trophy": {"cat": "fish", "stack": 5, "sell": 160, "buy": 0},
	&"fish_grass_carp": {"cat": "fish", "stack": 5, "sell": 15, "buy": 0},
	&"fish_grass_carp_cooked": {"cat": "food", "stack": 5, "sell": 21, "buy": 0, "food": 42},
	&"fish_grass_carp_cleaned": {"cat": "fish", "stack": 5, "sell": 15, "buy": 0},
	&"fish_grass_carp_cleaned_cooked": {"cat": "food", "stack": 5, "sell": 21, "buy": 0, "food": 92},
	&"fish_grass_carp_trophy": {"cat": "fish", "stack": 5, "sell": 150, "buy": 0},
	&"fish_silver_carp": {"cat": "fish", "stack": 5, "sell": 12, "buy": 0},
	&"fish_silver_carp_cooked": {"cat": "food", "stack": 5, "sell": 17, "buy": 0, "food": 40},
	&"fish_silver_carp_cleaned": {"cat": "fish", "stack": 5, "sell": 12, "buy": 0},
	&"fish_silver_carp_cleaned_cooked": {"cat": "food", "stack": 5, "sell": 17, "buy": 0, "food": 88},
	&"fish_silver_carp_trophy": {"cat": "fish", "stack": 5, "sell": 120, "buy": 0},
	&"fish_brown_trout": {"cat": "fish", "stack": 10, "sell": 20, "buy": 0},
	&"fish_brown_trout_cooked": {"cat": "food", "stack": 10, "sell": 28, "buy": 0, "food": 30},
	&"fish_brown_trout_cleaned": {"cat": "fish", "stack": 10, "sell": 20, "buy": 0},
	&"fish_brown_trout_cleaned_cooked": {"cat": "food", "stack": 10, "sell": 28, "buy": 0, "food": 66},
	&"fish_brown_trout_trophy": {"cat": "fish", "stack": 5, "sell": 200, "buy": 0},
	&"fish_sturgeon": {"cat": "fish", "stack": 5, "sell": 95, "buy": 0},
	&"fish_sturgeon_cooked": {"cat": "food", "stack": 5, "sell": 125, "buy": 0, "food": 70},
	&"fish_sturgeon_cleaned": {"cat": "fish", "stack": 5, "sell": 95, "buy": 0},
	&"fish_sturgeon_cleaned_cooked": {"cat": "food", "stack": 5, "sell": 125, "buy": 0, "food": 100},
	&"fish_sturgeon_trophy": {"cat": "fish", "stack": 5, "sell": 950, "buy": 0},
	# --- end FISHING ---
}

const CATEGORY_KEYS := {
	"tool": "CAT_TOOL", "seed": "CAT_SEED", "crop": "CAT_CROP", "resource": "CAT_RESOURCE",
	"feed": "CAT_FEED", "animal_product": "CAT_ANIMAL_PRODUCT", "artisan": "CAT_ARTISAN",
	"placeable": "CAT_PLACEABLE", "supply": "CAT_SUPPLY", "key": "CAT_KEY", "animal": "CAT_ANIMAL",
	"material": "CAT_MATERIAL", "bait": "CAT_BAIT", "sapling": "CAT_SAPLING",
	"fish": "CAT_FISH", "food": "CAT_FOOD", "junk": "CAT_JUNK", "meat": "CAT_MEAT",
	"forage": "CAT_FORAGE", "game": "CAT_GAME",
}

## Items the player starts a new game with: [id, count]
const STARTING_ITEMS := [
	[&"hoe", 1], [&"watering_can", 1], [&"scythe", 1], [&"pickaxe", 1], [&"axe", 1],
	[&"wheat_seed", 10], [&"potato_seed", 5],
]
