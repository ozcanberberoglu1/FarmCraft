class_name VetClinic
extends Node3D
## Yeşilova Veteriner Kliniği: the town's country vet, behind the south pavement at the
## west end of the street (Town.VET), facing it across a paved front yard. Built from the
## town's pieces into its mesh (Town adds this node and calls build): pale plaster over a
## dark stone plinth, a printed fascia sign with the clinic's badge (a white cross and a
## paw on green) and a blade sign over the yard, both lit at night, a shop window, an
## automatic sliding glass door under a concrete canopy, the hours on a plate by it.
##
## Inside, a small waiting room on a tiled floor: chairs along the wall under posters, a
## coffee table, a rubber plant in the window, a water cooler, a shelf of pet food and a dog
## scale by the counter. Dr. Selin (TownPeople places her at vet_spot()) stands behind the
## reception counter with her clipboard and the appointments monitor, the medicine
## cabinet, her diploma and the clock behind her, the closed door of the treatment room.
##
## Open OPENS..CLOSES (game hours): then the lights are on, the "AÇIK" sign hangs in the
## window, the door slides open for the player and E at the counter (the Point in group
## &"vet_counter") or at her opens the vet screen (Game.hud.open_vet). Closed, she has gone
## home, the room is dark, the door stays shut and only says when the clinic opens; a
## farmer still inside at closing time is served, and let out, before she leaves.

## Opening hours (game hours: from, to).
const OPENS := 8.0
const CLOSES := 20.0
## Wall height, wall thickness and the floor over the ground.
const HEIGHT := 3.4
const WALL := 0.3
const FLOOR_UP := 0.15
## The front: the door's centre (metres from the east corner), width and head; the shop
## window's centre (from the east corner), width, sill and head.
const DOOR_AT := 1.6
const DOOR_W := 1.5
const DOOR_TOP := 2.3
const WIN_AT := 6.3
const WIN_W := 5.8
const WIN_SILL := 0.55
const WIN_TOP := 2.45
## The reception counter: its customer face (metres in from the front), its ends (in from
## the west wall's outer face), depth and work top; the partition to the treatment room
## (in from the front) and that room's door (its centre, in from the west).
const COUNTER_Z := 3.8
const COUNTER_X := Vector2(3.7, 8.7)
const COUNTER_D := 0.65
const COUNTER_H := 1.02
const PART_Z := 5.8
const PART_T := 0.12
const ROOM_DOOR_X := 5.15
## The fee: FEE_SHARE of what the animal costs at the Animal Market (a young one's price
## for a young one), at least FEE_MIN dollars.
const FEE_SHARE := 0.35
const FEE_MIN := 10
## Minutes a treatment takes, by kind: a bird is quickly seen to, a sheep takes longer, a
## cow or a horse longest (2-3 game hours).
const TREATMENT := {&"chicken": 120.0, &"rooster": 120.0, &"sheep": 150.0, &"cow": 180.0, &"horse": 180.0}
## How bright the sign faces glow at night.
const SIGN_GLOW := 0.15
## Seconds the sliding leaves take to open or shut; how near the door opens them.
const DOOR_TIME := 0.7
const DOOR_REACH := 2.6
## Prints of art/textures/town/vet_print_albedo.png (make_town_textures.py, VET_REGIONS).
const PRINT := {
	"sign": Rect2(0, 0, 1, 0.125),
	"logo": Rect2(0, 0.125, 0.25, 0.25),
	"hours": Rect2(0.25, 0.125, 0.25, 0.125),
	"open": Rect2(0.5, 0.125, 0.25, 0.125),
	"closed": Rect2(0.75, 0.125, 0.25, 0.125),
	"door_plate": Rect2(0.25, 0.25, 0.25, 0.0625),
	"scale": Rect2(0.25, 0.3125, 0.125, 0.0625),
	"clock": Rect2(0.375, 0.3125, 0.0625, 0.0625),
	"screen": Rect2(0.5, 0.25, 0.25, 0.125),
	"diploma": Rect2(0.75, 0.25, 0.25, 0.125),
	"poster_rabies": Rect2(0, 0.375, 0.25, 0.375),
	"poster_parasite": Rect2(0.25, 0.375, 0.25, 0.375),
	"poster_farm": Rect2(0.5, 0.375, 0.25, 0.375),
	"poster_care": Rect2(0.75, 0.375, 0.25, 0.375),
	"bag_dog": Rect2(0, 0.75, 0.125, 0.1875),
	"bag_cat": Rect2(0.125, 0.75, 0.125, 0.1875),
	"bag_puppy": Rect2(0.25, 0.75, 0.125, 0.1875),
	"bag_feed": Rect2(0.375, 0.75, 0.125, 0.1875),
	"box_meds": Rect2(0.5, 0.75, 0.25, 0.125),
	"chart": Rect2(0.75, 0.75, 0.25, 0.25),
}
const PLASTER := Color(0.66, 0.65, 0.6)
const STONE := Color(0.27, 0.27, 0.28)
const WAINSCOT := Color(0.5, 0.6, 0.55)
const WALL_IN := Color(0.92, 0.9, 0.85)
const LAMINATE := Color(0.88, 0.88, 0.85)
const GREEN := Color(0.12, 0.45, 0.28)
const STEEL := Color(0.62, 0.63, 0.64)
const GALV_DARK := Color(0.48, 0.49, 0.49)

var town: Town
## The counter's service point (group &"vet_counter") and the vet at it (TownPeople).
var counter: Point
var vet: Townsperson
## The building's footprint and its floor height.
var rect := Rect2()
var floor_y := 0.0
## The vet is in (the lights on, the counter served): during the hours, and after them
## while the farmer is still inside.
var staffed := false

var _door_point: Point
var _leaves: Array[Node3D] = []
var _leaf_shut: Array[float] = []
var _door_shape: CollisionShape3D
var _door_t := 0.0
var _door_set := false
var _lights: Array[Light3D] = []
var _panels: MeshInstance3D
var _open_sign: MeshInstance3D
var _closed_sign: MeshInstance3D
var _check_t := 0.0
var _sign_lit := -1

static var _mats := {}


## The clinic's own surfaces, added to the town's (MeshBuilder.build overrides): its print
## matte (posters, labels), the sign faces (lit at night, see _process) and the monitor's
## and the scale's screens (self-lit).
static func add_materials(into: Dictionary) -> void:
	if _mats.is_empty():
		var tex: Texture2D = load("res://art/textures/town/vet_print_albedo.png")
		for key: StringName in [&"t_vet_print", &"t_vet_sign", &"t_vet_screen"]:
			var m := StandardMaterial3D.new()
			m.albedo_texture = tex
			m.vertex_color_use_as_albedo = true
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.roughness = 0.55 if key == &"t_vet_sign" else 0.7
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if key == &"t_vet_sign":
				m.emission_enabled = true
				m.emission_texture = tex
				m.emission = Color.WHITE
				m.emission_energy_multiplier = 0.0
			elif key == &"t_vet_screen":
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_mats[key] = m
	into.merge(_mats)


## What treating a `species` animal (`adult` or young) costs.
static func fee(species: StringName, adult: bool) -> int:
	var price := int(AnimalTable.get_species(species).get("adult_price" if adult else "baby_price", 0))
	return maxi(FEE_MIN, roundi(price * FEE_SHARE))


## Game minutes a `species` animal stays at the clinic.
static func treatment_minutes(species: StringName) -> float:
	return float(TREATMENT.get(species, 150.0))


func is_open() -> bool:
	var h := GameClock.get_hour_float()
	return h >= OPENS and h < CLOSES


## Where the vet stands behind the counter (her feet) and which way she faces (yaw).
func vet_spot() -> Vector3:
	return Vector3(rect.position.x + 6.0, floor_y, rect.position.y + COUNTER_Z + COUNTER_D + 0.24)


func vet_yaw() -> float:
	return PI


## The doorway's middle on the floor (where the street meets the clinic).
func door_point() -> Vector3:
	return Vector3(rect.end.x - DOOR_AT, floor_y, rect.position.y + WALL * 0.5)


## The player stands inside (in the waiting room or the staff's space).
func has_inside(p: Vector3) -> bool:
	return rect.grow(-WALL).has_point(Vector2(p.x, p.z)) and absf(p.y - floor_y) < 2.5


func _ready() -> void:
	name = "VetClinic"


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.25
		_update_state()
	_update_door(delta)


