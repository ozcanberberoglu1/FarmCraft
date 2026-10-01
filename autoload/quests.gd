extends Node
## The story's goals and the orders on the town board.
## Grandpa Osman has left the player his run-down farm in Yeşilova. The first day is
## walked through by hand: the stuck front door, his tools on the worktable inside, three
## beds of wheat, the pickup's key in the desk drawer, two hens from the poultry stall in
## town, a coop put up from a kit, the ripe beds he left behind, the shipping bin, the
## first egg, then the coop looked after (feed from the warehouse, water from the well,
## straw in the nests) and the house's broken boards renewed by hand with a tree's wood.
## After that the player is free; the next morning brings the workshop (a little money
## earned by selling, a workbench kit bought at the construction board and put up near
## the house like the coop, a knife made at it) and a first go at fishing (rope from the
## market for a rod, bait, a fish from the pond by the house, a campfire to cook it on, a
## meal), on the third morning a rooster for the hens (from the animal market in town, let
## out at the coop like them: eggs left in the nests under him hatch into chicks), and
## later only a few milestones of a growing farm (the barn, the dairy, the house), each
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

const CHAPTERS: Array[String] = ["arrival", "soil", "town", "coop", "harvest", "coop_care",
	"repair", "free", "workshop", "fishing", "rooster", "barn", "dairy", "legacy"]
