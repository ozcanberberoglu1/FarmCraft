class_name FishTable
extends RefCounted
## What bites in the farm pond: freshwater fish of a Turkish farm pond and lake (and the
## odd old boot), by rarity. Each cast rolls one catch from the species' chances, shaped
## by the bait on the hook (each species' "baits" liking; see BAIT), its time of day,
## (for some) rain and the rod (RODS). Prices by rarity (dollars, data/item_table.gd's
## fish block); a heavy fish is SILVER quality, a very heavy one GOLD, which the market
## pays more for (Economy.QUALITY_MULT).
##
## Fields: rarity (Rarity), chance (weight of the roll), kg (weight range), len (typical
## length in metres: the model's size at the middle of the range), baits (bait item ->
## chance factor: what it takes; any other bait gets the bait's "off"), time ("dawn",
## "day", "dusk", "night" or "" = any hour), rain (chance factor in rain or storm), junk
## (not a fish: can't be cooked or eaten).

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, JUNK }

const SPECIES := {
	# Kızılkanat: shoals in the shallows, takes bread dough and maggots.
	&"fish_rudd": {"rarity": Rarity.COMMON, "chance": 22.0, "kg": Vector2(0.12, 0.5), "len": 0.24,
		"baits": {&"dough": 2.0, &"maggot": 2.0, &"sweetcorn": 1.2}, "time": "day", "rain": 1.0},
	# Havuz balığı (crucian carp): the pond's most common fish.
	&"fish_crucian": {"rarity": Rarity.COMMON, "chance": 22.0, "kg": Vector2(0.1, 0.8), "len": 0.2,
		"baits": {&"dough": 2.2, &"sweetcorn": 1.8, &"maggot": 1.3, &"worm": 1.2}, "time": "", "rain": 1.0},
	# Tatlısu levreği: a striped hunter, goes for worms, little fish and a flashing spinner.
	&"fish_perch": {"rarity": Rarity.COMMON, "chance": 20.0, "kg": Vector2(0.12, 0.9), "len": 0.25,
		"baits": {&"worm": 2.2, &"spinner": 2.4, &"minnow": 2.2, &"maggot": 1.6}, "time": "day", "rain": 0.9},
	# Kızılgöz: silver with a red eye and orange fins; maggots above all.
	&"fish_roach": {"rarity": Rarity.COMMON, "chance": 20.0, "kg": Vector2(0.08, 0.8), "len": 0.22,
		"baits": {&"maggot": 2.4, &"dough": 1.8, &"sweetcorn": 1.0, &"worm": 1.0}, "time": "day", "rain": 1.0},
	# İnci balığı (bleak): a slim flash of silver near the top; a maggot is its whole meal.
	&"fish_bleak": {"rarity": Rarity.COMMON, "chance": 16.0, "kg": Vector2(0.01, 0.06), "len": 0.15,
		"baits": {&"maggot": 2.6, &"dough": 1.4}, "time": "day", "rain": 0.8},
	# Dere kayası (gudgeon): a little whiskered bottom fish that nibbles worms.
	&"fish_gudgeon": {"rarity": Rarity.COMMON, "chance": 14.0, "kg": Vector2(0.02, 0.12), "len": 0.13,
		"baits": {&"worm": 2.2, &"maggot": 2.0}, "time": "day", "rain": 1.1},
	# Kerevit: crawls over the muddy bottom at night.
	&"fish_crayfish": {"rarity": Rarity.UNCOMMON, "chance": 8.0, "kg": Vector2(0.03, 0.09), "len": 0.12,
		"baits": {&"worm": 1.8, &"cheese_bait": 1.8, &"minnow": 1.4}, "time": "night", "rain": 1.2},
	# Sazan: the big bottom feeder; sweetcorn and dough.
	&"fish_carp": {"rarity": Rarity.UNCOMMON, "chance": 9.0, "kg": Vector2(1.0, 6.5), "len": 0.52,
		"baits": {&"sweetcorn": 2.6, &"dough": 2.0, &"worm": 1.0}, "time": "dawn", "rain": 1.3},
	# Kadife: slow and slimy, in the weedy corners on dull days.
	&"fish_tench": {"rarity": Rarity.UNCOMMON, "chance": 8.0, "kg": Vector2(0.4, 2.5), "len": 0.36,
		"baits": {&"worm": 2.2, &"sweetcorn": 1.8, &"maggot": 1.5}, "time": "dusk", "rain": 1.5},
	# Çapak (bream): deep bronze slabs that shoal over the bottom toward evening.
	&"fish_bream": {"rarity": Rarity.UNCOMMON, "chance": 9.0, "kg": Vector2(0.3, 4.0), "len": 0.42,
		"baits": {&"sweetcorn": 2.0, &"maggot": 1.8, &"worm": 1.8, &"dough": 1.6}, "time": "dusk", "rain": 1.2},
	# Tatlısu kefali (chub): a bold, big-mouthed fish with orange fins; mad for cheese.
	&"fish_chub": {"rarity": Rarity.UNCOMMON, "chance": 7.0, "kg": Vector2(0.3, 3.5), "len": 0.42,
		"baits": {&"cheese_bait": 2.8, &"maggot": 1.6, &"spinner": 1.4, &"minnow": 1.2, &"worm": 1.2}, "time": "day",
		"rain": 1.1},
	# Bıyıklı balık (barbel): a golden bottom-rooter with four whiskers; cheese and worms at dusk.
	&"fish_barbel": {"rarity": Rarity.UNCOMMON, "chance": 5.0, "kg": Vector2(0.5, 5.0), "len": 0.5,
		"baits": {&"cheese_bait": 2.6, &"worm": 1.8, &"maggot": 1.5}, "time": "dusk", "rain": 1.4},
	# Alabalık (rainbow trout): rare in a still pond; bites in the cool of the morning.
	&"fish_trout": {"rarity": Rarity.RARE, "chance": 3.5, "kg": Vector2(0.3, 2.2), "len": 0.4,
		"baits": {&"spinner": 2.4, &"worm": 1.8, &"maggot": 1.6, &"sweetcorn": 1.2}, "time": "dawn", "rain": 1.2},
	# Dere alabalığı (brown trout): red-spotted and wary; a spinner or a live minnow at dusk.
	&"fish_brown_trout": {"rarity": Rarity.RARE, "chance": 2.5, "kg": Vector2(0.3, 3.0), "len": 0.42,
		"baits": {&"spinner": 2.6, &"minnow": 2.0, &"worm": 1.6}, "time": "dusk", "rain": 1.3},
	# Sudak: a glassy-eyed predator of the dusk.
	&"fish_zander": {"rarity": Rarity.RARE, "chance": 3.0, "kg": Vector2(0.8, 5.0), "len": 0.55,
		"baits": {&"minnow": 3.0, &"spinner": 1.8, &"worm": 0.8}, "time": "dusk", "rain": 1.1},
	# Turna: the pond's pike, a sudden ambusher of live bait and spinners.
	&"fish_pike": {"rarity": Rarity.RARE, "chance": 2.4, "kg": Vector2(1.0, 8.0), "len": 0.75,
		"baits": {&"minnow": 3.0, &"spinner": 2.8}, "time": "day", "rain": 1.0},
	# Yılan balığı (eel): comes out of the mud at night for worms and small fish.
	&"fish_eel": {"rarity": Rarity.RARE, "chance": 3.0, "kg": Vector2(0.3, 3.0), "len": 0.75,
		"baits": {&"worm": 2.4, &"minnow": 2.2}, "time": "night", "rain": 1.5},
	# Ot sazanı (grass carp): a long, heavy grazer of the weed beds; sweetcorn.
	&"fish_grass_carp": {"rarity": Rarity.RARE, "chance": 2.8, "kg": Vector2(2.0, 15.0), "len": 0.72,
		"baits": {&"sweetcorn": 2.6, &"dough": 1.6}, "time": "day", "rain": 1.1},
	# Gümüş sazan (silver carp): a bright, low-eyed filter feeder; only a soft paste of dough tempts it.
	&"fish_silver_carp": {"rarity": Rarity.RARE, "chance": 2.6, "kg": Vector2(1.5, 12.0), "len": 0.66,
		"baits": {&"dough": 2.6, &"sweetcorn": 0.8}, "time": "day", "rain": 1.0},
	# Yayın: the old whiskered giant that lives in the deep hole; comes up at night.
	&"fish_catfish": {"rarity": Rarity.LEGENDARY, "chance": 0.6, "kg": Vector2(3.0, 25.0), "len": 1.1,
		"baits": {&"minnow": 2.4, &"worm": 2.0, &"cheese_bait": 1.8}, "time": "night", "rain": 1.6},
	# Mersin balığı: the pond's legend, a sturgeon from the old river days, seen at night.
	&"fish_sturgeon": {"rarity": Rarity.LEGENDARY, "chance": 0.35, "kg": Vector2(8.0, 60.0), "len": 1.3,
		"baits": {&"worm": 2.0, &"minnow": 1.8, &"cheese_bait": 1.2}, "time": "night", "rain": 1.4},
	# Someone's lost rubber boot.
	&"old_boot": {"rarity": Rarity.JUNK, "chance": 2.5, "kg": Vector2(0.6, 0.6), "len": 0.34,
		"baits": {}, "time": "", "rain": 1.0, "junk": true},
}
## Chance factor at the species' time of day, and outside it.
const TIME_BONUS := 1.9
const TIME_MALUS := 0.55
## Share of the weight roll above which a fish is SILVER quality, and GOLD.
const SILVER_ROLL := 0.85
const GOLD_ROLL := 0.97
## Name colour of each rarity in the catch message.
const RARITY_COLORS := [Color(0.86, 0.9, 0.82), Color(0.5, 0.85, 1.0), Color(1.0, 0.72, 0.3),
	Color(1.0, 0.45, 0.85), Color(0.7, 0.66, 0.6)]
