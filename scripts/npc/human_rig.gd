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
##
## The arms keep out of the body: the torso's shape with its clothes is measured from
## the mesh once per model (slices round the spine, see _measure); every reach pushes
## the hand's target out of it and swings the elbow out until the upper arm, forearm
## and wrist are clear, and a turned hand whose palm or fingers would sink in is moved
## out. Held things go by the hand's grip (grip_point, hand_axes, hold): a rod or a
## glass sits in the fist, not at the wrist.

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

## The torso's shape at rest (see _measure), shared by every body of a model: slices
## SLICE apart from `y0` up, each a centre (cx, cz) and the farthest skin or cloth in
## BINS directions round it (r, slice by slice), and the farthest of them (rmax).
const SLICE := 0.03
const BINS := 32
## The bones that carry the torso, top down (a point goes with the first it is above).
const TORSO: Array[StringName] = [&"spine_03", &"spine_02", &"spine_01", &"pelvis"]
## Points checked along an arm: [0 upper arm / 1 forearm, how far along, radius].
## (The upper arm's are thin: hanging, it rests against the side of the chest as it does.)
const ARM_PROBES := [[0, 0.75, 0.026], [0, 0.92, 0.034], [1, 0.0, 0.043], [1, 0.35, 0.04], [1, 0.7, 0.035], [1, 1.0, 0.031]]
static var _shapes := {}
var _shape: Dictionary
var _torso_rest: Array[Vector3] = []
## The torso bones' posed heads and rotations this frame (TORSO order), redone when one
## of them turns or the pelvis moves.
var _torso_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _torso_rot: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY, Quaternion.IDENTITY, Quaternion.IDENTITY]
var _torso_inv: Array[Quaternion] = [Quaternion.IDENTITY, Quaternion.IDENTITY, Quaternion.IDENTITY, Quaternion.IDENTITY]
var _torso_ok := false
var _torso_ids := {}
## The way out of the torso (body frame) at the last probed point, the deepest arm
## point and the deepest hand point.
var _probe_out := Vector3.ZERO
var _arm_out := Vector3.ZERO
var _hand_out := Vector3.ZERO
## Per hand, at rest and relative to its bone's head: the fingers' way (d0), the palm's
## normal (p0), the thumb's side (t0), the fist's grip centre, the palm's skin centre and
## the palm's length; the frame's last reach [target, pole], redone by orient_hand.
var _hand0 := {}
var _grip0 := {}
var _palm0 := {}
var _palm_len := {}
var _last_reach := {}
var _last_hand := {}


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
	rig._measure()
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
	for k in TORSO.size():
		_torso_ids[bi(TORSO[k])] = k
		_torso_rest.append(pos_rest(TORSO[k]))
	# The hands: a fist closes round a point in front of the palm three quarters of the
	# way to the knuckles; the palm's skin is under the middle of the hand.
	for side: String in ["_l", "_r"]:
		var h := pos_rest("hand" + side)
		var knuckle := pos_rest("middle_01" + side)
		var d0 := (knuckle - h).normalized()
		var across := pos_rest("pinky_01" + side) - pos_rest("index_01" + side)
		var s := 1.0 if side == "_l" else -1.0
		var p0 := across.cross(d0).normalized() * s
		p0 = (p0 - d0 * p0.dot(d0)).normalized()
		var t0 := -s * d0.cross(p0)
		_hand0[side] = Basis(d0, p0, t0)
		var palm := knuckle.distance_to(h)
		_palm_len[side] = palm
		_grip0[side] = d0 * palm * 0.8 + p0 * 0.028
		_palm0[side] = d0 * palm * 0.55 + p0 * 0.017


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


# --- The body's shape ------------------------------------------------------------------------