## Every quarter second: whether she is in (lights, the vet, the window sign) and the
## sign's glow at night.
func _update_state() -> void:
	var player := Game.player as Node3D
	var inside := player != null and has_inside(player.global_position)
	# A farmer still inside at closing time is served (and let out) before she goes.
	var want := is_open() or (staffed and inside)
	if want != staffed:
		_set_staffed(want)
	_open_sign.visible = is_open()
	_closed_sign.visible = not is_open()
	var lit := 1 if DayNightCycle.night_factor > 0.35 or Weather.overcast > 0.85 else 0
	if lit != _sign_lit:
		_sign_lit = lit
		(_mats[&"t_vet_sign"] as StandardMaterial3D).emission_energy_multiplier = SIGN_GLOW * lit


func _set_staffed(on: bool) -> void:
	staffed = on
	for l in _lights:
		l.visible = on
	_panels.visible = on
	_door_point.collision_layer = 0 if on else 4
	set_vet(vet)


## The vet at the counter (TownPeople): there while the clinic is staffed, gone home (not
## drawn, not in the way, not posed) otherwise.
func set_vet(person: Townsperson) -> void:
	vet = person
	if vet == null:
		return
	vet.visible = staffed
	vet.collision_layer = (4 | 16) if staffed else 0
	vet.process_mode = Node.PROCESS_MODE_INHERIT if staffed else Node.PROCESS_MODE_DISABLED


## The leaves slide apart when the farmer comes near while she is in (or to let him out),
## and shut behind him; shut, they stop him.
func _update_door(delta: float) -> void:
	var want := false
	var player := Game.player as Node3D
	if player:
		var p := player.global_position
		var d := Vector2(p.x, p.z).distance_to(Vector2(door_point().x, door_point().z))
		want = d < DOOR_REACH and absf(p.y - floor_y) < 2.0 and (staffed or has_inside(p))
	var t := move_toward(_door_t, 1.0 if want else 0.0, delta / DOOR_TIME)
	if t == _door_t and _door_set:
		return
	_door_t = t
	_door_set = true
	var ease_t := t * t * (3.0 - 2.0 * t)
	for i in _leaves.size():
		_leaves[i].position.x = _leaf_x(i, ease_t)
	_door_shape.disabled = _door_t > 0.35


func _leaf_x(i: int, t: float) -> float:
	return _leaf_shut[i] + (-1.0 if i == 0 else 1.0) * (DOOR_W * 0.5 - 0.02) * t


# --- Building --------------------------------------------------------------------------

## Builds the clinic into the town's mesh `mb` and colliders `cols` (Town._ready).
func build(t: Town, mb: MeshBuilder, cols: Array) -> void:
	town = t
	rect = Town.VET
	floor_y = town._y(rect.get_center().x, rect.get_center().y) + FLOOR_UP
	add_materials(Town._materials())
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	BuildingKit.shell(mb, cols, rect, floor_y, HEIGHT, WALL, &"t_plaster", PLASTER, {
		"n": [{"at": WIN_AT, "w": WIN_W, "bottom": WIN_SILL, "top": WIN_TOP, "glass": false},
			{"at": DOOR_AT, "w": DOOR_W, "bottom": 0.0, "top": DOOR_TOP, "glass": false}],
		"w": [{"at": rect.size.y - 2.6 - WALL, "w": 1.2, "bottom": 1.0, "top": 2.2, "glass": true}],
	})
	# The shop window: clear plate glass (the waiting room plain to see), two mullions.
	var wx := x1 - WIN_AT
	var gz := z0 + WALL * 0.5
	town._glass("VetGlass").box_at(&"t_showroom_glass", Vector3(wx, floor_y + (WIN_SILL + WIN_TOP) * 0.5, gz),
			Vector3(WIN_W - 0.14, WIN_TOP - WIN_SILL - 0.14, 0.02), Color.WHITE)
	var alu := Color(0.7, 0.71, 0.72)
	for k in range(1, 3):
		mb.box_at(&"metal", Vector3(wx - WIN_W * 0.5 + WIN_W * k / 3.0, floor_y + (WIN_SILL + WIN_TOP) * 0.5, gz),
				Vector3(0.06, WIN_TOP - WIN_SILL, 0.12), alu)
	for y: float in [WIN_SILL + 0.035, WIN_TOP - 0.035]:
		mb.box_at(&"metal", Vector3(wx, floor_y + y, gz), Vector3(WIN_W, 0.07, 0.12), alu)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"metal", Vector3(wx + sx * (WIN_W * 0.5 - 0.035), floor_y + (WIN_SILL + WIN_TOP) * 0.5, gz),
				Vector3(0.07, WIN_TOP - WIN_SILL, 0.12), alu)
	cols.append([Vector3(wx, floor_y + (WIN_SILL + WIN_TOP) * 0.5, gz), Vector3(WIN_W, WIN_TOP - WIN_SILL, WALL), 0.0])
	_front(mb, cols)
	_yard(mb, cols)
	_sides_and_roof(mb, cols)
	_floor_and_walls(mb, cols)
	_waiting_room(mb, cols)
	_counter(mb, cols)
	_behind_counter(mb, cols)
	_door()
	_lighting(mb)
	_set_staffed(is_open())


## A print of PRINT on a quad centred on `at`, facing `normal` (upright), `size` metres.
func _print(mb: MeshBuilder, region: String, at: Vector3, normal: Vector3, size: Vector2,
		key := &"t_vet_print", tint := Color(0.86, 0.86, 0.86)) -> void:
	var r: Rect2 = PRINT[region]
	var right := Vector3.UP.cross(normal).normalized()
	var up := normal.cross(right)
	var hx := right * size.x * 0.5
	var hy := up * size.y * 0.5
	mb.quad(key, at - hx - hy, at + hx - hy, at + hx + hy, at - hx + hy, tint,
			Vector2(r.position.x, r.end.y), r.end, Vector2(r.end.x, r.position.y), r.position)


