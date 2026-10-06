class_name BreedingGoals
extends Node
## The lesson of the young (Breeding): quiet side goals beside the story's, on a compact
## card with a small dot (SideGoal.quiet), told once with the sheep, from the day the
## farmer owns his first grown ewe:
##
##   ram    "Grow the flock: buy a ram": Rıza the stockman's word under it, the dot on the
##          Animal Market (short of the ram's price: how much more and how to earn it,
##          Quests.money_short; the barn full: make room first).
##   wait   "Keep your ewe well fed and happy: a lamb is on the way": the dot on the ewe, her
##          state under the goal ("Pamuk: Fed ✓ · Content · Healthy ✓", then "Pregnant · 2
##          days left") and what she still lacks as the hint (hay and water, a pat, the
##          vet; the barn full when she is due).
##   name   "Your lamb is born: go to it and give it a name": the dot on the lamb. Walking
##          up to it opens the naming prompt (Animals.offer_name; E on it does too).
##
## Done with a warm line, a little farm experience and, when Zeynep is known, a short
## letter from her (Mail). Cows and horses get no lesson of their own: one line the first
## time a pair shares the barn (PAIR_HINT), and their first young asks for its name the
## same way. All of it is kept in FarmState.flags (saved with the farm):
##   breed_step        the last step told (STEPS' place + 1), "breed_done" once it is over
##   first_born_<kind> the id of that kind's first young while it waits for its name, 0 after
##   pair_hint_<kind>  the pair's line was said
## Automated runs keep it away unless a test turns `testing` on.

const STEPS: Array[StringName] = [&"ram", &"wait", &"name"]
const XP := {&"ram": 4, &"wait": 0, &"name": 8}
const GLYPH := "heart"
const COLOR := Color("f2c4a0")
const POLL := 0.4
## The first young's naming prompt opens when the farmer is this near it (metres).
const NAME_NEAR := 3.4
## The dot floats this high over the Animal Market's hatch.
const MARKET_LIFT := 1.6
## Kinds that get one line when a pair first shares a building (the sheep have the lesson).
const PAIR_HINT: Array[StringName] = [&"cow", &"horse"]

## Set by tests: the goals, the first young's naming and the pair's line happen in this
## automated run.
static var testing := false

var _goal: SideGoal
var _poll := 0.0


static func enabled() -> bool:
	return testing or not DebugTools.is_automated()


# --- The first young of a kind -----------------------------------------------------------------

static func _flag(species: StringName) -> String:
	return "first_born_%s" % String(species)


## `baby` was just born (Breeding.birth): the first of its kind on this farm waits for its
## name (true).
static func first_born(baby: AnimalData) -> bool:
	if not enabled() or SaveGame.loading or FarmState.flags.has(_flag(baby.species)):
		return false
	FarmState.flags[_flag(baby.species)] = baby.id
	return true


## The young of `species` waiting for the farmer to name it (null: none).
static func waiting(species: StringName) -> AnimalData:
	var id: Variant = FarmState.flags.get(_flag(species), 0)
	var a := Animals.by_id(int(id) if id is int or id is float else 0)
	return a if a != null and not a.adult else null


## Whether E on `a` gives it its name (a first young, on its legs, no prompt open for it).
static func wants_name(a: AnimalData) -> bool:
	return a != null and Breeding.breeds(a.species) and not a.adult and waiting(a.species) == a and Breeding.is_up(a)


## The naming prompt's kind for `a` ("LAMB", "CALF", "FOAL"; "" for the birds: Animals' own).
static func name_kind(a: AnimalData) -> String:
	if a == null or a.adult or not Breeding.breeds(a.species):
		return ""
	return {&"sheep": "LAMB", &"cow": "CALF", &"horse": "FOAL"}.get(a.species, "")


## `a` has the name the farmer chose (Animals._on_named): true when it was a first young
## (its welcome is said here; the lamb's ends the lesson).
func named(a: AnimalData) -> bool:
	if a == null or waiting(a.species) != a:
		return false
	FarmState.flags[_flag(a.species)] = 0
	if a.species == &"sheep" and not FarmState.flags.has("breed_done"):
		_finish(a)
	else:
		Progress.add(int(XP[&"name"]) / 2)
		Game.notify(tr("MSG_YOUNG_NAMED") % a.name, UiTheme.GOLD)
		Audio.ui("confirm", -6.0)
	_poll = 0.0
	return true


