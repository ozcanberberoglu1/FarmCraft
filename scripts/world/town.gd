class_name Town
extends Node3D
## The town of Yeşilova along the county road: a general market (buy seeds and raw
## materials, sell produce, also straight from a parked pickup), a filling station, the
## car dealership (Yeşilova Oto Galeri: used pickups, vans, a truck, an estate, a 4x4 and
## a tractor on the lot and in the showroom), the Animal Market (a small farm yard
## with animals of every kind on show: buy them there, hens in crates loaded into the
## pickup parked in the street), the vet clinic (Yeşilova Veteriner Kliniği, VetClinic), a
## couple of houses, pavements, street lamps and signs. Built from BuildingKit pieces.
## Also spawns Grandpa's old pickup at the farm: the town keeps every vehicle.
##
## Lived-in detail: interlocking pavers, kerbs with a gutter and drains (bevelled at the
## driveways), a wooden power line with its cables, shop awnings, roller-shutter cases,
## posters and signs printed on one atlas (art/textures/town, painted by
## make_town_textures.py), scanned clutter from Poly Haven (art/models/town) drawn as
## multimeshes, and decals for oil, patches, cracks and dirt that fade under snow.

const STREET_Z := 20.0
const WALK_N := Rect2(186, 13.3, 96, 3.2)
const WALK_S := Rect2(186, 23.5, 96, 3.2)
const MARKET := Rect2(196, -4, 20, 14)
const PARKING := Rect2(186, -2, 9.5, 15.3)
const DEALER := Rect2(232, -10, 30, 18)
const DEALER_LOT := Rect2(232, 8, 30, 5.3)
## Where the dealership shows what it sells (VehicleTable.FOR_SALE): x, z and heading
## (degrees, 90: nose east). On the lot in a row along the street, or in the showroom
## behind the glass (one on the turntable), each with its price board.
const DEALER_SPOTS := {
	&"pickup_stake": Vector3(236.3, 10.65, 90.0),
	&"pickup_90": Vector3(242.3, 10.65, 90.0),
	&"pickup_box": Vector3(250.3, 10.65, 90.0),
	&"truck": Vector3(257.4, 10.65, 90.0),
	&"pickup_canopy": Vector3(237.6, 2.2, 45.0),
	&"wagon": Vector3(242.0, -2.0, 25.0),
	&"offroad": Vector3(251.2, 2.3, -45.0),
	&"tractor": Vector3(258.2, 1.4, -110.0),
}
## The dealership's turntable in the showroom (x, z, radius) and how fast it turns
## (radians a second).
const TURNTABLE := Vector3(242.0, -2.0, 3.2)
const TURN_SPEED := 0.12
## Where a vehicle bought in the showroom is brought out: the service bay's apron on
## the east side, nose to the street.
const DELIVERY := Vector3(264.4, -1.2, 0.0)
const STATION := Rect2(194, 23.5, 34, 23.5)
const CANOPY := Rect2(199, 29, 24, 10)
const KIOSK := Rect2(202, 41, 18, 7)
## The Animal Market (see _animal_market): the whole lot behind the south pavement, the
## dealer's office at its front, the lane from the gate arch down between the pens, the
## coop run (its henhouse), the hen stall at the run's fence, the hay barn at the back
## and the paddocks east of the lane, front to back (a gate onto the lane each).
const ANIMAL_MARKET := Rect2(236.6, 29.3, 31.4, 25.7)
const RANCH_OFFICE := Rect2(236.6, 30.6, 9.0, 7.0)
const MARKET_LANE := Rect2(246.4, 29.3, 5.4, 25.7)
const COOP_RUN := Rect2(236.8, 38.3, 7.8, 8.7)
const HENHOUSE := Rect2(237.3, 43.5, 2.0, 2.6)
const HEN_STALL := Rect2(244.7, 40.4, 1.6, 3.2)
## Where bought crates wait (MarketCrates): the first crate's centre (x, z), the row
## running south (+z) along the lane's west edge from just inside the gate, in front of
## the open gate leaf and short of the office hatch.
const MARKET_PICKUP := Vector2(246.82, 30.2)
const HAY_BARN := Rect2(236.8, 47.6, 9.0, 7.0)
const HORSE_PADDOCK := Rect2(252.0, 29.8, 16.0, 8.2)
const COW_PADDOCK := Rect2(252.0, 38.0, 16.0, 8.4)
const SHEEP_PEN := Rect2(252.0, 46.4, 16.0, 8.6)
const PEN_GATE := 2.4
## Which paddock shows which kind (the coop's kinds live in the run).
const MARKET_PENS := {&"horse": HORSE_PADDOCK, &"cow": COW_PADDOCK, &"sheep": SHEEP_PEN}
## The general market's side yard, between its east wall and the dealership (where its
## poultry stall stood before the Animal Market took the hens).
const MARKET_SIDE_YARD := Rect2(216.6, 7.4, 7.6, 5.9)
## The vet clinic (VetClinic): its building behind the south pavement's west end, between
## the town sign and the filling station, its paved yard in front.
const VET := Rect2(180.6, 29.8, 10.0, 9.0)
## The market's paved forecourt runs from x to x between its front wall and the pavement.
const FORECOURT_X := Vector2(196.0, 216.0)
## Fuel price per litre, in dollars.
const FUEL_PRICE := 0.5

## Kerbs are bevelled into mountable kerbs across the driveways (x from, x to): on the
## south side the filling station's and the Animal Market lane's.
const DRIVEWAYS_N: Array[Vector2] = [Vector2(186.0, 195.5), Vector2(232.0, 262.0)]
const DRIVEWAYS_S: Array[Vector2] = [Vector2(194.0, 228.0), Vector2(246.1, 252.1)]
## Storm drains in the gutters (x) on each side of the street.
const DRAINS_N: Array[float] = [199.5, 223.0, 247.5, 270.0]
const DRAINS_S: Array[float] = [190.5, 212.5, 239.0, 268.5]
## Wooden poles of the overhead line behind the south pavement (XZ).
const POLES: Array[Vector2] = [Vector2(188.0, 27.3), Vector2(229.0, 27.3), Vector2(256.0, 27.3), Vector2(283.6, 27.3)]
const POLE_H := 8.6
## The zebra crossing (its centre along the street) and the bus stop behind the south pavement.
const CROSSING_X := 230.2
const BUS_STOP := Vector2(234.0, 27.85)
const KERB := Color(0.5, 0.5, 0.48)
const GUTTER := Color(0.45, 0.45, 0.43)
## Tint of the (beige, fairly light) paver photo: textured.gdshader multiplies by
## twice the tint's gamma value, so this darkens it by about (0.8, 0.85, 0.95). The
## material's weathering then bleaches most of the beige out in patches (see
## _materials), for the mid grey of worn concrete pavers, a shade darker than the
## plain concrete slabs the town had before.
const PAVER := Color(0.133, 0.152, 0.194)
const POLE_WOOD := Color(0.34, 0.29, 0.24)
const CABLE := Color(0.05, 0.05, 0.05)
const IRON := Color(0.1, 0.1, 0.11)
const GALV := Color(0.55, 0.56, 0.56)
const DECAL := "res://art/textures/town/decal_%s.png"
const SCAN := "res://art/models/town/%s/%s_1k.gltf"
## Scanned clutter (see art/models/town/CREDITS.md): [draw distance, casts a shadow,
## LOD bias (below 1 switches to the lighter LODs sooner)]. What stands in a cage, on
## a pallet, a plinth or at a table stays as long as its host (the town mesh) reads,
## about the length of the street; the imported LODs keep far instances cheap. Only
## loose litter and the flat manhole covers go sooner.
const SCAN_LOOK := {
	"water_manhole_cover": [70.0, false, 0.4],
	"utility_box_02": [130.0, true, 0.8],
	"barrel_03": [110.0, true, 0.8],
	"propane_tank": [120.0, false, 0.5],
	"old_tyre": [110.0, true, 0.7],
	"cement_bag": [120.0, true, 0.6],
	"plastic_monobloc_chair_01": [110.0, true, 0.9],
	"trashbag": [60.0, false, 0.8],
	"planter_pot_clay": [110.0, false, 0.7],
}
## Size of the patches the clutter is drawn in (see _build_props).
const PROP_CELL := 32.0
## Share of the clutter draw distance each graphics preset keeps (LOW..ULTRA); LOW also
## drops the decals.
const DETAIL_RANGE: Array[float] = [0.75, 0.85, 1.0, 1.0]
## Render layer of the scanned clutter ("small clutter", kept out of the rain height
## map), which the decals leave out so a stain under a drum doesn't paint its foot.
const CLUTTER_LAYER := 2
## Regions of art/textures/town/town_print_albedo.png (printed by make_town_textures.py).
const PRINT := {
	"flag_tr": Rect2(0, 0, 0.375, 0.25),
	"banner": Rect2(0.375, 0, 0.625, 0.15625),
	"plate_ataturk": Rect2(0.375, 0.15625, 0.3125, 0.09375),
	"plate_carsi": Rect2(0.6875, 0.15625, 0.3125, 0.09375),
	"feather_blue": Rect2(0, 0.25, 0.125, 0.5),
	"feather_red": Rect2(0.125, 0.25, 0.125, 0.5),
	"sign_crossing": Rect2(0.25, 0.25, 0.125, 0.125),
	"sign_50": Rect2(0.375, 0.25, 0.125, 0.125),
	"sign_parking": Rect2(0.5, 0.25, 0.125, 0.125),
	"sign_bus": Rect2(0.625, 0.25, 0.125, 0.125),
	"open": Rect2(0.75, 0.25, 0.25, 0.125),
	"poster_sale": Rect2(0.25, 0.375, 0.25, 0.375),
	"poster_fresh": Rect2(0.5, 0.375, 0.25, 0.375),
	"poster_bread": Rect2(0.75, 0.375, 0.25, 0.25),
	"poster_oil": Rect2(0.75, 0.625, 0.25, 0.375),
	"poster_ice": Rect2(0, 0.75, 0.25, 0.25),
	"hours": Rect2(0.25, 0.75, 0.25, 0.125),
	"lpg": Rect2(0.25, 0.875, 0.25, 0.125),
	"timetable": Rect2(0.5, 0.75, 0.25, 0.25),
}

var market_counter: Node3D
## The Animal Market's hen stall counter (E buys crated hens); `poultry_marker` floats
## over it for the story's waypoint ("town_chickens").
var poultry_stall: Node3D
var poultry_marker: Marker3D
## The Animal Market: its office hatch, the pens' gates (species -> TownPoint), the
## animals on show, and the spots in each pen the animals keep out of (species, or
## &"coop" for the run -> [Rect2]).
var market_office: Node3D
var market_pens := {}
## The pickup spot inside the gate where the crates bought here wait (LiveCrates).
var market_crates: MarketCrates
var herd: MarketHerd
## The vet clinic, its counter and its vet.
var vet_clinic: VetClinic
var market_avoid := {}
var pumps: Array[Node3D] = []
## The dealer's pickup on the lot (the Lightbody '90), and everything the dealership
## sells (VehicleTable.FOR_SALE order), bought or not.
var for_sale: Vehicle
var dealer_stock: Array[Vehicle] = []
## The showroom's spot lights over the cars (they cast shadows on High and Ultra).
var _showroom_spots: Array[SpotLight3D] = []
## The turntable's deck and the car for sale on it, which turns with it once it has
## settled on its wheels (see _turn_showroom).
var _deck: MeshInstance3D
var _turn_vehicle: Vehicle
var _turn_settle := 2.0
## Grandpa's old pickup: the player's from the first day, parked by the farm warehouse.
var farm_truck: Vehicle
var _lamps: Array[Light3D] = []
## Crates of goods on display: "item:variant:shadow" -> [Transform3D]. Drawn as
## multimeshes that only show up close, not baked into the town mesh.
var _goods := {}
## Scanned clutter to draw: model name -> [Transform3D] (see SCAN_LOOK).
var _props := {}
var _prop_nodes: Array[MultiMeshInstance3D] = []
var _decals: Array[Decal] = []
## Cables, strings and wires (see _cable), drawn without shadows.
var _wires := MeshBuilder.new()
var _wires_mi: MeshInstance3D
## Parts only a few centimetres thick (pennants, spokes, bars, bottles), also drawn
## without shadows: a shadow map breaks them into stipple on the walls behind.
var _fine := MeshBuilder.new()
## Glass set in front of the buildings, one small mesh per group (see _glass) so it
## sorts against vehicle glass and rain on its own.
var _glass_parts := {}
## The washing on the line (see _house_details): taken in when it rains or snows.
var _wash: MeshInstance3D
## Wall brackets the service drops of the houses end on (see _power_line).
var _house_drops: Array[Vector3] = []
var _lit := false
## Snow cover and wetness the decals were last shaded for (see _refresh_decals).
var _snow_seen := 0.0
var _wet_seen := 0.0

static var _mats := {}
static var _decal_tex := {}
static var _scans := {}


func _ready() -> void:
	add_to_group(&"town")
	var mb := MeshBuilder.new()
	var cols := []
	_pavements(mb, cols)
	_market(mb, cols)
	_market_side_yard(mb, cols)
	_dealer(mb, cols)
	_station(mb, cols)
	_animal_market(cols)
	_houses(mb, cols)
	vet_clinic = VetClinic.new()
	add_child(vet_clinic)
	vet_clinic.build(self, mb, cols)
	_lamps_and_signs(mb, cols)
	_power_line(mb, cols)
	_street_furniture(mb, cols)
	_road_marks()
	var mi := MeshInstance3D.new()
	mi.name = "TownMesh"
	mi.mesh = mb.build(_materials())
	add_child(mi)
	_wires_mi = _no_shadow_mesh("TownWires", _wires, 220.0)
	_no_shadow_mesh("TownDetail", _fine, 160.0)
	for key: String in _glass_parts:
		_no_shadow_mesh(key, _glass_parts[key], 0.0)
	_build_goods()
	_build_props()
	BuildingKit.collider(self, cols)
	_trees()
	for r: Rect2 in [WALK_N, WALK_S, MARKET.grow(0.5), PARKING, DEALER.grow(0.5), DEALER_LOT, STATION,
			ANIMAL_MARKET.grow(0.3), Rect2(RANCH_OFFICE.position.x, RANCH_OFFICE.position.y - 1.9, RANCH_OFFICE.size.x, 1.9),
			Rect2(MARKET_LANE.position.x, WALK_S.end.y, MARKET_LANE.size.x, MARKET_LANE.position.y - WALK_S.end.y),
			Rect2(268, -2, 11, 10), Rect2(270, 31, 11, 11), Rect2(196, 10, 20, 3.3),
			MARKET_SIDE_YARD, KIOSK.grow(0.3), Rect2(BUS_STOP.x - 1.9, BUS_STOP.y - 1.0, 3.8, 1.9), Rect2(DEALER.end.x + 0.3, -4.5, 4.4, 6.0),
			# The garden paths from the gates to the door steps, the bales by the market office.
			Rect2(272.6, 8.0, 1.8, 4.0), Rect2(274.6, 27.0, 1.8, 4.0),
			# Karamel's doghouse and bowls in Zeynep's garden (ZeynepHome).
			Rect2(267.9, 8.6, 2.2, 1.9), Rect2(RANCH_OFFICE.position.x - 1.1, RANCH_OFFICE.position.y + 2.0, 0.9, 5.6),
			VET.grow(0.4), vet_clinic.yard_rect()]:
		Game.world.block_grass(r)
	_spawn_dealer_stock()
	_spawn_farm_truck()
	# Grandpa's stock trailer and the cargo trailer for sale, beside the dealer's lot.
	TrailerYard.spawn(self)
	# The townspeople (scripts/npc): at the counters, the pumps, the dealer's, on the pavements.
	add_child(TownPeople.new())
	# The fishing contest's pond and board (FishingContest), and its crowd.
	add_child(ContestVenue.new())
	# Carnival nights (Carnival): the town's dressing, built only on those evenings.
	add_child(TownCarnival.new())
	Settings.changed.connect(_apply_quality)
	_apply_quality()


func _physics_process(delta: float) -> void:
	_turn_showroom(delta)


func _process(_delta: float) -> void:
	var lit := DayNightCycle.night_factor > 0.45 or Weather.overcast > 0.8
	if lit != _lit:
		_lit = lit
		for l in _lamps:
			l.visible = lit
			l.light_energy = (1.6 if l is OmniLight3D else 4.5) if lit else 0.0
		BuildingKit.lamp_material().set_shader_parameter("emission_strength", 4.0 if lit else 0.0)
	if absf(Weather.snow_cover - _snow_seen) > 0.02 or absf(Weather.wetness - _wet_seen) > 0.03:
		_snow_seen = Weather.snow_cover
		_wet_seen = Weather.wetness
		_refresh_decals()
	var hang := Weather.current() not in [Weather.Kind.RAIN, Weather.Kind.STORM, Weather.Kind.SNOW] and Weather.snow_cover < 0.1
	if _wash != null and _wash.visible != hang:
		_wash.visible = hang


## Clutter draws as far as the graphics preset allows; LOW leaves out the decals and
## fades the cables sooner (without MSAA they crawl once thinner than a pixel).
func _apply_quality() -> void:
	var q: int = Settings.quality
	_refresh_decals()
	for mmi in _prop_nodes:
		mmi.visibility_range_end = float(mmi.get_meta(&"range")) * DETAIL_RANGE[q]
	_wires_mi.visibility_range_end = 120.0 if q == Settings.Quality.LOW else 220.0
	for l in _showroom_spots:
		l.shadow_enabled = q >= Settings.Quality.HIGH


## Ground decals fade out under snow (the road's own paint does too); all of them
## darken as the surfaces under them get wet (see textured.gdshader). Hidden on LOW.
func _refresh_decals() -> void:
	var on: bool = Settings.quality > Settings.Quality.LOW
	var keep := 1.0 - smoothstep(0.05, 0.5, _snow_seen)
	var dark := 1.0 - 0.3 * _wet_seen
	for d in _decals:
		var base: Color = d.get_meta(&"tint")
		var a := base.a * (1.0 if d.has_meta(&"wall") else keep)
		d.modulate = Color(base.r * dark, base.g * dark, base.b * dark, a)
		d.visible = on and a > 0.01


