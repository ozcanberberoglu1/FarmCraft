extends Node
## Yeşilova's fishing contest, "En Büyük Balık Yarışması": the biggest fish of the day wins.
## The first on day 6, then one every EVERY_DAYS days (10, 14...), 09:00 to 17:00 at the
## town pond behind the filling station (ContestVenue: its shore and the board): always two
## days off a carnival (Carnival: 4, 8, 12...). Never on a carnival day: a contest that
## would fall on one (were the two cadences to change) is held the day after. On the day
## a side goal (SideStory.goals: "join the fishing contest", its dot over the pond) is up
## from the morning until he gets there while it is on (or until 17:00); the first
## contest's is prominent, later ones' quiet. It never stands in the story's way.
##
## The morning before, a letter from Nuri Hoca announces it (through the mailbox when the
## game has one, else on the letter sheet like Beyza's carnival letter; once: letter_day
## is saved). The town sets out early enough to be at the pond by then (ContestCrowd: each
## at his own time). At 09:00 a banner opens it: five anglers cast from the shore round
## the pond (RIVALS: four townspeople and Cemal Usta from the lake villages). A rival
## lands fish only while he stands at his place with his line in the water: the first a
## while after his cast (FIRST_CATCH), then one every half hour or so; the board and the
## card list nobody before his first fish. The town watches: a murmur of voices
## over the pond (Audio's "contest_crowd" loop), a call or a laugh now and then, and a
## cheer each time the board gets a new biggest fish (new_leader), whoever caught it. The player
## takes part by fishing there: every fish he lands within VENUE_RADIUS of the pond is
## weighed, his biggest counts. The board at the pond and a small HUD card (while he is
## there) show the top three and his best.
##
## At 17:00 a horn ends it, the crowd applauds, and the winner is named (a banner and a
## fanfare). The player winning keeps his fish (it is already his), earns the "En İyi
## Balıkçı" achievement, PRIZE_FISH ordinary fish (into the bag; what doesn't fit goes to
## the warehouse) and PRIZE_MONEY dollars (the day's report: REPORT_PRIZE). Then the crowd
## goes back to its day. A contest missed by sleeping through its end is settled quietly
## the next morning (result_day keeps a prize from coming twice). The leaderboard is saved.
##
## The afternoon before (from PREP_MINUTE on the day the letter comes) a second side goal
## says to get ready, "Get ready for the fishing contest": a fishing rod of any kind and
## PREP_BAIT bait, what he has of them ticked on its card ("Fishing rod 1/1 ✓ · Bait
## 2/5": SideGoal.needs). Its dot goes to what is missing and its hint says which: the
## workbench for a rod, the market for bait (short of the bait's price: where to earn it).
## Once he has it all it is a done line for the rest of that day ("You're all set", a
## note once: prep_day); it stays through the next morning while something is still
## missing and goes when the contest starts ("join the fishing contest" takes over). A
## farmer who has it all before it would come up is not asked. The first contest's is
## prominent, later ones' quiet.
##
## Automated runs (tests, screenshots) have no contests unless the run asks for them
## (`--contest`, or `testing` set by the contest scenario), so other checks' town stays as
## it is; the getting-ready goal only when a test turns `prep_testing` on as well.

signal began
signal finished
## The horn: the ceremony starts (the crowd claps).
signal ceremony_started
## A rival landed a fish (`catch`: FishTable.catch_of) at the venue.
signal rival_caught(id: StringName, catch: Dictionary)
## The leaderboard changed (a fish weighed, a new contest, a load).
signal board_changed
## The board has a new biggest fish (`who`: "player" or a rival's id): the crowd cheers.
signal new_leader(who: String, kg: float)

const FIRST_DAY := 6
const EVERY_DAYS := 4
const START_MINUTE := 9 * 60
const END_MINUTE := 17 * 60
const PRIZE_MONEY := 100
const PRIZE_FISH := 20
## The prize fish: ordinary ones.
const PRIZE_FISH_ID := &"fish_crucian"
const ACHIEVEMENT := &"best_angler"
## A fish landed this close to the town pond's centre (flat metres) is weighed for the contest.
const VENUE_RADIUS := 24.0
## The horn and the applause are heard this close to the pond; the banner shows in town.
const HEAR_RADIUS := 140.0
## The rivals (the anglers; ContestCrowd gives them their places) and their baits.
const RIVALS := {&"fisher": &"minnow", &"young": &"sweetcorn", &"farmer": &"worm", &"villager": &"dough",
	&"sweeper": &"maggot"}
