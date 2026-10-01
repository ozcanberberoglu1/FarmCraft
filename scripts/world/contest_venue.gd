class_name ContestVenue
extends Node3D
## The fishing contest's place (FishingContest), built by Town: the town pond on the meadow
## behind the filling station (a Pond with reeds along its far side, the shore ring open
## for the pier), a wooden pier with railings out from its north shore, the contest board
## by the pier (the leaderboard, or the next date and the last winner) and two benches
## for the old men who come to watch. It also knows where the anglers stand (angler_spots:
## on the pier and along the shore, the float's place on the water) and where the crowd
## watches from (crowd_spots, bench_seats); ContestCrowd sends the townspeople there.

const GROUP := &"contest_venue"
## Round the pond, as the pond's reed stands count angles (0 = east, PI/2 = south).
const PIER_ANGLE := 5.0
const PIER_LENGTH := 6.4
const PIER_WIDTH := 1.8
## How far the pier's root runs up onto the bank (metres past the waterline).
const PIER_ROOT := 1.6
## The anglers' places on the shore (angle, how far out the float lies).
const SHORE_ANGLERS := [[3.35, 5.0], [4.2, 5.4], [5.85, 4.8]]
## The crowd standing behind the north shore (angle, metres back from the waterline).
const CROWD := [[4.42, 3.4], [5.62, 3.1], [4.95, 4.6], [5.17, 5.2], [4.66, 4.5], [5.82, 4.2]]
const BENCHES := [[4.53, 2.3], [4.82, 2.4]]
const BOARD := [5.38, 1.6]
## Reeds on the far side, clear of the anglers: [angle, half width, clumps].
const REEDS := [[0.75, 0.38, 22], [1.55, 0.42, 26], [2.35, 0.3, 16], [2.85, 0.14, 7], [0.15, 0.1, 5]]
const WOOD := Color(0.47, 0.38, 0.29)

## {pos: Vector3, yaw: float, water: Vector3} for each angler (the pier's end first).
var angler_spots: Array = []
## {pos, yaw} where the crowd stands, and the benches' seats ({pos, yaw, height}).
var crowd_spots: Array = []
var bench_seats: Array = []
## The way in from the south pavement (world, ground level): past the bus stop, down the
## side of the filling station, onto the meadow.
var approach: Array[Vector3] = []
var pond: Pond

var _board_label: Label3D
var _deck_y := 0.0


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
	pond.wall_gap = PackedFloat32Array([PIER_ANGLE - 0.21, PIER_ANGLE + 0.21])
	add_child(pond)
	var mb := MeshBuilder.new()
	var cols: Array = []
	_pier(mb, cols)
	for b: Array in BENCHES:
		var d := _dir(float(b[0]))
		var at := _shore(float(b[0]), float(b[1]))
		var yaw := atan2(-d.x, -d.y)
		var base := Vector3(at.x, TerrainData.height(at.x, at.z) + 0.02, at.z)
		town._bench(mb, cols, base, yaw)
		bench_seats.append({"pos": base + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.12), "yaw": yaw, "height": 0.48})
		Game.world.block_grass(Rect2(base.x - 1.1, base.z - 1.1, 2.2, 2.2))
	_board(mb, cols)
	var mi := MeshInstance3D.new()
	mi.name = "VenueMesh"
	mi.mesh = mb.build()
	add_child(mi)
	BuildingKit.collider(self, cols)
	# Anglers: two at the pier's end, the rest along the shore facing the water.
	var pd := _dir(PIER_ANGLE)
	var inward := Vector3(-pd.x, 0.0, -pd.y)
	var side := Vector3(-inward.z, 0.0, inward.x)
	var end := _shore(PIER_ANGLE, -PIER_LENGTH + PIER_ROOT + 0.75)
	for k: float in [-0.45, 0.45]:
		var at := end + side * k
		var out := (inward + side * k * 0.9).normalized()
		angler_spots.append({"pos": Vector3(at.x, _deck_y, at.z), "yaw": atan2(out.x, out.z), "water": at + out * 5.5})
	for s: Array in SHORE_ANGLERS:
		var d := _dir(float(s[0]))
		var at := _shore(float(s[0]), 0.55)
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


