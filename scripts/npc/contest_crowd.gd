class_name ContestCrowd
extends EventCrowd
## Who goes to the fishing contest (FishingContest) and back (ContestVenue adds this; the
## going and coming back: EventCrowd):
##
##   anglers   Cemal Usta (a fisherman from the lake villages, here for the day), Emre,
##             Halil, Ayşe Teyze and Ali the shop boy (his broom with him, laid on the
##             grass beside him while he fishes): spread round the pond's shore, a rod
##             each, landing what the contest rolls for them (show_catch)
##   watching  Osman Dede and Nuri Hoca on the benches, two neighbours from the villages
##             standing behind the anglers (they come for the day), and the town's
##             workers: Hasan, Murat, Kemal, Rıza and Dr. Selin (their services still
##             work: the honesty box), and Zeynep with Karamel once she lives here
##             (ZeynepHome)
##
## Everyone is at his place when the contest opens at 09:00, so each sets out early
## enough for his own walk: along the pavement, down past the bus stop and the filling
## station onto the meadow, then round the pond on the venue's ring to his place
## (ContestVenue.path_in: never through the board or the benches). His leaving time is
## worked out from the length of that walk at his own pace and the game clock's pace now
## (leave_minute: a short day's clock runs faster, so they leave earlier by it; whoever is
## farther or slower leaves first), so that they come in one after another over the last
## half hour before the opening (EARLY), no two of them past the meadow's corner within
## APART of one another (_leads: nobody walks in inside somebody else). They walk it
## whether anyone sees them or not; a worker serving the player goes once he has gone.
## When the clock is skipped (a night slept, a load, a test) or run fast (the test
## shortcuts' fast-forward) everyone is put where he would be by then: still in town, on
## his way or at his place; one behind his time whom nobody sees is put on along his way,
## one ahead of it (the clock stood still over a window) waits where nobody sees him.
##
## The anglers stand at their places until the opening and cast one after another in the
## moments after it (cast_minute: FishingContest only has a rival land fish once his line
## is in the water). Whenever the leaderboard gets a new biggest fish the people watching
## cheer (a few arms up, some clapping); at the whistle the anglers put their rods down and
## everyone claps; when the winner has been named they walk back to where they were and
## go on with their day (the visitors walk off out of town and are gone).

## The rivals in angler_spots' order (round the pond from the way in), their rods.
const ANGLERS := [&"fisher", &"young", &"farmer", &"villager", &"sweeper"]
const RODS := [&"carp_rod", &"fishing_rod", &"cane_rod", &"cane_rod", &"cane_rod"]
const SEATED := [&"elder", &"teacher"]
## Lines called out at a new biggest fish (CONTEST_CHEER_1..n).
const CHEER_LINES := 3
## Visitors for the day: [id, model, tints, angler (else watching)].
const VISITORS := [
	[&"fisher", &"farmer", {"cloth_male_casualsuit05": Color(0.42, 0.5, 0.46), "cloth_jujube_newsboy_cap": Color(0.3, 0.32, 0.3)}],
	[&"visitor_a", &"villager", {}],
	[&"visitor_b", &"elder", {"cloth_male_casualsuit05": Color(0.62, 0.55, 0.5)}],
]
## Where the visitors come from and go back to: the west end of the south pavement.
const TOWN_EDGE := Vector3(186.5, 0.0, 24.8)

