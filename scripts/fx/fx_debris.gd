class_name FxDebris
extends Node3D
## Small solid bits thrown by work: bark chips and splinters off an axe blow, rock
## fragments off the pick, soil clods off the hoe, leaves, stalks and seeds. They are real
## little lit meshes (shaders/debris.gdshader) that tumble, bounce on the ground (the
## terrain, or a given floor such as a bed's soil), settle and sink away. Every look is
## one MultiMesh per shape, so a burst is a few draw calls however many bits it throws;
## the bits are moved here, a few dozen at a time, which is what lets them land where
## particles would fall through the ground. Fx owns the one instance in the world.

## Most bits of one look alive at once (a burst past it throws fewer).
const CAPACITY := 256
const GRAVITY := 9.8
const TEX_DIR := "res://art/textures/"


## How one kind of bit looks and moves.
class Look:
	var mmis: Array[MultiMeshInstance3D] = []
	var bits: Array = []
	## Air drag (1/s): high for leaves and stalks, which drift down.
	var drag := 0.0
	## Sideways sway (m/s²) of light bits as they fall.
	var flutter := 0.0
	## Share of the speed kept by a bounce.
	var bounce := 0.3
	## Share of the sliding speed kept by a bounce.
	var friction := 0.5
	## Settles lying flat (leaves, chips, stalks) rather than as it landed.
	var flat := false


## One bit in flight or lying on the ground.
class Bit:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var rot := Quaternion.IDENTITY
	## Rotation axis times speed (rad/s), in world space.
	var spin := Vector3.ZERO
	## Size along the mesh's axes (m).
	var size := Vector3.ONE
	var age := 0.0
	var life := 2.0
	## Seconds it takes to sink away at the end of its life.
	var fade := 0.5
	var floor_y := 0.0
	var has_floor := false
	var variant := 0
	var resting := false
	var bounces := 0
	var phase := 0.0
	var color := Color(0.5, 0.5, 0.5)
	var custom := Color()


static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var _looks: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Moved in _process: nothing to interpolate.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.randomize()
	set_process(false)