## A mesh from `mb` that casts no shadow and stays out of GI, fading out at `range_end`
## metres (0: always drawn).
func _no_shadow_mesh(node_name: String, mb: MeshBuilder, range_end: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mb.build(_materials())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if range_end > 0.0:
		mi.visibility_range_end = range_end
		mi.visibility_range_end_margin = 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	return mi


## The mesh builder for a group of glass panes (see _glass_parts).
func _glass(group: String) -> MeshBuilder:
	if not _glass_parts.has(group):
		_glass_parts[group] = MeshBuilder.new()
	return _glass_parts[group]


# --- Materials, decals, scanned clutter --------------------------------------------------

## Surfaces only the town uses (keys "t_*") for MeshBuilder.build: the pavers laid in
## world metres, brick and plaster splashed with dirt near the ground and streaked by
## rain, the print atlas (signs, posters, flags) and the switched lamp glow. Every
## other key comes from Mats.
static func _materials() -> Dictionary:
	if _mats.is_empty():
		_mats[&"lamp_glow"] = BuildingKit.lamp_material()
		_mats[&"t_pavers"] = _photo("patterned_concrete_pavers", {"uv_scale": 1.0 / 1.8, "ao_strength": 1.0, "weathering": 0.65})
		_mats[&"t_brick"] = _photo("red_brick_03", {"uv_scale": 0.5, "grime_top": 0.9, "weathering": 0.1})
		_mats[&"t_plaster"] = _photo("painted_plaster_wall", {"uv_scale": 0.4, "grime_top": 0.8, "weathering": 0.08})
		# The dealership's showroom windows: clean plate glass, the cars behind plain to see.
		_mats[&"t_showroom_glass"] = Mats._window_glass({"clarity": 0.9, "dirt": 0.08, "wobble": 0.0, "tint": Color(0.62, 0.68, 0.7)})
		var print_mat := StandardMaterial3D.new()
		print_mat.albedo_texture = load("res://art/textures/town/town_print_albedo.png")
		print_mat.vertex_color_use_as_albedo = true
		print_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		print_mat.alpha_scissor_threshold = 0.5
		print_mat.roughness = 0.62
		print_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[&"t_print"] = print_mat
	return _mats


static func _photo(tex: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/textured.gdshader")
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	m.set_shader_parameter("albedo_tex", Mats.texture(tex, "diff.jpg"))
	m.set_shader_parameter("normal_tex", Mats.texture(tex, "nor.jpg"))
	m.set_shader_parameter("arm_tex", Mats.texture(tex, "arm.jpg"))
	return m


## A stain, patch or marking projected straight down onto whatever lies within
## `depth` of `at` (the road, kerbs, a forecourt): `size` is its footprint along the
## decal's x and z, turned by `yaw`. Texture v runs along local +z.
func _decal(kind: String, at: Vector3, size: Vector2, yaw := 0.0, tint := Color.WHITE, depth := 0.5) -> Decal:
	var d := Decal.new()
	d.texture_albedo = _decal_texture(kind)
	if kind == "oil" or kind == "patch":
		d.texture_orm = _decal_texture(kind + "_orm")
	d.size = Vector3(size.x, depth, size.y)
	d.position = at
	d.rotation.y = yaw
	d.modulate = tint
	# The tint before weather (see _refresh_decals).
	d.set_meta(&"tint", tint)
	d.cull_mask = 0xFFFFF & ~CLUTTER_LAYER
	d.upper_fade = 0.25
	d.lower_fade = 0.25
	d.normal_fade = 0.35
	d.distance_fade_enabled = true
	d.distance_fade_begin = 55.0
	d.distance_fade_length = 15.0
	add_child(d)
	_decals.append(d)
	return d


## A decal on a wall facing `normal`: `size.x` along the wall, `size.y` down it from `top`.
func _wall_decal(kind: String, top: Vector3, normal: Vector3, size: Vector2, tint := Color.WHITE) -> Decal:
	var d := _decal(kind, top + Vector3.DOWN * size.y * 0.5, size, 0.0, tint, 0.3)
	d.basis = Basis(normal.cross(Vector3.DOWN), normal, Vector3.DOWN)
	d.normal_fade = 0.5
	# Snow doesn't settle on a wall (see _refresh_decals).
	d.set_meta(&"wall", true)
	return d


static func _decal_texture(kind: String) -> Texture2D:
	if not _decal_tex.has(kind):
		_decal_tex[kind] = load(DECAL % kind)
	return _decal_tex[kind]


## One more scanned prop to draw (SCAN_LOOK): standing on `at`, turned by `yaw`,
## scaled by `factor`, tipped by `tilt` (a tyre lying flat).
func _prop(model: String, at: Vector3, yaw := 0.0, factor := 1.0, tilt := Basis.IDENTITY) -> void:
	if not _props.has(model):
		_props[model] = []
	(_props[model] as Array).append(Transform3D(Basis(Vector3.UP, yaw) * tilt * Basis.from_scale(Vector3.ONE * factor), at))


## [transform in the model, mesh, materials, name] of every mesh in a scanned model.
static func _scan_parts(model: String) -> Array:
	if not _scans.has(model):
		_scans[model] = MeshMerge.scene_parts(load(SCAN % [model, model]) as PackedScene)
	return _scans[model]


## One multimesh per model and part for each patch of town (PROP_CELL metres), so each
## patch picks its own LOD and fades out on its own at its draw distance.
func _build_props() -> void:
	for model: String in _props:
		var look: Array = SCAN_LOOK[model]
		var cells := {}
		for xf: Transform3D in _props[model]:
			var cell := Vector2i(floori(xf.origin.x / PROP_CELL), floori(xf.origin.z / PROP_CELL))
			if not cells.has(cell):
				cells[cell] = []
			(cells[cell] as Array).append(xf)
		for cell: Vector2i in cells:
			var list: Array = cells[cell]
			for part: Array in _scan_parts(model):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = part[1]
				mm.instance_count = list.size()
				for i in list.size():
					mm.set_instance_transform(i, (list[i] as Transform3D) * (part[0] as Transform3D))
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "Props_" + model
				mmi.multimesh = mm
				var mats: Array = part[2]
				if (part[1] as Mesh).surface_get_material(0) == null and not mats.is_empty():
					mmi.material_override = mats[0]
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if look[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
				mmi.layers = CLUTTER_LAYER
				mmi.lod_bias = float(look[2])
				mmi.set_meta(&"range", float(look[0]))
				mmi.visibility_range_end = float(look[0])
				mmi.visibility_range_end_margin = 5.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				add_child(mmi)
				_prop_nodes.append(mmi)


## A piece of the print atlas (PRINT) on a quad centred on `at`, facing `normal`
## (upright), `size` in metres; `back` prints it on the reverse as well.
func _print(mb: MeshBuilder, region: String, at: Vector3, normal: Vector3, size: Vector2,
		tint := Color(0.86, 0.86, 0.86), back := false) -> void:
	var r: Rect2 = PRINT[region]
	var right := Vector3.UP.cross(normal).normalized()
	var up := normal.cross(right)
	var hx := right * size.x * 0.5
	var hy := up * size.y * 0.5
	var uv_bl := Vector2(r.position.x, r.end.y)
	var uv_br := Vector2(r.end.x, r.end.y)
	var uv_tr := Vector2(r.end.x, r.position.y)
	var uv_tl := r.position
	mb.quad(&"t_print", at - hx - hy, at + hx - hy, at + hx + hy, at - hx + hy, tint, uv_bl, uv_br, uv_tr, uv_tl)
	if back:
		mb.quad(&"t_print", at + hx - hy, at - hx - hy, at - hx + hy, at + hx + hy, tint, uv_bl, uv_br, uv_tr, uv_tl)


## Printed cloth (a flag or banner) hanging from its top corner `origin` at the pole,
## `w` along `along` (horizontal) and `h` down, rippling more toward the fly end.
## `arc` drops the top edge toward the fly (feather flags). Printed through: from
## behind it reads mirrored, like the real thing.
func _cloth(mb: MeshBuilder, region: String, origin: Vector3, along: Vector3, w: float, h: float,
		ripple: float, phase: float, arc := 0.0, tint := Color(0.88, 0.88, 0.88)) -> void:
	var r: Rect2 = PRINT[region]
	var side := along.cross(Vector3.UP).normalized()
	var nx := 6
	var ny := 3
	var grid: Array[Vector3] = []
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / ny
			var top := arc * u * u
			var y := -top - v * (h - top) - u * u * 0.05 * h * (1.0 - arc)
			grid.append(origin + along * (u * w) + Vector3(0, y, 0) + side * sin(u * 5.5 + v * 0.8 + phase) * ripple * u)
	for j in ny:
		for i in nx:
			var a := grid[(j + 1) * (nx + 1) + i]
			var b := grid[(j + 1) * (nx + 1) + i + 1]
			var c := grid[j * (nx + 1) + i + 1]
			var d := grid[j * (nx + 1) + i]
			var u0 := r.position.x + r.size.x * float(i) / nx
			var u1 := r.position.x + r.size.x * float(i + 1) / nx
			var v0 := r.position.y + r.size.y * float(j) / ny
			var v1 := r.position.y + r.size.y * float(j + 1) / ny
			mb.quad(&"t_print", a, b, c, d, tint, Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0))
			mb.quad(&"t_print", d, c, b, a, tint, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1))


# --- Ground ----------------------------------------------------------------------------

func _y(x: float, z: float) -> float:
	return TerrainData.height(x, z)


## Where the road's centreline crosses x (the town street runs along x).
static func _road_center_z(x: float) -> float:
	TerrainData.ensure()
	var best := INF
	var z := STREET_Z
	for p in TerrainData.road_points:
		if absf(p.x - x) < best:
			best = absf(p.x - x)
			z = p.y
	return z


## Height of the asphalt at (x, z): the road profile's height at the nearest point of
## its centreline plus the camber (3.5 cm at the crown, flush at the edges).
static func _road_y(x: float, z: float) -> float:
	TerrainData.ensure()
	var p := Vector2(x, z)
	var best := INF
	var h := 0.0
	for i in TerrainData.road_points.size():
		var d := p.distance_squared_to(TerrainData.road_points[i])
		if d < best:
			best = d
			h = TerrainData.road_heights[i]
	return h + 0.035 * clampf(1.0 - sqrt(best) / (WorldLayout.ROAD_WIDTH * 0.5), 0.0, 1.0)


func _pavements(mb: MeshBuilder, cols: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1907
	for r: Rect2 in [WALK_N, WALK_S]:
		var north := r == WALK_N
		var x0 := r.position.x
		while x0 < r.end.x - 0.01:
			var x1 := minf(x0 + 8.0, r.end.x)
			var seg := Rect2(x0, r.position.y, x1 - x0, r.size.y)
			var y := _y(seg.get_center().x, seg.get_center().y) + 0.15
			# Both ends too: the slabs follow the ground, so a neighbour can sit a
			# centimetre or two lower and would show a slit into this one.
			var sides := ("n" if north else "s") + "we"
			_paved(mb, cols, seg, y, 0.5, &"t_pavers", PAVER, sides, r, FORECOURT_X if north else Vector2.ZERO)
			x0 = x1
		var drives: Array[Vector2] = DRIVEWAYS_N if north else DRIVEWAYS_S
		var drains: Array[float] = DRAINS_N if north else DRAINS_S
		_kerb(mb, r, north, drives, drains)
	# The market's forecourt, paved like the pavement it meets.
	var forecourt := Rect2(FORECOURT_X.x, 10, FORECOURT_X.y - FORECOURT_X.x, WALK_N.position.y - 10.0)
	_paved(mb, cols, forecourt, _y(206, 11.5) + 0.15, 0.5, &"t_pavers", PAVER * 0.97, "swe", forecourt, Vector2.ZERO, FORECOURT_X)
	# The parking lot (its bays are painted: see _road_marks).
	BuildingKit.slab(mb, cols, PARKING, _y(191, 6) + 0.06, 0.4, &"asphalt", Color(0.46, 0.46, 0.46))
	# Concrete of the dealer's lot and the filling station, cast in bays.
	_cast_slab(mb, cols, DEALER_LOT, _y(247, 10.5) + 0.15, 0.5, Color(0.54, 0.54, 0.52), Vector2(5.0, 5.3), rng)
	_cast_slab(mb, cols, STATION, _y(211, 35) + 0.06, 0.4, Color(0.5, 0.5, 0.48), Vector2(4.25, 4.7), rng)


## A slab like BuildingKit.slab (the same collision box) whose top is laid in world
## metres, so the pavers run on seamlessly from slab to slab. `sides` lists the edges
## drawn ("n" -z, "s" +z, "w" -x, "e" +x); kerbs and walls hide the others. The top is
## cut into cells of about a metre whose corners carry the tint times _paver_shade, so
## the paving reads trodden and patchy rather than printed; `area` is the whole paved
## strip the slab belongs to: its long edges collect dirt, except along the x ranges
## `open_n` (-z edge) and `open_s` (+z edge) where the paving runs on.
func _paved(mb: MeshBuilder, cols: Array, rect: Rect2, top: float, thickness: float, key: StringName,
		color: Color, sides: String, area: Rect2, open_n := Vector2.ZERO, open_s := Vector2.ZERO) -> void:
	var nx := maxi(roundi(rect.size.x), 1)
	# Rows: half-metre bands along both edges (for the dirt there), about a metre between.
	var zs: Array[float] = [rect.position.y]
	var inner := maxi(roundi(rect.size.y - 1.1), 1)
	for j in inner + 1:
		zs.append(rect.position.y + 0.55 + (rect.size.y - 1.1) * j / inner)
	zs.append(rect.end.y)
	for i in nx:
		var xa := rect.position.x + rect.size.x * i / nx
		var xb := rect.position.x + rect.size.x * (i + 1) / nx
		for j in zs.size() - 1:
			var za := zs[j]
			var zb := zs[j + 1]
			var p: Array[Vector3] = [Vector3(xa, top, zb), Vector3(xb, top, zb), Vector3(xb, top, za), Vector3(xa, top, za)]
			var c: Array[Color] = []
			var uv: Array[Vector2] = []
			for q in p:
				var f := _paver_shade(q.x, q.z, area, open_n, open_s)
				c.append(Color(color.r * f, color.g * f, color.b * f))
				uv.append(Vector2(q.x, -q.z))
			mb.tri_n(key, p[0], p[1], p[2], Vector3.UP, Vector3.UP, Vector3.UP, c[0], c[1], c[2], uv[0], uv[1], uv[2])
			mb.tri_n(key, p[0], p[2], p[3], Vector3.UP, Vector3.UP, Vector3.UP, c[0], c[2], c[3], uv[0], uv[2], uv[3])
	_paved_sides(mb, rect, top, thickness, sides)
	cols.append([Vector3(rect.get_center().x, top - thickness * 0.5, rect.get_center().y), Vector3(rect.size.x, thickness, rect.size.y), 0.0])


## How much lighter or darker the paving is at (x, z), as a factor on its tint: broad
## blotches of wear and grime, and darker within 55 cm of `area`'s long edges, where
## dirt collects against the kerb and the building line (see _paved for `open_*`).
static func _paver_shade(x: float, z: float, area: Rect2, open_n: Vector2, open_s: Vector2) -> float:
	var n := sin(x * 0.61 + z * 1.37) * sin(x * 0.23 - z * 0.71 + 1.3) + 0.5 * sin(x * 1.9 + z * 0.4 + 0.7) * sin(z * 2.3 - x * 0.35)
	var to_n := INF if x > open_n.x and x < open_n.y else z - area.position.y
	var to_s := INF if x > open_s.x and x < open_s.y else area.end.y - z
	return (1.0 + 0.22 * n) * lerpf(0.62, 1.0, clampf(minf(to_n, to_s) / 0.55, 0.0, 1.0))


## The concrete edges of a slab (see _paved).
func _paved_sides(mb: MeshBuilder, rect: Rect2, top: float, thickness: float, sides: String) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var b := top - thickness
	var edge := Color(0.5, 0.5, 0.49)
	if "s" in sides:
		mb.quad(&"concrete", Vector3(x0, b, z1), Vector3(x1, b, z1), Vector3(x1, top, z1), Vector3(x0, top, z1), edge,
				Vector2(x0, b), Vector2(x1, b), Vector2(x1, top), Vector2(x0, top))
	if "n" in sides:
		mb.quad(&"concrete", Vector3(x1, b, z0), Vector3(x0, b, z0), Vector3(x0, top, z0), Vector3(x1, top, z0), edge,
				Vector2(x1, b), Vector2(x0, b), Vector2(x0, top), Vector2(x1, top))
	if "e" in sides:
		mb.quad(&"concrete", Vector3(x1, b, z1), Vector3(x1, b, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), edge,
				Vector2(z1, b), Vector2(z0, b), Vector2(z0, top), Vector2(z1, top))
	if "w" in sides:
		mb.quad(&"concrete", Vector3(x0, b, z0), Vector3(x0, b, z1), Vector3(x0, top, z1), Vector3(x0, top, z0), edge,
				Vector2(z0, b), Vector2(z1, b), Vector2(z1, top), Vector2(z0, top))


## A concrete apron like BuildingKit.slab (the same collision box) cast in bays of
## about `bay` metres, each a shade different, with sawn joints between them.
func _cast_slab(mb: MeshBuilder, cols: Array, rect: Rect2, top: float, thickness: float, color: Color, bay: Vector2,
		rng: RandomNumberGenerator) -> void:
	var nx := maxi(roundi(rect.size.x / bay.x), 1)
	var nz := maxi(roundi(rect.size.y / bay.y), 1)
	var dx := rect.size.x / nx
	var dz := rect.size.y / nz
	for i in nx:
		for j in nz:
			var x0 := rect.position.x + i * dx
			var x1 := x0 + dx
			var z0 := rect.position.y + j * dz
			var z1 := z0 + dz
			mb.quad(&"concrete", Vector3(x0, top, z1), Vector3(x1, top, z1), Vector3(x1, top, z0), Vector3(x0, top, z0),
					color.lightened(rng.randf_range(-0.05, 0.05)), Vector2(x0, -z1), Vector2(x1, -z1), Vector2(x1, -z0), Vector2(x0, -z0))
	var joint := Color(0.2, 0.2, 0.2)
	for i in range(1, nx):
		mb.box_at(&"concrete", Vector3(rect.position.x + i * dx, top + 0.001, rect.get_center().y), Vector3(0.022, 0.004, rect.size.y - 0.04), joint)
	for j in range(1, nz):
		mb.box_at(&"concrete", Vector3(rect.get_center().x, top + 0.001, rect.position.y + j * dz), Vector3(rect.size.x - 0.04, 0.004, 0.022), joint)
	_paved_sides(mb, rect, top, thickness, "nsew")
	cols.append([Vector3(rect.get_center().x, top - thickness * 0.5, rect.get_center().y), Vector3(rect.size.x, thickness, rect.size.y), 0.0])


## Kerb stones (a metre each) along a pavement's road edge, bevelled into mountable
## kerbs across driveways; a concrete gutter on the road in front with cast iron drain
## grates, and kerb returns at both ends. Visual only: the pavement slab is what feet
## and wheels meet, so the stones never sink below it.
func _kerb(mb: MeshBuilder, r: Rect2, north: bool, drives: Array[Vector2], drains: Array[float]) -> void:
	var edge_z := r.end.y if north else r.position.y
	var s := 1.0 if north else -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(edge_z * 10.0)
	var z_back := edge_z - s * 0.09
	var z_face := edge_z + s * 0.11
	var kx := r.position.x
	while kx < r.end.x - 0.01:
		var w := minf(1.0, r.end.x - kx)
		var road := _road_y(kx + w * 0.5, z_face + s * 0.1)
		var t0 := _kerb_top(kx, r, drives)
		var t1 := _kerb_top(kx + w, r, drives)
		var col := KERB.lightened(rng.randf_range(-0.07, 0.03))
		if rng.randf() < 0.12:
			col = col.darkened(0.12)
		_stone(mb, kx + 0.006, kx + w - 0.006, minf(z_back, z_face), maxf(z_back, z_face), road - 0.16, t0, t1, north, col)
		kx += w
	# Returns across both ends of the pavement.
	for ex: float in [r.position.x - 0.08, r.end.x + 0.08]:
		var top := _y(ex, r.get_center().y) + 0.165
		mb.box_at(&"concrete", Vector3(ex, top - 0.14, r.get_center().y - s * 0.01), Vector3(0.16, 0.28, r.size.y + 0.2), KERB)
	# The gutter: concrete channels in 2 m lengths on the road in front of the kerb.
	# Where the road bends away from the kerb line, asphalt fills the gap (and hides
	# the painted edge line, which the gutter covers elsewhere).
	var gz := z_face + s * 0.165
	var gx := r.position.x
	while gx < r.end.x - 0.01:
		var gw := minf(2.0, r.end.x - gx)
		var road := _road_y(gx + gw * 0.5, gz)
		var road_edge := _road_center_z(gx + gw * 0.5) - s * WorldLayout.ROAD_WIDTH * 0.5
		var gap := (road_edge - z_face) * s
		if gap > 0.05:
			var far := road_edge + s * 0.46
			mb.box_at(&"asphalt", Vector3(gx + gw * 0.5, road + 0.009 - 0.05, (z_face + far) * 0.5), Vector3(gw, 0.1, absf(far - z_face)), Color(0.46, 0.46, 0.46))
		mb.box_at(&"concrete", Vector3(gx + gw * 0.5, road + 0.012 - 0.04, gz), Vector3(gw - 0.012, 0.08, 0.33),
				GUTTER.lightened(rng.randf_range(-0.05, 0.02)))
		gx += gw
	# Drain grates in the gutter, a slot for the kerb inlet behind each.
	for dx: float in drains:
		var road := _road_y(dx, gz)
		mb.box_at(&"metal", Vector3(dx, road + 0.009, gz), Vector3(0.66, 0.02, 0.36), IRON)
		for k in 7:
			mb.box_at(&"metal", Vector3(dx - 0.24 + k * 0.08, road + 0.021, gz), Vector3(0.035, 0.006, 0.3), Color(0.16, 0.15, 0.14))
		mb.box_at(&"metal", Vector3(dx, road + 0.05, z_face + s * 0.002), Vector3(0.7, 0.05, 0.01), Color(0.02, 0.02, 0.02))


## The kerb at `x`: (top, how far its road-side arris is chamfered down). It stands a
## little proud of the pavement; across a driveway it is bevelled into a mountable
## kerb, easing in over a metre and a half either side. It never sinks toward the
## road: the pavement slab (and its collision) stays 15 cm up. It follows the ground,
## but never dips under the paving of the 8 m slabs behind it (see _pavements).
func _kerb_top(x: float, r: Rect2, drives: Array[Vector2]) -> Vector2:
	var full := _y(x, r.get_center().y) + 0.165
	for sx: float in [x - 0.01, x + 0.01]:
		var i := clampi(floori((sx - r.position.x) / 8.0), 0, ceili(r.size.x / 8.0) - 1)
		var s0 := r.position.x + i * 8.0
		var s1 := minf(s0 + 8.0, r.end.x)
		full = maxf(full, _y((s0 + s1) * 0.5, r.get_center().y) + 0.162)
	var drop := 0.0
	for d in drives:
		var outside := maxf(maxf(d.x - x, x - d.y), 0.0)
		drop = maxf(drop, clampf(1.0 - outside / 1.5, 0.0, 1.0))
	return Vector2(full - 0.007 * drop, lerpf(0.012, 0.08, drop))


## A kerb stone from x `a` to `b` whose top runs from `top_a` to `top_b` (see
## _kerb_top: x = height, y = chamfer), its road side (+z when `road_hi`) worn lower
## like a rounded arris, or bevelled at a driveway.
func _stone(mb: MeshBuilder, a: float, b: float, zlo: float, zhi: float, bottom: float, top_a: Vector2, top_b: Vector2,
		road_hi: bool, color: Color) -> void:
	var lo_a := 0.0 if road_hi else top_a.y
	var lo_b := 0.0 if road_hi else top_b.y
	var hi_a := top_a.y if road_hi else 0.0
	var hi_b := top_b.y if road_hi else 0.0
	var p: Array[Vector3] = [Vector3(a, bottom, zlo), Vector3(b, bottom, zlo), Vector3(b, top_b.x - lo_b, zlo), Vector3(a, top_a.x - lo_a, zlo),
		Vector3(a, bottom, zhi), Vector3(b, bottom, zhi), Vector3(b, top_b.x - hi_b, zhi), Vector3(a, top_a.x - hi_a, zhi)]
	mb.hexa(&"concrete", p, color)


## Paint, patches, stains and dirt on the ground: decals, so they follow the camber
## of the road and the kerbs, and the scanned manhole covers.
func _road_marks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# The zebra crossing (bars run along the street) and its stop lines.
	_decal("zebra", Vector3(CROSSING_X, _road_y(CROSSING_X, STREET_Z), STREET_Z), Vector2(3.5, 7.0))
	# Worn parking bays.
	for i in 4:
		var x := PARKING.position.x + 0.3 + i * 3.0
		_decal("line", Vector3(x, _y(191, 6) + 0.06, 3.0), Vector2(5.0, 0.16), PI * 0.5, Color(1, 1, 1, 0.9), 0.3)
	# Grit and leaf litter washed against the kerbs.
	for north: bool in [true, false]:
		var edge_z := WALK_N.end.y + 0.11 if north else WALK_S.position.y - 0.11
		var x := WALK_N.position.x + 2.0
		while x < WALK_N.end.x - 2.0:
			if rng.randf() < 0.85:
				var run := rng.randf_range(9.0, 13.0)
				var wide := rng.randf_range(0.7, 1.1)
				_decal("dirt", Vector3(x + run * 0.5, _road_y(x + run * 0.5, edge_z), edge_z + (wide * 0.5 if north else -wide * 0.5)),
						Vector2(run, wide), 0.0 if north else PI, Color(1, 1, 1, rng.randf_range(0.65, 1.0)), 0.6)
			x += rng.randf_range(10.0, 13.5)
	# Patched trenches and pot holes (fresh ones darker, old ones gone grey), sealed cracks.
	for p: Array in [[Vector3(212.0, 0, 18.3), Vector2(2.4, 1.3), 0.05, 0.8], [Vector3(241.5, 0, 21.7), Vector2(3.0, 1.6), -0.03, 1.2],
			[Vector3(266.0, 0, 18.0), Vector2(1.8, 1.2), 0.1, 1.05], [Vector3(196.5, 0, 21.9), Vector2(2.1, 1.5), 0.0, 1.3],
			[Vector3(251.0, 0, 18.25), Vector2(0.75, 3.5), 0.0, 1.15], [Vector3(221.0, 0, 22.2), Vector2(1.4, 1.1), 0.3, 0.9]]:
		var at: Vector3 = p[0]
		at.y = _road_y(at.x, at.z)
		var age: float = p[3]
		_decal("patch", at, p[1], float(p[2]) + rng.randf_range(-0.05, 0.05), Color(age, age, age * 0.98, rng.randf_range(0.8, 1.0)))
	for p: Vector2 in [Vector2(203.0, 21.0), Vector2(236.0, 18.5), Vector2(259.0, 21.5), Vector2(276.0, 19.0), Vector2(190.0, 18.4)]:
		_decal("cracks", Vector3(p.x, _road_y(p.x, p.y), p.y), Vector2(4.5, 4.5), rng.randf() * TAU, Color(1, 1, 1, rng.randf_range(0.4, 0.6)))
	# Oil dripped where cars stop, and tyre marks at the station's entry.
	for p: Vector2 in [Vector2(207.5, 21.8), Vector2(226.5, 18.0), Vector2(245.0, 21.9), Vector2(262.0, 18.2)]:
		_decal("oil", Vector3(p.x, _road_y(p.x, p.y), p.y), Vector2(rng.randf_range(0.9, 1.4), rng.randf_range(0.7, 1.0)),
				rng.randf() * TAU, Color(1, 1, 1, 0.55))
	for p: Vector2 in [Vector2(187.8, 3.0), Vector2(190.8, 2.4), Vector2(193.9, 3.6), Vector2(190.6, 9.5)]:
		_decal("oil", Vector3(p.x, _y(p.x, p.y) + 0.06, p.y), Vector2(1.3, 1.0), rng.randf() * TAU, Color(1, 1, 1, rng.randf_range(0.6, 0.95)))
	var st_top := _y(211, 35) + 0.06
	for p: Vector2 in [Vector2(203.8, 34.3), Vector2(208.2, 33.6), Vector2(213.8, 34.6), Vector2(218.1, 33.9),
			Vector2(209.0, 39.6), Vector2(225.0, 36.0), Vector2(197.0, 44.0)]:
		_decal("oil", Vector3(p.x, st_top, p.y), Vector2(rng.randf_range(1.1, 1.7), rng.randf_range(0.9, 1.3)), rng.randf() * TAU,
				Color(1, 1, 1, rng.randf_range(0.7, 1.0)))
	# Gum, spilt drinks and grime on the pavements where people stop.
	for p: Vector2 in [Vector2(205.8, 12.4), Vector2(220.4, 14.2), Vector2(233.6, 25.9), Vector2(198.5, 15.4), Vector2(262.0, 15.0)]:
		_decal("mud", Vector3(p.x, _y(p.x, p.y) + 0.15, p.y), Vector2(rng.randf_range(1.6, 2.4), rng.randf_range(1.2, 1.8)), rng.randf() * TAU,
				Color(0.55, 0.55, 0.55, rng.randf_range(0.3, 0.45)), 0.4)
	for p: Vector2 in [Vector2(247.0, 11.4), Vector2(255.0, 9.6)]:
		_decal("oil", Vector3(p.x, _y(p.x, p.y) + 0.15, p.y), Vector2(1.0, 0.8), rng.randf() * TAU, Color(1, 1, 1, 0.5))
	# Grime where people wait and walk in: under the benches, round the bins, at the
	# doors; grit swept against the building lines.
	for p: Vector3 in [Vector3(195.1, 12.3, 0.06), Vector3(193.0, 12.6, 0.15), Vector3(229.0, 12.6, 0.0), Vector3(265.0, 12.6, 0.15),
			Vector3(206.0, 10.7, 0.15), Vector3(214.0, 40.3, 0.06), Vector3(247.2, 30.2, 0.0), Vector3(234.0, 27.6, 0.11),
			Vector3(214.4, 13.9, 0.15), Vector3(244.0, 14.3, 0.15), Vector3(258.5, 25.1, 0.15), Vector3(201.5, 25.4, 0.15)]:
		_decal("mud", Vector3(p.x, _y(p.x, p.y) + p.z, p.y), Vector2(rng.randf_range(1.4, 2.2), rng.randf_range(1.1, 1.6)), rng.randf() * TAU,
				Color(0.6, 0.6, 0.58, rng.randf_range(0.22, 0.34)), 0.4)
	for w: Array in [[Vector2(FORECOURT_X.x + 0.4, FORECOURT_X.y - 0.4), 10.0, 0.0, _y(206, 11.5) + 0.15],
			[Vector2(DEALER.position.x + 0.4, DEALER.end.x - 0.4), DEALER.end.y, 0.0, _y(247, 10.5) + 0.15],
			[Vector2(KIOSK.position.x + 0.4, KIOSK.end.x - 0.4), KIOSK.position.y, PI, _y(211, 35) + 0.06]]:
		var span: Vector2 = w[0]
		var x := span.x
		while x < span.y - 1.0:
			var run := minf(rng.randf_range(5.0, 8.0), span.y - x)
			var wide := rng.randf_range(0.5, 0.7)
			var z: float = w[1] + (wide * 0.5 if float(w[2]) == 0.0 else -wide * 0.5)
			_decal("dirt", Vector3(x + run * 0.5, w[3], z), Vector2(run, wide), w[2], Color(0.75, 0.75, 0.73, rng.randf_range(0.45, 0.65)), 0.4)
			x += run + rng.randf_range(0.5, 2.5)
	_decal("tyre", Vector3(205.0, st_top, 28.5), Vector2(6.0, 1.7), PI * 0.5 + 0.12, Color(1, 1, 1, 0.8))
	# Rubber and grime worn into the lanes past the pumps, grit round the islands.
	for lx: float in [203.7, 208.3, 213.7, 218.3]:
		_decal("tyre", Vector3(lx, st_top, 34.0), Vector2(11.0, 2.0), PI * 0.5 + rng.randf_range(-0.03, 0.03), Color(1, 1, 1, 0.55))
	for ix: float in [CANOPY.position.x + 7.0, CANOPY.end.x - 7.0]:
		for sx: float in [-1.0, 1.0]:
			_decal("dirt", Vector3(ix + sx * 0.95, st_top, CANOPY.get_center().y), Vector2(6.8, 0.6), PI * 0.5 * sx, Color(0.8, 0.8, 0.8, 0.8), 0.4)
	_decal("tyre", Vector3(219.0, st_top, 29.0), Vector2(6.0, 1.7), PI * 0.5 - 0.2, Color(1, 1, 1, 0.6))
	_decal("tyre", Vector3(234.0, _road_y(234, 21.5), 21.5), Vector2(9.0, 1.7), 0.03, Color(1, 1, 1, 0.5))
	# Manhole covers in the lanes.
	for p: Vector2 in [Vector2(201.0, 18.2), Vector2(226.0, 21.8), Vector2(253.0, 18.4), Vector2(276.0, 21.5)]:
		var tilt := Basis(Vector3.RIGHT, 0.01 * signf(p.y - STREET_Z))
		_prop("water_manhole_cover", Vector3(p.x, _road_y(p.x, p.y) - 0.026, p.y), rng.randf() * TAU, 1.0, tilt)


# --- Market ------------------------------------------------------------------------------

func _market(mb: MeshBuilder, cols: Array) -> void:
	var y0 := _y(MARKET.get_center().x, MARKET.get_center().y) + 0.15
	var h := 5.0
	BuildingKit.shell(mb, cols, MARKET, y0, h, 0.3, &"t_brick", Color(0.5, 0.5, 0.5), {
		"s": [{"at": 4.0, "w": 6.4, "bottom": 0.6, "top": 3.4, "glass": true, "mullions": 1.6},
			{"at": 10.0, "w": 2.6, "bottom": 0.0, "top": 2.9, "glass": false},
			{"at": 16.0, "w": 6.4, "bottom": 0.6, "top": 3.4, "glass": true, "mullions": 1.6}],
		"w": [{"at": 7.0, "w": 3.0, "bottom": 1.2, "top": 2.8, "glass": true}],
	})
	# Plaster fascia with the sign above the shop front.
	var fz := MARKET.end.y + 0.02
	mb.box_at(&"plaster", Vector3(MARKET.get_center().x, y0 + 4.3, fz + 0.08), Vector3(MARKET.size.x + 0.3, 1.25, 0.2), Color(0.62, 0.6, 0.55))
	mb.box_at(&"sign", Vector3(MARKET.get_center().x, y0 + 4.3, fz + 0.2), Vector3(11.0, 0.9, 0.06), Color(0.12, 0.34, 0.2))
	BuildingKit.sign(self, "YEŞİLOVA MARKET", Vector3(MARKET.get_center().x, y0 + 4.3, fz + 0.24), 0.0, 128, Color(1.0, 0.97, 0.88))
	BuildingKit.awning(mb, Vector3(MARKET.position.x + 10.0, y0 + 3.2, fz + 0.05), 4.2, 1.5, Vector2(0, 1), Color(0.14, 0.36, 0.22))
	# A stepped cornice capping the fascia.
	mb.box_at(&"concrete", Vector3(MARKET.get_center().x, y0 + 4.97, fz + 0.12), Vector3(MARKET.size.x + 0.42, 0.1, 0.28), Color(0.58, 0.57, 0.54))
	mb.box_at(&"concrete", Vector3(MARKET.get_center().x, y0 + 5.06, fz + 0.1), Vector3(MARKET.size.x + 0.5, 0.08, 0.34), Color(0.6, 0.59, 0.56))
	_market_front(mb, cols, y0)
	# Interior: shelves of produce and the checkout.
	var shelf_col := Color(0.4, 0.42, 0.44)
	var goods: Array[StringName] = [&"tomato", &"carrot", &"pumpkin", &"potato", &"strawberry", &"corn", &"wheat", &"egg"]
	var gi := 0
	for row in 3:
		var z := MARKET.position.y + 2.2 + row * 3.0
		for half: float in [0.0, 1.0]:
			var x := MARKET.position.x + 6.5 + half * 8.0
			var base := Vector3(x, y0, z)
			mb.box_at(&"metal", base + Vector3(0, 0.9, 0), Vector3(5.0, 1.8, 0.08), shelf_col)
			for level in 4:
				var ly := 0.25 + level * 0.5
				mb.box_at(&"metal", base + Vector3(0, ly, 0.3), Vector3(5.0, 0.04, 0.56), shelf_col.lightened(0.1))
				_crates_on_shelf(base + Vector3(0, ly + 0.02, 0.3), goods[gi % goods.size()], 5.0, false)
				gi += 1
			cols.append([base + Vector3(0, 1.0, 0.25), Vector3(5.0, 2.0, 0.7), 0.0])
	# Checkout counter by the door.
	var counter := Vector3(MARKET.position.x + 13.5, y0, MARKET.end.y - 2.2)
	mb.box_at(&"wood_in", counter + Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 0.8), Color(0.45, 0.4, 0.34))
	mb.box_at(&"metal", counter + Vector3(0, 1.02, 0), Vector3(2.7, 0.05, 0.9), Color(0.2, 0.2, 0.21))
	mb.box_at(&"metal", counter + Vector3(0.6, 1.2, -0.1), Vector3(0.45, 0.3, 0.35), Color(0.12, 0.12, 0.13))
	mb.box_at(&"glow", counter + Vector3(0.6, 1.3, 0.08), Vector3(0.3, 0.12, 0.01), Color(0.4, 0.9, 0.6))
	market_counter = _interactable(counter + Vector3(0, 0.6, 0), Vector3(2.6, 1.2, 0.8), "ACTION_SHOP_MARKET",
			func() -> void: Game.hud.open_shop(ShopStock.town_market()))
	# Ceiling lights.
	for lx: float in [MARKET.position.x + 6.0, MARKET.position.x + 14.0]:
		for lz: float in [MARKET.position.y + 4.0, MARKET.position.y + 10.0]:
			mb.box_at(&"glow", Vector3(lx, y0 + h - 0.1, lz), Vector3(1.2, 0.04, 0.3), Color(1.0, 0.97, 0.9))
	for lx: float in [MARKET.position.x + 6.0, MARKET.position.x + 14.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(lx, y0 + h - 0.6, MARKET.get_center().y)
		light.light_color = Color(1.0, 0.96, 0.9)
		light.light_energy = 1.3
		light.omni_range = 10.0
		light.shadow_enabled = false
		add_child(light)
	# Crates of produce outside.
	for i in 2:
		var base := Vector3(MARKET.position.x + 1.6 + i * 15.0, y0, MARKET.end.y + 0.8)
		mb.box_at(&"planks", base + Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 0.6), Color(0.55, 0.5, 0.44))
		_crates_on_shelf(base + Vector3(0, 0.7, 0), goods[i * 3], 1.3, true)
	# Bench.
	_bench(mb, cols, Vector3(MARKET.position.x - 0.9, _y(195, 12) + 0.15, 12.3), 0.0)
	# The order board by the door, facing the street.
	var board := OrderBoard.new()
	board.name = "OrderBoard"
	var bx := MARKET.end.x - 1.4
	var bz := MARKET.end.y + 2.0
	board.position = Vector3(bx, _y(bx, bz) + 0.15, bz)
	add_child(board)


## The market's shop front and sides as a real one looks: a dark stone plinth,
## roller-shutter cases and guide rails (kepenk) over the windows and the door,
## striped awnings, posters and an "open" sign behind the glass, a drinks fridge,
## tea chairs and a bike by the door; downpipes, an air-conditioner and the meter box
## on the side, a water tank and condensers on the roof; LPG cylinders in a cage and
## a pallet of cement by the car park; rain streaks down the brick.
func _market_front(mb: MeshBuilder, cols: Array, y0: float) -> void:
	var wz := MARKET.end.y
	var x0 := MARKET.position.x
	var stone := Color(0.25, 0.25, 0.26)
	for seg: Vector2 in [Vector2(x0 - 0.03, x0 + 8.7), Vector2(x0 + 11.3, MARKET.end.x + 0.03)]:
		mb.box_at(&"concrete", Vector3((seg.x + seg.y) * 0.5, y0 + 0.2, wz + 0.025), Vector3(seg.y - seg.x, 0.55, 0.05), stone)
		mb.box_at(&"concrete", Vector3((seg.x + seg.y) * 0.5, y0 + 0.485, wz + 0.035), Vector3(seg.y - seg.x, 0.03, 0.07), stone.lightened(0.08))
	# Kepenk cases and rails: windows (x 0.8..7.2 and 12.8..19.2 from the corner), the door (8.7..11.3).
	for o: Vector3 in [Vector3(x0 + 0.8, x0 + 7.2, 3.4), Vector3(x0 + 8.7, x0 + 11.3, 2.9), Vector3(x0 + 12.8, x0 + 19.2, 3.4)]:
		_shutter_case(mb, o.x, o.y, wz, y0, y0 + o.z)
	var stripes: Array[Color] = [Color(0.13, 0.36, 0.22), Color(0.74, 0.72, 0.66)]
	_shop_awning(mb, x0 + 0.6, x0 + 7.4, wz, y0 + 3.72, 1.55, stripes)
	_shop_awning(mb, x0 + 12.6, x0 + 19.4, wz, y0 + 3.72, 1.55, stripes)
	# Posters behind the glass (centred in the panes, clear of the mullions).
	var gz := wz - 0.2
	_print(mb, "poster_sale", Vector3(x0 + 1.6, y0 + 1.75, gz), Vector3.BACK, Vector2(0.72, 1.08))
	_print(mb, "poster_bread", Vector3(x0 + 4.8, y0 + 1.45, gz), Vector3.BACK, Vector2(0.7, 0.7))
	_print(mb, "open", Vector3(x0 + 13.6, y0 + 2.0, gz), Vector3.BACK, Vector2(0.56, 0.28))
	_print(mb, "hours", Vector3(x0 + 13.6, y0 + 1.5, gz), Vector3.BACK, Vector2(0.44, 0.22))
	_print(mb, "poster_fresh", Vector3(x0 + 18.4, y0 + 1.75, gz), Vector3.BACK, Vector2(0.72, 1.08))
	# Sliding glass doors, open, parked behind the jambs; a mat on the threshold.
	_sliding_doors(mb, x0 + 8.7, x0 + 11.3, wz - 0.3, y0 + 0.02, y0 + 2.9)
	# A drinks fridge left of the door, standing on the forecourt.
	var fy := _y(206, 11.5) + 0.15
	var fridge := Vector3(x0 + 7.95, fy, wz + 0.42)
	_fridge(mb, fridge)
	cols.append([fridge + Vector3(0, 0.97, 0), Vector3(0.8, 1.95, 0.64), 0.0])
	# Tea at a plastic table under the awning.
	_prop("plastic_monobloc_chair_01", Vector3(x0 + 4.35, fy, wz + 0.95), PI * 0.5 + 0.2)
	_prop("plastic_monobloc_chair_01", Vector3(x0 + 5.95, fy, wz + 1.0), -PI * 0.5 - 0.15)
	_tea_table(mb, Vector3(x0 + 5.15, fy, wz + 0.98))
	# A bike against the wall between the door and the window.
	_bike(mb, Vector3(x0 + 12.25, fy, wz + 0.5), 0.04, deg_to_rad(-9.0), Color(0.12, 0.26, 0.45))
	# Downpipes at the front corners, on the side walls.
	for side: float in [-1.0, 1.0]:
		var px := (MARKET.position.x - 0.09) if side < 0.0 else (MARKET.end.x + 0.09)
		_downpipe(mb, Vector3(px, y0, wz - 0.4), y0 + 5.9)
	# West wall (over the car park): the air-conditioner, its pipes and the meter box.
	var wx := MARKET.position.x
	var ac := Vector3(wx - 0.2, y0 + 2.35, 6.8)
	mb.box_at(&"metal", ac, Vector3(0.32, 0.6, 0.85), Color(0.78, 0.78, 0.76))
	mb.cylinder(&"metal", Transform3D(Basis(Vector3.FORWARD, PI * 0.5), ac + Vector3(-0.16, 0, -0.08)), 0.23, 0.23, 0.012, 16, Color(0.1, 0.1, 0.1))
	for k in 5:
		mb.box_at(&"metal", ac + Vector3(-0.175, -0.2 + k * 0.1, -0.08), Vector3(0.01, 0.012, 0.46), Color(0.5, 0.5, 0.5))
	for dz: float in [-0.3, 0.3]:
		mb.box_at(&"metal", ac + Vector3(0.02, -0.33, dz), Vector3(0.36, 0.04, 0.04), IRON)
	mb.cylinder_between(&"metal", ac + Vector3(0.06, 0.3, 0.35), Vector3(wx - 0.06, y0 + 5.2, 7.2), 0.028, 0.028, 6, Color(0.82, 0.82, 0.8))
	mb.cylinder_between(&"metal", ac + Vector3(0.06, -0.3, 0.38), Vector3(wx - 0.05, y0 + 0.2, 7.25), 0.01, 0.01, 4, Color(0.8, 0.8, 0.78))
	mb.box_at(&"metal", Vector3(wx - 0.08, y0 + 1.35, 8.6), Vector3(0.16, 0.55, 0.42), Color(0.62, 0.63, 0.62))
	mb.box_at(&"glass", Vector3(wx - 0.165, y0 + 1.45, 8.6), Vector3(0.01, 0.14, 0.2), Color.WHITE)
	# LPG cylinders in their cage against the west wall (between the last bay and the wall).
	var cage := Vector3(wx - 0.36, _y(wx - 0.4, 5.4) + 0.06, 5.4)
	_gas_cage(mb, cols, cage, -PI * 0.5)
	# A pallet of cement and a half-used one against the back edge of the car park.
	_cement_pallet(mb, cols, Vector3(188.0, _y(188, -1.45) + 0.06, -1.45), 4, 0.05)
	_cement_pallet(mb, cols, Vector3(190.4, _y(190, -1.45) + 0.06, -1.45), 2, -0.03)
	# The roof: a black water tank, condensers.
	var roof := y0 + 5.0 + 0.3
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(x0 + 16.5, roof, -2.2)), 0.55, 0.55, 1.15, 16, Color(0.07, 0.07, 0.08))
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(x0 + 16.5, roof + 1.15, -2.2)), 0.2, 0.2, 0.08, 10, Color(0.07, 0.07, 0.08))
	for k in 2:
		var cp := Vector3(x0 + 3.0 + k * 1.3, roof, -1.8)
		mb.box_at(&"metal", cp + Vector3(0, 0.36, 0), Vector3(0.95, 0.72, 0.42), Color(0.74, 0.74, 0.72))
		mb.cylinder(&"metal", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), cp + Vector3(0, 0.38, 0.215)), 0.26, 0.26, 0.01, 14, Color(0.1, 0.1, 0.1))
	# Rain streaks under the parapet and the sills.
	for z: float in [-2.5, 2.5, 8.0]:
		_wall_decal("streaks", Vector3(wx - 0.02, y0 + 5.7, z), Vector3.LEFT, Vector2(2.6, 3.4), Color(1, 1, 1, 0.8))
	_wall_decal("streaks", Vector3(wx - 0.02, y0 + 1.2, 3.3), Vector3.LEFT, Vector2(2.8, 1.0), Color(1, 1, 1, 0.6))
	for z: float in [-1.0, 5.0]:
		_wall_decal("streaks", Vector3(MARKET.end.x + 0.02, y0 + 5.7, z), Vector3.RIGHT, Vector2(2.6, 3.0), Color(1, 1, 1, 0.7))


