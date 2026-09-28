@tool
class_name Anatomy
extends RefCounted
## Anatomical SDF definitions of the livestock, in meters for an adult, facing -Z,
## ground at y = 0. Each returns an AnimalBuilder ready to build.

const COAT := Color(0.93, 0.91, 0.87, 1.0)
const SOCK := Color(0.93, 0.91, 0.87, 0.0)
const HOOF := Color(0.13, 0.11, 0.1, 0.0)
const EYE := Color(0.05, 0.04, 0.035, 0.0)


static func _o(ab: AnimalBuilder, bone: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"bone": ab.bone_index(bone), "color": COAT}
	d.merge(extra, true)
	return d


static func _hoof_opts(ab: AnimalBuilder, bone: String) -> Dictionary:
	return _o(ab, bone, {"surface": AnimalBuilder.Surf.KERATIN, "color": HOOF, "fixed": 1.0, "gloss": 0.6, "fur": 0.0})


static func _eye_opts(ab: AnimalBuilder) -> Dictionary:
	return _o(ab, "head", {"surface": AnimalBuilder.Surf.EYE, "color": EYE, "fixed": 1.0, "fur": 0.0})


static func _add_quadruped_bones(ab: AnimalBuilder, front: Array, rear: Array) -> void:
	# front/rear: [x, [upper joint], [lower joint], [foot joint]] for the right side.
	for side: Array in [[-1.0, "l"], [1.0, "r"]]:
		var sx: float = side[0]
		var n: String = side[1]
		var fx := Vector3(sx, 1, 1)
		ab.add_bone("f%s_up" % n, "body", (front[0] as Vector3) * fx)
		ab.add_bone("f%s_lo" % n, "f%s_up" % n, (front[1] as Vector3) * fx)
		ab.add_bone("f%s_ft" % n, "f%s_lo" % n, (front[2] as Vector3) * fx)
		ab.add_bone("r%s_up" % n, "body", (rear[0] as Vector3) * fx)
		ab.add_bone("r%s_lo" % n, "r%s_up" % n, (rear[1] as Vector3) * fx)
		ab.add_bone("r%s_ft" % n, "r%s_lo" % n, (rear[2] as Vector3) * fx)


# --- Cow (Holstein) --------------------------------------------------------------------

