@tool
class_name AnimalRig
extends Node3D
## A sculpted, skinned animal model plus its procedural animation: walk and trot
## gaits (feet set down on the ground and held there, legs placed by IK, see
## _update_gait and _place_legs), grazing, eating at a trough, lying down, ear flicks,
## tail swishes and idle head movement. Drives Skeleton3D bone poses.

enum Mode { IDLE, WALK, GRAZE, EAT, SLEEP, RUN }

## Gait per species: `stride` metres per cycle (every foot one step) at `walk_speed` m/s
## (full size; faster, the strides lengthen and quicken, see _gait_rate); `duty` the
## share of the cycle a foot is down walking; `lift_f`/`lift_h` how high a front/hind foot
## is lifted, share of the leg's length; `trot_at` the speed a four-legged one trots from.
const PARAMS := {
	&"cow": {"stride": 0.95, "walk_speed": 0.8, "duty": 0.65, "lift_f": 0.1, "lift_h": 0.09, "trot_at": 1.5,
		"neck_down": 0.5, "head_down": 0.35, "lie_drop": 0.52, "baby_scale": 0.52, "hip_height": 1.0},
	&"horse": {"stride": 1.3, "walk_speed": 1.1, "duty": 0.62, "duty_trot": 0.3, "stride_exp": 0.5, "shift_f": 0.2, "lift_f": 0.15, "lift_h": 0.1, "trot_at": 1.9,
		"neck_down": 0.62, "head_down": 0.3, "lie_drop": 0.62, "baby_scale": 0.55, "hip_height": 1.08},
	&"sheep": {"stride": 0.55, "walk_speed": 0.75, "duty": 0.63, "lift_f": 0.15, "lift_h": 0.11, "trot_at": 1.2,
		"neck_down": 0.75, "head_down": 0.35, "lie_drop": 0.26, "baby_scale": 0.5, "hip_height": 0.45},
	&"chicken": {"stride": 0.26, "walk_speed": 0.8, "duty": 0.6, "lift_f": 0.2, "neck_down": 1.0, "head_down": 0.5,
		"lie_drop": 0.1, "baby_scale": 0.42, "hip_height": 0.2, "biped": true},
	&"rooster": {"stride": 0.3, "walk_speed": 0.85, "duty": 0.6, "lift_f": 0.2, "neck_down": 1.0, "head_down": 0.5,
		"lie_drop": 0.1, "baby_scale": 0.42, "hip_height": 0.22, "biped": true, "faint_drop": 0.17},
	# The downy chick (its own model, PhotoRig.MODELS): quick little steps, a big nod.
	&"chick": {"stride": 0.05, "walk_speed": 0.5, "duty": 0.5, "lift_f": 0.22, "neck_down": 0.9, "head_down": 0.6,
		"lie_drop": 0.018, "baby_scale": 1.0, "hip_height": 0.036, "biped": true},
}
const SCULPT_PATH := "res://art/models/animals/%s.scn"
## Lying down: [upper, lower, foot] joint angles (front, rear, birds) unless cfg overrides them.
const FOLD_FRONT := [-1.3, 2.45, 0.4]
const FOLD_REAR := [1.1, -2.1, -0.4]
const FOLD_BIPED := [-1.1, 1.9, 0.4]
## When each foot is set down, share of the gait cycle (l/r; f/r front and hind, a bird's
## two legs are f): walking the lateral sequence (left hind, left fore, right hind, right
## fore), trotting in diagonal pairs.
const TOUCH_WALK := {"rl": 0.0, "fl": 0.22, "rr": 0.5, "fr": 0.72}
const TOUCH_TROT := {"rl": 0.0, "fl": 0.5, "rr": 0.5, "fr": 1.0}
const TOUCH_BIRD := {"fl": 0.0, "fr": 0.5}
## Share of the cycle a foot is down trotting (PARAMS duty_trot; stride_exp how strides
## lengthen with speed, stride ~ speed^stride_exp).
const DUTY_TROT := 0.42
## Leg IK chains: two bones; three with the last kept at its angle to the first (a hind
## leg's stifle and hock flex together); three or four with those above the last two swung
## along a share of the leg.
enum Chain { NONE, TWO, COUPLED, LEAD }
## Out cold (a rooster's faint): [upper, lower, foot] leg angles, stiff and sticking out
## behind, spread by FAINT_SPREAD; the roll onto his (left) side; the wings fallen open
## onto the ground (left, right); the neck and head lying limp (euler angles).
const FAINT_LEGS := [-1.7, 0.3, 0.9]
const FAINT_SPREAD := 0.3
const FAINT_ROLL := 0.7
const FAINT_WINGS := Vector2(1.7, 1.5)
const FAINT_NECK := Vector3(-0.35, 0.3, 0.9)
const FAINT_HEAD := Vector3(0.4, 0.2, 0.9)
## A bird standing about (Mode.IDLE, not moving; see _update_bird_idle): seconds between
## the quick turns of its head, and between the things it does now and then.
const BIRD_LOOK := Vector2(0.35, 2.0)
const BIRD_ACT := Vector2(2.0, 6.0)
enum BirdAct { NONE, PECK, SCRATCH, PREEN }

var species: StringName
var cfg: Dictionary
var skeleton: Skeleton3D
var mesh: MeshInstance3D
var legs: Array[Dictionary] = []

var _b := {}
var _phase := 0.0
var _time := 0.0
var _head_down := 0.0
var _lie := 0.0
var _peck_timer := 0.0
var _peck := 0.0
var _ear_timer := 0.0
var _ear_flick := 0.0
var _seed := 0.0
var _age := 1.0
var _leg_extra := 0.0
## Ground height under a world point (y), set by the owner (Animal: its housing's floors and
## ramps); without one the ground is level with the rig.
var ground := Callable()
## 0 walking .. 1 trotting; how far the body is lowered for legs that cannot reach.
var _trot := 0.0
## Strides of settling steps left (after stopping or being moved on the spot); where the
## rig stood last frame.
var _settle := 0.0
var _last_at := Transform3D()
var _lift_ground := 0.0
var _crouch := 0.0
var _short := 0.0
## The skeleton's transform in the rig and the rig's X axis in skeleton space (legs swing
## about it); leg bones placed by IK (PhotoRig leaves them out of its clip cross-fades).
var _sk_xf := Transform3D.IDENTITY
var _sk_axis := Vector3.RIGHT
var _sk_roll := Vector3.BACK
var _ik_bones := {}
## Far from the camera the legs are solved every second or fourth frame (the last solution
## held between), and not at all while hidden.
var _ik_last: Array = []
var _ik_parents: Array[Transform3D] = []
var _ik_skip := 0
const IK_NEAR := 25.0
## The leg an injured animal favours: the right foreleg (a bird's right leg).
const HURT_LEG := "fr"
## 0..1: a rooster's crowing pose (neck stretched up, head thrown back, chest out, the
## wings beating as he starts), set by Animal while he crows.
var crow := 0.0
## A rooster's faint after a crow held far too long, set by Animal: 0..1 keeled over (on
## his breast and side, wings splayed down to the ground, neck and head limp on it, legs
## sticking out); how hard he trembles (straining, or shaking himself awake); the
## unsteady sway of getting back up; a quick fluff of his feathers once he stands.
var faint := 0.0
var tremble := 0.0
var wobble := 0.0
var fluff := 0.0
## An injured animal favouring its hurt leg (HURT_LEG), set by Animal: `limp` 0..1 drops
## the body a little and rolls it off that leg while it bears the weight (a foreleg: the
## head comes up as it lands), its step short and barely lifted; `stumble` 0..1 lurches
## it forward and down for a moment.
var limp := 0.0
var stumble := 0.0
## A bird the farmer holds in his arms (AnimalHandler), set by its handler: `held` 0..1
## its legs tucked up under it; `flutter` 0..1 its wings beating a little (he runs, it
## wriggles).
var held := 0.0
var flutter := 0.0
## A bird standing about: how far into it (fading in and out); where its head looks (neck
## pitch, yaw, head tilt), where it turns to next and when; what it is doing now and then
## (a BirdAct), for how long, on which side (-1 left, 1 right) and the wait for the next;
## its tail's flick, a shake of its feathers (both 1 -> 0) and the weight shift (-1..1).
var _rest := 0.0
var _gaze := Vector3.ZERO
var _gaze_to := Vector3.ZERO
var _gaze_wait := randf_range(BIRD_LOOK.x, BIRD_LOOK.y)
var _act := BirdAct.NONE
var _act_t := 0.0
var _act_len := 0.0
var _act_side := 1.0
var _act_wait := randf_range(BIRD_ACT.x * 0.5, BIRD_ACT.y)
var _flick := 0.0
var _shake := 0.0
var _lean := 0.0
var _lean_to := 0.0

