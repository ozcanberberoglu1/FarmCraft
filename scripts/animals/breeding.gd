class_name Breeding
extends RefCounted
## The big animals breed: sheep, cows and horses are female or male (AnimalData.male: a ram,
## a bull, a stallion), and a female kept well with a male of her kind carries young.
##
##   The male     sold grown at the Animal Market (buy_male: MALE_PRICE), a little bigger and
##                heavier than the females (MALE_SCALE), the ram with curled horns, the bull
##                in a dark coat. A ram still gives wool, a bull no milk, a stallion is
##                ridden like a mare.
##   Carrying     each dawn (daily, from Animals._breed) a grown female that is healthy, fed
##                and content (HEALTHY, FED, CONTENT), rested from her last birth (REST days)
##                and lives in the same building as a grown, sound male, conceives with
##                CHANCE. She carries GESTATION mornings (AnimalData.due_in counts them
##                down): her belly rounds out (AnimalRig.set_belly), her panel and prompt say
##                "Pregnant · 2 days left", near her term she walks a little slower
##                (TERM_PACE). Wool and milk go on as ever. Hurt, sick or hungry she keeps her
##                young; only her death ends it.
##   Birth        at dawn in her building when it has a place free: one young (its kind's
##                baby body), beside her, lying in the straw until the farmer comes near
##                (RISE_NEAR), then up on wobbly legs. With the building full she waits (a
##                note the morning before and every morning after says so) until there is
##                room. The young keeps close to its mother (decide), nurses now and then,
##                and grows up in its kind's grow_days like a bought one; it can be sold at
##                the market like any other.
##   Names        the first one born of each kind is named by the farmer when he first walks
##                up to it (BreedingGoals opens Animals' naming prompt); later ones get a name
##                from their kind's list, changed in the animal's panel like any name.
##
## The lesson is BreedingGoals' (the quiet side goals from the first grown ewe on).

## Mornings a female carries, mornings she rests after a birth, and her chance to conceive
## each dawn the conditions hold.
const GESTATION := {&"sheep": 3, &"cow": 4, &"horse": 5}
const REST := {&"sheep": 3, &"cow": 4, &"horse": 5}
const CHANCE := {&"sheep": 0.6, &"cow": 0.5, &"horse": 0.45}
## A grown male's price at the Animal Market (the female's is AnimalTable's adult_price).
const MALE_PRICE := {&"sheep": 250, &"cow": 420, &"horse": 650}
## How much bigger than a female a grown male stands.
const MALE_SCALE := {&"sheep": 1.12, &"cow": 1.1, &"horse": 1.07}
## The share of the young born male.
const MALE_BORN := 0.4
## What it takes to conceive: her health, her fullness at dawn and her happiness at least
## these; the male's health at least SIRE_HEALTH.
const HEALTHY := 60.0
const FED := 35.0
const CONTENT := 55.0
const SIRE_HEALTH := 50.0
## Her pace in the last TERM_DAYS mornings before the birth.
const TERM_DAYS := 1
const TERM_PACE := 0.75
## A newborn lies by its mother until the farmer is this near (metres) or RISE_AFTER game
## minutes have passed; getting up takes RISE_TIME seconds (trembling, a stumble or two).
const RISE_NEAR := 9.0
const RISE_AFTER := 180.0
const RISE_TIME := 4.2
## The young keeps within FOLLOW_FAR metres of its mother (beyond FOLLOW_RUN it hurries),
## and nurses every NURSE_EVERY seconds or so for NURSE_TIME.
const FOLLOW_FAR := 3.2
const FOLLOW_RUN := 6.0
const NURSE_EVERY := Vector2(40.0, 95.0)
const NURSE_TIME := Vector2(5.0, 8.0)
const NURSE_FOOD := 8.0
## The names a male comes with (the females' are AnimalTable.NAMES).
const MALE_NAMES := {
	&"sheep": ["Koçero", "Kınalı", "Yiğit", "Boynuz", "Şampiyon", "Aslan", "Dadaş", "Karakoç"],
	&"cow": ["Tosun", "Karaboğa", "Ferdi", "Dombay", "Paşa", "Kabadayı", "Efe", "Şahin"],
	&"horse": ["Yağız", "Şahbaz", "Doru", "Bora", "Kartal", "Karayel", "Alp", "Tufan"],
}
## The ram's horns (metres, from the head bone at the poll: x out to the side, y up, z to
## the tail): where one leaves the skull, the radius of its winding (root, tip), how far
## it stands out to the side by its tip, its thickness (root, tip) and its turns.
const HORN_BASE := Vector3(0.055, 0.04, -0.1)
const HORN_WIND := Vector2(0.062, 0.085)
const HORN_SPREAD := 0.15
const HORN_THICK := Vector2(0.03, 0.006)
const HORN_TURN := 0.8
## The bull's coat (dark and light tints over the cow's texture).
const BULL_COAT := [Color(0.035, 0.03, 0.028), Color(0.2, 0.15, 0.11)]
## A newborn's phases (not saved: one born today lies down again after a load until seen).
enum Phase { LYING, RISING, UP }

