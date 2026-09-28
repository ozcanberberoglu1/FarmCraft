extends SceneTree
## Prints a downloaded model's node tree, skeleton (bone hierarchy with rest
## positions in the model's frame, Y up), animation clips and materials, to fill
## PhotoRig.MODELS. Run: godot --headless --path . -s res://tools/inspect_model.gd -- --only=cow


func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for species: StringName in [&"cow", &"horse", &"sheep", &"chicken"]:
		if only != "" and String(species) != only:
			continue
		var file := PhotoRig.source_file(species)
		if file == "":
			print("== %s: no model" % species)
			continue
		print("== %s: %s" % [species, file])
		var scene: PackedScene = load(file)
		var model := scene.instantiate() as Node3D
		root.add_child(model)
		_print_tree(model, 0)
		for sk: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
			var to_model := PhotoRig._rel(sk, model)
			print("-- skeleton %s: %d bones, global scale %s" % [sk.name, sk.get_bone_count(), to_model.basis.get_scale()])
			for i in sk.get_bone_count():
				var depth := 0
				var p := sk.get_bone_parent(i)
				while p >= 0:
					depth += 1
					p = sk.get_bone_parent(p)
				var pos := to_model * sk.get_bone_global_rest(i).origin
				print("%s%d %s  (%.3f, %.3f, %.3f)" % ["  ".repeat(depth), i, sk.get_bone_name(i), pos.x, pos.y, pos.z])
		for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
			for anim_name in ap.get_animation_list():
				var anim := ap.get_animation(anim_name)
				print("-- clip '%s' %.2fs, %d tracks" % [anim_name, anim.length, anim.get_track_count()])
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var aabb := PhotoRig._rel(mi, model) * mi.get_aabb()
			print("-- mesh %s (parent %s, skeleton %s): %d surfaces, skin=%s, aabb %s" % [mi.name, mi.get_parent().name,
				mi.skeleton, mi.mesh.get_surface_count(), mi.skin != null, aabb])
			for si in mi.mesh.get_surface_count():
				var m := mi.get_active_material(si)
				var desc := str(m)
				if m is StandardMaterial3D:
					var sm := m as StandardMaterial3D
					desc = "albedo=%s tex=%s normal=%s rough_tex=%s transp=%d cull=%d" % [
						sm.albedo_color, sm.albedo_texture.resource_path.get_file() if sm.albedo_texture else "-",
						sm.normal_texture.resource_path.get_file() if sm.normal_texture else "-",
						sm.roughness_texture.resource_path.get_file() if sm.roughness_texture else "-",
						sm.transparency, sm.cull_mode]
				print("     surface %d: %s" % [si, desc])
		model.queue_free()
	quit()


func _print_tree(n: Node, depth: int) -> void:
	var extra := ""
	if n is Node3D:
		var t := (n as Node3D).transform
		extra = " pos=%s rot=%s scale=%s" % [t.origin, (n as Node3D).rotation_degrees, t.basis.get_scale()]
	print("%s%s [%s]%s" % ["  ".repeat(depth), n.name, n.get_class(), extra])
	if depth < 14:
		for c in n.get_children():
			_print_tree(c, depth + 1)
