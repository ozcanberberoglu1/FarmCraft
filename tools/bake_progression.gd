extends SceneTree
## Bakes only the workbench's new models (what tools/bake_tools.gd bakes for everything):
## the knife scan (ToolModels), the nail tin and the dough bowl scans (GoodsModels), and
## the workbench (PlaceableModels; the campfire is CampfireModel's). Then re-render their icons:
## godot --path . -s res://tools/icon_studio.gd -- --only=knife,bow,fishing_rod,campfire,nails,rope,worm,dough,sapling,workbench
## Run: godot --path . -s res://tools/bake_progression.gd  (with a renderer, not --headless)

const TOOLS: Array[StringName] = [&"knife"]
const GOODS: Array[StringName] = [&"nails_tin", &"dough_bowl"]
const PLACEABLES: Array[StringName] = [&"workbench"]


func _initialize() -> void:
	for id in TOOLS:
		_save(ToolModels.build(id), ToolModels.BAKED % id)
	for id in GOODS:
		_save(GoodsModels.build(id), GoodsModels.BAKED % id)
	for id in PLACEABLES:
		var built := PlaceableModels.build(id)
		for part: String in ["whole", "body", "moving"]:
			var path := PlaceableModels.BAKED % [id, part]
			var m: ArrayMesh = built.get(part)
			if m == null:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				continue
			_save(m, path)
	quit()


func _save(m: ArrayMesh, path: String) -> void:
	var err := ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS)
	print("baked %s (%s, %d surfaces)" % [path, "ok" if err == OK else "error %d" % err, m.get_surface_count()])
