class_name Catalog
extends Node
## Yeşilova Market by post: the grocer's catalogue (Mail owns it, Mail.catalog, and saves
## it with the letters).
##
## The morning after a mailbox first stands on the farm (at POST_MINUTE, the hour the post
## comes) Hasan the grocer writes: his catalogue is in the envelope. From then on the
## mailbox's screen has a second page (LetterScreen: CatalogPage) listing the market's
## everyday goods at the market's prices (goods(): what the town market stocks today, so
## seeds follow the season and anything a later round puts on its shelves shows up too;
## never animals, tools, kits or the one-off things: sells()). The farmer writes an order
## (up to MAX_KINDS kinds, a stack of each at most), pays for it on the spot (the goods plus
## FEE for the road) and can call it off for his money back until midnight. One order is
## open at a time.
##
## At POST_MINUTE the next morning the goods stand in a wooden crate beside the mailbox
## (DeliveryCrate; under a tarp when it rains): its flag is up and a note says so. E on the
## crate takes into the bag whatever fits; the rest waits in the crate, which goes once it
## is empty. An order written after midnight (the clock runs to 02:00 before the farmer
## sleeps) misses the round and comes the morning after. A crate still waiting takes the
## next delivery too.
##
## What keeps town worth the drive: the fee, nothing special in the catalogue, and selling
## is still done at the counter or the bin. CatalogGoals (goals) teaches it beside the
## story. Automated runs keep the catalogue away unless the run asks for it (`--catalog`,
## or `testing`).

## An order was written, called off or delivered, the crate was opened, or the catalogue came.
signal changed

## Dollars added to every order for the road.
const FEE := 3
## The post comes at this minute of the morning: the catalogue's letter, an order's crate.
const POST_MINUTE := 6 * 60 + 30
## Kinds of goods one order (one crate) takes; of each, a full stack at most (99 at most).
const MAX_KINDS := 8
const MAX_EACH := 99
## Who writes (the market's grocer), and the ledger's line for orders and refunds.
const SENDER := "PERSON_SHOPKEEPER"
const REASON := "REPORT_CATALOG"
## Not for the post: tools, keys, animals (their crates), things put down or built from a
## kit, gifts and fresh produce, vehicles; and the one-off buys.
const SKIP_CATEGORIES: Array[String] = ["tool", "key", "animal", "placeable", "gift", "animal_product", "vehicle", "kit", "story"]
const SKIP_ITEMS: Array[StringName] = [&"dog_ball"]
## The order the catalogue's pages run in (by item category; the rest after, as the market
## shelves them).
const PAGE_ORDER: Array[String] = ["feed", "seed", "supply", "material", "resource", "bait", "pet"]
const COLOR := Color("e2b877")
## Where the crate is set down, in the mailbox's frame (its door to +Z): to one side or
## the other (the free one further from the front door, out of the way), else in front or
## behind.
const CRATE_SPOTS: Array[Vector3] = [Vector3(-0.85, 0.0, 0.1), Vector3(0.85, 0.0, 0.1), Vector3(0.0, 0.0, 0.95), Vector3(0.0, 0.0, -0.95)]
const POLL := 1.0

## Saved: the day a mailbox first stood (0: none yet); the catalogue has come; the open
## order ({}: none; else {items: {id: count}, paid, day (written), due (the day it comes)});
## the crate waiting by the mailbox ({}: none; else {items, pos, yaw, day, seen (opened
## once), tarp}); how many orders were written, delivered, and crates opened.
var mailbox_day := 0
var arrived := false
var order := {}
var crate := {}
var placed := 0
var delivered := 0
var collected := 0
## Set by tests: the catalogue comes in this automated run.
var testing := false
## The quiet side goals that teach it.
var goals: CatalogGoals

var _node: DeliveryCrate
var _poll := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	goals = CatalogGoals.new()
	goals.name = "CatalogGoals"
	goals.catalog = self
	add_child(goals)
	Events.day_started.connect(func(_d: int) -> void: _poll = 0.0)
	Events.placed.connect(func(_id: StringName) -> void: _poll = 0.0)


## The catalogue is in this run (always in play; automated runs only when asked).
func enabled() -> bool:
	return testing or not DebugTools.is_automated() or DebugTools.args.has("catalog")


