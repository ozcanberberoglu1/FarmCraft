class_name LiveCrates
extends RefCounted
## Live animals in transport crates (a hen in a slatted crate, item "chicken_crate"):
## bought at the Animal Market in town (its hen stall, a pen's gate, the office hatch),
## they come straight into the farmer's hands and bag (buy); only what doesn't fit waits
## on the ground in front of the seller (the market's pickup spot, MarketCrates) until
## it is fetched. They ride in a truck bed, wait in the warehouse crate corner or go by
## hand, and are let out at their housing (the coop package does that). One crate holds
## one grown animal. The rules and counts shared by the market, the pickup spot, the bed,
## the warehouse, the storage screen and the story; also what the market wants to see on
## a farm before it sells a kind (market_lock), and what the story's first days keep it
## from selling (story_lock).

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


## How many more crates the market's pickup spot takes (it holds MAX_WAITING): the room
## for what the hands and the bag can't carry.
static func market_room() -> int:
	return FarmState.market_crates.space()


## How many more crates of `crate` the farmer can carry: the room on the stacks of it in
## the bag (hotbar included) and a stack's worth for every free slot.
static func carry_room(crate: StringName) -> int:
	var item := ItemDB.get_item(crate)
	if item == null:
		return 0
	var n := 0
	for s in PlayerState.inventory.slots:
		if s == null:
			n += item.max_stack
		elif s.item.id == crate and s.quality == 0:
			n += s.space_left()
	return n


## How many crates of `crate` one order can take now: what the farmer carries and what
## the pickup spot still takes.
static func buy_room(crate: StringName) -> int:
	return carry_room(crate) + market_room()


## The Animal Market's pickup spot, where bought crates wait (null before the town is built).
static func market_spot() -> MarketCrates:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(MarketCrates.GROUP) as MarketCrates if tree else null


## "" when the Animal Market sells `species` to this farm, else why not: the farm level
## it opens at (UnlockTable), then the story (story_lock: hens only at first), then the
## building the market wants to see first (AnimalTable.market_needs: the closed barn
## before a horse...). Room and money are asked separately (can_buy, Animals.can_buy).
static func market_lock(species: StringName) -> String:
	var need := UnlockTable.animal_level(species)
	if Progress.level < need:
		return tr_key("UI_NEEDS_LEVEL") % [need, Progress.level]
	var story := story_lock(species)
	if story != "":
		return story
	var project := AnimalTable.market_needs(species)
	if project != &"" and not FarmState.is_built(project):
		return tr_key("MSG_NEED_HOUSING") % tr_key("PROJECT_" + String(project).to_upper())
	return ""


## Why the story keeps the Animal Market from selling `species` yet ("" when it doesn't):
## until the rooster's own goal comes up (Quests "rooster_buy") the market sells hens
## only, so the first days' money can't go on a bird the story doesn't count. A farm with
## the story done or skipped buys what it likes.
static func story_lock(species: StringName) -> String:
	if species == &"chicken" or Quests.tutorial_done() or Quests.step >= Quests.index_of("rooster_buy"):
		return ""
	return tr_key("MARKET_LOCK_STORY")


## "" when `count` crated animals of `species` can be bought (the market opened at `_at`),
## else the reason. No coop is needed: the animals wait in their crates (unless the market
## asks for something first, see market_lock), as long as the farmer can carry them or
## the pickup spot has room for the rest.
static func can_buy(species: StringName, count: int, _at: Vector3) -> String:
	var crate := AnimalTable.crate_item(species)
	if crate == &"" or count <= 0:
		return tr_key("MSG_NO_ROOM")
	var lock := market_lock(species)
	if lock != "":
		return lock
	var cost := price(species) * count
	if Economy.money < cost:
		return tr_key("MSG_NEED_GOLD") % UiTheme.money(cost - Economy.money)
	if buy_room(crate) < count:
		return tr_key("MSG_MARKET_CRATES_FULL") % count_at(&"market")
	return ""


## Buys `count` crated animals of `species` (the market opened at `at`): they come
## straight to the farmer, into the hands first (put_in_hand) and then the bag; only what
## fits in neither is set down in front of the seller, at the Animal Market's pickup spot
## by the gate (FarmState.market_crates, shown by MarketCrates), and a toast says so.
## Returns how many were bought.
static func buy(species: StringName, count: int, at: Vector3) -> int:
	if can_buy(species, count, at) != "":
		return 0
	var crate := AnimalTable.crate_item(species)
	if not Economy.spend(price(species) * count, "REPORT_ANIMALS"):
		return 0
	var carried := put_in_hand(crate, count)
	if carried < count:
		carried += (count - carried) - PlayerState.inventory.add_item(crate, count - carried)
	var left := count - carried
	if left > 0:
		FarmState.market_crates.add(crate, left)
	var crate_name := ItemDB.get_item(crate).display_name()
	if carried > 0:
		Game.notify(tr_key("MSG_CRATES_BOUGHT") % [crate_name, carried], UiTheme.GREEN)
	if left > 0:
		Game.notify(tr_key("MSG_CRATES_OVERFLOW") % left, UiTheme.GOLD)
	var spot := market_spot()
	Audio.animal_voice(species, true, spot.global_position if spot and left > 0 else at, -6.0)
	Events.animals_bought.emit(species, count)
	return count