## The two leaves of an automatic sliding door slid open behind the jambs of an
## opening from `x0` to `x1` in a wall whose inner face is at `inner_z` (facing +z),
## the operator box over it and a mat on the floor.
func _sliding_doors(mb: MeshBuilder, x0: float, x1: float, inner_z: float, floor_y: float, top: float) -> void:
	var alu := Color(0.62, 0.63, 0.64)
	var w := (x1 - x0) * 0.5 + 0.08
	var h := top - floor_y - 0.02
	for side: float in [-1.0, 1.0]:
		var cx := (x0 - w * 0.5 + 0.12) if side < 0.0 else (x1 + w * 0.5 - 0.12)
		var z := inner_z - 0.06
		_glass("MarketGlass").box_at(&"shop_glass", Vector3(cx, floor_y + h * 0.5, z), Vector3(w - 0.08, h - 0.08, 0.012), Color.WHITE)
		for fx: float in [-1.0, 1.0]:
			mb.box_at(&"metal", Vector3(cx + fx * (w * 0.5 - 0.025), floor_y + h * 0.5, z), Vector3(0.05, h, 0.045), alu)
		for fy: float in [0.03, h - 0.03]:
			mb.box_at(&"metal", Vector3(cx, floor_y + fy, z), Vector3(w, 0.06, 0.045), alu)
		mb.box_at(&"metal", Vector3(cx, floor_y + 1.05, z), Vector3(w - 0.1, 0.035, 0.05), alu.darkened(0.2))
	mb.box_at(&"metal", Vector3((x0 + x1) * 0.5, top + 0.12, inner_z - 0.1), Vector3(x1 - x0 + 1.6, 0.22, 0.16), alu.darkened(0.1))
	mb.box_at(&"glow", Vector3((x0 + x1) * 0.5, top + 0.02, inner_z - 0.1), Vector3(0.12, 0.02, 0.06), Color(0.3, 0.6, 1.0))
	mb.box_at(&"cloth", Vector3((x0 + x1) * 0.5, floor_y + 0.006, inner_z - 0.6), Vector3(x1 - x0 - 0.3, 0.012, 1.0), Color(0.14, 0.14, 0.15))


## Roller-shutter case over an opening in a wall facing +z and the guide rails
## down both its sides.
func _shutter_case(mb: MeshBuilder, x0: float, x1: float, wall_z: float, bottom: float, top: float) -> void:
	var grey := Color(0.5, 0.51, 0.5)
	mb.box_at(&"metal", Vector3((x0 + x1) * 0.5, top + 0.13, wall_z + 0.12), Vector3(x1 - x0 + 0.16, 0.26, 0.24), grey)
	mb.box_at(&"metal", Vector3((x0 + x1) * 0.5, top + 0.005, wall_z + 0.2), Vector3(x1 - x0 + 0.1, 0.012, 0.05), grey.darkened(0.3))
	for x: float in [x0 - 0.04, x1 + 0.04]:
		mb.box_at(&"metal", Vector3(x, (bottom + top) * 0.5, wall_z + 0.035), Vector3(0.06, top - bottom, 0.07), grey.darkened(0.12))


## A striped retractable awning on a wall facing +z from `x0` to `x1`: the roller
## case at `y_top`, the cloth falling half a metre over `depth`, a valance, the front
## bar and folding arms.
func _shop_awning(mb: MeshBuilder, x0: float, x1: float, wall_z: float, y_top: float, depth: float, colors: Array[Color]) -> void:
	var drop := 0.5
	var n := maxi(int(roundf((x1 - x0) / 0.6)), 3)
	var w := (x1 - x0) / n
	var tilt := atan2(drop, depth)
	var slope_len := Vector2(depth, drop).length()
	for i in n:
		var cx := x0 + (i + 0.5) * w
		var col := colors[i % colors.size()]
		mb.box(&"cloth", Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(cx, y_top - drop * 0.5, wall_z + 0.12 + depth * 0.5)),
				Vector3(w + 0.002, 0.018, slope_len), col)
		mb.box_at(&"cloth", Vector3(cx, y_top - drop - 0.13, wall_z + 0.13 + depth), Vector3(w + 0.002, 0.26, 0.012), col)
		# Scalloped hem.
		var hem := Vector3(cx, y_top - drop - 0.26, wall_z + 0.137 + depth)
		mb.tri(&"cloth", hem + Vector3(-w * 0.5, 0, 0), hem + Vector3(0, -0.07, 0), hem + Vector3(w * 0.5, 0, 0), col)
		mb.tri(&"cloth", hem + Vector3(w * 0.5, 0, -0.012), hem + Vector3(0, -0.07, -0.012), hem + Vector3(-w * 0.5, 0, -0.012), col)
	var metal := Color(0.32, 0.33, 0.34)
	mb.box_at(&"metal", Vector3((x0 + x1) * 0.5, y_top - drop - 0.01, wall_z + 0.12 + depth), Vector3(x1 - x0 + 0.04, 0.05, 0.05), metal)
	mb.cylinder_between(&"metal", Vector3(x0 - 0.06, y_top + 0.04, wall_z + 0.1), Vector3(x1 + 0.06, y_top + 0.04, wall_z + 0.1), 0.085, 0.085, 10, Color(0.7, 0.7, 0.68))
	for ax: float in [x0 + 0.35, x1 - 0.35]:
		mb.cylinder_between(&"metal", Vector3(ax, y_top - 0.95, wall_z + 0.03), Vector3(ax, y_top - drop - 0.03, wall_z + 0.08 + depth),
				0.018, 0.018, 6, metal)


## A glass-fronted drinks fridge (red, lit header, rows of bottles) facing +z.
func _fridge(mb: MeshBuilder, base: Vector3) -> void:
	var red := Color(0.58, 0.08, 0.07)
	var w := 0.8
	var d := 0.64
	var h := 1.95
	mb.box_at(&"metal", base + Vector3(0, h * 0.5, -d * 0.5 + 0.03), Vector3(w, h, 0.06), red)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"metal", base + Vector3(sx * (w * 0.5 - 0.03), h * 0.5, 0), Vector3(0.06, h, d), red)
	mb.box_at(&"metal", base + Vector3(0, 0.08, 0), Vector3(w, 0.16, d), Color(0.1, 0.1, 0.1))
	mb.box_at(&"metal", base + Vector3(0, h - 0.14, 0), Vector3(w, 0.28, d), red)
	mb.box_at(&"glow", base + Vector3(0, h - 0.14, d * 0.5 + 0.003), Vector3(w - 0.12, 0.16, 0.004), Color(0.95, 0.92, 0.85))
	mb.box_at(&"metal", base + Vector3(0, 0.95, -d * 0.5 + 0.065), Vector3(w - 0.12, 1.55, 0.01), Color(0.85, 0.86, 0.87))
	var bottle := [Color(0.55, 0.12, 0.08), Color(0.25, 0.45, 0.2), Color(0.85, 0.55, 0.15), Color(0.2, 0.3, 0.5), Color(0.75, 0.75, 0.7)]
	for row in 5:
		var sy := 0.2 + row * 0.3
		mb.box_at(&"metal", base + Vector3(0, sy, 0), Vector3(w - 0.12, 0.015, d - 0.12), Color(0.6, 0.6, 0.6))
		for k in 6:
			_fine.cylinder(&"veg_gloss", Transform3D(Basis(), base + Vector3(-0.28 + k * 0.112, sy + 0.01, 0.12)), 0.035, 0.03, 0.22, 6,
					bottle[(row + k) % bottle.size()])
	_glass("MarketGlass").box_at(&"shop_glass", base + Vector3(0, 0.95, d * 0.5 - 0.02), Vector3(w - 0.1, 1.55, 0.012), Color.WHITE)
	mb.box_at(&"metal", base + Vector3(w * 0.5 - 0.1, 0.95, d * 0.5), Vector3(0.03, 0.5, 0.03), Color(0.75, 0.75, 0.75))


## A small white plastic table (top 73 cm up) with two glasses of tea on saucers.
func _tea_table(mb: MeshBuilder, base: Vector3) -> void:
	var white := Color(0.78, 0.78, 0.76)
	var top := 0.705
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), base + Vector3(0, top, 0)), 0.36, 0.36, 0.025, 20, white)
	mb.cylinder(&"veg_gloss", Transform3D(Basis(), base + Vector3(0, top - 0.05, 0)), 0.33, 0.35, 0.05, 20, white.darkened(0.06), true, false)
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		mb.cylinder_between(&"veg_gloss", base + Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), base + Vector3(cos(a) * 0.24, top, sin(a) * 0.24), 0.02, 0.02, 6, white)
	for p: Vector3 in [Vector3(-0.12, top + 0.025, 0.06), Vector3(0.14, top + 0.025, -0.05)]:
		_fine.cylinder(&"veg_gloss", Transform3D(Basis(), base + p), 0.05, 0.05, 0.006, 10, Color(0.85, 0.84, 0.8))
		_fine.cylinder(&"veg_gloss", Transform3D(Basis(), base + p + Vector3(0, 0.006, 0)), 0.02, 0.026, 0.055, 8, Color(0.5, 0.14, 0.05))


## A town bike leaning against a wall, turned by `yaw` and tipped by `lean` about its
## length: a diamond frame, 32-spoke wheels laced from both hub flanges, a two-bladed
## fork, cranks, pedals and chain, a saddle, mudguards, a rear rack and a wire basket.
## Spokes, chain and basket wire go into the no-shadow mesh.
func _bike(mb: MeshBuilder, base: Vector3, yaw: float, lean: float, color: Color) -> void:
	var fr := MeshBuilder.new()
	var thin := MeshBuilder.new()
	var wr := 0.34
	var tyre := Color(0.06, 0.06, 0.06)
	var steel := Color(0.62, 0.62, 0.64)
	var black := Color(0.08, 0.08, 0.08)
	var axle_r := Vector3(-0.53, wr, 0)
	var axle_f := Vector3(0.53, wr, 0)
	# Rings stand on their local y: turned so it points to -z (the wheel plane is z = 0).
	var on_side := Basis(Vector3.RIGHT, -PI * 0.5)
	for c: Vector3 in [axle_r, axle_f]:
		fr.ring(&"metal", Transform3D(on_side, c + Vector3(0, 0, 0.0175)), wr, wr - 0.036, 0.035, 24, tyre)
		fr.ring(&"metal", Transform3D(on_side, c + Vector3(0, 0, 0.011)), wr - 0.036, wr - 0.052, 0.022, 24, steel)
		fr.cylinder_between(&"metal", c + Vector3(0, 0, -0.05), c + Vector3(0, 0, 0.05), 0.02, 0.02, 8, steel)
		for k in 32:
			var a := k * TAU / 32.0
			var flange := 0.028 if k % 2 == 0 else -0.028
			var hub := Vector3(cos(a + 0.3), sin(a + 0.3), 0) * 0.024 + Vector3(0, 0, flange)
			thin.cylinder_between(&"metal", c + hub, c + Vector3(cos(a), sin(a), 0) * (wr - 0.05), 0.0014, 0.0014, 3, steel, false, false)
		# Mudguard: a curved strip over the top of the wheel.
		var arc := 10
		for k in arc:
			var a0 := deg_to_rad(15.0 + 150.0 * k / arc)
			var a1 := deg_to_rad(15.0 + 150.0 * (k + 1) / arc)
			var p0 := c + Vector3(cos(a0), sin(a0), 0) * (wr + 0.03)
			var p1 := c + Vector3(cos(a1), sin(a1), 0) * (wr + 0.03)
			fr.quad2(&"metal", p0 + Vector3(0, 0, -0.028), p1 + Vector3(0, 0, -0.028), p1 + Vector3(0, 0, 0.028), p0 + Vector3(0, 0, 0.028), color.darkened(0.15))
	var bb := Vector3(-0.05, 0.3, 0)
	var seat := Vector3(-0.2, 0.82, 0)
	var head_top := Vector3(0.36, 0.86, 0)
	var head_bot := Vector3(0.42, 0.66, 0)
	for tube: Array in [[bb, seat, 0.017], [seat + Vector3(0.015, -0.06, 0), head_top, 0.015], [bb, head_bot, 0.018], [head_top, head_bot, 0.021]]:
		fr.cylinder_between(&"metal", tube[0], tube[1], tube[2], tube[2], 8, color)
	for side: float in [-1.0, 1.0]:
		var z := Vector3(0, 0, side * 0.04)
		fr.cylinder_between(&"metal", bb + z * 0.6, axle_r + z, 0.01, 0.009, 6, color)
		fr.cylinder_between(&"metal", seat + Vector3(0.012, -0.06, 0), axle_r + z, 0.009, 0.008, 6, color)
		# Fork blades from the crown, raked forward to the front axle.
		fr.cylinder_between(&"metal", head_bot + z, head_bot + Vector3(0.05, -0.2, 0) + z * 1.1, 0.012, 0.011, 6, color)
		fr.cylinder_between(&"metal", head_bot + Vector3(0.05, -0.2, 0) + z * 1.1, axle_f + z * 1.1, 0.011, 0.008, 6, color)
		# Rear rack struts.
		fr.cylinder_between(&"metal", axle_r + z * 1.3, axle_r + Vector3(0.04, 0.42, 0) + z * 2.4, 0.005, 0.005, 5, black)
	fr.box_at(&"metal", head_bot + Vector3(0.0, 0.0, 0), Vector3(0.05, 0.03, 0.11), color)
	# Rack platform and its stays to the seat tube.
	for dz: float in [-0.08, 0.0, 0.08]:
		fr.cylinder_between(&"metal", axle_r + Vector3(-0.12, 0.42, dz), axle_r + Vector3(0.24, 0.42, dz), 0.005, 0.005, 5, black)
	fr.cylinder_between(&"metal", axle_r + Vector3(0.24, 0.42, 0), seat + Vector3(0.01, -0.12, 0), 0.005, 0.005, 5, black)
	# Seat post and saddle: wide at the back, a narrow nose, padded top.
	fr.cylinder_between(&"metal", seat, seat + Vector3(-0.025, 0.1, 0), 0.012, 0.012, 6, steel)
	var sd := seat + Vector3(-0.03, 0.12, 0)
	var sp: Array[Vector3] = [sd + Vector3(-0.13, -0.015, -0.085), sd + Vector3(0.14, -0.005, -0.025), sd + Vector3(0.14, 0.022, -0.025),
		sd + Vector3(-0.13, 0.03, -0.085), sd + Vector3(-0.13, -0.015, 0.085), sd + Vector3(0.14, -0.005, 0.025),
		sd + Vector3(0.14, 0.022, 0.025), sd + Vector3(-0.13, 0.03, 0.085)]
	fr.hexa(&"cloth", sp, Color(0.07, 0.06, 0.05))
	fr.sphere(&"cloth", Transform3D(Basis(), sd + Vector3(-0.07, 0.03, 0)), Vector3(0.08, 0.018, 0.08), 10, 4, Color(0.07, 0.06, 0.05))
	# Stem and a swept-back handlebar with grips.
	var stem := head_top + Vector3(-0.02, 0.1, 0)
	fr.cylinder_between(&"metal", head_top, stem, 0.013, 0.013, 6, steel)
	for side: float in [-1.0, 1.0]:
		var end := stem + Vector3(-0.1, 0.02, side * 0.28)
		fr.cylinder_between(&"metal", stem, stem + Vector3(-0.02, 0.0, side * 0.16), 0.011, 0.011, 6, steel)
		fr.cylinder_between(&"metal", stem + Vector3(-0.02, 0.0, side * 0.16), end, 0.011, 0.011, 6, steel)
		fr.cylinder_between(&"metal", end - Vector3(-0.03, 0.005, side * 0.11), end, 0.016, 0.016, 8, black)
	# Chainring, rear sprocket and the chain between them, cranks and pedals.
	fr.ring(&"metal", Transform3D(on_side, bb + Vector3(0, 0, 0.055)), 0.1, 0.075, 0.006, 20, steel)
	fr.ring(&"metal", Transform3D(on_side, axle_r + Vector3(0, 0, 0.05)), 0.042, 0.02, 0.006, 12, steel)
	for sy: float in [-1.0, 1.0]:
		thin.cylinder_between(&"metal", bb + Vector3(0, sy * 0.1, 0.052), axle_r + Vector3(0, sy * 0.042, 0.047), 0.004, 0.004, 4, Color(0.2, 0.2, 0.2), false, false)
	var crank := Vector3(cos(-0.9), sin(-0.9), 0) * 0.17
	for side: float in [-1.0, 1.0]:
		var arm := crank * side
		var z := Vector3(0, 0, side * 0.075)
		fr.cylinder_between(&"metal", bb + z, bb + z + arm, 0.012, 0.01, 6, steel)
		fr.box_at(&"metal", bb + z * 1.9 + arm, Vector3(0.1, 0.022, 0.08), black)
	fr.cylinder_between(&"metal", bb + Vector3(0, 0, -0.08), bb + Vector3(0, 0, 0.08), 0.022, 0.022, 8, steel)
	# A kickstand folded up along the left chain stay.
	fr.cylinder_between(&"metal", bb + Vector3(-0.06, -0.02, -0.06), bb + Vector3(-0.3, 0.02, -0.07), 0.008, 0.007, 5, black)
	# The wire basket over the front wheel, on struts to the axle.
	var bk := head_top + Vector3(0.21, -0.02, 0)
	var hb := Vector3(0.16, 0.12, 0.17)
	var corners: Array[Vector3] = []
	for cy: float in [-1.0, 1.0]:
		for cx: float in [-1.0, 1.0]:
			for cz: float in [-1.0, 1.0]:
				corners.append(bk + Vector3(cx * hb.x, cy * hb.y, cz * hb.z))
	for e: Vector2i in [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7), Vector2i(0, 2), Vector2i(1, 3), Vector2i(4, 6),
			Vector2i(5, 7), Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]:
		thin.cylinder_between(&"metal", corners[e.x], corners[e.y], 0.0045, 0.0045, 4, black)
	for k in 5:
		var t := (k + 1) / 6.0
		var y := bk.y - hb.y + 0.24 * t
		for cz: float in [-1.0, 1.0]:
			thin.cylinder_between(&"metal", Vector3(bk.x - hb.x, y, bk.z + cz * hb.z), Vector3(bk.x + hb.x, y, bk.z + cz * hb.z), 0.0025, 0.0025, 3, black, false, false)
		for cx: float in [-1.0, 1.0]:
			thin.cylinder_between(&"metal", Vector3(bk.x + cx * hb.x, y, bk.z - hb.z), Vector3(bk.x + cx * hb.x, y, bk.z + hb.z), 0.0025, 0.0025, 3, black, false, false)
		var x := bk.x - hb.x + 0.32 * t
		thin.cylinder_between(&"metal", Vector3(x, bk.y - hb.y, bk.z - hb.z), Vector3(x, bk.y - hb.y, bk.z + hb.z), 0.0025, 0.0025, 3, black, false, false)
	for side: float in [-1.0, 1.0]:
		thin.cylinder_between(&"metal", axle_f + Vector3(0, 0, side * 0.05), bk + Vector3(0.02, -hb.y, side * 0.1), 0.005, 0.005, 4, black)
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean), base)
	mb.append(fr, xf)
	_fine.append(thin, xf)


## A galvanised downpipe down a wall from a hopper at `top` to a shoe at `base`.
func _downpipe(mb: MeshBuilder, base: Vector3, top: float) -> void:
	var col := GALV.darkened(0.1)
	mb.cylinder(&"metal", Transform3D(Basis(), base + Vector3(0, 0.18, 0)), 0.05, 0.05, top - base.y - 0.35, 8, col)
	mb.box_at(&"metal", Vector3(base.x, top - 0.12, base.z), Vector3(0.2, 0.26, 0.2), col)
	mb.cylinder_between(&"metal", base + Vector3(0, 0.2, 0), base + Vector3(0, 0.05, 0.22), 0.05, 0.05, 8, col)
	for k in 3:
		mb.box_at(&"metal", base + Vector3(0, 1.0 + k * (top - base.y - 1.4) / 2.0, 0), Vector3(0.12, 0.03, 0.12), col.darkened(0.2))