## Throws bits. `spec` keys (all but "look" optional):
##   look (StringName): wood_oak, wood_pine, splinter, rock, clod, crumb, leaf, blade, seed
##   count, at, box (half extents of the spawn box), dir, cone (degrees around dir),
##   speed (Vector2 min..max m/s), size (Vector2 min..max m), shape (Vector3 per-axis
##   factors), shape_jitter (0..1), colors (Array of tints, 0.5 grey = texture as-is),
##   life (Vector2 seconds on the ground and in the air), spin (rad/s), floor (y of the
##   ground under them, else the terrain), vel (Vector3 added to every bit)
func throw(spec: Dictionary) -> void:
	var look_id: StringName = spec["look"]
	var look := _look(look_id)
	var count := mini(int(spec.get("count", 6)), CAPACITY - look.bits.size())
	if count <= 0:
		return
	var at: Vector3 = spec.get("at", Vector3.ZERO)
	var box: Vector3 = spec.get("box", Vector3.ZERO)
	var dir: Vector3 = (spec.get("dir", Vector3.UP) as Vector3).normalized()
	var cone := deg_to_rad(float(spec.get("cone", 30.0)))
	var speed: Vector2 = spec.get("speed", Vector2(1.0, 2.0))
	var size: Vector2 = spec.get("size", Vector2(0.01, 0.03))
	var shape: Vector3 = spec.get("shape", Vector3.ONE)
	var jitter := float(spec.get("shape_jitter", 0.3))
	var colors: Array = spec.get("colors", [Color(0.5, 0.5, 0.5)])
	var life: Vector2 = spec.get("life", Vector2(2.0, 3.0))
	var spin := float(spec.get("spin", 12.0))
	var extra: Vector3 = spec.get("vel", Vector3.ZERO)
	var has_floor := spec.has("floor")
	var floor_y := float(spec.get("floor", 0.0))
	var collide := bool(spec.get("collide", false)) and not has_floor
	var space := get_world_3d().direct_space_state if collide else null
	var basis := _basis_toward(dir)
	for i in count:
		var b := Bit.new()
		b.pos = at + Vector3(_rng.randf_range(-box.x, box.x), _rng.randf_range(-box.y, box.y), _rng.randf_range(-box.z, box.z))
		var ct := lerpf(1.0, cos(cone), _rng.randf())
		var st := sqrt(maxf(1.0 - ct * ct, 0.0))
		var ph := _rng.randf() * TAU
		b.vel = basis * Vector3(cos(ph) * st, ct, sin(ph) * st) * _rng.randf_range(speed.x, speed.y) + extra
		b.rot = Quaternion(_random_axis(), _rng.randf() * TAU)
		b.spin = _random_axis() * _rng.randf_range(0.4, 1.0) * spin
		var s := _rng.randf_range(size.x, size.y)
		b.size = Vector3(shape.x * _rng.randf_range(1.0 - jitter, 1.0 + jitter),
				shape.y * _rng.randf_range(1.0 - jitter, 1.0 + jitter),
				shape.z * _rng.randf_range(1.0 - jitter, 1.0 + jitter)) * s
		b.life = _rng.randf_range(life.x, life.y)
		b.fade = minf(0.6, b.life * 0.3)
		b.has_floor = has_floor
		b.floor_y = floor_y
		if space:
			_find_floor(space, b)
		b.variant = _rng.randi() % look.mmis.size()
		b.phase = _rng.randf() * TAU
		var c: Color = colors[_rng.randi() % colors.size()]
		var v := _rng.randf_range(0.88, 1.12)
		b.color = Color(c.r * v, c.g * v, c.b * v, 1.0)
		b.custom = Color(_rng.randf(), _rng.randf(), s, _rng.randf())
		look.bits.append(b)
	set_process(true)