## The dice of conception and of the young's sex and coat (tests seed it).
static var rng := RandomNumberGenerator.new()
## Animal id -> {phase, t, nurse, nursing, born_at}: what a young one is up to (not saved).
static var _young := {}
static var _horn_mesh: ArrayMesh
static var _seeded := false


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


# --- The rules --------------------------------------------------------------------------------

## Whether `species` breeds this way (sheep, cows, horses).
static func breeds(species: StringName) -> bool:
	return GESTATION.has(species)


## A grown male's price at the market.
static func male_price(species: StringName) -> int:
	return int(MALE_PRICE.get(species, AnimalTable.get_species(species).get("adult_price", 0)))


## What a `species` animal is called by its sex and age ("Ram", "Ewe", "Lamb").
static func sex_name(a: AnimalData) -> String:
	if not breeds(a.species):
		return Animals.species_name(a.species, a.adult)
	if not a.adult:
		return Animals.species_name(a.species, false)
	return _t("ANIMAL_%s_%s" % [String(a.species).to_upper(), "MALE" if a.male else "FEMALE"])


## The grown male's name for his kind ("Ram").
static func male_name(species: StringName) -> String:
	return _t("ANIMAL_%s_MALE" % String(species).to_upper())


## A grown, sound male of `species` living in `housing` (null: none).
static func sire_in(housing: AnimalHousing, species: StringName) -> AnimalData:
	for a in Animals.animals:
		if a.species == species and a.male and a.adult and not a.sick and not a.injured() and not a.at_vet() \
				and a.health >= SIRE_HEALTH and Animals.housing_of(a) == housing:
			return a
	return null


## What keeps female `a` from conceiving ("" when nothing does): "kind", "young", "male",
## "carrying", "away" (at the vet), "hurt", "sick", "health", "hungry", "unhappy", "rest",
## "no_male".
static func blocker(a: AnimalData) -> String:
	if not breeds(a.species):
		return "kind"
	if a.male:
		return "male"
	if not a.adult:
		return "young"
	if a.pregnant():
		return "carrying"
	if a.at_vet():
		return "away"
	if a.injured():
		return "hurt"
	if a.sick:
		return "sick"
	if a.health < HEALTHY:
		return "health"
	if a.fullness < FED:
		return "hungry"
	if a.happiness < CONTENT:
		return "unhappy"
	if sire_in(Animals.housing_of(a), a.species) == null:
		return "no_male"
	if GameClock.day - a.last_birth_day < int(REST[a.species]):
		return "rest"
	return ""


## Mornings until `a` gives birth (-1: not carrying; 0: due, waiting for room).
static func days_left(a: AnimalData) -> int:
	return a.due_in


## Whether `a` is due and only waits for a free place in her building.
static func waiting_for_room(a: AnimalData) -> bool:
	if a.due_in != 0:
		return false
	var h := Animals.housing_of(a)
	return h == null or h.free_space() <= 0


