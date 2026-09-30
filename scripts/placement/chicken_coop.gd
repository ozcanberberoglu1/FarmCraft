class_name ChickenCoop
extends PlacedObject
## A chicken coop put up from a kit (PlaceableTable "coop_kit") anywhere on open farm
## land, turned any way. It goes up as a construction site first (ConstructionSite:
## stakes, a frame, scaffolding and a sign counting down) for "build_seconds" real
## seconds of play (the time left is saved in its entry; a night's sleep finishes it),
## then the finished coop stands there in a cloud of dust: a closed house for 8 hens
## with nest boxes, a roost, troughs and a door that opens and shuts (CoopDoor), and a
## free-range yard around it (the whole footprint, which was clear when it was placed).
## Crated hens bought in town are let out at its door; the first one to move in lays an
## egg somewhere around it within the hour (the "first_egg" group: the story's waypoint).
## Inside: a feeder and a waterer the farmer fills (Trough), and three nest boxes along
## the west wall (Nest), empty until bedded with straw (hay in hand). Hens lay in bedded
## boxes: in the morning each walks in, hops into a free one, sits a while, leaves her
## egg on the straw and goes back out. With no box bedded they lay in the yard (on the
## coop floor behind a shut door).
## A content hen now and then lays a second egg later in the day (Animals.eggs_today).
## With a grown rooster living in the coop the eggs laid are fertile: one left where it
## lay (in a nest box or on the floor) for a whole day hatches there (HatchingEgg) into a
## chick of the hen that laid it, if the coop has room for one more (else it stays an
## egg, and the farmer is told). Picking an egg up stops it.
## Entry fields besides {id, pos, yaw}: stage ("site" / "done"), build_left (real
## seconds), door (open), uid (its home id), egg ("", "due", "nest", "laid", "taken"),
## egg_at (game minutes), egg_pos, nests ([bool] bedded), lay (eggs due: hen id ->
## {at, q, first, more}), fertile (eggs that may hatch: [{id, pos, at, hen, q}]),
## fertile_next (their next id).

## Its id in Events.construction_started and Events.building_completed.
const BUILD_ID := &"coop"
## Layout in the coop's own frame (door toward +Z). The yard is the whole footprint
## (PlaceableTable size 11 x 10); the house stands at its back.
const YARD := Rect2(-5.5, -5.0, 11.0, 10.0)
const HOUSE := Rect2(-2.5, -4.4, 5.0, 3.4)
## Game minutes after the first hen moves in until she lays her first egg.
const FIRST_EGG_MINUTES := 25.0
## Game minutes until a hen lays again after the story's egg was broken (hurry_egg).
const QUICK_EGG_MINUTES := 6.0
## The first egg's Pickup is in this group (for the waypoint).
const FIRST_EGG_GROUP := &"first_egg"
## Waypoint anchor ids (WaypointMarker.tag): over the coop (or its site), over the
## door (outside the ramp) and the first egg itself.
const ANCHOR_COOP := &"coop"
const ANCHOR_DOOR := &"coop_door"
const ANCHOR_EGG := &"first_egg"
## Over the feeder, the waterer and the next nest box still to bed (none once all are).
const ANCHOR_FEEDER := &"coop_feeder"
const ANCHOR_WATER := &"coop_water"
const ANCHOR_NEST := &"coop_nest"
## Nest boxes on a bench along the inside of the west wall (the coop's frame, heights over
## the coop floor): the bench's back and depth, the first box's middle and the pitch,
## the straw's top (where a hen sits and her egg lies) and the lid over the boxes.
const NESTS := 3
const NEST_BACK := -2.38
const NEST_DEPTH := 0.52
const NEST_Z0 := -3.93
const NEST_PITCH := 0.6
const NEST_SEAT := 0.43
const NEST_LID := 0.92
## Game minutes a hen's egg waits for her to lay it in a nest (the door shut on her, the
## night, the farmer asleep) before it turns up there anyway.
const LAY_GRACE := 120.0
## A night's sleep (or any skip this long, in game minutes) finishes the construction.
const SKIP_FINISHES := 60.0
## The chopping log in the yard (by the house's front right corner).
const LOG_AT := Vector3(3.6, 0.0, -0.1)
## FarmState.depleted day of ground cleared for good (grass and rocks never come back).
const CLEARED := 1 << 30
## Game minutes a fertile egg must lie before it hatches (a whole day).
const HATCH_MINUTES := 24.0 * 60.0
## Game minutes after her first egg until a hen lays her second of the day.
const SECOND_EGG_AFTER := Vector2(150.0, 330.0)

var housing: AnimalHousing
var site: ConstructionSite
var _first_egg: Pickup
## The nest boxes (built with the coop), the coop floor's height in this node's space,
## the guide dot over the next box to bed and which hen is on (or bound for) which box.
var _nests: Array[Nest] = []
var _floor_local := 0.0
var _nest_marker: Marker3D
var _claims := {}
## Fertile eggs lying about: record id -> their Pickup; the day the farmer was last told
## an egg could not hatch in a full coop.
var _fertile_eggs := {}
var _full_told := -1

static var _props_mesh: ArrayMesh
static var _ghost_mesh: ArrayMesh
static var _bench_mesh: ArrayMesh
static var _straw_mesh: ArrayMesh


