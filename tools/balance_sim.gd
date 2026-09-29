extends SceneTree
## Plays a year (40 days) of a sensible player against the game's real tables (items,
## crops, animals, recipes, projects, farm levels and what they unlock, orders) and
## prints how money, farm level and income grow, when the milestones and level-ups
## come, and what each machine and each animal earns a day. For tuning prices and
## thresholds; --days=120 shows three years.
## Run: godot --headless --path . -s res://tools/balance_sim.gd [-- --days=40 --seed=1]
##
## The player model: a new farm has Economy.STARTING_MONEY and Grandpa's pickup; the
## first day's story buys two hens and the coop kit, the second day's the workbench kit
## and the fishing rod's rope and bait. A day has ACTIONS actions (hoe, plant, water, harvest, care); beds are
## replanted with the crop that earns most per day in the season; sprinklers (from
## level 3) take watering off their hands; goods go through the shipping bin (75%) on
## the first two days, then to the town market every other day in the pickup; the
## market price drops 0.4% per unit sold that day. Money comes only from sales and
## orders, and goes, in order, to hens, a second coop kit, the barn, fields, animals,
## machines (their iron ore is bought; wood and stone are gathered), bigger buildings
## and the dealership's pickup, each as soon as the farm level opens it (UnlockTable,
## RecipeTable). Prices are read from the tables.

const ACTIONS := 70
const BEDS_PER_FIELD := 12
const BEDS_PER_SPRINKLER := 4
## Money kept back before a purchase (bigger ones keep a few times this).
const RESERVE := 50
## Litres of fuel a market trip to Yeşilova and back burns.
const TRIP_LITRES := 3.0

var money := 0
var day := 1
var level := 1
var xp := 0
var beds: Array = []
var fields := 1
var bag := {}
var dealer_pickup := false
var coops := 0
var barn := 0
var animals := {&"chicken": 0, &"cow": 0, &"sheep": 0}
var machines := {}
var sprinklers := 0
## The bigger buildings bought so far (warehouse_2, house_2, house_3).
var built := {}
var fertilizer_on := false
var milestones := {}
var log_rows := []
var income := {"crops": 0, "animals": 0, "artisan": 0, "orders": 0}
var rng := RandomNumberGenerator.new()
# Autoloads, reached through the tree (a -s script is compiled before they're global).
var _db
var _progress
var _quests
var _economy
## UnlockTable and Town.FUEL_PRICE, loaded once the autoloads are up (their scripts use
## them).
var _unlock: GDScript
var _fuel_price := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_db = root.get_node("ItemDB")
	_progress = root.get_node("Progress")
	_quests = root.get_node("Quests")
	_economy = root.get_node("Economy")
	_unlock = load("res://data/unlock_table.gd")
	_fuel_price = float((load("res://scripts/world/town.gd") as GDScript).get_script_constant_map()["FUEL_PRICE"])
	money = int(_economy.STARTING_MONEY)
	# The first day's story: two hens from the poultry stall and the coop kit for them.
	money -= 2 * _animal_price(&"chicken")
	animals[&"chicken"] = 2
	money -= _cost(&"coop_kit")
	coops = 1
	# The starter kit's seeds, and the carrots of Grandpa's ripe beds (Quests.GRANDPA_BEDS).
	for e: Array in ItemTable.STARTING_ITEMS:
		if _db.get_item(e[0]).category == "seed":
			_add(e[0], int(e[1]))
	_add(&"carrot", 3 * 2)
	_mark("2 hens + coop kit (money left %d)" % money)
	var days := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.substr(7))
		elif a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
	for i in BEDS_PER_FIELD:
		beds.append({"crop": &"", "growth": 0.0, "harvests": 0})
	for d in days:
		_day()
		day += 1
	_report()
	quit()


# --- One day -------------------------------------------------------------------------------

func _season() -> int:
	return int((day - 1) / 10) % 4