## Minutes since the first midnight, by the farmer's days (the clock runs past 24:00 until
## he sleeps: such a night still belongs to its day).
static func now() -> float:
	return GameClock.day * 1440.0 + GameClock.minute


## "06:30": the hour the post comes.
static func post_time() -> String:
	return "%02d:%02d" % [POST_MINUTE / 60, POST_MINUTE % 60]


## The catalogue has come and a mailbox stands: orders can be written (the mailbox screen
## shows its page).
func available() -> bool:
	return arrived and Mail.has_mailbox()


# --- The goods ---------------------------------------------------------------------------------

## Whether the catalogue lists `id`: an everyday thing with a price, open at the farm's level.
static func sells(id: StringName) -> bool:
	if not ItemDB.has_item(id) or id in SKIP_ITEMS:
		return false
	var item := ItemDB.get_item(id)
	if item.buy_price <= 0 or item.category in SKIP_CATEGORIES or item.has_durability() or item.water_capacity > 0:
		return false
	if LiveCrates.is_live(id) or PlaceableTable.is_placeable(id):
		return false
	return UnlockTable.item_level(id) <= Progress.level


## What the catalogue lists today: the town market's shelves (ShopStock.town_market), less
## what the post doesn't carry, a page (category) at a time.
func goods() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in ShopStock.town_market().get("stock", []):
		if sells(StringName(id)) and StringName(id) not in out:
			out.append(StringName(id))
	var shelf := out.duplicate()
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		var pa := _page(a)
		var pb := _page(b)
		return pa < pb if pa != pb else shelf.find(a) < shelf.find(b))
	return out


static func _page(id: StringName) -> int:
	var p := PAGE_ORDER.find(ItemDB.get_item(id).category)
	return p if p >= 0 else PAGE_ORDER.size()


## One unit's price (the market's own).
static func price(id: StringName) -> int:
	return Economy.buy_price(id)


## The most of `id` one order takes.
static func max_count(id: StringName) -> int:
	return mini(ItemDB.get_item(id).max_stack, MAX_EACH) if ItemDB.has_item(id) else 0


## What the goods of `items` ({id: count}) cost, without the fee.
static func goods_cost(items: Dictionary) -> int:
	var sum := 0
	for id: Variant in items:
		sum += price(StringName(id)) * int(items[id])
	return sum


## What an order of `items` costs at the mailbox: the goods and the fee.
static func total(items: Dictionary) -> int:
	return goods_cost(items) + FEE


## `items` as an order keeps them: {String id: count}, only what the catalogue lists, each
## within its limit.
func _clean(items: Dictionary) -> Dictionary:
	var out := {}
	var listed := goods()
	for id: Variant in items:
		var n := mini(int(items[id]), max_count(StringName(id)))
		if n > 0 and StringName(id) in listed:
			out[String(id)] = n
	return out


## Why an order of `items` can't be written now ("": it can): "open" (one is on its way),
## "empty", "kinds" (more than MAX_KINDS), "money".
func order_error(items: Dictionary) -> String:
	if not order.is_empty():
		return "open"
	var clean := _clean(items)
	if clean.is_empty():
		return "empty"
	if clean.size() > MAX_KINDS:
		return "kinds"
	if not Economy.can_afford(total(clean)):
		return "money"
	return ""


# --- Orders ------------------------------------------------------------------------------------

## The day an order written now comes (at POST_MINUTE): tomorrow, or the day after for one
## written past midnight.
static func due_day() -> int:
	return GameClock.day + (2 if GameClock.minute >= 1440.0 else 1)


## Writes the order: `items` ({id: count}) paid for now (goods and fee). False: it can't be
## (order_error).
func place_order(items: Dictionary) -> bool:
	if not available() or order_error(items) != "":
		return false
	var clean := _clean(items)
	var cost := total(clean)
	if not Economy.spend(cost, REASON):
		return false
	order = {"items": clean, "paid": cost, "day": GameClock.day, "due": due_day()}
	placed += 1
	# The first order ever is the side goal's doing: its done line says when it comes.
	var line := tr("MSG_CATALOG_ORDERED") if int(order["due"]) == GameClock.day + 1 else tr("MSG_CATALOG_ORDERED_LATE")
	if not goals.note_order(line):
		Game.notify(line, COLOR)
		Audio.ui("confirm", -6.0)
	_poll = 0.0
	changed.emit()
	return true