## Measures the torso with its clothes at rest from the skinned mesh (once per model):
## the vertices carried mostly by the pelvis, spine, clavicles and the thighs' tops, in
## horizontal slices from mid-thigh to over the shoulders; each slice keeps its centre
## and the farthest vertex in each of BINS directions round it.
func _measure() -> void:
	if _shapes.has(model_name):
		_shape = _shapes[model_name]
		return
	var carried := {}
	for b: StringName in [&"pelvis", &"spine_01", &"spine_02", &"spine_03", &"clavicle_l", &"clavicle_r", &"thigh_l", &"thigh_r"]:
		carried[bi(b)] = true
	var skin := body.skin
	var to_rig := _rel(skeleton, self)
	var xf: Array[Transform3D] = []
	var torso_bind := PackedByteArray()
	for k in skin.get_bind_count():
		var bone := skin.get_bind_bone(k)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(k))
		xf.append(to_rig * skeleton.get_bone_global_rest(bone) * skin.get_bind_pose(k))
		torso_bind.append(1 if carried.has(bone) else 0)
	var y0 := pelvis_y - 0.34
	var y1 := maxf(pos_rest("clavicle_l").y, pos_rest("clavicle_r").y) + 0.03
	var n := int(ceil((y1 - y0) / SLICE)) + 1
	var slices: Array[PackedVector2Array] = []
	slices.resize(n)
	var mesh := body.mesh
	for surf in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(surf)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if verts.is_empty() or arr[Mesh.ARRAY_BONES] == null:
			continue
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / verts.size()
		for v in verts.size():
			var tw := 0.0
			var best := 0
			var bw := -1.0
			for j in per:
				var w := weights[v * per + j]
				var bb := bones[v * per + j]
				if torso_bind[bb] == 1:
					tw += w
				if w > bw:
					bw = w
					best = bb
			if tw < 0.5:
				continue
			var p := xf[best] * verts[v]
			var f := (p.y - y0) / SLICE
			for k in range(maxi(int(ceil(f - 0.75)), 0), mini(int(floor(f + 0.75)), n - 1) + 1):
				slices[k].append(Vector2(p.x, p.z))
	var cx := PackedFloat32Array()
	var cz := PackedFloat32Array()
	var r := PackedFloat32Array()
	var rmax := PackedFloat32Array()
	r.resize(n * BINS)
	r.fill(0.0)
	for k in n:
		var pts := slices[k]
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in pts:
			lo = lo.min(p)
			hi = hi.max(p)
		var c := (lo + hi) * 0.5 if not pts.is_empty() else Vector2.ZERO
		cx.append(c.x)
		cz.append(c.y)
		var m := 0.0
		for p in pts:
			var d := p - c
			var j := int(fposmod(atan2(d.x, d.y) / TAU * BINS + 0.5, float(BINS))) % BINS
			r[k * BINS + j] = maxf(r[k * BINS + j], d.length())
			m = maxf(m, d.length())
		# A direction no vertex fell in: the mean of its neighbours.
		for j in BINS:
			if r[k * BINS + j] <= 0.0:
				r[k * BINS + j] = (r[k * BINS + (j + BINS - 1) % BINS] + r[k * BINS + (j + 1) % BINS]) * 0.5
		rmax.append(m)
	_shape = {"y0": y0, "n": n, "cx": cx, "cz": cz, "r": r, "rmax": rmax}
	_shapes[model_name] = _shape


func _torso_frame() -> void:
	for k in TORSO.size():
		var b := bi(TORSO[k])
		_torso_pos[k] = pos(b)
		_torso_rot[k] = acc(b)
		_torso_inv[k] = _torso_rot[k].inverse()
	_torso_ok = true


## Which torso bone carries `p` (body frame, the pose so far): the index in TORSO; `p`
## at rest relative to it is left in _probe_rest.
var _probe_rest := Vector3.ZERO
func _carrier(p: Vector3) -> int:
	if not _torso_ok:
		_torso_frame()
	for k in TORSO.size():
		var local := _torso_inv[k] * (p - _torso_pos[k])
		if local.y > -0.03 or k == TORSO.size() - 1:
			_probe_rest = _torso_rest[k] + local
			return k
	return TORSO.size() - 1


