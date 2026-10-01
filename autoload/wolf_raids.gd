extends Node
## Wolf raids: now and then at night wolves come down out of the forest round the valley
## for the farm's animals. Never into town, never by day; they are gone by dawn.
##
## The first raid is a lesson, on LESSON_NIGHT (the third night; the first night after
## it with animals on the farm): from HOWL_MINUTE intense howling far off, at NOTE_MINUTE
## a note and a side goal (SideStory.goals): shut the coop door once every bird is in,
## then go home and sleep (the dot on the coop door, then on the bed). The pack comes at
## ARRIVE_MINUTE. Later raids come on random nights, roughly every 4 to 7 (RARE_GAP when
## Settings.wolf_raids is RARE, none when it is OFF), never two in a row, likelier with a
## bigger herd, in winter and at full moon (raid_chance); howls and a short note warn of
## them earlier in the evening (EARLY_HOWL, EARLY_NOTE). A night whose note never came
## (the farmer was asleep by then, even with the howls begun) has no raid: the lesson
## waits for the next night.
##
## They take what they can get to (can_reach): animals out in the night, in an open pen
## (a fence keeps no wolf out), in a coop whose door stands open; not one in a closed
## building or by a burning campfire. Losses are capped (one killed and one hurt a night;
## one in all on the lesson night) and come by species (KILL_CHANCE): a bird is mostly
## killed, a sheep often only hurt, a cow or a horse only ever hurt.
##
## Awake, the raid plays out: PACK wolves (Wolf.spawn) from the forest edge nearest the
## animals, sent by set_goal at the animals they can reach and at the farmer when he is
## out near them; a bite (bit) on an animal kills it or hurts it (Animals.kill / injure). A wolf killed scatters the rest; a farmer in a vehicle they
## give up on; with nothing left to take they prowl a while (LINGER) and go. Asleep (or
## knocked out, Events.player_knocked_out) the rest of the night is worked out the same
## way as the time is skipped. The morning report says what happened (take_report).
## The first hurt animal brings the vet's side goal: have it treated in town.
## Automated runs (tests, screenshots) bring no wolves unless the run asks (`--raids`, or
## `testing` set by the raids scenario).

## The lesson's night, and the hours of the evening (game minutes from midnight):
## tonight's raid is decided from ROLL_MINUTE; distant howls from HOWL_MINUTE, the note at
## NOTE_MINUTE (later raids an hour earlier: EARLY_*), the pack at ARRIVE_MINUTE. They
## have gone by LEAVE_MINUTE (04:00; nobody stays up past 02:00 anyway).
const LESSON_NIGHT := 3
const ROLL_MINUTE := 18 * 60
const HOWL_MINUTE := 20 * 60 + 30
const NOTE_MINUTE := 21 * 60
const EARLY_HOWL := 19 * 60 + 30
const EARLY_NOTE := 20 * 60
const ARRIVE_MINUTE := 23 * 60
const LEAVE_MINUTE := 28 * 60
## Nights from one raid to the next: none before the first number, certain by the second
## (each night between likelier than the last).
const NORMAL_GAP := Vector2i(4, 7)
const RARE_GAP := Vector2i(8, 13)
## A herd this big (or bigger) makes a raid likelier by the factor beside it; so do
## winter and the full moon.
const HERD_ODDS := [[15, 1.5], [8, 1.25]]
const WINTER_ODDS := 1.3
const MOON_ODDS := 1.6
## A night's most losses (KILLED + HURT), and the lesson night's (in all).
const MAX_KILLED := 1
const MAX_HURT := 1
const LESSON_LOSSES := 1
## The chance a bite kills (else it hurts) by species.
const KILL_CHANCE := {&"chicken": 0.7, &"rooster": 0.7, &"sheep": 0.4, &"cow": 0.0, &"horse": 0.0}
## Who they go for first while the farmer sleeps (weights): small ones, then sheep.
const PREY_WEIGHT := {&"chicken": 3.0, &"rooster": 3.0, &"sheep": 2.0, &"cow": 1.0, &"horse": 1.0}
## Wolves in a pack (the lesson's is the smaller).
const PACK := Vector2i(3, 4)
## Metres: a burning campfire keeps them this far off; the farmer this close to one of them
## (out in the open) is attacked; animals this close to one bolt.
const FIRE_SAFE := 6.0
const PLAYER_RANGE := 25.0
const SPOOK_RADIUS := 7.0
## Where they come out of the forest (metres from the valley's middle), how far short of
## the animals they gather first, and when they count as there.
const EDGE := WorldLayout.VALLEY_RADIUS - 6.0
const APPROACH_BACK := 20.0
const ARRIVE_NEAR := 9.0
## Game minutes they prowl with nothing (more) to take before they go.
const LINGER := 60.0
## Seconds between the pack's orders.
const THINK := 0.5
## The colours of the side goals: the wolves' (the lesson, the note), the vet's.
const AMBER := Color("f0a65a")
const TEAL := Color("74cdb9")