## A welded cage of LPG cylinders (five, three in front) with the "TÜP" plate, facing
## `yaw`; its thin bars go into the no-shadow mesh.
func _gas_cage(mb: MeshBuilder, cols: Array, base: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var w := 1.2
	var d := 0.62
	var h := 1.15
	var grey := Color(0.36, 0.38, 0.37)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box(&"metal", Transform3D(b, base + b * Vector3(sx * w * 0.5, h * 0.5, sz * d * 0.5)), Vector3(0.035, h, 0.035), grey)
	for y: float in [0.03, h * 0.5, h]:
		for sz: float in [-1.0, 1.0]:
			mb.box(&"metal", Transform3D(b, base + b * Vector3(0, y, sz * d * 0.5)), Vector3(w, 0.03, 0.03), grey)
		for sx: float in [-1.0, 1.0]:
			mb.box(&"metal", Transform3D(b, base + b * Vector3(sx * w * 0.5, y, 0)), Vector3(0.03, 0.03, d), grey)
	for k in 11:
		_fine.box(&"metal", Transform3D(b, base + b * Vector3(-w * 0.5 + (k + 0.5) * w / 11.0, h * 0.5, d * 0.5)), Vector3(0.012, h, 0.012), grey)
	mb.box(&"metal", Transform3D(b, base + b * Vector3(0, h + 0.02, 0)), Vector3(w + 0.04, 0.03, d + 0.04), grey)
	_print(mb, "lpg", base + b * Vector3(0, h + 0.2, d * 0.5 - 0.1), b * Vector3.BACK, Vector2(0.6, 0.3))
	mb.box(&"metal", Transform3D(b, base + b * Vector3(0, h + 0.2, d * 0.5 - 0.115)), Vector3(0.62, 0.32, 0.02), grey)
	for k in 5:
		var p := Vector3(-0.38 + k * 0.38, 0.03, 0.14) if k < 3 else Vector3(-0.2 + (k - 3) * 0.4, 0.03, -0.14)
		_prop("propane_tank", base + b * p, yaw + k * 1.3)
	cols.append([base + Vector3(0, h * 0.5, 0), Vector3(w, h, d), yaw])


## A pallet with `layers` of cement bags, crossed layer on layer.
func _cement_pallet(mb: MeshBuilder, cols: Array, base: Vector3, layers: int, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wood := Color(0.55, 0.47, 0.37)
	for k in 5:
		mb.box(&"wood", Transform3D(b, base + b * Vector3(0, 0.13, -0.48 + k * 0.24)), Vector3(1.2, 0.022, 0.1), wood)
	for sx: float in [-0.55, 0.0, 0.55]:
		mb.box(&"wood", Transform3D(b, base + b * Vector3(sx, 0.07, 0)), Vector3(0.1, 0.1, 1.0), wood.darkened(0.1))
	for k in 3:
		mb.box(&"wood", Transform3D(b, base + b * Vector3(0, 0.011, -0.45 + k * 0.45)), Vector3(1.2, 0.022, 0.1), wood)
	for layer in layers:
		var y := 0.142 + layer * 0.165
		for k in 4:
			var alt := layer % 2 == 1
			var p := Vector3(-0.26 + (k % 2) * 0.52, y, -0.25 + (k / 2) * 0.5) if not alt else Vector3(-0.3 + (k / 2) * 0.6, y, -0.24 + (k % 2) * 0.48)
			_prop("cement_bag", base + b * p, yaw + (0.0 if not alt else PI * 0.5) + (k - 1.5) * 0.02)
	cols.append([base + Vector3(0, 0.07 + layers * 0.08, 0), Vector3(1.2, 0.14 + layers * 0.165, 1.0), yaw])


## A row of produce crates (CargoModels packages) along X, centred on `center`.
func _crates_on_shelf(center: Vector3, item: StringName, width: float, shadows: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(center) & 0xffff
	var n := maxi(int(width / (CargoModels.SIZE.x + 0.06)), 1)
	for k in n:
		var p := center + Vector3(-width * 0.5 + (k + 0.5) * width / n + rng.randf_range(-0.02, 0.02), 0.0, rng.randf_range(-0.02, 0.02))
		var yaw := rng.randf_range(-0.04, 0.04) + (PI if rng.randf() < 0.5 else 0.0)
		var key := "%s:%d:%d" % [item, k % 2, int(shadows)]
		if not _goods.has(key):
			_goods[key] = []
		(_goods[key] as Array).append(Transform3D(Basis(Vector3.UP, yaw), p))


func _build_goods() -> void:
	for key: String in _goods:
		var parts := key.split(":")
		var list: Array = _goods[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if parts[1] == "still":
			mm.mesh = ItemModels.mesh(StringName(parts[0]))
			parts = PackedStringArray([parts[0], "0", "1"])
		else:
			mm.mesh = CargoModels.mesh(StringName(parts[0]), int(parts[1]))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Goods_" + parts[0]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if parts[2] == "1" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Small detailed props: not voxelized into SDFGI (they still receive GI).
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mmi.visibility_range_end = 45.0
		mmi.visibility_range_end_margin = 5.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


## A park bench: cast-iron ends (legs, arm rests) and slatted seat and back.
func _bench(mb: MeshBuilder, cols: Array, base: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wood := Color(0.5, 0.42, 0.34)
	var iron := Color(0.12, 0.12, 0.13)
	for sx: float in [-0.8, 0.8]:
		mb.box(&"metal", Transform3D(b, base + b * Vector3(sx, 0.22, 0.17)), Vector3(0.05, 0.44, 0.05), iron)
		mb.box(&"metal", Transform3D(b * Basis(Vector3.RIGHT, deg_to_rad(10.0)), base + b * Vector3(sx, 0.4, -0.2)), Vector3(0.05, 0.82, 0.05), iron)
		mb.box(&"metal", Transform3D(b, base + b * Vector3(sx, 0.42, -0.02)), Vector3(0.045, 0.045, 0.46), iron)
		mb.box(&"metal", Transform3D(b, base + b * Vector3(sx, 0.64, 0.05)), Vector3(0.06, 0.035, 0.34), iron)
		mb.box(&"metal", Transform3D(b, base + b * Vector3(sx, 0.53, 0.19)), Vector3(0.035, 0.22, 0.035), iron)
		mb.box(&"metal", Transform3D(b, base + b * Vector3(sx, 0.012, 0.0)), Vector3(0.08, 0.025, 0.5), iron)
	for k in 3:
		mb.box(&"wood", Transform3D(b, base + b * Vector3(0, 0.46, -0.16 + k * 0.16)), Vector3(1.8, 0.04, 0.12), wood.lightened(k * 0.02 - 0.02))
	for k in 2:
		mb.box(&"wood", Transform3D(b * Basis(Vector3.RIGHT, deg_to_rad(-12)), base + b * Vector3(0, 0.66 + k * 0.16, -0.27)), Vector3(1.8, 0.1, 0.03), wood)
	cols.append([base + Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 0.55), yaw])


# --- Car dealership ---------------------------------------------------------------------

func _dealer(mb: MeshBuilder, cols: Array) -> void:
	var y0 := _y(DEALER.get_center().x, DEALER.get_center().y) + 0.15
	var h := 5.6
	BuildingKit.shell(mb, cols, DEALER, y0, h, 0.3, &"t_plaster", Color(0.6, 0.6, 0.6), {
		"s": [{"at": 7.0, "w": 11.0, "bottom": 0.25, "top": 4.8, "glass": false},
			{"at": 15.0, "w": 3.0, "bottom": 0.0, "top": 3.0, "glass": false},
			{"at": 23.0, "w": 11.0, "bottom": 0.25, "top": 4.8, "glass": false}],
		"e": [{"at": 9.0, "w": 5.0, "bottom": 0.0, "top": 3.6, "glass": false}],
	})
	# The showroom's plate glass: clear enough to show the cars inside from the street.
	for cx: float in [DEALER.position.x + 7.0, DEALER.position.x + 23.0]:
		var gz := DEALER.end.y - 0.15
		_glass("DealerGlass").box_at(&"t_showroom_glass", Vector3(cx, y0 + 2.525, gz), Vector3(11.0 - 0.14, 4.55 - 0.14, 0.02), Color.WHITE)
		for k in range(1, 4):
			mb.box_at(&"metal", Vector3(cx - 5.5 + 11.0 * k / 4.0, y0 + 2.525, gz), Vector3(0.05, 4.55, 0.34), Color(0.13, 0.14, 0.15))
		cols.append([Vector3(cx, y0 + 2.525, gz), Vector3(11.0, 4.55, 0.3), 0.0])
	var fz := DEALER.end.y + 0.02
	mb.box_at(&"sign", Vector3(DEALER.get_center().x, y0 + 5.35, fz + 0.1), Vector3(DEALER.size.x + 0.3, 1.0, 0.22), Color(0.1, 0.2, 0.36))
	BuildingKit.sign(self, "YEŞİLOVA OTO GALERİ", Vector3(DEALER.get_center().x, y0 + 5.35, fz + 0.24), 0.0, 140, Color(1, 1, 1))
	# Showroom: polished floor, desk, plants, a car turntable.
	var desk := Vector3(DEALER.position.x + 24.0, y0, DEALER.position.y + 5.0)
	mb.box_at(&"wood_in", desk + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 1.0), Color(0.32, 0.26, 0.2))
	mb.box_at(&"metal", desk + Vector3(0, 0.92, 0), Vector3(2.3, 0.05, 1.1), Color(0.8, 0.8, 0.78))
	mb.box_at(&"metal", desk + Vector3(-0.4, 1.15, -0.2), Vector3(0.6, 0.4, 0.04), Color(0.08, 0.08, 0.09))
	_interactable(desk + Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 1.0), "ACTION_DEALER",
			func() -> void: Game.hud.open_dealer(null))
	# The turntable: a low steel disc with a rubber-edged deck (it takes a car).
	var turntable := Vector3(TURNTABLE.x, y0 + 0.02, TURNTABLE.y)
	mb.cylinder(&"metal", Transform3D(Basis(), turntable), TURNTABLE.z, TURNTABLE.z, 0.1, 64, Color(0.2, 0.2, 0.21))
	# The deck turns (see _turn_showroom): its own mesh, with a ring of seams.
	var deck := MeshBuilder.new()
	deck.cylinder(&"concrete", Transform3D(Basis(), Vector3(0, 0.1, 0)), TURNTABLE.z - 0.06, TURNTABLE.z - 0.06, 0.02, 64, Color(0.62, 0.62, 0.62))
	for k in 12:
		var a := TAU * k / 12.0
		deck.box(&"metal", Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (TURNTABLE.z - 0.5) + Vector3(0, 0.121, 0)),
				Vector3(0.9, 0.004, 0.02), Color(0.35, 0.35, 0.36))
	_deck = MeshInstance3D.new()
	_deck.name = "TurntableDeck"
	_deck.mesh = deck.build(_materials())
	_deck.position = turntable
	_deck.visibility_range_end = 120.0
	add_child(_deck)
	var disc := StaticBody3D.new()
	disc.name = "Turntable"
	var disc_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TURNTABLE.z
	cylinder.height = 0.12
	disc_shape.shape = cylinder
	disc.position = turntable + Vector3(0, 0.06, 0)
	disc.add_child(disc_shape)
	add_child(disc)
	for p: Vector3 in [Vector3(DEALER.position.x + 2.0, y0, DEALER.end.y - 1.6), Vector3(DEALER.end.x - 2.0, y0, DEALER.end.y - 1.6)]:
		mb.cylinder(&"concrete", Transform3D(Basis(), p), 0.35, 0.3, 0.6, 16, Color(0.3, 0.3, 0.3))
		mb.blob(&"foliage", Transform3D(Basis(), p + Vector3(0, 1.0, 0)), 0.55, 2, Color(0.25, 0.4, 0.18), 0.2, 2.0, 7, 0.0, true, 0.0)
	for lx in 4:
		mb.box_at(&"glow", Vector3(DEALER.position.x + 4.0 + lx * 7.3, y0 + h - 0.1, DEALER.get_center().y), Vector3(2.4, 0.04, 0.3), Color(1.0, 0.98, 0.94))
	for lx: float in [-7.5, 7.5]:
		var light := OmniLight3D.new()
		light.position = Vector3(DEALER.get_center().x + lx, y0 + h - 0.8, DEALER.get_center().y)
		light.light_energy = 1.3
		light.omni_range = 13.0
		light.light_color = Color(1.0, 0.97, 0.92)
		add_child(light)
	_showroom_lights(mb, y0, h)
	_showroom_dressing(mb, cols, y0)
	_dealer_dressing(mb, cols, y0)


## What makes a car lot look like one: the Turkish flag on a tall pole on the grass
## west of the lot, feather flags and strings of pennants in front of the showroom
## glass, a campaign banner in the showroom window, the service bay's shutter case,
## downpipes and rain streaks. The colourful bits stay west of the pine at the lot's
## east end (seen through its needles they read as baubles).
func _dealer_dressing(mb: MeshBuilder, cols: Array, y0: float) -> void:
	var lot_y := _y(247, 10.5) + 0.15
	var white := Color(0.78, 0.78, 0.77)
	var pole := Vector3(DEALER_LOT.position.x - 1.0, 0.0, DEALER_LOT.end.y - 1.5)
	pole.y = _y(pole.x, pole.z) - 0.05
	mb.cylinder(&"metal", Transform3D(Basis(), pole), 0.055, 0.035, 8.1, 8, white)
	mb.sphere(&"metal", Transform3D(Basis(), pole + Vector3(0, 8.15, 0)), Vector3(0.07, 0.07, 0.07), 8, 5, Color(0.7, 0.58, 0.25))
	mb.cylinder(&"concrete", Transform3D(Basis(), pole + Vector3(0, -0.05, 0)), 0.24, 0.22, 0.25, 10, Color(0.5, 0.5, 0.49))
	cols.append([pole + Vector3(0, 2.0, 0), Vector3(0.14, 4.0, 0.14), 0.0])
	_cloth(mb, "flag_tr", pole + Vector3(0.05, 7.95, 0), Vector3(0.97, 0, 0.24).normalized(), 1.8, 1.2, 0.13, 0.4)
	# Feather flags along the lot's front edge (poles and arms too thin for shadows).
	var feathers: Array = [[Vector3(DEALER_LOT.position.x + 2.6, lot_y, DEALER_LOT.end.y - 0.3), "feather_blue", 0.3],
		[Vector3(DEALER_LOT.position.x + 12.4, lot_y, DEALER_LOT.end.y - 0.3), "feather_red", -0.4],
		[Vector3(DEALER_LOT.position.x + 17.8, lot_y, DEALER_LOT.end.y - 0.3), "feather_blue", 0.9]]
	for f: Array in feathers:
		var fp: Vector3 = f[0]
		var along := Vector3(cos(float(f[2])), 0, sin(float(f[2])))
		_fine.cylinder(&"metal", Transform3D(Basis(), fp), 0.02, 0.016, 3.5, 6, Color(0.2, 0.2, 0.22))
		_fine.cylinder_between(&"metal", fp + Vector3(0, 3.5, 0), fp + Vector3(0, 3.45, 0) + along * 0.72 + Vector3(0, -0.35, 0), 0.012, 0.01, 5, Color(0.2, 0.2, 0.22))
		mb.cylinder(&"metal", Transform3D(Basis(), fp + Vector3(0, -0.02, 0)), 0.2, 0.2, 0.06, 10, Color(0.15, 0.15, 0.15))
		_cloth(mb, f[1], fp + Vector3(0.025, 3.48, 0), along, 0.72, 2.9, 0.05, float(f[2]) * 3.0, 0.3)
	# Pennant strings from the fascia's west corner along the fascia and down to the
	# feather flags in front of the glass.
	var top_l := Vector3(DEALER.position.x + 0.25, y0 + 4.8, DEALER.end.y + 0.1)
	var top_m := Vector3(DEALER.position.x + 14.0, y0 + 4.8, DEALER.end.y + 0.1)
	_pennants(top_l, (feathers[0][0] as Vector3) + Vector3(0, 3.45, 0), 0.35)
	_pennants(top_l, top_m, 0.3)
	_pennants(top_m, (feathers[1][0] as Vector3) + Vector3(0, 3.45, 0), 0.35)
	_pennants(top_m, (feathers[2][0] as Vector3) + Vector3(0, 3.45, 0), 0.35)
	for hook: Vector3 in [top_l, top_m]:
		_fine.box_at(&"metal", hook + Vector3(0, 0.02, -0.05), Vector3(0.03, 0.03, 0.1), IRON)
	# The campaign banner hung inside the right-hand window.
	_print(mb, "banner", Vector3(DEALER.position.x + 23.0, y0 + 3.9, DEALER.end.y - 0.35), Vector3.BACK, Vector2(3.4, 0.85))
	for sx: float in [-1.7, 1.7]:
		_fine.cylinder_between(&"cloth", Vector3(DEALER.position.x + 23.0 + sx, y0 + 4.32, DEALER.end.y - 0.36), Vector3(DEALER.position.x + 23.0 + sx, y0 + 5.55, DEALER.end.y - 0.36), 0.004, 0.004, 3, Color(0.2, 0.2, 0.2))
	# The service bay on the east side: shutter case over the opening.
	var ex := DEALER.end.x
	var bz0 := DEALER.end.y - 0.3 - 9.0 - 2.5
	var bz1 := bz0 + 5.0
	mb.box_at(&"metal", Vector3(ex + 0.12, y0 + 3.6 + 0.15, (bz0 + bz1) * 0.5), Vector3(0.24, 0.3, 5.16), Color(0.5, 0.51, 0.5))
	for z: float in [bz0 - 0.04, bz1 + 0.04]:
		mb.box_at(&"metal", Vector3(ex + 0.035, y0 + 1.8, z), Vector3(0.07, 3.6, 0.06), Color(0.44, 0.45, 0.44))
	_decal("mud", Vector3(ex + 2.4, _y(ex + 2.4, (bz0 + bz1) * 0.5), (bz0 + bz1) * 0.5), Vector2(4.2, 5.4), 1.2, Color(0.85, 0.85, 0.85, 0.75), 0.8)
	for px: float in [DEALER.position.x - 0.09, DEALER.end.x + 0.09]:
		_downpipe(mb, Vector3(px, y0, DEALER.end.y - 0.4), y0 + 6.5)
	for z: float in [-7.0, -2.0, 4.0]:
		_wall_decal("streaks", Vector3(DEALER.position.x - 0.02, y0 + 6.3, z), Vector3.LEFT, Vector2(2.8, 3.6), Color(1, 1, 1, 0.75))
	for z: float in [-7.5, 4.5]:
		_wall_decal("streaks", Vector3(DEALER.end.x + 0.02, y0 + 6.3, z), Vector3.RIGHT, Vector2(2.8, 3.2), Color(1, 1, 1, 0.7))


## A string of triangular pennants sagging from `a` to `b` (no shadows: see _fine).
func _pennants(a: Vector3, b: Vector3, sag: float) -> void:
	_cable(a, b, sag, 0.004, Color(0.25, 0.25, 0.25))
	var colors := [Color(0.72, 0.1, 0.1), Color(0.85, 0.85, 0.82), Color(0.12, 0.28, 0.6), Color(0.85, 0.66, 0.1), Color(0.15, 0.5, 0.25)]
	var n := int(a.distance_to(b) / 0.42)
	var dir := (b - a).normalized()
	for i in range(1, n):
		var t := float(i) / n
		var p := _sag_point(a, b, sag, t)
		var q := _sag_point(a, b, sag, minf(t + 0.22 / a.distance_to(b), 1.0))
		var tip := (p + q) * 0.5 + Vector3(0, -0.3, 0) + dir.cross(Vector3.UP) * 0.03 * sin(i * 1.7)
		var col: Color = colors[i % colors.size()]
		_fine.tri(&"cloth", p, q, tip, col)
		_fine.tri(&"cloth", q, p, tip, col)


# --- Filling station ------------------------------------------------------------------

## A fuel dispenser: two-tone body on a plinth, a lit brand header, a display on each
## face (price and litres), and on each side a nozzle in its holster with a hose.
func _dispenser(mb: MeshBuilder, base: Vector3, red: Color, white: Color) -> void:
	var dark := Color(0.12, 0.12, 0.13)
	mb.box_at(&"metal", base + Vector3(0, 0.06, 0), Vector3(0.95, 0.12, 0.66), Color(0.3, 0.3, 0.31))
	mb.box_at(&"metal", base + Vector3(0, 0.62, 0), Vector3(0.82, 1.0, 0.56), white)
	mb.box_at(&"metal", base + Vector3(0, 1.38, 0), Vector3(0.78, 0.52, 0.52), white.darkened(0.04))
	# Rounded vertical edges.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.cylinder(&"metal", Transform3D(Basis(), base + Vector3(sx * 0.41, 0.12, sz * 0.28)), 0.02, 0.02, 1.52, 8, white.darkened(0.08))
	# Red band and the lit header with the brand stripe.
	mb.box_at(&"sign", base + Vector3(0, 0.2, 0), Vector3(0.84, 0.14, 0.58), red)
	mb.box_at(&"sign", base + Vector3(0, 1.76, 0), Vector3(0.84, 0.26, 0.6), red)
	mb.box_at(&"glow", base + Vector3(0, 1.76, 0.301), Vector3(0.6, 0.12, 0.01), Color(1.0, 0.95, 0.88))
	mb.box_at(&"glow", base + Vector3(0, 1.76, -0.301), Vector3(0.6, 0.12, 0.01), Color(1.0, 0.95, 0.88))
	for sz: float in [-1.0, 1.0]:
		var face := base + Vector3(0, 0, sz * 0.265)
		# Display: dark glass with lit digit rows and the keypad under it.
		mb.box_at(&"metal", face + Vector3(0, 1.4, sz * 0.012), Vector3(0.62, 0.36, 0.01), dark)
		for row in 3:
			mb.box_at(&"glow", face + Vector3(0.06, 1.5 - row * 0.1, sz * 0.02), Vector3(0.36, 0.05, 0.004), Color(0.55, 1.0, 0.7) if row < 2 else Color(1.0, 0.75, 0.3))
		mb.box_at(&"metal", face + Vector3(-0.23, 1.4, sz * 0.02), Vector3(0.1, 0.28, 0.004), Color(0.25, 0.25, 0.27))
		for kx in 3:
			for ky in 3:
				mb.box_at(&"metal", face + Vector3(-0.11 + kx * 0.05, 1.02 + ky * 0.045, sz * 0.02), Vector3(0.035, 0.03, 0.01), Color(0.7, 0.7, 0.72))
		mb.box_at(&"sign", face + Vector3(0.2, 1.08, sz * 0.02), Vector3(0.16, 0.12, 0.004), Color(0.86, 0.86, 0.82))
		# Grime where boots and bumpers rub the lower panel.
		mb.box_at(&"metal", face + Vector3(0, 0.36, sz * 0.018), Vector3(0.8, 0.18, 0.004), white.darkened(0.25))
	for sx: float in [-1.0, 1.0]:
		# Nozzle holster on the side, the nozzle in it and the hose looping down.
		var side := base + Vector3(sx * 0.42, 0, 0)
		mb.box_at(&"metal", side + Vector3(sx * 0.04, 1.02, 0.08), Vector3(0.06, 0.2, 0.12), dark)
		mb.box_at(&"metal", side + Vector3(sx * 0.08, 1.0, 0.08), Vector3(0.05, 0.08, 0.05), Color(0.2, 0.55, 0.25) if sx < 0 else Color(0.15, 0.15, 0.16))
		mb.cylinder_between(&"metal", side + Vector3(sx * 0.08, 0.96, 0.08), side + Vector3(sx * 0.14, 0.84, 0.13), 0.012, 0.01, 8, Color(0.55, 0.56, 0.58))
		var hose: Array[Vector3] = [side + Vector3(sx * 0.02, 1.28, -0.12), side + Vector3(sx * 0.14, 1.05, -0.16),
			side + Vector3(sx * 0.2, 0.62, -0.08), side + Vector3(sx * 0.2, 0.52, 0.05), side + Vector3(sx * 0.14, 0.72, 0.12),
			side + Vector3(sx * 0.1, 0.94, 0.1)]
		var hr: Array[float] = []
		for i in hose.size():
			hr.append(0.018)
		mb.loft(&"metal", hose, hr, 8, dark.lightened(0.05), false)


func _station(mb: MeshBuilder, cols: Array) -> void:
	var y0 := _y(STATION.get_center().x, STATION.get_center().y) + 0.06
	var red := Color(0.62, 0.1, 0.08)
	var white := Color(0.8, 0.8, 0.78)
	# Canopy on four columns.
	var top := y0 + 5.4
	for cx: float in [CANOPY.position.x + 2.0, CANOPY.end.x - 2.0]:
		for cz: float in [CANOPY.position.y + 2.0, CANOPY.end.y - 2.0]:
			mb.box_at(&"metal", Vector3(cx, y0 + 2.6, cz), Vector3(0.35, 5.2, 0.35), white)
			cols.append([Vector3(cx, y0 + 2.6, cz), Vector3(0.35, 5.2, 0.35), 0.0])
			# Concrete guard round the foot, striped against bumpers.
			for k in 4:
				mb.box_at(&"metal", Vector3(cx, y0 + 0.11 + k * 0.22, cz), Vector3(0.45, 0.22, 0.45),
						Color(0.8, 0.62, 0.1) if k % 2 == 0 else Color(0.08, 0.08, 0.08))
	mb.box_at(&"metal", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.get_center().y), Vector3(CANOPY.size.x, 0.7, CANOPY.size.y), white)
	# The roof deck on top: weathered grey membrane inside a low upstand.
	mb.box_at(&"concrete", Vector3(CANOPY.get_center().x, top + 0.705, CANOPY.get_center().y), Vector3(CANOPY.size.x - 0.3, 0.02, CANOPY.size.y - 0.3), Color(0.36, 0.36, 0.35))
	mb.box_at(&"sign", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.position.y - 0.02), Vector3(CANOPY.size.x + 0.04, 0.5, 0.04), red)
	mb.box_at(&"sign", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.end.y + 0.02), Vector3(CANOPY.size.x + 0.04, 0.5, 0.04), red)
	for ex: float in [CANOPY.position.x - 0.02, CANOPY.end.x + 0.02]:
		mb.box_at(&"sign", Vector3(ex, top + 0.35, CANOPY.get_center().y), Vector3(0.04, 0.5, CANOPY.size.y + 0.04), red)
	# Aluminium edge trims, the grey soffit and its drip edge.
	for ez: float in [CANOPY.position.y - 0.03, CANOPY.end.y + 0.03]:
		mb.box_at(&"metal", Vector3(CANOPY.get_center().x, top + 0.69, ez), Vector3(CANOPY.size.x + 0.08, 0.03, 0.05), Color(0.62, 0.63, 0.64))
		mb.box_at(&"metal", Vector3(CANOPY.get_center().x, top + 0.02, ez), Vector3(CANOPY.size.x + 0.08, 0.03, 0.05), Color(0.62, 0.63, 0.64))
	mb.box_at(&"metal", Vector3(CANOPY.get_center().x, top - 0.005, CANOPY.get_center().y), Vector3(CANOPY.size.x - 0.1, 0.01, CANOPY.size.y - 0.1), Color(0.6, 0.6, 0.6))
	BuildingKit.sign(self, "OVA PETROL", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.position.y - 0.06), PI, 110, Color(1, 1, 1))
	for lx in 3:
		for lz in 2:
			mb.box_at(&"glow", Vector3(CANOPY.position.x + 5.0 + lx * 7.0, top - 0.02, CANOPY.position.y + 3.0 + lz * 4.0), Vector3(1.4, 0.03, 0.8), Color(1.0, 1.0, 0.97))
	var canopy_light := OmniLight3D.new()
	canopy_light.position = Vector3(CANOPY.get_center().x, top - 1.0, CANOPY.get_center().y)
	canopy_light.light_energy = 0.0
	canopy_light.omni_range = 16.0
	canopy_light.visible = false
	add_child(canopy_light)
	_lamps.append(canopy_light)
	# Pump islands.
	for ix: float in [CANOPY.position.x + 7.0, CANOPY.end.x - 7.0]:
		var island := Vector3(ix, y0, CANOPY.get_center().y)
		mb.box_at(&"concrete", island + Vector3(0, 0.1, 0), Vector3(1.3, 0.2, 6.5), Color(0.62, 0.62, 0.6))
		cols.append([island + Vector3(0, 0.1, 0), Vector3(1.3, 0.2, 6.5), 0.0])
		# Striped noses at both ends.
		for sz: float in [-1.0, 1.0]:
			for k in 3:
				mb.box_at(&"concrete", island + Vector3(0, 0.1, sz * (3.25 - 0.1 - k * 0.2)), Vector3(1.31, 0.205, 0.2),
						Color(0.8, 0.62, 0.1) if k % 2 == 0 else Color(0.08, 0.08, 0.08))
		for bz: float in [-3.0, 3.0]:
			mb.cylinder(&"metal", Transform3D(Basis(), island + Vector3(0, 0.2, bz)), 0.1, 0.1, 0.9, 10, Color(0.85, 0.66, 0.1))
			mb.cylinder(&"metal", Transform3D(Basis(), island + Vector3(0, 0.75, bz)), 0.102, 0.102, 0.08, 10, Color(0.08, 0.08, 0.08))
		var pump := island + Vector3(0, 0.2, 0)
		_dispenser(mb, pump, red, white)
		pumps.append(_interactable(pump + Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.6), "ACTION_REFUEL", _refuel.bind(pump), true))
		# A bin and the squeegee bucket on the island.
		var bin := island + Vector3(0.28, 0.2, 1.7)
		mb.cylinder(&"metal", Transform3D(Basis(), bin), 0.17, 0.19, 0.72, 12, Color(0.18, 0.2, 0.2))
		mb.cylinder(&"metal", Transform3D(Basis(), bin + Vector3(0, 0.72, 0)), 0.2, 0.17, 0.08, 12, Color(0.6, 0.6, 0.6))
		var bucket := island + Vector3(-0.3, 0.2, -1.75)
		mb.cylinder(&"metal", Transform3D(Basis(), bucket), 0.14, 0.16, 0.3, 10, Color(0.1, 0.3, 0.55))
		mb.cylinder_between(&"metal", bucket + Vector3(0, 0.1, 0), bucket + Vector3(0.05, 0.75, 0.08), 0.012, 0.012, 5, Color(0.1, 0.1, 0.1))
		mb.box_at(&"metal", bucket + Vector3(0.055, 0.8, 0.085), Vector3(0.26, 0.05, 0.04), Color(0.1, 0.1, 0.1))
	# Kiosk.
	var ky := _y(KIOSK.get_center().x, KIOSK.get_center().y) + 0.15
	BuildingKit.shell(mb, cols, KIOSK, ky, 3.6, 0.25, &"t_plaster", Color(0.62, 0.62, 0.6), {
		"n": [{"at": 4.5, "w": 6.0, "bottom": 0.5, "top": 2.9, "glass": true, "mullions": 1.5},
			{"at": 12.0, "w": 2.2, "bottom": 0.0, "top": 2.6, "glass": false}],
	})
	mb.box_at(&"sign", Vector3(KIOSK.get_center().x, ky + 3.3, KIOSK.position.y - 0.12), Vector3(KIOSK.size.x + 0.2, 0.6, 0.12), red)
	BuildingKit.sign(self, "OVA MARKET", Vector3(KIOSK.position.x + 13.5, ky + 3.3, KIOSK.position.y - 0.19), PI, 80, Color(1, 1, 1))
	_kiosk_front(mb, cols, ky)
	# Price totem.
	var totem := Vector3(STATION.end.x - 1.2, _y(STATION.end.x, 25) + 0.06, STATION.position.y + 2.4)
	mb.box_at(&"metal", totem + Vector3(0, 2.8, 0), Vector3(1.4, 5.6, 0.3), white)
	mb.box_at(&"sign", totem + Vector3(0, 4.9, 0), Vector3(1.44, 1.0, 0.34), red)
	mb.box_at(&"concrete", totem + Vector3(0, 0.15, 0), Vector3(1.7, 0.3, 0.6), Color(0.45, 0.45, 0.44))
	BuildingKit.sign(self, "OVA", totem + Vector3(0, 4.9, -0.2), PI, 120, Color(1, 1, 1))
	BuildingKit.sign(self, "YAKIT\n$%.2f/L" % FUEL_PRICE, totem + Vector3(0, 3.1, -0.17), PI, 70, Color(0.1, 0.1, 0.1), Color(0, 0, 0, 0), false)
	cols.append([totem + Vector3(0, 2.8, 0), Vector3(1.4, 5.6, 0.3), 0.0])


## The kiosk's front (facing -z) and yard: posters in the window, an ice-cream freezer,
## LPG cylinders, a rack of motor oil, tyres and drums by the side wall, the tank vent
## pipes and the fill caps of the underground tanks, the air and water post.
func _kiosk_front(mb: MeshBuilder, cols: Array, ky: float) -> void:
	var fz := KIOSK.position.y
	var gz := fz + 0.16
	_print(mb, "poster_ice", Vector3(KIOSK.end.x - 6.75, ky + 1.65, gz), Vector3.FORWARD, Vector2(0.8, 0.8))
	_print(mb, "poster_oil", Vector3(KIOSK.end.x - 2.25, ky + 1.7, gz), Vector3.FORWARD, Vector2(0.7, 1.05))
	_print(mb, "open", Vector3(KIOSK.end.x - 3.75, ky + 2.1, gz), Vector3.FORWARD, Vector2(0.5, 0.25))
	# Ice-cream freezer by the wall.
	var fr := Vector3(KIOSK.position.x + 1.9, ky - 0.1, fz - 0.36)
	mb.box_at(&"metal", fr + Vector3(0, 0.42, 0), Vector3(1.2, 0.84, 0.62), Color(0.8, 0.8, 0.79))
	_glass("KioskGlass").box_at(&"shop_glass", fr + Vector3(0, 0.855, 0), Vector3(1.12, 0.02, 0.56), Color.WHITE)
	mb.box_at(&"metal", fr + Vector3(0, 0.8, 0), Vector3(1.1, 0.03, 0.54), Color(0.3, 0.45, 0.6))
	_print(mb, "poster_ice", fr + Vector3(0, 0.45, -0.312), Vector3.FORWARD, Vector2(0.5, 0.5))
	cols.append([fr + Vector3(0, 0.42, 0), Vector3(1.2, 0.84, 0.62), 0.0])
	# LPG cage between the door and the window.
	_gas_cage(mb, cols, Vector3(KIOSK.position.x + 8.6, ky - 0.1, fz - 0.36), PI)
	# Motor oil on a rack at the east end.
	var rack := Vector3(KIOSK.end.x - 0.6, ky - 0.1, fz - 0.28)
	for sx: float in [-0.42, 0.42]:
		mb.box_at(&"metal", rack + Vector3(sx, 0.65, 0), Vector3(0.03, 1.3, 0.4), Color(0.25, 0.25, 0.27))
	var oil := [Color(0.85, 0.66, 0.1), Color(0.1, 0.1, 0.12), Color(0.15, 0.35, 0.6)]
	for level in 3:
		var sy := 0.25 + level * 0.4
		mb.box_at(&"metal", rack + Vector3(0, sy, 0), Vector3(0.84, 0.02, 0.4), Color(0.4, 0.4, 0.42))
		for k in 6:
			_fine.box_at(&"veg_gloss", rack + Vector3(-0.33 + k * 0.132, sy + 0.14, (k % 2) * 0.12 - 0.06), Vector3(0.1, 0.26, 0.07), oil[level])
	# Tyres stacked and drums by the kiosk's west wall.
	var wx := KIOSK.position.x - 0.36
	for s in 2:
		for k in 4 - s:
			_prop("old_tyre", Vector3(wx, ky - 0.1 + 0.083 + k * 0.165, fz + 1.4 + s * 0.66), s * 0.7 + k * 0.9, 1.0, Basis(Vector3.RIGHT, PI * 0.5))
	_prop("old_tyre", Vector3(wx - 0.05, ky - 0.1 + 0.3, fz + 2.35), PI * 0.5, 1.0, Basis(Vector3.FORWARD, 0.2))
	_prop("barrel_03", Vector3(wx, ky - 0.1, fz + 3.1), 0.4, 0.92)
	_prop("barrel_03", Vector3(wx - 0.05, ky - 0.1, fz + 3.72), 2.1, 0.92)
	_decal("oil", Vector3(wx - 0.3, ky - 0.1, fz + 3.4), Vector2(1.4, 1.2), 0.7, Color(1, 1, 1, 0.9))
	# Vent pipes of the underground tanks up the east wall; their fill caps in the yard.
	for k in 3:
		var vp := Vector3(KIOSK.end.x + 0.12, ky - 0.1, KIOSK.position.y + 4.2 + k * 0.28)
		mb.cylinder(&"metal", Transform3D(Basis(), vp), 0.04, 0.04, 4.9, 8, GALV)
		mb.cylinder(&"metal", Transform3D(Basis(), vp + Vector3(0, 4.9, 0)), 0.07, 0.06, 0.12, 8, Color(0.3, 0.3, 0.3))
		mb.box_at(&"metal", vp + Vector3(-0.06, 1.2 + k * 0.1, 0), Vector3(0.08, 0.04, 0.1), IRON)
		mb.box_at(&"metal", vp + Vector3(-0.06, 3.4, 0), Vector3(0.08, 0.04, 0.1), IRON)
	var st_top := _y(211, 35) + 0.06
	for k in 3:
		_prop("water_manhole_cover", Vector3(KIOSK.end.x + 3.4 + k * 1.1, st_top - 0.022, KIOSK.position.y + 1.8), k * 1.1, 0.8)
	for p: Array in [[Vector3(KIOSK.end.x + 4.5, st_top + 0.002, KIOSK.position.y + 1.2), Vector3(3.8, 0.004, 0.06)],
			[Vector3(KIOSK.end.x + 4.5, st_top + 0.002, KIOSK.position.y + 2.4), Vector3(3.8, 0.004, 0.06)],
			[Vector3(KIOSK.end.x + 2.6, st_top + 0.002, KIOSK.position.y + 1.8), Vector3(0.06, 0.004, 1.2)],
			[Vector3(KIOSK.end.x + 6.4, st_top + 0.002, KIOSK.position.y + 1.8), Vector3(0.06, 0.004, 1.2)]]:
		mb.box_at(&"paint_in", p[0], p[1], Color(0.75, 0.6, 0.12))
	# The air and water post at the edge of the forecourt.
	var air := Vector3(STATION.end.x - 1.5, st_top, CANOPY.end.y - 0.5)
	mb.box_at(&"metal", air + Vector3(0, 0.6, 0), Vector3(0.32, 1.2, 0.26), Color(0.6, 0.1, 0.08))
	mb.box_at(&"metal", air + Vector3(0, 0.95, -0.132), Vector3(0.2, 0.14, 0.01), Color(0.1, 0.1, 0.1))
	mb.box_at(&"glow", air + Vector3(0, 0.95, -0.138), Vector3(0.14, 0.05, 0.004), Color(1.0, 0.55, 0.2))
	var coil: Array[Vector3] = []
	var coil_r: Array[float] = []
	for k in 13:
		var a := k * 0.55
		coil.append(air + Vector3(-0.2 + cos(a) * 0.12, 0.35 + k * 0.03, sin(a) * 0.12))
		coil_r.append(0.012)
	_fine.loft(&"metal", coil, coil_r, 5, Color(0.08, 0.08, 0.08), false)
	cols.append([air + Vector3(0, 0.6, 0), Vector3(0.35, 1.2, 0.3), 0.0])
	for x: float in [KIOSK.position.x + 3.0, KIOSK.position.x + 12.0]:
		_wall_decal("streaks", Vector3(x, ky + 4.4, fz - 0.14), Vector3.FORWARD, Vector2(3.0, 2.0), Color(1, 1, 1, 0.6))
	_wall_decal("streaks", Vector3(KIOSK.position.x - 0.02, ky + 4.4, KIOSK.get_center().y), Vector3.LEFT, Vector2(4.0, 3.6), Color(1, 1, 1, 0.8))


