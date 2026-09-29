@tool
class_name CraftModels
extends RefCounted
## Models of the workbench's things and what they are made from (the knife is a scan:
## ToolModels; the campfire a placeable: PlaceableModels), in ItemModels' frame: long
## tools stand along +Y with the hand at the origin, everything else stands on its base
## at the origin. Built from the photo-textured materials (Mats) and two scans
## (GoodsModels "nails_tin", "dough_bowl"; tools/fetch_progression_models.py).
##   bow: a yew longbow, strung, the leather grip at the hand, the string toward +Z
##   fishing_rod: a hand-made ash rod, the cord-wrapped grip in the hand, a wooden
##     centre-pin reel and wire guides under it (toward -Z), the line run to the tip
##   rope: a coil of three-strand hemp rope bound twice, its end hanging loose
##   nails: a rusted tin of nails, a few lying on its lid and beside it
##   worm: a little wooden bait box of dark earth with worms on it
##   dough: a ball of bread dough in a carved wooden bowl
##   sapling: a young tree with its root ball wrapped in burlap and tied with twine

const IDS: Array[StringName] = [&"bow", &"fishing_rod", &"rope", &"nails", &"worm", &"dough", &"sapling"]
## The fishing rod's tip ring (where the line leaves it) and the reel's spool, in item
## space: the fishing cast and reel animations start from them.
const ROD_TIP := Vector3(0, 1.99, -0.007)
const ROD_REEL := Vector3(0, 0.07, -0.05)
## The rod's length from the butt (y = ROD_BUTT) to the tip.
const ROD_BUTT := -0.36
const HEMP := Color(0.74, 0.64, 0.46)
const ASH := Color(0.7, 0.58, 0.4)
const YEW := Color(0.66, 0.43, 0.25)
const LEATHER := Color(0.3, 0.19, 0.12)
const LINE := Color(0.9, 0.88, 0.8)
const WORM := Color(0.66, 0.38, 0.34)
const BURLAP := Color(0.5, 0.4, 0.27)


static func has(id: StringName) -> bool:
	return id in IDS


static func mesh(id: StringName) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var surfaces := []
	match id:
		&"bow":
			_bow(mb)
		&"fishing_rod":
			_rod(mb)
		&"rope":
			_rope(mb)
		&"nails":
			_nails(mb, surfaces)
		&"worm":
			_worm_box(mb)
		&"dough":
			_dough(mb, surfaces)
		&"sapling":
			_sapling(mb)
	MeshMerge.add_mesh(surfaces, mb.build())
	return MeshMerge.build(surfaces)


# --- Bow ---------------------------------------------------------------------------------

static func _bow(mb: MeshBuilder) -> void:
	var half := 0.62
	var bend := 0.12
	var centers: Array[Vector3] = []
	var radii: Array[Vector2] = []
	var colors: Array[Color] = []
	var n := 33
	for i in n:
		var y := lerpf(-half, half, float(i) / (n - 1))
		var u := absf(y) / half
		centers.append(Vector3(0, y, bend * pow(u, 1.8)))
		# Round and thick at the handle, flat limbs thinning to the tips.
		var limb := clampf((absf(y) - 0.07) / (half - 0.07), 0.0, 1.0)
		var grip := 1.0 - smoothstep(0.05, 0.1, absf(y))
		radii.append(Vector2(lerpf(0.019, 0.008, limb) * (1.0 - grip) + 0.016 * grip,
				lerpf(0.013, 0.006, limb) * (1.0 - grip) + 0.02 * grip))
		# Pale sapwood toward the tips, darker heartwood by the handle.
		colors.append(YEW.lightened(0.12 * limb).darkened(0.08 * (1.0 - limb)))
	mb.loft_ellipse(&"wood", centers, radii, 10, YEW, colors, Vector3.BACK)
	# The leather grip, a little proud of the wood.
	var gc: Array[Vector3] = []
	var gr: Array[Vector2] = []
	for i in 7:
		var y := lerpf(-0.075, 0.075, float(i) / 6.0)
		gc.append(Vector3(0, y, bend * pow(absf(y) / half, 1.8)))
		gr.append(Vector2(0.0185, 0.0225))
	mb.loft_ellipse(&"cloth", gc, gr, 12, LEATHER, [], Vector3.BACK)
	for y: float in [-0.075, 0.075]:
		mb.ring(&"cloth", Transform3D(Basis(), Vector3(0, y - 0.004, 0)), 0.021, 0.015, 0.008, 12, LEATHER.darkened(0.3))
	# Horn nocks and the string between them.
	var tip_z := bend
	for s: float in [-1.0, 1.0]:
		var at := Vector3(0, s * half, tip_z)
		mb.cylinder_between(&"wood", at - Vector3(0, s * 0.03, 0), at + Vector3(0, s * 0.02, 0), 0.0075, 0.004, 8, Color(0.86, 0.8, 0.68))
	mb.cylinder_between(&"cloth", Vector3(0, half - 0.012, tip_z + 0.006), Vector3(0, -half + 0.012, tip_z + 0.006), 0.0013, 0.0013, 5, LINE.darkened(0.1), true, false)
	# The serving where the arrow's nock sits.
	mb.cylinder(&"cloth", Transform3D(Basis(), Vector3(0, -0.04, tip_z + 0.006)), 0.0022, 0.0022, 0.08, 6, Color(0.2, 0.18, 0.16))


