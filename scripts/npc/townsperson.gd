class_name Townsperson
extends AnimatableBody3D
## One of Yeşilova's townspeople (see TownPeople for who stands where): a HumanRig body
## doing its job or its day, looking at the player when he comes close and greeting him.
##
## Acts: STAND (idle, looking about), TALK (the car dealer: hands clasped, then selling
## with his hands), TILL (the grocer counting notes at the till), WIPE (the pump
## attendant wiping his pump), WRITE (the stockman at his hatch with the ledger), SWEEP
## (the shop boy sweeping the forecourt, a step at a time), BENCH (an old man sitting),
## TEA (sitting with a glass of tea, sipping), WALK (along a route on the pavements,
## over the zebra crossing when the street is clear, round the player, vehicles and
## each other; turning back when the way stays blocked), PET (down on one knee by a dog,
## stroking its back, the other hand on her knee) and DOORWAY (standing in an open
## doorway, a hand on the door's edge), FISH (at the water with a rod, the float out at
## fish_spot; show_catch() lands a fish and holds it up) and CLAP (applauding; clap()
## claps for a while in any act; cheer() throws both arms up for a while).
##
## His own things: the shop boy's broom is always in his hands (sweeping; carried in his
## left fist when he walks anywhere, stood beside him when he stops), laid on the ground
## where he stands while his hands are busy with something else (a rod, clapping) and
## picked up again when he walks on; Nuri Hoca's tea glass shows only at his tea (he
## leaves it on the table when he goes anywhere).
##
## Scripted by the story (Zeynep): walk_to() walks a path and calls back, receive()
## takes a thing in both hands and holds it (drop_held() lets it go), talk() gestures
## and nods to the player for a line of dialogue.
##
## E: a worker at a service (the counter, a pump with the player's vehicle at it, the
## dealer's desk, the Animal Market hatch) greets and opens it, so standing there never
## steals the service's prompt; anyone else is greeted and answers with a line of his
## own. Workers also welcome the player when he walks up. Animated only within
## ANIMATE_RANGE of the camera (less often off screen), drawn up to SHOW_RANGE.

enum Act { STAND, TALK, TILL, WIPE, WRITE, SWEEP, BENCH, TEA, WALK, PET, DOORWAY, FISH, CLAP }

const GROUP := &"townspeople"
const ANIMATE_RANGE := 60.0
## How far his body keeps off a vehicle's (m, Vehicle.keep_out).
const CAR_KEEP := 0.3
const NEAR_RANGE := 25.0
## Drawn up to (by graphics preset, LOW..ULTRA).
const SHOW_RANGE: Array[float] = [70.0, 90.0, 120.0, 140.0]
const LOOK_RANGE := 6.5
const WELCOME_RANGE := 4.0
const WELCOME_COOLDOWN := 150.0
const BUBBLE_SECONDS := 4.0
const GREET_SECONDS := 1.9
## Nuri Hoca's greeting: the glass put down on the table, the hand on the heart, the
## glass picked up again.
const TEA_GREET := 3.6
## How many lines each person has (SAY_<PERSON>_1..n).
const LINES := 2
## Walkers: how far off the route's line they step aside, how long they wait for a
## blocked way before turning back.
const MAX_LATERAL := 0.85
const GIVE_UP := 4.5

var person: StringName
var act := Act.STAND
var rig: HumanRig
## The service E opens (a TownPoint), or the pumps the attendant serves.
var service: Node
var pumps: Array = []
var worker := false
## Gone to a town event (EventCrowd): his service stays open without him (an honesty
## box: TownPeople's sign), E on him at the event is a greeting only.
var away := false
## Heights above the floor: the work surface (counter) and the seat.
var work_height := 1.0
var seat_height := 0.45
var waves := false
var hands_behind := false
var walk_speed := 1.1
## Walkers: waypoints {p: Vector3 (y ignored), wait: seconds, face: yaw or NAN}; a leg
## from one side of the street to the other is the zebra crossing.
var route: Array = []
## The sweeper: the line he sweeps along (world XZ, from - to).
var sweep_from := Vector3.ZERO
var sweep_to := Vector3.ZERO
## The tea drinker: the middle of his table's top (world), where he puts his glass down.
var tea_table := Vector3.INF
## PET: the dog stroked (its pet_point() if it has one, else its position); she turns to
## have it beside her on the stroking hand's side (PET_ASIDE) and goes down on the knee
## next to it, the other knee up in front of her, clear of the dog's head (stand her
## about half a metre from where the hand goes, the dog sitting beside her).
var pet_target: Node3D
## PET: the stroking hand, "_l" or "_r" ("": the one on the dog's side as she comes to it).
var pet_hand := ""
## DOORWAY: where the hand rests on the door's edge (world); INF: no hand on the door.
var door_hand := Vector3.INF

var _floor_y := 0.0
## The ground's normal under him at the last look (world) and its slope as his legs
## have it (rise a metre to his left, forward).
var _floor_n := Vector3.UP
var _slope := Vector2.ZERO
var _yaw := 0.0
var _speed := 0.0
var _wp := 1
var _dir := 1
var _wait := 0.0
var _blocked := 0.0
var _lateral := 0.0
var _crossing := false
var _probe_t := 0.0
var _greet_t := 99.0
var _stop_t := 0.0
var _line := 0
var _welcomed_at := -999.0
var _bubble: Label3D
var _bubble_t := 0.0
var _anim_acc := 0.0
var _look_target := Vector3.ZERO
var _look_t := 0.0
var _look_w := 0.0
var _prop: Node3D
var _sweep_s := 0.0
var _sweep_n := 0
var _step_left := 0.0
var _last_stroke := 0.0
var _last_step_phase := 0.0
var _on_screen: VisibleOnScreenNotifier3D
var _clock := 0.0
## The broom: 0 sweeping .. 1 held upright at his side (stopped to greet); the bristles'
## height above the ground; the right hand still on the handle.
var _broom_hold := 0.0
var _broom_lift := 0.0
var _broom_two_hands := true
## His own thing (_prop): "broom" or "glass" ("": none); whether it may show at all
## (show_own_props).
var _prop_kind := ""
var _props_on := true
## The broom laid on the ground (world) while his hands do something else; null: in his
## hands.
var _broom_down: Variant = null
## Carrying the broom: 0 stood beside him .. 1 carried along at a walk; the handle's way
## (body frame, bristles to top) as posed.
var _carry_w := 0.0
var _carry_axis := Vector3.UP
## Carried along, the fist holds the handle this far up from the bristles' ends (metres).
const CARRY_GRIP := 0.85
## The tea glass: in his hand, or on the table at _glass_spot (body frame).
var _glass_in_hand := true
var _glass_spot := Vector3(-0.16, 0.73, 0.46)
## Microseconds all townspeople spent posing their bodies (a cost gauge for tests).
static var anim_usec := 0

## Getting down on a knee or up again takes this long (seconds).
const KNEEL_TIME := 0.8
## One stroke of a dog's back and the hand back to where it starts (seconds, metres).
const STROKE_TIME := 2.3
const STROKE_LEN := 0.11
## How steeply a stroke goes down the back from pet_point (radians).
const STROKE_SLOPE := 0.3
## Petting, how far she turns from facing where the hand goes (radians): the dog sits at
## her side, not in front of the knee that is up and the hand on it.
const PET_ASIDE := 1.35
## receive(): the hands out to the thing (seconds), then brought in against her front.
const TAKE_TIME := 0.75
const BRING_TIME := 0.8
## The hand to the door's edge or away (seconds).
const DOOR_HAND_TIME := 0.5

## PET: 0 standing .. 1 down on the knee; the knee's (and the stroking hand's) side.
var _kneel := 0.0
var _pet_side := "_r"
## The way a stroke runs along the dog's back (body frame, level): its pet_along() if it
## has one (toward the tail); ZERO: straight on away from her.
var _pet_along := Vector3.ZERO
var _door_w := 0.0
## walk_to(): the points left and what to call at the end; the player stands in her way
## (she waits for him).
var _path: Array[Vector3] = []
var _path_done := Callable()
var _way_blocked := false
## talk(): seconds of the line left.
var _talk_t := 0.0
## receive(): the thing (held once it is in her hands: a child of the body), seconds
## since she reached for it, its box (its own frame), the axes of it her hands take
## (the side, index and sign; and which is up), where it was taken (body frame).
var _held: Node3D
var _held_t := 0.0
var _held_box := AABB()
var _held_side := Vector3.RIGHT
var _held_up := Vector3.UP
var _held_from := Transform3D.IDENTITY
var _held_in_hand := false
## How much the hands hold something (0..1: drop_held() lets them fall back).
var _hold_w := 0.0
var _hold_last: Array = []
## Where the dog's stroked and the door's edge were last (body frame), for the hands
## going back after the story let them go.
var _pet_last := Vector3(0.0, 0.5, 0.5)
var _door_last := Vector3(0.3, 1.0, 0.0)
## talk(): seconds since the line began.
var _talk_el := 0.0

## FISH: where the float sits on the water (world), the rod (a FishModels rod id).
var fish_spot := Vector3.INF
var rod_model := &"cane_rod"
## A catch shown (show_catch): this long from the strike to the fish put away (seconds).
const CATCH_SHOW := 5.2
var _rod: Node3D
var _bob: MeshInstance3D
var _fline: FishingLine
var _rod_tip := Vector3.ZERO
var _rod_lift := 0.0
var _catch_t := -1.0
var _catch_mi: MeshInstance3D
var _catch_len := 0.3
var _nibble_t := 0.0
## clap(): seconds of applause left; cheer(): of arms up.
var _clap_t := 0.0
var _cheer_t := 0.0