func _day() -> void:
	var actions := ACTIONS
	var earned := 0
	# Animals first: care and products.
	var care: int = animals[&"chicken"] + animals[&"cow"] * 2 + animals[&"sheep"] * 2
	actions -= care
	_add(&"egg", animals[&"chicken"])
	_add(&"milk", animals[&"cow"])
	if animals[&"sheep"] > 0 and day % 3 == 0:
		_add(&"wool", animals[&"sheep"])
	var winter := _season() == 3
	var hay_need: float = (animals[&"cow"] * 2 + animals[&"sheep"]) * (1.0 if winter else 0.3)
	var feed_need: float = animals[&"chicken"] * (1.0 if winter else 0.4)
	money -= roundi(hay_need * _db.get_item(&"hay").buy_price + feed_need * _db.get_item(&"feed").buy_price)
	_gain_xp(care * 1)
	# The second day's story: the workbench kit from the construction board (the wood is
	# gathered), then the fishing rod's rope and a bait from the market; the millstone is
	# made at the bench from gathered stone and wood.
	if day == 2:
		money -= _cost(&"workbench") + 2 * _db.get_item(&"rope").buy_price + _db.get_item(&"worm").buy_price
		machines[&"quern"] = 1
		_mark("workbench kit, rope and bait (money left %d)" % money)
	# Crops: harvest ripe beds, water growing ones, replant empty ones.
	var watered := sprinklers * BEDS_PER_SPRINKLER
	for b: Dictionary in beds:
		if b["crop"] == &"":
			continue
		var c := CropTable.get_crop(b["crop"])
		if not CropTable.in_season(b["crop"], _season()):
			b["crop"] = &""
			continue
		if watered > 0:
			watered -= 1
		elif actions > 0:
			actions -= 1
			_gain_xp(0)
		else:
			continue
		b["growth"] = float(b["growth"]) + 24.0 * (1.3 if fertilizer_on else 1.0)
		var need := float(c["regrow_h"] if int(b["harvests"]) > 0 else c["grow_h"])
		if float(b["growth"]) >= need and actions > 0:
			actions -= 1
			var y: Array = c["yield"]
			_add(c["item"], (int(y[0]) + int(y[1])) / 2)
			if c.has("extra"):
				_add(c["extra"][0], int(c["extra"][1]))
			_gain_xp(_progress.ACTION_XP["harvest"])
			if int(c["regrow_h"]) > 0:
				b["harvests"] = int(b["harvests"]) + 1
				b["growth"] = 0.0
			else:
				b["crop"] = &""
	for b: Dictionary in beds:
		if b["crop"] != &"" or actions < 2:
			continue
		var best := _best_crop()
		if best == &"":
			break
		# Seeds in the bag first (the starter kit's), else bought.
		var seed_id := StringName(String(best) + "_seed")
		if int(bag.get(seed_id, 0)) > 0:
			bag[seed_id] = int(bag[seed_id]) - 1
		elif money >= _db.get_item(seed_id).buy_price:
			money -= _db.get_item(seed_id).buy_price
		else:
			break
		actions -= 2
		b["crop"] = best
		b["growth"] = 0.0
		b["harvests"] = 0
		_gain_xp(_progress.ACTION_XP["hoe"] + _progress.ACTION_XP["plant"])
		if fertilizer_on:
			money -= _db.get_item(&"fertilizer").buy_price / 2
	# Machines turn goods into artisan goods.
	earned += _process_machines()
	# Orders: one every other day, from what's in store.
	if level >= 1 and day % 2 == 0:
		earned += _deliver_order()
	# Selling: the shipping bin on the first days, then the market in Grandpa's pickup.
	if day <= 2:
		earned += _sell(0.75)
	elif day % 2 == 0:
		earned += _sell(1.0)
		money -= ceili(TRIP_LITRES * _fuel_price)
	money += earned
	_spend()
	_gain_xp(earned / int(_progress.SALE_XP_DOLLARS))
	log_rows.append([day, money, level, xp, earned, fields * BEDS_PER_FIELD, animals.duplicate(), machines.duplicate()])


func _best_crop() -> StringName:
	var best: StringName = &""
	var best_rate := 0.0
	var left := (10 - (day - 1) % 10) * 24.0
	for id: StringName in CropTable.CROPS:
		var c := CropTable.get_crop(id)
		if not CropTable.in_season(id, _season()) or _unlock.crop_level(id) > level:
			continue
		var grow := float(c["grow_h"]) / (1.3 if fertilizer_on else 1.0)
		if grow > left:
			continue
		var y: Array = c["yield"]
		var per = (int(y[0]) + int(y[1])) * 0.5 * _db.get_item(c["item"]).sell_price
		var harvests := 1.0
		if int(c["regrow_h"]) > 0:
			harvests += floorf((left - grow) / (float(c["regrow_h"]) / (1.3 if fertilizer_on else 1.0)))
		# Seeds already in the bag cost nothing more.
		var seed_id := StringName(String(id) + "_seed")
		var seed_cost = 0 if int(bag.get(seed_id, 0)) > 0 else _db.get_item(seed_id).buy_price
		var rate = (per * harvests - seed_cost) / (grow + (harvests - 1.0) * float(c["regrow_h"]))
		if rate > best_rate:
			best_rate = rate
			best = id
	return best


