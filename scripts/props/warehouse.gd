class_name Warehouse
extends Node3D
## The farm warehouse: a timber shed on a stone plinth with a tin roof and a wide
## door onto the yard. A new farm finds Grandpa's shed run down (level 0): rotting
## boards, rusty sheets gone from the roof, a door off its rail, junk in a corner.
## Nailing new boards over the holes in its walls (RepairSpot, wood in hand) repairs
## it (level 1); the construction board enlarges it (level 2: a loft over the back
## racks). Inside, pallets fill up with crates and sacks as the stock grows,
## and crated hens kept in stock stand in the crate corner in front of the back
## pallets (CrateBay, the same at every level). E opens the storage screen from anywhere
## inside the shed (the player's interaction falls back to the warehouse he stands in when
## nothing else is aimed at: target_for), as do the ledger by the door and the doorway
## from outside; beside the crates on show the crate corner keeps its own prompt.

const PALLETS := 8
const H := 3.4
const T := 0.18
const RISE := 1.3
const PLANK := Color(0.46, 0.42, 0.38)
const PLANK_OLD := Color(0.5, 0.5, 0.49)
const POST_OLD := Color(0.36, 0.33, 0.3)
## Stained trim, corner boards and door frame of the repaired shed.
const TRIM := Color(0.36, 0.3, 0.25)
const TIN := Color(0.52, 0.52, 0.52)
## Seed of the ruin's damage: the same broken boards on every load.
const RUIN_SEED := 5150
## The big door in the front (south) wall: its middle along the wall from the west
## corner and its width; how far the ramp up to it runs out into the yard.
const DOOR_AT := 4.0
const DOOR_W := 3.6
const RAMP_RUN := 1.3
## How far the block that keeps vehicles out reaches into the shed from the door (m).
const BARRIER_DEPTH := 1.2
## Waypoint anchor id in the middle of the shed's floor (the story's dot for what is
## fetched from the storage: the feed sack).
const ANCHOR_INSIDE := &"warehouse_inside"

## 0 = run-down, 1 = repaired, 2 = bigger (FarmState.warehouse_level()); -1 = not built.
var level := -1

var _rect: Rect2
## Floor level: the plinth's top.
var _y0 := 0.0
## Everything that changes with the level (the stock mesh stays).
var _shell: Node3D
var _stock_mesh: MeshInstance3D
## Stock meshes by the number of full pallets (all the look depends on), each built
## once, and the number on show.
var _stock_meshes := {}
var _full_shown := -1
var _stock_queued := false
## The crate corner (crated hens in the warehouse stock).
var crate_bay: CrateBay
var _door_marker: Marker3D
var _inside_marker: Marker3D


func _ready() -> void:
	add_to_group(&"warehouse")
	_rect = WorldLayout.WAREHOUSE_RECT
	_y0 = TerrainData.height(_rect.get_center().x, _rect.get_center().y) + 0.25
	_stock_mesh = MeshInstance3D.new()
	add_child(_stock_mesh)
	set_level(FarmState.warehouse_level())
	FarmState.warehouse.changed.connect(_queue_stock)
	_refresh_stock()
	# Clear of the back pallets, the loft posts (level 2), the ladder and the side racks.
	crate_bay = CrateBay.new()
	crate_bay.name = "CrateBay"
	crate_bay.position = Vector3(_rect.position.x + 1.85, _y0 + 0.06, _rect.position.y + 2.25)
	add_child(crate_bay)
	_door_marker = Marker3D.new()
	_door_marker.name = "DoorMarker"
	_door_marker.position = Vector3(_rect.position.x + 4.0, _y0 + 2.2, _rect.end.y + 0.3)
	# Found by the guide dot (WaypointMarker.anchor) and by the "waypoints" group.
	WaypointMarker.tag(_door_marker, &"warehouse")
	_door_marker.add_to_group(&"waypoints")
	add_child(_door_marker)
	_add_vehicle_barrier()
	_inside_marker = Marker3D.new()
	_inside_marker.name = "InsideMarker"
	_inside_marker.position = Vector3(_rect.get_center().x, _y0 + 1.5, _rect.get_center().y)
	WaypointMarker.tag(_inside_marker, ANCHOR_INSIDE)
	_inside_marker.add_to_group(&"waypoints")
	add_child(_inside_marker)


## No vehicle goes in through the big door: a block in the doorway on the layer only
## vehicles run into (Vehicle.BARRIER_LAYER) stops them on the ramp, nose at the door.
## The farmer, the animals and what is carried in pass through it. It is not part of the
## shell: the run-down shed and the repaired ones have the same.
func _add_vehicle_barrier() -> void:
	var body := StaticBody3D.new()
	body.name = "VehicleBarrier"
	body.collision_layer = Vehicle.BARRIER_LAYER
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	# The opening and its jambs, from under the ramp's foot to over the door beam, and
	# well into the shed: a car that hits it fast is pushed back out, not through.
	shape.size = Vector3(DOOR_W + 0.4, 4.4, BARRIER_DEPTH)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(_rect.position.x + DOOR_AT, _y0 + 1.4, _rect.end.y - BARRIER_DEPTH * 0.5)
	body.add_child(cs)
	add_child(body)


## Whether a vehicle standing at `xf` reaches into the shed (in it, or through the door):
## `footprint` is its body's, in its own frame (x across, y along). Only a game saved
## before the doorway was blocked has one there (Vehicle._leave_warehouse).
static func holds_vehicle(xf: Transform3D, footprint: Rect2) -> bool:
	# One pressed against the barrier (a few cm into the doorway) is not in.
	var inside := WorldLayout.WAREHOUSE_RECT.grow(-0.3)
	var mid := footprint.get_center()
	for p: Vector2 in [mid, footprint.position, footprint.end, Vector2(footprint.position.x, footprint.end.y),
			Vector2(footprint.end.x, footprint.position.y), Vector2(mid.x, footprint.position.y), Vector2(mid.x, footprint.end.y)]:
		var g := xf * Vector3(p.x, 0.0, p.y)
		if inside.has_point(Vector2(g.x, g.z)):
			return true
	return false