## 0..1: how far along she is (her belly).
static func progress(a: AnimalData) -> float:
	if not a.pregnant() or not breeds(a.species):
		return 0.0
	var whole := float(GESTATION[a.species])
	return clampf(1.0 - float(a.due_in) / whole, 0.0, 1.0)


## How fast `a` walks against its kind's pace (near her term a little slower).
static func pace(a: AnimalData) -> float:
	return TERM_PACE if a.pregnant() and a.due_in <= TERM_DAYS else 1.0


## The line about her young for her panel and her prompt ("" when she carries none).
static func status_text(a: AnimalData) -> String:
	if not a.pregnant():
		return ""
	if waiting_for_room(a):
		return _t("STATUS_PREGNANT_WAITING")
	if a.due_in <= 0:
		return _t("STATUS_PREGNANT_DUE")
	if a.due_in == 1:
		return _t("STATUS_PREGNANT_TOMORROW")
	return _t("STATUS_PREGNANT") % a.due_in


# --- Buying a male ----------------------------------------------------------------------------

## "" when a grown male of `species` can be bought now, else why not (Animals.can_buy's
## reasons, with his own price).
static func can_buy_male(species: StringName) -> String:
	if not breeds(species):
		return _t("MSG_HOUSING_FULL")
	var why := Animals.can_buy(species, true)
	var price := male_price(species)
	var plain: int = AnimalTable.get_species(species).get("adult_price", 0)
	# Animals.can_buy counted the female's price: his own decides.
	if why != "" and Economy.money < plain and why == _t("MSG_NEED_GOLD") % UiTheme.money(plain - Economy.money):
		why = ""
	if why == "" and Economy.money < price:
		return _t("MSG_NEED_GOLD") % UiTheme.money(price - Economy.money)
	return why


## Buys a grown male of `species` into its housing (null when it can't be bought).
static func buy_male(species: StringName) -> AnimalData:
	if can_buy_male(species) != "":
		return null
	Economy.spend(male_price(species), "REPORT_ANIMALS")
	var a := Animals._add(species, true, "", Animals.home_for(species))
	make_male(a)
	Game.notify(_t("MSG_ANIMAL_ARRIVED") % [a.name, male_name(species)], Color(0.55, 1.0, 0.45))
	Animals.changed.emit()
	return a


## Turns `a` (just bought or born) into a male: his name from the males' list (unless he
## was given one), no milk waiting, his body dressed.
static func make_male(a: AnimalData, keep_name := false) -> void:
	a.male = true
	if not keep_name:
		a.name = _male_name(a.species, a)
	if a.species == &"cow":
		a.product_ready = false
	_refresh(a)


static func _male_name(species: StringName, own: AnimalData) -> String:
	var names: Array = MALE_NAMES.get(species, [])
	var taken := Animals.animals.filter(func(x: AnimalData) -> bool: return x != own).map(func(x: AnimalData) -> String: return x.name)
	var free := names.filter(func(n: String) -> bool: return n not in taken)
	if free.is_empty():
		return own.name
	return free[rng.randi() % free.size()]


# --- The day ------------------------------------------------------------------------------------

## Dawn (Animals._breed): the ones carrying come a morning nearer, the due ones give birth
## (or wait for room), and the ones the conditions hold for may conceive.
static func daily() -> void:
	if not _seeded:
		_seeded = true
		if not DebugTools.is_automated():
			rng.randomize()
	for a: AnimalData in Animals.animals.duplicate():
		if not breeds(a.species) or a.male or not a.adult:
			continue
		if a.pregnant():
			_carry_on(a)
		elif blocker(a) == "" and rng.randf() < float(CHANCE[a.species]):
			conceive(a)


## `a` is with young from this morning on (a note; her side goal shows the days).
static func conceive(a: AnimalData) -> void:
	if not breeds(a.species) or a.male or a.pregnant():
		return
	a.due_in = int(GESTATION[a.species])
	var msg := _t("MSG_ANIMAL_PREGNANT") % [a.name, a.due_in]
	Game.notify(msg, Color(0.98, 0.78, 0.86))
	Animals.report_notes.append(msg)
	_refresh(a)
	Animals.changed.emit()


