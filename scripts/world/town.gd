class_name Town
extends Node3D
## The town of Yeşilova along the county road: a general market (buy seeds and raw
## materials, sell produce, also straight from a parked pickup), the poultry stall
## beside it (hens in crates, loaded into the pickup parked in front), a filling
## station, the car dealership with a better pickup for sale, the livestock dealer, a
## couple of houses, pavements, street lamps and signs. Built from BuildingKit pieces.
## Also spawns Grandpa's old pickup at the farm: the town keeps every vehicle.

const STREET_Z := 20.0
const WALK_N := Rect2(186, 13.3, 96, 3.2)
const WALK_S := Rect2(186, 23.5, 96, 3.2)
const MARKET := Rect2(196, -4, 20, 14)
const PARKING := Rect2(186, -2, 9.5, 15.3)
const DEALER := Rect2(232, -10, 30, 18)
const DEALER_LOT := Rect2(232, 8, 30, 5.3)
const STATION := Rect2(194, 23.5, 34, 23.5)
const CANOPY := Rect2(199, 29, 24, 10)
const KIOSK := Rect2(202, 41, 18, 7)
const RANCH_OFFICE := Rect2(240, 31, 10, 8)
const RANCH_PEN := Rect2(252, 30, 12, 17)
## The poultry stall's yard, between the market's east wall and the dealership.
const POULTRY_YARD := Rect2(216.6, 7.4, 7.6, 5.9)
## Fuel price per litre.
const FUEL_PRICE := 2.0

var market_counter: Node3D
## The poultry stall's counter (E buys crated hens); `poultry_marker` floats over it
## for the story's waypoint.
var poultry_stall: Node3D
var poultry_marker: Marker3D
var pumps: Array[Node3D] = []
var for_sale: Vehicle
## Grandpa's old pickup: the player's from the first day, parked by the farm warehouse.
var farm_truck: Vehicle
var _lamps: Array[Light3D] = []
## Crates of goods on display: "item:variant:shadow" -> [Transform3D]. Drawn as
## multimeshes that only show up close, not baked into the town mesh.
var _goods := {}
var _lit := false


func _ready() -> void:
	add_to_group(&"town")
	var mb := MeshBuilder.new()
	var cols := []
	_pavements(mb, cols)
	_market(mb, cols)
	_poultry_stall(mb, cols)
	_dealer(mb, cols)
	_station(mb, cols)
	_livestock(mb, cols)
	_houses(mb, cols)
	_lamps_and_signs(mb, cols)
	var mi := MeshInstance3D.new()
	mi.name = "TownMesh"
	mi.mesh = mb.build({&"lamp_glow": BuildingKit.lamp_material()})
	add_child(mi)
	_build_goods()
	BuildingKit.collider(self, cols)
	_trees()
	for r: Rect2 in [WALK_N, WALK_S, MARKET.grow(0.5), PARKING, DEALER.grow(0.5), DEALER_LOT, STATION,
			RANCH_OFFICE.grow(0.5), RANCH_PEN, Rect2(268, -2, 11, 12), Rect2(270, 31, 11, 11), Rect2(196, 10, 20, 3.3),
			POULTRY_YARD]:
		Game.world.block_grass(r)
	_spawn_vehicle_for_sale()
	_spawn_farm_truck()


func _process(_delta: float) -> void:
	var lit := DayNightCycle.night_factor > 0.45 or Weather.overcast > 0.8
	if lit != _lit:
		_lit = lit
		for l in _lamps:
			l.visible = lit
			l.light_energy = (1.6 if l is OmniLight3D else 4.5) if lit else 0.0
		BuildingKit.lamp_material().set_shader_parameter("emission_strength", 4.0 if lit else 0.0)


# --- Ground ----------------------------------------------------------------------------

func _y(x: float, z: float) -> float:
	return TerrainData.height(x, z)


