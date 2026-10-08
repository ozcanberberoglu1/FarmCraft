extends Node
## The farmer's own dog: one of Karamel's pups, weaned, that Zeynep gives him (her
## story calls adopt). Its body in the world is a PetDog (spawned whenever the farm is
## built: at its doghouse or its bed at the farmhouse, or beside the farmer by day);
## everything about it that lasts is kept here and saved:
##   - its name (the farmer names it as it is given: PetNameScreen, "Fındık" unless he
##     types another), its age (game time since adoption; it grows from a pup of
##     PUPPY_SIZE to Karamel's size over GROW_DAYS) and its affection for him (petting it,
##     E: it learns faster the fonder it is);
##   - what it has learnt. Whistled for (H, whistle) it comes running from the first day,
##     though a young pup sometimes doesn't (DISTRACT_YOUNG, less as it grows). "Sit" (F
##     looking at it; learnt, it stays where it sits until he releases it: PetDog &"sit",
##     saved here with where it sits; the first time he walks away from it he is told it
##     waits and how it is called, `stay_told`) and fetching a thrown ball (the market's "dog_ball", LMB) are learnt
##     by practice: the command (or the ball picked up) and a pat (E) within
##     PRACTICE_WINDOW seconds, need(skill) times (fewer with affection); fetching only
##     once it is FETCH_AGE days old (before that it plays with the ball and leaves it).
##     The ball is never taken by walking near it: brought back it stays in the dog's
##     mouth (E pets the dog, which lets it drop; F takes it from it) and lying about it
##     is taken with E (Pickup, BALL); the first throw says so (`ball_told`). A ball left
##     out (lying about, in the dog's mouth) is saved with the game and lies there again
##     when it is loaded (`_balls_at`: pickups are not saved by themselves);
##   - grown to GUARD_AGE days it keeps watch by the animals at night (PetDog &"guard"):
##     on a raid night a bite about to land is stopped GUARD_SAVE of the time and the pack
##     leaves (WolfRaids._guard_foils), awake or asleep;
##   - where it is when it is not on the farm. G picks it up (AnimalHandler) and carried
##     into a vehicle it rides on the passenger seat, so it can be out with him; left
##     behind out there (he drove off, or walked away) it waits WAIT_MINUTES of game time
##     and then is home again (`left_at`; PetDog &"wait");
##   - its home on the farm: the doghouse put up from the construction board's kit
##     (Doghouse, `kennel`: it sleeps in it, waits by it); until one stands, a bed by the
##     farmhouse door;
##   - the quiet side goals that come with it (DogGoals, `goals`): a doghouse, a ball, the
##     first command, bringing the ball back; and feeding it, the first time it is hungry;
##   - its hunger and its food bowl. `hunger` goes from 0 (fed) to 1 (hungry) over
##     meal_minutes() of game time: a day for a grown dog, MEAL_MINUTES_PUP (18 hours) for
##     a new pup. Hungry, it eats a meal from its bowl by itself (PetDog &"eat": by day, on
##     the farm) and is fed again; the bowl empty, it comes to him whining now and then
##     and looks at its bowl, plays more slowly and takes no lesson ("aç karnına ders
##     olmaz"); it never falls ill, leaves or forgets anything, and it guards and follows
##     as ever. Out with him (in the pickup, in town, left there) its hunger stops short of
##     hungry (HUNGER_OUT): it eats when it is back. The bowl (DogBowl, `bowl`) stands by
##     its doghouse's door, or by its bed until there is one, and moves with them; E with
##     dog food (FOOD) in the bag pours a sack in: SACK_MEALS meals, the bowl holds
##     BOWL_MEALS (so a sack goes in once no more than one meal is left). A meal from the
##     bowl he filled makes it a little fonder of him (MEAL_AFFECTION). Hungry with an
##     empty bowl, he is told softly, at most once a game day (after the side goal).
##     Automated runs leave its hunger alone unless they ask (`--dog-hunger`, `hunger_testing`).

signal adopted(dog_name: String)
## It learnt a command (&"sit", &"fetch").
signal learned(skill: StringName)