## Game minutes between a rival's fish (a random wait in this range).
const CATCH_EVERY := Vector2(30.0, 75.0)
## Game minutes from a rival's cast to his first fish (a random wait in this range).
const FIRST_CATCH := Vector2(20.0, 60.0)
## A fish landed within this many game minutes is shown at the pond (rival_caught); older
## ones (the clock was skipped) are only weighed.
const CATCH_SHOWN := 6.0
## The rivals' fish run a little smaller than the pond allows (a share of the weight roll):
## a good fish of the player's beats most days' winners, a giant always does.
const RIVAL_ROLL := 0.8
## The ceremony (real seconds from the horn): applause, the winner named, the crowd leaves.
const APPLAUSE_AT := 1.2
const ANNOUNCE_AT := 4.5
const CEREMONY_LEN := 12.0
## Seconds between the player being free and the letter opening (a note comes first).
const LETTER_DELAY := 2.2
## The crowd's murmur at the pond (Audio's "contest_crowd" loop, 0..1), heard round it.
const MURMUR := 0.75
## Real seconds between a call or a laugh from the crowd (a random wait in this range),
## heard within CALL_RADIUS of the pond.
const CALL_EVERY := Vector2(5.0, 13.0)
const CALL_RADIUS := 60.0
## The side goal's colour and how often it is looked at (seconds).
const GOAL_COLOR := Color("f2c66d")
const GOAL_POLL := 0.5
## The getting-ready goal: up from this minute of the day before a contest, and the bait
## it asks for.
const PREP_MINUTE := 13 * 60
const PREP_BAIT := 5

## The day's leaderboard: entrant ("player" or a rival's id) -> {"kg": float, "fish": String}.
var entries := {}
## The contest day `entries` belong to (0: none yet).
var day_held := 0
## The last contest day settled (its winner named, its prize given).
var result_day := 0
## The last winner: {"id", "kg", "fish"} (the board shows it between contests).
var last_winner := {}
## The last contest day whose letter was read; today's letter waits for the player.
var letter_day := 0
## The last contest day the player came to (its side goal done).
var goal_day := 0
## The last contest day he was told he is all set for (the getting-ready goal's note).
var prep_day := 0
var letter_pending := false
## Set by the contest scenario: contests happen in this automated run (`testing_letter`:
## the letter opens by itself as in play). `ceremony_speed` hurries the ceremony.
var testing := false
var testing_letter := false
var ceremony_speed := 1.0
## Set by a test: the getting-ready goal comes up in this automated run.
var prep_testing := false

var _letter_wait := LETTER_DELAY
var _letter_noted := false
var _on := false
## Seconds since the horn (<0: no ceremony running); whether the winner was named.
var _ceremony_t := -1.0
var _announced := false
var _next_catch := {}
## The game minute each rival's fish are counted from: his cast (rival id -> minute), and
## who was seen away from the water since.
var _cast := {}
var _away := {}
## A game loaded in the middle of a contest from a save without the casts: the rivals'
## waits start again from this minute (0: none).
var _cast_floor := 0.0
var _crowd: Node
var _rng := RandomNumberGenerator.new()
var _card: GlassPanel
var _card_label: Label
var _card_t := 0.0
var _goal: SideGoal
var _prep: SideGoal
var _goal_t := 0.0
var _call_t := 4.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_goal = SideGoal.new(&"contest", "", "star", GOAL_COLOR)
	_prep = SideGoal.new(&"contest_prep", "", "star", GOAL_COLOR)
	Events.day_started.connect(_on_day_started)


# --- Schedule --------------------------------------------------------------------------------

## A contest is due on day `d` by the count (6, 10, 14...), before a carnival moves it.
static func _due(d: int) -> bool:
	return d >= FIRST_DAY and (d - FIRST_DAY) % EVERY_DAYS == 0


## Whether day `d` has the contest: a due day that isn't a carnival day, or the day after
## a due day that was one.
static func is_contest_day(d: int) -> bool:
	if _due(d) and not Carnival.is_carnival_day(d):
		return true
	return _due(d - 1) and Carnival.is_carnival_day(d - 1)