const RARITY_KEYS := ["FISH_RARITY_COMMON", "FISH_RARITY_UNCOMMON", "FISH_RARITY_RARE", "FISH_RARITY_LEGENDARY",
	"FISH_RARITY_JUNK"]
## Items that can go on the hook, cheapest first (the order R cycles them in).
const BAITS: Array[StringName] = [&"worm", &"dough", &"maggot", &"sweetcorn", &"cheese_bait", &"minnow", &"spinner"]
## Each bait: "off" is the chance factor of a species that doesn't care for it (the
## species' own "baits" factor otherwise); a live minnow or a spinner draws the hunters
## and hardly anything else. "lure": not eaten, so a cast keeps it; now and then it
## snags on the weed (LURE_LOSS) or a fish that gets away takes it.
const BAIT := {
	&"worm": {"off": 0.35}, &"dough": {"off": 0.3}, &"maggot": {"off": 0.3}, &"sweetcorn": {"off": 0.2},
	&"cheese_bait": {"off": 0.2}, &"minnow": {"off": 0.06}, &"spinner": {"off": 0.04, "lure": true},
}
const LURE_LOSS := 0.1
## A bait factor from which a species counts as taking it gladly (the catch message
## names it; a trophy is a little likelier).
const FAVOURED := 1.8
## The rods (all tool "fishing_rod"): the reach of a cast at no power and at full power
## (m), how soon a fish bites (a factor on the wait), the trophy odds (factor) and how
## readily the big fish (BIG_KG and up) take (a factor on their chance). A cane pole
## casts short and loses the big ones; the carbon rod and the carp rod reach far and
## hold the giants.
const RODS := {
	&"cane_rod": {"reach": Vector2(3.0, 9.0), "bite": 1.1, "trophy": 0.85, "big": 0.7},
	&"fishing_rod": {"reach": Vector2(4.0, 16.0), "bite": 1.0, "trophy": 1.0, "big": 1.0},
	&"carbon_rod": {"reach": Vector2(5.0, 19.0), "bite": 0.85, "trophy": 1.3, "big": 1.15},
	&"carp_rod": {"reach": Vector2(5.0, 21.0), "bite": 0.9, "trophy": 1.6, "big": 1.45},
}
const BIG_KG := 4.0
## Trophy fish: now and then the one that bites is a giant of its species ("<id>_trophy":
## ten times the weight and the price, a model about 2.4 times as long, as a fish ten
## times heavier is). The chance of each bite: about one in twenty, a little higher for
## the rarer species, at night, on a bait the species favours and with a better rod (at
## most TROPHY_MAX). And a farmer who has landed PITY_FROM fish in a row without one is
## owed a giant: from then each bite's chance climbs by PITY_STEP until it comes.
const TROPHY_CHANCE := 0.045
const TROPHY_RARITY := [1.0, 1.1, 1.2, 1.35, 0.0]
const TROPHY_NIGHT := 1.25
const TROPHY_BAIT := 1.15
const TROPHY_MAX := 0.12
const PITY_FROM := 25
const PITY_START := 0.2
const PITY_STEP := 0.25
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


