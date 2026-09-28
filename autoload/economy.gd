extends Node
## Player wallet, transaction ledger and the market that sets sell prices.
##
## Sell price = base × quality × daily market × saturation × season
##   - daily market: a smooth random walk per item between 0.85 and 1.15
##   - saturation: every unit sold today lowers the price a little (floor 0.6);
##     it recovers overnight
##   - season: crops sold out of their season fetch 20% more

## Grandpa's savings: a first round of seeds and repairs (his old pickup comes with
## the farm; the dealership's better one is a later purchase).
const STARTING_MONEY := 2500
const QUALITY_MULT := [1.0, 1.25, 1.5]
const SATURATION_PER_UNIT := 0.004
const SATURATION_FLOOR := 0.6

var money := STARTING_MONEY
## Today's transactions: [{amount, reason}], summarized and cleared each night.
var ledger: Array[Dictionary] = []
## Units of each item sold today (drives saturation).
var sold_today := {}
var market_seed := 0

var _noise := FastNoiseLite.new()


func _ready() -> void:
	market_seed = randi() % 100000
	_noise.frequency = 0.35
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	Events.day_started.connect(func(_d): sold_today.clear())


func add_money(amount: int, reason := "") -> void:
	if amount == 0:
		return
	money += amount
	ledger.append({"amount": amount, "reason": reason})
	Events.money_changed.emit(money, amount)


func can_afford(amount: int) -> bool:
	return money >= amount


## Deducts `amount` if affordable. Returns false (and changes nothing) otherwise.
func spend(amount: int, reason := "") -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	add_money(-amount, reason)
	return true


# --- Market ------------------------------------------------------------------------------

## Market factor of an item on a given day (0.85 .. 1.15).
func market_factor(item_id: StringName, day: int = -1) -> float:
	var d := GameClock.day if day < 0 else day
	_noise.seed = market_seed + hash(item_id) % 9973
	return 1.0 + _noise.get_noise_1d(float(d)) * 0.15 / 0.6


func saturation(item_id: StringName) -> float:
	return maxf(SATURATION_FLOOR, 1.0 - float(sold_today.get(item_id, 0)) * SATURATION_PER_UNIT)


func season_factor(item_id: StringName) -> float:
	if CropTable.CROPS.has(item_id) and not CropTable.in_season(item_id, GameClock.get_season()):
		return 1.2
	return 1.0


func sell_price(item_id: StringName, quality := 0) -> int:
	return _price_at(item_id, quality, int(sold_today.get(item_id, 0)))


## One unit's price once `sold` units of the item were sold today.
func _price_at(item_id: StringName, quality: int, sold: int) -> int:
	var item := ItemDB.get_item(item_id)
	if item == null or item.sell_price <= 0:
		return 0
	var sat := maxf(SATURATION_FLOOR, 1.0 - float(sold) * SATURATION_PER_UNIT)
	var f := market_factor(item_id) * sat * season_factor(item_id)
	return maxi(1, roundi(item.sell_price * QUALITY_MULT[clampi(quality, 0, 2)] * f))


## What selling `count` units would pay right now (each unit lowers the price, as in
## sell()) without selling them; `already` more units are counted as sold first, so
## a quote for several lots of one item (e.g. two qualities) adds up exactly.
func quote(item_id: StringName, count: int, quality := 0, factor := 1.0, already := 0) -> int:
	var sold := int(sold_today.get(item_id, 0)) + already
	var total := 0
	for i in count:
		total += roundi(_price_at(item_id, quality, sold + i) * factor)
	return total


func buy_price(item_id: StringName) -> int:
	var item := ItemDB.get_item(item_id)
	return item.buy_price if item else 0


## +1 rising, -1 falling, 0 steady compared to yesterday.
func price_trend(item_id: StringName) -> int:
	var delta := market_factor(item_id) - market_factor(item_id, GameClock.day - 1)
	if delta > 0.015:
		return 1
	if delta < -0.015:
		return -1
	return 0


## Sells `count` of an item: pays out and records saturation. Returns the income.
func sell(item_id: StringName, count: int, quality := 0, reason := "REPORT_SALES", factor := 1.0) -> int:
	var total := 0
	for i in count:
		total += roundi(_price_at(item_id, quality, int(sold_today.get(item_id, 0))) * factor)
		sold_today[item_id] = int(sold_today.get(item_id, 0)) + 1
	add_money(total, reason)
	Events.item_sold.emit(item_id, count, total)
	return total


## Summarizes and clears today's transactions: {income, expenses, lines}.
## `lines` groups amounts by reason.
func close_day() -> Dictionary:
	var income := 0
	var expenses := 0
	var by_reason := {}
	for t in ledger:
		var amount: int = t["amount"]
		if amount > 0:
			income += amount
		else:
			expenses -= amount
		var reason: String = t.get("reason", "")
		by_reason[reason] = int(by_reason.get(reason, 0)) + amount
	ledger.clear()
	return {"income": income, "expenses": expenses, "lines": by_reason}


func new_game() -> void:
	money = STARTING_MONEY
	ledger.clear()
	sold_today.clear()
	market_seed = randi() % 100000
	Events.money_changed.emit(money, 0)


func save_data() -> Dictionary:
	return {"money": money, "seed": market_seed, "sold": sold_today, "ledger": ledger}


func load_data(data: Dictionary) -> void:
	money = int(data.get("money", STARTING_MONEY))
	market_seed = int(data.get("seed", market_seed))
	sold_today = data.get("sold", {})
	ledger.assign(data.get("ledger", []))
	Events.money_changed.emit(money, 0)
