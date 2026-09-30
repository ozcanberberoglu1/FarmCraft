extends Node
## Owns every farm animal's state and simulates it over time: hunger and thirst,
## grazing, eating and drinking from the troughs, weather exposure (rain, storms and
## snow hurt animals left outside; closed buildings protect them), cold winter
## nights, sickness, growth, affection and daily products. Also spawns the Animal
## bodies into their housing. A farm can have several coops (Grandpa's run and the ones
## put up from kits): each animal keeps its home (`_homes`), and crated hens bought in
## town move into a coop when they are let out at its door (release).
## Poultry: a fed hen lays an egg most days and a content one now and then two
## (eggs_today); with a rooster in her coop the eggs left in the nest hatch a day later
## (ChickenCoop calls hatch): the chick follows its mother (Animal) and grows up into a
## hen, now and then a rooster, which then lays (or crows) like any other.

signal changed
signal notes_changed

const FULL_DECAY := 100.0 / 24.0
const WATER_DECAY := 100.0 / 22.0
const WATER_RATION := 50.0
const RAIN_DAMAGE := {Weather.Kind.RAIN: 3.5, Weather.Kind.STORM: 6.5, Weather.Kind.SNOW: 5.0}
## The vet's call-out fee in dollars (a share of the animal's value comes on top).
const VET_CALL := 10

var animals: Array[AnimalData] = []
## Lines for the morning report (cleared when shown).
var report_notes: PackedStringArray = []
var _next_id := 1
var _nodes := {}
var _warned_day := {}
var _warmed := false
## Animal id -> the home id of the kit-built coop it lives in (AnimalHousing.home_id);
## the others live in their kind's main housing (Farm.housing_for).
var _homes := {}


func _ready() -> void:
	Events.clock_tick.connect(_on_tick)
	Events.day_started.connect(_on_day_started)
	Events.day_ending.connect(_on_day_ending)


# --- Queries -------------------------------------------------------------------------------

func count_in(housing_kind: String) -> int:
	var n := 0
	for a in animals:
		if a.info().get("housing", "") == housing_kind:
			n += 1
	return n


func housing_of(a: AnimalData) -> AnimalHousing:
	if Game.world == null or Game.world.farm == null:
		return null
	var farm: Farm = Game.world.farm
	var home := String(_homes.get(a.id, ""))
	if home != "":
		var h := farm.housing_by_id(home)
		if h:
			return h
	return farm.housing_for(a.info().get("housing", "barn"))


## How many animals live in `housing`.
func count_at(housing: AnimalHousing) -> int:
	var n := 0
	for a in animals:
		if housing_of(a) == housing:
			n += 1
	return n


## Where a new animal of `species` moves in: its kind's housing with room (the main one
## first, then the kit-built coops), else the main one (which may be full or unbuilt).
func home_for(species: StringName) -> AnimalHousing:
	if Game.world == null or Game.world.farm == null:
		return null
	var farm: Farm = Game.world.farm
	var kind := String(AnimalTable.get_species(species).get("housing", "barn"))
	var main := farm.housing_for(kind)
	if main and main.level > 0 and main.free_space() > 0:
		return main
	for h in farm.housings():
		if h.kind == kind and h.level > 0 and h.free_space() > 0:
			return h
	return main


func node_of(a: AnimalData) -> Animal:
	# Untyped first: after the game scene is rebuilt the old node is freed.
	var n = _nodes.get(a.id)
	return n as Animal if is_instance_valid(n) else null


func accepts_food(a: AnimalData, item_id: StringName) -> bool:
	if AnimalTable.is_poultry(a.species):
		return item_id == &"feed" or item_id == &"wheat"
	return item_id == &"hay"


func names_in_use() -> Array:
	return animals.map(func(a: AnimalData): return a.name)


## The animal with id `id` (null when there is none: sold, or never was).
func by_id(id: int) -> AnimalData:
	if id <= 0:
		return null
	for a in animals:
		if a.id == id:
			return a
	return null


