extends Node
## The side track beside the story's goals (Quests), never in their way: Zeynep, the
## new neighbour.
##
## On day 3 at 07:00 Zeynep moves into the last house on the left at the far end of
## Yeşilova's street (Town's first house) with her dog Karamel: a banner says so and a
## side goal comes up, to meet her. Its dot (HUD.side_waypoint, beside the story's own)
## shows her in her front garden, crouched petting Karamel, from 07:00 to 20:00 until
## they have met (then indoors: her door, knocked on in the evening, or the garden in
## the morning). The player welcomes her, she thanks him, introduces herself and
## Karamel and goes in: one heart of friendship (Relations).
##
## From then on she asks now and then for a favour (an errand): the day after the
## meeting (day 4 at the earliest) a welcome gift for Karamel, a bag of dog food from
## the town market brought to her door (knocked on: she stays indoors until she has it,
## and the rest of that day; her garden days start after it); then, every 2 to 4 days
## after the last delivery, another favour in turn (ERRAND_TURN): a bottle of milk (the
## farm's own, or the market's), a bunch of flowers from the market, a bag of dog food
## because Karamel's has run out, eggs from his hens (only once he has some), a grilled
## fish (to her door or to her in the garden). Each delivery is one more heart, and her
## lines grow warmer with them, up to the tenth heart (no errands after that). A friendly
## chat once a day adds a little. Knocking with nothing to bring: she opens and has a
## word (not again within the hour); at night (22:00 to 07:00) nobody answers.
##
## At PUPPY_LEVEL hearts she calls him over (a note, the next morning's errand): Karamel
## has a pup, just weaned, and she wants him to have it; at her place a short talk and
## the pup is his (Pet.adopt, when the pet system is there). Her letters (Mail, once
## there is a mailbox): two days later "how's the little one?", and at INVITE_LEVEL an
## invitation for the next day; once read, a visit to her is an errand of its own.
##
## Her goals can wait, so they are quiet on the HUD (a compact card, a smaller dot).
##
## ZeynepHome (scripts/npc/zeynep.gd) plays all of it in the world; this keeps what is
## saved, which goal is up, where its dot points and what everyone says. Automated runs
## (tests, screenshots) keep her away unless the run asks for her (`--zeynep`, or
## `testing` set by the zeynep scenario), so other checks never meet her.
##
## Other side goals can be up at the same time as hers (`goals`: SideGoal, each on a card
## of its own with a dot of its own): the wolves' lesson and the vet's (WolfRaids) add and
## take away theirs, and day two's getting to know the town (TownGoals: town_goals, kept
## and saved here), and "fishing pays" for a farmer short of the barn's price (FishGoal:
## fish_goal, kept and saved here too).

## The side goal, its dot or its hint changed (the HUD refreshes).
signal changed
## A side goal was added to `goals` or taken away (the HUD builds its cards again).
signal goals_changed

