@tool
class_name WorldLayout
extends RefCounted
## Single source of truth for the farm map. X grows east, Z grows south (north = -Z).
## Terrain shaping, paths, grass exclusion and prop placement all read from here.

## Map rectangle (1 m terrain grid): the farm valley around the origin and the town
## valley to the east, joined by a road over a pass.
const MAP_MIN_X := -150
const MAP_MIN_Z := -150
const MAP_W := 500
const MAP_D := 300
const VALLEY_RADIUS := 90.0
const BOUNDARY_RADIUS := 94.0
const WATER_LEVEL := -0.55

## Town of Yeşilova: valley centre and radius (hills start past it).
const TOWN_CENTER := Vector2(232, 14)
const TOWN_VALLEY_RADIUS := 64.0
const TOWN_BOUNDARY_RADIUS := 66.0
## County road (asphalt) from the farm's east gate to the town square: control
## points of a smooth spline, width and the walkable/drivable corridor half-width.
const ROAD_POINTS := [Vector2(56, 22.5), Vector2(76, 25), Vector2(98, 29), Vector2(122, 31),
		Vector2(146, 29), Vector2(166, 24), Vector2(184, 21), Vector2(200, 20), Vector2(222, 20),
		Vector2(246, 20), Vector2(270, 20), Vector2(286, 21)]
const ROAD_WIDTH := 7.0
const ROAD_CORRIDOR := 9.0
## Steepest road grade the road profile allows.
const ROAD_MAX_GRADE := 0.065

const WELL_POS := Vector3(-8, 0, -6)
const MARKET_POS := Vector3(10, 0, 25)
const RANCHER_POS := Vector3(28, 0, 27)
const BOARD_POS := Vector3(-10.2, 0, -11.6)
const SHIPPING_BIN_POS := Vector3(-18.8, 0, -11.9)
const QUARRY_RECT := Rect2(-12, -74, 44, 18)

## The house grows west and north: its east wall and front (south) wall stay put,
## and the front door always sits at DOOR_X.
const HOUSE_EAST_X := -11.5
const HOUSE_FRONT_Z := -14.5
const HOUSE_DOOR_X := -16.0
## Footprint (width along X, depth along Z) per house level.
const HOUSE_SIZES := [Vector2(9, 7), Vector2(12, 8), Vector2(15, 9.5)]

const POND_CENTER := Vector2(-44, -4)
const POND_RADIUS := 11.0

const PLAYER_SPAWN := Vector3(-14, 0.2, -9)
## Farm warehouse (produce storage), its big door faces south onto the yard.
const WAREHOUSE_RECT := Rect2(-31, -12.5, 8, 7)
## Grandpa's old pickup: on the warehouse apron beside the track, nose to the yard (east),
## tailgate toward the warehouse door.
const FARM_TRUCK_SPOT := Vector2(-21, -0.2)
## "Needs repair" signs of the run-down house (east of the porch) and warehouse (east
## of its door).
const HOUSE_REPAIR_SIGN := Vector3(-12.7, 0, -12.3)
const WAREHOUSE_REPAIR_SIGN := Vector3(-22.3, 0, -4.9)

## Garden lots: fence rect (x, z, w, d) and gates [side, offset from the side's
## center, width]. Sides: "n" (-Z), "s" (+Z), "w" (-X), "e" (+X).
const FIELD_LOTS := {
	&"field_0": {"rect": Rect2(-4, -13, 15, 12), "gates": [["w", 0.0, 2.0], ["e", 0.0, 2.0]]},
	&"field_1": {"rect": Rect2(-4, 1, 15, 12), "gates": [["w", 0.0, 2.0]]},
	&"field_2": {"rect": Rect2(-4, -27, 15, 12), "gates": [["w", 0.0, 2.0]]},
	&"field_3": {"rect": Rect2(13, 1, 15, 12), "gates": [["n", 0.0, 2.0]]},
}

## Large-animal pen; the closed barn is built inside its north part.
const BARN_PEN := Rect2(36, -11, 24, 22)
const BARN_GATE := ["w", 0.0, 3.0]
const BARN_BUILDING := Rect2(41.5, -10.4, 13, 8)
## Poultry run; the closed coop is built inside its north part.
const COOP_PEN := Rect2(16, -26.5, 12, 9)
const COOP_GATE := ["s", 0.0, 2.4]
const COOP_BUILDING := Rect2(19, -26.1, 6, 4)
## Dung heap just east of the barn pen.
const MANURE_HEAP := Vector2(62.6, -6.0)

## Areas forced flat: rect (x, z, w, d), target height, falloff distance, strength.
const FLAT_ZONES := [
	{"rect": Rect2(-30, -32, 68, 46), "height": 0.0, "falloff": 14.0, "strength": 1.0},
	{"rect": Rect2(34, -22, 30, 40), "height": 0.0, "falloff": 10.0, "strength": 1.0},
	{"rect": Rect2(-2, 18, 40, 16), "height": 0.0, "falloff": 8.0, "strength": 1.0},
	# Town of Yeşilova.
	{"rect": Rect2(186, -26, 94, 78), "height": 0.0, "falloff": 16.0, "strength": 1.0},
]

## Dirt yards: circles (center, radius).
const DIRT_SPOTS := [
	{"center": Vector2(-15, -10.5), "radius": 3.2},
	{"center": Vector2(-8, -6), "radius": 2.2},
	{"center": Vector2(22, -15.8), "radius": 2.6},
	{"center": Vector2(37.2, 0), "radius": 3.0},
	{"center": Vector2(18, 25), "radius": 9.0},
	# Warehouse yard.
	{"center": Vector2(-27, -3.6), "radius": 3.6},
	# Where Grandpa's pickup stands.
	{"center": FARM_TRUCK_SPOT, "radius": 3.0},
]