## The chance that a bite of `id` is a trophy (with `bait` on the hook at `hour`, rod
## `rod` in hand, `dry` fish landed since the last trophy).
static func trophy_chance(id: StringName, bait: StringName, hour: float, rod := &"fishing_rod", dry := 0) -> float:
	if not is_fish(id) or not ItemTable.ITEMS.has(trophy_id(id)):
		return 0.0
	var s: Dictionary = SPECIES[id]
	var c: float = TROPHY_CHANCE * float(TROPHY_RARITY[int(s["rarity"])])
	if time_band(hour) == "night":
		c *= TROPHY_NIGHT
	if bait_factor(id, bait) >= FAVOURED:
		c *= TROPHY_BAIT
	c = minf(c * float(rod_stats(rod)["trophy"]), TROPHY_MAX)
	return maxf(c, pity(dry))


## The owed giant's chance after `dry` fish without a trophy (0 before PITY_FROM).
static func pity(dry: int) -> float:
	if dry < PITY_FROM:
		return 0.0
	return minf(PITY_START + PITY_STEP * (dry - PITY_FROM), 1.0)


## How a species takes `bait` (a factor on its chance): its own liking, else the bait's
## "off" (junk comes up whatever is on the hook).
static func bait_factor(id: StringName, bait: StringName) -> float:
	var s: Dictionary = SPECIES.get(id, {})
	if s.is_empty() or s.get("junk", false):
		return 1.0
	var likes: Dictionary = s["baits"]
	if likes.has(bait):
		return float(likes[bait])
	return float((BAIT.get(bait, {}) as Dictionary).get("off", 0.3))


