@tool
class_name FishModels
extends RefCounted
## The fishing models (tools/blender/make_fishing.py, art/models/fish): every fish and
## its cooked variant, the crayfish, the old boot, the fishing rod and its float.
##   real_mesh: as modelled, at the species' typical size (fish lie along +X, head
##     forward, back up, centred on their length; the rod stands along +Y with the hand
##     at the origin; the float's waterline is at the origin).
##   mesh: the item's model (held, dropped, icons): fish sized to a hand's length.
##   flop_mesh: the real mesh drawn with shaders/fish.gdshader, whose body bends by the
##     instance parameters flex (tail beat, 0..1), flex_phase (radians) and curl (arch).

const DIR := "res://art/models/fish/"
## The rod's tip ring (the line leaves it) in its model space.
const ROD_TIP := Vector3(0.0, 1.667, 0.0)
## Item-size fish are this long (a small fish keeps its size).
const ITEM_LEN_MIN := 0.2
const ITEM_LEN_MAX := 0.34

static var _real := {}
static var _item := {}
static var _flop := {}
static var _flop_mats := {}


static func has(id: StringName) -> bool:
	return ResourceLoader.exists(DIR + String(id) + ".gltf")


## The model as built, joined into one mesh (cached).
static func real_mesh(id: StringName) -> ArrayMesh:
	if _real.has(id):
		return _real[id]
	var m: ArrayMesh = null
	var path := DIR + String(id) + ".gltf"
	if ResourceLoader.exists(path):
		var surfaces := []
		MeshMerge.add_parts(surfaces, MeshMerge.scene_parts(load(path) as PackedScene))
		m = MeshMerge.build(MeshMerge.by_material(surfaces), 40000)
	else:
		m = ArrayMesh.new()
	_real[id] = m
	return m


## The item's model: fish scaled to fit the hand; the rod, float and boot as they are.
static func mesh(id: StringName) -> ArrayMesh:
	if _item.has(id):
		return _item[id]
	var real := real_mesh(id)
	var m := real
	var sid := String(id)
	if sid.begins_with("fish_") and real.get_surface_count() > 0:
		var aabb := real.get_aabb()
		var length := aabb.size.x
		var want := clampf(length, ITEM_LEN_MIN, ITEM_LEN_MAX)
		var s := want / maxf(length, 0.001)
		var surfaces := []
		MeshMerge.add_mesh(surfaces, real, Transform3D(Basis.from_scale(Vector3.ONE * s), -aabb.get_center() * s))
		m = MeshMerge.build(surfaces, 40000)
	_item[id] = m
	return m


## The real mesh with the bending fish shader on every surface.
static func flop_mesh(id: StringName) -> ArrayMesh:
	if _flop.has(id):
		return _flop[id]
	var real := real_mesh(id)
	var m := real.duplicate() as ArrayMesh
	var half := maxf(real.get_aabb().size.x * 0.5, 0.01)
	for si in m.get_surface_count():
		m.surface_set_material(si, flop_material(real.surface_get_material(si), half))
	_flop[id] = m
	return m


## A bending copy of a model's material (shared by every fish of the species).
static func flop_material(source: Material, half_length: float) -> ShaderMaterial:
	var key := [source, snappedf(half_length, 0.001)]
	if _flop_mats.has(key):
		return _flop_mats[key]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/fish.gdshader")
	sm.set_shader_parameter("half_length", half_length)
	var std := source as BaseMaterial3D
	if std:
		sm.set_shader_parameter("albedo", std.albedo_color)
		if std.albedo_texture:
			sm.set_shader_parameter("albedo_tex", std.albedo_texture)
			sm.set_shader_parameter("has_albedo_tex", true)
		if std.normal_enabled and std.normal_texture:
			sm.set_shader_parameter("normal_tex", std.normal_texture)
			sm.set_shader_parameter("has_normal_tex", true)
			sm.set_shader_parameter("normal_scale", std.normal_scale)
		sm.set_shader_parameter("roughness", std.roughness)
		sm.set_shader_parameter("metallic", std.metallic)
		sm.set_shader_parameter("clearcoat", std.clearcoat if std.clearcoat_enabled else 0.0)
	_flop_mats[key] = sm
	return sm
