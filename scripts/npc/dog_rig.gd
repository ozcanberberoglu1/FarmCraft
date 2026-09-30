class_name DogRig
extends Node3D
## Karamel's body and its procedural animation (see Dog for what he does).
##
## The model is MODEL_PATH, a skinned glTF built by tools/blender/build_dog.py from a
## downloaded dog (see art/models/animals/dog/CREDITS.md): a caramel coat with its normal
## and roughness maps, shell fur (FUR_LAYERS by graphics preset) and a skeleton of BONES,
## on the ground facing -Z, 56 cm at the withers.
##
## Everything is worked out in the dog's own frame (x right, y up, z back): standing
## about (breathing, weight shifting, looking round), sitting (the paws shuffled in under
## the body, the rump tucked under and down, the hocks on the ground behind the hind paws,
## the chest up until the forelegs stand straight), lying down (sphinx: forearms flat on
## the ground ahead, hind legs folded under, the head up or resting on the paws), nose
## down to the ground
## (sniffing, or eating from a bowl with the jaw working), the tail carried by mood and
## wagging from lazy sweeps to a hard wag that swings the hips, ears swinging with the
## head, a bark's jerk, panting.
##
## The gait: a walk in the lateral sequence (left hind, left fore, right hind, right fore)
## that becomes a trot in diagonal pairs (left hind with right fore) from TROT_FROM. A paw
## is set down in the world and stays exactly there while the body moves on over it,
## rolling over its toes late in the stance (the heel and the wrist lift); at its turn it
## lifts, the wrist or hock folding the paw back, and swings forward to land ahead of its
## place under the body, on time for its pair. A leg stretched as far as it reaches steps
## rather than drag its paw, and one that falls short brings the body down to it.
## Stopping, or turned on the spot, paws left off their places step back under the body,
## one at a time. Each leg is solved by IK: the paw placed flat, the pastern at its angle,
## the two long bones reaching the wrist (hock) from the shoulder (hip) with the elbow bent
## back and the stifle forward, and the shoulder blade swinging with the foreleg.

enum Pose { STAND, SIT, LIE }

const MODEL_PATH := "res://art/models/animals/dog/dog.gltf"
const STRANDS := "res://art/models/animals/dog/textures/dog_strands.png"
## Strand tiles per UV unit (the model has 1.21 m of surface per UV unit; a tile is 48
## strands, about 1 mm apart).
const STRAND_SCALE := 24.0
## Shell fur layers by graphics preset (LOW..ULTRA).
const FUR_LAYERS: Array[int] = [0, 6, 10, 14]
const BONES: Array[String] = ["root", "pelvis", "spine1", "spine2", "neck1", "neck2", "head", "jaw", "nose", "pet",
	"ear_l", "ear_l2", "ear_r", "ear_r2", "tail1", "tail2", "tail3", "tail4",
	"fl_sh", "fl_up", "fl_lo", "fl_ft", "fl_toe", "fl_tip", "fr_sh", "fr_up", "fr_lo", "fr_ft", "fr_toe", "fr_tip",
	"rl_up", "rl_lo", "rl_ft", "rl_toe", "rl_tip", "rr_up", "rr_lo", "rr_ft", "rr_toe", "rr_tip"]
const LEGS: Array[String] = ["fl", "fr", "rl", "rr"]

## Gait: stride cycles a second at WALK_SPEED (m/s), quicker and longer faster (rate ~
## speed^RATE_EXP); share of a cycle a paw is down walking and trotting; the speed the
## trot takes over from; when each paw is set down (share of the cycle).
const WALK_SPEED := 0.9
const WALK_RATE := 1.7
const RATE_EXP := 0.65
const DUTY_WALK := 0.62
const DUTY_TROT := 0.42
const TROT_FROM := 1.3
const TOUCH_WALK := {"rl": 0.0, "fl": 0.22, "rr": 0.5, "fr": 0.72}
const TOUCH_TROT := {"rl": 0.0, "fl": 0.5, "rr": 0.5, "fr": 1.0}
## How much lower the body goes walking and trotting (the legs reach further), metres.
const GAIT_CROUCH := Vector2(0.012, 0.028)
## How high a fore / hind paw is lifted swinging, metres.
const LIFT := Vector2(0.075, 0.06)
## A paw this far (m) off its place under the standing body steps back to it.
const SETTLE_OFF := 0.035
## Sitting: the hips lowered (m) and moved back, the rump tucked under (rad); lying: the
## body lowered (the chest on the ground) and the forepaws reaching forward.
const SIT_HIPS := Vector2(-0.33, 0.02)
const SIT_TUCK := 0.5
const LIE_BODY := Vector2(-0.275, 0.02)
const LIE_PITCH := 0.15
const LIE_REACH := 0.2
## Seconds to sit down (or get up) and to lie down from sitting.
const SIT_TIME := 0.8
const LIE_TIME := 1.1

static var _scene: PackedScene
static var _materials := {}

var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var fur: MeshInstance3D

