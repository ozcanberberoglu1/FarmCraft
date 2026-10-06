extends Node
## The story's goals and the orders on the town board.
## Grandpa Osman has left the player his run-down farm in Yeşilova. The story is farm life
## first, a day at a time; each day's goals wait for its morning ("day:<n>" goals between
## them, the player free in between). Day one is walked through by hand: the stuck front
## door, his tools on the worktable inside, three beds of wheat, the pickup's key in the
## desk drawer, two hens from the poultry stall in town (named by the farmer as they go
## into the coop: Animals), a coop put up from a kit, the ripe beds he left behind, the
## shipping bin, the coop looked after (feed from the warehouse, water from the well, straw
## in the nests), the first egg, then the farm tidied up (the broken boards of the house and
## the warehouse renewed by hand with wood from the trees) and a short walk with Grandpa
## (his two spots near the house: EXPLORE_SPOTS, a line from him at each), stone from the
## rocks at the second one, wild berries there and a bite to eat; the evening is free (a
## goal that waits for the morning lets the farmer go to bed at any hour: day_work_done,
## and brings a few quiet farm chores to pass the time: FarmChores). Day two is a farmer's day:
## the wheat sold at the town market and seeds bought there, three more beds sown, a
## sapling from the felled trees planted, a workbench put up near the house and a knife
## made at it for the night (the wolves' lesson comes that night: WolfRaids.LESSON_NIGHT).
## Day three brings a rooster for the hens (named like them; eggs left in the nests under
## him hatch into chicks) and the new beds watered; day four is a day at the pond (rope
## from the market for a rod, bait, a fish, a campfire to cook it on, a meal). Later only a
## few milestones of a growing farm (the barn and its sheep, the dairy, the house), each
## chapter opened by a line from his notebook. Goals
## give farm experience, never money: the farm earns only by selling. A dot on the
## screen (waypoint()) shows where a goal is done. Orders: customers who want a number
## of one product by a day and pay well above the market for it. They grow with the
## farm level; three hang on the board, expired ones are replaced each morning.

signal tutorial_changed
signal orders_changed
## A new chapter of the story begins (its index in CHAPTERS).
signal chapter_started(chapter: int)
## The last goal is done: the story ends with a letter from Grandpa.
signal story_finished
## One of Grandpa's spots (EXPLORE_SPOTS) reached on the walk round the land: its id and
## his line about it (the HUD shows it under the goal).
signal spot_visited(spot: String, line: String)

const CHAPTERS: Array[String] = ["arrival", "soil", "town", "coop", "harvest", "coop_care",
	"repair", "explore", "free", "market", "fields", "workshop", "rooster", "fishing", "barn",
	"dairy", "legacy"]