const WHO := &"zeynep"
const DOG := &"karamel"
const ITEM := &"dog_food"
## She moves in on MOVE_DAY at MOVE_MINUTE (the house is for sale before).
const MOVE_DAY := 3
const MOVE_MINUTE := 7 * 60
## The welcome gift is asked for from this day (and never on the day they met).
const GIFT_DAY := 4
## A new errand comes up at this hour of its day.
const ERRAND_MINUTE := 7 * 60
## Days from one delivery to the next errand.
const ERRAND_GAP := Vector2i(2, 4)
## Ways of asking for the next bag (SIDE_GOAL_FOOD_1..n).
const ERRAND_VARIANTS := 3
## The favours after the welcome gift, in turn (one not possible now is passed over: eggs
## need hens of his own, or eggs in the bag).
const ERRAND_TURN: Array[String] = ["milk", "flowers", "food", "eggs", "fish", "food"]
## What each errand asks for: kind -> [item id (&"" for any grilled fish), how many].
## Errands not here (a visit, Karamel's pup) ask for nothing to be brought.
const ERRAND_ITEMS := {
	"gift": [&"dog_food", 1], "food": [&"dog_food", 1], "milk": [&"milk", 1],
	"flowers": [&"flower_bouquet", 1], "eggs": [&"egg", 3], "fish": [&"", 1],
}
## Errands she fills Karamel's bowl after.
const FEEDS_KARAMEL: Array[String] = ["gift", "food"]
## At this many hearts she calls him over for Karamel's pup (the meeting, the welcome gift
## and one more favour); at INVITE_LEVEL (after the pup) she writes to invite him over.
const PUPPY_LEVEL := 3
const INVITE_LEVEL := 6
## Days after the pup her letter asking after it comes.
const PUPPY_LETTER_DAYS := 2
## Before they have met she is out in her garden from GARDEN_FROM to GARDEN_TO.
const GARDEN_FROM := 7 * 60
const GARDEN_TO := 20 * 60
## Afterwards, on her garden days (see garden_day), mornings and evenings.
const MORNING := Vector2i(8 * 60, 10 * 60 + 30)
const EVENING := Vector2i(17 * 60 + 30, 19 * 60 + 30)
## Nobody answers the door from SLEEP_FROM to SLEEP_TO.
const SLEEP_FROM := 22 * 60
const SLEEP_TO := 7 * 60
## Knocked on again within this many game minutes with nothing to bring: she is busy.
const KNOCK_COOLDOWN := 60.0
## A day's first friendly chat adds this much friendship (a heart is
## Relations.POINTS_PER_LEVEL).
const CHAT_POINTS := 2
## How often the dot's place is worked out again (seconds).
const WAYPOINT_REFRESH := 0.25
## The dot floats this high over the market counter (over the story's own dot there).
const MARKET_LIFT := 2.4
## The banner's rim and the side goal's colour.
const ROSE := Color("f59ac8")

## Saved: they have met (and on which day), the errand up now ({} for none: kind "gift"
## or "food", the day it came up, the variant of its words), the day the next one comes
## up, how many bags were delivered (and the day the welcome gift was), whether the
## moving-in banner was shown, the last day a chat added friendship.
var met := false
var met_day := 0
var errand := {}
var next_errand_day := 0
var deliveries := 0
var gift_day := 0
var announced := false
var chat_day := 0
## Saved: the next favour in ERRAND_TURN; the day Karamel's pup became his (0: not yet);
## her letters sent (the pup's, the invitation); the day of the visit she invited him for
## (0: none).
var turn := 0
var puppy_day := 0
var puppy_letter := false
var invite_sent := false
var visit_day := 0
## Set by the zeynep scenario: she comes in this automated run.
var testing := false
## Set by tests: the next errand is of this kind.
var test_kind := ""
## The other side goals up now, besides Zeynep's (in the order their cards show).
var goals: Array[SideGoal] = []
## Day two's quiet goals in town (meet the townspeople, the vet, the filling station).
var town_goals: TownGoals
## "Fishing pays": five fish, three of them giants, for a farmer short of the barn's price.
var fish_goal: FishGoal

## When she last opened the door to a knock with nothing to bring (GameClock.total_minutes).
var _last_knock := -INF
var _goal := ""
var _waypoint: Variant = null
var _label := ""
var _hint := ""
var _wp_left := 0.0
var _poll := 0.0
var _banner_wait := 1.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	town_goals = TownGoals.new()
	town_goals.name = "TownGoals"
	add_child(town_goals)
	fish_goal = FishGoal.new()
	fish_goal.name = "FishGoal"
	add_child(fish_goal)
	Events.day_started.connect(func(_d: int) -> void: _poll = 0.0)
	PlayerState.inventory.changed.connect(func() -> void: _poll = 0.0)
	Mail.opened.connect(_on_letter_opened)


## She is in this run (always in play; automated runs only when asked).
func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("zeynep")


## She has moved in (from MOVE_DAY at MOVE_MINUTE).
func moved_in() -> bool:
	if not enabled():
		return false
	return GameClock.day > MOVE_DAY or (GameClock.day == MOVE_DAY and GameClock.minute >= MOVE_MINUTE)