## Where a vehicle found in the shed is put: on the apron in front of the big door, clear
## of the ramp, its tail (`tail` m behind its origin) to the door, nose to the yard.
static func apron_spot(tail: float) -> Transform3D:
	var r := WorldLayout.WAREHOUSE_RECT
	var x := r.position.x + DOOR_AT
	var z := r.end.y + RAMP_RUN + 0.6 + tail
	return Transform3D(Basis(), Vector3(x, TerrainData.height(x, z) + 0.25, z))


## Where the story's waypoint dot floats to send the farmer here: over the big door.
func waypoint_door() -> Node3D:
	return _door_marker


## Where the story's dot floats for what is fetched from the storage: inside the shed.
func waypoint_inside() -> Node3D:
	return _inside_marker


## Whether `at` (a world position: the farmer's feet) is inside the shed, between its walls
## and under its roof.
func inside(at: Vector3) -> bool:
	return _rect.grow(-T).has_point(Vector2(at.x, at.z)) and at.y > _y0 - 0.6 and at.y < _y0 + H + RISE


## What E works on for `player` when nothing else is under the crosshair: the warehouse he
## stands in (its storage opens from anywhere inside), or its crate corner when he stands
## beside the crates on show and is turned their way (a crate to lift keeps its own
## prompt). null out of doors.
static func target_for(player: Player) -> Node:
	var wh := player.get_tree().get_first_node_in_group(&"warehouse") as Warehouse
	if wh == null or not wh.inside(player.global_position):
		return null
	if wh.crate_bay and wh.crate_bay.beside(player):
		return wh.crate_bay
	return wh


## E anywhere inside: the storage screen.
func interact_prompt(_player: Node) -> String:
	return tr("ACTION_OPEN_WAREHOUSE")


func interact(_player: Node) -> void:
	Game.hud.open_storage(null)


## Builds the shed for `new_level`; a repair or upgrade raises a cloud of dust.
func set_level(new_level: int, animate := false) -> void:
	if new_level == level:
		return
	level = new_level
	if _shell:
		remove_child(_shell)
		_shell.queue_free()
	_shell = Node3D.new()
	_shell.name = "Shell"
	add_child(_shell)
	if level <= 0:
		_build_ruin(_shell)
	else:
		_build_sound(_shell)
	if animate:
		var c := _rect.get_center()
		Fx.dust_cloud(Vector3(c.x, _y0 + 1.0, c.y), _rect.size * 0.5)


## Stone plinth, concrete floor and the ramp up through the big door (the plinth lifts
## the floor 0.31 m, more than the farmer can step up). Every level stands on it.
func _build_base(mb: MeshBuilder, cols: Array, ruined: bool) -> void:
	var c := _rect.get_center()
	var x0 := _rect.position.x
	var z1 := _rect.end.y
	# (Its top at the walls' foot: 5 cm higher, its sides lay in the plane of the end studs'.)
	mb.box_at(&"stone_old" if ruined else &"stone_ext", Vector3(c.x, _y0 - 0.225, c.y), Vector3(_rect.size.x, 0.45, _rect.size.y),
			Color(0.46, 0.45, 0.43) if ruined else Color(0.5, 0.5, 0.5))
	BuildingKit.slab(mb, cols, _rect.grow(-0.05), _y0 + 0.06, 0.1, &"concrete",
			Color(0.42, 0.41, 0.38) if ruined else Color(0.55, 0.54, 0.52))
	# The old shed's ramp is a few weathered boards on a wedge of earth.
	BuildingKit.ramp(mb, cols, Vector2(x0 + 4.0, z1), Vector2(0, 1), 4.0, 1.3, _y0 + 0.06,
			TerrainData.height(x0 + 4.0, z1 + 1.3), &"planks_old" if ruined else &"concrete",
			Color(0.44, 0.43, 0.41) if ruined else Color(0.52, 0.51, 0.49))


## The ledger by the door and the doorway itself open the storage screen.
func _add_points(parent: Node3D, desk: Vector3) -> void:
	var point := TownPoint.new()
	point.prompt_key = "ACTION_OPEN_WAREHOUSE"
	point.action = func() -> void: Game.hud.open_storage(null)
	point.position = desk + Vector3(0, 0.6, 0)
	point.size = Vector3(1.2, 1.2, 0.8)
	parent.add_child(point)
	var point2 := TownPoint.new()
	point2.prompt_key = "ACTION_OPEN_WAREHOUSE"
	point2.action = func() -> void: Game.hud.open_storage(null)
	point2.position = Vector3(_rect.position.x + 4.0, _y0 + 1.5, _rect.end.y)
	point2.size = Vector3(3.6, 3.0, 0.4)
	parent.add_child(point2)


