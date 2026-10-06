extends Node
## Pastures ("mera"): the farmer fences his own grazing with panels and a gate (FencePiece,
## put down by FencePlacing) and lights it against the wolves with lantern posts
## (LanternPost). This knows the loops the pieces close and what follows from them.
##
## A PASTURE is a closed loop of fence with at least one gate in it. The fence of the
## barn's pen (and of Grandpa's run) counts as part of a loop, so a pasture can lean on
## the pen: runs start at its corners or anywhere along it. Building walls don't count
## (a pasture stands in the open). When a loop closes it is recognised: a soft chime, its
## posts flash green once, a note, and a little board on the gate's post with its size in
## m² ("MERA 2 · 64 m²" when there are several). The same loop is found again from the
## saved pieces after a load (quietly).
##
## ANIMALS (sheep, cows, horses; not the birds): one let go of the halter inside a
## pasture stays there: it grazes and wanders within the loop instead of walking home,
## lies down there at night, and comes out only on the halter, through the open gate
## (Animal asks: settle, decide, keep, scare). A pasture that takes in the ground in front
## of the barn pen's gateway ("barn") needs no halter: the barn's animals walk out into
## it by themselves in the morning and home again at dusk (HOME_HOUR), or when it rains.
## Grazing in a pasture by day (GameClock: not at night, in winter or under snow):
##   - PASTURE_HAPPY more contentment an hour (on top of the usual),
##   - the grass and its dew keep its thirst off (PASTURE_WATER an hour, up to WATER_CAP),
##   - it eats nothing from its trough meanwhile, and after GRAZED_HOURS of it that day
##     it is "well grazed": hungry PASTURE_SAVING slower until the next morning
##     (hunger_rate: Animals asks).
## Left there overnight it is out in the night (wolves, rain): at DUSK_HOUR a note says how
## many are still out. They are there the next morning too (winter and snow bring them
## home: nothing to graze).
##
## WOLVES keep SAFE metres off a lit lantern post as off a burning campfire (lantern_near,
## lantern_escape: Wolf; guards: WolfRaids). A night slept through counts the animals of
## a pasture whose whole ground lies in lantern light as protected, the others as out
## in the open (`asleep`). Fences alone stop no wolf: it leaps them.
##
## The side goals that teach all this are PastureGoals (`goals`); what they and the day's
## grazing keep is saved in FarmState.flags, the pieces themselves in FarmState.placed
## (FencePiece: "len", "open") and an animal out at pasture as AnimalData.away with its spot.

## The pastures were worked out again.
signal changed
## A loop closed into a pasture (or changed its shape).
signal recognised(pasture: Dictionary)

## Posts nearer than this (m) are one post.
const MERGE := 0.3
## The smallest loop that is a pasture (m²).
const MIN_AREA := 6.0
## Grazing in a pasture: contentment and water an hour (water up to WATER_CAP), the hours
## that make an animal well grazed and how much slower it then gets hungry till morning.
const PASTURE_HAPPY := 2.0
const PASTURE_WATER := 6.0
const WATER_CAP := 75.0
const GRAZED_HOURS := 3.0
const PASTURE_SAVING := 0.5
## Game hours: the dusk note about animals still out; the barn's animals walk out into
## a pasture at their gateway from OUT_HOUR and home at HOME_HOUR.
const DUSK_HOUR := 18.0
const OUT_HOUR := 6.5
const HOME_HOUR := 18.5
## How far outside the barn pen's gateway (m) a pasture must reach to be the barn's own.
const GATEWAY_OUT := 1.6
## A pasture's ground is sampled this often (m) to see whether lanterns light all of it.
const COVER_STEP := 2.0
const SIGN_COLOR := Color(0.96, 0.9, 0.74)
const FLAG_GRAZED := "pasture_grazed"
const FLAG_DUSK := "pasture_dusk_day"

## The pastures now: {key, number, poly (PackedVector2Array of x, z), area (m²), center,
## posts (Array[Vector3]), gates (Array[FencePiece]), barn (it takes in the barn pen's
## gateway), covered (lanterns light all of it), box (Rect2 of its bounds)}.
var pastures: Array[Dictionary] = []
## The side goals that teach fencing a pasture.
var goals: PastureGoals
## The farmer is asleep (or down): the wolves' night is worked out (see guards).
var asleep := false

