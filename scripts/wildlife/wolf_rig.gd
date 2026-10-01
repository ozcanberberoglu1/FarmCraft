class_name WolfRig
extends DogRig
## The grey wolf's body and its procedural animation (see Wolf for what it does).
##
## Karamel's rig (DogRig: the gait with paws planted in the world, the legs' IK, sitting
## and lying, looking at things, the ears' swing) driving the wolf's model, WOLF_PATH,
## built by tools/blender/build_wolf.py from the same downloaded dog (see
## art/models/animals/wolf/CREDITS.md): a grizzled grey coat with long shell fur
## (wolf_fur.gdshader), erect ears on their own two bones each, eyes of their own
## (wolf_eye.gdshader: amber, shining back a light held near the one looking), 72 cm at
## the withers, facing -Z, DogRig's BONES.
##
## On top of the dog's walk and trot it has a wolf's carriage and moves, everything in
## its own frame (x right, y up, z back):
##   - its head carried low, level with its back, lower still trotting; the tail hanging,
##     raised when it means business (tail_mood 1), tucked when it runs from something
##     (-1), streaming out behind at a gallop;
##   - the gallop (from GALLOP_FROM): a rotary gallop, the hind pair landing one just
##     after the other and then the fore pair, a short stance and the back flexing and
##     stretching with each stride;
##   - stalking (`crouch` 0..1): the body low on bent legs, the head down and forward,
##     the ears pricked;
##   - snarling (`snarl` 0..1): head lowered, ears laid back, the jaw ajar, the hackles
##     up (the fur's `ruffle`);
##   - howling (`howl` 0..1, sitting): the head thrown up, the mouth rounded and
##     working with the note;
##   - a lunge and bite (lunge()): a spring forward and up, the jaws gaping and snapping
##     shut;
##   - a flinch when hit (flinch(side)): the body jerks away from the blow, ears flat;
##   - death (die(side)): the legs give, it rolls onto its side and lies still, legs
##     out, the head on the ground: the carcass (no shine left in its eyes).

const WOLF_PATH := "res://art/models/animals/wolf/wolf.gltf"
const WOLF_STRANDS := "res://art/models/animals/wolf/textures/wolf_strands.png"
## The wolf pelt item's model (built with the wolf).
const PELT_PATH := "res://art/models/animals/wolf/wolf_pelt.gltf"
## Strand tiles per UV unit (1.34 m of surface per UV unit; coarse hair, in locks).
const WOLF_STRAND_SCALE := 15.0
## Longest fur (m): the model's UV2.y is the fur length over this.
const FUR_MAX := 0.07
## Shell fur layers by graphics preset (LOW..ULTRA).
const WOLF_FUR_LAYERS: Array[int] = [0, 6, 10, 14]
## The gallop: when each paw is set down (share of the cycle: the hind pair, then the
## fore pair, rotary), the share of a cycle a paw is down, and the speed (m/s) it takes
## over from the trot.
const TOUCH_GALLOP := {"rl": 0.0, "rr": 0.1, "fl": 0.46, "fr": 0.56}
const DUTY_GALLOP := 0.3
const GALLOP_FROM := 3.4
## Sitting, how high over the ground the hips' pivot stays (m).
const SIT_SEAT := 0.2
## Seconds: a lunge, a flinch, falling dead.
const LUNGE_TIME := 0.5
const FLINCH_TIME := 0.45
const DIE_TIME := 1.1

## What the wolf is doing, set by its owner every frame (besides DogRig's pose,
## look_at_point, panting...): stalking crouched 0..1; snarling 0..1; howling 0..1 (with
## pose SIT); the tail's mood -1 (tucked) .. 0 (hanging) .. 1 (raised).
var crouch := 0.0
var snarl := 0.0
var howl := 0.0
var tail_mood := 0.0
var eyes: MeshInstance3D

## Eased: crouch, snarl, howl, the tail's mood, galloping 0..1; the one-shots running
## down 1 -> 0 (lunge, flinch) and the flinch's side; dying 0 -> 1 and the side it falls
## on (+1: onto its right).
var _crouch_a := 0.0
var _snarl_a := 0.0
var _howl_a := 0.0
var _tail_a := 0.0
var _gallop := 0.0
var _lunge := 0.0
var _flinch := 0.0
var _flinch_side := 1.0
var _dead := -1.0
var _dead_side := 1.0
var _howl_t := 0.0