static func cow() -> AnimalBuilder:
	var ab := AnimalBuilder.new()
	var s := SdfSculpt.new()
	ab.sculpt = s
	ab.cell = 0.02
	ab.set_eye_look(Color(0.17, 0.1, 0.06), Vector2(0.6, 0.3), 0.8)
	ab.add_bone("root", "", Vector3.ZERO)
	ab.add_bone("body", "root", Vector3(0, 1.05, 0.05))
	ab.add_bone("neck1", "body", Vector3(0, 1.18, -0.58))
	ab.add_bone("neck2", "neck1", Vector3(0, 1.28, -0.9))
	ab.add_bone("head", "neck2", Vector3(0, 1.33, -1.12))
	ab.add_bone("ear_l", "head", Vector3(-0.14, 1.34, -1.17))
	ab.add_bone("ear_r", "head", Vector3(0.14, 1.34, -1.17))
	ab.add_bone("tail1", "body", Vector3(0, 1.37, 0.96))
	ab.add_bone("tail2", "tail1", Vector3(0, 1.06, 1.04))
	ab.add_bone("tail3", "tail2", Vector3(0, 0.78, 1.05))
	_add_quadruped_bones(ab, [Vector3(0.19, 0.98, -0.56), Vector3(0.19, 0.51, -0.55), Vector3(0.19, 0.14, -0.55)],
			[Vector3(0.2, 1.02, 0.6), Vector3(0.2, 0.53, 0.74), Vector3(0.2, 0.14, 0.66)])

	var body := _o(ab, "body")
	# Barrel, belly and chest.
	s.ellipsoid(Vector3(0, 1.0, 0.05), Vector3(0.4, 0.43, 0.8), 0.12, body)
	s.ellipsoid(Vector3(0, 0.85, 0.08), Vector3(0.36, 0.3, 0.6), 0.14, body)
	s.ellipsoid(Vector3(0, 1.08, -0.48), Vector3(0.32, 0.4, 0.34), 0.12, body)
	s.ellipsoid(Vector3(0, 0.84, -0.62), Vector3(0.17, 0.2, 0.19), 0.1, body)
	s.ellipsoid(Vector3(0, 1.17, 0.62), Vector3(0.34, 0.3, 0.38), 0.1, body)
	# Topline, hook and pin bones, tail head.
	s.cone(Vector3(0, 1.36, -0.5), Vector3(0, 1.39, 0.72), 0.12, 0.12, 0.1, body)
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.25, 1.34, 0.56), Vector3(0.075, 0.05, 0.12), 0.11, body)
		s.ellipsoid(Vector3(sx * 0.11, 1.3, 0.91), Vector3(0.045, 0.038, 0.1), 0.1, body)
	s.cone(Vector3(0, 1.34, 0.86), Vector3(0, 1.38, 1.0), 0.08, 0.05, 0.06, body)
	# Udder with four teats.
	var skin := _o(ab, "body", {"surface": AnimalBuilder.Surf.SKIN, "color": Color(0.9, 0.7, 0.66, 0.0), "fixed": 1.0, "fur": 0.0, "gloss": 0.3})
	s.ellipsoid(Vector3(0, 0.69, 0.5), Vector3(0.17, 0.14, 0.2), 0.08, skin)
	for tx: float in [-0.06, 0.06]:
		for tz: float in [0.43, 0.59]:
			s.cone(Vector3(tx, 0.58, tz), Vector3(tx, 0.49, tz), 0.019, 0.014, 0.012, skin)

	# Neck and dewlap.
	s.cone(Vector3(0, 1.14, -0.52), Vector3(0, 1.25, -0.88), 0.3, 0.22, 0.12, _o(ab, "neck1"))
	s.cone(Vector3(0, 1.25, -0.88), Vector3(0, 1.32, -1.1), 0.22, 0.16, 0.1, _o(ab, "neck2"))
	s.ellipsoid(Vector3(0, 0.97, -0.84), Vector3(0.06, 0.2, 0.24), 0.1, _o(ab, "neck1"))

	# Head: broad forehead, long face, wide muzzle.
	var head := _o(ab, "head")
	s.ellipsoid(Vector3(0, 1.34, -1.18), Vector3(0.13, 0.12, 0.12), 0.08, head)
	s.ellipsoid(Vector3(0, 1.3, -1.25), Vector3(0.135, 0.12, 0.09), 0.08, head, Vector3(-30, 0, 0))
	s.cone(Vector3(0, 1.28, -1.25), Vector3(0, 1.04, -1.55), 0.115, 0.09, 0.08, head)
	s.ellipsoid(Vector3(0, 1.43, -1.15), Vector3(0.07, 0.04, 0.05), 0.05, head)
	s.ellipsoid(Vector3(0, 0.955, -1.5), Vector3(0.07, 0.05, 0.1), 0.06, head)
	var muzzle := _o(ab, "head", {"surface": AnimalBuilder.Surf.SKIN, "color": Color(0.62, 0.5, 0.5, 0.0), "fixed": 1.0, "fur": 0.0, "gloss": 0.55})
	s.ellipsoid(Vector3(0, 1.0, -1.59), Vector3(0.105, 0.085, 0.085), 0.05, muzzle)
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.08, 1.19, -1.3), Vector3(0.06, 0.1, 0.11), 0.06, head)
		s.ellipsoid(Vector3(sx * 0.105, 1.26, -1.29), Vector3(0.045, 0.04, 0.045), 0.03, head)
		ab.add_eye(Vector3(sx * 0.127, 1.24, -1.31), 0.024, "head", Vector3(sx, 0.15, -0.45), 0.36)
		var ear := _o(ab, "ear_r" if sx > 0.0 else "ear_l")
		s.ellipsoid(Vector3(sx * 0.24, 1.33, -1.18), Vector3(0.12, 0.03, 0.068), 0.04, ear, Vector3(0, -sx * 10.0, -sx * 15.0))

	# Legs.
	for sx: float in [-1.0, 1.0]:
		var n := "r" if sx > 0.0 else "l"
		var fx := sx * 0.19
		s.ellipsoid(Vector3(sx * 0.2, 1.12, -0.5), Vector3(0.12, 0.28, 0.2), 0.1, _o(ab, "f%s_up" % n), Vector3(0, 0, -sx * 8.0))
		s.cone(Vector3(fx, 1.0, -0.56), Vector3(fx, 0.53, -0.545), 0.13, 0.065, 0.08, _o(ab, "f%s_up" % n))
		s.ellipsoid(Vector3(fx, 0.51, -0.555), Vector3(0.066, 0.06, 0.066), 0.04, _o(ab, "f%s_lo" % n, {"color": SOCK}))
		s.cone(Vector3(fx, 0.5, -0.545), Vector3(fx, 0.16, -0.55), 0.055, 0.045, 0.04, _o(ab, "f%s_lo" % n, {"color": SOCK}))
		_lower_foot(ab, s, Vector3(fx, 0.14, -0.55), "f%s_ft" % n, true)
		var rx := sx * 0.2
		s.ellipsoid(Vector3(sx * 0.22, 1.02, 0.66), Vector3(0.14, 0.3, 0.26), 0.12, _o(ab, "r%s_up" % n))
		s.cone(Vector3(rx, 1.02, 0.6), Vector3(rx, 0.55, 0.74), 0.16, 0.065, 0.1, _o(ab, "r%s_up" % n))
		s.ellipsoid(Vector3(rx, 0.55, 0.8), Vector3(0.05, 0.075, 0.055), 0.04, _o(ab, "r%s_lo" % n, {"color": SOCK}))
		s.cone(Vector3(rx, 0.53, 0.73), Vector3(rx, 0.16, 0.66), 0.055, 0.045, 0.04, _o(ab, "r%s_lo" % n, {"color": SOCK}))
		_lower_foot(ab, s, Vector3(rx, 0.14, 0.66), "r%s_ft" % n, true)

	# Tail and its switch of hair.
	s.cone(Vector3(0, 1.38, 0.98), Vector3(0, 1.06, 1.05), 0.036, 0.026, 0.02, _o(ab, "tail1"))
	s.cone(Vector3(0, 1.06, 1.05), Vector3(0, 0.8, 1.06), 0.026, 0.02, 0.02, _o(ab, "tail2"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 12:
		var a := TAU * i / 12.0
		var o := Vector3(cos(a), 0, sin(a)) * 0.015
		var sway := Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.02, 0.03))
		ab.add_card(AnimalBuilder.Surf.HAIR_CARD, [Vector3(0, 0.84, 1.06) + o, Vector3(0, 0.7, 1.065) + o * 2.0 + sway * 0.5,
				Vector3(0, 0.56, 1.07) + o * 2.4 + sway], 0.06, Vector3(cos(a), 0, sin(a)), Rect2(rng.randf() * 0.6, 0, 0.4, 1), Color.WHITE, 0.2)

	# Nostrils (carved last).
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.045, 1.0, -1.668), Vector3(0.017, 0.013, 0.02), 0.012, _o(ab, "head", {"subtract": true}))
		s.cone(Vector3(sx * 0.1, 0.972, -1.52), Vector3(sx * 0.05, 0.968, -1.62), 0.007, 0.006, 0.01, _o(ab, "head", {"subtract": true}))
	return ab


