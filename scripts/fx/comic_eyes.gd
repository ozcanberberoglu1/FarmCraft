class_name ComicEyes
extends Node3D
## Big cartoon eyes on the poultry and the fish (the "Komik hayvanlar" setting, see
## ComicFx): a glossy white ball each side of the head, about three times a real eye, its black
## pupil (shaders/comic_eye.gdshader) glancing about and turning to the farmer when he is
## near, blinking now and then and wobbling when the head is jolted.
## On a bird it rides the head bone and watches the rig: a rooster out cold after his
## faint has X eyes and stars going round his head; a hen the farmer sprints right past
## jumps with a squawk and a puff of feathers (rarely); a chick now and then trips over its
## own feet. On a fish it sits on the model: flopping, the eyes roll; held up, it blinks
## slowly. Only animated near the camera; far off the balls are not drawn at all.

enum Kind { BIRD, FISH }
## A fish's situation: lying about (a dropped one), flopping on the bank, held up.
enum Mood { NORMAL, FLOP, HELD }

## Per poultry model: its right eye's middle in the head bone's space (the left one
## mirrored across axis `mirror`), the way it faces out of the head, the real eye's radius
## (bone units, measured on the model) and how many times bigger the cartoon one is; the
## eyelid's colour.
const BIRDS := {
	&"chicken": {"centre": Vector3(2.95, 1.85, 2.62), "out": Vector3(0.5, 0.3, 1.0), "mirror": 2, "radius": 0.65,
		"grow": 3.2, "lid": Color(0.72, 0.2, 0.15)},
	&"rooster": {"centre": Vector3(2.95, 1.85, 2.62), "out": Vector3(0.5, 0.3, 1.0), "mirror": 2, "radius": 0.65,
		"grow": 3.2, "lid": Color(0.72, 0.2, 0.15)},
	# The chick: a bigger share of its little head (cute).
	&"chick": {"centre": Vector3(0.0165, 0.018, 0.0127), "out": Vector3(1.0, 0.35, 0.65), "mirror": 0, "radius": 0.0052,
		"grow": 3.4, "lid": Color(0.95, 0.82, 0.45)},
}
## A fish's eyes are its model's own (its "_iris" parts) this many times bigger.
const FISH_GROW := 3.0
const FISH_LID := Color(0.58, 0.58, 0.54)
## How far the ball sits back into the head, share of its radius (the rest bulges out).
const SINK := 0.3
## Metres from the camera within which the eyes move at all, look at the farmer, and
## beyond which they are not drawn.
const ANIMATE_NEAR := 16.0
const LOOK_NEAR := 6.0
const DRAW_FAR := 32.0
## Furthest a pupil turns from straight out of the head (radians).
const LOOK_MAX := 0.95
## Seconds between blinks, and a blink's length (held up: slow ones).
const BLINK_WAIT := Vector2(2.2, 6.0)
const BLINK_TIME := 0.16
const SLOW_BLINK_WAIT := Vector2(2.0, 3.6)
const SLOW_BLINK_TIME := 0.8
## The wobble: spring stiffness and damping, how much a jolt (m/s²) moves it, its most.
const JIGGLE_K := 220.0
const JIGGLE_C := 10.0
const JIGGLE_GAIN := 0.012
const JIGGLE_MAX := 0.45
## A hen the farmer runs right past (closer than STARTLE_NEAR m, faster than STARTLE_SPEED
## m/s): STARTLE_CHANCE of the time she jumps STARTLE_HOP m for STARTLE_TIME s; then not
## again for STARTLE_REST s (nor any hen for STARTLE_ANY s).
const STARTLE_NEAR := 1.6
const STARTLE_SPEED := 5.4
const STARTLE_CHANCE := 0.6
const STARTLE_HOP := 0.17
const STARTLE_TIME := 0.42
const STARTLE_REST := 30.0
const STARTLE_ANY := 3.0
## A chick walking near the camera trips now and then: seconds of walking between the
## chances, the chance, and the tumble's length.
const TUMBLE_WAIT := Vector2(14.0, 34.0)
const TUMBLE_CHANCE := 0.35
const TUMBLE_TIME := 0.8
const TUMBLE_NEAR := 10.0