## The street front: the stone plinth, the fascia sign and the blade sign, the canopy
## over the door with its light, the hours plate, planters, the dogs' bowl and ring,
## downpipes and the window's sill; rain streaks under the sill and the parapet.
func _front(mb: MeshBuilder, cols: Array) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var fz := rect.position.y
	var y0 := floor_y
	var door_x := x1 - DOOR_AT
	# Plinth: a band of dark stone, broken by the door.
	for seg: Vector2 in [Vector2(x0 - 0.04, door_x - DOOR_W * 0.5), Vector2(door_x + DOOR_W * 0.5, x1 + 0.04)]:
		mb.box_at(&"concrete", Vector3((seg.x + seg.y) * 0.5, y0 + 0.17, fz - 0.025), Vector3(seg.y - seg.x, 0.5, 0.05), STONE)
		mb.box_at(&"concrete", Vector3((seg.x + seg.y) * 0.5, y0 + 0.43, fz - 0.035), Vector3(seg.y - seg.x, 0.03, 0.07), STONE.lightened(0.1))
	for side: Array in [[x0, Vector3.LEFT], [x1, Vector3.RIGHT]]:
		var sx: float = side[0]
		var n: Vector3 = side[1]
		mb.box_at(&"concrete", Vector3(sx + n.x * 0.025, y0 + 0.17, rect.get_center().y), Vector3(0.05, 0.5, rect.size.y + 0.1), STONE)
	# The window's sill outside.
	var wx := x1 - WIN_AT
	mb.box_at(&"concrete", Vector3(wx, y0 + WIN_SILL - 0.03, fz - 0.07), Vector3(WIN_W + 0.16, 0.06, 0.16), Color(0.6, 0.6, 0.58))
	town._wall_decal("streaks", Vector3(wx - 1.4, y0 + WIN_SILL - 0.05, fz - 0.02), Vector3.FORWARD, Vector2(2.2, 0.5), Color(1, 1, 1, 0.6))
	# The fascia: the printed sign in a slim aluminium frame, standing off the wall.
	var sign_c := Vector3(x0 + 4.95, y0 + 2.98, fz - 0.09)
	var sign_w := 8.4
	var sign_h := 1.05
	mb.box_at(&"metal", sign_c + Vector3(0, 0, 0.03), Vector3(sign_w + 0.08, sign_h + 0.08, 0.1), Color(0.78, 0.79, 0.8))
	_print(mb, "sign", sign_c + Vector3(0, 0, -0.022), Vector3.FORWARD, Vector2(sign_w, sign_h), &"t_vet_sign", Color(0.9, 0.9, 0.9))
	# The blade sign over the yard by the east corner: the badge, lit, both faces.
	var blade := Vector3(x1 - 0.3, y0 + 3.0, fz - 0.62)
	town._fine.cylinder_between(&"metal", Vector3(blade.x, blade.y + 0.42, fz - 0.02), Vector3(blade.x, blade.y + 0.42, blade.z - 0.42), 0.022, 0.022, 6, Color(0.2, 0.2, 0.21))
	mb.box_at(&"metal", Vector3(blade.x, blade.y + 0.42, fz - 0.03), Vector3(0.12, 0.16, 0.05), Color(0.2, 0.2, 0.21))
	mb.box_at(&"metal", blade, Vector3(0.1, 0.74, 0.74), Color(0.85, 0.86, 0.86))
	for n: Vector3 in [Vector3.LEFT, Vector3.RIGHT]:
		_print(mb, "logo", blade + n * 0.052, n, Vector2(0.7, 0.7), &"t_vet_sign", Color(0.92, 0.92, 0.92))
	# The canopy over the door: a concrete slab on two steel ties, a downlight under it.
	var canopy := Vector3(door_x, y0 + 2.48, fz - 0.47)
	mb.box_at(&"concrete", canopy, Vector3(DOOR_W + 0.6, 0.09, 0.95), Color(0.62, 0.62, 0.6))
	mb.box_at(&"metal", canopy + Vector3(0, 0.05, 0), Vector3(DOOR_W + 0.62, 0.012, 0.97), Color(0.45, 0.46, 0.47))
	for sx: float in [-1.0, 1.0]:
		town._fine.cylinder_between(&"metal", Vector3(door_x + sx * (DOOR_W * 0.5 + 0.2), y0 + 2.5, fz - 0.88),
				Vector3(door_x + sx * (DOOR_W * 0.5 + 0.2), y0 + 3.3, fz - 0.03), 0.012, 0.012, 5, Color(0.2, 0.2, 0.21))
	mb.cylinder(&"metal", Transform3D(Basis(), canopy + Vector3(0, -0.075, -0.05)), 0.07, 0.07, 0.03, 12, Color(0.85, 0.85, 0.83))
	mb.cylinder(&"lamp_glow", Transform3D(Basis(), canopy + Vector3(0, -0.08, -0.05)), 0.05, 0.05, 0.006, 12, Color(1.0, 0.9, 0.72))
	var spot := SpotLight3D.new()
	spot.position = canopy + Vector3(0, -0.12, -0.05)
	spot.basis = Basis.looking_at(Vector3(0, -1, -0.15), Vector3.FORWARD)
	spot.light_color = Color(1.0, 0.86, 0.66)
	spot.spot_range = 6.5
	spot.spot_angle = 68.0
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = false
	spot.light_energy = 0.0
	spot.visible = false
	town.add_child(spot)
	town._lamps.append(spot)
	# The step out of the doorway (the floor stands a hand over the yard).
	mb.box_at(&"concrete", Vector3(door_x, y0 - 0.05, fz - 0.22), Vector3(DOOR_W + 0.3, 0.1, 0.44), Color(0.5, 0.5, 0.49))
	# The hours plate on the wall east of the door, the badge as a sticker on the glass.
	_print(mb, "hours", Vector3(door_x + DOOR_W * 0.5 + 0.38, y0 + 1.55, fz - 0.012), Vector3.FORWARD, Vector2(0.42, 0.21))
	mb.box_at(&"metal", Vector3(door_x + DOOR_W * 0.5 + 0.38, y0 + 1.55, fz - 0.006), Vector3(0.44, 0.23, 0.01), Color(0.8, 0.8, 0.79))
	# Two planters of geraniums west of the door, the dogs' water bowl and tie ring east.
	for k in 2:
		var pot := Vector3(door_x - DOOR_W * 0.5 - 0.35 - k * 0.55, town._y(door_x - 1.2, fz - 0.35) + FLOOR_UP, fz - 0.3)
		town._prop("planter_pot_clay", pot, k * 2.1, 1.6)
		town._geranium(mb, pot + Vector3(0, 0.32, 0), 71 + k, Color(0.78, 0.1, 0.12) if k == 0 else Color(0.9, 0.42, 0.55))
	var bowl := Vector3(door_x + DOOR_W * 0.5 + 0.45, town._y(door_x + 1.2, fz - 0.3) + FLOOR_UP, fz - 0.32)
	mb.cylinder(&"metal", Transform3D(Basis(), bowl), 0.13, 0.15, 0.06, 16, STEEL)
	mb.cylinder(&"water_still", Transform3D(Basis(), bowl + Vector3(0, 0.035, 0)), 0.125, 0.125, 0.012, 16, Color(0.3, 0.36, 0.38))
	mb.ring(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(bowl.x, y0 + 0.62, fz - 0.03)), 0.05, 0.04, 0.012, 12, Color(0.3, 0.3, 0.31))
	mb.box_at(&"metal", Vector3(bowl.x, y0 + 0.66, fz - 0.012), Vector3(0.05, 0.05, 0.024), Color(0.3, 0.3, 0.31))
	# Downpipes at the front corners, on the side walls; streaks from the parapet.
	for side: float in [-1.0, 1.0]:
		var px := (x0 - 0.09) if side < 0.0 else (x1 + 0.09)
		town._downpipe(mb, Vector3(px, y0 - FLOOR_UP, fz + 0.4), y0 + HEIGHT + 0.7)
	for x: float in [x0 + 0.8, x1 - 3.4]:
		town._wall_decal("streaks", Vector3(x, y0 + HEIGHT + 0.95, fz - 0.02), Vector3.FORWARD, Vector2(2.0, 1.0), Color(1, 1, 1, 0.55))
	town._decal("mud", Vector3(door_x, y0 - 0.02, fz - 0.9), Vector2(1.8, 1.2), 0.3, Color(0.6, 0.6, 0.58, 0.3), 0.4)


## The paved yard between the pavement and the front, joining the pavement's west end:
## the pole and the cabinet of the street stand at its edge.
func _yard(mb: MeshBuilder, cols: Array) -> void:
	var yard := yard_rect()
	var top := town._y(yard.get_center().x, yard.get_center().y) + FLOOR_UP
	town._paved(mb, cols, yard, top, 0.5, &"t_pavers", Town.PAVER * 0.98, "nwe", yard, Vector2(Town.WALK_S.position.x, yard.end.x))


## The yard in front (world XZ).
func yard_rect() -> Rect2:
	return Rect2(rect.position.x - 0.7, Town.WALK_S.end.y, rect.size.x + 2.0, rect.position.y - Town.WALK_S.end.y)