## Fetlock, pastern and a cloven (cow, sheep) or solid (horse) hoof.
static func _lower_foot(ab: AnimalBuilder, s: SdfSculpt, fetlock: Vector3, bone: String, cloven: bool, scale := 1.0) -> void:
	var sock := _o(ab, bone, {"color": SOCK, "points": 1.0 if not cloven else 0.0})
	s.ellipsoid(fetlock, Vector3(0.055, 0.052, 0.058) * scale, 0.03 * scale, sock)
	s.cone(fetlock + Vector3(0, -0.01, -0.01) * scale, fetlock + Vector3(0, -0.07, -0.05) * scale, 0.046 * scale, 0.05 * scale, 0.02 * scale, sock)
	var hoof := _hoof_opts(ab, bone)
	var toe := fetlock + Vector3(0, -0.105, -0.07) * scale
	s.ellipsoid(toe, Vector3(0.066, 0.04, 0.085) * scale, 0.012 * scale, hoof)
	if cloven:
		s.ellipsoid(fetlock + Vector3(0, -0.03, 0.05) * scale, Vector3(0.02, 0.018, 0.02) * scale, 0.01 * scale, hoof)


# --- Horse ----------------------------------------------------------------------------

static func horse() -> AnimalBuilder:
	var ab := AnimalBuilder.new()
	var s := SdfSculpt.new()
	ab.sculpt = s
	ab.cell = 0.02
	ab.set_eye_look(Color(0.2, 0.11, 0.05), Vector2(0.62, 0.3), 0.82)
	ab.add_bone("root", "", Vector3.ZERO)
	ab.add_bone("body", "root", Vector3(0, 1.22, 0.02))
	ab.add_bone("neck1", "body", Vector3(0, 1.32, -0.5))
	ab.add_bone("neck2", "neck1", Vector3(0, 1.62, -0.8))
	ab.add_bone("head", "neck2", Vector3(0, 1.92, -0.99))
	ab.add_bone("ear_l", "head", Vector3(-0.05, 2.0, -0.98))
	ab.add_bone("ear_r", "head", Vector3(0.05, 2.0, -0.98))
	ab.add_bone("tail1", "body", Vector3(0, 1.44, 0.86))
	ab.add_bone("tail2", "tail1", Vector3(0, 1.2, 0.98))
	ab.add_bone("tail3", "tail2", Vector3(0, 0.92, 1.02))
	_add_quadruped_bones(ab, [Vector3(0.16, 1.04, -0.55), Vector3(0.16, 0.56, -0.56), Vector3(0.16, 0.19, -0.55)],
			[Vector3(0.17, 1.12, 0.6), Vector3(0.17, 0.62, 0.71), Vector3(0.17, 0.19, 0.645)])

	var body := _o(ab, "body")
	s.ellipsoid(Vector3(0, 1.2, 0.02), Vector3(0.3, 0.37, 0.7), 0.12, body)
	s.ellipsoid(Vector3(0, 1.06, 0.06), Vector3(0.27, 0.26, 0.5), 0.12, body)
	s.ellipsoid(Vector3(0, 1.2, -0.5), Vector3(0.26, 0.38, 0.3), 0.12, body)
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.1, 1.12, -0.7), Vector3(0.12, 0.16, 0.12), 0.08, body)
		s.ellipsoid(Vector3(sx * 0.23, 1.45, 0.42), Vector3(0.07, 0.06, 0.08), 0.07, body)
		s.ellipsoid(Vector3(sx * 0.13, 1.3, 0.74), Vector3(0.15, 0.26, 0.18), 0.08, _o(ab, "r%s_up" % ("r" if sx > 0.0 else "l")))
		s.ellipsoid(Vector3(sx * 0.19, 1.32, -0.44), Vector3(0.1, 0.3, 0.18), 0.08, _o(ab, "f%s_up" % ("r" if sx > 0.0 else "l")), Vector3(-20, 0, -sx * 6.0))
	s.cone(Vector3(0, 1.5, -0.5), Vector3(0, 1.53, -0.25), 0.11, 0.13, 0.08, body)
	s.cone(Vector3(0, 1.53, -0.25), Vector3(0, 1.53, 0.45), 0.13, 0.15, 0.1, body)
	s.ellipsoid(Vector3(0, 1.4, 0.58), Vector3(0.27, 0.26, 0.34), 0.1, body)
	s.cone(Vector3(0, 1.44, 0.8), Vector3(0, 1.4, 0.93), 0.06, 0.04, 0.05, _o(ab, "tail1"))

	# Neck: muscular crest on top, windpipe below.
	s.cone(Vector3(0, 1.3, -0.46), Vector3(0, 1.6, -0.8), 0.27, 0.18, 0.12, _o(ab, "neck1"))
	s.cone(Vector3(0, 1.6, -0.8), Vector3(0, 1.88, -0.97), 0.18, 0.12, 0.1, _o(ab, "neck2"))
	s.cone(Vector3(0, 1.52, -0.45), Vector3(0, 1.74, -0.72), 0.1, 0.085, 0.08, _o(ab, "neck1"))
	s.cone(Vector3(0, 1.74, -0.72), Vector3(0, 1.97, -0.94), 0.085, 0.065, 0.07, _o(ab, "neck2"))
	s.cone(Vector3(0, 1.22, -0.62), Vector3(0, 1.66, -1.02), 0.09, 0.07, 0.08, _o(ab, "neck2"))

	# Head: big rounded jowls, flat forehead, straight nasal bone, soft muzzle and lips.
	var head := _o(ab, "head")
	s.ellipsoid(Vector3(0, 1.93, -1.05), Vector3(0.095, 0.085, 0.1), 0.06, head)
	s.ellipsoid(Vector3(0, 1.89, -1.12), Vector3(0.1, 0.07, 0.09), 0.06, head, Vector3(-45, 0, 0))
	s.cone(Vector3(0, 1.86, -1.15), Vector3(0, 1.6, -1.37), 0.07, 0.055, 0.05, head)
	s.cone(Vector3(0, 1.76, -1.1), Vector3(0, 1.55, -1.33), 0.075, 0.05, 0.06, head)
	var muzzle := _o(ab, "head", {"points": 0.85, "gloss": 0.3})
	s.ellipsoid(Vector3(0, 1.56, -1.4), Vector3(0.062, 0.07, 0.068), 0.045, muzzle)
	s.ellipsoid(Vector3(0, 1.515, -1.42), Vector3(0.055, 0.03, 0.055), 0.025, muzzle)
	s.ellipsoid(Vector3(0, 1.5, -1.37), Vector3(0.042, 0.03, 0.045), 0.025, muzzle)
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.065, 1.79, -1.06), Vector3(0.065, 0.12, 0.12), 0.06, head, Vector3(-25, 0, 0))
		s.ellipsoid(Vector3(sx * 0.082, 1.895, -1.14), Vector3(0.035, 0.03, 0.04), 0.025, _o(ab, "head", {"color": Color(0.7, 0.68, 0.65, 1.0)}))
		ab.add_eye(Vector3(sx * 0.097, 1.885, -1.15), 0.024, "head", Vector3(sx, 0.1, -0.42), 0.36)
		var ear := _o(ab, "ear_r" if sx > 0.0 else "ear_l", {"points": 0.4})
		s.cone(Vector3(sx * 0.045, 1.99, -0.99), Vector3(sx * 0.065, 2.14, -0.97), 0.035, 0.006, 0.02, ear)

	# Legs: forearm, knee, cannon with tendons, fetlock, pastern, hoof.
	for sx: float in [-1.0, 1.0]:
		var n := "r" if sx > 0.0 else "l"
		var fx := sx * 0.16
		s.cone(Vector3(fx, 1.06, -0.54), Vector3(fx, 0.58, -0.56), 0.11, 0.06, 0.08, _o(ab, "f%s_up" % n))
		var lo := _o(ab, "f%s_lo" % n, {"points": 1.0})
		s.ellipsoid(Vector3(fx, 0.56, -0.57), Vector3(0.058, 0.065, 0.06), 0.04, lo)
		s.cone(Vector3(fx, 0.55, -0.56), Vector3(fx, 0.21, -0.55), 0.048, 0.042, 0.03, lo)
		s.cone(Vector3(fx, 0.5, -0.53), Vector3(fx, 0.23, -0.525), 0.028, 0.028, 0.03, lo)
		_horse_foot(ab, s, Vector3(fx, 0.19, -0.545), "f%s_ft" % n)
		var rx := sx * 0.17
		s.cone(Vector3(rx, 1.12, 0.6), Vector3(rx, 0.64, 0.72), 0.15, 0.06, 0.1, _o(ab, "r%s_up" % n))
		var rlo := _o(ab, "r%s_lo" % n, {"points": 1.0})
		s.ellipsoid(Vector3(rx, 0.63, 0.77), Vector3(0.045, 0.07, 0.05), 0.04, rlo)
		s.cone(Vector3(rx, 0.62, 0.71), Vector3(rx, 0.21, 0.645), 0.05, 0.043, 0.03, rlo)
		s.cone(Vector3(rx, 0.58, 0.745), Vector3(rx, 0.23, 0.67), 0.028, 0.028, 0.03, rlo)
		_horse_foot(ab, s, Vector3(rx, 0.19, 0.64), "r%s_ft" % n)

	# Nostrils.
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.03, 1.58, -1.46), Vector3(0.015, 0.026, 0.02), 0.01, _o(ab, "head", {"subtract": true}), Vector3(-35, 0, 0))

	# Mane and forelock are placed on the finished surface; the tail hangs free.
	ab.card_builders.append(_horse_mane)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf() * 0.2
		var r := rng.randf_range(0.01, 0.045)
		var o := Vector3(cos(a) * r, 0, sin(a) * r * 0.7)
		var length := rng.randf_range(0.75, 0.95)
		var sway := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(0.0, 0.06))
		var top := Vector3(0, 1.42, 0.9) + o
		ab.add_card(AnimalBuilder.Surf.HAIR_CARD, [top, top + Vector3(0, -0.08, 0.1) + o, top + Vector3(0, -length * 0.4, 0.2) + o * 1.8 + sway * 0.5,
				top + Vector3(0, -length * 0.75, 0.22) + o * 2.2 + sway, top + Vector3(0, -length, 0.2) + o * 2.4 + sway * 1.3],
				rng.randf_range(0.07, 0.1), Vector3(cos(a), 0.1, sin(a)).normalized(), Rect2(rng.randf() * 0.5, 0.0, 0.5, 1.0),
				Color(1, 1, 1).darkened(rng.randf() * 0.2), 0.25)
	return ab