## The pier: weathered planks on two stringers over pairs of posts driven into the
## pond's bed, a rail along each side; the ring that keeps the player on the shore stands
## round its sides and end (invisible), its root on the bank.
func _pier(mb: MeshBuilder, cols: Array) -> void:
	var root := _shore(PIER_ANGLE, PIER_ROOT)
	var tip := _shore(PIER_ANGLE, PIER_ROOT - PIER_LENGTH)
	_deck_y = maxf(root.y + 0.06, WorldLayout.WATER_LEVEL + 0.5)
	var along := Vector3(tip.x - root.x, 0.0, tip.z - root.z)
	var length := along.length()
	along /= length
	var yaw := atan2(along.x, along.z)
	var b := Basis(Vector3.UP, yaw)
	var o := Vector3(root.x, _deck_y, root.z)
	var half := PIER_WIDTH * 0.5
	# Planks across, a finger's gap apart, each a shade different.
	var n := int(length / 0.2)
	for i in n:
		var z := (i + 0.5) * length / n
		var tint := WOOD.darkened(0.04 * (i % 3)).lightened(0.03 * ((i * 7) % 4))
		mb.box(&"planks_ext", Transform3D(b, o + b * Vector3(0, -0.025, z)), Vector3(PIER_WIDTH, 0.05, length / n - 0.015), tint)
	# Stringers under the planks, and the posts down into the bed.
	for sx: float in [-half + 0.12, half - 0.12]:
		mb.box(&"wood_ext", Transform3D(b, o + b * Vector3(sx, -0.12, length * 0.5)), Vector3(0.1, 0.14, length), WOOD.darkened(0.2))
	var posts := 4
	for k in posts:
		var z := 0.3 + (length - 0.5) * k / (posts - 1)
		for sx: float in [-half + 0.06, half - 0.06]:
			var top := o + b * Vector3(sx, 0.95, z)
			var bed := TerrainData.height(top.x, top.z)
			var h := top.y - bed + 0.2
			mb.box(&"wood_ext", Transform3D(b, Vector3(top.x, top.y - h * 0.5, top.z)), Vector3(0.12, h, 0.12), WOOD.darkened(0.25))
	# The rails.
	for sx: float in [-half + 0.06, half - 0.06]:
		mb.box(&"wood_ext", Transform3D(b, o + b * Vector3(sx, 0.95, length * 0.5 + 0.05)), Vector3(0.09, 0.07, length - 0.3), WOOD)
		mb.box(&"wood_ext", Transform3D(b, o + b * Vector3(sx, 0.5, length * 0.5 + 0.05)), Vector3(0.05, 0.06, length - 0.3), WOOD.darkened(0.1))
	# The deck to walk on, the rails and the open end as walls (the end's is invisible).
	var mid := o + b * Vector3(0, -0.06, length * 0.5)
	cols.append([mid, Vector3(PIER_WIDTH, 0.12, length), b])
	for sx: float in [-half, half]:
		cols.append([o + b * Vector3(sx, 0.6, length * 0.5 + 0.6), Vector3(0.12, 1.2, length - 1.2), b])
	cols.append([o + b * Vector3(0, 0.6, length + 0.05), Vector3(PIER_WIDTH, 1.2, 0.12), b])
	# A step up onto it from the bank.
	var step := o + b * Vector3(0, -0.12, -0.25)
	mb.box(&"wood_ext", Transform3D(b, step), Vector3(PIER_WIDTH - 0.2, 0.1, 0.4), WOOD.darkened(0.12))
	cols.append([step, Vector3(PIER_WIDTH - 0.2, 0.1, 0.4), b])
	Game.world.block_grass(Rect2(root.x - 1.6, root.z - 1.6, 3.2, 3.2))
	# The shore ring is open for the pier: closed again on either side of it, up to its rails.
	var ring := WorldLayout.TOWN_POND_RADIUS - 0.9
	var edge := (half + 0.05) / ring
	for span: Vector2 in [Vector2(PIER_ANGLE - 0.32, PIER_ANGLE - edge), Vector2(PIER_ANGLE + edge, PIER_ANGLE + 0.32)]:
		var m := (span.x + span.y) * 0.5
		var w := ring * (span.y - span.x)
		# Part of the pond's own ring: casts fly over it as over the rest.
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w, 4.0, 0.4)
		cs.shape = box
		cs.position = Vector3(cos(m) * ring, 1.0, sin(m) * ring)
		cs.rotation.y = -m + PI * 0.5
		pond.shore_wall().add_child(cs)


## The contest board: a painted signboard on two posts by the pier, facing the way the
## crowd comes, with the leaderboard written on it (Label3D).
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
