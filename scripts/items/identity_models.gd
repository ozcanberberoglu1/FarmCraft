@tool
class_name IdentityModels
extends RefCounted
## Models of the things the farmer makes the farm his own with (FarmIdentity): the cans of
## paint (a tin with a label band in its colour, a drip down its side and a brush laid
## across the lid) and the decorations (PlaceableModels asks build_decor for them): a
## planter box of flowers, a slatted garden bench, a scarecrow in Grandpa's old shirt and
## straw hat, a flag pole and a stone bird bath. Every model stands on the ground at the
## origin, its front toward +Z. What changes on a decoration is its "moving" part, left
## out of the placed body and drawn by Decor itself: the planter's flowers (by season)
## and the pole's pennant (the farm's last paint colour).

const TIN := Color(0.66, 0.67, 0.69)
const WOOD := Color(0.56, 0.5, 0.44)
const WOOD_DARK := Color(0.4, 0.35, 0.3)
const STONE := Color(0.56, 0.55, 0.53)
const STRAW := Color(0.82, 0.7, 0.38)
const LEAF := Color(0.24, 0.42, 0.16)
## The bench: seat height, width, depth.
const BENCH_SEAT := 0.44
const BENCH_W := 1.5
const BENCH_D := 0.5
## The flag pole's height, and the pennant's size (along the wind, at the hoist).
const POLE_H := 3.3
const PENNANT := Vector2(0.95, 0.46)
## The planter's box: width, height of its rim, depth.
const PLANTER := Vector3(0.72, 0.3, 0.28)
## Blossom colours by season (GameClock.Season: spring, summer, autumn, winter).
const BLOSSOMS := [
	[Color(0.86, 0.16, 0.2), Color(0.96, 0.78, 0.2), Color(0.93, 0.5, 0.66)],
	[Color(0.85, 0.12, 0.16), Color(0.95, 0.94, 0.9), Color(0.9, 0.4, 0.6)],
	[Color(0.86, 0.48, 0.1), Color(0.62, 0.2, 0.12), Color(0.93, 0.76, 0.2)],
	[Color(0.9, 0.9, 0.92), Color(0.62, 0.16, 0.2), Color(0.9, 0.9, 0.92)],
]

static var _cache := {}


static func has(id: StringName) -> bool:
	return PaintTable.is_paint(id)


## A can of paint (the items "paint_<colour>").
static func mesh(id: StringName) -> ArrayMesh:
	if not _cache.has(id):
		var mb := MeshBuilder.new()
		_paint_can(mb, PaintTable.rgb(PaintTable.color_of(id)))
		_cache[id] = mb.build()
	return _cache[id]


## A decoration's parts for PlaceableModels.build: `body` what stands there, `moving` the
## part Decor draws itself (in the icon and the placement preview all the same).
static func build_decor(id: StringName, body: Array, moving: Array) -> void:
	var mb := MeshBuilder.new()
	var extra := MeshBuilder.new()
	match id:
		&"flower_pot":
			_planter(mb)
			flowers(extra, 0)
		&"garden_bench":
			_bench(mb)
		&"scarecrow":
			_scarecrow(mb)
		&"flag_pole":
			_flag_pole(mb)
			_pennant(extra, PaintTable.rgb(PaintTable.DEFAULT))
		&"bird_bath":
			_bird_bath(mb)
		_:
			return
	MeshMerge.add_mesh(body, mb.build())
	if not extra.is_empty():
		MeshMerge.add_mesh(moving, extra.build())


## The planter's flowers in `season` (their own mesh: Decor changes it with the seasons).
static func flowers_mesh(season: int) -> ArrayMesh:
	var key := "flowers/%d" % season
	if not _cache.has(key):
		var mb := MeshBuilder.new()
		flowers(mb, season)
		_cache[key] = mb.build()
	return _cache[key]


# --- Paint ------------------------------------------------------------------------------------