var _dirty := true
var _world_id := 0
## The first working-out after a world is built makes no fuss about loops found.
var _quiet := true
var _known := {}
var _points: Array[Vector3] = []
var _piece_points: Array[Vector3] = []
## Animals out at pasture (id -> where), and the barn's on their way out to one (id -> its key).
var _grazers := {}
var _walkers := {}
var _holder: Node3D
var _lanterns: Array[LanternPost] = []
var _lantern_tick := -1
var _poll := 0.0
var _asleep_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	goals = PastureGoals.new()
	goals.name = "PastureGoals"
	add_child(goals)
	Events.clock_tick.connect(_on_tick)
	Events.day_started.connect(_on_day_started)
	Events.day_ending.connect(func() -> void: _set_asleep(true))
	Events.player_knocked_out.connect(func() -> void: _set_asleep(true))


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_ensure()
	if asleep:
		# Never left on by a night that didn't come (a sleep called off).
		_asleep_left -= delta
		if _asleep_left <= 0.0:
			asleep = false
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		_dusk_note()


func _set_asleep(on: bool) -> void:
	asleep = on
	_asleep_left = 30.0


## A piece was put down, taken up or its world rebuilt: the loops are worked out again.
func mark_dirty() -> void:
	_dirty = true
	_lantern_tick = -1


## A gate swung open or shut.
func gate_moved(_gate: FencePiece) -> void:
	changed.emit()


# --- The loops -----------------------------------------------------------------------------

func _farm() -> Farm:
	var world := Game.world
	if world == null or not is_instance_valid(world):
		return null
	return world.get("farm") as Farm


## Works the pastures out again when anything changed (and afresh for a new world).
func _ensure() -> void:
	var farm := _farm()
	if farm == null or not farm.is_inside_tree():
		return
	var id := farm.get_instance_id()
	if id != _world_id:
		_world_id = id
		_known.clear()
		_grazers.clear()
		_walkers.clear()
		_holder = null
		_quiet = true
		_dirty = true
	if _dirty:
		_rebuild(farm)


## The fence's pieces standing now.
func pieces() -> Array[FencePiece]:
	var out: Array[FencePiece] = []
	for n in get_tree().get_nodes_in_group(FencePiece.GROUP):
		var fp := n as FencePiece
		if fp and fp.is_inside_tree() and not fp.is_queued_for_deletion():
			out.append(fp)
	return out


## The lantern posts standing now (looked up once a physics tick: every wolf asks, often).
func lantern_posts() -> Array[LanternPost]:
	var tick := Engine.get_physics_frames()
	if tick == _lantern_tick:
		return _lanterns
	_lantern_tick = tick
	_lanterns = []
	for n in get_tree().get_nodes_in_group(LanternPost.GROUP):
		var lp := n as LanternPost
		if lp and lp.is_inside_tree() and not lp.is_queued_for_deletion():
			_lanterns.append(lp)
	return _lanterns


## The pens whose own fence a loop may lean on (world rects): the barn's and Grandpa's run.
func _pen_rects(farm: Farm) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for h: AnimalHousing in [farm.barn, farm.coop]:
		if h != null and h.level > 0 and not h.placed:
			out.append(h.pen)
	return out


