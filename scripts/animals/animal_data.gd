class_name AnimalData
extends RefCounted
## Persistent state of one farm animal (the Animal node is just its body).

var id := 0
var species: StringName = &"cow"
var name := ""
var variant := 0
var adult := false
## Fed days counted toward adulthood.
var growth := 0.0
var fullness := 80.0
var hydration := 80.0
var happiness := 70.0
var health := 100.0
## 0..1000 (200 per heart).
var affection := 0.0
var petted_today := false
var brushed_today := false
var hand_fed_today := false
## Hours today with enough food (for growth and products).
var fed_hours := 0.0
var product_ready := false
var product_progress := 0.0
var wool := 1.0
var sick := false
var wet := 0.0
## Recent hours spent out in rain or snow (drives sickness).
var exposure := 0.0
var cold := false
## Horse left somewhere outside the pen by the rider.
var away := false
var away_pos := Vector3.ZERO
var away_yaw := 0.0
## Day this animal last gave birth (mothers rest a while before the next).
var last_birth_day := -100
## A chick's mother hen (her id; 0 for none): it follows her until it is grown.
var mother := 0
## Hurt by a wolf (GameClock.total_minutes it happened; -1 for sound): it limps, gives
## nothing and dies when Animals.INJURY_MINUTES have passed unless the vet treats it.
var injured_at := -1.0
## At the vet's clinic until this time (GameClock.total_minutes; -1 when on the farm): off
## the farm, it can't die meanwhile and comes back healed (Animals.send_to_vet).
var vet_until := -1.0
## The farmer was told its time is running out (Animals.INJURY_REMIND).
var injury_warned := false


## Hurt and not yet treated (also while it is at the clinic).
func injured() -> bool:
	return injured_at >= 0.0


## Away at the vet's clinic.
func at_vet() -> bool:
	return vet_until >= 0.0


func info() -> Dictionary:
	return AnimalTable.get_species(species)


func hearts() -> int:
	return clampi(int(affection / 200.0), 0, 5)


## A young bird (chicken or rooster) not grown yet.
func is_chick() -> bool:
	return not adult and AnimalTable.is_poultry(species)


## 0 baby .. 1 adult (drives body size).
func age_ratio() -> float:
	if adult:
		return 1.0
	return clampf(growth / float(info().get("grow_days", 5)), 0.0, 0.95)


func sale_value() -> int:
	var base: int = info().get("value", 100)
	var condition := 0.5 + 0.5 * (health / 100.0) * 0.6 + 0.2 * (happiness / 100.0)
	var age := 1.0 if adult else 0.35 + 0.35 * age_ratio()
	return maxi(10, roundi(base * condition * age * (1.0 + hearts() * 0.04)))


func to_dict() -> Dictionary:
	var d := {}
	for p in ["id", "name", "variant", "adult", "growth", "fullness", "hydration", "happiness", "health",
			"affection", "petted_today", "brushed_today", "hand_fed_today", "fed_hours", "product_ready",
			"product_progress", "wool", "sick", "wet", "exposure", "away", "away_yaw", "last_birth_day", "mother",
			"injured_at", "vet_until", "injury_warned"]:
		d[p] = get(p)
	d["species"] = String(species)
	d["away_pos"] = [away_pos.x, away_pos.y, away_pos.z]
	return d


static func from_dict(d: Dictionary) -> AnimalData:
	var a := AnimalData.new()
	for p in d:
		if p == "species":
			a.species = StringName(d[p])
		elif p == "away_pos":
			a.away_pos = Vector3(d[p][0], d[p][1], d[p][2])
		elif p in a:
			a.set(p, d[p])
	return a
