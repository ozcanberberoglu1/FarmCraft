class_name Animal
extends AnimatableBody3D
## A farm animal in the world. Its persistent state lives in `data` (simulated by
## the Animals autoload); this node handles the body: AI (wander, graze, eat and
## drink at the troughs, shelter in bad weather and at night, sleep, follow food),
## player interaction and status badges. A hen of a kit-built coop with an egg due walks
## to a bedded nest box, hops in, sits on it a while, lays and goes back out.
## Chicks come out of a hatching egg (hatch_in, then emerge), keep close to their mother
## (pecking about by her side, running with fluttering wings to catch up, through the
## coop door after her) and sleep huddled under her at night, cheeping as they go; the
## body changes from the downy chick to a pullet half way through growing up. A grown
## rooster crows a few times at first light, neck stretched and wings beating; now and
## then he holds a crow far too long, trembles and faints dead away for a while.
## One hurt by a wolf (AnimalData.injured) limps along slower on a sore leg, now and then
## stumbling, with a badge over it; one a wolf comes at (scare) bolts away from it.

enum State { IDLE, WANDER, GRAZE, GO_EAT, EAT, GO_DRINK, DRINK, SHELTER, SLEEP, FOLLOW, AWAY, RIDDEN, GO_NEST, NEST, HATCH, BROOD }

const BADGES := {
	"sick": preload("res://art/icons/ui/badge_sick.svg"), "wet": preload("res://art/icons/ui/badge_rain.svg"),
	"cold": preload("res://art/icons/ui/badge_cold.svg"), "thirsty": preload("res://art/icons/ui/badge_water.svg"),
	"hungry": preload("res://art/icons/ui/badge_hungry.svg"), "milk": preload("res://art/icons/ui/badge_milk.svg"),
	"wool": preload("res://art/icons/ui/badge_wool.svg"), "injured": preload("res://art/icons/ui/badge_injured.svg"),
}
const HEART := preload("res://art/icons/ui/heart.svg")
## Seconds of a hen's hop up into a nest box (and down again), and of sitting on it.
const NEST_HOP := 0.5
const NEST_SIT := Vector2(16.0, 26.0)
## Metres from its feeder within which an animal counts as crowding it (the farmer's feed
## then goes into the feeder, see _feeder_behind).
const FEEDER_REACH := 1.6
## Chicks: how far from their mother they potter about by day (metres from her middle,
## nearest and farthest), and beyond what they run to catch up with her.
const BROOD_NEAR := Vector2(0.26, 0.62)
const CATCH_UP := 1.4
## The downy chick model at its own scale 1 against the hen's size and radius (a ~10 cm
## chick): its body box and radius (how close it gets to walls, the door's edges and the
## others) follow its real size, not the hen's.
const CHICK_BODY := 0.22
## How near a chick gets to its spot by its mother before it counts as there (at night it
## settles within BROOD_NIGHT of it).
const CHICK_REACH := 0.12
const BROOD_NIGHT := 0.22
## Seconds of a chick's first wobbly steps out of the shell, and of its hop down from a
## nest box onto the coop floor.
const HATCH_WOBBLE := 1.4
const HATCH_HOP := 0.45
## A rooster crows CROWS times at first light (game hours), each crow CROW_TIME seconds
## long, a while apart (seconds).
const CROW_HOURS := Vector2(5.3, 7.8)
const CROWS := 3
const CROW_TIME := 2.4
const CROW_GAP := Vector2(8.0, 22.0)
## FAINT_CHANCE of his crows go on far too long: CROW_LONG seconds of it, FAINT_TREMBLE of
## trembling, FAINT_FALL keeling over, FAINT_OUT lying out cold, FAINT_RISE shaking himself
## and getting up (unsteadily), FAINT_FLUFF fluffing his feathers.
const FAINT_CHANCE := 0.6
const CROW_LONG := 3.6
const FAINT_TREMBLE := 0.8
const FAINT_FALL := 0.45
const FAINT_OUT := 6.0
const FAINT_RISE := 1.5
const FAINT_FLUFF := 0.7
## "The rooster fainted!" shows over him while the farmer, this close (metres), looks
## right at him (the view direction's dot with the way to him above FAINT_LOOK).
const FAINT_SEEN := 12.0
const FAINT_LOOK := 0.9
## Hurt (AnimalData.injured): its pace, how much slower still while the sore leg takes the
## weight (rig.limp_load), the walking seconds between stumbles and a stumble's length.
const INJURED_PACE := 0.55
const LIMP_HITCH := 0.55
const STUMBLE_EVERY := Vector2(5.0, 12.0)
const STUMBLE_TIME := 0.75
## Seconds an animal bolts from a wolf (scare), how much faster it goes and how far.
const SCARE_TIME := 3.0
const SCARE_PACE := 1.9
const SCARE_RUN := 4.5

var data: AnimalData
var housing: AnimalHousing
var rig: AnimalRig
var state := State.IDLE
var indoors := false
var ridden := false

var _path: Array[Vector3] = []
var _path_inside: Array[bool] = []
var _speed := 0.0
var _mode := AnimalRig.Mode.IDLE
var _move_speed := 0.8
var _state_time := 0.0
var _state_len := 3.0
var _think := 0.0
var _attention := 0.0
var _rng := RandomNumberGenerator.new()
var _badge: Sprite3D
var _badge_key := ""
var _shape: CollisionShape3D
var _age_shown := -1.0
var _wet_shown := -1.0
var _radius := 0.5
## The nest box she is bound for or sitting in (ChickenCoop), -1 for none; where she
## hopped up from, and whether the egg is laid yet.
var _nest := -1
var _nest_from := Vector3.ZERO
var _laid := false
## The model the rig shows (AnimalModels.look_for: the chick, a pullet, the grown bird).
var _look := &""
## Chicks: the pace to catch up with their mother, the next cheep, and a hatchling's
## way from the shell onto the floor.
var _hurry := 1.0
var _cheep := 0.0
var _hatch_from := Vector3.ZERO
var _hatch_to := Vector3.ZERO
var _hatch_shown := false
## A rooster's crowing: seconds into the crow (-1: not crowing), crows still to come this
## morning and the wait before the next, and the day he last greeted.
var _crow_t := -1.0
var _crows_left := 0
var _crow_wait := 0.0
var _crow_day := -1
## Seconds into a crow held too long and the faint after it (-1: none), the label over
## him and the wait before the next look whether the farmer sees him.
var _faint_t := -1.0
var _faint_label: Label3D
var _faint_look := 0.0
## Hurt: seconds into a stumble (-1: none) and the walking left before the next; seconds
## left of bolting from a wolf.
var _stumble_t := -1.0
var _stumble_wait := 0.0
var _scared := 0.0