func setup(model: StringName, tints: Dictionary = {}) -> void:
	rig = HumanRig.create(model, tints)
	rig.name = "Body"
	add_child(rig)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")
	collision_layer = 4 | 16
	collision_mask = 0
	sync_to_physics = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	var seated := act in [Act.BENCH, Act.TEA]
	cap.height = 1.25 if seated else 1.72
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5 + (0.05 if seated else 0.0), 0.1 if seated else 0.0)
	add_child(cs)
	_on_screen = VisibleOnScreenNotifier3D.new()
	_on_screen.aabb = AABB(Vector3(-0.6, 0, -0.6), Vector3(1.2, 1.9, 1.2))
	add_child(_on_screen)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font = UiTheme.font(700)
	_bubble.font_size = 44
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.05, 0.05, 0.06, 0.85)
	_bubble.modulate = Color(1.0, 0.97, 0.9)
	_bubble.pixel_size = 0.0021
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.width = 700.0
	_bubble.visible = false
	_bubble.fixed_size = false
	_bubble.no_depth_test = false
	add_child(_bubble)
	_yaw = rotation.y
	_floor_y = global_position.y
	_gait_style()
	if act == Act.SWEEP:
		_sweep_s = (_flat(position) - _flat(sweep_from)).dot((_flat(sweep_to) - _flat(sweep_from)).normalized())
		_prop = _broom()
		_prop_kind = "broom"
		rig.add_child(_prop)
	elif act == Act.TEA:
		_prop = _tea_glass()
		_prop_kind = "glass"
		rig.add_child(_prop)
		if tea_table.is_finite():
			# On the near side of the table, clear of the glasses standing on it.
			var c := to_local(tea_table)
			var toward := Vector3(-0.12, 0.0, 0.2) - Vector3(c.x, 0.0, c.z)
			_glass_spot = Vector3(c.x, c.y, c.z) + toward.normalized() * minf(0.27, toward.length())
	rig.reset()
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	_snap_to_ground.call_deferred()