## What the dog is doing, set by its owner every frame: the pose it goes to; a world point
## it looks at (INF: looks about); nose down to the ground 0..1 (sniffing, eating); the jaw
## chewing; how hard the tail wags 0..1; a lean to its right (+) or left (-) (into a
## stroking hand); ears laid back 0..1 (content); lying with the head down on the paws;
## panting.
var pose := Pose.STAND
var look_at_point := Vector3.INF
var nose_down := 0.0
var chewing := false
var wag := 0.25
var lean := 0.0
var ears_back := 0.0
var head_rest := false
var panting := false
## Ground height under a world point (x, z) -> y; without one the ground is level with the rig.
var ground := Callable()

var _b := {}  # rig bone -> bone index
var _conv := {}  # bone index -> [A, C, parent rest basis inverse]
var _to_rig := Transform3D.IDENTITY  # skeleton space -> rig
var _from_rig := Transform3D.IDENTITY
var _legs := {}
var _time := 0.0
## Eased pose state: sitting and lying 0..1, nose down, lean, ears back, the head resting,
## the look (yaw, pitch) and looking about, the tail's wag (amplitude, rate) and its phase,
## a bark's jerk (1 -> 0), the breath's phase and panting, the weight shifted from side to
## side.
var _sit := 0.0
var _lie := 0.0
var _nose := 0.0
var _lean := 0.0
var _ears := 0.0
var _rest_head := 0.0
var _look := Vector2.ZERO
var _look_about := Vector2.ZERO
var _look_about_to := Vector2.ZERO
var _look_timer := 1.0
var _wag_amp := 0.0
var _wag_rate := 1.5
var _wag_phase := 0.0
var _bark := 0.0
var _breath := 0.0
var _pant := 0.0
var _shift := 0.0
var _shift_to := 0.0
var _shift_timer := 3.0
## The gait: its phase, how brisk it is (0 still .. 1 walking .. 1.3), walk (0) to trot (1).
var _phase := 0.0
var _gamp := 0.0
var _trot := 0.0
## Ears: a swing each (rad) and its speed, driven by the head's motion.
var _ear_swing := Vector2.ZERO
var _ear_vel := Vector2.ZERO
var _last_head := Vector3.ZERO
var _head_vel := Vector3.ZERO
## Sitting, worked out from the skeleton: the body's pitch that stands the forelegs
## straight, and how far each paw is brought in under the body (a shuffle as it sits: the
## forepaws under the shoulders, the hind paws a little ahead of the hips).
var _sit_pitch := 0.6
var _sit_shift := {}
## The paws' knuckles in the world as last posed.
var _paws := {}
## How far the legs fell short of their planted paws last frame (m), how much lower the
## body goes for it, and where the hips were put this frame (rig frame offset).
var _short := 0.0
var _crouch := 0.0
var _hips := Vector3.ZERO


static func create() -> DogRig:
	var rig := DogRig.new()
	rig.name = "Rig"
	var scene := _load()
	if scene == null:
		push_error("DogRig: no model at %s" % MODEL_PATH)
		return rig
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	rig.add_child(model)
	rig._setup(model)
	return rig