## The side walls and the roof: an air conditioner and its pipe on the west wall, the
## sign's banner and a window there, the black water tank and a vent on the roof,
## streaks down the sides.
func _sides_and_roof(mb: MeshBuilder, _cols: Array) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var y0 := floor_y
	var ac := Vector3(x0 - 0.2, y0 + 2.5, rect.position.y + 2.2)
	mb.box_at(&"metal", ac, Vector3(0.32, 0.6, 0.85), Color(0.8, 0.8, 0.78))
	mb.cylinder(&"metal", Transform3D(Basis(Vector3.FORWARD, PI * 0.5), ac + Vector3(-0.16, 0, -0.08)), 0.23, 0.23, 0.012, 16, Color(0.1, 0.1, 0.1))
	for k in 5:
		mb.box_at(&"metal", ac + Vector3(-0.175, -0.2 + k * 0.1, -0.08), Vector3(0.01, 0.012, 0.46), Color(0.5, 0.5, 0.5))
	for dz: float in [-0.3, 0.3]:
		mb.box_at(&"metal", ac + Vector3(0.02, -0.33, dz), Vector3(0.36, 0.04, 0.04), Town.IRON)
	mb.cylinder_between(&"metal", ac + Vector3(0.06, 0.3, 0.35), Vector3(x0 - 0.05, y0 + 3.2, ac.z + 0.55), 0.028, 0.028, 6, Color(0.82, 0.82, 0.8))
	mb.cylinder_between(&"metal", ac + Vector3(0.06, -0.3, 0.38), Vector3(x0 - 0.05, y0 + 0.2, ac.z + 0.5), 0.01, 0.01, 4, Color(0.8, 0.8, 0.78))
	# A vinyl banner of the sign on the west wall, for the road into town.
	var banner := Vector3(x0 - 0.025, y0 + 2.8, rect.position.y + 5.6)
	_print(mb, "sign", banner, Vector3.LEFT, Vector2(4.8, 0.6), &"t_vet_print", Color(0.84, 0.84, 0.84))
	for sz: float in [-2.38, 2.38]:
		for sy: float in [-0.28, 0.28]:
			mb.box_at(&"metal", banner + Vector3(-0.005, sy, sz), Vector3(0.02, 0.025, 0.025), Color(0.75, 0.75, 0.74))
	# The side window's sill and a frosted pane (the treatment room).
	var sw := Vector3(x0 - 0.07, y0 + 0.97, rect.end.y - 2.6)
	mb.box_at(&"concrete", sw, Vector3(0.16, 0.06, 1.36), Color(0.6, 0.6, 0.58))
	mb.box_at(&"paint_in", Vector3(x0 + WALL * 0.5 + 0.03, y0 + 1.6, sw.z), Vector3(0.01, 1.06, 1.06), Color(0.82, 0.84, 0.84))
	var roof := y0 + HEIGHT + 0.3
	var tank := Vector3(x1 - 2.0, roof, rect.end.y - 2.0)
	mb.cylinder(&"metal", Transform3D(Basis(), tank), 0.5, 0.5, 1.05, 16, Color(0.07, 0.07, 0.08))
	mb.cylinder(&"metal", Transform3D(Basis(), tank + Vector3(0, 1.05, 0)), 0.18, 0.18, 0.07, 10, Color(0.07, 0.07, 0.08))
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(x0 + 2.0, roof, rect.end.y - 3.0)), 0.12, 0.12, 0.6, 10, GALV_DARK)
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(x0 + 2.0, roof + 0.6, rect.end.y - 3.0)), 0.2, 0.05, 0.12, 10, GALV_DARK)
	for z: float in [rect.position.y + 3.0, rect.end.y - 2.0]:
		town._wall_decal("streaks", Vector3(x0 - 0.02, y0 + HEIGHT + 0.95, z), Vector3.LEFT, Vector2(2.4, 2.4), Color(1, 1, 1, 0.7))
		town._wall_decal("streaks", Vector3(x1 + 0.02, y0 + HEIGHT + 0.95, z), Vector3.RIGHT, Vector2(2.4, 2.2), Color(1, 1, 1, 0.65))


## The floor tiled in light 60 cm tiles, the walls lined inside: a sage wainscot to a
## chair rail, cream plaster over it, a skirting; the partition to the treatment room.
func _floor_and_walls(mb: MeshBuilder, cols: Array) -> void:
	var ix0 := rect.position.x + WALL
	var ix1 := rect.end.x - WALL
	var iz0 := rect.position.y + WALL
	var iz1 := rect.end.y - WALL
	var y0 := floor_y
	var fy := y0 + 0.024
	mb.box_at(&"tile_floor", Vector3((ix0 + ix1) * 0.5, fy - 0.003, (iz0 + iz1) * 0.5), Vector3(ix1 - ix0, 0.006, iz1 - iz0), Color(0.74, 0.73, 0.7))
	var joint := Color(0.42, 0.41, 0.39)
	var x := ix0 + 0.6
	while x < ix1 - 0.05:
		mb.box_at(&"concrete", Vector3(x, fy + 0.001, (iz0 + iz1) * 0.5), Vector3(0.006, 0.002, iz1 - iz0), joint)
		x += 0.6
	var z := iz0 + 0.6
	while z < iz1 - 0.05:
		mb.box_at(&"concrete", Vector3((ix0 + ix1) * 0.5, fy + 0.001, z), Vector3(ix1 - ix0, 0.002, 0.006), joint)
		z += 0.6
	# The partition (the waiting side faces -z) with the treatment room's door opening.
	var pz := rect.position.y + PART_Z
	var dx := rect.position.x + ROOM_DOOR_X
	var dw := 0.92
	var dh := 2.08
	var top := y0 + HEIGHT - 0.04
	for seg: Vector2 in [Vector2(ix0, dx - dw * 0.5), Vector2(dx + dw * 0.5, ix1)]:
		var c := Vector3((seg.x + seg.y) * 0.5, (y0 + top) * 0.5, pz + PART_T * 0.5)
		var s := Vector3(seg.y - seg.x, top - y0, PART_T)
		mb.box_at(&"plaster_in", c, s, WALL_IN)
		cols.append([c, s, 0.0])
	mb.box_at(&"plaster_in", Vector3(dx, (y0 + dh + top) * 0.5, pz + PART_T * 0.5), Vector3(dw, top - y0 - dh, PART_T), WALL_IN)
	# Its door, shut: white, a frosted pane, a lever, the "MUAYENE" plate; a casing.
	var door := Vector3(dx, y0, pz - 0.005)
	mb.box_at(&"paint_in", door + Vector3(0, dh * 0.5, 0.03), Vector3(dw - 0.04, dh - 0.02, 0.04), Color(0.88, 0.88, 0.86))
	mb.box_at(&"paint_in", door + Vector3(0, 1.5, 0.0), Vector3(0.36, 0.56, 0.012), Color(0.8, 0.83, 0.84))
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"paint_in", door + Vector3(sx * (dw * 0.5 + 0.03), dh * 0.5, 0.0), Vector3(0.07, dh + 0.04, 0.03), Color(0.8, 0.8, 0.78))
	mb.box_at(&"paint_in", door + Vector3(0, dh + 0.04, 0.0), Vector3(dw + 0.13, 0.07, 0.03), Color(0.8, 0.8, 0.78))
	mb.box_at(&"metal", door + Vector3(dw * 0.5 - 0.12, 1.02, -0.02), Vector3(0.13, 0.02, 0.03), STEEL)
	_print(mb, "door_plate", door + Vector3(0, 1.9, -0.012), Vector3.FORWARD, Vector2(0.4, 0.1))
	cols.append([door + Vector3(0, dh * 0.5, 0.03), Vector3(dw, dh, 0.06), 0.0])
	# Linings: the wainscot and the plaster over it, on every inner face but the front's
	# openings (the front wall is lined beside and over them).
	var rail := 1.12
	var faces: Array = [
		# [from, to (XZ along the face), the face's normal (into the room)]
		[Vector2(ix0, iz0), Vector2(ix0, pz), Vector3.RIGHT],
		[Vector2(ix1, iz0), Vector2(ix1, pz), Vector3.LEFT],
		[Vector2(ix0, pz), Vector2(dx - dw * 0.5 - 0.07, pz), Vector3.FORWARD],
		[Vector2(dx + dw * 0.5 + 0.07, pz), Vector2(ix1, pz), Vector3.FORWARD],
		[Vector2(ix0, iz0), Vector2(rect.end.x - WIN_AT - WIN_W * 0.5, iz0), Vector3.BACK],
		[Vector2(rect.end.x - WIN_AT + WIN_W * 0.5, iz0), Vector2(rect.end.x - DOOR_AT - DOOR_W * 0.5, iz0), Vector3.BACK],
		[Vector2(rect.end.x - DOOR_AT + DOOR_W * 0.5, iz0), Vector2(ix1, iz0), Vector3.BACK],
	]
	for f: Array in faces:
		var a: Vector2 = f[0]
		var b: Vector2 = f[1]
		var n: Vector3 = f[2]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		var along_x := absf(n.x) < 0.5
		var size_of := func(h: float, t: float) -> Vector3: return Vector3(length, h, t) if along_x else Vector3(t, h, length)
		var at := Vector3(mid.x, 0.0, mid.y) + n * 0.012
		mb.box_at(&"paint_in", at + Vector3(0, y0 + rail * 0.5, 0), size_of.call(rail, 0.012), WAINSCOT)
		mb.box_at(&"plaster_in", at + Vector3(0, (y0 + rail + top) * 0.5, 0), size_of.call(top - y0 - rail, 0.012), WALL_IN)
		mb.box_at(&"paint_in", at + n * 0.012 + Vector3(0, y0 + rail, 0), size_of.call(0.04, 0.03), WAINSCOT.darkened(0.25))
		mb.box_at(&"paint_in", at + n * 0.008 + Vector3(0, y0 + 0.06, 0), size_of.call(0.1, 0.02), Color(0.32, 0.34, 0.33))
	# The front wall over and under its openings, inside.
	var wx := rect.end.x - WIN_AT
	var front := Vector3(0, 0, iz0 + 0.012)
	mb.box_at(&"paint_in", front + Vector3(wx, y0 + WIN_SILL * 0.5, 0), Vector3(WIN_W, WIN_SILL, 0.012), WAINSCOT)
	mb.box_at(&"paint_in", front + Vector3(wx, y0 + WIN_SILL, 0.02), Vector3(WIN_W + 0.1, 0.03, 0.06), Color(0.86, 0.86, 0.84))
	mb.box_at(&"plaster_in", front + Vector3(wx, (y0 + WIN_TOP + top) * 0.5, 0), Vector3(WIN_W, top - y0 - WIN_TOP, 0.012), WALL_IN)
	var dxf := rect.end.x - DOOR_AT
	mb.box_at(&"plaster_in", front + Vector3(dxf, (y0 + DOOR_TOP + top) * 0.5, 0), Vector3(DOOR_W, top - y0 - DOOR_TOP, 0.012), WALL_IN)