func _rebuild(farm: Farm) -> void:
	_dirty = false
	var nodes: Array[Vector2] = []
	## [node, node, piece (null: a pen's own fence)]
	var edges: Array = []
	var ends_of := {}
	var all := pieces()
	for fp in all:
		var e := fp.ends()
		var i := _node(nodes, Vector2(e[0].x, e[0].z))
		var j := _node(nodes, Vector2(e[1].x, e[1].z))
		ends_of[fp] = [i, j]
		if i != j:
			edges.append([i, j, fp])
	_piece_points.clear()
	for p in nodes:
		_piece_points.append(Vector3(p.x, TerrainData.height(p.x, p.y), p.y))
	var lanterns := lantern_posts()
	# The pens' fences: each side from corner to corner, through the posts set on it.
	for rect in _pen_rects(farm):
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		var ids: Array[int] = []
		for c in corners:
			ids.append(_node(nodes, c))
		for s in 4:
			var a := corners[s]
			var b := corners[(s + 1) % 4]
			var on: Array = []
			for k in nodes.size():
				if k == ids[s] or k == ids[(s + 1) % 4]:
					continue
				var t := (nodes[k] - a).dot(b - a) / (b - a).length_squared()
				if t > 0.0 and t < 1.0 and nodes[k].distance_to(a.lerp(b, t)) < MERGE:
					on.append([t, k])
			on.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
			var at := ids[s]
			for o: Array in on:
				edges.append([at, int(o[1]), null])
				at = int(o[1])
			edges.append([at, ids[(s + 1) % 4], null])
	_points.clear()
	for p in nodes:
		_points.append(Vector3(p.x, TerrainData.height(p.x, p.y), p.y))
	for lp in lanterns:
		_points.append(lp.global_position)
	_own_posts(all, ends_of, nodes, lanterns)
	var found := _faces(nodes, edges)
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var cx: Vector3 = x["center"]
		var cy: Vector3 = y["center"]
		return cx.x < cy.x if absf(cx.x - cy.x) > 0.01 else cx.z < cy.z)
	var barn_out := Vector2.INF
	if farm.barn != null and farm.barn.level > 0 and not farm.barn.gate.is_empty():
		var g := WorldLayout.gate_point(farm.barn.pen, farm.barn.gate, GATEWAY_OUT)
		barn_out = Vector2(g.x, g.z)
	for i in found.size():
		var p := found[i]
		p["number"] = i + 1
		p["barn"] = barn_out != Vector2.INF and Geometry2D.is_point_in_polygon(barn_out, p["poly"])
		p["covered"] = _covered(p, lanterns)
	pastures.assign(found)
	_put_signs(farm)
	var keys := {}
	for p in pastures:
		keys[p["key"]] = true
		if not _known.has(p["key"]) and not _quiet:
			_announce(farm, p)
	_known = keys
	_quiet = false
	changed.emit()


## The index in `nodes` of the post at `p` (a new one unless one stands within MERGE).
func _node(nodes: Array[Vector2], p: Vector2) -> int:
	for i in nodes.size():
		if nodes[i].distance_to(p) < MERGE:
			return i
	nodes.append(p)
	return nodes.size() - 1


## Which piece draws the post at each shared end: a gate's are always its own (sturdier);
## of panels the first; none where a lantern post stands.
func _own_posts(all: Array[FencePiece], ends_of: Dictionary, nodes: Array[Vector2], lanterns: Array[LanternPost]) -> void:
	var taken := {}
	for i in nodes.size():
		for lp in lanterns:
			if Vector2(lp.global_position.x, lp.global_position.z).distance_to(nodes[i]) < MERGE:
				taken[i] = true
	for fp in all:
		if fp.is_gate():
			for i: int in ends_of[fp]:
				taken[i] = true
	for fp in all:
		if fp.is_gate():
			continue
		var own: Array[bool] = []
		for i: int in ends_of[fp]:
			own.append(not taken.has(i))
			taken[i] = true
		fp.set_posts(own[0], own[1])