## A morning nearer her term; due: the birth, when her building has a free place.
static func _carry_on(a: AnimalData) -> void:
	if a.at_vet():
		# At the clinic: she comes home first.
		return
	if a.due_in > 0:
		a.due_in -= 1
	var h := Animals.housing_of(a)
	var room := h != null and h.level > 0 and h.free_space() > 0
	if a.due_in == 0 and room:
		birth(a)
		return
	if a.due_in <= 1 and not room:
		# The morning before, and every morning she waits: make room for the young one.
		var msg := _t("MSG_BIRTH_NO_ROOM" if a.due_in == 1 else "MSG_BIRTH_WAITING") % a.name
		Game.notify(msg, Color(1.0, 0.6, 0.35))
		Animals._urgent_note(msg)
	_refresh(a)


## `mother` gives birth in her building: the young one beside her (null when there is no
## room). Events.animal_born.
static func birth(mother: AnimalData) -> AnimalData:
	var h := Animals.housing_of(mother)
	if h == null or h.level <= 0 or h.free_space() <= 0:
		return null
	var sire := sire_in(h, mother.species)
	mother.due_in = -1
	mother.last_birth_day = GameClock.day
	var baby := Animals._add(mother.species, false, "", h)
	baby.mother = mother.id
	baby.born_day = GameClock.day
	# Its mother's coat, now and then its father's.
	var coat := sire if sire != null and rng.randf() < 0.35 else mother
	baby.variant = coat.variant % AnimalModels.variant_count(baby.species)
	baby.fullness = 85.0
	baby.hydration = 85.0
	baby.happiness = 85.0
	baby.affection = 140.0
	if rng.randf() < MALE_BORN:
		baby.male = true
		baby.name = _male_name(baby.species, baby)
	_young[baby.id] = {"phase": Phase.LYING, "t": 0.0, "nurse": rng.randf_range(8.0, 20.0), "nursing": false,
		"born_at": GameClock.total_minutes}
	var n := Animals.node_of(baby)
	var mom := Animals.node_of(mother)
	if n:
		n.refresh_body()
		_lay_down(n, mom)
	Events.animal_born.emit(baby.species)
	var first := BreedingGoals.first_born(baby)
	var msg := _t("MSG_ANIMAL_BORN") % [Animals.species_name(baby.species, false), mother.name, baby.name]
	if first:
		# The first of its kind: it waits for its name (the side goal's own note says so).
		msg = _t("MSG_FIRST_BORN_%s" % String(baby.species).to_upper()) % mother.name
	Game.notify(msg, Color(0.55, 1.0, 0.45))
	Animals.report_notes.append(msg)
	_refresh(mother)
	Animals.changed.emit()
	return baby


## The newborn's body down in the straw beside its mother (or where it stands without her).
static func _lay_down(n: Animal, mom: Animal) -> void:
	if mom != null and mom.is_inside_tree() and mom.housing == n.housing:
		var side := mom.global_basis.x * (mom.radius() + n.radius() + 0.25) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p := n.housing.constrain(mom.global_position + side, n.radius(), mom.indoors)
		p.y = n.housing.ground_height(p)
		n.global_position = p
		n.indoors = mom.indoors
		n.rotation.y = mom.rotation.y + rng.randf_range(-0.6, 0.6)
		n.reset_physics_interpolation()
	n._path.clear()
	n._path_inside.clear()
	n._set_state(Animal.State.SLEEP, 1e9)
	# Down already (not sinking onto its knees as it appears).
	n.rig._lie = 1.0


static func _refresh(a: AnimalData) -> void:
	var n := Animals.node_of(a)
	if n:
		n.refresh_body()


# --- The body (Animal's hooks) ------------------------------------------------------------------