func _setup() -> void:
	# Kit coops are placed with their stage; anything else (old debug entries) stands.
	if not entry.has("stage"):
		entry["stage"] = "done"
	if not entry.has("uid"):
		var p: Vector3 = entry["pos"]
		entry["uid"] = "coop@%.1f,%.1f" % [p.x, p.z]
	# A kit goes up with bare nest boxes; coops from before the boxes were bedded by hand
	# keep their straw.
	if not entry.has("nests"):
		var bedded := is_built()
		entry["nests"] = [bedded, bedded, bedded]
	_clear_ground()
	_add_markers()
	if is_built():
		_build_coop()
	else:
		_start_site()
	set_process(not is_built())
	Events.time_skipped.connect(_on_time_skipped)
	Events.clock_tick.connect(_on_tick)
	Events.animal_released.connect(_on_animal_released)
	if String(entry.get("egg", "")) == "laid":
		_spawn_first_egg.call_deferred()
	if not (entry.get("fertile", []) as Array).is_empty():
		_restore_fertile.call_deferred()


func _exit_tree() -> void:
	var farm := _farm()
	if housing and farm:
		farm.unregister_coop(housing)


## Finished (not a construction site any more).
func is_built() -> bool:
	return String(entry.get("stage", "done")) == "done"


## Real seconds the whole construction takes.
func build_seconds() -> float:
	return PlaceableTable.build_seconds(item_id)


## Real seconds of play until it is finished (0 once it is).
func seconds_left() -> float:
	return 0.0 if is_built() else maxf(float(entry.get("build_left", build_seconds())), 0.0)


## 0..1 of the construction done.
func progress() -> float:
	return 1.0 - seconds_left() / maxf(build_seconds(), 0.001)


## The home id its hens carry (AnimalHousing.home_id).
func uid() -> String:
	return String(entry.get("uid", ""))


## Where the door is, on the ground just outside the ramp (the waypoint for letting
## the hens in); the middle of the site while it is going up.
func door_point() -> Vector3:
	if housing:
		return housing.door_outside()
	var c := HOUSE.get_center()
	var w := global_transform * Vector3(c.x, 0.0, HOUSE.end.y + 1.5)
	return Vector3(w.x, TerrainData.height(w.x, w.z), w.z)


## The middle of the house on the ground (a waypoint for the coop itself).
func center_point() -> Vector3:
	var c := HOUSE.get_center()
	var w := global_transform * Vector3(c.x, 0.0, c.y)
	return Vector3(w.x, TerrainData.height(w.x, w.z), w.z)


## The coop a housing belongs to (null for Grandpa's barn and run).
static func of(h: AnimalHousing) -> ChickenCoop:
	return h.get_parent() as ChickenCoop if h != null and h.placed else null


## The first egg lying about (null when it isn't laid yet or was picked up).
func first_egg() -> Pickup:
	return _first_egg if is_instance_valid(_first_egg) and not _first_egg.is_queued_for_deletion() else null


## The kit's placement preview (Placer): the finished coop at the back of its plot, the
## door shut, and pegs and a line round the yard its hens will have. Built once.
static func ghost_mesh() -> ArrayMesh:
	if _ghost_mesh:
		return _ghost_mesh
	var surfaces := []
	var data := AnimalBuildings.coop(HOUSE.size, false)
	var c := HOUSE.get_center()
	MeshMerge.add_mesh(surfaces, data["mesh"], Transform3D(Basis(), Vector3(c.x, 0.0, c.y)))
	# Its small trim (battens, glazing bars, rafter tails) comes in a mesh of its own.
	MeshMerge.add_mesh(surfaces, data["straw_mesh"], Transform3D(Basis(), Vector3(c.x, 0.0, c.y)))
	var door_w := float(data["door_width"])
	var door_at := Vector3(c.x - door_w * 0.5, float(data["floor_y"]), c.y + HOUSE.size.y * 0.5 + 0.03)
	MeshMerge.add_mesh(surfaces, CoopDoor.leaf_mesh(door_w, float(data["door_height"])), Transform3D(Basis(), door_at))
	var mb := MeshBuilder.new()
	var pts: Array[Vector2] = [YARD.position, Vector2(YARD.end.x, YARD.position.y), YARD.end, Vector2(YARD.position.x, YARD.end.y)]
	var peg := Color(0.42, 0.37, 0.33)
	for i in 4:
		var a := pts[i]
		var b := pts[(i + 1) % 4]
		for k in 4:
			var p := a.lerp(b, k / 4.0)
			# Driven well in: the plot may fall away a little from its middle.
			mb.box_at(&"wood", Vector3(p.x, -0.05, p.y), Vector3(0.06, 1.1, 0.06), peg)
		mb.box(&"wood", Transform3D(Basis(Vector3.UP, atan2(-(b - a).y, (b - a).x)), Vector3((a.x + b.x) * 0.5, 0.42, (a.y + b.y) * 0.5)),
				Vector3(a.distance_to(b), 0.025, 0.025), peg)
	MeshMerge.add_mesh(surfaces, mb.build())
	_ghost_mesh = MeshMerge.build(surfaces)
	return _ghost_mesh


# --- Construction ---------------------------------------------------------------------

func _start_site() -> void:
	if not entry.has("build_left"):
		entry["build_left"] = build_seconds()
	site = ConstructionSite.new()
	site.name = "Site"
	site.house = HOUSE
	site.yard = YARD
	add_child(site)
	site.set_progress(progress(), seconds_left())


func _process(delta: float) -> void:
	if is_built():
		set_process(false)
		return
	# Real time of play: not while a menu or the map is open.
	if Game.is_ui_open():
		return
	var left := maxf(seconds_left() - delta, 0.0)
	entry["build_left"] = left
	if left <= 0.0:
		finish()
	elif site:
		site.set_progress(progress(), left)