## The next contest day from `d` on (`d` itself when it has one).
static func next_contest_day(d: int) -> int:
	var k := maxi(d, FIRST_DAY)
	while not is_contest_day(k):
		k += 1
	return k


func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("contest")


func is_today() -> bool:
	return enabled() and is_contest_day(GameClock.day)


## 09:00 to 17:00 of a contest day: fish landed at the pond are weighed.
func is_on() -> bool:
	return is_today() and GameClock.minute >= START_MINUTE and GameClock.minute < END_MINUTE


## The anglers and the crowd are at the pond: the contest, then its ceremony.
func crowd_out() -> bool:
	return is_on() or _ceremony_t >= 0.0


## Within VENUE_RADIUS of the town pond (flat).
static func at_venue(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(WorldLayout.TOWN_POND_CENTER) < VENUE_RADIUS


func _player_distance() -> float:
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p):
		return INF
	return Vector2(p.global_position.x, p.global_position.z).distance_to(WorldLayout.TOWN_POND_CENTER)


# --- The leaderboard -------------------------------------------------------------------------

## A fish the player landed at `at`: weighed for the contest when it is on and he is at
## the pond (his biggest counts). True when it was weighed.
func player_caught(id: StringName, kg: float, at: Vector3) -> bool:
	if not is_on() or not at_venue(at) or not FishTable.is_fish(id):
		return false
	_open_board()
	_goal_done()
	var best := float((entries.get("player", {}) as Dictionary).get("kg", 0.0))
	var w := FloppingFish.weight_text(kg)
	if kg > best:
		var top := top_kg()
		entries["player"] = {"kg": kg, "fish": String(id)}
		Game.notify(tr("MSG_CONTEST_ENTRY") % [w, rank_of("player")], UiTheme.GOLD_SOFT)
		board_changed.emit()
		if kg > top:
			_cheer("player", kg)
	else:
		Game.notify(tr("MSG_CONTEST_ENTRY_SMALL") % [w, FloppingFish.weight_text(best)], UiTheme.TEXT_MUTED)
	return true


## Records `catch` for entrant `who` (kept when it is his biggest): while the contest is on.
func record(who: String, catch: Dictionary) -> void:
	if not is_on():
		return
	_open_board()
	var kg := float(catch.get("kg", 0.0))
	if kg > float((entries.get(who, {}) as Dictionary).get("kg", 0.0)):
		var top := top_kg()
		entries[who] = {"kg": kg, "fish": String(catch.get("id", ""))}
		board_changed.emit()
		if kg > top:
			_cheer(who, kg)


## The biggest fish on today's board (kg; 0 with none weighed).
func top_kg() -> float:
	var best := 0.0
	for who: String in entries:
		best = maxf(best, float((entries[who] as Dictionary).get("kg", 0.0)))
	return best


## A new biggest fish: the crowd cheers at the pond (heard there), new_leader.
func _cheer(who: String, kg: float) -> void:
	if _player_distance() < HEAR_RADIUS:
		Audio.play("crowd_cheer", crowd_point(), -2.0, 0.05, &"Effects", 9.0)
	new_leader.emit(who, kg)


## Today's contest's board starts empty.
func _open_board() -> void:
	if day_held != GameClock.day:
		day_held = GameClock.day
		entries.clear()
		_next_catch.clear()
		_cast.clear()
		_away.clear()
		_cast_floor = 0.0
		board_changed.emit()


## The entrants, biggest fish first: [[id, kg, fish id], ...].
func standings() -> Array:
	var out: Array = []
	for who: String in entries:
		var e: Dictionary = entries[who]
		out.append([who, float(e.get("kg", 0.0)), StringName(String(e.get("fish", "")))])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	return out


## 1 for the leader; 0 when `who` has no fish weighed.
func rank_of(who: String) -> int:
	var s := standings()
	for i in s.size():
		if s[i][0] == who:
			return i + 1
	return 0


func entrant_name(who: String) -> String:
	# The farmer stands on the board with his farm's name once it has one (FarmIdentity).
	return FarmIdentity.contest_entrant(tr("CONTEST_YOU")) if who == "player" else tr("PERSON_" + who.to_upper())


