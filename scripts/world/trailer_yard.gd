class_name TrailerYard
extends RefCounted
## The town's side of the trailers (Trailer). The dealership's (Yeşilova Oto Galeri)
## trailer bay is the concrete yard between the market and the dealer's building, behind
## the north pavement under his "RÖMORK" board (Town.MARKET_SIDE_YARD): Grandpa's stock
## trailer, left with him for new tyres, and the cargo trailer for sale stand there side
## by side in a marked bay each, off the street and the pavement, tongues to the street
## (paid for at Kemal's desk in the dealership, a trailer is backed up to across the
## bevelled kerb, along the approach Trailer draws on the ground ahead of its tongue, and
## pulled straight out onto the street), the cargo trailer with its price board at the
## bay's front (it only shows the price: Kemal takes the money). One of his that still
## stands unhitched in the bay is not "at the market" (trailer_at_market): it has to be
## collected. At the Animal Market:
## the loading pen by the gate, where a sheep, cow or horse bought at the market waits for
## the farmer to put the rope on it (G) and lead it up his trailer's ramp. With no stock
## trailer of his by the market the dealer brings it over himself the next morning for
## DELIVERY_FEE (it waits in the pen meanwhile, and goes home with the morning as any
## animal left away does: Animals._on_day_started), so nobody is ever stuck. An animal
## brought to the market in the trailer sells for SALE_BONUS more than one sold off the
## farm's list.

## Where the trailers stand in the dealer's trailer bay: x, z (the axle) and heading
## (degrees; 0: tongue south, to the street). One in each marked bay of the yard
## (Town.TRAILER_BAY_LINES), tails short of its back edge, tongues short of the pavement;
## Grandpa's in the east bay, nearest the dealer's.
const SPOTS := {
	&"trailer_stock": Vector3(223.0, 9.2, 0.0),
	&"trailer_flat": Vector3(220.2, 9.2, 0.0),
}
## Where the cargo trailer's price board stands (x, z): at the bay's front beside its
## tongue, turned to the street.
const BOARD := Vector2(219.3, 12.85)
## At the kerb in front of the bays: x, z and heading (degrees; -90: nose west, as the
## traffic on that side goes).
const KERB := Vector3(221.6, 17.75, -90.0)
## The loading pen: on the verge east of the market's gate, open to the pavement.
const PEN := Rect2(252.6, 27.0, 2.8, 2.6)
## What the dealer takes to bring an animal out to the farm himself.
const DELIVERY_FEE := 15
## An animal sold out of the trailer at the market fetches this much more.
const SALE_BONUS := 0.15
## How near the market (the pen's middle) a trailer counts as there (m).
const MARKET_NEAR := 45.0
## Waypoint anchors (WaypointMarker): Grandpa's trailer, the pen.
const ANCHOR := &"trailer_stock"
const PEN_ANCHOR := &"loading_pen"


## Puts the trailers out in the dealer's trailer bay (a loaded game moves the farmer's
## own to where he left them) and the cargo trailer's price board beside it.
static func spawn(town: Town) -> void:
	var floor_y := Town.side_yard_top()
	for kind: StringName in VehicleTable.TRAILERS:
		var t := Trailer.make(kind, bay_place(kind), true)
		town.add_child(t)
		t.reset_physics_interpolation()
		if kind == &"trailer_stock":
			WaypointMarker.tag(t.waypoint_roof(), ANCHOR)
			t.waypoint_roof().add_to_group(&"waypoints")
		else:
			# At the bay's front beside its tongue, turned to the street.
			var board := _price_board(town, t, Vector3(BOARD.x, floor_y, BOARD.y))
			t.changed.connect(func() -> void: board.visible = not t.owned)


## Where trailer `kind` stands in the dealer's trailer bay (SPOTS), on its concrete.
static func bay_place(kind: StringName) -> Transform3D:
	var spot: Vector3 = SPOTS[kind]
	return Transform3D(Basis(Vector3.UP, deg_to_rad(spot.z)), Vector3(spot.x, Town.side_yard_top() + 0.02, spot.y))


## Where a vehicle that a save left standing in a bay is put (Vehicle._leave_bay): at the
## kerb in front of the bays, along the street.
static func kerb_place() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(KERB.z)), Vector3(KERB.x, TerrainData.height(KERB.x, KERB.y) + 0.3, KERB.y))


