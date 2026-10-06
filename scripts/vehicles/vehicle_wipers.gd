class_name VehicleWipers
extends Node3D
## Rain on a vehicle's windows, and the wipers that clear its windscreen (a child of
## the Vehicle, made by Vehicle._fit_pane for one with window panes: the tractor has
## none). While rain falls on it (Weather.rain_fall; not under a roof) water builds up
## on the panes (`wet`) and dries off again afterwards; for as long as there is any, the
## panes are drawn by vehicle_glass_wet.gdshader (drops that bead up and run down, the
## side windows' leaning back with speed) and get the rain and the wipers' cycle as
## shader parameters. With somebody at the wheel the wipers sweep by themselves: now and
## then in light rain, without a pause in a storm; a sweep that has begun is finished
## and parked. The blades are simple arms built here over the windscreen's own surface
## (the models' still ones are cut away), at the pivots and arcs the glass shader clears.

const DRY := preload("res://shaders/vehicle_glass.gdshader")
const WET := preload("res://shaders/vehicle_glass_wet.gdshader")
## Seconds one stroke takes (parked to right over, or back): in rain, in a storm.
const STROKE := 0.62
const STROKE_FAST := 0.46
## Seconds the blades stay parked between two sweeps in steady rain, and in the first
## and last drops of a shower. A storm (STORM_FROM of Weather.rain_fall) gets no pause.
const PAUSE := 1.9
const PAUSE_LIGHT := 3.6
const STORM_FROM := 0.9
## Seconds of rain for the panes to bead up fully, and of dry weather to dry off.
const WET_UP := 5.0
const DRY_OFF := 50.0
## "Never wiped" (seconds).
const NEVER := 1.0e6
## Blade poses worked out along a sweep (the rest is interpolated).
const SAMPLES := 16
## How much of the rain a pane catches: the windscreen, the rear glass, a side window.
const CATCH := Vector3(1.0, 0.85, 0.75)
## The blades of a windscreen pane, by the pane's mesh name: "blades" (per blade: the
## pivot's x as a share of the pane's width and its y in pane heights, the blade's inner
## and outer reach from it in pane heights) and "sweep" (the angle they park at and how
## far they turn from it, radians from pane +x, which runs to the vehicle's right;
## negative turns clockwise). The same numbers go to the glass shader.
const LAYOUT := {"Windshield": {"blades": [Vector4(0.14, -0.04, 0.1, 0.9), Vector4(0.52, -0.04, 0.1, 0.9)],
	"sweep": Vector2(0.12, 1.85)}}
## Vehicles that have theirs differently: the four-by-four's hang from the top rail of
## its split screen, one to a pane.
const LAYOUTS := {
	&"offroad": {"Windshield_L": {"blades": [Vector4(0.48, 1.0, 0.1, 0.64)], "sweep": Vector2(-0.82, -1.5)},
		"Windshield_R": {"blades": [Vector4(0.52, 1.0, 0.1, 0.64)], "sweep": Vector2(-2.32, 1.5)}},
}
## The models' own wipers, which cannot move: cut away (ModelStrip: the loose parts of
## the mesh of that name inside the box, model frame), by model.
const BAKED := {
	"res://art/models/vehicles/pickup_90/scene.gltf": ["bottom", AABB(Vector3(1.37, 1.22, -0.6), Vector3(0.14, 0.09, 1.05))],
	"res://art/models/vehicles/wagon/wagon.glb": ["Wagon_Body", AABB(Vector3(1.6, 0.87, -0.62), Vector3(0.11, 0.07, 1.24))],
	"res://art/models/vehicles/truck/truck.glb": ["Truck_Body", AABB(Vector3(3.97, 1.36, -0.82), Vector3(0.05, 0.06, 1.64))],
	"res://art/models/vehicles/offroad/offroad.glb": ["Offroad_Body", AABB(Vector3(1.94, 1.48, -0.44), Vector3(0.04, 0.37, 0.88))],
}

var vehicle: Vehicle
## How much rain water sits on the panes (0..1).
var wet := 0.0
## How hard it rains on them (the last rain's once it has stopped).
var rate := 0.75
## Seconds of rain they have had.
var rain_time := 0.0
## How far the side windows' runs lean back (metres per metre down).
var slant := 0.0
## The wipers' cycle: seconds since it began (a stroke, a stroke back, then parked),
## the seconds a stroke takes, the seconds they stood parked before it, how many so far.
var cycle_t := NEVER
var stroke := STROKE
var gap := NEVER
var count := 0
## Standing under a roof (looked up now and then while it rains).
var sheltered := false

