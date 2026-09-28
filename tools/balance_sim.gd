extends SceneTree
## Plays a year (40 days) of a sensible player against the game's real tables (items,
## crops, animals, recipes, projects, farm levels and what they unlock, orders) and
## prints how money, farm level and income grow, when the milestones and level-ups
## come, and what each machine and each animal earns a day. For tuning prices and
## thresholds; --days=120 shows three years.
## Run: godot --headless --path . -s res://tools/balance_sim.gd [-- --days=40 --seed=1]
##
## The player model: a day has ACTIONS actions (hoe, plant, water, harvest, care);
## beds are replanted with the crop that earns most per day in the season; sprinklers
## (from level 2) take watering off their hands; goods go through the shipping bin
## (75%) until the pickup is bought, then to the town market every other day; the
## market price drops 0.4% per unit sold that day. Money goes, in order, to the
## pickup, the coop, the barn, fields, animals, machines and bigger buildings, each
## as soon as the farm level opens it (UnlockTable, RecipeTable).

const ACTIONS := 70
const BEDS_PER_FIELD := 12
const BEDS_PER_SPRINKLER := 4

var money := 2500
var day := 1
var level := 1
var xp := 0
var beds: Array = []
var fields := 1
var bag := {}
var pickup := false
var coop := 0
var barn := 0
var animals := {&"chicken": 0, &"cow": 0, &"sheep": 0}
var machines := {}
var sprinklers := 0
var fertilizer_on := false
var milestones := {}
var log_rows := []
var income := {"crops": 0, "animals": 0, "artisan": 0, "orders": 0}
var rng := RandomNumberGenerator.new()
# Autoloads, reached through the tree (a -s script is compiled before they're global).
var _db
var _progress
var _quests


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_db = root.get_node("ItemDB")
	_progress = root.get_node("Progress")
	_quests = root.get_node("Quests")
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
		var seed_cost = _db.get_item(StringName(String(best) + "_seed")).buy_price
		if money < seed_cost:
			break
		money -= seed_cost
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
	# Selling.
	if pickup:
		if day % 2 == 0:
			earned += _sell(1.0)
			money -= 15
	else:
		earned += _sell(0.75)
	money += earned
	_spend()
	_gain_xp(earned / 20)
	log_rows.append([day, money, level, xp, earned, fields * BEDS_PER_FIELD, animals.duplicate(), machines.duplicate()])


func _best_crop() -> StringName:
	var best: StringName = &""
	var best_rate := 0.0
	var left := (10 - (day - 1) % 10) * 24.0
	for id: StringName in CropTable.CROPS:
		var c := CropTable.get_crop(id)
		if not CropTable.in_season(id, _season()) or UnlockTable.crop_level(id) > level:
			continue
		var grow := float(c["grow_h"]) / (1.3 if fertilizer_on else 1.0)
		if grow > left:
			continue
		var y: Array = c["yield"]
		var per = (int(y[0]) + int(y[1])) * 0.5 * _db.get_item(c["item"]).sell_price
		var harvests := 1.0
		if int(c["regrow_h"]) > 0:
			harvests += floorf((left - grow) / (float(c["regrow_h"]) / (1.3 if fertilizer_on else 1.0)))
		var seed_cost = _db.get_item(StringName(String(id) + "_seed")).buy_price
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
		if n <= 0:
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
			_gain_xp(20 + reward / 25)
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
	var reserve := 200
	if not pickup and money >= 1800 + reserve:
		money -= 1800
		pickup = true
		_mark("pickup")
	if pickup and coop == 0 and _open_project(&"coop_1") and money >= 500 + reserve:
		money -= 500
		coop = 1
		_mark("coop")
	while coop > 0 and _open_animal(&"chicken") and animals[&"chicken"] < ProjectTable.COOP_CAPACITY[coop] and money >= 250 + reserve:
		money -= 250
		animals[&"chicken"] += 1
	if pickup and barn == 0 and _open_project(&"barn_1") and money >= 800 + reserve:
		money -= 800
		barn = 1
		_mark("barn")
	if barn > 0 and animals[&"cow"] + animals[&"sheep"] < ProjectTable.BARN_CAPACITY[barn]:
		# Cows and sheep in turn; saving up for the cow rather than filling up on sheep.
		if _open_animal(&"cow") and animals[&"cow"] <= animals[&"sheep"]:
			if money >= 1500 + reserve:
				money -= 1500
				animals[&"cow"] += 1
				_mark("first cow")
		elif _open_animal(&"sheep") and money >= 900 + reserve:
			money -= 900
			animals[&"sheep"] += 1
			_mark("first sheep")
	if _open_recipe(&"cheese_press") and not machines.has(&"cheese_press") and animals[&"cow"] > 0:
		machines[&"cheese_press"] = 1
		_mark("cheese press")
	if _open_recipe(&"sprinkler") and sprinklers < fields * 3 and money >= 300:
		sprinklers += 1
		money -= 100
	if not fertilizer_on and _open_recipe(&"fertilizer") and animals[&"chicken"] > 0:
		fertilizer_on = true
		_mark("fertilizer")
	if _open_recipe(&"spinning_wheel") and not machines.has(&"spinning_wheel") and animals[&"sheep"] > 0:
		machines[&"spinning_wheel"] = 1
		_mark("spinning wheel")
	if _open_recipe(&"jam_kettle") and not machines.has(&"jam_kettle"):
		machines[&"jam_kettle"] = 1
		_mark("jam kettle")
	if _open_recipe(&"quern") and not machines.has(&"quern") and money >= 400:
		machines[&"quern"] = 1
	var fcost: Array = [0, 1000, 3000, 8000]
	if fields < 4 and _open_project(StringName("field_%d" % fields)) and money >= int(fcost[fields]) + reserve * 3:
		money -= int(fcost[fields])
		fields += 1
		for i in BEDS_PER_FIELD:
			beds.append({"crop": &"", "growth": 0.0, "harvests": 0})
		_mark("field %d" % fields)
	if barn == 1 and _open_project(&"barn_2") and money >= 4500 + reserve * 5:
		money -= 4500
		barn = 2
		_mark("closed barn")
	if coop == 1 and _open_project(&"coop_2") and money >= 2000 + reserve * 5:
		money -= 2000
		coop = 2
		_mark("closed coop")


func _open_project(id: StringName) -> bool:
	return level >= UnlockTable.project_level(id)


func _open_animal(species: StringName) -> bool:
	return level >= UnlockTable.animal_level(species)


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
	print("\nanimal gold per day (adult, fed):")
	print("  chicken %d  cow %d  sheep %.0f" % [_db.get_item(&"egg").sell_price, _db.get_item(&"milk").sell_price, _db.get_item(&"wool").sell_price / 3.0])
