class_name SaplingGrove
extends Node3D
## The saplings the player plants and the trees they grow into (FarmState.saplings).
## A felled tree drops a sapling now and then (DROP_CHANCE); with one in hand, LMB on
## open ground plants it (SaplingSpot, the Player's target there). A sapling grows only
## while its soil is wet (the watering can or rain keep it wet for CropTable.WET_HOURS):
## GROW_HOURS wet hours in all, about two days watered once a day, through
## Sapling.STAGE_SIZE, then it is a ChoppableTree like the valley's, with its own id.
## In the "fields" group: Weather waters every field, and every sapling, while it rains.

const ITEM := &"sapling"
const DROP_CHANCE := 0.6
## Wet hours from planting to a full tree.
const GROW_HOURS := 48.0
## How near a sapling may go to a tree (trunk to trunk), another sapling, a building.
const TREE_GAP := 3.0
const SAPLING_GAP := 2.5
const CLEAR_RADIUS := 0.9

static var instance: SaplingGrove = null
## Rolls a felled tree's sapling (tests seed it).
static var drop_rng := RandomNumberGenerator.new()
## The chance a felled tree drops a sapling (tests set it to 0 or 1).
static var drop_chance := DROP_CHANCE

## The planting spot (the Player's target on open ground with a sapling in hand).
var spot: SaplingSpot
## Growing saplings by id.
var _saplings := {}
## The trees grown from saplings by id.
var _trees := {}
var _clear_shape: CylinderShape3D


func _ready() -> void:
	instance = self
	add_to_group(&"fields")
	spot = SaplingSpot.new()
	spot.name = "Spot"
	add_child(spot)
	for e: Dictionary in FarmState.saplings:
		if bool(e.get("grown", false)):
			_spawn_tree(e)
		else:
			_spawn_sapling(e)
	Events.clock_tick.connect(_on_tick)
	Settings.changed.connect(_apply_quality)


func _exit_tree() -> void:
	if instance == self:
		instance = null


# --- Drops ------------------------------------------------------------------------------

## Whether a felled tree drops a sapling this time.
static func roll_drop() -> bool:
	return drop_rng.randf() < drop_chance


## A felled tree's crown landed: with DROP_CHANCE a sapling pops out at `at`.
static func drop_sapling(at: Vector3) -> Pickup:
	if not ItemDB.has_item(ITEM) or not roll_drop():
		return null
	var s := ItemStack.create(ITEM, 1)
	return Pickup.spawn(s, at, Vector3(drop_rng.randf_range(-0.8, 0.8), 2.4, drop_rng.randf_range(-0.8, 0.8)), true)


# --- Planting ---------------------------------------------------------------------------

## The Player's target on open ground: the planting spot where the ray meets the
## terrain, while a sapling is in hand (else null).
static func ground_target(player: Player, ray: RayCast3D) -> Node:
	if instance == null or not is_instance_valid(instance):
		return null
	var s := PlayerState.selected_stack()
	if s == null or s.item.id != ITEM or player.driving != null or player.riding != null:
		return null
	var body := ray.get_collider() as Node
	if body == null or not (body.get_parent() is Terrain) or ray.get_collision_normal().y < 0.7:
		return null
	return instance.spot.aim(player, ray.get_collision_point())


## "" where a sapling can go at `p` (on the ground), else why not (a translation key):
## open ground in the valley, off the road, the tracks, the fields and the farm's
## buildings and yard, not in water, not on a steep bank, clear of trees, saplings,
## rocks, fences and anything put down.
func plant_reason(p: Vector3, player: Node = null) -> String:
	var x := p.x
	var z := p.z
	var flat := Vector2(x, z)
	if WorldLayout.playable_distance(x, z) < 2.0 or flat.distance_to(WorldLayout.TOWN_CENTER) < WorldLayout.TOWN_BOUNDARY_RADIUS + 4.0 \
			or WorldLayout.distance_to_road(x, z) < 4.5:
		return "SAPLING_NOT_HERE"
	if WorldLayout.distance_to_pond(x, z) < WorldLayout.POND_RADIUS + 1.5 or TerrainData.is_underwater(x, z, 0.4):
		return "MSG_PLACE_WATER"
	if Placer.reserved(x, z) or TerrainData.path_at(x, z) > 0.1 or Placer.in_building_plot(p):
		return "SAPLING_NOT_HERE"
	if TerrainData.normal_at(x, z).y < 0.88:
		return "MSG_PLACE_FLAT"
	for t: Node3D in get_tree().get_nodes_in_group(&"trees"):
		if Vector2(t.global_position.x, t.global_position.z).distance_squared_to(flat) < TREE_GAP * TREE_GAP:
			return "SAPLING_TOO_CLOSE"
	for s: Sapling in _saplings.values():
		if Vector2(s.global_position.x, s.global_position.z).distance_squared_to(flat) < SAPLING_GAP * SAPLING_GAP:
			return "SAPLING_TOO_CLOSE"
	# Buildings, fences, rocks, machines, vehicles: anything standing round the spot.
	if _clear_shape == null:
		_clear_shape = CylinderShape3D.new()
		_clear_shape.radius = CLEAR_RADIUS
		_clear_shape.height = 2.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _clear_shape
	q.transform = Transform3D(Basis(), p + Vector3(0, 1.3, 0))
	q.collision_mask = 1 | 4 | 16
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	for path in ["Terrain/Collision", "Road/Collision"]:
		var body := Game.world.get_node_or_null(path) as CollisionObject3D if Game.world else null
		if body:
			exclude.append(body.get_rid())
	q.exclude = exclude
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(q, 8):
		# Tall grass is no obstacle: the sapling goes in among it.
		if hit["collider"] is GrassPatch:
			continue
		return "MSG_PLACE_BLOCKED"
	return ""