## The torso slice at rest height `y`, direction `ang` (0 the front, + to the left):
## Vector3(centre x, centre z, radius), or radius -1 off its top and bottom.
func _slice(y: float, ang: float) -> Vector3:
	var f := (y - float(_shape["y0"])) / SLICE
	var n: int = _shape["n"]
	if f < 0.0 or f > float(n - 1):
		return Vector3(0, 0, -1)
	var k := mini(int(f), n - 2)
	var t := f - float(k)
	var cxs: PackedFloat32Array = _shape["cx"]
	var czs: PackedFloat32Array = _shape["cz"]
	var rs: PackedFloat32Array = _shape["r"]
	var fb := fposmod(ang / TAU * BINS, float(BINS))
	var j := int(fb) % BINS
	var u := fb - floorf(fb)
	var j2 := (j + 1) % BINS
	var r0 := lerpf(rs[k * BINS + j], rs[k * BINS + j2], u)
	var r1 := lerpf(rs[(k + 1) * BINS + j], rs[(k + 1) * BINS + j2], u)
	return Vector3(lerpf(cxs[k], cxs[k + 1], t), lerpf(czs[k], czs[k + 1], t), lerpf(r0, r1, t))


## How far `p` (body frame, the pose so far) is inside the torso's skin or clothes
## (negative: outside by that much, -1 well clear); the way out is left in _probe_out.
func _probe(p: Vector3) -> float:
	var k := _carrier(p)
	var rp := _probe_rest
	var f := (rp.y - float(_shape["y0"])) / SLICE
	if f < 0.0 or f > float(int(_shape["n"]) - 1):
		return -1.0
	var ki := int(f)
	var cxs: PackedFloat32Array = _shape["cx"]
	var czs: PackedFloat32Array = _shape["cz"]
	var dx := rp.x - cxs[ki]
	var dz := rp.z - czs[ki]
	var rr := sqrt(dx * dx + dz * dz)
	if rr > (_shape["rmax"] as PackedFloat32Array)[ki] + 0.12:
		return -1.0
	var s := _slice(rp.y, atan2(dx, dz))
	dx = rp.x - s.x
	dz = rp.z - s.y
	rr = sqrt(dx * dx + dz * dz)
	_probe_out = _torso_rot[k] * (Vector3(dx, 0.0, dz) / rr if rr > 0.0001 else Vector3.BACK)
	return s.z - rr


## How deep a ball of `radius` at `p` (body frame) sinks into the torso (negative: clear).
func torso_depth(p: Vector3, radius: float) -> float:
	return _probe(p) + radius


## `p` (body frame) moved straight out of the torso until a ball of `radius` there is clear.
func keep_out(p: Vector3, radius: float) -> Vector3:
	var d := _probe(p) + radius
	return p + _probe_out * d if d > 0.0 else p


## A point on the torso's surface (body frame, this frame's pose) at rest height `y`,
## direction `ang`, and its outward normal: [point, normal].
func torso_surface(y: float, ang: float) -> Array:
	var s := _slice(y, ang)
	var dir := Vector3(sin(ang), 0.0, cos(ang))
	var rp := Vector3(s.x, y, s.y) + dir * s.z
	if not _torso_ok:
		_torso_frame()
	var k := 0
	while k < TORSO.size() - 1 and rp.y < _torso_rest[k].y - 0.03:
		k += 1
	var p := _torso_pos[k] + _torso_rot[k] * (rp - _torso_rest[k])
	return [p, _torso_rot[k] * dir]


# --- Bones -----------------------------------------------------------------------------------

func bi(bone: StringName) -> int:
	return int(_i.get(bone, -1))


func pos_rest(bone: StringName) -> Vector3:
	return _rest_pos[bi(bone)]


## Starts a frame's pose: everything at rest.
func begin() -> void:
	_q.clear()
	_curl.clear()
	_last_reach.clear()
	_last_hand.clear()
	_offset = Vector3.ZERO
	_torso_ok = false


## Rotates `bone` by `q` (body frame, applied after what it already has).
func rot(bone: StringName, q: Quaternion) -> void:
	var i := bi(bone)
	_q[i] = q * (_q.get(i, Quaternion.IDENTITY) as Quaternion)
	if _torso_ids.has(i):
		_torso_ok = false


func rot_x(bone: StringName, a: float) -> void:
	rot(bone, Quaternion(Vector3.RIGHT, a))


func rot_y(bone: StringName, a: float) -> void:
	rot(bone, Quaternion(Vector3.UP, a))