## The first chapter after the first day's story (the player is free until morning):
## saves from before the first day's story go on from here.
const DAY_TWO_CHAPTER := 8
## Format of the chain in saves (2: the hand-held first day; 3: the day ending with the
## coop's care and the house mended by hand; 4: the second day's workshop and fishing;
## 5: the second morning's harvest sold at the market instead of earning in the bin).
## Saves without it are older and skip the first day (MOVED_V2); chain 2 saves go on at
## the nearest goal still here (MOVED_V3), chain 3 saves on the stonework at the
## workshop (MOVED_V4), chain 4 saves on the earning goal at the second harvest (MOVED_V5);
## 6: the third morning's rooster after the fishing (chain 5 saves just past the fishing
## go back for it: MOVED_V6); 7: farm life first: the mending moved to day two, the knife
## made for the night, the rooster on day three and the fishing on day four (MOVED_V7);
## 8: a full first day: the mending back on it, then the walk round the land, the stone,
## the berries and the bite to eat; the second day's seeds and new beds, the third's
## watering (MOVED_V8).
const CHAIN := 8
## Story goals in order: chapter, id, what counts toward it, how many, and the farm
## experience it gives ("xp", none when left out). Goals pay no money: the farm earns
## only by selling (Economy.STARTING_MONEY).
## kind: "action" (a finished farm action; "plant:<crop>" counts one crop's sowing),
## "sold" (units sold), "placed", "crafted" (at a workbench; building kits count as
## "kit"), "product" (artisan goods made), "picked" (items picked up), "order", "fed"
## (feed put in a coop's feeder), "watered" (water in a coop's trough), "nests" (the most
## nests one coop has had straw in), "patched" (broken spots renewed on a building:
## "house" or "warehouse"), or "check" (a condition polled each second: "flag:<name>"
## (FarmState.flags), "table" (Grandpa's things taken off the worktable), "key" (the
## pickup's key found), "driving", "hens:owned" (hens bought, crated or let out),
## "home" (back in the farmyard, no hens left waiting at the Animal Market),
## "crates:warehouse" (hen crates stored, or hens let out), "owned:<species>" (bought:
## crated anywhere, or living on the farm), "kit" (a coop kit made), "coop:started" /
## "coop:built", "bin:<item or category>" (in the shipping bin, or shipped),
## "warehouse", "cargo", "near:town", "day:<n>", "level", "built:<project>",
## "animals:<species>", "trailer:<what>" (the stock trailer's lesson: TrailerGoals),
## "has:<item>" (in the bag or put down on the farm), "bench:kit" /
## "bench:started" / "bench:built" (a workbench bought, put down, finished), "bait"
## (worms or dough in the bag), "caught" (a fish caught since the story began), "full"
## (the farmer too full to eat now); the counting ones report progress).
## Kinds of the later days: "earned" (dollars from sales and orders), "caught" (fish
## caught: Events.fish_caught), "cooked" (food cooked on a campfire), "eaten" (anything
## eaten), "meal" (a cooked meal eaten: _is_meal), "visit" (Grandpa's spots reached on
## the walk round the land, each once: EXPLORE_SPOTS), "forage" (wild berries picked:
## ItemTable category "forage"), "purchased" (bought at a shop, by item category:
## "seed"), "sapling" (saplings planted); and the checks "nobush" (no wild bush in the
## valley has berries on it now), "nosapling" (no sapling in the bag), "bedsready" (three
## tilled beds stand empty, or no untilled ground is left), "nofield" (no bed free to sow
## and none left to till) and "nodry" (no sown bed is dry).
## "ever": the goal also counts what was done before it came up (see `tally`), so work
## done early is never asked for twice and the chain can't stall on it.
## "past": a check that shows the player is beyond this goal already (done out of order,
## a debug shot, a load): it completes the goal when it reads above 0.
## "at": where the dot points while the goal is up (see _target). When it points
## somewhere else first (the trees for wood, the shipping bin for money, the market for
## rope), the goal's text says why (goal_hint): the dot never sends the player off to
## buy something without saying what, nor to a shop that doesn't sell it. A goal short of
## money says how much more it takes and, under that, how to earn it from what the farmer
## has or can do right now (money_short, earn_plan): the dot goes where that line says.
## A goal that builds something from the construction board shows what it takes against
## what he has under its text ("Wood 32/50 · $120/200": goal_needs).
const TUTORIAL := [
	# Day one. Homecoming: the stuck front door, and Grandpa's things on the worktable inside.
	{"chapter": 0, "id": "door", "kind": "check", "arg": "flag:house_door_open", "count": 1, "at": "house_door", "past": "took"},
	# The count is FarmHouse.table_item_count() (ItemTable.STARTING_ITEMS); "table" copes
	# with a different number all the same.
	{"chapter": 0, "id": "tools", "kind": "check", "arg": "table", "count": 7, "at": "table"},
	# The farm's own name: Grandpa's old name board at the entrance, its paint flaked off
	# (NameBoard: E opens the naming prompt; a skipped one keeps Grandpa's name on it, and E
	# on the board renames the farm at any time). Added without a new chain: a save further
	# on is simply past it, its farm called by the default name until he writes another.
	{"chapter": 0, "id": "farm_name", "kind": "check", "arg": "flag:farm_named", "count": 1, "xp": 2, "at": "name_board"},
	# The soil: three beds of wheat, ripe by tomorrow morning.
	{"chapter": 1, "id": "till", "kind": "action", "arg": "hoe", "count": 3, "xp": 4, "ever": true, "at": "plot:untilled"},
	{"chapter": 1, "id": "plant", "kind": "action", "arg": "plant:wheat", "count": 3, "xp": 4, "ever": true, "at": "plot:empty"},
	{"chapter": 1, "id": "water", "kind": "action", "arg": "water", "count": 3, "xp": 4, "ever": true, "at": "plot:dry"},
	# The town: the pickup's key in the desk drawer, the drive, two hens in crates, home again.
	{"chapter": 2, "id": "drawer", "kind": "check", "arg": "flag:drawer_open", "count": 1, "at": "drawer", "past": "key"},
	{"chapter": 2, "id": "key", "kind": "check", "arg": "key", "count": 1, "at": "key"},
	{"chapter": 2, "id": "truck", "kind": "check", "arg": "driving", "count": 1, "at": "truck", "past": "hens:owned"},
	{"chapter": 2, "id": "buy_chickens", "kind": "check", "arg": "hens:owned", "count": 2, "at": "stall"},
	{"chapter": 2, "id": "drive_home", "kind": "check", "arg": "home", "count": 1, "xp": 4, "at": "home", "past": "crates:warehouse"},
	{"chapter": 2, "id": "crates_in", "kind": "check", "arg": "crates:warehouse", "count": 2, "xp": 5, "at": "crates"},
	# The coop: wood, a kit from the construction board, a spot, ten seconds' work (the
	# story's first: build_seconds), the hens in (each of the first two named by the farmer
	# as she goes in: Animals).
	{"chapter": 3, "id": "coop_wood", "kind": "picked", "arg": "wood", "count": 15, "xp": 5, "ever": true, "at": "trees", "past": "kit"},
	{"chapter": 3, "id": "coop_kit", "kind": "check", "arg": "kit", "count": 1, "at": "board"},
	{"chapter": 3, "id": "coop_place", "kind": "check", "arg": "coop:started", "count": 1, "xp": 4, "at": "coop_spot"},
	{"chapter": 3, "id": "coop_built", "kind": "check", "arg": "coop:built", "count": 1, "xp": 8, "at": "coop"},
	{"chapter": 3, "id": "hens_in", "kind": "check", "arg": "animals:chicken", "count": 2, "xp": 6, "at": "hens"},
	# The first harvest: the ripe beds Grandpa left, the shipping bin.
	{"chapter": 4, "id": "harvest", "kind": "action", "arg": "harvest", "count": 3, "xp": 5, "ever": true, "at": "plot:ripe", "past": "bin:crop"},
	{"chapter": 4, "id": "ship", "kind": "check", "arg": "bin:crop", "count": 1, "xp": 3, "at": "bin"},
	# The coop's care: the feed sack that waits in the warehouse into the feeder, the
	# watering can from the well into the water trough, straw from the meadow in the nests
	# (the hens lay there from then on); then the first egg (laid 25 minutes after the
	# first hen went in: ChickenCoop) picked up and put in the bin.
	{"chapter": 5, "id": "feed", "kind": "fed", "arg": "", "count": 1, "xp": 3, "ever": true, "at": "feeder"},
	{"chapter": 5, "id": "coop_water", "kind": "watered", "arg": "", "count": 1, "xp": 3, "ever": true, "at": "coop_water"},
	{"chapter": 5, "id": "straw", "kind": "nests", "arg": "", "count": 3, "xp": 4, "ever": true, "at": "nests"},
	{"chapter": 5, "id": "egg", "kind": "picked", "arg": "egg", "count": 1, "ever": true, "at": "egg", "past": "bin:egg"},
	{"chapter": 5, "id": "ship_egg", "kind": "check", "arg": "bin:egg", "count": 1, "xp": 3, "at": "bin"},
	# Tidying the farm up while it is light: wood for the house (counted from when the goal
	# comes up), then every broken board of the house renewed by hand, a piece of wood each
	# (its eight holes: the last one repairs it), then the warehouse's six the same way (no
	# wood goal of its own: with none in hand the dot goes to the trees first). (A building
	# repaired already passes its goals.)
	{"chapter": 6, "id": "wood", "kind": "picked", "arg": "wood", "count": 8, "xp": 2, "at": "trees", "past": "built:house_1"},
	{"chapter": 6, "id": "patch", "kind": "patched", "arg": "house", "count": 8, "xp": 8, "ever": true, "at": "house_repair", "past": "built:house_1"},
	{"chapter": 6, "id": "wh_patch", "kind": "patched", "arg": "warehouse", "count": 6, "xp": 8, "ever": true, "at": "warehouse_repair", "past": "built:warehouse_1"},
	# A short walk with Grandpa before dusk: his two spots near the house, one after the
	# other (the dot goes to the next one; any reached counts, each with a line from him),
	# ending at the forest's edge behind the house, where the rest is at hand: stone for the
	# knife of tomorrow night from the rocks lying there (two give the four asked for), then
	# wild berries off the bushes beside them (two bushes give the four) and a bite to eat
	# (the hunger bar; too full to eat passes it). A valley with no berries left on any bush
	# passes the berries (any picked earlier count). Saves from when the walk had four spots
	# and asked for more stone and berries keep what they did: a count already met passes.
	{"chapter": 7, "id": "explore", "kind": "visit", "arg": "", "count": 2, "xp": 6, "ever": true, "at": "explore"},
	{"chapter": 7, "id": "stones", "kind": "picked", "arg": "stone", "count": 4, "xp": 3, "ever": true, "at": "rocks"},
	{"chapter": 7, "id": "berries", "kind": "forage", "arg": "", "count": 4, "xp": 3, "ever": true, "at": "berries", "past": "nobush"},
	{"chapter": 7, "id": "snack", "kind": "eaten", "arg": "", "count": 1, "xp": 3, "ever": true, "at": "food", "past": "full"},
	# The first day's story is done: the farm is the player's own until the next morning
	# (no dot, no task; Grandpa's note says so).
	{"chapter": 8, "id": "free", "kind": "check", "arg": "day:2", "count": 1},
	# Day two, market day: yesterday's wheat reaped, loaded into the pickup's bed and sold
	# at the Yeşilova market (the money for the workbench later in the day; Grandpa's note
	# and the line under the goal say what sells and where: HINT_WHAT_SELLS), and seeds
	# bought on the same trip (any seed the market has: none is out of season). Short of
	# money for them, the dot shows where his own goods sell and the line names them
	# (_seeds_short); with nothing to sell either, the grocer gives the first three packets
	# (seed_gift_due): the goal never dead-ends.
	{"chapter": 9, "id": "harvest2", "kind": "check", "arg": "crops", "count": 3, "xp": 4, "at": "plot:ripe", "past": "bench:kit"},
	{"chapter": 9, "id": "load_crops", "kind": "check", "arg": "cargo:crop", "count": 3, "xp": 3, "at": "truck_load", "past": "bench:kit"},
	{"chapter": 9, "id": "sell_market", "kind": "sold", "arg": "", "count": 3, "xp": 4, "at": "sell_market", "past": "bench:kit"},
	{"chapter": 9, "id": "seeds", "kind": "purchased", "arg": "seed", "count": 3, "xp": 3, "ever": true, "at": "seeds"},
	# The field grows: three more beds tilled, sown (any seed: the new ones or Grandpa's
	# potatoes) and watered, counted from when each goal comes up; then a sapling from the
	# felled trees planted (passed when the bag has none: not every tree drops one). None of
	# them can stall on a field that is already done: three tilled beds ready to sow (or no
	# ground left to till) pass the tilling, a field with no bed free passes the sowing, and
	# no dry bed passes the watering.
	{"chapter": 10, "id": "till2", "kind": "action", "arg": "hoe", "count": 3, "xp": 3, "at": "plot:untilled", "past": "bedsready"},
	{"chapter": 10, "id": "sow", "kind": "action", "arg": "plant", "count": 3, "xp": 3, "at": "plot:empty", "past": "nofield"},
	{"chapter": 10, "id": "water2", "kind": "action", "arg": "water", "count": 3, "xp": 3, "at": "plot:dry", "past": "nodry"},
	{"chapter": 10, "id": "sapling", "kind": "sapling", "arg": "", "count": 1, "xp": 4, "ever": true, "at": "sapling", "past": "nosapling"},
	# The workshop before nightfall: the workbench kit from the construction board (bought,
	# like everything), put up near the house in ten seconds like the coop, then a
	# knife made at it: Grandpa's advice for the nights, when the wolves are about (the
	# lesson comes tonight: WolfRaids.LESSON_NIGHT).
	{"chapter": 11, "id": "bench_kit", "kind": "check", "arg": "bench:kit", "count": 1, "xp": 4, "at": "bench_board"},
	{"chapter": 11, "id": "bench_place", "kind": "check", "arg": "bench:started", "count": 1, "xp": 4, "at": "bench_spot"},
	{"chapter": 11, "id": "bench_built", "kind": "check", "arg": "bench:built", "count": 1, "xp": 6, "at": "bench"},
	{"chapter": 11, "id": "knife", "kind": "crafted", "arg": "knife", "count": 1, "xp": 6, "ever": true, "at": "craft:knife"},
	# The rest of the second day is the player's own (the night brings the wolves' lesson);
	# the third morning brings the rooster.
	{"chapter": 11, "id": "rooster_wait", "kind": "check", "arg": "day:3", "count": 1},
	# Day three, the flock grows: a rooster for the hens, bought at the animal market in town
	# (in his crate, like the hens) and let out at the coop door, named by the farmer like
	# the first hens; the eggs left in the nests under him hatch into chicks a day later
	# (the chapter's note and the release say so). Then the new beds watered again (a crop
	# wants water every day; counted from when the goal comes up).
	{"chapter": 12, "id": "rooster_buy", "kind": "check", "arg": "owned:rooster", "count": 1, "xp": 4, "at": "rooster_market", "past": "animals:rooster"},
	{"chapter": 12, "id": "rooster_in", "kind": "check", "arg": "animals:rooster", "count": 1, "xp": 8, "at": "hens"},
	{"chapter": 12, "id": "water3", "kind": "action", "arg": "water", "count": 3, "xp": 3, "at": "plot:dry", "past": "nodry"},
	{"chapter": 12, "id": "fishing_wait", "kind": "check", "arg": "day:4", "count": 1},
	# Day four, a day at the pond: rope from the town market for a rod (RecipeTable: 2) and
	# bait on the same trip, the rod made at the bench, a fish from the pond by the house, a
	# campfire made and put down to cook it on, and the meal. (Goals a save is past already
	# pass: a rod in the bag, a fish caught, a meal eaten.)
	{"chapter": 13, "id": "rope", "kind": "check", "arg": "has:rope", "count": 2, "xp": 3, "at": "buy:rope", "past": "rods"},
	{"chapter": 13, "id": "bait", "kind": "check", "arg": "bait", "count": 1, "xp": 3, "at": "bait", "past": "caught"},
	# Any rod will do (the cane rod, the standard one or a better one).
	{"chapter": 13, "id": "rod", "kind": "check", "arg": "rods", "count": 1, "xp": 6, "at": "craft:fishing_rod", "past": "rods"},
	{"chapter": 13, "id": "fish", "kind": "caught", "arg": "", "count": 1, "xp": 8, "ever": true, "at": "pond"},
	{"chapter": 13, "id": "campfire", "kind": "crafted", "arg": "campfire", "count": 1, "xp": 4, "ever": true, "at": "craft:campfire", "past": "has:campfire"},
	{"chapter": 13, "id": "cook", "kind": "cooked", "arg": "", "count": 1, "xp": 6, "ever": true, "at": "campfire"},
	{"chapter": 13, "id": "eat", "kind": "meal", "arg": "", "count": 1, "xp": 4, "ever": true},
	# From here the farm is the player's to run: a few milestones as it grows (sheep, a
	# cow and a bigger house). The barn and its sheep come after the pond's day, not
	# before: $200 and 50 wood for the barn and a sheep's price are beyond a three-day-old
	# farm (the pasture's spot on the first day's walk says it is coming). The building
	# goals' cards say what they take (goal_needs) and their dots show where it comes from
	# (the trees, the rocks, where money is earned), then the board; the animals' dots the
	# Animal Market's pen once their price is in hand.
	{"chapter": 14, "id": "level_3", "kind": "check", "arg": "level", "count": 3},
	{"chapter": 14, "id": "barn", "kind": "check", "arg": "built:barn_1", "count": 1, "xp": 10, "at": "project:barn_1"},
	# Grandpa's stock trailer (Trailer, TrailerGoals): paid for at the dealership, hitched
	# behind the pickup, the sheep bought at the Animal Market led up its ramp on the rope,
	# driven home and led into the barn's pen ("sheep", the goal older saves know: it is
	# done with a sheep in the pen, however it came). Each step passes once the farm is
	# beyond it (a sheep at home passes them all).
	{"chapter": 14, "id": "trailer_get", "kind": "check", "arg": "trailer:owned", "count": 1, "xp": 4, "at": "trailer:get", "past": "trailer:sheep_home"},
	{"chapter": 14, "id": "trailer_hitch", "kind": "check", "arg": "trailer:hitched", "count": 1, "xp": 4, "at": "trailer:hitch", "past": "trailer:sheep_owned"},
	{"chapter": 14, "id": "sheep_buy", "kind": "check", "arg": "trailer:sheep_owned", "count": 1, "xp": 4, "at": "animal:sheep"},
	{"chapter": 14, "id": "sheep_load", "kind": "check", "arg": "trailer:sheep_loaded", "count": 1, "xp": 5, "at": "trailer:load", "past": "trailer:sheep_home"},
	{"chapter": 14, "id": "sheep_ride", "kind": "check", "arg": "trailer:sheep_at_farm", "count": 1, "xp": 4, "at": "trailer:ride"},
	{"chapter": 14, "id": "sheep", "kind": "check", "arg": "trailer:sheep_home", "count": 1, "xp": 10, "at": "trailer:unload"},
	{"chapter": 14, "id": "shear", "kind": "action", "arg": "shear", "count": 1, "xp": 10},
	{"chapter": 15, "id": "level_4", "kind": "check", "arg": "level", "count": 4},
	{"chapter": 15, "id": "cow", "kind": "check", "arg": "animals:cow", "count": 1, "xp": 10, "at": "animal:cow"},
	{"chapter": 15, "id": "milk", "kind": "action", "arg": "milk", "count": 1, "xp": 10},
	{"chapter": 15, "id": "cheese", "kind": "product", "arg": "cheese", "count": 1, "xp": 10},
	{"chapter": 16, "id": "level_5", "kind": "check", "arg": "level", "count": 5},
	{"chapter": 16, "id": "house", "kind": "check", "arg": "built:house_2", "count": 1, "xp": 10, "at": "project:house_2"},
]
## Goals of the chain before the first day's story (saves without "chain") and where
## such a save goes on (MOVED_V3 then takes it on to this chain): its first day counts
## as done. Sowing and the first drive were day one's, the night and the harvest came
## before the flour, the level wait before the coop. Ids not listed are the same goal
## still.
const MOVED_V2 := {
	"till": "replant", "plant": "replant", "water": "replant",
	"truck": "load", "visit": "order",
	"sleep": "flour", "harvest": "flour", "replant": "flour",
	"level_2": "coop",
}
## Goals of chain 2 that went when the first day came to end with the coop's care and
## the house mended by hand, and where a save on one goes on (MOVED_V2 first for older
## saves): the bedtime and the yard's work gave way to the coop's care, the market and
## the workshop to the millstone, the house's repair sign to the flour, the old coop
## goals to the farm's milestones. Ids not listed are the same goal still.
const MOVED_V3 := {
	"sleep": "feed", "reap": "feed", "replant": "feed", "refill": "feed",
	"repair_warehouse": "quern", "store": "quern", "hay": "quern", "load": "quern",
	"order": "quern", "sell": "quern", "workbench": "quern", "craft": "quern",
	"repair_house": "flour", "coop": "level_3", "chickens": "level_3", "eggs": "level_3",
}
## The goals before the day-one chapters, in their old order: saves from then kept only
## an index into this list (see _legacy_id).
const LEGACY_TUTORIAL := [
	{"id": "till", "kind": "action", "arg": "hoe", "count": 3},
	{"id": "plant", "kind": "action", "arg": "plant", "count": 3},
	{"id": "water", "kind": "action", "arg": "water", "count": 3},
	{"id": "harvest", "kind": "action", "arg": "harvest", "count": 1},
	{"id": "store", "kind": "check", "arg": "warehouse", "count": 1},
	{"id": "pickup", "kind": "check", "arg": "pickup", "count": 1},
	{"id": "sell", "kind": "sold", "arg": "", "count": 10},
	{"id": "order", "kind": "order", "arg": "", "count": 1},
	{"id": "workbench", "kind": "placed", "arg": "workbench", "count": 1},
	{"id": "craft", "kind": "crafted", "arg": "", "count": 1},
	{"id": "level_2", "kind": "check", "arg": "level", "count": 2},
	{"id": "coop", "kind": "check", "arg": "built:coop_1", "count": 1},
	{"id": "chickens", "kind": "check", "arg": "animals:chicken", "count": 2},
	{"id": "eggs", "kind": "picked", "arg": "egg", "count": 3},
	{"id": "level_3", "kind": "check", "arg": "level", "count": 3},
	{"id": "barn", "kind": "check", "arg": "built:barn_1", "count": 1},
	{"id": "sheep", "kind": "check", "arg": "animals:sheep", "count": 1},
	{"id": "shear", "kind": "action", "arg": "shear", "count": 1},
	{"id": "level_4", "kind": "check", "arg": "level", "count": 4},
	{"id": "cow", "kind": "check", "arg": "animals:cow", "count": 1},
	{"id": "milk", "kind": "action", "arg": "milk", "count": 1},
	{"id": "cheese", "kind": "product", "arg": "cheese", "count": 1},
	{"id": "level_5", "kind": "check", "arg": "level", "count": 5},
	{"id": "house", "kind": "check", "arg": "built:house_2", "count": 1},
]
## Old goals that moved or went, and where an old save goes on (the chain of the day-one
## chapters; MOVED_V2 then takes it on to this chain): waiting for the first harvest
## filled the day in the yard, Grandpa's pickup came with the farm, and the order was
## due before the selling.
const LEGACY_MOVED := {"harvest": "wood", "pickup": "truck", "sell": "order"}
## Goals of chain 3 that went when the second day's stonework gave way to the workshop
## and the fishing, and where a save on one goes on (after MOVED_V2 and MOVED_V3): the
## stone, the millstone and the flour to earning the workbench's money (the millstone and
## its flour stay in the game, only not in the story).
const MOVED_V4 := {"stone": "earn", "quern": "earn", "flour": "earn"}
## Chain 4's goal to earn the workbench's money (in the bin or at the market), and where a
## save on it goes on: the second morning's harvest, taken to the market in the pickup.
const MOVED_V5 := {"earn": "harvest2"}
## Chain 5's first goal after the fishing, and where a save on it goes on: the rooster
## chapter that came in before the farm's milestones (a save further on keeps its goal).
const MOVED_V6 := {"level_3": "rooster_wait"}
## Chain 6's goals that moved when the story put farm life first, and where a save on one
## goes on: the first egg now comes after the coop's care (a save on it does the care
## first; the egg, picked or shipped already, then passes), and the fishing to the fourth
## day after the rooster (a save on it goes on at the rooster's morning; what it had of
## the fishing passes when it comes up again). A save past the fishing (on the rooster)
## keeps its goal, and the fishing then passes. (Chain 7 moved the mending to the second
## day; chain 8 brought it back to the first, where chain 6 had it: a chain 6 save on it
## keeps its goal.)
const MOVED_V7 := {
	"egg": "feed", "ship_egg": "feed",
	"rope": "rooster_wait", "bait": "rooster_wait", "rod": "rooster_wait", "fish": "rooster_wait",
	"campfire": "rooster_wait", "cook": "rooster_wait", "eat": "rooster_wait",
}
## Chain 7's goals that moved when the first day was filled out, and where a save on one
## goes on: the free evening now comes after the mending and the walk round the land (a
## save on it does them first; a house and warehouse repaired already pass), the bite to
## eat moved to the first day (a save on it, past the knife, is free until the third
## morning), and Grandpa's potatoes gave way to the new beds' watering on the third day.
const MOVED_V8 := {"free": "wood", "snack": "rooster_wait", "potatoes": "water3"}
## Chain 7's second morning sold at the market before the mending: a save on the market
## goes back to the mending and the walk (it did neither yet; what it has of the market
## passes when it comes up again: crops reaped or loaded count), and a save on the
## mending had sold already: the market's goals are marked done for it (DONE_MARK).
const MOVED_V8_MARKET := {"harvest2": "wood", "load_crops": "wood", "sell_market": "wood"}
const V8_SOLD_FIRST: Array[String] = ["wood", "patch", "wh_patch"]
const V8_MARKET: Array[String] = ["harvest2", "load_crops", "sell_market"]
## A goal a save did under an older chain (tally key "done:<id>"): it passes, without its
## experience again, when it comes up.
const DONE_MARK := "done:%s"
## Grandpa's spots on the first day's walk, in the order the dot takes them (any reached
## counts): where (world XZ), how near counts as there (m) and how high the dot floats
## over the ground (or the pond's water). Only two, both a short walk from the house
## (EXPLORE_NEAR at most from its door): the pond he fished (the fourth day's), beside the
## yard, and the edge of the old forest behind the house, where the wolves come down from
## (the second night's) and where the walk's stone and berries are at hand (two field
## rocks and two blueberry bushes stand within a few steps: NatureSpawner's fixed seeds).
## The far ones went (the old pasture across the farm, the quarry up the north path): the
## walk had become a hike. Each has a name (SPOT_<ID>) and a line from him
## (EXPLORE_<ID>_LINE).
const EXPLORE_SPOTS := {
	"pond": {"at": Vector2(-44, -4), "reach": 16.0, "lift": 2.2},
	"woods": {"at": Vector2(-20, -47), "reach": 12.0, "lift": 3.0},
}
## No spot of the walk lies farther than this from the house door (m).
const EXPLORE_NEAR := 40.0
## The first day keeps time for the story: the clock runs at FIRST_DAY_RATE game minutes
## a real minute and from LINGER_HOUR the late afternoon lingers (LINGER_RATE: the
## mending, the walk and the berries still come in daylight); once the day's story is
## done the clock runs as usual, and the evening is the player's own. Set on
## GameClock.time_scale, worked out against the day length setting (_pace_of), so the
## story's days take the same real time whether a day is 8, 10 or 12 minutes long
## (Settings.DAY_LENGTHS).
## The day starts at 13:00 (GameClock.FIRST_DAY_START_MINUTE): 13:00 to 17:00 (240 game
## minutes at 11.2 a real minute) takes 21 real minutes and the linger to sundown (about
## 19:15: 135 at 8.8) 15 more, about 37 in all, and to nightfall (20:00) 42: the first
## day's story (about 25 minutes to the first egg, then the mending, the walk and the
## berries) fits in daylight for a brisk player; what isn't done by night simply carries
## on the next morning. The first egg (ChickenCoop FIRST_EGG_MINUTES, game time) comes
## about half a real minute after the hens go in.
const FIRST_DAY_RATE := 11.2
const LINGER_HOUR := 17.0
const LINGER_RATE := 8.8
## The second day's farm work (the market, the new beds, the workbench and the knife)
## gets a gentler clock too while its goals are up: 06:00 to sundown (about 795 game
## minutes at 32 a real minute) is about 25 real minutes instead of the 6.6 of a
## 10-minute day, so the knife is made before the wolves' night. Once the day's goals
## are done (rooster_wait) the clock runs as usual.
const SECOND_DAY_RATE := 32.0
const SECOND_DAY_UNTIL := 19.5
## The same as time scales at the default 10-minute day (Settings.DEFAULT_DAY_LENGTH: 120
## game minutes a real minute): about 0.093, 0.073 and 0.267 (pace_for and
## second_day_pace give the scale for the day length set).
const DEFAULT_RATE := 120.0
const FIRST_DAY_PACE := FIRST_DAY_RATE / DEFAULT_RATE
const LINGER_PACE := LINGER_RATE / DEFAULT_RATE
const SECOND_DAY_PACE := SECOND_DAY_RATE / DEFAULT_RATE
## What sells (ItemTable categories), best first: the seeds goal names the farmer's own
## goods of these when he is short of money (sellable_names).
const SELLABLE: Array[String] = ["animal_product", "crop", "fish", "food", "artisan", "forage", "resource"]
## Set once the grocer gave the first seeds (FarmState.flags, saved with the farm).
const SEED_GIFT_FLAG := "seed_gift"
## Grandpa's beds: the far end of the first field is ripe on a new farm, so the first
## harvest can be made on day one (the player's own wheat needs 20 wet hours and ripens
## overnight, see FIRST_NIGHT_GROWTH). Carrots, or wheat out of the carrot seasons. Set
## once (BEDS_FLAG in FarmState.flags, saved with the farm).
const GRANDPA_BEDS := 3
const GRANDPA_CROP := &"carrot"
const BEDS_FLAG := "grandpa_beds"
## The first day starts at 13:00, so wheat sown that afternoon or evening would not have
## its 20 wet hours by the second morning, when the story asks for its harvest
## (harvest2). The first night makes up for the morning the day didn't have: a crop sown
## and watered on a new farm's first day wakes with at least this many hours of growth
## (a whole day, as if it had gone in at dawn), so the wheat is ripe and slower crops
## are a day along.
const FIRST_NIGHT_GROWTH := 24.0
## Back in the farmyard (the "home" check): this close to the warehouse door, on foot or
## at the wheel.
const HOME_RADIUS := 30.0
## How often the dot's place is worked out again (seconds).
const WAYPOINT_REFRESH := 0.25
## What the board asks for, by the farm level needed (UnlockTable opens the crops,
## animals and machines at those levels): [level, item, smallest, largest count].
const ORDER_GOODS := [
	[1, &"wheat", 10, 30], [1, &"potato", 8, 24], [1, &"carrot", 8, 24], [1, &"wood", 20, 60],
	[2, &"tomato", 8, 24], [2, &"strawberry", 8, 20], [2, &"egg", 6, 20], [2, &"flour", 3, 8],
	[3, &"corn", 8, 24], [3, &"wool", 3, 8], [3, &"pickles", 2, 6],
	[4, &"eggplant", 6, 18], [4, &"milk", 4, 12], [4, &"yarn", 2, 6], [4, &"pumpkin", 2, 6],
	[5, &"cheese", 2, 6], [5, &"jam", 2, 6], [5, &"tomato_paste", 2, 6],
]
## The first morning's board always carries the bakery's wood order, so the "order" goal
## can be met from the yard: item, count, days to deliver, client (OrderScreen.CLIENTS,
## 11 = Ova Fırını).
const FIRST_ORDER := {"item": &"wood", "count": 8, "days": 4, "client": 11}
const BOARD_SIZE := 3
## Orders pay this much more than the market (in steps of $5), and at least MIN_REWARD.
const PREMIUM := 1.6
const MIN_REWARD := 5