## Crows end in a faint only in play: automated runs keep to what they check (the
## rooster scenario switches it on).
static var faint_in_tests := false


func setup(animal_data: AnimalData, home: AnimalHousing) -> void:
	data = animal_data
	housing = home


func _enter_tree() -> void:
	housing.animals.append(self)


func _exit_tree() -> void:
	housing.animals.erase(self)


func _ready() -> void:
	# Moved in physics ticks: drawn between ticks (see Settings._ready).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	# Moved directly by code every frame (AI or the rider), not by physics sync.
	sync_to_physics = false
	collision_layer = 4 | 16
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"animals")
	_rng.seed = data.id * 7919 + 13
	var info := data.info()
	_move_speed = float(info.get("speed", 0.8))
	_look = AnimalModels.look_for(data)
	rig = AnimalModels.create_rig(data.species, _look)
	add_child(rig)
	# Feet set down on the ground under them (terrain, floors, ramps).
	rig.ground = func(p: Vector3) -> float: return housing.ground_height(p)
	_cheep = _rng.randf_range(1.0, 5.0)
	_stumble_wait = _rng.randf_range(STUMBLE_EVERY.x, STUMBLE_EVERY.y)
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)
	_badge = Sprite3D.new()
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.fixed_size = true
	_badge.pixel_size = 0.00036
	_badge.shaded = false
	_badge.no_depth_test = true
	_badge.render_priority = 10
	_badge.visible = false
	_badge.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_badge.layers = 2
	add_child(_badge)
	refresh_body()
	_place_initial()


## Updates size, coat and fleece from the data (after growth or shearing).
func refresh_body() -> void:
	# A chick turns into a pullet (and a cockerel into a rooster) as it grows: a new body.
	var look := AnimalModels.look_for(data)
	if look != _look:
		_look = look
		var old := rig
		rig = AnimalModels.create_rig(data.species, _look)
		rig.carry_on(old)
		add_child(rig)
		old.queue_free()
		_wet_shown = -1.0
	var t := data.age_ratio()
	rig.set_variant(data.variant, not data.adult)
	rig.set_age(t)
	rig.set_wool(data.wool if data.species == &"sheep" else 1.0)
	var size: Vector3 = data.info().get("size", Vector3.ONE)
	var s := rig.scale.x * (CHICK_BODY if _look == &"chick" else 1.0)
	(_shape.shape as BoxShape3D).size = (size * s).max(Vector3(0.1, 0.1, 0.1))
	_shape.position = Vector3(0, size.y * s * 0.5, 0)
	_badge.position = Vector3(0, size.y * s + 0.35, 0)
	_radius = float(data.info().get("radius", 0.5)) * s
	_age_shown = t


func _place_initial() -> void:
	if data.away:
		global_position = data.away_pos
		rotation.y = data.away_yaw
		reset_physics_interpolation()
		state = State.AWAY
		return
	# Behind a shut coop door the hens are indoors.
	var inside := housing.has_shelter() and (GameClock.is_night() or Weather.is_precipitating() or not housing.door_open)
	teleport_home(inside)


func teleport_home(inside: bool) -> void:
	var p := housing.random_indoor_point(_rng) if inside and housing.has_shelter() else housing.random_outdoor_point(_rng)
	indoors = inside and housing.has_shelter()
	global_position = p
	rotation.y = _rng.randf() * TAU
	reset_physics_interpolation()
	_path.clear()
	_path_inside.clear()
	_end_faint()
	_set_state(State.SLEEP if GameClock.is_night() else State.IDLE, 2.0)
	# A chick goes where its mother went (she may be moved after it).
	if data.is_chick():
		_snap_to_mother.call_deferred()


## A hen let out of her crate at the coop door (`p`, just inside it): she shakes
## herself out there and, with the door open in the daytime, soon wanders out.
func arrive(p: Vector3) -> void:
	p.y = housing.ground_height(p)
	global_position = p
	indoors = housing.is_in_building(p)
	_path.clear()
	_path_inside.clear()
	_face(p + housing.front())
	reset_physics_interpolation()
	_end_faint()
	_set_state(State.IDLE, _rng.randf_range(1.5, 3.0))
	_think = 1.0


## The coop door was shut: one on her way through it stops on the side she is on.
func door_shut() -> void:
	if ridden or data.away or _path_inside.is_empty():
		return
	var crossing := false
	for inside: bool in _path_inside:
		if inside != indoors:
			crossing = true
			break
	if not crossing:
		return
	indoors = housing.is_in_building(global_position)
	_path.clear()
	_path_inside.clear()
	var p := housing.constrain(global_position, radius(), indoors)
	p.y = housing.ground_height(p)
	global_position = p
	_set_state(State.IDLE, _rng.randf_range(2.0, 4.0))


func radius() -> float:
	return _radius


# --- Chicks -------------------------------------------------------------------------------

## A chick still in its egg at `at` (the nest's straw, the coop floor): hidden and still
## until the shell gives way (emerge).
func hatch_in(at: Vector3) -> void:
	_hatch_from = at
	var floor_at := at
	floor_at.y = housing.ground_height(at)
	var coop := ChickenCoop.of(housing)
	# Out of a nest box: a hop down onto the floor in front of it.
	if at.y - floor_at.y > 0.15 and coop:
		floor_at = at + coop.nest_out(coop.nest_near(at)) * 0.42
		floor_at.y = housing.ground_height(floor_at)
	_hatch_to = floor_at
	indoors = housing.is_in_building(floor_at)
	global_position = at
	reset_physics_interpolation()
	visible = false
	_hatch_shown = false
	_path.clear()
	_path_inside.clear()
	_set_state(State.HATCH, 1e9)


