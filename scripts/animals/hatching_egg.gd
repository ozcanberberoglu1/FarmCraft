class_name HatchingEgg
extends Node3D
## A fertile egg hatching where it lay (ChickenCoop): lying on its side it rocks now and
## then as the chick inside pecks at the shell (small taps and cracks, a fleck of shell),
## harder and harder, until the shell splits round its middle: the cap tumbles off, the
## chick (Animal.emerge) stands up out of the bottom half, and the two halves of shell lie
## there a while before they crumble away. The egg is the egg item's own model; the
## halves are lathed here with a jagged break, brown outside and white inside.

## Seconds of rocking and pecking before the shell gives way, the taps within them
## (seconds), how long the empty halves lie about, and how long they take to go.
const ROCK_TIME := 3.4
const TAPS := [0.35, 1.2, 1.9, 2.45, 2.85, 3.15]
const SHELLS_STAY := 9.0
const SHELLS_FADE := 1.2
## The egg item's profile (ItemModels._egg): its length along its axis and widest radius.
const HALF_LEN := 0.03
const RADIUS := 0.022
const SHELL := Color(0.86, 0.72, 0.55)
const INSIDE := Color(0.96, 0.94, 0.88)

var chick: Animal
var _t := 0.0
var _tap := 0
var _egg: MeshInstance3D
var _pivot: Node3D
var _cap: MeshInstance3D
var _base: MeshInstance3D
var _open := false
var _cap_vel := Vector3.ZERO
var _cap_spin := Vector3.ZERO

static var _cap_mesh: ArrayMesh
static var _base_mesh: ArrayMesh
static var _material: StandardMaterial3D


## Starts an egg hatching at `at` (world, where the egg lay, turned `yaw`) for `hatchling`
## (hidden until the shell gives way).
static func start(parent: Node, at: Vector3, yaw: float, hatchling: Animal) -> HatchingEgg:
	var h := HatchingEgg.new()
	h.chick = hatchling
	parent.add_child(h)
	h.global_position = at
	h.rotation.y = yaw
	return h


func _ready() -> void:
	# Moved by code each frame: no interpolation between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _cap_mesh == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.55
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cap_mesh = _half(true)
		_base_mesh = _half(false)
	# On its side, the way it lay in the straw: the egg's long axis along X.
	_pivot = Node3D.new()
	_pivot.position.y = RADIUS * 0.92
	add_child(_pivot)
	_egg = MeshInstance3D.new()
	_egg.mesh = ItemModels.mesh(&"egg")
	_egg.rotation.z = PI * 0.5
	_pivot.add_child(_egg)
	for m: MeshInstance3D in [_egg]:
		m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		m.layers = 2
	Audio.play("egg_crack", global_position, -12.0, 0.12, &"Effects", 3.0)


func _process(delta: float) -> void:
	_t += delta
	if not _open:
		_rock()
		if _t >= ROCK_TIME:
			_break()
		return
	# The cap tumbles off and settles; the halves go in the end.
	if _cap.position.y > 0.0 or _cap_vel.y > 0.0:
		_cap_vel.y -= 9.8 * delta
		_cap.position += _cap_vel * delta
		_cap.rotation += _cap_spin * delta
		if _cap.position.y <= 0.0:
			_cap.position.y = 0.0
			_cap_vel = Vector3.ZERO
			_cap_spin = Vector3.ZERO
	var gone := _t - ROCK_TIME - SHELLS_STAY
	if gone > 0.0:
		var k := clampf(1.0 - gone / SHELLS_FADE, 0.0, 1.0)
		_cap.scale = Vector3.ONE * maxf(k, 0.01)
		_base.scale = Vector3.ONE * maxf(k, 0.01)
		if k <= 0.0:
			queue_free()


## Rocking on its side, harder toward the end; a tap (and a fleck of shell) now and then.
func _rock() -> void:
	var build := _t / ROCK_TIME
	var shake := 0.0
	for tt: float in TAPS:
		var d := _t - tt
		if d > 0.0 and d < 0.35:
			shake += sin(d * 40.0) * exp(-d * 9.0) * (0.25 + 0.35 * build)
	_pivot.rotation.x = shake + sin(_t * 2.3) * 0.03 * build
	_pivot.rotation.z = shake * 0.4
	if _tap < TAPS.size() and _t >= float(TAPS[_tap]):
		_tap += 1
		Audio.play("egg_crack", global_position, -14.0 + 4.0 * build, 0.15, &"Effects", 3.0)
		Fx._burst(global_position + Vector3(0, RADIUS * 1.6, 0), INSIDE, 2 + _tap / 2, Vector3(0.01, 0.005, 0.01),
				0.35, 0.6, 50.0, 0.006, Vector3.UP, 6.0, 0.0, 1.0, false, 0.4)