func _refuel(pump: Vector3) -> void:
	var v := _nearest_owned_vehicle(pump, 7.5)
	if v == null:
		Game.notify(tr("MSG_NO_VEHICLE_AT_PUMP"), UiTheme.RED)
		return
	var cap := float(v.info.get("fuel_capacity", 40.0))
	var want := cap - v.fuel
	if want < 0.5:
		Game.notify(tr("MSG_TANK_FULL"))
		return
	var litres := minf(want, floorf(Economy.money / FUEL_PRICE))
	if litres < 1.0:
		Game.notify(tr("MSG_NOT_ENOUGH_MONEY"), UiTheme.RED)
		return
	var cost := int(ceil(litres * FUEL_PRICE))
	if Economy.spend(cost, "REPORT_FUEL"):
		v.fuel += litres
		Game.notify(tr("MSG_REFUELED") % [roundi(litres), UiTheme.money(cost)], UiTheme.GREEN)
		SideStory.town_goals.note_refuel()


static func _nearest_owned_vehicle(p: Vector3, max_dist: float) -> Vehicle:
	var best: Vehicle = null
	var best_d := max_dist
	for v: Vehicle in Game.world.get_tree().get_nodes_in_group(Vehicle.GROUP):
		# A trailer takes no fuel (the pumps' reach is the short one).
		if not v.owned or (v is Trailer and max_dist < 10.0):
			continue
		var d := v.global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = v
	return best


## The player's vehicle parked by the market (its bed can be sold from), if any.
func vehicle_at_market() -> Vehicle:
	if market_counter == null:
		return null
	var v := _nearest_owned_vehicle(market_counter.global_position, 30.0)
	# An empty trailer nearer the counter than the pickup that tows it: the pickup's bed is meant.
	if v is Trailer and v.cargo.total() == 0 and (v as Trailer).tow != null:
		return (v as Trailer).tow
	return v


## The player's vehicle parked by the Animal Market's hen stall (in the street in front
## will do) with room in its bed, if any (the crates bought there wait at the pickup
## spot, MarketCrates, for the farmer to load them).
func vehicle_at_poultry() -> Vehicle:
	if poultry_stall == null:
		return null
	return LiveCrates.vehicle_near(poultry_stall.global_position)


## Everything the dealership sells, each on its spot (DEALER_SPOTS) with its price
## board; `for_sale` is the Lightbody '90 on the lot. A loaded game puts the ones the
## player bought where they were left.
func _spawn_dealer_stock() -> void:
	dealer_stock.clear()
	for kind: StringName in VehicleTable.FOR_SALE:
		var spot: Vector3 = DEALER_SPOTS.get(kind, Vector3(DEALER_LOT.get_center().x, DEALER_LOT.get_center().y, 90.0))
		var v := Vehicle.create(kind, dealer_spot(kind), true)
		add_child(v)
		v.reset_physics_interpolation()
		dealer_stock.append(v)
		if kind == &"pickup_90":
			for_sale = v
		var board := _price_board(Vector2(spot.x, spot.y), v)
		v.changed.connect(func() -> void: board.visible = not v.owned)
		if Vector2(spot.x, spot.y).distance_to(Vector2(TURNTABLE.x, TURNTABLE.y)) < 0.1:
			_turn_vehicle = v


## The car for sale on the turntable turns slowly with the deck: once it has settled on
## its wheels it is held on display and turned by hand about the deck's middle, wheels
## and all (Vehicle.turn_on_display; a moving deck would drag it about); as soon as it
## is bought, driven or moved off, it is a free body again.
func _turn_showroom(delta: float) -> void:
	if _turn_vehicle == null or not is_instance_valid(_turn_vehicle):
		return
	var v := _turn_vehicle
	var on := not v.owned and v.driver == null \
			and Vector2(v.global_position.x - TURNTABLE.x, v.global_position.z - TURNTABLE.y).length() < 0.6
	if not on:
		# Only the hold of the display is let go: parked elsewhere it is held still as any.
		v.end_display()
		_turn_settle = 2.0
		return
	if _turn_settle > 0.0:
		_turn_settle -= delta
		return
	var step := TURN_SPEED * delta
	v.turn_on_display(step, Vector3(TURNTABLE.x, 0.0, TURNTABLE.y))
	_deck.rotate_y(step)


## Where the dealership shows `kind` (on the floor, the turntable or the lot).
func dealer_spot(kind: StringName) -> Transform3D:
	var spot: Vector3 = DEALER_SPOTS.get(kind, Vector3(DEALER_LOT.get_center().x, DEALER_LOT.get_center().y, 90.0))
	var p := Vector3(spot.x, 0.0, spot.y)
	if showroom_has(p):
		p.y = _y(DEALER.get_center().x, DEALER.get_center().y) + 0.17 + 0.25
		if Vector2(p.x, p.z).distance_to(Vector2(TURNTABLE.x, TURNTABLE.y)) < TURNTABLE.z:
			p.y += 0.12
	else:
		p.y = _y(p.x, p.z) + 0.25
	return Transform3D(Basis(Vector3.UP, deg_to_rad(spot.z)), p)


## Whether `p` is inside the showroom.
static func showroom_has(p: Vector3) -> bool:
	return DEALER.grow(-0.3).has_point(Vector2(p.x, p.z))


## A price board by a vehicle for sale: a yellow A-board on the lot, facing the street,
## or a lit stand beside it in the showroom.
func _price_board(at: Vector2, v: Vehicle) -> Node3D:
	var root := Node3D.new()
	root.name = "PriceBoard_%s" % v.kind
	add_child(root)
	var mb := MeshBuilder.new()
	var inside := showroom_has(Vector3(at.x, 0.0, at.y))
	var base: Vector3
	var yaw := 0.0
	if inside:
		# In front of the car, turned to the glass.
		var fwd := v.global_basis.z
		var side := v.global_basis.x
		base = v.global_position + fwd * (v.body_length() * 0.5 - 0.4) + side * (v.half_width() + 0.55)
		if Vector2(at.x, at.y).distance_to(Vector2(TURNTABLE.x, TURNTABLE.y)) < TURNTABLE.z:
			# Off the turning deck, on the side of the glass.
			base = Vector3(TURNTABLE.x + 1.3, 0.0, TURNTABLE.y + TURNTABLE.z + 0.45)
		base.y = _y(DEALER.get_center().x, DEALER.get_center().y) + 0.17
		var face := (Vector3(base.x, 0.0, DEALER.end.y + 4.0) - Vector3(base.x, 0.0, base.z)).normalized()
		yaw = atan2(face.x, face.z)
		var b := Basis(Vector3.UP, yaw)
		mb.cylinder(&"metal", Transform3D(b, base), 0.18, 0.18, 0.03, 20, Color(0.12, 0.12, 0.13))
		mb.cylinder(&"metal", Transform3D(b, base), 0.02, 0.02, 0.95, 8, Color(0.6, 0.6, 0.62))
		mb.box(&"metal", Transform3D(b * Basis(Vector3.RIGHT, deg_to_rad(-20.0)), base + Vector3(0, 1.0, 0)), Vector3(0.62, 0.42, 0.025), Color(0.08, 0.1, 0.16))
		mb.box(&"sign", Transform3D(b * Basis(Vector3.RIGHT, deg_to_rad(-20.0)), base + Vector3(0, 1.0, 0) + b * Vector3(0, 0, 0.014)), Vector3(0.58, 0.38, 0.004), Color(0.95, 0.95, 0.93))
	else:
		# In front of the car's middle, on the lot's front edge.
		base = Vector3(at.x, _y(at.x, DEALER_LOT.end.y - 0.55) + 0.15, DEALER_LOT.end.y - 0.55)
		var legs := Color(0.2, 0.2, 0.2)
		for sx: float in [-0.42, 0.42]:
			for sz: float in [-0.12, 0.12]:
				mb.cylinder_between(&"metal", base + Vector3(sx, 0, sz * 2.2), base + Vector3(sx, 0.95, sz * 0.3), 0.018, 0.016, 6, legs)
		mb.box(&"sign", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-8.0)), base + Vector3(0, 0.78, 0.07)), Vector3(1.0, 0.56, 0.03), Color(0.95, 0.8, 0.2))
		mb.box(&"sign", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)), base + Vector3(0, 0.78, -0.07)), Vector3(1.0, 0.56, 0.03), Color(0.95, 0.8, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(_materials())
	mi.visibility_range_end = 90.0
	root.add_child(mi)
	var label := BuildingKit.sign(root, UiTheme.money(v.price), Vector3.ZERO, yaw, 72 if inside else 96,
			Color(0.08, 0.1, 0.16) if inside else Color(0.12, 0.1, 0.05), Color(0, 0, 0, 0), false)
	if inside:
		label.position = base + Vector3(0, 1.0, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0.0, 0.03)
		label.rotation = Vector3(deg_to_rad(-20.0), yaw, 0.0)
	else:
		label.position = base + Vector3(0, 0.8, 0.105)
		label.rotation.x = deg_to_rad(-8.0)
	label.visibility_range_end = 60.0
	root.visible = not v.owned
	return root


## Inside the showroom: posters and the campaign banner on the back wall, a stack of
## tyres and a drum of oil by the workshop door, a tyre rack.
func _showroom_dressing(mb: MeshBuilder, cols: Array, y0: float) -> void:
	var back := DEALER.position.y + 0.31
	_print(mb, "banner", Vector3(DEALER.position.x + 11.0, y0 + 3.9, back), Vector3.BACK, Vector2(4.4, 1.1))
	_print(mb, "poster_oil", Vector3(DEALER.position.x + 3.5, y0 + 1.8, back), Vector3.BACK, Vector2(0.8, 1.2))
	_print(mb, "poster_sale", Vector3(DEALER.position.x + 18.5, y0 + 1.8, back), Vector3.BACK, Vector2(0.8, 1.2))
	_print(mb, "hours", Vector3(DEALER.position.x + 21.0, y0 + 1.6, back), Vector3.BACK, Vector2(0.8, 0.4))
	# Tyres stacked by the workshop door, one leaning on them; an oil drum.
	var tx := DEALER.end.x - 1.2
	var tz := DEALER.position.y + 2.2
	for k in 4:
		_prop("old_tyre", Vector3(tx, y0 + 0.02 + 0.083 + k * 0.165, tz), k * 0.9, 1.0, Basis(Vector3.RIGHT, PI * 0.5))
	_prop("old_tyre", Vector3(tx - 0.72, y0 + 0.02 + 0.3, tz + 0.1), PI * 0.5, 1.0, Basis(Vector3.FORWARD, 0.2))
	_prop("barrel_03", Vector3(tx, y0 + 0.02, tz + 1.3), 0.4)
	cols.append([Vector3(tx - 0.3, y0 + 0.4, tz + 0.5), Vector3(1.6, 0.8, 2.0), 0.0])


## Spot lights over the cars in the showroom, and a warm one over the desk.
func _showroom_lights(mb: MeshBuilder, y0: float, h: float) -> void:
	for kind: StringName in DEALER_SPOTS:
		var spot: Vector3 = DEALER_SPOTS[kind]
		if not showroom_has(Vector3(spot.x, 0.0, spot.y)):
			continue
		var at := Vector3(spot.x, y0 + h - 0.12, spot.y)
		mb.cylinder(&"metal", Transform3D(Basis(), at + Vector3(0, -0.12, 0)), 0.12, 0.1, 0.12, 12, Color(0.1, 0.1, 0.11))
		mb.box_at(&"glow", at + Vector3(0, -0.125, 0), Vector3(0.14, 0.01, 0.14), Color(1.0, 0.97, 0.9))
		var l := SpotLight3D.new()
		l.position = at + Vector3(0, -0.2, 0)
		l.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		l.spot_range = 9.0
		l.spot_angle = 44.0
		l.spot_attenuation = 0.7
		l.light_energy = 4.5
		l.light_color = Color(1.0, 0.96, 0.9)
		l.shadow_enabled = false
		add_child(l)
		_showroom_spots.append(l)


## A vehicle just bought: one from the showroom is brought round to the service bay's
## apron (DELIVERY), or the nearest clear spot to it. True when it was moved.
func deliver(v: Vehicle) -> bool:
	if v == null or not showroom_has(v.global_position):
		return false
	v.freeze = false
	var p := Vector3(DELIVERY.x, 0.0, DELIVERY.y)
	p.y = _y(p.x, p.z) + 0.3
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(DELIVERY.z)), p)
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(v.half_width() * 2.0 + 0.2, 1.3, v.body_length() + 0.3)
	q.shape = box
	q.collision_mask = 1
	q.exclude = [v.get_rid()]
	q.transform = Transform3D(xf.basis, p + Vector3(0, 1.1, 0))
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		xf = v.clear_spot_near(xf)
	v.teleport(xf)
	return true


## Grandpa's pickup comes with the farm (a loaded game moves it to where it was left).
## Its roof and bed carry the story's waypoints "truck" and "truck_bed".
func _spawn_farm_truck() -> void:
	farm_truck = Vehicle.create(&"pickup_old", farm_truck_home())
	add_child(farm_truck)
	farm_truck.reset_physics_interpolation()
	# Found by the guide dot (WaypointMarker.anchor) and by the "waypoints" group.
	WaypointMarker.tag(farm_truck.waypoint_roof(), &"truck")
	WaypointMarker.tag(farm_truck.waypoint_bed(), &"truck_bed")
	farm_truck.waypoint_roof().add_to_group(&"waypoints")
	farm_truck.waypoint_bed().add_to_group(&"waypoints")


## Where Grandpa's pickup stands on a new farm: on the warehouse apron, nose to the
## yard (east), tailgate towards the warehouse door.
static func farm_truck_home() -> Transform3D:
	var s := WorldLayout.FARM_TRUCK_SPOT
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(s.x, TerrainData.height(s.x, s.y) + 0.25, s.y))


# --- Animal Market ---------------------------------------------------------------------

## The Animal Market (Hayvan Pazarı): a small farm yard behind the south pavement, where
## the town's livestock dealer keeps a few of every kind he sells. From the street: the
## dealer's office with its porch and, beside it, a timber gate arch with the name board
## over a packed-earth lane that runs down between the pens. West of the lane the coop
## run (a henhouse, hens and whatever else lives in a coop, behind chicken wire) with
## the hen stall at its fence (crated hens) and the hay barn at the back; east of it the
## horse paddock, the cow paddock and the sheep pen, each with a field gate onto the
## lane, troughs, a hay rack or a shelter. The animals on show (MarketHerd) are never
## the player's. E at the office (its street window or the hatch onto the lane), the hen
## stall or a pen's gate opens the market (RancherScreen.open_market), at that pen's
## kind. Crates bought there wait just inside the gate by the hatch (MARKET_PICKUP,
## MarketCrates) for the farmer to carry to the pickup parked in the street.
func _animal_market(cols: Array) -> void:
	var yard := MeshBuilder.new()
	_market_lane(yard)
	_market_office(yard, cols)
	_market_gate(yard, cols)
	_market_pickup_spot()
	_market_paddocks(yard, cols)
	_market_coop_run(yard, cols)
	_hen_stall(yard, cols)
	_market_barn(yard, cols)
	var mi := MeshInstance3D.new()
	mi.name = "MarketYard"
	mi.mesh = yard.build(_materials().merged({&"chicken_net": _net_material()}))
	add_child(mi)
	_market_animals()
	# Where a sheep, cow or horse bought here waits for the farmer's trailer.
	TrailerYard.build_pen(self)


## Where E opens the market on `species` (&"": the whole list); a pen's prompt names
## its kind.
func _market_point(center: Vector3, size: Vector3, prompt_key: String, species: StringName, named := false) -> TownPoint:
	var at := center
	var point := _interactable(center, size, prompt_key,
			func() -> void: Game.hud.rancher_screen.open_market(at, species)) as TownPoint
	if named:
		point.prompt_args = ["ANIMAL_" + String(species).to_upper()]
	return point


## A farm building model (AnimalBuildings) as a node at `at`, turned by `yaw`, its
## colliders into `cols`: {mesh, straw_mesh (trim drawn without shadows), colliders}.
func _farm_building(data: Dictionary, node_name: String, at: Vector3, yaw: float, cols: Array) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	node.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = data["mesh"]
	node.add_child(mi)
	if data.has("straw_mesh"):
		var trim := MeshInstance3D.new()
		trim.mesh = data["straw_mesh"]
		trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trim.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		trim.layers = 2
		trim.visibility_range_end = 70.0
		node.add_child(trim)
	add_child(node)
	for c: Array in data["colliders"]:
		var b := node.transform.basis
		if c.size() > 2:
			b = b * Basis.from_euler((c[2] as Vector3) * (PI / 180.0))
		cols.append([node.transform * (c[0] as Vector3), c[1], b])
	return node


## The lane: packed earth from the pavement through the gate down to the back fence,
## two wheel ruts, straw blown about, mud at the gate and by the pens' gates.
func _market_lane(mb: MeshBuilder) -> void:
	var lane := Rect2(MARKET_LANE.position.x - 0.3, WALK_S.end.y, MARKET_LANE.size.x + 0.6, MARKET_LANE.end.y - WALK_S.end.y)
	var c := lane.get_center()
	var y := _y(c.x, c.y)
	mb.box(&"dirt_old", Transform3D(Basis(), Vector3(c.x, y - 0.035, c.y)), Vector3(lane.size.x, 0.1, lane.size.y), Color(0.34, 0.29, 0.23))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	for k in 3:
		var z := lane.position.y + 4.0 + k * 9.0
		for x: float in [c.x - 0.8, c.x + 0.85]:
			_decal("tyre", Vector3(x, y, z), Vector2(0.55, 9.5), rng.randf_range(-0.03, 0.03), Color(0.5, 0.45, 0.4, 0.95), 0.4)
	# Dried mud and dust in patches down the lane, wetter where the pens' gates are.
	for k in 9:
		var p := Vector2(c.x + rng.randf_range(-1.6, 1.6), lane.position.y + 2.0 + k * 3.0 + rng.randf_range(-0.8, 0.8))
		_decal("dirt", Vector3(p.x, y, p.y), Vector2(rng.randf_range(2.4, 3.6), rng.randf_range(2.0, 3.2)), rng.randf() * TAU,
				Color(0.75, 0.7, 0.65, rng.randf_range(0.6, 0.9)), 0.5)
	for p: Vector2 in [Vector2(c.x, MARKET_LANE.position.y + 1.2), Vector2(c.x + 1.8, 34.0), Vector2(c.x + 2.0, 42.2),
			Vector2(c.x + 1.9, 50.7), Vector2(c.x - 1.5, 42.8), Vector2(c.x - 1.2, 51.0)]:
		_decal("mud", Vector3(p.x, y, p.y), Vector2(rng.randf_range(2.2, 3.4), rng.randf_range(2.0, 3.0)), rng.randf() * TAU,
				Color(1, 1, 1, rng.randf_range(0.7, 0.95)), 0.5)
	for i in 60:
		var sp := Vector3(rng.randf_range(lane.position.x + 0.3, lane.end.x - 0.3), y + 0.016, rng.randf_range(MARKET_LANE.position.y, lane.end.y - 0.4))
		_fine.box(&"straw", Transform3D(Basis(Vector3.UP, rng.randf() * PI), sp), Vector3(rng.randf_range(0.08, 0.22), 0.004, rng.randf_range(0.008, 0.02)),
				Color(0.72, 0.62, 0.4).darkened(rng.randf() * 0.25))


## The dealer's office: a timber shell with a glazed counter window onto the street, a
## door, a hatch with a counter onto the lane (a price board beside it), a tin porch on
## two posts, a bench and drums at the door and square bales against the west wall.
func _market_office(mb: MeshBuilder, cols: Array) -> void:
	var o := RANCH_OFFICE
	var y0 := _y(o.get_center().x, o.get_center().y) + 0.1
	var hatch_z := o.end.y - 0.25 - 3.3
	BuildingKit.shell(mb, cols, o, y0, 3.4, 0.25, &"planks", Color(0.5, 0.46, 0.42), {
		"n": [{"at": 2.6, "w": 2.6, "bottom": 1.0, "top": 2.4, "glass": true},
			{"at": 6.8, "w": 1.6, "bottom": 0.0, "top": 2.4, "glass": false}],
		"e": [{"at": 3.3, "w": 2.2, "bottom": 1.0, "top": 2.2, "glass": false}],
	}, &"floor", false)
	mb.box_at(&"sign", Vector3(o.get_center().x, y0 + 3.9, o.position.y - 0.25), Vector3(6.0, 0.8, 0.1), Color(0.36, 0.22, 0.1))
	BuildingKit.sign(self, "HAYVAN PAZARI", Vector3(o.get_center().x, y0 + 3.9, o.position.y - 0.31), PI, 100, Color(1.0, 0.94, 0.8))
	# The counter under the hatch (inside), its shelf outside, a tin hood over it.
	var wood := Color(0.42, 0.32, 0.22)
	mb.box_at(&"wood_in", Vector3(o.end.x - 0.6, y0 + 0.5, hatch_z), Vector3(0.7, 1.0, 2.4), wood)
	mb.box_at(&"wood", Vector3(o.end.x + 0.12, y0 + 1.0, hatch_z), Vector3(0.34, 0.05, 2.3), wood.lightened(0.08))
	for sz: float in [-0.9, 0.9]:
		BuildingKit.beam(mb, &"wood", Vector3(o.end.x + 0.02, y0 + 0.7, hatch_z + sz), Vector3(o.end.x + 0.26, y0 + 0.97, hatch_z + sz), Vector2(0.05, 0.05), wood)
	BuildingKit.awning(mb, Vector3(o.end.x + 0.02, y0 + 2.45, hatch_z), 2.7, 0.9, Vector2(1, 0), Color(0.5, 0.2, 0.14))
	cols.append([Vector3(o.end.x - 0.6, y0 + 0.5, hatch_z), Vector3(0.7, 1.0, 2.4), 0.0])
	# The price board beside the hatch: what each kind costs, chalked in Turkish.
	var board := Vector3(o.end.x + 0.04, y0 + 1.75, hatch_z + 2.25)
	mb.box_at(&"wood", board, Vector3(0.05, 1.12, 1.0), Color(0.36, 0.28, 0.2))
	mb.box_at(&"paint_in", board + Vector3(0.028, 0.0, 0.0), Vector3(0.004, 1.0, 0.88), Color(0.12, 0.14, 0.13))
	var lines := PackedStringArray(["FİYATLAR"])
	var turkish := TranslationServer.get_translation_object("tr")
	for s: StringName in AnimalTable.ORDER:
		var n := String(turkish.get_message("ANIMAL_" + String(s).to_upper())) if turkish else String(s)
		lines.append("%s  %s" % [n.to_upper(), UiTheme.money(int(AnimalTable.get_species(s).get("adult_price", 0)))])
	var chalk := BuildingKit.sign(self, "\n".join(lines), board + Vector3(0.035, 0.0, 0.0), PI * 0.5, 40, Color(0.93, 0.93, 0.88), Color(0, 0, 0, 0), false)
	chalk.pixel_size = 0.0022
	# Where E opens the market: the hatch (from the lane or behind the counter) and the
	# street window.
	market_office = _market_point(Vector3(o.end.x, y0 + 1.3, hatch_z), Vector3(1.6, 1.2, 2.2), "ACTION_SHOP_ANIMALS", &"")
	_market_point(Vector3(o.end.x - 2.6, y0 + 1.7, o.position.y), Vector3(2.6, 1.4, 0.4), "ACTION_SHOP_ANIMALS", &"")
	# Porch: a corrugated roof on two posts at the office's front corners.
	var post := Color(0.38, 0.32, 0.26)
	var hi := y0 + 3.1
	var lo := y0 + 2.5
	var front := o.position.y - 1.7
	for px: float in [o.position.x + 0.15, o.end.x - 0.15]:
		mb.box_at(&"wood", Vector3(px, (lo + y0) * 0.5 - 0.05, front + 0.1), Vector3(0.12, lo - y0 + 0.1, 0.12), post, Vector3.ZERO, true)
		cols.append([Vector3(px, (lo + y0) * 0.5, front + 0.1), Vector3(0.14, lo - y0, 0.14), 0.0])
	mb.box_at(&"wood", Vector3(o.get_center().x, lo - 0.06, front + 0.1), Vector3(o.size.x, 0.12, 0.1), post)
	var tilt := atan2(hi - lo, o.position.y - front)
	mb.box(&"corrugated_old", Transform3D(Basis(Vector3.RIGHT, -tilt), Vector3(o.get_center().x, (hi + lo) * 0.5 + 0.02, (o.position.y + front) * 0.5 - 0.05)),
			Vector3(o.size.x + 0.4, 0.03, Vector2(o.position.y - front, hi - lo).length() + 0.3), Color(0.56, 0.52, 0.48))
	# A bulb under the porch for the evening.
	var bulb := Vector3(o.end.x - 2.6, lo - 0.3, front + 0.9)
	mb.sphere(&"lamp_glow", Transform3D(Basis(), bulb), Vector3(0.05, 0.06, 0.05), 8, 6, Color(1.0, 0.86, 0.6))
	_market_lamp(bulb - Vector3(0, 0.1, 0), 7.0)
	# A bench and drums by the door.
	_bench(mb, cols, Vector3(o.position.x + 4.6, y0, o.position.y - 0.5), PI)
	_prop("barrel_03", Vector3(o.position.x + 0.7, y0 - 0.1, o.position.y - 0.6), 0.3)
	_prop("barrel_03", Vector3(o.end.x + 0.45, y0 - 0.1, o.end.y - 0.5), 1.9)
	# Square bales stacked against the west wall.
	var bales := Vector3(o.position.x - 0.42, y0 - 0.1, o.position.y + 4.3)
	for layer in 3:
		for k in 5 - layer:
			_square_bale(mb, bales + Vector3(0, 0.2 + layer * 0.4, -1.8 + k * 0.92 + layer * 0.46), (k - 2) * 0.035,
					layer * 0.03 + (k % 2) * 0.03)
	cols.append([bales + Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 4.6), 0.0])


## The pickup spot (MARKET_PICKUP): the crates bought here wait on the lane's packed earth,
## their row along the lane's edge (MarketCrates' +X runs south).
func _market_pickup_spot() -> void:
	var lane := MARKET_LANE.get_center()
	# The lane is a flat slab (see _market_lane): the crates stand on its top.
	var top := maxf(_y(lane.x, (WALK_S.end.y + MARKET_LANE.end.y) * 0.5) + 0.015, _y(MARKET_PICKUP.x, MARKET_PICKUP.y))
	market_crates = MarketCrates.new()
	market_crates.name = "MarketCrates"
	market_crates.position = Vector3(MARKET_PICKUP.x, top, MARKET_PICKUP.y)
	market_crates.rotation.y = -PI * 0.5
	add_child(market_crates)


