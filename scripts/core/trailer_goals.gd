class_name TrailerGoals
extends RefCounted
## The barn chapter's lesson with Grandpa's stock trailer (Trailer, TrailerYard), as the
## story's goals see it (Quests: checks "trailer:<what>", places "trailer:<where>"):
##   trailer_get    pay Kemal the tyre bill for the trailer at the dealership ("owned");
##   trailer_hitch  stop the pickup near it and hitch it at its tongue, wheeled over by
##                  hand while it is empty ("hitched");
##   sheep_buy      a sheep from the Animal Market ("sheep_owned");
##   sheep_load     the rope on it (G), up the ramp (E), the gate shut ("sheep_loaded");
##   sheep_ride     home to the farm ("sheep_at_farm");
##   sheep          into the barn's pen ("sheep_home").
## Every check also reads true once the farm is past it (a sheep at home passes them
## all: a sheep the dealer brought, or bought before the lesson), so the chain never
## stalls; and every place comes with the line that says which key does it. A save from
## before the trailer came into the story that stood on "sheep" with none bought goes
## back to the lesson's start (_unload_place).

## How near the farmyard counts as back at the farm (m, from the warehouse's door).
const FARM_NEAR := 70.0


## How far the check `what` is along (1: done).
static func progress(what: String) -> int:
	var stock := Trailer.of_kind(&"trailer_stock")
	match what:
		"owned":
			return 1 if stock != null and stock.owned else 0
		"hitched":
			return 1 if stock != null and stock.owned and stock.tow != null else 0
		"sheep_owned":
			return 1 if not _sheep().is_empty() else 0
		"sheep_loaded":
			return 1 if not _sheep_aboard(true).is_empty() else 0
		"sheep_at_farm":
			for a in _sheep_aboard(false):
				var t := Trailer.carrying(a)
				if t != null and _flat(t.global_position, _farmyard()) < FARM_NEAR:
					return 1
			return 1 if _sheep_home() else 0
		"sheep_home":
			return 1 if _sheep_home() else 0
	return 0


## Where the dot points for the place `where` and the line under the goal: {"at", "hint"}.
static func place(where: String) -> Dictionary:
	var stock := Trailer.of_kind(&"trailer_stock")
	var p := Game.player as Player
	if stock == null or not is_instance_valid(p):
		return {"at": null, "hint": ""}
	match where:
		"get":
			# Short of the tyre bill: how much, and where to earn it.
			if Economy.money < stock.price:
				return Quests.money_short(stock.price)
			return {"at": stock.waypoint_roof(), "hint": _t("HINT_TRAILER_GET") % UiTheme.money(stock.price)}
		"hitch":
			return _hitch_place(stock, p)
		"load":
			return _load_place(stock, p)
		"ride":
			if p.driving == null and stock.tow != null and _flat(p.global_position, stock.tow.global_position) > 10.0:
				return {"at": stock.tow.waypoint_roof(), "hint": _t("HINT_SHEEP_DRIVE")}
			return {"at": Quests.place_for("home")["at"], "hint": _t("HINT_SHEEP_DRIVE")}
		"unload":
			return _unload_place(stock, p)
	return {"at": null, "hint": ""}


static func _hitch_place(stock: Trailer, p: Player) -> Dictionary:
	var over := stock.coupling() + Vector3(0, 1.1, 0)
	if p.driving != null:
		return {"at": over, "hint": _t("HINT_TRAILER_HITCH_DRIVE")}
	# (On its way to the pickup it is as good as coupled: the same line until it is.)
	if stock.can_couple() or stock.rolling():
		return {"at": over, "hint": _t("HINT_TRAILER_HITCH_FOOT")}
	# On foot with no vehicle near enough: the pickup first (when it stands far off).
	var truck := Quests.place_for("truck")
	if truck["at"] != null and _flat(p.global_position, stock.global_position) > 25.0:
		return {"at": truck["at"], "hint": _t("HINT_TRAILER_HITCH_TRUCK")}
	return {"at": over, "hint": _t("HINT_TRAILER_HITCH_TRUCK")}


