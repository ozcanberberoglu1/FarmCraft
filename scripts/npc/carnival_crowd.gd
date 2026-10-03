class_name CarnivalCrowd
extends EventCrowd
## The whole town at the carnival (Carnival; TownCarnival adds this, the going and coming
## back: EventCrowd). From 19:30, as the town dresses up, everyone walks over: along the
## north pavement (over the zebra crossing from the south side), under the KARNAVAL arch
## and down the festooned walk onto the fairground. There:
##
##   at the stalls     Hasan at the cotton candy, Murat at the roasted corn, Ali at the
##                     balloon seller's cart
##   by the carousel   Ayşe Teyze watching it go round, Osman Dede and Nuri Hoca beside
##                     her, hands behind their backs
##   in the plaza      Kemal and Rıza having a chat, Dr. Selin and Halil another
##   strolling         Emre, round the fair: the stalls, the carousel, the wheel
##   by the wheel      two neighbours from the villages (here for the night), and Zeynep
##                     with Karamel once she lives here (ZeynepHome)
##
## The workers' services still work meanwhile (the honesty box). When the fun starts at
## 20:00 the fireworks go up and everyone claps, and again now and then through the show
## and the finale. At 23:00 they all walk home and go on with their day (the visitors
## leave town).

## Spots: id -> [x, z, the point faced (x, z), act, hands behind, the way in (x, z pairs)].
## The ways in start from the plaza's mouth (MOUTH) and keep clear of the stalls, the
## masts and the rides.
const SPOTS := {
	&"shopkeeper": [222.1, -16.1, Vector2(221.05, -15.05), Townsperson.Act.STAND, false, []],
	&"attendant": [229.9, -16.1, Vector2(230.95, -15.05), Townsperson.Act.STAND, false, []],
	&"sweeper": [220.4, -20.0, Vector2(219.0, -20.0), Townsperson.Act.STAND, false, [Vector2(224.2, -17.6)]],
	&"villager": [214.6, -21.8, Vector2(208.0, -25.0), Townsperson.Act.STAND, false,
		[Vector2(224.2, -17.6), Vector2(219.6, -21.8)]],
	&"elder": [215.0, -25.0, Vector2(208.0, -25.0), Townsperson.Act.STAND, true,
		[Vector2(224.2, -17.6), Vector2(220.0, -24.6)]],
	&"teacher": [214.4, -28.4, Vector2(208.0, -25.0), Townsperson.Act.STAND, true,
		[Vector2(224.2, -17.6), Vector2(220.0, -24.6), Vector2(217.5, -27.6)]],
	&"salesman": [230.4, -21.2, Vector2(231.4, -22.0), Townsperson.Act.TALK, false, [Vector2(228.6, -17.0)]],
	&"rancher": [231.4, -22.0, Vector2(230.4, -21.2), Townsperson.Act.TALK, false, [Vector2(228.6, -17.0)]],
	&"vet": [221.6, -23.4, Vector2(222.6, -24.2), Townsperson.Act.TALK, false, [Vector2(224.2, -17.6)]],
	&"farmer": [222.6, -24.2, Vector2(221.6, -23.4), Townsperson.Act.TALK, false,
		[Vector2(224.2, -17.6), Vector2(224.0, -22.6)]],
	&"visitor_c": [223.0, -31.2, Vector2(226.0, -36.0), Townsperson.Act.STAND, false,
		[Vector2(224.2, -17.6), Vector2(224.0, -26.5)]],
	&"visitor_d": [229.0, -31.0, Vector2(226.0, -36.0), Townsperson.Act.STAND, true,
		[Vector2(228.6, -17.0), Vector2(228.8, -26.5)]],
	&"zeynep": [228.0, -27.4, Vector2(226.0, -36.0), Townsperson.Act.STAND, false, [Vector2(228.6, -17.0)]],
}
## Emre's stroll round the fair: [x, z, wait, the point faced while waiting (or none)].
const STROLL := [
	[226.8, -12.6, 0.0, null], [222.9, -17.0, 6.0, Vector2(221.05, -15.05)], [220.6, -23.0, 0.0, null],
	[216.6, -26.6, 8.0, Vector2(208.0, -25.0)], [223.4, -29.0, 0.0, null], [226.0, -29.6, 7.0, Vector2(226.0, -36.0)],
	[230.6, -26.4, 0.0, null], [233.2, -19.6, 0.0, null], [229.4, -16.8, 6.0, Vector2(230.95, -15.05)],
]
const STROLLER := &"young"
## Visitors for the night: [id, model, tints].
const VISITORS := [
	[&"visitor_c", &"villager", {"cloth_male_casualsuit05": Color(0.5, 0.42, 0.55)}],
	[&"visitor_d", &"elder", {"cloth_male_casualsuit05": Color(0.45, 0.5, 0.62)}],
]
## The way onto the fairground from the street: the north pavement at the arch's line,
## under the arch, down the walk, into the plaza's mouth.
const ARCH_X := 228.0
const MOUTH := Vector2(226.8, -12.0)
## Where the visitors come from and go back to: the west end of the north pavement.
const TOWN_EDGE := Vector3(187.0, 0.0, 15.3)
## Seconds between claps while the fireworks are going up.
const CLAP_EVERY := Vector2(2.5, 6.0)