## A shadowless warm light that comes on with the street lamps.
func _market_lamp(at: Vector3, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 0.0
	light.omni_range = reach
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	_lamps.append(light)


## The gate arch over the lane: two squared posts with knee braces and a beam, the name
## board hung under it on chains (lettered both ways), the two leaves of a timber gate
## swung open against the fences.
func _market_gate(mb: MeshBuilder, cols: Array) -> void:
	var z := MARKET_LANE.position.y + 0.2
	var xa := MARKET_LANE.position.x - 0.15
	var xb := MARKET_LANE.end.x + 0.15
	var y := _y((xa + xb) * 0.5, z)
	var wood := Color(0.44, 0.36, 0.28)
	var top := 4.3
	for x: float in [xa, xb]:
		mb.box_at(&"wood", Vector3(x, y + top * 0.5 - 0.3, z), Vector3(0.24, top + 0.6, 0.24), wood.darkened(0.05), Vector3.ZERO, true)
		mb.box_at(&"stone_ext", Vector3(x, y + 0.12, z), Vector3(0.5, 0.3, 0.5), Color(0.5, 0.49, 0.47))
		cols.append([Vector3(x, y + top * 0.5, z), Vector3(0.3, top, 0.3), 0.0])
		var inward := 1.0 if x == xa else -1.0
		BuildingKit.beam(mb, &"wood", Vector3(x + inward * 0.1, y + top - 1.1, z), Vector3(x + inward * 0.9, y + top - 0.12, z), Vector2(0.12, 0.12), wood)
	BuildingKit.beam(mb, &"wood", Vector3(xa - 0.5, y + top + 0.02, z), Vector3(xb + 0.5, y + top + 0.02, z), Vector2(0.26, 0.22), wood.darkened(0.08))
	# The board on two chains, its name both ways.
	var bc := Vector3((xa + xb) * 0.5, y + top - 0.85, z)
	mb.box_at(&"wood", bc, Vector3(4.2, 0.72, 0.07), Color(0.36, 0.22, 0.1))
	mb.box_at(&"wood", bc + Vector3(0, 0.39, 0), Vector3(4.3, 0.06, 0.1), wood.darkened(0.15))
	mb.box_at(&"wood", bc - Vector3(0, 0.39, 0), Vector3(4.3, 0.06, 0.1), wood.darkened(0.15))
	for sx: float in [-1.6, 1.6]:
		_cable(bc + Vector3(sx, 0.36, 0), Vector3(bc.x + sx, y + top - 0.12, z), 0.0, 0.012, IRON)
	BuildingKit.sign(self, "HAYVAN PAZARI", bc + Vector3(0, 0.02, -0.045), PI, 110, Color(1.0, 0.93, 0.76), Color(0, 0, 0, 0), false)
	BuildingKit.sign(self, "HAYVAN PAZARI", bc + Vector3(0, 0.02, 0.045), 0.0, 110, Color(1.0, 0.93, 0.76), Color(0, 0, 0, 0), false)
	# The gate leaves, open along the sides of the lane.
	_field_gate(mb, Vector3(xa + 0.2, y, z + 0.1), Vector3(xa + 0.25, y, z + 2.75))
	_field_gate(mb, Vector3(xb - 0.2, y, z + 0.1), Vector3(xb - 0.25, y, z + 2.75))
	# Dropped kerbs: concrete ramps up onto the pavement from the lane and from the
	# office door, so nobody has to hop up the pavement's edge.
	_pavement_ramp(mb, cols, MARKET_LANE.position.x - 0.3, MARKET_LANE.end.x + 0.3, 1.1)
	var door_x := RANCH_OFFICE.end.x - 6.8
	_pavement_ramp(mb, cols, door_x - 1.0, door_x + 1.0, 0.9)


## The south pavement's top at `x` (its 8 m slab's, see _pavements).
func _walk_s_top(x: float) -> float:
	var i := clampi(floori((x - WALK_S.position.x) / 8.0), 0, ceili(WALK_S.size.x / 8.0) - 1)
	var s0 := WALK_S.position.x + i * 8.0
	var s1 := minf(s0 + 8.0, WALK_S.end.x)
	return _y((s0 + s1) * 0.5, WALK_S.get_center().y) + 0.15


## A cast concrete ramp (a dropped kerb) from the south pavement's back edge down to
## the ground over `length` metres, from x `x0` to `x1`: in strips of about a metre,
## each starting flush with the slab it meets, with a few grip grooves across it. Its
## collision is the sloped top, so feet and wheels roll up it.
func _pavement_ramp(mb: MeshBuilder, cols: Array, x0: float, x1: float, length: float) -> void:
	var z0 := WALK_S.end.y
	var z1 := z0 + length
	var n := maxi(roundi(x1 - x0), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0 * 10.0)
	for k in n:
		var xa := x0 + (x1 - x0) * k / n
		var xb := x0 + (x1 - x0) * (k + 1) / n
		var xc := (xa + xb) * 0.5
		var head := _walk_s_top(xc)
		var foot := maxf(_y(xa, z1), _y(xb, z1)) + 0.012
		var bottom := foot - 0.2
		var col := Color(0.53, 0.53, 0.51).lightened(rng.randf_range(-0.04, 0.03))
		var p: Array[Vector3] = [Vector3(xa + 0.004, bottom, z0), Vector3(xb - 0.004, bottom, z0), Vector3(xb - 0.004, head, z0),
				Vector3(xa + 0.004, head, z0), Vector3(xa + 0.004, bottom, z1), Vector3(xb - 0.004, bottom, z1),
				Vector3(xb - 0.004, foot, z1), Vector3(xa + 0.004, foot, z1)]
		mb.hexa(&"concrete", p, col)
		var slope := atan2(head - foot, length)
		var b := Basis(Vector3.RIGHT, slope)
		var mid := Vector3(xc, (head + foot) * 0.5, (z0 + z1) * 0.5)
		cols.append([mid - b.y * 0.15, Vector3(xb - xa, 0.3, Vector2(length, head - foot).length()), b])
		for g in 4:
			var t := 0.2 + g * 0.2
			var at := Vector3(xc, lerpf(head, foot, t), lerpf(z0, z1, t)) + b.y * 0.001
			_fine.box(&"concrete", Transform3D(b, at), Vector3(xb - xa - 0.06, 0.004, 0.018), Color(0.3, 0.3, 0.29))
	Game.world.block_grass(Rect2(x0, z0, x1 - x0, length + 0.2))


## A timber five-bar field gate from its hinge `a` to its latch end `b` (on the ground):
## the hanging and latch stiles, five rails, the diagonal brace and iron hinges.
func _field_gate(mb: MeshBuilder, a: Vector3, b: Vector3, h := 1.15) -> void:
	var wood := Color(0.56, 0.53, 0.49)
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	for k in 5:
		var ry := 0.24 + k * (h - 0.32) / 4.0
		BuildingKit.beam(mb, &"fence_wood", a + Vector3(0, ry, 0), b + Vector3(0, ry, 0), Vector2(0.1, 0.035), wood.darkened(k * 0.015))
	for e: Vector3 in [a + dir * 0.04, b - dir * 0.04]:
		BuildingKit.beam(mb, &"fence_wood", e + Vector3(0, 0.12, 0), e + Vector3(0, h + 0.04, 0), Vector2(0.1, 0.07), wood.darkened(0.06))
	BuildingKit.beam(mb, &"fence_wood", a + dir * 0.08 + Vector3(0, 0.26, 0), b - dir * 0.4 + Vector3(0, h - 0.06, 0), Vector2(0.09, 0.035), wood)
	for ry: float in [0.3, h - 0.1]:
		_fine.box(&"metal", Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), a + Vector3(0, ry, 0) + dir * 0.2), Vector3(0.05, 0.05, 0.36), IRON)


## The three paddocks east of the lane (post-and-rail fences, a closed field gate onto
## the lane each, where E opens the market at that kind), with mud where the animals
## stand, a trough in each, a hay rack in the cows' and a lean-to shelter in the sheep's.
func _market_paddocks(mb: MeshBuilder, cols: Array) -> void:
	var x0 := HORSE_PADDOCK.position.x
	var x1 := HORSE_PADDOCK.end.x
	var z0 := HORSE_PADDOCK.position.y
	var z1 := SHEEP_PEN.end.y
	# Round the three, gates on the lane side (built from the south end northward).
	var pts := PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])
	var gaps := PackedInt32Array()
	var pens: Array = [[SHEEP_PEN, &"sheep"], [COW_PADDOCK, &"cow"], [HORSE_PADDOCK, &"horse"]]
	for pen: Array in pens:
		var r: Rect2 = pen[0]
		var gc := r.get_center().y
		pts.append(Vector2(x0, gc + PEN_GATE * 0.5))
		gaps.append(pts.size() - 1)
		pts.append(Vector2(x0, gc - PEN_GATE * 0.5))
	var fence := Fence.new()
	fence.name = "MarketFence"
	fence.points = pts
	fence.gaps = gaps
	fence.closed = true
	fence.seed_value = 41
	add_child(fence)
	for z: float in [COW_PADDOCK.position.y, SHEEP_PEN.position.y]:
		var cross := Fence.new()
		cross.points = PackedVector2Array([Vector2(x0 + 0.25, z), Vector2(x1 - 0.25, z)])
		cross.seed_value = int(z)
		add_child(cross)
	var rng := RandomNumberGenerator.new()
	rng.seed = 881
	for pen: Array in pens:
		var r: Rect2 = pen[0]
		var species: StringName = pen[1]
		var gc := r.get_center().y
		var gy := _y(x0, gc)
		# The closed gate, and where E opens the market at this kind.
		_field_gate(mb, Vector3(x0, gy, gc - PEN_GATE * 0.5 + 0.12), Vector3(x0, gy, gc + PEN_GATE * 0.5 - 0.12))
		cols.append([Vector3(x0, gy + 0.6, gc), Vector3(0.12, 1.2, PEN_GATE), 0.0])
		market_pens[species] = _market_point(Vector3(x0 - 0.1, gy + 0.9, gc), Vector3(0.5, 1.4, PEN_GATE), "ACTION_MARKET_PEN", species, true)
		for i in 3:
			var p := Vector2(rng.randf_range(r.position.x + 2.0, r.end.x - 2.0), rng.randf_range(r.position.y + 1.5, r.end.y - 1.5))
			_decal("mud", Vector3(p.x, _y(p.x, p.y), p.y), Vector2(rng.randf_range(3.5, 5.5), rng.randf_range(3.0, 4.5)), rng.randf() * TAU,
					Color(1, 1, 1, rng.randf_range(0.6, 0.9)), 1.0)
		# A trough along the back fence, mud around it.
		var tz := r.end.y - 0.75 if species != &"sheep" else r.position.y + 0.75
		var t := Vector3(r.end.x - 3.2, _y(r.end.x - 3.2, tz), tz)
		_galv_trough(mb, cols, t, 0.0, 2.4 if species != &"sheep" else 1.8)
		_decal("mud", t + Vector3(0, 0, -0.2 if species != &"sheep" else 0.2), Vector2(3.6, 2.2), 0.0, Color(0.85, 0.85, 0.85, 0.9), 0.5)
		market_avoid[species] = [Rect2(t.x - 1.4, t.z - 0.5, 2.8, 1.0)]
		for s in 18:
			var sp := Vector3(rng.randf_range(r.position.x + 0.5, r.end.x - 0.5), 0.0, rng.randf_range(r.position.y + 0.5, r.end.y - 0.5))
			sp.y = _y(sp.x, sp.z) + 0.006
			_fine.box(&"straw", Transform3D(Basis(Vector3.UP, rng.randf() * PI), sp), Vector3(rng.randf_range(0.08, 0.22), 0.004, rng.randf_range(0.008, 0.02)),
					Color(0.7, 0.6, 0.38))
	# The cows' hay rack against the east fence.
	var rack := Vector3(COW_PADDOCK.end.x - 1.4, _y(COW_PADDOCK.end.x - 1.4, COW_PADDOCK.get_center().y), COW_PADDOCK.get_center().y)
	_hay_rack(mb, cols, rack)
	(market_avoid[&"cow"] as Array).append(Rect2(rack.x - 0.8, rack.z - 1.1, 1.6, 2.2))
	# A round bale in the horses' paddock, its net half pulled away.
	var rb := Vector3(HORSE_PADDOCK.end.x - 2.2, _y(HORSE_PADDOCK.end.x - 2.2, HORSE_PADDOCK.position.y + 2.0), HORSE_PADDOCK.position.y + 2.0)
	_round_bale(mb, cols, rb, 0.4)
	(market_avoid[&"horse"] as Array).append(Rect2(rb.x - 1.0, rb.z - 1.0, 2.0, 2.0))
	# The sheep's lean-to in the back corner.
	var sh := Rect2(SHEEP_PEN.end.x - 5.2, SHEEP_PEN.end.y - 3.0, 4.8, 2.6)
	_lean_to(mb, cols, sh)
	(market_avoid[&"sheep"] as Array).append(sh.grow(0.2))


## A galvanised trough: sheet walls and bottom on two stands, a rolled rim, the water a
## hand below it; along X turned by `yaw`.
func _galv_trough(mb: MeshBuilder, cols: Array, c: Vector3, yaw: float, tw := 2.4) -> void:
	var b := Basis(Vector3.UP, yaw)
	var tg := GALV.darkened(0.15)
	var td := 0.62
	var bot := 0.1
	var rim := 0.56
	mb.box(&"metal", Transform3D(b, c + b * Vector3(0, bot, 0)), Vector3(tw, 0.02, td), tg.darkened(0.1))
	for sz: float in [-1.0, 1.0]:
		mb.box(&"metal", Transform3D(b, c + b * Vector3(0, (bot + rim) * 0.5, sz * (td * 0.5 - 0.01))), Vector3(tw, rim - bot, 0.02), tg)
	for sx: float in [-1.0, 1.0]:
		mb.box(&"metal", Transform3D(b, c + b * Vector3(sx * (tw * 0.5 - 0.01), (bot + rim) * 0.5, 0)), Vector3(0.02, rim - bot, td - 0.04), tg)
	var rc: Array[Vector3] = [c + b * Vector3(-tw * 0.5, rim, -td * 0.5), c + b * Vector3(tw * 0.5, rim, -td * 0.5),
		c + b * Vector3(tw * 0.5, rim, td * 0.5), c + b * Vector3(-tw * 0.5, rim, td * 0.5)]
	for k in 4:
		mb.cylinder_between(&"metal", rc[k], rc[(k + 1) % 4], 0.018, 0.018, 8, tg.lightened(0.08))
	mb.box(&"water_still", Transform3D(b, c + b * Vector3(0, rim - 0.09, 0)), Vector3(tw - 0.04, 0.01, td - 0.04), Color(0.2, 0.23, 0.2))
	for sx: float in [-1.0, 1.0]:
		mb.box(&"metal", Transform3D(b, c + b * Vector3(sx * (tw * 0.5 - 0.25), bot * 0.5 - 0.01, 0)), Vector3(0.08, bot + 0.02, td + 0.08), IRON)
	cols.append([c + Vector3(0, rim * 0.5, 0), Vector3(tw, rim, td) if is_zero_approx(fmod(yaw, PI)) else Vector3(td, rim, tw), 0.0])


## A V-shaped hay rack on legs (along Z): slats down both sides, hay poking through,
## stalks trodden into the mud around it.
func _hay_rack(mb: MeshBuilder, cols: Array, rack: Vector3) -> void:
	var post := Color(0.38, 0.32, 0.26)
	var rl := 1.7
	for sz: float in [-1.0, 1.0]:
		var ez := sz * rl * 0.5
		for sx: float in [-1.0, 1.0]:
			BuildingKit.beam(mb, &"wood", rack + Vector3(sx * 0.5, 0.0, ez), rack + Vector3(sx * 0.5, 1.5, ez), Vector2(0.08, 0.08), post)
			BuildingKit.beam(mb, &"wood", rack + Vector3(sx * 0.5, 1.45, ez), rack + Vector3(0, 0.6, ez), Vector2(0.07, 0.05), post.darkened(0.05))
		BuildingKit.beam(mb, &"wood", rack + Vector3(-0.5, 0.6, ez), rack + Vector3(0.5, 0.6, ez), Vector2(0.07, 0.05), post)
	for sx: float in [-1.0, 1.0]:
		BuildingKit.beam(mb, &"wood", rack + Vector3(sx * 0.5, 1.45, -rl * 0.5), rack + Vector3(sx * 0.5, 1.45, rl * 0.5), Vector2(0.07, 0.07), post)
	BuildingKit.beam(mb, &"wood", rack + Vector3(0, 0.6, -rl * 0.5), rack + Vector3(0, 0.6, rl * 0.5), Vector2(0.07, 0.07), post)
	for k in 7:
		var z := -rl * 0.5 + 0.2 + k * (rl - 0.4) / 6.0
		for sx: float in [-1.0, 1.0]:
			BuildingKit.beam(mb, &"wood", rack + Vector3(0, 0.62, z), rack + Vector3(sx * 0.47, 1.43, z), Vector2(0.035, 0.03), post.lightened(0.05))
	var hay := Color(0.66, 0.58, 0.36)
	mb.box(&"straw", Transform3D(Basis(Vector3.FORWARD, 0.12), rack + Vector3(0.02, 1.02, 0)), Vector3(0.62, 0.36, rl - 0.25), hay)
	mb.box(&"straw", Transform3D(Basis(Vector3.RIGHT, 0.08) * Basis(Vector3.FORWARD, -0.2), rack + Vector3(-0.05, 1.38, 0.1)), Vector3(0.8, 0.24, rl - 0.5), hay.lightened(0.05))
	mb.box(&"straw", Transform3D(Basis(Vector3.FORWARD, 0.35), rack + Vector3(0.1, 1.5, -0.3)), Vector3(0.5, 0.16, 0.7), hay.lightened(0.08))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3307
	for i in 14:
		var sp := rack + Vector3(rng.randf_range(-0.9, 0.9), 0.004, rng.randf_range(-1.1, 1.1))
		_fine.box(&"straw", Transform3D(Basis(Vector3.UP, rng.randf() * PI), sp), Vector3(rng.randf_range(0.2, 0.45), 0.012, rng.randf_range(0.05, 0.12)), hay.lightened(0.1))
	cols.append([rack + Vector3(0, 0.75, 0), Vector3(1.1, 1.5, rl + 0.1), 0.0])


## A square bale of straw (0.46 x 0.4 x 0.9, long side along Z turned by `yaw`) with its
## two strings; `shade` darkens it a little.
func _square_bale(mb: MeshBuilder, c: Vector3, yaw: float, shade := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	mb.box(&"straw", Transform3D(b, c), Vector3(0.46, 0.4, 0.9), Color(0.74, 0.64, 0.4).darkened(shade))
	for sz: float in [-0.22, 0.22]:
		_fine.box(&"cloth", Transform3D(b, c + b * Vector3(0, 0, sz)), Vector3(0.475, 0.415, 0.012), Color(0.62, 0.3, 0.14))


## A round bale lying on its side (axis along X turned by `yaw`), wrapped in net.
func _round_bale(mb: MeshBuilder, cols: Array, c: Vector3, yaw: float) -> void:
	var r := 0.75
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, PI * 0.5)
	mb.cylinder(&"straw", Transform3D(b, c + Vector3(0, r, 0) + Basis(Vector3.UP, yaw) * Vector3(-0.6, 0, 0)), r, r, 1.2, 22,
			Color(0.72, 0.62, 0.38), true, true, Color(0.66, 0.56, 0.34))
	for k in 3:
		var x := -0.45 + k * 0.45
		mb.ring(&"cloth", Transform3D(b, c + Vector3(0, r, 0) + Basis(Vector3.UP, yaw) * Vector3(x, 0, 0)), r + 0.012, r - 0.004, 0.03, 22, Color(0.85, 0.85, 0.8))
	cols.append([c + Vector3(0, r, 0), Vector3(1.2, r * 2.0, r * 2.0), yaw])


## A lean-to field shelter over `r` (open to the north): four posts, a tin roof falling
## to the back, boarded back and sides, bedding straw inside.
func _lean_to(mb: MeshBuilder, cols: Array, r: Rect2) -> void:
	var y := _y(r.get_center().x, r.get_center().y)
	var post := Color(0.4, 0.33, 0.26)
	var hf := 2.2
	var hb := 1.75
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var h := hf if p.y < r.get_center().y else hb
		mb.box_at(&"wood", Vector3(p.x, y + h * 0.5, p.y), Vector3(0.12, h, 0.12), post, Vector3.ZERO, true)
		cols.append([Vector3(p.x, y + h * 0.5, p.y), Vector3(0.14, h, 0.14), 0.0])
	var tilt := atan2(hf - hb, r.size.y)
	mb.box(&"corrugated_old", Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(r.get_center().x, y + (hf + hb) * 0.5 + 0.06, r.get_center().y + 0.1)),
			Vector3(r.size.x + 0.4, 0.03, r.size.y + 0.6), Color(0.55, 0.5, 0.46))
	var boards := Color(0.46, 0.38, 0.3)
	var n := int(r.size.x / 0.2)
	for k in n:
		var bx := r.position.x + (k + 0.5) * r.size.x / n
		mb.box_at(&"planks", Vector3(bx, y + hb * 0.5, r.end.y), Vector3(r.size.x / n - 0.01, hb, 0.03), boards.darkened((k % 3) * 0.04))
	for sx: float in [r.position.x, r.end.x]:
		mb.box_at(&"planks", Vector3(sx, y + hb * 0.5, r.get_center().y + 0.3), Vector3(0.03, hb, r.size.y - 0.6), boards)
	cols.append([Vector3(r.get_center().x, y + hb * 0.5, r.end.y), Vector3(r.size.x, hb, 0.1), 0.0])
	for sx: float in [r.position.x, r.end.x]:
		cols.append([Vector3(sx, y + hb * 0.5, r.get_center().y + 0.3), Vector3(0.1, hb, r.size.y - 0.6), 0.0])
	mb.box_at(&"straw", Vector3(r.get_center().x, y + 0.01, r.get_center().y + 0.3), Vector3(r.size.x - 0.3, 0.02, r.size.y - 0.8), Color(0.72, 0.6, 0.36))


## The coop run west of the lane: chicken wire on posts all round (a wire door onto the
## lane), a henhouse in the back corner, a feeder and a drinker, straw and dust.
func _market_coop_run(mb: MeshBuilder, cols: Array) -> void:
	var r := COOP_RUN
	var y := _y(r.get_center().x, r.get_center().y)
	var post := Color(0.42, 0.36, 0.3)
	var h := 1.7
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		var a := corners[k]
		var b := corners[(k + 1) % 4]
		var n := maxi(1, roundi(a.distance_to(b) / 1.9))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			mb.box_at(&"wood", Vector3(p.x, y + h * 0.5 - 0.1, p.y), Vector3(0.09, h + 0.2, 0.09), post.darkened(0.04 * (i % 2)), Vector3.ZERO, true)
		BuildingKit.beam(mb, &"wood", Vector3(a.x, y + h - 0.04, a.y), Vector3(b.x, y + h - 0.04, b.y), Vector2(0.07, 0.05), post)
		BuildingKit.beam(mb, &"wood", Vector3(a.x, y + 0.06, a.y), Vector3(b.x, y + 0.06, b.y), Vector2(0.12, 0.03), post.darkened(0.1))
		_net(mb, Vector3(a.x, y + 0.02, a.y), Vector3(b.x, y + 0.02, b.y), h - 0.06)
		var mid := (a + b) * 0.5
		cols.append([Vector3(mid.x, y + h * 0.5, mid.y), Vector3(maxf(absf(b.x - a.x), 0.1), h, maxf(absf(b.y - a.y), 0.1)), 0.0])
	# The henhouse: the kit coop's model, its door toward the lane.
	var hc := HENHOUSE.get_center()
	_farm_building(AnimalBuildings.coop(Vector2(HENHOUSE.size.y, HENHOUSE.size.x)), "MarketHenhouse", Vector3(hc.x, _y(hc.x, hc.y), hc.y), PI * 0.5, cols)
	# A hanging feeder and a drinker on bricks, a dust bath, straw.
	var fd := Vector3(r.end.x - 2.2, y, r.position.y + 1.6)
	mb.cylinder(&"metal", Transform3D(Basis(), fd + Vector3(0, 0.12, 0)), 0.2, 0.2, 0.05, 16, GALV.darkened(0.1))
	mb.cylinder(&"metal", Transform3D(Basis(), fd + Vector3(0, 0.16, 0)), 0.1, 0.12, 0.42, 14, GALV)
	mb.cylinder(&"metal", Transform3D(Basis(), fd + Vector3(0, 0.58, 0)), 0.13, 0.02, 0.1, 14, GALV.lightened(0.05))
	var dr := Vector3(r.position.x + 1.3, y, r.position.y + 1.3)
	mb.box_at(&"brick", dr + Vector3(0, 0.06, 0), Vector3(0.4, 0.12, 0.2), Color(0.55, 0.33, 0.25))
	mb.cylinder(&"metal", Transform3D(Basis(), dr + Vector3(0, 0.12, 0)), 0.19, 0.19, 0.04, 16, Color(0.8, 0.25, 0.18))
	mb.cylinder(&"metal", Transform3D(Basis(), dr + Vector3(0, 0.16, 0)), 0.13, 0.13, 0.36, 16, Color(0.85, 0.82, 0.75))
	market_avoid[&"coop"] = [HENHOUSE.grow(0.15), Rect2(fd.x - 0.3, fd.z - 0.3, 0.6, 0.6), Rect2(dr.x - 0.3, dr.z - 0.3, 0.6, 0.6)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2217
	for p: Vector2 in [Vector2(r.get_center().x, r.get_center().y), Vector2(r.position.x + 2.0, r.end.y - 2.0), Vector2(r.end.x - 2.0, r.end.y - 2.5)]:
		_decal("dirt", Vector3(p.x, y, p.y), Vector2(rng.randf_range(3.0, 4.2), rng.randf_range(2.6, 3.6)), rng.randf() * TAU, Color(0.8, 0.75, 0.7, 0.95), 0.5)
	for i in 40:
		var sp := Vector3(rng.randf_range(r.position.x + 0.3, r.end.x - 0.3), y + 0.006, rng.randf_range(r.position.y + 0.3, r.end.y - 0.3))
		_fine.box(&"straw", Transform3D(Basis(Vector3.UP, rng.randf() * PI), sp), Vector3(rng.randf_range(0.08, 0.22), 0.004, rng.randf_range(0.008, 0.02)),
				Color(0.74, 0.63, 0.4).darkened(rng.randf() * 0.15))
	# The wire door onto the lane, south of the stall.
	var dz := r.end.y - 0.9
	mb.box_at(&"wood", Vector3(r.end.x + 0.06, y + 0.9, dz - 0.5), Vector3(0.05, 1.5, 0.06), post)
	mb.box_at(&"wood", Vector3(r.end.x + 0.06, y + 0.9, dz + 0.5), Vector3(0.05, 1.5, 0.06), post)
	mb.box_at(&"wood", Vector3(r.end.x + 0.06, y + 1.63, dz), Vector3(0.05, 0.06, 1.06), post)
	mb.box_at(&"wood", Vector3(r.end.x + 0.06, y + 0.17, dz), Vector3(0.05, 0.06, 1.06), post)
	_fine.box(&"metal", Transform3D(Basis(), Vector3(r.end.x + 0.1, y + 0.95, dz + 0.42)), Vector3(0.05, 0.14, 0.04), IRON)


## A panel of chicken wire from `a` to `b` (on the ground), `h` tall, seen from both sides.
func _net(mb: MeshBuilder, a: Vector3, b: Vector3, h: float) -> void:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	var cell := 0.05
	var uv := Vector2(l / cell, h / (cell * sqrt(3.0)))
	var up := Vector3(0, h, 0)
	mb.quad(&"chicken_net", a, b, b + up, a + up, Color.WHITE, Vector2(0, uv.y), Vector2(uv.x, uv.y), Vector2(uv.x, 0), Vector2(0, 0))


static var _net_mat: StandardMaterial3D


## Galvanised hexagonal wire (a tile of the honeycomb drawn at start-up), alpha
## scissored and two-sided.
static func _net_material() -> StandardMaterial3D:
	if _net_mat:
		return _net_mat
	var w := 48
	var h := 84
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var row := sqrt(3.0) * 0.5
	for py in h:
		for px in w:
			var p := Vector2((px + 0.5) / w, (py + 0.5) / h * 2.0 * row)
			var d1 := 9.0
			var d2 := 9.0
			for j in range(-1, 4):
				for i in range(-1, 3):
					var c := Vector2(i + (0.5 if posmod(j, 2) == 1 else 0.0), j * row)
					var d := p.distance_to(c)
					if d < d1:
						d2 = d1
						d1 = d
					elif d < d2:
						d2 = d
			var edge := 1.0 - smoothstep(0.035, 0.075, d2 - d1)
			img.set_pixel(px, py, Color(0.78, 0.79, 0.8, edge))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.45
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.6
	m.roughness = 0.5
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_net_mat = m
	return m


## The hen stall at the coop run's fence, facing the lane: a timber frame under a rusty
## tin roof falling to the lane, a painted fascia with the name and a striped valance, a
## trestle counter with crated hens on it (live ones), the stock stacked behind, empty
## crates at the side, feed sacks and straw, the price chalked on a board and a bulb for
## the evening. E at the counter buys hens in crates: they wait at the market's pickup
## spot by the gate (MarketCrates) for the farmer to load them into the pickup.
func _hen_stall(mb: MeshBuilder, cols: Array) -> void:
	var c := HEN_STALL.get_center()
	var y0 := _y(c.x, c.y) + 0.02
	var rng := RandomNumberGenerator.new()
	rng.seed = 2217
	# The frame: along z, the front (the lane side, +x) lower than the back.
	var o := Vector3(c.x, y0, c.y)
	var post := Color(0.4, 0.33, 0.25)
	var hw := 1.6
	var hd := 0.8
	var front_h := 2.35
	var back_h := 2.75
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var ph := front_h if sx > 0.0 else back_h
			var pp := o + Vector3(sx * hd, ph * 0.5, sz * hw)
			mb.box_at(&"wood", pp, Vector3(0.1, ph, 0.1), post.lightened(rng.randf_range(-0.05, 0.03)), Vector3.ZERO, true)
			cols.append([pp, Vector3(0.12, ph, 0.12), 0.0])
	for sz: float in [-1.0, 1.0]:
		BuildingKit.beam(mb, &"wood", o + Vector3(hd, front_h - 0.55, sz * hw), o + Vector3(-hd, back_h - 0.4, sz * hw), Vector2(0.08, 0.06), post)
	for sx: float in [-1.0, 1.0]:
		var bh := front_h if sx > 0.0 else back_h
		mb.box_at(&"wood", o + Vector3(sx * hd, bh - 0.06, 0), Vector3(0.09, 0.12, hw * 2.0 + 0.2), post.darkened(0.08))
	# Rusty corrugated roof falling to the lane, the painted fascia with the name.
	var run := hd * 2.0 + 0.7
	var tilt := atan2(back_h - front_h, hd * 2.0)
	var roof_c := o + Vector3(0.12, (front_h + back_h) * 0.5 - 0.12 * tan(tilt) + 0.02, 0)
	mb.box(&"corrugated_old", Transform3D(Basis(Vector3.BACK, -tilt) * Basis(Vector3.UP, PI * 0.5), roof_c), Vector3(hw * 2.0 + 0.6, 0.03, run), Color(0.58, 0.5, 0.44))
	var fascia := o + Vector3(hd + 0.36, front_h + 0.12, 0)
	mb.box_at(&"wood", fascia, Vector3(0.04, 0.34, hw * 2.0 + 0.4), Color(0.52, 0.16, 0.1))
	BuildingKit.sign(self, "TAVUKÇU", fascia + Vector3(0.03, 0.0, 0.0), PI * 0.5, 84, Color(0.98, 0.92, 0.78), Color(0, 0, 0, 0), false)
	for k in 8:
		var vz := -hw - 0.1 + (k + 0.5) * (hw * 2.0 + 0.2) / 8.0
		mb.box_at(&"cloth", o + Vector3(hd + 0.33, front_h - 0.12, vz), Vector3(0.015, 0.24, (hw * 2.0 + 0.2) / 8.0),
				Color(0.86, 0.82, 0.72) if k % 2 == 0 else Color(0.55, 0.2, 0.14), Vector3(0, 0, -8))
	# The trestle counter at the front: plank top on two A-frame trestles.
	var counter := o + Vector3(hd - 0.3, 0, 0)
	var top_y := 0.82
	for k in 4:
		mb.box_at(&"planks", counter + Vector3(-0.27 + k * 0.18, top_y, 0), Vector3(0.17, 0.04, 2.9),
				Color(0.5, 0.45, 0.4).lightened(rng.randf_range(-0.05, 0.05)), Vector3(0, rng.randf_range(-0.4, 0.4), 0))
	for sz: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			mb.box_at(&"wood", counter + Vector3(lean * 0.14, top_y * 0.5 - 0.02, sz * 1.15), Vector3(0.06, top_y, 0.06), post,
					Vector3(0, 0, -lean * 11.0))
		mb.box_at(&"wood", counter + Vector3(0, 0.3, sz * 1.15), Vector3(0.62, 0.05, 0.05), post)
	cols.append([counter + Vector3(0, top_y * 0.5, 0), Vector3(0.72, top_y + 0.04, 2.9), 0.0])
	# Crated hens on the counter (live) and the stock stacked behind (modelled hens).
	var on_top := top_y + 0.02
	for k in 3:
		var hen_xf := Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.06, 0.06) + (PI if k == 1 else 0.0)),
				counter + Vector3(0.02, on_top, -0.85 + k * 0.85))
		_goods_add("chicken_crate:0:1", hen_xf)
		var hen := CrateHen.new()
		hen.name = "StallHen%d" % k
		hen.variant = k + 1
		# Goes out of sight with the crates on show (_build_goods).
		hen.view_range = 44.0
		hen.transform = hen_xf
		add_child(hen)
	for k in 4:
		var layer := k / 2
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.08, 0.08)),
				o + Vector3(-hd + 0.4, layer * (CargoModels.SIZE.y + 0.012), -0.9 + (k % 2) * 0.58 + layer * 0.05))
		_goods_add("chicken_crate:still", xf)
	cols.append([o + Vector3(-hd + 0.4, 0.28, -0.6), Vector3(0.42, 0.56, 1.3), 0.0])
	# Empty crates waiting at the side, feed sacks and a bale of straw.
	for k in 3:
		_goods_add("chicken_crate:1:0", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)),
				o + Vector3(0.1, k * (CargoModels.SIZE.y + 0.012), hw + 0.5)))
	cols.append([o + Vector3(0.1, 0.4, hw + 0.5), Vector3(0.55, 0.8, 0.42), 0.0])
	for k in 2:
		_goods_add("feed:%d:1" % k, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), o + Vector3(-hd + 0.4, 0.0, 0.5 + k * 0.52)))
	_goods_add("hay:0:1", Transform3D(Basis(Vector3.UP, 0.2), o + Vector3(-0.1, 0.0, -hw + 0.3)))
	for i in 9:
		var sp := o + Vector3(rng.randf_range(-hd, hd + 0.8), 0.004, rng.randf_range(-hw, hw))
		_fine.box(&"straw", Transform3D(Basis(Vector3.UP, rng.randf() * PI), sp), Vector3(rng.randf_range(0.15, 0.4), 0.01, rng.randf_range(0.05, 0.12)),
				Color(0.8, 0.68, 0.4))
	# The chalkboard on an easel in the lane, turned to the gate, the price chalked on it.
	var easel := o + Vector3(hd + 0.55, 0, -hw - 0.35)
	var yaw := PI * 0.75
	var board_b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-12.0))
	mb.box(&"wood", Transform3D(board_b, easel + Vector3(0, 0.62, 0)), Vector3(0.62, 0.86, 0.04), post)
	mb.box(&"paint_in", Transform3D(board_b, easel + Vector3(0, 0.64, 0) + board_b.z * 0.022), Vector3(0.54, 0.74, 0.004), Color(0.12, 0.14, 0.13))
	mb.box(&"wood", Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(18.0)), easel + Basis(Vector3.UP, yaw) * Vector3(0, 0.5, -0.2)),
			Vector3(0.05, 1.0, 0.04), post)
	var chalk := BuildingKit.sign(self, "CANLI\nTAVUK\n%s" % UiTheme.money(LiveCrates.price(&"chicken")),
			easel + Vector3(0, 0.66, 0) + board_b.z * 0.03, yaw, 44, Color(0.93, 0.93, 0.88), Color(0, 0, 0, 0), false)
	chalk.rotation.x = deg_to_rad(-12.0)
	# Chalked small enough to stay on the 0.54 m board (the sign default is shop-front size).
	chalk.pixel_size = 0.002
	cols.append([easel + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5), yaw])
	# A bare bulb under the roof for the evening.
	var bulb := o + Vector3(0.1, front_h - 0.25, 0)
	mb.cylinder_between(&"cloth", bulb + Vector3(0, 0.02, 0), bulb + Vector3(0, 0.35, 0), 0.004, 0.004, 5, Color(0.1, 0.1, 0.1))
	mb.sphere(&"lamp_glow", Transform3D(Basis(), bulb), Vector3(0.04, 0.05, 0.04), 8, 6, Color(1.0, 0.86, 0.6))
	_market_lamp(bulb - Vector3(0, 0.08, 0), 6.0)
	var at := counter + Vector3(0.05, 0.62, 0)
	poultry_stall = _market_point(at, Vector3(0.95, 1.0, 3.0), "ACTION_BUY_CHICKENS", &"chicken")
	poultry_marker = Marker3D.new()
	poultry_marker.name = "PoultryMarker"
	poultry_marker.position = o + Vector3(hd + 0.4, front_h + 0.75, 0)
	WaypointMarker.tag(poultry_marker, &"town_chickens")
	poultry_marker.add_to_group(&"waypoints")
	add_child(poultry_marker)