static var _ball: SphereMesh
static var _shader: Shader
static var _spots_cache := {}
static var _last_startle := -100.0
## Tests: every pass that may startle a hen does (no roll of the dice).
static var always_startle := false

var kind := Kind.BIRD
var mood := Mood.NORMAL
## The rig (birds) or the fish's mesh instance (fish).
var rig: AnimalRig
var host: MeshInstance3D
## The two balls, their rest positions, the node they ride (the head's bone attachment, or
## this node on a fish).
var eyes: Array[MeshInstance3D] = []
var _rest: Array[Vector3] = []
var _mount: Node3D
var _spec := {}
var _t := 0.0
var _gaze: Array[Vector3] = [Vector3.BACK, Vector3.BACK]
var _idle := Vector3.BACK
var _idle_wait := 0.0
var _blink_wait := 1.0
var _blink_t := -1.0
var _jig := Vector3.ZERO
var _jig_v := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _last_vel := Vector3.ZERO
var _moved := false
var _speed := 0.0
## 0..1 rolling (a fish thrashing), and the roll's angle.
var _roll := 0.0
var _roll_a := 0.0
## Out cold (X eyes) and the stars going round his head.
var _out := false
var _stars: Node3D
var _startle_t := -1.0
var _startle_rest := 0.0
var _tumble_t := -1.0
var _tumble_wait := 0.0
## The body's height and pitch before a jump or a tumble moved it.
var _base_y := 0.0
var _base_pitch := 0.0
var _rng := RandomNumberGenerator.new()


## The eyes for a poultry rig (null for anything else).
static func for_rig(animal_rig: AnimalRig) -> ComicEyes:
	if not BIRDS.has(animal_rig.species) or not animal_rig.skeleton or not animal_rig._b.has("head"):
		return null
	var e := ComicEyes.new()
	e.name = "ComicEyes"
	e.kind = Kind.BIRD
	e.rig = animal_rig
	e._spec = BIRDS[animal_rig.species]
	return e


## The eyes for a fish model (null when the mesh has no eyes of its own to go by).
static func for_fish(mi: MeshInstance3D, fallback: Mesh = null, fish_mood := Mood.NORMAL) -> ComicEyes:
	var spots := fish_spots(mi.mesh)
	if spots.is_empty() and fallback:
		spots = fish_spots(fallback)
	if spots.is_empty():
		return null
	var e := ComicEyes.new()
	e.name = "ComicEyes"
	e.kind = Kind.FISH
	e.mood = fish_mood
	e.host = mi
	e._spec = spots
	return e


## Where a fish model's eyes are: {centre: [right, left], out: [...], radius} from its
## "_iris" parts (fish lie along +X, their flanks facing +-Z); {} without them.
static func fish_spots(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}
	if _spots_cache.has(mesh):
		return _spots_cache[mesh]
	var sums := [Vector3.ZERO, Vector3.ZERO]
	var counts := [0, 0]
	var pts: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si)
		var names := [String(mesh.surface_get_name(si)), mat.resource_name if mat else ""]
		var iris := false
		for n: String in names:
			if n.ends_with("_iris") and not n.contains("cooked"):
				iris = true
		if not iris:
			continue
		for v: Vector3 in mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			var side := 0 if v.z >= 0.0 else 1
			sums[side] += v
			counts[side] += 1
			pts[side].append(v)
	var out := {}
	if counts[0] > 0 and counts[1] > 0:
		var centres: Array[Vector3] = [sums[0] / counts[0], sums[1] / counts[1]]
		var r := 0.0
		for side in 2:
			for v in pts[side]:
				r = maxf(r, Vector2(v.x - centres[side].x, v.y - centres[side].y).length())
		out = {"centre": centres, "out": [Vector3(0.0, 0.12, 1.0).normalized(), Vector3(0.0, 0.12, -1.0).normalized()],
			"radius": r}
	_spots_cache[mesh] = out
	return out


