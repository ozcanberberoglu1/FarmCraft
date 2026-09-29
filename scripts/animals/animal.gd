class_name Animal
extends AnimatableBody3D
## A farm animal in the world. Its persistent state lives in `data` (simulated by
## the Animals autoload); this node handles the body: AI (wander, graze, eat and
## drink at the troughs, shelter in bad weather and at night, sleep, follow food),
## player interaction and status badges. A hen of a kit-built coop with an egg due walks
## to a bedded nest box, hops in, sits on it a while, lays and goes back out.

enum State { IDLE, WANDER, GRAZE, GO_EAT, EAT, GO_DRINK, DRINK, SHELTER, SLEEP, FOLLOW, AWAY, RIDDEN, GO_NEST, NEST }

const BADGES := {
	"sick": preload("res://art/icons/ui/badge_sick.svg"), "wet": preload("res://art/icons/ui/badge_rain.svg"),
	"cold": preload("res://art/icons/ui/badge_cold.svg"), "thirsty": preload("res://art/icons/ui/badge_water.svg"),
	"hungry": preload("res://art/icons/ui/badge_hungry.svg"), "milk": preload("res://art/icons/ui/badge_milk.svg"),
	"wool": preload("res://art/icons/ui/badge_wool.svg"),
}
const HEART := preload("res://art/icons/ui/heart.svg")
## Seconds of a hen's hop up into a nest box (and down again), and of sitting on it.
const NEST_HOP := 0.5
const NEST_SIT := Vector2(16.0, 26.0)

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
	rig = AnimalModels.create_rig(data.species)
	add_child(rig)
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
	var t := data.age_ratio()
	rig.set_variant(data.variant, not data.adult)
	rig.set_age(t)
	rig.set_wool(data.wool if data.species == &"sheep" else 1.0)
	var size: Vector3 = data.info().get("size", Vector3.ONE)
	var s := rig.scale.x
	(_shape.shape as BoxShape3D).size = size * s
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
	_set_state(State.SLEEP if GameClock.is_night() else State.IDLE, 2.0)


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
	_think -= delta
	if _think <= 0.0:
		_think = _rng.randf_range(0.8, 2.0)
		_decide()
	if state == State.NEST:
		_sit_nest()
	elif _attention > 0.0 and state != State.SLEEP:
		_speed = move_toward(_speed, 0.0, delta * 3.0)
	else:
		match state:
			State.WANDER, State.GO_EAT, State.GO_DRINK, State.SHELTER, State.FOLLOW, State.GO_NEST:
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
			_mode = AnimalRig.Mode.WALK if _speed > 0.05 else AnimalRig.Mode.IDLE
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
	# On a nest: nothing else until she has laid and hopped down.
	if state == State.NEST:
		return
	var night := GameClock.is_night()
	var want_inside := housing.has_shelter() and (night or Weather.is_precipitating())
	var moving := state in [State.WANDER, State.GO_EAT, State.GO_DRINK, State.SHELTER, State.FOLLOW, State.GO_NEST]
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
	var along := _rng.randf_range(-0.7, 0.7) if t.long else _rng.randf_range(-0.15, 0.15)
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
	if dist < 0.3:
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
	var target_speed := _move_speed * (0.3 + 0.7 * align) * (1.25 if state == State.SHELTER else 1.0)
	_speed = move_toward(_speed, minf(target_speed, dist * 2.0 + 0.2), delta * 1.6)
	var p := pos + facing * _speed * delta + _separation() * delta
	var transit := _path_inside[0] != indoors
	if not transit:
		p = housing.constrain(p, radius(), indoors)
	p.y = housing.ground_height(p)
	global_position = p


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other: Animal in housing.animals:
		if other == self or other.ridden:
			continue
		var d := global_position - other.global_position
		d.y = 0.0
		var min_d := radius() + other.radius()
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
		var out := coop.nest_out()
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


# --- Badges -------------------------------------------------------------------------------

func status_key() -> String:
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
	return data.info().get("rideable", false) and data.adult and not data.sick and data.health > 25.0


func interact_prompt(_player: Node) -> String:
	if can_ride():
		return tr("ACTION_RIDE")
	return tr("ACTION_PET") if not data.petted_today else ""


func info_prompt() -> String:
	return tr("ACTION_INFO")


func interact(player: Node) -> void:
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
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	_attention = maxf(_attention, 0.6)
	if stack == null:
		return {}
	var id := stack.item.id
	if id == &"milk_pail" and data.species == &"cow" and data.product_ready:
		return {"id": "milk", "verb": "ACTION_MILK", "label": "PROGRESS_MILKING", "duration": 2.0}
	if id == &"shears" and data.species == &"sheep" and data.product_ready:
		return {"id": "shear", "verb": "ACTION_SHEAR", "label": "PROGRESS_SHEARING", "duration": 2.5, "wear": true}
	if id == &"brush" and not data.brushed_today:
		return {"id": "brush", "verb": "ACTION_BRUSH", "label": "PROGRESS_BRUSHING", "duration": 1.6}
	if id == &"medicine" and data.sick:
		return {"id": "medicine", "verb": "ACTION_MEDICINE", "label": "PROGRESS_TREATING", "duration": 1.2}
	if Animals.accepts_food(data, id) and data.fullness < 95.0:
		return {"id": "feed", "verb": "ACTION_FEED", "label": "PROGRESS_FEEDING", "duration": 0.8}
	return {}


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