## The shell gives way: two halves, the cap thrown aside, the chick stands up.
func _break() -> void:
	_open = true
	_egg.visible = false
	_base = MeshInstance3D.new()
	_base.mesh = _base_mesh
	_base.material_override = _material
	# The round end rolls back, open side up; the cap (the tip, toward -X) flies off.
	_base.rotation = Vector3(0.0, 0.0, PI * 0.5 - 1.05)
	_base.position = Vector3(0.008, RADIUS * 0.75, 0.0)
	_cap = MeshInstance3D.new()
	_cap.mesh = _cap_mesh
	_cap.material_override = _material
	_cap.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_cap.position = Vector3(0.0, RADIUS * 0.92, 0.0)
	for m: MeshInstance3D in [_base, _cap]:
		m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		m.layers = 2
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	_cap_vel = Vector3(-randf_range(0.15, 0.3), 0.55, randf_range(-0.2, 0.2))
	_cap_spin = Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(4.0, 9.0))
	Audio.play("egg_hatch", global_position, -6.0, 0.08, &"Effects", 3.5)
	Fx._burst(global_position + Vector3(0, RADIUS, 0), INSIDE, 6, Vector3(0.015, 0.01, 0.015),
			0.6, 0.8, 70.0, 0.007, Vector3.UP, 7.0, 0.0, 1.2, false, 0.4)
	Fx._burst(global_position + Vector3(0, RADIUS, 0), SHELL, 5, Vector3(0.015, 0.01, 0.015),
			0.5, 0.8, 70.0, 0.006, Vector3.UP, 7.0, 0.0, 1.2, false, 0.4)
	if is_instance_valid(chick):
		chick.emerge()


## Half an eggshell lathed round its axis (Y, the tip up): the tip half (`cap`) or the
## round end, cut along a jagged line near the middle; brown outside, white inside.
static func _half(cap: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 20
	var rows := 9
	var cut := 0.02
	for side in 2:
		var inner := side == 1
		var col := INSIDE if inner else SHELL
		var shrink := 0.0012 if inner else 0.0
		for i in rows:
			for j in segs:
				var quad: Array[Vector3] = []
				for c: Array in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
					quad.append(_shell_point(cap, int(c[0]), int(c[1]), rows, segs, cut, shrink))
				var tris := [[0, 1, 2], [0, 2, 3]]
				for tri: Array in tris:
					var order: Array = tri if not inner else [tri[0], tri[2], tri[1]]
					var a: Vector3 = quad[order[0]]
					var b: Vector3 = quad[order[1]]
					var c: Vector3 = quad[order[2]]
					var n := (b - a).cross(c - a).normalized()
					for p: Vector3 in [a, b, c]:
						st.set_color(col)
						st.set_normal(n if n.length() > 0.5 else Vector3.UP)
						st.add_vertex(p)
	return st.commit()


## A point on the shell: row `i` of `rows` from the pole to the jagged break, column `j`.
static func _shell_point(cap: bool, i: int, j: int, rows: int, segs: int, cut: float, shrink: float) -> Vector3:
	var a := TAU * float(j % segs) / segs
	# The break zigzags a few millimetres either side of the middle.
	var zig := (0.004 if j % 2 == 0 else -0.003)
	var edge_t := 0.5 + (cut if cap else -cut) * 0.5 + zig / (HALF_LEN * 2.0)
	var t: float
	if cap:
		t = lerpf(1.0, edge_t, float(i) / rows)
	else:
		t = lerpf(0.0, edge_t, float(i) / rows)
	var y := lerpf(-0.029, 0.031, t)
	var r := RADIUS * sqrt(maxf(sin(t * PI), 0.0)) * (1.08 - 0.22 * t)
	r = maxf(r - shrink, 0.0005)
	return Vector3(cos(a) * r, y, sin(a) * r)