## The shell has given way: the hatchling stands up wet and wobbly, shakes itself and
## (from a nest box) hops down, cheeping.
func emerge() -> void:
	if state != State.HATCH:
		return
	visible = true
	_hatch_shown = true
	rig.scale = Vector3.ONE * rig.scale.x * 0.6
	var tw := create_tween()
	tw.tween_property(rig, "scale", rig.scale / 0.6, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_time = 0.0
	_state_len = HATCH_WOBBLE + HATCH_HOP
	Audio.play("chick", global_position + Vector3(0, 0.1, 0), -6.0, 0.1, &"Effects", 4.0, 1.1)


func _hatching(_delta: float) -> void:
	_speed = 0.0
	if not _hatch_shown:
		_state_time = 0.0
		return
	var t := _state_time
	if t < HATCH_WOBBLE:
		# Finding its feet: a few unsteady turns on the spot.
		rotation.y += sin(t * 9.0) * 0.02
		global_position = _hatch_from
		return
	var u := (t - HATCH_WOBBLE) / HATCH_HOP
	if u < 1.0:
		global_position = _hop(_hatch_from, _hatch_to, u)
		return
	global_position = _hatch_to
	_set_state(State.IDLE, _rng.randf_range(0.5, 1.2))
	_think = 0.2


## The mother it follows (null when she is gone, away or living elsewhere).
func _mother_node() -> Animal:
	var m := Animals.by_id(data.mother)
	if m == null or m.away or not m.adult:
		return null
	var n := Animals.node_of(m)
	if n == null or n.housing != housing or n.ridden or n.state == State.HATCH:
		return null
	return n


## Where by its mother a chick keeps: all round her, each chick on its own side, drifting
## slowly by day; tucked in under her breast at night.
func _brood_spot(mom: Animal, night: bool) -> Vector3:
	var k := float(data.id) * 2.39996
	var off: Vector3
	if night:
		off = mom.global_basis * Vector3(cos(k) * 0.07, 0.0, -0.03 + sin(k) * 0.06)
	else:
		var r := lerpf(BROOD_NEAR.x, BROOD_NEAR.y, fposmod(k * 0.37, 1.0))
		var a := k + sin(Time.get_ticks_msec() * 0.00017 + k) * 0.9
		off = Vector3(cos(a) * r, 0.0, sin(a) * r)
	var p := mom.global_position + off
	p = housing.constrain(p, radius(), mom.indoors)
	p.y = housing.ground_height(p)
	return p


func _snap_to_mother() -> void:
	if not is_inside_tree() or state == State.HATCH or data.away:
		return
	var mom := _mother_node()
	if mom == null:
		return
	indoors = mom.indoors
	global_position = _brood_spot(mom, GameClock.is_night())
	reset_physics_interpolation()
	_path.clear()
	_path_inside.clear()


## A chick's next move while it has a mother to follow (false: none, the usual AI runs).
func _decide_chick() -> bool:
	var mom := _mother_node()
	if mom == null:
		return false
	# A drink or a peck at the feeder first (then back to her).
	if state in [State.GO_EAT, State.GO_DRINK] and not _path.is_empty():
		return true
	if (state == State.EAT or state == State.DRINK) and _busy():
		return true
	var night := GameClock.is_night() or mom.state == State.SLEEP
	var spot := _brood_spot(mom, night)
	var to := spot - global_position
	var d := Vector2(to.x, to.z).length()
	var apart := indoors != mom.indoors
	if apart or d > (BROOD_NIGHT if night else 0.5):
		# Moving already toward where she is: keep going, only aimed at her new place.
		var far := apart or d > CATCH_UP
		_hurry = 1.7 if far else 1.05
		_brood_to(spot, mom.indoors)
		if state != State.BROOD:
			_hurry = 1.0
		return true
	_hurry = 1.0
	if night:
		if state != State.SLEEP:
			_path.clear()
			_path_inside.clear()
			_face(mom.global_position)
			_set_state(State.SLEEP, 1e9)
		return true
	if state == State.SLEEP:
		_set_state(State.IDLE, _rng.randf_range(0.8, 2.0))
		return true
	if _busy():
		return true
	# Thirsty or hungry: to the troughs (in the coop, where she goes too).
	var water := housing.water
	var feed := housing.feed
	if data.hydration < 45.0 and water and not water.is_empty() and housing.is_in_building(water.global_position) == indoors:
		_go(_trough_spot(water), indoors, State.GO_DRINK)
		return true
	if data.fullness < 50.0 and feed and not feed.is_empty() and housing.is_in_building(feed.global_position) == indoors:
		_go(_trough_spot(feed), indoors, State.GO_EAT)
		return true
	# Pottering by her side: pecking at the ground, a look about, a step or two.
	var roll := _rng.randf()
	if roll < 0.55:
		_set_state(State.GRAZE, _rng.randf_range(1.2, 3.5))
	elif roll < 0.8:
		var near := spot + Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.2, 0.2))
		_brood_to(housing.constrain(near, radius(), mom.indoors), mom.indoors)
	else:
		_set_state(State.IDLE, _rng.randf_range(0.8, 2.5))
	return true


## Off to `spot` by its mother (on her side of the coop door). A way already under way to
## that side keeps going and only its end moves with her: planned afresh every look, it
## would turn back for the door's first waypoint each time and never get through.
func _brood_to(spot: Vector3, inside: bool) -> void:
	if state == State.BROOD and not _path.is_empty() and _path_inside.back() == inside:
		_path[_path.size() - 1] = spot
		return
	_go(spot, inside, State.BROOD)


## Now and then a cheep; often and loud when it has lost its mother or lags behind.
func _update_cheep(delta: float) -> void:
	_cheep -= delta
	if _cheep > 0.0:
		return
	var lost := _hurry > 1.5 or _mother_node() == null
	_cheep = _rng.randf_range(0.6, 1.5) if lost else _rng.randf_range(2.5, 7.0)
	if state == State.SLEEP or state == State.HATCH:
		_cheep *= 3.0
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_squared_to(global_position) < 22.0 * 22.0:
		Audio.play("chick", global_position + Vector3(0, 0.1, 0), -5.0 if lost else -11.0, 0.12, &"Effects", 3.0,
				_rng.randf_range(0.95, 1.12))


# --- The rooster's crow -------------------------------------------------------------------