var step := 0
var step_count := 0
## Lifetime counts of what goals ask for while the story runs ("action:harvest",
## "picked:wood", "sold:", "shipped:crop"...): an "ever" goal reads its own when it
## comes up.
var tally := {}
var orders: Array = []
var _next_order_id := 1
var _poll := 0.0
## The dot's place (a Vector3, a Node3D it follows, or null), worked out a few times a
## second: the HUD asks every frame.
var _waypoint: Variant = null
var _wp_left := 0.0
## Where the coop kit fits (found once when the goal comes up; null: nowhere found).
var _coop_spot: Variant = null
var _coop_spot_searched := false
## Where the workbench kit fits near the house (found once, as the coop's).
var _bench_spot: Variant = null
var _bench_spot_searched := false
## Open ground suggested for the second day's sapling (found once, as the coop's).
var _sapling_spot: Variant = null
var _sapling_spot_searched := false
## Why the dot points where it does when that isn't the goal's own place (a translated
## line under the goal, "" for none): set with the dot (_target), read by goal_hint().
var _hint := ""
## What the current goal's project takes against what the farmer has ("Wood 32/50 ·
## $120/200", "" for a goal that builds nothing): kept up to date with the dot, shown
## under the goal's text (goal_needs).
var _needs := ""
## The mark after a requirement that is met ("Wood 50/50 ✓").
const NEED_MET := "✓"
## From this hour on, goods waiting in the shipping bin are a reason to go to bed (they
## are paid for in the morning): earn_plan.
const BIN_BED_HOUR := 18.0
## Crates in hand in town go to the pickup's bed when it is parked within this many
## metres (_waiting_crates); farther away they are on their way home by hand.
const CRATES_TO_TRUCK := 80.0
## The first day's pace is set on GameClock.time_scale (given back when the day is over).
var _paced := false
## A building just finished (see _guide_to): the dot floats over it first (a Vector3),
## with a line on its pill, until the player is within NEW_BUILDING_NEAR metres or its
## time is up (counted while no screen is open): NEW_BUILDING_TIME, only
## NEW_BUILDING_BRIEF while the goal has a place of its own (its dot comes back after).
const NEW_BUILDING_NEAR := 8.0
const NEW_BUILDING_TIME := 180.0
const NEW_BUILDING_BRIEF := 20.0
var _new_building: Variant = null
var _new_building_text := ""
var _new_building_shown := 0.0
## Automated runs leave new buildings unmarked (their checks read the goal's dot)
## unless a test turns this on.
var guide_in_tests := false
## The quiet farm chores of the days the story leaves free (FarmChores; saved here).
var chores: FarmChores


func _ready() -> void:
	Events.action_done.connect(_on_action_done)
	Events.item_sold.connect(func(_id: StringName, n: int, g: int) -> void:
		_count("sold", "", n)
		_count("earned", "", g))
	Events.placed.connect(func(id: StringName) -> void: _count("placed", String(id), 1))
	Events.crafted.connect(_on_crafted)
	Events.product_made.connect(func(id: StringName, n: int) -> void: _count("product", String(id), n))
	Events.item_picked_up.connect(_on_picked_up)
	# The second day's seeds bought at the market, and a sapling planted.
	Events.item_bought.connect(func(id: StringName, n: int) -> void:
		if ItemDB.has_item(id):
			_count("purchased", ItemDB.get_item(id).category, n))
	Events.sapling_planted.connect(func(_s: Node) -> void: _count("sapling", "", 1))
	Events.order_delivered.connect(func(_id: StringName, _n: int, r: int) -> void:
		_count("order", "", 1)
		_count("earned", "", r))
	Events.day_started.connect(_on_day_started)
	# The first day's hands-on steps: counted where they carry a number, and the check
	# goals look again at once rather than a second later.
	Events.animals_bought.connect(func(species: StringName, n: int) -> void:
		_count("bought", String(species), n)
		_nudge())
	Events.animal_released.connect(func(species: StringName, _home: Node) -> void:
		_count("released", String(species), 1)
		_nudge())
	Events.crate_stored.connect(func(_id: StringName, where: StringName) -> void:
		_count("stored", String(where), 1)
		_nudge())
	Events.shipped.connect(_on_shipped)
	Events.door_toggled.connect(func(_id: StringName, _open: bool) -> void: _nudge())
	Events.drawer_opened.connect(func(_id: StringName) -> void: _nudge())
	Events.world_item_taken.connect(func(_id: StringName) -> void: _nudge())
	Events.vehicle_entered.connect(func(_v: Node) -> void: _nudge())
	Events.vehicle_exited.connect(func(_v: Node) -> void: _nudge())
	Events.construction_started.connect(func(_id: StringName, _site: Node) -> void: _nudge())
	Events.building_completed.connect(func(_id: StringName, _b: Node) -> void: _nudge())
	# The coop's care and the house mended by hand.
	Events.coop_fed.connect(func(_coop: Node) -> void: _count("fed", "", 1))
	Events.coop_watered.connect(func(_coop: Node) -> void: _count("watered", "", 1))
	Events.nest_filled.connect(_on_nest_filled)
	Events.wall_patched.connect(func(id: StringName, _done: int, _total: int) -> void: _count("patched", String(id), 1))
	Events.building_repaired.connect(func(_id: StringName) -> void: _nudge())
	Events.egg_broken.connect(func(_at: Vector3) -> void: _on_egg_broken())
	# The second day: fishing, the campfire and a meal (Events' contract with those
	# mechanics), and the workbench going up.
	Events.fish_caught.connect(func(id: StringName) -> void:
		_count("caught", String(id), 1)
		_nudge())
	Events.food_cooked.connect(func(id: StringName) -> void: _count("cooked", String(id), 1))
	Events.food_eaten.connect(func(id: StringName) -> void:
		_count("eaten", String(id), 1)
		if _is_meal(id):
			_count("meal", "", 1))
	Events.campfire_lit.connect(func(_fire: Node) -> void: _nudge())
	Events.placed.connect(func(_id: StringName) -> void: _nudge())
	# A building just finished: the dot shows where it went up.
	FarmState.project_built.connect(_on_project_built)
	Events.building_completed.connect(_on_building_completed)
	# The grocer's first seeds for a farmer with no money and nothing to sell: looked at
	# when the market's window opens and after each sale in it.
	Events.ui_opened.connect(func(ui: StringName) -> void:
		if ui == &"shop":
			_offer_seed_gift.call_deferred())
	Events.item_sold.connect(func(_id: StringName, _n: int, _g: int) -> void: _offer_seed_gift.call_deferred())
	chores = FarmChores.new()
	chores.name = "FarmChores"
	add_child(chores)
	_start.call_deferred()


## After every autoload is ready (DebugTools reads the command line in its _ready).
func _start() -> void:
	# Automated runs (tests, screenshots) start without the tutorial so its rewards
	# don't mix into their checks; a test turns it on when it wants it. (PlayerState gives
	# them the starter kit itself.)
	if DebugTools.is_automated():
		step = TUTORIAL.size()
		tutorial_changed.emit()
	# A fresh launch plays a new farm without SaveGame.new_game: its board starts here.
	if orders.is_empty():
		_post_first_order()
	refill_board()


# --- Tutorial ----------------------------------------------------------------------------

func tutorial_done() -> bool:
	return step >= TUTORIAL.size()


func current() -> Dictionary:
	return {} if tutorial_done() else TUTORIAL[step]


## Index in TUTORIAL of the goal `id` (-1 when there is none).
func index_of(id: String) -> int:
	for i in TUTORIAL.size():
		if String(TUTORIAL[i]["id"]) == id:
			return i
	return -1


## Index of the first goal after the first day's story (where older saves go on).
func day_two_step() -> int:
	for i in TUTORIAL.size():
		if int(TUTORIAL[i]["chapter"]) >= DAY_TWO_CHAPTER:
			return i
	return TUTORIAL.size()


## The story is on its first day (the hand-held chapters before the player is let free).
func first_day() -> bool:
	return not tutorial_done() and int(current()["chapter"]) < DAY_TWO_CHAPTER


## The goal `id` is behind the player (the story is past it, or over).
func passed(id: String) -> bool:
	var i := index_of(id)
	return tutorial_done() or (i >= 0 and step > i)


## The day's story is done and its next goal waits for a morning to come ("day:<n>": the
## free evening, the waits for the rooster's and the pond's day): the bed takes the
## farmer at any hour (Bed), the goal's card says so (HINT_DAY_DONE), and the quiet farm
## chores come up meanwhile (FarmChores).
func day_work_done() -> bool:
	if tutorial_done():
		return false
	var g := current()
	return String(g["kind"]) == "check" and String(g["arg"]).begins_with("day:")


## The story has nothing for the farmer to do right now: its goal waits for a morning
## (day_work_done) or for the farm to grow a level (the milestones after the pond's day).
## FarmChores fills such hours on the first days.
func story_idle() -> bool:
	return day_work_done() or (not tutorial_done() and String(current()["arg"]) == "level")


## Real seconds a building of kit `id` takes to go up if it is put down now: the story's
## first coop and first workbench (their goals up or still ahead, none put down yet) go
## up in PlaceableTable.TUTORIAL_BUILD_SECONDS, so nobody stands a minute before a site
## with a goal waiting on it; every later one takes its usual time. (Placer keeps it in
## the site's entry; the construction board and the note read it too.)
func build_seconds(id: StringName) -> float:
	if not tutorial_done():
		if id == &"coop_kit" and step <= index_of("coop_built") and not FarmState.coop_started():
			return PlaceableTable.TUTORIAL_BUILD_SECONDS
		if id == &"workbench" and step <= index_of("bench_built") and _placed_count(&"workbench") == 0:
			return PlaceableTable.TUTORIAL_BUILD_SECONDS
	return PlaceableTable.build_seconds(id)


func goal_text(goal: Dictionary = {}) -> String:
	var g := goal if not goal.is_empty() else current()
	if g.is_empty():
		return ""
	if String(g["arg"]) == "level":
		return tr("QUEST_LEVEL") % int(g["count"])
	var text := tr("QUEST_%s" % String(g["id"]).to_upper())
	# Goals that name their count ("Earn $%d", "Buy %d rope").
	if text.contains("%d"):
		text = text % int(g["count"])
	# The coop or the workbench going up: the time it still needs.
	if String(g["id"]) == "coop_built":
		var site := _coop_going_up()
		if site:
			text += " · %s" % ConstructionSite.clock_text(site.seconds_left())
	elif String(g["id"]) == "bench_built":
		var bench := _bench_going_up()
		if bench:
			text += " · %s" % ConstructionSite.clock_text(bench.seconds_left())
	# What its project takes against what he has, then why the dot is somewhere else
	# first (the current goal only).
	if goal.is_empty() and _needs != "":
		text += "\n%s" % _needs
	if goal.is_empty() and _hint != "":
		text += "\n%s" % _hint
	return text


## The line under the current goal saying why the dot points where it does ("" when it
## points at the goal's own place). Short of money it is two lines: how much more it
## takes, and how to earn it (money_short).
func goal_hint() -> String:
	return _hint


## What the current goal's project from the construction board takes against what the
## farmer has ("Wood 32/50 · $120/200", the ones met ticked; "" for a goal that builds
## nothing): the kit or the building the board opens on for it (board_project), so nobody
## walks to the board to read what is missing. The coop's wood goal counts its wood
## itself; a kit Grandpa pays for (coop_kit_is_gift) asks for its wood only.
func goal_needs() -> String:
	if tutorial_done() or String(current()["id"]) == "coop_wood":
		return ""
	var id := board_project()
	var p := ProjectTable.get_project(id)
	if p.is_empty() or FarmState.is_built(id):
		return ""
	var gift := id == &"coop_kit" and coop_kit_is_gift()
	return needs_text(p.get("items", {}), 0 if gift else int(p.get("cost", 0)))


## "Wood 32/50 · $120/200": the materials `items` (id -> count) from the bag and `cost`
## dollars (none for 0) against what the farmer has, each ticked once it is met. The goal
## cards' requirement line (the story's, the doghouse's).
static func needs_text(items: Dictionary, cost := 0) -> String:
	var parts := PackedStringArray()
	for id: StringName in items:
		parts.append(need_part(ItemDB.get_item(id).display_name(), PlayerState.inventory.count_item(id), int(items[id])))
	if cost > 0:
		# "$120/200" where the sign comes first, "120/200 $" where it follows.
		var need := UiTheme.number(cost)
		var pair := "%s/%s" % [UiTheme.number(clampi(Economy.money, 0, cost)), need]
		var text := UiTheme.money(cost).replace(need, pair)
		parts.append("%s %s" % [text, NEED_MET] if Economy.money >= cost else text)
	return " · ".join(parts)


