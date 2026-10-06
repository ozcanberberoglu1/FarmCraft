class_name PastureGoals
extends Node
## The quiet side goals that teach the farmer to fence a pasture of his own (Pastures owns
## it, Pastures.goals). They come up once he has an animal that grazes (a sheep, a cow, a
## horse) with a line from Grandpa's notebook ("Animals love to graze, son: fence them a
## pasture"), one at a time, each on a compact card with a small, faint dot
## (SideGoal.quiet) and a little farm experience when done (XP). Never in the story's way:
##
##   craft    "Make 8 fence panels and a gate at the workbench": the card counts them
##            against what he has (in the bag and standing: SideGoal.needs); the dot shows
##            the workbench, the hint what they take.
##   fence    "Set the panels out and close the loop with the gate": done when Pastures
##            recognises a pasture. The dot shows a good spot by the barn pen's gateway
##            until the first piece stands; the hint explains snapping and holding LMB.
##   graze    "Lead your animal to the pasture on the halter (G) and let it go": done when
##            one grazes in a pasture (walked in by itself from the barn's pen counts).
##            The dot follows the animal, then shows the pasture's gate.
##   lantern  "Put up a lantern post: it keeps the wolves off at night": done when one
##            stands. The dot shows the workbench until one is in the bag.
##
## One met already when its turn comes is ticked off at once. What is done is kept in
## FarmState.flags (FLAG), so it is saved with the farm. Automated runs keep them away
## unless the run asks for them (`--pasture-goals`, or `testing`).

const GOALS: Array[StringName] = [&"craft", &"fence", &"graze", &"lantern"]
const XP := {&"craft": 4, &"fence": 8, &"graze": 6, &"lantern": 6}
const GLYPH := "wheat"
const COLOR := Color("a9d67e")
## What the first pasture takes.
const PANELS := 8
const GATES := 1
## The dot floats this high over the spot by the barn pen, the workbench's own anchor
## and a gate.
const SPOT_LIFT := 1.4
const SPOT_OUT := 4.5
const FLAG := "pasture_goals"
const POLL := 0.5

## Set by tests: the goals come up in this automated run.
var testing := false

var _goal: SideGoal
var _poll := 0.0


func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("pasture-goals")


## What is saved: {"up": the first goal came up, "done": {id: true}}.
func _state() -> Dictionary:
	if not FarmState.flags.has(FLAG):
		FarmState.flags[FLAG] = {"up": false, "done": {}}
	return FarmState.flags[FLAG]


func is_done(id: StringName) -> bool:
	return (_state()["done"] as Dictionary).has(String(id))


## The goal whose turn it is (&"" once all are done).
func current() -> StringName:
	for id: StringName in GOALS:
		if not is_done(id):
			return id
	return &""


func goal() -> SideGoal:
	return _goal


## The goal `id` is on the HUD now.
func is_up(id: StringName) -> bool:
	return _goal != null and SideStory.goals.has(_goal) and current() == id


## The farmer has an animal that grazes.
func has_grazer() -> bool:
	for a: AnimalData in Animals.animals:
		if not AnimalTable.is_poultry(a.species):
			return true
	return false


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	update()


## Puts the goal whose turn it is on its card, keeps the card and the dot up to date and
## ticks it off when it is met.
func update() -> void:
	var id := current()
	if not enabled() or id == &"" or not (has_grazer() or bool(_state()["up"])):
		_take_down()
		return
	if _goal == null:
		_goal = SideGoal.new(&"pasture", tr("PASTURE_GOALS_TITLE"), GLYPH, COLOR)
		_goal.quiet = true
	_show(id)
	if not bool(_state()["up"]):
		_state()["up"] = true
		Game.notify(tr("MSG_PASTURE_NOTE"), COLOR)
		Audio.ui("notify", -8.0)
	if _met(id):
		_complete(id)
		return
	SideStory.add_goal(_goal)


func _take_down() -> void:
	if _goal != null:
		SideStory.remove_goal(_goal)


## Panels (or gates) he has: in the bag and standing on the farm.
func _have(item: StringName) -> int:
	var n := PlayerState.inventory.count_item(item)
	for e: Dictionary in FarmState.placed:
		if StringName(e.get("id", "")) == item:
			n += 1
	return n


func _standing(item: StringName) -> int:
	return _have(item) - PlayerState.inventory.count_item(item)


## Whether goal `id` is met now.
func _met(id: StringName) -> bool:
	match id:
		&"craft":
			return (_have(&"fence_panel") >= PANELS and _have(&"fence_gate") >= GATES) or not Pastures.pastures.is_empty()
		&"fence":
			return not Pastures.pastures.is_empty()
		&"graze":
			return not Pastures.grazing().is_empty()
		&"lantern":
			return _standing(&"lantern_post") > 0
	return false