## The sheep bought at the market: the rope, the ramp, the gate.
static func _load_place(stock: Trailer, p: Player) -> Dictionary:
	var gate := stock.global_transform * Vector3(0.0, 1.9, -1.6)
	if not _sheep_aboard(false).is_empty():
		# Aboard with the ramp still down.
		return {"at": gate, "hint": _t("HINT_SHEEP_GATE_UP")}
	var led := p.handler.led if p.handler != null else null
	if led != null and is_instance_valid(led) and led.data.species == &"sheep":
		if not stock.owned:
			return {"at": null, "hint": ""}
		return {"at": gate, "hint": _t("HINT_SHEEP_LOAD") if stock.gate_open else _t("HINT_SHEEP_GATE_DOWN")}
	for a in TrailerYard.waiting():
		if a.data.species == &"sheep":
			if TrailerYard.trailer_at_market() == null:
				# No trailer of his in town: the dealer brings it in the morning.
				return {"at": null, "hint": _t("HINT_SHEEP_TOMORROW")}
			return {"at": a.global_position + Vector3(0, 1.5, 0), "hint": _t("HINT_SHEEP_ROPE")}
	# A sheep of his somewhere else (let go on the way): the rope again.
	for a in _sheep():
		if a.can_lead():
			return {"at": a.global_position + Vector3(0, 1.5, 0), "hint": _t("HINT_SHEEP_ROPE")}
	return {"at": null, "hint": ""}


## Back at the farm: the ramp down, the rope on, into the barn's pen.
static func _unload_place(stock: Trailer, p: Player) -> Dictionary:
	if _sheep().is_empty():
		if not _owns_sheep() and not stock.owned and Quests.index_of("trailer_get") >= 0:
			# A save from before the trailer came into the story stood on this goal with
			# no sheep bought yet: it takes the trailer's lesson from its start.
			Quests.step = Quests.index_of("trailer_get")
			Quests.step_count = 0
			Quests.tutorial_changed.emit()
			return place("get")
		# None in the world (at the vet's): the market's line all the same.
		var market := Quests.place_for("animal:sheep")
		var why := String(market["hint"])
		return {"at": market["at"], "hint": _t("HINT_SHEEP_BUY_FIRST") if why == "" else why}
	var led := p.handler.led if p.handler != null else null
	if led != null and is_instance_valid(led) and led.data.species == &"sheep":
		return {"at": _pen_gate(led), "hint": _t("HINT_SHEEP_TO_BARN")}
	var riding := _sheep_aboard(false)
	if not riding.is_empty():
		var t := Trailer.carrying(riding[0])
		var gate := t.global_transform * Vector3(0.0, 1.9, -1.6)
		if _flat(t.global_position, _farmyard()) > FARM_NEAR:
			return {"at": Quests.place_for("home")["at"], "hint": _t("HINT_SHEEP_DRIVE")}
		return {"at": gate, "hint": _t("HINT_SHEEP_TAKE_OUT") if t.gate_open else _t("HINT_SHEEP_GATE_DOWN")}
	return _load_place(stock, p)


## Outside the gate of the pen `a` lives in.
static func _pen_gate(a: Animal) -> Vector3:
	var h := a.housing
	var at := h.center()
	if not h.gate.is_empty():
		at = WorldLayout.gate_point(h.pen, h.gate, -1.5)
	return Vector3(at.x, TerrainData.height(at.x, at.z) + 1.6, at.z)


## Whether the farm has a sheep at all (at the vet's too).
static func _owns_sheep() -> bool:
	for a: AnimalData in Animals.animals:
		if a.species == &"sheep":
			return true
	return false


## The farmer's sheep that are in the world (not at the vet's).
static func _sheep() -> Array[Animal]:
	var out: Array[Animal] = []
	for a: AnimalData in Animals.animals:
		if a.species == &"sheep":
			var n := Animals.node_of(a)
			if n != null:
				out.append(n)
	return out


## His sheep riding in a trailer (`shut`: only behind a raised gate, in their places).
static func _sheep_aboard(shut: bool) -> Array[Animal]:
	var out: Array[Animal] = []
	for a in _sheep():
		var t := Trailer.carrying(a)
		if t != null and (not shut or (not t.gate_open and t._walks.is_empty())):
			out.append(a)
	return out


## A sheep of his in its housing's pen (on the rope there counts: he has brought it in).
static func _sheep_home() -> bool:
	for a in _sheep():
		if not a.ridden and not a.data.away and a.housing != null and a.housing.in_pen(a.global_position, -0.3):
			return true
	return false


static func _farmyard() -> Vector3:
	var s := WorldLayout.FARM_TRUCK_SPOT
	return Vector3(s.x, 0.0, s.y)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))
