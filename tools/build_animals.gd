extends SceneTree
## Sculpts, skins and saves the livestock models to art/models/animals/<species>.scn.
## Run: godot --headless --path . -s res://tools/build_animals.gd [-- --only=cow,horse]

const OUT := "res://art/models/animals/"


func _initialize() -> void:
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for species in ["cow", "horse", "sheep", "chicken"]:
		if not only.is_empty() and species not in only:
			continue
		print("building ", species)
		var ab: AnimalBuilder
		match species:
			"cow": ab = Anatomy.cow()
			"horse": ab = Anatomy.horse()
			"sheep": ab = Anatomy.sheep()
			_: ab = Anatomy.chicken()
		var model := ab.build()
		var ps := PackedScene.new()
		var err := ps.pack(model)
		if err != OK:
			push_error("pack failed for %s: %s" % [species, error_string(err)])
			continue
		err = ResourceSaver.save(ps, OUT + species + ".scn", ResourceSaver.FLAG_COMPRESS)
		print("  saved %s (%s)" % [OUT + species + ".scn", error_string(err)])
		model.free()
	quit()