## The closed loops among `edges` with a gate in them, as pastures: dead ends are cut
## away, then every face of what is left is walked round (always taking the next edge
## clockwise at each post); the faces with ground inside come out with a positive area.
func _faces(nodes: Array[Vector2], edges: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var alive: Array[bool] = []
	var degree: Array[int] = []
	degree.resize(nodes.size())
	degree.fill(0)
	var seen := {}
	for e: Array in edges:
		# One edge between two posts.
		var k := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
		var ok: bool = e[0] != e[1] and not seen.has(k)
		seen[k] = true
		alive.append(ok)
		if ok:
			degree[e[0]] += 1
			degree[e[1]] += 1
	var cut := true
	while cut:
		cut = false
		for i in edges.size():
			if alive[i] and (degree[edges[i][0]] < 2 or degree[edges[i][1]] < 2):
				alive[i] = false
				degree[edges[i][0]] -= 1
				degree[edges[i][1]] -= 1
				cut = true
	var adj := {}
	for i in edges.size():
		if not alive[i]:
			continue
		for d in 2:
			var from: int = edges[i][d]
			var to: int = edges[i][1 - d]
			if not adj.has(from):
				adj[from] = []
			(adj[from] as Array).append([to, i, (nodes[to] - nodes[from]).angle()])
	for n: int in adj:
		(adj[n] as Array).sort_custom(func(x: Array, y: Array) -> bool: return x[2] < y[2])
	var walked := {}
	for i in edges.size():
		if not alive[i]:
			continue
		for d in 2:
			var u: int = edges[i][d]
			var v: int = edges[i][1 - d]
			var e := i
			var loop: Array[int] = []
			var used: Array[int] = []
			var guard := 0
			while not walked.has(Vector3i(u, v, e)) and guard < 4096:
				guard += 1
				walked[Vector3i(u, v, e)] = true
				loop.append(u)
				used.append(e)
				var list: Array = adj[v]
				var at := 0
				for k in list.size():
					if int(list[k][0]) == u and int(list[k][1]) == e:
						at = k
						break
				var next: Array = list[(at - 1 + list.size()) % list.size()]
				u = v
				v = int(next[0])
				e = int(next[1])
			if loop.size() < 3:
				continue
			var poly := PackedVector2Array()
			for n in loop:
				poly.append(nodes[n])
			var area := _area(poly)
			if area < MIN_AREA:
				continue
			var gates: Array[FencePiece] = []
			for k in used:
				var fp := edges[k][2] as FencePiece
				if fp != null and fp.is_gate() and not gates.has(fp):
					gates.append(fp)
			if gates.is_empty():
				continue
			var mid := Vector2.ZERO
			var box := Rect2(poly[0], Vector2.ZERO)
			var posts: Array[Vector3] = []
			for q in poly:
				mid += q
				box = box.expand(q)
				posts.append(Vector3(q.x, TerrainData.height(q.x, q.y), q.y))
			mid /= poly.size()
			out.append({"key": "%d:%d:%d" % [roundi(mid.x), roundi(mid.y), roundi(area)], "poly": poly, "area": area,
				"center": Vector3(mid.x, TerrainData.height(mid.x, mid.y), mid.y), "posts": posts, "gates": gates, "box": box})
	return out


## A polygon's area by the shoelace sum: positive when it runs the way _faces walks the
## faces that have ground inside.
static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


## Whether lantern posts light all of pasture `p`'s ground (its posts and a grid over it,
## each within LanternPost.SAFE of one).
func _covered(p: Dictionary, lanterns: Array[LanternPost]) -> bool:
	if lanterns.is_empty():
		return false
	var poly: PackedVector2Array = p["poly"]
	var box: Rect2 = p["box"]
	var samples: Array[Vector2] = []
	for q in poly:
		samples.append(q)
	var x := box.position.x + COVER_STEP * 0.5
	while x < box.end.x:
		var z := box.position.y + COVER_STEP * 0.5
		while z < box.end.y:
			if Geometry2D.is_point_in_polygon(Vector2(x, z), poly):
				samples.append(Vector2(x, z))
			z += COVER_STEP
		x += COVER_STEP
	for s in samples:
		var lit := false
		for lp in lanterns:
			if Vector2(lp.global_position.x, lp.global_position.z).distance_to(s) < LanternPost.SAFE:
				lit = true
				break
		if not lit:
			return false
	return true


## The posts a new piece can start from or end at: every piece's ends, the lantern posts
## and the corners of the pens' fences (`with_pens` off: the pieces' own posts only).
func snap_points(with_pens := true) -> Array[Vector3]:
	_ensure()
	return _points if with_pens else _piece_points


## The pasture whose ground `p` stands on ({} when none).
func pasture_at(p: Vector3) -> Dictionary:
	_ensure()
	var pt := Vector2(p.x, p.z)
	for pasture in pastures:
		if (pasture["box"] as Rect2).has_point(pt) and Geometry2D.is_point_in_polygon(pt, pasture["poly"]):
			return pasture
	return {}


## What a pasture is called: "Mera", or "Mera 2" when there are several.
func pasture_name(p: Dictionary) -> String:
	if pastures.size() < 2:
		return tr("PASTURE_NAME")
	return "%s %d" % [tr("PASTURE_NAME"), int(p.get("number", 1))]


## How far inside pasture `pasture`'s fence `p` is (m; negative outside it).
func depth(pasture: Dictionary, p: Vector3) -> float:
	var poly: PackedVector2Array = pasture["poly"]
	var pt := Vector2(p.x, p.z)
	if not Geometry2D.is_point_in_polygon(pt, poly):
		return -1.0
	var best := INF
	for i in poly.size():
		best = minf(best, Geometry2D.get_closest_point_to_segment(pt, poly[i], poly[(i + 1) % poly.size()]).distance_to(pt))
	return best


# --- Recognised: the board, the flash ---------------------------------------------------------

func _holder_node(farm: Farm) -> Node3D:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node3D.new()
		_holder.name = "PastureSigns"
		_holder.top_level = true
		farm.add_child(_holder)
	return _holder


## A little board on each pasture's first gate's hinge post: its name and its size.
func _put_signs(farm: Farm) -> void:
	var holder := _holder_node(farm)
	for c in holder.get_children():
		if c.is_in_group(&"pasture_signs"):
			c.queue_free()
	for p in pastures:
		var gate: FencePiece = (p["gates"] as Array)[0]
		var board := Node3D.new()
		board.add_to_group(&"pasture_signs")
		board.set_meta(&"pasture", p["key"])
		var hinge := gate.ends()[0]
		board.position = hinge + Vector3(0, FenceModels.GATE_POST + 0.26, 0)
		board.rotation.y = gate.rotation.y
		var mi := MeshInstance3D.new()
		var mb := MeshBuilder.new()
		mb.box_at(&"wood", Vector3(0, 0, 0), Vector3(0.7, 0.3, 0.03), Color(0.5, 0.44, 0.38))
		mb.box_at(&"fence_wood", Vector3(0, -0.2, 0), Vector3(0.05, 0.16, 0.05), FenceModels.WOOD_DARK)
		mi.mesh = mb.build()
		board.add_child(mi)
		var text := sign_text(p)
		for side: float in [1.0, -1.0]:
			var label := Label3D.new()
			label.text = text
			label.font = UiTheme.font(800)
			label.font_size = 40
			label.pixel_size = 0.0026
			label.outline_size = 8
			label.outline_modulate = Color(0.12, 0.09, 0.06, 0.9)
			label.modulate = SIGN_COLOR
			label.line_spacing = -6.0
			label.double_sided = false
			label.position = Vector3(0, 0.0, side * 0.018)
			label.rotation.y = 0.0 if side > 0.0 else PI
			label.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			board.add_child(label)
		holder.add_child(board)


## The board's two lines: "MERA 2" over "64 m²".
func sign_text(p: Dictionary) -> String:
	return "%s\n%d m²" % [UiTheme.caps(pasture_name(p)), roundi(float(p["area"]))]


## A loop has just closed: a soft chime, its posts flash green once, a note.
func _announce(farm: Farm, p: Dictionary) -> void:
	Audio.ui("confirm", -9.0)
	Game.notify(tr("MSG_PASTURE_RECOGNISED") % [pasture_name(p), roundi(float(p["area"]))], UiTheme.GREEN)
	flash(farm, p)
	recognised.emit(p)


## The posts of pasture `p` glow green and fade.
func flash(farm: Farm, p: Dictionary) -> void:
	var holder := _holder_node(farm)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 1.0, 0.45, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.4)
	mat.emission_energy_multiplier = 2.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.13
	mesh.bottom_radius = 0.13
	mesh.height = FenceModels.POST + 0.2
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = mat
	var glow := Node3D.new()
	glow.name = "PastureFlash"
	for post: Vector3 in p["posts"]:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = post + Vector3(0, mesh.height * 0.5, 0)
		glow.add_child(mi)
	holder.add_child(glow)
	var tw := glow.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.8, 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(glow.queue_free)


