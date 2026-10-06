class_name FishGoal
extends Node
## "Fishing pays": the quiet side goal that shows a farmer short of the barn's price that
## the pond pays (SideStory owns it, SideStory.fish_goal, and saves it). On a compact card
## with a small, faint dot (SideGoal.quiet), never in the story's way:
##
##   It comes up, once in a save, when the story's goal is to build the open barn, the
##   barn doesn't stand, his money doesn't reach its price (the materials don't matter)
##   and he has a rod in the bag. Once up it stays (money coming or going changes nothing)
##   until it is done; should the barn be built first, it goes without a word.
##   The card: "Catch 5 fish (n/5)" over a line that says why (fish, big ones above all,
##   sell well at the market: SideGoal.needs, always in view). The dot shows the nearest
##   pond's bank (Grandpa's pond at home); out of bait or without a rod, where the story
##   itself would send him for them (Quests.place_for), the hint saying why (out of
##   bait: "You need bait in your bag" first, the dot's pill reading "Bait").
##   It never comes up behind an open window (the level-up's, a shop's): its toast is
##   the only place its name is said, so it waits for the window to shut.
##   Every fish landed while it is up counts (the old boot doesn't, nor does a bite that
##   got away), and BIG of the FISH are giants for sure (FishTable.trophy_of of whatever
##   bites): which ones is drawn when the goal comes up (`slots`) and saved, so a load
##   neither draws again nor loses one. Angler asks before each bite (shape) and tells of
##   each landing (note_landed); everything else about a giant is as ever (the harder
##   bite, the spray, the fanfare, the dry run starting over). A giant that comes by
##   itself on another catch is plain luck: the promised ones still come.
##   A promised giant is one worth showing: the giant of a common fish fetches $20 to $40
##   (a "giant" gudgeon of 230 g for $20 shows nobody that the pond pays), so when the
##   giant of what bites would fetch less than WORTH the water is asked again (the same
##   roll: the same bait, hour, weather and rod, so nothing bites that couldn't bite
##   there) until one bites that fetches as much; see shape. The three then fetch 3 x
##   WORTH = $180 of the barn's $200 at the least, at list prices. By the same asking it
##   is big on the scale too (KG: no giant crayfish of half a kilo), it is none of the
##   pond's two legends (TOP: those stay luck, as a giant that bites by itself is) and
##   not the third giant of one species (KIND), where the water gives another.
##   At the fishing contest (on, and he at its pond) nothing is made a giant and nothing
##   counts: the contest stays a contest (the card's line says so there, in the place
##   of the line of why, so it is always in view).
##   The fifth fish landed: a little farm experience (XP) and a closing line with what
##   his catch fetches at the market (fish_worth: the fish in the bag and those still
##   lying on the bank), to be sold in Yeşilova (held back while a window is open, the
##   level-up's above all). It pays no money itself: money comes from sales alone, and
##   the story's own line under the barn goal then names the fish to sell, before his
##   eggs and crops, until the barn stands (catch_first, Quests.sellable_names).
##
## Automated runs keep it away unless the run asks for it (`--fish-goal`, or `testing`).

## How many fish it asks for, and how many of them are giants for sure.
const FISH := 5
const BIG := 3
## A promised giant fetches this much or more at the market's list price: every giant of
## the pond's uncommon fish and rarer does ($60 a crayfish or a bream .. $950 a sturgeon;
## data/item_table.gd), none of the common ones (bleak and gudgeon $20, rudd, crucian and
## roach $30, perch $40).
const WORTH := 60
## And this much at the most: up to the pike's $300. The pond's two legends (the catfish
## $550, the sturgeon $950: three to five barns in one fish) are no promise: asking again
## for the fish worth showing brought one in every tenth go on worms at night. They stay
## what they are, luck: one that bites as a giant by itself is kept.
const TOP := 300
## It is big on the scale as well: its species' lightest giant (the low end of the
## species' weights x FishTable.TROPHY_KG) weighs this much or more. Of the fish worth
## WORTH that leaves out the crayfish alone ("Giant Crayfish, 0.45 kg": 0.3 to 0.9 kg;
## the lightest of the others weighs 3 kg).
const KG := 2.0
## And it isn't the third giant of its species in this goal (`kinds`): two of a kind at
## the most, where the water gives another (cheese draws the chub, dough at dawn the
## carp: three of the same in a row read as one fish said three times).
const KIND := 2
## How often the water is asked again for one at the most: a guard alone. On the bait and
## at the hour that draw the fewest of them (maggots at noon on a cane pole) one bite in
## ten is worth showing: nine or ten asks on average, and a hundred fall short once in
## some 50 000 giants (oftener for a third of a kind, which is then the catch); on worms
## at noon it takes three or four, at dusk about one.
const ASKS := 100
## How the giant of a bite shows that the pond pays (fit): not (too little in the purse
## or on the scale, or a legend that didn't come by itself), well but for being the third
## of its kind, or well.
enum Fit { POOR, REPEAT, GOOD }
const XP := 8
const GLYPH := "drop"
const COLOR := Color("7cc4e8")
## The story's goal it comes up beside, and the project that goal builds.
const QUEST := "barn"
const PROJECT := &"barn_1"
## The dot floats this high over the bank.
const BANK_LIFT := 0.8
const POLL := 0.5