func _apply_quality() -> void:
	rig.apply_quality()
	var r: float = SHOW_RANGE[Settings.quality]
	rig.body.visibility_range_end = r
	rig.body.visibility_range_end_margin = 8.0
	rig.body.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if _prop:
		for mi: MeshInstance3D in _prop.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = minf(r, 60.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if Settings.quality == Settings.Quality.LOW else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _snap_to_ground() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var h := _ground(global_position.x, global_position.z, global_position.y)
	if act in [Act.BENCH, Act.TEA]:
		return
	global_position.y = h
	_floor_y = h


func _ground(x: float, z: float, near_y: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, near_y + 1.2, z), Vector3(x, near_y - 2.0, z), 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return near_y
	# (a kerb's face or a wall's foot is no slope to walk on)
	var n: Vector3 = hit["normal"]
	_floor_n = n if n.y > 0.85 else Vector3.UP
	return (hit["position"] as Vector3).y


## How he walks (HumanRig's gait_*): everyone a little his own; Ayşe Teyze's short,
## careful steps with a little stoop and her arms hardly swinging, Halil's unhurried
## old man's walk, Emre's long springy stride, Zeynep's light quick step.
func _gait_style() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(String(person))
	rig.gait_stride = r.randf_range(0.95, 1.05)
	rig.gait_arms = r.randf_range(0.85, 1.15)
	rig.gait_bounce = r.randf_range(0.9, 1.1)
	rig.gait_roll = r.randf_range(0.9, 1.05)
	match person:
		&"villager":
			rig.gait_stride = 0.88
			rig.gait_arms = 0.55
			rig.gait_bounce = 0.7
			rig.gait_roll = 0.7
			rig.gait_stoop = 0.1
		&"farmer":
			rig.gait_stride = 0.95
			rig.gait_bounce = 0.8
			rig.gait_roll = 0.8
			rig.gait_stoop = 0.05
		&"young":
			rig.gait_stride = 1.05
			rig.gait_arms = 1.15
			rig.gait_bounce = 1.15
			rig.gait_roll = 1.1
		&"zeynep":
			rig.gait_stride = 0.94
			rig.gait_arms = 0.95
			rig.gait_bounce = 1.15
			rig.gait_roll = 1.1


# --- Interaction -----------------------------------------------------------------------------

func interact_title() -> String:
	var title := tr("PERSON_" + String(person).to_upper())
	# Befriended by greetings (Relations): his hearts once there are some points.
	if Relations.TOWN_GIFTS.has(person) and Relations.points_of(person) > 0:
		return "%s  %s" % [title, Relations.hearts_text(person)]
	return title


func interact_prompt(player: Node) -> String:
	var s := service_now()
	if s != null:
		return s.interact_prompt(player)
	return tr("ACTION_GREET")


func interact(player: Node) -> void:
	greet()
	befriend()
	var s := service_now()
	if s != null:
		s.interact(player)


## The player's greeting counts toward the friendship with him (Relations.greet: once a
## day); on a greeting after a new heart he gives a small gift: his line in the bubble, a
## note, the things into the bag (a full bag: at the player's feet).
func befriend() -> void:
	var gift := Relations.greet(person)
	if gift.is_empty():
		return
	say(tr("GIFT_SAY_%s" % String(person).to_upper()))
	Relations.hand_gift(gift)
	Game.notify(tr("MSG_TOWN_GIFT") % [tr("PERSON_" + String(person).to_upper()), Relations.gift_text(gift)], Relations.NOTE_COLOR)
	Audio.ui("confirm", -6.0)


## The service E on this person opens now: his counter or desk, or the pump the
## player's vehicle stands at (the attendant); null: a greeting only.
func service_now() -> Node:
	if away:
		return null
	if service != null and is_instance_valid(service):
		return service
	for p: Node3D in pumps:
		if is_instance_valid(p) and Town._nearest_owned_vehicle(p.global_position, 7.5) != null:
			return p
	return null


## Says the next of his lines (a speech bubble over his head) with a gesture, turned
## to the player; a walker stops for it.
func greet(line := -1) -> void:
	_line = (line if line >= 0 else _line) % LINES
	say(tr("SAY_%s_%d" % [String(person).to_upper(), _line + 1]))
	_line += 1
	# A greeting under way isn't started over (the hand would jump back): while the hand
	# is on the heart it stays there longer.
	var hold := Vector2(1.3, 2.4) if act == Act.TEA else Vector2(0.45, GREET_SECONDS - 0.5)
	if _greet_t >= _greet_len():
		_greet_t = 0.0
	elif _greet_t > hold.x and _greet_t < hold.y:
		_greet_t = hold.x
	_welcomed_at = _clock
	if act == Act.WALK or act == Act.SWEEP:
		_stop_t = 3.2


func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bubble_t = BUBBLE_SECONDS


func is_speaking() -> bool:
	return _bubble.visible


## A one-off walk along `points` (world; the heights follow the ground) at a natural
## pace, turning smoothly and slowing into the stop; then she stands (STAND) and
## `on_arrive` is called. From a knee she gets up first.
func walk_to(points: Array[Vector3], on_arrive: Callable = Callable()) -> void:
	_path = points.duplicate()
	_path_done = on_arrive
	_yaw = rotation.y
	_wait = 0.0
	act = Act.WALK
	if _path.is_empty():
		_arrive()


func is_walking_to() -> bool:
	return not _path.is_empty()


## On a walk_to(), stopped because the player stands in her way.
func blocked_by_player() -> bool:
	return _way_blocked and not _path.is_empty()


## Ends a walk_to() where she is, without calling back; she stands.
func stop_walk() -> void:
	_path.clear()
	_path_done = Callable()
	_speed = 0.0
	_way_blocked = false
	if act == Act.WALK:
		act = Act.STAND


## Reaches out with both hands for `item` (where it is now), takes it (it becomes a
## child of her body, in her hands) and holds it against her front until drop_held().
func receive(item: Node3D) -> void:
	if item == null:
		return
	if _held != null and is_instance_valid(_held) and _held != item:
		_held.queue_free()
	_held = item
	_held_t = 0.0
	_held_in_hand = false
	_held_box = _box_of(item)
	# The hands take it by the sides facing her left and right; it is held with the side
	# that is most up now up.
	var local := _body_xf().affine_inverse() * item.global_transform
	var axes := [local.basis.x.normalized(), local.basis.y.normalized(), local.basis.z.normalized()]
	var side_i := 0
	var up_i := 1
	for k in 3:
		if absf((axes[k] as Vector3).x) > absf((axes[side_i] as Vector3).x):
			side_i = k
	var up_best := -1.0
	for k in 3:
		if k != side_i and absf((axes[k] as Vector3).y) > up_best:
			up_best = absf((axes[k] as Vector3).y)
			up_i = k
	var unit := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	_held_side = (unit[side_i] as Vector3) * signf((axes[side_i] as Vector3).x if absf((axes[side_i] as Vector3).x) > 0.001 else 1.0)
	_held_up = (unit[up_i] as Vector3) * signf((axes[up_i] as Vector3).y if absf((axes[up_i] as Vector3).y) > 0.001 else 1.0)


## Lets go of what she holds: it is freed, the hands go back.
func drop_held() -> void:
	if _held != null and is_instance_valid(_held):
		_held.queue_free()
	_held = null
	_held_in_hand = false


## What she holds (null: nothing).
func held() -> Node3D:
	return _held if _held != null and is_instance_valid(_held) else null


## Talks for `seconds` (a line of dialogue): looking at the player, nodding, the free
## hands moving with the words.
func talk(seconds: float) -> void:
	_talk_t = maxf(_talk_t, seconds)


func is_talking() -> bool:
	return _talk_t > 0.0


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else global_position + Vector3(0, 50, 0)


# --- Frame -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	var cam := _camera_pos()
	var dist := cam.distance_to(global_position)
	if _bubble.visible:
		_bubble_t -= delta
		_bubble.modulate.a = clampf(_bubble_t / 0.6, 0.0, 1.0)
		if _bubble_t <= 0.0:
			_bubble.visible = false
	_greet_t += delta
	_update_story(delta)
	if not is_visible_in_tree():
		return
	if worker and not away and dist < WELCOME_RANGE and _clock - _welcomed_at > WELCOME_COOLDOWN and Game.player and (Game.player as Player).driving == null:
		greet(0)
	# Past ANIMATE_RANGE only someone on the move keeps moving his legs (a few times a
	# second, as far as he is drawn): a frozen stride sliding along would show.
	var moving := _speed > 0.05
	if dist > (SHOW_RANGE[Settings.quality] if moving else ANIMATE_RANGE):
		return
	_anim_acc += delta
	var every := 0.0
	if not _on_screen.is_on_screen():
		every = 0.3
	elif dist > ANIMATE_RANGE:
		every = 0.1
	elif dist > NEAR_RANGE:
		every = 1.0 / 15.0
	elif dist > 10.0:
		every = 1.0 / 30.0
	if _anim_acc < every:
		return
	var t0 := Time.get_ticks_usec()
	_animate(_anim_acc, cam)
	anim_usec += Time.get_ticks_usec() - t0
	_anim_acc = 0.0


func _physics_process(delta: float) -> void:
	_stop_t = maxf(_stop_t - delta, 0.0)
	_clap_t = maxf(_clap_t - delta, 0.0)
	_cheer_t = maxf(_cheer_t - delta, 0.0)
	if act == Act.FISH:
		_fish_tick(delta)
	if not _path.is_empty():
		_walk_path(delta)
	elif act == Act.WALK:
		_walk_route(delta)
	elif act == Act.SWEEP:
		_sweep_move(delta)


# --- Walking ---------------------------------------------------------------------------------

func _walk_route(delta: float) -> void:
	if route.size() < 2:
		return
	var here := global_position
	var target: Dictionary = route[_wp]
	var prev: Dictionary = route[posmod(_wp - _dir, route.size())]
	var to := _flat(target["p"]) - _flat(here)
	var seg := (_flat(target["p"]) - _flat(prev["p"])).normalized()
	var want := walk_speed
	var face := NAN
	if _stop_t > 0.0:
		want = 0.0
		face = _yaw_to(Game.player.global_position) if Game.player else NAN
	elif _wait > 0.0:
		_wait -= delta
		want = 0.0
		face = float(prev.get("face", NAN))
	elif _is_crossing(prev, target) and not _crossing:
		# At the kerb: over the zebra only when no vehicle stands on it or comes.
		if _road_clear(here):
			_crossing = true
		else:
			want = 0.0
			face = atan2(seg.x, seg.z)
			# A vehicle left on the crossing: after a while he walks on the way he came.
			_blocked += delta * 0.25
	var lateral_want := 0.0
	if want > 0.0:
		var probe := _flat(here) + seg * 1.2 + _left(seg) * _lateral
		var r := _obstacle(probe, here, seg)
		if r == 1:
			# Something ahead: step aside where it's free, else wait.
			var best := NAN
			for k in [0.5, -0.5, 0.85, -0.85, 0.25, -0.25]:
				var lat := clampf(_lateral + float(k), -MAX_LATERAL, MAX_LATERAL)
				if absf(lat - _lateral) < 0.2:
					continue
				if _obstacle(_flat(here) + seg * 1.2 + _left(seg) * lat, here, seg) == 0:
					best = lat
					break
			if is_nan(best):
				want = 0.0
				_blocked += delta
			else:
				lateral_want = best
		elif r == 2:
			lateral_want = -0.6
		else:
			_blocked = 0.0
			lateral_want = _lateral * 0.98 if absf(_lateral) > 0.05 else 0.0
	if _blocked > GIVE_UP:
		# Still blocked: turn back the way he came.
		_blocked = 0.0
		_dir = -_dir
		_wp = posmod(_wp + _dir, route.size())
		_crossing = false
		return
	if _is_crossing(prev, target):
		lateral_want = 0.0
	_lateral = move_toward(_lateral, lateral_want if want > 0.0 else _lateral, delta * 0.8)
	var aim := _flat(target["p"]) + _left(seg) * _lateral * clampf(to.length() / 2.0, 0.0, 1.0)
	var heading := aim - _flat(here)
	var move_yaw := atan2(heading.x, heading.z) if heading.length() > 0.05 else _yaw
	var turn := absf(wrapf(move_yaw - _yaw, -PI, PI))
	if want > 0.0 and turn > 0.9:
		want *= 0.3
	_speed = move_toward(_speed, want, delta * (1.6 if want > _speed else 3.0))
	var yaw_goal := move_yaw if _speed > 0.05 or want > 0.0 else (face if not is_nan(face) else _yaw)
	_yaw = _turn(_yaw, yaw_goal, delta * 2.6)
	rotation.y = _yaw
	if _speed > 0.001:
		var step := heading.normalized() * _speed * delta
		var p := here + Vector3(step.x, 0.0, step.z)
		_probe_t -= delta
		if _probe_t <= 0.0:
			_probe_t = 0.15
			_floor_y = _ground(p.x, p.z, _floor_y)
		p.y = lerpf(here.y, _floor_y, clampf(delta * 10.0, 0.0, 1.0))
		# Never into a vehicle parked in his way (his body would shove it): along its side.
		global_position = Vehicle.keep_out(here, p, CAR_KEEP)
	if to.length() < 0.35 and _stop_t <= 0.0:
		_wait = float(target.get("wait", 0.0))
		_crossing = false
		_wp = posmod(_wp + _dir, route.size())


## walk_to(): on along the path at walk_speed, turning smoothly (nearly on the spot for a
## sharp turn), slowing into the last point; waits while the player stands in the way
## (ahead of her, short of where she stops or not well past it: someone she walks up to
## stands further off) and while she is still getting up off her knee.
func _walk_path(delta: float) -> void:
	var here := global_position
	var target := _path[0]
	var to := _flat(target) - _flat(here)
	var last := _path.size() == 1
	if not last and to.length() < 0.45:
		_path.remove_at(0)
		return
	if last and to.length() < 0.04:
		_arrive()
		return
	var want := walk_speed
	if last:
		want = minf(walk_speed, to.length() * 1.3 + 0.12)
	if _kneel > 0.0:
		want = 0.0
	var player := Game.player as Player
	_way_blocked = false
	if player and player.driving == null:
		# Blocked where she is going (not where she faces: turning to go is never blocked).
		var dir := to.normalized()
		var rel := _flat(player.global_position) - _flat(here)
		var along := rel.dot(dir)
		if along > 0.0 and along < 1.3 and (rel - dir * along).length() < 0.6 and along - to.length() < 0.6:
			_way_blocked = true
			want = 0.0
	var move_yaw := atan2(to.x, to.z)
	if absf(wrapf(move_yaw - _yaw, -PI, PI)) > 0.9:
		want *= 0.25
	_speed = move_toward(_speed, want, delta * (1.6 if want > _speed else 3.0))
	if want > 0.0 or _speed > 0.0:
		_yaw = _turn(_yaw, move_yaw, delta * 2.6)
		rotation.y = _yaw
	if _speed > 0.001:
		var d := minf(_speed * delta, to.length())
		var p := here + to.normalized() * d
		_probe_t -= delta
		if _probe_t <= 0.0:
			_probe_t = 0.15
			_floor_y = _ground(p.x, p.z, _floor_y)
		p.y = lerpf(here.y, _floor_y, clampf(delta * 10.0, 0.0, 1.0))
		# Never into a vehicle parked in his way (his body would shove it): along its side.
		global_position = Vehicle.keep_out(here, p, CAR_KEEP)


func _arrive() -> void:
	_path.clear()
	_speed = 0.0
	_way_blocked = false
	act = Act.STAND
	var done := _path_done
	_path_done = Callable()
	if done.is_valid():
		done.call()


## A leg of the route over the street (its ends on either side): the zebra crossing.
static func _is_crossing(a: Dictionary, b: Dictionary) -> bool:
	return ((a["p"] as Vector3).z - Town.STREET_Z) * ((b["p"] as Vector3).z - Town.STREET_Z) < 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _left(dir: Vector3) -> Vector3:
	return Vector3(dir.z, 0.0, -dir.x)


func _yaw_to(p: Vector3) -> float:
	var d := p - global_position
	return atan2(d.x, d.z)


static func _turn(from: float, to: float, max_step: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -max_step, max_step)


## 0: free, 1: blocked (the player, a vehicle), 2: another walker coming (keep right).
func _obstacle(probe: Vector3, here: Vector3, seg: Vector3) -> int:
	var player := Game.player as Player
	if player and player.driving == null:
		var pp := _flat(player.global_position)
		if pp.distance_to(probe) < 1.0 or (pp.distance_to(_flat(here)) < 1.1 and (pp - _flat(here)).dot(seg) > 0.0):
			return 1
	for v: Node3D in get_tree().get_nodes_in_group(Vehicle.GROUP):
		var local := v.global_transform.affine_inverse() * Vector3(probe.x, v.global_position.y, probe.z)
		if absf(local.x) < 1.35 and absf(local.z) < 3.0:
			return 1
	for o: Townsperson in get_tree().get_nodes_in_group(GROUP):
		if o == self:
			continue
		if _flat(o.global_position).distance_to(probe) < 0.9:
			return 2 if o.act == Act.WALK else 1
	return 0


## The street is clear to cross at `at`: nothing on the crossing, nothing coming.
func _road_clear(at: Vector3) -> bool:
	for v: Node3D in get_tree().get_nodes_in_group(Vehicle.GROUP):
		var p := v.global_position
		if absf(p.z - Town.STREET_Z) > 6.0:
			continue
		var dx := p.x - at.x
		if absf(dx) < 5.0:
			return false
		var vel: Vector3 = (v as RigidBody3D).linear_velocity if v is RigidBody3D else Vector3.ZERO
		if absf(dx) < 30.0 and vel.length() > 0.8 and vel.x * dx < 0.0:
			return false
	return true


# --- Sweeping --------------------------------------------------------------------------------

## A few strokes where he stands, then a couple of steps on along the line; back at its end.
func _sweep_move(delta: float) -> void:
	var line := _flat(sweep_to) - _flat(sweep_from)
	var length := line.length()
	var dir := line / length
	if _step_left > 0.0 and _stop_t <= 0.0:
		var player := Game.player as Player
		var ahead := _flat(global_position) + dir * float(_dir) * 1.0
		if player and player.driving == null and _flat(player.global_position).distance_to(ahead) < 1.0:
			return
		var d := minf(delta * 0.55, _step_left)
		_step_left -= d
		_sweep_s = clampf(_sweep_s + d * float(_dir), 0.0, length)
		var p := _flat(sweep_from) + dir * _sweep_s
		p.y = global_position.y
		global_position = p
		_speed = 0.55
		if _sweep_s <= 0.0 or _sweep_s >= length:
			_dir = -_dir
	else:
		_speed = 0.0
	# He faces the way he sweeps along the line (turning round at its ends), or the
	# player who greeted him.
	var face := atan2(dir.x * float(_dir), dir.z * float(_dir))
	if _stop_t > 0.0 and Game.player:
		face = _yaw_to(Game.player.global_position)
	_yaw = _turn(_yaw, face, delta * 2.0)
	rotation.y = _yaw


# --- Animation -------------------------------------------------------------------------------

func _greet_len() -> float:
	return TEA_GREET if act == Act.TEA else GREET_SECONDS


func _animate(delta: float, cam: Vector3) -> void:
	rig.time += delta
	rig.begin()
	var greeting := _greet_t < _greet_len()
	# g: the nod and bow; the hand goes to the heart (or waves) and stays till near the end.
	var g := 0.0
	var hand := 0.0
	if greeting:
		if act == Act.TEA:
			g = sin(clampf((_greet_t - 0.9) / 1.8, 0.0, 1.0) * PI)
		else:
			g = sin(clampf(_greet_t / GREET_SECONDS, 0.0, 1.0) * PI)
			hand = smoothstep(0.0, 0.45, _greet_t) * (1.0 - smoothstep(GREET_SECONDS - 0.5, GREET_SECONDS, _greet_t))
	_update_broom()
	if _kneel > 0.0 or act == Act.PET:
		_legs_pet()
	else:
		_legs(delta, greeting)
	if greeting:
		rig.rot_x(&"spine_03", g * 0.1)
	_look(delta, cam, g)
	_arms(delta, greeting)
	if hand > 0.0:
		_arms_greet(hand)
	_place_props()
	if _speed > 0.05 and act == Act.WALK:
		var ph := fposmod(rig.gait_phase * 2.0, 1.0)
		if ph < _last_step_phase and cam.distance_to(global_position) < 14.0:
			Audio.play("step_concrete", global_position, -21.0, 0.12, &"Effects", 2.0)
		_last_step_phase = ph
	rig.commit()
	if _bubble.visible:
		_bubble.position = rig.eye_point() + Vector3(0, 0.42, 0)


func _legs(delta: float, greeting: bool) -> void:
	# A hand on a door's edge: the hips shift (the feet stay) and she leans a little so the
	# arm reaches it easily, away from an edge close by, towards one further off.
	var door_lean := 0.0
	if _door_w > 0.0:
		var side := "_l" if _door_last.x > 0.0 else "_r"
		var sh := rig.pos_rest("upperarm" + side)
		var drop := sh.y - _door_last.y
		var want := sqrt(maxf(0.46 * 0.46 - drop * drop, 0.0))
		var need := clampf(want - Vector2(_door_last.x - sh.x, _door_last.z - sh.z).length(), -0.1, 0.14)
		var w := smoothstep(0.0, 1.0, _door_w)
		var hip := clampf(need, 0.0, 0.07)
		rig.move_pelvis(Vector3(-signf(_door_last.x) * hip * w, 0.0, 0.0))
		door_lean = signf(_door_last.x) * (need - hip) / 0.45 * w
	match act:
		Act.BENCH:
			rig.sit(seat_height, 0.2)
		Act.TEA:
			rig.sit(seat_height, 0.1, false)
		Act.WALK:
			if _speed > 0.05:
				var n := global_basis.inverse() * _floor_n
				_slope = _slope.lerp(Vector2(-n.x, -n.z) / maxf(n.y, 0.5), clampf(delta * 5.0, 0.0, 1.0))
				rig.walk(delta, _speed, 0.92 if hands_behind else 1.0, not hands_behind and not greeting and held() == null, _slope)
			else:
				rig.stance(0.0, false)
		Act.SWEEP:
			if _speed > 0.05:
				rig.walk(delta, _speed * 0.8, 0.7, false)
				rig.rot_x(&"spine_02", 0.16)
			else:
				rig.move_pelvis(Vector3(0.0, -0.035, -0.03))
				rig.stance(0.42, false)
		Act.WRITE:
			rig.stance(0.32, false)
		Act.TILL:
			rig.stance(0.12, false)
		_:
			rig.stance(0.0, false)
	if door_lean != 0.0:
		rig.rot_z(&"spine_01", door_lean)


func _arms(delta: float, greeting: bool) -> void:
	match act:
		Act.TILL:
			_arms_till()
		Act.WRITE:
			_arms_write()
		Act.WIPE:
			_arms_wipe()
		Act.TALK:
			_arms_talk()
		Act.SWEEP:
			_arms_sweep(delta)
		Act.TEA:
			_arms_tea()
		Act.WALK:
			if hands_behind:
				_hands_behind()
			elif _speed <= 0.05 or greeting:
				rig.relaxed_arms()
		Act.STAND:
			if hands_behind:
				_hands_behind()
			else:
				rig.relaxed_arms()
		Act.PET, Act.DOORWAY:
			rig.relaxed_arms()
		Act.FISH:
			_arms_fish(delta)
		Act.CLAP:
			_arms_clap()
	if _carrying():
		_arms_carry(delta)
	if _clap_t > 0.0 and act != Act.FISH and not _carrying():
		_arms_clap()
	if _cheer_t > 0.0 and act in [Act.STAND, Act.WALK] and not _carrying():
		_arms_cheer()
	# Zeynep's: the hands to the dog, the door, the words, what she is given.
	if _kneel > 0.0:
		_arms_pet()
	if _door_w > 0.0:
		_arms_door()
	if _talk_t > 0.0:
		_arms_talking()
	if held() != null or _hold_w > 0.0:
		_arms_hold()


## The head: to the player when he is close and in front (a worker at work glances
## less), else looking about now and then; down at the work while working.
func _look(delta: float, cam: Vector3, greet_amount: float) -> void:
	# Talking: at the player; petting: at the dog.
	if _talk_t > 0.0 or (_kneel > 0.3 and act == Act.PET):
		var at := to_local(cam) if _talk_t > 0.0 else _pet_last + Vector3(0.0, 0.05, 0.0)
		_look_w = move_toward(_look_w, 1.0, delta * 1.5)
		rig.look_at_point(at, 1.0, delta)
		if greet_amount > 0.0:
			rig.rot_x(&"head", greet_amount * 0.28)
		return
	var local := to_local(cam)
	var d := local - rig.eye_point()
	var facing := absf(atan2(d.x, d.z))
	var near := d.length() < LOOK_RANGE and facing < 1.9
	var busy := _busy()
	var w := 0.0
	if near:
		w = 1.0 if (not busy or greet_amount > 0.0 or d.length() < 2.6) else 0.55
	_look_w = move_toward(_look_w, w, delta * 1.5)
	if _look_w > 0.02:
		rig.look_at_point(local, _look_w, delta)
		if greet_amount > 0.0:
			rig.rot_x(&"head", greet_amount * 0.28)
		return
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = randf_range(2.5, 6.5)
		var yaw := randf_range(-0.9, 0.9) if act != Act.WALK else randf_range(-0.4, 0.4)
		var pitch := randf_range(-0.15, 0.1)
		if busy:
			yaw *= 0.3
			pitch = 0.45
		_look_target = rig.eye_point() + Vector3(sin(yaw), -sin(pitch), cos(yaw)) * 3.0
	if busy:
		_look_target = _work_point()
	rig.look_at_point(_look_target, 0.85, delta)
	if greet_amount > 0.0:
		rig.rot_x(&"head", greet_amount * 0.28)


func _busy() -> bool:
	match act:
		Act.TILL:
			return fmod(rig.time + rig.seed_phase, 14.0) < 8.0
		Act.WRITE:
			return fmod(rig.time + rig.seed_phase, 12.0) < 7.5
		Act.WIPE:
			return _wiping()
		Act.SWEEP:
			return _speed < 0.05
		Act.FISH:
			return _catch_t < 0.0 or _catch_t > 1.0
	return false


func _work_point() -> Vector3:
	match act:
		Act.SWEEP:
			return _broom_head
		Act.TILL, Act.WRITE:
			return Vector3(-0.05, work_height, 0.42)
		Act.WIPE:
			return Vector3(-0.05, 1.2, 0.45)
		Act.FISH:
			if _catch_t > 1.4 and _catch_mi and _catch_mi.visible:
				return to_local(_catch_mi.global_position)
			return to_local(fish_spot) if fish_spot.is_finite() else rig.eye_point() + Vector3(0, -0.8, 4.0)
	return rig.eye_point() + Vector3(0, -0.5, 2.0)


func _pole(side: String) -> Vector3:
	var sgn := 1.0 if side == "_l" else -1.0
	return Vector3(sgn * 0.7, -0.3, -0.6)


func _flat_hand(side: String, at: Vector3, fingers := Vector3(0, 0, 1)) -> void:
	var sgn := 1.0 if side == "_l" else -1.0
	rig.reach(side, at, _pole(side))
	rig.orient_hand(side, fingers + Vector3(-sgn * 0.15, 0, 0), Vector3(0, -1, 0))
	rig.curl(side, 0.15, 0.2)


func _arms_till() -> void:
	var top := work_height + 0.04
	if fmod(rig.time + rig.seed_phase, 14.0) < 8.0:
		# Counting notes: the left hand holds the wad up, the right flicks them over.
		var c := fmod(rig.time * 1.6, 1.0)
		var flick := sin(c * PI)
		rig.reach("_l", Vector3(0.1, top + 0.06, 0.42), _pole("_l"))
		rig.orient_hand("_l", Vector3(-0.5, 0.2, 1.0), Vector3(-0.4, 0.4, -0.3))
		rig.curl("_l", 0.45, 0.2)
		rig.reach("_r", Vector3(-0.12 + flick * 0.07, top + 0.03 + flick * 0.05, 0.44), _pole("_r"))
		rig.orient_hand("_r", Vector3(0.5, -0.1, 1.0), Vector3(0.3, -0.6, 0.0))
		rig.curl("_r", 0.3 + flick * 0.2, 0.3)
		if c < _last_stroke and fmod(rig.time, 5.0) < 1.0:
			Audio.play("coins_small", global_position + Vector3(0, 1, 0), -22.0, 0.1, &"Effects", 2.0)
		_last_stroke = c
	else:
		_flat_hand("_l", Vector3(0.2, top, 0.38))
		_flat_hand("_r", Vector3(-0.2, top, 0.4))


func _arms_write() -> void:
	var top := work_height + 0.05
	_flat_hand("_l", Vector3(0.18, top, 0.4), Vector3(-0.4, 0, 1))
	var w := fmod(rig.time + rig.seed_phase, 12.0) < 7.5
	var s := Vector3(sin(rig.time * 9.0) * 0.012 + fmod(rig.time * 0.8, 1.0) * 0.08, 0.0, cos(rig.time * 11.0) * 0.008) if w else Vector3.ZERO
	rig.reach("_r", Vector3(-0.12, top + 0.02, 0.4) + s, _pole("_r"))
	rig.orient_hand("_r", Vector3(0.5, -0.2, 1.0), Vector3(0.1, -1, -0.2))
	rig.curl("_r", 0.55, 0.5)


func _wiping() -> bool:
	return fmod(rig.time + rig.seed_phase, 13.0) < 5.0


func _arms_wipe() -> void:
	if _wiping():
		var a := rig.time * 5.0
		rig.reach("_r", Vector3(-0.06 + cos(a) * 0.1, 1.2 + sin(a) * 0.08, 0.42), _pole("_r"))
		rig.orient_hand("_r", Vector3(0.2, 1.0, 0.1), Vector3(0, 0, 1))
		rig.curl("_r", 0.2, 0.2)
		rig.reach("_l", Vector3(0.24, 1.25, 0.38), _pole("_l"))
		rig.orient_hand("_l", Vector3(0, 1.0, 0.1), Vector3(0, 0, 1))
		rig.curl("_l", 0.1, 0.2)
	else:
		_hands_behind()


func _arms_talk() -> void:
	var t := fmod(rig.time + rig.seed_phase, 11.0)
	if t < 4.5 or is_speaking():
		# Selling: open hands up in front, moving with the words.
		var wl := rig.wobble(2.2, 3.0)
		var wr := rig.wobble(2.6, 5.0)
		rig.reach("_l", Vector3(0.2 + wl * 0.05, 1.08 + wl * 0.06, 0.34), _pole("_l"))
		rig.orient_hand("_l", Vector3(-0.2, 0.3, 1.0), Vector3(-0.5, 0.8, 0.0))
		rig.curl("_l", 0.2, 0.2)
		rig.reach("_r", Vector3(-0.22 + wr * 0.06, 1.12 + wr * 0.07, 0.36), _pole("_r"))
		rig.orient_hand("_r", Vector3(0.2, 0.3, 1.0), Vector3(0.5, 0.8, 0.0))
		rig.curl("_r", 0.2, 0.2)
	else:
		# Hands clasped in front.
		var c := Vector3(0.0, rig.pelvis_y + 0.04, 0.2)
		rig.reach("_l", c + Vector3(0.035, 0.0, 0.0), _pole("_l"))
		rig.orient_hand("_l", Vector3(-1, -0.4, 0.3), Vector3(-0.2, 0, -1))
		rig.reach("_r", c + Vector3(-0.03, 0.02, 0.02), _pole("_r"))
		rig.orient_hand("_r", Vector3(1, -0.4, 0.3), Vector3(0.2, 0, -1))
		rig.curl("_l", 0.5, 0.4)
		rig.curl("_r", 0.5, 0.4)


func _hands_behind() -> void:
	var c := Vector3(0.0, rig.pelvis_y + 0.09, -0.24)
	rig.reach("_l", c + Vector3(0.05, 0.0, 0.0), Vector3(0.8, 0.0, 0.2))
	rig.orient_hand("_l", Vector3(-1, -0.3, 0), Vector3(0, 0, -1))
	rig.reach("_r", c + Vector3(-0.04, 0.02, -0.02), Vector3(-0.8, 0.0, 0.2))
	rig.orient_hand("_r", Vector3(1, -0.3, 0), Vector3(0, 0, -1))
	rig.curl("_l", 0.55, 0.4)
	rig.curl("_r", 0.6, 0.4)


var _broom_head := Vector3(0, 0, 0.5)


## The broom: strokes from his right to his left across the ground in front, the head
## lifted on the way back; the left fist at the top leads, the right one lower down
## pushes, the handle through both. Stopped to greet, he stands it upright at his left
## side in the left hand (the right one goes to his heart).
func _arms_sweep(delta: float) -> void:
	var stroke := fmod(rig.time * 0.95 + rig.seed_phase, 1.0)
	var bx := 0.0
	var lift := 0.0
	if _speed > 0.05 or _stop_t > 0.0:
		bx = 0.0
		lift = 0.08
	elif stroke < 0.45:
		bx = lerpf(-0.42, 0.22, smoothstep(0.0, 0.45, stroke))
	else:
		bx = lerpf(0.22, -0.42, smoothstep(0.45, 1.0, stroke))
		lift = sin((stroke - 0.45) / 0.55 * PI) * 0.07
	if _speed <= 0.05 and _stop_t <= 0.0:
		if stroke < _last_stroke:
			_sweep_n += 1
			if _sweep_n >= 5:
				_sweep_n = 0
				_step_left = 0.7
			if _camera_pos().distance_to(global_position) < 18.0:
				Audio.play("brush", global_position + transform.basis.z * 0.6, -15.0, 0.15, &"Effects", 3.0, 0.75)
		_last_stroke = stroke
	# Stopped to greet, or stepping on: the broom stood (carried) upright at his left.
	_broom_hold = move_toward(_broom_hold, 1.0 if _stop_t > 0.0 or _speed > 0.05 else 0.0, delta * 2.5)
	var up := smoothstep(0.0, 1.0, _broom_hold)
	# The left fist near the top at his waist, the right one a forearm lower down the
	# handle (both within reach of the bent-over body), the bristles out in front.
	var y0 := rig.pelvis_y
	var head := Vector3(bx - 0.14, lift, 0.6).lerp(Vector3(0.36, 0.05 if _speed > 0.05 else 0.0, 0.3), up)
	var top := Vector3(-0.07 + bx * 0.25, y0 + 0.3, 0.3).lerp(Vector3(0.25, y0 + 0.08, 0.2), up)
	_broom_head = head
	_broom_lift = head.y
	rig.rot_y(&"spine_02", bx * 0.25 * (1.0 - up))
	var axis := (top - head).normalized()
	var low := top - axis * 0.23
	rig.hold("_l", top, axis, Vector3(-1, 0.1, 0.1), _pole("_l"), 0.85)
	var grip := rig.hold_pose("_r", low, axis, Vector3(-1, -0.25, 0.2))
	_broom_two_hands = up <= 0.0
	if _broom_two_hands:
		rig.hold("_r", low, axis, Vector3(-1, -0.25, 0.2), _pole("_r"), 0.85)
	else:
		# The right hand lets go and hangs at his side while the broom stands, out round his
		# hip on the way (straight from the handle to his side it would pass through it,
		# the more so as his hips sway with a step).
		var rel := rig.relaxed_pose("_r")
		var bow := Vector3(-0.08, 0.0, 0.07) * sin(up * PI)
		rig.pose_between("_r", [(grip[0] as Vector3) + bow, grip[1]], [(rel[0] as Vector3) + bow, rel[1]], up, _pole("_r"), 0.85, 0.35)


## Nuri Hoca at his tea: the glass in his right hand, raised to sip now and then; the left
## hand on its thigh. Greeted, he puts the glass down on the table, lays his hand on his
## heart, then takes the glass up again.
func _arms_tea() -> void:
	var t := fmod(rig.time + rig.seed_phase, 16.0)
	var sip := smoothstep(0.0, 0.8, t) * (1.0 - smoothstep(2.4, 3.2, t))
	var gt := _greet_t if _greet_t < TEA_GREET else -1.0
	# The left hand on its thigh.
	var knee := rig.pos(rig.bi(&"calf_l"))
	var hip := rig.pos(rig.bi(&"thigh_l"))
	rig.reach("_l", hip.lerp(knee, 0.6) + Vector3(0.02, 0.07, 0.0), Vector3(0.6, -0.2, -1.0))
	rig.orient_hand("_l", Vector3(-0.25, -0.35, 1.0), Vector3(0, -1, 0))
	rig.curl("_l", 0.3, 0.3)
	# The glass held in front of him, or at his lips, tipped towards him.
	var at := Vector3(-0.07, seat_height + 0.31, 0.3).lerp(rig.eye_point() + Vector3(-0.01, -0.17, 0.085), sip)
	if is_speaking() and sip < 0.05 and gt < 0.0:
		at += Vector3(rig.wobble(3.0, 1.0) * 0.04, rig.wobble(2.4, 2.0) * 0.05 + 0.06, 0.04)
	var glass_up := Vector3(0.0, cos(sip * 0.55), -sin(sip * 0.55))
	# Greeted: down on the table (0-0.8 s), hand on the heart (0.8-2.9 s), up again.
	var down := 0.0
	var heart := 0.0
	_glass_in_hand = true
	if gt >= 0.0:
		if gt < 0.8:
			down = smoothstep(0.0, 0.8, gt)
		elif gt < 2.9:
			down = 1.0
			_glass_in_hand = false
			heart = smoothstep(0.8, 1.3, gt) * (1.0 - smoothstep(2.4, 2.9, gt))
		else:
			down = 1.0 - smoothstep(2.9, 3.6, gt)
	if down > 0.0:
		rig.rot_x(&"spine_02", down * (1.0 - heart) * 0.22)
		at = at.lerp(_glass_spot + Vector3(0.0, 0.042, 0.0), down) + Vector3(0.0, sin(down * PI) * 0.05, 0.0)
		glass_up = glass_up.slerp(Vector3.UP, down)
	rig.hold("_r", at, glass_up, Vector3(0.3, -0.1, 1.0), _pole("_r"), 0.62)
	if heart > 0.0:
		rig.hand_on_heart("_r", heart)
	if sip > 0.5:
		rig.rot_x(&"head", -sip * 0.12)


# --- Zeynep: the dog, the door, talking, taking things ------------------------------------

## The story's timers and blends, kept up even when she is too far to be posed: the
## knee (down only once she has turned to the dog), the hand to the door, the line, the
## thing she is taking (in her hands after TAKE_TIME).
func _update_story(delta: float) -> void:
	var petting := act == Act.PET and pet_target != null and is_instance_valid(pet_target)
	if petting:
		var pw := _pet_world()
		_pet_last = to_local(pw)
		_pet_along = Vector3.ZERO
		if pet_target.has_method(&"pet_along"):
			var along: Vector3 = global_basis.inverse() * (pet_target.call(&"pet_along") as Vector3)
			along.y = 0.0
			_pet_along = along.normalized() if along.length() > 0.01 else Vector3.ZERO
		if _kneel <= 0.0:
			# Turned to have the dog beside her on the stroking hand's side, then down.
			if pet_hand != "":
				_pet_side = pet_hand
			elif absf(_pet_last.x) > 0.1:
				_pet_side = "_l" if _pet_last.x > 0.0 else "_r"
			var want := _yaw_to(pw) - (1.0 if _pet_side == "_l" else -1.0) * PET_ASIDE
			_yaw = _turn(rotation.y, want, delta * 2.2)
			rotation.y = _yaw
			petting = absf(wrapf(want - _yaw, -PI, PI)) < 0.25
	_kneel = move_toward(_kneel, 1.0 if petting else 0.0, delta / KNEEL_TIME)
	var on_door := act == Act.DOORWAY and door_hand.is_finite() and held() == null
	if on_door:
		_door_last = to_local(door_hand)
	_door_w = move_toward(_door_w, 1.0 if on_door else 0.0, delta / DOOR_HAND_TIME)
	if _talk_t > 0.0:
		_talk_el += delta
		_talk_t = maxf(_talk_t - delta, 0.0)
	else:
		_talk_el = 0.0
	if held() != null:
		_held_t += delta
		_hold_w = 1.0
		if not _held_in_hand and _held_t >= TAKE_TIME:
			# In her hands: it goes with them now.
			_held_from = _body_xf().affine_inverse() * _held.global_transform
			_held.reparent(rig, true)
			_held_in_hand = true
			_held_t = 0.0
	else:
		_hold_w = move_toward(_hold_w, 0.0, delta / 0.5)


## The legs for PET (and getting up from it): down on one knee, leaning to the dog.
func _legs_pet() -> void:
	var p := _pet_last
	var sgn := 1.0 if _pet_side == "_l" else -1.0
	# Down a little nearer a dog further ahead; bent forward as far as the hand goes ahead
	# of her, over to the side as far as it goes out to it (a dog beside her), the chest
	# turned a little to the stroking side.
	var ahead := p.z
	var out := absf(p.x)
	var forward := clampf(ahead - 0.45, -0.1, 0.3)
	rig.kneel(_kneel, _pet_side, clampf(0.2 + (ahead - forward - 0.25) * 1.2, 0.12, 0.65), sgn * 0.2, forward)
	var bend := clampf((out - 0.3) * 1.2, 0.0, 0.3) * smoothstep(0.2, 1.0, _kneel)
	rig.rot_z(&"spine_01", -sgn * bend * 0.45)
	rig.rot_z(&"spine_02", -sgn * bend * 0.35)
	rig.rot_z(&"spine_03", -sgn * bend * 0.2)


## Stroking the dog's back: the palm flat on it from where its pet_point is, along the
## back away from her and down it a little, lifted back for the next stroke; the other
## hand on the raised knee. Faded in and out with the knee.
func _arms_pet() -> void:
	var side := _pet_side
	var other := "_r" if side == "_l" else "_l"
	var sgn := 1.0 if side == "_l" else -1.0
	var a := smoothstep(0.45, 1.0, _kneel)
	var st := _stroke()
	var pose: Array = rig.palm_pose(side, st[0], st[1], st[2])
	var from := rig.relaxed_pose(side)
	rig.reach(side, (from[0] as Vector3).lerp(pose[0], a), Vector3(sgn * 0.75, -0.45, -0.4))
	rig.set_hand(side, (from[1] as Quaternion).slerp(pose[1], a))
	rig.curl(side, lerpf(0.35, 0.14, a), lerpf(0.35, 0.15, a))
	# The other hand on top of the knee that is up, the fingers over its front.
	var b := smoothstep(0.55, 1.0, _kneel)
	var knee := rig.pos(rig.bi("calf" + other))
	var kpose: Array = rig.palm_pose(other, knee + Vector3(sgn * 0.01, 0.058, 0.025), Vector3(0.0, 1.0, 0.25), Vector3(sgn * 0.25, -0.35, 1.0))
	var kfrom := rig.relaxed_pose(other)
	rig.reach(other, (kfrom[0] as Vector3).lerp(kpose[0], b), Vector3(-sgn * 0.8, -0.2, -0.5))
	rig.set_hand(other, (kfrom[1] as Quaternion).slerp(kpose[1], b))
	rig.curl(other, lerpf(0.35, 0.3, b), 0.3)


## Where the stroking palm is now (body frame): [point, the back's outward normal, the
## way the stroke goes]: from a little before pet_point along the back (toward the tail,
## or else away from her), sloping down a little, then lifted back.
func _stroke() -> Array:
	var p := _pet_last
	var d := _pet_along if _pet_along != Vector3.ZERO else Vector3(p.x, 0.0, p.z)
	d = d.normalized() if d.length() > 0.05 else Vector3.BACK
	var along := d * cos(STROKE_SLOPE) + Vector3.DOWN * sin(STROKE_SLOPE)
	var n := Vector3.UP * cos(STROKE_SLOPE) + d * sin(STROKE_SLOPE)
	var u := fposmod(rig.time / STROKE_TIME + rig.seed_phase, 1.0)
	var s := 0.0
	var lift := 0.0
	if u < 0.62:
		s = lerpf(-0.02, STROKE_LEN - 0.02, smoothstep(0.0, 0.62, u))
	else:
		var r := (u - 0.62) / 0.38
		s = lerpf(STROKE_LEN - 0.02, -0.02, smoothstep(0.0, 1.0, r))
		lift = sin(r * PI) * 0.045
	return [p + along * s + n * (0.004 + lift), n, along]


## The hand on the open door's edge: down by her hip the palm rests against it, the
## fingers down round it, the arm hanging; higher up the hand closes loosely round it,
## the thumb up, the forearm raised.
func _arms_door() -> void:
	var at := _door_last
	var side := "_l" if at.x > 0.0 else "_r"
	var sgn := 1.0 if side == "_l" else -1.0
	var sh := rig.pos(rig.bi("upperarm" + side))
	var toward := Vector3(at.x - sh.x, 0.0, at.z - sh.z)
	toward = toward.normalized() if toward.length() > 0.01 else Vector3(sgn, 0.0, 0.0)
	var high := 1.0 - smoothstep(0.2, 0.42, sh.y - at.y)
	var low_pose := rig.palm_pose(side, at, -toward, Vector3(0.0, -1.0, 0.25) + toward * 0.3)
	var high_pose := rig.hold_pose(side, at, Vector3.UP, toward)
	var pose := [(low_pose[0] as Vector3).lerp(high_pose[0], high), (low_pose[1] as Quaternion).slerp(high_pose[1], high)]
	var t := smoothstep(0.0, 1.0, _door_w)
	rig.pose_between(side, rig.relaxed_pose(side), pose, t, Vector3(sgn * 0.3, -0.5, -1.0).lerp(Vector3(sgn * 0.7, -0.6, -0.3), high),
			0.35, lerpf(0.42, 0.5, high))


## Talking: the free hands move with the words in front of her (the one that talks
## most: her right), and she nods now and then.
func _arms_talking() -> void:
	var g := minf(_talk_el / 0.4, 1.0) * minf(_talk_t / 0.4, 1.0)
	g = smoothstep(0.0, 1.0, g)
	rig.rot_x(&"head", g * (0.07 * pow(maxf(sin(rig.time * 3.1 + rig.seed_phase), 0.0), 3.0) + 0.02 * rig.wobble(1.3, 4.0)))
	rig.rot_z(&"head", g * 0.05 * rig.wobble(0.6, 5.0))
	if _kneel > 0.05 or held() != null or _hold_w > 0.0:
		return
	var door_side := ("_l" if _door_last.x > 0.0 else "_r") if _door_w > 0.0 else ""
	for side: String in ["_r", "_l"]:
		if side == door_side:
			continue
		var sgn := 1.0 if side == "_l" else -1.0
		var w := rig.wobble(2.3, 3.0 if side == "_r" else 7.0)
		var amount := 0.8 + 0.2 * w if side == "_r" or door_side == "_r" else maxf(rig.wobble(0.45, 9.0), 0.0) * 0.8
		var t := g * amount
		if t <= 0.01:
			continue
		var to_p := Vector3(sgn * (0.19 + w * 0.03), rig.pelvis_y + 0.17 + w * 0.05, 0.3 + w * 0.03)
		var to_q := rig.hand_rot(side, Vector3(-sgn * 0.15, 0.12, 1.0), Vector3(-sgn * 0.35, 0.95, 0.0))
		var from: Array = rig.hand_pose(side)
		rig.reach(side, (from[0] as Vector3).lerp(to_p, t), Vector3(sgn * 0.6, -0.5, -0.6))
		rig.set_hand(side, (from[1] as Quaternion).slerp(to_q, t))
		rig.curl(side, lerpf(0.35, 0.22, t), 0.3)


## Taking a thing and holding it: both hands out to its sides where it is, then (in her
## hands) brought in against her front, upright, its sides in her palms. Let go, the
## hands go back from where they held it.
func _arms_hold() -> void:
	var item := held()
	var xf := Transform3D.IDENTITY
	var reach_t := 1.0
	if item != null:
		if _held_in_hand:
			xf = _held_from.interpolate_with(_held_pose(), smoothstep(0.0, 1.0, minf(_held_t / BRING_TIME, 1.0)))
		else:
			xf = _body_xf().affine_inverse() * item.global_transform
			reach_t = smoothstep(0.0, 1.0, minf(_held_t / TAKE_TIME, 1.0))
	var ext := _held_box.size * 0.5
	var c := _held_box.get_center()
	var side_ext := absf(_held_side.dot(ext))
	var up_ext := absf(_held_up.dot(ext))
	var fwd := _held_side.cross(_held_up)
	var poses := {}
	for side: String in ["_l", "_r"]:
		var sgn := 1.0 if side == "_l" else -1.0
		if item != null:
			var n := (xf.basis * _held_side).normalized() * sgn
			var at := xf * (c + _held_side * sgn * side_ext - _held_up * up_ext * 0.2) + n * 0.006
			var fingers := (xf.basis * fwd).normalized() + Vector3.DOWN * 0.45
			poses[side] = rig.palm_pose(side, at, n, fingers)
		elif _hold_last.size() == 2:
			poses[side] = _hold_last[0 if side == "_l" else 1]
		else:
			return
	var w := reach_t if item != null else smoothstep(0.0, 1.0, _hold_w)
	for side: String in ["_l", "_r"]:
		var sgn := 1.0 if side == "_l" else -1.0
		var from: Array = rig.hand_pose(side)
		var to: Array = poses[side]
		rig.reach(side, (from[0] as Vector3).lerp(to[0], w), Vector3(sgn * 0.8, -0.6, -0.25))
		rig.set_hand(side, (from[1] as Quaternion).slerp(to[1], w))
		rig.curl(side, lerpf(0.35, 0.3, w), lerpf(0.35, 0.25, w))
	_hold_last = [poses["_l"], poses["_r"]]
	if item != null and _held_in_hand:
		# It goes where the hands are (a hand that fell a little short takes it along; never
		# into her).
		var want := ((xf * (c + _held_side * side_ext)) + (xf * (c - _held_side * side_ext))) * 0.5
		var got := (rig.palm_point("_l") + rig.palm_point("_r")) * 0.5
		var shift := got - want
		shift.z = maxf(shift.z, 0.0)
		xf.origin += shift
		item.transform = xf


## Where a thing she was given is held (body frame): upright as it came, its sides to
## her hands, its back against her front between the waist and the chest.
func _held_pose() -> Transform3D:
	var m := Basis(_held_side, _held_up, _held_side.cross(_held_up))
	var b := m.transposed()
	var half := (b * (_held_box.size * 0.5)).abs()
	var y := lerpf(rig.pos_rest("spine_01").y, rig.pos_rest("spine_03").y, 0.7)
	var front: Vector3 = rig.torso_surface(y, 0.0)[0]
	var centre := Vector3(front.x, front.y, front.z + half.z + 0.015)
	return Transform3D(b, centre - b * _held_box.get_center())


## The dog's stroked place (world): its pet_point() if it has one.
func _pet_world() -> Vector3:
	if pet_target.has_method(&"pet_point"):
		return pet_target.call(&"pet_point")
	return pet_target.global_position


func _body_xf() -> Transform3D:
	return rig.global_transform


## The box round what `item` draws (its own frame).
static func _box_of(item: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := item.global_transform.affine_inverse()
	var meshes: Array[Node] = item.find_children("*", "VisualInstance3D", true, false)
	if item is VisualInstance3D:
		meshes.push_front(item)
	for n: Node in meshes:
		var vi := n as VisualInstance3D
		var b := (inv * vi.global_transform) * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
	return box


## Right hand on the heart and a nod ("hoş geldin"); the young man waves instead.
## `amount`: 0 at the work .. 1 on the heart.
func _arms_greet(amount: float) -> void:
	if waves:
		rig.wave("_r", amount, _greet_t * 11.0)
	elif act != Act.TEA:
		rig.hand_on_heart("_r", amount)
	if act == Act.SWEEP and amount > 0.02:
		_broom_two_hands = false


## Held things go where the hands holding them are now (the pose just made); the broom
## on the ground where he laid it, the tea glass away from his tea.
func _place_props() -> void:
	if _prop == null:
		return
	if _prop_kind == "glass":
		_prop.visible = _props_on and act == Act.TEA
	elif _prop_kind == "broom":
		_prop.visible = _props_on
	if not _prop.visible:
		return
	match act:
		Act.SWEEP:
			# The handle through the left fist (and the right one while it holds on), the
			# bristles on the ground (or lifted off it).
			var gl := rig.grip_point("_l")
			var axis := (gl - rig.grip_point("_r")).normalized() if _broom_two_hands else (gl - _broom_head).normalized()
			# (a fist that fell short of its place on the handle: the handle through the
			# top one to where the bristles should be)
			if axis.y < 0.3 or (gl.y - _broom_lift) / axis.y > 1.44:
				axis = (gl - _broom_head).normalized()
			var head := gl - axis * ((gl.y - _broom_lift) / axis.y)
			var z := (Vector3.RIGHT - axis * axis.x).normalized()
			_prop.transform = Transform3D(Basis(axis.cross(z), axis, z), head)
		Act.TEA:
			if _glass_in_hand:
				# Upright along the fist's thumb side, held a little below its middle.
				var ax := rig.hand_axes("_r")
				var up := ax.z.normalized()
				var x := (ax.x - up * ax.x.dot(up)).normalized()
				_prop.transform = Transform3D(Basis(x, up, x.cross(up)), rig.grip_point("_r") - up * 0.042)
			else:
				_prop.transform = Transform3D(Basis(), _glass_spot)
		_:
			if _prop_kind != "broom":
				return
			if _broom_down != null:
				_prop.transform = rig.global_transform.affine_inverse() * (_broom_down as Transform3D)
				return
			# Carried: the handle through the left fist; stood beside him the bristles are on
			# the ground, carried along they are off it behind him.
			var gl := rig.grip_point("_l")
			var axis := _carry_axis
			var w := smoothstep(0.0, 1.0, _carry_w)
			var along := lerpf(minf(gl.y / maxf(axis.y, 0.3), 1.44), CARRY_GRIP, w)
			var z := (Vector3.RIGHT - axis * axis.x).normalized()
			_prop.transform = Transform3D(Basis(axis.cross(z), axis, z), gl - axis * along)


## The broom: in his hands sweeping and walking (picked up again as he walks on), laid
## down where he stands when his hands are wanted for something else (a rod, clapping,
## cheering, sitting).
func _update_broom() -> void:
	if _prop_kind != "broom":
		return
	if act == Act.SWEEP or (act == Act.WALK and (is_walking_to() or _speed > 0.05)):
		_broom_down = null
	elif _broom_down == null and (not (act in [Act.WALK, Act.STAND]) or _clap_t > 0.0 or _cheer_t > 0.0):
		_broom_down = _broom_on_ground()


## Carrying his broom (walking or standing, not laid down).
func _carrying() -> bool:
	return _prop_kind == "broom" and _props_on and _broom_down == null and act in [Act.WALK, Act.STAND]


## Where the broom lies when he puts it down (world): on the grass just behind him, along
## his shoulders (level with where he stands), the bristles flat.
func _broom_on_ground() -> Transform3D:
	var a := to_global(Vector3(-0.35, 0.0, -0.6))
	var b := to_global(Vector3(1.15, 0.0, -0.6))
	a.y = _ground(a.x, a.z, global_position.y) + 0.015
	b.y = _ground(b.x, b.z, global_position.y) + 0.015
	var axis := (b - a).normalized()
	var up := (Vector3.UP - axis * axis.y).normalized()
	return Transform3D(Basis(axis.cross(up), axis, up), a)


## The broom carried (left hand): standing, stood upright beside him, the bristles on the
## ground (as when he stops sweeping to greet); walking, carried at his side in the
## hanging fist, the handle sloping forward and up, the bristles off the ground behind
## him, the arm swinging a little with his stride.
func _arms_carry(delta: float) -> void:
	_carry_w = move_toward(_carry_w, 1.0 if _speed > 0.05 else 0.0, delta * 2.5)
	var w := smoothstep(0.0, 1.0, _carry_w)
	var y0 := rig.pelvis_y
	var top := Vector3(0.25, y0 + 0.08, 0.2)
	var axis_s := (top - Vector3(0.36, 0.0, 0.3)).normalized()
	var swing := -cos(TAU * rig.gait_phase) * 0.2 * w
	var rel: Array = rig.relaxed_pose("_l", swing)
	var fist := (rel[0] as Vector3) + Vector3(-0.01, -0.07, 0.03)
	var axis_w := Vector3(0.0, 0.55, 0.835).normalized().rotated(Vector3.RIGHT, -swing * 0.4)
	var a: Array = rig.hold_pose("_l", top, axis_s, Vector3(-1, 0.1, 0.1))
	var b: Array = rig.hold_pose("_l", fist, axis_w, Vector3(-1, -0.3, 0.0))
	rig.pose_between("_l", a, b, w, _pole("_l"), 0.85, 0.85)
	_carry_axis = axis_s.slerp(axis_w, w).normalized()


# --- Props -----------------------------------------------------------------------------------

static func _broom() -> Node3D:
	var mb := MeshBuilder.new()
	mb.cylinder(&"wood", Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.013, 0.012, 1.2, 8, Color(0.55, 0.42, 0.28))
	mb.box_at(&"metal", Vector3(0, 0.29, 0), Vector3(0.05, 0.05, 0.05), Color(0.6, 0.15, 0.1))
	for k in 9:
		var a := (float(k) / 8.0 - 0.5) * 0.7
		mb.box(&"straw", Transform3D(Basis(Vector3.BACK, a), Vector3(sin(a) * 0.14, 0.15, 0.0)), Vector3(0.05, 0.3, 0.025), Color(0.72, 0.6, 0.36).darkened(randf() * 0.15))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.name = "Broom"
	var n := Node3D.new()
	n.add_child(mi)
	return n


static func _tea_glass() -> Node3D:
	var mb := MeshBuilder.new()
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), Vector3(0, 0.005, 0)), 0.018, 0.014, 0.045, 10, Color(0.42, 0.07, 0.03))
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.014, 0.019, 0.035, 10, Color(0.45, 0.08, 0.03))
	mb.cylinder(&"glass", Transform3D(Basis(), Vector3.ZERO), 0.022, 0.017, 0.05, 12, Color(1, 1, 1, 0.3))
	mb.cylinder(&"glass", Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.017, 0.024, 0.045, 12, Color(1, 1, 1, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.name = "TeaGlass"
	var n := Node3D.new()
	n.add_child(mi)
	return n


# --- The fishing contest: a rod at the water, applause ---------------------------------------

## Stands here (world; the height follows the ground) facing `yaw`, at once.
func place_at(at: Vector3, yaw: float) -> void:
	stop_walk()
	global_position = at
	rotation.y = yaw
	_yaw = yaw
	if is_inside_tree():
		_floor_y = _ground(at.x, at.z, at.y)
		global_position.y = _floor_y
	reset_physics_interpolation()


## Fishes with rod `rod` (a FishModels rod id), the float out at `spot` (world, on the
## water); his own things are put down meanwhile (the broom on the grass beside him).
func start_fishing(spot: Vector3, rod := &"cane_rod") -> void:
	fish_spot = Vector3(spot.x, WorldLayout.WATER_LEVEL, spot.z)
	rod_model = rod
	act = Act.FISH
	_catch_t = -1.0
	_rod_lift = 0.0
	if _rod == null:
		_rod = Node3D.new()
		_rod.name = "Rod"
		var mi := MeshInstance3D.new()
		mi.mesh = FishModels.real_mesh(rod)
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.visibility_range_end = 60.0
		_rod.add_child(mi)
		rig.add_child(_rod)
		_bob = MeshInstance3D.new()
		_bob.mesh = FishModels.real_mesh(&"fishing_float")
		_bob.top_level = true
		_bob.visibility_range_end = 45.0
		_bob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_bob)
		_fline = FishingLine.new()
		add_child(_fline)
		_catch_mi = MeshInstance3D.new()
		_catch_mi.top_level = true
		_catch_mi.visible = false
		_catch_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_catch_mi)
	_bob.global_position = fish_spot
	_bob.visible = true


