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
## Entry fields besides {id, pos, yaw}: stage ("site" / "done"), build_left (real
## seconds), door (open), uid (its home id), egg ("", "due", "laid", "taken"), egg_at
## (game minutes), egg_pos.

## Its id in Events.construction_started and Events.building_completed.
const BUILD_ID := &"coop"
## Layout in the coop's own frame (door toward +Z). The yard is the whole footprint
## (PlaceableTable size 11 x 10); the house stands at its back.
const YARD := Rect2(-5.5, -5.0, 11.0, 10.0)
const HOUSE := Rect2(-2.5, -4.4, 5.0, 3.4)
## Game minutes after the first hen moves in until she lays her first egg.
const FIRST_EGG_MINUTES := 25.0
## The first egg's Pickup is in this group (for the waypoint).
const FIRST_EGG_GROUP := &"first_egg"
## Waypoint anchor ids (WaypointMarker.tag): over the coop (or its site), over the
## door (outside the ramp) and the first egg itself.
const ANCHOR_COOP := &"coop"
const ANCHOR_DOOR := &"coop_door"
const ANCHOR_EGG := &"first_egg"
## A night's sleep (or any skip this long, in game minutes) finishes the construction.
const SKIP_FINISHES := 60.0
## The chopping log in the yard (by the house's front right corner).
const LOG_AT := Vector3(3.6, 0.0, -0.1)
## FarmState.depleted day of ground cleared for good (grass and rocks never come back).
const CLEARED := 1 << 30

var housing: AnimalHousing
var site: ConstructionSite
var _first_egg: Pickup

static var _props_mesh: ArrayMesh
static var _ghost_mesh: ArrayMesh


func _setup() -> void:
	# Kit coops are placed with their stage; anything else (old debug entries) stands.
	if not entry.has("stage"):
		entry["stage"] = "done"
	if not entry.has("uid"):
		var p: Vector3 = entry["pos"]
		entry["uid"] = "coop@%.1f,%.1f" % [p.x, p.z]
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


func _exit_tree() -> void:
	var farm := _farm()
	if housing and farm:
		farm.unregister_coop(housing)


## Finished (not a construction site any more).
func is_built() -> bool:
	return String(entry.get("stage", "done")) == "done"


## Real seconds the whole construction takes.
func build_seconds() -> float:
	return float(PlaceableTable.get_info(item_id).get("build_seconds", 180.0))


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
	if home != self or species != &"chicken" or String(entry.get("egg", "")) != "":
		return
	entry["egg"] = "due"
	entry["egg_at"] = GameClock.total_minutes + FIRST_EGG_MINUTES


func _on_tick(_total: float, _delta: float) -> void:
	if housing and String(entry.get("egg", "")) == "due" and GameClock.total_minutes >= float(entry.get("egg_at", 0.0)):
		_lay_first_egg()


## Where a hen is scratching about in the yard (else in front of the coop, or in a nest
## box when they are all shut in), with a cackle and a note.
func _lay_first_egg() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(uid())
	var spot := Vector3.INF
	for n in housing.animals_outside():
		spot = housing.clamp_to_pen(n.global_position, 0.6)
		spot.y = housing.ground_height(spot) + 0.1
		break
	if spot == Vector3.INF:
		spot = housing.egg_spot(rng) if not housing.door_open else housing.random_outdoor_point(rng) + Vector3(0, 0.1, 0)
	entry["egg"] = "laid"
	entry["egg_pos"] = spot
	_spawn_first_egg()
	Audio.animal_voice(&"chicken", true, spot, -2.0)
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
