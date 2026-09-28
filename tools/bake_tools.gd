extends SceneTree
## Bakes the scanned tool models (ToolModels.MODELS) into item space and saves them
## to art/models/tools/baked/<id>.res, the produce and goods (GoodsModels) to
## art/models/items/baked/, the crop plants (PlantModels, fresh and withered) to
## art/models/crops/baked/, and the placeable machines (PlaceableModels) and the manure
## heap's mounds (ManureHeap) to art/models/props/baked/. Rerun after changing either, then re-render the icons:
## godot --path . -s res://tools/icon_studio.gd -- --only=<ids>
## Run: godot --path . -s res://tools/bake_tools.gd
## (with a renderer, not --headless: the dummy renderer may drop the meshes' LODs.)
##
## Textures a scan's importer generated (the wheat's spec-gloss material becomes two
## 2048² images) would be copied, uncompressed, into every baked file. They are written
## once to SCAN_TEX as PNGs instead; after a bake that wrote new ones, import them (VRAM
## compressed, with mipmaps) and bake again, and the meshes point at them.

## Scans whose generated textures go to files of their own: item or crop id -> folder.
const SCAN_TEX := {&"wheat": "res://art/models/crops/wheat/baked_tex/"}
## Material slots checked for generated textures, and their PNG name prefixes.
const TEX_SLOTS := {
	BaseMaterial3D.TEXTURE_ALBEDO: "albedo", BaseMaterial3D.TEXTURE_ROUGHNESS: "roughness",
	BaseMaterial3D.TEXTURE_METALLIC: "metallic", BaseMaterial3D.TEXTURE_NORMAL: "normal",
	BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION: "ao",
}

## Generated texture -> its PNG (one file per texture, whichever meshes share it).
var _pngs := {}


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path((ToolModels.BAKED % "x").get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir)
	for id: StringName in ToolModels.MODELS:
		var m := ToolModels.build(id)
		var path := ToolModels.BAKED % id
		var err := ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS)
		print("baked %s -> %s (%s)" % [id, path, "ok" if err == OK else "error %d" % err])
	# Produce and goods.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path((GoodsModels.BAKED % "x").get_base_dir()))
	for id: StringName in GoodsModels.MODELS:
		if not ResourceLoader.exists(GoodsModels.MODELS[id]["path"]):
			print("skipped %s (source model missing)" % id)
			continue
		var m := GoodsModels.build(id)
		if SCAN_TEX.has(id):
			_externalize(m, SCAN_TEX[id])
		var err := ResourceSaver.save(m, GoodsModels.BAKED % id, ResourceSaver.FLAG_COMPRESS)
		print("baked %s (%s, %d surfaces, %d vertices)" % [id, "ok" if err == OK else "error %d" % err, m.get_surface_count(), _vertex_count(m)])
		if GoodsModels.LOW.has(id):
			var low := GoodsModels.decimated(m, GoodsModels.LOW[id])
			err = ResourceSaver.save(low, GoodsModels.BAKED_LOW % id, ResourceSaver.FLAG_COMPRESS)
			print("baked %s_low (%s, %d triangles)" % [id, "ok" if err == OK else "error %d" % err, _triangle_count(low)])
	# Crop plants, one per crop and growth stage, and its withered copy.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path((PlantModels.BAKED % ["x", 0]).get_base_dir()))
	for crop: StringName in PlantModels.CROPS:
		for stage in 4:
			var m := PlantModels.build_unit(crop, stage)
			if SCAN_TEX.has(crop):
				_externalize(m, SCAN_TEX[crop])
			var err := ResourceSaver.save(m, PlantModels.BAKED % [crop, stage], ResourceSaver.FLAG_COMPRESS)
			print("baked plant %s/%d (%s, %d surfaces, %d vertices)" % [crop, stage, "ok" if err == OK else "error %d" % err, m.get_surface_count(), _vertex_count(m)])
			err = ResourceSaver.save(PlantModels._browned(m), PlantModels.BAKED_W % [crop, stage], ResourceSaver.FLAG_COMPRESS)
			print("baked withered plant %s/%d (%s)" % [crop, stage, "ok" if err == OK else "error %d" % err])
	# Placeable machines (and the town's order board): whole, body and moving meshes.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path((PlaceableModels.BAKED % ["x", "x"]).get_base_dir()))
	var ids: Array = PlaceableTable.PLACEABLES.keys()
	ids.append(&"order_board")
	for id: StringName in ids:
		var built := PlaceableModels.build(id)
		for part: String in ["whole", "body", "moving"]:
			var m: ArrayMesh = built.get(part)
			var path := PlaceableModels.BAKED % [id, part]
			if m == null:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				continue
			var err := ResourceSaver.save(m, path, ResourceSaver.FLAG_COMPRESS)
			print("baked %s/%s (%s, %d surfaces)" % [id, part, "ok" if err == OK else "error %d" % err, m.get_surface_count()])
	# The manure heap's mound at every size step.
	for step in range(1, ManureMound.steps() + 1):
		var m := ManureMound.build(step)
		var err := ResourceSaver.save(m, ManureMound.BAKED % step, ResourceSaver.FLAG_COMPRESS)
		print("baked manure heap %d (%s, %d vertices)" % [step, "ok" if err == OK else "error %d" % err, _vertex_count(m)])
	quit()


## Points the materials of `m` at PNG copies of their generated textures (written on
## the first bake, used once the editor has imported them).
func _externalize(m: ArrayMesh, dir: String) -> void:
	for si in m.get_surface_count():
		var mat := m.surface_get_material(si) as BaseMaterial3D
		if mat == null:
			continue
		for slot: BaseMaterial3D.TextureParam in TEX_SLOTS:
			var tex := mat.get_texture(slot)
			# Textures loaded from a file of their own are referenced as they are.
			if tex == null or not (tex.resource_path.is_empty() or tex.resource_path.contains("::")):
				continue
			if not _pngs.has(tex):
				_pngs[tex] = _png_of(tex, dir, TEX_SLOTS[slot])
			var png: String = _pngs[tex]
			if not png.is_empty() and ResourceLoader.exists(png):
				mat.set_texture(slot, load(png) as Texture2D)


## Writes `tex` to a PNG in `dir`, named by its slot and its content (so every bake
## finds the same file), unless it is there already; returns its path.
func _png_of(tex: Texture2D, dir: String, slot_name: String) -> String:
	var img := tex.get_image()
	if img == null:
		return ""
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	var path := dir + "%s_%08x.png" % [slot_name, hash(img.get_data())]
	if not FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var err := img.save_png(ProjectSettings.globalize_path(path))
		print("wrote %s (%s)" % [path, "ok" if err == OK else "error %d" % err])
	if not ResourceLoader.exists(path):
		print("%s is not imported yet: this bake keeps its texture inside the meshes; import it and bake again" % path)
	return path


static func _vertex_count(m: ArrayMesh) -> int:
	var n := 0
	for si in m.get_surface_count():
		n += (m.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


static func _triangle_count(m: ArrayMesh) -> int:
	var n := 0
	for si in m.get_surface_count():
		n += (m.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return n
