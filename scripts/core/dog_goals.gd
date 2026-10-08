class_name DogGoals
extends Node
## The quiet side goals that come with the farmer's own dog (Pet owns it, Pet.goals, and
## saves it): things to do with the dog once it is his, one at a time, each on a compact
## card with a small, faint dot (SideGoal.quiet), a little farm experience when done (XP).
## They never stand in the story's way and never run out:
##
##   kennel  "Build <name> a doghouse": the construction board's Doghouse kit, put up and
##           finished (Pet.kennel). The dot shows the board until the kit is in the bag,
##           and the card says what the kit takes against what he has ("Wood 3/8 · Nails
##           0/6 · $10/10 ✓": SideGoal.needs).
##   ball    "Buy a ball at the market": a dog ball in the bag (the dot shows the market).
##           Short of the kit's or the ball's price, the hint says how much more it takes
##           and how to earn it, and the dot goes there first (Quests.money_short).
##   sit     "First lesson: teach <name> to sit": Pet.knows(&"sit") (F looking at it, then
##           a pat; the hint counts the practices).
##   fetch   "Teach <name> to bring the ball back": comes up once it is old enough
##           (Pet.FETCH_AGE days); Pet.knows(&"fetch"). With the ball lying about (not in
##           the bag, not the dog's) the dot shows the ball and the hint how it is taken.
##
## And one out of turn, before whichever of those is up, the first time the dog is really
## hungry (Pet.hungry; `feed_up`):
##
##   feed    "<name> is hungry: put food in its bowl": dog food poured into its bowl
##           (Pet.fed_by_him). With a sack in the bag the dot shows the bowl; with none the
##           hint says the market sells it and for how much, and the dot shows the market
##           (short of its price: how to earn it, as for the ball). Had he filled the bowl
##           before it ever came up, there is nothing to teach: it is done without a word.
##
## One met already when its turn comes (a ball in the bag) is ticked off at once. Automated
## runs keep them away unless the run asks for them (`--dog-goals`, or `testing`).

const GOALS: Array[StringName] = [&"kennel", &"ball", &"sit", &"fetch"]
## The one that comes out of turn: feeding it.
const FEED := &"feed"
const XP := {&"kennel": 6, &"ball": 3, &"sit": 8, &"fetch": 10, &"feed": 4}
const GLYPH := "paw"
const COLOR := Color("e8c088")
## The dot floats this high over the board, over the market's counter.
const BOARD_LIFT := 2.3
const COUNTER_LIFT := 1.5
const BOWL_LIFT := 0.5
const POLL := 0.5

## Saved: the first goal came up (the farmer was told); the ones done (id -> true); the
## dog has been hungry and the feeding goal is up until it is done.
var up := false
var done := {}
var feed_up := false
## Set by tests: the goals come up in this automated run.
var testing := false

var _goal: SideGoal
var _poll := 0.0


func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("dog-goals")


## The goal whose turn it is (&"" once all are done).
func current() -> StringName:
	if feed_up and not done.has(FEED):
		return FEED
	for id: StringName in GOALS:
		if not done.has(id):
			return id
	return &""


## The card (null before there is a dog to name it after).
func goal() -> SideGoal:
	return _goal


## The goal `id` is on the HUD now.
func is_up(id: StringName) -> bool:
	return _goal != null and SideStory.goals.has(_goal) and current() == id


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	update()


## Puts the goal whose turn it is on its card, keeps the card and the dot up to date, and
## ticks it off when it is met.
func update() -> void:
	if enabled() and Pet.has_dog() and not feed_up and not done.has(FEED):
		if Pet.fed_by_him:
			# He found the bowl by himself: nothing to teach.
			done[FEED] = true
		elif Pet.hungry():
			feed_up = true
	var id := current()
	if not enabled() or not Pet.has_dog() or id == &"":
		_take_down()
		return
	if _goal == null or _goal.title != Pet.dog_name:
		_take_down()
		_goal = SideGoal.new(&"dog", Pet.dog_name, GLYPH, COLOR)
		_goal.quiet = true
	if id == &"fetch" and not _met(id) and Pet.age_days() < Pet.FETCH_AGE:
		# Too young yet to bring a ball back: this one waits till it has grown a little.
		_take_down()
		return
	_show(id)
	if not up:
		up = true
		Game.notify(tr("MSG_DOG_GOALS_NEW") % Pet.dog_name, COLOR)
		Audio.ui("notify", -8.0)
	if _met(id):
		_complete(id)
		return
	SideStory.add_goal(_goal)


func _take_down() -> void:
	if _goal != null:
		SideStory.remove_goal(_goal)


## Whether goal `id` is met now.
func _met(id: StringName) -> bool:
	match id:
		&"kennel":
			return Pet.kennel != null
		&"ball":
			return PlayerState.inventory.has_item(Pet.BALL) or Pet.knows(&"fetch") or int(Pet.practice.get(&"fetch", 0)) > 0 \
					or Pet.ball_lying() != null or (Pet.dog != null and is_instance_valid(Pet.dog) and Pet.dog.holding_ball)
		&"sit":
			return Pet.knows(&"sit")
		&"fetch":
			return Pet.knows(&"fetch")
		FEED:
			return Pet.fed_by_him
	return false


