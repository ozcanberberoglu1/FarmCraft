class_name VehicleLook
extends RefCounted
## Materials that dress a vehicle model from its VehicleTable entry: clear-coated,
## weathered body paint (vehicle_paint), trim with chrome, dust and rust (vehicle_trim),
## tyres, rims and brakes (vehicle_wheel), a cab interior out of the sky's light and
## Turkish number plates; and the modelled parts that stand in for the model's own
## (add_detail). Used by Vehicle and by tools/vehicle_portraits.gd (which runs without
## the game's autoloads, so nothing here may use them).

## Wear textures of the paint and trim shaders (Poly Haven, CC0): painted steel with
## rust pitting (its spots are the rust mask) and coarse rust scale.
const PIT_TEX := "res://art/textures/rusty_metal_02/rusty_metal_02_%s.jpg"
const SCALE_TEX := "res://art/textures/rust_coarse_01/rust_coarse_01_%s.jpg"
## Share of the ambient (sky and bounce) light that reaches inside the cab.
const CAB_AMBIENT := 0.4
## The modelled wheels' materials (tools/build_pickup_hd.py), in the order of
## vehicle_wheel.gdshader's `part`.
const WHEEL_PARTS := ["Tire_Rubber", "Tire_Rim", "Tire_Hardware", "Tire_Brake"]

## Number plate quads by plate box and texture.
static var _plate_cache := {}
## Modelled parts by scene path: node name -> mesh.
static var _detail_cache := {}
## Small single-colour textures by colour (untextured source materials).
static var _flat_cache := {}


## The entry's model, ready to dress: the downloaded (or Blender-built) scene with its
## modelled wheels ("detail"), the load baked into its bed cut away ("strip_parts"),
## the parts another body replaces taken off ("hide_parts": node names containing one
## of them) and that body added ("extra": a scene in the same model frame).
static func build_model(info: Dictionary) -> Node3D:
	var model := (load(info["model"]) as PackedScene).instantiate() as Node3D
	if info.has("detail"):
		add_detail(model, info["detail"])
	var hide: Array = info.get("hide_parts", [])
	if not hide.is_empty():
		var gone: Array[Node] = []
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for part: String in hide:
				if part in String(mi.name):
					gone.append(mi)
					break
		for n in gone:
			n.get_parent().remove_child(n)
			n.free()
	if info.has("strip_parts"):
		ModelStrip.strip_parts(model, info["strip_parts"][0], info["strip_parts"][1])
	if info.has("extra"):
		var extra := (load(info["extra"]) as PackedScene).instantiate() as Node3D
		extra.name = "Extra"
		model.add_child(extra)
	return model


## What the dressing shaders make of a source material, by its name: "paint" (a name
## with "Bodymat"), "trim" (the pickup's "UCB_BOTTOM" atlas, or "Trim_<kind>"),
## "interior" ("Interior"), "wheel" ("Tire_*"), or "" (left as it is, or a lamp or
## pane that Vehicle dresses by the mesh's name).
static func role_of(src: BaseMaterial3D) -> String:
	var n := src.resource_name
	if "Bodymat" in n:
		return "paint"
	if "UCB_BOTTOM" in n or n.begins_with("Trim_"):
		return "trim"
	if "Interior" in n:
		return "interior"
	if "Tire" in n:
		return "wheel"
	return ""


## The shader material for a surface whose source material has a dressing role (see
## role_of), made once per vehicle and kept in `mats` (one paint for the whole body,
## one per trim, cab or wheel material); null when it has none.
static func surface_material(src: BaseMaterial3D, info: Dictionary, mats: Dictionary) -> ShaderMaterial:
	var role := role_of(src)
	if role == "":
		return null
	var key := "paint" if role == "paint" else "%s:%s" % [role, src.resource_name]
	if not mats.has(key):
		match role:
			"paint":
				mats[key] = paint(src, info)
			"trim":
				mats[key] = trim(src, info)
			"interior":
				mats[key] = interior(src)
			_:
				mats[key] = wheel(src, info)
	return mats[key]