func _pavements(mb: MeshBuilder, cols: Array) -> void:
	var curb := Color(0.62, 0.62, 0.6)
	for r: Rect2 in [WALK_N, WALK_S]:
		var x0 := r.position.x
		while x0 < r.end.x - 0.01:
			var x1 := minf(x0 + 8.0, r.end.x)
			# Driveways (filling station, dealer lot, parking) have no curb.
			var seg := Rect2(x0, r.position.y, x1 - x0, r.size.y)
			var y := _y(seg.get_center().x, seg.get_center().y) + 0.15
			BuildingKit.slab(mb, cols, seg, y, 0.5, &"concrete", Color(0.55, 0.55, 0.54))
			# Paving slab joints across the walk, and one along its middle.
			var jx := x0 + 1.6
			while jx < x1 - 0.05:
				mb.box_at(&"concrete", Vector3(jx, y + 0.003, seg.get_center().y), Vector3(0.022, 0.006, seg.size.y - 0.05), Color(0.32, 0.32, 0.31))
				jx += 1.6
			mb.box_at(&"concrete", Vector3(seg.get_center().x, y + 0.003, seg.get_center().y), Vector3(seg.size.x - 0.05, 0.006, 0.022), Color(0.32, 0.32, 0.31))
			x0 = x1
		# Kerb stones, a metre each with a thin gap.
		var edge_z := r.end.y if r == WALK_N else r.position.y
		var kx := r.position.x
		var rng := RandomNumberGenerator.new()
		rng.seed = int(edge_z * 10.0)
		while kx < r.end.x - 0.01:
			var w := minf(1.0, r.end.x - kx)
			var cx := kx + w * 0.5
			mb.box_at(&"concrete", Vector3(cx, _y(cx, edge_z) + 0.08, edge_z), Vector3(w - 0.015, 0.2, 0.22),
					curb.lightened(rng.randf_range(-0.06, 0.04)))
			kx += w
	# Forecourts and the parking lot.
	BuildingKit.slab(mb, cols, Rect2(196, 10, 20, 3.3), _y(206, 11.5) + 0.15, 0.5, &"concrete", Color(0.55, 0.55, 0.54))
	BuildingKit.slab(mb, cols, PARKING, _y(191, 6) + 0.06, 0.4, &"asphalt", Color(0.5, 0.5, 0.5))
	for i in 4:
		var x := PARKING.position.x + 0.3 + i * 3.0
		mb.box_at(&"paint_in", Vector3(x, _y(191, 6) + 0.065, 3.0), Vector3(0.12, 0.01, 5.0), Color(0.92, 0.92, 0.88))
	BuildingKit.slab(mb, cols, DEALER_LOT, _y(247, 10.5) + 0.15, 0.5, &"concrete", Color(0.6, 0.6, 0.58))
	BuildingKit.slab(mb, cols, STATION, _y(211, 35) + 0.06, 0.4, &"concrete", Color(0.52, 0.52, 0.5))


# --- Market ------------------------------------------------------------------------------

func _market(mb: MeshBuilder, cols: Array) -> void:
	var y0 := _y(MARKET.get_center().x, MARKET.get_center().y) + 0.15
	var h := 5.0
	BuildingKit.shell(mb, cols, MARKET, y0, h, 0.3, &"brick", Color(0.5, 0.5, 0.5), {
		"s": [{"at": 4.0, "w": 6.4, "bottom": 0.6, "top": 3.4, "glass": true, "mullions": 1.6},
			{"at": 10.0, "w": 2.6, "bottom": 0.0, "top": 2.9, "glass": false},
			{"at": 16.0, "w": 6.4, "bottom": 0.6, "top": 3.4, "glass": true, "mullions": 1.6}],
		"w": [{"at": 7.0, "w": 3.0, "bottom": 1.2, "top": 2.8, "glass": true}],
	})
	# Plaster fascia with the sign above the shop front.
	var fz := MARKET.end.y + 0.02
	mb.box_at(&"plaster", Vector3(MARKET.get_center().x, y0 + 4.3, fz + 0.08), Vector3(MARKET.size.x + 0.3, 1.25, 0.2), Color(0.66, 0.64, 0.58))
	mb.box_at(&"sign", Vector3(MARKET.get_center().x, y0 + 4.3, fz + 0.2), Vector3(11.0, 0.9, 0.06), Color(0.12, 0.34, 0.2))
	BuildingKit.sign(self, "YEŞİLOVA MARKET", Vector3(MARKET.get_center().x, y0 + 4.3, fz + 0.24), 0.0, 128, Color(1.0, 0.97, 0.88))
	BuildingKit.awning(mb, Vector3(MARKET.position.x + 10.0, y0 + 3.2, fz + 0.05), 4.2, 1.5, Vector2(0, 1), Color(0.14, 0.36, 0.22))
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


