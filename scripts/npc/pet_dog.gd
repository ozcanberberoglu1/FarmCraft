class_name PetDog
extends Dog
## The farmer's own dog in the world (what it knows, its age and name: Pet). Karamel's
## body (Dog, DogRig) at the size Pet.size() gives (a pup's: smaller, its head and paws
## drawn bigger; grown, Karamel's), the gait worked out at the model's size so its paws
## never slide, and a day of its own (`task`):
##   &"follow"  near the farmer on the farm, loosely: it trots up (runs, far behind) when
##              he walks off and stops FOLLOW_NEAR short, then potters about near him
##              (Dog's roaming: sniffing, standing looking at him, sitting, lying down);
##              outside the farmhouse door while he is in the house. Left far behind out
##              of sight it catches up (CATCH_UP).
##   &"home"    by its doghouse (Pet.kennel; until one is built, its bed at the farmhouse)
##              while he is away (driving, off the farm); when he comes back on foot it
##              runs to greet him, barking.
##   &"bed"     asleep in its doghouse (on its bed) at night (NIGHT_FROM .. NIGHT_TO); grown
##              (Pet.guards) it keeps watch by the animals instead:
##   &"guard"   lying near the animals with its head up; wolves within WOLF_BARK: up,
##              facing the nearest, barking; one closer than WOLF_BACK_OFF it backs away
##              from (the wolves never go for it).
##   &"come"    whistled for (Pet.whistle): running to him, then greeting him (Dog's
##              &"greet"); a pup not listening only looks up.
##   &"sit"     told to sit (F), once it has learnt to: it stays (`stay`) where it is, sitting,
##              watching him go; he further than STAY_PERK for STAY_LIE seconds it lies down,
##              its eyes still on him (its head on its paws after STAY_DOZE seconds with
##              him further than STAY_NEAR), and sits up again as he comes back. It stays
##              until he releases it: a whistle (H: a dog that waits hears it anywhere on
##              the farm and never misses it), F again ("Up!"), a pat (E), picking it up
##              (G); a thrown ball is an invitation too. On the farm with him it waits as
##              long as the day lasts (a game day is short), and it is never stuck there:
##              at night it goes to its bed or its watch (he goes to bed: it is home,
##              send_home); a wolf within WOLF_BARK and it is up, grown barking at it as on
##              its watch, a pup running to him; he off the farm for STAY_MINUTES of game
##              time it gets up and goes home (Pet says so; back before that he finds it
##              still sitting there). Hungry it waits all the same and eats once it is let
##              go. Off the farm with him a stay he walks LEFT_FAR away from becomes the
##              usual &"wait". Saved with the game (Pet). Sat down without having learnt
##              it (sit_down by hand), only SIT_HOLD seconds.
##   &"petted"  a pat (E): it sits and leans into the hand (Dog's &"petted").
##   &"fetch"   after a thrown ball (a Pickup) at a run (FETCH_RUN: clearly faster than
##              the ball rolls, cutting it off), snatching it up from GRAB_EXTRA beyond
##              its nose, rolling or still; then, once it has learnt to,
##              &"carry": back to him with it at the same run, and
##              &"offer": standing before him with the ball in its mouth, looking up,
##              wagging. The ball is the farmer's to take on purpose, never by walking
##              up: E pets the dog (praise: it lets the ball drop at its feet, where E on
##              the ball takes it), F takes the ball out of its mouth; left alone
##              OFFER_HOLD seconds it lets it drop at his feet. Not yet taught:
##              &"play": trotting about with it, dropping it, pouncing on it again, and
##              in the end leaving it lying.
##   &"eat"     hungry (Pet.hungry) with food in its bowl, by day on the farm: to its bowl
##              (Pet.bowl_stand), its head down in it, chewing and crunching for MEAL_TIME,
##              then fed (Pet.meal_eaten), a happy bark and back to him. Hungry with the
##              bowl empty it stays with him, a little less lively (it trots where it would
##              run, after a ball too: HUNGRY_PACE), and now and then (BEG_EVERY) comes up
##              to him, looks up, whines and looks round at its bowl (beg).
##   &"held"    picked up (G, AnimalHandler): in the farmer's arms in front of the view,
##              sitting on his forearm, out of the world's goings-on (no body to bump
##              into), looking about and up at him, wagging, now and then a happy whine.
##   &"ride"    on the passenger seat of the vehicle he got into carrying it: sitting
##              there, looking about and out, panting; out beside him with a bark when he
##              gets out (leave_vehicle).
##   &"wait"    left off the farm (he drove off without it, or walked LEFT_FAR away): it
##              stays where it was left, pottering about, greets him when he comes back,
##              and after Pet.WAIT_MINUTES goes home on its own (it is by its doghouse the
##              next time he looks: never lost in town).
## Off the farm with him (`out_with_him`: brought in the pickup or carried out, set down
## there) it follows him as on the farm, by night too, until they are back on the farm. On
## foot it never leaves the farm after him: he walks off, it turns home.
## Obstacles (walls, fences, the house) are felt for ahead (_steer) and never walked
## through. After a ball, back with it and whistled for it knows the gates of the garden
## lots and the animals' pens (_by_gate): a ball thrown from the yard lands behind a
## fence as often as not, and feeling its way along it the dog never found the gate. Cheap: a ground ray a tick, a ray ahead while it moves, a few probes five
## times a second while it heads somewhere, its choices four times a second.

const PET_GROUP := &"pet_dog"
## Night: on its bed (or on guard) from NIGHT_FROM to NIGHT_TO (hours).
const NIGHT_FROM := 21.5
const NIGHT_TO := 6.0
## Running at the model's size (m/s; a pup runs as much slower as it is smaller).
const RUN := 3.3
## Following: it goes when he is further than FOLLOW_FAR, stops FOLLOW_NEAR off; left
## further than CATCH_UP behind, out of sight, it catches up.
const FOLLOW_NEAR := 2.2
const FOLLOW_FAR := 5.5
## How much wider than its body it goes round a vehicle's corner (m).
const CAR_BERTH := 0.7
const CATCH_UP := 28.0
## Whistled: it stops this far from him, and greets him this long. Coming to him (or back
## with the ball) and no nearer for COME_STALL seconds, something between them it finds no
## way round (the house, with the sign and the board at its corner): where he cannot see
## it, it is round it all the same (_catch_up).
const COME_GAP := 1.1
const GREET_HOLD := 3.0
const COME_STALL := 5.0
## After the ball and back with it: its run at the model's size (m/s) and how much
## quicker than otherwise it gets going; it snatches the ball up from this far beyond its
## nose's reach (m), no higher over its feet than GRAB_HIGH (m, at its size, and a
## little), in GRAB_TIME seconds (the ball swings up into its mouth over SNATCH_TIME); a
## ball it cannot get at it gives up after FETCH_GIVE_UP seconds.
const FETCH_RUN := 4.5
const FETCH_ACCEL := 2.6
const GRAB_EXTRA := 0.5
const GRAB_HIGH := 0.55
const GRAB_TIME := 0.12
const SNATCH_TIME := 0.14
const FETCH_GIVE_UP := 25.0
## Back with the ball it stops this far from him (m) and stands before him with it in its
## mouth this long (s), then lets it drop at his feet; he walks further than OFFER_LEFT
## from it: after him with it.
const OFFER_GAP := 1.3
const OFFER_HOLD := 6.0
const OFFER_LEFT := 3.0
## A meal at its bowl takes this long (s); it gets there within EAT_REACH seconds or tries
## again EAT_RETRY later (out of sight it is simply there; the third time it has eaten
## all the same). Hungry, its pace against its usual after a ball and following.
const MEAL_TIME := 7.0
const EAT_REACH := 25.0
const EAT_RETRY := 15.0
const HUNGRY_PACE := 0.6
## Hungry with an empty bowl: seconds between its comings to him to say so, how long one
## lasts once it stands before him (looking up at him, then round at its bowl), how near
## he has to be for it to come (m).
const BEG_EVERY := Vector2(35.0, 70.0)
const BEG_TIME := 5.0
const BEG_RANGE := 25.0
## Seconds it stays sat when it has not learnt to stay, and leaning into a pat.
const SIT_HOLD := 25.0
const PET_HOLD := 2.5
## Told to sit, learnt (`stay`): he within STAY_PERK m it sits up, looking at him; he
## further for STAY_LIE seconds it lies down, and for STAY_DOZE seconds, he further than
## STAY_NEAR m, its head is on its paws. He off the farm for STAY_MINUTES of game time (a
## minute and a half of play at the usual day's length): it gets up and goes home. He has
## walked STAY_TOLD_AT m from it: the one-time note on how it is called (Pet.stay_note).
const STAY_PERK := 9.0
const STAY_LIE := 40.0
const STAY_NEAR := 20.0
const STAY_DOZE := 90.0
const STAY_MINUTES := 180.0
const STAY_TOLD_AT := 7.0
## Guarding: wolves this near are barked at, this near backed away from (m); how far from
## the animals toward the house it keeps watch.
const WOLF_BARK := 30.0
const WOLF_BACK_OFF := 3.5
const GUARD_OFF := 7.0
## Seconds between looks ahead for obstacles while heading somewhere.
const PROBE := 0.2
## Through a gate: it heads for this far before it on its own side (m), and goes straight
## through once it is within the opening less GATE_EDGE (m, and its own half width).
const GATE_OFF := 1.3
const GATE_EDGE := 0.3
## Round a fenced lot in its way: by its corners, this far out (m: the lanes between the
## garden lots are two metres wide).
const ROUND_OFF := 1.0
## Off the farm with him: he has left it once he is this far off (m), and is back this near.
const LEFT_FAR := 45.0
const BACK_NEAR := 35.0
## Half the side of the patch it keeps to while it waits where it was left (m).
const WAIT_PATCH := 2.2
## In his arms: seconds between its looks up at him (and how long one lasts), between its
## happy whines and its wriggles.
const HELD_LOOK_EVERY := Vector2(3.0, 7.0)
const HELD_LOOK_TIME := Vector2(1.6, 3.2)
const HELD_WHINE_EVERY := Vector2(6.0, 14.0)
## On the seat: seconds between its looks out of the side window and at the driver.
const RIDE_LOOK_EVERY := Vector2(2.5, 6.0)
## On the seat: how far its rump keeps from the seat's back and its soles are set over the
## cushion (m); how far, at its size, its toes may reach past the cushion's inner end
## sitting across it, and keep before the cushion's front edge facing the road (the edge
## is rounded: toes on it stand in the air); how far its hocks keep inside the cushion's
## side by the door sitting across it (m: rounded too, and the door may be a hand's width
## further out: its hind paws are not left in the air beside the seat);
## and how far at most, at its size, its forepaws are drawn back to stay on a cushion
## shorter than it sits (DogRig.sit_tuck), and how far while it still sits facing the
## road rather than across the seat; how far, at its size, its nose keeps from the
## dashboard facing the road (its head still: it nods and pants). Every SEAT_SKIN-th
## vertex of its body is measured to seat it.
const SEAT_GAP := 0.012
const SEAT_OVER := 0.003
const SEAT_TOES := 0.02
const SEAT_EDGE := 0.02
const SEAT_SIDE := 0.03
const SEAT_TUCK := 0.15
const SEAT_TUCK_EASY := 0.05
const SEAT_NOSE := 0.05
const SEAT_SKIN := 3

