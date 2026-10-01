class_name AnimalHousing
extends Node3D
## Animal housing: level 1 is an open pen (fence, feed and water troughs), level 2
## adds a closed building inside the pen that shelters animals from rain, snow and
## the night. Also answers the AI's questions about where to go.
## Grandpa's barn and chicken run sit at the world origin, so their rects are world
## rects. A coop put up from a kit (ChickenCoop) is a level-2 house in its own frame
## (`frame`: where it stands and how it is turned; its rects are in that frame) with a
## free-range yard around it instead of a fence, and a door that opens and shuts
## (`door_open`): shut, no hen goes in or out. Made longer at its east end (`expansion`
## steps, `added` metres of house), its door stays where it was (`door_shift` off the
## house's middle) and so does its floor; while the new part goes up its builders' ground
## (`works`) is kept clear of the hens.

signal changed

var kind := "barn"
var level := 0
var pen := Rect2()
var building := Rect2()
var gate: Array = []
var feed: Trough
var water: Trough
## The Animal bodies living here (each adds itself while it is in the tree).
var animals: Array[Animal] = []
## A coop put up from a kit: its own frame, a yard without a fence, a door.
var placed := false
## Its key in the Animals' homes ("" for Grandpa's barn and run).
var home_id := ""
## World transform of the rects: a turn about Y and a spot on the ground (identity for
## Grandpa's barn and run, whose rects are world rects).
var frame := Transform3D.IDENTITY
## The coop door stands open (always, for housing without a door).
var door_open := true
var door: CoopDoor
## A kit-built coop's expansion steps (its places: ProjectTable.KIT_COOP_CAPACITY), the
## metres of house they added at its east end, and the door's offset along X from the
## house's middle (the door stays at the middle of the house as it came).
var expansion := 0
var added := 0.0
var door_shift := 0.0
## Ground the hens keep off (rects of the frame): an expansion going up.
var works: Array[Rect2] = []

## Half the width of the straight way through a coop or barn door (plan_route).
const DOOR_LANE := 0.3
## The coop's ramp (AnimalBuildings.coop): its length out from the door, the height of its
## boards' top over the slope, its cleats (distance out from the door) and their height
## over the boards.
const RAMP_LEN := 1.1
const RAMP_BOARD := 0.026
const RAMP_CLEATS: Array[float] = [0.11, 0.33, 0.55, 0.77, 0.99]
const RAMP_CLEAT := 0.024

var _inv := Transform3D.IDENTITY
var _structure: Node3D
var _building_node: Node3D
var _floor_y := 0.0
## World height of a kit-built coop's floor: it stands level where the ground doesn't.
var _floor_top := 0.0


func setup(housing_kind: String) -> void:
	kind = housing_kind
	if kind == "barn":
		pen = WorldLayout.BARN_PEN
		building = WorldLayout.BARN_BUILDING
		gate = WorldLayout.BARN_GATE
	else:
		pen = WorldLayout.COOP_PEN
		building = WorldLayout.COOP_BUILDING
		gate = WorldLayout.COOP_GATE
	name = "Barn" if kind == "barn" else "Coop"
	# Animals may arrive at any time: have their models ready by then.
	AnimalModels.preload_models()


## A coop put up from a kit: `yard` (where its hens scratch about) and `house` (the
## closed coop, door toward +Z) in the frame `at` (turned about Y only), keyed `id`
## in the Animals' homes. Call before adding it to the tree; set_level(2) then builds it.
func setup_placed(at: Transform3D, yard: Rect2, house: Rect2, open: bool, id: String) -> void:
	kind = "coop"
	placed = true
	home_id = id
	pen = yard
	building = house
	gate = []
	door_open = open
	frame = Transform3D(at.basis.orthonormalized(), Vector3(at.origin.x, 0.0, at.origin.z))
	_inv = frame.affine_inverse()
	name = "PlacedCoop"
	# The node stays at the world origin, so its animals keep world positions and turns.
	top_level = true
	AnimalModels.preload_models()


func capacity() -> int:
	if placed and level >= 2:
		return ProjectTable.KIT_COOP_CAPACITY[clampi(expansion, 0, ProjectTable.KIT_COOP_CAPACITY.size() - 1)]
	var table := ProjectTable.BARN_CAPACITY if kind == "barn" else ProjectTable.COOP_CAPACITY
	return table[clampi(level, 0, table.size() - 1)]