## The repaired shed (levels 1-2).
func _build_sound(parent: Node3D) -> void:
	var mb := MeshBuilder.new()
	var cols := []
	var y0 := _y0
	var plank := PLANK
	var h := H
	var t := T
	_build_base(mb, cols, false)
	var x0 := _rect.position.x
	var z0 := _rect.position.y
	var x1 := _rect.end.x
	var z1 := _rect.end.y
	var ht := t * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = RUIN_SEED + 1
	# Lap siding over sheathing on studs (the studs show inside); the colliders are the
	# plain walls' (a scratch mesh takes those walls' own boxes). Small trim goes into
	# `detail`, drawn without shadows.
	var scratch := MeshBuilder.new()
	var detail := MeshBuilder.new()
	for wall: Array in [
			[Vector2(x0, z1 - ht), Vector2(x1, z1 - ht), [{"at": 4.0, "w": 3.6, "bottom": 0.0, "top": 3.0, "glass": false}]],
			[Vector2(x1, z0 + ht), Vector2(x0, z0 + ht), []],
			[Vector2(x1 - ht, z1 - t), Vector2(x1 - ht, z0 + t), [{"at": 3.3, "w": 1.4, "bottom": 1.3, "top": 2.3, "glass": true}]],
			[Vector2(x0 + ht, z0 + t), Vector2(x0 + ht, z1 - t), []]]:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		BuildingKit.wall(scratch, cols, a, b, y0, h, t, &"planks", plank, wall[2])
		BuildingKit.board_wall(mb, [], a, b, y0, h, t, &"planks_ext", plank, wall[2], rng, 0.0, &"", 0.9, true)
		for o: Dictionary in wall[2]:
			BuildingKit.opening_trim(mb, a, b, y0, t, o, &"wood_ext", TRIM, false, detail)
	_corner_boards(mb, y0, h, &"wood_ext", TRIM)
	mb.box_at(&"wood_ext", Vector3(x0 + 4.0, y0 + 3.1, z1 + 0.03), Vector3(4.2, 0.25, 0.3), Color(0.36, 0.3, 0.24), Vector3.ZERO, true)
	# Sliding door leaves parked beside the opening: boards on ledges with a brace,
	# hung from rollers on the rail.
	for dx: float in [0.95, 7.05]:
		_door_leaf(mb, Transform3D(Basis(), Vector3(x0 + dx, y0 + 1.5, z1 + 0.15)), -1, rng, &"planks_ext", &"wood_ext",
				plank.darkened(0.12), Color(0.34, 0.29, 0.24), true)
		for hx: float in [-0.6, 0.6]:
			detail.box_at(&"steel", Vector3(x0 + dx + hx, y0 + 3.02, z1 + 0.2), Vector3(0.05, 0.12, 0.012), Color(0.2, 0.2, 0.2))
			detail.cylinder_between(&"steel", Vector3(x0 + dx + hx, y0 + 3.1, z1 + 0.16), Vector3(x0 + dx + hx, y0 + 3.1, z1 + 0.22), 0.045, 0.045,
					10, Color(0.2, 0.2, 0.2))
	mb.box_at(&"metal", Vector3(x0 + 4.0, y0 + 3.05, z1 + 0.2), Vector3(8.0, 0.08, 0.06), Color(0.2, 0.2, 0.2))
	# Low gable roof in corrugated iron along X on purlins and rafters, gables boarded.
	_tin_roof(mb, detail, cols, rng, true)
	for gx: float in [x0 + ht, x1 - ht]:
		mb.prism(&"planks_ext", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(gx, y0 + h, _rect.get_center().y)), _rect.size.y, RISE, t, plank, false)
	for sx: float in [-1.0, 1.0]:
		var gx := x1 if sx > 0.0 else x0
		var gable := Transform3D(Basis(Vector3(0, 0, -sx), Vector3.UP, Vector3(sx, 0, 0)), Vector3(gx, y0 + h, _rect.get_center().y))
		BuildingKit.gable_siding(mb, &"planks_ext", gable, _rect.size.y, RISE, plank, rng)
		mb.box(&"wood_ext", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(gx + sx * 0.026, y0 + h, _rect.get_center().y)),
				Vector3(_rect.size.y + 0.02, 0.14, 0.03), TRIM, true)
	if level >= 2:
		_build_loft(mb, cols)
	# Ledger desk by the door (interaction point).
	var desk := Vector3(x0 + 6.8, y0, z1 - 0.9)
	mb.box_at(&"wood_in", desk + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 0.6), Color(0.4, 0.33, 0.26))
	mb.box_at(&"paper", desk + Vector3(0, 1.02, 0), Vector3(0.36, 0.02, 0.26), Color(0.9, 0.88, 0.8), Vector3(0, 12, 0))
	# Painted board on the east gable, facing the house and the yard.
	var gz := _rect.get_center().y
	mb.box_at(&"wood", Vector3(x1 + 0.065, y0 + h + 0.42, gz), Vector3(0.05, 0.62, 1.9), Color(0.16, 0.2, 0.17))
	var sign_board := BuildingKit.sign(parent, UiTheme.caps(tr("UI_WAREHOUSE")), Vector3(x1 + 0.095, y0 + h + 0.42, gz), PI * 0.5, 120, Color(0.95, 0.9, 0.78), Color(0, 0, 0, 0), false)
	sign_board.pixel_size = 0.0035
	_add_points(parent, desk)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	parent.add_child(mi)
	parent.add_child(BuildingKit.detail_instance(detail.build()))
	BuildingKit.collider(parent, cols)
	var light := OmniLight3D.new()
	light.position = Vector3(_rect.get_center().x, y0 + 2.8, _rect.get_center().y)
	light.light_color = Color(1.0, 0.88, 0.68)
	light.light_energy = 0.8
	light.omni_range = 7.0
	parent.add_child(light)


