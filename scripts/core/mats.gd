@tool
class_name Mats
extends RefCounted
## Shared material library, keyed by the surface names used in MeshBuilder.
## Photo-textured surfaces use CC0 Poly Haven maps from art/textures (see CREDITS.md).
## For textured materials the vertex color is a tint: mid grey (0.5) = texture as-is.

const TEX_DIR := "res://art/textures/"

static var _cache: Dictionary = {}


static func get_mat(key: StringName) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m := _create(key)
	_cache[key] = m
	return m


static func _create(key: StringName) -> Material:
	match key:
		# --- Photo-textured -------------------------------------------------------
		&"planks":
			return _textured("weathered_brown_planks", {"uv_scale": 0.45})
		&"floor":
			return _textured("old_wood_floor", {"uv_scale": 0.55, "snow_accumulates": 0.0})
		&"roof":
			return _textured("roof_tiles_14", {"uv_scale": 0.5, "normal_strength": 1.2})
		&"stone":
			return _textured("stone_wall", {"uv_scale": 0.6, "triplanar": true})
		&"stone_in":
			return _textured("stone_wall", {"uv_scale": 0.6, "triplanar": true, "snow_accumulates": 0.0})
		&"wood":
			return _textured("rough_wood", {"uv_scale": 0.7})
		&"wood_in":
			return _textured("rough_wood", {"uv_scale": 0.7, "snow_accumulates": 0.0})
		&"paint":
			return _textured("rough_wood", {"uv_scale": 0.7, "roughness_mult": 0.9})
		&"bark":
			return _textured("bark_brown_02", {"uv_scale": 0.9, "normal_strength": 1.3})
		&"bark_pine":
			return _textured("pine_bark", {"uv_scale": 0.8, "normal_strength": 1.3})
		&"rock":
			return _textured("mossy_rock", {"uv_scale": 0.45, "triplanar": true, "normal_strength": 1.2})
		&"leaves":
			return _foliage("leaves_broad", {"tint": Color(0.92, 1.0, 0.86), "brightness": 1.05, "deciduous": 1.0})
		&"leaves_far":
			return _foliage("leaves_broad", {"tint": Color(0.84, 0.97, 0.8), "brightness": 1.0, "deciduous": 1.0,
				"crown_ao": 1.0})
		&"needles":
			return _foliage("leaves_fir", {"autumn_factor": 0.0, "sway_amount": 0.07, "translucency": 0.3,
				"brightness": 1.1})
		&"needles_far":
			return _foliage("leaves_fir", {"autumn_factor": 0.0, "sway_amount": 0.05, "translucency": 0.3,
				"brightness": 1.0, "alpha_cut": 0.22, "crown_ao": 1.0, "tint": Color(0.82, 0.96, 0.8)})
		&"crop_leaves":
			return _foliage("leaves_broad", {"autumn_factor": 0.0, "sway_amount": 0.05, "flutter": 0.012,
				"tint": Color(0.86, 1.0, 0.8), "translucency": 0.5})
		&"crop_feathery":
			return _foliage("leaves_fir", {"autumn_factor": 0.0, "sway_amount": 0.05, "flutter": 0.015,
				"tint": Color(0.82, 1.3, 0.62), "brightness": 1.15, "translucency": 0.5})
		&"asphalt":
			return _textured("asphalt_02", {"uv_scale": 0.25})
		&"concrete":
			return _textured("concrete_floor_worn_001", {"uv_scale": 0.35})
		&"plaster":
			return _textured("painted_plaster_wall", {"uv_scale": 0.4, "tint_strength": 1.0})
		&"plaster_in":
			return _textured("painted_plaster_wall", {"uv_scale": 0.4, "snow_accumulates": 0.0})
		&"brick":
			return _textured("red_brick_03", {"uv_scale": 0.5})
		&"corrugated":
			return _textured("corrugated_iron_02", {"uv_scale": 0.5, "normal_strength": 1.2})
		&"tile_floor":
			return _textured("concrete_floor_worn_001", {"uv_scale": 0.7, "snow_accumulates": 0.0, "roughness_mult": 0.6})
		# --- Aged: Grandpa's run-down house and warehouse (same photos, weathered) ------
		&"planks_old":
			return _textured("weathered_brown_planks", {"uv_scale": 0.45, "weathering": 0.55, "grime_top": 1.3,
				"roughness_mult": 1.15, "normal_strength": 1.35, "moss_amount": 0.25})
		&"wood_old":
			return _textured("rough_wood", {"uv_scale": 0.7, "weathering": 0.5, "grime_top": 1.0, "roughness_mult": 1.1,
				"moss_amount": 0.3})
		&"wood_old_in":
			return _textured("rough_wood", {"uv_scale": 0.7, "weathering": 0.3, "snow_accumulates": 0.0})
		&"paint_old":
			return _textured("rough_wood", {"uv_scale": 0.7, "weathering": 0.25, "grime_top": 0.8, "roughness_mult": 1.05})
		&"floor_old":
			return _textured("old_wood_floor", {"uv_scale": 0.55, "weathering": 0.3, "roughness_mult": 1.2,
				"snow_accumulates": 0.0})
		&"roof_old":
			return _textured("roof_tiles_14", {"uv_scale": 0.5, "normal_strength": 1.3, "moss_amount": 0.4,
				"weathering": 0.2})
		&"stone_old":
			return _textured("stone_wall", {"uv_scale": 0.6, "triplanar": true, "moss_amount": 0.35, "grime_top": 0.9})
		&"corrugated_old":
			return _textured("corrugated_iron_02", {"uv_scale": 0.5, "normal_strength": 1.3, "rust_amount": 0.65,
				"roughness_mult": 1.15, "moss_amount": 0.12})
		&"dirt_old":
			# Dust, dried mud and leaf litter on old floors (no UVs needed).
			return _textured("raked_dirt", {"uv_scale": 1.1, "triplanar": true, "normal_strength": 0.7,
				"roughness_mult": 1.05, "snow_accumulates": 0.0})
		&"rusty":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.86, "metallic_val": 0.3, "specular_val": 0.35, "noise_strength": 0.4,
				"noise_scale": Vector3(16, 16, 16), "snow_accumulates": 0.0})
		&"glass_old":
			# Grimy, cracked panes: seen from both sides.
			var go := StandardMaterial3D.new()
			go.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			go.cull_mode = BaseMaterial3D.CULL_DISABLED
			go.albedo_color = Color(0.52, 0.55, 0.47, 0.5)
			go.roughness = 0.45
			go.metallic_specular = 0.6
			return go
		&"cobweb":
			# Dusty webs in the corners; vertex alpha fades them toward the rim.
			var cw := StandardMaterial3D.new()
			cw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cw.cull_mode = BaseMaterial3D.CULL_DISABLED
			cw.vertex_color_use_as_albedo = true
			cw.albedo_color = Color(0.86, 0.85, 0.82, 1.0)
			cw.roughness = 0.95
			cw.metallic_specular = 0.2
			return cw
		&"shop_glass":
			var sg := StandardMaterial3D.new()
			sg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sg.albedo_color = Color(0.55, 0.66, 0.7, 0.28)
			sg.roughness = 0.03
			sg.metallic = 0.2
			sg.metallic_specular = 0.9
			return sg
		&"sign":
			return _shader("res://shaders/vcolor.gdshader", {"roughness": 0.4, "specular_val": 0.5, "snow_accumulates": 0.0})
		&"barn_floor":
			return _textured("raked_dirt", {"uv_scale": 0.45, "snow_accumulates": 0.0, "normal_strength": 0.6})
		&"dung":
			# Rotted manure: dirt texture on every side, bumpy and a little wet.
			return _textured("raked_dirt", {"uv_scale": 1.6, "triplanar": true, "normal_strength": 1.6,
				"roughness_mult": 0.95, "snow_accumulates": 0.6})
		&"soil_tilled":
			return _soil("raked_dirt", 0.55, Color(1.02, 0.9, 0.8))
		&"soil_untilled":
			return _soil("rocky_trail_02", 0.5, Color(0.95, 0.95, 0.9))
		# --- Animals ----------------------------------------------------------------
		&"fur":
			return _shader("res://shaders/coat.gdshader", {"pattern": 0})
		&"holstein":
			return _shader("res://shaders/coat.gdshader", {"pattern": 1, "fur_strength": 0.1})
		&"wool":
			return _shader("res://shaders/coat.gdshader", {"pattern": 2, "rim_amount": 0.55})
		&"fleece":
			return _shader("res://shaders/coat.gdshader", {"pattern": 2, "rim_amount": 0.3, "curl_scale": 150.0, "fur_strength": 0.35})
		&"feather":
			return _shader("res://shaders/coat.gdshader", {"pattern": 3, "fur_strength": 0.08, "rim_amount": 0.25})
		&"hair":
			return _shader("res://shaders/coat.gdshader", {"pattern": 4, "fur_strength": 0.05, "rim_amount": 0.2})
		&"skin":
			return _shader("res://shaders/coat.gdshader", {"pattern": 0, "fur_strength": 0.05, "roughness_base": 0.55, "rim_amount": 0.1})
		&"hoof":
			return _shader("res://shaders/vcolor.gdshader", {"roughness": 0.55, "noise_strength": 0.1, "snow_accumulates": 0.0})
		&"eye":
			var e := StandardMaterial3D.new()
			e.albedo_color = Color(0.03, 0.025, 0.02)
			e.roughness = 0.08
			e.metallic_specular = 0.9
			return e
		# --- Items ------------------------------------------------------------------
		&"steel":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.52, "metallic_val": 0.9, "specular_val": 0.5, "noise_strength": 0.18,
				"noise_scale": Vector3(9, 9, 9), "snow_accumulates": 0.0})
		&"galv":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.58, "metallic_val": 0.55, "specular_val": 0.45, "noise_strength": 0.16,
				"noise_scale": Vector3(14, 14, 14), "snow_accumulates": 0.0})
		&"veg":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.62, "specular_val": 0.45, "noise_strength": 0.16,
				"noise_scale": Vector3(28, 28, 28), "snow_accumulates": 0.0})
		&"veg_gloss":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.24, "specular_val": 0.6, "noise_strength": 0.06,
				"noise_scale": Vector3(30, 30, 30), "snow_accumulates": 0.0})
		&"veg_rough":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.82, "specular_val": 0.3, "noise_strength": 0.38,
				"noise_scale": Vector3(45, 45, 45), "snow_accumulates": 0.0})
		&"paper":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.92, "specular_val": 0.25, "noise_strength": 0.05,
				"noise_scale": Vector3(60, 60, 60), "snow_accumulates": 0.0})
		&"straw":
			return _shader("res://shaders/straw.gdshader", {})
		&"endgrain":
			return _shader("res://shaders/endgrain.gdshader", {})
		# --- Procedural -------------------------------------------------------------
		&"foliage":
			return _shader("res://shaders/foliage.gdshader", {"autumn_factor": 1.0})
		&"evergreen":
			return _shader("res://shaders/foliage.gdshader", {
				"autumn_factor": 0.0, "sway_amount": 0.05, "translucency": 0.2})
		&"metal":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.35, "metallic_val": 0.85, "noise_strength": 0.06, "specular_val": 0.5})
		&"cloth":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 1.0, "noise_strength": 0.1, "noise_scale": Vector3(14, 14, 14),
				"snow_accumulates": 0.0, "specular_val": 0.2})
		&"paint_in":
			return _shader("res://shaders/vcolor.gdshader", {"snow_accumulates": 0.0})
		&"glow":
			return _shader("res://shaders/vcolor.gdshader", {"emission_strength": 3.0, "snow_accumulates": 0.0})
		&"glass":
			var g := StandardMaterial3D.new()
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.albedo_color = Color(0.72, 0.86, 0.95, 0.22)
			g.roughness = 0.05
			g.metallic_specular = 0.8
			return g
		&"water_still":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.08, "specular_val": 0.7, "noise_strength": 0.05, "snow_accumulates": 0.0})
		_:
			return _shader("res://shaders/vcolor.gdshader", {})


static func texture(name: String, suffix: String) -> Texture2D:
	return load("%s%s/%s_%s" % [TEX_DIR, name, name, suffix]) as Texture2D


static func _textured(name: String, params: Dictionary) -> ShaderMaterial:
	var m := _shader("res://shaders/textured.gdshader", params)
	m.set_shader_parameter("albedo_tex", texture(name, "diff.jpg"))
	m.set_shader_parameter("normal_tex", texture(name, "nor.jpg"))
	m.set_shader_parameter("arm_tex", texture(name, "arm.jpg"))
	return m


static func _soil(name: String, scale: float, tint: Color) -> ShaderMaterial:
	var m := _shader("res://shaders/soil.gdshader", {"uv_scale": scale, "tint": tint})
	m.set_shader_parameter("albedo_tex", texture(name, "diff.jpg"))
	m.set_shader_parameter("normal_tex", texture(name, "nor.jpg"))
	return m


static func _foliage(name: String, params: Dictionary) -> ShaderMaterial:
	var m := _shader("res://shaders/foliage_card.gdshader", params)
	m.set_shader_parameter("albedo_tex", texture(name, "albedo.png"))
	m.set_shader_parameter("normal_tex", texture(name, "nor.jpg"))
	return m


static func _shader(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m