## The bait species `id` likes best (&"" for junk).
static func favourite_bait(id: StringName) -> StringName:
	var best: StringName = &""
	var top := 0.0
	var likes: Dictionary = SPECIES.get(id, {}).get("baits", {})
	for b: StringName in likes:
		if float(likes[b]) > top:
			top = float(likes[b])
			best = b
	return best


## A rod's figures (RODS; the standard rod's for anything else).
static func rod_stats(rod: StringName) -> Dictionary:
	return RODS.get(rod, RODS[&"fishing_rod"])


## Whether `bait` is a lure (kept on a cast).
static func is_lure(bait: StringName) -> bool:
	return bool((BAIT.get(bait, {}) as Dictionary).get("lure", false))


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


## Each species' share of the next bite with `bait` at `hour` (rain: raining now) on
## rod `rod`.
static func chances(bait: StringName, hour: float, rain: bool, rod := &"fishing_rod") -> Dictionary:
	var band := time_band(hour)
	var big := float(rod_stats(rod)["big"])
	var out := {}
	for id: StringName in SPECIES:
		var s: Dictionary = SPECIES[id]
		var w := float(s["chance"]) * bait_factor(id, bait)
		var t: String = s["time"]
		if t != "":
			w *= TIME_BONUS if t == band else TIME_MALUS
		if rain:
			w *= float(s["rain"])
		if (s["kg"] as Vector2).y >= BIG_KG:
			w *= big
		out[id] = w
	return out


## Rolls a catch: {id, kg, quality, scale (model size factor)}; a trophy also has
## "trophy" and "species" (see trophy_of). `rod` in hand, `dry` fish landed since the
## last trophy (the owed giant; see pity). An owed giant is never an old boot.
static func roll(bait: StringName, hour: float, rain: bool, rng: RandomNumberGenerator, rod := &"fishing_rod",
		dry := 0) -> Dictionary:
	var ch := chances(bait, hour, rain, rod)
	if pity(dry) >= 1.0:
		for id: StringName in ch.keys():
			if not is_fish(id):
				ch.erase(id)
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
	if rng.randf() < trophy_chance(chosen, bait, hour, rod, dry):
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