func _bench(mb: MeshBuilder, cols: Array, base: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var wood := Color(0.5, 0.42, 0.34)
	var iron := Color(0.12, 0.12, 0.13)
	for sx: float in [-0.8, 0.8]:
		mb.box(&"metal", Transform3D(b, base + b * Vector3(sx, 0.22, 0)), Vector3(0.06, 0.44, 0.5), iron)
	for k in 3:
		mb.box(&"wood", Transform3D(b, base + b * Vector3(0, 0.46, -0.16 + k * 0.16)), Vector3(1.8, 0.04, 0.12), wood)
	for k in 2:
		mb.box(&"wood", Transform3D(b * Basis(Vector3.RIGHT, deg_to_rad(-12)), base + b * Vector3(0, 0.66 + k * 0.16, -0.27)), Vector3(1.8, 0.1, 0.03), wood)
	cols.append([base + Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 0.55), yaw])


# --- Car dealership ---------------------------------------------------------------------

func _dealer(mb: MeshBuilder, cols: Array) -> void:
	var y0 := _y(DEALER.get_center().x, DEALER.get_center().y) + 0.15
	var h := 5.6
	BuildingKit.shell(mb, cols, DEALER, y0, h, 0.3, &"plaster", Color(0.62, 0.62, 0.62), {
		"s": [{"at": 7.0, "w": 11.0, "bottom": 0.25, "top": 4.8, "glass": true, "mullions": 2.75},
			{"at": 15.0, "w": 3.0, "bottom": 0.0, "top": 3.0, "glass": false},
			{"at": 23.0, "w": 11.0, "bottom": 0.25, "top": 4.8, "glass": true, "mullions": 2.75}],
		"e": [{"at": 9.0, "w": 5.0, "bottom": 0.0, "top": 3.6, "glass": false}],
	})
	var fz := DEALER.end.y + 0.02
	mb.box_at(&"sign", Vector3(DEALER.get_center().x, y0 + 5.35, fz + 0.1), Vector3(DEALER.size.x + 0.3, 1.0, 0.22), Color(0.1, 0.2, 0.36))
	BuildingKit.sign(self, "YEŞİLOVA OTO GALERİ", Vector3(DEALER.get_center().x, y0 + 5.35, fz + 0.24), 0.0, 140, Color(1, 1, 1))
	# Showroom: polished floor, desk, plants, a car turntable.
	var desk := Vector3(DEALER.position.x + 24.0, y0, DEALER.position.y + 5.0)
	mb.box_at(&"wood_in", desk + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 1.0), Color(0.32, 0.26, 0.2))
	mb.box_at(&"metal", desk + Vector3(0, 0.92, 0), Vector3(2.3, 0.05, 1.1), Color(0.85, 0.85, 0.83))
	mb.box_at(&"metal", desk + Vector3(-0.4, 1.15, -0.2), Vector3(0.6, 0.4, 0.04), Color(0.08, 0.08, 0.09))
	_interactable(desk + Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 1.0), "ACTION_DEALER",
			func() -> void: Game.hud.open_dealer(for_sale))
	mb.cylinder(&"concrete", Transform3D(Basis(), Vector3(DEALER.position.x + 10.0, y0 + 0.02, DEALER.position.y + 8.0)), 3.2, 3.2, 0.12, 48, Color(0.75, 0.75, 0.75))
	for p: Vector3 in [Vector3(DEALER.position.x + 2.0, y0, DEALER.end.y - 1.6), Vector3(DEALER.end.x - 2.0, y0, DEALER.end.y - 1.6)]:
		mb.cylinder(&"concrete", Transform3D(Basis(), p), 0.35, 0.3, 0.6, 16, Color(0.3, 0.3, 0.3))
		mb.blob(&"foliage", Transform3D(Basis(), p + Vector3(0, 1.0, 0)), 0.55, 2, Color(0.25, 0.4, 0.18), 0.2, 2.0, 7, 0.0, true, 0.0)
	for lx in 4:
		mb.box_at(&"glow", Vector3(DEALER.position.x + 4.0 + lx * 7.3, y0 + h - 0.1, DEALER.get_center().y), Vector3(2.4, 0.04, 0.3), Color(1.0, 0.98, 0.94))
	var light := OmniLight3D.new()
	light.position = Vector3(DEALER.get_center().x, y0 + h - 0.8, DEALER.get_center().y)
	light.light_energy = 1.4
	light.omni_range = 16.0
	add_child(light)
	# Price board on the lot.
	var board := Vector3(DEALER_LOT.position.x + 16.0, _y(248, 12) + 0.15, DEALER_LOT.end.y - 0.4)
	mb.box_at(&"metal", board + Vector3(0, 0.6, 0), Vector3(0.08, 1.2, 0.08), Color(0.2, 0.2, 0.2))
	mb.box_at(&"sign", board + Vector3(0, 1.35, 0), Vector3(1.6, 0.7, 0.06), Color(0.95, 0.8, 0.2))


