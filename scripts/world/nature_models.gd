@tool
class_name NatureModels
extends RefCounted
## Vegetation and rocks. Trees are procedural: bark-textured trunks and limbs dressed
## with foliage cards cut from composed atlases (tools/build_foliage.gd: whole spruce
## branches and leafy broadleaf twigs laid out from scanned twigs and leaves), shaded
## darker deeper inside the crown. Rocks, ferns, nettles, fallen branches, stumps and
## logs are photo-scans (Poly Haven, CC0, art/models/nature) with their own material
## (shaders/nature_scan*.gdshader). Meshes are cached per (kind, seed); the vegetation
## meshes are only ever drawn, so they are built indexed (shared vertices).

## Regions of the broadleaf atlas (leaves_broad_albedo.png), UV space (crops use them).
const BROAD_TWIGS: Array[Rect2] = [Rect2(0.35, 0.06, 0.24, 0.63), Rect2(0.56, 0.03, 0.30, 0.64)]
const BROAD_SCATTER: Array[Rect2] = [Rect2(0.0, 0.02, 0.44, 0.47), Rect2(0.0, 0.5, 0.44, 0.48)]
## Needle twigs in the fir atlas (leaves_fir_albedo.png); the stem end is at the bottom.
const FIR_TWIGS: Array[Rect2] = [Rect2(0.31, 0.40, 0.34, 0.38), Rect2(0.63, 0.44, 0.33, 0.39),
		Rect2(0.19, 0.03, 0.23, 0.28), Rect2(0.65, 0.03, 0.28, 0.34)]
## Cells of the spruce atlas (leaves_spruce, see tools/build_foliage.gd): whole branches
## ("fronds", stem end at the bottom middle, tip at the top), the leader shoot and
## round needle clumps (a branch seen end-on).
const SPRUCE_FRONDS: Array[Rect2] = [Rect2(0.0, 0.0, 0.5, 0.5), Rect2(0.5, 0.0, 0.5, 0.5), Rect2(0.0, 0.5, 0.5, 0.5)]
const SPRUCE_LEADER := Rect2(0.5, 0.5, 0.25, 0.5)
const SPRUCE_CLUMPS: Array[Rect2] = [Rect2(0.75, 0.5, 0.25, 0.25), Rect2(0.75, 0.75, 0.25, 0.25)]
## Leafy twig sprays of the cluster atlas (leaves_cluster), stem end at the bottom middle.
const LEAF_SPRAYS: Array[Rect2] = [Rect2(0.0, 0.0, 0.5, 0.5), Rect2(0.5, 0.0, 0.5, 0.5),
		Rect2(0.0, 0.5, 0.5, 0.5), Rect2(0.5, 0.5, 0.5, 0.5)]

const NEUTRAL := Color(0.5, 0.5, 0.5)
const FLOWER_COLORS: Array[Color] = [Color("f4f1e6"), Color("f7d445"), Color("b48be0"), Color("ef6f5e"), Color("f2a0c8")]

static var _cache: Dictionary = {}
## Rock collision hulls, keyed like the rock meshes in _cache.
static var _rock_shapes: Dictionary = {}
## Crown of each built tree mesh (keyed by the mesh): [crown bottom, top, radius, broadleaf].
static var _crowns: Dictionary = {}


static func _cached(key: String, maker: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


## Brightness of a card deep inside a crown (next to the trunk, under the crown)
## relative to one on its sunlit outside: the self-shadowing and lost sky light the
## vertex colour carries (also ambient occlusion in shaders/foliage_card.gdshader).
## Trees with real shadows need less of it than the shadowless far ones (and their
## impostor pictures, which are rendered unlit).
const CROWN_SHADE_NEAR := 0.7
const CROWN_SHADE_FAR := 0.42


static func _tint(rng: RandomNumberGenerator, amount := 0.08, warm := 0.0) -> Color:
	var v := 0.5 * (1.0 + rng.randf_range(-amount, amount))
	var hue := rng.randf_range(-amount, amount) * 0.5 + warm
	return Color(v * (1.0 + hue), v, v * (1.0 - hue * 0.5))


## Darkens a card colour by how deep it sits in the crown: `open` is 0 deep inside
## (next to the trunk, under the crown) to 1 at the sunlit outside.
static func _crown_shade(c: Color, open: float, deep := CROWN_SHADE_FAR) -> Color:
	var k := lerpf(deep, 1.0, clampf(open, 0.0, 1.0))
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _basis_from_dir(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y).normalized())


## How far a foliage card's lighting normal leans from the crown's towards the card's.
const CARD_FACING := 0.8


## A foliage card growing from `base` along `up` (full length), `right` wide, with the
## stem end of the atlas cell at `base`. The colour runs from `c_base` at the stem to
## `c_tip`, so a branch darkens towards the trunk; `n` is the lighting normal.
static func _stem_card(mb: MeshBuilder, key: StringName, base: Vector3, right: Vector3, up: Vector3,
		rect: Rect2, n: Vector3, c_base: Color, c_tip: Color, sway_base := 1.0, sway_tip := 1.0) -> void:
	var r := right * 0.5
	var bl := base - r
	var br := base + r
	var tr := base + r + up
	var tl := base - r + up
	var uv_bl := Vector2(rect.position.x, rect.end.y)
	var uv_br := rect.end
	var uv_tr := Vector2(rect.end.x, rect.position.y)
	var uv_tl := rect.position
	# Leaned towards the card's own facing (on the side the crown normal is on): the
	# shadows' normal bias follows this normal, and one lying in the card's plane would
	# let the card shadow itself in stripes (acne).
	var facing := right.cross(up).normalized()
	if facing.dot(n) < 0.0:
		facing = -facing
	n = (n.normalized() + facing * CARD_FACING).normalized()
	var cb := Color(c_base.r, c_base.g, c_base.b, sway_base)
	var ct := Color(c_tip.r, c_tip.g, c_tip.b, sway_tip)
	mb.tri_n(key, bl, br, tr, n, n, n, cb, cb, ct, uv_bl, uv_br, uv_tr)
	mb.tri_n(key, bl, tr, tl, n, n, n, cb, ct, ct, uv_bl, uv_tr, uv_tl)


