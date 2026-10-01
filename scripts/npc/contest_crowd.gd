class_name ContestCrowd
extends Node
## Who goes to the fishing contest (FishingContest) and back (ContestVenue adds this):
##
##   anglers   Cemal Usta (a fisherman from the lake villages, here for the day), Emre,
##             Halil, Ayşe Teyze and Ali the shop boy (his broom left at the shop): on the
##             pier's end and along the shore, a rod each, landing what the contest rolls
##             for them (show_catch)
##   watching  Osman Dede and Nuri Hoca on the benches, and two neighbours from the
##             villages standing behind the shore (they come for the day)
##
## Hasan, Murat, Kemal, Rıza and Dr. Selin mind their counters. From 09:00 each walks
## over (a few seconds apart) along the pavement, down past the bus stop and the filling
## station onto the meadow; out of the player's sight they are simply there (and on a load
## in the middle of it). At the horn the anglers put their rods down and everyone claps;
## when the winner has been named they walk back to where they were and go on with their
## day (the visitors walk off out of town and are gone).

## The rivals in angler_spots' order (the pier's end first), their rods.
const ANGLERS := [&"fisher", &"young", &"farmer", &"villager", &"sweeper"]
const RODS := [&"carp_rod", &"fishing_rod", &"cane_rod", &"cane_rod", &"cane_rod"]
const SEATED := [&"elder", &"teacher"]
## Visitors for the day: [id, model, tints, angler (else watching)].
const VISITORS := [
	[&"fisher", &"farmer", {"cloth_male_casualsuit05": Color(0.42, 0.5, 0.46), "cloth_jujube_newsboy_cap": Color(0.3, 0.32, 0.3)}],
	[&"visitor_a", &"villager", {}],
	[&"visitor_b", &"elder", {"cloth_male_casualsuit05": Color(0.62, 0.55, 0.5)}],
]
## Where the visitors come from and go back to: the west end of the south pavement.
const TOWN_EDGE := Vector3(186.5, 0.0, 24.8)
## Out of the camera's sight this far, a move is made at once.
const SEEN := 70.0
const NORTH_WALK := 15.3
const SOUTH_WALK := 24.8

var venue: ContestVenue
var town: Town
## Everyone's place before the contest: id -> {pos, yaw, act}.
var _home := {}
## id -> Townsperson at the contest (the visitors too).
var _out := {}
var _gathered := false
var _first := true
var _check_t := 0.0


func _ready() -> void:
	name = "ContestCrowd"
	FishingContest.rival_caught.connect(_on_rival_caught)
	FishingContest.ceremony_started.connect(_on_ceremony)


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.5
	var want := FishingContest.crowd_out()
	if want and not _gathered:
		_gather(_first)
	elif not want and _gathered:
		_disperse()
	_first = false


func person(id: StringName) -> Townsperson:
	if _out.has(id) and is_instance_valid(_out[id]):
		return _out[id]
	return town.get_node_or_null("TownPeople/Person_" + String(id)) as Townsperson


func is_gathered() -> bool:
	return _gathered


## Everyone at the contest now (the visitors included).
func people() -> Array:
	var out: Array = []
	for id: StringName in _out:
		if is_instance_valid(_out[id]):
			out.append(_out[id])
	return out


# --- To the pond -----------------------------------------------------------------------------

func _gather(instant: bool) -> void:
	_gathered = true
	_home.clear()
	_out.clear()
	var crowd := 0
	for v: Array in VISITORS:
		var id: StringName = v[0]
		var p := Townsperson.new()
		p.name = "Person_" + String(id)
		p.person = id
		p.act = Townsperson.Act.STAND
		p.setup(v[1], v[2])
		p.position = TOWN_EDGE + Vector3(0.0, TerrainData.height(TOWN_EDGE.x, TOWN_EDGE.z), 0.0)
		town.get_node("TownPeople").add_child(p)
		_out[id] = p
	for i in ANGLERS.size():
		var p := person(ANGLERS[i])
		if p == null:
			continue
		_out[ANGLERS[i]] = p
		var spot: Dictionary = venue.angler_spots[mini(i, venue.angler_spots.size() - 1)]
		_send(p, spot["pos"], float(spot["yaw"]), instant, _fish.bind(p, spot["water"], RODS[i]))
	for i in SEATED.size():
		var p := person(SEATED[i])
		if p == null or i >= venue.bench_seats.size():
			continue
		_out[SEATED[i]] = p
		var seat: Dictionary = venue.bench_seats[i]
		_send(p, seat["pos"], float(seat["yaw"]), instant, _sit.bind(p, seat))
	for v: Array in VISITORS:
		var id: StringName = v[0]
		if id in ANGLERS:
			continue
		var spot: Dictionary = venue.crowd_spots[crowd % venue.crowd_spots.size()]
		crowd += 1
		_send(_out[id], spot["pos"], float(spot["yaw"]), instant, _watch.bind(_out[id], float(spot["yaw"])))


