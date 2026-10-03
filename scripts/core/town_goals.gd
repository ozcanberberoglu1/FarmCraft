class_name TownGoals
extends Node
## Day two's quiet side goals: getting to know Yeşilova while the story's goals leave the
## player free. They come up on day two once he first reaches town (UP_MINUTE at the
## latest), each on a compact card with a small, faint dot (SideGoal.quiet), give a little
## farm experience when done (XP), never stand in the story's way, and quietly go after
## LAST_DAY if left undone:
##
##   meet   "Get to know the townspeople": greet MEET_COUNT different townspeople with E
##          (Relations counts greetings; anyone greeted before counts too). In town the
##          dot shows the nearest one not met yet.
##   vet    "Drop in on Dr. Selin": E on her or her counter while it is up starts a short
##          talk instead of her screen (wolves come down at night; a hurt animal goes to
##          her straight away).
##   fuel   "Fill up the pickup": at a pump of the filling station (Town._refuel tells).
##
## SideStory owns it (SideStory.town_goals) and saves it. Automated runs keep it away
## unless the run asks for it (`--town-goals`, or `testing`).

const DAY := 2
const LAST_DAY := 4
const UP_MINUTE := 12 * 60
const MEET_COUNT := 5
const GOALS: Array[StringName] = [&"meet", &"vet", &"fuel"]
const XP := {&"meet": 8, &"vet": 5, &"fuel": 5}
const GLYPHS := {&"meet": "smile", &"vet": "health", &"fuel": "fuel"}
const COLOR := Color("a8d8a0")
## The player is in town this close to its square (flat metres).
const IN_TOWN := 80.0
## The dot floats this high over a townsperson's feet, over a pump's middle.
const PERSON_LIFT := 2.15
const PUMP_LIFT := 1.4
const POLL := 0.5

## Saved: the goals came up; the ones done (id -> true).
var up := false
var done := {}
## Set by tests: the goals come up in this automated run.
var testing := false

var _goals := {}
var _poll := 0.0


func _ready() -> void:
	for id: StringName in GOALS:
		var g := SideGoal.new(StringName("town_" + String(id)), tr("SIDE_TOWN_TITLE"), GLYPHS[id], COLOR)
		g.quiet = true
		_goals[id] = g


func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("town-goals")


func goal(id: StringName) -> SideGoal:
	return _goals.get(id)


## The goal `id` is on the HUD now.
func is_up(id: StringName) -> bool:
	return SideStory.goals.has(goal(id))


## How many townspeople the player has greeted (met) so far.
static func met_count() -> int:
	var n := 0
	for who: StringName in Relations.greeted:
		if Relations.TOWN_GIFTS.has(who):
			n += 1
	return n


func _in_town() -> bool:
	return Carnival.town_distance() < IN_TOWN


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	update()


## Puts the goals up when their day comes, keeps their cards and dots up to date, and
## takes them down once done or past their days.
func update() -> void:
	var day := GameClock.day
	if not enabled() or day < DAY or day > LAST_DAY:
		_take_down()
		return
	if not up:
		if day == DAY and not _in_town() and SideStory.day_minute() < UP_MINUTE:
			return
		up = true
		Game.notify(tr("MSG_TOWN_GOALS_NEW"), COLOR)
		Audio.ui("notify", -8.0)
	for id: StringName in GOALS:
		var g: SideGoal = _goals[id]
		if done.has(id):
			SideStory.remove_goal(g)
			continue
		if id == &"meet" and met_count() >= MEET_COUNT:
			_show_goal(id)
			_complete(id)
			continue
		SideStory.add_goal(g)
		_show_goal(id)


func _take_down() -> void:
	for id: StringName in GOALS:
		SideStory.remove_goal(_goals[id])