# --- The card -------------------------------------------------------------------------------------

## The card (null before the lesson began; tests).
func goal() -> SideGoal:
	return _goal


## The step on the card now (&"" when none is up).
func shown() -> StringName:
	return step() if _goal != null and SideStory.goals.has(_goal) else &""


## The lesson's step whose turn it is: &"" (not begun: no grown ewe; or over), &"ram",
## &"wait", &"name", or &"over" (the lamb named, grown or gone: to be closed).
func step() -> StringName:
	if FarmState.flags.has("breed_done"):
		return &""
	if waiting(&"sheep") != null:
		return &"name"
	if FarmState.flags.has(_flag(&"sheep")):
		return &"over"
	var ewe := ewe_of_lesson()
	if ewe == null:
		return &""
	if not ewe.pregnant() and _ram() == null:
		return &"ram"
	return &"wait"


## The ewe the lesson follows: one carrying first, else the one best kept (null: no grown
## ewe on the farm).
func ewe_of_lesson() -> AnimalData:
	var best: AnimalData = null
	for a in Animals.animals:
		if a.species != &"sheep" or a.male or not a.adult:
			continue
		if a.pregnant():
			return a
		if best == null or a.happiness + a.health > best.happiness + best.health:
			best = a
	return best


## A grown ram on the farm (null: none).
func _ram() -> AnimalData:
	for a in Animals.animals:
		if a.species == &"sheep" and a.male and a.adult:
			return a
	return null


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	update()


## Keeps the card and its dot up to date, tells each step once, opens the first young's
## naming prompt when the farmer walks up to it and says the pair's line for the other kinds.
func update() -> void:
	if not enabled():
		_take_down()
		return
	_ask_names()
	_pair_hints()
	var now := step()
	if now == &"":
		_take_down()
		return
	if now == &"over":
		# The lamb grew up or was lost before it had its name: the lesson closes quietly.
		FarmState.flags["breed_done"] = true
		_take_down()
		return
	if _goal == null:
		_goal = SideGoal.new(&"breeding", tr("SIDE_BREED_TITLE"), GLYPH, COLOR)
		_goal.quiet = true
	_show(now)
	var told := int(FarmState.flags.get("breed_step", 0))
	var place := STEPS.find(now) + 1
	if place > told:
		# The step before is done (the ram bought): a little farm experience for it.
		if told > 0 and told <= STEPS.size():
			Progress.add(int(XP[STEPS[told - 1]]))
		FarmState.flags["breed_step"] = place
		Game.notify(tr("MSG_SIDE_NEW") % _goal.text, COLOR)
		Audio.ui("notify", -8.0)
	SideStory.add_goal(_goal)


func _take_down() -> void:
	if _goal != null:
		SideStory.remove_goal(_goal)


## What step `id`'s card says and where its dot points.
func _show(id: StringName) -> void:
	match id:
		&"ram":
			var price := Breeding.male_price(&"sheep")
			var hint := tr("SIDE_HINT_BREED_RAM")
			var where: Variant = _market()
			var label := tr("LABEL_ANIMAL_MARKET")
			var home := Animals.home_for(&"sheep")
			if home != null and home.free_space() <= 0:
				hint = tr("SIDE_HINT_BREED_FULL")
				where = null
			elif Economy.money < price:
				var short: Dictionary = Quests.money_short(price)
				hint = String(short["hint"])
				where = short["at"]
				label = ""
			_goal.set_needs(Quests.needs_text({}, price))
			_goal.set_goal(tr("SIDE_GOAL_BREED_RAM"), hint, where, label if where != null else "")
		&"wait":
			var ewe := ewe_of_lesson()
			var n := Animals.node_of(ewe)
			var where: Variant = n if n != null and n.is_inside_tree() else null
			_goal.set_needs(state_line(ewe))
			_goal.set_goal(tr("SIDE_GOAL_BREED_WAIT"), _wait_hint(ewe), where, ewe.name if where != null else "")
		&"name":
			var lamb := waiting(&"sheep")
			var n := Animals.node_of(lamb)
			var mother := Animals.by_id(lamb.mother)
			var where: Variant = n if n != null and n.is_inside_tree() else null
			_goal.set_needs("")
			_goal.set_goal(tr("SIDE_GOAL_BREED_NAME"), tr("SIDE_HINT_BREED_NAME") % mother.name if mother != null else tr("SIDE_HINT_BREED_NAME_ALONE"),
					where, Animals.species_name(&"sheep", false) if where != null else "")