# --- Lanterns and wolves ---------------------------------------------------------------------

## A lit lantern post within its reach of `p`: no wolf goes there (Wolf).
func lantern_near(p: Vector3) -> bool:
	return _lantern_within(p, true)


## Out of a lit lantern's reach from `p`: the way to go (zero when `p` is in none).
func lantern_escape(p: Vector3) -> Vector3:
	for lp in lantern_posts():
		if not lp.is_lit():
			continue
		var d := Vector3(p.x - lp.global_position.x, 0.0, p.z - lp.global_position.z)
		if d.length() < LanternPost.SAFE:
			return d.normalized() if d.length() > 0.01 else Vector3.RIGHT
	return Vector3.ZERO


## Whether lantern light keeps the wolves off an animal at `p` tonight (WolfRaids.near_fire).
## Awake: a lit lantern within its reach. With the farmer asleep the night is worked out
## from where the animals are as he goes to bed: one in a pasture is safe when lanterns
## light the whole of it (it moves about in there), any other by a lantern near it.
func guards(p: Vector3) -> bool:
	if not asleep:
		return _lantern_within(p, true)
	var pasture := pasture_at(p)
	if not pasture.is_empty():
		return bool(pasture["covered"])
	return _lantern_within(p, false)


func _lantern_within(p: Vector3, lit_only: bool) -> bool:
	for lp in lantern_posts():
		if lit_only and not lp.is_lit():
			continue
		if Vector2(lp.global_position.x - p.x, lp.global_position.z - p.z).length() < LanternPost.SAFE:
			return true
	return false