func rot_z(bone: StringName, a: float) -> void:
	rot(bone, Quaternion(Vector3.BACK, a))


func move_pelvis(offset: Vector3) -> void:
	_offset += offset
	_torso_ok = false


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
	set_hand(side, hand_rot(side, dir, palm))


## The hand's rotation (body frame, from rest) with its fingers along `dir`, its palm
## facing `palm`.
func hand_rot(side: String, dir: Vector3, palm: Vector3) -> Quaternion:
	var h0: Basis = _hand0[side]
	return _frame(dir, palm) * _frame(h0.x, h0.y).inverse()


## Turns the hand to `w` (body frame, from rest); curl() then keeps it out of the torso.
func set_hand(side: String, w: Quaternion) -> void:
	var h := bi("hand" + side)
	_q[h] = acc(skeleton.get_bone_parent(h)).inverse() * w
	_last_hand[side] = w


## How deep the hand turned to `w` sinks into the torso: the palm, the knuckles and the
## fingers curled by `amount` (bent towards the palm); the way out is left in _hand_out.
func _hand_depth(side: String, w: Quaternion, amount: float) -> float:
	var wrist := pos(bi("hand" + side))
	var h0: Basis = _hand0[side]
	var d := w * h0.x
	var p := w * h0.y
	var palm: float = _palm_len[side]
	var knuckle := wrist + d * palm
	var a1 := amount * 0.9
	var a2 := a1 + amount * 1.2
	var mid := knuckle + (d * cos(a1) + p * sin(a1)) * 0.045
	var tip := mid + (d * cos(a2) + p * sin(a2)) * 0.03
	var worst := -1.0
	for pr: Array in [[wrist + d * palm * 0.5, 0.016], [knuckle, 0.014], [mid, 0.011], [tip, 0.009]]:
		var depth := _probe(pr[0]) + float(pr[1])
		if depth > worst:
			worst = depth
			_hand_out = _probe_out
	return worst


## The arm to `target` (body frame), the elbow towards `pole`; kept out of the torso:
## the target pushed clear for the wrist, then the elbow swung out (a new pole through
## where it would be clear) while the arm still sinks in, and an arm too straight to
## swing its elbow taken out with its hand.
func reach(side: String, target: Vector3, pole: Vector3) -> void:
	var up := "upperarm" + side
	var low := "lowerarm" + side
	var hand := "hand" + side
	var hinge := arm_hinge(side)
	var t := keep_out(target, 0.034)
	var p := pole
	ik(up, low, hand, t, p, hinge)
	# (up to 10 goes: a two-handed grip, like the broom's, can take a few more to clear)
	for k in 10:
		var d := _arm_depth(side)
		if d < -0.012:
			break
		if k < 3:
			var s := pos(bi(up))
			var e := pos(bi(low))
			p = e + _arm_out * (d + 0.012) * 2.5 - s
		else:
			# (a straight arm can't swing its elbow out: the hand goes out with it)
			t += Vector3(_arm_out.x, 0.0, _arm_out.z) * (d + 0.012) * 2.0
		ik(up, low, hand, t, p, hinge)
	_last_reach[side] = [t, p]


## How deep the arm (upper arm below the shoulder, elbow, forearm, wrist) sinks into the
## torso; the way out is left in _arm_out.
func _arm_depth(side: String) -> float:
	var s := pos(bi("upperarm" + side))
	var e := pos(bi("lowerarm" + side))
	var w := pos(bi("hand" + side))
	var worst := -1.0
	for pr: Array in ARM_PROBES:
		var at := s.lerp(e, pr[1]) if int(pr[0]) == 0 else e.lerp(w, pr[1])
		var d := _probe(at) + float(pr[2])
		if d > worst:
			worst = d
			_arm_out = _probe_out
	return worst


# --- Hands and what they hold -----------------------------------------------------------------

## The hand's axes now (body frame): x the fingers' way, y out of the palm, z the thumb's side.
func hand_axes(side: String) -> Basis:
	var q := acc(bi("hand" + side))
	var h0: Basis = _hand0[side]
	return Basis(q * h0.x, q * h0.y, q * h0.z)