static func _load() -> PackedScene:
	if _scene == null:
		if ResourceLoader.load_threaded_get_status(MODEL_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_scene = ResourceLoader.load_threaded_get(MODEL_PATH) as PackedScene
		if _scene == null and ResourceLoader.exists(MODEL_PATH):
			_scene = load(MODEL_PATH) as PackedScene
	return _scene


## Starts loading the model on a background thread.
static func preload_model() -> void:
	if _scene == null and ResourceLoader.exists(MODEL_PATH) \
			and ResourceLoader.load_threaded_get_status(MODEL_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(MODEL_PATH)


## The graphics preset (ULTRA where there are no settings, e.g. in tools).
static func _quality() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("Settings") if tree else null
	return int(settings.get("quality")) if settings else FUR_LAYERS.size() - 1


# --- Setup ---------------------------------------------------------------------------------

func _setup(model: Node3D) -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for bone in BONES:
		var idx := skeleton.find_bone(bone)
		if idx >= 0:
			_b[bone] = idx
		else:
			push_warning("DogRig: no bone %s" % bone)
	_to_rig = _rel(skeleton, self)
	_from_rig = _to_rig.affine_inverse()
	for bone: String in _b:
		_prepare_bone(_b[bone])
	for leg in LEGS:
		_prepare_leg(leg)
	_prepare_sit()
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		meshes.append(mi)
		# Small and moving: no GI voxelization, out of the rain-blocker heightfield.
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.layers = 2
		if mi.name == &"Fur":
			fur = mi
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, _material(mi, si))
	apply_quality()


## Shell fur by the graphics preset (none on LOW); the coat a little darker under it.
func apply_quality() -> void:
	var layers: int = FUR_LAYERS[clampi(_quality(), 0, FUR_LAYERS.size() - 1)]
	if fur:
		fur.set_instance_shader_parameter(&"fur_layers", float(layers))
		fur.visible = layers > 0
	for mi in meshes:
		if mi != fur:
			mi.set_instance_shader_parameter(&"skin_shade", 0.86 if layers > 0 else 1.0)


static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _prepare_bone(idx: int) -> void:
	var frame := _to_rig.basis.get_rotation_quaternion().inverse()
	var br := skeleton.get_bone_global_rest(idx).basis.get_rotation_quaternion()
	var parent := skeleton.get_bone_parent(idx)
	var pr := Quaternion.IDENTITY
	var pbasis := Basis.IDENTITY
	if parent >= 0:
		pbasis = skeleton.get_bone_global_rest(parent).basis
		pr = pbasis.get_rotation_quaternion()
	_conv[idx] = [pr.inverse() * frame, frame.inverse() * br, pbasis.inverse()]


func _rest_rig(bone: String) -> Vector3:
	return _to_rig * skeleton.get_bone_global_rest(_b[bone]).origin


## A leg's rest geometry (rig frame): its joints, the bones' lengths, where its paw stands
## (the knuckle joint, "mcp"), the pastern's angle from the vertical (+ leaning back) and
## the paw's direction.
func _prepare_leg(leg: String) -> void:
	for part in ["_up", "_lo", "_ft", "_toe", "_tip"]:
		if not _b.has(leg + part):
			return
	var hip := _rest_rig(leg + "_up")
	var knee := _rest_rig(leg + "_lo")
	var wrist := _rest_rig(leg + "_ft")
	var mcp := _rest_rig(leg + "_toe")
	var tip := _rest_rig(leg + "_tip")
	var d := wrist - mcp
	_legs[leg] = {
		"up": _b[leg + "_up"], "lo": _b[leg + "_lo"], "ft": _b[leg + "_ft"], "toe": _b[leg + "_toe"],
		"sh": _b.get(leg + "_sh", -1),
		"lo_local": skeleton.get_bone_rest(_b[leg + "_lo"]).origin, "ft_local": skeleton.get_bone_rest(_b[leg + "_ft"]).origin,
		"toe_local": skeleton.get_bone_rest(_b[leg + "_toe"]).origin, "tip_local": skeleton.get_bone_rest(_b[leg + "_tip"]).origin,
		"l1": hip.distance_to(knee), "l2": knee.distance_to(wrist), "l3": wrist.distance_to(mcp), "l4": mcp.distance_to(tip),
		"hip": hip, "foot0": mcp, "c_h": mcp.y, "tip_h": tip.y,
		"phi0": atan2(d.z, d.y), "toe_dir": (tip - mcp).normalized(),
		"front": leg.begins_with("f"), "side": -1.0 if leg.ends_with("l") else 1.0,
		# Gait state: planted at `lock` (world), or swinging from `from` (rig) to where it lands.
		"planted": true, "swing": false, "lock": Vector3.INF, "u": 0.0, "p": 0.0, "from": mcp, "cur": mcp,
		"phi": atan2(d.z, d.y), "curl": 0.0,
	}


## The body's pitch sitting (hips down and back) that leaves the forelegs straight but for
## a little give at the elbow over paws just ahead of the shoulders, and the paws' shuffle
## in under the body.
func _prepare_sit() -> void:
	if not (_legs.has("fl") and _legs.has("rl")):
		return
	var F: Dictionary = _legs["fl"]
	var R: Dictionary = _legs["rl"]
	var root := _rest_rig("root")
	var hips := root + Vector3(0, SIT_HIPS.x, SIT_HIPS.y)
	var phi: float = F["phi0"]
	var l3: float = F["l3"]
	var wrist_h := float(F["c_h"]) + cos(phi) * l3
	var want := (float(F["l1"]) + float(F["l2"])) * 0.965
	var shoulder0: Vector3 = F["hip"]
	var lo := 0.0
	var hi := 1.3
	for i in 30:
		var th := (lo + hi) * 0.5
		var sy := hips.y + (Basis(Vector3.RIGHT, th) * (shoulder0 - root)).y
		if sy - wrist_h < want:
			lo = th
		else:
			hi = th
	_sit_pitch = lo
	var shoulder := hips + Basis(Vector3.RIGHT, lo) * (shoulder0 - root)
	var hip := hips + Basis(Vector3.RIGHT, lo + SIT_TUCK) * ((R["hip"] as Vector3) - root)
	for leg: String in _legs:
		var L: Dictionary = _legs[leg]
		var n: Vector3 = L["foot0"]
		var z := shoulder.z - 0.02 - sin(phi) * l3 if L["front"] else hip.z - 0.06
		_sit_shift[leg] = Vector3(0, 0, z - n.z)


# --- Materials -----------------------------------------------------------------------------

func _material(mi: MeshInstance3D, si: int) -> Material:
	var key := "%s/%d" % [mi.name, si]
	if _materials.has(key):
		return _materials[key]
	var src := mi.mesh.surface_get_material(si)
	var sm := src as StandardMaterial3D
	var m := ShaderMaterial.new()
	if mi.name == &"Fur":
		m.shader = load("res://shaders/dog_fur.gdshader")
		m.set_shader_parameter(&"strands", load(STRANDS))
		m.set_shader_parameter(&"strand_scale", STRAND_SCALE)
		m.set_shader_parameter(&"layer_count", 14.0)
	else:
		m.shader = load("res://shaders/dog_coat.gdshader")
		if sm:
			m.set_shader_parameter(&"normal_tex", sm.normal_texture)
			m.set_shader_parameter(&"orm_tex", sm.roughness_texture)
	if sm:
		m.set_shader_parameter(&"albedo_tex", sm.albedo_texture)
	_materials[key] = m
	return m


# --- Where things are ------------------------------------------------------------------------

## A bone's joint in the world as posed.
func bone_world(bone: String) -> Vector3:
	if not _b.has(bone):
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(_b[bone]).origin


## The world point on the dog's back, behind the withers, where a stroking hand goes.
func pet_world() -> Vector3:
	return bone_world("pet")


func nose_world() -> Vector3:
	return bone_world("nose")


## The paws' knuckle joints in the world (fl, fr, rl, rr) as last posed (where they are
## drawn) and how high above its sole each stands in the model (m).
func paw_world(leg: String) -> Vector3:
	return _paws.get(leg, bone_world(leg + "_toe"))


func paw_height(leg: String) -> float:
	return float((_legs.get(leg, {}) as Dictionary).get("c_h", 0.03))


## How many times a paw has been set down.
func paw_steps(leg: String) -> int:
	return int((_legs.get(leg, {}) as Dictionary).get("steps", 0))


## Whether a paw is set down (not swinging).
func paw_planted(leg: String) -> bool:
	return bool((_legs.get(leg, {}) as Dictionary).get("planted", true))


## Eased pose amounts for the owner and tests: sitting and lying 0..1.
func sit_amount() -> float:
	return _sit


func lie_amount() -> float:
	return _lie


## The gait's briskness (0 standing .. 1 walking .. 1.3).
func gait_amount() -> float:
	return _gamp


## Where the nose is (rig frame) with the head down in a bowl, standing square.
func eat_nose_rig() -> Vector3:
	if not _b.has("nose"):
		return Vector3(0, 0.05, -0.6)
	var keep := [_nose, _sit, _lie, _look, _bark, _gamp, _rest_head, _lean]
	_nose = 1.0
	_sit = 0.0
	_lie = 0.0
	_look = Vector2.ZERO
	_bark = 0.0
	_gamp = 0.0
	_rest_head = 0.0
	_lean = 0.0
	skeleton.reset_bone_poses()
	_pose_body(0.0)
	var at := _to_rig * skeleton.get_bone_global_pose(_b["nose"]).origin
	skeleton.reset_bone_poses()
	_nose = keep[0]
	_sit = keep[1]
	_lie = keep[2]
	_look = keep[3]
	_bark = keep[4]
	_gamp = keep[5]
	_rest_head = keep[6]
	_lean = keep[7]
	return at


## A bark: the head jerks up and forward, the chest heaves, the jaw drops a little.
func woof() -> void:
	_bark = 1.0


# --- Animation -----------------------------------------------------------------------------

## The pose for this frame: `speed` (m/s over the ground, forward) drives the gait.
func animate(delta: float, speed: float) -> void:
	if skeleton == null or delta <= 0.0:
		return
	_time += delta
	_ease(delta)
	var xf := _world_xf()
	_update_gait(delta, speed, xf)
	skeleton.reset_bone_poses()
	_pose_body(delta)
	_pose_legs(xf)
	if _short > 0.001:
		# A leg fell short of its planted paw: the body comes down to it now (and stays
		# down while it has to, see _pose_body), the legs solved again.
		_crouch = maxf(_crouch, minf(_short * 1.15, 0.05))
		_hips.y -= _short * 1.15
		_offset("root", _hips)
		for leg: String in _legs:
			var L: Dictionary = _legs[leg]
			for key in ["up", "lo", "ft", "toe"]:
				var idx: int = L[key]
				skeleton.set_bone_pose_rotation(idx, skeleton.get_bone_rest(idx).basis.get_rotation_quaternion())
		_pose_legs(xf)
	_track_head(delta)
	var sk := xf * _to_rig
	for leg: String in _legs:
		_paws[leg] = sk * skeleton.get_bone_global_pose(_legs[leg]["toe"]).origin


func _world_xf() -> Transform3D:
	if not is_inside_tree():
		return transform
	return global_transform if Engine.is_in_physics_frame() else get_global_transform_interpolated()


## Eases the pose amounts toward what the owner asks: sitting down takes SIT_TIME, lying
## down from sitting LIE_TIME more (and getting up the other way round: a lying dog sits
## up first).
func _ease(delta: float) -> void:
	var want_sit := 1.0 if pose != Pose.STAND else 0.0
	var want_lie := 1.0 if pose == Pose.LIE else 0.0
	if want_lie > _lie and _sit < 0.97:
		want_lie = _lie
	if want_sit < _sit and _lie > 0.03:
		want_sit = _sit
	_sit = move_toward(_sit, want_sit, delta / SIT_TIME)
	_lie = move_toward(_lie, want_lie, delta / LIE_TIME)
	var k := 1.0 - exp(-delta * 3.0)
	_nose = move_toward(_nose, clampf(nose_down, 0.0, 1.0), delta * 1.6)
	_lean = lerpf(_lean, clampf(lean, -1.0, 1.0), k)
	_ears = lerpf(_ears, clampf(ears_back, 0.0, 1.0), k)
	_rest_head = move_toward(_rest_head, 1.0 if head_rest and pose == Pose.LIE else 0.0, delta * 0.6)
	# The wag: amplitude and rate follow the mood; the phase runs on at the rate.
	var w := clampf(wag, 0.0, 1.0)
	_wag_amp = lerpf(_wag_amp, 0.05 + 0.6 * w, 1.0 - exp(-delta * 4.0))
	_wag_rate = lerpf(_wag_rate, 1.2 + 3.6 * w, 1.0 - exp(-delta * 4.0))
	_wag_phase = fposmod(_wag_phase + _wag_rate * delta, 1.0)
	_bark = move_toward(_bark, 0.0, delta / 0.4)
	_pant = move_toward(_pant, 1.0 if panting else 0.0, delta * 0.8)
	var rate := lerpf(0.35, 3.2, _pant)
	_breath = fposmod(_breath + rate * delta, 1.0)
	# Looking about now and then when not looking at anything.
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(1.5, 5.0)
		_look_about_to = Vector2(randf_range(-0.7, 0.7), randf_range(-0.15, 0.2)) if randf() < 0.65 else Vector2.ZERO
	_look_about = _look_about.lerp(_look_about_to, 1.0 - exp(-delta * 2.5))
	var goal := _look_about * (1.0 - _nose)
	if look_at_point.is_finite() and is_inside_tree():
		var t := global_transform.affine_inverse() * look_at_point
		var from := _rest_rig("head") + Vector3(0, -_sit * 0.05, 0)
		var d := t - from
		goal = Vector2(clampf(atan2(-d.x, -d.z), -1.3, 1.3), clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.75))
	_look = _look.lerp(goal, 1.0 - exp(-delta * 4.0))
	# Weight shifted from one side to the other now and then, standing.
	_shift_timer -= delta
	if _shift_timer <= 0.0:
		_shift_timer = randf_range(2.5, 7.0)
		_shift_to = randf_range(-1.0, 1.0)
	_shift = lerpf(_shift, _shift_to, 1.0 - exp(-delta * 1.5))