## Level 2: a plank loft over the back row of pallets on posts between them, with
## sacks and crates up there and a ladder.
func _build_loft(mb: MeshBuilder, cols: Array) -> void:
	var x0 := _rect.position.x
	var z0 := _rect.position.y
	var x1 := _rect.end.x
	var floor_y := _y0 + 2.3
	var front := z0 + 1.65
	var dark := Color(0.34, 0.28, 0.22)
	for px: float in [x0 + 0.25, x0 + 2.05, x0 + 3.95, x0 + 5.85, x1 - 0.25]:
		mb.box_at(&"wood", Vector3(px, (_y0 + 0.06 + floor_y) * 0.5, front), Vector3(0.14, floor_y - _y0 - 0.06, 0.14), dark)
		cols.append([Vector3(px, (_y0 + floor_y) * 0.5, front), Vector3(0.14, floor_y - _y0, 0.14), 0.0])
	mb.box_at(&"wood", Vector3((x0 + x1) * 0.5, floor_y - 0.12, front), Vector3(x1 - x0 - 0.3, 0.16, 0.14), dark, Vector3.ZERO, true)
	var boards := int((front - z0 - T) / 0.2)
	for k in boards:
		var bz := z0 + T + 0.1 + k * (front + 0.07 - z0 - T) / boards
		mb.box_at(&"planks", Vector3((x0 + x1) * 0.5, floor_y, bz), Vector3(x1 - x0 - 2.0 * T, 0.05, 0.19), PLANK.lightened(0.04 * (k % 3)))
	cols.append([Vector3((x0 + x1) * 0.5, floor_y, (z0 + T + front + 0.07) * 0.5), Vector3(x1 - x0 - 2.0 * T, 0.06, front + 0.07 - z0 - T), 0.0])
	# Rail along the front edge.
	for ry: float in [0.5, 0.95]:
		mb.box_at(&"wood", Vector3((x0 + x1) * 0.5 + 0.6, floor_y + ry, front), Vector3(x1 - x0 - 1.6, 0.07, 0.06), dark, Vector3.ZERO, true)
	for px: float in [x0 + 2.05, x0 + 3.95, x0 + 5.85, x1 - 0.25]:
		mb.box_at(&"wood", Vector3(px, floor_y + 0.5, front), Vector3(0.08, 1.0, 0.08), dark)
	# Sacks and crates stored up there.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 7:
		var p := Vector3(x0 + 1.7 + i * 0.9 + rng.randf_range(-0.12, 0.12), floor_y + 0.2, z0 + T + 0.55 + rng.randf_range(-0.15, 0.25))
		if i % 3 == 1:
			mb.box_at(&"planks", p + Vector3(0, 0.05, 0), Vector3(0.6, 0.5, 0.5), Color(0.56, 0.48, 0.38), Vector3(0, rng.randf_range(-15, 15), 0))
		else:
			mb.blob(&"cloth", Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 0.8)), p), 0.3, 2, Color(0.72, 0.64, 0.48), 0.1, 2.0, 90 + i, 0.0, true, -0.35)
	# Ladder up at the west end, where the rail leaves a gap.
	var foot := Vector3(x0 + 0.75, _y0 + 0.06, front + 0.45)
	var top := Vector3(x0 + 0.75, floor_y + 0.9, front - 0.05)
	for sx: float in [-0.22, 0.22]:
		mb.cylinder_between(&"wood", foot + Vector3(sx, 0, 0), top + Vector3(sx, 0, 0), 0.03, 0.03, 6, dark)
	for k in 9:
		var p := foot.lerp(top, (k + 0.6) / 9.6)
		mb.cylinder_between(&"wood", p + Vector3(-0.22, 0, 0), p + Vector3(0.22, 0, 0), 0.02, 0.02, 6, dark)


# --- Grandpa's run-down shed (level 0) ------------------------------------------------
# Same plinth, ramp, doorway, desk and ledger as the repaired one, so it stores and
# loads the same (half the racks are rotten: see ProjectTable.WAREHOUSE_CAPACITY).

## A hole broken through an old wall: a RepairSpot's place.
func _hole_op(at: float, w: float, bottom: float, top: float) -> Dictionary:
	return {"at": at, "w": w, "bottom": bottom, "top": top, "hole": true, "spot": true}


