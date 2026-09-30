@tool
class_name RabbitRig
extends Node3D
## The wild rabbit's model and its procedural animation. The model is sculpted and
## skinned like the livestock's sculpts (SdfSculpt, AnimalBuilder; tools/build_rabbit.gd
## saves it to MODEL): a brown European rabbit in its sitting pose, facing -Z, with a
## pale belly, a white scut and black-tipped ears. RabbitRig drives its bones: sitting
## (breathing, nose and ear twitches, a hind-foot scratch), nibbling the grass, sitting
## up on alert, and the hop (both hind feet together, the front paws landing one after
## the other, the hind feet swinging past them) from a lazy hop to a flat-out bound
## with the ears laid back.

enum Mode { SIT, GRAZE, ALERT, HOP }

const MODEL := "res://art/models/wildlife/rabbit.scn"
## The wild coat: agouti brown, a cream belly (the shader's "points" zone).
const COAT := Color(0.44, 0.36, 0.27)
const BELLY := Color(0.86, 0.8, 0.7)
## Metres travelled per hop at a walk and flat out (the hop's rate follows the speed).
const STRIDE := Vector2(0.32, 1.35)
## How high the hops go at a walk and flat out (m).
const LIFT := Vector2(0.045, 0.16)

static var _scene: PackedScene

var skeleton: Skeleton3D
var mesh: MeshInstance3D
var _b := {}
var _phase := 0.0
var _time := 0.0
var _seed := 0.0
## Blended pose values (see _target).
var _pose := {}
var _twitch := 0.0
var _ear_flick := Vector2.ZERO
var _ear_timer := 1.0
var _scratch := 0.0
var _scratch_timer := 6.0


static func create() -> RabbitRig:
	var rig := RabbitRig.new()
	rig.name = "Rig"
	if _scene == null:
		_scene = load(MODEL) as PackedScene
	var model: Node3D = _scene.instantiate()
	rig.add_child(model)
	rig.skeleton = model.get_node("Skeleton")
	rig.mesh = rig.skeleton.get_node("Mesh")
	# Small and moving: no GI voxelization, out of the rain-blocker heightfield.
	rig.mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	rig.mesh.layers = 2
	for i in rig.skeleton.get_bone_count():
		rig._b[rig.skeleton.get_bone_name(i)] = i
	rig._seed = randf() * 100.0
	var shade := randf_range(0.88, 1.1)
	rig.mesh.set_instance_shader_parameter("coat_tint", Color(COAT.r * shade, COAT.g * shade, COAT.b * shade))
	rig.mesh.set_instance_shader_parameter("points_tint", BELLY)
	rig.mesh.set_instance_shader_parameter("hair_tint", COAT.darkened(0.4))
	return rig


## Starts loading the model on a background thread.
static func preload_model() -> void:
	if _scene == null and ResourceLoader.exists(MODEL) \
			and ResourceLoader.load_threaded_get_status(MODEL) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(MODEL)


## The pose for this frame: `speed` (m/s over the ground) drives the hop.
func animate(delta: float, speed: float, mode: int) -> void:
	_time += delta
	var target := _target(delta, speed, mode)
	# Hops are driven straight from their cycle; the rest eases in.
	var k := 1.0 - exp(-delta * (18.0 if mode == Mode.HOP else 7.0))
	for key: String in target:
		_pose[key] = lerpf(float(_pose.get(key, 0.0)), float(target[key]), k)
	_apply()


