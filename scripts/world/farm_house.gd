@tool
class_name FarmHouse
extends Node3D
## The player's log house. A new farm finds Grandpa's house run down (level 0): grey
## rotting boards, holes in the walls and the roof, boarded windows, a crooked old
## door. Nailing new boards over the holes in its walls (RepairSpot, wood in hand)
## repairs it (level 1), and then it grows with the construction board's upgrades
## (levels 2-3): the east and front walls and the front door stay where they are while
## the house extends west and north. Level 2 adds a kitchen with a pantry, level 3 a
## separate bedroom. The node sits at the footprint center; the door faces +Z.
##
## The first day of a new farm starts here: the front door is shut (E opens it), and
## Grandpa's things lie on his worktable inside the door (E takes each), with the
## pickup's key in the drawer of his writing desk under the east window. What was
## opened and taken is kept in FarmState.flags (the *_FLAG keys), so a repair, an
## upgrade or a load finds everything as it was. Old saves (LEGACY_FLAG) and automated
## runs find the door open and the table and drawer empty.

const FLOOR_Y := 0.56
const WALL_H := 3.0
const T := 0.22
const EAVE := 0.55
const GABLE_OVERHANG := 0.45

const LOG := Color(0.5, 0.49, 0.48)
## The repaired house's siding: a shade up on LOG, as its boards vary darker from it.
const SIDING := Color(0.55, 0.535, 0.52)
const LOG_DARK := Color(0.36, 0.33, 0.31)
const TRIM := Color(0.92, 0.9, 0.86)
const ROOF := Color(0.5, 0.48, 0.47)
const STONE := Color(0.52, 0.51, 0.5)
const FLOOR := Color(0.52, 0.5, 0.48)
const WOOD_FURN := Color(0.48, 0.42, 0.36)
## Extra render layer (20) of the house and its furniture. The lamp's shadow is drawn
## from this layer only, so wind-swayed foliage in its range (bushes, trees) doesn't
## make it re-render all six cube-map faces every frame.
const LAMP_SHADOW_LAYER := 1 << 19

## The run-down house (level 0): sun-bleached boards, trim with the paint peeling off.
const LOG_OLD := Color(0.5, 0.5, 0.49)
const TRIM_OLD := Color(0.66, 0.64, 0.58)
const STONE_OLD := Color(0.46, 0.45, 0.43)
const FLOOR_OLD := Color(0.47, 0.45, 0.42)
## Seed of the ruin's damage: the same broken boards on every load.
const RUIN_SEED := 1907
## Grandpa's oil lantern, hanging from the east tie beam.
const LANTERN := Vector3(3.0, FLOOR_Y + 2.15, 0.3)
## Roof grid of the ruin: cells along x (gable to gable) and down each slope.
const ROOF_NX := 11
const ROOF_NS := 5
## Roof cells (side, i from the west gable, j down from the ridge) that are open to
## the sky: front over the west half of the room, back over the north-west corner.
const ROOF_HOLES := {Vector3i(1, 2, 2): true, Vector3i(1, 3, 2): true, Vector3i(1, 3, 1): true,
	Vector3i(-1, 1, 1): true, Vector3i(-1, 1, 2): true}
## Cells whose tiles have slid off the boards.
const ROOF_BARE := {Vector3i(1, 6, 1): true, Vector3i(1, 7, 3): true, Vector3i(1, 1, 3): true,
	Vector3i(1, 9, 0): true, Vector3i(1, 4, 2): true, Vector3i(-1, 4, 1): true, Vector3i(-1, 6, 2): true,
	Vector3i(-1, 8, 0): true, Vector3i(-1, 2, 3): true}
## Floor boards gone: (row, from x, to x), under the roof holes where the rain rotted them.
const FLOOR_GAPS: Array[Vector3] = [Vector3(5, -3.9, -2.7), Vector3(6, -3.7, -3.0), Vector3(22, -3.0, -2.2)]

## FarmState.flags the house keeps: the front door stands open (bool), the desk drawer
## is out (bool), which of Grandpa's things were taken off the worktable (an Array of
## item id Strings), the pickup key was taken out of the drawer (bool).
const DOOR_FLAG := "house_door_open"
const DRAWER_FLAG := "drawer_open"
const TABLE_FLAG := "table_taken"
const KEY_FLAG := "key_taken"
## Set true by the story to keep the desk drawer shut (no prompt) until its step.
const DRAWER_LOCK_FLAG := "drawer_locked"
## A game from before the first day's story (set by the save migration): the door
## stands open and the worktable and the drawer are empty, as they always were.
const LEGACY_FLAG := "legacy"
## Asks an automated run (a test) for a new farm's house all the same.
const FIRST_DAY_FLAG := "first_day"
## Sent with Events.door_toggled / drawer_opened.
const DOOR_ID := &"house_door"
const DRAWER_ID := &"desk"
## Groups of the pieces the story points at.
const DOOR_GROUP := &"house_door"
const TABLE_GROUP := &"house_table"
const DRAWER_GROUP := &"house_drawer"
## Grandpa's worktable: length, height of its top face, depth.
const WORKTABLE := Vector3(2.4, 0.81, 0.9)
## Grandpa's writing desk: width, height of its top face, depth (see _desk_xf).
const DESK := Vector3(1.0, 0.76, 0.55)
## Where its drawer's front sits, shut, in desk space (the back face of the front).
const DESK_DRAWER := Vector3(0.0, 0.655, 0.233)
## How Grandpa's things lie on the worktable, by item id (ItemTable.STARTING_ITEMS says
## what and how many): [spot on the top from its centre (x along it, y toward the
## wall), pose (see _table_lay), anchor (see WorldItem), yaw in degrees]. Long tools lie
## across it, the spot on their handle line, head at the back and the grip out over the
## edge; the seed packets and the can lie at the west end, nearest the door.
const TABLE_LAYOUT := {
	&"wheat_seed": [Vector2(-1.08, -0.24), "packet", Vector3(0.5, 0, 0.5), 12.0],
	&"potato_seed": [Vector2(-0.94, -0.3), "packet", Vector3(0.5, 0, 0.5), -9.0],
	&"watering_can": [Vector2(-0.7, 0.0), "upright", Vector3(0.5, 0, 0.5), 150.0],
	&"hoe": [Vector2(-0.39, 0.41), "on_side", Vector3(NAN, 0, 1), 0.0],
	&"pickaxe": [Vector2(0.15, 0.41), "across", Vector3(NAN, 0, 1), 0.0],
	&"axe": [Vector2(0.5, 0.41), "across", Vector3(NAN, 0, 1), 0.0],
	&"scythe": [Vector2(0.84, 0.41), "across", Vector3(NAN, 0, 1), 0.0],
}

@export_range(0, 3) var level := 1:
	set(value):
		level = clampi(value, 0, 3)
		if _ready_done:
			build()

var W := 9.0
var D := 7.0
var RISE := 2.2
var door_x := 0.0
var fireplace_x := -0.3
## Local x of the bedroom partition wall (level 3), or INF.
var partition_x := INF

var _colliders: Array[Dictionary] = []
var _ready_done := false
var _lamp: OmniLight3D
var _fire: OmniLight3D
var _flicker := 0.0
## The ruin's holes in the walls, the RepairSpots' places: [{xf, size}] (see _ruin_wall).
var _spots: Array[Dictionary] = []
## The ruin's roof: slope angle, ridge height and slope length (set by _ruin_roof).
var _theta := 0.0
var _ridge_y := 0.0
var _slab_len := 1.0
## Small trim of the repaired house (sash bars, curtains, rafter tails, balusters,
## downpipe brackets): its own mesh, drawn without shadows and only near by.
var _detail: MeshBuilder


func _ready() -> void:
	add_to_group(&"farm_house")
	if not Engine.is_editor_hint():
		level = FarmState.house_level()
	_ready_done = true
	build()


func build() -> void:
	for c in get_children():
		# Out of the tree at once, so the new pieces keep their names (Bed, Chest...).
		remove_child(c)
		c.queue_free()
	_colliders.clear()
	_spots.clear()
	var rect := WorldLayout.house_rect(level)
	W = rect.size.x
	D = rect.size.y
	RISE = D * 0.31
	var center := rect.get_center()
	position = Vector3(center.x, 0, center.y)
	door_x = WorldLayout.HOUSE_DOOR_X - center.x
	fireplace_x = door_x - 0.3
	partition_x = -W * 0.5 + 5.2 if level >= 3 else INF

	var mb := MeshBuilder.new()
	# Small clutter of the ruin (cobwebs, dust, the lantern): casts no shadow and stays
	# off visual layer 1, so the lamp and the rain map ignore it.
	var clutter := MeshBuilder.new()
	_detail = MeshBuilder.new()
	_build_base(mb)
	if level == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = RUIN_SEED
		_ruin_walls(mb, rng)
		_ruin_roof(mb, rng)
		_ruin_porch(mb, rng)
		_ruin_interior(mb, clutter, rng)
		_ruin_yard(mb, rng)
	else:
		_build_walls(mb)
		_build_roof(mb)
		_build_porch(mb)
		_build_interior(mb)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.build()
	mi.layers = 1 | LAMP_SHADOW_LAYER
	add_child(mi)
	if not clutter.is_empty():
		var cm := MeshInstance3D.new()
		cm.name = "Clutter"
		cm.mesh = clutter.build()
		cm.layers = 2
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(cm)
	if not _detail.is_empty():
		add_child(BuildingKit.detail_instance(_detail.build()))
	_detail = null
	_build_collision()
	_place_furniture_nodes()
	# The holes in the old walls are mended by hand, with wood (RepairSpot).
	if level == 0 and not Engine.is_editor_hint():
		RepairSpot.add_all(self, &"house", _spots, mi)

	# The old house's hearth is cold.
	_fire = null
	if level > 0:
		_fire = OmniLight3D.new()
		_fire.name = "FireLight"
		_fire.position = Vector3(fireplace_x, FLOOR_Y + 0.45, -D * 0.5 + 0.9)
		_fire.light_color = Color(1.0, 0.55, 0.22)
		_fire.omni_range = 5.5
		_fire.omni_attenuation = 1.4
		add_child(_fire)
	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	if level == 0:
		# In the lantern itself: it is drawn in the clutter mesh, so it casts no shadow.
		_lamp.position = LANTERN
		_lamp.light_color = Color(1.0, 0.72, 0.42)
		_lamp.omni_range = 7.0
	else:
		_lamp.position = Vector3(door_x - 2.4, FLOOR_Y + 1.35, D * 0.5 - 3.9)
		_lamp.light_color = Color(1.0, 0.78, 0.5)
		_lamp.omni_range = 9.0 + level
	_lamp.shadow_enabled = true
	_lamp.shadow_caster_mask = LAMP_SHADOW_LAYER
	add_child(_lamp)
	if level >= 3:
		var bedroom_lamp := OmniLight3D.new()
		bedroom_lamp.position = Vector3(-W * 0.5 + 2.6, FLOOR_Y + 2.2, 0)
		bedroom_lamp.light_color = Color(1.0, 0.8, 0.55)
		bedroom_lamp.omni_range = 6.0
		bedroom_lamp.light_energy = 0.8
		add_child(bedroom_lamp)
	if level == 0 and not Engine.is_editor_hint():
		_spawn_weeds()

	if not Engine.is_editor_hint() and Game.world and Game.world.has_method("block_grass"):
		Game.world.block_grass(Rect2(rect.position - Vector2(0.4, 0.4), rect.size + Vector2(0.8, 3.2)))
	# An upgrade moves the house to its new centre in one jump.
	reset_physics_interpolation()


## Footprint in world XZ (used for grass and placement).
func footprint() -> Rect2:
	return WorldLayout.house_rect(level)


func _process(delta: float) -> void:
	if _lamp:
		var e := Vector2(0.25, 1.1) if level == 0 else Vector2(0.35, 1.6)
		_lamp.light_energy = lerpf(e.x, e.y, DayNightCycle.night_factor)
	if _fire:
		_flicker += delta
		var f := sin(_flicker * 9.0) * 0.08 + sin(_flicker * 23.0) * 0.05 + sin(_flicker * 3.1) * 0.1
		_fire.light_energy = lerpf(0.7, 1.5, DayNightCycle.night_factor) * (1.0 + f)


func _place_furniture_nodes() -> void:
	var bed := Bed.new()
	bed.name = "Bed"
	bed.worn = level == 0
	if level >= 3:
		bed.position = Vector3(-W * 0.5 + T + 1.6, FLOOR_Y, -D * 0.5 + T + 1.12)
	else:
		bed.position = Vector3(W * 0.5 - T - 0.75, FLOOR_Y, -D * 0.5 + T + 1.12)
	add_child(bed)
	_cast_lamp_shadow(bed)
	# Same place and storage at levels 0 and 1: the repair keeps what is in it. A new
	# farm's chest is empty (the coop's wood comes from the axe); automated runs keep
	# the old stock, which the tests build with.
	var chest := Chest.new()
	chest.name = "Chest"
	chest.storage_id = "house_main"
	if not Engine.is_editor_hint() and DebugTools.is_automated():
		chest.starting_items = [[&"wood", 10], [&"stone", 5]]
	chest.worn = level == 0
	chest.position = Vector3(W * 0.5 - T - 0.75, FLOOR_Y, D * 0.5 - 4.3)
	add_child(chest)
	_cast_lamp_shadow(chest)
	if level >= 2:
		var pantry := Chest.new()
		pantry.name = "Pantry"
		pantry.storage_id = "house_pantry"
		pantry.slots = 24
		pantry.title_key = "UI_PANTRY"
		pantry.position = Vector3(_kitchen_x() + 0.2, FLOOR_Y, D * 0.5 - T - 0.55)
		pantry.rotation.y = PI
		add_child(pantry)
		_cast_lamp_shadow(pantry)
	if level >= 3:
		var wardrobe := Chest.new()
		wardrobe.name = "Wardrobe"
		wardrobe.storage_id = "house_wardrobe"
		wardrobe.slots = 24
		wardrobe.position = Vector3(-W * 0.5 + T + 0.6, FLOOR_Y, D * 0.5 - 1.6)
		wardrobe.rotation.y = -PI * 0.5
		add_child(wardrobe)
		_cast_lamp_shadow(wardrobe)
	var dressed := first_day()
	_place_front_door(dressed)
	_place_worktable(dressed)
	_place_desk_drawer(dressed)


## Adds the meshes under `node` to the layer the lamp's shadow is drawn from.
func _cast_lamp_shadow(node: Node) -> void:
	for g: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
		g.layers |= LAMP_SHADOW_LAYER