var task: StringName = &"follow"
## Its size against Karamel's (Pet.size()).
var size := 1.0
## The ball it is after (a Pickup lying or rolling), and whether one is in its mouth.
var ball: Pickup
var holding_ball := false
## Told to sit, it stays until he releases it (&"sit", learnt).
var stay := false
## Counters for tests: balls brought back, balls played with, whistles answered.
var fetched := 0
var played := 0
var came := 0
## The vehicle it rides in (&"ride").
var vehicle: Vehicle
## Where it sits in that vehicle (the vehicle's body frame), and whether across the seat,
## facing the driver (grown too long to sit facing the road on it): see _fit_seat.
var _seat := Transform3D.IDENTITY
var seat_across := false
## Set down off the farm (out of the pickup, out of his arms): out with him, until it is
## back on the farm.
var out_with_him := false

var _task_t := 0.0
var _going := false
var _settled := false
var _think := 0.0
var _probe_t := 0.0
var _detour := 0.0
var _detour_side := 1.0
var _stuck_t := 0.0
## What it goes back to after a pat or a sit.
var _after: StringName = &"follow"
## Seconds it looks up at the farmer (a whistle, a command it doesn't know yet).
var _look_up := 0.0
var _play_left := 0
## The ball was just thrown (not tossed about in play): its first pick-up counts.
var _fresh_throw := false
var _play_goal := Vector3.INF
var _mouth_t := 0.0
var _post := Vector3.INF
var _wolf: Node3D
var _grow_t := 0.0
var _ball_mesh: MeshInstance3D
## Where the ball was snatched up from, and the seconds since (it swings into the mouth).
var _snatch_from := Vector3.ZERO
var _snatch_t := 9.0
## This ball's bringing back has been counted (`fetched`).
var _brought := false
## Held or riding: seconds to its next look (at him, out of the window), how long the look
## lasts, what it looks at (0 about, 1 at him, 2 out of the side window), and to its next whine.
var _gaze_wait := 2.0
var _gaze_t := 0.0
var _gaze := 0
var _whine_wait := 5.0
## Going to its bed in the doghouse: it has reached the doorstep and goes in.
var _at_door := false
## Hungry: seconds to its next coming to him, seconds left of this one (0: none), whether
## it has whined this time; counters for tests: the times it came, the whines.
var _beg_wait := 3.0
var _beg_t := 0.0
var _beg_whined := false
var begs := 0
var whines := 0
## Seconds until it tries its bowl again, and the tries that never got there.
var _eat_wait := 0.0
var _eat_tries := 0
## Staying: GameClock.total_minutes since which he is off the farm (-1: he is not), and
## the seconds he has been further than STAY_PERK.
var _stay_alone := -1.0
var _stay_far := 0.0
## Coming to him: the nearest it has been (m), and the seconds since it last got nearer.
var _near_d := INF
var _stall_t := 0.0
## Its way goes by a gate just now (_by_gate).
var _via_gate := false

static var _lot_list: Array = []


func _init() -> void:
	name = "PetDog"


func _ready() -> void:
	super()
	remove_from_group(Dog.GROUP)
	add_to_group(PET_GROUP)
	add_to_group(&"interactable")
	home_area = Rect2()
	_ball_mesh = MeshInstance3D.new()
	_ball_mesh.name = "Ball"
	_ball_mesh.mesh = ItemModels.mesh(Pet.BALL)
	_ball_mesh.top_level = true
	_ball_mesh.visible = false
	_ball_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_ball_mesh)
	Events.day_ending.connect(_on_day_ending)
	grow()


## Its size and a pup's proportions for its age now (Pet.size, Pet.growth).
func grow() -> void:
	size = Pet.size()
	var young := 1.0 - Pet.growth()
	gait_scale = size
	if rig:
		rig.scale = Vector3.ONE * size
		rig.head_scale = lerpf(1.0, Pet.PUPPY_HEAD, young)
		rig.paw_scale = lerpf(1.0, Pet.PUPPY_PAWS, young)
	var cap := _shape.shape as CapsuleShape3D if _shape else null
	if cap:
		cap.radius = 0.15 * size
		cap.height = 0.92 * size
	if _on_screen:
		_on_screen.aabb = AABB(Vector3(-0.4, 0.0, -0.8) * size, Vector3(0.8, 0.9, 1.6) * size)
	if task == &"ride" and vehicle != null and is_instance_valid(vehicle):
		# Grown on the seat: sat on it again at its new size.
		_fit_seat()


