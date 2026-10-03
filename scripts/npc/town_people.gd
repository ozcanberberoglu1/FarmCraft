class_name TownPeople
extends Node3D
## Yeşilova's townspeople (Town adds this node): who stands where and who walks which
## way. Workers at the town's services, locals about the place:
##
##   Hasan, the grocer         behind the general market's counter, at the till
##   Murat, the attendant      on the first pump island, wiping his pump
##   Kemal, the car dealer     behind his desk in the showroom
##   Rıza, the stockman        at the Animal Market's hatch with his ledger
##   Dr. Selin, the vet        behind the vet clinic's counter with her clipboard (in
##                             the clinic's hours: VetClinic sends her home after them)
##   Ali, the shop boy         sweeping the market's forecourt (clear of the door)
##   Osman Dede                on the bench by the market
##   Nuri Hoca                 at the tea table under the market's awning
##   Ayşe Teyze, Emre, Halil   walking the pavements: the zebra crossing to the Animal
##                             Market, the station's kiosk and the bus stop, the car lot
##
## Places follow the town's own layout (its constants and service points), so nobody
## stands in a door, on a route of the player's or in a vehicle's way. Seven bodies
## share six models (tints tell the farmers apart); the vet has her own.
##
## While a worker is away at a town event (Townsperson.away: EventCrowd takes the whole
## town to the carnival and the fishing contest) his counter, desk, hatch or pump still
## works: a little card stands where he works ("ETKİNLİKTEYİZ", take what you need and
## leave the money in the till) and the prompt says so (TownPoint.hint_prompt).

const CROSS_N := 16.05
const CROSS_S := 23.95
## The honesty box's card: its size (metres) and how often the cards are looked at.
const CARD_SIZE := Vector2(0.44, 0.3)
const CARD_CHECK := 0.5

var town: Town
## The honesty box's cards: [worker, card] pairs.
var _cards: Array = []
var _card_t := 0.0


