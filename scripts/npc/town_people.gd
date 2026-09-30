class_name TownPeople
extends Node3D
## Yeşilova's townspeople (Town adds this node): who stands where and who walks which
## way. Workers at the town's services, locals about the place:
##
##   Hasan, the grocer         behind the general market's counter, at the till
##   Murat, the attendant      on the first pump island, wiping his pump
##   Kemal, the car dealer     behind his desk in the showroom
##   Rıza, the stockman        at the Animal Market's hatch with his ledger
##   Ali, the shop boy         sweeping the market's forecourt (clear of the door)
##   Osman Dede                on the bench by the market
##   Nuri Hoca                 at the tea table under the market's awning
##   Ayşe Teyze, Emre, Halil   walking the pavements: the zebra crossing to the Animal
##                             Market, the station's kiosk and the bus stop, the car lot
##
## Places follow the town's own layout (its constants and service points), so nobody
## stands in a door, on a route of the player's or in a vehicle's way. Seven bodies
## share six models (tints tell the farmers apart).

const CROSS_N := 16.05
const CROSS_S := 23.95

var town: Town


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
	var w1 := _person(&"villager", &"villager", Townsperson.Act.WALK, Vector3(205.0, fy, n), PI * 0.5, {"walk_speed": 1.0})
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