## Saved: the lesson was given; the vet's lesson done; the day of the last raid's night;
## the last day tonight's raid was decided; tonight's raid ({} for none: see _set_tonight);
## lines for the morning report (take_report).
var lesson_done := false
var vet_lesson_done := false
var last_raid_day := -100
var rolled_day := 0
var tonight := {}
var report := PackedStringArray()
## Set by the raids scenario: raids come in this automated run.
var testing := false
## Distant howls asked for (Wolf.play_distant_howls) and the last one's intensity (tests).
var howls_asked := 0
var last_howl := 0.0

var _rng := RandomNumberGenerator.new()
## The wolves out tonight (alive, not yet given up), and the last order each was given.
var _wolves: Array[Node3D] = []
var _orders := {}
var _think := 0.0
var _howl_wait := 0.0
var _arrived := false
var _arrive_time := 0.0
## Game minutes since the pack has had nothing to do (-1: busy).
var _idle_from := -1.0
## Where the animals are (the pack's goal) and where it gathers first.
var _area := Vector3.ZERO
var _approach := Vector3.ZERO
## Ids of the animals the wolves could get to as the farmer went to bed (day_ending).
var _sleep_targets: Variant = null
var _goal_wait := 0.0
## The lesson goal's step ("door" / "sleep").
var _lesson_step := ""
var _wolf_goal: SideGoal
var _vet_goal: SideGoal


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_wolf_goal = SideGoal.new(&"wolves", "", "moon", AMBER)
	_vet_goal = SideGoal.new(&"vet", "", "health", TEAL)
	Events.day_ending.connect(_on_day_ending)
	Events.time_skipped.connect(_on_time_skipped)
	Events.day_started.connect(_on_day_started)
	Animals.vet_visit.connect(_on_vet_visit)
	Settings.changed.connect(_on_settings)
	Events.player_knocked_out.connect(_on_knocked_out)


## Raids come in this run (the setting; automated runs only when asked).
func enabled() -> bool:
	if Settings.wolf_raids == Settings.Raids.OFF:
		return false
	return testing or not DebugTools.is_automated() or DebugTools.args.has("raids")


## The wolves out on the farm now.
func wolves() -> Array[Node3D]:
	var out: Array[Node3D] = []
	out.assign(_wolves.filter(func(w: Variant) -> bool: return is_instance_valid(w) and not (w as Node3D).is_queued_for_deletion()))
	return out


## A raid tonight that has not ended yet.
func raid_pending() -> bool:
	return not tonight.is_empty() and String(tonight.get("phase", "")) != "done"


## The morning report's lines about the night (cleared once taken: the sleep screen).
func take_report() -> PackedStringArray:
	var out := report
	report = PackedStringArray()
	return out


# --- Which nights ------------------------------------------------------------------------------

## The chance of a raid tonight, `gap` nights after the last one (raid_chance(gap) > 0 only
## from the gap's first night; never two in a row).
func raid_chance(gap: int, day := -1) -> float:
	if day < 0:
		day = GameClock.day
	var span := RARE_GAP if Settings.wolf_raids == Settings.Raids.RARE else NORMAL_GAP
	if gap < maxi(span.x, 2):
		return 0.0
	if gap >= span.y:
		return 1.0
	var p := float(gap - span.x + 1) / float(span.y - span.x + 1)
	var herd := _herd()
	for step: Array in HERD_ODDS:
		if herd >= int(step[0]):
			p *= float(step[1])
			break
	if (floori((day - 1) / float(GameClock.DAYS_PER_SEASON)) % 4) == GameClock.Season.WINTER:
		p *= WINTER_ODDS
	if full_moon(day):
		p *= MOON_ODDS
	return minf(p, 1.0)


