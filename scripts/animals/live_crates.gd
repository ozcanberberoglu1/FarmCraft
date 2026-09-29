class_name LiveCrates
extends RefCounted
## Live animals in transport crates (a hen in a slatted crate, item "chicken_crate"):
## bought at the poultry stall in town, they ride in a truck bed, wait in the
## warehouse crate corner or go by hand, and are let out at their housing (the coop
## package does that). One crate holds one grown animal. The rules and counts shared
## by the stall, the bed, the warehouse, the storage screen and the story.

## A bought crate goes into the bed of the player's own vehicle parked this close to
## the stall (the street in front and the market lot both count), else into the bag.
const STALL_RANGE := 32.0
## Most crates one order can hold.
const MAX_ORDER := 8


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
## vehicle's bed), &"warehouse", &"carried" (also &"bag": the player's bag, hotbar
## included), &"hand" (the selected slot only) or &"all".
static func count_at(place: StringName, id := &"") -> int:
	match place:
		&"bed", &"truck":
			var n := 0
			for v in _vehicles():
				n += _in_stock(v.cargo, id)
			return n
		&"warehouse":
			return _in_stock(FarmState.warehouse, id)
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
			return count_at(&"bed", id) + count_at(&"warehouse", id) + count_at(&"carried", id)
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


## How many crates of `id` still fit in the bag (stacks with room, then empty slots).
static func bag_room(id: StringName) -> int:
	var item := ItemDB.get_item(id)
	if item == null:
		return 0
	var n := 0
	for s in PlayerState.inventory.slots:
		if s == null:
			n += item.max_stack
		elif s.item.id == id:
			n += s.space_left()
	return n


## How many crates bought at `at` can be taken away: the bed of a vehicle parked
## there, else the bag.
static func room_at(species: StringName, at: Vector3) -> int:
	var v := vehicle_near(at)
	if v:
		return v.cargo.space()
	return bag_room(AnimalTable.crate_item(species))


## "" when `count` crated animals of `species` can be bought at `at`, else the reason.
## No building is needed: the animals wait in their crates.
static func can_buy(species: StringName, count: int, at: Vector3) -> String:
	if AnimalTable.crate_item(species) == &"" or count <= 0:
		return tr_key("MSG_NO_ROOM")
	var cost := price(species) * count
	if Economy.money < cost:
		return tr_key("MSG_NEED_GOLD") % UiTheme.money(cost - Economy.money)
	if room_at(species, at) < count:
		return tr_key("MSG_CRATES_NO_ROOM")
	return ""


## Buys `count` crated animals of `species` at `at`: they go into the bed of the
## player's vehicle parked there (dropping in one after another), else into the bag.
## Returns how many were bought.
static func buy(species: StringName, count: int, at: Vector3) -> int:
	if can_buy(species, count, at) != "":
		return 0
	var crate := AnimalTable.crate_item(species)
	if not Economy.spend(price(species) * count, "REPORT_ANIMALS"):
		return 0
	var v := vehicle_near(at)
	var what := ItemDB.get_item(crate).display_name()
	if v:
		# The bed announces the crates coming aboard (Events.crate_stored, "bed").
		v.cargo.add(crate, count)
		Game.notify(tr_key("MSG_CRATES_IN_BED") % [what, count, v.display_name()], UiTheme.GREEN)
		Audio.animal_voice(species, true, v.global_position, -6.0)
	else:
		var left := PlayerState.inventory.add_item(crate, count)
		if left > 0:
			# can_buy counted the room: only a race could leave some over. Refund it.
			Economy.add_money(price(species) * left, "REPORT_ANIMALS")
		Game.notify(tr_key("MSG_CRATES_IN_BAG") % [what, count - left], UiTheme.GREEN)
		count -= left
	Events.animals_bought.emit(species, count)
	return count


## Translates outside a node (these helpers are static).
static func tr_key(key: String) -> String:
	return String(TranslationServer.translate(key))


# --- Hands -------------------------------------------------------------------------

## Puts up to `amount` of `id` into the farmer's hands: onto the stack in hand when
## it is the same, else into the selected slot when free, else into the first free
## hotbar slot (selected), else into the bag. Returns how many went in.
static func put_in_hand(id: StringName, amount := 1, quality := 0) -> int:
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
		return amount - inv.add_item(id, amount, quality)
	var cur := inv.get_stack(slot)
	var n := mini(amount, item.max_stack - (cur.count if cur else 0))
	if n <= 0:
		return 0
	if cur:
		cur.count += n
		inv.changed.emit()
	else:
		inv.set_stack(slot, ItemStack.create(id, n, quality))
	if slot != sel:
		PlayerState.select(slot)
	return n
