class_name HumanRig
extends Node3D
## A townsperson's body and its procedural animation. The body is one skinned mesh
## (art/models/people/<model>.gltf: an MPFB2 human on the "game_engine" rig, dressed,
## see tools/blender/build_people.py); the rig moves its skeleton every frame from a
## few layered motions instead of clips:
##
##   stance      breathing, the weight shifting from foot to foot, relaxed arms
##   walk        a heel-to-toe gait: planted feet (leg IK), pelvis bob, sway and
##               twist, counter-rotating shoulders, swinging arms
##   sit         on a bench or a chair, hands on the thighs
##   hands       arm IK to targets in the body frame (the till, the broom's handle,
##               the tea glass, the heart in a greeting, behind the back)
##   look        the head (neck and chest a little) turned to a point
##
## Rotations are written in the body frame (+Z forward, +Y up, +X the person's left)
## as if each bone's parent stood at rest, so a chain composes like FK
## (global = Q_root * ... * Q_bone * rest); positions come from the same FK, which
## the IK needs for the shoulders and hips.

const DIR := "res://art/models/people/"
const MODELS: Array[StringName] = [&"shopkeeper", &"worker", &"salesman", &"farmer", &"elder", &"villager", &"young"]
## Skin, lips and cheeks a little warmer and darker than the source scans (Anatolian sun).
const SKIN_TINT := Color(0.96, 0.87, 0.78)
## Bones the rig writes, by role.
const BODY := [&"pelvis", &"spine_01", &"spine_02", &"spine_03", &"neck_01", &"head",
	&"clavicle_l", &"upperarm_l", &"lowerarm_l", &"hand_l", &"clavicle_r", &"upperarm_r", &"lowerarm_r", &"hand_r",
	&"thigh_l", &"calf_l", &"foot_l", &"ball_l", &"thigh_r", &"calf_r", &"foot_r", &"ball_r"]
const FINGERS := [&"index", &"middle", &"ring", &"pinky"]

var model_name: StringName
var skeleton: Skeleton3D
var body: MeshInstance3D
## Seconds since spawn (every motion's clock) and a per-person offset for its cycles.
var time := 0.0
var seed_phase := 0.0

var _i := {}
var _rest_pos := {}
var _rest_rot := {}
var _pre := {}
var _chain := {}
var _len := {}
var _q := {}
var _offset := Vector3.ZERO
var _curl := {}
var _root_rot_inv := Quaternion.IDENTITY
var _pelvis_rest_local := Vector3.ZERO
## Body measures (model space): pelvis height, the leg's hip-to-ankle length.
var pelvis_y := 0.9
var leg_len := 0.84
var ankle_y := 0.07
## Walk state: phase of the gait (0..1 at the left heel strike) and the blend in.
var gait_phase := 0.0
var _walk_blend := 0.0
var _look := Vector2.ZERO
var _materials: Array[BaseMaterial3D] = []


static func create(model: StringName, tints: Dictionary = {}) -> HumanRig:
	var rig := HumanRig.new()
	rig.model_name = model
	var scene: PackedScene = load(DIR + String(model) + ".gltf")
	var inst := scene.instantiate() as Node3D
	inst.name = "Model"
	rig.add_child(inst)
	rig.skeleton = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	rig.body = rig.skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	rig._setup()
	rig._setup_materials(tints)
	return rig