func _build_ruin(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RUIN_SEED
	var mb := MeshBuilder.new()
	# Cobwebs, dust and puddles: no shadows, off the rain map's layer.
	var clutter := MeshBuilder.new()
	var cols := []
	var y0 := _y0
	var c := _rect.get_center()
	var x0 := _rect.position.x
	var z0 := _rect.position.y
	var x1 := _rect.end.x
	var z1 := _rect.end.y
	var ht := T * 0.5
	_build_base(mb, cols, true)
	# Board walls on studs over an old inner lining: daylight only comes through the holes.
	var door := {"at": 4.0, "w": 3.6, "bottom": 0.0, "top": 3.0}
	var window := {"at": 3.3, "w": 1.4, "bottom": 1.3, "top": 2.3}
	# Six holes (two in each wall but the front, whose door leaves hide it) are the
	# RepairSpots: wood nailed over each one repairs the shed.
	var spots: Array[Dictionary] = []
	for wall: Array in [
			[Vector2(x0, z1 - ht), Vector2(x1, z1 - ht), [door], 0.18],
			[Vector2(x1, z0 + ht), Vector2(x0, z0 + ht), [_hole_op(5.4, 0.9, 1.6, 2.5), _hole_op(2.0, 0.7, 0.4, 1.1)], 0.2],
			[Vector2(x1 - ht, z1 - T), Vector2(x1 - ht, z0 + T), [window, _hole_op(5.8, 0.6, 0.3, 0.9), _hole_op(1.2, 0.6, 1.35, 2.05)], 0.16],
			[Vector2(x0 + ht, z0 + T), Vector2(x0 + ht, z1 - T), [_hole_op(4.6, 0.7, 0.4, 1.1), _hole_op(5.9, 0.55, 1.3, 1.95)], 0.22]]:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		BuildingKit.board_wall(mb, cols, a, b, y0, H, T, &"planks_old", PLANK_OLD, wall[2], rng, float(wall[3]), &"wood_old_in", 0.9)
		for o: Dictionary in wall[2]:
			if o.get("spot", false):
				spots.append({"xf": BuildingKit.opening_frame(a, b, y0, T, o),
						"size": Vector2(float(o["w"]), float(o["top"]) - float(o["bottom"]))})
	# The east window, boarded up from outside (it stops people like the glass did).
	var wz := z1 - T - 3.3
	var wmid := y0 + 1.8
	# Its frame stands 8 mm into the opening (the wall's boards and studs end behind its
	# faces, not in them), the jambs between the head and the sill.
	for piece: Array in [[Vector3(0, 0, -0.736), Vector3(T + 0.04, 0.984, 0.088)], [Vector3(0, 0, 0.736), Vector3(T + 0.04, 0.984, 0.088)],
			[Vector3(0, 0.536, 0), Vector3(T + 0.04, 0.088, 1.56)], [Vector3(0.04, -0.5335, 0), Vector3(T + 0.12, 0.083, 1.64)]]:
		mb.box_at(&"wood_old", Vector3(x1 - ht, wmid, wz) + (piece[0] as Vector3), piece[1], POST_OLD.lightened(0.1))
	for k in 3:
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-8.0, 8.0)))
		BuildingKit.plank(mb, &"planks_old", Transform3D(tilt, Vector3(x1 + 0.04, wmid + (k - 1) * 0.36, wz)),
				Vector3(0.03, BuildingKit.BOARD_H, 1.7), Color(0.45, 0.45, 0.44) * rng.randf_range(0.85, 1.05),
				Vector2(rng.randf() * 2.0, BuildingKit.BOARD_SEAM + k * 4 * BuildingKit.BOARD_H))
	cols.append([Vector3(x1 - ht, wmid, wz), Vector3(T, 1.0, 1.4), 0.0])
	# Corner posts (one leaning) and the beam and jambs of the door.
	for cx: float in [x0 + 0.1, x1 - 0.1]:
		for cz: float in [z0 + 0.1, z1 - 0.1]:
			var lean := 2.5 if cx < c.x and cz > c.y else 0.0
			# (Let 2 cm into the plinth and ending 2 cm under the walls' tops: not in their planes.)
			mb.box_at(&"wood_old", Vector3(cx, y0 + H * 0.5 - 0.02, cz), Vector3(0.24, H, 0.24), POST_OLD * rng.randf_range(0.9, 1.05),
					Vector3(0, 0, lean), true)
	# (The beam's back 2 cm inside the studs' inner faces, the jambs let 1 cm into the floor.)
	mb.box_at(&"wood_old", Vector3(x0 + 4.0, y0 + 3.1, z1 + 0.01), Vector3(4.2, 0.25, 0.32), POST_OLD)
	for jx: float in [x0 + 2.14, x0 + 5.86]:
		mb.box_at(&"wood_old", Vector3(jx, y0 + 1.49, z1 - ht), Vector3(0.1, 3.0, T + 0.04), POST_OLD.lightened(0.08), Vector3.ZERO, true)
	# Door leaves: the west one off its rail, leaning on the wall outside; the east one
	# hanging askew where it was parked. The rail has broken in two.
	var ground := TerrainData.height(x0 + 1.0, z1 + 1.0)
	var west_leaf := Basis(Vector3.RIGHT, deg_to_rad(-17.0)) * Basis(Vector3.BACK, deg_to_rad(2.0))
	var west_at := Vector3(x0 + 1.0, ground + 1.45, z1 + 0.62)
	_door_leaf(mb, Transform3D(west_leaf, west_at), 1, rng)
	cols.append([west_at, Vector3(1.8, 3.0, 0.1), west_leaf])
	_door_leaf(mb, Transform3D(Basis(Vector3.BACK, deg_to_rad(-5.0)), Vector3(x0 + 7.05, y0 + 1.46, z1 + 0.14)), 3, rng)
	mb.box_at(&"rusty", Vector3(x0 + 6.0, y0 + 3.05, z1 + 0.2), Vector3(4.0, 0.08, 0.06), Color(0.34, 0.24, 0.17))
	mb.box(&"rusty", Transform3D(Basis(Vector3.BACK, deg_to_rad(4.0)), Vector3(x0 + 4.0, y0 + 3.05, z1 + 0.2) + Vector3(-2.0, -0.14, 0)),
			Vector3(4.0, 0.08, 0.06), Color(0.34, 0.24, 0.17))
	_tin_roof(mb, clutter, cols, rng)
	# An old crate for a desk, the ledger still on it.
	var desk := Vector3(x0 + 6.8, y0 + 0.06, z1 - 0.9)
	mb.box_at(&"planks_old", desk + Vector3(0, 0.43, 0), Vector3(0.8, 0.86, 0.6), Color(0.46, 0.44, 0.42), Vector3(0, 4, 0))
	for band: float in [0.1, 0.76]:
		mb.box_at(&"wood_old", desk + Vector3(0, band, 0), Vector3(0.82, 0.07, 0.62), POST_OLD, Vector3(0, 4, 0))
	mb.box_at(&"planks_old", desk + Vector3(0, 0.885, 0), Vector3(1.0, 0.035, 0.66), Color(0.48, 0.46, 0.44), Vector3(0, -3, 0))
	mb.box_at(&"paper", desk + Vector3(0, 0.915, 0), Vector3(0.36, 0.02, 0.26), Color(0.8, 0.76, 0.64), Vector3(0, 12, 0))
	_add_points(parent, desk - Vector3(0, 0.06, 0))
	# The gable board has slipped on its nails and faded.
	var gz := c.y
	mb.box_at(&"wood_old", Vector3(x1 + 0.03, y0 + H + 0.42, gz), Vector3(0.05, 0.62, 1.9), Color(0.2, 0.22, 0.2), Vector3(-4, 0, 0))
	var sign_board := BuildingKit.sign(parent, UiTheme.caps(tr("UI_WAREHOUSE")), Vector3(x1 + 0.06, y0 + H + 0.42, gz), PI * 0.5, 120,
			Color(0.66, 0.62, 0.54), Color(0, 0, 0, 0), false)
	sign_board.pixel_size = 0.0035
	sign_board.rotation.z = deg_to_rad(-4.0)
	_ruin_junk(parent, mb, cols, rng)
	# Dust, dried mud and a puddle under the roof hole.
	for i in 5:
		var dp := Vector3(rng.randf_range(x0 + 0.8, x1 - 0.8), y0 + 0.062, rng.randf_range(z0 + 1.8, z1 - 0.6))
		clutter.blob(&"dirt_old", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.5, 0.012, 1.0)), dp),
				rng.randf_range(0.45, 0.7), 2, Color(0.27, 0.24, 0.2), 0.45, 1.8, 130 + i, 0.0, true)
	clutter.blob(&"water_still", Transform3D(Basis.from_scale(Vector3(1.0, 0.01, 1.6)), Vector3(x0 + 4.45, y0 + 0.061, c.y + 1.9)), 0.5, 2,
			Color(0.14, 0.14, 0.13), 0.35, 1.6, 17, 0.0, true)
	# Cobwebs in the top corners and under the door beam.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(c.x + sx * (_rect.size.x * 0.5 - T - 0.13), y0 + H - 0.05, c.y + sz * (_rect.size.y * 0.5 - T - 0.13))
			BuildingKit.cobweb(clutter, corner, Vector3(-sx, -0.5, 0).normalized(), Vector3(0, -0.5, -sz).normalized(),
					rng.randf_range(0.5, 0.8), rng)
	BuildingKit.cobweb(clutter, Vector3(x0 + 2.2, y0 + 2.97, z1 - T), Vector3(1, -0.3, 0).normalized(), Vector3(0, -1, 0), 0.45, rng)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.build()
	parent.add_child(mi)
	RepairSpot.add_all(parent, &"warehouse", spots, mi)
	var cm := MeshInstance3D.new()
	cm.name = "Clutter"
	cm.mesh = clutter.build()
	cm.layers = 2
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(cm)
	BuildingKit.collider(parent, cols)
	var light := OmniLight3D.new()
	light.position = Vector3(c.x, y0 + 2.8, c.y)
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 0.35
	light.omni_range = 6.0
	parent.add_child(light)
	# Weeds up the west and north walls; the scythe cuts them for hay.
	var weeds: Array[Vector2] = [Vector2(x0 - 1.0, z0 + 1.0), Vector2(x0 - 1.1, z1 - 0.8), Vector2(c.x + 1.2, z0 - 1.0)]
	for i in weeds.size():
		var patch := GrassPatch.new()
		patch.name = "Weed%d" % i
		patch.patch_seed = 400 + i
		patch.resource_id = "warehouse_weed_%d" % i
		patch.position = Vector3(weeds[i].x, TerrainData.height(weeds[i].x, weeds[i].y), weeds[i].y)
		parent.add_child(patch)