## A trunk as one smooth tube through `centers` (continuous bark, no seams between
## pieces), `radii` wide, coloured `colors` along it. Bark UVs are in metres (u round
## the base's circumference). The base spreads into `roots` buttresses (0 = round)
## that fade out over the first 0.7 m, so the tree grows out of the ground.
static func _trunk(mb: MeshBuilder, key: StringName, centers: Array[Vector3], radii: Array[float], sides: int,
		colors: Array[Color], roots: float, rng: RandomNumberGenerator) -> void:
	var n := centers.size()
	var phase := rng.randf() * TAU
	var lobes := rng.randi_range(4, 6)
	var rings: Array[PackedVector3Array] = []
	var dirs: Array[PackedVector3Array] = []
	var prev_side := Vector3.ZERO
	for i in n:
		var t := (centers[mini(i + 1, n - 1)] - centers[maxi(i - 1, 0)]).normalized()
		var side := prev_side
		if side == Vector3.ZERO or absf(side.dot(t)) > 0.99:
			side = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		side = (side - t * side.dot(t)).normalized()
		prev_side = side
		var up := t.cross(side).normalized()
		var flare := roots * (1.0 - smoothstep(0.0, 0.7, centers[i].y))
		var ring := PackedVector3Array()
		var dring := PackedVector3Array()
		for k in sides + 1:
			var a := TAU * float(k) / sides
			var d := side * cos(a) + up * sin(a)
			var lobe := pow(maxf(0.0, sin(a * lobes + phase)), 2.0) - 0.3
			ring.append(centers[i] + d * radii[i] * (1.0 + flare * lobe))
			dring.append(d)
		rings.append(ring)
		dirs.append(dring)
	var around := TAU * radii[0]
	var v := 0.0
	for i in n - 1:
		var seg := centers[i].distance_to(centers[i + 1])
		var t := (centers[i + 1] - centers[i]) / maxf(seg, 0.0001)
		var taper := (radii[i] - radii[i + 1]) / maxf(seg, 0.0001)
		for k in sides:
			var u0 := float(k) / sides * around
			var u1 := float(k + 1) / sides * around
			var na := (dirs[i][k] + t * taper).normalized()
			var nb := (dirs[i][k + 1] + t * taper).normalized()
			var nc := (dirs[i + 1][k + 1] + t * taper).normalized()
			var nd := (dirs[i + 1][k] + t * taper).normalized()
			mb.tri_n(key, rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], na, nb, nc, colors[i], colors[i], colors[i + 1],
					Vector2(u0, v), Vector2(u1, v), Vector2(u1, v + seg))
			mb.tri_n(key, rings[i][k], rings[i + 1][k + 1], rings[i + 1][k], na, nc, nd, colors[i], colors[i + 1], colors[i + 1],
					Vector2(u0, v), Vector2(u1, v + seg), Vector2(u0, v + seg))
		v += seg


# --- Broadleaf tree ------------------------------------------------------------------

## Deciduous tree (kept under the old name so callers don't change): a trunk forking
## into limbs, each ending in a lobe of leafy twigs, so the crown is a cluster of
## rounded masses with gaps and shaded hollows between them, not one ball.
static func oak(seed_value: int, detail := true) -> ArrayMesh:
	return _cached("broad_%d_%s" % [seed_value, detail], _make_broadleaf.bind(seed_value, detail))


static func _make_broadleaf(seed_value: int, detail: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 313 + 11
	var mb := MeshBuilder.new()
	var height := rng.randf_range(7.5, 10.0)
	var trunk_top := height * rng.randf_range(0.27, 0.35)
	var spread := rng.randf_range(2.8, 3.6)
	var crown := Vector3(spread, (height - trunk_top) * 0.5, spread * rng.randf_range(0.85, 1.05))
	var crown_center := Vector3(rng.randf_range(-0.3, 0.3), height - crown.y, rng.randf_range(-0.3, 0.3))
	var leaves := &"leaves" if detail else &"leaves_far"
	var deep := CROWN_SHADE_NEAR if detail else CROWN_SHADE_FAR

	# Trunk: a slightly wandering spine with a flared base.
	var spine: Array[Vector3] = [Vector3.ZERO]
	var segs := 4
	for i in range(1, segs + 1):
		var t := float(i) / segs
		spine.append(Vector3(rng.randf_range(-0.14, 0.14) * t, trunk_top * t, rng.randf_range(-0.14, 0.14) * t))
	var r0 := rng.randf_range(0.26, 0.34)
	var sides := 10 if detail else 6
	# Far trees have no shadows (nor do their impostor pictures): the trunk darkens
	# up into the crown's shade.
	var shade_top := NEUTRAL if detail else Color(0.28, 0.28, 0.28)
	var centers: Array[Vector3] = [Vector3(0, -0.1, 0), Vector3(0, 0.2, 0)]
	var radii: Array[float] = [r0 * 1.55, r0 * 1.18]
	var colors: Array[Color] = [NEUTRAL, NEUTRAL]
	for i in segs + 1:
		var p := spine[i] if i > 0 else Vector3(0, 0.5, 0)
		centers.append(p)
		radii.append(lerpf(r0, r0 * 0.7, float(i) / segs))
		colors.append(NEUTRAL.lerp(shade_top, float(i) / segs))
	# Above the first limbs the trunk goes on up into the crown, thinning out.
	var lean := Vector3(crown_center.x, 0.0, crown_center.z) * 0.5
	for k in 2:
		centers.append(spine[segs].lerp(crown_center + lean + Vector3(0, crown.y * 0.35, 0), 0.5 + k * 0.5))
		radii.append(r0 * (0.5 if k == 0 else 0.22))
		colors.append(shade_top)
	_trunk(mb, &"bark", centers, radii, sides, colors, 0.35, rng)

	# Lobes: sub-crowns at the ends of the limbs, spread over the crown's dome (its
	# underside flatter), plus one on top.
	var lobes: Array[Array] = []
	var limbs := rng.randi_range(7, 9) if detail else rng.randi_range(6, 7)
	var lobe_size := 1.0 if detail else 1.15
	for b in limbs:
		var ang := b * 2.39996 + rng.randf_range(-0.3, 0.3)
		var rise := lerpf(-0.45, 0.7, fmod(b * 0.618 + rng.randf() * 0.3, 1.0))
		var out := Vector3(cos(ang) * sqrt(1.0 - rise * rise), rise, sin(ang) * sqrt(1.0 - rise * rise))
		var c := crown_center + out * crown * rng.randf_range(0.5, 0.64)
		lobes.append([c, rng.randf_range(1.3, 1.75) * lobe_size])
	lobes.append([crown_center + Vector3(rng.randf_range(-0.4, 0.4), crown.y * 0.5, rng.randf_range(-0.4, 0.4)),
			rng.randf_range(1.4, 1.7) * lobe_size])
	# Limbs: each leaves the trunk at a height that goes with its lobe's (low lobes from
	# low down), rises steeply, then arcs out to the lobe, thinning.
	var limb_end := NEUTRAL if detail else Color(0.2, 0.2, 0.2)
	for li in lobes.size() - 1:
		var c: Vector3 = lobes[li][0]
		var k := clampf((c.y - trunk_top) / maxf(height - trunk_top, 0.1), 0.0, 1.0)
		var start := _along(centers, lerpf(trunk_top * 0.8, crown_center.y + crown.y * 0.15, k * 0.8 + rng.randf_range(0.0, 0.15)))
		var end := start.lerp(c, 0.85)
		var reach := start.distance_to(end)
		var mid := start.lerp(end, 0.4) + Vector3.UP * reach * 0.16 \
				+ Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * reach * 0.07
		var r_limb := r0 * lerpf(0.55, 0.35, k)
		_trunk(mb, &"bark", [start, mid, end], [r_limb, r_limb * 0.62, 0.05],
				7 if detail else 4, [shade_top, shade_top, limb_end], 0.0, rng)
		if detail:
			for t in 2:
				var s0 := mid.lerp(end, rng.randf_range(0.1, 0.7))
				var d := (end - mid).normalized() + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.1, 0.5), rng.randf_range(-0.9, 0.9))
				mb.cylinder_between(&"bark", s0, s0 + d.normalized() * float(lobes[li][1]) * 0.8, 0.05, 0.015, 4, NEUTRAL, true, false)

	# Leafy twigs over each lobe's surface, pointing out of it.
	var density := 8.0 if detail else 5.0
	var card := 1.45 if detail else 2.0
	for lobe: Array in lobes:
		var c: Vector3 = lobe[0]
		var radius: float = lobe[1]
		var n_cards := int(radius * radius * density)
		for i in n_cards:
			var out := _rand_in_sphere(rng).normalized()
			var p := c + out * radius * rng.randf_range(0.5, 0.9)
			_leaf_card(mb, leaves, p, out, c, crown_center, crown, rng, card * rng.randf_range(0.85, 1.1), deep)
	# A few inside, so the crown isn't hollow.
	for i in (8 if detail else 4):
		var p := crown_center + _rand_in_sphere(rng) * crown * 0.45
		_leaf_card(mb, leaves, p, _rand_in_sphere(rng).normalized(), p, crown_center, crown, rng, card, deep)
	mb.set_sway_by_height(&"bark", trunk_top * 0.8, height, 0.3)
	mb.set_sway_by_height(leaves, trunk_top * 0.6, height, 1.0)
	var m := mb.build({}, true)
	_crowns[m] = [trunk_top, height, spread, true]
	return m