func _fish_name(id: StringName) -> String:
	var item := ItemDB.get_item(id)
	return item.display_name() if item else String(id)


## The board's lines: the top three and the player's best while a contest has a board
## (nobody is listed before his first fish: until the first one it says the contest has
## begun); between contests the next date and the last winner.
func board_text(with_title := true) -> String:
	var lines := PackedStringArray()
	if with_title:
		lines.append(UiTheme.caps(tr("CONTEST_BOARD_TITLE")))
	var live := is_today() and day_held == GameClock.day and GameClock.minute >= START_MINUTE
	if live or (is_on()):
		var s := standings()
		if s.is_empty():
			lines.append(tr("CONTEST_BOARD_BEGUN"))
		for i in mini(3, s.size()):
			lines.append("%d. %s — %s" % [i + 1, entrant_name(s[i][0]), FloppingFish.weight_text(float(s[i][1]))])
		if entries.has("player"):
			lines.append(tr("CONTEST_YOUR_BEST") % [FloppingFish.weight_text(float((entries["player"] as Dictionary)["kg"])),
					rank_of("player")])
		elif is_on():
			lines.append(tr("CONTEST_YOUR_NONE"))
	else:
		var d := next_contest_day(GameClock.day if GameClock.minute < END_MINUTE else GameClock.day + 1)
		lines.append(tr("CONTEST_BOARD_NEXT") % [d, _clock(START_MINUTE), _clock(END_MINUTE)])
		if not last_winner.is_empty():
			lines.append(tr("CONTEST_BOARD_LAST") % [entrant_name(String(last_winner.get("id", ""))),
					FloppingFish.weight_text(float(last_winner.get("kg", 0.0)))])
	return "\n".join(lines)


# --- Frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Game.player == null or not is_instance_valid(Game.player) or SaveGame.loading:
		return
	var on := is_on()
	if on != _on:
		_on = on
		if on:
			_open_board()
			began.emit()
			_show_banner(tr("CONTEST_BANNER_TITLE"), tr("CONTEST_BANNER_TEXT") % _clock(END_MINUTE), "sparkles")
	if on:
		_sim_rivals()
		_crowd_calls(delta)
	_goal_t -= delta
	if _goal_t <= 0.0:
		_goal_t = GOAL_POLL
		_update_goal()
		_update_prep()
	# The end: the horn at the pond, or (missed, slept through, loaded later) settled quietly.
	if _ceremony_t < 0.0 and day_held > 0 and result_day != day_held and enabled() \
			and (GameClock.day > day_held or GameClock.minute >= END_MINUTE):
		if GameClock.day == day_held and _player_distance() < HEAR_RADIUS:
			_start_ceremony()
		else:
			_settle(false)
	if _ceremony_t >= 0.0:
		_ceremony(delta * ceremony_speed)
	_update_letter(delta)
	_update_card(delta)


## The town's contest crowd (null: no town in this world).
func crowd() -> Node:
	if _crowd == null or not is_instance_valid(_crowd):
		_crowd = null
		for n: Node in get_tree().get_nodes_in_group(EventCrowd.GROUP):
			if n is ContestCrowd:
				_crowd = n
	return _crowd


## The game minute rival `id` cast the line that is in the water now; -1 while he is not
## fishing (not at his place yet, not cast yet, away). Without a town: from the opening.
func rival_cast(id: StringName) -> float:
	var c := crowd() as ContestCrowd
	return c.cast_minute(id) if c else float(START_MINUTE)


## The rivals land a fish now and then (by the game clock), each kept if his biggest: only
## one whose line is in the water, the first a while after his cast. A skipped clock is
## caught up with (the fish he would have landed meanwhile).
func _sim_rivals() -> void:
	var now := GameClock.minute
	for id: StringName in RIVALS:
		var key := String(id)
		var cast := rival_cast(id)
		if cast < 0.0:
			if _cast.has(key):
				_away[key] = true
			continue
		# His first cast, or a new one after he was away: the wait starts from it.
		if not _cast.has(key) or (_away.has(key) and cast > float(_cast[key]) + 1.0):
			_cast[key] = clampf(maxf(cast, _cast_floor), float(START_MINUTE), now)
			_next_catch[key] = float(_cast[key]) + _rng.randf_range(FIRST_CATCH.x, FIRST_CATCH.y)
		_away.erase(key)
		for guard in 24:
			var at := float(_next_catch.get(key, INF))
			if now < at:
				break
			_next_catch[key] = at + _rng.randf_range(CATCH_EVERY.x, CATCH_EVERY.y)
			var c := rival_catch(id)
			if c.is_empty():
				continue
			record(key, c)
			if now - at < CATCH_SHOWN:
				rival_caught.emit(id, c)