## A sliding door leaf (1.8 x 3.0, centred on `xf`): vertical boards on two ledges and
## a brace (behind it, or in front when `ledges_out`). Board `missing` is gone below
## the lower ledge.
func _door_leaf(mb: MeshBuilder, xf: Transform3D, missing: int, rng: RandomNumberGenerator, key := &"planks_old",
		ledge_key := &"wood_old", color := Color(0.42, 0.42, 0.41), ledge_color := POST_OLD, ledges_out := false) -> void:
	var count := 10
	var step := 1.8 / count
	for k in count:
		var bottom := -1.5 + (0.75 if k == missing else 0.0)
		var hh := 1.5 - bottom
		BuildingKit.plank(mb, key, xf * Transform3D(Basis(), Vector3(-0.9 + (k + 0.5) * step, (bottom + 1.5) * 0.5, 0)),
				Vector3(BuildingKit.BOARD_H, hh, 0.035), color * rng.randf_range(0.88, 1.06),
				Vector2(rng.randf() * 2.0, BuildingKit.BOARD_SEAM + rng.randi_range(0, 12) * BuildingKit.BOARD_H), true)
	var lz := 0.035 if ledges_out else -0.035
	for ly: float in [-0.9, 0.9]:
		mb.box(ledge_key, xf * Transform3D(Basis(), Vector3(0, ly, lz)), Vector3(1.74, 0.14, 0.035), ledge_color, true)
	BuildingKit.beam(mb, ledge_key, xf * Vector3(-0.8, -0.8, lz), xf * Vector3(0.8, 0.8, lz), Vector2(0.12, 0.035), ledge_color, true)