## Where the closed fist holds a handle or a glass now (body frame).
func grip_point(side: String) -> Vector3:
	var h := bi("hand" + side)
	return pos(h) + acc(h) * (_grip0[side] as Vector3)


## The grip as the skeleton draws it (body frame), for tests.
func drawn_grip(side: String) -> Vector3:
	var h := bi("hand" + side)
	var xf := _rel(skeleton, self) * skeleton.get_bone_global_pose(h)
	var local := (_rest_rot[h] as Quaternion).inverse() * (_grip0[side] as Vector3)
	return xf.origin + xf.basis.get_rotation_quaternion() * local


## The hand (`side`) closed round a handle or a glass at `at` (body frame): `rod` the way
## the thumb's side of the fist points along it, `fingers` about where the fingers point
## (made square to the rod), the elbow towards `pole`.
func hold(side: String, at: Vector3, rod: Vector3, fingers: Vector3, pole: Vector3, fist := 0.8) -> void:
	var pose := hold_pose(side, at, rod, fingers)
	reach(side, pose[0], pole)
	set_hand(side, pose[1])
	curl(side, fist, 0.6)


## The hand (`side`) laid flat with its palm on a surface at `at` (outward `normal`),
## the fingers along `fingers`.
func palm_on(side: String, at: Vector3, normal: Vector3, fingers: Vector3, pole: Vector3) -> void:
	var n := normal.normalized()
	var w := hand_rot(side, (fingers - n * fingers.dot(n)).normalized(), -n)
	reach(side, at - w * (_palm0[side] as Vector3), pole)
	set_hand(side, w)


## The heart's place on the clothes over the left breast (body frame, this frame's
## pose): [point, outward normal].
func heart() -> Array:
	var y := lerpf(pos_rest("spine_03").y, pos_rest("clavicle_l").y, 0.5)
	return torso_surface(y, 0.42)


## The hand (`side`) to the heart, `amount` 0..1 of the way from where the arm is now:
## out in front of the body on the way, the palm resting flat on the chest, the fingers
## towards the other shoulder.
func hand_on_heart(side: String, amount: float) -> void:
	if amount <= 0.001:
		return
	var sgn := 1.0 if side == "_l" else -1.0
	var h := bi("hand" + side)
	var from_p := pos(h)
	var from_q := acc(h)
	var curl0 := float(_curl.get(bi("middle_01" + side), 0.3)) / 0.9
	var spot := heart()
	var n: Vector3 = spot[1]
	if not _torso_ok:
		_torso_frame()
	var chest := _torso_rot[0]
	var fingers := chest * Vector3(-sgn, 0.5, 0.0)
	var w := hand_rot(side, (fingers - n * fingers.dot(n)).normalized(), -n)
	var to_p: Vector3 = (spot[0] as Vector3) + n * 0.005 - w * (_palm0[side] as Vector3)
	var t := smoothstep(0.0, 1.0, amount)
	# (round the side and in front: from behind the back too)
	var mid := (from_p + to_p) * 0.5 + chest * Vector3(sgn * 0.22, 0.0, 0.26)
	reach(side, from_p.lerp(mid, t).lerp(mid.lerp(to_p, t), t), chest * Vector3(sgn * 0.9, -0.8, 0.45))
	set_hand(side, from_q.slerp(w, t))
	curl(side, lerpf(curl0, 0.18, t), lerpf(0.35, 0.2, t))


## A wave of the hand (`side`) raised beside the head, `amount` 0..1 of the way from
## where the arm is now, the hand swaying at `phase`.
func wave(side: String, amount: float, phase: float) -> void:
	if amount <= 0.001:
		return
	var sgn := 1.0 if side == "_l" else -1.0
	var h := bi("hand" + side)
	var from_p := pos(h)
	var from_q := acc(h)
	var curl0 := float(_curl.get(bi("middle_01" + side), 0.3)) / 0.9
	var to_p := pos(bi("upperarm" + side)) + Vector3(sgn * 0.3, 0.17, 0.12)
	var w := hand_rot(side, Vector3(sgn * 0.12 + sin(phase) * 0.35, 1.0, 0.05).normalized(), Vector3(0, 0, 1))
	var t := smoothstep(0.0, 1.0, amount)
	var mid := (from_p + to_p) * 0.5 + Vector3(sgn * 0.14, 0.0, 0.1)
	reach(side, from_p.lerp(mid, t).lerp(mid.lerp(to_p, t), t), Vector3(sgn, -0.5, -0.15))
	set_hand(side, from_q.slerp(w, t))
	curl(side, lerpf(curl0, 0.06, t), lerpf(0.35, 0.1, t))


