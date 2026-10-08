class_name SeatProbe
extends RefCounted
## A vehicle's cab measured off its own drawn meshes, in the vehicle's body frame (+X left,
## +Y up, +Z ahead): rays through the triangles of everything under its "Model" that is
## shown (the body, the panes, the cab: not the wheels).
##
## Building the ray trees reads every mesh back from the renderer (a fifth of a second for
## a pickup): this is for the measuring step and the tests (seat23), not for a frame of
## play. What it finds is kept in the vehicle's table entry ("seat", see `measure`); only a
## kind whose entry keeps none is measured at play, once (Vehicle.seat).

## Ray trees of `v`: [TriangleMesh, body -> mesh, mesh -> body, the mesh's box (body frame)].
static func trees(v: Vehicle) -> Array:
	var out := []
	var holder := v.get_node_or_null("Model") as Node3D
	if holder == null:
		return out
	var inv := v.global_transform.affine_inverse()
	for mi: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var tm := mi.mesh.generate_triangle_mesh()
		if tm == null:
			continue
		var to_body := inv * mi.global_transform
		out.append([tm, to_body.affine_inverse(), to_body, (to_body * mi.get_aabb()).grow(0.001), String(mi.name)])
	return out


## The first thing of the vehicle on the way from `from` to `to` (body frame): where, or
## INF when nothing stands there.
static func cast(rays: Array, from: Vector3, to: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for t: Array in rays:
		if (t[3] as AABB).intersects_segment(from, to) == null and not (t[3] as AABB).has_point(from):
			continue
		var m: Transform3D = t[1]
		var hit: Dictionary = (t[0] as TriangleMesh).intersect_segment(m * from, m * to)
		if hit.is_empty():
			continue
		var p: Vector3 = (t[2] as Transform3D) * (hit["position"] as Vector3)
		var d := from.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


## Steps of the profiles (m), how much a cushion's top may rise and fall along it (its
## rake, its pleats), how long it is at least, how far the floor lies under its front edge
## at least, how far its top has rounded off where its front edge is taken to be, how far
## the seat's back rises behind it at least, and how far under the driver's eyes its top
## is looked for.
const STEP := 0.01
const TOP_BAND := 0.055
const TOP_MIN := 0.22
const EDGE_DROP := 0.1
const EDGE_ROUND := 0.025
const BACK_RISE := 0.2
const TOP_UNDER := Vector2(0.4, 1.0)
## Heights over the cushion (m) the seat's back is felt for at (where a sitter's rump is),
## and how far to either side of the seat's middle.
const BACK_AT: Array[float] = [0.03, 0.06, 0.09, 0.12, 0.16, 0.2]
const BESIDE := 0.08
## The seat is taken to reach this far to either side of where the passenger sits at most
## (a bench goes on to the driver's place).
const HALF_WIDTH := 0.3
## The door is felt for this far from the seat's middle (none nearer: this far); the
## driver's place is taken to begin this far from his eyes; and two cushions of a row are
## one to sit across when the gap between them is no wider than this (m).
const DOOR_OPEN := 0.6
## Heights over the cushion (m) the dashboard and the windscreen are felt for at (where a
## sitter's head is), and how far ahead of the seat's back (none nearer: this far).
const HEAD_AT: Array[float] = [0.15, 0.25, 0.35, 0.45, 0.55, 0.65]
const AHEAD_OPEN := 1.5
const DRIVER_HALF := 0.25
const SEAT_GAP_MAX := 0.05


## The passenger seat of `v` found on its meshes: across the cab from the driver's eyes,
## the level stretch with the floor dropping away before it and the seat's back rising
## behind it. Model frame (front +X, left -Z), as the vehicle table keeps it ("seat"):
##   "at"     the cushion's top at the foot of the seat's back, in the seat's middle
##   "depth"  from there to the cushion's front edge (m)
##   "width"  the cushion's width (m)
##   "pitch"  its rake: how much higher its front is (rad)
##   "door"   from the seat's middle to the door beside it, low over the cushion (m)
##   "inner"  from the seat's middle toward the driver as far as there is cushion (m)
##   "ahead"  from the foot of the seat's back to the dashboard or the windscreen, at the
##            height of a sitter's head (m)
## Empty when no seat is found.
static func measure(v: Vehicle) -> Dictionary:
	if not v.has_passenger_seat():
		return {}
	var rays := trees(v)
	if rays.is_empty():
		return {}
	var eye := v.driver_eye_local()
	var x := -eye.x
	var zs := PackedFloat32Array()
	var hs := PackedFloat32Array()
	var z := eye.z - 0.45
	while z <= eye.z + 0.9:
		zs.append(z)
		hs.append(_top(rays, x, eye.y, z))
		z += STEP
	var n := zs.size()
	var found := Vector2i(-1, -1)
	var off := INF
	var i := 0
	while i < n:
		if not is_finite(hs[i]):
			i += 1
			continue
		var j := i
		var lo := hs[i]
		var hi := hs[i]
		while j + 1 < n and is_finite(hs[j + 1]) and maxf(hi, hs[j + 1]) - minf(lo, hs[j + 1]) <= TOP_BAND:
			j += 1
			lo = minf(lo, hs[j])
			hi = maxf(hi, hs[j])
		var mid := (lo + hi) * 0.5
		var ok := zs[j] - zs[i] >= TOP_MIN and eye.y - mid >= TOP_UNDER.x and eye.y - mid <= TOP_UNDER.y
		if ok:
			# The floor before it, the seat's back behind it.
			var drop := false
			for k in range(j + 1, mini(j + 9, n)):
				if not is_finite(hs[k]) or hs[k] < mid - EDGE_DROP:
					drop = true
			var rise := false
			for k in range(maxi(i - 20, 0), i):
				if is_finite(hs[k]) and hs[k] > mid + BACK_RISE:
					rise = true
			ok = drop and rise
		if ok:
			var want := eye.z + 0.15
			var d := 0.0 if want >= zs[i] and want <= zs[j] else minf(absf(want - zs[i]), absf(want - zs[j]))
			if d < off:
				off = d
				found = Vector2i(i, j)
		i = j + 1
	if found.x < 0:
		return {}
	# The top as a raked line laid on its highest points (pleats, piping), three lines wide.
	var a := found.x + 2
	var b := found.y - 2
	var zc := (zs[a] + zs[b]) * 0.5
	var sz := 0.0
	var sy := 0.0
	var szz := 0.0
	var szy := 0.0
	var count := 0
	for k in range(a, b + 1):
		var dz := zs[k] - zc
		sz += dz
		sy += hs[k]
		szz += dz * dz
		szy += dz * hs[k]
		count += 1
	var slope := (szy - sz * sy / count) / maxf(szz - sz * sz / count, 1e-9)
	var level := sy / count - slope * sz / count
	var over := 0.0
	for k in range(a, b + 1):
		for side: float in [0.0, -BESIDE, BESIDE]:
			var h := hs[k] if side == 0.0 else _top(rays, x + side, eye.y, zs[k])
			if is_finite(h) and h - (level + slope * (zs[k] - zc)) < TOP_BAND:
				over = maxf(over, h - (level + slope * (zs[k] - zc)))
	level += over
	# The seat's back where a sitter's rump is: its foremost point low over the cushion.
	var foot := zs[found.x]
	var felt := false
	for up: float in BACK_AT:
		for side: float in [0.0, -BESIDE, BESIDE]:
			var from := Vector3(x + side, level + up, zc)
			var hit := cast(rays, from, from - Vector3(0, 0, 0.6))
			if hit.is_finite():
				foot = hit.z if not felt else maxf(foot, hit.z)
				felt = true
	# The front edge: where the top rounds off and falls away.
	var front := zc
	var zf := zc
	while zf < zs[found.y] + 0.05:
		zf += STEP * 0.2
		var h := _top(rays, x, eye.y, zf)
		if not is_finite(h) or h < level + slope * (zf - zc) - EDGE_ROUND:
			break
		front = zf
	# Its width, each way from where the passenger sits.
	var left := x
	var right := x
	for dir: float in [-1.0, 1.0]:
		var reach := 0.0
		while reach < HALF_WIDTH:
			var h := _top(rays, x + dir * (reach + STEP), eye.y, zc)
			if not is_finite(h) or absf(h - level) > TOP_BAND:
				break
			reach += STEP
		if dir < 0.0:
			left = x - reach
		else:
			right = x + reach
	var cx := (left + right) * 0.5
	# The door beside it, where a sitter's rump is: its nearest point.
	var out := signf(x)
	var door := DOOR_OPEN
	for up: float in BACK_AT:
		for zd: float in [foot + 0.1, zc, front - 0.08]:
			var from := Vector3(cx, level + slope * (zd - zc) + up, zd)
			var hit := cast(rays, from, from + Vector3(out * DOOR_OPEN, 0, 0))
			if hit.is_finite():
				door = minf(door, absf(hit.x - cx))
	# How far toward the driver there is cushion to sit on (a bench, the next seat of a
	# row: a gap between two cushions is stepped over), short of the driver's place.
	var inner := 0.0
	var gap := 0.0
	var reach := 0.0
	while reach < absf(eye.x - cx) - DRIVER_HALF:
		reach += STEP
		var h := _top(rays, cx - out * reach, eye.y, zc)
		if is_finite(h) and absf(h - level) <= TOP_BAND:
			inner = reach
			gap = 0.0
		else:
			gap += STEP
			if gap > SEAT_GAP_MAX:
				break
	# The dashboard and the windscreen ahead, where a sitter's head is: their nearest point.
	var ahead := AHEAD_OPEN
	for up: float in HEAD_AT:
		for side: float in [0.0, -BESIDE, BESIDE]:
			var from := Vector3(cx + side, level + up, foot + 0.1)
			var hit := cast(rays, from, from + Vector3(0, 0, AHEAD_OPEN))
			if hit.is_finite():
				ahead = minf(ahead, hit.z - foot)
	var at := Vector3(cx, level + slope * (foot - zc), foot)
	return {"at": v.to_model(at).snappedf(0.001), "depth": snappedf(front - foot, 0.001), "width": snappedf(right - left, 0.001),
		"pitch": snappedf(atan(slope), 0.001), "door": snappedf(door, 0.001), "inner": snappedf(inner, 0.001),
		"ahead": snappedf(ahead, 0.001)}


## The top of what stands under (x, from, z), body frame: its height, or -INF.
static func _top(rays: Array, x: float, from: float, z: float) -> float:
	var hit := cast(rays, Vector3(x, from, z), Vector3(x, from - 1.5, z))
	return hit.y if hit.is_finite() else -INF