## Puts a sapling in the ground at `p` (the player planted it: it is already out of the
## bag). Returns the new sapling.
func plant(p: Vector3) -> Sapling:
	FarmState.sapling_serial += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(p.x * 10.0), roundi(p.z * 10.0))) + FarmState.sapling_serial
	var e := {"id": "planted_%d" % FarmState.sapling_serial, "kind": _kind_near(p, rng), "variant": rng.randi_range(1, 3),
		"pos": p, "yaw": rng.randf() * TAU, "scale": rng.randf_range(0.85, 1.15), "growth": 0.0, "wet": 0.0}
	FarmState.saplings.append(e)
	var s := _spawn_sapling(e)
	s.planted()
	Events.sapling_planted.emit(s)
	return s


## A sapling takes after the woods it is planted in: the nearest standing tree's kind
## (conifer or broadleaf); out in the open, either.
func _kind_near(p: Vector3, rng: RandomNumberGenerator) -> int:
	var best: ChoppableTree = null
	var best_d := 40.0 * 40.0
	for t: ChoppableTree in get_tree().get_nodes_in_group(&"trees"):
		var d := t.global_position.distance_squared_to(p)
		if d < best_d:
			best = t
			best_d = d
	if best:
		return best.kind
	return 0 if rng.randf() < 0.55 else 1


## Takes a sapling out of the ground again (dug up or chopped down).
func remove(s: Sapling) -> void:
	FarmState.saplings.erase(s.entry)
	_saplings.erase(String(s.entry["id"]))


func saplings() -> Array:
	return _saplings.values()


func grown_trees() -> Array:
	return _trees.values()


# --- Growing ----------------------------------------------------------------------------

func _on_tick(_total: float, delta_minutes: float) -> void:
	var hours := delta_minutes / 60.0
	for s: Sapling in _saplings.values():
		if s.advance(hours):
			_grow_up(s)


## Rain waters every sapling (Weather calls the "fields" group).
func rain() -> void:
	for s: Sapling in _saplings.values():
		s.soak()


## A sapling that has had its GROW_HOURS becomes a tree where it stood.
func _grow_up(s: Sapling) -> ChoppableTree:
	var e := s.entry
	e["grown"] = true
	e.erase("growth")
	e.erase("wet")
	_saplings.erase(String(e["id"]))
	var from := s.tree_size()
	s.become_tree()
	var t := _spawn_tree(e)
	t.grow_in(from, 3.0)
	Events.sapling_grown.emit(t)
	if not SaveGame.loading and is_instance_valid(Game.player) \
			and (Game.player as Node3D).global_position.distance_to(t.global_position) < 60.0:
		Game.notify(tr("MSG_SAPLING_GROWN"), UiTheme.GREEN)
	return t


func _spawn_sapling(e: Dictionary) -> Sapling:
	var s := Sapling.new()
	s.name = String(e["id"])
	s.entry = e
	add_child(s)
	_saplings[String(e["id"])] = s
	return s


func _spawn_tree(e: Dictionary) -> ChoppableTree:
	var t := ChoppableTree.new()
	t.name = String(e["id"])
	t.resource_id = String(e["id"])
	t.kind = int(e.get("kind", 0))
	t.variant = int(e.get("variant", 1))
	t.tree_scale = float(e.get("scale", 1.0))
	var p: Vector3 = e["pos"]
	t.position = TerrainData.point_on_ground(p.x, p.z, -0.1)
	t.rotation.y = float(e.get("yaw", 0.0))
	add_child(t)
	_trees[String(e["id"])] = t
	_lod(t)
	return t


## The grown trees keep their detail as far as the valley's (NatureSpawner.LOD_BIAS).
func _lod(t: Node) -> void:
	for mi: MeshInstance3D in t.find_children("*", "MeshInstance3D", true, false):
		mi.lod_bias = NatureSpawner.LOD_BIAS[Settings.quality]


func _apply_quality() -> void:
	for t: Node in _trees.values():
		if is_instance_valid(t):
			_lod(t)
	for s: Sapling in _saplings.values():
		s.apply_quality()