## Puts the rod away (and anything he was showing); he stands.
func stop_fishing() -> void:
	for n: Node in [_rod, _bob, _fline, _catch_mi]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_rod = null
	_bob = null
	_fline = null
	_catch_mi = null
	_catch_t = -1.0
	fish_spot = Vector3.INF
	if act == Act.FISH:
		act = Act.STAND
	show_own_props(true)


## His broom or tea glass may show (false: put away altogether); where it is and whether
## it shows now follows what he does (_place_props).
func show_own_props(on: bool) -> void:
	_props_on = on
	if _prop and not on:
		_prop.visible = false


## FISH: a fish (FishTable.catch_of) bites and comes out: the rod swept up, the fish
## swinging in on the line, held up in his left hand for a moment, then into his keepnet.
func show_catch(catch: Dictionary) -> void:
	if act != Act.FISH or _catch_mi == null:
		return
	var species := StringName(catch.get("species", catch.get("id", &"fish_crucian")))
	var mesh := FishModels.real_mesh(species)
	_catch_mi.mesh = mesh
	var sc := float(catch.get("scale", 1.0))
	if FishTable.is_trophy(StringName(catch.get("id", &""))):
		sc *= FishTable.TROPHY_SIZE
	_catch_mi.scale = Vector3.ONE * sc
	_catch_len = mesh.get_aabb().size.x * sc
	_catch_t = 0.0
	var near := _camera_pos().distance_to(global_position) < 30.0
	if near:
		FishingAudio.play("splash", fish_spot, -6.0)
		PondFx.ring(fish_spot, 1.2, 2.0, 1.4)
		PondFx.drops(fish_spot, 18, 1.8, 0.1, 0.006)
	say(FloppingFish.weight_text(float(catch.get("kg", 0.5))) + "!")


