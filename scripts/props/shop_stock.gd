class_name ShopStock
extends RefCounted
## What each merchant sells.


static func general_store() -> Dictionary:
	var stock: Array[StringName] = []
	var season := GameClock.get_season()
	# Late in a season (and all winter) next season's seeds are on sale too.
	var next := (season + 1) % 4
	var early_access := GameClock.get_day_of_season() >= 8 or season == GameClock.Season.WINTER
	for crop: StringName in CropTable.CROPS:
		if CropTable.in_season(crop, season) or (early_access and CropTable.in_season(crop, next)):
			stock.append(StringName(String(crop) + "_seed"))
	stock.append_array([&"wood", &"stone", &"iron_ore"])
	return {"title": "UI_MERCHANT", "stock": stock, "buys": true, "repair": true}


static func rancher_supplies() -> Dictionary:
	var stock: Array[StringName] = []
	for id: StringName in [&"feed", &"hay", &"medicine", &"brush", &"milk_pail", &"shears"]:
		if ItemDB.has_item(id):
			stock.append(id)
	return {"title": "UI_RANCHER", "stock": stock, "buys": false}


## What the town market sells besides the stalls' seeds and materials: feed, the
## workbench kit, the workbench's hardware (nails, rope), bait for the rod (worms and
## dough $1, maggots and sweetcorn $2, cheese $3, live minnows $4, a spinner $15: each
## draws its own fish, FishTable) and dog food (Zeynep's errands, SideStory).
const MARKET_EXTRAS: Array[StringName] = [&"feed", &"hay", &"fertilizer", &"nails", &"rope", &"worm", &"dough",
	&"maggot", &"sweetcorn", &"cheese_bait", &"minnow", &"spinner", &"workbench", &"dog_food"]


## Yeşilova Market: seeds, building materials, hardware, bait and feed; buys all produce.
static func town_market() -> Dictionary:
	var shop := general_store()
	shop["title"] = "UI_TOWN_MARKET"
	for id: StringName in MARKET_EXTRAS:
		if ItemDB.has_item(id) and id not in shop["stock"]:
			(shop["stock"] as Array).append(id)
	shop["cargo"] = true
	return shop
