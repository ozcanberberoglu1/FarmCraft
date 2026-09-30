class_name LiveCrates
extends RefCounted
## Live animals in transport crates (a hen in a slatted crate, item "chicken_crate"):
## bought at the Animal Market in town (its hen stall, a pen's gate, the office hatch),
## they wait on the ground in front of the seller (the market's pickup spot, MarketCrates)
## until the farmer carries them to the pickup, ride in a truck bed, wait in the warehouse
## crate corner or go by hand, and are let out at their housing (the coop package does
## that). One crate holds one grown animal. The rules and counts shared by the market,
## the pickup spot, the bed, the warehouse, the storage screen and the story; also what
## the market wants to see on a farm before it sells a kind (market_lock).

## The player's own vehicle parked this close to where the market was opened counts as
## parked at it (Town.vehicle_at_poultry: the street in front of the Animal Market counts).
const STALL_RANGE := 32.0
## Most crates one order can hold.
const MAX_ORDER := 8
## Most crates that can wait at the market's pickup spot at once (FarmState.market_crates;
## MarketCrates shows as many).
const MAX_WAITING := 12

## The instance id of the vehicle whose bed the crates now in hand were last lifted out of
## (0: they came from somewhere else). E at that bed's tailgate lifts out more of the same
## kind (unloading); at any other bed, or with crates from the market's pickup spot or the
## warehouse, E loads them (BedPoint).
static var lifted_from := 0


## Whether `id` is a crated live animal.
static func is_live(id: StringName) -> bool:
	return AnimalTable.species_of_crate(id) != &""


## The price of one crated animal of `species` (a grown one).
static func price(species: StringName) -> int:
	return int(AnimalTable.get_species(species).get("adult_price", 0))


## The crated animal in the player's hand (&"" when the hand holds none).
static func held() -> StringName:
	var s := PlayerState.selected_stack()
	return s.item.id if s and is_live(s.item.id) else &""


# --- Counts ------------------------------------------------------------------------

## Crates of `id` (any crate when &"") at `place`: &"bed" (also &"truck": every owned
## vehicle's bed), &"warehouse", &"market" (waiting at the Animal Market's pickup spot),
## &"carried" (also &"bag": the player's bag, hotbar included), &"hand" (the selected
## slot only) or &"all".
static func count_at(place: StringName, id := &"") -> int:
	match place:
		&"bed", &"truck":
			var n := 0
			for v in _vehicles():
				n += _in_stock(v.cargo, id)
			return n
		&"warehouse":
			return _in_stock(FarmState.warehouse, id)
		&"market":
			return _in_stock(FarmState.market_crates, id)
		&"carried", &"bag":
			var n := 0
			for s in PlayerState.inventory.slots:
				if s and (s.item.id == id if id != &"" else is_live(s.item.id)):
					n += s.count
			return n
		&"hand":
			var s := PlayerState.selected_stack()
			return s.count if s and (s.item.id == id if id != &"" else is_live(s.item.id)) else 0
		&"all":
			return count_at(&"bed", id) + count_at(&"warehouse", id) + count_at(&"market", id) + count_at(&"carried", id)
	return 0


static func _in_stock(stock: Stockpile, id: StringName) -> int:
	if id != &"":
		return stock.count(id)
	var n := 0
	for e: Dictionary in stock.entries():
		if is_live(e["id"]):
			n += int(e["count"])
	return n


static func _vehicles() -> Array[Vehicle]:
	var out: Array[Vehicle] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for n in tree.get_nodes_in_group(Vehicle.GROUP):
		var v := n as Vehicle
		if v and v.owned:
			out.append(v)
	return out


# --- Buying ------------------------------------------------------------------------

## The player's own vehicle parked nearest `at` within `radius` whose bed has room.
static func vehicle_near(at: Vector3, radius := STALL_RANGE) -> Vehicle:
	var best: Vehicle = null
	var best_d := radius
	for v in _vehicles():
		if v.is_driven() or v.cargo.space() <= 0:
			continue
		var d := v.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = v
	return best


## How many more crates can be bought now: the market's pickup spot holds MAX_WAITING.
static func market_room() -> int:
	return FarmState.market_crates.space()


## The Animal Market's pickup spot, where bought crates wait (null before the town is built).
static func market_spot() -> MarketCrates:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(MarketCrates.GROUP) as MarketCrates if tree else null


## "" when the Animal Market sells `species` to this farm, else why not: the farm level
## it opens at (UnlockTable), then the building the market wants to see first
## (AnimalTable.market_needs: the closed barn before a horse...). Room and money are
## asked separately (can_buy, Animals.can_buy).
static func market_lock(species: StringName) -> String:
	var need := UnlockTable.animal_level(species)
	if Progress.level < need:
		return tr_key("UI_NEEDS_LEVEL") % [need, Progress.level]
	var project := AnimalTable.market_needs(species)
	if project != &"" and not FarmState.is_built(project):
		return tr_key("MSG_NEED_HOUSING") % tr_key("PROJECT_" + String(project).to_upper())
	return ""


