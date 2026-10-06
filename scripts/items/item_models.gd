@tool
class_name ItemModels
extends RefCounted
## Realistic 3D models for items, used for held items, dropped pickups and the
## rendered inventory icons. Tools stand along +Y with the grip near the origin;
## most are photo-scanned models brought into that frame by ToolModels.

const HANDLE := Color(0.64, 0.58, 0.5)
const HANDLE_DARK := Color(0.52, 0.46, 0.4)
const STEEL := Color(0.33, 0.34, 0.36)
const STEEL_EDGE := Color(0.74, 0.75, 0.77)
const GALV := Color(0.58, 0.61, 0.63)
const NEUTRAL := Color(0.5, 0.5, 0.5)
const LEAF_GREEN := Color(0.24, 0.42, 0.14)

const CROP_COLORS := {
	&"wheat": Color(0.9, 0.66, 0.24), &"carrot": Color(0.93, 0.45, 0.1), &"potato": Color(0.5, 0.36, 0.22),
	&"tomato": Color(0.82, 0.12, 0.07), &"corn": Color(0.96, 0.78, 0.22), &"eggplant": Color(0.22, 0.09, 0.26),
	&"strawberry": Color(0.86, 0.08, 0.1), &"pumpkin": Color(0.9, 0.42, 0.06),
}

## Rotation (degrees) used when rendering the icon, so long tools sit diagonally.
const ICON_ROTATION := {
	&"hoe": Vector3(38, 115, 0), &"scythe": Vector3(0, -20, -22), &"pickaxe": Vector3(0, 0, -40),
	&"axe": Vector3(0, 0, -40), &"pitchfork": Vector3(0, -15, -36), &"watering_can": Vector3(0, -60, 0),
	&"milk_pail": Vector3(15, 20, 0), &"shears": Vector3(0, 0, -30), &"brush": Vector3(22, -32, 0),
	&"wheat": Vector3(0, 0, -25), &"carrot": Vector3(0, 0, -50), &"corn": Vector3(0, 0, -45),
	&"eggplant": Vector3(0, 0, -40), &"wood": Vector3(15, 30, 0), &"hay": Vector3(0, 0, -30),
	&"hay_big": Vector3(18, 40, 0),
	&"cheese": Vector3(22, -35, 0), &"truck_key": Vector3(64, 0, -30), &"chicken_crate": Vector3(16, -34, 0), &"rooster_crate": Vector3(16, -34, 0),
	&"knife": Vector3(0, 0, -45), &"bow": Vector3(40, 90, 0), &"fishing_rod": Vector3(12, 150, -38),
	&"rope": Vector3(28, 20, 0), &"nails": Vector3(18, 25, 0), &"worm": Vector3(32, 20, 0), &"dough": Vector3(30, 20, 0),
	&"sapling": Vector3(0, 30, -8), &"campfire": Vector3(20, 20, 0),
	&"rabbit": Vector3(8, 135, 0), &"wolf_pelt": Vector3(30, 35, 0),
	&"cane_rod": Vector3(12, 150, -38), &"carbon_rod": Vector3(12, 150, -38), &"carp_rod": Vector3(12, 150, -38),
	&"maggot": Vector3(35, 20, 0), &"sweetcorn": Vector3(28, 20, 0), &"cheese_bait": Vector3(35, 20, 0),
	&"minnow": Vector3(35, 20, 0), &"spinner": Vector3(55, 10, -20),
	&"arrow": Vector3(10, 30, -48),
}

## Long tools are framed on their working end: model-space focus point and view radius.
const ICON_FRAME := {
	&"hoe": [Vector3(0, 0.66, 0.0), 0.52], &"scythe": [Vector3(0.16, 0.5, 0.0), 0.56],
	&"pitchfork": [Vector3(0, 0.84, 0.0), 0.5],
	# The rod on its grip and reel (the tip runs out of the picture).
	&"fishing_rod": [Vector3(0, 0.3, 0.0), 0.42],
	&"cane_rod": [Vector3(0, 0.25, 0.0), 0.42], &"carbon_rod": [Vector3(0, 0.3, 0.0), 0.45],
	&"carp_rod": [Vector3(0, 0.3, 0.0), 0.48],
	# The flag pole on its pennant, the scarecrow on its head and shoulders.
	&"flag_pole": [Vector3(0.36, 2.86, 0.0), 0.72], &"scarecrow": [Vector3(0, 1.36, 0.0), 0.8],
}

static var _cache: Dictionary = {}


static func mesh(id: StringName) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	# Tools, produce and goods come from photo-scanned models where one has been
	# added; machines use their placed model.
	var m: ArrayMesh
	if ToolModels.has(id):
		m = ToolModels.mesh(id)
	elif GoodsModels.has(id):
		m = GoodsModels.mesh(id)
	elif FoodModels.has(id):
		# The catch cleaned at the food table, game meat and trophy fish (scripts/camp).
		m = FoodModels.mesh(id)
	elif FishModels.has(id):
		# The fish, the fishing rod and the old boot (art/models/fish).
		m = FishModels.mesh(id)
	elif CraftModels.has(id):
		m = CraftModels.mesh(id)
	elif ArrowModels.has(id):
		# The bow's arrows (scripts/combat).
		m = ArrowModels.mesh(id)
	elif BerryModels.LOOK.has(id):
		# Wild berries (a handful) and the caught rabbit (NATURE).
		m = BerryModels.handful(id)
	elif id == &"rabbit":
		m = RabbitRig.item_mesh()
	elif id == &"wolf_pelt":
		# A folded wolf pelt (tools/blender/build_wolf.py).
		m = WolfRig.pelt_mesh()
	elif IdentityModels.has(id):
		# The cans of paint (FarmIdentity).
		m = IdentityModels.mesh(id)
	elif PlaceableTable.is_placeable(id):
		m = PlaceableModels.mesh(id, "whole")
	else:
		m = procedural(id)
	_cache[id] = m
	return m


## The hand-built model (also kept for tools, for comparison and as a fallback).
static func procedural(id: StringName) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var overrides := {}
	var sid := String(id)
	match id:
		&"hoe": _hoe(mb)
		&"watering_can": _watering_can(mb)
		&"scythe": _scythe(mb)
		&"pickaxe": _pickaxe(mb)
		&"axe": _axe(mb)
		&"milk_pail": _milk_pail(mb)
		&"shears": _shears(mb)
		&"brush": _brush(mb)
		&"pitchfork": _pitchfork(mb)
		&"wheat": _wheat(mb)
		&"carrot": _carrot(mb)
		&"potato": _potato(mb)
		&"tomato": _tomato(mb)
		&"corn": _corn(mb)
		&"eggplant": _eggplant(mb)
		&"strawberry": _strawberry(mb)
		&"pumpkin": _pumpkin(mb)
		&"wood": _logs(mb)
		&"stone": _stone(mb, false)
		&"iron_ore": _stone(mb, true)
		&"hay": _hay(mb)
		&"egg": _egg(mb)
		&"milk": _milk(mb)
		&"wool": _wool(mb)
		&"feed": _feed_sack(mb)
		&"medicine": _medicine(mb)
		&"cheese": _cheese(mb)
		&"yarn": _yarn(mb)
		&"pickles": _jar(mb, "pickles")
		&"jam": _jar(mb, "jam")
		&"tomato_paste": _jar(mb, "paste")
		&"flour": _sack(mb, Color(0.93, 0.91, 0.86), Color(0.7, 0.55, 0.3), &"paper", false)
		&"fertilizer": _sack(mb, Color(0.22, 0.44, 0.27), Color(0.95, 0.95, 0.9), &"veg_gloss", false)
		&"manure": _sack(mb, Color(0.6, 0.5, 0.36), Color(0.0, 0.0, 0.0, 0.0), &"cloth", true)
		&"truck_key": _truck_key(mb)
		&"flower_bouquet": _bouquet(mb)
		&"dog_food":
			_dog_food(mb)
			overrides[&"print"] = _print_material("dog_food_print")
		&"dog_ball": _dog_ball(mb)
		&"chicken_crate", &"rooster_crate":
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			poultry_crate(mb, rng)
			hen_figure(mb, Transform3D(Basis(), Vector3(0, CRATE_FLOOR, 0)))
		_:
			if sid.ends_with("_seed"):
				var crop := StringName(sid.trim_suffix("_seed"))
				_seed_packet(mb, crop)
				overrides[&"label"] = _label_material(crop)
			else:
				mb.box_at(&"paper", Vector3.ZERO, Vector3(0.1, 0.1, 0.1), Color(0.8, 0.2, 0.8))
	return mb.build(overrides)


# --- Tools -----------------------------------------------------------------------

static func _handle(mb: MeshBuilder, points: Array[Vector3], radii: Array[float], color := HANDLE) -> void:
	mb.loft(&"wood", points, radii, 10, color)