## Minutes into the day (the clock runs past 24:00 until the player sleeps).
static func day_minute() -> float:
	return fmod(GameClock.minute, 1440.0)


## 22:00 to 07:00: she is asleep and doesn't answer the door.
func asleep() -> bool:
	var m := day_minute()
	return m >= SLEEP_FROM or m < SLEEP_TO


## Whether she spends some of `day` in her garden once they have met (three days in five).
static func garden_day(day: int) -> bool:
	return (day * 7 + 3) % 5 < 3


## Where her day puts her now: out in the front garden (true) or indoors.
func outside_now() -> bool:
	if not moved_in():
		return false
	var m := day_minute()
	if not met:
		return m >= GARDEN_FROM and m < GARDEN_TO
	# She went in after they met; that day she stays in, and until the welcome gift is in
	# her hands (its goal is a knock on her door) and the rest of that day.
	if GameClock.day == met_day or deliveries == 0 or GameClock.day == gift_day or not garden_day(GameClock.day):
		return false
	return (m >= MORNING.x and m < MORNING.y) or (m >= EVENING.x and m < EVENING.y)


## The errand up now ("" for none): "gift", "food", "milk", "flowers", "eggs", "fish",
## "visit" or "puppy".
func errand_kind() -> String:
	return String(errand.get("kind", "")) if not errand.is_empty() else ""


## The errand up now asks for something to be brought.
func errand_needs_item() -> bool:
	return ERRAND_ITEMS.has(errand_kind())


## How many of errand_item() she asked for.
func errand_count() -> int:
	return int((ERRAND_ITEMS.get(errand_kind(), [&"", 1]) as Array)[1])


## The item to hand her for the errand up now (the grilled fish the player has, for "fish";
## &"" when there is none or nothing is asked for).
func errand_item() -> StringName:
	var kind := errand_kind()
	if not ERRAND_ITEMS.has(kind):
		return &""
	var id: StringName = ERRAND_ITEMS[kind][0]
	if id != &"":
		return id
	for f: StringName in cooked_fish():
		if PlayerState.inventory.count_item(f) > 0:
			return f
	return &""


## Every grilled fish there is (whole or cleaned).
static func cooked_fish() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ItemTable.ITEMS:
		var s := String(id)
		if s.begins_with("fish_") and s.ends_with("_cooked"):
			out.append(id)
	return out


## What the errand up now asks for is in the bag (always, for one that asks for nothing).
func has_food() -> bool:
	if not errand_needs_item():
		return true
	var id := errand_item()
	return id != &"" and PlayerState.inventory.count_item(id) >= errand_count()


## What she asks for can be handed over now: an errand is up and what it asks for is in
## the bag (a visit, the pup: she is there).
func can_deliver() -> bool:
	return met and not errand.is_empty() and has_food()


## A knock now finds her busy (she opened to a knock with nothing to bring within the
## hour).
func knock_cooling() -> bool:
	return GameClock.total_minutes - _last_knock < KNOCK_COOLDOWN


func note_knock() -> void:
	_last_knock = GameClock.total_minutes


# --- The goal ----------------------------------------------------------------------------------

## The side goal up now: "" (none), "meet", "<kind>_buy" / "<kind>_bring" for an errand
## asking for something ("gift_buy", "food_bring", "milk_buy"...), "visit", "puppy".
func goal() -> String:
	if not moved_in():
		return ""
	if not met:
		return "meet"
	if errand.is_empty():
		return ""
	if not errand_needs_item():
		return errand_kind()
	return "%s_%s" % [errand_kind(), "bring" if has_food() else "buy"]


func goal_text() -> String:
	var g := goal()
	match g:
		"":
			return ""
		"food_buy":
			var v := clampi(int(errand.get("variant", 0)), 0, ERRAND_VARIANTS - 1) + 1
			return tr("SIDE_GOAL_FOOD_%d" % v)
	return tr("SIDE_GOAL_%s" % g.to_upper())


## The line under the side goal: where to find her, why the dot points where it does.
func goal_hint() -> String:
	return _hint


