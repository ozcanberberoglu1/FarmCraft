@tool
class_name RabbitRig
extends Node3D
## The wild rabbit's model and its procedural animation.
##
## The model is MODEL["path"], a skinned glTF loaded by that explicit path. The game's
## own is built by tools/blender/build_rabbit.py: a European rabbit in its sitting
## pose with a painted agouti coat, shell fur, glossy eyes and whiskers. MODEL maps the
## rig's bones onto the model's, so another rabbit can be wired in by changing MODEL
## alone (see its comment).
##
## The animation is worked out here in the rabbit's own frame (x right, y up, z back):
## sitting (breathing, the nose twitching, ears flicking and turning, looking about),
## nibbling the grass (head down, chewing), sitting up on alert (up on the haunches,
## ears straight up, forepaws off the ground), and the hop up to a flat-out bound: the
## hind feet push off together, the body stretches out in the air, the front paws land
## one after the other, the back bunches up as the hind feet swing past them to land
## ahead; at speed the ears lie back, the white scut is up and the body leans into
## turns. Feet are placed with two-bone IK (hip-knee-hock, shoulder-elbow-wrist, then
## the foot), so feet on the ground stay put.

enum Mode { SIT, GRAZE, ALERT, HOP }

## Where the model is and how it fits the rig:
##   path    the model, loaded by this path (never found by listing folders)
##   height  0: the model is in metres, on the ground, facing -Z. Otherwise it is
##           scaled so its `body` bone stands this high (m) above its lowest bone,
##           centred on its legs and turned to face -Z (from its head and root bones)
##   bones   rig bone -> the model's bone, for any named differently. Rig bones: root,
##           body (pelvis), spine, chest, neck, head, nose, jaw, ear_l, ear_l2, ear_r,
##           ear_r2, tail, and per leg (fl fr rl rr; l = the rabbit's left) _up, _lo,
##           _ft and _toe (the toe tip). Bones a model lacks are left still; a leg needs
##           _up, _lo and _ft (without _toe, the foot's own axis is used)
##   fur     the shell fur mesh ("" for none)
##   coat    meshes drawn with the coat shader (from their own albedo texture)
## A rabbit downloaded to art/models/animals/source/rabbit/scene.gltf is wired as
##   {"path": "res://art/models/animals/source/rabbit/scene.gltf", "height": 0.1,
##    "bones": {"root": "...", "body": "...", ...}, "fur": "", "coat": []}
## (the model's bone names show on its Skeleton3D in the editor).
const MODEL := {
	"path": "res://art/models/wildlife/rabbit/rabbit.gltf",
	"height": 0.0,
	"bones": {},
	"fur": "Fur",
	"coat": ["Body"],
}
const STRANDS := "res://art/models/wildlife/rabbit/textures/rabbit_strands.png"
## Strand tiles per UV unit (tools/blender/build_rabbit.py prints the model's metres per
## UV unit; a tile is 64 strands 0.55 mm apart).
const STRAND_SCALE := 14.6
## Shell fur layers by graphics preset (LOW..ULTRA).
const FUR_LAYERS: Array[int] = [0, 8, 12, 16]
const BONES: Array[String] = ["root", "body", "spine", "chest", "neck", "head", "nose", "jaw",
	"ear_l", "ear_l2", "ear_r", "ear_r2", "tail",
	"fl_up", "fl_lo", "fl_ft", "fl_toe", "fr_up", "fr_lo", "fr_ft", "fr_toe",
	"rl_up", "rl_lo", "rl_ft", "rl_toe", "rr_up", "rr_lo", "rr_ft", "rr_toe"]
## Hops per second: a lazy hop and flat out.
const HOP_RATE := Vector2(2.4, 4.3)

static var _scene: PackedScene
static var _materials := {}

var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var fur: MeshInstance3D

var _b := {}  # rig bone -> model bone index
var _conv := {}  # bone index -> [A, C, parent rest basis inverse]
var _frame := Quaternion.IDENTITY  # rig frame -> skeleton space
var _unit := 1.0  # skeleton units per metre
var _to_rig := Transform3D.IDENTITY  # skeleton space -> rig
var _from_rig := Transform3D.IDENTITY
var _legs := {}