func free_space() -> int:
	return capacity() - Animals.count_at(self)


func has_shelter() -> bool:
	return level >= 2


## Whether animals can go in and out of the building (a shut coop door stops them).
func can_pass() -> bool:
	return door_open or level < 2


## Opens or shuts the coop door (the CoopDoor swings it; this is the rule). Hens on
## their way through stop on the side they are on.
func set_door(open: bool) -> void:
	if open == door_open:
		return
	door_open = open
	if not open:
		for n in animals:
			n.door_shut()
	changed.emit()


## The animals out in the pen or yard (not in the building, not ridden or away).
func animals_outside() -> Array[Animal]:
	var out: Array[Animal] = []
	for n in animals:
		if not n.indoors and not n.ridden and not n.data.away:
			out.append(n)
	return out


func set_level(new_level: int, animate := false) -> void:
	if new_level == level:
		return
	level = new_level
	_rebuild(animate)


## A kit-built coop's house `house` after `step` expansion steps that added `length`
## metres at its east end (the door and the floor stay where they were). Call before
## set_level(2) builds it; on a coop that stands, it goes up again at once (the troughs'
## contents and the door kept, the animals where they are).
func set_extension(house: Rect2, step: int, length: float) -> void:
	building = house
	expansion = step
	added = length
	door_shift = -length * 0.5
	if level > 0:
		_rebuild(false)


## Puts up the structure for the level it is at (the troughs keep what was in them).
func _rebuild(animate: bool) -> void:
	var feed_amount := feed.amount if feed else 0.0
	var water_amount := water.amount if water else 0.0
	if _structure:
		# Gone at the frame's end: its name is the new one's at once.
		_structure.name = "StructureOld"
		_structure.queue_free()
		_structure = null
	feed = null
	water = null
	door = null
	if level <= 0:
		return
	_structure = Node3D.new()
	_structure.name = "Structure"
	_structure.transform = frame
	add_child(_structure)
	_build_pen()
	if level >= 2:
		_build_building()
	_build_troughs()
	feed.set_amount(feed_amount)
	water.set_amount(water_amount)
	# Animals standing where the new building went up are now inside it.
	if level >= 2:
		for n in animals:
			if not n.ridden and building.grow(0.3).has_point(flat(n.global_position)):
				n.indoors = true
	if animate:
		var c := pen.get_center()
		Fx.dust_cloud(world_at(c.x, c.y, 0.5), Vector2(pen.size) * 0.5)
	changed.emit()


