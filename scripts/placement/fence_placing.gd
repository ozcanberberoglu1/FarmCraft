class_name FencePlacing
extends RefCounted
## Putting down the farmer's own fence (PlaceableTable "fence": panels, gates, lantern
## posts), for the Placer:
##   - A panel or a gate in hand STARTS at a post when the farmer looks near one (the free
##     end of the piece he just put down first, so a run goes on; else the nearest post of
##     any piece, a lantern post or a corner of the barn's or Grandpa's run's fence) and
##     points where he looks, in 15° steps. With no post near it lies free on the ground
##     where he looks and R turns it (R by a post lets go of the run, for another post).
##   - Its far end closes onto another post it comes near (CLOSE): the last piece of a
##     loop is cut to the gap (FenceModels.PANEL_MIN to PANEL_MAX long).
##   - The posts stand on the ground at both ends, so a run follows the slope (not up a
##     bank steeper than MAX_RISE in a panel's length).
##   - Green where it fits: on open farm land, not through a building, a field, a pen, the
##     road, the water or anything else that stands there.
##   - LMB puts it down; LMB held lays a run, a piece every RUN_EVERY seconds from the
##     last one's end toward where he looks, as he walks.
##   - A lantern post stands where he looks, or on a fence's post he looks at.

const STEP := PI / 12.0
const GRID := 0.25
## The aim this near a post (m): the piece starts there. This near the end of the piece
## just put down: the run goes on from it.
const SNAP_REACH := 2.7
const RUN_REACH := 5.0
## The far end this near another post: it ends there.
const CLOSE := 0.8
## A lantern post this near a fence's post stands on it.
const POST_SNAP := 0.7
## Seconds between the pieces of a run laid with LMB held, and how far ahead of the
## run's end (m) the farmer must look for the next one.
const RUN_EVERY := 0.32
const RUN_AHEAD := 1.3
## The most a panel's far end may stand over (or under) its near end, a metre of it.
const MAX_RISE := 0.5

## The free end of the piece just put down (the run goes on from it; INF: none).
static var last_end := Vector3.INF
## What the preview shows now: {a, b (its ends on the ground), len, yaw, pos, from (the
## post it starts at, INF when it lies free), closed (its far end met a post)}; a
## lantern post: {pos, yaw, on_post}.
static var spot := {}
static var _run_wait := 0.0
static var _ghost_key := ""
static var _ghost: ArrayMesh


## Works out where the piece in hand would go for the aim `aim`, shows it and checks it.
static func update(placer: Placer, player: Player, aim: Vector3) -> void:
	var id := placer.item_id()
	if id == &"lantern_post":
		spot = _post_spot(aim)
	else:
		spot = _piece_spot(placer, player, aim)
	placer.global_transform = Transform3D(Basis(Vector3.UP, float(spot["yaw"])), spot["pos"])
	placer.reason = check(player, id, spot)
	placer.valid = placer.reason == ""
	placer.show_piece(_ghost_mesh(id), placer.valid)
	_run_wait = maxf(_run_wait - player.get_physics_process_delta_time(), 0.0)


## Where a panel or a gate would go: from a post toward the aim, else free at the aim.
static func _piece_spot(placer: Placer, player: Player, aim: Vector3) -> Dictionary:
	var points := Pastures.snap_points()
	# The run's end is forgotten once it is gone or he has walked off from it.
	if last_end != Vector3.INF and (_flat(last_end, aim) > RUN_REACH + 3.0 or _near(points, last_end, 0.3) == Vector3.INF):
		last_end = Vector3.INF
	var from := Vector3.INF
	if last_end != Vector3.INF and _flat(last_end, aim) < RUN_REACH:
		from = last_end
	else:
		from = _near(points, aim, SNAP_REACH)
	var a: Vector3
	var b: Vector3
	var closed := false
	if from == Vector3.INF:
		var yaw := placer.yaw()
		var mid := Vector3(snappedf(aim.x, GRID), 0.0, snappedf(aim.z, GRID))
		var half := Vector3(cos(yaw), 0.0, -sin(yaw)) * FenceModels.PANEL * 0.5
		a = mid - half
		b = mid + half
	else:
		var to := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
		if to.length() < 0.4:
			# Looking right at the post: the way he faces.
			to = -player.global_basis.z
		var ang := snappedf(atan2(-to.z, to.x), STEP)
		a = from
		b = from + Vector3(cos(ang), 0.0, -sin(ang)) * FenceModels.PANEL
		# Onto another post near its far end: the loop's last piece, cut to the gap.
		var best := CLOSE
		var meet := Vector3.INF
		for q: Vector3 in points:
			var gap := _flat(q, a)
			if gap < FenceModels.PANEL_MIN or gap > FenceModels.PANEL_MAX:
				continue
			var d := _flat(q, b)
			if d < best:
				best = d
				meet = q
		if meet != Vector3.INF:
			b = meet
			closed = true
	a.y = TerrainData.height(a.x, a.z)
	b.y = TerrainData.height(b.x, b.z)
	return {"a": a, "b": b, "len": _flat(a, b), "yaw": atan2(-(b.z - a.z), b.x - a.x), "pos": (a + b) * 0.5,
		"from": from, "closed": closed}


