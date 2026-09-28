class_name AnimalBuildings
extends RefCounted
## Closed barn and coop models built around a local origin at the footprint
## center (door on the +Z side). Each returns {mesh, colliders: [[center, size]]};
## the barn also returns straw_mesh, its loose bedding stalks (drawn without shadows).
## The coop leaves its door leaf out with `with_door` false (the kit-built coop hangs a
## CoopDoor that opens and shuts there instead).

const PLANK := Color(0.6, 0.44, 0.4)
const PLANK_DARK := Color(0.42, 0.34, 0.31)
const STONE := Color(0.52, 0.51, 0.5)
const ROOF := Color(0.46, 0.45, 0.45)
const TRIM := Color(0.88, 0.86, 0.8)


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
		mb.box_at(&"stone", side[0], side[1], STONE)
	for sx: float in [-1.0, 1.0]:
		var seg := (w - door_w) * 0.5
		mb.box_at(&"stone", Vector3(sx * (door_w * 0.5 + seg * 0.5), base_h * 0.5, d * 0.5 - t * 0.5), Vector3(seg, base_h, t + 0.1), STONE)
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
	# Walls: vertical board siding above the footing.
	var wy := base_h + (wall_h - base_h) * 0.5
	var wh := wall_h - base_h
	_wall(mb, cols, Vector3(0, wy, -d * 0.5 + t * 0.5), Vector3(w, wh, t))
	_wall(mb, cols, Vector3(-w * 0.5 + t * 0.5, wy, 0), Vector3(t, wh, d - t * 2.0))
	_wall(mb, cols, Vector3(w * 0.5 - t * 0.5, wy, 0), Vector3(t, wh, d - t * 2.0))
	var seg := (w - door_w) * 0.5
	for sx: float in [-1.0, 1.0]:
		_wall(mb, cols, Vector3(sx * (door_w * 0.5 + seg * 0.5), wy, d * 0.5 - t * 0.5), Vector3(seg, wh, t))
	# Header above the door.
	mb.box_at(&"planks", Vector3(0, door_h + (wall_h - door_h) * 0.5, d * 0.5 - t * 0.5), Vector3(door_w, wall_h - door_h, t), PLANK, Vector3.ZERO, true)
	# Sliding doors parked beside the opening, with the X brace and a rail.
	for sx: float in [-1.0, 1.0]:
		var dc := Vector3(sx * (door_w * 0.5 + door_w * 0.25 + 0.05), door_h * 0.5 + 0.05, d * 0.5 + 0.08)
		mb.box_at(&"planks", dc, Vector3(door_w * 0.5, door_h, 0.07), PLANK.darkened(0.05), Vector3.ZERO, true)
		var hw := door_w * 0.25 - 0.08
		var hh := door_h * 0.5 - 0.08
		for diag: float in [1.0, -1.0]:
			var ang := atan2(hh * 2.0, hw * 2.0) * diag
			mb.box_at(&"paint", dc + Vector3(0, 0, 0.045), Vector3(sqrt(hw * hw * 4.0 + hh * hh * 4.0), 0.1, 0.02), TRIM, Vector3(0, 0, rad_to_deg(ang)))
		for border: Array in [[Vector3(0, hh, 0.045), Vector3(door_w * 0.5, 0.1, 0.02)], [Vector3(0, -hh, 0.045), Vector3(door_w * 0.5, 0.1, 0.02)],
				[Vector3(hw, 0, 0.045), Vector3(0.1, door_h, 0.02)], [Vector3(-hw, 0, 0.045), Vector3(0.1, door_h, 0.02)]]:
			mb.box_at(&"paint", dc + border[0], border[1], TRIM)
	mb.box_at(&"steel", Vector3(0, door_h + 0.12, d * 0.5 + 0.1), Vector3(door_w * 2.1, 0.06, 0.06), Color(0.2, 0.2, 0.2))
	# Small high windows on the side walls.
	for sx: float in [-1.0, 1.0]:
		for wz: float in [-d * 0.22, d * 0.22]:
			var c := Vector3(sx * (w * 0.5 + 0.005), 2.4, wz)
			mb.box_at(&"paint", c, Vector3(0.04, 0.7, 0.9), TRIM)
			mb.box_at(&"paint_in", c + Vector3(sx * 0.01, 0, 0), Vector3(0.03, 0.56, 0.76), Color(0.08, 0.08, 0.07))
	# Gable roof along X with gables filled in.
	var rise := d * 0.36
	var theta := atan2(rise, d * 0.5)
	var run := d * 0.5 + 0.5
	var slab_len := run / cos(theta)
	var ridge_y := wall_h + rise
	for side: float in [1.0, -1.0]:
		var basis := Basis(Vector3.RIGHT, theta * side)
		var center := Vector3(0, ridge_y - tan(theta) * run * 0.5, side * run * 0.5) + basis.y * 0.08
		mb.box(&"roof", Transform3D(basis, center), Vector3(w + 0.8, 0.16, slab_len), ROOF)
		var plane := Vector3(0, ridge_y - tan(theta) * run * 0.5, side * run * 0.5)
		mb.box(&"wood_in", Transform3D(basis, plane - basis.y * 0.013), Vector3(w + 0.78, 0.02, slab_len - 0.02), PLANK_DARK, true)
	for sx: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (w * 0.5 - t * 0.5), wall_h, 0))
		mb.prism(&"planks", xf, d, rise, t, PLANK, false)
	mb.box_at(&"wood", Vector3(0, ridge_y + 0.08, 0), Vector3(w + 0.9, 0.18, 0.26), PLANK_DARK)
	# Hayloft doors on both gables.
	for sx: float in [-1.0, 1.0]:
		var hl := Vector3(sx * (w * 0.5 + 0.02), wall_h + rise * 0.28, 0)
		mb.box_at(&"planks", hl, Vector3(0.06, 1.0, 1.2), PLANK.darkened(0.1), Vector3.ZERO, true)
		mb.box_at(&"paint", hl + Vector3(sx * 0.02, 0, 0), Vector3(0.03, 1.1, 0.08), TRIM)
		mb.box_at(&"paint", hl + Vector3(sx * 0.02, 0.52, 0), Vector3(0.03, 0.08, 1.3), TRIM)
	# Interior: roof beams and stall dividers along the back wall.
	for i in 4:
		var bx := -w * 0.5 + w * (i + 0.5) / 4.0
		mb.box_at(&"wood_in", Vector3(bx, wall_h - 0.12, 0), Vector3(0.2, 0.22, d - 0.3), PLANK_DARK)
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