## The moon is full on `day`'s night (DayNightCycle.moon_phase).
static func full_moon(day: int) -> bool:
	return DayNightCycle.moon_phase(day) > PI * 0.97


## Animals on the farm (not at the vet's clinic).
func _herd() -> int:
	var n := 0
	for a in Animals.animals:
		if not a.at_vet():
			n += 1
	return n


## Once each evening (from ROLL_MINUTE): is tonight a raid's night?
func _schedule() -> void:
	if not tonight.is_empty() or not enabled() or rolled_day == GameClock.day:
		return
	var m := GameClock.minute
	if m < ROLL_MINUTE or m >= ARRIVE_MINUTE - 30:
		return
	rolled_day = GameClock.day
	if _herd() == 0:
		return
	if not lesson_done:
		if GameClock.day >= LESSON_NIGHT:
			_set_tonight(true)
		return
	if _rng.randf() < raid_chance(GameClock.day - last_raid_day):
		_set_tonight(false)


## Tonight's raid: when it is heard, noted and comes (GameClock.total_minutes), what it has
## taken so far, whether the farmer fainted or killed a wolf.
func _set_tonight(lesson: bool) -> void:
	var midnight := GameClock.total_minutes - GameClock.minute
	tonight = {"day": GameClock.day, "lesson": lesson, "phase": "set",
		"howl": midnight + (HOWL_MINUTE if lesson else EARLY_HOWL), "note": midnight + (NOTE_MINUTE if lesson else EARLY_NOTE),
		"at": midnight + ARRIVE_MINUTE, "leave": midnight + LEAVE_MINUTE, "noted": false,
		"killed": 0, "hurt": 0, "victims": [], "fainted": false, "wolf_killed": false,
		"pack": PACK.x if lesson else _rng.randi_range(PACK.x, PACK.y)}
	# What wolves leave behind is drawn in the background now (no stall at a death).
	Remains.prepare()


# --- The night -----------------------------------------------------------------------------------

## Nothing moves on while the game is paused (the pause menu, the settings: the wolves
## stand frozen too, Wolf.frozen), so the howls and the pack's orders wait.
func _process(delta: float) -> void:
	if SaveGame.loading or Wolf.frozen() or Game.world == null or Game.player == null or not is_instance_valid(Game.player):
		return
	_schedule()
	_update_night(delta)
	_goal_wait -= delta
	if _goal_wait <= 0.0:
		_goal_wait = 0.25
		_update_goals()


func _update_night(delta: float) -> void:
	if tonight.is_empty():
		return
	var now := GameClock.total_minutes
	match String(tonight["phase"]):
		"set":
			if now >= float(tonight["howl"]):
				tonight["phase"] = "warned"
				_howl_wait = 0.0
		"warned":
			if not bool(tonight["noted"]) and now >= float(tonight["note"]):
				_give_note()
			_howl(delta, now)
			if now >= float(tonight["at"]):
				_arrive()
		"active":
			_drive_pack(delta)


## Howling far off, building up toward the pack's coming (the lesson's from the start).
func _howl(delta: float, now: float) -> void:
	_howl_wait -= delta
	if _howl_wait > 0.0:
		return
	var t := clampf((now - float(tonight["howl"])) / maxf(float(tonight["at"]) - float(tonight["howl"]), 1.0), 0.0, 1.0)
	var intensity := lerpf(0.6 if bool(tonight["lesson"]) else 0.35, 1.0, t)
	_howl_wait = _rng.randf_range(10.0, 22.0) * lerpf(1.3, 0.7, t)
	play_distant_howls(intensity)


## Wolves howling far off (the wolf's own sounds: Wolf.play_distant_howls).
func play_distant_howls(intensity: float) -> void:
	howls_asked += 1
	last_howl = intensity
	Wolf.play_distant_howls(intensity)


## The evening's note (the lesson's goals come up with it, _update_goals).
func _give_note() -> void:
	tonight["noted"] = true
	Game.notify(tr("MSG_WOLVES_LESSON") if bool(tonight["lesson"]) else tr("MSG_WOLVES_TONIGHT"), AMBER)
	Audio.ui("notify", -6.0)


