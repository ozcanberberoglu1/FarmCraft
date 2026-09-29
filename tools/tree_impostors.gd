extends SceneTree
## Renders the hill forest trees (NatureModels.forest_meshes) from the side, unlit and
## with no wind, into one atlas for the distant impostor cards: one cell per tree,
## base at the bottom edge, framed by NatureModels.impostor_frame.
## Run (needs a window): godot --path . -s res://tools/tree_impostors.gd
## then reimport: godot --headless --path . --import

const CELL := Vector2i(256, 384)
const SUPERSAMPLE := 2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Summer, dry, still: seasons and weather are applied by the impostor shader.
	for g: StringName in [&"snow_amount", &"autumn_amount", &"wetness", &"leaf_drop", &"wind_strength"]:
		RenderingServer.global_shader_parameter_set(g, 0.0)
	var meshes := NatureModels.forest_meshes()
	var vp := SubViewport.new()
	vp.size = CELL * SUPERSAMPLE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	# Far off (orthogonal, so only for the foliage's shade by distance): the trees as
	# seen where their pictures take over.
	cam.far = 400.0
	vp.add_child(cam)
	var mi := MeshInstance3D.new()
	vp.add_child(mi)
	var atlas := Image.create(CELL.x * meshes.size(), CELL.y, false, Image.FORMAT_RGBA8)
	for i in meshes.size():
		mi.mesh = meshes[i]
		var frame := NatureModels.impostor_frame(meshes[i])
		cam.size = frame.y
		cam.position = Vector3(0, frame.y * 0.5, 150)
		cam.look_at(Vector3(0, frame.y * 0.5, 0), Vector3.UP)
		for f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		# Spread leaf colours into the transparent border so mipmaps don't darken edges.
		img.fix_alpha_edges()
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, 0))
		print("impostor %d: frame %.2f x %.2f m" % [i, frame.x, frame.y])
	atlas.fix_alpha_edges()
	var path := ProjectSettings.globalize_path(NatureModels.IMPOSTOR_ATLAS)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	atlas.save_png(path)
	print("atlas ", path)
	quit()