## The hay barn at the back of the coop run: Grandpa's kind of barn (AnimalBuildings),
## its big door onto the lane, a lamp over it, bales stacked inside and out, round bales
## at the end of the lane and the back fence with its field gate.
func _market_barn(mb: MeshBuilder, cols: Array) -> void:
	var r := HAY_BARN
	var c := r.get_center()
	var barn := _farm_building(AnimalBuildings.barn(Vector2(r.size.y, r.size.x)), "MarketBarn", Vector3(c.x, _y(c.x, c.y), c.y), PI * 0.5, cols)
	var y := barn.position.y
	# Bales inside along the back wall, more by the door, round bales at the lane's end.
	for layer in 3:
		for k in 6 - layer:
			_square_bale(mb, Vector3(r.position.x + 0.6 + layer * 0.02, y + 0.22 + layer * 0.4, r.position.y + 1.2 + k * 0.92 + layer * 0.46), 0.0, layer * 0.03)
	for k in 3:
		_square_bale(mb, Vector3(r.end.x + 0.35, y + 0.2, r.end.y - 0.7 - k * 0.5), PI * 0.5 + k * 0.1, 0.02 * k)
	_square_bale(mb, Vector3(r.end.x + 0.35, y + 0.6, r.end.y - 0.95), PI * 0.5 + 0.05, 0.05)
	cols.append([Vector3(r.end.x + 0.35, y + 0.4, r.end.y - 1.2), Vector3(1.0, 0.8, 1.6), 0.0])
	var end := MARKET_LANE.end.y
	_round_bale(mb, cols, Vector3(MARKET_LANE.position.x + 1.2, _y(MARKET_LANE.position.x + 1.2, end - 1.5), end - 1.5), PI * 0.5)
	_round_bale(mb, cols, Vector3(MARKET_LANE.end.x - 1.1, _y(MARKET_LANE.end.x - 1.1, end - 1.3), end - 1.3), PI * 0.5 + 0.15)
	# A lamp over the barn door.
	var door := Vector3(r.end.x + 0.25, y + 3.25, c.y)
	mb.box_at(&"metal", door, Vector3(0.3, 0.14, 0.3), Color(0.14, 0.15, 0.15))
	mb.box_at(&"lamp_glow", door - Vector3(0, 0.08, 0), Vector3(0.22, 0.02, 0.22), Color(1.0, 0.9, 0.7))
	_market_lamp(door - Vector3(-0.3, 0.3, 0), 9.0)
	# The back fence across the lane's end, a closed field gate in it.
	var back := Fence.new()
	back.points = PackedVector2Array([Vector2(r.end.x, end), Vector2(MARKET_LANE.get_center().x - 1.5, end),
			Vector2(MARKET_LANE.get_center().x + 1.5, end), Vector2(HORSE_PADDOCK.position.x - 0.25, end)])
	back.gaps = PackedInt32Array([1])
	back.seed_value = 77
	add_child(back)
	var gy := _y(MARKET_LANE.get_center().x, end)
	_field_gate(mb, Vector3(MARKET_LANE.get_center().x - 1.4, gy, end), Vector3(MARKET_LANE.get_center().x + 1.4, gy, end))
	cols.append([Vector3(MARKET_LANE.get_center().x, gy + 0.6, end), Vector3(3.0, 1.2, 0.12), 0.0])


## The animals on show, a few of each kind the market sells in its pen (the coop's kinds
## in the run).
func _market_animals() -> void:
	herd = MarketHerd.new()
	add_child(herd)
	var run_avoid: Array[Rect2] = []
	run_avoid.assign(market_avoid.get(&"coop", []))
	for species: StringName in AnimalTable.ORDER:
		if String(AnimalTable.get_species(species).get("housing", "")) == "coop":
			herd.add_pen(COOP_RUN.grow(-0.1), species, 5 if species == &"chicken" else 1, 0, run_avoid)
		elif MARKET_PENS.has(species):
			var avoid: Array[Rect2] = []
			avoid.assign(market_avoid.get(species, []))
			herd.add_pen((MARKET_PENS[species] as Rect2).grow(-0.2), species, 3 if species == &"sheep" else 2, 1, avoid)


## The general market's side yard (where its poultry stall used to stand): old concrete
## patched with packed earth, a pallet of cement and a drum.
func _market_side_yard(mb: MeshBuilder, cols: Array) -> void:
	var c := MARKET_SIDE_YARD.get_center()
	var y0 := _y(c.x, c.y) + 0.15
	BuildingKit.slab(mb, cols, MARKET_SIDE_YARD, y0, 0.45, &"concrete", Color(0.5, 0.49, 0.47))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2217
	for i in 4:
		var p := Vector3(rng.randf_range(MARKET_SIDE_YARD.position.x + 0.8, MARKET_SIDE_YARD.end.x - 0.8), y0 + 0.004,
				rng.randf_range(MARKET_SIDE_YARD.position.y + 0.8, MARKET_SIDE_YARD.end.y - 0.8))
		mb.blob(&"dirt_old", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.4, 0.01, 1.0)), p),
				rng.randf_range(0.5, 0.9), 1, Color(0.3, 0.26, 0.2), 0.4, 1.8, 60 + i, 0.0, true)
	_cement_pallet(mb, cols, Vector3(c.x - 1.4, y0, c.y - 1.2), 3, 0.1)
	_cement_pallet(mb, cols, Vector3(c.x + 1.3, y0, c.y - 1.5), 2, -0.06)
	_prop("barrel_03", Vector3(MARKET_SIDE_YARD.end.x - 0.7, y0, MARKET_SIDE_YARD.position.y + 0.7), 0.8)


## One more package on display (see _goods): "item:variant:shadow", or "item:still"
## for a crate with a modelled hen in it (the stock behind the stall).
func _goods_add(key: String, xf: Transform3D) -> void:
	if not _goods.has(key):
		_goods[key] = []
	(_goods[key] as Array).append(xf)


# --- Houses and street furniture ------------------------------------------------------

func _houses(mb: MeshBuilder, cols: Array) -> void:
	var idx := 0
	for spec: Array in [[Rect2(268, -2, 11, 10), "s", Color(0.66, 0.6, 0.52)], [Rect2(270, 31, 11, 10), "n", Color(0.6, 0.64, 0.66)]]:
		var r: Rect2 = spec[0]
		var y0 := _y(r.get_center().x, r.get_center().y) + 0.2
		var front: String = spec[1]
		var ops := {front: [{"at": 2.5, "w": 1.6, "bottom": 0.9, "top": 2.3, "glass": true},
				{"at": 5.5, "w": 1.1, "bottom": 0.0, "top": 2.2, "glass": false},
				{"at": 8.5, "w": 1.6, "bottom": 0.9, "top": 2.3, "glass": true}]}
		BuildingKit.shell(mb, cols, r, y0, 3.0, 0.3, &"t_plaster", spec[2], ops, &"floor", false)
		var door_x := r.position.x + 5.5
		var door_z := r.end.y - 0.15 if front == "s" else r.position.y + 0.15
		if idx == 0:
			# Zeynep's house (ZeynepHome): a working door, the hallway behind it, and the
			# door step to stand on.
			_zeynep_hallway(mb, r, y0)
			cols.append([Vector3(door_x, y0 - 0.1, r.end.y + 0.35), Vector3(1.6, 0.2, 0.7), 0.0])
		else:
			# Door leaf (closed) in the doorway.
			mb.box_at(&"wood", Vector3(door_x, y0 + 1.1, door_z), Vector3(1.0, 2.2, 0.06), Color(0.36, 0.24, 0.16))
			cols.append([Vector3(door_x, y0 + 1.1, door_z), Vector3(1.1, 2.2, 0.3), 0.0])
		# Hip-less gable roof along X over the flat roof slab.
		var rise := 2.2
		mb.prism(&"roof", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(r.get_center().x, y0 + 3.45, r.get_center().y)), r.size.y + 0.8, rise, r.size.x + 0.8, Color(0.5, 0.5, 0.5))
		# Garden fence.
		var garden := Rect2(r.position.x - 1.0, r.end.y if front == "s" else r.position.y - 4.0, r.size.x + 2.0, 4.0)
		var gf := Fence.new()
		var side := "s" if front == "s" else "n"
		var fd := WorldLayout.fence_around(garden, [[side, 0.0, 1.4]])
		gf.points = fd["points"]
		gf.gaps = fd["gaps"]
		gf.closed = true
		if idx == 0:
			# Open along the house: the fence runs from one front corner of the house round
			# the garden to the other, so the door is free.
			var pts := PackedVector2Array([Vector2(r.position.x, garden.position.y + 0.05), Vector2(garden.position.x, garden.position.y + 0.05),
					Vector2(garden.position.x, garden.end.y)])
			var gate := garden.get_center().x
			pts.append(Vector2(gate - 0.7, garden.end.y))
			pts.append(Vector2(gate + 0.7, garden.end.y))
			pts.append_array([Vector2(garden.end.x, garden.end.y), Vector2(garden.end.x, garden.position.y + 0.05),
					Vector2(r.end.x, garden.position.y + 0.05)])
			gf.points = pts
			gf.gaps = PackedInt32Array([3])
			gf.closed = false
		add_child(gf)
		_house_details(mb, r, y0, front == "s", idx)
		if idx == 0:
			var home := ZeynepHome.new()
			home.house = r
			home.floor_y = y0
			home.garden = garden
			add_child(home)
		# The service drop from the pole ends on a bracket on the east wall by the front.
		var drop := Vector3(r.end.x + 0.14, y0 + 2.75, r.end.y - 0.5 if front == "s" else r.position.y + 0.5)
		mb.box_at(&"metal", drop + Vector3(-0.07, 0, 0), Vector3(0.14, 0.04, 0.04), IRON)
		mb.cylinder(&"metal", Transform3D(Basis(), drop + Vector3(0, -0.08, 0)), 0.03, 0.022, 0.08, 8, Color(0.55, 0.6, 0.55))
		_house_drops.append(drop)
		idx += 1


## A lived-in village house: window sills, a door canopy and step with pots of
## geraniums, gutters and downpipes, a chimney, the solar water heater and the
## satellite dish every roof here has, and rain streaks under the sills. The house
## at the back also has a washing line at the side of its front garden.
func _house_details(mb: MeshBuilder, r: Rect2, y0: float, faces_south: bool, idx: int) -> void:
	var s := 1.0 if faces_south else -1.0
	var wall_z := r.end.y if faces_south else r.position.y
	var normal := Vector3(0, 0, s)
	var sill := Color(0.62, 0.61, 0.58)
	for wx: float in ([r.position.x + 2.5, r.position.x + 8.5] if faces_south else [r.end.x - 2.5, r.end.x - 8.5]):
		mb.box_at(&"concrete", Vector3(wx, y0 + 0.86, wall_z + s * 0.06), Vector3(1.8, 0.06, 0.14), sill)
		mb.box_at(&"concrete", Vector3(wx, y0 + 2.4, wall_z + s * 0.03), Vector3(1.8, 0.14, 0.08), sill.darkened(0.05))
		_wall_decal("streaks", Vector3(wx, y0 + 0.84, wall_z + s * 0.02), normal, Vector2(1.7, 0.75), Color(1, 1, 1, 0.75))
	var door_x := r.position.x + 5.5 if faces_south else r.end.x - 5.5
	# The canopy over the door, the step and pots on it.
	mb.box_at(&"concrete", Vector3(door_x, y0 + 2.5, wall_z + s * 0.45), Vector3(1.7, 0.08, 0.9), sill.darkened(0.08))
	for sx: float in [-0.7, 0.7]:
		mb.cylinder_between(&"metal", Vector3(door_x + sx, y0 + 2.46, wall_z + s * 0.85), Vector3(door_x + sx, y0 + 1.9, wall_z + s * 0.02), 0.012, 0.012, 5, IRON)
	mb.box_at(&"concrete", Vector3(door_x, y0 - 0.1, wall_z + s * 0.35), Vector3(1.6, 0.2, 0.7), sill.darkened(0.12))
	for k in 3:
		var pot := Vector3(door_x + (-0.62 if k < 2 else 0.64) + (k % 2) * 0.1, y0, wall_z + s * (0.22 + (k % 2) * 0.3))
		_prop("planter_pot_clay", pot, k * 1.7, 1.5)
		_geranium(mb, pot + Vector3(0, 0.3, 0), 40 + k + idx * 3, Color(0.72, 0.08, 0.1) if (k + idx) % 3 != 1 else Color(0.86, 0.36, 0.52))
	# Gutters along both eaves and downpipes at the front corners.
	var eave_y := y0 + 3.45 + 0.02
	for ez: float in [r.position.y - 0.4, r.end.y + 0.4]:
		mb.cylinder_between(&"metal", Vector3(r.position.x - 0.4, eave_y, ez), Vector3(r.end.x + 0.4, eave_y, ez), 0.065, 0.065, 8, GALV)
	for dx: float in [r.position.x - 0.25, r.end.x + 0.25]:
		_downpipe(mb, Vector3(dx, y0 - 0.2, wall_z + s * 0.4), eave_y + 0.1)
	# Chimney through the back slope.
	var ch := Vector3(r.position.x + 2.2, y0 + 3.45, r.get_center().y - s * 1.6)
	mb.box_at(&"brick", ch + Vector3(0, 1.4, 0), Vector3(0.55, 2.8, 0.55), Color(0.5, 0.5, 0.5))
	mb.box_at(&"concrete", ch + Vector3(0, 2.85, 0), Vector3(0.7, 0.08, 0.7), Color(0.4, 0.4, 0.39))
	mb.box_at(&"metal", ch + Vector3(0, 3.02, 0), Vector3(0.3, 0.26, 0.3), Color(0.2, 0.2, 0.2))
	# Solar water heater on the sunny (south) slope: the panel on the tiles, the tank above.
	var run := r.size.y * 0.5 + 0.4
	var slope := atan2(2.2, run)
	var sx0 := r.end.x - 3.2
	var along_z := r.get_center().y + 2.2
	var surf_y := y0 + 3.45 + 2.2 - (along_z - r.get_center().y) * (2.2 / run)
	var pb := Basis(Vector3.RIGHT, slope)
	for k in 2:
		var pc := Vector3(sx0 + (k - 0.5) * 1.05, surf_y + 0.12, along_z)
		mb.box(&"metal", Transform3D(pb, pc), Vector3(1.0, 0.07, 1.9), Color(0.35, 0.36, 0.38))
		mb.box(&"metal", Transform3D(pb, pc + pb.y * 0.04), Vector3(0.92, 0.01, 1.8), Color(0.05, 0.07, 0.12))
	var tank := Vector3(sx0, surf_y + 0.12 + 1.9 * 0.5 * sin(slope) + 0.45, along_z - 1.9 * 0.5 * cos(slope) - 0.15)
	mb.cylinder_between(&"metal", tank + Vector3(-1.05, 0, 0), tank + Vector3(1.05, 0, 0), 0.27, 0.27, 14, Color(0.78, 0.78, 0.77))
	for sx: float in [-0.8, 0.8]:
		mb.cylinder_between(&"metal", tank + Vector3(sx, -0.25, 0), tank + Vector3(sx, -0.75, 0.3), 0.02, 0.02, 4, GALV)
		mb.cylinder_between(&"metal", tank + Vector3(sx, -0.25, 0), tank + Vector3(sx, -0.55, -0.35), 0.02, 0.02, 4, GALV)
	# Satellite dish on a wall bracket by the front corner.
	var dish := Vector3(r.end.x - 0.6 if faces_south else r.position.x + 0.6, y0 + 2.75, wall_z + s * 0.45)
	var aim := Basis.looking_at(Vector3(0.3, 0.55, s), Vector3.UP)
	mb.cylinder(&"metal", Transform3D(aim * Basis(Vector3.RIGHT, -PI * 0.5), dish), 0.04, 0.34, 0.12, 16, Color(0.78, 0.78, 0.77))
	mb.cylinder_between(&"metal", dish, dish + aim * Vector3(0, -0.12, -0.4), 0.012, 0.012, 4, Color(0.3, 0.3, 0.3))
	mb.cylinder_between(&"metal", dish, Vector3(dish.x, dish.y - 0.05, wall_z + s * 0.02), 0.02, 0.02, 5, Color(0.3, 0.3, 0.3))
	if idx == 1:
		# A washing line along the east end of the front garden, clear of the path.
		var a := Vector3(r.end.x - 0.7, y0 + 1.85, r.position.y - 3.3)
		var b := Vector3(r.end.x - 0.7, y0 + 1.85, r.position.y - 0.6)
		for p: Vector3 in [a, b]:
			mb.cylinder(&"metal", Transform3D(Basis(), Vector3(p.x, y0 - 0.25, p.z)), 0.025, 0.025, 2.15, 6, GALV.darkened(0.2))
			mb.box_at(&"metal", p + Vector3(0, 0.02, 0), Vector3(0.5, 0.04, 0.04), GALV.darkened(0.2))
		for dx: float in [-0.2, 0.2]:
			_cable(a + Vector3(dx, 0, 0), b + Vector3(dx, 0, 0), 0.06, 0.004, Color(0.8, 0.8, 0.78))
		_hang_washing(a + Vector3(0.2, 0, 0), b + Vector3(0.2, 0, 0), 0.06)


## The hallway behind Zeynep's front door (ZeynepHome), for when it stands open: warm
## cream walls under a lower ceiling, a kilim on the wooden floor, a coat rack with her
## jacket and a scarf, a shoe cabinet with a plant and a bowl for keys, shoes by it, two
## framed pictures, a pendant lamp (ZeynepHome lights it) and a painted inner door at
## the far end. Seen only through the doorway: no colliders.
func _zeynep_hallway(mb: MeshBuilder, r: Rect2, y0: float) -> void:
	var dx := r.position.x + 5.5
	var zi := r.end.y - 0.3
	var x0 := dx - 1.45
	var x1 := dx + 1.45
	var z0 := zi - 2.75
	var top := y0 + 2.62
	var wall := Color(0.58, 0.53, 0.45)
	var wood := Color(0.36, 0.27, 0.2)
	var paint := Color(0.88, 0.85, 0.79)
	# Side walls, the far wall round the inner door, and the ceiling.
	for x: float in [x0 - 0.05, x1 + 0.05]:
		mb.box_at(&"plaster_in", Vector3(x, (y0 + top) * 0.5, (z0 + zi) * 0.5), Vector3(0.1, top - y0, zi - z0), wall)
		mb.box_at(&"wood_in", Vector3(x + (0.055 if x < dx else -0.055), y0 + 0.06, (z0 + zi) * 0.5), Vector3(0.012, 0.1, zi - z0), wood, Vector3.ZERO, true)
	var inner_w := 0.84
	var inner_h := 2.04
	for sx: float in [-1.0, 1.0]:
		var w := (x1 - x0 - inner_w) * 0.5
		mb.box_at(&"plaster_in", Vector3(dx + sx * (inner_w * 0.5 + w * 0.5), (y0 + top) * 0.5, z0 - 0.05), Vector3(w, top - y0, 0.1), wall)
	mb.box_at(&"plaster_in", Vector3(dx, (y0 + inner_h + top) * 0.5, z0 - 0.05), Vector3(inner_w, top - y0 - inner_h, 0.1), wall)
	mb.box_at(&"plaster_in", Vector3(dx, top + 0.03, (z0 + zi) * 0.5), Vector3(x1 - x0 + 0.2, 0.06, zi - z0 + 0.1), Color(0.62, 0.6, 0.56))
	# The inner door: a painted panel door in a wooden casing, a brass lever.
	mb.box_at(&"paint_in", Vector3(dx, y0 + inner_h * 0.5, z0 + 0.01), Vector3(inner_w - 0.04, inner_h - 0.02, 0.04), paint)
	for py: float in [0.55, 1.45]:
		mb.box_at(&"paint_in", Vector3(dx, y0 + py, z0 + 0.034), Vector3(inner_w - 0.24, 0.7, 0.01), paint.darkened(0.06))
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"wood_in", Vector3(dx + sx * (inner_w * 0.5 + 0.03), y0 + inner_h * 0.5, z0 + 0.02), Vector3(0.07, inner_h + 0.04, 0.03), wood)
	mb.box_at(&"wood_in", Vector3(dx, y0 + inner_h + 0.04, z0 + 0.02), Vector3(inner_w + 0.13, 0.07, 0.03), wood, Vector3.ZERO, true)
	mb.box_at(&"metal", Vector3(dx + inner_w * 0.5 - 0.1, y0 + 1.02, z0 + 0.05), Vector3(0.11, 0.018, 0.03), Color(0.78, 0.62, 0.3))
	# A kilim on the floor, clear of the front door's swing.
	var rug := Vector3(dx + 0.05, y0 + 0.028, z0 + 1.0)
	mb.box_at(&"cloth", rug, Vector3(1.05, 0.012, 1.55), Color(0.55, 0.13, 0.1))
	mb.box_at(&"cloth", rug + Vector3(0, 0.002, 0), Vector3(0.85, 0.012, 1.35), Color(0.82, 0.72, 0.55))
	mb.box_at(&"cloth", rug + Vector3(0, 0.004, 0), Vector3(0.72, 0.012, 1.22), Color(0.6, 0.16, 0.12))
	for k in 3:
		var c := rug + Vector3(0, 0.006, (k - 1) * 0.38)
		mb.box_at(&"cloth", c, Vector3(0.28, 0.012, 0.28), Color(0.16, 0.2, 0.34), Vector3(0, 45, 0))
		mb.box_at(&"cloth", c + Vector3(0, 0.002, 0), Vector3(0.13, 0.012, 0.13), Color(0.9, 0.6, 0.2), Vector3(0, 45, 0))
	# The coat rack on the east wall by the door, her mustard jacket and a scarf on it.
	var rack_x := x1 - 0.02
	mb.box_at(&"wood_in", Vector3(rack_x, y0 + 1.74, zi - 0.75), Vector3(0.03, 0.1, 0.95), wood, Vector3.ZERO, true)
	for k in 4:
		_fine.box_at(&"metal", Vector3(rack_x - 0.045, y0 + 1.72, zi - 1.1 + k * 0.23), Vector3(0.07, 0.014, 0.014), Color(0.15, 0.15, 0.15))
	var coat := Vector3(rack_x - 0.1, y0 + 1.27, zi - 0.64)
	mb.box_at(&"cloth", coat, Vector3(0.13, 0.86, 0.44), Color(0.64, 0.46, 0.16))
	mb.box_at(&"cloth", coat + Vector3(-0.01, 0.38, 0), Vector3(0.1, 0.12, 0.2), Color(0.58, 0.41, 0.14))
	for sz: float in [-1.0, 1.0]:
		mb.box_at(&"cloth", coat + Vector3(-0.02, -0.02, sz * 0.24), Vector3(0.1, 0.72, 0.08), Color(0.6, 0.43, 0.15), Vector3(sz * -4.0, 0, 0))
	for k in 5:
		mb.box_at(&"cloth", Vector3(rack_x - 0.06, y0 + 1.36 - k * 0.1, zi - 1.1), Vector3(0.05, 0.1, 0.16),
				Color(0.2, 0.36, 0.5) if k % 2 == 0 else Color(0.85, 0.82, 0.74))
	# The shoe cabinet further in, a plant and a bowl for keys on it, shoes by it.
	var cab := Vector3(x1 - 0.17, y0, z0 + 0.62)
	mb.box_at(&"paint_in", cab + Vector3(0, 0.42, 0), Vector3(0.32, 0.84, 0.8), paint)
	mb.box_at(&"wood_in", cab + Vector3(0, 0.855, 0), Vector3(0.36, 0.03, 0.84), Color(0.46, 0.33, 0.22), Vector3.ZERO, true)
	for sz: float in [-1.0, 1.0]:
		mb.box_at(&"paint_in", cab + Vector3(-0.162, 0.42, sz * 0.2), Vector3(0.006, 0.76, 0.37), paint.darkened(0.05))
		mb.box_at(&"metal", cab + Vector3(-0.172, 0.7, sz * 0.03), Vector3(0.014, 0.06, 0.014), Color(0.78, 0.62, 0.3))
	mb.cylinder(&"clay", Transform3D(Basis(), cab + Vector3(0, 0.87, 0.24)), 0.065, 0.085, 0.13, 12, Color(0.62, 0.34, 0.2))
	mb.blob(&"veg", Transform3D(Basis.from_scale(Vector3(1.0, 1.2, 1.0)), cab + Vector3(0, 1.08, 0.24)), 0.13, 1, Color(0.3, 0.46, 0.2), 0.3, 3.0, 7, 0.1)
	mb.cylinder(&"clay", Transform3D(Basis(), cab + Vector3(0.02, 0.87, -0.2)), 0.08, 0.05, 0.04, 14, Color(0.2, 0.36, 0.48))
	for shoe: Array in [[Vector3(x1 - 0.5, y0 + 0.03, z0 + 1.3), Color(0.9, 0.9, 0.88)], [Vector3(x1 - 0.5, y0 + 0.03, z0 + 1.46), Color(0.9, 0.9, 0.88)],
			[Vector3(x1 - 0.72, y0 + 0.03, z0 + 1.3), Color(0.32, 0.2, 0.12)], [Vector3(x1 - 0.72, y0 + 0.03, z0 + 1.44), Color(0.32, 0.2, 0.12)]]:
		var at: Vector3 = shoe[0]
		mb.box_at(&"cloth", at + Vector3(0, 0.04, 0), Vector3(0.26, 0.08, 0.1), shoe[1], Vector3(0, 90, 0))
		mb.box_at(&"cloth", at + Vector3(0.06, 0.1, 0), Vector3(0.1, 0.06, 0.09), (shoe[1] as Color).darkened(0.1), Vector3(0, 90, 0))
	# Two framed pictures on the west wall: a landscape, and Karamel as a puppy.
	for pic: Array in [[z0 + 1.35, Vector2(0.62, 0.48), 0], [z0 + 0.55, Vector2(0.3, 0.38), 1]]:
		var pz: float = pic[0]
		var ps: Vector2 = pic[1]
		var px := x0 + 0.015
		var py := y0 + 1.6
		mb.box_at(&"wood_in", Vector3(px, py, pz), Vector3(0.025, ps.y, ps.x), wood.darkened(0.2))
		mb.box_at(&"paint_in", Vector3(px + 0.014, py, pz), Vector3(0.006, ps.y - 0.06, ps.x - 0.06), Color(0.93, 0.91, 0.86))
		var iw := ps.x - 0.14
		var ih := ps.y - 0.14
		if int(pic[2]) == 0:
			mb.box_at(&"paint_in", Vector3(px + 0.018, py + ih * 0.22, pz), Vector3(0.004, ih * 0.56, iw), Color(0.55, 0.7, 0.85))
			mb.box_at(&"paint_in", Vector3(px + 0.018, py - ih * 0.25, pz), Vector3(0.004, ih * 0.5, iw), Color(0.34, 0.5, 0.26))
			mb.box_at(&"paint_in", Vector3(px + 0.02, py - ih * 0.02, pz - iw * 0.12), Vector3(0.004, ih * 0.22, iw * 0.55), Color(0.26, 0.4, 0.22), Vector3(-14, 0, 0))
			mb.box_at(&"paint_in", Vector3(px + 0.021, py + ih * 0.32, pz + iw * 0.3), Vector3(0.004, 0.05, 0.05), Color(0.98, 0.86, 0.5))
		else:
			mb.box_at(&"paint_in", Vector3(px + 0.018, py, pz), Vector3(0.004, ih, iw), Color(0.78, 0.74, 0.66))
			mb.box_at(&"paint_in", Vector3(px + 0.02, py - ih * 0.1, pz), Vector3(0.004, ih * 0.45, iw * 0.6), Color(0.6, 0.4, 0.22))
			mb.box_at(&"paint_in", Vector3(px + 0.021, py + ih * 0.2, pz), Vector3(0.004, ih * 0.3, iw * 0.4), Color(0.62, 0.42, 0.24))
	# The pendant lamp: a cloth shade over a warm bulb.
	var lamp := Vector3(dx, top - 0.36, zi - 1.7)
	_fine.cylinder_between(&"metal", Vector3(lamp.x, top, lamp.z), lamp + Vector3(0, 0.14, 0), 0.005, 0.005, 4, Color(0.1, 0.1, 0.1))
	mb.cylinder(&"cloth", Transform3D(Basis(), lamp), 0.2, 0.1, 0.16, 16, Color(0.93, 0.86, 0.7))
	mb.sphere(&"glow", Transform3D(Basis(), lamp + Vector3(0, 0.03, 0)), Vector3(0.045, 0.05, 0.045), 8, 5, Color(1.0, 0.82, 0.55))