var _time := 0.0
var _seed := 0.0
var _phase := 0.0
var _gait := 0.0  # 0 still .. 1 hopping
var _run := 0.0
var _pose := {}  # eased channels of the still modes
var _last_yaw := 0.0
var _turn := 0.0
var _look := Vector2.ZERO
var _look_to := Vector2.ZERO
var _look_timer := 1.0
var _ear_flick: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _ear_timer: Array[float] = [1.0, 2.0]
var _ear_turn: Array[float] = [0.0, 0.0]
var _ear_bounce := 0.0
var _ear_bounce_v := 0.0
var _last_lift := 0.0
var _lift_v := 0.0
var _twitch := 0.0
var _twitch_on := true
var _twitch_timer := 2.0


static func create() -> RabbitRig:
	var rig := RabbitRig.new()
	rig.name = "Rig"
	var scene := _load()
	if scene == null:
		return rig
	var model: Node3D = scene.instantiate()
	model.name = "Model"
	rig.add_child(model)
	rig._setup(model)
	return rig


static func _load() -> PackedScene:
	if _scene == null:
		var path: String = MODEL["path"]
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_scene = ResourceLoader.load_threaded_get(path) as PackedScene
		if _scene == null:
			_scene = load(path) as PackedScene
	return _scene


## Starts loading the model on a background thread.
static func preload_model() -> void:
	var path: String = MODEL["path"]
	if _scene == null and ResourceLoader.exists(path) \
			and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


## The graphics preset (ULTRA where there are no settings, e.g. in tools).
static func _quality() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("Settings") if tree else null
	return int(settings.get("quality")) if settings else FUR_LAYERS.size() - 1


# --- Setup ---------------------------------------------------------------------------------

func _setup(model: Node3D) -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var names: Dictionary = MODEL["bones"]
	for bone in BONES:
		var idx := skeleton.find_bone(names.get(bone, bone))
		if idx >= 0:
			_b[bone] = idx
	_normalize(model)
	for bone: String in _b:
		_prepare_bone(_b[bone])
	for leg in ["fl", "fr", "rl", "rr"]:
		_prepare_leg(leg)
	_seed = randf() * 100.0
	var shade := randf_range(0.88, 1.1)
	var layers: int = FUR_LAYERS[clampi(_quality(), 0, FUR_LAYERS.size() - 1)]
	var coat: Array = MODEL["coat"]
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		meshes.append(mi)
		# Small and moving: no GI voxelization, out of the rain-blocker heightfield.
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.layers = 2
		var nm := String(mi.name)
		if nm == MODEL["fur"]:
			fur = mi
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_instance_shader_parameter(&"fur_layers", float(layers))
			mi.visible = layers > 0
		elif nm in coat:
			# The skin reads darker under the fur (the roots in its shade).
			mi.set_instance_shader_parameter(&"skin_shade", 0.82 if layers > 0 and MODEL["fur"] != "" else 1.0)
		else:
			# Eyes and whiskers: too small for a shadow.
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter(&"coat_shade", shade)
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, _material(mi, si))


## Leaves a model built for the rig as it is; puts any other on the ground facing -Z at
## MODEL["height"] (as PhotoRig does for the livestock).
func _normalize(model: Node3D) -> void:
	var height := float(MODEL["height"])
	if height > 0.0:
		model.transform = Transform3D.IDENTITY
		var sk := _rel(skeleton, self)
		var pts: Array[Vector3] = []
		for i in skeleton.get_bone_count():
			pts.append(sk * skeleton.get_bone_global_rest(i).origin)
		var head: Vector3 = pts[_b.get("head", 0)]
		var root: Vector3 = pts[_b.get("root", 0)]
		var yaw := PI - atan2(head.x - root.x, head.z - root.z)
		var y_min := INF
		for p in pts:
			y_min = minf(y_min, p.y)
		var body_y: float = pts[_b.get("body", _b.get("root", 0))].y
		var s := height / maxf(body_y - y_min, 0.0001)
		var centre := Vector3.ZERO
		var n := 0
		for key in ["fl_up", "fr_up", "rl_up", "rr_up"]:
			if _b.has(key):
				centre += pts[_b[key]]
				n += 1
		centre = centre / n if n > 0 else root
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s)
		model.transform = Transform3D(basis, -(basis * Vector3(centre.x, y_min, centre.z)))
	_to_rig = _rel(skeleton, self)
	_from_rig = _to_rig.affine_inverse()
	_frame = _to_rig.basis.get_rotation_quaternion().inverse()
	_unit = 1.0 / _to_rig.basis.get_scale().x