static func _hoe(mb: MeshBuilder) -> void:
	_handle(mb, [Vector3(0, -0.42, 0), Vector3(0, 0.2, 0), Vector3(0, 0.82, 0)], [0.018, 0.019, 0.017])
	mb.cylinder(&"steel", Transform3D(Basis(), Vector3(0, 0.76, 0)), 0.025, 0.023, 0.09, 12, STEEL)
	mb.loft(&"steel", [Vector3(0, 0.84, 0), Vector3(0, 0.9, 0.035), Vector3(0, 0.89, 0.08), Vector3(0, 0.86, 0.105)],
			[0.011, 0.01, 0.009, 0.009], 8, STEEL)
	var blade: Array[Vector3] = [
		Vector3(-0.085, 0.7, 0.107), Vector3(0.085, 0.7, 0.107), Vector3(0.062, 0.875, 0.101), Vector3(-0.062, 0.875, 0.101),
		Vector3(-0.085, 0.7, 0.111), Vector3(0.085, 0.7, 0.111), Vector3(0.062, 0.875, 0.113), Vector3(-0.062, 0.875, 0.113)]
	mb.hexa(&"steel", blade, STEEL)
	var edge: Array[Vector3] = [
		Vector3(-0.086, 0.698, 0.1065), Vector3(0.086, 0.698, 0.1065), Vector3(0.084, 0.716, 0.1062), Vector3(-0.084, 0.716, 0.1062),
		Vector3(-0.086, 0.698, 0.1115), Vector3(0.086, 0.698, 0.1115), Vector3(0.084, 0.716, 0.1118), Vector3(-0.084, 0.716, 0.1118)]
	mb.hexa(&"steel", edge, STEEL_EDGE)


static func _watering_can(mb: MeshBuilder) -> void:
	mb.cylinder(&"galv", Transform3D.IDENTITY, 0.125, 0.115, 0.24, 28, GALV)
	mb.ring(&"galv", Transform3D(Basis(), Vector3(0, 0.232, 0)), 0.121, 0.1, 0.014, 28, GALV.darkened(0.08))
	mb.ring(&"galv", Transform3D(Basis(), Vector3(0, -0.002, 0)), 0.13, 0.118, 0.014, 28, GALV.darkened(0.15))
	mb.ring(&"galv", Transform3D(Basis(), Vector3(0, 0.1, 0)), 0.1235, 0.119, 0.012, 28, GALV.darkened(0.1))
	var arc: Array[Vector3] = []
	var arc_r: Array[float] = []
	for i in 11:
		var a := PI * float(i) / 10.0
		arc.append(Vector3(0, 0.24 + sin(a) * 0.11, cos(a) * 0.085))
		arc_r.append(0.0085)
	mb.loft(&"galv", arc, arc_r, 8, GALV)
	mb.loft(&"galv", [Vector3(0, 0.21, -0.112), Vector3(0, 0.19, -0.16), Vector3(0, 0.12, -0.17), Vector3(0, 0.06, -0.118)],
			[0.008, 0.008, 0.008, 0.008], 8, GALV)
	var s0 := Vector3(0, 0.05, 0.1)
	var s2 := Vector3(0, 0.27, 0.36)
	mb.loft(&"galv", [s0, Vector3(0, 0.14, 0.22), s2], [0.026, 0.016, 0.012], 12, GALV)
	var dir := (s2 - Vector3(0, 0.14, 0.22)).normalized()
	mb.cylinder_between(&"galv", s2, s2 + dir * 0.035, 0.016, 0.034, 14, GALV.darkened(0.05))
	mb.cylinder_between(&"steel", s2 + dir * 0.035, s2 + dir * 0.038, 0.034, 0.034, 14, STEEL.darkened(0.2))


static func _scythe(mb: MeshBuilder) -> void:
	_handle(mb, [Vector3(0, -0.6, 0), Vector3(0.018, -0.12, 0), Vector3(0, 0.36, 0), Vector3(-0.03, 0.82, 0)],
			[0.02, 0.02, 0.019, 0.018])
	for g: Array in [[Vector3(0.012, -0.02, 0), Vector3(0.012, 0.0, 0.13)], [Vector3(0.005, 0.46, 0), Vector3(0.005, 0.48, 0.12)]]:
		mb.cylinder_between(&"wood", g[0], g[1], 0.013, 0.012, 8, HANDLE_DARK)
	mb.cylinder(&"steel", Transform3D(Basis(), Vector3(-0.03, 0.78, 0)), 0.024, 0.023, 0.06, 10, STEEL)
	# Curved blade: a thin slab swept out sideways from the heel.
	var heel := Vector3(-0.03, 0.81, 0)
	var n := 14
	var prev_back := Vector3.ZERO
	var prev_front := Vector3.ZERO
	for i in n:
		var t := float(i) / (n - 1)
		var back := heel + Vector3(0.64 * t, -0.05 * t, 0.2 * t * t)
		var tangent := Vector3(0.64, -0.05, 0.4 * t).normalized()
		var toward_edge := tangent.cross(Vector3.UP).normalized() * -1.0
		var width := lerpf(0.075, 0.006, pow(t, 1.3))
		var front := back + toward_edge * width
		if i > 0:
			var th := 0.003
			var up := Vector3(0, th, 0)
			mb.quad(&"steel", prev_back + up, back + up, front + up, prev_front + up, STEEL)
			mb.quad(&"steel", prev_front - up, front - up, back - up, prev_back - up, STEEL)
			mb.quad(&"steel", prev_back - up, back - up, back + up, prev_back + up, STEEL.darkened(0.1))
			var edge_in_prev := prev_front.lerp(prev_back, 0.12)
			var edge_in := front.lerp(back, 0.12)
			mb.quad(&"steel", edge_in_prev + up * 1.05, edge_in + up * 1.05, front + up * 1.05, prev_front + up * 1.05, STEEL_EDGE)
		prev_back = back
		prev_front = front


static func _pickaxe(mb: MeshBuilder) -> void:
	_handle(mb, [Vector3(0, -0.4, 0), Vector3(0, 0.1, 0), Vector3(0, 0.5, 0)], [0.021, 0.019, 0.02])
	mb.box_at(&"steel", Vector3(0, 0.525, 0), Vector3(0.075, 0.085, 0.055), STEEL)
	mb.loft(&"steel", [Vector3(-0.03, 0.535, 0), Vector3(-0.12, 0.54, 0), Vector3(-0.22, 0.515, 0), Vector3(-0.3, 0.46, 0)],
			[0.028, 0.022, 0.013, 0.002], 8, STEEL)
	mb.loft(&"steel", [Vector3(0.03, 0.535, 0), Vector3(0.12, 0.54, 0), Vector3(0.21, 0.52, 0), Vector3(0.27, 0.49, 0)],
			[0.028, 0.023, 0.016, 0.006], 8, STEEL)


static func _axe(mb: MeshBuilder) -> void:
	_handle(mb, [Vector3(0, -0.36, 0), Vector3(0.012, 0.04, 0), Vector3(0, 0.44, 0)], [0.021, 0.019, 0.022])
	var head: Array[Vector3] = [
		Vector3(-0.04, 0.36, -0.022), Vector3(0.16, 0.32, -0.002), Vector3(0.16, 0.47, -0.002), Vector3(-0.04, 0.44, -0.022),
		Vector3(-0.04, 0.36, 0.022), Vector3(0.16, 0.32, 0.002), Vector3(0.16, 0.47, 0.002), Vector3(-0.04, 0.44, 0.022)]
	mb.hexa(&"steel", head, STEEL)
	var edge: Array[Vector3] = [
		Vector3(0.135, 0.325, -0.0045), Vector3(0.162, 0.318, -0.0015), Vector3(0.162, 0.472, -0.0015), Vector3(0.135, 0.466, -0.0045),
		Vector3(0.135, 0.325, 0.0045), Vector3(0.162, 0.318, 0.0015), Vector3(0.162, 0.472, 0.0015), Vector3(0.135, 0.466, 0.0045)]
	mb.hexa(&"steel", edge, STEEL_EDGE)


