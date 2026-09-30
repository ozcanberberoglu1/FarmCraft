class_name MarketCrates
extends StaticBody3D
## The Animal Market's pickup spot: the crates bought there (FarmState.market_crates) are
## set down on the ground in front of the seller, just inside the gate by the office
## hatch, and wait until the farmer carries them to the pickup parked in the street (or
## home by hand). They stand in a tidy row along the lane's edge, stacked up to LAYERS
## high (PER_ROW * LAYERS = LiveCrates.MAX_WAITING), a live bird in each of the first
## LIVE_MAX and a still one in the rest. E lifts one into the hands (onto the crates of
## the same kind already carried, see LiveCrates.put_in_hand). Local frame: the row runs
## along +X from the origin on the ground; this node's box (layer 4, only while crates
## wait) stops the interaction ray, a child body (layer 1) keeps the farmer and vehicles
## out of the crates on show.

## Found by LiveCrates.market_spot.
const GROUP := &"market_crates"
## Waypoint anchor id over the crates (the story's dot while bought crates wait).
const ANCHOR := &"market_crates"
const PER_ROW := 4
const LAYERS := 3
## Centre to centre along the row.
const STEP := 0.56
## Crates with a live bird in them; the others get a modelled one (saves rigs).
const LIVE_MAX := 8

## Crate mesh key ("id:live" or "id:still") -> MultiMeshInstance3D.
var _mmis := {}
var _birds: Array[CrateHen] = []
var _ray_box: CollisionShape3D
var _solid: CollisionShape3D
var _marker: Marker3D
var _queued := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(GROUP)
	_ray_box = CollisionShape3D.new()
	_ray_box.shape = BoxShape3D.new()
	add_child(_ray_box)
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_solid = CollisionShape3D.new()
	_solid.shape = BoxShape3D.new()
	body.add_child(_solid)
	_marker = Marker3D.new()
	_marker.name = "MarketCratesMarker"
	_marker.position = Vector3((PER_ROW - 1) * STEP * 0.5, CargoModels.SIZE.y * LAYERS + 1.0, 0)
	# Found by the guide dot (WaypointMarker.anchor) and by the "waypoints" group.
	WaypointMarker.tag(_marker, ANCHOR)
	_marker.add_to_group(&"waypoints")
	add_child(_marker)
	FarmState.market_crates.changed.connect(_queue)
	_refresh()


## Where the story's waypoint dot floats (over the stack).
func waypoint() -> Node3D:
	return _marker


## Crates waiting: [{id, quality, count}], the first kind first.
func live_entries() -> Array:
	return FarmState.market_crates.entries().filter(func(e: Dictionary) -> bool: return LiveCrates.is_live(e["id"]))


## Crates on show (all kinds).
func shown() -> int:
	var n := 0
	for mmi: MultiMeshInstance3D in _mmis.values():
		n += mmi.multimesh.instance_count
	return n


## Live birds sitting in the crates on show.
func live_count() -> int:
	return _birds.size()


## Stock changes come in bursts: one look after the burst.
func _queue() -> void:
	if not _queued:
		_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_queued = false
	if not is_inside_tree():
		return
	# Slots: along the row on the ground first, then a layer on top, and another.
	var order: Array[StringName] = []
	for e: Dictionary in live_entries():
		for i in int(e["count"]):
			if order.size() < PER_ROW * LAYERS:
				order.append(e["id"])
	var groups := {}
	var bird_slots: Array[Transform3D] = []
	var bird_kinds: Array[StringName] = []
	for i in order.size():
		var xf := _slot(i)
		var live := i < LIVE_MAX
		var key := "%s:%s" % [order[i], "live" if live else "still"]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
		if live:
			bird_slots.append(xf)
			bird_kinds.append(AnimalTable.species_of_crate(order[i]))
	for key: String in _mmis:
		if not groups.has(key):
			(_mmis[key] as MultiMeshInstance3D).multimesh.instance_count = 0
	for key: String in groups:
		var list: Array = groups[key]
		var mm := _mmi(key).multimesh
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])
	_sync_birds(bird_slots, bird_kinds)
	# Nothing waiting: nothing to bump into, and the ray passes (to the hatch beyond).
	var n := order.size()
	_solid.disabled = n == 0
	_ray_box.disabled = n == 0
	collision_layer = 4 if n > 0 else 0
	if n > 0:
		var along := mini(n, PER_ROW)
		var high := ceili(float(n) / PER_ROW)
		var h := CargoModels.SIZE.y * high + 0.012 * (high - 1)
		(_solid.shape as BoxShape3D).size = Vector3(along * STEP, h + 0.02, CargoModels.SIZE.z + 0.04)
		_solid.position = Vector3((along - 1) * STEP * 0.5, (h + 0.02) * 0.5, 0)
		(_ray_box.shape as BoxShape3D).size = Vector3(along * STEP + 0.2, h + 0.3, CargoModels.SIZE.z + 0.4)
		_ray_box.position = Vector3((along - 1) * STEP * 0.5, (h + 0.3) * 0.5, 0)


