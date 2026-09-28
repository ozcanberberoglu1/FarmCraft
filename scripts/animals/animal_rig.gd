@tool
class_name AnimalRig
extends Node3D
## A sculpted, skinned animal model plus its procedural animation: walk and gallop
## gaits, grazing, eating at a trough, lying down, ear flicks, tail swishes and
## idle head movement. Drives Skeleton3D bone poses.

enum Mode { IDLE, WALK, GRAZE, EAT, SLEEP, RUN }

const PARAMS := {
	&"cow": {"stride": 1.35, "walk_speed": 0.8, "swing": 0.34, "knee": 0.6, "neck_down": 0.5, "head_down": 0.35,
		"lie_drop": 0.52, "baby_scale": 0.52, "hip_height": 1.0},
	&"horse": {"stride": 1.7, "walk_speed": 1.1, "swing": 0.38, "knee": 0.75, "neck_down": 0.62, "head_down": 0.3,
		"lie_drop": 0.62, "baby_scale": 0.55, "hip_height": 1.08},
	&"sheep": {"stride": 0.7, "walk_speed": 0.75, "swing": 0.42, "knee": 0.55, "neck_down": 0.75, "head_down": 0.35,
		"lie_drop": 0.26, "baby_scale": 0.5, "hip_height": 0.45},
	&"chicken": {"stride": 0.16, "walk_speed": 0.8, "swing": 0.55, "knee": 0.7, "neck_down": 1.0, "head_down": 0.5,
		"lie_drop": 0.1, "baby_scale": 0.42, "hip_height": 0.2, "biped": true},
}
const SCULPT_PATH := "res://art/models/animals/%s.scn"
## Lying down: [upper, lower, foot] joint angles (front, rear, birds) unless cfg overrides them.
const FOLD_FRONT := [-1.3, 2.45, 0.4]
const FOLD_REAR := [1.1, -2.1, -0.4]
const FOLD_BIPED := [-1.1, 1.9, 0.4]
## Gallop: leg phase offset -> phase within the bound.
const GALLOP := {0.0: 0.0, 0.5: 0.1, 0.25: 0.45, 0.75: 0.55}

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
			var left: bool = side[1] < 0.0
			var offset := 0.0
			if biped:
				offset = 0.0 if left else 0.5
			else:
				offset = (0.25 if left else 0.75) if front else (0.0 if left else 0.5)
			legs.append({"up": _b[prefix + "_up"], "lo": _b[prefix + "_lo"], "ft": _b.get(prefix + "_ft", -1),
				"front": front, "offset": offset})


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


## Sheep: 1 = full fleece, 0 = freshly shorn.
func set_wool(amount: float) -> void:
	mesh.set_instance_shader_parameter("wool_amount", clampf(amount, 0.0, 1.0))


# --- Animation ------------------------------------------------------------------------------