## Finishes the construction now: the site makes way for the coop in a cloud of dust
## (sleeping through it, tests and debug call it too).
func finish() -> void:
	if is_built():
		return
	entry["stage"] = "done"
	entry["build_left"] = 0.0
	set_process(false)
	if site:
		site.queue_free()
		site = null
	_build_coop()
	var c := center_point()
	Fx.dust_cloud(c + Vector3(0, 1.0, 0), HOUSE.size * 0.65)
	Fx.dust_cloud(c + Vector3(0, 0.3, 0), YARD.size * 0.3)
	Audio.play("plank", c + Vector3(0, 1.0, 0), 0.0)
	Audio.play("wood_hit", c + Vector3(0, 1.5, 0), -3.0)
	Game.notify(tr("MSG_BUILT") % tr("HOUSING_COOP"), Color(0.55, 1.0, 0.45))
	# A new roof: the rain height map is rendered again.
	Weather.refresh_rain_blockers.call_deferred()
	Events.building_completed.emit(BUILD_ID, self)


func _on_time_skipped(minutes: float) -> void:
	if not is_built() and minutes >= SKIP_FINISHES:
		finish()


func _build_coop() -> void:
	var pos: Vector3 = entry["pos"]
	housing = AnimalHousing.new()
	housing.setup_placed(Transform3D(Basis(Vector3.UP, float(entry.get("yaw", 0.0))), pos), YARD, HOUSE,
			bool(entry.get("door", true)), uid())
	add_child(housing)
	housing.set_level(2)
	housing.changed.connect(func() -> void: entry["door"] = housing.door_open)
	# Game.world.farm is not set yet while the farm spawns its placed things.
	var farm := _farm()
	if farm:
		farm.register_coop(housing)
	_add_props()
	_add_care()
	_add_nests()


## A few things lying about the yard: a chopping log the hens hop onto (by the house's
## front right corner, LOG_AT), an old tin bucket and straw spilled by the ramp.
func _add_props() -> void:
	if _props_mesh == null:
		var mb := MeshBuilder.new()
		var bark := Color(0.4, 0.33, 0.27)
		var log_at := LOG_AT
		mb.cylinder(&"bark", Transform3D(Basis(), log_at + Vector3(0, -0.1, 0)), 0.3, 0.28, 0.52, 12, bark)
		mb.disc(&"endgrain", Transform3D(Basis(), log_at + Vector3(0, 0.425, 0)), 0.28, 12, Color(0.62, 0.52, 0.4))
		var bucket := Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, 0.3), Vector3(HOUSE.position.x - 0.9, 0.16, HOUSE.end.y + 0.4))
		mb.cylinder(&"rusty", bucket, 0.13, 0.16, 0.3, 12, Color(0.46, 0.45, 0.42), true, false)
		mb.disc(&"rusty", bucket * Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), 0.13, 12, Color(0.4, 0.38, 0.35))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 70:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 0.9
			var p := Vector3(HOUSE.get_center().x + cos(a) * r * 1.2, 0.03, HOUSE.end.y + 1.3 + sin(a) * r * 0.6)
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 0.1), rng.randf_range(-1, 1)).normalized()
			mb.cylinder_between(&"veg", p, p + dir * rng.randf_range(0.12, 0.26), 0.004, 0.003, 3,
					Color(0.8, 0.66, 0.36).lightened(rng.randf_range(-0.2, 0.1)), false, false)
		_props_mesh = mb.build()
	var mi := MeshInstance3D.new()
	mi.name = "YardProps"
	mi.mesh = _props_mesh
	# On the ground under the props (the coop node stands at the footprint's middle).
	var c := HOUSE.get_center()
	var w := global_transform * Vector3(c.x, 0.0, HOUSE.end.y + 1.0)
	mi.position.y = TerrainData.height(w.x, w.z) - global_position.y
	add_child(mi)
	# The log is solid (the coop's own body: it has no other shape once built).
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 0.5
	cs.shape = cyl
	cs.position = LOG_AT + Vector3(0, mi.position.y + 0.16, 0)
	add_child(cs)


## Tall grass in the footprint goes for good, and rocks broken there never come back
## (the yard is kept clear). Done again on every load: the patches are rebuilt.
func _clear_ground() -> void:
	var pos: Vector3 = entry["pos"]
	var inv := Transform3D(Basis(Vector3.UP, float(entry.get("yaw", 0.0))), pos).affine_inverse()
	var area := YARD.grow(0.6)
	for n in get_tree().get_nodes_in_group(&"grass_patches"):
		var g := n as GrassPatch
		if g == null:
			continue
		var l := inv * g.global_position
		if not area.has_point(Vector2(l.x, l.z)):
			continue
		FarmState.depleted[g.resource_id] = CLEARED
		g.visible = false
		g.collision_layer = 0
		g.remove_from_group(&"interactable")
	for n in get_tree().get_nodes_in_group(&"rocks"):
		var r := n as Node3D
		if r == null:
			continue
		var l := inv * r.global_position
		var rid: Variant = r.get("resource_id")
		if area.has_point(Vector2(l.x, l.z)) and rid != null and FarmState.depleted.has(rid):
			FarmState.depleted[rid] = CLEARED