## Where the side goal's dot points: a Vector3, a Node3D it follows, or null.
func guide_point() -> Variant:
	if typeof(_waypoint) == TYPE_OBJECT and not is_instance_valid(_waypoint):
		return null
	return _waypoint


## The line on the side dot's pill: who or what it points at.
func guide_label() -> String:
	return _label


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_update_banner(delta)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_post_errand()
		_post_letters()
		var g := goal()
		if g != _goal:
			_goal = g
			_wp_left = 0.0
			changed.emit()
	_wp_left -= delta
	if _wp_left <= 0.0:
		_wp_left = WAYPOINT_REFRESH
		var hint := _hint
		var label := _label
		_hint = ""
		_label = ""
		_waypoint = _target(_goal)
		if _hint != hint or _label != label:
			changed.emit()


## The day's errand comes up at ERRAND_MINUTE once its day has come: the welcome gift
## first, Karamel's pup at PUPPY_LEVEL hearts, a visit she invited him for, else the next
## favour in turn.
func _post_errand() -> void:
	if not met or not errand.is_empty() or not moved_in():
		return
	var kind := ""
	if visit_day > 0 and _day_come(visit_day):
		kind = "visit"
	elif not _day_come(next_errand_day):
		return
	elif deliveries == 0:
		kind = "gift"
	elif test_kind != "":
		kind = test_kind
	elif puppy_day == 0 and Relations.level(WHO) >= PUPPY_LEVEL:
		kind = "puppy"
	elif Relations.is_max(WHO):
		return
	else:
		kind = _next_kind()
	errand = {"kind": kind, "day": GameClock.day, "variant": randi() % ERRAND_VARIANTS}
	if not DebugTools.is_automated() or testing:
		if kind == "puppy":
			Game.notify(tr("MSG_ZEYNEP_PUPPY_CALL"), ROSE)
		else:
			Game.notify(tr("MSG_SIDE_NEW") % goal_text(), ROSE)
		Audio.ui("notify", -6.0)
	_goal = goal()
	changed.emit()


## `day` has come, from ERRAND_MINUTE.
func _day_come(day: int) -> bool:
	return GameClock.day > day or (GameClock.day == day and day_minute() >= ERRAND_MINUTE)


## The next favour in ERRAND_TURN that can be done now (eggs: his own hens, or eggs in
## the bag).
func _next_kind() -> String:
	for i in ERRAND_TURN.size():
		var kind := ERRAND_TURN[(turn + i) % ERRAND_TURN.size()]
		if kind == "eggs" and not _has_hens() and PlayerState.inventory.count_item(&"egg") < errand_count_of(kind):
			continue
		turn = (turn + i + 1) % ERRAND_TURN.size()
		return kind
	return "food"


static func errand_count_of(kind: String) -> int:
	return int((ERRAND_ITEMS.get(kind, [&"", 1]) as Array)[1])


func _has_hens() -> bool:
	for a: AnimalData in Animals.animals:
		if a.species == &"chicken":
			return true
	return false


## Her letters (Mail): asking after the pup PUPPY_LETTER_DAYS after it, the invitation at
## INVITE_LEVEL hearts (after the pup).
func _post_letters() -> void:
	if puppy_day <= 0:
		return
	if not puppy_letter and GameClock.day >= puppy_day + PUPPY_LETTER_DAYS:
		puppy_letter = true
		Mail.send("PERSON_ZEYNEP", "MAIL_ZEYNEP_PUPPY_TITLE", "MAIL_ZEYNEP_PUPPY_BODY", {&"dog_food": 1})
	if not invite_sent and Relations.level(WHO) >= INVITE_LEVEL:
		invite_sent = true
		Mail.send("PERSON_ZEYNEP", "MAIL_ZEYNEP_INVITE_TITLE", "MAIL_ZEYNEP_INVITE_BODY")


## Her invitation read: the visit is the next day's errand.
func _on_letter_opened(letter: Dictionary) -> void:
	if String(letter.get("title", "")) == "MAIL_ZEYNEP_INVITE_TITLE" and visit_day == 0:
		visit_day = GameClock.day + 1