static func _milk_pail(mb: MeshBuilder) -> void:
	var segs := 28
	var h := 0.26
	var rb := 0.12
	var rt := 0.145
	mb.cylinder(&"galv", Transform3D.IDENTITY, rb, rt, h, segs, GALV, true, false)
	mb.disc(&"galv", Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.0, 0)), rb, segs, GALV.darkened(0.1))
	# Inner wall and floor, facing inward.
	var inner := 0.006
	for k in segs:
		var a0 := TAU * float(k) / segs
		var a1 := TAU * float(k + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := d0 * (rb - inner) + Vector3(0, 0.01, 0)
		var b1 := d1 * (rb - inner) + Vector3(0, 0.01, 0)
		var t0 := d0 * (rt - inner) + Vector3(0, h, 0)
		var t1 := d1 * (rt - inner) + Vector3(0, h, 0)
		mb.tri_n(&"galv", b0, b1, t1, -d0, -d1, -d1, GALV.darkened(0.2), GALV.darkened(0.2), GALV.darkened(0.1))
		mb.tri_n(&"galv", b0, t1, t0, -d0, -d1, -d0, GALV.darkened(0.2), GALV.darkened(0.1), GALV.darkened(0.1))
	mb.disc(&"galv", Transform3D(Basis(), Vector3(0, 0.01, 0)), rb - inner, segs, GALV.darkened(0.25))
	mb.ring(&"galv", Transform3D(Basis(), Vector3(0, h - 0.004, 0)), rt + 0.004, rt - inner, 0.012, segs, GALV.darkened(0.05))
	var arc: Array[Vector3] = []
	var arc_r: Array[float] = []
	for i in 13:
		var a := PI * float(i) / 12.0
		arc.append(Vector3(cos(a) * (rt + 0.006), h + sin(a) * 0.13 - 0.02, 0))
		arc_r.append(0.004)
	mb.loft(&"steel", arc, arc_r, 6, STEEL)


static func _shears(mb: MeshBuilder) -> void:
	for side: float in [-1.0, 1.0]:
		var blade: Array[Vector3] = [
			Vector3(-0.012 * side, 0.0, -0.004), Vector3(0.012 * side, 0.0, -0.004),
			Vector3(0.002 * side, 0.2, -0.001), Vector3(-0.004 * side, 0.2, -0.001),
			Vector3(-0.012 * side, 0.0, 0.0), Vector3(0.012 * side, 0.0, 0.0),
			Vector3(0.002 * side, 0.2, 0.001), Vector3(-0.004 * side, 0.2, 0.001)]
		var xf := Transform3D(Basis(Vector3.BACK, side * 0.12), Vector3(0, 0, side * 0.003))
		var pts: Array[Vector3] = []
		for p in blade:
			pts.append(xf * p)
		mb.hexa(&"steel", pts, STEEL_EDGE.darkened(0.1))
		var loop: Array[Vector3] = []
		var loop_r: Array[float] = []
		var center := xf * Vector3(0.0, -0.06, 0.0) + Vector3(side * 0.02, 0, 0)
		for i in 17:
			var a := TAU * float(i) / 16.0
			loop.append(center + Vector3(cos(a) * 0.028, sin(a) * 0.035, 0))
			loop_r.append(0.006)
		mb.loft(&"veg_gloss", loop, loop_r, 8, Color(0.62, 0.08, 0.06), false)
		mb.cylinder_between(&"steel", xf * Vector3(0, 0.0, 0), center + Vector3(0, 0.03, 0), 0.006, 0.006, 6, STEEL)
	mb.cylinder_between(&"steel", Vector3(0, 0.0, -0.01), Vector3(0, 0.0, 0.01), 0.007, 0.007, 10, STEEL.darkened(0.2))


## A dandy brush for grooming: an oval wooden back with a leather strap over it and
## stiff natural-fibre tufts below.
static func _brush(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var oval := Basis.from_scale(Vector3(1.0, 1.0, 0.42))
	var wood := Color(0.6, 0.44, 0.3)
	mb.cylinder(&"wood", Transform3D(oval, Vector3(0, 0.034, 0)), 0.084, 0.083, 0.02, 28, wood)
	mb.cylinder(&"wood", Transform3D(oval, Vector3(0, 0.054, 0)), 0.083, 0.072, 0.007, 28, wood.lightened(0.04))
	# The strap arches over the back from end to end, nailed at both.
	var centers: Array[Vector3] = []
	var radii: Array[Vector2] = []
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-0.064, 0.064, t)
		centers.append(Vector3(x, 0.063 + sin(t * PI) * 0.018, 0))
		radii.append(Vector2(0.021, 0.0022))
	mb.loft_ellipse(&"cloth", centers, radii, 10, Color(0.34, 0.2, 0.11))
	for x: float in [-0.064, 0.064]:
		mb.cylinder(&"steel", Transform3D(Basis(), Vector3(x, 0.062, 0)), 0.004, 0.004, 0.004, 8, STEEL_EDGE.darkened(0.3))
	# Fibre tufts packed across the underside, splaying a little toward the tips.
	var step := 0.0082
	for r in range(-4, 5):
		var z := r * step * 0.87
		var half := 0.077 * sqrt(maxf(1.0 - pow(z / 0.031, 2.0), 0.0))
		var shift := step * 0.5 if r % 2 != 0 else 0.0
		var x := -half + shift
		while x <= half:
			var root := Vector3(x, 0.035, z)
			var out := Vector3(x / 0.077, 0, z / 0.031) * 0.12
			var dir := (Vector3(out.x + rng.randf_range(-0.05, 0.05), -1.0, out.z + rng.randf_range(-0.05, 0.05))).normalized()
			var fibre := Color(0.64, 0.52, 0.35).lerp(Color(0.44, 0.34, 0.22), rng.randf_range(0.0, 0.7))
			mb.cylinder_between(&"cloth", root, root + dir * rng.randf_range(0.03, 0.034), 0.0046, 0.0038, 6, fibre, true, true)
			x += step


static func _pitchfork(mb: MeshBuilder) -> void:
	_handle(mb, [Vector3(0, -0.6, 0), Vector3(0, 0.2, 0), Vector3(0, 0.7, 0)], [0.019, 0.02, 0.019])
	mb.cylinder(&"steel", Transform3D(Basis(), Vector3(0, 0.66, 0)), 0.024, 0.022, 0.08, 10, STEEL)
	mb.loft(&"steel", [Vector3(-0.1, 0.76, 0), Vector3(0, 0.745, 0), Vector3(0.1, 0.76, 0)], [0.009, 0.012, 0.009], 8, STEEL)
	for i in 4:
		var x := -0.09 + i * 0.06
		mb.loft(&"steel", [Vector3(x, 0.755, 0), Vector3(x * 1.05, 0.9, 0.012), Vector3(x * 1.08, 1.05, 0.035), Vector3(x * 1.1, 1.14, 0.06)],
				[0.007, 0.0065, 0.005, 0.0015], 6, STEEL)


# --- Crops -----------------------------------------------------------------------

static func _wheat(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var grain := CROP_COLORS[&"wheat"]
	for s in 9:
		var base := Vector3(rng.randf_range(-0.012, 0.012), -0.17, rng.randf_range(-0.012, 0.012))
		var lean := Vector3(rng.randf_range(-0.07, 0.07), 0, rng.randf_range(-0.07, 0.07))
		var top := base + Vector3(0, 0.34, 0) + lean
		mb.cylinder_between(&"veg", base, top, 0.0028, 0.0022, 5, grain.darkened(0.15), true, false)
		var dir := (top - base).normalized()
		var side := dir.cross(Vector3.RIGHT).normalized()
		for g in 16:
			var t := float(g) / 16.0
			var p := top - dir * 0.075 + dir * (t * 0.08)
			var around := side.rotated(dir, g * PI * 0.5)
			var gxf := Transform3D(ItemModels._basis_from_dir((dir + around * 0.7).normalized()), p + around * 0.0035)
			mb.sphere(&"veg", gxf, Vector3(0.0034, 0.0068, 0.0034), 6, 4, grain.lightened(rng.randf_range(-0.05, 0.08)))
			mb.cylinder_between(&"veg", p + around * 0.004, p + (dir * 0.85 + around * 0.5).normalized() * 0.045, 0.0005, 0.0002, 3, grain.lightened(0.1), false, false)
	var twine: Array[Vector3] = []
	var twine_r: Array[float] = []
	for i in 17:
		var a := TAU * float(i) / 16.0
		twine.append(Vector3(cos(a) * 0.022, -0.06, sin(a) * 0.022))
		twine_r.append(0.0032)
	mb.loft(&"cloth", twine, twine_r, 6, Color(0.55, 0.38, 0.22), false)


static func _carrot(mb: MeshBuilder) -> void:
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 14:
		var t := float(i) / 13.0
		pts.append(Vector3(sin(t * 1.3) * 0.014, 0.09 - t * 0.19, 0))
		radii.append(lerpf(0.022, 0.0015, pow(t, 1.25)) * (1.0 + 0.05 * sin(t * 47.0)))
	mb.loft(&"veg", pts, radii, 16, CROP_COLORS[&"carrot"])
	mb.disc(&"veg", Transform3D(Basis(), Vector3(0, 0.0905, 0)), 0.02, 16, Color(0.72, 0.4, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf() * 0.4
		var tip := Vector3(cos(a) * 0.025, 0.16 + rng.randf() * 0.03, sin(a) * 0.025)
		mb.loft(&"veg", [Vector3(0, 0.088, 0), Vector3(cos(a) * 0.008, 0.12, sin(a) * 0.008), tip], [0.003, 0.0025, 0.0015], 5, LEAF_GREEN, false)
		for j in 4:
			var p := Vector3(0, 0.088, 0).lerp(tip, 0.45 + j * 0.15)
			var d := Vector3(cos(a + (j % 2 - 0.5) * 1.8), 0.6, sin(a + (j % 2 - 0.5) * 1.8)).normalized()
			mb.leaf(&"veg", p, d, Vector3.UP, 0.028, 0.012, LEAF_GREEN.lightened(0.08), LEAF_GREEN, 0.004, true)


static func _potato(mb: MeshBuilder) -> void:
	var xf := Transform3D(Basis.from_scale(Vector3(1.25, 0.82, 0.95)), Vector3.ZERO)
	mb.blob(&"veg_rough", xf, 0.045, 3, CROP_COLORS[&"potato"], 0.2, 1.9, 21, 0.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 6:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var p := xf * (d * 0.043)
		mb.sphere(&"veg", Transform3D(Basis(), p), Vector3(0.0035, 0.0025, 0.0035), 6, 4, Color(0.42, 0.3, 0.18))


static func _tomato(mb: MeshBuilder) -> void:
	var col: Color = CROP_COLORS[&"tomato"]
	mb.sphere(&"veg_gloss", Transform3D.IDENTITY, Vector3(0.043, 0.035, 0.043), 28, 18, col)
	for k in 5:
		var a := TAU * k / 5.0
		var d := Vector3(cos(a), 0.15, sin(a))
		mb.leaf(&"veg", Vector3(0, 0.034, 0), d, Vector3.UP, 0.03, 0.011, LEAF_GREEN, LEAF_GREEN.darkened(0.1), 0.006, true)
	mb.loft(&"veg", [Vector3(0, 0.032, 0), Vector3(0.002, 0.045, 0), Vector3(0.008, 0.052, 0)], [0.0035, 0.003, 0.0028], 6, LEAF_GREEN)


static func _corn(mb: MeshBuilder) -> void:
	var col: Color = CROP_COLORS[&"corn"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rows := 16
	var around := 14
	for r in rows:
		var t := (float(r) + 0.5) / rows
		var y := lerpf(-0.075, 0.075, t)
		var radius := 0.025 * sqrt(maxf(1.0 - pow(abs(t - 0.45) / 0.58, 3.0), 0.05))
		for k in around:
			var a := TAU * (k + (r % 2) * 0.5) / around
			var dir := Vector3(cos(a), 0, sin(a))
			var xf := Transform3D(ItemModels._basis_from_dir(dir), dir * radius + Vector3(0, y, 0))
			mb.sphere(&"veg_gloss", xf, Vector3(0.0058, 0.0048, 0.005), 6, 4, col.lightened(rng.randf_range(-0.06, 0.06)))
	mb.loft(&"veg", [Vector3(0, -0.09, 0), Vector3(0, -0.075, 0), Vector3(0, 0.07, 0)], [0.012, 0.02, 0.012], 12, Color(0.85, 0.75, 0.5))
	mb.cylinder_between(&"veg", Vector3(0, -0.12, 0), Vector3(0, -0.085, 0), 0.008, 0.011, 8, Color(0.55, 0.6, 0.3))
	for i in 3:
		var a := TAU * i / 3.0
		var husk: Array[Vector3] = [Vector3(cos(a) * 0.012, -0.09, sin(a) * 0.012), Vector3(cos(a) * 0.03, -0.05, sin(a) * 0.03),
				Vector3(cos(a) * 0.034, 0.0, sin(a) * 0.034), Vector3(cos(a) * 0.045, 0.05, sin(a) * 0.045)]
		mb.loft(&"veg", husk, [0.004, 0.009, 0.008, 0.002], 6, Color(0.5, 0.62, 0.28))
	for i in 7:
		var a := rng.randf() * TAU
		mb.cylinder_between(&"veg", Vector3(0, 0.078, 0), Vector3(cos(a) * 0.025, 0.11, sin(a) * 0.025), 0.001, 0.0006, 3, Color(0.78, 0.6, 0.35), false, false)


static func _eggplant(mb: MeshBuilder) -> void:
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 16:
		var t := float(i) / 15.0
		pts.append(Vector3(sin(t * 1.1) * 0.025, 0.1 - t * 0.2, 0))
		radii.append(0.011 + 0.03 * sin(pow(t, 0.7) * PI) * (0.85 + 0.15 * t))
	radii[15] = 0.006
	mb.loft(&"veg_gloss", pts, radii, 20, CROP_COLORS[&"eggplant"])
	for k in 5:
		var a := TAU * k / 5.0
		var d := Vector3(cos(a), -0.8, sin(a))
		mb.leaf(&"veg", Vector3(0, 0.1, 0), d, d.cross(Vector3(-sin(a), 0, cos(a))), 0.035, 0.014, LEAF_GREEN, LEAF_GREEN.darkened(0.15), 0.0, true)
	mb.loft(&"veg", [Vector3(0, 0.098, 0), Vector3(0.003, 0.12, 0), Vector3(0.012, 0.135, 0)], [0.006, 0.005, 0.0045], 8, LEAF_GREEN.darkened(0.1))


static func _strawberry(mb: MeshBuilder) -> void:
	var col: Color = CROP_COLORS[&"strawberry"]
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 12:
		var t := float(i) / 11.0
		pts.append(Vector3(0, 0.022 - t * 0.055, 0))
		radii.append(0.004 + 0.022 * sin(pow(t, 0.55) * PI) * (1.0 - t * 0.35))
	radii[11] = 0.002
	mb.loft(&"veg_gloss", pts, radii, 18, col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 36:
		var t := rng.randf_range(0.15, 0.9)
		var ring := int(t * 11.0)
		var a := rng.randf() * TAU
		var r: float = lerpf(radii[ring], radii[mini(ring + 1, 11)], fmod(t * 11.0, 1.0))
		var p := Vector3(cos(a) * r, lerpf(0.022, -0.033, t), sin(a) * r)
		mb.sphere(&"veg", Transform3D(Basis(), p), Vector3(0.0014, 0.0022, 0.0014), 5, 3, Color(0.95, 0.82, 0.35))
	for k in 7:
		var a := TAU * k / 7.0
		mb.leaf(&"veg", Vector3(0, 0.022, 0), Vector3(cos(a), 0.2, sin(a)), Vector3.UP, 0.022, 0.009, LEAF_GREEN, LEAF_GREEN.lightened(0.1), 0.004, true)
	mb.loft(&"veg", [Vector3(0, 0.02, 0), Vector3(0.002, 0.035, 0), Vector3(0.006, 0.042, 0)], [0.0022, 0.002, 0.0018], 5, LEAF_GREEN)


static func _pumpkin(mb: MeshBuilder) -> void:
	var col: Color = CROP_COLORS[&"pumpkin"]
	var segs := 40
	var rings := 22
	var grid: Array[PackedVector3Array] = []
	for r in rings + 1:
		var v := PI * float(r) / rings
		var row := PackedVector3Array()
		for s in segs:
			var u := TAU * float(s) / segs
			var rib := 0.9 + 0.1 * pow(absf(cos(u * 4.0)), 0.6)
			var radius := 0.14 * rib
			var p := Vector3(sin(v) * cos(u) * radius, cos(v) * 0.105, sin(v) * sin(u) * radius)
			# Dimples at the stem and blossom ends.
			p.y -= signf(cos(v)) * 0.03 * pow(1.0 - sin(v), 3.0)
			row.append(p)
		grid.append(row)
	# Smooth normals from grid neighbors so the ribs shade softly.
	var normals: Array[PackedVector3Array] = []
	for r in rings + 1:
		var row := PackedVector3Array()
		for s in segs:
			var across := grid[r][(s + 1) % segs] - grid[r][(s - 1 + segs) % segs]
			var down := grid[mini(r + 1, rings)][s] - grid[maxi(r - 1, 0)][s]
			var n := across.cross(down).normalized()
			if n.dot(grid[r][s]) < 0.0:
				n = -n
			if r == 0 or r == rings:
				n = Vector3(0, signf(grid[r][s].y + 0.0001), 0)
			row.append(n)
		normals.append(row)
	var colors := PackedColorArray()
	for s in segs:
		colors.append(col.darkened(0.14 * (1.0 - pow(absf(cos(TAU * s / segs * 4.0)), 0.6))))
	for r in rings:
		for s in segs:
			var s1 := (s + 1) % segs
			# Rows run from the top pole down; (a, b, c) / (a, c, d) face outward.
			var a := grid[r][s]
			var b := grid[r][s1]
			var c := grid[r + 1][s1]
			var d := grid[r + 1][s]
			mb.tri_n(&"veg", a, b, c, normals[r][s], normals[r][s1], normals[r + 1][s1], colors[s], colors[s1], colors[s1])
			mb.tri_n(&"veg", a, c, d, normals[r][s], normals[r + 1][s1], normals[r + 1][s], colors[s], colors[s1], colors[s])
	mb.loft(&"veg", [Vector3(0, 0.08, 0), Vector3(0.004, 0.11, 0), Vector3(0.015, 0.135, 0.004), Vector3(0.028, 0.145, 0.01)],
			[0.014, 0.012, 0.01, 0.008], 8, Color(0.42, 0.45, 0.22))


# --- Resources -------------------------------------------------------------------

static func _logs(mb: MeshBuilder) -> void:
	var logs := [[Vector3(0, 0.07, -0.075), 0.072], [Vector3(0, 0.07, 0.075), 0.068], [Vector3(0.01, 0.195, 0), 0.066]]
	for entry in logs:
		var c: Vector3 = entry[0]
		var r: float = entry[1]
		var half := Vector3(0.19, 0, 0)
		mb.cylinder_between(&"bark", c - half, c + half, r, r * 0.97, 14, NEUTRAL, true, false)
		mb.disc(&"endgrain", Transform3D(Basis(Vector3.BACK, -PI * 0.5), c + half), r * 0.97, 14, Color.WHITE)
		mb.disc(&"endgrain", Transform3D(Basis(Vector3.BACK, PI * 0.5), c - half), r, 14, Color.WHITE)


static func _stone(mb: MeshBuilder, iron: bool) -> void:
	var tint := Color(0.26, 0.25, 0.25) if iron else Color(0.4, 0.4, 0.4)
	mb.blob(&"stone", Transform3D(Basis.from_scale(Vector3(1.2, 0.8, 1.0)), Vector3.ZERO), 0.075, 3, tint, 0.3, 2.2, 31 if iron else 17, 0.0, true, -0.35)
	if iron:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for i in 7:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 1.0), rng.randf_range(-1, 1)).normalized()
			var p := Vector3(d.x * 0.08, d.y * 0.052, d.z * 0.066)
			var c := Color(0.62, 0.34, 0.16) if i % 3 != 0 else Color(0.78, 0.78, 0.8)
			mb.blob(&"steel", Transform3D(Basis(), p), 0.012, 1, c, 0.3, 3.0, i)


static func _hay(mb: MeshBuilder) -> void:
	# A sheaf of dry straw tied in the middle, ends splayed.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 70:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.028
		var mid := Vector3(cos(a) * r, 0, sin(a) * r)
		var spread := Vector3(cos(a), 0, sin(a)) * (r * 1.6 + 0.01)
		var bottom := mid + Vector3(0, -0.16 + rng.randf_range(-0.02, 0.02), 0) + spread * 1.4
		var top := mid + Vector3(0, 0.16 + rng.randf_range(-0.02, 0.03), 0) + spread * 1.8
		var col := Color(0.8, 0.65, 0.33).lightened(rng.randf_range(-0.14, 0.1))
		mb.loft(&"veg", [bottom, mid, top], [0.0022, 0.0019, 0.0015], 4, col, false)
	var twine: Array[Vector3] = []
	var twine_r: Array[float] = []
	for i in 17:
		var a := TAU * float(i) / 16.0
		twine.append(Vector3(cos(a) * 0.033, 0, sin(a) * 0.033))
		twine_r.append(0.004)
	mb.loft(&"cloth", twine, twine_r, 6, Color(0.5, 0.33, 0.2), false)


# --- Animal products & supplies -----------------------------------------------------

static func _egg(mb: MeshBuilder) -> void:
	var rows: Array[Vector3] = []
	var radii: Array[Vector2] = []
	var n := 14
	for i in n + 1:
		var t := float(i) / n
		var y := lerpf(-0.029, 0.031, t)
		# Egg profile: fuller at the bottom, narrower toward the top.
		var r := 0.022 * sqrt(maxf(sin(t * PI), 0.0)) * (1.08 - 0.22 * t)
		rows.append(Vector3(0, y, 0))
		radii.append(Vector2(maxf(r, 0.0008), maxf(r, 0.0008)))
	var no_colors: Array[Color] = []
	mb.loft_ellipse(&"veg", rows, radii, 18, Color(0.86, 0.72, 0.55), no_colors, Vector3.FORWARD)


static func _milk(mb: MeshBuilder) -> void:
	var white := Color(0.96, 0.95, 0.92)
	mb.cylinder(&"veg_gloss", Transform3D.IDENTITY, 0.042, 0.042, 0.12, 20, white)
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), Vector3(0, 0.12, 0)), 0.042, 0.02, 0.05, 20, white)
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), Vector3(0, 0.17, 0)), 0.02, 0.02, 0.025, 16, white)
	mb.cylinder(&"paper", Transform3D(Basis(), Vector3(0, 0.19, 0)), 0.024, 0.024, 0.014, 16, Color(0.2, 0.42, 0.78))
	mb.ring(&"paper", Transform3D(Basis(), Vector3(0, 0.035, 0)), 0.0435, 0.041, 0.05, 20, Color(0.2, 0.42, 0.78))