static func _paint_can(mb: MeshBuilder, color: Color) -> void:
	var r := 0.078
	var h := 0.17
	mb.cylinder(&"galv", Transform3D(Basis(), Vector3.ZERO), r, r, h, 20, TIN)
	# The label band in the paint's colour, a pale stripe round its middle.
	mb.cylinder(&"paper", Transform3D(Basis(), Vector3(0, 0.022, 0)), r + 0.0012, r + 0.0012, h - 0.05, 20, color, true, false)
	mb.cylinder(&"paper", Transform3D(Basis(), Vector3(0, 0.07, 0)), r + 0.002, r + 0.002, 0.032, 20, Color(0.93, 0.9, 0.82), true, false)
	# The rim and the pressed-in lid, a run of paint over the edge.
	mb.ring(&"galv", Transform3D(Basis(), Vector3(0, h - 0.004, 0)), r + 0.004, r - 0.012, 0.012, 20, TIN.lightened(0.1))
	mb.cylinder(&"galv", Transform3D(Basis(), Vector3(0, h - 0.008, 0)), r - 0.012, r - 0.012, 0.008, 20, TIN.darkened(0.08))
	mb.sphere(&"veg_gloss", Transform3D(Basis(), Vector3(0.02, h + 0.002, 0.03)), Vector3(0.034, 0.006, 0.026), 10, 5, color)
	for drip: Array in [[0.5, 0.075], [0.95, 0.045], [-0.3, 0.03]]:
		var a := float(drip[0])
		var run := float(drip[1])
		var p := Vector3(sin(a) * (r + 0.004), h - run * 0.5 + 0.004, cos(a) * (r + 0.004))
		mb.sphere(&"veg_gloss", Transform3D(Basis(Vector3.UP, a), p), Vector3(0.011, run * 0.5, 0.005), 8, 6, color)
	# The wire bail, hanging down one side.
	var prev := Vector3(-r - 0.004, h - 0.035, 0)
	for k in range(1, 9):
		var t := float(k) / 8.0
		var next := Vector3(-cos(t * PI) * (r + 0.004), h - 0.035 - sin(t * PI) * 0.085, 0.004 + sin(t * PI) * (r * 0.65))
		mb.cylinder_between(&"steel", prev, next, 0.0025, 0.0025, 5, Color(0.3, 0.3, 0.32), true, false)
		prev = next
	# The brush across the lid: a wooden handle, a tin ferrule, bristles wet with the paint.
	var bx := Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.0, h + 0.014, -0.005))
	mb.box(&"wood", bx * Transform3D(Basis(), Vector3(-0.075, 0, 0)), Vector3(0.12, 0.014, 0.026), Color(0.62, 0.5, 0.36), true)
	mb.box(&"galv", bx * Transform3D(Basis(), Vector3(0.0, 0, 0)), Vector3(0.036, 0.016, 0.046), TIN.lightened(0.12))
	mb.box(&"cloth", bx * Transform3D(Basis(), Vector3(0.045, 0, 0)), Vector3(0.056, 0.013, 0.046), Color(0.24, 0.2, 0.16))
	mb.box(&"veg_gloss", bx * Transform3D(Basis(), Vector3(0.066, 0.0005, 0)), Vector3(0.022, 0.0145, 0.048), color)


# --- Planter ----------------------------------------------------------------------------------

static func _planter(mb: MeshBuilder) -> void:
	var w := PLANTER.x
	var h := PLANTER.y
	var d := PLANTER.z
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# Two bearers under it, lapped boards round it, a capping rail, dark soil inside.
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(sx * (w * 0.5 - 0.09), 0.02, 0), Vector3(0.06, 0.04, d + 0.02), WOOD_DARK)
	for k in 3:
		var y := 0.04 + (h - 0.06) * (float(k) + 0.5) / 3.0
		var bh := (h - 0.06) / 3.0 - 0.005
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"planks", Vector3(0, y, sz * (d * 0.5 - 0.011)), Vector3(w, bh, 0.022), WOOD.lightened(rng.randf_range(-0.05, 0.06)), Vector3.ZERO, true)
		for sx: float in [-1.0, 1.0]:
			mb.box(&"planks", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (w * 0.5 - 0.011), y, 0)), Vector3(d - 0.044, bh, 0.022),
					WOOD.lightened(rng.randf_range(-0.05, 0.06)), true)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(sx * (w * 0.5 - 0.005), h * 0.5 + 0.01, sz * (d * 0.5 - 0.005)), Vector3(0.035, h - 0.02, 0.035), WOOD_DARK)
	for sz: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(0, h, sz * (d * 0.5 - 0.012)), Vector3(w + 0.03, 0.022, 0.045), WOOD.darkened(0.08), Vector3.ZERO, true)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(sx * (w * 0.5 - 0.012), h, 0), Vector3(0.045, 0.022, d - 0.04), WOOD.darkened(0.08))
	mb.box_at(&"dung", Vector3(0, h - 0.045, 0), Vector3(w - 0.05, 0.03, d - 0.05), Color(0.3, 0.24, 0.19))