## A yellow A-board with the price, turned to the street.
static func _price_board(town: Town, t: Trailer, base: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "PriceBoard_%s" % t.kind
	town.add_child(root)
	var mb := MeshBuilder.new()
	for sx: float in [-0.36, 0.36]:
		for sz: float in [-0.12, 0.12]:
			mb.cylinder_between(&"metal", base + Vector3(sx, 0, sz * 2.2), base + Vector3(sx, 0.95, sz * 0.3), 0.018, 0.016, 6, Color(0.2, 0.2, 0.2))
	mb.box(&"sign", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-8.0)), base + Vector3(0, 0.78, 0.07)), Vector3(0.86, 0.56, 0.03), Color(0.95, 0.8, 0.2))
	mb.box(&"sign", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)), base + Vector3(0, 0.78, -0.07)), Vector3(0.86, 0.56, 0.03), Color(0.95, 0.8, 0.2))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(Town._materials())
	mi.visibility_range_end = 90.0
	root.add_child(mi)
	var label := BuildingKit.sign(root, "YÜK RÖMORKU\n%s" % UiTheme.money(t.price), Vector3.ZERO, 0.0, 60, Color(0.12, 0.1, 0.05), Color(0, 0, 0, 0), false)
	label.position = base + Vector3(0, 0.8, 0.105)
	label.rotation.x = deg_to_rad(-8.0)
	label.visibility_range_end = 60.0
	root.visible = not t.owned
	return root


## The loading pen: three rails' worth of post-and-rail fence round a patch of trodden
## earth and straw, open to the north, a board over its back rail.
static func build_pen(town: Town) -> void:
	var mb := MeshBuilder.new()
	var y := TerrainData.height(PEN.get_center().x, PEN.get_center().y)
	var wood := Color(0.56, 0.53, 0.49)
	var corners: Array[Vector2] = [PEN.position, Vector2(PEN.position.x, PEN.end.y), PEN.end, Vector2(PEN.end.x, PEN.position.y)]
	var body := StaticBody3D.new()
	body.name = "LoadingPen"
	town.add_child(body)
	for i in 3:
		var a := Vector3(corners[i].x, y, corners[i].y)
		var b := Vector3(corners[i + 1].x, y, corners[i + 1].y)
		for ry: float in [0.35, 0.72, 1.08]:
			BuildingKit.beam(mb, &"fence_wood", a + Vector3(0, ry, 0), b + Vector3(0, ry, 0), Vector2(0.1, 0.035), wood.darkened(ry * 0.03))
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var mid := (a + b) * 0.5
		shape.size = Vector3(absf(b.x - a.x) + 0.1, 1.2, absf(b.z - a.z) + 0.1)
		cs.shape = shape
		cs.position = mid + Vector3(0, 0.6, 0)
		body.add_child(cs)
	for c in corners:
		mb.box_at(&"fence_wood", Vector3(c.x, y + 0.6, c.y), Vector3(0.12, 1.3, 0.12), wood.darkened(0.08))
	# Trodden earth and a scatter of straw.
	mb.box_at(&"dirt_old", Vector3(PEN.get_center().x, y - 0.03, PEN.get_center().y - 0.2), Vector3(PEN.size.x + 0.5, 0.1, PEN.size.y + 0.9), Color(0.34, 0.29, 0.23))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2121
	for i in 26:
		var sp := Vector3(rng.randf_range(PEN.position.x + 0.2, PEN.end.x - 0.2), y + 0.022, rng.randf_range(PEN.position.y, PEN.end.y - 0.2))
		mb.box(&"straw", Transform3D(Basis(Vector3.UP, rng.randf() * PI), sp), Vector3(rng.randf_range(0.08, 0.22), 0.004, rng.randf_range(0.008, 0.02)),
				Color(0.72, 0.62, 0.4).darkened(rng.randf() * 0.25))
	# The board on the back rail.
	var bc := Vector3(PEN.get_center().x, y + 1.42, PEN.end.y)
	mb.box_at(&"wood", bc, Vector3(1.5, 0.34, 0.05), Color(0.36, 0.22, 0.1))
	for sx: float in [-0.6, 0.6]:
		mb.box_at(&"fence_wood", bc + Vector3(sx, -0.25, 0.0), Vector3(0.06, 0.4, 0.05), wood.darkened(0.1))
	var mi := MeshInstance3D.new()
	mi.name = "LoadingPenMesh"
	mi.mesh = mb.build(Town._materials())
	mi.visibility_range_end = 120.0
	town.add_child(mi)
	BuildingKit.sign(town, "YÜKLEME AĞILI", bc + Vector3(0, 0.0, -0.03), PI, 44, Color(1.0, 0.93, 0.76), Color(0, 0, 0, 0), false)
	var marker := Marker3D.new()
	marker.name = "LoadingPenMarker"
	marker.position = Vector3(PEN.get_center().x, y + 1.9, PEN.get_center().y)
	town.add_child(marker)
	WaypointMarker.tag(marker, PEN_ANCHOR)
	Game.world.block_grass(PEN.grow(0.4))