## Local x where the kitchen corner starts (west part of the main room).
func _kitchen_x() -> float:
	return (partition_x if level >= 3 else -W * 0.5) + 0.9


# --- The first day: door, worktable, desk drawer ------------------------------------
# All three stand at every level in the same world spot (the front and east walls
# never move), so a repair or an upgrade rebuilds them where they were, as they were.

## True when the house greets a new farm's first day: the front door starts shut,
## Grandpa's things lie on the worktable and the pickup key in the desk drawer (each
## until it is taken). False for old saves (LEGACY_FLAG) and automated runs, unless
## FIRST_DAY_FLAG or the `--first_day` argument (screenshot runs) asks for it; the
## editor shows it.
static func first_day() -> bool:
	if Engine.is_editor_hint():
		return true
	if FarmState.flags.get(LEGACY_FLAG, false):
		return false
	if DebugTools.is_automated():
		return bool(FarmState.flags.get(FIRST_DAY_FLAG, false)) or DebugTools.args.has("first_day")
	return true


## How many of Grandpa's things were taken off the worktable (of table_item_count()).
static func table_taken_count() -> int:
	var v: Variant = FarmState.flags.get(TABLE_FLAG)
	return (v as Array).size() if v is Array else 0


static func table_item_count() -> int:
	return ItemTable.STARTING_ITEMS.size()


func front_door() -> Door:
	return get_node_or_null("FrontDoor") as Door


func desk_drawer() -> Drawer:
	return get_node_or_null("DeskDrawer") as Drawer


## Middle of the front doorway at chest height (a waypoint target).
func door_point() -> Vector3:
	return to_global(Vector3(door_x, FLOOR_Y + 1.2, D * 0.5 - T * 0.5))


## Above the middle of the worktable (a waypoint target).
func table_point() -> Vector3:
	return to_global(_worktable_pos() + Vector3(0, WORKTABLE.y + 0.15, 0))


## The desk drawer's knob, wherever the drawer is (a waypoint target).
func drawer_point() -> Vector3:
	var drawer := desk_drawer()
	return drawer.waypoint_point() if drawer else to_global(_desk_xf() * DESK_DRAWER)


## Floor centre of the worktable: just inside the front wall, east of the lane from
## the door (its west end 0.8 m from the doorway's middle).
func _worktable_pos() -> Vector3:
	return Vector3(door_x + 2.0, FLOOR_Y, D * 0.5 - T - 0.5)


## The writing desk's frame: its floor centre against the east wall under the window,
## its front (the drawer, +Z) turned west to the room.
func _desk_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(W * 0.5 - T - 0.3, FLOOR_Y, D * 0.5 - 2.7))


## The front door on its hinge: the west jamb, on the wall's inner face. It opens
## inward and stays in the same world spot at every level; Grandpa's old door on the
## ruin, a new one once repaired. Open or shut is kept in DOOR_FLAG.
func _place_front_door(dressed: bool) -> void:
	var door := Door.new()
	door.name = "FrontDoor"
	door.style = &"ruin" if level == 0 else &"plank"
	door.door_id = DOOR_ID
	door.flag = DOOR_FLAG
	door.start_open = not dressed
	door.position = Vector3(door_x - 0.63, FLOOR_Y + 0.015, D * 0.5 - T)
	door.add_to_group(DOOR_GROUP)
	add_child(door)
	_cast_lamp_shadow(door)


## The worktable's mark (TABLE_GROUP) and, on the first day, Grandpa's things on it:
## ItemTable.STARTING_ITEMS laid out by TABLE_LAYOUT (an id without a spot lies at the
## east end). Each is taken with E and remembered in TABLE_FLAG.
func _place_worktable(dressed: bool) -> void:
	var p := _worktable_pos()
	var mark := Marker3D.new()
	mark.name = "Worktable"
	mark.position = p + Vector3(0, WORKTABLE.y + 0.15, 0)
	mark.add_to_group(TABLE_GROUP)
	add_child(mark)
	if not dressed:
		return
	var spare := 0
	for entry: Array in ItemTable.STARTING_ITEMS:
		var id: StringName = entry[0]
		if not Engine.is_editor_hint() and WorldItem.is_taken(TABLE_FLAG, String(id)):
			continue
		var spot: Array = TABLE_LAYOUT.get(id, [])
		if spot.is_empty():
			spot = [Vector2(1.05 - spare * 0.14, -0.28), "upright", Vector3(0.5, 0, 0.5), 0.0]
			spare += 1
		var item := WorldItem.new()
		item.name = "Table_%s" % id
		item.item_id = id
		item.count = int(entry[1])
		item.flag = TABLE_FLAG
		item.flag_entry = String(id)
		item.lay = _table_lay(String(spot[1]))
		item.anchor = spot[2]
		item.settle = spot[1] == "across" or spot[1] == "on_side"
		var at: Vector2 = spot[0]
		item.position = p + Vector3(at.x, WORKTABLE.y, at.y)
		item.rotation.y = deg_to_rad(float(spot[3]))
		add_child(item)
		_cast_lamp_shadow(item)


## A table pose from TABLE_LAYOUT as a lay basis for the model (ItemModels frame).
func _table_lay(pose: String) -> Basis:
	match pose:
		"packet":
			# Face up, its top toward the wall: it reads from the room.
			return Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI * 0.5)
		"across":
			# Along +Z, the head at the back (by the wall), the grip out over the room.
			return Basis(Vector3.RIGHT, PI * 0.5)
		"on_side":
			# As "across", rolled onto its side (a hoe on the edge of its blade).
			return Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
	return Basis()


## The desk drawer (DRAWER_GROUP) and, on the first day, the pickup key lying in it
## (KEY_FLAG once taken). DRAWER_LOCK_FLAG keeps it shut until the story wants it.
func _place_desk_drawer(dressed: bool) -> void:
	var drawer := Drawer.new()
	drawer.name = "DeskDrawer"
	drawer.size = Vector3(0.5, 0.09, 0.4)
	drawer.travel = 0.28
	drawer.reach_up = DESK.y - 0.035 - DESK_DRAWER.y
	drawer.reach_out = 0.03
	drawer.worn = level == 0
	drawer.drawer_id = DRAWER_ID
	drawer.flag = DRAWER_FLAG
	drawer.lock_flag = DRAWER_LOCK_FLAG
	drawer.transform = _desk_xf() * Transform3D(Basis(), DESK_DRAWER)
	drawer.add_to_group(DRAWER_GROUP)
	if dressed and (Engine.is_editor_hint() or not WorldItem.is_taken(KEY_FLAG)):
		var key := WorldItem.new()
		key.name = "TruckKey"
		key.item_id = &"truck_key"
		key.flag = KEY_FLAG
		drawer.put(key, Vector2(0.07, 0.14), 28.0)
	add_child(drawer)
	_cast_lamp_shadow(drawer)


## Grandpa's worktable (2.4 x 0.9 m): a top of three heavy planks on square legs with
## aprons, and a shelf of boards low down with an old sack and a tin on it. `worn`
## is the ruin's: grey, dry wood, one top plank cupped.
func _worktable(mb: MeshBuilder, worn: bool) -> void:
	var p := _worktable_pos()
	var key: StringName = &"wood_old_in" if worn else &"wood_in"
	var top_c := _shade(LOG_OLD, 0.9) if worn else WOOD_FURN
	var frame_c := _shade(LOG_DARK, 1.08) if worn else LOG_DARK
	var hx := WORKTABLE.x * 0.5
	var hz := WORKTABLE.z * 0.5
	var top := WORKTABLE.y
	var bw := WORKTABLE.z / 3.0
	for k in 3:
		var z := -hz + (k + 0.5) * bw
		var cup := Basis(Vector3.RIGHT, deg_to_rad(0.8)) if worn and k == 2 else Basis()
		BuildingKit.plank(mb, key, Transform3D(cup, p + Vector3(0, top - 0.03, z)), Vector3(WORKTABLE.x, 0.06, bw - 0.006),
				_shade(top_c, 0.93 + 0.05 * k), Vector2(0.9 * k, 0.37 * k))
	var leg_h := top - 0.06
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(key, p + Vector3(sx * (hx - 0.09), leg_h * 0.5, sz * (hz - 0.08)), Vector3(0.08, leg_h, 0.08), frame_c)
		# Side aprons and the stretchers under the shelf.
		mb.box_at(key, p + Vector3(sx * (hx - 0.09), top - 0.12, 0), Vector3(0.025, 0.12, WORKTABLE.z - 0.24), frame_c)
		mb.box_at(key, p + Vector3(sx * (hx - 0.09), 0.13, 0), Vector3(0.05, 0.05, WORKTABLE.z - 0.2), frame_c)
	for sz: float in [-1.0, 1.0]:
		mb.box_at(key, p + Vector3(0, top - 0.12, sz * (hz - 0.08)), Vector3(WORKTABLE.x - 0.26, 0.12, 0.025), _shade(frame_c, 1.05))
	# The shelf: three loose boards across the stretchers.
	for k in 3:
		var z := -0.24 + k * 0.24
		BuildingKit.plank(mb, key, Transform3D(Basis(), p + Vector3(0, 0.165, z)), Vector3(WORKTABLE.x - 0.14, 0.02, 0.21),
				_shade(top_c, 0.82 + 0.04 * k), Vector2(0.4 * k, 1.1))
	# An old sack slumped on the shelf, and a tin can beside it.
	mb.blob(&"cloth", Transform3D(Basis(Vector3.UP, 0.3) * Basis.from_scale(Vector3(1.7, 0.55, 1.05)), p + Vector3(-0.55, 0.21, 0.05)),
			0.15, 1, Color(0.5, 0.43, 0.32) if not worn else Color(0.44, 0.4, 0.34), 0.25, 2.2, 17, 0.1, true, -0.4)
	mb.cylinder(&"rusty" if worn else &"metal", Transform3D(Basis(), p + Vector3(0.62, 0.175, -0.05)), 0.055, 0.055, 0.12, 12,
			Color(0.4, 0.3, 0.22) if worn else Color(0.46, 0.46, 0.44))
	_add_collider(p + Vector3(0, top - 0.03, 0), Vector3(WORKTABLE.x, 0.06, WORKTABLE.z))
	_add_collider(p + Vector3(0, leg_h * 0.5, 0), Vector3(WORKTABLE.x - 0.1, leg_h, WORKTABLE.z - 0.1))


## Grandpa's writing desk under the east window: a plank top on square legs, a deep
## apron with the drawer's opening in front (the drawer is its own node, see
## _place_desk_drawer), a ledger, an inkwell with a pen and a tin mug on top. Its
## colliders stay behind the drawer's face, so the ray finds the drawer.
func _desk(mb: MeshBuilder, worn: bool) -> void:
	var xf := _desk_xf()
	var tmp := MeshBuilder.new()
	var key: StringName = &"wood_old_in" if worn else &"wood_in"
	var c := _shade(LOG_OLD, 0.86) if worn else Color(0.44, 0.37, 0.31)
	var dark := _shade(c, 0.8)
	var hx := DESK.x * 0.5
	var hz := DESK.z * 0.5
	var top := DESK.y
	var under := top - 0.035
	tmp.box_at(key, Vector3(0, top - 0.0175, 0), Vector3(DESK.x, 0.035, DESK.z), c)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			tmp.box_at(key, Vector3(sx * (hx - 0.05), under * 0.5, sz * (hz - 0.05)), Vector3(0.05, under, 0.05), dark)
		# Side aprons and low stretchers.
		tmp.box_at(key, Vector3(sx * (hx - 0.05), under - 0.0675, 0), Vector3(0.02, 0.135, DESK.z - 0.12), dark)
		tmp.box_at(key, Vector3(sx * (hx - 0.05), 0.15, 0), Vector3(0.03, 0.045, DESK.z - 0.12), dark)
	tmp.box_at(key, Vector3(0, under - 0.0675, -(hz - 0.05)), Vector3(DESK.x - 0.12, 0.135, 0.02), dark)
	tmp.box_at(key, Vector3(0, 0.15, -(hz - 0.05)), Vector3(DESK.x - 0.12, 0.045, 0.03), dark)
	# The front apron around the drawer's opening (0.5 x 0.09), set back behind the
	# drawer front, which laps over it; runners under the drawer's sides.
	var ow := 0.25
	var oy0 := DESK_DRAWER.y - 0.045
	var oy1 := DESK_DRAWER.y + 0.045
	var az := DESK_DRAWER.z - 0.01
	var inner := hx - 0.075
	tmp.box_at(key, Vector3(0, (under + oy1) * 0.5, az), Vector3(inner * 2.0, under - oy1, 0.02), c)
	tmp.box_at(key, Vector3(0, (oy0 + under - 0.135) * 0.5, az), Vector3(inner * 2.0, oy0 - (under - 0.135), 0.02), c)
	for sx: float in [-1.0, 1.0]:
		tmp.box_at(key, Vector3(sx * (ow + inner) * 0.5, DESK_DRAWER.y, az), Vector3(inner - ow, oy1 - oy0, 0.02), c)
		tmp.box_at(key, Vector3(sx * (ow + 0.01), oy0 - 0.008, -0.02), Vector3(0.03, 0.016, DESK.z - 0.12), dark)
	# On top: a ledger, an inkwell with a dip pen, a tin mug.
	var book := Transform3D(Basis(Vector3.UP, deg_to_rad(8.0)), Vector3(-0.2, top, -0.03))
	tmp.box(&"cloth", book * Transform3D(Basis(), Vector3(0, 0.019, 0)), Vector3(0.23, 0.038, 0.31), Color(0.3, 0.16, 0.12))
	tmp.box(&"paper", book * Transform3D(Basis(), Vector3(0.006, 0.019, 0)), Vector3(0.225, 0.03, 0.296), Color(0.86, 0.82, 0.7))
	var ink := Vector3(0.24, top, -0.14)
	tmp.cylinder(&"paint_in", Transform3D(Basis(), ink), 0.03, 0.026, 0.045, 10, Color(0.1, 0.11, 0.14))
	tmp.cylinder(&"paint_in", Transform3D(Basis(), ink + Vector3(0, 0.045, 0)), 0.014, 0.014, 0.012, 8, Color(0.08, 0.08, 0.09))
	tmp.cylinder_between(&"paint_in", Vector3(0.14, top + 0.005, -0.02), Vector3(0.3, top + 0.005, 0.03), 0.004, 0.003, 6,
			Color(0.22, 0.15, 0.1))
	var mug := Vector3(0.3, top, 0.12)
	var mug_key: StringName = &"rusty" if worn else &"metal"
	var mug_c := Color(0.42, 0.33, 0.25) if worn else Color(0.55, 0.56, 0.55)
	tmp.ring(mug_key, Transform3D(Basis(), mug), 0.042, 0.038, 0.095, 14, mug_c)
	tmp.disc(mug_key, Transform3D(Basis(), mug + Vector3(0, 0.004, 0)), 0.04, 14, _shade(mug_c, 0.7))
	tmp.loft(mug_key, [mug + Vector3(0.04, 0.075, 0), mug + Vector3(0.068, 0.07, 0), mug + Vector3(0.07, 0.03, 0),
			mug + Vector3(0.04, 0.022, 0)], [0.005, 0.005, 0.005, 0.005], 5, mug_c)
	mb.append(tmp, xf)
	_colliders.append({"xf": xf * Transform3D(Basis(), Vector3(0, top - 0.0175, 0)), "size": Vector3(DESK.x, 0.035, DESK.z)})
	# The body stops just behind the drawer's front.
	var front := DESK_DRAWER.z - 0.001
	_colliders.append({"xf": xf * Transform3D(Basis(), Vector3(0, under * 0.5, (front - hz) * 0.5)),
			"size": Vector3(DESK.x, under, front + hz)})


