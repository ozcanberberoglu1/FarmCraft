class_name CrateBay
extends StaticBody3D
## The crate corner in the farm warehouse: crated animals kept in the warehouse stock
## stand in a row on the floor in front of the back pallets (a second row stacked on
## the first), a live hen in each of the first LIVE_MAX and a still one in the rest.
## E sets the crates in hand down, or lifts one up into the hands. Crates moved in
## through the ledger show up here too, and every crate that arrives is announced
## (Events.crate_stored, "warehouse"). Local frame: the row runs along +X from the
## origin on the floor; this node's box (layer 4) only stops the interaction ray, a
## child body (layer 1) keeps the farmer out of the crates on show.

const PER_ROW := 8
const ROWS := 2
## Centre to centre along the row.
const STEP := 0.56
## Crates with a live hen in them; the others get a modelled one (saves rigs).
const LIVE_MAX := 8

## Crate mesh key ("id:live" or "id:still") -> MultiMeshInstance3D.
var _mmis := {}
var _hens: Array[CrateHen] = []
var _solid: CollisionShape3D
var _marker: Marker3D
## Crates in the stock by id at the last look, to tell arrivals.
var _known := {}
var _queued := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	var length := PER_ROW * STEP
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length + 0.2, 0.9, 0.8)
	cs.shape = box
	cs.position = Vector3(length * 0.5 - STEP * 0.5, 0.45, 0)
	add_child(cs)
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_solid = CollisionShape3D.new()
	_solid.shape = BoxShape3D.new()
	_solid.disabled = true
	body.add_child(_solid)
	_marker = Marker3D.new()
	_marker.name = "CrateBayMarker"
	_marker.position = Vector3(length * 0.5 - STEP * 0.5, 1.1, 0)
	# Found by the guide dot (WaypointMarker.anchor) and by the "waypoints" group.
	WaypointMarker.tag(_marker, &"crate_bay")
	_marker.add_to_group(&"waypoints")
	add_child(_marker)
	_known = _crates()
	FarmState.warehouse.changed.connect(_queue)
	_refresh()


## Where the story's waypoint dot floats (over the row).
func waypoint() -> Node3D:
	return _marker


## Crates in the warehouse stock: [{id, quality, count}], the first kind first.
func live_entries() -> Array:
	return FarmState.warehouse.entries().filter(func(e: Dictionary) -> bool: return LiveCrates.is_live(e["id"]))


## Crates on show (all kinds).
func shown() -> int:
	var n := 0
	for mmi: MultiMeshInstance3D in _mmis.values():
		n += mmi.multimesh.instance_count
	return n


## Live hens sitting in the crates on show.
func live_count() -> int:
	return _hens.size()


func _crates() -> Dictionary:
	var out := {}
	for e: Dictionary in live_entries():
		out[e["id"]] = int(out.get(e["id"], 0)) + int(e["count"])
	return out


## Stock changes come in bursts: one look after the burst.
func _queue() -> void:
	if not _queued:
		_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_queued = false
	if not is_inside_tree():
		return
	var now := _crates()
	if not SaveGame.loading:
		for id: StringName in now:
			if int(now[id]) > int(_known.get(id, 0)):
				Events.crate_stored.emit(id, &"warehouse")
	_known = now
	# Slots: the floor row first, then the row on top.
	var order: Array[StringName] = []
	for id: StringName in now:
		for i in int(now[id]):
			if order.size() < PER_ROW * ROWS:
				order.append(id)
	var groups := {}
	var hen_slots: Array[Transform3D] = []
	for i in order.size():
		var xf := _slot(i)
		var live := i < LIVE_MAX
		var key := "%s:%s" % [order[i], "live" if live else "still"]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(xf)
		if live:
			hen_slots.append(xf)
	for key: String in _mmis:
		if not groups.has(key):
			(_mmis[key] as MultiMeshInstance3D).multimesh.instance_count = 0
	for key: String in groups:
		var list: Array = groups[key]
		var mm := _mmi(key).multimesh
		mm.instance_count = list.size()
		for j in list.size():
			mm.set_instance_transform(j, list[j])
	_sync_hens(hen_slots)
	# The farmer walks round the crates, not through them.
	var n := order.size()
	_solid.disabled = n == 0
	if n > 0:
		var along := mini(n, PER_ROW)
		var high := 2 if n > PER_ROW else 1
		(_solid.shape as BoxShape3D).size = Vector3(along * STEP, CargoModels.SIZE.y * high + 0.02, CargoModels.SIZE.z + 0.04)
		_solid.position = Vector3((along - 1) * STEP * 0.5, (CargoModels.SIZE.y * high + 0.02) * 0.5, 0)