func _spawn_vehicle_for_sale() -> void:
	var p := Vector3(DEALER_LOT.position.x + 8.0, 0.0, DEALER_LOT.get_center().y)
	p.y = _y(p.x, p.z) + 0.25
	for_sale = Vehicle.create(&"pickup_90", Transform3D(Basis(Vector3.UP, PI * 0.5), p), true)
	add_child(for_sale)
	for_sale.reset_physics_interpolation()
	var price := BuildingKit.sign(self, "%s ALTIN" % UiTheme.money(for_sale.price),
			Vector3(DEALER_LOT.position.x + 16.0, _y(248, 12) + 1.5, DEALER_LOT.end.y - 0.36), 0.0, 90, Color(0.12, 0.1, 0.05), Color(0, 0, 0, 0), false)
	for_sale.changed.connect(func() -> void: price.visible = not for_sale.owned)


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
		mb.box_at(&"sign", face + Vector3(0.2, 1.08, sz * 0.02), Vector3(0.16, 0.12, 0.004), Color(0.9, 0.9, 0.86))
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
	var white := Color(0.9, 0.9, 0.88)
	# Canopy on four columns.
	var top := y0 + 5.4
	for cx: float in [CANOPY.position.x + 2.0, CANOPY.end.x - 2.0]:
		for cz: float in [CANOPY.position.y + 2.0, CANOPY.end.y - 2.0]:
			mb.box_at(&"metal", Vector3(cx, y0 + 2.6, cz), Vector3(0.35, 5.2, 0.35), white)
			cols.append([Vector3(cx, y0 + 2.6, cz), Vector3(0.35, 5.2, 0.35), 0.0])
	mb.box_at(&"metal", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.get_center().y), Vector3(CANOPY.size.x, 0.7, CANOPY.size.y), white)
	mb.box_at(&"sign", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.position.y - 0.02), Vector3(CANOPY.size.x + 0.04, 0.5, 0.04), red)
	mb.box_at(&"sign", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.end.y + 0.02), Vector3(CANOPY.size.x + 0.04, 0.5, 0.04), red)
	BuildingKit.sign(self, "OVA PETROL", Vector3(CANOPY.get_center().x, top + 0.35, CANOPY.position.y - 0.06), PI, 110, Color(1, 1, 1))
	for lx in 3:
		for lz in 2:
			mb.box_at(&"glow", Vector3(CANOPY.position.x + 5.0 + lx * 7.0, top - 0.01, CANOPY.position.y + 3.0 + lz * 4.0), Vector3(1.4, 0.03, 0.8), Color(1.0, 1.0, 0.97))
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
		mb.box_at(&"concrete", island + Vector3(0, 0.1, 0), Vector3(1.3, 0.2, 6.5), Color(0.7, 0.7, 0.68))
		cols.append([island + Vector3(0, 0.1, 0), Vector3(1.3, 0.2, 6.5), 0.0])
		for bz: float in [-3.0, 3.0]:
			mb.cylinder(&"metal", Transform3D(Basis(), island + Vector3(0, 0.2, bz)), 0.1, 0.1, 0.9, 10, Color(0.95, 0.75, 0.1))
		var pump := island + Vector3(0, 0.2, 0)
		_dispenser(mb, pump, red, white)
		pumps.append(_interactable(pump + Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.6), "ACTION_REFUEL", _refuel.bind(pump), true))
	# Kiosk.
	var ky := _y(KIOSK.get_center().x, KIOSK.get_center().y) + 0.15
	BuildingKit.shell(mb, cols, KIOSK, ky, 3.6, 0.25, &"plaster", Color(0.66, 0.66, 0.64), {
		"n": [{"at": 4.5, "w": 6.0, "bottom": 0.5, "top": 2.9, "glass": true, "mullions": 1.5},
			{"at": 12.0, "w": 2.2, "bottom": 0.0, "top": 2.6, "glass": false}],
	})
	mb.box_at(&"sign", Vector3(KIOSK.get_center().x, ky + 3.3, KIOSK.position.y - 0.12), Vector3(KIOSK.size.x + 0.2, 0.6, 0.12), red)
	# Price totem.
	var totem := Vector3(STATION.end.x - 1.2, _y(STATION.end.x, 25) + 0.06, STATION.position.y + 2.4)
	mb.box_at(&"metal", totem + Vector3(0, 2.8, 0), Vector3(1.4, 5.6, 0.3), white)
	mb.box_at(&"sign", totem + Vector3(0, 4.9, 0), Vector3(1.44, 1.0, 0.34), red)
	BuildingKit.sign(self, "OVA", totem + Vector3(0, 4.9, -0.2), PI, 120, Color(1, 1, 1))
	BuildingKit.sign(self, "YAKIT\n%d ALTIN/L" % int(FUEL_PRICE), totem + Vector3(0, 3.1, -0.17), PI, 70, Color(0.1, 0.1, 0.1), Color(0, 0, 0, 0), false)
	cols.append([totem + Vector3(0, 2.8, 0), Vector3(1.4, 5.6, 0.3), 0.0])


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