## At first light a grown rooster crows a few times (not while he sits on anything).
func _update_crow(delta: float) -> void:
	if _faint_t >= 0.0:
		_update_faint(delta)
		return
	if _crow_t >= 0.0:
		_crow_t += delta
		rig.crow = _crow_envelope(_crow_t)
		if _crow_t >= CROW_TIME:
			_crow_t = -1.0
			rig.crow = 0.0
		return
	var hour := GameClock.get_hour_float()
	if _crow_day != GameClock.day and hour >= CROW_HOURS.x and hour < CROW_HOURS.y:
		_crow_day = GameClock.day
		_crows_left = CROWS
		_crow_wait = _rng.randf_range(0.5, 3.0)
	if _crows_left <= 0:
		return
	if hour >= CROW_HOURS.y or hour < CROW_HOURS.x:
		_crows_left = 0
		return
	_crow_wait -= delta
	if _crow_wait <= 0.0 and state != State.AWAY and not ridden:
		_crows_left -= 1
		_crow_wait = _rng.randf_range(CROW_GAP.x, CROW_GAP.y)
		crow()


## Throws his head back and crows (the wings beat first). Now and then (or with `faint`)
## the crow goes on far too long and ends in a faint (_update_faint).
func crow(faint := false) -> void:
	if faint or _rolls_faint():
		_crow_t = -1.0
		_faint_t = 0.0
		Audio.long_crow(global_position + Vector3(0, 0.5, 0), CROW_LONG)
		return
	_crow_t = 0.0
	Audio.play("rooster", global_position + Vector3(0, 0.5, 0), 0.0, 0.03, &"Effects", 10.0)


## Whether this crow is held too long: FAINT_CHANCE of them, not in his sleep, on a nest,
## away or in automated runs (unless faint_in_tests).
func _rolls_faint() -> bool:
	if not faint_in_tests and DebugTools.is_automated():
		return false
	if ridden or data.away or state in [State.SLEEP, State.NEST, State.HATCH, State.AWAY]:
		return false
	return _rng.randf() < FAINT_CHANCE


## Keeled over, lying out cold (not while straining, falling or getting up).
func fainted() -> bool:
	var down := CROW_LONG + FAINT_TREMBLE + FAINT_FALL
	return _faint_t >= down and _faint_t < down + FAINT_OUT


## The crow held on and on (head back, straining, quivering at the end), trembling,
## keeling over onto the ground with a thud, lying there, then shaking himself, getting
## up with a stagger and fluffing his feathers; he does nothing else meanwhile.
func _update_faint(delta: float) -> void:
	var was := _faint_t
	_faint_t += delta
	var t := _faint_t
	var fall_at := CROW_LONG + FAINT_TREMBLE
	var down_at := fall_at + FAINT_FALL
	var up_at := down_at + FAINT_OUT
	var stood_at := up_at + FAINT_RISE
	rig.crow = smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(CROW_LONG - 0.1, down_at, t))
	if t < CROW_LONG:
		rig.tremble = 0.3 * smoothstep(CROW_LONG - 1.4, CROW_LONG, t)
	elif t < fall_at:
		rig.tremble = lerpf(0.3, 1.0, smoothstep(CROW_LONG, CROW_LONG + 0.15, t))
	elif t < down_at:
		rig.tremble = 1.0 - (t - fall_at) / FAINT_FALL
	else:
		# Coming round: he shakes himself before he gets up.
		rig.tremble = 0.9 * smoothstep(up_at, up_at + 0.1, t) * (1.0 - smoothstep(up_at + 0.35, up_at + 0.55, t))
	var u := clampf((t - fall_at) / FAINT_FALL, 0.0, 1.0)
	rig.faint = u * u * (1.0 - smoothstep(up_at + 0.45, stood_at, t))
	rig.wobble = smoothstep(up_at + 0.4, up_at + 0.7, t) * (1.0 - smoothstep(stood_at - 0.3, stood_at + 0.3, t))
	rig.fluff = sin(PI * clampf((t - stood_at) / FAINT_FLUFF, 0.0, 1.0))
	if was < down_at and t >= down_at:
		Audio.play("soft", global_position + Vector3(0, 0.1, 0), -2.0, 0.05, &"Effects", 4.0, 0.6)
	if was < stood_at and t >= stood_at:
		Audio.animal_voice(&"rooster", true, global_position, -8.0)
	_faint_look -= delta
	if not fainted():
		_show_faint_label(false)
	elif _faint_look <= 0.0:
		_faint_look = 0.15
		_show_faint_label(_seen_by_player())
	if t >= stood_at + FAINT_FLUFF:
		_end_faint()
		_think = _rng.randf_range(0.3, 0.8)


func _end_faint() -> void:
	if _faint_t < 0.0:
		return
	_faint_t = -1.0
	rig.crow = 0.0
	rig.faint = 0.0
	rig.tremble = 0.0
	rig.wobble = 0.0
	rig.fluff = 0.0
	_show_faint_label(false)


## Whether the farmer is close and looking right at him, nothing solid in between.
func _seen_by_player() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var at := global_position + Vector3(0, 0.15, 0)
	var to := at - cam.global_position
	var d := to.length()
	if d > FAINT_SEEN or d < 0.05 or (-cam.global_basis.z).dot(to / d) < FAINT_LOOK:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, at, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _show_faint_label(on: bool) -> void:
	if on and _faint_label == null:
		_faint_label = Label3D.new()
		_faint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_faint_label.fixed_size = true
		_faint_label.font = UiTheme.font(800)
		_faint_label.font_size = 64
		_faint_label.pixel_size = 0.0009
		_faint_label.outline_size = 14
		_faint_label.outline_modulate = Color(0.08, 0.06, 0.04, 0.85)
		_faint_label.modulate = Color(1.0, 0.84, 0.42)
		_faint_label.no_depth_test = true
		_faint_label.render_priority = 10
		_faint_label.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_faint_label.layers = 2
		_faint_label.position = Vector3(0, 0.55, 0)
		add_child(_faint_label)
	if _faint_label:
		_faint_label.visible = on
		if on:
			_faint_label.text = tr("MSG_ROOSTER_FAINTED")


## 0..1: how far into the crowing pose (up quickly, held, eased back down).
static func _crow_envelope(t: float) -> float:
	return smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(CROW_TIME - 0.6, CROW_TIME, t))


# --- Frame update --------------------------------------------------------------------------

