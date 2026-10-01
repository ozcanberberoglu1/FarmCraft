extends Node
## Letters from the town, delivered to the mailbox by the house.
##
## On MAILBOX_DAY at 07:00 a side goal comes up (quiet, like Zeynep's errands): put up a
## mailbox in front of the house. It is made at the workbench (a little wood and nails)
## and put down like the other placeables (scripts/placement/mailbox.gd). From then on
## letters arrive in it: its little red flag goes up, a quiet note says so, and E on it
## opens them (LetterScreen.open_mail: the unread ones first, the read ones in a list).
## A letter may carry a small gift (item ids -> counts), taken out when it is opened (into
## the bag; what doesn't fit drops at the player's feet).
##
## Anyone may write (send): the townspeople thank the player as friendships grow
## (Relations: at THANKS_LEVELS), Zeynep writes as hers does (SideStory), other systems
## post their own. Letters sent before there is a mailbox wait and are all delivered once
## it is up. Saved with the game (SaveGame).

## A letter was sent (the mailbox's flag and the note follow).
signal letters_changed
## A letter was opened (read for the first time): its sender, title and body keys.
signal opened(letter: Dictionary)

## The mailbox (placeable item id).
const ITEM := &"mailbox"
## The side goal to put one up comes up on this day at GOAL_MINUTE.
const MAILBOX_DAY := 8
const GOAL_MINUTE := 7 * 60
## A townsperson writes a thank-you note on reaching these friendship levels (their
## letters' keys: MAIL_THANKS_<n>_TITLE/_BODY, n the place in this list + 1); the last
## one carries his gift (Relations.TOWN_GIFTS).
const THANKS_LEVELS: Array[int] = [2, 4]
const COLOR := Color("e8c48a")

## Saved: every letter, oldest first: {from, title, body (translation keys), args (filling
## {placeholders} in the body), gift ({item id: count}), day, read, noted (its note shown)};
## the mailbox goal done.
var letters: Array[Dictionary] = []
var goal_done := false
## Set by tests: the mailbox goal comes up in this automated run.
var testing := false

var _goal: SideGoal
var _poll := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_goal = SideGoal.new(&"mailbox", tr("SIDE_MAILBOX_TITLE"), "letter", COLOR)
	_goal.quiet = true
	Events.placed.connect(func(id: StringName) -> void:
		if id == ITEM:
			_poll = 0.0)
	Relations.leveled_up.connect(_on_leveled_up)


## Sends a letter: from `from_key` (the sender's name), titled `title_key`, saying
## `body_key` (translation keys; `args` fill its {placeholders}), with `gift` (item id ->
## count) in the envelope. It arrives in the mailbox (or waits for one to be put up).
func send(from_key: String, title_key: String, body_key: String, gift: Dictionary = {}, args: Dictionary = {}) -> void:
	var g := {}
	for id: Variant in gift:
		if int(gift[id]) > 0 and ItemDB.has_item(StringName(id)):
			g[String(id)] = int(gift[id])
	letters.append({"from": from_key, "title": title_key, "body": body_key, "args": args.duplicate(),
		"gift": g, "day": GameClock.day, "read": false, "noted": false})
	_poll = 0.0
	letters_changed.emit()


## A mailbox stands on the farm.
func has_mailbox() -> bool:
	for e: Dictionary in FarmState.placed:
		if StringName(e.get("id", "")) == ITEM:
			return true
	return false


## Letters in the mailbox not opened yet (none without a mailbox).
func unread_count() -> int:
	if not has_mailbox():
		return 0
	var n := 0
	for l: Dictionary in letters:
		if not bool(l.get("read", false)):
			n += 1
	return n


## Opens letter `index`: marks it read and hands over its gift (into the bag; what
## doesn't fit drops at `drop_at`). Returns what the gift was ({} for none).
func open_letter(index: int, drop_at := Vector3.INF) -> Dictionary:
	if index < 0 or index >= letters.size():
		return {}
	var l: Dictionary = letters[index]
	if bool(l.get("read", false)):
		return {}
	l["read"] = true
	l["noted"] = true
	var gift: Dictionary = l.get("gift", {})
	if not gift.is_empty():
		Relations.hand_gift(gift, drop_at)
	letters_changed.emit()
	opened.emit(l)
	return gift