## Walks `p` from where he is to `to` (or puts him there at once, out of sight), then `then`.
func _send(p: Townsperson, to: Vector3, yaw: float, instant: bool, then: Callable) -> void:
	if not _home.has(p.person) and p.get_parent() == town.get_node("TownPeople") and not (p.person in _visitor_ids()):
		_home[p.person] = {"pos": p.global_position, "yaw": p.rotation.y, "act": p.act}
	var cam := _camera()
	if instant or (cam.distance_to(p.global_position) > SEEN and cam.distance_to(to) > SEEN):
		p.place_at(to, yaw)
		then.call()
		return
	var path := _path_to_venue(p.global_position)
	path.append(to)
	# Not all at once: a few seconds apart.
	get_tree().create_timer(randf_range(0.0, 9.0), false).timeout.connect(func() -> void:
		if is_instance_valid(p) and _gathered:
			p.show_own_props(false)
			p.walk_to(path, func() -> void:
				p.rotation.y = yaw
				p._yaw = yaw
				then.call()))


func _fish(p: Townsperson, water: Vector3, rod: StringName) -> void:
	if FishingContest.crowd_out():
		p.start_fishing(water, rod)


func _sit(p: Townsperson, seat: Dictionary) -> void:
	p.global_position = seat["pos"]
	p.rotation.y = float(seat["yaw"])
	p._yaw = p.rotation.y
	p.seat_height = float(seat["height"])
	p.act = Townsperson.Act.BENCH
	p.show_own_props(false)


func _watch(p: Townsperson, yaw: float) -> void:
	p.rotation.y = yaw
	p._yaw = yaw
	p.act = Townsperson.Act.STAND
	p.hands_behind = randf() < 0.5


## From `from` to the meadow: along the pavement (over the zebra crossing from the north
## side), down past the bus stop and the filling station.
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


func _disperse() -> void:
	_gathered = false
	var cam := _camera()
	for id: StringName in _out.keys():
		var p: Townsperson = _out[id]
		if not is_instance_valid(p):
			continue
		p.stop_fishing()
		p.hands_behind = false
		if id in _visitor_ids():
			if cam.distance_to(p.global_position) > SEEN:
				p.queue_free()
				continue
			var path := _path_from_venue(p.global_position, TOWN_EDGE)
			p.walk_to(path, p.queue_free)
			continue
		var home: Dictionary = _home.get(id, {})
		if home.is_empty():
			continue
		var at: Vector3 = home["pos"]
		if cam.distance_to(p.global_position) > SEEN and cam.distance_to(at) > SEEN:
			_restore(p, home)
			continue
		var path := _path_from_venue(p.global_position, at)
		p.act = Townsperson.Act.STAND
		get_tree().create_timer(randf_range(0.0, 4.0), false).timeout.connect(func() -> void:
			if is_instance_valid(p) and not _gathered:
				p.walk_to(path, _restore.bind(p, home)))
	_out.clear()


## The way back from the pond to `to` (the reverse of the way there).
func _path_from_venue(from: Vector3, to: Vector3) -> Array[Vector3]:
	var there := _path_to_venue(to)
	there.reverse()
	there.append(to)
	# Leaving the pond: straight to the meadow's corner first.
	if from.distance_to(venue.approach[2]) < 2.0:
		there.remove_at(0)
	return there


## Back in his place, doing what he was doing.
func _restore(p: Townsperson, home: Dictionary) -> void:
	if not is_instance_valid(p):
		return
	p.stop_walk()
	p.global_position = home["pos"]
	p.rotation.y = float(home["yaw"])
	p._yaw = p.rotation.y
	p.act = home["act"]
	p.show_own_props(true)
	if p.act == Townsperson.Act.WALK and not p.route.is_empty():
		p._wp = TownPeople._nearest_waypoint(p)
	p.reset_physics_interpolation()


func _visitor_ids() -> Array:
	return VISITORS.map(func(v: Array) -> StringName: return v[0])


func _camera() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3(0, 1000, 0)