## Mane strands lying along the crest (mostly on the right side) and a forelock.
static func _horse_mane(ab: AnimalBuilder) -> void:
	var s := ab.sculpt
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var crest: Array[Vector3] = [Vector3(0, 1.98, -0.98), Vector3(0, 1.86, -0.9), Vector3(0, 1.74, -0.8),
		Vector3(0, 1.64, -0.7), Vector3(0, 1.57, -0.6), Vector3(0, 1.53, -0.5), Vector3(0, 1.5, -0.42)]
	for i in 64:
		var t := float(i) / 63.0
		var fi := t * (crest.size() - 1)
		var c := crest[int(fi)].lerp(crest[mini(int(fi) + 1, crest.size() - 1)], fi - int(fi))
		var top := s.raycast(c + Vector3(0, 0.5, 0), Vector3.DOWN, 1.0) + Vector3(0, 0.012, 0)
		# The mane falls to the right; a few short strands on the left give it body.
		var left := rng.randf() < 0.15
		var side := -1.0 if left else 1.0
		var length := rng.randf_range(0.16, 0.24)
		if left:
			length = rng.randf_range(0.06, 0.1)
		length *= clampf(0.45 + t * 3.0, 0.45, 1.0) * clampf((1.0 - t) * 5.0 + 0.4, 0.4, 1.0)
		var pts: Array = [top]
		for k in 3:
			var drop := length * (k + 1) / 3.0
			var probe := top + Vector3(0, -drop, 0.03 * (k + 1) + rng.randf_range(-0.01, 0.01))
			pts.append(s.project_out(probe, Vector3(side, 0.15, 0), 0.012 + 0.006 * k))
		var out := Vector3(side, 0.4, 0.1).normalized()
		ab.add_card(AnimalBuilder.Surf.HAIR_CARD, pts, rng.randf_range(0.09, 0.13), out,
				Rect2(rng.randf() * 0.5, 0.0, 0.5, 1.0), Color(1, 1, 1).darkened(rng.randf() * 0.15), 0.35)
	for i in 5:
		var x := (i - 2) * 0.022
		var root := s.raycast(Vector3(x, 2.4, -1.02), Vector3.DOWN, 1.0) + Vector3(0, 0.01, 0)
		var p1 := s.project_out(root + Vector3(0, -0.07, -0.07), Vector3(0, 0.3, -1), 0.012)
		var p2 := s.project_out(root + Vector3(x * 0.4, -0.15, -0.12), Vector3(0, 0.3, -1), 0.014)
		ab.add_card(AnimalBuilder.Surf.HAIR_CARD, [root, p1, p2], 0.06, Vector3(0, 0.5, -1).normalized(),
				Rect2(rng.randf() * 0.5, 0.0, 0.5, 1.0), Color.WHITE, 0.4)