## E on the mailbox: the letter screen, the first unread letter open.
func open_mailbox(box: Node3D = null) -> void:
	var hud := Game.hud as HUD
	if hud == null:
		return
	hud.letter_screen.open_mail(box.global_position + Vector3(0, 0.3, 0.4) if box else Vector3.INF)


func _process(delta: float) -> void:
	if SaveGame.loading:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 1.0
	_update_goal()
	_note_new()


## The mailbox goal: up from MAILBOX_DAY until one stands on the farm.
func _update_goal() -> void:
	if goal_done:
		if SideStory.goals.has(_goal):
			SideStory.remove_goal(_goal)
		return
	if has_mailbox():
		goal_done = true
		SideStory.remove_goal(_goal)
		Game.notify(tr("MSG_SIDE_DONE") % tr("SIDE_GOAL_MAILBOX"), UiTheme.GOLD)
		return
	var due := GameClock.day > MAILBOX_DAY or (GameClock.day == MAILBOX_DAY and SideStory.day_minute() >= GOAL_MINUTE)
	if not due or (DebugTools.is_automated() and not testing) or Game.player == null:
		return
	if not SideStory.goals.has(_goal):
		SideStory.add_goal(_goal)
		Game.notify(tr("MSG_SIDE_NEW") % tr("SIDE_GOAL_MAILBOX"), COLOR)
	var bench := WaypointMarker.anchor(Workbench.ANCHOR)
	if PlayerState.inventory.count_item(ITEM) > 0:
		var house := get_tree().get_first_node_in_group(&"farm_house") as FarmHouse
		_goal.set_goal(tr("SIDE_GOAL_MAILBOX"), tr("SIDE_HINT_MAILBOX_PLACE"), house.door_point() if house else null,
				tr("SIDE_LABEL_HOUSE"))
	else:
		var need := []
		var items: Dictionary = RecipeTable.crafting(ITEM).get("items", {})
		for id: StringName in items:
			need.append("%d %s" % [int(items[id]), ItemDB.get_item(id).display_name()])
		_goal.set_goal(tr("SIDE_GOAL_MAILBOX"), tr("SIDE_HINT_MAILBOX_CRAFT") % ", ".join(need), bench,
				tr("ITEM_WORKBENCH") if bench else "")


## A quiet note for letters newly in the mailbox.
func _note_new() -> void:
	if not has_mailbox():
		return
	var fresh := false
	for l: Dictionary in letters:
		if not bool(l.get("read", false)) and not bool(l.get("noted", false)):
			l["noted"] = true
			fresh = true
	if fresh:
		Game.notify(tr("MSG_MAIL_NEW"), COLOR)
		Audio.ui("notify", -8.0)
		letters_changed.emit()


## A townsperson's thank-you note at THANKS_LEVELS (Zeynep writes her own: SideStory).
func _on_leveled_up(who: StringName, level: int) -> void:
	var n := THANKS_LEVELS.find(level)
	if n < 0 or not Relations.TOWN_GIFTS.has(who):
		return
	var gift := {}
	if n == THANKS_LEVELS.size() - 1:
		var g: Array = Relations.TOWN_GIFTS[who]
		gift[g[0]] = int(g[1])
	send(String(Relations.PEOPLE[who]["name"]), "MAIL_THANKS_%d_TITLE" % (n + 1), "MAIL_THANKS_%d_BODY" % (n + 1), gift)


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	var out := []
	for l: Dictionary in letters:
		out.append(l.duplicate(true))
	return {"letters": out, "goal_done": goal_done}


func load_data(data: Dictionary) -> void:
	letters.clear()
	for l: Variant in data.get("letters", []):
		if l is Dictionary:
			letters.append((l as Dictionary).duplicate(true))
	goal_done = bool(data.get("goal_done", false))
	if _goal and SideStory.goals.has(_goal):
		SideStory.remove_goal(_goal)
	_poll = 0.0
	letters_changed.emit()