## One requirement on a goal's card: "Wood 32/50", ticked once it is met ("Wood 50/50 ✓").
static func need_part(what: String, have: int, need: int) -> String:
	var text := "%s %d/%d" % [what, clampi(have, 0, need), need]
	return "%s %s" % [text, NEED_MET] if have >= need else text


## Index in CHAPTERS of the current goal (the last chapter once the story is done).
func chapter() -> int:
	return int(current()["chapter"]) if not tutorial_done() else CHAPTERS.size() - 1


func chapter_title(index: int) -> String:
	return tr("CHAPTER_%s" % CHAPTERS[index].to_upper())


## Grandpa's notebook line that opens a chapter.
func chapter_note(index: int) -> String:
	return tr("CHAPTER_%s_NOTE" % CHAPTERS[index].to_upper())


## Where the HUD's waypoint dot points for the current goal: a Vector3, a Node3D it
## follows, or null for no dot. Cheap: the place is worked out a few times a second.
func waypoint() -> Variant:
	if typeof(_waypoint) == TYPE_OBJECT and not is_instance_valid(_waypoint):
		return null
	return _waypoint


## A finished farm action; sowing also counts by crop ("plant:wheat").
func _on_action_done(id: String, target: Node) -> void:
	_count("action", id, 1)
	if id == "plant" and target is FarmPlot:
		_count("action", "plant:%s" % (target as FarmPlot).crop, 1)


## Picked up ("picked", by item); wild berries off a bush count as foraged too.
func _on_picked_up(id: StringName, n: int) -> void:
	_count("picked", String(id), n)
	if ItemDB.has_item(id) and ItemDB.get_item(id).category == "forage":
		_count("forage", String(id), n)


## Made at a workbench ("crafted"), or a building kit cut at the construction board
## ("kit": the coop kit of day one is not the workshop's first piece of work).
func _on_crafted(id: StringName, n: int) -> void:
	if PlaceableTable.is_building(id):
		_count("kit", String(id), n)
		# The kit goals are checks: they look now, and the dot moves on to the kit's spot.
		_nudge()
	else:
		_count("crafted", String(id), n)


# --- The construction board ---------------------------------------------------------------

## The project the construction board opens on for the current goal (&"" for none): the
## coop kit while the coop is to be made (its wood being cut, the kit itself, a kit lost
## before it was put down), the workbench kit for the second day's, and any project a
## goal asks to be built ("built:<project>": the barn, the bigger house).
func board_project() -> StringName:
	if tutorial_done():
		return &""
	var g := current()
	match String(g["id"]):
		"coop_wood", "coop_kit":
			return &"coop_kit"
		"coop_place":
			return &"coop_kit" if not has_coop_kit() and not FarmState.coop_started() else &""
		"bench_kit":
			return &"workbench"
		"bench_place":
			return &"workbench" if PlayerState.inventory.count_item(&"workbench") == 0 and _placed_count(&"workbench") == 0 else &""
	var arg := String(g["arg"])
	if String(g["kind"]) == "check" and arg.begins_with("built:"):
		return StringName(arg.get_slice(":", 1))
	return &""


## The first day's money is kept for the coop: from the start of the story until the
## first coop kit is made (or a coop stands), the board sells nothing else that costs
## money (BuildScreen locks it, "the coop first"), so the kit's price can't be spent on a
## workbench by mistake. Should the money be gone all the same (spent at the market), the
## board makes that first kit for its wood alone (coop_kit_is_gift): never a dead end.
func coop_comes_first() -> bool:
	return first_day() and step <= index_of("coop_kit") and _check_progress("kit") == 0


## Grandpa paid for the first coop kit: true while the coop comes first and the farmer
## can't pay the kit's price (BuildScreen then asks for the wood only).
func coop_kit_is_gift() -> bool:
	return coop_comes_first() and Economy.money < int(ProjectTable.get_project(&"coop_kit").get("cost", 0))


## A coop kit at hand: in the bag (the hotbar and the hand included).
func has_coop_kit() -> bool:
	return PlayerState.inventory.count_item(&"coop_kit") > 0


## Straw laid in a coop's nests: counted as the most nests one coop has had filled, so
## a nest filled again after the hens used its straw isn't counted twice.
func _on_nest_filled(_coop: Node, filled: int) -> void:
	if tutorial_done():
		return
	var had := int(tally.get("nests:", 0))
	if filled > had:
		_count("nests", "", filled - had)


## Goods put in the shipping bin, counted by item and by category ("shipped:crop").
func _on_shipped(id: StringName, n: int) -> void:
	if tutorial_done():
		return
	var item := ItemDB.get_item(id)
	if item:
		var key := "shipped:%s" % item.category
		tally[key] = int(tally.get(key, 0)) + n
	_count("shipped", String(id), n)
	_nudge()


func _count(kind: String, arg: String, amount: int) -> void:
	if tutorial_done():
		return
	_tally(kind, arg, amount)
	var g := current()
	if g["kind"] != kind or (String(g["arg"]) != "" and String(g["arg"]) != arg):
		return
	var have := step_count + amount
	if bool(g.get("ever", false)):
		have = maxi(have, _tallied(g))
	step_count = mini(have, int(g["count"]))
	if step_count >= int(g["count"]):
		_complete()
	else:
		tutorial_changed.emit()


## Adds to the lifetime counts: "kind:arg", and "kind:" that goals taking any arg read.
func _tally(kind: String, arg: String, amount: int) -> void:
	var key := "%s:" % kind
	tally[key] = int(tally.get(key, 0)) + amount
	if arg != "":
		key += arg
		tally[key] = int(tally.get(key, 0)) + amount


## How much of what goal `g` asks for was done since the story began.
func _tallied(g: Dictionary) -> int:
	return int(tally.get("%s:%s" % [g["kind"], g["arg"]], 0))


## An "ever" goal counts what was done before it came up, and may be done at once; a
## goal whose count is met already (a save of an older chain asked for more) is done.
func _catch_up() -> void:
	if tutorial_done() or SaveGame.loading:
		return
	var g := current()
	if step_count >= int(g["count"]):
		_complete()
		return
	if not bool(g.get("ever", false)):
		return
	var have := mini(maxi(step_count, _tallied(g)), int(g["count"]))
	if have == step_count:
		return
	step_count = have
	if step_count >= int(g["count"]):
		_complete()
	else:
		tutorial_changed.emit()


func _complete() -> void:
	var g := current()
	# A goal a save did under an older chain passes without its experience again.
	var xp := 0 if tally.has(DONE_MARK % g["id"]) else int(g.get("xp", 0))
	if xp > 0:
		Progress.add(xp)
		Game.notify(tr("MSG_QUEST_DONE") % goal_text(g), UiTheme.GOLD)
	Audio.ui("confirm", -4.0)
	step += 1
	step_count = 0
	if tutorial_done():
		tally = {}
		Game.notify(tr("MSG_TUTORIAL_DONE"), UiTheme.GREEN)
		story_finished.emit()
	elif int(current()["chapter"]) != int(g["chapter"]):
		chapter_started.emit(int(current()["chapter"]))
	tutorial_changed.emit()
	_goal_started()
	# The next goal may be done already: it's counted next frame, so goals finished
	# ahead of time complete one after another rather than in one burst.
	_catch_up.call_deferred()


## A goal came up: the dot moves on at once, the drawer opens for its step, and a first
## day's story done late in the afternoon says evening is coming.
func _goal_started() -> void:
	_wp_left = 0.0
	_poll = minf(_poll, 0.25)
	_sync_drawer_lock()
	if tutorial_done() or DebugTools.is_automated():
		return
	if String(current()["id"]) == "free" and GameClock.day == 1 and GameClock.minute / 60.0 >= LINGER_HOUR:
		Game.notify(tr("MSG_EVENING"), UiTheme.GOLD_SOFT)


## Something the current goal may check just happened: look now, not in a second.
func _nudge() -> void:
	_poll = 0.0
	_wp_left = 0.0


## Every frame: the first day's pace and the dot. Once a second: the first day's farm
## set-up, then a "check" goal looks at the world, a goal behind the player ("past")
## completes, and an "ever" goal that was set from outside (a load, a debug shot)
## catches up with the tally.
func _process(delta: float) -> void:
	_pace()
	_tick_new_building(delta)
	if tutorial_done() or SaveGame.loading:
		_waypoint = null
		_needs = ""
		return
	_wp_left -= delta
	if _wp_left <= 0.0:
		_wp_left = WAYPOINT_REFRESH
		# Grandpa's spots are looked for as often as the dot moves: a pickup driving by
		# is through one in a second or two.
		if String(current()["kind"]) == "visit":
			_visit_spots()
		var hint := _hint
		var needs := _needs
		_hint = ""
		_waypoint = _target(String(current().get("at", "")))
		_needs = goal_needs()
		# Waiting for the morning: the card says the bed is open at any hour.
		if _hint == "" and day_work_done():
			_hint = tr("HINT_DAY_DONE")
		if _hint != hint or _needs != needs:
			tutorial_changed.emit()
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 1.0
	_first_day_setup()
	var g := current()
	var past := String(g.get("past", ""))
	if tally.has(DONE_MARK % g["id"]) or (past != "" and _check_progress(past) > 0):
		step_count = int(g["count"])
		_complete()
		return
	if g["kind"] != "check":
		_catch_up()
		return
	var have := _check_progress(String(g["arg"]), int(g["count"]))
	if have >= int(g["count"]):
		step_count = int(g["count"])
		_complete()
	elif have != step_count:
		step_count = have
		tutorial_changed.emit()
	elif String(g["id"]) in ["coop_built", "bench_built"]:
		tutorial_changed.emit()  # the build clock in the goal text


## How far a "check" goal is along (`count`: what the goal asks for, for the checks that
## report progress toward it).
func _check_progress(arg: String, count := 1) -> int:
	var what := arg.get_slice(":", 1)
	match arg.get_slice(":", 0):
		"flag":
			var v: Variant = FarmState.flags.get(what, false)
			return 1 if v is bool and v else 0
		"table":
			# Done when the worktable is bare, however many things lay on it.
			var taken := FarmHouse.table_taken_count()
			return count if taken >= FarmHouse.table_item_count() else mini(taken, maxi(count - 1, 0))
		"took":
			return FarmHouse.table_taken_count()
		"key":
			return 1 if _has_truck_key() else 0
		"driving":
			# At the wheel of one of the player's own vehicles (Grandpa's pickup at first).
			var p := _player()
			return 1 if p != null and p.driving != null and p.driving.owned else 0
		"hens":
			# Bought: in crates anywhere (waiting at the market, the bed, the bag, the
			# warehouse) or let out.
			var crated := LiveCrates.count_at(&"all", AnimalTable.crate_item(&"chicken"))
			return maxi(crated + _animal_count(&"chicken"), int(tally.get("bought:chicken", 0)))
		"home":
			# Back with the hens: none of them left waiting at the Animal Market's pickup
			# spot (the dot sends the farmer back for them, _target("home")).
			var left := LiveCrates.count_at(&"market", AnimalTable.crate_item(&"chicken"))
			return 1 if _near("home") and left == 0 else 0
		"owned":
			# Bought: in its crate anywhere (waiting at the market, the bed, the bag, the
			# warehouse) or living here.
			var sp := StringName(what)
			var crate := AnimalTable.crate_item(sp)
			var crated := LiveCrates.count_at(&"all", crate) if crate != &"" else 0
			return maxi(crated + _animal_count(sp), int(tally.get("bought:%s" % what, 0)))
		"crates":
			# Stored in the warehouse; hens let out already count too.
			return LiveCrates.count_at(&"warehouse", AnimalTable.crate_item(&"chicken")) + _animal_count(&"chicken")
		"kit":
			var made := PlayerState.inventory.count_item(&"coop_kit") > 0 or int(tally.get("kit:coop_kit", 0)) > 0
			return 1 if made or FarmState.coop_started() else 0
		"coop":
			return 1 if (FarmState.has_coop() if what == "built" else FarmState.coop_started()) else 0
		"bin":
			return maxi(ShippingBin.count_in_bin(StringName(what)), int(tally.get("shipped:%s" % what, 0)))
		"warehouse":
			return 1 if FarmState.warehouse.total() > 0 else 0
		"crops":
			# Harvested crops at hand: in the bag or already in a pickup's bed.
			return _crop_units_in_bag() + _crop_units_in_cargo()
		"cargo":
			if what == "crop":
				return _crop_units_in_cargo()
			# Goods in the bed of one of the player's vehicles.
			for v: Vehicle in get_tree().get_nodes_in_group(Vehicle.GROUP):
				if v.owned and v.cargo != null and v.cargo.total() > 0:
					return 1
			return 0
		"near":
			return 1 if _near(what) else 0
		"day":
			return 1 if GameClock.day >= int(what) else 0
		"level":
			return Progress.level
		"built":
			return 1 if FarmState.is_built(StringName(what)) else 0
		"animals":
			return _animal_count(StringName(what))
		"trailer":
			# The stock trailer's lesson in the barn chapter.
			return TrailerGoals.progress(what)
		"has":
			return PlayerState.inventory.count_item(StringName(what)) + _placed_count(StringName(what))
		"rods":
			return _rod_count()
		"bench":
			match what:
				"kit":
					var got := PlayerState.inventory.count_item(&"workbench") > 0 or int(tally.get("kit:workbench", 0)) > 0
					return 1 if got or _placed_count(&"workbench") > 0 else 0
				"started":
					return 1 if _placed_count(&"workbench") > 0 else 0
				"built":
					return 1 if _bench_built() else 0
		"bait":
			return _bait_count()
		"caught":
			return int(tally.get("caught:", 0))
		"full":
			# Too full to eat now (Eating's "You're full"): no bite asked for.
			return 1 if PlayerState.needs.hunger >= Needs.MAX - Eating.FULL_MARGIN else 0
		"nobush":
			# Every wild bush in the valley picked bare (or none at all): no berries to ask for.
			return 1 if _nearest_berry_bush(Vector3.ZERO) == null else 0
		"nosapling":
			# Not every felled tree drops a sapling: none in the bag, none asked for.
			return 1 if PlayerState.inventory.count_item(SaplingGrove.ITEM) == 0 else 0
		"bedsready", "nofield", "nodry":
			# The field as it stands: a farmer who tilled, sowed or watered everything
			# already is never asked for more than there is.
			var ready := 0
			var untilled := 0
			var dry := 0
			for n in get_tree().get_nodes_in_group(&"farm_plots"):
				var plot := n as FarmPlot
				if plot == null:
					continue
				if plot.soil == FarmPlot.Soil.UNTILLED:
					untilled += 1
				elif plot.crop == &"":
					ready += 1
				elif not plot.withered and not plot.is_wet():
					dry += 1
			match arg:
				"bedsready":
					return 1 if ready >= 3 or untilled == 0 else 0
				"nofield":
					return 1 if ready == 0 and untilled == 0 else 0
				_:
					return 1 if dry == 0 else 0
	return 0


## A cooked meal (ItemTable category "food": a fish off the campfire), not a raw bite.
func _is_meal(id: StringName) -> bool:
	if ItemDB.has_item(id) and ItemDB.get_item(id).category == "food":
		return true
	return String(id).ends_with("_cooked")


## Something to eat in the bag (Eating.food_value).
func _has_food() -> bool:
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and Eating.food_value(st.item.id) > 0:
			return true
	return false


## The nearest wild bush with berries on it, or null.
func _nearest_berry_bush(from: Vector3) -> Variant:
	var best: BerryBush = null
	var best_d := INF
	for b: BerryBush in get_tree().get_nodes_in_group(&"berry_bushes"):
		var d := b.global_position.distance_squared_to(from)
		if b.is_ripe() and d < best_d:
			best = b
			best_d = d
	if best == null:
		return null
	return best.global_position + Vector3(0, 1.2, 0)


## A finished workbench stands on the farm (benches from before the kit have no stage).
func _bench_built() -> bool:
	for e: Dictionary in FarmState.placed:
		if StringName(e["id"]) == &"workbench" and String(e.get("stage", "done")) == "done":
			return true
	return false