## The pack comes out of the forest edge nearest the animals and gathers short of them.
func _arrive() -> void:
	tonight["phase"] = "active"
	_area = _target_area()
	var edge := _forest_edge(_area)
	var back := edge - _area
	back.y = 0.0
	_approach = _area + back.normalized() * minf(APPROACH_BACK, back.length() * 0.5)
	_wolves.clear()
	_orders.clear()
	for i in int(tonight["pack"]):
		var at := edge + Vector3(_rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-3.0, 3.0))
		var w := _spawn_wolf(at)
		if w:
			_order(w, &"approach", _approach + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5)))
	_arrived = false
	_arrive_time = 0.0
	_idle_from = -1.0
	_think = 0.0
	play_distant_howls(1.0)


func _spawn_wolf(at: Vector3) -> Wolf:
	var wolf := Wolf.spawn(Game.world, at)
	wolf.bit.connect(_on_bit.bind(wolf))
	wolf.died.connect(_on_wolf_died)
	wolf.gave_up.connect(_on_gave_up)
	_wolves.append(wolf)
	return wolf


## Gives wolf `w` an order when it is a new one (the wolf keeps on at the last otherwise).
func _order(w: Node3D, goal: StringName, target: Variant = null) -> void:
	var last: Array = _orders.get(w, [])
	if not last.is_empty() and last[0] == goal:
		var same := false
		if target is Vector3 and last[1] is Vector3:
			same = (target as Vector3).distance_to(last[1]) < 1.0
		elif typeof(target) == TYPE_OBJECT and typeof(last[1]) == TYPE_OBJECT:
			same = is_same(target, last[1])
		if same:
			return
	_orders[w] = [goal, target]
	(w as Wolf).set_goal(goal, target)


## The raid while the farmer is awake: who goes for what, every THINK seconds.
func _drive_pack(delta: float) -> void:
	_arrive_time += delta
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK
	var live := wolves()
	_wolves = live
	if live.is_empty() and not bool(tonight.get("again", false)) and GameClock.total_minutes < float(tonight["leave"]):
		# Gone with the scene (the game rebuilt for a new language): the pack comes again.
		tonight["again"] = true
		_arrive()
		return
	if live.is_empty() or GameClock.total_minutes >= float(tonight["leave"]):
		_end_raid()
		return
	if not _arrived:
		for w in live:
			if _flat(w.global_position, _approach) < ARRIVE_NEAR:
				_arrived = true
		if not _arrived and _arrive_time < 40.0:
			return
		_arrived = true
	var targets := _target_nodes()
	var player := _exposed_player(live)
	var hunting := 0
	for w in live:
		Animals.spook(w.global_position, SPOOK_RADIUS)
		if not targets.is_empty() and (hunting < 2 or player == null):
			_order(w, &"hunt", _nearest(targets, w.global_position))
			hunting += 1
		elif player != null:
			_order(w, &"attack_player", player)
		else:
			_order(w, &"prowl", _area)
	# Nothing (more) to take and nobody to go for: a while longer, then they go.
	if targets.is_empty() and player == null:
		if _idle_from < 0.0:
			_idle_from = GameClock.total_minutes
		elif GameClock.total_minutes - _idle_from >= LINGER:
			_end_raid()
	else:
		_idle_from = -1.0


## A bite landed (Wolf.bit): on a farm animal it kills or hurts it (the night's caps); on
## the farmer the wolf has hurt him itself.
func _on_bit(target: Node3D, wolf: Node3D) -> void:
	if not raid_pending() or String(tonight["phase"]) != "active":
		return
	var animal := target as Animal
	if animal == null or animal.data == null:
		return
	var at := animal.global_position
	if bite(animal.data.id, true) != &"" and is_instance_valid(wolf):
		# Done with that one: round the spot a while.
		_order(wolf, &"prowl", at)


## A wolf takes animal `id` (awake: with a word on screen): killed or hurt by its species
## within the night's caps. Returns &"kill", &"hurt" or &"" (nothing more to take; one hurt
## already is left be: the farmer has it to look after).
func bite(id: int, awake := false) -> StringName:
	var a := Animals.by_id(id)
	if a == null or a.injured() or tonight.is_empty() or (tonight["victims"] as Array).has(id):
		return &""
	var outcome := _outcome(a.species)
	if outcome == &"":
		return &""
	(tonight["victims"] as Array).append(id)
	var who := [a.name, Animals.species_name(a.species, a.adult)]
	var line: String
	if outcome == &"kill":
		tonight["killed"] = int(tonight["killed"]) + 1
		line = tr("REPORT_WOLF_KILLED") % who
		Animals.kill(id, &"wolf")
	else:
		tonight["hurt"] = int(tonight["hurt"]) + 1
		line = tr("REPORT_WOLF_HURT") % who
		Animals.injure(id)
	report.append(line)
	if awake:
		Game.notify(line, Color(1.0, 0.45, 0.35))
	return outcome