## The waiting room: three linked chairs against the west wall under two posters, a
## coffee table with magazines, a rubber plant in the window's corner, the water cooler
## and a coat stand by the door, the vaccination chart and a poster on the east wall, a
## poster in the window for the street, the "open" / "closed" sign hung in the window.
func _waiting_room(mb: MeshBuilder, cols: Array) -> void:
	var ix0 := rect.position.x + WALL
	var ix1 := rect.end.x - WALL
	var iz0 := rect.position.y + WALL
	var y0 := floor_y + 0.024
	# Chairs: grey shells on a steel beam with two legs, facing east.
	var beam := Vector3(ix0 + 0.33, y0, iz0 + 1.75)
	var frame := Color(0.2, 0.21, 0.22)
	mb.box_at(&"metal", beam + Vector3(0, 0.38, 0), Vector3(0.06, 0.05, 1.86), frame)
	for sz: float in [-0.75, 0.75]:
		mb.box_at(&"metal", beam + Vector3(0, 0.19, sz), Vector3(0.05, 0.38, 0.05), frame)
		mb.box_at(&"metal", beam + Vector3(0.0, 0.012, sz), Vector3(0.5, 0.025, 0.06), frame)
	for k in 3:
		var c := beam + Vector3(0.0, 0.0, (k - 1) * 0.6)
		var shell := Color(0.32, 0.4, 0.42)
		mb.box_at(&"cloth", c + Vector3(0.02, 0.44, 0), Vector3(0.44, 0.05, 0.5), shell)
		mb.box(&"cloth", Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-8.0)), c + Vector3(-0.2, 0.72, 0)), Vector3(0.04, 0.5, 0.48), shell)
	cols.append([beam + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 1.86), 0.0])
	# The posters over them.
	_print(mb, "poster_rabies", Vector3(ix0 + 0.03, floor_y + 1.72, iz0 + 1.35), Vector3.RIGHT, Vector2(0.5, 0.75))
	_print(mb, "poster_parasite", Vector3(ix0 + 0.03, floor_y + 1.72, iz0 + 2.15), Vector3.RIGHT, Vector2(0.5, 0.75))
	# A low table with magazines at the chairs' end; a rubber plant in the window's corner.
	var table := Vector3(ix0 + 0.4, y0, iz0 + 3.0)
	mb.box_at(&"wood_in", table + Vector3(0, 0.42, 0), Vector3(0.55, 0.03, 0.55), Color(0.5, 0.38, 0.26))
	for sx: float in [-0.23, 0.23]:
		for sz: float in [-0.23, 0.23]:
			mb.box_at(&"metal", table + Vector3(sx, 0.2, sz), Vector3(0.03, 0.4, 0.03), frame)
	for k in 3:
		var tint: Color = [Color(0.8, 0.3, 0.25), Color(0.25, 0.45, 0.7), Color(0.9, 0.85, 0.7)][k]
		mb.box_at(&"paper", table + Vector3(-0.05 + k * 0.06, 0.44 + k * 0.006, -0.06 + k * 0.08), Vector3(0.21, 0.006, 0.28), tint, Vector3(0, k * 17.0 - 10.0, 0))
	cols.append([table + Vector3(0, 0.22, 0), Vector3(0.55, 0.44, 0.55), 0.0])
	var plant := Vector3(ix0 + 0.35, y0, iz0 + 0.4)
	_rubber_plant(mb, plant)
	cols.append([plant + Vector3(0, 0.3, 0), Vector3(0.4, 0.6, 0.4), 0.0])
	# Water cooler and coat stand east of the door.
	var cooler := Vector3(ix1 - 0.25, y0, iz0 + 1.55)
	mb.box_at(&"paint_in", cooler + Vector3(0, 0.5, 0), Vector3(0.32, 1.0, 0.32), Color(0.9, 0.9, 0.88))
	mb.cylinder(&"glass", Transform3D(Basis(), cooler + Vector3(0, 1.0, 0)), 0.14, 0.14, 0.42, 14, Color.WHITE)
	mb.cylinder(&"water_still", Transform3D(Basis(), cooler + Vector3(0, 1.02, 0)), 0.13, 0.13, 0.3, 14, Color(0.55, 0.7, 0.8))
	mb.box_at(&"metal", cooler + Vector3(-0.17, 0.82, -0.06), Vector3(0.03, 0.05, 0.03), Color(0.2, 0.4, 0.8))
	mb.box_at(&"metal", cooler + Vector3(-0.17, 0.82, 0.06), Vector3(0.03, 0.05, 0.03), Color(0.8, 0.2, 0.2))
	cols.append([cooler + Vector3(0, 0.7, 0), Vector3(0.34, 1.4, 0.34), 0.0])
	var stand := Vector3(ix1 - 0.3, y0, iz0 + 0.6)
	mb.cylinder(&"metal", Transform3D(Basis(), stand), 0.2, 0.2, 0.02, 12, frame)
	mb.cylinder(&"metal", Transform3D(Basis(), stand), 0.018, 0.018, 1.75, 6, frame)
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		town._fine.cylinder_between(&"metal", stand + Vector3(0, 1.62, 0), stand + Vector3(cos(a) * 0.14, 1.7, sin(a) * 0.14), 0.01, 0.01, 4, frame)
	mb.box_at(&"cloth", stand + Vector3(0.06, 1.3, 0.05), Vector3(0.12, 0.62, 0.36), Color(0.35, 0.3, 0.22), Vector3(0, 30, 4))
	# On the east wall: the vaccination chart and the herd's poster.
	_print(mb, "chart", Vector3(ix1 - 0.03, floor_y + 1.6, iz0 + 2.7), Vector3.LEFT, Vector2(0.6, 0.6))
	_print(mb, "poster_farm", Vector3(ix1 - 0.03, floor_y + 1.72, iz0 + 3.5), Vector3.LEFT, Vector2(0.5, 0.75))
	# For the street: a poster in the window, the hanging sign by the door (see _process).
	var gz := rect.position.y + WALL * 0.5 + 0.03
	var wx := rect.end.x - WIN_AT
	_print(mb, "poster_care", Vector3(wx - WIN_W * 0.5 + 0.55, floor_y + 1.55, gz), Vector3.FORWARD, Vector2(0.5, 0.75))
	_print(mb, "poster_care", Vector3(wx - WIN_W * 0.5 + 0.55, floor_y + 1.55, gz + 0.004), Vector3.BACK, Vector2(0.5, 0.75), &"t_vet_print", Color(0.5, 0.5, 0.5))
	var hang := Vector3(wx + WIN_W * 0.5 - 0.45, floor_y + 1.78, gz + 0.02)
	for sx: float in [-0.11, 0.11]:
		town._fine.cylinder_between(&"cloth", hang + Vector3(sx, 0.07, 0), hang + Vector3(0, 0.32, 0), 0.003, 0.003, 3, Color(0.2, 0.2, 0.2))
	mb.box_at(&"metal", hang + Vector3(0, 0.33, 0), Vector3(0.02, 0.02, 0.02), frame)
	for key: String in ["open", "closed"]:
		var smb := MeshBuilder.new()
		_print(smb, key, hang, Vector3.FORWARD, Vector2(0.34, 0.17))
		_print(smb, key, hang + Vector3(0, 0, 0.006), Vector3.BACK, Vector2(0.34, 0.17))
		var mi := MeshInstance3D.new()
		mi.name = "VetSign_" + key
		mi.mesh = smb.build(Town._materials())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 60.0
		add_child(mi)
		if key == "open":
			_open_sign = mi
		else:
			_closed_sign = mi
	# The dog scale at the counter's west end: a ribbed platform, the readout on a post.
	var scale := Vector3(rect.position.x + COUNTER_X.x - 1.1, y0, rect.position.y + COUNTER_Z + 0.65)
	mb.box_at(&"metal", scale + Vector3(0, 0.035, 0), Vector3(0.95, 0.07, 0.6), Color(0.3, 0.31, 0.32))
	mb.box_at(&"cloth", scale + Vector3(0, 0.072, 0), Vector3(0.88, 0.006, 0.53), Color(0.12, 0.12, 0.12))
	for k in 8:
		mb.box_at(&"cloth", scale + Vector3(-0.385 + k * 0.11, 0.076, 0), Vector3(0.025, 0.004, 0.5), Color(0.18, 0.18, 0.18))
	mb.box_at(&"metal", scale + Vector3(0.43, 0.5, 0.25), Vector3(0.04, 0.9, 0.04), STEEL)
	var head := scale + Vector3(0.43, 0.98, 0.25)
	mb.box_at(&"paint_in", head, Vector3(0.24, 0.14, 0.06), Color(0.9, 0.9, 0.88), Vector3(-25, 0, 0))
	_print(mb, "scale", head + Basis.from_euler(Vector3(deg_to_rad(-25), 0, 0)) * Vector3(0, 0.0, -0.032), Basis.from_euler(Vector3(deg_to_rad(-25), 0, 0)) * Vector3.FORWARD,
			Vector2(0.17, 0.085), &"t_vet_screen", Color(0.75, 0.75, 0.75))
	cols.append([scale + Vector3(0, 0.035, 0), Vector3(0.95, 0.07, 0.6), 0.0])
	# Pet food on a steel shelf against the partition, west of the counter.
	var shelf := Vector3(ix0 + 1.25, y0, rect.position.y + PART_Z - 0.21)
	mb.box_at(&"metal", shelf + Vector3(0, 0.9, 0.19), Vector3(2.0, 1.8, 0.02), Color(0.7, 0.71, 0.72))
	for sx: float in [-0.99, 0.99]:
		mb.box_at(&"metal", shelf + Vector3(sx, 0.9, 0), Vector3(0.03, 1.8, 0.4), Color(0.6, 0.61, 0.62))
	var bags := ["bag_dog", "bag_cat", "bag_puppy", "bag_feed"]
	for level in 4:
		var ly := 0.12 + level * 0.46
		mb.box_at(&"metal", shelf + Vector3(0, ly, 0), Vector3(1.98, 0.025, 0.4), Color(0.74, 0.75, 0.76))
		var n := 4 if level < 3 else 6
		for k in n:
			var bx := -0.75 + k * (1.5 / (n - 1))
			var region: String = bags[(level + k) % bags.size()]
			var bh := 0.36 if level < 2 else 0.26
			var bw := 0.28 if level < 3 else 0.2
			var bc := shelf + Vector3(bx, ly + 0.0125 + bh * 0.5, -0.02)
			var col := Color(0.85, 0.85, 0.85)
			mb.box_at(&"paper", bc + Vector3(0, 0, 0.04), Vector3(bw, bh, 0.14), _bag_tint(region))
			_print(mb, region, bc + Vector3(0, 0, -0.031), Vector3.FORWARD, Vector2(bw, bh), &"t_vet_print", col)
	cols.append([shelf + Vector3(0, 0.9, 0), Vector3(2.0, 1.8, 0.42), 0.0])