func _ready() -> void:
	_rng.randomize()
	_blink_wait = _rng.randf_range(0.5, BLINK_WAIT.y)
	_tumble_wait = _rng.randf_range(TUMBLE_WAIT.x, TUMBLE_WAIT.y)
	if _ball == null:
		_ball = SphereMesh.new()
		_ball.radius = 1.0
		_ball.height = 2.0
		_ball.radial_segments = 20
		_ball.rings = 10
		_shader = load("res://shaders/comic_eye.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var lid: Color
	if kind == Kind.BIRD:
		var bone := rig.skeleton.get_bone_name(int(rig._b["head"]))
		var at := BoneAttachment3D.new()
		at.name = "ComicHead"
		rig.skeleton.add_child(at)
		at.bone_name = bone
		_mount = at
		var c: Vector3 = _spec["centre"]
		var o: Vector3 = (_spec["out"] as Vector3).normalized()
		var axis: int = _spec["mirror"]
		var r: float = float(_spec["radius"]) * float(_spec["grow"])
		for side in 2:
			var cc := c
			var oo := o
			if side == 1:
				cc[axis] = -cc[axis]
				oo[axis] = -oo[axis]
			_add_eye(mat, cc - oo * r * SINK, oo, r)
		lid = _spec["lid"]
	else:
		_mount = self
		var grow := FISH_GROW
		var r: float = float(_spec["radius"]) * grow
		for side in 2:
			var oo: Vector3 = _spec["out"][side]
			_add_eye(mat, (_spec["centre"][side] as Vector3) - oo * r * SINK, oo, r)
		lid = FISH_LID
		if mood == Mood.HELD:
			_blink_wait = _rng.randf_range(0.6, 1.4)
	for e in eyes:
		e.set_instance_shader_parameter(&"lid", lid)
	_last_pos = _mount.global_position if _mount.is_inside_tree() else Vector3.ZERO


func _add_eye(mat: ShaderMaterial, at: Vector3, out: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Eye%d" % eyes.size()
	mi.mesh = _ball
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.layers = 2
	mi.visibility_range_end = DRAW_FAR
	# +Z straight out of the head, +Y as near the head's up as it goes.
	var x := Vector3.UP.cross(out).normalized()
	var y := out.cross(x).normalized()
	mi.transform = Transform3D(Basis(x, y, out).scaled(Vector3.ONE * r), at)
	_mount.add_child(mi)
	eyes.append(mi)
	_rest.append(at)


func _exit_tree() -> void:
	if is_instance_valid(_mount) and _mount != self:
		_mount.queue_free()
	if is_instance_valid(_stars):
		_stars.queue_free()
	# A jump or a tumble cut short: the body back where it was.
	if kind == Kind.BIRD and is_instance_valid(rig):
		if _startle_t >= 0.0:
			rig.position.y = _base_y
			rig.fluff = 0.0
		if _tumble_t >= 0.0:
			rig.rotation.x = _base_pitch


## Out cold with X eyes (a fainted rooster).
func is_out() -> bool:
	return _out


func _process(delta: float) -> void:
	if eyes.is_empty() or not _mount.is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := _mount.global_position
	var dist := cam.global_position.distance_to(head)
	_update_motion(head, delta)
	if kind == Kind.BIRD:
		_update_bird(delta, dist, cam.global_position)
	if dist > ANIMATE_NEAR or not is_visible_in_tree():
		return
	_t += delta
	if kind == Kind.FISH:
		_update_fish(delta)
	_update_blink(delta)
	# Where the pupils go: the farmer when near (in front of the eye), else a glance about;
	# round and round as a fish thrashes.
	_idle_wait -= delta
	if _idle_wait <= 0.0:
		_idle_wait = _rng.randf_range(0.7, 2.6)
		_idle = Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.3, 0.35), 1.0).normalized()
	_roll_a += delta * 13.0
	var k := 1.0 - exp(-delta * 16.0)
	for i in eyes.size():
		var e := eyes[i]
		var want := _idle
		if dist < LOOK_NEAR or mood == Mood.HELD:
			var to := (e.global_transform.affine_inverse() * cam.global_position).normalized()
			if to.z > -0.2:
				want = _clamp_look(to)
		if _roll > 0.0:
			var circle := Vector3(cos(_roll_a) * 0.75, sin(_roll_a) * 0.75, 1.0).normalized()
			want = want.slerp(circle, _roll)
		# The wobble, in the eye's own frame.
		var j := e.global_basis.orthonormalized().inverse() * _jig
		want = (want + Vector3(j.x, j.y, 0.0)).normalized()
		_gaze[i] = _gaze[i].slerp(want, k).normalized()
		e.set_instance_shader_parameter(&"gaze", _gaze[i])
		e.set_instance_shader_parameter(&"mode", 1.0 if _out else 0.0)