## Where a bit thrown off a boulder or a trunk comes down: whatever solid thing is under
## the spot its throw carries it to (the boulder's top, a stump, the ground). One ray
## per bit, when it is thrown.
func _find_floor(space: PhysicsDirectSpaceState3D, b: Bit) -> void:
	var ground := TerrainData.height(b.pos.x, b.pos.z)
	var h := maxf(b.pos.y - ground, 0.0)
	# Time to fall back to the ground's height, drag left out.
	var t := (b.vel.y + sqrt(b.vel.y * b.vel.y + 2.0 * GRAVITY * h)) / GRAVITY
	var land := b.pos + Vector3(b.vel.x, 0.0, b.vel.z) * t
	var q := PhysicsRayQueryParameters3D.create(Vector3(land.x, b.pos.y + 0.6, land.z), Vector3(land.x, ground - 0.2, land.z), 1 | 4)
	if Game.player is CollisionObject3D:
		q.exclude = [(Game.player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).y > TerrainData.height(land.x, land.z) + 0.03:
		b.floor_y = (hit["position"] as Vector3).y
		b.has_floor = true


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	var busy := false
	for look: Look in _looks.values():
		if look.bits.is_empty():
			continue
		busy = true
		_step(look, dt)
	if not busy:
		set_process(false)


func _step(look: Look, dt: float) -> void:
	var bits := look.bits
	var i := bits.size() - 1
	while i >= 0:
		var b: Bit = bits[i]
		b.age += dt
		if b.age >= b.life:
			bits[i] = bits[bits.size() - 1]
			bits.pop_back()
			i -= 1
			continue
		if not b.resting:
			_move(look, b, dt)
		i -= 1
	var counts: Array[int] = []
	counts.resize(look.mmis.size())
	counts.fill(0)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for b: Bit in bits:
		var mm := look.mmis[b.variant].multimesh
		var k := counts[b.variant]
		counts[b.variant] = k + 1
		# Sinks into the ground and shrinks away at the end.
		var left := clampf((b.life - b.age) / b.fade, 0.0, 1.0)
		left = left * left * (3.0 - 2.0 * left)
		var s := b.size * maxf(left, 0.001)
		var at := b.pos - Vector3(0.0, (1.0 - left) * b.size.y * 0.5, 0.0)
		mm.set_instance_transform(k, Transform3D(Basis(b.rot) * Basis.from_scale(s), at))
		mm.set_instance_color(k, b.color)
		mm.set_instance_custom_data(k, b.custom)
		lo = lo.min(at)
		hi = hi.max(at)
	var box := AABB(lo - Vector3.ONE * 0.2, hi - lo + Vector3.ONE * 0.4)
	for v in look.mmis.size():
		var mmi := look.mmis[v]
		mmi.multimesh.visible_instance_count = counts[v]
		mmi.visible = counts[v] > 0
		if counts[v] > 0:
			mmi.custom_aabb = box


func _move(look: Look, b: Bit, dt: float) -> void:
	b.vel.y -= GRAVITY * dt
	if look.drag > 0.0:
		b.vel /= 1.0 + look.drag * dt
	if look.flutter > 0.0:
		b.vel.x += sin(b.age * 5.3 + b.phase) * look.flutter * dt
		b.vel.z += cos(b.age * 4.1 + b.phase * 1.7) * look.flutter * dt
	b.pos += b.vel * dt
	if b.spin != Vector3.ZERO:
		b.rot = (Quaternion(b.spin.normalized(), b.spin.length() * dt) * b.rot).normalized()
	var ground := b.floor_y if b.has_floor else TerrainData.height(b.pos.x, b.pos.z)
	# Resting on its thinnest side.
	var lift := minf(b.size.x, minf(b.size.y, b.size.z)) * 0.5
	if b.pos.y >= ground + lift:
		return
	b.pos.y = ground + lift
	if b.vel.y < -0.8 and b.bounces < 2 and look.bounce > 0.0:
		b.vel.y = -b.vel.y * look.bounce * _rng.randf_range(0.5, 1.0)
		b.vel.x *= look.friction
		b.vel.z *= look.friction
		b.spin = _random_axis() * b.spin.length() * 0.6
		b.bounces += 1
		return
	b.resting = true
	b.vel = Vector3.ZERO
	b.spin = Vector3.ZERO
	if look.flat:
		# Lies down on its broad side, turned any way.
		b.rot = Quaternion(Vector3.UP, _rng.randf() * TAU) * Quaternion(Vector3.RIGHT, _rng.randf_range(-0.15, 0.15))
		b.pos.y = ground + b.size.y * 0.5 + 0.002


func _look(id: StringName) -> Look:
	if _looks.has(id):
		return _looks[id]
	var look := Look.new()
	var meshes: Array = FxDebris.meshes_for(id)
	var mat := FxDebris.material_for(id)
	for m: Mesh in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = m
		mm.instance_count = CAPACITY
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Small clutter: kept out of the rain height map (layer 2) and out of GI.
		mmi.layers = 2
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mmi.visible = false
		add_child(mmi)
		look.mmis.append(mmi)
	match id:
		&"leaf":
			look.drag = 7.0
			look.flutter = 6.0
			look.bounce = 0.0
			look.flat = true
		&"blade":
			look.drag = 3.5
			look.flutter = 3.0
			look.bounce = 0.0
			look.flat = true
		&"seed":
			look.bounce = 0.25
			look.friction = 0.3
		&"splinter":
			look.drag = 0.6
			look.bounce = 0.25
			look.flat = true
		&"wood_oak", &"wood_pine":
			look.drag = 0.5
			look.bounce = 0.3
			look.flat = true
		&"clod", &"crumb":
			look.bounce = 0.15
			look.friction = 0.3
		_:
			look.bounce = 0.35
			look.friction = 0.55
	_looks[id] = look
	return look


static func _basis_toward(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := side.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


func _random_axis() -> Vector3:
	var z := _rng.randf_range(-1.0, 1.0)
	var a := _rng.randf() * TAU
	var r := sqrt(1.0 - z * z)
	return Vector3(cos(a) * r, sin(a) * r, z)


# --- Shapes --------------------------------------------------------------------------
# All about one unit across (scaled per bit), centred on the origin.

## The shapes of a look (a few for the ones seen by the dozen, so no two match).
static func meshes_for(id: StringName) -> Array:
	if _meshes.has(id):
		return _meshes[id]
	var list: Array = []
	match id:
		&"rock":
			for s in 3:
				list.append(_rock_mesh(s + 1, true))
		&"clod":
			for s in 2:
				list.append(_rock_mesh(s + 11, false))
		&"crumb":
			list.append(_rock_mesh(21, true))
		&"wood_oak", &"wood_pine":
			for s in 2:
				list.append(_chip_mesh(s + 31))
		&"splinter":
			list.append(_splinter_mesh(41))
			list.append(_splinter_mesh(42))
		&"leaf":
			list.append(_leaf_mesh())
		&"blade":
			list.append(_blade_mesh())
		_:
			list.append(_seed_mesh())
	_meshes[id] = list
	return list


## An icosahedron with its corners pushed in and out: a faceted rock chip (`flat` faces)
## or, subdivided and smooth, a lumpy soil clod.
static func _rock_mesh(seed_value: int, faceted: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array[Vector3i] = [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10),
			Vector3i(0, 10, 11), Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6),
			Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8),
			Vector3i(3, 8, 9), Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7),
			Vector3i(9, 8, 1)]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	if not faceted:
		# One subdivision for a rounder lump.
		var mid := {}
		var out: Array[Vector3i] = []
		for f in faces:
			var a := _midpoint(verts, mid, f.x, f.y)
			var b := _midpoint(verts, mid, f.y, f.z)
			var c := _midpoint(verts, mid, f.z, f.x)
			out.append_array([Vector3i(f.x, a, c), Vector3i(f.y, b, a), Vector3i(f.z, c, b), Vector3i(a, b, c)])
		faces = out
	for i in verts.size():
		var k := rng.randf_range(0.62, 1.0) if faceted else rng.randf_range(0.8, 1.08)
		verts[i] = verts[i] * k * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	if faceted:
		st.set_smooth_group(-1)
	for f in faces:
		# Godot's front faces wind clockwise.
		st.add_vertex(verts[f.x])
		st.add_vertex(verts[f.z])
		st.add_vertex(verts[f.y])
	if not faceted:
		st.index()
	st.generate_normals()
	return st.commit()


