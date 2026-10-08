class_name FeedGoal
extends Node
## "Feed the hens": the quiet side goal of the first time the farmer's hens go hungry
## (SideStory owns it, SideStory.feed_goal, and saves it). On a compact card with a small,
## faint dot (SideGoal.quiet), never in the story's way, once in a save:
##
##   It comes up the first time one of his birds wears the hungry badge (her fullness under
##   Animals.HUNGRY_LEVEL) while her coop's feeder holds less than one ration (RATION:
##   hens eat whole rations, so that is nothing she can eat), and the story's own feeding
##   lesson is behind him (Quests.passed(LESSON)). Not while the story itself asks for
##   feeding: its lesson up or still ahead, or the farm chores' "top up the feeder" card up
##   (FarmChores; while this one is up that chore waits instead: one card about feed at a
##   time). Nor behind an open window (the morning report's, a shop's): its toast is the
##   only place it is announced, so it waits for the window to shut.
##   The card: "Feed the hens" over a line that says where feed comes from (SideGoal.needs,
##   always in view): the market sells it, and he can make it himself at the workbench, as
##   RecipeTable has it ("2 wheat into 5 feed"), said only once his farm level makes that
##   recipe.
##   The dot (its pill names the place, the hint under the card says what to do there):
##   the feeder when he has feed in the bag; else the warehouse when feed waits there
##   (Grandpa's sacks: where the story's lesson fetched it); else his workbench when he has
##   one and the wheat the recipe takes; else the market's counter (no hint there: the
##   card's line says it already), or, short of a sack's price, where to earn it first
##   (Quests.money_short).
##   Done when the feeder has feed again: filled by his hand (Trough.filled: hungry hens
##   empty a single sack before the next look), or found with a ration in it. Or when he
##   fed the hungry birds from his hand instead (feed in hand and the use key on a hen:
##   the card says "feed the hens", and that is what he did): none of that coop's birds
##   hungry any more and one of them fed by hand today (fed_by_hand). A little farm
##   experience (XP) and the usual closing line. It never comes again (`done`), and should
##   there be no bird left to feed while it is up it goes without a word.
##
## Automated runs keep it away unless the run asks for it (`--feed-goal`, or `testing`).

## The story's own feeding lesson (Quests.TUTORIAL) and the farm chore that asks for feed.
const LESSON := "feed"
const CHORE := &"care"
## Feed, its big sack, and the grain the workbench makes it from.
const ITEM := &"feed"
const BIG := &"feed_big"
const GRAIN := &"wheat"
## A feeder under this holds nothing a hen can eat (Animals.eat_from takes whole rations).
const RATION := 0.99
const XP := 4
const GLYPH := "wheat"
const COLOR := Color("f0b860")
## The dot floats this high over the feeder, over the market's counter.
const FEEDER_LIFT := 0.85
const COUNTER_LIFT := 1.5
const POLL := 0.5

## Saved: it came up; it is over (the feeder filled, or no bird left to feed).
var up := false
var done := false
## Set by tests: it comes up in this automated run.
var testing := false

var _goal: SideGoal
var _poll := 0.0
## The coop whose feeder the card is about (found again after a load).
var _home: AnimalHousing


func _ready() -> void:
	_goal = SideGoal.new(&"feed_goal", tr("FEED_GOAL_TEXT"), GLYPH, COLOR)
	_goal.quiet = true


func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("feed-goal")


## The card.
func goal() -> SideGoal:
	return _goal


## It is on the HUD now.
func is_up() -> bool:
	return SideStory.goals.has(_goal)


## It is running: up and not over yet.
func running() -> bool:
	return enabled() and up and not done


## The coop whose birds are going hungry before an empty feeder: one of them wears the
## hungry badge and the feeder holds less than a ration (the hungriest such bird's coop;
## null when there is none). Birds at the vet's or led away aren't the feeder's to feed.
func hungry_home() -> AnimalHousing:
	var best: AnimalHousing = null
	var least := Animals.HUNGRY_LEVEL
	for a: AnimalData in Animals.animals:
		if not AnimalTable.is_poultry(a.species) or a.at_vet() or a.away or a.fullness >= least:
			continue
		var h := Animals.housing_of(a)
		if not _has_feeder(h) or h.feed.amount >= RATION:
			continue
		best = h
		least = a.fullness
	return best