## The game minute rival `id`'s fish are counted from today (his cast); -1: none yet.
func cast_of(id: StringName) -> float:
	return float(_cast.get(String(id), -1.0))


## A fish for rival `id` as the pond gives it to his bait at this hour (no giants: those
## are the player's luck); {} for the odd boot.
func rival_catch(id: StringName) -> Dictionary:
	var c := FishTable.roll(RIVALS.get(id, &"worm"), GameClock.get_hour_float(), Weather.is_raining(), _rng)
	if not FishTable.is_fish(StringName(c.get("id", &""))):
		return {}
	return FishTable.catch_of(StringName(c["species"]), _rng.randf() * RIVAL_ROLL)


func _start_ceremony() -> void:
	_ceremony_t = 0.0
	_announced = false
	Audio.play("contest_horn", _venue_point(), 4.0, 0.0, &"Effects", 40.0)
	ceremony_started.emit()


func _ceremony(dt: float) -> void:
	var prev := _ceremony_t
	_ceremony_t += dt
	if prev < APPLAUSE_AT and _ceremony_t >= APPLAUSE_AT:
		Audio.play("applause", _venue_point() + Vector3(0, 1.5, -6.0), 2.0, 0.0, &"Effects", 30.0)
	if not _announced and _ceremony_t >= ANNOUNCE_AT:
		_announced = true
		_settle(true)
	if _ceremony_t >= CEREMONY_LEN:
		_ceremony_t = -1.0
		finished.emit()


## Names the winner of the contest held on day_held and gives the player his prize when
## it is him; `loud`: at the pond (a banner and the fanfare), else a note.
func _settle(loud: bool) -> void:
	if result_day == day_held:
		return
	result_day = day_held
	# A rival who never landed one still weighs in with the fish in his keepnet.
	for id: StringName in RIVALS:
		if not entries.has(String(id)):
			var c := rival_catch(id)
			if not c.is_empty():
				entries[String(id)] = {"kg": float(c["kg"]), "fish": String(c["id"])}
	var s := standings()
	if s.is_empty():
		return
	var top: Array = s[0]
	last_winner = {"id": top[0], "kg": float(top[1]), "fish": String(top[2])}
	board_changed.emit()
	var weight := FloppingFish.weight_text(float(top[1]))
	if top[0] == "player":
		Achievements.unlock(ACHIEVEMENT)
		Economy.add_money(PRIZE_MONEY, "REPORT_PRIZE")
		var left := PlayerState.give(PRIZE_FISH_ID, PRIZE_FISH, false)
		if left > 0:
			FarmState.warehouse.add(PRIZE_FISH_ID, left)
			Game.notify(tr("MSG_CONTEST_PRIZE_STORED") % left, UiTheme.GOLD_SOFT)
		var text := tr("CONTEST_WIN_TEXT") % [_fish_name(top[2]), weight, PRIZE_MONEY, PRIZE_FISH]
		if loud:
			_show_banner(tr("CONTEST_WIN_TITLE"), text, "star")
			Audio.ui("fanfare", -2.0)
		else:
			Game.notify(tr("CONTEST_WIN_TITLE") + " " + text, UiTheme.GOLD)
	else:
		var text := tr("CONTEST_LOSE_TEXT") % [entrant_name(top[0]), _fish_name(top[2]), weight]
		if loud:
			_show_banner(tr("CONTEST_LOSE_TITLE"), text, "star")
			Audio.ui("fanfare", -8.0)
		else:
			Game.notify(text, UiTheme.GOLD_SOFT)


# --- The crowd's voices and the side goal ----------------------------------------------------

## The murmur's level at the pond now (0..1): while the town is out there.
func crowd_level() -> float:
	return MURMUR if crowd_out() else 0.0