## Everyone is at his place between these many game minutes before the opening (the last
## and the first of them, each his own time between), and never less than EARLY_FLOOR real
## seconds before it (a short day's clock runs fast); a little earlier where he would
## otherwise walk in together with somebody else (APART).
const EARLY := Vector2(8.0, 30.0)
const EARLY_FLOOR := 4.0
## Zeynep's own time in that span (0..1).
const ZEYNEP_EARLY := 0.45
## A walk takes its length at his pace and a little more: setting off and slowing into his
## place (seconds), each sharp corner (seconds), and a share on top.
const WALK_EXTRA := 1.5
const WALK_CORNER := 0.3
const WALK_SLACK := 1.01
## Behind his time by more than this (seconds of walking), a walker nobody sees is put on
## along his way; ahead of it by more than AHEAD, he waits where he is until it has caught
## up with him.
const BEHIND := 2.5
const AHEAD := 4.0
## No two of them come past the meadow's corner (the end of the way they all share) within
## this many real seconds of one another.
const APART := 1.5
## Zeynep's row in _leads.
const ZEYNEP := &"zeynep"
## A clock that moved this many game minutes more than the frame took was skipped (slept,
## loaded, set by a test): everyone is put where he would be by now.
const JUMP := 3.0
## After the opening the anglers cast one after another: real seconds (a random wait).
const CAST_AFTER := Vector2(0.6, 5.0)
const TICK := 0.25

var venue: ContestVenue
## Kept in town by a test (ids): they do not set out.
var held := {}

## Everyone who comes and his place (the places never move; built once): {id, to, yaw, via,
## kind (fish, sit or watch), early (0..1 of EARLY), visitor (his VISITORS row or []),
## water and rod (an angler's), seat (a bench's)}.
var _plan: Array = []
## Who has set out today, and the game minute each reached his place.
var _sent := {}
var _there := {}
## The game minute each angler cast (his line is in the water from then), the seconds he
## still waits before casting, and who was still held back when it opened (he casts when
## he comes, whatever the clock did meanwhile).
var _cast := {}
var _cast_wait := {}
var _late := {}
## The next look puts everyone where he would be by now (a skipped clock, a load).
var _resync := false
var _tick_t := 0.0
var _last_minute := -1.0
var _last_day := -1
var _zeynep_gone := false
## The clock was skipped past Zeynep's leaving time before she was on her way: she is put
## where she would be once she is (ZeynepHome sends her a moment after the crowd looks).
var _zeynep_owed := false
## The fast-forward ran on the last frame.
var _was_fast := false
## Real seconds before the opening each is due at his place (id -> seconds, ZEYNEP: hers),
## as worked out for this pace of the clock and with or without her (_leads).
var _lead := {}
var _lead_rate := -1.0
var _lead_zeynep := false


func _ready() -> void:
	super._ready()
	name = "ContestCrowd"
	FishingContest.rival_caught.connect(_on_rival_caught)
	FishingContest.ceremony_started.connect(_on_ceremony)
	FishingContest.new_leader.connect(_on_new_leader)


## The contest and its ceremony, and before it from when the first of them has to leave.
func wants_out() -> bool:
	if FishingContest.crowd_out():
		return true
	if venue == null or not FishingContest.is_today() or GameClock.minute >= FishingContest.START_MINUTE:
		return false
	# (once the first has set out it stays so: the walkers' rounds move their times about)
	return _gathered or GameClock.minute >= first_leave_minute()


## Zeynep watches from the crowd's place after the workers' (round the pond to it).
func zeynep_spot() -> Dictionary:
	var spot: Dictionary = venue.crowd_spots[(VISITORS.size() - 1 + WORKERS.size()) % venue.crowd_spots.size()]
	return {"pos": spot["pos"], "yaw": spot["yaw"], "via": venue.path_in(spot["pos"])}


## She leaves at her own time too (in time for her walk from her gate).
func zeynep_out() -> bool:
	if FishingContest.crowd_out():
		return true
	if not _gathered or not FishingContest.is_today() or GameClock.minute >= FishingContest.START_MINUTE:
		return false
	if not _zeynep_gone:
		_zeynep_gone = GameClock.minute >= _zeynep_leave()
	return _zeynep_gone


## Until she is due at her place she walks there, seen or not.
func zeynep_walks() -> bool:
	return FishingContest.is_today() and GameClock.minute < _zeynep_arrive()