## Where a lantern post would go: on the fence's post he looks at, else where he looks.
static func _post_spot(aim: Vector3) -> Dictionary:
	var on := _near(Pastures.snap_points(false), aim, POST_SNAP)
	var p := on if on != Vector3.INF else Vector3(snappedf(aim.x, GRID), 0.0, snappedf(aim.z, GRID))
	p.y = TerrainData.height(p.x, p.z)
	return {"pos": p, "yaw": 0.0, "on_post": on != Vector3.INF}


## "" where the piece `id` fits at `at` (a spot as update works it out), else why not
## (a translation key).
static func check(player: Player, id: StringName, at: Dictionary) -> String:
	var lantern := id == &"lantern_post"
	var samples: Array[Vector3] = []
	if lantern:
		samples.append(at["pos"])
	else:
		var a: Vector3 = at["a"]
		var b: Vector3 = at["b"]
		var length := float(at["len"])
		if absf(b.y - a.y) > MAX_RISE * length:
			return "MSG_PLACE_FLAT"
		for i in 5:
			samples.append(a.lerp(b, i / 4.0))
		# Not on top of a piece that runs between the same two posts.
		for n in Engine.get_main_loop().get_nodes_in_group(FencePiece.GROUP):
			var ends := (n as FencePiece).ends()
			if (_flat(ends[0], a) < 0.3 and _flat(ends[1], b) < 0.3) or (_flat(ends[0], b) < 0.3 and _flat(ends[1], a) < 0.3):
				return "MSG_PLACE_BLOCKED"
	for s in samples:
		var why := ground_reason(s, lantern)
		if why != "":
			return why
	if player == null or not player.is_inside_tree():
		return ""
	# The farmer himself in the way (he would be walled in a post).
	var me := player.global_position
	for s in samples:
		if _flat(s, me) < 0.5:
			return "MSG_FENCE_STEP_BACK"
	var shape := BoxShape3D.new()
	var q := PhysicsShapeQueryParameters3D.new()
	var mid: Vector3 = at["pos"]
	if lantern:
		shape.size = Vector3(0.24, 1.9, 0.24)
		q.transform = Transform3D(Basis(), mid + Vector3(0, 1.15, 0))
	else:
		# Short of the posts at its ends: its neighbours stand there.
		var a2: Vector3 = at["a"]
		var b2: Vector3 = at["b"]
		shape.size = Vector3(maxf(float(at["len"]) - 0.7, 0.3), 0.8, 0.12)
		var basis := Basis(Vector3.UP, float(at["yaw"])) * Basis(Vector3.BACK, atan2(b2.y - a2.y, float(at["len"])))
		q.transform = Transform3D(basis, mid + Vector3(0, 0.7, 0))
	q.shape = shape
	q.collision_mask = 1 | 4 | 16
	var exclude: Array[RID] = [player.get_rid()]
	for path in ["Terrain/Collision", "Road/Collision"]:
		var body := Game.world.get_node_or_null(path) as CollisionObject3D if Game.world else null
		if body:
			exclude.append(body.get_rid())
	q.exclude = exclude
	for hit: Dictionary in player.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c: Object = hit["collider"]
		# Grass stays where a fence goes up; a lantern post may stand on a fence's post.
		if c is GrassPatch or (lantern and bool(at.get("on_post", false)) and _fence_of(c) != null):
			continue
		return "MSG_PLACE_BLOCKED"
	return ""


## "" when a fence may stand on the ground at `p`, else why not: only on the farm's open
## land, off the road, out of the water, not in a field, a pen, a building or a kit
## building's plot.
static func ground_reason(p: Vector3, lantern := false) -> String:
	if WorldLayout.playable_distance(p.x, p.z) < 1.0 \
			or Vector2(p.x, p.z).distance_to(WorldLayout.TOWN_CENTER) < WorldLayout.TOWN_BOUNDARY_RADIUS + 8.0 \
			or WorldLayout.distance_to_road(p.x, p.z) < 5.0:
		return "MSG_FENCE_FARM_ONLY"
	if WorldLayout.distance_to_pond(p.x, p.z) < WorldLayout.POND_RADIUS + 0.8 or TerrainData.is_underwater(p.x, p.z, 0.15):
		return "MSG_PLACE_WATER"
	var pt := Vector2(p.x, p.z)
	for lot_id: StringName in WorldLayout.FIELD_LOTS:
		var lot: Rect2 = WorldLayout.FIELD_LOTS[lot_id]["rect"]
		if lot.grow(0.3).has_point(pt):
			return "MSG_PLACE_RESERVED"
	# On the pens' own fence line is fine (a run starts at their corners), inside is not;
	# a lantern post may stand in a pen (its animals sleep in its light).
	if not lantern:
		if WorldLayout.BARN_PEN.grow(-0.25).has_point(pt):
			return "MSG_PLACE_RESERVED"
		if FarmState.coop_level() > 0 and WorldLayout.COOP_PEN.grow(-0.25).has_point(pt):
			return "MSG_PLACE_RESERVED"
	if WorldLayout.QUARRY_RECT.has_point(pt) or Placer.indoors(p) or Placer.in_building_plot(p):
		return "MSG_PLACE_RESERVED"
	return ""


