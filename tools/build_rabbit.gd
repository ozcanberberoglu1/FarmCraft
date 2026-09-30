extends SceneTree
## Sculpts, skins and saves the wild rabbit (RabbitRig.sculpt) to RabbitRig.MODEL.
## Run: godot --headless --path . -s res://tools/build_rabbit.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RabbitRig.MODEL.get_base_dir()))
	var model := RabbitRig.sculpt().build()
	var ps := PackedScene.new()
	var err := ps.pack(model)
	if err == OK:
		err = ResourceSaver.save(ps, RabbitRig.MODEL, ResourceSaver.FLAG_COMPRESS)
	print("saved %s (%s)" % [RabbitRig.MODEL, error_string(err)])
	model.free()
	quit()