## A planter's row of flowers for `season`: tulips in spring, geraniums and daisies in
## summer, chrysanthemums in autumn, heather with a few red berries in winter.
static func flowers(mb: MeshBuilder, season: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + season
	var tones: Array = BLOSSOMS[clampi(season, 0, 3)]
	var top := PLANTER.y - 0.03
	var n := 9
	for i in n:
		var x := -PLANTER.x * 0.5 + 0.07 + (PLANTER.x - 0.14) * (float(i) + 0.5) / n + rng.randf_range(-0.015, 0.015)
		var z := rng.randf_range(-0.07, 0.07)
		var tall := rng.randf_range(0.16, 0.27) if season != 3 else rng.randf_range(0.1, 0.17)
		var lean := Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03))
		var foot := Vector3(x, top, z)
		var head := foot + Vector3(0, tall, 0) + lean
		var green := LEAF.lightened(rng.randf_range(-0.04, 0.1))
		mb.cylinder_between(&"veg", foot, head, 0.005, 0.004, 5, green, true, false)
		# Leaves low on the stem (a tuft of them for the winter heather).
		for k in (4 if season == 3 else 2):
			var a := rng.randf() * TAU
			var out := Vector3(cos(a), 0.45, sin(a)).normalized()
			var at := foot + Vector3(0, tall * rng.randf_range(0.15, 0.5), 0) + out * 0.035
			mb.sphere(&"veg", Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.5), at), Vector3(0.04, 0.006, 0.016), 6, 4, green)
		var tone: Color = tones[i % tones.size()]
		tone = tone.lightened(rng.randf_range(-0.06, 0.08))
		match season:
			0:
				# A tulip's cup.
				mb.sphere(&"veg", Transform3D(Basis(), head + Vector3(0, 0.022, 0)), Vector3(0.022, 0.032, 0.022), 8, 6, tone)
			1:
				# A head of small blossoms round a pale eye.
				for k in 5:
					var a := TAU * float(k) / 5.0 + rng.randf() * 0.4
					mb.sphere(&"veg", Transform3D(Basis(), head + Vector3(cos(a) * 0.018, 0.008 + rng.randf() * 0.008, sin(a) * 0.018)), Vector3(0.016, 0.012, 0.016), 6, 4, tone)
				mb.sphere(&"veg", Transform3D(Basis(), head + Vector3(0, 0.016, 0)), Vector3(0.011, 0.01, 0.011), 6, 4, Color(0.96, 0.82, 0.3))
			2:
				# A chrysanthemum's shaggy ball.
				mb.sphere(&"veg_rough", Transform3D(Basis(), head + Vector3(0, 0.012, 0)), Vector3(0.03, 0.022, 0.03), 9, 6, tone)
			_:
				# Heather: a spike of tiny bells, a red berry here and there.
				mb.sphere(&"veg_rough", Transform3D(Basis(), head), Vector3(0.013, 0.04, 0.013), 6, 5, tone)
				if i % 3 == 1:
					mb.sphere(&"veg_gloss", Transform3D(Basis(), foot + Vector3(0.02, 0.05, 0.015)), Vector3(0.011, 0.011, 0.011), 6, 4, Color(0.7, 0.1, 0.1))


# --- Bench ------------------------------------------------------------------------------------