# --- Structure -----------------------------------------------------------------

## Stone base (the floor's collision) and, once repaired, the plank floor. The ruin
## lays its own loose boards (_ruin_floor).
func _build_base(mb: MeshBuilder) -> void:
	var old := level == 0
	if old:
		mb.box_at(&"stone_old", Vector3(0, 0.2, 0), Vector3(W + 0.4, 0.6, D + 0.4), STONE_OLD)
	else:
		mb.box_at(&"stone_ext", Vector3(0, 0.2, 0), Vector3(W + 0.4, 0.6, D + 0.4), STONE)
		mb.box_at(&"floor", Vector3(0, FLOOR_Y - 0.03, 0), Vector3(W - 0.12, 0.06, D - 0.12), FLOOR)
	# Mortared cap along the plinth's edge (lying on it) and the sill beam the walls stand
	# on (its grain along it; let 1 cm into the plinth, so its underside is not the cap's).
	var cap_key: StringName = &"stone_old" if old else &"stone_ext"
	var sill_key: StringName = &"wood_old" if old else &"wood_ext"
	var sill_c := _shade(LOG_DARK, 0.95 if old else 0.85)
	for sz: float in [-1.0, 1.0]:
		mb.box_at(cap_key, Vector3(0, 0.52, sz * (D * 0.5 + 0.1)), Vector3(W + 0.44, 0.04, 0.24), _shade(STONE_OLD if old else STONE, 0.9))
		mb.box_at(sill_key, Vector3(0, 0.555, sz * (D * 0.5 - 0.06)), Vector3(W + 0.04, 0.13, 0.16), sill_c, Vector3.ZERO, true)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(cap_key, Vector3(sx * (W * 0.5 + 0.1), 0.52, 0), Vector3(0.24, 0.04, D - 0.04), _shade(STONE_OLD if old else STONE, 0.9))
		BuildingKit.beam(mb, sill_key, Vector3(sx * (W * 0.5 - 0.06), 0.555, -D * 0.5 + 0.05), Vector3(sx * (W * 0.5 - 0.06), 0.555, D * 0.5 - 0.05),
				Vector2(0.13, 0.16), sill_c, true)
	_add_collider(Vector3(0, (FLOOR_Y - 0.2) * 0.5, 0), Vector3(W + 0.4, FLOOR_Y + 0.2, D + 0.4))


func _windows_along(length: float, avoid: Array, spacing := 3.2) -> Array:
	var window := {"w": 1.2, "bottom": 1.0, "top": 2.1}
	var result := []
	var count := maxi(1, int(length / spacing))
	for i in count:
		var at := -length * 0.5 + length * (i + 0.5) / count
		var blocked := false
		for a: float in avoid:
			if absf(at - a) < 1.3:
				blocked = true
		if not blocked:
			result.append(_op(at, window))
	return result


func _build_walls(mb: MeshBuilder) -> void:
	var hw := W * 0.5 - T * 0.5
	var hd := D * 0.5 - T * 0.5
	var window := {"w": 1.2, "bottom": 1.0, "top": 2.1}
	var rng := RandomNumberGenerator.new()
	rng.seed = RUIN_SEED + 11 * level
	# Back (north) wall, windows avoiding the chimney.
	# (Nor one where the bedroom's partition meets the wall: it would stand in the window.)
	_wall_x(mb, -hd, _windows_along(W - 1.0, [fireplace_x, partition_x] if level >= 3 else [fireplace_x]), -1, rng)
	# Front (south) wall: the doorway plus windows on either side.
	var front: Array = [{"at": door_x, "w": 1.3, "bottom": 0.0, "top": 2.3}]
	for wx: float in [door_x - 2.9, door_x + 2.9, door_x - 6.2]:
		if absf(wx) < W * 0.5 - 1.0 and (level < 3 or absf(wx - partition_x) > 1.2):
			front.append(_op(wx, window))
	if level >= 3:
		front.append(_op((partition_x - W * 0.5) * 0.5, window))
	_wall_x(mb, hd, front, 1, rng)
	# Side walls.
	var side := [_op(0.0, window)] if D < 8.5 else [_op(-D * 0.22, window), _op(D * 0.22, window)]
	_wall_z(mb, -hw, side, -1, rng)
	_wall_z(mb, hw, [_op(0.6, window)] if D < 8.5 else [_op(-D * 0.2, window)], 1, rng)
	# Bedroom partition with a doorway (level 3).
	if level >= 3:
		var from := -D * 0.5 + 0.15
		var to := D * 0.5 - 0.15
		var door := {"at": D * 0.5 - 1.6, "w": 1.1, "bottom": 0.0, "top": 2.2}
		for seg in _wall_segments(from, to, [door]):
			var c := Vector3(partition_x, FLOOR_Y + (seg.z + seg.w) * 0.5, (seg.x + seg.y) * 0.5)
			var s := Vector3(0.14, seg.w - seg.z, seg.y - seg.x)
			mb.box_at(&"wood_in", c, s, LOG)
			_add_collider(c, s)
		_opening_trim(mb, Vector3(partition_x, 0, door["at"]), door, false, 1, 0.14)
	_corner_boards(mb, &"paint_ext", TRIM)
	# The door leaf is a node of its own (see _place_front_door): it swings.


func _op(at: float, template: Dictionary) -> Dictionary:
	var o := template.duplicate()
	o["at"] = at
	return o


## Wall along X at z = `z`, spanning the full width. `outward` = sign of the outer face.
## Lap siding on a closed wall, lined inside with boards (the colliders are the wall's
## plain stretches).
func _wall_x(mb: MeshBuilder, z: float, openings: Array, outward: int, rng: RandomNumberGenerator) -> void:
	var from := -W * 0.5 + 0.15
	var to := W * 0.5 - 0.15
	for seg in _wall_segments(from, to, openings):
		_add_collider(Vector3((seg.x + seg.y) * 0.5, FLOOR_Y + (seg.z + seg.w) * 0.5, z), Vector3(seg.y - seg.x, seg.w - seg.z, T))
	_siding(mb, true, z, openings, outward, rng)
	for o in openings:
		_opening_trim(mb, Vector3(o["at"], 0, z), o, true, outward)


## Wall along Z at x = `x`.
func _wall_z(mb: MeshBuilder, x: float, openings: Array, outward: int, rng: RandomNumberGenerator) -> void:
	var from := -D * 0.5 + 0.15
	var to := D * 0.5 - 0.15
	for seg in _wall_segments(from, to, openings):
		_add_collider(Vector3(x, FLOOR_Y + (seg.z + seg.w) * 0.5, (seg.x + seg.y) * 0.5), Vector3(T, seg.w - seg.z, seg.y - seg.x))
	_siding(mb, false, x, openings, outward, rng)
	for o in openings:
		_opening_trim(mb, Vector3(x, 0, o["at"]), o, false, outward)


## A house wall's ends and openings as BuildingKit.board_wall() takes them: along X at
## z = `fixed` or along Z at x = `fixed`, outer face toward `outward`. Returns [a, b,
## openings with "at" measured from a].
func _board_wall_frame(along_x: bool, fixed: float, openings: Array, outward: int) -> Array:
	var span := (W if along_x else D) * 0.5 - 0.15
	# BuildingKit walls face basis.z of the direction a -> b: +X walls run east to face
	# south, Z walls run north to face east.
	var forward := outward > 0 if along_x else outward < 0
	var from := -span if forward else span
	var a := Vector2(from, fixed) if along_x else Vector2(fixed, from)
	var b := Vector2(-from, fixed) if along_x else Vector2(fixed, -from)
	var ops := []
	for o: Dictionary in openings:
		var k := o.duplicate()
		k["at"] = absf(float(o["at"]) - from)
		ops.append(k)
	return [a, b, ops]


## The repaired house's lap siding over a closed wall lined with boards inside.
func _siding(mb: MeshBuilder, along_x: bool, fixed: float, openings: Array, outward: int, rng: RandomNumberGenerator) -> void:
	var f := _board_wall_frame(along_x, fixed, openings, outward)
	BuildingKit.board_wall(mb, [], f[0], f[1], FLOOR_Y, WALL_H, T, &"planks_ext", SIDING, f[2], rng, 0.0, &"wood_in", 0.6, true)


## Corner boards over the siding's ends (and a post filling the corner behind them),
## their grain running up them (`key` is a rough_wood key).
func _corner_boards(mb: MeshBuilder, key: StringName, color: Color, rng: RandomNumberGenerator = null) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := _shade(color, rng.randf_range(0.88, 1.05)) if rng else color
			var y := FLOOR_Y + WALL_H * 0.5 - 0.03
			var h := WALL_H + 0.06
			# (The post ends 2 cm under the walls' tops, so its top is not in their plane.)
			mb.box_at(&"wood_in", Vector3(sx * (W * 0.5 - 0.08), y - 0.01, sz * (D * 0.5 - 0.08)), Vector3(0.16, h - 0.02, 0.16), LOG_DARK)
			BuildingKit.plank(mb, key, Transform3D(Basis(), Vector3(sx * (W * 0.5 - 0.0525), y, sz * (D * 0.5 + 0.028))),
					Vector3(0.195, h, 0.034), c, Vector2(0.3 + sx * 0.2 + sz * 0.45, 0.0))
			BuildingKit.plank(mb, key, Transform3D(Basis(), Vector3(sx * (W * 0.5 + 0.028), y, sz * (D * 0.5 - 0.0695))),
					Vector3(0.034, h, 0.161), c, Vector2(0.9 + sx * 0.2 + sz * 0.45, 0.4))


## Splits a wall span into solid boxes around openings.
## Returns Vector4(start, end, bottom, top) along the wall.
func _wall_segments(from: float, to: float, openings: Array) -> Array[Vector4]:
	var result: Array[Vector4] = []
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a, b): return a["at"] < b["at"])
	var cursor := from
	for o in sorted:
		var left := float(o["at"]) - float(o["w"]) * 0.5
		var right := float(o["at"]) + float(o["w"]) * 0.5
		if left - cursor > 0.01:
			result.append(Vector4(cursor, left, 0.0, WALL_H))
		if float(o["bottom"]) > 0.01:
			result.append(Vector4(left, right, 0.0, o["bottom"]))
		if WALL_H - float(o["top"]) > 0.01:
			result.append(Vector4(left, right, o["top"], WALL_H))
		cursor = right
	if to - cursor > 0.01:
		result.append(Vector4(cursor, to, 0.0, WALL_H))
	return result


## Trim of a window or doorway in a repaired wall `thick` deep: casings on both faces,
## linings through the wall and, for a window, a sill with its apron, a drip cap over
## the head, a stool inside, a double-hung sash (the upper one a little further out)
## with its panes, and curtains drawn back inside. A doorway gets a threshold.
func _opening_trim(mb: MeshBuilder, center: Vector3, o: Dictionary, along_x: bool, outward: int, thick := T) -> void:
	var w: float = o["w"]
	var bottom: float = o["bottom"]
	var top: float = o["top"]
	var is_window := bottom > 0.01
	var y0 := FLOOR_Y + bottom
	var y1 := FLOOR_Y + top
	var h := top - bottom
	var cw := 0.1
	var ct := 0.028
	var paint := _shade(TRIM, 0.97)
	var o_sign := float(outward)
	var pieces: Array[Array] = []
	# Casings, outside and in, standing proud of the siding / lining.
	var foot := y0 if is_window else FLOOR_Y
	for face: float in [1.0, -1.0]:
		var z := o_sign * face * (thick * 0.5 + 0.012 + ct * 0.5)
		for sx: float in [-1.0, 1.0]:
			pieces.append([Vector3(sx * (w * 0.5 + cw * 0.5), (foot + y1 + cw) * 0.5, z), Vector3(cw, y1 + cw - foot, ct)])
		pieces.append([Vector3(0, y1 + cw * 0.5, z), Vector3(w + cw * 2.0, cw, ct)])
	# Linings through the wall.
	for sx: float in [-1.0, 1.0]:
		pieces.append([Vector3(sx * (w * 0.5 - 0.012), (y0 + y1) * 0.5, 0), Vector3(0.024, h, thick + 0.02)])
	pieces.append([Vector3(0, y1 - 0.012, 0), Vector3(w, 0.024, thick + 0.02)])
	if is_window:
		pieces.append([Vector3(0, y0 + 0.012, 0), Vector3(w, 0.024, thick + 0.02)])
		# Sill with its nose out over the siding, the apron under it, the drip cap, the stool.
		pieces.append([Vector3(0, y0 - 0.02, o_sign * (thick * 0.5 + 0.055)), Vector3(w + cw * 2.0 + 0.1, 0.045, 0.17)])
		pieces.append([Vector3(0, y0 - 0.085, o_sign * (thick * 0.5 + 0.025)), Vector3(w + cw * 2.0, 0.09, 0.026)])
		pieces.append([Vector3(0, y1 + cw + 0.018, o_sign * (thick * 0.5 + 0.04)), Vector3(w + cw * 2.0 + 0.06, 0.036, 0.07)])
		pieces.append([Vector3(0, y0 - 0.012, -o_sign * (thick * 0.5 + 0.035)), Vector3(w + cw * 2.0 + 0.06, 0.03, 0.09)])
	else:
		pieces.append([Vector3(0, FLOOR_Y + 0.006, 0), Vector3(w, 0.012, thick + 0.06)])
	for p in pieces:
		_trim_box(mb, &"paint_ext", center, p[0], p[1], along_x, paint)
	if not is_window:
		return
	# Double-hung sash: the upper one 4 cm further out, meeting at a rail in the middle.
	var mid := (y0 + y1) * 0.5
	var inner_w := w - 0.048
	for upper: bool in [false, true]:
		var z := o_sign * (0.022 if upper else -0.022)
		var s0 := mid - 0.012 if upper else y0 + 0.024
		var s1 := y1 - 0.024 if upper else mid + 0.012
		var sc := _shade(TRIM, 0.9)
		var frame: Array[Array] = [
			[Vector3(-inner_w * 0.5 + 0.025, (s0 + s1) * 0.5, z), Vector3(0.05, s1 - s0, 0.04)],
			[Vector3(inner_w * 0.5 - 0.025, (s0 + s1) * 0.5, z), Vector3(0.05, s1 - s0, 0.04)],
			[Vector3(0, s1 - 0.03, z), Vector3(inner_w, 0.06 if upper else 0.035, 0.04)],
			[Vector3(0, s0 + 0.035, z), Vector3(inner_w, 0.035 if upper else 0.07, 0.04)],
			[Vector3(0, (s0 + s1) * 0.5, z), Vector3(0.022, s1 - s0, 0.03)],
		]
		for i in frame.size():
			# The middle glazing bar is detail.
			_trim_box(_detail if i == 4 else mb, &"paint_ext", center, frame[i][0], frame[i][1], along_x, sc)
		var gy := (s0 + s1) * 0.5 + (0.0125 if upper else 0.0175)
		_trim_box(mb, &"window_glass", center, Vector3(0, gy, z), Vector3(inner_w - 0.09, s1 - s0 - 0.095, 0.006), along_x, Color.WHITE)
	# Linen curtains drawn back on a rod inside, three folds each.
	var cz := -o_sign * (thick * 0.5 + 0.075)
	var linen := Color(0.74, 0.68, 0.58)
	_trim_box(_detail, &"wood_in", center, Vector3(0, y1 + 0.16, cz), Vector3(w + 0.46, 0.022, 0.022), along_x, Color(0.3, 0.26, 0.22))
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var fx := sx * (w * 0.5 + 0.1 - k * 0.085)
			var fz := cz + o_sign * (0.018 if k % 2 == 0 else -0.012)
			_trim_box(_detail, &"cloth", center, Vector3(fx, (y0 - 0.12 + y1 + 0.15) * 0.5, fz), Vector3(0.1, y1 - y0 + 0.27, 0.012),
					along_x, _shade(linen, 0.93 + 0.05 * k))