var _prev_t := NEVER
var _wait := 0.0
var _shelter_t := 0.0
var _held := false
var _wet_shader := false
var _mats: Array[ShaderMaterial] = []
var _panes: Array[Pane] = []
## Per blade: its pane, arm and blade meshes, pivot, and the blade's ends and the
## glass' normal there at SAMPLES + 1 steps of the sweep (body frame).
var _blades: Array[Dictionary] = []


## A window pane's surface in the vehicle's body frame, by pane space (x across in pane
## heights, towards the vehicle's right or, on a side window, forwards; y up).
class Pane:
	var mesh: MeshInstance3D
	var verts := PackedVector3Array()
	var at := PackedVector2Array()
	var tris := PackedInt32Array()
	var aspect := 1.0
	var inside := Vector3.ZERO

	## The triangle `q` lies in (the nearest one for a point off the pane) and its
	## weights there: [index into tris, u, v].
	func _find(q: Vector2) -> Array:
		var near := Vector2(clampf(q.x, 0.03 * aspect, 0.97 * aspect), clampf(q.y, 0.03, 0.97))
		var best := -1
		var best_in := -INF
		for t in tris.size() / 3:
			var w := _weights(t, near)
			var deep := minf(minf(w.x, w.y), 1.0 - w.x - w.y)
			if deep > best_in:
				best_in = deep
				best = t
		if best < 0:
			return []
		var there := _weights(best, q)
		return [best, there.x, there.y]

	func _weights(t: int, q: Vector2) -> Vector2:
		var a := at[tris[t * 3]]
		var v0 := at[tris[t * 3 + 1]] - a
		var v1 := at[tris[t * 3 + 2]] - a
		var v2 := q - a
		var den := v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-9:
			return Vector2(-INF, -INF)
		return Vector2((v2.x * v1.y - v1.x * v2.y) / den, (v0.x * v2.y - v2.x * v0.y) / den)

	## Pane point `q` on the glass; beyond its edges, on the plane of the glass there.
	func point(q: Vector2) -> Vector3:
		var f := _find(q)
		if f.is_empty():
			return Vector3.ZERO
		var t: int = f[0]
		var a := verts[tris[t * 3]]
		return a + (verts[tris[t * 3 + 1]] - a) * float(f[1]) + (verts[tris[t * 3 + 2]] - a) * float(f[2])

	## The glass' outward normal at `q`.
	func normal(q: Vector2) -> Vector3:
		var f := _find(q)
		if f.is_empty():
			return Vector3.UP
		var t: int = f[0]
		var a := verts[tris[t * 3]]
		var n := (verts[tris[t * 3 + 1]] - a).cross(verts[tris[t * 3 + 2]] - a).normalized()
		return -n if n.dot(a - inside) < 0.0 else n

	## Where the ray from `from` along `dir` meets the pane, in pane space (INF: misses).
	func hit(from: Vector3, dir: Vector3) -> Vector2:
		for t in tris.size() / 3:
			var a := verts[tris[t * 3]]
			var e1 := verts[tris[t * 3 + 1]] - a
			var e2 := verts[tris[t * 3 + 2]] - a
			var h := dir.cross(e2)
			var det := e1.dot(h)
			if absf(det) < 1e-9:
				continue
			var s := from - a
			var u := s.dot(h) / det
			var k := s.cross(e1)
			var v := dir.dot(k) / det
			if u < 0.0 or v < 0.0 or u + v > 1.0 or e2.dot(k) / det <= 0.0:
				continue
			var pa := at[tris[t * 3]]
			return pa + (at[tris[t * 3 + 1]] - pa) * u + (at[tris[t * 3 + 2]] - pa) * v
		return Vector2(INF, INF)


## The vehicle's wipers (null when it has none; `create`: made on the first call).
static func of(v: Vehicle, create := false) -> VehicleWipers:
	var w := v.get_node_or_null(^"Wipers") as VehicleWipers
	if w == null and create:
		w = VehicleWipers.new()
		w.name = "Wipers"
		w.vehicle = v
		v.add_child(w)
		# Once the vehicle has built itself: its panes dressed, its model in place.
		w._setup.call_deferred()
	return w