func _setup() -> void:
	seed_phase = randf() * 100.0
	for i in skeleton.get_bone_count():
		_i[skeleton.get_bone_name(i)] = i
	var to_rig := _rel(skeleton, self)
	var rig_rot := to_rig.basis.get_rotation_quaternion()
	for i in skeleton.get_bone_count():
		var g := skeleton.get_bone_global_rest(i)
		_rest_pos[i] = to_rig * g.origin
		_rest_rot[i] = rig_rot * g.basis.get_rotation_quaternion()
	for i in skeleton.get_bone_count():
		var p := skeleton.get_bone_parent(i)
		_pre[i] = (_rest_rot[p] as Quaternion).inverse() if p >= 0 else rig_rot.inverse()
		var chain: Array[int] = []
		var j := i
		while j >= 0:
			chain.push_front(j)
			j = skeleton.get_bone_parent(j)
		_chain[i] = chain
		var kids := skeleton.get_bone_children(i)
		if not kids.is_empty():
			_len[i] = (_rest_pos[kids[0]] as Vector3).distance_to(_rest_pos[i])
	# Children the limbs' lengths are measured to (the first child of a hand is a finger).
	for side: String in ["_l", "_r"]:
		_len[bi("upperarm" + side)] = pos_rest("lowerarm" + side).distance_to(pos_rest("upperarm" + side))
		_len[bi("lowerarm" + side)] = pos_rest("hand" + side).distance_to(pos_rest("lowerarm" + side))
		_len[bi("thigh" + side)] = pos_rest("calf" + side).distance_to(pos_rest("thigh" + side))
		_len[bi("calf" + side)] = pos_rest("foot" + side).distance_to(pos_rest("calf" + side))
	var root := skeleton.get_bone_parent(bi("pelvis"))
	_root_rot_inv = (_rest_rot[root] as Quaternion).inverse() if root >= 0 else rig_rot.inverse()
	_pelvis_rest_local = skeleton.get_bone_rest(bi("pelvis")).origin
	pelvis_y = pos_rest("pelvis").y
	ankle_y = pos_rest("foot_l").y
	leg_len = float(_len[bi("thigh_l")]) + float(_len[bi("calf_l")])


static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## The materials by role (their names from the build: skin, eyes, brows, lashes, hair,
## beard, cloth_*): skin with subsurface scattering on HIGH/ULTRA, hair and lashes cut
## out with alpha to coverage, cloth matte. `tints` multiplies cloth colours by material
## name ("cloth_male_worksuit01": Color) so one model dresses several people.
func _setup_materials(tints: Dictionary) -> void:
	var mesh := body.mesh
	for s in mesh.get_surface_count():
		var src := mesh.surface_get_material(s) as BaseMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as BaseMaterial3D
		var mat_name := src.resource_name
		m.set_meta(&"role", mat_name)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		match mat_name:
			"skin":
				m.albedo_color = SKIN_TINT
				m.roughness = 0.52
				m.metallic_specular = 0.35
				m.subsurf_scatter_skin_mode = true
			"eyes":
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				m.roughness = 0.08
				m.metallic_specular = 0.7
			"brows", "lashes", "hair", "beard":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.3 if mat_name == "lashes" else 0.42
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.roughness = 0.62
				m.metallic_specular = 0.3
			_:
				m.roughness = 0.92
				m.metallic_specular = 0.25
				m.cull_mode = BaseMaterial3D.CULL_DISABLED if mat_name == "cloth_scarf" else BaseMaterial3D.CULL_BACK
				if tints.has(mat_name):
					m.albedo_color = tints[mat_name]
		body.set_surface_override_material(s, m)
		_materials.append(m)
	apply_quality()


## Shadows off and plain skin on LOW; subsurface skin and alpha to coverage on HIGH/ULTRA.
func apply_quality() -> void:
	var q: int = Settings.quality
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if q == Settings.Quality.LOW else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for m in _materials:
		var role := String(m.get_meta(&"role", ""))
		if role == "skin":
			m.subsurf_scatter_enabled = q >= Settings.Quality.HIGH
			m.subsurf_scatter_strength = 0.28
		elif role in ["brows", "lashes", "hair", "beard"]:
			m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE if q >= Settings.Quality.HIGH else BaseMaterial3D.ALPHA_ANTIALIASING_OFF


# --- Bones -----------------------------------------------------------------------------------

func bi(bone: StringName) -> int:
	return int(_i.get(bone, -1))


func pos_rest(bone: StringName) -> Vector3:
	return _rest_pos[bi(bone)]


## Starts a frame's pose: everything at rest.
func begin() -> void:
	_q.clear()
	_curl.clear()
	_offset = Vector3.ZERO


## Rotates `bone` by `q` (body frame, applied after what it already has).
func rot(bone: StringName, q: Quaternion) -> void:
	var i := bi(bone)
	_q[i] = q * (_q.get(i, Quaternion.IDENTITY) as Quaternion)