## The pose is visual only: it follows the rendered frame rate (the body itself is
## moved per physics tick and interpolated), and hitch catch-up ticks skip it. A
## ridden horse is posed by its rider.
func _process(delta: float) -> void:
	if not ridden:
		rig.animate(delta, _speed, _mode)


func _physics_process(delta: float) -> void:
	if ridden:
		return
	_state_time += delta
	_attention = maxf(_attention - delta, 0.0)
	_scared = maxf(_scared - delta, 0.0)
	_think -= delta
	_update_limp(delta)
	var chick := data.is_chick()
	if _think <= 0.0:
		# Chicks look up to their mother often: they keep close.
		_think = _rng.randf_range(0.3, 0.6) if chick else _rng.randf_range(0.8, 2.0)
		_decide()
	if chick:
		_update_cheep(delta)
	elif data.species == &"rooster" and data.adult:
		_update_crow(delta)
	if state == State.HATCH:
		_hatching(delta)
		_mode = AnimalRig.Mode.IDLE
		return
	if state == State.NEST:
		_sit_nest()
	elif (_attention > 0.0 or _crow_t >= 0.0 or _faint_t >= 0.0) and state != State.SLEEP:
		_speed = move_toward(_speed, 0.0, delta * 3.0)
	else:
		match state:
			State.WANDER, State.GO_EAT, State.GO_DRINK, State.SHELTER, State.FOLLOW, State.GO_NEST, State.BROOD:
				_move(delta)
			_:
				_speed = move_toward(_speed, 0.0, delta * 2.0)
	match state:
		State.NEST:
			# Settled down on the straw between the hops (standing up a moment before).
			var t := _state_time
			_mode = AnimalRig.Mode.SLEEP if t > NEST_HOP and t < _state_len - NEST_HOP - 1.3 else AnimalRig.Mode.IDLE
		State.GRAZE:
			_mode = AnimalRig.Mode.GRAZE
		State.EAT, State.DRINK:
			_mode = AnimalRig.Mode.EAT
		State.SLEEP:
			_mode = AnimalRig.Mode.SLEEP
		State.AWAY:
			_mode = AnimalRig.Mode.GRAZE if fmod(_state_time, 20.0) < 12.0 else AnimalRig.Mode.IDLE
		_:
			# A downy chick running to catch up flutters its stubs of wings (RUN); a crow is
			# posed by hand.
			if _speed > 0.05:
				# Bolting from a wolf it runs too (a bird flutters), not on a sore leg.
				var run := (_hurry > 1.5 and _look == &"chick") or (_scared > 0.0 and not data.injured())
				_mode = AnimalRig.Mode.RUN if run else AnimalRig.Mode.WALK
			else:
				_mode = AnimalRig.Mode.IDLE
	if _crow_t >= 0.0 or _faint_t >= 0.0:
		_mode = AnimalRig.Mode.WALK
	# Wetness only changes on clock ticks: skip the instance uniform write otherwise.
	if data.wet != _wet_shown:
		_wet_shown = data.wet
		rig.set_wet(_wet_shown)
	if absf(_age_shown - data.age_ratio()) > 0.001:
		refresh_body()
	_update_badge()


func _set_state(s: int, length := 3.0) -> void:
	if _nest >= 0 and s != State.GO_NEST and s != State.NEST:
		_drop_nest()
	state = s
	_state_time = 0.0
	_state_len = length


func _busy() -> bool:
	return (state == State.EAT or state == State.DRINK or state == State.GRAZE or state == State.IDLE) and _state_time < _state_len


## Picks what to do next from needs, weather and time of day.
func _decide() -> void:
	if data.away:
		if state != State.AWAY:
			_set_state(State.AWAY, 1e9)
		return
	# On a nest: nothing else until she has laid and hopped down; out of the egg, in the
	# middle of a crow or in a faint, nothing either.
	if state == State.NEST or state == State.HATCH or _crow_t >= 0.0 or _faint_t >= 0.0:
		return
	if data.is_chick() and _decide_chick():
		return
	var night := GameClock.is_night()
	var want_inside := housing.has_shelter() and (night or Weather.is_precipitating())
	var moving := state in [State.WANDER, State.GO_EAT, State.GO_DRINK, State.SHELTER, State.FOLLOW, State.GO_NEST, State.BROOD]
	# Shelter comes first: interrupt anything else (a hen bound for a nest is going in).
	if want_inside and not indoors:
		if housing.can_pass():
			if state != State.SHELTER and state != State.GO_NEST:
				_go(housing.random_indoor_point(_rng), true, State.SHELTER)
			return
		# Shut out (the coop door is closed): she waits by the ramp in the wet and the dark.
		if moving and not _path.is_empty():
			return
		var wait := housing.door_outside()
		if Vector2(wait.x - global_position.x, wait.z - global_position.z).length() > 1.8:
			var off := housing.frame.basis * Vector3(_rng.randf_range(-0.9, 0.9), 0.0, _rng.randf_range(0.0, 0.9))
			_go(wait + off, false, State.SHELTER)
		elif night:
			if state != State.SLEEP:
				_set_state(State.SLEEP, 1e9)
		elif not _busy():
			_set_state(State.IDLE, _rng.randf_range(3.0, 6.0))
		return
	if moving and not _path.is_empty():
		if state == State.FOLLOW:
			_follow_update()
		return
	if night:
		if state != State.SLEEP:
			_set_state(State.SLEEP, 1e9)
		return
	if state == State.SLEEP:
		_set_state(State.IDLE, _rng.randf_range(2.0, 5.0))
		return
	if _busy():
		return
	if _try_nest():
		return
	# Leave the barn when the weather is fine (not through a shut coop door).
	if indoors and not want_inside and housing.can_pass() and _rng.randf() < 0.45:
		_go(housing.random_outdoor_point(_rng), false, State.WANDER)
		return
	var water := housing.water
	var feed := housing.feed
	if data.hydration < 55.0 and water and not water.is_empty():
		_go(_trough_spot(water), housing.is_in_building(water.global_position), State.GO_DRINK)
		return
	if data.fullness < 60.0 and feed and not feed.is_empty():
		_go(_trough_spot(feed), housing.is_in_building(feed.global_position), State.GO_EAT)
		return
	if _player_has_food() and data.fullness < 97.0:
		_set_state(State.FOLLOW, 1e9)
		_follow_update()
		return
	var can_graze := not indoors and _grazing_ok()
	var roll := _rng.randf()
	if can_graze and roll < 0.5:
		_set_state(State.GRAZE, _rng.randf_range(6.0, 16.0))
	elif roll < 0.8:
		var p := housing.random_indoor_point(_rng) if indoors else housing.random_outdoor_point(_rng)
		_go(p, indoors, State.WANDER)
	else:
		_set_state(State.IDLE, _rng.randf_range(3.0, 8.0))