## One trim piece given along an X wall; walls along Z get it turned a quarter. The
## rough_wood grain runs along a piece that lies along the wall (wider than tall).
func _trim_box(mb: MeshBuilder, key: StringName, center: Vector3, local_pos: Vector3, size: Vector3, along_x: bool,
		color: Color) -> void:
	var lying := size.x > size.y
	if along_x:
		mb.box_at(key, center + local_pos, size, color, Vector3.ZERO, lying)
	else:
		mb.box(key, Transform3D(Basis(Vector3.UP, PI * 0.5), center + Vector3(local_pos.z, local_pos.y, local_pos.x)), size, color, lying)


## The repaired roof: tiles laid in courses over a board deck on exposed rafter tails,
## painted fascia and barge boards, half-round ridge tiles, gutters with a downpipe at
## the east end in front and the west end at the back; lap-sided gables over the
## gable walls; a stone chimney up the back wall with a cap and a clay pot.
func _build_roof(mb: MeshBuilder) -> void:
	var wall_top := FLOOR_Y + WALL_H
	var ridge_y := wall_top + RISE
	var theta := atan2(RISE, D * 0.5)
	var run := D * 0.5 + EAVE
	var slab_len := run / cos(theta)
	var deck := 0.12
	var length_x := W + GABLE_OVERHANG * 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 610 + level
	# The deck's top passes over the ridge so that its underside meets the walls' tops.
	var apex := Vector3(0, ridge_y + deck / cos(theta), 0)
	for side: float in [1.0, -1.0]:
		var frame := BuildingKit.slope_frame(apex, theta, side)
		var edge := BuildingKit.roof_trim(mb, frame, length_x, 0.0, slab_len, D * 0.5 / cos(theta), &"paint_ext", TRIM,
				&"wood_in", LOG, deck, -1.0, _detail)
		BuildingKit.roof_courses(mb, &"roof", frame, length_x + 0.06, 0.0, slab_len + 0.06, ROOF, rng)
		var out := Vector3(0, 0, side)
		var g := edge + out * 0.075 + Vector3(0, -0.035, 0)
		BuildingKit.gutter(mb, g - Vector3(length_x * 0.5 - 0.02, 0, 0), g + Vector3(length_x * 0.5 - 0.02, 0, 0), out)
		var px := (W * 0.5 - 0.32) * side
		var wall := Vector3(px, 0, side * (D * 0.5 + 0.012))
		# Down to the plinth, out over it (it stands 0.21 proud of the siding), on to the ground.
		BuildingKit.downpipe(mb, Vector3(px, g.y - 0.05, g.z), wall, out, _ground(px, side * (D * 0.5 + 0.35)), BuildingKit.GALV,
				0.07, 0.78, 0.21)
		# Frieze board along the wall's top, under the rafter tails.
		mb.box_at(&"paint_ext", Vector3(0, wall_top - 0.08, side * (D * 0.5 + 0.026)), Vector3(W + 0.04, 0.16, 0.03), TRIM, Vector3.ZERO, true)
	BuildingKit.ridge_tiles(mb, &"roof", apex + Vector3(-length_x * 0.5 - 0.02, 0.045, 0), apex + Vector3(length_x * 0.5 + 0.02, 0.045, 0),
			_shade(ROOF, 0.95), rng)
	for sx: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (W * 0.5 - T * 0.5), wall_top, 0))
		mb.prism(&"planks_ext", xf, D, RISE, T, LOG, false)
		var gable := Transform3D(Basis(Vector3(0, 0, -sx), Vector3.UP, Vector3(sx, 0, 0)), Vector3(sx * W * 0.5, wall_top, 0))
		BuildingKit.gable_siding(mb, &"planks_ext", gable, D, RISE, SIDING, rng)
		# A belt board where the gable meets the wall.
		mb.box(&"paint_ext", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (W * 0.5 + 0.026), wall_top, 0)), Vector3(D + 0.02, 0.14, 0.03),
				TRIM, true)
	# Tie beams inside, the grain along them, their tops 12 mm under the walls' (their ends
	# are let into the walls). (No ridge beam: tucked up under the ridge, global
	# illumination leaks the sky onto it through the thin roof.)
	var beams := maxi(2, int(W / 3.0))
	for i in beams:
		var bx := -W * 0.5 + W * (i + 0.5) / beams
		BuildingKit.beam(mb, &"wood_in", Vector3(bx, wall_top - 0.106, -D * 0.5 + 0.1), Vector3(bx, wall_top - 0.106, D * 0.5 - 0.1), Vector2(0.188, 0.18),
				LOG_DARK, true, 0.0, Vector2(i * 0.43, i * 0.71))
	# Stone chimney: outside stack up the back wall past the ridge, inside flue.
	var chimney_top := ridge_y + 0.9
	var outside_z := -D * 0.5 - 0.12
	mb.box_at(&"stone_ext", Vector3(fireplace_x, chimney_top * 0.5, outside_z), Vector3(0.95, chimney_top, 0.62), STONE)
	mb.box_at(&"stone_ext", Vector3(fireplace_x, chimney_top + 0.05, outside_z), Vector3(1.1, 0.12, 0.76), STONE.darkened(0.15))
	var pot := Transform3D(Basis(), Vector3(fireplace_x + 0.12, chimney_top + 0.11, outside_z))
	mb.cylinder(&"clay", pot, 0.13, 0.11, 0.34, 10, Color(0.56, 0.35, 0.26))
	mb.ring(&"clay", pot * Transform3D(Basis(), Vector3(0, 0.34, 0)), 0.13, 0.09, 0.04, 10, Color(0.5, 0.32, 0.24))
	mb.disc(&"paint_in", pot * Transform3D(Basis(), Vector3(0, 0.3, 0)), 0.1, 10, Color(0.05, 0.045, 0.04))
	_add_collider(Vector3(fireplace_x, 1.5, outside_z), Vector3(0.95, 3.0, 0.62))
	_build_flue(mb, ridge_y, theta)


## The flue inside, from the fireplace up through the roof.
func _build_flue(mb: MeshBuilder, ridge_y: float, theta: float) -> void:
	var flue_z := -D * 0.5 + T + 0.2
	var flue_bottom := FLOOR_Y + 1.33
	var flue_top := ridge_y - tan(theta) * absf(flue_z) + 0.1
	mb.box_at(&"stone", Vector3(fireplace_x, (flue_bottom + flue_top) * 0.5, flue_z), Vector3(0.7, flue_top - flue_bottom, 0.4), STONE.lightened(0.05))


func _porch_width() -> float:
	return 5.0 + (maxi(level, 1) - 1) * 1.5


## Centre of the porch awning (a slab sloping down from the front wall).
func _awning_center(front: float, depth: float) -> Vector3:
	return Vector3(door_x, FLOOR_Y + WALL_H - 0.55, front + depth * 0.5 + 0.1)


## Height of the awning's underside over a porch post standing at `z`.
func _post_top(front: float, depth: float, z: float) -> float:
	var center := _awning_center(front, depth)
	return center.y - (z - center.z) * (0.5 / depth) - 0.06


## The porch as the player walks it: deck, the ramp up from the yard (under the
## steps), the posts and the side rails. The new and the run-down porch share it.
func _porch_colliders(front: float, depth: float, width: float, px: float) -> void:
	_add_collider(Vector3(px, FLOOR_Y * 0.5, front + depth * 0.5), Vector3(width, FLOOR_Y, depth))
	var ramp_angle := atan2(FLOOR_Y, 0.8)
	var ramp_basis := Basis(Vector3.RIGHT, ramp_angle)
	var ramp_center := Vector3(px, FLOOR_Y * 0.5, front + depth + 0.4) - ramp_basis.y * 0.05
	_colliders.append({"xf": Transform3D(ramp_basis, ramp_center), "size": Vector3(1.8, 0.1, Vector2(0.8, FLOOR_Y).length())})
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(px + sx * (width * 0.5 - 0.15), 0, front + depth - 0.15)
		var post_h := _post_top(front, depth, p.z) - FLOOR_Y
		_add_collider(p + Vector3(0, FLOOR_Y + post_h * 0.5, 0), Vector3(0.16, post_h, 0.16))
		var x := px + sx * (width * 0.5 - 0.08)
		_add_collider(Vector3(x, FLOOR_Y + 0.5, front + depth * 0.5 - 0.1), Vector3(0.1, 1.0, depth - 0.2))


## The repaired porch: a deck of boards on a stone footing with rim joists round it,
## box steps of treads and risers, posts on base blocks under a header beam with knee
## braces, side railings with balusters, and a tiled lean-to roof on exposed rafters.
func _build_porch(mb: MeshBuilder) -> void:
	var front := D * 0.5
	var depth := 1.8
	var width := _porch_width()
	var px := door_x
	_porch_colliders(front, depth, width, px)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + level
	var dark := LOG_DARK
	mb.box_at(&"stone_ext", Vector3(px, (FLOOR_Y - 0.2) * 0.5, front + depth * 0.5 - 0.03), Vector3(width - 0.1, FLOOR_Y - 0.2, depth - 0.1), STONE)
	# Rim joists, the grain along them.
	mb.box_at(&"wood_ext", Vector3(px, FLOOR_Y - 0.13, front + depth - 0.02), Vector3(width, 0.2, 0.04), dark, Vector3.ZERO, true)
	for sx: float in [-1.0, 1.0]:
		# The side rims butt against the front one's back.
		var rx := px + sx * (width * 0.5 - 0.02)
		BuildingKit.beam(mb, &"wood_ext", Vector3(rx, FLOOR_Y - 0.13, front), Vector3(rx, FLOOR_Y - 0.13, front + depth - 0.04), Vector2(0.2, 0.04),
				dark, true)
	# Deck boards running out from the house.
	var count := int(width / 0.14)
	var bw := width / count
	for k in count:
		var bx := px - width * 0.5 + (k + 0.5) * bw
		BuildingKit.plank(mb, &"floor", Transform3D(Basis(), Vector3(bx, FLOOR_Y - 0.02, front + depth * 0.5 + 0.01)),
				Vector3(bw - 0.008, 0.04, depth + 0.02), _shade(FLOOR, rng.randf_range(0.86, 1.06)),
				Vector2(rng.randf() * 1.8, rng.randf() * 1.8), true)
	# Two box steps: treads with a nose over the risers, closed at the sides.
	for st: Array in [[0.38, 0.0], [0.19, 0.38]]:
		var top: float = st[0]
		var z0: float = front + depth + float(st[1])
		# The lower step's sides start just past the upper one's ends (not inside them).
		var step_in := 0.012 if float(st[1]) > 0.0 else -0.01
		BuildingKit.plank(mb, &"floor", Transform3D(Basis(), Vector3(px, top - 0.02, z0 + 0.21)), Vector3(1.84, 0.04, 0.42),
				_shade(FLOOR, rng.randf_range(0.9, 1.05)), Vector2(rng.randf(), rng.randf()), false)
		mb.box_at(&"wood_ext", Vector3(px, (top - 0.04) * 0.5, z0 + 0.375), Vector3(1.72, top - 0.04, 0.025), dark, Vector3.ZERO, true)
		for sx: float in [-1.0, 1.0]:
			BuildingKit.beam(mb, &"wood_ext", Vector3(px + sx * 0.88, (top - 0.04) * 0.5, z0 + step_in), Vector3(px + sx * 0.88, (top - 0.04) * 0.5, z0 + 0.39),
					Vector2(top - 0.04, 0.04), dark, true)
	# Posts on base blocks, a header beam over them with knee braces.
	var post_z := front + depth - 0.15
	var beam_top := _post_top(front, depth, post_z)
	var beam_h := 0.16
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(px + sx * (width * 0.5 - 0.15), 0, post_z)
		var h := beam_top - beam_h - FLOOR_Y
		mb.box_at(&"wood_ext", p + Vector3(0, FLOOR_Y + h * 0.5, 0), Vector3(0.14, h, 0.14), dark)
		mb.box_at(&"wood_ext", p + Vector3(0, FLOOR_Y + 0.04, 0), Vector3(0.2, 0.08, 0.2), _shade(dark, 0.9))
		mb.box_at(&"wood_ext", p + Vector3(0, beam_top - beam_h - 0.025, 0), Vector3(0.19, 0.05, 0.19), _shade(dark, 0.9))
		BuildingKit.beam(mb, &"wood_ext", p + Vector3(-sx * 0.05, beam_top - beam_h - 0.5, 0), p + Vector3(-sx * 0.5, beam_top - beam_h - 0.03, 0),
				Vector2(0.09, 0.07), dark, true)
	mb.box_at(&"wood_ext", Vector3(px, beam_top - beam_h * 0.5, post_z), Vector3(width + 0.1, beam_h, 0.14), dark, Vector3.ZERO, true)
	# Side railings: top and bottom rail, balusters between.
	for sx: float in [-1.0, 1.0]:
		var x := px + sx * (width * 0.5 - 0.08)
		var z0 := front + 0.02
		var z1 := post_z - 0.07
		BuildingKit.beam(mb, &"wood_ext", Vector3(x, FLOOR_Y + 0.93, z0), Vector3(x, FLOOR_Y + 0.93, z1), Vector2(0.05, 0.09), dark, true)
		BuildingKit.beam(mb, &"wood_ext", Vector3(x, FLOOR_Y + 0.12, z0), Vector3(x, FLOOR_Y + 0.12, z1), Vector2(0.05, 0.06), dark, true)
		var n := int((z1 - z0) / 0.13)
		for k in range(1, n):
			BuildingKit.plank(_detail, &"wood_in", Transform3D(Basis(), Vector3(x, FLOOR_Y + 0.525, z0 + (z1 - z0) * k / n)), Vector3(0.035, 0.76, 0.035),
					_shade(dark, 1.08), Vector2(k * 0.31, k * 0.57))
	# The lean-to roof: its deck's top where the old slab's was.
	var theta := atan2(0.5, depth)
	var ad := depth + 0.5
	var aw := width + 0.4
	var back_top := _awning_center(front, depth) + Basis(Vector3.RIGHT, theta) * Vector3(0, 0.06, -ad * 0.5)
	var frame := BuildingKit.slope_frame(back_top, theta, 1.0)
	BuildingKit.roof_trim(mb, frame, aw, 0.0, ad, 0.2, &"paint_ext", TRIM, &"wood_in", LOG, 0.12, -1.0, _detail)
	BuildingKit.roof_courses(mb, &"roof", frame, aw + 0.06, 0.0, ad + 0.06, ROOF, rng)
	# Flashing board where it meets the wall.
	mb.box_at(&"paint_ext", Vector3(back_top.x, back_top.y + 0.07, front + 0.016), Vector3(aw, 0.14, 0.03), TRIM, Vector3.ZERO, true)