## The leg's ankle to `target`, the knee towards `pole`.
func step(side: String, target: Vector3, pole := Vector3(0, 0, 1)) -> void:
	var thigh := pos_rest("calf" + side) - pos_rest("thigh" + side)
	var hinge := Vector3.RIGHT - thigh.normalized() * thigh.normalized().x
	ik("thigh" + side, "calf" + side, "foot" + side, target, pole, hinge.normalized())


## Curls the fingers (0 open .. 1 a fist) and the thumb.
## (The last step of posing a hand: if the palm or the curled fingers would sink into the
## torso, the arm reaches again that much further out.)
func curl(side: String, amount: float, thumb := 0.4) -> void:
	for f: StringName in FINGERS:
		for k in 3:
			_curl[bi("%s_0%d%s" % [f, k + 1, side])] = amount * (0.9 if k == 0 else 1.2)
	for k in 3:
		_curl[bi("thumb_0%d%s" % [k + 1, side])] = thumb * (0.3 if k == 0 else 0.6)
	if not (_last_reach.has(side) and _last_hand.has(side)):
		return
	var w: Quaternion = _last_hand[side]
	var h := bi("hand" + side)
	for k in 2:
		var d := _hand_depth(side, w, amount)
		if d <= 0.0:
			break
		var last: Array = _last_reach[side]
		reach(side, (last[0] as Vector3) + _hand_out * (d + 0.003), last[1])
		_q[h] = acc(skeleton.get_bone_parent(h)).inverse() * w


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
		relaxed_arm(side, swing_l if side == "_l" else swing_r)


func relaxed_arm(side: String, swing := 0.0) -> void:
	var sgn := 1.0 if side == "_l" else -1.0
	var pose := relaxed_pose(side, swing)
	reach(side, pose[0], Vector3(sgn * 0.2, 0.0, -1.0))
	set_hand(side, pose[1])
	curl(side, 0.35, 0.35)


## The hanging arm's hand: [wrist (body frame), the hand's rotation].
func relaxed_pose(side: String, swing := 0.0) -> Array:
	var sgn := 1.0 if side == "_l" else -1.0
	var sh := pos(bi("upperarm" + side))
	var drop: float = float(_len[bi("upperarm" + side)]) + float(_len[bi("lowerarm" + side)])
	var hand := sh + Vector3(sgn * 0.07, -drop * 0.96, 0.05 + swing * 0.28)
	hand.y += maxf(swing, 0.0) * 0.08
	return [hand, hand_rot(side, Vector3(sgn * 0.12, -1.0, 0.18 + swing * 0.3), Vector3(-sgn, 0.0, 0.1))]


## What hold() does with the hand: [wrist (body frame), the hand's rotation].
func hold_pose(side: String, at: Vector3, rod: Vector3, fingers: Vector3) -> Array:
	var r := rod.normalized()
	var d := (fingers - r * fingers.dot(r)).normalized()
	var w := hand_rot(side, d, d.cross(r) * (1.0 if side == "_l" else -1.0))
	return [at - w * (_grip0[side] as Vector3), w]


## The hand a way `t` from pose `a` to pose `b` ([wrist, rotation] each), the elbow
## towards `pole`, the fingers curled from `curl_a` to `curl_b`.
func pose_between(side: String, a: Array, b: Array, t: float, pole: Vector3, curl_a: float, curl_b: float) -> void:
	reach(side, (a[0] as Vector3).lerp(b[0], t), pole)
	set_hand(side, (a[1] as Quaternion).slerp(b[1], t))
	curl(side, lerpf(curl_a, curl_b, t), lerpf(0.35, 0.6, t))


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