## Translates outside a node (these helpers are static).
static func tr_key(key: String) -> String:
	return String(TranslationServer.translate(key))


# --- Selling his own birds ---------------------------------------------------------
#
# A grown hen or rooster of his own is sold in two steps: "Sell" on the bird's card (F)
# asks once and puts it into a crate in the bag (crate_up), the same crate a bought one
# comes in, with who it is inside (Animals.crated); the Animal Market's dealer then buys
# crated birds out of the bag (sale_offers, sell_offer), paid at once. A change of mind:
# the crate opens at a coop door like any other and the same bird comes out
# (Animals.release). Crates are all alike, so with bought birds and his own in crates at
# once, his own come out first (the one crated last before the others) and are the ones
# the dealer names.
#
# The price is the bird's value on its card (AnimalData.sale_value: the table's "value",
# its health and happiness, 4% more a heart): a hen $38 the day she was bought and up
# to $48, a rooster $52 up to $66, always under what the market asks ($50, $70). A crate
# never opened sells at the fresh bird's price. The carnival's double pay is not for
# livestock (as for the dealer's other sales; it would make buying and selling pay).
#
# The story's birds stay: while a goal ahead still counts hens (up to the first egg in
# the bin: STORY_HENS_UNTIL) two must be left, crated or not, and one rooster until he
# is in the coop (STORY_ROOSTER_UNTIL); neither the card nor the dealer takes one below
# that (story_block).
#
# The dealer buys out of the bag only: a crate of his own bird set down in a pickup's bed
# or the warehouse keeps its bird (Animals.crated_of counts crates anywhere), the side goal
# stays up for it, and the dealer's list says to bring it (RancherScreen: RANCHER_CRATE_LEFT).
# With wolves on the farm no bird goes into a crate (wolves_about).

## The story's last goal that needs the first hens (the first egg shipped), how many of
## them, and the last one that needs the rooster.
const STORY_HENS_UNTIL := "ship_egg"
const STORY_HENS := 2
const STORY_ROOSTER_UNTIL := "rooster_in"
## FarmState.flags: he has been told once where a crated bird is sold.
const SELL_TOLD_FLAG := "sell_bird_told"


## How many birds of `species` the story's goals ahead still need (0: none).
static func story_needs(species: StringName) -> int:
	if Quests.tutorial_done():
		return 0
	if species == &"chicken":
		return STORY_HENS if Quests.step <= Quests.index_of(STORY_HENS_UNTIL) else 0
	if species == &"rooster":
		return 1 if Quests.step <= Quests.index_of(STORY_ROOSTER_UNTIL) else 0
	return 0


## His grown birds of `species`: living on the farm and in crates anywhere.
static func birds_owned(species: StringName) -> int:
	var n := count_at(&"all", AnimalTable.crate_item(species))
	for a in Animals.animals:
		if a.species == species and a.adult:
			n += 1
	return n


## Why the story keeps one more bird of `species` from being sold ("" when it doesn't).
static func story_block(species: StringName) -> String:
	var need := story_needs(species)
	if need <= 0 or birds_owned(species) > need:
		return ""
	return tr_key("SELL_NO_STORY_ROOSTER" if species == &"rooster" else "SELL_NO_STORY_HENS")


## "" when his bird `a` can go into a crate to be sold, else the line that says why not:
## a chick, one away at the vet, hurt or sick, in his arms, wolves on the farm, a hen with
## chicks at her heels or sitting on her nest, the story's own birds (story_block), no room
## in the bag.
static func crate_block(a: AnimalData) -> String:
	if a == null or not Animals.animals.has(a) or not AnimalTable.is_poultry(a.species):
		return tr_key("SELL_NO_KIND")
	if not a.adult:
		return tr_key("SELL_NO_CHICK") % a.name
	if a.at_vet():
		return tr_key("SELL_NO_VET") % a.name
	if a.injured() or a.sick:
		return tr_key("SELL_NO_HURT") % a.name
	var n := Animals.node_of(a)
	if n and (n.carried or n.led or n.ridden):
		return tr_key("SELL_NO_CARRIED") % a.name
	# Wolves on the farm: no bird is whisked out of their reach through its card (the
	# coop's door, the fire and the knife are for that).
	if wolves_about():
		return tr_key("SELL_NO_WOLVES") % a.name
	if not Animals.chicks_of(a).is_empty():
		return tr_key("SELL_NO_MOTHER") % a.name
	if n and n.on_nest():
		return tr_key("SELL_NO_NEST") % a.name
	var story := story_block(a.species)
	if story != "":
		return story
	if carry_room(AnimalTable.crate_item(a.species)) <= 0:
		return tr_key("SELL_NO_ROOM")
	return ""