func _build_pen() -> void:
	# A kit-built coop's hens range free about it: no fence (its yard is kept clear).
	if placed:
		return
	var fence := Fence.new()
	var f := WorldLayout.fence_around(pen, [gate])
	fence.points = f["points"]
	fence.gaps = f["gaps"]
	fence.closed = true
	fence.height = 1.25 if kind == "barn" else 1.0
	fence.post_spacing = 2.4 if kind == "barn" else 1.8
	fence.seed_value = 21 if kind == "barn" else 22
	_structure.add_child(fence)
	# Invisible gate that stops animals but lets the player through.
	var barrier := StaticBody3D.new()
	barrier.collision_layer = 32
	barrier.collision_mask = 0
	var gp := WorldLayout.gate_point(pen, gate, 0.0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var along_x := String(gate[0]) in ["n", "s"]
	box.size = Vector3(float(gate[2]) + 0.4, 2.0, 0.3) if along_x else Vector3(0.3, 2.0, float(gate[2]) + 0.4)
	cs.shape = box
	cs.position = gp + Vector3(0, 1.0, 0)
	barrier.add_child(cs)
	_structure.add_child(barrier)
	if kind == "coop":
		# Grandpa's run (old farms) takes crated hens bought in town at its gate.
		var drop := CrateGate.new()
		drop.name = "CrateGate"
		drop.housing = self
		var drop_cs := CollisionShape3D.new()
		var drop_box := BoxShape3D.new()
		drop_box.size = Vector3(float(gate[2]), 1.3, 0.5) if along_x else Vector3(0.5, 1.3, float(gate[2]))
		drop_cs.shape = drop_box
		drop_cs.position = Vector3(gp.x, TerrainData.height(gp.x, gp.z) + 0.65, gp.z)
		drop.add_child(drop_cs)
		_structure.add_child(drop)


func _build_building() -> void:
	var data := AnimalBuildings.barn(building.size) if kind == "barn" \
			else AnimalBuildings.coop(building.size, not placed, door_shift, added)
	_floor_y = float(data.get("floor_y", 0.0))
	_building_node = Node3D.new()
	_building_node.name = "Building"
	var c := building.get_center()
	# Level with the ground under the door's middle (the house's as it came: a longer
	# coop's floor stays at the height it had).
	var wc := frame * Vector3(door_x(), 0.0, c.y)
	# The frame has no height: the building's local y is the world height.
	var ground := TerrainData.height(wc.x, wc.z)
	_building_node.position = Vector3(c.x, ground, c.y)
	_floor_top = ground + _floor_y
	var mi := MeshInstance3D.new()
	mi.mesh = data["mesh"]
	_building_node.add_child(mi)
	if data.has("straw_mesh"):
		# Millimetre stalks under the roof: far below a shadow texel, so no shadow pass.
		var straw := MeshInstance3D.new()
		straw.mesh = data["straw_mesh"]
		straw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		straw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		straw.layers = 2
		_building_node.add_child(straw)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for col: Array in data["colliders"]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = col[1]
		cs.shape = box
		cs.position = col[0]
		if col.size() > 2:
			cs.rotation_degrees = col[2]
		body.add_child(cs)
	_building_node.add_child(body)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4 if kind == "barn" else 1.8, 0)
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.omni_range = 7.0 if kind == "barn" else 4.0 + added * 0.5
	lamp.light_energy = 0.6
	_building_node.add_child(lamp)
	if placed:
		# A real door on the left jamb (the kit-built coop's model leaves its leaf out).
		door = CoopDoor.new()
		door.name = "Door"
		door.housing = self
		door.width = float(data["door_width"])
		door.height = float(data["door_height"])
		door.position = Vector3(door_shift - door.width * 0.5, _floor_y, building.size.y * 0.5 + 0.03)
		_building_node.add_child(door)
	_structure.add_child(_building_node)
	# The ramp too (it runs out 1.1 m in front of the door).
	Game.world.block_grass(world_rect(building.grow_individual(0.15, 0.15, 0.15, 1.3)) if placed else building)


func _build_troughs() -> void:
	feed = Trough.new()
	feed.kind = Trough.Kind.FEED
	water = Trough.new()
	water.kind = Trough.Kind.WATER
	var cap := maxi(capacity() * 2, 4)
	feed.capacity = cap
	water.capacity = cap
	if kind == "barn":
		feed.accepts = [&"hay"]
		var z := building.position.y + 0.8
		feed.position = Vector3(building.get_center().x - 3.2, 0, z)
		water.position = Vector3(building.get_center().x + 3.2, 0, z)
		feed.rotation.y = PI * 0.5
		water.rotation.y = PI * 0.5
	else:
		feed.accepts = [&"feed", &"wheat"]
		feed.long = false
		water.long = false
		if level >= 2:
			# Either side of the way in from the door; a longer coop's are longer, each
			# growing away from the door's west side (the nest boxes stand there).
			var span := 0.9 + 0.3 * expansion
			if placed:
				feed.span = span
				water.span = span
			feed.position = Vector3(door_x() - 1.35 + span * 0.5, 0, building.get_center().y - 0.9)
			water.position = Vector3(door_x() + 0.75 + span * 0.5, 0, building.get_center().y - 0.9)
		else:
			feed.position = Vector3(pen.position.x + 1.6, 0, pen.position.y + 1.4)
			water.position = Vector3(pen.end.x - 1.6, 0, pen.position.y + 1.4)
		feed.rotation.y = PI * 0.5
		water.rotation.y = PI * 0.5
	feed.outdoors = level < 2
	water.outdoors = level < 2
	for t: Trough in [feed, water]:
		# On the coop's floor, else on the ground.
		var w := frame * t.position
		t.position.y = _floor_top if (kind == "coop" and level >= 2) else TerrainData.height(w.x, w.z)
		_structure.add_child(t)


# --- Frame helpers ----------------------------------------------------------------------