## Whether a blade laid out by `layout` (see LAYOUT) comes by pane point `q` (x in pane
## heights) of a pane `aspect` wide for its height: the arcs the glass shader clears.
static func sweeps(q: Vector2, aspect: float, layout: Dictionary) -> bool:
	var sweep: Vector2 = layout["sweep"]
	for w: Vector4 in layout["blades"]:
		var d := (q - Vector2(w.x * aspect, w.y)).rotated(-sweep.x)
		var share := atan2(d.y, d.x) * signf(sweep.y) / absf(sweep.y)
		if share > 0.0 and share < 1.0 and d.length() > w.z and d.length() < w.w:
			return true
	return false


## How far along its turn a blade is (0 parked .. 1 right over) `t` seconds into a
## cycle of strokes `stroke_s` long: eased at both ends, as the glass shader takes it.
static func share_at(t: float, stroke_s: float) -> float:
	if t >= 2.0 * stroke_s:
		return 0.0
	var u := t / stroke_s if t < stroke_s else 2.0 - t / stroke_s
	return 0.5 - 0.5 * cos(PI * u)


func _setup() -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	for key: String in vehicle._glass_mats:
		_mats.append(vehicle._glass_mats[key])
	if _warm == null:
		_warm = ShaderMaterial.new()
		_warm.shader = WET
	var model := vehicle.get_node_or_null(^"Model")
	var layouts: Dictionary = LAYOUTS.get(vehicle.kind, LAYOUT)
	var baked: Array = BAKED.get(String(vehicle.info.get("model", "")), [])
	if not baked.is_empty() and model and model.get_child_count() > 0 and not layouts.is_empty():
		ModelStrip.strip_parts(model.get_child(0) as Node3D, baked[0], baked[1])
	# A point inside the cab: between the front seats, at the height of the driver's chin.
	var cab := vehicle._eye_rig.position * Vector3(0, 1, 1) - Vector3(0, 0.12, 0)
	for mi: MeshInstance3D in vehicle.find_children("*", "MeshInstance3D", true, false):
		for si in mi.get_surface_override_material_count():
			var sm := mi.get_surface_override_material(si) as ShaderMaterial
			if sm and sm in _mats:
				_dress(mi, si, cab, layouts)
				break
	_pose(0.0)
	set_process(true)


## Reads pane `mi` (its glass surface `si`) and tells the shader about it: the cab's
## side of it, its size and how the rain meets it; builds a windscreen's blades.
func _dress(mi: MeshInstance3D, si: int, cab: Vector3, layouts: Dictionary) -> void:
	var to_body := vehicle.global_transform.affine_inverse() * mi.global_transform
	mi.set_instance_shader_parameter("cab_at", Vector4(0, 0, 0, 1) + _v4(to_body.affine_inverse() * cab))
	var lo: Variant = mi.get_instance_shader_parameter("pane_min")
	var hi: Variant = mi.get_instance_shader_parameter("pane_max")
	var arrays := mi.mesh.surface_get_arrays(si)
	if not (lo is Vector2 and hi is Vector2 and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array):
		return
	var pane := Pane.new()
	pane.mesh = mi
	pane.inside = cab
	pane.aspect = float(mi.get_instance_shader_parameter("aspect"))
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		pane.verts.append(to_body * v)
	for uv in uvs:
		pane.at.append((uv - (lo as Vector2)) / ((hi as Vector2) - (lo as Vector2)) * Vector2(pane.aspect, 1.0))
	if arrays[Mesh.ARRAY_INDEX] != null:
		pane.tris = arrays[Mesh.ARRAY_INDEX]
	else:
		for i in pane.verts.size():
			pane.tris.append(i)
	_panes.append(pane)
	var mid := Vector2(pane.aspect * 0.5, 0.5)
	var height := pane.point(mid + Vector2(0, 0.4)).distance_to(pane.point(mid - Vector2(0, 0.4))) / 0.8
	var out := pane.normal(mid)
	var side := absf(out.x) > absf(out.z)
	var layout: Dictionary = {}
	for key: String in layouts:
		if key in String(mi.name):
			layout = layouts[key]
	mi.set_instance_shader_parameter("rain_pane", Vector4(height, CATCH.z if side else (CATCH.x if out.z > 0.0 else CATCH.y),
			1.0 if side else 0.0, 0.0 if layout.is_empty() else 1.0))
	if layout.is_empty():
		return
	var blades: Array = layout["blades"]
	mi.set_instance_shader_parameter("wiper_a", blades[0])
	mi.set_instance_shader_parameter("wiper_b", blades[1] if blades.size() > 1 else Vector4.ZERO)
	mi.set_instance_shader_parameter("wiper_sweep", layout["sweep"])
	for w: Vector4 in blades:
		_build_blade(pane, w, layout["sweep"])


