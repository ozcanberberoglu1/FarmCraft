extends Node
## How well the player gets on with the townspeople he befriends (hearts): Zeynep, the
## new neighbour, so far (SideStory). Friendship is counted in points, POINTS_PER_LEVEL
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
}
const POINTS_PER_LEVEL := 10
## What a heart's note looks like.
const NOTE_COLOR := Color("f59ac8")

## id -> points (only people met: a missing id is 0).
var points := {}


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


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	var out := {}
	for who: StringName in points:
		out[String(who)] = int(points[who])
	return {"points": out}


func load_data(data: Dictionary) -> void:
	points = {}
	var saved: Dictionary = data.get("points", {})
	for who: String in saved:
		if PEOPLE.has(StringName(who)):
			points[StringName(who)] = clampi(int(saved[who]), 0, max_level(StringName(who)) * POINTS_PER_LEVEL)
	for who: StringName in PEOPLE:
		changed.emit(who, level(who), points_of(who))
