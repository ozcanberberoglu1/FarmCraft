class_name TrailerGoals
extends RefCounted
## The barn chapter's lesson with Grandpa's stock trailer (Trailer, TrailerYard), as the
## story's goals see it (Quests: checks "trailer:<what>", places "trailer:<where>"):
##   trailer_get    pay Kemal the tyre bill at his desk in the dealership ("owned");
##   trailer_see    over to the trailer in the bay next door, where Kemal sends him
##                  ("seen": within SEE_NEAR of it, or at the wheel already);
##   trailer_truck  into the pickup ("aboard");
##   trailer_back   past the trailer (the dot beyond it shows how far: _pull_up) and backed
##                  up to its tongue in line with it, along the approach drawn on the
##                  ground (Trailer._approach), stopped once the marker over the coupling
##                  is green ("backed");
##   trailer_hitch  out of the cab, E at the tongue ("hitched");
##   sheep_buy      a sheep from the Animal Market ("sheep_owned");
##   sheep_load     the rope on it (G), up the ramp (E), the gate shut ("sheep_loaded");
##   sheep_ride     home to the farm ("sheep_at_farm");
##   sheep          into the barn's pen ("sheep_home").
## Every check also reads true once the farm is past it (hitched passes the steps before
## it, a sheep at home passes them all: a sheep the dealer brought, or bought before the
## lesson), so the chain never stalls; and every place comes with the line that says what
## to do there, whatever the farmer does out of turn (on foot at the backing goal: the
## pickup first; driven off again at the coupling goal: back up again). A save from before
## the trailer came into the story that stood on "sheep" with none bought goes back to the
## lesson's start (_unload_place); one from before the hitch was taught step by step goes
## on from the goal it stood on (their ids are the same).

## How near the farmyard counts as back at the farm (m, from the warehouse's door).
const FARM_NEAR := 70.0
## How near the trailer counts as having come to it (m), and below which speed (km/h) a
## vehicle counts as stopped at its tongue.
const SEE_NEAR := 9.0
const STOP_KMH := 2.5
## Where the pickup pulls up before it backs in (_pull_up): this far past the tongue's line
## the way it is heading and this far out ahead of the coupling (m; at the dealer's bay:
## on the street, across its middle), so that its tail has the room to swing onto the lane;
## and how far past the line its ball must have come for that to count as done (m; measured
## with a keyboard driver, 60 goes at the bay: stopped less than 6 m past he never got his
## tail round onto the lane, from 6 m on he did, so the dot lets go a little later).
const PULL_PAST := 12.5
const PULL_AHEAD := 8.6
const PULLED_PAST := 7.0
## The goals that teach the hitch: the approach on the ground shows for Grandpa's trailer
## while one of them is up (teaching).
const LESSON: Array[String] = ["trailer_see", "trailer_truck", "trailer_back", "trailer_hitch"]


## How far the check `what` is along (1: done).
static func progress(what: String) -> int:
	var stock := Trailer.of_kind(&"trailer_stock")
	var mine := stock != null and stock.owned
	var p := Game.player as Player
	match what:
		"owned":
			return 1 if mine else 0
		"seen":
			if not mine or not is_instance_valid(p):
				return 0
			return 1 if stock.tow != null or p.driving != null or _flat(p.global_position, stock.global_position) < SEE_NEAR else 0
		"aboard":
			if not mine or not is_instance_valid(p):
				return 0
			return 1 if stock.tow != null or stock.tow_in_reach() != null or _can_tow(p.driving) else 0
		"backed":
			if not mine:
				return 0
			var v := stock.tow_in_reach()
			return 1 if stock.tow != null or (v != null and v.speed_kmh() < STOP_KMH) else 0
		"hitched":
			return 1 if mine and stock.tow != null else 0
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
			return {"at": Town.dealer_desk(), "hint": _t("HINT_TRAILER_GET") % UiTheme.money(stock.price)}
		"see":
			return {"at": stock.waypoint_roof(), "hint": _t("HINT_TRAILER_SEE")}
		"truck":
			return _truck_place(stock, p)
		"back":
			return _back_place(stock, p)
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


## Whether the approach is drawn on the ground for `t` while the farmer is on foot: it is
## his and still waits unhitched in the dealer's bay, or it is Grandpa's and the story
## teaches the hitch right now.
static func teaching(t: Trailer) -> bool:
	if not t.owned or t.tow != null:
		return false
	if TrailerYard.in_bay(t):
		return true
	return t.kind == &"trailer_stock" and not Quests.tutorial_done() and LESSON.has(String(Quests.current().get("id", "")))