func rot_x(bone: StringName, a: float) -> void:
	rot(bone, Quaternion(Vector3.RIGHT, a))


func rot_y(bone: StringName, a: float) -> void:
	rot(bone, Quaternion(Vector3.UP, a))


func rot_z(bone: StringName, a: float) -> void:
	rot(bone, Quaternion(Vector3.BACK, a))


func move_pelvis(offset: Vector3) -> void:
	_offset += offset


## The accumulated rotation of bone `i` (its parents' and its own).
func acc(i: int) -> Quaternion:
	var q := Quaternion.IDENTITY
	for j: int in _chain[i]:
		q = q * (_q.get(j, Quaternion.IDENTITY) as Quaternion)
	return q


## Where bone `i`'s head is now (FK over the rotations set so far).
func pos(i: int) -> Vector3:
	var chain: Array = _chain[i]
	var p: Vector3 = _rest_pos[chain[0]]
	var q := Quaternion.IDENTITY
	var pelvis := bi(&"pelvis")
	for k in chain.size():
		var j: int = chain[k]
		if k > 0:
			p += q * ((_rest_pos[j] as Vector3) - (_rest_pos[chain[k - 1]] as Vector3))
		if j == pelvis:
			p += _offset
		q = q * (_q.get(j, Quaternion.IDENTITY) as Quaternion)
	return p


## Writes the frame's pose to the skeleton.
func commit() -> void:
	for i: int in _q:
		skeleton.set_bone_pose_rotation(i, (_pre[i] as Quaternion) * (_q[i] as Quaternion) * (_rest_rot[i] as Quaternion))
	skeleton.set_bone_pose_position(bi(&"pelvis"), _pelvis_rest_local + _root_rot_inv * _offset)
	for i: int in _curl:
		var r := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(i, r * Quaternion(Vector3.RIGHT, float(_curl[i])))


## Every bone the rig ever moves back to rest (before the first frame).
func reset() -> void:
	begin()
	for b: StringName in BODY:
		_q[bi(b)] = Quaternion.IDENTITY
	commit()


# --- IK --------------------------------------------------------------------------------------

static func _frame(d: Vector3, h: Vector3) -> Quaternion:
	var x := d.normalized()
	var y := (h - x * h.dot(x)).normalized()
	return Basis(x, y, x.cross(y)).get_rotation_quaternion()


## Two-bone IK: `upper` and `lower` bend so `end` reaches `target`, the middle joint
## towards `pole` (a direction). `hinge` is the rest hinge axis (a positive turn about it
## bends the joint).
func ik(upper: StringName, lower: StringName, end: StringName, target: Vector3, pole: Vector3, hinge: Vector3) -> void:
	var u_i := bi(upper)
	var l_i := bi(lower)
	var e_i := bi(end)
	var s := pos(u_i)
	var a: float = _len[u_i]
	var b: float = _len[l_i]
	var to := target - s
	var d := clampf(to.length(), absf(a - b) + 0.02, a + b - 0.003)
	var u := to.normalized()
	var v := pole - u * pole.dot(u)
	if v.length_squared() < 1e-6:
		v = Vector3.FORWARD.cross(u)
	v = v.normalized()
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := s + (u * cos_a + v * sqrt(1.0 - cos_a * cos_a)) * a
	var tip := s + u * d
	var d0: Vector3 = ((_rest_pos[l_i] as Vector3) - (_rest_pos[u_i] as Vector3)).normalized()
	var l0: Vector3 = ((_rest_pos[e_i] as Vector3) - (_rest_pos[l_i] as Vector3)).normalized()
	var d1 := (elbow - s).normalized()
	var l1 := (tip - elbow).normalized()
	var h1 := d1.cross(l1)
	if h1.length_squared() < 1e-6:
		h1 = v.cross(u)
	var g := _frame(d1, h1) * _frame(d0, hinge).inverse()
	var parent_acc := acc(skeleton.get_bone_parent(u_i))
	_q[u_i] = parent_acc.inverse() * g
	var cur := g * l0
	var delta := Quaternion(cur.normalized(), l1) if cur.normalized().dot(l1) < 0.99999 else Quaternion.IDENTITY
	_q[l_i] = g.inverse() * delta * g