## Fishing rods of any kind in the bag (the cane rod up to the carp rod).
func _rod_count() -> int:
	var n := 0
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.tool_type == &"fishing_rod":
			n += st.count
	return n


## Bait in the bag (worms, dough: ItemTable category "bait").
func _bait_count() -> int:
	var n := 0
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.category == "bait":
			n += st.count
	return n


## How many `id` are put down on the farm (FarmState.placed).
func _placed_count(id: StringName) -> int:
	var n := 0
	for e: Dictionary in FarmState.placed:
		if StringName(e["id"]) == id:
			n += 1
	return n


func _animal_count(species: StringName) -> int:
	var n := 0
	for a: AnimalData in Animals.animals:
		if a.species == species:
			n += 1
	return n


## The pickup's key was found: taken from the drawer, in the bag, or already in the
## ignition (old saves, automated runs).
func _has_truck_key() -> bool:
	if bool(FarmState.flags.get(FarmHouse.KEY_FLAG, false)) or PlayerState.inventory.count_item(&"truck_key") > 0:
		return true
	var truck := _farm_truck()
	return truck != null and not truck.is_locked()


## The player in the world (null while the game scene is being rebuilt).
func _player() -> Player:
	var p := Game.player
	if not is_instance_valid(p) or not p.is_inside_tree():
		return null
	return p as Player


## Whether the player (on foot or at the wheel) is at `place`: "town" is the Yeşilova
## valley, "home" the farmyard by the warehouse.
func _near(place: String) -> bool:
	var p := _player()
	if p == null:
		return false
	var at := Vector2(p.global_position.x, p.global_position.z)
	match place:
		"town":
			return at.distance_to(WorldLayout.TOWN_CENTER) < WorldLayout.TOWN_VALLEY_RADIUS
		"home":
			var door := _warehouse_door()
			return at.distance_to(Vector2(door.x, door.z)) < HOME_RADIUS
	return false


func skip_tutorial() -> void:
	step = TUTORIAL.size()
	step_count = 0
	tally = {}
	# The story is over: the desk drawer (and the pickup's key in it) opens for good.
	_sync_drawer_lock()
	tutorial_changed.emit()


# --- The first day ------------------------------------------------------------------------

## The story's egg thrown away before it was shipped, with no other to hand (in the bag,
## the bin or lying about): the story asks for an egg again, and a hen lays one soon
## (eggs otherwise come each morning).
func _on_egg_broken() -> void:
	if tutorial_done() or (step != index_of("egg") and step != index_of("ship_egg")):
		return
	if _eggs_left() > 0:
		return
	# The eggs picked up so far were for the broken one: the next one counts afresh.
	tally.erase("picked:egg")
	if step != index_of("egg"):
		step = index_of("egg")
		step_count = 0
		tutorial_changed.emit()
		_goal_started()
	var coop := _newest_coop()
	if coop:
		coop.hurry_egg()
	Game.notify(tr("MSG_EGG_BROKEN"), UiTheme.RED)


## Eggs the player could still ship: in the bag, the bin (or shipped), the warehouse or
## lying on the farm.
func _eggs_left() -> int:
	var n := PlayerState.inventory.count_item(&"egg") + FarmState.warehouse.count(&"egg")
	n += _check_progress("bin:egg")
	for p in get_tree().get_nodes_in_group(&"pickups"):
		var pk := p as Pickup
		if pk and not pk.is_queued_for_deletion() and pk.stack and pk.stack.item.id == &"egg":
			n += pk.stack.count
	return n


## The walk round the land: a spot of Grandpa's the player (on foot or at the wheel) has
## come to counts once ("visit:<id>" in the tally, saved with it), with his line about it
## under the goal and its name in a note.
func _visit_spots() -> void:
	var p := _player()
	if p == null:
		return
	var at := Vector2(p.global_position.x, p.global_position.z)
	for id: String in EXPLORE_SPOTS:
		if tally.has("visit:%s" % id):
			continue
		var spot: Dictionary = EXPLORE_SPOTS[id]
		if at.distance_to(spot["at"]) < float(spot["reach"]):
			reach_spot(id)
			return


## Grandpa's spot `id` reached (once): its name in a note, his line under the goal, and
## the walk counts it (debug shots call it too).
func reach_spot(id: String) -> void:
	if tally.has("visit:%s" % id) or not EXPLORE_SPOTS.has(id):
		return
	Game.notify(tr("MSG_SPOT_FOUND") % spot_name(id), UiTheme.GOLD_SOFT)
	Audio.ui("confirm", -8.0)
	spot_visited.emit(id, tr("EXPLORE_%s_LINE" % id.to_upper()))
	_count("visit", id, 1)


## A spot's name on the walk round the land ("Grandpa's pond").
func spot_name(id: String) -> String:
	return tr("SPOT_%s" % id.to_upper())


## Grandpa's spots not reached yet, in the walk's order.
func spots_left() -> Array[String]:
	var left: Array[String] = []
	for id: String in EXPLORE_SPOTS:
		if not tally.has("visit:%s" % id):
			left.append(id)
	return left


## Where the dot floats over Grandpa's spot `id` (over the water at the pond).
func spot_point(id: String) -> Vector3:
	var spot: Dictionary = EXPLORE_SPOTS[id]
	var xz: Vector2 = spot["at"]
	var ground := maxf(TerrainData.height(xz.x, xz.y), WorldLayout.WATER_LEVEL)
	return Vector3(xz.x, ground + float(spot["lift"]), xz.y)


## Once a second while the story runs: Grandpa's ripe beds on a new farm, and the desk
## drawer kept shut until its step.
func _first_day_setup() -> void:
	_dress_grandpa_beds()
	_keep_beds_for_harvest()
	_sync_drawer_lock()


## A new farm's first field has Grandpa's last crop ripe at its far end (the beds farthest
## from the house): the first harvest of the story. Once per farm, on beds nobody touched.
func _dress_grandpa_beds() -> void:
	if FarmState.flags.has(BEDS_FLAG) or GameClock.day > 1 or not FarmHouse.first_day():
		return
	if tutorial_done() or step > index_of("harvest"):
		return
	var field := _first_field()
	if field == null or field.plots.is_empty():
		return
	var beds: Array[FarmPlot] = []
	for pl: FarmPlot in field.plots:
		if pl.soil == FarmPlot.Soil.UNTILLED and pl.crop == &"":
			beds.append(pl)
	_ripen_beds(beds, GRANDPA_BEDS)
	FarmState.flags[BEDS_FLAG] = true


## The harvest step always has ripe beds to cut: any that went missing before it (a
## rebuilt field, an early swing of the scythe...) come back ripe at the field's far end.
func _keep_beds_for_harvest() -> void:
	if tutorial_done() or step != index_of("harvest"):
		return
	var field := _first_field()
	if field == null or field.plots.is_empty():
		return
	var need := int(TUTORIAL[step]["count"]) - step_count
	var free: Array[FarmPlot] = []
	for pl: FarmPlot in field.plots:
		if pl.crop != &"" and not pl.withered and pl.is_ready():
			need -= 1
		elif pl.crop == &"" or pl.withered:
			free.append(pl)
	if need > 0:
		_ripen_beds(free, need)


## Grandpa's beds wait for the harvest goal: until it comes up nothing shows over them
## and no tool works on them (FarmPlot.held_back), so the first day's steps before it
## aren't muddled by a harvest the story hasn't asked for yet.
func holds_grandpa_beds() -> bool:
	return not tutorial_done() and step < index_of("harvest")


## Grandpa's crop, ripe and watered, on the `count` beds of `beds` farthest from the house
## (marked as his: FarmPlot.grandpa).
func _ripen_beds(beds: Array[FarmPlot], count: int) -> void:
	var crop: StringName = GRANDPA_CROP if CropTable.in_season(GRANDPA_CROP, GameClock.get_season()) else &"wheat"
	var door := Vector3(WorldLayout.HOUSE_DOOR_X, 0.0, WorldLayout.HOUSE_FRONT_Z)
	beds.sort_custom(func(a: FarmPlot, b: FarmPlot) -> bool:
		return a.global_position.distance_squared_to(door) > b.global_position.distance_squared_to(door))
	for pl: FarmPlot in beds.slice(0, count):
		pl.load_data({"soil": FarmPlot.Soil.TILLED, "crop": String(crop),
			"growth": float(CropTable.get_crop(crop).get("grow_h", 20)), "wet": 4.0, "grandpa": true})


func _first_field() -> Field:
	var farm := _farm()
	if farm == null:
		return null
	var f: Variant = farm.fields.get(&"field_0")
	return f as Field if is_instance_valid(f) else null


## The key waits in the desk drawer for its step: the drawer stays shut (no prompt) on a
## new farm until then (FarmHouse.DRAWER_LOCK_FLAG), and opens for good after.
func _sync_drawer_lock() -> void:
	var lock := false
	if FarmHouse.first_day() and not tutorial_done() and step < index_of("drawer"):
		lock = not bool(FarmState.flags.get(FarmHouse.KEY_FLAG, false)) \
				and not bool(FarmState.flags.get(FarmHouse.DRAWER_FLAG, false))
	if lock and not FarmState.flags.has(FarmHouse.DRAWER_LOCK_FLAG):
		FarmState.flags[FarmHouse.DRAWER_LOCK_FLAG] = true
	elif not lock and FarmState.flags.has(FarmHouse.DRAWER_LOCK_FLAG):
		FarmState.flags.erase(FarmHouse.DRAWER_LOCK_FLAG)


## The first day's clock (see FIRST_DAY_RATE, and SECOND_DAY_RATE for the second day's
## work): set while it runs, given back after (the night, a skip, a load).
func _pace() -> void:
	if _paces_day():
		# Hours past midnight count on (25.0 is 01:00): the day ends at the first sleep.
		var want := pace_for(GameClock.minute / 60.0) if GameClock.day == 1 else second_day_pace()
		if GameClock.time_scale != want:
			GameClock.time_scale = want
		_paced = true
	elif _paced:
		GameClock.time_scale = 1.0
		_paced = false


func _paces_day() -> bool:
	if SaveGame.loading or DebugTools.is_automated():
		return false
	if GameClock.day == 1:
		return first_day() and FarmHouse.first_day()
	# The second day's work, up to its own evening (rooster_wait), in daylight only (the
	# wolves' night runs as usual).
	return GameClock.day == 2 and GameClock.minute < SECOND_DAY_UNTIL * 60.0 and not tutorial_done() \
			and int(current()["chapter"]) >= DAY_TWO_CHAPTER and step < index_of("rooster_wait")


## The first day's time scale at `hour` (from 13.0, past 24 after midnight) while its
## story runs, at the day length set (FIRST_DAY_PACE and LINGER_PACE at the default;
## tests check it).
func pace_for(hour: float) -> float:
	return _pace_of(FIRST_DAY_RATE if hour < LINGER_HOUR else LINGER_RATE)


## The second day's time scale while its goals are up (SECOND_DAY_PACE at the default
## day length).
func second_day_pace() -> float:
	return _pace_of(SECOND_DAY_RATE)


## The time scale at which the clock runs `rate` game minutes a real minute at the day
## length set (Settings.game_minutes_per_second): a longer day's clock is slower to
## begin with and is slowed less, so the story's days last the same real time.
func _pace_of(rate: float) -> float:
	return rate / maxf(Settings.game_minutes_per_second() * 60.0, 0.001)


# --- Waypoints ----------------------------------------------------------------------------

## Where the HUD's dot floats: over a building just finished first, else at the goal's
## place (waypoint()).
func guide_point() -> Variant:
	return _new_building if _new_building != null else waypoint()


## The line on the dot's pill while it shows a new building ("" otherwise).
func guide_label() -> String:
	return _new_building_text if _new_building != null else ""


## A project from the construction board (or mended by hand) is built: its gate or door.
func _on_project_built(id: StringName) -> void:
	var at: Variant = null
	match id:
		&"barn_1", &"barn_2":
			var g := WorldLayout.gate_point(WorldLayout.BARN_PEN, WorldLayout.BARN_GATE, 0.0)
			at = _ground(g.x, g.z, 1.9)
		&"coop_1", &"coop_2":
			var g := WorldLayout.gate_point(WorldLayout.COOP_PEN, WorldLayout.COOP_GATE, 0.0)
			at = _ground(g.x, g.z, 1.6)
		&"house_1", &"house_2", &"house_3":
			at = _target("house_door")
		&"warehouse_1", &"warehouse_2":
			var door := WaypointMarker.anchor(&"warehouse")
			at = door.global_position if door else _warehouse_door()
		_:
			var lot: Dictionary = WorldLayout.FIELD_LOTS.get(id, {})
			if not lot.is_empty():
				var g := WorldLayout.gate_point(lot["rect"], lot["gates"][0], 0.0)
				at = _ground(g.x, g.z, 1.6)
	_guide_to(at, tr("PROJECT_" + String(id).to_upper()))


## A kit building finished on its site (a coop, the workbench), or a coop made longer:
## its door or top.
func _on_building_completed(id: StringName, building: Node) -> void:
	if building is ChickenCoop:
		var coop := building as ChickenCoop
		_guide_to(coop.door_point() + Vector3(0, 1.4, 0), coop.coop_name() if id == ChickenCoop.EXPAND_ID else tr("HOUSING_COOP"))
	elif building is Workbench:
		_guide_to((building as Workbench).top_point(), tr("PROJECT_" + String(id).to_upper()))
	elif building is Node3D and (building as Node3D).is_inside_tree():
		_guide_to((building as Node3D).global_position + Vector3(0, 2.0, 0), tr("PROJECT_" + String(id).to_upper()))


## Points the dot at `at` (a Vector3; null: nowhere) for the building `building_name`
## just finished (instead of an older one's), unless the player stands by it already.
func _guide_to(at: Variant, building_name: String) -> void:
	if typeof(at) != TYPE_VECTOR3 or (DebugTools.is_automated() and not guide_in_tests):
		return
	_new_building = null
	_new_building_text = ""
	var p := _player()
	if p and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < NEW_BUILDING_NEAR:
		return
	_new_building = at
	_new_building_text = tr("HINT_NEW_BUILDING") % building_name
	_new_building_shown = 0.0


## Shows the dot over `at` a while, as over a building just finished, with `place_name`
## on its pill (the construction board's "Show" on one of the coops).
func point_out(at: Vector3, place_name: String) -> void:
	_new_building = at
	_new_building_text = tr("HINT_NEW_BUILDING") % place_name
	_new_building_shown = 0.0


## Drops the new building's dot once the player is there or its time is up.
func _tick_new_building(delta: float) -> void:
	if _new_building == null:
		return
	var at: Vector3 = _new_building
	var p := _player()
	var there := p != null and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < NEW_BUILDING_NEAR
	if not Game.is_ui_open() and not SaveGame.loading:
		_new_building_shown += delta
	if there or _new_building_shown >= (NEW_BUILDING_BRIEF if waypoint() != null else NEW_BUILDING_TIME):
		_new_building = null
		_new_building_text = ""