## Animal.refresh_body: a grown male's size, horns and coat, a carrying female's belly and
## pace.
static func dress(n: Animal) -> void:
	var a := n.data
	if a == null or not breeds(a.species) or n.rig == null:
		return
	var grown_male := a.male and a.adult
	if grown_male:
		n.rig.scale *= float(MALE_SCALE.get(a.species, 1.0))
	n._move_speed = float(a.info().get("speed", 0.8)) * pace(a)
	n.rig.set_belly(progress(a))
	_set_horns(n.rig, grown_male and a.species == &"sheep")
	if grown_male and a.species == &"cow" and n.rig is PhotoRig:
		for mi in (n.rig as PhotoRig).meshes:
			mi.set_instance_shader_parameter(&"dark_tint", BULL_COAT[0])
			mi.set_instance_shader_parameter(&"light_tint", BULL_COAT[1])
			mi.set_instance_shader_parameter(&"recolor", 1.0)


## Animal.hint_prompt: the line under her prompts while she carries ("" otherwise).
static func hint(a: AnimalData) -> String:
	return status_text(a)


## Animal._decide: a young one with its mother does as she does (true: decided). Lying
## newborn, getting up, then keeping close: after her through the barn door, asleep by her
## at night, a drink or a mouthful at the troughs, nursing now and then, pottering about
## within a few steps of her.
static func decide(n: Animal) -> bool:
	var a := n.data
	if a.adult or a.mother == 0 or not breeds(a.species):
		return false
	var st := _state(a)
	if int(st["phase"]) == Phase.LYING:
		if n.state != Animal.State.SLEEP:
			n._set_state(Animal.State.SLEEP, 1e9)
		return true
	if int(st["phase"]) == Phase.RISING:
		return true
	var mom := n._mother_node()
	if mom == null:
		return false
	var to := mom.global_position - n.global_position
	var d := Vector2(to.x, to.z).length()
	var apart := n.indoors != mom.indoors
	var close := mom.radius() + n.radius() + 0.3
	var night := GameClock.is_night() or mom.state == Animal.State.SLEEP
	var moving := n.state in [Animal.State.WANDER, Animal.State.GO_EAT, Animal.State.GO_DRINK, Animal.State.SHELTER,
		Animal.State.BROOD] and not n._path.is_empty()
	if apart or d > (close + 0.7 if night else FOLLOW_FAR):
		# After her: hurrying when she is far off or on the other side of the door.
		n._hurry = 1.6 if apart or d > FOLLOW_RUN else 1.15
		st["nursing"] = false
		n._brood_to(_spot_by(n, mom, close + 0.25), mom.indoors)
		return true
	if moving:
		return true
	n._hurry = 1.0
	if night:
		if n.state != Animal.State.SLEEP:
			n._path.clear()
			n._path_inside.clear()
			n._face(mom.global_position)
			n._set_state(Animal.State.SLEEP, 1e9)
		return true
	if n.state == Animal.State.SLEEP:
		n._set_state(Animal.State.IDLE, n._rng.randf_range(0.8, 2.0))
		return true
	if bool(st["nursing"]):
		# At her flank: head under her, a few seconds of milk.
		st["nursing"] = false
		n._face(mom.global_position)
		n._set_state(Animal.State.EAT, n._rng.randf_range(NURSE_TIME.x, NURSE_TIME.y))
		a.fullness = minf(a.fullness + NURSE_FOOD, 100.0)
		a.happiness = minf(a.happiness + 2.0, 100.0)
		return true
	if n._busy():
		return true
	var water := n.housing.water
	var feed := n.housing.feed
	if a.hydration < 45.0 and water and not water.is_empty() and n.housing.is_in_building(water.global_position) == n.indoors:
		n._go(n._trough_spot(water), n.indoors, Animal.State.GO_DRINK)
		return true
	var standing := mom._speed < 0.05 and mom.state in [Animal.State.IDLE, Animal.State.GRAZE, Animal.State.EAT, Animal.State.DRINK]
	if float(st["nurse"]) <= 0.0 and standing:
		st["nurse"] = n._rng.randf_range(NURSE_EVERY.x, NURSE_EVERY.y)
		st["nursing"] = true
		n._brood_to(_flank(n, mom), mom.indoors)
		return true
	if a.fullness < 45.0 and feed and not feed.is_empty() and n.housing.is_in_building(feed.global_position) == n.indoors:
		n._go(n._trough_spot(feed), n.indoors, Animal.State.GO_EAT)
		return true
	var roll := n._rng.randf()
	if roll < 0.45 and not n.indoors and n._grazing_ok():
		n._set_state(Animal.State.GRAZE, n._rng.randf_range(4.0, 10.0))
	elif roll < 0.75:
		n._brood_to(_spot_by(n, mom, close + n._rng.randf_range(0.2, 1.6)), mom.indoors)
	else:
		n._set_state(Animal.State.IDLE, n._rng.randf_range(2.0, 5.0))
	return true