static func _bench(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var hw := BENCH_W * 0.5
	var back_tilt := 12.0
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw - 0.04)
		# Front leg up to the arm, back leg up into the back rest (leaning), a stretcher, the arm.
		mb.box_at(&"wood", Vector3(x, 0.31, BENCH_D * 0.5 - 0.04), Vector3(0.06, 0.62, 0.06), WOOD_DARK)
		mb.box_at(&"wood", Vector3(x, 0.22, -BENCH_D * 0.5 + 0.05), Vector3(0.06, 0.44, 0.06), WOOD_DARK)
		mb.box_at(&"wood", Vector3(x, 0.66, -BENCH_D * 0.5 + 0.005), Vector3(0.055, 0.5, 0.05), WOOD_DARK, Vector3(-back_tilt, 0, 0))
		mb.box(&"wood", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0.17, 0.0)), Vector3(BENCH_D - 0.14, 0.045, 0.04), WOOD_DARK.lightened(0.05), true)
		mb.box(&"wood", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, BENCH_SEAT - 0.045, 0.0)), Vector3(BENCH_D - 0.1, 0.06, 0.04), WOOD_DARK.lightened(0.05), true)
		mb.box(&"wood", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0.635, 0.03)), Vector3(BENCH_D + 0.02, 0.035, 0.075), WOOD.darkened(0.05), true)
	# The seat's slats and the back's, the grain along them.
	for k in 5:
		var z := -BENCH_D * 0.5 + 0.075 + k * 0.094
		mb.box_at(&"planks", Vector3(0, BENCH_SEAT - 0.004 * absf(float(k) - 2.0), z), Vector3(BENCH_W - 0.02, 0.028, 0.082), WOOD.lightened(rng.randf_range(-0.05, 0.07)),
				Vector3.ZERO, true)
	for k in 4:
		var up := 0.11 + k * 0.105
		var lean := Basis(Vector3.RIGHT, deg_to_rad(-back_tilt))
		var c := Vector3(0, BENCH_SEAT + 0.02, -BENCH_D * 0.5 + 0.04) + lean * Vector3(0, up, 0.0)
		mb.box(&"planks", Transform3D(lean, c), Vector3(BENCH_W - 0.02, 0.085, 0.024), WOOD.lightened(rng.randf_range(-0.05, 0.07)), true)
	mb.box_at(&"wood", Vector3(0, 0.17, 0.0), Vector3(BENCH_W - 0.14, 0.04, 0.04), WOOD_DARK.lightened(0.05), Vector3.ZERO, true)


# --- Scarecrow --------------------------------------------------------------------------------