## Grown roosters living in `housing`.
func roosters_in(housing: AnimalHousing) -> int:
	var n := 0
	for a in animals:
		if a.species == &"rooster" and a.adult and housing_of(a) == housing:
			n += 1
	return n


## Chicks following `mother` (not grown yet).
func chicks_of(mother: AnimalData) -> Array[AnimalData]:
	var out: Array[AnimalData] = []
	for a in animals:
		if a.mother == mother.id and a.is_chick():
			out.append(a)
	return out


# --- Buying & selling --------------------------------------------------------------------

## Returns "" if the animal can be bought, else the reason.
func can_buy(species: StringName, adult: bool) -> String:
	var need := UnlockTable.animal_level(species)
	if Progress.level < need:
		return tr("UI_NEEDS_LEVEL") % [need, Progress.level]
	var info := AnimalTable.get_species(species)
	var housing := home_for(species)
	if housing == null or housing.level <= 0:
		# Coops come from kits now: "the coop", not Grandpa's old run.
		var what := tr("HOUSING_COOP") if info["housing"] == "coop" else tr("PROJECT_%s_1" % String(info["housing"]).to_upper())
		return tr("MSG_NEED_HOUSING") % what
	if housing.free_space() <= 0:
		return tr("MSG_HOUSING_FULL")
	var price: int = info["adult_price"] if adult else info["baby_price"]
	if Economy.money < price:
		return tr("MSG_NEED_GOLD") % UiTheme.money(price - Economy.money)
	return ""


func buy(species: StringName, adult: bool, animal_name := "") -> AnimalData:
	if can_buy(species, adult) != "":
		return null
	var info := AnimalTable.get_species(species)
	Economy.spend(info["adult_price"] if adult else info["baby_price"], "REPORT_ANIMALS")
	var a := _add(species, adult, animal_name, home_for(species))
	Game.notify(tr("MSG_ANIMAL_ARRIVED") % [a.name, species_name(species, adult)], Color(0.55, 1.0, 0.45))
	changed.emit()
	return a


## A crated animal (bought at the town stall) let out at `housing`'s door: she moves in
## there for good, hopping out just inside the door (or at `at`: Grandpa's run takes
## them at its gate). Null when there is no room.
## Emits Events.animal_released with her new home (the ChickenCoop of a kit-built coop,
## else the housing).
func release(species: StringName, housing: AnimalHousing, at := Vector3.INF) -> AnimalData:
	if housing == null or housing.level <= 0 or housing.free_space() <= 0:
		return null
	var a := _add(species, true, "", housing)
	var n := node_of(a)
	if n:
		if at != Vector3.INF:
			n.arrive(at)
		elif housing.has_shelter():
			n.arrive(housing.door_inside())
		else:
			n.arrive(housing.random_outdoor_point(RandomNumberGenerator.new()))
	Game.notify(tr("MSG_ANIMAL_ARRIVED") % [a.name, species_name(species)], Color(0.55, 1.0, 0.45))
	var home: Node = housing.get_parent() if housing.placed else housing
	Events.animal_released.emit(species, home)
	changed.emit()
	return a