static var _scenes: Dictionary = {}


static func assemble(species_id: StringName) -> AnimalRig:
	var rig := AnimalRig.new()
	rig.species = species_id
	rig.cfg = PARAMS.get(species_id, PARAMS[&"cow"])
	rig._seed = randf() * 100.0
	var model: Node3D = _scene(species_id, SCULPT_PATH % species_id).instantiate()
	rig.add_child(model)
	rig.skeleton = model.get_node("Skeleton")
	rig.mesh = rig.skeleton.get_node("Mesh")
	for i in rig.skeleton.get_bone_count():
		rig._b[rig.skeleton.get_bone_name(i)] = i
	rig._collect_legs()
	rig._setup_ik()
	return rig


## Starts loading a species' model scene on a background thread (see `_scene`).
static func request_scene(species_id: StringName, path: String) -> void:
	if not _scenes.has(species_id) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path, "PackedScene")


## A species' model scene, loaded once: taken from its background load when one
## was requested (waiting only if it is still running), otherwise loaded here.
static func _scene(species_id: StringName, path: String) -> PackedScene:
	if not _scenes.has(species_id):
		var scene: PackedScene = null
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			scene = ResourceLoader.load_threaded_get(path) as PackedScene
		if scene == null:
			scene = load(path) as PackedScene
		_scenes[species_id] = scene
	return _scenes[species_id]


## Leg chains from the canonical bone names: f/r (front/rear), l/r, _up/_lo/_ft.
func _collect_legs() -> void:
	legs.clear()
	var biped: bool = cfg.get("biped", false)
	for side: Array in [["l", -1.0], ["r", 1.0]]:
		for front: bool in [true, false]:
			var prefix := ("f" if front else "r") + String(side[0])
			if not _b.has(prefix + "_up") or not _b.has(prefix + "_lo"):
				continue
			var walk: float = (TOUCH_BIRD if biped else TOUCH_WALK).get(prefix, 0.0)
			legs.append({"up": _b[prefix + "_up"], "lo": _b[prefix + "_lo"], "ft": _b.get(prefix + "_ft", -1),
				"front": front or biped, "side": side[1], "key": prefix, "td_walk": walk,
				"td_trot": TOUCH_TROT.get(prefix, walk)})


## Takes over the pose state of the rig this one replaces (a chick's body swapped for a
## pullet's): one lying down stays down, a lowered head stays lowered.
func carry_on(from: AnimalRig) -> void:
	_lie = from._lie
	_head_down = from._head_down
	_phase = from._phase
	ground = from.ground


func _bone(bone_name: String) -> int:
	return _b.get(bone_name, -1)


func _rot(bone_name: String, euler: Vector3) -> void:
	var i := _bone(bone_name)
	if i >= 0:
		_pose_rot(i, Quaternion.from_euler(euler))


## Sets a bone's rotation, given in the animal's frame (faces -Z, +X to its right)
## relative to its parent. The sculpted models have identity rest bases, so this is
## the plain pose rotation; imported models convert it (see PhotoRig).
func _pose_rot(idx: int, q: Quaternion) -> void:
	skeleton.set_bone_pose_rotation(idx, q)


## Moves a bone away from its rest position by `offset` metres in the animal's frame.
func _pose_offset(idx: int, offset: Vector3) -> void:
	skeleton.set_bone_pose_position(idx, skeleton.get_bone_rest(idx).origin + offset)


func _pose_scale(idx: int, s: Vector3) -> void:
	skeleton.set_bone_pose_scale(idx, s)


# --- Appearance -----------------------------------------------------------------------------

func set_variant(variant: int, baby: bool) -> void:
	var list: Array = AnimalModels.VARIANTS.get(species, [{}])
	var v: Dictionary = list[clampi(variant, 0, list.size() - 1)]
	mesh.set_instance_shader_parameter("coat_tint", v.get("coat", Color.WHITE))
	mesh.set_instance_shader_parameter("points_tint", v.get("points", v.get("coat", Color.WHITE)))
	mesh.set_instance_shader_parameter("hair_tint", v.get("hair", Color(0.1, 0.08, 0.07)))
	mesh.set_instance_shader_parameter("patch_color", v.get("patch", Color.BLACK))
	mesh.set_instance_shader_parameter("patches", 1.0 if v.get("patches", false) else 0.0)
	mesh.set_instance_shader_parameter("pattern_seed", float(variant * 7) + fmod(_seed, 13.0))
	mesh.set_instance_shader_parameter("baby", 1.0 if baby else 0.0)


func set_wet(amount: float) -> void:
	mesh.set_instance_shader_parameter(&"wet", amount)