## Where the story's guide dot floats: over the roof (the site's sign while it goes up)
## and over the door, just outside the ramp.
func _add_markers() -> void:
	var c := HOUSE.get_center()
	for m: Array in [[ANCHOR_COOP, Vector3(c.x, 0.0, c.y), 3.4], [ANCHOR_DOOR, Vector3(c.x, 0.0, HOUSE.end.y + 1.5), 1.4]]:
		var marker := Marker3D.new()
		marker.name = "Waypoint_%s" % m[0]
		var at: Vector3 = m[1]
		var w := global_transform * at
		at.y = TerrainData.height(w.x, w.z) - global_position.y + float(m[2])
		marker.position = at
		add_child(marker)
		WaypointMarker.tag(marker, m[0])
		marker.add_to_group(&"waypoints")


func _farm() -> Farm:
	var n := get_parent()
	while n and not (n is Farm):
		n = n.get_parent()
	return n as Farm


# --- Prompts ------------------------------------------------------------------------------

## A site goes back into the bag as the kit (put up in the wrong place); a finished
## coop stays.
func can_pick_up() -> bool:
	return not is_built()


## The countdown over the site, as a plain prompt line.
func hint_prompt() -> String:
	if is_built():
		return ""
	return "%s · %s" % [tr("SIGN_CONSTRUCTION"), tr("CROP_TIME_LEFT") % ConstructionSite.clock_text(seconds_left())]


## F on a site: the kit back into the bag.
func info_interact(player: Node) -> void:
	if not can_pick_up():
		return
	super.info_interact(player)


# --- The first egg -------------------------------------------------------------------------

func _on_animal_released(species: StringName, home: Node) -> void:
	if home != self:
		return
	# The first rooster in: the farmer hears what that means for the eggs.
	if species == &"rooster" and housing and Animals.roosters_in(housing) == 1:
		Game.notify(tr("MSG_ROOSTER_IN"), Color(0.55, 1.0, 0.45))
	if species != &"chicken" or String(entry.get("egg", "")) != "":
		return
	entry["egg"] = "due"
	entry["egg_at"] = GameClock.total_minutes + FIRST_EGG_MINUTES


func _on_tick(_total: float, _delta: float) -> void:
	if housing == null:
		return
	if String(entry.get("egg", "")) == "due" and GameClock.total_minutes >= float(entry.get("egg_at", 0.0)):
		_first_egg_due()
	_overdue_lays()
	_hatch_due()


## With a nest box bedded, one of the hens goes and lays it there (the egg stays "nest"
## until she has); else it is laid at once about the yard.
func _first_egg_due() -> void:
	var hen := _first_hen()
	if hen and filled_nests() > 0:
		var lays := _lays()
		var key := str(hen.data.id)
		var d: Dictionary = lays.get(key, {"q": ItemStack.Quality.NORMAL})
		d["at"] = minf(float(d.get("at", GameClock.total_minutes)), GameClock.total_minutes)
		d["first"] = true
		lays[key] = d
		entry["egg"] = "nest"
		return
	_lay_first_egg()


## A hen of this coop that can get to the nest boxes now (inside, or the door open), else
## any of them.
func _first_hen() -> Animal:
	var any: Animal = null
	for n in housing.animals:
		if n.data.away or n.ridden or n.data.species != &"chicken" or not n.data.adult:
			continue
		if n.indoors or housing.can_pass():
			return n
		if any == null:
			any = n
	return any


## The story's egg was broken with none left: a hen lays another in a few game minutes
## (the one-off hurry; eggs otherwise come each morning). It is the story's egg again.
func hurry_egg() -> void:
	if housing == null or housing.animals.is_empty():
		return
	if String(entry.get("egg", "")) in ["due", "nest"]:
		entry["egg_at"] = minf(float(entry.get("egg_at", INF)), GameClock.total_minutes + QUICK_EGG_MINUTES)
		return
	entry["egg"] = "due"
	entry["egg_at"] = GameClock.total_minutes + QUICK_EGG_MINUTES


## Where a hen is scratching about in the yard (else in front of the coop, or on the coop
## floor when they are all shut in), with a cackle and a note.
func _lay_first_egg() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(uid())
	var spot := Vector3.INF
	for n in housing.animals_outside():
		spot = housing.clamp_to_pen(n.global_position, 0.6)
		spot.y = housing.ground_height(spot) + 0.1
		break
	if spot == Vector3.INF:
		spot = _loose_spot(rng)
	entry["egg"] = "laid"
	entry["egg_pos"] = spot
	_spawn_first_egg()
	Audio.animal_voice(&"chicken", true, spot, -2.0)
	Game.notify(tr("MSG_FIRST_EGG"), Color(0.55, 1.0, 0.45))


## The first egg came out in a nest box: it is the story's egg.
func _first_laid(p: Pickup) -> void:
	entry["egg"] = "laid"
	entry["egg_pos"] = p.global_position
	_adopt_egg(p)
	Game.notify(tr("MSG_FIRST_EGG"), Color(0.55, 1.0, 0.45))


func _spawn_first_egg() -> void:
	if String(entry.get("egg", "")) != "laid" or Game.world == null or first_egg() != null:
		return
	var at: Vector3 = entry.get("egg_pos", global_position)
	# An egg already lying there (a restored pickup) is the one.
	for n in get_tree().get_nodes_in_group(&"pickups"):
		var p := n as Pickup
		if p and p.stack and p.stack.item.id == &"egg" and p.global_position.distance_to(at) < 0.8:
			_adopt_egg(p)
			return
	_adopt_egg(Pickup.spawn(ItemStack.create(&"egg", 1), at + Vector3(0, 0.05, 0)))