## The farm's valley (where it follows him; off it, he is away).
static func on_farm(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < WorldLayout.VALLEY_RADIUS - 4.0


# --- The farmer's commands (Pet) -------------------------------------------------------------

## A whistle: heeded, it comes running; not (a pup with its nose in something), it only
## looks up and goes on.
func whistled(heeded: bool) -> void:
	_look_up = 1.6
	if not heeded or task == &"carry" or task == &"offer" or task == &"eat" or is_carried():
		return
	if holding_ball:
		_drop_ball(Vector3.ZERO)
	_set_task(&"come")
	_barks_left = 1
	_bark_wait = 0.3


## "Sit!": it sits where it is, looking up at him; having learnt it (Pet.knows), it stays
## there until he releases it.
func sit_down() -> void:
	if is_carried():
		return
	if task != &"sit" and task != &"petted":
		_after = task
	_set_task(&"sit")
	_start_act(Act.SIT)
	stay = Pet.knows(&"sit")
	_stay_alone = -1.0
	_stay_far = 0.0


## Whether it sits and waits for him now (told to, learnt).
func is_staying() -> bool:
	return stay and task == &"sit"


## "Up!" (F again): the stay is over, it is with him again, with a bark for it.
func release() -> void:
	if not is_staying():
		return
	_set_task(&"follow")
	_look_up = 2.0
	_barks_left = 1
	_bark_wait = 0.25


## Loaded while it stayed: sitting (lying) there again turned to `yaw`, he having been off
## the farm `alone_minutes` of game time (-1: he was not) and further than STAY_PERK from
## it `far_seconds`.
func resume_stay(yaw: float, alone_minutes: float, far_seconds: float) -> void:
	_yaw = yaw
	rotation.y = yaw
	sit_down()
	stay = true
	_stay_alone = GameClock.total_minutes - alone_minutes if alone_minutes >= 0.0 else -1.0
	_stay_far = maxf(far_seconds, 0.0)
	if _stay_far > STAY_LIE:
		_act = Act.LIE


## Game minutes he has been off the farm while it stays (-1: he is not, or it does not stay).
func stay_alone_minutes() -> float:
	return maxf(GameClock.total_minutes - _stay_alone, 0.0) if is_staying() and _stay_alone >= 0.0 else -1.0


## Seconds he has been further than STAY_PERK from it on its stay.
func stay_far_seconds() -> float:
	return _stay_far if is_staying() else 0.0


## He goes to bed with it still sitting somewhere: it goes to its own place for the night.
func _on_day_ending() -> void:
	if is_staying():
		send_home()


## "Sit!" not yet learnt: it looks up at him wagging, not sure what he wants.
func puzzled() -> void:
	_look_up = 2.5
	if randf() < 0.5:
		bark()


## Asked for a lesson on an empty stomach: it looks up at him and whines.
func refuse_lesson() -> void:
	_look_up = 2.5
	whines += 1
	_sound("dog_whine", -9.0)


## Hungry with an empty bowl: it comes to him now, looks up, whines, looks at its bowl.
func beg() -> void:
	if task != &"follow" or is_carried():
		return
	_beg_t = BEG_TIME
	_beg_whined = false
	_beg_wait = randf_range(BEG_EVERY.x, BEG_EVERY.y)
	_going = false
	begs += 1


## A pat: it sits and leans into the hand a moment.
func petted_by(petter: Node3D) -> void:
	if is_carried():
		return
	if holding_ball:
		# It lets the ball drop to be petted: at its feet, before its nose.
		_drop_ball(-global_basis.z * 0.3)
	ball = null
	if task != &"petted":
		_after = task
	_set_task(&"petted")
	set_mode(&"petted", petter.global_position if petter else Vector3.INF)


## Turns it at once to face `p` (set down beside the farmer).
func look_toward(p: Vector3) -> void:
	var to := _flat(p - global_position)
	if to.length() > 0.05:
		_yaw = atan2(-to.x, -to.z)
		rotation.y = _yaw


## A ball thrown: it goes after it (not while he is away, nor with wolves to watch).
func chase(b: Pickup) -> void:
	if b == null or task == &"home" or task == &"wait" or task == &"eat" or is_carried() or (task == &"guard" and _wolf != null):
		return
	_beg_t = 0.0
	if holding_ball:
		# Another ball: the one in its mouth is let go.
		_drop_ball(Vector3.ZERO)
	ball = b
	_play_left = randi_range(2, 3)
	_fresh_throw = true
	_set_task(&"fetch")


# --- The player's interaction ------------------------------------------------------------------

func interact_title() -> String:
	return Pet.dog_name


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_PET")


func interact(_player: Node) -> void:
	Pet.pat()


## Under its name: that it waits for him (told to sit), and how it is (fed, getting
## hungry, hungry).
func hint_prompt() -> String:
	var mood := Pet.mood_text()
	if is_staying():
		return tr("PET_STAYING") if mood == "" else "%s · %s" % [tr("PET_STAYING"), mood]
	return mood


## F: "sit!" (sitting on its stay: "up!"); with the ball in its mouth, the ball out of it.
func info_prompt() -> String:
	if holding_ball:
		return tr("ACTION_DOG_TAKE_BALL")
	return tr("ACTION_DOG_UP") if is_staying() else tr("ACTION_DOG_SIT")


func info_interact(player: Node) -> void:
	if holding_ball:
		take_ball(player)
	else:
		Pet.command_sit()


## The ball out of its mouth into the farmer's bag (no room there: it keeps it). Returns
## whether he has it.
func take_ball(player: Node) -> bool:
	if not holding_ball:
		return false
	var stack := ItemStack.create(Pet.BALL, 1)
	if stack == null or PlayerState.inventory.add_stack(stack) > 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))
		return false
	var from := _ball_mesh.global_transform
	holding_ball = false
	_ball_mesh.visible = false
	ball = null
	Audio.play("soft", global_position, -12.0, 0.1, &"Effects", 3.0, 1.7)
	Game.notify("+1x %s" % ItemDB.get_item(Pet.BALL).display_name())
	Events.item_picked_up.emit(Pet.BALL, 1)
	if player is Player:
		(player as Player).show_take(Pet.BALL, from)
	if task in [&"offer", &"carry", &"play"]:
		_set_task(&"follow")
	_look_up = 2.0
	return true


# --- Carried, and riding along (AnimalHandler) ---------------------------------------------------

## Whether G picks it up now (not with wolves to bark at).
func can_carry() -> bool:
	return task != &"held" and task != &"ride" and not (task == &"guard" and _wolf != null)


## In his arms or on the seat: nothing in the world acts on it.
func is_carried() -> bool:
	return task == &"held" or task == &"ride"


## Picked up into the farmer's arms: out of the world's goings-on (no body to bump into or
## aim at, no shadow of a dog in mid air) until put down; the handler places it in front of
## the view every frame (pose_held).
func pick_up() -> void:
	if holding_ball:
		_drop_ball(Vector3.ZERO)
	ball = null
	_set_task(&"held")
	_leave_world()
	_gaze = 1
	_gaze_t = 1.5
	_gaze_wait = randf_range(HELD_LOOK_EVERY.x, HELD_LOOK_EVERY.y)
	_whine_wait = randf_range(2.0, 5.0)
	_sound("dog_whine", -10.0)


## Set down at `p` facing `yaw`: on its feet in the world again, with him.
func put_down(p: Vector3, yaw: float) -> void:
	vehicle = null
	seat_across = false
	rig.sit_tuck = 0.0
	rig.tail_side = 0.0
	# Its collider comes back once its body has been carried here: set down from the
	# passenger seat with it on, the body's sweep across the cab rammed the pickup through
	# the ground (BodyWarp).
	BodyWarp.on_after_move(_shape)
	add_to_group(&"interactable")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	rig.held = false
	for mi in rig.meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_yaw = yaw
	global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
	out_with_him = not on_farm(p)
	_floor_y = p.y
	_speed = 0.0
	reset_physics_interpolation()
	_set_task(&"follow")
	_look_up = 2.0


## Onto the passenger seat of `v` (he got in carrying it): it rides along, sitting.
func seat_in(v: Vehicle) -> void:
	if task != &"held":
		_leave_world()
	vehicle = v
	_set_task(&"ride")
	_gaze = 0
	_gaze_wait = randf_range(1.0, 2.5)
	rig.snap_sit()
	_fit_seat()
	_place_on_seat()
	reset_physics_interpolation()


## Where it sits in the vehicle it rides in (the vehicle's body frame).
func seat_spot() -> Transform3D:
	return _seat


## Sits it on the vehicle's passenger seat (Vehicle.seat, measured off the cab) by its own
## body as it sits at its size now (DogRig.sitting_points): its lowest points (its soles,
## its hocks) on the cushion's top, square on the cushion's rake, its tail laid round on
## the cushion instead of out behind. Facing the road, in the seat's middle, its rump
## SEAT_GAP before the seat's back, while it is no longer than the cushion (its forepaws
## drawn back up to SEAT_TUCK_EASY to stay on it) and its nose is short of the dashboard;
## longer than that (it grows to more than a seat is deep), it sits across the seat as a
## big dog does, facing the driver, its rump by the door or its hocks at the cushion's
## side where the door is further out, its side SEAT_GAP before the seat's back (its
## forepaws drawn back up to SEAT_TUCK where the seats are narrow).
func _fit_seat() -> void:
	var frame := vehicle.passenger_seat()
	var s := vehicle.seat()
	rig.sit_tuck = 0.0
	seat_across = false
	if s.is_empty() or rig.skeleton == null:
		rig.tail_side = 0.0
		_seat = frame
		return
	var up := frame.basis.y
	var ahead := -frame.basis.z
	var foot: Vector3 = s["at"]
	# Its own right is the vehicle's right: the tail goes to the driver's side.
	var driver := signf(vehicle.driver_eye_local().x)
	rig.tail_side = -driver
	var m := _sitting()
	var tuck := maxf(SEAT_GAP + float(m["rear"]) + float(m["fore"]) + SEAT_EDGE * size - float(s["depth"]), 0.0) / size
	# Across the seat its middle is this far from the seat's middle toward the driver: its
	# rump SEAT_GAP before the door, and its hocks on the cushion (a seat narrower than
	# the cab leaves a gap by the door: it does not sit over that).
	var mid_across := maxf(SEAT_GAP + float(m["rear"]) - float(s["door"]), float(m["hock"]) + SEAT_SIDE - float(s["width"]) * 0.5)
	var tuck_across := maxf(mid_across + float(m["fore"]) - SEAT_TOES * size - float(s["inner"]), 0.0) / size
	# Facing the road: on a cushion long enough for it, its nose short of the dashboard.
	var fits := tuck <= SEAT_TUCK_EASY and SEAT_GAP + float(m["rear"]) + float(m["nose"]) + SEAT_NOSE * size <= float(s["ahead"])
	if fits or (tuck_across > SEAT_TUCK and tuck_across >= tuck):
		if tuck > 0.0:
			rig.sit_tuck = minf(tuck, SEAT_TUCK)
			m = _sitting()
		_seat = Transform3D(frame.basis, foot + ahead * (SEAT_GAP + float(m["rear"])) + up * (SEAT_OVER - float(m["low"])))
		return
	# Across the seat: facing the driver (its right toward the road ahead, where its tail
	# goes: the seat's back is on its other side).
	seat_across = true
	var to_driver := Vector3(driver, 0.0, 0.0)
	var basis := Basis(up.cross(-to_driver), up, -to_driver)
	var right_ahead := basis.x.dot(ahead) > 0.0
	rig.tail_side = 1.0 if right_ahead else -1.0
	rig.sit_tuck = minf(tuck_across, SEAT_TUCK)
	m = _sitting()
	mid_across = maxf(SEAT_GAP + float(m["rear"]) - float(s["door"]), float(m["hock"]) + SEAT_SIDE - float(s["width"]) * 0.5)
	var back_side: float = m["left"] if right_ahead else m["right"]
	var along := maxf(float(s["depth"]) * 0.5, SEAT_GAP + back_side)
	_seat = Transform3D(basis, foot + ahead * along + to_driver * mid_across + up * (SEAT_OVER - float(m["low"])))


