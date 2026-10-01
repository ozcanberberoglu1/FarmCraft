extends Node
## How well the player gets on with the townspeople he befriends (hearts): Zeynep, the
## new neighbour (SideStory), and Yeşilova's townspeople (TownPeople), whom a greeting
## with E befriends a little (GREET_POINTS, once a day each: greet); on a greeting after
## a new heart they give a small gift (TOWN_GIFTS: a line in their bubble and a note, the
## things into the bag). Friendship is counted in points, POINTS_PER_LEVEL
## to a heart, up to the person's number of levels (PEOPLE); meeting and every errand
## done for someone give a whole heart, a friendly chat once a day a little. A heart
## gained says so in a note ("Zeynep and you are getting closer ♥ 2/10"); looking at
## the person shows the hearts on the prompt's title (hearts_text). Saved with the
## game (SaveGame), a new game starts every friendship at nothing.

## A friendship's points or level changed (`who`, its level and points now).
signal changed(who: StringName, level: int, points: int)
## A new heart for `who`.
signal leveled_up(who: StringName, level: int)

## The people there is a friendship with: id -> {levels: the most hearts, name: the
## translation key of the name the notes use}.
const PEOPLE := {
	&"zeynep": {"levels": 10, "name": "PERSON_ZEYNEP"},
	&"shopkeeper": {"levels": 5, "name": "PERSON_SHOPKEEPER"},
	&"attendant": {"levels": 5, "name": "PERSON_ATTENDANT"},
	&"salesman": {"levels": 5, "name": "PERSON_SALESMAN"},
	&"rancher": {"levels": 5, "name": "PERSON_RANCHER"},
	&"sweeper": {"levels": 5, "name": "PERSON_SWEEPER"},
	&"elder": {"levels": 5, "name": "PERSON_ELDER"},
	&"teacher": {"levels": 5, "name": "PERSON_TEACHER"},
	&"villager": {"levels": 5, "name": "PERSON_VILLAGER"},
	&"young": {"levels": 5, "name": "PERSON_YOUNG"},
	&"farmer": {"levels": 5, "name": "PERSON_FARMER"},
}
## What each townsperson gives on a greeting after a new heart: [item id, count] (their
## line: GIFT_SAY_<ID>). Things of their trade or their day: the grocer's eggs, the
## attendant's rope, the dealer's spare nails, the stockman's feed, the shop boy's worms,
## Osman Dede's sapling, Nuri Hoca's tomato seeds, Ayşe Teyze's jam, Emre's sweetcorn
## bait, Halil's seed potatoes.
const TOWN_GIFTS := {
	&"shopkeeper": [&"egg", 2], &"attendant": [&"rope", 2], &"salesman": [&"nails", 10],
	&"rancher": [&"feed", 5], &"sweeper": [&"worm", 5], &"elder": [&"sapling", 1],
	&"teacher": [&"tomato_seed", 5], &"villager": [&"jam", 1], &"young": [&"sweetcorn", 5],
	&"farmer": [&"potato_seed", 5],
}
## A day's first greeting adds this much friendship with a townsperson (a heart every
## three days or so of greetings).
const GREET_POINTS := 4
const POINTS_PER_LEVEL := 10
## What a heart's note looks like.
const NOTE_COLOR := Color("f59ac8")

## id -> points (only people met: a missing id is 0).
var points := {}
## Townspeople: id -> the last day a greeting counted; id -> the last level a gift was
## given for.
var greeted := {}
var gifted := {}


func level(who: StringName) -> int:
	return mini(floori(points_of(who) / float(POINTS_PER_LEVEL)), max_level(who))


func max_level(who: StringName) -> int:
	return int((PEOPLE.get(who, {}) as Dictionary).get("levels", 10))


func points_of(who: StringName) -> int:
	return int(points.get(who, 0))


## Whether the friendship with `who` has all its hearts.
func is_max(who: StringName) -> bool:
	return level(who) >= max_level(who)