func _adopt_egg(p: Pickup) -> void:
	_first_egg = p
	p.add_to_group(FIRST_EGG_GROUP)
	WaypointMarker.tag(p, ANCHOR_EGG)
	p.add_to_group(&"waypoints")
	p.tree_exiting.connect(func() -> void:
		# Collected (the pickup frees itself), not just cleared away with the world.
		if p.is_queued_for_deletion() and String(entry.get("egg", "")) == "laid":
			entry["egg"] = "taken")


# --- Feeder, waterer and nest boxes -------------------------------------------------------

## The feeder and the waterer (the housing's troughs): guide dots over them, and the
## story hears when the farmer fills them.
func _add_care() -> void:
	for t: Array in [[housing.feed, ANCHOR_FEEDER], [housing.water, ANCHOR_WATER]]:
		var trough: Trough = t[0]
		if trough == null:
			continue
		var m := Marker3D.new()
		m.name = "Waypoint_%s" % t[1]
		m.position = Vector3(0, 0.85, 0)
		trough.add_child(m)
		WaypointMarker.tag(m, t[1])
		m.add_to_group(&"waypoints")
	if housing.feed:
		housing.feed.filled.connect(func() -> void: Events.coop_fed.emit(self))
	if housing.water:
		housing.water.filled.connect(func() -> void: Events.coop_watered.emit(self))