const BALL := &"dog_ball"
## A saved ball is put back this high over where it lay (m).
const BALL_LIFT := 0.05
const SKILLS: Array[StringName] = [&"sit", &"fetch"]
## The pup's size against Karamel's (56 cm at the withers), its head and paws' (drawn
## bigger, DogRig.head_scale / paw_scale), and the game days it takes to grow up.
const PUPPY_SIZE := 0.52
const PUPPY_HEAD := 1.3
const PUPPY_PAWS := 1.3
const GROW_DAYS := 8.0
## Days old (since given) it can learn to bring a ball back, and keeps watch at night.
const FETCH_AGE := 2.0
const GUARD_AGE := 6.0
## Practices to learn a command at no affection (two fewer when it adores him), and the
## seconds after a command a pat counts as practice (twice that after picking the ball up).
const NEED := {&"sit": 5, &"fetch": 4}
const PRACTICE_WINDOW := 8.0
## Affection 0..100: a pat's worth (no more than one counted every PAT_GAP seconds), and
## where it starts.
const PAT_AFFECTION := 4.0
const PAT_GAP := 2.0
const START_AFFECTION := 20.0
## The chance a whistle goes unheeded (a pup with its nose in something), new and grown.
const DISTRACT_YOUNG := 0.4
const DISTRACT_GROWN := 0.03
## How far a whistle carries (m).
const WHISTLE_RANGE := 70.0
## The share of bites its barking stops on a raid night (WolfRaids).
const GUARD_SAVE := 0.5
## Where its bed goes (x, z): the first of these with nothing standing there (the
## farmhouse's front-west corner, by the warehouse; else beside it; else east of the
## house), and its turn (yaw).
const BED_SPOTS: Array[Vector2] = [Vector2(-21.3, -12.9), Vector2(-21.4, -11.1), Vector2(-7.2, -15.6)]
const BED_YAW := PI * 0.5
## Game minutes it waits where it was left off the farm before it goes home on its own.
const WAIT_MINUTES := 90.0
## Its food (the market's sack) and the meals in one; the meals its bowl holds.
const FOOD := &"dog_food"
const SACK_MEALS := 3
const BOWL_MEALS := 4
## Game minutes from fed to hungry: a new pup, a grown dog (in between as it grows).
const MEAL_MINUTES_PUP := 18.0 * 60.0
const MEAL_MINUTES_GROWN := 24.0 * 60.0
## Its hunger (0 fed .. 1 hungry) as it is given, in a save from before it had any, and
## where it stops while it is out with him; from PECKISH on its name tag says it is
## getting hungry.
const HUNGER_START := 0.3
const HUNGER_OLD_SAVE := 0.5
const HUNGER_OUT := 0.9
const PECKISH := 0.6
## Affection a meal from its bowl is worth.
const MEAL_AFFECTION := 3.0
## Seconds between two "no lessons on an empty stomach" lines.
const NO_LESSON_GAP := 20.0
## Where the bowl stands by the doghouse (its frame: left of the door, as the water bowl
## of its model is to the right), and the spots tried by the bed (x, z from its middle).
const BOWL_AT_KENNEL := Vector3(-0.775, 0.0, 0.835)
const BOWL_BY_BED: Array[Vector2] = [Vector2(1.0, 0.1), Vector2(0.1, 1.0), Vector2(-1.0, 0.1), Vector2(0.1, -1.0)]

## Saved.
var has_pet := false
var dog_name := ""
## GameClock.total_minutes when it was given.
var adopted_at := 0.0
var affection := 0.0
var practice := {&"sit": 0, &"fetch": 0}
var skills := {&"sit": false, &"fetch": false}
## The grown-up note was given (it guards from now on).
var guard_told := false
## The note on how the ball is taken up again was given (the first throw).
var ball_told := false
## The note that it waits where it was told to sit, and how it is called, was given.
var stay_told := false
## GameClock.total_minutes when it was left behind off the farm (-1: it wasn't).
var left_at := -1.0
## Its hunger: 0 fed .. 1 hungry.
var hunger := 0.0
## Meals in its bowl.
var bowl_meals := 0
## He has put food in its bowl (the side goal's end); the note on how the bowl works was
## given; the game day he was last told it is hungry and its bowl empty.
var fed_by_him := false
var bowl_told := false
var hungry_told_day := 0
## Its side goals (a doghouse, a ball, the first command, fetching; feeding).
var goals: DogGoals

## The body in the world (null while the farm is rebuilt or before adoption).
var dog: PetDog
## Its doghouse on the farm (the first finished one), null while it has only its bed.
var kennel: Doghouse
## Its food bowl in the world (by the doghouse, or by its bed).
var bowl: DogBowl
## Set by tests: its hunger is live in this automated run.
var hunger_testing := false
## Counters for tests: meals eaten from the bowl, lessons refused on an empty stomach.
var meals_eaten := 0
var lessons_refused := 0
## Counters for tests: whistles heeded and not.
var whistles_heeded := 0
var whistles_missed := 0

var _rng := RandomNumberGenerator.new()
## Seconds left on each skill's practice (a pat now counts), and since the last pat.
var _window := {}
var _since_pat := 99.0
var _naming: PetNameScreen
var _bed: Node3D
## The bed's spot on this build of the farm (BED_SPOTS).
var _bed_at := Vector2.INF
var _check := 0.0
## Loaded: where it was off the farm (INF: on the farm), until its body is out again.
var _out_at := Vector3.INF
## GameClock.total_minutes its hunger was last worked out at (-1: not yet).
var _hunger_at := -1.0
## Seconds until the next "no lessons on an empty stomach" line may be said.
var _no_lesson_wait := 0.0
## The bowl's spot by the bed (BOWL_BY_BED) and the bed it was chosen for.
var _bowl_off := Vector2.INF
var _bowl_bed := Vector2.INF
## Loaded while it sat and stayed: where (INF: it did not), its turn, the game minutes he
## had been off the farm (-1: he was not) and the seconds he had been away from its side,
## until its body is out again.
var _stay_at := Vector3.INF
var _stay_yaw := 0.0
var _stay_alone := -1.0
var _stay_far := 0.0
## Loaded: the balls that lay about when the game was saved ([x, y, z, how many]), until
## they lie in the world again.
var _balls_at: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	goals = DogGoals.new()
	goals.name = "DogGoals"
	add_child(goals)