func _ready() -> void:
	name = "TownPeople"
	town = get_parent() as Town
	var dealer: TownPoint = null
	for c in town.get_children():
		if c is TownPoint and (c as TownPoint).prompt_key == "ACTION_DEALER":
			dealer = c
	# The grocer behind the counter, by the till (the till is on his right).
	var counter := town.market_counter.global_position
	_person(&"shopkeeper", &"shopkeeper", Townsperson.Act.TILL, Vector3(counter.x + 0.35, counter.y - 0.6, counter.z + 0.72), PI,
			{"service": town.market_counter, "worker": true, "work_height": 1.045})
	# The attendant beside the first pump, on the island, facing it.
	if not town.pumps.is_empty():
		var pump: Vector3 = town.pumps[0].global_position
		_person(&"attendant", &"worker", Townsperson.Act.WIPE, Vector3(pump.x, pump.y - 0.95, pump.z + 0.78), PI,
				{"pumps": town.pumps, "worker": true})
	# The car dealer behind his desk, facing the showroom.
	if dealer:
		var desk := dealer.global_position
		_person(&"salesman", &"salesman", Townsperson.Act.TALK, Vector3(desk.x + 0.25, desk.y - 0.5, desk.z - 1.12), 0.0,
				{"service": dealer, "worker": true})
	# The stockman inside the office, behind the hatch's counter, facing the lane.
	var hatch := town.market_office.global_position
	_person(&"rancher", &"farmer", Townsperson.Act.WRITE, Vector3(hatch.x - 1.5, hatch.y - 1.3, hatch.z + 0.1), PI * 0.5,
			{"service": town.market_office, "worker": true, "work_height": 1.0,
			"tints": {"cloth_male_casualsuit05": Color(0.95, 0.8, 0.62), "cloth_jujube_newsboy_cap": Color(0.62, 0.5, 0.4)}})
	# The vet behind her counter, writing on her clipboard, facing the waiting room.
	if town.vet_clinic:
		var clinic := town.vet_clinic
		var vet := _person(&"vet", &"vet", Townsperson.Act.WRITE, clinic.vet_spot(), clinic.vet_yaw(),
				{"service": clinic.counter, "worker": true, "work_height": VetClinic.COUNTER_H})
		clinic.set_vet(vet)
	# The shop boy sweeping the forecourt west of the door.
	var fz := Town.MARKET.end.y + 2.4
	var fy := town._y(206, 11.5) + 0.15
	var sweeper := _person(&"sweeper", &"worker", Townsperson.Act.SWEEP, Vector3(Town.MARKET.position.x + 2.0, fy, fz), 0.0,
			{"tints": {"cloth_male_worksuit01": Color(0.55, 0.58, 0.52)}})
	sweeper.sweep_from = Vector3(Town.MARKET.position.x + 1.6, fy, fz)
	sweeper.sweep_to = Vector3(Town.MARKET.position.x + 7.6, fy, fz)
	# Osman Dede on the bench west of the market, facing the street.
	var bench := Vector3(Town.MARKET.position.x - 0.9, town._y(195, 12) + 0.15, 12.3)
	_person(&"elder", &"farmer", Townsperson.Act.BENCH, bench + Vector3(0, 0, 0.12), 0.0,
			{"seat_height": 0.48, "tints": {"cloth_male_casualsuit05": Color(0.7, 0.7, 0.72)}})
	# Nuri Hoca on the chair at the tea table (the chair faces the table; both as
	# Town._market_front places them, the table's top 73 cm up).
	var chair_yaw := PI * 0.5 + 0.2
	var chair := Vector3(Town.MARKET.position.x + 4.35, fy, Town.MARKET.end.y + 0.95)
	_person(&"teacher", &"elder", Townsperson.Act.TEA, chair + Vector3(sin(chair_yaw), 0, cos(chair_yaw)) * 0.1, chair_yaw,
			{"seat_height": 0.45, "tea_table": Vector3(Town.MARKET.position.x + 5.15, fy + 0.73, Town.MARKET.end.y + 0.98)})
	# Walkers.
	var n := 15.3
	var s := 24.75
	var w1 := _person(&"villager", &"villager", Townsperson.Act.WALK, Vector3(205.0, fy, n), PI * 0.5, {"walk_speed": 0.85})
	w1.route = [_wp(199.0, n), _wp(228.8, n), _wp(Town.CROSSING_X, CROSS_N), _wp(Town.CROSSING_X, CROSS_S),
		_wp(232.0, s), _wp(247.6, s), _wp(247.6, 25.9, 7.0, 0.0), _wp(247.6, s), _wp(232.0, s),
		_wp(Town.CROSSING_X, CROSS_S), _wp(Town.CROSSING_X, CROSS_N), _wp(228.8, n), _wp(188.5, n, 5.0, PI)]
	var w2 := _person(&"young", &"young", Townsperson.Act.WALK, Vector3(226.0, fy, s), -PI * 0.5, {"walk_speed": 1.3, "waves": true})
	w2.route = [_wp(233.2, 26.2, 9.0, PI), _wp(212.0, s), _wp(211.0, 29.0), _wp(211.0, 38.8), _wp(217.3, 40.2, 6.0, 0.0),
		_wp(211.0, 38.8), _wp(211.0, 29.0), _wp(212.0, s), _wp(262.0, s, 4.0, PI), _wp(240.0, s)]
	var w3 := _person(&"farmer", &"farmer", Townsperson.Act.WALK, Vector3(236.0, fy, 15.0), PI * 0.5,
			{"walk_speed": 0.8, "hands_behind": true})
	w3.route = [_wp(221.0, 15.0, 3.0, PI), _wp(247.0, 15.0, 10.0, PI), _wp(268.0, 15.0, 4.0), _wp(247.0, 15.2, 6.0, PI)]
	for w: Townsperson in [w1, w2, w3]:
		w._wp = _nearest_waypoint(w)
	_staff_points()