## Corner boards over the siding's ends at the shed's four corners, the grain running
## up them (`key` is a rough_wood key).
func _corner_boards(mb: MeshBuilder, y0: float, h: float, key: StringName, color: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var cx := _rect.get_center().x + sx * _rect.size.x * 0.5
			var cz := _rect.get_center().y + sz * _rect.size.y * 0.5
			BuildingKit.plank(mb, key, Transform3D(Basis(), Vector3(cx - sx * 0.0525, y0 + h * 0.5, cz + sz * 0.028)), Vector3(0.195, h, 0.034),
					color, Vector2(0.3 + sx * 0.2 + sz * 0.45, 0.0))
			BuildingKit.plank(mb, key, Transform3D(Basis(), Vector3(cx + sx * 0.028, y0 + h * 0.5, cz - sz * 0.0695)), Vector3(0.034, h, 0.161),
					color, Vector2(0.9 + sx * 0.2 + sz * 0.45, 0.4))


## The tin roof on purlins and rafters, with fascia and barge boards. `sound` (the
## repaired shed): galvanised sheets all there, a flashing along the ridge, a gutter
## and downpipe at the back. Otherwise Grandpa's: loose, rusty sheets (some replaced
## once with galvanised ones gone rusty in turn), two gone from ridge to eave (the
## purlins and rafters show), one lying by the west wall. The rafter tails go into
## `clutter` (small, drawn without shadows).
func _tin_roof(mb: MeshBuilder, clutter: MeshBuilder, cols: Array, rng: RandomNumberGenerator, sound := false) -> void:
	var c := _rect.get_center()
	var x0 := _rect.position.x
	var x1 := _rect.end.x
	var run := _rect.size.y * 0.5 + 0.45
	var theta := atan2(RISE, _rect.size.y * 0.5)
	var slab_len := run / cos(theta)
	var ridge := _y0 + H + RISE
	var length := _rect.size.x + 0.6
	var sheets := 10
	var sw := length / sheets
	for side: float in [1.0, -1.0]:
		var basis := Basis(Vector3.RIGHT, theta * side)
		var n := basis.y
		var frame := BuildingKit.slope_frame(Vector3(c.x, ridge, c.y), theta, side)
		var trim_c := Color(0.34, 0.29, 0.24) if sound else POST_OLD
		var edge := BuildingKit.roof_trim(mb, frame, length - 0.04, 0.0, slab_len - 0.03, _rect.size.y * 0.5 / cos(theta),
				&"wood_ext" if sound else &"wood_old", trim_c, &"wood_ext" if sound else &"wood_old", trim_c * 0.95, 0.0, -1.0, clutter)
		if sound and side < 0.0:
			var g := edge + Vector3(0, -0.04, -0.075)
			BuildingKit.gutter(mb, g - Vector3(length * 0.5 - 0.04, 0, 0), g + Vector3(length * 0.5 - 0.04, 0, 0), Vector3.FORWARD)
			BuildingKit.downpipe(mb, Vector3(x0 + 0.3, g.y - 0.05, g.z), Vector3(x0 + 0.3, 0, _rect.position.y - 0.012), Vector3.FORWARD,
					TerrainData.height(x0 + 0.3, _rect.position.y - 0.35))
		for i in sheets:
			if not sound and ((side > 0.0 and i == 5) or (side < 0.0 and i == 2)):
				continue
			var cx := c.x - length * 0.5 + (i + 0.5) * sw
			var sheet_len := slab_len
			var slip := 0.0
			var roll := Basis()
			var key := &"corrugated"
			var col := TIN * rng.randf_range(0.92, 1.04)
			if not sound:
				sheet_len -= 0.25 if rng.randf() < 0.25 else 0.0
				slip = rng.randf_range(0.02, 0.18) if rng.randf() < 0.3 else 0.0
				roll = Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-1.2, 1.2)))
				var worn := rng.randf() < 0.35
				key = &"corrugated_worn" if worn else &"corrugated_old"
				col = Color(0.55, 0.55, 0.55) * rng.randf_range(0.88, 1.05) if worn else Color(0.5, 0.49, 0.48) * rng.randf_range(0.85, 1.08)
			var s := sheet_len * 0.5 + slip
			var p := Vector3(cx, ridge - sin(theta) * s, c.y + side * cos(theta) * s) + n * (0.04 + 0.012 * (i % 2) + rng.randf() * 0.008)
			mb.box(key, Transform3D(basis * roll, p), Vector3(sw + 0.06, 0.03, sheet_len), col)
		# Purlins across the rafters.
		for k in 3:
			var s := 0.45 + k * (slab_len - 0.8) / 2.0
			var p := Vector3(c.x, ridge - sin(theta) * s, c.y + side * cos(theta) * s) - n * 0.03
			mb.box(&"wood_ext" if sound else &"wood_old", Transform3D(basis, p), Vector3(length - 0.1, 0.1, 0.08), trim_c, true)
		if not sound:
			for k in 6:
				var rx := x0 + 0.1 + k * (x1 - x0 - 0.2) / 5.0
				var p := Vector3(rx, ridge - sin(theta) * slab_len * 0.5, c.y + side * cos(theta) * slab_len * 0.5) - n * 0.15
				mb.box(&"wood_old", Transform3D(basis, p), Vector3(0.08, 0.14, slab_len), POST_OLD.darkened(0.1), true)
		else:
			# Flashing bent over the ridge.
			mb.box(&"corrugated", Transform3D(basis, Vector3(c.x, ridge, c.y) + basis.z * 0.13 + n * 0.075), Vector3(length + 0.08, 0.012, 0.3),
					TIN * 0.9)
	if sound:
		return
	# The ridge cap and the gables.
	mb.box_at(&"corrugated_old", Vector3(c.x, ridge + 0.07, c.y), Vector3(length + 0.1, 0.05, 0.36), Color(0.5, 0.47, 0.45))
	for gx: float in [x0 + T * 0.5, x1 - T * 0.5]:
		mb.prism(&"planks_old", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(gx, _y0 + H, c.y)), _rect.size.y, RISE, T, PLANK_OLD, false)
	# One sheet blew off and leans on the west wall.
	var ground := TerrainData.height(x0 - 0.5, c.y - 1.2)
	var b := Basis(Vector3.BACK, deg_to_rad(-15.0)) * Basis(Vector3.UP, deg_to_rad(4.0))
	var at := Vector3(x0 - 0.1 - 1.4 * sin(deg_to_rad(15.0)), ground + 1.4 * cos(deg_to_rad(15.0)), c.y - 1.2)
	mb.box(&"corrugated_old", Transform3D(b, at), Vector3(0.03, 2.8, sw + 0.06), Color(0.5, 0.48, 0.46))
	cols.append([at, Vector3(0.1, 2.8, sw + 0.06), b])
	# A few scraps of tin and rust flakes under the missing front sheet.
	for k in 3:
		var fp := Vector3(x0 + 4.2 + rng.randf_range(-0.4, 0.5), _y0 + 0.065, c.y + 1.2 + rng.randf_range(-0.5, 1.0))
		clutter.box_at(&"rusty", fp, Vector3(rng.randf_range(0.1, 0.25), 0.008, rng.randf_range(0.08, 0.2)), Color(0.4, 0.26, 0.17),
				Vector3(rng.randf_range(-3, 3), rng.randf_range(0, 180), 0))


