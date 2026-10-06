@tool
class_name FenceModels
extends RefCounted
## The farmer's own fencing (PlaceableTable "fence_panel", "fence_gate", "lantern_post"):
## post-and-rail panels in the same weathered split wood as the farm's old fences (Fence:
## the "fence_wood" material, hewn seven-sided posts, five-sided rails), a boarded gate
## on two sturdier posts and a tall post with an oil lantern hanging from its arm.
## Pieces run along their own X from end A (-X) to end B (+X), standing on the ground at
## the origin; a panel on a slope has its ends at different heights (`rise`: B over A)
## and its posts upright all the same. Posts shared with a neighbour are left out by one
## of the two (FencePiece asks Pastures which ends are its own).

## A panel's usual length and the lengths the last one of a run may take to close a gap.
const PANEL := 2.0
const PANEL_MIN := 1.1
const PANEL_MAX := 2.7
## Heights (m): the rails' top, a panel's posts, a gate's posts, the lantern post and
## where its lantern hangs (the flame, model frame).
const RAIL_TOP := 1.02
const POST := 1.18
const GATE_POST := 1.42
const LANTERN_POST := 2.35
const LANTERN_FLAME := Vector3(0.34, 1.86, 0.0)
const WOOD := Color(0.52, 0.5, 0.48)
const WOOD_DARK := Color(0.42, 0.4, 0.38)
const IRON := Color(0.16, 0.16, 0.17)

static var _cache := {}


## A panel `length` m long whose end B stands `rise` m higher than end A (the node's
## origin at the middle, at the mean of the two), with the posts asked for.
static func panel(length: float, rise: float, post_a: bool, post_b: bool, seed_value: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := Vector3(-length * 0.5, -rise * 0.5, 0.0)
	var b := Vector3(length * 0.5, rise * 0.5, 0.0)
	if post_a:
		post(mb, a, POST, 0.14, _seed_at(seed_value, 0))
	if post_b:
		post(mb, b, POST, 0.14, _seed_at(seed_value, 1))
	for y: float in [RAIL_TOP * 0.42, RAIL_TOP * 0.9]:
		_rail(mb, a + Vector3(0, y, 0), b + Vector3(0, y, 0), rng)
	return mb.build()


## A gate's two posts (sturdier and taller than a panel's, with a cap), `length` apart.
static func gate_posts(length: float, rise: float, seed_value: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var a := Vector3(-length * 0.5, -rise * 0.5, 0.0)
	var b := Vector3(length * 0.5, rise * 0.5, 0.0)
	for i in 2:
		var at := a if i == 0 else b
		post(mb, at, GATE_POST, 0.19, _seed_at(seed_value, i), 1.0)
		mb.box_at(&"fence_wood", at + Vector3(0, GATE_POST + 0.06, 0), Vector3(0.2, 0.035, 0.2), WOOD_DARK)
	# Two iron hinge straps on the hinge post (A) and the latch's keep on the other.
	for y: float in [0.34, 0.92]:
		mb.box_at(&"metal", a + Vector3(0.1, y, 0.0), Vector3(0.1, 0.035, 0.05), IRON)
	mb.box_at(&"metal", b + Vector3(-0.1, 0.78, 0.0), Vector3(0.06, 0.07, 0.07), IRON)
	return mb.build()


## A gate's leaf, hinged at its origin and reaching out along +X: three rails between two
## stiles, a diagonal brace up from the hinge's foot and an iron latch at its free end.
static func gate_leaf(length: float) -> ArrayMesh:
	var key := "leaf/%d" % roundi(length * 100.0)
	if _cache.has(key):
		return _cache[key]
	var mb := MeshBuilder.new()
	var w := length - 0.34
	var x0 := 0.14
	var lo := 0.2
	var hi := 1.08
	for x: float in [x0, x0 + w]:
		mb.box_at(&"fence_wood", Vector3(x, (lo + hi) * 0.5, 0.0), Vector3(0.07, hi - lo, 0.045), WOOD.lightened(0.04))
	for i in 3:
		var y := lerpf(lo + 0.05, hi - 0.05, i / 2.0)
		mb.box_at(&"fence_wood", Vector3(x0 + w * 0.5, y, 0.012), Vector3(w + 0.07, 0.085, 0.03), WOOD.lerp(WOOD_DARK, 0.2 * i), Vector3.ZERO, false)
	# The brace: from the hinge side's foot up to the free end's top.
	var from := Vector3(x0 + 0.02, lo + 0.07, -0.014)
	var to := Vector3(x0 + w - 0.02, hi - 0.07, -0.014)
	var d := to - from
	mb.box(&"fence_wood", Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x)), (from + to) * 0.5), Vector3(d.length(), 0.075, 0.028), WOOD_DARK)
	# The latch: a flat iron bar and its ring.
	mb.box_at(&"metal", Vector3(x0 + w + 0.02, 0.78, 0.03), Vector3(0.2, 0.03, 0.012), IRON)
	mb.ring(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x0 + w - 0.1, 0.7, 0.036)), 0.04, 0.03, 0.01, 10, IRON)
	var m := mb.build()
	_cache[key] = m
	return m