## Where the crowd's murmur comes from: over the middle of the pond (they stand all round).
func crowd_point() -> Vector3:
	var c := WorldLayout.TOWN_POND_CENTER
	return Vector3(c.x, WorldLayout.WATER_LEVEL + 1.6, c.y)


## Now and then someone in the crowd calls out or laughs (from where one of them stands).
func _crowd_calls(delta: float) -> void:
	_call_t -= delta
	if _call_t > 0.0:
		return
	_call_t = _rng.randf_range(CALL_EVERY.x, CALL_EVERY.y)
	if _player_distance() > CALL_RADIUS:
		return
	var venue := get_tree().get_first_node_in_group(ContestVenue.GROUP) as ContestVenue
	var at := crowd_point()
	if venue and not venue.crowd_spots.is_empty():
		at = (venue.crowd_spots[_rng.randi() % venue.crowd_spots.size()]["pos"] as Vector3) + Vector3(0, 1.6, 0)
	Audio.play("crowd_call", at, -7.0, 0.1, &"Effects", 4.0)


## The side goal on a contest day: up from the morning, its dot over the pond, until he
## comes to it while the contest is on (or it is over); quiet after the first contest.
func _update_goal() -> void:
	var up := is_today() and GameClock.minute < END_MINUTE and goal_day != GameClock.day
	if up and is_on() and _player_distance() < VENUE_RADIUS:
		_goal_done()
		return
	if not up:
		if SideStory.goals.has(_goal):
			SideStory.remove_goal(_goal)
		return
	if not SideStory.goals.has(_goal):
		_goal.title = tr("SIDE_CONTEST_TITLE")
		_goal.quiet = result_day > 0
		SideStory.add_goal(_goal)
		Game.notify(tr("MSG_SIDE_NEW") % tr("SIDE_GOAL_CONTEST"), GOAL_COLOR)
	var hint := tr("SIDE_HINT_CONTEST_ON") % _clock(END_MINUTE) if is_on() else tr("SIDE_HINT_CONTEST_SOON") % _clock(START_MINUTE)
	var c := WorldLayout.TOWN_POND_CENTER
	_goal.set_goal(tr("SIDE_GOAL_CONTEST"), hint, Vector3(c.x, WorldLayout.WATER_LEVEL + 1.2, c.y), tr("SIDE_LABEL_CONTEST"))


## The contest the getting-ready goal is for now: tomorrow's from PREP_MINUTE on, today's
## until it starts (0: none, or not in this run).
func prep_for() -> int:
	if not enabled() or (DebugTools.is_automated() and not prep_testing):
		return 0
	var d := GameClock.day
	if is_contest_day(d + 1) and GameClock.minute >= PREP_MINUTE:
		return d + 1
	if is_contest_day(d) and GameClock.minute < START_MINUTE:
		return d
	return 0


## The getting-ready goal: what he has of the rod and the bait on its card, its dot at
## what is missing; a done line the day before once he has it all, gone on the contest's
## morning then, and at its start whatever he has. (All set from the start: never up.)
func _update_prep() -> void:
	var contest := prep_for()
	var up := SideStory.goals.has(_prep)
	if contest == 0:
		if up:
			SideStory.remove_goal(_prep)
		return
	var rods := Quests._rod_count()
	var bait := Quests._bait_count()
	var ready := rods > 0 and bait >= PREP_BAIT
	# All set before the goal ever came up, or on the contest's own morning: no card.
	if ready and (not up or contest == GameClock.day):
		if up:
			SideStory.remove_goal(_prep)
			_prep_told(contest)
		return
	if not up:
		_prep.title = tr("SIDE_CONTEST_TITLE")
		_prep.quiet = result_day > 0
		SideStory.add_goal(_prep)
		Game.notify(tr("MSG_SIDE_NEW") % tr("SIDE_GOAL_CONTEST_PREP"), GOAL_COLOR)
	_prep.set_needs("%s · %s" % [Quests.need_part(tr("CONTEST_PREP_ROD"), rods, 1), Quests.need_part(tr("CONTEST_PREP_BAIT"), bait, PREP_BAIT)])
	var hint := ""
	var at: Variant = null
	var label := ""
	if rods == 0:
		# A rod is made at the workbench (the dot: the bench; with none yet, the way to one).
		var bench: Dictionary = Quests.place_for("bench")
		hint = tr("SIDE_HINT_PREP_ROD")
		at = bench["at"]
		label = tr("PROJECT_WORKBENCH") if String(bench["hint"]) == "" else ""
	elif bait < PREP_BAIT:
		var price := Economy.buy_price(&"worm") * (PREP_BAIT - bait)
		if Economy.money < price:
			var short: Dictionary = Quests.money_short(price)
			hint = String(short["hint"])
			at = short["at"]
		else:
			hint = tr("SIDE_HINT_PREP_BAIT")
			at = Quests.place_for("market")["at"]
			label = tr("UI_TOWN_MARKET")
	else:
		hint = tr("SIDE_HINT_PREP_READY") % _clock(START_MINUTE)
		_prep_told(contest)
	_prep.set_goal(tr("SIDE_GOAL_CONTEST_PREP"), hint, at, label if at != null else "")