## Adds `amount` points to the friendship with `who` (capped at its last heart); a new
## heart comes with a note unless `quiet`. Returns the level now.
func raise(who: StringName, amount: int, quiet := false) -> int:
	if amount <= 0 or not PEOPLE.has(who):
		return level(who)
	var before := level(who)
	var cap := max_level(who) * POINTS_PER_LEVEL
	points[who] = mini(points_of(who) + amount, cap)
	var now := level(who)
	changed.emit(who, now, points_of(who))
	if now > before:
		leveled_up.emit(who, now)
		if not quiet:
			Game.notify(tr("MSG_FRIENDSHIP_UP") % [tr(String(PEOPLE[who]["name"])), now, max_level(who)], NOTE_COLOR)
			Audio.ui("confirm", -6.0)
	return now


## "♥♥♡♡♡" style hearts for `who`: full ones for the level, empty ones for the rest.
func hearts_text(who: StringName) -> String:
	var n := level(who)
	return "♥".repeat(n) + "♡".repeat(max_level(who) - n)


## The player greeted townsperson `who` (E): a gift if a heart came since the last one
## (returned as {item id: count}, and marked given), then the day's first greeting adds
## GREET_POINTS. {} when no gift is due.
func greet(who: StringName) -> Dictionary:
	if not TOWN_GIFTS.has(who):
		return {}
	var gift := {}
	var lv := level(who)
	if lv > int(gifted.get(who, 0)):
		gifted[who] = lv
		var g: Array = TOWN_GIFTS[who]
		gift[g[0]] = int(g[1])
	if int(greeted.get(who, -1)) != GameClock.day:
		greeted[who] = GameClock.day
		raise(who, GREET_POINTS)
	return gift


## A gift into the player's bag ({item id: count}, quietly); what doesn't fit drops as a
## pickup at `drop_at` (the player's feet when INF).
func hand_gift(gift: Dictionary, drop_at := Vector3.INF) -> void:
	for id: Variant in gift:
		var item := StringName(id)
		if not ItemDB.has_item(item):
			continue
		var left := PlayerState.inventory.add_item(item, int(gift[id]))
		if left <= 0:
			continue
		var at := drop_at
		if at == Vector3.INF:
			var p := Game.player as Node3D
			if p == null or not is_instance_valid(p) or Game.world == null:
				continue
			at = p.global_position + (-p.global_transform.basis.z * 0.6) + Vector3(0, 0.4, 0)
		Pickup.spawn(ItemStack.create(item, left), at, Vector3.UP * 0.5)
		Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))


## "2× Egg, 5× Feed" for a gift.
static func gift_text(gift: Dictionary) -> String:
	var parts: Array[String] = []
	for id: Variant in gift:
		var item := ItemDB.get_item(StringName(id))
		if item:
			parts.append("%d× %s" % [int(gift[id]), item.display_name()])
	return ", ".join(parts)


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	var out := {}
	for who: StringName in points:
		out[String(who)] = int(points[who])
	var g := {}
	for who: StringName in greeted:
		g[String(who)] = int(greeted[who])
	var gl := {}
	for who: StringName in gifted:
		gl[String(who)] = int(gifted[who])
	return {"points": out, "greeted": g, "gifted": gl}


func load_data(data: Dictionary) -> void:
	points = {}
	var saved: Dictionary = data.get("points", {})
	for who: String in saved:
		if PEOPLE.has(StringName(who)):
			points[StringName(who)] = clampi(int(saved[who]), 0, max_level(StringName(who)) * POINTS_PER_LEVEL)
	greeted = {}
	gifted = {}
	for who: String in (data.get("greeted", {}) as Dictionary):
		greeted[StringName(who)] = int(data["greeted"][who])
	for who: String in (data.get("gifted", {}) as Dictionary):
		gifted[StringName(who)] = int(data["gifted"][who])
	for who: StringName in PEOPLE:
		changed.emit(who, level(who), points_of(who))