## Whether wolves are out on the farm now (WolfRaids: the pack has come and not left yet).
static func wolves_about() -> bool:
	return not WolfRaids.wolves().is_empty()


## Puts his bird `a` into a crate, into the hands or the bag like a bought one (the
## card's "Sell", once he has said yes). The first time, a line says where it is sold.
## False, and nothing done, when crate_block has a reason.
static func crate_up(a: AnimalData) -> bool:
	if crate_block(a) != "":
		return false
	var crate := AnimalTable.crate_item(a.species)
	if not Animals.crate(a):
		return false
	if put_in_hand(crate, 1) < 1 and PlayerState.inventory.add_item(crate, 1) > 0:
		# (Room was asked for above: never.) Back where she was.
		Animals.uncrate(a, Animals.home_for(a.species))
		return false
	Game.notify(tr_key("MSG_BIRD_CRATED") % a.name, UiTheme.GOLD_SOFT)
	if not bool(FarmState.flags.get(SELL_TOLD_FLAG, false)):
		FarmState.flags[SELL_TOLD_FLAG] = true
		Game.notify(tr_key("HINT_SELL_BIRD"), UiTheme.GOLD)
	return true


## What the dealer pays for crated bird `a`.
static func sale_price(a: AnimalData) -> int:
	return a.sale_value()


## What he pays for a bought bird of `species` still in the crate it came in.
static func fresh_price(species: StringName) -> int:
	var a := AnimalData.new()
	a.species = species
	a.adult = true
	a.affection = 100.0
	return a.sale_value()


## His own crated birds in the bag now (oldest first): no more of a kind than the bag
## holds crates of it.
static func own_in_bag() -> Array[AnimalData]:
	var out: Array[AnimalData] = []
	if Animals.crated.is_empty():
		return out
	for sp: StringName in AnimalTable.POULTRY:
		var own := Animals.crated_of(sp)
		var carried := count_at(&"carried", AnimalTable.crate_item(sp))
		out.append_array(own.slice(maxi(own.size() - carried, 0)))
	return out


## The crated birds the dealer can buy out of the bag, his own first (named), then the
## bought ones never let out: [{species, bird (AnimalData; null for a bought one), name,
## price, why ("" or the story's line)}].
static func sale_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own := own_in_bag()
	for sp: StringName in AnimalTable.POULTRY:
		var why := story_block(sp)
		var named := 0
		for a in own:
			if a.species == sp:
				named += 1
				out.append({"species": sp, "bird": a, "name": a.name, "price": sale_price(a), "why": why})
		for i in count_at(&"carried", AnimalTable.crate_item(sp)) - named:
			out.append({"species": sp, "bird": null, "name": Animals.species_name(sp), "price": fresh_price(sp), "why": why})
	return out


## The dealer buys the crated bird of `offer` (one of sale_offers) out of the bag, paid at
## once. Returns what he paid (0, and nothing done, when the story keeps the bird or its
## crate is no longer in the bag).
static func sell_offer(offer: Dictionary) -> int:
	var sp: StringName = offer.get("species", &"")
	var crate := AnimalTable.crate_item(sp)
	var bird: AnimalData = offer.get("bird")
	if crate == &"" or story_block(sp) != "" or PlayerState.inventory.count_item(crate) <= 0:
		return 0
	if bird != null and not Animals.crated.has(bird):
		return 0
	var pay := sale_price(bird) if bird != null else fresh_price(sp)
	PlayerState.inventory.remove_item(crate, 1)
	Economy.add_money(pay, "REPORT_ANIMALS")
	if bird != null:
		Animals.crated_sold(bird)
		Game.notify(tr_key("MSG_BIRD_SOLD") % [bird.name, UiTheme.money(pay)], UiTheme.GOLD_SOFT)
	else:
		Animals.changed.emit()
		Game.notify("+" + UiTheme.money(pay), UiTheme.GOLD_SOFT)
	return pay


## Where the Animal Market's dealer serves (his hatch), for the side goal's dot; null
## before the town is built.
static func dealer_point() -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	var town := tree.get_first_node_in_group(&"town") as Town if tree else null
	if town == null or town.market_office == null or not town.market_office.is_inside_tree():
		return null
	return town.market_office.global_position + Vector3(0, 1.1, 0)


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
