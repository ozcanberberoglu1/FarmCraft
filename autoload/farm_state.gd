extends Node
## What the player owns on the farm: built projects (fields, house level, animal
## housing) and the contents of every storage container.

signal project_built(id: StringName)
signal manure_changed

var built := {&"field_0": true}
## Container inventories by id (chests, shipping bin...), so they survive rebuilds.
var storage := {}
## Harvested world resources (trees, rocks, grass) by id -> day they were depleted.
var depleted := {}
## Felled trees' stumps by id -> [cut height over the tree's origin (m), notch yaw].
var stumps := {}
## Saplings the player planted and the trees they grew into (SaplingGrove):
## [{id, kind, variant, pos, yaw, scale, growth, wet, grown}]. Ids "planted_<n>" never
## meet the valley's generated "tree_<n>".
var saplings: Array = []
var sapling_serial := 0
## The farm warehouse: produce and materials stocked by the unit. Its capacity follows
## warehouse_level() (a new farm starts with Grandpa's run-down shed).
var warehouse := Stockpile.new(ProjectTable.WAREHOUSE_CAPACITY[0])
## Manure on the heap by the barn (fills overnight from the animals' bedding).
var manure := 0.0
const MANURE_MAX := ManureMound.MAX
## Rations of chicken feed Grandpa left in the warehouse (a new game's first hens eat it).
const STARTER_FEED := 20
## Things put down on the farm: [{id, pos, yaw, ...their own state}].
var placed: Array = []
## One-off states of the farm (the house door, the desk drawer, what was taken from the
## table...), by name.
var flags := {}


func _ready() -> void:
	project_built.connect(func(id: StringName) -> void:
		if id == &"warehouse_1" or id == &"warehouse_2":
			warehouse.capacity = ProjectTable.WAREHOUSE_CAPACITY[warehouse_level()]
			warehouse.changed.emit())
	# The first "New Game" after launch plays on the farm built at launch, which never
	# went through new_game(): stock its warehouse the same way. Deferred, so DebugTools
	# has read its arguments (automated runs keep an empty warehouse).
	_stock_fresh_farm.call_deferred()


func _stock_fresh_farm() -> void:
	if DebugTools.is_automated() or SaveGame.loading:
		return
	if not flags.has("legacy") and not flags.has("starter_feed") and warehouse.total() == 0:
		warehouse.add(&"feed", STARTER_FEED)
	flags["starter_feed"] = true


func is_built(id: StringName) -> bool:
	return built.get(id, false)


func can_build(id: StringName) -> bool:
	var p := ProjectTable.get_project(id)
	if p.is_empty() or is_built(id) or Progress.level < UnlockTable.project_level(id):
		return false
	for req in p["requires"]:
		if not is_built(req):
			return false
	return true


## Returns "" when affordable, else a message describing what is missing.
func missing_for(id: StringName) -> String:
	var p := ProjectTable.get_project(id)
	var missing := PackedStringArray()
	if Economy.money < int(p["cost"]):
		missing.append(tr("MSG_NEED_GOLD") % UiTheme.money(int(p["cost"]) - Economy.money))
	for item_id: StringName in p["items"]:
		var have := PlayerState.inventory.count_item(item_id)
		var need: int = p["items"][item_id]
		if have < need:
			missing.append("%s ×%d" % [ItemDB.get_item(item_id).display_name(), need - have])
	return UiTheme.join_list(missing)


## Pays for and builds a project. Returns false if it can't be built or afforded.
## A kit project (ProjectTable "kit") is cut and bundled instead: the kit goes into the
## bag (at the player's feet when the bag is full) and the project stays open.
func build(id: StringName) -> bool:
	if not can_build(id) or missing_for(id) != "":
		return false
	var p := ProjectTable.get_project(id)
	Economy.spend(int(p["cost"]), "REPORT_CONSTRUCTION")
	for item_id: StringName in p["items"]:
		PlayerState.inventory.remove_item(item_id, p["items"][item_id])
	var kit := ProjectTable.kit_of(id)
	if kit != &"":
		if PlayerState.give(kit, 1) > 0 and Game.player:
			var at := (Game.player as Node3D).global_position
			Pickup.spawn(ItemStack.create(kit, 1), at + Vector3(0, 0.6, 0))
		Events.crafted.emit(kit, 1)
		return true
	built[id] = true
	project_built.emit(id)
	return true