func _process(delta: float) -> void:
	_since_pat += delta
	_no_lesson_wait = maxf(_no_lesson_wait - delta, 0.0)
	for k: StringName in _window.keys():
		_window[k] = float(_window[k]) - delta
		if float(_window[k]) <= 0.0:
			_window.erase(k)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if SaveGame.loading or Game.world == null or not is_instance_valid(Game.world) or not Game.world.is_inside_tree() \
			or Game.player == null or not is_instance_valid(Game.player):
		return
	if not _balls_at.is_empty():
		_put_balls_back()
	if not has_pet:
		return
	_find_kennel()
	if dog == null or not is_instance_valid(dog) or dog.is_queued_for_deletion():
		_build_bed()
		if _stay_at.is_finite():
			# It sat and stayed when the game was saved: there again, waiting.
			var at := _stay_at
			_stay_at = Vector3.INF
			_out_at = Vector3.INF
			_spawn(at)
			dog.resume_stay(_stay_yaw, _stay_alone, _stay_far)
		else:
			_spawn(_start_spot())
	_place_bowl()
	_tick_hunger()
	_remind_hungry()
	if not guard_told and guards():
		guard_told = true
		Game.notify(tr("MSG_PET_GROWN") % dog_name, Color(0.95, 0.8, 0.5))


# --- The contract --------------------------------------------------------------------------

## Zeynep gives the farmer the pup: named `pet_name`, or (none given) by him in a small
## prompt (PetNameScreen) with "Fındık" in it. It appears beside him.
func adopt(pet_name: String = "") -> void:
	if has_pet:
		return
	if pet_name.strip_edges() != "":
		_finish_adopt(pet_name)
		return
	if Game.hud == null:
		_finish_adopt(default_name())
		return
	if _naming == null or not is_instance_valid(_naming):
		_naming = PetNameScreen.new()
		_naming.named.connect(_finish_adopt)
		Game.hud.add_child(_naming)
	_naming.open(default_name())


func has_dog() -> bool:
	return has_pet


func default_name() -> String:
	return tr("PET_DEFAULT_NAME")


## Days since it was given (fractions by the minute).
func age_days() -> float:
	return maxf(GameClock.total_minutes - adopted_at, 0.0) / float(GameClock.MINUTES_PER_DAY) if has_pet else 0.0


## How grown it is 0 (just weaned) .. 1 (grown), quickest at first.
func growth() -> float:
	var t := clampf(age_days() / GROW_DAYS, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 1.5)


## Its size against Karamel's.
func size() -> float:
	return lerpf(PUPPY_SIZE, 1.0, growth())


## It was left behind off the farm just now (PetDog): its wait begins.
func note_left() -> void:
	if left_at < 0.0:
		left_at = GameClock.total_minutes


## Left off the farm, it has waited long enough (PetDog sends it home).
func wait_over() -> bool:
	return left_at >= 0.0 and GameClock.total_minutes - left_at >= WAIT_MINUTES


## It went home on its own after waiting (PetDog): the farmer is told where it is.
func note_home() -> void:
	left_at = -1.0
	Game.notify(tr("MSG_PET_WENT_HOME") % dog_name, Color(0.95, 0.8, 0.5))


## Grown enough to keep watch at night (WolfRaids asks).
func guards() -> bool:
	return has_pet and age_days() >= GUARD_AGE


func knows(skill: StringName) -> bool:
	return bool(skills.get(skill, false))


## Practices `skill` takes: fewer the fonder it is of him.
func need(skill: StringName) -> int:
	return maxi(int(NEED.get(skill, 4)) - int(affection / 40.0), 2)


## The chance a whistle goes unheeded now.
func distract_chance() -> float:
	return lerpf(DISTRACT_YOUNG, DISTRACT_GROWN, growth())


# --- Commands ------------------------------------------------------------------------------

## H: the farmer whistles. Within earshot the dog comes running (now and then a pup
## doesn't). Returns whether it came.
func whistle() -> bool:
	if Game.player:
		Audio.play("whistle", null, -7.0, 0.03)
	if dog == null or not is_instance_valid(dog) or Game.player == null:
		return false
	# (A dog told to sit waits for just this: it hears him anywhere on the farm and never
	# has its nose in something else.)
	var waiting := dog.is_staying()
	if dog.global_position.distance_to(Game.player.global_position) > (WorldLayout.VALLEY_RADIUS * 2.0 if waiting else WHISTLE_RANGE):
		return false
	var heeded := waiting or _rng.randf() >= distract_chance()
	if heeded:
		whistles_heeded += 1
	else:
		whistles_missed += 1
	dog.whistled(heeded)
	return heeded