## A world point in the rects' frame (x, z).
func flat(p: Vector3) -> Vector2:
	var l := _inv * p
	return Vector2(l.x, l.z)


## The world point on the ground at (x, z) of the rects' frame, `lift` above it.
func world_at(x: float, z: float, lift := 0.0) -> Vector3:
	var w := frame * Vector3(x, 0.0, z)
	w.y = TerrainData.height(w.x, w.z) + lift
	return w


## World XZ bounds of a rect of the frame.
func world_rect(r: Rect2) -> Rect2:
	var out := Rect2()
	for i in 4:
		var corner := Vector2(r.end.x if i == 1 or i == 2 else r.position.x, r.end.y if i >= 2 else r.position.y)
		var w := frame * Vector3(corner.x, 0.0, corner.y)
		if i == 0:
			out = Rect2(w.x, w.z, 0.0, 0.0)
		else:
			out = out.expand(Vector2(w.x, w.z))
	return out


## Whether `p` is in the pen (or the yard), `margin` metres grown.
func in_pen(p: Vector3, margin := 0.0) -> bool:
	return pen.grow(margin).has_point(flat(p))


## World-space direction of the frame's +Z (out of the building's door).
func front() -> Vector3:
	return frame.basis.z


## Where the middle of the building's door is along the frame's X.
func door_x() -> float:
	return building.get_center().x + door_shift


## The middle of the building (or of the pen before there is one), on the ground.
func center() -> Vector3:
	var c := building.get_center() if level >= 2 else pen.get_center()
	return world_at(c.x, c.y)


## World height of a kit-built coop's floor (it stands level).
func floor_height() -> float:
	return _floor_top


func _floor_at(ground: float) -> float:
	return _floor_top if placed else ground + _floor_y


# --- Spatial queries for the AI ------------------------------------------------------------

func is_in_building(p: Vector3) -> bool:
	return level >= 2 and building.grow(-0.1).has_point(flat(p))


## Ground height for animals, including the raised coop floor and its ramp.
func ground_height(p: Vector3) -> float:
	var h := TerrainData.height(p.x, p.z)
	if level >= 2 and _floor_y > 0.0:
		var l := flat(p)
		if building.has_point(l):
			return _floor_at(h)
		var dz := l.y - building.end.y
		if absf(l.x - door_x()) < 0.6 and dz >= 0.0 and dz < RAMP_LEN:
			# On the ramp's boards (easing on at both ends), stepping over its cleats: a
			# chick's feet are only a few centimetres long.
			var on := smoothstep(0.0, 0.08, dz) * smoothstep(RAMP_LEN, RAMP_LEN - 0.08, dz)
			var cleat := 0.0
			for c: float in RAMP_CLEATS:
				cleat = maxf(cleat, 1.0 - absf(dz - c) / 0.07)
			return lerpf(_floor_at(h), h, dz / RAMP_LEN) + on * (RAMP_BOARD + RAMP_CLEAT * cleat)
	return h


func clamp_to_pen(p: Vector3, r: float) -> Vector3:
	var inner := pen.grow(-(r + 0.35))
	var l := _inv * p
	l.x = clampf(l.x, inner.position.x, inner.end.x)
	l.z = clampf(l.z, inner.position.y, inner.end.y)
	return frame * l


## Keeps an animal inside the pen and on its side of the building walls (and off the
## builders' ground of an expansion going up).
func constrain(p: Vector3, r: float, inside: bool) -> Vector3:
	p = clamp_to_pen(p, r)
	if level < 2:
		return p if inside else _off_works(p, r)
	var l := _inv * p
	if inside:
		var bi := building.grow(-(r + 0.25))
		l.x = clampf(l.x, bi.position.x, bi.end.x)
		l.z = clampf(l.z, bi.position.y, bi.end.y)
		return frame * l
	var bo := building.grow(r + 0.15)
	if bo.has_point(Vector2(l.x, l.z)):
		# Push out through the nearest side that has room (never into the narrow
		# strip between the back wall and the fence).
		var inner := pen.grow(-(r + 0.35))
		var left := l.x - bo.position.x if bo.position.x > inner.position.x + 0.1 else INF
		var right := bo.end.x - l.x if bo.end.x < inner.end.x - 0.1 else INF
		var top := l.z - bo.position.y if bo.position.y > inner.position.y + 0.1 else INF
		var bottom := bo.end.y - l.z
		var m := minf(minf(left, right), minf(top, bottom))
		if m == left:
			l.x = bo.position.x
		elif m == right:
			l.x = bo.end.x
		elif m == top:
			l.z = bo.position.y
		else:
			l.z = bo.end.y
		return _off_works(frame * l, r)
	return _off_works(p, r)


