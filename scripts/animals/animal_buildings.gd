class_name AnimalBuildings
extends RefCounted
## Closed barn and coop models built around a local origin at the footprint
## center (door on the +Z side). Each returns {mesh, straw_mesh, colliders: [[center,
## size]]}: straw_mesh is drawn without shadows, so it holds what is thinner than a
## shadow texel: the barn's loose bedding stalks and both buildings' small trim
## (battens, glazing bars, rafter tails, door hardware).
## Board-and-batten walls (battens over the photo's joints), trimmed doors and glazed
## windows, tiled roofs laid in courses on rafters with fascia, barge boards and
## gutters.
## The coop leaves its door leaf out with `with_door` false (the kit-built coop hangs a
## CoopDoor that opens and shuts there instead); a kit-built coop made longer has its
## door off the middle (`door_x`) and its newer east end (`ext`) told by fresher boards.

const PLANK := Color(0.6, 0.44, 0.4)
const PLANK_DARK := Color(0.42, 0.34, 0.31)
const STONE := Color(0.52, 0.51, 0.5)
const ROOF := Color(0.46, 0.45, 0.45)
const TRIM := Color(0.88, 0.86, 0.8)
const BATTEN := Color(0.5, 0.38, 0.34)


static func barn(size: Vector2) -> Dictionary:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var w := size.x
	var d := size.y
	var wall_h := 3.3
	var t := 0.18
	var base_h := 0.35
	var door_w := 3.4
	var door_h := 2.9
	# Stone footing and a straw-covered earth floor.
	for side: Array in [[Vector3(0, base_h * 0.5, -d * 0.5 + t * 0.5), Vector3(w, base_h, t + 0.1)],
			[Vector3(-w * 0.5 + t * 0.5, base_h * 0.5, 0), Vector3(t + 0.1, base_h, d)],
			[Vector3(w * 0.5 - t * 0.5, base_h * 0.5, 0), Vector3(t + 0.1, base_h, d)]]:
		mb.box_at(&"stone_ext", side[0], side[1], STONE)
	for sx: float in [-1.0, 1.0]:
		var seg := (w - door_w) * 0.5
		mb.box_at(&"stone_ext", Vector3(sx * (door_w * 0.5 + seg * 0.5), base_h * 0.5, d * 0.5 - t * 0.5), Vector3(seg, base_h, t + 0.1), STONE)
	mb.box_at(&"barn_floor", Vector3(0, 0.02, 0), Vector3(w - 0.3, 0.04, d - 0.3), Color(0.5, 0.5, 0.5))
	# Loose straw bedding: clusters of individual stalks on the earth floor.
	var straw := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for c in 22:
		var center := Vector3(rng.randf_range(-w * 0.42, w * 0.42), 0.04, rng.randf_range(-d * 0.42, d * 0.42))
		var radius := rng.randf_range(0.4, 1.0)
		for k in 60:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * radius
			var p := center + Vector3(cos(a) * r, rng.randf_range(0.0, 0.03), sin(a) * r)
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.05, 0.15), rng.randf_range(-1, 1)).normalized()
			var col := Color(0.8, 0.66, 0.36).lightened(rng.randf_range(-0.2, 0.12))
			straw.cylinder_between(&"veg", p, p + dir * rng.randf_range(0.12, 0.3), 0.004, 0.003, 3, col, false, false)
	# Walls: vertical board siding above the footing, battens over the joints.
	var wy := base_h + (wall_h - base_h) * 0.5
	var wh := wall_h - base_h
	_wall(mb, cols, Vector3(0, wy, -d * 0.5 + t * 0.5), Vector3(w, wh, t), PLANK, Vector3.FORWARD, straw)
	var win_z := d * 0.22
	for sx: float in [-1.0, 1.0]:
		# Side walls: no battens over the two windows.
		var c := Vector3(sx * (w * 0.5 - t * 0.5), wy, 0)
		var ws := Vector3(t, wh, d - t * 2.0)
		mb.box_at(&"planks_ext", c, ws, PLANK, Vector3.ZERO, true)
		cols.append([c, ws])
		BuildingKit.battens(straw, &"paint_ext", Transform3D(Basis(), c), ws, Vector3(sx, 0, 0), BATTEN, 2,
				[Vector2(-win_z - 0.56, -win_z + 0.56), Vector2(win_z - 0.56, win_z + 0.56)])
	var seg := (w - door_w) * 0.5
	for sx: float in [-1.0, 1.0]:
		_wall(mb, cols, Vector3(sx * (door_w * 0.5 + seg * 0.5), wy, d * 0.5 - t * 0.5), Vector3(seg, wh, t), PLANK, Vector3.BACK, straw)
	# Header above the door.
	var header := Vector3(0, door_h + (wall_h - door_h) * 0.5, d * 0.5 - t * 0.5)
	mb.box_at(&"planks_ext", header, Vector3(door_w, wall_h - door_h, t), PLANK, Vector3.ZERO, true)
	BuildingKit.battens(straw, &"paint_ext", Transform3D(Basis(), header), Vector3(door_w, wall_h - door_h, t), Vector3.BACK, BATTEN)
	# Trim round the doorway (the grain along each piece).
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"paint_ext", Vector3(sx * (door_w * 0.5 + 0.06), door_h * 0.5 + 0.1, d * 0.5 + 0.02), Vector3(0.12, door_h - 0.2, 0.04), TRIM)
	mb.box_at(&"paint_ext", Vector3(0, door_h + 0.06, d * 0.5 + 0.02), Vector3(door_w + 0.24, 0.12, 0.04), TRIM, Vector3.ZERO, true)
	# Sliding doors parked beside the opening, with the X brace and a rail.
	for sx: float in [-1.0, 1.0]:
		var dc := Vector3(sx * (door_w * 0.5 + door_w * 0.25 + 0.05), door_h * 0.5 + 0.05, d * 0.5 + 0.08)
		mb.box_at(&"planks_ext", dc, Vector3(door_w * 0.5, door_h, 0.07), PLANK.darkened(0.05), Vector3.ZERO, true)
		var hw := door_w * 0.25 - 0.08
		var hh := door_h * 0.5 - 0.08
		for diag: float in [1.0, -1.0]:
			var ang := atan2(hh * 2.0, hw * 2.0) * diag
			mb.box_at(&"paint_ext", dc + Vector3(0, 0, 0.045), Vector3(sqrt(hw * hw * 4.0 + hh * hh * 4.0), 0.1, 0.02), TRIM,
					Vector3(0, 0, rad_to_deg(ang)), true)
		for border: Array in [[Vector3(0, hh, 0.045), Vector3(door_w * 0.5, 0.1, 0.02)], [Vector3(0, -hh, 0.045), Vector3(door_w * 0.5, 0.1, 0.02)],
				[Vector3(hw, 0, 0.045), Vector3(0.1, door_h, 0.02)], [Vector3(-hw, 0, 0.045), Vector3(0.1, door_h, 0.02)]]:
			var bs: Vector3 = border[1]
			mb.box_at(&"paint_ext", dc + border[0], bs, TRIM, Vector3.ZERO, bs.x > bs.y)
	var iron := Color(0.2, 0.2, 0.2)
	mb.box_at(&"steel", Vector3(0, door_h + 0.12, d * 0.5 + 0.1), Vector3(door_w * 2.1, 0.06, 0.06), iron)
	# Hangers and rollers on the rail, a pull on each leaf.
	for sx: float in [-1.0, 1.0]:
		var dx := sx * (door_w * 0.5 + door_w * 0.25 + 0.05)
		for hx: float in [-0.55, 0.55]:
			straw.box_at(&"steel", Vector3(dx + hx, door_h + 0.08, d * 0.5 + 0.125), Vector3(0.05, 0.16, 0.012), iron)
			straw.cylinder_between(&"steel", Vector3(dx + hx, door_h + 0.16, d * 0.5 + 0.08), Vector3(dx + hx, door_h + 0.16, d * 0.5 + 0.14),
					0.05, 0.05, 10, iron)
		straw.box_at(&"steel", Vector3(dx - sx * (door_w * 0.25 - 0.18), 1.1, d * 0.5 + 0.14), Vector3(0.03, 0.3, 0.03), iron)
	# Small high windows on the side walls: glazed, four panes, dark inside.
	for sx: float in [-1.0, 1.0]:
		for wz: float in [-d * 0.22, d * 0.22]:
			_window(mb, straw, Vector3(sx * w * 0.5, 2.4, wz), Vector3(sx, 0, 0), 0.9, 0.7)
	# Gable roof along X: tiles in courses on a board deck and rafters, fascia and barge
	# boards, ridge tiles, gutters and downpipes.
	var rise := d * 0.36
	var theta := atan2(rise, d * 0.5)
	var run := d * 0.5 + 0.5
	var slab_len := run / cos(theta)
	var ridge_y := wall_h + rise
	var deck := 0.12
	var length := w + 0.8
	var apex := Vector3(0, ridge_y + deck / cos(theta), 0)
	for side: float in [1.0, -1.0]:
		var frame := BuildingKit.slope_frame(apex, theta, side)
		var edge := BuildingKit.roof_trim(mb, frame, length, 0.0, slab_len, d * 0.5 / cos(theta), &"paint_ext", TRIM, &"wood_in",
				PLANK_DARK, deck, -1.0, straw)
		BuildingKit.roof_courses(mb, &"roof", frame, length + 0.06, 0.0, slab_len + 0.06, ROOF, rng)
		var out := Vector3(0, 0, side)
		var g := edge + out * 0.075 + Vector3(0, -0.035, 0)
		BuildingKit.gutter(mb, g - Vector3(length * 0.5 - 0.02, 0, 0), g + Vector3(length * 0.5 - 0.02, 0, 0), out)
		var px := (w * 0.5 - 0.3) * side
		BuildingKit.downpipe(mb, Vector3(px, g.y - 0.05, g.z), Vector3(px, 0, side * (d * 0.5 + 0.012)), out, 0.0)
	BuildingKit.ridge_tiles(mb, &"roof", apex + Vector3(-length * 0.5 - 0.02, 0.045, 0), apex + Vector3(length * 0.5 + 0.02, 0.045, 0),
			ROOF.darkened(0.05), rng)
	# A louvred vent on the middle of the ridge, with its own little gable roof.
	var cv := apex + Vector3(0, 0.02, 0)
	var cw := 0.9
	var ch := 0.62
	# Its body stops just under the tiles (the courses hide its foot), clear of the ceiling.
	mb.box_at(&"planks_ext", cv + Vector3(0, (ch - 0.1) * 0.5, 0), Vector3(cw, ch + 0.1, cw), PLANK, Vector3.ZERO, true)
	for f: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		var fb := Basis(Vector3.UP.cross(f), Vector3.UP, f)
		var fc := cv + f * (cw * 0.5)
		for k in 4:
			straw.box(&"paint_ext", Transform3D(fb * Basis(Vector3.RIGHT, deg_to_rad(-35.0)), fc + Vector3(0, 0.14 + k * 0.1, 0) + f * 0.02),
					Vector3(cw - 0.16, 0.012, 0.09), TRIM, true)
		mb.box(&"paint_in", Transform3D(fb, fc + Vector3(0, 0.29, 0) + f * 0.004), Vector3(cw - 0.16, 0.42, 0.01), Color(0.05, 0.045, 0.04))
		for sx: float in [-1.0, 1.0]:
			mb.box(&"paint_ext", Transform3D(fb, fc + fb * Vector3(sx * (cw * 0.5 - 0.04), ch * 0.5, 0.012)), Vector3(0.08, ch, 0.025), TRIM)
	var ctheta := deg_to_rad(38.0)
	var capex := cv + Vector3(0, ch + 0.34 + 0.04 / cos(ctheta), 0)
	for side: float in [1.0, -1.0]:
		var frame := BuildingKit.slope_frame(capex, ctheta, side)
		BuildingKit.roof_trim(mb, frame, cw + 0.3, 0.0, 0.78, 0.6, &"paint_ext", TRIM, &"wood_in", PLANK_DARK, 0.04, 0.08, straw)
		BuildingKit.roof_courses(mb, &"roof", frame, cw + 0.36, 0.0, 0.84, ROOF, rng, BuildingKit.ROOF_ROW, BuildingKit.ROOF_SEAM, 0.015, 0.014)
	for sx: float in [-1.0, 1.0]:
		mb.prism(&"planks_ext", Transform3D(Basis(Vector3.UP, PI * 0.5), cv + Vector3(sx * (cw * 0.5 - 0.02), ch, 0)), cw, 0.35, 0.04, PLANK, false)
	BuildingKit.ridge_tiles(mb, &"roof", capex + Vector3(-cw * 0.5 - 0.17, 0.035, 0), capex + Vector3(cw * 0.5 + 0.17, 0.035, 0),
			ROOF.darkened(0.05), rng, 0.06, 0.26)
	# Gables: the frame (a prism) boarded over with vertical boards and battens.
	for sx: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (w * 0.5 - t * 0.5), wall_h, 0))
		mb.prism(&"planks_ext", xf, d, rise, t, PLANK, false)
		var bw := BuildingKit.BOARD_H
		var count := int(d / bw)
		for k in count:
			var z0 := -d * 0.5 + k * bw
			var edge_z := maxf(absf(z0), absf(z0 + bw))
			var bh := rise * (1.0 - edge_z / (d * 0.5))
			if bh < 0.05:
				continue
			var v := rng.randf_range(0.85, 1.05)
			BuildingKit.plank(mb, &"planks_ext", Transform3D(Basis(), Vector3(sx * (w * 0.5 + 0.014), wall_h + bh * 0.5 - 0.02, z0 + bw * 0.5)),
					Vector3(0.028, bh + 0.04, bw - 0.004), Color(PLANK.r * v, PLANK.g * v, PLANK.b * v),
					Vector2(rng.randf() * 2.0, BuildingKit.BOARD_SEAM + rng.randi_range(0, 12) * bw), true)
			if k % 2 == 1 and absf(z0) > 0.7:
				BuildingKit.plank(straw, &"paint_ext", Transform3D(Basis(), Vector3(sx * (w * 0.5 + 0.039), wall_h + bh * 0.5 - 0.02, z0)),
						Vector3(0.022, bh + 0.04, 0.055), BATTEN, Vector2(k * 0.29, k * 0.53))
		mb.box(&"paint_ext", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (w * 0.5 + 0.04), wall_h, 0)), Vector3(d + 0.02, 0.14, 0.03),
				TRIM, true)
	# Hayloft doors on both gables.
	for sx: float in [-1.0, 1.0]:
		var hl := Vector3(sx * (w * 0.5 + 0.075), wall_h + rise * 0.28, 0)
		mb.box_at(&"planks_ext", hl, Vector3(0.05, 1.0, 1.2), PLANK.darkened(0.1), Vector3.ZERO, true)
		mb.box_at(&"paint_ext", hl + Vector3(sx * 0.03, 0, 0), Vector3(0.025, 1.0, 0.08), TRIM)
		for ty: float in [-0.46, 0.46]:
			mb.box(&"paint_ext", Transform3D(Basis(Vector3.UP, PI * 0.5), hl + Vector3(sx * 0.03, ty, 0)), Vector3(1.2, 0.08, 0.025), TRIM, true)
		for tz: float in [-0.56, 0.56]:
			mb.box_at(&"paint_ext", hl + Vector3(sx * 0.03, 0, tz), Vector3(0.025, 1.0, 0.08), TRIM)
	# Interior: roof beams and stall dividers along the back wall.
	for i in 4:
		var bx := -w * 0.5 + w * (i + 0.5) / 4.0
		BuildingKit.beam(mb, &"wood_in", Vector3(bx, wall_h - 0.12, -d * 0.5 + 0.15), Vector3(bx, wall_h - 0.12, d * 0.5 - 0.15), Vector2(0.22, 0.2),
				PLANK_DARK, true, 0.0, Vector2(i * 0.41, i * 0.77))
	for rx: float in [-w * 0.5 + 1.2, 0.0, w * 0.5 - 1.2]:
		mb.box_at(&"wood_in", Vector3(rx, 0.7, -d * 0.5 + 1.3), Vector3(0.08, 1.3, 2.2), PLANK_DARK)
		mb.box_at(&"wood_in", Vector3(rx, 1.3, -d * 0.5 + 1.3), Vector3(0.1, 0.1, 2.3), PLANK_DARK)
		cols.append([Vector3(rx, 0.7, -d * 0.5 + 1.3), Vector3(0.1, 1.4, 2.2)])
	# Hay bales stacked in a corner.
	for i in 3:
		var hb := Vector3(w * 0.5 - 0.9, 0.3 + i * 0.5 * float(i < 2), d * 0.5 - 1.0 - (0.95 if i == 1 else 0.0))
		mb.box(&"straw", Transform3D(Basis(Vector3.UP, 0.1 * i), hb), Vector3(0.95, 0.5, 0.6), Color(0.8, 0.66, 0.38))
	cols.append([Vector3(w * 0.5 - 0.9, 0.5, d * 0.5 - 1.45), Vector3(1.0, 1.0, 1.6)])
	return {"mesh": mb.build(), "straw_mesh": straw.build(), "colliders": cols, "door_width": door_w}