## Looking no further than LOOK_MAX from straight out.
func _clamp_look(d: Vector3) -> Vector3:
	var a := Vector3.BACK.angle_to(d)
	if a <= LOOK_MAX:
		return d
	var axis := Vector3.BACK.cross(d)
	if axis.length_squared() < 1e-8:
		return Vector3.BACK
	return Vector3.BACK.rotated(axis.normalized(), LOOK_MAX)


## How the head moves: its speed, and the jolts that set the pupils wobbling.
func _update_motion(head: Vector3, delta: float) -> void:
	if delta <= 0.0:
		return
	var vel := (head - _last_pos) / delta
	_last_pos = head
	if not _moved or vel.length() > 25.0:
		# First frame, or moved across the world: no jolt.
		_moved = true
		_last_vel = Vector3.ZERO
		return
	var acc := ((vel - _last_vel) / delta).limit_length(80.0)
	_last_vel = vel
	_speed = lerpf(_speed, Vector2(vel.x, vel.z).length(), clampf(delta * 6.0, 0.0, 1.0))
	_jig_v += (-JIGGLE_K * _jig - JIGGLE_C * _jig_v - acc * JIGGLE_GAIN * JIGGLE_K) * delta
	_jig += _jig_v * delta
	_jig = _jig.limit_length(JIGGLE_MAX)


func _update_blink(delta: float) -> void:
	var slow := kind == Kind.FISH and mood == Mood.HELD
	var length := SLOW_BLINK_TIME if slow else BLINK_TIME
	var b := 0.0
	if _out:
		_blink_t = -1.0
	elif _blink_t >= 0.0:
		_blink_t += delta
		var u := _blink_t / length
		# Shut quickly, open a little slower (a slow one droops shut and lifts).
		b = u / 0.4 if u < 0.4 else 1.0 - (u - 0.4) / 0.6
		if u >= 1.0:
			_blink_t = -1.0
			b = 0.0
	else:
		_blink_wait -= delta
		if _blink_wait <= 0.0:
			_blink_t = 0.0
			var wait := SLOW_BLINK_WAIT if slow else BLINK_WAIT
			_blink_wait = _rng.randf_range(wait.x, wait.y)
	for e in eyes:
		e.set_instance_shader_parameter(&"blink", clampf(b, 0.0, 1.0))


## Starts a blink now (tests).
func blink_now() -> void:
	_blink_t = 0.0


# --- Fish ----------------------------------------------------------------------------------

## The balls go with the head as the body bends (shaders/fish.gdshader's bend), and roll
## while the fish thrashes.
func _update_fish(delta: float) -> void:
	var flex := _param(&"flex")
	var thrash := mood == Mood.FLOP and flex > 0.5
	_roll = move_toward(_roll, 1.0 if thrash else 0.0, delta * (6.0 if thrash else 1.6))
	var mesh := host.mesh
	if mesh == null:
		return
	var half := maxf(mesh.get_aabb().size.x * 0.5, 0.01)
	var phase := _param(&"flex_phase")
	var curl := _param(&"curl")
	for i in eyes.size():
		var x := _rest[i].x
		var u := x / half
		var t := clampf((0.55 - u) / 1.55, 0.0, 1.0)
		var off := flex * half * 0.42 * t * t * sin(phase - t * 3.2) + curl * half * 0.35 * (u * u - 0.33)
		eyes[i].position = _rest[i] + Vector3(0.0, 0.0, off)


func _param(p: StringName) -> float:
	var v: Variant = host.get_instance_shader_parameter(p)
	return float(v) if v != null else 0.0


## Whether the eyes are rolling (a fish thrashing).
func is_rolling() -> bool:
	return _roll > 0.5


# --- Birds ---------------------------------------------------------------------------------

func _update_bird(delta: float, dist: float, cam: Vector3) -> void:
	# Out cold after the faint: X eyes, stars round his head; back up, they go.
	var out := rig.faint >= 0.98 and rig.tremble < 0.3
	if out != _out:
		_out = out
		if out:
			_blink_t = -1.0
		for e in eyes:
			e.set_instance_shader_parameter(&"mode", 1.0 if out else 0.0)
	if _out:
		if _stars == null:
			_stars = ComicFx.make_stars()
			add_child(_stars)
		_stars.visible = true
		ComicFx.spin_stars(_stars, _mount.global_position, Time.get_ticks_msec() * 0.001, rig.scale.x, cam)
	elif _stars and _stars.visible:
		_stars.visible = false
	var animal := rig.get_parent() as Animal
	if animal == null:
		return
	_update_startle(delta, animal, dist)
	_update_tumble(delta, animal, dist)


