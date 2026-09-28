class_name ManureMound
extends RefCounted
## The manure heap's mound at each size step (see ManureHeap). No autoloads here, so
## tools/bake_tools.gd can build and bake every step.

## Most manure the heap holds (FarmState.MANURE_MAX).
const MAX := 60.0
const STEP := 6.0
const BAKED := "res://art/models/props/baked/manure_heap_%d.res"


## Number of size steps (the mound of the last one is full).
static func steps() -> int:
	return ceili(MAX / STEP)


## Builds the mound at size `step` (its size follows the step, not the exact amount).
static func build(step: int) -> ArrayMesh:
	var fill := clampf(step * STEP / MAX, 0.12, 1.0)
	var mb := MeshBuilder.new()
	# Forkfuls of rotted dung and soiled bedding dumped on top of each other: a low base
	# of photo-textured dirt, lumpy clods piled over it, and straw lying matted on top.
	var dung := Color(0.15, 0.1, 0.06)
	var size := 0.6 + 0.4 * fill
	var height := (0.3 + 0.5 * fill) * size
	var rx := 1.2 * size
	var rz := 1.0 * size
	var base := Transform3D(Basis.from_scale(Vector3(rx * 1.1, height * 0.7, rz * 1.1)), Vector3(0, -0.05, 0))
	mb.blob(&"dung", base, 1.0, 3, dung.darkened(0.15), 0.18, 1.5, 7, 0.06, true, -0.05)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in int(18 + fill * 40.0):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.95
		var u := cos(a) * r
		var v := sin(a) * r
		var dome := height * sqrt(maxf(1.0 - r * r, 0.0))
		var p := Vector3(u * rx, dome * 0.72 - 0.04, v * rz)
		var lump := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 0.55, 0.8)), p)
		var col := dung.darkened(rng.randf_range(-0.12, 0.25))
		mb.blob(&"dung", lump, rng.randf_range(0.16, 0.3) * size, 2, col, 0.45, 3.2, i + 11, 0.15, true, -0.3)
	# Bedding straw, lying along the surface: lighter where fresh on top.
	for i in int(120 + fill * 260.0):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.98
		var u := cos(a) * r
		var v := sin(a) * r
		var y := height * sqrt(maxf(1.0 - r * r, 0.0)) * 0.95
		var p := Vector3(u * rx, y, v * rz)
		var n := Vector3(u / rx, y / maxf(height * height, 0.0001) * height, v / rz).normalized()
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		d = (d - n * d.dot(n)).normalized()
		var top := y / maxf(height, 0.01)
		var col := Color(0.66, 0.53, 0.3).darkened(0.55 - top * 0.35 + rng.randf() * 0.15)
		mb.cylinder_between(&"straw", p + n * 0.012, p + n * 0.012 + d * rng.randf_range(0.1, 0.24), 0.008, 0.006, 3, col, false, false)
	return mb.build()