## The spine, neck, head, tail and ears.
func _pose_body(delta: float) -> void:
	var s := smoothstep(0.0, 1.0, _sit)
	var l := smoothstep(0.0, 1.0, _lie)
	var ws := s * (1.0 - l)
	var wl := l
	var still := 1.0 - clampf(_gamp, 0.0, 1.0)
	var ph := TAU * _phase
	# Gait: walking the body dips at each step, trotting it rises between the beats; it
	# rolls a little over the side that carries it.
	var bob := (-(0.5 + 0.5 * cos(2.0 * ph - 0.6)) * 0.008 * (1.0 - _trot) + (0.5 - 0.5 * cos(2.0 * ph)) * 0.014 * _trot) \
			* clampf(_gamp, 0.0, 1.0)
	var roll := sin(ph) * 0.02 * clampf(_gamp, 0.0, 1.0)
	var breath := sin(TAU * _breath)
	# Eating or sniffing: the forequarters come down a little.
	var dip := _nose * (1.0 - ws) * (1.0 - wl)
	var hips := Vector3(0.0, SIT_HIPS.x, SIT_HIPS.y) * ws + Vector3(0.0, LIE_BODY.x, LIE_BODY.y) * wl
	# A leg that fell short of its planted paw brings the body down to it.
	_crouch = move_toward(_crouch, clampf(_short * 1.2, 0.0, 0.05), delta * (0.8 if _short > _crouch else 0.05))
	hips.y += bob + breath * 0.002 * still - lerpf(GAIT_CROUCH.x, GAIT_CROUCH.y, _trot) * clampf(_gamp, 0.0, 1.0) - _crouch
	hips.x += _shift * 0.006 * still * (1.0 - ws - wl)
	var pitch := _sit_pitch * ws + LIE_PITCH * wl - 0.07 * dip + _bark * 0.03
	# A hard wag swings the hips.
	var wag_swing := sin(TAU * _wag_phase) * _wag_amp
	var hip_yaw := wag_swing * 0.14 * smoothstep(0.35, 0.6, _wag_amp) * (1.0 - ws) * (1.0 - wl)
	_hips = hips
	_offset("root", hips)
	_rot("root", Vector3(pitch, hip_yaw, roll - _lean * 0.1 * maxf(ws, 0.4)))
	# Sitting the rump tucks under; lying the hips roll a little onto one side.
	_rot("pelvis", Vector3(SIT_TUCK * ws + 0.05 * wl, -hip_yaw * 0.5, 0.12 * wl))
	_rot("spine1", Vector3(-0.08 * ws + breath * 0.004, -hip_yaw * 0.8, 0))
	_rot("spine2", Vector3(-0.06 * ws + breath * lerpf(0.008, 0.02, _pant) - 0.05 * wl, 0, -_lean * 0.05))
	# Neck and head: level against the body's pitch, down to the ground, up and turned to
	# what it looks at; lying, up and alert or resting on the forepaws.
	var yaw := _look.x
	var up := _look.y
	var bark := sin(PI * minf((1.0 - _bark) * 1.6, 1.0)) * _bark
	var nd := _nose
	var level := -_sit_pitch * ws - LIE_PITCH * wl
	var rest := _rest_head
	var pant_bob := sin(TAU * _breath) * 0.02 * _pant
	var nod := -(0.5 + 0.5 * cos(2.0 * ph - TAU * 0.44)) * 0.04 * clampf(_gamp, 0.0, 1.0)
	_rot("neck1", Vector3(level * 0.45 - nd * 0.95 + up * 0.35 + 0.12 * wl - rest * 0.62 + nod, yaw * 0.35, 0))
	_rot("neck2", Vector3(level * 0.3 - nd * 0.4 + up * 0.3 - rest * 0.1 + bark * 0.15, yaw * 0.3, 0))
	_rot("head", Vector3(level * 0.25 - nd * 0.45 + up * 0.35 + rest * 0.42 + bark * 0.12 + pant_bob, yaw * 0.35,
			-yaw * 0.08 - _lean * 0.15))
	var chew := (0.04 + 0.05 * sin(_time * 11.0)) if chewing else 0.0
	_rot("jaw", Vector3(chew + bark * 0.22 + _pant * (0.1 + 0.02 * sin(TAU * _breath)), 0, 0))
	# Tail: carried by mood (low and relaxed, higher when happy or on the move, lying along
	# the ground sitting or lying), wagging from the base with the rest following.
	var happy := smoothstep(0.3, 0.8, _wag_amp)
	var carry := lerpf(1.05, 0.55, happy) - 0.25 * clampf(_gamp, 0.0, 1.3) * (1.0 - happy)
	carry = lerpf(carry, 0.35, ws)
	carry = lerpf(carry, 0.95, wl)
	var droop := lerpf(0.28, 0.12, happy)
	var sweep := wag_swing * (1.0 + 0.4 * (ws + wl))
	for i in 4:
		var lag := float(i) * 0.09
		var sw := sin(TAU * (_wag_phase - lag)) * _wag_amp * (1.0 + 0.25 * float(i)) * (0.55 if i == 0 else 0.4)
		var p := carry if i == 0 else droop * (1.0 - 0.2 * float(i))
		if i == 1:
			p += -0.25 * ws + 0.1 * wl
		_rot("tail%d" % (i + 1), Vector3(p, sw if i > 0 else sweep * 0.9, 0))
	# Ears: hanging, swinging with the head's motion, laid back when content, a little up
	# at a bark.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var n := "l" if i == 0 else "r"
		var swing := _ear_swing[i]
		var back := _ears * 0.35
		_rot("ear_" + n, Vector3(-back + swing * 0.7 - bark * 0.2, 0, side * (0.06 + 0.1 * bark + _ears * 0.05 - swing * 0.2)))
		_rot("ear_%s2" % n, Vector3(swing * 0.5, 0, 0))