static func _scarecrow(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var shirt := Color(0.56, 0.24, 0.2)
	var denim := Color(0.26, 0.33, 0.44)
	var sack := Color(0.74, 0.64, 0.46)
	var arm_y := 1.42
	# A stake and a crossbar lashed to it.
	mb.cylinder(&"wood", Transform3D(Basis(), Vector3(0, -0.05, 0)), 0.032, 0.028, 1.75, 8, WOOD_DARK)
	mb.cylinder(&"wood", Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.68, arm_y, 0)), 0.024, 0.024, 1.36, 8, WOOD_DARK)
	# Grandpa's old shirt stuffed with straw: the body, the sleeves along the bar, a patch.
	mb.sphere(&"cloth", Transform3D(Basis(), Vector3(0, 1.16, 0)), Vector3(0.21, 0.33, 0.13), 14, 9, shirt)
	for sx: float in [-1.0, 1.0]:
		mb.cylinder(&"cloth", Transform3D(Basis(Vector3.FORWARD, sx * PI * 0.5), Vector3(sx * 0.14, arm_y, 0)), 0.075, 0.058, 0.42, 10, shirt.darkened(0.06))
		# Straw out of the cuffs.
		for k in 12:
			var from := Vector3(sx * 0.55, arm_y + rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
			var dir := Vector3(sx * rng.randf_range(0.6, 1.0), rng.randf_range(-0.7, 0.25), rng.randf_range(-0.4, 0.4)).normalized()
			mb.cylinder_between(&"veg", from, from + dir * rng.randf_range(0.1, 0.2), 0.004, 0.002, 3, STRAW.lightened(rng.randf_range(-0.15, 0.1)), false, false)
		# A leg of the old trousers, straw at its hem.
		mb.cylinder(&"cloth", Transform3D(Basis(Vector3.FORWARD, sx * 0.08), Vector3(sx * 0.1, 0.36, 0)), 0.07, 0.085, 0.52, 10, denim.lightened(sx * 0.03))
		for k in 8:
			var from := Vector3(sx * 0.1 + rng.randf_range(-0.05, 0.05), 0.38, rng.randf_range(-0.05, 0.05))
			mb.cylinder_between(&"veg", from, from + Vector3(rng.randf_range(-0.05, 0.05), -rng.randf_range(0.08, 0.16), rng.randf_range(-0.05, 0.05)), 0.004, 0.002, 3,
					STRAW.lightened(rng.randf_range(-0.15, 0.1)), false, false)
	mb.box_at(&"cloth", Vector3(0.08, 1.06, 0.118), Vector3(0.1, 0.09, 0.012), Color(0.3, 0.42, 0.3), Vector3(0, 12, 8))
	mb.box_at(&"cloth", Vector3(0, 0.88, 0.0), Vector3(0.36, 0.04, 0.2), WOOD_DARK.darkened(0.2))
	for k in 3:
		mb.sphere(&"paint_in", Transform3D(Basis(), Vector3(0, 1.3 - k * 0.11, 0.128)), Vector3(0.014, 0.014, 0.006), 6, 4, Color(0.9, 0.86, 0.74))
	# The head: a sack tied at the neck, button eyes, a carrot of a nose, a stitched grin.
	var head := Vector3(0, 1.66, 0.01)
	mb.sphere(&"cloth", Transform3D(Basis(), head), Vector3(0.15, 0.17, 0.145), 14, 10, sack)
	mb.cylinder(&"cloth", Transform3D(Basis(), Vector3(0, 1.47, 0)), 0.1, 0.07, 0.06, 10, sack.darkened(0.12))
	for k in 14:
		var a := rng.randf() * TAU
		var from := Vector3(cos(a) * 0.07, 1.5, sin(a) * 0.07)
		mb.cylinder_between(&"veg", from, from + Vector3(cos(a) * 0.09, -rng.randf_range(0.02, 0.09), sin(a) * 0.09), 0.004, 0.002, 3,
				STRAW.lightened(rng.randf_range(-0.15, 0.1)), false, false)
	for sx: float in [-1.0, 1.0]:
		var eye := head + Vector3(sx * 0.055, 0.03, 0.132)
		mb.cylinder(&"paint_in", Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, sx * 0.35), eye), 0.03, 0.03, 0.008, 12, Color(0.1, 0.09, 0.08))
		mb.sphere(&"paint_in", Transform3D(Basis(), eye + Vector3(0.008, 0.008, 0.01)), Vector3(0.008, 0.008, 0.003), 6, 4, Color(0.95, 0.95, 0.92))
	mb.cylinder(&"veg", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), head + Vector3(0, -0.01, 0.14)), 0.02, 0.004, 0.09, 8, Color(0.9, 0.45, 0.12))
	for k in 7:
		var t := (float(k) - 3.0) / 3.0
		mb.box_at(&"paint_in", head + Vector3(t * 0.07, -0.075 + t * t * 0.03, 0.128 - absf(t) * 0.018), Vector3(0.016, 0.006, 0.004), Color(0.16, 0.12, 0.1), Vector3(0, 0, t * -28.0))
		mb.box_at(&"paint_in", head + Vector3(t * 0.07, -0.075 + t * t * 0.03, 0.129 - absf(t) * 0.018), Vector3(0.004, 0.018, 0.004), Color(0.16, 0.12, 0.1))
	# The straw hat, tipped back a little, with a band.
	var hat := Transform3D(Basis(Vector3.RIGHT, -0.16) * Basis(Vector3.FORWARD, 0.08), head + Vector3(0, 0.115, -0.01))
	mb.cylinder(&"straw", hat, 0.29, 0.275, 0.014, 20, STRAW)
	mb.cylinder(&"straw", hat * Transform3D(Basis(), Vector3(0, 0.012, 0)), 0.15, 0.12, 0.11, 16, STRAW.lightened(0.04))
	mb.cylinder(&"cloth", hat * Transform3D(Basis(), Vector3(0, 0.014, 0)), 0.153, 0.147, 0.03, 16, Color(0.5, 0.16, 0.14), true, false)


# --- Flag pole --------------------------------------------------------------------------------

static func _flag_pole(mb: MeshBuilder) -> void:
	# A stone footing, a white-painted pole tapering to a ball, a cleat with the halyard.
	mb.cylinder(&"stone", Transform3D(Basis(), Vector3(0, -0.04, 0)), 0.19, 0.16, 0.16, 10, STONE)
	mb.cylinder(&"paint", Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.036, 0.022, POLE_H - 0.1, 10, Color(0.9, 0.89, 0.85))
	mb.sphere(&"veg_gloss", Transform3D(Basis(), Vector3(0, POLE_H + 0.03, 0)), Vector3(0.04, 0.04, 0.04), 10, 7, Color(0.78, 0.6, 0.2))
	mb.box_at(&"steel", Vector3(0, 1.1, 0.036), Vector3(0.02, 0.09, 0.014), Color(0.25, 0.25, 0.27))
	mb.cylinder_between(&"cloth", Vector3(0.012, 1.1, 0.04), Vector3(0.02, POLE_H - 0.08, 0.03), 0.003, 0.003, 4, Color(0.8, 0.76, 0.66), true, false)


