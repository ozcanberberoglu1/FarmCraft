class_name Farm
extends Node3D
## Creates everything the player owns from FarmState (garden lots, animal housing,
## house level) and adds new projects the moment they are built. Unbuilt lots get
## a "for sale" sign, Grandpa's run-down house and warehouse a "needs repair" one
## (mended by hand with wood, see RepairSpot).
## Coops are put up from kits (ChickenCoop, among the placed things); Grandpa's fixed
## chicken run stays only on the farms that built it.

var fields := {}
var barn: AnimalHousing
var coop: AnimalHousing
## The finished kit-built coops' housing by home id (ChickenCoop registers them).
var placed_coops := {}
var _signs := {}


func _ready() -> void:
	# The crop plants load in the background now, not when a bed first grows into them.
	PlantModels.warm_units()
	for lot_id: StringName in WorldLayout.FIELD_LOTS:
		if FarmState.is_built(lot_id):
			_build_field(lot_id, false)
		else:
			_add_sign(lot_id, _lot_sign_point(lot_id))
	barn = AnimalHousing.new()
	barn.setup("barn")
	add_child(barn)
	barn.set_level(FarmState.barn_level())
	coop = AnimalHousing.new()
	coop.setup("coop")
	add_child(coop)
	coop.set_level(FarmState.coop_level())
	if FarmState.barn_level() == 0:
		_add_sign(&"barn_1", WorldLayout.gate_point(WorldLayout.BARN_PEN, WorldLayout.BARN_GATE, 2.2) + Vector3(0, 0, 3.0))
	# No sign for Grandpa's old run: it isn't sold any more (coops come as kits).
	# Repair signs face the yard: the house one where the player wakes up, the
	# warehouse one the track from the house.
	if not FarmState.is_built(&"house_1"):
		_add_sign(&"house_1", WorldLayout.HOUSE_REPAIR_SIGN, "SIGN_REPAIR",
				Vector2(WorldLayout.PLAYER_SPAWN.x, WorldLayout.PLAYER_SPAWN.z))
	if not FarmState.is_built(&"warehouse_1"):
		_add_sign(&"warehouse_1", WorldLayout.WAREHOUSE_REPAIR_SIGN, "SIGN_REPAIR", Vector2(-15, -2))
	FarmState.project_built.connect(_on_project_built)
	_place_props()
	var placed_root := Node3D.new()
	placed_root.name = "Placed"
	add_child(placed_root)
	for e: Dictionary in FarmState.placed:
		spawn_placed(e)
	Animals.spawn_all.call_deferred()


func _place_props() -> void:
	var board := ConstructionBoard.new()
	board.name = "ConstructionBoard"
	board.position = WorldLayout.BOARD_POS
	board.rotation.y = deg_to_rad(-35.0)
	add_child(board)
	var bin := ShippingBin.new()
	bin.name = "ShippingBin"
	bin.position = WorldLayout.SHIPPING_BIN_POS
	add_child(bin)
	# The market and the livestock dealer are in town (Yeşilova) now.
	var heap := ManureHeap.new()
	heap.name = "ManureHeap"
	heap.position = Vector3(WorldLayout.MANURE_HEAP.x, 0.0, WorldLayout.MANURE_HEAP.y)
	heap.position.y = TerrainData.height(heap.position.x, heap.position.z) - 0.12
	add_child(heap)
	Game.world.block_grass(Rect2(heap.position.x - 1.6, heap.position.z - 1.4, 3.2, 2.8))
	var warehouse := Warehouse.new()
	warehouse.name = "Warehouse"
	add_child(warehouse)
	Game.world.block_grass(Rect2(WorldLayout.SHIPPING_BIN_POS.x - 0.8, WorldLayout.SHIPPING_BIN_POS.z - 0.6, 1.6, 1.2))


## The node for something the player put down (FarmState.placed entry).
func spawn_placed(e: Dictionary) -> PlacedObject:
	var node := PlacedObject.create(e)
	get_node("Placed").add_child(node)
	return node


## The main housing of a kind: the barn; Grandpa's run when it is built, else the
## first finished kit-built coop, else the unbuilt run (level 0).
func housing_for(kind: String) -> AnimalHousing:
	if kind == "barn":
		return barn
	if coop.level > 0:
		return coop
	for id: String in placed_coops:
		var h := housing_by_id(id)
		if h:
			return h
	return coop


## A finished kit-built coop's housing by its home id (null when there is none).
func housing_by_id(id: String) -> AnimalHousing:
	# Untyped first: a coop may have been freed with its scene.
	var h = placed_coops.get(id)
	return h as AnimalHousing if is_instance_valid(h) else null