## F looking at it: "sit!". Learnt, it sits and stays there until he releases it (F again
## is "up!"); not yet, it looks up at him wagging, and a pat now is a practice.
func command_sit() -> void:
	if dog == null:
		return
	if knows(&"sit"):
		if dog.is_staying():
			dog.release()
		else:
			dog.sit_down()
		return
	if hungry():
		# No lesson on an empty stomach: it only looks up at him and whines.
		dog.refuse_lesson()
		_no_lesson()
		return
	dog.puzzled()
	_window[&"sit"] = PRACTICE_WINDOW


## The first time he walks away from it sitting (PetDog): it waits there, and how it is
## called (the keys by their names in the input map).
func stay_note() -> void:
	# (Not from a body on its way out as a game is loaded.)
	if stay_told or not has_pet or dog == null or not is_instance_valid(dog) or dog.is_queued_for_deletion():
		return
	stay_told = true
	Game.notify(tr("MSG_PET_STAY_HOWTO") % [dog_name, key_name(&"whistle"), key_name(&"interact"), key_name(&"animal_info")], Color(0.85, 0.85, 0.8))


## He has been off the farm long enough for it to get up from its stay and go home
## (PetDog): he is told where it is.
func stay_given_up() -> void:
	if not has_pet or dog == null or not is_instance_valid(dog) or dog.is_queued_for_deletion():
		return
	Game.notify(tr("MSG_PET_STAY_OVER") % dog_name, Color(0.95, 0.8, 0.5))


## The name of the key `action` is on (the input map's first key; "" if it has none).
func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k:
			return OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	return ""


## E: a pat. It loves him a little more; a command (or the ball) just before makes it a
## practice.
func pat() -> void:
	if dog == null:
		return
	dog.petted_by(Game.player)
	if _since_pat >= PAT_GAP:
		affection = minf(affection + PAT_AFFECTION, 100.0)
	_since_pat = 0.0
	for skill: StringName in SKILLS:
		if _window.has(skill):
			_window.erase(skill)
			_practise(skill)


## The farmer threw the ball (Player._throw_ball): a ball flying from `from` at
## `velocity`, bouncing and rolling where it lands; the dog goes after it.
func ball_thrown(from: Vector3, velocity: Vector3, stack: ItemStack) -> Pickup:
	var p := Pickup.spawn(stack, from)
	p.linear_velocity = velocity
	if dog and is_instance_valid(dog):
		dog.chase(p)
	if not ball_told:
		# The first throw: how the ball comes back into the bag (never by itself).
		ball_told = true
		Game.notify(tr("MSG_BALL_HOWTO"), Color(0.85, 0.85, 0.8))
	return p


## A ball lying about for the farmer to take (not the one the dog is after); null: none.
func ball_lying() -> Pickup:
	for n in get_tree().get_nodes_in_group(&"pickups"):
		var p := n as Pickup
		if p and p.is_ball and not p.is_queued_for_deletion() and not (dog != null and is_instance_valid(dog) and dog.ball == p):
			return p
	return null


## The balls out in the world, to save: each one lying about ([x, y, z, how many]) and the
## one in the dog's mouth (at its feet); those of a loaded game not put back yet.
func _balls_out() -> Array:
	var out: Array = _balls_at.duplicate()
	for n in get_tree().get_nodes_in_group(&"pickups"):
		var p := n as Pickup
		if p and p.is_ball and p.is_inside_tree() and not p.is_queued_for_deletion() and p.stack != null and out.size() < 12:
			var at := p.global_position
			out.append([at.x, at.y, at.z, p.stack.count])
	if dog != null and is_instance_valid(dog) and dog.is_inside_tree() and dog.holding_ball and out.size() < 12:
		var at := dog.global_position
		out.append([at.x, at.y + BALL_LIFT, at.z, 1])
	return out


## The balls that lay about when the game was saved lie there again.
func _put_balls_back() -> void:
	var balls := _balls_at
	_balls_at = []
	for b: Variant in balls:
		if not (b is Array) or (b as Array).size() < 4:
			continue
		var a: Array = b
		var stack := ItemStack.create(BALL, clampi(int(a[3]), 1, 5))
		if stack == null:
			continue
		var x := float(a[0])
		var z := float(a[2])
		Pickup.spawn(stack, Vector3(x, maxf(float(a[1]), TerrainData.height(x, z)) + BALL_LIFT, z))


## The dog has the ball in its mouth: a pat soon is a practice; one that knows enough
## (and is old enough) has learnt to bring it back.
func ball_caught() -> void:
	if hungry() and not knows(&"fetch"):
		# Hungry, it plays with the ball a little but takes no lesson.
		_no_lesson()
		return
	# (Longer: he has to get to it, playing with the ball out where it landed.)
	_window[&"fetch"] = PRACTICE_WINDOW * 2.0
	if not knows(&"fetch") and int(practice[&"fetch"]) >= need(&"fetch") and age_days() >= FETCH_AGE:
		_learn(&"fetch")