static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _prepare_bone(idx: int) -> void:
	var br := skeleton.get_bone_global_rest(idx).basis.get_rotation_quaternion()
	var parent := skeleton.get_bone_parent(idx)
	var pr := Quaternion.IDENTITY
	var pbasis := Basis.IDENTITY
	if parent >= 0:
		pbasis = skeleton.get_bone_global_rest(parent).basis
		pr = pbasis.get_rotation_quaternion()
	_conv[idx] = [pr.inverse() * _frame, _frame.inverse() * br, pbasis.inverse()]


## A leg's rest geometry: where its toe is and the foot's angle (rig frame), its
## segments' lengths (skeleton units) and each child's place in its parent bone.
func _prepare_leg(leg: String) -> void:
	for part in ["_up", "_lo", "_ft"]:
		if not _b.has(leg + part):
			return
	var lo: int = _b[leg + "_lo"]
	var ft: int = _b[leg + "_ft"]
	var ankle := skeleton.get_bone_global_rest(ft)
	var toe_local: Vector3
	if _b.has(leg + "_toe"):
		toe_local = skeleton.get_bone_rest(_b[leg + "_toe"]).origin
	else:
		toe_local = Vector3(0, skeleton.get_bone_rest(ft).origin.length() * 0.8, 0)
	var toe_rig := _to_rig * (ankle * toe_local)
	var ankle_rig := _to_rig * ankle.origin
	_legs[leg] = {
		"up": _b[leg + "_up"], "lo": lo, "ft": ft,
		"lo_local": skeleton.get_bone_rest(lo).origin, "ft_local": skeleton.get_bone_rest(ft).origin,
		"toe_local": toe_local,
		"l1": skeleton.get_bone_rest(lo).origin.length(), "l2": skeleton.get_bone_rest(ft).origin.length(),
		"l3": toe_local.length(),
		"toe": toe_rig, "angle": atan2(ankle_rig.y - toe_rig.y, ankle_rig.z - toe_rig.z),
		"front": leg.begins_with("f"),
	}


# --- Materials -----------------------------------------------------------------------------

func _material(mi: MeshInstance3D, si: int) -> Material:
	var key := "%s/%d" % [mi.name, si]
	if _materials.has(key):
		return _materials[key]
	var src := mi.mesh.surface_get_material(si)
	var out: Material = src
	var sm := src as StandardMaterial3D
	var nm := String(mi.name)
	var coat: Array = MODEL["coat"]
	if nm == MODEL["fur"] or nm in coat:
		var m := ShaderMaterial.new()
		var is_fur: bool = nm == MODEL["fur"]
		m.shader = load("res://shaders/rabbit_fur.gdshader" if is_fur else "res://shaders/rabbit_coat.gdshader")
		if sm:
			m.set_shader_parameter(&"albedo_tex", sm.albedo_texture)
		if is_fur:
			m.set_shader_parameter(&"strands", load(STRANDS))
			m.set_shader_parameter(&"strand_scale", STRAND_SCALE)
		out = m
	elif sm and sm.resource_name.contains("eye"):
		# Wet and glassy: the sky and the sun shine in them.
		var e := sm.duplicate() as StandardMaterial3D
		e.roughness = 0.04
		e.metallic_specular = 0.9
		e.clearcoat_enabled = true
		e.clearcoat = 1.0
		e.clearcoat_roughness = 0.02
		out = e
	_materials[key] = out
	return out


# --- Animation -----------------------------------------------------------------------------