## A fertile egg hatched in `housing` at `at` (ChickenCoop): a chick of `mother` (her
## coop's hen that laid it; null picks one of its hens), now and then a cockerel. Its
## body comes out hidden and still (Animal.hatch_in): the hatching egg shows it when the
## shell gives way. Null when the housing is full. Emits Events.chick_hatched.
func hatch(housing: AnimalHousing, at: Vector3, mother: AnimalData = null) -> AnimalData:
	if housing == null or housing.level <= 0 or housing.free_space() <= 0:
		return null
	if mother == null or housing_of(mother) != housing:
		mother = _a_hen_of(housing)
	var chance := float(AnimalTable.get_species(&"chicken").get("rooster_chance", 0.2))
	var species := &"rooster" if randf() < chance else &"chicken"
	var a := _add(species, false, "", housing)
	a.mother = mother.id if mother else 0
	# The mother's coat (a black hen's chicks come out dark): cockerels keep theirs in range.
	if mother:
		a.variant = mother.variant % AnimalModels.variant_count(species)
	a.fullness = 70.0
	a.hydration = 70.0
	a.happiness = 80.0
	a.affection = 60.0
	var n := node_of(a)
	if n:
		n.hatch_in(at)
	Events.chick_hatched.emit(n)
	var msg := tr("MSG_CHICK_HATCHED") % ([a.name, mother.name] if mother else [a.name, "?"])
	Game.notify(msg, Color(0.55, 1.0, 0.45))
	report_notes.append(msg)
	changed.emit()
	return a


## A grown hen of `housing` (the healthiest), or null.
func _a_hen_of(housing: AnimalHousing) -> AnimalData:
	var best: AnimalData = null
	for a in animals:
		if a.species == &"chicken" and a.adult and housing_of(a) == housing and (best == null or a.health > best.health):
			best = a
	return best


## A new animal on the farm (bought, born or let out of a crate), living in `home`
## (its kind's main housing when null).
func _add(species: StringName, adult: bool, animal_name := "", home: AnimalHousing = null) -> AnimalData:
	var info := AnimalTable.get_species(species)
	var a := AnimalData.new()
	a.id = _next_id
	_next_id += 1
	if home and home.home_id != "":
		_homes[a.id] = home.home_id
	a.species = species
	a.name = animal_name if animal_name != "" else AnimalTable.random_name(species, names_in_use())
	a.variant = randi() % AnimalModels.variant_count(species)
	a.adult = adult
	a.growth = float(info["grow_days"]) if adult else 0.0
	a.wool = 1.0 if adult else 0.0
	a.affection = 100.0
	animals.append(a)
	_spawn(a)
	return a


func sell(a: AnimalData) -> int:
	var value := a.sale_value()
	Economy.add_money(value, "REPORT_ANIMALS")
	var n := node_of(a)
	if n:
		if n.ridden and Game.player:
			(Game.player as Player).dismount()
		n.queue_free()
	_nodes.erase(a.id)
	_homes.erase(a.id)
	animals.erase(a)
	changed.emit()
	return value


func species_name(species: StringName, adult := true) -> String:
	return tr(("ANIMAL_%s" if adult else "ANIMAL_%s_BABY") % String(species).to_upper())


# --- Spawning ------------------------------------------------------------------------------

func spawn_all() -> void:
	_warm_up()
	for a in animals:
		if node_of(a) == null:
			_spawn(a)


## Once per session, while the world is being built: puts one model of every
## species out of sight below the farm for a few frames, so its scene is loaded and
## its materials compiled before the first animal of a kind is bought or born.
func _warm_up() -> void:
	if _warmed or Game.world == null or Game.world.farm == null:
		return
	_warmed = true
	var holder := Node3D.new()
	holder.name = "AnimalWarmUp"
	holder.position = Vector3(0.0, -60.0, 0.0)
	Game.world.farm.add_child(holder)
	for species: StringName in AnimalTable.ORDER:
		holder.add_child(AnimalModels.create_rig(species))
	holder.add_child(AnimalModels.create_rig(&"chicken", &"chick"))
	for i in 5:
		await get_tree().process_frame
	if is_instance_valid(holder):
		holder.queue_free()


func _spawn(a: AnimalData) -> void:
	var housing := housing_of(a)
	if housing == null:
		return
	var n := Animal.new()
	n.name = "%s_%d" % [a.species, a.id]
	n.setup(a, housing)
	housing.add_child(n)
	_nodes[a.id] = n


# --- Care actions ---------------------------------------------------------------------------