func is_showing_catch() -> bool:
	return _catch_t >= 0.0


## Claps for `seconds` (whatever he is doing; a fisherman keeps his rod).
func clap(seconds: float) -> void:
	_clap_t = maxf(_clap_t, seconds)


func is_clapping() -> bool:
	return _clap_t > 0.0 or act == Act.CLAP


## Cheers for `seconds` (a new biggest fish at the contest): both arms thrown up, fists
## shaking (standing; anyone sitting or busy claps instead: the caller's choice).
func cheer(seconds: float) -> void:
	_cheer_t = maxf(_cheer_t, seconds)


func is_cheering() -> bool:
	return _cheer_t > 0.0


## FISH, every physics frame: the float bobbing (a nibble now and then), the catch's
## timeline, the line from the tip.
func _fish_tick(delta: float) -> void:
	if _bob == null:
		return
	_nibble_t -= delta
	if _nibble_t < -randf_range(6.0, 20.0):
		_nibble_t = 0.5
	var dip := maxf(_nibble_t, 0.0) * 0.06 * sin(_nibble_t * 30.0)
	var bob := fish_spot + Vector3(0.0, sin(_clock * 1.7 + rig.seed_phase) * 0.004 - absf(dip), 0.0)
	if _catch_t >= 0.0:
		_catch_t += delta
		if _catch_t >= CATCH_SHOW:
			_catch_t = -1.0
			_catch_mi.visible = false
	var lift := 0.0
	if _catch_t >= 0.0:
		lift = smoothstep(0.0, 0.5, _catch_t) * (1.0 - smoothstep(CATCH_SHOW - 0.9, CATCH_SHOW, _catch_t))
	_rod_lift = lift
	var tip := rig.to_global(_rod_tip) if _rod and _rod_tip != Vector3.ZERO else global_position + Vector3(0, 2, 0)
	var on_line := Vector3.INF
	if _catch_t >= 0.0 and _catch_t < 1.5:
		# Out of the water and swinging in on the line under the raised tip.
		var u := smoothstep(0.15, 1.5, _catch_t)
		var hang := tip + Vector3(0.0, -0.55 - _catch_len * 0.5, 0.0)
		on_line = fish_spot.lerp(hang, u) + Vector3(0.0, sin(u * PI) * 0.8, 0.0)
		_catch_mi.visible = true
		_catch_mi.global_transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5 + sin(_clock * 18.0) * 0.4)
				.rotated(Vector3.UP, rotation.y + PI * 0.5).scaled(_catch_mi.scale), on_line)
		bob = on_line + Vector3(0.0, _catch_len * 0.5, 0.0)
	elif _catch_t >= 1.5:
		# Held up in his left hand, side on to whoever watches, wriggling now and then.
		var hand := rig.to_global(rig.grip_point("_l"))
		var wig := sin(_clock * 11.0) * 0.12 * maxf(0.0, sin(_clock * 0.9))
		var b := Basis(Vector3.UP, rotation.y + PI * 0.5 + wig).scaled(_catch_mi.scale)
		_catch_mi.global_transform = Transform3D(b, hand + Vector3(0.0, -0.02, 0.0))
		_catch_mi.visible = _catch_t < CATCH_SHOW - 0.6
		bob = tip + Vector3(0.0, -0.5, 0.0)
	_bob.global_position = bob
	_bob.visible = true
	if _fline and _camera_pos().distance_to(global_position) < 35.0:
		_fline.visible = true
		var slack := 0.25 if _catch_t < 0.0 else 0.02
		_fline.draw_line(tip, bob + Vector3(0.0, 0.06, 0.0), slack * tip.distance_to(bob) * 0.2,
				WorldLayout.WATER_LEVEL if _catch_t < 0.0 else NAN)
	elif _fline:
		_fline.visible = false