## Saved: it came up; it is over (done, or the barn was built first); the fish landed so
## far; which of the catches still to come are giants for sure (0 the first .. FISH - 1).
var up := false
var done := false
var count := 0
var slots: Array[int] = []
## Saved: the species of the giants landed for it so far (promised or by luck).
var kinds: Array[StringName] = []
## Set by tests: it comes up in this automated run.
var testing := false

var _goal: SideGoal
var _poll := 0.0
## The closing line, held back while a window is open (said once it is shut).
var _closing := ""
## Draws the giants' places (tests seed it).
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_goal = SideGoal.new(&"fish_goal", tr("FISH_GOAL_TITLE"), GLYPH, COLOR)
	_goal.quiet = true


func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("fish-goal")


## The card.
func goal() -> SideGoal:
	return _goal


## It is on the HUD now.
func is_up() -> bool:
	return SideStory.goals.has(_goal)


## It is running: up and not over yet.
func running() -> bool:
	return enabled() and up and not done


## The barn's price.
static func price() -> int:
	return int(ProjectTable.get_project(PROJECT).get("cost", 0))


## A rod in the bag (any of them, worn out or not).
static func has_rod() -> bool:
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and (st.item.id == Angler.ROD or st.item.tool_type == Angler.ROD):
			return true
	return false


static func _has_bait() -> bool:
	for st: ItemStack in PlayerState.inventory.slots:
		if st != null and st.item.category == "bait":
			return true
	return false


## The fishing contest is on and he is at its pond: his fish are the contest's, not this
## goal's.
func suspended() -> bool:
	var p := Game.player as Node3D
	return FishingContest.is_on() and p != null and is_instance_valid(p) and FishingContest.at_venue(p.global_position)


## Its moment: the barn is the story's goal, doesn't stand and can't be paid for, and
## there is a rod to fish with.
func _due() -> bool:
	if Quests.tutorial_done() or String(Quests.current().get("id", "")) != QUEST:
		return false
	return not FarmState.is_built(PROJECT) and Economy.money < price() and has_rod()


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	if _closing != "" and not Game.is_ui_open():
		_say_closing()
	update()


## Puts the goal up when its moment comes, keeps its card and dot up to date, and takes
## it down for good once the barn stands.
func update() -> void:
	if not enabled() or done:
		_take_down()
		return
	if FarmState.is_built(PROJECT):
		# Built before the fifth fish (or before it ever came up): nothing left to show.
		if up:
			done = true
		_take_down()
		return
	if not up:
		# Not behind a window (the level-up's, when level 3 itself brings the barn goal; a
		# shop's, when a purchase leaves him short): its toast would come and go unseen.
		if not _due() or Game.is_ui_open():
			return
		up = true
		count = 0
		slots = _draw()
		kinds = []
		Game.notify(tr("MSG_SIDE_NEW") % tr("FISH_GOAL_TITLE"), COLOR)
		Audio.ui("notify", -8.0)
	_show()
	SideStory.add_goal(_goal)


func _take_down() -> void:
	if _goal != null:
		SideStory.remove_goal(_goal)


## Which BIG of the FISH catches are giants: drawn once, when the goal comes up.
func _draw() -> Array[int]:
	var all: Array[int] = []
	for i in FISH:
		all.append(i)
	var out: Array[int] = []
	for i in BIG:
		out.append(all.pop_at(_rng.randi_range(0, all.size() - 1)))
	out.sort()
	return out