static func _horse_foot(ab: AnimalBuilder, s: SdfSculpt, fetlock: Vector3, bone: String) -> void:
	var sock := _o(ab, bone, {"points": 1.0})
	s.ellipsoid(fetlock, Vector3(0.05, 0.055, 0.058), 0.03, sock)
	s.cone(fetlock + Vector3(0, -0.02, -0.01), fetlock + Vector3(0, -0.1, -0.055), 0.042, 0.046, 0.02, sock)
	var hoof := _hoof_opts(ab, bone)
	hoof["fixed"] = 0.0
	hoof["points"] = 1.0
	hoof["color"] = Color(0.3, 0.28, 0.26, 0.0)
	s.cone(fetlock + Vector3(0, -0.1, -0.06), fetlock + Vector3(0, -0.18, -0.08), 0.05, 0.064, 0.01, hoof)


# --- Sheep ------------------------------------------------------------------------------

static func sheep() -> AnimalBuilder:
	var ab := AnimalBuilder.new()
	var s := SdfSculpt.new()
	ab.sculpt = s
	ab.cell = 0.014
	ab.set_eye_look(Color(0.66, 0.48, 0.18), Vector2(0.64, 0.2), 0.86)
	ab.add_bone("root", "", Vector3.ZERO)
	ab.add_bone("body", "root", Vector3(0, 0.6, 0.0))
	ab.add_bone("neck1", "body", Vector3(0, 0.68, -0.34))
	ab.add_bone("head", "neck1", Vector3(0, 0.84, -0.52))
	ab.add_bone("ear_l", "head", Vector3(-0.07, 0.86, -0.53))
	ab.add_bone("ear_r", "head", Vector3(0.07, 0.86, -0.53))
	ab.add_bone("tail1", "body", Vector3(0, 0.66, 0.5))
	_add_quadruped_bones(ab, [Vector3(0.12, 0.44, -0.3), Vector3(0.12, 0.22, -0.3), Vector3(0.12, 0.07, -0.3)],
			[Vector3(0.12, 0.46, 0.3), Vector3(0.12, 0.24, 0.36), Vector3(0.12, 0.07, 0.33)])
	var wool := _o(ab, "body", {"surface": AnimalBuilder.Surf.WOOL, "noise": [0.028, 14.0]})
	s.ellipsoid(Vector3(0, 0.63, 0.0), Vector3(0.34, 0.33, 0.55), 0.1, wool)
	s.ellipsoid(Vector3(0, 0.64, 0.33), Vector3(0.31, 0.3, 0.3), 0.1, wool)
	s.ellipsoid(Vector3(0, 0.64, -0.32), Vector3(0.28, 0.3, 0.26), 0.1, wool)
	s.cone(Vector3(0, 0.64, 0.5), Vector3(0, 0.5, 0.58), 0.06, 0.04, 0.05, _o(ab, "tail1", {"surface": AnimalBuilder.Surf.WOOL, "noise": [0.012, 20.0]}))
	s.cone(Vector3(0, 0.68, -0.3), Vector3(0, 0.8, -0.48), 0.22, 0.13, 0.08, _o(ab, "neck1", {"surface": AnimalBuilder.Surf.WOOL, "noise": [0.022, 16.0]}))
	for sx: float in [-1.0, 1.0]:
		var n := "r" if sx > 0.0 else "l"
		s.cone(Vector3(sx * 0.13, 0.5, -0.3), Vector3(sx * 0.12, 0.26, -0.3), 0.085, 0.05, 0.06, _o(ab, "f%s_up" % n, {"surface": AnimalBuilder.Surf.WOOL, "noise": [0.015, 18.0]}))
		s.cone(Vector3(sx * 0.13, 0.52, 0.3), Vector3(sx * 0.12, 0.28, 0.35), 0.1, 0.055, 0.06, _o(ab, "r%s_up" % n, {"surface": AnimalBuilder.Surf.WOOL, "noise": [0.015, 18.0]}))

	var face := _o(ab, "head", {"points": 1.0})
	s.cone(Vector3(0, 0.86, -0.52), Vector3(0, 0.72, -0.72), 0.07, 0.045, 0.05, face)
	s.ellipsoid(Vector3(0, 0.84, -0.53), Vector3(0.075, 0.07, 0.07), 0.05, face)
	s.ellipsoid(Vector3(0, 0.705, -0.735), Vector3(0.045, 0.04, 0.045), 0.03, face)
	s.ellipsoid(Vector3(0, 0.9, -0.5), Vector3(0.085, 0.065, 0.085), 0.04, _o(ab, "head", {"surface": AnimalBuilder.Surf.WOOL, "noise": [0.01, 22.0]}))
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.045, 0.8, -0.58), Vector3(0.04, 0.05, 0.06), 0.03, face)
		ab.add_eye(Vector3(sx * 0.07, 0.815, -0.585), 0.016, "head", Vector3(sx, 0.2, -0.32), 0.36)
		var ear := _o(ab, "ear_r" if sx > 0.0 else "ear_l", {"points": 1.0})
		s.ellipsoid(Vector3(sx * 0.11, 0.84, -0.53), Vector3(0.08, 0.02, 0.035), 0.02, ear, Vector3(0, 0, -sx * 25.0))
		var n := "r" if sx > 0.0 else "l"
		s.cone(Vector3(sx * 0.12, 0.24, -0.3), Vector3(sx * 0.12, 0.08, -0.3), 0.026, 0.022, 0.02, _o(ab, "f%s_lo" % n, {"points": 1.0}))
		_lower_foot(ab, s, Vector3(sx * 0.12, 0.07, -0.3), "f%s_ft" % n, true, 0.5)
		s.cone(Vector3(sx * 0.12, 0.26, 0.36), Vector3(sx * 0.12, 0.08, 0.33), 0.028, 0.022, 0.02, _o(ab, "r%s_lo" % n, {"points": 1.0}))
		_lower_foot(ab, s, Vector3(sx * 0.12, 0.07, 0.33), "r%s_ft" % n, true, 0.5)
		s.ellipsoid(Vector3(sx * 0.02, 0.715, -0.775), Vector3(0.008, 0.01, 0.01), 0.006, _o(ab, "head", {"subtract": true}))
	return ab