## The head's motion drives the ears' swing (a spring each).
func _track_head(delta: float) -> void:
	if not _b.has("head"):
		return
	var h := _to_rig * skeleton.get_bone_global_pose(_b["head"]).origin
	var v := (h - _last_head) / delta
	var acc := (v - _head_vel) / delta
	_last_head = h
	_head_vel = v
	# (Posed seldom far off, the spring is stepped no longer than it stays steady for.)
	var dt := minf(delta, 0.05)
	for i in 2:
		var force := clampf(acc.z * 0.02 + acc.y * 0.015 + float(i * 2 - 1) * acc.x * 0.01, -8.0, 8.0)
		_ear_vel[i] += (-_ear_swing[i] * 90.0 - _ear_vel[i] * 7.0 + force) * dt
		_ear_swing[i] = clampf(_ear_swing[i] + _ear_vel[i] * dt, -0.5, 0.5)


# --- Legs: gait and IK ----------------------------------------------------------------------

## Stride cycles a second at `v` m/s.
static func gait_rate(v: float) -> float:
	return WALK_RATE * pow(clampf(v / WALK_SPEED, 0.35, 3.5), RATE_EXP)


## Advances the gait and works out where each paw goes (leg["cur"], rig frame) and its
## pastern's angle and curl. A planted paw stays where it was set down in the world; at
## its turn it lifts and swings forward to land ahead of its place (as far as the stance
## it will cover), so a step is the ground covered while it is down and it never slides.
## Standing, a paw left off its place steps back to it at its turn and the clock stops
## once all stand square.
func _update_gait(delta: float, speed: float, xf: Transform3D) -> void:
	var v := maxf(speed, 0.0)
	var moving := v > 0.04
	_trot = move_toward(_trot, 1.0 if v > TROT_FROM else 0.0, delta * 2.5)
	var inv := xf.affine_inverse()
	var settling := false
	var seated := _sit > 0.02 or _lie > 0.02
	for leg: String in _legs:
		var L: Dictionary = _legs[leg]
		if not (L["lock"] as Vector3).is_finite():
			L["lock"] = xf * _grounded(L["foot0"], xf, L["c_h"])
		if L["swing"] or (not seated and _off_place(L, inv) > SETTLE_OFF):
			settling = true
	var rate := gait_rate(v) if moving else gait_rate(WALK_SPEED) * 0.9
	var run := moving or settling
	_gamp = move_toward(_gamp, clampf(v / WALK_SPEED, 0.0, 1.3) if moving else 0.0, delta * 3.0)
	if run:
		_phase = fposmod(_phase + rate * delta, 1.0)
	var duty := lerpf(DUTY_WALK, DUTY_TROT, _trot)
	var stride := v / rate if moving else 0.0
	var stance := stride * duty
	for leg: String in _legs:
		var L: Dictionary = _legs[leg]
		var front: bool = L["front"]
		var n: Vector3 = L["foot0"]
		var ln := float(L["l1"]) + float(L["l2"]) + float(L["l3"])
		var touch := lerpf(float(TOUCH_WALK[leg]), float(TOUCH_TROT[leg]), _trot)
		var u := fposmod(_phase - touch, 1.0)
		var prev: float = L["u"]
		L["u"] = u
		var turn := run and ((prev < duty and u >= duty) or (u < prev and prev < duty))
		var phi0: float = L["phi0"]
		if L["planted"]:
			var here: Vector3 = inv * (L["lock"] as Vector3)
			var off := Vector2(here.x - n.x, here.z - n.z)
			if off.length() > ln * 1.5:
				# Far off (the dog was moved, or walked on unseen): under it again.
				L["lock"] = xf * _grounded(n, xf, L["c_h"])
				here = inv * (L["lock"] as Vector3)
				off = Vector2.ZERO
			L["cur"] = here
			var lift := false
			if seated:
				lift = false
			elif moving and (turn or off.length() > stance * 0.5 + ln * 0.45):
				lift = true
			elif not moving and turn and off.length() > SETTLE_OFF * 0.5:
				lift = true
			elif (not moving or here.z > n.z or u > duty * 0.15) and _out_of_reach(L, here):
				# Left as far as the leg reaches (behind on a long step, out to the side as
				# the body turns): it steps now rather than be dragged. (Just set down
				# reaching forward, the leg is given a moment to come over it.)
				lift = true
			if lift:
				L["planted"] = false
				L["swing"] = true
				L["from"] = here
				L["p"] = 0.0
				# The share of a cycle until its touchdown: a paw lifted early swings longer,
				# so the pairs stay in step (standing, a plain swing's length).
				L["left"] = maxf(fposmod(-u, 1.0), (1.0 - duty) * 0.5) if moving else 1.0 - duty
			else:
				# Late in the stance the heel and the wrist lift as it rolls over its toes.
				var behind := clampf((here.z - n.z) / ln, -0.3, 0.6)
				L["phi"] = lerpf(float(L["phi"]), phi0 - behind * (1.6 if front else 1.1), 1.0 - exp(-delta * 20.0))
				L["curl"] = lerpf(float(L["curl"]), 0.0, 1.0 - exp(-delta * 12.0))
		if L["swing"]:
			L["p"] = float(L["p"]) + rate * delta / maxf(float(L.get("left", 1.0 - duty)), 0.05)
			var p := minf(float(L["p"]), 1.0)
			# Landing half a stance ahead of its place under the body (a forepaw a little
			# less: the foreleg reaches less far forward than it swings back).
			var land := n + Vector3(0, 0, -stance * (0.36 if front else 0.46))
			var from: Vector3 = L["from"]
			var t := smoothstep(0.05, 0.95, p) if front else smoothstep(0.0, 1.0, p)
			var cur := from.lerp(land, t)
			var step_len := Vector2(land.x - from.x, land.z - from.z).length()
			var h := (LIFT.x if front else LIFT.y) * (1.0 + 0.35 * _trot) * clampf(step_len / 0.25, 0.35, 1.0)
			var arch := sin(PI * pow(p, 0.8 if front else 1.0))
			cur.y = lerpf(from.y, land.y, t) + h * arch
			L["cur"] = cur
			# The paw folds back as it leaves the ground and reaches out to land.
			var fold := sin(PI * minf(p * 1.4, 1.0)) * (1.0 - smoothstep(0.55, 0.95, p))
			if front:
				L["phi"] = phi0 - fold * 1.9 * clampf(step_len / 0.2, 0.4, 1.0) + smoothstep(0.7, 1.0, p) * (1.0 - p) * 0.3
			else:
				L["phi"] = phi0 + fold * 0.7 * clampf(step_len / 0.2, 0.4, 1.0)
			L["curl"] = fold * (0.9 if front else 0.6)
			if p >= 1.0:
				L["swing"] = false
				L["planted"] = true
				L["steps"] = int(L.get("steps", 0)) + 1
				L["lock"] = xf * _grounded(land, xf, L["c_h"])
				L["cur"] = inv * (L["lock"] as Vector3)