## What goal `id`'s card says and where its dot points.
func _show(id: StringName) -> void:
	var dog_name := Pet.dog_name
	var dog: Variant = Pet.dog if Pet.dog != null and is_instance_valid(Pet.dog) and not Pet.dog.is_carried() else null
	match id:
		FEED:
			_goal.set_needs("")
			var text := tr("DOG_GOAL_FEED") % dog_name
			if PlayerState.inventory.has_item(Pet.FOOD):
				var bowl: Variant = Pet.bowl_point() + Vector3(0.0, BOWL_LIFT, 0.0) if Pet.bowl != null and is_instance_valid(Pet.bowl) else null
				_goal.set_goal(text, tr("DOG_HINT_FEED_BOWL") % Pet.SACK_MEALS, bowl, tr("PET_BOWL") if bowl != null else "")
				return
			# No dog food: the market sells it (short of its price: how to earn it first).
			var town := get_tree().get_first_node_in_group(&"town") as Town
			var counter: Variant = town.market_counter.global_position + Vector3(0.0, COUNTER_LIFT, 0.0) if town and town.market_counter else null
			var price := Economy.buy_price(Pet.FOOD)
			var hint := tr("DOG_HINT_FEED_MARKET") % [UiTheme.money(price), Pet.SACK_MEALS]
			var label := tr("UI_TOWN_MARKET")
			if Economy.money < price:
				var short: Dictionary = Quests.money_short(price)
				hint = "%s\n%s" % [hint, String(short["hint"])]
				counter = short["at"]
				label = ""
			_goal.set_goal(text, hint, counter, label if counter != null else "")
		&"kennel":
			var hint := tr("DOG_HINT_KENNEL_BOARD")
			var where: Variant = WorldLayout.BOARD_POS + Vector3(0.0, TerrainData.height(WorldLayout.BOARD_POS.x, WorldLayout.BOARD_POS.z) + BOARD_LIFT, 0.0)
			var label := tr("DOG_LABEL_BOARD")
			var needs := ""
			if PlayerState.inventory.has_item(&"doghouse"):
				hint = tr("DOG_HINT_KENNEL_PLACE")
				where = null
			elif not get_tree().get_nodes_in_group(Doghouse.GROUP).is_empty():
				hint = tr("DOG_HINT_KENNEL_WAIT")
				where = null
			else:
				# The kit is still to be made: what it takes against what he has; short of
				# its price, how to earn it first.
				var kit := ProjectTable.get_project(&"doghouse")
				needs = Quests.needs_text(kit.get("items", {}), int(kit.get("cost", 0)))
				if Economy.money < int(kit.get("cost", 0)):
					var short: Dictionary = Quests.money_short(int(kit.get("cost", 0)), kit.get("items", {}))
					hint = String(short["hint"])
					where = short["at"]
					label = ""
			_goal.set_needs(needs)
			_goal.set_goal(tr("DOG_GOAL_KENNEL") % dog_name, hint, where, label if where != null else "")
		&"ball":
			var town := get_tree().get_first_node_in_group(&"town") as Town
			var counter: Variant = town.market_counter.global_position + Vector3(0.0, COUNTER_LIFT, 0.0) if town and town.market_counter else null
			var hint := tr("DOG_HINT_BALL") % dog_name
			var label := tr("UI_TOWN_MARKET")
			var price := Economy.buy_price(Pet.BALL)
			if Economy.money < price:
				var short: Dictionary = Quests.money_short(price)
				hint = String(short["hint"])
				counter = short["at"]
				label = ""
			_goal.set_needs("")
			_goal.set_goal(tr("DOG_GOAL_BALL"), hint, counter, label if counter != null else "")
		&"sit":
			_goal.set_needs("")
			_goal.set_goal(tr("DOG_GOAL_SIT") % dog_name,
					tr("DOG_HINT_SIT") % [mini(int(Pet.practice.get(&"sit", 0)), Pet.need(&"sit")), Pet.need(&"sit")], dog, dog_name if dog != null else "")
		&"fetch":
			var has_ball := PlayerState.inventory.has_item(Pet.BALL) or (dog != null and ((dog as PetDog).holding_ball or (dog as PetDog).ball != null))
			var hint := tr("DOG_HINT_FETCH") % [mini(int(Pet.practice.get(&"fetch", 0)), Pet.need(&"fetch")), Pet.need(&"fetch")]
			var lying := Pet.ball_lying() if not has_ball else null
			if lying != null:
				# The ball lies about somewhere (it never comes into the bag by itself): the
				# dot shows where, the hint says how it is taken.
				_goal.set_goal(tr("DOG_GOAL_FETCH") % dog_name, tr("DOG_HINT_FETCH_LYING"), lying.global_position + Vector3(0.0, 0.5, 0.0), tr("ITEM_DOG_BALL"))
				return
			_goal.set_goal(tr("DOG_GOAL_FETCH") % dog_name, hint if has_ball else tr("DOG_HINT_FETCH_NO_BALL"), dog, dog_name if dog != null else "")


## Goal `id` done: a note, a little farm experience; the next one's turn.
func _complete(id: StringName) -> void:
	if done.has(id):
		return
	done[id] = true
	Progress.add(int(XP[id]))
	Game.notify(tr("MSG_SIDE_DONE") % _goal.text, UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	SideStory.remove_goal(_goal)
	_poll = 1.5


# --- Save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"up": up, "done": done.keys().map(func(k: StringName) -> String: return String(k)), "feed_up": feed_up}


func load_data(data: Dictionary) -> void:
	_take_down()
	_goal = null
	up = bool(data.get("up", false))
	feed_up = bool(data.get("feed_up", false))
	done = {}
	for id: Variant in data.get("done", []):
		done[StringName(id)] = true
	_poll = 0.0