# --- Chicken ----------------------------------------------------------------------------

static func chicken() -> AnimalBuilder:
	var ab := AnimalBuilder.new()
	var s := SdfSculpt.new()
	ab.sculpt = s
	ab.cell = 0.006
	ab.set_eye_look(Color(0.88, 0.52, 0.12), Vector2(0.42, 0.42), 0.9)
	ab.add_bone("root", "", Vector3.ZERO)
	ab.add_bone("body", "root", Vector3(0, 0.27, 0.0))
	ab.add_bone("neck1", "body", Vector3(0, 0.33, -0.1))
	ab.add_bone("head", "neck1", Vector3(0, 0.44, -0.135))
	ab.add_bone("tail1", "body", Vector3(0, 0.34, 0.14))
	ab.add_bone("wing_l", "body", Vector3(-0.1, 0.31, -0.03))
	ab.add_bone("wing_r", "body", Vector3(0.1, 0.31, -0.03))
	for side: Array in [[-1.0, "l"], [1.0, "r"]]:
		var sx: float = side[0]
		var n: String = side[1]
		ab.add_bone("f%s_up" % n, "body", Vector3(sx * 0.05, 0.2, 0.02))
		ab.add_bone("f%s_lo" % n, "f%s_up" % n, Vector3(sx * 0.05, 0.13, 0.03))
		ab.add_bone("f%s_ft" % n, "f%s_lo" % n, Vector3(sx * 0.05, 0.022, 0.005))
	var feather := _o(ab, "body", {"surface": AnimalBuilder.Surf.FEATHER})
	s.ellipsoid(Vector3(0, 0.27, 0.02), Vector3(0.12, 0.12, 0.17), 0.06, feather)
	s.ellipsoid(Vector3(0, 0.26, -0.09), Vector3(0.105, 0.115, 0.1), 0.05, feather)
	s.cone(Vector3(0, 0.32, 0.02), Vector3(0, 0.36, 0.16), 0.09, 0.05, 0.05, _o(ab, "tail1", {"surface": AnimalBuilder.Surf.FEATHER}))
	s.ellipsoid(Vector3(0, 0.19, 0.05), Vector3(0.09, 0.07, 0.1), 0.05, feather)
	s.cone(Vector3(0, 0.31, -0.1), Vector3(0, 0.43, -0.135), 0.07, 0.04, 0.04, _o(ab, "neck1", {"surface": AnimalBuilder.Surf.FEATHER}))
	s.ellipsoid(Vector3(0, 0.36, -0.1), Vector3(0.075, 0.07, 0.07), 0.04, _o(ab, "neck1", {"surface": AnimalBuilder.Surf.FEATHER}))
	s.ellipsoid(Vector3(0, 0.455, -0.14), Vector3(0.036, 0.04, 0.046), 0.02, _o(ab, "head", {"surface": AnimalBuilder.Surf.FEATHER}))
	var red := _o(ab, "head", {"surface": AnimalBuilder.Surf.SKIN, "color": Color(0.8, 0.08, 0.06, 0.0), "fixed": 1.0, "fur": 0.0, "gloss": 0.3})
	var comb := red.duplicate()
	comb["adult_only"] = true
	for i in 5:
		var z := -0.105 - i * 0.014
		s.ellipsoid(Vector3(0, 0.49 + 0.012 * sin(i * 1.3 + 0.5), z), Vector3(0.006, 0.02 - absf(i - 2) * 0.003, 0.01), 0.006, comb)
	for sx: float in [-1.0, 1.0]:
		s.ellipsoid(Vector3(sx * 0.022, 0.455, -0.157), Vector3(0.018, 0.02, 0.02), 0.006, red)
		s.ellipsoid(Vector3(sx * 0.01, 0.412, -0.17), Vector3(0.011, 0.022, 0.012), 0.006, comb)
		ab.add_eye(Vector3(sx * 0.032, 0.462, -0.153), 0.0075, "head", Vector3(sx, 0.05, -0.28), 0.34)
	var beak := _o(ab, "head", {"surface": AnimalBuilder.Surf.KERATIN, "color": Color(0.86, 0.7, 0.34, 0.0), "fixed": 1.0, "gloss": 0.5, "fur": 0.0})
	s.cone(Vector3(0, 0.458, -0.176), Vector3(0, 0.446, -0.205), 0.014, 0.002, 0.004, beak)
	var yellow := Color(0.9, 0.72, 0.3, 0.0)
	for sx: float in [-1.0, 1.0]:
		var n := "r" if sx > 0.0 else "l"
		s.ellipsoid(Vector3(sx * 0.11, 0.3, 0.02), Vector3(0.03, 0.08, 0.13), 0.02, _o(ab, "wing_%s" % n, {"surface": AnimalBuilder.Surf.FEATHER}), Vector3(-10, 0, -sx * 8.0))
		s.ellipsoid(Vector3(sx * 0.055, 0.19, 0.02), Vector3(0.042, 0.06, 0.05), 0.03, _o(ab, "f%s_up" % n, {"surface": AnimalBuilder.Surf.FEATHER}))
		var leg := _o(ab, "f%s_lo" % n, {"surface": AnimalBuilder.Surf.KERATIN, "color": yellow, "fixed": 1.0, "gloss": 0.3, "fur": 0.0})
		s.cone(Vector3(sx * 0.05, 0.14, 0.03), Vector3(sx * 0.05, 0.025, 0.006), 0.011, 0.009, 0.006, leg)
		var foot := _o(ab, "f%s_ft" % n, {"surface": AnimalBuilder.Surf.KERATIN, "color": yellow, "fixed": 1.0, "gloss": 0.3, "fur": 0.0})
		var ankle := Vector3(sx * 0.05, 0.02, 0.006)
		for t in 4:
			var ang := (t - 1) * 0.5 if t < 3 else PI
			var dir := Vector3(sin(ang), 0, -cos(ang))
			var length := 0.055 if t < 3 else 0.028
			s.cone(ankle, ankle + dir * length + Vector3(0, -0.012, 0), 0.007, 0.004, 0.004, foot)
	# Tail and wing feathers as cards.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 11:
		var t := float(i) / 10.0
		var x := (t - 0.5) * 0.06
		var rise := rng.randf_range(0.14, 0.2)
		var base := Vector3(x, 0.34, 0.15)
		var back := rng.randf_range(0.08, 0.14)
		ab.add_card(AnimalBuilder.Surf.FEATHER_CARD, [base, base + Vector3(x * 0.4, rise * 0.55, back * 0.4),
				base + Vector3(x * 0.8, rise, back), base + Vector3(x, rise * 1.05, back * 1.5)],
				rng.randf_range(0.04, 0.055), Vector3(1, 0, 0) if x >= 0.0 else Vector3(-1, 0, 0), Rect2(0, 0, 1, 1), Color.WHITE, 0.5)
	# Folded primaries at the back edge of each wing.
	for sx: float in [-1.0, 1.0]:
		for i in 4:
			var base := Vector3(sx * 0.128, 0.325 - i * 0.012, 0.03 + i * 0.022)
			ab.add_card(AnimalBuilder.Surf.FEATHER_CARD, [base, base + Vector3(sx * 0.004, -0.012, 0.05), base + Vector3(sx * 0.002, -0.02, 0.095)],
					0.04, Vector3(sx, 0.15, 0).normalized(), Rect2(0, 0, 1, 1), Color.WHITE.darkened(0.06 * i), 0.45)
	return ab