## The rest hinge of an arm (its elbow bent a little in the A pose) or a leg (+X).
func arm_hinge(side: String) -> Vector3:
	var d0 := pos_rest("lowerarm" + side) - pos_rest("upperarm" + side)
	var l0 := pos_rest("hand" + side) - pos_rest("lowerarm" + side)
	return d0.cross(l0).normalized()


## Turns a hand so its fingers point along `dir` and its palm faces `palm` (body frame).
func orient_hand(side: String, dir: Vector3, palm: Vector3) -> void:
	var h := bi("hand" + side)
	var d0 := (pos_rest("middle_01" + side) - pos_rest("hand" + side)).normalized()
	var across := pos_rest("pinky_01" + side) - pos_rest("index_01" + side)
	var p0 := across.cross(d0).normalized() * (1.0 if side == "_l" else -1.0)
	var w := _frame(dir, palm) * _frame(d0, p0).inverse()
	_q[h] = acc(skeleton.get_bone_parent(h)).inverse() * w


## The arm to `target` (body frame), the elbow towards `pole`.
func reach(side: String, target: Vector3, pole: Vector3) -> void:
	ik("upperarm" + side, "lowerarm" + side, "hand" + side, target, pole, arm_hinge(side))


## The leg's ankle to `target`, the knee towards `pole`.
func step(side: String, target: Vector3, pole := Vector3(0, 0, 1)) -> void:
	var thigh := pos_rest("calf" + side) - pos_rest("thigh" + side)
	var hinge := Vector3.RIGHT - thigh.normalized() * thigh.normalized().x
	ik("thigh" + side, "calf" + side, "foot" + side, target, pole, hinge.normalized())


## Curls the fingers (0 open .. 1 a fist) and the thumb.
func curl(side: String, amount: float, thumb := 0.4) -> void:
	for f: StringName in FINGERS:
		for k in 3:
			_curl[bi("%s_0%d%s" % [f, k + 1, side])] = amount * (0.9 if k == 0 else 1.2)
	for k in 3:
		_curl[bi("thumb_0%d%s" % [k + 1, side])] = thumb * (0.3 if k == 0 else 0.6)


# --- Motions ---------------------------------------------------------------------------------

## Smooth noise in -1..1 (sum of incommensurate sines) for idle drift.
func wobble(rate: float, k: float) -> float:
	var t := time * rate + seed_phase * k
	return (sin(t) * 0.6 + sin(t * 2.31 + 1.7) * 0.3 + sin(t * 4.7 + 0.3) * 0.1)


## Standing: breathing, the weight shifting from foot to foot (the feet stay planted),
## arms hanging relaxed unless the caller poses them after this. `lean` bows forward.
func stance(lean := 0.0, arms := true) -> void:
	var breath := sin(time * 1.55 + seed_phase)
	var shift := wobble(0.55, 1.0)
	move_pelvis(Vector3(shift * 0.03, -0.012 - absf(shift) * 0.012, 0.0))
	rot_z(&"pelvis", -shift * 0.045)
	rot_y(&"pelvis", wobble(0.3, 2.0) * 0.06)
	rot_z(&"spine_02", shift * 0.035)
	rot_x(&"spine_01", lean * 0.4)
	rot_x(&"spine_02", lean * 0.35 + breath * 0.008)
	rot_x(&"spine_03", lean * 0.25 - breath * 0.018)
	rot_z(&"clavicle_l", breath * 0.012)
	rot_z(&"clavicle_r", -breath * 0.012)
	for side: String in ["_l", "_r"]:
		var foot := pos_rest("foot" + side) + Vector3(0.0, 0.0, 0.02)
		foot.x *= 1.08
		step(side, foot, Vector3(signf(foot.x) * 0.15, 0, 1))
	if arms:
		relaxed_arms()