## A 4 x 4 texture of one colour, standing in for an untextured material's map.
static func flat_texture(c: Color) -> Texture2D:
	var key := c.to_html()
	if not _flat_cache.has(key):
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(c)
		_flat_cache[key] = ImageTexture.create_from_image(img)
	return _flat_cache[key]


## The source's colour map, or its colour as a flat one.
static func albedo_of(src: BaseMaterial3D) -> Texture2D:
	return src.albedo_texture if src.albedo_texture else flat_texture(Color(src.albedo_color, 1.0))


## The source's occlusion / roughness / metal map, or its roughness and metalness as a flat one.
static func orm_of(src: BaseMaterial3D) -> Texture2D:
	return src.metallic_texture if src.metallic_texture else flat_texture(Color(1.0, src.roughness, src.metallic))


## Modelled parts that stand in for the downloaded model's own (tools/build_pickup_hd.py):
## a mesh of the scene at `path` replaces the model's mesh of the same node name, in
## that node's frame (it fills the same box, so wheel radius and pivots stay). Where
## it names one of the old mesh's materials, that material stays on.
static func add_detail(model: Node3D, path: String) -> void:
	if not _detail_cache.has(path):
		var found := {}
		var parts := (load(path) as PackedScene).instantiate()
		for mi: MeshInstance3D in parts.find_children("*", "MeshInstance3D", true, false):
			found[String(mi.name)] = mi.mesh
		parts.free()
		_detail_cache[path] = found
	var meshes: Dictionary = _detail_cache[path]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = meshes.get(String(mi.name))
		if mesh == null:
			continue
		var own := {}
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si)
			if m:
				own[m.resource_name] = m
		mi.mesh = mesh
		for si in mesh.get_surface_count():
			var m := mesh.surface_get_material(si)
			if m and own.has(m.resource_name):
				mi.set_surface_override_material(si, own[m.resource_name])


## Body paint from the model's paint material (its panel-line normals and occlusion)
## and the entry's "paint" look.
static func paint(src: BaseMaterial3D, info: Dictionary) -> ShaderMaterial:
	var look: Dictionary = (info.get("paint", {"paint": Color(0.07, 0.12, 0.26)}) as Dictionary).duplicate()
	look.merge(info.get("body_shape", {}), true)
	var mat := _shader_mat("res://shaders/vehicle_paint.gdshader", look, info)
	if src.normal_texture:
		mat.set_shader_parameter("normal_tex", src.normal_texture)
		mat.set_shader_parameter("has_normal", true)
	if src.ao_texture:
		mat.set_shader_parameter("ao_tex", src.ao_texture)
	set_wear_textures(mat)
	return mat


## Bumpers, bull bar, underbody and bed trim from the model's trim atlas and the
## entry's "trim" look. A "Trim_<kind>" material (Blender-built parts) has no atlas:
## its own colour, roughness and metalness, or the photo texture its "trims" look names
## ("tex", art/textures/<tex>/: colour and ARM maps on the mesh's UVs), with no lamp
## sprites or tail lamps; the look of that kind goes over the vehicle's.
static func trim(src: BaseMaterial3D, info: Dictionary) -> ShaderMaterial:
	var look: Dictionary = (info.get("trim", {}) as Dictionary).duplicate()
	look.merge(info.get("body_shape", {}), true)
	var tex := ""
	if not "UCB_BOTTOM" in src.resource_name:
		look.merge({"tail_x": -99.0, "lens_rect": Vector3(9, 9, 9)}, true)
		var kind := src.resource_name.trim_prefix("Trim_")
		look.merge((info.get("trims", {}) as Dictionary).get(kind, {}), true)
		tex = String(look.get("tex", ""))
		look.erase("tex")
	var mat := _shader_mat("res://shaders/vehicle_trim.gdshader", look, info)
	if tex != "":
		mat.set_shader_parameter("albedo_tex", Mats.texture(tex, "diff.jpg"))
		mat.set_shader_parameter("orm_tex", Mats.texture(tex, "arm.jpg"))
	else:
		mat.set_shader_parameter("albedo_tex", albedo_of(src))
		mat.set_shader_parameter("orm_tex", orm_of(src))
	set_wear_textures(mat)
	return mat