## A rubber plant in a grey ceramic pot standing on the floor at `base`: three canes,
## the big glossy leaves along them turning up toward the tips.
func _rubber_plant(mb: MeshBuilder, base: Vector3) -> void:
	mb.cylinder(&"clay", Transform3D(Basis(), base), 0.17, 0.21, 0.4, 16, Color(0.27, 0.27, 0.28))
	mb.cylinder(&"veg", Transform3D(Basis(), base + Vector3(0, 0.37, 0)), 0.19, 0.19, 0.02, 12, Color(0.2, 0.15, 0.1))
	var soil := base + Vector3(0, 0.38, 0)
	for s in 3:
		var lean := Vector3(cos(s * 2.1) * 0.13, 1.0, sin(s * 2.1) * 0.13).normalized()
		var h := 0.75 + s * 0.22
		mb.cylinder_between(&"wood", soil, soil + lean * h, 0.013, 0.008, 5, Color(0.36, 0.3, 0.22))
		var n := 8 + s * 2
		for i in n:
			var t := 0.3 + 0.7 * float(i) / (n - 1)
			var ang := i * 2.4 + s * 1.3
			var out := Vector3(cos(ang), 0.0, sin(ang))
			var dir := (out * (0.9 - 0.4 * t) + Vector3(0, 0.25 + 0.6 * t, 0)).normalized()
			var side := dir.cross(Vector3.UP).normalized()
			var length := lerpf(0.27, 0.16, t)
			var shade := 0.85 + 0.15 * sin(i * 1.7 + s)
			mb.leaf(&"veg_gloss", soil + lean * h * t, dir, side.cross(dir), length, length * 0.48,
					Color(0.1, 0.24, 0.11) * shade, Color(0.14, 0.3, 0.13) * shade, 0.03, true)


## A bag's own colour round its printed front (the sides and the back).
static func _bag_tint(region: String) -> Color:
	match region:
		"bag_dog":
			return Color(0.66, 0.16, 0.14)
		"bag_cat":
			return Color(0.4, 0.24, 0.52)
		"bag_puppy":
			return Color(0.18, 0.42, 0.66)
	return Color(0.24, 0.46, 0.24)