## The moving-in banner (MOVE_DAY) once she has moved in, when the player is free (no
## window open, not at the night's report).
func _update_banner(delta: float) -> void:
	if announced or not moved_in() or not is_instance_valid(Game.hud):
		return
	var hud := Game.hud as HUD
	if hud == null or Game.is_ui_open() or hud.sleep_screen.is_busy():
		_banner_wait = 1.5
		return
	_banner_wait -= delta
	if _banner_wait > 0.0:
		return
	announced = true
	var banner := NewsBanner.new()
	var parent: Node = hud.get_node_or_null("Root")
	(parent if parent else hud).add_child(banner)
	banner.play(tr("ZEYNEP_BANNER_KICKER"), tr("ZEYNEP_BANNER_TITLE"), tr("ZEYNEP_BANNER_TEXT"), "heart", ROSE)
	Audio.ui("notify", -4.0)


func _home() -> ZeynepHome:
	return get_tree().get_first_node_in_group(ZeynepHome.GROUP) as ZeynepHome


## Where the side dot points for goal `g` (and its pill's line and the hint under the
## goal).
func _target(g: String) -> Variant:
	if g == "":
		return null
	var home := _home()
	if home == null:
		return null
	var out := home.zeynep_outside()
	if g == "meet" or g.ends_with("_bring") or not g.ends_with("_buy"):
		_label = tr("PERSON_ZEYNEP")
		if home.at_event():
			# Out at the town's event: her door, for when it is over.
			_hint = tr("SIDE_HINT_AT_EVENT")
			return home.door_point()
		if g == "meet":
			if out:
				_hint = tr("SIDE_HINT_MEET")
			elif asleep():
				_hint = tr("SIDE_HINT_MEET_NIGHT")
			else:
				_hint = tr("SIDE_HINT_MEET_EVENING")
		elif out:
			# (A visit, the pup: nothing to hand over.)
			_hint = tr("SIDE_HINT_GARDEN") if g.ends_with("_bring") else ""
		elif asleep():
			_hint = tr("SIDE_HINT_ASLEEP")
		return home.zeynep_marker() if out else home.door_point()
	# Eggs come from his hens' nests, a grilled fish from the pond and the fire.
	match errand_kind():
		"eggs":
			_hint = tr("SIDE_HINT_EGGS")
			return null
		"fish":
			_hint = tr("SIDE_HINT_FISH")
			return null
	# Short of what she asked for: the town market sells it (milk: or his own cows').
	var item := errand_item()
	_label = ItemDB.get_item(item).display_name()
	var price := Economy.buy_price(item) * errand_count()
	if Economy.money < price:
		# Short of its price: how much, how to earn it, and the dot where that line says.
		var short: Dictionary = Quests.money_short(price)
		_hint = String(short["hint"])
		_label = ""
		return short["at"]
	elif errand_kind() == "milk":
		_hint = tr("SIDE_HINT_MILK")
	else:
		_hint = tr("HINT_MARKET")
	var town := get_tree().get_first_node_in_group(&"town") as Town
	if town == null or town.market_counter == null:
		return null
	return town.market_counter.global_position + Vector3(0, MARKET_LIFT, 0)


## Puts side goal `g` up beside the others (once).
func add_goal(g: SideGoal) -> void:
	if g == null or goals.has(g):
		return
	goals.append(g)
	goals_changed.emit()


## Takes side goal `g` down.
func remove_goal(g: SideGoal) -> void:
	if not goals.has(g):
		return
	goals.erase(g)
	goals_changed.emit()


# --- What happens ------------------------------------------------------------------------------

## They met (in the garden or at her door): the first heart, and the welcome gift is
## asked for the next day (GIFT_DAY at the earliest).
func on_met() -> void:
	if met:
		return
	var text := goal_text()
	met = true
	met_day = GameClock.day
	next_errand_day = maxi(GIFT_DAY, GameClock.day + 1)
	Game.notify(tr("MSG_SIDE_DONE") % text, UiTheme.GOLD)
	Relations.raise(WHO, Relations.POINTS_PER_LEVEL)
	_goal = goal()
	_wp_left = 0.0
	changed.emit()