## Whether the leg, as the body stands now, can't reach its paw at `mcp` (rig frame)
## any more.
func _out_of_reach(L: Dictionary, mcp: Vector3) -> bool:
	var hip := _to_rig * skeleton.get_bone_global_pose(L["up"]).origin
	var phi: float = L["phi"]
	var wrist := mcp + Vector3(0.0, cos(phi), sin(phi)) * float(L["l3"])
	return hip.distance_to(wrist) > (float(L["l1"]) + float(L["l2"])) * 0.985


## Where a planted paw stands off its place under the body (m, level).
func _off_place(L: Dictionary, inv: Transform3D) -> float:
	if not L["planted"]:
		return 1.0
	var here: Vector3 = inv * (L["lock"] as Vector3)
	var n: Vector3 = L["foot0"]
	return Vector2(here.x - n.x, here.z - n.z).length()


## A paw's knuckle joint (rig frame) put down on the ground below it.
func _grounded(p: Vector3, xf: Transform3D, c_h: float) -> Vector3:
	var w := xf * Vector3(p.x, 0.0, p.z)
	var gy := float(ground.call(w.x, w.z)) if ground.is_valid() else xf.origin.y
	var l := xf.affine_inverse() * Vector3(w.x, gy, w.z)
	return Vector3(p.x, l.y + c_h, p.z)