func _practise(skill: StringName) -> void:
	if knows(skill):
		return
	if hungry():
		_no_lesson()
		return
	var n := int(practice.get(skill, 0)) + 1
	practice[skill] = n
	var goal := need(skill)
	if n >= goal and (skill != &"fetch" or age_days() >= FETCH_AGE):
		_learn(skill)
		return
	var key := "MSG_PET_LEARN_SIT" if skill == &"sit" else "MSG_PET_LEARN_FETCH"
	Game.notify(tr(key) % [dog_name, mini(n, goal), goal], Color(0.95, 0.85, 0.6))
	if n >= goal:
		# Taught, but too young yet to bring it back: it will once it is older.
		Game.notify(tr("MSG_PET_FETCH_YOUNG") % dog_name, Color(0.95, 0.85, 0.6))


func _learn(skill: StringName) -> void:
	skills[skill] = true
	practice[skill] = maxi(int(practice.get(skill, 0)), need(skill))
	var key := "MSG_PET_LEARNED_SIT" if skill == &"sit" else "MSG_PET_LEARNED_FETCH"
	Game.notify(tr(key) % dog_name, Color(0.6, 0.95, 0.6))
	Audio.ui("confirm", -6.0)
	learned.emit(skill)


# --- In the world --------------------------------------------------------------------------

func _finish_adopt(pet_name: String) -> void:
	if has_pet:
		return
	var n := pet_name.strip_edges().left(18)
	has_pet = true
	dog_name = n if n != "" else default_name()
	adopted_at = GameClock.total_minutes
	affection = START_AFFECTION
	practice = {&"sit": 0, &"fetch": 0}
	skills = {&"sit": false, &"fetch": false}
	guard_told = false
	left_at = -1.0
	_out_at = Vector3.INF
	_stay_at = Vector3.INF
	hunger = HUNGER_START
	bowl_meals = 0
	fed_by_him = false
	bowl_told = false
	hungry_told_day = 0
	_hunger_at = -1.0
	goals.load_data({})
	if Game.world and Game.player and is_instance_valid(Game.player):
		var p := Game.player as Node3D
		var side := p.global_basis.x
		var fwd := -p.global_basis.z
		_spawn(p.global_position + fwd * 1.6 + side * 0.6)
		dog.look_toward(p.global_position)
	Game.notify(tr("MSG_PET_ADOPTED") % dog_name, Color(0.95, 0.8, 0.5))
	Game.notify(tr("MSG_PET_HOWTO"), Color(0.85, 0.85, 0.8))
	Game.notify(tr("MSG_PET_CARRY_HOWTO"), Color(0.85, 0.85, 0.8))
	adopted.emit(dog_name)


## Where it is when the farm is built: where it was off the farm (out with him, or left
## there and still waiting); else beside the farmer by day on the farm, else at its
## doghouse (its bed).
func _start_spot() -> Vector3:
	if _out_at.is_finite():
		var at := _out_at
		_out_at = Vector3.INF
		if not wait_over():
			return at
		left_at = -1.0
	var p := Game.player as Node3D
	var h := GameClock.get_hour_float()
	var night := h >= PetDog.NIGHT_FROM or h < PetDog.NIGHT_TO
	if not night and p and PetDog.on_farm(p.global_position):
		return p.global_position + p.global_basis.x * 1.5 - p.global_basis.z * 1.2
	return bed_point() if night else home_point()


func _spawn(at: Vector3) -> void:
	if dog and is_instance_valid(dog):
		dog.queue_free()
	_build_bed()
	dog = PetDog.new()
	dog.position = Vector3(at.x, TerrainData.height(at.x, at.z), at.z)
	# (Loaded where it was off the farm: out with him, or left there.)
	dog.out_with_him = not PetDog.on_farm(at)
	Game.world.add_child(dog)
	dog.grow()


## Where it sleeps: in its doghouse, just inside the door; else the bed's middle on the ground.
func bed_point() -> Vector3:
	if kennel != null:
		return kennel.sleep_point(size())
	var s := _bed_at if _bed_at.is_finite() else BED_SPOTS[0]
	return Vector3(s.x, TerrainData.height(s.x, s.y), s.y)


## Where it waits for him at the farm: its doghouse's doorstep, or its bed.
func home_point() -> Vector3:
	return kennel.porch_point() if kennel != null else bed_point()


## Looks for its doghouse (the first finished one on the farm). When one comes to stand
## the bed by the farmhouse goes, and the dog takes to its new place.
func _find_kennel() -> void:
	var found: Doghouse = null
	for n in get_tree().get_nodes_in_group(Doghouse.GROUP):
		var k := n as Doghouse
		if k and k.is_built() and k.is_inside_tree() and not k.is_queued_for_deletion():
			found = k
			break
	if kennel != null and not is_instance_valid(kennel):
		kennel = null
	if found == kennel:
		return
	kennel = found
	_home_moved()