static func _nearest_owned_vehicle(p: Vector3, max_dist: float) -> Vehicle:
	var best: Vehicle = null
	var best_d := max_dist
	for v: Vehicle in Game.world.get_tree().get_nodes_in_group(Vehicle.GROUP):
		if not v.owned:
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
	return _nearest_owned_vehicle(market_counter.global_position, 30.0)


## The player's vehicle parked by the poultry stall whose bed takes the crates bought
## there (null: they go into the bag).
func vehicle_at_poultry() -> Vehicle:
	if poultry_stall == null:
		return null
	return LiveCrates.vehicle_near(poultry_stall.global_position)


# --- Poultry stall ---------------------------------------------------------------------

## A timber market stall under a rusty tin roof beside the market: a trestle counter
## with crated hens on it (live ones; the stock stacked behind), a chalkboard with the
## price, feed sacks and straw, empty crates waiting at the side and a bulb for the
## evening. E at the counter buys hens in crates; they go into the bed of the pickup
## parked in front, else into the bag.
func _poultry_stall(mb: MeshBuilder, cols: Array) -> void:
	var c := POULTRY_YARD.get_center()
	var y0 := _y(c.x, c.y) + 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = 2217
	# Old concrete underfoot, patched with packed earth, joined to the pavement.
	BuildingKit.slab(mb, cols, POULTRY_YARD, y0, 0.45, &"concrete", Color(0.5, 0.49, 0.47))
	for i in 4:
		var p := Vector3(rng.randf_range(POULTRY_YARD.position.x + 0.8, POULTRY_YARD.end.x - 0.8), y0 + 0.004,
				rng.randf_range(POULTRY_YARD.position.y + 0.8, POULTRY_YARD.end.y - 0.8))
		mb.blob(&"dirt_old", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(1.4, 0.01, 1.0)), p),
				rng.randf_range(0.5, 0.9), 1, Color(0.3, 0.26, 0.2), 0.4, 1.8, 60 + i, 0.0, true)
	# Frame: four posts (the back ones taller), a beam front and back, braces.
	var o := Vector3(c.x, y0, c.y - 0.9)
	var post := Color(0.4, 0.33, 0.25)
	var hw := 1.6
	var hd := 0.95
	var front_h := 2.35
	var back_h := 2.75
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var ph := front_h if sz > 0.0 else back_h
			var pp := o + Vector3(sx * hw, ph * 0.5, sz * hd)
			mb.box_at(&"wood", pp, Vector3(0.1, ph, 0.1), post.lightened(rng.randf_range(-0.05, 0.03)), Vector3.ZERO, true)
			cols.append([pp, Vector3(0.12, ph, 0.12), 0.0])
		BuildingKit.beam(mb, &"wood", o + Vector3(sx * hw, front_h - 0.55, hd), o + Vector3(sx * hw, back_h - 0.4, -hd), Vector2(0.08, 0.06), post)
	for sz: float in [-1.0, 1.0]:
		var bh := front_h if sz > 0.0 else back_h
		mb.box_at(&"wood", o + Vector3(0, bh - 0.06, sz * hd), Vector3(hw * 2.0 + 0.2, 0.12, 0.09), post.darkened(0.08))
	# Rusty corrugated roof sloping to the street, a painted fascia board with the name.
	var run := hd * 2.0 + 0.7
	var tilt := atan2(back_h - front_h, hd * 2.0)
	# Resting on the front and back beams (their tops lie on the slope through z = 0).
	var roof_c := o + Vector3(0, (front_h + back_h) * 0.5 - 0.12 * tan(tilt) + 0.02, 0.12)
	mb.box(&"corrugated_old", Transform3D(Basis(Vector3.RIGHT, tilt), roof_c), Vector3(hw * 2.0 + 0.6, 0.03, run), Color(0.58, 0.5, 0.44))
	var fascia := o + Vector3(0, front_h + 0.12, hd + 0.36)
	mb.box_at(&"wood", fascia, Vector3(hw * 2.0 + 0.4, 0.34, 0.04), Color(0.52, 0.16, 0.1))
	BuildingKit.sign(self, "TAVUKÇU", fascia + Vector3(0, 0.0, 0.03), 0.0, 84, Color(0.98, 0.92, 0.78), Color(0, 0, 0, 0), false)
	# A striped canvas valance under the fascia.
	for k in 8:
		var vx := -hw - 0.1 + (k + 0.5) * (hw * 2.0 + 0.2) / 8.0
		mb.box_at(&"cloth", o + Vector3(vx, front_h - 0.12, hd + 0.33), Vector3((hw * 2.0 + 0.2) / 8.0, 0.24, 0.015),
				Color(0.86, 0.82, 0.72) if k % 2 == 0 else Color(0.55, 0.2, 0.14), Vector3(8, 0, 0))
	# The trestle counter at the front: plank top on two A-frame trestles.
	var counter := o + Vector3(0, 0, hd - 0.3)
	var top_y := 0.82
	for k in 4:
		mb.box_at(&"planks", counter + Vector3(0, top_y, -0.27 + k * 0.18), Vector3(2.9, 0.04, 0.17),
				Color(0.5, 0.45, 0.4).lightened(rng.randf_range(-0.05, 0.05)), Vector3(0, rng.randf_range(-0.4, 0.4), 0))
	for sx: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			mb.box_at(&"wood", counter + Vector3(sx * 1.15, top_y * 0.5 - 0.02, lean * 0.14), Vector3(0.06, top_y, 0.06), post,
					Vector3(lean * 11.0, 0, 0))
		mb.box_at(&"wood", counter + Vector3(sx * 1.15, 0.3, 0), Vector3(0.05, 0.05, 0.62), post)
	cols.append([counter + Vector3(0, top_y * 0.5, 0), Vector3(2.9, top_y + 0.04, 0.72), 0.0])
	# Crated hens on the counter (live) and the stock stacked behind (modelled hens).
	var on_top := top_y + 0.02
	for k in 3:
		var hen_xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06) + (PI if k == 1 else 0.0)),
				counter + Vector3(-0.85 + k * 0.85, on_top, 0.02))
		_goods_add("chicken_crate:0:1", hen_xf)
		var hen := CrateHen.new()
		hen.name = "StallHen%d" % k
		hen.variant = k + 1
		# Goes out of sight with the crates on show (_build_goods).
		hen.view_range = 44.0
		hen.transform = hen_xf
		add_child(hen)
	for k in 4:
		var row := k / 2
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)),
				o + Vector3(-0.9 + (k % 2) * 0.58 + row * 0.05, row * (CargoModels.SIZE.y + 0.012), -hd + 0.45))
		_goods_add("chicken_crate:still", xf)
	cols.append([o + Vector3(-0.45, 0.28, -hd + 0.45), Vector3(1.3, 0.56, 0.42), 0.0])
	# Empty crates waiting at the side, feed sacks and a bale of straw.
	for k in 3:
		_goods_add("chicken_crate:1:0", Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.1, 0.1)),
				o + Vector3(hw + 0.45, k * (CargoModels.SIZE.y + 0.012), 0.2)))
	cols.append([o + Vector3(hw + 0.45, 0.4, 0.2), Vector3(0.42, 0.8, 0.55), 0.0])
	for k in 2:
		_goods_add("feed:%d:1" % k, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), o + Vector3(0.6 + k * 0.52, 0.0, -hd + 0.4)))
	_goods_add("hay:0:1", Transform3D(Basis(Vector3.UP, 0.2), o + Vector3(-hw + 0.3, 0.0, -0.1)))
	for i in 9:
		var sp := o + Vector3(rng.randf_range(-hw, hw), 0.004, rng.randf_range(-hd, hd + 0.8))
		mb.box_at(&"straw", sp, Vector3(rng.randf_range(0.15, 0.4), 0.01, rng.randf_range(0.05, 0.12)), Color(0.8, 0.68, 0.4),
				Vector3(0, rng.randf() * 180.0, 0))
	# The chalkboard on an easel by the counter, the price chalked on it.
	var easel := o + Vector3(-hw - 0.55, 0, hd + 0.35)
	var board_b := Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, deg_to_rad(-12.0))
	mb.box(&"wood", Transform3D(board_b, easel + Vector3(0, 0.62, 0)), Vector3(0.62, 0.86, 0.04), post)
	mb.box(&"paint_in", Transform3D(board_b, easel + Vector3(0, 0.64, 0) + board_b.z * 0.022), Vector3(0.54, 0.74, 0.004), Color(0.12, 0.14, 0.13))
	mb.box(&"wood", Transform3D(Basis(Vector3.UP, 0.35) * Basis(Vector3.RIGHT, deg_to_rad(18.0)), easel + Vector3(0, 0.5, -0.2)),
			Vector3(0.05, 1.0, 0.04), post)
	var chalk := BuildingKit.sign(self, "CANLI\nTAVUK\n%s ALTIN" % UiTheme.money(LiveCrates.price(&"chicken")),
			easel + Vector3(0, 0.66, 0) + board_b.z * 0.03, 0.35, 44, Color(0.93, 0.93, 0.88), Color(0, 0, 0, 0), false)
	chalk.rotation.x = deg_to_rad(-12.0)
	# Chalked small enough to stay on the 0.54 m board (the sign default is shop-front size).
	chalk.pixel_size = 0.002
	cols.append([easel + Vector3(0, 0.5, -0.05), Vector3(0.6, 1.0, 0.35), 0.35])
	# A bare bulb under the roof for the evening.
	var bulb := o + Vector3(0, front_h - 0.25, 0.1)
	mb.cylinder_between(&"cloth", bulb + Vector3(0, 0.02, 0), bulb + Vector3(0, 0.35, 0), 0.004, 0.004, 5, Color(0.1, 0.1, 0.1))
	mb.sphere(&"lamp_glow", Transform3D(Basis(), bulb), Vector3(0.04, 0.05, 0.04), 8, 6, Color(1.0, 0.86, 0.6))
	var light := OmniLight3D.new()
	light.position = bulb - Vector3(0, 0.08, 0)
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 0.0
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	_lamps.append(light)
	poultry_stall = _interactable(counter + Vector3(0, 0.62, 0.05), Vector3(3.0, 1.0, 0.95), "ACTION_BUY_CHICKENS",
			func() -> void: Game.hud.rancher_screen.open_poultry(poultry_stall.global_position))
	poultry_marker = Marker3D.new()
	poultry_marker.name = "PoultryMarker"
	poultry_marker.position = o + Vector3(0, front_h + 0.75, hd + 0.4)
	WaypointMarker.tag(poultry_marker, &"town_chickens")
	poultry_marker.add_to_group(&"waypoints")
	add_child(poultry_marker)


