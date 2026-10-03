class_name ContestVenue
extends Node3D
## The fishing contest's place (FishingContest), built by Town: the town pond on the meadow
## behind the filling station (a Pond with reed stands between the anglers, no pier: the
## anglers and the player fish from the shore all round it), the contest board facing the
## way the crowd comes (the leaderboard, or the next date and the last winner) and two
## benches for the old men who come to watch. It also knows where the anglers stand
## (angler_spots: spread round the bank, each facing the water, the float's place on it),
## where the crowd watches from (crowd_spots: a couple behind each angler; bench_seats) and
## the way to each place (path_in, path_out): in from the meadow's corner, round the pond
## on a ring between the anglers and the crowd, never through the board, the benches or
## the water; ContestCrowd sends the townspeople there.

const GROUP := &"contest_venue"
## The anglers round the pond (angle, as the pond's reed stands count them: 0 = east,
## PI/2 = south; how far out the float lies), about a fifth of the way round apart; they
## stand ANGLER_BACK up the bank from the waterline, facing the water.
const ANGLERS := [[4.95, 5.0], [6.17, 5.4], [1.22, 4.8], [2.42, 5.2], [3.71, 4.9]]
const ANGLER_BACK := 0.6
## The crowd standing behind the anglers (angle, metres back from the waterline), at
## least one behind each: the visitors, the town's workers and Zeynep (ContestCrowd), in
## that order (the nearest to the way in first).
const CROWD := [[5.07, 3.4], [6.06, 3.0], [4.84, 2.9], [1.11, 3.1], [3.83, 3.3], [2.31, 3.0], [6.29, 3.5],
	[3.6, 3.0], [1.33, 2.8], [2.54, 3.4]]
const BENCHES := [[4.47, 4.4], [4.66, 4.5]]
## The board, back from the shore beside the way in.
const BOARD := [5.3, 3.3]
## The walkers' ring round the pond (metres back from the waterline): behind the anglers,
## in front of the crowd, the benches and the board. Its points are this far apart (radians).
const RING_BACK := 1.9
const RING_STEP := 0.3
## A walker's path keeps this far off the board's and the benches' footprints (metres,
## about a body's width).
const CLEARANCE := 0.45
## Reeds between the anglers, clear of their lines: [angle, half width, clumps].
const REEDS := [[0.55, 0.3, 18], [1.82, 0.3, 18], [3.06, 0.3, 16], [4.33, 0.18, 9]]
const WOOD := Color(0.47, 0.38, 0.29)

## {pos: Vector3, yaw: float, water: Vector3} for each angler.
var angler_spots: Array = []
## {pos, yaw} where the crowd stands, and the benches' seats ({pos, yaw, height}).
var crowd_spots: Array = []
var bench_seats: Array = []
## The way in from the south pavement (world, ground level): past the bus stop, down the
## side of the filling station, onto the meadow (its last point: the meadow's corner).
var approach: Array[Vector3] = []
## What the walkers go round: [centre (Vector2, world xz), half size (Vector2), yaw] for
## the board and each bench.
var footprints: Array = []
var pond: Pond

var _board_label: Label3D