## The hearth; a cold one (the ruin's) has grey ash and charred logs instead of a fire.
func _build_fireplace(mb: MeshBuilder, lit := true) -> void:
	var back := -D * 0.5 + T
	var base := Vector3(fireplace_x, FLOOR_Y, back + 0.36)
	var stone := STONE.lightened(0.05) if lit else STONE_OLD
	mb.box_at(&"stone_in", base + Vector3(-0.62, 0.62, 0), Vector3(0.46, 1.24, 0.72), stone)
	mb.box_at(&"stone_in", base + Vector3(0.62, 0.62, 0), Vector3(0.46, 1.24, 0.72), stone)
	# The lintel and the dark firebox stand between the jambs (their sides against the
	# jambs' inner faces), the firebox clear of the wall and on the hearth, the hearth
	# let 1 cm into the floor: none of their faces lies in another's plane.
	mb.box_at(&"stone_in", base + Vector3(0, 1.02, 0), Vector3(0.78, 0.44, 0.72), stone)
	mb.box_at(&"paint_in", base + Vector3(0, 0.465, -0.15), Vector3(0.78, 0.75, 0.4), Color("1c1714") if lit else Color("141210"))
	mb.box_at(&"stone_in", base + Vector3(0, 0.045, 0.2), Vector3(1.9, 0.11, 0.9), STONE.darkened(0.1) if lit else STONE_OLD.darkened(0.15))
	mb.box_at(&"wood_in" if lit else &"wood_old_in", base + Vector3(0, 1.28, 0.04), Vector3(1.95, 0.1, 0.84), LOG_DARK)
	var log_col := Color(0.5, 0.5, 0.5) if lit else Color(0.17, 0.16, 0.15)
	for i in 3:
		var lx := -0.2 + i * 0.2
		mb.cylinder_between(&"bark", base + Vector3(lx, 0.16, -0.25), base + Vector3(lx + 0.05, 0.16, 0.12), 0.06, 0.06, 6, log_col)
	if lit:
		mb.box_at(&"glow", base + Vector3(0, 0.12, -0.06), Vector3(0.62, 0.05, 0.36), Color("ff8a2a"))
		mb.blob(&"glow", Transform3D(Basis.from_scale(Vector3(1.0, 1.8, 0.6)), base + Vector3(0, 0.3, -0.05)), 0.12, 1, Color("ffb347"), 0.3, 2.0, 5)
	else:
		# Old ash, cold for years.
		mb.blob(&"paint_in", Transform3D(Basis.from_scale(Vector3(1.5, 0.22, 0.9)), base + Vector3(0, 0.1, -0.08)), 0.22, 1,
				Color(0.4, 0.39, 0.37), 0.35, 2.2, 7, 0.1)
	_add_collider(base + Vector3(0, 0.65, 0), Vector3(1.8, 1.3, 0.75))


func _build_interior(mb: MeshBuilder) -> void:
	_build_fireplace(mb)
	var fz := D * 0.5
	# Rug in front of the fireplace.
	var rug := Vector3(door_x + 0.2, FLOOR_Y, fz - 3.1)
	# Its bands lie 6 mm over one another (2 mm apart they flickered from across the yard).
	mb.box_at(&"cloth", rug + Vector3(0, 0.006, 0), Vector3(3.0, 0.012, 2.0), Color("9b3d32"))
	mb.box_at(&"cloth", rug + Vector3(0, 0.009, 0), Vector3(2.6, 0.018, 1.6), Color("c8a660"))
	mb.box_at(&"cloth", rug + Vector3(0, 0.012, 0), Vector3(2.2, 0.024, 1.2), Color("9b3d32"))
	# Table with two stools and a lantern.
	var table := Vector3(door_x - 2.4, FLOOR_Y, fz - 3.9)
	_table(mb, table)
	# Shelf with jars on the west wall of the main room.
	var west := (partition_x + 0.07 if level >= 3 else -W * 0.5 + T)
	if level < 2:
		var shelf := Vector3(west + 0.2, FLOOR_Y + 1.6, fz - 1.7)
		mb.box_at(&"wood_in", shelf, Vector3(0.36, 0.05, 1.6), WOOD_FURN)
		var jar_colors: Array[Color] = [Color("c96f3a"), Color("e1c15a"), Color("6e9a4a"), Color("b04a4a")]
		for i in 4:
			var jp := shelf + Vector3(0, 0.03, -0.6 + i * 0.4)
			_jar(mb, Transform3D(Basis(), jp), jar_colors[i])
	# Cupboard by the door.
	var cup := Vector3(W * 0.5 - T - 0.35, FLOOR_Y, fz - 1.3)
	mb.box_at(&"wood_in", cup + Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 1.0), Color(0.44, 0.38, 0.33))
	mb.box_at(&"wood_in", cup + Vector3(-0.31, 0.55, -0.24), Vector3(0.02, 0.9, 0.44), Color(0.5, 0.44, 0.38), Vector3.ZERO, true)
	mb.box_at(&"wood_in", cup + Vector3(-0.31, 0.55, 0.24), Vector3(0.02, 0.9, 0.44), Color(0.5, 0.44, 0.38), Vector3.ZERO, true)
	_add_collider(cup + Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 1.0))
	_worktable(mb, false)
	_desk(mb, false)
	if level >= 2:
		_kitchen(mb)
	if level >= 3:
		_bedroom(mb)


## A preserve jar with its lid, standing on the origin of `xf`.
func _jar(mb: MeshBuilder, xf: Transform3D, color: Color) -> void:
	mb.cylinder(&"paint_in", xf, 0.09, 0.08, 0.2, 8, color)
	mb.cylinder(&"wood_in", xf * Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.06, 0.06, 0.04, 8, Color(0.42, 0.37, 0.32))


## Table (1.4 x 0.9) with, when asked, a lantern, two stools and its collision box.
func _table(mb: MeshBuilder, table: Vector3, furnished := true, collide := true) -> void:
	mb.box_at(&"wood_in", table + Vector3(0, 0.78, 0), Vector3(1.4, 0.06, 0.9), WOOD_FURN)
	for lx: float in [-0.6, 0.6]:
		for lz: float in [-0.35, 0.35]:
			mb.box_at(&"wood_in", table + Vector3(lx, 0.38, lz), Vector3(0.07, 0.76, 0.07), LOG_DARK)
	if collide:
		_add_collider(table + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.9))
	if not furnished:
		return
	for sz: float in [-0.85, 0.85]:
		_stool(mb, table + Vector3(0, 0, sz))
	var lantern := table + Vector3(0.2, 0.81, 0.1)
	mb.box_at(&"metal", lantern + Vector3(0, 0.02, 0), Vector3(0.16, 0.04, 0.16), Color("3b3b3b"))
	mb.box_at(&"glow", lantern + Vector3(0, 0.13, 0), Vector3(0.1, 0.16, 0.1), Color("ffcf7a"))
	mb.box_at(&"metal", lantern + Vector3(0, 0.24, 0), Vector3(0.16, 0.05, 0.16), Color("3b3b3b"))


## Three-legged stool standing on `stool`.
func _stool(mb: MeshBuilder, stool: Vector3) -> void:
	mb.cylinder(&"wood_in", Transform3D(Basis(), stool + Vector3(0, 0.44, 0)), 0.2, 0.2, 0.05, 10, WOOD_FURN)
	for i in 3:
		var a := TAU * i / 3.0
		mb.cylinder_between(&"wood_in", stool + Vector3(cos(a) * 0.14, 0, sin(a) * 0.14), stool + Vector3(cos(a) * 0.1, 0.44, sin(a) * 0.1), 0.025, 0.02, 5, LOG_DARK)


## Kitchen corner along the back wall of the main room's west side.
func _kitchen(mb: MeshBuilder) -> void:
	var back := -D * 0.5 + T
	var x0 := _kitchen_x()
	var length := 3.4
	var counter := Vector3(x0 + length * 0.5, FLOOR_Y, back + 0.33)
	mb.box_at(&"wood_in", counter + Vector3(0, 0.44, 0), Vector3(length, 0.88, 0.62), Color(0.44, 0.38, 0.33))
	mb.box_at(&"stone_in", counter + Vector3(0, 0.9, 0), Vector3(length + 0.04, 0.05, 0.66), Color(0.62, 0.6, 0.58))
	for i in 4:
		var dx := -length * 0.5 + length * (i + 0.5) / 4.0
		mb.box_at(&"wood_in", counter + Vector3(dx, 0.46, 0.315), Vector3(length / 4.0 - 0.06, 0.7, 0.02), Color(0.5, 0.44, 0.38), Vector3.ZERO, true)
		mb.box_at(&"metal", counter + Vector3(dx, 0.7, 0.34), Vector3(0.12, 0.025, 0.025), Color(0.25, 0.25, 0.25))
	_add_collider(counter + Vector3(0, 0.45, 0), Vector3(length, 0.9, 0.62))
	# Cast-iron stove at the end of the counter.
	var stove := Vector3(x0 + length + 0.45, FLOOR_Y, back + 0.36)
	mb.box_at(&"steel", stove + Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.64), Color(0.16, 0.16, 0.17))
	mb.box_at(&"steel", stove + Vector3(0, 0.92, 0), Vector3(0.74, 0.04, 0.68), Color(0.12, 0.12, 0.13))
	for sx: float in [-0.15, 0.15]:
		mb.cylinder(&"steel", Transform3D(Basis(), stove + Vector3(sx, 0.94, 0)), 0.1, 0.1, 0.02, 12, Color(0.2, 0.2, 0.2))
	mb.box_at(&"glow", stove + Vector3(0, 0.3, 0.325), Vector3(0.3, 0.12, 0.01), Color("ff7a24"))
	mb.cylinder(&"steel", Transform3D(Basis(), stove + Vector3(0.2, 0.94, -0.2)), 0.07, 0.07, WALL_H + 0.5, 10, Color(0.16, 0.16, 0.17))
	_add_collider(stove + Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.64))
	# Pots and a cutting board on the counter.
	mb.cylinder(&"steel", Transform3D(Basis(), counter + Vector3(-0.8, 0.925, 0)), 0.15, 0.14, 0.16, 14, Color(0.5, 0.5, 0.52))
	mb.box_at(&"wood_in", counter + Vector3(0.6, 0.94, 0.02), Vector3(0.5, 0.03, 0.32), Color(0.62, 0.5, 0.36))
	# Hanging shelf with jars above the counter.
	var shelf := counter + Vector3(0, 1.62, -0.12)
	mb.box_at(&"wood_in", shelf, Vector3(length - 0.2, 0.05, 0.32), WOOD_FURN)
	var jar_colors: Array[Color] = [Color("c96f3a"), Color("e1c15a"), Color("6e9a4a"), Color("b04a4a"), Color("d9d3c2")]
	for i in 5:
		_jar(mb, Transform3D(Basis(), shelf + Vector3(-1.3 + i * 0.65, 0.03, 0)), jar_colors[i])
	# Dining table in the middle of the room.
	var dining := Vector3(x0 + 1.7, FLOOR_Y, back + 2.4)
	_table(mb, dining)


func _bedroom(mb: MeshBuilder) -> void:
	var x_mid := (-W * 0.5 + partition_x) * 0.5
	var rug := Vector3(x_mid + 0.3, FLOOR_Y, 0.2)
	mb.box_at(&"cloth", rug + Vector3(0, 0.006, 0), Vector3(2.2, 0.012, 2.8), Color("3e5a7a"))
	mb.box_at(&"cloth", rug + Vector3(0, 0.009, 0), Vector3(1.8, 0.018, 2.4), Color("d8cfb8"))
	# Nightstand with a candle beside the bed.
	var stand := Vector3(-W * 0.5 + T + 2.75, FLOOR_Y, -D * 0.5 + T + 0.35)
	mb.box_at(&"wood_in", stand + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.45), WOOD_FURN)
	mb.cylinder(&"paint_in", Transform3D(Basis(), stand + Vector3(0, 0.6, 0)), 0.03, 0.03, 0.12, 8, Color(0.95, 0.92, 0.85))
	mb.box_at(&"glow", stand + Vector3(0, 0.74, 0), Vector3(0.015, 0.03, 0.015), Color("ffcf7a"))
	_add_collider(stand + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.45))
	# Bookshelf on the partition wall.
	var books := Vector3(partition_x - 0.3, FLOOR_Y, -D * 0.5 + 1.6)
	mb.box_at(&"wood_in", books + Vector3(0, 0.9, 0), Vector3(0.38, 1.8, 1.2), Color(0.4, 0.34, 0.29))
	var book_colors: Array[Color] = [Color("7a2e2a"), Color("2f4f6f"), Color("3f6b3a"), Color("8a6a2a"), Color("4a3a5a")]
	for shelf in 3:
		for b in 7:
			var h := 0.22 + (b % 3) * 0.03
			mb.box_at(&"paint_in", books + Vector3(-0.16, 0.35 + shelf * 0.55 + h * 0.5, -0.5 + b * 0.15), Vector3(0.05, h, 0.12), book_colors[(b + shelf) % 5])
	_add_collider(books + Vector3(0, 0.9, 0), Vector3(0.38, 1.8, 1.2))