## Dirt roads and trails as polylines.
const PATHS := [
	{"width": 2.4, "points": [Vector2(-16, -13), Vector2(-12, -9.5), Vector2(-6, -7.5), Vector2(-4.5, -7)]},
	{"width": 2.6, "points": [Vector2(-16, -13), Vector2(-15, -2), Vector2(-12, 9), Vector2(-7, 15.5)]},
	{"width": 3.6, "points": [Vector2(-128, 24), Vector2(-90, 21), Vector2(-60, 22), Vector2(-30, 17),
			Vector2(-7, 15.5), Vector2(15, 16), Vector2(40, 20), Vector2(57, 22.5)]},
	{"width": 2.2, "points": [Vector2(11.5, -7), Vector2(18, -6), Vector2(28, -1.5), Vector2(36.5, 0)]},
	{"width": 2.0, "points": [Vector2(12.5, -7.5), Vector2(17, -13), Vector2(22, -17)]},
	{"width": 2.0, "points": [Vector2(-6, -8.5), Vector2(-9, -16), Vector2(-9, -28), Vector2(0, -40),
			Vector2(5, -48), Vector2(9, -60)]},
	{"width": 1.8, "points": [Vector2(-15, -2), Vector2(-24, -3), Vector2(-31, -4)]},
	{"width": 2.4, "points": [Vector2(10, 16), Vector2(10, 21)]},
	{"width": 2.4, "points": [Vector2(28, 18.5), Vector2(28, 23)]},
	{"width": 1.8, "points": [Vector2(-12.5, 7), Vector2(-4.3, 7)]},
	{"width": 1.8, "points": [Vector2(-9, -21), Vector2(-4.3, -21)]},
	{"width": 1.8, "points": [Vector2(21, -4.3), Vector2(20.5, 1.3)]},
]

## Static structures that remove meadow grass (buildings added later register
## their own footprint with GrassField.block()).
const NO_GRASS_RECTS := [
	Rect2(-11, -12.4, 1.6, 1.6),   # construction board
	Rect2(-32, -13.5, 10, 11),     # warehouse and its apron
]

const CLEAR_CIRCLES := [
	{"center": Vector2(-8, -6), "radius": 1.6},
]


static func flat_weight(x: float, z: float, zone: Dictionary) -> float:
	var r: Rect2 = zone["rect"]
	var dx := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
	var d := sqrt(dx * dx + dz * dz)
	return (1.0 - smoothstep(0.0, float(zone["falloff"]), d)) * float(zone["strength"])


static func is_cleared(x: float, z: float, margin := 0.0) -> bool:
	for r: Rect2 in NO_GRASS_RECTS:
		if r.grow(margin).has_point(Vector2(x, z)):
			return true
	for c in CLEAR_CIRCLES:
		if Vector2(x, z).distance_to(c["center"]) < float(c["radius"]) + margin:
			return true
	return false


## Distance from a point to the road's control polyline (cheap, for shaping).
static func distance_to_road(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in ROAD_POINTS.size() - 1:
		var a: Vector2 = ROAD_POINTS[i]
		var b: Vector2 = ROAD_POINTS[i + 1]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


## Signed distance to the edge of the playable area (farm valley, town valley and
## the road corridor between them): positive inside.
static func playable_distance(x: float, z: float) -> float:
	var farm := BOUNDARY_RADIUS - Vector2(x, z).length()
	var town := TOWN_BOUNDARY_RADIUS - Vector2(x, z).distance_to(TOWN_CENTER)
	var road := ROAD_CORRIDOR - distance_to_road(x, z)
	return maxf(farm, maxf(town, road))


static func map_rect() -> Rect2:
	return Rect2(MAP_MIN_X, MAP_MIN_Z, MAP_W, MAP_D)


static func distance_to_pond(x: float, z: float) -> float:
	return Vector2(x, z).distance_to(POND_CENTER)


static func house_rect(level: int) -> Rect2:
	var s: Vector2 = HOUSE_SIZES[clampi(level, 1, HOUSE_SIZES.size()) - 1]
	return Rect2(HOUSE_EAST_X - s.x, HOUSE_FRONT_Z - s.y, s.x, s.y)


## Closed fence polyline around `rect` (counter-clockwise from the north-west corner)
## with gate openings. Returns {points: PackedVector2Array, gaps: PackedInt32Array}.
static func fence_around(rect: Rect2, gates: Array) -> Dictionary:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	# Side order along the loop: north (0->1), east (1->2), south (2->3), west (3->0).
	var sides := ["n", "e", "s", "w"]
	var points := PackedVector2Array()
	var gaps := PackedInt32Array()
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		points.append(a)
		for g in gates:
			if g[0] != sides[i]:
				continue
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			var center := mid + dir * float(g[1])
			var half := float(g[2]) * 0.5
			points.append(center - dir * half)
			gaps.append(points.size() - 1)
			points.append(center + dir * half)
	return {"points": points, "gaps": gaps}


## World position just outside a gate (where signs and approach points go).
static func gate_point(rect: Rect2, gate: Array, outside := 1.2) -> Vector3:
	var c := rect.get_center()
	var p := Vector2.ZERO
	match String(gate[0]):
		"n":
			p = Vector2(c.x + float(gate[1]), rect.position.y - outside)
		"s":
			p = Vector2(c.x + float(gate[1]), rect.end.y + outside)
		"w":
			p = Vector2(rect.position.x - outside, c.y + float(gate[1]))
		"e":
			p = Vector2(rect.end.x + outside, c.y + float(gate[1]))
	return Vector3(p.x, 0, p.y)