## Grandpa's coop (`with_door`: its door leaf hangs open, its nest boxes are bedded).
## A kit-built coop's model leaves out the leaf (CoopDoor) and the nest boxes: its own
## (ChickenCoop) are empty until the farmer beds them with straw.
## A kit-built coop made longer (ChickenCoop's expansion): `ext` metres at its east end
## are the newer part, under the same roof: fresher boards behind a trim board over the
## joint, a window in its front, a roost of its own along the new end wall (the old one
## stays where it stood); its door, ramp and floor stay where they were, `door_x` metres
## along X from the middle of the longer house.
static func coop(size: Vector2, with_door := true, door_x := 0.0, ext := 0.0) -> Dictionary:
	var mb := MeshBuilder.new()
	# Small trim, drawn without shadows (returned as straw_mesh, as the barn's).
	var detail := MeshBuilder.new()
	var cols: Array = []
	var w := size.x
	var d := size.y
	var t := 0.12
	var front_h := 2.5
	var back_h := 1.95
	var door_w := 1.0
	var door_h := 2.05
	var floor_y := 0.3
	# Where the newer east end meets the house as it came (none without one), and its
	# fresher boards.
	var joint := w * 0.5 - ext if ext > 0.0 else INF
	var fresh := PLANK.lightened(0.05).lerp(Color(0.72, 0.58, 0.46), 0.3)
	# Raised floor on short posts (sunk 0.3 m, so a coop on a gentle slope never floats).
	mb.box_at(&"floor", Vector3(0, floor_y - 0.05, 0), Vector3(w, 0.1, d), Color(0.5, 0.48, 0.46))
	var post_xs: Array[float] = [-(w * 0.5 - 0.1), w * 0.5 - 0.1]
	if ext > 0.0:
		post_xs.append(joint)
	for px: float in post_xs:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"wood_ext", Vector3(px, (floor_y - 0.3) * 0.5 - 0.05, sz * (d * 0.5 - 0.1)), Vector3(0.14, floor_y + 0.3, 0.14), PLANK_DARK)
	mb.box(&"straw", Transform3D(Basis(), Vector3(0, floor_y + 0.015, 0)), Vector3(w - 0.3, 0.03, d - 0.3), Color(0.72, 0.6, 0.35))
	cols.append([Vector3(0, floor_y * 0.5, 0), Vector3(w, floor_y, d)])
	# Walls; the roof slopes from the front (door side) down to the back.
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	if ext > 0.0:
		# The house as it came and its newer end, the trim board over the joint (no batten
		# under it).
		var old_w := w - ext
		_wall(mb, cols, Vector3(-w * 0.5 + old_w * 0.5, floor_y + back_h * 0.5, -d * 0.5 + t * 0.5), Vector3(old_w, back_h, t),
				PLANK.lightened(0.05), Vector3.FORWARD, detail, [Vector2(old_w * 0.5 - 0.14, old_w)])
		_wall(mb, cols, Vector3(joint + ext * 0.5, floor_y + back_h * 0.5, -d * 0.5 + t * 0.5), Vector3(ext, back_h, t),
				fresh, Vector3.FORWARD, detail, [Vector2(-ext, -ext * 0.5 + 0.14)])
		BuildingKit.plank(mb, &"paint_ext", Transform3D(Basis(), Vector3(joint, floor_y + back_h * 0.5, -d * 0.5 - 0.012)),
				Vector3(0.14, back_h, 0.024), TRIM, Vector2(0.7, 0.2))
	else:
		var back_c := Vector3(0, floor_y + back_h * 0.5, -d * 0.5 + t * 0.5)
		_wall(mb, cols, back_c, Vector3(w, back_h, t), PLANK.lightened(0.05), Vector3.FORWARD, detail)
	for sx: float in [-1.0, 1.0]:
		var sc := Vector3(sx * (w * 0.5 - t * 0.5), floor_y + back_h * 0.5, 0)
		var ss := Vector3(t, back_h, d - t * 2.0)
		_wall(mb, cols, sc, ss, PLANK.lightened(0.05))
		var skip: Array[Vector2] = []
		if sx > 0.0:
			skip.append(Vector2(-0.62, 0.62))
		BuildingKit.battens(detail, &"paint_ext", Transform3D(Basis(), sc), ss, Vector3(sx, 0, 0), BATTEN, 2, skip)
		# Triangular top of the side walls (the roof rises toward the front), its boards
		# upright like the wall's below (the planks photo turned as box() uv_rotate does).
		var origin := Vector3(sx * (w * 0.5 - t * 0.5), floor_y + back_h, 0)
		var a := origin + Vector3(0, 0, -d * 0.5)
		var b := origin + Vector3(0, 0, d * 0.5)
		var c := origin + Vector3(0, front_h - back_h, d * 0.5)
		var col := PLANK.lightened(0.05)
		for face: float in [1.0, -1.0]:
			var off := Vector3(face * t * 0.5, 0, 0)
			# U up from the wall's foot, V along it as on that face of the box below.
			var v_a := d - t if face > 0.0 else -t
			var v_b := -t if face > 0.0 else d - t
			var uv_a := Vector2(back_h, v_a)
			var uv_b := Vector2(back_h, v_b)
			var uv_c := Vector2(front_h, v_b)
			if face > 0.0:
				mb.tri(&"planks_ext", a + off, c + off, b + off, col, uv_a, uv_c, uv_b)
			else:
				mb.tri(&"planks_ext", a + off, b + off, c + off, col, uv_a, uv_b, uv_c)
	# The front either side of the door (the east side up to the newer end, which has a
	# window in the middle of its own boards).
	var door_l := door_x - door_w * 0.5
	var door_r := door_x + door_w * 0.5
	var east := minf(joint, w * 0.5)
	for piece: Vector2 in [Vector2(-w * 0.5, door_l), Vector2(door_r, east)]:
		var pw := piece.y - piece.x
		var skips: Array[Vector2] = []
		if piece.y == joint:
			skips.append(Vector2(pw * 0.5 - 0.14, pw))
		_wall(mb, cols, Vector3((piece.x + piece.y) * 0.5, floor_y + front_h * 0.5, d * 0.5 - t * 0.5), Vector3(pw, front_h, t),
				PLANK.lightened(0.05), Vector3.BACK, detail, skips)
	if ext > 0.0:
		var win := Vector3(joint + ext * 0.5, floor_y + 1.45, d * 0.5)
		_wall(mb, cols, Vector3(win.x, floor_y + front_h * 0.5, d * 0.5 - t * 0.5), Vector3(ext, front_h, t), fresh, Vector3.BACK, detail,
				[Vector2(-ext, -ext * 0.5 + 0.14), Vector2(-0.5, 0.5)])
		BuildingKit.plank(mb, &"paint_ext", Transform3D(Basis(), Vector3(joint, floor_y + front_h * 0.5, d * 0.5 + 0.012)),
				Vector3(0.14, front_h, 0.024), TRIM, Vector2(0.2, 0.6))
		_window(mb, detail, win, Vector3.BACK, 0.8, 0.6)
	for sx: float in [-1.0, 1.0]:
		# Corner boards, the grain running up them.
		for sz: float in [-1.0, 1.0]:
			var ch := front_h if sz > 0.0 else back_h
			BuildingKit.plank(mb, &"paint_ext", Transform3D(Basis(), Vector3(sx * (w * 0.5 + 0.012), floor_y + ch * 0.5, sz * (d * 0.5 - 0.05))),
					Vector3(0.024, ch, 0.12), TRIM, Vector2(0.3 + sx * 0.2 + sz * 0.45, 0.0))
			BuildingKit.plank(mb, &"paint_ext", Transform3D(Basis(), Vector3(sx * (w * 0.5 - 0.05), floor_y + ch * 0.5, sz * (d * 0.5 + 0.012))),
					Vector3(0.124, ch, 0.024), TRIM, Vector2(0.9 + sx * 0.2 + sz * 0.45, 0.4))
	mb.box_at(&"planks_ext", Vector3(door_x, floor_y + door_h + (front_h - door_h) * 0.5, d * 0.5 - t * 0.5), Vector3(door_w, front_h - door_h, t), PLANK, Vector3.ZERO, true)
	# Trim round the doorway.
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"paint_ext", Vector3(door_x + sx * (door_w * 0.5 + 0.045), floor_y + door_h * 0.5, d * 0.5 + 0.012), Vector3(0.09, door_h, 0.024), TRIM)
	mb.box_at(&"paint_ext", Vector3(door_x, floor_y + door_h + 0.045, d * 0.5 + 0.012), Vector3(door_w + 0.18, 0.09, 0.024), TRIM, Vector3.ZERO, true)
	# Door leaf hanging open and a ramp down to the run.
	if with_door:
		mb.box_at(&"planks_ext", Vector3(door_x - door_w * 0.5 - 0.5, floor_y + door_h * 0.5, d * 0.5 + 0.05), Vector3(door_w, door_h, 0.05), PLANK.darkened(0.08), Vector3.ZERO, true)
	var ramp_len := 1.1
	var ramp_ang := atan2(floor_y, ramp_len)
	var ramp_c := Vector3(door_x, floor_y * 0.5, d * 0.5 + ramp_len * 0.5)
	mb.box_at(&"planks_ext", ramp_c, Vector3(door_w - 0.1, 0.05, Vector2(ramp_len, floor_y).length()), PLANK_DARK, Vector3(rad_to_deg(ramp_ang), 0, 0))
	cols.append([ramp_c - Vector3(0, 0.04, 0), Vector3(door_w - 0.1, 0.1, Vector2(ramp_len, floor_y).length()), Vector3(rad_to_deg(ramp_ang), 0, 0)])
	for i in 5:
		mb.box_at(&"wood_ext", ramp_c + Vector3(0, 0.035, -ramp_len * 0.4 + i * ramp_len * 0.2) + Vector3(0, (ramp_len * 0.4 - i * ramp_len * 0.2) * tan(ramp_ang), 0), Vector3(door_w - 0.15, 0.03, 0.04), PLANK_DARK,
				Vector3.ZERO, true)
	# Glazed window on the east wall.
	_window(mb, detail, Vector3(w * 0.5, floor_y + 1.2, 0), Vector3.RIGHT, 1.0, 0.6)
	# Lean-to roof falling to the back: tiles in courses on a board deck, fascia at both
	# edges, barge boards, a gutter and a downpipe at the back.
	var roof_ang := atan2(front_h - back_h, d)
	var roof_len := Vector2(d + 0.7, (front_h - back_h) * (d + 0.7) / d).length()
	var roof_basis := Basis(Vector3.RIGHT, -roof_ang)
	var roof_c := Vector3(0, floor_y + (front_h + back_h) * 0.5 + 0.1, 0.05)
	var top_front := roof_c + roof_basis.y * 0.05 + roof_basis.z * (roof_len * 0.5)
	var frame := BuildingKit.slope_frame(top_front, roof_ang, -1.0)
	var rl := w + 0.6
	var edge := BuildingKit.roof_trim(mb, frame, rl, 0.0, roof_len, (top_front.z + d * 0.5) / cos(roof_ang), &"paint_ext", TRIM,
			&"wood_in", PLANK_DARK, 0.1, -1.0, detail)
	BuildingKit.roof_courses(mb, &"roof", frame, rl + 0.06, 0.0, roof_len + 0.06, ROOF, rng)
	mb.box_at(&"paint_ext", top_front + Vector3(0, -0.1, 0.016), Vector3(rl + 0.02, 0.2, 0.032), TRIM, Vector3.ZERO, true)
	var g := edge + Vector3(0, -0.035, -0.075)
	BuildingKit.gutter(mb, g - Vector3(rl * 0.5 - 0.02, 0, 0), g + Vector3(rl * 0.5 - 0.02, 0, 0), Vector3.FORWARD)
	BuildingKit.downpipe(mb, Vector3(w * 0.5 - 0.28, g.y - 0.05, g.z), Vector3(w * 0.5 - 0.28, 0, -d * 0.5 - 0.012), Vector3.FORWARD, 0.0)
	# Nest boxes along the west wall (Grandpa's) and a perch.
	if with_door:
		for i in 4:
			var nb := Vector3(-w * 0.5 + 0.45, floor_y + 0.55, -d * 0.5 + 0.55 + i * 0.75)
			mb.box_at(&"wood_in", nb + Vector3(0, -0.2, 0), Vector3(0.6, 0.05, 0.66), PLANK_DARK)
			mb.box_at(&"wood_in", nb + Vector3(0, 0.15, 0), Vector3(0.6, 0.05, 0.66), PLANK_DARK)
			mb.box_at(&"wood_in", nb + Vector3(0, -0.02, -0.33), Vector3(0.6, 0.4, 0.04), PLANK_DARK)
			mb.box(&"straw", Transform3D(Basis(), nb + Vector3(0.02, -0.14, 0)), Vector3(0.5, 0.08, 0.55), Color(0.78, 0.64, 0.36))
		mb.box_at(&"wood_in", Vector3(-w * 0.5 + 0.45, floor_y + 0.5, 0.9), Vector3(0.6, 1.0, 0.05), PLANK_DARK)
		# Solid below the nest floors and above their lids: eggs laid in the boxes (egg_spot)
		# lie on the straw in the gap instead of starting inside a block.
		cols.append([Vector3(-w * 0.5 + 0.45, floor_y + 0.185, -d * 0.5 + 1.6), Vector3(0.6, 0.37, 3.2)])
		cols.append([Vector3(-w * 0.5 + 0.45, floor_y + 0.85, -d * 0.5 + 1.6), Vector3(0.6, 0.3, 3.2)])
	# The roost: two bars rising from the back to the front, on legs (a longer coop keeps
	# its first one and has another along its new end wall).
	var roosts: Array[float] = [w * 0.5]
	if ext > 0.0:
		roosts.push_front(joint)
	for rx: float in roosts:
		for py: float in [0.9, 1.3]:
			var a := Vector3(rx - 0.6, floor_y + py, -d * 0.5 + 0.4)
			var b := Vector3(rx - 0.6 - (py - 0.5), floor_y + py, d * 0.5 - 0.6)
			mb.cylinder_between(&"wood_in", a, b, 0.03, 0.03, 6, PLANK_DARK)
			for e: Vector3 in [a, b]:
				mb.cylinder_between(&"wood_in", Vector3(e.x, floor_y, e.z), e + Vector3(0, -0.03, 0), 0.022, 0.022, 6, PLANK_DARK.darkened(0.08))
	return {"mesh": mb.build(), "straw_mesh": detail.build(), "colliders": cols, "door_width": door_w, "door_height": door_h,
		"floor_y": floor_y}