func _grazing_ok() -> bool:
	return not GameClock.is_night() and GameClock.get_season() != GameClock.Season.WINTER and Weather.snow_cover < 0.3


## Where to stand to eat or drink: in front of the trough (troughs face the housing's +Z).
func _trough_spot(t: Trough) -> Vector3:
	var along := _rng.randf_range(-t.reach(), t.reach())
	return t.global_position + housing.frame.basis * Vector3(along, 0, 0.45 + radius() * 1.1)


func _player_has_food() -> bool:
	var player := Game.player as Node3D
	if player == null or indoors:
		return false
	var s := PlayerState.selected_stack()
	if s == null or not Animals.accepts_food(data, s.item.id):
		return false
	var d := player.global_position.distance_to(global_position)
	return d < 8.0 and housing.in_pen(player.global_position, 1.5)


func _follow_update() -> void:
	if not _player_has_food():
		_set_state(State.IDLE, 2.0)
		_path.clear()
		_path_inside.clear()
		return
	var player := Game.player as Node3D
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() < 1.3 + radius():
		_path.clear()
		_path_inside.clear()
		_face(player.global_position)
		return
	var goal := player.global_position - to.normalized() * (1.2 + radius())
	goal = housing.clamp_to_pen(goal, radius())
	_path = [goal]
	_path_inside = [false]


## Plans a route (through the barn door when needed) and starts walking. With the way
## shut (a closed coop door) she stays where she is a while.
func _go(target: Vector3, target_inside: bool, new_state: int) -> void:
	# Half way through the doorway: planned from the side it really is on.
	if not _path_inside.is_empty() and _path_inside[0] != indoors:
		indoors = housing.is_in_building(global_position)
	var route := housing.plan_route(global_position, indoors, target, target_inside)
	_path.clear()
	_path_inside.clear()
	if route.is_empty():
		_set_state(State.IDLE, _rng.randf_range(3.0, 6.0))
		return
	for r: Array in route:
		_path.append(r[0])
		_path_inside.append(r[1])
	_set_state(new_state, 1e9)


func _move(delta: float) -> void:
	if _path.is_empty():
		_arrived()
		return
	var target := _path[0]
	var pos := global_position
	var to := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var dist := to.length()
	# A chick gets right up to its spot by its mother (the door's waypoints as any bird).
	var reach := CHICK_REACH if state == State.BROOD and _path.size() == 1 else 0.3
	if dist < reach:
		indoors = _path_inside[0]
		_path.pop_front()
		_path_inside.pop_front()
		if _path.is_empty():
			_arrived()
		return
	var dir := to / dist
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 3.5, 0.0, 1.0))
	var facing := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var align := maxf(0.0, facing.dot(dir))
	var target_speed := _move_speed * (0.3 + 0.7 * align) * (1.25 if state == State.SHELTER else 1.0) \
			* (_hurry if state == State.BROOD else 1.0) * (SCARE_PACE if _scared > 0.0 else 1.0)
	if data.injured():
		# On a sore leg: slower, and slower still each time it takes the weight; stopped dead
		# in a stumble.
		target_speed *= INJURED_PACE * (1.0 - LIMP_HITCH * rig.limp_load())
		if _stumble_t >= 0.0:
			target_speed = 0.0
	_speed = move_toward(_speed, minf(target_speed, dist * 2.0 + 0.2), delta * (3.0 if state == State.BROOD else 1.6))
	var p := pos + facing * _speed * delta + _separation() * delta
	var transit := _path_inside[0] != indoors
	if not transit:
		p = housing.constrain(p, radius(), indoors)
	p.y = housing.ground_height(p)
	global_position = p


func _separation() -> Vector3:
	var push := Vector3.ZERO
	var chick := data.is_chick()
	for other: Animal in housing.animals:
		if other == self or other.ridden or other.state == State.HATCH:
			continue
		# Grown birds step over chicks; a chick snuggles right up to its mother.
		if not chick and other.data.is_chick():
			continue
		var d := global_position - other.global_position
		d.y = 0.0
		var min_d := radius() + other.radius()
		if chick and other.data.id == data.mother:
			min_d *= 0.25 if state == State.SLEEP or GameClock.is_night() else 0.8
		elif chick and other.data.is_chick() and GameClock.is_night():
			# Huddled together under her.
			min_d *= 0.5
		var l := d.length()
		if l < min_d and l > 0.001:
			push += d / l * (min_d - l) * 2.0
	return push


func _arrived() -> void:
	match state:
		State.GO_EAT:
			_set_state(State.EAT, _rng.randf_range(6.0, 10.0))
			Animals.eat_from(data, housing.feed)
			if housing.feed:
				_face(housing.feed.global_position)
		State.GO_DRINK:
			_set_state(State.DRINK, _rng.randf_range(4.0, 7.0))
			Animals.drink_from(data, housing.water)
			if housing.water:
				_face(housing.water.global_position)
		State.SHELTER:
			_set_state(State.SLEEP if GameClock.is_night() else State.IDLE, _rng.randf_range(4.0, 10.0))
		State.BROOD:
			_hurry = 1.0
			_set_state(State.IDLE, _rng.randf_range(0.3, 0.9))
		State.GO_NEST:
			var coop := ChickenCoop.of(housing)
			if coop == null or not coop.nest_filled(_nest):
				_set_state(State.IDLE, 2.0)
				return
			_nest_from = global_position
			_laid = false
			_face(coop.nest_seat(_nest))
			_set_state(State.NEST, NEST_HOP * 2.0 + _rng.randf_range(NEST_SIT.x, NEST_SIT.y))
		State.FOLLOW:
			pass
		_:
			var graze := not indoors and _grazing_ok() and _rng.randf() < 0.6
			_set_state(State.GRAZE if graze else State.IDLE, _rng.randf_range(4.0, 10.0))