func _process(delta: float) -> void:
	# The clock skipped (a night slept, a load, a test's) or runs fast (the test shortcuts'
	# fast-forward: the walkers keep their own pace, so the clock leaves them behind): look
	# at once, and put everyone where he would be by now, in sight or not.
	var fast := GameClock.fast_forward > 1.0
	var jumped := fast or _was_fast or GameClock.day != _last_day or absf(GameClock.minute - _last_minute - delta * pace()) > JUMP
	_was_fast = fast
	_last_day = GameClock.day
	_last_minute = GameClock.minute
	if jumped:
		_check_t = 0.0
		_resync = true
	super._process(delta)
	_tick_t -= delta
	if not _gathered:
		_resync = false
	elif _resync or _tick_t <= 0.0:
		_run(TICK - _tick_t, _resync)
		_tick_t = TICK
		_resync = false


# --- When each leaves ------------------------------------------------------------------------

## Game minutes a real second takes now (the day's length, a paced day). Not the test
## shortcuts' fast-forward: nobody leaves earlier for it, _process puts them on instead.
static func pace() -> float:
	return maxf(Settings.game_minutes_per_second() * GameClock.time_scale, 0.001)


## Everyone who comes, with his place (see _plan).
func plan() -> Array:
	if not _plan.is_empty() or venue == null:
		return _plan
	for i in ANGLERS.size():
		var spot: Dictionary = venue.angler_spots[mini(i, venue.angler_spots.size() - 1)]
		_plan.append(_entry(ANGLERS[i], spot["pos"], float(spot["yaw"]), &"fish", {"water": spot["water"], "rod": RODS[i]}))
	for i in mini(SEATED.size(), venue.bench_seats.size()):
		var seat: Dictionary = venue.bench_seats[i]
		_plan.append(_entry(SEATED[i], seat["pos"], float(seat["yaw"]), &"sit", {"seat": seat}))
	var watching: Array[StringName] = []
	for v: Array in VISITORS:
		if not (v[0] in ANGLERS):
			watching.append(v[0])
	watching.append_array(WORKERS)
	for i in watching.size():
		var spot: Dictionary = venue.crowd_spots[i % venue.crowd_spots.size()]
		_plan.append(_entry(watching[i], spot["pos"], float(spot["yaw"]), &"watch", {}))
	# Each his own time in the last half hour, in no order of place.
	for i in _plan.size():
		_plan[i]["early"] = fposmod(0.37 + i * 0.618034, 1.0)
	return _plan


func _entry(id: StringName, to: Vector3, yaw: float, kind: StringName, more: Dictionary) -> Dictionary:
	var e := {"id": id, "to": to, "yaw": yaw, "kind": kind, "via": venue.path_in(to), "visitor": [], "early": 0.0}
	for v: Array in VISITORS:
		if v[0] == id:
			e["visitor"] = v
	e.merge(more)
	return e


func _entry_of(id: StringName) -> Dictionary:
	for e: Dictionary in plan():
		if e["id"] == id:
			return e
	return {}


## The ids of everyone who comes (the visitors too; not Zeynep, who goes by herself).
func plan_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in plan():
		out.append(e["id"])
	return out


## The game minute `e`'s man is due at his place.
func _arrive_minute(e: Dictionary) -> float:
	return FishingContest.START_MINUTE - float(_leads().get(e["id"], EARLY_FLOOR)) * pace()