func _target(delta: float, speed: float, mode: int) -> Dictionary:
	var t := {"lift": 0.0, "body": 0.0, "chest": 0.0, "stretch": 0.0, "neck": 0.0, "head": 0.0, "ears": 0.0,
		"splay": 0.0, "fl": 0.0, "fl_lo": 0.0, "rl": 0.0, "rl_lo": 0.0, "rl_ft": 0.0, "tail": 0.0, "breath": 0.0}
	# Ear flicks and nose twitches now and then, whatever it does.
	_ear_timer -= delta
	if _ear_timer <= 0.0:
		_ear_timer = randf_range(0.8, 3.5)
		_ear_flick = Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
	_ear_flick = _ear_flick.lerp(Vector2.ZERO, 1.0 - exp(-delta * 3.0))
	_twitch = sin(_time * 22.0 + _seed) * (0.5 + 0.5 * sin(_time * 1.7 + _seed * 2.0))
	match mode:
		Mode.SIT:
			t["breath"] = sin(_time * 5.5 + _seed)
			t["head"] = 0.03 * _twitch
			t["ears"] = -0.15
			t["splay"] = 0.1
			# A scratch behind the ear with a hind foot, once in a while.
			_scratch_timer -= delta
			if _scratch_timer <= 0.0:
				_scratch_timer = randf_range(8.0, 20.0)
				_scratch = 1.2
			if _scratch > 0.0:
				_scratch -= delta
				var s := sin(_time * 30.0) * 0.25
				t["rl"] = 0.9 + s
				t["rl_lo"] = -0.6
				t["neck"] = -0.25
				t["head"] = -0.35
				t["ears"] = 0.35
		Mode.GRAZE:
			# Nose down in the grass, chewing.
			t["chest"] = -0.12
			t["neck"] = -0.55
			t["head"] = -0.5 + 0.06 * sin(_time * 9.0 + _seed)
			t["ears"] = 0.1
			t["splay"] = 0.2
			t["fl"] = 0.15
			t["breath"] = sin(_time * 5.5 + _seed) * 0.6
		Mode.ALERT:
			# Up on its haunches, ears straight up, looking round.
			t["chest"] = 0.55
			t["neck"] = -0.25
			t["head"] = -0.25 + 0.04 * _twitch
			t["ears"] = -0.35
			t["splay"] = -0.05
			t["fl"] = -0.35
			t["fl_lo"] = 0.7
			t["rl"] = -0.1
		Mode.HOP:
			var run := clampf((speed - 1.0) / 6.0, 0.0, 1.0)
			var stride := lerpf(STRIDE.x, STRIDE.y, run)
			_phase = fmod(_phase + delta * speed / stride, 1.0)
			var p := _phase
			var lift := lerpf(LIFT.x, LIFT.y, run)
			# Airborne from the hind feet's push (0.18) to the front feet landing (0.6).
			var air := clampf((p - 0.18) / 0.42, 0.0, 1.0)
			t["lift"] = lift * sin(air * PI)
			# Nose up off the push, down onto the front paws.
			t["body"] = lerpf(0.0, 1.0, run) * (0.12 * sin(p * TAU) - 0.1 * sin(p * TAU * 2.0 + 0.5))
			# The back stretches out in the air and bunches up as the hind feet come through.
			t["stretch"] = cos(p * TAU) * lerpf(0.01, 0.035, run)
			t["chest"] = -0.08 * run
			t["neck"] = -0.1 - 0.15 * run
			t["head"] = -0.05 + 0.1 * run
			# Ears: up at a hop, laid back flat along the back at a run.
			t["ears"] = lerpf(0.0, 1.25, run)
			t["splay"] = lerpf(0.1, -0.1, run)
			# Hind legs: push back (0-0.3), trail in the air, swing forward past the front
			# paws (0.6-0.95).
			var hind := -sin(clampf(p / 0.45, 0.0, 1.0) * PI * 0.5) if p < 0.45 else \
					lerpf(-1.0, 1.0, smoothstep(0.55, 0.95, p))
			t["rl"] = hind * lerpf(0.55, 1.05, run)
			t["rl_lo"] = maxf(-hind, 0.0) * 0.5 * run - maxf(hind, 0.0) * 0.4
			t["rl_ft"] = -hind * 0.6
			# Front legs: reach forward in the air (0.3-0.55), sweep back under the body
			# as they carry it (0.6-0.85), then fold up.
			var front := sin(clampf((p - 0.25) / 0.35, 0.0, 1.0) * PI * 0.5) if p < 0.6 else \
					lerpf(1.0, -0.8, smoothstep(0.6, 0.9, p))
			t["fl"] = front * lerpf(0.5, 1.1, run)
			t["fl_lo"] = (1.0 - absf(front)) * 0.6
			t["tail"] = 0.3 * run
	return t


func _apply() -> void:
	var breath := float(_pose["breath"])
	_offset("root", Vector3(0, float(_pose["lift"]), 0))
	_rot("body", Vector3(float(_pose["body"]), 0, 0))
	_rot("chest", Vector3(float(_pose["chest"]), 0, 0))
	_offset("chest", Vector3(0, 0, float(_pose["stretch"])))
	_scale("chest", Vector3(1.0 + breath * 0.015, 1.0 + breath * 0.02, 1.0))
	_rot("neck", Vector3(float(_pose["neck"]), 0, 0))
	_rot("head", Vector3(float(_pose["head"]), 0.0, 0.0))
	var ears := float(_pose["ears"])
	var splay := float(_pose["splay"])
	_rot("ear_l", Vector3(ears * 0.9 + _ear_flick.x * 0.5, _ear_flick.x, splay))
	_rot("ear_r", Vector3(ears * 0.9 + _ear_flick.y * 0.5, -_ear_flick.y, -splay))
	for side in ["l", "r"]:
		_rot("f%s_up" % side, Vector3(float(_pose["fl"]), 0, 0))
		_rot("f%s_lo" % side, Vector3(-float(_pose["fl_lo"]), 0, 0))
		_rot("r%s_up" % side, Vector3(float(_pose["rl"]), 0, 0))
		_rot("r%s_lo" % side, Vector3(float(_pose["rl_lo"]), 0, 0))
		_rot("r%s_ft" % side, Vector3(float(_pose["rl_ft"]), 0, 0))
	_rot("tail", Vector3(float(_pose["tail"]), 0, 0))


