class_name EventCrowd
extends Node
## The whole town going to one of its events and back again: what ContestCrowd (the
## fishing contest at the town pond) and CarnivalCrowd (the carnival on the green behind
## the market) share. Every CHECK seconds it asks wants_out(): the first time it says yes
## everyone is sent to his place there (_gather), the first time after that it says no
## they all go back to where they were and go on with their day (_disperse); a load in
## the middle of it puts them there at once.
##
## The workers go too (WORKERS: Hasan, Murat, Kemal, Rıza and Dr. Selin): `away`
## meanwhile, their counters, desk, hatch and pumps still work (TownPeople's honesty box
## card and the prompt's line). One working indoors (behind a counter, his desk, the
## hatch) finishes with the player first: he leaves only once the camera is more than
## WORKER_SEEN from his place, stepping out onto the pavement in front of it and walking
## from there; coming back he walks to that spot and is at work again. Out of the camera's
## sight (SEEN) at both ends of a walk, a move is made at once. Dr. Selin, gone home after
## the clinic's hours, comes from home the same way. Zeynep (ZeynepHome) goes by herself
## with Karamel, to zeynep_spot().

const GROUP := &"event_crowd"
## Out of the camera's sight this far, a move is made at once.
const SEEN := 70.0
## A worker indoors stays at his post while the camera is this near it.
const WORKER_SEEN := 25.0
const NORTH_WALK := 15.3
const SOUTH_WALK := 24.8
const CHECK := 0.5
const WORKERS: Array[StringName] = [&"shopkeeper", &"attendant", &"salesman", &"rancher", &"vet"]

var town: Town
## Everyone's place before the event: id -> {pos, yaw, act, route}.
var _home := {}
## id -> Townsperson at the event (the visitors too).
var _out := {}
## Workers still at their posts, to leave once nobody sees them: id -> [to, yaw, then, via].
var _waiting := {}
## The way in to each one's place from where the event's ground begins (id -> points):
## walked back out the same way.
var _via := {}
var _gathered := false
var _first := true
var _check_t := 0.0


func _ready() -> void:
	add_to_group(GROUP)


## Whether the town is (or is going) at the event now.
func wants_out() -> bool:
	return false


## Where Zeynep stands at the event ({pos, yaw}; {} for nowhere): ZeynepHome asks.
func zeynep_spot() -> Dictionary:
	return {}


## Whether Zeynep is on her way to the event (or there) by now: ZeynepHome asks while the
## town is out. (The contest: everyone leaves at his own time.)
func zeynep_out() -> bool:
	return true


## Whether Zeynep walks to the event whoever sees it, even on a load (the crowd then puts
## her where she would be by now), instead of simply being there when nobody is about.
func zeynep_walks() -> bool:
	return false


## The way from `from` to the event (world points, ground level), the last one where the
## event's own places begin.
func _path_to_venue(_from: Vector3) -> Array[Vector3]:
	return []


## Sends everyone to his place (`instant`: put there at once).
func _gather(_instant: bool) -> void:
	pass


## The ids of the visitors for the day (they leave town afterwards).
func _visitor_ids() -> Array:
	return []


## The event the town is at now (null: none).
static func active(tree: SceneTree) -> EventCrowd:
	for n: Node in tree.get_nodes_in_group(GROUP):
		var c := n as EventCrowd
		if c and c.wants_out():
			return c
	return null


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK
	var want := wants_out()
	if want and not _gathered:
		_gathered = true
		_home.clear()
		_out.clear()
		_waiting.clear()
		_via.clear()
		_gather(_first)
	elif not want and _gathered:
		_disperse()
	elif _gathered:
		_leave_waiting()
	_first = false


func person(id: StringName) -> Townsperson:
	if _out.has(id) and is_instance_valid(_out[id]):
		return _out[id]
	return town.get_node_or_null("TownPeople/Person_" + String(id)) as Townsperson


func is_gathered() -> bool:
	return _gathered


## Everyone at the event now (the visitors included).
func people() -> Array:
	var out: Array = []
	for id: StringName in _out:
		if is_instance_valid(_out[id]):
			out.append(_out[id])
	return out


## Workers still at their posts (waiting for the player to go).
func waiting() -> Array:
	return _waiting.keys()


# --- There -----------------------------------------------------------------------------------

## A visitor for the day, standing at `at` (TownPeople's child, freed when he leaves).
func _visitor(id: StringName, model: StringName, tints: Dictionary, at: Vector3) -> Townsperson:
	var p := Townsperson.new()
	p.name = "Person_" + String(id)
	p.person = id
	p.act = Townsperson.Act.STAND
	p.setup(model, tints)
	p.position = at + Vector3(0.0, TerrainData.height(at.x, at.z), 0.0)
	town.get_node("TownPeople").add_child(p)
	_out[id] = p
	return p