## Real seconds before the opening each is due at his place (see _lead): his own time in
## EARLY, made earlier where he would come past the meadow's corner within APART of the
## one after him. They all walk the same pavement, approach and ring at the same pace, so
## two who pass the corner together would walk the whole way in inside one another.
func _leads() -> Dictionary:
	var rate := pace()
	var zeynep := SideStory.moved_in() and _zeynep_home() != null
	if not _lead.is_empty() and is_equal_approx(rate, _lead_rate) and zeynep == _lead_zeynep:
		return _lead
	_lead_rate = rate
	_lead_zeynep = zeynep
	_lead.clear()
	var corner := venue.approach[venue.approach.size() - 1]
	# [seconds before the opening he passes the corner, of them from there to his place, id]
	var rows: Array = []
	for e: Dictionary in plan():
		var p := person(e["id"])
		var way: Array[Vector3] = []
		way.assign(e["via"])
		way.append(e["to"])
		var ring := walk_seconds(corner, way, p.walk_speed if p else 1.1)
		rows.append([maxf(lerpf(EARLY.x, EARLY.y, float(e["early"])) / rate, EARLY_FLOOR) + ring, ring, e["id"]])
	if zeynep:
		var home := _zeynep_home()
		var spot := zeynep_spot()
		var way: Array[Vector3] = []
		way.assign(spot["via"])
		way.append(spot["pos"])
		var ring := walk_seconds(corner, way, home.zeynep.walk_speed if home.zeynep else 1.1)
		rows.append([maxf(lerpf(EARLY.x, EARLY.y, ZEYNEP_EARLY) / rate, EARLY_FLOOR) + ring, ring, ZEYNEP])
	# From the last one past the corner back to the first.
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]) if not is_equal_approx(float(a[0]), float(b[0])) else String(a[2]) < String(b[2]))
	var after := -INF
	for r: Array in rows:
		after = maxf(float(r[0]), after + APART)
		_lead[r[2]] = after - float(r[1])
	return _lead


## Where his walk starts from as things are now (a worker indoors or gone home: the
## pavement in front of his post), and his pace.
func _start_of(e: Dictionary) -> Array:
	if not (e["visitor"] as Array).is_empty():
		return [TOWN_EDGE, 1.1]
	var p := person(e["id"])
	if p == null:
		return []
	var from := p.global_position
	if p.worker and (_indoors(p) or not p.visible):
		from = _exit_of(from)
	return [from, p.walk_speed]


## The whole way from `from` to his place.
func _way(e: Dictionary, from: Vector3) -> Array[Vector3]:
	var path := _path_to_venue(from)
	path.append_array(e["via"])
	path.append(e["to"])
	return path


## Real seconds the walk from `from` along `path` takes at `speed` (metres a second).
static func walk_seconds(from: Vector3, path: Array[Vector3], speed: float) -> float:
	var length := 0.0
	var corners := 0
	var at := from
	var dir := Vector2.ZERO
	for q: Vector3 in path:
		var leg := Vector2(q.x - at.x, q.z - at.z)
		if leg.length() > 0.01:
			if dir != Vector2.ZERO and absf(dir.angle_to(leg)) > 0.9:
				corners += 1
			dir = leg
			length += leg.length()
		at = q
	return length / maxf(speed, 0.1) * WALK_SLACK + WALK_EXTRA + corners * WALK_CORNER


func _leave_minute(e: Dictionary) -> float:
	var start := _start_of(e)
	if start.is_empty():
		return INF
	return _arrive_minute(e) - walk_seconds(start[0], _way(e, start[0]), float(start[1])) * pace()


## The game minute `id` sets out today from where he is now (INF: he does not come), and
## the minute he is due at his place.
func leave_minute(id: StringName) -> float:
	var e := _entry_of(id)
	return INF if e.is_empty() else _leave_minute(e)


func arrive_minute(id: StringName) -> float:
	var e := _entry_of(id)
	return INF if e.is_empty() else _arrive_minute(e)


## The game minute the first of them sets out (Zeynep too, once she lives here).
func first_leave_minute() -> float:
	var first := float(FishingContest.START_MINUTE)
	for e: Dictionary in plan():
		if not held.has(e["id"]):
			first = minf(first, _leave_minute(e))
	if SideStory.moved_in():
		first = minf(first, _zeynep_leave())
	return first


## `id` has set out (or is there); is at his place.
func has_left(id: StringName) -> bool:
	return _gathered and _sent.has(id)


func is_there(id: StringName) -> bool:
	return _there.has(id) and is_instance_valid(_out.get(id))


## The game minute angler `id` cast (his line is in the water now); -1 while it is not:
## still in town, on his way, at his place before the opening, held back.
func cast_minute(id: StringName) -> float:
	var p := _out.get(id) as Townsperson
	if p == null or not is_instance_valid(p) or not _cast.has(id) or p.act != Townsperson.Act.FISH or p.is_walking_to():
		return -1.0
	return float(_cast[id])


# --- To the pond -----------------------------------------------------------------------------