## He has the rod and the bait for the contest on day `contest`: a note, once.
func _prep_told(contest: int) -> void:
	if prep_day == contest:
		return
	prep_day = contest
	Game.notify(tr("MSG_SIDE_DONE") % tr("SIDE_GOAL_CONTEST_PREP"), UiTheme.GOLD)
	Audio.ui("confirm", -6.0)


## The getting-ready goal is up (tests).
func prep_up() -> bool:
	return SideStory.goals.has(_prep)


func prep_goal() -> SideGoal:
	return _prep


## He came to the contest (or landed a fish there): today's goal is done.
func _goal_done() -> void:
	if goal_day == GameClock.day:
		return
	goal_day = GameClock.day
	if SideStory.goals.has(_goal):
		SideStory.remove_goal(_goal)
		Game.notify(tr("MSG_SIDE_DONE") % tr("SIDE_GOAL_CONTEST"), UiTheme.GOLD)


## Today's side goal is up (tests).
func goal_up() -> bool:
	return SideStory.goals.has(_goal)


func goal() -> SideGoal:
	return _goal


func _venue_point() -> Vector3:
	var c := WorldLayout.TOWN_POND_CENTER
	return Vector3(c.x, WorldLayout.WATER_LEVEL + 1.0, c.y - WorldLayout.TOWN_POND_RADIUS)


func _show_banner(title: String, line: String, glyph: String) -> void:
	var hud := Game.hud as HUD
	if hud == null:
		return
	var banner := NewsBanner.new()
	var parent: Node = hud.get_node_or_null("Root")
	(parent if parent else hud).add_child(banner)
	banner.play(tr("CONTEST_BANNER_KICKER"), title, line, glyph, UiTheme.GOLD)
	Audio.ui("confirm", -4.0)


# --- The HUD card ----------------------------------------------------------------------------

## A small card under the clock while the player is at the pond during the contest.
func _update_card(delta: float) -> void:
	_card_t -= delta
	var want := (is_on() or _ceremony_t >= 0.0) and _player_distance() < VENUE_RADIUS + 8.0
	var hud := Game.hud as HUD
	if not want or hud == null:
		if _card and is_instance_valid(_card):
			_card.visible = false
		return
	if _card == null or not is_instance_valid(_card):
		_build_card(hud)
	_card.visible = true
	if _card_t <= 0.0:
		_card_t = 0.5
		_card_label.text = board_text(false)
		var clock_card := hud.get("_clock_card") as Control
		if clock_card:
			_card.offset_top = clock_card.get_global_rect().end.y - hud.get_node("Root").get_global_rect().position.y + 12.0


func _build_card(hud: HUD) -> void:
	_card = GlassPanel.new(Vector4(18, 12, 20, 14), 16.0)
	_card.name = "ContestCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = -28
	_card.offset_right = -28
	_card.offset_top = 190
	var parent: Node = hud.get_node_or_null("Root")
	(parent if parent else hud).add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var fish := ItemDB.get_item(&"fish_carp")
	head.add_child(UiTheme.icon_rect(fish.icon if fish else UiTheme.glyph("star"), 24))
	head.add_child(UiTheme.make_label(UiTheme.caps(tr("CONTEST_HUD_TITLE") % _clock(END_MINUTE)),
			UiTheme.heading(14, UiTheme.GOLD_SOFT, 700, 2)))
	_card_label = UiTheme.make_label("", UiTheme.heading(17, UiTheme.TEXT, 600, 0))
	col.add_child(_card_label)