## What goal `id`'s card says and where its dot points.
func _show(id: StringName) -> void:
	var bench: Variant = WaypointMarker.anchor(Workbench.ANCHOR)
	match id:
		&"craft":
			_goal.set_needs("%s · %s" % [
				Quests.need_part(ItemDB.get_item(&"fence_panel").display_name(), _have(&"fence_panel"), PANELS),
				Quests.need_part(ItemDB.get_item(&"fence_gate").display_name(), _have(&"fence_gate"), GATES)])
			_goal.set_goal(tr("PASTURE_GOAL_CRAFT") % [PANELS, GATES], tr("PASTURE_HINT_CRAFT") if bench != null else tr("PASTURE_HINT_NO_BENCH"),
					bench, tr("ITEM_WORKBENCH") if bench != null else "")
		&"fence":
			var standing := _standing(&"fence_panel") + _standing(&"fence_gate")
			_goal.set_needs(tr("PASTURE_NEEDS_FENCE") % [_standing(&"fence_panel"), _standing(&"fence_gate"), GATES] if standing > 0 else "")
			var where: Variant = spot() if standing == 0 else null
			_goal.set_goal(tr("PASTURE_GOAL_FENCE"), tr("PASTURE_HINT_FENCE"), where, tr("PASTURE_LABEL_SPOT") if where != null else "")
		&"graze":
			_goal.set_needs("")
			var animal := _animal()
			var where: Variant = animal
			var label := animal.data.name if animal != null else ""
			var player := Game.player as Player
			if animal == null or (player != null and player.handler != null and player.handler.led != null):
				# On the halter already: the pasture's gate.
				where = _gate_point()
				label = tr("PASTURE_NAME") if where != null else ""
			_goal.set_goal(tr("PASTURE_GOAL_GRAZE"), tr("PASTURE_HINT_GRAZE"), where, label)
		&"lantern":
			var have := PlayerState.inventory.count_item(&"lantern_post")
			_goal.set_needs(Quests.need_part(ItemDB.get_item(&"lantern_post").display_name(), have, 1) if have == 0 else "")
			var where: Variant = bench if have == 0 else _gate_point()
			var label := (tr("ITEM_WORKBENCH") if have == 0 else tr("PASTURE_NAME")) if where != null else ""
			_goal.set_goal(tr("PASTURE_GOAL_LANTERN"), tr("PASTURE_HINT_LANTERN_CRAFT") if have == 0 else tr("PASTURE_HINT_LANTERN"), where, label)


## A good place for the first pasture: the ground in front of the barn pen's gateway (the
## barn's animals then walk out into it by themselves).
static func spot() -> Vector3:
	var p := WorldLayout.gate_point(WorldLayout.BARN_PEN, WorldLayout.BARN_GATE, SPOT_OUT)
	return Vector3(p.x, TerrainData.height(p.x, p.z) + SPOT_LIFT, p.z)


## The grazing animal nearest the farmer that is not at pasture yet (null when none).
func _animal() -> Animal:
	var player := Game.player as Node3D
	var best: Animal = null
	var best_d := INF
	for a: AnimalData in Animals.animals:
		var n := Animals.node_of(a)
		if n == null or not n.is_inside_tree() or AnimalTable.is_poultry(a.species) or n.ridden or Pastures.is_grazing(n):
			continue
		var d := n.global_position.distance_squared_to(player.global_position) if player else 0.0
		if d < best_d:
			best = n
			best_d = d
	return best


## Over the first pasture's gate (null when there is no pasture).
func _gate_point() -> Variant:
	if Pastures.pastures.is_empty():
		return null
	var gates: Array = Pastures.pastures[0]["gates"]
	if gates.is_empty() or not is_instance_valid(gates[0]):
		return null
	return (gates[0] as FencePiece).global_position + Vector3(0, SPOT_LIFT + 0.4, 0)


## Goal `id` done: a note, a little farm experience; the next one's turn.
func _complete(id: StringName) -> void:
	if is_done(id):
		return
	(_state()["done"] as Dictionary)[String(id)] = true
	Progress.add(int(XP[id]))
	Game.notify(tr("MSG_SIDE_DONE") % _goal.text, UiTheme.GOLD)
	Audio.ui("confirm", -6.0)
	SideStory.remove_goal(_goal)
	if current() == &"":
		Game.notify(tr("MSG_PASTURE_GOALS_DONE"), COLOR)
	_poll = 1.5