static func _midpoint(verts: Array[Vector3], cache: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if cache.has(key):
		return cache[key]
	verts.append((verts[a] + verts[b]).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1


## A chip of a trunk: a curved slab, bark on its outer face (vertex alpha 1) and fresh
## wood under it and round its torn edges (alpha 0). Long along X, the grain's way.
static func _chip_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 104729
	var nx := 4
	var nz := 3
	var thick := 0.22
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for iz in nz + 1:
		for ix in nx + 1:
			var u := float(ix) / nx - 0.5
			var w := float(iz) / nz - 0.5
			# A ragged outline, narrower at the torn ends.
			var edge_x := absf(u) > 0.49
			var edge_z := absf(w) > 0.49
			var x := u + (rng.randf_range(-0.08, 0.08) if edge_z else 0.0)
			var z := w * 0.55 * (1.0 - absf(u) * 0.5) + (rng.randf_range(-0.06, 0.06) if edge_x else 0.0)
			var y := -z * z * 0.9 + rng.randf_range(-0.02, 0.02)
			top.append(Vector3(x, y + thick * 0.5, z))
			bottom.append(Vector3(x, y - thick * 0.5 + rng.randf_range(-0.03, 0.03), z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			_quad(st, top[a], top[b], top[d], top[c], Vector3.UP, 1.0)
			_quad(st, bottom[a], bottom[c], bottom[d], bottom[b], Vector3.DOWN, 0.0)
	# Torn edges all round.
	var ring: Array[int] = []
	for ix in nx + 1:
		ring.append(ix)
	for iz in range(1, nz + 1):
		ring.append(iz * (nx + 1) + nx)
	for ix in range(nx - 1, -1, -1):
		ring.append(nz * (nx + 1) + ix)
	for iz in range(nz - 1, 0, -1):
		ring.append(iz * (nx + 1))
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		var mid := (top[a] + top[b]) * 0.5
		var out := Vector3(mid.x, 0.0, mid.z).normalized()
		_quad(st, top[a], bottom[a], bottom[b], top[b], out, 0.0)
	st.generate_normals()
	return st.commit()


## A splinter: a long thin sliver, pointed at both ends, slightly twisted.
static func _splinter_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 3571
	var segs := 5
	var rings: Array = []
	for i in segs + 1:
		var u := float(i) / segs
		var x := u - 0.5
		var taper := pow(sin(u * PI), 0.6) if i > 0 and i < segs else 0.0
		var tw := u * 0.8
		var w := 0.09 * taper * rng.randf_range(0.8, 1.2)
		var h := 0.045 * taper * rng.randf_range(0.8, 1.2)
		var r: Array[Vector3] = []
		for k in 4:
			var a := k * TAU / 4.0 + tw
			r.append(Vector3(x, sin(a) * h, cos(a) * w) + Vector3(0, rng.randf_range(-0.01, 0.01), 0))
		rings.append(r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in segs:
		var r0: Array[Vector3] = rings[i]
		var r1: Array[Vector3] = rings[i + 1]
		for k in 4:
			var k1 := (k + 1) % 4
			var mid := (r0[k] + r0[k1] + r1[k] + r1[k1]) * 0.25
			var out := Vector3(0.0, mid.y, mid.z).normalized()
			_quad(st, r0[k], r1[k], r1[k1], r0[k1], out, 0.0)
	st.generate_normals()
	return st.commit()


## A leaf: pointed oval blade folded a little along its midrib and curled at the tip.
## UV.x runs along the midrib from the stalk, UV.y across (-1..1).
static func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(1, 1, 1, 0))
	var n := 7
	var mid: Array[Vector3] = []
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in n + 1:
		var u := float(i) / n
		var w := 0.36 * pow(sin(u * PI), 0.75) * (1.0 - u * 0.25)
		var y := u * u * 0.12
		mid.append(Vector3(u - 0.5, y, 0.0))
		left.append(Vector3(u - 0.5, y + w * 0.25, -w))
		right.append(Vector3(u - 0.5, y + w * 0.25, w))
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		_leaf_tri(st, mid[i], left[i], mid[i + 1], Vector2(u0, 0), Vector2(u0, -1), Vector2(u1, 0))
		_leaf_tri(st, mid[i + 1], left[i], left[i + 1], Vector2(u1, 0), Vector2(u0, -1), Vector2(u1, -1))
		_leaf_tri(st, mid[i], mid[i + 1], right[i], Vector2(u0, 0), Vector2(u1, 0), Vector2(u0, 1))
		_leaf_tri(st, mid[i + 1], right[i + 1], right[i], Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))
	st.generate_normals()
	return st.commit()


static func _leaf_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	# Faces up (+Y); Godot's front faces wind clockwise.
	if (b - a).cross(c - a).y > 0.0:
		st.set_uv(ua)
		st.add_vertex(a)
		st.set_uv(uc)
		st.add_vertex(c)
		st.set_uv(ub)
		st.add_vertex(b)
	else:
		st.set_uv(ua)
		st.add_vertex(a)
		st.set_uv(ub)
		st.add_vertex(b)
		st.set_uv(uc)
		st.add_vertex(c)


## A stalk or blade of grass: a thin curved strip (UV as the leaf's).
static func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(1, 1, 1, 0))
	var n := 4
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var w0 := 0.05 * (1.0 - u0 * 0.7)
		var w1 := 0.05 * (1.0 - u1 * 0.7)
		var a := Vector3(u0 - 0.5, u0 * u0 * 0.15, -w0)
		var b := Vector3(u0 - 0.5, u0 * u0 * 0.15, w0)
		var c := Vector3(u1 - 0.5, u1 * u1 * 0.15, -w1)
		var d := Vector3(u1 - 0.5, u1 * u1 * 0.15, w1)
		_leaf_tri(st, a, c, b, Vector2(u0, -1), Vector2(u1, -1), Vector2(u0, 1))
		_leaf_tri(st, b, c, d, Vector2(u0, 1), Vector2(u1, -1), Vector2(u1, 1))
	st.generate_normals()
	return st.commit()


## A seed, a crumb of sawdust: a small smooth ovoid.
static func _seed_mesh() -> ArrayMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 8
	m.rings = 4
	var arrays := m.get_mesh_arrays()
	var cols := PackedColorArray()
	cols.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## A quad (a, b, c, d around it) facing `out`, its vertex alpha `mask`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, mask: float) -> void:
	st.set_color(Color(1, 1, 1, mask))
	for tri: Array in [[a, b, c], [a, c, d]]:
		var p: Vector3 = tri[0]
		var q: Vector3 = tri[1]
		var r: Vector3 = tri[2]
		# Godot's front faces wind clockwise seen from outside.
		if (q - p).cross(r - p).dot(out) > 0.0:
			st.add_vertex(p)
			st.add_vertex(r)
			st.add_vertex(q)
		else:
			st.add_vertex(p)
			st.add_vertex(q)
			st.add_vertex(r)


# --- Materials -----------------------------------------------------------------------

static func material_for(id: StringName) -> ShaderMaterial:
	if _materials.has(id):
		return _materials[id]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/debris.gdshader")
	match id:
		&"rock":
			_photo(m, "rock_face_03", 0, 9.0)
			m.set_shader_parameter("roughness", 0.82)
			m.set_shader_parameter("normal_strength", 1.4)
		&"clod", &"crumb":
			_photo(m, "farm_soil", 0, 5.0)
			m.set_shader_parameter("roughness", 0.95)
			m.set_shader_parameter("normal_strength", 1.6)
		&"wood_oak":
			_photo(m, "bark_brown_02", 1, 2.5)
			m.set_shader_parameter("fresh_color", Color(0.68, 0.56, 0.4))
		&"wood_pine":
			_photo(m, "pine_bark", 1, 2.5)
			m.set_shader_parameter("fresh_color", Color(0.74, 0.62, 0.43))
		&"splinter":
			_photo(m, "bark_brown_02", 1, 2.5)
			m.set_shader_parameter("fresh_color", Color(0.7, 0.58, 0.42))
		&"leaf", &"blade":
			m.set_shader_parameter("look", 2)
			m.set_shader_parameter("translucency", 0.2)
			m.set_shader_parameter("roughness", 0.6)
			m.set_shader_parameter("has_normal", false)
		_:
			m.set_shader_parameter("look", 3)
			m.set_shader_parameter("roughness", 0.55)
			m.set_shader_parameter("has_normal", false)
	_materials[id] = m
	return m


static func _photo(m: ShaderMaterial, tex: String, look: int, uv_scale: float) -> void:
	m.set_shader_parameter("look", look)
	m.set_shader_parameter("albedo_tex", load("%s%s/%s_diff.jpg" % [TEX_DIR, tex, tex]))
	m.set_shader_parameter("normal_tex", load("%s%s/%s_nor.jpg" % [TEX_DIR, tex, tex]))
	m.set_shader_parameter("uv_scale", uv_scale)