## A tyre, rim, hardware or brake material of the modelled wheels (by the name of
## `src`, see WHEEL_PARTS) with the entry's "wheel" look.
static func wheel(src: BaseMaterial3D, info: Dictionary) -> ShaderMaterial:
	var mat := _shader_mat("res://shaders/vehicle_wheel.gdshader", info.get("wheel", {}), info)
	mat.set_shader_parameter("part", maxi(WHEEL_PARTS.find(src.resource_name), 0))
	mat.set_shader_parameter("pit_albedo", load(PIT_TEX % "diff"))
	return mat


## The cab interior (vehicle_interior): the atlas marks most of the dash and door cards
## as metal, here moulded plastic and vinyl; the mirror glass and chrome stay mirrors.
## The body stays out of SDFGI (it moves), so the cab would get the open sky's bounce
## light as if it had no roof: it is occluded down to what the windows let in.
static func interior(src: BaseMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vehicle_interior.gdshader")
	if src.albedo_texture:
		mat.set_shader_parameter("albedo_tex", src.albedo_texture)
		mat.set_shader_parameter("tint", src.albedo_color)
	else:
		# Untextured (Blender-built cabs): the colour is the tint over white.
		mat.set_shader_parameter("albedo_tex", flat_texture(Color.WHITE))
		mat.set_shader_parameter("tint", Color(src.albedo_color, 1.0))
	mat.set_shader_parameter("orm_tex", orm_of(src))
	mat.set_shader_parameter("cab_ambient", CAB_AMBIENT)
	return mat


## Gives a paint or trim shader its wear textures.
static func set_wear_textures(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("pit_albedo", load(PIT_TEX % "diff"))
	mat.set_shader_parameter("pit_normal", load(PIT_TEX % "nor"))
	mat.set_shader_parameter("scale_albedo", load(SCALE_TEX % "diff"))
	mat.set_shader_parameter("scale_normal", load(SCALE_TEX % "nor"))


## Tells a paint or trim mesh where its own space sits in the model frame (front +X,
## up +Y, right +Z, ground at 0): the rows of that transform, as instance uniforms.
static func fit_frame(mi: GeometryInstance3D, model: Node3D) -> void:
	var xf := model.global_transform.affine_inverse() * mi.global_transform
	var b := xf.basis
	mi.set_instance_shader_parameter("frame_x", Vector4(b.x.x, b.y.x, b.z.x, xf.origin.x))
	mi.set_instance_shader_parameter("frame_y", Vector4(b.x.y, b.y.y, b.z.y, xf.origin.y))
	mi.set_instance_shader_parameter("frame_z", Vector4(b.x.z, b.y.z, b.z.z, xf.origin.z))


## The model's plates carry US-style lettering: a Turkish plate (drawn by
## tools/make_vehicle_plates.py) goes on the face of each, just in front of it.
static func add_plate(mi: MeshInstance3D, texture_path: String) -> void:
	var box := mi.get_aabb()
	var key := "%s|%s" % [box, texture_path]
	if not _plate_cache.has(key):
		# The flat face inside the bevel, on the plate's front (+Z).
		var lo := Vector2(box.position.x + 0.008, box.position.y + 0.006)
		var hi := Vector2(box.end.x - 0.008, box.end.y - 0.006)
		var z := box.end.z + 0.0012
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(lo.x, lo.y, z), Vector3(hi.x, lo.y, z),
				Vector3(hi.x, hi.y, z), Vector3(lo.x, hi.y, z)])
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
		var quad := ArrayMesh.new()
		quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(texture_path)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Embossed, slightly glossy sheeting.
		mat.roughness = 0.5
		quad.surface_set_material(0, mat)
		_plate_cache[key] = quad
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = _plate_cache[key]
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.add_child(plate)


## A material of `shader` with `params`; the road dust takes the paint's dust colour.
static func _shader_mat(shader: String, params: Dictionary, info: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(shader)
	var look: Dictionary = info.get("paint", {})
	if look.has("dirt_color"):
		mat.set_shader_parameter("dirt_color", look["dirt_color"])
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	return mat