## The pose for this frame: `speed` (m/s over the ground) drives the hop.
func animate(delta: float, speed: float, mode: int) -> void:
	if skeleton == null or delta <= 0.0:
		return
	_time += delta
	var yaw := global_rotation.y if is_inside_tree() else 0.0
	_turn = lerpf(_turn, angle_difference(_last_yaw, yaw) / delta, 1.0 - exp(-delta * 6.0))
	_last_yaw = yaw
	var hopping := mode == Mode.HOP and speed > 0.05
	if hopping and _gait <= 0.0:
		# Off with a push of the hind feet.
		_phase = 0.3
	_gait = move_toward(_gait, 1.0 if hopping else 0.0, delta * (6.0 if hopping else 4.0))
	_run = move_toward(_run, clampf((speed - 1.2) / 5.0, 0.0, 1.0), delta * 3.0)
	# The nose twitches in bursts (the whiskers go with it).
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_on = not _twitch_on
		_twitch_timer = randf_range(1.5, 4.0) if _twitch_on else randf_range(0.4, 2.5)
	_twitch = sin(_time * 44.0) if _twitch_on else 0.0
	var idle := _idle(delta, mode)
	var k := 1.0 - exp(-delta * 7.0)
	for key: String in idle:
		_pose[key] = lerpf(float(_pose.get(key, 0.0)), float(idle[key]), k)
	var ch: Dictionary = _pose.duplicate()
	var feet := {}
	var w := smoothstep(0.0, 1.0, _gait)
	if _gait > 0.0:
		var rate := lerpf(HOP_RATE.x, HOP_RATE.y, _run)
		if hopping:
			_phase = fposmod(_phase + delta * rate, 1.0)
		var hop := _hop(_phase, _run, maxf(speed, 0.3) / rate)
		var hc: Dictionary = hop["ch"]
		for key: String in hc:
			ch[key] = lerpf(float(ch.get(key, 0.0)), float(hc[key]), w)
		feet = hop["feet"]
	_ears(delta, ch)
	_apply(ch, feet, w)


## The eased channels of the still modes (sitting, grazing, alert).
func _idle(delta: float, mode: int) -> Dictionary:
	var t := {"lift": 0.0, "surge": 0.0, "pitch": 0.0, "roll": 0.0, "flex": 0.0, "chest": 0.0, "neck": 0.0, "head": 0.0,
		"yaw": 0.0, "ears": 0.0, "splay": 0.0, "ear_bend": 0.0, "tail": 0.0, "chew": 0.0, "free": 0.0}
	# Looking about now and then.
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(1.2, 4.5)
		_look_to = Vector2(randf_range(-0.55, 0.55), randf_range(-0.12, 0.1)) if randf() < 0.7 else Vector2.ZERO
	_look = _look.lerp(_look_to, 1.0 - exp(-delta * 5.0))
	match mode:
		Mode.GRAZE:
			# Nose down in the grass, chewing.
			t["pitch"] = -0.1
			t["chest"] = -0.12
			t["neck"] = -0.62
			t["head"] = -0.5 + 0.05 * sin(_time * 3.1 + _seed)
			t["yaw"] = 0.15 * sin(_time * 0.7 + _seed)
			# Laid back along the neck, clear of the grass.
			t["ears"] = 1.7
			t["splay"] = 0.2
			t["chew"] = 1.0
		Mode.ALERT:
			# Up on its haunches, ears straight up, looking round.
			t["lift"] = 0.012
			t["pitch"] = 0.3
			t["flex"] = -0.5
			t["chest"] = 0.1
			t["neck"] = -0.25
			t["head"] = -0.34 + _look.y * 0.5
			t["yaw"] = _look.x * 0.6
			t["ears"] = -0.18
			t["splay"] = -0.04
			t["tail"] = 0.15
			t["free"] = 1.0
		_:
			t["yaw"] = _look.x
			t["head"] = _look.y
			t["splay"] = 0.08
	return t