## The errand up now is done (what she asked for in her hands; the visit paid; the pup
## his): one more heart, the next errand a few days on (her call for the pup the next
## morning, once its hearts are there).
func on_delivered() -> void:
	if errand.is_empty():
		return
	var kind := errand_kind()
	var text := tr("SIDE_DONE_%s" % kind.to_upper())
	if kind == "gift":
		gift_day = GameClock.day
	elif kind == "visit":
		visit_day = 0
	elif kind == "puppy":
		puppy_day = GameClock.day
		var pet := get_node_or_null("/root/Pet")
		if pet:
			pet.call("adopt")
	errand = {}
	deliveries += 1
	next_errand_day = GameClock.day + randi_range(ERRAND_GAP.x, ERRAND_GAP.y)
	Game.notify(tr("MSG_SIDE_DONE") % text, UiTheme.GOLD)
	Relations.raise(WHO, Relations.POINTS_PER_LEVEL)
	if puppy_day == 0 and Relations.level(WHO) >= PUPPY_LEVEL:
		next_errand_day = GameClock.day + 1
	_goal = goal()
	_wp_left = 0.0
	changed.emit()


## A friendly chat: the day's first adds a little friendship.
func on_chat() -> void:
	if not met or chat_day == GameClock.day:
		return
	chat_day = GameClock.day
	Relations.raise(WHO, CHAT_POINTS)


# --- What they say -------------------------------------------------------------------------------
# Lines are DialogueScreen's {who, text} with a "tag" ZeynepHome turns into a cue:
# "stand" (she gets up from Karamel), "take" (she takes the bag), "bye" (she says
# goodbye).

## Meeting her: in the garden (she gets up from Karamel), or at her door.
func lines_meet(at_door: bool) -> Array:
	var out := [_line(&"player", "ZEYNEP_MEET_PLAYER")]
	out.append(_line(WHO, "ZEYNEP_MEET_DOOR_1" if at_door else "ZEYNEP_MEET_1", "" if at_door else "stand"))
	out.append(_line(WHO, "ZEYNEP_MEET_2"))
	out.append(_line(WHO, "ZEYNEP_MEET_3", "bye"))
	return out


## Handing over what the errand asked for (the welcome gift, food because Karamel's ran
## out, the milk, the flowers...), the visit, Karamel's pup; her thanks grow warmer with
## the friendship.
func lines_deliver(at_door: bool) -> Array:
	var out := []
	var kind := errand_kind()
	if kind == "puppy":
		# She does the calling: the pup is the news.
		out.append(_line(WHO, "ZEYNEP_PUPPY_1"))
		out.append(_line(WHO, "ZEYNEP_PUPPY_2"))
		out.append(_line(&"player", "ZEYNEP_PUPPY_PLAYER"))
		out.append(_line(WHO, "ZEYNEP_PUPPY_3", "bye"))
		return out
	if at_door:
		out.append(_line(WHO, "ZEYNEP_DOOR_HELLO_%d" % _band()))
	if kind == "gift":
		out.append(_line(&"player", "ZEYNEP_GIFT_PLAYER", "take"))
		out.append(_line(WHO, "ZEYNEP_GIFT_1"))
		out.append(_line(WHO, "ZEYNEP_GIFT_2", "bye"))
		return out
	if kind == "visit":
		out.append(_line(&"player", "ZEYNEP_VISIT_PLAYER"))
		out.append(_line(WHO, "ZEYNEP_VISIT_1"))
		out.append(_line(WHO, "ZEYNEP_VISIT_2", "bye"))
		return out
	if kind != "food":
		var k := kind.to_upper()
		out.append(_line(&"player", "ZEYNEP_%s_PLAYER" % k, "take"))
		if Relations.level(WHO) + 1 >= Relations.max_level(WHO):
			out.append(_line(WHO, "ZEYNEP_FOOD_BEST_1"))
			out.append(_line(WHO, "ZEYNEP_FOOD_BEST_2", "bye"))
			return out
		out.append(_line(WHO, "ZEYNEP_%s_1" % k))
		out.append(_line(WHO, "ZEYNEP_%s_2" % k, "bye"))
		return out
	out.append(_line(&"player", _food_player_line(), "take"))
	# The last heart gets a line of its own.
	if Relations.level(WHO) + 1 >= Relations.max_level(WHO):
		out.append(_line(WHO, "ZEYNEP_FOOD_BEST_1"))
		out.append(_line(WHO, "ZEYNEP_FOOD_BEST_2", "bye"))
		return out
	var band := _band()
	out.append(_line(WHO, "ZEYNEP_FOOD_%d_1" % band))
	out.append(_line(WHO, "ZEYNEP_FOOD_%d_2" % band, "bye"))
	return out