static func coop(size: Vector2, with_door := true) -> Dictionary:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var w := size.x
	var d := size.y
	var t := 0.12
	var front_h := 2.5
	var back_h := 1.95
	var door_w := 1.0
	var door_h := 2.05
	var floor_y := 0.3
	# Raised floor on short posts (sunk 0.3 m, so a coop on a gentle slope never floats).
	mb.box_at(&"floor", Vector3(0, floor_y - 0.05, 0), Vector3(w, 0.1, d), Color(0.5, 0.48, 0.46))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(sx * (w * 0.5 - 0.1), (floor_y - 0.3) * 0.5 - 0.05, sz * (d * 0.5 - 0.1)), Vector3(0.14, floor_y + 0.3, 0.14), PLANK_DARK, Vector3.ZERO, true)
	mb.box(&"straw", Transform3D(Basis(), Vector3(0, floor_y + 0.015, 0)), Vector3(w - 0.3, 0.03, d - 0.3), Color(0.72, 0.6, 0.35))
	cols.append([Vector3(0, floor_y * 0.5, 0), Vector3(w, floor_y, d)])
	# Walls; the roof slopes from the front (door side) down to the back.
	var back_c := Vector3(0, floor_y + back_h * 0.5, -d * 0.5 + t * 0.5)
	_wall(mb, cols, back_c, Vector3(w, back_h, t), PLANK.lightened(0.05))
	for sx: float in [-1.0, 1.0]:
		_wall(mb, cols, Vector3(sx * (w * 0.5 - t * 0.5), floor_y + back_h * 0.5, 0), Vector3(t, back_h, d - t * 2.0), PLANK.lightened(0.05))
		# Triangular top of the side walls (the roof rises toward the front).
		var origin := Vector3(sx * (w * 0.5 - t * 0.5), floor_y + back_h, 0)
		var a := origin + Vector3(0, 0, -d * 0.5)
		var b := origin + Vector3(0, 0, d * 0.5)
		var c := origin + Vector3(0, front_h - back_h, d * 0.5)
		var col := PLANK.lightened(0.05)
		var uv_c := Vector2(d, front_h - back_h)
		for face: float in [1.0, -1.0]:
			var off := Vector3(face * t * 0.5, 0, 0)
			if face > 0.0:
				mb.tri(&"planks", a + off, c + off, b + off, col, Vector2.ZERO, uv_c, Vector2(d, 0))
			else:
				mb.tri(&"planks", a + off, b + off, c + off, col, Vector2.ZERO, Vector2(d, 0), uv_c)
	var seg := (w - door_w) * 0.5
	for sx: float in [-1.0, 1.0]:
		_wall(mb, cols, Vector3(sx * (door_w * 0.5 + seg * 0.5), floor_y + front_h * 0.5, d * 0.5 - t * 0.5), Vector3(seg, front_h, t), PLANK.lightened(0.05))
	mb.box_at(&"planks", Vector3(0, floor_y + door_h + (front_h - door_h) * 0.5, d * 0.5 - t * 0.5), Vector3(door_w, front_h - door_h, t), PLANK, Vector3.ZERO, true)
	# Door leaf hanging open and a ramp down to the run.
	if with_door:
		mb.box_at(&"planks", Vector3(-door_w * 0.5 - 0.5, floor_y + door_h * 0.5, d * 0.5 + 0.05), Vector3(door_w, door_h, 0.05), PLANK.darkened(0.08), Vector3.ZERO, true)
	var ramp_len := 1.1
	var ramp_ang := atan2(floor_y, ramp_len)
	var ramp_c := Vector3(0, floor_y * 0.5, d * 0.5 + ramp_len * 0.5)
	mb.box_at(&"planks", ramp_c, Vector3(door_w - 0.1, 0.05, Vector2(ramp_len, floor_y).length()), PLANK_DARK, Vector3(rad_to_deg(ramp_ang), 0, 0))
	cols.append([ramp_c - Vector3(0, 0.04, 0), Vector3(door_w - 0.1, 0.1, Vector2(ramp_len, floor_y).length()), Vector3(rad_to_deg(ramp_ang), 0, 0)])
	for i in 5:
		mb.box_at(&"wood", ramp_c + Vector3(0, 0.035, -ramp_len * 0.4 + i * ramp_len * 0.2) + Vector3(0, (ramp_len * 0.4 - i * ramp_len * 0.2) * tan(ramp_ang), 0), Vector3(door_w - 0.15, 0.03, 0.04), PLANK_DARK)
	# Mesh-covered window on the east wall.
	var win := Vector3(w * 0.5 + 0.005, floor_y + 1.2, 0)
	mb.box_at(&"paint", win, Vector3(0.03, 0.6, 1.0), TRIM)
	mb.box_at(&"paint_in", win + Vector3(0.005, 0, 0), Vector3(0.03, 0.48, 0.88), Color(0.1, 0.1, 0.09))
	# Sloped roof with overhang.
	var roof_ang := atan2(front_h - back_h, d)
	var roof_len := Vector2(d + 0.7, (front_h - back_h) * (d + 0.7) / d).length()
	var roof_basis := Basis(Vector3.RIGHT, -roof_ang)
	var roof_c := Vector3(0, floor_y + (front_h + back_h) * 0.5 + 0.1, 0.05)
	mb.box(&"roof", Transform3D(roof_basis, roof_c), Vector3(w + 0.6, 0.1, roof_len), ROOF)
	mb.box(&"wood_in", Transform3D(roof_basis, roof_c - roof_basis.y * 0.063), Vector3(w + 0.58, 0.02, roof_len - 0.02), PLANK_DARK, true)
	# Nest boxes along the west wall and a perch.
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
	for py: float in [0.9, 1.3]:
		mb.cylinder_between(&"wood_in", Vector3(w * 0.5 - 0.6, floor_y + py, -d * 0.5 + 0.4), Vector3(w * 0.5 - 0.6 - (py - 0.5), floor_y + py, d * 0.5 - 0.6), 0.03, 0.03, 6, PLANK_DARK)
	return {"mesh": mb.build(), "colliders": cols, "door_width": door_w, "door_height": door_h, "floor_y": floor_y}


static func _wall(mb: MeshBuilder, cols: Array, center: Vector3, size: Vector3, col := PLANK) -> void:
	mb.box_at(&"planks", center, size, col, Vector3.ZERO, true)
	cols.append([center, size])