# --- Animals at pasture ----------------------------------------------------------------------

## One that grazes in a pasture: the farmer's own sheep, cow or horse.
func grazes(a: Animal) -> bool:
	return a != null and a.data != null and not AnimalTable.is_poultry(a.data.species) and a.owned()


## The animals out at pasture now.
func grazing() -> Array[Animal]:
	var out: Array[Animal] = []
	for id: int in _grazers:
		var d := Animals.by_id(id)
		var n := Animals.node_of(d) if d else null
		if n != null and d.away:
			out.append(n)
	return out


func is_grazing(a: Animal) -> bool:
	return a != null and a.data != null and _grazers.has(a.data.id) and a.data.away


## Hours animal `id` has grazed in a pasture today.
func grazed_hours(id: int) -> float:
	return float((FarmState.flags.get(FLAG_GRAZED, {}) as Dictionary).get(id, 0.0))


## Grazed long enough today to be hungry slower until the morning.
func well_grazed(id: int) -> bool:
	return grazed_hours(id) >= GRAZED_HOURS


## How fast animal `id` gets hungry now against the usual (Animals._simulate): slower
## for one well grazed today.
func hunger_rate(id: int) -> float:
	return 1.0 - PASTURE_SAVING if well_grazed(id) else 1.0


## Animal.settle hook: let go (off the halter, off a horse) inside a pasture, it stays
## there. True when it does.
func settle(a: Animal) -> bool:
	if not grazes(a):
		return false
	var pasture := pasture_at(a.global_position)
	if pasture.is_empty():
		_grazers.erase(a.data.id)
		return false
	_begin(a)
	if not DebugTools.is_automated() or goals.testing:
		Game.notify(tr("MSG_PASTURE_GRAZING") % [a.data.name, pasture_name(pasture)], UiTheme.GREEN)
	return true


func _begin(a: Animal) -> void:
	a.data.away = true
	a.data.away_pos = a.global_position
	a.data.away_yaw = a.rotation.y
	a.indoors = false
	_walkers.erase(a.data.id)
	_grazers[a.data.id] = a.global_position
	a._path.clear()
	a._path_inside.clear()
	a._set_state(Animal.State.IDLE, a._rng.randf_range(1.0, 2.5))


## Animal._decide hook: what one at pasture (or on its way to one) does next. False for
## every other animal (its usual ways).
func decide(a: Animal) -> bool:
	if a.data == null or a.ridden or a.led or a.carried:
		return false
	var id := a.data.id
	if _walkers.has(id):
		return _decide_walker(a)
	if not a.data.away:
		_grazers.erase(id)
		return _try_walk_out(a)
	var pasture := pasture_at(a.global_position)
	if pasture.is_empty():
		if _grazers.has(id):
			# Its fence is gone from round it: home it goes, as one let go in the open.
			_grazers.erase(id)
			a.data.away = false
			a._settle_where_left()
			return true
		return false
	if not grazes(a):
		return false
	_grazers[id] = a.global_position
	a.data.away_pos = a.global_position
	a.data.away_yaw = a.rotation.y
	if a.state == Animal.State.WANDER and not a._path.is_empty():
		return true
	if bool(pasture["barn"]) and _home_time():
		_walk_home(a)
		return true
	if GameClock.is_night():
		if a.state != Animal.State.SLEEP:
			a._set_state(Animal.State.SLEEP, 1e9)
		return true
	if a.state not in [Animal.State.IDLE, Animal.State.GRAZE, Animal.State.WANDER]:
		a._set_state(Animal.State.IDLE, a._rng.randf_range(1.0, 3.0))
		return true
	if a._busy():
		return true
	var roll := a._rng.randf()
	if a._grazing_ok() and roll < 0.55:
		a._set_state(Animal.State.GRAZE, a._rng.randf_range(6.0, 16.0))
	elif roll < 0.85:
		var to := _random_point(pasture, a)
		if to == Vector3.INF:
			a._set_state(Animal.State.IDLE, a._rng.randf_range(2.0, 5.0))
		else:
			_walk(a, [to], Animal.State.WANDER)
	else:
		a._set_state(Animal.State.IDLE, a._rng.randf_range(3.0, 8.0))
	return true