## What goal `id`'s card says and where its dot points.
func _show_goal(id: StringName) -> void:
	var g: SideGoal = _goals[id]
	var town := get_tree().get_first_node_in_group(&"town") as Town
	match id:
		&"meet":
			var who: Townsperson = _nearest_stranger() if _in_town() else null
			g.set_goal(tr("SIDE_GOAL_TOWN_MEET") % [mini(met_count(), MEET_COUNT), MEET_COUNT], tr("SIDE_HINT_TOWN_MEET"),
					who.global_position + Vector3(0.0, PERSON_LIFT, 0.0) if who else null,
					tr("PERSON_" + String(who.person).to_upper()) if who else "")
		&"vet":
			var clinic: VetClinic = town.vet_clinic if town else null
			var open := clinic != null and clinic.staffed
			g.set_goal(tr("SIDE_GOAL_TOWN_VET"), tr("SIDE_HINT_TOWN_VET") if open else tr("SIDE_HINT_TOWN_VET_CLOSED"),
					clinic.counter.waypoint_point() if clinic else null, tr("PERSON_VET"))
		&"fuel":
			var pump: Vector3 = town.pumps[0].global_position + Vector3(0.0, PUMP_LIFT, 0.0) if town and not town.pumps.is_empty() else Vector3.INF
			g.set_goal(tr("SIDE_GOAL_TOWN_FUEL"), tr("SIDE_HINT_TOWN_FUEL"), pump if pump.is_finite() else null,
					tr("SIDE_LABEL_STATION"))


## The nearest townsperson the player hasn't greeted yet (null: none about).
func _nearest_stranger() -> Townsperson:
	var p := Game.player as Node3D
	var best: Townsperson = null
	var best_d := INF
	for n: Node in get_tree().get_nodes_in_group(Townsperson.GROUP):
		var t := n as Townsperson
		if t == null or not Relations.TOWN_GIFTS.has(t.person) or Relations.greeted.has(t.person) or not t.is_visible_in_tree():
			continue
		var d := t.global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best


## Goal `id` done: a note, a little farm experience, its card goes.
func _complete(id: StringName) -> void:
	if done.has(id):
		return
	var g: SideGoal = _goals[id]
	done[id] = true
	Progress.add(int(XP[id]))
	Game.notify(tr("MSG_SIDE_DONE") % g.text, UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	SideStory.remove_goal(g)


## The pickup was filled up at the filling station (Town._refuel).
func note_refuel() -> void:
	if is_up(&"fuel"):
		_complete(&"fuel")


## E at the vet's counter (or on her) while "drop in on Dr. Selin" is up and she is there:
## a short talk about the wolves and hurt animals instead of her screen, and the goal is
## done. False: nothing to say (her screen opens as usual).
func vet_hello(vet: Townsperson) -> bool:
	if not is_up(&"vet") or vet == null or not is_instance_valid(vet) or vet.away or not vet.is_visible_in_tree():
		return false
	var hud := Game.hud as HUD
	if hud == null or hud.dialogue_screen == null:
		return false
	if hud.dialogue_screen.is_open():
		return true
	var talk: Array = []
	for l: Array in [[&"vet", "VET_HELLO_1"], [&"player", "VET_HELLO_PLAYER"], [&"vet", "VET_HELLO_2"], [&"vet", "VET_HELLO_3"]]:
		var text := tr(String(l[1]))
		var line := {"who": l[0], "text": text}
		if l[0] == &"vet":
			line["cue"] = func() -> void:
				if is_instance_valid(vet):
					vet.talk(clampf(text.length() / 16.0, 1.2, 6.0))
		talk.append(line)
	hud.dialogue_screen.open(talk, func() -> void: _complete(&"vet"), vet)
	return true


# --- Save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"up": up, "done": done.keys().map(func(k: StringName) -> String: return String(k))}


func load_data(data: Dictionary) -> void:
	up = bool(data.get("up", false))
	done = {}
	for id: Variant in data.get("done", []):
		done[StringName(id)] = true
	_take_down()
	_poll = 0.0