## 0 baby .. 1 adult: overall size, a bigger head and relatively longer legs.
func set_age(t: float) -> void:
	_age = clampf(t, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(float(cfg.get("baby_scale", 0.5)), 1.0, _age)
	_leg_extra = 0.22 * (1.0 - _age)
	for leg in legs:
		_pose_scale(leg["up"], Vector3(1.0, 1.0 + _leg_extra, 1.0))
	var head := _bone("head")
	if head >= 0:
		_pose_scale(head, Vector3.ONE * (1.0 + 0.3 * (1.0 - _age)))


## How much higher a young one's body stands on its longer legs: as much as its shortest
## upper leg bone grew (the IK straightens the others), metres.
func _age_raise() -> float:
	var grew := INF
	for leg in legs:
		if leg.has("up_len"):
			grew = minf(grew, float(leg["up_len"]) * _leg_extra)
	return grew if grew < INF else float(cfg["hip_height"]) * _leg_extra


## Sheep: 1 = full fleece, 0 = freshly shorn.
func set_wool(amount: float) -> void:
	mesh.set_instance_shader_parameter("wool_amount", clampf(amount, 0.0, 1.0))


# --- Animation ------------------------------------------------------------------------------

func animate(delta: float, speed: float, mode: int) -> void:
	_time += delta
	var biped: bool = cfg.get("biped", false)
	var running := mode == Mode.RUN
	_lie = move_toward(_lie, 1.0 if mode == Mode.SLEEP else 0.0, delta * 0.7)
	var head_target := 0.0
	if mode == Mode.GRAZE:
		head_target = 1.0
	elif mode == Mode.EAT:
		head_target = 0.6
	_head_down = lerpf(_head_down, head_target, clampf(delta * 2.5, 0.0, 1.0))
	var lie := smoothstep(0.0, 1.0, _lie)
	# A faint: trembling in small fast shakes, a slow sway getting up, a quick ruffle after.
	var shake := (sin(_time * 53.0) + sin(_time * 37.0 + 1.3)) * 0.5 * tremble
	var stagger := sin(_time * 4.2) * wobble
	# Birds standing about (never while crowing or in a faint): see _update_bird_idle.
	var rest := 0.0
	var dip := 0.0
	var rake := 0.0
	var preen := 0.0
	if biped:
		_update_bird_idle(delta, mode == Mode.IDLE and speed < 0.05 and crow == 0.0 and faint == 0.0 and tremble == 0.0
				and wobble == 0.0)
		rest = smoothstep(0.0, 1.0, _rest)
		var env := smoothstep(0.0, 0.25, _act_t) * (1.0 - smoothstep(_act_len - 0.3, _act_len, _act_t))
		if _act == BirdAct.PECK:
			dip = env * rest
		elif _act == BirdAct.SCRATCH:
			rake = smoothstep(0.0, 0.12, _act_t) * (1.0 - smoothstep(_act_len - 0.2, _act_len, _act_t)) * rest
		elif _act == BirdAct.PREEN:
			preen = env * rest
	var fluffed := maxf(fluff, sin(PI * _shake) * rest)
	var ruffle := sin(_time * 34.0) * fluffed

	# The gait: where each foot is (set down and held, or stepping), how briskly it goes.
	var gamp := _update_gait(delta, speed, running, rake) * (1.0 - lie)
	var hip: float = cfg["hip_height"]
	var ph2 := TAU * 2.0 * _phase
	# The body dips a little at each step walking; trotting it springs up between the beats.
	var bob := (-(0.5 + 0.5 * cos(ph2 - 0.8)) * 0.012 * (1.0 - _trot) + (0.5 - 0.5 * cos(ph2)) * 0.025 * _trot) \
			* hip * gamp - _crouch
	# Favouring the hurt leg: down and off it while it bears the weight; a stumble lurches.
	var hurt := limp_load() * clampf(gamp * 1.5, 0.0, 1.0)
	var sag := (hurt * (0.1 if biped else 0.06) + stumble * 0.16) * hip
	var root := _bone("root")
	if root >= 0:
		_pose_offset(root, Vector3(shake * 0.004, _age_raise() + bob - lie * float(cfg["lie_drop"])
				- faint * float(cfg.get("faint_drop", hip * 0.7)) - sag, 0))
	if biped:
		# Keeled over onto his breast and side (and swaying as he gets back up).
		_rot("root", Vector3(-faint * 0.1 + stagger * 0.05, stagger * 0.08, faint * FAINT_ROLL + stagger * 0.16))
	# Rolling a little over the foot it stands on (a bird waddles).
	var pitch := sin(ph2) * 0.012 * _trot * gamp + lie * 0.03 + crow * 0.1 + shake * 0.06 - stumble * 0.24
	var roll := sin(TAU * _phase) * gamp * (0.03 if biped else 0.012) + shake * 0.05 + ruffle * 0.2 \
			+ hurt * (0.2 if biped else 0.07)
	# Standing about: breathing, the weight on one foot then the other, leaning into a
	# scratch or a peck, turned a little toward the wing it preens.
	pitch += (sin(_time * 2.3 + _seed) * 0.012 - rake * 0.1 - dip * 0.06) * rest
	roll += (_lean * 0.05 + preen * _act_side * 0.06) * rest
	_rot("body", Vector3(pitch, preen * -_act_side * 0.12, roll))

	var idle := (1.0 - _head_down) * (1.0 - clampf(speed, 0.0, 1.0))
	var nd: float = cfg["neck_down"]
	var look_yaw := sin(_time * 0.37 + _seed) * 0.2 * idle
	var nod := sin(_time * 0.7 + _seed) * 0.04 * idle
	# Walking, the head nods with each forefoot set down; trotting it is held steadier.
	nod -= (0.5 + 0.5 * cos(ph2 - TAU * 2.0 * 0.3)) * 0.05 * gamp * (1.0 - _trot * 0.6)
	var head := Vector3(-_head_down * float(cfg["head_down"]) + crow * 0.38, look_yaw * 0.3 * (1.0 - crow), shake * 0.2)
	if biped:
		_peck = move_toward(_peck, 0.0, delta * 5.0)
		if mode == Mode.GRAZE or mode == Mode.EAT or dip > 0.6:
			_peck_timer -= delta
			if _peck_timer <= 0.0:
				_peck_timer = randf_range(0.35, 1.1)
				_peck = 1.0
		var bob_head := sin(TAU * _phase * 2.0) * 0.12 * clampf(speed * 2.0, 0.0, 1.0)
		# The head held still between quick turns (not in a peck or preening), or turned
		# back into the wing to preen, nibbling.
		var g := _gaze * idle * (1.0 - crow) * (1.0 - dip) * (1.0 - preen) * (1.0 - lie * 0.8)
		var nibble := sin(_time * 21.0) * 0.08 * preen
		var neck := Vector3(-_head_down * nd - _peck * 0.7 + bob_head - lie * 0.3 + crow * 0.45 + shake * 0.15
				+ g.x * 0.4 - dip * nd * 0.8 - preen * 0.3, g.y * 0.6 + preen * _act_side * -1.5, ruffle * 0.3)
		_rot("neck1", neck.lerp(FAINT_NECK, faint))
		head = Vector3(-_head_down * float(cfg["head_down"]) + crow * 0.38 + g.x * 0.6 - dip * 0.35 - preen * 0.35 + nibble,
				g.y * 0.4 + preen * _act_side * -0.7, shake * 0.2 + g.z + preen * _act_side * 0.3)
	else:
		# A sore foreleg: the head goes up as it lands, down again on the sound one.
		nod += hurt * 0.3 - stumble * 0.25
		_rot("neck1", Vector3(-_head_down * nd * 0.55 + nod - lie * 0.2, look_yaw * 0.6, 0))
		_rot("neck2", Vector3(-_head_down * nd * 0.45, look_yaw * 0.4, 0))
	_rot("head", head.lerp(FAINT_HEAD, faint))

	# Ears flick now and then.
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(2.0, 7.0)
		_ear_flick = 1.0
	_ear_flick = move_toward(_ear_flick, 0.0, delta * 4.0)
	_rot("ear_l", Vector3(0, 0, -_ear_flick * 0.5))
	_rot("ear_r", Vector3(0, 0, _ear_flick * 0.3 * sin(_time * 3.0)))

	var sway := sin(_time * 1.4 + _seed) * 0.16 + sin(_time * 3.3 + _seed) * 0.05
	if biped:
		# A bird's tail barely sways: now and then it flicks, side to side.
		sway = sin(_time * 1.1 + _seed) * 0.02 + sin((1.0 - _flick) * TAU * 2.5) * 0.22 * _flick
	# Limp and flat on the ground in a faint, up a moment as he fluffs himself.
	var lift_tail := (0.25 if running else 0.05) - lie * 0.2 - faint * 0.6 + fluffed * 0.2
	_rot("tail1", Vector3(-lift_tail, 0, sway + faint * 0.4))
	_rot("tail2", Vector3(-lift_tail * 0.5, 0, sway * 1.2))
	_rot("tail3", Vector3(0, 0, sway * 1.4))
	if biped:
		# Running flutters the wings; a crow starts with a few strong beats.
		var beat := crow * (1.0 - smoothstep(0.55, 0.9, crow)) if crow > 0.0 else 0.0
		var flap := sin(_time * 18.0) * 0.4 * (1.0 if running else 0.0) + sin(_time * 14.0) * 0.7 * beat \
				+ (0.5 + 0.5 * sin(_time * 21.0)) * 0.55 * flutter
		# Fallen open in a faint, quivering, held out a little in a ruffle; the one preened
		# lifted a little from the body.
		var splay := shake * 0.3 + fluffed * 0.35
		var lift_l := preen * 0.3 if _act_side < 0.0 else 0.0
		var lift_r := preen * 0.3 if _act_side > 0.0 else 0.0
		_rot("wing_l", Vector3(0, 0, flap + splay + lift_l + faint * FAINT_WINGS.x))
		_rot("wing_r", Vector3(0, 0, -flap - splay - lift_r - faint * FAINT_WINGS.y))

	# Legs: folded under lying down or out cold in a faint (posed joint by joint), otherwise
	# placed by IK on the feet (_place_legs), the two blended while it lies down or gets up.
	# Held in the arms the legs are tucked up as lying down.
	var tuck := maxf(lie, held)
	var fk := maxf(tuck, faint)
	if fk > 0.0:
		for leg in legs:
			var fold: Array = (cfg.get("fold_front", FOLD_FRONT) if leg["front"] else cfg.get("fold_rear", FOLD_REAR)) \
					if not biped else FOLD_BIPED
			var spread := float(leg["side"]) * FAINT_SPREAD * faint
			_pose_rot(leg["up"], Quaternion.from_euler(Vector3(lerpf(fold[0] * tuck, FAINT_LEGS[0], faint), 0, spread)))
			_pose_rot(leg["lo"], Quaternion(Vector3.RIGHT, lerpf(fold[1] * tuck, FAINT_LEGS[1], faint)))
			if leg["ft"] >= 0:
				_pose_rot(leg["ft"], Quaternion(Vector3.RIGHT, lerpf(fold[2] * tuck, FAINT_LEGS[2], faint)))
	_place_legs(fk, delta)


## A bird standing about (`standing`): its head held still between quick turns, looking
## about with one eye and the other; now and then a peck at something on the ground (a few
## quick jabs), a scratch with one foot (then a look and a peck at what it turned up), a
## preen under one wing, a flick of the tail, a shake of its feathers, the weight moved
## onto the other foot. Only the upper body and the scratching foot move: the feet stay
## where they stand. Anything under way fades out once it moves off.
func _update_bird_idle(delta: float, standing: bool) -> void:
	_rest = move_toward(_rest, 1.0 if standing else 0.0, delta * (2.0 if standing else 5.0))
	_flick = move_toward(_flick, 0.0, delta * 2.8)
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	_lean = lerpf(_lean, _lean_to, 1.0 - exp(-delta * 2.5))
	_gaze_wait -= delta
	if _gaze_wait <= 0.0:
		_gaze_wait = randf_range(BIRD_LOOK.x, BIRD_LOOK.y)
		# Sideways to look with one eye, now and then a long look round, tilted up or down.
		var far := 1.7 if randf() < 0.2 else 1.0
		_gaze_to = Vector3(randf_range(-0.3, 0.15), randf_range(-0.6, 0.6) * far, randf_range(-0.45, 0.45) if randf() < 0.45 else 0.0)
	# A bird's eyes hardly move in its head: the head snaps to where it looks.
	_gaze = _gaze.lerp(_gaze_to, 1.0 - exp(-delta * 16.0))
	if _act != BirdAct.NONE:
		_act_t += delta
		if _act_t >= _act_len:
			var scratched := _act == BirdAct.SCRATCH
			_act = BirdAct.NONE
			if scratched and standing:
				# A look at what the scratch turned up, and a peck.
				_start_act(BirdAct.PECK, randf_range(0.8, 1.4))
	if not standing or _act != BirdAct.NONE:
		return
	_act_wait -= delta
	if _act_wait > 0.0:
		return
	_act_wait = randf_range(BIRD_ACT.x, BIRD_ACT.y)
	var roll := randf()
	if roll < 0.3:
		_start_act(BirdAct.PECK, randf_range(0.8, 1.6))
	elif roll < 0.45:
		_start_act(BirdAct.SCRATCH, randf_range(0.9, 1.3))
	elif roll < 0.57:
		_start_act(BirdAct.PREEN, randf_range(1.5, 3.0))
	elif roll < 0.75:
		_flick = 1.0
	elif roll < 0.8:
		_shake = 1.0
	else:
		_lean_to = randf_range(0.4, 1.0) * (-1.0 if _lean_to > 0.0 else 1.0)


func _start_act(act: BirdAct, length: float) -> void:
	_act = act
	_act_t = 0.0
	_act_len = length
	_act_side = -1.0 if randf() < 0.5 else 1.0


# --- Legs: gait and IK ----------------------------------------------------------------------

## Builds each leg's IK chain (the bones from its `up` bone down to the `ft` bone, or to
## `lo` without one) and measures it in the standing pose (rest, or PhotoRig's squared-up
## stance): where its foot touches the ground and how its joints bend.
func _setup_ik() -> void:
	_sk_xf = _path_xf(skeleton, self)
	_sk_axis = (_sk_xf.basis.inverse() * Vector3.RIGHT).normalized()
	_sk_roll = (_sk_xf.basis.inverse() * Vector3.BACK).normalized()
	var biped: bool = cfg.get("biped", false)
	for leg in legs:
		leg["kind"] = Chain.NONE
		var ft: int = leg["ft"]
		# A foot bone outside the leg's chain (leg["ctrl"]: a model's IK control, the
		# pastern and hoof skinned to it) is carried at the end of the leg.
		var detached := ft < 0 and int(leg.get("ctrl", -1)) >= 0
		if detached:
			ft = leg["ctrl"]
		var last: int = skeleton.get_bone_parent(ft) if ft >= 0 and not detached else int(leg["lo"])
		var chain: Array[int] = []
		var b := last
		while b >= 0 and b != int(leg["up"]):
			chain.push_front(b)
			b = skeleton.get_bone_parent(b)
		if b < 0 or chain.size() > 2:
			continue
		chain.push_front(b)
		# A shoulder blade (fl_sh / fr_sh) swings with the foreleg, reaching further.
		var sh: int = _b.get(String(leg["key"]) + "_sh", -1)
		if sh >= 0 and chain.size() <= 3 and skeleton.get_bone_parent(b) == sh:
			chain.push_front(sh)
			b = sh
		var bones: Array[int] = chain.duplicate()
		if ft >= 0:
			bones.append(ft)
		var refs: Array[Quaternion] = []
		var pos: Array[Vector3] = []
		var g: Array[Transform3D] = []
		var t := _ref_parent(skeleton.get_bone_parent(b), leg)
		var n := chain.size()
		var rel := Transform3D.IDENTITY
		if detached:
			rel = skeleton.get_bone_global_rest(chain[-1]).affine_inverse() * skeleton.get_bone_global_rest(ft)
		for bone in bones:
			refs.append(_ref_rot(bone, leg))
			pos.append(skeleton.get_bone_rest(bone).origin)
			t = g[-1] * rel if detached and bone == ft else t * Transform3D(Basis(refs[-1]), pos[-1])
			g.append(t)
		var end_t: Transform3D = g[n] if ft >= 0 else g[n - 1]
		var contact := end_t.origin
		if not (biped and ft >= 0):
			contact = _lowest_point(bones[-1], end_t)
		var c_rig := _sk_xf * contact
		var joints: Array[Vector2] = []
		for i in n:
			joints.append(_sagittal(_sk_xf * g[i].origin))
		joints.append(_sagittal(_sk_xf * g[n].origin) if ft >= 0 else _sagittal(c_rig))
		var segs: Array[Vector2] = []
		var length := 0.0
		for i in n:
			segs.append(joints[i + 1] - joints[i])
			length += segs[i].length()
		# Which way the joint IK bends goes forward (+1: a foreleg's carpus, a hind leg's
		# stifle) or back (-1: a hock, a bird's ankle), as in the animal (models' poses are
		# often nearly straight or a little over-straight there).
		var kind := Chain.TWO
		if n >= 3:
			kind = Chain.LEAD if biped or leg["front"] or n > 3 else Chain.COUPLED
		var bend := 1.0 if not biped and (leg["front"] or kind == Chain.COUPLED) else -1.0
		leg["kind"] = kind
		leg["bend"] = bend
		var ui := chain.find(int(leg["up"]))
		leg["up_len"] = segs[ui].length() if ui >= 0 and ui < segs.size() else 0.0
		leg["bones"] = bones
		leg["n"] = n
		var locals: Array[Transform3D] = []
		for i in bones.size():
			locals.append(rel if detached and i == n else Transform3D(Basis(refs[i]), pos[i]))
		leg["local"] = locals
		leg["parent"] = skeleton.get_bone_parent(b)
		leg["detached"] = detached
		leg["rel"] = rel
		leg["c_local"] = end_t.affine_inverse() * contact
		# Its place in a square stance, the middle of its steps: halfway between where the
		# foot stands in the model's pose and below the joint the leg swings from.
		var hip := _sk_xf * g[chain.find(int(leg["up"]))].origin
		leg["foot0"] = Vector3(c_rig.x, 0.0, lerpf(c_rig.z, hip.z, 0.5))
		# (A model's lowest bone may sit a little under its sole.)
		leg["c_h"] = maxf(c_rig.y, 0.0)
		leg["len"] = length + ((c_rig - _sk_xf * g[n].origin).length() if ft >= 0 else 0.0)
		leg["init"] = false
		leg["planted"] = false
		leg["swing"] = false
		leg["cur"] = leg["foot0"]
		leg["psi"] = 0.0
		for bone in bones:
			_ik_bones[bone] = true
	# Each pair stands square: left and right feet level, as wide apart.
	for i in legs.size():
		for j in range(i + 1, legs.size()):
			var a: Dictionary = legs[i]
			var c: Dictionary = legs[j]
			if a["kind"] != Chain.NONE and c["kind"] != Chain.NONE and a["front"] == c["front"]:
				var fa: Vector3 = a["foot0"]
				var fc: Vector3 = c["foot0"]
				var z := (fa.z + fc.z) * 0.5
				var x := (absf(fa.x) + absf(fc.x)) * 0.5
				a["foot0"] = Vector3(x * signf(fa.x), 0.0, z)
				c["foot0"] = Vector3(x * signf(fc.x), 0.0, z)
				a["cur"] = a["foot0"]
				c["cur"] = c["foot0"]


## A point in the rig as (forward, up).
static func _sagittal(p: Vector3) -> Vector2:
	return Vector2(-p.z, p.y)


## Where a leg's end bone meets the ground in the standing pose (skeleton space): its
## lowest descendant, or without any, where the bone's own axis reaches the ground.
func _lowest_point(bone: int, xf: Transform3D) -> Vector3:
	var best := xf.origin
	var best_y := (_sk_xf * best).y
	var stack: Array = [[bone, xf]]
	var found := false
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		for child in skeleton.get_bone_children(top[0]):
			var cx: Transform3D = (top[1] as Transform3D) * skeleton.get_bone_rest(child)
			var y := (_sk_xf * cx.origin).y
			if y < best_y:
				best_y = y
				best = cx.origin
			found = true
			stack.append([child, cx])
	if not found:
		var o := _sk_xf * xf.origin
		var ax := (_sk_xf.basis * xf.basis.y).normalized()
		if ax.y < -0.3:
			best = _sk_xf.affine_inverse() * (o + ax * (o.y / -ax.y))
	return best


## A leg bone's rotation in the standing pose (relative to its parent).
func _ref_rot(idx: int, _leg: Dictionary) -> Quaternion:
	return skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()


## Where a leg chain's parent bone is (skeleton space) in the pose its leg is measured in.
func _ref_parent(idx: int, _leg: Dictionary) -> Transform3D:
	return skeleton.get_bone_global_rest(idx)


## Gait cycles per second at `v` m/s (full size): strides lengthen and quicken with speed.
func _gait_rate(v: float) -> float:
	var walk: float = cfg["walk_speed"]
	return v / (float(cfg["stride"]) * clampf(pow(maxf(v, 0.0) / walk, float(cfg.get("stride_exp", 0.6))), 0.4, 2.6))


## Whether the legs are placed by IK now (PhotoRig: not while a clip poses them).
func _legs_ik() -> bool:
	return true


## Transform of `node` relative to `ancestor`, without needing the scene tree.
static func _path_xf(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## A point of the rig (its frame, full size) put down on the ground below it (a foot's
## contact point: its height above the ground in the standing pose added).
func _grounded(p: Vector3, xf: Transform3D, inv: Transform3D, c_h: float) -> Vector3:
	var w := xf * p
	w.y = float(ground.call(w)) + _lift_ground if ground.is_valid() else xf.origin.y
	var l := inv * w
	l.y += c_h
	return l


## Advances the gait and works out where each foot goes this frame (leg["cur"], in the rig,
## and leg["psi"], its foot's pitch). A planted foot stays where it was set down in the
## world while the body walks on over it; at its turn it lifts, swings forward and is set
## down half a step ahead of its place in a square stance. A step is the ground covered
## while the foot is down, so it never slides; strides lengthen and quicken with speed.
## Coming to a stand, a foot left off its square stance (or in the air) steps up to it, then
## the gait stops. Returns the gait's briskness (0 standing .. 1 walking .. 1.3).
func _update_gait(delta: float, speed: float, running: bool, rake: float) -> float:
	var biped: bool = cfg.get("biped", false)
	var s := maxf(scale.x, 0.01)
	var v := speed / s
	var walk: float = cfg["walk_speed"]
	_trot = move_toward(_trot, 1.0 if not biped and (running or v > float(cfg.get("trot_at", 1e9))) else 0.0, delta * 2.0)
	var rate := _gait_rate(v)
	var stride := v / rate if rate > 0.0 else float(cfg["stride"]) * 0.4
	var duty := lerpf(float(cfg.get("duty", 0.62)), float(cfg.get("duty_trot", DUTY_TROT)), _trot)
	var moving := v > 0.03
	var step := duty * stride if moving else 0.0
	if not _legs_ik():
		for leg in legs:
			leg["init"] = false
		_phase = fmod(_phase + rate * delta, 1.0)
		return clampf(v / walk, 0.0, 1.3)
	# Where the body is drawn (between physics ticks when posed per rendered frame).
	var xf := transform
	if is_inside_tree():
		xf = global_transform if Engine.is_in_physics_frame() else get_global_transform_interpolated()
	_follow_slope(xf, delta)
	var inv := xf.affine_inverse()
	var fwd := Vector3(0, 0, -step)
	# Settling steps (at about the walking pace) for a stride or so after it stops or is
	# moved on the spot (pushed aside, turned); none lying down or out cold.
	if moving or xf.origin.distance_squared_to(_last_at.origin) > 4e-4 or xf.basis.z.dot(_last_at.basis.z) < 0.9986 * xf.basis.z.length_squared():
		_settle = 1.5
	_last_at = xf
	# Standing, the gait's clock stops: a foot left off its place steps up to it on its own,
	# one at a time, at about the walking pace (and one in the air comes down).
	var swing_rate := rate
	var stepping := false
	if not moving:
		rate = 0.0
		swing_rate = walk / float(cfg["stride"])
		for leg in legs:
			stepping = stepping or bool(leg.get("swing", false))
		if stepping:
			_settle -= swing_rate * delta
	_phase = fmod(_phase + rate * delta, 1.0)
	# The ground under the feet as high as where the body stands (an animal on a nest box
	# or a perch the ground it knows is not).
	_lift_ground = 0.0
	if ground.is_valid():
		_lift_ground = xf.origin.y - float(ground.call(xf.origin))
		if absf(_lift_ground) < 0.01:
			_lift_ground = 0.0
	var lying := _lie > 0.01 or faint > 0.0
	for leg in legs:
		if leg["kind"] == Chain.NONE:
			continue
		# The middle of a foot's steps a little ahead of where it stands (shift_f / shift_h,
		# share of a step) as the model's legs reach.
		var n: Vector3 = leg["foot0"] + fwd * float(cfg.get("shift_f" if leg["front"] else "shift_h", 0.0 if leg["front"] else 0.05))
		var c_h: float = leg["c_h"]
		var ln: float = leg["len"]
		var u := fposmod(_phase - lerpf(leg["td_walk"], leg["td_trot"], _trot), 1.0)
		if not leg["init"]:
			leg["init"] = true
			leg["planted"] = true
			leg["swing"] = false
			leg["lock"] = xf * _grounded(n, xf, inv, c_h)
			leg["u"] = u
		# The foot's turn to lift: its stance share of the cycle just ran out.
		var prev: float = leg["u"]
		var lift_off := (prev < duty and u >= duty) or (u < prev and prev < duty)
		leg["u"] = u
		var tgt: Vector3
		var psi := 0.0
		# Late in its stance a hoof rolls over its toe, the heel coming up first.
		var roll := 0.0 if biped else (0.45 + 0.25 * _trot) * gamp_of(v)
		if leg["planted"]:
			tgt = inv * (leg["lock"] as Vector3)
			if u < duty and moving:
				psi = -roll * smoothstep(0.65, 1.0, u / duty)
			var off := Vector2(tgt.x - n.x, tgt.z - n.z)
			var out_of_reach := float(leg.get("short", 0.0)) > ln * 0.03
			if off.length() > ln * 1.2:
				# Far off (carried off, turned round on the spot): under it again.
				tgt = _grounded(n, xf, inv, c_h)
				leg["lock"] = xf * tgt
			elif lying:
				pass
			elif out_of_reach and not moving and (off.length() < ln * 0.12 or _settle <= 0.0):
				# Standing on something the ground it knows is not (a nest box's edge, a
				# step): the foot stands where the leg reaches.
				tgt = leg["got"]
				leg["lock"] = xf * tgt
			elif (lift_off and moving) or (out_of_reach and (moving or not stepping)) \
					or (not moving and not stepping and _settle > 0.0 and _off_stance(leg, inv)) \
					or (moving and (off.y > step * 0.5 + ln * 0.12 or off.length() > ln * 0.5
					or (off.y > 0.0 and float(leg.get("short", 0.0)) > ln * 0.01))):
				# Lifted at its turn, or early when left too far behind (setting off, a turn,
				# pushed aside, the leg stretched as far as it goes).
				leg["planted"] = false
				leg["swing"] = true
				leg["from"] = tgt
				# The share of a cycle until its touchdown point (a foot lifted early swings
				# longer, one lifted late no quicker than half a swing).
				leg["left"] = maxf(fposmod(-u, 1.0), (1.0 - duty) * 0.5) if moving else 1.0 - duty
				leg["p"] = 0.0
				stepping = true
				leg["land_y"] = _grounded(n + fwd * 0.5, xf, inv, c_h).y
		if leg["swing"]:
			# The swing takes the rest of the cycle; set down where a foot planted at this
			# point of the gait stands (half a step ahead when it lands on time).
			leg["p"] = float(leg["p"]) + swing_rate * delta / float(leg["left"])
			var p: float = minf(leg["p"], 1.0)
			var ahead := (0.5 - u / duty if u < duty else 0.5) if moving else 0.0
			var sore := limp if leg["key"] == HURT_LEG else 0.0
			# The hurt leg is put down short (and barely lifted).
			ahead *= 1.0 - 0.45 * sore
			# The ground where it lands, looked up as it lifts (and again as it lands).
			var land := n + fwd * ahead
			land.y = leg["land_y"]
			if p >= 1.0:
				land = _grounded(land, xf, inv, c_h)
			var from: Vector3 = leg["from"]
			var front: bool = leg["front"]
			# A forefoot is picked up and folded back first, then reaches out.
			tgt = from.lerp(land, smoothstep(0.08, 0.95, p) if front and not biped else smoothstep(0.0, 1.0, p))
			var lift := float(cfg.get("lift_f" if front else "lift_h", 0.1)) * ln * (1.0 + 0.4 * _trot)
			lift *= clampf(Vector2(land.x - from.x, land.z - from.z).length() / (ln * 0.45), 0.3, 1.0) * (1.0 - 0.55 * sore)
			var arch := sin(PI * pow(p, 0.75 if front else 1.0))
			tgt.y += lift * arch
			psi = -arch * (0.9 if biped else ((0.8 + 0.4 * _trot) if front else 0.55)) - roll * (1.0 - p) * (1.0 - p)
			if p >= 1.0:
				leg["swing"] = false
				leg["planted"] = true
				if float(leg.get("short", 0.0)) > ln * 0.005:
					# It could not reach its spot: set down where it got to.
					var got: Vector3 = leg["got"]
					land = _grounded(Vector3(got.x, 0.0, got.z), xf, inv, c_h)
				leg["lock"] = xf * land
				tgt = land
		if rake > 0.0 and float(leg["side"]) == _act_side:
			# Scratching: the foot reaches forward in the air and rakes back over the ground.
			var rp := TAU * 2.2 * _act_t
			var scratch := n + Vector3(0, maxf(0.0, cos(rp)) * 0.2 * ln, -0.3 * ln * sin(rp))
			tgt = tgt.lerp(scratch + Vector3(0, c_h, 0), rake)
			psi = lerpf(psi, -0.5 * maxf(0.0, cos(rp)), rake)
		leg["cur"] = tgt
		leg["psi"] = psi
	return clampf(v / walk, 0.0, 1.3)


## On a slope the body tilts with the ground between its fore and hind feet (the whole
## rig pitched about its centre, which stands on the ground).
func _follow_slope(xf: Transform3D, delta: float) -> void:
	if not ground.is_valid() or legs.size() < 4:
		return
	var front := 0.0
	var hind := 0.0
	for leg in legs:
		var f: Vector3 = leg["foot0"]
		if leg["front"]:
			front = f.z
		else:
			hind = f.z
	if hind - front < 0.05:
		return
	var ahead := -xf.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var sc := xf.basis.get_scale().x
	var hf := float(ground.call(xf.origin - ahead * front * sc))
	var hh := float(ground.call(xf.origin - ahead * hind * sc))
	var want := clampf(atan2(hf - hh, (hind - front) * sc), -0.35, 0.35)
	rotation.x = lerpf(rotation.x, want, 1.0 - exp(-delta * 6.0))


## 0..limp: how much weight the hurt leg (HURT_LEG) bears now: most in the middle of its
## time on the ground, none in the air. The limp's beat: Animal slows its pace on it.
func limp_load() -> float:
	if limp <= 0.0:
		return 0.0
	for leg in legs:
		if leg["key"] != HURT_LEG:
			continue
		var duty := lerpf(float(cfg.get("duty", 0.62)), float(cfg.get("duty_trot", DUTY_TROT)), _trot)
		var u := fposmod(_phase - lerpf(leg["td_walk"], leg["td_trot"], _trot), 1.0)
		return sin(PI * u / duty) * limp if u < duty else 0.0
	return 0.0


## How brisk the gait is at `v` m/s (full size): 0 standing .. 1 walking .. 1.3.
func gamp_of(v: float) -> float:
	return clampf(v / float(cfg["walk_speed"]), 0.0, 1.3)


## Whether a planted foot stands off its place in a square stance (by an eighth of the leg).
func _off_stance(leg: Dictionary, inv: Transform3D) -> bool:
	if not leg["planted"]:
		return true
	var l := inv * (leg["lock"] as Vector3)
	var n: Vector3 = leg["foot0"]
	var ln: float = leg["len"]
	return Vector2(l.x - n.x, l.z - n.z).length() > ln * 0.12


## Poses the legs on their feet (leg["cur"]): each chain turned in the body's upright
## plane about its hip so the foot meets its spot, the foot pitched by leg["psi"]. Blended
## by `fk` into the pose already set joint by joint (lying down, a faint). Legs that cannot
## reach a planted foot lower the body a little (_crouch) on the next frames.
func _place_legs(fk: float, delta: float) -> void:
	if not _legs_ik() or (fk < 1.0 and not is_visible_in_tree()):
		return
	if fk >= 1.0:
		# Folded up lying down (only a detached foot is carried along below).
		for leg in legs:
			leg["short"] = 0.0
	var every := _ik_every()
	if fk <= 0.0 and not _ik_last.is_empty() and every > 1:
		_ik_skip = (_ik_skip + 1) % every
		if _ik_skip != 0:
			for o: Array in _ik_last:
				if o.size() > 2:
					skeleton.set_bone_pose_position(o[0], o[2])
				skeleton.set_bone_pose_rotation(o[0], o[1])
			return
	# Global poses read before any leg bone is set (the skeleton updates them once): each
	# chain's parent, and for a detached foot its parent and where the posed leg carries it.
	var parents: Array[Transform3D] = []
	var carried := {}
	for leg in legs:
		if leg["kind"] == Chain.NONE:
			parents.append(Transform3D.IDENTITY)
			continue
		parents.append(skeleton.get_bone_global_pose(leg["parent"]))
		if leg["detached"]:
			var bones: Array[int] = leg["bones"]
			carried[bones[-1]] = [skeleton.get_bone_global_pose(skeleton.get_bone_parent(bones[-1])),
				skeleton.get_bone_global_pose(bones[-2]) * (leg["rel"] as Transform3D)]
	# Nothing moved since the last solve (standing still, the hips within a couple of mm
	# of where they were, a clip breathing): the same pose again.
	if fk <= 0.0 and not _ik_last.is_empty() and parents.size() == _ik_parents.size():
		var same := true
		for leg in legs:
			if leg["kind"] != Chain.NONE and (leg["swing"] or leg["cur"] != leg.get("cur_last") or float(leg["psi"]) != 0.0):
				same = false
				break
		if same:
			for i in parents.size():
				if (_sk_xf.basis * (parents[i].origin - _ik_parents[i].origin)).length_squared() > 4e-6 \
						or parents[i].basis.get_rotation_quaternion().angle_to(_ik_parents[i].basis.get_rotation_quaternion()) > 0.008:
					same = false
					break
		if same:
			for o: Array in _ik_last:
				if o.size() > 2:
					skeleton.set_bone_pose_position(o[0], o[2])
				skeleton.set_bone_pose_rotation(o[0], o[1])
			return
	_ik_parents = parents
	for leg in legs:
		leg["cur_last"] = leg["cur"]
	# Skeleton space -> the rig's (forward, up): rows of the skeleton's transform in the rig.
	var fw := -Vector3(_sk_xf.basis.x.z, _sk_xf.basis.y.z, _sk_xf.basis.z.z)
	var up := Vector3(_sk_xf.basis.x.y, _sk_xf.basis.y.y, _sk_xf.basis.z.y)
	var out: Array = []
	var short := 0.0
	var young := _leg_extra > 0.0
	for li in legs.size():
		var leg: Dictionary = legs[li]
		if leg["kind"] == Chain.NONE or fk >= 1.0:
			continue
		var bones: Array[int] = leg["bones"]
		var locals: Array[Transform3D] = leg["local"]
		var n: int = leg["n"]
		var has_ft: bool = bones.size() > n
		var detached: bool = leg["detached"]
		var g: Array[Transform3D] = []
		var t := parents[li]
		for i in bones.size():
			var lx := locals[i]
			if young and not (detached and i == n):
				var sc := skeleton.get_bone_pose_scale(bones[i])
				if sc != Vector3.ONE:
					lx.basis = lx.basis * Basis.from_scale(sc)
			t = t * lx
			g.append(t)
		var end_t: Transform3D = g[n] if has_ft else g[n - 1]
		var c_sk := end_t * (leg["c_local"] as Vector3)
		var a_sk := g[n].origin if has_ft else c_sk
		var psi: float = leg["psi"]
		var c_goal: Vector3 = leg["cur"]
		var c_t := c_goal
		var mark := out.size()
		var j0 := g[0].origin
		var h := _sk_xf * j0
		# A young one's legs are lengthened by scaling their upper bones along their length,
		# which stretches the bones below unevenly as they bend: solved twice, the second
		# time for where the first put the foot.
		for attempt in (2 if young else 1):
			out.resize(mark)
			var a_t := c_t
			if has_ft:
				var d := c_sk - a_sk
				a_t -= Basis(Vector3.RIGHT, psi) * Vector3(0.0, up.dot(d), -fw.dot(d))
			var segs: Array[Vector2] = []
			for i in n:
				var d := (g[i + 1].origin if i + 1 < n else a_sk) - g[i].origin
				segs.append(Vector2(fw.dot(d), up.dot(d)))
			# Sideways the leg leans out or in about its hip (rolled about the body's length) to
			# stand over its foot: as deep unrolled as the foot is from the hip, turned onto it.
			var c_rig := _sk_xf * c_sk
			var x0 := c_rig.x - h.x
			var tx := c_t.x - h.x
			var ty := a_t.y - h.y
			var deep := -sqrt(maxf(tx * tx + ty * ty - x0 * x0, ty * ty * 0.25))
			var roll := clampf(atan2(tx, -ty) - atan2(x0, -deep), -0.35, 0.35)
			var target := Vector2(h.z - a_t.z, deep)
			var turn := _solve_leg(leg, segs, target)
			# Where the foot got to (short of the target when out of reach), in the rig.
			var got := target * (1.0 - _short / maxf(target.length(), 0.001))
			leg["got"] = c_goal + Vector3(0.0, got.y - deep, target.x - got.x)
			leg["short"] = _short
			if leg["planted"]:
				short = maxf(short, _short)
			var qr := Quaternion(_sk_roll, roll)
			# Each bone turned so its segment points where the solution wants it, through its
			# parent's pose as it is (a young one's longer upper leg is scaled along its length).
			var b_prev := parents[li].basis
			var end := j0
			for i in n:
				var seg := (g[i + 1].origin if i + 1 < n else a_sk) - g[i].origin
				var want := qr * Quaternion(_sk_axis, turn[i]) * seg
				var m_ref := g[i - 1].basis if i > 0 else parents[li].basis
				var turn_local := Quaternion((m_ref.inverse() * seg).normalized(), (b_prev.inverse() * want).normalized())
				var lr := turn_local * locals[i].basis.get_rotation_quaternion()
				out.append([bones[i], lr])
				b_prev = b_prev * Basis(lr).scaled_local(skeleton.get_bone_pose_scale(bones[i]) if young else Vector3.ONE)
				if detached:
					end += want
			if has_ft:
				var qf := Quaternion(_sk_axis, psi) * g[n].basis.get_rotation_quaternion()
				if detached:
					# Placed at the end of the leg (its parent is not the leg).
					var c: Array = carried[bones[n]]
					var want := Transform3D(Basis(qf), end)
					if fk > 0.0:
						want = want.interpolate_with(c[1], fk)
					var local := (c[0] as Transform3D).affine_inverse() * want
					out.append([bones[n], local.basis.get_rotation_quaternion(), local.origin])
				else:
					out.append([bones[n], (b_prev.inverse() * Basis(qf)).get_rotation_quaternion()])
			if attempt == 0 and young:
				var tt := parents[li]
				for i in n:
					tt = tt * Transform3D(Basis(out[mark + i][1] as Quaternion).scaled_local(skeleton.get_bone_pose_scale(bones[i])), locals[i].origin)
				var reached := tt * (leg["c_local"] as Vector3)
				if has_ft:
					var ft_o: Array = out[mark + n]
					var ftx := Transform3D(Basis(ft_o[1] as Quaternion), ft_o[2]) if ft_o.size() > 2 \
							else tt * Transform3D(Basis(ft_o[1] as Quaternion).scaled_local(skeleton.get_bone_pose_scale(bones[n])), locals[n].origin)
					if ft_o.size() > 2:
						ftx = (carried[bones[n]][0] as Transform3D) * ftx
					reached = ftx * (leg["c_local"] as Vector3)
				c_t -= (_sk_xf * reached - c_goal).limit_length(float(leg["len"]) * 0.1)
		if detached:
			carried.erase(bones[n])
	for o: Array in out:
		if fk > 0.0 and o.size() == 2:
			o[1] = (o[1] as Quaternion).slerp(skeleton.get_bone_pose_rotation(o[0]), fk)
		if o.size() > 2:
			skeleton.set_bone_pose_position(o[0], o[2])
		skeleton.set_bone_pose_rotation(o[0], o[1])
	_ik_last = out
	# Detached feet of legs posed joint by joint only (lying down): carried by the leg.
	for bone: int in carried:
		var c: Array = carried[bone]
		var local := (c[0] as Transform3D).affine_inverse() * (c[1] as Transform3D)
		skeleton.set_bone_pose_position(bone, local.origin)
		skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
	var hip: float = cfg["hip_height"]
	if short > 0.0005:
		_crouch = minf(_crouch + short * 0.5, hip * 0.04)
	else:
		_crouch = move_toward(_crouch, 0.0, hip * 0.01 * delta)


## Every how many frames the legs are solved: each one near the camera, fewer far off.
func _ik_every() -> int:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null:
		return 1
	var d2 := cam.global_position.distance_squared_to(global_position)
	return 1 if d2 < IK_NEAR * IK_NEAR else (2 if d2 < 4.0 * IK_NEAR * IK_NEAR else 4)


## A leg chain's turn per bone (radians, forward positive) so it reaches `target` (from its
## hip, forward/up); sets _short to how far the target is out of reach.
func _solve_leg(leg: Dictionary, segs: Array[Vector2], target: Vector2) -> PackedFloat32Array:
	var bend: float = leg["bend"]
	var out := PackedFloat32Array()
	match int(leg["kind"]):
		Chain.TWO:
			var r := _two_bone(target, segs[0].length(), segs[1].length(), bend)
			out.append(r.x - segs[0].angle())
			out.append(r.y - segs[1].angle())
		Chain.COUPLED:
			# Thigh and cannon keep their angle: together one virtual bone.
			var a1 := segs[0].angle()
			var z := Vector2(segs[0].length(), 0.0) + Vector2(segs[2].length(), 0.0).rotated(segs[2].angle() - a1)
			var r := _two_bone(target, z.length(), segs[1].length(), bend)
			var d1 := r.x - z.angle() - a1
			out.append(d1)
			out.append(r.y - segs[1].angle())
			out.append(d1)
		Chain.LEAD:
			# The bones above the last two (a shoulder blade, a bird's thigh, a horse's upper
			# arm) swing part of the way the leg does.
			var m := segs.size()
			var reach := Vector2.ZERO
			for sg in segs:
				reach += sg
			var swing := wrapf(target.angle() - reach.angle(), -PI, PI)
			var far := (segs[m - 2].length() + segs[m - 1].length()) * 0.995
			# Less of the swing (or against it) where the last two could not reach.
			var best := []
			var best_short := INF
			for share: float in [1.0, 0.6, 0.25, -0.15, -0.5]:
				var turns := []
				var base := Vector2.ZERO
				for i in m - 2:
					var d := swing * share * (0.4 if m == 3 else (0.5 if i == 0 else 0.8))
					turns.append(d)
					base += segs[i].rotated(d)
				var miss := (target - base).length() - far
				if miss < best_short:
					best_short = miss
					best = [turns, base]
				if miss <= 0.0:
					break
			var base: Vector2 = best[1]
			for d: float in best[0]:
				out.append(d)
			var r := _two_bone(target - base, segs[m - 2].length(), segs[m - 1].length(), bend)
			out.append(r.x - segs[m - 2].angle())
			out.append(r.y - segs[m - 1].angle())
	for i in out.size():
		out[i] = wrapf(out[i], -PI, PI)
	return out


## Two-bone IK in a plane: the angles of both bones reaching `target` from the origin, the
## joint bent to the `bend` side (+1: ahead of the line to the target).
func _two_bone(target: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d := target.length()
	var far := (l1 + l2) * 0.999
	_short = maxf(d - far, 0.0)
	d = clampf(d, absf(l1 - l2) + 0.001, far)
	var base := target.angle()
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var t1 := base + bend * a
	var joint := Vector2(l1, 0.0).rotated(t1)
	var end := Vector2(d, 0.0).rotated(base)
	return Vector2(t1, (end - joint).angle())