func _init() -> void:
	# A bigger animal than Karamel: a little faster at each gait, higher steps, a
	# lower seat.
	walk_speed = 1.05
	walk_rate = 1.5
	trot_from = 1.6
	lift = Vector2(0.1, 0.085)
	gait_crouch = Vector2(0.015, 0.035)
	sit_hips = Vector2(-0.43, 0.03)
	lie_body = Vector2(-0.37, 0.03)
	lie_reach = 0.27


static func make() -> WolfRig:
	var rig := WolfRig.new()
	rig._build()
	return rig


func model_path() -> String:
	return WOLF_PATH


## Starts loading the wolf's model on a background thread.
static func preload_wolf() -> void:
	DogRig.preload_model(WOLF_PATH)


## The wolf pelt item's model (PELT_PATH, in ItemModels' frame: lying on its base at the
## origin), as one mesh: the hide with its coat's material and its shell fur (PeltFur,
## the wolf's fur shader at full layers).
static func pelt_mesh() -> ArrayMesh:
	var out := ArrayMesh.new()
	var scene := _load(PELT_PATH)
	if scene == null:
		return out
	var root := scene.instantiate() as Node3D
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := _rel(mi, root)
		for si in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(si)
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
			var mat := mi.mesh.surface_get_material(si)
			if mi.name == &"PeltFur":
				mat = _fur_material(mat as StandardMaterial3D)
			out.surface_set_material(out.get_surface_count() - 1, mat)
	root.free()
	return out