## A doghouse is leaving the farm (picked up again): at once, so nothing asks it anything.
func kennel_gone(k: Doghouse) -> void:
	if kennel != k:
		return
	kennel = null
	_home_moved.call_deferred()


func _home_moved() -> void:
	if not has_pet or Game.world == null or not is_instance_valid(Game.world) or not Game.world.is_inside_tree():
		return
	_build_bed()
	if dog and is_instance_valid(dog) and dog.task in [&"home", &"bed"]:
		dog._set_task(dog.task)


## The first of BED_SPOTS with nothing solid (a wall, a bin, a crate) on its ground.
func _pick_bed_spot() -> Vector2:
	var space := Game.world.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.5, 1.4)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = 1 | 4
	for s in BED_SPOTS:
		q.transform = Transform3D(Basis(), Vector3(s.x, TerrainData.height(s.x, s.y) + 0.45, s.y))
		if space.intersect_shape(q, 1).is_empty():
			return s
	return BED_SPOTS[0]


## Its bed by the farmhouse: a round cushion in a stuffed bolster, worn and warm.
func _build_bed() -> void:
	if kennel != null:
		# It has a doghouse now: the old bed by the door is taken away.
		var old := Game.world.get_node_or_null("PetBed") as Node3D
		if old:
			old.free()
		_bed = null
		return
	if _bed and is_instance_valid(_bed) and _bed.is_inside_tree():
		return
	var existing := Game.world.get_node_or_null("PetBed") as Node3D
	if existing:
		_bed = existing
		_bed_at = Vector2(existing.global_position.x, existing.global_position.z)
		return
	_bed_at = _pick_bed_spot()
	_bed = Node3D.new()
	_bed.name = "PetBed"
	_bed.position = bed_point()
	_bed.rotation.y = BED_YAW
	Game.world.add_child(_bed)
	var mb := MeshBuilder.new()
	var bolster := Color(0.36, 0.22, 0.15)
	var cushion := Color(0.6, 0.5, 0.39)
	var R := 0.5
	var ring: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 33:
		var a := TAU * float(i) / 32.0
		ring.append(Vector3(cos(a) * R, 0.085, sin(a) * R * 0.86))
		radii.append(0.085)
	mb.loft(&"cloth", ring, radii, 12, bolster)
	mb.cylinder(&"cloth", Transform3D.IDENTITY, R * 0.98, R * 0.98, 0.03, 32, bolster.darkened(0.2))
	mb.sphere(&"cloth", Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.86)), Vector3(0, 0.03, 0)),
			Vector3(R * 0.86, 0.045, R * 0.86), 28, 8, cushion)
	var mi := MeshInstance3D.new()
	mi.name = "Bed"
	mi.mesh = mb.build()
	mi.visibility_range_end = 70.0
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_bed.add_child(mi)


# --- Hunger and the bowl ---------------------------------------------------------------------

## Whether its hunger is live (automated runs leave it alone unless they ask).
func hunger_enabled() -> bool:
	return hunger_testing or not DebugTools.is_automated() or DebugTools.args.has("dog-hunger")


## Game minutes from fed to hungry at its age.
func meal_minutes() -> float:
	return lerpf(MEAL_MINUTES_PUP, MEAL_MINUTES_GROWN, growth())


## Really hungry: it wants its bowl.
func hungry() -> bool:
	return has_pet and hunger_enabled() and hunger >= 1.0


## How it is, for its name tag: fed, getting hungry, hungry ("" while its hunger is off).
func mood_text() -> String:
	if not has_pet or not hunger_enabled():
		return ""
	if hunger >= 1.0:
		return tr("PET_MOOD_HUNGRY")
	return tr("PET_MOOD_PECKISH") if hunger >= PECKISH else tr("PET_MOOD_FED")


## Its bowl's level as a line of text: "Dog food: 75% · 3 meals".
func bowl_text() -> String:
	return tr("PET_BOWL_LEVEL") % [roundi(float(bowl_meals) / float(BOWL_MEALS) * 100.0), bowl_meals]


## Room in the bowl for a whole sack.
func bowl_has_room() -> bool:
	return bowl_meals + SACK_MEALS <= BOWL_MEALS


func can_fill_bowl() -> bool:
	return has_pet and bowl_has_room() and PlayerState.inventory.has_item(FOOD)


## E at the bowl: a sack of dog food from the bag into it. Returns whether one went in.
func fill_bowl() -> bool:
	if not can_fill_bowl():
		return false
	PlayerState.inventory.remove_item(FOOD, 1)
	bowl_meals += SACK_MEALS
	fed_by_him = true
	if bowl != null and is_instance_valid(bowl):
		bowl.refresh()
		Audio.action_done("fill_feed", bowl.global_position + Vector3(0, 0.1, 0))
	Game.notify(tr("MSG_BOWL_FILLED") % bowl_meals)
	if not bowl_told:
		# The first sack: how the bowl works from here on.
		bowl_told = true
		Game.notify(tr("MSG_BOWL_HOWTO") % [dog_name, SACK_MEALS], Color(0.85, 0.85, 0.8))
	goals.update()
	return true


