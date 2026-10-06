class_name FarmChores
extends Node
## Quiet farm chores for the hours the story leaves free. On days FIRST_DAY to LAST_DAY,
## once the day's story is done and its next goal waits for a morning to come
## (Quests.story_idle: the wait for the rooster's day, for the pond's, a farm level after
## it), a few small things to do round the yard come up beside the story's card, each on
## a compact card with a small, faint dot (SideGoal.quiet, like the town's: TownGoals).
## They use what the farm already has, teach the daily round and send nobody on a trip:
##
##   bin     "Put something to sell in the shipping bin": anything shipped (the hint says
##           what sells, and that the courier pays in the morning).
##   eggs    "Collect today's eggs": the eggs lying about, three at most.
##   care    "Top up the coop's feeder and water": each filled once by hand, or well filled
##           already (CARE_FULL of its trough).
##   pet     "Pet your hens": PET_COUNT animals petted today (E).
##   wood    "Stock up on firewood": WOOD pieces picked up.
##   stones  "Clear stones off the land": STONES picked up.
##
## SHOWN at a time at most (SHOWN_BUSY while other side goals are up too: the town's, the
## wolves'), in an order that turns with the days (so day three doesn't open with day
## two's); done ones give a little farm experience (XP) and make room for the next. A chore there is nothing to do for (no eggs lying, no hens) isn't shown, and
## one that is done already when its turn comes (the troughs full, every hen petted) is
## passed over without a word. Each morning they start afresh; they go when the story's
## next goal comes up, never in its way. Quests owns it (Quests.chores) and saves it.
## Automated runs keep it away unless a test asks for it (`testing`).

const FIRST_DAY := 2
const LAST_DAY := 4
## Cards up at a time, and while other side goals have cards up as well (the column of
## cards stays short).
const SHOWN := 3
const SHOWN_BUSY := 2
const CHORES: Array[StringName] = [&"bin", &"eggs", &"care", &"pet", &"wood", &"stones"]
const XP := {&"bin": 3, &"eggs": 2, &"care": 3, &"pet": 2, &"wood": 3, &"stones": 2}
const GLYPHS := {&"bin": "tag", &"eggs": "box", &"care": "drop", &"pet": "heart", &"wood": "campfire", &"stones": "hammer"}
const COLOR := Color("e6c77a")
const EGGS_MOST := 3
const PET_COUNT := 3
const WOOD := 10
const STONES := 5
## A trough this full (of its capacity) wants no topping up.
const CARE_FULL := 0.75
const POLL := 0.5

## Saved: the day these belong to, the chores done on it (id -> true), what was counted
## toward the ones up (id -> n; the care's two halves under "fed" and "watered") and
## whether the day's note was shown.
var day := 0
var done := {}
var counts := {}
var told := false
## Set by tests: the chores come up in this automated run.
var testing := false

var _goals := {}
var _poll := 0.0


func _ready() -> void:
	for id: StringName in CHORES:
		var g := SideGoal.new(StringName("farm_" + String(id)), tr("SIDE_FARM_TITLE"), GLYPHS[id], COLOR)
		g.quiet = true
		_goals[id] = g
	Events.item_picked_up.connect(_on_picked_up)
	Events.shipped.connect(func(_id: StringName, n: int) -> void: _add(&"bin", n))
	Events.coop_fed.connect(func(_coop: Node) -> void: _add(&"care", 1, "fed"))
	Events.coop_watered.connect(func(_coop: Node) -> void: _add(&"care", 1, "watered"))
	Events.day_started.connect(func(_d: int) -> void: _poll = 0.0)


func enabled() -> bool:
	return testing or not DebugTools.is_automated()


func goal(id: StringName) -> SideGoal:
	return _goals.get(id)


## The chore `id` is on the HUD now.
func is_up(id: StringName) -> bool:
	return SideStory.goals.has(goal(id))


## The chores on the HUD now, in the order of their cards.
func shown() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _order():
		if is_up(id):
			out.append(id)
	return out


## The story leaves the farmer free on one of the chores' days.
func active() -> bool:
	return enabled() and GameClock.day >= FIRST_DAY and GameClock.day <= LAST_DAY and Quests.story_idle()


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	update()


## Puts the chores up while the story waits, keeps their cards and dots up to date, takes
## the done ones down (the next comes up) and all of them once the story goes on.
func update() -> void:
	if GameClock.day != day:
		day = GameClock.day
		done = {}
		counts = {}
		told = false
	if not active():
		_take_down()
		return
	# The cards up first: a done one goes (with its thanks), one with nothing left to do
	# for goes quietly.
	var up := 0
	for id: StringName in _order():
		if not is_up(id):
			continue
		if done.has(id) or not (_progress(id) >= _need(id) or _available(id)):
			SideStory.remove_goal(_goals[id])
		elif _progress(id) >= _need(id):
			_complete(id)
		else:
			up += 1
	# Then the next ones in today's order, as many as there is room for.
	var room := _room(up)
	for id: StringName in _order():
		if up >= room:
			break
		if done.has(id) or is_up(id) or not _available(id):
			continue
		if _progress(id) >= _need(id):
			# Done before its turn came (the troughs full, the hens petted): passed over.
			done[id] = true
			continue
		SideStory.add_goal(_goals[id])
		up += 1
	for id: StringName in _order():
		if is_up(id):
			_show(id)
	if up > 0 and not told:
		told = true
		Game.notify(tr("MSG_FARM_CHORES_NEW"), COLOR)
		Audio.ui("notify", -8.0)