func pet(a: AnimalData) -> void:
	if a.petted_today:
		return
	a.petted_today = true
	a.affection = minf(a.affection + 30.0, 1000.0)
	a.happiness = minf(a.happiness + 10.0, 100.0)
	changed.emit()


func brush(a: AnimalData) -> void:
	a.brushed_today = true
	a.affection = minf(a.affection + 25.0, 1000.0)
	a.happiness = minf(a.happiness + 12.0, 100.0)
	a.wet = maxf(a.wet - 0.5, 0.0)
	changed.emit()


func hand_feed(a: AnimalData) -> void:
	a.fullness = minf(a.fullness + 100.0 / float(a.info().get("food", 1.0)), 110.0)
	if not a.hand_fed_today:
		a.hand_fed_today = true
		a.affection = minf(a.affection + 10.0, 1000.0)
	changed.emit()


func give_medicine(a: AnimalData) -> void:
	a.sick = false
	a.health = minf(a.health + 40.0, 100.0)
	a.exposure = 0.0
	Game.notify(tr("MSG_ANIMAL_CURED") % a.name, Color(0.55, 1.0, 0.45))
	changed.emit()


func eat_from(a: AnimalData, trough: Trough) -> void:
	if trough == null:
		return
	var per := 100.0 / float(a.info().get("food", 1.0))
	while a.fullness < 75.0 and trough.amount >= 0.99:
		trough.take(1.0)
		a.fullness += per


func drink_from(a: AnimalData, trough: Trough) -> void:
	if trough == null:
		return
	while a.hydration < 75.0 and trough.amount >= 0.99:
		trough.take(1.0)
		a.hydration += WATER_RATION


func quality_for(a: AnimalData) -> int:
	var h := a.hearts()
	var r := randf()
	if h >= 4 and r < (h - 3) * 0.35:
		return ItemStack.Quality.GOLD
	if h >= 2 and r < 0.25 + h * 0.1:
		return ItemStack.Quality.SILVER
	return ItemStack.Quality.NORMAL


## Milk or wool into the player's inventory.
func collect_product(a: AnimalData) -> void:
	var item: StringName = a.info().get("product", &"")
	if item == &"" or not a.product_ready:
		return
	var left := PlayerState.inventory.add_item(item, 1, quality_for(a))
	if left > 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))
		return
	Game.notify("+1x %s" % ItemDB.get_item(item).display_name())
	a.product_ready = false
	a.product_progress = 0.0
	if a.species == &"sheep":
		a.wool = 0.0
	a.affection = minf(a.affection + 5.0, 1000.0)
	changed.emit()


# --- Simulation -----------------------------------------------------------------------------

func _on_tick(total: float, delta_minutes: float) -> void:
	if animals.is_empty():
		return
	var t := total - delta_minutes
	var remaining := delta_minutes
	while remaining > 0.001:
		var step := minf(remaining, 60.0)
		_simulate(step / 60.0, t, t + step)
		t += step
		remaining -= step
	changed.emit()


func _is_outdoors(a: AnimalData) -> bool:
	var n := node_of(a)
	if n:
		return not n.indoors
	var h := housing_of(a)
	return h == null or not h.has_shelter()