## FISH: the rod in both hands out over the water (raised for a catch, the left hand then
## off it holding the fish up).
func _arms_fish(_delta: float) -> void:
	if _rod == null:
		rig.relaxed_arms()
		return
	var y0 := rig.pelvis_y
	var axis := Vector3(0.05, 0.42, 1.0).normalized().slerp(Vector3(0.0, 1.6, 0.45).normalized(), _rod_lift)
	# The rod sways a little with the breeze and his patience.
	axis = axis.rotated(Vector3.UP, rig.wobble(0.25, 2.0) * 0.06).normalized()
	var grip_r := Vector3(-0.12, y0 + 0.16 + _rod_lift * 0.12, 0.3)
	rig.hold("_r", grip_r, axis, Vector3(0.2, -1.0, 0.2), _pole("_r"), 0.85)
	if _catch_t > 1.2:
		# The fish held up before him in the left hand, the right keeping the rod up.
		var show := Vector3(0.2, y0 + 0.5, 0.42)
		rig.hold("_l", show, Vector3(0.0, 1.0, 0.0), Vector3(-0.3, 0.0, 1.0), _pole("_l"), 0.7)
	else:
		rig.hold("_l", grip_r + axis * 0.42, axis, Vector3(-0.2, -1.0, 0.2), _pole("_l"), 0.8)
	var grip := rig.grip_point("_r")
	var x := axis.cross(Vector3.UP).normalized()
	_rod.transform = Transform3D(Basis(x, axis, x.cross(axis)), grip - axis * 0.05)
	_rod_tip = grip - axis * 0.05 + axis * FishModels.rod_tip(rod_model).y


