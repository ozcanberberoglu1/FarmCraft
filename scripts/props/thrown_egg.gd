class_name ThrownEgg
extends Node3D
## An egg thrown from the hand (LMB with an egg): it flies on an arc where the player
## looked and breaks on the first thing it hits, leaving a splash of yolk for a while.

const GRAVITY := 9.8
## Seconds in the air before it is given up on (thrown off a cliff, into the sky).
const MAX_FLIGHT := 5.0
## The world and the animals stop it (not the player, pickups or interaction volumes).
const HIT_MASK := 1 | 16
## How long the yolk stays on the ground before it fades.
const SPLAT_SECONDS := 14.0

static var _shell_mat: StandardMaterial3D
static var _yolk_mat: StandardMaterial3D
static var _white_mat: StandardMaterial3D

var velocity := Vector3.ZERO
var _exclude: Array[RID] = []
var _age := 0.0


static func launch(from: Vector3, vel: Vector3, thrower: CollisionObject3D = null) -> ThrownEgg:
	var e := ThrownEgg.new()
	e.velocity = vel
	if thrower:
		e._exclude = [thrower.get_rid()]
	e.position = from
	Game.world.add_child(e)
	e.reset_physics_interpolation()
	return e


func _ready() -> void:
	add_to_group(&"thrown_eggs")
	if _shell_mat == null:
		_shell_mat = _mat(Color(0.93, 0.86, 0.72), 0.6)
		_yolk_mat = _mat(Color(0.96, 0.66, 0.1), 0.15)
		_white_mat = _mat(Color(0.97, 0.95, 0.88, 0.75), 0.1)
		_white_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.024
	m.height = 0.062
	m.radial_segments = 12
	m.rings = 6
	m.material = _shell_mat
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _physics_process(delta: float) -> void:
	_age += delta
	var from := global_position
	velocity.y -= GRAVITY * delta
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_break(hit["position"], hit["normal"])
		return
	global_position = to
	rotate_object_local(Vector3.RIGHT, delta * 14.0)
	if _age > MAX_FLIGHT:
		queue_free()


func _break(at: Vector3, normal: Vector3) -> void:
	Fx.egg_splat(at, normal)
	Audio.play("soft", at, -2.0, 0.1, &"Effects", 5.0, 1.5)
	Audio.play("splash", at, -16.0, 0.1, &"Effects", 5.0, 1.9)
	_leave_splat(at, normal)
	Events.egg_broken.emit(at)
	queue_free()


## The broken egg on whatever it hit: a puddle of white round the yolk, flat on the
## surface, fading away after a while.
func _leave_splat(at: Vector3, normal: Vector3) -> void:
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var splat := Node3D.new()
	Game.world.add_child(splat)
	var side := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.UP)) > 0.9 else Vector3.UP).normalized()
	splat.global_transform = Transform3D(Basis(side, n, side.cross(n)).orthonormalized(), at + n * 0.006)
	splat.rotate_object_local(Vector3.UP, randf() * TAU)
	var parts: Array[MeshInstance3D] = []
	for p: Array in [[_white_mat, 0.07, 0.004, Vector3.ZERO], [_yolk_mat, 0.026, 0.012, Vector3(0.012, 0.004, 0.006)]]:
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = float(p[1])
		m.bottom_radius = float(p[1])
		m.height = float(p[2])
		m.radial_segments = 14
		m.rings = 1
		m.material = p[0]
		mi.mesh = m
		mi.position = p[3]
		mi.scale = Vector3(1.0, 1.0, randf_range(0.7, 1.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splat.add_child(mi)
		parts.append(mi)
	var tw := splat.create_tween()
	tw.tween_interval(SPLAT_SECONDS)
	tw.tween_property(splat, "scale", Vector3(0.01, 1.0, 0.01), 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(splat.queue_free)


static func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