func _simulate(hours: float, t0: float, t1: float) -> void:
	var hour := fmod(6.0 + t0 / 60.0, 24.0)
	var night := hour >= 20.0 or hour < 6.0
	var kind := Weather.current()
	var precip := Weather._precip_minutes(t0, t1) / maxf(t1 - t0, 0.001)
	var winter := GameClock.get_season() == GameClock.Season.WINTER
	var exposed_names := []
	for a in animals:
		var info := a.info()
		var housing := housing_of(a)
		var outdoors := _is_outdoors(a)
		a.fullness -= FULL_DECAY * hours
		a.hydration -= WATER_DECAY * hours
		# Grazing and foraging outdoors in daylight.
		if outdoors and not night and not winter and Weather.snow_cover < 0.3:
			a.fullness += float(info.get("graze", 0.0)) * hours * (1.0 - precip * 0.5)
		# Troughs (animals eat and drink when they need to).
		if housing and not a.away:
			eat_from(a, housing.feed)
			drink_from(a, housing.water)
		# Rain, storms and snow hurt animals left outside.
		var cold := outdoors and winter and (night or (precip > 0.0 and kind == Weather.Kind.SNOW))
		a.cold = cold
		if outdoors and precip > 0.0:
			a.health -= float(RAIN_DAMAGE.get(kind, 3.5)) * precip * hours
			a.happiness -= 7.0 * precip * hours
			a.wet = minf(a.wet + precip * hours * 0.8, 1.0)
			a.exposure += precip * hours
			exposed_names.append(a.name)
		else:
			a.wet = maxf(a.wet - hours * (0.6 if not outdoors else 0.35), 0.0)
			a.exposure = maxf(a.exposure - hours * 0.4, 0.0)
		if cold:
			a.health -= 2.5 * hours
			a.happiness -= 3.0 * hours
		# Hunger and thirst.
		if a.fullness <= 0.0:
			a.health -= 3.5 * hours
			a.happiness -= 5.0 * hours
		if a.hydration <= 0.0:
			a.health -= 4.5 * hours
			a.happiness -= 5.0 * hours
		if a.fullness > 25.0:
			a.fed_hours += hours
		# Recovery when cared for.
		if a.fullness > 40.0 and a.hydration > 40.0 and a.wet < 0.2 and not a.sick and not cold:
			a.health += 1.5 * hours
			a.happiness += (2.0 if outdoors and not night and precip == 0.0 else 1.0) * hours
		# Sickness.
		if a.sick:
			a.health -= 1.2 * hours
			a.happiness -= 2.0 * hours
		else:
			var chance := 0.0
			if a.exposure > 5.0:
				chance += 0.05 * hours
			if a.health < 35.0:
				chance += 0.04 * hours
			if randf() < chance:
				a.sick = true
				Game.notify(tr("MSG_ANIMAL_SICK") % a.name, Color(1.0, 0.45, 0.35))
				report_notes.append(tr("MSG_ANIMAL_SICK") % a.name)
		a.fullness = clampf(a.fullness, 0.0, 110.0)
		a.hydration = clampf(a.hydration, 0.0, 110.0)
		a.happiness = clampf(a.happiness, 0.0, 100.0)
		a.health = minf(a.health, 100.0)
		if a.health <= 0.0:
			_vet(a)
	if not exposed_names.is_empty():
		_warn_exposure(exposed_names)


## A vet takes care of an animal that collapsed (costly, and it loses trust).
func _vet(a: AnimalData) -> void:
	var fee := mini(roundi(a.sale_value() * 0.3) + VET_CALL, Economy.money)
	if fee > 0:
		Economy.spend(fee, "REPORT_VET")
	a.health = 35.0
	a.sick = false
	a.affection = maxf(a.affection - 300.0, 0.0)
	var msg := tr("MSG_VET") % [a.name, UiTheme.money(fee)]
	Game.notify(msg, Color(1.0, 0.45, 0.35))
	report_notes.append(msg)


func _warn_exposure(names: Array) -> void:
	if _warned_day.get(GameClock.day, false) or DebugTools.args.has("shots"):
		return
	_warned_day[GameClock.day] = true
	var msg := tr("MSG_ANIMALS_IN_RAIN") % UiTheme.join_list(PackedStringArray(names.slice(0, 3)))
	Game.notify(msg, Color(1.0, 0.6, 0.35))
	report_notes.append(msg)


## At bedtime animals with a closed building go inside for the night (not the hens
## shut out of their coop: they spend it by the door).
func _on_day_ending() -> void:
	for a in animals:
		var n := node_of(a)
		var h := housing_of(a)
		if n and h and not a.away and not n.ridden and h.has_shelter() and (h.can_pass() or n.indoors):
			n.teleport_home(true)