## Crate `i` on show: along the row, a little askew; the top row sits on the bottom one.
func _slot(i: int) -> Transform3D:
	var row := i / PER_ROW
	var k := i % PER_ROW
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 977 + 13
	var yaw := rng.randf_range(-0.07, 0.07) + (PI if (k + row) % 2 == 1 else 0.0)
	var at := Vector3(k * STEP + rng.randf_range(-0.025, 0.025), row * (CargoModels.SIZE.y + 0.012), rng.randf_range(-0.03, 0.03))
	return Transform3D(Basis(Vector3.UP, yaw), at)


func _sync_hens(slots: Array[Transform3D]) -> void:
	while _hens.size() > slots.size():
		_hens.pop_back().queue_free()
	while _hens.size() < slots.size():
		var hen := CrateHen.new()
		hen.variant = _hens.size() + 1
		# A crowd of crates in a shed would be a racket: every other one keeps quiet.
		hen.voice = _hens.size() % 2 == 0
		add_child(hen)
		_hens.append(hen)
	for i in slots.size():
		_hens[i].transform = slots[i]


func _mmi(key: String) -> MultiMeshInstance3D:
	if _mmis.has(key):
		return _mmis[key]
	var parts := key.split(":")
	var id := StringName(parts[0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Live crates are empty for their CrateHen; the still ones carry a modelled hen.
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
	var s := PlayerState.selected_stack()
	var next := _next_crate(s)
	if next.is_empty():
		if s and LiveCrates.is_live(s.item.id):
			return tr("ACTION_SET_DOWN_CRATES") % s.count
		return ""
	return tr("ACTION_TAKE_CRATE") % [ItemDB.get_item(next["id"]).display_name(), LiveCrates.count_at(&"warehouse")]


## With crates in hand and more to pick up, E stacks the next one on them: Q sets them down.
func drop_prompt() -> String:
	var s := PlayerState.selected_stack()
	if s and LiveCrates.is_live(s.item.id) and not _next_crate(s).is_empty():
		return tr("ACTION_SET_DOWN_CRATES") % s.count
	return ""


## Q at the bay: the crates in hand go back into the warehouse.
func drop_held() -> bool:
	var s := PlayerState.selected_stack()
	if s == null or not LiveCrates.is_live(s.item.id):
		return false
	_set_down()
	return true


func interact(_player: Node) -> void:
	var s := PlayerState.selected_stack()
	var next := _next_crate(s)
	if next.is_empty():
		if s and LiveCrates.is_live(s.item.id):
			_set_down()
		return
	var id: StringName = next["id"]
	var q := int(next["quality"])
	if LiveCrates.put_in_hand(id, 1, q) <= 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), UiTheme.RED)
		return
	FarmState.warehouse.take(id, 1, q)
	Audio.animal_voice(AnimalTable.species_of_crate(id), true, _marker.global_position - Vector3(0, 0.8, 0), -10.0)


## The crate E would pick up: with crates already in hand, one more of the same kind
## while the stack has room (they are carried together); else the first on the pile.
func _next_crate(held: ItemStack) -> Dictionary:
	var live := live_entries()
	if held and LiveCrates.is_live(held.item.id):
		if held.space_left() <= 0:
			return {}
		for e: Dictionary in live:
			if StringName(e["id"]) == held.item.id and int(e["quality"]) == held.quality:
				return e
		return {}
	return {} if live.is_empty() else live[0]


func _set_down() -> void:
	if FarmState.warehouse.store_stack(PlayerState.inventory, PlayerState.selected) <= 0:
		Game.notify(tr("MSG_NO_ROOM"), UiTheme.RED)
	else:
		Audio.play("plank", _marker.global_position - Vector3(0, 0.8, 0), -10.0)