## What a bite on a `species` does now: &"kill", &"hurt" or &"" (the night's caps are met).
func _outcome(species: StringName) -> StringName:
	var k := int(tonight.get("killed", 0))
	var h := int(tonight.get("hurt", 0))
	var can_kill := k < MAX_KILLED
	var can_hurt := h < MAX_HURT
	if bool(tonight.get("lesson", false)):
		can_kill = k + h < LESSON_LOSSES
		can_hurt = can_kill
	var p := float(KILL_CHANCE.get(species, 0.0))
	if can_kill and p > 0.0 and (_rng.randf() < p or not can_hurt):
		return &"kill"
	return &"hurt" if can_hurt else &""


## Whether a bite on a `species` could still do anything tonight.
func _can_take(species: StringName) -> bool:
	var k := int(tonight.get("killed", 0))
	var h := int(tonight.get("hurt", 0))
	if bool(tonight.get("lesson", false)):
		return k + h < LESSON_LOSSES
	return h < MAX_HURT or (k < MAX_KILLED and float(KILL_CHANCE.get(species, 0.0)) > 0.0)


func _on_wolf_died(wolf: Node3D) -> void:
	_wolves.erase(wolf)
	_orders.erase(wolf)
	if not raid_pending():
		return
	tonight["wolf_killed"] = true
	report.append(tr("REPORT_WOLF_SLAIN"))
	Game.notify(tr("MSG_WOLF_PACK_FLED"), AMBER)
	_end_raid()


func _on_gave_up(wolf: Node3D) -> void:
	_wolves.erase(wolf)
	_orders.erase(wolf)
	if raid_pending() and String(tonight["phase"]) == "active" and wolves().is_empty():
		_end_raid()


## The pack goes (back into the forest), the night's lines go to the morning report.
func _end_raid() -> void:
	if not raid_pending():
		return
	for w in wolves():
		_order(w, &"flee", _flee_point(w.global_position))
	_wolves.clear()
	_orders.clear()
	tonight["phase"] = "done"
	_close_night()
	if not bool(tonight["wolf_killed"]) and not bool(tonight["fainted"]):
		Game.notify(tr("MSG_WOLVES_LEFT"), AMBER)


## The night's raid is over: remembered, and its last lines for the morning.
func _close_night() -> void:
	last_raid_day = int(tonight["day"])
	if int(tonight["killed"]) + int(tonight["hurt"]) == 0:
		report.append(tr("REPORT_WOLVES_SAFE"))
	if bool(tonight["lesson"]):
		lesson_done = true
		report.append(tr("REPORT_WOLVES_LATER"))


## Wolves out tonight gone at once (the night is skipped).
func _clear_wolves() -> void:
	for w in wolves():
		w.queue_free()
	_wolves.clear()
	_orders.clear()


# --- Asleep, or knocked out ------------------------------------------------------------------

## Going to bed (or carried there): who the wolves can get to tonight; the pack out now
## leaves the farmer be (the skip works the rest out).
func _on_day_ending() -> void:
	if not raid_pending():
		return
	_sleep_targets = _target_ids()
	if String(tonight["phase"]) == "active":
		_clear_wolves()
		tonight["phase"] = "asleep"


## The farmer fainted from the wolves' bites: they leave him; the night goes on without
## him (the skip that follows works it out). The morning report's own line says he fainted
## (SleepScreen: REPORT_KNOCKED_OUT).
func _on_knocked_out() -> void:
	if not raid_pending():
		return
	tonight["fainted"] = true
	for w in wolves():
		_order(w, &"flee", _flee_point(w.global_position))
	_wolves.clear()
	_orders.clear()
	if String(tonight["phase"]) == "active":
		tonight["phase"] = "asleep"


## The night skipped (sleep, a faint): a raid that was warned of happens all the same, as
## it would have with the farmer awake; one he went to bed before the note of (the howls
## only just begun, or not yet) doesn't, so the lesson is never spent on a loss he was
## never told how to prevent: it comes the next night.
func _on_time_skipped(_minutes: float) -> void:
	if not raid_pending():
		_sleep_targets = null
		return
	if String(tonight["phase"]) == "set" or not bool(tonight.get("noted", false)):
		tonight = {}
		_sleep_targets = null
		return
	_clear_wolves()
	resolve_night()