## The day's going begins: nobody has set out yet (`instant`: the first look after the
## world was built, so everyone is put where he would be by now).
func _gather(instant: bool) -> void:
	_sent.clear()
	_there.clear()
	_cast.clear()
	_cast_wait.clear()
	_late.clear()
	_zeynep_gone = false
	_zeynep_owed = false
	_resync = _resync or instant
	_tick_t = 0.0


## Each sets out at his own time; one behind his time is put on along his way when the
## clock was skipped (`resync`) or nobody sees it; the anglers cast after the opening.
func _run(dt: float, resync: bool) -> void:
	var now := GameClock.minute
	var cam := _camera()
	for e: Dictionary in plan():
		var id: StringName = e["id"]
		if held.has(id):
			if FishingContest.is_on():
				_late[id] = true
			continue
		if not _sent.has(id):
			if now < _leave_minute(e) or (_waiting.has(id) and not resync):
				continue
			_set_out(e, resync)
		var p := _out.get(id) as Townsperson
		if p == null or not is_instance_valid(p) or _there.has(id) or not p.is_walking_to():
			continue
		_keep_time(p, _arrive_minute(e), e["to"], resync, cam)
	_cast_lines(dt, resync)
	if resync:
		_zeynep_owed = now >= _zeynep_leave()
	_zeynep_keep_time(resync, cam)


## `e`'s man leaves for the pond now: a visitor appears at the town's edge; a worker
## serving the player (indoors, the camera near) stays until he has gone (not on `resync`).
func _set_out(e: Dictionary, resync: bool) -> void:
	var id: StringName = e["id"]
	var v: Array = e["visitor"]
	var p := person(id)
	if p != null and p.is_queued_for_deletion():
		p = null
	if p == null and not v.is_empty():
		p = _visitor(v[0], v[1], v[2], TOWN_EDGE)
	if p == null:
		_sent[id] = true
		return
	var from := p.global_position
	if p.worker:
		var gone_home := not p.visible
		if not resync and not gone_home and _indoors(p) and _camera().distance_to(from) < WORKER_SEEN:
			_waiting[id] = [e["to"], e["yaw"], Callable(), e["via"]]
			return
		_waiting.erase(id)
		if _indoors(p) or gone_home:
			from = _exit_of(from)
	if v.is_empty() and not _home.has(id):
		_home[id] = {"pos": p.global_position, "yaw": p.rotation.y, "act": p.act, "route": p.route.duplicate(),
			"hands": p.hands_behind}
	_out[id] = p
	_via[id] = e["via"]
	_sent[id] = true
	_leave_post(p)
	if from != p.global_position:
		p.place_at(from, p.rotation.y)
	p.walk_to(_way(e, from), _reached.bind(e, p))


## A worker who waited for the player to go (EventCrowd._leave_waiting) leaves now.
func _send(p: Townsperson, _to: Vector3, _yaw: float, instant: bool, _then: Callable, _way_in: Array[Vector3] = []) -> void:
	var e := _entry_of(p.person) if p else {}
	if not e.is_empty() and not _sent.has(p.person) and not held.has(p.person):
		_set_out(e, instant)


## At his place: on the bench, watching, or (an angler) standing at the water until he casts.
func _reached(e: Dictionary, p: Townsperson) -> void:
	if not is_instance_valid(p) or not _gathered or _out.get(e["id"]) != p:
		return
	var yaw := float(e["yaw"])
	_there[e["id"]] = GameClock.minute
	match e["kind"]:
		&"sit":
			_sit(p, e["seat"])
		&"watch":
			_watch(p, yaw)
		_:
			_stand(p, yaw)


