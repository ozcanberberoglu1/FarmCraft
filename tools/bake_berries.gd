extends SceneTree
## Builds the wild berry bushes (BerryModels: twigs cut from the Poly Haven shrub scans,
## mounded into bushes, their berries hung on the outer leaves) and saves them to
## art/models/nature/baked/berry_<kind>_<variant>.res and ..._fruit.res, with their LODs.
## Rerun after changing BerryModels.LOOK or refetching the scans (tools/fetch_wild.py).
## Run: godot --headless --path . -s res://tools/bake_berries.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BerryModels.BAKED.get_base_dir()))
	for kind: StringName in BerryModels.KINDS:
		for v in BerryModels.VARIANTS:
			var t := Time.get_ticks_msec()
			var meshes := BerryModels.build_bush(kind, v)
			for i in 2:
				var m: ArrayMesh = meshes[i]
				var path := BerryModels.BAKED % [kind, v, "_fruit" if i == 1 else ""]
				var err := ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS)
				var tris := (m.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				print("baked %s (%d triangles, %d LODs, %s) in %d ms" % [path, tris, m.surface_get_lod_count(0) if m.has_method("surface_get_lod_count") else 0,
						"ok" if err == OK else "error %d" % err, Time.get_ticks_msec() - t])
	quit()
