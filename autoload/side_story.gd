extends Node
## The side track beside the story's goals (Quests), never in their way: Zeynep, the
## new neighbour.
##
## On day 6 at 07:00 Zeynep moves into the last house on the left at the far end of
## Yeşilova's street (Town's first house) with her dog Karamel: a banner says so and a
## side goal comes up, to meet her. Its dot (HUD.side_waypoint, beside the story's own)
## shows her in her front garden, crouched petting Karamel, from 07:00 to 20:00 until
## they have met (then indoors: her door, knocked on in the evening, or the garden in
## the morning). The player welcomes her, she thanks him, introduces herself and
## Karamel and goes in: one heart of friendship (Relations).
##
## From then on she asks now and then for a favour (an errand): the day after the
## meeting (day 7 at the earliest) a welcome gift for Karamel, a bag of dog food from
## the town market brought to her door (knocked on: she stays indoors until she has it,
## and the rest of that day; her garden days start after it); then, every 2 to 4 days
## after the last delivery, another bag because Karamel's food has run out (to her door
## or to her in the garden). Each delivery is one more heart, and her lines grow warmer
## with them, up to the tenth heart (no errands after that). A friendly chat once a day
## adds a little. Knocking with nothing to bring: she opens and has a word (not again
## within the hour); at night (22:00 to 07:00) nobody answers.
##
## ZeynepHome (scripts/npc/zeynep.gd) plays all of it in the world; this keeps what is
## saved, which goal is up, where its dot points and what everyone says. Automated runs
## (tests, screenshots) keep her away unless the run asks for her (`--zeynep`, or
## `testing` set by the zeynep scenario), so other checks never meet her.

## The side goal, its dot or its hint changed (the HUD refreshes).
signal changed

const WHO := &"zeynep"
const DOG := &"karamel"
const ITEM := &"dog_food"
## She moves in on MOVE_DAY at MOVE_MINUTE (the house is for sale before).
const MOVE_DAY := 6
const MOVE_MINUTE := 7 * 60
## The welcome gift is asked for from this day (and never on the day they met).
const GIFT_DAY := 7
## A new errand comes up at this hour of its day.
const ERRAND_MINUTE := 7 * 60
## Days from one delivery to the next errand.
const ERRAND_GAP := Vector2i(2, 4)
## Ways of asking for the next bag (SIDE_GOAL_FOOD_1..n).
const ERRAND_VARIANTS := 3
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
## Set by the zeynep scenario: she comes in this automated run.
var testing := false

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
	Events.day_started.connect(func(_d: int) -> void: _poll = 0.0)
	PlayerState.inventory.changed.connect(func() -> void: _poll = 0.0)


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


func has_food() -> bool:
	return PlayerState.inventory.count_item(ITEM) > 0


## What she asks for can be handed over now: an errand is up and a bag is in the bag.
func can_deliver() -> bool:
	return met and not errand.is_empty() and has_food()


## A knock now finds her busy (she opened to a knock with nothing to bring within the
## hour).
func knock_cooling() -> bool:
	return GameClock.total_minutes - _last_knock < KNOCK_COOLDOWN


func note_knock() -> void:
	_last_knock = GameClock.total_minutes


# --- The goal ----------------------------------------------------------------------------------

## The side goal up now: "" (none), "meet", "gift_buy", "gift_bring", "food_buy",
## "food_bring".
func goal() -> String:
	if not moved_in():
		return ""
	if not met:
		return "meet"
	if errand.is_empty():
		return ""
	return "%s_%s" % [String(errand.get("kind", "food")), "bring" if has_food() else "buy"]


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


## The day's errand comes up at ERRAND_MINUTE once its day has come.
func _post_errand() -> void:
	if not met or not errand.is_empty() or Relations.is_max(WHO) or not moved_in():
		return
	if GameClock.day < next_errand_day or (GameClock.day == next_errand_day and day_minute() < ERRAND_MINUTE):
		return
	var kind := "gift" if deliveries == 0 else "food"
	errand = {"kind": kind, "day": GameClock.day, "variant": randi() % ERRAND_VARIANTS}
	if not DebugTools.is_automated() or testing:
		Game.notify(tr("MSG_SIDE_NEW") % goal_text(), ROSE)
		Audio.ui("notify", -6.0)
	_goal = goal()
	changed.emit()


## The day-6 banner once she has moved in, when the player is free (no window open, not
## at the night's report).
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
	if g == "meet" or g.ends_with("_bring"):
		_label = tr("PERSON_ZEYNEP")
		if g == "meet":
			if out:
				_hint = tr("SIDE_HINT_MEET")
			elif asleep():
				_hint = tr("SIDE_HINT_MEET_NIGHT")
			else:
				_hint = tr("SIDE_HINT_MEET_EVENING")
		elif out:
			_hint = tr("SIDE_HINT_GARDEN")
		elif asleep():
			_hint = tr("SIDE_HINT_ASLEEP")
		return home.zeynep_marker() if out else home.door_point()
	# Short of dog food: the town market sells it.
	_label = ItemDB.get_item(ITEM).display_name()
	var price := Economy.buy_price(ITEM)
	if Economy.money < price:
		_hint = tr("HINT_NEED_MONEY") % UiTheme.money(price - Economy.money)
	else:
		_hint = tr("HINT_MARKET")
	var town := get_tree().get_first_node_in_group(&"town") as Town
	if town == null or town.market_counter == null:
		return null
	return town.market_counter.global_position + Vector3(0, MARKET_LIFT, 0)


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


## She took a bag of dog food for the errand up now: one more heart, the next errand a
## few days on.
func on_delivered() -> void:
	if errand.is_empty():
		return
	var kind := String(errand.get("kind", "food"))
	var text := tr("SIDE_DONE_%s" % kind.to_upper())
	if kind == "gift":
		gift_day = GameClock.day
	errand = {}
	deliveries += 1
	next_errand_day = GameClock.day + randi_range(ERRAND_GAP.x, ERRAND_GAP.y)
	Game.notify(tr("MSG_SIDE_DONE") % text, UiTheme.GOLD)
	Relations.raise(WHO, Relations.POINTS_PER_LEVEL)
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


## Handing over the errand's bag (the welcome gift, or food because Karamel's ran out);
## her thanks grow warmer with the friendship.
func lines_deliver(at_door: bool) -> Array:
	var out := []
	if at_door:
		out.append(_line(WHO, "ZEYNEP_DOOR_HELLO_%d" % _band()))
	if String(errand.get("kind", "food")) == "gift":
		out.append(_line(&"player", "ZEYNEP_GIFT_PLAYER", "take"))
		out.append(_line(WHO, "ZEYNEP_GIFT_1"))
		out.append(_line(WHO, "ZEYNEP_GIFT_2", "bye"))
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
		"deliveries": deliveries, "gift_day": gift_day, "announced": announced, "chat_day": chat_day}


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
	_last_knock = -INF
	_goal = goal()
	_waypoint = null
	_label = ""
	_hint = ""
	_wp_left = 0.0
	_poll = 0.0
	_banner_wait = 1.5
	changed.emit()