## The reception counter: white laminate with a green band and the badge on its front, a
## raised ledge for the customers (a bowl of treats, leaflets, a bell), the work top
## behind it (her clipboard, the monitor and keyboard, a pen pot), closed off at its
## east end by a low gate; the service point on it.
func _counter(mb: MeshBuilder, cols: Array) -> void:
	var cx0 := rect.position.x + COUNTER_X.x
	var cx1 := rect.position.x + COUNTER_X.y
	var cz := rect.position.y + COUNTER_Z
	var y0 := floor_y + 0.024
	var mid := (cx0 + cx1) * 0.5
	var length := cx1 - cx0
	# The body (customer face at cz) and the plinth.
	mb.box_at(&"paint_in", Vector3(mid, y0 + 0.55, cz + COUNTER_D * 0.5), Vector3(length, 1.1, COUNTER_D), LAMINATE)
	mb.box_at(&"paint_in", Vector3(mid, y0 + 0.05, cz + 0.06), Vector3(length - 0.02, 0.1, 0.02), Color(0.3, 0.32, 0.31))
	mb.box_at(&"paint_in", Vector3(mid, y0 + 0.8, cz - 0.004), Vector3(length, 0.12, 0.01), GREEN)
	# The front's laminate in four panels (their joints), an aluminium edge under the ledge.
	for k in range(1, 4):
		mb.box_at(&"paint_in", Vector3(cx0 + length * k / 4.0, y0 + 0.6, cz - 0.006), Vector3(0.006, 0.98, 0.006), LAMINATE.darkened(0.3))
	mb.box_at(&"metal", Vector3(mid, y0 + 1.105, cz - 0.006), Vector3(length, 0.02, 0.014), Color(0.7, 0.71, 0.72))
	_print(mb, "logo", Vector3(cx0 + length * 0.375, y0 + 0.48, cz - 0.008), Vector3.FORWARD, Vector2(0.42, 0.42))
	# The ledge on the customer side and the lower work top behind it.
	mb.box_at(&"wood_in", Vector3(mid, y0 + 1.14, cz + 0.11), Vector3(length + 0.06, 0.04, 0.3), Color(0.55, 0.43, 0.3))
	mb.box_at(&"paint_in", Vector3(mid, y0 + COUNTER_H - 0.02, cz + 0.42), Vector3(length, 0.04, 0.46), Color(0.92, 0.92, 0.9))
	cols.append([Vector3(mid, y0 + 0.58, cz + COUNTER_D * 0.5), Vector3(length, 1.16, COUNTER_D), 0.0])
	# On the ledge: a bowl of dog treats, a stand of leaflets, a bell.
	mb.cylinder(&"clay", Transform3D(Basis(), Vector3(mid + 1.4, y0 + 1.16, cz + 0.1)), 0.09, 0.11, 0.07, 14, Color(0.9, 0.88, 0.82))
	for k in 6:
		mb.sphere(&"veg", Transform3D(Basis(), Vector3(mid + 1.4 + cos(k * 1.1) * 0.05, y0 + 1.225, cz + 0.1 + sin(k * 1.1) * 0.05)),
				Vector3(0.028, 0.012, 0.018), 6, 3, Color(0.5, 0.32, 0.18))
	var stand := Vector3(mid - 0.3, y0 + 1.16, cz + 0.12)
	mb.box_at(&"glass", stand + Vector3(0, 0.1, 0), Vector3(0.24, 0.2, 0.08), Color.WHITE)
	for k in 2:
		_print(mb, ["poster_rabies", "poster_parasite"][k], stand + Vector3(-0.055 + k * 0.11, 0.12, -0.01 + k * 0.012), Vector3.FORWARD, Vector2(0.1, 0.15))
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(mid + 0.8, y0 + 1.16, cz + 0.12)), 0.035, 0.035, 0.012, 10, Color(0.18, 0.18, 0.19))
	mb.sphere(&"metal", Transform3D(Basis(), Vector3(mid + 0.8, y0 + 1.19, cz + 0.12)), Vector3(0.03, 0.025, 0.03), 10, 5, Color(0.8, 0.66, 0.3))
	# The work top: her clipboard where she writes (see vet_spot, Townsperson WRITE), the
	# monitor and keyboard on her right, a pen pot and a stack of files.
	var v := vet_spot()
	var top := y0 + COUNTER_H
	var back := cz + COUNTER_D
	var board := Vector3(v.x - 0.03, top + 0.004, back - 0.17)
	mb.box_at(&"wood_in", board, Vector3(0.23, 0.008, 0.3), Color(0.48, 0.36, 0.24), Vector3(0, 8, 0))
	mb.box_at(&"paper", board + Vector3(0, 0.006, 0.01), Vector3(0.2, 0.003, 0.25), Color(0.95, 0.95, 0.93), Vector3(0, 8, 0))
	mb.box_at(&"metal", board + Vector3(0.0, 0.012, -0.125), Vector3(0.09, 0.012, 0.03), STEEL, Vector3(0, 8, 0))
	var mon := Vector3(v.x + 0.85, top, back - 0.14)
	mb.box_at(&"metal", mon + Vector3(0, 0.01, 0), Vector3(0.22, 0.02, 0.16), Color(0.1, 0.1, 0.11))
	mb.box_at(&"metal", mon + Vector3(0, 0.13, -0.03), Vector3(0.05, 0.24, 0.03), Color(0.1, 0.1, 0.11))
	var screen := mon + Vector3(0, 0.33, -0.05)
	var yaw := deg_to_rad(-15.0)
	var sb := Basis(Vector3.UP, yaw)
	mb.box(&"metal", Transform3D(sb, screen), Vector3(0.56, 0.34, 0.035), Color(0.08, 0.08, 0.09))
	_print(mb, "screen", screen + sb * Vector3(0, 0, 0.019), sb * Vector3.BACK, Vector2(0.52, 0.3), &"t_vet_screen", Color(0.8, 0.8, 0.8))
	mb.box_at(&"metal", Vector3(v.x + 0.55, top + 0.012, back - 0.1), Vector3(0.42, 0.02, 0.13), Color(0.14, 0.14, 0.15), Vector3(0, -12, 0))
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(v.x - 0.55, top, back - 0.22)), 0.04, 0.04, 0.1, 10, Color(0.2, 0.3, 0.4))
	for k in 3:
		town._fine.cylinder_between(&"metal", Vector3(v.x - 0.55 + (k - 1) * 0.012, top + 0.05, back - 0.22),
				Vector3(v.x - 0.55 + (k - 1) * 0.03, top + 0.17, back - 0.22 + (k - 1) * 0.01), 0.004, 0.004, 4, [Color(0.1, 0.2, 0.7), Color(0.8, 0.1, 0.1), Color(0.1, 0.1, 0.1)][k])
	for k in 4:
		mb.box_at(&"paper", Vector3(v.x - 1.15, top + 0.012 + k * 0.022, back - 0.2), Vector3(0.24, 0.02, 0.3),
				[Color(0.9, 0.75, 0.3), Color(0.35, 0.55, 0.8), Color(0.85, 0.4, 0.35), Color(0.6, 0.75, 0.5)][k], Vector3(0, k * 4.0 - 6.0, 0))
	# The gate between the counter and the east wall (staff only).
	var gx0 := cx1
	var gx1 := rect.end.x - WALL
	var gate := Vector3((gx0 + gx1) * 0.5, y0, cz + 0.3)
	mb.box_at(&"paint_in", gate + Vector3(0, 0.5, 0), Vector3(gx1 - gx0 - 0.04, 0.88, 0.04), LAMINATE)
	mb.box_at(&"wood_in", gate + Vector3(0, 0.96, 0), Vector3(gx1 - gx0, 0.04, 0.08), Color(0.55, 0.43, 0.3))
	cols.append([gate + Vector3(0, 0.5, 0), Vector3(gx1 - gx0, 1.0, 0.1), 0.0])
	# The west end of the staff's space: a side panel from the counter to the partition.
	var pz := rect.position.y + PART_Z
	var side := Vector3(cx0 + 0.02, y0, (cz + COUNTER_D + pz) * 0.5)
	mb.box_at(&"paint_in", side + Vector3(0, 0.55, 0), Vector3(0.04, 1.1, pz - cz - COUNTER_D), LAMINATE)
	cols.append([side + Vector3(0, 0.55, 0), Vector3(0.06, 1.1, pz - cz - COUNTER_D), 0.0])
	# The service point (E opens the vet screen) over the work top.
	counter = Point.new()
	counter.clinic = self
	counter.prompt_key = "ACTION_VET"
	counter.size = Vector3(length, 1.2, COUNTER_D + 0.1)
	counter.position = Vector3(mid, y0 + 0.6, cz + COUNTER_D * 0.5)
	add_child(counter)


## Behind the counter, against the partition: the medicine cabinet (glass doors, boxes
## and bottles), her diploma and the clock over the treatment room's door.
func _behind_counter(mb: MeshBuilder, cols: Array) -> void:
	var pz := rect.position.y + PART_Z
	var y0 := floor_y + 0.024
	var cab := Vector3(rect.position.x + 7.6, y0, pz - 0.19)
	var w := 1.6
	mb.box_at(&"paint_in", cab + Vector3(0, 0.45, 0), Vector3(w, 0.9, 0.38), LAMINATE)
	mb.box_at(&"wood_in", cab + Vector3(0, 0.915, 0), Vector3(w + 0.04, 0.03, 0.42), Color(0.55, 0.43, 0.3))
	for k in 3:
		mb.box_at(&"paint_in", cab + Vector3(-w * 0.5 + w * (k + 0.5) / 3.0, 0.45, -0.192), Vector3(w / 3.0 - 0.02, 0.84, 0.01), LAMINATE.darkened(0.04))
		mb.box_at(&"metal", cab + Vector3(-w * 0.5 + w * (k + 0.5) / 3.0, 0.78, -0.2), Vector3(0.12, 0.012, 0.02), STEEL)
	# The glass-fronted upper cabinet with the medicines.
	var up := cab + Vector3(0, 1.25, 0.06)
	var case_col := Color(0.9, 0.9, 0.88)
	mb.box_at(&"paint_in", up + Vector3(0, 0.45, 0.12), Vector3(w, 0.9, 0.02), case_col)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"paint_in", up + Vector3(sx * (w * 0.5 - 0.01), 0.45, 0), Vector3(0.02, 0.9, 0.26), case_col)
	for y: float in [0.01, 0.89]:
		mb.box_at(&"paint_in", up + Vector3(0, y, 0), Vector3(w, 0.02, 0.26), case_col)
	for level in 2:
		var ly := up.y + 0.1 + level * 0.42
		mb.box_at(&"paint_in", Vector3(up.x, ly - 0.012, up.z - 0.01), Vector3(w - 0.04, 0.012, 0.22), Color(0.86, 0.86, 0.84))
		for k in 9:
			var bx := up.x - w * 0.5 + 0.13 + k * 0.168
			if (k + level) % 3 == 2:
				mb.cylinder(&"glass", Transform3D(Basis(), Vector3(bx, ly, up.z - 0.04)), 0.035, 0.035, 0.13, 10, Color.WHITE)
				mb.cylinder(&"paint_in", Transform3D(Basis(), Vector3(bx, ly + 0.13, up.z - 0.04)), 0.02, 0.02, 0.03, 8, Color(0.2, 0.35, 0.6))
			else:
				var bc := Vector3(bx, ly + 0.07, up.z - 0.04)
				var region_col: Color = [Color(0.92, 0.92, 0.9), Color(0.82, 0.88, 0.94), Color(0.94, 0.88, 0.78), Color(0.86, 0.93, 0.85)][(k + level) % 4]
				mb.box_at(&"paper", bc, Vector3(0.12, 0.14, 0.09), region_col)
				var r: Rect2 = PRINT["box_meds"]
				var cell := (k + level) % 4
				var uv0 := r.position + Vector2((cell % 2) * r.size.x * 0.5, (cell / 2) * r.size.y * 0.5)
				var uv1 := uv0 + r.size * 0.5
				var f := Vector3(bc.x, bc.y, bc.z - 0.046)
				mb.quad(&"t_vet_print", f + Vector3(-0.06, -0.07, 0), f + Vector3(0.06, -0.07, 0), f + Vector3(0.06, 0.07, 0), f + Vector3(-0.06, 0.07, 0),
						Color(0.86, 0.86, 0.86), Vector2(uv0.x, uv1.y), uv1, Vector2(uv1.x, uv0.y), uv0)
	town._glass("VetGlass").box_at(&"t_showroom_glass", up + Vector3(0, 0.45, -0.135), Vector3(w - 0.04, 0.86, 0.01), Color.WHITE)
	mb.box_at(&"metal", up + Vector3(0, 0.45, -0.14), Vector3(0.02, 0.86, 0.015), STEEL)
	cols.append([cab + Vector3(0, 0.45, 0), Vector3(w, 0.9, 0.4), 0.0])
	# Her diploma in a frame west of the door, the clock over the door.
	var dip := Vector3(rect.position.x + COUNTER_X.x + 0.55, floor_y + 1.75, pz - 0.015)
	mb.box_at(&"wood_in", dip, Vector3(0.6, 0.34, 0.02), Color(0.3, 0.22, 0.14))
	_print(mb, "diploma", dip + Vector3(0, 0, -0.012), Vector3.FORWARD, Vector2(0.54, 0.27))
	_print(mb, "clock", Vector3(rect.position.x + ROOM_DOOR_X, floor_y + 2.55, pz - 0.018), Vector3.FORWARD, Vector2(0.3, 0.3))
	mb.cylinder(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(rect.position.x + ROOM_DOOR_X, floor_y + 2.55, pz - 0.01)),
			0.15, 0.15, 0.015, 20, Color(0.15, 0.15, 0.15))