## The open order can still be called off: until the midnight before its morning.
func can_cancel() -> bool:
	return not order.is_empty() and now() < float(order["due"]) * 1440.0


## Calls the open order off: its money back. False once it is on its way.
func cancel_order() -> bool:
	if not can_cancel():
		return false
	var back := int(order.get("paid", 0))
	order = {}
	Economy.add_money(back, REASON)
	Game.notify(tr("MSG_CATALOG_CANCELLED") % UiTheme.money(back), COLOR)
	changed.emit()
	return true


## Mornings from today to the open order's ("this morning" 0, "tomorrow" 1, the one after 2;
## for an order that would be written now when none is open).
func mornings_left() -> int:
	return maxi((int(order["due"]) if not order.is_empty() else due_day()) - GameClock.day, 0)


## A crate stands by the mailbox with goods in it.
func has_crate() -> bool:
	return not crate.is_empty() and not (crate.get("items", {}) as Dictionary).is_empty()


## A delivery the farmer hasn't looked into yet (the mailbox's flag stays up for it).
func crate_waiting() -> bool:
	return has_crate() and not bool(crate.get("seen", false))


## The crate's node (null: none stands).
func crate_node() -> DeliveryCrate:
	return _node if _node != null and is_instance_valid(_node) and not _node.is_queued_for_deletion() else null


## What waits in the crate: {StringName id: count}.
func crate_items() -> Dictionary:
	var out := {}
	if has_crate():
		for id: Variant in crate["items"]:
			out[StringName(id)] = int(crate["items"][id])
	return out


## E on the crate: everything that fits goes into the bag, the rest waits; the crate goes
## once it is empty. Returns what was taken ({StringName id: count}).
func take_delivery() -> Dictionary:
	var taken := {}
	if not has_crate():
		return taken
	var items: Dictionary = crate["items"]
	for id: Variant in items.keys():
		var n := int(items[id])
		var left := PlayerState.inventory.add_item(StringName(id), n) if ItemDB.has_item(StringName(id)) else 0
		if n - left > 0:
			taken[StringName(id)] = n - left
			# Bought, like goods carried off the counter (the story counts purchases).
			Events.item_bought.emit(StringName(id), n - left)
		if left > 0:
			items[id] = left
		else:
			items.erase(id)
	crate["seen"] = true
	if not taken.is_empty():
		collected += 1
	if items.is_empty():
		crate = {}
	changed.emit()
	Mail.letters_changed.emit()
	return taken


func _process(delta: float) -> void:
	if SaveGame.loading or Game.player == null or not is_instance_valid(Game.player):
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	update()


## The post's round: notes the mailbox's first day, sends the catalogue the morning after,
## sets an order due down by the mailbox; keeps the crate's node standing.
func update() -> void:
	_sync_crate()
	if not enabled() or not Mail.has_mailbox():
		return
	if mailbox_day <= 0:
		mailbox_day = GameClock.day
	if not arrived and now() >= (mailbox_day + 1) * 1440.0 + POST_MINUTE:
		arrived = true
		Mail.send(SENDER, "CATALOG_TITLE", "MAIL_CATALOG_BODY", {}, {"fee": UiTheme.money(FEE), "time": post_time()})
		changed.emit()
	if not order.is_empty() and now() >= float(order["due"]) * 1440.0 + POST_MINUTE:
		_deliver()


## The open order's goods into a crate beside the mailbox (into the one still waiting there).
func _deliver() -> void:
	var box := mailbox()
	if box == null:
		return
	if not has_crate():
		var spot := crate_spot(box)
		crate = {"items": {}, "pos": spot.origin, "yaw": spot.basis.get_euler().y, "day": GameClock.day}
	var items: Dictionary = crate["items"]
	for id: Variant in order["items"]:
		items[String(id)] = int(items.get(String(id), 0)) + int(order["items"][id])
	crate["seen"] = false
	crate["tarp"] = Weather.is_precipitating()
	order = {}
	delivered += 1
	if crate_node() != null:
		_node.queue_free()
	_node = null
	_sync_crate()
	Game.notify(tr("MSG_CATALOG_DELIVERED"), COLOR)
	Audio.ui("notify", -8.0)
	changed.emit()
	Mail.letters_changed.emit()