## Arms hanging at the sides, elbows a little bent, hands half open.
func relaxed_arms(swing_l := 0.0, swing_r := 0.0) -> void:
	for side: String in ["_l", "_r"]:
		var sgn := 1.0 if side == "_l" else -1.0
		var swing := swing_l if side == "_l" else swing_r
		var sh := pos(bi("upperarm" + side))
		var drop: float = float(_len[bi("upperarm" + side)]) + float(_len[bi("lowerarm" + side)])
		var hand := sh + Vector3(sgn * 0.07, -drop * 0.96, 0.05 + swing * 0.28)
		hand.y += maxf(swing, 0.0) * 0.08
		reach(side, hand, Vector3(sgn * 0.2, 0.0, -1.0))
		orient_hand(side, Vector3(sgn * 0.12, -1.0, 0.18 + swing * 0.3), Vector3(-sgn, 0.0, 0.1))
		curl(side, 0.35, 0.35)


## One step of the gait at `speed` m/s (the phase advances by `delta`). The feet roll
## heel to toe and stay planted while on the ground (leg IK), the pelvis rides over them.
func walk(delta: float, speed: float, stride_scale := 1.0, arms := true) -> void:
	var stride := clampf(0.55 + speed * 0.5, 0.8, 1.55) * stride_scale
	var freq := speed / stride
	gait_phase = fposmod(gait_phase + delta * freq, 1.0)
	var p := gait_phase
	var hips := {}
	var ankles := {}
	var pitches := {}
	var reach_y := pelvis_y
	for side: String in ["_l", "_r"]:
		var ph := fposmod(p + (0.0 if side == "_l" else 0.5), 1.0)
		var foot := _foot_path(ph, stride, speed)
		var ankle := Vector3(pos_rest("foot" + side).x * 0.9, ankle_y + foot.y, foot.x)
		ankles[side] = ankle
		pitches[side] = foot.z
		var hip := pos_rest("thigh" + side)
		hips[side] = hip
		var horiz := Vector2(ankle.x - hip.x, ankle.z - hip.z).length()
		var reach_len := leg_len * 0.985
		var hip_at := ankle.y + sqrt(maxf(reach_len * reach_len - horiz * horiz, 0.0))
		reach_y = minf(reach_y, hip_at + (pelvis_y - hip.y))
	# Pelvis: rides as high as the legs allow, sways over the standing foot, twists
	# with the forward leg and drops on the swing side.
	var twist := sin(TAU * p) * 0.08
	var sway := -cos(TAU * p) * 0.022
	move_pelvis(Vector3(sway, minf(reach_y - pelvis_y, -0.005), 0.0))
	rot_y(&"pelvis", twist)
	rot_z(&"pelvis", sin(TAU * p * 2.0) * 0.03)
	rot_x(&"pelvis", 0.03)
	# The chest turns against the pelvis, the head keeps looking ahead.
	rot_y(&"spine_02", -twist * 0.9)
	rot_y(&"spine_03", -twist * 0.7)
	rot_x(&"spine_03", 0.04 + sin(TAU * p * 2.0) * 0.012)
	rot_y(&"neck_01", twist * 0.3)
	for side: String in ["_l", "_r"]:
		var sgn := 1.0 if side == "_l" else -1.0
		step(side, ankles[side], Vector3(sgn * 0.1, 0.0, 1.0))
		rot(&"foot" + side, Quaternion(Vector3.RIGHT, -float(pitches[side])))
		rot_x(&"ball" + side, clampf(float(pitches[side]) * 0.9, -0.6, 0.0) if float(pitches[side]) < 0.0 else 0.0)
	if arms:
		var swing := cos(TAU * p) * clampf(speed * 0.45, 0.25, 0.7)
		relaxed_arms(-swing, swing)