## Out of the works' rects (each pushed out through its nearest side within the yard and
## clear of the building).
func _off_works(p: Vector3, r: float) -> Vector3:
	if works.is_empty():
		return p
	var l := _inv * p
	var inner := pen.grow(-(r + 0.35))
	var walls := building.grow(r + 0.15) if level >= 2 else Rect2()
	for w: Rect2 in works:
		var g := w.grow(r + 0.1)
		if not g.has_point(Vector2(l.x, l.z)):
			continue
		var best := INF
		var to := Vector2(l.x, l.z)
		for c: Vector2 in [Vector2(g.position.x, l.z), Vector2(g.end.x, l.z), Vector2(l.x, g.position.y), Vector2(l.x, g.end.y)]:
			if not inner.has_point(c) or walls.has_point(c):
				continue
			var d := c.distance_to(Vector2(l.x, l.z))
			if d < best:
				best = d
				to = c
		l.x = to.x
		l.z = to.y
	return frame * l


## Route as [[point, inside], ...]: through the door when entering or leaving the
## building and around it when walking between its sides. Empty when the way is shut
## (a closed coop door between the two).
func plan_route(from: Vector3, from_inside: bool, to: Vector3, to_inside: bool) -> Array:
	if level < 2:
		return [[to, false]]
	if from_inside and to_inside:
		return [[to, true]]
	if not from_inside and not to_inside:
		return _outside_route(from, to)
	if not can_pass():
		return []
	var route := []
	# Already in the doorway's lane (by the door inside, on the threshold or the ramp): on
	# through it, not back to the lane's far end first.
	var in_lane := _in_door_lane(from)
	if from_inside:
		if not in_lane:
			route.append([door_inside(), true])
		route.append([door_outside(), false])
		route.append_array(_outside_route(door_outside(), to))
	else:
		if not in_lane:
			route.append_array(_outside_route(from, door_outside()))
		route.append([door_inside(), true])
		route.append([to, true])
	return route


## Whether `p` is in the straight way through the door: between the waypoints inside and
## outside it (door_inside, door_outside) and well within the doorway's width.
func _in_door_lane(p: Vector3) -> bool:
	var l := flat(p)
	var back := building.end.y - 1.4
	var front := building.end.y + (1.6 if kind == "barn" else 1.5)
	return absf(l.x - door_x()) < DOOR_LANE and l.y > back and l.y < front


func _outside_route(a: Vector3, b: Vector3) -> Array:
	var r := building.grow(1.0)
	var la := _inv * a
	var lb := _inv * b
	var hit := false
	var steps := int(a.distance_to(b) / 0.3) + 1
	for i in steps + 1:
		var p := la.lerp(lb, float(i) / steps)
		if r.has_point(Vector2(p.x, p.z)):
			hit = true
			break
	if not hit:
		return [[b, false]]
	var z := minf(r.end.y + 0.5, pen.end.y - 1.0)
	return [[frame * Vector3(la.x, 0, z), false], [frame * Vector3(lb.x, 0, z), false], [b, false]]


## Random point in the pen outside the building.
func random_outdoor_point(rng: RandomNumberGenerator) -> Vector3:
	var inner := pen.grow(-1.2)
	for i in 20:
		var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
		if level >= 2 and building.grow(0.8).has_point(p):
			continue
		if _on_works(p, 0.8):
			continue
		# Not in the kit-built coop's chopping log.
		if placed and p.distance_to(Vector2(ChickenCoop.LOG_AT.x, ChickenCoop.LOG_AT.z)) < 0.7:
			continue
		return world_at(p.x, p.y)
	var c := pen.get_center()
	return world_at(c.x, pen.end.y - 2.0)