## Walks `p` from where he is to `to` (or puts him there at once, out of sight), then `then`;
## from where the event's ground begins along `via` (points) to `to`.
func _send(p: Townsperson, to: Vector3, yaw: float, instant: bool, then: Callable, via: Array[Vector3] = []) -> void:
	if p == null:
		return
	var visitor := p.person in _visitor_ids()
	if not _home.has(p.person) and not visitor:
		_home[p.person] = {"pos": p.global_position, "yaw": p.rotation.y, "act": p.act, "route": p.route.duplicate(),
			"hands": p.hands_behind}
	var cam := _camera()
	var from := p.global_position
	if p.worker and not instant:
		var gone_home := not p.visible
		if not gone_home and _indoors(p) and cam.distance_to(from) < WORKER_SEEN:
			# Still serving: he goes once the player has.
			_waiting[p.person] = [to, yaw, then, via]
			return
		_waiting.erase(p.person)
		if _indoors(p) or gone_home:
			from = _exit_of(from)
	_out[p.person] = p
	_via[p.person] = via
	_leave_post(p)
	if instant or (cam.distance_to(from) > SEEN and cam.distance_to(to) > SEEN):
		p.place_at(to, yaw)
		then.call()
		return
	if from != p.global_position:
		p.place_at(from, p.rotation.y)
	var path := _path_to_venue(from)
	path.append_array(via)
	path.append(to)
	# Not all at once: a few seconds apart.
	get_tree().create_timer(randf_range(0.0, 9.0), false).timeout.connect(func() -> void:
		if is_instance_valid(p) and _gathered and _out.get(p.person) == p:
			p.walk_to(path, func() -> void:
				p.rotation.y = yaw
				p._yaw = yaw
				then.call()))


## Off duty for the event: away from his post (the honesty box), the vet back from home if
## the clinic had closed. His own things go with him as they do (Townsperson: the broom
## carried, the tea glass left on the table).
func _leave_post(p: Townsperson) -> void:
	p.away = p.worker
	p.stop_walk()
	if p.act in [Townsperson.Act.TILL, Townsperson.Act.WRITE, Townsperson.Act.WIPE, Townsperson.Act.SWEEP,
			Townsperson.Act.TEA, Townsperson.Act.BENCH, Townsperson.Act.WALK]:
		p.act = Townsperson.Act.STAND
	if not p.visible:
		p.visible = true
		p.collision_layer = 4 | 16
		p.process_mode = Node.PROCESS_MODE_INHERIT


## Workers waiting at their posts go once the camera is away from them.
func _leave_waiting() -> void:
	if _waiting.is_empty():
		return
	var cam := _camera()
	for id: StringName in _waiting.keys():
		var p := person(id)
		if p == null:
			_waiting.erase(id)
			continue
		if cam.distance_to(p.global_position) >= WORKER_SEEN:
			var w: Array = _waiting[id]
			_send(p, w[0], w[1], false, w[2], w[3])


## Standing, facing `yaw`, `act` (STAND, TALK...), hands behind him or not.
func _stand(p: Townsperson, yaw: float, act := Townsperson.Act.STAND, hands := false) -> void:
	p.rotation.y = yaw
	p._yaw = yaw
	p.act = act
	p.hands_behind = hands


## The worker works indoors (behind a counter, his desk, the hatch): not the attendant.
static func _indoors(p: Townsperson) -> bool:
	return p.worker and p.service != null


## The spot on the pavement in front of `post` (where a worker steps out to and back to).
static func _exit_of(post: Vector3) -> Vector3:
	var x := clampf(post.x, Town.WALK_N.position.x + 2.0, Town.WALK_N.end.x - 2.0)
	return Vector3(x, 0.0, NORTH_WALK if post.z < Town.STREET_Z else SOUTH_WALK)


# --- And back --------------------------------------------------------------------------------

func _disperse() -> void:
	_gathered = false
	var cam := _camera()
	for id: StringName in _waiting.keys():
		var p := person(id)
		if p:
			p.away = false
	_waiting.clear()
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
			p.act = Townsperson.Act.STAND
			var out: Array[Vector3] = []
			out.assign(_via.get(id, []))
			out.reverse()
			out.append_array(_path_from_venue(p.global_position, _visitor_exit()))
			p.walk_to(out, p.queue_free)
			continue
		var home: Dictionary = _home.get(id, {})
		if home.is_empty():
			continue
		var at: Vector3 = home["pos"]
		var to := _exit_of(at) if _indoors(p) else at
		if cam.distance_to(p.global_position) > SEEN and cam.distance_to(to) > SEEN:
			_restore(p, home)
			continue
		var path: Array[Vector3] = []
		path.assign(_via.get(id, []))
		path.reverse()
		path.append_array(_path_from_venue(p.global_position, to))
		p.stop_walk()
		p.act = Townsperson.Act.STAND
		get_tree().create_timer(randf_range(0.0, 4.0), false).timeout.connect(func() -> void:
			if is_instance_valid(p) and not _gathered:
				p.walk_to(path, _restore.bind(p, home)))
	_out.clear()


## Where the visitors go when it is over (out of town).
func _visitor_exit() -> Vector3:
	return Vector3(Town.WALK_S.position.x + 0.5, 0.0, SOUTH_WALK)


## The way back from the event to `to` (the reverse of the way there).
func _path_from_venue(_from: Vector3, to: Vector3) -> Array[Vector3]:
	var there := _path_to_venue(to)
	there.reverse()
	there.append(to)
	return there


## Back in his place, doing what he was doing (at work again: the vet goes home if the
## clinic has closed meanwhile).
func _restore(p: Townsperson, home: Dictionary) -> void:
	if not is_instance_valid(p) or _gathered:
		return
	p.stop_walk()
	p.global_position = home["pos"]
	p.rotation.y = float(home["yaw"])
	p._yaw = p.rotation.y
	p.act = home["act"]
	p.hands_behind = bool(home.get("hands", false))
	p.route = (home.get("route", []) as Array).duplicate()
	p.away = false
	p.show_own_props(true)
	if p.act == Townsperson.Act.WALK and not p.route.is_empty():
		p._wp = TownPeople._nearest_waypoint(p)
	p.reset_physics_interpolation()
	if p.person == &"vet" and town.vet_clinic:
		town.vet_clinic.set_vet(p)


func _camera() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3(0, 1000, 0)