## Where the dot points for a goal's "at" (a Vector3 or a Node3D; null for none).
func _target(at: String) -> Variant:
	if at == "" or Game.world == null:
		return null
	var p := _player()
	var from := p.global_position if p else Vector3(WorldLayout.HOUSE_DOOR_X, 0.0, WorldLayout.HOUSE_FRONT_Z)
	match at.get_slice(":", 0):
		"house_door":
			var house := _house()
			return house.door_point() if house else _ground(WorldLayout.HOUSE_DOOR_X, WorldLayout.HOUSE_FRONT_Z, FarmHouse.FLOOR_Y + 1.2)
		"table":
			var house := _house()
			if house == null:
				return null
			return house.table_point()
		"drawer":
			var house := _house()
			if house == null:
				return null
			return house.drawer_point()
		"name_board":
			# Grandpa's name board at the farm's entrance; the line says where it stands.
			_hint = tr("HINT_NAME_BOARD")
			var name_board := FarmIdentity.board()
			return _anchor(NameBoard.ANCHOR, name_board.guide_point() if name_board else null)
		"key":
			var house := _house()
			if house == null:
				return null
			var drawer := house.desk_drawer()
			if drawer:
				for item: WorldItem in drawer.items():
					if is_instance_valid(item):
						return item.waypoint_point()
			return house.drawer_point()
		"plot":
			var state := at.get_slice(":", 1)
			var spot: Variant = _plot_spot(state, from)
			# Nothing tilled to sow into: till another bed first.
			if spot == null and state == "empty":
				spot = _plot_spot("untilled", from)
			# No bone-dry bed (rain, or all watered once): any bed the can still takes.
			elif spot == null and state == "dry":
				spot = _plot_spot("waterable", from)
			return spot
		"rooster_market":
			# The rooster costs money: short of it, where to earn it first.
			if not _can_pay(LiveCrates.price(&"rooster")):
				return _earn_target(from)
			return _target("stall")
		"truck":
			# At the wheel already: on to the Animal Market's hen stall.
			if p and p.driving != null:
				return _target("stall")
			return _anchor(&"truck", _truck_roof_point())
		"stall":
			# The hen stall in the Animal Market's lane (its marker is "town_chickens").
			var town := _town()
			var fallback: Variant = null
			if town and town.poultry_stall:
				fallback = town.poultry_stall.global_position + Vector3(0, 1.5, 0)
			elif town and town.market_counter:
				fallback = town.market_counter.global_position + Vector3(0, 1.5, 0)
			return _anchor(&"town_chickens", fallback)
		"home":
			# Hens still waiting at the market: into the pickup first (every one of them,
			# even with some carried off already: the goal wants them all home).
			var hens_waiting: Variant = _waiting_crates(AnimalTable.crate_item(&"chicken"), true)
			if hens_waiting != null:
				return hens_waiting
			# The hens ride in the bed: on foot away from the pickup, back to it first.
			if p and p.driving == null and LiveCrates.count_at(&"bed") > 0:
				var truck := _farm_truck()
				if truck and truck.global_position.distance_to(from) > 12.0:
					return _anchor(&"truck", _truck_roof_point())
			return _anchor(&"warehouse", _warehouse_door())
		"crates":
			var crates_waiting: Variant = _waiting_crates(AnimalTable.crate_item(&"chicken"))
			if crates_waiting != null:
				return crates_waiting
			if LiveCrates.count_at(&"carried") > 0:
				return _anchor(&"crate_bay", _warehouse_door())
			if LiveCrates.count_at(&"bed") > 0:
				return _anchor(&"truck_bed", _truck_roof_point())
			return _anchor(&"warehouse", _warehouse_door())
		"trees":
			# The coop's wood is for its kit: with a kit made already (or a coop going up)
			# no tree is asked for; on to where the kit goes.
			if String(current().get("id", "")) == "coop_wood" and (has_coop_kit() or FarmState.coop_started()):
				return _target("coop_spot")
			var logs: Variant = _nearest_pickup(&"wood", from, 30.0)
			return logs if logs != null else _nearest_tree(from)
		"rocks":
			var chips: Variant = _nearest_pickup(&"stone", from, 30.0)
			return chips if chips != null else _nearest_rock(from)
		"board":
			# A kit in the bag (or a coop going up) is past the board and its wood: the dot
			# never goes back to the trees, it shows where the kit goes.
			if has_coop_kit() or FarmState.coop_started():
				return _target("coop_spot")
			# The kit takes wood from the bag: short of it, the trees first, and the line
			# under the goal says how much is missing. (Its price too, once Grandpa no
			# longer pays for it: coop_kit_is_gift.)
			return _project_target(&"coop_kit", from, coop_kit_is_gift())
		"coop_spot":
			# The kit is on the ground (dropped, or the bag was full when it was made): pick
			# it up; gone altogether with no coop going up: the board makes another.
			if not has_coop_kit() and not FarmState.coop_started():
				var kit: Variant = _nearest_pickup(&"coop_kit", from, 400.0)
				if kit != null:
					return kit
				if String(current().get("id", "")) == "coop_place":
					return _ground(WorldLayout.BOARD_POS.x, WorldLayout.BOARD_POS.z, 1.9)
			if not _coop_spot_searched:
				_coop_spot_searched = true
				_coop_spot = _find_coop_spot()
			return _coop_spot
		"coop":
			var coop := _newest_coop()
			if coop:
				return _anchor(ChickenCoop.ANCHOR_COOP, coop.center_point() + Vector3(0, 3.0, 0))
			var farm := _farm()
			if farm and farm.coop and farm.coop.level > 0:
				var c := WorldLayout.COOP_BUILDING.get_center()
				return _ground(c.x, c.y, 2.5)
			# The site was picked up again (the kit is back in the bag): set it down.
			if PlayerState.inventory.count_item(&"coop_kit") > 0:
				return _target("coop_spot")
			return null
		"hens":
			# The goal's kind (hens, the rooster) still at the market: into the pickup first.
			var kind := StringName(String(current().get("arg", "")).get_slice(":", 1))
			var bird_crate := AnimalTable.crate_item(kind if AnimalTable.crate_item(kind) != &"" else &"chicken")
			var birds_waiting: Variant = _waiting_crates(bird_crate)
			if birds_waiting != null:
				return birds_waiting
			# Crates in hand go to the coop door; else fetch them from where they wait.
			if LiveCrates.count_at(&"carried") > 0:
				return _coop_door()
			if LiveCrates.count_at(&"warehouse") > 0:
				return _anchor(&"crate_bay", _warehouse_door())
			if LiveCrates.count_at(&"bed") > 0:
				return _anchor(&"truck_bed", _truck_roof_point())
			return _coop_door()
		"bin":
			var b := WorldLayout.SHIPPING_BIN_POS
			return _anchor(&"shipping_bin", _ground(b.x, b.z, 1.1))
		"egg":
			var egg := WaypointMarker.anchor(ChickenCoop.ANCHOR_EGG)
			return egg if egg else _target("coop")
		"well":
			return _ground(WorldLayout.WELL_POS.x, WorldLayout.WELL_POS.z, 1.5)
		"warehouse":
			return _anchor(&"warehouse", _warehouse_door())
		"market":
			var town := _town()
			if town == null or town.market_counter == null:
				return null
			return town.market_counter.global_position + Vector3(0, 1.5, 0)
		"feeder":
			# The feed sack waits in the warehouse: fetch it first. The dot floats inside
			# the shed (E opens its storage from anywhere in there), and the line under the
			# goal says what to do.
			if PlayerState.inventory.count_item(&"feed") == 0:
				_hint = tr("HINT_FEED_WAREHOUSE")
				return _anchor(Warehouse.ANCHOR_INSIDE, _anchor(&"warehouse", _warehouse_door()))
			return _anchor(&"coop_feeder", _target("coop"))
		"coop_water":
			# An empty can goes to the well first.
			if not _can_has_water():
				return _target("well")
			return _anchor(&"coop_water", _target("coop"))
		"nests":
			# Short of straw for the nests still empty: hay lying about, else grass to cut.
			var want := maxi(int(current().get("count", 1)) - step_count, 1)
			if PlayerState.inventory.count_item(&"hay") < want:
				var hay: Variant = _nearest_pickup(&"hay", from, 30.0)
				if hay == null:
					hay = _nearest_grass(from)
				if hay != null:
					return hay
			return _anchor(&"coop_nest", _target("coop"))
		"house_repair":
			# Boards are mended with wood in hand: none left, the trees first.
			if PlayerState.inventory.count_item(&"wood") == 0:
				return _target("trees")
			var house := _house()
			var door: Variant = house.door_point() if house else null
			return _anchor(&"house_repair", door)
		"warehouse_repair":
			# The same with the warehouse's boards.
			if PlayerState.inventory.count_item(&"wood") == 0:
				return _target("trees")
			return _anchor(&"warehouse_repair", _warehouse_door())
		"earn":
			return _earn_target(from)
		"sell_market":
			# To town at the wheel of the loaded pickup, then the market counter. The line
			# under the goal says what sells and where (the first sale of the story).
			_hint = tr("HINT_WHAT_SELLS")
			var pl := _player()
			if _near("town") or (pl and pl.driving != null):
				return _target("market")
			return _target("truck_load")
		"truck_load":
			# The harvest into the pickup's bed: nothing to load yet, the ripe beds first.
			if _crop_units_in_bag() == 0:
				var ripe_bed: Variant = _plot_spot("ripe", from)
				if ripe_bed != null:
					return ripe_bed
			return _anchor(&"truck", _truck_roof_point())
		"bench_board":
			# The kit costs money and wood: short of either, where to get it first.
			return _project_target(&"workbench", from)
		"project":
			# A building from the construction board (the barn, the bigger house): the
			# same, then the board.
			return _project_target(StringName(at.get_slice(":", 1)), from)
		"animal":
			# A grown animal from the Animal Market: short of its price, where to earn it
			# first; then its pen there.
			var kind := StringName(at.get_slice(":", 1))
			if not _can_pay(LiveCrates.price(kind)):
				return _earn_target(from)
			var market := _town()
			var pen: Variant = market.market_pens.get(kind) if market else null
			if pen is Node3D and (pen as Node3D).is_inside_tree():
				return (pen as Node3D).global_position + Vector3(0, 1.2, 0)
			return _target("stall")
		"trailer":
			# The stock trailer's lesson: its place and the line that names the key.
			var lesson := TrailerGoals.place(at.get_slice(":", 1))
			_hint = String(lesson.get("hint", ""))
			return lesson.get("at")
		"bench_spot":
			if PlayerState.inventory.count_item(&"workbench") == 0 and _placed_count(&"workbench") == 0:
				return _target("bench_board")
			_hint = tr("HINT_PLACE_KIT")
			if not _bench_spot_searched:
				_bench_spot_searched = true
				_bench_spot = _find_bench_spot()
			return _bench_spot
		"bench":
			var bench := _nearest_placed(&"workbench", from) as Workbench
			if bench:
				return bench.top_point()
			if PlayerState.inventory.count_item(&"workbench") > 0:
				return _target("bench_spot")
			return _target("bench_board")
		"craft":
			return _craft_target(StringName(at.get_slice(":", 1)), from)
		"buy":
			return _buy_target(StringName(at.get_slice(":", 1)), maxi(int(current().get("count", 1)) - step_count, 1))
		"bait":
			# In town (buying the rope): dough from the market on the same trip. At home with
			# wheat and a bench, dough can be kneaded there instead.
			if not _near("town"):
				var dough: Dictionary = RecipeTable.crafting(&"dough")
				var wheat := int((dough.get("items", {}) as Dictionary).get(&"wheat", 2))
				if PlayerState.inventory.count_item(&"wheat") >= wheat and _bench_built():
					_hint = tr("HINT_DOUGH")
					return _target("bench")
			return _buy_target(&"dough", 1)
		"pond":
			if _rod_count() == 0:
				return _craft_target(&"fishing_rod", from)
			if _bait_count() == 0:
				_hint = tr("HINT_NEED_BAIT")
				return _target("bait")
			return _pond_edge(from)
		"explore":
			# The next of Grandpa's spots not reached yet, named under the goal.
			var left := spots_left()
			if left.is_empty():
				return null
			_hint = tr("HINT_EXPLORE_NEXT") % spot_name(left[0])
			return spot_point(left[0])
		"berries":
			# The nearest wild bush with berries on it (none left anywhere passes the goal).
			var ripe_bush: Variant = _nearest_berry_bush(from)
			if ripe_bush != null:
				_hint = tr("HINT_BERRIES")
			return ripe_bush
		"seeds":
			var seed_id := _seed_to_buy()
			if seed_id == &"":
				return null
			# Short of money: where his own goods sell, named under the goal.
			if Economy.money < seeds_cost():
				return _seeds_short()
			return _buy_target(seed_id, maxi(int(current().get("count", 1)) - step_count, 1))
		"sapling":
			# Hold the sapling and plant it: the dot suggests open ground by the pond.
			_hint = tr("HINT_PLANT_SAPLING")
			if not _sapling_spot_searched:
				_sapling_spot_searched = true
				_sapling_spot = _find_sapling_spot()
			return _sapling_spot
		"food":
			# Food in the bag already: hold it and eat (no dot). Else berries off a wild bush.
			if _has_food():
				_hint = tr("HINT_EAT_FOOD")
				return null
			var bush: Variant = _nearest_berry_bush(from)
			if bush != null:
				_hint = tr("HINT_BERRIES")
			return bush
		"campfire":
			var fire := _nearest_placed(&"campfire", from)
			if fire == null:
				if PlayerState.inventory.count_item(&"campfire") > 0:
					_hint = tr("HINT_PLACE_FIRE")
					return null
				return _craft_target(&"campfire", from)
			if not _has_raw_fish():
				_hint = tr("HINT_NEED_FISH")
				return _target("pond")
			return fire.global_position + Vector3(0, 1.0, 0)
	return null


## The dot while crates of `crate` bought at the Animal Market are still in town: waiting
## at the market's pickup spot (MarketCrates), else in the hands (the selected slot: E at
## the tailgate loads only that) on foot in town with the pickup there, its bed. The line
## under the goal says to load them into the pickup. null when neither. Crates carried
## off out of town go on by the goal's own dot first (to the coop door...), unless `every`:
## the goal wants all of them brought along, and the dot goes back for those still waiting.
func _waiting_crates(crate: StringName, every := false) -> Variant:
	var p := _player()
	var carried := LiveCrates.count_at(&"carried", crate)
	var in_town := _near("town")
	if LiveCrates.count_at(&"market", crate) > 0 and (in_town or carried == 0 or every):
		_hint = tr("HINT_MARKET_CRATES")
		var town := _town()
		var fallback: Variant = null
		if town and town.market_crates:
			fallback = town.market_crates.global_position + Vector3(0, 1.5, 0)
		return _anchor(MarketCrates.ANCHOR, fallback)
	var truck := _farm_truck()
	if in_town and LiveCrates.count_at(&"hand", crate) > 0 and p and p.driving == null and truck \
			and truck.global_position.distance_to(p.global_position) < CRATES_TO_TRUCK:
		_hint = tr("HINT_LOAD_CRATES")
		return _anchor(&"truck_bed", _truck_roof_point())
	return null


## A goal short of money: the line under it goes on (after "$28 more needed", set by
## _can_pay) with how to earn it, and the dot goes where that line says (earn_plan).
func _earn_target(from: Vector3) -> Variant:
	var plan := earn_plan(from, _goal_keep())
	_hint = String(plan["line"]) if _hint == "" else "%s\n%s" % [_hint, plan["line"]]
	return plan["at"]


## How the farmer can earn money right now, from what he has or can do: {"line": what the
## goal's card says, "at": where the dot goes for it}. Never a silent detour:
##   goods to sell (the bag's and the pickup's; `keep`: materials the goal itself asks for,
##   item -> count, are not offered): named ("Eggs, Wood"), sold at the market counter
##   when he is in town or at the wheel, else taken there in the pickup (the line says the
##   shipping bin pays too, next morning);
##   nothing in hand but goods waiting in the bin, in the evening: they are paid for in the
##   morning, so to bed;
##   nothing to sell: what there is to gather first: a ripe bed, an egg lying in the coop,
##   else wood from the trees (the line says eggs and fish sell too).
func earn_plan(from: Vector3, keep := {}) -> Dictionary:
	var goods := sellable_names(3, keep)
	var pl := _player()
	if not goods.is_empty():
		var names := UiTheme.join_list(PackedStringArray(goods))
		if _near("town") or (pl and pl.driving != null):
			return {"line": tr("HINT_SELL_GOODS") % names, "at": _target("market")}
		return {"line": tr("HINT_SELL_GOODS_HOME") % names, "at": _anchor(&"truck", _truck_roof_point())}
	var waiting := _bin_value()
	if waiting > 0 and GameClock.minute >= BIN_BED_HOUR * 60.0:
		var house := _house()
		return {"line": tr("HINT_BIN_WAIT") % UiTheme.money(waiting), "at": house.door_point() if house else null}
	var ripe: Variant = _plot_spot("ripe", from)
	if ripe != null:
		return {"line": tr("HINT_EARN_HARVEST"), "at": ripe}
	var egg: Variant = _nearest_pickup(&"egg", from, 400.0)
	if egg != null:
		return {"line": tr("HINT_EARN_EGGS"), "at": egg}
	var logs: Variant = _nearest_pickup(&"wood", from, 30.0)
	return {"line": tr("HINT_EARN_GATHER"), "at": logs if logs != null else _nearest_tree(from)}


