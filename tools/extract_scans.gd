extends SceneTree
## Copies single models out of a big downloaded glTF pack into the project, so only
## what the game uses is kept (the Sketchfab fruit & vegetable pack is 145 MB).
## Each pick is saved as art/models/items/<folder>/<name>.gltf with its textures.
## Run: godot --headless --path . -s res://tools/extract_scans.gd -- --src=<pack.gltf>
##      --out=<res folder> --pick=<node prefix>:<name>,...

func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(String(args["src"]), state) != OK:
		push_error("can't read " + String(args["src"]))
		quit(1)
		return
	var scene := doc.generate_scene(state)
	for pick: String in String(args["pick"]).split(","):
		var prefix := pick.get_slice(":", 0)
		var out_name := pick.get_slice(":", 1)
		var found: MeshInstance3D = null
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).begins_with(prefix):
				found = mi
				break
		if found == null:
			push_error("no mesh named %s*" % prefix)
			continue
		var root_node := Node3D.new()
		root_node.name = out_name
		var mi := MeshInstance3D.new()
		mi.name = out_name
		mi.mesh = found.mesh
		# Keep the scan's own orientation and scale relative to the pack root.
		mi.transform = found.global_transform if found.is_inside_tree() else _to_root(found, scene)
		root_node.add_child(mi)
		mi.owner = root_node
		var folder := String(args["out"]).path_join(out_name)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var out_doc := GLTFDocument.new()
		var out_state := GLTFState.new()
		out_doc.append_from_scene(root_node, out_state)
		var err := out_doc.write_to_filesystem(out_state, ProjectSettings.globalize_path(folder.path_join(out_name + ".gltf")))
		print("%s -> %s (%s)" % [prefix, folder, "ok" if err == OK else "error %d" % err])
		root_node.free()
	scene.free()
	quit()


static func _to_root(n: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