## Crate `i` on show: along the row, a little askew, each layer on the one below.
func _slot(i: int) -> Transform3D:
	var layer := i / PER_ROW
	var k := i % PER_ROW
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 613 + 29
	var yaw := rng.randf_range(-0.06, 0.06) + (PI if (k + layer) % 2 == 1 else 0.0)
	var at := Vector3(k * STEP + rng.randf_range(-0.03, 0.03), layer * (CargoModels.SIZE.y + 0.012), rng.randf_range(-0.03, 0.03))
	return Transform3D(Basis(Vector3.UP, yaw), at)


func _sync_birds(slots: Array[Transform3D], kinds: Array[StringName]) -> void:
	# A crate that now holds another kind (a rooster where a hen sat): a new bird.
	for i in mini(_birds.size(), kinds.size()):
		if _birds[i].species != kinds[i]:
			while _birds.size() > i:
				_birds.pop_back().queue_free()
			break
	while _birds.size() > slots.size():
		_birds.pop_back().queue_free()
	while _birds.size() < slots.size():
		var bird := CrateHen.new()
		bird.variant = _birds.size() + 2
		bird.species = kinds[_birds.size()]
		# A stack of crates in the lane would be a racket: every other one keeps quiet.
		bird.voice = _birds.size() % 2 == 0
		bird.view_range = 60.0
		add_child(bird)
		_birds.append(bird)
	for i in slots.size():
		_birds[i].transform = slots[i]


func _mmi(key: String) -> MultiMeshInstance3D:
	if _mmis.has(key):
		return _mmis[key]
	var parts := key.split(":")
	var id := StringName(parts[0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Live crates are empty for their CrateHen; the still ones carry a modelled bird.
	mm.mesh = CargoModels.mesh(id, 0) if parts[1] == "live" else ItemModels.mesh(id)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Crates_" + key.replace(":", "_")
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.layers = 2
	mmi.visibility_range_end = 60.0
	add_child(mmi)
	_mmis[key] = mmi
	return mmi


# --- Interaction ---------------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	var next := _next_crate()
	if next.is_empty():
		return ""
	return tr("ACTION_TAKE_CRATE") % [ItemDB.get_item(next["id"]).display_name(), LiveCrates.count_at(&"market")]


## E: the next crate goes into the hands, never into the bag (with a full hotbar what
## is in hand goes into the bag instead, see LiveCrates.put_in_hand); with crates filling
## the hands, or no room in the bag for what is in hand, it stays here.
func interact(_player: Node) -> void:
	var next := _next_crate()
	if next.is_empty():
		return
	var id: StringName = next["id"]
	var q := int(next["quality"])
	if LiveCrates.put_in_hand(id, 1, q) <= 0:
		Game.notify(LiveCrates.hands_full_message(), UiTheme.RED)
		return
	FarmState.market_crates.take(id, 1, q)
	Audio.animal_voice(AnimalTable.species_of_crate(id), true, _marker.global_position - Vector3(0, 1.2, 0), -10.0)


## The crate E would pick up: one more of the kind in hand while the stack has room
## (they are carried together), else the first waiting.
func _next_crate() -> Dictionary:
	var live := live_entries()
	if live.is_empty():
		return {}
	var held := PlayerState.selected_stack()
	if held and LiveCrates.is_live(held.item.id) and held.space_left() > 0:
		for e: Dictionary in live:
			if StringName(e["id"]) == held.item.id and int(e["quality"]) == held.quality:
				return e
	return live[0]
