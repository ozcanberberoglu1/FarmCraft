extends Node
## Achievements: firsts the player reaches on a farm (the first harvest, the first
## building...). Each unlocks once per game, gives a little farm experience, shows the
## HUD's toast (AchievementToast listens to Events.achievement_unlocked) and stays in
## the save. They unlock from the event bus, so nothing that earns one has to know about
## it; Achievements.unlock(id) works from anywhere too. Old saves get what their farm
## has done already, silently.

## id -> "icon": a UI glyph (art/icons/ui2) drawn in gold, or "item": an item whose own
## icon it shows; "xp": the farm experience it gives. Title and line: ACH_<ID> and
## ACH_<ID>_DESC.
const LIST := {
	&"first_harvest": {"icon": "wheat", "xp": 10},
	&"first_building": {"icon": "hammer", "xp": 15},
	&"first_chickens": {"icon": "paw", "xp": 10},
	&"first_egg": {"item": &"egg", "xp": 5},
	&"first_sale": {"icon": "tag", "xp": 5},
	&"first_night": {"icon": "moon", "xp": 5},
	# The fishing contest won (FishingContest).
	&"best_angler": {"item": &"fish_carp", "xp": 20},
}
## The order they come in on the first day (for a list of them).
const ORDER: Array[StringName] = [&"first_harvest", &"first_building", &"first_chickens",
	&"first_egg", &"first_sale", &"first_night"]

## Unlocked achievements: id -> the game day each came on.
var unlocked := {}
## A save from before achievements: what its farm has done counts once it is up.
var _backfill := false


func _ready() -> void:
	Events.action_done.connect(func(id: String, _t: Node) -> void:
		if id == "harvest":
			unlock(&"first_harvest"))
	Events.building_completed.connect(func(_id: StringName, _b: Node) -> void: unlock(&"first_building"))
	Events.animal_released.connect(func(species: StringName, _home: Node) -> void:
		if species == &"chicken":
			unlock(&"first_chickens"))
	Events.item_picked_up.connect(func(id: StringName, _n: int) -> void:
		if id == &"egg":
			unlock(&"first_egg"))
	Events.morning_sale.connect(func(gold: int) -> void:
		if gold > 0:
			unlock(&"first_sale"))
	# Only sleeping starts a day (GameClock.sleep_to_next_morning).
	Events.day_started.connect(func(day: int) -> void:
		if day > 1:
			unlock(&"first_night"))
	SaveGame.loaded.connect(func(_slot: String) -> void: _run_backfill())


## Unlocks `id` once: its farm experience and its toast (neither when `quiet`). False
## when it was unlocked already, doesn't exist, or a game is being loaded.
func unlock(id: StringName, quiet := false) -> bool:
	if unlocked.has(id) or not LIST.has(id) or SaveGame.loading:
		return false
	unlocked[id] = GameClock.day
	if not quiet:
		Progress.add(int((LIST[id] as Dictionary).get("xp", 0)))
		Events.achievement_unlocked.emit(id)
	return true


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func title(id: StringName) -> String:
	return tr("ACH_%s" % String(id).to_upper())


func description(id: StringName) -> String:
	return tr("ACH_%s_DESC" % String(id).to_upper())


## The achievement's picture: an item's icon, else its UI glyph.
func icon(id: StringName) -> Texture2D:
	var info: Dictionary = LIST.get(id, {})
	if info.has("item"):
		var item := ItemDB.get_item(StringName(info["item"]))
		if item and item.icon:
			return item.icon
	return UiTheme.glyph(String(info.get("icon", "star")))


## True when the icon is a line glyph (drawn tinted), false for an item's coloured icon.
func icon_is_glyph(id: StringName) -> bool:
	var info: Dictionary = LIST.get(id, {})
	return not info.has("item")


## Old saves: what the loaded farm has done already counts, without toasts or
## experience. Runs once the world is up (animals and plots are restored by then).
func _run_backfill() -> void:
	if not _backfill:
		return
	_backfill = false
	if GameClock.day > 1:
		unlock(&"first_night", true)
	for id: StringName in FarmState.built:
		if String(ProjectTable.get_project(id).get("group", "")) == "animals":
			unlock(&"first_building", true)
	if Animals.animals.any(func(a: AnimalData) -> bool: return a.species == &"chicken"):
		unlock(&"first_chickens", true)
	if int(Quests.tally.get("action:harvest", 0)) > 0:
		unlock(&"first_harvest", true)
	if int(Quests.tally.get("picked:egg", 0)) > 0:
		unlock(&"first_egg", true)


func new_game() -> void:
	unlocked.clear()
	_backfill = false


func save_data() -> Dictionary:
	var days := {}
	for id: StringName in unlocked:
		days[String(id)] = int(unlocked[id])
	return {"unlocked": days.keys(), "days": days}


func load_data(d: Dictionary) -> void:
	unlocked.clear()
	var days: Dictionary = d.get("days", {})
	for k: Variant in d.get("unlocked", []):
		unlocked[StringName(str(k))] = int(days.get(str(k), 0))
	# Saves from before achievements have none: work them out once the world is up.
	_backfill = d.is_empty()
