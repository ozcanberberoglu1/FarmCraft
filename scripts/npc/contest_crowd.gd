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
## From 09:00 each walks over (a few seconds apart) along the pavement, down past the bus
## stop and the filling station onto the meadow, then round the pond on the venue's ring
## to his place (ContestVenue.path_in: never through the board or the benches); out of the
## player's sight they are simply there (and on a load in the middle of it). Whenever the
## leaderboard gets a new biggest fish the people watching cheer (a few arms up, some
## clapping); at the horn the anglers put their rods down and everyone claps; when the
## winner has been named they walk back to where they were and go on with their day (the
## visitors walk off out of town and are gone).

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

var venue: ContestVenue


func _ready() -> void:
	super._ready()
	name = "ContestCrowd"
	FishingContest.rival_caught.connect(_on_rival_caught)
	FishingContest.ceremony_started.connect(_on_ceremony)
	FishingContest.new_leader.connect(_on_new_leader)


func wants_out() -> bool:
	return FishingContest.crowd_out()


## Zeynep watches from the crowd's place after the workers' (round the pond to it).
func zeynep_spot() -> Dictionary:
	var spot: Dictionary = venue.crowd_spots[(VISITORS.size() - 1 + WORKERS.size()) % venue.crowd_spots.size()]
	return {"pos": spot["pos"], "yaw": spot["yaw"], "via": venue.path_in(spot["pos"])}


# --- To the pond -----------------------------------------------------------------------------

func _gather(instant: bool) -> void:
	var crowd := 0
	for v: Array in VISITORS:
		_visitor(v[0], v[1], v[2], TOWN_EDGE)
	for i in ANGLERS.size():
		var p := person(ANGLERS[i])
		if p == null:
			continue
		var spot: Dictionary = venue.angler_spots[mini(i, venue.angler_spots.size() - 1)]
		_send(p, spot["pos"], float(spot["yaw"]), instant, _fish.bind(p, spot["water"], RODS[i]), venue.path_in(spot["pos"]))
	for i in SEATED.size():
		var p := person(SEATED[i])
		if p == null or i >= venue.bench_seats.size():
			continue
		var seat: Dictionary = venue.bench_seats[i]
		_send(p, seat["pos"], float(seat["yaw"]), instant, _sit.bind(p, seat), venue.path_in(seat["pos"]))
	var watching: Array = []
	for v: Array in VISITORS:
		if not (v[0] in ANGLERS):
			watching.append(_out[v[0]])
	for id: StringName in WORKERS:
		var p := person(id)
		if p:
			watching.append(p)
	for p: Townsperson in watching:
		var spot: Dictionary = venue.crowd_spots[crowd % venue.crowd_spots.size()]
		crowd += 1
		_send(p, spot["pos"], float(spot["yaw"]), instant, _watch.bind(p, float(spot["yaw"])), venue.path_in(spot["pos"]))


func _fish(p: Townsperson, water: Vector3, rod: StringName) -> void:
	if FishingContest.crowd_out():
		p.start_fishing(water, rod)


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