## Whether the construction board lists `id`: Grandpa's old chicken run (and its
## upgrade) only on the farms that have it; everyone else builds coops from the kit.
func is_listed(id: StringName) -> bool:
	match id:
		&"coop_1":
			return is_built(&"coop_1")
		&"coop_2":
			return is_built(&"coop_1")
	return true


## 0 = Grandpa's run-down house, 1 = repaired, 2-3 = extended.
func house_level() -> int:
	if is_built(&"house_3"):
		return 3
	if is_built(&"house_2"):
		return 2
	return 1 if is_built(&"house_1") else 0


## 0 = run-down, 1 = repaired, 2 = bigger (see ProjectTable.WAREHOUSE_CAPACITY).
func warehouse_level() -> int:
	if is_built(&"warehouse_2"):
		return 2
	return 1 if is_built(&"warehouse_1") else 0


func barn_level() -> int:
	if is_built(&"barn_2"):
		return 2
	return 1 if is_built(&"barn_1") else 0


func coop_level() -> int:
	if is_built(&"coop_2"):
		return 2
	return 1 if is_built(&"coop_1") else 0


## The coops put up from kits (their `placed` entries), finished or still going up.
func coop_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in placed:
		if String(e.get("id", "")) == "coop_kit":
			out.append(e)
	return out


## A chicken house hens can move into: Grandpa's old run or a finished coop.
func has_coop() -> bool:
	if coop_level() > 0:
		return true
	for e in coop_entries():
		if String(e.get("stage", "done")) == "done":
			return true
	return false


## A coop stands on the farm or one is going up.
func coop_started() -> bool:
	return coop_level() > 0 or not coop_entries().is_empty()


func get_storage(id: String, size: int) -> Inventory:
	if not storage.has(id):
		storage[id] = Inventory.new(size)
	var inv: Inventory = storage[id]
	if not inv.accepts.is_valid():
		inv.accepts = func(item: ItemData) -> bool: return item.category != "animal"
	if inv.size() < size:
		inv.slots.resize(size)
	return inv


func add_placed(id: StringName, pos: Vector3, yaw: float) -> Dictionary:
	var e := {"id": String(id), "pos": pos, "yaw": yaw}
	placed.append(e)
	return e


func remove_placed(e: Dictionary) -> void:
	placed.erase(e)


func add_manure(amount: float) -> void:
	manure = clampf(manure + amount, 0.0, MANURE_MAX)
	manure_changed.emit()


func new_game() -> void:
	built = {&"field_0": true}
	storage.clear()
	depleted.clear()
	stumps.clear()
	saplings.clear()
	sapling_serial = 0
	manure = 0.0
	placed.clear()
	flags.clear()
	warehouse.from_dict({"capacity": ProjectTable.WAREHOUSE_CAPACITY[0], "items": {}})
	# Automated runs keep an empty warehouse (like the farm built at launch).
	if not DebugTools.is_automated():
		warehouse.add(&"feed", STARTER_FEED)


func save_data() -> Dictionary:
	var inv := {}
	for id in storage:
		inv[id] = (storage[id] as Inventory).to_array()
	return {"built": built.keys().map(func(k): return String(k)), "storage": inv, "depleted": depleted,
		"stumps": stumps.duplicate(true), "saplings": saplings.duplicate(true), "sapling_serial": sapling_serial,
		"warehouse": warehouse.to_dict(), "manure": manure,
		"placed": placed.duplicate(true), "flags": flags.duplicate(true)}


func load_data(d: Dictionary) -> void:
	built.clear()
	for k in d.get("built", ["field_0"]):
		built[StringName(k)] = true
	storage.clear()
	depleted = d.get("depleted", {})
	stumps = (d.get("stumps", {}) as Dictionary).duplicate(true)
	saplings = (d.get("saplings", []) as Array).duplicate(true)
	sapling_serial = int(d.get("sapling_serial", saplings.size()))
	var inv: Dictionary = d.get("storage", {})
	for id in inv:
		var arr: Array = inv[id]
		var i := Inventory.new(arr.size())
		i.from_array(arr)
		storage[id] = i
	warehouse.from_dict({"capacity": ProjectTable.WAREHOUSE_CAPACITY[warehouse_level()],
		"items": (d.get("warehouse", {}) as Dictionary).get("items", {})})
	manure = float(d.get("manure", 0.0))
	placed = (d.get("placed", []) as Array).duplicate(true)
	# Saves from before the first-day walkthrough have no flags: their farm is lived in
	# (the door open, the table cleared, the truck unlocked).
	flags = (d.get("flags", {"legacy": true}) as Dictionary).duplicate(true)
