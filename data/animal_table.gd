class_name AnimalTable
extends RefCounted
## Livestock data. Prices in dollars (a grown hen at the Animal Market: 50); growth in fed days; food in rations per day
## (1 ration = 1 hay for barn animals, 1 feed for chickens).
##
## graze:      fullness gained per hour while outdoors in daylight (not winter)
## product:    item made by adults (every product_days days) and the tool needed
## value:      sale value of a healthy adult (babies sell for half)
## crate:      item a grown one travels in when bought at the Animal Market in town (one
##             animal per crate, let out at its housing); species without one are bought
##             straight into their housing
## market:     the building project the Animal Market wants to see on the farm before it
##             sells the species (&"" = none: crated birds wait in their crates); a species
##             without the field asks for its housing's first project (see market_needs)
## Poultry: hens lay in the coop's nest boxes (see Animals.eggs_today); a rooster living
## with them makes the eggs left in the nest fertile, and one left a whole day hatches
## (ChickenCoop). Chicks ("chick_days" the chick look, then a pullet) follow their
## mother and grow up in "grow_days" fed days; "rooster_chance" of them are cockerels.

const SPECIES := {
	&"chicken": {"housing": "coop", "baby_price": 20, "adult_price": 50, "grow_days": 4, "food": 1.0,
		"graze": 2.5, "product": &"egg", "product_days": 1, "tool": &"", "speed": 0.8, "value": 40,
		"radius": 0.22, "size": Vector3(0.3, 0.45, 0.42), "crate": &"chicken_crate", "market": &"",
		"chick_days": 2, "rooster_chance": 0.2},
	## The cock of the coop: lays nothing, crows at dawn, and makes the hens' eggs fertile.
	&"rooster": {"housing": "coop", "baby_price": 20, "adult_price": 70, "grow_days": 4, "food": 1.0,
		"graze": 2.5, "product": &"", "product_days": 0, "tool": &"", "speed": 0.85, "value": 55,
		"radius": 0.24, "size": Vector3(0.32, 0.6, 0.5), "crate": &"rooster_crate", "market": &"",
		"chick_days": 2},
	&"sheep": {"housing": "barn", "baby_price": 90, "adult_price": 225, "grow_days": 5, "food": 1.0,
		"graze": 9.0, "product": &"wool", "product_days": 3, "tool": &"shears", "speed": 0.75, "value": 180,
		"radius": 0.45, "size": Vector3(0.7, 0.95, 1.15), "market": &"barn_1"},
	&"cow": {"housing": "barn", "baby_price": 150, "adult_price": 375, "grow_days": 6, "food": 2.0,
		"graze": 9.0, "product": &"milk", "product_days": 1, "tool": &"milk_pail", "speed": 0.8, "value": 300,
		"radius": 0.65, "size": Vector3(0.8, 1.5, 2.3), "market": &"barn_1"},
	&"horse": {"housing": "barn", "baby_price": 225, "adult_price": 600, "grow_days": 6, "food": 2.0,
		"graze": 9.0, "product": &"", "product_days": 0, "tool": &"", "speed": 1.1, "value": 475,
		"radius": 0.6, "size": Vector3(0.7, 1.75, 2.2), "rideable": true, "market": &"barn_2"},
}

const ORDER := [&"chicken", &"rooster", &"sheep", &"cow", &"horse"]
## Species that live in a coop and hatch from eggs (their young are chicks).
const POULTRY := [&"chicken", &"rooster"]

const NAMES := {
	&"chicken": ["Pıtırcık", "Minnoş", "Tüylü", "Gıdık", "Benekli", "Çilli", "Fındık", "Pamuk", "Kınalı", "Sarı"],
	&"rooster": ["Sultan", "Paşa", "Kabadayı", "Horozcan", "İbiş", "Şahin", "Tokat", "Efe", "Kral", "Zıpzıp"],
	&"sheep": ["Pamuk", "Bulut", "Kuzucuk", "Karabaş", "Yumak", "Kıvırcık", "Beyaz", "Zeytin", "Poyraz", "Gümüş"],
	&"cow": ["Sarıkız", "Benekli", "Nazlı", "Karakız", "Papatya", "Menekşe", "Gülbahar", "Maviş", "Ala", "Fındık"],
	&"horse": ["Rüzgar", "Yıldız", "Kısrak", "Tarçın", "Duman", "Şimşek", "Karaelmas", "Asil", "Poyraz", "Kumral"],
}


## Shared fallback, so a lookup does not build a new empty Dictionary.
const _NONE := {}


static func get_species(id: StringName) -> Dictionary:
	return SPECIES.get(id, _NONE)


## The crate item a species travels in (&"" when it has none).
static func crate_item(species: StringName) -> StringName:
	return get_species(species).get("crate", &"")


## The building project the Animal Market asks for before it sells `species` (&"" when
## none): the "market" field, else barn animals the open barn and birds nothing more
## than their housing (Animals.can_buy asks for that).
static func market_needs(species: StringName) -> StringName:
	var info := get_species(species)
	if info.has("market"):
		return info["market"]
	return &"barn_1" if String(info.get("housing", "barn")) == "barn" and info.get("crate", &"") == &"" else &""


## The species riding in a crate item (&"" when `item_id` is no animal crate).
static func species_of_crate(item_id: StringName) -> StringName:
	if item_id == &"":
		return &""
	for s: StringName in SPECIES:
		if SPECIES[s].get("crate", &"") == item_id:
			return s
	return &""


## Whether `species` is poultry (lives in a coop, hatches from an egg).
static func is_poultry(species: StringName) -> bool:
	return species in POULTRY


## Whether the town's animal market sells `species` (every species with a "market"
## field; see market_needs for what the farm must have first).
static func sold_at_market(species: StringName) -> bool:
	return get_species(species).has("market")


static func random_name(species: StringName, taken: Array) -> String:
	var names: Array = NAMES.get(species, ["?"])
	var free := names.filter(func(n): return n not in taken)
	if free.is_empty():
		return "%s %d" % [names[randi() % names.size()], taken.size() + 1]
	return free[randi() % free.size()]