## A foot's path through the gait cycle at phase `ph` (0: its heel strike): x = its
## forward position, y = the ankle's lift, z = the foot's pitch (+ toes up).
func _foot_path(ph: float, stride: float, speed: float) -> Vector3:
	var stance := 0.62
	var reach_fwd := stride * 0.3
	var travel := stride * stance
	if ph < stance:
		var z := reach_fwd - travel * (ph / stance)
		var pitch := 0.0
		if ph < 0.1:
			pitch = lerpf(0.22, 0.0, smoothstep(0.0, 0.1, ph))
		elif ph > 0.36:
			pitch = -0.6 * smoothstep(0.36, stance, ph)
		var toe := 0.13
		var y := 0.0
		if pitch < 0.0:
			# The heel rises, the foot turns about its ball.
			y = toe * sin(-pitch)
			z += toe - toe * cos(pitch)
		return Vector3(z, y, pitch)
	var s := (ph - stance) / (1.0 - stance)
	var z0 := reach_fwd - travel + 0.13 - 0.13 * cos(0.6)
	var e := 0.5 - 0.5 * cos(PI * s)
	var z := lerpf(z0, reach_fwd, e)
	var lift := 0.13 * sin(0.6) * (1.0 - s) + sin(PI * minf(s * 1.15, 1.0)) * (0.07 + speed * 0.02)
	var pitch := lerpf(-0.6, 0.22, smoothstep(0.1, 0.95, s))
	return Vector3(z, lift, pitch)


## Sitting on a seat `seat_y` high (body frame), feet flat in front, hands on the
## thighs unless the caller poses them after this.
func sit(seat_y: float, slouch := 0.1, arms := true) -> void:
	var drop := seat_y + 0.1 - pelvis_y
	move_pelvis(Vector3(0.0, drop, -0.1))
	rot_x(&"pelvis", -0.12)
	rot_x(&"spine_01", 0.08 + slouch * 0.5)
	rot_x(&"spine_02", 0.06 + slouch * 0.4 + sin(time * 1.4 + seed_phase) * 0.008)
	rot_x(&"spine_03", 0.04 + slouch * 0.3)
	for side: String in ["_l", "_r"]:
		var sgn := 1.0 if side == "_l" else -1.0
		var hip := pos(bi("thigh" + side))
		var knee_fwd: float = _len[bi("thigh" + side)]
		var foot := Vector3(hip.x * 1.35 + sgn * 0.02, ankle_y + 0.01, hip.z + knee_fwd * 0.95 + 0.04)
		step(side, foot, Vector3(sgn * 0.15, 0.4, 1.0))
	if arms:
		for side: String in ["_l", "_r"]:
			var sgn := 1.0 if side == "_l" else -1.0
			var knee := pos(bi("calf" + side))
			var hip := pos(bi("thigh" + side))
			reach(side, hip.lerp(knee, 0.62) + Vector3(sgn * 0.02, 0.07, 0.0), Vector3(sgn * 0.6, -0.2, -1.0))
			orient_hand(side, Vector3(-sgn * 0.25, -0.35, 1.0), Vector3(0, -1, 0))
			curl(side, 0.3, 0.3)


## Turns the head (the neck and chest a little) to look at `target` (body frame);
## `weight` fades it in and out. Limits keep it human.
func look_at_point(target: Vector3, weight: float, delta: float) -> void:
	var head := pos(bi(&"head")) + Vector3(0, 0.08, 0)
	var d := target - head
	var want := Vector2.ZERO
	if weight > 0.001 and d.length() > 0.2:
		var yaw := clampf(atan2(d.x, d.z), -1.3, 1.3)
		var pitch := clampf(-atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.6)
		want = Vector2(yaw, pitch) * weight
	_look = _look.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	look(_look.x, _look.y)


## Yaw (+ left) and pitch (+ down) of the gaze, spread over chest, neck and head.
func look(yaw: float, pitch: float) -> void:
	rot(&"spine_03", Quaternion(Vector3.UP, yaw * 0.18))
	rot(&"neck_01", Quaternion(Vector3.UP, yaw * 0.32) * Quaternion(Vector3.RIGHT, pitch * 0.4))
	rot(&"head", Quaternion(Vector3.UP, yaw * 0.5) * Quaternion(Vector3.RIGHT, pitch * 0.6))


## Where the eyes are (body frame), for looking back at the player.
func eye_point() -> Vector3:
	return pos(bi(&"head")) + Vector3(0, 0.09, 0.08)


## A point on the chest in front of the sternum (hand on the heart, a glass held).
func chest_point() -> Vector3:
	return pos(bi(&"spine_03")) + acc(bi(&"spine_03")) * Vector3(0.0, 0.14, 0.16)