## The two lines of a goal short of `amount` dollars and where its dot goes, for the side
## goals (the doghouse's kit, the dog's ball, the contest's bait, Zeynep's errands):
## {"hint": "$28 more needed" over how to earn it (earn_plan), "at": the place that line
## names}. `keep`: materials the goal itself asks for.
func money_short(amount: int, keep := {}) -> Dictionary:
	var p := _player()
	var plan := earn_plan(p.global_position if p else Vector3.ZERO, keep)
	return {"hint": "%s\n%s" % [tr("HINT_NEED_MONEY") % UiTheme.money(amount - Economy.money), plan["line"]], "at": plan["at"]}


## The materials the current goal itself asks for (item -> count): the earning line never
## offers them for sale (the kit's wood, the rod's).
func _goal_keep() -> Dictionary:
	if tutorial_done():
		return {}
	var project := board_project()
	if project != &"":
		return ProjectTable.get_project(project).get("items", {})
	var at := String(current().get("at", ""))
	if at.begins_with("craft:"):
		return RecipeTable.crafting(StringName(at.get_slice(":", 1))).get("items", {})
	if at == "buy:rope":
		return RecipeTable.crafting(&"fishing_rod").get("items", {})
	return {}


## The dot for a goal that makes project `id` at the construction board: short of its
## price, where to earn it (the line says how much and how); short of a material, where it
## comes from (the line says what is missing); else the board. `gift`: nothing to pay.
func _project_target(id: StringName, from: Vector3, gift := false) -> Variant:
	var p := ProjectTable.get_project(id)
	if not gift and not _can_pay(int(p.get("cost", 0))):
		return _earn_target(from)
	var items: Dictionary = p.get("items", {})
	for mat: StringName in items:
		if PlayerState.inventory.count_item(mat) < int(items[mat]):
			return _material_target(mat, int(items[mat]), from)
	return _ground(WorldLayout.BOARD_POS.x, WorldLayout.BOARD_POS.z, 1.9)


## Where the dot would point for `at` (see _target) and the line saying why, for the side
## goals that go by the story's places (the contest's rod at the workbench): {"at",
## "hint"}. The story's own line is left alone.
func place_for(at: String) -> Dictionary:
	var kept := _hint
	_hint = ""
	var point: Variant = _target(at)
	var why := _hint
	_hint = kept
	return {"at": point, "hint": why}


## What the shipping bin's goods will fetch in the morning (the courier's cut taken).
func _bin_value() -> int:
	var n := 0
	for st: ItemStack in FarmState.get_storage(ShippingBin.STORAGE_ID, ShippingBin.SLOTS).slots:
		if st != null:
			n += Economy.quote(st.item.id, st.count, st.quality, ShippingBin.COMMISSION_FACTOR)
	return n


## Crops (ItemTable category "crop") in the bag.
func _crop_units_in_bag() -> int:
	var n := 0
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.category == "crop":
			n += st.count
	return n


## Crops in the bed of one of the player's vehicles.
func _crop_units_in_cargo() -> int:
	var n := 0
	for v: Vehicle in get_tree().get_nodes_in_group(Vehicle.GROUP):
		if v.owned and v.cargo != null:
			for e: Dictionary in v.cargo.entries():
				var item := ItemDB.get_item(e["id"])
				if item and item.category == "crop":
					n += int(e["count"])
	return n


## Whether the bag holds a raw fish (ItemTable category "fish") to cook.
func _has_raw_fish() -> bool:
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.category == "fish":
			return true
	return false


## Whether `amount` dollars can be paid; if not, the hint says how much is short.
func _can_pay(amount: int) -> bool:
	if Economy.money >= amount:
		return true
	_hint = tr("HINT_NEED_MONEY") % UiTheme.money(amount - Economy.money)
	return false


## "Wood ×3": what is short of `need` × `id` in the bag.
func _short_of(id: StringName, need: int) -> String:
	return "%s ×%d" % [ItemDB.get_item(id).display_name(), need - PlayerState.inventory.count_item(id)]


## The dot for a goal that makes `id` at the workbench: the first material short (wood
## from the trees, stone from the rocks, wheat from the ripe beds, the market's goods
## from the market), else the bench (put down or bought first).
func _craft_target(id: StringName, from: Vector3) -> Variant:
	var items: Dictionary = RecipeTable.crafting(id).get("items", {})
	for mat: StringName in items:
		if PlayerState.inventory.count_item(mat) < int(items[mat]):
			return _material_target(mat, int(items[mat]), from)
	return _target("bench")


## Where the material `mat` a goal is short of comes from (`need`: how many it takes;
## the line under the goal says what is missing, "Short of Wood ×3"): wood from the trees,
## stone from the rocks, wheat from the ripe beds, the market's goods from the market
## (short of their price: where to earn it); null when it is nowhere to be had.
func _material_target(mat: StringName, need: int, from: Vector3) -> Variant:
	_hint = tr("HINT_NEED_ITEM") % _short_of(mat, need)
	match mat:
		&"wood":
			return _target("trees")
		&"stone":
			return _target("rocks")
		&"wheat":
			var ripe: Variant = _plot_spot("ripe", from)
			if ripe != null:
				return ripe
	if _sold_at_market(mat):
		var short := _hint
		var at: Variant = _buy_target(mat, need - PlayerState.inventory.count_item(mat))
		if _hint == tr("HINT_MARKET"):
			_hint = "%s · %s" % [short, _hint]
		return at
	return null


## The seed the second day's goal sends the player to buy: carrots or potatoes when the
## town market has them, else any seed on its shelves (out of season ones aren't, so the
## dot never asks for those); &"" when it sells none.
func _seed_to_buy() -> StringName:
	var stock: Array = ShopStock.town_market()["stock"]
	for id: StringName in [&"carrot_seed", &"potato_seed"]:
		if id in stock:
			return id
	for id: StringName in stock:
		if ItemDB.has_item(id) and ItemDB.get_item(id).category == "seed":
			return id
	return &""


## What the seeds still asked for cost at the market (0 off the seeds goal, or when the
## market has none).
func seeds_cost() -> int:
	if tutorial_done() or String(current()["id"]) != "seeds":
		return 0
	var seed_id := _seed_to_buy()
	if seed_id == &"":
		return 0
	return Economy.buy_price(seed_id) * maxi(int(current()["count"]) - step_count, 0)


## Short of money at the seeds goal: the dot goes to where the farmer's own goods sell
## (the market counter in town or at the wheel, else the pickup that takes them there),
## and the lines under the goal say how much is short and name what he has ("$6 more
## needed" over "Sell your Eggs, Wood: the market counter pays at once").
## With nothing to sell either, the grocer helps out at the counter (seed_gift_due).
func _seeds_short() -> Variant:
	var goods := sellable_names()
	_hint = "%s\n%s" % [tr("HINT_NEED_MONEY") % UiTheme.money(seeds_cost() - Economy.money),
			tr("HINT_SEEDS_GIFT") if goods.is_empty() else tr("HINT_SELL_GOODS") % UiTheme.join_list(PackedStringArray(goods))]
	var pl := _player()
	if _near("town") or (pl and pl.driving != null):
		return _target("market")
	return _anchor(&"truck", _truck_roof_point())


## Names of the goods the farmer has to sell (the bag, then the bed of his pickup), the
## best sellers first (SELLABLE's order), `most` at most. `keep` (item -> count): that
## many of each are spoken for (a goal's own materials) and only what is over them counts.
func sellable_names(most := 3, keep := {}) -> Array[String]:
	var have := {}
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.sell_price > 0 and st.item.category in SELLABLE:
			have[st.item.id] = int(have.get(st.item.id, 0)) + st.count
	for v: Vehicle in get_tree().get_nodes_in_group(Vehicle.GROUP):
		if v.owned and v.cargo != null:
			for e: Dictionary in v.cargo.entries():
				var item := ItemDB.get_item(e["id"])
				if item and item.sell_price > 0 and item.category in SELLABLE:
					have[item.id] = int(have.get(item.id, 0)) + int(e["count"])
	var ids: Array[StringName] = []
	for id: StringName in have:
		if int(have[id]) > int(keep.get(id, 0)):
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return SELLABLE.find(ItemDB.get_item(a).category) < SELLABLE.find(ItemDB.get_item(b).category))
	var names: Array[String] = []
	for id: StringName in ids.slice(0, most):
		names.append(ItemDB.get_item(id).display_name())
	return names


## The seeds goal can't be met any other way: it is up, the money doesn't reach, the
## farmer has nothing to sell, and the grocer hasn't helped yet (SEED_GIFT_FLAG).
func seed_gift_due() -> bool:
	if tutorial_done() or String(current()["id"]) != "seeds" or FarmState.flags.has(SEED_GIFT_FLAG):
		return false
	var cost := seeds_cost()
	return cost > 0 and Economy.money < cost and sellable_names(1).is_empty()


## At the town market's counter (its window open): the grocer hands over the seeds still
## asked for, once, when seed_gift_due ("The first seeds are on me, neighbour"). They
## count as the goal's.
func _offer_seed_gift() -> void:
	if not seed_gift_due() or Game.top_ui() != &"shop" or not _near("town"):
		return
	var hud := Game.hud as HUD
	if hud == null or hud.shop_screen == null or not hud.shop_screen.is_town_market():
		return
	give_seed_gift()


## The grocer's gift itself (see _offer_seed_gift; tests call it too).
func give_seed_gift() -> void:
	var seed_id := _seed_to_buy()
	var want := maxi(int(current()["count"]) - step_count, 1)
	FarmState.flags[SEED_GIFT_FLAG] = true
	PlayerState.give(seed_id, want, false)
	Game.notify(tr("MSG_SEED_GIFT") % [tr("PERSON_SHOPKEEPER"), want, ItemDB.get_item(seed_id).display_name()], UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	_count("purchased", "seed", want)


## The town market's counter for buying `count` × `id` (only for goods it sells: no dot
## to a shop without them). Short of money: where to earn it first.
func _buy_target(id: StringName, count: int) -> Variant:
	if not _sold_at_market(id):
		return null
	if not _can_pay(Economy.buy_price(id) * count):
		return _earn_target(_player().global_position if _player() else Vector3.ZERO)
	_hint = tr("HINT_MARKET")
	return _target("market")


## Whether the town market sells `id` (ShopStock.town_market).
func _sold_at_market(id: StringName) -> bool:
	return id in (ShopStock.town_market()["stock"] as Array)


## The pond's edge nearest the player (the pond by the house: WorldLayout.POND_CENTER).
func _pond_edge(from: Vector3) -> Vector3:
	var c := WorldLayout.POND_CENTER
	var d := Vector2(from.x, from.z) - c
	if d.length() < 0.1:
		d = Vector2(1, 0)
	var at := c + d.normalized() * (WorldLayout.POND_RADIUS - 0.5)
	return _ground(at.x, at.y, 0.8)


## A tagged place (WaypointMarker.anchor), else `fallback`.
func _anchor(id: StringName, fallback: Variant) -> Variant:
	var n := WaypointMarker.anchor(id)
	return n if n else fallback


func _ground(x: float, z: float, lift: float) -> Vector3:
	return Vector3(x, TerrainData.height(x, z) + lift, z)


func _farm() -> Farm:
	if Game.world == null or not is_instance_valid(Game.world):
		return null
	var f: Variant = Game.world.get("farm")
	return f as Farm if is_instance_valid(f) else null


func _house() -> FarmHouse:
	return get_tree().get_first_node_in_group(&"farm_house") as FarmHouse


func _town() -> Town:
	return get_tree().get_first_node_in_group(&"town") as Town


func _farm_truck() -> Vehicle:
	var town := _town()
	return town.farm_truck if town and is_instance_valid(town.farm_truck) else null


func _truck_roof_point() -> Variant:
	var truck := _farm_truck()
	if truck == null:
		return null
	return truck.global_position + Vector3(0, 1.7, 0)


## Over the warehouse's big door (WorldLayout.WAREHOUSE_RECT: the door is in its south
## wall, 4 m in from the west end).
func _warehouse_door() -> Vector3:
	var w := WorldLayout.WAREHOUSE_RECT
	return _ground(w.position.x + 4.0, w.end.y + 0.3, 2.2)


## The newest coop put up from a kit (its site while it goes up), or null.
func _newest_coop() -> ChickenCoop:
	var farm := _farm()
	if farm == null:
		return null
	var coops := farm.kit_coops()
	return coops.back() if not coops.is_empty() else null


## The newest workbench still going up, or null.
func _bench_going_up() -> Workbench:
	for n in get_tree().get_nodes_in_group(&"placed"):
		var b := n as Workbench
		if b and not b.is_built() and not b.is_queued_for_deletion():
			return b
	return null


## The newest coop still going up, or null.
func _coop_going_up() -> ChickenCoop:
	var coop := _newest_coop()
	return coop if coop and not coop.is_built() else null


func _coop_door() -> Variant:
	var coop := _newest_coop()
	if coop:
		return _anchor(ChickenCoop.ANCHOR_DOOR, coop.door_point() + Vector3(0, 1.4, 0))
	return _target("coop")


## The nearest bed in `state`: untilled, empty (tilled, unsown), dry (sown, not wet),
## waterable (tilled, the can takes it: FarmPlot's own rule), ripe. Grandpa's beds
## waiting for their goal are left out.
func _plot_spot(state: String, from: Vector3) -> Variant:
	var best: FarmPlot = null
	var best_d := INF
	for pl: FarmPlot in get_tree().get_nodes_in_group(&"farm_plots"):
		if pl.held_back():
			continue
		var fits := false
		match state:
			"untilled":
				fits = pl.soil == FarmPlot.Soil.UNTILLED
			"empty":
				fits = pl.soil == FarmPlot.Soil.TILLED and pl.crop == &""
			"dry":
				fits = pl.crop != &"" and not pl.withered and not pl.is_wet() and not pl.is_ready()
			"waterable":
				fits = pl.soil == FarmPlot.Soil.TILLED and not pl.withered and pl.wet_hours < CropTable.WET_HOURS - 1.0
			"ripe":
				fits = pl.is_ready()
		if not fits:
			continue
		var d := pl.global_position.distance_squared_to(from)
		if d < best_d:
			best = pl
			best_d = d
	if best == null:
		return null
	return best.global_position + Vector3(0, 0.6, 0)


## The nearest standing tree (within 90 m), or null.
func _nearest_tree(from: Vector3) -> Variant:
	var best: Node3D = null
	var best_d := 90.0 * 90.0
	for t: ChoppableTree in get_tree().get_nodes_in_group(&"trees"):
		var d := t.global_position.distance_squared_to(from)
		if not t.felled and d < best_d:
			best = t
			best_d = d
	if best == null:
		return null
	return best.global_position + Vector3(0, 1.6, 0)


## The nearest whole rock (within 120 m), else the quarry.
func _nearest_rock(from: Vector3) -> Variant:
	var best: Node3D = null
	var best_d := 120.0 * 120.0
	for r: BreakableRock in get_tree().get_nodes_in_group(&"rocks"):
		var d := r.global_position.distance_squared_to(from)
		if not r.broken and d < best_d:
			best = r
			best_d = d
	if best:
		return best.global_position + Vector3(0, 1.2, 0)
	var q := WorldLayout.QUARRY_RECT.get_center()
	return _ground(q.x, q.y, 1.5)


## Whether a watering can in the bag holds any water.
func _can_has_water() -> bool:
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.water_capacity > 0 and st.water > 0:
			return true
	return false


## The nearest uncut clump of tall grass (within 150 m), or null.
func _nearest_grass(from: Vector3) -> Variant:
	var best: GrassPatch = null
	var best_d := 150.0 * 150.0
	for g: GrassPatch in get_tree().get_nodes_in_group(&"grass_patches"):
		var d := g.global_position.distance_squared_to(from)
		if not g.cut and d < best_d:
			best = g
			best_d = d
	if best == null:
		return null
	return best.global_position + Vector3(0, 1.1, 0)


## The nearest `id` put down on the farm (a workbench, a machine), or null.
func _nearest_placed(id: StringName, from: Vector3) -> PlacedObject:
	var best: PlacedObject = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"placed"):
		var po := n as PlacedObject
		if po == null or po.item_id != id:
			continue
		var d := po.global_position.distance_squared_to(from)
		if d < best_d:
			best = po
			best_d = d
	return best