# --- Grandpa's run-down house (level 0) ---------------------------------------------
# Same footprint, door, porch, bed and chest as level 1, so it walks and sleeps the
# same. The damage is only for show: every wall stretch and hole has a full collider.

func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f)


## Ground height under local (x, z) (flat in the editor, which has no terrain).
func _ground(x: float, z: float) -> float:
	if Engine.is_editor_hint():
		return 0.0
	return TerrainData.height(position.x + x, position.z + z) - position.y


## A hole broken through an old wall: a RepairSpot's place.
func _hole_op(at: float, w: float, bottom: float, top: float) -> Dictionary:
	return {"at": at, "w": w, "bottom": bottom, "top": top, "hole": true, "spot": true}


## The level-1 walls gone to ruin: board walls with the same openings, eight holes
## broken through (two a wall, each a RepairSpot), peeling trim and boarded front
## windows (the old door is a node of its own, see _place_front_door).
func _ruin_walls(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var hw := W * 0.5 - T * 0.5
	var hd := D * 0.5 - T * 0.5
	var window := {"w": 1.2, "bottom": 1.0, "top": 2.1}
	var back := _windows_along(W - 1.0, [fireplace_x])
	var front: Array = [{"at": door_x, "w": 1.3, "bottom": 0.0, "top": 2.3}]
	for wx: float in [door_x - 2.9, door_x + 2.9]:
		front.append(_op(wx, window))
	var west := [_op(0.0, window)]
	var east := [_op(0.6, window)]
	_ruin_wall(mb, true, -hd, back + [_hole_op(0.8, 0.75, 1.8, 2.55), _hole_op(-3.5, 0.6, 0.35, 1.05)], -1, rng)
	_ruin_wall(mb, true, hd, front + [_hole_op(door_x - 1.45, 0.55, 0.25, 0.85), _hole_op(door_x + 1.55, 0.6, 1.25, 1.95)], 1, rng)
	_ruin_wall(mb, false, -hw, west + [_hole_op(-2.3, 0.8, 1.5, 2.3), _hole_op(1.9, 0.7, 0.3, 1.0)], -1, rng)
	_ruin_wall(mb, false, hw, east + [_hole_op(-2.0, 0.8, 0.5, 1.3), _hole_op(2.4, 0.6, 1.4, 2.1)], 1, rng)
	for o: Dictionary in back:
		_ruin_trim(mb, Vector3(o["at"], 0, -hd), o, true, -1, rng, 1)
	for o: Dictionary in front:
		_ruin_trim(mb, Vector3(o["at"], 0, hd), o, true, 1, rng, 0)
	for o: Dictionary in west:
		_ruin_trim(mb, Vector3(-hw, 0, o["at"]), o, false, -1, rng, 1)
	for o: Dictionary in east:
		_ruin_trim(mb, Vector3(hw, 0, o["at"]), o, false, 1, rng, 1)
	# Corner boards, their paint long gone.
	_corner_boards(mb, &"paint_old", TRIM_OLD, rng)


## One board wall of the ruin from FarmHouse openings ("at" along the wall's axis): along
## X at z = `fixed` or along Z at x = `fixed`, its outer face toward `outward`.
func _ruin_wall(mb: MeshBuilder, along_x: bool, fixed: float, openings: Array, outward: int,
		rng: RandomNumberGenerator) -> void:
	var f := _board_wall_frame(along_x, fixed, openings, outward)
	var a: Vector2 = f[0]
	var b: Vector2 = f[1]
	var ops: Array = f[2]
	var cols := []
	BuildingKit.board_wall(mb, cols, a, b, FLOOR_Y, WALL_H, T, &"planks_old", LOG_OLD, ops, rng, 0.14, &"wood_old_in", 0.6, true)
	for o: Dictionary in ops:
		if o.get("spot", false):
			_spots.append({"xf": BuildingKit.opening_frame(a, b, FLOOR_Y, T, o),
					"size": Vector2(float(o["w"]), float(o["top"]) - float(o["bottom"]))})
	for c: Array in cols:
		_colliders.append({"xf": Transform3D(Basis(Vector3.UP, float(c[2])), c[0]), "size": c[1]})


## Weathered frame of a window or door: some pieces have lost their paint, a sill is
## gone. Style 0 (front windows) is boarded up over broken glass; style 1 keeps its
## cross bars, one grimy pane and a few shards.
func _ruin_trim(mb: MeshBuilder, center: Vector3, o: Dictionary, along_x: bool, outward: int,
		rng: RandomNumberGenerator, style: int) -> void:
	var w: float = o["w"]
	var bottom: float = o["bottom"]
	var top: float = o["top"]
	var fw := 0.1
	var depth := T + 0.08
	var mid_y := FLOOR_Y + (bottom + top) * 0.5
	var h := top - bottom
	var is_window := bottom > 0.01
	# The frame stands `proud` into the opening, so the ends of the wall's boards, studs and
	# lining lie behind its faces, not in them. The head runs over both jambs, which stand
	# on the sill (without one they run on down past the opening): no piece inside another.
	var proud := 0.008
	var sill := is_window and rng.randf() < 0.75
	var y_top := FLOOR_Y + top - proud
	var y_foot := FLOOR_Y + bottom + (proud if sill else -fw)
	var jamb := Vector3(fw + proud, y_top - y_foot, depth)
	var pieces: Array[Array] = [
		[Vector3(-w * 0.5 - (fw - proud) * 0.5, (y_top + y_foot) * 0.5, 0), jamb],
		[Vector3(w * 0.5 + (fw - proud) * 0.5, (y_top + y_foot) * 0.5, 0), jamb],
		[Vector3(0, FLOOR_Y + top + (fw - proud) * 0.5, 0), Vector3(w + fw * 2.0, fw + proud, depth)],
	]
	if sill:
		pieces.append([Vector3(0, FLOOR_Y + bottom - (fw - proud) * 0.5, outward * 0.06), Vector3(w + fw * 3.0, fw + proud, depth + 0.12)])
	for p: Array in pieces:
		if rng.randf() < 0.4:
			_trim_box(mb, &"wood_old", center, p[0], p[1], along_x, _shade(LOG_DARK, rng.randf_range(1.1, 1.3)))
		else:
			_trim_box(mb, &"paint_old", center, p[0], p[1], along_x, _shade(TRIM_OLD, rng.randf_range(0.88, 1.04)))
	if not is_window:
		return
	var basis: Basis = Basis() if along_x else Basis(Vector3.UP, PI * 0.5)
	if style == 1:
		# The upright bar stands 6 mm proud of the lying one where they cross.
		_trim_box(mb, &"paint_old", center, Vector3(0, mid_y, 0), Vector3(0.05, h, 0.072), along_x, _shade(TRIM_OLD, 0.9))
		_trim_box(mb, &"paint_old", center, Vector3(0, mid_y, 0), Vector3(w, 0.05, 0.06), along_x, _shade(TRIM_OLD, 0.9))
	for qx: float in [-0.25, 0.25]:
		for qy: float in [-0.25, 0.25]:
			var pane := Transform3D(basis, center + basis * Vector3(qx * w, 0, 0) + Vector3(0, mid_y + qy * h, 0))
			if style == 1 and qx < 0.0 and qy > 0.0:
				mb.box(&"glass_old", pane, Vector3(w * 0.5 - 0.03, h * 0.5 - 0.03, 0.01), Color.WHITE)
			elif style == 1 or rng.randf() < 0.5:
				BuildingKit.broken_glass(mb, pane, w * 0.5 - 0.03, h * 0.5 - 0.03, rng)
	if style == 0:
		# Boards nailed across the outside, none quite level.
		for k in 3:
			var y := mid_y + (k - 1) * h * 0.32 + rng.randf_range(-0.04, 0.04)
			var tilt := Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-7.0, 7.0)))
			var xf := Transform3D(basis * tilt, center + Vector3(0, y, 0) + basis.z * (outward * (T * 0.5 + 0.058)))
			BuildingKit.plank(mb, &"planks_old", xf, Vector3(w + 0.3 + rng.randf_range(0.0, 0.12), BuildingKit.BOARD_H, 0.03),
					_shade(LOG_OLD, rng.randf_range(0.85, 1.05)),
					Vector2(rng.randf() * 2.0, BuildingKit.BOARD_SEAM + rng.randi_range(0, 12) * BuildingKit.BOARD_H))


## Point on the old roof: `x` along the ridge, `s` metres down the slope from it,
## `lift` off the roof plane (bent by the sag).
func _roof_at(side: float, x: float, s: float, lift: float) -> Vector3:
	var n := Vector3(0, cos(_theta), side * sin(_theta))
	return Vector3(x, _ridge_y - sin(_theta) * s - _sag(x, s), side * cos(_theta) * s) + n * lift


## How far the old ridge has sagged at roof point (x, s): most in the middle of the
## ridge, nothing at the gables or down at the eaves, which rest on the walls.
func _sag(x: float, s: float) -> float:
	var lx := W * 0.5 + GABLE_OVERHANG
	return 0.18 * maxf(0.0, 1.0 - x * x / (lx * lx)) * clampf(1.0 - s / _slab_len, 0.0, 1.0)


## Uneven old tiles: a gentle wave over the roof.
func _bump(x: float, s: float) -> float:
	return 0.015 * sin(x * 2.3 + s * 0.8) * sin(s * 3.1 + x * 0.5)


## A panel of the old roof between x `xa..xb` and slope distances `sa..sb`, `lo..hi`
## off the roof plane. `top_uv` / `bottom_uv` give that face roof coordinates (u along
## the ridge, v down the slope) so tiles and boards run on across panels; `bumpy`
## waves the top like old tiles.
func _roof_box(mb: MeshBuilder, key: StringName, side: float, xa: float, xb: float, sa: float, sb: float,
		lo: float, hi: float, color: Color, top_uv := false, bottom_uv := false, bumpy := false) -> void:
	# Box corner order wants -z first: down the slope is +z at the front, -z at the back.
	var sm := sa if side > 0.0 else sb
	var sp := sb if side > 0.0 else sa
	var ha := [hi, hi, hi, hi]
	if bumpy:
		ha = [hi + _bump(xb, sm), hi + _bump(xa, sm), hi + _bump(xb, sp), hi + _bump(xa, sp)]
	var p: Array[Vector3] = [
		_roof_at(side, xa, sm, lo), _roof_at(side, xb, sm, lo), _roof_at(side, xb, sm, ha[0]), _roof_at(side, xa, sm, ha[1]),
		_roof_at(side, xa, sp, lo), _roof_at(side, xb, sp, lo), _roof_at(side, xb, sp, ha[2]), _roof_at(side, xa, sp, ha[3])]
	if not top_uv and not bottom_uv:
		mb.hexa(key, p, color)
		return
	var top: Array[Vector2] = [Vector2(xa, sp), Vector2(xb, sp), Vector2(xb, sm), Vector2(xa, sm)]
	if not top_uv:
		var u := p[7].distance_to(p[6])
		var v := p[7].distance_to(p[3])
		top = [Vector2.ZERO, Vector2(u, 0), Vector2(u, v), Vector2(0, v)]
	var bottom: Array[Vector2] = []
	if bottom_uv:
		bottom = [Vector2(xa, sm), Vector2(xb, sm), Vector2(xb, sp), Vector2(xa, sp)]
	BuildingKit.panel(mb, key, p, color, top, bottom)