## A shorn fleece rolled up: a flattened, lumpy mass of greasy cream locks.
static func _wool(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 16:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.075
		var p := Vector3(cos(a) * r, rng.randf_range(0.012, 0.045) * (1.0 - r / 0.1), sin(a) * r * 0.7)
		var col := Color(0.78, 0.74, 0.64).lerp(Color(0.68, 0.62, 0.5), rng.randf_range(0.0, 0.6))
		var squash := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(1.0, rng.randf_range(0.55, 0.75), 1.0))
		mb.blob(&"fleece", Transform3D(squash, p), rng.randf_range(0.028, 0.042), 2, col, 0.28, 3.4, i, 0.0, true)


static func _feed_sack(mb: MeshBuilder) -> void:
	var burlap := Color(0.66, 0.56, 0.4)
	mb.blob(&"cloth", Transform3D(Basis.from_scale(Vector3(1.0, 1.25, 0.8)), Vector3(0, 0.07, 0)), 0.07, 2, burlap, 0.12, 2.5, 3, 0.0, true, -0.5)
	mb.cylinder(&"cloth", Transform3D(Basis(), Vector3(0, 0.15, 0)), 0.03, 0.045, 0.04, 12, burlap.darkened(0.1))
	mb.ring(&"cloth", Transform3D(Basis(), Vector3(0, 0.148, 0)), 0.034, 0.028, 0.012, 12, Color(0.5, 0.33, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		var p := Vector3(rng.randf_range(-0.03, 0.03), 0.19, rng.randf_range(-0.03, 0.03))
		mb.sphere(&"veg", Transform3D(Basis(), p), Vector3(0.005, 0.004, 0.007), 5, 4, Color(0.9, 0.72, 0.3))
	mb.box_at(&"paper", Vector3(0, 0.08, 0.057), Vector3(0.07, 0.05, 0.002), Color(0.95, 0.92, 0.82))


# --- Live animals in crates ----------------------------------------------------------------

## Top of the straw inside a poultry crate (the hen sits on it).
const CRATE_FLOOR := 0.03
const CRATE_PINE := Color(0.6, 0.52, 0.4)


## A wooden poultry transport crate for one hen (0.5 x 0.26 x 0.36, the size of a bed
## package; bottom centre at the origin, long side along +X): a pine frame of corner
## posts and rails, closely set upright slats on every side so the bird shows between
## them, a board floor under a layer of straw, a slatted lid with a small hinged hatch
## and a wire latch, rope handles at the ends and a stencilled tin tag. Empty inside:
## the bed and the warehouse seat a live hen in it (CrateHen); the item adds a
## modelled one (hen_figure). Weathered by `rng`.
static func poultry_crate(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var l := 0.5
	var w := 0.36
	var h := 0.26
	var wood := CRATE_PINE.lightened(rng.randf_range(-0.07, 0.05))
	var dark := wood.darkened(0.2)
	var hl := l * 0.5
	var hw := w * 0.5
	# Floor boards on two runners, straw over them.
	for x: float in [-hl + 0.03, hl - 0.03]:
		mb.box_at(&"wood", Vector3(x, 0.009, 0), Vector3(0.04, 0.018, w - 0.01), dark)
	for k in 3:
		var bz := -hw + 0.065 + k * (w - 0.13) / 2.0
		mb.box_at(&"wood", Vector3(0, 0.022, bz), Vector3(l - 0.02, 0.012, 0.11), wood.darkened(rng.randf_range(0.02, 0.12)),
				Vector3(0, rng.randf_range(-0.6, 0.6), 0))
	mb.box_at(&"straw", Vector3(0, CRATE_FLOOR - 0.002, 0), Vector3(l - 0.05, 0.006, w - 0.05), Color(0.82, 0.7, 0.42))
	for i in 7:
		var tuft := Vector3(rng.randf_range(-hl + 0.05, hl - 0.05), CRATE_FLOOR + 0.002, rng.randf_range(-hw + 0.04, hw - 0.04))
		mb.box_at(&"straw", tuft, Vector3(rng.randf_range(0.05, 0.1), 0.008, rng.randf_range(0.02, 0.04)), Color(0.86, 0.74, 0.44),
				Vector3(rng.randf_range(-8, 8), rng.randf() * 180.0, 0))
	# Corner posts and the rails round the bottom and the top.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(sx * (hl - 0.016), h * 0.5, sz * (hw - 0.016)), Vector3(0.032, h, 0.032), dark, Vector3.ZERO, true)
	for y: float in [0.04, h - 0.024]:
		for s: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(0, y, s * (hw - 0.012)), Vector3(l - 0.03, 0.03, 0.022), wood)
			mb.box_at(&"wood", Vector3(s * (hl - 0.012), y, 0), Vector3(0.022, 0.03, w - 0.03), wood)
	# Upright slats: 0.016 wide with gaps of about 0.035.
	var slat_h := h - 0.07
	var slat_y := 0.04 + slat_h * 0.5 + 0.004
	for s: float in [-1.0, 1.0]:
		var n := 9
		for i in n:
			var x := -hl + 0.045 + i * (l - 0.09) / (n - 1)
			mb.box_at(&"wood", Vector3(x, slat_y, s * (hw - 0.008)), Vector3(0.016, slat_h, 0.009),
					wood.lightened(rng.randf_range(-0.06, 0.05)), Vector3(0, 0, rng.randf_range(-1.2, 1.2)), true)
		var m := 6
		for i in m:
			var z := -hw + 0.045 + i * (w - 0.09) / (m - 1)
			mb.box_at(&"wood", Vector3(s * (hl - 0.008), slat_y, z), Vector3(0.009, slat_h, 0.016),
					wood.lightened(rng.randf_range(-0.06, 0.05)), Vector3(rng.randf_range(-1.2, 1.2), 0, 0), true)
	# The lid: slats along X over the top rails, the middle two a hatch on wire hinges.
	var lid_y := h + 0.005
	for k in 5:
		var z := -hw + 0.03 + k * (w - 0.06) / 4.0
		var hatch := k == 1 or k == 2
		var slat_len := l * 0.46 if hatch else l - 0.01
		var x := -l * 0.25 if hatch else 0.0
		mb.box_at(&"wood", Vector3(x, lid_y, z), Vector3(slat_len, 0.012, 0.05), wood.lightened(rng.randf_range(-0.05, 0.06)),
				Vector3(0, rng.randf_range(-0.8, 0.8), 0))
	# Hatch: two slats on a cross batten, lifting at the +X end.
	var hatch_c := Vector3(l * 0.24, lid_y + 0.003, -hw + 0.03 + 1.5 * (w - 0.06) / 4.0)
	for k in 2:
		mb.box_at(&"wood", hatch_c + Vector3(0, 0, (k - 0.5) * (w - 0.06) / 4.0), Vector3(l * 0.44, 0.012, 0.05), wood.lightened(0.04))
	mb.box_at(&"wood", hatch_c + Vector3(0.08, 0.009, 0), Vector3(0.028, 0.008, 0.14), dark)
	for k in 2:
		mb.ring(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hatch_c + Vector3(-l * 0.22, 0.004, (k - 0.5) * 0.08)),
				0.007, 0.005, 0.006, 8, Color(0.45, 0.44, 0.42))
	mb.cylinder_between(&"metal", hatch_c + Vector3(l * 0.21, 0.008, -0.015), hatch_c + Vector3(l * 0.23, -0.02, -0.015),
			0.0016, 0.0016, 5, Color(0.5, 0.49, 0.47))
	# Rope handles through the end rails.
	for s: float in [-1.0, 1.0]:
		var pts: Array[Vector3] = []
		var radii: Array[float] = []
		for i in 9:
			var a := PI * float(i) / 8.0
			pts.append(Vector3(s * (hl + 0.004 + sin(a) * 0.026), h - 0.03 - sin(a) * 0.012, -0.055 + (1.0 - cos(a)) * 0.055))
			radii.append(0.0055)
		mb.loft(&"cloth", pts, radii, 6, Color(0.62, 0.5, 0.32), true)
	# A tin tag nailed to one side, its stencil worn.
	mb.box_at(&"metal", Vector3(-0.12, h * 0.5, hw + 0.006), Vector3(0.07, 0.04, 0.002), Color(0.62, 0.6, 0.55))
	mb.box_at(&"paint_in", Vector3(-0.12, h * 0.5, hw + 0.0072), Vector3(0.05, 0.012, 0.0006), Color(0.62, 0.14, 0.1))
	# Droppings and a feather on the straw: the crate has been used.
	for i in 3:
		var dp := Vector3(rng.randf_range(-0.18, 0.18), CRATE_FLOOR + 0.004, rng.randf_range(-0.12, 0.12))
		mb.sphere(&"veg_rough", Transform3D(Basis(), dp), Vector3(0.008, 0.004, 0.007), 6, 3, Color(0.34, 0.3, 0.22))
	mb.box_at(&"cloth", Vector3(0.16, CRATE_FLOOR + 0.003, -0.1), Vector3(0.05, 0.002, 0.012), Color(0.9, 0.88, 0.82), Vector3(0, 35, 6))


## A sitting hen, modelled (items, icons and pickups; the bed and the warehouse use the
## live rig): body along +X, head at +X, standing on the origin of `xf`.
static func hen_figure(mb: MeshBuilder, xf: Transform3D) -> void:
	var coat := Color(0.62, 0.3, 0.12)
	var wing := coat.darkened(0.2)
	var red := Color(0.72, 0.08, 0.06)
	# Body: a broad teardrop settled on the straw, breast forward, a lifted tail.
	mb.sphere(&"feather", xf * Transform3D(Basis(Vector3.BACK, 0.12), Vector3(-0.01, 0.075, 0)), Vector3(0.12, 0.075, 0.085), 16, 10, coat)
	mb.sphere(&"feather", xf * Transform3D(Basis(), Vector3(0.065, 0.088, 0)), Vector3(0.06, 0.065, 0.066), 12, 8, coat.lightened(0.05))
	for s: float in [-1.0, 1.0]:
		mb.sphere(&"feather", xf * Transform3D(Basis(Vector3.BACK, 0.18) * Basis(Vector3.UP, s * 0.12), Vector3(-0.02, 0.09, s * 0.066)),
				Vector3(0.095, 0.046, 0.024), 12, 6, wing)
	mb.sphere(&"feather", xf * Transform3D(Basis(Vector3.BACK, 0.9), Vector3(-0.11, 0.13, 0)), Vector3(0.055, 0.032, 0.028), 10, 6, wing.darkened(0.1))
	mb.sphere(&"feather", xf * Transform3D(Basis(Vector3.BACK, 0.6), Vector3(-0.095, 0.115, 0)), Vector3(0.05, 0.028, 0.042), 10, 6, coat)
	# Neck up to the head.
	var neck: Array[Vector3] = [xf * Vector3(0.065, 0.11, 0), xf * Vector3(0.09, 0.14, 0), xf * Vector3(0.105, 0.16, 0)]
	var neck_r: Array[float] = [0.042, 0.032, 0.026]
	mb.loft(&"feather", neck, neck_r, 10, coat.lightened(0.08), false)
	var head := xf * Vector3(0.115, 0.172, 0)
	mb.sphere(&"feather", Transform3D(xf.basis, head), Vector3(0.032, 0.028, 0.026), 10, 7, coat.lightened(0.1))
	# Comb, wattles, beak and eyes.
	for k in 4:
		mb.sphere(&"veg", Transform3D(xf.basis, head + xf.basis * Vector3(0.016 - k * 0.011, 0.027 + (0.004 if k % 2 == 0 else 0.0), 0)),
				Vector3(0.008, 0.012, 0.004), 6, 4, red)
	mb.sphere(&"veg", Transform3D(xf.basis, head + xf.basis * Vector3(0.026, -0.026, 0)), Vector3(0.007, 0.012, 0.006), 6, 4, red)
	mb.cylinder(&"hoof", Transform3D(xf.basis * Basis(Vector3.BACK, -PI * 0.5), head + xf.basis * Vector3(0.028, -0.004, 0)),
			0.0085, 0.0, 0.021, 8, Color(0.85, 0.66, 0.3))
	for s: float in [-1.0, 1.0]:
		mb.sphere(&"eye", Transform3D(xf.basis, head + xf.basis * Vector3(0.013, 0.007, s * 0.022)), Vector3.ONE * 0.005, 6, 4, Color.BLACK)
		mb.sphere(&"veg", Transform3D(xf.basis, head + xf.basis * Vector3(0.011, -0.004, s * 0.02)), Vector3(0.006, 0.008, 0.003), 6, 4, red.lightened(0.1))


## Grandpa's pickup key, lying flat: a worn brass key with a round bow, the blade cut
## on one edge, on a steel split ring with a stitched leather fob and a brass rivet.
static func _truck_key(mb: MeshBuilder) -> void:
	var brass := Color(0.74, 0.58, 0.3)
	var steel := Color(0.62, 0.62, 0.6)
	var leather := Color(0.32, 0.19, 0.1)
	var t := 0.0032
	# Bow with its hole, a shoulder and the blade along +X.
	mb.ring(&"metal", Transform3D(Basis(), Vector3(0, 0, 0)), 0.0155, 0.0052, t, 20, brass)
	mb.box_at(&"metal", Vector3(0.019, t * 0.5, 0), Vector3(0.01, t, 0.013), brass.darkened(0.05))
	mb.box_at(&"metal", Vector3(0.024, t * 0.5, 0), Vector3(0.004, t * 1.3, 0.016), brass.darkened(0.1))
	mb.box_at(&"metal", Vector3(0.049, t * 0.5, 0.0015), Vector3(0.046, t, 0.0085), brass)
	mb.box_at(&"metal", Vector3(0.048, t + 0.0002, 0.002), Vector3(0.04, 0.0006, 0.0018), brass.darkened(0.3))
	mb.box_at(&"metal", Vector3(0.0735, t * 0.5, 0.0008), Vector3(0.006, t, 0.006), brass, Vector3(0, 45, 0))
	# The bitting: five cuts of different depths on the -Z edge.
	var depths := [0.0035, 0.0055, 0.003, 0.005, 0.0042]
	for k in 5:
		var d: float = depths[k]
		mb.box_at(&"metal", Vector3(0.032 + k * 0.0085, t * 0.5, -0.0028 - d * 0.5), Vector3(0.0055, t, d), brass.darkened(0.04), Vector3(0, 0, 0))
	# Split ring through the bow.
	mb.ring(&"metal", Transform3D(Basis(Vector3.BACK, 0.08), Vector3(-0.012, 0.0006, 0)), 0.0135, 0.0115, 0.0018, 18, steel)
	# Leather fob: a strap folded round the ring and riveted, then the tag.
	var fob := Vector3(-0.06, 0.0, 0)
	mb.box_at(&"cloth", Vector3(-0.03, 0.0035, 0), Vector3(0.018, 0.005, 0.011), leather.lightened(0.06))
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(-0.031, 0.0055, 0)), 0.0032, 0.0028, 0.0014, 10, brass.darkened(0.08))
	mb.box_at(&"cloth", fob + Vector3(0, 0.0022, 0), Vector3(0.05, 0.0044, 0.027), leather)
	mb.cylinder(&"cloth", Transform3D(Basis(), fob + Vector3(-0.025, 0, 0)), 0.0135, 0.0135, 0.0044, 16, leather)
	# Stitching round the edge and a worn patch where the thumb rubs it.
	for s: float in [-1.0, 1.0]:
		mb.box_at(&"cloth", fob + Vector3(-0.002, 0.0046, s * 0.0105), Vector3(0.05, 0.0005, 0.0012), Color(0.72, 0.62, 0.44))
	mb.box_at(&"cloth", fob + Vector3(-0.008, 0.0046, 0), Vector3(0.022, 0.0003, 0.012), leather.lightened(0.18))
	mb.ring(&"metal", Transform3D(Basis(), fob + Vector3(-0.026, 0.0002, 0)), 0.0045, 0.0028, 0.0048, 10, brass.darkened(0.1))