# --- Laying in a nest box -----------------------------------------------------------------

## An egg due and a bedded box free: off to it (through the door when she is out).
func _try_nest() -> bool:
	var coop := ChickenCoop.of(housing)
	if coop == null or not coop.wants_to_lay(data.id):
		return false
	if not indoors and not housing.can_pass():
		return false
	var i := coop.claim_nest(self)
	if i < 0:
		return false
	_nest = i
	_go(coop.nest_front(i), true, State.GO_NEST)
	return true


## The hop up, sitting (the egg comes three quarters of the way through), the hop down
## and out into the yard.
func _sit_nest() -> void:
	var coop := ChickenCoop.of(housing)
	if coop == null or _nest < 0:
		_set_state(State.IDLE, 1.0)
		return
	_speed = 0.0
	var seat := coop.nest_seat(_nest)
	var t := _state_time
	var down_at := _state_len - NEST_HOP
	if t < NEST_HOP:
		global_position = _hop(_nest_from, seat, t / NEST_HOP)
		return
	if t < down_at:
		global_position = seat
		var out := coop.nest_out(_nest)
		rotation.y = lerp_angle(rotation.y, atan2(-out.x, -out.z), 0.06)
		if not _laid and t >= NEST_HOP + (down_at - NEST_HOP) * 0.75:
			_laid = true
			coop.lay_in_nest(self, _nest)
		return
	if not _laid:
		_laid = true
		coop.lay_in_nest(self, _nest)
	if t < _state_len:
		global_position = _hop(seat, _nest_from, (t - down_at) / NEST_HOP)
		return
	global_position = _nest_from
	_set_state(State.IDLE, _rng.randf_range(1.0, 2.0))
	# Back out into the yard, unless it is night or wet (or the door is shut).
	if housing.can_pass() and not GameClock.is_night() and not Weather.is_precipitating():
		_go(housing.random_outdoor_point(_rng), false, State.WANDER)


## A hop from `a` to `b`, `u` 0..1 of the way, in a little arc.
func _hop(a: Vector3, b: Vector3, u: float) -> Vector3:
	var k := clampf(u, 0.0, 1.0)
	return a.lerp(b, smoothstep(0.0, 1.0, k)) + Vector3(0, sin(k * PI) * 0.3, 0)


func _drop_nest() -> void:
	var coop := ChickenCoop.of(housing)
	if coop:
		coop.release_nest(self)
	_nest = -1


