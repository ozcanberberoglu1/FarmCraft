@tool
class_name AnimalModels
extends RefCounted
## Livestock model factory and coat variants. The models themselves are sculpted
## offline (tools/build_animals.gd, see scripts/animals/sculpt/anatomy.gd).


## Coat variants per species (tints applied through instance shader parameters).
const VARIANTS := {
	&"cow": [
		{"coat": Color(0.95, 0.94, 0.92), "patch": Color(0.05, 0.045, 0.04), "patches": true, "hair": Color(0.9, 0.88, 0.85)},
		{"coat": Color(0.95, 0.92, 0.88), "patch": Color(0.4, 0.17, 0.07), "patches": true, "hair": Color(0.9, 0.88, 0.85)},
		{"coat": Color(0.64, 0.44, 0.26), "patch": Color(0.52, 0.34, 0.18), "hair": Color(0.2, 0.14, 0.1)},
	],
	&"horse": [
		{"coat": Color(0.46, 0.26, 0.13), "points": Color(0.08, 0.07, 0.06), "hair": Color(0.07, 0.06, 0.055)},
		{"coat": Color(0.62, 0.32, 0.14), "points": Color(0.55, 0.28, 0.12), "hair": Color(0.88, 0.76, 0.52)},
		{"coat": Color(0.11, 0.1, 0.095), "points": Color(0.08, 0.075, 0.07), "hair": Color(0.06, 0.055, 0.05)},
		{"coat": Color(0.8, 0.79, 0.77), "points": Color(0.48, 0.47, 0.46), "hair": Color(0.9, 0.89, 0.87)},
	],
	&"sheep": [
		{"coat": Color(0.95, 0.92, 0.84), "points": Color(0.88, 0.83, 0.75)},
		{"coat": Color(0.94, 0.9, 0.82), "points": Color(0.11, 0.1, 0.095)},
		{"coat": Color(0.5, 0.39, 0.29), "points": Color(0.32, 0.24, 0.17)},
	],
	&"chicken": [
		{"coat": Color(0.97, 0.96, 0.93)},
		{"coat": Color(0.58, 0.25, 0.09)},
		{"coat": Color(0.12, 0.12, 0.13)},
		{"coat": Color(0.88, 0.66, 0.36)},
	],
	# Red-and-black and white (PhotoRig.MODELS["rooster"] has the real ones).
	&"rooster": [
		{"coat": Color(0.6, 0.2, 0.07)},
		{"coat": Color(0.97, 0.96, 0.93)},
	],
}
## How far through growing up (AnimalData.age_ratio) a young bird keeps the downy chick
## body before it turns into a pullet (the hen's body, small): chick_days of grow_days.
const CHICK_UNTIL := 0.5


static func variant_count(species: StringName) -> int:
	return (VARIANTS.get(species, [{}]) as Array).size()


## The body an animal shows: its species' own, but young poultry are the downy chick
## (&"chick") for their first days, then a pullet on the hen's body (&"chicken"), cockerels
## too, until grown.
static func look_for(a: AnimalData) -> StringName:
	if not a.is_chick():
		return a.species
	var info := a.info()
	var until := float(info.get("chick_days", 2)) / maxf(float(info.get("grow_days", 4)), 1.0)
	if a.age_ratio() < until and PhotoRig.available(&"chick"):
		return &"chick"
	return &"chicken"


## The downloaded photo-textured model when it is in the project, otherwise the
## sculpted one. Animals move, so their meshes stay out of SDFGI voxelization and
## (as small clutter, visual layer 2) out of the rain-blocker heightfield.
static func create_rig(species: StringName, look := &"") -> AnimalRig:
	var model := look if look != &"" else species
	var rig: AnimalRig
	if PhotoRig.available(model):
		rig = PhotoRig.assemble_photo(model)
	elif AnimalRig.PARAMS.has(model) and ResourceLoader.exists(AnimalRig.SCULPT_PATH % model):
		rig = AnimalRig.assemble(model)
	else:
		# No model of its own (a rooster before his was built): the hen's.
		rig = AnimalRig.assemble(&"chicken") if not PhotoRig.available(&"chicken") else PhotoRig.assemble_photo(&"chicken")
	for g in rig.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		(g as GeometryInstance3D).layers = 2
	# Cartoon eyes on the poultry ("Komik hayvanlar" setting).
	ComicFx.dress_rig(rig)
	return rig


## Starts loading every species' model in the background, so the first rig of a
## kind (the world-build warm-up, a purchase, a birth) does not wait on the disk.
static func preload_models() -> void:
	for species: StringName in VARIANTS.keys() + [&"chick"]:
		if PhotoRig.available(species):
			AnimalRig.request_scene(species, PhotoRig.source_file(species))
		elif ResourceLoader.exists(AnimalRig.SCULPT_PATH % species):
			AnimalRig.request_scene(species, AnimalRig.SCULPT_PATH % species)