## Works out the rest of tonight's raid at once: they take what they could get to (as
## the farmer went to bed) up to the night's caps, the smaller ones first.
func resolve_night() -> void:
	if not raid_pending():
		return
	var ids: Array = _sleep_targets if _sleep_targets != null else _target_ids()
	_sleep_targets = null
	ids = ids.filter(func(id: int) -> bool:
		var a := Animals.by_id(id)
		return a != null and not a.injured() and not (tonight["victims"] as Array).has(id))
	while not ids.is_empty():
		var id := _pick(ids)
		ids.erase(id)
		var a := Animals.by_id(id)
		if a and _can_take(a.species):
			bite(id)
	tonight["phase"] = "done"
	_close_night()


## One of `ids`, the smaller animals likelier (PREY_WEIGHT); on the lesson night not the
## rooster (just bought for the hens) while there is anything else.
func _pick(ids: Array) -> int:
	if bool(tonight.get("lesson", false)):
		var spared := ids.filter(func(id: int) -> bool: return Animals.by_id(id).species != &"rooster")
		if not spared.is_empty():
			ids = spared
	var total := 0.0
	for id: int in ids:
		total += float(PREY_WEIGHT.get(Animals.by_id(id).species, 1.0))
	var r := _rng.randf() * total
	for id: int in ids:
		r -= float(PREY_WEIGHT.get(Animals.by_id(id).species, 1.0))
		if r <= 0.0:
			return id
	return ids.back()


func _on_day_started(_day: int) -> void:
	if not tonight.is_empty() and String(tonight["phase"]) == "done" and GameClock.day > int(tonight["day"]):
		tonight = {}
	_lesson_step = ""


func _on_settings() -> void:
	if enabled() or tonight.is_empty():
		return
	# Turned off: tonight's wolves go back, nothing comes of it.
	for w in wolves():
		_order(w, &"flee", _flee_point(w.global_position))
	_wolves.clear()
	_orders.clear()
	tonight = {}


# --- What they can get to --------------------------------------------------------------------

## Whether the wolves can get to animal `a`: out in the night, in an open pen, in a coop
## with its door open; not in a closed building, not by a burning campfire, not at the
## clinic, ridden or still in its egg.
func can_reach(a: AnimalData) -> bool:
	if a == null or a.at_vet():
		return false
	var n := Animals.node_of(a)
	if n == null or n.ridden or n.state == Animal.State.HATCH or not n.visible:
		return false
	var h := n.housing
	if n.indoors and h and h.has_shelter() and not (h.placed and h.door_open):
		return false
	return not near_fire(n.global_position)


## A burning campfire within FIRE_SAFE of `p`.
func near_fire(p: Vector3) -> bool:
	for f in get_tree().get_nodes_in_group(&"campfires"):
		var fire := f as Node3D
		if fire and fire.has_method("is_burning") and fire.is_burning() and _flat(fire.global_position, p) < FIRE_SAFE:
			return true
	return false


func _target_ids() -> Array:
	var out := []
	for a in Animals.animals:
		if can_reach(a):
			out.append(a.id)
	return out


## The bodies of the animals still to take (reachable, not bitten yet, something left to do;
## on the lesson night the rooster only when nothing else is there).
func _target_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var victims: Array = tonight.get("victims", [])
	for a in Animals.animals:
		if victims.has(a.id) or a.injured() or not _can_take(a.species) or not can_reach(a):
			continue
		out.append(Animals.node_of(a))
	if bool(tonight.get("lesson", false)):
		var spared := out.filter(func(n: Node3D) -> bool: return (n as Animal).data.species != &"rooster")
		if not spared.is_empty():
			out.assign(spared)
	return out


func _nearest(nodes: Array[Node3D], from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in nodes:
		var d := _flat(n.global_position, from)
		if d < best_d:
			best = n
			best_d = d
	return best


## The farmer when he is out in the open near the pack (not in the farmhouse, not down).
func _exposed_player(live: Array[Node3D]) -> Node3D:
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p) or in_house(p.global_position):
		return null
	if PlayerState.knocked_out:
		return null
	for w in live:
		if _flat(w.global_position, p.global_position) < PLAYER_RANGE:
			return p
	return null