## Who serves at each service (TownPoint.staff), and a card for when he is away: on the
## counter, the desk or the hatch's sill facing the customer; on a post where the
## attendant stands on the pump island (both ways).
func _staff_points() -> void:
	for p: Townsperson in get_children():
		if not p.worker:
			continue
		var point := p.service as TownPoint
		if point:
			point.staff = p
		for pump: Node in p.pumps:
			if pump is TownPoint:
				(pump as TownPoint).staff = p
		var fwd := Vector3(sin(p.rotation.y), 0.0, cos(p.rotation.y))
		var at := p.position
		match p.person:
			&"shopkeeper", &"vet":
				at = Vector3(point.global_position.x - 0.3, at.y + p.work_height, point.global_position.z)
			&"salesman":
				at = Vector3(point.global_position.x + 0.45, at.y + 0.95, point.global_position.z + 0.1)
			&"rancher":
				at += fwd * 0.75 + Vector3(0.0, p.work_height, 0.25)
			&"attendant":
				at += Vector3(0.0, 0.0, 0.05)
		_cards.append([p, _card(at, p.rotation.y, p.person == &"attendant")])


## A small cardboard card standing on its foot (or on a post), the town's own words on it.
func _card(at: Vector3, yaw: float, posted: bool) -> Node3D:
	var card := Node3D.new()
	card.name = "HonestyCard"
	card.position = at
	card.rotation.y = yaw
	card.visible = false
	add_child(card)
	var lift := 0.95 if posted else 0.0
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CARD_SIZE.x, CARD_SIZE.y, 0.012)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.78, 0.62)
	mat.roughness = 0.95
	box.material = mat
	board.mesh = box
	board.position = Vector3(0.0, lift + CARD_SIZE.y * 0.5 + 0.01, 0.0)
	board.rotation.x = 0.0 if posted else -0.18
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.add_child(board)
	if posted:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.015
		cyl.bottom_radius = 0.02
		cyl.height = lift
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.3, 0.3, 0.32)
		cyl.material = pm
		post.mesh = cyl
		post.position = Vector3(0.0, lift * 0.5, -0.012)
		card.add_child(post)
	for side: float in ([1.0, -1.0] if posted else [1.0]):
		var head := Label3D.new()
		head.text = "ETKİNLİKTEYİZ"
		head.font = UiTheme.display(700, 3)
		head.font_size = 40
		head.pixel_size = 0.0011
		head.modulate = Color(0.62, 0.12, 0.1)
		head.double_sided = false
		head.position = Vector3(0.0, 0.085, 0.008 * side)
		head.rotation.y = 0.0 if side > 0.0 else PI
		board.add_child(head)
		var line := Label3D.new()
		line.text = "Kendin al,\nparayı kasaya bırak"
		line.font = UiTheme.font(600)
		line.font_size = 34
		line.pixel_size = 0.0011
		line.modulate = Color(0.12, 0.11, 0.1)
		line.double_sided = false
		line.position = Vector3(0.0, -0.04, 0.008 * side)
		line.rotation.y = head.rotation.y
		board.add_child(line)
	return card


func _process(delta: float) -> void:
	_card_t -= delta
	if _card_t > 0.0:
		return
	_card_t = CARD_CHECK
	for e: Array in _cards:
		var p: Townsperson = e[0]
		(e[1] as Node3D).visible = is_instance_valid(p) and p.away


## The honesty box's card at `person`'s service (tests).
func card_of(person: StringName) -> Node3D:
	for e: Array in _cards:
		if is_instance_valid(e[0]) and (e[0] as Townsperson).person == person:
			return e[1]
	return null


static func _wp(x: float, z: float, wait := 0.0, face := NAN) -> Dictionary:
	return {"p": Vector3(x, 0.0, z), "wait": wait, "face": face}


static func _nearest_waypoint(w: Townsperson) -> int:
	var best := 0
	var d := INF
	for i in w.route.size():
		var p: Vector3 = w.route[i]["p"]
		var dd := Vector2(p.x, p.z).distance_to(Vector2(w.position.x, w.position.z))
		if dd < d:
			d = dd
			best = i
	return best


func _person(id: StringName, model: StringName, act: Townsperson.Act, at: Vector3, yaw: float, opts := {}) -> Townsperson:
	var p := Townsperson.new()
	p.name = "Person_" + String(id)
	p.person = id
	p.act = act
	p.setup(model, opts.get("tints", {}))
	for k: String in opts:
		if k != "tints":
			p.set(k, opts[k])
	p.position = at
	p.rotation.y = yaw
	add_child(p)
	return p