## Its body as it sits at its size (its own frame, m): "low" its lowest point's height,
## "rear" how far behind its middle its rearmost point is, "fore" how far ahead of it its
## forepaws' toes reach and "nose" its nose, "left" and "right" how far to either side
## it reaches, "hock" how far behind its middle it rests on what it sits on (its hind
## paws and the pasterns lying behind them: its rump and its tail reach further back, in
## the air).
func _sitting() -> Dictionary:
	var low := INF
	var rear := -INF
	var left := 0.0
	var right := 0.0
	var fore := 0.0
	var nose := 0.0
	var hock := 0.0
	var pts := rig.sitting_points(SEAT_SKIN)
	var bones := rig.skin_bones(SEAT_SKIN)
	for i in pts.size():
		pts[i] = rig.transform * pts[i]
		low = minf(low, pts[i].y)
	for i in pts.size():
		var p := pts[i]
		rear = maxf(rear, p.z)
		left = maxf(left, -p.x)
		right = maxf(right, p.x)
		nose = maxf(nose, -p.z)
		var bone := bones[i]
		if bone == "fl_toe" or bone == "fr_toe":
			fore = maxf(fore, -p.z)
		elif (bone == "rl_ft" or bone == "rr_ft" or bone == "rl_toe" or bone == "rr_toe") and p.y < low + 0.03 * size:
			hock = maxf(hock, p.z)
	return {"low": low, "rear": rear, "fore": fore, "nose": nose, "left": left, "right": right, "hock": hock}


## Out of the vehicle with him: down at `p` facing `yaw`, with a bark for having arrived.
func leave_vehicle(p: Vector3, yaw: float) -> void:
	put_down(p, yaw)
	_barks_left = 1
	_bark_wait = 0.35


## Its body out of the world while it is carried or rides.
func _leave_world() -> void:
	BodyWarp.off(_shape)
	remove_from_group(&"interactable")
	# Moved per rendered frame (with the view, with the vehicle as it is drawn).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	rig.held = true
	for mi in rig.meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_speed = 0.0
	_want_speed = 0.0


## The handler has just put it in front of the view: its pose for this frame (sitting on his
## forearm, looking about, up at him for a moment now and then, wagging; a soft whine).
func pose_held(delta: float) -> void:
	_gaze_wait -= delta
	_gaze_t -= delta
	if _gaze_t <= 0.0:
		_gaze = 0
	if _gaze_wait <= 0.0:
		_gaze_wait = randf_range(HELD_LOOK_EVERY.x, HELD_LOOK_EVERY.y)
		_gaze_t = randf_range(HELD_LOOK_TIME.x, HELD_LOOK_TIME.y)
		_gaze = 1
	_whine_wait -= delta
	if _whine_wait <= 0.0:
		_whine_wait = randf_range(HELD_WHINE_EVERY.x, HELD_WHINE_EVERY.y)
		_sound("dog_whine", -14.0)
	_bark_cd = maxf(_bark_cd - delta, 0.0)
	_mood()
	rig.animate(delta, 0.0)


## On the seat as the vehicle is drawn this frame.
func _place_on_seat() -> void:
	global_transform = vehicle.get_global_transform_interpolated() * _seat
	_yaw = global_rotation.y
	_floor_y = global_position.y