# --- Fishing rod -------------------------------------------------------------------------

static func _rod(mb: MeshBuilder) -> void:
	var tip := ROD_TIP.y
	var centers: Array[Vector3] = []
	var radii: Array[float] = []
	var n := 24
	for i in n:
		var t := float(i) / (n - 1)
		var y := lerpf(ROD_BUTT, tip, t)
		centers.append(Vector3(0, y, 0))
		radii.append(lerpf(0.0135, 0.0028, pow(t, 0.8)))
	mb.loft(&"wood", centers, radii, 10, ASH)
	# The butt cap, and the grip wrapped in cord, turn by turn.
	mb.cylinder(&"wood", Transform3D(Basis(), Vector3(0, ROD_BUTT - 0.01, 0)), 0.016, 0.016, 0.02, 12, ASH.darkened(0.35))
	var wraps := 34
	for i in wraps:
		var y := ROD_BUTT + 0.02 + i * 0.0105
		mb.ring(&"cloth", Transform3D(Basis(Vector3.FORWARD, 0.06), Vector3(0, y, 0)), 0.0172, 0.0125, 0.0092, 12,
				HEMP.darkened(0.04 * float(i % 3)))
	# The reel seat: two brass bands round the rod, a wooden centre-pin reel under it.
	for y: float in [0.02, 0.12]:
		mb.ring(&"metal", Transform3D(Basis(), Vector3(0, y, 0)), 0.0155, 0.0115, 0.012, 12, Color(0.62, 0.5, 0.28))
	var r := ROD_REEL
	mb.box_at(&"metal", Vector3(0, r.y, -0.0145), Vector3(0.012, 0.11, 0.004), Color(0.55, 0.45, 0.26))
	mb.box_at(&"metal", Vector3(0, r.y, -0.024), Vector3(0.01, 0.02, 0.018), Color(0.55, 0.45, 0.26))
	var axle := Basis(Vector3.FORWARD, PI * 0.5)
	for sx: float in [-0.013, 0.013]:
		mb.cylinder(&"wood", Transform3D(axle, r + Vector3(sx + (0.003 if sx > 0 else 0.0), 0, 0)), 0.033, 0.033, 0.003 if sx > 0 else 0.004, 18, ASH.darkened(0.2))
	mb.cylinder(&"wood", Transform3D(axle, r + Vector3(0.013, 0, 0)), 0.012, 0.012, 0.026, 12, ASH.darkened(0.1))
	mb.cylinder(&"cloth", Transform3D(axle, r + Vector3(0.012, 0, 0)), 0.024, 0.024, 0.024, 16, LINE.darkened(0.05))
	# A knob on the reel's face to wind it by.
	mb.cylinder(&"wood", Transform3D(axle, r + Vector3(-0.017, 0.02, 0)), 0.004, 0.004, 0.018, 8, ASH.darkened(0.4))
	# Wire guides under the rod, whipped on with thread, smaller toward the tip.
	var guides: Array[float] = [0.42, 0.76, 1.06, 1.34, 1.58, 1.8]
	var line_pts: Array[Vector3] = [r + Vector3(0, 0.024, -0.0)]
	for i in guides.size():
		var y := guides[i]
		var rod_r := lerpf(0.0135, 0.0028, pow((y - ROD_BUTT) / (tip - ROD_BUTT), 0.8))
		var gr := lerpf(0.0075, 0.0035, float(i) / (guides.size() - 1))
		var gc := Vector3(0, y, -(rod_r + gr + 0.003))
		mb.ring(&"steel", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), gc + Vector3(0, 0, 0.0)), gr, gr - 0.0012, 0.0015, 10, Color(0.55, 0.56, 0.58))
		mb.cylinder_between(&"steel", Vector3(0, y - 0.012, -rod_r), gc + Vector3(0, 0, gr * 0.6), 0.0008, 0.0008, 4, Color(0.55, 0.56, 0.58), true, false)
		mb.ring(&"cloth", Transform3D(Basis(), Vector3(0, y - 0.018, 0)), rod_r + 0.0012, rod_r, 0.012, 10, Color(0.45, 0.12, 0.1))
		line_pts.append(gc)
	# The tip ring.
	mb.ring(&"steel", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), ROD_TIP), 0.0035, 0.0023, 0.0015, 10, Color(0.55, 0.56, 0.58))
	line_pts.append(ROD_TIP)
	for i in line_pts.size() - 1:
		mb.cylinder_between(&"cloth", line_pts[i], line_pts[i + 1], 0.00065, 0.00065, 4, LINE, true, false)