func _rot(bone: String, euler: Vector3) -> void:
	var i: int = _b.get(bone, -1)
	if i >= 0:
		skeleton.set_bone_pose_rotation(i, Quaternion.from_euler(euler))


func _offset(bone: String, offset: Vector3) -> void:
	var i: int = _b.get(bone, -1)
	if i >= 0:
		skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin + offset)


func _scale(bone: String, s: Vector3) -> void:
	var i: int = _b.get(bone, -1)
	if i >= 0:
		skeleton.set_bone_pose_scale(i, s)


# --- The sculpt (tools/build_rabbit.gd) ------------------------------------------------------

## A European rabbit about 40 cm long, sitting (hind feet flat, front paws down), in
## metres, facing -Z, the ground at y 0.
static func sculpt() -> AnimalBuilder:
	var ab := AnimalBuilder.new()
	var s := SdfSculpt.new()
	ab.sculpt = s
	ab.cell = 0.0045
	ab.set_eye_look(Color(0.2, 0.1, 0.04), Vector2(0.5, 0.5), 0.92)
	ab.add_bone("root", "", Vector3.ZERO)
	ab.add_bone("body", "root", Vector3(0, 0.13, 0.05))
	ab.add_bone("chest", "body", Vector3(0, 0.13, -0.05))
	ab.add_bone("neck", "chest", Vector3(0, 0.17, -0.105))
	ab.add_bone("head", "neck", Vector3(0, 0.21, -0.15))
	ab.add_bone("ear_l", "head", Vector3(-0.019, 0.255, -0.152))
	ab.add_bone("ear_r", "head", Vector3(0.019, 0.255, -0.152))
	ab.add_bone("tail", "body", Vector3(0, 0.14, 0.155))
	for side: Array in [[-1.0, "l"], [1.0, "r"]]:
		var sx: float = side[0]
		var n: String = side[1]
		ab.add_bone("f%s_up" % n, "chest", Vector3(sx * 0.03, 0.105, -0.085))
		ab.add_bone("f%s_lo" % n, "f%s_up" % n, Vector3(sx * 0.03, 0.05, -0.1))
		ab.add_bone("f%s_ft" % n, "f%s_lo" % n, Vector3(sx * 0.03, 0.012, -0.108))
		ab.add_bone("r%s_up" % n, "body", Vector3(sx * 0.05, 0.11, 0.075))
		ab.add_bone("r%s_lo" % n, "r%s_up" % n, Vector3(sx * 0.055, 0.055, 0.105))
		ab.add_bone("r%s_ft" % n, "r%s_lo" % n, Vector3(sx * 0.05, 0.018, 0.13))
	var fur := func(bone: String, extra := {}) -> Dictionary:
		var d := {"bone": ab.bone_index(bone), "color": Color(1, 1, 1, 0), "surface": AnimalBuilder.Surf.FUR,
			"noise": [0.0007, 140.0]}
		d.merge(extra, true)
		return d
	var belly := {"points": 1.0}
	# Haunches and back: the round rump of a sitting rabbit, the back arched over it.
	s.ellipsoid(Vector3(0, 0.12, 0.075), Vector3(0.082, 0.092, 0.1), 0.035, fur.call("body"))
	s.ellipsoid(Vector3(0, 0.15, 0.02), Vector3(0.07, 0.07, 0.1), 0.035, fur.call("body"))
	for sx: float in [-1.0, 1.0]:
		var n := "r" if sx > 0.0 else "l"
		s.ellipsoid(Vector3(sx * 0.048, 0.095, 0.08), Vector3(0.038, 0.06, 0.068), 0.025, fur.call("r%s_up" % n))
		# Hind feet: long, flat on the ground from the heel to the toes, pale underneath.
		s.cone(Vector3(sx * 0.055, 0.06, 0.105), Vector3(sx * 0.05, 0.022, 0.13), 0.02, 0.015, 0.015,
				fur.call("r%s_lo" % n))
		s.ellipsoid(Vector3(sx * 0.05, 0.016, 0.075), Vector3(0.019, 0.015, 0.066), 0.015, fur.call("r%s_ft" % n))
		s.ellipsoid(Vector3(sx * 0.05, 0.009, 0.07), Vector3(0.016, 0.008, 0.06), 0.008, fur.call("r%s_ft" % n, belly))
	# Chest and belly.
	s.ellipsoid(Vector3(0, 0.125, -0.045), Vector3(0.064, 0.072, 0.088), 0.035, fur.call("chest"))
	s.ellipsoid(Vector3(0, 0.1, -0.085), Vector3(0.046, 0.058, 0.045), 0.03, fur.call("chest"))
	s.ellipsoid(Vector3(0, 0.07, -0.02), Vector3(0.05, 0.035, 0.08), 0.03, fur.call("chest", belly))
	# Neck and head: a short neck, a round head with a blunt muzzle and full cheeks.
	s.cone(Vector3(0, 0.15, -0.09), Vector3(0, 0.195, -0.14), 0.048, 0.036, 0.03, fur.call("neck"))
	s.ellipsoid(Vector3(0, 0.212, -0.162), Vector3(0.037, 0.04, 0.05), 0.022, fur.call("head"), Vector3(-12, 0, 0))
	s.ellipsoid(Vector3(0, 0.198, -0.2), Vector3(0.027, 0.028, 0.03), 0.018, fur.call("head"))
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.022, 0.195, -0.178), Vector3(0.021, 0.024, 0.03), 0.015, fur.call("head"))
		ab.add_eye(Vector3(sx * 0.031, 0.222, -0.173), 0.0092, "head", Vector3(sx, 0.15, -0.35), 0.5)
	s.ellipsoid(Vector3(0, 0.178, -0.19), Vector3(0.022, 0.016, 0.025), 0.012, fur.call("head", belly))
	var nose: Dictionary = fur.call("head", {"surface": AnimalBuilder.Surf.SKIN, "color": Color(0.3, 0.2, 0.19, 0.0), "fixed": 1.0,
		"fur": 0.0, "gloss": 0.1})
	s.ellipsoid(Vector3(0, 0.205, -0.232), Vector3(0.0105, 0.008, 0.0065), 0.003, nose)
	# Ears: long, thin, leaning back and a little out, their tips black.
	for sx: float in [-1.0, 1.0]:
		var ear: String = "ear_r" if sx > 0.0 else "ear_l"
		var base := Vector3(sx * 0.019, 0.25, -0.152)
		var dir := Vector3(sx * 0.17, 0.94, 0.3).normalized()
		s.ellipsoid(base + dir * 0.052, Vector3(0.018, 0.056, 0.0065), 0.01, fur.call(ear), Vector3(18, 0, -sx * 10.0))
		s.ellipsoid(base + dir * 0.104, Vector3(0.013, 0.016, 0.0078), 0.004,
				fur.call(ear, {"color": Color(0.07, 0.065, 0.06, 0.0)}), Vector3(18, 0, -sx * 10.0))
	# Front legs: slim, straight down in front of the chest, pale paws.
	for sx: float in [-1.0, 1.0]:
		var n := "r" if sx > 0.0 else "l"
		s.cone(Vector3(sx * 0.03, 0.11, -0.082), Vector3(sx * 0.03, 0.05, -0.1), 0.017, 0.011, 0.012, fur.call("f%s_up" % n))
		s.cone(Vector3(sx * 0.03, 0.05, -0.1), Vector3(sx * 0.03, 0.014, -0.106), 0.011, 0.009, 0.008, fur.call("f%s_lo" % n))
		s.ellipsoid(Vector3(sx * 0.03, 0.009, -0.114), Vector3(0.011, 0.009, 0.018), 0.008, fur.call("f%s_ft" % n, belly))
	# The scut: dark on top, snow white beneath.
	s.ellipsoid(Vector3(0, 0.135, 0.172), Vector3(0.024, 0.026, 0.02), 0.012,
			fur.call("tail", {"color": Color(0.94, 0.92, 0.88, 0.0), "fixed": 1.0}))
	s.ellipsoid(Vector3(0, 0.152, 0.168), Vector3(0.017, 0.013, 0.014), 0.008, fur.call("tail"))
	return ab


## The caught rabbit as an item (held, dropped, its icon): the sitting model as a plain
## mesh, its coat colours baked into the vertices (no per-animal tint on an item).
static func item_mesh() -> ArrayMesh:
	if _scene == null:
		_scene = load(MODEL) as PackedScene
	if _scene == null:
		return ArrayMesh.new()
	var model: Node3D = _scene.instantiate()
	var src := (model.get_node("Skeleton/Mesh") as MeshInstance3D).mesh
	var out := ArrayMesh.new()
	var coat := COAT.srgb_to_linear()
	var belly := BELLY.srgb_to_linear()
	var flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		if colors.size() == uvs.size():
			for i in colors.size():
				if uvs[i].y < 0.5:
					var tint := coat.lerp(belly, clampf(uvs[i].x, 0.0, 1.0))
					colors[i] = Color(colors[i].r * tint.r, colors[i].g * tint.g, colors[i].b * tint.b, colors[i].a)
					uvs[i].y = 1.0
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_TEX_UV] = uvs
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
				flags if arrays[Mesh.ARRAY_CUSTOM0] != null else 0)
		out.surface_set_material(si, src.surface_get_material(si))
	model.free()
	return out