## The dog has eaten a meal from its bowl (PetDog): fed, and a little fonder of him.
## Returns whether there was one.
func meal_eaten() -> bool:
	if bowl_meals <= 0:
		return false
	bowl_meals -= 1
	hunger = 0.0
	meals_eaten += 1
	affection = minf(affection + MEAL_AFFECTION, 100.0)
	if bowl != null and is_instance_valid(bowl):
		bowl.refresh()
	return true


## Its hunger over the game time since it was last worked out (sleeping through a night
## counts like any other time). Out with him it stops short of hungry.
func _tick_hunger() -> void:
	var now := GameClock.total_minutes
	if _hunger_at < 0.0 or now < _hunger_at:
		_hunger_at = now
		return
	var passed := now - _hunger_at
	_hunger_at = now
	if passed <= 0.0 or not hunger_enabled():
		return
	var top := HUNGER_OUT if _dog_out() else 1.0
	if hunger < top:
		hunger = minf(hunger + passed / meal_minutes(), top)


## Out with him off the farm (riding along, carried, following him there, left there).
func _dog_out() -> bool:
	if dog == null or not is_instance_valid(dog) or not dog.is_inside_tree():
		return _out_at.is_finite()
	return dog.out_with_him or dog.task == &"wait" or not PetDog.on_farm(dog.global_position)


## Hungry with an empty bowl: he is told softly, once a game day at most, when it is with
## him on the farm (it comes to him whining as he reads it). Not while the side goal that
## teaches it is still to come or up (its card says so).
func _remind_hungry() -> void:
	if not hungry() or bowl_meals > 0 or hungry_told_day == GameClock.day:
		return
	if goals.enabled() and not goals.done.has(DogGoals.FEED):
		return
	if dog == null or not is_instance_valid(dog) or dog.task != &"follow" or dog.out_with_him:
		return
	hungry_told_day = GameClock.day
	Game.notify(tr("MSG_PET_HUNGRY") % dog_name, Color(0.95, 0.85, 0.6))
	dog.beg()


## "No lessons on an empty stomach", not said over and over.
func _no_lesson() -> void:
	lessons_refused += 1
	if _no_lesson_wait > 0.0:
		return
	_no_lesson_wait = NO_LESSON_GAP
	Game.notify(tr("MSG_PET_NO_LESSON") % dog_name, Color(0.95, 0.85, 0.6))


## Where its bowl stands, on the ground: by the doghouse's door, else by its bed.
func bowl_point() -> Vector3:
	if kennel != null:
		var k := kennel.global_transform * BOWL_AT_KENNEL
		return Vector3(k.x, TerrainData.height(k.x, k.z), k.z)
	var bed := bed_point()
	var off := _bowl_off if _bowl_off.is_finite() else BOWL_BY_BED[0]
	return Vector3(bed.x + off.x, TerrainData.height(bed.x + off.x, bed.z + off.y), bed.z + off.y)


## The way from the bowl to where the dog stands to eat (level, one metre): out in front
## of the doghouse; by the bed, away from it.
func bowl_front() -> Vector3:
	var dir := kennel.global_basis.z if kennel != null else bowl_point() - bed_point()
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3(1, 0, 0)


## Where a dog whose nose reaches `reach` m ahead of its middle stands to eat from it.
func bowl_stand(reach: float) -> Vector3:
	var p := bowl_point() + bowl_front() * reach
	return Vector3(p.x, TerrainData.height(p.x, p.z), p.z)


## The first of BOWL_BY_BED where the bowl and the dog eating from it stand clear.
func _pick_bowl_spot(bed: Vector3) -> Vector2:
	var space := Game.world.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.28
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = 1 | 4
	if bowl != null and is_instance_valid(bowl):
		q.exclude = [bowl.get_rid()]
	for off in BOWL_BY_BED:
		var clear := true
		for k: float in [1.0, 1.75]:
			var x := bed.x + off.x * k
			var z := bed.z + off.y * k
			q.transform = Transform3D(Basis(), Vector3(x, TerrainData.height(x, z) + 0.4, z))
			if not space.intersect_shape(q, 1).is_empty():
				clear = false
				break
		if clear:
			return off
	return BOWL_BY_BED[0]


## Keeps its bowl in the world and with its home (the doghouse's door, else its bed).
func _place_bowl() -> void:
	if Game.world == null or not is_instance_valid(Game.world) or not Game.world.is_inside_tree():
		return
	if bowl == null or not is_instance_valid(bowl) or not bowl.is_inside_tree():
		bowl = Game.world.get_node_or_null("PetBowl") as DogBowl
		if bowl == null:
			bowl = DogBowl.new()
			Game.world.add_child(bowl)
			bowl.global_position = Vector3(0.0, -50.0, 0.0)
	if kennel == null and (not _bowl_off.is_finite() or _bowl_bed != _bed_at):
		_bowl_bed = _bed_at
		_bowl_off = _pick_bowl_spot(bed_point())
	var at := bowl_point()
	if bowl.global_position.distance_to(at) > 0.01:
		bowl.global_position = at
		bowl.rotation.y = kennel.global_rotation.y if kennel != null else 0.0
		bowl.reset_physics_interpolation()
	bowl.refresh()