## The bench of nest boxes along the west wall, each bedded or bare as saved, and the
## guide dot over the next one to bed.
func _add_nests() -> void:
	_floor_local = housing.ground_height(center_point()) - global_position.y
	if _bench_mesh == null:
		_bench_mesh = _build_bench()
		_straw_mesh = _build_straw()
	var root := Node3D.new()
	root.name = "Nests"
	root.position.y = _floor_local
	add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = _bench_mesh
	root.add_child(mi)
	# Solid under the straw (eggs lie on it) and over the boxes (the lid).
	var bench := StaticBody3D.new()
	bench.name = "Bench"
	bench.collision_layer = 1
	bench.collision_mask = 0
	var length := NEST_PITCH * NESTS
	var mid := Vector3(NEST_BACK + NEST_DEPTH * 0.5, 0.0, NEST_Z0 + NEST_PITCH * (NESTS - 1) * 0.5)
	for part: Array in [[NEST_SEAT * 0.5, NEST_SEAT], [NEST_LID + 0.13, 0.26]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(NEST_DEPTH, float(part[1]), length)
		cs.shape = box
		cs.position = mid + Vector3(0, float(part[0]), 0)
		bench.add_child(cs)
	root.add_child(bench)
	var flags: Array = entry.get("nests", [])
	for i in NESTS:
		var n := Nest.new()
		n.name = "Nest%d" % i
		n.coop = self
		n.index = i
		n.straw_mesh = _straw_mesh
		n.position = _nest_local(i)
		root.add_child(n)
		n.set_filled(i < flags.size() and bool(flags[i]))
		_nests.append(n)
	_nest_marker = Marker3D.new()
	_nest_marker.name = "Waypoint_%s" % ANCHOR_NEST
	root.add_child(_nest_marker)
	_nest_marker.add_to_group(&"waypoints")
	_refresh_nest_anchor()


## Nest box `i`'s middle on the coop floor (in the "Nests" node's space).
func _nest_local(i: int) -> Vector3:
	return Vector3(NEST_BACK + NEST_DEPTH * 0.5, 0.0, NEST_Z0 + i * NEST_PITCH)


## The guide dot floats over the first box still bare; with all bedded it is gone.
func _refresh_nest_anchor() -> void:
	if _nest_marker == null:
		return
	for i in NESTS:
		if not nest_filled(i):
			_nest_marker.position = _nest_local(i) + Vector3(0, NEST_LID + 0.45, 0)
			WaypointMarker.tag(_nest_marker, ANCHOR_NEST)
			return
	_nest_marker.remove_from_group(WaypointMarker.ANCHOR_GROUP)


## Whether nest box `i` is bedded with straw.
func nest_filled(i: int) -> bool:
	var flags: Array = entry.get("nests", [])
	return i >= 0 and i < flags.size() and bool(flags[i])


## How many nest boxes are bedded.
func filled_nests() -> int:
	var n := 0
	for i in NESTS:
		if nest_filled(i):
			n += 1
	return n


## Beds nest box `i` with straw (the farmer's armful of hay): Events.nest_filled.
func bed_nest(i: int) -> bool:
	if i < 0 or i >= NESTS or nest_filled(i):
		return false
	var flags: Array = (entry.get("nests", []) as Array).duplicate()
	flags.resize(NESTS)
	for k in NESTS:
		flags[k] = flags[k] is bool and flags[k]
	flags[i] = true
	entry["nests"] = flags
	if i < _nests.size():
		_nests[i].set_filled(true)
	_refresh_nest_anchor()
	var n := filled_nests()
	Events.nest_filled.emit(self, n)
	if n == NESTS:
		Game.notify(tr("MSG_NESTS_BEDDED"), Color(0.55, 1.0, 0.45))
	return true


## World point where a hen sits in nest box `i` (on the straw).
func nest_seat(i: int) -> Vector3:
	return global_transform * (_nest_local(i) + Vector3(0, _floor_local + NEST_SEAT, 0))


## World point on the coop floor in front of nest box `i`, where a hen hops up from.
func nest_front(i: int) -> Vector3:
	return global_transform * (_nest_local(i) + Vector3(NEST_DEPTH * 0.5 + 0.4, _floor_local, 0))


## Out of the boxes, into the coop (world).
func nest_out() -> Vector3:
	return global_basis.x


func _nest_egg_spot(i: int) -> Vector3:
	return nest_seat(i) + global_basis * Vector3(randf_range(-0.08, 0.04), 0.07, randf_range(-0.1, 0.1))


# --- Laying --------------------------------------------------------------------------------

## Eggs due today: hen id (String) -> {"at": game minutes, "q": quality, "first": the
## story's first egg}.
func _lays() -> Dictionary:
	if not entry.has("lay"):
		entry["lay"] = {}
	return entry["lay"]


## A hen's egg for the day (Animals, at dawn): with a box bedded she lays it there later in
## the morning; else it lies about the yard at once (the coop floor behind a shut door).
## `count` eggs: the second comes later in the day (SECOND_EGG_AFTER).
func egg_due(a: AnimalData, quality: int, count := 1) -> void:
	if housing == null or count <= 0:
		return
	if filled_nests() == 0:
		for i in count:
			_spawn_egg(_loose_spot(null), quality, a.id)
		return
	var key := str(a.id)
	# Yesterday's never came: they turn up now.
	for i in 3:
		if not _lays().has(key):
			break
		_lay_now(key)
	_lays()[key] = {"at": GameClock.total_minutes + randf_range(20.0, 240.0), "q": quality, "more": count - 1}


## Whether hen `id` has an egg to lay now and a bedded box to lay it in.
func wants_to_lay(id: int) -> bool:
	var d: Dictionary = (entry.get("lay", {}) as Dictionary).get(str(id), {})
	return not d.is_empty() and GameClock.total_minutes >= float(d.get("at", 0.0)) and filled_nests() > 0


## A free bedded box for `hen` (kept for her until she leaves it), or -1.
func claim_nest(hen: Animal) -> int:
	release_nest(hen)
	var free: Array[int] = []
	for i in NESTS:
		if nest_filled(i) and not _is_claimed(i):
			free.append(i)
	if free.is_empty():
		return -1
	var i := free[randi() % free.size()]
	_claims[i] = hen
	return i


func release_nest(hen: Animal) -> void:
	for i: int in _claims.keys():
		if _claims[i] == hen:
			_claims.erase(i)


func _is_claimed(i: int) -> bool:
	var hen: Variant = _claims.get(i)
	return hen != null and is_instance_valid(hen)


## The hen on nest box `i` lays her egg there (false when she had none due any more).
func lay_in_nest(hen: Animal, i: int) -> bool:
	var lays := _lays()
	var key := str(hen.data.id)
	if not lays.has(key) or not nest_filled(i):
		return false
	var d: Dictionary = lays[key]
	lays.erase(key)
	var first := bool(d.get("first", false))
	var egg := _spawn_egg(_nest_egg_spot(i), int(d.get("q", ItemStack.Quality.NORMAL)), -1 if first else hen.data.id)
	Audio.animal_voice(&"chicken", true, egg.global_position, -4.0)
	if first:
		_first_laid(egg)
	_next_egg(key, d)
	return true


## After an egg, a hen with another due today lays it later on.
func _next_egg(key: String, d: Dictionary) -> void:
	var more := int(d.get("more", 0))
	if more <= 0 or _lays().has(key):
		return
	_lays()[key] = {"at": GameClock.total_minutes + randf_range(SECOND_EGG_AFTER.x, SECOND_EGG_AFTER.y),
		"q": int(d.get("q", ItemStack.Quality.NORMAL)), "more": more - 1}


## Eggs a hen hasn't laid in time (shut out, the night, the farmer asleep) turn up
## anyway; one on her way to a box or sitting in one gets longer. A hen gone from the
## coop leaves none behind.
func _overdue_lays() -> void:
	var lays: Dictionary = entry.get("lay", {})
	if lays.is_empty():
		return
	var now := GameClock.total_minutes
	for key: String in lays.keys():
		var d: Dictionary = lays[key]
		var late := now - float(d.get("at", now))
		if late < LAY_GRACE:
			continue
		var hen := _hen(int(key))
		if hen and _claims.values().has(hen) and late < LAY_GRACE * 3.0:
			continue
		_lay_now(key)


## Lays hen `key`'s egg now: in a bedded box when she could get there, else loose.
func _lay_now(key: String) -> void:
	var lays := _lays()
	var d: Dictionary = lays.get(key, {})
	lays.erase(key)
	var first := bool(d.get("first", false))
	if d.is_empty() or (not first and not _lives_here(int(key))):
		return
	var hen := _hen(int(key))
	if hen:
		release_nest(hen)
	var q := int(d.get("q", ItemStack.Quality.NORMAL))
	var boxes: Array[int] = []
	for i in NESTS:
		if nest_filled(i):
			boxes.append(i)
	var reach := hen == null or hen.indoors or housing.can_pass()
	var at := _nest_egg_spot(boxes[randi() % boxes.size()]) if reach and not boxes.is_empty() else _loose_spot(null)
	var egg := _spawn_egg(at, q, -1 if first else int(key))
	if first:
		_first_laid(egg)
	_next_egg(key, d)


func _hen(id: int) -> Animal:
	for n in housing.animals:
		if n.data.id == id:
			return n
	return null


func _lives_here(id: int) -> bool:
	for a in Animals.animals:
		if a.id == id:
			return Animals.housing_of(a) == housing
	return false


## An egg lying where no nest is: about the yard, or on the coop floor with the door shut.
func _loose_spot(rng: RandomNumberGenerator) -> Vector3:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if housing.door_open:
		return housing.random_outdoor_point(rng) + Vector3(0, 0.1, 0)
	return housing.random_indoor_point(rng) + Vector3(0, 0.1, 0)


## An egg laid by hen `hen` (-1: the story's first egg, never fertile): fertile while a
## grown rooster lives here.
func _spawn_egg(at: Vector3, quality: int, hen := 0) -> Pickup:
	var egg := Pickup.spawn(ItemStack.create(&"egg", 1, quality), at)
	if hen >= 0 and has_rooster():
		var id := int(entry.get("fertile_next", 1))
		entry["fertile_next"] = id + 1
		var rec := {"id": id, "pos": at, "at": GameClock.total_minutes, "hen": hen, "q": quality}
		_fertile().append(rec)
		_watch_egg(egg, id)
	return egg


# --- Fertile eggs and hatching -------------------------------------------------------------

## Whether a grown rooster lives in this coop (the hens' eggs are fertile).
func has_rooster() -> bool:
	return housing != null and Animals.roosters_in(housing) > 0


## The fertile eggs' records (saved in the entry).
func _fertile() -> Array:
	if not entry.has("fertile"):
		entry["fertile"] = []
	return entry["fertile"]


## Fertile eggs lying here now (their pickups).
func fertile_eggs() -> Array[Pickup]:
	var out: Array[Pickup] = []
	for id: int in _fertile_eggs:
		var p: Variant = _fertile_eggs[id]
		if is_instance_valid(p) and not (p as Pickup).is_queued_for_deletion():
			out.append(p)
	return out


func _record(id: int) -> Dictionary:
	for rec: Dictionary in _fertile():
		if int(rec["id"]) == id:
			return rec
	return {}


## Keeps an eye on a fertile egg: picked up (the pickup frees itself), it won't hatch.
func _watch_egg(egg: Pickup, id: int) -> void:
	_fertile_eggs[id] = egg
	egg.tree_exiting.connect(func() -> void:
		if egg.is_queued_for_deletion() and _fertile_eggs.get(id) == egg:
			_fertile_eggs.erase(id)
			var rec := _record(id)
			if not rec.is_empty():
				_fertile().erase(rec))


## Fertile eggs lie where they were after a load (pickups are not saved).
func _restore_fertile() -> void:
	if Game.world == null:
		return
	for rec: Dictionary in _fertile():
		var id := int(rec["id"])
		if is_instance_valid(_fertile_eggs.get(id)):
			continue
		var at: Vector3 = rec.get("pos", global_position)
		var egg := Pickup.spawn(ItemStack.create(&"egg", 1, int(rec.get("q", 0))), at + Vector3(0, 0.03, 0))
		_watch_egg(egg, id)


## A fertile egg a whole day old hatches where it lies (room permitting).
func _hatch_due() -> void:
	var list: Array = entry.get("fertile", [])
	if list.is_empty():
		return
	var now := GameClock.total_minutes
	for rec: Dictionary in list.duplicate():
		var egg: Variant = _fertile_eggs.get(int(rec["id"]))
		if is_instance_valid(egg):
			rec["pos"] = (egg as Pickup).global_position
		if now - float(rec.get("at", now)) < HATCH_MINUTES:
			continue
		hatch_egg(rec)


## Hatches fertile egg `rec` now (tests and the day's check call it): its pickup makes
## way for the hatching shell and a chick. In a full coop it stays an ordinary egg.
func hatch_egg(rec: Dictionary) -> Animal:
	var id := int(rec["id"])
	_fertile().erase(rec)
	var egg: Variant = _fertile_eggs.get(id)
	_fertile_eggs.erase(id)
	if housing.free_space() <= 0:
		if _full_told != GameClock.day:
			_full_told = GameClock.day
			Game.notify(tr("MSG_EGG_NO_ROOM"), Color(1.0, 0.6, 0.35))
			Animals.report_notes.append(tr("MSG_EGG_NO_ROOM"))
		return null
	var at: Vector3 = rec.get("pos", global_position)
	var yaw := randf() * TAU
	if is_instance_valid(egg):
		var p := egg as Pickup
		at = p.global_position
		yaw = p.rotation.y
		p.queue_free()
	# Settled on whatever it lay on (the straw, the floor).
	at.y -= 0.02
	var a := Animals.hatch(housing, at, Animals.by_id(int(rec.get("hen", 0))))
	if a == null:
		return null
	var n := Animals.node_of(a)
	HatchingEgg.start(self, at, yaw, n)
	Events.animal_born.emit(a.species)
	return n


# --- Models ---------------------------------------------------------------------------------

## The nest bench: a plank-clad base, the boxes' floor, dividers, a lip that keeps the
## straw in and a sloping lid the hens can't roost on (the "Nests" node's space).
static func _build_bench() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var dark := AnimalBuildings.PLANK_DARK
	var x1 := NEST_BACK + NEST_DEPTH
	var xc := NEST_BACK + NEST_DEPTH * 0.5
	var z0 := NEST_Z0 - NEST_PITCH * 0.5
	var length := NEST_PITCH * NESTS
	var zc := z0 + length * 0.5
	var floor_top := NEST_SEAT - 0.03
	mb.box_at(&"planks", Vector3(xc, floor_top * 0.5, zc), Vector3(NEST_DEPTH, floor_top, length), dark, Vector3.ZERO, true)
	mb.box_at(&"wood_in", Vector3(xc + 0.01, floor_top - 0.015, zc), Vector3(NEST_DEPTH + 0.02, 0.03, length + 0.02), dark.lightened(0.05))
	# A kick board along the foot, scuffed darker.
	mb.box_at(&"wood_in", Vector3(x1 + 0.012, 0.06, zc), Vector3(0.025, 0.12, length), dark.darkened(0.15))
	var h := NEST_LID - floor_top
	for i in NESTS + 1:
		var z := z0 + i * NEST_PITCH
		mb.box_at(&"wood_in", Vector3(xc, floor_top + h * 0.5, z), Vector3(NEST_DEPTH, h, 0.025), dark.lightened(0.03 * (i % 2)))
	mb.box_at(&"wood_in", Vector3(x1 - 0.015, NEST_SEAT + 0.04, zc), Vector3(0.03, 0.12, length), dark.darkened(0.06))
	var rise := 0.22
	var run := NEST_DEPTH + 0.06
	mb.box_at(&"wood_in", Vector3(NEST_BACK + 0.015, NEST_LID + rise * 0.5, zc), Vector3(0.03, rise, length), dark)
	var ang := atan2(rise, run)
	var lid := Transform3D(Basis(Vector3(0, 0, 1), -ang), Vector3(NEST_BACK + run * 0.5, NEST_LID + rise * 0.5 + 0.015, zc))
	mb.box(&"wood_in", lid, Vector3(Vector2(run, rise).length(), 0.03, length + 0.06), dark.lightened(0.04))
	return mb.build()


## A nest box's bedding: a layer of straw pressed into a hollow, loose stalks and a few
## hanging over the lip (a nest's own space: its middle on the coop floor).
static func _build_straw() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var straw := Color(0.8, 0.66, 0.38)
	var inner := Vector2(NEST_DEPTH - 0.06, NEST_PITCH - 0.06)
	mb.box(&"straw", Transform3D(Basis(), Vector3(0, NEST_SEAT - 0.01, 0)), Vector3(inner.x, 0.06, inner.y), straw)
	for i in 9:
		var a := TAU * i / 9.0
		var p := Vector3(cos(a) * 0.13, NEST_SEAT + 0.02, sin(a) * 0.17)
		mb.sphere(&"straw", Transform3D(Basis(Vector3.UP, -a), p), Vector3(0.08, 0.04, 0.05), 6, 3,
				straw.lightened(rng.randf_range(-0.12, 0.08)))
	for i in 70:
		var p := Vector3(rng.randf_range(-0.2, 0.2), NEST_SEAT + rng.randf_range(0.01, 0.04), rng.randf_range(-0.26, 0.26))
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 0.45), rng.randf_range(-1, 1)).normalized()
		mb.cylinder_between(&"veg", p, p + d * rng.randf_range(0.07, 0.17), 0.003, 0.002, 3,
				straw.lightened(rng.randf_range(-0.22, 0.12)), false, false)
	for i in 12:
		var z := rng.randf_range(-0.25, 0.25)
		var p := Vector3(NEST_DEPTH * 0.5 - 0.12, NEST_SEAT + 0.04, z)
		var q := Vector3(NEST_DEPTH * 0.5 + 0.01, NEST_SEAT + 0.115, z + rng.randf_range(-0.04, 0.04))
		var r := q + Vector3(rng.randf_range(0.02, 0.05), -rng.randf_range(0.06, 0.16), rng.randf_range(-0.03, 0.03))
		var col := straw.lightened(rng.randf_range(-0.2, 0.1))
		mb.cylinder_between(&"veg", p, q, 0.003, 0.0025, 3, col, false, false)
		mb.cylinder_between(&"veg", q, r, 0.0025, 0.002, 3, col, false, false)
	return mb.build()