## The player's words with a bag for the errand up now: every other time a plain "here's
## a bag", else what her errand said (the food run out, running low, no time for the
## market).
func _food_player_line() -> String:
	if deliveries % 2 == 1:
		return "ZEYNEP_FOOD_PLAYER_2"
	match clampi(int(errand.get("variant", 0)), 0, ERRAND_VARIANTS - 1):
		1:
			return "ZEYNEP_FOOD_PLAYER_LOW"
		2:
			return "ZEYNEP_FOOD_PLAYER_MARKET"
	return "ZEYNEP_FOOD_PLAYER_1"


## A word with her when there is nothing to bring: at the door (after a knock) or in the
## garden.
func lines_chat(at_door: bool) -> Array:
	var band := _band()
	if at_door:
		return [_line(WHO, "ZEYNEP_DOOR_HELLO_%d" % band), _line(WHO, "ZEYNEP_DOOR_CHAT_%d" % band, "bye")]
	var part := "MORNING" if day_minute() < 13 * 60 else "EVENING"
	return [_line(WHO, "ZEYNEP_GARDEN_%s_%d" % [part, band]), _line(&"player", "ZEYNEP_GARDEN_PLAYER_%d" % band)]


## Her warmth by the friendship: 1 (a new neighbour), 2 (a friend), 3 (a close friend).
func _band() -> int:
	var lv := Relations.level(WHO)
	return 1 if lv < 4 else (2 if lv < 7 else 3)


static func _line(who: StringName, key: String, tag := "") -> Dictionary:
	return {"who": who, "text": TranslationServer.translate(key), "tag": tag}


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	return {"met": met, "met_day": met_day, "errand": errand.duplicate(), "next": next_errand_day,
		"deliveries": deliveries, "gift_day": gift_day, "announced": announced, "chat_day": chat_day,
		"turn": turn, "puppy_day": puppy_day, "puppy_letter": puppy_letter, "invite_sent": invite_sent,
		"visit_day": visit_day, "town": town_goals.save_data(), "fish": fish_goal.save_data()}


## After GameClock.load_data.
func load_data(data: Dictionary) -> void:
	met = bool(data.get("met", false))
	met_day = int(data.get("met_day", 0))
	errand = (data.get("errand", {}) as Dictionary).duplicate()
	next_errand_day = int(data.get("next", 0))
	deliveries = int(data.get("deliveries", 0))
	gift_day = int(data.get("gift_day", 0))
	announced = bool(data.get("announced", false))
	chat_day = int(data.get("chat_day", 0))
	turn = int(data.get("turn", 0))
	puppy_day = int(data.get("puppy_day", 0))
	puppy_letter = bool(data.get("puppy_letter", false))
	invite_sent = bool(data.get("invite_sent", false))
	visit_day = int(data.get("visit_day", 0))
	town_goals.load_data(data.get("town", {}))
	fish_goal.load_data(data.get("fish", {}))
	_last_knock = -INF
	_goal = goal()
	_waypoint = null
	_label = ""
	_hint = ""
	_wp_left = 0.0
	_poll = 0.0
	_banner_wait = 1.5
	changed.emit()
