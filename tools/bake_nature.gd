extends SceneTree
## Saves the scanned nature models (NatureModels.SCANS: rocks, ferns, nettles, fallen
## branches, stumps, logs) simplified and with their LODs to
## art/models/nature/baked/<scan>_<piece>.res, so the game doesn't simplify the dense
## scans at load. Rerun after changing SCANS or SCAN_LOOK's triangle limits.
## Run: godot --headless --path . -s res://tools/bake_nature.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NatureModels.SCAN_BAKED.get_base_dir()))
	for scan: String in NatureModels.SCANS:
		var pieces := NatureModels.build_scan(scan)
		for i in pieces.size():
			var path := NatureModels.SCAN_BAKED % [scan, i]
			var err := ResourceSaver.save(pieces[i], path, ResourceSaver.FLAG_COMPRESS)
			var tris := (pieces[i].get_surface_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			print("baked %s %d (%s, %d triangles, %d LODs) %s" % [scan, i, pieces[i].get_surface_name(0), tris,
					pieces[i].get_surface_lod_count(0), "ok" if err == OK else "error %d" % err])
		# A stale piece past the new count would be picked up as an extra one.
		var extra := pieces.size()
		while FileAccess.file_exists(ProjectSettings.globalize_path(NatureModels.SCAN_BAKED % [scan, extra])):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(NatureModels.SCAN_BAKED % [scan, extra]))
			extra += 1
	quit()
