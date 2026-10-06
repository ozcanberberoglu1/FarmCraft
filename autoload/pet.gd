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
##     looking at it) and fetching a thrown ball (the market's "dog_ball", LMB) are learnt
##     by practice: the command (or the ball picked up) and a pat (E) within
##     PRACTICE_WINDOW seconds, need(skill) times (fewer with affection); fetching only
##     once it is FETCH_AGE days old (before that it plays with the ball and leaves it);
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
##     first command, bringing the ball back.

signal adopted(dog_name: String)
## It learnt a command (&"sit", &"fetch").
signal learned(skill: StringName)

const BALL := &"dog_ball"
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
## GameClock.total_minutes when it was left behind off the farm (-1: it wasn't).
var left_at := -1.0
## Its side goals (a doghouse, a ball, the first command, fetching).
var goals: DogGoals

## The body in the world (null while the farm is rebuilt or before adoption).
var dog: PetDog
## Its doghouse on the farm (the first finished one), null while it has only its bed.
var kennel: Doghouse
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	goals = DogGoals.new()
	goals.name = "DogGoals"
	add_child(goals)


func _process(delta: float) -> void:
	_since_pat += delta
	for k: StringName in _window.keys():
		_window[k] = float(_window[k]) - delta
		if float(_window[k]) <= 0.0:
			_window.erase(k)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if not has_pet or SaveGame.loading or Game.world == null or not is_instance_valid(Game.world) \
			or Game.player == null or not is_instance_valid(Game.player):
		return
	_find_kennel()
	if dog == null or not is_instance_valid(dog) or dog.is_queued_for_deletion():
		_build_bed()
		_spawn(_start_spot())
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
	if dog.global_position.distance_to(Game.player.global_position) > WHISTLE_RANGE:
		return false
	var heeded := _rng.randf() >= distract_chance()
	if heeded:
		whistles_heeded += 1
	else:
		whistles_missed += 1
	dog.whistled(heeded)
	return heeded


## F looking at it: "sit!". Learnt, it sits (and stays a while); not yet, it looks up at
## him wagging, and a pat now is a practice.
func command_sit() -> void:
	if dog == null:
		return
	if knows(&"sit"):
		dog.sit_down()
		return
	dog.puzzled()
	_window[&"sit"] = PRACTICE_WINDOW


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
	make_bouncy(p)
	p.linear_velocity = velocity
	if dog and is_instance_valid(dog):
		dog.chase(p)
	return p


## A ball lying about rolls and bounces like one (a sphere, not the pickup's box).
static func make_bouncy(p: Pickup) -> void:
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.7
	mat.rough = true
	p.physics_material_override = mat
	p.angular_damp = 0.8
	p.linear_damp = 0.15
	# Small and quick: swept, so it never tunnels through the ground.
	p.continuous_cd = true
	for c in p.get_children():
		if c is CollisionShape3D:
			var sphere := SphereShape3D.new()
			sphere.radius = 0.034
			(c as CollisionShape3D).shape = sphere


## The dog has the ball in its mouth: a pat soon is a practice; one that knows enough
## (and is old enough) has learnt to bring it back.
func ball_caught() -> void:
	# (Longer: he has to get to it, playing with the ball out where it landed.)
	_window[&"fetch"] = PRACTICE_WINDOW * 2.0
	if not knows(&"fetch") and int(practice[&"fetch"]) >= need(&"fetch") and age_days() >= FETCH_AGE:
		_learn(&"fetch")


func _practise(skill: StringName) -> void:
	if knows(skill):
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


# --- Save ----------------------------------------------------------------------------------

func new_game() -> void:
	load_data({})


func save_data() -> Dictionary:
	if not has_pet:
		return {}
	var d := {"name": dog_name, "at": adopted_at, "affection": affection,
		"practice": {"sit": int(practice[&"sit"]), "fetch": int(practice[&"fetch"])},
		"skills": {"sit": knows(&"sit"), "fetch": knows(&"fetch")}, "guard_told": guard_told,
		"goals": goals.save_data()}
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
	var out: Array = d.get("out", [])
	_out_at = Vector3(float(out[0]), float(out[1]), float(out[2])) if out.size() == 3 else Vector3.INF
	left_at = float(d.get("left", -1.0)) if _out_at.is_finite() else -1.0
	kennel = null
	goals.load_data(d.get("goals", {}))
	_window.clear()
	_check = 0.0