func _ready() -> void:
	add_to_group(GROUP)
	name = "ContestVenue"
	var town := get_parent() as Town
	var c := WorldLayout.TOWN_POND_CENTER
	var r := WorldLayout.TOWN_POND_RADIUS
	pond = Pond.new()
	pond.name = "TownPond"
	pond.center = c
	pond.radius = r
	pond.reed_stands = REEDS
	add_child(pond)
	var mb := MeshBuilder.new()
	var cols: Array = []
	for b: Array in BENCHES:
		var d := _dir(float(b[0]))
		var at := _shore(float(b[0]), float(b[1]))
		var yaw := atan2(-d.x, -d.y)
		var base := Vector3(at.x, TerrainData.height(at.x, at.z) + 0.02, at.z)
		town._bench(mb, cols, base, yaw)
		bench_seats.append({"pos": base + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.12), "yaw": yaw, "height": 0.48})
		footprints.append([Vector2(base.x, base.z), Vector2(0.9, 0.28), yaw])
		Game.world.block_grass(Rect2(base.x - 1.1, base.z - 1.1, 2.2, 2.2))
	_board(mb, cols)
	var mi := MeshInstance3D.new()
	mi.name = "VenueMesh"
	mi.mesh = mb.build()
	add_child(mi)
	BuildingKit.collider(self, cols)
	# The anglers on the bank, each facing the water, the float well out on it.
	for s: Array in ANGLERS:
		var d := _dir(float(s[0]))
		var at := _shore(float(s[0]), ANGLER_BACK)
		var to_water := Vector3(-d.x, 0.0, -d.y)
		angler_spots.append({"pos": at, "yaw": atan2(to_water.x, to_water.z), "water": at + to_water * float(s[1])})
	for s: Array in CROWD:
		var d := _dir(float(s[0]))
		var at := _shore(float(s[0]), float(s[1]))
		crowd_spots.append({"pos": at, "yaw": atan2(-d.x, -d.y) + randf_range(-0.25, 0.25)})
	approach = [Vector3(230.6, 0.0, 24.8), Vector3(230.6, 0.0, 40.0), Vector3(229.2, 0.0, 49.0)]
	_board_label.text = FishingContest.board_text()
	FishingContest.board_changed.connect(_refresh)
	FishingContest.began.connect(_refresh)
	Events.day_started.connect(func(_d: int) -> void: _refresh())
	# The crowd (after the townspeople are in: TownPeople is added before the venue).
	var crowd := ContestCrowd.new()
	crowd.venue = self
	crowd.town = town
	add_child(crowd)


func _refresh() -> void:
	if _board_label:
		_board_label.text = FishingContest.board_text()


## Round the pond at `angle`: (cos, sin) on the map's x and z.
static func _dir(angle: float) -> Vector2:
	return Vector2(cos(angle), sin(angle))


## The point `back` metres up the bank from the waterline at `angle` (negative: out over
## the water), on the ground.
func _shore(angle: float, back: float) -> Vector3:
	var c := WorldLayout.TOWN_POND_CENTER
	var d := _dir(angle)
	var p := c + d * (Pond.shore_radius(c, WorldLayout.TOWN_POND_RADIUS, d) + back)
	return Vector3(p.x, TerrainData.height(p.x, p.y), p.y)


# --- The ways in and out ---------------------------------------------------------------------

## The way from the meadow's corner (approach's last point) to `to` (a place at the pond,
## world): out to the ring at the corner's angle, round it the shorter way to the place's
## angle, then straight to it; round the board and the benches. Ground-level points (y
## 0), `to` itself not included. ContestCrowd walks it as the `via` of each one's place
## (EventCrowd: walked back out the same way).
func path_in(to: Vector3) -> Array[Vector3]:
	var corner := approach[approach.size() - 1]
	var a0 := _angle_of(corner)
	var a1 := _angle_of(to)
	var turn := wrapf(a1 - a0, -PI, PI)
	var n := maxi(1, ceili(absf(turn) / RING_STEP))
	var out: Array[Vector3] = []
	for i in n + 1:
		var p := _shore(a0 + turn * i / n, RING_BACK)
		out.append(Vector3(p.x, 0.0, p.z))
	# The last ring point is at the place's own angle: the place is straight in or out from it.
	var full: Array[Vector3] = [corner]
	full.append_array(out)
	full.append(Vector3(to.x, 0.0, to.z))
	# (a bench sat on is walked up to from in front, not gone round)
	var skip: Array = []
	for fp: Array in footprints:
		if crosses(to, to, fp, 0.05):
			skip.append(fp)
	_go_round(full, skip)
	full.remove_at(full.size() - 1)
	full.remove_at(0)
	return full


## The way from `from` (a place at the pond) back out to the meadow's corner (the corner
## not included): path_in's the other way round.
func path_out(from: Vector3) -> Array[Vector3]:
	var out := path_in(from)
	out.reverse()
	return out


## Round the pond: the angle of `p` (world) from its centre, as ANGLERS count them.
static func _angle_of(p: Vector3) -> float:
	var c := WorldLayout.TOWN_POND_CENTER
	return fposmod(atan2(p.z - c.y, p.x - c.x), TAU)


## Whether the flat segment `a`-`b` (world) passes within `margin` of a footprint
## ([centre, half size, yaw]); `margin` grows the footprint all round.
static func crosses(a: Vector3, b: Vector3, fp: Array, margin: float) -> bool:
	return _seg_box(Vector2(a.x, a.z), Vector2(b.x, b.z), fp, margin) < 0.0