## One more package on display (see _goods): "item:variant:shadow", or "item:still"
## for a crate with a modelled hen in it (the stock behind the stall).
func _goods_add(key: String, xf: Transform3D) -> void:
	if not _goods.has(key):
		_goods[key] = []
	(_goods[key] as Array).append(xf)


# --- Livestock dealer ------------------------------------------------------------------

func _livestock(mb: MeshBuilder, cols: Array) -> void:
	var y0 := _y(RANCH_OFFICE.get_center().x, RANCH_OFFICE.get_center().y) + 0.1
	BuildingKit.shell(mb, cols, RANCH_OFFICE, y0, 3.4, 0.25, &"planks", Color(0.5, 0.46, 0.42), {
		"n": [{"at": 3.0, "w": 2.6, "bottom": 1.0, "top": 2.4, "glass": true},
			{"at": 7.2, "w": 1.6, "bottom": 0.0, "top": 2.4, "glass": false}],
	}, &"floor", false)
	mb.box_at(&"sign", Vector3(RANCH_OFFICE.get_center().x, y0 + 3.9, RANCH_OFFICE.position.y - 0.25), Vector3(6.0, 0.8, 0.1), Color(0.36, 0.22, 0.1))
	BuildingKit.sign(self, "HAYVAN PAZARI", Vector3(RANCH_OFFICE.get_center().x, y0 + 3.9, RANCH_OFFICE.position.y - 0.31), PI, 100, Color(1.0, 0.94, 0.8))
	var counter := Vector3(RANCH_OFFICE.position.x + 3.0, y0, RANCH_OFFICE.position.y + 1.4)
	mb.box_at(&"wood_in", counter + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.7), Color(0.42, 0.32, 0.22))
	_interactable(counter + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.7), "ACTION_SHOP_ANIMALS",
			func() -> void: Game.hud.open_rancher())
	# The window counter faces the street too.
	_interactable(Vector3(RANCH_OFFICE.position.x + 3.0, y0 + 1.7, RANCH_OFFICE.position.y), Vector3(2.6, 1.4, 0.4), "ACTION_SHOP_ANIMALS",
			func() -> void: Game.hud.open_rancher())
	# Paddock with hay.
	var fence := Fence.new()
	var f := WorldLayout.fence_around(RANCH_PEN, [])
	fence.points = f["points"]
	fence.gaps = f["gaps"]
	fence.closed = true
	add_child(fence)
	for i in 3:
		var p := Vector3(RANCH_PEN.position.x + 2.5 + i * 1.3, _y(RANCH_PEN.position.x + 3, RANCH_PEN.end.y - 3), RANCH_PEN.end.y - 2.5)
		mb.cylinder(&"straw", Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p + Vector3(0.6, 0.6, 0)), 0.6, 0.6, 1.2, 18, Color(0.8, 0.7, 0.4))