## "" when `count` crated animals of `species` can be bought (the market opened at `_at`),
## else the reason. No coop is needed: the animals wait in their crates (unless the market
## asks for something first, see market_lock), as long as the pickup spot has room.
static func can_buy(species: StringName, count: int, _at: Vector3) -> String:
	if AnimalTable.crate_item(species) == &"" or count <= 0:
		return tr_key("MSG_NO_ROOM")
	var lock := market_lock(species)
	if lock != "":
		return lock
	var cost := price(species) * count
	if Economy.money < cost:
		return tr_key("MSG_NEED_GOLD") % UiTheme.money(cost - Economy.money)
	if market_room() < count:
		return tr_key("MSG_MARKET_CRATES_FULL") % count_at(&"market")
	return ""


## Buys `count` crated animals of `species` (the market opened at `at`): they are set
## down in front of the seller, at the Animal Market's pickup spot by the gate
## (FarmState.market_crates, shown by MarketCrates), for the farmer to carry to the
## pickup. Returns how many were bought.
static func buy(species: StringName, count: int, at: Vector3) -> int:
	if can_buy(species, count, at) != "":
		return 0
	var crate := AnimalTable.crate_item(species)
	if not Economy.spend(price(species) * count, "REPORT_ANIMALS"):
		return 0
	FarmState.market_crates.add(crate, count)
	Game.notify(tr_key("MSG_CRATES_WAITING") % [ItemDB.get_item(crate).display_name(), count], UiTheme.GREEN)
	var spot := market_spot()
	Audio.animal_voice(species, true, spot.global_position if spot else at, -6.0)
	Events.animals_bought.emit(species, count)
	return count


## Translates outside a node (these helpers are static).
static func tr_key(key: String) -> String:
	return String(TranslationServer.translate(key))


# --- Hands -------------------------------------------------------------------------

## Puts up to `amount` of `id` into the farmer's hands: onto the stack in hand when
## it is the same, else into the selected slot when free, else into the first free
## hotbar slot (selected); with every hotbar slot taken, what is in hand goes into the
## bag to free it (a toast says so). A crate never goes into the bag by itself: the
## tailgate loads, and the coop door lets out, only what is in hand. Nothing goes in
## when crates fill the hands already or the bag has no room for what is in hand
## (hands_full_message says which). `from`: the vehicle whose bed they were lifted out
## of (see lifted_from). Returns how many went in.
static func put_in_hand(id: StringName, amount := 1, quality := 0, from: Object = null) -> int:
	var inv := PlayerState.inventory
	var item := ItemDB.get_item(id)
	if item == null or amount <= 0:
		return 0
	var sel := PlayerState.selected
	var s := inv.get_stack(sel)
	var slot := -1
	if s and s.item.id == id and s.quality == quality and s.space_left() > 0:
		slot = sel
	elif s == null:
		slot = sel
	else:
		slot = inv.first_empty(0, PlayerState.HOTBAR_SIZE)
	if slot < 0:
		# Crates in hand stay there (they are what is being carried about).
		if is_live(s.item.id) or not _stow(sel):
			return 0
		slot = sel
	var cur := inv.get_stack(slot)
	var n := mini(amount, item.max_stack - (cur.count if cur else 0))
	if n <= 0:
		return 0
	lifted_from = from.get_instance_id() if from else 0
	if cur:
		cur.count += n
		inv.changed.emit()
	else:
		inv.set_stack(slot, ItemStack.create(id, n, quality))
	if slot != sel:
		PlayerState.select(slot)
	return n


## Why put_in_hand took nothing: crates fill the hands already (every hotbar slot taken,
## the one in hand a crate), else the bag has no room for what is in hand.
static func hands_full_message() -> String:
	return tr_key("MSG_HANDS_FULL_CRATES") if held() != &"" else tr_key("MSG_INVENTORY_FULL")


## Moves the stack in hotbar slot `slot` into the bag (the slots past the hotbar) to
## free the hands for a crate, with a toast saying where it went. False, and nothing
## moved, when the bag has no room for all of it.
static func _stow(slot: int) -> bool:
	var inv := PlayerState.inventory
	var s := inv.get_stack(slot)
	if s == null:
		return true
	var room := 0
	for i in range(PlayerState.HOTBAR_SIZE, inv.size()):
		var b := inv.get_stack(i)
		if b == null:
			room += s.item.max_stack
		elif b.can_merge(s):
			room += b.space_left()
	if room < s.count:
		return false
	inv.set_stack(slot, null)
	inv.add_stack(s, PlayerState.HOTBAR_SIZE)
	Game.notify(tr_key("MSG_STOWED_FOR_CRATE") % s.item.display_name())
	return true