## Whether `v` is a vehicle that could take a trailer now (not one itself, none behind it).
static func _can_tow(v: Vehicle) -> bool:
	return v != null and is_instance_valid(v) and not v is Trailer and Trailer.towed_by(v) == null


## On foot: the pickup first. At the wheel of one that tows another trailer already (the
## cargo trailer, bought and coupled before Grandpa's was paid for): that one comes off
## first, the dot over its tongue.
static func _truck_place(stock: Trailer, p: Player) -> Dictionary:
	if _can_tow(p.driving):
		return _back_place(stock, p)
	var behind := Trailer.towed_by(p.driving) if p.driving != null else null
	if behind != null:
		return {"at": behind.coupling() + Vector3(0, 1.1, 0), "hint": _t("HINT_TRAILER_TOW_TAKEN")}
	var truck: Variant = Quests.place_for("truck")["at"] if p.driving == null else null
	return {"at": truck if truck != null else stock.coupling() + Vector3(0, 1.1, 0), "hint": _t("HINT_TRAILER_TRUCK")}


## At the wheel: past the trailer and back along the approach to its tongue; the dot first
## over the spot beyond the trailer where the pickup pulls up (_pull_up), then, once it is
## past, over the place outlined for it on the ground, and over the coupling once the ball
## is in reach ("stop").
static func _back_place(stock: Trailer, p: Player) -> Dictionary:
	if not _can_tow(p.driving):
		return _truck_place(stock, p)
	var over := stock.coupling() + Vector3(0, 1.1, 0)
	if stock.tow_in_reach() == p.driving:
		return {"at": over, "hint": _t("HINT_TRAILER_STOP")}
	var pull: Variant = _pull_up(stock, p.driving)
	if pull != null:
		return {"at": pull, "hint": _t("HINT_TRAILER_HITCH_DRIVE")}
	var place := stock.approach_place(p.driving._footprint.size.y + 0.25)
	return {"at": place.origin + Vector3(0, 1.3, 0), "hint": _t("HINT_TRAILER_HITCH_DRIVE")}


## Where `v` pulls up before it backs in to `stock`'s tongue (over the ground there), or
## null when that is behind it: backing already, turned tail to the trailer out ahead of
## its tongue, or its ball PULLED_PAST beyond the tongue's line. The spot lies beyond that
## line the way `v` is heading (the side it is on when it heads at the trailer or away),
## PULL_PAST from it and PULL_AHEAD out ahead of the coupling.
static func _pull_up(stock: Trailer, v: Vehicle) -> Variant:
	var c := stock.coupling()
	var f := Vector2(stock.global_basis.z.x, stock.global_basis.z.z).normalized()
	var r := Vector2(f.y, -f.x)
	var h := Vector2(v.global_basis.z.x, v.global_basis.z.z).normalized()
	var ball := v.global_transform * Trailer.hitch_of(v)
	var b := Vector2(ball.x - c.x, ball.z - c.z)
	if v.forward_speed() < -0.3 or (h.dot(f) > 0.35 and b.dot(f) > 0.5):
		return null
	var way := 1.0
	if absf(h.dot(r)) > 0.3:
		way = signf(h.dot(r))
	elif absf(b.dot(r)) > 1.0:
		way = signf(b.dot(r))
	if b.dot(r) * way >= PULLED_PAST:
		return null
	var at := Vector2(c.x, c.z) + f * PULL_AHEAD + r * way * PULL_PAST
	return Vector3(at.x, stock._ground_under(at, c.y) + 1.3, at.y)


## The ball in reach: stop, get out, E at the tongue. Not in reach (any more): back up.
static func _hitch_place(stock: Trailer, p: Player) -> Dictionary:
	var over := stock.coupling() + Vector3(0, 1.1, 0)
	var v := stock.tow_in_reach()
	if v == null:
		return _back_place(stock, p)
	if p.driving != null:
		return {"at": over, "hint": _t("HINT_TRAILER_STOP") if p.driving.speed_kmh() >= STOP_KMH else _t("MSG_TRAILER_IN_REACH")}
	return {"at": over, "hint": _t("HINT_TRAILER_HITCH_FOOT")}


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