func _add(id: StringName, n: int) -> void:
	if n > 0:
		bag[id] = int(bag.get(id, 0)) + n


## Sells everything but what the machines want; saturation lowers the price per unit.
func _sell(factor: float) -> int:
	var total := 0
	var keep := {}
	for m: StringName in machines:
		for r: Dictionary in RecipeTable.processing(m):
			for id: StringName in r["in"]:
				keep[id] = int(keep.get(id, 0)) + int(r["in"][id]) * int(machines[m]) * 2
	for id: StringName in bag.keys():
		var n := int(bag[id]) - int(keep.get(id, 0))
		if n <= 0 or _db.get_item(id).category == "seed":
			continue
		var base = _db.get_item(id).sell_price * (1.12 if fertilizer_on else 1.02)
		var sum := 0.0
		for i in n:
			sum += base * maxf(1.0 - 0.004 * i, 0.6)
		var gold := roundi(sum * factor)
		total += gold
		bag[id] = int(bag[id]) - n
		var cat = _db.get_item(id).category
		income["artisan" if cat == "artisan" else ("animals" if cat == "animal_product" else "crops")] += gold
	return total


func _process_machines() -> int:
	var made := 0
	for m: StringName in machines:
		for r: Dictionary in RecipeTable.processing(m):
			var batches := int(machines[m]) * maxi(int(24.0 / float(r["hours"])), 1)
			for i in batches:
				var ok := true
				for id: StringName in r["in"]:
					if int(bag.get(id, 0)) < int(r["in"][id]):
						ok = false
				if not ok:
					break
				for id: StringName in r["in"]:
					bag[id] = int(bag[id]) - int(r["in"][id])
				_add(r["out"], 1)
				_gain_xp(4)
				made += 1
	return 0


func _deliver_order() -> int:
	var pool = _quests.ORDER_GOODS.filter(func(g: Array) -> bool: return int(g[0]) <= level)
	for tries in 3:
		var g: Array = pool[rng.randi() % pool.size()]
		var count := int((int(g[2]) + int(g[3])) / 2.0 * (1.0 + (level - int(g[0])) * 0.25))
		if int(bag.get(g[1], 0)) >= count:
			bag[g[1]] = int(bag[g[1]]) - count
			var reward := roundi(_db.get_item(g[1]).sell_price * count * _quests.PREMIUM)
			income["orders"] += reward
			_gain_xp(20 + reward / int(_progress.ORDER_XP_DOLLARS))
			return reward
	return 0


func _gain_xp(n: int) -> void:
	xp += n
	while level < _progress.MAX_LEVEL and xp >= _progress.THRESHOLDS[level + 1]:
		level += 1
		_mark("level %d" % level)


func _mark(what: String) -> void:
	if not milestones.has(what):
		milestones[what] = day