## A geranium in a pot whose soil is at `soil`: a rosette of leaf cards and a few
## flower heads (umbels of small five-petalled florets) on stalks above them.
func _geranium(mb: MeshBuilder, soil: Vector3, seed_value: int, petal: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 11:
		var ang := TAU * i / 11.0 + rng.randf_range(-0.25, 0.25)
		var dir := Vector3(cos(ang), rng.randf_range(0.45, 1.0), sin(ang)).normalized()
		var d := dir
		var side := d.cross(Vector3.UP).normalized().rotated(d, rng.randf_range(-0.6, 0.6))
		var length := rng.randf_range(0.2, 0.28)
		var rect: Rect2 = NatureModels.BROAD_SCATTER[rng.randi() % 2]
		var shade := (Vector3(d.x, 0.0, d.z) * 0.5 + Vector3.UP).normalized()
		var v := 0.5 * (1.0 + rng.randf_range(-0.1, 0.05))
		mb.card(&"crop_leaves", soil + d * length * 0.5, side * length * 0.9, d * length, rect, shade, Color(v * 0.9, v, v * 0.85), 0.2, 0.8)
	for h in 3:
		var ang := TAU * h / 3.0 + rng.randf_range(-0.4, 0.4)
		var head := soil + Vector3(cos(ang) * 0.09, rng.randf_range(0.3, 0.38), sin(ang) * 0.09)
		_fine.cylinder_between(&"evergreen", soil + Vector3(cos(ang) * 0.03, 0.0, sin(ang) * 0.03), head, 0.005, 0.004, 3,
				Color(0.3, 0.42, 0.2, 0.3), false, false)
		for f in 9:
			var fa := f * 2.4
			var fy := 0.035 * sqrt(1.0 - float(f) / 9.0)
			var fc := head + Vector3(cos(fa), 0.0, sin(fa)) * 0.045 * sqrt(float(f) / 9.0) + Vector3(0, fy, 0)
			var up := (fc - head + Vector3(0, 0.04, 0)).normalized()
			var ax := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
			for k in 5:
				var pd := ax.rotated(up, k * TAU / 5.0 + f)
				_fine.leaf(&"evergreen", fc, (pd + up * 0.25).normalized(), up, 0.022, 0.02, Color(petal, 0.3), Color(petal.lightened(0.1), 0.3))


## The day's wash pegged on a line from `a` to `b` (sagging by `sag`): a towel, a
## shirt with its sleeves hanging, trousers by the waistband, a tea towel. Muted
## colours, a little fold in each. A mesh of its own, taken in when it rains or snows.
func _hang_washing(a: Vector3, b: Vector3, sag: float) -> void:
	var wb := MeshBuilder.new()
	var along := (b - a).normalized()
	var out := along.cross(Vector3.UP).normalized()
	var span := a.distance_to(b)
	var t := 0.08
	var items := [["towel", 0.55, Color(0.72, 0.7, 0.64)], ["shirt", 0.52, Color(0.38, 0.46, 0.58)],
		["trousers", 0.44, Color(0.22, 0.27, 0.36)], ["towel", 0.42, Color(0.5, 0.24, 0.25)]]
	for item: Array in items:
		var w: float = item[1]
		var top := _sag_point(a, b, sag, t + w * 0.5 / span) + Vector3(0, -0.012, 0)
		var col: Color = item[2]
		# Outline in (along, down) metres, as quads of [top-left, top-right] pairs per row.
		var rows: Array = []
		match String(item[0]):
			"towel":
				rows = [[-0.5 * w, 0.5 * w, 0.0], [-0.5 * w, 0.5 * w, 0.35], [-0.49 * w, 0.49 * w, 0.72]]
			"shirt":
				rows = [[-0.5 * w, 0.5 * w, 0.0], [-0.5 * w, 0.5 * w, 0.3], [-0.47 * w, 0.47 * w, 0.68]]
			"trousers":
				rows = [[-0.5 * w, 0.5 * w, 0.0], [-0.52 * w, 0.52 * w, 0.28]]
		for j in rows.size() - 1:
			var r0: Array = rows[j]
			var r1: Array = rows[j + 1]
			var fold0 := out * 0.025 * sin(j * 1.7 + t * 9.0)
			var fold1 := out * 0.025 * sin((j + 1) * 1.7 + t * 9.0)
			var p0 := top + along * float(r0[0]) + Vector3.DOWN * float(r0[2]) + fold0
			var p1 := top + along * float(r0[1]) + Vector3.DOWN * float(r0[2]) + fold0
			var p2 := top + along * float(r1[1]) + Vector3.DOWN * float(r1[2]) + fold1
			var p3 := top + along * float(r1[0]) + Vector3.DOWN * float(r1[2]) + fold1
			wb.quad2(&"cloth", p3, p2, p1, p0, col.darkened(0.04 * j))
		match String(item[0]):
			"shirt":
				# Sleeves hanging down from the shoulders.
				for sd: float in [-1.0, 1.0]:
					var sh := top + along * sd * 0.5 * w + Vector3.DOWN * 0.03
					var p0 := sh
					var p1 := sh + along * sd * 0.12 + Vector3.DOWN * 0.04
					var p2 := sh + along * sd * 0.1 + Vector3.DOWN * 0.5 + out * 0.02
					var p3 := sh + along * sd * -0.03 + Vector3.DOWN * 0.46 + out * 0.02
					if sd > 0.0:
						wb.quad2(&"cloth", p3, p2, p1, p0, col.darkened(0.08))
					else:
						wb.quad2(&"cloth", p0, p1, p2, p3, col.darkened(0.08))
				wb.box(&"cloth", Transform3D(Basis(along, Vector3.UP, out), top + Vector3(0, -0.02, 0) + out * 0.01), Vector3(0.14, 0.05, 0.015), col.lightened(0.1))
			"trousers":
				# Two legs below the seat.
				for sd: float in [-1.0, 1.0]:
					var x0 := 0.03 * sd
					var x1 := 0.52 * w * sd
					var y0 := 0.28
					var p0 := top + along * x0 + Vector3.DOWN * y0
					var p1 := top + along * x1 + Vector3.DOWN * y0
					var p2 := top + along * (x1 - sd * 0.02) + Vector3.DOWN * 0.95 + out * 0.03 * sd
					var p3 := top + along * (x0 + sd * 0.02) + Vector3.DOWN * 0.95 + out * 0.03 * sd
					if sd > 0.0:
						wb.quad2(&"cloth", p3, p2, p1, p0, col.darkened(0.06))
					else:
						wb.quad2(&"cloth", p0, p1, p2, p3, col.darkened(0.06))
		# Two pegs.
		for px: float in [-0.4 * w, 0.4 * w]:
			wb.box(&"veg", Transform3D(Basis(along, Vector3.UP, out), top + along * px + Vector3(0, 0.015, 0)), Vector3(0.012, 0.07, 0.02), Color(0.7, 0.62, 0.45))
		t += (w + 0.12) / span
	_wash = MeshInstance3D.new()
	_wash.name = "Washing"
	_wash.mesh = wb.build(_materials())
	_wash.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_wash.visibility_range_end = 120.0
	add_child(_wash)


## Where a sagging cable from `a` to `b` passes at `t` (0..1).
static func _sag_point(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


## A sagging cable from `a` to `b` (a parabola is close enough to the catenary), into
## the wire mesh that casts no shadow (a shadow map breaks centimetre-thin cables into
## dashes).
func _cable(a: Vector3, b: Vector3, sag: float, radius: float, color := CABLE) -> void:
	var n := clampi(int(a.distance_to(b) / 2.0), 3, 18)
	var pts: Array[Vector3] = []
	var rs: Array[float] = []
	for i in n + 1:
		pts.append(_sag_point(a, b, sag, float(i) / n))
		rs.append(radius)
	_wires.loft(&"t_cable", pts, rs, 4, color, false)


## The overhead line behind the south pavement: wooden poles with cross-arms and
## insulators, a transformer on the pole by the crossing, three conductors and a
## telephone cable from pole to pole, guy wires at both ends (the west one over a stub
## pole), and service drops to the market, the dealership, the livestock office, the vet
## clinic and the houses.
func _power_line(mb: MeshBuilder, cols: Array) -> void:
	var tops: Array[Array] = []
	for p in POLES:
		var base := Vector3(p.x, _y(p.x, p.y) - 0.4, p.y)
		var top := base + Vector3(0, POLE_H + 0.4, 0)
		mb.cylinder(&"wood", Transform3D(Basis(), base), 0.15, 0.11, POLE_H + 0.4, 10, POLE_WOOD)
		mb.cylinder(&"metal", Transform3D(Basis(), top), 0.12, 0.02, 0.1, 8, Color(0.2, 0.2, 0.2))
		# Cross-arm across the line with two braces, three insulators.
		mb.box_at(&"wood", top + Vector3(0, -0.42, 0), Vector3(0.1, 0.1, 1.9), POLE_WOOD.darkened(0.1))
		for sz: float in [-1.0, 1.0]:
			mb.cylinder_between(&"metal", top + Vector3(0.06, -1.05, 0), top + Vector3(0.06, -0.47, sz * 0.62), 0.012, 0.012, 4, IRON)
		var att: Array[Vector3] = []
		for iz: float in [-0.8, 0.0, 0.8]:
			var ip := top + Vector3(0, -0.37, iz) if iz != 0.0 else top + Vector3(0, 0.02, 0.14)
			mb.cylinder(&"metal", Transform3D(Basis(), ip), 0.05, 0.035, 0.16, 8, Color(0.55, 0.6, 0.55))
			att.append(ip + Vector3(0, 0.15, 0))
		# The telephone cable on a hook lower down.
		var tel := base + Vector3(0.14, 6.6, 0)
		mb.box_at(&"metal", tel + Vector3(-0.05, 0, 0), Vector3(0.1, 0.04, 0.04), IRON)
		att.append(tel)
		# Pole number tag and a band of reflective paint.
		mb.box_at(&"metal", base + Vector3(0, 2.4, 0.13), Vector3(0.1, 0.14, 0.01), Color(0.7, 0.7, 0.68))
		cols.append([Vector3(p.x, base.y + 2.4, p.y), Vector3(0.28, 4.0, 0.28), 0.0])
		tops.append(att)
	for i in POLES.size() - 1:
		var span := POLES[i].distance_to(POLES[i + 1])
		for k in 4:
			_cable(tops[i][k], tops[i + 1][k], span * span * (0.0005 if k < 3 else 0.0008), 0.011 if k < 3 else 0.016)
	# Guy wires at both ends, anchored in the ground beyond the last poles. The west one
	# would come down across the vet clinic's front: there a span guy runs high over its
	# yard to a stub pole past the clinic's corner, which is guyed to the ground in turn.
	var stub := Vector3(VET.position.x - 1.0, 0.0, POLES[0].y)
	stub.y = _y(stub.x, stub.z) - 0.4
	mb.cylinder(&"wood", Transform3D(Basis(), stub), 0.12, 0.09, 6.5, 8, POLE_WOOD.darkened(0.05))
	mb.cylinder(&"metal", Transform3D(Basis(), stub + Vector3(0, 6.5, 0)), 0.1, 0.02, 0.08, 8, Color(0.2, 0.2, 0.2))
	cols.append([Vector3(stub.x, stub.y + 2.4, stub.z), Vector3(0.24, 4.0, 0.24), 0.0])
	var stub_top := stub + Vector3(0, 6.2, 0)
	mb.box_at(&"metal", stub_top + Vector3(0.1, 0, 0), Vector3(0.06, 0.12, 0.12), IRON)
	_cable(Vector3(POLES[0].x, POLE_H - 1.0, POLES[0].y), stub_top, 0.05, 0.008, Color(0.35, 0.35, 0.36))
	var last := POLES[POLES.size() - 1]
	for end: Array in [[stub_top, -1.0], [Vector3(last.x, POLE_H - 1.0, last.y), 1.0]]:
		var wire_top: Vector3 = end[0]
		var dir := float(end[1])
		var anchor := Vector3(wire_top.x + dir * 3.2, _y(wire_top.x + dir * 3.2, wire_top.z), wire_top.z)
		_cable(wire_top, anchor + Vector3(0, 0.3, 0), 0.0, 0.008, Color(0.35, 0.35, 0.36))
		mb.cylinder(&"concrete", Transform3D(Basis(), anchor), 0.12, 0.1, 0.3, 8, Color(0.45, 0.45, 0.44))
		# The yellow guard sleeved round the wire's lowest two metres.
		var up_wire := (wire_top - anchor - Vector3(0, 0.3, 0)).normalized()
		mb.cylinder_between(&"metal", anchor + Vector3(0, 0.34, 0), anchor + Vector3(0, 0.34, 0) + up_wire * 1.8, 0.03, 0.03, 8, Color(0.8, 0.66, 0.1))
	# A pole transformer on the pole by the crossing.
	var tp := Vector3(POLES[1].x, 0, POLES[1].y)
	var ty := _y(tp.x, tp.z) + 5.6
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(tp.x, ty, tp.z - 0.42)), 0.3, 0.3, 0.95, 14, Color(0.45, 0.5, 0.46))
	mb.cylinder(&"metal", Transform3D(Basis(), Vector3(tp.x, ty + 0.95, tp.z - 0.42)), 0.31, 0.2, 0.08, 14, Color(0.4, 0.45, 0.41))
	for k in 2:
		var bush := Vector3(tp.x - 0.1 + k * 0.2, ty + 1.03, tp.z - 0.42)
		mb.cylinder(&"metal", Transform3D(Basis(), bush), 0.035, 0.025, 0.2, 6, Color(0.5, 0.35, 0.25))
		_cable(bush + Vector3(0, 0.2, 0), (tops[1][k * 2] as Vector3) + Vector3(0, -0.05, 0), 0.05, 0.007)
	mb.box_at(&"metal", Vector3(tp.x, ty + 0.3, tp.z - 0.13), Vector3(0.1, 0.5, 0.12), IRON)
	# Service drops to the buildings.
	var mk_y := _y(206, 3) + 0.15
	var dl_y := _y(247, -1) + 0.15
	var drops: Array = [
		[0, Vector3(MARKET.position.x - 0.1, mk_y + 5.0, MARKET.end.y - 1.0)],
		[1, Vector3(DEALER.position.x + 0.4, dl_y + 5.2, DEALER.end.y + 0.25)],
		[2, Vector3(RANCH_OFFICE.end.x - 0.3, _y(245, 35) + 3.3, RANCH_OFFICE.position.y - 0.1)],
		[0, Vector3(VET.end.x - 0.15, vet_clinic.floor_y + 3.62, VET.position.y - 0.1)]]
	for d: Array in drops:
		mb.box_at(&"metal", d[1], Vector3(0.12, 0.08, 0.12), IRON)
	for h in _house_drops:
		drops.append([3, h])
	for d: Array in drops:
		var from: Vector3 = tops[d[0]][3]
		var to: Vector3 = d[1]
		_cable(from + Vector3(0, -0.3, 0), to, from.distance_to(to) * 0.02, 0.009)


func _lamps_and_signs(mb: MeshBuilder, cols: Array) -> void:
	for x: float in [190.0, 204.0, 218.0, 232.0, 246.0, 260.0, 274.0]:
		_lamps.append(BuildingKit.street_lamp(self, mb, cols, Vector3(x, _y(x, 14.0) + 0.15, 14.0), Vector2(0, 1)))
	for x: float in [236.0, 250.0, 264.0, 278.0]:
		_lamps.append(BuildingKit.street_lamp(self, mb, cols, Vector3(x, _y(x, 26.1) + 0.15, 26.1), Vector2(0, -1)))
	# Town sign at the western entrance, facing incoming traffic.
	var sp := Vector3(178.0, _y(178, 26.5), 26.5)
	for sz: float in [-1.1, 1.1]:
		mb.box_at(&"metal", sp + Vector3(0, 1.1, sz), Vector3(0.08, 2.2, 0.08), Color(0.3, 0.3, 0.3))
	mb.box_at(&"sign", sp + Vector3(0, 2.0, 0), Vector3(0.06, 0.9, 3.0), Color(0.08, 0.36, 0.2))
	BuildingKit.sign(self, "YEŞİLOVA", sp + Vector3(-0.05, 2.0, 0), -PI * 0.5, 120, Color(1, 1, 1), Color(0, 0, 0, 0), false)
	cols.append([sp + Vector3(0, 1.2, 0), Vector3(0.2, 2.4, 3.0), 0.0])
	# Litter bins: steel drums on a post, a liner showing at the rim.
	for p: Vector3 in [Vector3(193, 0, 12.6), Vector3(229, 0, 12.6), Vector3(265, 0, 12.6)]:
		var base := Vector3(p.x, _y(p.x, p.z) + 0.15, p.z)
		mb.cylinder(&"metal", Transform3D(Basis(), base), 0.2, 0.2, 0.06, 12, Color(0.2, 0.2, 0.2))
		mb.cylinder(&"metal", Transform3D(Basis(), base + Vector3(0, 0.12, 0)), 0.21, 0.22, 0.68, 16, Color(0.16, 0.28, 0.19))
		mb.ring(&"metal", Transform3D(Basis(), base + Vector3(0, 0.78, 0)), 0.235, 0.18, 0.05, 16, Color(0.12, 0.2, 0.14))
		mb.cylinder(&"metal", Transform3D(Basis(), base + Vector3(0, 0.6, 0)), 0.18, 0.2, 0.2, 12, Color(0.03, 0.03, 0.03))
		for k in 4:
			mb.box_at(&"metal", base + Vector3(0, 0.3 + k * 0.1, 0.215), Vector3(0.12, 0.012, 0.012), Color(0.1, 0.16, 0.12))
		cols.append([base + Vector3(0, 0.45, 0), Vector3(0.44, 0.9, 0.44), 0.0])
	_prop("trashbag", Vector3(265.45, _y(265, 12.4) + 0.15, 12.35), 0.8, 0.9)
	_prop("trashbag", Vector3(193.5, _y(193, 12.3) + 0.06, 12.2), 2.5, 0.85)


## Everything else a small street has: name plates on the lamp posts, the speed limit
## and crossing signs, a bus shelter, a municipal rubbish container by the car park,
## the "P" sign, electricity cabinets.
func _street_furniture(mb: MeshBuilder, cols: Array) -> void:
	# Street name plates (both faces) on two lamp posts, the "P" sign at the car park.
	for p: Array in [[Vector3(204.0, 0, 14.0), "plate_ataturk"], [Vector3(260.0, 0, 14.0), "plate_ataturk"], [Vector3(190.0, 0, 14.0), "plate_carsi"]]:
		var at: Vector3 = p[0]
		at.y = _y(at.x, at.z) + 2.75
		mb.box_at(&"metal", at + Vector3(0, 0, 0.09), Vector3(0.72, 0.23, 0.02), Color(0.1, 0.18, 0.4))
		_print(mb, p[1], at + Vector3(0, 0, 0.101), Vector3.BACK, Vector2(0.7, 0.21), Color(0.86, 0.86, 0.86), false)
		_print(mb, p[1], at + Vector3(0, 0, 0.079), Vector3.FORWARD, Vector2(0.7, 0.21), Color(0.86, 0.86, 0.86), false)
		mb.box_at(&"metal", at + Vector3(0, 0, 0.045), Vector3(0.06, 0.06, 0.07), IRON)
	# The "P" on the grass by the car park's entrance corner, clear of turning pickups.
	_sign_post(mb, cols, Vector3(185.35, _y(185.35, 12.7), 12.7), "sign_parking", Vector3.BACK, 2.35)
	# Speed limit at the western entrance, facing incoming traffic.
	_sign_post(mb, cols, Vector3(182.0, _y(182, 25.6), 25.6), "sign_50", Vector3.LEFT, 2.2)
	# The crossing's signs, printed both ways.
	_sign_post(mb, cols, Vector3(CROSSING_X - 2.1, _y(228, 13.5) + 0.15, 13.5), "sign_crossing", Vector3.RIGHT, 2.3, true)
	_sign_post(mb, cols, Vector3(CROSSING_X + 1.95, _y(232, 26.55) + 0.15, 26.55), "sign_crossing", Vector3.LEFT, 2.3, true)
	_bus_stop(mb, cols)
	# The municipality's wheeled rubbish container against the back edge of the car park.
	var bin := Vector3(193.9, _y(194, -1.45) + 0.06, -1.45)
	var galv := GALV.darkened(0.05)
	mb.box_at(&"metal", bin + Vector3(0, 0.62, 0), Vector3(1.36, 0.9, 1.05), galv)
	mb.box(&"metal", Transform3D(Basis(Vector3.RIGHT, -0.06), bin + Vector3(0, 1.1, 0.02)), Vector3(1.4, 0.05, 1.12), Color(0.14, 0.3, 0.18))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.cylinder(&"metal", Transform3D(Basis(), bin + Vector3(sx * 0.55, 0.0, sz * 0.4)), 0.02, 0.02, 0.17, 5, IRON)
			mb.cylinder_between(&"metal", bin + Vector3(sx * 0.55 - 0.02, 0.08, sz * 0.4), bin + Vector3(sx * 0.55 + 0.02, 0.08, sz * 0.4), 0.08, 0.08, 10, Color(0.06, 0.06, 0.06))
	for k in 4:
		mb.box_at(&"metal", bin + Vector3(0, 0.3 + k * 0.2, 0.53), Vector3(1.3, 0.025, 0.012), galv.darkened(0.15))
	cols.append([bin + Vector3(0, 0.6, 0), Vector3(1.36, 1.2, 1.05), 0.0])
	_prop("trashbag", bin + Vector3(0.95, 0.0, 0.1), 1.1, 1.0)
	_prop("trashbag", bin + Vector3(0.85, 0.0, -0.45), 3.9, 0.8)
	_decal("dirt", bin + Vector3(0.2, 0.0, 0.0), Vector2(2.6, 1.8), PI * 0.5, Color(0.6, 0.6, 0.6, 0.9), 0.4)
	# Electricity cabinets.
	for p: Array in [[Vector3(225.6, _y(225.6, 12.95) + 0.06, 12.95), PI], [Vector3(193.0, _y(193, 27.25), 27.25), 0.0]]:
		var at: Vector3 = p[0]
		_prop("utility_box_02", at, p[1])
		mb.box_at(&"concrete", at + Vector3(0, -0.02, 0), Vector3(1.05, 0.12, 0.56), Color(0.46, 0.46, 0.45))
		cols.append([at + Vector3(0, 0.56, 0), Vector3(0.92, 1.12, 0.44), p[1]])


## A road sign on a galvanised post: `region` of the print atlas facing `normal`.
func _sign_post(mb: MeshBuilder, cols: Array, base: Vector3, region: String, normal: Vector3, height: float, both := false) -> void:
	mb.cylinder(&"metal", Transform3D(Basis(), base), 0.03, 0.03, height + 0.3, 6, GALV)
	var at := base + Vector3(0, height, 0) + normal * 0.04
	var round_sign := region == "sign_50"
	if round_sign:
		mb.cylinder(&"metal", Transform3D(Basis.looking_at(normal, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), at - normal * 0.015), 0.3, 0.3, 0.012, 20, GALV.darkened(0.2))
	else:
		mb.box(&"metal", Transform3D(Basis.looking_at(normal, Vector3.UP), at - normal * 0.012), Vector3(0.62, 0.62, 0.012), GALV.darkened(0.2))
	_print(mb, region, at, normal, Vector2(0.6, 0.6), Color(0.86, 0.86, 0.86))
	if both:
		_print(mb, region, at - normal * 0.026, -normal, Vector2(0.6, 0.6), Color(0.86, 0.86, 0.86))
	for k in 2:
		mb.box(&"metal", Transform3D(Basis.looking_at(normal, Vector3.UP), base + Vector3(0, height - 0.18 + k * 0.36, 0) - normal * 0.005), Vector3(0.08, 0.03, 0.04), IRON)
	cols.append([base + Vector3(0, 1.2, 0), Vector3(0.08, 2.4, 0.08), 0.0])


## A bus shelter on a concrete pad behind the south pavement, open to the street:
## steel frame, glazed back and side, a flat roof with the stop's sign, a bench and
## the timetable.
func _bus_stop(mb: MeshBuilder, cols: Array) -> void:
	var c := Vector3(BUS_STOP.x, _y(BUS_STOP.x, BUS_STOP.y), BUS_STOP.y)
	var w := 3.2
	var d := 1.45
	var h := 2.45
	var frame := Color(0.22, 0.24, 0.26)
	mb.box_at(&"concrete", c + Vector3(0, 0.02, 0.05), Vector3(w + 0.5, 0.18, d + 0.45), Color(0.5, 0.5, 0.49))
	var fl := c.y + 0.11
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"metal", Vector3(c.x + sx * w * 0.5, fl + h * 0.5, c.z + sz * d * 0.5), Vector3(0.07, h, 0.07), frame)
	mb.box_at(&"metal", Vector3(c.x, fl + h + 0.06, c.z), Vector3(w + 0.3, 0.12, d + 0.3), frame)
	mb.box_at(&"metal", Vector3(c.x, fl + h + 0.125, c.z), Vector3(w + 0.26, 0.01, d + 0.26), Color(0.4, 0.42, 0.44))
	# Glazing: the back and the east side; rails top and bottom.
	_glass("BusShelterGlass").box_at(&"shop_glass", Vector3(c.x, fl + 1.25, c.z + d * 0.5), Vector3(w - 0.07, 2.1, 0.012), Color.WHITE)
	_glass("BusShelterGlass").box_at(&"shop_glass", Vector3(c.x + w * 0.5, fl + 1.25, c.z), Vector3(0.012, 2.1, d - 0.07), Color.WHITE)
	for y: float in [fl + 0.18, fl + 2.33]:
		mb.box_at(&"metal", Vector3(c.x, y, c.z + d * 0.5), Vector3(w, 0.05, 0.05), frame)
		mb.box_at(&"metal", Vector3(c.x + w * 0.5, y, c.z), Vector3(0.05, 0.05, d), frame)
	cols.append([Vector3(c.x, fl + 1.2, c.z + d * 0.5), Vector3(w, 2.4, 0.1), 0.0])
	cols.append([Vector3(c.x + w * 0.5, fl + 1.2, c.z), Vector3(0.1, 2.4, d), 0.0])
	# Bench along the back, the timetable on the side glass, the sign on the roof edge.
	var bench := Vector3(c.x - 0.2, fl, c.z + d * 0.5 - 0.3)
	for sx: float in [-0.85, 0.85]:
		mb.box_at(&"metal", bench + Vector3(sx, 0.22, 0), Vector3(0.05, 0.44, 0.34), frame)
	for k in 3:
		mb.box_at(&"wood", bench + Vector3(0, 0.46, -0.11 + k * 0.11), Vector3(1.9, 0.035, 0.09), Color(0.45, 0.36, 0.27))
	cols.append([bench + Vector3(0, 0.25, 0), Vector3(1.9, 0.5, 0.35), 0.0])
	_print(mb, "timetable", Vector3(c.x + w * 0.5 - 0.02, fl + 1.5, c.z + 0.1), Vector3.LEFT, Vector2(0.55, 0.55))
	_print(mb, "sign_bus", Vector3(c.x - w * 0.5 + 0.35, fl + h + 0.4, c.z - d * 0.5 - 0.1), Vector3.FORWARD, Vector2(0.5, 0.5))
	_print(mb, "sign_bus", Vector3(c.x - w * 0.5 + 0.35, fl + h + 0.4, c.z - d * 0.5 - 0.115), Vector3.BACK, Vector2(0.5, 0.5))
	mb.box_at(&"metal", Vector3(c.x - w * 0.5 + 0.35, fl + h + 0.4, c.z - d * 0.5 - 0.107), Vector3(0.52, 0.52, 0.01), GALV.darkened(0.2))
	mb.box_at(&"metal", Vector3(c.x - w * 0.5 + 0.35, fl + h + 0.1, c.z - d * 0.5 - 0.107), Vector3(0.04, 0.2, 0.04), frame)
	_decal("dirt", Vector3(c.x, fl, c.z - 0.2), Vector2(3.6, 1.4), PI, Color(0.7, 0.7, 0.7, 0.8), 0.4)


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for p: Vector2 in [Vector2(182, 8), Vector2(222, 6), Vector2(226, -8), Vector2(266, 14.8), Vector2(284, 6),
			Vector2(286, 34), Vector2(232, 44), Vector2(187, 43.4), Vector2(185, -14), Vector2(214, -12), Vector2(262, -16)]:
		var mi := MeshInstance3D.new()
		mi.mesh = NatureModels.oak(rng.randi_range(1, 3), true) if rng.randf() < 0.7 else NatureModels.pine(rng.randi_range(1, 3), true)
		mi.position = TerrainData.point_on_ground(p.x, p.y, -0.1)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
		add_child(mi)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(0, 1.5, 0)
		body.add_child(cs)
		mi.add_child(body)


# --- Interaction points -----------------------------------------------------------------

func _interactable(center: Vector3, size: Vector3, prompt_key: String, action: Callable, pump := false) -> Node3D:
	var point := TownPoint.new()
	point.prompt_key = prompt_key
	point.action = action
	point.is_pump = pump
	point.position = center
	point.size = size
	add_child(point)
	return point