# --- Houses and street furniture ------------------------------------------------------

func _houses(mb: MeshBuilder, cols: Array) -> void:
	for spec: Array in [[Rect2(268, -2, 11, 10), "s", Color(0.66, 0.6, 0.52)], [Rect2(270, 31, 11, 10), "n", Color(0.6, 0.64, 0.66)]]:
		var r: Rect2 = spec[0]
		var y0 := _y(r.get_center().x, r.get_center().y) + 0.2
		var front: String = spec[1]
		var ops := {front: [{"at": 2.5, "w": 1.6, "bottom": 0.9, "top": 2.3, "glass": true},
				{"at": 5.5, "w": 1.1, "bottom": 0.0, "top": 2.2, "glass": false},
				{"at": 8.5, "w": 1.6, "bottom": 0.9, "top": 2.3, "glass": true}]}
		BuildingKit.shell(mb, cols, r, y0, 3.0, 0.3, &"plaster", spec[2], ops, &"floor", false)
		# Door leaf (closed) in the doorway.
		var door_x := r.position.x + 5.5
		var door_z := r.end.y - 0.15 if front == "s" else r.position.y + 0.15
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
		add_child(gf)


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
	for p: Vector3 in [Vector3(193, 0, 12.6), Vector3(229, 0, 12.6), Vector3(265, 0, 12.6)]:
		var base := Vector3(p.x, _y(p.x, p.z) + 0.15, p.z)
		mb.cylinder(&"metal", Transform3D(Basis(), base), 0.22, 0.22, 0.85, 14, Color(0.18, 0.3, 0.2))
		cols.append([base + Vector3(0, 0.45, 0), Vector3(0.44, 0.9, 0.44), 0.0])


func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for p: Vector2 in [Vector2(182, 8), Vector2(222, 6), Vector2(226, -8), Vector2(266, 14.8), Vector2(284, 6),
			Vector2(286, 34), Vector2(232, 44), Vector2(190, 40), Vector2(185, -14), Vector2(214, -12), Vector2(262, -16)]:
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