## Spending, in order of what a player goes for, once the farm level opens it.
func _spend() -> void:
	var hen := _animal_price(&"chicken")
	while animals[&"chicken"] < ProjectTable.COOP_CAPACITY[2] * coops and money >= hen + RESERVE:
		money -= hen
		animals[&"chicken"] += 1
	# A second coop kit once the first is full.
	if coops == 1 and animals[&"chicken"] >= ProjectTable.COOP_CAPACITY[2] and money >= _cost(&"coop_kit") + RESERVE * 2:
		money -= _cost(&"coop_kit")
		coops = 2
		_mark("second coop")
	if barn == 0 and _open_project(&"barn_1") and money >= _cost(&"barn_1") + RESERVE:
		money -= _cost(&"barn_1")
		barn = 1
		_mark("barn")
	if barn > 0 and animals[&"cow"] + animals[&"sheep"] < ProjectTable.BARN_CAPACITY[barn]:
		# Cows and sheep in turn; saving up for the cow rather than filling up on sheep.
		if _open_animal(&"cow") and animals[&"cow"] <= animals[&"sheep"]:
			if money >= _animal_price(&"cow") + RESERVE:
				money -= _animal_price(&"cow")
				animals[&"cow"] += 1
				_mark("first cow")
		elif _open_animal(&"sheep") and money >= _animal_price(&"sheep") + RESERVE:
			money -= _animal_price(&"sheep")
			animals[&"sheep"] += 1
			_mark("first sheep")
	for m: StringName in [&"cheese_press", &"spinning_wheel", &"jam_kettle"]:
		var feeds: bool = m == &"jam_kettle" or (m == &"cheese_press" and animals[&"cow"] > 0) \
				or (m == &"spinning_wheel" and animals[&"sheep"] > 0)
		if _open_recipe(m) and not machines.has(m) and feeds and money >= _ore_cost(m) + RESERVE:
			money -= _ore_cost(m)
			machines[m] = 1
			_mark(String(m).replace("_", " "))
	if _open_recipe(&"sprinkler") and sprinklers < fields * 3 and money >= _ore_cost(&"sprinkler") + RESERVE * 2:
		sprinklers += 1
		money -= _ore_cost(&"sprinkler")
	if not fertilizer_on and _open_recipe(&"fertilizer") and animals[&"chicken"] > 0:
		fertilizer_on = true
		_mark("fertilizer")
	var field := StringName("field_%d" % fields)
	if fields < 4 and _open_project(field) and money >= _cost(field) + RESERVE * 3:
		money -= _cost(field)
		fields += 1
		for i in BEDS_PER_FIELD:
			beds.append({"crop": &"", "growth": 0.0, "harvests": 0})
		_mark("field %d" % fields)
	if barn == 1 and _open_project(&"barn_2") and money >= _cost(&"barn_2") + RESERVE * 5:
		money -= _cost(&"barn_2")
		barn = 2
		_mark("closed barn")
	for big: StringName in [&"warehouse_2", &"house_2", &"house_3"]:
		if not built.has(big) and _open_project(big) and money >= _cost(big) + RESERVE * 5:
			money -= _cost(big)
			built[big] = true
			_mark(String(big))
	var truck := int(VehicleTable.get_info(&"pickup_90")["price"])
	if not dealer_pickup and fields >= 3 and money >= truck + RESERVE * 5:
		money -= truck
		dealer_pickup = true
		_mark("dealer pickup")


func _cost(project: StringName) -> int:
	return int(ProjectTable.get_project(project)["cost"])


func _animal_price(species: StringName) -> int:
	return int(AnimalTable.get_species(species)["adult_price"])


## The iron ore a workbench recipe takes, bought at the market (wood and stone are
## gathered on the farm).
func _ore_cost(id: StringName) -> int:
	var items: Dictionary = RecipeTable.crafting(id).get("items", {})
	return int(items.get(&"iron_ore", 0)) * _db.get_item(&"iron_ore").buy_price


func _open_project(id: StringName) -> bool:
	return level >= _unlock.project_level(id)


func _open_animal(species: StringName) -> bool:
	return level >= _unlock.animal_level(species)


func _open_recipe(id: StringName) -> bool:
	return level >= int(RecipeTable.crafting(id)["level"])


func _report() -> void:
	print("\n=== FarmCraft balance: one year ===")
	print("day  money   lvl  xp     earned  beds  chickens cows sheep  machines")
	for r: Array in log_rows:
		if int(r[0]) % 5 == 0 or int(r[0]) <= 3:
			var a: Dictionary = r[6]
			print("%3d %7d  %3d %6d  %6d  %4d  %8d %4d %5d  %s" % [r[0], r[1], r[2], r[3], r[4], r[5], a[&"chicken"], a[&"cow"], a[&"sheep"], (r[7] as Dictionary).keys()])
	print("\nmilestones (day): ", milestones)
	print("income by source: ", income)
	print("\nvalue added per batch (market price out - in):")
	for m: StringName in RecipeTable.PROCESSING:
		for r: Dictionary in RecipeTable.processing(m):
			var cost := 0
			for id: StringName in r["in"]:
				cost += _db.get_item(id).sell_price * int(r["in"][id])
			var out = _db.get_item(r["out"]).sell_price
			print("  %-14s %-12s in %4d  out %4d  +%4d (%+.0f%%)  %dh  -> +%d/day max" % [m, r["out"], cost, out, out - cost,
					100.0 * (out - cost) / maxf(cost, 1.0), int(r["hours"]), (out - cost) * maxi(int(24 / int(r["hours"])), 1)])
	print("\nanimal dollars per day (adult, fed):")
	print("  chicken %d  cow %d  sheep %.0f" % [_db.get_item(&"egg").sell_price, _db.get_item(&"milk").sell_price, _db.get_item(&"wool").sell_price / 3.0])
