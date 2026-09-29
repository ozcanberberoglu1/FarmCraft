@tool
class_name Well
extends StaticBody3D
## Stone well with a small roof, crank and bucket. Refills the watering can (phase 3).

const STONE := Color(0.5, 0.5, 0.49)
const WOOD := Color(0.44, 0.42, 0.4)
const ROOF := Color(0.5, 0.48, 0.47)


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	# Dry-stone shaft sunk a little into the ground, a ring of coping stones on top.
	mb.ring(&"stone_ext", Transform3D(Basis(), Vector3(0, -0.1, 0)), 0.85, 0.62, 0.88, 20, STONE, 0.08, 3)
	var coping := 13
	for i in coping:
		var a0 := TAU * (i + 0.04) / coping
		var a1 := TAU * (i + 0.96) / coping
		var h := rng.randf_range(0.1, 0.14)
		var y0 := 0.77
		var ro := 0.9 + rng.randf_range(-0.02, 0.02)
		var ri := 0.58
		var p: Array[Vector3] = []
		for c: Array in [[a0, ri, y0], [a0, ro, y0], [a0, ro, y0 + h], [a0, ri, y0 + h],
				[a1, ri, y0], [a1, ro, y0], [a1, ro, y0 + h * rng.randf_range(0.9, 1.08)], [a1, ri, y0 + h]]:
			var ang: float = c[0]
			var r: float = c[1]
			p.append(Vector3(cos(ang) * r, float(c[2]), sin(ang) * r))
		# In hexa() order: X out from the shaft, Y up, Z round it.
		mb.hexa(&"stone_ext", p, STONE.lightened(rng.randf_range(0.0, 0.08)))
	mb.cylinder(&"water_still", Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.62, 0.62, 0.3, 14, Color("1d3440"), true, true)
	# Two hewn posts on the coping carry the ridge beam (the grain along each).
	var wood := WOOD
	for sx: float in [-1.0, 1.0]:
		var lean := Basis(Vector3.BACK, deg_to_rad(sx * rng.randf_range(-1.2, 1.2)))
		BuildingKit.plank(mb, &"wood_ext", Transform3D(lean, Vector3(sx * 0.72, 1.28, 0)), Vector3(0.13, 2.36, 0.13), wood.darkened(0.05),
				Vector2(0.4 + sx * 0.3, 0.2))
	mb.box_at(&"wood_ext", Vector3(0, 2.5, 0), Vector3(1.9, 0.14, 0.12), wood.darkened(0.08), Vector3.ZERO, true)
	# Windlass: a log with the rope wound round it, a crank on iron.
	mb.cylinder_between(&"wood", Vector3(-0.8, 1.55, 0), Vector3(0.84, 1.55, 0), 0.065, 0.065, 10, wood.lightened(0.08))
	mb.cylinder_between(&"cloth", Vector3(-0.22, 1.55, 0), Vector3(0.18, 1.55, 0), 0.085, 0.085, 12, Color(0.5, 0.45, 0.36))
	var iron := Color(0.16, 0.15, 0.14)
	mb.cylinder_between(&"rusty", Vector3(0.84, 1.55, 0), Vector3(0.95, 1.55, 0), 0.02, 0.02, 6, iron)
	mb.box_at(&"rusty", Vector3(0.95, 1.43, 0), Vector3(0.03, 0.28, 0.035), iron)
	mb.cylinder_between(&"wood", Vector3(0.95, 1.31, 0), Vector3(1.1, 1.31, 0), 0.024, 0.024, 6, wood)
	mb.cylinder_between(&"cloth", Vector3(0.0, 1.47, 0), Vector3(0.0, 1.14, 0), 0.011, 0.011, 4, Color(0.5, 0.45, 0.36))
	# The bucket: staves, two iron hoops, a bail.
	var bucket := Transform3D(Basis(), Vector3(0, 0.9, 0))
	mb.cylinder(&"wood", bucket, 0.13, 0.155, 0.24, 12, Color(0.46, 0.4, 0.34))
	for hy: float in [0.04, 0.19]:
		var r := lerpf(0.13, 0.155, hy / 0.24) + 0.004
		mb.ring(&"rusty", bucket * Transform3D(Basis(), Vector3(0, hy, 0)), r, r - 0.012, 0.025, 12, iron)
	var bail: Array[Vector3] = []
	var bail_r: Array[float] = []
	for k in 7:
		var a := PI * k / 6.0
		bail.append(bucket * Vector3(cos(a) * 0.155, 0.24 + sin(a) * 0.16, 0))
		bail_r.append(0.006)
	mb.loft(&"rusty", bail, bail_r, 5, iron)
	# Roof: tiles in close, flat courses (a small roof) on a board deck and rafters,
	# barge boards, a boarded ridge cap.
	var theta := deg_to_rad(40.0)
	var slope := 0.98
	var length := 1.95
	var apex := Vector3(0, 2.57 + 0.05 / cos(theta), 0)
	for side: float in [1.0, -1.0]:
		var frame := BuildingKit.slope_frame(apex, theta, side)
		BuildingKit.roof_trim(mb, frame, length, 0.0, slope, 0.12, &"wood_ext", wood.darkened(0.1), &"wood_ext", wood, 0.05, 0.1)
		# A purlin under each slope, braced from the posts.
		mb.box(&"wood_ext", Transform3D(frame.basis, frame * Vector3(0, -0.1, 0.55)), Vector3(length - 0.04, 0.1, 0.09), wood.darkened(0.08), true)
		for sx: float in [-1.0, 1.0]:
			var pb := frame * Vector3(0, -0.15, 0.55)
			pb.x = sx * 0.72
			BuildingKit.beam(mb, &"wood_ext", Vector3(sx * 0.72, pb.y - 0.4, side * 0.05), pb, Vector2(0.07, 0.06), wood, true)
		BuildingKit.roof_courses(mb, &"roof", frame, length + 0.06, 0.0, slope + 0.06, ROOF, rng, BuildingKit.ROOF_ROW, BuildingKit.ROOF_SEAM,
				0.015, 0.012)
		BuildingKit.ridge_boards(mb, &"wood_ext", frame, length + 0.1, wood.darkened(0.12), 0.015 + 0.012)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.92
	shape.height = 1.0
	cs.shape = shape
	cs.position.y = 0.5
	add_child(cs)


func use_prompt(_player: Node, stack: ItemStack) -> String:
	return WaterSource.use_prompt(stack)


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return WaterSource.use_action(stack)


func can_start(_action: Dictionary, stack: ItemStack) -> String:
	return WaterSource.can_start(stack)


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	WaterSource.refill(stack)