## What the card says and where its dot points.
func _show() -> void:
	_goal.title = tr("FISH_GOAL_TITLE")
	# At the contest the line of why gives way to the one that says his fish count for
	# the contest alone: always in view there (a quiet card's hint shows only for a while
	# and near its dot, which stays at Grandpa's pond).
	_goal.set_needs(tr("FISH_GOAL_CONTEST") if suspended() else tr("FISH_GOAL_WHY"))
	var text := tr("FISH_GOAL_TEXT") % [FISH, mini(count, FISH), FISH]
	if not has_rod() or not _has_bait():
		# No rod any more, or out of bait: where the story sends him for them, and why.
		var place: Dictionary = Quests.place_for("pond")
		var hint := String(place["hint"])
		var label := ""
		if has_rod():
			# Out of bait: said first (the story's line alone, "Sold at the town market"
			# under "Catch 5 fish", reads as if the fish were), and on the dot's pill
			# where that line sends him for bait (not where it sends him to earn its price).
			var need := tr("HINT_NEED_BAIT")
			if hint in [tr("HINT_MARKET"), tr("HINT_DOUGH")]:
				label = tr("CAT_BAIT")
			if not hint.contains(need):
				hint = need if hint == "" else "%s\n%s" % [need, hint]
		_goal.set_goal(text, hint, place["at"], label)
		return
	var bank := _bank()
	_goal.set_goal(text, "", bank["at"], String(bank["label"]))


## The bank of the nearest pond, on the farmer's side: {"at", "label"}. Grandpa's pond
## while the contest has the town's.
func _bank() -> Dictionary:
	var p := Game.player as Node3D
	var from := Vector2(p.global_position.x, p.global_position.z) if p != null and is_instance_valid(p) else Vector2.ZERO
	var c := WorldLayout.POND_CENTER
	var r := WorldLayout.POND_RADIUS
	var label := "SPOT_POND"
	if not FishingContest.is_on() \
			and from.distance_to(WorldLayout.TOWN_POND_CENTER) - WorldLayout.TOWN_POND_RADIUS < from.distance_to(c) - r:
		c = WorldLayout.TOWN_POND_CENTER
		r = WorldLayout.TOWN_POND_RADIUS
		label = "SIDE_LABEL_CONTEST"
	var d := from - c
	if d.length() < 0.1:
		d = Vector2(1, 0)
	var at := c + d.normalized() * (r - 0.5)
	return {"at": Vector3(at.x, maxf(TerrainData.height(at.x, at.y), WorldLayout.WATER_LEVEL) + BANK_LIFT, at.y), "label": tr(label)}


# --- The catches -----------------------------------------------------------------------------

## The catch now due is one of the giants for sure.
func owes_giant() -> bool:
	return running() and not suspended() and slots.has(count)


## The bite as it will be (Angler.roll_catch): `catch` (FishTable.roll) made the giant of
## its species when one is due. An old boot stays a boot (it uses up nothing, and the
## water isn't asked again for it). Should that giant not be one worth showing (fit: under
## WORTH, under KG on the scale, a legend over TOP, the third of its kind), `again` (the
## roll that gave `catch`, once more) is asked until a fish bites whose giant is, ASKS
## times at the most: the first such is the catch; else a third of its kind, if one bit
## (the water gives nothing else worth showing), else the most valuable giant that bit
## (it holds nothing better). A giant that bit by luck and is worth showing is kept as it
## is, a legend too; so is any catch that owes none.
func shape(catch: Dictionary, again := Callable()) -> Dictionary:
	if not owes_giant():
		return catch
	var best := _giant(catch)
	if best.is_empty():
		return catch
	var rank := fit(catch)
	var asks := 0
	while rank < Fit.GOOD and again.is_valid() and asks < ASKS:
		asks += 1
		var bite: Dictionary = again.call()
		var other := _giant(bite)
		if other.is_empty():
			continue
		var r := fit(bite)
		if r > rank or (r == rank and giant_price(other["id"]) > giant_price(best["id"])):
			best = other
			rank = r
	return best


## How well the giant of `bite` (a catch as the water gave it) shows that the pond pays:
## see WORTH, TOP, KG and KIND (an old boot: Fit.POOR).
func fit(bite: Dictionary) -> Fit:
	var sp := FishTable.species_of(bite["id"])
	if not FishTable.is_fish(sp):
		return Fit.POOR
	var fetches := giant_price(sp)
	var kg: Vector2 = FishTable.get_species(sp)["kg"]
	if fetches < WORTH or kg.x * FishTable.TROPHY_KG < KG:
		return Fit.POOR
	if fetches > TOP and not bool(bite.get("trophy", false)):
		return Fit.POOR
	return Fit.REPEAT if kinds.count(sp) >= KIND else Fit.GOOD