func _face(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


# --- Hurt and frightened --------------------------------------------------------------------

## The limp of a hurt one (rig.limp) and now and then, walking, a stumble (rig.stumble):
## it catches the sore leg, lurches and stops a moment.
func _update_limp(delta: float) -> void:
	var hurt := data.injured()
	rig.limp = move_toward(rig.limp, 1.0 if hurt else 0.0, delta * 2.0)
	if _stumble_t >= 0.0:
		_stumble_t += delta
		rig.stumble = sin(PI * clampf(_stumble_t / STUMBLE_TIME, 0.0, 1.0))
		if _stumble_t >= STUMBLE_TIME:
			_stumble_t = -1.0
			rig.stumble = 0.0
		return
	if not hurt or _speed < 0.1:
		return
	_stumble_wait -= delta
	if _stumble_wait <= 0.0:
		_stumble_wait = _rng.randf_range(STUMBLE_EVERY.x, STUMBLE_EVERY.y)
		_stumble_t = 0.0


## A wolf bit it and it lived: a start, a cry, a few feathers (or a little wool) off it.
## From now on it limps (data.injured).
func hurt() -> void:
	_end_faint()
	_stumble_t = 0.0
	_scared = SCARE_TIME
	Audio.animal_voice(data.species, data.adult, global_position + Vector3(0, 0.4, 0), -2.0)
	if AnimalTable.is_poultry(data.species):
		CoopDoor.feathers(global_position + Vector3(0, 0.35, 0))
	_badge_key = ""


## A wolf coming at it from `from`: it bolts the other way for a few seconds, as far as its
## pen (or its side of the coop wall) lets it (not one sitting on a nest, hatching, ridden
## or away).
func scare(from: Vector3) -> void:
	if ridden or data.away or state in [State.NEST, State.HATCH, State.AWAY, State.RIDDEN]:
		return
	if _scared > SCARE_TIME * 0.5:
		return
	_end_faint()
	_scared = SCARE_TIME
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	var to := global_position + away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * SCARE_RUN
	to = housing.constrain(to, radius(), indoors)
	_go(to, indoors, State.WANDER)
	if _rng.randf() < 0.6:
		Audio.animal_voice(data.species, data.adult, global_position + Vector3(0, 0.4, 0), -6.0)


# --- Badges -------------------------------------------------------------------------------

func status_key() -> String:
	if data.injured():
		return "injured"
	if data.sick:
		return "sick"
	if data.wet > 0.25 and not indoors and Weather.is_precipitating():
		return "wet"
	if data.cold:
		return "cold"
	if data.hydration < 25.0:
		return "thirsty"
	if data.fullness < 25.0:
		return "hungry"
	if data.product_ready and data.species == &"cow":
		return "milk"
	if data.product_ready and data.species == &"sheep":
		return "wool"
	return ""


func _update_badge() -> void:
	var key := status_key()
	if key == _badge_key:
		return
	_badge_key = key
	_badge.visible = key != ""
	if key != "":
		_badge.texture = BADGES[key]


func pop_heart() -> void:
	var heart := Sprite3D.new()
	heart.texture = HEART
	heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heart.pixel_size = 0.0022
	heart.shaded = false
	heart.no_depth_test = true
	heart.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	heart.layers = 2
	# Rises by tween (not per physics tick).
	heart.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	heart.position = _badge.position - Vector3(0, 0.1, 0)
	add_child(heart)
	var tw := heart.create_tween()
	tw.set_parallel(true)
	tw.tween_property(heart, "position:y", heart.position.y + 0.7, 1.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(heart, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(heart.queue_free)


# --- Interaction --------------------------------------------------------------------------

func can_ride() -> bool:
	return data.info().get("rideable", false) and data.adult and not data.sick and not data.injured() and data.health > 25.0


func interact_prompt(_player: Node) -> String:
	if _faint_t >= 0.0:
		return ""
	if can_ride():
		return tr("ACTION_RIDE")
	return tr("ACTION_PET") if not data.petted_today else ""


func info_prompt() -> String:
	return tr("ACTION_INFO")


func interact(player: Node) -> void:
	if _faint_t >= 0.0:
		return
	if can_ride():
		(player as Player).mount(self)
		return
	if not data.petted_today:
		Animals.pet(data)
		pop_heart()
		_face((player as Node3D).global_position)
		_attention = 2.0


func use_prompt(player: Node, stack: ItemStack) -> String:
	var a := use_action(player, stack)
	# A cow already milked shows no verb (pulling the pail on her anyway says why).
	if a.is_empty() or a.get("dry", false):
		return ""
	return tr(a["verb"])


## Pulling the pail on a cow with no milk yet: says when it comes (a toast, not a line
## that would sit under the prompt right after she has been milked).
func can_start(action: Dictionary, _stack: ItemStack) -> String:
	if action.get("dry", false):
		return tr("HINT_MILK_TOMORROW")
	return ""


## A plain line under the prompts while the farmer holds this animal's tool (shears for
## a sheep, the pail for a cow) and there is nothing to take yet: when the fleece is
## grown, or that the young one is too small yet (a milked cow says nothing until the
## pail is pulled on her again, can_start).
func hint_prompt() -> String:
	if data.injured():
		# Hurt: how long it has left to be treated (the vet in town).
		return tr("HINT_ANIMAL_INJURED") % maxi(1, ceili(Animals.hours_left(data.id)))
	if _faint_t >= 0.0 or data.product_ready:
		return ""
	var stack := PlayerState.selected_stack()
	var tool: StringName = data.info().get("tool", &"")
	if stack == null or tool == &"" or stack.item.id != tool:
		return ""
	if not data.adult:
		return tr("HINT_ANIMAL_TOO_YOUNG")
	match data.species:
		&"sheep":
			var days := wool_days_left()
			return tr("HINT_WOOL_TOMORROW") if days <= 1 else tr("HINT_WOOL_DAYS") % days
	return ""


## Mornings (fed ones) until a shorn sheep's fleece has grown back.
func wool_days_left() -> int:
	var per_day := 1.0 / float(data.info().get("product_days", 3))
	return maxi(1, ceili((1.0 - data.wool) / per_day - 0.001))


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	_attention = maxf(_attention, 0.6)
	if stack == null:
		return {}
	# Out cold: nothing for him till he comes round (the feeder he lies by still fills).
	if _faint_t >= 0.0:
		var by := _feeder_behind(stack)
		return by.use_action(_player, stack) if by else {}
	var id := stack.item.id
	# Hurt, it gives nothing until it has been treated.
	if id == &"milk_pail" and data.species == &"cow" and data.product_ready and not data.injured():
		return {"id": "milk", "verb": "ACTION_MILK", "label": "PROGRESS_MILKING", "duration": 2.0}
	if id == &"milk_pail" and data.species == &"cow" and data.adult and not data.injured():
		# Milked already (or not fed for the morning's milk): refused in can_start.
		return {"id": "milk", "verb": "ACTION_MILK", "label": "PROGRESS_MILKING", "duration": 2.0, "dry": true}
	if id == &"shears" and data.species == &"sheep" and data.product_ready and not data.injured():
		return {"id": "shear", "verb": "ACTION_SHEAR", "label": "PROGRESS_SHEARING", "duration": 2.5, "wear": true}
	if id == &"brush" and not data.brushed_today:
		return {"id": "brush", "verb": "ACTION_BRUSH", "label": "PROGRESS_BRUSHING", "duration": 1.6}
	if id == &"medicine" and data.sick:
		return {"id": "medicine", "verb": "ACTION_MEDICINE", "label": "PROGRESS_TREATING", "duration": 1.2}
	# Crowding its feeder: what the feeder takes goes into it, not down this one beak.
	var feeder := _feeder_behind(stack)
	if feeder:
		return feeder.use_action(_player, stack)
	if Animals.accepts_food(data, id) and data.fullness < 95.0:
		return {"id": "feed", "verb": "ACTION_FEED", "label": "PROGRESS_FEEDING", "duration": 0.8}
	return {}


## Its home's feeder when this animal stands at it and the farmer holds something the
## feeder takes while it has room (hungry hens crowd an empty feeder, so the look lands
## on them rather than on it).
func _feeder_behind(stack: ItemStack) -> Trough:
	if housing == null or not is_instance_valid(housing.feed) or stack == null:
		return null
	var feeder := housing.feed
	if not feeder.takes(stack.item.id) or feeder.amount >= feeder.capacity - 0.01:
		return null
	return feeder if global_position.distance_to(feeder.global_position) < FEEDER_REACH else null


func complete_use(_player: Node, stack: ItemStack, action: Dictionary) -> void:
	match action.get("id", ""):
		"milk":
			Animals.collect_product(data)
		"shear":
			Animals.collect_product(data)
			refresh_body()
		"brush":
			Animals.brush(data)
			pop_heart()
		"medicine":
			PlayerState.inventory.remove_item(&"medicine", 1)
			Animals.give_medicine(data)
		"feed":
			PlayerState.inventory.remove_item(stack.item.id, 1)
			Animals.hand_feed(data)
			pop_heart()
		"fill_feed":
			var feeder := _feeder_behind(stack)
			if feeder:
				feeder.complete_use(_player, stack, action)
	_attention = 1.5


# --- Riding ------------------------------------------------------------------------------

func set_ridden(on: bool) -> void:
	ridden = on
	_shape.set_deferred("disabled", on)
	if on:
		_path.clear()
		_path_inside.clear()
		_set_state(State.RIDDEN, 1e9)
		remove_from_group(&"interactable")
	else:
		add_to_group(&"interactable")
		# Set down where the rider left it: no glide from the last interpolated frame.
		reset_physics_interpolation()
		var in_pen := housing.in_pen(global_position, -0.5)
		data.away = not in_pen
		data.away_pos = global_position
		data.away_yaw = rotation.y
		indoors = in_pen and housing.is_in_building(global_position)
		_set_state(State.AWAY if data.away else State.IDLE, 2.0)