## Every built housing: the barn, Grandpa's run and the finished coops.
func housings() -> Array[AnimalHousing]:
	var out: Array[AnimalHousing] = []
	for h: AnimalHousing in [barn, coop]:
		if h.level > 0:
			out.append(h)
	for id: String in placed_coops:
		var h := housing_by_id(id)
		if h and h.level > 0:
			out.append(h)
	return out


## The coops put up from kits, sites included, oldest first (waypoints, tests).
func kit_coops() -> Array[ChickenCoop]:
	var out: Array[ChickenCoop] = []
	var root := get_node_or_null("Placed")
	if root:
		for n in root.get_children():
			if n is ChickenCoop and not n.is_queued_for_deletion():
				out.append(n as ChickenCoop)
	return out


## Called by a ChickenCoop when it is finished (or loaded finished).
func register_coop(housing: AnimalHousing) -> void:
	placed_coops[housing.home_id] = housing


func unregister_coop(housing: AnimalHousing) -> void:
	var cur = placed_coops.get(housing.home_id)
	if not is_instance_valid(cur) or cur == housing:
		placed_coops.erase(housing.home_id)


func _lot_sign_point(lot_id: StringName) -> Vector3:
	var lot: Dictionary = WorldLayout.FIELD_LOTS[lot_id]
	return WorldLayout.gate_point(lot["rect"], lot["gates"][0], 1.4)


## A sign for `project_id` at `at`, facing `face` (world XZ; the farmhouse door when
## left out). `header_key` is its header ("SIGN_FOR_SALE" or "SIGN_REPAIR"); a repair
## sign says to mend the walls with wood and counts the holes done (RepairSpot.Sign).
func _add_sign(project_id: StringName, at: Vector3, header_key := "SIGN_FOR_SALE",
		face := Vector2(WorldLayout.HOUSE_DOOR_X, WorldLayout.HOUSE_FRONT_Z)) -> void:
	var board: ForSaleSign
	if header_key == "SIGN_REPAIR":
		var repair := RepairSpot.Sign.new()
		repair.building_id = RepairSpot.building_of(project_id)
		board = repair
	else:
		board = ForSaleSign.new()
	board.project_id = project_id
	board.name = "Sign_%s" % project_id
	board.header_key = header_key
	if header_key == "SIGN_REPAIR":
		board.accent = Color(0.78, 0.46, 0.1)
	board.position = Vector3(at.x, TerrainData.height(at.x, at.z), at.z)
	var to_face := face - Vector2(at.x, at.z)
	board.rotation.y = atan2(to_face.x, to_face.y)
	add_child(board)
	_signs[project_id] = board


func _remove_sign(project_id: StringName) -> void:
	if _signs.has(project_id):
		_signs[project_id].queue_free()
		_signs.erase(project_id)


func _build_field(lot_id: StringName, animate: bool) -> void:
	var lot: Dictionary = WorldLayout.FIELD_LOTS[lot_id]
	var rect: Rect2 = lot["rect"]
	var fence := Fence.new()
	var f := WorldLayout.fence_around(rect, lot["gates"])
	fence.name = "Fence_%s" % lot_id
	fence.points = f["points"]
	fence.gaps = f["gaps"]
	fence.closed = true
	fence.seed_value = hash(lot_id) % 1000
	add_child(fence)
	var field := Field.new()
	field.name = String(lot_id)
	var c := rect.get_center()
	field.position = Vector3(c.x, 0, c.y)
	add_child(field)
	fields[lot_id] = field
	Game.world.block_grass(rect.grow(-0.3))
	if animate:
		Fx.dust_cloud(Vector3(c.x, 0.4, c.y), rect.size * 0.5)


func _on_project_built(id: StringName) -> void:
	_remove_sign(id)
	match id:
		&"field_1", &"field_2", &"field_3":
			_build_field(id, true)
		&"barn_1", &"barn_2":
			barn.set_level(FarmState.barn_level(), true)
		&"coop_1", &"coop_2":
			coop.set_level(FarmState.coop_level(), true)
		&"house_1", &"house_2", &"house_3":
			var house := get_parent().get_node_or_null("FarmHouse") as FarmHouse
			if house:
				house.level = FarmState.house_level()
				var r := house.footprint()
				Fx.dust_cloud(Vector3(r.get_center().x, 1.0, r.get_center().y), r.size * 0.5)
		&"warehouse_1", &"warehouse_2":
			var wh := get_node_or_null("Warehouse") as Warehouse
			if wh:
				wh.set_level(FarmState.warehouse_level(), true)
	Game.notify(tr("MSG_BUILT") % tr("PROJECT_" + String(id).to_upper()), Color(0.55, 1.0, 0.45))