## The lantern post without its glow: a tall hewn post, a braced arm and the oil lantern
## hanging from it on a ring (an iron frame round glass, a domed cap, the font below).
static func lantern_body() -> ArrayMesh:
	if _cache.has("lantern"):
		return _cache["lantern"]
	var mb := MeshBuilder.new()
	post(mb, Vector3.ZERO, LANTERN_POST, 0.17, 77, 0.6)
	var top := LANTERN_POST - 0.16
	mb.box_at(&"fence_wood", Vector3(0.2, top, 0.0), Vector3(0.52, 0.07, 0.07), WOOD_DARK)
	var from := Vector3(0.03, top - 0.34, 0.0)
	var to := Vector3(0.36, top - 0.03, 0.0)
	var d := to - from
	mb.box(&"fence_wood", Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x)), (from + to) * 0.5), Vector3(d.length(), 0.05, 0.05), WOOD)
	var f := LANTERN_FLAME
	# The hook and the ring it hangs by.
	mb.cylinder_between(&"metal", Vector3(f.x, top - 0.035, 0.0), Vector3(f.x, f.y + 0.2, 0.0), 0.006, 0.006, 5, IRON)
	mb.ring(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(f.x, f.y + 0.17, 0.005)), 0.03, 0.022, 0.01, 10, IRON)
	# The cap, the cage's four rods and the font (the oil) with its burner.
	mb.cylinder(&"metal", Transform3D(Basis(), f + Vector3(0, 0.1, 0)), 0.075, 0.02, 0.05, 10, IRON.lightened(0.08))
	mb.cylinder(&"metal", Transform3D(Basis(), f + Vector3(0, 0.085, 0)), 0.08, 0.08, 0.016, 10, IRON)
	for i in 4:
		var ang := TAU * i / 4.0 + PI * 0.25
		var off := Vector3(cos(ang), 0.0, sin(ang)) * 0.066
		mb.cylinder_between(&"metal", f + off + Vector3(0, -0.1, 0), f + off + Vector3(0, 0.09, 0), 0.005, 0.005, 4, IRON)
	mb.cylinder(&"metal", Transform3D(Basis(), f + Vector3(0, -0.15, 0)), 0.07, 0.08, 0.055, 10, IRON.lightened(0.05))
	mb.cylinder(&"metal", Transform3D(Basis(), f + Vector3(0, -0.095, 0)), 0.03, 0.022, 0.03, 8, Color(0.5, 0.4, 0.2))
	mb.cylinder(&"glass", Transform3D(Basis(), f + Vector3(0, -0.095, 0)), 0.058, 0.058, 0.18, 10, Color.WHITE, true, false)
	var m := mb.build()
	_cache["lantern"] = m
	return m


## The lantern's flame (shown lit): a small bright teardrop in the glass.
static func lantern_flame() -> ArrayMesh:
	if _cache.has("flame"):
		return _cache["flame"]
	var mb := MeshBuilder.new()
	mb.sphere(&"glow", Transform3D(Basis(), LANTERN_FLAME + Vector3(0, -0.03, 0)), Vector3(0.022, 0.045, 0.022), 8, 6, Color(1.0, 0.72, 0.3))
	var m := mb.build()
	_cache["flame"] = m
	return m


## The item's model (the icon, the hand, a dropped one, the placing preview of the gate
## and the lantern post): the piece as it stands.
static func add_whole(out: Array, id: StringName) -> void:
	match id:
		&"fence_panel":
			MeshMerge.add_mesh(out, panel(PANEL, 0.0, true, true, 5))
		&"fence_gate":
			MeshMerge.add_mesh(out, gate_posts(PANEL, 0.0, 9))
			MeshMerge.add_mesh(out, gate_leaf(PANEL), Transform3D(Basis(), Vector3(-PANEL * 0.5, 0.0, 0.0)))
		&"lantern_post":
			MeshMerge.add_mesh(out, lantern_body())
			MeshMerge.add_mesh(out, lantern_flame())


## A hewn post standing at `at` (its foot a little in the ground): seven faces, tapering,
## dark and green where the grass wets it, most near true and now and then one leaning
## (`lean`: how much of that; a gate's and the lantern's stand straighter).
static func post(mb: MeshBuilder, at: Vector3, height: float, thickness: float, seed_value: int, lean := 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var h := height * rng.randf_range(0.97, 1.05) + 0.1
	var tilt_max := (2.5 if rng.randf() < 0.85 else 5.0) * lean
	var tilt := Vector3(rng.randf_range(-tilt_max, tilt_max), rng.randf_range(0, 360), rng.randf_range(-tilt_max, tilt_max))
	var col := WOOD_DARK.lerp(WOOD, rng.randf())
	var r := thickness * 0.62
	var wet := Color(col.r * 0.6, col.g * 0.64, col.b * 0.52)
	var foot := Transform3D(Basis.from_euler(tilt * (PI / 180.0)), at + Vector3(0, -0.1, 0))
	mb.cylinder(&"fence_wood", foot, r * 1.06, r, 0.45, 7, wet, false, false, col)
	mb.cylinder(&"fence_wood", foot * Transform3D(Basis(), Vector3(0, 0.45, 0)), r, r * 0.9, h - 0.45, 7, col, false, true)


## A split rail from post to post: an uneven five-sided section, a little thicker at one
## end, sagging a touch and running on past the posts.
static func _rail(mb: MeshBuilder, from: Vector3, to: Vector3, rng: RandomNumberGenerator) -> void:
	var sag := Vector3(0, rng.randf_range(-0.03, 0.015), 0)
	var dir := (to - from).normalized()
	var col := WOOD.lerp(WOOD_DARK, rng.randf() * 0.5)
	var r := rng.randf_range(0.045, 0.056)
	var a := from - dir * 0.07 + sag * 0.3
	var b := to + dir * 0.07 + sag * 0.3
	var mid := (from + to) * 0.5 + sag
	var taper := rng.randf_range(0.85, 1.0)
	mb.cylinder_between(&"fence_wood", a, mid, r, r * lerpf(1.0, taper, 0.5), 5, col, false, true)
	mb.cylinder_between(&"fence_wood", mid, b, r * lerpf(1.0, taper, 0.5), r * taper, 5, col, false, true)


static func _seed_at(seed_value: int, end: int) -> int:
	return seed_value * 31 + end * 7 + 3