func _on_day_started(_day: int) -> void:
	if Game.world and Game.world.farm:
		for housing in (Game.world.farm as Farm).housings():
			housing.morning_refill()
	var grown: Array[AnimalData] = []
	for a in animals:
		var info := a.info()
		var fed := a.fed_hours >= 16.0
		if not a.adult and fed:
			a.growth += 1.0
			if a.growth >= float(info["grow_days"]):
				a.adult = true
				a.wool = 0.0
				var msg := tr("MSG_ANIMAL_GROWN") % [a.name, species_name(a.species)]
				Game.notify(msg, Color(0.55, 1.0, 0.45))
				report_notes.append(msg)
				if AnimalTable.is_poultry(a.species):
					grown.append(a)
		if not a.petted_today:
			a.affection = maxf(a.affection - 15.0, 0.0)
		if not fed:
			a.affection = maxf(a.affection - 25.0, 0.0)
			report_notes.append(tr("MSG_ANIMAL_HUNGRY") % a.name)
		if a.species == &"chicken" and a.adult:
			# A hen fed only part of the day may still lay (eggs_today).
			_lay(a)
		elif a.adult and fed and a.health > 30.0 and not a.sick:
			_produce(a)
		if a.sick and a.health > 70.0 and randf() < 0.3:
			a.sick = false
		a.petted_today = false
		a.brushed_today = false
		a.hand_fed_today = false
		a.fed_hours = 0.0
		if a.away:
			a.away = false
		var n := node_of(a)
		if n and not n.ridden:
			# Out into the morning, unless the coop door is shut on them.
			var h := housing_of(a)
			n.teleport_home(h != null and not h.can_pass() and n.indoors)
			n.refresh_body()
	_muck_out()
	_breed()
	# Grown chicks (their bodies refreshed above) walk off on their own now.
	for a in grown:
		Events.chick_grown.emit(node_of(a))
	changed.emit()
	notes_changed.emit()


## Units of manure each animal leaves in its bedding overnight.
const MANURE := {&"cow": 3.0, &"horse": 3.0, &"sheep": 1.5, &"chicken": 0.5, &"rooster": 0.5}
## Nightly chance of a birth, and days a mother rests afterwards (poultry hatch from
## fertile eggs instead: ChickenCoop).
const BREED_CHANCE := {&"sheep": 0.14, &"cow": 0.1, &"horse": 0.07}
const BREED_REST := {&"sheep": 8, &"cow": 12, &"horse": 14}
## Laying: hours of a day a hen must have been fed for her egg (FED_EGG_HOURS), fewer
## (HALF_FED_HOURS) give one only now and then (HALF_FED_EGG); a second egg the same
## day comes to a content hen (happiness over CONTENT) with a chance growing with her
## hearts: SECOND_EGG + SECOND_EGG_HEART per heart + up to SECOND_EGG_HAPPY when happy.
const FED_EGG_HOURS := 16.0
const HALF_FED_HOURS := 8.0
const HALF_FED_EGG := 0.6
const CONTENT := 50.0
const SECOND_EGG := 0.1
const SECOND_EGG_HEART := 0.08
const SECOND_EGG_HAPPY := 0.12


## The bedding is mucked out onto the heap by the barn.
func _muck_out() -> void:
	var total := 0.0
	for a in animals:
		total += float(MANURE.get(a.species, 1.0)) * (1.0 if a.adult else 0.5)
	if total > 0.0:
		FarmState.add_manure(total)


