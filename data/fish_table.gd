class_name FishTable
extends RefCounted
## What bites in the farm pond: freshwater fish of a Turkish farm pond (and the odd old
## boot), by rarity. Each cast rolls one catch from the species' chances, raised when
## the bait is the one it prefers, at its time of day and (for some) in rain. Prices by
## rarity (dollars, data/item_table.gd's fish block); a heavy fish is SILVER quality and a
## trophy GOLD, which the market pays more for (Economy.QUALITY_MULT).
##
## Fields: rarity (Rarity), chance (weight of the roll), kg (weight range), len (typical
## length in metres: the model's size at the middle of the range), bait (preferred bait
## item), time ("dawn", "day", "dusk", "night" or "" = any hour), rain (chance factor in
## rain or storm), junk (not a fish: can't be cooked or eaten).

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, JUNK }

const SPECIES := {
	# Kızılkanat: shoals in the shallows, takes bread dough.
	&"fish_rudd": {"rarity": Rarity.COMMON, "chance": 22.0, "kg": Vector2(0.12, 0.5), "len": 0.24,
		"bait": &"dough", "time": "day", "rain": 1.0},
	# Havuz balığı (crucian carp): the pond's most common fish.
	&"fish_crucian": {"rarity": Rarity.COMMON, "chance": 22.0, "kg": Vector2(0.1, 0.8), "len": 0.2,
		"bait": &"dough", "time": "", "rain": 1.0},
	# Tatlısu levreği: a striped hunter, goes for worms.
	&"fish_perch": {"rarity": Rarity.COMMON, "chance": 20.0, "kg": Vector2(0.12, 0.9), "len": 0.25,
		"bait": &"worm", "time": "day", "rain": 0.9},
	# Kerevit: crawls over the muddy bottom at night.
	&"fish_crayfish": {"rarity": Rarity.UNCOMMON, "chance": 8.0, "kg": Vector2(0.03, 0.09), "len": 0.12,
		"bait": &"worm", "time": "night", "rain": 1.2},
	# Sazan: the big bottom feeder, fond of dough.
	&"fish_carp": {"rarity": Rarity.UNCOMMON, "chance": 9.0, "kg": Vector2(1.0, 6.5), "len": 0.52,
		"bait": &"dough", "time": "dawn", "rain": 1.3},
	# Kadife: slow and slimy, in the weedy corners on dull days.
	&"fish_tench": {"rarity": Rarity.UNCOMMON, "chance": 8.0, "kg": Vector2(0.4, 2.5), "len": 0.36,
		"bait": &"worm", "time": "dusk", "rain": 1.5},
	# Alabalık: rare in a still pond; bites in the cool of the morning.
	&"fish_trout": {"rarity": Rarity.RARE, "chance": 3.5, "kg": Vector2(0.3, 2.2), "len": 0.4,
		"bait": &"worm", "time": "dawn", "rain": 1.2},
	# Sudak: a glassy-eyed predator of the dusk.
	&"fish_zander": {"rarity": Rarity.RARE, "chance": 3.0, "kg": Vector2(0.8, 5.0), "len": 0.55,
		"bait": &"worm", "time": "dusk", "rain": 1.1},
	# Turna: the pond's pike, a sudden ambusher.
	&"fish_pike": {"rarity": Rarity.RARE, "chance": 2.4, "kg": Vector2(1.0, 8.0), "len": 0.75,
		"bait": &"worm", "time": "day", "rain": 1.0},
	# Yayın: the old whiskered giant that lives in the deep hole; comes up at night.
	&"fish_catfish": {"rarity": Rarity.LEGENDARY, "chance": 0.6, "kg": Vector2(3.0, 25.0), "len": 1.1,
		"bait": &"worm", "time": "night", "rain": 1.6},
	# Someone's lost rubber boot.
	&"old_boot": {"rarity": Rarity.JUNK, "chance": 2.5, "kg": Vector2(0.6, 0.6), "len": 0.34,
		"bait": &"", "time": "", "rain": 1.0, "junk": true},
}
## Chance factor at the species' time of day, and outside it.
const TIME_BONUS := 1.9
const TIME_MALUS := 0.55
## Chance factor with the bait the species prefers.
const BAIT_BONUS := 1.8
## Share of the weight roll above which a fish is SILVER quality, and GOLD.
const SILVER_ROLL := 0.85
const GOLD_ROLL := 0.97
## Name colour of each rarity in the catch message.
const RARITY_COLORS := [Color(0.86, 0.9, 0.82), Color(0.5, 0.85, 1.0), Color(1.0, 0.72, 0.3),
	Color(1.0, 0.45, 0.85), Color(0.7, 0.66, 0.6)]
const RARITY_KEYS := ["FISH_RARITY_COMMON", "FISH_RARITY_UNCOMMON", "FISH_RARITY_RARE", "FISH_RARITY_LEGENDARY",
	"FISH_RARITY_JUNK"]
