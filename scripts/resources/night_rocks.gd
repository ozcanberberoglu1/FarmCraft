class_name NightRocks
extends Node3D
## Stones the nights bring up: every morning (Events.day_started) a few new field rocks
## lie in the valley's open ground, more when the land has been picked clean, none once
## it is back to FIELD_TARGET standing field rocks (the valley's own, broken ones come
## back on their own after BreakableRock.RESPAWN_DAYS). They are BreakableRocks like the
## valley's, with ids "nrock_<n>" (FarmState.night_rock_serial) that never meet the
## generated "rock_<n>", saved in FarmState.night_rocks; one broken is gone for good
## the next morning (its entry and its depleted mark are dropped).
## NatureSpawner puts this under its "Rocks".

## Standing field rocks (not the quarry's) the mornings bring the valley back up to.
const FIELD_TARGET := 38
## New rocks a morning brings at most.
const PER_NIGHT := 3
## Never closer than this to the player (m): nothing appears in front of them.
const PLAYER_GAP := 18.0
## Clear of other rocks, trees, bushes and whatever the player put down (m).
const ROCK_GAP := 3.5
const TREE_GAP := 2.5
const PLACED_GAP := 5.0
const SIZE := Vector2(0.5, 1.05)

## Rolls where and how big (tests seed it).
static var rng := RandomNumberGenerator.new()

## Mornings bring rocks (off in automated runs, so other checks keep their ground; the
## nature scenario turns it on).
var active := true
var _rocks := {}


func _ready() -> void:
	rng.randomize()
	active = not DebugTools.is_automated()
	for e: Dictionary in FarmState.night_rocks:
		_spawn(e)
	Events.day_started.connect(_on_day_started)


## Standing (unbroken) field rocks in the valley, the valley's own and the nights'.
func standing_field_rocks() -> int:
	var n := 0
	for r: BreakableRock in get_tree().get_nodes_in_group(&"rocks"):
		if not r.quarry and not r.broken:
			n += 1
	return n


## How many a morning brings now: a third of what is missing (at least one), at most
## PER_NIGHT.
func due() -> int:
	var missing := FIELD_TARGET - standing_field_rocks()
	if missing <= 0:
		return 0
	return clampi(ceili(missing / 3.0), 1, PER_NIGHT)


func _on_day_started(_day: int) -> void:
	_clear_broken()
	if not active:
		return
	var n := due()
	var added := 0
	var attempts := 0
	while added < n and attempts < 400:
		attempts += 1
		var p := Vector2(rng.randf_range(-86.0, 86.0), rng.randf_range(-86.0, 86.0))
		if not _can_stand(p):
			continue
		var e := {"id": "nrock_%d" % FarmState.night_rock_serial, "x": p.x, "z": p.y,
			"size": snappedf(rng.randf_range(SIZE.x, SIZE.y), 0.05), "seed": rng.randi_range(1, 12), "yaw": rng.randf() * TAU}
		FarmState.night_rock_serial += 1
		FarmState.night_rocks.append(e)
		_spawn(e)
		added += 1


## Night rocks broken since yesterday are gone.
func _clear_broken() -> void:
	for e: Dictionary in FarmState.night_rocks.duplicate():
		var id := String(e.get("id", ""))
		if not FarmState.depleted.has(id):
			continue
		FarmState.depleted.erase(id)
		FarmState.night_rocks.erase(e)
		var rock: Node = _rocks.get(id)
		_rocks.erase(id)
		if rock and is_instance_valid(rock):
			rock.queue_free()


func _spawn(e: Dictionary) -> BreakableRock:
	var rock := BreakableRock.new()
	var id := String(e["id"])
	rock.name = id.to_pascal_case()
	rock.resource_id = id
	rock.size = float(e.get("size", 0.8))
	rock.rock_seed = int(e.get("seed", 1))
	rock.quarry = false
	rock.position = TerrainData.point_on_ground(float(e["x"]), float(e["z"]), -0.15 * rock.size)
	rock.rotation.y = float(e.get("yaw", 0.0))
	add_child(rock)
	_rocks[id] = rock
	return rock


## Open wild ground (NatureSpawner.open_ground), off the road, out of the town and the
## farm's plots, clear of rocks, trees, bushes, saplings and things put down, and away
## from the player.
func _can_stand(p: Vector2) -> bool:
	if not NatureSpawner.open_ground(p.x, p.y, 2.5):
		return false
	if WorldLayout.distance_to_road(p.x, p.y) < 7.0 or Placer.reserved(p.x, p.y):
		return false
	var at := Vector3(p.x, TerrainData.height(p.x, p.y), p.y)
	if Placer.in_building_plot(at):
		return false
	var player := Game.player as Node3D
	if player and is_instance_valid(player):
		var pp := player.global_position
		if Vector2(pp.x, pp.z).distance_squared_to(p) < PLAYER_GAP * PLAYER_GAP:
			return false
	for group: Array in [[&"rocks", ROCK_GAP], [&"trees", TREE_GAP], [&"berry_bushes", ROCK_GAP],
			[&"grass_patches", 2.0]]:
		var gap: float = group[1]
		for n: Node3D in get_tree().get_nodes_in_group(group[0]):
			var q := n.global_position
			if Vector2(q.x, q.z).distance_squared_to(p) < gap * gap:
				return false
	for e: Dictionary in FarmState.placed + FarmState.saplings:
		var pos: Variant = e.get("pos")
		if pos is Vector3 and Vector2((pos as Vector3).x, (pos as Vector3).z).distance_squared_to(p) < PLACED_GAP * PLACED_GAP:
			return false
	return true