## How far the segment `a`-`b` (flat) stays outside footprint `fp` grown by `margin`
## (negative: it goes through), by sampling it every 10 cm.
static func _seg_box(a: Vector2, b: Vector2, fp: Array, margin: float) -> float:
	var c: Vector2 = fp[0]
	var half: Vector2 = (fp[1] as Vector2) + Vector2(margin, margin)
	var yaw := float(fp[2])
	var n := maxi(1, ceili(a.distance_to(b) / 0.1))
	var best := INF
	for i in n + 1:
		# Into the footprint's own frame (its x along the board or the bench).
		var p := (a.lerp(b, float(i) / n) - c).rotated(yaw)
		var q := Vector2(absf(p.x), absf(p.y)) - half
		best = minf(best, maxf(q.x, q.y) if q.x < 0.0 or q.y < 0.0 else q.length())
	return best


## Bends `points` (a path, its ends fixed) round any footprint (but those in `skip`) a leg
## of it would pass through: a point beside the footprint on the side the leg passed
## nearer, as often as needed (a few times at most).
func _go_round(points: Array[Vector3], skip: Array = []) -> void:
	for guard in 12:
		var bent := false
		for i in points.size() - 1:
			for fp: Array in footprints:
				if fp in skip or not crosses(points[i], points[i + 1], fp, CLEARANCE):
					continue
				var c: Vector2 = fp[0]
				var a := Vector2(points[i].x, points[i].z)
				var b := Vector2(points[i + 1].x, points[i + 1].z)
				var ab := (b - a).normalized()
				var side := Vector2(-ab.y, ab.x)
				if (c - a).dot(side) > 0.0:
					side = -side
				var reach := (fp[1] as Vector2).length() + CLEARANCE + 0.25
				var mid := c + side * reach
				points.insert(i + 1, Vector3(mid.x, 0.0, mid.y))
				bent = true
				break
			if bent:
				break
		if not bent:
			return


## The contest board: a painted signboard on two posts back from the shore, facing the
## way the crowd comes in, with the leaderboard written on it (Label3D).
func _board(mb: MeshBuilder, cols: Array) -> void:
	var at := _shore(float(BOARD[0]), float(BOARD[1]))
	var face := Vector3(229.2 - at.x, 0.0, 49.0 - at.z).normalized()
	var yaw := atan2(face.x, face.z)
	var b := Basis(Vector3.UP, yaw)
	for sx: float in [-0.75, 0.75]:
		mb.box(&"wood_ext", Transform3D(b, at + b * Vector3(sx, 0.95, 0.0)), Vector3(0.09, 1.9, 0.09), WOOD.darkened(0.2))
	# The board: a frame round a cream painted panel.
	var panel := at + b * Vector3(0, 1.35, 0.05)
	mb.box(&"paint_ext", Transform3D(b, panel), Vector3(1.6, 0.95, 0.04), Color(0.86, 0.82, 0.7))
	mb.box(&"wood_ext", Transform3D(b, panel + b * Vector3(0, 0.5, 0.0)), Vector3(1.7, 0.06, 0.07), WOOD.darkened(0.1))
	mb.box(&"wood_ext", Transform3D(b, panel + b * Vector3(0, -0.5, 0.0)), Vector3(1.7, 0.06, 0.07), WOOD.darkened(0.1))
	# A little roof over it against the rain.
	mb.box(&"wood_ext", Transform3D(b * Basis(Vector3.RIGHT, deg_to_rad(-18.0)), at + b * Vector3(0, 1.94, 0.08)), Vector3(1.9, 0.04, 0.42), WOOD.darkened(0.3))
	cols.append([at + Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 0.2), b])
	# (the roof over it reaches out further than the posts)
	footprints.append([Vector2(at.x, at.z), Vector2(0.95, 0.22), yaw])
	_board_label = Label3D.new()
	_board_label.name = "BoardText"
	_board_label.font = UiTheme.font(700)
	_board_label.font_size = 40
	_board_label.pixel_size = 0.0021
	_board_label.modulate = Color(0.16, 0.12, 0.09)
	_board_label.outline_size = 0
	_board_label.shaded = true
	_board_label.double_sided = false
	_board_label.line_spacing = -2.0
	_board_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_board_label.width = 700.0
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_label.position = panel + b * Vector3(0, 0, 0.03) - global_position
	_board_label.rotation.y = yaw
	add_child(_board_label)
	Game.world.block_grass(Rect2(at.x - 1.0, at.z - 1.0, 2.0, 2.0))