# --- Save ----------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	var balls := _balls_out()
	if not has_pet:
		return {"balls": balls} if not balls.is_empty() else {}
	var d := {"name": dog_name, "at": adopted_at, "affection": affection,
		"practice": {"sit": int(practice[&"sit"]), "fetch": int(practice[&"fetch"])},
		"skills": {"sit": knows(&"sit"), "fetch": knows(&"fetch")}, "guard_told": guard_told, "ball_told": ball_told,
		"hunger": hunger, "bowl": bowl_meals, "fed": fed_by_him, "bowl_told": bowl_told, "hungry_told": hungry_told_day,
		"stay_told": stay_told, "goals": goals.save_data()}
	if not balls.is_empty():
		d["balls"] = balls
	if dog != null and is_instance_valid(dog) and dog.is_inside_tree() and dog.is_staying():
		# Told to sit and waiting: where, its turn, the game minutes he has been off the
		# farm and the seconds he has been away from its side.
		var at := dog.global_position
		d["stay"] = [at.x, at.y, at.z, dog.rotation.y, dog.stay_alone_minutes(), dog.stay_far_seconds()]
	elif _stay_at.is_finite():
		d["stay"] = [_stay_at.x, _stay_at.y, _stay_at.z, _stay_yaw, _stay_alone, _stay_far]
	var out := _out_spot()
	if out.is_finite():
		d["out"] = [out.x, out.y, out.z]
		d["left"] = left_at
	return d


## Where it is off the farm, to save (INF: on the farm). In his arms or on the seat it is
## put beside where he will stand.
func _out_spot() -> Vector3:
	if dog == null or not is_instance_valid(dog) or not dog.is_inside_tree():
		return _out_at
	var at := dog.global_position
	var p := Game.player as Player
	if dog.task == &"ride" and dog.vehicle != null and is_instance_valid(dog.vehicle):
		var spot := dog.vehicle.exit_point()
		var off := spot - dog.vehicle.global_position
		off.y = 0.0
		at = spot + off.normalized() * 0.8
	elif dog.task == &"held" and p != null and is_instance_valid(p):
		at = p.global_position + p.global_basis.x * 0.9
	elif not dog.out_with_him:
		return Vector3.INF
	return at if not PetDog.on_farm(at) else Vector3.INF


func load_data(d: Dictionary) -> void:
	if dog and is_instance_valid(dog):
		dog.queue_free()
	dog = null
	has_pet = d.has("name")
	dog_name = String(d.get("name", ""))
	adopted_at = float(d.get("at", 0.0))
	affection = float(d.get("affection", 0.0))
	var p: Dictionary = d.get("practice", {})
	var s: Dictionary = d.get("skills", {})
	practice = {&"sit": int(p.get("sit", 0)), &"fetch": int(p.get("fetch", 0))}
	skills = {&"sit": bool(s.get("sit", false)), &"fetch": bool(s.get("fetch", false))}
	guard_told = bool(d.get("guard_told", false))
	ball_told = bool(d.get("ball_told", false))
	stay_told = bool(d.get("stay_told", false))
	var lay: Variant = d.get("balls", [])
	_balls_at = (lay as Array).duplicate() if lay is Array else []
	var stay: Array = d.get("stay", [])
	_stay_at = Vector3(float(stay[0]), float(stay[1]), float(stay[2])) if stay.size() == 6 and has_pet else Vector3.INF
	_stay_yaw = float(stay[3]) if stay.size() == 6 else 0.0
	_stay_alone = float(stay[4]) if stay.size() == 6 else -1.0
	_stay_far = float(stay[5]) if stay.size() == 6 else 0.0
	# (A save from before it had any hunger: half way to its next meal, an empty bowl.)
	hunger = clampf(float(d.get("hunger", HUNGER_OLD_SAVE if has_pet else 0.0)), 0.0, 1.0)
	bowl_meals = clampi(int(d.get("bowl", 0)), 0, BOWL_MEALS)
	fed_by_him = bool(d.get("fed", false))
	bowl_told = bool(d.get("bowl_told", false))
	hungry_told_day = int(d.get("hungry_told", 0))
	_hunger_at = -1.0
	_no_lesson_wait = 0.0
	if bowl != null and is_instance_valid(bowl):
		if has_pet:
			bowl.refresh()
		else:
			# (Out of the way at once: a new dog's bowl is looked up by its name.)
			bowl.name = "PetBowlGone"
			bowl.queue_free()
			bowl = null
	var out: Array = d.get("out", [])
	_out_at = Vector3(float(out[0]), float(out[1]), float(out[2])) if out.size() == 3 else Vector3.INF
	left_at = float(d.get("left", -1.0)) if _out_at.is_finite() else -1.0
	kennel = null
	goals.load_data(d.get("goals", {}))
	_window.clear()
	_check = 0.0