## Animal._move hook: where its step from `from` to `to` may take it. One at pasture
## keeps within its fence (no nearer it than its own width, unless it is on its way in
## from there), one on its way out to a pasture goes free, any other keeps to its pen.
func keep(a: Animal, from: Vector3, to: Vector3) -> Vector3:
	var id := a.data.id
	if _walkers.has(id):
		return to
	if a.data.away and _grazers.has(id):
		var pasture := pasture_at(from)
		if pasture.is_empty():
			return to
		var room := depth(pasture, to)
		if room >= a.radius() + 0.3 or room > depth(pasture, from):
			return to
		# Up against the fence: it stops and thinks again.
		a._path.clear()
		a._path_inside.clear()
		return from
	return a.housing.constrain(to, a.radius(), a.indoors)


## Animal.scare hook: one at pasture bolts from a wolf at `from` as far as its fence
## lets it. True when it did.
func scare(a: Animal, from: Vector3) -> bool:
	if not is_grazing(a):
		return false
	var pasture := pasture_at(a.global_position)
	if pasture.is_empty():
		return false
	var best := Vector3.INF
	var best_d := -INF
	for i in 6:
		var p := _random_point(pasture, a)
		if p != Vector3.INF and p.distance_to(from) > best_d:
			best_d = p.distance_to(from)
			best = p
	if best != Vector3.INF:
		_walk(a, [best], Animal.State.WANDER)
	return true


## A point in pasture `pasture` animal `a` can walk straight to (INF when none is found).
func _random_point(pasture: Dictionary, a: Animal) -> Vector3:
	var box: Rect2 = pasture["box"]
	var from := a.global_position
	var room := a.radius() + 0.6
	for i in 24:
		var p := Vector3(a._rng.randf_range(box.position.x, box.end.x), 0.0, a._rng.randf_range(box.position.y, box.end.y))
		if depth(pasture, p) < room:
			continue
		var steps := int(Vector2(p.x - from.x, p.z - from.z).length() / 0.7) + 1
		var free := true
		for k in range(1, steps):
			if depth(pasture, from.lerp(p, float(k) / steps)) < 0.2:
				free = false
				break
		if free:
			p.y = TerrainData.height(p.x, p.z)
			return p
	return Vector3.INF


## Sends `a` along `points` (in the open) in state `state`.
func _walk(a: Animal, points: Array, state: int) -> void:
	a._path.clear()
	a._path_inside.clear()
	for p: Vector3 in points:
		a._path.append(Vector3(p.x, TerrainData.height(p.x, p.z), p.z))
		a._path_inside.append(false)
	a._set_state(state, 1e9)


## The pasture that takes in the barn pen's gateway ({} when none does).
func barn_pasture() -> Dictionary:
	_ensure()
	for p in pastures:
		if bool(p["barn"]):
			return p
	return {}


## Daylight with grass to graze and no rain: the barn's animals are out in their pasture.
func _out_time() -> bool:
	var h := GameClock.get_hour_float()
	return h >= OUT_HOUR and h < HOME_HOUR and grass_ok() and not Weather.is_precipitating()


func _home_time() -> bool:
	return not _out_time()


## There is grass to graze: not in winter, not under snow.
func grass_ok() -> bool:
	return GameClock.get_season() != GameClock.Season.WINTER and Weather.snow_cover < 0.3


## One of the barn's animals, out in its pen with nothing else to do, walks out through
## the gateway into the pasture in front of it. True when it set off.
func _try_walk_out(a: Animal) -> bool:
	if pastures.is_empty() or not grazes(a) or a.housing == null or a.housing.kind != "barn" or a.housing.placed:
		return false
	if a.indoors or a.data.injured() or a.data.hydration < 55.0 or a._busy() or not _out_time():
		return false
	if a.state not in [Animal.State.IDLE, Animal.State.GRAZE] or not a.housing.in_pen(a.global_position, -0.2):
		return false
	var pasture := barn_pasture()
	if pasture.is_empty() or a._rng.randf() > 0.6:
		return false
	var h := a.housing
	var to := Vector3.INF
	var out := WorldLayout.gate_point(h.pen, h.gate, GATEWAY_OUT)
	var box: Rect2 = pasture["box"]
	for i in 24:
		var p := Vector3(a._rng.randf_range(box.position.x, box.end.x), 0.0, a._rng.randf_range(box.position.y, box.end.y))
		if depth(pasture, p) >= a.radius() + 0.6:
			to = p
			break
	if to == Vector3.INF:
		return false
	_walkers[a.data.id] = pasture["key"]
	_walk(a, [WorldLayout.gate_point(h.pen, h.gate, -1.2), out, to], Animal.State.WANDER)
	return true