# --- Artisan goods and supplies ----------------------------------------------------------

## A wheel of farm cheese with a wedge cut from it lying alongside, showing the paste.
static func _cheese(mb: MeshBuilder) -> void:
	var rind := Color(0.78, 0.52, 0.18)
	var paste := Color(0.95, 0.84, 0.5)
	mb.cylinder(&"veg", Transform3D.IDENTITY, 0.11, 0.11, 0.09, 32, rind)
	mb.ring(&"veg", Transform3D(Basis(), Vector3(0, 0.086, 0)), 0.112, 0.1, 0.006, 32, rind.darkened(0.12))
	# The wedge: a prism of paste with rind on its round back.
	var wedge := Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.1, 0.0, 0.1))
	mb.prism(&"veg", wedge, 0.09, 0.11, 0.09, paste)
	mb.box(&"veg", wedge * Transform3D(Basis(), Vector3(0, 0.113, 0)), Vector3(0.095, 0.008, 0.09), rind)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 4:
		var hole := wedge * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(rng.randf_range(-0.015, 0.015), rng.randf_range(0.03, 0.08), 0.0455))
		mb.disc(&"veg", hole, 0.006, 8, paste.darkened(0.3))


## A ball of natural wool yarn: a fuzzy core wound with strands at many angles and a
## loose end.
static func _yarn(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var wool := Color(0.74, 0.64, 0.5)
	var r := 0.065
	mb.sphere(&"cloth", Transform3D(Basis(), Vector3(0, r, 0)), Vector3.ONE * (r - 0.006), 18, 12, wool.darkened(0.12))
	for k in 14:
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var b := Basis(axis, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0, PI))
		var pts: Array[Vector3] = []
		var radii: Array[float] = []
		for i in 25:
			var a := TAU * float(i) / 24.0
			pts.append(Vector3(0, r, 0) + b * Vector3(cos(a) * r, 0, sin(a) * r))
			radii.append(0.0045)
		mb.loft(&"cloth", pts, radii, 5, wool.lightened(rng.randf_range(-0.05, 0.06)), false)
	var end_pts: Array[Vector3] = [Vector3(0.045, 0.03, 0.045), Vector3(0.07, 0.01, 0.06), Vector3(0.1, 0.004, 0.06), Vector3(0.13, 0.004, 0.045)]
	var end_r: Array[float] = [0.0045, 0.0045, 0.0042, 0.004]
	mb.loft(&"cloth", end_pts, end_r, 5, wool, false)