## The middle of the pen, on the ground.
static func pen_center() -> Vector3:
	var c := PEN.get_center()
	return Vector3(c.x, TerrainData.height(c.x, c.y), c.y)


## The farmer's stock trailer standing in town by the market (hitched or not), or null.
## One still standing unhitched in the dealer's trailer bay is not there yet: it has to
## be collected; on the pickup's ball it is with him, wherever in town the rig stands
## (still at the bay across the street, too).
static func trailer_at_market() -> Trailer:
	for t in Trailer.every():
		if t.owned and t.takes_animals() and t.global_position.distance_to(pen_center()) < MARKET_NEAR and (t.tow != null or not in_bay(t)):
			return t
	return null


## Whether `t` stands in the dealer's trailer bay (Town.MARKET_SIDE_YARD).
static func in_bay(t: Trailer) -> bool:
	return Town.MARKET_SIDE_YARD.grow(0.5).has_point(Vector2(t.global_position.x, t.global_position.z))


## What bringing an animal out costs now: nothing with his trailer at the market.
static func fee_now() -> int:
	return 0 if trailer_at_market() != null else DELIVERY_FEE


## The line the market shows under a kind that walks: where it will wait, or what the
## dealer takes to bring it.
static func delivery_line() -> String:
	if trailer_at_market() != null:
		return TranslationServer.translate("MARKET_PEN_WAITS")
	return String(TranslationServer.translate("MARKET_DELIVERY_FEE")) % UiTheme.money(DELIVERY_FEE)


## The farmer's animals waiting in the pen.
static func waiting() -> Array[Animal]:
	var out: Array[Animal] = []
	for a: AnimalData in Animals.animals:
		if not a.away or not PEN.grow(0.5).has_point(Vector2(a.away_pos.x, a.away_pos.z)):
			continue
		var n := Animals.node_of(a)
		if n != null and not n.ridden and not n.led:
			out.append(n)
	return out


## Animal `a`, just bought at the market, goes into the loading pen; the dealer's fee is
## taken when no trailer is there to fetch it, and the farmer is told which it is.
static func bought(a: AnimalData) -> void:
	var n := Animals.node_of(a)
	if n == null:
		return
	var fee := fee_now()
	var k := waiting().size()
	var at := Vector3(PEN.position.x + 0.8 + 1.2 * (k % 2), 0.0, PEN.end.y - 0.9 - 0.9 * ((k / 2) % 2))
	at.y = TerrainData.height(at.x, at.z)
	a.away = true
	a.away_pos = at
	a.away_yaw = 0.0
	n._path.clear()
	n._path_inside.clear()
	n.indoors = false
	n.global_position = at
	n.rotation.y = 0.0
	n.reset_physics_interpolation()
	n._set_state(Animal.State.AWAY, 1e9)
	if fee > 0:
		Economy.spend(fee, "REPORT_ANIMALS")
		Game.notify(String(TranslationServer.translate("MSG_MARKET_DELIVERY")) % [a.name, UiTheme.money(fee)], UiTheme.GOLD_SOFT)
	else:
		Game.notify(String(TranslationServer.translate("MSG_MARKET_PEN")) % a.name, Color(0.55, 1.0, 0.45))


## What selling `a` at the market adds to its price when it was brought there in the
## trailer (0 otherwise).
static func sale_bonus(a: AnimalData) -> int:
	var n := Animals.node_of(a)
	if n == null:
		return 0
	var t := Trailer.carrying(n)
	if t == null or t.global_position.distance_to(pen_center()) > MARKET_NEAR:
		return 0
	return roundi(a.sale_value() * SALE_BONUS)