static func _has_feeder(h: AnimalHousing) -> bool:
	return h != null and is_instance_valid(h) and h.level > 0 and h.feed != null and is_instance_valid(h.feed)


## The coops birds live in now.
func _homes() -> Array[AnimalHousing]:
	var out: Array[AnimalHousing] = []
	for a: AnimalData in Animals.animals:
		if not AnimalTable.is_poultry(a.species):
			continue
		var h := Animals.housing_of(a)
		if _has_feeder(h) and not out.has(h):
			out.append(h)
	return out


## The farmer fed `home`'s hungry birds from his hand: none of them is hungry any more and
## one ate from his hand today (nothing else fills a hen before an empty feeder: a hungry
## one sold, or back from the vet's, doesn't count as fed).
func fed_by_hand(home: AnimalHousing) -> bool:
	var by_hand := false
	for a: AnimalData in Animals.animals:
		if not AnimalTable.is_poultry(a.species) or a.at_vet() or a.away or Animals.housing_of(a) != home:
			continue
		if a.fullness < Animals.HUNGRY_LEVEL:
			return false
		by_hand = by_hand or a.hand_fed_today
	return by_hand


## A bird lives on the farm (at the vet's too).
static func _has_birds() -> bool:
	for a: AnimalData in Animals.animals:
		if AnimalTable.is_poultry(a.species):
			return true
	return false


## The story itself asks for feeding now, or hasn't taught it yet: its lesson up or still
## ahead, or the farm chores' card for the feeder up.
func story_feeding() -> bool:
	if not Quests.passed(LESSON):
		return true
	return Quests.chores != null and Quests.chores.is_up(CHORE)


## The farmer can make feed himself now as far as his level goes (RecipeTable: wheat alone
## into feed).
static func can_make() -> bool:
	var r := RecipeTable.crafting(ITEM)
	var items: Dictionary = r.get("items", {})
	return items.size() == 1 and int(items.get(GRAIN, 0)) > 0 and Progress.level >= int(r.get("level", 1))


## The card's line: where feed comes from. The market sells it; and he can make it at the
## workbench, as the recipe has it (so much wheat into so much feed), once his level does.
func why() -> String:
	if not can_make():
		return tr("FEED_GOAL_WHY_BUY")
	var r := RecipeTable.crafting(ITEM)
	return tr("FEED_GOAL_WHY") % [int((r["items"] as Dictionary)[GRAIN]), int(r.get("count", 1))]


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	update()


## Puts the goal up when its moment comes, keeps its card and dot up to date, and ends it
## once the feeder has feed again.
func update() -> void:
	if not enabled() or done:
		_take_down()
		return
	if not up:
		if story_feeding() or Game.is_ui_open():
			return
		var home := hungry_home()
		if home == null:
			return
		up = true
		_home = home
		Game.notify("%s %s" % [tr("FEED_GOAL_NEW"), tr("MSG_SIDE_NEW") % tr("FEED_GOAL_TEXT")], COLOR)
		Audio.ui("notify", -8.0)
	elif not Quests.passed(LESSON):
		# (A save a newer chain put back before the lesson: the story's own card says it.)
		_take_down()
		return
	var feeder := _feeder()
	if feeder == null:
		# No bird left to feed (sold, or lost): nothing more to show, for good. (Birds whose
		# coop isn't to be found just now: the card waits for it.)
		done = not _has_birds()
		_take_down()
		return
	if feeder.amount >= RATION or fed_by_hand(_home):
		_complete()
		return
	_show(feeder)
	SideStory.add_goal(_goal)


func _take_down() -> void:
	if _goal != null:
		SideStory.remove_goal(_goal)


## The feeder the card is about: the hungry birds' (the same one while its coop stands and
## birds live in it), else that of a coop whose birds have nothing to eat, else one with
## feed in it (the goal is then met); null with no bird on the farm.
func _feeder() -> Trough:
	var homes := _homes()
	if not is_instance_valid(_home) or not homes.has(_home):
		_home = hungry_home()
	if _home == null:
		for h: AnimalHousing in homes:
			if _home == null or (h.feed.amount < RATION and _home.feed.amount >= RATION):
				_home = h
	return _home.feed if _home != null else null