## Animal._physics_process: a newborn's first minutes (lying until the farmer comes near,
## then up on wobbly legs) and the wait between a young one's feeds.
static func tick(n: Animal, delta: float) -> void:
	var a := n.data
	# (One whose mother is gone still finishes getting up.)
	if a.adult or not breeds(a.species) or (a.mother == 0 and not _young.has(a.id)):
		return
	var st := _state(a)
	st["nurse"] = float(st["nurse"]) - delta
	match int(st["phase"]):
		Phase.LYING:
			var player := Game.player as Node3D
			var near := player != null and is_instance_valid(player) and player.global_position.distance_to(n.global_position) < RISE_NEAR
			if near or GameClock.total_minutes - float(st["born_at"]) > RISE_AFTER:
				st["phase"] = Phase.RISING
				st["t"] = 0.0
				n._set_state(Animal.State.IDLE, RISE_TIME)
				Audio.animal_voice(a.species, false, n.global_position + Vector3(0, 0.3, 0), -5.0)
		Phase.RISING:
			var t := float(st["t"]) + delta
			st["t"] = t
			# Trembling as it gets its legs under it, then two lurches before it stands.
			n.rig.tremble = 0.55 * (1.0 - smoothstep(1.6, RISE_TIME, t))
			n.rig.stumble = 0.7 * (_pulse(t, 2.0, 0.7) + _pulse(t, 3.1, 0.6))
			if t >= RISE_TIME:
				n.rig.tremble = 0.0
				n.rig.stumble = 0.0
				st["phase"] = Phase.UP
				n._think = 0.2


## A newborn out of its first lie-down (BreedingGoals asks for its name only then).
static func is_up(a: AnimalData) -> bool:
	if a.adult or a.mother == 0 or not breeds(a.species):
		return true
	return int(_state(a)["phase"]) == Phase.UP


## Whether `a` still lies where it was born.
static func lying(a: AnimalData) -> bool:
	return _young.has(a.id) and int(_young[a.id]["phase"]) == Phase.LYING


## Forgets the young ones' goings-on (a new game, a load).
static func reset() -> void:
	_young.clear()


static func _pulse(t: float, at: float, length: float) -> float:
	return sin(PI * clampf((t - at) / length, 0.0, 1.0))


## What young `a` is up to: made on first use (after a load: one born this very morning
## lies down again, any other is up).
static func _state(a: AnimalData) -> Dictionary:
	if not _young.has(a.id):
		var newborn := a.born_day == GameClock.day and a.growth <= 0.0
		_young[a.id] = {"phase": Phase.LYING if newborn else Phase.UP, "t": 0.0, "nurse": rng.randf_range(15.0, 60.0),
			"nursing": false, "born_at": GameClock.total_minutes}
	return _young[a.id]


## A spot `far` metres from its mother, each young one on its own side of her.
static func _spot_by(n: Animal, mom: Animal, far: float) -> Vector3:
	var k := float(n.data.id) * 2.39996 + n._rng.randf_range(-0.7, 0.7)
	var p := mom.global_position + Vector3(cos(k), 0.0, sin(k)) * far
	p = n.housing.constrain(p, n.radius(), mom.indoors)
	p.y = n.housing.ground_height(p)
	return p