## The old roof: tiles on a ridge that has sagged in the middle, holes down to the
## rafters with a few battens left across, patches where the tiles slid off the boards,
## a lost piece of ridge and fascia. The panels follow one bent surface, so they meet.
func _ruin_roof(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var wall_top := FLOOR_Y + WALL_H
	_ridge_y = wall_top + RISE
	_theta = atan2(RISE, D * 0.5)
	var run := D * 0.5 + EAVE
	_slab_len = run / cos(_theta)
	var lx := W * 0.5 + GABLE_OVERHANG
	var cell_x := lx * 2.0 / ROOF_NX
	var cell_s := _slab_len / ROOF_NS
	for side: float in [1.0, -1.0]:
		for i in ROOF_NX:
			var xa := -lx + i * cell_x
			var xb := xa + cell_x
			for j in ROOF_NS:
				var sa := j * cell_s
				var sb := sa + cell_s
				var cell := Vector3i(int(side), i, j)
				if ROOF_HOLES.has(cell):
					_roof_hole(mb, side, xa, xb, sa, sb, rng)
					continue
				# Ceiling boards under the tiles, seen from inside and under the eaves.
				_roof_box(mb, &"wood_old_in", side, xa, xb, sa, sb, -0.023, -0.003, LOG_OLD, false, true)
				if ROOF_BARE.has(cell):
					_roof_box(mb, &"planks_old", side, xa, xb, sa, sb, -0.003, 0.03, _shade(LOG_OLD, 0.82), true)
				else:
					_roof_box(mb, &"roof_old", side, xa, xb, sa, sb, -0.003, 0.16, ROOF, true, false, true)
		# Rafters under every panel joint, shown by the holes and under the eaves.
		for i in ROOF_NX + 1:
			var x := clampf(-lx + i * cell_x, -lx + 0.07, lx - 0.07)
			_roof_box(mb, &"wood_old", side, x - 0.045, x + 0.045, 0.0, _slab_len, -0.17, -0.025, LOG_DARK)
		# Fascia along the eave, one length rotted away.
		var basis := Basis(Vector3.RIGHT, _theta * side)
		for i in ROOF_NX:
			if (side > 0.0 and i == 8) or (side < 0.0 and i == 3):
				continue
			var eave := _roof_at(side, -lx + (i + 0.5) * cell_x, _slab_len, 0.02)
			mb.box(&"wood_old", Transform3D(basis, eave), Vector3(cell_x - 0.004, 0.22, 0.06), _shade(LOG_DARK, rng.randf_range(0.9, 1.1)))
	# Ridge boards following the sag, one piece lost.
	for i in ROOF_NX:
		if i == 4:
			continue
		var xa := -lx + i * cell_x
		var xb := xa + cell_x
		BuildingKit.beam(mb, &"wood_old", Vector3(xa, _ridge_y - _sag(xa, 0.0) + 0.14, 0), Vector3(xb, _ridge_y - _sag(xb, 0.0) + 0.14, 0),
				Vector2(0.18, 0.28), _shade(LOG_DARK, rng.randf_range(0.9, 1.1)), true)
	for sx: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (W * 0.5 - T * 0.5), wall_top, 0))
		mb.prism(&"planks_old", xf, D, RISE, T, LOG_OLD, false)
	# What is left of the front gutter east of the porch: rusted through at a joint, its
	# end length hanging from one bracket; the downpipe lies in the weeds by the corner.
	var rust := Color(0.36, 0.27, 0.21)
	var g0 := _roof_at(1.0, door_x + _porch_width() * 0.5 + 0.35, _slab_len, 0.0) + Vector3(0, -0.14, 0.1)
	var brk := _roof_at(1.0, door_x + _porch_width() * 0.5 + 1.3, _slab_len, 0.0) + Vector3(0, -0.14, 0.1)
	BuildingKit.gutter(mb, g0, brk, Vector3.BACK, 0.065, rust, &"rusty")
	BuildingKit.gutter(mb, brk + Vector3(0.03, -0.02, 0.01), Vector3(lx - 0.1, brk.y - 1.1, brk.z + 0.14), Vector3.BACK, 0.065,
			rust * 0.95, &"rusty")
	mb.cylinder_between(&"rusty", Vector3(4.95, _ground(4.95, 3.3) + 0.04, 3.3), Vector3(6.1, _ground(6.1, 4.5) + 0.05, 4.5), 0.04, 0.04, 8,
			rust * 0.9)
	# Tie beams; the west one has snapped and its south half hangs down.
	var beams := maxi(2, int(W / 3.0))
	for i in beams:
		var bx := -W * 0.5 + W * (i + 0.5) / beams
		if i > 0:
			mb.box_at(&"wood_old_in", Vector3(bx, wall_top - 0.106, 0), Vector3(0.18, 0.188, D - 0.2), LOG_DARK)
			continue
		mb.box_at(&"wood_old_in", Vector3(bx, wall_top - 0.106, -D * 0.25 - 0.05), Vector3(0.18, 0.188, D * 0.5 - 0.2), LOG_DARK)
		var hang := Vector3(bx, wall_top - 0.1, D * 0.5 - 0.1)
		var r := Basis(Vector3.RIGHT, deg_to_rad(-18.0))
		var half := D * 0.5 - 0.15
		mb.box(&"wood_old_in", Transform3D(r, hang + r * Vector3(0, 0, -half * 0.5)), Vector3(0.18, 0.2, half), LOG_DARK)
	# The chimney has lost its cap and top courses; its stones lie on the roof.
	var chimney_top := _ridge_y + 0.4
	var outside_z := -D * 0.5 - 0.12
	mb.box_at(&"stone_old", Vector3(fireplace_x, chimney_top * 0.5, outside_z), Vector3(0.95, chimney_top, 0.62), STONE_OLD)
	for k in 3:
		var sp := Vector3(fireplace_x + rng.randf_range(-0.3, 0.3), chimney_top + 0.06, outside_z + rng.randf_range(-0.18, 0.18))
		mb.blob(&"stone_old", Transform3D(Basis(), sp), rng.randf_range(0.07, 0.11), 1, STONE_OLD, 0.25, 2.0, 40 + k, 0.1, false, -0.3)
	_add_collider(Vector3(fireplace_x, 1.5, outside_z), Vector3(0.95, 3.0, 0.62))
	_build_flue(mb, _ridge_y, _theta)


## A roof cell open to the sky: a few battens left across the rafters (some broken),
## tiles hanging over its upper edge, and what fell through lying on the floor.
func _roof_hole(mb: MeshBuilder, side: float, xa: float, xb: float, sa: float, sb: float,
		rng: RandomNumberGenerator) -> void:
	var s := sa + 0.16
	while s < sb - 0.06:
		var x0 := xa
		var x1 := xb
		if rng.randf() < 0.35:
			if rng.randf() < 0.5:
				x1 = xa + (xb - xa) * rng.randf_range(0.2, 0.6)
			else:
				x0 = xb - (xb - xa) * rng.randf_range(0.2, 0.6)
		_roof_box(mb, &"wood_old", side, x0, x1, s - 0.025, s + 0.025, -0.025, 0.0, _shade(LOG_DARK, 1.15))
		s += 0.32
	var roof_basis := Basis(Vector3.RIGHT, _theta * side)
	for k in 3:
		var tx := rng.randf_range(xa + 0.12, xb - 0.12)
		var tile := _roof_at(side, tx, sa + 0.1, 0.1)
		var b := roof_basis * Basis(Vector3.RIGHT, side * deg_to_rad(rng.randf_range(12.0, 30.0))) \
				* Basis(Vector3.UP, rng.randf_range(-0.3, 0.3))
		mb.box(&"roof_old", Transform3D(b, tile), Vector3(0.24, 0.02, 0.3), _shade(ROOF, rng.randf_range(0.85, 1.05)))
	# Fallen tiles and a broken batten on the floor below, if it is inside.
	var mid := _roof_at(side, (xa + xb) * 0.5, (sa + sb) * 0.5, 0.0)
	if absf(mid.x) > W * 0.5 - T - 0.3 or absf(mid.z) > D * 0.5 - T - 0.3:
		return
	for k in 5:
		var fp := Vector3(mid.x + rng.randf_range(-0.5, 0.5), FLOOR_Y + 0.012, mid.z + rng.randf_range(-0.45, 0.45))
		var size := Vector3(0.24, 0.02, 0.3) * (rng.randf_range(0.45, 1.0) if k > 1 else 1.0)
		mb.box_at(&"roof_old", fp, size, _shade(ROOF, rng.randf_range(0.8, 1.0)),
				Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 180.0), rng.randf_range(-8.0, 8.0)))
	var yaw := rng.randf_range(0.0, TAU)
	var dir := Vector3(cos(yaw), 0, sin(yaw)) * 0.45
	BuildingKit.beam(mb, &"wood_old", Vector3(mid.x, FLOOR_Y + 0.02, mid.z) - dir, Vector3(mid.x, FLOOR_Y + 0.05, mid.z) + dir,
			Vector2(0.025, 0.05), _shade(LOG_DARK, 1.1), true)


## The old porch: the same walkable shape (shared colliders), over a deck of rotting
## boards with two missing, a sunk step, a sagging split awning, a leaning post and a
## broken rail.
func _ruin_porch(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var front := D * 0.5
	var depth := 1.8
	var width := _porch_width()
	var px := door_x
	_porch_colliders(front, depth, width, px)
	mb.box_at(&"stone_old", Vector3(px, (FLOOR_Y - 0.16) * 0.5, front + depth * 0.5), Vector3(width, FLOOR_Y - 0.16, depth), STONE_OLD)
	for k in 5:
		var jz := front + 0.12 + k * (depth - 0.24) / 4.0
		mb.box_at(&"wood_old", Vector3(px, FLOOR_Y - 0.1, jz), Vector3(width - 0.1, 0.1, 0.1), LOG_DARK)
	# The rim board, proud of the deck boards' ends and the stone under them.
	mb.box_at(&"wood_old", Vector3(px, FLOOR_Y - 0.1, front + depth), Vector3(width + 0.02, 0.2, 0.04), _shade(LOG_DARK, 1.1))
	# Deck boards running out from the house.
	var count := int(width / 0.2)
	var bw := width / count
	for k in count:
		if k == 4 or k == count - 8:
			continue
		var bx := px - width * 0.5 + (k + 0.5) * bw
		var c := _shade(FLOOR_OLD, rng.randf_range(0.8, 1.05))
		var uv := Vector2(rng.randf() * 1.8, rng.randf() * 1.8)
		if k == int(count * 0.5) - 2:
			# Cracked through and sunk between two joists, its broken ends down.
			for piece: float in [-1.0, 1.0]:
				var pz := front + depth * 0.5 + piece * depth * 0.25
				var tilt := Basis(Vector3.RIGHT, deg_to_rad(-3.5 * piece)) * Basis(Vector3.BACK, deg_to_rad(1.5))
				BuildingKit.plank(mb, &"floor_old", Transform3D(tilt, Vector3(bx, FLOOR_Y - 0.045, pz)), Vector3(bw - 0.012, 0.045, depth * 0.5 - 0.02),
						_shade(c, 0.85), uv, true)
			continue
		var warp := Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-1.2, 1.2)))
		BuildingKit.plank(mb, &"floor_old", Transform3D(warp, Vector3(bx, FLOOR_Y - 0.025, front + depth * 0.5)),
				Vector3(bw - 0.012, 0.05, depth), c, uv, true)
	# Box steps of rotten boards: the top tread split, its west half sunk and tipped;
	# the lower one darker from the wet.
	for st: Array in [[0.38, 0.0], [0.19, 0.38]]:
		var top: float = st[0]
		var z0: float = front + depth + float(st[1])
		# The lower step's sides start just past the upper one's ends (not inside them).
		var step_in := 0.012 if float(st[1]) > 0.0 else -0.01
		var dark := _shade(LOG_DARK, 0.9 if top < 0.3 else 1.0)
		mb.box_at(&"wood_old", Vector3(px, (top - 0.04) * 0.5, z0 + 0.375), Vector3(1.72, top - 0.04, 0.025), dark, Vector3.ZERO, true)
		for sx: float in [-1.0, 1.0]:
			BuildingKit.beam(mb, &"wood_old", Vector3(px + sx * 0.88, (top - 0.04) * 0.5, z0 + step_in), Vector3(px + sx * 0.88, (top - 0.04) * 0.5, z0 + 0.39),
					Vector2(top - 0.04, 0.04), dark, true)
		# Treads of the old siding boards, grey, grimy and mossy from the wet.
		var tc := _shade(LOG_OLD, 0.64 if top < 0.3 else 0.74)
		if top > 0.3:
			var tip := Basis.from_euler(Vector3(deg_to_rad(6.0), 0.0, deg_to_rad(-4.0)))
			BuildingKit.plank(mb, &"planks_old", Transform3D(tip, Vector3(px - 0.45, top - 0.065, z0 + 0.21)), Vector3(0.86, 0.04, 0.42),
					_shade(tc, 0.9), Vector2(rng.randf(), rng.randf()), false)
			BuildingKit.plank(mb, &"planks_old", Transform3D(Basis(), Vector3(px + 0.46, top - 0.02, z0 + 0.21)), Vector3(0.9, 0.04, 0.42), tc,
					Vector2(rng.randf(), rng.randf()), false)
		else:
			BuildingKit.plank(mb, &"planks_old", Transform3D(Basis(Vector3.UP, deg_to_rad(1.5)), Vector3(px, top - 0.02, z0 + 0.21)),
					Vector3(1.84, 0.04, 0.42), tc, Vector2(rng.randf(), rng.randf()), false)
	# Awning in two pieces, the east one sagging further, a rafter across the gap.
	var theta := atan2(0.5, depth)
	var center := _awning_center(front, depth)
	var aw := width + 0.4
	var ad := depth + 0.5
	var gap := Vector2(0.85, 1.25)
	var back_edge := center + Basis(Vector3.RIGHT, theta) * Vector3(0, 0, -ad * 0.5)
	for piece in 2:
		var x0 := -aw * 0.5 if piece == 0 else gap.y
		var x1 := gap.x if piece == 0 else aw * 0.5
		var b := Basis(Vector3.RIGHT, theta + deg_to_rad(3.0 * piece))
		var c := back_edge + Vector3((x0 + x1) * 0.5, 0, 0) + b * Vector3(0, 0, ad * 0.5)
		# Half round so the tiles' V runs down the slope (see _build_roof).
		mb.box(&"roof_old", Transform3D(b * Basis(Vector3.UP, PI), c), Vector3(x1 - x0, 0.12, ad), ROOF)
	for rx: float in [gap.x + 0.12, gap.y - 0.1]:
		var from := back_edge + Vector3(rx, -0.1, 0)
		var to := back_edge + Vector3(rx, -0.1 - sin(theta) * ad, cos(theta) * ad)
		BuildingKit.beam(mb, &"wood_old", from, to, Vector2(0.08, 0.06), LOG_DARK, true)
	# Posts (the west one leans; its collider stays upright) and rails.
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(px + sx * (width * 0.5 - 0.15), 0, front + depth - 0.15)
		var post_h := _post_top(front, depth, p.z) - FLOOR_Y
		mb.box_at(&"wood_old", p + Vector3(0, FLOOR_Y + post_h * 0.5, 0), Vector3(0.16, post_h, 0.16), LOG_DARK,
				Vector3(0, 0, 3.0 if sx < 0.0 else 0.0), true)
		var x := px + sx * (width * 0.5 - 0.08)
		var rz := front + depth * 0.5 - 0.1
		if sx > 0.0:
			mb.box_at(&"wood_old", Vector3(x, FLOOR_Y + 0.85, rz), Vector3(0.08, 0.08, depth - 0.2), LOG_DARK)
			mb.box_at(&"wood_old", Vector3(x, FLOOR_Y + 0.45, rz), Vector3(0.06, 0.06, depth - 0.2), LOG_DARK)
		else:
			# Top rail snapped: a stub on the post, the rest down on the deck.
			mb.box_at(&"wood_old", Vector3(x, FLOOR_Y + 0.85, front + depth - 0.45), Vector3(0.08, 0.08, 0.5), LOG_DARK)
			BuildingKit.beam(mb, &"wood_old", Vector3(x, FLOOR_Y + 0.85, front + 0.12), Vector3(x + 0.12, FLOOR_Y + 0.05, front + depth - 0.75),
					Vector2(0.08, 0.08), LOG_DARK, true)