## Applause: the hands meeting before the chest, three claps or so a second.
func _arms_clap() -> void:
	var y := rig.pos_rest("spine_03").y + 0.08
	var c := Vector3(0.0, y, 0.3)
	var gap := 0.015 + 0.075 * absf(sin((rig.time + rig.seed_phase) * PI * 3.1))
	rig.reach("_l", c + Vector3(gap, 0.0, 0.0), _pole("_l"))
	rig.orient_hand("_l", Vector3(-0.2, 0.7, 1.0), Vector3(-1.0, 0.0, 0.1))
	rig.curl("_l", 0.15, 0.2)
	rig.reach("_r", c + Vector3(-gap, 0.01, 0.0), _pole("_r"))
	rig.orient_hand("_r", Vector3(0.2, 0.7, 1.0), Vector3(1.0, 0.0, 0.1))
	rig.curl("_r", 0.15, 0.2)


## Cheering: both fists up over his head, shaking with joy.
func _arms_cheer() -> void:
	var t := (rig.time + rig.seed_phase) * 9.0
	var head := rig.eye_point()
	for side: String in ["_l", "_r"]:
		var sgn := 1.0 if side == "_l" else -1.0
		var shake := sin(t + sgn * 1.3) * 0.035
		var at := Vector3(sgn * 0.3, head.y + 0.28 + shake, head.z + 0.1)
		rig.reach(side, at, Vector3(sgn * 1.0, -0.4, -0.2))
		rig.orient_hand(side, Vector3(sgn * 0.15, 1.0, 0.1), Vector3(0.0, 0.0, 1.0))
		rig.curl(side, 0.75, 0.55)
