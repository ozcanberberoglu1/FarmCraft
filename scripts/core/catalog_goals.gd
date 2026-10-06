class_name CatalogGoals
extends Node
## The quiet side goals that teach the market's catalogue (Catalog owns it, Catalog.goals,
## and saves it): one at a time on a compact card with a small, faint dot (SideGoal.quiet),
## a little farm experience when done (XP). They never stand in the story's way:
##
##   order    "The catalogue is here: place an order from your mailbox": up the morning
##            Hasan's catalogue comes (the dot shows the mailbox; the hint: E, then the
##            Catalogue page). Done when the first order is written and paid for: its
##            done line says it will be at the door in the morning (note_order).
##   collect  "Collect your order from the delivery crate": up the morning the first crate
##            stands by the mailbox (the dot shows the crate). Done when it is opened and
##            something is taken out.
##
## Automated runs keep them away unless the run asks for the catalogue (Catalog.enabled).

const GOALS: Array[StringName] = [&"order", &"collect"]
const XP := {&"order": 4, &"collect": 4}
const GLYPH := "book"
const COLOR := Color("e2b877")
## The dot floats this high over the mailbox's foot, over the crate's.
const BOX_LIFT := 1.55
const CRATE_LIFT := 0.95
const POLL := 0.5

## Saved: the first goal came up (the farmer was told); the ones done (id -> true).
var up := false
var done := {}
var catalog: Catalog

var _goal: SideGoal
var _poll := 0.0


func _ready() -> void:
	_goal = SideGoal.new(&"catalog", tr("CATALOG_TAB"), GLYPH, COLOR)
	_goal.quiet = true


## The goal whose turn it is (&"" once all are done).
func current() -> StringName:
	for id: StringName in GOALS:
		if not done.has(id):
			return id
	return &""


## The card.
func goal() -> SideGoal:
	return _goal


## The goal `id` is on the HUD now.
func is_up(id: StringName) -> bool:
	return SideStory.goals.has(_goal) and current() == id


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
	var id := current()
	if catalog == null or not catalog.enabled() or id == &"" or not catalog.available():
		_take_down()
		return
	if _met(id):
		_show(id)
		_complete(id)
		return
	if id == &"collect" and not catalog.has_crate():
		# Written and on its way: nothing to do until the crate stands by the mailbox.
		_take_down()
		return
	_show(id)
	if not SideStory.goals.has(_goal):
		SideStory.add_goal(_goal)
		Game.notify(tr("MSG_SIDE_NEW") % _goal.text, COLOR)
		if not up:
			up = true
			Audio.ui("notify", -8.0)


func _take_down() -> void:
	if _goal != null:
		SideStory.remove_goal(_goal)


## Whether goal `id` is met now.
func _met(id: StringName) -> bool:
	match id:
		&"order":
			return catalog.placed > 0
		&"collect":
			return catalog.collected > 0
	return false


## What goal `id`'s card says and where its dot points.
func _show(id: StringName) -> void:
	match id:
		&"order":
			var box := catalog.mailbox()
			_goal.set_goal(tr("SIDE_GOAL_CATALOG_ORDER"), tr("SIDE_HINT_CATALOG_ORDER"),
					box.global_position + Vector3(0.0, BOX_LIFT, 0.0) if box else null, tr("SIDE_MAILBOX_TITLE") if box else "")
		&"collect":
			var crate := catalog.crate_node()
			_goal.set_goal(tr("SIDE_GOAL_CATALOG_COLLECT"), tr("SIDE_HINT_CATALOG_COLLECT"),
					crate.global_position + Vector3(0.0, CRATE_LIFT, 0.0) if crate else null, tr("UI_DELIVERY_CRATE") if crate else "")


## An order was just written, `line` saying when it comes ("at your door tomorrow
## morning"). True when that was the first goal's doing: it is done, with `line` as its done
## line (the catalogue then says nothing more itself).
func note_order(line: String) -> bool:
	if catalog == null or not catalog.enabled() or current() != &"order":
		return false
	_complete(&"order", line)
	return true


## Goal `id` done: its done line (`line`, else its own), a little farm experience; the
## next one's turn.
func _complete(id: StringName, line := "") -> void:
	if done.has(id):
		return
	done[id] = true
	Progress.add(int(XP[id]))
	Game.notify(tr("MSG_SIDE_DONE") % (line if line != "" else tr("SIDE_DONE_CATALOG_" + String(id).to_upper())), UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	SideStory.remove_goal(_goal)
	_poll = 1.5


# --- Save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"up": up, "done": done.keys().map(func(k: StringName) -> String: return String(k))}


func load_data(data: Dictionary) -> void:
	_take_down()
	up = bool(data.get("up", false))
	done = {}
	for id: Variant in data.get("done", []):
		done[StringName(id)] = true
	_poll = 0.0
