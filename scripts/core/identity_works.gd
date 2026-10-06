class_name IdentityWorks
extends Node
## Lives in the farm (FarmIdentity.setup) and looks after what the farmer made his own:
##
##   - the colours stay on: every POLL it puts the saved paint back on the farmhouse, the
##     kit coops, the doghouses, the mailboxes and the name board's frame (Painter.apply:
##     nothing to do when it is on already), and at once when the house is repaired or
##     grows a level, a coop is made longer or something is finished. So a load, an
##     upgrade or an expansion (their meshes are built anew) never loses a colour.
##   - the quiet side goal "Add some colour to your home" (SideGoal, like the dog's): up
##     once the house is repaired, its dot on the town market until a can of paint is in
##     the bag (short of its price: how much more, and where to earn it), then on the
##     house; done the first time the house is painted (a little farm experience, and a
##     line on the decorations the market sells too).
##   - the one-line hint the first time a decoration is in hand.
##
## Automated runs keep the goal away unless the run asks for it (`--paint-goal`, or
## `testing`). `--paint-all=<colour>` paints every placed thing that takes paint (shots).

const GROUP := &"identity_works"
const POLL := 0.5
const GOAL_XP := 5
const GOAL_COLOR := Color("e2b98a")
const COUNTER_LIFT := 1.5

## Set by tests: the side goal comes up in this automated run.
var testing := false

var _poll := 0.0
var _goal: SideGoal
var _goal_told := false
## The name and the last colour as last seen: a load or a debug shot changes them without
## telling anyone.
var _seen := ""


func _ready() -> void:
	add_to_group(GROUP)
	_goal = SideGoal.new(&"paint_house", tr("SIDE_PAINT_TITLE"), "home", GOAL_COLOR)
	_goal.quiet = true
	FarmState.project_built.connect(_on_built)
	Events.building_completed.connect(func(_id: StringName, _b: Node) -> void: _soon())
	Events.placed.connect(func(_id: StringName) -> void: _soon())
	apply_all.call_deferred()


func _exit_tree() -> void:
	if _goal != null:
		SideStory.remove_goal(_goal)


func _on_built(_id: StringName) -> void:
	# The farm rebuilds the house in its own handler: the colours go back on after it.
	apply_all.call_deferred()


func _soon() -> void:
	apply_all.call_deferred()


func _process(delta: float) -> void:
	if SaveGame.loading:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	var now := "%s|%s|%s" % [FarmIdentity.farm_name(), FarmIdentity.is_named(), FarmIdentity.last_color()]
	if now != _seen:
		if _seen != "":
			FarmIdentity.notify_changed(&"name")
			FarmIdentity.notify_changed(&"paint")
		_seen = now
	apply_all()
	if Game.player == null or not is_instance_valid(Game.player):
		return
	_update_goal()
	_decor_hint()


## Puts every saved colour on its building (the ones on already are left alone).
func apply_all() -> void:
	if not is_inside_tree():
		return
	for part: String in ["house_walls", "house_trim"]:
		var s := Painter.house_spec(part)
		if not s.is_empty():
			Painter.apply(null, s)
	var board := FarmIdentity.board()
	if board:
		Painter.apply(board)
	# (`--paint-all=<colour>`: a debug shot's placed things wear that colour.)
	var all := String(DebugTools.args.get("paint-all", ""))
	for n: Node in get_tree().get_nodes_in_group(&"placed"):
		if not n is PlacedObject or n.is_queued_for_deletion():
			continue
		var e: Dictionary = (n as PlacedObject).entry
		if all != "" and not e.has("paint") and not Painter.spec(n).is_empty():
			e["paint"] = all
		if e.has("paint"):
			Painter.apply(n)


## Something was painted by hand (Painter.complete_use): the side goal hears of the house.
func painted(_node: Node, part: String) -> void:
	if part.begins_with("house_"):
		_poll = 0.0


# --- The quiet goal: add some colour to your home ----------------------------------------------

func goal_enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("paint-goal")


## The side goal's card (tests).
func goal() -> SideGoal:
	return _goal


func goal_up() -> bool:
	return SideStory.goals.has(_goal)


func goal_done() -> bool:
	return bool(FarmState.flags.get(FarmIdentity.PAINT_GOAL_FLAG, false))


func _house_painted() -> bool:
	return FarmIdentity.part_color("house_walls") != &"" or FarmIdentity.part_color("house_trim") != &""


func _update_goal() -> void:
	if goal_done() or not goal_enabled() or FarmState.house_level() < 1:
		SideStory.remove_goal(_goal)
		return
	if _house_painted():
		FarmState.flags[FarmIdentity.PAINT_GOAL_FLAG] = true
		Progress.add(GOAL_XP)
		Game.notify(tr("MSG_SIDE_DONE") % tr("SIDE_GOAL_PAINT"), UiTheme.GOLD)
		# And what else the market has for a farm of his own.
		Game.notify(tr("MSG_DECOR_TIP"), GOAL_COLOR)
		Audio.ui("confirm", -6.0)
		SideStory.remove_goal(_goal)
		return
	# The first day's story has the yard to itself: the card comes up with the free evening.
	if Quests.first_day() and not Quests.day_work_done():
		return
	var has_can := false
	for c: StringName in FarmIdentity.COLOR_ORDER:
		if PlayerState.inventory.has_item(FarmIdentity.paint_item(c)):
			has_can = true
			break
	if has_can:
		var house := get_tree().get_first_node_in_group(&"farm_house") as FarmHouse
		_goal.set_goal(tr("SIDE_GOAL_PAINT"), tr("SIDE_HINT_PAINT_HOUSE"), house.door_point() if house else null, tr("SIDE_LABEL_HOUSE"))
	else:
		var town := get_tree().get_first_node_in_group(&"town") as Town
		var counter: Variant = town.market_counter.global_position + Vector3(0.0, COUNTER_LIFT, 0.0) if town and town.market_counter else null
		var hint := tr("SIDE_HINT_PAINT_BUY")
		var label := tr("UI_TOWN_MARKET")
		var price := Economy.buy_price(FarmIdentity.paint_item(FarmIdentity.DEFAULT_COLOR))
		if Economy.money < price:
			var short: Dictionary = Quests.money_short(price)
			hint = String(short["hint"])
			counter = short["at"]
			label = ""
		_goal.set_goal(tr("SIDE_GOAL_PAINT"), hint, counter, label if counter != null else "")
	if not goal_up():
		SideStory.add_goal(_goal)
		if not _goal_told:
			_goal_told = true
			Game.notify(tr("MSG_SIDE_NEW") % tr("SIDE_GOAL_PAINT"), GOAL_COLOR)
			Audio.ui("notify", -8.0)


# --- Decorations --------------------------------------------------------------------------------

## The first time a decoration is in hand: one line on how it is put down and taken back.
func _decor_hint() -> void:
	if bool(FarmState.flags.get(FarmIdentity.DECOR_HINT_FLAG, false)) or DebugTools.is_automated() and not testing:
		return
	var stack := PlayerState.selected_stack()
	if stack == null or stack.item.id not in FarmIdentity.DECOR:
		return
	FarmState.flags[FarmIdentity.DECOR_HINT_FLAG] = true
	Game.notify(tr("HINT_DECOR_PLACE"), GOAL_COLOR)