## The legs: each paw where the gait (standing, walking) or the pose (sitting, lying) puts
## it, solved by IK.
func _pose_legs(xf: Transform3D) -> void:
	var s := smoothstep(0.0, 1.0, _sit)
	var l := smoothstep(0.0, 1.0, _lie)
	var ws := s * (1.0 - l)
	var wl := l
	var body_q := Basis.from_euler(Vector3(_sit_pitch * ws, 0, 0))
	_short = 0.0
	for leg: String in _legs:
		var L: Dictionary = _legs[leg]
		var front: bool = L["front"]
		var n: Vector3 = L["foot0"]
		var mcp: Vector3 = L["cur"]
		var phi: float = L["phi"]
		var curl: float = L["curl"]
		var toe: Vector3 = L["toe_dir"]
		# Sitting: the hind pasterns (hocks down) lie flat along the ground behind the
		# paws. Lying: the forearms flat on the ground ahead, the hind legs folded under.
		mcp += (_sit_shift.get(leg, Vector3.ZERO) as Vector3) * ws
		if not front:
			phi = lerpf(phi, 1.42, ws)
		if wl > 0.0:
			var lying := n + (Vector3(0, 0, -LIE_REACH) if front else Vector3(0.03 * float(L["side"]), 0, -0.1))
			lying.y = mcp.y
			mcp = mcp.lerp(lying, wl)
			phi = lerpf(phi, 1.45, wl)
		var pastern := Vector3(0.0, cos(phi), sin(phi))
		toe = Basis(Vector3.RIGHT, -curl) * toe
		if front and L["sh"] >= 0:
			# The shoulder blade swings with the foreleg (a share of its reach forward or back).
			var wrist := mcp + pastern * float(L["l3"])
			var hip: Vector3 = L["hip"]
			var sw := atan2(-(wrist.z - hip.z), hip.y - wrist.y) - atan2(-(n.z - hip.z), hip.y - n.y)
			_rot(("fl" if leg == "fl" else "fr") + "_sh", Vector3(sw * 0.55 * (1.0 - wl), 0, 0))
		var pole := body_q * (Vector3(0, 0.3, 1) if front else Vector3(0, -0.15, -1))
		pole.x += float(L["side"]) * (0.15 if front else 0.25)
		_solve_leg(L, mcp, pastern, toe, pole)