## The ewe's state under the goal: "Pamuk: Fed ✓ · Content · Healthy ✓", or her days left.
func state_line(ewe: AnimalData) -> String:
	if ewe.pregnant():
		return "%s: %s" % [ewe.name, Breeding.status_text(ewe)]
	var parts := PackedStringArray()
	for pair: Array in [["BREED_FED", ewe.fullness >= Breeding.FED], ["BREED_CONTENT", ewe.happiness >= Breeding.CONTENT],
			["BREED_HEALTHY", ewe.health >= Breeding.HEALTHY and not ewe.sick and not ewe.injured()]]:
		parts.append("%s %s" % [tr(pair[0]), Quests.NEED_MET] if pair[1] else tr(pair[0]))
	return "%s: %s" % [ewe.name, " · ".join(parts)]


## What she still lacks (or Grandpa's word while she carries).
func _wait_hint(ewe: AnimalData) -> String:
	if ewe.pregnant():
		return tr("SIDE_HINT_BREED_ROOM") if Breeding.waiting_for_room(ewe) or (ewe.due_in <= 1 and _full(ewe)) else tr("SIDE_HINT_BREED_CARRYING")
	match Breeding.blocker(ewe):
		"hungry":
			return tr("SIDE_HINT_BREED_HUNGRY")
		"unhappy":
			return tr("SIDE_HINT_BREED_UNHAPPY")
		"health", "sick", "hurt", "away":
			return tr("SIDE_HINT_BREED_HEALTH")
		"no_male":
			return tr("SIDE_HINT_BREED_APART")
	return tr("SIDE_HINT_BREED_SOON")


func _full(ewe: AnimalData) -> bool:
	var h := Animals.housing_of(ewe)
	return h == null or h.free_space() <= 0


## Over the Animal Market's hatch in town (null without a town).
func _market() -> Variant:
	var town := get_tree().get_first_node_in_group(&"town") as Town
	if town == null or town.market_office == null:
		return null
	return town.market_office.global_position + Vector3(0.0, MARKET_LIFT, 0.0)


## The lamb has its name: the lesson is done (a warm line, farm experience, Zeynep's letter).
func _finish(lamb: AnimalData) -> void:
	FarmState.flags["breed_done"] = true
	_take_down()
	Progress.add(int(XP[&"name"]))
	Game.notify(tr("MSG_BREED_DONE") % lamb.name, UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	var mail := get_node_or_null(^"/root/Mail")
	if mail != null and SideStory.met:
		mail.call(&"send", "PERSON_ZEYNEP", "MAIL_ZEYNEP_LAMB_TITLE", "MAIL_ZEYNEP_LAMB_BODY", {}, {"name": lamb.name})


## A first young on its legs with the farmer beside it: its naming prompt opens (once; E
## on it opens it too). One grown or gone before it was named is let be.
func _ask_names() -> void:
	var player := Game.player as Node3D
	for species: StringName in Breeding.GESTATION:
		if not FarmState.flags.has(_flag(species)):
			continue
		var id: Variant = FarmState.flags[_flag(species)]
		if not (id is int or id is float) or int(id) == 0:
			continue
		var a := waiting(species)
		if a == null:
			FarmState.flags[_flag(species)] = 0
			continue
		var n := Animals.node_of(a)
		if n == null or not Breeding.is_up(a) or Animals.naming() != null or Game.is_ui_open():
			continue
		if player.global_position.distance_to(n.global_position) < NAME_NEAR:
			Animals.offer_name(a)


## The first time a grown cow and a bull (a mare and a stallion) share a building: one line.
func _pair_hints() -> void:
	for species: StringName in PAIR_HINT:
		var key := "pair_hint_%s" % String(species)
		if FarmState.flags.has(key):
			continue
		for a in Animals.animals:
			if a.species == species and a.adult and not a.male and Breeding.sire_in(Animals.housing_of(a), species) != null:
				FarmState.flags[key] = true
				Game.notify(tr("MSG_PAIR_%s" % String(species).to_upper()), COLOR)
				Audio.ui("notify", -8.0)
				break


## A new game or a load: the card comes down and is put up afresh from the farm's flags.
func reset() -> void:
	_take_down()
	_goal = null
	_poll = 0.0