var carnival: TownCarnival
var _clap_t := 0.0
## The fun has just started: (nearly) everyone claps at the first shells.
var _cheer := false


func _ready() -> void:
	super._ready()
	name = "CarnivalCrowd"
	Carnival.began.connect(_on_began)


func wants_out() -> bool:
	return Carnival.is_dressed()


func zeynep_spot() -> Dictionary:
	var spot := _spot(&"zeynep")
	spot["via"] = _way_in(&"zeynep")
	return spot


func _spot(id: StringName) -> Dictionary:
	var s: Array = SPOTS[id]
	var at := Vector3(float(s[0]), 0.0, float(s[1]))
	var face: Vector2 = s[2]
	return {"pos": at, "yaw": atan2(face.x - at.x, face.y - at.z)}


## The way in to `id`'s spot from the plaza's mouth.
func _way_in(id: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Vector2 in (SPOTS[id][5] as Array):
		out.append(Vector3(v.x, 0.0, v.y))
	return out


func _process(delta: float) -> void:
	super._process(delta)
	if not _gathered or not Carnival.is_on() or carnival == null or not carnival.show_on():
		return
	_clap_t -= delta
	if _clap_t > 0.0:
		return
	_clap_t = randf_range(CLAP_EVERY.x, CLAP_EVERY.y)
	var chance := 0.85 if _cheer else 0.45
	_cheer = false
	for p: Townsperson in people():
		if not p.is_walking_to() and p.act != Townsperson.Act.WALK and randf() < chance:
			p.clap(randf_range(1.4, 3.0) + (1.5 if chance > 0.5 else 0.0))


# --- To the fair -----------------------------------------------------------------------------

func _gather(instant: bool) -> void:
	for v: Array in VISITORS:
		_visitor(v[0], v[1], v[2], TOWN_EDGE)
	for id: StringName in SPOTS:
		if id == SideStory.WHO:
			continue
		var p := person(id)
		if p == null:
			continue
		var spot := _spot(id)
		_send(p, spot["pos"], float(spot["yaw"]), instant, _settle.bind(p, id), _way_in(id))
	var w := person(STROLLER)
	if w:
		var first: Array = STROLL[0]
		_send(w, Vector3(float(first[0]), 0.0, float(first[1])), 0.0, instant, _stroll.bind(w))


func _settle(p: Townsperson, id: StringName) -> void:
	var s: Array = SPOTS[id]
	_stand(p, float(_spot(id)["yaw"]), s[3], bool(s[4]))


## Emre walks round the fair (a walker's route of his own while it lasts).
func _stroll(p: Townsperson) -> void:
	var route: Array = []
	for s: Array in STROLL:
		var face: Variant = s[3]
		var yaw := NAN
		if face is Vector2:
			yaw = atan2((face as Vector2).x - float(s[0]), (face as Vector2).y - float(s[1]))
		route.append(TownPeople._wp(float(s[0]), float(s[1]), float(s[2]), yaw))
	p.route = route
	p.act = Townsperson.Act.WALK
	p._wp = TownPeople._nearest_waypoint(p)


## From `from` to the plaza's mouth: to the north pavement (over the zebra crossing from
## the south side), along it to the arch, under it and down the walk.
func _path_to_venue(from: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if from.z > Town.STREET_Z:
		if from.z > SOUTH_WALK + 1.0:
			out.append(Vector3(from.x, 0.0, SOUTH_WALK))
		out.append(Vector3(Town.CROSSING_X, 0.0, TownPeople.CROSS_S))
		out.append(Vector3(Town.CROSSING_X, 0.0, TownPeople.CROSS_N))
	elif from.z > 0.0:
		out.append(Vector3(from.x, 0.0, NORTH_WALK))
	out.append(Vector3(ARCH_X, 0.0, NORTH_WALK))
	out.append(Vector3(ARCH_X, 0.0, 9.0))
	out.append(Vector3(ARCH_X, 0.0, -2.0))
	out.append(Vector3(MOUTH.x, 0.0, MOUTH.y))
	return out


func _visitor_ids() -> Array:
	return VISITORS.map(func(v: Array) -> StringName: return v[0])


func _visitor_exit() -> Vector3:
	return TOWN_EDGE


# --- Fireworks -------------------------------------------------------------------------------

## The fun starts: the first shells go up and everyone claps.
func _on_began() -> void:
	_clap_t = 1.2
	_cheer = true