## A jar of preserves: the filled glass (contents seen through it), the empty neck,
## and a lid (metal, or a checked cloth tied with twine for jam) and a paper label.
static func _jar(mb: MeshBuilder, kind: String) -> void:
	var r := 0.045
	var h := 0.11
	var fill := h - 0.022
	match kind:
		"pickles":
			mb.cylinder(&"veg_gloss", Transform3D.IDENTITY, r, r, fill, 20, Color(0.62, 0.62, 0.22), true, true)
			var rng := RandomNumberGenerator.new()
			rng.seed = 12
			for i in 14:
				var a := rng.randf() * TAU
				var p := Vector3(cos(a) * (r - 0.004), rng.randf_range(0.012, fill - 0.012), sin(a) * (r - 0.004))
				if i % 2 == 0:
					mb.cylinder_between(&"veg", p, p + Vector3(0, 0.03, 0), 0.008, 0.006, 8, CROP_COLORS[&"carrot"])
				else:
					mb.sphere(&"veg", Transform3D(Basis(), p), Vector3(0.011, 0.011, 0.004), 8, 5, Color(0.78, 0.8, 0.52))
		"jam":
			mb.cylinder(&"veg_gloss", Transform3D.IDENTITY, r, r, fill, 20, Color(0.36, 0.02, 0.06))
		_:
			mb.cylinder(&"veg_gloss", Transform3D.IDENTITY, r, r, fill, 20, Color(0.5, 0.04, 0.02))
	mb.cylinder(&"glass", Transform3D(Basis(), Vector3(0, fill, 0)), r, r * 0.88, h - fill, 20, Color(0.85, 0.92, 0.95), true, false)
	if kind == "jam":
		mb.cylinder(&"cloth", Transform3D(Basis(), Vector3(0, h - 0.004, 0)), r * 1.28, r * 0.92, 0.022, 16, Color(0.78, 0.16, 0.14))
		mb.disc(&"cloth", Transform3D(Basis(), Vector3(0, h + 0.018, 0)), r * 0.92, 16, Color(0.95, 0.93, 0.88))
		mb.ring(&"cloth", Transform3D(Basis(), Vector3(0, h - 0.008, 0)), r * 0.96, r * 0.9, 0.006, 16, Color(0.6, 0.45, 0.28))
	else:
		mb.cylinder(&"metal", Transform3D(Basis(), Vector3(0, h, 0)), r * 0.92, r * 0.92, 0.016, 20,
				Color(0.78, 0.66, 0.34) if kind == "pickles" else Color(0.75, 0.2, 0.15))
	mb.ring(&"paper", Transform3D(Basis(), Vector3(0, 0.03, 0)), r + 0.0012, r + 0.0002, 0.032, 20, Color(0.94, 0.9, 0.78))