## Startled hen: a hop straight up, a squawk, two or three feathers.
func _update_startle(delta: float, animal: Animal, dist: float) -> void:
	_startle_rest -= delta
	if _startle_t >= 0.0:
		_startle_t += delta
		var u := clampf(_startle_t / STARTLE_TIME, 0.0, 1.0)
		rig.position.y = _base_y + STARTLE_HOP * rig.scale.x * 4.0 * u * (1.0 - u)
		rig.fluff = sin(PI * u)
		if u >= 1.0:
			_startle_t = -1.0
			rig.position.y = _base_y
			rig.fluff = 0.0
		return
	if rig.species != &"chicken" or dist > 4.0 or _startle_rest > 0.0:
		return
	var player := Game.player as Player
	if player == null or player.driving:
		return
	var flat := Vector2(player.global_position.x - animal.global_position.x, player.global_position.z - animal.global_position.z)
	if flat.length() > STARTLE_NEAR or Vector2(player.velocity.x, player.velocity.z).length() < STARTLE_SPEED:
		return
	if animal.state in [Animal.State.SLEEP, Animal.State.NEST, Animal.State.HATCH, Animal.State.AWAY] or animal.ridden:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_startle < STARTLE_ANY:
		return
	# One roll per pass: win or lose, not again for a while.
	_startle_rest = 6.0
	if _rng.randf() >= STARTLE_CHANCE and not always_startle:
		return
	startle()


## Jumps with a squawk and a puff of feathers.
func startle() -> void:
	if _startle_t >= 0.0:
		return
	var animal := rig.get_parent() as Node3D
	_last_startle = Time.get_ticks_msec() * 0.001
	_startle_rest = STARTLE_REST
	_startle_t = 0.0
	_base_y = rig.position.y
	_blink_t = -1.0
	_jig_v += Vector3(0.0, 6.0, 0.0)
	var at := (animal.global_position if animal else rig.global_position) + Vector3(0, 0.3, 0)
	Audio.play("chicken", at, 2.0, 0.05, &"Effects", 5.0, 1.45)
	ComicFx.feather_puff(at, _coat())


## Whether she is in the air from a fright.
func is_startled() -> bool:
	return _startle_t >= 0.0


func _coat() -> Color:
	var animal := rig.get_parent() as Animal
	var list: Array = AnimalModels.VARIANTS.get(&"chicken", [{}])
	var v := animal.data.variant if animal and animal.data else 0
	return (list[clampi(v, 0, list.size() - 1)] as Dictionary).get("coat", Color.WHITE)


## A chick on the move near the camera trips now and then: nose down onto the ground and
## straight back up.
func _update_tumble(delta: float, animal: Animal, dist: float) -> void:
	if _tumble_t >= 0.0:
		_tumble_t += delta
		var u := clampf(_tumble_t / TUMBLE_TIME, 0.0, 1.0)
		var down := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.55, 1.0, u))
		rig.rotation.x = _base_pitch - 1.15 * down
		if u >= 1.0:
			_tumble_t = -1.0
			rig.rotation.x = _base_pitch
		return
	if rig.species != &"chick" or dist > TUMBLE_NEAR or _speed < 0.12 or animal.state == Animal.State.HATCH:
		return
	_tumble_wait -= delta
	if _tumble_wait > 0.0:
		return
	_tumble_wait = _rng.randf_range(TUMBLE_WAIT.x, TUMBLE_WAIT.y)
	if _rng.randf() < TUMBLE_CHANCE:
		tumble()


## Trips over its own feet.
func tumble() -> void:
	if _tumble_t >= 0.0:
		return
	_base_pitch = rig.rotation.x
	_tumble_t = 0.0
	Audio.play("chick", rig.global_position + Vector3(0, 0.1, 0), -9.0, 0.1, &"Effects", 3.0, 1.15)


func is_tumbling() -> bool:
	return _tumble_t >= 0.0