## What the card says and where its dot points.
func _show(feeder: Trough) -> void:
	_goal.title = tr("FEED_GOAL_TEXT")
	if not feeder.filled.is_connected(_on_filled):
		feeder.filled.connect(_on_filled)
	_goal.set_needs(why())
	var place := place_now(feeder)
	_goal.set_goal(tr("FEED_GOAL_TEXT"), String(place["hint"]), place["at"], String(place["label"]) if place["at"] != null else "")


## Where the dot points now, the line that says what to do there and the dot's pill:
## {"at", "hint", "label", "where"} (`where`: "feeder", "warehouse", "bench", "market" or
## "earn").
func place_now(feeder: Trough) -> Dictionary:
	var inv := PlayerState.inventory
	# Feed in the bag: the feeder.
	if inv.count_item(ITEM) > 0 or inv.count_item(BIG) > 0:
		return {"where": "feeder", "at": feeder.global_position + Vector3(0.0, FEEDER_LIFT, 0.0),
			"hint": tr("FEED_GOAL_HINT_POUR"), "label": tr("FEED_GOAL_LABEL_FEEDER")}
	# Feed waiting in the warehouse: fetched from there, as in the story's lesson.
	if FarmState.warehouse.count(ITEM) > 0 or FarmState.warehouse.count(BIG) > 0:
		var shed: Variant = WaypointMarker.anchor(Warehouse.ANCHOR_INSIDE)
		return {"where": "warehouse", "at": shed if shed != null else Quests.place_for("warehouse")["at"],
			"hint": tr("HINT_FEED_WAREHOUSE"), "label": tr("UI_WAREHOUSE")}
	# The wheat the recipe takes and a workbench to make it at.
	var bench := _bench()
	if bench != null and can_make() and inv.count_item(GRAIN) >= int((RecipeTable.crafting(ITEM)["items"] as Dictionary)[GRAIN]):
		return {"where": "bench", "at": bench.top_point(), "hint": tr("FEED_GOAL_HINT_MAKE"), "label": tr("UI_WORKBENCH")}
	# Else the market sells it; short of a sack's price, where to earn it first.
	var price := Economy.buy_price(ITEM)
	if Economy.money < price:
		var short: Dictionary = Quests.money_short(price)
		return {"where": "earn", "at": short["at"], "hint": String(short["hint"]), "label": ""}
	var town := get_tree().get_first_node_in_group(&"town") as Town
	var counter: Variant = town.market_counter.global_position + Vector3(0.0, COUNTER_LIFT, 0.0) if town and town.market_counter else null
	# (No hint: the card's own line says the market sells it.)
	return {"where": "market", "at": counter, "hint": "", "label": tr("UI_TOWN_MARKET")}


## The nearest finished workbench on the farm (null: none).
func _bench() -> Workbench:
	var p := Game.player as Node3D
	var from := p.global_position if p != null and is_instance_valid(p) else Vector3.ZERO
	var best: Workbench = null
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group(&"placed"):
		var b := n as Workbench
		if b == null or not b.is_built() or b.is_queued_for_deletion():
			continue
		var d := b.global_position.distance_squared_to(from)
		if d < best_d:
			best = b
			best_d = d
	return best


## The farmer poured feed into a coop's feeder while the card is up: done (before the
## hungry hens empty it again).
func _on_filled() -> void:
	if running() and is_up():
		_complete()


## The feeder has feed again: a note, a little farm experience, and it is over for good.
func _complete() -> void:
	if done:
		return
	done = true
	Progress.add(XP)
	Game.notify(tr("MSG_SIDE_DONE") % tr("FEED_GOAL_TEXT"), UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	_take_down()
	_poll = 1.5


# --- Save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"up": up, "done": done}


## A save from before the goal: it simply comes up when its moment does.
func load_data(data: Dictionary) -> void:
	_take_down()
	up = bool(data.get("up", false))
	done = bool(data.get("done", false))
	_home = null
	_poll = 0.0