## The first chapter after the first day's story (the player is free until morning):
## saves from before the first day's story go on from here.
const DAY_TWO_CHAPTER := 7
## Format of the chain in saves (2: the hand-held first day; 3: the day ending with the
## coop's care and the house mended by hand; 4: the second day's workshop and fishing;
## 5: the second morning's harvest sold at the market instead of earning in the bin).
## Saves without it are older and skip the first day (MOVED_V2); chain 2 saves go on at
## the nearest goal still here (MOVED_V3), chain 3 saves on the stonework at the
## workshop (MOVED_V4), chain 4 saves on the earning goal at the second harvest (MOVED_V5);
## 6: the third morning's rooster after the fishing (chain 5 saves just past the fishing
## go back for it: MOVED_V6).
const CHAIN := 6
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
## "animals:<species>", "has:<item>" (in the bag or put down on the farm), "bench:kit" /
## "bench:started" / "bench:built" (a workbench bought, put down, finished), "bait"
## (worms or dough in the bag), "caught" (a fish caught since the story began); the
## counting ones report progress).
## Kinds of the second day: "earned" (dollars from sales and orders), "caught" (fish
## caught: Events.fish_caught), "cooked" (food cooked on a campfire), "eaten" (food
## eaten).
## "ever": the goal also counts what was done before it came up (see `tally`), so work
## done early is never asked for twice and the chain can't stall on it.
## "past": a check that shows the player is beyond this goal already (done out of order,
## a debug shot, a load): it completes the goal when it reads above 0.
## "at": where the dot points while the goal is up (see _target). When it points
## somewhere else first (the trees for wood, the shipping bin for money, the market for
## rope), the goal's text says why (goal_hint): the dot never sends the player off to
## buy something without saying what, nor to a shop that doesn't sell it.
const TUTORIAL := [
	# Day one. Homecoming: the stuck front door, and Grandpa's things on the worktable inside.
	{"chapter": 0, "id": "door", "kind": "check", "arg": "flag:house_door_open", "count": 1, "at": "house_door", "past": "took"},
	# The count is FarmHouse.table_item_count() (ItemTable.STARTING_ITEMS); "table" copes
	# with a different number all the same.
	{"chapter": 0, "id": "tools", "kind": "check", "arg": "table", "count": 7, "at": "table"},
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
	# The coop: wood, a kit from the construction board, a spot, a minute's work, the hens in.
	{"chapter": 3, "id": "coop_wood", "kind": "picked", "arg": "wood", "count": 15, "xp": 5, "ever": true, "at": "trees", "past": "kit"},
	{"chapter": 3, "id": "coop_kit", "kind": "check", "arg": "kit", "count": 1, "at": "board"},
	{"chapter": 3, "id": "coop_place", "kind": "check", "arg": "coop:started", "count": 1, "xp": 4, "at": "coop_spot"},
	{"chapter": 3, "id": "coop_built", "kind": "check", "arg": "coop:built", "count": 1, "xp": 8, "at": "coop"},
	{"chapter": 3, "id": "hens_in", "kind": "check", "arg": "animals:chicken", "count": 2, "xp": 6, "at": "hens"},
	# The first harvest: the ripe beds Grandpa left, the shipping bin, the first egg.
	{"chapter": 4, "id": "harvest", "kind": "action", "arg": "harvest", "count": 3, "xp": 5, "ever": true, "at": "plot:ripe", "past": "bin:crop"},
	{"chapter": 4, "id": "ship", "kind": "check", "arg": "bin:crop", "count": 1, "xp": 3, "at": "bin"},
	{"chapter": 4, "id": "egg", "kind": "picked", "arg": "egg", "count": 1, "ever": true, "at": "egg", "past": "bin:egg"},
	{"chapter": 4, "id": "ship_egg", "kind": "check", "arg": "bin:egg", "count": 1, "xp": 3, "at": "bin"},
	# The coop's care: the feed sack that waits in the warehouse into the feeder, the
	# watering can from the well into the water trough, straw from the meadow in the nests
	# (the hens lay there from then on).
	{"chapter": 5, "id": "feed", "kind": "fed", "arg": "", "count": 1, "xp": 3, "ever": true, "at": "feeder"},
	{"chapter": 5, "id": "coop_water", "kind": "watered", "arg": "", "count": 1, "xp": 3, "ever": true, "at": "coop_water"},
	{"chapter": 5, "id": "straw", "kind": "nests", "arg": "", "count": 3, "xp": 4, "ever": true, "at": "nests"},
	# Mending: one tree's wood (counted from when the goal comes up), then the house's
	# broken boards renewed by hand, a piece of wood each. (A house repaired already
	# passes both.)
	{"chapter": 6, "id": "wood", "kind": "picked", "arg": "wood", "count": 3, "xp": 2, "at": "trees", "past": "built:house_1"},
	{"chapter": 6, "id": "patch", "kind": "patched", "arg": "house", "count": 3, "xp": 8, "ever": true, "at": "house_repair", "past": "built:house_1"},
	# The first day's story is done: the farm is the player's own until the next morning
	# (no dot, no task; Grandpa's note says so).
	{"chapter": 7, "id": "free", "kind": "check", "arg": "day:2", "count": 1},
	# Day two, the workshop: some money of the farm's own first (the kit is bought, like
	# everything), the workbench kit from the construction board, put up near the house
	# with a minute's work like the coop, then the first tool made at it: a knife.
	# The second morning: yesterday's wheat reaped, loaded into the pickup's bed and sold at
	# the Yeşilova market, then the workbench from what it fetched.
	{"chapter": 8, "id": "harvest2", "kind": "check", "arg": "crops", "count": 3, "xp": 4, "at": "plot:ripe", "past": "bench:kit"},
	{"chapter": 8, "id": "load_crops", "kind": "check", "arg": "cargo:crop", "count": 3, "xp": 3, "at": "truck_load", "past": "bench:kit"},
	{"chapter": 8, "id": "sell_market", "kind": "sold", "arg": "", "count": 3, "xp": 4, "at": "sell_market", "past": "bench:kit"},
	{"chapter": 8, "id": "bench_kit", "kind": "check", "arg": "bench:kit", "count": 1, "xp": 4, "at": "bench_board"},
	{"chapter": 8, "id": "bench_place", "kind": "check", "arg": "bench:started", "count": 1, "xp": 4, "at": "bench_spot"},
	{"chapter": 8, "id": "bench_built", "kind": "check", "arg": "bench:built", "count": 1, "xp": 6, "at": "bench"},
	{"chapter": 8, "id": "knife", "kind": "crafted", "arg": "knife", "count": 1, "xp": 6, "ever": true, "at": "craft:knife"},
	# Fishing, shown once: rope from the town market for a rod (RecipeTable: 2), the rod
	# made at the bench, bait, a fish from the pond by the house, a campfire made and put
	# down to cook it on, and the meal.
	# The rope and the bait on the same trip to the market, then the rod at the bench.
	{"chapter": 9, "id": "rope", "kind": "check", "arg": "has:rope", "count": 2, "xp": 3, "at": "buy:rope", "past": "rods"},
	{"chapter": 9, "id": "bait", "kind": "check", "arg": "bait", "count": 1, "xp": 3, "at": "bait", "past": "caught"},
	# Any rod will do (the cane rod, the standard one or a better one).
	{"chapter": 9, "id": "rod", "kind": "check", "arg": "rods", "count": 1, "xp": 6, "at": "craft:fishing_rod", "past": "rods"},
	{"chapter": 9, "id": "fish", "kind": "caught", "arg": "", "count": 1, "xp": 8, "ever": true, "at": "pond"},
	{"chapter": 9, "id": "campfire", "kind": "crafted", "arg": "campfire", "count": 1, "xp": 4, "ever": true, "at": "craft:campfire", "past": "has:campfire"},
	{"chapter": 9, "id": "cook", "kind": "cooked", "arg": "", "count": 1, "xp": 6, "ever": true, "at": "campfire"},
	{"chapter": 9, "id": "eat", "kind": "eaten", "arg": "", "count": 1, "xp": 4, "ever": true},
	# The rest of the second day (and the next, if the fishing went quickly) is the
	# player's own; the third morning brings the rooster.
	{"chapter": 9, "id": "rooster_wait", "kind": "check", "arg": "day:3", "count": 1},
	# Day three, a rooster for the hens: bought at the animal market in town (in his crate,
	# like the hens) and let out at the coop door; the eggs left in the nests under him
	# hatch into chicks a day later (the chapter's note and the release say so).
	{"chapter": 10, "id": "rooster_buy", "kind": "check", "arg": "owned:rooster", "count": 1, "xp": 4, "at": "rooster_market", "past": "animals:rooster"},
	{"chapter": 10, "id": "rooster_in", "kind": "check", "arg": "animals:rooster", "count": 1, "xp": 8, "at": "hens"},
	# From here the farm is the player's to run: a few milestones as it grows (sheep, a
	# cow and a bigger house).
	{"chapter": 11, "id": "level_3", "kind": "check", "arg": "level", "count": 3},
	{"chapter": 11, "id": "barn", "kind": "check", "arg": "built:barn_1", "count": 1, "xp": 10},
	{"chapter": 11, "id": "sheep", "kind": "check", "arg": "animals:sheep", "count": 1, "xp": 10},
	{"chapter": 11, "id": "shear", "kind": "action", "arg": "shear", "count": 1, "xp": 10},
	{"chapter": 12, "id": "level_4", "kind": "check", "arg": "level", "count": 4},
	{"chapter": 12, "id": "cow", "kind": "check", "arg": "animals:cow", "count": 1, "xp": 10},
	{"chapter": 12, "id": "milk", "kind": "action", "arg": "milk", "count": 1, "xp": 10},
	{"chapter": 12, "id": "cheese", "kind": "product", "arg": "cheese", "count": 1, "xp": 10},
	{"chapter": 13, "id": "level_5", "kind": "check", "arg": "level", "count": 5},
	{"chapter": 13, "id": "house", "kind": "check", "arg": "built:house_2", "count": 1, "xp": 10},
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
## The first day keeps time for the story: the clock runs at FIRST_DAY_PACE and from
## LINGER_HOUR the late afternoon lingers (LINGER_PACE: the first egg still comes, and
## there is light to mend the house by); once the day's story is done the clock runs as
## usual. Multiplies GameClock.time_scale; the day length setting still applies.
## The day starts at noon (GameClock.FIRST_DAY_START_MINUTE): at the default 15-minute
## day (Settings: 80 game minutes a real minute) noon to 16:30 takes 13.5 real minutes
## and the linger to sundown (about 19:15) 10 more, to nightfall (20:00) 13: about the
## 24 and 26 minutes the story had when the day started at 06:00 (at 0.5 and 0.25).
const FIRST_DAY_PACE := 0.25
const LINGER_HOUR := 16.5
const LINGER_PACE := 0.2
## Grandpa's beds: the far end of the first field is ripe on a new farm, so the first
## harvest can be made on day one (the player's own wheat needs 20 wet hours and ripens
## overnight, see FIRST_NIGHT_GROWTH). Carrots, or wheat out of the carrot seasons. Set
## once (BEDS_FLAG in FarmState.flags, saved with the farm).
const GRANDPA_BEDS := 3
const GRANDPA_CROP := &"carrot"
const BEDS_FLAG := "grandpa_beds"
## The first day starts at noon, so wheat sown that afternoon or evening would not have
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
## Why the dot points where it does when that isn't the goal's own place (a translated
## line under the goal, "" for none): set with the dot (_target), read by goal_hint().
var _hint := ""
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


func _ready() -> void:
	Events.action_done.connect(_on_action_done)
	Events.item_sold.connect(func(_id: StringName, n: int, g: int) -> void:
		_count("sold", "", n)
		_count("earned", "", g))
	Events.placed.connect(func(id: StringName) -> void: _count("placed", String(id), 1))
	Events.crafted.connect(_on_crafted)
	Events.product_made.connect(func(id: StringName, n: int) -> void: _count("product", String(id), n))
	Events.item_picked_up.connect(func(id: StringName, n: int) -> void: _count("picked", String(id), n))
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
	Events.food_eaten.connect(func(id: StringName) -> void: _count("eaten", String(id), 1))
	Events.campfire_lit.connect(func(_fire: Node) -> void: _nudge())
	Events.placed.connect(func(_id: StringName) -> void: _nudge())
	# A building just finished: the dot shows where it went up.
	FarmState.project_built.connect(_on_project_built)
	Events.building_completed.connect(_on_building_completed)
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
	# Why the dot is somewhere else first (the current goal only).
	if goal.is_empty() and _hint != "":
		text += "\n%s" % _hint
	return text


## The line under the current goal saying why the dot points where it does ("" when it
## points at the goal's own place).
func goal_hint() -> String:
	return _hint


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


## Made at a workbench ("crafted"), or a building kit cut at the construction board
## ("kit": the coop kit of day one is not the workshop's first piece of work).
func _on_crafted(id: StringName, n: int) -> void:
	if PlaceableTable.is_building(id):
		_count("kit", String(id), n)
	else:
		_count("crafted", String(id), n)


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
	var xp := int(g.get("xp", 0))
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
		return
	_wp_left -= delta
	if _wp_left <= 0.0:
		_wp_left = WAYPOINT_REFRESH
		var hint := _hint
		_hint = ""
		_waypoint = _target(String(current().get("at", "")))
		if _hint != hint:
			tutorial_changed.emit()
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 1.0
	_first_day_setup()
	var g := current()
	var past := String(g.get("past", ""))
	if past != "" and _check_progress(past) > 0:
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
	return 0


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


## The first day's clock (see FIRST_DAY_PACE): set while a new farm's first day runs,
## given back after (the first night, a skip, a load).
func _pace() -> void:
	if _paces_day():
		# Hours past midnight count on (25.0 is 01:00): the day ends at the first sleep.
		var want := pace_for(GameClock.minute / 60.0)
		if GameClock.time_scale != want:
			GameClock.time_scale = want
		_paced = true
	elif _paced:
		GameClock.time_scale = 1.0
		_paced = false


func _paces_day() -> bool:
	return first_day() and GameClock.day == 1 and not SaveGame.loading \
			and not DebugTools.is_automated() and FarmHouse.first_day()


## The first day's time scale at `hour` (from 12.0, past 24 after midnight) while its
## story runs (tests check it).
func pace_for(hour: float) -> float:
	return FIRST_DAY_PACE if hour < LINGER_HOUR else LINGER_PACE


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
			var logs: Variant = _nearest_pickup(&"wood", from, 30.0)
			return logs if logs != null else _nearest_tree(from)
		"rocks":
			var chips: Variant = _nearest_pickup(&"stone", from, 30.0)
			return chips if chips != null else _nearest_rock(from)
		"board":
			# The kit takes wood from the bag: short of it, the trees first.
			var need := int((ProjectTable.get_project(&"coop_kit").get("items", {}) as Dictionary).get(&"wood", 0))
			if PlayerState.inventory.count_item(&"wood") < need and not FarmState.coop_started() \
					and PlayerState.inventory.count_item(&"coop_kit") == 0:
				return _target("trees")
			return _ground(WorldLayout.BOARD_POS.x, WorldLayout.BOARD_POS.z, 1.9)
		"coop_spot":
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
			# The feed sack waits in the warehouse: fetch it first.
			if PlayerState.inventory.count_item(&"feed") == 0:
				return _anchor(&"warehouse", _warehouse_door())
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
		"earn":
			return _earn_target(from)
		"sell_market":
			# To town at the wheel of the loaded pickup, then the market counter.
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
			var p_kit := ProjectTable.get_project(&"workbench")
			if not _can_pay(int(p_kit.get("cost", 0))):
				return _earn_target(from)
			var wood_need := int((p_kit.get("items", {}) as Dictionary).get(&"wood", 0))
			if PlayerState.inventory.count_item(&"wood") < wood_need:
				_hint = tr("HINT_NEED_ITEM") % _short_of(&"wood", wood_need)
				return _target("trees")
			return _ground(WorldLayout.BOARD_POS.x, WorldLayout.BOARD_POS.z, 1.9)
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


## Where money comes from for the goals that buy something: goods to sell in the bag go
## to the shipping bin (the market when in town, which pays at once), else the ripe beds,
## eggs lying about, the hens' coop.
func _earn_target(from: Vector3) -> Variant:
	# A goal short of money says how much; the earning goal itself says how.
	var own := _hint == ""
	if _has_goods_to_sell() or _crop_units_in_cargo() > 0:
		if _near("town"):
			if own:
				_hint = tr("HINT_SELL_MARKET")
			return _target("market")
		# Into the pickup and off to the market (the bin only pays the next morning).
		if own:
			_hint = tr("HINT_SELL_TOWN")
		var pl := _player()
		if pl and pl.driving != null:
			return _target("market")
		return _anchor(&"truck", _truck_roof_point())
	if own:
		_hint = tr("HINT_EARN")
	var ripe: Variant = _plot_spot("ripe", from)
	if ripe != null:
		return ripe
	var egg: Variant = _nearest_pickup(&"egg", from, 60.0)
	if egg != null:
		return egg
	# Goods waiting in the bin are paid for in the morning: bed, once it is evening.
	if _bin_value() > 0 and GameClock.minute >= 18 * 60:
		if own:
			_hint = tr("HINT_BIN_MORNING")
		var house := _house()
		return house.door_point() if house else null
	var coop := _newest_coop()
	return _target("coop") if coop else _target("bin")


## What the shipping bin's goods will fetch in the morning (the courier's cut taken).
func _bin_value() -> int:
	var n := 0
	for st: ItemStack in FarmState.get_storage(ShippingBin.STORAGE_ID, ShippingBin.SLOTS).slots:
		if st != null:
			n += Economy.quote(st.item.id, st.count, st.quality, ShippingBin.COMMISSION_FACTOR)
	return n


## Goods in the bag that sell for something and aren't wanted for the story's making:
## crops, eggs, milk, wool, artisan goods, fish.
func _has_goods_to_sell() -> bool:
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.sell_price > 0 and st.item.category in ["crop", "animal_product", "artisan", "fish", "food"]:
			return true
	return false


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
		var need := int(items[mat])
		if PlayerState.inventory.count_item(mat) >= need:
			continue
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
	return _target("bench")


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
	_hint = ""


## The goal is kept by its id (and the index, for reference), so goals can be added;
## "chain" tells this chain from older ones.
func save_data() -> Dictionary:
	return {"chain": CHAIN, "step": step, "id": String(current().get("id", "")), "count": step_count,
		"tally": tally.duplicate(), "orders": orders.duplicate(true), "next": _next_order_id}


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
	if orders.is_empty():
		refill_board()
	tutorial_changed.emit()
	orders_changed.emit()


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