## The hop at phase `p` (0 = the hind feet touch down): body channels and where the
## feet go. `run` 0 is a lazy hop, 1 flat out; `stride` is metres per hop.
func _hop(p: float, run: float, stride: float) -> Dictionary:
	var hs := lerpf(0.36, 0.2, run)  # hind feet down
	var fs := lerpf(0.3, 0.42, run)  # the left fore paw touches down
	var fd := lerpf(0.42, 0.15, run)  # a fore paw's time down
	var fo := lerpf(0.1, 0.07, run)  # the right one after it
	var ch := {}
	# A lazy hop: the forepaws reach out while the hind feet stay, then the rump
	# hops up and forward, the back arched, bringing the hind feet up behind them.
	var slow_lift := 0.022 + 0.04 * _bump(p, hs - 0.06, 1.02)
	var slow_pitch := 0.04 * _bump(p, 0.0, hs) - 0.2 * _bump(p, hs - 0.02, 1.0) - 0.05
	var slow_flex := 0.3 * _bump(p, hs + 0.02, 1.04) - 0.1 * _bump(p, 0.0, hs + 0.05)
	# Flat out: off the hind feet into a stretched-out leap, onto the forepaws one after
	# the other, then bunched up in the air as the hind feet swing past them.
	var fast_lift := 0.03 + 0.075 * _bump(p, hs * 0.6, fs + 0.05) - 0.02 * _bump(p, fs, fs + fd + fo)
	var fast_pitch := 0.12 * _bump(p, 0.0, fs) - 0.2 * _bump(p, fs - 0.05, fs + fd + fo + 0.1) - 0.05
	var fast_flex := 0.42 * _bump(p, fs + fd * 0.4, 1.05) - 0.28 * _bump(p, hs * 0.5, fs + 0.05)
	ch["lift"] = lerpf(slow_lift, fast_lift, run)
	ch["pitch"] = lerpf(slow_pitch, fast_pitch, run)
	ch["flex"] = lerpf(slow_flex, fast_flex, run)
	# The rump hangs back over the planted hind feet, then catches up (m, + back).
	var surge := 0.0
	if p < hs:
		surge = p / hs - 0.5
	else:
		surge = 0.5 - smoothstep(0.0, 1.0, (p - hs) / (1.0 - hs))
	ch["surge"] = surge * minf(stride * hs * 0.45, 0.035) * (1.0 - run)
	ch["roll"] = clampf(_turn * (0.02 + 0.05 * run), -0.35, 0.35)
	ch["chest"] = 0.0
	ch["neck"] = -0.1 - 0.2 * run
	# The head held steady against the body's rocking, looking into the turn.
	ch["head"] = -0.7 * (float(ch["pitch"]) - float(ch["flex"])) + 0.12 * run
	ch["yaw"] = clampf(_turn * 0.12, -0.4, 0.4)
	ch["ears"] = lerpf(0.12, 1.3, run)
	ch["splay"] = lerpf(0.1, -0.12, run)
	ch["ear_bend"] = lerpf(0.0, 0.25, run)
	ch["tail"] = lerpf(0.15, 0.8, run)
	ch["chew"] = 0.0
	ch["free"] = 0.0
	var feet := {}
	for side in ["l", "r"]:
		var leg: Dictionary = _legs.get("r" + side, {})
		if not leg.is_empty():
			feet["r" + side] = _hind_foot(fposmod(p - (0.02 * run if side == "r" else 0.0), 1.0), run, stride, hs, leg)
		leg = _legs.get("f" + side, {})
		if not leg.is_empty():
			feet["f" + side] = _fore_foot(fposmod(p - fs - (fo if side == "r" else 0.0), 1.0), run, stride, fd, leg)
	return {"ch": ch, "feet": feet}


## [toe position, foot angle (0 flat forward, + heel up)] of a hind foot.
func _hind_foot(p: float, run: float, stride: float, hs: float, leg: Dictionary) -> Array:
	var rest: Vector3 = leg["toe"]
	var z_td := rest.z + lerpf(0.0, -0.07, run)
	var z_lo := z_td + stride * hs
	var rest_a: float = leg["angle"]
	var land_a := lerpf(rest_a, 0.45, run)
	var push_a := lerpf(0.7, 1.35, run)
	if p < hs:
		var s := p / hs
		return [Vector3(rest.x, rest.y, lerpf(z_td, z_lo, s)), lerpf(land_a, push_a, smoothstep(0.25, 1.0, s))]
	var s := (p - hs) / (1.0 - hs)
	var z := lerpf(z_lo, z_td, smoothstep(lerpf(0.15, 0.06, run), lerpf(0.85, 0.62, run), s)) \
			+ sin(minf(s * 4.0, 1.0) * PI) * 0.03 * run
	var y := rest.y + sin(s * PI) * lerpf(0.022, 0.045, run)
	# Pushed off with the heel up (flat out, trailing behind), folded up flat under the
	# body, then reaching forward to land.
	var a := lerpf(push_a, lerpf(0.75, 1.8, run), smoothstep(0.0, 0.12, s))
	a = lerpf(a, 0.25, smoothstep(0.12, lerpf(0.5, 0.36, run), s))
	a = lerpf(a, land_a, smoothstep(0.75, 1.0, s))
	return [Vector3(rest.x, y, z), a]