## One leafy twig card growing from `p` out of its lobe (centred at `lobe`), lit with a
## normal between the lobe's and the whole crown's, darker deeper in the crown.
static func _leaf_card(mb: MeshBuilder, key: StringName, p: Vector3, out: Vector3, lobe: Vector3,
		crown_center: Vector3, crown: Vector3, rng: RandomNumberGenerator, length: float, deep: float) -> void:
	var dir := (out + Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.2, 0.45), rng.randf_range(-0.45, 0.45))).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	side = side.rotated(dir, rng.randf_range(-1.2, 1.2))
	var rel := (p - crown_center) / crown
	var n := (out * 0.55 + rel.normalized() * 0.35 + Vector3.UP * 0.25).normalized()
	var tint := _tint(rng, 0.1)
	# Deeper in the crown and on its underside is darker; the twig's stem end is
	# further in than its tip.
	var depth := clampf(rel.length(), 0.0, 1.2)
	var open := depth * 0.75 + rel.y * 0.3 + 0.1
	var base := p - dir * length * 0.3
	_stem_card(mb, key, base, side * length, dir * length, LEAF_SPRAYS[rng.randi() % LEAF_SPRAYS.size()], n,
			_crown_shade(tint, open - 0.3, deep), _crown_shade(tint, open + 0.15, deep), 0.85, 1.0)


## The point at height `y` on a trunk rising through `centers` (clamped to its ends).
static func _along(centers: Array[Vector3], y: float) -> Vector3:
	for i in centers.size() - 1:
		if centers[i + 1].y >= y:
			var t := clampf((y - centers[i].y) / maxf(centers[i + 1].y - centers[i].y, 0.0001), 0.0, 1.0)
			return centers[i].lerp(centers[i + 1], t)
	return centers[centers.size() - 1]