## Two well-kept adults of a kind (healthy, content, two hearts or more) and room in
## their building: now and then a baby is born overnight.
func _breed() -> void:
	for species: StringName in BREED_CHANCE:
		var parents := animals.filter(func(a: AnimalData) -> bool:
			return a.species == species and a.adult and not a.sick and a.health >= 70.0 \
					and a.happiness >= 60.0 and a.hearts() >= 2)
		if parents.size() < 2:
			continue
		var mothers := parents.filter(func(a: AnimalData) -> bool:
			return GameClock.day - a.last_birth_day >= int(BREED_REST[species]))
		if mothers.is_empty() or randf() > float(BREED_CHANCE[species]):
			continue
		var mother: AnimalData = mothers.pick_random()
		# The baby stays with its mother when there is room, else goes where there is.
		var housing := housing_of(mother)
		if housing == null or housing.free_space() <= 0:
			housing = home_for(species)
		if housing == null or housing.level <= 0 or housing.free_space() <= 0:
			continue
		mother.last_birth_day = GameClock.day
		var baby := _add(species, false, "", housing)
		Events.animal_born.emit(species)
		var msg := tr("MSG_ANIMAL_BORN") % [species_name(species, false), mother.name, baby.name]
		Game.notify(msg, Color(0.55, 1.0, 0.45))
		report_notes.append(msg)


## How many eggs hen `a` lays today (0-2), at dawn from the day that went: a hen fed
## the day through lays one, one fed only part of it sometimes; a content one with
## hearts now and then lays a second later in the day. None when sick or run down.
func eggs_today(a: AnimalData) -> int:
	if a.sick or a.health <= 30.0:
		return 0
	var n := 0
	if a.fed_hours >= FED_EGG_HOURS:
		n = 1
	elif a.fed_hours >= HALF_FED_HOURS and randf() < HALF_FED_EGG:
		n = 1
	if n == 1 and a.fed_hours >= FED_EGG_HOURS and a.happiness >= CONTENT and randf() < second_egg_chance(a):
		n = 2
	return n


## The chance of a well-fed hen laying a second egg today.
func second_egg_chance(a: AnimalData) -> float:
	var happy := clampf((a.happiness - CONTENT) / (100.0 - CONTENT), 0.0, 1.0)
	return SECOND_EGG + SECOND_EGG_HEART * a.hearts() + SECOND_EGG_HAPPY * happy


## A hen's eggs for the day: a kit-built coop's hens lay in its bedded nest boxes during
## the morning (the second one later on); Grandpa's old run has them lying about.
func _lay(a: AnimalData) -> void:
	var n := eggs_today(a)
	if n <= 0:
		return
	var h := housing_of(a)
	var coop := ChickenCoop.of(h)
	if coop:
		coop.egg_due(a, quality_for(a), n)
	elif h:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in n:
			Pickup.spawn(ItemStack.create(&"egg", 1, quality_for(a)), h.egg_spot(rng) + Vector3(0, 0.08, 0))


func _produce(a: AnimalData) -> void:
	match a.species:
		&"chicken":
			_lay(a)
		&"cow":
			a.product_ready = true
		&"sheep":
			a.wool = minf(a.wool + 1.0 / float(a.info()["product_days"]), 1.0)
			if a.wool >= 0.999:
				a.product_ready = true


# --- Save -----------------------------------------------------------------------------------

func new_game() -> void:
	for a in animals.duplicate():
		var n := node_of(a)
		if n:
			n.queue_free()
	animals.clear()
	_nodes.clear()
	_homes.clear()
	_next_id = 1


func save_data() -> Dictionary:
	var homes := {}
	for id: int in _homes:
		homes[str(id)] = String(_homes[id])
	return {"next_id": _next_id, "animals": animals.map(func(a: AnimalData): return a.to_dict()), "homes": homes}


func load_data(d: Dictionary) -> void:
	new_game()
	_next_id = int(d.get("next_id", 1))
	for ad: Dictionary in d.get("animals", []):
		animals.append(AnimalData.from_dict(ad))
	var homes: Dictionary = d.get("homes", {})
	for k: Variant in homes:
		_homes[int(str(k))] = String(homes[k])
	spawn_all()