## Puts the piece in hand down where the preview shows it. True when placed.
static func place(placer: Placer) -> bool:
	if not placer.valid or spot.is_empty():
		if placer.reason != "":
			Game.notify(TranslationServer.translate(placer.reason), UiTheme.RED)
		return false
	var id := placer.item_id()
	var pos: Vector3 = spot["pos"]
	var e := FarmState.add_placed(id, pos, float(spot["yaw"]))
	if id != &"lantern_post":
		e["len"] = float(spot["len"])
	Game.world.farm.spawn_placed(e)
	PlayerState.inventory.remove_item(id, 1)
	Events.placed.emit(id)
	Audio.play("wood_hit", pos + Vector3(0, 0.6, 0), -7.0, 0.12)
	if id == &"lantern_post":
		Fx.dirt_burst(pos + Vector3(0, 0.05, 0), 0.6)
	else:
		for end: Vector3 in [spot["a"], spot["b"]]:
			Fx.dirt_burst(end + Vector3(0, 0.05, 0), 0.5)
		last_end = spot["b"]
	_run_wait = RUN_EVERY
	Pastures.mark_dirty()
	return true


## LMB held with a panel or a gate in hand: whether the next piece of the run goes down
## now (the preview fits, starts at the run's end and he looks far enough ahead).
static func run_ready(placer: Placer) -> bool:
	if not placer.active or not placer.valid or spot.is_empty() or _run_wait > 0.0 or placer.item_id() == &"lantern_post":
		return false
	var from: Vector3 = spot.get("from", Vector3.INF)
	if from == Vector3.INF or last_end == Vector3.INF or _flat(from, last_end) > 0.05:
		return false
	return bool(spot.get("closed", false)) or _flat(placer.aim, last_end) > RUN_AHEAD


## R by a post: lets go of the run (the nearest post to the aim is taken next). True when
## there was a run to let go of.
static func let_go_run() -> bool:
	if last_end == Vector3.INF:
		return false
	last_end = Vector3.INF
	return true


## Piece `piece` is gone: a run ending at it ends.
static func forget(piece: FencePiece) -> void:
	if last_end == Vector3.INF:
		return
	for end in piece.ends():
		if _flat(end, last_end) < 0.3:
			last_end = Vector3.INF


## The preview's mesh for what is in hand at the spot shown.
static func _ghost_mesh(id: StringName) -> ArrayMesh:
	if id == &"lantern_post":
		return PlaceableModels.mesh(id, "whole")
	var a: Vector3 = spot["a"]
	var b: Vector3 = spot["b"]
	var length := snappedf(float(spot["len"]), 0.02)
	var rise := snappedf(b.y - a.y, 0.03)
	var key := "%s/%.2f/%.2f" % [id, length, rise]
	if key != _ghost_key:
		_ghost_key = key
		if id == &"fence_gate":
			var parts := []
			MeshMerge.add_mesh(parts, FenceModels.gate_posts(length, rise, 9))
			MeshMerge.add_mesh(parts, FenceModels.gate_leaf(length),
					Transform3D(Basis(Vector3.BACK, atan2(rise, length)), Vector3(-length * 0.5, -rise * 0.5, 0.0)))
			_ghost = MeshMerge.build(parts)
		else:
			_ghost = FenceModels.panel(length, rise, true, true, 5)
	return _ghost


## The point of `points` nearest `p` within `reach` metres (INF when none).
static func _near(points: Array[Vector3], p: Vector3, reach: float) -> Vector3:
	var best := reach
	var out := Vector3.INF
	for q in points:
		var d := _flat(q, p)
		if d < best:
			best = d
			out = q
	return out


## The fence piece `collider` belongs to (itself, or a gate's leaf), or null.
static func _fence_of(collider: Object) -> FencePiece:
	var n := collider as Node
	for i in 3:
		if n == null:
			return null
		if n is FencePiece:
			return n
		n = n.get_parent()
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