## The mailbox the post comes to (null: none stands in the world).
func mailbox() -> Mailbox:
	return get_tree().get_first_node_in_group(Mailbox.GROUP) as Mailbox


## Where the crate is set down beside `box`: the free one of CRATE_SPOTS' two sides that
## is further from the house's front door (never in the way to it), else the first of the
## others nothing stands in; on the ground there, a little askew.
func crate_spot(box: Node3D) -> Transform3D:
	var space := box.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = GameClock.day * 131 + 7
	var basis := Basis(Vector3.UP, box.global_rotation.y + rng.randf_range(-0.14, 0.14))
	var skip: Array[RID] = []
	if Game.player is CollisionObject3D:
		skip.append((Game.player as CollisionObject3D).get_rid())
	var house := get_tree().get_first_node_in_group(&"farm_house") as FarmHouse
	var door := house.door_point() if house else Vector3.INF
	var first := Vector3.INF
	var best := Vector3.INF
	var best_d := -1.0
	for i in CRATE_SPOTS.size():
		# The two sides are looked at together; in front and behind only when neither is free.
		if i >= 2 and best != Vector3.INF:
			break
		var at := box.global_transform * CRATE_SPOTS[i]
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 1.2, 0.0), at - Vector3(0.0, 1.5, 0.0), 1)
		ray.exclude = skip
		var hit := space.intersect_ray(ray)
		at.y = (hit["position"] as Vector3).y if not hit.is_empty() else box.global_position.y
		if first == Vector3.INF:
			first = at
		# Free: the ground is about level with the mailbox's foot and nothing solid stands there.
		if absf(at.y - box.global_position.y) > 0.45:
			continue
		var probe := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = DeliveryCrate.SIZE * Vector3(1.0, 0.6, 1.0)
		probe.shape = shape
		probe.transform = Transform3D(basis, at + Vector3(0.0, DeliveryCrate.SIZE.y * 0.6, 0.0))
		probe.collision_mask = 1
		probe.exclude = skip
		if not space.intersect_shape(probe, 1).is_empty():
			continue
		var d := Vector2(at.x - door.x, at.z - door.z).length() if door != Vector3.INF else 0.0
		if d > best_d:
			best = at
			best_d = d
	return Transform3D(basis, best if best != Vector3.INF else first)


## The crate's node stands while goods wait in it (built again after a load).
func _sync_crate() -> void:
	if not has_crate():
		return
	if crate_node() != null and _node.is_inside_tree():
		return
	if Game.world == null or not is_instance_valid(Game.world) or not Game.world.is_inside_tree():
		return
	_node = DeliveryCrate.new()
	_node.catalog = self
	_node.tarp = bool(crate.get("tarp", false)) and not bool(crate.get("seen", false))
	_node.opened = bool(crate.get("seen", false))
	Game.world.add_child(_node)
	_node.global_transform = Transform3D(Basis(Vector3.UP, float(crate.get("yaw", 0.0))), crate["pos"])
	_node.reset_physics_interpolation()


# --- Save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"mailbox_day": mailbox_day, "arrived": arrived, "order": order.duplicate(true), "crate": crate.duplicate(true),
		"placed": placed, "delivered": delivered, "collected": collected, "goals": goals.save_data()}


func load_data(data: Dictionary) -> void:
	mailbox_day = int(data.get("mailbox_day", 0))
	arrived = bool(data.get("arrived", false))
	order = (data.get("order", {}) as Dictionary).duplicate(true)
	crate = (data.get("crate", {}) as Dictionary).duplicate(true)
	placed = int(data.get("placed", 0))
	delivered = int(data.get("delivered", 0))
	collected = int(data.get("collected", 0))
	if _node != null and is_instance_valid(_node):
		_node.queue_free()
	_node = null
	goals.load_data(data.get("goals", {}))
	_poll = 0.0
	changed.emit()