## Two-bone IK from the shoulder (hip) to the wrist (hock), which stands the pastern's
## length up from the knuckle along `pastern`; then the pastern aimed at the knuckle and
## the paw along `toe` (all rig frame).
func _solve_leg(L: Dictionary, mcp_rig: Vector3, pastern_rig: Vector3, toe_rig: Vector3, pole_rig: Vector3) -> void:
	var l1: float = L["l1"]
	var l2: float = L["l2"]
	var l3: float = L["l3"]
	var hip := skeleton.get_bone_global_pose(L["up"]).origin
	var mcp := _from_rig * mcp_rig
	var pastern := (_from_rig.basis * pastern_rig).normalized()
	var wrist := mcp + pastern * l3
	var to := wrist - hip
	if L["planted"] and _lie < 0.01:
		_short = maxf(_short, to.length() - (l1 + l2) * 0.999)
	var d := clampf(to.length(), absf(l1 - l2) + 0.0001, (l1 + l2) * 0.999)
	var axis := to.normalized()
	var pole := _from_rig.basis * pole_rig
	pole = (pole - axis * axis.dot(pole)).normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var knee := hip + axis * (l1 * ca) + pole * (l1 * sqrt(1.0 - ca * ca))
	var reach := hip + axis * d
	_aim(L["up"], L["lo_local"], knee - hip)
	_aim(L["lo"], L["ft_local"], reach - knee)
	_aim(L["ft"], L["toe_local"], mcp - reach)
	_aim(L["toe"], L["tip_local"], _from_rig.basis * toe_rig)


## Turns bone `idx` (from its pose under its posed parent) so the direction to its
## child at `child_local` points along `dir` (skeleton space).
func _aim(idx: int, child_local: Vector3, dir: Vector3) -> void:
	if dir.length_squared() < 1e-12:
		return
	var parent := skeleton.get_bone_parent(idx)
	var pg := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var g := pg * Basis(skeleton.get_bone_pose_rotation(idx))
	var q := Quaternion((g * child_local).normalized(), dir.normalized())
	skeleton.set_bone_pose_rotation(idx, (pg.inverse() * (Basis(q) * g)).get_rotation_quaternion())


## Rotation in the dog's frame (euler, radians) -> the bone's pose, as if its parent were
## at rest; chained bones compose like a rig built in that frame.
func _rot(bone: String, euler: Vector3) -> void:
	var idx: int = _b.get(bone, -1)
	if idx < 0:
		return
	var c: Array = _conv[idx]
	skeleton.set_bone_pose_rotation(idx, (c[0] as Quaternion) * Quaternion.from_euler(euler) * (c[1] as Quaternion))


func _offset(bone: String, offset: Vector3) -> void:
	var idx: int = _b.get(bone, -1)
	if idx < 0:
		return
	var c: Array = _conv[idx]
	var frame := _to_rig.basis.get_rotation_quaternion().inverse()
	var unit := 1.0 / _to_rig.basis.get_scale().x
	skeleton.set_bone_pose_position(idx, skeleton.get_bone_rest(idx).origin + (c[2] as Basis) * (frame * offset * unit))