func animate(delta: float, speed: float, mode: int) -> void:
	_time += delta
	var biped: bool = cfg.get("biped", false)
	var running := mode == Mode.RUN
	if running:
		# Galloping covers ground with fewer, longer bounds.
		speed *= 0.45
	var stride: float = cfg["stride"] * (1.6 if running else 1.0)
	_phase = fmod(_phase + delta * speed / stride, 1.0)
	var amp := clampf(speed / float(cfg["walk_speed"]), 0.0, 1.3) * float(cfg["swing"])
	if running:
		amp = float(cfg["swing"]) * 1.55
	_lie = move_toward(_lie, 1.0 if mode == Mode.SLEEP else 0.0, delta * 0.7)
	var head_target := 0.0
	if mode == Mode.GRAZE:
		head_target = 1.0
	elif mode == Mode.EAT:
		head_target = 0.6
	_head_down = lerpf(_head_down, head_target, clampf(delta * 2.5, 0.0, 1.0))
	var lie := smoothstep(0.0, 1.0, _lie)
	var knee_scale := float(cfg["knee"]) / float(cfg["swing"])

	for leg in legs:
		var ph := TAU * (_phase + float(leg["offset"]))
		if running and not biped:
			ph = TAU * (_phase + float(GALLOP.get(leg["offset"], 0.0)))
		var swing := amp * sin(ph)
		var lift := maxf(0.0, cos(ph)) * amp * knee_scale
		var front: bool = leg["front"]
		var knee := -lift if (front or biped) else lift * 0.9
		var foot := lift * (0.6 if front else -0.5)
		var fold: Array = (cfg.get("fold_front", FOLD_FRONT) if front else cfg.get("fold_rear", FOLD_REAR)) \
				if not biped else FOLD_BIPED
		_pose_rot(leg["up"], Quaternion(Vector3.RIGHT, lerpf(swing, fold[0], lie)))
		_pose_rot(leg["lo"], Quaternion(Vector3.RIGHT, lerpf(knee, fold[1], lie)))
		if leg["ft"] >= 0:
			_pose_rot(leg["ft"], Quaternion(Vector3.RIGHT, lerpf(foot, fold[2], lie)))

	var hip: float = cfg["hip_height"]
	var bob := absf(sin(TAU * _phase * 2.0)) * amp * 0.035 * hip
	var root := _bone("root")
	if root >= 0:
		_pose_offset(root, Vector3(0, hip * _leg_extra + bob - lie * float(cfg["lie_drop"]), 0))
	var pitch := (sin(TAU * _phase) * 0.06 if running else 0.0) + lie * 0.03
	var roll := sin(TAU * _phase) * amp * 0.04
	_rot("body", Vector3(pitch, 0, roll))

	var idle := (1.0 - _head_down) * (1.0 - clampf(speed, 0.0, 1.0))
	var nd: float = cfg["neck_down"]
	var look_yaw := sin(_time * 0.37 + _seed) * 0.2 * idle
	var nod := sin(_time * 0.7 + _seed) * 0.04 * idle
	if running:
		nod += sin(TAU * _phase) * 0.08
	if biped:
		_peck = move_toward(_peck, 0.0, delta * 5.0)
		if mode == Mode.GRAZE or mode == Mode.EAT:
			_peck_timer -= delta
			if _peck_timer <= 0.0:
				_peck_timer = randf_range(0.35, 1.1)
				_peck = 1.0
		var bob_head := sin(TAU * _phase * 2.0) * 0.12 * clampf(speed * 2.0, 0.0, 1.0)
		_rot("neck1", Vector3(-_head_down * nd - _peck * 0.7 + bob_head - lie * 0.3, look_yaw * 1.5, 0))
	else:
		_rot("neck1", Vector3(-_head_down * nd * 0.55 + nod - lie * 0.2, look_yaw * 0.6, 0))
		_rot("neck2", Vector3(-_head_down * nd * 0.45, look_yaw * 0.4, 0))
	_rot("head", Vector3(-_head_down * float(cfg["head_down"]), look_yaw * 0.3, 0))

	# Ears flick now and then.
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(2.0, 7.0)
		_ear_flick = 1.0
	_ear_flick = move_toward(_ear_flick, 0.0, delta * 4.0)
	_rot("ear_l", Vector3(0, 0, -_ear_flick * 0.5))
	_rot("ear_r", Vector3(0, 0, _ear_flick * 0.3 * sin(_time * 3.0)))

	var sway := sin(_time * 1.4 + _seed) * 0.16 + sin(_time * 3.3 + _seed) * 0.05
	var lift_tail := (0.25 if running else 0.05) - lie * 0.2
	_rot("tail1", Vector3(-lift_tail, 0, sway))
	_rot("tail2", Vector3(-lift_tail * 0.5, 0, sway * 1.2))
	_rot("tail3", Vector3(0, 0, sway * 1.4))
	if biped:
		var flap := sin(_time * 18.0) * 0.4 * (1.0 if running else 0.0)
		_rot("wing_l", Vector3(0, 0, flap))
		_rot("wing_r", Vector3(0, 0, -flap))