## How many cards may be up now: fewer while other side goals show theirs (`up`: the
## chores' own cards among SideStory.goals).
func _room(up: int) -> int:
	return SHOWN if SideStory.goals.size() <= up else SHOWN_BUSY


func _take_down() -> void:
	for id: StringName in CHORES:
		SideStory.remove_goal(_goals[id])


## The chores in today's order: the list turned two places on each day.
func _order() -> Array[StringName]:
	var out: Array[StringName] = []
	var from := posmod((GameClock.day - FIRST_DAY) * 2, CHORES.size())
	for i in CHORES.size():
		out.append(CHORES[(from + i) % CHORES.size()])
	return out


## Counts `n` toward chore `id` while its card is up (`key`: one of its halves).
func _add(id: StringName, n: int, key := "") -> void:
	if not is_up(id):
		return
	var k := key if key != "" else String(id)
	counts[k] = int(counts.get(k, 0)) + n
	_poll = 0.0


func _on_picked_up(id: StringName, n: int) -> void:
	match id:
		&"egg":
			_add(&"eggs", n)
		&"wood":
			_add(&"wood", n)
		&"stone":
			_add(&"stones", n)


func _count(key: String) -> int:
	return int(counts.get(key, 0))


## How much chore `id` asks for now.
func _need(id: StringName) -> int:
	match id:
		&"eggs":
			return clampi(_count("eggs") + _eggs_lying(), 1, EGGS_MOST)
		&"care":
			return 2
		&"pet":
			return clampi(Animals.animals.size(), 1, PET_COUNT)
		&"wood":
			return WOOD
		&"stones":
			return STONES
	return 1


## How far along chore `id` is.
func _progress(id: StringName) -> int:
	match id:
		&"care":
			var coop := _coop()
			if coop == null:
				return 0
			return int(_count("fed") > 0 or _well_filled(coop.housing.feed)) + int(_count("watered") > 0 or _well_filled(coop.housing.water))
		&"pet":
			var n := 0
			for a: AnimalData in Animals.animals:
				if a.petted_today:
					n += 1
			return n
	return _count(String(id))


## Whether there is anything to do for chore `id` now.
func _available(id: StringName) -> bool:
	match id:
		&"eggs":
			return _eggs_lying() > 0
		&"care":
			return _coop() != null
		&"pet":
			return not Animals.animals.is_empty()
	return true


static func _well_filled(trough: Trough) -> bool:
	return trough == null or trough.amount >= trough.capacity * CARE_FULL


## The newest finished coop (the one the story's hens live in), or null.
func _coop() -> ChickenCoop:
	var coop := Quests._newest_coop()
	return coop if coop != null and coop.is_built() and coop.housing != null else null


## Eggs lying about to be picked up.
func _eggs_lying() -> int:
	var n := 0
	for p in get_tree().get_nodes_in_group(&"pickups"):
		var pk := p as Pickup
		if pk and not pk.is_queued_for_deletion() and pk.stack and pk.stack.item.id == &"egg":
			n += pk.stack.count
	return n


## What chore `id`'s card says and where its dot points.
func _show(id: StringName) -> void:
	var g: SideGoal = _goals[id]
	var key := String(id).to_upper()
	var text := tr("SIDE_GOAL_FARM_" + key)
	if text.contains("%d"):
		text = text % [mini(_progress(id), _need(id)), _need(id)]
	g.set_goal(text, tr("SIDE_HINT_FARM_" + key), _point(id))


## Where chore `id` is done: the bin, the nearest egg, the trough still to fill, the
## nearest hen not petted yet, the nearest tree or rock (or what lies about of them).
func _point(id: StringName) -> Variant:
	var p := Game.player as Node3D
	var from := p.global_position if p and is_instance_valid(p) else Vector3.ZERO
	match id:
		&"bin":
			return Quests._target("bin")
		&"eggs":
			return Quests._nearest_pickup(&"egg", from, 400.0)
		&"care":
			var coop := _coop()
			if coop == null:
				return null
			var feed_done := _count("fed") > 0 or _well_filled(coop.housing.feed)
			return WaypointMarker.anchor(ChickenCoop.ANCHOR_WATER if feed_done else ChickenCoop.ANCHOR_FEEDER)
		&"pet":
			var best: Animal = null
			var best_d := INF
			for a: AnimalData in Animals.animals:
				var n := Animals.node_of(a)
				if n == null or a.petted_today or not n.is_inside_tree():
					continue
				var d := n.global_position.distance_squared_to(from)
				if d < best_d:
					best = n
					best_d = d
			return best
		&"wood":
			var logs: Variant = Quests._nearest_pickup(&"wood", from, 30.0)
			return logs if logs != null else Quests._nearest_tree(from)
		&"stones":
			var chips: Variant = Quests._nearest_pickup(&"stone", from, 30.0)
			return chips if chips != null else Quests._nearest_rock(from)
	return null


## Chore `id` done: a note, a little farm experience, its card goes.
func _complete(id: StringName) -> void:
	if done.has(id):
		return
	var g: SideGoal = _goals[id]
	_show(id)
	done[id] = true
	Progress.add(int(XP[id]))
	Game.notify(tr("MSG_SIDE_DONE") % g.text, UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	SideStory.remove_goal(g)
	_poll = 0.0


# --- Save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"day": day, "done": done.keys().map(func(k: StringName) -> String: return String(k)),
		"counts": counts.duplicate(), "told": told}


func load_data(data: Dictionary) -> void:
	day = int(data.get("day", 0))
	done = {}
	for id: Variant in data.get("done", []):
		done[StringName(id)] = true
	counts = (data.get("counts", {}) as Dictionary).duplicate()
	told = bool(data.get("told", false))
	_take_down()
	_poll = 0.0