## A filled sack: paper (flour), plastic (fertilizer) or burlap with manure showing at
## the open top. `band` is the printed band (transparent for none).
static func _sack(mb: MeshBuilder, color: Color, band: Color, mat: StringName, open_top: bool) -> void:
	mb.blob(mat, Transform3D(Basis.from_scale(Vector3(1.0, 1.3, 0.7)), Vector3(0, 0.085, 0)), 0.075, 2, color, 0.1, 2.5, 5, 0.0, true, -0.55)
	if band.a > 0.0:
		mb.box_at(&"paper", Vector3(0, 0.09, 0.052), Vector3(0.1, 0.05, 0.004), band)
	if open_top:
		mb.ring(mat, Transform3D(Basis(), Vector3(0, 0.16, 0)), 0.05, 0.042, 0.03, 12, color.darkened(0.1))
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		for i in 5:
			var p := Vector3(rng.randf_range(-0.025, 0.025), 0.18, rng.randf_range(-0.02, 0.02))
			mb.blob(&"veg_rough", Transform3D(Basis(), p), 0.022, 1, Color(0.22, 0.15, 0.1), 0.3, 3.0, i, 0.1)
	else:
		mb.cylinder(mat, Transform3D(Basis(), Vector3(0, 0.165, 0)), 0.03, 0.045, 0.03, 12, color.darkened(0.08))
		mb.box_at(mat, Vector3(0, 0.2, 0), Vector3(0.1, 0.03, 0.012), color.darkened(0.05))