## One on its way out: it walks on; arrived, it is at pasture (or, the fence gone
## meanwhile, turns back home).
func _decide_walker(a: Animal) -> bool:
	if a.state == Animal.State.WANDER and not a._path.is_empty():
		return true
	_walkers.erase(a.data.id)
	if pasture_at(a.global_position).is_empty():
		if not a.housing.in_pen(a.global_position, -0.2):
			a._go_back_home()
		return true
	_begin(a)
	return true


## Home from the pasture at the barn's gateway: out of it by the gateway and into the pen.
func _walk_home(a: Animal) -> void:
	var h := a.housing
	_grazers.erase(a.data.id)
	a.data.away = false
	_walk(a, [WorldLayout.gate_point(h.pen, h.gate, GATEWAY_OUT), WorldLayout.gate_point(h.pen, h.gate, -1.4)], Animal.State.RETURN)


# --- The day's grazing -----------------------------------------------------------------------

## Game time passed: what the grass does for the animals at pasture, hour by hour.
func _on_tick(total: float, delta_minutes: float) -> void:
	if Animals.animals.is_empty():
		return
	if _grazers.is_empty():
		return
	var grazed: Dictionary = FarmState.flags.get(FLAG_GRAZED, {})
	var grass := grass_ok()
	var t := total - delta_minutes
	var left := delta_minutes
	while left > 0.001:
		var step := minf(left, 60.0)
		var hours := step / 60.0
		var hour := fmod(6.0 + t / 60.0, 24.0)
		var day := grass and hour >= 6.0 and hour < 20.0
		for id: int in _grazers:
			var a := Animals.by_id(id)
			if a == null or not a.away or a.at_vet() or not day:
				continue
			a.happiness = minf(a.happiness + PASTURE_HAPPY * hours, 100.0)
			if a.hydration < WATER_CAP:
				a.hydration = minf(a.hydration + (Animals.WATER_DECAY + PASTURE_WATER) * hours, WATER_CAP)
			grazed[id] = float(grazed.get(id, 0.0)) + hours
		t += step
		left -= step
	FarmState.flags[FLAG_GRAZED] = grazed


## A new morning: the animals left at pasture overnight are still there (Animals has just
## brought every animal home: back they go), unless there is nothing to graze; yesterday's
## grazing is forgotten.
func _on_day_started(_day: int) -> void:
	asleep = false
	FarmState.flags.erase(FLAG_GRAZED)
	_ensure()
	for id: int in _grazers.keys():
		var d := Animals.by_id(id)
		var n := Animals.node_of(d) if d else null
		var at: Vector3 = _grazers[id]
		var pasture := pasture_at(at)
		if n == null or d.at_vet() or n.ridden or pasture.is_empty() or bool(pasture["barn"]) or not grass_ok():
			_grazers.erase(id)
			continue
		n.global_position = at
		n.rotation.y = d.away_yaw
		n.reset_physics_interpolation()
		_begin(n)


## At dusk: a word about the animals still out at pasture (once a day), by whether
## lanterns light them.
func _dusk_note() -> void:
	var h := GameClock.get_hour_float()
	if h < DUSK_HOUR or h >= 22.0 or int(FarmState.flags.get(FLAG_DUSK, 0)) == GameClock.day:
		return
	var out := 0
	var unlit := 0
	for a in grazing():
		var pasture := pasture_at(a.global_position)
		if pasture.is_empty() or bool(pasture["barn"]):
			continue
		out += 1
		if not bool(pasture["covered"]):
			unlit += 1
	if out == 0:
		return
	FarmState.flags[FLAG_DUSK] = GameClock.day
	if unlit > 0:
		Game.notify(tr("MSG_PASTURE_DUSK") % out, WolfRaids.AMBER)
	else:
		Game.notify(tr("MSG_PASTURE_DUSK_SAFE") % out, UiTheme.GREEN)
	Audio.ui("notify", -8.0)
