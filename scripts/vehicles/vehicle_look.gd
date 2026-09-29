class_name VehicleLook
extends RefCounted
## Materials that dress a vehicle model from its VehicleTable entry: clear-coated,
## weathered body paint (vehicle_paint), trim with chrome, dust and rust (vehicle_trim),
## rubber and rims (vehicle_wheel), a cab interior out of the sky's light and Turkish
## number plates. Used by Vehicle and by tools/vehicle_portraits.gd (which runs without
## the game's autoloads, so nothing here may use them).

## Wear textures of the paint and trim shaders (Poly Haven, CC0): painted steel with
## rust pitting (its spots are the rust mask) and coarse rust scale.
const PIT_TEX := "res://art/textures/rusty_metal_02/rusty_metal_02_%s.jpg"
const SCALE_TEX := "res://art/textures/rust_coarse_01/rust_coarse_01_%s.jpg"
## Share of the ambient (sky and bounce) light that reaches inside the cab.
const CAB_AMBIENT := 0.4

## Number plate quads by plate box and texture.
static var _plate_cache := {}


## Body paint from the model's paint material (its panel-line normals and occlusion)
## and the entry's "paint" look.
static func paint(src: StandardMaterial3D, info: Dictionary) -> ShaderMaterial:
	var mat := _shader_mat("res://shaders/vehicle_paint.gdshader", info.get("paint", {"paint": Color(0.07, 0.12, 0.26)}), info)
	if src.normal_texture:
		mat.set_shader_parameter("normal_tex", src.normal_texture)
		mat.set_shader_parameter("has_normal", true)
	if src.ao_texture:
		mat.set_shader_parameter("ao_tex", src.ao_texture)
	set_wear_textures(mat)
	return mat


## Bumpers, bull bar, underbody and bed trim from the model's trim atlas and the
## entry's "trim" look.
static func trim(src: StandardMaterial3D, info: Dictionary) -> ShaderMaterial:
	var mat := _shader_mat("res://shaders/vehicle_trim.gdshader", info.get("trim", {}), info)
	mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	mat.set_shader_parameter("orm_tex", src.metallic_texture)
	set_wear_textures(mat)
	return mat


## Tyres and rims from the model's tyre atlas and the entry's "wheel" look.
static func wheel(src: StandardMaterial3D, info: Dictionary) -> ShaderMaterial:
	var mat := _shader_mat("res://shaders/vehicle_wheel.gdshader", info.get("wheel", {}), info)
	mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	mat.set_shader_parameter("orm_tex", src.metallic_texture)
	mat.set_shader_parameter("pit_albedo", load(PIT_TEX % "diff"))
	return mat


## The cab interior (vehicle_interior): the atlas marks most of the dash and door cards
## as metal, here moulded plastic and vinyl; the mirror glass and chrome stay mirrors.
## The body stays out of SDFGI (it moves), so the cab would get the open sky's bounce
## light as if it had no roof: it is occluded down to what the windows let in.
static func interior(src: StandardMaterial3D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vehicle_interior.gdshader")
	mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	mat.set_shader_parameter("orm_tex", src.metallic_texture)
	mat.set_shader_parameter("tint", src.albedo_color)
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