func random_indoor_point(rng: RandomNumberGenerator) -> Vector3:
	var inner := building.grow(-0.9)
	# Keep clear of the trough row along the back wall.
	inner.position.y += 1.0
	inner.size.y -= 1.0
	var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
	var w := frame * Vector3(p.x, 0.0, p.y)
	w.y = _floor_at(TerrainData.height(w.x, w.z))
	return w


## Waypoints round the building from `from` (outside it) to just outside its door: past
## its nearer end and along its front when the building stands in the way (none when it
## doesn't). A wolf going in by the door follows them (behind a long coop it would
## otherwise turn this way and that against the back wall).
func way_round_to_door(from: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if level < 2:
		return out
	var a := flat(from)
	var door := flat(door_outside())
	var walls := building.grow(0.5)
	var steps := int(a.distance_to(door) / 0.25) + 1
	var blocked := false
	for i in steps + 1:
		blocked = blocked or walls.has_point(a.lerp(door, float(i) / steps))
	if not blocked:
		return out
	var r := building.grow(1.0)
	var best: Array[Vector2] = []
	var best_len := INF
	for x: float in [r.position.x, r.end.x]:
		var pts: Array[Vector2] = []
		if a.y < r.position.y:
			pts.append(Vector2(x, r.position.y))
		pts.append(Vector2(x, r.end.y))
		var length := 0.0
		var at := a
		for p: Vector2 in pts:
			length += at.distance_to(p)
			at = p
		length += at.distance_to(door)
		if length < best_len:
			best_len = length
			best = pts
	for p: Vector2 in best:
		out.append(world_at(p.x, p.y))
	return out


## Whether `p` (the frame's x, z) is on the works' ground, `margin` metres grown.
func _on_works(p: Vector2, margin: float) -> bool:
	for w: Rect2 in works:
		if w.grow(margin).has_point(p):
			return true
	return false


func door_outside() -> Vector3:
	return world_at(door_x(), building.end.y + (1.6 if kind == "barn" else 1.5))


func door_inside() -> Vector3:
	var w := frame * Vector3(door_x(), 0.0, building.end.y - 1.4)
	w.y = _floor_at(TerrainData.height(w.x, w.z))
	return w


func trough_point(t: Trough) -> Vector3:
	# Stand in front of the trough (on the side away from the back wall/fence).
	return t.global_position + frame.basis * Vector3(0, 0, 1.0 if kind == "barn" else 0.7)


## Where eggs are laid: nest boxes inside the coop, or the ground of an open run.
func egg_spot(rng: RandomNumberGenerator) -> Vector3:
	if kind == "coop" and level >= 2:
		var i := rng.randi_range(0, 3)
		var nb := frame * Vector3(building.position.x + 0.45, 0.0, building.position.y + 0.55 + i * 0.75)
		nb.y = _floor_at(TerrainData.height(nb.x, nb.z)) + 0.45
		return nb
	return random_outdoor_point(rng) + Vector3(0, 0.05, 0)


## Closed buildings have plumbing: the water trough refills every morning.
func morning_refill() -> void:
	if level >= 2 and water:
		water.set_amount(water.capacity)


func save_data() -> Dictionary:
	return {"feed": feed.amount if feed else 0.0, "water": water.amount if water else 0.0}


func load_data(d: Dictionary) -> void:
	if feed:
		feed.set_amount(float(d.get("feed", 0.0)))
	if water:
		water.set_amount(float(d.get("water", 0.0)))


## Grandpa's chicken run lets crated hens in at its gate (a kit-built coop takes them
## at its door, CoopDoor). On the interaction layer only while a crate is in hand, so
## the hens stay easy to aim at through the gate; the farmer walks through it.
class CrateGate extends StaticBody3D:
	var housing: AnimalHousing

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 0
		add_to_group(&"interactable")

	func _physics_process(_delta: float) -> void:
		var layer := 4 if CoopDoor.held_crate() != &"" else 0
		if collision_layer != layer:
			collision_layer = layer

	func interact_prompt(_player: Node) -> String:
		return CoopDoor.release_prompt() if CoopDoor.held_crate() != &"" else ""

	func interact(_player: Node) -> void:
		# Just inside the gate.
		var at := housing.clamp_to_pen(WorldLayout.gate_point(housing.pen, housing.gate, -1.2), 0.3)
		if CoopDoor.release_held(housing, at):
			Audio.play("plank", at + Vector3(0, 0.6, 0), -8.0)