static func _v4(v: Vector3) -> Vector4:
	return Vector4(v.x, v.y, v.z, 0.0)


## One wiper: a pivot cap, a sprung arm and the blade it carries, in satin black.
func _build_blade(pane: Pane, w: Vector4, sweep: Vector2) -> void:
	var pivot_q := Vector2(w.x * pane.aspect, w.y)
	var inner := PackedVector3Array()
	var outer := PackedVector3Array()
	var up := PackedVector3Array()
	for i in SAMPLES + 1:
		var dir := Vector2.from_angle(sweep.x + sweep.y * float(i) / SAMPLES)
		inner.append(pane.point(pivot_q + dir * w.z))
		outer.append(pane.point(pivot_q + dir * w.w))
		up.append(pane.normal(pivot_q + dir * (w.z + w.w) * 0.5))
	var mat := _material()
	var arm := _box(mat)
	arm.name = "WiperArm"
	var blade := _box(mat)
	blade.name = "WiperBlade"
	var cap := MeshInstance3D.new()
	cap.name = "WiperPivot"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.011
	cyl.bottom_radius = 0.014
	cyl.height = 0.03
	cyl.radial_segments = 10
	cyl.rings = 1
	cyl.material = mat
	cap.mesh = cyl
	cap.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(cap)
	var pn := pane.normal(pivot_q)
	var pivot := pane.point(pivot_q) + pn * 0.012
	cap.transform = Transform3D(Basis(Quaternion(Vector3.UP, pn)), pivot)
	_blades.append({"pane": pane, "arm": arm, "blade": blade, "pivot": pivot + pn * 0.012, "inner": inner, "outer": outer, "up": up})


func _box(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = mat
	mi.mesh = box
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	return mi


static var _mat: StandardMaterial3D
## Holds the wet glass shader from the first vehicle on: compiled while the world is
## built, not when the first drop falls.
static var _warm: ShaderMaterial


static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.028, 0.028, 0.03)
		_mat.roughness = 0.42
		_mat.metallic = 0.0
	return _mat


## Stands the blades `share` of the way along their turn (0 parked .. 1 right over).
func _pose(share: float) -> void:
	var f := clampf(share, 0.0, 1.0) * SAMPLES
	var i := mini(int(f), SAMPLES - 1)
	var k := f - i
	for b: Dictionary in _blades:
		var p0 := (b["inner"][i] as Vector3).lerp(b["inner"][i + 1], k)
		var p1 := (b["outer"][i] as Vector3).lerp(b["outer"][i + 1], k)
		var n := (b["up"][i] as Vector3).lerp(b["up"][i + 1], k).normalized()
		# The rubber stands on the glass; the arm reaches its middle from the pivot.
		(b["blade"] as Node3D).transform = _span(p0 + n * 0.009, p1 + n * 0.009, n, 0.016, 0.011)
		(b["arm"] as Node3D).transform = _span(b["pivot"], (p0 + p1) * 0.5 + n * 0.022, n, 0.007, 0.017)


## A unit box stretched from `a` to `b`, `thick` along `up` and `wide` across.
static func _span(a: Vector3, b: Vector3, up: Vector3, thick: float, wide: float) -> Transform3D:
	var x := b - a
	var along := x.normalized()
	var y := (up - along * up.dot(along)).normalized()
	return Transform3D(Basis(x, y * thick, along.cross(y) * wide), (a + b) * 0.5)


## Whether the wipers should be sweeping: rain on the screen and somebody at the wheel.
func wanted() -> bool:
	return not _blades.is_empty() and vehicle.driver != null and not sheltered and Weather.rain_fall > 0.05 and wet > 0.1


## Whether the blades are in the middle of a sweep.
func sweeping() -> bool:
	return cycle_t < 2.0 * stroke


func has_blades() -> bool:
	return not _blades.is_empty()


## Whether the blades' arcs clear the glass where the driver looks through it at the
## road, `ahead` metres in front of him.
func clears_view(ahead := 15.0) -> bool:
	var eye := vehicle._eye_rig.position
	var sight := Vector3(0.0, -eye.y, ahead).normalized()
	for pane in _panes:
		var layout: Dictionary = {}
		var layouts: Dictionary = LAYOUTS.get(vehicle.kind, LAYOUT)
		for key: String in layouts:
			if key in String(pane.mesh.name):
				layout = layouts[key]
		if layout.is_empty():
			continue
		var q := pane.hit(eye, sight)
		if q.x != INF and sweeps(q, pane.aspect, layout):
			return true
	return false