# --- Rope --------------------------------------------------------------------------------

## Three strands laid round the coil's path, ~5 turns stacked loosely.
static func _rope(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var turns := 5.0
	var ring_r := 0.1
	var strand := 0.0052
	var path: Array[Vector3] = []
	var steps := 330
	for i in steps + 1:
		var t := float(i) / steps
		var a := t * turns * TAU
		var rr := ring_r + 0.006 * sin(a * 1.7 + 0.4) + 0.004 * sin(a * 0.45)
		path.append(Vector3(cos(a) * rr, 0.012 + t * 0.042 + 0.004 * sin(a * 2.3), sin(a) * rr))
	# The loose end falls over the coil's side.
	var last := path[path.size() - 1]
	var out_dir := Vector3(last.x, 0.0, last.z).normalized()
	for i in range(1, 12):
		var u := float(i) / 11.0
		path.append(last + out_dir * (0.05 * u) + Vector3(0, -0.045 * u * u, 0) + out_dir.cross(Vector3.UP) * (0.03 * u))
	_laid_rope(mb, path, strand, HEMP, 0.036)
	# Two bindings round the bundle, opposite each other.
	for a: float in [0.3, PI + 0.3]:
		var c := Vector3(cos(a) * ring_r, 0.033, sin(a) * ring_r)
		var tangent := Vector3(-sin(a), 0, cos(a))
		for w in 3:
			mb.ring(&"cloth", Transform3D(Basis(Quaternion(Vector3.UP, tangent)), c + tangent * (w - 1) * 0.011),
					0.036, 0.029, 0.009, 14, HEMP.darkened(0.12))


## A rope along `path`: three strands of radius `r` twisted round it (one twist in
## `pitch` metres).
static func _laid_rope(mb: MeshBuilder, path: Array[Vector3], r: float, color: Color, pitch: float) -> void:
	var dist: Array[float] = [0.0]
	for i in range(1, path.size()):
		dist.append(dist[i - 1] + path[i].distance_to(path[i - 1]))
	for k in 3:
		var pts: Array[Vector3] = []
		var radii: Array[float] = []
		var side_prev := Vector3.ZERO
		# Sample finer than the path: ~6 points a twist.
		var total := dist[dist.size() - 1]
		var samples := int(total / pitch * 6.0)
		var j := 0
		for s in samples + 1:
			var d := total * float(s) / samples
			while j < path.size() - 2 and dist[j + 1] < d:
				j += 1
			var f := clampf((d - dist[j]) / maxf(dist[j + 1] - dist[j], 1e-6), 0.0, 1.0)
			var p := path[j].lerp(path[j + 1], f)
			var t := (path[j + 1] - path[j]).normalized()
			var side := t.cross(Vector3.UP)
			if side.length_squared() < 1e-6:
				side = side_prev
			side = side.normalized()
			side_prev = side
			var up := side.cross(t).normalized()
			var th := d / pitch * TAU + k * TAU / 3.0
			pts.append(p + (side * cos(th) + up * sin(th)) * r * 0.95)
			radii.append(r)
		mb.loft(&"cloth", pts, radii, 6, color.lightened(0.05 * (k - 1)))


# --- Nails ---------------------------------------------------------------------------------

static func _nails(mb: MeshBuilder, surfaces: Array) -> void:
	var tin := GoodsModels.mesh(&"nails_tin")
	MeshMerge.add_mesh(surfaces, tin)
	var top := tin.get_aabb().end.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 6:
		var on_lid := i < 3
		var c := Vector3(rng.randf_range(-0.022, 0.022), top + 0.002, rng.randf_range(-0.022, 0.022)) if on_lid \
				else Vector3(0.07 + rng.randf_range(-0.01, 0.03), 0.002, rng.randf_range(-0.04, 0.04))
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		_nail(mb, c - dir * 0.03, c + dir * 0.03)


## One wire nail lying from its head at `head` to its point at `point`.
static func _nail(mb: MeshBuilder, head: Vector3, point: Vector3) -> void:
	var steel := Color(0.46, 0.46, 0.47)
	var dir := (point - head).normalized()
	mb.cylinder_between(&"steel", head, point - dir * 0.006, 0.0017, 0.0017, 6, steel)
	mb.cylinder_between(&"steel", point - dir * 0.006, point, 0.0017, 0.0002, 6, steel)
	mb.cylinder_between(&"steel", head - dir * 0.001, head + dir * 0.0006, 0.0045, 0.0045, 10, steel.lightened(0.08))


# --- Bait ----------------------------------------------------------------------------------

## A little box of boards, dark earth in it and five worms on the earth.
static func _worm_box(mb: MeshBuilder) -> void:
	var w := 0.13
	var d := 0.09
	var h := 0.055
	var t := 0.007
	var wood := Color(0.58, 0.48, 0.36)
	mb.box_at(&"planks", Vector3(0, t * 0.5, 0), Vector3(w, t, d), wood.darkened(0.1))
	for s: float in [-1.0, 1.0]:
		mb.box_at(&"planks", Vector3(0, h * 0.5, s * (d - t) * 0.5), Vector3(w, h, t), wood, Vector3.ZERO, true)
		mb.box_at(&"planks", Vector3(s * (w - t) * 0.5, h * 0.5, 0), Vector3(t, h, d - 2.0 * t), wood.lightened(0.05))
	mb.box_at(&"soil_tilled", Vector3(0, h * 0.4, 0), Vector3(w - 2.0 * t, h * 0.8, d - 2.0 * t), Color(0.3, 0.22, 0.16))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 5:
		var pts: Array[Vector3] = []
		var radii: Array[float] = []
		var start := Vector3(rng.randf_range(-0.04, 0.04), h * 0.8 + 0.003, rng.randf_range(-0.025, 0.025))
		var heading := rng.randf() * TAU
		var p := start
		var n := 12
		for k in n:
			var u := float(k) / (n - 1)
			pts.append(p + Vector3(0, 0.0025 * sin(u * PI * 2.0 + i), 0))
			radii.append(0.0034 * sin(clampf(u, 0.08, 0.92) * PI) + 0.0012)
			heading += rng.randf_range(-0.6, 0.6)
			p += Vector3(cos(heading), 0, sin(heading)) * 0.0065
			p.x = clampf(p.x, -w * 0.5 + t + 0.004, w * 0.5 - t - 0.004)
			p.z = clampf(p.z, -d * 0.5 + t + 0.004, d * 0.5 - t - 0.004)
		mb.loft(&"veg_gloss", pts, radii, 7, WORM.lightened(rng.randf_range(-0.08, 0.06)))
		# The saddle, a paler band a third of the way along.
		mb.sphere(&"veg_gloss", Transform3D(Basis(), pts[4]), Vector3.ONE * 0.0042, 7, 5, WORM.lightened(0.2))


## A soft ball of dough, floured, in the carved bowl.
static func _dough(mb: MeshBuilder, surfaces: Array) -> void:
	var bowl := GoodsModels.mesh(&"dough_bowl")
	MeshMerge.add_mesh(surfaces, bowl)
	var b := bowl.get_aabb()
	var c := Vector3(b.get_center().x, b.position.y + b.size.y * 0.55, b.get_center().z)
	var r := minf(b.size.x, b.size.z) * 0.3
	mb.sphere(&"veg_rough", Transform3D(Basis(Vector3.UP, 0.4), c), Vector3(r, r * 0.62, r * 0.92), 16, 10, Color(0.8, 0.66, 0.46))
	mb.sphere(&"veg_rough", Transform3D(Basis(), c + Vector3(r * 0.35, r * 0.4, -r * 0.2)), Vector3(r * 0.45, r * 0.25, r * 0.4), 10, 6, Color(0.84, 0.72, 0.52))
	# A dusting of flour on top.
	mb.sphere(&"veg_rough", Transform3D(Basis(), c + Vector3(-r * 0.2, r * 0.5, r * 0.1)), Vector3(r * 0.5, r * 0.14, r * 0.45), 10, 5, Color(0.93, 0.9, 0.84))


# --- Sapling -------------------------------------------------------------------------------

## A young broadleaf about 0.8 m tall: its root ball in burlap tied at the neck, a thin
## stem with a few side twigs and fresh leaves on them.
static func _sapling(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var ball_y := 0.085
	mb.sphere(&"cloth", Transform3D(Basis(), Vector3(0, ball_y, 0)), Vector3(0.11, 0.085, 0.11), 14, 9, BURLAP)
	mb.cylinder(&"cloth", Transform3D(Basis(), Vector3(0, ball_y + 0.05, 0)), 0.06, 0.016, 0.05, 12, BURLAP.darkened(0.06))
	for y: float in [ball_y, ball_y + 0.083]:
		var rr := 0.112 if y == ball_y else 0.022
		mb.ring(&"cloth", Transform3D(Basis(), Vector3(0, y - 0.003, 0)), rr + 0.002, rr - 0.001, 0.006, 16, Color(0.45, 0.36, 0.24))
	# The stem, leaning a little, thinning to its top bud.
	var stem: Array[Vector3] = []
	var sr: Array[float] = []
	var n := 9
	for i in n:
		var u := float(i) / (n - 1)
		stem.append(Vector3(0.02 * sin(u * 2.2), ball_y + 0.06 + u * 0.72, 0.015 * sin(u * 3.1)))
		sr.append(lerpf(0.0085, 0.0022, u))
	mb.loft(&"bark", stem, sr, 8, Color(0.46, 0.38, 0.3))
	_leaf_cluster(mb, stem[n - 1], Vector3.UP, 5, rng, 1.0)
	# Side twigs, alternating round the stem.
	for i in 5:
		var at := 3 + i * 1
		if at >= n - 1:
			break
		var base := stem[at]
		var a := i * 2.4 + 0.5
		var dir := Vector3(cos(a), 0.9, sin(a)).normalized()
		var length := rng.randf_range(0.1, 0.16) * (1.0 - float(i) * 0.1)
		var twig: Array[Vector3] = [base, base + dir * length * 0.5 + Vector3(0, 0.01, 0), base + dir * length + Vector3(0, 0.03, 0)]
		mb.loft(&"bark", twig, [0.003, 0.0022, 0.0012] as Array[float], 6, Color(0.5, 0.42, 0.32))
		_leaf_cluster(mb, twig[2], dir, 4, rng, 0.9)
		_leaf_cluster(mb, twig[1], dir, 2, rng, 0.8)


## `count` leaves spread round a twig's end at `at`, pointing out along `dir`.
static func _leaf_cluster(mb: MeshBuilder, at: Vector3, dir: Vector3, count: int, rng: RandomNumberGenerator, size: float) -> void:
	for k in count:
		var a := TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / count
		var out := (dir * 0.6 + Vector3(cos(a), rng.randf_range(-0.1, 0.35), sin(a))).normalized()
		var length := rng.randf_range(0.03, 0.042) * size
		var c := at + out * length * 0.9
		# Flat along `out`, a little cupped (the thin axis tipped up).
		var x := out
		var z := out.cross(Vector3.UP).normalized()
		if z.length_squared() < 0.01:
			z = Vector3.FORWARD
		var y := z.cross(x).normalized()
		var basis := Basis(x, y, z).rotated(out, rng.randf_range(-0.5, 0.5))
		var green := Color(0.3, 0.5, 0.17).lerp(Color(0.46, 0.6, 0.2), rng.randf())
		mb.sphere(&"veg", Transform3D(basis, c), Vector3(length, 0.0018, length * 0.5), 8, 4, green)
		mb.cylinder_between(&"veg", at, c - out * length * 0.8, 0.0008, 0.0006, 3, green.darkened(0.3), true, false)