## `catch` as the giant of its species (itself, if it is one already; {} for an old boot).
static func _giant(catch: Dictionary) -> Dictionary:
	if bool(catch.get("trophy", false)):
		return catch
	var id: StringName = catch["id"]
	if not FishTable.is_fish(id) or not ItemDB.has_item(FishTable.trophy_id(id)):
		return {}
	return FishTable.trophy_of(catch)


## What the giant of a fish fetches at the market's list price (`id`: the fish, or its
## giant; 0 for an old boot).
static func giant_price(id: StringName) -> int:
	var item := ItemDB.get_item(FishTable.trophy_id(FishTable.species_of(id)))
	return item.sell_price if item != null else 0


## A catch landed on the bank (Angler): a fish counts (a giant among them takes its
## place off `slots`, and its species is noted in `kinds`), the fifth ends the goal.
func note_landed(id: StringName) -> void:
	if not running() or suspended() or not FishTable.is_fish(FishTable.species_of(id)):
		return
	if FishTable.is_trophy(id):
		kinds.append(FishTable.species_of(id))
	if slots.has(count):
		slots.erase(count)
		if not FishTable.is_trophy(id):
			# Hooked before the goal knew of it: the giant is owed on a later catch.
			for i in range(count + 1, FISH):
				if not slots.has(i):
					slots.append(i)
					slots.sort()
					break
	count += 1
	if count >= FISH:
		_complete()
	else:
		_show()


## What the farmer's fish fetch at the market right now: the raw fish in the bag and the
## ones still lying on the bank, lot by lot as the counter pays (Economy.quote).
func fish_worth() -> int:
	var worth := 0
	var counted := {}
	for st: ItemStack in PlayerState.inventory.slots:
		if st == null or st.item.category != "fish" or st.item.sell_price <= 0:
			continue
		worth += Economy.quote(st.item.id, st.count, st.quality, 1.0, int(counted.get(st.item.id, 0)))
		counted[st.item.id] = int(counted.get(st.item.id, 0)) + st.count
	for n: Node in get_tree().get_nodes_in_group(&"caught_fish"):
		var f := n as FloppingFish
		if f == null or f.is_queued_for_deletion() or not FishTable.is_fish(FishTable.species_of(f.item_id)):
			continue
		worth += Economy.quote(f.item_id, 1, f.quality, 1.0, int(counted.get(f.item_id, 0)))
		counted[f.item_id] = int(counted.get(f.item_id, 0)) + 1
	return worth


## The fifth fish: a little farm experience and what the catch is worth at the market.
## With a window open (the level-up's, should this fish or the experience bring a level)
## the line waits until it is shut (_process).
func _complete() -> void:
	if done:
		return
	done = true
	slots = []
	kinds = []
	_closing = tr("MSG_SIDE_DONE") % (tr("FISH_GOAL_DONE") % UiTheme.money(fish_worth()))
	Progress.add(XP)
	if not Game.is_ui_open():
		_say_closing()
	_take_down()
	_poll = 1.5


func _say_closing() -> void:
	Game.notify(_closing, UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	_closing = ""


## The five are caught and the barn they were caught for isn't built yet: his fish are
## the goods the story's line names first to sell (Quests.sellable_names).
func catch_first() -> bool:
	return enabled() and up and done and not FarmState.is_built(PROJECT)


# --- Save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var kinds_saved: Array[String] = []
	for sp: StringName in kinds:
		kinds_saved.append(String(sp))
	return {"up": up, "done": done, "count": count, "slots": slots.duplicate(), "kinds": kinds_saved}


## A save from before the goal: it simply comes up when its moment does (one from before
## `kinds`: as if no giant had been landed yet).
func load_data(data: Dictionary) -> void:
	_take_down()
	up = bool(data.get("up", false))
	done = bool(data.get("done", false))
	count = int(data.get("count", 0))
	slots = []
	for i: Variant in data.get("slots", []):
		slots.append(int(i))
	kinds = []
	for sp: Variant in data.get("kinds", []):
		kinds.append(StringName(str(sp)))
	_closing = ""
	_poll = 0.0