## Debug and screenshots: stands the blades `share` along the stroke up of a sweep and
## keeps them there (negative: lets them go again).
func hold(share: float) -> void:
	_held = share >= 0.0
	if _held:
		if cycle_t >= 2.0 * stroke:
			gap = cycle_t - 2.0 * stroke
			count += 1
		cycle_t = acos(1.0 - 2.0 * clampf(share, 0.0, 1.0)) / PI * stroke
		_prev_t = cycle_t
		_pose(share_at(cycle_t, stroke))


func _physics_process(delta: float) -> void:
	if _blades.is_empty() or _held:
		return
	var was := sweeping()
	_prev_t = cycle_t
	if was:
		cycle_t += delta
		if not sweeping():
			_wait = _pause()
	else:
		if cycle_t < NEVER:
			cycle_t = minf(cycle_t + delta, NEVER)
		if wanted():
			_wait -= delta
			if _wait <= 0.0:
				_start_sweep()
	if not (was or sweeping()):
		return
	_pose(share_at(cycle_t, stroke))
	# Each stroke has its own soft sweep of rubber over wet glass.
	if sweeping() and (not was or (_prev_t < stroke and cycle_t >= stroke)):
		var b: Dictionary = _blades[0]
		Audio.play("wiper", vehicle.to_global(b["pivot"]), -15.0, 0.05, &"Effects", 1.6, STROKE / stroke)


func _start_sweep() -> void:
	gap = cycle_t - 2.0 * stroke if cycle_t < NEVER else NEVER
	stroke = STROKE_FAST if Weather.rain_fall >= STORM_FROM else STROKE
	cycle_t = 0.0
	count += 1


## Seconds parked before the next sweep, by how hard it rains.
func _pause() -> float:
	if Weather.rain_fall >= STORM_FROM:
		return 0.0
	return PAUSE if Weather.rain_fall >= 0.5 else PAUSE_LIGHT


func _process(delta: float) -> void:
	if _mats.is_empty():
		return
	var falling := Weather.rain_fall
	if falling <= 0.0 and wet <= 0.0:
		# Dry weather, dry glass: nothing to do.
		if _wet_shader:
			_use_wet(false)
		return
	if falling > 0.0:
		_shelter_t -= delta
		if _shelter_t <= 0.0:
			_shelter_t = 1.0
			sheltered = _under_roof()
		if sheltered:
			falling = 0.0
	if falling > wet:
		wet = move_toward(wet, falling, delta / WET_UP)
	else:
		# The airstream dries a moving vehicle sooner.
		wet = move_toward(wet, falling, delta / DRY_OFF * (1.0 + vehicle.linear_velocity.length() / 8.0))
	if falling > 0.05:
		rate = falling
	rain_time += delta * falling
	slant = lerpf(slant, clampf(vehicle.forward_speed() / 7.0, -3.0, 3.0), clampf(delta * 1.5, 0.0, 1.0))
	_use_wet(wet > 0.001)
	if not _wet_shader:
		return
	# The blades are drawn between physics ticks: so is the glass they clear.
	var t := lerpf(_prev_t, cycle_t, Engine.get_physics_interpolation_fraction()) if cycle_t >= _prev_t else cycle_t
	for m in _mats:
		m.set_shader_parameter("rain_wet", wet)
		m.set_shader_parameter("rain_rate", rate)
		m.set_shader_parameter("rain_time", rain_time)
		m.set_shader_parameter("rain_slant", slant)
		m.set_shader_parameter("wiper_t", t)
		m.set_shader_parameter("wiper_stroke", stroke)
		m.set_shader_parameter("wiper_gap", gap)
		m.set_shader_parameter("wiper_count", float(count % 64))


## Gives the panes the shader with the rain on it, or the dry one back.
func _use_wet(on: bool) -> void:
	if on == _wet_shader:
		return
	_wet_shader = on
	for m in _mats:
		m.shader = WET if on else DRY


## Whether something solid stands over the roof (a shed, the showroom).
func _under_roof() -> bool:
	var from := vehicle.waypoint_roof().global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 40, 0), 1)
	q.exclude = [vehicle.get_rid()]
	return not vehicle.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