## The nearest `item` lying about to pick up (logs of a felled tree), within `radius`.
func _nearest_pickup(item: StringName, from: Vector3, radius: float) -> Variant:
	var best: Pickup = null
	var best_d := radius * radius
	for pk: Pickup in get_tree().get_nodes_in_group(&"pickups"):
		if pk.stack == null or pk.stack.item.id != item or pk.is_queued_for_deletion():
			continue
		var d := pk.global_position.distance_squared_to(from)
		if d < best_d:
			best = pk
			best_d = d
	return best


## A place on open farm land where the coop kit's plot fits, searched in rings around
## Grandpa's old run by the ground rules Placer checks without physics: no reserved
## ground, road or water, not too uneven, no tree, rock or other building in the plot.
## The player may put it anywhere else; this is only where the dot suggests.
func _find_coop_spot() -> Variant:
	var size: Vector3 = PlaceableTable.get_info(&"coop_kit").get("size", Vector3(11.0, 2.8, 10.0))
	var c := WorldLayout.COOP_PEN.get_center()
	for ring in 6:
		var n := 1 if ring == 0 else ring * 8
		for i in n:
			var a := TAU * float(i) / float(n)
			var at := c + Vector2(cos(a), sin(a)) * float(ring) * 5.0
			if _plot_clear(at, size):
				return _ground(at.x, at.y, 1.2)
	return null


## A place near the house where the workbench kit's plot fits: searched in rings from the
## front yard, a few steps out of the door toward the warehouse (east of the house the
## track and the fields leave no room), by the same ground rules as the coop's. Only a
## suggestion: it goes anywhere it fits.
func _find_bench_spot() -> Variant:
	var size: Vector3 = PlaceableTable.get_info(&"workbench").get("size", Vector3(2.4, 1.0, 1.6))
	var c := Vector2(WorldLayout.HOUSE_DOOR_X - 3.5, WorldLayout.HOUSE_FRONT_Z + 6.5)
	for ring in 8:
		var n := 1 if ring == 0 else ring * 6
		for i in n:
			var a := TAU * float(i) / float(n)
			var at := c + Vector2(cos(a), sin(a)) * float(ring) * 2.0
			if _plot_clear(at, size, 2.0):
				return _ground(at.x, at.y, 1.3)
	return null


## Open ground where a sapling can go (SaplingGrove.plant_reason), searched in rings on
## the meadow by the pond's north-east bank, a short walk from the yard. Only a
## suggestion: it goes anywhere the grove allows. null when none is found.
func _find_sapling_spot() -> Variant:
	var grove := SaplingGrove.instance
	if grove == null or not is_instance_valid(grove) or not grove.is_inside_tree():
		return null
	var c := WorldLayout.POND_CENTER + Vector2(10.0, -14.0)
	for ring in 7:
		var n := 1 if ring == 0 else ring * 6
		for i in n:
			var a := TAU * float(i) / float(n)
			var at := c + Vector2(cos(a), sin(a)) * float(ring) * 2.5
			var p := Vector3(at.x, TerrainData.height(at.x, at.y), at.y)
			if grove.plant_reason(p) == "":
				return p + Vector3(0, 1.0, 0)
	return null


## Whether a building plot of `size` fits with its middle at `at` (world XZ). The cheap
## tests go first: trees, rocks and other things put down, then the ground sampled every
## metre or so as Placer does.
func _plot_clear(at: Vector2, size: Vector3, keep_off := 6.0) -> bool:
	var half := Vector2(size.x, size.z) * 0.5 + Vector2(0.5, 0.5)
	var rect := Rect2(at - half, half * 2.0).grow(0.8)
	for group: StringName in [&"trees", &"rocks"]:
		for n in get_tree().get_nodes_in_group(group):
			var p := (n as Node3D).global_position
			if rect.has_point(Vector2(p.x, p.z)):
				return false
	for e: Dictionary in FarmState.placed:
		var pos: Vector3 = e["pos"]
		if rect.grow(keep_off).has_point(Vector2(pos.x, pos.z)):
			return false
	if TerrainData.normal_at(at.x, at.y).y < 0.95:
		return false
	var nx := ceili(half.x * 2.0)
	var nz := ceili(half.y * 2.0)
	var lo := INF
	var hi := -INF
	for ix in nx + 1:
		for iz in nz + 1:
			var x := at.x - half.x + half.x * 2.0 * float(ix) / float(nx)
			var z := at.y - half.y + half.y * 2.0 * float(iz) / float(nz)
			if Placer.reserved(x, z) or TerrainData.is_underwater(x, z, 0.3) \
					or WorldLayout.distance_to_pond(x, z) < WorldLayout.POND_RADIUS + 2.0 \
					or WorldLayout.playable_distance(x, z) < 1.0 or WorldLayout.distance_to_road(x, z) < 5.0:
				return false
			var h := TerrainData.height(x, z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo <= Placer.MAX_SPAN * 0.8


# --- Orders -------------------------------------------------------------------------------

## Keeps the board full: drops expired orders, adds new ones for the current level.
func refill_board() -> void:
	var before := orders.size()
	orders = orders.filter(func(o: Dictionary) -> bool: return int(o["due"]) >= GameClock.day)
	var expired := before - orders.size()
	if expired > 0:
		Game.notify(tr("MSG_ORDERS_EXPIRED") % expired, UiTheme.TEXT_MUTED)
	while orders.size() < UnlockTable.order_slots(Progress.level, BOARD_SIZE):
		orders.append(_new_order())
	orders_changed.emit()


func _new_order() -> Dictionary:
	var level := Progress.level
	var pool := ORDER_GOODS.filter(func(g: Array) -> bool:
		return int(g[0]) <= level and orders.all(func(o: Dictionary) -> bool: return StringName(o["item"]) != g[1]))
	if pool.is_empty():
		pool = ORDER_GOODS.filter(func(g: Array) -> bool: return int(g[0]) <= level)
	# Newer goods come up more often as the farm grows.
	var weights := pool.map(func(g: Array) -> float: return 1.0 + float(g[0]) * 0.6)
	var total := 0.0
	for w: float in weights:
		total += w
	var r := randf() * total
	var pick: Array = pool[0]
	for i in pool.size():
		r -= float(weights[i])
		if r <= 0.0:
			pick = pool[i]
			break
	var scale := 1.0 + (level - int(pick[0])) * 0.25
	var count := clampi(roundi(randf_range(int(pick[2]), int(pick[3])) * scale), int(pick[2]), int(pick[3]) * 2)
	return _order(StringName(pick[1]), count, GameClock.day + randi_range(3, 6), randi() % 12)


## An order for `count` × `item` from `client` (OrderScreen.CLIENTS), due on day `due`,
## paying the market price with the PREMIUM.
func _order(item: StringName, count: int, due: int, client: int) -> Dictionary:
	var base := ItemDB.get_item(item).sell_price
	var reward := roundi(base * count * PREMIUM * UnlockTable.order_bonus(Progress.level) / 5.0) * 5
	var o := {"id": _next_order_id, "item": String(item), "count": count, "reward": maxi(reward, MIN_REWARD),
		"due": due, "client": client}
	_next_order_id += 1
	return o


## Pins the bakery's wood order (FIRST_ORDER) on a new farm's board.
func _post_first_order() -> void:
	orders.append(_order(StringName(FIRST_ORDER["item"]), int(FIRST_ORDER["count"]),
		GameClock.day + int(FIRST_ORDER["days"]), int(FIRST_ORDER["client"])))


## Units of `item` the player can hand over: the bag and the bed of a pickup nearby.
func available(item: StringName) -> int:
	var n := PlayerState.inventory.count_item(item)
	var v := _pickup_nearby()
	if v:
		n += v.cargo.count(item)
	return n


func _pickup_nearby() -> Vehicle:
	var board := get_tree().get_first_node_in_group(&"order_board") as Node3D
	if board == null:
		return null
	var best: Vehicle = null
	var best_d := 30.0
	for v: Vehicle in get_tree().get_nodes_in_group(&"vehicles"):
		var d := v.global_position.distance_to(board.global_position)
		if v.owned and d < best_d:
			best = v
			best_d = d
	return best


func can_deliver(o: Dictionary) -> bool:
	return available(StringName(o["item"])) >= int(o["count"])


## Hands the goods over (bag first, then the bed) and gets paid.
func deliver(o: Dictionary) -> bool:
	if o not in orders or not can_deliver(o):
		return false
	var item := StringName(o["item"])
	var need := int(o["count"])
	var from_bag := mini(need, PlayerState.inventory.count_item(item))
	PlayerState.inventory.remove_item(item, from_bag)
	need -= from_bag
	var v := _pickup_nearby()
	if need > 0 and v:
		for e: Dictionary in v.cargo.entries():
			if e["id"] == item and need > 0:
				need -= v.cargo.take(item, mini(need, int(e["count"])), int(e["quality"]))
	orders.erase(o)
	# A carnival night pays double for an order delivered in town too.
	var reward := roundi(int(o["reward"]) * Economy.carnival_factor())
	Economy.add_money(reward, "REPORT_ORDERS")
	Events.order_delivered.emit(item, int(o["count"]), reward)
	Game.notify(tr("MSG_ORDER_DONE") % [ItemDB.get_item(item).display_name(), UiTheme.money(reward)], UiTheme.GOLD)
	orders_changed.emit()
	return true


## A night went by: the board is refilled, and a goal waiting for the morning looks now.
func _on_day_started(day: int) -> void:
	if day == 2:
		_grow_first_sowing()
	refill_board()
	_nudge()


## The first night on a new farm (see FIRST_NIGHT_GROWTH): every crop sown on the first
## day and watered (its soil still wet in the morning) has at least a whole day's growth.
func _grow_first_sowing() -> void:
	if not FarmHouse.first_day():
		return
	for pl: FarmPlot in get_tree().get_nodes_in_group(&"farm_plots"):
		if pl.harvests == 0 and pl.is_wet():
			pl.grow_to(FIRST_NIGHT_GROWTH * pl.growth_rate())


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	step = 0
	step_count = 0
	tally = {}
	orders = []
	_next_order_id = 1
	_reset_cache()
	chores.load_data({})
	_post_first_order()
	refill_board()
	tutorial_changed.emit()


func _reset_cache() -> void:
	_waypoint = null
	_new_building = null
	_new_building_text = ""
	_wp_left = 0.0
	_poll = 0.0
	_coop_spot = null
	_coop_spot_searched = false
	_bench_spot = null
	_bench_spot_searched = false
	_sapling_spot = null
	_sapling_spot_searched = false
	_hint = ""
	_needs = ""


## The goal is kept by its id (and the index, for reference), so goals can be added;
## "chain" tells this chain from older ones.
func save_data() -> Dictionary:
	return {"chain": CHAIN, "step": step, "id": String(current().get("id", "")), "count": step_count,
		"tally": tally.duplicate(), "orders": orders.duplicate(true), "next": _next_order_id,
		"chores": chores.save_data()}


func load_data(d: Dictionary) -> void:
	tally = (d.get("tally", {}) as Dictionary).duplicate()
	step_count = int(d.get("count", 0))
	_reset_cache()
	# Saves from before the first day's story: that day counts as done, they go on in
	# the chapters after it. Saves of an older chain go on at the nearest goal still here.
	var chain := int(d.get("chain", 1))
	var old := chain < 2
	var id := String(d["id"]) if d.has("id") else _legacy_id(int(d.get("step", 0)))
	if old and MOVED_V2.has(id):
		id = String(MOVED_V2[id])
		step_count = 0
	if chain < 3 and MOVED_V3.has(id):
		id = String(MOVED_V3[id])
		step_count = 0
	if chain < 4 and MOVED_V4.has(id):
		id = String(MOVED_V4[id])
		step_count = 0
	if chain < 5 and MOVED_V5.has(id):
		id = String(MOVED_V5[id])
		step_count = 0
	if chain < 6 and MOVED_V6.has(id):
		id = String(MOVED_V6[id])
		step_count = 0
	if chain < 7:
		if MOVED_V7.has(id):
			id = String(MOVED_V7[id])
			step_count = 0
		_tally_meals()
	if chain < 8:
		# Chain 7's market came before the mending (MOVED_V8_MARKET); older chains mended
		# on the first day and keep their market.
		if chain == 7 and id in V8_SOLD_FIRST:
			for done: String in V8_MARKET:
				tally[DONE_MARK % done] = 1
		if chain == 7 and MOVED_V8_MARKET.has(id):
			id = String(MOVED_V8_MARKET[id])
			step_count = 0
		elif MOVED_V8.has(id):
			id = String(MOVED_V8[id])
			step_count = 0
	step = TUTORIAL.size() if id == "" else index_of(id)
	if step < 0:
		# A goal this version no longer has: go on from about where it stood.
		step = clampi(int(d.get("step", 0)), 0, TUTORIAL.size())
		step_count = 0
	if old:
		if step < day_two_step():
			step = day_two_step()
			step_count = 0
		if SaveGame.loading:
			_mark_old_farm()
	if not tutorial_done():
		step_count = clampi(step_count, 0, int(current()["count"]))
	orders = (d.get("orders", []) as Array).duplicate(true)
	_next_order_id = int(d.get("next", 1))
	chores.load_data(d.get("chores", {}))
	if orders.is_empty():
		refill_board()
	tutorial_changed.emit()
	orders_changed.emit()


## Saves before chain 7 counted only what was eaten: the cooked meals among it count as
## meals (the fourth day's "eat" goal), so a fish eaten then isn't asked for again.
func _tally_meals() -> void:
	if tally.has("meal:"):
		return
	var meals := 0
	for key: String in tally.keys():
		if key.begins_with("eaten:") and key.length() > 6 and _is_meal(StringName(key.substr(6))):
			meals += int(tally[key])
	if meals > 0:
		tally["meal:"] = meals


## A save from before the first day's story is being loaded: its farm had the house open,
## Grandpa's things long in the bag and the pickup's key in the ignition. (The save
## migration marks it too; this keeps an old farm playable either way.)
func _mark_old_farm() -> void:
	FarmState.flags[FarmHouse.LEGACY_FLAG] = true
	FarmState.flags[Vehicle.UNLOCK_FLAG % "pickup_old"] = true
	FarmState.flags[BEDS_FLAG] = true


## Saves from before the day-one chapters kept only an index into LEGACY_TUTORIAL. The goal
## is found again by its id (LEGACY_MOVED for goals that moved or went; returned as the
## id of the chain after it, "" when the story was done), and the work the old goals
## asked for goes into the tally, so the "ever" goals don't ask for it again.
func _legacy_id(old: int) -> String:
	var count := step_count
	step_count = 0
	if old >= LEGACY_TUTORIAL.size():
		return ""
	old = maxi(old, 0)
	for i in old + 1:
		var lg: Dictionary = LEGACY_TUTORIAL[i]
		var done := int(lg["count"]) if i < old else count
		if String(lg["kind"]) != "check" and done > 0:
			_tally(String(lg["kind"]), String(lg["arg"]), done)
	var id := String(LEGACY_TUTORIAL[old]["id"])
	var to := String(LEGACY_MOVED.get(id, id))
	if to == id:
		step_count = count
	return to
