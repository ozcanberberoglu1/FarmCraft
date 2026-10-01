@tool
class_name ArrowModels
extends RefCounted
## The bow's arrows, built from the photo-textured materials (Mats): an ash shaft, an iron
## broadhead, a horn nock and three goose-feather vanes (the cock feather dyed red, as
## hunters do so an arrow is found again in the grass, the two hen feathers pale).
##   single(): one arrow along -Z, its nock at the origin (flying, stuck where it landed,
##     nocked on the bow in hand)
##   mesh(&"arrow"): the item, a sheaf of arrows tied with twine, standing on its nocks
##     at the origin like the other goods (icon, hand, pickup)

const IDS: Array[StringName] = [&"arrow"]
## The arrow's length (nock to point) and its shaft's radius (m).
const LENGTH := 0.8
const SHAFT_R := 0.0042
## How far the broadhead and the vanes reach along the shaft (from the point, the nock).
const HEAD := 0.052
const VANES := Vector2(0.028, 0.15)
const ASH := Color(0.76, 0.62, 0.44)
const IRON := Color(0.36, 0.35, 0.34)
const HORN := Color(0.2, 0.17, 0.14)
const TWINE := Color(0.62, 0.52, 0.36)
const COCK := Color(0.78, 0.16, 0.1)
const HEN := Color(0.9, 0.88, 0.82)

static var _single: ArrayMesh


static func has(id: StringName) -> bool:
	return id in IDS


static func mesh(_id: StringName) -> ArrayMesh:
	var mb := MeshBuilder.new()
	# Five arrows standing on their nocks, fanned a little at the heads, bound at a third.
	var spots: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.011, 0.006), Vector2(-0.01, 0.007),
		Vector2(0.005, -0.011), Vector2(-0.008, -0.009)]
	for i in spots.size():
		var base := Vector3(spots[i].x, 0.0, spots[i].y)
		var lean := Vector3(spots[i].x, 0.0, spots[i].y) * 2.2
		var up := (Vector3.UP + lean).normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		# single() runs along -Z: turn it to stand along `up`, each with its own twist.
		var b := Basis(side, side.cross(up).normalized(), -up).rotated(up, float(i) * 1.3)
		_arrow(mb, Transform3D(b.orthonormalized(), base))
	for y: float in [0.26, 0.3]:
		mb.ring(&"cloth", Transform3D(Basis(), Vector3(0, y, 0)), 0.021, 0.015, 0.007, 14, TWINE.darkened(0.05 if y > 0.27 else 0.0))
	return mb.build()


## One arrow along -Z with its nock at the origin (cached: every arrow in flight, stuck
## in the ground and on the string shares it).
static func single() -> ArrayMesh:
	if _single == null:
		var mb := MeshBuilder.new()
		_arrow(mb, Transform3D.IDENTITY)
		_single = mb.build()
	return _single


## An arrow under `xf` (nock at its origin, the point along its -Z).
static func _arrow(mb: MeshBuilder, xf: Transform3D) -> void:
	var z := func(d: float) -> Vector3: return xf * Vector3(0, 0, -d)
	# The shaft, a touch slimmer toward the point (barrelled ash), and the horn nock.
	mb.cylinder_between(&"wood", z.call(0.012), z.call(LENGTH - HEAD + 0.012), SHAFT_R, SHAFT_R * 0.9, 8, ASH)
	mb.cylinder_between(&"wood", z.call(0.0), z.call(0.014), SHAFT_R * 1.05, SHAFT_R * 1.12, 8, HORN)
	# The broadhead: a socket over the shaft and a flat two-edged blade.
	var socket := LENGTH - HEAD
	mb.cylinder_between(&"steel", z.call(socket - 0.006), z.call(socket + 0.016), SHAFT_R * 1.15, SHAFT_R * 0.95, 8, IRON)
	var side := xf.basis * Vector3.RIGHT
	var up := xf.basis * Vector3.UP
	var tip: Vector3 = z.call(LENGTH)
	var barb_l: Vector3 = z.call(socket + 0.012) + side * 0.011
	var barb_r: Vector3 = z.call(socket + 0.012) - side * 0.011
	var neck: Vector3 = z.call(socket + 0.016)
	var t := up * 0.0009
	mb.quad(&"steel", neck + t, barb_l + t, tip + t, barb_r + t, IRON.lightened(0.08))
	mb.quad(&"steel", neck - t, barb_r - t, tip - t, barb_l - t, IRON.lightened(0.08))
	# Three vanes, 120 degrees apart, the cock feather standing straight off the nock's slot.
	for k in 3:
		var a := TAU * float(k) / 3.0 + PI * 0.5
		var d := xf.basis * Vector3(cos(a), sin(a), 0.0)
		var col: Color = COCK if k == 0 else HEN
		_vane(mb, z, d, col)
	# Silk whipping in front of and behind the vanes.
	for at: float in [VANES.x - 0.006, VANES.y + 0.004]:
		var p: Vector3 = z.call(at)
		var q: Vector3 = z.call(at + 0.006)
		mb.cylinder_between(&"cloth", p, q, SHAFT_R * 1.2, SHAFT_R * 1.2, 8, Color(0.5, 0.18, 0.12), true, false)


## A shield-cut feather vane along the shaft from VANES.x to VANES.y (from the nock),
## standing out along `out`: full height at the back, curving down to the shaft in front.
static func _vane(mb: MeshBuilder, z: Callable, out: Vector3, col: Color) -> void:
	var n := 7
	var height := 0.015
	var prev_b := Vector3.ZERO
	var prev_t := Vector3.ZERO
	for i in n + 1:
		var u := float(i) / n
		var d := lerpf(VANES.x, VANES.y, u)
		# A shield cut: square at the back, a long curve down at the front.
		var h := height * (1.0 if u < 0.35 else cos((u - 0.35) / 0.65 * PI * 0.5))
		var b: Vector3 = z.call(d) + out * SHAFT_R
		var tp: Vector3 = b + out * maxf(h, 0.0006)
		if i > 0:
			mb.quad2(&"cloth", prev_b, b, tp, prev_t, col.darkened(0.06 * u))
		prev_b = b
		prev_t = tp