## The pennant as a still mesh (the icon, the placement preview): a long triangle flying
## toward +X from the pole's top.
static func _pennant(mb: MeshBuilder, color: Color) -> void:
	var top := POLE_H - 0.1
	var a := Vector3(0.03, top, 0.0)
	var b := Vector3(0.03, top - PENNANT.y, 0.0)
	var c := Vector3(0.03 + PENNANT.x, top - PENNANT.y * 0.5 - 0.06, 0.05)
	mb.tri(&"cloth", a, b, c, color)
	mb.tri(&"cloth", a, c, b, color)


## The pennant as Decor flies it: a strip of quads from the hoist (x 0) to the point
## (x PENNANT.x), UV.x along it (the wave shader swings it by that), seen from both sides.
static func pennant_mesh() -> ArrayMesh:
	if _cache.has("pennant"):
		return _cache["pennant"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 10
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var h0 := PENNANT.y * 0.5 * (1.0 - u0)
		var h1 := PENNANT.y * 0.5 * (1.0 - u1)
		var quad := [Vector3(u0 * PENNANT.x, h0, 0), Vector3(u1 * PENNANT.x, h1, 0), Vector3(u1 * PENNANT.x, -h1, 0), Vector3(u0 * PENNANT.x, -h0, 0)]
		var uvs := [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(uvs[k])
			st.add_vertex(quad[k])
	var m := st.commit()
	_cache["pennant"] = m
	return m


# --- Bird bath --------------------------------------------------------------------------------

static func _bird_bath(mb: MeshBuilder) -> void:
	# A square plinth, a turned column, a wide shallow bowl with water in it.
	mb.box_at(&"stone", Vector3(0, 0.03, 0), Vector3(0.44, 0.08, 0.44), STONE.darkened(0.06))
	mb.cylinder(&"stone", Transform3D(Basis(), Vector3(0, 0.07, 0)), 0.15, 0.1, 0.07, 12, STONE)
	var centers: Array[Vector3] = [Vector3(0, 0.14, 0), Vector3(0, 0.24, 0), Vector3(0, 0.36, 0), Vector3(0, 0.48, 0), Vector3(0, 0.56, 0)]
	var radii: Array[float] = [0.095, 0.075, 0.09, 0.07, 0.11]
	mb.loft(&"stone", centers, radii, 12, STONE, false)
	mb.cylinder(&"stone", Transform3D(Basis(), Vector3(0, 0.56, 0)), 0.14, 0.36, 0.1, 18, STONE.lightened(0.03))
	mb.ring(&"stone", Transform3D(Basis(), Vector3(0, 0.66, 0)), 0.37, 0.31, 0.03, 18, STONE.lightened(0.06))
	mb.disc(&"water_still", Transform3D(Basis(), Vector3(0, 0.672, 0)), 0.315, 18, Color(0.3, 0.42, 0.46))
	# A sparrow on the rim, looking about.
	var bird := Transform3D(Basis(Vector3.UP, 2.3), Vector3(0.22, 0.69, 0.25))
	var brown := Color(0.5, 0.38, 0.27)
	mb.sphere(&"cloth", bird * Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.045, 0)), Vector3(0.032, 0.03, 0.05), 10, 7, brown)
	mb.sphere(&"cloth", bird * Transform3D(Basis(), Vector3(0, 0.082, 0.036)), Vector3(0.022, 0.021, 0.023), 8, 6, brown.darkened(0.1))
	mb.sphere(&"cloth", bird * Transform3D(Basis(), Vector3(0, 0.04, 0.03)), Vector3(0.024, 0.02, 0.026), 8, 6, Color(0.8, 0.76, 0.68))
	mb.cylinder(&"hoof", bird * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.08, 0.055)), 0.006, 0.001, 0.016, 5, Color(0.25, 0.2, 0.15))
	mb.box(&"cloth", bird * Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.05, -0.062)), Vector3(0.022, 0.006, 0.05), brown.darkened(0.2))
	for sx: float in [-1.0, 1.0]:
		mb.sphere(&"eye", bird * Transform3D(Basis(), Vector3(sx * 0.017, 0.087, 0.047)), Vector3(0.005, 0.005, 0.004), 5, 4, Color(0.05, 0.05, 0.05))
		mb.cylinder(&"hoof", bird * Transform3D(Basis(), Vector3(sx * 0.012, 0.0, 0.0)), 0.002, 0.002, 0.022, 4, Color(0.3, 0.24, 0.18))