## Inside the old house: a floor of loose, rotting boards, a cold hearth, the table
## knocked over under the broken beam, the shelf off the wall, a cupboard without its
## doors, crates, dust, cobwebs and Grandpa's lantern; his worktable and desk still
## stand. The lane from the door and the way to the bed stay clear.
func _ruin_interior(mb: MeshBuilder, clutter: MeshBuilder, rng: RandomNumberGenerator) -> void:
	_ruin_floor(mb, rng)
	_build_fireplace(mb, false)
	var fz := D * 0.5
	var west := -W * 0.5 + T
	# The table lies on its side where the beam came down; a stool fell over.
	var table := Vector3(door_x - 2.4, FLOOR_Y, fz - 3.9)
	var tmp := MeshBuilder.new()
	_table(tmp, Vector3.ZERO, false, false)
	mb.append(tmp, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-82.0)), table + Vector3(0, 0.385, 0.3)))
	_add_collider(table + Vector3(0, 0.47, -0.105), Vector3(1.4, 0.94, 0.92))
	_stool(mb, Vector3(door_x - 1.3, FLOOR_Y, fz - 3.0))
	tmp = MeshBuilder.new()
	_stool(tmp, Vector3.ZERO)
	mb.append(tmp, Transform3D(Basis(Vector3.BACK, deg_to_rad(88.0)) * Basis(Vector3.UP, 0.4), Vector3(door_x - 3.3, FLOOR_Y + 0.2, fz - 5.0)))
	# The shelf hangs from one bracket; its jars lie broken on the floor.
	var shelf := Vector3(west + 0.2, FLOOR_Y + 1.6, fz - 2.5)
	var r := Basis(Vector3.RIGHT, deg_to_rad(25.0))
	mb.box(&"wood_old_in", Transform3D(r, shelf + r * Vector3(0, 0, 0.8)), Vector3(0.36, 0.05, 1.6), _shade(WOOD_FURN, 0.85))
	mb.box_at(&"wood_old_in", shelf + Vector3(-0.06, -0.08, 0.05), Vector3(0.22, 0.14, 0.04), LOG_DARK)
	var jar_colors: Array[Color] = [Color("8a5a3a"), Color("a08a52")]
	for i in 2:
		var jp := Vector3(west + 0.45 + i * 0.35, FLOOR_Y + 0.09, fz - 1.9 + i * 0.4)
		_jar(mb, Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, rng.randf_range(0.0, TAU)), jp), jar_colors[i])
	for i in 4:
		mb.box_at(&"paint_in", Vector3(west + 0.4 + rng.randf() * 0.6, FLOOR_Y + 0.006, fz - 1.4 + rng.randf() * 0.5),
				Vector3(rng.randf_range(0.03, 0.07), 0.01, rng.randf_range(0.03, 0.06)), Color("6e9a4a").darkened(0.3),
				Vector3(0, rng.randf_range(0, 180), 0))
	# Cupboard: one door hanging open, the other on the floor.
	var cup := Vector3(W * 0.5 - T - 0.35, FLOOR_Y, fz - 1.3)
	var cup_col := Color(0.4, 0.35, 0.3)
	mb.box_at(&"wood_old_in", cup + Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 1.0), cup_col)
	mb.box_at(&"paint_in", cup + Vector3(-0.302, 0.55, 0), Vector3(0.006, 0.9, 0.92), Color(0.07, 0.06, 0.05))
	var hinge := cup + Vector3(-0.31, 0.55, 0.46)
	mb.box(&"wood_old_in", Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)), hinge) * Transform3D(Basis(), Vector3(0, 0, -0.22)),
			Vector3(0.02, 0.9, 0.44), _shade(cup_col, 1.15), true)
	mb.box_at(&"wood_old_in", cup + Vector3(-0.75, 0.012, -0.55), Vector3(0.44, 0.02, 0.9), _shade(cup_col, 1.1), Vector3(0, 22, 0), true)
	_add_collider(cup + Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 1.0))
	# Grandpa's worktable and writing desk stood through it all.
	_worktable(mb, true)
	_desk(mb, true)
	# The rug, rolled up against the west wall long ago.
	mb.cylinder_between(&"cloth", Vector3(west + 0.14, FLOOR_Y + 0.13, -1.9), Vector3(west + 0.18, FLOOR_Y + 0.13, 0.0), 0.13, 0.13, 10,
			Color(0.43, 0.29, 0.25))
	# Crates stacked in the south-west corner.
	_crate(mb, Vector3(-W * 0.5 + T + 0.36, FLOOR_Y, fz - T - 0.38), Vector3(0.62, 0.6, 0.62), 8.0, rng)
	_crate(mb, Vector3(-W * 0.5 + T + 0.4, FLOOR_Y + 0.6, fz - T - 0.42), Vector3(0.5, 0.48, 0.5), -12.0, rng)
	_crate(mb, Vector3(-W * 0.5 + T + 1.05, FLOOR_Y, fz - T - 0.34), Vector3(0.55, 0.46, 0.5), 20.0, rng)
	_add_collider(Vector3(-W * 0.5 + T + 0.7, FLOOR_Y + 0.55, fz - T - 0.4), Vector3(1.4, 1.1, 0.76))
	# Rain has come in under the front hole: a damp patch on the floor.
	var puddle := Vector3(door_x - 2.4, FLOOR_Y + 0.001, 1.6)
	clutter.blob(&"water_still", Transform3D(Basis.from_scale(Vector3(1.5, 0.012, 1.0)), puddle), 0.42, 2, Color(0.13, 0.13, 0.12),
			0.35, 1.6, 11, 0.0, true)
	# Dust and dried mud blown in over the years.
	var dirt: Array[Vector3] = [Vector3(door_x, 0, fz - 0.45), Vector3(-W * 0.5 + 0.7, 0, -D * 0.5 + 0.7),
		Vector3(W * 0.5 - 0.7, 0, fz - 0.6), Vector3(door_x - 1.4, 0, 1.0), Vector3(-W * 0.5 + 0.8, 0, 0.9)]
	for i in dirt.size():
		var dp := Vector3(dirt[i].x, FLOOR_Y + 0.002, dirt[i].z)
		clutter.blob(&"dirt_old", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.4, 0.015, 0.9)), dp),
				rng.randf_range(0.35, 0.55), 2, Color(0.5, 0.46, 0.4), 0.45, 1.8, 20 + i, 0.0, true)
	# Cobwebs in the upper corners and on the tie beams.
	var top := FLOOR_Y + WALL_H - 0.03
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * (W * 0.5 - T - 0.01), top, sz * (D * 0.5 - T - 0.01))
			BuildingKit.cobweb(clutter, corner, Vector3(-sx, -0.55, 0).normalized(), Vector3(0, -0.55, -sz).normalized(),
					rng.randf_range(0.45, 0.7), rng)
	for bz: float in [-1.8, 1.4]:
		BuildingKit.cobweb(clutter, Vector3(0.09, FLOOR_Y + WALL_H - 0.2, bz), Vector3(1, -0.2, 0).normalized(),
				Vector3(0, -0.7, 0.7).normalized(), 0.4, rng)
	# Grandpa's oil lantern on a chain from the east tie beam.
	clutter.cylinder_between(&"metal", Vector3(LANTERN.x, FLOOR_Y + WALL_H - 0.2, LANTERN.z), LANTERN + Vector3(0, 0.2, 0), 0.008, 0.008, 4,
			Color(0.2, 0.19, 0.18))
	clutter.box_at(&"rusty", LANTERN + Vector3(0, -0.12, 0), Vector3(0.15, 0.03, 0.15), Color(0.3, 0.22, 0.16))
	clutter.box_at(&"glow", LANTERN, Vector3(0.08, 0.16, 0.08), Color("ffc46a"))
	for cx: float in [-0.06, 0.06]:
		for cz: float in [-0.06, 0.06]:
			clutter.box_at(&"rusty", LANTERN + Vector3(cx, 0, cz), Vector3(0.012, 0.22, 0.012), Color(0.3, 0.22, 0.16))
	clutter.cylinder(&"rusty", Transform3D(Basis(), LANTERN + Vector3(0, 0.1, 0)), 0.1, 0.02, 0.1, 8, Color(0.3, 0.22, 0.16))


## Floor of loose boards over the stone base: some warped, one sunk, a few gone
## (FLOOR_GAPS) where the rain came through. It walks as one flat floor.
func _ruin_floor(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var fw := W - 0.1
	var fd := D - 0.1
	var rows := int(fd / 0.2)
	var bw := fd / rows
	for row in rows:
		var z := -fd * 0.5 + (row + 0.5) * bw
		var u := -fw * 0.5
		while u < fw * 0.5 - 0.05:
			var run := minf(rng.randf_range(1.6, 3.4), fw * 0.5 - u)
			if fw * 0.5 - u - run < 0.4:
				run = fw * 0.5 - u
			var c := _shade(FLOOR_OLD, rng.randf_range(0.82, 1.06))
			var uv := Vector2(rng.randf() * 1.8, rng.randf() * 1.8)
			var warp := rng.randf_range(-1.2, 1.2) if rng.randf() < 0.2 else 0.0
			# Cut out the gaps in this row.
			var pieces: Array[Vector2] = [Vector2(u, u + run)]
			for g: Vector3 in FLOOR_GAPS:
				if int(g.x) != row:
					continue
				var next: Array[Vector2] = []
				for pc: Vector2 in pieces:
					if g.z <= pc.x or g.y >= pc.y:
						next.append(pc)
						continue
					if g.y - pc.x > 0.1:
						next.append(Vector2(pc.x, g.y))
					if pc.y - g.z > 0.1:
						next.append(Vector2(g.z, pc.y))
				pieces = next
			for pc: Vector2 in pieces:
				var cx := (pc.x + pc.y) * 0.5
				var b := Basis(Vector3.RIGHT, deg_to_rad(warp))
				var y := FLOOR_Y - 0.025
				if row == 23 and absf(cx - (door_x - 1.9)) < run * 0.5:
					b = Basis(Vector3.RIGHT, deg_to_rad(3.5))
					y -= 0.02
				BuildingKit.plank(mb, &"floor_old", Transform3D(b, Vector3(cx, y, z)), Vector3(pc.y - pc.x - 0.008, 0.05, bw - 0.008),
						c, uv)
			u += run


## A weathered crate standing on `base`, turned `yaw` degrees.
func _crate(mb: MeshBuilder, base: Vector3, size: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var c := _shade(LOG_OLD, rng.randf_range(0.85, 1.05))
	mb.box(&"planks_old", Transform3D(b, base + Vector3(0, size.y * 0.5, 0)), size, c)
	for band: float in [0.12, size.y - 0.12]:
		mb.box(&"wood_old", Transform3D(b, base + Vector3(0, band, 0)), Vector3(size.x + 0.02, 0.07, size.z + 0.02), LOG_DARK)


## Junk around the old house: boards leaning on the east wall, a barrel and a rusty
## bucket, tiles that slid off the roof, rubble from the chimney.
func _ruin_yard(mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var ex := W * 0.5 + 0.03
	for k in 6:
		var z := 0.3 + k * 0.29 + rng.randf_range(-0.05, 0.05)
		var lean := deg_to_rad(rng.randf_range(68.0, 76.0))
		var length := rng.randf_range(1.7, 2.1)
		var foot := Vector3(ex + cos(lean) * length, _ground(ex + 0.5, z) + 0.02, z)
		var top := Vector3(ex, foot.y + sin(lean) * length, z + rng.randf_range(-0.12, 0.12))
		BuildingKit.beam(mb, &"planks_old", foot, top, Vector2(0.03, BuildingKit.BOARD_H), _shade(LOG_OLD, rng.randf_range(0.8, 1.02)),
				false, 0.0, Vector2(rng.randf() * 2.0, BuildingKit.BOARD_SEAM + rng.randi_range(0, 12) * BuildingKit.BOARD_H))
	_add_collider(Vector3(ex + 0.3, _ground(ex + 0.3, 1.0) + 0.8, 1.05), Vector3(0.6, 1.6, 1.9))
	# A rusty bucket on its side by the porch, and roof tiles that slid off.
	var bucket := Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.BACK, PI * 0.5), Vector3(4.35, _ground(4.2, 4.1) + 0.16, 4.1))
	mb.ring(&"rusty", bucket, 0.16, 0.148, 0.3, 14, Color(0.42, 0.28, 0.2), 0.12, 3)
	mb.disc(&"rusty", bucket * Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), 0.16, 14, Color(0.4, 0.27, 0.19))
	mb.disc(&"rusty", bucket * Transform3D(Basis(), Vector3(0, 0.006, 0)), 0.148, 14, Color(0.3, 0.2, 0.14))
	for k in 6:
		var tx := rng.randf_range(2.9, 4.0)
		var tz := rng.randf_range(3.7, 4.4)
		mb.box_at(&"roof_old", Vector3(tx, _ground(tx, tz) + 0.02, tz), Vector3(0.24, 0.02, 0.3) * (1.0 if k < 4 else 0.55),
				_shade(ROOF, rng.randf_range(0.8, 1.0)), Vector3(rng.randf_range(-6, 6), rng.randf_range(0, 180), rng.randf_range(-6, 6)))
	for k in 4:
		var rx := fireplace_x + rng.randf_range(-0.7, 0.7)
		var rz := -D * 0.5 - 0.65 - rng.randf() * 0.4
		mb.blob(&"stone_old", Transform3D(Basis(), Vector3(rx, _ground(rx, rz) + 0.05, rz)), rng.randf_range(0.12, 0.2), 1, STONE_OLD,
				0.25, 2.0, 60 + k, 0.1, false, -0.3)
	if Engine.is_editor_hint():
		return
	# Grandpa's old barrel by the front corner.
	var barrel := MeshInstance3D.new()
	barrel.name = "OldBarrel"
	barrel.mesh = PlaceableModels.mesh(&"pickle_barrel")
	barrel.position = Vector3(W * 0.5 + 0.75, _ground(W * 0.5 + 0.75, 2.75), 2.75)
	barrel.rotation = Vector3(0, 0.6, deg_to_rad(2.0))
	add_child(barrel)
	_add_collider(barrel.position + Vector3(0, 0.44, 0), Vector3(0.62, 0.87, 0.62))


## Tall weeds around the neglected house; the scythe cuts them for hay. The repair
## rebuilds the house without them.
func _spawn_weeds() -> void:
	var spots: Array[Vector2] = [Vector2(-5.6, -1.8), Vector2(-5.5, 1.6), Vector2(-2.4, -4.5), Vector2(1.9, -4.4),
		Vector2(5.6, -1.5), Vector2(4.4, -4.4)]
	for i in spots.size():
		var patch := GrassPatch.new()
		patch.name = "Weed%d" % i
		patch.patch_seed = 300 + i
		patch.resource_id = "house_weed_%d" % i
		patch.position = Vector3(spots[i].x, _ground(spots[i].x, spots[i].y), spots[i].y)
		add_child(patch)


# --- Collision -------------------------------------------------------------------

func _add_collider(center: Vector3, size: Vector3) -> void:
	_colliders.append({"xf": Transform3D(Basis(), center), "size": size})


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	for c in _colliders:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c["size"]
		cs.shape = box
		cs.transform = c["xf"]
		body.add_child(cs)
	add_child(body)