## The sliding front door: two clear leaves in aluminium frames that part behind the
## jambs (see _update_door), the operator box over them, a mat; shut, a box stops the way.
func _door() -> void:
	var door_x := rect.end.x - DOOR_AT
	var z := rect.position.y + WALL + 0.05
	var y0 := floor_y + 0.024
	var lw := DOOR_W * 0.5 + 0.02
	var h := DOOR_TOP - 0.02
	var alu := Color(0.7, 0.71, 0.72)
	for i in 2:
		var leaf := Node3D.new()
		leaf.name = "VetDoorLeaf%d" % i
		var lmb := MeshBuilder.new()
		var gmb := MeshBuilder.new()
		gmb.box_at(&"t_showroom_glass", Vector3(0, h * 0.5, 0), Vector3(lw - 0.08, h - 0.08, 0.012), Color.WHITE)
		for fx: float in [-1.0, 1.0]:
			lmb.box_at(&"metal", Vector3(fx * (lw * 0.5 - 0.025), h * 0.5, 0), Vector3(0.05, h, 0.045), alu)
		for fy: float in [0.03, h - 0.03]:
			lmb.box_at(&"metal", Vector3(0, fy, 0), Vector3(lw, 0.06, 0.045), alu)
		lmb.box_at(&"metal", Vector3(0, 1.05, 0), Vector3(lw - 0.1, 0.035, 0.05), alu.darkened(0.2))
		if i == 1:
			# The badge as a sticker on the glass.
			_print(lmb, "logo", Vector3(0, 1.5, -0.008), Vector3.FORWARD, Vector2(0.26, 0.26))
		for part: Array in [[lmb, false], [gmb, true]]:
			var mi := MeshInstance3D.new()
			mi.mesh = (part[0] as MeshBuilder).build(Town._materials())
			if part[1]:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			leaf.add_child(mi)
		var shut_x := door_x + (-1.0 if i == 0 else 1.0) * (lw * 0.5 - 0.01)
		_leaf_shut.append(shut_x)
		leaf.position = Vector3(shut_x, y0, z + (0.0 if i == 0 else 0.05))
		add_child(leaf)
		_leaves.append(leaf)
	var omb := MeshBuilder.new()
	omb.box_at(&"metal", Vector3(door_x, y0 + DOOR_TOP + 0.12, z + 0.04), Vector3(DOOR_W * 2.0 + 0.1, 0.22, 0.16), alu.darkened(0.1))
	omb.box_at(&"glow", Vector3(door_x, y0 + DOOR_TOP + 0.005, z + 0.04), Vector3(0.12, 0.02, 0.06), Color(0.3, 0.6, 1.0))
	omb.box_at(&"cloth", Vector3(door_x, y0 + 0.006, z + 0.75), Vector3(DOOR_W - 0.1, 0.012, 1.0), Color(0.14, 0.15, 0.15))
	var omi := MeshInstance3D.new()
	omi.name = "VetDoorTop"
	omi.mesh = omb.build(Town._materials())
	add_child(omi)
	var body := StaticBody3D.new()
	body.name = "VetDoorBody"
	_door_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(DOOR_W, DOOR_TOP, 0.12)
	_door_shape.shape = box
	_door_shape.position = Vector3(door_x, y0 + DOOR_TOP * 0.5, z + 0.02)
	body.add_child(_door_shape)
	add_child(body)
	# Shut (out of hours) the door says when the clinic opens.
	_door_point = Point.new()
	_door_point.clinic = self
	_door_point.door = true
	_door_point.size = Vector3(DOOR_W, DOOR_TOP, 0.2)
	_door_point.position = Vector3(door_x, y0 + DOOR_TOP * 0.5, rect.position.y + 0.05)
	add_child(_door_point)


## Ceiling panels (their diffusers lit while she is in) and two lights without shadows.
func _lighting(mb: MeshBuilder) -> void:
	var ceil := floor_y + HEIGHT - 0.14
	var pmb := MeshBuilder.new()
	var spots: Array[Vector2] = [Vector2(rect.position.x + 2.6, rect.position.y + 1.9), Vector2(rect.position.x + 6.4, rect.position.y + 1.9),
		Vector2(rect.position.x + 6.4, rect.position.y + COUNTER_Z + 1.0), Vector2(rect.position.x + 2.6, rect.position.y + COUNTER_Z + 1.0)]
	for s in spots:
		mb.box_at(&"paint_in", Vector3(s.x, ceil - 0.012, s.y), Vector3(0.64, 0.024, 0.64), Color(0.88, 0.88, 0.86))
		pmb.box_at(&"glow", Vector3(s.x, ceil - 0.026, s.y), Vector3(0.58, 0.006, 0.58), Color(1.0, 0.98, 0.94))
	_panels = MeshInstance3D.new()
	_panels.name = "VetPanels"
	_panels.mesh = pmb.build(Town._materials())
	_panels.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_panels)
	for s: Vector2 in [Vector2(rect.position.x + 4.5, rect.position.y + 1.9), Vector2(rect.position.x + 5.5, rect.position.y + COUNTER_Z + 1.0)]:
		var l := OmniLight3D.new()
		l.position = Vector3(s.x, ceil - 0.5, s.y)
		l.light_color = Color(1.0, 0.97, 0.92)
		l.light_energy = 1.1
		l.omni_range = 6.5
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 45.0
		l.distance_fade_length = 10.0
		add_child(l)
		_lights.append(l)


## The counter (E: the vet screen while she is in) and the shut front door (it says when
## the clinic opens): interaction boxes like the town's other services'. The counter is
## in group &"vet_counter" (the story's dot points at waypoint_point()).
class Point extends TownPoint:
	var clinic: VetClinic
	var door := false

	func _ready() -> void:
		super._ready()
		if not door:
			add_to_group(&"vet_counter")

	func interact_title() -> String:
		return tr("VET_CLINIC") if door else ""

	func interact_prompt(_player: Node) -> String:
		if door or not clinic.staffed:
			return ""
		return tr(prompt_key)

	func hint_prompt() -> String:
		if door:
			return tr("VET_CLOSED_DOOR")
		return "" if clinic.staffed else tr("VET_CLOSED")

	func interact(_player: Node) -> void:
		if door or not clinic.staffed:
			Audio.ui("error", -8.0)
			return
		Game.hud.open_vet()

	## Over the counter's work top (the waypoint dot).
	func waypoint_point() -> Vector3:
		return global_position + Vector3(0, 0.75, 0)