# --- The letter ------------------------------------------------------------------------------

## The letter opens a moment after the player is free (as Beyza's does).
func _update_letter(delta: float) -> void:
	if not letter_pending:
		return
	if not enabled() or not is_contest_day(GameClock.day + 1):
		letter_pending = false
		return
	if DebugTools.is_automated() and not testing_letter:
		return
	var hud := Game.hud as HUD
	var player := Game.player as Player
	if hud == null or Game.is_ui_open() or hud.sleep_screen.is_busy() or (player and player.driving != null):
		_letter_wait = LETTER_DELAY
		return
	if not _letter_noted:
		_letter_noted = true
		Game.notify(tr("MSG_CONTEST_LETTER"), UiTheme.GOLD_SOFT)
		Audio.ui("notify", -6.0)
	_letter_wait -= delta
	if _letter_wait <= 0.0:
		open_letter()


## Delivers the letter now (and marks it read): into the mailbox when there is one, else
## on the letter sheet.
func open_letter() -> void:
	letter_pending = false
	letter_day = GameClock.day
	var args := letter_args()
	var mail := get_node_or_null("/root/Mail")
	if mail and mail.has_method("send") and _send_mail(mail, args):
		return
	var hud := Game.hud as HUD
	if hud:
		hud.letter_screen.open("contest", args)


## The mailbox's send(): a letter as a dictionary (sender, title, body, day). False when
## its send() takes something else (the letter sheet shows it instead).
func _send_mail(mail: Node, args: Dictionary) -> bool:
	for m: Dictionary in mail.get_method_list():
		if m["name"] == "send" and (m["args"] as Array).size() == 1:
			mail.call("send", {"id": "contest_%d" % (GameClock.day + 1), "from": tr("LETTER_CONTEST_SIGN"),
				"title": tr("LETTER_CONTEST_TITLE"), "body": tr("LETTER_CONTEST_BODY").format(args).replace("|", "\n\n"),
				"day": GameClock.day})
			return true
	return false


## The letter's {start}, {end}, {money}, {fish}.
static func letter_args() -> Dictionary:
	return {"start": _clock(START_MINUTE), "end": _clock(END_MINUTE), "money": PRIZE_MONEY, "fish": PRIZE_FISH}


static func _clock(minute: int) -> String:
	return "%02d:%02d" % [floori(minute / 60.0), minute % 60]


func _on_day_started(d: int) -> void:
	_on = false
	_letter_noted = false
	_letter_wait = LETTER_DELAY
	letter_pending = enabled() and is_contest_day(d + 1) and letter_day != d


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	return {"entries": entries.duplicate(true), "day_held": day_held, "result_day": result_day,
		"last_winner": last_winner.duplicate(), "letter_day": letter_day, "goal_day": goal_day, "prep_day": prep_day,
		"cast": _cast.duplicate(), "next_catch": _next_catch.duplicate()}


## After GameClock.load_data: the board as saved, the rivals' casts and next fish with it
## (nothing is fished again that was fished before the save); a morning before a contest
## whose letter wasn't read yet brings it.
func load_data(data: Dictionary) -> void:
	entries = (data.get("entries", {}) as Dictionary).duplicate(true)
	day_held = int(data.get("day_held", 0))
	result_day = int(data.get("result_day", 0))
	last_winner = (data.get("last_winner", {}) as Dictionary).duplicate()
	letter_day = int(data.get("letter_day", 0))
	goal_day = int(data.get("goal_day", 0))
	prep_day = int(data.get("prep_day", 0))
	_goal_t = 0.0
	# Loaded mid-contest: no opening banner again.
	_on = is_on()
	_ceremony_t = -1.0
	_next_catch = (data.get("next_catch", {}) as Dictionary).duplicate()
	_cast = (data.get("cast", {}) as Dictionary).duplicate()
	_away.clear()
	# (an older save made in the middle of a contest: the waits start again from now)
	_cast_floor = GameClock.minute if _on and day_held == GameClock.day and not data.has("cast") else 0.0
	_letter_noted = false
	_letter_wait = LETTER_DELAY
	letter_pending = enabled() and is_contest_day(GameClock.day + 1) and letter_day != GameClock.day
	board_changed.emit()
