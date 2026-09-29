class_name AnimalTable
extends RefCounted
## Livestock data. Prices in dollars (a grown hen at the poultry stall: 50); growth in fed days; food in rations per day
## (1 ration = 1 hay for barn animals, 1 feed for chickens).
##
## graze:      fullness gained per hour while outdoors in daylight (not winter)
## product:    item made by adults (every product_days days) and the tool needed
## value:      sale value of a healthy adult (babies sell for half)
## crate:      item a grown one travels in when bought at the town stall (one animal per
##             crate, let out at its housing); species without one are bought straight in

const SPECIES := {
	&"chicken": {"housing": "coop", "baby_price": 20, "adult_price": 50, "grow_days": 3, "food": 1.0,
		"graze": 2.5, "product": &"egg", "product_days": 1, "tool": &"", "speed": 0.8, "value": 40,
		"radius": 0.22, "size": Vector3(0.3, 0.45, 0.42), "crate": &"chicken_crate"},
	&"sheep": {"housing": "barn", "baby_price": 90, "adult_price": 225, "grow_days": 5, "food": 1.0,
		"graze": 9.0, "product": &"wool", "product_days": 3, "tool": &"shears", "speed": 0.75, "value": 180,
		"radius": 0.45, "size": Vector3(0.7, 0.95, 1.15)},
	&"cow": {"housing": "barn", "baby_price": 150, "adult_price": 375, "grow_days": 6, "food": 2.0,
		"graze": 9.0, "product": &"milk", "product_days": 1, "tool": &"milk_pail", "speed": 0.8, "value": 300,
		"radius": 0.65, "size": Vector3(0.8, 1.5, 2.3)},
	&"horse": {"housing": "barn", "baby_price": 225, "adult_price": 600, "grow_days": 6, "food": 2.0,
		"graze": 9.0, "product": &"", "product_days": 0, "tool": &"", "speed": 1.1, "value": 475,
		"radius": 0.6, "size": Vector3(0.7, 1.75, 2.2), "rideable": true},
}

const ORDER := [&"chicken", &"sheep", &"cow", &"horse"]

const NAMES := {
	&"chicken": ["Pıtırcık", "Minnoş", "Tüylü", "Gıdık", "Benekli", "Çilli", "Fındık", "Pamuk", "Kınalı", "Sarı"],
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


## The species riding in a crate item (&"" when `item_id` is no animal crate).
static func species_of_crate(item_id: StringName) -> StringName:
	if item_id == &"":
		return &""
	for s: StringName in SPECIES:
		if SPECIES[s].get("crate", &"") == item_id:
			return s
	return &""


static func random_name(species: StringName, taken: Array) -> String:
	var names: Array = NAMES.get(species, ["?"])
	var free := names.filter(func(n): return n not in taken)
	if free.is_empty():
		return "%s %d" % [names[randi() % names.size()], taken.size() + 1]
	return free[randi() % free.size()]