## Walker `p`, due at `to` at game minute `due`: behind his time by more than BEHIND, he is
## put on along his way to where he would be (at his place when it is past `due`) when the
## clock was skipped (`resync`) or nobody sees him go or come. True when he was moved.
## Ahead of it by more than AHEAD (the clock stood still over a window while he walked
## on), he waits where he is while nobody sees him.
func _keep_time(p: Townsperson, due: float, to: Vector3, resync: bool, cam: Vector3) -> bool:
	var have := maxf(due - GameClock.minute, 0.0) / pace()
	var behind := walk_seconds(p.global_position, p._path, p.walk_speed) - have
	p.walk_held = behind < -AHEAD and cam.distance_to(p.global_position) > SEEN
	# (after a skipped clock one who is due is there, however little he had left to walk)
	if behind <= BEHIND and not (resync and have <= 0.0):
		return false
	var ahead := _ahead(p, INF if have <= 0.0 else behind * p.walk_speed)
	var at: Vector3 = ahead[0]
	if not resync and (cam.distance_to(p.global_position) <= SEEN or cam.distance_to(to) <= SEEN or cam.distance_to(at) <= SEEN):
		return false
	var rest: Array[Vector3] = ahead[1]
	var done := p._path_done
	var yaw := p.rotation.y if rest.is_empty() else atan2(rest[0].x - at.x, rest[0].z - at.z)
	at.y = TerrainData.height(at.x, at.z)
	p.place_at(at, yaw)
	if rest.is_empty():
		if done.is_valid():
			done.call()
	else:
		p.walk_to(rest, done)
		p._speed = p.walk_speed
	return true


## Where walker `p` is `metres` further along his way: [the point, the way left after it]
## (its end and nothing left when it is no longer than that).
static func _ahead(p: Townsperson, metres: float) -> Array:
	var at := p.global_position
	var rest: Array[Vector3] = p._path.duplicate()
	var left := metres
	while not rest.is_empty():
		var leg := Vector3(rest[0].x - at.x, 0.0, rest[0].z - at.z)
		if leg.length() > left:
			return [at + leg.normalized() * left, rest]
		left -= leg.length()
		at = Vector3(rest[0].x, at.y, rest[0].z)
		rest.remove_at(0)
	return [at, rest]


## The contest is on: each angler at his place casts (a moment after the opening, one
## after another; on `resync` they have been fishing since it opened).
func _cast_lines(dt: float, resync: bool) -> void:
	if not FishingContest.is_on():
		return
	for e: Dictionary in plan():
		var id: StringName = e["id"]
		if e["kind"] != &"fish" or _cast.has(id) or not _there.has(id) or held.has(id):
			continue
		var p := _out.get(id) as Townsperson
		if p == null or not is_instance_valid(p):
			continue
		var at := GameClock.minute
		if resync and not _late.has(id):
			at = float(FishingContest.START_MINUTE)
		else:
			if not _cast_wait.has(id):
				_cast_wait[id] = randf_range(CAST_AFTER.x, CAST_AFTER.y)
			_cast_wait[id] = float(_cast_wait[id]) - dt
			if float(_cast_wait[id]) > 0.0:
				continue
		p.start_fishing(e["water"], e["rod"])
		_cast[id] = at


# --- Zeynep ----------------------------------------------------------------------------------

func _zeynep_home() -> ZeynepHome:
	return get_tree().get_first_node_in_group(ZeynepHome.GROUP) as ZeynepHome


## The game minute Zeynep is due at her place, and the minute she leaves her gate for it.
func _zeynep_arrive() -> float:
	return FishingContest.START_MINUTE - float(_leads().get(ZEYNEP, maxf(lerpf(EARLY.x, EARLY.y, ZEYNEP_EARLY) / pace(), EARLY_FLOOR))) * pace()


func _zeynep_leave() -> float:
	var home := _zeynep_home()
	if home == null:
		return INF
	var spot := zeynep_spot()
	var gate := home._gate_out()
	var path := _path_to_venue(gate)
	path.append_array(spot["via"])
	path.append(spot["pos"])
	return _zeynep_arrive() - walk_seconds(gate, path, home.zeynep.walk_speed if home.zeynep else 1.1) * pace()