## Items that can go on the hook.
const BAITS: Array[StringName] = [&"worm", &"dough"]
## Trophy fish: now and then the one that bites is a giant of its species ("<id>_trophy":
## ten times the weight and the price, a model about 2.4 times as long, as a fish ten
## times heavier is). The chance of each bite, a little higher for the rarer, bigger
## species, at night and on the bait the species prefers (at most TROPHY_MAX).
const TROPHY_CHANCE := 0.022
const TROPHY_RARITY := [1.0, 1.25, 1.5, 1.8, 0.0]
const TROPHY_NIGHT := 1.3
const TROPHY_BAIT := 1.2
const TROPHY_MAX := 0.045
const TROPHY_KG := 10.0
const TROPHY_SIZE := 2.4
const TROPHY_SUFFIX := "_trophy"


static func is_fish(id: StringName) -> bool:
	return SPECIES.has(id) and not SPECIES[id].get("junk", false)


## The trophy of species `id` ("fish_carp_trophy").
static func trophy_id(id: StringName) -> StringName:
	return StringName(String(id) + TROPHY_SUFFIX)


static func is_trophy(id: StringName) -> bool:
	return String(id).ends_with(TROPHY_SUFFIX) and is_fish(species_of(id))


## The species a catch item is of: the fish itself, or the species of a trophy.
static func species_of(id: StringName) -> StringName:
	var s := String(id)
	return StringName(s.trim_suffix(TROPHY_SUFFIX)) if s.ends_with(TROPHY_SUFFIX) else id


## The chance that a bite of `id` is a trophy (with `bait` on the hook at `hour`).
static func trophy_chance(id: StringName, bait: StringName, hour: float) -> float:
	if not is_fish(id) or not ItemTable.ITEMS.has(trophy_id(id)):
		return 0.0
	var s: Dictionary = SPECIES[id]
	var c: float = TROPHY_CHANCE * float(TROPHY_RARITY[int(s["rarity"])])
	if time_band(hour) == "night":
		c *= TROPHY_NIGHT
	if bait != &"" and s["bait"] == bait:
		c *= TROPHY_BAIT
	return minf(c, TROPHY_MAX)


## `catch` (catch_of) made a trophy: ten times the weight, the giant's model size.
static func trophy_of(catch: Dictionary) -> Dictionary:
	var id: StringName = catch["id"]
	var out := catch.duplicate()
	out["id"] = trophy_id(id)
	out["species"] = id
	out["kg"] = float(catch["kg"]) * TROPHY_KG
	out["quality"] = ItemStack.Quality.NORMAL
	out["scale"] = float(catch["scale"]) * TROPHY_SIZE
	out["trophy"] = true
	return out


static func get_species(id: StringName) -> Dictionary:
	return SPECIES.get(id, {})


## "dawn" 5-9, "day" 9-17, "dusk" 17-21, "night" 21-5.
static func time_band(hour: float) -> String:
	if hour >= 5.0 and hour < 9.0:
		return "dawn"
	if hour >= 9.0 and hour < 17.0:
		return "day"
	if hour >= 17.0 and hour < 21.0:
		return "dusk"
	return "night"


## Each species' share of the next bite with `bait` at `hour` (rain: raining now).
static func chances(bait: StringName, hour: float, rain: bool) -> Dictionary:
	var band := time_band(hour)
	var out := {}
	for id: StringName in SPECIES:
		var s: Dictionary = SPECIES[id]
		var w := float(s["chance"])
		var t: String = s["time"]
		if t != "":
			w *= TIME_BONUS if t == band else TIME_MALUS
		if s["bait"] != &"" and s["bait"] == bait:
			w *= BAIT_BONUS
		if rain:
			w *= float(s["rain"])
		out[id] = w
	return out


## Rolls a catch: {id, kg, quality, scale (model size factor)}; a trophy also has
## "trophy" and "species" (see trophy_of).
static func roll(bait: StringName, hour: float, rain: bool, rng: RandomNumberGenerator) -> Dictionary:
	var ch := chances(bait, hour, rain)
	var total := 0.0
	for id: StringName in ch:
		total += float(ch[id])
	var pick := rng.randf() * total
	var chosen: StringName = ch.keys()[0]
	for id: StringName in ch:
		pick -= float(ch[id])
		if pick <= 0.0:
			chosen = id
			break
	var catch := catch_of(chosen, rng.randf())
	if rng.randf() < trophy_chance(chosen, bait, hour):
		return trophy_of(catch)
	return catch


## The catch of `id` at weight roll `r` (0..1; most fish are on the light side).
static func catch_of(id: StringName, r: float) -> Dictionary:
	var s: Dictionary = SPECIES[id]
	var kg_range: Vector2 = s["kg"]
	var kg := lerpf(kg_range.x, kg_range.y, pow(r, 1.8))
	var mid := lerpf(kg_range.x, kg_range.y, pow(0.5, 1.8))
	var quality := ItemStack.Quality.NORMAL
	if not s.get("junk", false):
		if r >= GOLD_ROLL:
			quality = ItemStack.Quality.GOLD
		elif r >= SILVER_ROLL:
			quality = ItemStack.Quality.SILVER
	return {"id": id, "species": id, "kg": kg, "quality": quality,
		"scale": clampf(pow(kg / maxf(mid, 0.001), 1.0 / 3.0), 0.72, 1.4)}


## The cooked item a fish turns into on the campfire.
static func cooked_id(id: StringName) -> StringName:
	return StringName(String(id) + "_cooked")
