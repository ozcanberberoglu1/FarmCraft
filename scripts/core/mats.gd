@tool
class_name Mats
extends RefCounted
## Shared material library, keyed by the surface names used in MeshBuilder.
## Photo-textured surfaces use CC0 Poly Haven maps from art/textures (see CREDITS.md).
## For textured materials the vertex color is a tint: mid grey (0.5) = texture as-is.

const TEX_DIR := "res://art/textures/"
## The stone_wall photo is a pale limestone: brought down to field stone.
const STONE_TINT := Vector3(0.74, 0.74, 0.76)
## Side of the random texture behind the textured shader's value noise (its `tnoise`
## assumes 256).
const NOISE_SIZE := 256

static var _cache: Dictionary = {}
static var _noise: ImageTexture


static func get_mat(key: StringName) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m := _create(key)
	_cache[key] = m
	return m


static func _create(key: StringName) -> Material:
	match key:
		# --- Photo-textured -------------------------------------------------------
		# The plain keys are for anything, props that move included; the *_ext ones age
		# with world-space stains (grime at the foot, rain streaks, patches), so only
		# buildings and other things that never move use them.
		&"planks":
			return _textured("weathered_brown_planks", {"uv_scale": 0.45, "ao_albedo": 0.3})
		&"planks_ext":
			return _textured("weathered_brown_planks", {"uv_scale": 0.45, "ao_albedo": 0.35, "macro_variation": 0.5,
				"grime_top": 0.55, "streaks": 0.3})
		&"floor":
			return _textured("old_wood_floor", {"uv_scale": 0.55, "snow_accumulates": 0.0, "ao_albedo": 0.3,
				"macro_variation": 0.35})
		&"roof":
			# Tile rows are ROOF_ROW apart (see BuildingKit.roof_courses).
			return _textured("roof_tiles_14", {"uv_scale": 0.4, "normal_strength": 1.2, "ao_albedo": 0.3,
				"macro_variation": 0.6})
		&"stone":
			return _textured("stone_wall", {"uv_scale": 0.6, "triplanar": true, "albedo_tint": STONE_TINT,
				"ao_albedo": 0.5})
		&"stone_ext":
			# Plinths and footings: splashed dirt at the foot, a few lichen rosettes.
			return _textured("stone_wall", {"uv_scale": 0.6, "triplanar": true, "albedo_tint": STONE_TINT,
				"ao_albedo": 0.5, "macro_variation": 0.5, "grime_top": 0.5, "lichen_amount": 0.15})
		&"stone_in":
			return _textured("stone_wall", {"uv_scale": 0.6, "triplanar": true, "snow_accumulates": 0.0,
				"albedo_tint": STONE_TINT, "ao_albedo": 0.5, "macro_variation": 0.3})
		# rough_wood's grain runs along V: MeshBuilder.box() without `uv_rotate` for an
		# upright member, BuildingKit.beam(..., true) (or box with `uv_rotate` when its
		# length is on X) for a lying one.
		&"wood":
			return _textured("rough_wood", {"uv_scale": 0.7, "ao_albedo": 0.25})
		&"wood_ext":
			return _textured("rough_wood", {"uv_scale": 0.7, "ao_albedo": 0.3, "macro_variation": 0.4, "grime_top": 0.4})
		&"wood_in":
			return _textured("rough_wood", {"uv_scale": 0.7, "snow_accumulates": 0.0, "ao_albedo": 0.3,
				"macro_variation": 0.3})
		&"paint":
			return _textured("rough_wood", {"uv_scale": 0.7, "roughness_mult": 0.9, "ao_albedo": 0.2})
		&"paint_ext":
			return _textured("rough_wood", {"uv_scale": 0.7, "roughness_mult": 0.9, "ao_albedo": 0.25,
				"macro_variation": 0.3, "grime_top": 0.4, "streaks": 0.25})
		&"fence_wood":
			# Split rails and posts out in the weather for decades: silvered, lichen, green feet.
			return _textured("rough_wood", {"uv_scale": 0.9, "weathering": 0.35, "ao_albedo": 0.4, "macro_variation": 0.5,
				"lichen_amount": 0.5, "moss_amount": 0.2, "normal_strength": 1.3, "roughness_mult": 1.1})
		&"bark":
			return _textured("bark_brown_02", {"uv_scale": 0.9, "normal_strength": 1.3})
		&"bark_pine":
			return _textured("pine_bark", {"uv_scale": 0.8, "normal_strength": 1.3})
		&"rock":
			return _textured("mossy_rock", {"uv_scale": 0.45, "triplanar": true, "normal_strength": 1.2})
		# The bushes' leaf cards are shaded by distance (foliage_card.gdshader shade_*):
		# shaded by the sun's shadows, they get their crown depth (vertex colour) as shade
		# past the shadows' reach (NatureSpawner sets it per graphics preset). The trees
		# have their own materials (NatureModels.tree).
		&"leaves":
			# Leafy twigs of the bushes (tools/build_foliage.gd).
			return _foliage("leaves_cluster", {"tint": Color(0.96, 1.0, 0.94), "brightness": 0.95, "deciduous": 1.0,
				"crown_ao": 0.35, "translucency": 0.5, "alpha_cut": 0.45, "mip_alpha": 0.6, "underside": 0.6,
				"edge_fade": 0.3, "shadow_blur": 2.5, "shade_far": Vector2(4.0, 0.7)})
		&"crop_leaves":
			return _foliage("leaves_broad", {"autumn_factor": 0.0, "sway_amount": 0.05, "flutter": 0.012,
				"tint": Color(0.86, 1.0, 0.8), "translucency": 0.5})
		&"crop_feathery":
			# Carrot tops: a deep, slightly blue green, not the fir twig's lime.
			return _foliage("leaves_fir", {"autumn_factor": 0.0, "sway_amount": 0.05, "flutter": 0.015,
				"tint": Color(0.7, 1.02, 0.58), "brightness": 0.95, "translucency": 0.45})
		&"asphalt":
			return _textured("asphalt_02", {"uv_scale": 0.25, "macro_variation": 0.3})
		&"concrete":
			return _textured("concrete_floor_worn_001", {"uv_scale": 0.35, "ao_albedo": 0.3, "macro_variation": 0.45,
				"streaks": 0.25})
		&"plaster":
			return _textured("painted_plaster_wall", {"uv_scale": 0.4, "tint_strength": 1.0, "macro_variation": 0.3,
				"grime_top": 0.45, "streaks": 0.3})
		&"plaster_in":
			return _textured("painted_plaster_wall", {"uv_scale": 0.4, "snow_accumulates": 0.0})
		&"brick":
			return _textured("red_brick_03", {"uv_scale": 0.5, "ao_albedo": 0.35, "macro_variation": 0.35,
				"grime_top": 0.4, "streaks": 0.2})
		&"corrugated":
			return _textured("corrugated_iron_02", {"uv_scale": 0.5, "normal_strength": 1.2, "macro_variation": 0.4,
				"streaks": 0.35, "rust_amount": 0.08})
		&"tile_floor":
			return _textured("concrete_floor_worn_001", {"uv_scale": 0.7, "snow_accumulates": 0.0, "roughness_mult": 0.6,
				"ao_albedo": 0.3})
		# --- Aged: Grandpa's run-down house and warehouse (same photos, weathered) ------
		&"planks_old":
			return _textured("weathered_brown_planks", {"uv_scale": 0.45, "weathering": 0.55, "grime_top": 1.3,
				"roughness_mult": 1.15, "normal_strength": 1.35, "moss_amount": 0.25, "ao_albedo": 0.45,
				"macro_variation": 0.6, "streaks": 0.45, "lichen_amount": 0.15})
		&"wood_old":
			return _textured("rough_wood", {"uv_scale": 0.7, "weathering": 0.5, "grime_top": 1.0, "roughness_mult": 1.1,
				"moss_amount": 0.3, "ao_albedo": 0.4, "macro_variation": 0.5, "lichen_amount": 0.3})
		&"wood_old_in":
			return _textured("rough_wood", {"uv_scale": 0.7, "weathering": 0.3, "snow_accumulates": 0.0, "ao_albedo": 0.35,
				"macro_variation": 0.4})
		&"paint_old":
			return _textured("rough_wood", {"uv_scale": 0.7, "weathering": 0.25, "grime_top": 0.8, "roughness_mult": 1.05,
				"ao_albedo": 0.35, "macro_variation": 0.5, "streaks": 0.4})
		&"floor_old":
			return _textured("old_wood_floor", {"uv_scale": 0.55, "weathering": 0.3, "roughness_mult": 1.2,
				"snow_accumulates": 0.0, "ao_albedo": 0.35, "macro_variation": 0.5})
		&"roof_old":
			return _textured("roof_tiles_14", {"uv_scale": 0.5, "normal_strength": 1.3, "moss_amount": 0.4,
				"weathering": 0.2, "ao_albedo": 0.35, "macro_variation": 0.7, "lichen_amount": 0.45})
		&"stone_old":
			return _textured("stone_wall", {"uv_scale": 0.6, "triplanar": true, "moss_amount": 0.35, "grime_top": 0.9,
				"albedo_tint": STONE_TINT * 0.92, "ao_albedo": 0.55, "macro_variation": 0.6, "lichen_amount": 0.35})
		&"corrugated_old":
			# Rusted tin: the photo is rust through and through, the shader adds patches of bare zinc.
			return _textured("rusty_corrugated_iron", {"uv_scale": 0.5, "normal_strength": 1.3, "roughness_mult": 1.05,
				"moss_amount": 0.1, "macro_variation": 0.6, "streaks": 0.3, "weathering": 0.3})
		&"corrugated_worn":
			# Galvanised sheets gone rusty in patches and runs (the odd replaced sheet).
			return _textured("corrugated_iron_02", {"uv_scale": 0.5, "normal_strength": 1.3, "rust_amount": 0.6,
				"roughness_mult": 1.15, "moss_amount": 0.1, "macro_variation": 0.5, "streaks": 0.35})
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
			go.albedo_color = Color(0.4, 0.42, 0.36, 0.62)
			go.roughness = 0.35
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
			# Plate glass: the shop behind it only dimly (no interiors are modelled), the
			# street in it at an angle.
			return _window_glass({"clarity": 0.42, "dirt": 0.18, "wobble": 0.0, "tint": Color(0.5, 0.58, 0.6)})
		&"sign":
			return _shader("res://shaders/vcolor.gdshader", {"roughness": 0.4, "specular_val": 0.5, "snow_accumulates": 0.0})
		&"barn_floor":
			return _textured("raked_dirt", {"uv_scale": 0.45, "snow_accumulates": 0.0, "normal_strength": 0.6})
		&"dung":
			# Rotted manure: dirt texture on every side, bumpy and a little wet.
			return _textured("raked_dirt", {"uv_scale": 1.6, "triplanar": true, "normal_strength": 1.6,
				"roughness_mult": 0.95, "snow_accumulates": 0.6})
		&"soil_tilled":
			# Freshly hoed, dark crumbly earth.
			return _soil("farm_soil", 0.6, Color(0.88, 0.92, 1.0))
		&"soil_untilled":
			# Packed bed soil with a dry crust.
			var packed := _soil("dirt", 0.5, Color(0.92, 0.92, 0.92))
			packed.set_shader_parameter("crust", 1.0)
			return packed
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
		&"zinc":
			# Galvanised sheet years out in the weather (gutters, downpipes): dull grey, so it
			# doesn't mirror the warm light bounced under the eaves.
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.72, "metallic_val": 0.22, "specular_val": 0.4, "noise_strength": 0.2,
				"noise_scale": Vector3(14, 14, 14)})
		&"clay":
			# Fired clay (a chimney pot).
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.82, "specular_val": 0.35, "noise_strength": 0.22, "noise_scale": Vector3(9, 9, 9)})
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
			# Clear glass on small things (a jar's neck).
			var g := StandardMaterial3D.new()
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.albedo_color = Color(0.72, 0.86, 0.95, 0.22)
			g.roughness = 0.05
			g.metallic_specular = 0.8
			return g
		&"window_glass":
			# Old sheet glass in a farmhouse window: dim room behind, sky in it at an angle.
			return _window_glass({"clarity": 0.72, "dirt": 0.22, "wobble": 0.35})
		&"water_still":
			return _shader("res://shaders/vcolor.gdshader", {
				"roughness": 0.08, "specular_val": 0.7, "noise_strength": 0.05, "snow_accumulates": 0.0})
		_:
			return _shader("res://shaders/vcolor.gdshader", {})


static func texture(name: String, suffix: String) -> Texture2D:
	return load("%s%s/%s_%s" % [TEX_DIR, name, name, suffix]) as Texture2D


## The random texture the textured and window-glass shaders build their value noise
## from (one byte a texel, the same on every machine). Made once, in a few milliseconds.
static func noise_texture() -> ImageTexture:
	if _noise == null:
		var bytes := PackedByteArray()
		# 32 random bytes a hash.
		for i in range(0, NOISE_SIZE * NOISE_SIZE, 32):
			bytes.append_array(("farm noise %d" % i).sha256_buffer())
		_noise = ImageTexture.create_from_image(Image.create_from_data(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_R8, bytes))
	return _noise


static func _window_glass(params: Dictionary) -> ShaderMaterial:
	var m := _shader("res://shaders/window_glass.gdshader", params)
	m.set_shader_parameter("noise_tex", noise_texture())
	return m


static func _textured(name: String, params: Dictionary) -> ShaderMaterial:
	var m := _shader("res://shaders/textured.gdshader", params)
	m.set_shader_parameter("noise_tex", noise_texture())
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