## Riding: on the seat, looking about, now out of the side window, now at the driver.
func _ride(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
		# The vehicle is gone from under it: down where it is.
		var at := global_position
		put_down(Vector3(at.x, TerrainData.height(at.x, at.z), at.z), _yaw)
		return
	_place_on_seat()
	_gaze_wait -= delta
	_gaze_t -= delta
	if _gaze_t <= 0.0:
		_gaze = 0
	if _gaze_wait <= 0.0:
		_gaze_wait = randf_range(RIDE_LOOK_EVERY.x, RIDE_LOOK_EVERY.y)
		_gaze_t = randf_range(1.5, 4.0)
		_gaze = 2 if randf() < 0.6 else 1
	_mood()
	rig.animate(delta, 0.0)


# --- Frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if task == &"held":
		# Posed by the handler, right after it is put in front of the view (pose_held).
		return
	if task == &"ride":
		_ride(delta)
		return
	super(delta)
	if holding_ball:
		_snatch_t += delta
		var mouth := _mouth_point()
		_ball_mesh.global_position = mouth if _snatch_t >= SNATCH_TIME else _snatch_from.lerp(mouth, smoothstep(0.0, 1.0, _snatch_t / SNATCH_TIME))
		_ball_mesh.scale = Vector3.ONE * clampf(size * 1.3, 0.8, 1.0)


func _physics_process(delta: float) -> void:
	_mode_t += delta
	_task_t += delta
	_look_up -= delta
	if is_carried():
		# In his arms or on the seat: placed and posed per rendered frame (_process); only
		# its growing goes on.
		_think -= delta
		if _think <= 0.0:
			_think = 0.25
			_decide()
		return
	_bark_cd = maxf(_bark_cd - delta, 0.0)
	_sound_t -= delta
	_notice_player(delta)
	_think -= delta
	if _think <= 0.0:
		_think = 0.25
		_decide()
	match task:
		&"follow":
			_follow(delta)
		&"home":
			_stay_home(delta)
		&"wait":
			_roam(delta)
		&"bed", &"guard":
			_night_watch(delta)
		&"come":
			_come(delta)
		&"sit":
			_sit(delta)
		&"petted":
			target = _player_pos()
			_petted(delta)
			if _task_t > PET_HOLD:
				_set_task(_after if _after in [&"follow", &"home", &"bed", &"guard"] else &"follow")
		&"eat":
			_eat_bowl(delta)
		&"fetch":
			_fetch(delta)
		&"carry":
			_carry(delta)
		&"offer":
			_offer(delta)
		&"play":
			_play(delta)
	_move_pet(delta)
	_place_collider()


## What it should be doing, four times a second: the day's routine (with him on the farm,
## at home while he is away, its bed or its watch at night) and its growing.
func _decide() -> void:
	_grow_t -= 0.25
	if _grow_t <= 0.0:
		_grow_t = 5.0
		if absf(Pet.size() - size) > 0.002:
			grow()
	if is_carried():
		return
	if out_with_him and on_farm(global_position):
		out_with_him = false
	var away := _away()
	var out := out_with_him
	# Off the farm with him it keeps to him by night too (its bed is at the farm).
	var night := _night_now() and not out
	_wolf = _nearest_wolf() if task == &"guard" else null
	if out and away:
		# Left behind off the farm: it waits there a while, then goes home on its own.
		if task != &"wait":
			if holding_ball:
				_drop_ball(Vector3.ZERO)
			ball = null
			_set_task(&"wait")
			Pet.note_left()
		elif Pet.wait_over():
			_go_home()
		return
	_eat_wait = maxf(_eat_wait - 0.25, 0.0)
	if Pet.hungry() and not out and not night and (task == &"follow" or task == &"home") and on_farm(global_position):
		if Pet.bowl_meals > 0:
			if _eat_wait <= 0.0:
				_beg_t = 0.0
				_set_task(&"eat")
				return
		elif task == &"follow" and _beg_t <= 0.0 and not away:
			# The bowl is empty: now and then it comes to him to say so.
			_beg_wait -= 0.25
			if _beg_wait <= 0.0 and _flat(_player_pos() - global_position).length() < BEG_RANGE:
				beg()
	elif _beg_t > 0.0 and not Pet.hungry():
		_beg_t = 0.0
	match task:
		&"wait":
			# He is back: a run and a bark or two to greet him.
			Pet.left_at = -1.0
			_set_task(&"come")
			_barks_left = 2
			_bark_wait = 0.3
		&"follow":
			if away:
				_set_task(&"home")
			elif night:
				_set_task(_night_task())
		&"home":
			if night:
				_set_task(_night_task())
			elif not away and _flat(_player_pos() - global_position).length() < 35.0:
				# He is back: a run and a bark or two to greet him.
				_set_task(&"come")
				_barks_left = 2
				_bark_wait = 0.3
		&"bed", &"guard":
			if not night:
				# (Wolves it got up from its stay for by day: it barks till they are gone.)
				if not (task == &"guard" and _wolf != null):
					_set_task(&"home" if away else &"follow")
			elif task != _night_task():
				_set_task(_night_task())
		&"sit":
			if stay:
				_decide_stay(away, night)
			elif away or _task_t > SIT_HOLD or _flat(_player_pos() - global_position).length() > 12.0:
				_set_task(&"follow")
		&"come":
			if away:
				_set_task(&"home")
		&"fetch", &"carry", &"offer", &"play":
			if away:
				if holding_ball:
					_drop_ball(Vector3.ZERO)
				ball = null
				_set_task(&"home")


## On its stay, four times a second: what ends it besides his release (night, wolves, he
## off the farm too long), the clock of his being off the farm, and the one-time note as
## he first walks away from it.
func _decide_stay(away: bool, night: bool) -> void:
	if night:
		# Night falls: to its bed, or (grown) on its watch.
		_set_task(_night_task())
		return
	var wolf := _nearest_wolf()
	if wolf != null:
		# Wolves: grown it is up and barks at them as on its watch; a pup runs to him.
		if Pet.guards():
			_set_task(&"guard")
			_wolf = wolf
		else:
			_set_task(&"home" if away else &"follow")
			_barks_left = 2
			_bark_wait = 0.2
		return
	var p := _player_pos()
	# (Off the farm with him, his walking off is the usual &"wait": _decide.)
	var gone := not out_with_him and (not p.is_finite() or not on_farm(p))
	if not gone:
		_stay_alone = -1.0
	elif _stay_alone < 0.0:
		_stay_alone = GameClock.total_minutes
	elif GameClock.total_minutes - _stay_alone >= STAY_MINUTES:
		# He has been off the farm long enough: home to its place, and he is told.
		Pet.stay_given_up()
		_set_task(&"home")
		return
	if p.is_finite() and _flat(p - global_position).length() > STAY_TOLD_AT:
		Pet.stay_note()


func _set_task(t: StringName) -> void:
	if task == &"wait" and t != &"wait":
		# No longer left behind (he is back, it was whistled for, it went home).
		Pet.left_at = -1.0
	task = t
	stay = false
	_task_t = 0.0
	_beg_t = 0.0
	_going = false
	_settled = false
	_stuck_t = 0.0
	_mouth_t = 0.0
	_play_goal = Vector3.INF
	_at_door = false
	_near_d = INF
	_stall_t = 0.0
	home_area = _home_area() if t == &"home" else Rect2()
	if t == &"wait":
		# The patch it keeps to where it was left.
		home_area = Rect2(global_position.x - WAIT_PATCH, global_position.z - WAIT_PATCH, WAIT_PATCH * 2.0, WAIT_PATCH * 2.0)
	if mode != &"roam":
		set_mode(&"roam")
	else:
		_start_act(Act.STAND)
	if t == &"guard":
		_post = _guard_post()


func _night_now() -> bool:
	var h := GameClock.get_hour_float()
	return h >= NIGHT_FROM or h < NIGHT_TO


func _night_task() -> StringName:
	return &"guard" if Pet.guards() else &"bed"


## The farmer away: driving (without it), or, the dog on the farm, off the farm's valley
## (gone to town); off the farm with him, once he has gone LEFT_FAR from it (back again
## within BACK_NEAR; whistled for, it comes from as far as it heard him).
func _away() -> bool:
	var p := Game.player as Player
	if p == null or not is_instance_valid(p):
		return true
	if p.driving != null:
		return true
	if not out_with_him:
		return not on_farm(p.global_position)
	var limit := LEFT_FAR
	if task == &"wait":
		limit = BACK_NEAR
	elif task == &"come":
		limit = Pet.WHISTLE_RANGE + 10.0
	return _flat(p.global_position - global_position).length() > limit


## It has waited long enough where it was left: home to its doghouse (its bed), once nobody
## is looking at it.
func _go_home() -> void:
	if _on_screen.is_on_screen() and _camera_pos().distance_to(global_position) < 70.0:
		return
	send_home()
	Pet.note_home()


## Straight to its place at the farm (the doghouse's doorstep, its bed), whatever it was doing.
func send_home() -> void:
	if is_carried():
		return
	if holding_ball:
		_drop_ball(Vector3.ZERO)
	ball = null
	Pet.left_at = -1.0
	out_with_him = false
	_warp(Pet.home_point())
	_set_task(&"home")


# --- The day ---------------------------------------------------------------------------------

## Loosely after him: up to FOLLOW_NEAR off when he is further than FOLLOW_FAR (by the
## door while he is in the house), then pottering about.
func _follow(delta: float) -> void:
	var p := _player_pos()
	if not p.is_finite():
		return
	var goal := p
	var near := FOLLOW_NEAR
	var far := FOLLOW_FAR
	if WolfRaids.in_house(p):
		goal = _door_point()
		near = 0.5
		far = 1.6
	var d := _flat(goal - global_position).length()
	if _beg_t > 0.0:
		_beg(p, delta)
		return
	if not _going and d > far:
		_going = true
		_start_act(Act.WANDER)
	if _going:
		if d <= near + 0.25:
			_going = false
			_start_act(Act.STAND)
			return
		var spot := goal + _flat(global_position - goal).normalized() * near
		# (Hungry it trots where it would run.)
		var pace := RUN if d > 9.0 and not Pet.hungry() else (TROT if d > 4.5 else WALK)
		_steer(spot, pace * size, delta)
		if d > CATCH_UP:
			_catch_up(goal)
		return
	_roam(delta)


## Told to sit. Not having learnt to stay: sitting, turned to him. On its stay: sitting,
## turning after him as he goes; he further than STAY_PERK for STAY_LIE seconds it lies
## down (and lies as it is: only its head follows him), and sits up when he is back.
func _sit(delta: float) -> void:
	_want_speed = 0.0
	var p := _player_pos()
	if not stay:
		_act = Act.SIT
		_turn_to(p, delta * 0.5)
		return
	var near := p.is_finite() and _flat(p - global_position).length() < STAY_PERK
	_wag_t -= delta
	if near and _stay_far > STAY_LIE:
		# He is back: up on its haunches, its tail going.
		_wag_t = 5.0
	_stay_far = 0.0 if near else _stay_far + delta
	_act = Act.LIE if _stay_far > STAY_LIE else Act.SIT
	if rig.lie_amount() < 0.05 and p.is_finite():
		_turn_to(p, delta * 0.5)


## Hungry, its bowl empty: up to him (COME_GAP off), then standing before him, looking
## up at him with a whine and, for the last of it, round at its bowl.
func _beg(p: Vector3, delta: float) -> void:
	var d := _flat(p - global_position).length()
	if d > BEG_RANGE or WolfRaids.in_house(p):
		_beg_t = 0.0
		return
	if d > COME_GAP + 0.5 and not _beg_whined:
		# (He walks on: it gives it up after a while.)
		_beg_t -= delta * 0.25
		_act = Act.STAND
		_steer(p + _flat(global_position - p).normalized() * COME_GAP, (TROT if d > 3.0 else WALK) * size, delta)
		return
	_want_speed = 0.0
	_act = Act.STAND
	_beg_t -= delta
	if not _beg_whined:
		_beg_whined = true
		whines += 1
		_sound("dog_whine", -8.0)
	_turn_to(p if _beg_t > BEG_TIME * 0.4 else Pet.bowl_point(), delta)
	if _beg_t <= 0.0:
		_start_act(Act.STAND)


## At its bowl: to where it stands to eat, round to face the bowl, its head down in it
## for MEAL_TIME; then it is fed, with a bark for it, and off to him again.
func _eat_bowl(delta: float) -> void:
	if Pet.bowl_meals <= 0 or not Pet.hungry():
		_set_task(&"follow")
		return
	var bowl := Pet.bowl_point()
	if not _settled:
		var stand := Pet.bowl_stand(Vector2(_eat_nose.x, _eat_nose.z).length() * size)
		var d := _flat(stand - global_position).length()
		if d > 0.06 and _task_t < EAT_REACH:
			_act = Act.STAND
			_steer(stand, (RUN * HUNGRY_PACE if d > 8.0 else (TROT if d > 2.0 else (WALK if d > 0.4 else 0.35))) * size, delta)
			if (d > 30.0 or _stuck_t > 5.0 or _task_t > EAT_REACH * 0.5) and not _on_screen.is_on_screen() and _camera_pos().distance_to(stand) > 30.0:
				_warp(stand)
				look_toward(bowl)
			return
		if d > 0.6:
			# It never got to its bowl (something in the way): later again; the third time
			# it has eaten all the same.
			_eat_tries += 1
			if _eat_tries >= 3:
				_eat_tries = 0
				Pet.meal_eaten()
			_eat_wait = EAT_RETRY
			_set_task(&"follow")
			return
		_want_speed = 0.0
		_act = Act.STAND
		_turn_to(bowl, delta * 1.5)
		if _facing(bowl, 0.1) or _task_t > EAT_REACH + 3.0:
			_settled = true
			_eat_left = MEAL_TIME
			_sound_t = 0.4
		return
	_want_speed = 0.0
	_act = Act.STAND
	_turn_to(bowl, delta * 0.3)
	_eat_left -= delta
	if _sound_t <= 0.0:
		_sound_t = randf_range(1.1, 1.8)
		_sound("dog_eat", -9.0)
	if _eat_left <= 0.0:
		_eat_tries = 0
		Pet.meal_eaten()
		_set_task(&"follow")
		_look_up = 2.5
		_barks_left = 1
		_bark_wait = 0.5


## Whether its head is down in its bowl now (tests).
func is_eating() -> bool:
	return task == &"eat" and _settled


## Just outside the farmhouse's door.
func _door_point() -> Vector3:
	var x := WorldLayout.HOUSE_DOOR_X + 1.0
	var z := WorldLayout.HOUSE_FRONT_Z + 2.4
	return Vector3(x, TerrainData.height(x, z), z)


## Out of sight far behind: round the corner after him, a few metres back. `stuck` (it
## has come no nearer for a while): also when it is only hidden from him (a wall between
## it and his eyes), and to whichever side of him he does not look at, with a clear way on
## to him from there.
func _catch_up(goal: Vector3, stuck := false) -> void:
	if _on_screen.is_on_screen() and not (stuck and _hidden()):
		return
	var back := _flat(global_position - goal).normalized()
	var cam := get_viewport().get_camera_3d()
	var turns: Array[float] = [0.0]
	if stuck:
		turns = [0.0, 1.0, -1.0, 2.1, -2.1, PI]
	for turn in turns:
		var at := goal + back.rotated(Vector3.UP, turn) * 8.0
		at.y = TerrainData.height(at.x, at.z)
		if cam and cam.is_position_in_frustum(at + Vector3(0, 0.3, 0)):
			continue
		if absf(_ground_at(at.x, at.z) - at.y) > 0.3:
			continue
		if stuck and _ray(Vector3(goal.x, goal.y + 0.4, goal.z), at + Vector3(0, 0.4, 0)):
			continue
		_warp(at)
		_near_d = INF
		_stall_t = 0.0
		return


## Coming to him, `d` m off: whether it has come no nearer for COME_STALL seconds (going
## round by a gate is its way to him, however far round).
func _stalled(d: float, delta: float) -> bool:
	if _via_gate or d < _near_d - 0.5:
		_near_d = d
		_stall_t = 0.0
		return false
	_stall_t += delta
	return _stall_t > COME_STALL


## Something solid and tall (a building, not a fence he sees it over or through) between
## the farmer's eyes and it: he cannot see it.
func _hidden() -> bool:
	var cam := _camera_pos()
	return _ray(cam, global_position + Vector3(0, 0.3 * size + 0.1, 0)) and _ray(cam, global_position + Vector3(0, 1.7, 0))


func _warp(at: Vector3) -> void:
	# Never swept there with its collider on (BodyWarp).
	BodyWarp.moved(_shape)
	global_position = at
	_floor_y = at.y
	_speed = 0.0
	reset_physics_interpolation()


## Its patch while the farmer is away (x, z rect): in front of its doghouse, or round its
## bed in front of the house.
func _home_area() -> Rect2:
	if Pet.kennel != null:
		var c := Pet.kennel.yard_point()
		return Rect2(c.x - 2.3, c.z - 2.3, 4.6, 4.6)
	var bed := Pet.bed_point()
	return Rect2(bed.x - 1.4, bed.z - 0.8, 4.2, 4.0)


## By its doghouse (its bed) while he is away (back there first), roaming its patch.
func _stay_home(delta: float) -> void:
	var bed := Pet.home_point()
	if not _home_area().grow(-0.5).has_point(Vector2(global_position.x, global_position.z)):
		var d := _flat(bed - global_position).length()
		var cam := _camera_pos()
		# (Beside the bed by the house; on the doghouse's doorstep.)
		var beside := bed if Pet.kennel != null else bed + Vector3(1.4, 0.0, 1.2)
		if d > 30.0 and not _on_screen.is_on_screen() and cam.distance_to(bed) > 30.0:
			_warp(beside)
			return
		_steer(bed, (TROT if d > 8.0 else WALK) * size, delta)
		if _stuck_t > 6.0 and not _on_screen.is_on_screen():
			_warp(beside)
		return
	_roam(delta)


## Night: to its bed and asleep on it, or (grown) on watch near the animals.
func _night_watch(delta: float) -> void:
	var spot := Pet.bed_point() if task == &"bed" else _post
	if task == &"guard" and _wolf != null and is_instance_valid(_wolf):
		var away := _flat(global_position - _wolf.global_position)
		_act = Act.STAND
		if away.length() < WOLF_BACK_OFF:
			# Too close: it gives ground, still barking.
			_steer(global_position + away.normalized() * 3.0, TROT * size, delta)
		else:
			_want_speed = 0.0
			_turn_to(_wolf.global_position, delta)
		if _sound_t <= 0.0:
			_sound_t = randf_range(0.7, 1.4)
			bark()
		return
	var in_kennel := task == &"bed" and Pet.kennel != null
	if not _settled:
		var d := _flat(spot - global_position).length()
		if d > (0.12 if in_kennel else 0.3) and _stuck_t < 5.0 and _task_t < 120.0:
			_act = Act.STAND
			if in_kennel and not _at_door:
				# To its doorstep first, then in through the door.
				var step := Pet.kennel.porch_point()
				var ds := _flat(step - global_position).length()
				if ds < 0.3 or Pet.kennel.in_doorway(global_position):
					_at_door = true
				else:
					_steer(step, (TROT if ds > 6.0 else WALK) * size, delta)
			else:
				_steer(spot, (TROT if d > 6.0 else WALK) * size, delta)
			if d > 30.0 and not _on_screen.is_on_screen() and _camera_pos().distance_to(spot) > 30.0:
				_warp(spot)
				_face_out()
			return
		if in_kennel and d > 0.5 and not _on_screen.is_on_screen():
			# It never found its way in (something in the way): it is in there all the same.
			_warp(spot)
			_face_out()
		_settled = true
		_start_act(Act.STAND if in_kennel else Act.LIE)
	_want_speed = 0.0
	if in_kennel and rig.lie_amount() < 0.05 and not _facing(Pet.kennel.porch_point(), 0.25):
		# Round to face out of the door before it lies down.
		_act = Act.STAND
		_turn_to(Pet.kennel.porch_point(), delta * 1.6)
		return
	_act = Act.LIE
	_act_t += delta


## Turned at once to look out of its doghouse's door.
func _face_out() -> void:
	if Pet.kennel != null:
		look_toward(Pet.kennel.porch_point())


## Where it keeps watch: from the animals GUARD_OFF toward the farmhouse.
func _guard_post() -> Vector3:
	var a := WolfRaids.animals_area()
	var house := _door_point()
	var dir := _flat(house - a)
	var p := a + dir.normalized() * minf(GUARD_OFF, dir.length()) if dir.length() > 0.1 else a
	return Vector3(p.x, TerrainData.height(p.x, p.z), p.z)


func _nearest_wolf() -> Node3D:
	var best: Node3D = null
	var best_d := WOLF_BARK
	for w in WolfRaids.wolves():
		var d := _flat(w.global_position - global_position).length()
		if d < best_d:
			best = w
			best_d = d
	return best


## Whistled: running to him, then greeting him.
func _come(delta: float) -> void:
	var p := _player_pos()
	if not p.is_finite():
		_set_task(&"follow")
		return
	if mode == &"greet":
		target = p
		_greet(delta)
		if _mode_t > GREET_HOLD:
			_set_task(&"follow")
		return
	var d := _flat(p - global_position).length()
	if d <= COME_GAP + 0.3 or _task_t > 40.0:
		came += 1
		set_mode(&"greet", p)
		return
	var spot := p + _flat(global_position - p).normalized() * COME_GAP
	_steer(_by_gate(spot), (RUN if d > 3.0 else TROT) * size, delta)
	if d > CATCH_UP:
		_catch_up(p)
	elif _stalled(d, delta):
		_catch_up(p, true)


# --- The ball --------------------------------------------------------------------------------

## After the ball at a run, to where it will be in a moment (it cuts a rolling ball off);
## within its reach (GRAB_EXTRA beyond its nose), rolling or still, its head goes down
## and it has it.
func _fetch(delta: float) -> void:
	if ball == null or not is_instance_valid(ball) or ball.is_queued_for_deletion() or ball._flying:
		ball = null
		_set_task(&"follow")
		return
	var bp := ball.global_position
	var to := _flat(bp - global_position)
	var d := to.length()
	if d <= _mouth_reach() + GRAB_EXTRA and bp.y - global_position.y < GRAB_HIGH * size + 0.25:
		_mouth_t += delta
		_steer(bp, TROT * size, delta)
		if _mouth_t >= GRAB_TIME:
			_pick_up()
		return
	_mouth_t = 0.0
	# (Hungry it is slower to play.)
	var run := FETCH_RUN * size * (HUNGRY_PACE if Pet.hungry() else 1.0)
	var roll := Vector3.ZERO if ball.freeze else ball.linear_velocity
	var ahead := bp + Vector3(roll.x, 0.0, roll.z) * clampf(d / run, 0.0, 0.7)
	# (Easing up over the last two metres: it does not overrun the ball.)
	_steer(_by_gate(ahead), maxf(run * clampf(d / 2.0, 0.0, 1.0), TROT * size), delta)
	if _task_t > FETCH_GIVE_UP:
		# It cannot get at it (behind a fence, afloat far out): the ball stays where it is.
		ball = null
		_set_task(&"follow")


func _pick_up() -> void:
	_snatch_from = ball.global_position if ball and is_instance_valid(ball) else _mouth_point()
	_snatch_t = 0.0
	_brought = false
	if ball and is_instance_valid(ball):
		ball.queue_free()
	ball = null
	holding_ball = true
	_ball_mesh.global_position = _snatch_from
	_ball_mesh.visible = true
	Pet.ball_caught()
	if Pet.knows(&"fetch"):
		_set_task(&"carry")
	else:
		if _fresh_throw:
			played += 1
		_set_task(&"play")
	_fresh_throw = false


## The ball back to him at a run: up to OFFER_GAP before him, and there it stands with it
## (&"offer").
func _carry(delta: float) -> void:
	var p := _player_pos()
	if not p.is_finite() or _task_t > 40.0:
		_drop_ball(Vector3.ZERO)
		ball = null
		_set_task(&"follow")
		return
	var d := _flat(p - global_position).length()
	if d > OFFER_GAP + 0.25:
		var spot := p + _flat(global_position - p).normalized() * OFFER_GAP
		var run := FETCH_RUN * size * (HUNGRY_PACE if Pet.hungry() else 1.0)
		_steer(_by_gate(spot), maxf(run * clampf((d - OFFER_GAP) / 2.0, 0.0, 1.0), TROT * 0.7 * size), delta)
		if d > CATCH_UP:
			_catch_up(p)
		elif _stalled(d, delta):
			_catch_up(p, true)
		return
	if not _brought:
		_brought = true
		fetched += 1
	_set_task(&"offer")


## Before him with the ball in its mouth, looking up at him, wagging: his to pet (E: it
## lets the ball drop at its feet) or to take the ball from (F). He walks off: after him
## with it. Nothing for OFFER_HOLD seconds: it lets the ball drop at his feet and goes on.
func _offer(delta: float) -> void:
	var p := _player_pos()
	if not holding_ball or not p.is_finite():
		_set_task(&"follow")
		return
	if _flat(p - global_position).length() > OFFER_LEFT:
		_set_task(&"carry")
		return
	_want_speed = 0.0
	_act = Act.STAND
	_turn_to(p, delta * 1.5)
	if _task_t > OFFER_HOLD:
		_drop_ball(_flat(p - global_position).normalized() * 0.5 + Vector3.UP * 0.3)
		ball = null
		_set_task(&"follow")
		_look_up = 2.0


## Not yet taught to bring it: trotting about with the ball, dropping it with a toss of the
## head and pouncing on it again, a few times; then it leaves it lying.
func _play(delta: float) -> void:
	if not _play_goal.is_finite():
		_play_goal = _pick_spot(2.2)
	var d := _flat(_play_goal - global_position).length()
	if d > 0.3 and _task_t < 2.5:
		_steer(_play_goal, TROT * 0.8 * size, delta)
		return
	_want_speed = 0.0
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var tossed := _drop_ball(fwd.rotated(Vector3.UP, randf_range(-0.8, 0.8)) * randf_range(0.8, 1.6) + Vector3.UP * 1.1)
	_play_left -= 1
	if _play_left > 0 and tossed:
		ball = tossed
		var keep := _play_left
		_set_task(&"fetch")
		_play_left = keep
	else:
		ball = null
		_set_task(&"follow")


## The ball out of its mouth (with `vel`): lying in the world again, a pickup. Returns it.
func _drop_ball(vel: Vector3) -> Pickup:
	if not holding_ball:
		return null
	holding_ball = false
	_ball_mesh.visible = false
	var stack := ItemStack.create(Pet.BALL, 1)
	if stack == null or Game.world == null:
		return null
	var p := Pickup.spawn(stack, _mouth_point())
	p.linear_velocity = vel
	return p


## Where the ball is held: in its mouth, just under and behind the nose.
func _mouth_point() -> Vector3:
	var nose := rig.nose_world() if rig and rig.skeleton else global_position + Vector3(0, 0.5, 0) * size
	return nose + global_basis.z * 0.025 * size - Vector3.UP * 0.05 * size


## How far ahead of its middle the ball is when its nose is on it (m).
func _mouth_reach() -> float:
	return 0.6 * size


# --- Moving --------------------------------------------------------------------------------

## The fenced lots whose gates it knows ([rect, gates] as WorldLayout has them): the
## garden lots, the barn's pen, the coop's.
static func _lots() -> Array:
	if _lot_list.is_empty():
		for lot: Dictionary in WorldLayout.FIELD_LOTS.values():
			_lot_list.append([lot["rect"], lot["gates"]])
		_lot_list.append([WorldLayout.BARN_PEN, [WorldLayout.BARN_GATE]])
		_lot_list.append([WorldLayout.COOP_PEN, [WorldLayout.COOP_GATE]])
	return _lot_list


## The way to `goal` past the fenced lots it knows. A lot's fence between them (one of them
## inside it, the other not, no clear line from its chest to there): by the lot's handiest
## gate, to GATE_OFF before it on its own side first, then straight through. A fenced lot
## it is not headed into in its way: round it by a corner, not in by one gate and out by
## the other. Else `goal`.
func _by_gate(goal: Vector3) -> Vector3:
	var me := Vector2(global_position.x, global_position.z)
	_via_gate = false
	var aim := _gate_aim(me, goal)
	var to := Vector2(aim.x, aim.z)
	for lot: Array in _lots():
		var rect: Rect2 = lot[0]
		if rect.has_point(me) or rect.has_point(to):
			continue
		var by := _round(rect, me, to)
		if by != to and _fenced(rect):
			_via_gate = true
			return Vector3(by.x, TerrainData.height(by.x, by.y), by.y)
	return aim


## `goal`, or the gate to go by first (_by_gate) from `me`.
func _gate_aim(me: Vector2, goal: Vector3) -> Vector3:
	var to := Vector2(goal.x, goal.z)
	for lot: Array in _lots():
		var rect: Rect2 = lot[0]
		var inside := rect.has_point(me)
		if inside == rect.has_point(to) or not _fenced(rect):
			continue
		var h := 0.28 * size + 0.08
		if not _ray(global_position + Vector3(0, h, 0), Vector3(goal.x, TerrainData.height(goal.x, goal.z) + h, goal.z)):
			return goal
		var best := goal
		var best_d := INF
		for gate: Array in lot[1]:
			var mid3 := WorldLayout.gate_point(rect, gate, 0.0)
			var mid := Vector2(mid3.x, mid3.z)
			var d := me.distance_to(mid) + to.distance_to(mid)
			if d >= best_d:
				continue
			best_d = d
			var mine := WorldLayout.gate_point(rect, gate, -GATE_OFF if inside else GATE_OFF)
			var far := WorldLayout.gate_point(rect, gate, GATE_OFF if inside else -GATE_OFF)
			# (How far to the side of the gate's middle it is, along the fence.)
			var out := (Vector2(mine.x, mine.z) - mid).normalized()
			var off := me - mid
			var aside := absf(off.x * out.y - off.y * out.x)
			var pick := far if aside < float(gate[2]) * 0.5 - GATE_EDGE - 0.15 * size else mine
			best = Vector3(pick.x, TerrainData.height(pick.x, pick.z), pick.z)
		_via_gate = best_d < INF
		return best
	return goal


## Whether the lot `rect` has its fence up (one not bought yet is open ground with a sign
## where its gate will be): felt for across its corner, at the height of its chest.
func _fenced(rect: Rect2) -> bool:
	var c := rect.position
	var y := TerrainData.height(c.x, c.y) + 0.28 * size + 0.08
	return _ray(Vector3(c.x - 0.7, y, c.y - 0.7), Vector3(c.x + 0.7, y, c.y + 0.7))


## From `a` to `b`, both outside the lot `rect`: `b`, or, the straight way cutting through
## the lot, the first corner (ROUND_OFF out from it) of the shorter way round it.
static func _round(rect: Rect2, a: Vector2, b: Vector2) -> Vector2:
	var hard := rect.grow(0.25)
	if hard.has_point(a) or hard.has_point(b) or not _cuts(hard, a, b):
		return b
	var soft := rect.grow(ROUND_OFF)
	var c: Array[Vector2] = [soft.position, Vector2(soft.end.x, soft.position.y), soft.end, Vector2(soft.position.x, soft.end.y)]
	var best := b
	var best_d := INF
	for i in 4:
		if _cuts(hard, a, c[i]):
			continue
		for dir: int in [1, -1]:
			# On round the lot from this corner, this way, to the first corner that sees `b`.
			var d := a.distance_to(c[i])
			var k := i
			for step in 4:
				if not _cuts(hard, c[k], b):
					d += c[k].distance_to(b)
					if d < best_d:
						best_d = d
						best = c[i]
					break
				var n := posmod(k + dir, 4)
				d += c[k].distance_to(c[n])
				k = n
	return best


## Whether the level stretch from `a` to `b` passes through `rect`.
static func _cuts(rect: Rect2, a: Vector2, b: Vector2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var lo := rect.position[axis]
		var hi := rect.end[axis]
		if absf(d[axis]) < 0.0001:
			if a[axis] <= lo or a[axis] >= hi:
				return false
			continue
		var ta := (lo - a[axis]) / d[axis]
		var tb := (hi - a[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 >= t1:
			return false
	return true


## Heads for `goal` at `speed`, feeling ahead for walls and fences (every PROBE seconds)
## and turning aside round them; round a parked vehicle in its way by the nearer corner
## (Vehicle.way_round: the guard in _move only stops it at the body, and straight behind
## the pickup it stood there instead of coming after the farmer).
func _steer(goal: Vector3, speed: float, delta: float) -> void:
	goal = Vehicle.way_round(global_position, goal, CAR_KEEP * size, CAR_BERTH)
	var to := _flat(goal - global_position)
	if to.length() < 0.03:
		_want_speed = 0.0
		return
	var dir := to.normalized()
	_probe_t -= delta
	if _probe_t <= 0.0:
		_probe_t = PROBE
		var reach := minf(to.length(), 0.9 * size + 0.5)
		if _clear(dir, reach):
			_detour = 0.0
		else:
			var found := false
			for a: float in [0.55, 1.1, 1.65, 2.2]:
				for sgn: float in [_detour_side, -_detour_side]:
					if _clear(dir.rotated(Vector3.UP, a * sgn), reach):
						_detour = a * sgn
						_detour_side = sgn
						found = true
						break
				if found:
					break
			if not found:
				_detour = PI * 0.5 * _detour_side
	if _stuck_t > 2.0:
		# Stuck against something: the other way round it.
		_detour_side = -_detour_side
		_stuck_t = 0.0
		_probe_t = 0.0
	var aim := goal if _detour == 0.0 else global_position + dir.rotated(Vector3.UP, _detour) * maxf(to.length(), 0.6)
	_head_to(aim, speed, delta)


## Nothing solid (walls, fences, the house: the world layer) within `reach` along `dir`,
## at the height of its chest, following the ground ahead.
func _clear(dir: Vector3, reach: float) -> bool:
	var h := 0.28 * size + 0.08
	var a := global_position + Vector3(0, h, 0)
	var b := global_position + dir * reach
	b.y = maxf(TerrainData.height(b.x, b.z), global_position.y - 0.3) + h
	return not _ray(a, b)


## Moves on at its speed (it gets up first) where nothing blocks it, on the ground.
func _move_pet(delta: float) -> void:
	var up := rig.sit_amount() < 0.05 and rig.lie_amount() < 0.05
	if not up and _want_speed > 0.05 and _camera_pos().distance_to(global_position) > ANIMATE_RANGE:
		# Sitting or lying too far off to be drawn moving (Dog._process leaves it be): it
		# gets up all the same (called from its stay, sent to its bed or home from it).
		_mood()
		rig.animate(delta, 0.0)
	# (After the ball and back with it, it is off the mark at once.)
	var quick := FETCH_ACCEL if task == &"fetch" or task == &"carry" else 1.0
	_speed = move_toward(_speed, _want_speed if up else 0.0, ACCEL * quick * delta)
	rotation.y = _yaw
	if _speed > 0.001:
		var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var step := fwd * _speed * delta
		# Never into a vehicle (its body would shove it): along its side, or stopped.
		var next := Vehicle.keep_out(global_position, global_position + step, CAR_KEEP * size)
		if _clear(fwd, 0.3 * size + 0.12 + step.length()) and _flat(next - global_position).length() > step.length() * 0.05:
			global_position = next
			_stuck_t = maxf(_stuck_t - delta, 0.0)
		else:
			_speed = 0.0
			_stuck_t += delta
			_probe_t = 0.0
	elif _want_speed > 0.05 and up:
		_stuck_t += delta * 0.5
	var h := _ground_at(global_position.x, global_position.z)
	_floor_y = h if absf(h - _floor_y) > 0.5 else lerpf(_floor_y, h, 1.0 - exp(-delta * 12.0))
	global_position.y = _floor_y


## The collider along its body at its size.
func _place_collider() -> void:
	if _shape == null or rig == null:
		return
	var s := rig.sit_amount() * (1.0 - rig.lie_amount())
	var l := rig.lie_amount()
	var pitch := lerpf(PI * 0.5, PI * 0.5 - 0.65, s)
	var y := lerpf(lerpf(0.4, 0.34, s), 0.2, l) * size
	_shape.transform = Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0, y, lerpf(0.02, 0.1, s) * size))


# --- How it looks ----------------------------------------------------------------------------

func _mood() -> void:
	super()
	var p := _player_pos()
	if is_carried():
		_mood_carried()
		return
	match task:
		&"follow", &"home":
			if _going or _speed > 0.3:
				rig.pose = DogRig.Pose.STAND
				rig.nose_down = 0.0
				rig.head_rest = false
				rig.wag = maxf(rig.wag, 0.6)
		&"bed":
			if _settled and _act == Act.LIE:
				rig.pose = DogRig.Pose.LIE
				rig.head_rest = _act_t > 3.0
				rig.wag = 0.0 if rig.head_rest else 0.3
				rig.look_at_point = Vector3.INF
			else:
				rig.pose = DogRig.Pose.STAND
		&"guard":
			rig.head_rest = false
			if _wolf != null and is_instance_valid(_wolf):
				rig.pose = DogRig.Pose.STAND
				rig.look_at_point = _wolf.global_position + Vector3(0, 0.5, 0)
				rig.wag = 0.0
				rig.panting = false
			elif _settled:
				rig.pose = DogRig.Pose.LIE
				rig.wag = 0.15
			else:
				rig.pose = DogRig.Pose.STAND
		&"come", &"carry", &"offer":
			if mode != &"greet":
				rig.pose = DogRig.Pose.STAND
				rig.nose_down = 0.0
				rig.head_rest = false
				if p.is_finite():
					rig.look_at_point = p + Vector3(0, 1.2, 0)
				rig.wag = 1.0
				rig.panting = true
		&"sit":
			rig.nose_down = 0.0
			rig.panting = false
			if stay and _act == Act.LIE:
				# Waiting, lying: its eyes on him; he far off a good while, its head on its paws.
				rig.pose = DogRig.Pose.LIE
				rig.head_rest = _stay_far > STAY_DOZE and not (p.is_finite() and _flat(p - global_position).length() < STAY_NEAR)
				rig.wag = 0.0 if rig.head_rest else 0.2
			else:
				rig.pose = DogRig.Pose.SIT
				rig.head_rest = false
				# (He comes back to it: its tail goes harder; he is off: only a little.)
				rig.wag = 1.0 if stay and _wag_t > 0.0 else (0.6 if not stay or _stay_far <= 0.0 else 0.35)
			rig.look_at_point = p + Vector3(0, 1.5, 0) if p.is_finite() and not rig.head_rest else Vector3.INF
		&"eat":
			rig.pose = DogRig.Pose.STAND
			rig.head_rest = false
			rig.nose_down = 1.0 if _settled else 0.0
			rig.chewing = _settled
			rig.wag = 0.5
			rig.panting = false
			# (Its eyes on its bowl on the way; in it, on nothing else.)
			rig.look_at_point = Vector3.INF if _settled else Pet.bowl_point()
		&"fetch":
			rig.pose = DogRig.Pose.STAND
			rig.head_rest = false
			rig.nose_down = 0.9 if _mouth_t > 0.0 else 0.0
			if ball and is_instance_valid(ball) and _mouth_t <= 0.0:
				rig.look_at_point = ball.global_position
			rig.wag = 0.9
		&"play":
			rig.pose = DogRig.Pose.STAND
			rig.head_rest = false
			rig.nose_down = 0.15
			rig.wag = 1.0
	if _beg_t > 0.0 and task == &"follow" and p.is_finite():
		# Asking for its dinner: up at him, ears back; then round at its bowl.
		rig.pose = DogRig.Pose.STAND
		rig.nose_down = 0.0
		rig.head_rest = false
		rig.ears_back = 0.6
		rig.wag = 0.35
		rig.look_at_point = p + Vector3(0, 1.4, 0) if _beg_t > BEG_TIME * 0.4 or not _beg_whined else Pet.bowl_point() + Vector3(0, 0.05, 0)
		return
	if _look_up > 0.0 and p.is_finite() and task != &"sit" and task != &"eat":
		rig.look_at_point = p + Vector3(0, 1.4, 0)
		rig.head_rest = false
		rig.wag = maxf(rig.wag, 0.7)


## In his arms, on the seat: sitting up, happy; its eyes about, on him, out of the window.
func _mood_carried() -> void:
	rig.pose = DogRig.Pose.SIT
	rig.nose_down = 0.0
	rig.head_rest = false
	rig.chewing = false
	rig.lean = 0.0
	rig.look_at_point = Vector3.INF
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if task == &"held":
		rig.wag = 0.85
		rig.ears_back = 0.6 if _gaze == 1 else 0.3
		rig.panting = _gaze == 1
		if _gaze == 1 and cam:
			# Up at his face (a little above the eyes he looks out of).
			rig.look_at_point = cam.global_position + cam.global_basis.y * 0.06
	else:
		rig.wag = 0.55
		rig.ears_back = 0.0
		rig.panting = true
		if _gaze == 1 and vehicle:
			rig.look_at_point = vehicle.driver_eye_global()
		elif _gaze == 2 and seat_across and vehicle:
			# Sitting across the seat: at the road ahead, out of the windscreen.
			rig.look_at_point = global_position + vehicle.global_basis.z * 4.0 - global_basis.z * 1.5 + Vector3(0, 0.4 * size, 0)
		elif _gaze == 2:
			# Out of its own window: off to the side it sits on, a little ahead.
			var side := global_basis.x * (1.0 if to_local(vehicle.global_position).x < 0.0 else -1.0) if vehicle else global_basis.x
			rig.look_at_point = global_position + side * 4.0 - global_basis.z * 2.0 + Vector3(0, 0.5 * size, 0)