static func _rand_in_sphere(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if v.length_squared() <= 1.0 and v.length_squared() > 0.01:
			return v
	return Vector3.UP


# --- Conifer ---------------------------------------------------------------------

## Spruce (kept under the old name so callers don't change): whorls of whole branches
## that droop low down and rise near the top, a dense dark core of needle clumps round
## the trunk and an upright leader. Seeds vary height, slenderness and droop.
static func pine(seed_value: int, detail := true) -> ArrayMesh:
	return _cached("fir_%d_%s" % [seed_value, detail], _make_spruce.bind(seed_value, detail))


static func _make_spruce(seed_value: int, detail: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 101 + 3
	var mb := MeshBuilder.new()
	var height := rng.randf_range(8.5, 12.0)
	var r0 := rng.randf_range(0.22, 0.3)
	var radius := height * rng.randf_range(0.23, 0.3)
	var droop := rng.randf_range(0.5, 1.0)
	var needles := &"needles" if detail else &"needles_far"
	var deep := CROWN_SHADE_NEAR if detail else CROWN_SHADE_FAR
	var crown_base := rng.randf_range(0.6, 1.5)
	# Inside the crown the trunk is in deep shade; far trees (and their impostor
	# pictures) have no shadows to show it, so it is dark from the crown up.
	var inner := NEUTRAL if detail else Color(0.12, 0.12, 0.12)
	# The trunk ends inside the leader shoot (the shoot's own stem carries on up).
	var tip := height - 1.1
	var centers: Array[Vector3] = [Vector3(0, -0.1, 0), Vector3(0, 0.2, 0), Vector3(0, 0.5, 0),
			Vector3(0, crown_base + 0.3, 0), Vector3(0, lerpf(crown_base, tip, 0.5), 0), Vector3(0, tip, 0)]
	var radii: Array[float] = [r0 * 1.5, r0 * 1.15, r0, lerpf(r0, 0.03, (crown_base - 0.2) / tip),
			lerpf(r0, 0.03, 0.5), 0.03]
	var colors: Array[Color] = [NEUTRAL, NEUTRAL, NEUTRAL, NEUTRAL.lerp(inner, 0.7), inner, inner]
	_trunk(mb, &"bark_pine", centers, radii, 10 if detail else 5, colors, 0.3, rng)
	var spacing := 0.46 if detail else 0.5
	var y := crown_base
	var whorl := 0
	while y < height - 1.3:
		var t := (y - crown_base) / (height - crown_base)
		var length := radius * pow(1.0 - t, 0.92) * rng.randf_range(0.88, 1.1) + 0.35
		var count := rng.randi_range(5, 6) if detail else 5
		for b in count:
			var ang := TAU * (b + rng.randf_range(-0.22, 0.22)) / count + whorl * 1.13
			var out := Vector3(cos(ang), 0.0, sin(ang))
			# Low branches hang, high ones rise.
			var elev := lerpf(-0.38 * droop, 0.55, pow(t, 0.85)) + rng.randf_range(-0.08, 0.08)
			var dir := (out + Vector3.UP * elev).normalized()
			var start := Vector3(0, y, 0) + out * r0 * 0.4
			if detail and t < 0.75:
				mb.cylinder_between(&"bark_pine", start, start + dir * length * 0.7, 0.035, 0.01, 4, NEUTRAL, true, false)
			_spruce_branch(mb, needles, start, out, dir, length, t, rng, detail, deep)
		y += spacing * rng.randf_range(0.85, 1.15)
		whorl += 1
	# Needle clumps round the trunk: the dense, dark core of a spruce.
	var cy := crown_base + 0.4
	while cy < height - 1.6:
		var t := (cy - crown_base) / (height - crown_base)
		var size := minf(radius * pow(1.0 - t, 0.92) * 1.1 + 0.4, 2.6)
		var a := rng.randf() * TAU
		for k in 2:
			var face := Vector3(cos(a + k * PI * 0.5), 0.0, sin(a + k * PI * 0.5))
			var side := face.cross(Vector3.UP)
			var shade := _crown_shade(_tint(rng, 0.06, -0.02), 0.35 + t * 0.4, deep)
			mb.card(needles, Vector3(0, cy, 0), side * size, Vector3.UP * size * 0.9,
					SPRUCE_CLUMPS[rng.randi() % 2], (face * 0.5 + Vector3.UP * 0.5), shade, 0.6, 0.8)
		cy += 1.0 if detail else 0.9
	# The leader: two crossed upright shoots.
	var top := height - 1.75
	for k in 2:
		var a := rng.randf() * PI + k * PI * 0.5
		var side := Vector3(cos(a), 0.0, sin(a))
		_stem_card(mb, needles, Vector3(0, top, 0), side * 0.95, Vector3.UP * 1.9, SPRUCE_LEADER,
				(side.cross(Vector3.UP) * 0.4 + Vector3.UP * 0.6), _tint(rng, 0.05), _tint(rng, 0.05))
	mb.set_sway_by_height(needles, 0.0, height, 1.0)
	mb.set_sway_by_height(&"bark_pine", height * 0.3, height, 0.4)
	var m := mb.build({}, true)
	_crowns[m] = [crown_base, height, radius, false]
	return m


## One whorl branch: two fronds crossed along it at a random turn (so it has depth
## from every side and is never just a flat card seen edge-on), darker at the trunk
## end and on low whorls.
static func _spruce_branch(mb: MeshBuilder, key: StringName, start: Vector3, out: Vector3, dir: Vector3,
		length: float, t: float, rng: RandomNumberGenerator, detail: bool, deep: float) -> void:
	var flat := dir.cross(Vector3.UP).normalized()
	var n := (out * 0.62 + Vector3.UP * (0.45 + 0.25 * t)).normalized()
	var reach := length * (1.08 if detail else 1.12)
	var width := reach * 0.95
	var first := rng.randf_range(0.25, 0.75) * (1.0 if rng.randf() < 0.5 else -1.0)
	var rolls := [first, first + PI * 0.5 + rng.randf_range(-0.3, 0.3)]
	for i in rolls.size():
		var side := flat.rotated(dir, rolls[i])
		var rect := SPRUCE_FRONDS[rng.randi() % SPRUCE_FRONDS.size()]
		var tint := _tint(rng, 0.07, -0.02)
		# Under the crown and next to the trunk is darker.
		var low := 0.55 + 0.45 * t
		_stem_card(mb, key, start - dir * 0.1, side * width * (1.0 if i == 0 else 0.8), dir * reach, rect,
				n, _crown_shade(tint, 0.25 * low, deep), _crown_shade(tint, (0.85 + rng.randf_range(0.0, 0.15)) * low, deep),
				0.3, 1.0)


# --- Distant impostors ------------------------------------------------------------------
# The far hill forest is drawn as camera-facing cards showing a picture of the real
# tree (tools/tree_impostors.gd renders the atlas): one layer per tree instead of a
# hundred overlapping foliage cards.

const IMPOSTOR_ATLAS := "res://art/textures/impostors/forest.png"
## Cell height / width in the atlas.
const IMPOSTOR_ASPECT := 1.5
## Which of forest_meshes() are broadleaf (autumn colours, leaf fall). The first five
## keep the old order (three conifers, two broadleaf): the backdrop picks among them.
const FOREST_BROAD: Array[bool] = [false, false, false, true, true, false, false, true]


## The hill forest trees, in atlas order.
static func forest_meshes() -> Array[Mesh]:
	return [pine(4, false), pine(5, false), pine(6, false), oak(4, false), oak(5, false),
		pine(7, false), pine(8, false), oak(6, false)]


## Indices into forest_meshes() of the conifers and of the broadleaf trees.
static func forest_kinds(broad: bool) -> Array[int]:
	var out: Array[int] = []
	for i in FOREST_BROAD.size():
		if FOREST_BROAD[i] == broad:
			out.append(i)
	return out


## World size (width, height) of a tree's picture: base at the bottom edge, trunk centred.
static func impostor_frame(mesh: Mesh) -> Vector2:
	var box := mesh.get_aabb()
	var half := maxf(maxf(-box.position.x, box.end.x), maxf(-box.position.z, box.end.z))
	var h := maxf(box.end.y * 1.02, half * 2.0 * IMPOSTOR_ASPECT)
	return Vector2(h / IMPOSTOR_ASPECT, h)


## Unit card for the impostor shader: x across (-0.5..0.5), y up (0..1).
static func impostor_card() -> ArrayMesh:
	if _cache.has("impostor_card"):
		return _cache["impostor_card"]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tree_impostor.gdshader")
	mat.set_shader_parameter("atlas", load(IMPOSTOR_ATLAS))
	mat.set_shader_parameter("cells", float(forest_meshes().size()))
	# Matches the foliage-card trees' average brightness (measured side by side).
	mat.set_shader_parameter("brightness", 1.2)
	m.surface_set_material(0, mat)
	# The card turns to face the camera: cull it as the whole tree volume.
	var widest := 0.0
	var tallest := 0.0
	for tree in forest_meshes():
		var f := impostor_frame(tree)
		widest = maxf(widest, f.x)
		tallest = maxf(tallest, f.y)
	m.custom_aabb = AABB(Vector3(-widest * 0.5, 0, -widest * 0.5), Vector3(widest, tallest, widest))
	_cache["impostor_card"] = m
	return m


# --- Shadow proxies ------------------------------------------------------------------
# The hill forest's foliage cards cast no shadows (thousands of alpha-tested cards in
# every shadow cascade would cost more than the trees). Instead each tree casts the
# shadow of a plain cone or ellipsoid a little inside its crown, holed in patches so
# the shade is dappled with sun flecks: it falls on the forest floor and on the tree's
# own inner and far-side branches.

## Unit shadow shape: a lumpy cone (base radius about 1 at y 0, tip at y 1) for
## conifers, or a lumpy ellipsoid (radius 1 round (0, 0.5, 0), 1 tall) for broadleaf
## trees. The lumps break up the shadow's outline like whorls and lobes do.
static func shadow_shape(broad: bool) -> ArrayMesh:
	var key := "shadow_%s" % broad
	if _cache.has(key):
		return _cache[key]
	var mb := MeshBuilder.new()
	if broad:
		mb.blob(&"shadow", Transform3D(Basis.from_scale(Vector3(1.0, 0.5, 1.0)), Vector3(0, 0.5, 0)), 1.0, 1, NEUTRAL,
				0.45, 1.6, 3)
	else:
		# Tiers like the whorls of branches (a jagged, layered outline, not a smooth cone).
		var sides := 9
		var tiers := 5
		var rng := RandomNumberGenerator.new()
		rng.seed = 12
		for k in tiers:
			var y0 := 0.88 * k / tiers
			var y1 := y0 + 0.32
			var r0 := (1.0 - y0) * rng.randf_range(0.9, 1.1)
			var turn := rng.randf() * TAU
			var bottom := PackedVector3Array()
			for i in sides:
				var a := turn + TAU * i / sides
				var r := r0 * rng.randf_range(0.72, 1.12)
				bottom.append(Vector3(cos(a) * r, y0 + rng.randf_range(-0.03, 0.05), sin(a) * r))
			var tip := Vector3(0, minf(y1, 1.0), 0)
			for i in sides:
				mb.tri(&"shadow", bottom[i], tip, bottom[(i + 1) % sides], NEUTRAL)
				mb.tri(&"shadow", bottom[i], bottom[(i + 1) % sides], Vector3(0, y0, 0), NEUTRAL)
	var m := mb.build({&"shadow": _shadow_material()})
	_cache[key] = m
	return m


## Dappled: holes in patches let sun flecks through (shaders/tree_shadow.gdshader).
## Either winding casts: the shapes are only ever drawn into shadow maps.
static func _shadow_material() -> Material:
	if not _cache.has("shadow_mat"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/tree_shadow.gdshader")
		_cache["shadow_mat"] = mat
	return _cache["shadow_mat"]


## Transform of a tree's shadow shape (shadow_shape) relative to the tree: its crown,
## a little smaller so the outer foliage stays sunlit.
static func shadow_transform(mesh: Mesh) -> Transform3D:
	var crown: Array = _crowns.get(mesh, [2.0, 10.0, 3.0, false])
	var bottom: float = crown[0]
	var top: float = crown[1]
	var radius: float = crown[2]
	if crown[3]:
		return Transform3D(Basis.from_scale(Vector3(radius * 0.6, (top - bottom) * 0.72, radius * 0.6)),
				Vector3(0, bottom + (top - bottom) * 0.12, 0))
	return Transform3D(Basis.from_scale(Vector3(radius * 0.52, (top - bottom) * 0.9, radius * 0.52)),
			Vector3(0, bottom + 0.4, 0))


# --- Bushes ------------------------------------------------------------------------

## A shrub: a few stems under two or three low mounds of leafy twigs.
static func bush(seed_value: int) -> ArrayMesh:
	return _cached("bush_%d" % seed_value, _make_bush.bind(seed_value))


static func _make_bush(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 71 + 5
	var mb := MeshBuilder.new()
	var center := Vector3(0, 0.55, 0)
	var radius := Vector3(rng.randf_range(0.85, 1.15), 0.62, rng.randf_range(0.85, 1.15))
	var mounds: Array[Array] = []
	for i in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		mounds.append([center + Vector3(cos(a) * 0.35, rng.randf_range(-0.05, 0.15), sin(a) * 0.35), rng.randf_range(0.6, 0.8)])
	for i in 6:
		var tip := center + Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(0.0, 0.45), rng.randf_range(-0.55, 0.55))
		mb.cylinder_between(&"bark", Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12)), tip, 0.03, 0.01,
				4, NEUTRAL, true, false)
	for m: Array in mounds:
		var c: Vector3 = m[0]
		var r: float = m[1]
		for i in int(r * r * 30.0):
			var out := _rand_in_sphere(rng).normalized()
			out.y = absf(out.y) * 0.8 + 0.1
			out = out.normalized()
			var p := c + out * r * rng.randf_range(0.35, 0.8)
			p.y = maxf(p.y, 0.12)
			_leaf_card(mb, &"leaves", p, out, c, center, radius, rng, rng.randf_range(0.7, 0.95), CROWN_SHADE_NEAR)
	mb.set_sway_by_height(&"leaves", 0.0, 1.4, 0.45)
	return mb.build({}, true)


# --- Scanned nature models ------------------------------------------------------------

## Poly Haven scans (see art/models/nature/CREDITS.md): glTF path and texture resolution.
const SCANS := {
	"rock_moss_set_01": ["res://art/models/nature/rock_moss_set_01/rock_moss_set_01_2k.gltf", "2k"],
	"rock_moss_set_02": ["res://art/models/nature/rock_moss_set_02/rock_moss_set_02_2k.gltf", "2k"],
	"boulder_01": ["res://art/models/nature/boulder_01/boulder_01_2k.gltf", "2k"],
	"rock_09": ["res://art/models/nature/rock_09/rock_09_1k.gltf", "1k"],
	"fern_02": ["res://art/models/nature/fern_02/fern_02_1k.gltf", "1k"],
	"nettle_plant": ["res://art/models/nature/nettle_plant/nettle_plant_1k.gltf", "1k"],
	"dry_branches_medium_01": ["res://art/models/nature/dry_branches_medium_01/dry_branches_medium_01_1k.gltf", "1k"],
	"tree_stump_01": ["res://art/models/nature/tree_stump_01/tree_stump_01_1k.gltf", "1k"],
	"dead_tree_trunk": ["res://art/models/nature/dead_tree_trunk/dead_tree_trunk_1k.gltf", "1k"],
}
## Material settings per scan (shaders/nature_scan*.gdshader uniforms). Scans without
## an ARM map have a plain roughness map.
const SCAN_LOOK := {
	"rock_moss_set_01": {"arm": false, "moss_amount": 0.15, "tint": Color(0.92, 0.92, 0.9), "max_triangles": 6000},
	"rock_moss_set_02": {"arm": false, "moss_amount": 0.2, "tint": Color(0.9, 0.9, 0.88), "max_triangles": 6000},
	"boulder_01": {"moss_amount": 0.3, "tint": Color(0.86, 0.86, 0.86), "max_triangles": 6000},
	"rock_09": {"moss_amount": 0.0, "tint": Color(0.78, 0.76, 0.74), "roughness_mult": 1.5, "max_triangles": 6000},
	"fern_02": {"foliage": true, "sway": 0.06, "tint": Color(1.0, 1.04, 0.95), "soil_height": 0.0},
	"nettle_plant": {"foliage": true, "sway": 0.05, "tint": Color(0.95, 1.0, 0.92), "soil_height": 0.0,
		"max_triangles": 2500},
	"dry_branches_medium_01": {"moss_amount": 0.1, "max_triangles": 2500},
	"tree_stump_01": {"moss_amount": 0.25, "max_triangles": 8000},
	"dead_tree_trunk": {"moss_amount": 0.35, "max_triangles": 8000},
}
## Largest triangle count a scan piece keeps unless SCAN_LOOK says otherwise (denser
## scans are simplified first).
const SCAN_MAX_TRIANGLES := 12000


## Simplified scan pieces saved by tools/bake_nature.gd: <scan>_<piece index>.res
## (ImporterMesh with its LODs), so the game doesn't simplify the dense scans at load.
const SCAN_BAKED := "res://art/models/nature/baked/%s_%d.res"


## The pieces of a scan: [surface arrays (footprint centred on the origin, lowest point
## at y 0, in metres), LODs {size: indices}, node name], ordered by name. Each piece is
## simplified to its triangle limit and has its LODs (baked, or made here once).
static func scan_pieces(scan: String) -> Array:
	var key := "scan_" + scan
	if _cache.has(key):
		return _cache[key]
	var out := []
	if ResourceLoader.exists(SCAN_BAKED % [scan, 0]):
		var i := 0
		while ResourceLoader.exists(SCAN_BAKED % [scan, i]):
			out.append(_piece_from(load(SCAN_BAKED % [scan, i]) as ImporterMesh))
			i += 1
	else:
		for im in build_scan(scan):
			out.append(_piece_from(im))
	_cache[key] = out
	return out


## [arrays, lods, name] of a simplified piece.
static func _piece_from(im: ImporterMesh) -> Array:
	var lods := {}
	for i in im.get_surface_lod_count(0):
		lods[im.get_surface_lod_size(0, i)] = im.get_surface_lod_indices(0, i)
	return [im.get_surface_arrays(0), lods, im.get_surface_name(0)]


## A scan's pieces, each sat on the origin and simplified with its LODs (what
## tools/bake_nature.gd saves), ordered by node name.
static func build_scan(scan: String) -> Array[ImporterMesh]:
	var parts := MeshMerge.scene_parts(load(SCANS[scan][0]) as PackedScene)
	parts.sort_custom(func(a: Array, b: Array) -> bool: return String(a[3]) < String(b[3]))
	var out: Array[ImporterMesh] = []
	var limit: int = (SCAN_LOOK.get(scan, {}) as Dictionary).get("max_triangles", SCAN_MAX_TRIANGLES)
	for part: Array in parts:
		var arrays := _transformed((part[1] as Mesh).surface_get_arrays(0), part[0])
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var box := AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
		arrays[Mesh.ARRAY_VERTEX] = Transform3D(Basis(), Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)) * verts
		for ch in [Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2,
				Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			arrays[ch] = null
		var im := _simplified(arrays, limit)
		# Keep the node name with the piece.
		var named := ImporterMesh.new()
		var lods := {}
		for i in im.get_surface_lod_count(0):
			lods[im.get_surface_lod_size(0, i)] = im.get_surface_lod_indices(0, i)
		named.add_surface(Mesh.PRIMITIVE_TRIANGLES, im.get_surface_arrays(0), [], lods, null, String(part[3]))
		out.append(named)
	return out


## `arrays` under `xf` (normals and tangents turned with it). Normals are left
## unnormalised: the GPU encoding normalises them.
static func _transformed(arrays: Array, xf: Transform3D) -> Array:
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = xf * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	if arrays[Mesh.ARRAY_NORMAL] != null:
		out[Mesh.ARRAY_NORMAL] = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) \
				* (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
		var b := xf.basis
		for i in range(0, tangents.size(), 4):
			var t := b * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		out[Mesh.ARRAY_TANGENT] = tangents
	return out


## `arrays` cut down to `max_triangles` if denser, with its LODs.
static func _simplified(arrays: Array, max_triangles: int) -> ImporterMesh:
	if arrays[Mesh.ARRAY_INDEX] == null:
		var idx := PackedInt32Array()
		for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			idx.append(i)
		arrays[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	if (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 > max_triangles:
		# The first LOD under the limit becomes the full-detail mesh, simplified again.
		for i in im.get_surface_lod_count(0):
			var li := im.get_surface_lod_indices(0, i)
			if li.size() / 3 <= max_triangles:
				var base := im.get_surface_arrays(0)
				base[Mesh.ARRAY_INDEX] = li
				im = ImporterMesh.new()
				im.add_surface(Mesh.PRIMITIVE_TRIANGLES, base)
				im.generate_lods(25.0, 60.0, [])
				break
	return im


## [arrays, lods] of scan piece `index` under `xf`. `ground_y` is the ground's height in
## the piece's own frame: vertex colour alpha carries the height above it (/ 4 m), for
## the soil and moss the material puts near the ground.
static func _piece(scan: String, index: int, xf := Transform3D.IDENTITY, ground_y := 0.0) -> Array:
	var piece: Array = scan_pieces(scan)[index]
	var src: Array = piece[0]
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var up := absf(xf.basis.y.y)
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		colors[i] = Color(1, 1, 1, clampf((verts[i].y - ground_y) * up / 4.0, 0.0, 1.0))
	var arrays := _transformed(src, xf)
	arrays[Mesh.ARRAY_COLOR] = colors
	var s := xf.basis.get_scale()
	var k := (absf(s.x) + absf(s.y) + absf(s.z)) / 3.0
	var lods := {}
	for size: float in piece[1]:
		lods[size * k] = piece[1][size]
	return [arrays, lods]


## Bounding box of scan piece `index` (its footprint centred, lowest point at y 0).
static func piece_bounds(scan: String, index: int) -> AABB:
	var key := "bounds_%s_%d" % [scan, index]
	if not _cache.has(key):
		var verts: PackedVector3Array = scan_pieces(scan)[index][0][Mesh.ARRAY_VERTEX]
		var box := AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
		_cache[key] = box
	return _cache[key]


## Scan piece `index` as forest-floor clutter: sunk `sink` of its height into the
## ground, shrinking away into it towards `view_range` metres (no popping), cut down
## to its first level of detail under `max_triangles` (small things need few).
static func floor_mesh(scan: String, index: int, sink: float, view_range: float, max_triangles := 100000) -> ArrayMesh:
	var key := "floor_%s_%d_%.2f_%.0f_%d" % [scan, index, sink, view_range, max_triangles]
	if _cache.has(key):
		return _cache[key]
	var p := _piece(scan, index, Transform3D.IDENTITY, piece_bounds(scan, index).size.y * sink)
	var arrays: Array = p[0]
	var lods: Dictionary = p[1]
	if (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 > max_triangles:
		var sizes := lods.keys()
		sizes.sort()
		for size: float in sizes:
			var idx: PackedInt32Array = lods[size]
			if idx.size() / 3 <= max_triangles:
				arrays[Mesh.ARRAY_INDEX] = idx
				break
		# Only the levels coarser than the new full detail stay.
		var kept := {}
		for size: float in sizes:
			if (lods[size] as PackedInt32Array).size() < (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size():
				kept[size] = lods[size]
		lods = kept
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	m.surface_set_material(0, scan_material(scan, view_range))
	_cache[key] = m
	return m


## Scales the view range the forest-floor materials shrink away at (graphics presets).
static func set_floor_range_scale(k: float) -> void:
	for key: String in _cache:
		if key.begins_with("scanmat_"):
			var mat: ShaderMaterial = _cache[key]
			var base: float = mat.get_meta("view_range", 0.0)
			if base > 0.0:
				mat.set_shader_parameter("fade_end", base * k)


## The shared material of a scan's pieces; with a `view_range` (forest-floor clutter)
## they shrink away into the ground before it.
static func scan_material(scan: String, view_range := 0.0) -> ShaderMaterial:
	var key := "scanmat_%s_%.0f" % [scan, view_range]
	if _cache.has(key):
		return _cache[key]
	var look: Dictionary = SCAN_LOOK.get(scan, {})
	var foliage: bool = look.get("foliage", false)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/nature_scan_foliage.gdshader" if foliage else "res://shaders/nature_scan.gdshader")
	var dir := (SCANS[scan][0] as String).get_base_dir() + "/textures/%s_%s_%s.jpg"
	var res: String = SCANS[scan][1]
	var arm: bool = look.get("arm", true)
	mat.set_shader_parameter("albedo_tex", load(dir % [scan, "diff", res]))
	mat.set_shader_parameter("normal_tex", load(dir % [scan, "nor_gl", res]))
	mat.set_shader_parameter("rough_tex", load(dir % [scan, "arm" if arm else "rough", res]))
	mat.set_shader_parameter("arm", arm)
	if foliage:
		mat.set_shader_parameter("alpha_tex", load(dir % [scan, "alpha", res]))
	for k: String in look:
		if k in ["foliage", "arm", "max_triangles"]:
			continue
		mat.set_shader_parameter(k, look[k])
	if view_range > 0.0:
		mat.set_meta("view_range", view_range)
		mat.set_shader_parameter("fade_end", view_range)
	_cache[key] = mat
	return mat


# --- Rocks -----------------------------------------------------------------------

## Scan pieces the breakable rocks wear: [scan, piece index]. Field rocks are the
## mossy granite boulders; quarry rocks (seed >= QUARRY_SEED) the bare, rust-veined ones.
const FIELD_ROCKS := [["rock_moss_set_01", 0], ["rock_moss_set_01", 1], ["rock_moss_set_01", 2], ["rock_moss_set_01", 3],
	["rock_moss_set_01", 4], ["rock_moss_set_01", 5], ["rock_moss_set_02", 0], ["rock_moss_set_02", 1],
	["rock_moss_set_02", 2], ["rock_moss_set_02", 4], ["rock_moss_set_02", 5], ["boulder_01", 0]]
const QUARRY_ROCKS := [["rock_09", 0], ["rock_moss_set_02", 0], ["rock_moss_set_02", 3], ["rock_moss_set_02", 6],
	["boulder_01", 0], ["rock_moss_set_02", 2]]
## Rock seeds from here on are quarry rocks (seed - QUARRY_SEED gives the shape).
const QUARRY_SEED := 100


static func rock(seed_value: int, size := 1.0) -> ArrayMesh:
	return _cached(_rock_key(seed_value, size), _make_rock.bind(seed_value, size))


## Collision hull of rock(seed_value, size), shared by every rock of that shape. It is
## made from the generated vertices, so the mesh is never read back from the GPU.
static func rock_shape(seed_value: int, size := 1.0) -> ConvexPolygonShape3D:
	rock(seed_value, size)
	return _rock_shapes[_rock_key(seed_value, size)]


static func _rock_key(seed_value: int, size: float) -> String:
	return "rock_%d_%.2f" % [seed_value, size]


## A boulder: the collision hull is the rounded shape the rocks always had (one blob and
## sometimes a smaller one beside it); the scanned rocks drawn are fitted into each blob,
## sunk a little into the ground.
static func _make_rock(seed_value: int, size: float) -> ArrayMesh:
	var shape_seed := seed_value % QUARRY_SEED
	var quarry := seed_value >= QUARRY_SEED
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed * 977 + 1
	var main := MeshBuilder.new()
	var scale := Vector3(rng.randf_range(1.0, 1.45), rng.randf_range(0.55, 0.8), rng.randf_range(0.85, 1.2)) * size
	var yaw := rng.randf() * TAU
	var xf := Transform3D(Basis.from_scale(scale).rotated(Vector3.UP, yaw), Vector3(0, 0.22 * scale.y, 0))
	main.blob(&"rock", xf, 0.85, 3, NEUTRAL, 0.38, 1.3, shape_seed, 0.0, true, -0.35)
	var side := MeshBuilder.new()
	var side_at := Vector3.ZERO
	if rng.randf() < 0.55:
		var a := rng.randf() * TAU
		side_at = Vector3(cos(a), 0.0, sin(a)) * 1.05 * size
		side.blob(&"rock", Transform3D(Basis.from_scale(Vector3(1.1, 0.65, 0.9)), side_at), 0.36 * size, 2, NEUTRAL,
				0.35, 1.8, shape_seed + 5, 0.0, true, -0.3)
	var points := main.vertices()
	points.append_array(side.vertices())
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	_rock_shapes[_rock_key(seed_value, size)] = hull
	# The rock origin is 0.15 * size below the ground (NatureSpawner).
	var ground := 0.15 * size
	var pool: Array = QUARRY_ROCKS if quarry else FIELD_ROCKS
	var pick: Array = pool[(shape_seed * 7 + int(size * 10.0)) % pool.size()]
	var p := _fit_scan(pick, main.vertices(), yaw, ground, 0.12)
	if not side.is_empty():
		# The small one beside it is another piece of the same scan (one material).
		var count := scan_pieces(pick[0]).size()
		var small := [pick[0], (int(pick[1]) + 1 + shape_seed) % count]
		p = _concat(p, _fit_scan(small, side.vertices(), yaw + 0.7, ground, 0.1))
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, p[0], [], p[1])
	m.surface_set_material(0, scan_material(pick[0]))
	return m


## [arrays, lods] of a scan piece stretched into the box of `points` (in the frame
## turned by `yaw`), its base sunk `sink` of its height below the box's bottom.
static func _fit_scan(pick: Array, points: PackedVector3Array, yaw: float, ground: float, sink: float) -> Array:
	var turn := Basis(Vector3.UP, yaw)
	var inv := turn.inverse()
	var box := AABB(inv * points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(inv * p)
	var own := piece_bounds(pick[0], pick[1])
	# Lay the piece's long side along the box's long side.
	var swap := (own.size.x > own.size.z) != (box.size.x > box.size.z)
	var tx := box.size.z if swap else box.size.x
	var tz := box.size.x if swap else box.size.z
	var s := Vector3(tx * 0.98 / maxf(own.size.x, 0.01), box.size.y * (1.0 + sink) / maxf(own.size.y, 0.01),
			tz * 0.98 / maxf(own.size.z, 0.01))
	# Keep the scan's proportions within reason (no rubber rocks).
	var mean := pow(s.x * s.y * s.z, 1.0 / 3.0)
	s = s.clamp(Vector3.ONE * mean * 0.7, Vector3.ONE * mean * 1.45)
	var basis := turn * (Basis(Vector3.UP, PI * 0.5) if swap else Basis()) * Basis.from_scale(s)
	var origin := turn * Vector3(box.get_center().x, box.position.y - box.size.y * sink, box.get_center().z)
	return _piece(pick[0], pick[1], Transform3D(basis, origin), (ground - origin.y) / s.y)


## Two [arrays, lods] joined into one (same material): LOD levels are paired in order.
static func _concat(a: Array, b: Array) -> Array:
	var out: Array = (a[0] as Array).duplicate(true)
	var bb: Array = b[0]
	var base := (out[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for ch in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR]:
		if out[ch] != null and bb[ch] != null:
			out[ch].append_array(bb[ch])
	var shifted := func(idx: PackedInt32Array) -> PackedInt32Array:
		var r := idx.duplicate()
		for i in r.size():
			r[i] += base
		return r
	var joined: PackedInt32Array = out[Mesh.ARRAY_INDEX]
	joined.append_array(shifted.call(bb[Mesh.ARRAY_INDEX]))
	out[Mesh.ARRAY_INDEX] = joined
	var ka: Array = (a[1] as Dictionary).keys()
	var kb: Array = (b[1] as Dictionary).keys()
	ka.sort()
	kb.sort()
	var lods := {}
	for i in ka.size():
		var ia: PackedInt32Array = (a[1][ka[i]] as PackedInt32Array).duplicate()
		var ib: PackedInt32Array = b[1][kb[mini(i, kb.size() - 1)]] if not kb.is_empty() else bb[Mesh.ARRAY_INDEX]
		ia.append_array(shifted.call(ib))
		lods[ka[i]] = ia
	return [out, lods]


# --- Ground cover ------------------------------------------------------------------

## Clump of grass blades. UV.x = blade height (m), UV.y = 0 at root .. 1 at tip.
static func grass_clump(seed_value: int, blades := 7) -> ArrayMesh:
	return _cached("grass_%d_%d" % [seed_value, blades], _make_grass.bind(seed_value, blades))


static func _make_grass(seed_value: int, blades: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 53 + 9
	var mb := MeshBuilder.new()
	var white := Color.WHITE
	for i in blades:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.2)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0, sin(facing))
		var lean := Vector3(-side.z, 0, side.x) * rng.randf_range(0.05, 0.25)
		var h := rng.randf_range(0.26, 0.62)
		var w := rng.randf_range(0.022, 0.04)
		var up := Vector3.UP
		var p0 := root - side * w * 0.5
		var p1 := root + side * w * 0.5
		var mid := root + up * h * 0.55 + lean * 0.35
		var p2 := mid - side * w * 0.36
		var p3 := mid + side * w * 0.36
		var tip := root + up * h + lean
		var n := up
		mb.tri_n(&"grass", p0, p1, p3, n, n, n, white, white, white, Vector2(h, 0), Vector2(h, 0), Vector2(h, 0.55))
		mb.tri_n(&"grass", p0, p3, p2, n, n, n, white, white, white, Vector2(h, 0), Vector2(h, 0.55), Vector2(h, 0.55))
		mb.tri_n(&"grass", p2, p3, tip, n, n, n, white, white, white, Vector2(h, 0.55), Vector2(h, 0.55), Vector2(h, 1.0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	return mb.build({&"grass": mat}, true)


static func flower(seed_value: int) -> ArrayMesh:
	return _cached("flower_%d" % seed_value, _make_flower.bind(seed_value))


static func _make_flower(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 29 + 7
	var mb := MeshBuilder.new()
	var petal: Color = FLOWER_COLORS[seed_value % FLOWER_COLORS.size()]
	var stem := Color("4f7a34")
	var count := rng.randi_range(2, 4)
	for i in count:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.15)
		var h := rng.randf_range(0.25, 0.42)
		var head := root + Vector3(rng.randf_range(-0.04, 0.04), h, rng.randf_range(-0.04, 0.04))
		mb.cylinder_between(&"evergreen", root, head, 0.008, 0.006, 3, stem, false, false)
		var petals := 6
		for p in petals:
			var pa := TAU * float(p) / petals + rng.randf() * 0.3
			var dir := Vector3(cos(pa), 0.2, sin(pa))
			mb.leaf(&"evergreen", head, dir, Vector3.UP, 0.05, 0.035, petal)
		mb.blob(&"evergreen", Transform3D(Basis(), head + Vector3(0, 0.008, 0)), 0.013, 0, Color("e9b93a"))
	mb.set_sway_by_height(&"evergreen", 0.0, 0.45, 0.6)
	return mb.build({}, true)