## A glazed four-pane window on a solid wall's outer face at `c`, facing `out`: a dark
## board behind the glass (the dim inside), a frame with its cross bars (those into
## `detail`), a sill.
static func _window(mb: MeshBuilder, detail: MeshBuilder, c: Vector3, out: Vector3, w: float, h: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), c)
	mb.box(&"paint_in", xf * Transform3D(Basis(), Vector3(0, 0, 0.006)), Vector3(w - 0.08, h - 0.08, 0.01), Color(0.04, 0.035, 0.03))
	mb.box(&"window_glass", xf * Transform3D(Basis(), Vector3(0, 0, 0.028)), Vector3(w - 0.1, h - 0.1, 0.006), Color.WHITE)
	for piece: Array in [[Vector3(-w * 0.5 + 0.04, 0, 0.03), Vector3(0.08, h, 0.06), mb], [Vector3(w * 0.5 - 0.04, 0, 0.03), Vector3(0.08, h, 0.06), mb],
			[Vector3(0, h * 0.5 - 0.04, 0.03), Vector3(w, 0.08, 0.06), mb], [Vector3(0, -h * 0.5 + 0.04, 0.03), Vector3(w, 0.08, 0.06), mb],
			[Vector3(0, 0, 0.032), Vector3(0.03, h - 0.1, 0.03), detail], [Vector3(0, 0, 0.032), Vector3(w - 0.1, 0.03, 0.03), detail]]:
		var size: Vector3 = piece[1]
		(piece[2] as MeshBuilder).box(&"paint_ext", xf * Transform3D(Basis(), piece[0]), size, TRIM, size.x > size.y)
	mb.box(&"paint_ext", xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - 0.02, 0.05)), Vector3(w + 0.14, 0.04, 0.1), TRIM, true)


## A wall of vertical boards and its collider; battens (into `detail`) on the face out
## toward `face` (none when it is zero). The battens share the trim's key (the same
## rough_wood photo), so the small trim is one surface fewer to draw.
static func _wall(mb: MeshBuilder, cols: Array, center: Vector3, size: Vector3, col := PLANK, face := Vector3.ZERO,
		detail: MeshBuilder = null, skips: Array[Vector2] = []) -> void:
	mb.box_at(&"planks_ext", center, size, col, Vector3.ZERO, true)
	cols.append([center, size])
	if face != Vector3.ZERO:
		BuildingKit.battens(detail if detail else mb, &"paint_ext", Transform3D(Basis(), center), size, face,
				Color(col.r * 0.85, col.g * 0.86, col.b * 0.86), 2, skips)