## A nest box: bedded with straw by hand (hay in hand, use), then the hens lay in it. Aimed
## at through its whole box, on the interaction layer only (eggs and the farmer pass; the
## bench is the solid part).
class Nest extends StaticBody3D:
	var coop: ChickenCoop
	var index := 0
	var straw_mesh: ArrayMesh
	var _straw: MeshInstance3D

	func _ready() -> void:
		collision_layer = 4
		collision_mask = 0
		add_to_group(&"interactable")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(ChickenCoop.NEST_DEPTH + 0.02, ChickenCoop.NEST_LID + 0.04, ChickenCoop.NEST_PITCH - 0.03)
		cs.shape = box
		cs.position.y = box.size.y * 0.5
		add_child(cs)
		# Millimetre stalks: no shadow pass, no GI.
		_straw = MeshInstance3D.new()
		_straw.mesh = straw_mesh
		_straw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_straw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_straw.visible = false
		add_child(_straw)

	func set_filled(on: bool) -> void:
		_straw.visible = on

	func interact_prompt(_player: Node) -> String:
		return ""

	func hint_prompt() -> String:
		if coop.nest_filled(index):
			return tr("HINT_NEST_BEDDED")
		var s := PlayerState.selected_stack()
		return tr("HINT_NEST_EMPTY") if s == null or s.item.id != &"hay" else ""

	func use_prompt(player: Node, stack: ItemStack) -> String:
		var a := use_action(player, stack)
		return tr(a["verb"]) if not a.is_empty() else ""

	func use_action(_player: Node, stack: ItemStack) -> Dictionary:
		if stack == null or stack.item.id != &"hay" or coop.nest_filled(index):
			return {}
		return {"id": "bed_nest", "verb": "ACTION_BED_NEST", "label": "PROGRESS_BEDDING", "duration": 0.9}

	func complete_use(_player: Node, _stack: ItemStack, _action: Dictionary) -> void:
		if coop.nest_filled(index) or PlayerState.inventory.count_item(&"hay") <= 0:
			return
		PlayerState.inventory.remove_item(&"hay", 1)
		coop.bed_nest(index)
		Audio.play("grass", global_position + Vector3(0, ChickenCoop.NEST_SEAT + 0.1, 0), -6.0)