## [toe position, paw angle (+ wrist up)] of a fore paw; p = 0 when it touches down.
func _fore_foot(p: float, run: float, stride: float, fd: float, leg: Dictionary) -> Array:
	var rest: Vector3 = leg["toe"]
	var z_td := rest.z + lerpf(-0.03, -0.045, run)
	var z_lo := z_td + stride * fd
	var rest_a: float = leg["angle"]
	if p < fd:
		var s := p / fd
		return [Vector3(rest.x, rest.y, lerpf(z_td, z_lo, s)), lerpf(rest_a + 0.1, 1.2, smoothstep(0.3, 1.0, s))]
	var s := (p - fd) / (1.0 - fd)
	var z := lerpf(z_lo, z_td, smoothstep(0.05, 0.9, s))
	var y := rest.y + sin(s * PI) * lerpf(0.022, 0.05, run)
	# The paw curls up as it leaves the ground and reaches out to land.
	var a := lerpf(1.2, 2.3, smoothstep(0.0, 0.3, s))
	a = lerpf(a, rest_a + 0.1, smoothstep(0.45, 0.95, s))
	return [Vector3(rest.x, y, z), a]


## A smooth hump from a to b (wrapping past 1).
static func _bump(p: float, a: float, b: float) -> float:
	var w := b - a
	var q := fposmod(p - a, 1.0)
	return sin(q / w * PI) if q < w else 0.0


## Ears: flicks and turns now and then, bouncing on the hops.
func _ears(delta: float, ch: Dictionary) -> void:
	for i in 2:
		_ear_timer[i] -= delta
		if _ear_timer[i] <= 0.0:
			_ear_timer[i] = randf_range(0.7, 3.5)
			if randf() < 0.55:
				_ear_flick[i] = Vector3(randf_range(-0.3, 0.35), randf_range(-0.5, 0.5), randf_range(-0.12, 0.12))
			else:
				_ear_turn[i] = randf_range(-0.7, 0.5)
		_ear_flick[i] = _ear_flick[i].lerp(Vector3.ZERO, 1.0 - exp(-delta * 5.0))
	# A spring driven by the body's rise and fall.
	var lift := float(ch["lift"])
	var v := (lift - _last_lift) / delta
	_last_lift = lift
	var acc := (v - _lift_v) / delta
	_lift_v = v
	_ear_bounce_v += (-_ear_bounce * 260.0 - _ear_bounce_v * 14.0 + clampf(acc, -60.0, 60.0) * 0.02) * delta
	_ear_bounce = clampf(_ear_bounce + _ear_bounce_v * delta, -0.5, 0.5)


func _apply(ch: Dictionary, feet: Dictionary, gait: float) -> void:
	var pitch := float(ch["pitch"])
	var flex := float(ch["flex"])
	var still := 1.0 - gait
	var surge := float(ch["surge"])
	_offset("root", Vector3(0, float(ch["lift"]), surge))
	_rot("body", Vector3(pitch, 0, float(ch["roll"])))
	_rot("spine", Vector3(-flex * 0.5 + sin(_time * 5.2 + _seed) * 0.012 * still, 0, 0))
	# The front keeps going while the rump hangs back: the back stretches.
	_offset("spine", Vector3(0, 0, flex * 0.012 - surge * 0.6))
	_rot("chest", Vector3(float(ch["chest"]) - flex * 0.5, 0, 0))
	var yaw := float(ch["yaw"])
	_rot("neck", Vector3(float(ch["neck"]), yaw * 0.4, 0))
	_rot("head", Vector3(float(ch["head"]), yaw * 0.6, -yaw * 0.1))
	_rot("nose", Vector3(0.05 * _twitch * still, 0, 0))
	_offset("nose", Vector3(0, 0.0007 * _twitch * still, 0))
	_rot("jaw", Vector3(-0.07 * float(ch["chew"]) * (1.0 + sin(_time * 25.0)), 0, 0))
	var ears := float(ch["ears"]) + _ear_bounce
	var splay := float(ch["splay"])
	var bend := float(ch["ear_bend"])
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var n := "l" if i == 0 else "r"
		var f := _ear_flick[i]
		var turn := _ear_turn[i] * still
		_rot("ear_" + n, Vector3(ears * 0.8 + f.x, (turn + f.y) * -s, -s * (splay + f.z)))
		_rot("ear_%s2" % n, Vector3(ears * 0.25 + bend + f.x * 0.5, 0, 0))
	_rot("tail", Vector3(float(ch["tail"]), 0, 0))
	# Legs: planted where they stand, on their hop, or (sat up) hanging free.
	var free := float(ch["free"])
	var body_q := Quaternion.from_euler(Vector3(pitch, 0, 0))
	for leg: String in _legs:
		var L: Dictionary = _legs[leg]
		_reset_leg(L)
		var toe: Vector3 = L["toe"]
		var angle: float = L["angle"]
		if feet.has(leg):
			var f: Array = feet[leg]
			toe = toe.lerp(f[0], gait)
			angle = lerpf(angle, f[1], gait)
		var foot := Vector3(0, -sin(angle), -cos(angle))
		var front: bool = L["front"]
		if front and free > 0.0 and _b.has("chest"):
			# Carried up with the chest, the paws hanging.
			var chest: int = _b["chest"]
			var carried := _to_rig * skeleton.get_bone_global_pose(chest) \
					* (_to_rig * skeleton.get_bone_global_rest(chest)).affine_inverse() * (toe + Vector3(0, 0.02, 0.01))
			toe = toe.lerp(carried, free)
			foot = foot.lerp(Vector3(0, -1, 0.35).normalized(), free).normalized()
		var pole := body_q * (Vector3(0, 0.25, 1) if front else Vector3(0, -0.2, -1))
		_solve_leg(L, toe, foot, pole)