## The wolf's shell fur material over a coat material's albedo.
static func _fur_material(sm: StandardMaterial3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/wolf_fur.gdshader")
	m.set_shader_parameter(&"strands", load(WOLF_STRANDS))
	m.set_shader_parameter(&"strand_scale", WOLF_STRAND_SCALE)
	m.set_shader_parameter(&"layer_count", 14.0)
	m.set_shader_parameter(&"max_length", FUR_MAX)
	if sm:
		m.set_shader_parameter(&"albedo_tex", sm.albedo_texture)
	return m


func _setup(model: Node3D) -> void:
	super._setup(model)
	for mi in meshes:
		if mi.name == &"Eyes":
			eyes = mi
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Sitting: the hips down to just over the ground (the rump on it), whatever the
## model's height, before DogRig works out the body's pitch from it.
func _prepare_sit() -> void:
	if _b.has("root"):
		sit_hips.x = -(_rest_rig("root").y - SIT_SEAT)
	super._prepare_sit()


## Shell fur by the graphics preset (none on LOW); the coat a little darker under it.
func apply_quality() -> void:
	var layers: int = WOLF_FUR_LAYERS[clampi(_quality(), 0, WOLF_FUR_LAYERS.size() - 1)]
	if fur:
		fur.set_instance_shader_parameter(&"fur_layers", float(layers))
		fur.visible = layers > 0
	for mi in meshes:
		if mi != fur and mi.name != &"Eyes":
			mi.set_instance_shader_parameter(&"skin_shade", 0.84 if layers > 0 else 1.0)


func _material(mi: MeshInstance3D, si: int) -> Material:
	var key := "%s/%s/%d" % [model_path(), mi.name, si]
	if _materials.has(key):
		return _materials[key]
	if mi.name == &"Eyes":
		var e := ShaderMaterial.new()
		e.shader = load("res://shaders/wolf_eye.gdshader")
		_materials[key] = e
		return e
	if mi.name != &"Fur":
		return super._material(mi, si)
	var m := _fur_material(mi.mesh.surface_get_material(si) as StandardMaterial3D)
	_materials[key] = m
	return m


# --- Moves -----------------------------------------------------------------------------------

## A lunge and bite: a spring forward, the jaws gaping, then snapping shut.
func lunge() -> void:
	if not is_dead():
		_lunge = 1.0


## Hit from `side` (+1: the blow came from its right): it jerks away.
func flinch(side: float) -> void:
	if not is_dead():
		_flinch = 1.0
		_flinch_side = signf(side) if side != 0.0 else 1.0


## Falls dead onto its `side` (+1: its right) and lies there.
func die(side: float) -> void:
	if is_dead():
		return
	_dead = 0.0
	_dead_side = signf(side) if side != 0.0 else 1.0
	if eyes:
		eyes.set_instance_shader_parameter(&"shine_amount", 0.0)


func is_dead() -> bool:
	return _dead >= 0.0


## How far into its fall (0 .. 1 lying still), -1 alive.
func dead_amount() -> float:
	return _dead


## Eased amounts for the owner and tests.
func gallop_amount() -> float:
	return _gallop


func crouch_amount() -> float:
	return _crouch_a


func howl_amount() -> float:
	return _howl_a


func lunge_amount() -> float:
	return _lunge


# --- Animation -----------------------------------------------------------------------------

func animate(delta: float, speed: float) -> void:
	if skeleton == null or delta <= 0.0:
		return
	if is_dead():
		_time += delta
		_dead = minf(_dead + delta / DIE_TIME, 1.0)
		skeleton.reset_bone_poses()
		_pose_dead()
		return
	var k := 1.0 - exp(-delta * 5.0)
	_crouch_a = lerpf(_crouch_a, clampf(crouch, 0.0, 1.0), k)
	_snarl_a = lerpf(_snarl_a, clampf(snarl, 0.0, 1.0), 1.0 - exp(-delta * 7.0))
	_howl_a = move_toward(_howl_a, clampf(howl, 0.0, 1.0) if _sit > 0.8 else 0.0, delta * 1.2)
	_tail_a = lerpf(_tail_a, clampf(tail_mood, -1.0, 1.0), 1.0 - exp(-delta * 3.0))
	_gallop = move_toward(_gallop, 1.0 if speed > GALLOP_FROM else 0.0, delta * 2.0)
	_lunge = move_toward(_lunge, 0.0, delta / LUNGE_TIME)
	_flinch = move_toward(_flinch, 0.0, delta / FLINCH_TIME)
	_howl_t += delta
	if fur:
		fur.set_instance_shader_parameter(&"ruffle", _snarl_a * 0.8)
	super.animate(delta, speed)


## The gallop's footfalls and short stance over the walk's and trot's.
func _touch(leg: String) -> float:
	return lerpf(super._touch(leg), float(TOUCH_GALLOP[leg]), _gallop)


func _duty() -> float:
	return lerpf(super._duty(), DUTY_GALLOP, _gallop)


## The spine, neck, head, tail and ears: a wolf's carriage and moves.
func _pose_body(delta: float) -> void:
	var s := smoothstep(0.0, 1.0, _sit)
	var l := smoothstep(0.0, 1.0, _lie)
	var ws := s * (1.0 - l)
	var wl := l
	var still := 1.0 - clampf(_gamp, 0.0, 1.0)
	var moving := clampf(_gamp, 0.0, 1.0)
	var ph := TAU * _phase
	var g := _gallop
	var cr := _crouch_a * (1.0 - ws) * (1.0 - wl)
	var sn := _snarl_a
	var hw := _howl_a * ws
	# The lunge: up and out over the first half, settling back over the second.
	var lt := 1.0 - _lunge if _lunge > 0.0 else 0.0
	var lp := sin(PI * lt) if _lunge > 0.0 else 0.0
	var fl := sin(PI * minf((1.0 - _flinch) * 1.6, 1.0)) * _flinch if _flinch > 0.0 else 0.0
	var fs := _flinch_side
	# Walking the body dips at each step, trotting it rises between the beats, galloping
	# it rides up over each stride; it rolls a little over the side that carries it.
	var bob := (-(0.5 + 0.5 * cos(2.0 * ph - 0.6)) * 0.01 * (1.0 - _trot) + (0.5 - 0.5 * cos(2.0 * ph)) * 0.016 * _trot) \
			* moving * (1.0 - g) + sin(ph - 0.8) * 0.035 * g
	var roll := sin(ph) * 0.02 * moving * (1.0 - g)
	var breath := sin(TAU * _breath)
	var dip := _nose * (1.0 - ws) * (1.0 - wl)
	var hips := Vector3(0.0, sit_hips.x, sit_hips.y) * ws + Vector3(0.0, lie_body.x, lie_body.y) * wl
	_crouch = move_toward(_crouch, clampf(_short * 1.2, 0.0, 0.05), delta * (0.8 if _short > _crouch else 0.05))
	hips.y += bob + breath * 0.0025 * still - lerpf(gait_crouch.x, gait_crouch.y, _trot) * moving - _crouch
	hips.x += _shift * 0.006 * still * (1.0 - ws - wl)
	# Stalking low; the lunge's spring; the flinch's jerk away from the blow.
	hips += Vector3(0.0, -0.13 * cr, 0.03 * cr)
	hips += Vector3(0.0, 0.05 * lp, -0.12 * lp)
	hips += Vector3(-0.05 * fs * fl, -0.03 * fl, 0.0)
	var pitch := _sit_pitch * ws + LIE_PITCH * wl - 0.07 * dip - 0.05 * cr + 0.14 * lp + sin(ph - 0.3) * 0.05 * g
	_hips = hips
	_offset("root", hips)
	_rot("root", Vector3(pitch, -0.12 * fs * fl, roll - _lean * 0.1 * maxf(ws, 0.4) - 0.18 * fs * fl))
	# The back flexes and stretches with the gallop's stride.
	var flex := sin(ph + 0.4) * 0.11 * g
	_rot("pelvis", Vector3(SIT_TUCK * ws + 0.05 * wl - flex * 0.8, 0.0, 0.12 * wl))
	_rot("spine1", Vector3(-0.08 * ws + breath * 0.004 + flex, 0.0, 0.0))
	_rot("spine2", Vector3(-0.06 * ws + breath * lerpf(0.008, 0.02, _pant) - 0.05 * wl - flex * 0.6, 0, -_lean * 0.05))
	# Neck and head: carried low and level (lower trotting, stretched out galloping), down
	# and forward stalking, low snarling; thrown up howling; up and out in the lunge;
	# turned to what it looks at.
	var yaw := _look.x * (1.0 - hw)
	var up := _look.y * (1.0 - hw)
	var nd := _nose
	var level := -_sit_pitch * ws - LIE_PITCH * wl
	var carry := -0.36 * (1.0 - ws) * (1.0 - wl) - 0.22 * moving * (1.0 - g) + 0.12 * g
	carry += -0.42 * cr - 0.22 * sn * (1.0 - hw)
	var nod := -(0.5 + 0.5 * cos(2.0 * ph - TAU * 0.44)) * 0.04 * moving * (1.0 - g) + sin(ph + 1.2) * 0.06 * g
	var howl_up := hw * (0.95 + 0.05 * sin(_howl_t * 2.1))
	_rot("neck1", Vector3(level * 0.45 - nd * 0.95 + up * 0.35 + 0.12 * wl + nod + carry * 0.6 + howl_up * 0.42 + lp * 0.22,
			yaw * 0.35 + 0.25 * fs * fl, 0))
	_rot("neck2", Vector3(level * 0.3 - nd * 0.4 + up * 0.3 + carry * 0.25 + howl_up * 0.3 + lp * 0.1, yaw * 0.3, 0))
	_rot("head", Vector3(level * 0.25 - nd * 0.45 + up * 0.35 - carry * 0.15 + howl_up * 0.35 + lp * 0.08 + 0.12 * cr,
			yaw * 0.35, -yaw * 0.08 - _lean * 0.15))
	# The jaw: ajar snarling, rounded and working howling, gaping then snapping in a lunge.
	var bite := 0.0
	if _lunge > 0.0:
		bite = 0.6 * smoothstep(0.0, 0.25, lt) * (1.0 - smoothstep(0.55, 0.7, lt))
	var song := hw * (0.26 + 0.06 * sin(_howl_t * 3.3) + 0.03 * sin(_howl_t * 7.1))
	_rot("jaw", Vector3(0.12 * sn + song + bite + _pant * (0.1 + 0.02 * sin(TAU * _breath)), 0, 0))
	# Tail: hanging; raised when it means business; tucked when it runs from something;
	# streaming out behind at a gallop; a slow sway with the gait.
	var tm := _tail_a
	var tcarry := 2.2 - 1.0 * maxf(tm, 0.0) + 0.35 * maxf(-tm, 0.0)
	tcarry = lerpf(tcarry, 1.15, g * (1.0 - maxf(-tm, 0.0)))
	tcarry = lerpf(tcarry, 0.6, ws)
	tcarry = lerpf(tcarry, 0.95, wl)
	tcarry += 0.35 * cr
	var sway := sin(ph * 2.0 + 0.5) * 0.08 * moving + sin(_time * 0.7) * 0.03 * still
	for i in 4:
		var p := tcarry if i == 0 else (0.02 - 0.04 * float(i) + 0.15 * maxf(-tm, 0.0) - 0.06 * g)
		if i == 1:
			p += -0.25 * ws + 0.1 * wl
		var sw := sway * (0.6 + 0.3 * float(i)) + sin(ph * 2.0 - float(i) * 0.6) * 0.05 * g
		_rot("tail%d" % (i + 1), Vector3(p, sw, 0))
	# Ears: up and a little forward; pricked stalking; laid back and out snarling, in a
	# lunge, flinching, a little howling; swinging with the head.
	var back := clampf(maxf(maxf(sn, _lunge * 1.2), maxf(fl * 1.5, ears_back)) + 0.3 * hw, 0.0, 1.0)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var n := "l" if i == 0 else "r"
		var swing := _ear_swing[i]
		var prick := 0.12 * cr
		_rot("ear_" + n, Vector3(-0.85 * back + prick + swing * 0.18, side * 0.25 * back, side * (0.3 * back + swing * 0.05)))
		_rot("ear_%s2" % n, Vector3(swing * 0.12 - 0.15 * back, 0, 0))


## Lying dead: the legs gone, rolled onto its side, the legs out and limp, the head and
## tail on the ground.
func _pose_dead() -> void:
	var t := _dead
	# The legs give first (the body drops), then it rolls over.
	var drop := smoothstep(0.0, 0.45, t)
	var over := smoothstep(0.2, 0.8, t)
	var side := _dead_side
	var root_h := _rest_rig("root").y
	var hips := Vector3(0.0, -(root_h - 0.13) * (0.55 * drop + 0.45 * over), 0.02 * drop)
	_offset("root", hips)
	_rot("root", Vector3(0.0, 0.0, side * PI * 0.5 * over))
	_rot("pelvis", Vector3(0.05, 0.0, 0.0))
	_rot("spine1", Vector3(-0.04, side * 0.08 * over, 0.0))
	_rot("spine2", Vector3(0.0, side * 0.08 * over, 0.0))
	# The head down to the ground beside it, the jaw slack.
	_rot("neck1", Vector3(-0.25 * drop, side * 0.2 * over, side * 0.15 * over))
	_rot("neck2", Vector3(-0.1 * drop, side * 0.15 * over, 0.0))
	_rot("head", Vector3(0.05, 0.0, side * 0.12 * over))
	_rot("jaw", Vector3(0.1 * drop, 0, 0))
	for i in 4:
		_rot("tail%d" % (i + 1), Vector3(0.9 if i == 0 else 0.05, side * 0.08 * over, 0.0))
	for i in 2:
		var n := "l" if i == 0 else "r"
		var es := -1.0 if i == 0 else 1.0
		_rot("ear_" + n, Vector3(-0.6 * drop, 0.0, es * 0.25 * drop))
	# Legs: the forelegs out ahead, the hind legs back, all a little bent, lying over
	# one another on the ground. (Rolled onto `side`, the ground is toward the body's
	# other side: -side along its x; the legs of that side are underneath.)
	for leg: String in LEGS:
		var front := leg.begins_with("f")
		var ls := -1.0 if leg.ends_with("l") else 1.0
		var under := ls == -side
		var droop := -side * (0.12 if under else 0.5) * over
		var a := over * (-0.45 if front else 0.55) + (0.12 if under else -0.1) * over
		if front:
			_rot(leg + "_sh", Vector3(-0.15 * over, 0.0, 0.0))
		_rot(leg + "_up", Vector3(a, 0.0, droop))
		_rot(leg + "_lo", Vector3((0.25 if front else -0.35) * over, 0.0, 0.0))
		_rot(leg + "_ft", Vector3((-0.2 if front else 0.3) * over, 0.0, 0.0))
		_rot(leg + "_toe", Vector3(0.4 * over, 0.0, 0.0))