## Where it stands to nurse: at her flank, the side it is on.
static func _flank(n: Animal, mom: Animal) -> Vector3:
	var right := mom.global_basis.x
	var side := 1.0 if (n.global_position - mom.global_position).dot(right) >= 0.0 else -1.0
	var p := mom.global_position + right * side * (mom.radius() + n.radius() + 0.02) + mom.global_basis.z * mom.radius() * 0.35
	p = n.housing.constrain(p, n.radius(), mom.indoors)
	p.y = n.housing.ground_height(p)
	return p


# --- The ram's horns ---------------------------------------------------------------------------

## Puts the ram's curled horns on (or takes them off) the head of `rig`: a mesh carried by
## the head bone, set so that at rest it stands in the rig's own axes at the bone.
static func _set_horns(rig: AnimalRig, on: bool) -> void:
	var have: Node = rig.skeleton.get_node_or_null(^"Horns") if rig.skeleton != null else null
	if not on:
		if have != null:
			have.name = "HornsGone"
			have.queue_free()
		return
	if have != null or rig.skeleton == null:
		return
	var head := rig._bone("head")
	if head < 0:
		return
	var at := BoneAttachment3D.new()
	at.name = "Horns"
	at.bone_idx = head
	rig.skeleton.add_child(at)
	var mi := MeshInstance3D.new()
	mi.mesh = _horns()
	# The head bone at rest, in the rig: the mesh (metres, the rig's axes, its origin at the
	# bone) is carried from there.
	var rest := rig._sk_xf * rig.skeleton.get_bone_global_rest(head)
	mi.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin)
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.layers = 2
	at.add_child(mi)


## Both horns (built once), metres in the animal's axes (x to its right, y up, z to its
## tail) from the head bone at the poll: each a ridged, tapering tube that rises from the
## top of the skull in front of the ear, winds back over it, down behind it and forward
## again beside the cheek, standing out from the head more and more as it goes.
static func _horns() -> ArrayMesh:
	if _horn_mesh != null:
		return _horn_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RINGS := 48
	const SIDES := 10
	for side: float in [1.0, -1.0]:
		var base := Vector3(HORN_BASE.x * side, HORN_BASE.y, HORN_BASE.z)
		var out := Vector3(side, 0.0, 0.0)
		var centres: Array[Vector3] = []
		var radii: Array[float] = []
		for i in RINGS + 1:
			var t := float(i) / RINGS
			var turn := t * HORN_TURN * TAU
			var wind := lerpf(HORN_WIND.x, HORN_WIND.y, t)
			centres.append(base - Vector3.UP * HORN_WIND.x + (Vector3.UP * cos(turn) + Vector3.BACK * sin(turn)) * wind
					+ out * HORN_SPREAD * pow(t, 0.75))
			radii.append(lerpf(HORN_THICK.x, HORN_THICK.y, pow(t, 0.85)) * (1.0 + 0.07 * sin(t * 80.0)))
		var verts: Array[Vector3] = []
		var normals: Array[Vector3] = []
		var colors: Array[Color] = []
		for i in RINGS + 1:
			var t := float(i) / RINGS
			var along := (centres[mini(i + 1, RINGS)] - centres[maxi(i - 1, 0)]).normalized()
			var a := along.cross(out).normalized()
			var b := along.cross(a).normalized()
			# Darker in the grooves and at the root, paler toward the tip.
			var shade := lerpf(0.7, 1.0, 0.5 + 0.5 * sin(t * 80.0)) * lerpf(0.78, 1.1, t)
			for j in SIDES:
				var ang := TAU * float(j) / SIDES
				var dir := a * cos(ang) + b * sin(ang)
				verts.append(centres[i] + dir * radii[i])
				normals.append(dir)
				colors.append(Color(0.47 * shade, 0.39 * shade, 0.29 * shade))
		for i in RINGS:
			for j in SIDES:
				var p0 := i * SIDES + j
				var p1 := i * SIDES + (j + 1) % SIDES
				var p2 := p0 + SIDES
				var p3 := p1 + SIDES
				for k: int in [p0, p2, p1, p1, p2, p3]:
					st.set_normal(normals[k])
					st.set_color(colors[k])
					st.add_vertex(verts[k])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.62
	mat.metallic_specular = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_horn_mesh = st.commit()
	return _horn_mesh