func _reset_leg(L: Dictionary) -> void:
	for key in ["up", "lo", "ft"]:
		var idx: int = L[key]
		skeleton.set_bone_pose_rotation(idx, skeleton.get_bone_rest(idx).basis.get_rotation_quaternion())


## Two-bone IK to the ankle (the toe less the foot), then the foot to the toe.
func _solve_leg(L: Dictionary, toe_rig: Vector3, foot_rig: Vector3, pole_rig: Vector3) -> void:
	var l1: float = L["l1"]
	var l2: float = L["l2"]
	var l3: float = L["l3"]
	var hip := skeleton.get_bone_global_pose(L["up"]).origin
	var toe := _from_rig * toe_rig
	var ankle := toe - (_from_rig.basis * foot_rig).normalized() * l3
	var to := ankle - hip
	var d := clampf(to.length(), absf(l1 - l2) + 0.0001, (l1 + l2) * 0.999)
	var axis := to.normalized()
	var pole := _from_rig.basis * pole_rig
	pole = (pole - axis * axis.dot(pole)).normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var knee := hip + axis * (l1 * ca) + pole * (l1 * sqrt(1.0 - ca * ca))
	var reach := hip + axis * d
	_aim(L["up"], L["lo_local"], knee - hip)
	_aim(L["lo"], L["ft_local"], reach - knee)
	_aim(L["ft"], L["toe_local"], toe - reach)


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


## Rotation in the rabbit's frame (euler, radians) -> the bone's pose, as if its parent
## were at rest; chained bones compose like a rig built in that frame.
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
	skeleton.set_bone_pose_position(idx, skeleton.get_bone_rest(idx).origin + (c[2] as Basis) * (_frame * offset * _unit))


# --- The caught rabbit (an item) -------------------------------------------------------------

## The caught rabbit as an item (held, dropped, its icon): the sitting model as a plain
## mesh with its coat, fur, eyes and whiskers.
static func item_mesh() -> ArrayMesh:
	var out := ArrayMesh.new()
	if _load() == null:
		return out
	var rig := RabbitRig.create()
	for mi in rig.meshes:
		var xf := _rel(mi, rig)
		var src := mi.mesh
		for si in src.get_surface_count():
			var arrays := src.surface_get_arrays(si)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			arrays[Mesh.ARRAY_TANGENT] = null
			if not xf.is_equal_approx(Transform3D.IDENTITY):
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in verts.size():
					verts[i] = xf * verts[i]
				arrays[Mesh.ARRAY_VERTEX] = verts
				if arrays[Mesh.ARRAY_NORMAL] != null:
					var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					for i in norms.size():
						norms[i] = (xf.basis * norms[i]).normalized()
					arrays[Mesh.ARRAY_NORMAL] = norms
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, mi.get_surface_override_material(si))
	rig.free()
	return out