## Inside the farmhouse (safe: they prowl outside).
func in_house(p: Vector3) -> bool:
	var house := Game.world.get_node_or_null("FarmHouse") as FarmHouse if Game.world else null
	return house != null and house.footprint().grow(-0.1).has_point(Vector2(p.x, p.z))


## Where the animals are: the middle of the ones the wolves can get to (else of them all,
## else the farmhouse).
func _target_area() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for pass_reach: bool in [true, false]:
		for a in Animals.animals:
			var node := Animals.node_of(a)
			if node and (not pass_reach or can_reach(a)):
				sum += node.global_position
				n += 1
		if n > 0:
			return sum / n
	return Vector3(WorldLayout.HOUSE_DOOR_X, 0.0, WorldLayout.HOUSE_FRONT_Z + 6.0)


## The forest's edge nearest `area` (round the valley, away from the road to town and out
## of the farmer's sight if it can be).
func _forest_edge(area: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var best := Vector3.INF
	var best_d := INF
	for i in 48:
		var ang := TAU * i / 48.0
		var p := Vector3(cos(ang) * EDGE, 0.0, sin(ang) * EDGE)
		if WorldLayout.distance_to_road(p.x, p.z) < 25.0 or WorldLayout.playable_distance(p.x, p.z) < 3.0:
			continue
		p.y = TerrainData.height(p.x, p.z)
		var d := _flat(p, area)
		if cam and cam.is_position_in_frustum(p + Vector3(0, 0.5, 0)) and cam.global_position.distance_to(p) < 70.0:
			d += 40.0
		if d < best_d:
			best = p
			best_d = d
	return best if best != Vector3.INF else Vector3(-EDGE, TerrainData.height(-EDGE, 0.0), 0.0)


## Back into the forest from `from`: out to the valley's rim the way it is facing.
func _flee_point(from: Vector3) -> Vector3:
	var out := Vector3(from.x, 0.0, from.z)
	if out.length() < 1.0:
		out = Vector3(-1.0, 0.0, 0.0)
	var p := out.normalized() * (WorldLayout.VALLEY_RADIUS + 2.0)
	if WorldLayout.distance_to_road(p.x, p.z) < 20.0:
		p = Vector3(-p.x, 0.0, p.z)
	p.y = TerrainData.height(p.x, p.z)
	return p


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Side goals ---------------------------------------------------------------------------------

## The wolves' card (the lesson night's goals, a later raid's note) and the vet's.
func _update_goals() -> void:
	var noted := raid_pending() and bool(tonight.get("noted", false)) and String(tonight["phase"]) in ["warned", "active"]
	if noted:
		_wolf_goal.title = tr("SIDE_WOLVES_TITLE")
		if bool(tonight["lesson"]):
			_lesson_goal()
		else:
			var hint := tr("SIDE_HINT_WOLVES_HERE") if String(tonight["phase"]) == "active" else tr("SIDE_HINT_WOLVES_NOTE")
			_wolf_goal.set_goal(tr("SIDE_NOTE_WOLVES"), hint)
		SideStory.add_goal(_wolf_goal)
	else:
		SideStory.remove_goal(_wolf_goal)
	var hurt := Animals.injured_ids()
	if not vet_lesson_done and not hurt.is_empty():
		_vet_goal.title = tr("SIDE_VET_TITLE")
		_vet_lesson_goal(hurt)
		SideStory.add_goal(_vet_goal)
	else:
		SideStory.remove_goal(_vet_goal)


## The lesson night: the coop door shut with every bird inside (the dot on the door), then
## home to bed (the dot on the bed).
func _lesson_goal() -> void:
	var coop := lesson_coop()
	if coop:
		_lesson_step = "door"
		var out := birds_out(coop)
		var hint: String
		if not coop.housing.door_open:
			hint = tr("SIDE_HINT_WOLF_OPEN") % out
		elif out > 0:
			hint = tr("SIDE_HINT_WOLF_WAIT") % out
		else:
			hint = tr("SIDE_HINT_WOLF_SHUT")
		var door: Variant = coop.get_node_or_null("Waypoint_%s" % ChickenCoop.ANCHOR_DOOR)
		_wolf_goal.set_goal(tr("SIDE_GOAL_WOLF_DOOR"), hint, door if door else coop.door_point() + Vector3(0, 1.4, 0),
				tr("HOUSING_COOP"))
		return
	if _lesson_step == "door":
		Game.notify(tr("MSG_SIDE_DONE") % tr("SIDE_GOAL_WOLF_DOOR"), UiTheme.GOLD)
	_lesson_step = "sleep"
	var bed := get_tree().get_first_node_in_group(&"beds") as Node3D
	var where: Variant = bed.global_position + Vector3(0, 1.1, 0) if bed else null
	var hint := tr("SIDE_HINT_WOLVES_HERE") if String(tonight["phase"]) == "active" else tr("SIDE_HINT_WOLF_SLEEP")
	_wolf_goal.set_goal(tr("SIDE_GOAL_WOLF_SLEEP"), hint, where, tr("SIDE_LABEL_BED"))


## The kit-built coop with birds in it that isn't shut for the night yet (its door open, or
## some still outside), or null when every coop is.
func lesson_coop() -> ChickenCoop:
	var farm := Game.world.farm as Farm if Game.world else null
	if farm == null:
		return null
	for coop in farm.kit_coops():
		if not coop.is_built() or coop.housing == null or Animals.count_at(coop.housing) == 0:
			continue
		if coop.housing.door_open or birds_out(coop) > 0:
			return coop
	return null


## Birds of `coop` outside it now (not counting one away at the clinic).
func birds_out(coop: ChickenCoop) -> int:
	var n := 0
	for a: Animal in coop.housing.animals:
		if not a.indoors and not a.ridden and not a.data.away and a.state != Animal.State.HATCH:
			n += 1
	return n


## The vet's lesson: the hurt animal with the least time left, the dot on the clinic's
## counter (vet_point).
func _vet_lesson_goal(hurt: Array) -> void:
	var worst: AnimalData = null
	for id: int in hurt:
		var a := Animals.by_id(id)
		if a and (worst == null or Animals.hours_left(id) < Animals.hours_left(worst.id)):
			worst = a
	var hint := tr("SIDE_HINT_VET") % [worst.name, maxi(1, ceili(Animals.hours_left(worst.id)))] if worst else ""
	_vet_goal.set_goal(tr("SIDE_GOAL_VET"), hint, vet_point(), tr("SIDE_LABEL_VET"))


## Where the vet's counter is (its waypoint: the clinic's &"vet_counter"), else (no town
## built yet) the town square.
func vet_point() -> Variant:
	var counter := get_tree().get_first_node_in_group(&"vet_counter")
	if counter and counter.has_method("waypoint_point"):
		return counter.call("waypoint_point")
	if counter is Node3D:
		return (counter as Node3D).global_position + Vector3(0, 1.6, 0)
	var c := WorldLayout.TOWN_CENTER
	return Vector3(c.x, TerrainData.height(c.x, c.y) + 2.0, c.y)


func _on_vet_visit(_id: int) -> void:
	if vet_lesson_done:
		return
	vet_lesson_done = true
	Game.notify(tr("MSG_SIDE_DONE") % tr("SIDE_GOAL_VET"), UiTheme.GOLD)
	SideStory.remove_goal(_vet_goal)


# --- Save ------------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	return {"lesson": lesson_done, "vet_lesson": vet_lesson_done, "last": last_raid_day, "rolled": rolled_day,
		"tonight": tonight.duplicate(true), "report": Array(report), "seed": _rng.seed, "state": _rng.state}


## Loaded in the middle of a raid: the losses so far stand, the pack comes again.
func load_data(d: Dictionary) -> void:
	_clear_wolves()
	lesson_done = bool(d.get("lesson", false))
	vet_lesson_done = bool(d.get("vet_lesson", false))
	last_raid_day = int(d.get("last", -100))
	rolled_day = int(d.get("rolled", 0))
	tonight = (d.get("tonight", {}) as Dictionary).duplicate(true)
	if String(tonight.get("phase", "")) in ["active", "asleep"]:
		tonight["phase"] = "warned"
	report = PackedStringArray(d.get("report", []))
	if d.has("seed"):
		_rng.seed = int(d["seed"])
		if d.has("state"):
			_rng.state = int(d["state"])
	_sleep_targets = null
	_lesson_step = ""
	_goal_wait = 0.0
	SideStory.remove_goal(_wolf_goal)
	SideStory.remove_goal(_vet_goal)