## Zeynep on her way here (ZeynepHome walks her): kept to her time like everyone else. A
## skipped clock found her past her leaving time and not on her way yet (_zeynep_owed:
## ZeynepHome starts her from her gate a moment later): she is put where she would be then.
func _zeynep_keep_time(resync: bool, cam: Vector3) -> void:
	var home := _zeynep_home()
	if home == null or home.zeynep == null or home.where != &"event" or home._event != self or home._event_walk != "there":
		return
	var z: Townsperson = home.zeynep
	if not z.is_walking_to():
		return
	var owed := resync or _zeynep_owed
	_zeynep_owed = false
	if _keep_time(z, _zeynep_arrive(), zeynep_spot()["pos"], owed, cam) and home._event_walk == "there" and home.dog:
		home.dog.global_position = z.global_position + Vector3(0.9, 0.0, -0.4)


func _sit(p: Townsperson, seat: Dictionary) -> void:
	p.global_position = seat["pos"]
	p.rotation.y = float(seat["yaw"])
	p._yaw = p.rotation.y
	p.seat_height = float(seat["height"])
	p.act = Townsperson.Act.BENCH


func _watch(p: Townsperson, yaw: float) -> void:
	_stand(p, yaw, Townsperson.Act.STAND, randf() < 0.5)


## From `from` to the meadow's corner: along the pavement (over the zebra crossing from
## the north side), down past the bus stop and the filling station (round the pond from
## there: each one's `via`, ContestVenue.path_in).
func _path_to_venue(from: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if from.z < Town.STREET_Z:
		out.append(Vector3(from.x, 0.0, NORTH_WALK))
		out.append(Vector3(Town.CROSSING_X, 0.0, TownPeople.CROSS_N))
		out.append(Vector3(Town.CROSSING_X, 0.0, TownPeople.CROSS_S))
	elif from.z > SOUTH_WALK + 1.0 and from.distance_to(venue.approach[1]) > 12.0:
		out.append(Vector3(from.x, 0.0, SOUTH_WALK))
	out.append_array(venue.approach)
	return out


# --- The ceremony and back -------------------------------------------------------------------

func _disperse() -> void:
	super._disperse()
	_sent.clear()
	_there.clear()
	_cast.clear()
	_cast_wait.clear()
	_late.clear()
	_zeynep_gone = false
	_zeynep_owed = false


func _on_ceremony() -> void:
	for p: Townsperson in people():
		if p.act == Townsperson.Act.FISH:
			p.stop_fishing()
		if p.is_walking_to():
			continue
		if p.act != Townsperson.Act.BENCH:
			p.act = Townsperson.Act.CLAP
		p.clap(FishingContest.CEREMONY_LEN - 1.0)


func _on_rival_caught(id: StringName, catch: Dictionary) -> void:
	var p := person(id)
	if p == null or not _out.has(id) or p.act != Townsperson.Act.FISH:
		return
	p.show_catch(catch)
	# The ones watching nearby give him a hand now and then.
	for q: Townsperson in people():
		if q != p and q.act in [Townsperson.Act.STAND, Townsperson.Act.BENCH] and randf() < 0.5:
			q.clap(randf_range(1.2, 2.4))


## A new biggest fish on the board (`who`: "player" or a rival's id): the people watching
## cheer, a few with their arms up, the rest clapping; one calls out.
func _on_new_leader(who: String, _kg: float) -> void:
	if not _gathered:
		return
	var watching: Array = []
	for q: Townsperson in people():
		if String(q.person) != who and q.act in [Townsperson.Act.STAND, Townsperson.Act.BENCH] and not q.is_walking_to():
			watching.append(q)
	watching.shuffle()
	for i in watching.size():
		var q: Townsperson = watching[i]
		if i < 3 and q.act == Townsperson.Act.STAND:
			q.cheer(randf_range(2.2, 3.2))
		else:
			q.clap(randf_range(1.8, 3.0))
	if not watching.is_empty():
		(watching[0] as Townsperson).say(tr("CONTEST_CHEER_%d" % randi_range(1, CHEER_LINES)))


func _visitor_exit() -> Vector3:
	return TOWN_EDGE


func _visitor_ids() -> Array:
	return VISITORS.map(func(v: Array) -> StringName: return v[0])