## Junk in the front-west corner, clear of the pallets and the doorway lane: a barrel,
## a broken pallet leaning on the wall, a rusty bucket and rotten planks.
func _ruin_junk(parent: Node3D, mb: MeshBuilder, cols: Array, rng: RandomNumberGenerator) -> void:
	var x0 := _rect.position.x
	var z1 := _rect.end.y
	var fy := _y0 + 0.06
	var barrel := MeshInstance3D.new()
	barrel.name = "OldBarrel"
	barrel.mesh = PlaceableModels.mesh(&"pickle_barrel")
	# North of the pallet (which fills z1-1.25..z1-0.25), still clear of the side pallets.
	barrel.position = Vector3(x0 + 0.6, fy, z1 - 1.62)
	barrel.rotation.y = 0.9
	parent.add_child(barrel)
	# The pallet: three deck boards on three stringers, one board split off.
	var pallet := MeshBuilder.new()
	for k in 3:
		pallet.box_at(&"wood_old", Vector3(0, 0.05, -0.4 + k * 0.4), Vector3(1.0, 0.09, 0.09), POST_OLD)
	for k in 5:
		if k == 3:
			continue
		pallet.box_at(&"planks_old", Vector3(-0.4 + k * 0.2, 0.115, 0), Vector3(0.15, 0.02, 0.95), Color(0.5, 0.48, 0.45))
	# Stood on its edge, leaning back on the wall.
	mb.append(pallet, Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(-72.0)), Vector3(x0 + T + 0.32, fy + 0.47, z1 - 0.75)))
	var bucket := Transform3D(Basis(), Vector3(x0 + 1.3, fy, z1 - 1.72))
	mb.ring(&"rusty", bucket, 0.16, 0.148, 0.3, 14, Color(0.42, 0.28, 0.2), 0.12, 5)
	mb.disc(&"rusty", bucket * Transform3D(Basis(), Vector3(0, 0.01, 0)), 0.148, 14, Color(0.3, 0.2, 0.14))
	for k in 3:
		var from := Vector3(x0 + 0.9 + rng.randf() * 0.3, fy + 0.02 + k * 0.025, z1 - 0.45 - rng.randf() * 0.2)
		var to := from + Vector3(rng.randf_range(0.3, 0.6), 0.0, rng.randf_range(-0.9, -0.6))
		BuildingKit.beam(mb, &"planks_old", from, to, Vector2(0.025, BuildingKit.BOARD_H), Color(0.42, 0.42, 0.4) * rng.randf_range(0.85, 1.0),
				false, 0.0, Vector2(rng.randf() * 2.0, BuildingKit.BOARD_SEAM + rng.randi_range(0, 12) * BuildingKit.BOARD_H))
	cols.append([Vector3(x0 + 0.95, fy + 0.5, z1 - 1.1), Vector3(1.5, 1.0, 1.6), 0.0])


## Stock changes come in bursts (storing or loading everything moves one kind of good
## after another): the pallets are checked once, after the burst.
func _queue_stock() -> void:
	if not _stock_queued:
		_stock_queued = true
		_refresh_stock.call_deferred()


## Pallets along the back and side walls fill up with the stock level.
func _refresh_stock() -> void:
	_stock_queued = false
	# Crated hens stand in the crate corner, not on the pallets.
	var goods := FarmState.warehouse.total() - LiveCrates.count_at(&"warehouse")
	var fill := float(goods) / maxf(FarmState.warehouse.capacity, 1.0)
	var full := mini(int(ceil(fill * PALLETS)), PALLETS)
	if full == _full_shown:
		return
	_full_shown = full
	if not _stock_meshes.has(full):
		_stock_meshes[full] = _build_stock(full)
	_stock_mesh.mesh = _stock_meshes[full]


## Crates and sacks on the first `full` pallets (the same ones at every level).
func _build_stock(full: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var y0 := TerrainData.height(_rect.get_center().x, _rect.get_center().y) + 0.31
	var spots: Array[Vector3] = []
	for i in 4:
		spots.append(Vector3(_rect.position.x + 1.1 + i * 1.9, y0, _rect.position.y + 0.95))
	for i in 2:
		spots.append(Vector3(_rect.position.x + 0.95, y0, _rect.position.y + 2.9 + i * 1.6))
		spots.append(Vector3(_rect.end.x - 0.95, y0, _rect.position.y + 2.9 + i * 1.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in spots.size():
		var p := spots[i]
		mb.box_at(&"wood_in", p + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), Color(0.55, 0.46, 0.36))
		if i >= full:
			continue
		var layers := 1 + rng.randi_range(0, 2)
		for l in layers:
			for c in 4:
				var off := Vector3(-0.3 + (c % 2) * 0.6, 0.14 + l * 0.42 + 0.21, -0.25 + (c / 2) * 0.5)
				if rng.randf() < 0.5:
					mb.box_at(&"planks", p + off, Vector3(0.56, 0.42, 0.46), Color(0.58, 0.5, 0.4))
				else:
					mb.blob(&"cloth", Transform3D(Basis.from_scale(Vector3(0.9, 0.7, 0.8)), p + off), 0.28, 2, Color(0.74, 0.66, 0.5), 0.1, 2.0, i * 7 + c, 0.0, true, -0.35)
	return mb.build() if not mb.is_empty() else null