## A 3 kg bag of dog food (Zeynep's errands, SideStory): a gusseted plastic bag standing
## on its broad foot, narrowing to a crimped heat seal at the top, printed front and back
## (art/textures/items/dog_food_print.png, tools/make_item_prints.py: the front on the
## left half, the back on the right), plain red on the gussets.
## A dog's rubber ball, 7 cm: glossy red with a cream band round it, a little scuffed.
static func _dog_ball(mb: MeshBuilder) -> void:
	var r := 0.034
	mb.sphere(&"veg_gloss", Transform3D.IDENTITY, Vector3(r, r, r), 22, 14, Color(0.72, 0.1, 0.07))
	mb.ring(&"veg_gloss", Transform3D(Basis(Vector3.FORWARD, 0.35), Vector3(0, -0.0045, 0).rotated(Vector3.FORWARD, 0.35)),
			r + 0.0006, r - 0.004, 0.009, 22, Color(0.9, 0.86, 0.76))


static func _dog_food(mb: MeshBuilder) -> void:
	var w := 0.22
	var h := 0.3
	var d := 0.09
	var top := 0.012
	var red := Color(0.62, 0.2, 0.13)
	var hw := w * 0.5
	var p: Array[Vector3] = [Vector3(-hw, 0, -d * 0.5), Vector3(hw, 0, -d * 0.5), Vector3(hw * 0.98, h, -top),
		Vector3(-hw * 0.98, h, -top), Vector3(-hw, 0, d * 0.5), Vector3(hw, 0, d * 0.5), Vector3(hw * 0.98, h, top),
		Vector3(-hw * 0.98, h, top)]
	mb.hexa(&"veg_gloss", p, red)
	# The printed faces a hair off the bag, front (+Z) and back (-Z).
	var n_front := (p[5] - p[4]).cross(p[7] - p[4]).normalized() * 0.0015
	mb.quad(&"print", p[4] + n_front, p[5] + n_front, p[6] + n_front, p[7] + n_front, Color.WHITE,
			Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(0.5, 0.0), Vector2(0.0, 0.0))
	var n_back := (p[0] - p[1]).cross(p[2] - p[1]).normalized() * 0.0015
	mb.quad(&"print", p[1] + n_back, p[0] + n_back, p[3] + n_back, p[2] + n_back, Color.WHITE,
			Vector2(0.5, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.5, 0.0))
	# The crimped seal along the top, and a carry hole punched through it.
	mb.box_at(&"veg_gloss", Vector3(0, h + 0.014, 0), Vector3(w * 0.98, 0.03, 0.006), red.darkened(0.12))
	for k in 14:
		var x := -hw * 0.92 + k * (w * 0.92 / 13.0)
		mb.box_at(&"veg_gloss", Vector3(x, h + 0.014, 0.0033), Vector3(0.0015, 0.024, 0.0015), red.darkened(0.16))
	mb.box_at(&"veg_gloss", Vector3(0, h + 0.017, 0), Vector3(0.042, 0.009, 0.0075), red.darkened(0.6))


## The printed face of a packaged item (art/textures/items/<file>.png).
## A bunch of field flowers (daisies, poppies, cornflowers, buttercups) in a cone of kraft
## paper tied with a red ribbon, standing on its narrow end.
static func _bouquet(mb: MeshBuilder) -> void:
	var paper := Color(0.72, 0.58, 0.4)
	mb.cylinder(&"paper", Transform3D.IDENTITY, 0.022, 0.085, 0.24, 18, paper, true, false)
	mb.cylinder(&"paper", Transform3D(Basis(), Vector3(0, 0.002, 0)), 0.02, 0.08, 0.232, 18, paper.darkened(0.12), true, false)
	mb.ring(&"cloth", Transform3D(Basis(), Vector3(0, 0.07, 0)), 0.042, 0.038, 0.018, 18, Color(0.72, 0.1, 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var looks: Array[Color] = [Color(0.95, 0.94, 0.9), Color(0.82, 0.12, 0.08), Color(0.3, 0.4, 0.85),
		Color(0.96, 0.8, 0.2), Color(0.95, 0.94, 0.9), Color(0.8, 0.45, 0.75)]
	for i in 16:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.07
		var top := Vector3(cos(a) * r, rng.randf_range(0.27, 0.34), sin(a) * r)
		mb.cylinder_between(&"veg", Vector3(top.x * 0.2, 0.04, top.z * 0.2), top, 0.0025, 0.002, 5, LEAF_GREEN, true, false)
		var col: Color = looks[i % looks.size()]
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		# A flat open blossom with a darker heart.
		mb.sphere(&"veg", Transform3D(tilt, top), Vector3(0.019, 0.007, 0.019), 10, 5, col)
		mb.sphere(&"veg", Transform3D(tilt, top + tilt.y * 0.005), Vector3(0.006, 0.004, 0.006), 8, 4,
				Color(0.95, 0.75, 0.15) if col.b < 0.5 or col.r > 0.9 else Color(0.15, 0.12, 0.1))
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var base := Vector3(cos(a) * 0.03, 0.2, sin(a) * 0.03)
		mb.leaf(&"veg", base, Vector3(cos(a) * 0.5, 1.0, sin(a) * 0.5), Vector3(cos(a), 0, sin(a)), 0.11, 0.022,
				LEAF_GREEN, LEAF_GREEN.lightened(0.15), 0.3, true)


static func _print_material(file: String) -> Material:
	var m := StandardMaterial3D.new()
	var path := "res://art/textures/items/%s.png" % file
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.roughness = 0.42
	m.metallic_specular = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _medicine(mb: MeshBuilder) -> void:
	var glass := Color(0.4, 0.2, 0.08)
	mb.cylinder(&"veg_gloss", Transform3D.IDENTITY, 0.032, 0.032, 0.08, 18, glass)
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), Vector3(0, 0.08, 0)), 0.032, 0.014, 0.025, 18, glass)
	mb.cylinder(&"wood", Transform3D(Basis(), Vector3(0, 0.103, 0)), 0.015, 0.016, 0.022, 12, Color(0.6, 0.48, 0.34))
	mb.ring(&"paper", Transform3D(Basis(), Vector3(0, 0.02, 0)), 0.0325, 0.0315, 0.042, 18, Color(0.97, 0.96, 0.92))
	mb.box_at(&"paper", Vector3(0, 0.041, 0.034), Vector3(0.024, 0.008, 0.002), Color(0.85, 0.12, 0.1))
	mb.box_at(&"paper", Vector3(0, 0.041, 0.034), Vector3(0.008, 0.024, 0.002), Color(0.85, 0.12, 0.1))


# --- Seeds -------------------------------------------------------------------------

static func _seed_packet(mb: MeshBuilder, crop: StringName) -> void:
	var band: Color = CROP_COLORS.get(crop, Color(0.5, 0.5, 0.5))
	mb.box_at(&"paper", Vector3(0, 0, 0), Vector3(0.09, 0.13, 0.012), Color(0.85, 0.76, 0.58))
	mb.box_at(&"paper", Vector3(0, 0.071, 0), Vector3(0.092, 0.014, 0.014), Color(0.74, 0.64, 0.46))
	mb.box_at(&"paper", Vector3(0, -0.052, 0.0005), Vector3(0.091, 0.022, 0.0125), band)
	mb.box_at(&"paper", Vector3(0, 0.012, 0.0063), Vector3(0.074, 0.074, 0.001), Color(0.97, 0.95, 0.9))
	var z := 0.0069
	mb.quad(&"label", Vector3(-0.034, -0.022, z), Vector3(0.034, -0.022, z), Vector3(0.034, 0.046, z), Vector3(-0.034, 0.046, z),
			Color.WHITE, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))


static func _label_material(crop: StringName) -> Material:
	var m := StandardMaterial3D.new()
	var path := "res://art/icons/items/%s.png" % crop
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	elif FileAccess.file_exists(path):
		# Freshly rendered by the icon studio and not imported yet.
		m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.3
	m.roughness = 0.8
	return m


static func _basis_from_dir(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y).normalized())
